# Frontend

## Stack

- **Framework**: React 18 + Vite
- **State**: Redux Toolkit (slices) + RTK Query (API)
- **Routing**: React Router v6
- **Styling**: Tailwind CSS (custom components only — no component library)
- **Testing**: Jest + React Testing Library
- **Language**: TypeScript strict

---

## Vite Configuration

Use the first-party `@tailwindcss/vite` plugin (Tailwind v4) instead of PostCSS. It provides significantly faster HMR and eliminates the PostCSS config file.

```ts
// apps/web/vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import path from 'node:path';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: { '@': path.resolve(__dirname, 'src') },
  },
  server: {
    port: 5173,
    proxy: {
      '/api': { target: 'http://localhost:3001', changeOrigin: true },
    },
  },
});
```

---

## Redux Store

### Store Setup

```ts
// src/app/store.ts
import { configureStore } from '@reduxjs/toolkit';
import { baseApi } from '@/services/baseApi';
import { authSlice } from '@/features/auth/authSlice';

export const store = configureStore({
  reducer: {
    [baseApi.reducerPath]: baseApi.reducer,
    auth: authSlice.reducer,
  },
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware().concat(baseApi.middleware),
});

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;
```

### Typed Hooks

```ts
// src/app/hooks.ts
import { useDispatch, useSelector } from 'react-redux';
import type { RootState, AppDispatch } from './store';

export const useAppDispatch = () => useDispatch<AppDispatch>();
export const useAppSelector = <T>(selector: (state: RootState) => T) =>
  useSelector(selector);
```

Always use `useAppDispatch` and `useAppSelector` — never the untyped versions.

### Base API (RTK Query)

There must be exactly **one `createApi` call per backend base URL**. Never create multiple API slices for the same server — use `injectEndpoints` to add feature-level endpoints to the shared base. Multiple API slices cause cache fragmentation and make tag invalidation unreliable.

```ts
// src/services/baseApi.ts
import { createApi, fetchBaseQuery } from '@reduxjs/toolkit/query/react';
import { env } from '@/utils/env';
import type { RootState } from '@/app/store';

export const baseApi = createApi({
  reducerPath: 'api',
  baseQuery: fetchBaseQuery({
    baseUrl: `${env.apiUrl}/api`,
    prepareHeaders: (headers, { getState }) => {
      const token = (getState() as RootState).auth.accessToken;
      if (token) headers.set('Authorization', `Bearer ${token}`);
      return headers;
    },
  }),
  tagTypes: ['User'],   // expand as needed per feature
  endpoints: () => ({}),
});
```

### Feature Slice + API Pattern

Each feature injects its endpoints into the base API and owns its own slice for local UI state:

```ts
// src/features/user/userApi.ts
import { baseApi } from '@/services/baseApi';
import type { User, UpdateUserDto } from '@myapp/shared';

export const userApi = baseApi.injectEndpoints({
  endpoints: (builder) => ({
    getMe: builder.query<User, void>({
      query: () => '/users/me',
      providesTags: ['User'],
    }),
    updateMe: builder.mutation<User, UpdateUserDto>({
      query: (body) => ({ url: '/users/me', method: 'PATCH', body }),
      invalidatesTags: ['User'],
    }),
  }),
});

export const { useGetMeQuery, useUpdateMeMutation } = userApi;
```

```ts
// src/features/user/userSlice.ts
import { createSlice, type PayloadAction } from '@reduxjs/toolkit';
import type { User } from '@myapp/shared';

interface UserState {
  profile: User | null;
}

const initialState: UserState = { profile: null };

export const userSlice = createSlice({
  name: 'user',
  initialState,
  reducers: {
    setProfile: (state, action: PayloadAction<User>) => {
      state.profile = action.payload;
    },
    clearProfile: (state) => {
      state.profile = null;
    },
  },
});

export const { setProfile, clearProfile } = userSlice.actions;
```

---

## React Router

