---
title: Discord.js v14 Fundamentals
weight: 1
---

# Discord.js v14 Fundamentals

## Table of Contents

1. [Client Setup and Intents](#client-setup-and-intents)
2. [Gateway Intents Reference](#gateway-intents-reference)
3. [Event Handling](#event-handling)
4. [Slash Commands](#slash-commands)
5. [Command Options](#command-options)
6. [Subcommands and Groups](#subcommands-and-groups)
7. [Interaction Responses](#interaction-responses)
8. [Embeds](#embeds)
9. [Buttons](#buttons)
10. [Select Menus](#select-menus)
11. [Modals](#modals)
12. [Context Menus](#context-menus)
13. [Collectors](#collectors)
14. [Autocomplete](#autocomplete)
15. [Partials](#partials)
16. [Cache Configuration](#cache-configuration)
17. [Cooldowns](#cooldowns)
18. [Discord Timestamps](#discord-timestamps)
19. [Key Imports Reference](#key-imports-reference)

---

## Client Setup and Intents

```ts
import { Client, GatewayIntentBits, Options, Partials } from 'discord.js';

const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,           // Guild structures, channels, roles
    GatewayIntentBits.GuildMessages,    // Message events in guilds
    GatewayIntentBits.MessageContent,   // PRIVILEGED: access message.content
    GatewayIntentBits.GuildMembers,     // PRIVILEGED: member join/leave events
  ],
  partials: [
    Partials.Message,   // Reactions on uncached messages
    Partials.Channel,   // DM channels
    Partials.Reaction,  // Uncached reactions
  ],
  // Cache limits to prevent memory leaks
  makeCache: Options.cacheWithLimits({
    MessageManager: 100,       // per channel
    GuildMemberManager: 200,   // per guild
    PresenceManager: 0,        // don't cache unless needed
  }),
  sweepers: {
    messages: {
      interval: 3600,   // every hour
      lifetime: 1800,   // remove messages older than 30min
    },
  },
});
```

**Privileged intents** (`GuildMembers`, `GuildPresences`, `MessageContent`) must be enabled in the Discord Developer Portal under Bot > Privileged Gateway Intents. Bots in 75+ servers need verification to use them.

---

## Gateway Intents Reference

| Intent | Privileged | Required For |
|--------|-----------|-------------|
| `Guilds` | No | Guild structures, channels, roles, threads |
| `GuildMessages` | No | Message create/update/delete in guilds |
| `MessageContent` | **Yes** | Reading `message.content`, embeds, attachments |
| `GuildMembers` | **Yes** | `guildMemberAdd`/`Remove` events, member cache |
| `GuildPresences` | **Yes** | Online/offline status tracking |
| `GuildMessageReactions` | No | Reaction add/remove events |
| `GuildVoiceStates` | No | Voice channel join/leave/move |
| `DirectMessages` | No | DM message events |
| `GuildScheduledEvents` | No | Scheduled event CRUD |
| `GuildInvites` | No | Invite create/delete |
| `GuildWebhooks` | No | Webhook updates |
| `GuildEmojisAndStickers` | No | Emoji/sticker updates |
| `AutoModerationConfiguration` | No | AutoMod rule changes |
| `AutoModerationExecution` | No | AutoMod action execution |

Only request intents the bot actually uses. Unnecessary privileged intents will block verification.

---

## Event Handling

### Event file structure

```ts
// src/events/ready.ts
import { Events, type Client } from 'discord.js';

export default {
  name: Events.ClientReady,
  once: true,
  execute(client: Client<true>) {
    console.log(`Ready! Logged in as ${client.user.tag}`);
  },
};
```

### Common events

| Event | Fires When |
|-------|-----------|
| `Events.ClientReady` | Bot connected and ready |
| `Events.InteractionCreate` | Any interaction (slash command, button, modal, etc.) |
| `Events.MessageCreate` | New message sent |
| `Events.GuildMemberAdd` | User joins a server |
| `Events.GuildMemberRemove` | User leaves/kicked/banned |
| `Events.GuildCreate` | Bot added to a new server |
| `Events.GuildDelete` | Bot removed from a server |
| `Events.MessageReactionAdd` | Reaction added to a message |
| `Events.VoiceStateUpdate` | User joins/leaves/moves voice channel |
| `Events.GuildBanAdd` | User banned |
| `Events.MessageUpdate` | Message edited |
| `Events.MessageDelete` | Message deleted |

---

## Slash Commands

### Command file structure

```ts
// src/commands/utility/ping.ts
import { SlashCommandBuilder, type ChatInputCommandInteraction } from 'discord.js';

export default {
  data: new SlashCommandBuilder()
    .setName('ping')
    .setDescription('Check bot latency'),
  async execute(interaction: ChatInputCommandInteraction) {
    const sent = await interaction.reply({ content: 'Pinging...', fetchReply: true });
    const roundtrip = sent.createdTimestamp - interaction.createdTimestamp;
    await interaction.editReply(
      `Pong! Roundtrip: ${roundtrip}ms | WebSocket: ${Math.round(interaction.client.ws.ping)}ms`
    );
  },
};
```

### Registering commands (deploy-commands.ts)

```ts
import { REST, Routes } from 'discord.js';
import { config } from './lib/config.js';

// Collect all command data...

const rest = new REST().setToken(config.token);

// Guild-specific (instant, for development):
await rest.put(
  Routes.applicationGuildCommands(config.clientId, config.devGuildId),
  { body: commands },
);

// Global (up to 1 hour propagation, for production):
await rest.put(
  Routes.applicationCommands(config.clientId),
  { body: commands },
);
```

Guild commands update instantly — use for development. Global commands take up to 1 hour — use for production.

---

## Command Options

```ts
builder
  .addStringOption(opt => opt.setName('query').setDescription('Search query').setRequired(true))
  .addIntegerOption(opt => opt.setName('count').setDescription('Number').setMinValue(1).setMaxValue(100))
  .addNumberOption(opt => opt.setName('amount').setDescription('Decimal number'))
  .addBooleanOption(opt => opt.setName('ephemeral').setDescription('Hidden response'))
  .addUserOption(opt => opt.setName('target').setDescription('Target user'))
  .addChannelOption(opt => opt.setName('channel').setDescription('Target channel'))
  .addRoleOption(opt => opt.setName('role').setDescription('Target role'))
  .addMentionableOption(opt => opt.setName('mention').setDescription('User or role'))
  .addAttachmentOption(opt => opt.setName('file').setDescription('Upload a file'))
```

### String choices

```ts
.addStringOption(opt =>
  opt.setName('category')
    .setDescription('The category')
    .setRequired(true)
    .addChoices(
      { name: 'Funny', value: 'funny' },
      { name: 'Meme', value: 'meme' },
    ))
```

### Reading options

```ts
const query = interaction.options.getString('query', true);   // required
const count = interaction.options.getInteger('count') ?? 10;   // optional with default
const user = interaction.options.getUser('target');
const member = interaction.options.getMember('target');         // GuildMember (may be null)
const channel = interaction.options.getChannel('channel');
const role = interaction.options.getRole('role');
const attachment = interaction.options.getAttachment('file');
```

---

## Subcommands and Groups

```ts
new SlashCommandBuilder()
  .setName('config')
  .setDescription('Server configuration')
  .addSubcommandGroup(group =>
    group.setName('channel')
      .setDescription('Channel settings')
      .addSubcommand(sub =>
        sub.setName('set')
          .setDescription('Set a config channel')
          .addChannelOption(opt => opt.setName('channel').setDescription('Channel').setRequired(true))
          .addStringOption(opt => opt.setName('type').setDescription('Type').setRequired(true)
            .addChoices({ name: 'Welcome', value: 'welcome' }, { name: 'Logs', value: 'logs' }))))
  .addSubcommand(sub =>
    sub.setName('prefix')
      .setDescription('Set prefix')
      .addStringOption(opt => opt.setName('prefix').setDescription('New prefix').setRequired(true)))
```

Handle with:
```ts
const group = interaction.options.getSubcommandGroup(false);
const sub = interaction.options.getSubcommand();
```

---

## Interaction Responses

```ts
// Basic reply
await interaction.reply('Hello!');
await interaction.reply({ content: 'Secret', ephemeral: true });

// Defer for slow operations (shows "Bot is thinking...")
await interaction.deferReply();
await interaction.deferReply({ ephemeral: true });
// ... do work ...
await interaction.editReply('Done!');

// Follow-up (additional messages after the initial reply)
await interaction.followUp('Another message');
await interaction.followUp({ content: 'Secret follow-up', ephemeral: true });

// Delete the reply
await interaction.deleteReply();

// Fetch the reply as a Message object
const message = await interaction.fetchReply();
```

**Critical timing**: Respond within **3 seconds** or the interaction fails. Use `deferReply()` for anything slow.
**After deferring**: You have **15 minutes** to call `editReply()`.
**Modal restriction**: `showModal()` must be the **first** response — cannot defer then show modal.

---

## Embeds

```ts
import { EmbedBuilder } from 'discord.js';

const embed = new EmbedBuilder()
  .setColor(0x5865F2)
  .setTitle('Title')
  .setURL('https://example.com')
  .setAuthor({ name: 'Author', iconURL: 'https://...', url: 'https://...' })
  .setDescription('Description text')
  .setThumbnail('https://...')
  .addFields(
    { name: 'Field 1', value: 'Value 1' },
    { name: 'Inline 1', value: 'Val', inline: true },
    { name: 'Inline 2', value: 'Val', inline: true },
  )
  .setImage('https://...')
  .setTimestamp()
  .setFooter({ text: 'Footer', iconURL: 'https://...' });

await interaction.reply({ embeds: [embed] });
```

---

## Buttons

```ts
import { ActionRowBuilder, ButtonBuilder, ButtonStyle } from 'discord.js';

const row = new ActionRowBuilder<ButtonBuilder>().addComponents(
  new ButtonBuilder().setCustomId('approve').setLabel('Approve').setStyle(ButtonStyle.Success).setEmoji('✅'),
  new ButtonBuilder().setCustomId('deny').setLabel('Deny').setStyle(ButtonStyle.Danger),
  new ButtonBuilder().setLabel('Website').setURL('https://...').setStyle(ButtonStyle.Link),
  new ButtonBuilder().setCustomId('disabled').setLabel('Disabled').setStyle(ButtonStyle.Secondary).setDisabled(true),
);

await interaction.reply({ content: 'Review:', components: [row] });
```

**ButtonStyle values**: `Primary` (blurple), `Secondary` (grey), `Success` (green), `Danger` (red), `Link` (opens URL, no customId).

### Handling button clicks

```ts
if (interaction.isButton()) {
  if (interaction.customId === 'approve') {
    await interaction.update({ content: 'Approved!', components: [] });
  }
}
```

---

## Select Menus

```ts
import { ActionRowBuilder, StringSelectMenuBuilder, StringSelectMenuOptionBuilder } from 'discord.js';

const select = new StringSelectMenuBuilder()
  .setCustomId('role_select')
  .setPlaceholder('Select roles')
  .setMinValues(1)
  .setMaxValues(3)
  .addOptions(
    new StringSelectMenuOptionBuilder().setLabel('JavaScript').setValue('js').setEmoji('📜'),
    new StringSelectMenuOptionBuilder().setLabel('Python').setValue('py').setEmoji('🐍'),
  );

const row = new ActionRowBuilder<StringSelectMenuBuilder>().addComponents(select);
```

Other select types: `UserSelectMenuBuilder`, `RoleSelectMenuBuilder`, `ChannelSelectMenuBuilder`, `MentionableSelectMenuBuilder`.

### Handling selections

```ts
if (interaction.isStringSelectMenu()) {
  const values = interaction.values; // string[]
  await interaction.reply({ content: `Selected: ${values.join(', ')}`, ephemeral: true });
}
```

---

## Modals

```ts
import { ModalBuilder, TextInputBuilder, TextInputStyle, ActionRowBuilder } from 'discord.js';

const modal = new ModalBuilder().setCustomId('feedback').setTitle('Feedback');

const titleInput = new TextInputBuilder()
  .setCustomId('title').setLabel('Title').setStyle(TextInputStyle.Short)
  .setPlaceholder('Brief summary').setRequired(true).setMaxLength(100);

const bodyInput = new TextInputBuilder()
  .setCustomId('body').setLabel('Details').setStyle(TextInputStyle.Paragraph)
  .setRequired(true).setMinLength(10).setMaxLength(4000);

modal.addComponents(
  new ActionRowBuilder<TextInputBuilder>().addComponents(titleInput),
  new ActionRowBuilder<TextInputBuilder>().addComponents(bodyInput),
);

await interaction.showModal(modal);
```

### Handling submissions

```ts
if (interaction.isModalSubmit()) {
  const title = interaction.fields.getTextInputValue('title');
  const body = interaction.fields.getTextInputValue('body');
  await interaction.reply({ content: `Received: **${title}**`, ephemeral: true });
}
```

---

## Context Menus

```ts
import { ApplicationCommandType, ContextMenuCommandBuilder } from 'discord.js';

// Right-click user
export default {
  data: new ContextMenuCommandBuilder()
    .setName('User Info')
    .setType(ApplicationCommandType.User),
  async execute(interaction) {
    await interaction.reply(`User: ${interaction.targetUser.tag}`);
  },
};

// Right-click message
export default {
  data: new ContextMenuCommandBuilder()
    .setName('Report Message')
    .setType(ApplicationCommandType.Message),
  async execute(interaction) {
    await interaction.reply({ content: `Reported message from ${interaction.targetMessage.author.tag}`, ephemeral: true });
  },
};
```

---

## Collectors

```ts
import { ComponentType } from 'discord.js';

const response = await interaction.reply({ content: 'Click!', components: [row], fetchReply: true });

// Collector pattern (multiple interactions)
const collector = response.createMessageComponentCollector({
  componentType: ComponentType.Button,
  time: 60_000,
  filter: (i) => i.user.id === interaction.user.id,
});

collector.on('collect', async (i) => {
  await i.update({ content: `You clicked ${i.customId}`, components: [] });
});

collector.on('end', (collected, reason) => {
  if (reason === 'time') {
    interaction.editReply({ content: 'Timed out', components: [] });
  }
});
```

### Promise-based (single interaction)

```ts
try {
  const confirmation = await response.awaitMessageComponent({
    filter: (i) => i.user.id === interaction.user.id,
    time: 60_000,
  });
  await confirmation.update({ content: 'Confirmed!', components: [] });
} catch {
  await interaction.editReply({ content: 'Timed out', components: [] });
}
```

---

## Autocomplete

```ts
// In command definition:
.addStringOption(opt => opt.setName('query').setDescription('Search').setAutocomplete(true))

// In command module:
export default {
  data: /* ... */,
  async autocomplete(interaction: AutocompleteInteraction) {
    const focused = interaction.options.getFocused();
    const choices = ['Option A', 'Option B', 'Option C'];
    const filtered = choices.filter(c => c.toLowerCase().startsWith(focused.toLowerCase()));
    await interaction.respond(filtered.slice(0, 25).map(c => ({ name: c, value: c })));
  },
  async execute(interaction) { /* ... */ },
};
```

Handle in interactionCreate:
```ts
if (interaction.isAutocomplete()) {
  const command = client.commands.get(interaction.commandName);
  await command?.autocomplete?.(interaction);
}
```

---

## Partials

When events fire for uncached data, the objects are "partial" — missing most fields. Enable partials and always fetch:

```ts
client.on('messageReactionAdd', async (reaction, user) => {
  if (reaction.partial) {
    try { await reaction.fetch(); }
    catch { return; } // Message was deleted
  }
  if (reaction.message.partial) {
    try { await reaction.message.fetch(); }
    catch { return; }
  }
  // Now safe to use reaction.message.content, etc.
});
```

---

## Cache Configuration

```ts
import { Options } from 'discord.js';

const client = new Client({
  makeCache: Options.cacheWithLimits({
    MessageManager: 100,        // per channel
    GuildMemberManager: 200,    // per guild
    PresenceManager: 0,         // disable unless needed
    ThreadManager: 50,
    ReactionUserManager: 0,
    GuildBanManager: 0,
  }),
  sweepers: {
    messages: { interval: 3600, lifetime: 1800 },
    users: {
      interval: 3600,
      filter: () => (user) => !user.bot && user.id !== user.client.user?.id,
    },
  },
});
```

---

## Cooldowns

```ts
import { Collection } from 'discord.js';

// On the client:
client.cooldowns = new Collection<string, Collection<string, number>>();

// In interactionCreate:
const { cooldowns } = client;
if (!cooldowns.has(command.data.name)) {
  cooldowns.set(command.data.name, new Collection());
}

const now = Date.now();
const timestamps = cooldowns.get(command.data.name)!;
const cooldownMs = (command.cooldown ?? 3) * 1000;

if (timestamps.has(interaction.user.id)) {
  const expiry = timestamps.get(interaction.user.id)! + cooldownMs;
  if (now < expiry) {
    const expiredTimestamp = Math.round(expiry / 1000);
    return interaction.reply({
      content: `Cooldown active. Try again <t:${expiredTimestamp}:R>.`,
      ephemeral: true,
    });
  }
}

timestamps.set(interaction.user.id, now);
setTimeout(() => timestamps.delete(interaction.user.id), cooldownMs);
```

---

## Discord Timestamps

```ts
const unix = Math.floor(Date.now() / 1000);
`<t:${unix}:R>`  // "2 minutes ago"
`<t:${unix}:F>`  // "Saturday, March 28, 2026 4:30 PM"
`<t:${unix}:f>`  // "March 28, 2026 4:30 PM"
`<t:${unix}:D>`  // "March 28, 2026"
`<t:${unix}:d>`  // "03/28/2026"
`<t:${unix}:T>`  // "4:30:00 PM"
`<t:${unix}:t>`  // "4:30 PM"
```

---

## Key Imports Reference

```ts
import {
  // Core
  Client, GatewayIntentBits, Events, Collection, Partials, REST, Routes, Options,
  // Builders
  SlashCommandBuilder, ContextMenuCommandBuilder, EmbedBuilder,
  ActionRowBuilder, ButtonBuilder, StringSelectMenuBuilder, StringSelectMenuOptionBuilder,
  UserSelectMenuBuilder, RoleSelectMenuBuilder, ChannelSelectMenuBuilder,
  ModalBuilder, TextInputBuilder, AttachmentBuilder,
  // Enums
  ButtonStyle, TextInputStyle, ApplicationCommandType, ComponentType,
  ChannelType, PermissionFlagsBits, ActivityType,
  // Utilities
  PermissionsBitField, ShardingManager,
} from 'discord.js';
```

### Permissions

```ts
import { PermissionFlagsBits } from 'discord.js';

// Set default command permissions (only users with these perms see the command)
builder.setDefaultMemberPermissions(PermissionFlagsBits.BanMembers);
builder.setDefaultMemberPermissions(PermissionFlagsBits.ManageGuild | PermissionFlagsBits.ManageChannels);

// Check member permissions at runtime
if (!interaction.memberPermissions?.has(PermissionFlagsBits.BanMembers)) { ... }

// Check bot permissions in a channel
const botPerms = interaction.channel?.permissionsFor(interaction.guild!.members.me!);
if (!botPerms?.has(PermissionFlagsBits.ManageMessages)) { ... }

// Check role hierarchy before moderation
const target = await interaction.guild!.members.fetch(targetUser.id);
if (target.roles.highest.position >= interaction.guild!.members.me!.roles.highest.position) {
  return interaction.reply({ content: 'I cannot moderate this user — their role is too high.', ephemeral: true });
}
```

Common `PermissionFlagsBits`: `Administrator`, `ManageGuild`, `ManageChannels`, `ManageRoles`, `KickMembers`, `BanMembers`, `ModerateMembers` (timeout), `ManageMessages`, `ManageWebhooks`, `SendMessages`, `EmbedLinks`, `AttachFiles`, `ReadMessageHistory`, `MentionEveryone`, `ViewChannel`, `Connect`, `Speak`, `MuteMembers`, `DeafenMembers`, `MoveMembers`.
