---
title: Caching and Redis
weight: 5
---

# Caching and Redis

This reference covers Redis setup, caching patterns, cache invalidation, and TTL strategies for the NestJS backend.

## Table of Contents

- [Setup](#setup)
- [Cache-Aside Pattern](#cache-aside-pattern)
- [Per-Route Caching](#per-route-caching)
- [Cache Invalidation](#cache-invalidation)
- [Key Conventions](#key-conventions)
- [TTL Strategy](#ttl-strategy)
- [Docker Compose](#docker-compose)

---

## Setup

### Packages

```bash
pnpm add @nestjs/cache-manager cache-manager cache-manager-redis-yet
```

`cache-manager` v5+ with `cache-manager-redis-yet` (wraps `node-redis` v4) is the current recommended stack. The older `cache-manager-redis-store` is deprecated.

### Module Registration

```ts
// infrastructure/cache/cache.module.ts
import { CacheModule } from '@nestjs/cache-manager';
import { redisStore } from 'cache-manager-redis-yet';
import { ConfigService } from '@nestjs/config';

@Module({
  imports: [
    CacheModule.registerAsync({
      isGlobal: true,
      inject: [ConfigService],
      useFactory: async (config: ConfigService) => ({
        store: await redisStore({
          socket: {
            host: config.getOrThrow('REDIS_HOST'),
            port: config.getOrThrow<number>('REDIS_PORT'),
          },
          password: config.get('REDIS_PASSWORD'),
          ttl: 60_000, // default TTL in ms (cache-manager v5 uses ms)
        }),
      }),
    }),
  ],
})
export class InfrastructureCacheModule {}
```

### Environment Variables

```dotenv
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
```

---

## Cache-Aside Pattern

Prefer explicit service-level caching over route-level interceptors. It gives you control over what gets cached and when it's invalidated.

```ts
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { Cache } from 'cache-manager';

@Injectable()
export class ProductsService {
  constructor(
    @Inject(CACHE_MANAGER) private cache: Cache,
    private prisma: PrismaService,
  ) {}

  async findById(id: string): Promise<Product> {
    const cacheKey = `product:${id}`;
    const cached = await this.cache.get<Product>(cacheKey);
    if (cached) return cached;

    const product = await this.prisma.product.findUniqueOrThrow({ where: { id } });
    await this.cache.set(cacheKey, product, 300_000); // 5 min
    return product;
  }

  async update(id: string, dto: UpdateProductDto): Promise<Product> {
    const product = await this.prisma.product.update({ where: { id }, data: dto });

    // Invalidate item cache AND related list caches
    await Promise.all([
      this.cache.del(`product:${id}`),
      this.invalidateListCaches(),
    ]);

    return product;
  }

  private async invalidateListCaches() {
    // Pattern-based deletion via the underlying Redis client
    const client = (this.cache as any).store.client;
    let cursor = 0;
    do {
      const result = await client.scan(cursor, { MATCH: 'products:list:*', COUNT: 100 });
      cursor = result.cursor;
      if (result.keys.length) await client.del(result.keys);
    } while (cursor !== 0);
  }
}
```

---

## Per-Route Caching

Only suitable for pure GET endpoints where the response is the same for all users.

```ts
import { CacheInterceptor, CacheTTL, CacheKey } from '@nestjs/cache-manager';

@Controller('categories')
@UseInterceptors(CacheInterceptor)
export class CategoriesController {
  @Get()
  @CacheTTL(600_000) // 10 min
  @CacheKey('categories:all')
  findAll() {
    return this.categoriesService.findAll();
  }
}
```

### User-Aware Cache Keys

For endpoints that return per-user data, override the key generation:

```ts
@Injectable()
export class UserAwareCacheInterceptor extends CacheInterceptor {
  trackBy(context: ExecutionContext): string | undefined {
    const request = context.switchToHttp().getRequest();
    const userId = request.user?.id ?? 'anon';
    const url = request.originalUrl;
    return `http:${userId}:${url}`;
  }
}
```

---

## Cache Invalidation

### Strategies

| Strategy | When to use |
|----------|-------------|
| **TTL-based** | Data that's OK to be slightly stale (categories, settings) |
| **Write-through** | Invalidate on every write — most common for CRUD |
| **Event-driven** | Invalidate via pub/sub when other services change the data |

### Write-Through Pattern

On every create/update/delete, invalidate both the item and any list caches:

```ts
async create(dto: CreateProductDto): Promise<Product> {
  const product = await this.prisma.product.create({ data: dto });
  await this.cache.del('products:list:*'); // pattern invalidation
  return product;
}

async delete(id: string): Promise<void> {
  await this.prisma.product.delete({ where: { id } });
  await Promise.all([
    this.cache.del(`product:${id}`),
    this.invalidateListCaches(),
  ]);
}
```

---

## Key Conventions

Use a consistent hierarchical scheme:

```
{entity}:{id}                      → product:abc123
{entity}:list:{hash-of-filters}    → products:list:sha256(JSON.stringify(filters))
{entity}:{id}:{relation}           → product:abc123:reviews
user:{id}:session                  → user:def456:session
```

For list cache keys with dynamic filters, hash the filter parameters:

```ts
import { createHash } from 'node:crypto';

function listCacheKey(entity: string, filters: Record<string, unknown>): string {
  const hash = createHash('sha256')
    .update(JSON.stringify(filters))
    .digest('hex')
    .slice(0, 12);
  return `${entity}:list:${hash}`;
}
```

---

## TTL Strategy

| Data type | TTL | Rationale |
|-----------|-----|-----------|
| Reference/lookup data (roles, categories) | 1-24 hours | Rarely changes |
| Entity by ID | 5-15 minutes | Balance freshness vs DB load |
| List/search results | 1-5 minutes | Aggregates stale faster |
| User session data | Match session expiry | Security boundary |
| Rate limit counters | Exact window size | Functional requirement |
| Computed aggregations (dashboards) | 30-60 seconds | Expensive to compute, OK to be briefly stale |

---

## Docker Compose

Add Redis to the dev stack:

```yaml
# infrastructure/docker-compose.yml
services:
  redis:
    image: redis:7-alpine
    ports:
      - '6379:6379'
    volumes:
      - redis_data:/data
    healthcheck:
      test: ['CMD', 'redis-cli', 'ping']
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  redis_data:
```

### Production Considerations

- **Separate Redis instances**: Use one for cache (volatile, `maxmemory-policy allkeys-lru`) and another for queues (persistent, AOF enabled). Cache data can be evicted; queue data cannot.
- **Redis Cluster**: For high availability, use Redis Cluster or AWS ElastiCache with failover.
- **Connection pooling**: Redis is single-threaded; more connections doesn't mean more throughput. Keep the pool small (5-20 connections per app instance).
