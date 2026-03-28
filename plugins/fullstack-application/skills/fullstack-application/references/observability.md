---
title: Observability and Monitoring
weight: 9
---

# Observability and Monitoring

This reference covers structured logging, error tracking, health checks, distributed tracing, metrics, and feature flags.

## Table of Contents

- [Structured Logging with Pino](#structured-logging-with-pino)
- [Error Tracking with Sentry](#error-tracking-with-sentry)
- [Health Checks](#health-checks)
- [OpenTelemetry](#opentelemetry)
- [Prometheus Metrics](#prometheus-metrics)
- [Feature Flags](#feature-flags)

---

## Structured Logging with Pino

Pino is preferred over Winston — it's faster, outputs JSON natively, and integrates cleanly with log aggregation.

```bash
pnpm add nestjs-pino pino-http
pnpm add -D pino-pretty
```

```ts
// common/logger/logger.module.ts
import { LoggerModule as PinoLoggerModule } from 'nestjs-pino';

@Module({
  imports: [
    PinoLoggerModule.forRoot({
      pinoHttp: {
        level: process.env.LOG_LEVEL || 'info',
        transport: process.env.NODE_ENV !== 'production'
          ? { target: 'pino-pretty', options: { colorize: true } }
          : undefined,
        genReqId: (req) => req.headers['x-correlation-id']?.toString() || randomUUID(),
        redact: {
          paths: [
            'req.headers.authorization',
            'req.headers.cookie',
            'body.password',
            'body.token',
          ],
          censor: '[REDACTED]',
        },
        customProps: () => ({
          service: 'my-api',
          environment: process.env.NODE_ENV,
          version: process.env.APP_VERSION || 'unknown',
        }),
      },
    }),
  ],
})
export class LoggerModule {}
```

**Key points:**
- `redact` automatically masks sensitive fields — prevents PII/secrets in logs
- `genReqId` uses the correlation ID from the middleware
- In development, `pino-pretty` makes logs readable; in production, raw JSON is sent to the aggregation pipeline

---

## Error Tracking with Sentry

### Backend

```bash
pnpm add @sentry/node @sentry/profiling-node
```

```ts
// common/sentry/sentry.module.ts
import * as Sentry from '@sentry/node';

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  release: `my-api@${process.env.APP_VERSION}`,
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  beforeSend(event) {
    if (event.request?.headers) {
      delete event.request.headers['authorization'];
      delete event.request.headers['cookie'];
    }
    return event;
  },
  ignoreErrors: ['NotFoundException', 'UnauthorizedException'],
});
```

Exception filter — only report 5xx errors:

```ts
@Catch()
export class SentryExceptionFilter extends BaseExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const status = exception instanceof HttpException
      ? exception.getStatus()
      : HttpStatus.INTERNAL_SERVER_ERROR;

    if (status >= 500) {
      Sentry.withScope((scope) => {
        const request = host.switchToHttp().getRequest();
        scope.setTag('correlation_id', request.headers['x-correlation-id']);
        if (request.user) scope.setUser({ id: request.user.id });
        Sentry.captureException(exception);
      });
    }

    super.catch(exception, host);
  }
}
```

### Frontend

```bash
pnpm add @sentry/react @sentry/vite-plugin
```

```ts
// sentry.ts
import * as Sentry from '@sentry/react';

Sentry.init({
  dsn: import.meta.env.VITE_SENTRY_DSN,
  environment: import.meta.env.MODE,
  release: `my-frontend@${import.meta.env.VITE_APP_VERSION}`,
  integrations: [
    Sentry.browserTracingIntegration(),
    Sentry.replayIntegration({ maskAllText: false, blockAllMedia: false }),
  ],
  tracesSampleRate: import.meta.env.PROD ? 0.1 : 1.0,
  replaysOnErrorSampleRate: 1.0,
});
```

### Source Maps

Upload source maps to Sentry during build, then delete them so they're never served publicly:

```ts
// vite.config.ts
import { sentryVitePlugin } from '@sentry/vite-plugin';

export default defineConfig({
  build: { sourcemap: true },
  plugins: [
    sentryVitePlugin({
      org: process.env.SENTRY_ORG,
      project: process.env.SENTRY_PROJECT,
      authToken: process.env.SENTRY_AUTH_TOKEN,
      sourcemaps: {
        filesToDeleteAfterUpload: '**/*.map',
      },
    }),
  ],
});
```

---

## Health Checks

Use `@nestjs/terminus` for production health checks. Separate liveness (fast, for load balancer) from readiness (deep, probes all dependencies).

```bash
pnpm add @nestjs/terminus
```

```ts
@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: PrismaHealthIndicator,
    private memory: MemoryHealthIndicator,
    private redis: RedisHealthIndicator,
  ) {}

  // Fast — for load balancer / K8s liveness probe
  @Get()
  @HealthCheck()
  liveness() {
    return this.health.check([
      () => this.memory.checkHeap('memory_heap', 256 * 1024 * 1024),
    ]);
  }

  // Deep — for monitoring / K8s readiness probe
  @Get('ready')
  @HealthCheck()
  readiness() {
    return this.health.check([
      () => this.db.pingCheck('database', { timeout: 1500 }),
      () => this.redis.isHealthy('redis'),
      () => this.memory.checkHeap('memory_heap', 256 * 1024 * 1024),
    ]);
  }
}
```

### Custom Redis Health Indicator

```ts
@Injectable()
export class RedisHealthIndicator extends HealthIndicator {
  constructor(@Inject(CACHE_MANAGER) private cache: Cache) { super(); }

  async isHealthy(key: string): Promise<HealthIndicatorResult> {
    try {
      const start = Date.now();
      await (this.cache as any).store.client.ping();
      return this.getStatus(key, true, { latency_ms: Date.now() - start });
    } catch (error) {
      throw new HealthCheckError('Redis check failed',
        this.getStatus(key, false, { message: error.message }));
    }
  }
}
```

---

## OpenTelemetry

Initialize before any other imports. Auto-instruments HTTP, Prisma, and Redis.

```bash
pnpm add @opentelemetry/sdk-node @opentelemetry/auto-instrumentations-node \
  @opentelemetry/exporter-trace-otlp-http @opentelemetry/exporter-metrics-otlp-http
```

```ts
// tracing.ts — import FIRST in main.ts
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { Resource } from '@opentelemetry/resources';
import { ATTR_SERVICE_NAME } from '@opentelemetry/semantic-conventions';

const sdk = new NodeSDK({
  resource: new Resource({ [ATTR_SERVICE_NAME]: 'my-api' }),
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318/v1/traces',
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-http': {
        ignoreIncomingRequestHook: (req) => req.url?.startsWith('/health') ?? false,
      },
      '@opentelemetry/instrumentation-fs': { enabled: false },
    }),
  ],
});

sdk.start();
process.on('SIGTERM', () => sdk.shutdown());
```

```ts
// main.ts
import './tracing'; // MUST be first
import { NestFactory } from '@nestjs/core';
```

---

## Prometheus Metrics

```bash
pnpm add @willsoto/nestjs-prometheus prom-client
```

```ts
// common/metrics/metrics.module.ts
import { PrometheusModule, makeCounterProvider, makeHistogramProvider } from '@willsoto/nestjs-prometheus';

@Global()
@Module({
  imports: [PrometheusModule.register({ path: '/metrics' })],
  providers: [
    makeCounterProvider({
      name: 'http_requests_total',
      help: 'Total HTTP requests',
      labelNames: ['method', 'path', 'status'],
    }),
    makeHistogramProvider({
      name: 'http_request_duration_seconds',
      help: 'HTTP request duration',
      labelNames: ['method', 'path', 'status'],
      buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
    }),
  ],
  exports: [PrometheusModule],
})
export class MetricsModule {}
```

Use route patterns (not actual URLs) in labels to avoid high cardinality.

---

## Feature Flags

Simple, code-defined feature flags without an external service. Supports boolean, environment-based, percentage rollout, and allowlists.

```ts
// common/feature-flags/feature-flags.ts
export const FLAGS = {
  NEW_DASHBOARD: {
    description: 'Redesigned dashboard UI',
    environments: ['development', 'staging'],
    percentageRollout: 20,
  },
  BULK_EXPORT: {
    description: 'Bulk CSV export',
    enabled: true,
  },
  MAINTENANCE_MODE: {
    description: 'Show maintenance banner',
    enabled: false,
  },
} as const satisfies Record<string, FeatureFlagDefinition>;
```

```ts
// common/feature-flags/feature-flag.service.ts
@Injectable()
export class FeatureFlagService {
  isEnabled(flag: FeatureFlagName, context?: { userId?: string }): boolean {
    // Priority: env var override > hard on/off > environment check > allowlist > percentage rollout
    const envOverride = process.env[`FEATURE_${flag}`];
    if (envOverride === 'true') return true;
    if (envOverride === 'false') return false;

    const def = FLAGS[flag];
    if (typeof def.enabled === 'boolean') return def.enabled;
    if (def.environments && !def.environments.includes(process.env.NODE_ENV)) return false;
    if (def.allowlist?.includes(context?.userId)) return true;

    if (typeof def.percentageRollout === 'number' && context?.userId) {
      // Consistent hash: same user+flag always gets the same result
      const hash = createHash('sha256').update(`${flag}:${context.userId}`).digest();
      return hash.readUInt32BE(0) % 100 < def.percentageRollout;
    }

    return def.environments?.includes(process.env.NODE_ENV) ?? false;
  }
}
```

### Guard for Feature-Gated Endpoints

```ts
@Post('export')
@RequireFeature('BULK_EXPORT')
@UseGuards(FeatureFlagGuard)
async bulkExport() { /* ... */ }
```

### React Hook

```ts
export function useFeatureFlag(flag: string): boolean {
  const flags = useContext(FlagsContext);
  return flags[flag] ?? false;
}

// Usage:
const showNewDashboard = useFeatureFlag('NEW_DASHBOARD');
```

Fetch flags from `GET /flags` endpoint, cache for 5 minutes, refetch on window focus.
