---
title: Notification Daemon Configuration Reference
weight: 6
---

# Notification Daemon Reference

Complete configuration and theming guide for the three major notification daemons used with Hyprland: dunst, mako, and swaync. Load this when generating notification daemon configs or when the user asks about notification styling.

## Table of Contents
- [Choosing a daemon](#choosing-a-daemon)
- [dunst](#dunst)
- [mako](#mako)
- [swaync (SwayNotificationCenter)](#swaync)
- [Hyprland integration](#hyprland-integration)

---

## Choosing a daemon

| Feature | dunst | mako | swaync |
|---------|-------|------|--------|
| Config format | INI (`dunstrc`) | key=value | JSON + CSS |
| Styling method | Config options | Config options | Full GTK CSS |
| Notification center | No (popups only) | No (popups only) | Yes (side panel) |
| Action buttons | Yes | Yes | Yes |
| Inline replies | No | No | Yes |
| Media controls | No | No | Yes (mpris widget) |
| Do Not Disturb | Via `dunstctl` | Via `makoctl` | Built-in toggle |
| Grouped notifications | Via `stack_tag` | Via `group-by` | Built-in |
| Resource usage | Low | Very low | Moderate |
| Complexity | Medium | Low | Higher |

**Recommendation**: dunst for most users (battle-tested, highly configurable). swaync if the user wants a notification center panel with media controls. mako for minimal setups.

Only one notification daemon should run at a time — they conflict on the D-Bus notification interface.

---

## dunst

**Config location**: `~/.config/dunst/dunstrc`
**Format**: INI-like with `[section]` blocks

### Complete themed config

```ini
[global]
    # Display
    monitor = 0
    follow = mouse                  # none/mouse/keyboard
    width = (300, 400)              # min, max width
    height = 300                    # max height per notification
    origin = top-right
    offset = 12x12                  # x,y from origin
    notification_limit = 5          # max visible (0 = unlimited)

    # Appearance
    corner_radius = 12              # match hyprland rounding
    frame_width = 2
    frame_color = "#cba6f7"         # accent color for border
    separator_height = 2
    separator_color = frame
    gap_size = 6                    # gap between notifications
    padding = 12
    horizontal_padding = 12
    text_icon_padding = 12

    # Text
    font = JetBrainsMono Nerd Font 10
    markup = full                   # full/strip/no — enables Pango markup
    format = "<b>%s</b>\n%b"        # %s = summary, %b = body, %a = appname, %i = icon
    alignment = left
    vertical_alignment = center
    word_wrap = true
    ellipsize = end

    # Icons
    icon_position = left            # left/right/top/off
    min_icon_size = 32
    max_icon_size = 64
    icon_theme = Papirus
    enable_recursive_icon_lookup = true

    # Behavior
    sort = true                     # sort by urgency
    indicate_hidden = true          # show count of hidden notifications
    show_indicators = true          # show action indicators (A/U)
    idle_threshold = 120            # pause timeout when idle (seconds)
    sticky_history = true
    history_length = 20
    show_age_threshold = 60         # show age after N seconds (-1 = never)

    # Actions
    mouse_left_click = do_action, close_current
    mouse_middle_click = close_all
    mouse_right_click = close_current

    # Wayland-specific
    layer = top                     # bottom/top/overlay
    force_xwayland = false

    # Progress bar (for volume/brightness notifications)
    progress_bar = true
    progress_bar_height = 10
    progress_bar_frame_width = 1
    progress_bar_min_width = 150
    progress_bar_max_width = 300
    progress_bar_corner_radius = 4

[urgency_low]
    background = "#1e1e2e"
    foreground = "#cdd6f4"
    frame_color = "#585b70"
    timeout = 5
    highlight = "#89b4fa"           # progress bar color

[urgency_normal]
    background = "#1e1e2e"
    foreground = "#cdd6f4"
    frame_color = "#cba6f7"
    timeout = 8
    highlight = "#cba6f7"

[urgency_critical]
    background = "#1e1e2e"
    foreground = "#cdd6f4"
    frame_color = "#f38ba8"
    timeout = 0                     # 0 = never auto-dismiss
    highlight = "#f38ba8"
```

### Custom rules

Rules match notifications and override properties. Place after urgency sections:

```ini
# Volume/brightness progress bar notifications
[volume]
    appname = "changevolume"
    highlight = "#cba6f7"
    set_stack_tag = "volume"

# Slack — longer timeout, custom icon
[slack]
    desktop_entry = "Slack"
    timeout = 15

# Discord — mark as low urgency
[discord]
    appname = "discord"
    urgency = low
```

### dunstctl commands

```bash
dunstctl close          # close top notification
dunstctl close-all      # close all
dunstctl history-pop    # show last from history
dunstctl set-paused true/false/toggle  # DND mode
dunstctl count          # show notification counts
```

### Color format

dunst uses quoted hex: `"#RRGGBB"` or `"#RRGGBBAA"` for transparency. The quotes are required in dunstrc.

---

## mako

**Config location**: `~/.config/mako/config`
**Format**: key=value, one per line (no `=` spaces)

### Complete themed config

```ini
# Appearance
font=JetBrainsMono Nerd Font 10
background-color=#1e1e2eee
text-color=#cdd6f4
border-size=2
border-color=#cba6f7
border-radius=12
width=350
height=150
margin=12
padding=12,16
icons=1
max-icon-size=48
icon-path=/usr/share/icons/Papirus

# Behavior
max-visible=5
sort=-time
layer=overlay
anchor=top-right
default-timeout=5000
ignore-timeout=0

# Grouping
group-by=app-name
format=<b>%s</b>\n%b

# Actions
on-button-left=invoke-default-action
on-button-middle=dismiss-all
on-button-right=dismiss

[urgency=low]
border-color=#585b70
default-timeout=3000

[urgency=critical]
border-color=#f38ba8
default-timeout=0
ignore-timeout=1

# Per-app overrides
[app-name=Slack]
default-timeout=15000

[app-name=discord]
border-color=#89b4fa
```

### Criteria sections

mako uses `[criteria]` blocks for conditional styling. Criteria can match:
- `app-name=X` — application name
- `urgency=low/normal/critical`
- `category=X` — notification category
- `desktop-entry=X` — .desktop file name
- `actionable` — has actions
- `expiring` — will auto-dismiss
- `grouped` — is part of a group
- `hidden` — is hidden (overflow)
- `mode=X` — current mode (for DND)

### makoctl commands

```bash
makoctl dismiss         # dismiss top
makoctl dismiss --all   # dismiss all
makoctl invoke          # invoke default action
makoctl set-mode dnd    # enable DND
makoctl set-mode default  # disable DND
makoctl reload          # reload config
```

### Color format

mako uses `#RRGGBB` or `#RRGGBBAA` — no quotes needed.

### Auto-start note

mako supports D-Bus activation (starts when a notification arrives) but explicitly starting it in autostart is more reliable when multiple daemons are installed:
```ini
exec-once = mako
```

---

## swaync

**Config location**: `~/.config/swaync/config.json` + `~/.config/swaync/style.css`

swaync is unique among the three — it provides a full notification center panel (toggled open/closed) in addition to popup notifications, and its appearance is controlled via GTK CSS rather than config options.

### config.json

```json
{
  "$schema": "/etc/xdg/swaync/configSchema.json",
  "positionX": "right",
  "positionY": "top",
  "layer": "overlay",
  "control-center-layer": "top",
  "cssPriority": "user",
  "control-center-margin-top": 8,
  "control-center-margin-bottom": 8,
  "control-center-margin-right": 8,
  "control-center-width": 500,
  "notification-window-width": 400,
  "notification-icon-size": 48,
  "notification-body-image-height": 100,
  "notification-body-image-width": 200,
  "timeout": 5,
  "timeout-low": 3,
  "timeout-critical": 0,
  "fit-to-screen": true,
  "transition-time": 200,
  "hide-on-clear": false,
  "hide-on-action": true,
  "script-fail-notify": true,
  "widgets": [
    "title",
    "dnd",
    "mpris",
    "notifications"
  ],
  "widget-config": {
    "title": {
      "text": "Notifications",
      "clear-all-button": true,
      "button-text": "Clear"
    },
    "dnd": {
      "text": "Do Not Disturb"
    },
    "mpris": {
      "image-size": 96,
      "image-radius": 8
    }
  }
}
```

### Available widgets (for the `widgets` array)

| Widget | Purpose |
|--------|---------|
| `title` | Header with "Notifications" text and clear-all button |
| `dnd` | Do Not Disturb toggle switch |
| `notifications` | The notification list itself |
| `mpris` | Media player controls (album art, play/pause/skip) |
| `label` | Custom text label |
| `menubar` | Custom menu with submenus and buttons |
| `buttons-grid` | Grid of toggle buttons (wifi, bluetooth, DND, etc.) |
| `volume` | Volume slider (requires wireplumber) |
| `backlight` | Brightness slider |
| `inhibitors` | List of notification inhibitors |

### style.css — Complete themed example (Catppuccin Mocha)

```css
/* Notification popups */
.notification-row {
    outline: none;
}

.notification {
    border-radius: 12px;
    margin: 4px 8px;
    padding: 0;
    background: transparent;
}

.notification-content {
    background: rgba(30, 30, 46, 0.92);
    border-radius: 12px;
    border: 1px solid rgba(203, 166, 247, 0.25);
    padding: 8px;
}

.notification.critical .notification-content {
    border: 1px solid #f38ba8;
}

.notification-default-action,
.notification-action {
    border-radius: 8px;
    margin: 4px;
    padding: 4px 8px;
    background: rgba(49, 50, 68, 0.7);
    color: #cdd6f4;
}

.notification-default-action:hover,
.notification-action:hover {
    background: rgba(69, 71, 90, 0.8);
}

.close-button {
    background: rgba(243, 139, 168, 0.3);
    border-radius: 50%;
    color: #f38ba8;
    min-width: 24px;
    min-height: 24px;
    margin: 4px;
    padding: 2px;
}

.close-button:hover {
    background: rgba(243, 139, 168, 0.5);
}

/* Notification body text */
.body {
    color: #bac2de;
}

.summary {
    color: #cdd6f4;
    font-weight: bold;
}

.time {
    color: #6c7086;
    font-size: 0.85em;
}

.body-image {
    border-radius: 8px;
}

/* Control center (side panel) */
.control-center {
    background: rgba(30, 30, 46, 0.88);
    border-radius: 16px;
    border: 1px solid rgba(203, 166, 247, 0.2);
    padding: 12px;
}

.control-center-list {
    background: transparent;
}

/* Widget styling */
.widget-title {
    color: #cdd6f4;
    font-size: 1.3em;
    font-weight: bold;
    margin: 8px;
}

.widget-title > button {
    border-radius: 8px;
    background: rgba(203, 166, 247, 0.2);
    color: #cba6f7;
    padding: 4px 12px;
    border: none;
}

.widget-title > button:hover {
    background: rgba(203, 166, 247, 0.35);
}

.widget-dnd {
    margin: 4px 8px;
    padding: 4px;
}

.widget-dnd > switch {
    border-radius: 12px;
    background: rgba(49, 50, 68, 0.8);
}

.widget-dnd > switch:checked {
    background: rgba(203, 166, 247, 0.5);
}

.widget-dnd > switch slider {
    border-radius: 50%;
    background: #cdd6f4;
}

/* MPRIS widget */
.widget-mpris {
    margin: 8px;
    padding: 8px;
    background: rgba(49, 50, 68, 0.6);
    border-radius: 12px;
}

.widget-mpris-player {
    padding: 8px;
}

.widget-mpris-title {
    color: #cdd6f4;
    font-weight: bold;
}

.widget-mpris-subtitle {
    color: #a6adc8;
}

/* Buttons grid widget */
.widget-buttons-grid {
    margin: 4px 8px;
    padding: 4px;
}

.widget-buttons-grid > flowbox > flowboxchild > button {
    background: rgba(49, 50, 68, 0.6);
    border-radius: 10px;
    color: #cdd6f4;
    min-width: 48px;
    min-height: 48px;
    margin: 4px;
    border: none;
}

.widget-buttons-grid > flowbox > flowboxchild > button.toggle:checked {
    background: rgba(203, 166, 247, 0.3);
    color: #cba6f7;
}
```

### swaync-client commands

```bash
swaync-client -t        # toggle control center
swaync-client -d        # toggle DND
swaync-client -C        # close all notifications
swaync-client -c        # count notifications
swaync-client -swb      # subscribe to notification count (for waybar)
swaync-client -rs       # reload style.css
swaync-client -R        # reload config.json
```

### Debugging CSS

Use `GTK_DEBUG=interactive swaync` to launch the GTK inspector and identify widget class names and hierarchy.

### Color format

config.json doesn't define colors — all colors go in style.css using standard CSS formats: `#RRGGBB`, `rgba(r, g, b, a)`, `rgb(r, g, b)`.

---

## Hyprland integration

### Autostart

Only start ONE notification daemon:

```ini
exec-once = dunst
# OR
exec-once = mako
# OR
exec-once = swaync
```

### Layer rules for blur

Notification daemons are Wayland layers. Apply blur with:

```ini
# dunst
layerrule = blur true, match:namespace notifications

# mako
layerrule = blur true, match:namespace notifications

# swaync — separate rules for popups and control center
layerrule = blur true, match:namespace swaync-control-center
layerrule = blur true, match:namespace swaync-notification-window
```

Find the actual namespace if blur isn't working: `hyprctl layers`

### Waybar integration

**dunst toggle button:**
```json
"custom/dunst": {
    "exec": "dunstctl count | jq -r '.data[0][0].body.data'",
    "on-click": "dunstctl set-paused toggle",
    "restart-interval": 1,
    "return-type": "json",
    "format": "{}"
}
```

**swaync toggle button (recommended):**
```json
"custom/swaync": {
    "tooltip": false,
    "format": "{icon} {}",
    "format-icons": {
        "notification": "󰂚",
        "none": "󰂜",
        "dnd-notification": "󰂛",
        "dnd-none": "󰪑",
        "inhibited-notification": "󰂚",
        "inhibited-none": "󰂜",
        "dnd-inhibited-notification": "󰂛",
        "dnd-inhibited-none": "󰪑"
    },
    "return-type": "json",
    "exec-if": "which swaync-client",
    "exec": "swaync-client -swb",
    "on-click": "swaync-client -t -sw",
    "on-click-right": "swaync-client -d -sw",
    "escape": true
}
```

### Progress bar notifications (volume/brightness)

dunst natively supports progress bars via the `value` hint. Common pattern with `notify-send`:

```bash
# Volume change notification with progress bar
wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ && \
  notify-send -h int:value:$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}') \
    -h string:x-dunst-stack-tag:volume "Volume"
```

mako and swaync also support the `value` hint for progress bars.
