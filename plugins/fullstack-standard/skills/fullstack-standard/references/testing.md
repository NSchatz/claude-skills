# Testing

## Strategy

| Type | Tool | Location | What it tests |
|------|------|----------|---------------|
| Unit | Jest | Alongside source (`*.spec.ts`) | Pure functions, service methods with mocked Prisma |
| Integration | Jest + Supertest | `apps/api/test/` | Full HTTP request through real NestJS app + test DB |
| E2E | Playwright | `e2e/tests/` | Critical user flows in a browser |

Coverage threshold: **80% lines and functions** on both apps.

---

## Backend Unit Tests (Jest)

### Configuration

```ts
// apps/api/jest.config.ts
import type { Config } from 'jest';

export default {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: 'src',
  testRegex: '.*\\.spec\\.ts$',
  transform: { '^.+\\.ts$': 'ts-jest' },
  moduleNameMapper: { '^@/(.*)$': '<rootDir>/$1' },
  coverageDirectory: '../coverage',
  collectCoverageFrom: ['**/*.ts', '!**/*.module.ts', '!**/main.ts', '!**/*.dto.ts'],
  coverageThreshold: { global: { lines: 80, functions: 80 } },
  testEnvironment: 'node',
} satisfies Config;
```

### Service Unit Test Pattern

Mock Prisma with `jest.fn()`. Test the service in isolation:

```ts
// posts.service.spec.ts
import { NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { PrismaService } from '@/database/prisma.service';
import { PostsService } from './posts.service';

const mockPrisma = {
  post: {
    create: jest.fn(),
    findMany: jest.fn(),
    findFirst: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  },
};

describe('PostsService', () => {
  let service: PostsService;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        PostsService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get(PostsService);
    jest.clearAllMocks();
  });

  describe('findOneOrThrow', () => {
    it('returns the post when it exists', async () => {
      const post = { id: '1', title: 'Hello', userId: 'u1' };
      mockPrisma.post.findFirst.mockResolvedValue(post);

      const result = await service.findOneOrThrow('1', 'u1');

      expect(result).toEqual(post);
      expect(mockPrisma.post.findFirst).toHaveBeenCalledWith({
        where: { id: '1', userId: 'u1' },
      });
    });

    it('throws NotFoundException when post is not found', async () => {
      mockPrisma.post.findFirst.mockResolvedValue(null);

      await expect(service.findOneOrThrow('999', 'u1')).rejects.toThrow(NotFoundException);
    });
  });
});
```

---

## Backend Integration Tests (Jest + Supertest)

Integration tests boot the real NestJS application against a test database. They test the full HTTP stack including guards, pipes, and interceptors.

### Unit Testing with Mocked Prisma

For pure service-layer unit tests, mock Prisma with `jest-mock-extended` (or `vitest-mock-extended`). This avoids database dependencies and is fast.

```ts
// test/prisma-mock.ts
import { mockDeep, mockReset, type DeepMockProxy } from 'jest-mock-extended';
import { PrismaClient } from '@myapp/database';

export const prismaMock = mockDeep<PrismaClient>();

beforeEach(() => {
  mockReset(prismaMock);
});
```

Use `prismaMock` as the `useValue` for `PrismaService` in unit tests (same pattern shown in the Backend Unit Test section above).

### Integration Test Setup

Integration tests run against a **real PostgreSQL database** — the test database defined by `TEST_DATABASE_URL`. Rather than truncating tables between tests (which is slow and order-dependent), use PostgreSQL savepoints to wrap each test in a transaction that is always rolled back:

```ts
// test/db-helpers.ts
import { PrismaClient } from '@myapp/database';

const prisma = new PrismaClient({
  datasources: { db: { url: process.env.TEST_DATABASE_URL } },
});

beforeAll(async () => {
  await prisma.$connect();
  // Apply any pending migrations against the test DB
});

beforeEach(async () => {
  await prisma.$executeRaw`SAVEPOINT test_savepoint`;
});

afterEach(async () => {
  await prisma.$executeRaw`ROLLBACK TO SAVEPOINT test_savepoint`;
});

afterAll(async () => {
  await prisma.$disconnect();
});

export { prisma };
```

