---
title: Security Best Practices
weight: 7
---

# Security Best Practices

## Table of Contents

1. [Token Security](#token-security)
2. [Input Sanitization](#input-sanitization)
3. [Permission Checks](#permission-checks)
4. [Anti-Raid Protection](#anti-raid-protection)
5. [Dependency Security](#dependency-security)
6. [Process Isolation](#process-isolation)
7. [Rate Limiting](#rate-limiting)
8. [Webhook Security](#webhook-security)

---

## Token Security

### The basics

- **Never** commit tokens to version control. Use `.env` files with `dotenv`.
- Add `.env` to `.gitignore` **before the first commit**.
- If a token is leaked (even briefly), **regenerate it immediately** in the Discord Developer Portal. Automated scrapers on GitHub find exposed tokens within minutes.
- Token format: tokens are base64-encoded and contain the bot's user ID. Anyone can extract the bot ID from a token.

### .env pattern

```env
DISCORD_TOKEN=your-bot-token-here
```

```ts
import 'dotenv/config';
// Token is accessed only through the validated config module
```

### Production secrets

- **VPS**: `.env` file with restricted permissions (`chmod 600 .env`)
- **Docker**: Environment variables via `docker-compose.yml` or Docker secrets
- **CI/CD**: GitHub Actions secrets, never in workflow files
- **Cloud platforms**: Platform-specific secret management (Railway env vars, Fly.io secrets)

### What to do if a token leaks

1. Go to Discord Developer Portal > Bot > Reset Token
2. Update the token in all deployment environments
3. Check audit logs for unauthorized activity
4. Review git history — if the token was committed, it's in the history even after removal. Consider using `git-filter-repo` to purge it.

---

## Input Sanitization

### Never use eval() with user input

This is the #1 security rule. No exceptions, not even for "admin-only" commands:

```ts
// NEVER DO THIS
eval(interaction.options.getString('code'));

// NEVER DO THIS EITHER
new Function(userInput)();

// Also avoid:
require(userInput);
import(userInput);
```

### Mention injection

User input in message content can contain mentions that ping everyone:

```ts
// BAD: User input can contain @everyone, @here, role mentions
await channel.send(userInput);

// GOOD: Disable all mentions
await channel.send({
  content: userInput,
  allowedMentions: { parse: [] },
});

// Or selectively allow:
await channel.send({
  content: `Welcome ${user}!`,
  allowedMentions: { users: [user.id] }, // Only allow this specific user mention
});
```

### SQL injection

Prisma and other ORMs handle parameterization automatically. If using raw queries:

```ts
// BAD
const result = await prisma.$queryRawUnsafe(`SELECT * FROM users WHERE id = '${userId}'`);

// GOOD
const result = await prisma.$queryRaw`SELECT * FROM users WHERE id = ${userId}`;
```

### Command injection

If shelling out to external processes:

```ts
import { execFile } from 'node:child_process';

// BAD: String interpolation in shell command
exec(`ffmpeg -i ${userInput} output.mp3`);

// GOOD: Argument array (no shell interpretation)
execFile('ffmpeg', ['-i', userInput, 'output.mp3']);
```

### Path traversal

If the bot reads/writes files based on user input:

```ts
import { resolve, join } from 'node:path';

const SAFE_DIR = '/opt/discord-bot/uploads';

function safePath(userInput: string): string {
  const resolved = resolve(join(SAFE_DIR, userInput));
  if (!resolved.startsWith(SAFE_DIR)) {
    throw new Error('Path traversal attempt');
  }
  return resolved;
}
```

---

## Permission Checks

### Always verify permissions at runtime

Don't rely solely on Discord's `setDefaultMemberPermissions` — it's a UI hint that can be overridden by server admins. Validate in the command handler:

```ts
async execute(interaction: ChatInputCommandInteraction) {
  // Check user has permission
  if (!interaction.memberPermissions?.has(PermissionFlagsBits.BanMembers)) {
    return interaction.reply({ content: 'You need Ban Members permission.', ephemeral: true });
  }

  // Check bot has permission
  const botMember = interaction.guild!.members.me!;
  if (!botMember.permissions.has(PermissionFlagsBits.BanMembers)) {
    return interaction.reply({ content: 'I need Ban Members permission.', ephemeral: true });
  }

  // Check role hierarchy
  const target = await interaction.guild!.members.fetch(targetUser.id);
  if (target.roles.highest.position >= botMember.roles.highest.position) {
    return interaction.reply({ content: 'I cannot moderate this user — their role is too high.', ephemeral: true });
  }

  // Also check user vs target hierarchy (prevent mods from banning other mods)
  const member = interaction.member as GuildMember;
  if (target.roles.highest.position >= member.roles.highest.position) {
    return interaction.reply({ content: 'You cannot moderate someone with an equal or higher role.', ephemeral: true });
  }
}
```

### Channel-specific permission checks

```ts
const channel = interaction.channel!;
const botPerms = channel.permissionsFor(interaction.guild!.members.me!);

if (!botPerms?.has(PermissionFlagsBits.SendMessages)) {
  return interaction.reply({ content: 'I cannot send messages in that channel.', ephemeral: true });
}
```

### Owner-only commands

For dangerous commands (shutdown, eval debug, global announcements):

```ts
const OWNER_IDS = ['123456789', '987654321']; // Hardcoded, not configurable via commands

if (!OWNER_IDS.includes(interaction.user.id)) {
  return interaction.reply({ content: 'This command is restricted to bot owners.', ephemeral: true });
}
```

---

## Anti-Raid Protection

### Join rate detection

Track joins per time window. If the rate exceeds a threshold, trigger lockdown:

```ts
const joinLog = new Map<string, number[]>(); // guildId -> timestamps

function detectRaid(guildId: string, threshold: number, windowMs: number): boolean {
  const now = Date.now();
  const timestamps = joinLog.get(guildId) ?? [];

  // Remove entries outside the window
  const recent = timestamps.filter(t => now - t < windowMs);
  recent.push(now);
  joinLog.set(guildId, recent);

  return recent.length >= threshold;
}

// In guildMemberAdd:
if (detectRaid(member.guild.id, 10, 10_000)) { // 10 joins in 10 seconds
  // Trigger lockdown:
  // 1. Set verification level to highest
  // 2. Alert moderators in the log channel
  // 3. Optionally enable slowmode in all text channels
}
```

### Account age filtering

```ts
const MINIMUM_ACCOUNT_AGE_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

client.on('guildMemberAdd', async (member) => {
  const accountAge = Date.now() - member.user.createdTimestamp;
  if (accountAge < MINIMUM_ACCOUNT_AGE_MS) {
    // Log as suspicious, optionally quarantine (add a restricted role)
    logger.warn({
      userId: member.id,
      guildId: member.guild.id,
      accountAgeDays: Math.floor(accountAge / 86400000),
    }, 'New account joined');
  }
});
```

### Message spam detection

```ts
const messageLog = new Map<string, number[]>(); // `${guildId}:${userId}` -> timestamps

function isSpamming(guildId: string, userId: string, maxMessages: number, windowMs: number): boolean {
  const key = `${guildId}:${userId}`;
  const now = Date.now();
  const timestamps = (messageLog.get(key) ?? []).filter(t => now - t < windowMs);
  timestamps.push(now);
  messageLog.set(key, timestamps);
  return timestamps.length > maxMessages;
}

// In messageCreate:
if (isSpamming(message.guildId!, message.author.id, 5, 3000)) { // 5 messages in 3 seconds
  await message.member?.timeout(60_000, 'Auto-mod: spam detection');
}
```

---

## Dependency Security

### Audit dependencies regularly

```bash
pnpm audit
```

### Pin major versions

In `package.json`, use caret (`^`) for minor/patch updates but review major version changes:

```json
"discord.js": "^14.16.0",
"@prisma/client": "^6.0.0"
```

### Watch for typosquatting

The Discord bot ecosystem has seen supply chain attacks with packages named similarly to popular Discord libraries. Always verify package names before installing:

- `discord.js` (correct) vs `discord.js-selfbot` (malicious)
- `@discordjs/voice` (correct) vs `discord-voice` (unknown)

### Lock files

Always commit `pnpm-lock.yaml`. Use `--frozen-lockfile` in CI to ensure reproducible builds.

---

## Process Isolation

- Run the bot as a **non-root user** (both on VPS and in Docker)
- In Docker, use the `USER` directive in the Dockerfile
- On a VPS, create a dedicated `botuser` with minimal permissions
- Limit file system access to only what's needed
- Use systemd hardening options (`NoNewPrivileges`, `ProtectSystem`, `ProtectHome`)

---

## Rate Limiting

### Discord's rate limits

| Action | Limit | Notes |
|--------|-------|-------|
| Send message | 5 per 5s per channel | |
| Edit message | 5 per 5s per channel | Shares bucket with send |
| Delete message | 5 per 1s per channel | |
| Bulk delete | 1 per 1s per channel | Up to 100 messages |
| Add reaction | 1 per 0.25s per channel | Very restrictive |
| Edit channel | 2 per 10min per channel | |
| Ban member | 30 per 30s per guild | |
| Global | 50 per second | Across all routes |

### discord.js handles rate limits automatically

The REST handler queues requests and respects rate limit headers. Monitor for issues:

```ts
client.rest.on('rateLimited', (info) => {
  logger.warn({
    route: info.route,
    timeout: info.timeToReset,
    global: info.global,
  }, 'Rate limited');
});
```

### User-facing rate limiting

Implement cooldowns on commands to prevent abuse:

```ts
// Per-command cooldowns (in interactionCreate handler)
const cooldownMs = (command.cooldown ?? 3) * 1000;
```

For more sophisticated rate limiting, use Redis:

```ts
async function rateLimit(key: string, maxRequests: number, windowSeconds: number): Promise<boolean> {
  const current = await redis.incr(key);
  if (current === 1) {
    await redis.expire(key, windowSeconds);
  }
  return current <= maxRequests;
}

// Usage:
const allowed = await rateLimit(`cmd:${interaction.user.id}:daily`, 1, 86400);
```

---

## Webhook Security

If the bot exposes webhook endpoints (for GitHub, Twitch, etc.), always verify the incoming request:

### GitHub webhook verification

```ts
import { createHmac } from 'node:crypto';

function verifyGitHubWebhook(payload: string, signature: string, secret: string): boolean {
  const expected = 'sha256=' + createHmac('sha256', secret).update(payload).digest('hex');
  return signature === expected;
}
```

### General webhook security

- Always verify signatures/secrets
- Use HTTPS endpoints
- Validate the request body structure before processing
- Rate limit incoming webhooks
- Log and alert on verification failures
