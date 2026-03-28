# Code Standards

## TypeScript

### Configuration

Every app and package extends from `packages/config/tsconfig.base.json`:

```json
// packages/config/tsconfig.base.json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "forceConsistentCasingInFileNames": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  }
}
```

```json
// apps/web/tsconfig.json
{
  "extends": "@myapp/config/tsconfig.base.json",
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "baseUrl": ".",
    "paths": { "@/*": ["src/*"] }
  },
  "include": ["src"]
}
```

```json
// apps/api/tsconfig.json
{
  "extends": "@myapp/config/tsconfig.base.json",
  "compilerOptions": {
    "target": "ES2021",
    "module": "CommonJS",
    "moduleResolution": "node",
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true,
    "baseUrl": ".",
    "paths": { "@/*": ["src/*"] }
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist", "test"]
}
```

### Rules

- **No `any`** — use `unknown` with type guards when the shape is truly dynamic
- **No non-null assertions (`!`)** unless the reason is obvious and documented
- **No type casting with `as`** unless unavoidable — prefer type guards
- Prefer `interface` for object shapes that may be extended; `type` for unions, intersections, and utility types
- Use `const` assertions (`as const`) for fixed data structures
- Export types separately from values to keep tree-shaking intact

---

## Biome (Lint + Format)

Biome replaces ESLint + Prettier. All formatting and linting runs through a single tool.

### Root `biome.json`
```json
{
  "$schema": "https://biomejs.dev/schemas/1.9.0/schema.json",
  "extends": ["./packages/config/biome.base.json"],
  "files": {
    "ignore": ["**/dist/**", "**/node_modules/**", "**/.next/**", "**/coverage/**"]
  }
}
```

### `packages/config/biome.base.json`
```json
{
  "$schema": "https://biomejs.dev/schemas/1.9.0/schema.json",
  "organizeImports": { "enabled": true },
  "formatter": {
    "enabled": true,
    "indentStyle": "space",
    "indentWidth": 2,
    "lineWidth": 100
  },
  "linter": {
    "enabled": true,
    "rules": {
      "recommended": true,
      "correctness": {
        "noUnusedVariables": "error",
        "noUnusedImports": "error"
      },
      "suspicious": {
        "noExplicitAny": "error",
        "noConsoleLog": "warn"
      },
      "style": {
        "useConst": "error",
        "noVar": "error",
        "useTemplate": "error"
      }
    }
  },
  "javascript": {
    "formatter": {
      "quoteStyle": "single",
      "trailingCommas": "all",
      "semicolons": "always"
    }
  }
}
```

### Usage

```bash
# Check (CI)
biome check .

# Fix and format (dev)
biome check --write .

# Check a specific file
biome check src/app/store.ts
```

Biome must pass with zero errors before any code is merged.

---

## Import Organization

Biome's `organizeImports` handles ordering automatically. The convention is:

1. Node built-ins (`node:fs`, `node:path`)
2. External packages (`react`, `@nestjs/common`)
3. Internal workspace packages (`@myapp/shared`)
4. Internal app imports (`@/components/...`, `@/features/...`)
5. Relative imports (`./utils`, `../models`)
6. Type-only imports last

Never mix value and type imports — use `import type { Foo }` for type-only imports:
```ts
import { Injectable } from '@nestjs/common';
import type { PrismaClient } from '@myapp/database';
```

---

## Error Handling

### Backend (NestJS)

Use NestJS built-in HTTP exceptions for expected errors. Never throw raw `Error` in a controller or service:

```ts
// Good
throw new NotFoundException(`User with id ${id} not found`);
throw new BadRequestException('Email is already taken');
throw new UnauthorizedException();

// Bad
throw new Error('not found');
```

For unexpected errors, let them bubble to the global exception filter — do not swallow them with an empty catch.

Register a global exception filter in `main.ts` that logs the error with context before responding:

```ts
app.useGlobalFilters(new HttpExceptionFilter());
```

### Frontend

- API errors from RTK Query are typed — handle `isError` and `error` from the query/mutation result in the component
- Use an error boundary component at the route level for unexpected render errors
- Never `console.log` errors in production code — use a logger utility that can be silenced in production

---

## Environment Variables

### Backend

Use `@nestjs/config` with a Joi validation schema. Never read `process.env` directly outside of the config module:

```ts
// config/env.validation.ts
import Joi from 'joi';

export const envValidationSchema = Joi.object({
  NODE_ENV: Joi.string().valid('development', 'test', 'production').required(),
  DATABASE_URL: Joi.string().required(),
  JWT_SECRET: Joi.string().min(32).required(),
  GOOGLE_CLIENT_ID: Joi.string().required(),
  GOOGLE_CLIENT_SECRET: Joi.string().required(),
});
```

```ts
// app.module.ts
ConfigModule.forRoot({
  isGlobal: true,
  validationSchema: envValidationSchema,
})
```

### Frontend

All frontend env vars are prefixed `VITE_`. Access via `import.meta.env.VITE_API_URL`. Create a typed wrapper:

```ts
// src/utils/env.ts
export const env = {
  apiUrl: import.meta.env.VITE_API_URL as string,
} as const;
```

---

## Logging

### Backend

Use NestJS's built-in `Logger` — instantiate per-class, not globally:

```ts
@Injectable()
export class UserService {
  private readonly logger = new Logger(UserService.name);

  async findOne(id: string) {
    this.logger.debug(`Finding user ${id}`);
    // ...
  }
}
```

Log levels by environment:
- `development`: `debug` and above
- `production`: `warn` and above

### Frontend

Create a logger utility that wraps `console` and is a no-op in production:

```ts
// src/utils/logger.ts
const isDev = import.meta.env.DEV;

export const logger = {
  debug: (...args: unknown[]) => isDev && console.debug(...args),
  warn: (...args: unknown[]) => console.warn(...args),
  error: (...args: unknown[]) => console.error(...args),
};
```

---

## Code Comments

Write comments to explain **why**, not **what**. The what is visible in the code.

```ts
// Bad: restates the code
// Finds user by id
const user = await this.userService.findById(id);

// Good: explains non-obvious reasoning
// We re-fetch here rather than using the cached value because the OAuth
// callback may have updated the user's profile since the token was issued.
const user = await this.userService.findById(id);
```

Add a JSDoc comment on every exported function/class with a non-obvious signature.
