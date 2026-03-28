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

```ts
// apps/web/vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'node:path';

export default defineConfig({
  plugins: [react()],
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
  tagTypes: ['User'],   // expand as needed
  endpoints: () => ({}),
});
```

### Feature Slice + API Pattern

Each feature owns its slice and its RTK Query endpoints. Inject endpoints into the base API:

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

```ts
// tailwind.config.ts
import type { Config } from 'tailwindcss';

export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        // Define project-specific colors here
        primary: { DEFAULT: '#3B82F6', dark: '#1D4ED8' },
      },
    },
  },
  plugins: [],
} satisfies Config;
```

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

## Frontend Testing (Jest)

```ts
// jest.config.ts (apps/web)
import type { Config } from 'jest';

export default {
  preset: 'ts-jest',
  testEnvironment: 'jsdom',
  setupFilesAfterFramework: ['<rootDir>/src/test/setup.ts'],
  moduleNameMapper: { '^@/(.*)$': '<rootDir>/src/$1' },
  coverageThreshold: { global: { lines: 80, functions: 80 } },
} satisfies Config;
```

```ts
// src/test/setup.ts
import '@testing-library/jest-dom';
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

Wrap components in a test store wrapper when they use `useAppSelector` or dispatch.
