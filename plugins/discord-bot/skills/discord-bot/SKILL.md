---
name: discord-bot
description: Complete Discord bot project generator and guide. Use this skill whenever the user wants to create a Discord bot, scaffold a Discord bot project, add features to an existing Discord bot, set up slash commands, configure Discord.js, handle Discord events, implement moderation/music/economy/leveling/ticket/utility bot features, set up sharding, deploy a Discord bot, or work with the Discord API in any capacity. Also trigger when the user mentions discord.js, Discord intents, Discord slash commands, Discord components (buttons, select menus, modals), Discord gateway, bot tokens, or any Discord bot development topic. When the user wants a web dashboard or admin panel for their Discord bot, this skill handles the bot side and orchestrates the fullstack-application skill for the web app. Always use this skill for any Discord bot work — even simple questions about a single command or event handler.
version: 1.0.0
---

# Discord Bot Generator

You are helping the user create a **complete, production-ready Discord bot** — not just a starter template, but a fully functional bot tailored to their specific use case with proper project structure, database integration, deployment configuration, and all the edge cases handled.

## Default Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | TypeScript (strict mode) |
| Runtime | Node.js 20+ |
| Discord Library | discord.js v14 |
| Framework | Sapphire Framework (`@sapphire/framework`) for medium/large bots, raw discord.js for small bots |
| Database | PostgreSQL + Prisma ORM |
| Cache | Redis (for cooldowns, cross-shard state, sessions) |
| Logging | Pino (structured JSON logging) |
| Deployment | Docker + Docker Compose |
| Process Manager | PM2 (VPS) or Docker restart policy |
| CI/CD | GitHub Actions |
| Package Manager | npm (or pnpm if user prefers) |

Use this stack by default. If the user explicitly requests alternatives (JavaScript, discord.py, MongoDB, etc.), adapt — but recommend this stack first and explain why. Use npm by default since it ships with Node.js and requires no extra setup — many users (especially beginners) won't have pnpm installed. If the user explicitly prefers pnpm, adapt the Dockerfile, CI, and lockfile accordingly.

## Reference Files

Load these as needed based on what you're working on — not all at once:

| File | When to load |
|------|-------------|
| [`references/discord-js-fundamentals.md`](references/discord-js-fundamentals.md) | Setting up the client, intents, events, slash commands, builders, components, collectors, partials |
| [`references/project-scaffold.md`](references/project-scaffold.md) | Scaffolding a new project — full file tree, package.json, tsconfig, loader patterns, entry point |
| [`references/bot-types.md`](references/bot-types.md) | When determining which commands/features to generate based on the bot type |
| [`references/database.md`](references/database.md) | Prisma schema design, PostgreSQL patterns, Redis caching, migration workflow |
| [`references/deployment.md`](references/deployment.md) | Docker, PM2, systemd, CI/CD pipelines, hosting options, environment management |
| [`references/sharding.md`](references/sharding.md) | ShardingManager, cross-shard communication, stateless design, large bot scaling |
| [`references/security.md`](references/security.md) | Token safety, input sanitization, permission checks, anti-raid, dependency auditing |
| [`references/integrations.md`](references/integrations.md) | AI/LLM chatbots, webhook feeds (GitHub/Twitch/YouTube), Lavalink music, web dashboards, image generation |

---

## Workflow

### Step 1: Identify the request type

**A. New bot from scratch** — Run the full interview (Step 2), then scaffold everything (Step 3).

**B. Adding features to an existing bot** — Ask for the relevant files if not provided. Read before editing. Load the relevant reference files.

**C. Targeted question** (e.g., "how do I create a button interaction?") — Answer directly with the correct code. Load only the relevant reference.

---

### Step 2: The User Interview (for new bots)

Ask all relevant questions in a single message, grouped by topic. Wait for the user's full response before generating anything.

#### Group 1: Bot Purpose and Type

- What does this bot do? Describe the core functionality in a sentence or two.
- Which category best describes it? (can be multiple)
  - Moderation (ban, kick, warn, automod, logging)
  - Music (play, queue, skip — requires Lavalink)
  - Economy / RPG (balance, shop, inventory, gambling)
  - Leveling / XP (rank cards, leaderboards, role rewards)
  - Utility (polls, reminders, server info, embeds)
  - Tickets (support ticket system with transcripts)
  - Welcome / Goodbye (configurable greetings, auto-role)
  - AI Chatbot (LLM-powered conversational features)
  - Custom (describe what you need)
