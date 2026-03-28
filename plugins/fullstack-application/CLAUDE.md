# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

This is the `fullstack-application` plugin for the claude-skills marketplace. It contains a single skill (`fullstack-application`) that serves as the source of truth for scaffolding and developing side-project full-stack applications. There is no application code here — only skill definitions, reference docs, and evals.

## Stack Defined by This Skill

Turborepo + pnpm monorepo, React 19 + Vite + Redux Toolkit + Tailwind CSS v4 (frontend), NestJS + Prisma + PostgreSQL (backend), Google OAuth via Passport, Redis (caching + BullMQ queues), Socket.IO (WebSockets), S3 (file uploads), SES (email), React Hook Form + Zod (forms), Helmet + Throttler (security), Pino + Sentry + OpenTelemetry (observability), Biome, Vitest/Jest + Playwright + axe-core, GitHub Actions, Docker (distroless API, nginx web), AWS ECS/EKS.

## Plugin Structure

```
.claude-plugin/plugin.json       # Plugin metadata (name, version, author)
skills/fullstack-application/
  SKILL.md                       # Skill front matter + full behavioral spec
  references/*.md                # Lazy-loaded topic guides (18 files)
  evals/evals.json               # Prompt/assertion test cases (if present)
```

## How to Work on This Plugin

There is no build step, no dependencies to install, and no tests to run locally. The skill is consumed at runtime by Claude Code's harness.

- **SKILL.md** is the entry point. Its YAML `description` field controls when the skill auto-invokes. Changes to trigger conditions go there.
- **Reference files** are loaded lazily by the skill — SKILL.md specifies when each one should be read. Don't consolidate them into SKILL.md; the separation is intentional for context management.
- **Evals** (`evals/evals.json`) validate skill output with prompt + assertion pairs.
- After changes, register the plugin in the root `.claude-plugin/marketplace.json` if not already present.

## Key Design Decisions

- **Interview-first pattern**: The skill must ask targeted questions before generating any code. This is enforced in SKILL.md under "Always Interview First." New project, feature, infra, and debugging flows each have their own question set.
- **One `createApi` call per backend**: RTK Query uses `injectEndpoints` per feature — never multiple `createApi` slices for the same server. This prevents cache fragmentation.
- **Refresh tokens in HttpOnly cookies only**: Never in JSON response bodies. The JWT refresh strategy extracts from cookies, not the Authorization header.
- **Prisma migrations**: `prisma migrate dev` for local development only. CI and production always use `prisma migrate deploy`.
- **Always index foreign keys**: Prisma does not auto-index FK columns. Every `@@index([foreignKeyId])` must be explicit.
- **RFC 7807 error responses**: All API errors return Problem Details format with `application/problem+json` content type. Never leak stack traces.
- **Never send email synchronously**: All email goes through BullMQ. The processor respects SES rate limits via BullMQ's `limiter` config.
- **Expand-then-contract migrations**: Zero-downtime schema changes require two migrations — add the new thing, then remove the old thing in a later deploy.
- **Cache-aside pattern**: Service-level caching with explicit invalidation on writes. Route-level caching only for public, user-agnostic GET endpoints.
- **Redis adapter for WebSockets**: Required when running multiple API instances. Without it, events only reach clients on the same instance.
- **Distroless production images**: API Dockerfile uses `gcr.io/distroless/nodejs20-debian12` — no shell available. Use the `:debug` tag only for troubleshooting.
- **Kustomize for own apps, Helm for third-party**: K8s manifests use Kustomize base/overlay pattern, not Helm templates.
- **Tailwind v4**: CSS-first config via `@theme` in CSS, `@tailwindcss/vite` plugin instead of PostCSS. No `tailwind.config.js` needed.
- **WCAG 2.1 AA baseline**: All components keyboard accessible, semantic HTML first, ARIA only when needed. `axe-core` in Playwright for CI.
- **Consistent hashing for feature flag rollouts**: Same user+flag always resolves to the same bucket — no flip-flopping between requests.
