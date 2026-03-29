---
name: hyprland-config
description: Use this skill whenever the user wants to set up, configure, or modify Hyprland — the Wayland compositor. This includes creating a full Hyprland environment from scratch, modifying an existing config, configuring companion apps (waybar, wofi, rofi, fuzzel, anyrun, kitty, dunst, mako, swaync, hyprlock, hypridle, hyprpaper, swww, wlogout), setting up monitors, keybindings, window rules, animations, decorations, layouts, workspace rules, and generating an install.sh. Trigger whenever the user mentions hyprland.conf, hyprctl, Hyprland settings, ricing, tiling on Wayland, or any Hyprland-specific topic like gaps, borders, blur, or animations. Also trigger when the user pastes a hyprland.conf snippet and asks for help. Always use this skill for any Hyprland-related configuration — even simple questions about a single keybind or option.
version: 3.2.0
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
| `references/waybar.md` | Waybar config.jsonc structure, CSS styling patterns, Hyprland modules, design patterns (floating pill, color-blocked, minimal), custom modules, complete examples |
| `references/ricing.md` | Decoration/blur/shadow details, animation presets, smart gaps, special workspaces, hyprlock widgets, swaync/rofi ricing, plugins, common mistakes |
| `references/theming.md` | GTK/Qt theming, icon themes, cursor consistency, fontconfig, pywal/wallust, ags/hyprpanel |
| `references/shell.md` | Shell choice (bash/zsh/fish), prompt theming (starship/p10k), plugins, CLI utilities, aliases, color integration |
| `references/notifications.md` | dunst, mako, swaync — full config format, theming, per-app rules, Hyprland layer rules, waybar integration |
| `references/launchers.md` | wofi, rofi-wayland, fuzzel, anyrun — full config format, CSS/RASI/INI theming, clipboard integration, Hyprland keybinds |
| `references/wlogout.md` | wlogout logout menu — layout JSON, CSS theming, custom icons, waybar power button, launch options |
| `references/swww.md` | swww animated wallpaper daemon — transitions, GIF support, cycling scripts, per-monitor setup, vs hyprpaper comparison |

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
- **Logout menu?** wlogout (graphical fullscreen overlay) / none (keybind-only)?
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
- **Bar style:** floating pills (rounded modules floating above desktop — most popular) / solid bar (traditional flat bar) / color-blocked (each module gets its own bold color) / minimal (subtle, icon-only)? *Default: floating pills*
- **Gaps:** inner (between windows) / outer (from screen edge)? *Common: 8/16 or 10/20; default: 5/20*
- **Border size:** pixels? *Rices commonly use 2–3; default: 1*
- **Corner rounding:** radius in px? *Rices commonly use 8–12; default: 0*
- **Blur:** disabled / subtle / moderate / heavy?
- **Shadows:** yes / no?
- **Window opacity:** fully opaque, or transparent inactive windows? *e.g. active 1.0, inactive 0.85*
- **Animation style:** minimal / balanced / fancy?
- **Smart gaps?** (no gaps when only one window on workspace — very popular in rices) yes/no?
- **Special workspaces?** (toggle-able scratchpad overlays) yes/no? How many, and what for (terminal, notes, etc.)?

#### Group G — Keybind preferences *(ask all at once; user can say "defaults" or "i3-like")*
- **Keybind style?** i3/sway-like (most common) / vim-centric (hjkl everything) / Windows/GNOME-familiar / custom?
  - *i3-like*: SUPER+Return=terminal, SUPER+D=launcher, SUPER+SHIFT+Q=kill, SUPER+1-0=workspaces — the community standard
  - *vim-centric*: hjkl for all directional actions, minimal arrow key use, resize/launch submaps
  - *Windows/GNOME-familiar*: SUPER+E=files, ALT+F4=close, ALT+Tab=cycle, SUPER alone opens launcher
