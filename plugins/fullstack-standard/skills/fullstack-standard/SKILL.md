---
name: fullstack-standard
description: Source of truth for all side project full-stack applications. Always invoke this skill when creating a new project, scaffolding features, making architectural or tooling decisions, writing tests, setting up CI/CD, or working on any side project code. Stack: Turborepo + pnpm monorepo, React + Redux Toolkit + Tailwind CSS + Vite (frontend), NestJS + Prisma + PostgreSQL (backend), Google OAuth via Passport, Swagger/OpenAPI, Biome, Jest + Playwright, GitHub Actions, Docker + Docker Compose, AWS ECS/EKS + RDS or self-hosted. Use this skill proactively whenever the user mentions a side project, starting an app, adding a feature, or asks about project setup — even if they don't explicitly ask for the standard.
---

# Full-Stack Application Standard

This skill is the single source of truth for all side project applications. Every project follows these standards without exception.

## Tech Stack

| Layer            | Technology                                                        |
|------------------|-------------------------------------------------------------------|
| Monorepo         | Turborepo 2.x (`tasks` key) + pnpm workspaces with `catalog:`    |
| Frontend         | React 19 + Vite + Redux Toolkit + Tailwind CSS v4                 |
| Backend          | NestJS (REST) + Prisma ORM + PostgreSQL                           |
| Auth             | Passport.js + Google OAuth 2.0 + JWT (access) + HttpOnly cookie (refresh) |
| API Docs         | Swagger / OpenAPI (`@nestjs/swagger`)                             |
| Code Quality     | Biome (lint + format) + TypeScript strict mode                    |
| Unit / Int Tests | Vitest (frontend) + Jest (backend) + React Testing Library + Supertest |
| E2E Tests        | Playwright                                                        |
| CI/CD            | GitHub Actions                                                    |
| Containers       | Docker multi-stage (distroless API, nginx web) + Docker Compose   |
| Cloud            | AWS ECS or EKS + RDS (or self-hosted Docker Compose)              |

## Reference Files

Read the relevant reference before making decisions. Don't guess at conventions.

| File | When to read |
|------|-------------|
| [`references/project-structure.md`](references/project-structure.md) | Setting up a new project, adding a package/app, understanding file placement |
| [`references/code-standards.md`](references/code-standards.md) | TypeScript config, Biome setup, naming conventions, error handling |
| [`references/frontend.md`](references/frontend.md) | React components, RTK store/slices/RTK Query, Tailwind patterns, routing |
| [`references/backend.md`](references/backend.md) | NestJS module layout, Prisma usage, Passport OAuth, Swagger decorators, DTOs |
| [`references/testing.md`](references/testing.md) | Jest unit/integration test patterns, Playwright E2E, coverage thresholds |
| [`references/infrastructure.md`](references/infrastructure.md) | Dockerfiles, Docker Compose, GitHub Actions CI/CD, AWS deployment, K8s |

---

## Scaffolding a New Project

When the user asks to create a new project, follow these steps in order. Confirm the project name before writing files.

1. Read `references/project-structure.md` — internalize the full directory tree before writing anything
2. Generate root-level files: `turbo.json`, `pnpm-workspace.yaml`, `package.json`, `biome.json`, `.env.example`, `.gitignore`
3. Scaffold `packages/config` — shared `tsconfig.base.json`, `biome.base.json`
4. Scaffold `packages/database` — Prisma schema with base `User` model, `package.json`, `src/index.ts` re-exporting the Prisma client
5. Scaffold `packages/shared` — empty `types/`, `dtos/`, `constants/` dirs with barrel `index.ts` exports
6. Scaffold `apps/api` — NestJS app with `AppModule`, `AuthModule` (Passport Google), `HealthModule`, Swagger bootstrap in `main.ts`
7. Scaffold `apps/web` — Vite React app with RTK store, React Router, Tailwind CSS, base layout component
8. Generate `infrastructure/docker/web.Dockerfile`, `infrastructure/docker/api.Dockerfile`
9. Generate `infrastructure/docker-compose.yml` (dev stack with Postgres) and `infrastructure/docker-compose.prod.yml`
10. Generate `.github/workflows/ci.yml`
11. Confirm with the user and write all files

---

## Adding a Feature

When adding a new feature to an existing project:

1. **Backend**: create a NestJS module at `apps/api/src/modules/<feature>/` with controller, service, and Prisma-backed repository pattern. Add Swagger decorators to every endpoint. Read `references/backend.md`.
2. **Frontend**: create a feature slice at `apps/web/src/features/<feature>/` containing the RTK slice, RTK Query endpoints, and feature-specific components. Read `references/frontend.md`.
3. **Shared types**: add request/response DTOs and TypeScript interfaces to `packages/shared/src/` so both apps consume the same contract.
4. **Tests**: write Jest unit tests alongside the code; integration tests under `apps/api/test/`; Playwright tests under `e2e/tests/` for user-facing flows. Read `references/testing.md`.
5. Update `packages/database` Prisma schema if new models are needed — always generate a named migration.

---

## Non-Negotiable Rules

These apply to every task, no exceptions:

- TypeScript strict mode on in every package and app
- No `any` types — use `unknown` + type guards when the shape is truly dynamic
- All backend endpoints have Swagger decorators and input DTOs validated with `class-validator`
- All new modules include at minimum a unit test file
- Biome passes with zero errors before any code is considered done
- Environment variables are never hardcoded — always read from `ConfigModule` (backend) or Vite `import.meta.env` (frontend)
- Dockerfiles are multi-stage; API production image uses distroless, web uses nginx:alpine
- Never run `prisma migrate dev` in CI or production — always use `prisma migrate deploy`
- Refresh tokens go in HttpOnly cookies only — never in a JSON response body
