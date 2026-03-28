# Hyprland Ricing Reference

Complete reference for making a Hyprland config look great. Load this when generating a full rice, answering questions about visual style, or when the user mentions blur, animations, plugins, special workspaces, or opacity.

---

## decoration block — ricing values

```ini
decoration {
    rounding = 10            # 8-12px sweet spot; 0 = unfinished; 20+ = pill shapes
    rounding_power = 2.0     # 2.0 = circular; 4.0+ = squircle (trendy 2025)
    active_opacity = 1.0
    inactive_opacity = 0.9   # subtle dim on unfocused windows
    fullscreen_opacity = 1.0
    dim_inactive = true
    dim_strength = 0.15      # default 0.5 is too heavy; 0.1-0.2 = subtle

    blur {
        enabled = true
        size = 8
        passes = 3
        noise = 0.0117
        contrast = 0.9
        brightness = 0.8
        vibrancy = 0.17          # color saturation boost in blur
        vibrancy_darkness = 0.0  # darkens vibrancy effect
        new_optimizations = true
        xray = false             # true = ignore window content, blur full background
        special = true           # blur special workspace background
    }

    shadow {
        enabled = true
        range = 20
        render_power = 3
        color = rgba(1a1a1abb)          # dark semi-transparent
        color_inactive = rgba(1a1a1a44) # lighter on unfocused
        offset = 0 0                    # x y pixel offset
        scale = 1.0
    }
}
```

**Blur size/passes pairing** — mismatched values look grainy:
| Style | size | passes |
|-------|------|--------|
| Subtle | 4 | 2 |
| Moderate | 8 | 3 |
| Heavy | 12 | 4 |

---

## general block — gradient borders

Gradient borders are the single highest-impact visual setting in Hyprland ricing.

```ini
general {
    gaps_in = 8            # between windows; 5-10 common
    gaps_out = 16          # from screen edge; 10-20 common
    border_size = 2        # 2-3px in rices; 1 gets lost; 0 = borderless

    # Gradient border — two accent colors at an angle
    col.active_border = rgba(cba6f7ff) rgba(89b4faff) 45deg
    col.inactive_border = rgba(595959aa)

    # Animated rotating gradient (use `once` not `loop` — loop drains GPU)
    # col.active_border = rgba(cba6f7ff) rgba(89b4faff) rgba(a6e3a1ff) 45deg

    resize_on_border = true   # drag window borders to resize — very popular QoL
    layout = dwindle
}
```

**Color reference — Catppuccin Mocha accents** (most common rice palette):
- Mauve: `cba6f7`, Blue: `89b4fa`, Green: `a6e3a1`, Red: `f38ba8`
- Peach: `fab387`, Yellow: `f9e2af`, Base: `1e1e2e`, Surface0: `313244`

---

## misc block

```ini
misc {
    disable_hyprland_logo = true        # always set in rices
    disable_splash_rendering = true     # always set
    force_default_wallpaper = 0
    enable_swallow = true               # terminal hides when launching GUI app
    swallow_regex = ^(kitty|alacritty|foot|wezterm|ghostty)$
    vfr = true                          # variable frame rate — saves power
    animate_manual_resizes = true       # smooth resize animations
    focus_on_activate = false           # don't steal focus on activation requests
}
```

---

## Animation system

### Full animation tree

```
global
├── windows
│   ├── windowsIn      (opening)
│   ├── windowsOut     (closing)
│   └── windowsMove    (moving/resizing)
├── fade
│   ├── fadeIn
│   ├── fadeOut
│   └── fadeSwitch     (layer visibility changes)
├── border             (border color transitions)
├── borderangle        (gradient angle rotation)
├── workspaces
│   ├── workspacesIn
│   └── workspacesOut
└── specialWorkspace
    ├── specialWorkspaceIn
    └── specialWorkspaceOut
```

### Syntax

```ini
bezier = NAME, X1, Y1, X2, Y2   # cubic bezier control points
animation = TYPE, ON, SPEED, BEZIER[, STYLE [MODIFIER]]
```

