# Hyprland Theming Pipeline

Full reference for GTK, Qt, icon, cursor, and font theming. Load this when the user asks about cursor inconsistency, GTK app appearance, Qt app styling, icon themes, or font rendering.

---

## GTK theming

GTK apps (Nautilus, Thunar, Firefox, most GNOME apps) pick up their theme from multiple sources. Set all of them for consistency.

### 1. GTK_THEME env var (immediate, broad effect)

```ini
# env.conf
env = GTK_THEME,Catppuccin-Mocha-Standard-Mauve-Dark
```

Available GTK themes: `catppuccin-gtk` (AUR: `catppuccin-gtk-theme-mocha`), `Dracula`, `TokyoNight`, `Gruvbox-Dark`, `Nordic`.

### 2. settings.ini files

```ini
# ~/.config/gtk-3.0/settings.ini
[Settings]
gtk-theme-name = Catppuccin-Mocha-Standard-Mauve-Dark
gtk-icon-theme-name = Papirus-Dark
gtk-cursor-theme-name = Bibata-Modern-Classic
gtk-cursor-theme-size = 24
gtk-font-name = JetBrainsMono Nerd Font 11
gtk-application-prefer-dark-theme = 1
```

```ini
# ~/.config/gtk-4.0/settings.ini
[Settings]
gtk-theme-name = Catppuccin-Mocha-Standard-Mauve-Dark
gtk-icon-theme-name = Papirus-Dark
gtk-cursor-theme-name = Bibata-Modern-Classic
gtk-cursor-theme-size = 24
gtk-font-name = JetBrainsMono Nerd Font 11
gtk-application-prefer-dark-theme = 1
```

### 3. gsettings (runtime, affects running apps)

```bash
gsettings set org.gnome.desktop.interface gtk-theme      'Catppuccin-Mocha-Standard-Mauve-Dark'
gsettings set org.gnome.desktop.interface icon-theme      'Papirus-Dark'
gsettings set org.gnome.desktop.interface cursor-theme    'Bibata-Modern-Classic'
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
# env.conf
env = QT_QPA_PLATFORMTHEME,qt5ct   # or qt6ct; qt5ct often handles both
```

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

**Available cursor themes:** `Bibata-Modern-Classic` (AUR: `bibata-cursor-theme`), `Catppuccin-Mocha-Dark` (AUR: `catppuccin-cursors-mocha`), `Nordzy-cursors` (AUR).

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

### ags (Aylur's GTK Shell)

Full JavaScript/TypeScript widget system. Can create bars, overlays, popups, OSD anywhere. Much more powerful than waybar but significantly steeper learning curve.

- Config: `~/.config/ags/config.js` (or `app.ts`)
- Widgets are JS/TS functions returning GTK widgets
- Can animate in/out as overlays; reacts to system state with real JS logic

**When to suggest:** If the user wants a highly customized bar with OSD popups, power menu, animated overlays, or per-app widgets — or if they specifically mention ags.

### hyprpanel

Built on ags, designed for Hyprland with minimal setup. Provides bar + notification center + volume/brightness OSD + app launcher in one package.

- Config: `~/.config/hyprpanel/config.json` — single color palette drives everything
- Much easier than raw ags; less flexible than custom ags
- OSD popups (volume/brightness bubbles) look significantly more polished than typical waybar

```bash
# AUR: hyprpanel
```

**When to suggest:** If the user wants something more polished than waybar without writing JavaScript, or mentions hyprpanel specifically.
