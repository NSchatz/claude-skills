# Hyprland Theming Pipeline

Full reference for GTK, Qt, icon, cursor, and font theming. Load this when the user asks about cursor inconsistency, GTK app appearance, Qt app styling, icon themes, or font rendering.

---

## GTK theming

GTK apps (Nautilus, Thunar, Firefox, most GNOME apps) pick up their theme from multiple sources. Set all of them for consistency.

### 1. GTK_THEME env var (immediate, broad effect)

```ini
# env.conf (or ~/.config/uwsm/env for uwsm users)
env = GTK_THEME,catppuccin-mocha-mauve-standard+default
```

> **IMPORTANT**: The AUR package `catppuccin-gtk-theme-mocha` installs themes as `catppuccin-mocha-{accent}-standard+default` (e.g., `catppuccin-mocha-mauve-standard+default`), NOT `Catppuccin-Mocha-Standard-Mauve-Dark`. Always check `/usr/share/themes/` for actual installed names. The install script should detect names dynamically rather than hardcoding them.

Available GTK themes: `catppuccin-gtk-theme-mocha` (AUR), `Dracula`, `TokyoNight`, `Gruvbox-Dark`, `Nordic`.

### 2. settings.ini files

```ini
# ~/.config/gtk-3.0/settings.ini
[Settings]
gtk-theme-name=catppuccin-mocha-mauve-standard+default
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=catppuccin-mocha-mauve-cursors
gtk-cursor-theme-size=24
gtk-font-name=JetBrainsMono Nerd Font 11
gtk-application-prefer-dark-theme=1
```

```ini
# ~/.config/gtk-4.0/settings.ini
[Settings]
gtk-theme-name=catppuccin-mocha-mauve-standard+default
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=catppuccin-mocha-mauve-cursors
gtk-cursor-theme-size=24
gtk-font-name=JetBrainsMono Nerd Font 11
gtk-application-prefer-dark-theme=1
```

> **NOTE**: `nwg-look` writes settings without spaces around `=`. Both formats work but nwg-look will rewrite them without spaces. If the user runs nwg-look, the install script should detect Adwaita defaults and re-apply Catppuccin settings.

### 3. gsettings (runtime, affects running apps)

```bash
gsettings set org.gnome.desktop.interface gtk-theme      'catppuccin-mocha-mauve-standard+default'
gsettings set org.gnome.desktop.interface icon-theme      'Papirus-Dark'
gsettings set org.gnome.desktop.interface cursor-theme    'catppuccin-mocha-mauve-cursors'
gsettings set org.gnome.desktop.interface cursor-size     24
gsettings set org.gnome.desktop.interface font-name       'JetBrainsMono Nerd Font 11'
gsettings set org.gnome.desktop.interface color-scheme    'prefer-dark'
```

### 4. nwg-look (GUI tool — recommended)

`nwg-look` is the GTK settings manager for wlroots compositors. It writes all the above automatically.

```bash
# Install
sudo pacman -S nwg-look

# Run it to configure GTK theme, icons, cursors, fonts
nwg-look
```

**Add to install.sh** and suggest the user run it after installing packages.

---

## Qt theming

Qt apps need their own theming setup — they don't use GTK themes.

### qt5ct + qt6ct (settings GUIs)

```ini
# env.conf (non-uwsm)
env = QT_QPA_PLATFORMTHEME,qt5ct   # or qt6ct; qt5ct often handles both

# uwsm env (~/.config/uwsm/env)
export QT_QPA_PLATFORMTHEME=qt5ct
```

> **CRITICAL**: Without `QT_QPA_PLATFORMTHEME` set, qt5ct will refuse to launch with the error: "The QT_QPA_PLATFORMTHEME environment variable is not set (required values: qt5ct or qt6ct)." For uwsm users, this env var must be in `~/.config/uwsm/env` AND won't take effect until the next Hyprland session. The install script should also `export QT_QPA_PLATFORMTHEME=qt5ct` for the current session so the user can run qt5ct immediately after install.

```bash
# Install
sudo pacman -S qt5ct qt6ct

# Run to configure style, fonts, icons
qt5ct
```

### Kvantum (SVG-based theme engine)

For themes with custom shapes (not just color overrides), install Kvantum:

```bash
sudo pacman -S kvantum
# AUR themes: kvantum-theme-catppuccin, kvantum-theme-nordic
```

In qt5ct, set Style to `kvantum`. Then open `kvantummanager` to apply the SVG theme.

```ini
# env.conf — tell Qt to use Kvantum
env = QT_STYLE_OVERRIDE,kvantum
```

---

## Icon themes

```bash
# Papirus (most popular in rices)
sudo pacman -S papirus-icon-theme

# Catppuccin folder color patch (colors folder icons to accent color)
# AUR: catppuccin-papirus-folders-git
catppuccin-folders -t Papirus-Dark -a mocha -c mauve
```

