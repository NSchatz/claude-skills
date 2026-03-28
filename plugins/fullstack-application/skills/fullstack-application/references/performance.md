---
title: Performance Optimization
weight: 13
---

# Performance Optimization

This reference covers frontend performance: code splitting, bundle analysis, image optimization, prefetching, skeleton loading, error boundaries, and advanced RTK Query patterns.

## Table of Contents

- [Code Splitting](#code-splitting)
- [Bundle Analysis](#bundle-analysis)
- [Vite Build Optimization](#vite-build-optimization)
- [Image Optimization](#image-optimization)
- [Skeleton Loading](#skeleton-loading)
- [Error Boundaries](#error-boundaries)
- [RTK Query Advanced Patterns](#rtk-query-advanced-patterns)
- [Toast System](#toast-system)
- [Infinite Scroll](#infinite-scroll)

---

## Code Splitting

Use `React.lazy` + `Suspense` for route-based splitting. Each lazy route becomes its own chunk.

```tsx
import { lazy, Suspense } from 'react';
import { createBrowserRouter, Outlet } from 'react-router-dom';

const Dashboard = lazy(() => import('@/pages/Dashboard'));
const Settings = lazy(() => import('@/pages/Settings'));
const UserProfile = lazy(() => import('@/pages/UserProfile'));

function SuspenseLayout() {
  return (
    <Suspense fallback={<PageSkeleton />}>
      <Outlet />
    </Suspense>
  );
}

export const router = createBrowserRouter([
  {
    element: <SuspenseLayout />,
    children: [
      { path: '/', element: <Dashboard /> },
      { path: '/settings', element: <Settings /> },
      { path: '/users/:id', element: <UserProfile /> },
    ],
  },
]);
```

### Preload on Hover

Trigger chunk download on link hover for near-instant navigation:

```tsx
const preloadMap = {
  dashboard: () => import('@/pages/Dashboard'),
  settings: () => import('@/pages/Settings'),
};

export function PreloadLink({ preloadKey, ...props }: LinkProps & { preloadKey: keyof typeof preloadMap }) {
  return (
    <Link {...props}
      onMouseEnter={() => preloadMap[preloadKey]()}
      onFocus={() => preloadMap[preloadKey]()} />
  );
}
```

---

## Bundle Analysis

```bash
pnpm add -D rollup-plugin-visualizer
```

```ts
// vite.config.ts
import { visualizer } from 'rollup-plugin-visualizer';

export default defineConfig(({ mode }) => ({
  plugins: [
    mode === 'analyze' && visualizer({
      open: true, gzipSize: true, filename: 'dist/bundle-analysis.html',
    }),
  ].filter(Boolean),
}));
```

Run: `npx vite build --mode analyze`

Review regularly to catch bundle bloat. Watch for accidentally imported heavy libraries.

---

## Vite Build Optimization

```ts
export default defineConfig({
  build: {
    target: 'es2022',
    cssCodeSplit: true,
    rollupOptions: {
      output: {
        manualChunks: {
          'vendor-react': ['react', 'react-dom'],
          'vendor-redux': ['@reduxjs/toolkit', 'react-redux'],
          'vendor-router': ['react-router-dom'],
          'vendor-form': ['react-hook-form', '@hookform/resolvers', 'zod'],
        },
      },
    },
    chunkSizeWarningLimit: 500,
  },
  optimizeDeps: {
    include: ['react', 'react-dom', 'react-router-dom', '@reduxjs/toolkit', 'react-redux'],
  },
});
```

Separating vendor chunks improves caching — vendor code changes less often than app code.

---

## Image Optimization

```tsx
interface OptimizedImageProps {
  src: string;
  alt: string;
  width: number;
  height: number;
  sizes?: string;
  priority?: boolean;
}

export function OptimizedImage({ src, alt, width, height, sizes = '100vw', priority = false }: OptimizedImageProps) {
  const [loaded, setLoaded] = useState(false);

  // Generate srcset for responsive images (assumes CDN supports width params)
  const widths = [320, 640, 960, 1280, 1920];
  const srcSet = widths.map((w) => `${src}?w=${w}&format=webp ${w}w`).join(', ');

  return (
    <div className="relative overflow-hidden" style={{ aspectRatio: `${width} / ${height}` }}>
      {!loaded && <div className="absolute inset-0 bg-gray-200 animate-pulse" aria-hidden="true" />}
      <img
        src={`${src}?w=${width}&format=webp`}
        srcSet={srcSet}
        sizes={sizes}
        alt={alt}
        width={width}
        height={height}
        loading={priority ? 'eager' : 'lazy'}
        decoding={priority ? 'sync' : 'async'}
        fetchPriority={priority ? 'high' : 'auto'}
        onLoad={() => setLoaded(true)}
        className={`w-full h-full object-cover transition-opacity ${loaded ? 'opacity-100' : 'opacity-0'}`}
      />
    </div>
  );
}
```

**Key patterns:**
- `loading="lazy"` for below-the-fold images
- `priority` for hero/LCP images — eager load with high fetch priority
- `srcSet` + `sizes` for responsive images
- Aspect ratio container prevents layout shift (CLS)
- WebP format via CDN transformation

---

## Skeleton Loading

```tsx
export function Skeleton({ className = '', lines }: { className?: string; lines?: number }) {
  if (lines) {
    return (
      <div className="space-y-2" aria-busy="true" aria-label="Loading">
        {Array.from({ length: lines }, (_, i) => (
          <div key={i} className={`h-4 bg-gray-200 dark:bg-gray-700 rounded animate-pulse
            ${i === lines - 1 ? 'w-3/4' : 'w-full'}`} />
        ))}
      </div>
    );
  }
  return <div aria-busy="true" className={`bg-gray-200 dark:bg-gray-700 rounded animate-pulse ${className}`} />;
}

export function CardSkeleton() {
  return (
    <div className="border rounded-lg p-4 space-y-4" aria-busy="true">
      <Skeleton className="h-48 w-full rounded" />
      <Skeleton className="h-6 w-3/4" />
      <Skeleton lines={3} />
    </div>
  );
}
```

Usage with RTK Query:

```tsx
function PostList() {
  const { data, isLoading } = useGetPostsQuery();
  if (isLoading) return <div className="grid grid-cols-3 gap-4">
    {Array.from({ length: 6 }, (_, i) => <CardSkeleton key={i} />)}
  </div>;
  return /* ... */;
}
```

---

## Error Boundaries

Wrap each route in its own error boundary so failures are isolated:

```tsx
export class ErrorBoundary extends Component<
  { fallback?: ReactNode | ((error: Error, reset: () => void) => ReactNode); children: ReactNode },
  { error: Error | null }
> {
  state = { error: null as Error | null };

  static getDerivedStateFromError(error: Error) { return { error }; }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    // Report to Sentry
    console.error('ErrorBoundary caught:', error, info.componentStack);
  }

  reset = () => this.setState({ error: null });

  render() {
    if (this.state.error) {
      if (typeof this.props.fallback === 'function') return this.props.fallback(this.state.error, this.reset);
      return this.props.fallback ?? <DefaultErrorFallback onReset={this.reset} />;
    }
    return this.props.children;
  }
}
```

---

## RTK Query Advanced Patterns

### Token Refresh with Mutex

Prevents thundering herd of parallel refresh requests:

```ts
import { Mutex } from 'async-mutex';

const mutex = new Mutex();

const baseQueryWithReauth: BaseQueryFn = async (args, api, extraOptions) => {
  await mutex.waitForUnlock();
  let result = await rawBaseQuery(args, api, extraOptions);

  if (result.error?.status === 401) {
    if (!mutex.isLocked()) {
      const release = await mutex.acquire();
      try {
        const refreshResult = await rawBaseQuery({ url: '/auth/refresh', method: 'POST' }, api, extraOptions);
        if (refreshResult.data) {
          api.dispatch(setCredentials(refreshResult.data));
          result = await rawBaseQuery(args, api, extraOptions);
        } else {
          api.dispatch(logout());
        }
      } finally { release(); }
    } else {
      await mutex.waitForUnlock();
      result = await rawBaseQuery(args, api, extraOptions);
    }
  }
  return result;
};
```

### Optimistic Updates

```ts
likePost: builder.mutation<Post, string>({
  query: (id) => ({ url: `/posts/${id}/like`, method: 'POST' }),
  async onQueryStarted(id, { dispatch, queryFulfilled }) {
    const patch = dispatch(
      postsApi.util.updateQueryData('getPosts', undefined, (draft) => {
        const post = draft.find((p) => p.id === id);
        if (post) post.likes += 1;
      }),
    );
    try { await queryFulfilled; } catch { patch.undo(); }
  },
}),
```

### Global API Error Middleware

```ts
export const apiErrorMiddleware: Middleware = () => (next) => (action) => {
  if (isRejectedWithValue(action)) {
    const status = (action.payload as any)?.status;
    if (status === 401) return next(action); // handled by reauth
    if (status === 403) toast.error('Permission denied');
    else if (status >= 500) toast.error('Server error. Please try again.');
    else if ((action.payload as any)?.error === 'FETCH_ERROR') toast.error('Network error');
  }
  return next(action);
};
```

---

## Toast System

Imperative toast API backed by Redux — usable from both components and middleware:

```ts
// lib/toast.ts
let counter = 0;
export const toast = {
  success: (message: string) => fire('success', message),
  error: (message: string) => fire('error', message),
  warning: (message: string) => fire('warning', message),
  info: (message: string) => fire('info', message),
};

function fire(type: string, message: string, duration = 5000) {
  const id = `toast-${++counter}`;
  store.dispatch(addToast({ id, message, type, duration }));
  setTimeout(() => store.dispatch(removeToast(id)), duration);
}
```

The toast container uses `aria-live="polite"` for screen reader support.

---

## Infinite Scroll

Use Intersection Observer for efficient scroll detection:

```ts
export function useInfiniteScroll(onIntersect: () => void, options: { enabled: boolean }) {
  const sentinelRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!options.enabled || !sentinelRef.current) return;
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) onIntersect(); },
      { rootMargin: '200px' },
    );
    observer.observe(sentinelRef.current);
    return () => observer.disconnect();
  }, [onIntersect, options.enabled]);

  return sentinelRef;
}
```

RTK Query endpoint for merged pages:

```ts
getPostsInfinite: builder.query({
  query: (page) => `/posts?page=${page}&limit=20`,
  serializeQueryArgs: ({ endpointName }) => endpointName,
  merge: (cache, newItems) => {
    cache.items.push(...newItems.items);
    cache.hasMore = newItems.hasMore;
  },
  forceRefetch: ({ currentArg, previousArg }) => currentArg !== previousArg,
}),
```
