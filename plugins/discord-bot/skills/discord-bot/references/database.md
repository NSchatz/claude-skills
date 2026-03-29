---
title: Database Patterns
weight: 4
---

# Database Patterns

## Table of Contents

1. [Prisma Setup](#prisma-setup)
2. [Schema Design Principles](#schema-design-principles)
3. [Common Schema Patterns](#common-schema-patterns)
4. [Migration Workflow](#migration-workflow)
5. [Query Patterns](#query-patterns)
6. [Redis Integration](#redis-integration)
7. [Alternative Databases](#alternative-databases)

---

## Prisma Setup

### prisma/schema.prisma (base)

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}
```

### Prisma client singleton

```ts
// src/lib/database.ts
import { PrismaClient } from '@prisma/client';
import { logger } from './logger.js';

export const prisma = new PrismaClient({
  log: [
    { emit: 'event', level: 'error' },
    { emit: 'event', level: 'warn' },
  ],
});

prisma.$on('error', (e) => logger.error(e, 'Prisma error'));
prisma.$on('warn', (e) => logger.warn(e, 'Prisma warning'));
```

---

## Schema Design Principles

### Discord snowflake IDs are strings

Discord IDs (user, guild, channel, role, message) are 64-bit integers that exceed JavaScript's `Number.MAX_SAFE_INTEGER`. Always store them as `String`:

```prisma
model GuildConfig {
  id String @id // Discord guild snowflake — NOT Int
}
```

### Index frequently queried fields

Most queries filter by `guildId` and often `userId`. Always add composite indexes:

```prisma
model UserLevel {
  id      String @id @default(cuid())
  guildId String
  userId  String
  xp      Int    @default(0)

  @@unique([guildId, userId])          // Enforce one record per user per guild
  @@index([guildId, xp(sort: Desc)])   // Leaderboard queries
}
```

### Use `@@unique` for natural compound keys

When a record is uniquely identified by a combination of fields (like a user in a specific guild), use `@@unique` instead of a separate primary key when you want upsert behavior:

```prisma
@@unique([guildId, userId])
```

This enables `prisma.userLevel.upsert({ where: { guildId_userId: { guildId, userId } }, ... })`.

### Timestamps

Always include `createdAt`. Add `updatedAt` for records that change:

```prisma
createdAt DateTime @default(now())
updatedAt DateTime @updatedAt
```

---

## Common Schema Patterns

### Guild Configuration (every bot needs this)

```prisma
model GuildConfig {
  id        String   @id // guild snowflake

  // Moderation
  logChannelId    String?
  muteRoleId      String?
  automod         Boolean @default(false)

  // Welcome
  welcomeEnabled  Boolean @default(false)
  welcomeChannel  String?
  welcomeMessage  String  @default("Welcome to {server}, {user}!")
  goodbyeEnabled  Boolean @default(false)
  goodbyeChannel  String?
  goodbyeMessage  String  @default("Goodbye {user.tag}!")
  autoRoleId      String?

  // Modules
  enableEconomy   Boolean @default(true)
  enableLeveling  Boolean @default(true)
  enableTickets   Boolean @default(false)

  // Leveling config
  xpCooldown      Int     @default(60) // seconds
  xpMin           Int     @default(15)
  xpMax           Int     @default(25)
  levelUpChannel  String? // null = same channel

  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
```

### Upsert on first interaction

When the bot first interacts with a guild, ensure a config record exists:

```ts
export async function getGuildConfig(guildId: string) {
  return prisma.guildConfig.upsert({
    where: { id: guildId },
    update: {},
    create: { id: guildId },
  });
}
```

### Moderation actions

```prisma
model ModAction {
  id          Int      @id @default(autoincrement())
  guildId     String
  userId      String   // target
  moderatorId String
  action      String   // "ban", "kick", "timeout", "warn", "unban", "untimeout"
  reason      String?
  duration    Int?     // seconds, for temp actions
  createdAt   DateTime @default(now())

  @@index([guildId, userId])
  @@index([guildId, createdAt(sort: Desc)])
}
```

### Economy with transactions

```prisma
model UserEconomy {
  id       String @id @default(cuid())
  guildId  String
  userId   String
  wallet   Int    @default(0)
  bank     Int    @default(0)
  bankMax  Int    @default(10000)
  lastDaily DateTime?
  lastWork  DateTime?

  @@unique([guildId, userId])
  @@index([guildId, wallet(sort: Desc)])
}
```

**Critical**: Use database transactions for balance operations to prevent race conditions:

```ts
async function transferCoins(guildId: string, fromId: string, toId: string, amount: number) {
  return prisma.$transaction(async (tx) => {
    const sender = await tx.userEconomy.findUnique({
      where: { guildId_userId: { guildId, userId: fromId } },
    });

    if (!sender || sender.wallet < amount) {
      throw new Error('Insufficient funds');
    }

    await tx.userEconomy.update({
      where: { guildId_userId: { guildId, userId: fromId } },
      data: { wallet: { decrement: amount } },
    });

    await tx.userEconomy.upsert({
      where: { guildId_userId: { guildId, userId: toId } },
      update: { wallet: { increment: amount } },
      create: { guildId, userId: toId, wallet: amount },
    });
  });
}
```

---

## Migration Workflow

### Development

```bash
# Create and apply a migration
npx prisma migrate dev --name add_economy_tables

# Generate client after schema changes
npx prisma generate

# Open Prisma Studio (GUI)
npx prisma studio
```

### Production

```bash
# Apply pending migrations (non-interactive, for CI/CD)
npx prisma migrate deploy
```

**Never** run `prisma migrate dev` in production — it can reset data. Always use `prisma migrate deploy`.

### In CI/CD pipeline

```yaml
- name: Run database migrations
  run: npx prisma migrate deploy
  env:
    DATABASE_URL: ${{ secrets.DATABASE_URL }}
```

---

## Query Patterns

### Paginated leaderboard

```ts
async function getLeaderboard(guildId: string, page: number, pageSize = 10) {
  const [users, total] = await Promise.all([
    prisma.userEconomy.findMany({
      where: { guildId },
      orderBy: { wallet: 'desc' },
      skip: (page - 1) * pageSize,
      take: pageSize,
    }),
    prisma.userEconomy.count({ where: { guildId } }),
  ]);

  return {
    users,
    totalPages: Math.ceil(total / pageSize),
    currentPage: page,
  };
}
```

### Moderation case lookup

```ts
async function getModHistory(guildId: string, userId: string) {
  return prisma.modAction.findMany({
    where: { guildId, userId },
    orderBy: { createdAt: 'desc' },
    take: 25,
  });
}
```

### Bulk operations with createMany

```ts
// Useful for importing or bulk-creating records
await prisma.modAction.createMany({
  data: actions,
  skipDuplicates: true,
});
```

---

## Redis Integration

### Setup

```ts
// src/lib/redis.ts
import Redis from 'ioredis';
import { config } from './config.js';
import { logger } from './logger.js';

// ioredis with ESM: the default export is a namespace, so use Redis.default as the constructor
export const redis = config.REDIS_URL
  ? new Redis.default(config.REDIS_URL, {
      maxRetriesPerRequest: 3,
      lazyConnect: true,
    })
  : null;

redis?.on('error', (err: Error) => logger.error(err, 'Redis error'));
redis?.on('connect', () => logger.info('Redis connected'));
```

### Cooldown tracking with Redis

```ts
/**
 * Check and set a cooldown. Returns seconds remaining if on cooldown, or 0 if clear.
 */
export async function checkCooldown(
  key: string,
  cooldownSeconds: number,
): Promise<number> {
  if (!redis) return 0; // No Redis = no persistent cooldowns

  const existing = await redis.get(key);
  if (existing) {
    const ttl = await redis.ttl(key);
    return ttl > 0 ? ttl : 0;
  }

  await redis.set(key, '1', 'EX', cooldownSeconds);
  return 0;
}

// Usage:
const remaining = await checkCooldown(`daily:${guildId}:${userId}`, 86400);
if (remaining > 0) {
  return interaction.reply({ content: `Try again in ${formatDuration(remaining)}`, ephemeral: true });
}
```

### Cross-shard state

Redis Pub/Sub for real-time cross-shard communication:

```ts
// Publisher (any shard)
await redis.publish('guild-config-update', JSON.stringify({ guildId, key, value }));

// Subscriber (all shards)
const sub = redis.duplicate();
sub.subscribe('guild-config-update');
sub.on('message', (channel, message) => {
  const data = JSON.parse(message);
  // Update in-memory cache
});
```

### Cache layer

```ts
async function getCachedGuildConfig(guildId: string) {
  if (redis) {
    const cached = await redis.get(`config:${guildId}`);
    if (cached) return JSON.parse(cached);
  }

  const config = await prisma.guildConfig.upsert({
    where: { id: guildId },
    update: {},
    create: { id: guildId },
  });

  if (redis) {
    await redis.set(`config:${guildId}`, JSON.stringify(config), 'EX', 300); // 5 min TTL
  }

  return config;
}
```

---

## Alternative Databases

### SQLite (for small/personal bots)

Use `better-sqlite3` directly — skip the ORM for tiny bots:

```ts
import Database from 'better-sqlite3';

const db = new Database('bot.db');
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS guild_config (
    id TEXT PRIMARY KEY,
    prefix TEXT DEFAULT '!',
    log_channel TEXT
  )
`);

const getConfig = db.prepare('SELECT * FROM guild_config WHERE id = ?');
const setConfig = db.prepare('INSERT OR REPLACE INTO guild_config (id, prefix) VALUES (?, ?)');
```

**Limitations**: No concurrent writes (problematic with sharding), no connection pooling, single-file storage. Fine for bots under ~100 guilds that don't need to shard.

### MongoDB (with Mongoose)

If the user specifically wants MongoDB:

```ts
import mongoose from 'mongoose';

const guildConfigSchema = new mongoose.Schema({
  _id: String, // guild snowflake
  logChannel: String,
  welcomeEnabled: { type: Boolean, default: false },
  welcomeMessage: { type: String, default: 'Welcome {user}!' },
}, { timestamps: true });

export const GuildConfig = mongoose.model('GuildConfig', guildConfigSchema);
```

Recommendation: PostgreSQL + Prisma is the better default for Discord bots because relational data (users belong to guilds, transactions reference users, mod actions reference both) maps naturally to SQL. MongoDB works but leads to denormalization and `$lookup` overhead for common queries.

### Drizzle ORM (alternative to Prisma)

Lighter weight, SQL-like syntax, excellent TypeScript support:

```ts
import { pgTable, text, integer, boolean, timestamp } from 'drizzle-orm/pg-core';

export const guildConfig = pgTable('guild_config', {
  id: text('id').primaryKey(),
  logChannelId: text('log_channel_id'),
  automod: boolean('automod').default(false),
  createdAt: timestamp('created_at').defaultNow(),
});
```

Good choice if the user prefers staying closer to raw SQL. Trade-off: less magic than Prisma, more manual work for migrations.
