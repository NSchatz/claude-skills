# Project Structure

## Monorepo Directory Tree

```
<project-name>/
├── apps/
│   ├── web/                          # React + Vite frontend
│   │   ├── src/
│   │   │   ├── app/
│   │   │   │   ├── store.ts          # Redux store configuration
│   │   │   │   ├── hooks.ts          # Typed useAppDispatch / useAppSelector
│   │   │   │   └── router.tsx        # React Router route definitions
│   │   │   ├── components/           # Shared, reusable UI components (no feature logic)
│   │   │   │   └── ui/               # Base design system components (Button, Input, etc.)
│   │   │   ├── features/             # Feature-sliced modules
│   │   │   │   └── <feature>/
│   │   │   │       ├── <Feature>Page.tsx
│   │   │   │       ├── <feature>Slice.ts
│   │   │   │       ├── <feature>Api.ts     # RTK Query endpoints
│   │   │   │       ├── components/         # Components local to this feature
│   │   │   │       └── index.ts            # Barrel export
│   │   │   ├── hooks/                # Shared custom React hooks
│   │   │   ├── layouts/              # Page layout wrappers
│   │   │   ├── styles/               # Global CSS, Tailwind base imports
│   │   │   ├── utils/                # Pure utility functions
│   │   │   ├── main.tsx              # React entry point
│   │   │   └── App.tsx               # Root component (Provider, Router)
│   │   ├── public/
│   │   ├── index.html
│   │   ├── vite.config.ts
│   │   ├── tailwind.config.ts
│   │   ├── postcss.config.js
│   │   ├── tsconfig.json             # Extends packages/config
│   │   └── package.json
│   │
│   └── api/                          # NestJS backend
│       ├── src/
│       │   ├── auth/                 # Auth module (Passport, OAuth strategies, guards)
│       │   │   ├── strategies/       # passport-google-oauth20 strategy, JWT strategy
│       │   │   ├── guards/           # AuthGuard, RolesGuard
│       │   │   ├── decorators/       # @CurrentUser(), @Public()
│       │   │   ├── auth.controller.ts
│       │   │   ├── auth.service.ts
│       │   │   └── auth.module.ts
│       │   ├── common/               # Shared NestJS infrastructure
│       │   │   ├── filters/          # Global exception filters
│       │   │   ├── interceptors/     # Logging, transform interceptors
│       │   │   ├── pipes/            # Global validation pipe
│       │   │   └── decorators/
│       │   ├── config/               # ConfigModule setup, validation schema
│       │   ├── health/               # Health check endpoint (/health)
│       │   ├── modules/              # Feature modules
│       │   │   └── <feature>/
│       │   │       ├── dto/
│       │   │       │   ├── create-<feature>.dto.ts
│       │   │       │   └── update-<feature>.dto.ts
│       │   │       ├── <feature>.controller.ts
│       │   │       ├── <feature>.service.ts
│       │   │       ├── <feature>.module.ts
│       │   │       └── <feature>.service.spec.ts
│       │   ├── app.module.ts
│       │   └── main.ts               # Bootstrap, Swagger setup, global pipes
│       ├── test/                     # Integration / e2e tests (Jest + Supertest)
│       ├── tsconfig.json
│       ├── tsconfig.build.json
│       └── package.json
│
├── packages/
│   ├── database/                     # Prisma schema, client, migrations
│   │   ├── prisma/
│   │   │   ├── schema.prisma
│   │   │   └── migrations/
│   │   ├── src/
│   │   │   └── index.ts              # Re-exports PrismaClient instance (singleton)
│   │   └── package.json
│   │
│   ├── shared/                       # Types, DTOs, enums shared between apps
│   │   ├── src/
│   │   │   ├── types/                # TypeScript interfaces
│   │   │   ├── dtos/                 # Shared DTO shapes (class-transformer compatible)
│   │   │   ├── constants/            # Shared enums and constant values
│   │   │   └── index.ts              # Barrel export
│   │   └── package.json
│   │
│   └── config/                       # Shared tool configurations
│       ├── tsconfig.base.json
│       ├── biome.base.json
│       └── package.json
│
├── infrastructure/
│   ├── docker/
│   │   ├── web.Dockerfile            # Multi-stage: build → nginx
│   │   └── api.Dockerfile            # Multi-stage: build → node:alpine
│   ├── k8s/
│   │   ├── base/                     # Kustomize base manifests
│   │   │   ├── kustomization.yaml
│   │   │   ├── web-deployment.yaml
│   │   │   ├── api-deployment.yaml
│   │   │   ├── services.yaml
│   │   │   └── ingress.yaml
│   │   └── overlays/
│   │       ├── staging/
│   │       │   └── kustomization.yaml
│   │       └── production/
│   │           └── kustomization.yaml
│   ├── docker-compose.yml            # Full dev stack (app + postgres)
│   └── docker-compose.prod.yml       # Self-hosted production stack
│
├── e2e/                              # Playwright end-to-end tests
│   ├── tests/
│   │   └── <feature>.spec.ts
│   ├── pages/                        # Page Object Models
│   │   └── <Feature>Page.ts
│   └── playwright.config.ts
│
├── .github/
│   └── workflows/
│       ├── ci.yml                    # PR checks: typecheck, lint, test
│       ├── cd-staging.yml            # Push to staging on merge to develop
│       └── cd-production.yml         # Push to production on merge to main
│
├── turbo.json
├── pnpm-workspace.yaml
├── package.json                      # Root: scripts, devDependencies (turbo, biome)
├── biome.json                        # Root Biome config (extends packages/config)
├── .env.example                      # All env vars documented, no real values
├── .env                              # Local only — gitignored
└── .gitignore
```

