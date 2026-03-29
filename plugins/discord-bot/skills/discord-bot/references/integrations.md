---
title: Integrations
weight: 8
---

# Integrations

## Table of Contents

1. [AI / LLM Chatbot](#ai--llm-chatbot)
2. [Webhook Feeds (GitHub, Twitch, YouTube)](#webhook-feeds)
3. [Music with Lavalink](#music-with-lavalink)
4. [Web Dashboard](#web-dashboard)
5. [Image Generation](#image-generation)

---

## AI / LLM Chatbot

### Single-turn command (/ask)

```ts
import Anthropic from '@anthropic-ai/sdk';

const anthropic = new Anthropic({ apiKey: config.ANTHROPIC_API_KEY });

// Command: /ask <question>
async execute(interaction: ChatInputCommandInteraction) {
  await interaction.deferReply();

  const question = interaction.options.getString('question', true);

  try {
    const response = await anthropic.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1024,
      messages: [{ role: 'user', content: question }],
    });

    const answer = response.content[0].type === 'text' ? response.content[0].text : 'No response';

    // Discord message limit is 2000 chars
    if (answer.length > 2000) {
      await interaction.editReply(answer.slice(0, 1997) + '...');
    } else {
      await interaction.editReply(answer);
    }
  } catch (error) {
    logger.error(error, 'AI API error');
    await interaction.editReply('Failed to get a response. Please try again.');
  }
}
```

### Thread-based conversation (/chat)

```ts
// /chat — creates a thread and maintains conversation history

async execute(interaction: ChatInputCommandInteraction) {
  await interaction.deferReply();

  const thread = await interaction.channel!.threads.create({
    name: `Chat with ${interaction.user.displayName}`,
    autoArchiveDuration: 60,
    reason: 'AI conversation thread',
  });

  await interaction.editReply(`Started a conversation: ${thread}`);

  // Listen for messages in this thread
  const collector = thread.createMessageCollector({
    filter: (m) => !m.author.bot,
    idle: 300_000, // 5 minute idle timeout
  });

  const history: Array<{ role: 'user' | 'assistant'; content: string }> = [];

  collector.on('collect', async (message) => {
    history.push({ role: 'user', content: message.content });

    // Trim history to last 20 messages to control costs
    const trimmedHistory = history.slice(-20);

    try {
      await message.channel.sendTyping();

      const response = await anthropic.messages.create({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 1024,
        system: 'You are a helpful assistant in a Discord server. Keep responses concise.',
        messages: trimmedHistory,
      });

      const answer = response.content[0].type === 'text' ? response.content[0].text : '';
      history.push({ role: 'assistant', content: answer });

      if (answer.length > 2000) {
        // Split long responses
        for (let i = 0; i < answer.length; i += 2000) {
          await thread.send(answer.slice(i, i + 2000));
        }
      } else {
        await thread.send(answer);
      }
    } catch (error) {
      logger.error(error, 'AI chat error');
      await thread.send('Sorry, I encountered an error. Please try again.');
    }
  });

  collector.on('end', () => {
    thread.send('This conversation has been closed due to inactivity.').catch(() => {});
  });
}
```

### Always-listening AI channel

```ts
// In messageCreate event:
const guildConfig = await getGuildConfig(message.guildId!);
if (message.channelId !== guildConfig.aiChannelId) return;
if (message.author.bot) return;

// Rate limit: check Redis
const rateLimitKey = `ai:${message.author.id}`;
const count = await redis.incr(rateLimitKey);
if (count === 1) await redis.expire(rateLimitKey, 3600);
if (count > 10) return; // 10 messages per hour per user

// Fetch recent channel messages for context
const messages = await message.channel.messages.fetch({ limit: 20 });
const history = messages
  .reverse()
  .filter(m => m.content.length > 0)
  .map(m => ({
    role: m.author.bot ? 'assistant' as const : 'user' as const,
    content: m.content,
  }));

await message.channel.sendTyping();

const response = await anthropic.messages.create({
  model: 'claude-sonnet-4-20250514',
  max_tokens: 1024,
  system: guildConfig.aiPersona ?? 'You are a helpful assistant.',
  messages: history,
});

const answer = response.content[0].type === 'text' ? response.content[0].text : '';
await message.reply({ content: answer, allowedMentions: { parse: [] } });
```

### Streaming responses with batched edits

```ts
await interaction.deferReply();

const stream = await anthropic.messages.stream({
  model: 'claude-sonnet-4-20250514',
  max_tokens: 1024,
  messages: [{ role: 'user', content: question }],
});

let buffer = '';
let lastEdit = 0;
const EDIT_INTERVAL = 1500; // Discord rate limit: ~5 edits per 5 seconds

stream.on('text', async (text) => {
  buffer += text;
  const now = Date.now();
  if (now - lastEdit >= EDIT_INTERVAL && buffer.length > 0) {
    await interaction.editReply(buffer.slice(0, 2000)).catch(() => {});
    lastEdit = now;
  }
});

stream.on('end', async () => {
  if (buffer.length > 2000) {
    await interaction.editReply(buffer.slice(0, 1997) + '...');
  } else {
    await interaction.editReply(buffer || 'No response received.');
  }
});
```

### Dependencies

```json
"@anthropic-ai/sdk": "^0.30.0"
```

Or for OpenAI:
```json
"openai": "^4.60.0"
```

---

## Webhook Feeds

### GitHub notifications

Set up a simple HTTP server alongside the bot to receive GitHub webhooks:

```ts
// src/integrations/github-webhook.ts
import { createServer, type IncomingMessage, type ServerResponse } from 'node:http';
import { createHmac } from 'node:crypto';
import { EmbedBuilder, type TextChannel } from 'discord.js';

export function startGitHubWebhookServer(client: Client, port: number) {
  const server = createServer(async (req, res) => {
    if (req.method !== 'POST' || req.url !== '/github') {
      res.writeHead(404);
      return res.end();
    }

    const body = await readBody(req);
    const signature = req.headers['x-hub-signature-256'] as string;

    if (!verifySignature(body, signature, config.GITHUB_WEBHOOK_SECRET)) {
      res.writeHead(401);
      return res.end('Invalid signature');
    }

    const event = req.headers['x-github-event'] as string;
    const payload = JSON.parse(body);

    const embed = formatGitHubEvent(event, payload);
    if (embed) {
      const channel = await client.channels.fetch(config.GITHUB_CHANNEL_ID) as TextChannel;
      await channel.send({ embeds: [embed] });
    }

    res.writeHead(200);
    res.end('OK');
  });

  server.listen(port, () => logger.info(`GitHub webhook server on port ${port}`));
}

function formatGitHubEvent(event: string, payload: any): EmbedBuilder | null {
  switch (event) {
    case 'push':
      return new EmbedBuilder()
        .setColor(0x24292e)
        .setTitle(`Push to ${payload.repository.full_name}`)
        .setDescription(
          payload.commits
            .slice(0, 5)
            .map((c: any) => `[\`${c.id.slice(0, 7)}\`](${c.url}) ${c.message.split('\n')[0]}`)
            .join('\n')
        )
        .setAuthor({ name: payload.pusher.name })
        .setTimestamp();

    case 'pull_request':
      return new EmbedBuilder()
        .setColor(payload.action === 'opened' ? 0x2cbe4e : 0x6f42c1)
        .setTitle(`PR ${payload.action}: ${payload.pull_request.title}`)
        .setURL(payload.pull_request.html_url)
        .setDescription(payload.pull_request.body?.slice(0, 200) ?? '')
        .setAuthor({ name: payload.pull_request.user.login });

    case 'issues':
      return new EmbedBuilder()
        .setColor(0xd73a49)
        .setTitle(`Issue ${payload.action}: ${payload.issue.title}`)
        .setURL(payload.issue.html_url)
        .setAuthor({ name: payload.issue.user.login });

    default:
      return null;
  }
}
```

### Twitch live notifications

Use Twitch EventSub via WebSocket (no public endpoint needed):

```ts
// Simplified pattern — real implementation uses the Twitch EventSub WebSocket API
// Consider using the `twitch-eventsub-ws` or `@twurple/eventsub-ws` packages

import { ApiClient } from '@twurple/api';
import { EventSubWsListener } from '@twurple/eventsub-ws';

const twitchApi = new ApiClient({ authProvider });
const listener = new EventSubWsListener({ apiClient: twitchApi });

listener.onStreamOnline(broadcasterId, async (event) => {
  const channel = await client.channels.fetch(config.TWITCH_CHANNEL_ID) as TextChannel;
  const stream = await event.getStream();

  const embed = new EmbedBuilder()
    .setColor(0x9146ff)
    .setTitle(`${event.broadcasterDisplayName} is live!`)
    .setURL(`https://twitch.tv/${event.broadcasterName}`)
    .setDescription(stream?.title ?? 'No title')
    .setThumbnail(stream?.thumbnailUrl.replace('{width}', '320').replace('{height}', '180') ?? '')
    .setTimestamp();

  await channel.send({ embeds: [embed] });
});

listener.start();
```

### YouTube upload notifications

YouTube doesn't have reliable webhooks. Poll RSS feeds:

```ts
// Poll every 10 minutes
const YOUTUBE_RSS = 'https://www.youtube.com/feeds/videos.xml?channel_id=';

async function checkYouTubeUploads(channelId: string, lastChecked: Date) {
  const response = await fetch(`${YOUTUBE_RSS}${channelId}`);
  const xml = await response.text();
  // Parse XML (use `fast-xml-parser` package)
  // Check if any entries are newer than lastChecked
  // If so, send notification to Discord
}

setInterval(() => {
  for (const sub of youtubeSubscriptions) {
    checkYouTubeUploads(sub.youtubeChannelId, sub.lastChecked).catch(logger.error);
  }
}, 600_000); // 10 minutes
```

---

## Music with Lavalink

### Docker Compose addition

```yaml
lavalink:
  image: ghcr.io/lavalink-devs/lavalink:4
  environment:
    - LAVALINK_SERVER_PASSWORD=youshallnotpass
    - SERVER_PORT=2333
  ports:
    - "2333:2333"
  restart: unless-stopped
```

### Shoukaku client setup

```ts
// src/lib/music.ts
import { Shoukaku, Connectors } from 'shoukaku';

const nodes = [{
  name: 'main',
  url: `${config.LAVALINK_HOST}:${config.LAVALINK_PORT}`,
  auth: config.LAVALINK_PASSWORD,
}];

export const shoukaku = new Shoukaku(new Connectors.DiscordJS(client), nodes, {
  moveOnDisconnect: false,
  resume: true,
  resumeTimeout: 30,
  reconnectTries: 3,
  restTimeout: 60_000,
});

shoukaku.on('ready', (name) => logger.info(`Lavalink node ${name} connected`));
shoukaku.on('error', (name, error) => logger.error({ name, error }, 'Lavalink error'));
shoukaku.on('close', (name, code, reason) => logger.warn({ name, code, reason }, 'Lavalink closed'));
```

### Queue manager

```ts
// src/lib/queue.ts
import type { Player, Track } from 'shoukaku';

interface GuildQueue {
  player: Player;
  tracks: Track[];
  current: Track | null;
  loop: 'off' | 'track' | 'queue';
  volume: number;
  textChannelId: string;
}

export const queues = new Map<string, GuildQueue>();

export function getQueue(guildId: string): GuildQueue | undefined {
  return queues.get(guildId);
}

export function createQueue(guildId: string, player: Player, textChannelId: string): GuildQueue {
  const queue: GuildQueue = {
    player,
    tracks: [],
    current: null,
    loop: 'off',
    volume: 100,
    textChannelId,
  };
  queues.set(guildId, queue);
  return queue;
}

export function destroyQueue(guildId: string) {
  const queue = queues.get(guildId);
  if (queue) {
    queue.player.connection.disconnect();
    queues.delete(guildId);
  }
}
```

### Play command (simplified)

```ts
async execute(interaction: ChatInputCommandInteraction) {
  const query = interaction.options.getString('query', true);
  const member = interaction.member as GuildMember;
  const voiceChannel = member.voice.channel;

  if (!voiceChannel) {
    return interaction.reply({ content: 'Join a voice channel first.', ephemeral: true });
  }

  await interaction.deferReply();

  // Get or create player
  let queue = getQueue(interaction.guildId!);
  if (!queue) {
    const node = shoukaku.options.nodeResolver(shoukaku.nodes);
    const player = await node!.joinChannel({
      guildId: interaction.guildId!,
      channelId: voiceChannel.id,
      shardId: 0,
    });
    queue = createQueue(interaction.guildId!, player, interaction.channelId);
  }

  // Search for track
  const result = await queue.player.node.rest.resolve(
    query.startsWith('http') ? query : `scsearch:${query}` // SoundCloud search
  );

  if (!result?.data || (Array.isArray(result.data) && result.data.length === 0)) {
    return interaction.editReply('No results found.');
  }

  const track = Array.isArray(result.data) ? result.data[0] : result.data;
  queue.tracks.push(track);

  if (!queue.current) {
    queue.current = queue.tracks.shift()!;
    await queue.player.playTrack({ track: { encoded: queue.current.encoded } });
  }

  await interaction.editReply(`Added to queue: **${track.info.title}**`);
}
```

### Dependencies

```json
"shoukaku": "^4.1.0"
```

---

## Web Dashboard

For a full web dashboard, the **fullstack-application** skill handles the web app scaffolding (React frontend, NestJS API, Docker, CI/CD). This reference covers the Discord-specific integration points that the dashboard needs regardless of how it's built.

### Architecture

Bot and dashboard are separate processes sharing a database. The dashboard is a full web application (React + NestJS via the fullstack-application skill), not an embedded HTTP server in the bot.

```
Browser → Dashboard (React + NestJS) → PostgreSQL ← Bot (discord.js)
                                        ↕
                                      Redis (pub/sub + cache)
```

### Discord OAuth2 flow

The dashboard authenticates users via Discord OAuth2 instead of Google OAuth. This replaces the default Passport Google strategy from the fullstack-application skill.

**Required scopes**: `identify` (user info) + `guilds` (list user's servers)

**NestJS Passport strategy for Discord OAuth2:**

```ts
// apps/api/src/modules/auth/strategies/discord.strategy.ts
import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy, type Profile } from 'passport-discord';

@Injectable()
export class DiscordStrategy extends PassportStrategy(Strategy, 'discord') {
  constructor(private readonly configService: ConfigService) {
    super({
      clientID: configService.get('DISCORD_CLIENT_ID'),
      clientSecret: configService.get('DISCORD_CLIENT_SECRET'),
      callbackURL: configService.get('DASHBOARD_URL') + '/auth/discord/callback',
      scope: ['identify', 'guilds'],
    });
  }

  async validate(accessToken: string, refreshToken: string, profile: Profile) {
    // Store tokens — you'll need the access token to fetch guilds later
    return {
      discordId: profile.id,
      username: profile.username,
      avatar: profile.avatar,
      accessToken,
      guilds: profile.guilds,
    };
  }
}
```

**Dependencies:** `passport-discord` + `@types/passport-discord`

### Guild permission filtering

Only show servers where the user has `MANAGE_GUILD` (0x20) permission — this matches what Discord shows in the bot invite flow:

```ts
const MANAGE_GUILD = 0x20n;

function getManageableGuilds(guilds: DiscordGuild[]) {
  return guilds.filter(g => (BigInt(g.permissions) & MANAGE_GUILD) === MANAGE_GUILD);
}
```

Additionally, filter to guilds where the bot is actually present by cross-referencing with the bot's guild list (query the database or the bot's internal API).

### Dashboard API pattern

All guild-specific endpoints should be scoped under `/api/guilds/:guildId/` and protected by a guard that verifies both authentication and guild-level permissions:

```ts
// apps/api/src/modules/guilds/guards/guild-permission.guard.ts
@Injectable()
export class GuildPermissionGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const { guildId } = request.params;
    const userGuilds = request.user.guilds;

    const guild = userGuilds.find((g: any) => g.id === guildId);
    if (!guild) return false;

    return (BigInt(guild.permissions) & 0x20n) === 0x20n;
  }
}
```

### Config change propagation (Redis pub/sub)

When the dashboard updates a guild's config, it must notify the bot so the bot invalidates its cache immediately:

```ts
// In the dashboard API service, after saving a config change:
await this.redis.del(`config:${guildId}`);
await this.redis.publish('config-update', JSON.stringify({ guildId }));
```

The bot subscribes to this channel on startup (see SKILL.md "Combined Bot + Web Dashboard Architecture" section).

### Common dashboard features by bot type

| Bot Type | Dashboard Features |
|----------|--------------------|
| Moderation | Mod action log viewer, automod rule editor, warning history, banned word list |
| Leveling | XP multiplier settings, level reward role mapper, leaderboard viewer, rank card customizer |
| Economy | Shop item editor, economy settings (starting balance, daily amount), transaction log |
| Tickets | Ticket panel config, canned response editor, transcript viewer, staff performance stats |
| Welcome | Welcome/goodbye message editor with variable preview, auto-role selector, join/leave analytics |
| General | Logging channel selector, command toggle per channel, prefix settings, feature flags |

---

## Image Generation

### Rank cards with @napi-rs/canvas

```ts
import { createCanvas, loadImage, GlobalFonts } from '@napi-rs/canvas';
import { AttachmentBuilder } from 'discord.js';