- Is this for a single server (personal/community bot) or will it be invited to many servers (public bot)?

#### Group 2: Features and Scope

- What are the first 3-5 commands you want working?
- Do you need a web dashboard for server admins to configure the bot? If so:
  - What should admins be able to configure from the dashboard? (e.g., welcome messages, automod rules, logging channels, role rewards, custom commands)
  - Should the dashboard show analytics? (e.g., member activity, moderation stats, command usage)
  - Do you need a public-facing landing page for the bot (features, invite link, documentation)?
- Do you need any external integrations? (GitHub notifications, Twitch live alerts, YouTube uploads, etc.)
- Will the bot need voice channel features? (music, voice activity tracking, TTS)

#### Group 3: Infrastructure

- How will you host this? (VPS, Railway, Fly.io, Docker on your own server, other)
- Do you already have a PostgreSQL database, or should we include one in Docker Compose?
- Do you need Redis? (recommended if: cooldowns, cross-shard state, rate limiting, or caching)
- Do you expect this bot to grow past 2,500 servers? (determines whether to set up sharding from the start)

#### Group 4: Development Environment

- Do you already have a Discord application/bot token, or do you need setup instructions?
- Do you have a test server (guild) for development?
- GitHub repo already created? If so, what's the owner/repo?

#### Adapt the interview:
- If the user provides a detailed description up front, extract answers from it and only ask what's missing.
- If the user says "just a simple moderation bot" — don't ask about music, economy, dashboards, or sharding. Keep it focused.
- For experienced developers who signal they know what they want, trim the interview to essentials only.

---

### Step 3: Generate the Project

Only begin after completing the interview. Read `references/project-scaffold.md` for the full file tree and patterns.

#### 3a. Scaffold the project structure

Generate files in this order:

1. **Root config files**: `package.json`, `tsconfig.json`, `.env.example`, `.gitignore`, `Dockerfile`, `docker-compose.yml`, `ecosystem.config.js` (PM2), `.github/workflows/ci.yml`
2. **Source entry point**: `src/index.ts` (client creation, event/command loader, login)
3. **Command deployment script**: `src/deploy-commands.ts` (registers slash commands with Discord API — run separately, not on every startup)
4. **Event handlers**: `src/events/ready.ts`, `src/events/interactionCreate.ts`, and any event handlers needed for the bot type
5. **Commands**: Organized by category in `src/commands/<category>/<command>.ts`
6. **Database**: `prisma/schema.prisma` with models tailored to the bot type, `src/lib/database.ts` for the Prisma client singleton
7. **Utilities**: `src/lib/logger.ts` (Pino), `src/lib/config.ts` (env validation), `src/lib/embeds.ts` (common embed helpers)
8. **Components** (if needed): `src/components/buttons/`, `src/components/selectMenus/`, `src/components/modals/`

#### 3b. Tailor commands to the bot type

Read `references/bot-types.md` to determine which commands to generate. Every command must:

- Use `SlashCommandBuilder` with proper option types, descriptions, and permission defaults
- Have full error handling with user-friendly error messages
- Use `deferReply()` for any operation that might take over 3 seconds
- Include cooldown metadata where appropriate
- Check both user permissions and bot permissions before acting

#### 3c. Database schema

Read `references/database.md`. Design the Prisma schema based on the bot type:

- **Every bot**: `GuildConfig` model (settings per server)
- **Moderation**: `Warning`, `ModAction`, `MuteRecord` models
- **Economy**: `UserEconomy`, `ShopItem`, `Inventory`, `Transaction` models
- **Leveling**: `UserLevel`, `LevelReward` models
- **Tickets**: `Ticket`, `TicketConfig` models

