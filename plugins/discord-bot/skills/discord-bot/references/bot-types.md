---
title: Bot Types and Command Sets
weight: 3
---

# Bot Types and Command Sets

Use this reference to determine which commands and features to generate based on the bot type the user selected during the interview. Each section includes the slash commands, events, database models, and intents required.

## Table of Contents

1. [Moderation](#moderation)
2. [Music](#music)
3. [Economy / RPG](#economy--rpg)
4. [Leveling / XP](#leveling--xp)
5. [Utility](#utility)
6. [Tickets](#tickets)
7. [Welcome / Goodbye](#welcome--goodbye)
8. [AI Chatbot](#ai-chatbot)
9. [Multi-Purpose](#multi-purpose)

---

## Moderation

### Commands

| Command | Description | Permissions |
|---------|------------|-------------|
| `/ban <user> [reason] [days]` | Ban a user, optionally delete N days of messages | `BanMembers` |
| `/unban <user-id> [reason]` | Unban a user by ID | `BanMembers` |
| `/kick <user> [reason]` | Kick a user from the server | `KickMembers` |
| `/timeout <user> <duration> [reason]` | Timeout a user (1min - 28 days) | `ModerateMembers` |
| `/untimeout <user> [reason]` | Remove timeout from a user | `ModerateMembers` |
| `/warn <user> <reason>` | Issue a warning (stored in DB) | `ModerateMembers` |
| `/warnings <user>` | View warnings for a user | `ModerateMembers` |
| `/clearwarnings <user>` | Clear all warnings for a user | `ManageGuild` |
| `/purge <count> [user] [filter]` | Bulk delete messages (max 100, < 14 days old) | `ManageMessages` |
| `/slowmode <seconds> [channel]` | Set channel slowmode (0 = off, max 21600) | `ManageChannels` |
| `/lockdown [channel]` | Deny send messages for @everyone in a channel | `ManageChannels` |
| `/unlock [channel]` | Restore send messages for @everyone | `ManageChannels` |
| `/modlog <user>` | View full moderation history for a user | `ModerateMembers` |

### Events

- `guildMemberAdd` — Log new member joins
- `guildMemberRemove` — Log leaves/kicks
- `guildBanAdd` / `guildBanRemove` — Log bans/unbans
- `messageDelete` — Log deleted messages (requires message cache or `Partials.Message`)
- `messageUpdate` — Log edited messages

### Required Intents

```ts
GatewayIntentBits.Guilds,
GatewayIntentBits.GuildMessages,
GatewayIntentBits.GuildMembers,       // PRIVILEGED
GatewayIntentBits.MessageContent,     // PRIVILEGED (for logging deleted message content)
```

### Database Models

```prisma
model GuildConfig {
  id            String   @id // guild snowflake
  logChannelId  String?
  muteRoleId    String?
  automod       Boolean  @default(false)
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt
}

model ModAction {
  id          Int      @id @default(autoincrement())
  guildId     String
  userId      String
  moderatorId String
  action      String   // "ban", "kick", "timeout", "warn", "unban"
  reason      String?
  duration    Int?     // seconds, for timeout/tempban
  createdAt   DateTime @default(now())

  @@index([guildId, userId])
  @@index([guildId])
}
```

### Implementation Notes

- **Purge**: Discord's bulk delete API only works on messages < 14 days old. For older messages, delete individually (rate limited to 5/1s). Always tell the user how many messages were actually deleted.
- **Lockdown**: Store the previous permission state before overriding so `unlock` can restore it cleanly.
- **Warn escalation**: Configurable thresholds (e.g., 3 warns = timeout, 5 warns = ban). Store threshold config in `GuildConfig`.
- **Duration parsing**: Use a utility that accepts human-readable durations ("30m", "2h", "7d"). The `ms` npm package works well.
- **DM before action**: Attempt to DM the user with the reason before banning/kicking. Wrap in try/catch since many users have DMs disabled.
- **Role hierarchy**: Always check that the bot's highest role is above the target's highest role before moderating.
- **Audit log reason**: Pass the reason string to Discord's API (`member.ban({ reason })`) so it appears in the server's audit log.

---

## Music

### Commands

| Command | Description |
|---------|------------|
| `/play <query>` | Play a song (URL or search query) |
| `/skip` | Skip the current song |
| `/queue [page]` | Show the queue (paginated) |
| `/pause` | Pause playback |
| `/resume` | Resume playback |
| `/stop` | Stop playback and clear queue |
| `/nowplaying` | Show the currently playing track |
| `/volume <1-100>` | Set playback volume |
| `/shuffle` | Shuffle the queue |
| `/loop <off\|track\|queue>` | Set loop mode |
| `/seek <position>` | Seek to a position in the current track |
| `/remove <position>` | Remove a track from the queue |

### Required Infrastructure

Music bots need **Lavalink** — a standalone Java audio server that handles audio streaming:

- Lavalink v4 requires Java 17+
- Node.js client: `shoukaku` (recommended, actively maintained)
- Docker setup recommended: run Lavalink as a separate container

```yaml
# docker-compose.yml addition
lavalink:
  image: ghcr.io/lavalink-devs/lavalink:4
  environment:
    - LAVALINK_SERVER_PASSWORD=youshallnotpass
    - SERVER_PORT=2333
  ports:
    - "2333:2333"
  restart: unless-stopped
```

### Required Intents

```ts
GatewayIntentBits.Guilds,
GatewayIntentBits.GuildVoiceStates,   // Required for voice channel tracking
```

### Implementation Notes

- The bot must join the user's voice channel before playing. Check that the user is in a voice channel first.
- Handle disconnect events (user leaves, bot gets moved, voice channel deleted).
- Implement an inactivity timeout — leave the voice channel if nothing is playing for N minutes.
- Queue is per-guild, stored in memory (not database — music state is ephemeral).
- YouTube extraction is legally gray. Default to SoundCloud, Spotify metadata resolution, or direct URLs.
- Volume control is done through Lavalink filters, not discord.js.

---

## Economy / RPG

### Commands

| Command | Description |
|---------|------------|
| `/balance [user]` | Check balance (wallet + bank) |
| `/daily` | Claim daily reward (24h cooldown) |
| `/work` | Earn coins (1h cooldown, random amount) |
| `/pay <user> <amount>` | Transfer coins to another user |
| `/deposit <amount>` | Move coins from wallet to bank |
| `/withdraw <amount>` | Move coins from bank to wallet |
| `/shop` | View available items |
| `/buy <item> [quantity]` | Purchase an item |
| `/inventory [user]` | View inventory |
| `/leaderboard [page]` | Top users by balance |
| `/gamble <amount>` | Coin flip gambling |
| `/rob <user>` | Attempt to steal from another user (fail chance) |

### Database Models

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
  lastRob   DateTime?

  @@unique([guildId, userId])
  @@index([guildId])
}

model ShopItem {
  id          String @id @default(cuid())
  guildId     String
  name        String
  description String
  price       Int
  roleId      String?   // Grant a role on purchase
  maxQuantity Int       @default(-1) // -1 = unlimited
  createdAt   DateTime  @default(now())

  @@index([guildId])
}

model Inventory {
  id       String @id @default(cuid())
  guildId  String
  userId   String
  itemId   String
  quantity Int    @default(1)

  @@unique([guildId, userId, itemId])
}

model Transaction {
  id        Int      @id @default(autoincrement())
  guildId   String
  fromId    String
  toId      String
  amount    Int
  type      String   // "transfer", "daily", "work", "shop", "gamble", "rob"
  createdAt DateTime @default(now())

  @@index([guildId, fromId])
  @@index([guildId, toId])
}
```

### Implementation Notes

- **Race conditions**: Use database transactions for all balance modifications. Two concurrent `/pay` commands could overdraw without transactions.
- **Cooldowns**: Use Redis `SET key EX seconds` for cooldown tracking (survives bot restarts). Fall back to in-memory `Collection` if Redis isn't available.
- **Rob mechanics**: Configurable success chance (default ~40%), penalty on failure (fine), cooldown (2h). Cannot rob users with 0 balance.
- **Leaderboard pagination**: Use cursor-based pagination with embeds and buttons for prev/next.
- **Anti-exploit**: New accounts (< 7 days in server) have transfer restrictions. Self-transfer prevention. Maximum transfer amounts.

---

## Leveling / XP

### Commands

| Command | Description |
|---------|------------|
| `/rank [user]` | Show rank card (generated image) |
| `/leaderboard [page]` | Server XP leaderboard |
| `/rewards` | List level-up role rewards |
| `/addreward <level> <role>` | Add a role reward at a level |
| `/removereward <level>` | Remove a role reward |
| `/setxp <user> <amount>` | Admin: set user XP |
| `/resetxp [user]` | Admin: reset user XP |

### XP Algorithm

```ts
// XP per message: random 15-25, with 60-second cooldown per user
const XP_MIN = 15;
const XP_MAX = 25;
const XP_COOLDOWN_MS = 60_000;

// Level formula (MEE6-style):
function xpForLevel(level: number): number {
  return 5 * level * level + 50 * level + 100;
}

function levelFromTotalXp(totalXp: number): number {
  let level = 0;
  let remaining = totalXp;
  while (remaining >= xpForLevel(level)) {
    remaining -= xpForLevel(level);
    level++;
  }
  return level;
}
```

### Events

- `messageCreate` — Award XP on each message (with cooldown). Check for level-up and award roles.

### Required Intents

```ts
GatewayIntentBits.Guilds,
GatewayIntentBits.GuildMessages,
GatewayIntentBits.GuildMembers,     // PRIVILEGED: for role management
```

### Database Models

```prisma
model UserLevel {
  id       String @id @default(cuid())
  guildId  String
  userId   String
  xp       Int    @default(0)
  level    Int    @default(0)
  messages Int    @default(0)
  lastXpAt DateTime?

  @@unique([guildId, userId])
  @@index([guildId, level(sort: Desc)])
}

model LevelReward {
  id      String @id @default(cuid())
  guildId String
  level   Int
  roleId  String

  @@unique([guildId, level])
  @@index([guildId])
}
```

### Implementation Notes

- **Rank card generation**: Use `@napi-rs/canvas` (modern, fast, minimal native deps). Draw: avatar (circular crop), username, level, XP progress bar, rank number, optional custom background.
- **Role rewards**: On level-up, check all configured rewards at or below the new level. Add any missing roles. Check role hierarchy before attempting.
- **Performance**: XP tracking fires on every message. Use Redis or in-memory cache for cooldowns — don't hit the database on every message, only when XP is actually awarded.
- **Ignored channels**: Allow admins to configure channels where XP isn't earned (e.g., bot-commands channels).

---

## Utility

### Commands

| Command | Description |
|---------|------------|
| `/ping` | Bot latency and API latency |
| `/serverinfo` | Server metadata (members, channels, boost level, etc.) |
| `/userinfo [user]` | User metadata (account age, join date, roles) |
| `/avatar [user]` | Show user's avatar (full size, with link) |
| `/banner [user]` | Show user's banner (if set) |
| `/poll <question> <option1> <option2> [...]` | Create a poll with buttons |
| `/remind <duration> <message>` | Set a reminder (DM after duration) |
| `/embed` | Interactive embed builder (modal-based) |
| `/roleinfo <role>` | Role metadata (color, members, permissions) |
| `/channelinfo [channel]` | Channel metadata |

### Implementation Notes

- **Reminders**: Store in database with scheduled execution time. On startup, load all pending reminders and schedule them. Use `setTimeout` for near-term, periodic check (every minute) for long-term.
- **Polls**: Use buttons for voting, embed for display. Track votes in-memory or database. Show results when poll ends (configurable duration).
- **Embed builder**: Use a modal for title/description/color, then buttons to add fields, set image, etc. Preview after each step.

---

## Tickets

### Commands

| Command | Description |
|---------|------------|
| `/ticket setup <category> <channel>` | Set up the ticket panel (button in a channel) |
| `/ticket close [reason]` | Close the current ticket |
| `/ticket add <user>` | Add a user to the current ticket |
| `/ticket remove <user>` | Remove a user from the current ticket |
| `/ticket claim` | Claim the ticket (staff) |
| `/ticket rename <name>` | Rename the ticket channel |
| `/ticket transcript` | Generate and send a transcript |

### Flow

1. Admin runs `/ticket setup` — bot sends an embed with a "Create Ticket" button in the designated channel
2. User clicks the button — bot creates a private thread (or channel) visible to the user + support role
3. Bot sends a welcome message with ticket info and a "Close" button
4. Staff can claim, add/remove users, and eventually close
5. On close — generate HTML transcript, send to a log channel, then delete the thread/channel after a delay

### Database Models

```prisma
model TicketConfig {
  id          String @id @default(cuid())
  guildId     String
  categoryId  String?  // Channel category for ticket channels
  supportRoleId String
  logChannelId String?
  panelChannelId String
  panelMessageId String?
  greeting    String   @default("A staff member will be with you shortly.")
  maxOpen     Int      @default(3) // max open tickets per user

  @@unique([guildId])
}

model Ticket {
  id          Int      @id @default(autoincrement())
  guildId     String
  channelId   String   @unique
  userId      String   // who opened it
  claimedById String?
  status      String   @default("open") // "open", "closed"
  createdAt   DateTime @default(now())
  closedAt    DateTime?

  @@index([guildId, userId])
  @@index([guildId, status])
}
```

### Implementation Notes

- **Threads vs channels**: Private threads are cleaner (no channel clutter), but channels give more permission control. Default to threads; offer channel mode as a config option.
- **Transcripts**: Use the `discord-html-transcripts` package for good-looking HTML transcripts. Upload to the log channel as a file attachment.
- **Max tickets**: Enforce a per-user limit to prevent abuse.
- **Button persistence**: The "Create Ticket" button must work after bot restarts. Use a stable `customId` (e.g., `ticket:create`) and handle it in the component router, not a collector.

---

## Welcome / Goodbye

### Events

- `guildMemberAdd` — Send welcome message, assign auto-role
- `guildMemberRemove` — Send goodbye message

### Configuration Commands

| Command | Description |
|---------|------------|
| `/welcome channel <channel>` | Set welcome message channel |
| `/welcome message <template>` | Set welcome message template |
| `/welcome toggle` | Enable/disable welcome messages |
| `/welcome autorole <role>` | Set auto-role on join |
| `/welcome test` | Send a test welcome message |
| `/goodbye channel <channel>` | Set goodbye message channel |
| `/goodbye message <template>` | Set goodbye message template |
| `/goodbye toggle` | Enable/disable goodbye messages |

### Template Variables

```
{user}         — User mention (@User)
{user.tag}     — Username#0000
{user.name}    — Username
{server}       — Server name
{memberCount}  — Current member count
{user.avatar}  — User avatar URL
```

### Required Intents

```ts
GatewayIntentBits.Guilds,
GatewayIntentBits.GuildMembers,     // PRIVILEGED: required for join/leave events
```

### Database Models

```prisma
model WelcomeConfig {
  id              String  @id // guild snowflake
  welcomeEnabled  Boolean @default(false)
  welcomeChannel  String?
  welcomeMessage  String  @default("Welcome to {server}, {user}! You are member #{memberCount}.")
  goodbyeEnabled  Boolean @default(false)
  goodbyeChannel  String?
  goodbyeMessage  String  @default("Goodbye {user.tag}, we'll miss you!")
  autoRoleId      String?
}
```

### Implementation Notes

- **DM welcome**: Optional — many users have DMs disabled. Always wrap in try/catch.
- **Auto-role**: Check bot role hierarchy. The auto-role must be below the bot's highest role.
- **Welcome images**: Optional advanced feature using `@napi-rs/canvas`. Generate an image with the user's avatar, server name, and member count.

---

## AI Chatbot

### Commands

| Command | Description |
|---------|------------|
| `/ask <question>` | Ask a question (single turn, no history) |
| `/chat` | Start a conversation thread |
| `/setchannel <channel>` | Set an always-listening AI channel |
| `/persona <name>` | Set the bot's personality/system prompt |

### Implementation Patterns

**Single-turn (`/ask`)**: Send the question to the LLM API, return the response in an embed. Defer the reply since API calls take 2-10 seconds.

**Thread-based (`/chat`)**: Create a thread, maintain conversation history within it. On each message in the thread, collect the last N messages as context and send to the LLM.

**Always-listening channel**: Configure a channel where every message gets an AI response. Track conversation context per channel with a rolling window.

### Cost Management

- Set per-user rate limits (e.g., 10 messages per hour)
- Use cheaper models for simple queries, expensive models for complex ones
- Cache common responses
- Set maximum context window size (e.g., last 20 messages)

### Streaming Responses

Discord rate limits message edits to ~5 per 5 seconds per channel. For streaming LLM responses:

```ts
// Batch updates every 1.5 seconds
let buffer = '';
let lastEdit = 0;
const EDIT_INTERVAL = 1500;

for await (const chunk of stream) {
  buffer += chunk;
  const now = Date.now();
  if (now - lastEdit >= EDIT_INTERVAL) {
    await interaction.editReply(buffer);
    lastEdit = now;
  }
}
// Final edit with complete response
await interaction.editReply(buffer);
```

### Required Environment Variables

```env
OPENAI_API_KEY=sk-...
# or
ANTHROPIC_API_KEY=sk-ant-...
```

---

## Multi-Purpose

When the user wants a bot that combines multiple categories, generate all the relevant commands from each category above. Shared patterns:

- Single `GuildConfig` model that encompasses all module settings
- Module enable/disable flags in config (`enableEconomy`, `enableLeveling`, etc.)
- `/config` command with subcommand groups per module
- Shared event handlers that check which modules are enabled before running

The interactionCreate handler should route to the appropriate command regardless of category. The event handlers should check guild config to see if the relevant module is enabled.
