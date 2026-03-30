---
title: Hyprland Ecosystem Packages Reference
---

This file covers the common packages used in a Hyprland setup, organized by category. Use this during the user interview to know what options exist and what questions to ask.

## Table of Contents
- [Essential (always install)](#essential)
- [Status Bars](#status-bars)
- [App Launchers](#app-launchers)
- [Terminals](#terminals)
- [Wallpaper Daemons](#wallpaper)
- [Notification Daemons](#notifications)
- [Screen Lockers](#screen-lockers)
- [Idle Daemons](#idle-daemons)
- [File Managers](#file-managers)
- [Clipboard Managers](#clipboard)
- [Screenshot Tools](#screenshots)
- [Audio](#audio)
- [Brightness Control](#brightness)
- [Bluetooth](#bluetooth)
- [Network](#network)
- [Color Temperature](#color-temperature)
- [Theming (GTK, icons, cursors, fonts)](#theming)
- [Screen Recording](#screen-recording)
- [Auto-mount](#auto-mount)
- [Polkit Agents](#polkit)
- [Shells](#shells)
- [Shell Prompts](#shell-prompts)
- [Modern CLI Utilities](#modern-cli-utilities)

---

## Essential

Always include these — without them, Hyprland will feel broken:

| Package | Purpose | Arch name |
|---------|---------|-----------|
| `xdg-desktop-portal-hyprland` | File pickers, screensharing, global shortcuts | `xdg-desktop-portal-hyprland` |
| `xdg-desktop-portal-gtk` | GTK portal fallback | `xdg-desktop-portal-gtk` |
| `qt5-wayland` | Qt5 Wayland support | `qt5-wayland` |
| `qt6-wayland` | Qt6 Wayland support | `qt6-wayland` |
| `pipewire` + `wireplumber` | Audio + screensharing | `pipewire wireplumber` |
| `noto-fonts` | Required sans-serif font | `noto-fonts` |
| `polkit agent` | Password prompts for privilege elevation | see [Polkit](#polkit) |

---

## Status Bars

| Name | Type | Notes |
|------|------|-------|
| **waybar** | GTK, highly configurable | Most popular; native Hyprland workspace module |
| ashell | Rust, simpler | Ready-to-go, less config needed |

**Default recommendation:** `waybar`

Arch: `waybar`

---

## App Launchers

| Name | Notes |
|------|-------|
| **wofi** | GTK, common default, easy to theme |
| **rofi** (rofi-wayland) | Wayland port of rofi; feature-rich, many plugins |
| **fuzzel** | Lightweight, fast, minimal dependencies |
| **tofi** | Extremely fast, wlroots-based |
| hyprlauncher | First-party Hypr launcher |
| bemenu | dmenu replacement, Wayland-native |
| walker | Service-based for fast startup |

**Default recommendation:** `wofi`

Arch: `wofi` / `rofi-wayland` (AUR) / `fuzzel`

---

## Terminals

| Name | Notes |
|------|-------|
| **kitty** | GPU-accelerated, highly themeable, most popular for ricing |
| **alacritty** | Fast, GPU-accelerated, minimal |
| **foot** | Lightweight, Wayland-native |
| **wezterm** | Feature-rich, Lua config, multiplexer built-in |
| **ghostty** | New, fast, native Wayland |

**Default recommendation:** `kitty`

Arch: `kitty` / `alacritty` / `foot` / `wezterm` / `ghostty` (AUR)

---

## Wallpaper

| Name | Notes |
|------|-------|
| **hyprpaper** | First-party, static/directory cycling, IPC, fast |
| **swww** | Animated wallpapers, smooth transitions, very popular |
| **swaybg** | Dead simple static wallpaper |
| wpaperd | Automatic changing |
| mpvpaper | Video wallpaper |

**Default recommendation:** `hyprpaper` (static) or `swww` (animated)

Arch: `hyprpaper` / `swww` (AUR)

Config location: `~/.config/hypr/hyprpaper.conf`

---

## Notifications

| Name | Notes |
|------|-------|
| **dunst** | Most popular, highly configurable |
| **mako** | Simple, lightweight, wlroots-native |
| **swaync** | Side panel notification center, very modern |
| fnott | Minimal, keyboard-driven |

**Default recommendation:** `dunst`

Arch: `dunst` / `mako` / `swaync` (AUR)

Config locations:
- dunst: `~/.config/dunst/dunstrc`
- mako: `~/.config/mako/config`
- swaync: `~/.config/swaync/`

---

## Screen Lockers

| Name | Notes |
|------|-------|
| **hyprlock** | First-party, fast, GPU-accelerated, highly customizable |
| swaylock | Simpler, more battle-tested |
| swaylock-effects | swaylock with blur/effects |

**Default recommendation:** `hyprlock`

Arch: `hyprlock`

Config location: `~/.config/hypr/hyprlock.conf`

> [!IMPORTANT] hyprlock will not render anything without a config file — even a minimal one is required.

---

## Idle Daemons

| Name | Notes |
|------|-------|
| **hypridle** | First-party, integrates with hyprlock and loginctl |
| swayidle | More established, wlroots-based |

**Default recommendation:** `hypridle`

Arch: `hypridle`

Config location: `~/.config/hypr/hypridle.conf`

---

## File Managers

| Name | Type | Notes |
|------|------|-------|
| **thunar** | GUI, GTK | Lightweight, XFCE-based, very popular |
| **nautilus** | GUI, GTK | GNOME's file manager, feature-rich |
| **nemo** | GUI, GTK | Cinnamon's file manager |
| dolphin | GUI, Qt | KDE's file manager |
| **yazi** | TUI | Fast, modern terminal file manager |
| ranger | TUI | Vi-keybinding, Python-based |

Arch: `thunar` / `nautilus` / `nemo` / `yazi`

---

## Clipboard

The most common combo: `cliphist` + `wl-clipboard` + a keybind to `wofi`/`rofi`.

| Package | Purpose |
|---------|---------|
| **wl-clipboard** | `wl-copy` / `wl-paste` CLI tools |
| **cliphist** | Clipboard history daemon |
| copyq | GUI clipboard manager |

Arch: `wl-clipboard cliphist`

Setup in autostart:
```ini
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
```

Keybind to open history:
```ini
bind = SUPER, V, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy
```

---

## Screenshots

| Tool | Notes |
|------|-------|
| **grim** | Takes screenshots (required for most setups) |
| **slurp** | Select screen region (works with grim) |
| **grimblast** | Script wrapping grim+slurp with extra features |
| hyprshot | Hyprland-specific screenshot utility |
| flameshot | Feature-rich GUI, needs `--gui` flag on Wayland |
| satty | Annotation tool (pair with grim) |

**Default recommendation:** `grim` + `slurp`

Arch: `grim slurp grimblast` (grimblast in AUR or hyprland-contrib)

Example keybinds:
```ini
bind = , Print, exec, grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png
bind = SHIFT, Print, exec, grim -g "$(slurp)" ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png
bind = CTRL, Print, exec, grim -g "$(slurp)" - | wl-copy
```

---

## Audio

| Package | Purpose |
|---------|---------|
| **pipewire** | Modern audio server (replaces PulseAudio) |
| **wireplumber** | PipeWire session manager |
| **pavucontrol** | GUI volume mixer |
| **pamixer** | CLI volume control (for keybinds) |
| **playerctl** | MPRIS media player control (play/pause/next) |
| **wpctl** | WirePlumber CLI (preferred over pamixer on pipewire) |

Arch: `pipewire wireplumber pavucontrol pamixer playerctl`

Media keybinds:
```ini
bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl  = , XF86AudioMute,        exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindl  = , XF86AudioPlay,        exec, playerctl play-pause
bindl  = , XF86AudioPrev,        exec, playerctl previous
bindl  = , XF86AudioNext,        exec, playerctl next
```

---

## Brightness

| Package | Purpose |
|---------|---------|
| **brightnessctl** | Backlight control (laptop screens, keyboards) |
| light | Alternative backlight control |

Arch: `brightnessctl`

Keybinds:
```ini
bindel = , XF86MonBrightnessUp,   exec, brightnessctl set 5%+
bindel = , XF86MonBrightnessDown, exec, brightnessctl set 5%-
```

---

## Bluetooth

| Package | Notes |
|---------|-------|
| **bluez** + **bluez-utils** | Bluetooth stack (required) |
| **blueman** | GTK Bluetooth manager, most popular |
| **blueberry** | Another GTK option |
| overskride | GTK4 Bluetooth client |

Arch: `bluez bluez-utils blueman`

Enable service: `systemctl enable --now bluetooth.service`

---

## Network

| Package | Notes |
|---------|-------|
| **NetworkManager** | Most common network manager |
| **nm-applet** | System tray applet for NetworkManager |
| **nm-connection-editor** | GUI editor for connections |
| iwd | Lightweight Wi-Fi daemon alternative |
| iwgtk | GTK frontend for iwd |

Arch: `networkmanager network-manager-applet nm-connection-editor`

Enable: `systemctl enable --now NetworkManager.service`

Autostart applet:
```ini
exec-once = nm-applet --indicator
```

---

## Color Temperature

| Package | Notes |
|---------|-------|
| **hyprsunset** | First-party, adjusts color temp by schedule |
| gammastep | Location-based color temperature |

Arch: `hyprsunset` / `gammastep`

---

## Theming

### GTK Themes

| Theme | Notes |
|-------|-------|
| **catppuccin-gtk** | Popular dark theme, Mocha/Macchiato/Frappe/Latte variants |
| adw-gtk3 | Matches GNOME's Adwaita, pairs well with GTK4 apps |
| Dracula | Classic dark theme |
| Gruvbox GTK | Warm retro colors |
| Tokyo Night | Cooler dark theme |

Apply GTK theme:
```ini
env = GTK_THEME, catppuccin-mocha-blue-standard+default
```
Or use `nwg-look` (GUI) / `gsettings`.

### Icon Themes

| Theme | Notes |
|-------|-------|
| **Papirus** | Most popular, extensive coverage |
| **Tela** | Clean, modern |
| Catppuccin Papirus | Catppuccin-colored Papirus |

Arch: `papirus-icon-theme`

### Cursor Themes

| Theme | Notes |
|-------|-------|
| **Bibata-Modern-Classic** | Popular, clean cursors |
| **Catppuccin Cursors** | Matches catppuccin theme |
| **Hyprcursor** | First-party high-DPI cursor format |

Set cursor:
```ini
env = XCURSOR_THEME, Bibata-Modern-Classic
env = XCURSOR_SIZE, 24
```

### Fonts

| Font | Notes |
|------|-------|
| **JetBrainsMono Nerd Font** | Most popular for ricing, coding |
| **FiraCode Nerd Font** | Ligatures, popular |
| **Hack Nerd Font** | Clean, readable |
| **CaskaydiaCove Nerd Font** | Cascadia Code with Nerd Font patches |
| noto-fonts | Required sans-serif fallback |
| noto-fonts-emoji | Emoji rendering |

Arch: `ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji`

---

## Screen Recording

| Package | Notes |
|---------|-------|
| **obs-studio** | Full-featured, requires pipewire for Wayland capture |
| **wf-recorder** | Simple CLI screen recorder |
| kooha | Simple GUI recorder for Wayland |

Arch: `obs-studio wf-recorder`

---

## Auto-mount

| Package | Notes |
|---------|-------|
| **udiskie** | Auto-mounts USB drives using udisks2 |

Arch: `udiskie`

Autostart:
```ini
exec-once = udiskie
```

---

## Polkit

Authentication agents handle password prompts for privilege elevation.

| Package | Notes |
|---------|-------|
| **hyprpolkitagent** | First-party, integrates with Hyprland |
| polkit-gnome | GNOME's agent, widely compatible |
| lxqt-policykit | Lightweight Qt agent |

Arch: `hyprpolkitagent` / `polkit-gnome`

Autostart:
```ini
# hyprpolkitagent (preferred)
exec-once = systemctl --user start hyprpolkitagent

# polkit-gnome (alternative)
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
```

---

## Login / Display Managers

| Package | Notes |
|---------|-------|
| **SDDM** | Most popular with Hyprland; Qt-based, supports Wayland-native mode |
| **greetd** + **tuigreet** | Minimal, terminal-based; common in minimal rices |
| **ly** | TUI display manager; very minimal |
| **uwsm** | Universal Wayland Session Manager; manages session lifecycle with systemd |

Arch: `sddm` / `greetd` (AUR)

---

## System Info / Monitoring

| Package | Notes |
|---------|-------|
| **fastfetch** | Fast CLI system info display (neofetch successor) |
| **btop** | Beautiful TUI resource monitor (CPU, RAM, disk, network) |
| **hyprsysteminfo** | First-party Hyprland system info GUI |

Arch: `fastfetch btop`

---

## Extended Status Bar / Shell Options

Beyond waybar, for users who want more than a status bar:

| Package | Notes | Arch |
|---------|-------|------|
| **ags** (Aylur's GTK Shell) | TypeScript/JSX shell framework — bar, notifications, launcher, OSD, quick settings, power menu in one codebase. Uses Astal libraries for system integration. Most powerful option but requires TypeScript knowledge. | `aylurs-gtk-shell-git` (AUR) |
| **hyprpanel** | Pre-built shell for Hyprland built on AGS/Astal. Bar + notification center + OSD + launcher with minimal JSON config. Easier than raw AGS. | `hyprpanel` (AUR) |
| **eww** | Declarative widget system in Rust/Yuck DSL; maximum flexibility | `eww` (AUR) |

**AGS Astal library packages** (install what you need — `aylurs-gtk-shell-git` pulls core deps):

| Package | Purpose | Arch |
|---------|---------|------|
| `astal-battery-git` | Battery monitoring (UPower) | AUR |
| `astal-bluetooth-git` | Bluetooth control (BlueZ) | AUR |
| `astal-hyprland-git` | Hyprland IPC (workspaces, clients, monitors) | AUR |
| `astal-mpris-git` | Media player control (replaces playerctl) | AUR |
| `astal-network-git` | NetworkManager WiFi/wired | AUR |
| `astal-notifd-git` | Notification daemon (replaces dunst/mako/swaync) | AUR |
| `astal-tray-git` | System tray | AUR |
| `astal-wireplumber-git` | Audio control via PipeWire (replaces pamixer/wpctl) | AUR |
| `astal-apps-git` | Application launcher queries | AUR |
| `astal-power-profiles-git` | Power profile switching | AUR |
| `astal-auth-git` | PAM authentication (for lock screens) | AUR |
| `astal-cava-git` | Audio visualization | AUR |

When the user chooses AGS, many standalone tools become optional — AGS with Astal libraries replaces waybar, dunst/mako/swaync, wofi/rofi/fuzzel, pamixer, and playerctl.

---

## Screenshot Annotation

| Package | Notes |
|---------|-------|
| **swappy** | Pipe grim output into swappy for quick markup |
| **satty** | Modern Rust-based annotation tool; pair with grim |

Arch: `swappy` / `satty` (AUR)

---

## Color Picker

| Package | Notes |
|---------|-------|
| **hyprpicker** | First-party; click any pixel, get its hex/RGB value |

Arch: `hyprpicker` (AUR or hypr repo)

---

## Shells

| Name | Notes |
|------|-------|
| **bash** | Pre-installed on Arch; POSIX-compatible; universal |
| **zsh** | Most popular for ricing; huge plugin ecosystem; superior completions |
| **fish** | Best out-of-box UX; syntax highlighting + suggestions built-in; NOT POSIX-compatible |

**Default recommendation:** `zsh`

Arch: `zsh` / `fish` (bash is pre-installed)

Essential Zsh plugins (available as system packages):
```bash
sudo pacman -S zsh-syntax-highlighting zsh-autosuggestions zsh-completions
```

Fish plugin manager:
```fish
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
```

---

## Shell Prompts

| Name | Shells | Notes |
|------|--------|-------|
| **starship** | bash, zsh, fish | Cross-shell, Rust-based, fast, auto-detects context |
| **powerlevel10k** | zsh only | Most popular Zsh prompt; instant prompt; interactive wizard |
| **oh-my-posh** | bash, zsh, fish | Cross-shell, JSON themes; less popular on Linux |

**Default recommendation:** `starship` (works with any shell, minimal config)

Arch: `starship` / `zsh-theme-powerlevel10k` / `oh-my-posh` (AUR)

---

## Modern CLI Utilities

Popular Rust-based replacements for traditional Unix tools. Install all or pick favorites.

| Name | Replaces | Arch package | Notes |
|------|----------|-------------|-------|
| **eza** | `ls` | `eza` | Git-aware, icons, tree view |
| **bat** | `cat` | `bat` | Syntax highlighting, line numbers |
| **fd** | `find` | `fd` | Simpler syntax, respects .gitignore |
| **ripgrep** | `grep` | `ripgrep` | Extremely fast, .gitignore aware |
| **fzf** | — | `fzf` | Fuzzy finder for files/history/processes |
| **zoxide** | `cd` | `zoxide` | Learning directory jumper |
| **delta** | `diff` | `git-delta` | Syntax-highlighted git diffs |
| **dust** | `du` | `dust` | Visual disk usage |
| **duf** | `df` | `duf` | Colorful disk free |
| **procs** | `ps` | `procs` | Human-readable process viewer |

Arch (all at once):
```bash
sudo pacman -S eza bat fd ripgrep fzf zoxide git-delta dust duf procs
```

---

## Quick Reference: Minimum Viable Setup (Arch)

```bash
# Core Hypr ecosystem
sudo pacman -S hyprland hyprpaper hypridle hyprlock \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk

# Audio
sudo pacman -S pipewire wireplumber

# Bar + launcher + notifications
sudo pacman -S waybar wofi dunst

# Terminal + clipboard + screenshots
sudo pacman -S kitty wl-clipboard cliphist grim slurp

# Network + Bluetooth
sudo pacman -S networkmanager network-manager-applet \
  bluez bluez-utils blueman

# Theming
sudo pacman -S nwg-look papirus-icon-theme \
  ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji

# Utilities
sudo pacman -S brightnessctl pamixer playerctl pavucontrol udiskie

# Shell + prompt
sudo pacman -S zsh starship zsh-syntax-highlighting \
  zsh-autosuggestions zsh-completions

# Modern CLI utilities
sudo pacman -S eza bat fd ripgrep fzf zoxide fastfetch btop

# Auth agent (AUR or hypr repos)
yay -S hyprpolkitagent
```
