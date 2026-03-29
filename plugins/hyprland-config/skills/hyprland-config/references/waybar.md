---
title: Waybar Configuration
weight: 8
---

# Waybar Configuration for Hyprland

## Table of Contents

1. [Config Structure](#config-structure)
2. [Bar-Level Properties](#bar-level-properties)
3. [Hyprland-Specific Modules](#hyprland-specific-modules)
4. [Essential Modules](#essential-modules)
5. [Custom Modules](#custom-modules)
6. [CSS Styling Guide](#css-styling-guide)
7. [Design Patterns](#design-patterns)
8. [Complete Examples](#complete-examples)
9. [Common Mistakes](#common-mistakes)

---

## Config Structure

Waybar uses two files:
- `~/.config/waybar/config.jsonc` — module layout and behavior
- `~/.config/waybar/style.css` — all visual styling

Always use `.jsonc` (JSON with comments) for the config — it allows inline documentation and is waybar's preferred format.

---

## Bar-Level Properties

```jsonc
{
    "layer": "top",           // "top" = above windows (almost always want this)
    "position": "top",        // "top", "bottom", "left", "right"
    "height": 36,             // px — omit for auto-sizing
    "spacing": 4,             // gap between modules in px
    "margin-top": 6,          // creates a floating bar effect
    "margin-left": 8,
    "margin-right": 8,
    "fixed-center": true,     // keeps center section truly centered
    "exclusive": true,        // reserves screen space (don't overlap windows)
    "reload_style_on_change": true,  // live-reload CSS on save

    "modules-left": [],
    "modules-center": [],
    "modules-right": []
}
```

Key decisions:
- **Floating bar**: Set `margin-top`, `margin-left`, `margin-right` to create space between bar and screen edges. This is one of the most impactful visual choices — it makes the bar feel like a standalone element rather than glued to the edge.
- **Height**: 30-40px is typical. Omitting it lets modules determine the height naturally — this works well with padding-based sizing in CSS.
- **Spacing**: Controls gaps between modules. Set to 0 if you want modules to touch (and use CSS margin/padding instead for finer control).

---

## Hyprland-Specific Modules

These are the modules that integrate directly with Hyprland. Using the wrong module names (e.g. `sway/workspaces`) is a common and hard-to-debug mistake — nothing renders, no error shown.

### hyprland/workspaces

The most important module. Shows workspace indicators.

```jsonc
"hyprland/workspaces": {
    "format": "{icon}",
    "format-icons": {
        "1": "",        // terminal
        "2": "",        // browser
        "3": "",        // code
        "4": "",        // chat
        "5": "",        // music
        "active": "",
        "default": ""
    },
    "persistent-workspaces": {
        "*": 5            // always show 5 workspaces on all monitors
    },
    "sort-by": "id",
    "on-click": "activate",
    "on-scroll-up": "hyprctl dispatch workspace e+1",
    "on-scroll-down": "hyprctl dispatch workspace e-1"
}
```

**Format options:**
- `{id}` — workspace number
- `{name}` — workspace name
- `{icon}` — icon from format-icons (matched by workspace id/name, then state)
- `{windows}` — window icons in the workspace (requires `window-rewrite`)

**Workspace window icons** (shows app icons per workspace):
```jsonc
"hyprland/workspaces": {
    "format": "{id} {windows}",
    "format-window-separator": " ",
    "window-rewrite-default": "",
    "window-rewrite": {
        "class<firefox>": "",
        "class<kitty>": "",
        "class<code>": "",
        "class<thunar>": "",
        "class<discord>": "",
        "class<spotify>": ""
    }
}
```

**CSS selectors:**
- `#workspaces button` — all workspace buttons
- `#workspaces button.active` — the focused workspace (**not** `.focused`)
- `#workspaces button.empty` — workspaces with no windows
- `#workspaces button.persistent` — always-shown workspaces
- `#workspaces button.urgent` — workspaces requesting attention
- `#workspaces button.special` — special (scratchpad) workspaces
- `#workspaces button.visible` — visible workspaces (multi-monitor)

### hyprland/window

Shows the title or class of the active window.

```jsonc
"hyprland/window": {
    "format": "{}",
    "max-length": 50,
    "separate-outputs": true,    // show window for this monitor only
    "icon": true,
    "icon-size": 18,
    "rewrite": {
        "(.*) — Mozilla Firefox": " $1",
        "(.*) - Visual Studio Code": " $1",
        "kitty": " Terminal"
    }
}
```

**CSS classes:** `#window`, `window#waybar.empty` (no window focused), `.floating`, `.fullscreen`

### hyprland/submap

Shows the active submap (like vim modes for keybinds).

```jsonc
"hyprland/submap": {
    "format": " {}",
    "max-length": 20,
    "tooltip": false
}
```

### hyprland/language

Shows the active keyboard layout.

```jsonc
"hyprland/language": {
    "format": " {short}"
}
```

---

## Essential Modules

### Clock

```jsonc
"clock": {
    "format": " {:%H:%M}",
    "format-alt": " {:%A, %B %d, %Y}",    // click to toggle
    "tooltip-format": "<tt><small>{calendar}</small></tt>",
    "calendar": {
        "mode": "year",
        "mode-mon-col": 3,
        "weeks-pos": "right",
        "format": {
            "months": "<span color='#cba6f7'><b>{}</b></span>",
            "days": "<span color='#cdd6f4'>{}</span>",
            "weeks": "<span color='#7f849c'>W{}</span>",
            "weekdays": "<span color='#f9e2af'><b>{}</b></span>",
            "today": "<span color='#a6e3a1'><b><u>{}</u></b></span>"
        }
    }
}
```

### Network

```jsonc
"network": {
    "format-wifi": "  {signalStrength}%",
    "format-ethernet": " {ipaddr}/{cidr}",
    "format-disconnected": " Disconnected",
    "tooltip-format": "{ifname}: {ipaddr}/{cidr}\n  {bandwidthUpBits}\n  {bandwidthDownBits}",
    "format-alt": " {essid}",
    "on-click-right": "nm-connection-editor"
}
```

### PulseAudio (or wireplumber)

```jsonc
"pulseaudio": {
    "format": "{icon} {volume}%",
    "format-bluetooth": " {volume}%",
    "format-muted": " Muted",
    "format-icons": {
        "headphone": "",
        "default": ["", "", ""]
    },
    "scroll-step": 5,
    "on-click": "pavucontrol",
    "on-click-right": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
}
```

Or the newer wireplumber module:
```jsonc
"wireplumber": {
    "format": "{icon} {volume}%",
    "format-muted": " Muted",
    "format-icons": ["", "", ""],
    "on-click": "pavucontrol"
}
```

### Battery (laptops)

```jsonc
"battery": {
    "interval": 10,
    "states": {
        "warning": 30,
        "critical": 15
    },
    "format": "{icon} {capacity}%",
    "format-charging": " {capacity}%",
    "format-plugged": " {capacity}%",
    "format-icons": ["", "", "", "", ""],
    "tooltip-format": "{timeTo}\n{power:.1f}W"
}
```

CSS uses `.warning` and `.critical` classes automatically from the `states` object.

### Backlight (laptops)

```jsonc
"backlight": {
    "format": "{icon} {percent}%",
    "format-icons": ["", "", "", "", "", "", "", "", ""],
    "tooltip": false
}
```

### CPU / Memory / Disk

```jsonc
"cpu": {
    "interval": 5,
    "format": " {usage}%",
    "on-click": "kitty --title htop -e htop"
},
"memory": {
    "interval": 5,
    "format": " {percentage}%",
    "tooltip-format": "{used:.1f}GiB / {total:.1f}GiB"
},
"disk": {
    "interval": 30,
    "format": " {percentage_used}%",
    "path": "/"
}
```

### Tray

```jsonc
"tray": {
    "icon-size": 16,
    "spacing": 8
}
```

### Idle Inhibitor

```jsonc
"idle_inhibitor": {
    "format": "{icon}",
    "format-icons": {
        "activated": "",
        "deactivated": ""
    },
    "tooltip-format-activated": "Idle inhibitor: ON",
    "tooltip-format-deactivated": "Idle inhibitor: OFF"
}
```

---

## Custom Modules

Custom modules run scripts and display their output. They're the primary way to add functionality waybar doesn't have built-in.

### Basic structure

```jsonc
"custom/module-name": {
    "exec": "path/to/script.sh",
    "interval": 60,           // seconds between runs (omit for continuous)
    "return-type": "json",     // or omit for plain text
    "format": "{icon} {}",
    "format-icons": { ... },
    "on-click": "command",
    "tooltip": true
}
```

For JSON return type, scripts output:
```json
{"text": "display text", "tooltip": "hover text", "class": "css-class", "percentage": 50}
```

### Power menu

```jsonc
"custom/power": {
    "format": "⏻",
    "tooltip": false,
    "on-click": "wlogout",
    "on-click-right": "hyprctl dispatch exit"
}
```

### Media player (MPRIS)

The built-in mpris module is often better than a custom script:
```jsonc
"mpris": {
    "format": "{player_icon} {dynamic}",
    "format-paused": "{status_icon} <i>{dynamic}</i>",
    "player-icons": {
        "default": "▶",
        "spotify": "",
        "firefox": ""
    },
    "status-icons": {
        "paused": "⏸"
    },
    "dynamic-order": ["title", "artist"],
    "dynamic-separator": " - ",
    "max-length": 40
}
```

### System updates

```jsonc
"custom/updates": {
    "format": " {}",
    "exec": "checkupdates 2>/dev/null | wc -l",
    "interval": 3600,
    "signal": 8,
    "on-click": "kitty -e bash -c 'sudo pacman -Syu; echo Done; read'"
}
```

Trigger manual refresh: `pkill -RTMIN+8 waybar`

### Weather

```jsonc
"custom/weather": {
    "format": "{}",
    "exec": "curl -s 'wttr.in/?format=%c+%t'",
    "interval": 1800,
    "tooltip": false
}
```

### Notification indicator (swaync)

```jsonc
"custom/notification": {
    "tooltip": false,
    "format": "{icon}",
    "format-icons": {
        "notification": " <span foreground='red'><sup></sup></span>",
        "none": "",
        "dnd-notification": " <span foreground='red'><sup></sup></span>",
        "dnd-none": "",
        "inhibited-notification": " <span foreground='red'><sup></sup></span>",
        "inhibited-none": "",
        "dnd-inhibited-notification": " <span foreground='red'><sup></sup></span>",
        "dnd-inhibited-none": ""
    },
    "return-type": "json",
    "exec": "swaync-client -swb",
    "on-click": "swaync-client -t -sw",
    "on-click-right": "swaync-client -d -sw",
    "escape": true
}
```

---

## CSS Styling Guide

Waybar uses GTK3 CSS — a subset of web CSS. Some web properties don't work, but the fundamentals (color, background, padding, margin, border, border-radius, font, box-shadow, opacity, transitions) all do.

### Color definitions

Use `@define-color` at the top of `style.css` to create a theme palette. This is the single most important thing for a cohesive look — every module should draw from these colors.

```css
/* Catppuccin Mocha palette */
@define-color base #1e1e2e;
@define-color mantle #181825;
@define-color crust #11111b;
@define-color surface0 #313244;
@define-color surface1 #45475a;
@define-color surface2 #585b70;
@define-color text #cdd6f4;
@define-color subtext0 #a6adc8;
@define-color subtext1 #bac2de;
@define-color lavender #b4befe;
@define-color blue #89b4fa;
@define-color sapphire #74c7ec;
@define-color sky #89dceb;
@define-color teal #94e2d5;
@define-color green #a6e3a1;
@define-color yellow #f9e2af;
@define-color peach #fab387;
@define-color maroon #eba0ac;
@define-color red #f38ba8;
@define-color mauve #cba6f7;
@define-color pink #f5c2e7;
@define-color flamingo #f2cdcd;
@define-color rosewater #f5e0dc;
```

Reference these throughout: `color: @text; background-color: @base;`

### Global reset and base styling

```css
* {
    border: none;
    border-radius: 0;
    font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free";
    font-size: 14px;
    min-height: 0;          /* prevents GTK minimum sizing */
}

window#waybar {
    background-color: transparent;   /* transparent for floating pill style */
    /* or: background-color: alpha(@base, 0.85); for solid semi-transparent */
    color: @text;
}

tooltip {
    background: @base;
    border: 2px solid @surface1;
    border-radius: 8px;
}

tooltip label {
    color: @text;
}
```

### Module selectors

Every built-in module has an `#id` selector:

```css
#clock { }
#battery { }
#network { }
#pulseaudio { }
#cpu { }
#memory { }
#tray { }
#workspaces { }
#workspaces button { }
#window { }
#custom-power { }          /* custom modules: #custom-<name> */
```

### State-based styling

Modules expose state classes for conditional styling:

```css
/* Battery states (from "states" config) */
#battery.warning { color: @yellow; }
#battery.critical { color: @red; animation: blink 1s steps(5) infinite; }
#battery.charging { color: @green; }

/* Network states */
#network.disconnected { color: @red; }
#network.wifi { color: @blue; }
#network.ethernet { color: @green; }

/* Audio states */
#pulseaudio.muted { color: @surface2; }

/* Idle inhibitor */
#idle_inhibitor.activated { color: @green; }

/* Workspace states */
#workspaces button.active { background: @mauve; color: @base; }
#workspaces button.urgent { background: @red; color: @base; }
#workspaces button.empty { color: @surface2; }
```

### Animations

```css
@keyframes blink {
    to { color: @red; }
}

/* Use steps() to reduce CPU usage */
#battery.critical {
    animation: blink 1s steps(12) infinite alternate;
}
```

---

## Design Patterns

These are the major visual styles seen in the community. Each creates a distinctly different look.

### Pattern 1: Floating Pill Bar (most popular)

The bar background is transparent; modules are grouped into rounded pill-shaped containers with gaps between them. This is the look most people associate with a polished Hyprland rice.

```css
window#waybar {
    background: transparent;
}

/* Each section becomes a pill */
.modules-left, .modules-center, .modules-right {
    background-color: alpha(@base, 0.85);
    border-radius: 12px;
    padding: 2px 8px;
    margin: 4px 0;
}
```

For **individual module pills** (each module is its own capsule):

```css
window#waybar {
    background: transparent;
}

.modules-left, .modules-center, .modules-right {
    background: transparent;
}

/* Every module becomes its own pill */
#clock, #battery, #network, #pulseaudio, #cpu, #memory,
#tray, #custom-power, #workspaces, #idle_inhibitor, #backlight {
    background-color: alpha(@base, 0.85);
    border-radius: 12px;
    padding: 4px 12px;
    margin: 4px 3px;
}

#workspaces {
    padding: 4px 6px;
}

#workspaces button {
    background: transparent;
    color: @subtext0;
    border-radius: 8px;
    padding: 2px 8px;
    margin: 0 2px;
    transition: all 0.2s ease;
}

#workspaces button.active {
    background: @mauve;
    color: @base;
}
```

### Pattern 2: Solid Bar with Module Accents

A traditional solid bar where each module gets a unique accent color. Classic and readable.

```css
window#waybar {
    background-color: @base;
    border-bottom: 2px solid @surface0;
}

#clock { color: @green; }
#battery { color: @yellow; }
#network { color: @blue; }
#pulseaudio { color: @mauve; }
#cpu { color: @peach; }
#memory { color: @red; }

/* Underline active module */
#clock, #battery, #network, #pulseaudio, #cpu, #memory {
    padding: 0 10px;
    border-bottom: 3px solid transparent;
}

#clock:hover, #battery:hover, #network:hover,
#pulseaudio:hover, #cpu:hover, #memory:hover {
    border-bottom-color: currentColor;
}
```

### Pattern 3: Color-Blocked Modules

Each module has its own background color — bold and distinctive.

```css
window#waybar {
    background: transparent;
}

#clock {
    background-color: @green;
    color: @base;
    border-radius: 0 12px 12px 0;    /* rounded right side */
    padding: 0 12px;
    margin: 4px 0 4px 0;
}

#battery {
    background-color: @yellow;
    color: @base;
    padding: 0 12px;
    margin: 4px 0;
}

#network {
    background-color: @blue;
    color: @base;
    border-radius: 12px 0 0 12px;    /* rounded left side */
    padding: 0 12px;
    margin: 4px 0;
}
```

### Pattern 4: Minimal / Clean

Subtle, barely-there bar that shows information without drawing attention.

```css
window#waybar {
    background-color: alpha(@base, 0.6);
}

* {
    font-size: 13px;
    color: @subtext1;
}

#workspaces button {
    color: @surface2;
    padding: 0 5px;
}

#workspaces button.active {
    color: @text;
}

/* Only show icons, no backgrounds or borders */
#clock, #battery, #network, #pulseaudio {
    padding: 0 8px;
}
```

### Pattern 5: macOS-Inspired

Center-focused with a dock-like feel.

```css
window#waybar {
    background: transparent;
}

.modules-center {
    background-color: alpha(@base, 0.75);
    border-radius: 16px;
    padding: 2px 16px;
    margin: 6px 0;
    box-shadow: 0 2px 4px alpha(#000000, 0.3);
}

.modules-left, .modules-right {
    background-color: alpha(@base, 0.75);
    border-radius: 16px;
    padding: 2px 12px;
    margin: 6px 8px;
    box-shadow: 0 2px 4px alpha(#000000, 0.3);
}
```

---

## Module Layout Recommendations

A well-arranged bar follows the principle: **navigation on the left, context in the center, status on the right.**

### Full-featured layout (desktop)
```jsonc
"modules-left": ["hyprland/workspaces", "hyprland/submap", "custom/power"],
"modules-center": ["hyprland/window"],
"modules-right": ["mpris", "idle_inhibitor", "pulseaudio", "network", "cpu", "memory", "clock", "tray"]
```

### Full-featured layout (laptop)
```jsonc
"modules-left": ["hyprland/workspaces", "hyprland/submap"],
"modules-center": ["hyprland/window"],
"modules-right": ["mpris", "idle_inhibitor", "pulseaudio", "backlight", "battery", "network", "clock", "tray"]
```

### Minimal layout
```jsonc
"modules-left": ["hyprland/workspaces"],
"modules-center": ["clock"],
"modules-right": ["pulseaudio", "network", "battery", "tray"]
```

---

## Complete Examples

### Example 1: Floating Pill Bar (Catppuccin Mocha)

**config.jsonc:**
```jsonc
{
    "layer": "top",
    "position": "top",
    "height": 36,
    "spacing": 0,
    "margin-top": 6,
    "margin-left": 8,
    "margin-right": 8,
    "reload_style_on_change": true,

    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["hyprland/window"],
    "modules-right": ["tray", "idle_inhibitor", "pulseaudio", "network", "clock", "custom/power"],

    "hyprland/workspaces": {
        "format": "{icon}",
        "format-icons": {
            "active": "",
            "default": "",
            "empty": ""
        },
        "persistent-workspaces": {
            "*": 5
        },
        "on-click": "activate",
        "on-scroll-up": "hyprctl dispatch workspace e+1",
        "on-scroll-down": "hyprctl dispatch workspace e-1"
    },

    "hyprland/window": {
        "format": "{}",
        "max-length": 50,
        "separate-outputs": true,
        "icon": true,
        "icon-size": 18
    },

    "clock": {
        "format": " {:%H:%M}",
        "format-alt": " {:%A, %B %d}",
        "tooltip-format": "<tt><small>{calendar}</small></tt>",
        "calendar": {
            "mode": "year",
            "mode-mon-col": 3,
            "format": {
                "today": "<span color='#a6e3a1'><b><u>{}</u></b></span>"
            }
        }
    },

    "network": {
        "format-wifi": " {signalStrength}%",
        "format-ethernet": "",
        "format-disconnected": " ",
        "tooltip-format": "{ifname}: {ipaddr}/{cidr}",
        "on-click-right": "nm-connection-editor"
    },

    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": " ",
        "format-icons": {
            "default": ["", "", ""]
        },
        "scroll-step": 5,
        "on-click": "pavucontrol"
    },

    "tray": {
        "icon-size": 16,
        "spacing": 8
    },

    "idle_inhibitor": {
        "format": "{icon}",
        "format-icons": {
            "activated": "",
            "deactivated": ""
        }
    },

    "custom/power": {
        "format": "⏻",
        "tooltip": false,
        "on-click": "wlogout"
    }
}
```

**style.css:**
```css
@define-color base #1e1e2e;
@define-color mantle #181825;
@define-color surface0 #313244;
@define-color surface1 #45475a;
@define-color surface2 #585b70;
@define-color text #cdd6f4;
@define-color subtext0 #a6adc8;
@define-color mauve #cba6f7;
@define-color red #f38ba8;
@define-color green #a6e3a1;
@define-color yellow #f9e2af;
@define-color blue #89b4fa;
@define-color peach #fab387;

* {
    border: none;
    border-radius: 0;
    font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free";
    font-size: 14px;
    min-height: 0;
}

window#waybar {
    background: transparent;
    color: @text;
}

tooltip {
    background: @base;
    border: 2px solid @surface1;
    border-radius: 8px;
}

tooltip label {
    color: @text;
}

.modules-left,
.modules-center,
.modules-right {
    background-color: alpha(@base, 0.85);
    border-radius: 12px;
    padding: 2px 8px;
    margin: 3px 0;
}

#workspaces {
    padding: 2px 4px;
}

#workspaces button {
    background: transparent;
    color: @surface2;
    border-radius: 8px;
    padding: 2px 8px;
    margin: 0 2px;
    transition: all 0.2s ease;
}

#workspaces button.active {
    background: @mauve;
    color: @base;
    border-radius: 8px;
}

#workspaces button.urgent {
    background: @red;
    color: @base;
}

#workspaces button:hover {
    background: @surface0;
    color: @text;
}

#window {
    color: @text;
    padding: 0 8px;
}

window#waybar.empty #window {
    background: transparent;
    padding: 0;
}

#clock,
#network,
#pulseaudio,
#battery,
#cpu,
#memory,
#tray,
#idle_inhibitor,
#custom-power {
    padding: 0 10px;
    color: @text;
}

#clock { color: @blue; }
#network { color: @green; }
#network.disconnected { color: @red; }
#pulseaudio { color: @mauve; }
#pulseaudio.muted { color: @surface2; }
#battery { color: @green; }
#battery.warning { color: @yellow; }
#battery.critical { color: @red; animation: blink 1s steps(12) infinite alternate; }
#battery.charging { color: @green; }
#cpu { color: @peach; }
#memory { color: @red; }
#idle_inhibitor.activated { color: @green; }
#custom-power { color: @red; padding-right: 4px; }

#tray > .passive { opacity: 0.6; }
#tray > .needs-attention { color: @red; }

@keyframes blink {
    to { color: @red; background-color: alpha(@red, 0.15); }
}
```

### Example 2: Individual Module Pills

Replace the section grouping with per-module pills for a more segmented look. Same config.jsonc as above, different CSS approach:

```css
/* ... same @define-color and reset as above ... */

window#waybar {
    background: transparent;
    color: @text;
}

.modules-left,
.modules-center,
.modules-right {
    background: transparent;
}

#workspaces,
#window,
#clock,
#network,
#pulseaudio,
#battery,
#cpu,
#memory,
#tray,
#idle_inhibitor,
#custom-power {
    background-color: alpha(@base, 0.85);
    border-radius: 12px;
    padding: 4px 14px;
    margin: 4px 3px;
    color: @text;
}

#workspaces {
    padding: 4px 6px;
}

#workspaces button {
    background: transparent;
    color: @surface2;
    border-radius: 8px;
    padding: 2px 8px;
    margin: 0 2px;
    transition: all 0.15s ease;
}

#workspaces button.active {
    background: @mauve;
    color: @base;
}

/* Per-module accent icons */
#clock { color: @blue; }
#network { color: @green; }
#pulseaudio { color: @mauve; }
#battery { color: @yellow; }
```

### Example 3: Color-Blocked Powerline

Bold, colorful modules that stand out:

```css
/* ... same reset ... */

window#waybar {
    background: transparent;
    color: @base;         /* dark text on colored backgrounds */
}

.modules-left,
.modules-center,
.modules-right {
    margin: 4px 4px;
}

#workspaces {
    background: @surface0;
    border-radius: 12px 0 0 12px;
    padding: 4px 8px;
    margin: 4px 0 4px 4px;
}

#workspaces button { color: @subtext0; padding: 2px 6px; }
#workspaces button.active { color: @mauve; }

#clock {
    background: @blue;
    color: @base;
    padding: 4px 14px;
    border-radius: 0 12px 12px 0;
    margin: 4px 4px 4px 0;
    font-weight: bold;
}

#pulseaudio {
    background: @mauve;
    color: @base;
    padding: 4px 14px;
    margin: 4px 0;
}

#network {
    background: @green;
    color: @base;
    padding: 4px 14px;
    margin: 4px 0;
}

#battery {
    background: @yellow;
    color: @base;
    padding: 4px 14px;
    margin: 4px 0;
}
```

---

## Common Mistakes

1. **`sway/workspaces` instead of `hyprland/workspaces`** — the module simply won't appear. No error. Always use `hyprland/` prefix.
2. **`button.focused` instead of `button.active`** — Sway uses `.focused`, Hyprland uses `.active`. Wrong selector = no active workspace highlighting.
3. **Missing Nerd Font** — icons show as boxes/tofu. The font family in CSS must match an installed Nerd Font. `fc-list | grep -i nerd` to check.
4. **Stripped Nerd Font glyphs** — icons render as empty spaces (not boxes). This happens when Nerd Font codepoints (U+E000–U+F8FF, U+F0000–U+10FFFF) are silently dropped during copy-paste, file transfer, or encoding conversion. The config appears correct but the format strings contain zero-width or invisible characters where icons should be. Diagnose by checking for non-ASCII characters: `python3 -c "import sys; [print(f'U+{ord(c):04X}', repr(c)) for c in open(sys.argv[1]).read() if ord(c) > 127]" config.jsonc`. If only standard Unicode symbols (em dash, power symbol) appear and no Nerd Font codepoints, the icons were stripped. Fix by re-inserting explicit Nerd Font glyphs. Also prefer `"JetBrainsMono Nerd Font Mono"` over `"JetBrainsMono Nerd Font"` in CSS — the non-Mono variant uses proportional widths for icon glyphs which can cause them to render at zero width in Pango.
5. **`config` instead of `config.jsonc`** — waybar accepts both, but `.jsonc` allows comments. If using plain `config`, it's parsed as JSON (no comments allowed).
6. **`layer: "bottom"`** — bar renders behind windows and is invisible. Almost always want `"top"`.
7. **No `exec-once = waybar` in autostart.conf** — bar doesn't launch. Or using `exec =` which spawns duplicates on config reload.
8. **Huge `font-size` in CSS without adjusting height** — text gets clipped. Either set a larger `height` in config or let it auto-size by omitting `height`.
9. **`background-color` on `window#waybar` with floating pill style** — must be `transparent` for the pill effect to work. The background goes on `.modules-left/center/right` or individual modules instead.
10. **Missing `alpha()` for transparency** — `background-color: @base;` is fully opaque. Use `alpha(@base, 0.85)` for the frosted glass look (pair with `layerrule = blur true, match:namespace waybar` in Hyprland config).
11. **Forgetting `reload_style_on_change: true`** — without this, CSS changes require manually restarting waybar (`killall waybar && waybar &`).