```tsx
// src/app/router.tsx
import { createBrowserRouter } from 'react-router-dom';
import { RootLayout } from '@/layouts/RootLayout';
import { ProtectedLayout } from '@/layouts/ProtectedLayout';
import { HomePage } from '@/features/home/HomePage';
import { DashboardPage } from '@/features/dashboard/DashboardPage';

export const router = createBrowserRouter([
  {
    element: <RootLayout />,
    children: [
      { path: '/', element: <HomePage /> },
      {
        element: <ProtectedLayout />,   // redirects to /login if not authed
        children: [
          { path: '/dashboard', element: <DashboardPage /> },
        ],
      },
    ],
  },
]);
```

```tsx
// src/App.tsx
import { Provider } from 'react-redux';
import { RouterProvider } from 'react-router-dom';
import { store } from '@/app/store';
import { router } from '@/app/router';

export function App() {
  return (
    <Provider store={store}>
      <RouterProvider router={router} />
    </Provider>
  );
}
```

---

## Tailwind CSS

### Setup

Tailwind v4 uses a CSS-first configuration approach. The `tailwind.config.js` file is no longer needed — theme customization lives in the CSS file via `@theme`. The `@tailwindcss/vite` plugin handles content detection automatically (no `content:` array needed).

```css
/* src/styles/globals.css */
@import "tailwindcss";

@theme {
  /* Define project tokens here — automatically exposed as CSS variables */
  --color-primary: oklch(0.6 0.2 250);
  --color-primary-dark: oklch(0.45 0.2 250);
  --font-sans: "Inter", sans-serif;
}
```

```ts
// main.tsx
import '@/styles/globals.css';
```

**Notable Tailwind v4 behavior changes to be aware of:**
- `cursor-pointer` is no longer set on buttons by default (browser default `cursor-default` applies)
- Placeholder text color is now 50% opacity of the current color, not a fixed gray
- Gradient utilities changed: `bg-gradient-to-r` → `bg-linear-to-r`
- Container queries are built-in — no plugin needed (`@container`, `@lg:`)

### Component Pattern

Build all UI components from scratch using Tailwind. Use a `cn()` utility for conditional class merging:

```ts
// src/utils/cn.ts
import { clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';
import type { ClassValue } from 'clsx';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

```tsx
// src/components/ui/Button.tsx
import { cn } from '@/utils/cn';
import type { ButtonHTMLAttributes } from 'react';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
}

const variantClasses = {
  primary: 'bg-primary text-white hover:bg-primary-dark',
  secondary: 'bg-gray-100 text-gray-900 hover:bg-gray-200',
  ghost: 'text-gray-700 hover:bg-gray-100',
};

const sizeClasses = {
  sm: 'px-3 py-1.5 text-sm',
  md: 'px-4 py-2 text-base',
  lg: 'px-6 py-3 text-lg',
};

export function Button({
  variant = 'primary',
  size = 'md',
  className,
  children,
  ...props
}: ButtonProps) {
  return (
    <button
      className={cn(
        'inline-flex items-center justify-center rounded-md font-medium transition-colors',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary',
        'disabled:pointer-events-none disabled:opacity-50',
        variantClasses[variant],
        sizeClasses[size],
        className,
      )}
      {...props}
    >
      {children}
    </button>
  );
}
```

**Rules:**
- Use `cn()` for all conditional class logic — never string concatenation
- Extend the Tailwind theme for brand colors and spacing — avoid one-off inline values
- No inline `style` props unless truly dynamic (e.g., runtime-calculated widths)

---

## Component Guidelines

### Structure

Keep components small and focused. A component that does too much should be split:

```
features/dashboard/
├── DashboardPage.tsx        # Route entry — composes sections
├── components/
│   ├── DashboardHeader.tsx
│   ├── MetricsGrid.tsx
│   └── ActivityFeed.tsx
├── dashboardSlice.ts
├── dashboardApi.ts
└── index.ts
```

### Data Fetching

Fetch data with RTK Query hooks directly in the component that needs it. Avoid prop-drilling fetched data — let components subscribe themselves:

```tsx
function MetricsGrid() {
  const { data: metrics, isLoading } = useGetMetricsQuery();

  if (isLoading) return <MetricsSkeleton />;
  if (!metrics) return null;

  return (
    <div className="grid grid-cols-3 gap-4">
      {metrics.map((m) => <MetricCard key={m.id} metric={m} />)}
    </div>
  );
}
```

### Custom Hooks

Extract complex logic and side effects into custom hooks in `src/hooks/` (shared) or `features/<feature>/use<Hook>.ts` (feature-local):

```ts
// src/hooks/useDebounce.ts
import { useEffect, useState } from 'react';

