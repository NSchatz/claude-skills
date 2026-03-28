---
title: Sharding
weight: 6
---

# Sharding

## Table of Contents

1. [When Sharding is Required](#when-sharding-is-required)
2. [ShardingManager Setup](#shardingmanager-setup)
3. [Cross-Shard Communication](#cross-shard-communication)
4. [Stateless Design](#stateless-design)
5. [Large Bot Scaling](#large-bot-scaling)
6. [Memory Planning](#memory-planning)

---

## When Sharding is Required

Discord **mandates** sharding once a bot is in **2,500+ guilds**. At that point, a single gateway connection cannot handle all guilds, and Discord will refuse the connection.

**When to set up sharding:**
- If the bot is already approaching 2,500 guilds
- If the user explicitly expects growth to that scale
- If the user asks for it

**When to skip sharding:**
- Personal/community bots for a single server
- Bots that will realistically stay under 2,500 guilds
- The initial version of any bot (add sharding later when needed)

Even when skipping sharding initially, write code that's sharding-compatible — avoid global in-memory state, use a database or Redis for shared state.

---

## ShardingManager Setup

The ShardingManager spawns your bot file as separate child processes, each handling a subset of guilds.

### Entry point (shard.ts)

```ts
// src/shard.ts — This becomes the actual entry point instead of index.ts
import { ShardingManager } from 'discord.js';
import { config } from './lib/config.js';
import { logger } from './lib/logger.js';

const manager = new ShardingManager('./dist/index.js', {
  token: config.DISCORD_TOKEN,
  totalShards: 'auto', // Discord tells you how many you need
  // totalShards: 4,   // Or set manually for testing
});

manager.on('shardCreate', (shard) => {
  logger.info(`Launched shard ${shard.id}`);

  shard.on('ready', () => {
    logger.info(`Shard ${shard.id} ready`);
  });

  shard.on('disconnect', () => {
    logger.warn(`Shard ${shard.id} disconnected`);
  });

  shard.on('reconnecting', () => {
    logger.info(`Shard ${shard.id} reconnecting`);
  });

  shard.on('death', (process) => {
    logger.error(`Shard ${shard.id} died (PID: ${process.pid})`);
  });

  shard.on('error', (error) => {
    logger.error({ error, shardId: shard.id }, 'Shard error');
  });
});

manager.spawn({ timeout: 30_000 });
```

### Update package.json scripts

```json
{
  "scripts": {
    "start": "node dist/shard.js",
    "start:dev": "tsx src/shard.ts"
  }
}
```

### Bot file (index.ts) changes for sharding

The bot file (`index.ts`) runs once per shard. It mostly stays the same, but:

```ts
client.on('ready', () => {
  logger.info(`Shard ${client.shard?.ids[0]} ready, serving ${client.guilds.cache.size} guilds`);
});
```

---

## Cross-Shard Communication

### Fetching data across all shards

```ts
// Get total guild count across all shards
const results = await client.shard!.fetchClientValues('guilds.cache.size') as number[];
const totalGuilds = results.reduce((a, b) => a + b, 0);
```

### broadcastEval — run code on all shards

```ts
// Find a specific guild across shards
const guildName = await client.shard!.broadcastEval(
  (c, { guildId }) => c.guilds.cache.get(guildId)?.name ?? null,
  { context: { guildId: '123456789' } },
);
// Returns an array — one result per shard, most will be null
const name = guildName.find(n => n !== null);
```

### Redis Pub/Sub for real-time cross-shard messaging

For more complex cross-shard communication (e.g., updating a cached config across all shards), use Redis Pub/Sub:

```ts
// Publisher (any shard)
await redis.publish('config-update', JSON.stringify({ guildId, changes }));

// Subscriber (run on each shard at startup)
const subscriber = redis.duplicate();
await subscriber.subscribe('config-update');
subscriber.on('message', (channel, message) => {
  const { guildId, changes } = JSON.parse(message);
  // Update in-memory cache for this shard
  configCache.set(guildId, { ...configCache.get(guildId), ...changes });
});
```

---

## Stateless Design

The most important principle for shard-compatible bots: **don't store shared state in memory**.

### What NOT to do

```ts
// BAD: Global in-memory state
const guildConfigs = new Map<string, GuildConfig>();  // Each shard has its own copy!
const activePolls = new Map<string, Poll>();           // Poll on shard 0, voter on shard 3 — lost!
```

### What to do instead

| State | Store In | Why |
|-------|---------|-----|
| Guild configs | Database + Redis cache | Shared across all shards |
| User data (XP, balance) | Database | Must be consistent |
| Cooldowns | Redis `SET key EX` | Cross-shard, survives restarts |
| Active polls/giveaways | Database + Redis pub/sub | Cross-shard coordination |
| Music queues | In-memory per shard | Ephemeral, guild is always on one shard |
| Command cooldowns (if brief) | In-memory per shard | OK since commands route to the shard that owns the guild |

### The "one guild, one shard" guarantee

Discord assigns each guild to exactly one shard. All events for a guild arrive on the same shard. This means:

- Music queues can safely live in memory (the guild's shard handles all its voice events)
- Per-guild in-memory caches are fine for the owning shard
- But cross-guild operations (leaderboards, user lookup across servers) need a database

---

## Large Bot Scaling

### 2,500-10,000 guilds

- `totalShards: 'auto'` is sufficient
- Single machine can handle all shards
- Each shard typically uses 50-150MB RAM
- PostgreSQL + Redis is the standard backend

### 10,000-100,000 guilds

- Consider `discord-hybrid-sharding` for running shards across multiple machines
- Use a dedicated Redis cluster
- PostgreSQL with connection pooling (PgBouncer)
- Monitor memory per shard — adjust cache limits

### 100,000+ guilds

- Request "large bot sharding" from Discord (increases connection concurrency)
- Multiple machines required, each running a subset of shards
- Consider a message queue (RabbitMQ, NATS) for inter-process communication
- Dedicated database replicas for read-heavy operations (leaderboards)
- The Sapphire framework or a custom framework becomes essential at this scale

### discord-hybrid-sharding

For multi-machine sharding:

```ts
import { ClusterManager } from 'discord-hybrid-sharding';

const manager = new ClusterManager('./dist/index.js', {
  totalShards: 'auto',
  shardsPerClusters: 2,
  token: config.DISCORD_TOKEN,
});

manager.spawn({ timeout: -1 });
```

In the bot file:
```ts
import { ClusterClient, getInfo } from 'discord-hybrid-sharding';

const client = new Client({
  shards: getInfo().SHARD_LIST,
  shardCount: getInfo().TOTAL_SHARDS,
  intents: [/* ... */],
});

client.cluster = new ClusterClient(client);
```

---

## Memory Planning

| Scenario | RAM per Shard | Notes |
|----------|-------------|-------|
| Minimal bot, few intents | 50-80MB | Just `Guilds` intent, no message caching |
| Standard bot, message caching | 100-200MB | `Guilds` + `GuildMessages` + `MessageContent` |
| Full-featured, many intents | 200-400MB | All intents, generous cache limits |
| Unconfigured cache (default) | 300MB-1GB+ | **Danger** — grows unbounded |

### Cache configuration for sharded bots

```ts
import { Options } from 'discord.js';

const client = new Client({
  makeCache: Options.cacheWithLimits({
    MessageManager: 50,         // Reduced from default
    GuildMemberManager: 100,    // Only cache active members
    PresenceManager: 0,         // Don't cache presences
    ReactionUserManager: 0,
    ThreadManager: 25,
    GuildBanManager: 0,
    VoiceStateManager: 50,
  }),
  sweepers: {
    messages: {
      interval: 1800,   // every 30 min
      lifetime: 900,    // remove messages older than 15 min
    },
    users: {
      interval: 3600,
      filter: () => (user) => !user.bot,
    },
    guildMembers: {
      interval: 3600,
      filter: () => (member) => !member.user.bot,
    },
  },
});
```

### Monitoring memory

```ts
// Log memory usage periodically
setInterval(() => {
  const usage = process.memoryUsage();
  logger.info({
    heapUsed: Math.round(usage.heapUsed / 1024 / 1024),
    heapTotal: Math.round(usage.heapTotal / 1024 / 1024),
    rss: Math.round(usage.rss / 1024 / 1024),
    shardId: client.shard?.ids[0],
  }, 'Memory usage');
}, 300_000); // every 5 min
```