Available accent colors: rosewater, flamingo, pink, mauve, red, maroon, peach, yellow, green, teal, sky, sapphire, blue, lavender.

Set in GTK settings and `~/.config/gtk-3.0/settings.ini`.

---

## Cursor themes

Cursor consistency across Wayland, XWayland, and GTK requires setting it in four places:

### 1. Hyprland env vars

```ini
# env.conf
env = XCURSOR_THEME,Bibata-Modern-Classic
env = XCURSOR_SIZE,24
env = HYPRCURSOR_THEME,Bibata-Modern-Classic   # native hyprcursor format if available
env = HYPRCURSOR_SIZE,24
```

### 2. XWayland cursor fallback

```ini
# ~/.icons/default/index.theme
[Icon Theme]
Name=Default
Comment=Default Cursor Theme
Inherits=Bibata-Modern-Classic
```

### 3. Hyprland cursor block

```ini
# hyprland.conf
cursor {
    no_hardware_cursors = false
    hotspot_padding = 1
    inactive_timeout = 5    # hide cursor after N seconds of inactivity
    zoom_factor = 1.0
}
```

### 4. GTK settings (for GTK apps)

Set `gtk-cursor-theme-name` in both `settings.ini` files (see GTK section).

**Available cursor themes:** `Bibata-Modern-Classic` (AUR: `bibata-cursor-theme`), Catppuccin per-accent (AUR: `catppuccin-cursors-mocha` — installs `catppuccin-mocha-{accent}-cursors`, e.g., `catppuccin-mocha-mauve-cursors`), `Nordzy-cursors` (AUR).

> **IMPORTANT**: `catppuccin-cursors-mocha` installs per-accent cursor themes (mauve, blue, green, etc.), NOT a single `Catppuccin-Mocha-Dark`. Check `/usr/share/icons/catppuccin-mocha-*-cursors` for installed variants. The install script should detect the actual installed cursor name dynamically.

---

## Font rendering (fontconfig)

For sharp, well-hinted fonts in all apps:

```xml
<!-- ~/.config/fontconfig/fonts.conf -->
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <!-- Antialiasing -->
  <match target="font">
    <edit name="antialias" mode="assign"><bool>true</bool></edit>
    <edit name="hinting" mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
    <edit name="rgba" mode="assign"><const>rgb</const></edit>
    <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
  </match>

  <!-- Prefer Nerd Font variants -->
  <alias>
    <family>monospace</family>
    <prefer>
      <family>JetBrainsMono Nerd Font</family>
    </prefer>
  </alias>
</fontconfig>
```

---

## pywal / wallust (dynamic theming)

Generate a color scheme from the current wallpaper, then push it to all apps.

### wallust (modern pywal replacement)

```bash
# AUR: wallust
wallust run /path/to/wallpaper.png

# Outputs colors to ~/.cache/wallust/
# Templates: ~/.config/wallust/templates/
```

### pywal

```bash
sudo pacman -S python-pywal   # or AUR: pywal

# Generate scheme from wallpaper
wal -i /path/to/wallpaper.png --backend colorz

# Colors written to ~/.cache/wal/colors*
```

### Integration with Hyprland

Add to `autostart.conf`:
```ini
exec-once = wal -i $(cat ~/.config/hypr/wallpaper_path) -n -s -t -e
```

Pull colors into hyprland.conf via pywal-generated file:
```ini
source = ~/.cache/wal/colors-hyprland.conf   # if pywal-hyprland template exists
```

For waybar, source the colors file in CSS:
```css
@import "/home/USER/.cache/wal/colors-waybar.css";
```

**When to suggest:** Only suggest pywal/wallust if the user specifically wants dynamic wallpaper-based theming or mentions it. Most rices use a fixed palette (Catppuccin, Tokyo Night, etc.) and don't need it.

---

## ags / hyprpanel

For comprehensive AGS configuration, load `references/ags.md` — it covers the full TypeScript/JSX framework, all Astal libraries, widget types, CSS theming, and complete component examples.

**Quick summary:**
- **AGS** — Full TypeScript/JSX shell framework. Can replace waybar + notification daemon + launcher + OSD with a single unified codebase. Config: `~/.config/ags/app.ts` + widget `.tsx` files + `style.scss`. Suggest when the user wants a highly customized bar with OSD popups, power menu, animated overlays, per-app widgets, notification center, or app launcher — all in one framework.
- **HyprPanel** — Pre-built shell for Hyprland built on AGS/Astal. Config: `~/.config/hyprpanel/config.json` — single JSON file drives the entire theme. Suggest when the user wants something more polished than waybar without writing TypeScript. Install: `yay -S hyprpanel`.
