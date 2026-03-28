---
name: hyprland-config
description: Use this skill whenever the user wants to set up, configure, or modify Hyprland — the Wayland compositor. This includes creating a full Hyprland environment from scratch, modifying an existing config, configuring companion apps (waybar, wofi, kitty, dunst, mako, hyprlock, hypridle, hyprpaper, swww), setting up monitors, keybindings, window rules, animations, decorations, layouts, workspace rules, and generating an install.sh. Trigger whenever the user mentions hyprland.conf, hyprctl, Hyprland settings, ricing, tiling on Wayland, or any Hyprland-specific topic like gaps, borders, blur, or animations. Also trigger when the user pastes a hyprland.conf snippet and asks for help. Always use this skill for any Hyprland-related configuration — even simple questions about a single keybind or option.
version: 3.0.0
---

# Hyprland Configuration Skill

You are helping the user set up and configure a **complete Hyprland environment** — not just `hyprland.conf`, but the full ecosystem of companion tools that make Hyprland usable as a daily driver desktop.

## Reference Files

Load these as needed — not all at once:

| File | When to load |
|------|-------------|
| `references/packages.md` | During the user interview — lists all package categories and common choices |
| `references/variables.md` | `general {}`, `decoration {}`, `input {}`, `misc {}`, etc. sections |
| `references/keybinds.md` | `bind =` syntax, flags, submaps, mouse binds |
| `references/dispatchers.md` | Actions used in keybinds |
| `references/monitors.md` | `monitor =` keyword |
| `references/window-rules.md` | `windowrule {}` blocks and effects |
| `references/animations.md` | `animation =`, `bezier =` |
| `references/workspace-rules.md` | Workspace rules |
| `references/layouts.md` → `references/dwindle-layout.md` / `references/master-layout.md` | Layout options (dwindle, master, scrolling, monocle) |
| `references/keywords.md` | `exec`, `exec-once`, `source`, `env` keywords |
| `references/environment.md` | Environment variables |
| `references/hyprlock.md` | hyprlock configuration |
| `references/hypridle.md` | hypridle configuration |
| `references/hyprpaper.md` | hyprpaper configuration |
| `references/xwayland.md` | XWayland, HiDPI setup |

---

## Workflow

### Step 1: Identify the request type

**A. Full setup from scratch** → Run the full interview (Step 2), then generate everything.

**B. Modifying an existing config** → Ask for the relevant file(s) if not pasted. Read before editing. Make minimal targeted changes.

**C. Targeted question** (e.g., "how do I bind SUPER+T to kitty?") → Answer directly with the correct snippet. Load only the relevant reference.

---

### Step 2: The User Interview (for new setups)

Read `references/packages.md` now. Work through these groups, batching related questions together. If the user's opening message already answers some questions (e.g., "catppuccin mocha, kitty, arch linux"), extract those answers and only ask about what's still missing.

#### Group A — System basics
- **Distro?** (Arch/AUR, Fedora, openSUSE, Debian/Ubuntu, NixOS) — affects package names in install.sh
- **Starting fresh or have an existing `~/.config/hypr/`?**

#### Group B — Core tools *(ask all at once)*
- **Terminal:** kitty / alacritty / foot / wezterm / ghostty / other?
- **App launcher:** wofi / rofi / fuzzel / tofi / other?
- **Status bar:** waybar / other / none?
- **Notification daemon:** dunst / mako / swaync / other?

#### Group C — Hypr ecosystem *(ask all at once)*
- **Wallpaper:** hyprpaper (static) / swww (animated) / none?
- **Screen locker:** hyprlock / swaylock / none?
- **Idle daemon:** hypridle / swayidle / none?

#### Group D — Additional tools *(ask all at once)*
- **File manager:** thunar / nautilus / nemo / yazi / none?
- **Screenshots:** grim+slurp / grimblast / other?
- **Clipboard history?** (cliphist + wl-clipboard — yes/no)
- **Bluetooth GUI?** blueman / none?
- **Display manager?** SDDM / greetd+tuigreet / none (TTY launch)?
- **Color temperature?** hyprsunset / gammastep / none?
- **Starting via uwsm?** (changes where env vars go — see env.conf section)

#### Group E — Look and feel *(ask all at once)*
- **Color scheme:** Catppuccin (Mocha/Macchiato/Frappe/Latte) / Tokyo Night / Gruvbox / Dracula / Nord / Everforest / custom?
- **Font:** JetBrainsMono Nerd Font / FiraCode Nerd Font / Hack / other? Font size?
- **Cursor theme:** Bibata-Modern-Classic / Catppuccin / system default?
- **Monitor(s):** how many, resolution(s), refresh rate(s)?
- **Keyboard layout?** (default: `us`)
- **Touchpad?** (yes/no — affects input config)

#### Group F — Visual style *(ask all at once; user can say "all defaults")*
- **Gaps:** inner (between windows) / outer (from screen edge)? *Common: 8/16 or 10/20; default: 5/20*
- **Border size:** pixels? *Rices commonly use 2–3; default: 1*
- **Corner rounding:** radius in px? *Rices commonly use 8–12; default: 0*
- **Blur:** disabled / subtle / moderate / heavy?
- **Shadows:** yes / no?
- **Window opacity:** fully opaque, or transparent inactive windows? *e.g. active 1.0, inactive 0.85*
- **Animation style:** minimal / balanced / fancy?