export function useDebounce<T>(value: T, delay: number): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);
  return debounced;
}
```

---

## React 19 Notes

React 19 (December 2024) is the current stable version. Key changes that affect how we write components:

- **`forwardRef` is deprecated** — refs are now a direct prop. Stop wrapping components in `forwardRef`.
- **`use()` hook** — can be called conditionally; use it to unwrap Promises and Context.
- **Actions API** — pass async functions to `<form action={...}>` for built-in pending/error states via `useActionState` and `useFormStatus`.
- **Auto-memoization** (React Compiler, opt-in) — reduces need for `useMemo`/`useCallback` when enabled.

For new components, write refs as props directly:

```tsx
// React 19 — ref is a regular prop
function Input({ ref, ...props }: InputHTMLAttributes<HTMLInputElement> & { ref?: Ref<HTMLInputElement> }) {
  return <input ref={ref} {...props} />;
}
```

---

## Frontend Testing (Jest + React Testing Library)

**Prefer Vitest over Jest** for Vite projects — it shares Vite's config, runs faster, and uses identical syntax. If starting fresh, use Vitest. The patterns below apply to both.

```ts
// vitest.config.ts (apps/web) — preferred for Vite projects
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    coverage: { thresholds: { lines: 80, functions: 80 } },
  },
  resolve: { alias: { '@': '/src' } },
});
```

```ts
// src/test/setup.ts
import '@testing-library/jest-dom';
```

### Locator Priority

Always prefer accessible, semantic locators. This order matches how real users and screen readers perceive the page:

```ts
// Best — role-based
screen.getByRole('button', { name: /submit/i })
screen.getByLabelText(/email/i)
screen.getByText(/welcome/i)

// Acceptable — explicit test hook
screen.getByTestId('submit-button')

// Avoid — fragile, couples tests to implementation
container.querySelector('.btn-primary')
```

### User Events

Always use `@testing-library/user-event` instead of `fireEvent`. `userEvent` simulates real browser event sequences (pointerdown, mousedown, focus, click, etc.), while `fireEvent` dispatches a single synthetic event and misses intermediate states.

```tsx
import userEvent from '@testing-library/user-event';

it('submits the form', async () => {
  const user = userEvent.setup();
  render(<LoginForm onSubmit={onSubmit} />);

  await user.type(screen.getByLabelText(/email/i), 'jane@example.com');
  await user.click(screen.getByRole('button', { name: /login/i }));

  expect(onSubmit).toHaveBeenCalledWith({ email: 'jane@example.com' });
});
```

### Test Patterns

```tsx
// features/user/components/UserProfile.test.tsx
import { render, screen } from '@testing-library/react';
import { Provider } from 'react-redux';
import { store } from '@/app/store';
import { UserProfile } from './UserProfile';
import type { User } from '@myapp/shared';

const mockUser: User = { id: '1', name: 'Jane Doe', email: 'jane@example.com' };

describe('UserProfile', () => {
  it('renders the user name', () => {
    render(
      <Provider store={store}>
        <UserProfile user={mockUser} />
      </Provider>,
    );
    expect(screen.getByText('Jane Doe')).toBeInTheDocument();
  });
});
```

Wrap components in a test store wrapper when they use `useAppSelector` or dispatch. Do not test internal state or implementation details — test what the user sees and interacts with.