- `ON`: 1 = enabled, 0 = disabled
- `SPEED`: in deciseconds (1 = 100ms). Range: 3-10 typical
- `STYLE`: slide, slidevert, fade, slidefade, slidefadevert, popin, popout
- `MODIFIER`: direction (left/right/top/bottom) or percent (e.g. `slidefade 20%`)

### Bezier curve presets

```ini
bezier = linear,     1, 1, 0, 0
bezier = default,    0.25, 0.1, 0.25, 1.0   # Hyprland default
bezier = snap,       0.05, 0.9, 0.1, 1.0    # fast snap-in
bezier = easeOut,    0.0, 0.0, 0.2, 1.0     # decelerate
bezier = overshoot,  0.05, 0.9, 0.1, 1.1    # slight bounce (y2 > 1.0)
bezier = myBezier,   0.05, 0.9, 0.1, 1.05   # gentle overshoot — most popular
```

Overshoot beziers (`y2 > 1.0`) need `SPEED >= 7` or the bounce looks clipped.

### Animation presets

**Minimal:**
```ini
animation = global, 1, 3, default
```

**Balanced:**
```ini
bezier = myBezier, 0.05, 0.9, 0.1, 1.05
animation = windows,    1, 7, myBezier, slide
animation = fade,       1, 5, myBezier
animation = workspaces, 1, 6, myBezier, slidefade 20%
animation = specialWorkspace, 1, 5, myBezier, slidevert
animation = border,     1, 10, default
```

**Fancy:**
```ini
bezier = overshoot,    0.05, 0.9, 0.1, 1.1
bezier = easeOutCubic, 0.33, 1, 0.68, 1
animation = windowsIn,  1, 7, overshoot,    popin 80%
animation = windowsOut, 1, 5, easeOutCubic, popin 80%
animation = workspaces, 1, 8, overshoot,    slide
animation = specialWorkspace, 1, 5, easeOutCubic, slidefadevert 30%
animation = fade,       1, 4, easeOutCubic
animation = border,     1, 10, linear
animation = borderangle, 1, 20, linear, once   # once = renders once, not looping
```

**Workspace animation styles:**
| Style | Description |
|-------|-------------|
| `slide` | Horizontal slide; direction auto-follows workspace number |
| `slidevert` | Vertical slide |
| `fade` | Cross-fade; no movement |
| `slidefade 20%` | 20% slide + fade — modern, smooth |
| `slidefadevert 20%` | Vertical version |

---

## Smart gaps (no gaps when solo window)

Extremely popular rice pattern — gaps disappear when only one window is on the workspace:

```ini
workspace = w[tv1], gapsout:0, gapsin:0
workspace = f[1], gapsout:0, gapsin:0
windowrule = border_size 0, match:float 0, match:workspace w[tv1]
windowrule = rounding 0, match:float 0, match:workspace w[tv1]
```

`w[tv1]` = workspace with 1 tiled window (v = visible, t = tiled); `f[1]` = first fullscreen.

---

## Special workspaces (scratchpads)

Toggle-able floating overlays, separate from normal workspaces:

```ini
# Toggle
bind = SUPER, S, togglespecialworkspace, scratchpad
# Send window to it silently
bind = SUPER_SHIFT, S, movetoworkspacesilent, special:scratchpad

# Multiple named special workspaces
bind = SUPER, T, togglespecialworkspace, terminal
bind = SUPER_SHIFT, T, movetoworkspacesilent, special:terminal

# Auto-launch in special workspace
exec-once = [workspace special:terminal silent] kitty
```

**Appearance:**
```ini
decoration {
    dim_special = 0.3    # 0.0 = no dim; 0.5 = heavy; default 0.2
    blur {
        special = true   # blur background behind special workspace
    }
}
```

**Animation** — best options:
```ini
animation = specialWorkspace, 1, 6, myBezier, slidevert      # slide from top
animation = specialWorkspace, 1, 5, myBezier, slidefade 20%  # fade+slide
animation = specialWorkspace, 1, 4, easeOut, fade            # subtle fade
```

---

## Window opacity rules

