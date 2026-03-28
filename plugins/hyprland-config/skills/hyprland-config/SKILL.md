---
name: hyprland-config
description: Use this skill whenever the user wants to set up, configure, or modify Hyprland — the Wayland compositor. This includes creating a full Hyprland environment from scratch, modifying an existing config, configuring companion apps (waybar, wofi, kitty, dunst, mako, hyprlock, hypridle, hyprpaper, swww), setting up monitors, keybindings, window rules, animations, decorations, layouts, workspace rules, and generating an install.sh. Trigger whenever the user mentions hyprland.conf, hyprctl, Hyprland settings, ricing, tiling on Wayland, or any Hyprland-specific topic like gaps, borders, blur, or animations. Also trigger when the user pastes a hyprland.conf snippet and asks for help. Always use this skill for any Hyprland-related configuration — even simple questions about a single keybind or option.
version: 3.1.0
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
| `references/ricing.md` | Decoration/blur/shadow details, animation presets, smart gaps, special workspaces, hyprlock widgets, swaync/rofi ricing, plugins, common mistakes |
| `references/theming.md` | GTK/Qt theming, icon themes, cursor consistency, fontconfig, pywal/wallust, ags/hyprpanel |

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
- **Status bar:** waybar / ags / hyprpanel / other / none?
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
- **Workspace overview plugin?** hyprexpo (macOS Exposé grid) / none?
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
- **Smart gaps?** (no gaps when only one window on workspace — very popular in rices) yes/no?
- **Special workspaces?** (toggle-able scratchpad overlays) yes/no? How many, and what for (terminal, notes, etc.)?

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

> **uwsm users**: env vars go in `~/.config/uwsm/env` (format: `export KEY=VAL`) and `~/.config/uwsm/env-hyprland` for `HYPR*`/`AQ_*` vars. Skip generating env.conf and leave a comment in hyprland.conf. **Quote values with special shell characters**: `export QT_QPA_PLATFORM='wayland;xcb'`, `export GDK_BACKEND='wayland,x11,*'` — unquoted semicolons and asterisks will be interpreted by the shell.

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

Load `references/ricing.md` now — it has complete values for decoration, animations, smart gaps, special workspaces, opacity rules, and layer rules.

Key summaries:
- **Blur**: match `size` and `passes` — subtle: 4/2, moderate: 8/3, heavy: 12/4. Set on `decoration:blur {}`.
- **Shadow**: `decoration:shadow { enabled = true; range = 20; render_power = 3; color = rgba(1a1a1abb) }`.
- **Gradient border**: `col.active_border = rgba(colorAff) rgba(colorBff) 45deg` — highest-impact single setting.
- **Opacity**: `active_opacity`/`inactive_opacity` in `decoration {}` are multipliers. Use `override` in windowrules for exact values.
- **Animation style**: see presets in `references/ricing.md` — minimal/balanced/fancy with bezier presets.
- **Smart gaps**: uses `workspace = w[tv1], gapsout:0, gapsin:0` — see `references/ricing.md`.
- **Special workspaces**: `togglespecialworkspace` + `movetoworkspacesilent` + `dim_special` — see `references/ricing.md`.

---

### Step 4: Companion app configs

Generate configs that use the **same color palette throughout** — if Catppuccin Mocha, use it in waybar CSS, dunstrc, kitty.conf, wofi style.css, and hyprlock. This coherence is what separates a polished rice from a patchwork.

#### waybar
Generate `config.jsonc` + `style.css`. Include `hyprland/workspaces` (not `sway/workspaces`), `hyprland/window`, clock, tray, audio, network. In CSS: use `#workspaces button.active` (not `.focused`).

#### dunst / mako / swaync
- **dunst**: `dunstrc` with `[global]`, `[urgency_low/normal/critical]`. Match `corner_radius` to hyprland `rounding`.
- **mako**: `~/.config/mako/config` in plain `key=value` format.
- **swaync**: `~/.config/swaync/config.json` (behavior) + `~/.config/swaync/style.css` (full CSS). Load `references/ricing.md` for the themed CSS template. Add `layerrule = blur true, match:namespace swaync-control-center` for frosted glass.

