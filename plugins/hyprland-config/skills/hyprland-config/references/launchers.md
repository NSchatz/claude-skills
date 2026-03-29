---
title: Application Launcher Configuration Reference
weight: 6
---

# Application Launcher Reference

Complete configuration and theming guide for the four major application launchers used with Hyprland: wofi, rofi-wayland, fuzzel, and anyrun. Load this when generating launcher configs or when the user asks about launcher styling.

## Table of Contents
- [Choosing a launcher](#choosing-a-launcher)
- [wofi](#wofi)
- [rofi-wayland](#rofi-wayland)
- [fuzzel](#fuzzel)
- [anyrun](#anyrun)
- [Hyprland integration](#hyprland-integration)

---

## Choosing a launcher

| Feature | wofi | rofi-wayland | fuzzel | anyrun |
|---------|------|-------------|--------|--------|
| Config format | key=value + CSS | RASI (CSS-like) | INI | RON + CSS |
| Theming power | Good (GTK CSS) | Excellent (full layout control) | Basic (colors only) | Good (GTK4 CSS) |
| Modes | run, drun, dmenu | drun, run, window, ssh, filebrowser, combi, dmenu | drun, dmenu | Plugin-based (modular) |
| Fuzzy matching | Yes | Yes | Yes | Yes |
| Icons | Yes | Yes | Yes | Yes |
| GTK version | GTK3 | GTK3 | None (native) | GTK4 |
| Maintenance | Unmaintained | Active (lbonn fork) | Active | Active |
| Weight | Medium | Medium | Very light | Medium |
| Wayland-native | Yes | Yes (wayland fork) | Yes | Yes |

**Recommendation**: fuzzel for minimal setups (lightweight, fast, well-maintained). rofi-wayland for maximum theming power. wofi works fine but is no longer maintained. anyrun for plugin extensibility.

---

## wofi

**Config**: `~/.config/wofi/config` (behavior) + `~/.config/wofi/style.css` (appearance)
**Package**: `wofi`

### config

```ini
show=drun
width=600
height=400
lines=12
prompt=Search...
matching=fuzzy
insensitive=true
allow_markup=true
allow_images=true
image_size=32
columns=1
sort_order=alphabetical
gtk_dark=true
layer=overlay
```

Key options:
- `show`: `drun` (desktop entries), `run` (PATH binaries), `dmenu` (stdin pipe)
- `matching`: `contains`, `fuzzy`, `multi-contains`
- `location`: 0=center, 1-8=edges/corners (numpad layout)
- `halign`/`valign`: `fill`, `start`, `end`, `center`
- `hide_scroll`: true/false
- `dynamic_lines`: true = shrink to fit results
- `cache_file`: `/dev/null` to disable frecency caching

### style.css — Complete themed example (Catppuccin Mocha)

```css
/* Main window */
window {
    background-color: rgba(30, 30, 46, 0.88);
    border: 2px solid rgba(203, 166, 247, 0.4);
    border-radius: 16px;
    font-family: "JetBrainsMono Nerd Font";
    font-size: 14px;
}

/* Search input */
#input {
    background-color: rgba(49, 50, 68, 0.8);
    border: none;
    border-radius: 12px;
    color: #cdd6f4;
    margin: 12px;
    padding: 8px 16px;
    font-size: 15px;
}

#input:focus {
    border: 1px solid rgba(203, 166, 247, 0.5);
}

/* Results list */
#inner-box {
    background-color: transparent;
    margin: 0 8px 8px 8px;
}

#outer-box {
    background-color: transparent;
}

#scroll {
    margin: 0;
}

/* Individual entries */
#entry {
    padding: 6px 12px;
    border-radius: 10px;
    color: #cdd6f4;
}

#entry:selected {
    background-color: rgba(203, 166, 247, 0.2);
    color: #cba6f7;
}

/* Entry text and icon */
#text {
    color: inherit;
}

#img {
    margin-right: 8px;
}

/* Unselected entries (hover state) */
#entry:hover {
    background-color: rgba(69, 71, 90, 0.5);
}
```

### CSS selectors reference

| Selector | Element |
|----------|---------|
| `window` | Main wofi window |
| `#outer-box` | Outermost container |
| `#input` | Search text entry |
| `#scroll` | Scroll container |
| `#inner-box` | Results container |
| `#entry` | Individual result row |
| `#entry:selected` | Currently highlighted row |
| `#text` | Entry label text |
| `#img` | Entry icon |
| `#unselected` | Non-highlighted entries |

### Colors file

Optional `~/.config/wofi/colors` — hex colors (one per line) accessible as CSS variables `--wofi-color0` through `--wofi-colorN`:

```
#1e1e2e
#cba6f7
#89b4fa
#a6e3a1
#f38ba8
```

---

## rofi-wayland

**Config**: `~/.config/rofi/config.rasi` (main config + theme, or separate theme files)
**Package**: `rofi-wayland` (AUR) — the Wayland-compatible fork of rofi

rofi has the most powerful theming system of all launchers. Themes use RASI format — a CSS-like language with a widget tree hierarchy.

### config.rasi — Main config

```rasi
configuration {
    modi: "drun,run,filebrowser";
    show-icons: true;
    icon-theme: "Papirus";
    display-drun: " Apps";
    display-run: " Run";
    display-filebrowser: " Files";
    drun-display-format: "{name}";
    font: "JetBrainsMono Nerd Font 12";
    click-to-exit: true;
}

/* Import theme — either inline below or from a file */
@theme "catppuccin"
```

### Theme file — Complete example (Catppuccin Mocha)

Save as `~/.config/rofi/themes/catppuccin.rasi`:

```rasi
* {
    bg:          #1e1e2eee;
    bg-alt:      #313244;
    bg-selected: #45475a;
    fg:          #cdd6f4;
    fg-muted:    #6c7086;
    accent:      #cba6f7;
    urgent:      #f38ba8;

    background-color: transparent;
    text-color: @fg;
    margin: 0;
    padding: 0;
    spacing: 0;
}

window {
    background-color: @bg;
    border: 2px solid;
    border-color: @accent;
    border-radius: 16px;
    width: 650px;
    location: center;
    anchor: center;
}

mainbox {
    children: [ inputbar, message, listview ];
}

inputbar {
    background-color: @bg-alt;
    border-radius: 12px 12px 0 0;
    padding: 12px 16px;
    spacing: 8px;
    children: [ prompt, entry ];
}

prompt {
    text-color: @accent;
    font: "JetBrainsMono Nerd Font Bold 13";
}

entry {
    placeholder: "Search...";
    placeholder-color: @fg-muted;
}

message {
    background-color: @bg-alt;
    padding: 8px 16px;
}

textbox {
    text-color: @fg;
}

listview {
    lines: 10;
    columns: 1;
    fixed-height: true;
    padding: 4px;
    spacing: 2px;
    scrollbar: false;
}

element {
    padding: 8px 16px;
    spacing: 12px;
    border-radius: 10px;
}

element selected.normal {
    background-color: @accent;
    text-color: @bg;
}

element selected.urgent {
    background-color: @urgent;
    text-color: @bg;
}

element normal.active {
    text-color: @accent;
}

element-icon {
    size: 24px;
    vertical-align: 0.5;
}

element-text {
    text-color: inherit;
    vertical-align: 0.5;
}
```

### RASI widget hierarchy

```
window
└── mainbox
    ├── inputbar
    │   ├── prompt        (mode label, e.g., " Apps")
    │   ├── textbox-prompt-colon
    │   ├── entry         (search text)
    │   ├── num-filtered-rows
    │   └── case-indicator
    ├── message
    │   └── textbox
    ├── listview
    │   └── element       (one per result)
    │       ├── element-icon
    │       └── element-text
    └── mode-switcher
        └── button        (one per mode)
```

### RASI property reference

**Layout**: `padding`, `margin`, `spacing`, `border`, `border-radius`, `width`, `height`, `orientation` (horizontal/vertical), `children` (widget list)

**Colors**: `#RRGGBB`, `#RRGGBBAA`, `rgb(r,g,b)`, `rgba(r,g,b,a)`, `hsl(h,s,l)`, `hsla(h,s,l,a)`, named colors. Variables with `@name`.

**Text**: `font`, `text-color`, `highlight` (matching text style: `bold`, `underline`, `italic`, or a color)

**Positioning**: `location` (center, north, south, east, west, north-east, etc.), `anchor`, `x-offset`, `y-offset`

**State selectors**: `element normal.normal`, `element normal.urgent`, `element normal.active`, `element selected.normal`, `element selected.urgent`, `element selected.active`, `element alternate.normal`

### Useful rofi commands

```bash
rofi -dump-config        # print full config with defaults
rofi -dump-theme         # print current theme
rofi -show drun -theme mytheme  # launch with specific theme
rofi -dmenu              # dmenu mode (pipe input)
```

---

## fuzzel

**Config**: `~/.config/fuzzel/fuzzel.ini`
**Package**: `fuzzel`

fuzzel is the lightest launcher — no GTK dependency, native Wayland. Theming is through config options only (no separate CSS file), but covers the essentials.

### Complete themed config (Catppuccin Mocha)

```ini
[main]
font=JetBrainsMono Nerd Font:size=12
dpi-aware=auto
prompt="  "
icon-theme=Papirus
icons-enabled=yes
fields=name,generic,comment,categories,filename,keywords
terminal=kitty
lines=12
width=55
horizontal-pad=12
vertical-pad=8
inner-pad=4
layer=overlay
exit-on-keyboard-focus-loss=yes
list-executables-in-path=no

[colors]
# Format: RRGGBBAA
background=1e1e2eee
text=cdd6f4ff
prompt=cba6f7ff
placeholder=6c7086ff
input=cdd6f4ff
match=cba6f7ff
selection=45475aff
selection-text=cdd6f4ff
selection-match=cba6f7ff
counter=6c7086ff
border=cba6f780

[border]
width=2
radius=16

[key-bindings]
# Vim-style navigation (optional)
prev=Up Control+k Control+p
next=Down Control+j Control+n
```

### Color format

fuzzel uses `RRGGBBAA` — 8-character hex without `#` prefix. The alpha channel is required.

### Theme includes

fuzzel supports `include` directives for reusable theme files:

```ini
[main]
include=/path/to/catppuccin-mocha.ini
```

This makes it easy to switch color schemes without editing the main config.

---

## anyrun

**Config**: `~/.config/anyrun/config.ron` + `~/.config/anyrun/style.css`
**Package**: `anyrun-git` (AUR)

anyrun uses RON (Rust Object Notation) for config and GTK4 CSS for styling. It's plugin-based — each search mode is a separate `.so` file.

### config.ron

```ron
Config(
    x: Fraction(0.5),          // horizontal position (0.0-1.0)
    y: Fraction(0.3),          // vertical position
    width: Fraction(0.35),     // width as fraction of screen
    hide_icons: false,
    hide_plugin_info: false,
    close_on_click: false,
    show_results_immediately: true,
    max_entries: Some(10),
    ignore_exclusive_zones: false,
    layer: Overlay,            // Background, Bottom, Top, Overlay

    plugins: [
        "libapplications.so",     // .desktop entry launcher
        "libsymbols.so",          // unicode symbol search
        "librink.so",             // calculator + unit conversion
        "libshell.so",            // shell command execution
        "libtranslate.so",        // translation
        "libdictionary.so",       // dictionary lookup
    ],
)
```

### Plugin-specific config files

Each plugin has its own config in `~/.config/anyrun/`:

**applications.ron:**
```ron
Config(
    desktop_actions: false,
    max_entries: 8,
    terminal: Some("kitty"),
)
```

**symbols.ron:**
```ron
Config(
    prefix: "::",
    max_entries: 5,
)
```

### style.css — Themed example (Catppuccin Mocha)

```css
/* Main window */
#window {
    background: transparent;
}

/* Search box container */
#main {
    background: rgba(30, 30, 46, 0.9);
    border: 2px solid rgba(203, 166, 247, 0.4);
    border-radius: 16px;
    padding: 8px;
}

/* Search input */
#entry {
    background: rgba(49, 50, 68, 0.8);
    border: none;
    border-radius: 12px;
    color: #cdd6f4;
    font-family: "JetBrainsMono Nerd Font";
    font-size: 16px;
    min-height: 36px;
    padding: 4px 12px;
}

/* Results list */
#plugin {
    background: transparent;
    padding: 4px;
}

/* Plugin label */
#plugin label {
    color: #6c7086;
    font-size: 12px;
}

/* Individual result */
#match {
    background: transparent;
    border-radius: 10px;
    padding: 4px 8px;
}

#match:selected,
#match:hover {
    background: rgba(203, 166, 247, 0.2);
}

/* Result text */
#match .title {
    color: #cdd6f4;
    font-size: 14px;
}

#match .description {
    color: #a6adc8;
    font-size: 12px;
}
```

### CSS selectors reference

| Selector | Element |
|----------|---------|
| `#window` | Root window (set transparent for floating effect) |
| `#main` | Main container (search + results) |
| `#entry` | Search text input |
| `#plugin` | Plugin results section |
| `#match` | Individual result item |
| `#match:selected` | Highlighted result |
| `#match:hover` | Hovered result |

---

## Hyprland integration

### Keybinds

```ini
# wofi
bindd = $mainMod, D, Open app launcher, exec, wofi --show drun

# rofi
bindd = $mainMod, D, Open app launcher, exec, rofi -show drun

# fuzzel
bindd = $mainMod, D, Open app launcher, exec, fuzzel

# anyrun
bindd = $mainMod, D, Open app launcher, exec, anyrun
```

### Layer rules for blur

```ini
layerrule = blur true, match:namespace wofi
layerrule = blur true, match:namespace rofi
# fuzzel — uses "launcher" as its layer namespace
layerrule = blur true, match:namespace launcher
# anyrun — check with hyprctl layers
layerrule = blur true, match:namespace anyrun
```

### Clipboard history with launchers

```ini
# wofi
bindd = $mainMod, V, Clipboard history, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy

# rofi
bindd = $mainMod, V, Clipboard history, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy

# fuzzel
bindd = $mainMod, V, Clipboard history, exec, cliphist list | fuzzel --dmenu | cliphist decode | wl-copy
```

### Emoji picker pattern

```bash
# rofi emoji picker (requires rofi-emoji plugin or a Unicode list)
bindd = $mainMod, period, Emoji picker, exec, rofi -modi emoji -show emoji

# anyrun has built-in symbols plugin (prefix with ::)
```
