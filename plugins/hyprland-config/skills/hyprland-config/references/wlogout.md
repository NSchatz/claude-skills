---
title: wlogout Logout Menu Configuration Reference
weight: 7
---

# wlogout Reference

Configuration and theming guide for wlogout — a Wayland logout menu for Hyprland. Load this when generating a power/logout menu or when the user asks about session management UI.

## Overview

wlogout displays a fullscreen overlay with buttons for lock, logout, suspend, hibernate, reboot, and shutdown. It's the most popular graphical session menu for Hyprland rices.

**Config location**: `~/.config/wlogout/layout` (JSON) + `~/.config/wlogout/style.css` (GTK CSS)
**Package**: `wlogout` (AUR)

---

## layout file

The layout file is a JSON array of button objects. Each button has:

| Field | Type | Description |
|-------|------|-------------|
| `label` | string | CSS class name for styling (also used as ID) |
| `action` | string | Shell command to execute |
| `text` | string | Display text on the button |
| `keybind` | string | Keyboard shortcut (single key) |
| `circular` | bool | Round button shape (optional) |
| `height` | float | Relative height 0.0-1.0 (optional) |
| `width` | float | Relative width 0.0-1.0 (optional) |

### Complete layout example

```json
[
    {
        "label": "lock",
        "action": "loginctl lock-session",
        "text": "Lock",
        "keybind": "l"
    },
    {
        "label": "logout",
        "action": "hyprctl dispatch exit",
        "text": "Logout",
        "keybind": "e"
    },
    {
        "label": "suspend",
        "action": "systemctl suspend",
        "text": "Suspend",
        "keybind": "s"
    },
    {
        "label": "hibernate",
        "action": "systemctl hibernate",
        "text": "Hibernate",
        "keybind": "h"
    },
    {
        "label": "reboot",
        "action": "systemctl reboot",
        "text": "Reboot",
        "keybind": "r"
    },
    {
        "label": "shutdown",
        "action": "systemctl poweroff",
        "text": "Shutdown",
        "keybind": "p"
    }
]
```

**Notes on actions:**
- Use `loginctl lock-session` instead of `hyprlock` directly — lets hypridle hooks fire properly
- Use `hyprctl dispatch exit` for Hyprland logout (not `loginctl terminate-user`)
- Hibernate requires swap partition/file and may need `resume=` kernel parameter
- If using uwsm: `uwsm stop` for logout instead of `hyprctl dispatch exit`

---

## style.css — Complete themed example (Catppuccin Mocha)

```css
/* Full-screen background overlay */
window {
    background-color: rgba(30, 30, 46, 0.85);
    font-family: "JetBrainsMono Nerd Font";
}

/* All buttons share this base style */
button {
    background-color: rgba(49, 50, 68, 0.6);
    background-repeat: no-repeat;
    background-position: center;
    background-size: 20%;
    border: 2px solid transparent;
    border-radius: 16px;
    color: #cdd6f4;
    font-size: 18px;
    margin: 12px;
    transition: all 0.3s ease;
}

button:hover {
    background-color: rgba(69, 71, 90, 0.8);
    border-color: rgba(203, 166, 247, 0.5);
}

button:focus {
    background-color: rgba(69, 71, 90, 0.8);
    border-color: #cba6f7;
}

/* Per-button icons and accent colors */
#lock {
    background-image: image(url("/usr/share/wlogout/icons/lock.png"));
}
#lock:hover {
    border-color: #89b4fa;
}

#logout {
    background-image: image(url("/usr/share/wlogout/icons/logout.png"));
}
#logout:hover {
    border-color: #a6e3a1;
}

#suspend {
    background-image: image(url("/usr/share/wlogout/icons/suspend.png"));
}
#suspend:hover {
    border-color: #f9e2af;
}

#hibernate {
    background-image: image(url("/usr/share/wlogout/icons/hibernate.png"));
}
#hibernate:hover {
    border-color: #fab387;
}

#reboot {
    background-image: image(url("/usr/share/wlogout/icons/reboot.png"));
}
#reboot:hover {
    border-color: #cba6f7;
}

#shutdown {
    background-image: image(url("/usr/share/wlogout/icons/shutdown.png"));
}
#shutdown:hover {
    border-color: #f38ba8;
}
```

### Custom icons

The default icons at `/usr/share/wlogout/icons/` are basic. Many rices use custom SVG icons. To use custom icons:

1. Create `~/.config/wlogout/icons/` and place SVGs there
2. Reference them in CSS: `background-image: image(url("icons/lock.svg"));` (relative to `~/.config/wlogout/`)

Popular icon sets for wlogout: Phosphor Icons, Lucide, or hand-drawn SVGs matching the rice aesthetic.

### Layout variations

**3-column (no hibernate)** — most common, since hibernate requires swap:

Remove the hibernate entry from the layout JSON and adjust CSS grid if needed. wlogout auto-arranges buttons in a grid.

**Circular buttons:**

```css
button {
    border-radius: 50%;
    min-width: 120px;
    min-height: 120px;
    background-size: 40%;
}
```

**Text-only (no icons):**

Remove all `background-image` properties and increase font size:

```css
button {
    font-size: 24px;
    font-weight: bold;
}
```

---

## Launch options

```bash
wlogout                                     # defaults
wlogout --protocol layer-shell              # explicit Wayland layer-shell
wlogout --layout ~/.config/wlogout/layout   # custom layout path
wlogout --css ~/.config/wlogout/style.css   # custom CSS path
wlogout -b 5                                # button margin (pixels)
wlogout -c 0                                # column count (0 = auto)
wlogout -r 0                                # row count (0 = auto)
wlogout -m 600                              # margin from screen edge
wlogout --no-span                           # don't span all monitors
```

**Common flags:**
- `-b 5 -T 400 -B 400` — margin from top/bottom for a centered floating feel
- `-c 6 -r 1` — force single row of 6 buttons (horizontal layout)
- `-c 3 -r 2` — force 3x2 grid

---

## Hyprland integration

### Keybind

```ini
bindd = $mainMod, Escape, Open power menu, exec, wlogout
# Or in a power submap:
bindd = $mainMod, P, Open power menu, exec, wlogout
```

### Waybar power button

```json
"custom/power": {
    "format": "⏻",
    "tooltip": false,
    "on-click": "wlogout"
}
```

### Window rules

wlogout creates a layer-shell surface, not a regular window. Layer rules apply:

```ini
layerrule = blur true, match:namespace logout_dialog
```

### Alternative: power submap vs wlogout

For users who prefer a keyboard-driven approach without a GUI, a Hyprland submap serves the same purpose (defined in keybinds.conf). wlogout is better for users who want a visual, mouse-friendly interface. Both can coexist — bind wlogout to a key and the power submap to another.