---

### Step 3: Generate the full config set

Produce **modular files** for each component. Use `source =` in `hyprland.conf` to link them. (Globbing works too: `source = ~/.config/hypr/conf.d/*.conf`)

#### Standard file layout

```
~/.config/hypr/
├── hyprland.conf          ← main entry — sources the below; holds general/decoration/input/misc/gestures
├── monitors.conf          ← monitor = lines
├── autostart.conf         ← exec-once = lines
├── env.conf               ← env = lines (omit if using uwsm — see below)
├── keybinds.conf          ← bind = lines
├── windowrules.conf       ← windowrule blocks
└── animations.conf        ← bezier = and animation = lines
hyprpaper.conf / hyprlock.conf / hypridle.conf  (in ~/.config/hypr/ if applicable)

~/.config/waybar/config.jsonc + style.css
~/.config/dunst/dunstrc  (or ~/.config/mako/config)
~/.config/wofi/config + style.css
~/.config/kitty/kitty.conf
install.sh
```

#### autostart.conf

Include what the user actually chose. Core lines for most setups:

```ini
exec-once = systemctl --user start hyprpolkitagent   # auth agent — always needed
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP  # screensharing
exec-once = waybar
exec-once = hyprpaper          # or: swww-daemon
exec-once = dunst              # or: mako / swaync
exec-once = hypridle
exec-once = nm-applet --indicator
exec-once = wl-paste --type text --watch cliphist store   # if using cliphist
exec-once = wl-paste --type image --watch cliphist store
exec-once = udiskie            # if auto-mounting USB
```

> The `dbus-update-activation-environment` line is not needed if using uwsm — it handles this automatically.

#### env.conf

> **uwsm users**: env vars go in `~/.config/uwsm/env` (format: `export KEY=VAL`) and `~/.config/uwsm/env-hyprland` for `HYPR*`/`AQ_*` vars. Skip generating env.conf and leave a comment in hyprland.conf.

```ini
env = XCURSOR_SIZE,24
env = XCURSOR_THEME,Bibata-Modern-Classic
env = QT_QPA_PLATFORM,wayland;xcb
env = QT_QPA_PLATFORMTHEME,qt5ct
env = QT_AUTO_SCREEN_SCALE_FACTOR,1
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = GDK_BACKEND,wayland,x11,*
env = SDL_VIDEODRIVER,wayland
env = CLUTTER_BACKEND,wayland
env = MOZ_ENABLE_WAYLAND,1
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland
env = XDG_CURRENT_DESKTOP,Hyprland
```

#### Visual style — translating Group F answers

**Blur** (`decoration:blur {}`):
- Subtle: `size = 4; passes = 2; noise = 0.02`
- Moderate: `size = 8; passes = 3; noise = 0.02`
- Heavy: `size = 12; passes = 4; noise = 0.01`

**Shadow** (`decoration:shadow {}`): `enabled = true; range = 20; render_power = 3` + theme accent color.

**Opacity**: `active_opacity` and `inactive_opacity` in `decoration {}`. Note these are multipliers — `0.9 × 0.9 = 0.81`. Use `override` in windowrules for exact values.

**Animation style presets:**
- Minimal: `animation = global, 1, 3, default`
- Balanced: `bezier = ease, 0.05, 0.9, 0.1, 1.05` + `animation = global, 1, 5, ease`
- Fancy: per-type animations (`popin` for windows, `slide` for workspaces) with overshoot bezier curves

---

### Step 4: Companion app configs

Generate configs that use the **same color palette throughout** — if Catppuccin Mocha, use it in waybar CSS, dunstrc, kitty.conf, wofi style.css, and hyprlock. This coherence is what separates a polished rice from a patchwork.

#### waybar
Generate `config.jsonc` + `style.css`. Include `hyprland/workspaces` (not `sway/workspaces`), `hyprland/window`, clock, tray, audio, network. In CSS: use `#workspaces button.active` (not `.focused`).

#### dunst / mako
- **dunst**: `dunstrc` with `[global]`, `[urgency_low/normal/critical]`. Match `corner_radius` to hyprland `rounding`.
- **mako**: `~/.config/mako/config` in plain `key=value` format.

#### wofi
`config` (size, mode, location) + `style.css` (themed to match).

#### kitty
`kitty.conf` with font, font size, opacity, all 16 terminal colors, cursor style.

#### hyprlock
Load `references/hyprlock.md`. Generate with `background {}` (blur or solid), `input-field {}`, and `label {}` blocks for clock/date. Match theme colors. **A config is required — without one, hyprlock locks but renders nothing.**

#### hypridle
Load `references/hypridle.md`. Generate with `general {}` block (`lock_cmd = loginctl lock-session`, `before_sleep_cmd`) and listeners: dim at ~2.5 min, lock at ~5 min, screen off at ~5.5 min, suspend at ~30 min (optional).

