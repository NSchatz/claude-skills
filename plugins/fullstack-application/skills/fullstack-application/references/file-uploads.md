---
title: File Uploads and S3
weight: 7
---

# File Uploads and S3

This reference covers file upload handling with Multer, S3 storage with presigned URLs, file validation, and image processing.

## Table of Contents

- [Upload Strategy Decision](#upload-strategy-decision)
- [Multer Configuration](#multer-configuration)
- [S3 Service](#s3-service)
- [Server-Side Upload Controller](#server-side-upload-controller)
- [Presigned URL Flow](#presigned-url-flow)
- [Image Processing Pipeline](#image-processing-pipeline)
- [Frontend Upload Component](#frontend-upload-component)

---

## Upload Strategy Decision

| Factor | Server-side upload | Presigned URL |
|--------|-------------------|---------------|
| File size | < 10 MB | > 10 MB or video |
| Server processing needed | Yes (resize, validate content) | No immediate processing |
| Server memory | Consumed during upload | Not consumed |
| Validation | Full server-side validation | Content-type + size via S3 policy |
| Complexity | Single request | Two requests (get URL, then PUT to S3) |

Use server-side upload for avatars, thumbnails, and small documents. Use presigned URLs for large files (videos, bulk imports).

---

## Multer Configuration

```bash
pnpm add multer
pnpm add -D @types/multer
```

```ts
// infrastructure/upload/multer.config.ts
import { MulterModuleOptions } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { BadRequestException } from '@nestjs/common';

const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10 MB

const ALLOWED_MIME_TYPES: Record<string, string[]> = {
  image: ['image/jpeg', 'image/png', 'image/webp', 'image/gif'],
  document: ['application/pdf', 'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
};

export function createMulterOptions(
  category: keyof typeof ALLOWED_MIME_TYPES,
): MulterModuleOptions {
  return {
    storage: memoryStorage(), // keep in memory for S3 upload pipeline
    limits: { fileSize: MAX_FILE_SIZE },
    fileFilter: (_req, file, cb) => {
      if (!ALLOWED_MIME_TYPES[category].includes(file.mimetype)) {
        return cb(
          new BadRequestException(
            `Invalid file type. Allowed: ${ALLOWED_MIME_TYPES[category].join(', ')}`,
          ),
          false,
        );
      }
      cb(null, true);
    },
  };
}
```

---

## S3 Service

```bash
pnpm add @aws-sdk/client-s3 @aws-sdk/s3-request-presigner
```

```ts
// infrastructure/upload/s3.service.ts
import {
  S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'node:crypto';
import { extname } from 'node:path';

@Injectable()
export class S3Service {
  private client: S3Client;
  private bucket: string;

  constructor(private config: ConfigService) {
    this.bucket = config.getOrThrow('S3_BUCKET');
    this.client = new S3Client({
      region: config.getOrThrow('AWS_REGION'),
      // For local dev with MinIO:
      ...(config.get('S3_ENDPOINT') && {
        endpoint: config.get('S3_ENDPOINT'),
        forcePathStyle: true,
      }),
    });
  }

  async upload(file: Express.Multer.File, folder: string): Promise<{ key: string; url: string }> {
    const key = `${folder}/${randomUUID()}${extname(file.originalname)}`;

    await this.client.send(new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      Body: file.buffer,
      ContentType: file.mimetype,
    }));

    return { key, url: `https://${this.bucket}.s3.amazonaws.com/${key}` };
  }

  async getPresignedUploadUrl(
    folder: string, filename: string, contentType: string,
  ): Promise<{ uploadUrl: string; key: string }> {
    const key = `${folder}/${randomUUID()}${extname(filename)}`;

    const uploadUrl = await getSignedUrl(
      this.client,
      new PutObjectCommand({ Bucket: this.bucket, Key: key, ContentType: contentType }),
      { expiresIn: 3600 },
    );

    return { uploadUrl, key };
  }

  async getPresignedDownloadUrl(key: string): Promise<string> {
    return getSignedUrl(
      this.client,
      new GetObjectCommand({ Bucket: this.bucket, Key: key }),
      { expiresIn: 3600 },
    );
  }

  async delete(key: string): Promise<void> {
    await this.client.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: key }));
  }
}
```

### Environment Variables

```dotenv
S3_BUCKET=myapp-uploads
AWS_REGION=us-east-1
# For local dev with MinIO:
S3_ENDPOINT=http://localhost:9000
```

---

## Server-Side Upload Controller

```ts
@Controller('uploads')
@UseGuards(JwtAuthGuard)
export class UploadsController {
  constructor(private s3: S3Service) {}

  @Post('avatar')
  @UseInterceptors(FileInterceptor('file', createMulterOptions('image')))
  async uploadAvatar(
    @UploadedFile(new ParseFilePipe({
      validators: [
        new MaxFileSizeValidator({ maxSize: 5 * 1024 * 1024 }),
        new FileTypeValidator({ fileType: /^image\/(jpeg|png|webp)$/ }),
      ],
    }))
    file: Express.Multer.File,
    @CurrentUser() user: User,
  ) {
    return this.s3.upload(file, `avatars/${user.id}`);
  }
}
```

---

## Presigned URL Flow

For large files, the client uploads directly to S3:

1. Client requests a presigned URL from the API
2. Client uploads the file directly to S3 using the presigned URL
3. Client confirms the upload with the API

```ts
@Post('presigned-url')
async getPresignedUrl(@Body() dto: PresignedUrlDto, @CurrentUser() user: User) {
  const allowedTypes = ['image/jpeg', 'image/png', 'video/mp4', 'application/pdf'];
  if (!allowedTypes.includes(dto.contentType)) {
    throw new BadRequestException('Unsupported file type');
  }

  return this.s3.getPresignedUploadUrl(
    `user-uploads/${user.id}`, dto.filename, dto.contentType,
  );
}

@Post('confirm')
async confirmUpload(@Body() dto: ConfirmUploadDto, @CurrentUser() user: User) {
  // Verify the object exists in S3 and belongs to the user's folder
  return this.uploadsService.confirm(dto.key, user.id);
}
```

---

## Image Processing Pipeline

Use BullMQ + Sharp for async image processing (thumbnails, WebP conversion):

```bash
pnpm add sharp
pnpm add -D @types/sharp
```

```ts
// infrastructure/queue/processors/media.processor.ts
import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import sharp from 'sharp';

interface ProcessAvatarPayload {
  key: string;
  userId: string;
  variants: Array<{ name: string; width: number; height: number }>;
}

@Processor('media-processing', { concurrency: 3 })
export class MediaProcessor extends WorkerHost {
  constructor(private s3: S3Service) { super(); }

  async process(job: Job<ProcessAvatarPayload>): Promise<void> {
    const { key, userId, variants } = job.data;

    const originalBuffer = await this.s3.getBuffer(key);

    await Promise.all(
      variants.map(async (variant) => {
        const processed = await sharp(originalBuffer)
          .resize(variant.width, variant.height, { fit: 'cover', position: 'attention' })
          .webp({ quality: 80 })
          .toBuffer();

        const variantKey = key.replace(/(\.[^.]+)$/, `-${variant.name}.webp`);
        await this.s3.uploadBuffer(processed, variantKey, 'image/webp');
      }),
    );

    await job.updateProgress(100);
  }
}
```

Typical variant sizes:

| Variant | Width | Height | Use case |
|---------|-------|--------|----------|
| `thumb` | 64 | 64 | Avatar in nav/list |
| `medium` | 256 | 256 | Profile page |
| `large` | 512 | 512 | Full-size display |

---

## Frontend Upload Component

See `forms-and-validation.md` for a complete file upload form with progress tracking, abort, and validation.

### Presigned URL Upload Flow

```ts
async function uploadWithPresignedUrl(file: File) {
  // 1. Get presigned URL from our API
  const { uploadUrl, key } = await api.post('/uploads/presigned-url', {
    filename: file.name,
    contentType: file.type,
  });

  // 2. Upload directly to S3
  await fetch(uploadUrl, {
    method: 'PUT',
    body: file,
    headers: { 'Content-Type': file.type },
  });

  // 3. Confirm with our API
  await api.post('/uploads/confirm', { key });

  return key;
}
```

### Local Dev with MinIO

Add MinIO to Docker Compose for S3-compatible local development:

```yaml
# infrastructure/docker-compose.yml
services:
  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    ports:
      - '9000:9000'
      - '9001:9001'
    volumes:
      - minio_data:/data

volumes:
  minio_data:
```