```ini
# Global in decoration {}
decoration {
    active_opacity = 1.0
    inactive_opacity = 0.87
    dim_inactive = true
    dim_strength = 0.15
}

# Windowrule patterns — block syntax with required name = as first field
# Terminals (most commonly semi-transparent)
windowrule {
    name = kitty-opacity
    match:class = kitty
    opacity = 0.92 override 0.85 override
}

# Force opaque for media/games
windowrule {
    name = opaque-mpv
    match:class = mpv
    opaque = on
}

windowrule {
    name = opaque-steam
    match:class = steam
    opaque = on
}

# Keep file manager opaque
windowrule {
    name = opaque-thunar
    match:class = thunar
    opacity = 1.0 override 1.0 override
}
```

**Opacity is multiplicative.** `decoration:inactive_opacity = 0.9` × windowrule `opacity 0.9` = 0.81. Use `override` for exact values:
- `opacity 0.9` = multiply by global
- `opacity 0.9 override` = set active to exactly 0.9
- `opacity 0.9 override 0.8 override` = active 0.9, inactive 0.8

---

## Layer rules (blur bars and launchers)

Bars, launchers, and notification daemons are Wayland *layers*, not windows. Use `layerrule`:

```ini
# Frosted glass effect on waybar, rofi, notifications
layerrule = blur true, match:namespace waybar
layerrule = blur true, match:namespace wofi
layerrule = blur true, match:namespace rofi
layerrule = blur true, match:namespace notifications   # dunst/mako
layerrule = blur true, match:namespace swaync-control-center
```

> **IMPORTANT (Hyprland 0.54+):**
> - `ignorezero` and `ignorealpha` are **removed** as layerrule field types. Do NOT use them — they cause config errors.
> - Use `blur true` / `blur false`, NOT `blur on` / `blur off`. Layerrule bool fields require `true`/`false` specifically.
> - Always test new layerrules with `hyprctl keyword layerrule "..."` before committing to config.

Find a layer's namespace: `hyprctl layers`

---

## Hyprland plugins (hyprpm)

```bash
hyprpm add https://github.com/OWNER/REPO
hyprpm enable PLUGIN_NAME
hyprpm update
```

Load at startup: `exec-once = hyprpm reload -n` in autostart.conf.

### Popular ricing plugins

**hyprexpo** — workspace overview grid (macOS Exposé):
```ini
plugin {
    hyprexpo {
        columns = 3
        gap_size = 5
        bg_col = rgba(111111ff)
        workspace_method = center current
        enable_gesture = true
        gesture_fingers = 3
    }
}
bind = SUPER, grave, hyprexpo:expo, toggle
```

**hyprbars** — window title bars with close/max/min buttons:
```ini
plugin {
    hyprbars {
        bar_height = 28
        bar_color = rgba(1e1e2eff)
        col.text = rgba(cdd6f4ff)
        bar_text_font = JetBrainsMono Nerd Font
        bar_text_size = 11
        bar_part_of_window = true
        buttons {
            button_size = 10
            col.close = rgba(f38ba8ff)
            col.maximize = rgba(a6e3a1ff)
            col.minimize = rgba(f9e2afff)
        }
    }
}
```

**hyprtrails** — fading cursor trail:
```ini
plugin {
    hyprtrails {
        color = rgba(cba6f766)   # accent color, semi-transparent
    }
}
```

**hyprwinwrap** — renders a window as wallpaper (video wallpapers):
```ini
windowrule = noblur,  match:class hyprwinwrap
windowrule = nofocus, match:class hyprwinwrap
windowrule = noshadow, match:class hyprwinwrap
windowrule = pin,     match:class hyprwinwrap
windowrule = noanim,  match:class hyprwinwrap
exec-once = hyprwinwrap -c "mpv --loop --no-audio ~/wallpaper.mp4"
```

---

## hyprlock — full ricing reference

Hyprlock requires a config file — without one it renders a black screen. Generate at least `background {}` + `input-field {}`.

### background widget

```ini
# Option A: blurred screenshot (most popular)
background {
    monitor =
    path = screenshot
    blur_passes = 3
    blur_size = 7
    noise = 0.0117
    contrast = 0.8916
    brightness = 0.8172
    vibrancy = 0.1696
}

# Option B: wallpaper with blur
background {
    monitor =
    path = /path/to/wallpaper.png
    blur_passes = 2
    blur_size = 5
}
```