This gives each test a clean slate without the overhead of schema drops or table truncations.

### Integration Test Pattern

```ts
// test/posts.integration.spec.ts
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import * as request from 'supertest';
import { AppModule } from '@/app.module';
import { PrismaService } from '@/database/prisma.service';

describe('Posts (integration)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let accessToken: string;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();

    prisma = app.get(PrismaService);

    // Create a test user and get a token
    const user = await prisma.user.create({
      data: { email: 'test@example.com', name: 'Test User' },
    });
    accessToken = generateTestJwt(user.id); // helper that signs a JWT
  });

  afterAll(async () => {
    await prisma.$executeRaw`TRUNCATE TABLE "users", "posts" RESTART IDENTITY CASCADE`;
    await app.close();
  });

  it('POST /api/posts - creates a post', async () => {
    const response = await request(app.getHttpServer())
      .post('/api/posts')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ title: 'My First Post' })
      .expect(201);

    expect(response.body).toMatchObject({ title: 'My First Post' });
  });

  it('GET /api/posts/:id - returns 404 for unknown post', async () => {
    await request(app.getHttpServer())
      .get('/api/posts/nonexistent')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(404);
  });
});
```

### Test Database

Integration tests require a separate PostgreSQL database. Set `TEST_DATABASE_URL` in `.env.test`:

```dotenv
# .env.test
TEST_DATABASE_URL="postgresql://postgres:postgres@localhost:5432/myapp_test"
```

The CI pipeline spins up a Postgres service container for integration tests — see `references/infrastructure.md`.

---

## Frontend Unit Tests (Jest + RTL)

### Configuration

```ts
// apps/web/jest.config.ts
import type { Config } from 'jest';

export default {
  preset: 'ts-jest',
  testEnvironment: 'jsdom',
  setupFilesAfterFramework: ['<rootDir>/src/test/setup.ts'],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
    '\\.(css|scss)$': 'identity-obj-proxy',
  },
  coverageThreshold: { global: { lines: 80, functions: 80 } },
} satisfies Config;
```

### RTK Query Test Pattern

Wrap components under test with a pre-configured test store and `msw` for API mocking:

```ts
// src/test/renderWithProviders.tsx
import { render, type RenderOptions } from '@testing-library/react';
import { Provider } from 'react-redux';
import { MemoryRouter } from 'react-router-dom';
import { configureStore } from '@reduxjs/toolkit';
import { baseApi } from '@/services/baseApi';
import { authSlice } from '@/features/auth/authSlice';
import type { ReactElement } from 'react';

export function renderWithProviders(
  ui: ReactElement,
  options?: RenderOptions,
) {
  const store = configureStore({
    reducer: {
      [baseApi.reducerPath]: baseApi.reducer,
      auth: authSlice.reducer,
    },
    middleware: (gDM) => gDM().concat(baseApi.middleware),
  });

  return render(
    <Provider store={store}>
      <MemoryRouter>{ui}</MemoryRouter>
    </Provider>,
    options,
  );
}
```

### Slice Unit Test Pattern

Test reducers and selectors directly — no rendering needed:

```ts
// features/user/userSlice.spec.ts
import { userSlice, setProfile, clearProfile } from './userSlice';
import type { User } from '@myapp/shared';

const mockUser: User = { id: '1', name: 'Jane', email: 'jane@example.com' };

describe('userSlice', () => {
  it('sets the profile', () => {
    const state = userSlice.reducer(undefined, setProfile(mockUser));
    expect(state.profile).toEqual(mockUser);
  });

  it('clears the profile', () => {
    const withUser = userSlice.reducer({ profile: mockUser }, clearProfile());
    expect(withUser.profile).toBeNull();
  });
});
```

