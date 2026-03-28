---
title: Deployment and CI/CD
weight: 5
---

# Deployment and CI/CD

## Table of Contents

1. [Docker](#docker)
2. [Docker Compose](#docker-compose)
3. [PM2 Process Manager](#pm2-process-manager)
4. [systemd Service](#systemd-service)
5. [GitHub Actions CI/CD](#github-actions-cicd)
6. [Hosting Options](#hosting-options)
7. [Environment Management](#environment-management)
8. [Health Monitoring](#health-monitoring)

---

## Docker

### Dockerfile (multi-stage, production-ready)

```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
RUN corepack enable pnpm

COPY package.json pnpm-lock.yaml ./
COPY prisma ./prisma/
RUN pnpm install --frozen-lockfile
RUN pnpm exec prisma generate

COPY tsconfig.json ./
COPY src ./src/
RUN pnpm run build

# Production stage
FROM node:20-alpine AS production
WORKDIR /app
RUN corepack enable pnpm

COPY package.json pnpm-lock.yaml ./
COPY prisma ./prisma/
RUN pnpm install --frozen-lockfile --prod
RUN pnpm exec prisma generate

COPY --from=builder /app/dist ./dist/

# Non-root user
RUN addgroup -g 1001 -S botuser && adduser -S botuser -u 1001
USER botuser

CMD ["node", "dist/index.js"]
```

Key points:
- Multi-stage build keeps the production image small (no TypeScript, no dev dependencies)
- `--frozen-lockfile` ensures reproducible builds
- Prisma client must be generated in both stages (build needs it for type-checking, production needs it for runtime)
- Non-root user is a security best practice
- Alpine base for smaller image size

### .dockerignore

```
node_modules
dist
.env
.git
*.md
.github
```

---

## Docker Compose

### Development stack

```yaml
services:
  bot:
    build: .
    restart: unless-stopped
    env_file: .env
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    volumes:
      - ./src:/app/src  # Hot reload in dev (with tsx watch)

  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: discordbot
      POSTGRES_USER: bot
      POSTGRES_PASSWORD: ${DB_PASSWORD:-localdev}
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U bot -d discordbot"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --maxmemory 128mb --maxmemory-policy allkeys-lru
    ports:
      - "6379:6379"

volumes:
  pgdata:
```

### Production overrides (docker-compose.prod.yml)

```yaml
services:
  bot:
    build:
      context: .
      target: production
    restart: always
    volumes: []  # No source mounting in prod
    deploy:
      resources:
        limits:
          memory: 512M
```

Run production: `docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d`

---

## PM2 Process Manager

### ecosystem.config.js

```js
module.exports = {
  apps: [{
    name: 'discord-bot',
    script: 'dist/index.js',
    instances: 1,              // Don't use cluster mode — Discord bots need a single gateway connection per shard
    autorestart: true,
    watch: false,
    max_memory_restart: '500M',
    env: {
      NODE_ENV: 'production',
    },
    error_file: './logs/error.log',
    out_file: './logs/out.log',
    merge_logs: true,
    log_date_format: 'YYYY-MM-DD HH:mm:ss',
  }],
};
```

### Common PM2 commands

```bash
pm2 start ecosystem.config.js    # Start the bot
pm2 restart discord-bot           # Restart
pm2 stop discord-bot              # Stop
pm2 logs discord-bot              # View logs
pm2 monit                         # Real-time monitoring
pm2 startup                       # Auto-start on system boot
pm2 save                          # Save current process list
```

Important: Don't use PM2's `cluster_mode` or `instances > 1` for Discord bots. The Discord gateway expects one connection per shard. If you need multiple processes, use Discord.js's ShardingManager instead.

---

## systemd Service

### /etc/systemd/system/discord-bot.service

```ini
[Unit]
Description=Discord Bot
After=network.target postgresql.service redis.service

[Service]
Type=simple
User=botuser
WorkingDirectory=/opt/discord-bot
ExecStart=/usr/bin/node dist/index.js
Restart=always
RestartSec=5
EnvironmentFile=/opt/discord-bot/.env
StandardOutput=journal
StandardError=journal
SyslogIdentifier=discord-bot

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/discord-bot

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable discord-bot    # Auto-start on boot
sudo systemctl start discord-bot     # Start
sudo systemctl status discord-bot    # Check status
sudo journalctl -u discord-bot -f    # View logs
```

---

## GitHub Actions CI/CD

### .github/workflows/ci.yml

```yaml
name: CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile
      - run: pnpm exec prisma generate
      - run: pnpm run lint          # tsc --noEmit
      - run: pnpm run test          # vitest run

  deploy:
    needs: check
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    steps:
      - uses: actions/checkout@v4

      # Option A: Deploy to VPS via SSH
      - name: Deploy to VPS
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_KEY }}
          script: |
            cd /opt/discord-bot
            git pull origin main
            pnpm install --frozen-lockfile --prod
            pnpm exec prisma generate
            pnpm exec prisma migrate deploy
            pnpm run build
            pm2 restart discord-bot

      # Option B: Build and push Docker image
      # - name: Build and push Docker image
      #   run: |
      #     docker build -t ghcr.io/${{ github.repository }}:latest .
      #     echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
      #     docker push ghcr.io/${{ github.repository }}:latest

      # Option C: Deploy to Railway
      # - uses: bervProject/railway-deploy@main
      #   with:
      #     railway_token: ${{ secrets.RAILWAY_TOKEN }}
```

### Slash command deployment in CI

Register global commands as part of the deploy pipeline:

```yaml
  deploy-commands:
    needs: deploy
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile
      - run: pnpm exec prisma generate
      - run: DEPLOY_GLOBAL=true pnpm run deploy-commands
        env:
          DISCORD_TOKEN: ${{ secrets.DISCORD_TOKEN }}
          CLIENT_ID: ${{ secrets.CLIENT_ID }}
```

Only run command deployment when command files actually change (use `paths` filter or a manual trigger).

---

## Hosting Options

| Platform | Monthly Cost | Pros | Cons | Best For |
|----------|-------------|------|------|----------|
| **VPS (Hetzner, DigitalOcean)** | $4-12 | Full control, cheapest at scale | Manual setup, maintenance | Production bots |
| **Railway** | $5+ (usage) | Easy deploy, good DX | Can get expensive | Quick deploys, small bots |
| **Fly.io** | $0-5+ | Global edge, Docker-native | More complex setup | Distributed bots |
| **Oracle Cloud Free** | Free | Generous ARM instances | Complex UI, availability | Budget projects |
| **AWS Lightsail** | $3.50+ | Predictable pricing | AWS complexity | AWS-familiar teams |
| **Home server** | Electricity | No limits | Uptime depends on you | Personal bots |

### Important: Discord bots need always-on hosting

Discord bots maintain a persistent WebSocket connection. **Serverless platforms (AWS Lambda, Vercel Functions, Cloudflare Workers) cannot host the main bot process.** They can be used for auxiliary endpoints (webhooks, dashboard API) but not the gateway connection.

### Hosting with free tier notes

- **Railway**: Free tier removed in 2023. Usage-based pricing now. Good DX but watch costs.
- **Fly.io**: Generous free tier (3 shared VMs). Good for small bots.
- **Render**: Free tier has cold starts — terrible for Discord bots since the WebSocket disconnects.
- **Oracle Cloud**: Always-free ARM instances (4 OCPU, 24GB RAM) are incredible if you can get them provisioned.

---

## Environment Management

### Dev vs production tokens

Always use **separate Discord applications** for development and production:

1. Create two applications in the Discord Developer Portal
2. Dev bot token in `.env` (used locally, guild-specific commands)
3. Prod bot token in CI/CD secrets (global commands)
4. Dev bot is only in your test server
5. Prod bot is the one users invite

### Config validation at startup

```ts
// src/lib/config.ts validates env vars with Zod
// If any required var is missing, the bot exits immediately with a clear error
// This prevents the bot from starting in a broken state
```

### Secret management in production

| Approach | When to use |
|----------|-----------|
| `.env` file on the server | Simple VPS deployments |
| Docker secrets | Docker Swarm deployments |
| Platform env vars | Railway, Fly.io, Render |
| AWS Secrets Manager | AWS-hosted bots |
| GitHub Actions secrets | CI/CD pipeline |

---

## Health Monitoring

### HTTP health endpoint

Expose a simple health check alongside the bot:

```ts
import { createServer } from 'node:http';

const server = createServer((req, res) => {
  if (req.url === '/health') {
    const healthy = client.ws.status === 0; // 0 = WebSocketShardStatus.Ready
    res.writeHead(healthy ? 200 : 503, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: healthy ? 'healthy' : 'unhealthy',
      uptime: process.uptime(),
      guilds: client.guilds.cache.size,
      ping: client.ws.ping,
      memory: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
    }));
  } else {
    res.writeHead(404);
    res.end();
  }
});

server.listen(process.env.PORT || 3000);
```

### Status webhook

Send bot status updates to a Discord channel:

```ts
import { WebhookClient } from 'discord.js';

const statusHook = process.env.STATUS_WEBHOOK_URL
  ? new WebhookClient({ url: process.env.STATUS_WEBHOOK_URL })
  : null;

client.on('ready', () => {
  statusHook?.send(`✅ Bot online. Serving ${client.guilds.cache.size} guilds. Ping: ${client.ws.ping}ms`);
});

// Also useful: send on shard disconnect, error, rate limit events
```

### External monitoring

- **UptimeRobot** (free tier) — ping the `/health` endpoint every 5 minutes
- **Better Uptime** — more features, good free tier
- **Sentry** — error tracking with Node.js SDK, groups similar errors, alerts on new issues