---

## Naming Conventions

### Files and Directories

| Type | Convention | Example |
|------|-----------|---------|
| React components | `PascalCase.tsx` | `UserProfile.tsx` |
| Feature directories | `kebab-case` | `user-profile/` |
| NestJS files | `kebab-case.<type>.ts` | `user.service.ts` |
| Test files | same name + `.spec.ts` | `user.service.spec.ts` |
| DTOs | `kebab-case.dto.ts` | `create-user.dto.ts` |
| Prisma migrations | auto-generated by Prisma CLI | `20240101_add_user_table` |
| E2E page objects | `PascalCasePage.ts` | `LoginPage.ts` |

### Code

| Type | Convention | Example |
|------|-----------|---------|
| React components | `PascalCase` | `UserProfile` |
| Functions / hooks | `camelCase` | `useCurrentUser`, `formatDate` |
| Constants | `SCREAMING_SNAKE_CASE` | `MAX_RETRY_COUNT` |
| TypeScript interfaces | `PascalCase`, no `I` prefix | `UserProfile` |
| TypeScript enums | `PascalCase` | `UserRole` |
| RTK slices | `camelCase` + `Slice` suffix | `userSlice` |
| RTK Query APIs | `camelCase` + `Api` suffix | `userApi` |
| NestJS modules | `PascalCase` + `Module` | `UserModule` |
| Environment variables | `SCREAMING_SNAKE_CASE` | `DATABASE_URL` |

---

## Package Naming

Packages in `packages/` use the workspace name format `@<project>/package-name`:

```json
// packages/shared/package.json
{ "name": "@myapp/shared" }

// packages/database/package.json
{ "name": "@myapp/database" }

// packages/config/package.json
{ "name": "@myapp/config" }
```

Reference them in other packages/apps:
```json
// apps/api/package.json
{
  "dependencies": {
    "@myapp/database": "workspace:*",
    "@myapp/shared": "workspace:*"
  }
}
```

---

## Root Configuration Files

### `turbo.json`
```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**", ".next/**", "build/**"]
    },
    "test": {
      "dependsOn": ["^build"]
    },
    "lint": {},
    "typecheck": {},
    "dev": {
      "cache": false,
      "persistent": true
    },
    "db:generate": {
      "cache": false
    },
    "db:migrate": {
      "cache": false
    }
  }
}
```

### `pnpm-workspace.yaml`
```yaml
packages:
  - 'apps/*'
  - 'packages/*'
```

### Root `package.json`
```json
{
  "private": true,
  "scripts": {
    "build": "turbo run build",
    "dev": "turbo run dev",
    "test": "turbo run test",
    "lint": "biome check .",
    "lint:fix": "biome check --write .",
    "typecheck": "turbo run typecheck",
    "db:generate": "turbo run db:generate",
    "db:migrate": "turbo run db:migrate",
    "db:studio": "pnpm --filter @myapp/database exec prisma studio"
  },
  "devDependencies": {
    "turbo": "latest",
    "@biomejs/biome": "latest",
    "typescript": "^5.0.0"
  }
}
```

### `.env.example`
```dotenv
# Database
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/myapp"

# Auth
GOOGLE_CLIENT_ID=""
GOOGLE_CLIENT_SECRET=""
GOOGLE_CALLBACK_URL="http://localhost:3001/auth/google/callback"
JWT_SECRET=""
JWT_EXPIRES_IN="7d"
JWT_REFRESH_SECRET=""
JWT_REFRESH_EXPIRES_IN="30d"

# API
API_PORT=3001
NODE_ENV=development
FRONTEND_URL="http://localhost:5173"

# Frontend
VITE_API_URL="http://localhost:3001"
```