#### hyprpaper
Load `references/hyprpaper.md`. Use `wallpaper {}` block syntax with `fit_mode = cover`. Add a fallback block with empty monitor. For rotating wallpapers: set `path` to a directory, add `timeout = 300` and `order = random`.

---

### Step 5: install.sh

Detect package manager, install all chosen packages, copy configs to `~/.config/`, enable services (bluetooth, NetworkManager), print next steps. Tailor the package list strictly to what the user chose — don't install tools they said "none" to.

---

### Step 6: Validate before presenting

- **env vars**: `env = KEY,VALUE` — no space before value, no quotes
- **`exec-once` vs `exec`**: `exec-once` = startup only; `exec` = every config reload (using `exec` for daemons creates duplicates)
- **Shadow/blur are subcategories**: `decoration:shadow:enabled = true`, `decoration:blur:size = 8` — not flat `drop_shadow = true`
- **Gestures**: `workspace_swipe` vars are removed; use `gesture = 3, horizontal, workspace` instead
- **Window rules**: block syntax `windowrule { match:class = X; float = on }` or anonymous `windowrule = float on, match:class X`. The deprecated form is `windowrule = float, ^(class)$` (old regex syntax). `windowrulev2` no longer exists.
- **Opacity is multiplicative**: `decoration:active_opacity = 0.9` × windowrule `opacity 0.9` = 0.81. Use `opacity 0.9 override` for exact values.
- **Bool values**: only `true`/`false`, `yes`/`no`, `on`/`off`, `0`/`1`
- **Modifier syntax**: `SUPER`, `SUPER_SHIFT`, `CTRL_ALT` (underscores, no commas)
- **No `autogenerated = 1`** — delete it; it causes the file to be regenerated on update
- **waybar**: `hyprland/workspaces` not `sway/workspaces`; `button.active` not `button.focused`

---

## Common Patterns

### Keybinds

```ini
# Lock screen — always use loginctl, not hyprlock directly (lets hypridle hooks fire)
bind = SUPER, L, exec, loginctl lock-session

# Clipboard history
bind = SUPER, V, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy

# Screenshots
bind = , Print, exec, grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png
bind = SHIFT, Print, exec, grim -g "$(slurp)" ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png
bind = CTRL, Print, exec, grim -g "$(slurp)" - | wl-copy

# Brightness & media (bindel = repeat on hold)
bindel = , XF86MonBrightnessUp,   exec, brightnessctl set 5%+
bindel = , XF86MonBrightnessDown, exec, brightnessctl set 5%-
bindel = , XF86AudioRaiseVolume,  exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindel = , XF86AudioLowerVolume,  exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl  = , XF86AudioMute,         exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindl  = , XF86AudioPlay,         exec, playerctl play-pause
bindl  = , XF86AudioPrev,         exec, playerctl previous
bindl  = , XF86AudioNext,         exec, playerctl next

# Color temperature toggle (if using hyprsunset)
bind = SUPER, F9, exec, pkill hyprsunset || hyprsunset -t 4500
```

### Window rules

```ini
# Float + center common dialogs
windowrule { match:class = pavucontrol; float = on; center = on }
windowrule { match:class = nm-connection-editor; float = on; center = on }
windowrule { match:class = blueman-manager; float = on; center = on }
```

Named rules can be toggled at runtime without a reload: `hyprctl keyword 'windowrule[my-rule]:enable false'`

When writing rules for unfamiliar apps, run `hyprctl clients` first to see the actual `class` and `initialClass`.

### Layer rules (blur bars and launchers)

Waybar, wofi, and notification daemons are Wayland *layers*, not windows — blur them with `layerrule`:

```ini
layerrule = blur on, match:namespace waybar
layerrule = blur on, match:namespace wofi
layerrule = ignorezero on, match:namespace waybar
```

### Window swallowing

When launching a GUI app from a terminal, the terminal hides until the app closes:

```ini
misc {
  enable_swallow = true
  swallow_regex = ^(kitty|foot|alacritty|wezterm)$
}
```

### Display manager setup
- **SDDM**: enable `sddm.service`; set `DisplayServer=wayland` in `/etc/sddm.conf.d/10-wayland.conf`
- **greetd + tuigreet**: enable `greetd.service`; set `command = "Hyprland"` in `/etc/greetd/config.toml`
- **TTY**: add `[[ -z $WAYLAND_DISPLAY && $XDG_VTNR -eq 1 ]] && exec Hyprland` to `~/.bash_profile` or `~/.zprofile`

---

## Asking for more info

If the user says "update my config" without pasting it:
> "Could you paste your `~/.config/hypr/hyprland.conf` (or the relevant file)? That way I can make the change without overwriting your other settings."

If the user doesn't mention their distro when generating install.sh:
> "What distro are you on? I'll use the right package manager in install.sh."

For HiDPI cursor issues (inconsistent cursor size across apps), set cursor size in three places: `env = XCURSOR_SIZE,24`, `cursor:zoom_factor` in hyprland.conf, and via `nwg-look` or `gsettings` for GTK apps.
