---
title: swww Animated Wallpaper Daemon Reference
weight: 7
---

# swww Reference

Configuration and usage guide for swww — an animated wallpaper daemon for Wayland. Load this when the user chose swww for wallpapers, or when they ask about animated wallpaper transitions.

## Overview

swww differs from hyprpaper in that it supports smooth animated transitions between wallpapers (fade, wipe, wave, grow, etc.) and can display animated GIFs. It's a daemon + client architecture — `swww-daemon` runs in the background and `swww img` commands set wallpapers.

**Package**: `swww` (AUR)
**No config file** — all options are command-line flags.

---

## Setup

### Autostart

```ini
# Start the daemon (required)
exec-once = swww-daemon

# Optionally set an initial wallpaper after the daemon starts
exec-once = swww img ~/Pictures/wallpaper.png
```

The daemon must be running before any `swww img` commands. If setting a wallpaper at startup, ensure ordering with a small delay or use `&&`:

```ini
exec-once = swww-daemon && swww img ~/Pictures/wallpaper.png
```

### Daemon options

```bash
swww-daemon                         # default
swww-daemon --format xrgb           # pixel format (xrgb or xbgr)
swww-daemon --no-cache              # disable wallpaper cache
```

The daemon caches the current wallpaper per-output so it persists across restarts. Cache location: `$XDG_CACHE_HOME/swww/` or `~/.cache/swww/`.

---

## Setting wallpapers

### Basic usage

```bash
swww img /path/to/wallpaper.png          # set on all monitors
swww img -o DP-1 /path/to/wallpaper.png  # set on specific monitor
swww img /path/to/animated.gif           # animated GIF support
```

### Transition options

The transition system is swww's main feature. All transitions are specified as flags to `swww img`:

| Flag | Description | Default |
|------|-------------|---------|
| `--transition-type` | Animation type (see table below) | `simple` |
| `--transition-step` | Speed: frames per step (1-255, higher = faster) | `90` |
| `--transition-duration` | Duration in seconds (float) | `3` |
| `--transition-fps` | Animation frame rate (1-255) | `30` |
| `--transition-angle` | Angle in degrees for directional transitions | `45` |
| `--transition-pos` | Origin point for grow/center transitions | `center` |
| `--transition-bezier` | Custom bezier curve (4 floats: x1,y1,x2,y2) | `.25,.1,.25,1` |
| `--transition-wave` | Wave size for wave transition (width,height) | `20,20` |
| `--fill` | Scaling: `crop`, `fit`, `no` | `crop` |
| `--filter` | Scaling filter: `Nearest`, `Bilinear`, `CatmullRom`, `Mitchell`, `Lanczos3` | `Lanczos3` |
| `--resize` | Resize behavior: `crop`, `fit`, `no` | `crop` |
| `--invert-y` | Invert y-axis for transition | - |

### Transition types

| Type | Description | Best for |
|------|-------------|----------|
| `simple` | Instant swap (no animation) | Quick changes |
| `fade` | Cross-fade between old and new | Most universally appealing |
| `left` | Slide in from left | Workspace-like feel |
| `right` | Slide in from right | Workspace-like feel |
| `top` | Slide in from top | — |
| `bottom` | Slide in from bottom | — |
| `center` | Expand from center outward | Dramatic reveal |
| `outer` | Shrink inward from edges | Reverse of center |
| `wipe` | Directional wipe (use `--transition-angle`) | Clean, modern |
| `wave` | Wavy transition (use `--transition-wave`) | Playful, distinctive |
| `grow` | Expand from a point (use `--transition-pos`) | Click-origin effects |
| `any` | Random from all types | Variety |
| `random` | Random (excludes simple/none) | Variety |
| `none` | Same as simple | — |

### Transition position (`--transition-pos`)

Used with `grow` and `center` types:
- `center` — screen center
- `top`, `bottom`, `left`, `right` — edges
- `top-left`, `top-right`, `bottom-left`, `bottom-right` — corners
- `0.5,0.5` — fractional coordinates (0.0-1.0)
- Pixel coordinates: `960,540`

### Example commands