- **Primary modifier?** SUPER (recommended — avoids app conflicts) / ALT / other? *Default: `$mainMod = SUPER`*
- **Directional navigation?** arrow keys / hjkl / both? *Default: both — costs nothing and accommodates muscle memory from either background*
- **Window close bind?** SUPER+Q / SUPER+C / SUPER+SHIFT+Q / SUPER+SHIFT+C? *i3 tradition: SUPER+SHIFT+Q; Hyprland default example: SUPER+C*
- **Terminal launch bind?** SUPER+Return (i3/sway tradition, most popular) / SUPER+T (GNOME-like) / SUPER+Q (Hyprland example default)?
- **Resize mode?** submap (enter resize mode with SUPER+R, use arrows/hjkl, Escape to exit) / hold modifier (SUPER+CTRL+arrows) / mouse only (SUPER+RMB drag)? *Default: submap + mouse drag — submap is the most popular community pattern*
- **Include submaps?** Which ones? resize (most common) / launch (single-key app shortcuts) / power/session (l=lock, e=logout, s=suspend, r=reboot, p=poweroff) / screenshot (f=fullscreen, s=select, w=window)? *Default: resize only*
- **Number of workspaces?** 10 (SUPER+1 through SUPER+0, most common) / fewer / more? *Beyond 10 requires F-keys or other binds*
- **Extra workspace navigation?** mouse scroll through workspaces (SUPER+scroll) / next-prev keys (SUPER+Tab) / both? *Default: both*
- **Bind descriptions?** Use `bindd` flag so keybinds are queryable with `hyprctl binds` and cheatsheet tools? yes/no? *Default: yes — negligible cost, useful for discoverability*

> **Shorthand answers**: If the user says "i3-like", use: SUPER mod, both arrows+hjkl, SUPER+SHIFT+Q to kill, SUPER+Return for terminal, resize submap, 10 workspaces with mouse scroll, bind descriptions on. If they say "defaults" or don't have a preference, use the same i3-like defaults — it's what most Hyprland users expect.

#### Group H — Shell configuration *(ask all at once; user can say "defaults" or "skip")*
- **Shell:** bash (system default) / zsh (most popular for ricing) / fish (best out-of-box UX) / keep current?
- **Shell prompt:** starship (cross-shell, fast, recommended) / powerlevel10k (zsh only, wizard-configured) / oh-my-posh / plain default?
- **Shell plugins?** For zsh: syntax highlighting + autosuggestions + completions (via system packages or zinit)? For fish: fisher + fzf plugin? For bash: ble.sh? Or skip?
- **Modern CLI utilities?** eza (ls) / bat (cat) / fd (find) / ripgrep (grep) / fzf (fuzzy finder) / zoxide (cd) / fastfetch / btop — install all / pick some / skip?
- **Shell aliases?** Generate aliases for installed CLI utilities + Hyprland convenience shortcuts? yes/no?

> **Shorthand answers**: If the user says "defaults", use: zsh + starship + system-packaged plugins (syntax highlighting, autosuggestions, completions) + all CLI utilities + aliases. If they say "skip", don't generate any shell config. If they say "fish", use: fish + starship + fisher with fzf plugin + all CLI utilities + fish abbreviations.

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
~/.config/dunst/dunstrc  (or ~/.config/mako/config  or ~/.config/swaync/{config.json,style.css})
~/.config/wofi/config + style.css  (or ~/.config/rofi/{config.rasi,themes/}  or ~/.config/fuzzel/fuzzel.ini)
~/.config/wlogout/layout + style.css  (if using wlogout)
~/.config/kitty/kitty.conf
~/.config/starship.toml  (if using starship)
~/.zshrc / ~/.config/fish/config.fish  (if shell config requested)
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

#### Keybinds — translating Group G answers

Load `references/keybinds.md` and `references/dispatchers.md` now. Generate `keybinds.conf` tailored to the user's chosen style. Always define `$mainMod` as a variable at the top so users can change their modifier in one place.

**Core structure** — every keybinds.conf needs these sections:

1. **Modifier variable**: `$mainMod = SUPER` (or user's choice)
2. **App launches**: terminal, launcher, file manager, browser — use the apps chosen in Group B/D
3. **Window management**: kill, float toggle, fullscreen, pseudo-tile, split toggle
4. **Focus navigation**: directional focus (arrows and/or hjkl based on Group G answer)
5. **Window movement**: move windows directionally (SHIFT layer of focus binds)
6. **Workspace switching**: `$mainMod + 1-0` for workspaces 1-10
7. **Window-to-workspace**: `$mainMod + SHIFT + 1-0`
8. **Mouse binds**: `$mainMod + LMB` = move, `$mainMod + RMB` = resize
9. **Media/brightness keys**: always include with `el` flags (repeat + locked)
10. **Screenshots**: based on chosen tool (grimblast/hyprshot/grim+slurp)
11. **Utility binds**: lock screen, clipboard history, color temperature toggle
12. **Submaps**: based on user's Group G submap choices

**Style presets** — map the user's keybind style answer to concrete binds:

*i3/sway-like (default):*
```ini
$mainMod = SUPER
bindd = $mainMod, Return, Launch terminal, exec, $terminal
bindd = $mainMod, D, Open app launcher, exec, $menu
bindd = $mainMod_SHIFT, Q, Close active window, killactive
bindd = $mainMod_SHIFT, E, Exit Hyprland, exit
bindd = $mainMod, V, Toggle floating, togglefloating
bindd = $mainMod, F, Toggle fullscreen, fullscreen, 0
bindd = $mainMod, P, Pseudo-tile, pseudo
# Focus: both arrows + hjkl
bindd = $mainMod, H, Focus left, movefocus, l
bindd = $mainMod, L, Focus right, movefocus, r
bindd = $mainMod, K, Focus up, movefocus, u
bindd = $mainMod, J, Focus down, movefocus, d
bindd = $mainMod, left, Focus left, movefocus, l
bindd = $mainMod, right, Focus right, movefocus, r
bindd = $mainMod, up, Focus up, movefocus, u
bindd = $mainMod, down, Focus down, movefocus, d
# Move: SHIFT layer
bindd = $mainMod_SHIFT, H, Move window left, movewindow, l
bindd = $mainMod_SHIFT, L, Move window right, movewindow, r
bindd = $mainMod_SHIFT, K, Move window up, movewindow, u
bindd = $mainMod_SHIFT, J, Move window down, movewindow, d
```

*vim-centric:* Same as i3-like but omit arrow key duplicates, add more submaps (resize, launch), and use hjkl exclusively.

*Windows/GNOME-familiar:*
```ini
$mainMod = SUPER
bindd = $mainMod, T, Launch terminal, exec, $terminal
bindd = $mainMod, E, Open file manager, exec, $fileManager
bindd = ALT, F4, Close active window, killactive
bindd = $mainMod, Tab, Cycle windows, cyclenext
# SUPER alone to open launcher (release bind):
bindr = SUPER, SUPER_L, exec, $menu
```

**Submaps** — generate based on user's choices:

*Resize submap (most popular):*
```ini
bindd = $mainMod, R, Enter resize mode, submap, resize
submap = resize
binded = , right, Grow right, resizeactive, 30 0
binded = , left, Shrink right, resizeactive, -30 0
binded = , up, Shrink down, resizeactive, 0 -30
binded = , down, Grow down, resizeactive, 0 30
binded = , L, Grow right, resizeactive, 30 0
binded = , H, Shrink right, resizeactive, -30 0
binded = , K, Shrink down, resizeactive, 0 -30
binded = , J, Grow down, resizeactive, 0 30
bindd = , escape, Exit resize mode, submap, reset
bindd = , Return, Exit resize mode, submap, reset
submap = reset
```

*Power/session submap:*
```ini
bindd = $mainMod, Escape, Enter power menu, submap, power
submap = power
bindd = , L, Lock screen, exec, loginctl lock-session
bind = , L, submap, reset
bindd = , E, Logout, exit
bindd = , S, Suspend, exec, systemctl suspend
bind = , S, submap, reset
bindd = , R, Reboot, exec, systemctl reboot
bindd = , P, Power off, exec, systemctl poweroff
bindd = , escape, Cancel, submap, reset
submap = reset
```

*Launch submap (single-key app shortcuts):*
```ini
bindd = $mainMod, Space, Enter launch mode, submap, launch
submap = launch
bindd = , F, Launch browser, exec, firefox
bind = , F, submap, reset
bindd = , T, Launch terminal, exec, $terminal
bind = , T, submap, reset
bindd = , E, Launch file manager, exec, $fileManager
bind = , E, submap, reset
bindd = , escape, Cancel, submap, reset
submap = reset
```

**Use `bindd` (description flag) by default** — it makes keybinds queryable with `hyprctl binds` and enables cheatsheet tools. The only cost is a slightly longer line; the discoverability benefit is significant.

---

### Step 4: Companion app configs

Generate configs that use the **same color palette throughout** — if Catppuccin Mocha, use it in waybar CSS, dunstrc, kitty.conf, wofi style.css, and hyprlock. This coherence is what separates a polished rice from a patchwork.

#### waybar
Load `references/waybar.md` for comprehensive guidance. Generate `config.jsonc` + `style.css`.

Key rules:
- Use `hyprland/workspaces` (never `sway/workspaces`) and `hyprland/window`
- In CSS: `#workspaces button.active` (not `.focused`)
- Use `@define-color` at the top of `style.css` to define the full color palette — every module should reference these colors for consistency
- Always include: workspaces, window title, clock, tray, audio (pulseaudio or wireplumber), network. Add battery + backlight for laptops. Add `hyprland/submap` when the user has submaps configured — it shows which mode is active (resize, power, etc.) and prevents confusion
- Default to the **floating pill bar** style (transparent `window#waybar`, rounded `.modules-left/center/right` containers, `margin-top/left/right` for floating effect) — this is the most popular community pattern and looks significantly more polished than a flat solid bar
- Include `"reload_style_on_change": true` so users can iterate on CSS without restarting
- Set `"margin-top": 6, "margin-left": 8, "margin-right": 8` for the floating effect
- Use Nerd Font icons for every module (not plain text labels). **Nerd Font icon stripping pitfall**: When generating or editing waybar configs, Nerd Font glyphs (U+E000–U+F8FF, U+F0000–U+10FFFF) can silently be stripped or replaced with zero-width characters during copy-paste, file transfer, or encoding issues. If a user reports missing icons but the config looks correct, check the actual Unicode codepoints in the format strings — they may be empty. After writing any waybar config containing Nerd Font icons, verify the icons survived by checking for non-ASCII characters in the file (e.g., `python3 -c "for c in open('config.jsonc').read(): ..."`). If icons are missing, re-insert them using explicit Nerd Font codepoints (e.g., `󰥔` for clock, `󰤨` for wifi, `󰕾` for volume)
- Add hover effects and state-based styling (battery warning/critical, network disconnected, audio muted)
- Include a power button module (`custom/power`) with wlogout or a simple menu

The bar is one of the most visible parts of a rice — a flat, unstyled bar with plain text labels immediately looks unfinished. The difference between a good and great config is in the CSS: rounded corners, consistent color-coded icons, smooth transitions, and proper spacing.

#### dunst / mako / swaync
Load `references/notifications.md` for complete config formats, theming examples, and Hyprland integration (layer rules, waybar buttons).
- **dunst**: `~/.config/dunst/dunstrc` — INI format with `[global]`, `[urgency_low/normal/critical]`, custom `[rule]` sections. Match `corner_radius` to hyprland `rounding`. Colors in `"#RRGGBB"` or `"#RRGGBBAA"` (quotes required).
- **mako**: `~/.config/mako/config` — key=value format. Criteria sections `[app-name=X]` for per-app styling. Colors in `#RRGGBBAA` (no quotes).
- **swaync**: `~/.config/swaync/config.json` (behavior + widgets) + `~/.config/swaync/style.css` (full GTK CSS). Most feature-rich — has notification center panel, mpris media controls, buttons grid, DND toggle. Add `layerrule = blur true, match:namespace swaync-control-center` for frosted glass.

Only one notification daemon should run — they conflict on the D-Bus notification interface.

#### wofi / rofi / fuzzel / anyrun
Load `references/launchers.md` for complete config formats, theming examples, and Hyprland integration (keybinds, layer rules, clipboard history).
- **wofi**: `~/.config/wofi/config` + `~/.config/wofi/style.css` (GTK CSS). Good enough but unmaintained.
- **rofi** (requires `rofi-wayland`): `~/.config/rofi/config.rasi` + theme files in RASI format. Most powerful theming — full layout control with CSS-like widget hierarchy. Theme files go in `~/.config/rofi/themes/`.
- **fuzzel**: `~/.config/fuzzel/fuzzel.ini` — INI format, colors are `RRGGBBAA` (no `#` prefix). Lightest option, no GTK dependency, well-maintained. Theme via config options only.
- **anyrun**: `~/.config/anyrun/config.ron` (RON format) + `~/.config/anyrun/style.css` (GTK4 CSS). Plugin-based architecture — each search mode is a .so file. Supports calculator, translation, symbols out of the box.

#### wlogout
Load `references/wlogout.md` for complete layout format, CSS theming, and launch options. Generate if the user chose wlogout in Group D:
- `~/.config/wlogout/layout` — JSON array of button objects (label, action, text, keybind)
- `~/.config/wlogout/style.css` — GTK CSS with per-button icon and hover color styling
- Use `loginctl lock-session` for lock (not `hyprlock` directly), `hyprctl dispatch exit` for logout (or `uwsm stop` if using uwsm)
- Add a waybar power button module pointing to wlogout

#### kitty
`kitty.conf` with font, font size, opacity, all 16 terminal colors, cursor style.

**Opacity stacking pitfall**: If Hyprland's `active_opacity` is < 1.0 AND kitty's `background_opacity` is < 1.0, they multiply (e.g., 0.92 × 0.92 = 0.85). To avoid this, set kitty `background_opacity = 1.0` and control opacity entirely through Hyprland window rules with `override`:
```ini
windowrule {
    name = opacity-kitty
    match:class = kitty
    opacity = 0.92 override 0.78 override
}
```

**Shell directive**: If the user is switching to a non-default shell (fish, zsh), add `shell /usr/bin/fish` (or `/usr/bin/zsh`) to `kitty.conf` so it takes effect immediately without waiting for `chsh` + re-login.

#### hyprlock
Load `references/hyprlock.md` and `references/ricing.md`. Generate with `background {}` (blurred screenshot is most popular), `input-field {}` (full color states: outer, inner, check, fail, capslock), and `label {}` blocks for clock/date. Optionally add `image {}` for profile picture and `shape {}` for decorative elements. Match all colors to the theme. Add `animations {}` block. **A config is required — without one, hyprlock locks but renders nothing.**

#### hypridle
Load `references/hypridle.md`. Generate with `general {}` block (`lock_cmd = loginctl lock-session`, `before_sleep_cmd`) and listeners: dim at ~2.5 min, lock at ~5 min, screen off at ~5.5 min, suspend at ~30 min (optional).

#### hyprpaper / swww
If the user chose **hyprpaper**: Load `references/hyprpaper.md`. Use `wallpaper {}` block syntax with `fit_mode = cover`. Add a fallback block with empty monitor. For rotating wallpapers: set `path` to a directory, add `timeout = 300` and `order = random`.

If the user chose **swww**: Load `references/swww.md`. No config file — all options are CLI flags. Generate autostart line (`exec-once = swww-daemon && swww img ~/Pictures/wallpaper.png`), optionally generate a wallpaper cycling script (`~/.config/hypr/scripts/wallpaper-cycle.sh`) and a keybind for random wallpaper. Key selling point: animated transitions (`--transition-type fade/wipe/wave/grow`). Only one wallpaper daemon should run — don't autostart both.

#### GTK / Qt / icon / cursor theming
Load `references/theming.md`. For a complete rice, generate:
- `~/.config/gtk-3.0/settings.ini` and `~/.config/gtk-4.0/settings.ini` (theme, icons, cursor, font)
- env vars: `GTK_THEME`, `XCURSOR_THEME`, `XCURSOR_SIZE`, `QT_QPA_PLATFORMTHEME` (qt5ct), `HYPRCURSOR_THEME`
- `~/.icons/default/index.theme` (XWayland cursor fallback)
- Tell the user to run `nwg-look` after install to apply GTK settings, and `qt5ct` for Qt apps
- For Qt ricing beyond colors: mention Kvantum (`QT_STYLE_OVERRIDE=kvantum`)
- For font rendering: optionally generate `~/.config/fontconfig/fonts.conf`

#### Shell configuration
Load `references/shell.md` now. Generate shell config based on Group H answers:

- **Shell rc file**: Generate `.zshrc`, `config.fish`, or additions to `.bashrc` depending on chosen shell. Include: prompt initialization, plugin sourcing, tool initialization (zoxide, fzf), and aliases/abbreviations for installed CLI utilities.
- **Starship config**: If using starship, generate `~/.config/starship.toml` with a theme-matched palette (e.g., Catppuccin Mocha colors) and Nerd Font symbols. Use the same font the user chose in Group E.
- **Powerlevel10k**: If using p10k, add the source line to `.zshrc` and tell the user to run `p10k configure` after install — the wizard generates `~/.p10k.zsh` interactively.
- **Plugin setup**: For zsh with system packages, add `source` lines for syntax highlighting + autosuggestions. For zsh with zinit, generate the zinit block. For fish with fisher, add fisher install commands to `install.sh`.
- **CLI utilities**: Add initialization lines for zoxide and fzf to the shell rc. Generate aliases (bash/zsh) or abbreviations (fish) only for tools the user chose to install.
- **TTY launch line**: If the user chose no display manager, add the Hyprland auto-start line to the correct login profile for their shell (`.bash_profile`, `.zprofile`, or `config.fish`). Use uwsm variant if applicable. **Do NOT generate TTY launch lines if the user chose greetd or SDDM** — the display manager handles session launch, and having both creates a conflict where the TTY line tries to start Hyprland before greetd does.
- **Default shell change**: Add `chsh -s /usr/bin/zsh` (or fish) to `install.sh` if the user chose a non-default shell. Include a comment that re-login is required.
- **Fastfetch**: If installed, optionally add `fastfetch` to the end of the shell rc so it displays system info on terminal launch. Ask the user if they want this — some find it annoying on every new terminal.

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
- **Plugin config options**: Plugin options change between versions and invalid options cause parse errors. Only use options documented in `references/ricing.md` — do not guess or invent plugin options. Specifically: hyprexpo has NO gesture-related options (`enable_gesture`, `gesture_fingers`, `gesture_distance`, `gesture_positive` are all invalid); hyprbars has NO per-window `plugin:hyprbars:nobar` windowrule field. If a plugin failed to build, do NOT include its `plugin {}` config block.
- **hyprpm build dependencies**: hyprpm requires `cmake`, `cpio`, `pkg-config`, `git`, `gcc`. If `hyprpm update` fails with "Missing dependency", install them first (Arch: `sudo pacman -S cmake cpio`).

---

## Common Patterns

### Utility keybinds (always include regardless of style)

These complement the style-specific binds generated from Group G. Always include them in `keybinds.conf`:

```ini
# Lock screen — always use loginctl, not hyprlock directly (lets hypridle hooks fire)
bindd = $mainMod, L, Lock screen, exec, loginctl lock-session

# Clipboard history (if using cliphist — substitute rofi/fuzzel for wofi as needed)
bindd = $mainMod, V, Clipboard history, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy

# Screenshots (grim+slurp — substitute grimblast/hyprshot based on Group D choice)
bindd = , Print, Screenshot full screen, exec, grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png
bindd = SHIFT, Print, Screenshot region, exec, grim -g "$(slurp)" ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png
bindd = CTRL, Print, Screenshot region to clipboard, exec, grim -g "$(slurp)" - | wl-copy

# Brightness & media (el = repeat on hold + works on lockscreen)
bindeld = , XF86MonBrightnessUp,   Brightness up, exec, brightnessctl set 5%+
bindeld = , XF86MonBrightnessDown, Brightness down, exec, brightnessctl set 5%-
bindeld = , XF86AudioRaiseVolume,  Volume up, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindeld = , XF86AudioLowerVolume,  Volume down, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindld  = , XF86AudioMute,         Toggle mute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindld  = , XF86AudioPlay,         Play/pause, exec, playerctl play-pause
bindld  = , XF86AudioPrev,         Previous track, exec, playerctl previous
bindld  = , XF86AudioNext,         Next track, exec, playerctl next

# Color temperature toggle (if using hyprsunset)
bindd = $mainMod, F9, Toggle night light, exec, pkill hyprsunset || hyprsunset -t 4500

# Mouse binds — move and resize floating windows
bindmd = $mainMod, mouse:272, Move window, movewindow
bindmd = $mainMod, mouse:273, Resize window, resizewindow

# Workspace scroll
bindd = $mainMod, mouse_down, Next workspace, workspace, e+1
bindd = $mainMod, mouse_up, Previous workspace, workspace, e-1
```

### Opacity overrides for media (when using global opacity < 1.0)

When `active_opacity` or `inactive_opacity` is below 1.0, browsers, video players, games, and fullscreen apps will appear semi-transparent. Always generate these overrides:

```ini
windowrule {
    name = opaque-firefox
    match:class = firefox
    opaque = on
}
windowrule {
    name = opaque-chromium
    match:class = (chromium|google-chrome|brave-browser)
    opaque = on
}
windowrule {
    name = opaque-steam
    match:class = steam
    opaque = on
}
windowrule {
    name = opaque-fullscreen
    match:fullscreen = true
    opaque = on
}
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
- **TTY**: auto-start line depends on the user's shell — see `references/shell.md` TTY Launch Lines section. Bash: `~/.bash_profile`, Zsh: `~/.zprofile`, Fish: `~/.config/fish/config.fish`

---

## Asking for more info

If the user says "update my config" without pasting it:
> "Could you paste your `~/.config/hypr/hyprland.conf` (or the relevant file)? That way I can make the change without overwriting your other settings."

If the user doesn't mention their distro when generating install.sh:
> "What distro are you on? I'll use the right package manager in install.sh."

For HiDPI cursor issues (inconsistent cursor size across apps), set cursor size in three places: `env = XCURSOR_SIZE,24`, `cursor:zoom_factor` in hyprland.conf, and via `nwg-look` or `gsettings` for GTK apps.
