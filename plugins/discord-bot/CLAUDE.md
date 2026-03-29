# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Claude Code skill plugin that generates production-ready Discord bots, optionally combined with a fullstack web dashboard. This is **not** a Discord bot itself — it's a skill that teaches Claude Code how to scaffold and build complete Discord bot projects when users ask for one.

The skill lives at `skills/discord-bot/SKILL.md` and is auto-invoked whenever a user asks about Discord bot development in any capacity. When a user wants a web dashboard for their bot, this skill orchestrates the **fullstack-application** skill to handle the web app side.

## Skill Structure

- `SKILL.md` — The main skill definition with the full workflow (interview → scaffold → post-generation checklist), code standards, and decision framework (Sapphire vs raw discord.js)
- `references/*.md` — Lazy-loaded knowledge files. Each covers a specific domain (fundamentals, scaffolding, bot types, database, deployment, sharding, security, integrations). SKILL.md specifies when to load each one.
- `evals/evals.json` — Four eval scenarios: moderation bot, leveling/economy bot, ticket bot, and bot + web dashboard. Each has specific assertions about generated output.

## Running Evals

Evals validate that the skill produces correct output. Each eval has a `prompt` and a list of `assertions` (text checks against generated output). There is no test runner — evals are executed through Claude Code's skill eval system.

## Default Tech Stack (Generated Bots)

The skill generates bots using: TypeScript (strict), discord.js v14, Node.js 20+, PostgreSQL + Prisma, Redis (optional), Pino logging, Docker, pnpm. The Sapphire Framework is added for bots with 10+ commands.

## Key Design Decisions

- **Command registration is always a separate script** (`deploy-commands.ts`) — never in the `ready` event. This prevents rate limits.
- **Discord snowflake IDs are always `String` in Prisma** — they exceed `Number.MAX_SAFE_INTEGER`.
- **Intents are minimal and commented** — only request what the bot needs, with a comment per intent explaining why.
- **Modals cannot follow `deferReply()`** — modals must be the first interaction response. This is a common mistake the skill actively prevents.
- **Component interactions use stable `customId` patterns** (e.g., `ticket:close:12345`), not collectors, so they persist across bot restarts.
- **Dashboard projects use a monorepo** — When a web dashboard is requested, the project becomes a Turborepo monorepo (`apps/bot/`, `apps/api/`, `apps/web/`, `packages/database/`). The fullstack-application skill handles the web side; this skill handles the bot side and shared database schema.
- **Dashboard auth is Discord OAuth2** — not Google OAuth. The fullstack-application skill's default Passport Google strategy must be swapped for `passport-discord`.
- **Config changes propagate via Redis pub/sub** — The dashboard publishes to a `config-update` channel; the bot subscribes and invalidates its cache.

## Editing the Skill

When modifying `SKILL.md`, preserve the interview → scaffold → checklist workflow structure. The interview is designed to adapt (skip irrelevant questions for simple bots, trim for experienced developers).

When adding reference files, add a corresponding row to the "Reference Files" table in `SKILL.md` with a clear "When to load" condition — references should not all be loaded at once.

When adding evals, each assertion should check for a specific, falsifiable property of the generated output (e.g., "uses `String` for snowflake IDs", not "has good code").
