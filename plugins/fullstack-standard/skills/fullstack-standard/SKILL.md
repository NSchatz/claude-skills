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

## Always Interview First — Never Start Without Answers

Before writing any code, generating any files, or making any architectural decisions, you must ask the user a targeted set of questions. The goal is to understand exactly what is needed so the output is correct the first time. Do not proceed until you have answers to the questions relevant to the task.

Ask all relevant questions in a single message, grouped clearly by topic. Wait for the user's full response before doing any work.

---

### Questions: New Project

Ask every one of these before scaffolding a new project:

**Project basics**
- What is the project name? (This becomes the directory name and package scope, e.g. `@myapp/`)
- In one or two sentences, what does this application do? Who uses it?
- Is this an MVP / prototype, or a production-quality starting point?

**Features and domain**
- What are the main entities or data models you anticipate? (e.g. User, Post, Order, etc.)
- What are the first 2–3 features you want to build after the scaffold?
- Do you need any roles or permissions beyond "authenticated user"? (e.g. admin, moderator)

**Auth**
- Google OAuth only, or do you also want username/password (email + password) login?
- Any other OAuth providers needed now or soon? (GitHub, Apple, etc.)
- Should sessions expire? If so, how long should the access token and refresh token last?

**Deployment**
- Will this be deployed to AWS (ECS or EKS), self-hosted via Docker Compose, or both?
- If AWS: do you have a preference between ECS (simpler, AWS-native) and EKS (Kubernetes)?
- Do you need multiple environments (dev / staging / production), or just production?
- Do you have an existing AWS account, ECR registry, or VPC you want to target?

**Infrastructure**
- Will the database be RDS (managed) or self-hosted PostgreSQL?
- Do you need Redis (for caching, queues, or session storage)?
- Any other AWS services needed? (S3 for file uploads, SES for email, SQS for queues, etc.)

**CI/CD**
- Is the GitHub repo already created? What is the full `owner/repo` path?
- Should CI run on every PR, or only on pushes to specific branches?
- Is there a Vercel Remote Cache token available for Turborepo, or should we skip remote caching for now?

**Frontend**
- Will this app have a public-facing marketing/landing page, or is it entirely behind auth?
- Any specific page routes you know you'll need from the start?
- Any preferences on color palette, typography, or visual direction for the custom UI?

---

### Questions: Adding a Feature

Ask all of these before writing any code for a new feature:

**Scope**
- What is the feature called, and what does it do in plain language?
- Is this entirely new, or does it extend an existing module?
- What user role(s) can access this feature?

**Data**
- What are the new database models or fields required?
- Are there relationships to existing models? (e.g. "a Post belongs to a User")
- Do any existing models need columns added or removed?

**API**
- What endpoints are needed? (e.g. `GET /posts`, `POST /posts`, `DELETE /posts/:id`)
- Are there any non-CRUD operations? (e.g. "publish", "archive", "send notification")
- Should any endpoints be paginated? If so, cursor-based or offset?

**Frontend**
- What pages or views need to be created or updated?
- Is there any real-time behavior? (polling, WebSockets, SSE)
- Are there any file uploads or external API integrations involved?

**Testing**
- Should Playwright E2E tests be written for this feature, or just unit/integration?
- Are there any edge cases or error scenarios you want explicitly tested?

---

### Questions: Infrastructure / CI / Deployment

Ask these when the request involves infrastructure, pipelines, or deployment:

**Environment**
- Which environment is this for? (dev, staging, production, or all three?)
- AWS region preference?
- Is the container registry (ECR) already set up, or does it need to be created?

**Deployment target**
- ECS or EKS? If ECS: Fargate or EC2 launch type?
- Rolling update or blue/green deployment?
- Is there an existing ALB / ingress, or does one need to be provisioned?

**Secrets and config**
- Where should secrets live? (AWS Secrets Manager, Parameter Store, K8s Secrets, `.env` file on the host)
- Are any secrets already stored somewhere, or starting from scratch?

**Database migrations**
- Should migrations run automatically as part of deployment, or manually triggered?
- Is there an existing database that needs to be connected to, or a fresh one?

---

### Questions: Debugging or Modifying Existing Code

When the user points you at existing code to fix or change:

- What is the current behavior?
- What is the expected behavior?
- Are there any error messages, logs, or stack traces you can share?
- Is this a regression (it used to work), or has it never worked?
- Are there any constraints on the fix? (e.g. "don't change the API shape", "must be backwards compatible")

---

## Scaffolding a New Project

Only begin this after completing the interview above. Follow these steps in order.

1. Read `references/project-structure.md` — internalize the full directory tree before writing anything
2. Generate root-level files: `turbo.json`, `pnpm-workspace.yaml`, `package.json`, `biome.json`, `.env.example`, `.gitignore`
3. Scaffold `packages/config` — shared `tsconfig.base.json`, `biome.base.json`
4. Scaffold `packages/database` — Prisma schema with base `User` model (and any other models the user identified), `package.json`, `src/index.ts` re-exporting the Prisma client
5. Scaffold `packages/shared` — empty `types/`, `dtos/`, `constants/` dirs with barrel `index.ts` exports
6. Scaffold `apps/api` — NestJS app with `AppModule`, `AuthModule` (Passport Google), `HealthModule`, Swagger bootstrap in `main.ts`
7. Scaffold `apps/web` — Vite React app with RTK store, React Router, Tailwind CSS, base layout component
8. Generate `infrastructure/docker/web.Dockerfile`, `infrastructure/docker/api.Dockerfile`
9. Generate `infrastructure/docker-compose.yml` (dev stack with Postgres) and `infrastructure/docker-compose.prod.yml`
10. Generate `.github/workflows/ci.yml`
11. Present the full list of files to be created and confirm with the user before writing anything

---

## Adding a Feature

Only begin this after completing the feature interview above.

1. **Backend**: create a NestJS module at `apps/api/src/modules/<feature>/` with controller, service, and Prisma-backed repository pattern. Add Swagger decorators to every endpoint. Read `references/backend.md`.
2. **Frontend**: create a feature slice at `apps/web/src/features/<feature>/` containing the RTK slice, RTK Query endpoints, and feature-specific components. Read `references/frontend.md`.
3. **Shared types**: add request/response DTOs and TypeScript interfaces to `packages/shared/src/` so both apps consume the same contract.
4. **Tests**: write unit tests alongside the code; integration tests under `apps/api/test/`; Playwright tests under `e2e/tests/` for user-facing flows. Read `references/testing.md`.
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
