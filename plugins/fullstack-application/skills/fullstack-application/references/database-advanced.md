---
title: Database Advanced Patterns
weight: 4
---

# Database Advanced Patterns

This reference covers Prisma patterns beyond basic CRUD: seeding, migration strategies, query optimization, indexes, transactions, soft deletes, and connection pooling. For basic Prisma setup and schema conventions, see `backend.md`.

## Table of Contents

- [Database Seeding](#database-seeding)
- [Migration Strategies](#migration-strategies)
- [Query Optimization](#query-optimization)
- [Indexes](#indexes)
- [Connection Pooling](#connection-pooling)
- [Transactions](#transactions)
- [Soft Deletes](#soft-deletes)
- [Full-Text Search](#full-text-search)
- [JSON Columns](#json-columns)
- [Optimistic Concurrency](#optimistic-concurrency)

---

## Database Seeding

### Setup

In `packages/database/package.json`:

```json
{
  "prisma": {
    "seed": "tsx prisma/seed.ts"
  }
}
```

Run with `npx prisma db seed`. Also runs automatically after `prisma migrate reset`.

### Seed Structure

```
packages/database/prisma/
├── seed.ts            # orchestrator
├── seeds/
│   ├── roles.seed.ts
│   ├── users.seed.ts
│   └── products.seed.ts
```

### Idempotent Seeds

Use `upsert` so seeds can be re-run safely:

```ts
// seeds/roles.seed.ts
export async function seedRoles(prisma: PrismaClient) {
  const roles = [
    { name: 'ADMIN', description: 'Full access' },
    { name: 'USER', description: 'Standard access' },
  ];

  for (const role of roles) {
    await prisma.role.upsert({
      where: { name: role.name },
      update: { description: role.description },
      create: role,
    });
  }
}
```

For bulk inserts: `createMany({ data: roles, skipDuplicates: true })`.

### Environment-Aware Seeding

```ts
const env = process.env.NODE_ENV ?? 'development';

async function main() {
  await seedRoles(prisma);     // always: reference data
  await seedPermissions(prisma);

  if (env === 'development') {
    await seedDevUsers(prisma);   // fake data for local dev
    await seedSampleProducts(prisma);
  }
  // Production: only seed system-critical lookup data
}
```

---

## Migration Strategies

### Commands

| Command | Purpose | Environment |
|---------|---------|-------------|
| `prisma migrate dev` | Create and apply migrations | Local dev only |
| `prisma migrate deploy` | Apply pending migrations | CI, staging, production |
| `prisma migrate status` | Check migration status | CI (validation) |

**Never run `prisma migrate dev` in CI or production.** It can reset the database if drift is detected.

### Zero-Downtime Migrations

Use the **expand-then-contract** pattern: never do a breaking change in a single step.

**Renaming a column** (`name` → `fullName`):

Step 1 — Add new column, backfill, deploy code that writes to both:
```sql
ALTER TABLE "User" ADD COLUMN "fullName" TEXT;
UPDATE "User" SET "fullName" = "name";
```

Step 2 — After all reads use `fullName`, drop old column:
```sql
ALTER TABLE "User" DROP COLUMN "name";
```

**Adding a NOT NULL column:**

```sql
-- Step 1: add as nullable
ALTER TABLE "User" ADD COLUMN "tenantId" TEXT;
-- Step 2: backfill
UPDATE "User" SET "tenantId" = 'default' WHERE "tenantId" IS NULL;
-- Step 3 (separate migration): add constraint
ALTER TABLE "User" ALTER COLUMN "tenantId" SET NOT NULL;
```

### Rollback

Prisma has no `migrate down`. Options:

1. **Forward-fix**: Create a new migration that reverts the change (recommended)
2. **Manual**: Apply reverse SQL with `prisma db execute --file rollback.sql`
3. **Snapshot restore**: Restore from database backup

Always take a database snapshot before running production migrations.

---

## Query Optimization

### select vs include

`include` fetches entire related records. `select` picks individual fields:

```ts
// Over-fetching — all user fields + all post fields
const users = await prisma.user.findMany({ include: { posts: true } });

// Precise — only what the API response needs
const users = await prisma.user.findMany({
  select: {
    id: true, email: true,
    posts: { select: { id: true, title: true } },
  },
});
```

### Avoiding N+1

Prisma's relation queries batch automatically (`WHERE id IN (...)`), so `include` is safe:

```ts
// This is 2 queries, not N+1
const users = await prisma.user.findMany({ include: { posts: true } });
```

The N+1 trap is in application code loops:

```ts
// BAD — N+1
const users = await prisma.user.findMany();
for (const user of users) {
  const posts = await prisma.post.findMany({ where: { authorId: user.id } });
}
```

### Slow Query Detection

```ts
const prisma = new PrismaClient({
  log: [{ level: 'query', emit: 'event' }],
});

prisma.$on('query', (e) => {
  if (e.duration > 500) {
    console.warn(`Slow query (${e.duration}ms): ${e.query}`);
  }
});
```

---

## Indexes

Prisma does not auto-index foreign keys. Add them explicitly.

```prisma
model Post {
  id          String    @id @default(cuid())
  title       String
  slug        String    @unique
  authorId    String
  categoryId  String
  status      PostStatus
  publishedAt DateTime?

  author   User     @relation(fields: [authorId], references: [id])
  category Category @relation(fields: [categoryId], references: [id])

  @@index([authorId])                           // FK index
  @@index([status, publishedAt(sort: Desc)])    // composite for filter + sort
  @@index([categoryId, status])                 // composite for multi-column lookup
  @@unique([authorId, slug])                    // unique business rule
}
```

**When to index:**
- Foreign key columns used in WHERE or JOIN
- Columns in `orderBy`
- Columns in frequent `WHERE` clauses
- Composite: put the most selective or equality-check column first

**When NOT to index:**
- Tables with very few rows
- Very low cardinality columns alone (e.g., boolean)
- Write-heavy tables where index maintenance outweighs read benefit

---

## Connection Pooling

### PgBouncer

Use two database URLs — one through PgBouncer for queries, one direct for migrations:

```dotenv
DATABASE_URL="postgresql://user:pass@pgbouncer:6432/mydb?pgbouncer=true"
DIRECT_URL="postgresql://user:pass@db:5432/mydb"
```

```prisma
datasource db {
  provider  = "postgresql"
  url       = env("DATABASE_URL")
  directUrl = env("DIRECT_URL")
}
```

### Pool Sizing

Rule of thumb: `num_physical_cores * 2 + 1` for the database server, divided across app instances.

Set via URL parameter: `?connection_limit=20&pool_timeout=30`

---

## Transactions

### Sequential (batch)

All-or-nothing, single round trip:

```ts
const [user, post] = await prisma.$transaction([
  prisma.user.create({ data: { email: 'a@b.com', name: 'A' } }),
  prisma.post.create({ data: { title: 'First', authorId: knownId } }),
]);
```

### Interactive

When later operations depend on earlier results:

```ts
const result = await prisma.$transaction(async (tx) => {
  const user = await tx.user.create({ data: { email: 'a@b.com', name: 'A' } });
  const post = await tx.post.create({ data: { title: 'First', authorId: user.id } });

  if (someCondition) throw new Error('Rolling back');

  return { user, post };
}, {
  maxWait: 5000,
  timeout: 10000,
  isolationLevel: 'Serializable',
});
```

---

## Soft Deletes

Use Prisma client extensions (not the deprecated middleware API):

```prisma
model Post {
  id        String    @id @default(cuid())
  title     String
  deletedAt DateTime?
  @@index([deletedAt])
}
```

```ts
const prisma = new PrismaClient().$extends({
  query: {
    post: {
      async findMany({ args, query }) {
        args.where = { ...args.where, deletedAt: null };
        return query(args);
      },
      async findFirst({ args, query }) {
        args.where = { ...args.where, deletedAt: null };
        return query(args);
      },
      async delete({ args }) {
        return prisma.post.update({
          where: args.where,
          data: { deletedAt: new Date() },
        });
      },
    },
  },
});
```

---

## Full-Text Search

PostgreSQL has built-in full-text search. Add a generated tsvector column via a custom migration:

```sql
ALTER TABLE "Article" ADD COLUMN "searchVector" tsvector
  GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce("title", '')), 'A') ||
    setweight(to_tsvector('english', coalesce("content", '')), 'B')
  ) STORED;

CREATE INDEX "Article_searchVector_idx" ON "Article" USING GIN ("searchVector");
```

Query with Prisma's native search or raw SQL:

```ts
const results = await prisma.$queryRaw`
  SELECT id, title,
         ts_rank("searchVector", websearch_to_tsquery('english', ${query})) AS rank
  FROM "Article"
  WHERE "searchVector" @@ websearch_to_tsquery('english', ${query})
  ORDER BY rank DESC
  LIMIT ${limit}
`;
```

---

## JSON Columns

Use `Json` for truly dynamic data. Always validate at the application boundary:

```prisma
model User {
  id          String @id @default(cuid())
  preferences Json   @default("{}")
}
```

```ts
import { z } from 'zod';

const UserPreferencesSchema = z.object({
  theme: z.enum(['light', 'dark']).default('light'),
  locale: z.string().default('en-US'),
  notifications: z.object({
    email: z.boolean().default(true),
    push: z.boolean().default(false),
  }).default({}),
});
```

If you need to query or sort on fields inside the data, use a separate table instead.

---

## Optimistic Concurrency

Prevent lost updates from concurrent writes with a version field:

```prisma
model Product {
  id      String @id @default(cuid())
  name    String
  stock   Int
  version Int    @default(0)
}
```

```ts
async function decrementStock(productId: string, quantity: number) {
  const product = await prisma.product.findUniqueOrThrow({ where: { id: productId } });

  if (product.stock < quantity) throw new Error('Insufficient stock');

  const updated = await prisma.product.updateMany({
    where: { id: productId, version: product.version },
    data: { stock: product.stock - quantity, version: { increment: 1 } },
  });

  if (updated.count === 0) {
    throw new Error('Concurrent modification — retry');
  }
}
```

Wrap with a retry loop (3 attempts with exponential backoff).
