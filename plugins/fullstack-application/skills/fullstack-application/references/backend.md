# Backend

## Stack

- **Framework**: NestJS
- **ORM**: Prisma
- **Database**: PostgreSQL
- **Auth**: Passport.js + Google OAuth 2.0 + JWT refresh tokens (`@nestjs/jwt`)
- **API Docs**: Swagger / OpenAPI via `@nestjs/swagger`
- **Validation**: `class-validator` + `class-transformer`

## Critical NestJS + pnpm Notes

These are common issues that cause compilation failures in pnpm monorepos with NestJS:

1. **Always include `@nestjs/jwt` in dependencies** — it's required for `JwtService` and `JwtModule` but easy to forget since auth code references it indirectly.

2. **Use `require()` for CJS middleware packages** — NestJS uses CommonJS modules. Packages like `helmet` and `cookie-parser` don't work with `import X from 'Y'` or `import * as X from 'Y'` in CommonJS mode. Use `const helmet = require('helmet');` instead.

3. **Import Prisma types from the workspace database package** — Use `import type { Prisma } from '@myapp/database'` instead of `import type { Prisma } from '@prisma/client'`. In pnpm's strict node_modules, `@prisma/client` may not resolve correctly from `apps/api`.

4. **ConfigModule needs an explicit `envFilePath`** — When `nest start` runs, the CWD is `apps/api`, not the monorepo root. ConfigModule won't find the root `.env` file. Always set:
   ```ts
   ConfigModule.forRoot({
     isGlobal: true,
     envFilePath: join(__dirname, '..', '..', '..', '.env'),
     validationSchema: envValidationSchema,
   })
   ```

5. **Version-match `@nestjs/swagger` to your NestJS major** — NestJS 11 requires `@nestjs/swagger@^11.0.0`, not `^8.x`. Mismatched versions cause unmet peer dependency errors.
- **Language**: TypeScript strict

---

## Module Structure

Every feature is a self-contained NestJS module. The controller is thin (routing + validation only), the service holds business logic, and Prisma is injected via the `DatabaseModule`.

```
modules/posts/
├── dto/
│   ├── create-post.dto.ts
│   └── update-post.dto.ts
├── posts.controller.ts
├── posts.service.ts
├── posts.module.ts
└── posts.service.spec.ts
```

### Module

```ts
// posts.module.ts
import { Module } from '@nestjs/common';
import { PostsController } from './posts.controller';
import { PostsService } from './posts.service';

@Module({
  controllers: [PostsController],
  providers: [PostsService],
})
export class PostsModule {}
```

### Controller

Controllers handle routing, DTO extraction, and Swagger documentation only:

```ts
// posts.controller.ts
import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '@/auth/guards/jwt-auth.guard';
import { CurrentUser } from '@/auth/decorators/current-user.decorator';
import type { User } from '@myapp/shared';
import { CreatePostDto } from './dto/create-post.dto';
import { UpdatePostDto } from './dto/update-post.dto';
import { PostsService } from './posts.service';

@ApiTags('Posts')
@UseGuards(JwtAuthGuard)
@Controller('posts')
export class PostsController {
  constructor(private readonly postsService: PostsService) {}

  @Post()
  @ApiOperation({ summary: 'Create a post' })
  @ApiResponse({ status: 201, description: 'Post created successfully' })
  create(@Body() dto: CreatePostDto, @CurrentUser() user: User) {
    return this.postsService.create(dto, user.id);
  }

  @Get()
  @ApiOperation({ summary: 'List all posts for the current user' })
  findAll(@CurrentUser() user: User) {
    return this.postsService.findAll(user.id);
  }

  @Get(':id')
  findOne(@Param('id') id: string, @CurrentUser() user: User) {
    return this.postsService.findOneOrThrow(id, user.id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdatePostDto, @CurrentUser() user: User) {
    return this.postsService.update(id, dto, user.id);
  }

  @Delete(':id')
  @ApiResponse({ status: 204 })
  remove(@Param('id') id: string, @CurrentUser() user: User) {
    return this.postsService.remove(id, user.id);
  }
}
```

### Service

Services contain all business logic. They interact with Prisma directly (no separate repository class unless the logic warrants it):

