---
title: Security Hardening
weight: 2
---

# Security Hardening

This reference covers security measures beyond authentication. Auth (Passport, OAuth, JWT) is in `backend.md` — this file covers everything else: headers, CORS, rate limiting, CSRF, input sanitization, and defense-in-depth patterns.

## Table of Contents

- [Security Headers with Helmet](#security-headers-with-helmet)
- [CORS Configuration](#cors-configuration)
- [Rate Limiting](#rate-limiting)
- [CSRF Protection](#csrf-protection)
- [Input Sanitization](#input-sanitization)
- [Authorization & Resource Access](#authorization--resource-access)
- [Dependency Security](#dependency-security)

---

## Security Headers with Helmet

Install `helmet` and apply it early in the middleware chain. Helmet sets HTTP headers that protect against clickjacking, MIME sniffing, XSS, and other common attacks.

```ts
// main.ts
import helmet from 'helmet';

app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", 'data:', 'https:'],
        connectSrc: ["'self'"],
        fontSrc: ["'self'"],
        objectSrc: ["'none'"],
        frameAncestors: ["'none'"],
      },
    },
    crossOriginEmbedderPolicy: true,
    crossOriginOpenerPolicy: { policy: 'same-origin' },
    crossOriginResourcePolicy: { policy: 'same-origin' },
    hsts: { maxAge: 63072000, includeSubDomains: true, preload: true },
    referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
  }),
);
```

Headers this sets:

| Header | Purpose |
|--------|---------|
| `Content-Security-Policy` | Restricts which resources the browser can load |
| `Strict-Transport-Security` | Forces HTTPS for 2 years, including subdomains |
| `X-Content-Type-Options: nosniff` | Prevents MIME type sniffing |
| `X-Frame-Options: DENY` | Blocks clickjacking via iframes |
| `Referrer-Policy` | Controls how much referrer info is sent |
| `Cross-Origin-*-Policy` | Isolates cross-origin resources |

Adjust the CSP `directives` based on what the app actually loads. If using Google Fonts, add the CDN to `fontSrc` and `styleSrc`. If using an analytics script, add it to `scriptSrc`. The tighter the CSP, the better.

---

## CORS Configuration

The basic `enableCors({ origin, credentials: true })` from `backend.md` is a starting point. Production apps need more control.

```ts
// main.ts
app.enableCors({
  origin: (origin, callback) => {
    const allowedOrigins = configService.get<string[]>('ALLOWED_ORIGINS');
    // Allow requests with no origin (mobile apps, curl, server-to-server)
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new ForbiddenException('Not allowed by CORS'));
    }
  },
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-ID'],
  exposedHeaders: ['X-Request-ID', 'X-RateLimit-Remaining'],
  credentials: true,
  maxAge: 3600, // cache preflight for 1 hour
});
```

**Environment configuration:**

```dotenv
# .env
ALLOWED_ORIGINS="http://localhost:5173"

# .env.production
ALLOWED_ORIGINS="https://myapp.com,https://www.myapp.com"
```

Parse as an array in the config validation:

```ts
// config/env.validation.ts
ALLOWED_ORIGINS: Joi.string().required().custom((value) => value.split(',')),
```

**Key points:**
- Never use `origin: '*'` with `credentials: true` — browsers reject it
- `exposedHeaders` controls which response headers JavaScript can read
- `maxAge` reduces preflight requests — set it high (3600s) in production
- Mobile apps and server-to-server requests send no `Origin` header — allow `!origin` for those

---

## Rate Limiting

Use `@nestjs/throttler` with multiple time windows. This protects against brute force, credential stuffing, and abuse.

### Global Setup

```ts
// app.module.ts
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';

@Module({
  imports: [
    ThrottlerModule.forRoot({
      throttlers: [
        { name: 'short', ttl: 1000, limit: 3 },      // 3 req/sec burst
        { name: 'medium', ttl: 10000, limit: 20 },    // 20 req/10sec
        { name: 'long', ttl: 60000, limit: 100 },     // 100 req/min
      ],
    }),
  ],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
  ],
})
export class AppModule {}
```

### Per-Route Overrides

Sensitive endpoints get tighter limits:

```ts
import { Throttle, SkipThrottle } from '@nestjs/throttler';

@Controller('auth')
export class AuthController {
  @Throttle({ short: { limit: 5, ttl: 60000 } })
  @Post('login')
  login() { /* ... */ }

  @Throttle({ short: { limit: 3, ttl: 60000 } })
  @Post('forgot-password')
  forgotPassword() { /* ... */ }

  @SkipThrottle()
  @Get('/health')
  health() { return { status: 'ok' }; }
}
```

### Per-User Throttling with Tiers

Override the default tracker to use the authenticated user's ID instead of IP, and apply tier multipliers:

```ts
// tiered-throttler.guard.ts
import { ThrottlerGuard } from '@nestjs/throttler';
import { Injectable, ExecutionContext } from '@nestjs/common';

@Injectable()
export class TieredThrottlerGuard extends ThrottlerGuard {
  protected async getTracker(req: Record<string, any>): Promise<string> {
    return req.user?.id ?? req.ip;
  }

  protected async handleRequest(requestProps: {
    context: ExecutionContext;
    limit: number;
    ttl: number;
    throttler: any;
    blockDuration: number;
  }): Promise<boolean> {
    const request = requestProps.context.switchToHttp().getRequest();
    const user = request.user;

    if (user) {
      const multipliers: Record<string, number> = {
        free: 1,
        pro: 5,
        enterprise: 20,
      };
      requestProps.limit *= multipliers[user.tier] ?? 1;
    }

    return super.handleRequest(requestProps);
  }
}
```

### Redis Store for Production

In-memory throttling resets on restart and doesn't work across multiple instances. Use Redis:

```ts
ThrottlerModule.forRoot({
  throttlers: [/* ... */],
  storage: new ThrottlerStorageRedisService(redisClient),
}),
```

---

## CSRF Protection

**When you need CSRF protection:** When mutation requests (POST, PUT, DELETE) are authenticated via cookies. Since our refresh token lives in an HttpOnly cookie, the `/auth/refresh` endpoint is vulnerable to CSRF without protection.

**When you don't need it:** Endpoints authenticated purely via the `Authorization: Bearer <token>` header are inherently CSRF-safe — browsers don't auto-attach custom headers cross-origin.

For the cookie-authenticated auth endpoints, use the double-submit cookie pattern:

```ts
// main.ts
import { doubleCsrf } from 'csrf-csrf';

const { generateToken, doubleCsrfProtection } = doubleCsrf({
  getSecret: () => configService.getOrThrow<string>('CSRF_SECRET'),
  cookieName: '__Host-csrf',
  cookieOptions: {
    httpOnly: true,
    sameSite: 'strict',
    secure: true,
    path: '/',
  },
  size: 64,
  getTokenFromRequest: (req) => req.headers['x-csrf-token'] as string,
});

app.use(cookieParser());
// Apply CSRF protection only to auth mutation routes
app.use('/api/auth', doubleCsrfProtection);
```

The frontend fetches a CSRF token and sends it with mutation requests:

```ts
// Frontend: fetch CSRF token on app init
const { data } = await fetch('/api/auth/csrf-token');
// Send it in subsequent requests
headers.set('X-CSRF-Token', data.token);
```

---

## Input Sanitization

`class-validator` checks shape and types. Sanitization strips dangerous content from values that pass validation — defense in depth.

### Global Sanitization Interceptor

```ts
// sanitize.interceptor.ts
import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { Observable } from 'rxjs';
import DOMPurify from 'isomorphic-dompurify';

@Injectable()
export class SanitizeInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context.switchToHttp().getRequest();
    if (request.body) {
      request.body = this.sanitize(request.body);
    }
    return next.handle();
  }

  private sanitize(obj: unknown): unknown {
    if (typeof obj === 'string') {
      return DOMPurify.sanitize(obj, { ALLOWED_TAGS: [] });
    }
    if (Array.isArray(obj)) {
      return obj.map((item) => this.sanitize(item));
    }
    if (obj !== null && typeof obj === 'object') {
      const sanitized: Record<string, unknown> = {};
      for (const [key, value] of Object.entries(obj)) {
        sanitized[key] = this.sanitize(value);
      }
      return sanitized;
    }
    return obj;
  }
}
```

Register globally:

```ts
app.useGlobalInterceptors(new SanitizeInterceptor());
```

**When to allow HTML:** If a field legitimately contains rich text (a blog post body), use `DOMPurify.sanitize(value)` without `{ ALLOWED_TAGS: [] }` — it strips dangerous tags (`<script>`, `<iframe>`, event handlers) while preserving safe formatting (`<p>`, `<strong>`, `<em>`). Apply this selectively via a decorator, not globally.

### Prisma and SQL Injection

Prisma uses parameterized queries by default — standard CRUD operations are safe. The risk comes from raw queries:

```ts
// Safe — parameterized
await this.prisma.$queryRaw`SELECT * FROM users WHERE email = ${email}`;

// DANGEROUS — string interpolation
await this.prisma.$queryRawUnsafe(`SELECT * FROM users WHERE email = '${email}'`);
```

**Rule:** Never use `$queryRawUnsafe` with user input. If you must use raw SQL, always use tagged template literals with `$queryRaw`.

---

## Authorization & Resource Access

The auth module provides identity (who is this user). Authorization controls what they can do.

### Resource Ownership Guard

Most endpoints need to verify the user owns the resource they're accessing:

```ts
// The service layer handles ownership checks — not a separate guard
async findOneOrThrow(id: string, userId: string) {
  const post = await this.prisma.post.findFirst({
    where: { id, userId },
  });
  if (!post) throw new NotFoundException(`Post ${id} not found`);
  return post;
}
```

Always filter by `userId` in the `where` clause rather than fetching first and comparing. This is simpler, faster, and avoids leaking whether the resource exists to unauthorized users (they get 404, not 403).

### Role-Based Access Control

```ts
// roles.decorator.ts
import { SetMetadata } from '@nestjs/common';

export const ROLES_KEY = 'roles';
export const Roles = (...roles: string[]) => SetMetadata(ROLES_KEY, roles);

// roles.guard.ts
import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!requiredRoles) return true;

    const { user } = context.switchToHttp().getRequest();
    return requiredRoles.some((role) => user.roles?.includes(role));
  }
}

// Usage:
@Roles('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Delete('users/:id')
removeUser(@Param('id') id: string) { /* ... */ }
```

---

## Dependency Security

### Automated Vulnerability Scanning

Add to CI:

```yaml
# In ci.yml
- name: Audit dependencies
  run: pnpm audit --audit-level=high
```

### Dependabot / Renovate

Enable Dependabot for automated security updates:

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: npm
    directory: /
    schedule:
      interval: weekly
    open-pull-requests-limit: 10
    groups:
      production-dependencies:
        dependency-type: production
      development-dependencies:
        dependency-type: development
        update-types: [minor, patch]
```

### Lock File Integrity

Always commit `pnpm-lock.yaml`. In CI, use `pnpm install --frozen-lockfile` — this fails if the lock file is out of sync, preventing supply chain attacks from modified `package.json` ranges.
