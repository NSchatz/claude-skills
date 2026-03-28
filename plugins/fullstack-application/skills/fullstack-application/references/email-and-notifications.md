---
title: Email and Notifications
weight: 10
---

# Email and Notifications

This reference covers transactional email delivery, email templates, in-app notifications with real-time delivery, and queue integration.

## Table of Contents

- [Email Setup](#email-setup)
- [Email Service](#email-service)
- [Email Templates](#email-templates)
- [In-App Notifications](#in-app-notifications)
- [Frontend Notification Hook](#frontend-notification-hook)

---

## Email Setup

Never send email synchronously in a request handler. Always enqueue via BullMQ — this decouples request latency from the email provider, handles retries, and respects rate limits.

```bash
pnpm add @nestjs-modules/mailer nodemailer
pnpm add -D @types/nodemailer
```

```ts
// mail/mail.module.ts
import { MailerModule } from '@nestjs-modules/mailer';
import { HandlebarsAdapter } from '@nestjs-modules/mailer/dist/adapters/handlebars.adapter';
import { join } from 'path';

@Module({
  imports: [
    MailerModule.forRoot({
      transport: {
        host: process.env.SMTP_HOST || 'email-smtp.us-east-1.amazonaws.com',
        port: 465,
        secure: true,
        auth: {
          user: process.env.SES_SMTP_USER,
          pass: process.env.SES_SMTP_PASS,
        },
        pool: true,
        maxConnections: 5,
        rateLimit: 14, // SES default: 14/sec
      },
      defaults: { from: '"MyApp" <noreply@myapp.com>' },
      template: {
        dir: join(__dirname, 'templates'),
        adapter: new HandlebarsAdapter(),
        options: { strict: true },
      },
    }),
    BullModule.registerQueue({ name: 'email' }),
  ],
  providers: [MailService, MailProcessor],
  exports: [MailService],
})
export class MailModule {}
```

---

## Email Service

The service enqueues emails; the processor sends them.

```ts
// mail/mail.service.ts
@Injectable()
export class MailService {
  constructor(@InjectQueue('email') private emailQueue: Queue) {}

  async sendWelcome(user: { email: string; name: string }) {
    return this.enqueue({
      to: user.email,
      subject: 'Welcome to MyApp',
      template: 'welcome',
      context: { name: user.name },
    });
  }

  async sendPasswordReset(user: { email: string; name: string }, token: string) {
    return this.enqueue({
      to: user.email,
      subject: 'Reset your password',
      template: 'password-reset',
      context: {
        name: user.name,
        resetUrl: `${process.env.FRONTEND_URL}/reset-password?token=${token}`,
        expiresInMinutes: 30,
      },
      priority: 'high',
    });
  }

  private async enqueue(options: SendMailOptions) {
    const priorityMap = { high: 1, normal: 5, low: 10 };
    return this.emailQueue.add('send', options, {
      priority: priorityMap[options.priority || 'normal'],
      attempts: 3,
      backoff: { type: 'exponential', delay: 5000 },
    });
  }
}
```

### Processor

```ts
// mail/mail.processor.ts
@Processor('email', {
  concurrency: 5,
  limiter: { max: 14, duration: 1000 }, // match SES rate limit
})
export class MailProcessor extends WorkerHost {
  constructor(private mailer: MailerService) { super(); }

  async process(job: Job<SendMailOptions>) {
    const { to, subject, template, context } = job.data;
    await this.mailer.sendMail({ to, subject, template, context });
  }
}
```

---

## Email Templates

### Option 1: Handlebars (simple)

```
mail/templates/
├── welcome.hbs
├── password-reset.hbs
└── layouts/
    └── default.hbs
```

### Option 2: React Email (typed, composable)

```bash
pnpm add @react-email/components react-email
```

```tsx
// emails/welcome.tsx
import { Body, Container, Head, Heading, Html, Button, Text, Preview } from '@react-email/components';

interface WelcomeEmailProps {
  name: string;
  dashboardUrl?: string;
}

export default function WelcomeEmail({ name, dashboardUrl = 'https://myapp.com/dashboard' }: WelcomeEmailProps) {
  return (
    <Html>
      <Head />
      <Preview>Welcome to MyApp, {name}!</Preview>
      <Body style={{ backgroundColor: '#f6f9fc', fontFamily: 'sans-serif' }}>
        <Container style={{ margin: '0 auto', padding: '40px 20px', maxWidth: '560px' }}>
          <Heading>Welcome, {name}!</Heading>
          <Text>Your account is ready.</Text>
          <Button href={dashboardUrl} style={{
            backgroundColor: '#2563eb', color: '#fff', padding: '12px 24px',
            borderRadius: '6px', textDecoration: 'none',
          }}>
            Go to Dashboard
          </Button>
        </Container>
      </Body>
    </Html>
  );
}
```

Render server-side:

```ts
import { render } from '@react-email/render';
import WelcomeEmail from '../../emails/welcome';

export async function renderEmail(template: string, props: Record<string, unknown>): Promise<string> {
  const templates = { welcome: WelcomeEmail /* ... */ };
  return render(templates[template](props));
}
```

---

## In-App Notifications

### Database Model

```prisma
model Notification {
  id        String    @id @default(cuid())
  userId    String
  title     String
  body      String
  type      String    @default("info") // info, success, warning, error
  actionUrl String?
  read      Boolean   @default(false)
  readAt    DateTime?
  createdAt DateTime  @default(now())

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId, read, createdAt])
}
```

### Service

```ts
@Injectable()
export class NotificationsService {
  constructor(
    private prisma: PrismaService,
    private gateway: NotificationsGateway,
  ) {}

  async create(params: {
    userId: string; title: string; body: string;
    type?: string; actionUrl?: string;
  }) {
    const notification = await this.prisma.notification.create({ data: params });

    // Deliver in real-time via WebSocket
    this.gateway.sendToUser(params.userId, 'notification:new', notification);

    return notification;
  }

  async getForUser(userId: string, opts: { unreadOnly?: boolean; limit?: number; cursor?: string }) {
    const where: Prisma.NotificationWhereInput = { userId };
    if (opts.unreadOnly) where.read = false;
    if (opts.cursor) where.createdAt = { lt: new Date(opts.cursor) };

    const results = await this.prisma.notification.findMany({
      where,
      take: (opts.limit ?? 20) + 1,
      orderBy: { createdAt: 'desc' },
    });

    const hasMore = results.length > (opts.limit ?? 20);
    const items = hasMore ? results.slice(0, opts.limit ?? 20) : results;

    return {
      items,
      hasMore,
      nextCursor: items.at(-1)?.createdAt.toISOString() ?? null,
    };
  }

  async markRead(userId: string, id: string) {
    await this.prisma.notification.update({
      where: { id, userId },
      data: { read: true, readAt: new Date() },
    });
    this.gateway.sendToUser(userId, 'notification:read', { id });
  }

  async markAllRead(userId: string) {
    await this.prisma.notification.updateMany({
      where: { userId, read: false },
      data: { read: true, readAt: new Date() },
    });
    this.gateway.sendToUser(userId, 'notification:all-read', {});
  }

  async getUnreadCount(userId: string): Promise<number> {
    return this.prisma.notification.count({ where: { userId, read: false } });
  }
}
```

### WebSocket Gateway

```ts
@WebSocketGateway({ namespace: '/notifications', cors: { origin: process.env.FRONTEND_URL, credentials: true } })
export class NotificationsGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server: Server;

  async handleConnection(client: Socket) {
    try {
      const token = client.handshake.auth?.token;
      const payload = this.jwt.verify(token);
      client.data.userId = payload.sub;
      client.join(`user:${payload.sub}`);
    } catch {
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) { /* cleanup */ }

  sendToUser(userId: string, event: string, data: unknown) {
    this.server.to(`user:${userId}`).emit(event, data);
  }
}
```

---

## Frontend Notification Hook

```ts
// hooks/useNotifications.ts
export function useNotifications() {
  const { token } = useAuth();
  const queryClient = useQueryClient();

  // WebSocket connection for real-time delivery
  useEffect(() => {
    if (!token) return;
    const socket = io(`${import.meta.env.VITE_API_URL}/notifications`, {
      auth: { token },
      transports: ['websocket'],
    });

    socket.on('notification:new', () => {
      queryClient.setQueryData<number>(['notifications', 'unread'], (old) => (old ?? 0) + 1);
      queryClient.invalidateQueries({ queryKey: ['notifications', 'list'] });
    });

    socket.on('notification:read', ({ id }) => {
      queryClient.setQueryData<number>(['notifications', 'unread'], (old) => Math.max((old ?? 1) - 1, 0));
    });

    socket.on('notification:all-read', () => {
      queryClient.setQueryData<number>(['notifications', 'unread'], 0);
    });

    return () => { socket.disconnect(); };
  }, [token, queryClient]);

  const unreadCount = useGetUnreadCountQuery();
  const markRead = useMarkReadMutation();
  const markAllRead = useMarkAllReadMutation();

  return { unreadCount: unreadCount.data ?? 0, markRead, markAllRead };
}
```
