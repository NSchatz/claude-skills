# claude-skills

A personal Claude Code skills plugin marketplace — a collection of reusable skills that extend [Claude Code](https://claude.ai/code)'s capabilities.

## Skills

### `hyprland-config` (v3.1.0)
Full Hyprland Wayland compositor setup. Generates a complete environment from scratch: `hyprland.conf`, monitors, keybinds, window rules, animations, workspace rules, and companion app configs (waybar, wofi, kitty, dunst, hyprlock, hypridle, hyprpaper). Also produces an `install.sh` for the appropriate package manager.

Includes a guided interview covering system basics, core tools, visual style, and **keybind preferences** — supports i3/sway-like, vim-centric, and Windows/GNOME-familiar keybind styles with customizable submaps (resize, power/session, launch), directional navigation (hjkl/arrows/both), and `bindd` descriptions for discoverability.

Auto-triggers on any Hyprland-related topic — config files, ricing, tiling, keybinds, etc.

### `fullstack-standard` (v1.0.0)
Single source of truth for side project full-stack applications. Enforces a consistent stack across all projects:

| Layer | Technology |
|---|---|
| Monorepo | Turborepo + pnpm workspaces |
| Frontend | React 19 + Vite + Redux Toolkit + Tailwind CSS v4 |
| Backend | NestJS + Prisma + PostgreSQL |
| Auth | Passport.js + Google OAuth 2.0 + JWT |
| Testing | Vitest + Jest + Playwright |
| CI/CD | GitHub Actions + Docker + AWS ECS/EKS |

Auto-triggers on any side project work — new projects, scaffolding, architecture decisions, CI/CD setup.

### `discord-bot` (v1.0.0)
Complete Discord bot project generator — scaffolds full, production-ready bots tailored to specific use cases. Default stack:

| Layer | Technology |
|---|---|
| Language | TypeScript (strict mode) |
| Discord Library | discord.js v14 |
| Framework | Sapphire Framework (medium/large bots) |
| Database | PostgreSQL + Prisma ORM |
| Cache | Redis |
| Deployment | Docker + Docker Compose |
| CI/CD | GitHub Actions |

Auto-triggers on any Discord bot work — creating bots, slash commands, Discord.js, events, sharding, deployment, or any Discord API topic.

## Repository Structure

```
.claude-plugin/
└── marketplace.json        # central plugin registry

plugins/
├── template/               # reference template for new skills
├── hyprland-config/
├── fullstack-standard/
└── discord-bot/
```

Each plugin follows this layout:

```
plugins/<name>/
├── .claude-plugin/
│   └── plugin.json         # name, version, description, author
└── skills/<name>/
    ├── SKILL.md             # front matter + skill behavior
    ├── evals/
    │   └── evals.json       # test cases with assertions
    └── references/
        └── *.md             # topic-specific guides (lazy-loaded)
```

## Adding a Skill

1. Copy `plugins/template/` and rename it
2. Update `.claude-plugin/plugin.json`
3. Write `skills/<name>/SKILL.md` — the `description` front-matter field controls auto-invocation
4. Add reference files under `references/` for topic-specific knowledge
5. Add `evals/evals.json` to validate generated output
6. Register the plugin in `.claude-plugin/marketplace.json`
