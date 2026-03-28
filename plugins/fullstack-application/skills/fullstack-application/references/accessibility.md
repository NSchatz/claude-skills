---
title: Accessibility
weight: 12
---

# Accessibility (a11y)

This reference covers WCAG 2.1 AA compliance for React applications: semantic HTML, keyboard navigation, ARIA patterns, focus management, color contrast, screen reader support, and motion preferences.

## Table of Contents

- [Core Requirements](#core-requirements)
- [Skip Link](#skip-link)
- [Focus Trap Hook](#focus-trap-hook)
- [Accessible Modal](#accessible-modal)
- [Accessible Tabs](#accessible-tabs)
- [Live Regions](#live-regions)
- [Dark Mode](#dark-mode)
- [Motion Preferences](#motion-preferences)
- [Testing](#testing)

---

## Core Requirements

| Category | Requirement | Implementation |
|----------|-------------|---------------|
| Perceivable | Text alternatives | `alt` on all `<img>`; decorative images get `alt=""` |
| Perceivable | Color contrast | >= 4.5:1 for text, >= 3:1 for large text |
| Operable | Keyboard accessible | Native `<button>`, `<a>`, `<input>`; custom widgets need `tabIndex`, `onKeyDown` |
| Operable | No keyboard traps | Focus must be escapable from every component |
| Operable | Skip navigation | First focusable element is a skip link |
| Understandable | Form labels | `htmlFor`/`id` pairing or wrapping `<label>` |
| Understandable | Error identification | `aria-invalid`, `aria-describedby` pointing to error text |
| Robust | Semantic HTML | Correct heading hierarchy (`h1` > `h2` > `h3`), landmark regions |

**General rule:** Use native HTML elements first. Only add ARIA when native semantics are insufficient. A `<button>` is always better than a `<div role="button" tabIndex={0} onKeyDown={...}>`.

---

## Skip Link

```tsx
export function SkipLink() {
  return (
    <a
      href="#main-content"
      className="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4
                 focus:z-50 focus:bg-white focus:px-4 focus:py-2 focus:rounded
                 focus:shadow-lg focus:text-blue-700"
    >
      Skip to main content
    </a>
  );
}

// In root layout:
<SkipLink />
<header>...</header>
<main id="main-content" tabIndex={-1}>...</main>
```

---

## Focus Trap Hook

For modals, drawers, and popovers — traps focus within the container and restores it on close.

```ts
import { useEffect, useRef } from 'react';

const FOCUSABLE = 'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

export function useFocusTrap(active: boolean) {
  const containerRef = useRef<HTMLDivElement>(null);
  const previousFocusRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (!active) return;
    previousFocusRef.current = document.activeElement as HTMLElement;

    const container = containerRef.current;
    if (!container) return;

    const focusable = () => Array.from(container.querySelectorAll<HTMLElement>(FOCUSABLE));
    focusable()[0]?.focus();

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key !== 'Tab') return;
      const elements = focusable();
      const first = elements[0];
      const last = elements.at(-1);

      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last?.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first?.focus();
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.removeEventListener('keydown', handleKeyDown);
      previousFocusRef.current?.focus();
    };
  }, [active]);

  return containerRef;
}
```

---

## Accessible Modal

```tsx
import { useEffect, useId } from 'react';
import { createPortal } from 'react-dom';
import { useFocusTrap } from '@/hooks/useFocusTrap';

interface ModalProps {
  open: boolean;
  onClose: () => void;
  title: string;
  children: React.ReactNode;
}

export function Modal({ open, onClose, title, children }: ModalProps) {
  const titleId = useId();
  const containerRef = useFocusTrap(open);

  useEffect(() => {
    if (!open) return;
    const handleEscape = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    document.body.style.overflow = 'hidden';
    document.addEventListener('keydown', handleEscape);
    return () => {
      document.body.style.overflow = '';
      document.removeEventListener('keydown', handleEscape);
    };
  }, [open, onClose]);

  if (!open) return null;

  return createPortal(
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      <div className="absolute inset-0 bg-black/50" aria-hidden="true" onClick={onClose} />
      <div ref={containerRef} role="dialog" aria-modal="true" aria-labelledby={titleId}
        className="relative z-10 bg-white rounded-lg shadow-xl p-6 max-w-lg w-full mx-4">
        <h2 id={titleId} className="text-xl font-semibold mb-4">{title}</h2>
        {children}
        <button onClick={onClose} aria-label="Close dialog"
          className="absolute top-3 right-3 text-gray-400 hover:text-gray-600">
          &times;
        </button>
      </div>
    </div>,
    document.body,
  );
}
```

Key patterns:
- `role="dialog"` + `aria-modal="true"` tells screen readers it's a modal
- `aria-labelledby` associates the title
- Focus trap prevents tabbing outside
- Escape key closes
- Background scroll is locked
- Focus returns to trigger element on close

---

## Accessible Tabs

Arrow keys navigate between tabs. Only the active tab is in the tab order.

```tsx
import { useState, useRef, useId, useCallback } from 'react';

export function Tabs({ tabs }: { tabs: Array<{ label: string; content: React.ReactNode }> }) {
  const [active, setActive] = useState(0);
  const tabRefs = useRef<(HTMLButtonElement | null)[]>([]);
  const baseId = useId();

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    let next = active;
    switch (e.key) {
      case 'ArrowRight': next = (active + 1) % tabs.length; break;
      case 'ArrowLeft': next = (active - 1 + tabs.length) % tabs.length; break;
      case 'Home': next = 0; break;
      case 'End': next = tabs.length - 1; break;
      default: return;
    }
    e.preventDefault();
    setActive(next);
    tabRefs.current[next]?.focus();
  }, [active, tabs.length]);

  return (
    <div>
      <div role="tablist" aria-label="Content tabs" onKeyDown={handleKeyDown}>
        {tabs.map((tab, i) => (
          <button key={i} ref={(el) => { tabRefs.current[i] = el; }}
            role="tab" id={`${baseId}-tab-${i}`}
            aria-selected={i === active} aria-controls={`${baseId}-panel-${i}`}
            tabIndex={i === active ? 0 : -1} onClick={() => setActive(i)}
            className={i === active ? 'border-b-2 border-blue-600 text-blue-600' : 'text-gray-500'}>
            {tab.label}
          </button>
        ))}
      </div>
      {tabs.map((tab, i) => (
        <div key={i} role="tabpanel" id={`${baseId}-panel-${i}`}
          aria-labelledby={`${baseId}-tab-${i}`} hidden={i !== active} tabIndex={0}>
          {tab.content}
        </div>
      ))}
    </div>
  );
}
```

---

## Live Regions

For dynamic content that screen readers should announce (toasts, status updates):

```tsx
export function LiveRegion({ message, priority = 'polite' }: {
  message: string;
  priority?: 'polite' | 'assertive';
}) {
  return (
    <div role="status" aria-live={priority} aria-atomic="true" className="sr-only">
      {message}
    </div>
  );
}
```

- `polite`: announces when the screen reader is idle (notifications, success messages)
- `assertive`: interrupts immediately (errors, urgent alerts)

---

## Dark Mode

Tailwind v4 uses CSS custom properties with `@custom-variant`:

```css
@import "tailwindcss";

@custom-variant dark (&:where(.dark, .dark *));

@theme {
  --color-surface: #ffffff;
  --color-text-primary: #111827;
}

.dark {
  --color-surface: #0f172a;
  --color-text-primary: #f1f5f9;
}
```

```ts
// hooks/useDarkMode.ts
export function useDarkMode() {
  const [theme, setThemeState] = useState<'light' | 'dark' | 'system'>(() =>
    (localStorage.getItem('theme') as any) ?? 'system',
  );

  const applyTheme = useCallback((t: string) => {
    const isDark = t === 'dark' || (t === 'system' && matchMedia('(prefers-color-scheme: dark)').matches);
    document.documentElement.classList.toggle('dark', isDark);
  }, []);

  const setTheme = useCallback((t: 'light' | 'dark' | 'system') => {
    setThemeState(t);
    localStorage.setItem('theme', t);
    applyTheme(t);
  }, [applyTheme]);

  useEffect(() => {
    applyTheme(theme);
    if (theme !== 'system') return;
    const mq = matchMedia('(prefers-color-scheme: dark)');
    const handler = () => applyTheme('system');
    mq.addEventListener('change', handler);
    return () => mq.removeEventListener('change', handler);
  }, [theme, applyTheme]);

  return { theme, setTheme };
}
```

---

## Motion Preferences

Respect `prefers-reduced-motion` for users who are sensitive to animation:

```css
/* In globals.css */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

In JavaScript:

```ts
const prefersReducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
// Use for conditional animations in JS (e.g., skip complex transitions)
```

---

## Testing

### Automated

Add `axe-core` to your test suite:

```bash
pnpm add -D @axe-core/react axe-core
```

```ts
// In test setup (development only)
import React from 'react';
import ReactDOM from 'react-dom';

if (process.env.NODE_ENV === 'development') {
  import('@axe-core/react').then((axe) => {
    axe.default(React, ReactDOM, 1000);
  });
}
```

### CI Integration

```bash
pnpm add -D @axe-core/playwright
```

```ts
// e2e/tests/a11y.spec.ts
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test('homepage passes accessibility audit', async ({ page }) => {
  await page.goto('/');
  const results = await new AxeBuilder({ page }).analyze();
  expect(results.violations).toEqual([]);
});
```

### Manual Testing Checklist

- Tab through the entire page — is the focus order logical?
- Can every interactive element be activated with keyboard (Enter/Space)?
- Do screen readers (VoiceOver on Mac, NVDA on Windows) announce content correctly?
- Is color contrast sufficient? (Use browser DevTools accessibility inspector)
- Do error messages announce themselves to screen readers?
