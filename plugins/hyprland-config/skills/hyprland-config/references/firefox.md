---
title: Firefox Theming Reference
weight: 7
---

# Firefox Theming Reference

Complete guide to theming Firefox with userChrome.css, userContent.css, and user.js. Load this when the user asks for Firefox theming, a "full rice", or mentions Firefox as a daily app and theming coherence matters.

## Table of Contents
- [Overview](#overview)
- [Profile Path Detection](#profile-path-detection)
- [user.js — Enabling Custom CSS](#userjs--enabling-custom-css)
- [userChrome.css — UI Theming](#userchromecss--ui-theming)
  - [Color Palette Variables](#color-palette-variables)
  - [Toolbar Transparency](#toolbar-transparency)
  - [Floating Tabs](#floating-tabs)
  - [URL Bar](#url-bar)
  - [Bookmarks Bar Auto-Hide](#bookmarks-bar-auto-hide)
  - [Compact Padding](#compact-padding)
  - [Sidebar](#sidebar)
  - [Context Menus](#context-menus)
  - [Findbar](#findbar)
- [userContent.css — Internal Pages](#usercontentcss--internal-pages)
  - [New Tab Page](#new-tab-page)
  - [Settings Page](#settings-page)
  - [Add-ons Manager](#add-ons-manager)
  - [Private Browsing Page](#private-browsing-page)
- [Common Pitfalls](#common-pitfalls)
- [Complete Example — Catppuccin Mocha](#complete-example--catppuccin-mocha)

---

## Overview

Firefox supports three files for customization, all within the active profile directory:

| File | Location | Purpose |
|------|----------|---------|
| `user.js` | `<profile>/user.js` | Sets `about:config` preferences on every launch |
| `userChrome.css` | `<profile>/chrome/userChrome.css` | Styles Firefox's own UI (tabs, toolbar, sidebar, menus) |
| `userContent.css` | `<profile>/chrome/userContent.css` | Styles web content on internal pages (`about:newtab`, `about:preferences`, etc.) |

The `chrome/` directory does not exist by default — create it. Firefox ignores these files unless `toolkit.legacyUserProfileCustomizations.stylesheets` is `true` in `about:config` (set via `user.js`).

Changes require a **full Firefox restart** (quit + reopen, not just reload).

---

## Profile Path Detection

Firefox stores profiles in one of two locations on Linux:

```
~/.mozilla/firefox/profiles.ini
~/.config/mozilla/firefox/profiles.ini
```

Read `profiles.ini` to find the active profile. The active profile for the default install is under the `[Install*]` section:

```ini
[Install4F96D1932A9F858E]
Default=xxxx.default-release    # ← this is the active profile directory name
```

The full path is then: `<firefox-root>/<profile-dir>/`

**Detection script:**
```bash
# Find the profiles.ini
PROFILES_INI=$(find ~/.mozilla ~/.config/mozilla -name "profiles.ini" -path "*firefox*" 2>/dev/null | head -1)
# Extract the active profile directory
PROFILE_DIR=$(grep -A1 '^\[Install' "$PROFILES_INI" | grep "Default=" | cut -d= -f2)
PROFILE_PATH="$(dirname "$PROFILES_INI")/$PROFILE_DIR"
echo "$PROFILE_PATH"
```

---

## user.js — Enabling Custom CSS

`user.js` sets preferences that apply on every Firefox launch, overriding `about:config` values. Place it directly in the profile directory (NOT in `chrome/`).

```javascript
// Enable userChrome.css and userContent.css (required)
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Compact density (optional — smaller toolbar buttons, less padding)
user_pref("browser.compactmode.show", true);
user_pref("browser.uidensity", 1);

// Allow transparent/rounded windows on Wayland (optional)
user_pref("widget.gtk.rounded-bottom-corners.enabled", true);
```

**Density values:** `0` = normal, `1` = compact, `2` = touch.

---

## userChrome.css — UI Theming

### Color Palette Variables

Define the color palette as CSS custom properties on `:root` so all selectors can reference them. Match the user's chosen theme exactly.

```css
:root {
    --ctp-mauve: #cba6f7;
    --ctp-red: #f38ba8;
    --ctp-text: #cdd6f4;
    --ctp-subtext1: #bac2de;
    --ctp-overlay0: #6c7086;
    --ctp-surface2: #585b70;
    --ctp-surface1: #45475a;
    --ctp-surface0: #313244;
    --ctp-base: #1e1e2e;
    --ctp-mantle: #181825;
    --ctp-crust: #11111b;
    /* ... full palette */
}
```

### Toolbar Transparency

Makes the toolbar area semi-transparent so the wallpaper + Hyprland blur shows through. Match the opacity to other transparent apps in the rice (typically 0.85).

```css
#navigator-toolbox {
    background: rgba(30, 30, 46, 0.85) !important;
    border-bottom: 1px solid rgba(69, 71, 90, 0.5) !important;
}
```

### Floating Tabs

The most popular tab style in rices. Tabs appear as rounded pills with gaps between them.

```css
/* Tab bar background */
#TabsToolbar {
    background: transparent !important;
    padding: 4px 4px 0 4px !important;
}

#tabbrowser-tabs {
    border: none !important;
}

/* Individual tabs — rounded pills */
.tabbrowser-tab {
    margin: 2px 2px !important;
    border-radius: 10px !important;
    overflow: hidden !important;
    min-height: 32px !important;
}

.tabbrowser-tab .tab-background {
    border-radius: 10px !important;
    margin: 0 !important;
    border: none !important;
    background: rgba(49, 50, 68, 0.6) !important;
    outline: none !important;
}

/* Active tab — accent color highlight */
.tabbrowser-tab[selected="true"] .tab-background {
    background: rgba(203, 166, 247, 0.2) !important;
    border: 1px solid rgba(203, 166, 247, 0.35) !important;
}

/* Hovered tab */
.tabbrowser-tab:hover:not([selected="true"]) .tab-background {
    background: rgba(69, 71, 90, 0.7) !important;
}

/* Tab text colors */
.tabbrowser-tab .tab-label {
    color: var(--ctp-subtext1) !important;
}

.tabbrowser-tab[selected="true"] .tab-label {
    color: var(--ctp-text) !important;
    font-weight: 600 !important;
}

/* Close button — hidden until hover */
.tabbrowser-tab .tab-close-button {
    border-radius: 50% !important;
    opacity: 0;
    transition: opacity 0.15s ease !important;
}

.tabbrowser-tab:hover .tab-close-button {
    opacity: 1;
}

.tabbrowser-tab .tab-close-button:hover {
    background: rgba(243, 139, 168, 0.3) !important;
    color: var(--ctp-red) !important;
}

/* New tab button */
#tabs-newtab-button,
#new-tab-button {
    border-radius: 10px !important;
    margin: 2px !important;
    padding: 4px 8px !important;
}

#tabs-newtab-button:hover,
#new-tab-button:hover {
    background: rgba(69, 71, 90, 0.7) !important;
}
```

**Match the `border-radius` to the user's Hyprland rounding value** (e.g., `rounding = 10` → `border-radius: 10px`).

For **connected tabs** (traditional style), skip the margin/gap and only round the top corners:

```css
.tabbrowser-tab .tab-background {
    border-radius: 10px 10px 0 0 !important;
    margin: 0 !important;
}
```

### URL Bar

```css
/* Navigation toolbar */
#nav-bar {
    background: transparent !important;
    border: none !important;
    padding: 2px 4px !important;
}

/* URL bar field */
#urlbar-background {
    background: rgba(49, 50, 68, 0.7) !important;
    border: 1px solid rgba(69, 71, 90, 0.5) !important;
    border-radius: 10px !important;
}

#urlbar[focused="true"] > #urlbar-background {
    border-color: rgba(203, 166, 247, 0.5) !important;
}

#urlbar-input {
    color: var(--ctp-text) !important;
}

/* Suggestions dropdown */
#urlbar .urlbarView {
    background: var(--ctp-base) !important;
    border: 1px solid var(--ctp-surface1) !important;
    border-radius: 10px !important;
    margin-top: 4px !important;
}

.urlbarView-row {
    border-radius: 8px !important;
    margin: 1px 4px !important;
}

.urlbarView-row:hover,
.urlbarView-row[selected] {
    background: var(--ctp-surface0) !important;
}

/* Hide Firefox Suggest label */
.urlbarView-title[is-url],
#urlbar-label-box {
    display: none !important;
}
```

### Bookmarks Bar Auto-Hide

The bookmarks bar slides down when hovering the toolbar area and hides otherwise:

```css
#PersonalToolbar {
    max-height: 0px !important;
    opacity: 0 !important;
    overflow: hidden !important;
    transition: max-height 0.3s ease, opacity 0.3s ease !important;
    background: transparent !important;
    padding: 0 !important;
}

#navigator-toolbox:hover #PersonalToolbar {
    max-height: 40px !important;
    opacity: 1 !important;
    padding: 2px 4px !important;
}

#PersonalToolbar .bookmark-item {
    border-radius: 8px !important;
}

#PersonalToolbar .bookmark-item:hover {
    background: rgba(69, 71, 90, 0.7) !important;
}
```

### Compact Padding

Reduce overall toolbar height and button spacing:

```css
:root {
    --tab-min-height: 32px !important;
    --toolbarbutton-inner-padding: 6px !important;
    --toolbarbutton-outer-padding: 2px !important;
}
```

Also style navigation buttons for rounded hover states:

```css
#back-button,
#forward-button,
#reload-button,
#stop-button,
#home-button,
#downloads-button,
#library-button,
#fxa-toolbar-menu-button,
#unified-extensions-button {
    border-radius: 8px !important;
    margin: 1px !important;
}

#back-button:hover,
#forward-button:hover,
#reload-button:hover,
#stop-button:hover,
#home-button:hover,
#downloads-button:hover,
#library-button:hover,
#fxa-toolbar-menu-button:hover,
#unified-extensions-button:hover {
    background: rgba(69, 71, 90, 0.7) !important;
}
```

### Sidebar

```css
#sidebar-box {
    background: rgba(30, 30, 46, 0.92) !important;
    border-right: 1px solid var(--ctp-surface1) !important;
}

#sidebar-header {
    background: var(--ctp-mantle) !important;
    border-bottom: 1px solid var(--ctp-surface0) !important;
    color: var(--ctp-text) !important;
    padding: 6px 8px !important;
}

#sidebar {
    background: transparent !important;
    color: var(--ctp-text) !important;
}

#sidebar-splitter {
    border: none !important;
    width: 1px !important;
    background: var(--ctp-surface1) !important;
}
```

### Context Menus

```css
menupopup {
    background: var(--ctp-base) !important;
    border: 1px solid var(--ctp-surface1) !important;
    border-radius: 10px !important;
    padding: 4px !important;
}

menuitem,
menu {
    border-radius: 6px !important;
    color: var(--ctp-text) !important;
}

menuitem:hover,
menu:hover,
menuitem[_moz-menuactive="true"],
menu[_moz-menuactive="true"] {
    background: var(--ctp-surface0) !important;
    color: var(--ctp-text) !important;
}

menuseparator {
    border-color: var(--ctp-surface1) !important;
    margin: 2px 8px !important;
}
```

### Findbar

```css
findbar {
    background: var(--ctp-mantle) !important;
    border-top: 1px solid var(--ctp-surface1) !important;
    color: var(--ctp-text) !important;
}

findbar .findbar-textbox {
    background: var(--ctp-surface0) !important;
    color: var(--ctp-text) !important;
    border: 1px solid var(--ctp-surface1) !important;
    border-radius: 6px !important;
}
```

---

## userContent.css — Internal Pages

Use `@-moz-document` rules to target specific internal pages.

### New Tab Page

```css
@-moz-document url("about:newtab"), url("about:home") {
    body {
        background-color: #1e1e2e !important;
        color: #cdd6f4 !important;
    }

    /* Search bar */
    .search-wrapper input {
        background-color: #313244 !important;
        color: #cdd6f4 !important;
        border: 1px solid #45475a !important;
        border-radius: 10px !important;
        box-shadow: none !important;
    }

    .search-wrapper input:focus {
        border-color: rgba(203, 166, 247, 0.5) !important;
    }

    .search-wrapper .search-button {
        fill: #cba6f7 !important;
    }

    /* Top site shortcuts */
    .top-site-outer .tile {
        background-color: #313244 !important;
        border-radius: 10px !important;
        border: 1px solid #45475a !important;
    }

    .top-site-outer:hover .tile {
        background-color: #45475a !important;
    }

    .top-site-outer .title span {
        color: #bac2de !important;
    }

    /* Section titles */
    .section-title span {
        color: #a6adc8 !important;
    }

    /* Cards (Pocket, highlights) */
    .card-outer {
        background-color: #313244 !important;
        border-radius: 10px !important;
        border: 1px solid #45475a !important;
    }

    .card-outer:hover {
        background-color: #45475a !important;
    }

    .card-outer .card-title {
        color: #cdd6f4 !important;
    }

    .card-outer .card-host-name,
    .card-outer .card-context {
        color: #6c7086 !important;
    }
}
```

### Settings Page

```css
@-moz-document url-prefix("about:preferences") {
    :root {
        --in-content-page-background: #1e1e2e !important;
        --in-content-page-color: #cdd6f4 !important;
        --in-content-box-background: #313244 !important;
        --in-content-box-border-color: #45475a !important;
        --in-content-primary-button-background: #cba6f7 !important;
        --in-content-primary-button-background-hover: #b490e0 !important;
        --in-content-primary-button-text-color: #1e1e2e !important;
        --in-content-focus-outline-color: #cba6f7 !important;
        --in-content-accent-color: #cba6f7 !important;
    }
}
```

### Add-ons Manager

```css
@-moz-document url-prefix("about:addons") {
    :root {
        --in-content-page-background: #1e1e2e !important;
        --in-content-page-color: #cdd6f4 !important;
        --in-content-box-background: #313244 !important;
        --in-content-box-border-color: #45475a !important;
        --in-content-primary-button-background: #cba6f7 !important;
        --in-content-primary-button-text-color: #1e1e2e !important;
        --in-content-accent-color: #cba6f7 !important;
    }
}
```

### Private Browsing Page

```css
@-moz-document url("about:privatebrowsing") {
    body {
        background-color: #181825 !important;
        color: #cdd6f4 !important;
    }
}
```

---

## Common Pitfalls

- **CSS not loading**: `toolkit.legacyUserProfileCustomizations.stylesheets` must be `true`. Check `about:config` if `user.js` didn't apply. Make sure the files are in `<profile>/chrome/`, not `<profile>/`.
- **Wrong profile**: Firefox may have multiple profiles. The active one is under the `[Install*]` section in `profiles.ini`, not necessarily `[Profile0]`.
- **`!important` is required**: Firefox's built-in styles use `!important` extensively. Custom rules must also use it to override.
- **Changes not visible**: Firefox requires a full restart (quit + reopen). `Ctrl+Shift+R` does not reload chrome CSS.
- **Tab close button flicker**: Use `opacity` transitions rather than `display: none` for smooth show/hide.
- **Accent color mismatch**: Use the same accent color as the rest of the rice. If the Hyprland border uses mauve (`#cba6f7`), use mauve for active tab highlights, focus borders, and primary buttons.
- **`about:newtab` not styling**: This page runs in a special sandbox. Use `@-moz-document url("about:newtab"), url("about:home")` — both URLs must be listed. Colors must be hardcoded hex values (CSS custom properties from userChrome.css don't cross into content pages).
- **Scrollbar styling**: Use `scrollbar-width: thin; scrollbar-color: <thumb> <track>;` in a `*` selector for thin themed scrollbars.

---

## Adapting to Other Color Schemes

The examples above use Catppuccin Mocha. To adapt to another scheme:

1. Replace all color hex values with the target palette
2. Keep the same structural CSS (selectors, properties, layout)
3. Maintain the accent color pattern: use the user's primary accent (e.g., Nord frost blue, Dracula purple, Gruvbox orange) for active states, focus borders, and primary buttons
4. For transparency, adjust the `rgba()` alpha values — darker themes can use lower alpha (0.80-0.85), lighter themes may need higher (0.90-0.95) to maintain contrast
