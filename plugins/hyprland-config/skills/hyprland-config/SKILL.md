---
name: hyprland-config
description: Use this skill whenever the user wants to set up, configure, or modify Hyprland — the Wayland compositor. This includes creating a full Hyprland environment from scratch, modifying an existing config, configuring companion apps (waybar, wofi, rofi, fuzzel, anyrun, kitty, dunst, mako, swaync, hyprlock, hypridle, hyprpaper, swww, wlogout), setting up monitors, keybindings, window rules, animations, decorations, layouts, workspace rules, generating an install.sh, and setting up a dotfiles repository with GNU Stow for config backup/sharing/reuse across machines. Trigger whenever the user mentions hyprland.conf, hyprctl, Hyprland settings, ricing, tiling on Wayland, dotfiles repo for Hyprland, stow + hyprland, or any Hyprland-specific topic like gaps, borders, blur, or animations. Also trigger when the user pastes a hyprland.conf snippet and asks for help. Always use this skill for any Hyprland-related configuration — even simple questions about a single keybind or option.
version: 3.3.0
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
| `references/ags.md` | AGS (Aylur's GTK Shell) — full TypeScript/JSX shell framework: project structure, reactivity, all Astal library APIs, widget types, CSS theming, complete component examples (bar, notifications, launcher, OSD, quick settings, media player, power menu), multi-monitor, HyprPanel |
| `references/firefox.md` | Firefox userChrome.css/userContent.css theming — floating tabs, transparent toolbar, auto-hide bookmarks, Catppuccin/themed new tab page, sidebar styling, compact density, user.js setup |
| `references/dotfiles.md` | Dotfile management with Git + GNU Stow — repo structure, stow commands, machine-specific configs, bootstrap scripts, adopting existing configs, secrets handling |

---

## Workflow

### Step 1: Identify the request type

**A. Full setup from scratch** → Run the full interview (Step 2), then generate everything.

**B. Modifying an existing config** → Ask for the relevant file(s) if not pasted. Read before editing. Make minimal targeted changes.

**C. Targeted question** (e.g., "how do I bind SUPER+T to kitty?") → Answer directly with the correct snippet. Load only the relevant reference.

**D. Dotfiles repo setup** → The user wants to store their Hyprland configs in a git repo with GNU Stow. This can be combined with A (generate everything into a dotfiles repo) or standalone (restructure existing configs into a stow-managed repo). Load `references/dotfiles.md` and follow Step 5c.

---

### Step 2: The User Interview (for new setups)

Read `references/packages.md` now. The interview is the most important part of generating a config that actually fits the user. Rushing through it produces generic configs that feel impersonal.

#### How to present questions

Use the `AskUserQuestion` tool for all interview questions. This lets the user click choices instead of typing out answers — faster and less tedious. Each call supports 1-4 questions with 2-4 selectable options each. Every question automatically gets an "Other" option for custom input. Use `multiSelect: true` when choices aren't mutually exclusive. Mark recommended options by putting "(Recommended)" at the end of the label.

**Pacing:** Present 3-4 related questions per `AskUserQuestion` call. After each batch of answers, acknowledge choices and ask follow-up questions (as text or additional `AskUserQuestion` calls) before moving to the next batch. If an answer is ambiguous or interesting, ask a follow-up before moving on. The goal is a conversation, not a form.

If the user's opening message already answers some questions (e.g., "catppuccin mocha, kitty, arch linux"), extract those answers and skip those questions. But still ask follow-up questions about things they mentioned — "you said kitty — do you want any specific kitty config (opacity, font size, shell override)?" shows you're paying attention.

#### Batch 1 — System basics

Ask these 4 questions together with `AskUserQuestion`:

| Header | Question | Options | Multi? |
|--------|----------|---------|--------|
| Distro | What distro are you on? (affects package names in install.sh) | `Arch/AUR`, `Fedora`, `openSUSE`, `Debian/Ubuntu` | no |
| Setup | Starting fresh or modifying an existing config? | `Fresh install`, `Existing ~/.config/hypr/` | no |
| Device | Desktop or laptop? (affects battery, backlight, touchpad, lid switch) | `Desktop`, `Laptop` | no |
| Use case | Primary use case? (helps prioritize window rules and keybinds) | `Development`, `Gaming`, `Creative work`, `General use` | no |

#### Batch 2 — Dotfiles + Core tools

| Header | Question | Options | Multi? |
|--------|----------|---------|--------|
| Dotfiles | Store configs in a git repo with GNU Stow for backup/sharing/reuse? | `Yes — ~/dotfiles/ with stow`, `No — write directly to ~/.config/` | no |
| Terminal | Which terminal? | `kitty`, `alacritty`, `foot`, `wezterm` | no |
| Launcher | App launcher? | `wofi`, `rofi-wayland`, `fuzzel`, `tofi` | no |
| Bar | Status bar? | `waybar (JSON config, easiest)`, `ags (TypeScript, most powerful)`, `hyprpanel (pre-built AGS, minimal config)`, `None` | no |

#### Batch 3 — Notifications + Hypr ecosystem

| Header | Question | Options | Multi? |
|--------|----------|---------|--------|
| Notify | Notification daemon? | `dunst`, `mako`, `swaync`, `ags (if using ags as shell)` | no |
| Wallpaper | Wallpaper tool? | `hyprpaper (static)`, `swww (animated transitions)`, `None` | no |
| Lock | Screen locker? | `hyprlock (Recommended)`, `swaylock`, `None` | no |
| Idle | Idle daemon? | `hypridle (Recommended)`, `swayidle`, `None` | no |

**Follow-ups** — ask these as text or additional `AskUserQuestion` calls based on Batch 2-3 answers. Ask before moving to the next batch:

*If waybar:* "What modules do you want in your bar? The standard set is workspaces, window title, clock, tray, volume, network. For laptops: battery and backlight. Any extras — media player, CPU/RAM usage, weather, custom scripts, power button? And where do you want the bar — top or bottom?"

*If ags:* "AGS can handle a lot more than just a bar. Which components do you want it to cover? Bar (workspaces, tray, clock, system indicators), notification popups, notification center/drawer, app launcher, volume/brightness OSD, quick settings panel (WiFi/BT/volume/brightness toggles), media player widget, power menu? The more it handles, the fewer separate tools you need."

*If swaync:* "swaync has a built-in notification center with optional widgets — do you want the mpris media controls widget, a do-not-disturb toggle, volume slider, or buttons grid in the notification panel?"

*Terminal follow-up:* "Any specific terminal preferences? Font size, background opacity, shell override (e.g., launch fish instead of default bash)? Or just use the color scheme defaults?"

*Launcher follow-up:* "Do you want the launcher to also handle clipboard history (SUPER+V to search clipboard)? And do you want it to show only apps, or also calculations / file search / emoji picker?"

**Hypr ecosystem follow-ups** (based on Batch 3 answers):

*If hyprpaper:* "Do you have a specific wallpaper in mind, or want a default path? Do you want wallpaper rotation (cycle through a directory on a timer)?"

*If swww:* "What transition style for wallpaper changes? Fade (smooth, subtle), wipe (directional sweep), wave, or grow (radial)? Do you want a wallpaper cycling script with a keybind to shuffle?"

*If hyprlock:* "What do you want on your lock screen? The basics are a clock and password field. Extras: date, profile picture/avatar, a greeting message, battery indicator, song currently playing? Do you want a blurred screenshot of the desktop as background, or a solid color / specific image?"

*If hypridle:* "What idle timeouts feel right? Common setup: dim screen at 2.5 min, lock at 5 min, screen off at 5.5 min, suspend at 30 min. Want to adjust any of those, or disable suspend entirely (common for desktops)?"

#### Batch 4 — Additional tools (choices)

| Header | Question | Options | Multi? |
|--------|----------|---------|--------|
| Files | File manager? | `thunar`, `nautilus`, `nemo`, `yazi (terminal-based)` | no |
| Screenshot | Screenshot tool? | `grim+slurp`, `grimblast`, `None` | no |
| Login | Display manager? | `SDDM`, `greetd+tuigreet`, `None (TTY launch)` | no |
| Night light | Color temperature? | `hyprsunset (Recommended)`, `gammastep`, `None` | no |

#### Batch 5 — Additional tools (extras)

Use two multiSelect questions to cover the remaining yes/no tools:

| Header | Question | Options | Multi? |
|--------|----------|---------|--------|
| Extras | Which extra tools do you want? | `Clipboard history (cliphist)`, `Bluetooth GUI (blueman)`, `Logout menu (wlogout)`, `Workspace overview (hyprexpo)` | yes |
| More extras | Any more? | `Launch via uwsm`, `Screen recording (obs/wf-recorder)`, `Auto-mount USB (udiskie)`, `Color picker (hyprpicker)` | yes |

#### Batch 6 — Look and feel

| Header | Question | Options | Multi? |
|--------|----------|---------|--------|
| Colors | Color scheme? | `Catppuccin`, `Tokyo Night`, `Gruvbox`, `Dracula` | no |
| Font | Font? | `JetBrainsMono Nerd Font (Recommended)`, `FiraCode Nerd Font`, `Hack Nerd Font` | no |
| Cursor | Cursor theme? | `Bibata-Modern-Classic (Recommended)`, `Catppuccin`, `System default` | no |
| Layout | Tiling layout? | `dwindle (default, most popular)`, `master (one large + stack)` | no |

**Follow-ups:**

*If Catppuccin:* Ask flavor with `AskUserQuestion`: `Mocha (dark, most popular)`, `Macchiato`, `Frappe`, `Latte (light)`

*Monitor setup:* "How many monitors do you have? What resolution(s) and refresh rate(s)? Names if known (e.g., DP-1, HDMI-A-1)?"

*If multi-monitor:* "Which monitor is primary? How are they arranged — side by side, stacked? Do you want specific workspaces assigned to specific monitors (e.g., 1-5 on left, 6-10 on right)?"

*Keyboard:* "What keyboard layout? (default: us) Multiple layouts with toggle?"

*If laptop:* Ask touchpad preferences with `AskUserQuestion` (multiSelect): `Tap-to-click`, `Natural scrolling (reverse, like phone)`, `Disable while typing`

*Input:* "Do you want mouse acceleration or flat input (1:1 movement, preferred by gamers)?"

#### Batch 7 — Visual style

Tell the user they can say "all defaults" to skip this and the next batch. If they do, use: floating pills bar (top), 8/16 gaps, 2px border, gradient border, 10px rounding, moderate blur, balanced animations, shadows on, slight transparency, smart gaps on.

| Header | Question | Options | Multi? |
|--------|----------|---------|--------|
| Bar style | Bar visual style? | `Floating pills (Recommended)`, `Solid bar (traditional)`, `Color-blocked (bold per-module colors)`, `Minimal (subtle, icon-only)` | no |
| Gaps | Gap size (inner/outer pixels)? | `Tight (5/10)`, `Balanced (8/16) (Recommended)`, `Spacious (10/20)`, `Wide (15/30)` | no |
| Borders | Border width? | `Thin (1px)`, `Medium (2px) (Recommended)`, `Thick (3px)` | no |
| Rounding | Corner rounding? | `None (0px)`, `Subtle (4-6px)`, `Moderate (8-10px) (Recommended)`, `Round (12+px)` | no |

#### Batch 8 — More visual style

| Header | Question | Options | Multi? |
|--------|----------|---------|--------|
| Border color | Border color style? | `Solid theme color`, `Gradient (two colors + angle; highest impact) (Recommended)`, `Rainbow` | no |
| Blur | Background blur? | `Disabled`, `Subtle`, `Moderate (Recommended)`, `Heavy` | no |
| Animations | Animation style? | `Minimal (quick, snappy)`, `Balanced (smooth, moderate) (Recommended)`, `Fancy (bouncy, dramatic)` | no |
| Opacity | Window opacity? | `Fully opaque`, `Slight transparency (active 1.0, inactive 0.9)`, `More transparent (active 0.95, inactive 0.85)` | no |

#### Batch 9 — Visual extras

| Header | Question | Options | Multi? |
|--------|----------|---------|--------|
| Extras | Which visual extras? | `Shadows`, `Smart gaps (no gaps with 1 window)`, `Dim inactive windows` | yes |
| Scratch | Special workspaces (scratchpads)? | `None`, `1-2 (terminal + notes)`, `3+ (terminal, notes, music, etc.)` | no |

#### Batch 10 — Window behavior and app rules

| Header | Question | Options | Multi? |
|--------|----------|---------|--------|
| Swallow | Window swallowing? (terminal hides when launching a GUI app from it) | `Yes`, `No` | no |
| XWayland | Do you run X11-only apps? (some games, older apps) | `Yes — configure XWayland`, `No` | no |

Then ask these as text follow-ups (answers are too varied for selectable options):
- "Which apps do you use daily? (e.g., Firefox, Discord, Spotify, Steam, VS Code) — I'll set up smart window rules."
- "Want specific apps on certain workspaces? Common: browser on 2, editor on 3, chat on 4, music on 5."
- "Any apps you always want floating? Common: calculator, settings dialogs, password managers."

These questions help generate window rules that match the user's actual workflow rather than generic defaults. A developer who uses VS Code + Firefox all day needs different rules than a gamer who runs Steam + Discord.

#### Batch 11 — Keybind preferences

Tell the user they can say "defaults" or "i3-like" to skip details.

| Header | Question | Options | Multi? |
|--------|----------|---------|--------|
| Style | Keybind style? | `i3/sway-like (Recommended)`, `vim-centric (hjkl everything)`, `Windows/GNOME-familiar`, `Custom` | no |
| Modifier | Primary modifier key? | `SUPER (Recommended)`, `ALT` | no |
| Close | Window close keybind? | `SUPER+SHIFT+Q (i3 tradition)`, `SUPER+Q`, `SUPER+C`, `SUPER+SHIFT+C` | no |
| Terminal | Terminal launch keybind? | `SUPER+Return (i3/sway tradition)`, `SUPER+T (GNOME-like)` | no |

Style descriptions for context:
- *i3-like*: SUPER+Return=terminal, SUPER+D=launcher, SUPER+SHIFT+Q=kill, SUPER+1-0=workspaces — the community standard
- *vim-centric*: hjkl for all directional actions, minimal arrow key use, resize/launch submaps
- *Windows/GNOME-familiar*: SUPER+E=files, ALT+F4=close, ALT+Tab=cycle, SUPER alone opens launcher

#### Batch 12 — More keybind options

| Header | Question | Options | Multi? |
|--------|----------|---------|--------|
| Resize | Resize mode? | `Submap (SUPER+R then arrows) (Recommended)`, `Hold modifier (SUPER+CTRL+arrows)`, `Mouse only (SUPER+RMB drag)` | no |
| Submaps | Which submaps to include? | `Resize only (Recommended)`, `Resize + power/session`, `Resize + launch + power`, `All (resize, launch, power, screenshot)` | no |
| Directions | Direction keys? | `Both arrows + hjkl (Recommended)`, `Arrows only`, `hjkl only` | no |
| Workspaces | Number of workspaces? | `10 (SUPER+1-0, most common) (Recommended)`, `Fewer`, `More (requires F-keys)` | no |

> **Shorthand**: If the user picks "i3/sway-like" in Batch 11, you can pre-fill sensible defaults for Batch 12 (submap resize, both arrows+hjkl, 10 workspaces) and ask "These are the standard i3-like defaults — want to change any?" instead of asking each question. If they say "defaults", use the same i3-like defaults — it's what most Hyprland users expect. Always use `bindd` (bind descriptions) — negligible cost, useful for discoverability.

#### Batch 13 — Shell configuration

Tell the user they can say "defaults" or "skip" for this batch.

| Header | Question | Options | Multi? |
|--------|----------|---------|--------|
| Shell | Shell? | `zsh (most popular for ricing)`, `fish (best out-of-box UX)`, `bash (system default)`, `Keep current` | no |
| Prompt | Shell prompt? | `starship (cross-shell, fast) (Recommended)`, `powerlevel10k (zsh only)`, `oh-my-posh`, `Plain default` | no |
| CLI tools | Modern CLI utilities? (eza, bat, fd, ripgrep, fzf, zoxide, btop) | `Install all (Recommended)`, `Let me pick`, `Skip` | no |
| Aliases | Generate shell aliases for installed tools? | `Yes (Recommended)`, `No` | no |

> **Shorthand**: If the user says "defaults", use: zsh + starship + system-packaged plugins (syntax highlighting, autosuggestions, completions) + all CLI utilities + aliases. If "skip", don't generate any shell config. If "fish", use: fish + starship + fisher with fzf plugin + all CLI utilities + fish abbreviations.

#### Pre-generation confirmation

Before generating anything, summarize the choices back to the user in a compact list. This catches misunderstandings early and makes the user feel heard. Something like:

> Here's what I've got:
> - **System:** Arch, laptop, fresh install
> - **Core:** kitty, wofi, waybar (floating pills, top), dunst
> - **Hypr tools:** hyprpaper (static), hyprlock (clock + blur bg), hypridle (lock at 5min, suspend at 30min)
> - **Extras:** thunar, grim+slurp, cliphist, blueman, wlogout, uwsm, no DM
> - **Theme:** Catppuccin Mocha, JetBrainsMono NF 11pt, Bibata cursor
> - **Visual:** 8/20 gaps, 2px border, 10px rounding, moderate blur, shadows, 0.85 inactive opacity, balanced animations, smart gaps
> - **Input:** touchpad (tap-to-click, natural scroll), us layout, flat mouse input
> - **Apps:** Firefox on ws2, VS Code on ws3, Discord on ws4, Steam floating
> - **Keybinds:** i3-like, SUPER mod, both arrows+hjkl, resize submap
> - **Shell:** zsh + starship + all CLI tools
>
> Anything you'd like to change before I generate?

Wait for confirmation. If they say "looks good" or similar, proceed. If they correct something, update and re-confirm if the change was significant.

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
~/.config/Code - OSS/User/settings.json  (or Code/User/ or VSCodium/User/ — if VS Code theming requested)
<firefox-profile>/chrome/userChrome.css + userContent.css + ../user.js  (if Firefox theming requested)
~/.config/starship.toml  (if using starship)
~/.zshrc / ~/.config/fish/config.fish  (if shell config requested)
install.sh
uninstall.sh
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

#### Visual style — translating Batch 7-9 answers

Load `references/ricing.md` now — it has complete values for decoration, animations, smart gaps, special workspaces, opacity rules, and layer rules.

Key summaries:
- **Blur**: match `size` and `passes` — subtle: 4/2, moderate: 8/3, heavy: 12/4. Set on `decoration:blur {}`.
- **Shadow**: `decoration:shadow { enabled = true; range = 20; render_power = 3; color = rgba(1a1a1abb) }`.
- **Gradient border**: `col.active_border = rgba(colorAff) rgba(colorBff) 45deg` — highest-impact single setting.
- **Opacity**: `active_opacity`/`inactive_opacity` in `decoration {}` are multipliers. Use `override` in windowrules for exact values.
- **Animation style**: see presets in `references/ricing.md` — minimal/balanced/fancy with bezier presets.
- **Smart gaps**: uses `workspace = w[tv1], gapsout:0, gapsin:0` — see `references/ricing.md`.
- **Special workspaces**: `togglespecialworkspace` + `movetoworkspacesilent` + `dim_special` — see `references/ricing.md`.

#### Keybinds — translating Batch 11-12 answers

Load `references/keybinds.md` and `references/dispatchers.md` now. Generate `keybinds.conf` tailored to the user's chosen style. Always define `$mainMod` as a variable at the top so users can change their modifier in one place.

**Core structure** — every keybinds.conf needs these sections:

1. **Modifier variable**: `$mainMod = SUPER` (or user's choice)
2. **App launches**: terminal, launcher, file manager, browser — use the apps chosen in Batches 2-5
3. **Window management**: kill, float toggle, fullscreen, pseudo-tile, split toggle
4. **Focus navigation**: directional focus (arrows and/or hjkl based on Batch 12 answer)
5. **Window movement**: move windows directionally (SHIFT layer of focus binds)
6. **Workspace switching**: `$mainMod + 1-0` for workspaces 1-10
7. **Window-to-workspace**: `$mainMod + SHIFT + 1-0`
8. **Mouse binds**: `$mainMod + LMB` = move, `$mainMod + RMB` = resize
9. **Media/brightness keys**: always include with `el` flags (repeat + locked)
10. **Screenshots**: based on chosen tool (grimblast/hyprshot/grim+slurp)
11. **Utility binds**: lock screen, clipboard history, color temperature toggle
12. **Submaps**: based on user's Batch 12 submap choices

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
Load `references/wlogout.md` for complete layout format, CSS theming, and launch options. Generate if the user chose wlogout in Batch 5:
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

#### VS Code
If the user mentions VS Code as a daily app or asks for a complete rice, offer to theme it. VS Code is one of the most visible apps on a developer's desktop — an unthemed VS Code breaks the visual coherence.

**Variants and config paths** (detect which is installed):
- **Code OSS** (Arch `code` package): class `code-oss`, config at `~/.config/Code - OSS/User/settings.json`
- **Visual Studio Code** (official Microsoft binary / AUR `visual-studio-code-bin`): class `code`, config at `~/.config/Code/User/settings.json`
- **VSCodium** (FOSS build): class `vscodium`, config at `~/.config/VSCodium/User/settings.json`

**Extensions** — install via CLI:
```bash
code --install-extension Catppuccin.catppuccin-vsc        # color theme
code --install-extension Catppuccin.catppuccin-vsc-icons  # file icons
```

**settings.json** — create or merge into the user's existing settings:
```json
{
    "workbench.colorTheme": "Catppuccin Mocha",
    "workbench.iconTheme": "catppuccin-mocha",
    "editor.fontFamily": "'JetBrainsMono Nerd Font', 'JetBrains Mono', monospace",
    "editor.fontSize": 14,
    "editor.fontLigatures": true,
    "window.titleBarStyle": "custom"
}
```

Adjust the color theme name to match the user's flavor (Mocha/Macchiato/Frappe/Latte) and the font to match their Batch 6 choice.

**Transparency** — use a Hyprland window rule, not VS Code's built-in transparency settings. Match the class to the installed variant:
```ini
windowrule {
    name = opacity-vscode
    match:class = code-oss
    opacity = 0.9 override 0.8 override
}
```

The `override` flag ensures exact values that bypass Hyprland's global `inactive_opacity`. Blur shows through the transparent areas for a frosted glass effect.

**Available Catppuccin themes**: Mocha, Macchiato, Frappe, Latte — plus "No Italics" variants of each. Match the user's chosen flavor.

#### Firefox
Load `references/firefox.md` for complete userChrome.css patterns, userContent.css styling, and the interview questions to ask. Firefox is a highly visible app and an unthemed Firefox with its default light UI breaks an otherwise polished dark rice. If the user mentions Firefox as a daily app or asks for a "complete rice", offer to theme it.

**Three files, one profile directory:**
- `chrome/userChrome.css` — styles Firefox's UI (tabs, toolbar, sidebar, menus)
- `chrome/userContent.css` — styles internal pages (`about:newtab`, `about:preferences`, `about:addons`, `about:privatebrowsing`)
- `user.js` — enables `toolkit.legacyUserProfileCustomizations.stylesheets` (required) and sets preferences like compact density

**Profile path detection**: Firefox on Linux stores profiles at `~/.mozilla/firefox/` or `~/.config/mozilla/firefox/`. Read `profiles.ini` to find the active profile (the one under `[Install*]` → `Default=`). The `chrome/` directory may not exist yet — create it.

**Interview questions** (ask individually, not as a batch):
1. **Tab style**: floating pills (rounded, gaps between tabs) or connected (traditional with rounded top corners)?
2. **Toolbar density**: compact or normal? (suggest compact if unsure — pairs well with tiling WMs)
3. **What to hide**: title bar, auto-hide bookmarks bar, reduce padding, hide Firefox Suggest? (offer "all" as a shortcut)
4. **New tab page**: style `about:newtab` with the user's color scheme?
5. **Sidebar**: do they use it? If yes, theme it.
6. **Transparency**: make the toolbar transparent so wallpaper blur shows through?

**Key implementation rules:**
- Match `border-radius` in tabs/URL bar to the user's Hyprland `rounding` value for visual consistency
- Use the same color palette variables as the rest of the rice (e.g., Catppuccin Mocha mauve for active/focus accents)
- Floating tabs use `.tabbrowser-tab .tab-background` with `border-radius`, margin for gaps, and transparent/semi-transparent backgrounds
- Auto-hide bookmarks bar uses `max-height: 0` + `opacity: 0` with transition, revealed on `#navigator-toolbox:hover`
- Toolbar transparency: `#navigator-toolbox { background: rgba(base, 0.85) }` — matches the pattern used for waybar pills
- `user.js` must set `toolkit.legacyUserProfileCustomizations.stylesheets` to `true` or the CSS files are ignored
- Set `browser.compactmode.show` and `browser.uidensity` to `1` for compact mode
- Remind the user to **fully restart Firefox** (quit + reopen) for changes to take effect

#### hyprlock
Load `references/hyprlock.md` and `references/ricing.md`. Generate with `background {}` (blurred screenshot is most popular), `input-field {}` (full color states: outer, inner, check, fail, capslock), and `label {}` blocks for clock/date. Optionally add `image {}` for profile picture and `shape {}` for decorative elements. Match all colors to the theme. Add `animations {}` block. **A config is required — without one, hyprlock locks but renders nothing.**

#### hypridle
Load `references/hypridle.md`. Generate with `general {}` block (`lock_cmd = loginctl lock-session`, `before_sleep_cmd`) and listeners: dim at ~2.5 min, lock at ~5 min, screen off at ~5.5 min, suspend at ~30 min (optional).

#### hyprpaper / swww
If the user chose **hyprpaper**: Load `references/hyprpaper.md`. Use `wallpaper {}` block syntax with `fit_mode = cover`. Add a fallback block with empty monitor. For rotating wallpapers: set `path` to a directory, add `timeout = 300` and `order = random`.

If the user chose **swww**: Load `references/swww.md`. No config file — all options are CLI flags. Generate autostart line (`exec-once = swww-daemon && swww img ~/Pictures/wallpaper.png`), optionally generate a wallpaper cycling script (`~/.config/hypr/scripts/wallpaper-cycle.sh`) and a keybind for random wallpaper. Key selling point: animated transitions (`--transition-type fade/wipe/wave/grow`). Only one wallpaper daemon should run — don't autostart both.

> **swww package naming pitfall (Arch)**: The `swww` AUR package may install binaries as `awww` and `awww-daemon` instead of `swww` and `swww-daemon`. Before generating autostart lines, verify the actual binary name with `pacman -Ql swww | grep bin`. If the binaries are named `awww`, use `awww-daemon` and `awww img` in all generated configs. The cache directory also changes to `~/.cache/awww/`.

#### GTK / Qt / icon / cursor theming
Load `references/theming.md`. For a complete rice, generate:
- `~/.config/gtk-3.0/settings.ini` and `~/.config/gtk-4.0/settings.ini` (theme, icons, cursor, font)
- env vars: `GTK_THEME`, `XCURSOR_THEME`, `XCURSOR_SIZE`, `QT_QPA_PLATFORMTHEME` (qt5ct), `HYPRCURSOR_THEME`
- `~/.icons/default/index.theme` (XWayland cursor fallback)
- Tell the user to run `nwg-look` after install to apply GTK settings, and `qt5ct` for Qt apps
- For Qt ricing beyond colors: mention Kvantum (`QT_STYLE_OVERRIDE=kvantum`)
- For font rendering: optionally generate `~/.config/fontconfig/fonts.conf`

#### Shell configuration
Load `references/shell.md` now. Generate shell config based on Batch 13 answers:

- **Shell rc file**: Generate `.zshrc`, `config.fish`, or additions to `.bashrc` depending on chosen shell. Include: prompt initialization, plugin sourcing, tool initialization (zoxide, fzf), and aliases/abbreviations for installed CLI utilities.
- **Starship config**: If using starship, generate `~/.config/starship.toml` with a theme-matched palette (e.g., Catppuccin Mocha colors) and Nerd Font symbols. Use the same font the user chose in Batch 6.
- **Powerlevel10k**: If using p10k, add the source line to `.zshrc` and tell the user to run `p10k configure` after install — the wizard generates `~/.p10k.zsh` interactively.
- **Plugin setup**: For zsh with system packages, add `source` lines for syntax highlighting + autosuggestions. For zsh with zinit, generate the zinit block. For fish with fisher, add fisher install commands to `install.sh`.
- **CLI utilities**: Add initialization lines for zoxide and fzf to the shell rc. Generate aliases (bash/zsh) or abbreviations (fish) only for tools the user chose to install. **zoxide `--cmd cd` pitfall**: Do NOT use `alias cd=z` or `abbr -a cd z` — this breaks autosuggestions/completions because `z` is a shell function, not a real command. Instead, use `zoxide init <shell> --cmd cd | source` which makes zoxide register directly as `cd` (and `cdi` for interactive mode) with proper completions. This applies to all shells.
- **TTY launch line**: If the user chose no display manager, add the Hyprland auto-start line to the correct login profile for their shell (`.bash_profile`, `.zprofile`, or `config.fish`). Use uwsm variant if applicable. **Do NOT generate TTY launch lines if the user chose greetd or SDDM** — the display manager handles session launch, and having both creates a conflict where the TTY line tries to start Hyprland before greetd does.
- **Default shell change**: Add `chsh -s /usr/bin/zsh` (or fish) to `install.sh` if the user chose a non-default shell. Include a comment that re-login is required.
- **Fastfetch**: If installed, optionally add `fastfetch` to the end of the shell rc so it displays system info on terminal launch. Ask the user if they want this — some find it annoying on every new terminal.

#### ags (Aylur's GTK Shell)
If the user chose ags as their bar/shell, load `references/ags.md` now. AGS replaces multiple companion apps at once — it can serve as bar, notification daemon, app launcher, OSD, and more in a single TypeScript codebase.

Generate a complete AGS project:
1. **`~/.config/ags/app.ts`** — entry point with `app.start()`, imports all widget files, loads CSS
2. **Widget files** — one `.tsx` per component the user wants. A typical full setup: `Bar.tsx`, `Notifications.tsx`, `Launcher.tsx`, `OSD.tsx`, `QuickSettings.tsx`, `MediaPlayer.tsx`, `PowerMenu.tsx`
3. **`~/.config/ags/style.scss`** — SCSS with the user's color palette (Catppuccin/Tokyo Night/etc.), matching the same palette used in hyprlock and other Hyprland configs
4. **`tsconfig.json`** — include `"experimentalDecorators": false`, `"target": "ES2020"` if using GObject decorators

Key generation rules:
- Use AGS v3 APIs only: `createState`, `createBinding`, `createComputed`, `createEffect`, `createPoll`. Never use v1/v2 APIs (`Variable`, `bind()`, `Widget.Box`, `astalify`, `App.config`)
- **`app` is a default export**: `import app from "ags/gtk4/app"` — NOT `import { App } from "ags/gtk4/app"`. Use lowercase `app` everywhere (e.g., `application={app}`, `app.toggle_window(...)`)
- **Import locations**: `createState`/`createBinding`/`createComputed`/`For`/`With` from `"ags"`, `createPoll` from `"ags/time"`, `exec`/`execAsync` from `"ags/process"`
- **Astal service imports use NO version string**: `import AstalTray from "gi://AstalTray"` — NOT `gi://AstalTray?version=0.1`. Only `Astal`, `Gtk`, `Gdk` need `?version=4.0`
- **GTK4 box has no `vertical` prop**: Use `orientation={Gtk.Orientation.VERTICAL}` instead
- **Use `class` not `cssClasses`**: AGS JSX uses `class="name"` (string), not `cssClasses={["name"]}` (array). For reactive: `class={createComputed(() => "...")}`
- **Use `$` not `setup`** for ref callbacks: `$={(self) => { ... }}`
- **CenterBox children need `$type` props**: `$type="start"`, `$type="center"`, `$type="end"` — without these the bar renders 1px tall
- **Never `createBinding(createComputed(...))`**: `createBinding` is only for GObject + property name. `createComputed` already returns a reactive value
- **Use `<For each={binding}>` for dynamic lists**: Don't use `{binding((list) => list.map(...))}` as children — it renders as "Accessor { }" text
- **`requestHandler(argv: string[], res)`**: `argv` is an array, not a string — don't call `.trim()` or `.split()` on it
- **Global CSS reset required**: GTK4 Adwaita theme applies white backgrounds to buttons. Include `* { background: transparent; border: none; }` at top of SCSS
- **`dart-sass` required**: Install it or AGS crashes with "executable sass not found"
- Every window needs `visible` set explicitly (GTK4 windows are invisible by default)
- Set `namespace` on windows so Hyprland layerrules can target them
- Use `exclusivity={Astal.Exclusivity.EXCLUSIVE}` for bars (reserves screen space)
- Popup windows (launcher, quick settings, power menu) should use `application={app}` and `name="xxx"` so `ags toggle xxx` works from keybinds
- The notification daemon is exclusive — if AGS handles notifications via AstalNotifd, kill and mask dunst/mako/swaync first (`systemctl --user mask dunst.service`)
- **Astal packages are `libastal-*-git`** in AUR, NOT `astal-*-git` — wrong names silently fail

When AGS is the bar, skip generating waybar config. When AGS handles notifications, skip dunst/mako/swaync. When AGS includes a launcher, skip wofi/rofi/fuzzel. Adjust autostart.conf accordingly:
```ini
exec-once = ags run ~/.config/ags/app.ts
# No waybar, no dunst, no wofi — AGS handles all of these
```

Add Hyprland keybinds for toggling AGS windows:
```ini
bindd = $mainMod, D, Open launcher, exec, ags toggle launcher
bindd = $mainMod, A, Quick settings, exec, ags toggle quicksettings
bindd = $mainMod, Escape, Power menu, exec, ags toggle powermenu
```

Add layerrules for AGS window namespaces:
```ini
layerrule = blur true, match:namespace bar
layerrule = blur true, match:namespace launcher
layerrule = blur true, match:namespace quicksettings
layerrule = blur true, match:namespace notifications
layerrule = blur true, match:namespace osd
```

#### hyprpanel
If the user chose hyprpanel (the out-of-box AGS-based panel), it's much simpler — one JSON config drives everything:
- Config: `~/.config/hyprpanel/config.json` — set the color palette and it propagates everywhere
- Includes bar + notification center + volume/brightness OSD + app launcher
- Much easier than raw AGS but less flexible
- Install: `yay -S hyprpanel`
- Autostart: `exec-once = hyprpanel`
- Don't also start waybar, dunst, or wofi — hyprpanel replaces them all

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

**Astal library package naming** (Arch AUR):
- All Astal service libraries are named `libastal-*-git`, NOT `astal-*-git`. The `astal-*-git` names do not exist.
- Core: `libastal-io-git`, `libastal-git`, `libastal-4-git`
- Services: `libastal-battery-git`, `libastal-bluetooth-git`, `libastal-hyprland-git`, `libastal-mpris-git`, `libastal-network-git`, `libastal-notifd-git`, `libastal-tray-git`, `libastal-wireplumber-git`, `libastal-apps-git`, `libastal-powerprofiles-git`
- `grimblast` is AUR-only as `grimblast-git` — it is NOT in official repos, so put it in the AUR package list, not the pacman list
- `dart-sass` is required for AGS SCSS compilation — include it in pacman packages
- Add `fc-cache -f` before font verification in install.sh — newly installed fonts may not be found by `fc-list` until the cache is rebuilt

### Step 5b: uninstall.sh

Generate an uninstall script alongside install.sh. The uninstall script should cleanly reverse the install — removing packages, config files, and system changes — while being safe and confirmatory. Users need this when switching to a different setup, troubleshooting a broken rice, or doing a clean reinstall.

**Structure:**
- **Confirmation prompt**: Show what will be removed and require explicit confirmation before proceeding. The uninstall script should never silently remove files.
- **Selective uninstall**: Offer the user a choice between full uninstall (everything) and partial (keep packages, only remove configs — or vice versa). This matters because someone might want to reset their config without losing all their installed packages.
- **Config backup**: Before removing any config files, create a timestamped backup tarball (e.g., `~/hypr-backup-20260331.tar.gz`) containing all config directories that will be removed. Tell the user where the backup is so they can restore if needed.
- **Config removal**: Remove the config directories the install script created:
  - `~/.config/hypr/` (hyprland.conf and all modular configs)
  - `~/.config/waybar/` or `~/.config/ags/` (depending on what was installed)
  - `~/.config/dunst/` / `~/.config/mako/` / `~/.config/swaync/` (notification daemon)
  - `~/.config/wofi/` / `~/.config/rofi/` / `~/.config/fuzzel/` (launcher)
  - `~/.config/wlogout/` (if installed)
  - `~/.config/kitty/kitty.conf` (or the full directory if the skill created it)
  - `~/.config/starship.toml`
  - `~/.config/uwsm/` (uwsm env files)
  - `~/.config/gtk-3.0/settings.ini`, `~/.config/gtk-4.0/settings.ini`
  - `~/.icons/default/index.theme`
  - Shell config additions (warn but don't auto-remove `.zshrc`/`config.fish` — the user may have other customizations in there)
- **Package removal**: Use the same package manager detected at install time. Remove packages in reverse order (AUR first, then official). Use `pacman -Rns` to also remove orphaned dependencies. List each package being removed.
- **Service cleanup**: Unmask any masked services (e.g., `systemctl --user unmask dunst.service`), disable any enabled services the install script set up.
- **Plugin cleanup**: Run `hyprpm remove` for any plugins that were installed.
- **Shell restoration**: If the install changed the default shell (e.g., to fish or zsh), offer to change it back to bash with `chsh -s /bin/bash`.
- **Summary**: Show what was removed, what was backed up, and any manual steps remaining (e.g., "log out and back in for shell change to take effect").

**Safety rules:**
- Never remove packages that were already installed before the rice (the install script can't easily track this, so warn the user that some packages may have been pre-existing)
- Never remove system-critical packages (pipewire, networkmanager, etc.) — only remove rice-specific packages (themes, fonts, companion tools)
- Don't remove the user's wallpapers, screenshots, or personal files
- Don't touch `/etc/` files without explicit confirmation
- Color-code output the same way as install.sh (green for success, yellow for warnings, red for errors)

---

### Step 5c: Dotfiles repo with GNU Stow (if user said yes in Batch 2)

Load `references/dotfiles.md` now. When the user wants a dotfiles repo, the entire output structure changes — instead of writing configs directly to `~/.config/`, generate them inside a stow-managed git repo at `~/dotfiles/`.

#### Output structure

Organize configs into **one stow package per application**, with each package's internal directory structure mirroring the path from `$HOME`. See `references/dotfiles.md` for the full directory layout.

**Which packages to create** depends on what the user chose in the interview. Every tool they selected becomes its own package:

| Interview choice | Package name | Target path |
|-----------------|-------------|-------------|
| Hyprland core configs | `hypr/` | `.config/hypr/*` |
| Waybar | `waybar/` | `.config/waybar/*` |
| AGS / hyprpanel | `ags/` | `.config/ags/*` |
| Kitty / Alacritty / etc. | `kitty/` (or terminal name) | `.config/kitty/*` |
| Dunst / Mako / SwayNC | `dunst/` (or daemon name) | `.config/dunst/*` |
| Wofi / Rofi / Fuzzel | `wofi/` (or launcher name) | `.config/wofi/*` |
| Wlogout | `wlogout/` | `.config/wlogout/*` |
| Hyprlock + Hypridle | Include in `hypr/` package | `.config/hypr/hyprlock.conf`, etc. |
| Hyprpaper / swww | `hypr/` (for hyprpaper.conf) or `scripts/` (for swww cycling script) | `.config/hypr/hyprpaper.conf` |
| GTK/Qt theming | `gtk/` | `.config/gtk-3.0/`, `.config/gtk-4.0/`, `.icons/` |
| Shell (zsh/fish) + starship | `shell/` | `.zshrc`, `.zprofile`, `.config/starship.toml`, or `.config/fish/` |
| Custom scripts | `scripts/` | `.local/bin/*` |
| VS Code theming | `vscode/` | `.config/Code/User/settings.json` |
| Firefox theming | `firefox/` | `.mozilla/firefox/PROFILE/chrome/*` |
| uwsm env files | `uwsm/` | `.config/uwsm/*` |

#### Variable declaration order in dotfiles repos

This is especially important with stow: the main `hyprland.conf` must declare all variables (`$terminal`, `$fileManager`, `$menu`, etc.) **before** any `source =` lines. Since sourced files are processed inline, a variable referenced in `keybinds.conf` must already be defined in `hyprland.conf` above the `source = ~/.config/hypr/keybinds.conf` line.

#### setup.sh replaces install.sh

When generating a dotfiles repo, generate a `setup.sh` at the repo root instead of a standalone `install.sh`. The setup script combines package installation with stow operations:

1. **Install system dependencies** (same logic as Step 5's install.sh — AUR helper detection, batch install with fallback, etc.)
2. **Install stow** itself (`sudo pacman -S --needed stow`)
3. **Backup existing configs** — move real files (not symlinks) to `~/.config-backup-TIMESTAMP/`
4. **Generate `.stowrc`** with `--target=$HOME`
5. **Stow all packages** — iterate over the packages that exist in the repo
6. **Post-install** — font cache rebuild, display manager setup, shell change, verification

Also generate a `teardown.sh` that unstows all packages and optionally removes installed packages (same logic as Step 5b's uninstall.sh, but using `stow -D` to remove symlinks instead of `rm`).

#### Package list files

Generate plain text package lists at the repo root for easy maintenance:

- `packages.txt` — official repo packages (one per line)
- `aur-packages.txt` — AUR packages (one per line)

The setup script reads these instead of hardcoding package names, so users can add/remove packages without editing the script.

#### .gitignore and .stow-local-ignore

Generate both files at the repo root:

**`.gitignore`:**
```gitignore
# Secrets
*.secret
.env

# Machine-specific overrides
**/local.conf

# OS
.DS_Store
*.swp
*~
```

**`.stow-local-ignore`** (replaces stow defaults — must re-add them):
```
\.git
\.gitignore
\.gitmodules
^README.*
^LICENSE.*
\.stowrc
^packages\.txt
^aur-packages\.txt
^setup\.sh
^teardown\.sh
^Makefile
^\.stow-local-ignore
```

#### README.md

Generate a README.md with:
- Screenshot placeholder (users love showing off their rice)
- List of tools/packages used
- Quick-start instructions (`git clone` → `cd dotfiles` → `./setup.sh`)
- Manual stow commands for selective installation
- Credit/theme info

#### Multi-machine support

If the user mentions multiple machines or asks about portability, use the **host-specific packages** strategy from `references/dotfiles.md`: shared configs in the base package, machine-specific overrides (monitors, touchpad, HiDPI) in `hypr-desktop/` or `hypr-laptop/` packages. The setup script should accept an optional hostname argument or auto-detect.

#### Adopting existing configs

If the user already has Hyprland configs and wants to migrate them into a dotfiles repo (request type D standalone):

1. Create the package directory structure
2. Move existing files into the correct package paths
3. Stow to create symlinks back
4. Initialize git repo, commit, and optionally set up a remote

Walk the user through `stow --adopt` if they want to pull in existing files, but warn them to `git diff` immediately after.

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

These complement the style-specific binds generated from Batches 11-12. Always include them in `keybinds.conf`:

```ini
# Lock screen — always use loginctl, not hyprlock directly (lets hypridle hooks fire)
bindd = $mainMod, L, Lock screen, exec, loginctl lock-session

# Clipboard history (if using cliphist — substitute rofi/fuzzel for wofi as needed)
bindd = $mainMod, V, Clipboard history, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy

# Screenshots (grim+slurp — substitute grimblast/hyprshot based on Batch 4 choice)
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