#### wofi / rofi / fuzzel
- **wofi**: `~/.config/wofi/config` + `~/.config/wofi/style.css`. Load `references/ricing.md` for CSS template.
- **rofi** (requires `rofi-wayland`): `~/.config/rofi/themes/NAME.rasi`. Load `references/ricing.md` for the `.rasi` skeleton.
- **fuzzel**: `~/.config/fuzzel/fuzzel.ini` — native Wayland blur without layerrules needed.

#### kitty
`kitty.conf` with font, font size, opacity, all 16 terminal colors, cursor style.

#### hyprlock
Load `references/hyprlock.md` and `references/ricing.md`. Generate with `background {}` (blurred screenshot is most popular), `input-field {}` (full color states: outer, inner, check, fail, capslock), and `label {}` blocks for clock/date. Optionally add `image {}` for profile picture and `shape {}` for decorative elements. Match all colors to the theme. Add `animations {}` block. **A config is required — without one, hyprlock locks but renders nothing.**

#### hypridle
Load `references/hypridle.md`. Generate with `general {}` block (`lock_cmd = loginctl lock-session`, `before_sleep_cmd`) and listeners: dim at ~2.5 min, lock at ~5 min, screen off at ~5.5 min, suspend at ~30 min (optional).

#### hyprpaper
Load `references/hyprpaper.md`. Use `wallpaper {}` block syntax with `fit_mode = cover`. Add a fallback block with empty monitor. For rotating wallpapers: set `path` to a directory, add `timeout = 300` and `order = random`.

#### GTK / Qt / icon / cursor theming
Load `references/theming.md`. For a complete rice, generate:
- `~/.config/gtk-3.0/settings.ini` and `~/.config/gtk-4.0/settings.ini` (theme, icons, cursor, font)
- env vars: `GTK_THEME`, `XCURSOR_THEME`, `XCURSOR_SIZE`, `QT_QPA_PLATFORMTHEME` (qt5ct), `HYPRCURSOR_THEME`
- `~/.icons/default/index.theme` (XWayland cursor fallback)
- Tell the user to run `nwg-look` after install to apply GTK settings, and `qt5ct` for Qt apps
- For Qt ricing beyond colors: mention Kvantum (`QT_STYLE_OVERRIDE=kvantum`)
- For font rendering: optionally generate `~/.config/fontconfig/fonts.conf`

#### ags / hyprpanel
If user chose ags or hyprpanel instead of waybar, load `references/theming.md` for notes. Note that ags requires TypeScript/JS knowledge; hyprpanel is preconfigured with a JSON palette. Provide install instructions but note that full ags config generation is beyond this skill's scope — suggest the user start from an existing ags config and customize it.

---

### Step 5: install.sh

Generate a robust install script with comprehensive error handling. Tailor the package list strictly to what the user chose — don't install tools they said "none" to.

**Required error handling:**
- **Pre-flight checks**: refuse to run as root, verify pacman exists, test sudo access, check internet connectivity, keep sudo session alive throughout.
- **AUR helper**: detect paru/yay. If neither is found, **auto-install yay** by cloning `yay-bin` from AUR and building with `makepkg -si`. Requires `base-devel` and `git`.
- **Package conflicts**: check for `xdg-desktop-portal-kde` (breaks screensharing), conflicting notification daemons. Prompt user before removing.
- **Package installation**: try batch install first (fast path). If batch fails, fall back to installing one-by-one to identify which packages failed. Track succeeded/failed separately.
- **AUR packages**: install individually (not batch) to isolate failures.
- **Display manager conflicts**: check if `/etc/systemd/system/display-manager.service` symlink exists. If it points to another DM (e.g., sddm), prompt to disable it before enabling greetd. **Never blindly `systemctl enable greetd`** — it will fail if another DM owns the symlink.
- **greetd config**: back up existing `/etc/greetd/config.toml` before overwriting.
- **uwsm env validation**: ensure `QT_QPA_PLATFORMTHEME=qt5ct` is set in `~/.config/uwsm/env`. Also export it for the current session so tools like `qt5ct` work immediately after install.
- **GTK settings**: detect actual installed theme/cursor/icon names by checking filesystem paths (e.g., `/usr/share/themes/catppuccin-mocha-mauve-standard+default`). Don't hardcode names that may not match the actual package contents.
- **Post-install verification**: check every binary exists with `command -v`, verify font with `fc-list : family | grep -qi`, verify cursor/GTK theme directories exist using glob patterns (e.g., `catppuccin-mocha-*-cursors`), verify `QT_QPA_PLATFORMTHEME` is set in uwsm env.
- **Summary**: color-coded output with separate sections for errors, warnings, skipped items, and missing commands.