// Register custom font (optional)
GlobalFonts.registerFromPath('./assets/fonts/Inter-Bold.ttf', 'Inter');

export async function generateRankCard(
  avatarUrl: string,
  username: string,
  level: number,
  xp: number,
  xpNeeded: number,
  rank: number,
): Promise<AttachmentBuilder> {
  const canvas = createCanvas(934, 282);
  const ctx = canvas.getContext('2d');

  // Background
  ctx.fillStyle = '#23272A';
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  // Avatar (circular)
  const avatar = await loadImage(avatarUrl);
  ctx.save();
  ctx.beginPath();
  ctx.arc(141, 141, 100, 0, Math.PI * 2);
  ctx.closePath();
  ctx.clip();
  ctx.drawImage(avatar, 41, 41, 200, 200);
  ctx.restore();

  // Username
  ctx.fillStyle = '#FFFFFF';
  ctx.font = 'bold 36px Inter, sans-serif';
  ctx.fillText(username, 280, 120);

  // XP bar background
  ctx.fillStyle = '#484B4E';
  ctx.fillRect(280, 160, 600, 30);

  // XP bar fill
  const progress = Math.min(xp / xpNeeded, 1);
  ctx.fillStyle = '#5865F2';
  ctx.fillRect(280, 160, 600 * progress, 30);

  // Level and rank text
  ctx.fillStyle = '#99AAB5';
  ctx.font = '24px Inter, sans-serif';
  ctx.fillText(`Level ${level}`, 280, 220);
  ctx.fillText(`Rank #${rank}`, 280, 250);
  ctx.fillText(`${xp} / ${xpNeeded} XP`, 680, 220);

  const buffer = canvas.toBuffer('image/png');
  return new AttachmentBuilder(buffer, { name: 'rank.png' });
}
```

### Dependencies

```json
"@napi-rs/canvas": "^0.1.56"
```

Alternative: `canvas` (node-canvas) if you need features @napi-rs/canvas doesn't support, but it requires system dependencies (Cairo, Pango, libjpeg).
