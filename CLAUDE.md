# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in this repository.

## Repository Purpose

This is a personal Claude Code skills plugin marketplace — a collection of reusable skills that extend Claude Code's capabilities. Skills are consumed by Claude Code's harness at runtime; there is no build step.

## Plugin and Skill Architecture

Plugins live under `plugins/` and follow this structure:

```
plugins/<plugin-name>/
├── .claude-plugin/
│   └── plugin.json           # name, version, description, author
└── skills/<skill-name>/
    ├── SKILL.md              # front matter + skill behavior docs
    ├── evals/
    │   └── evals.json        # test cases with prompt/assertion pairs
    └── references/
        └── *.md              # topic-specific guides, lazy-loaded
```

The root `.claude-plugin/marketplace.json` is the central registry. Every new plugin must be added there.

## SKILL.md Format

Each `SKILL.md` has a YAML front matter block followed by Markdown content:

```yaml
---
name: skill-name
description: When/trigger condition for auto-invocation
# disable-model-invocation: true   # manual /skill only
# user-invocable: false            # background knowledge only
# context: fork                    # run in isolated subagent
# paths:                           # restrict to file patterns
#   - "src/**/*.ts"
---
```

The `description` field is what determines auto-invocation — be precise about the trigger condition.

## Reference Files

- Stored in `skills/<name>/references/*.md`
- Should be loaded **lazily** (not all at once) — the SKILL.md should specify when each reference is needed
- Use front matter for metadata (e.g., `weight`, `title`)

## Evals

`evals/evals.json` test cases contain a prompt and a list of assertions (string checks against generated output). Use evals to validate that a skill produces correct, expected output — especially for code generation skills.

## Known Pitfalls

### Hyprland Config: Variable Declaration Order

In generated Hyprland configs, variables (`$terminal`, `$fileManager`, `$menu`, etc.) **must be defined before** any `source =` lines that reference them. Hyprland processes configs top-to-bottom, so a `source`d file that uses `$terminal` will resolve to an empty string if the variable is declared later in the parent file.

## Adding a New Skill

1. Copy `plugins/template/` as a starting point
2. Update `plugin.json` with correct name/version/author
3. Write `SKILL.md` — the `description` front-matter field is the auto-invocation trigger
4. Add reference files under `references/` if the skill needs topic-specific knowledge
5. Add evals under `evals/evals.json` if the skill generates output that can be validated
6. Register the plugin in `.claude-plugin/marketplace.json`
