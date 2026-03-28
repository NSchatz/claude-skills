---
title: Background Jobs and Queues
weight: 6
---

# Background Jobs and Queues

This reference covers BullMQ for asynchronous job processing: email delivery, media processing, scheduled tasks, and queue monitoring.

## Table of Contents

- [Setup](#setup)
- [Producer Pattern](#producer-pattern)
- [Processor Pattern](#processor-pattern)
- [Retry and Dead Letter Queues](#retry-and-dead-letter-queues)
- [Scheduled Jobs](#scheduled-jobs)
- [Queue Monitoring](#queue-monitoring)
- [Patterns](#patterns)
- [Separate Worker Process](#separate-worker-process)

---

## Setup

### Packages

```bash
pnpm add @nestjs/bullmq bullmq
```

BullMQ is the successor to Bull. Use `@nestjs/bullmq` (not `@nestjs/bull`).

### Module Registration

```ts
// infrastructure/queue/queue.module.ts
import { BullModule } from '@nestjs/bullmq';

@Module({
  imports: [
    BullModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        connection: {
          host: config.getOrThrow('REDIS_HOST'),
          port: config.getOrThrow<number>('REDIS_PORT'),
          password: config.get('REDIS_PASSWORD'),
        },
        defaultJobOptions: {
          attempts: 3,
          backoff: { type: 'exponential', delay: 1000 },
          removeOnComplete: { age: 86400, count: 1000 },
          removeOnFail: { age: 604800, count: 5000 },
        },
      }),
    }),

    // Register queues
    BullModule.registerQueue(
      { name: 'email' },
      { name: 'media-processing' },
      { name: 'notifications' },
    ),
  ],
  exports: [BullModule],
})
export class QueueModule {}
```

---

## Producer Pattern

Services add jobs to queues. Keep the job payload minimal — store IDs, not full objects.

```ts
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

@Injectable()
export class AuthService {
  constructor(@InjectQueue('email') private emailQueue: Queue) {}

  async register(dto: RegisterDto) {
    const user = await this.usersService.create(dto);

    await this.emailQueue.add(
      'welcome-email',           // job name (routes to handler in processor)
      { userId: user.id, email: user.email },
      {
        priority: 1,             // lower number = higher priority
        delay: 5000,             // wait 5s before processing
        attempts: 5,
        backoff: { type: 'exponential', delay: 2000 },
      },
    );

    return user;
  }
}
```

---

## Processor Pattern

Processors consume jobs from a queue. The `@Processor` decorator creates a BullMQ Worker.

```ts
// infrastructure/queue/processors/email.processor.ts
import { Processor, WorkerHost, OnWorkerEvent } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { Logger } from '@nestjs/common';

@Processor('email', {
  concurrency: 5,
  limiter: { max: 14, duration: 1000 }, // rate limit: 14 jobs/sec (SES default)
})
export class EmailProcessor extends WorkerHost {
  private readonly logger = new Logger(EmailProcessor.name);

  async process(job: Job<{ userId: string; email: string }>): Promise<void> {
    switch (job.name) {
      case 'welcome-email':
        await this.sendWelcome(job.data);
        break;
      case 'password-reset':
        await this.sendPasswordReset(job.data);
        break;
      default:
        this.logger.warn(`Unknown job name: ${job.name}`);
    }
  }

  @OnWorkerEvent('failed')
  onFailed(job: Job, error: Error) {
    this.logger.error(
      `Job ${job.id} (${job.name}) failed after ${job.attemptsMade} attempts: ${error.message}`,
    );
  }

  @OnWorkerEvent('completed')
  onCompleted(job: Job) {
    this.logger.log(`Job ${job.id} (${job.name}) completed`);
  }

  private async sendWelcome(data: { userId: string; email: string }) {
    // ... email sending logic
  }

  private async sendPasswordReset(data: { userId: string; email: string }) {
    // ...
  }
}
```

---

## Retry and Dead Letter Queues

BullMQ retries automatically based on `attempts` and `backoff` in job options. After all retries are exhausted, move the job to a dead letter queue for manual inspection.

```ts
@Processor('email', { concurrency: 5 })
export class EmailProcessor extends WorkerHost {
  constructor(@InjectQueue('email-dlq') private dlq: Queue) {
    super();
  }

  @OnWorkerEvent('failed')
  async onFailed(job: Job, error: Error) {
    if (job.attemptsMade >= (job.opts.attempts ?? 3)) {
      await this.dlq.add('failed-email', {
        originalJob: { name: job.name, data: job.data, id: job.id },
        error: { message: error.message, stack: error.stack },
        failedAt: new Date().toISOString(),
      });
    }
  }

  async process(job: Job): Promise<void> { /* ... */ }
}
```

---

## Scheduled Jobs

Use repeatable jobs for cron-like scheduling. Remove existing repeatables on startup to avoid duplicates:

```ts
@Injectable()
export class SchedulerService implements OnModuleInit {
  constructor(@InjectQueue('notifications') private queue: Queue) {}

  async onModuleInit() {
    // Clear existing repeatable jobs to avoid duplicates on restart
    const existing = await this.queue.getRepeatableJobs();
    for (const job of existing) {
      await this.queue.removeRepeatableByKey(job.key);
    }

    // Daily digest at 8am UTC
    await this.queue.add('daily-digest', {}, {
      repeat: { pattern: '0 8 * * *' },
    });

    // Every 5 minutes: stale cart cleanup
    await this.queue.add('cleanup-stale-carts', {}, {
      repeat: { every: 300_000 },
    });
  }
}
```

---

## Queue Monitoring

Bull Board provides a web UI for inspecting queues, jobs, and their states.

```ts
// infrastructure/queue/bull-board.module.ts
import { BullBoardModule } from '@bull-board/nestjs';
import { ExpressAdapter } from '@bull-board/express';
import { BullMQAdapter } from '@bull-board/api/bullMQAdapter';

@Module({
  imports: [
    BullBoardModule.forRoot({
      route: '/admin/queues',
      adapter: ExpressAdapter,
    }),
    BullBoardModule.forFeature(
      { name: 'email', adapter: BullMQAdapter },
      { name: 'media-processing', adapter: BullMQAdapter },
      { name: 'notifications', adapter: BullMQAdapter },
    ),
  ],
})
export class BullBoardSetupModule {}
```

Protect the route with admin authentication — either basic auth middleware or the `JwtAuthGuard` + `RolesGuard`.

---

## Patterns

### Fan-Out

One event triggers jobs in multiple queues:

```ts
async processOrder(order: Order) {
  await Promise.all([
    this.emailQueue.add('order-confirmation', { orderId: order.id }),
    this.inventoryQueue.add('reserve-stock', { items: order.items }),
    this.analyticsQueue.add('track-purchase', { orderId: order.id }),
    this.notificationQueue.add('push', { userId: order.userId, type: 'order' }),
  ]);
}
```

### Priority Queue

Higher-tier users get priority processing:

```ts
const priority = user.tier === 'vip' ? 1 : user.tier === 'pro' ? 5 : 10;
await this.queue.add('process-request', payload, { priority });
```

### Batch Processing

Use a flow for jobs that must complete in a specific order:

```ts
import { FlowProducer } from 'bullmq';

const flowProducer = new FlowProducer({ connection: redisConnection });

await flowProducer.add({
  name: 'finalize-report',
  queueName: 'reports',
  data: { reportId },
  children: [
    { name: 'fetch-data', queueName: 'reports', data: { reportId, source: 'sales' } },
    { name: 'fetch-data', queueName: 'reports', data: { reportId, source: 'inventory' } },
  ],
});
```

---

## Separate Worker Process

For horizontal scaling, run processors in a dedicated app that doesn't serve HTTP:

```
apps/
  api/          # HTTP server only — adds jobs, doesn't process them
  worker/       # BullMQ processors only — no HTTP listener
    src/
      main.ts   # NestFactory.createApplicationContext(WorkerModule)
      worker.module.ts
```

```ts
// apps/worker/src/main.ts
import { NestFactory } from '@nestjs/core';
import { WorkerModule } from './worker.module';

async function bootstrap() {
  // No HTTP server — just start the NestJS container for DI
  const app = await NestFactory.createApplicationContext(WorkerModule);
  console.log('Worker started');
}
bootstrap();
```

This lets you scale workers independently from the API. Both share the same Redis connection and the same processor code (import from a shared package or directly from `apps/api`).