**uwsm env file syntax**: values with special shell characters must be quoted: `export QT_QPA_PLATFORM='wayland;xcb'`, `export GDK_BACKEND='wayland,x11,*'`.

**Catppuccin package naming** (Arch AUR):
- GTK theme package: `catppuccin-gtk-theme-mocha` — installs themes as `catppuccin-mocha-{accent}-standard+default` (NOT `catppuccin-mocha-standard-{accent}-dark`)
- Cursor package: `catppuccin-cursors-mocha` — installs as `catppuccin-mocha-{accent}-cursors` (NOT `catppuccin-mocha-dark-cursors` unless using the generic dark variant)
- Always verify actual installed names by checking `/usr/share/themes/` and `/usr/share/icons/` after install.

---

### Step 6: Validate before presenting

**After every config change** — whether writing new files or editing existing ones — run `hyprctl configerrors` and show the output to the user. An empty response means the config parsed cleanly. If there are errors, fix them before presenting the final result. This applies to all Hyprland config files (`hyprland.conf`, `keybinds.conf`, `windowrules.conf`, etc.) — not companion app configs like `waybar/config.jsonc` or `dunstrc`.

- **env vars**: `env = KEY,VALUE` — no space before value, no quotes
- **`exec-once` vs `exec`**: `exec-once` = startup only; `exec` = every config reload (using `exec` for daemons creates duplicates)
- **Shadow/blur are subcategories**: `decoration:shadow:enabled = true`, `decoration:blur:size = 8` — not flat `drop_shadow = true`
- **Gestures**: `workspace_swipe` vars are removed; use `gesture = 3, horizontal, workspace` instead
- **Window rules**: block syntax requires multiline with `name =` as the first field — inline `windowrule { match:class = X; float = on }` does NOT work. Every block MUST have a unique `name`. The deprecated form is `windowrule = float, ^(class)$` (old regex syntax). `windowrulev2` no longer exists.
- **Opacity is multiplicative**: `decoration:active_opacity = 0.9` × windowrule `opacity 0.9` = 0.81. Use `opacity 0.9 override` for exact values.
- **Bool values**: only `true`/`false`, `yes`/`no`, `on`/`off`, `0`/`1`
- **Modifier syntax**: `SUPER`, `SUPER_SHIFT`, `CTRL_ALT` (underscores, no commas)
- **No `autogenerated = 1`** — delete it; it causes the file to be regenerated on update
- **waybar**: `hyprland/workspaces` not `sway/workspaces`; `button.active` not `button.focused`
- **Gradient borders**: `col.active_border = rgba(Aff) rgba(Bff) 45deg` — no spaces around values
- **`borderangle` style**: use `once`, never `loop` — loop renders at full refresh rate constantly
- **`layerrule = blur true`** required for bars/launchers — `decoration:blur` only affects windows. Use `blur true` NOT `blur on` (0.54+).
- **`ignorezero` / `ignorealpha`** — removed in Hyprland 0.54+. Do not use these layerrule fields; they cause config errors.
- **layerrule bool values** — use `true`/`false`, not `on`/`off` (unlike most Hyprland bools, layerrule fields are stricter).
- **xdg-desktop-portal**: only `xdg-desktop-portal-hyprland` + `xdg-desktop-portal-gtk`; remove `-kde`

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
# Float + center common dialogs — every block MUST have name = as first field
windowrule {
    name = float-pavucontrol
    match:class = pavucontrol
    float = on
    center = on
}
windowrule {
    name = float-nm-editor
    match:class = nm-connection-editor
    float = on
    center = on
}
windowrule {
    name = float-blueman
    match:class = blueman-manager
    float = on
    center = on
}
```

> **IMPORTANT**: Inline single-line block syntax (`windowrule { match:class = X; float = on }`) does NOT work. Always use multiline blocks with `name =` as the first field.

Named rules can be toggled at runtime without a reload: `hyprctl keyword 'windowrule[my-rule]:enable false'`

When writing rules for unfamiliar apps, run `hyprctl clients` first to see the actual `class` and `initialClass`.

### Smart gaps (no gaps when solo window)

```ini
workspace = w[tv1], gapsout:0, gapsin:0
workspace = f[1], gapsout:0, gapsin:0
windowrule = border_size 0, match:float 0, match:workspace w[tv1]
windowrule = rounding 0, match:float 0, match:workspace w[tv1]
```

### Special workspaces (scratchpads)

```ini
bind = SUPER, S, togglespecialworkspace, scratchpad
bind = SUPER_SHIFT, S, movetoworkspacesilent, special:scratchpad
# Auto-launch on startup
exec-once = [workspace special:terminal silent] kitty
```

Animate with `animation = specialWorkspace, 1, 6, myBezier, slidevert` and dim the background via `decoration { dim_special = 0.3 }`.

### Layer rules (blur bars and launchers)

Waybar, wofi, and notification daemons are Wayland *layers*, not windows — blur them with `layerrule`:

```ini
layerrule = blur true, match:namespace waybar
layerrule = blur true, match:namespace wofi
layerrule = blur true, match:namespace rofi
layerrule = blur true, match:namespace notifications
layerrule = blur true, match:namespace swaync-control-center
```

> **IMPORTANT (0.54+)**: `ignorezero` and `ignorealpha` are removed as layerrule field types. `blur on` syntax is also invalid — use `blur true`. Always test layerrules with `hyprctl keyword layerrule "..."` to verify syntax.

Find a layer's namespace: `hyprctl layers`

### Window swallowing

When launching a GUI app from a terminal, the terminal hides until the app closes:

```ini
misc {
  enable_swallow = true
  swallow_regex = ^(kitty|foot|alacritty|wezterm)$
}
```

### Display manager setup

> **CRITICAL**: Only one display manager can own `/etc/systemd/system/display-manager.service`. Always check for and disable existing DMs before enabling a new one.

- **SDDM**: enable `sddm.service`; set `DisplayServer=wayland` in `/etc/sddm.conf.d/10-wayland.conf`
- **greetd + tuigreet**: check for existing DM first (`readlink /etc/systemd/system/display-manager.service`), disable it, then enable `greetd.service`. For uwsm: `command = "tuigreet --time --remember --remember-session --asterisks --cmd 'uwsm start hyprland-uwsm.desktop'"` in `/etc/greetd/config.toml`.
- **TTY**: add `[[ -z $WAYLAND_DISPLAY && $XDG_VTNR -eq 1 ]] && exec Hyprland` to `~/.bash_profile` or `~/.zprofile`

---

## Asking for more info

If the user says "update my config" without pasting it:
> "Could you paste your `~/.config/hypr/hyprland.conf` (or the relevant file)? That way I can make the change without overwriting your other settings."

If the user doesn't mention their distro when generating install.sh:
> "What distro are you on? I'll use the right package manager in install.sh."

For HiDPI cursor issues (inconsistent cursor size across apps), set cursor size in three places: `env = XCURSOR_SIZE,24`, `cursor:zoom_factor` in hyprland.conf, and via `nwg-look` or `gsettings` for GTK apps.
