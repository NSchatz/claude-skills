#!/usr/bin/env bash
# ── Hyprland Environment Install Script ──────────────────────────
# Catppuccin Mocha | kitty | wofi | dunst | waybar | hyprpaper | hyprlock | hypridle
# Target: Arch Linux with AUR
set -euo pipefail

# ── Colors ───────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

SUCCEEDED=()
FAILED=()
WARNINGS=()

# ── Pre-flight checks ───────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
    err "Do not run this script as root. Run as your normal user."
    exit 1
fi

if ! command -v pacman &>/dev/null; then
    err "pacman not found. This script is for Arch Linux."
    exit 1
fi

if ! sudo -v; then
    err "Cannot obtain sudo access."
    exit 1
fi

# Keep sudo alive
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_PID=$!
trap "kill $SUDO_PID 2>/dev/null" EXIT

if ! ping -c 1 archlinux.org &>/dev/null; then
    err "No internet connection."
    exit 1
fi

info "Pre-flight checks passed."

# ── AUR helper ───────────────────────────────────────────────────
AUR_HELPER=""
if command -v paru &>/dev/null; then
    AUR_HELPER="paru"
elif command -v yay &>/dev/null; then
    AUR_HELPER="yay"
else
    info "No AUR helper found. Installing yay..."
    sudo pacman -S --needed --noconfirm base-devel git
    TMPDIR=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$TMPDIR/yay-bin"
    (cd "$TMPDIR/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$TMPDIR"
    AUR_HELPER="yay"
fi

ok "AUR helper: $AUR_HELPER"

# ── Check for conflicting packages ──────────────────────────────
if pacman -Qi xdg-desktop-portal-kde &>/dev/null; then
    warn "xdg-desktop-portal-kde is installed and conflicts with Hyprland screensharing."
    read -rp "Remove it? [y/N] " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        sudo pacman -Rns --noconfirm xdg-desktop-portal-kde
    fi
fi

# ── Official repo packages ──────────────────────────────────────
OFFICIAL_PKGS=(
    hyprland
    hyprpaper
    hyprlock
    hypridle
    hyprpolkitagent
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    kitty
    wofi
    dunst
    waybar
    grim
    slurp
    wl-clipboard
    brightnessctl
    playerctl
    nm-applet
    network-manager-applet
    pavucontrol
    qt5ct
    nwg-look
    ttf-jetbrains-mono-nerd
    wlogout
    polkit-gnome
)

info "Installing official packages..."
if sudo pacman -S --needed --noconfirm "${OFFICIAL_PKGS[@]}" 2>/dev/null; then
    ok "Official packages installed successfully."
    SUCCEEDED+=("official-packages")
else
    warn "Batch install had issues. Falling back to one-by-one..."
    for pkg in "${OFFICIAL_PKGS[@]}"; do
        if sudo pacman -S --needed --noconfirm "$pkg" &>/dev/null; then
            SUCCEEDED+=("$pkg")
        else
            FAILED+=("$pkg")
            warn "Failed to install: $pkg"
        fi
    done
fi

# ── AUR packages ────────────────────────────────────────────────
AUR_PKGS=(
    catppuccin-gtk-theme-mocha
    catppuccin-cursors-mocha
)

info "Installing AUR packages..."
for pkg in "${AUR_PKGS[@]}"; do
    if $AUR_HELPER -S --needed --noconfirm "$pkg" &>/dev/null; then
        ok "Installed AUR package: $pkg"
        SUCCEEDED+=("$pkg")
    else
        err "Failed to install AUR package: $pkg"
        FAILED+=("$pkg")
    fi
done

# ── Deploy config files ─────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info "Deploying configuration files..."

# Hyprland configs
mkdir -p ~/.config/hypr
for f in hyprland.conf monitors.conf env.conf autostart.conf keybinds.conf windowrules.conf animations.conf hyprpaper.conf hyprlock.conf hypridle.conf; do
    if [[ -f "$SCRIPT_DIR/$f" ]]; then
        cp "$SCRIPT_DIR/$f" ~/.config/hypr/"$f"
        ok "Deployed $f"
    fi
done

# Waybar
mkdir -p ~/.config/waybar
if [[ -d "$SCRIPT_DIR/waybar" ]]; then
    cp "$SCRIPT_DIR/waybar/config.jsonc" ~/.config/waybar/
    cp "$SCRIPT_DIR/waybar/style.css" ~/.config/waybar/
    ok "Deployed waybar config"
fi

# Dunst
mkdir -p ~/.config/dunst
if [[ -d "$SCRIPT_DIR/dunst" ]]; then
    cp "$SCRIPT_DIR/dunst/dunstrc" ~/.config/dunst/
    ok "Deployed dunst config"
fi

# Wofi
mkdir -p ~/.config/wofi
if [[ -d "$SCRIPT_DIR/wofi" ]]; then
    cp "$SCRIPT_DIR/wofi/config" ~/.config/wofi/
    cp "$SCRIPT_DIR/wofi/style.css" ~/.config/wofi/
    ok "Deployed wofi config"
fi

# Kitty
mkdir -p ~/.config/kitty
if [[ -d "$SCRIPT_DIR/kitty" ]]; then
    cp "$SCRIPT_DIR/kitty/kitty.conf" ~/.config/kitty/
    ok "Deployed kitty config"
fi

# ── GTK theming ──────────────────────────────────────────────────
info "Configuring GTK theme..."

# Detect actual installed theme name
GTK_THEME=""
for theme_dir in /usr/share/themes/catppuccin-mocha-*-standard+default; do
    if [[ -d "$theme_dir" ]]; then
        GTK_THEME=$(basename "$theme_dir")
        break
    fi
done

if [[ -z "$GTK_THEME" ]]; then
    GTK_THEME="catppuccin-mocha-mauve-standard+default"
    warn "Could not detect installed GTK theme name. Using default: $GTK_THEME"
fi

# Detect actual cursor theme name
CURSOR_THEME=""
for cursor_dir in /usr/share/icons/catppuccin-mocha-*-cursors; do
    if [[ -d "$cursor_dir" ]]; then
        CURSOR_THEME=$(basename "$cursor_dir")
        break
    fi
done

if [[ -z "$CURSOR_THEME" ]]; then
    CURSOR_THEME="catppuccin-mocha-mauve-cursors"
    warn "Could not detect installed cursor theme name. Using default: $CURSOR_THEME"
fi

# GTK 3
mkdir -p ~/.config/gtk-3.0
cat > ~/.config/gtk-3.0/settings.ini << GTKEOF
[Settings]
gtk-theme-name=$GTK_THEME
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=$CURSOR_THEME
gtk-cursor-theme-size=24
gtk-font-name=JetBrainsMono Nerd Font 11
gtk-application-prefer-dark-theme=true
GTKEOF
ok "GTK 3 settings written"

# GTK 4
mkdir -p ~/.config/gtk-4.0
cat > ~/.config/gtk-4.0/settings.ini << GTKEOF
[Settings]
gtk-theme-name=$GTK_THEME
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=$CURSOR_THEME
gtk-cursor-theme-size=24
gtk-font-name=JetBrainsMono Nerd Font 11
gtk-application-prefer-dark-theme=true
GTKEOF
ok "GTK 4 settings written"

# XWayland cursor fallback
mkdir -p ~/.icons/default
cat > ~/.icons/default/index.theme << CURSOREOF
[Icon Theme]
Name=Default
Comment=Default Cursor Theme
Inherits=$CURSOR_THEME
CURSOREOF
ok "XWayland cursor fallback configured"

# Create Pictures directory for screenshots
mkdir -p ~/Pictures

# ── Post-install verification ────────────────────────────────────
info "Verifying installation..."
echo ""

MISSING_CMDS=()
for cmd in hyprland hyprpaper hyprlock hypridle kitty wofi dunst waybar grim slurp wl-copy brightnessctl playerctl; do
    if command -v "$cmd" &>/dev/null; then
        ok "Found: $cmd"
    else
        err "Missing: $cmd"
        MISSING_CMDS+=("$cmd")
    fi
done

# Verify font
if fc-list : family | grep -qi "JetBrainsMono Nerd Font"; then
    ok "Font: JetBrainsMono Nerd Font is installed"
else
    warn "Font: JetBrainsMono Nerd Font not found (check fc-list)"
    WARNINGS+=("JetBrainsMono Nerd Font not found")
fi

# Verify cursor theme
if ls -d /usr/share/icons/catppuccin-mocha-*-cursors &>/dev/null; then
    ok "Cursor theme: Catppuccin Mocha cursors installed"
else
    warn "Cursor theme: Catppuccin Mocha cursors not found in /usr/share/icons/"
    WARNINGS+=("Catppuccin cursor theme not found")
fi

# Verify GTK theme
if ls -d /usr/share/themes/catppuccin-mocha-*-standard+default &>/dev/null; then
    ok "GTK theme: Catppuccin Mocha installed"
else
    warn "GTK theme: Catppuccin Mocha not found in /usr/share/themes/"
    WARNINGS+=("Catppuccin GTK theme not found")
fi

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Installation Summary${NC}"
echo -e "${BOLD}════════════════════════════════════════════${NC}"

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo -e "${RED}Failed packages:${NC}"
    for pkg in "${FAILED[@]}"; do
        echo -e "  ${RED}x${NC} $pkg"
    done
fi

if [[ ${#MISSING_CMDS[@]} -gt 0 ]]; then
    echo -e "${RED}Missing commands:${NC}"
    for cmd in "${MISSING_CMDS[@]}"; do
        echo -e "  ${RED}x${NC} $cmd"
    done
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Warnings:${NC}"
    for w in "${WARNINGS[@]}"; do
        echo -e "  ${YELLOW}!${NC} $w"
    done
fi

if [[ ${#FAILED[@]} -eq 0 && ${#MISSING_CMDS[@]} -eq 0 ]]; then
    echo -e "${GREEN}All packages installed successfully!${NC}"
fi

echo ""
info "Next steps:"
echo "  1. Place a wallpaper at ~/Pictures/wallpaper.png"
echo "  2. Run 'nwg-look' to apply GTK settings visually"
echo "  3. Run 'qt5ct' to configure Qt app theming"
echo "  4. Log out and start Hyprland from your TTY or display manager"
echo ""
ok "Done!"
