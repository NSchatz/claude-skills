---
name: discord-bot
description: Complete Discord bot project generator and guide. Use this skill whenever the user wants to create a Discord bot, scaffold a Discord bot project, add features to an existing Discord bot, set up slash commands, configure Discord.js, handle Discord events, implement moderation/music/economy/leveling/ticket/utility bot features, set up sharding, deploy a Discord bot, or work with the Discord API in any capacity. Also trigger when the user mentions discord.js, Discord intents, Discord slash commands, Discord components (buttons, select menus, modals), Discord gateway, bot tokens, or any Discord bot development topic. Always use this skill for any Discord bot work — even simple questions about a single command or event handler.
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
| Package Manager | pnpm |

Use this stack by default. If the user explicitly requests alternatives (JavaScript, discord.py, MongoDB, etc.), adapt — but recommend this stack first and explain why.

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
- Do you need a web dashboard for server admins to configure the bot?
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
2. **Environment** — Copy `.env.example` to `.env`, fill in token, client ID, database URL
3. **Database** — Run `docker compose up -d db` (if using Docker Compose), then `npx prisma migrate dev`
4. **Deploy commands** — Run `npx tsx src/deploy-commands.ts` to register slash commands
5. **Start the bot** — `npx tsx src/index.ts` for development, `docker compose up` for production
6. **Invite the bot** — Provide the OAuth2 URL with the correct permissions and scopes

List exactly which privileged intents need to be enabled in the Developer Portal and why.

---

## Code Patterns and Standards

These apply to all generated code:

### TypeScript

- Strict mode on (`"strict": true` in tsconfig)
- No `any` types — use `unknown` + type guards or proper discord.js types
- Use `const enum` or object literals for constants, not magic strings
- ES2022 target, Node16 module resolution

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
