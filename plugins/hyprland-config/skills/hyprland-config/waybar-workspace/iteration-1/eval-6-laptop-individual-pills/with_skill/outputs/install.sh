#!/usr/bin/env bash
# ── Hyprland Environment Install Script ──────────────────────────────
# Tokyo Night | Kitty | Wofi | Mako | Waybar | Hyprlock | Hypridle
set -euo pipefail

# ── Colors ───────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

SUCCEEDED=()
FAILED=()
WARNINGS=()

# ── Pre-flight checks ───────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
    error "Do not run this script as root."
    exit 1
fi

if ! command -v pacman &>/dev/null; then
    error "This script requires pacman (Arch Linux)."
    exit 1
fi

if ! sudo -v; then
    error "Failed to obtain sudo access."
    exit 1
fi

# Keep sudo alive
while true; do sudo -n true; sleep 60; done 2>/dev/null &
SUDO_PID=$!
trap "kill $SUDO_PID 2>/dev/null" EXIT

if ! ping -c 1 archlinux.org &>/dev/null; then
    error "No internet connectivity detected."
    exit 1
fi

info "Pre-flight checks passed."

# ── AUR helper ───────────────────────────────────────────────────────
AUR_HELPER=""
if command -v paru &>/dev/null; then
    AUR_HELPER="paru"
elif command -v yay &>/dev/null; then
    AUR_HELPER="yay"
else
    info "No AUR helper found. Installing yay..."
    sudo pacman -S --needed --noconfirm base-devel git
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
    (cd "$tmpdir/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
    AUR_HELPER="yay"
fi
success "AUR helper: $AUR_HELPER"

# ── Check for conflicting packages ──────────────────────────────────
if pacman -Qi xdg-desktop-portal-kde &>/dev/null; then
    warn "xdg-desktop-portal-kde is installed and may break screensharing."
    read -rp "Remove it? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] && sudo pacman -Rns --noconfirm xdg-desktop-portal-kde
fi

# ── Official packages ───────────────────────────────────────────────
OFFICIAL_PKGS=(
    hyprland
    hyprlock
    hypridle
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    hyprpolkitagent
    waybar
    kitty
    wofi
    mako
    grim
    slurp
    wl-clipboard
    brightnessctl
    playerctl
    blueman
    network-manager-applet
    qt5ct
    qt6ct
    ttf-jetbrains-mono-nerd
    noto-fonts
    noto-fonts-emoji
)

info "Installing official packages..."
if sudo pacman -S --needed --noconfirm "${OFFICIAL_PKGS[@]}" 2>/dev/null; then
    for pkg in "${OFFICIAL_PKGS[@]}"; do
        SUCCEEDED+=("$pkg")
    done
else
    warn "Batch install failed. Falling back to one-by-one..."
    for pkg in "${OFFICIAL_PKGS[@]}"; do
        if sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null; then
            SUCCEEDED+=("$pkg")
        else
            FAILED+=("$pkg")
            warn "Failed to install: $pkg"
        fi
    done
fi

# ── AUR packages ────────────────────────────────────────────────────
AUR_PKGS=(
    bibata-cursor-theme
    wlogout
)

info "Installing AUR packages..."
for pkg in "${AUR_PKGS[@]}"; do
    if $AUR_HELPER -S --needed --noconfirm "$pkg" 2>/dev/null; then
        SUCCEEDED+=("$pkg")
    else
        FAILED+=("$pkg")
        warn "Failed to install AUR package: $pkg"
    fi
done

# ── Deploy config files ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info "Deploying config files..."

# Hyprland
mkdir -p ~/.config/hypr
for f in hyprland.conf monitors.conf env.conf autostart.conf keybinds.conf windowrules.conf animations.conf hyprlock.conf hypridle.conf; do
    if [[ -f "$SCRIPT_DIR/$f" ]]; then
        cp "$SCRIPT_DIR/$f" ~/.config/hypr/"$f"
        success "Deployed ~/.config/hypr/$f"
    fi
done

# Waybar
mkdir -p ~/.config/waybar
[[ -f "$SCRIPT_DIR/waybar-config.jsonc" ]] && cp "$SCRIPT_DIR/waybar-config.jsonc" ~/.config/waybar/config.jsonc && success "Deployed waybar config.jsonc"
[[ -f "$SCRIPT_DIR/waybar-style.css" ]] && cp "$SCRIPT_DIR/waybar-style.css" ~/.config/waybar/style.css && success "Deployed waybar style.css"

# Mako
mkdir -p ~/.config/mako
[[ -f "$SCRIPT_DIR/mako-config" ]] && cp "$SCRIPT_DIR/mako-config" ~/.config/mako/config && success "Deployed mako config"

# Wofi
mkdir -p ~/.config/wofi
[[ -f "$SCRIPT_DIR/wofi-config" ]] && cp "$SCRIPT_DIR/wofi-config" ~/.config/wofi/config && success "Deployed wofi config"
[[ -f "$SCRIPT_DIR/wofi-style.css" ]] && cp "$SCRIPT_DIR/wofi-style.css" ~/.config/wofi/style.css && success "Deployed wofi style.css"

# Kitty
mkdir -p ~/.config/kitty
[[ -f "$SCRIPT_DIR/kitty.conf" ]] && cp "$SCRIPT_DIR/kitty.conf" ~/.config/kitty/kitty.conf && success "Deployed kitty.conf"

# ── Post-install verification ────────────────────────────────────────
info "Running post-install verification..."

EXPECTED_CMDS=(hyprland hyprlock hypridle waybar kitty wofi mako grim slurp brightnessctl playerctl wl-copy blueman-manager)
MISSING_CMDS=()
for cmd in "${EXPECTED_CMDS[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING_CMDS+=("$cmd")
    fi
done

# Font check
if fc-list : family | grep -qi "JetBrainsMono Nerd Font"; then
    success "JetBrainsMono Nerd Font is installed"
else
    WARNINGS+=("JetBrainsMono Nerd Font not found in fc-list")
fi

# Cursor check
if ls /usr/share/icons/Bibata-Modern-Classic* &>/dev/null; then
    success "Bibata-Modern-Classic cursor theme found"
else
    WARNINGS+=("Bibata-Modern-Classic cursor theme not found in /usr/share/icons/")
fi

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Installation Summary${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"

if [[ ${#SUCCEEDED[@]} -gt 0 ]]; then
    echo -e "${GREEN}  Installed: ${#SUCCEEDED[@]} packages${NC}"
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo -e "${RED}  Failed:${NC}"
    for pkg in "${FAILED[@]}"; do
        echo -e "    ${RED}✗${NC} $pkg"
    done
fi

if [[ ${#MISSING_CMDS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}  Missing commands:${NC}"
    for cmd in "${MISSING_CMDS[@]}"; do
        echo -e "    ${YELLOW}!${NC} $cmd"
    done
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}  Warnings:${NC}"
    for w in "${WARNINGS[@]}"; do
        echo -e "    ${YELLOW}!${NC} $w"
    done
fi

echo ""
echo -e "${GREEN}  Config files deployed to ~/.config/${NC}"
echo -e "${BLUE}  Next steps:${NC}"
echo -e "    1. Log out and start Hyprland from your display manager or TTY"
echo -e "    2. Run ${BOLD}nwg-look${NC} to apply GTK theme settings"
echo -e "    3. Run ${BOLD}qt5ct${NC} / ${BOLD}qt6ct${NC} to configure Qt app theming"
echo ""