Always use Discord snowflake IDs as `String` types (they exceed JavaScript's `Number.MAX_SAFE_INTEGER`). Add proper indexes on frequently queried fields like `guildId` and `userId`.

#### 3d. Deployment configuration

Read `references/deployment.md`. Generate:

- `Dockerfile` — Multi-stage build, non-root user, production-only dependencies
- `docker-compose.yml` — Bot + PostgreSQL + Redis (if needed)
- `.env.example` — All required environment variables with comments
- `.github/workflows/ci.yml` — Lint, type-check, test, and deploy pipeline
- `ecosystem.config.js` — PM2 config (if VPS deployment)

#### 3e. Present the file list

Before writing any files, present the complete list of files that will be created and get confirmation from the user. Group them by directory.

---

### Step 4: Post-generation checklist

After generating all files, walk the user through:

1. **Bot setup** — Create application at discord.com/developers, get token, enable required intents in the portal
2. **Enable privileged intents** — In the Developer Portal under Bot > Privileged Gateway Intents, enable the intents the bot needs. List exactly which ones and why. The bot will crash with "Used disallowed intents" if these aren't enabled.
3. **Environment** — Copy `.env.example` to `.env`, fill in token, client ID (Application ID from General Information page), database URL, and DEV_GUILD_ID (right-click server > Copy Server ID with Developer Mode on)
4. **Docker networking** — If running via Docker Compose, the `.env` hostnames must use Docker service names (`db`, `redis`, `lavalink`) instead of `localhost`. For running scripts locally against Dockerized services (e.g., `deploy-commands.ts`, `prisma migrate dev`), override with `localhost` on the command line: `DATABASE_URL=postgresql://bot:localdev@localhost:5432/discordbot npx prisma migrate dev`
5. **Database** — Run `docker compose up -d db` (if using Docker Compose), then run the migration from the host with the localhost override
6. **Deploy commands** — Run `npx tsx src/deploy-commands.ts` with localhost overrides for DB/Redis. The bot must be invited to the DEV_GUILD_ID server first, or this fails with "Missing Access"
7. **Invite the bot** — Provide the OAuth2 URL with the correct permissions and scopes. The bot must be in the server before deploying guild commands.
8. **Start the bot** — `npx tsx src/index.ts` for development, `docker compose up` for production

---

## Code Patterns and Standards

These apply to all generated code:

### TypeScript

- Strict mode on (`"strict": true` in tsconfig)
- No `any` types — use `unknown` + type guards or proper discord.js types
- Use `const enum` or object literals for constants, not magic strings
- ES2022 target, Node16 module resolution
- **Type error-prone patterns to watch for:**
  - **ioredis ESM import**: `import Redis from 'ioredis'` gives a namespace, not a class. Construct with `new Redis.default(url, opts)`, not `new Redis(url, opts)`. Error callbacks need typed params: `.on('error', (err: Error) => ...)`
  - **`ms()` package**: With strict types, `ms(someString)` fails because `string` is not assignable to `ms.StringValue`. Cast user input: `ms(durationStr as ms.StringValue)`
  - **discord.js channel unions**: `TextBasedChannel` is a union including `PartialGroupDMChannel` which lacks `.send()`, `.sendTyping()`, and `.threads`. Always narrow with type guards: `if ('send' in channel)`, `if ('threads' in channel)`, or `if ('sendTyping' in channel)` before accessing these properties
  - **Collection `.first(n)`**: Returns an array `T[]`, not a `Collection`. Don't assign back to a Collection variable — use `[...collection.values()].slice(0, n)` and reconstruct if needed
  - **Shoukaku v4 API**: `joinVoiceChannel()` is on the `Shoukaku` instance, not on `Node`. `Player` has no `.connection` property — use `shoukaku.leaveVoiceChannel(guildId)` or `player.destroy()`. `node.rest.resolve()` returns different `data` shapes per `loadType` — always check with `Array.isArray()` and `'encoded' in result.data` before using as `Track`

### Discord.js Patterns

- **Intents**: Only request what the bot actually needs. List each intent with a comment explaining why.
- **Partials**: Only enable partials the bot needs (e.g., `Partials.Message` for reaction roles on old messages). Always null-check and fetch partial data before using it.
- **Cache configuration**: Set `makeCache` and `sweepers` to limit memory usage. Don't cache presences unless the bot needs them.
- **Interaction responses**: Always handle the case where an interaction has already been replied to or deferred. Use a `safeReply` utility.
- **Command registration**: Always use a separate `deploy-commands.ts` script. Never register commands in the `ready` event — it hits rate limits and slows startup.
- **Error boundaries**: Wrap every interaction handler in try/catch. Log the error with context (guild, user, command name). Reply with a generic error message to the user.

### Environment Variables

- Validate all required env vars at startup with clear error messages
- Use a typed config module — not raw `process.env` access scattered through the code
- Separate dev and prod bot tokens (separate Discord applications)
- Never hardcode IDs, tokens, or secrets

### Graceful Shutdown

Every bot must handle:
```
process.on('SIGINT', ...)   // Ctrl+C
process.on('SIGTERM', ...)  // Docker/PM2 stop
```
Destroy the client, close database connections, flush logs.

### Process Error Handling

```
process.on('unhandledRejection', ...)  // Log, don't crash
process.on('uncaughtException', ...)   // Log and exit (let PM2/Docker restart)
```

---

## Deciding: Sapphire vs Raw Discord.js

**Use raw discord.js when:**
- The bot has fewer than ~10 commands
- It's a single-purpose bot (e.g., only does welcome messages)
- The user wants minimal dependencies
- The user explicitly asks for no framework

**Use Sapphire when:**
- The bot has 10+ commands
- Multiple command categories (moderation + utility + fun)
- Need built-in preconditions (cooldowns, permissions, NSFW checks)
- The user wants plugin-based architecture
- The bot will grow over time

When using Sapphire, leverage its features:
- `Preconditions` for permission checks and cooldowns
- `Listeners` for event handling
- `InteractionHandlers` for components (buttons, menus, modals)
- `@sapphire/plugin-subcommands` for complex command groups

---

## Common Mistakes to Prevent

These are patterns that cause real production issues. The generated code must avoid all of them:

1. **Registering commands on every startup** — Causes rate limits. Use `deploy-commands.ts` separately.
2. **Missing intents** — Results in silent failures (empty `message.content`, events not firing). Always match intents to features.
3. **No `deferReply()` for slow operations** — Interaction fails after 3 seconds. Any database query, API call, or file operation should defer.
4. **Unbounded cache growth** — Bots in many servers will OOM without cache limits and sweepers.
5. **Storing snowflake IDs as numbers** — Discord IDs exceed `Number.MAX_SAFE_INTEGER`. Always use `String` or `BigInt`.
6. **No error handling on interactions** — One uncaught error crashes the entire event loop. Always try/catch.
7. **`eval()` with user input** — Never. Not even in "admin-only" commands.
8. **Hardcoded token** — Always `.env`. Add `.env` to `.gitignore` before the first commit.
9. **Modal after deferReply** — Modals must be the first response to an interaction. Cannot defer first.
10. **Mass DM on member join** — Many users have DMs disabled. Always handle the error silently.
11. **Editing messages in a loop** — Hits rate limits (5 edits/5s per channel). Batch updates.
12. **No graceful shutdown** — Causes dangling connections, incomplete database writes, and reconnection storms.
13. **Untyped error callbacks in strict mode** — `.catch((err) => ...)` and `.on('error', (err) => ...)` fail with `noImplicitAny`. Always annotate: `.catch((err: Error) => ...)`.
14. **Wrong ioredis constructor in ESM** — `new Redis(url)` fails because `import Redis from 'ioredis'` is a namespace in ESM. Use `new Redis.default(url, opts)`.
15. **Shoukaku v4 API mismatch** — `node.joinChannel()` and `player.connection.disconnect()` are Shoukaku v3 patterns. In v4, use `shoukaku.joinVoiceChannel()` and `shoukaku.leaveVoiceChannel()` / `player.destroy()`.
16. **Accessing `.threads`/`.send()`/`.sendTyping()` without narrowing** — `TextBasedChannel` includes types like `PartialGroupDMChannel` that lack these methods. Always use `'threads' in channel` or similar type guards first.

---

## Combined Bot + Web Dashboard Architecture

When the user wants a web dashboard alongside their Discord bot, this skill handles the **bot** and the **fullstack-application** skill handles the **web application**. Both share the same database and coordinate via Redis pub/sub for real-time config updates.

### When to invoke the fullstack-application skill

Invoke the `fullstack-application` skill when the user answers "yes" to needing a web dashboard. This skill remains the primary orchestrator — it handles the bot, the shared database schema, and the integration points. The fullstack-application skill handles the web app scaffolding, frontend, and API.

### How the two skills work together

```
┌─────────────────────────────┐     ┌──────────────────────────────┐
│  Discord Bot (this skill)   │     │  Web Dashboard (fullstack    │
│  - discord.js v14           │     │  -application skill)         │
│  - Event handlers           │     │  - React + NestJS            │
│  - Slash commands            │     │  - Admin UI                  │
│  - Background tasks         │     │  - Discord OAuth2            │
└────────────┬────────────────┘     └──────────────┬───────────────┘
             │                                      │
             ▼                                      ▼
      ┌──────────────┐                    ┌──────────────┐
      │  PostgreSQL   │◄──── shared ─────►│    Redis      │
      │  (Prisma)     │     database      │  (pub/sub +   │
      └──────────────┘                    │   cache)      │
                                          └──────────────┘
```

### What this skill is responsible for (bot side)

1. **Shared Prisma schema** — The bot owns the database schema. Design `GuildConfig` and all bot-specific models in the bot's `prisma/schema.prisma`. The web app connects to the same database using the same Prisma schema (published as a shared package or imported directly).

2. **Redis pub/sub listener** — The bot subscribes to a `config-update` channel. When the dashboard saves a config change, it publishes to this channel, and the bot invalidates its local cache immediately instead of waiting for a TTL expiry.

   ```ts
   // In the bot's startup:
   const subscriber = redis.duplicate();
   await subscriber.subscribe('config-update');
   subscriber.on('message', (channel, message) => {
     const { guildId } = JSON.parse(message);
     guildConfigCache.delete(guildId);
     logger.info({ guildId }, 'Config cache invalidated by dashboard');
   });
   ```

3. **Bot API endpoints (optional)** — If the dashboard needs data only the bot can provide (e.g., live guild member counts, channel lists, role hierarchies), the bot can expose a lightweight internal HTTP API. This API is **not** public-facing — it's only accessible from the dashboard backend within the same network.

4. **Discord OAuth2 guidance** — The dashboard authenticates users via Discord OAuth2 (`identify` + `guilds` scopes). Read `references/integrations.md` for the OAuth2 flow. The dashboard should filter guilds to those where the user has `MANAGE_GUILD` permission, matching what Discord shows in the bot invite flow.

### What the fullstack-application skill handles (web side)

When invoking the fullstack-application skill for the dashboard, provide it with this context:

- **Auth**: Discord OAuth2 (not Google OAuth) — the user authenticates with their Discord account
- **Database**: Connects to the same PostgreSQL instance as the bot, using the same Prisma schema
- **Key pages**: Server selector (list guilds the user manages), per-server config panels, analytics/stats views
- **Real-time**: Redis pub/sub to notify the bot of config changes; optionally WebSockets to push live bot stats to the dashboard
- **API design**: RESTful endpoints scoped by guild (`/api/guilds/:id/config`, `/api/guilds/:id/stats`, etc.)

The fullstack-application skill will handle the Turborepo monorepo setup, React frontend, NestJS API, Docker, CI/CD, and all the web-side concerns.

### Monorepo structure for combined projects

When both bot and dashboard exist, the recommended structure is a monorepo:

```
my-bot/
├── apps/
│   ├── bot/              ← Discord bot (this skill generates this)
│   ├── api/              ← Dashboard backend (fullstack skill generates this)
│   └── web/              ← Dashboard frontend (fullstack skill generates this)
├── packages/
│   ├── database/         ← Shared Prisma schema + client
│   ├── shared/           ← Shared types, constants, DTOs
│   └── config/           ← Shared tsconfig, biome config
├── infrastructure/
│   ├── docker/
│   │   ├── bot.Dockerfile
│   │   ├── api.Dockerfile
│   │   └── web.Dockerfile
│   ├── docker-compose.yml       ← All services: bot + api + web + postgres + redis
│   └── docker-compose.prod.yml
├── turbo.json
├── pnpm-workspace.yaml
└── package.json
```

The bot lives at `apps/bot/` instead of being the root project. The Prisma schema moves to `packages/database/` so both the bot and the API import from the same source. This is a significant structural difference from a bot-only project — if the user initially creates a bot and later adds a dashboard, the project will need to be restructured into this monorepo layout.

### Workflow when dashboard is requested

1. Complete the bot interview (Step 2) as normal, including the expanded dashboard questions
2. Generate the bot code (Step 3) as normal, but using the monorepo structure above
3. Design the shared Prisma schema in `packages/database/` with all models both the bot and dashboard need
4. **Invoke the fullstack-application skill** to scaffold `apps/api/` and `apps/web/`, telling it:
   - Project name and description (from the interview)
   - Auth method: Discord OAuth2 (provide the OAuth2 flow from `references/integrations.md`)
   - Database: Use the shared `packages/database/` Prisma package — do not create a separate schema
   - Features: Guild config management, whatever analytics/admin features the user requested
   - Deployment: Match the bot's deployment choice (Docker Compose, etc.)
5. Wire up the Redis pub/sub integration between bot and dashboard
6. Update `docker-compose.yml` to include all services
7. Present the complete file list and walk through the combined setup
