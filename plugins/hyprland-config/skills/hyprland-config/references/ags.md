---
title: AGS (Aylur's GTK Shell) — Full Configuration Reference
weight: 10
---

AGS is a TypeScript/JSX framework for building complete desktop shells on Wayland — bars, notification centers, app launchers, OSD popups, sidebars, media players, lock screens, and more. It replaces waybar + notification daemon + launcher + OSD with a single unified codebase.

This reference covers AGS v3 (current), which uses the Gnim reactivity system and Astal libraries. Do not mix v1/v2 APIs (`Variable`, `bind()`, `Widget.Box`, `astalify`, `App.config`) — they are incompatible with v3.

## Table of Contents

- [When to Use AGS vs Waybar](#when-to-use-ags-vs-waybar)
- [Installation](#installation)
- [Project Structure](#project-structure)
- [Entry Point](#entry-point)
- [CLI Commands](#cli-commands)
- [Reactivity System](#reactivity-system)
- [JSX and Widgets](#jsx-and-widgets)
- [Window (Layer Shell)](#window-layer-shell)
- [Control Flow](#control-flow)
- [CSS Theming](#css-theming)
- [Astal Libraries](#astal-libraries)
- [Multi-Monitor Support](#multi-monitor-support)
- [Complete Component Examples](#complete-component-examples)
- [Common Patterns](#common-patterns)
- [HyprPanel](#hyprpanel)

---

## When to Use AGS vs Waybar

| Aspect | AGS | Waybar |
|--------|-----|--------|
| Language | TypeScript/JSX | JSON config + CSS |
| Complexity | Build from scratch with full programming language | Pre-built modules, configure don't code |
| Widget toolkit | Full GTK4 (or GTK3) | GTK3 with predefined modules |
| Flexibility | Unlimited — any GTK widget, custom logic, animations | Limited to existing modules + custom scripts |
| Beyond a bar | Notifications, launcher, sidebar, OSD, lock screen, greeter | Bar only |
| Learning curve | Steep — TypeScript, GTK, Astal knowledge needed | Low — JSON config with good docs |
| Performance | GJS runtime; heavier than waybar | Lightweight C++ |

**Recommend AGS when:** User wants a unified shell (bar + notifications + launcher + OSD in one framework), complex interactive widgets (media player with album art, volume mixer with per-app control), or says they're comfortable with TypeScript.

**Recommend waybar when:** User wants a quick reliable bar, doesn't want to write code, wants minimal resource usage, or just needs standard modules.

---

## Installation

**Arch Linux (AUR):**
```bash
yay -S aylurs-gtk-shell-git
```

This pulls in core astal libraries as dependencies, but NOT the service libraries. You must install each service library separately.

> **CRITICAL: Package names are `libastal-*-git`, NOT `astal-*-git`.** The `astal-*-git` names do not exist in AUR. Getting this wrong means AGS will crash with "Typelib file for namespace 'AstalXxx' not found".

```bash
# Core (required) — pulled in by aylurs-gtk-shell-git
yay -S libastal-io-git libastal-git libastal-4-git

# Service libraries (install what you need — NOT pulled in automatically)
yay -S libastal-battery-git libastal-bluetooth-git libastal-hyprland-git
yay -S libastal-mpris-git libastal-network-git libastal-notifd-git
yay -S libastal-tray-git libastal-wireplumber-git libastal-apps-git
yay -S libastal-powerprofiles-git libastal-auth-git libastal-cava-git
```

**Additional build dependencies:** `dart-sass` (required for SCSS compilation — AGS will fail with "executable sass not found" without it), `npm`, `meson`, `ninja`, `go`, `gobject-introspection`, `gtk3`, `gtk4`, `gtk-layer-shell`, `gtk4-layer-shell`

**Nix:**
```bash
nix shell github:aylur/ags
```

---

## Project Structure

Initialize with `ags init -d ~/.config/ags`. Typical layout:

```
~/.config/ags/
├── app.ts                  # Entry point
├── style.scss              # Global styles (SCSS supported)
├── tsconfig.json           # TypeScript config
├── widget/
│   ├── Bar.tsx             # Status bar
│   ├── Notifications.tsx   # Notification popups + center
│   ├── Launcher.tsx        # App launcher
│   ├── OSD.tsx             # Volume/brightness OSD
│   ├── QuickSettings.tsx   # WiFi, bluetooth, audio panel
│   ├── MediaPlayer.tsx     # MPRIS player widget
│   └── PowerMenu.tsx       # Shutdown/reboot/suspend
└── lib/
    └── utils.ts            # Shared helpers
```

When generating an AGS config, create all files the user needs. A minimal setup is `app.ts` + `style.scss` + one widget file. A full shell has 5-8 widget files.

---

## Entry Point

Every AGS project starts with `app.start()`:

> **CRITICAL: `app` is a default export**, not a named export. Use `import app from "ags/gtk4/app"`, NOT `import { App } from "ags/gtk4/app"`. This is the #1 import mistake.

```typescript
import app from "ags/gtk4/app"  // DEFAULT import — not { App }
import style from "./style.scss"
import Bar from "./widget/Bar"
import NotificationPopups from "./widget/Notifications"

app.start({
    css: style,
    main() {
        Bar()
        NotificationPopups()
    },
    // NOTE: requestHandler receives string[] (array), not a single string
    requestHandler(argv: string[], res: (response: string) => void) {
        if (argv[0] === "toggle") {
            const win = app.get_window(argv[1])
            if (win) { win.visible = !win.visible; res("ok") }
            else res(`window "${argv[1]}" not found`)
        } else {
            res("unknown command")
        }
    },
})
```

**Key options:**
- `css` — imported CSS/SCSS string (requires `dart-sass` installed for .scss)
- `main()` — instantiate all windows here
- `instanceName` — DBus name suffix (default: "astal")
- `icons` — path to custom icon directory
- `gtkTheme` — lock to specific GTK theme (e.g., `"Adwaita"`, `"adw-gtk3-dark"`)
- `requestHandler(argv: string[], res)` — handle `ags request <message>` from CLI/keybinds. **`argv` is a string array**, not a single string — do NOT call `.trim()` or `.split()` on it

---

## CLI Commands

```bash
ags run ./app.ts             # Run a project file
ags init -d ~/.config/ags    # Initialize project template
ags types -u -d ~/.config/ags  # Generate/update TypeScript types
ags inspect                  # Open GTK Inspector (live CSS debugging)
ags toggle <window-name>     # Toggle a named window's visibility
ags request <message>        # Send message to running instance
```

Files can use a shebang: `#!/usr/bin/env -S ags run`

**Integration with Hyprland keybinds:**
```ini
# Toggle launcher from Hyprland
bindd = $mainMod, D, Open launcher, exec, ags toggle launcher
# Toggle quick settings panel
bindd = $mainMod, A, Quick settings, exec, ags toggle quicksettings
```

---

## Reactivity System

AGS uses signal-based reactivity (like SolidJS). Values are tracked automatically — when a dependency changes, the UI updates. No virtual DOM, no manual re-renders.

### createState — Local reactive state

```typescript
import { createState } from "ags"

const [count, setCount] = createState(0)
count()                    // read (tracks dependency)
count.peek()               // read without tracking
setCount(5)                // set directly
setCount(prev => prev + 1) // set with updater function
```

### createBinding — Bind to GObject properties

This is the primary way to connect Astal library data to widgets. It takes a **GObject instance** and a **property name string** — nothing else.

> **CRITICAL: Do NOT wrap createComputed in createBinding.** `createBinding(createComputed(...))` is WRONG and causes "str is undefined" errors. `createBinding` is ONLY for GObject property bindings. `createComputed` already returns a reactive value usable directly in JSX.

```typescript
import { createBinding } from "ags"
import Battery from "gi://AstalBattery"

const battery = Battery.get_default()
const percentage = createBinding(battery, "percentage")

// Use in JSX — auto-updates when battery changes
// The transform function is chained with (), not a separate call
<label label={percentage(p => `${Math.floor(p * 100)}%`)} />

// WRONG — never do this:
// <label label={createBinding(createComputed(() => someValue()))} />
// RIGHT — use createComputed directly:
// <label label={createComputed(() => someValue())} />
```

### createComputed — Derived values

`createComputed` returns a reactive value that can be used directly in JSX props — no need to wrap it in `createBinding`.

```typescript
import { createComputed } from "ags"

const doubled = createComputed(() => count() * 2)

// Use directly in JSX — this is reactive:
<label label={createComputed(() => `Count: ${count()}`)} />
<box class={createComputed(() => active() ? "active" : "inactive")} />

// Shorthand: transform a binding directly
const label = percentage(p => `${Math.floor(p * 100)}%`)
```

### createEffect — Side effects

```typescript
import { createEffect } from "ags"

createEffect(() => {
    console.log("Battery:", percentage())  // reruns when percentage changes
})
```

### createPoll — Polling external commands

```typescript
import { createPoll } from "ags/time"

// Poll a shell command every N ms
const clock = createPoll("", 1000, "date +%H:%M")
const cpuTemp = createPoll("", 5000, "cat /sys/class/thermal/thermal_zone0/temp")

// Poll with a function
const counter = createPoll(0, 1000, prev => prev + 1)
```

### createSubprocess — Stream from process stdout

```typescript
import { createSubprocess } from "ags/time"

const log = createSubprocess("", "journalctl -f")
```

### onCleanup / onMount

```typescript
import { onCleanup, onMount } from "ags"

onCleanup(() => { /* runs when scope is destroyed */ })
onMount(() => { /* runs after root scope returns */ })
```

---

## JSX and Widgets

Lowercase JSX tags are intrinsic GTK widgets. Uppercase are custom components (plain functions).

### GTK4 Intrinsic Widgets

> **CRITICAL GTK4 differences from GTK3:**
> - `box` does NOT have a `vertical` boolean prop. Use `orientation={Gtk.Orientation.VERTICAL}` instead. Using `vertical` causes "No property vertical on GtkBox" error.
> - Use `class="my-class"` (string) for CSS classes, NOT `cssClasses={["my-class"]}` (array). AGS's JSX system only handles the `class` prop — `cssClasses` bypasses it and won't work for reactive updates.
> - Use `$` for ref callbacks, NOT `setup`. The `setup` prop does not exist.
> - `centerbox` children MUST have `$type="start"`, `$type="center"`, `$type="end"` props, or the centerbox layout will be broken (1px tall bar).

| Tag | GTK Class | Key Props |
|-----|-----------|-----------|
| `box` | Gtk.Box | `orientation={Gtk.Orientation.VERTICAL}`, `spacing`, `homogeneous` |
| `button` | Gtk.Button | `onClicked`, `child`, `label` |
| `centerbox` | Gtk.CenterBox | children **MUST** have `$type="start"/"center"/"end"` |
| `entry` | Gtk.Entry | `placeholderText`, `onNotifyText`, `text` |
| `image` | Gtk.Image | `iconName`, `file`, `pixelSize`, `gicon` |
| `label` | Gtk.Label | `label`, `useMarkup`, `wrap`, `ellipsize` |
| `levelbar` | Gtk.LevelBar | `value`, `orientation` |
| `menubutton` | Gtk.MenuButton | child + `<popover>` |
| `overlay` | Gtk.Overlay | children with `$type="overlay"` |
| `revealer` | Gtk.Revealer | `revealChild`, `transitionType`, `transitionDuration` |
| `scrolledwindow` | Gtk.ScrolledWindow | `maxContentHeight` |
| `slider` | Astal.Slider | `value`, `min`, `max`, `onChangeValue` |
| `stack` | Gtk.Stack | `visibleChildName`, children with `$type="named"` |
| `switch` | Gtk.Switch | `active`, `onNotifyActive` |
| `togglebutton` | Gtk.ToggleButton | `active`, `onToggled` |
| `window` | Astal.Window | see [Window section](#window-layer-shell) |
| `drawingarea` | Gtk.DrawingArea | `set_draw_func` for Cairo drawing |
| `popover` | Gtk.Popover | used inside `menubutton` |

**GTK3 additional widgets** (if using `ags/gtk3/app`):
- `circularprogress` — Astal.CircularProgress (`value`, `startAt`, `endAt`)
- `eventbox` — Astal.EventBox (`onClick`, `onHover`)
- `icon` — Astal.Icon (`icon` name or file path)

Any GTK widget works directly: `<Gtk.Calendar />`, `<Adw.Clamp />`, etc.

### Custom Components

Custom components are plain functions:

```typescript
function Clock() {
    const time = createPoll("", 1000, "date +%H:%M")
    return <label class="clock" label={time} />
}

// Use as JSX
<Clock />
```

### The $ prop (setup callback)

Access the underlying GTK widget instance:

```typescript
<box $={self => {
    // self is the Gtk.Box instance
    self.add_css_class("my-class")
}} />
```

---

## Window (Layer Shell)

Every AGS widget tree starts with a `<window>` — an Astal.Window with gtk-layer-shell integration.

```typescript
import { Astal } from "ags/gtk4"

function Bar({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
    return (
        <window
            visible
            name="bar"
            namespace="bar"
            gdkmonitor={gdkmonitor}
            anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.LEFT | Astal.WindowAnchor.RIGHT}
            exclusivity={Astal.Exclusivity.EXCLUSIVE}
            application={app}
        >
            <centerbox>
                <box $type="start">...</box>
                <box $type="center">...</box>
                <box $type="end">...</box>
            </centerbox>
        </window>
    )
}
```

**Window properties:**

| Prop | Type | Notes |
|------|------|-------|
| `visible` | boolean | GTK4 windows are invisible by default — always set this |
| `name` | string | Unique name for `ags toggle <name>` |
| `namespace` | string | Compositor layer namespace (for Hyprland layerrules) |
| `gdkmonitor` | Gdk.Monitor | Which monitor to display on |
| `anchor` | WindowAnchor flags | `TOP`, `BOTTOM`, `LEFT`, `RIGHT` — combine with `\|` |
| `exclusivity` | Exclusivity | `EXCLUSIVE` (reserve space), `NORMAL`, `IGNORE` |
| `layer` | Layer | `BACKGROUND`, `BOTTOM`, `TOP`, `OVERLAY` |
| `keymode` | Keymode | `NONE`, `EXCLUSIVE` (grab all keys), `ON_DEMAND` |
| `application` | App | Pass `app` to register for CLI toggle |
| `margin-top/bottom/left/right` | number | Pixel margins from anchored edge |

**Anchor combinations:**
- Bar (top): `TOP | LEFT | RIGHT` — stretches across top
- Bar (bottom): `BOTTOM | LEFT | RIGHT`
- Sidebar (right): `TOP | RIGHT | BOTTOM` — stretches vertically on right
- Centered popup: no anchors — floats in center
- Corner widget: `TOP | RIGHT` — sits in top-right corner

**Exclusivity:**
- `EXCLUSIVE` — other windows/layers won't overlap (use for bars)
- `NORMAL` — normal stacking
- `IGNORE` — render behind exclusive zones (use for wallpaper widgets)

---

## Control Flow

### `<For>` — Dynamic lists

Renders a list with efficient diffing (items are added/removed, not re-created):

```typescript
import { For } from "ags"

<For each={workspaces}>
    {(ws, index) => (
        <button
            class={createBinding(ws, "id")(id =>
                id === focusedId() ? "workspace active" : "workspace"
            )}
            onClicked={() => ws.focus()}
        >
            <label label={createBinding(ws, "id")(id => `${id}`)} />
        </button>
    )}
</For>
```

### `<With>` — Nullable unpacking

Renders children only when value is non-null:

```typescript
import { With } from "ags"

<With value={focusedClient}>
    {(client) => <label label={createBinding(client, "title")} />}
</With>
```

**Important:** Both `<For>` and `<With>` append new widgets rather than replacing. Wrap in a container (`<box>`) to maintain layout ordering.

---

## CSS Theming

AGS uses GTK's CSS engine — a subset of web CSS. Not all web properties work.

### Loading Styles

```typescript
import css from "./style.css"     // plain CSS
import scss from "./style.scss"   // SCSS (compiled automatically)

app.start({ css: scss })

// Runtime application
app.apply_css("/path/to/file.css")
app.apply_css(`window { background: transparent; }`)
app.reset_css()
```

### Inline CSS (does NOT cascade to children)

```typescript
<box css="padding: 1em; border: 1px solid red;" />
```

### CSS Classes

```typescript
<button class="workspace active" />
<button class={isActive ? "workspace active" : "workspace"} />
```

### Supported GTK CSS Properties

These reliably work in GTK CSS:
- `color`, `background-color`, `background` (including gradients)
- `padding`, `margin`, `border`, `border-radius`
- `min-width`, `min-height`
- `font-family`, `font-size`, `font-weight`, `font-style`
- `opacity`, `box-shadow` (limited), `text-shadow`
- `transition` (property, duration, timing function)
- `@keyframes` + `animation`
- `-gtk-icon-size`, `-gtk-icon-palette`

**NOT supported:** flexbox, grid, `position`, `display`, `float`, `z-index`, most modern web CSS.

### SCSS Pattern for Themed Bar

```scss
// Define palette variables matching the Hyprland color scheme
$rosewater: #f5e0dc;
$flamingo: #f2cdcd;
$pink: #f5c2e7;
$mauve: #cba6f7;
$red: #f38ba8;
$maroon: #eba0ac;
$peach: #fab387;
$yellow: #f9e2af;
$green: #a6e3a1;
$teal: #94e2d5;
$sky: #89dceb;
$sapphire: #74c7ec;
$blue: #89b4fa;
$lavender: #b4befe;
$text: #cdd6f4;
$subtext1: #bac2de;
$subtext0: #a6adc8;
$overlay2: #9399b2;
$overlay1: #7f849c;
$overlay0: #6c7086;
$surface2: #585b70;
$surface1: #45475a;
$surface0: #313244;
$base: #1e1e2e;
$mantle: #181825;
$crust: #11111b;

// Transparent bar background for floating effect
window {
    background: transparent;
}

window > box {
    background: alpha($base, 0.85);
    border-radius: 12px;
    margin: 8px;
    padding: 4px 12px;
}

// Workspace indicators
.workspace {
    min-width: 24px;
    min-height: 24px;
    border-radius: 50%;
    margin: 2px;
    background: $surface0;
    transition: all 200ms ease;

    &.active {
        background: $blue;
        min-width: 32px;
        border-radius: 12px;
    }

    &.occupied {
        background: $surface2;
    }
}

// Module styling
.module {
    padding: 4px 12px;
    margin: 2px;
    border-radius: 8px;
}

.clock {
    color: $text;
    font-weight: bold;
}

.battery {
    &.warning { color: $yellow; }
    &.critical { color: $red; }
    &.charging { color: $green; }
}

.volume-slider {
    slider {
        min-width: 8px;
        min-height: 8px;
        border-radius: 50%;
        background: $blue;
    }
    trough {
        min-height: 6px;
        border-radius: 3px;
        background: $surface0;
    }
    highlight {
        border-radius: 3px;
        background: $blue;
    }
}

// Notification popup
.notification {
    background: $base;
    border: 1px solid $surface1;
    border-radius: 12px;
    padding: 12px;
    margin: 4px 8px;

    .title { font-weight: bold; color: $text; }
    .body { color: $subtext1; }
    .app-name { color: $overlay1; font-size: 0.85em; }

    &.critical { border-color: $red; }
}

// Launcher
.launcher {
    background: alpha($base, 0.95);
    border-radius: 16px;
    padding: 16px;
    min-width: 500px;

    entry {
        background: $surface0;
        border-radius: 8px;
        padding: 8px 16px;
        color: $text;
        caret-color: $blue;
        margin-bottom: 8px;
    }

    .app-item {
        padding: 8px 12px;
        border-radius: 8px;
        transition: background 150ms ease;

        &:hover { background: $surface1; }
        &.selected { background: $surface2; }

        .app-name { color: $text; }
        .app-description { color: $overlay1; font-size: 0.85em; }
    }
}

// OSD popup
.osd {
    background: alpha($base, 0.9);
    border-radius: 24px;
    padding: 12px 24px;
    min-width: 200px;

    levelbar {
        min-height: 8px;
        border-radius: 4px;

        trough { background: $surface0; }
        block.filled { background: $blue; border-radius: 4px; }
    }
}
```

### Global CSS Reset (Required for GTK4)

GTK4's default Adwaita theme applies white backgrounds, borders, and shadows to buttons and other widgets. Without a global reset, your bar will have white button backgrounds. **Always include this reset at the top of your SCSS:**

```scss
* {
  font-family: "YourFont", monospace;
  font-size: 14px;
  color: $text;
  background: transparent;
  border: none;
  box-shadow: none;
  text-shadow: none;
  -gtk-icon-shadow: none;
  min-height: 0;
  min-width: 0;
}

button {
  background: transparent;
  border: none;
  box-shadow: none;
  padding: 0;
  &:hover { background: transparent; }
  &:active { background: transparent; }
  &:checked { background: transparent; }
}

menubutton {
  background: transparent;
  border: none;
  > button { background: transparent; border: none; padding: 2px; }
}
```

Then apply specific backgrounds to your containers (bar, notifications, etc.) below the reset. Without this, every button and menubutton in your bar will show the default GTK theme styling.

### Debugging CSS

Run `ags inspect` to open the GTK Inspector — lets you see the widget tree, test CSS live, and find class names.

---

## Astal Libraries

All libraries use GObject Introspection. Import with `gi://AstalXxx`. Most provide a singleton via `get_default()`.

> **CRITICAL: Astal service libraries use NO version string in imports.** Only core GTK/Astal bindings need versions.
>
> **Correct:**
> ```typescript
> import AstalBattery from "gi://AstalBattery"        // NO version
> import AstalTray from "gi://AstalTray"              // NO version
> import AstalWp from "gi://AstalWp"                  // NO version
> import AstalNetwork from "gi://AstalNetwork"        // NO version
> import AstalMpris from "gi://AstalMpris"            // NO version
> import AstalNotifd from "gi://AstalNotifd"          // NO version
> import AstalHyprland from "gi://AstalHyprland"      // NO version
> import AstalApps from "gi://AstalApps"              // NO version
> import AstalBluetooth from "gi://AstalBluetooth"    // NO version
> ```
>
> **Core bindings that DO need versions:**
> ```typescript
> import Astal from "gi://Astal?version=4.0"          // version required
> import Gtk from "gi://Gtk?version=4.0"              // version required
> import Gdk from "gi://Gdk?version=4.0"              // version required
> import GLib from "gi://GLib"                         // no version needed
> ```
>
> **WRONG:** `import AstalTray from "gi://AstalTray?version=0.1"` — causes "Typelib file not found" errors.
>
> **Also note:** `AstalTray.get_default()` not `AstalTray.Tray.get_default()`. Same for all other services — the module IS the class.

### Battery (AstalBattery)

```typescript
import Battery from "gi://AstalBattery"

const battery = Battery.get_default()

// Key properties (all bindable):
// percentage: number (0–1)
// charging: boolean
// icon_name: string (e.g. "battery-level-80-charging-symbolic")
// state: Battery.State (CHARGING, DISCHARGING, FULLY_CHARGED, etc.)
// time_to_empty: number (seconds, 0 if unknown)
// time_to_full: number (seconds, 0 if unknown)
// energy_rate: number (watts)
// is_present: boolean

function BatteryWidget() {
    const percentage = createBinding(battery, "percentage")
    const charging = createBinding(battery, "charging")
    const icon = createBinding(battery, "iconName")

    const cssClass = percentage(p => {
        if (p <= 0.15) return "battery critical"
        if (p <= 0.30) return "battery warning"
        return "battery"
    })

    return (
        <box class={cssClass}>
            <image iconName={icon} />
            <label label={percentage(p => `${Math.floor(p * 100)}%`)} />
        </box>
    )
}
```

### Hyprland (AstalHyprland)

Direct IPC with the Hyprland compositor — workspaces, clients, monitors, events.

```typescript
import Hyprland from "gi://AstalHyprland"

const hyprland = Hyprland.get_default()

// Key properties:
// workspaces: Workspace[]
// clients: Client[]
// monitors: Monitor[]
// focused_workspace: Workspace
// focused_monitor: Monitor
// focused_client: Client | null

// Key methods:
// dispatch(dispatcher, args) — exec hyprctl dispatch
// message(msg) — raw IPC message
// get_workspace(id), get_client(address), get_monitor(id)

// Signals:
// workspace-added, workspace-removed
// client-added, client-removed
// submap — fires when entering/leaving a submap
// urgent — fires when a window requests attention

function Workspaces() {
    const workspaces = createBinding(hyprland, "workspaces")
    const focused = createBinding(hyprland, "focusedWorkspace")

    return (
        <box class="workspaces">
            <For each={workspaces(ws => ws.sort((a, b) => a.id - b.id))}>
                {(ws) => {
                    const id = createBinding(ws, "id")
                    const cls = createComputed(() => {
                        const isFocused = focused()?.id === id()
                        const hasClients = createBinding(ws, "clients")().length > 0
                        return `workspace${isFocused ? " active" : ""}${hasClients ? " occupied" : ""}`
                    })
                    return (
                        <button class={cls} onClicked={() => ws.focus()}>
                            <label label={id(i => `${i}`)} />
                        </button>
                    )
                }}
            </For>
        </box>
    )
}

// Active window title
function WindowTitle() {
    const client = createBinding(hyprland, "focusedClient")
    return (
        <With value={client}>
            {(c) => <label class="window-title"
                label={createBinding(c, "title")}
                ellipsize={3} maxWidthChars={40} />}
        </With>
    )
}
```

**Workspace class:** `id`, `name`, `monitor`, `clients`, `has_fullscreen`, `last_client`. Methods: `focus()`, `move_to(monitor)`.

**Client class:** `address`, `title`, `class`, `pid`, `workspace`, `monitor`, `floating`, `fullscreen`, `x`, `y`, `width`, `height`. Methods: `kill()`, `focus()`, `move_to(workspace)`, `toggle_floating()`.

### WirePlumber (AstalWp) — Audio Control

Controls PipeWire audio via WirePlumber. Replaces pamixer/wpctl for widgets.

```typescript
import Wp from "gi://AstalWp"

const wp = Wp.get_default()!
// NOTE: WirePlumber loads asynchronously. Lists are empty until "ready" signal.
// Widget bindings handle this automatically.

const speaker = wp.audio.defaultSpeaker!
const mic = wp.audio.defaultMicrophone!

// Speaker/Mic properties:
// volume: number (0–1.5)
// mute: boolean
// volume_icon: string (icon name reflecting volume level + mute state)
// description: string (device name)

function VolumeSlider() {
    return (
        <box class="volume">
            <button onClicked={() => speaker.set_mute(!speaker.mute)}>
                <image iconName={createBinding(speaker, "volumeIcon")} />
            </button>
            <slider
                value={createBinding(speaker, "volume")}
                onChangeValue={({ value }) => speaker.set_volume(value)}
                min={0} max={1}
            />
            <label label={createBinding(speaker, "volume")(v =>
                `${Math.round(v * 100)}%`
            )} />
        </box>
    )
}

// Per-app volume (audio streams)
function AudioStreams() {
    const streams = createBinding(wp.audio, "streams")
    return (
        <For each={streams}>
            {(stream) => (
                <box class="stream">
                    <image iconName={createBinding(stream, "icon")} pixelSize={24} />
                    <label label={createBinding(stream, "description")} />
                    <slider
                        value={createBinding(stream, "volume")}
                        onChangeValue={({ value }) => stream.set_volume(value)}
                    />
                </box>
            )}
        </For>
    )
}
```

**Audio class properties:** `default_speaker`, `default_microphone`, `speakers`, `microphones`, `streams`, `recorders`. Each has `-added`/`-removed` signals.

### Network (AstalNetwork)

```typescript
import Network from "gi://AstalNetwork"

const network = Network.get_default()

// network.wifi properties:
// ssid: string, strength: number, icon_name: string
// enabled: boolean, scanning: boolean, access_points: AccessPoint[]
// Methods: scan(), set_enabled(bool)

// network.wired properties:
// speed: number, icon_name: string, internet: Internet enum

function WiFiIndicator() {
    const wifi = network.wifi
    return (
        <box class="network">
            <image iconName={createBinding(wifi, "iconName")} />
            <label label={createBinding(wifi, "ssid")(s => s || "Disconnected")} />
        </box>
    )
}

// WiFi access point list (for quick settings)
function WiFiList() {
    const wifi = network.wifi
    const aps = createBinding(wifi, "accessPoints")

    return (
        <scrolledwindow maxContentHeight={300}>
            <box vertical>
                <For each={aps(list => list
                    .filter(ap => ap.ssid)
                    .sort((a, b) => b.strength - a.strength)
                )}>
                    {(ap) => (
                        <button class="wifi-ap" onClicked={() => {/* connect logic */}}>
                            <image iconName={createBinding(ap, "iconName")} />
                            <label label={createBinding(ap, "ssid")} />
                            <label label={createBinding(ap, "strength")(s => `${s}%`)} />
                        </button>
                    )}
                </For>
            </box>
        </scrolledwindow>
    )
}
```

### Bluetooth (AstalBluetooth)

```typescript
import Bluetooth from "gi://AstalBluetooth"

const bluetooth = Bluetooth.get_default()

// Properties: is_powered, is_connected, devices, adapters
// Methods: toggle()
// Device props: name, connected, paired, icon, battery_percentage (-1 if N/A)
// Device methods: connect_device(), disconnect_device(), pair()

function BluetoothIndicator() {
    const powered = createBinding(bluetooth, "isPowered")
    const connected = createBinding(bluetooth, "isConnected")
    return (
        <button
            class={connected(c => c ? "bluetooth connected" : "bluetooth")}
            onClicked={() => bluetooth.toggle()}
        >
            <image iconName={powered(p =>
                p ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"
            )} />
        </button>
    )
}
```

### MPRIS (AstalMpris) — Media Players

```typescript
import Mpris from "gi://AstalMpris"

const mpris = Mpris.get_default()

// mpris.players: Player[]
// Player.new("spotify") — target specific player
// Player props: title, artist, album, cover_art (cached path), art_url,
//   playback_status, position, length, volume, shuffle_status, loop_status,
//   can_play, can_pause, can_go_next, can_go_previous, can_seek, identity
// Player methods: play(), pause(), play_pause(), next(), previous(),
//   stop(), loop(), shuffle(), raise(), quit()

function MediaPlayer() {
    const players = createBinding(mpris, "players")

    return (
        <For each={players}>
            {(player) => {
                const title = createBinding(player, "title")
                const artist = createBinding(player, "artist")
                const cover = createBinding(player, "coverArt")
                const status = createBinding(player, "playbackStatus")

                return (
                    <box class="media-player">
                        <With value={cover}>
                            {(path) => <image file={path} class="cover-art" />}
                        </With>
                        <box vertical>
                            <label class="title" label={title} ellipsize={3} />
                            <label class="artist" label={artist} ellipsize={3} />
                            <box class="controls">
                                <button onClicked={() => player.previous()}>
                                    <image iconName="media-skip-backward-symbolic" />
                                </button>
                                <button onClicked={() => player.play_pause()}>
                                    <image iconName={status(s =>
                                        s === Mpris.PlaybackStatus.PLAYING
                                            ? "media-playback-pause-symbolic"
                                            : "media-playback-start-symbolic"
                                    )} />
                                </button>
                                <button onClicked={() => player.next()}>
                                    <image iconName="media-skip-forward-symbolic" />
                                </button>
                            </box>
                        </box>
                    </box>
                )
            }}
        </For>
    )
}
```

### System Tray (AstalTray)

```typescript
import Tray from "gi://AstalTray"

const tray = Tray.get_default()

// tray.items: TrayItem[]
// TrayItem props: title, gicon, tooltip_markup, is_menu, menu_model, action_group
// TrayItem methods: activate(), secondary_activate(), scroll(dx, dy)

function SysTray() {
    const items = createBinding(tray, "items")
    return (
        <box class="tray">
            <For each={items}>
                {(item) => (
                    <menubutton
                        class="tray-item"
                        tooltipMarkup={createBinding(item, "tooltipMarkup")}
                        $={self => {
                            self.menuModel = item.menuModel
                            self.insert_action_group("dbusmenu", item.actionGroup)
                        }}
                    >
                        <image gicon={createBinding(item, "gicon")} pixelSize={16} />
                    </menubutton>
                )}
            </For>
        </box>
    )
}
```

### Notifications (AstalNotifd)

AGS can replace dunst/mako/swaync entirely by acting as the notification daemon.

```typescript
import Notifd from "gi://AstalNotifd"

const notifd = Notifd.get_default()

// NOTE: First instantiation becomes the daemon. Only one notification
// daemon can run — don't also start dunst/mako/swaync.

// notifd props: notifications, dont_disturb, ignore_timeout
// Signals: notified(id, replaced), resolved(id, reason)
// Notification props: id, app_name, app_icon, summary, body, urgency,
//   expire_timeout, time, image, actions, hints

function NotificationPopups() {
    const [popups, setPopups] = createState<number[]>([])

    // Listen for new notifications
    notifd.connect("notified", (_, id) => {
        setPopups(prev => [id, ...prev])

        // Auto-dismiss after timeout
        const notif = notifd.get_notification(id)
        if (notif && notif.expire_timeout > 0) {
            setTimeout(() => {
                setPopups(prev => prev.filter(i => i !== id))
            }, notif.expire_timeout)
        }
    })

    return (
        <window
            visible
            name="notifications"
            namespace="notifications"
            anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
            layer={Astal.Layer.OVERLAY}
        >
            <box vertical class="notification-popups">
                <For each={popups}>
                    {(id) => {
                        const notif = notifd.get_notification(id)
                        if (!notif) return <box />
                        return (
                            <box class={`notification ${notif.urgency === 2 ? "critical" : ""}`}>
                                <box vertical>
                                    <box>
                                        <label class="app-name"
                                            label={notif.app_name || "Notification"} />
                                        <button
                                            class="close"
                                            onClicked={() => notif.dismiss()}
                                        >
                                            <image iconName="window-close-symbolic" />
                                        </button>
                                    </box>
                                    <label class="title" label={notif.summary}
                                        wrap useMarkup />
                                    <label class="body" label={notif.body}
                                        wrap useMarkup />
                                    {notif.actions.length > 0 && (
                                        <box class="actions">
                                            {notif.actions.map(action => (
                                                <button
                                                    onClicked={() => notif.invoke(action.id)}
                                                >
                                                    <label label={action.label} />
                                                </button>
                                            ))}
                                        </box>
                                    )}
                                </box>
                            </box>
                        )
                    }}
                </For>
            </box>
        </window>
    )
}
```

### Apps (AstalApps) — Application Launcher

```typescript
import Apps from "gi://AstalApps"

const apps = new Apps.Apps({
    nameMultiplier: 2,
    entryMultiplier: 0,
    executableMultiplier: 0.5,
})

// apps.fuzzy_query(text): Application[] — returns sorted by relevance
// Application props: name, description, icon_name, executable, keywords, categories
// Application methods: launch()

function AppLauncher() {
    const [query, setQuery] = createState("")
    const results = createComputed(() =>
        query() ? apps.fuzzy_query(query()) : apps.list.slice(0, 20)
    )
    const [selected, setSelected] = createState(0)

    return (
        <window
            visible={false}
            name="launcher"
            namespace="launcher"
            keymode={Astal.Keymode.ON_DEMAND}
            anchor={Astal.WindowAnchor.TOP}
            application={app}
        >
            <box vertical class="launcher">
                <entry
                    placeholderText="Search applications..."
                    onNotifyText={({ text }) => {
                        setQuery(text)
                        setSelected(0)
                    }}
                    onActivate={() => {
                        const r = results()
                        if (r[selected()]) {
                            r[selected()].launch()
                            app.toggle_window("launcher")
                        }
                    }}
                />
                <scrolledwindow maxContentHeight={400}>
                    <box vertical>
                        <For each={results}>
                            {(appItem, index) => (
                                <button
                                    class={index(i => i === selected() ? "app-item selected" : "app-item")}
                                    onClicked={() => {
                                        appItem.launch()
                                        app.toggle_window("launcher")
                                    }}
                                >
                                    <image iconName={appItem.icon_name || "application-x-executable"}
                                        pixelSize={32} />
                                    <box vertical>
                                        <label class="app-name" label={appItem.name}
                                            halign={Gtk.Align.START} />
                                        {appItem.description && (
                                            <label class="app-description"
                                                label={appItem.description}
                                                halign={Gtk.Align.START}
                                                ellipsize={3} />
                                        )}
                                    </box>
                                </button>
                            )}
                        </For>
                    </box>
                </scrolledwindow>
            </box>
        </window>
    )
}
```

### Power Profiles (AstalPowerProfiles)

```typescript
import PowerProfiles from "gi://AstalPowerProfiles"

const profiles = PowerProfiles.get_default()

// Properties: active_profile ("performance" | "balanced" | "power-saver")
// Methods: set_active_profile(profile)

function PowerProfileToggle() {
    const active = createBinding(profiles, "activeProfile")
    const icons: Record<string, string> = {
        "performance": "power-profile-performance-symbolic",
        "balanced": "power-profile-balanced-symbolic",
        "power-saver": "power-profile-power-saver-symbolic",
    }
    const next: Record<string, string> = {
        "performance": "balanced",
        "balanced": "power-saver",
        "power-saver": "performance",
    }
    return (
        <button
            class={active(p => `power-profile ${p}`)}
            onClicked={() => profiles.set_active_profile(next[profiles.active_profile])}
            tooltipText={active}
        >
            <image iconName={active(p => icons[p])} />
        </button>
    )
}
```

### Auth (AstalAuth) — PAM Authentication

Used for lock screens and greeters:

```typescript
import Auth from "gi://AstalAuth"

// Auth.Pam.authenticate(password, callback)
// callback receives (result, error)

function authenticate(password: string): Promise<boolean> {
    return new Promise((resolve) => {
        Auth.Pam.authenticate(password, (_, result) => {
            try {
                Auth.Pam.authenticate_finish(result)
                resolve(true)
            } catch {
                resolve(false)
            }
        })
    })
}
```

### Cava (AstalCava) — Audio Visualization

```typescript
import Cava from "gi://AstalCava"

const cava = Cava.get_default()

// Properties: values (number[])
// Listen for changes: connect("notify::values", () => {...})
```

---

## Multi-Monitor Support

Create a bar instance for each monitor:

```typescript
import app from "ags/gtk4/app"

app.start({
    css: style,
    main() {
        const monitors = createBinding(app, "monitors")
        return (
            <For each={monitors}>
                {(monitor) => <Bar gdkmonitor={monitor} />}
            </For>
        )
    },
})
```

With cleanup for disconnected monitors:

```typescript
function Bar({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
    let win: Astal.Window
    onCleanup(() => win?.destroy())

    return (
        <window
            $={self => win = self}
            gdkmonitor={gdkmonitor}
            visible
            name={`bar-${gdkmonitor.get_model()}`}
            ...
        />
    )
}
```

Popups/launchers/notifications typically only need one instance (no per-monitor).

---

## Complete Component Examples

### OSD (On-Screen Display)

Volume/brightness popups that appear briefly on change:

```typescript
import Wp from "gi://AstalWp"

function OSD() {
    const wp = Wp.get_default()!
    const speaker = wp.audio.defaultSpeaker!
    const [visible, setVisible] = createState(false)
    let timeout: number | null = null

    // Show OSD when volume changes
    createEffect(() => {
        const vol = createBinding(speaker, "volume")()
        setVisible(true)
        if (timeout) clearTimeout(timeout)
        timeout = setTimeout(() => setVisible(false), 2000)
    })

    return (
        <window
            visible={visible}
            name="osd"
            namespace="osd"
            anchor={Astal.WindowAnchor.BOTTOM}
            layer={Astal.Layer.OVERLAY}
            exclusivity={Astal.Exclusivity.IGNORE}
            margin-bottom={80}
        >
            <box class="osd">
                <image iconName={createBinding(speaker, "volumeIcon")} pixelSize={24} />
                <levelbar value={createBinding(speaker, "volume")} />
                <label label={createBinding(speaker, "volume")(v =>
                    `${Math.round(v * 100)}%`)} />
            </box>
        </window>
    )
}
```

### Quick Settings Panel

```typescript
function QuickSettings() {
    const network = Network.get_default()
    const bluetooth = Bluetooth.get_default()
    const wp = Wp.get_default()!
    const profiles = PowerProfiles.get_default()

    return (
        <window
            visible={false}
            name="quicksettings"
            namespace="quicksettings"
            anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
            layer={Astal.Layer.OVERLAY}
            keymode={Astal.Keymode.ON_DEMAND}
            application={app}
            margin-top={8} margin-right={8}
        >
            <box vertical class="quick-settings" spacing={8}>
                {/* Toggle buttons row */}
                <box spacing={8}>
                    <togglebutton
                        class="qs-toggle"
                        active={createBinding(network.wifi, "enabled")}
                        onToggled={({ active }) => network.wifi.set_enabled(active)}
                    >
                        <box vertical>
                            <image iconName={createBinding(network.wifi, "iconName")} />
                            <label label="WiFi" />
                        </box>
                    </togglebutton>
                    <togglebutton
                        class="qs-toggle"
                        active={createBinding(bluetooth, "isPowered")}
                        onToggled={() => bluetooth.toggle()}
                    >
                        <box vertical>
                            <image iconName="bluetooth-active-symbolic" />
                            <label label="Bluetooth" />
                        </box>
                    </togglebutton>
                    <togglebutton
                        class="qs-toggle"
                        active={createBinding(notifd, "dontDisturb")}
                        onToggled={({ active }) => { notifd.dont_disturb = active }}
                    >
                        <box vertical>
                            <image iconName="notifications-disabled-symbolic" />
                            <label label="DnD" />
                        </box>
                    </togglebutton>
                </box>

                {/* Volume slider */}
                <VolumeSlider />

                {/* Brightness slider (using brightnessctl) */}
                <BrightnessSlider />

                {/* Power profile selector */}
                <PowerProfileToggle />

                {/* Power buttons */}
                <box class="power-buttons" spacing={8}>
                    <button onClicked={() => execAsync("loginctl lock-session")}>
                        <image iconName="system-lock-screen-symbolic" />
                    </button>
                    <button onClicked={() => execAsync("systemctl suspend")}>
                        <image iconName="system-suspend-symbolic" />
                    </button>
                    <button onClicked={() => execAsync("systemctl poweroff")}>
                        <image iconName="system-shutdown-symbolic" />
                    </button>
                </box>
            </box>
        </window>
    )
}
```

### Power Menu

```typescript
function PowerMenu() {
    const buttons = [
        { icon: "system-lock-screen-symbolic", label: "Lock", cmd: "loginctl lock-session" },
        { icon: "system-log-out-symbolic", label: "Logout", cmd: "hyprctl dispatch exit" },
        { icon: "system-suspend-symbolic", label: "Suspend", cmd: "systemctl suspend" },
        { icon: "system-reboot-symbolic", label: "Reboot", cmd: "systemctl reboot" },
        { icon: "system-shutdown-symbolic", label: "Shutdown", cmd: "systemctl poweroff" },
    ]

    return (
        <window
            visible={false}
            name="powermenu"
            namespace="powermenu"
            keymode={Astal.Keymode.EXCLUSIVE}
            layer={Astal.Layer.OVERLAY}
            application={app}
        >
            <box class="powermenu" spacing={24}>
                {buttons.map(btn => (
                    <button class="power-button" onClicked={() => {
                        execAsync(btn.cmd)
                        app.toggle_window("powermenu")
                    }}>
                        <box vertical spacing={8}>
                            <image iconName={btn.icon} pixelSize={48} />
                            <label label={btn.label} />
                        </box>
                    </button>
                ))}
            </box>
        </window>
    )
}
```

---

## Common Patterns

### Environment Variables

GLib.getenv for reading env vars (no shell expansion in exec):

```typescript
import GLib from "gi://GLib"
const home = GLib.getenv("HOME")
```

For shell features in commands, wrap with bash:

```typescript
execAsync(["bash", "-c", "echo $HOME"])
```

### File Monitoring

```typescript
import { monitorFile } from "ags/file"

monitorFile("/path/to/file", (file, event) => {
    // event: Gio.FileMonitorEvent
    console.log("File changed:", file)
})
```

### HTTP Fetch

```typescript
import { fetch } from "ags/fetch"

const response = await fetch("https://api.example.com/data")
const json = await response.json()
```

### GObject Decorators (Custom Services)

Create singleton services for shared state:

```typescript
import GObject, { register, property, signal } from "ags/gobject"

@register({ GTypeName: "BrightnessService" })
class BrightnessService extends GObject.Object {
    @property(Number) screen = 0

    constructor() {
        super()
        // Initialize from brightnessctl
        const out = exec("brightnessctl get")
        const max = exec("brightnessctl max")
        this.screen = Number(out) / Number(max)

        // Monitor changes
        monitorFile("/sys/class/backlight", () => {
            const out = exec("brightnessctl get")
            const max = exec("brightnessctl max")
            this.screen = Number(out) / Number(max)
        })
    }

    set_screen(value: number) {
        execAsync(`brightnessctl set ${Math.round(value * 100)}% -q`)
    }
}

const brightness = new BrightnessService()
```

Requires `tsconfig.json`: `"experimentalDecorators": false`, `"target": "ES2020"`.

### Hyprland Integration

Keybinds to toggle AGS windows:
```ini
bindd = $mainMod, D, Open launcher, exec, ags toggle launcher
bindd = $mainMod, A, Quick settings, exec, ags toggle quicksettings
bindd = $mainMod, Escape, Power menu, exec, ags toggle powermenu
```

Layer rules for AGS namespaces:
```ini
layerrule = blur true, match:namespace bar
layerrule = blur true, match:namespace launcher
layerrule = blur true, match:namespace quicksettings
layerrule = blur true, match:namespace notifications
layerrule = blur true, match:namespace osd
```

Autostart:
```ini
exec-once = ags run ~/.config/ags/app.ts
```

---

## HyprPanel

HyprPanel is a pre-built shell for Hyprland built on AGS/Astal. It provides bar + notification center + OSD + app launcher + quick settings with minimal configuration.

**Install:**
```bash
# AUR
yay -S hyprpanel
```

**Config:** `~/.config/hyprpanel/config.json` — a single JSON file drives the entire theme. Change one color palette and everything updates.

**When to recommend HyprPanel over raw AGS:** User wants something more polished than waybar, with notifications + OSD + launcher included, but doesn't want to write TypeScript. HyprPanel is the "out-of-box" path; raw AGS is the "build from scratch" path.

**When to recommend raw AGS over HyprPanel:** User wants full control, unique widget designs, custom logic, or components HyprPanel doesn't offer.

Autostart:
```ini
exec-once = hyprpanel
```

---

## AGS Common Mistakes (Verified from Real Debugging)

These are real bugs encountered when generating AGS configs. Each one caused actual runtime failures. Read this section before generating any AGS code.

### Import Mistakes

1. **Named import of app**: `import { App } from "ags/gtk4/app"` is WRONG. The app is a **default export**: `import app from "ags/gtk4/app"`. Then use `app.start()`, `app.toggle_window()`, `app.get_window()`, and pass `application={app}` in JSX.

2. **Version strings on Astal services**: `import AstalTray from "gi://AstalTray?version=0.1"` is WRONG. Astal service libraries use NO version string: `import AstalTray from "gi://AstalTray"`. Only `Astal`, `Gtk`, and `Gdk` need `?version=4.0`.

3. **createPoll import location**: `createPoll` is in `"ags/time"`, NOT in `"ags"`. Similarly, `exec`/`execAsync` are in `"ags/process"`.

4. **Tray singleton**: `AstalTray.get_default()`, NOT `AstalTray.Tray.get_default()`. The module IS the class for all Astal services.

### JSX Mistakes

5. **`vertical` prop on box**: GTK4 `box` has NO `vertical` boolean prop. Use `orientation={Gtk.Orientation.VERTICAL}`. Using `vertical` causes "No property vertical on GtkBox" error.

6. **`cssClasses` instead of `class`**: AGS JSX uses `class="my-class"` (a string), NOT `cssClasses={["my-class"]}` (an array). The `class` prop is intercepted by AGS's JSX runtime and handles reactive updates. `cssClasses` bypasses this and silently fails for reactive values. For reactive classes: `class={createComputed(() => active() ? "btn active" : "btn")}`.

7. **`setup` instead of `$`**: The ref callback prop is `$`, NOT `setup`. Use `$={(self) => { ... }}`.

8. **Missing `$type` on centerbox children**: `<centerbox>` children MUST have `$type="start"`, `$type="center"`, `$type="end"`. Without these, the centerbox layout is broken — the bar renders as 1px tall because `vfunc_add_child` doesn't know which slot to assign children to.

9. **`createBinding(createComputed(...))` anti-pattern**: NEVER wrap a `createComputed` in `createBinding`. `createBinding` takes a GObject + property name ONLY. `createComputed` already returns a reactive value. Use `createComputed` directly in JSX props.

10. **Binding as children renders "Accessor { }"**: Using `{binding((list) => list.map(...))}` as JSX children can render the Accessor object as text. Use `<For each={binding}>` for dynamic lists instead.

### CSS Mistakes

11. **Missing global CSS reset**: GTK4's Adwaita theme applies white backgrounds and borders to buttons by default. Without a global `* { background: transparent; border: none; }` reset, your bar will have white button backgrounds even with custom CSS.

12. **`sass` not installed**: AGS requires `dart-sass` to compile `.scss` files. Without it, AGS crashes with "executable sass not found in $PATH". Install with `pacman -S dart-sass`.

### Configuration Mistakes

13. **`requestHandler` signature**: The parameter is `argv: string[]` (array), NOT `request: string`. Calling `.trim()` on it causes "request.trim is not a function".

14. **Notification daemon conflict**: Only one notification daemon can run. If AGS handles notifications via AstalNotifd, kill and mask dunst/mako/swaync first: `pkill dunst; systemctl --user mask dunst.service`. Otherwise AGS gets "dunst is already running" and the notification component fails.

15. **`ags init` on existing directory**: If `~/.config/ags/` already has files, `ags init -d ~/.config/ags` fails. Just run `ags types -u -d ~/.config/ags` to generate type definitions without scaffolding.

16. **Wrong Arch package names in install.sh**: The Astal library packages are named `libastal-*-git` in AUR, NOT `astal-*-git`. Wrong names silently fail with "package not found" and then AGS crashes at runtime with missing typelib errors.