### input-field widget — full options

```ini
input-field {
    monitor =
    size = 300, 60
    outline_thickness = 3
    dots_size = 0.3
    dots_spacing = 0.15
    dots_center = true
    dots_rounding = -1              # -1 = circle dots

    outer_color = rgba(cba6f7ff)
    inner_color = rgba(1e1e2ecc)
    font_color = rgb(205, 214, 244)
    font_family = JetBrainsMono Nerd Font

    check_color = rgba(fab387ff) rgba(f9e2afff) 45deg   # amber while checking
    fail_color  = rgba(f38ba8ff) rgba(eba0acff) 45deg   # red on fail
    capslock_color = rgba(f9e2afff)                     # yellow on capslock

    fade_on_empty = true
    fade_timeout = 1500
    placeholder_text = <i>Password...</i>
    rounding = 12
    swap_font_color = false    # true = dramatic invert on auth events

    position = 0, -100
    halign = center
    valign = center
    shadow_passes = 2
}
```

### label widgets (clock, date, user)

```ini
# Large clock
label {
    monitor =
    text = cmd[update:1000] echo "<span font_desc='JetBrainsMono Nerd Font Bold 72'>$(date +"%H:%M")</span>"
    color = rgba(205, 214, 244, 1.0)
    font_size = 72
    font_family = JetBrainsMono Nerd Font Bold
    position = 0, 250
    halign = center
    valign = center
}

# Date
label {
    monitor =
    text = cmd[update:60000] echo "$(date +"%A, %B %d")"
    color = rgba(147, 153, 178, 1.0)
    font_size = 18
    position = 0, 170
    halign = center
    valign = center
}

# Fail attempts
label {
    monitor =
    text = $FAIL <b>($ATTEMPTS[0])</b>
    color = rgba(243, 139, 168, 1.0)
    font_size = 14
    position = 0, -160
    halign = center
    valign = center
}
```

### image widget (profile picture)

```ini
image {
    monitor =
    path = /home/$USER/.face
    size = 100
    rounding = -1                    # -1 = circle
    border_size = 3
    border_color = rgba(cba6f7ff)
    position = 0, 75
    halign = center
    valign = center
    shadow_passes = 1
}
```

### shape widget (decorative)

```ini
# Frosted pill behind clock
shape {
    monitor =
    size = 400, 100
    color = rgba(30, 30, 46, 0.5)
    rounding = 50
    border_size = 0
    position = 0, 250
    halign = center
    valign = center
    zindex = -1         # behind labels
}
```

### hyprlock animations

```ini
animations {
    enabled = true
}
bezier = easeOut, 0.0, 0.0, 0.2, 1.0
animation = fade, 1, 3, easeOut
animation = inputFieldColors, 1, 2, linear
animation = inputFieldDots, 1, 1, linear
animation = inputFieldFade, 1, 2, easeOut
```

---

## swaync ricing

swaync adds a side-panel notification center (not just toast popups).

**Config:** `~/.config/swaync/config.json` + `~/.config/swaync/style.css`

### config.json (key options)

```json
{
  "positionX": "right",
  "positionY": "top",
  "layer": "overlay",
  "control-center-layer": "top",
  "control-center-margin-top": 8,
  "control-center-margin-right": 8,
  "control-center-width": 500,
  "notification-window-width": 400,
  "timeout": 5,
  "timeout-critical": 0,
  "transition-time": 200,
  "hide-on-action": true,
  "widgets": ["title", "dnd", "notifications"],
  "widget-config": {
    "title": { "text": "Notifications", "clear-all-button": true },
    "dnd": { "text": "Do Not Disturb" }
  }
}
```

### style.css (themed example — Catppuccin Mocha)

```css
.control-center {
    background: rgba(30, 30, 46, 0.85);
    border-radius: 12px;
    border: 1px solid rgba(203, 166, 247, 0.3);
    box-shadow: 0 4px 24px rgba(0,0,0,0.4);
    backdrop-filter: blur(20px);
}

.notification {
    border-radius: 10px;
    background: rgba(49, 50, 68, 0.9);
    margin: 4px 8px;
}

.notification.critical {
    border: 1px solid #f38ba8;
}

.notification-action {
    border-radius: 6px;
    color: #cba6f7;
}
```