---

## E2E Tests (Playwright)

### Configuration

```ts
// e2e/playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL ?? 'http://localhost:5173',
    trace: 'on-first-retry',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
  webServer: {
    command: 'pnpm --filter web dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
  },
});
```

### Page Object Model

Every page or major UI region gets a Page Object:

```ts
// e2e/pages/DashboardPage.ts
import type { Page, Locator } from '@playwright/test';

export class DashboardPage {
  readonly page: Page;
  readonly heading: Locator;
  readonly createPostButton: Locator;

  constructor(page: Page) {
    this.page = page;
    this.heading = page.getByRole('heading', { name: 'Dashboard' });
    this.createPostButton = page.getByRole('button', { name: 'New Post' });
  }

  async goto() {
    await this.page.goto('/dashboard');
  }

  async createPost(title: string) {
    await this.createPostButton.click();
    await this.page.getByLabel('Title').fill(title);
    await this.page.getByRole('button', { name: 'Save' }).click();
  }
}
```

### E2E Test Pattern

```ts
// e2e/tests/posts.spec.ts
import { test, expect } from '@playwright/test';
import { DashboardPage } from '../pages/DashboardPage';

test.describe('Posts', () => {
  test.beforeEach(async ({ page }) => {
    // Set auth token in localStorage to skip OAuth flow in tests
    await page.addInitScript((token) => {
      localStorage.setItem('accessToken', token);
    }, process.env.TEST_ACCESS_TOKEN!);
  });

  test('user can create a post', async ({ page }) => {
    const dashboard = new DashboardPage(page);
    await dashboard.goto();
    await expect(dashboard.heading).toBeVisible();

    await dashboard.createPost('My E2E Post');

    await expect(page.getByText('My E2E Post')).toBeVisible();
  });
});
```

### E2E Test Scope

Cover the following flows at minimum:
- Auth: redirect to Google OAuth, callback handling, protected route redirect
- Core CRUD: create, view, update, delete for each primary resource
- Error states: 404 page, form validation errors

### CI Setup

Use `--shard` to parallelize across multiple runners:

```yaml
# In ci.yml
strategy:
  matrix:
    shard: [1, 2, 3, 4]

steps:
  - name: Install Playwright browsers
    run: npx playwright install --with-deps chromium   # Only install what you test

  - name: Run Playwright tests
    run: npx playwright test --shard=${{ matrix.shard }}/4
    env:
      PLAYWRIGHT_BASE_URL: http://localhost:5173
      TEST_ACCESS_TOKEN: ${{ secrets.TEST_ACCESS_TOKEN }}

  - name: Upload test results
    if: always()
    uses: actions/upload-artifact@v4
    with:
      name: playwright-results-${{ matrix.shard }}
      path: playwright-report/
```

**CI practices:**
- Run on Linux only — cheaper than macOS/Windows and behavior is identical for web apps
- Install only the browsers you actually test against — don't install all three browsers in CI
- Upload traces and screenshots as artifacts on failure to enable debugging without re-running
- Use `retries: 2` in config for CI flakiness tolerance — but treat any consistently-retrying test as a bug to fix, not ignore

### Anti-Patterns

- **Never use `page.waitForTimeout(n)`** — this is a time-based sleep that makes tests slow and brittle. Use web-first assertions (`await expect(locator).toBeVisible()`) which auto-retry until the condition is met or timeout.
- Do not test third-party UIs — mock the Google OAuth flow at the network layer with `page.route()` to stub the OAuth callback; don't actually hit Google in tests.
- Do not share browser state between tests — each test gets a fresh browser context. Use Playwright's `storageState` to efficiently reuse authenticated sessions without re-logging in every test.
- Avoid CSS class selectors and XPath — use role-based locators (`getByRole`, `getByLabel`) that survive refactoring.