```ts
// posts.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '@/database/prisma.service';
import type { CreatePostDto, UpdatePostDto } from './dto';

@Injectable()
export class PostsService {
  constructor(private readonly prisma: PrismaService) {}

  create(dto: CreatePostDto, userId: string) {
    return this.prisma.post.create({
      data: { ...dto, userId },
    });
  }

  findAll(userId: string) {
    return this.prisma.post.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOneOrThrow(id: string, userId: string) {
    const post = await this.prisma.post.findFirst({ where: { id, userId } });
    if (!post) throw new NotFoundException(`Post ${id} not found`);
    return post;
  }

  async update(id: string, dto: UpdatePostDto, userId: string) {
    await this.findOneOrThrow(id, userId);
    return this.prisma.post.update({ where: { id }, data: dto });
  }

  async remove(id: string, userId: string) {
    await this.findOneOrThrow(id, userId);
    return this.prisma.post.delete({ where: { id } });
  }
}
```

---

## DTOs

Use `class-validator` for validation and `@nestjs/swagger` decorators for docs. Define request DTOs in the feature's `dto/` directory; share response types via `packages/shared`.

```ts
// dto/create-post.dto.ts
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreatePostDto {
  @ApiProperty({ description: 'Post title', maxLength: 255 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  title: string;

  @ApiPropertyOptional({ description: 'Post body content' })
  @IsString()
  @IsOptional()
  body?: string;
}
```

Enable the global validation pipe in `main.ts`:

```ts
app.useGlobalPipes(
  new ValidationPipe({
    whitelist: true,          // strip unknown properties
    forbidNonWhitelisted: true,
    transform: true,          // auto-transform payloads to DTO instances
    transformOptions: { enableImplicitConversion: true },
  }),
);
```

---

## Prisma

### PrismaService

Wrap the Prisma client in a NestJS service, available as a global module:

```ts
// src/database/prisma.service.ts
import { Injectable, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@myapp/database';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  async onModuleInit() {
    await this.$connect();
  }
}
```

```ts
// src/database/database.module.ts
import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class DatabaseModule {}
```

### Schema Conventions

```prisma
// packages/database/prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id           String    @id @default(cuid())
  email        String    @unique
  name         String?
  picture      String?
  googleId     String?   @unique
  accessToken  String?
  refreshToken String?
  createdAt    DateTime  @default(now())
  updatedAt    DateTime  @updatedAt

  posts Post[]

  @@map("users")
}

model Post {
  id        String   @id @default(cuid())
  title     String
  body      String?
  userId    String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@map("posts")
}
```

**Rules:**
- Always use `cuid()` for primary keys
- Always include `createdAt` and `updatedAt`
- Use `@@map()` to keep table names lowercase snake_case
- Every migration must be named descriptively: `prisma migrate dev --name add_post_table`
- Never edit a migration file after it has been applied

---

## Auth (Passport + Google OAuth + JWT)

### Strategy

```ts
// auth/strategies/google.strategy.ts
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy, type VerifyCallback, type Profile } from 'passport-google-oauth20';
import { AuthService } from '../auth.service';

@Injectable()
export class GoogleStrategy extends PassportStrategy(Strategy, 'google') {
  constructor(
    private readonly configService: ConfigService,
    private readonly authService: AuthService,
  ) {
    super({
      clientID: configService.getOrThrow('GOOGLE_CLIENT_ID'),
      clientSecret: configService.getOrThrow('GOOGLE_CLIENT_SECRET'),
      callbackURL: configService.getOrThrow('GOOGLE_CALLBACK_URL'),
      scope: ['email', 'profile'],
    });
  }

  async validate(
    accessToken: string,
    refreshToken: string,
    profile: Profile,
    done: VerifyCallback,
  ) {
    const user = await this.authService.findOrCreateFromGoogle(profile, accessToken);
    done(null, user);
  }
}
```

### Auth Controller

The access token is returned as JSON. The refresh token is set as an **HttpOnly, Secure, SameSite=Strict cookie** — never as a JSON response body. This makes it immune to XSS (JavaScript cannot read it).