**Autostart:** `exec-once = swaync`
**Waybar toggle button:**
```json
"custom/swaync": {
    "exec": "swaync-client -swb",
    "on-click": "swaync-client -t -sw",
    "format": " {}"
}
```

---

## rofi ricing (.rasi files)

rofi requires `rofi-wayland` package. Themes go in `~/.config/rofi/themes/`.

```rasi
/* ~/.config/rofi/themes/catppuccin.rasi */
* {
    bg:     #1e1e2e;
    bg-alt: #313244;
    accent: #cba6f7;
    fg:     #cdd6f4;
    fg-muted: #6c7086;
}

window {
    background-color: @bg;
    border-radius: 12px;
    border: 2px solid @accent;
    width: 600px;
}

mainbox { background-color: transparent; }

inputbar {
    background-color: @bg-alt;
    border-radius: 10px 10px 0 0;
    padding: 8px 12px;
    children: [ prompt, entry ];
}

prompt { color: @accent; }
entry  { color: @fg; background-color: transparent; }

listview {
    background-color: transparent;
    padding: 4px;
}

element selected {
    background-color: @accent;
    border-radius: 6px;
    color: @bg;
}

element-text { color: inherit; }
```

Use in keybind: `bind = SUPER, R, exec, rofi -show drun -theme ~/.config/rofi/themes/catppuccin.rasi`

---

## Common rice mistakes

1. **Opacity stacking without `override`** — `inactive_opacity = 0.85` + windowrule `opacity 0.85` = 0.72. Add `override`.
2. **`blur:passes = 1` with high `blur:size`** — looks grainy. Match the table above.
3. **Thin border (`border_size = 1`) with gap rice** — barely visible. Use 2-3px.
4. **Missing `layerrule = blur true`** for bars/launchers — windows blur but waybar stays flat. Use `blur true` NOT `blur on`.
5. **`borderangle` with `loop`** — renders at full refresh rate constantly, drains battery. Use `once`.
6. **Both `xdg-desktop-portal-kde` and `xdg-desktop-portal-hyprland` installed** — screensharing breaks. Keep only `-hyprland` + `-gtk`.
7. **`autogenerated = 1` in hyprland.conf** — Hyprland overwrites your config on update. Delete it.
8. **`exec` instead of `exec-once` for daemons** — creates duplicates on every reload.
9. **`windowrulev2` syntax** — removed in 0.41+. Use `windowrule {}` blocks or `windowrule = effect, match:class ...`.
10. **`sway/workspaces` in waybar** — must be `hyprland/workspaces`; `button.focused` → `button.active`.
11. **`env = QT_QPA_PLATFORM,"wayland"`** — quotes are literal in env values. No quotes.
12. **`ignorezero` / `ignorealpha` in layerrules** — removed in 0.54+. These field types no longer exist and cause config errors.
13. **Inline windowrule block syntax** — `windowrule { match:class = X; float = on }` on a single line does NOT work. Must use multiline blocks.
14. **Missing `name =` in windowrule blocks** — every `windowrule {}` block MUST have `name =` as its first field, or you get "special category's first value must be the key" error.
15. **Catppuccin theme name mismatch** — the AUR package `catppuccin-gtk-theme-mocha` installs as `catppuccin-mocha-{accent}-standard+default`, NOT `catppuccin-mocha-standard-{accent}-dark`. Always check `/usr/share/themes/` for actual names.
16. **Catppuccin cursor name mismatch** — `catppuccin-cursors-mocha` installs per-accent (e.g., `catppuccin-mocha-mauve-cursors`), not just `catppuccin-mocha-dark-cursors`. Check `/usr/share/icons/` for actual names.
17. **Unquoted uwsm env values** — `export QT_QPA_PLATFORM=wayland;xcb` will execute `xcb` as a command. Must be `export QT_QPA_PLATFORM='wayland;xcb'`. Same for `GDK_BACKEND`.
18. **Font verification with `fc-list | grep`** — unreliable due to full path output. Use `fc-list : family | grep -qi` to search clean family names only.
