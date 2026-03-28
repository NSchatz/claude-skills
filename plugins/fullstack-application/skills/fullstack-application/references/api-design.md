---
title: API Design Patterns
weight: 3
---

# API Design Patterns

This reference covers API response standardization, pagination, filtering, sorting, versioning, and request/response middleware. For endpoint-level patterns (controllers, DTOs, Swagger), see `backend.md`.

## Table of Contents

- [Error Response Format (RFC 7807)](#error-response-format-rfc-7807)
- [Pagination](#pagination)
- [Filtering and Sorting](#filtering-and-sorting)
- [API Versioning](#api-versioning)
- [Response Envelope](#response-envelope)
- [Correlation IDs](#correlation-ids)
- [Request Logging](#request-logging)

---

## Error Response Format (RFC 7807)

All API errors use the [RFC 7807 Problem Details](https://www.rfc-editor.org/rfc/rfc7807) format. This gives clients a consistent, machine-readable error shape regardless of which endpoint failed.

### Shape

```ts
// common/interfaces/problem-details.interface.ts
export interface ProblemDetails {
  type: string;          // URI identifying the error type
  title: string;         // short human-readable summary
  status: number;        // HTTP status code
  detail?: string;       // explanation specific to this occurrence
  instance?: string;     // the request path
  traceId?: string;      // correlation ID for debugging
  errors?: FieldError[]; // validation errors
}

export interface FieldError {
  field: string;
  message: string;
  code: string;
}
```

### Global Exception Filter

```ts
// common/filters/problem-details.filter.ts
import {
  ExceptionFilter, Catch, ArgumentsHost, HttpException, HttpStatus, Logger,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import type { ProblemDetails, FieldError } from '../interfaces/problem-details.interface';

@Catch()
export class ProblemDetailsFilter implements ExceptionFilter {
  private readonly logger = new Logger(ProblemDetailsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status: number;
    let problem: ProblemDetails;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const body = exception.getResponse();
      const fieldErrors = this.extractFieldErrors(body);

      problem = {
        type: `https://api.example.com/errors/${this.typeSlug(status)}`,
        title: this.title(status),
        status,
        detail: typeof body === 'string' ? body : (body as any).message,
        instance: request.url,
        traceId: request.headers['x-request-id'] as string,
        ...(fieldErrors.length > 0 && { errors: fieldErrors }),
      };
    } else {
      status = HttpStatus.INTERNAL_SERVER_ERROR;
      problem = {
        type: 'https://api.example.com/errors/internal-server-error',
        title: 'Internal Server Error',
        status: 500,
        detail: 'An unexpected error occurred.',
        instance: request.url,
        traceId: request.headers['x-request-id'] as string,
      };
      this.logger.error('Unhandled exception', exception);
    }

    response
      .status(status)
      .header('Content-Type', 'application/problem+json')
      .json(problem);
  }

  private typeSlug(status: number): string {
    const map: Record<number, string> = {
      400: 'bad-request', 401: 'unauthorized', 403: 'forbidden',
      404: 'not-found', 409: 'conflict', 422: 'unprocessable-entity',
      429: 'too-many-requests',
    };
    return map[status] ?? 'internal-server-error';
  }

  private title(status: number): string {
    const map: Record<number, string> = {
      400: 'Bad Request', 401: 'Unauthorized', 403: 'Forbidden',
      404: 'Not Found', 409: 'Conflict', 422: 'Unprocessable Entity',
      429: 'Too Many Requests',
    };
    return map[status] ?? 'Internal Server Error';
  }

  private extractFieldErrors(body: unknown): FieldError[] {
    if (typeof body === 'object' && body !== null && 'message' in body) {
      const msg = (body as any).message;
      if (Array.isArray(msg)) {
        return msg.map((m: string) => ({
          field: m.split(' ')[0] ?? 'unknown',
          message: m,
          code: 'VALIDATION_ERROR',
        }));
      }
    }
    return [];
  }
}
```

Register in `main.ts`:

```ts
app.useGlobalFilters(new ProblemDetailsFilter());
```

### Example Error Responses

**Validation error (422):**
```json
{
  "type": "https://api.example.com/errors/unprocessable-entity",
  "title": "Unprocessable Entity",
  "status": 422,
  "detail": "Validation failed",
  "instance": "/api/posts",
  "traceId": "abc-123-def",
  "errors": [
    { "field": "title", "message": "title must be a string", "code": "VALIDATION_ERROR" }
  ]
}
```

**Not found (404):**
```json
{
  "type": "https://api.example.com/errors/not-found",
  "title": "Not Found",
  "status": 404,
  "detail": "Post clx123 not found",
  "instance": "/api/posts/clx123",
  "traceId": "abc-456-ghi"
}
```

---

## Pagination

### When to Use Which

| Pattern | Use when | Example |
|---------|----------|---------|
| **Offset** | Users need to jump to specific pages, datasets are small-to-medium, admin dashboards | `GET /api/users?page=3&limit=20` |
| **Cursor** | Data changes frequently, infinite scroll, large datasets, public APIs | `GET /api/posts?cursor=abc123&limit=20` |

### Offset-Based Pagination

```ts
// common/dto/offset-pagination.dto.ts
import { IsOptional, IsInt, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class OffsetPaginationDto {
  @ApiPropertyOptional({ minimum: 1, default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @ApiPropertyOptional({ minimum: 1, maximum: 100, default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 20;
}

export interface OffsetPaginatedResponse<T> {
  data: T[];
  meta: {
    page: number;
    limit: number;
    totalItems: number;
    totalPages: number;
    hasNextPage: boolean;
    hasPrevPage: boolean;
  };
}
```

**Service usage with Prisma:**

```ts
async findAll(dto: OffsetPaginationDto): Promise<OffsetPaginatedResponse<Post>> {
  const { page = 1, limit = 20 } = dto;
  const skip = (page - 1) * limit;

  const [data, totalItems] = await Promise.all([
    this.prisma.post.findMany({
      skip,
      take: limit,
      orderBy: { createdAt: 'desc' },
    }),
    this.prisma.post.count(),
  ]);

  const totalPages = Math.ceil(totalItems / limit);

  return {
    data,
    meta: { page, limit, totalItems, totalPages, hasNextPage: page < totalPages, hasPrevPage: page > 1 },
  };
}
```

### Cursor-Based Pagination

```ts
// common/dto/cursor-pagination.dto.ts
export class CursorPaginationDto {
  @ApiPropertyOptional({ description: 'Opaque cursor from previous response' })
  @IsOptional()
  @IsString()
  cursor?: string;

  @ApiPropertyOptional({ minimum: 1, maximum: 100, default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 20;
}

export interface CursorPaginatedResponse<T> {
  data: T[];
  meta: {
    hasNextPage: boolean;
    nextCursor: string | null;
    limit: number;
  };
}
```

**Cursor encoding/decoding:**

```ts
// common/utils/cursor.ts
export function encodeCursor(id: string, createdAt: Date): string {
  return Buffer.from(
    JSON.stringify({ id, createdAt: createdAt.toISOString() }),
  ).toString('base64url');
}

export function decodeCursor(cursor: string): { id: string; createdAt: Date } {
  const parsed = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8'));
  return { id: parsed.id, createdAt: new Date(parsed.createdAt) };
}
```

**Service usage with Prisma:**

```ts
async findAll(dto: CursorPaginationDto): Promise<CursorPaginatedResponse<Post>> {
  const { cursor, limit = 20 } = dto;

  const whereClause = cursor
    ? (() => {
        const decoded = decodeCursor(cursor);
        return {
          OR: [
            { createdAt: { lt: decoded.createdAt } },
            { createdAt: decoded.createdAt, id: { lt: decoded.id } },
          ],
        };
      })()
    : {};

  const results = await this.prisma.post.findMany({
    where: whereClause,
    take: limit + 1, // fetch one extra to detect next page
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
  });

  const hasNextPage = results.length > limit;
  const data = hasNextPage ? results.slice(0, limit) : results;
  const last = data.at(-1);

  return {
    data,
    meta: {
      hasNextPage,
      nextCursor: last ? encodeCursor(last.id, last.createdAt) : null,
      limit,
    },
  };
}
```

---

## Filtering and Sorting

Combine filtering with pagination. Allowlist sortable columns to prevent injection.

```ts
// modules/posts/dto/post-query.dto.ts
import { IsOptional, IsString, IsEnum, IsIn } from 'class-validator';

export enum SortOrder {
  ASC = 'asc',
  DESC = 'desc',
}

export class PostQueryDto extends OffsetPaginationDto {
  @ApiPropertyOptional({ description: 'Search title and body' })
  @IsOptional()
  @IsString()
  search?: string;

  @ApiPropertyOptional({ description: 'Filter by author ID' })
  @IsOptional()
  @IsString()
  authorId?: string;

  @ApiPropertyOptional({ enum: ['createdAt', 'title', 'updatedAt'], default: 'createdAt' })
  @IsOptional()
  @IsIn(['createdAt', 'title', 'updatedAt'])
  sortBy?: string = 'createdAt';

  @ApiPropertyOptional({ enum: SortOrder, default: SortOrder.DESC })
  @IsOptional()
  @IsEnum(SortOrder)
  sortOrder?: SortOrder = SortOrder.DESC;
}
```

**Service:**

```ts
async findAll(query: PostQueryDto): Promise<OffsetPaginatedResponse<Post>> {
  const where: Prisma.PostWhereInput = {};

  if (query.search) {
    where.OR = [
      { title: { contains: query.search, mode: 'insensitive' } },
      { body: { contains: query.search, mode: 'insensitive' } },
    ];
  }

  if (query.authorId) {
    where.userId = query.authorId;
  }

  const { page = 1, limit = 20 } = query;
  const skip = (page - 1) * limit;

  const [data, totalItems] = await Promise.all([
    this.prisma.post.findMany({
      where,
      skip,
      take: limit,
      orderBy: { [query.sortBy ?? 'createdAt']: query.sortOrder ?? 'desc' },
    }),
    this.prisma.post.count({ where }),
  ]);

  const totalPages = Math.ceil(totalItems / limit);

  return {
    data,
    meta: { page, limit, totalItems, totalPages, hasNextPage: page < totalPages, hasPrevPage: page > 1 },
  };
}
```

**Request:** `GET /api/posts?search=typescript&sortBy=createdAt&sortOrder=desc&page=2&limit=10`

---

## API Versioning

Use URI-based versioning — it's the most explicit and cacheable strategy.

```ts
// main.ts
import { VersioningType } from '@nestjs/common';

app.enableVersioning({
  type: VersioningType.URI,
  defaultVersion: '1',
  prefix: 'api/v',
});
```

### Per-Controller Versioning

```ts
// For breaking changes, create a new versioned controller:
@Controller({ path: 'users', version: '2' })
export class UsersV2Controller {
  // New response shape, different behavior, etc.
}
```

### Per-Route Versioning

```ts
@Controller('users')
export class UsersController {
  @Version('1')
  @Get()
  findAllV1() { /* original */ }

  @Version('2')
  @Get()
  findAllV2() { /* new shape */ }
}
```

**When to version:**
- Response shape changes that break existing clients
- Endpoint behavior changes (different default sort, different included fields)
- Removed fields or changed field types

**When NOT to version:**
- Adding new optional fields to a response
- Adding new endpoints
- Bug fixes

---

## Response Envelope

Wrap successful responses in a consistent envelope so clients can rely on the shape:

```ts
// common/interceptors/transform-response.interceptor.ts
import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { Observable, map } from 'rxjs';

export interface ApiResponse<T> {
  data: T;
  meta?: Record<string, unknown>;
  timestamp: string;
  path: string;
}

@Injectable()
export class TransformResponseInterceptor<T> implements NestInterceptor<T, ApiResponse<T>> {
  intercept(context: ExecutionContext, next: CallHandler): Observable<ApiResponse<T>> {
    const request = context.switchToHttp().getRequest();

    return next.handle().pipe(
      map((body) => {
        // Paginated responses already have data + meta — preserve them
        if (body && typeof body === 'object' && 'data' in body && 'meta' in body) {
          return { ...body, timestamp: new Date().toISOString(), path: request.url };
        }

        return {
          data: body,
          timestamp: new Date().toISOString(),
          path: request.url,
        };
      }),
    );
  }
}
```

Register in `main.ts`:

```ts
app.useGlobalInterceptors(new TransformResponseInterceptor());
```

---

## Correlation IDs

Assign a unique ID to every request for end-to-end tracing across services and logs.

```ts
// common/middleware/correlation-id.middleware.ts
import { Injectable, NestMiddleware } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import type { Request, Response, NextFunction } from 'express';

export const CORRELATION_ID_HEADER = 'x-request-id';

@Injectable()
export class CorrelationIdMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    const id = (req.headers[CORRELATION_ID_HEADER] as string) || randomUUID();
    req.headers[CORRELATION_ID_HEADER] = id;
    res.setHeader(CORRELATION_ID_HEADER, id);
    next();
  }
}

// app.module.ts
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(CorrelationIdMiddleware).forRoutes('*');
  }
}
```

The correlation ID flows through:
1. Middleware assigns it
2. Logging interceptor includes it in every log line
3. Error filter includes it in Problem Details responses
4. Frontend can display it in error messages for support tickets

---

## Request Logging

Structured JSON logging for every request — essential for log aggregation:

```ts
// common/interceptors/logging.interceptor.ts
import {
  CallHandler, ExecutionContext, Injectable, Logger, NestInterceptor,
} from '@nestjs/common';
import { Observable, tap } from 'rxjs';
import { CORRELATION_ID_HEADER } from '../middleware/correlation-id.middleware';

@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger('HTTP');

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context.switchToHttp().getRequest();
    const { method, url, ip } = request;
    const correlationId = request.headers[CORRELATION_ID_HEADER];
    const userId = request.user?.id ?? 'anonymous';
    const startTime = Date.now();

    return next.handle().pipe(
      tap({
        next: () => {
          const response = context.switchToHttp().getResponse();
          const duration = Date.now() - startTime;
          this.logger.log(
            JSON.stringify({
              correlationId, method, url,
              statusCode: response.statusCode,
              duration: `${duration}ms`,
              userId, ip,
            }),
          );
        },
        error: (error) => {
          const duration = Date.now() - startTime;
          this.logger.error(
            JSON.stringify({
              correlationId, method, url,
              statusCode: error.status ?? 500,
              duration: `${duration}ms`,
              userId, ip,
              error: error.message,
            }),
          );
        },
      }),
    );
  }
}
```

### main.ts Assembly Order

Interceptors execute in registration order — outermost first:

```ts
app.useGlobalInterceptors(
  new LoggingInterceptor(),        // 1. Log the request
  new SanitizeInterceptor(),       // 2. Clean input
  new TransformResponseInterceptor(), // 3. Wrap response
);
```