```bash
# Smooth fade over 2 seconds at 60fps
swww img ~/wallpaper.png --transition-type fade --transition-duration 2 --transition-fps 60

# Wipe from left to right
swww img ~/wallpaper.png --transition-type wipe --transition-angle 0

# Wipe diagonally
swww img ~/wallpaper.png --transition-type wipe --transition-angle 45

# Grow from center, fast
swww img ~/wallpaper.png --transition-type grow --transition-pos center --transition-duration 1.5

# Wave effect
swww img ~/wallpaper.png --transition-type wave --transition-wave 30,30 --transition-duration 3

# Random transition
swww img ~/wallpaper.png --transition-type random --transition-duration 2 --transition-fps 60
```

---

## Wallpaper cycling scripts

swww doesn't have built-in directory cycling like hyprpaper. Common pattern: a shell script + timer or cron.

### Simple cycling script

```bash
#!/bin/bash
# ~/.config/hypr/scripts/wallpaper-cycle.sh
WALLPAPER_DIR="$HOME/Pictures/wallpapers"
INTERVAL=300  # seconds

while true; do
    # Pick a random wallpaper
    WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" \) | shuf -n 1)

    swww img "$WALLPAPER" \
        --transition-type fade \
        --transition-duration 2 \
        --transition-fps 60

    sleep "$INTERVAL"
done
```

Add to autostart:

```ini
exec-once = ~/.config/hypr/scripts/wallpaper-cycle.sh &
```

### Keybind for next wallpaper

```bash
#!/bin/bash
# ~/.config/hypr/scripts/wallpaper-random.sh
WALLPAPER_DIR="$HOME/Pictures/wallpapers"
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" \) | shuf -n 1)

swww img "$WALLPAPER" \
    --transition-type random \
    --transition-duration 2 \
    --transition-fps 60
```

```ini
bindd = $mainMod, W, Next wallpaper, exec, ~/.config/hypr/scripts/wallpaper-random.sh
```

### Per-monitor wallpapers

```bash
swww img -o DP-1 ~/wallpapers/monitor1.png --transition-type fade
swww img -o HDMI-A-1 ~/wallpapers/monitor2.png --transition-type fade
```

---

## Other commands

```bash
swww query            # show current wallpaper per output
swww clear 1e1e2e     # set solid color (RRGGBB, no #)
swww kill             # stop the daemon
swww restore          # restore cached wallpapers (automatic on daemon start)
```

---

## GIF wallpapers

swww supports animated GIF wallpapers:

```bash
swww img ~/wallpapers/animated.gif
```

**Performance notes:**
- First display of a GIF triggers frame caching (brief CPU spike)
- Subsequent displays of the same GIF are cached and fast
- Large/high-framerate GIFs consume more memory
- Cache location: `~/.cache/swww/`
- Use `--no-cache` on the daemon to disable caching (not recommended)

---

## swww vs hyprpaper

| Feature | swww | hyprpaper |
|---------|------|-----------|
| Animated transitions | Yes (12+ types) | No |
| GIF support | Yes | No |
| Config file | None (CLI flags) | hyprpaper.conf |
| IPC | `swww img` CLI | `hyprctl hyprpaper` |
| Directory cycling | Script-based | Built-in (`timeout`, `order`) |
| Memory usage | Higher (frame cache) | Lower |
| Startup speed | Slightly slower | Fast |
| Per-monitor | Yes (`-o`) | Yes (`monitor =`) |

**Choose swww** when: the user wants animated transitions, GIF wallpapers, or a more dynamic feel.
**Choose hyprpaper** when: the user wants simple static wallpapers with minimal resource usage and built-in directory rotation.

---

## Hyprland integration notes

### Layer rules

swww renders directly to the background layer — no layer rules needed.

### Wallpaper-dependent theming

For setups using wallust/pywal to generate colors from wallpaper, swww pairs well:

```bash
# In wallpaper script, after swww img:
wallust run "$WALLPAPER"
# Then reload waybar, dunst, etc. with new colors
```

### Conflict with hyprpaper

swww and hyprpaper cannot run simultaneously. Only autostart one. If switching from hyprpaper to swww, remove the hyprpaper exec-once line and hyprpaper.conf reference.