```ts
// auth/auth.controller.ts
import { Controller, Get, Post, Req, Res, UseGuards, UnauthorizedException } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import type { Request, Response } from 'express';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { JwtRefreshGuard } from './guards/jwt-refresh.guard';
import { CurrentUser } from './decorators/current-user.decorator';
import type { User } from '@myapp/shared';

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly configService: ConfigService,
  ) {}

  @Get('google')
  @UseGuards(AuthGuard('google'))
  @ApiOperation({ summary: 'Redirect to Google OAuth' })
  googleLogin() {
    // Passport handles the redirect
  }

  @Get('google/callback')
  @UseGuards(AuthGuard('google'))
  @ApiOperation({ summary: 'Google OAuth callback' })
  async googleCallback(@Req() req: Request, @Res() res: Response) {
    const tokens = await this.authService.generateTokens(req.user as User);
    this.setRefreshTokenCookie(res, tokens.refreshToken);

    const frontendUrl = this.configService.getOrThrow('FRONTEND_URL');
    // Pass only the short-lived access token in the URL; the refresh token is in the cookie
    res.redirect(`${frontendUrl}/auth/callback?token=${tokens.accessToken}`);
  }

  @Post('refresh')
  @UseGuards(JwtRefreshGuard)   // Extracts refresh token from cookie
  @ApiOperation({ summary: 'Rotate access and refresh tokens' })
  async refresh(@Req() req: Request, @Res() res: Response) {
    const tokens = await this.authService.rotateTokens(req.user as User);
    this.setRefreshTokenCookie(res, tokens.refreshToken);
    return res.json({ accessToken: tokens.accessToken });
  }

  @Post('logout')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Invalidate refresh token and clear cookie' })
  async logout(@Req() req: Request, @Res() res: Response, @CurrentUser() user: User) {
    await this.authService.revokeRefreshToken(user.id);
    res.clearCookie('refresh_token');
    return res.json({ message: 'Logged out' });
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Get current authenticated user' })
  getMe(@CurrentUser() user: User) {
    return user;
  }

  private setRefreshTokenCookie(res: Response, token: string) {
    res.cookie('refresh_token', token, {
      httpOnly: true,
      secure: this.configService.get('NODE_ENV') === 'production',
      sameSite: 'strict',
      maxAge: 30 * 24 * 60 * 60 * 1000,  // 30 days in ms
      path: '/api/auth',                  // Restrict cookie scope to auth endpoints
    });
  }
}
```

**Refresh token strategy** — extracts token from cookie, not the Authorization header:

```ts
// auth/strategies/jwt-refresh.strategy.ts
@Injectable()
export class JwtRefreshStrategy extends PassportStrategy(Strategy, 'jwt-refresh') {
  constructor(
    private readonly configService: ConfigService,
    private readonly authService: AuthService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromExtractors([
        (req: Request) => req?.cookies?.['refresh_token'] ?? null,
      ]),
      secretOrKey: configService.getOrThrow('JWT_REFRESH_SECRET'),
      passReqToCallback: true,
    });
  }

  async validate(req: Request, payload: { sub: string }) {
    const refreshToken = req.cookies['refresh_token'];
    // Verify the stored token hash matches — detects reuse of revoked tokens
    return this.authService.validateRefreshToken(payload.sub, refreshToken);
  }
}
```

**Token rotation**: Every `/auth/refresh` call issues a new access token + refresh token and invalidates the old refresh token (store a hash in the DB, not the token itself). If a revoked refresh token is used, treat it as a breach and revoke all sessions for that user.

### Adding More OAuth Providers

To add a new provider (e.g., GitHub):
1. Install `passport-github2`
2. Create `auth/strategies/github.strategy.ts` mirroring the Google strategy
3. Add `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, `GITHUB_CALLBACK_URL` to env
4. Add a `GET /auth/github` and `GET /auth/github/callback` route
5. `AuthService.findOrCreateFromGithub()` follows the same upsert pattern

---

## Swagger Setup

Bootstrap Swagger in `main.ts`:

```ts
// main.ts
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.setGlobalPrefix('api');
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.enableCors({
    origin: process.env.FRONTEND_URL,
    credentials: true,
  });

  const config = new DocumentBuilder()
    .setTitle('My App API')
    .setDescription('API documentation')
    .setVersion('1.0')
    .addBearerAuth()
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  await app.listen(process.env.API_PORT ?? 3001);
}

bootstrap();
```

Every controller and DTO must have Swagger decorators. Minimum requirements:
- `@ApiTags()` on the controller class
- `@ApiOperation({ summary })` on each endpoint
- `@ApiResponse` for non-200 responses
- `@ApiProperty()` on every DTO field
- `@ApiBearerAuth()` on protected controllers

---

## Health Check

```ts
// health/health.controller.ts
import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';

@ApiTags('Health')
@Controller('health')
export class HealthController {
  @Get()
  @ApiOperation({ summary: 'Health check' })
  check() {
    return { status: 'ok', timestamp: new Date().toISOString() };
  }
}
```

The health endpoint must be public (excluded from `JwtAuthGuard`) and must be the path used for Docker and K8s health checks.
