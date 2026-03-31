---
title: Dotfile Management with Git + Stow
weight: 10
---

# Dotfile Management with Git + GNU Stow

This reference covers how to structure a Hyprland rice as a version-controlled, portable dotfiles repository using GNU Stow for symlink management. This is the standard approach in the Hyprland/unixporn community for sharing, backing up, and reusing configs across machines.

## Table of Contents

1. [How GNU Stow Works](#how-gnu-stow-works)
2. [Directory Structure for Hyprland Dotfiles](#directory-structure)
3. [Stow Commands Reference](#stow-commands)
4. [The .stowrc File](#stowrc)
5. [Ignoring Files](#ignoring-files)
6. [Machine-Specific Configs](#machine-specific-configs)
7. [Bootstrap / Setup Script](#bootstrap-script)
8. [Secrets and Sensitive Data](#secrets)
9. [Adopting Existing Configs](#adopting-existing-configs)
10. [Alternatives to Stow](#alternatives)
11. [Common Pitfalls](#pitfalls)

---

## How GNU Stow Works <a name="how-gnu-stow-works"></a>

GNU Stow is a **symlink farm manager**. It takes files organized in a "stow directory" and creates symlinks in a "target directory" so the files appear to be installed there.

**Core concepts:**

- **Stow directory**: Where your actual files live (e.g., `~/dotfiles`). This is the git repo root.
- **Target directory**: Where symlinks are created (defaults to the parent of the stow directory — typically `$HOME`).
- **Packages**: Each subdirectory in the stow directory is a "package." Its internal structure mirrors the target directory.

**Example**: If `~/dotfiles/hypr/.config/hypr/hyprland.conf` exists and you run `stow hypr`, Stow creates a symlink at `~/.config/hypr/hyprland.conf` → `../dotfiles/hypr/.config/hypr/hyprland.conf`.

**Tree folding**: Stow optimizes by symlinking entire directories when possible. If only one package contributes files to `~/.config/hypr/`, Stow may symlink the entire `hypr/` directory rather than individual files. When a second package needs to add files there, Stow "unfolds" — replaces the directory symlink with a real directory containing individual file symlinks. Use `--no-folding` to force individual symlinks always.

**Safety**: Stow scans for all potential conflicts before making any filesystem changes. If any conflict is found (e.g., a real file already exists where a symlink would go), the entire operation aborts without modifying anything. Stow never deletes anything it doesn't own.

---

## Directory Structure for Hyprland Dotfiles <a name="directory-structure"></a>

The convention is one package per application, with each package's internal structure mirroring the path from `$HOME`:

```
~/dotfiles/                              # git repo root = stow directory
├── .gitignore
├── .stowrc                              # default stow flags (--target=$HOME)
├── README.md                            # describe the rice, show screenshots
├── packages.txt                         # pacman/AUR package list
│
├── hypr/                                # package: Hyprland
│   └── .config/
│       └── hypr/
│           ├── hyprland.conf            # main config (sources modular files)
│           ├── monitors.conf
│           ├── keybinds.conf
│           ├── windowrules.conf
│           ├── autostart.conf
│           ├── animations.conf
│           └── env.conf
│
├── waybar/                              # package: Waybar
│   └── .config/
│       └── waybar/
│           ├── config.jsonc
│           └── style.css
│
├── dunst/                               # package: notification daemon
│   └── .config/
│       └── dunst/
│           └── dunstrc
│
├── wofi/                                # package: app launcher
│   └── .config/
│       └── wofi/
│           ├── config
│           └── style.css
│
├── kitty/                               # package: terminal
│   └── .config/
│       └── kitty/
│           └── kitty.conf
│
├── hyprlock/                            # package: lock screen
│   └── .config/
│       └── hypr/
│           └── hyprlock.conf
│
├── hypridle/                            # package: idle daemon
│   └── .config/
│       └── hypr/
│           └── hypridle.conf
│
├── hyprpaper/                           # package: wallpaper (or swww/)
│   └── .config/
│       └── hypr/
│           └── hyprpaper.conf
│
├── wlogout/                             # package: logout menu
│   └── .config/
│       └── wlogout/
│           ├── layout
│           └── style.css
│
├── gtk/                                 # package: GTK theming
│   ├── .config/
│   │   ├── gtk-3.0/
│   │   │   └── settings.ini
│   │   └── gtk-4.0/
│   │       └── settings.ini
│   └── .icons/
│       └── default/
│           └── index.theme
│
├── shell/                               # package: shell config
│   ├── .zshrc                           # or .config/fish/config.fish
│   ├── .zprofile                        # TTY launch line
│   └── .config/
│       └── starship.toml
│
├── scripts/                             # package: custom scripts
│   └── .local/
│       └── bin/
│           ├── wallpaper-cycle.sh
│           ├── screenshot.sh
│           └── power-menu.sh
│
├── vscode/                              # package: VS Code (if themed)
│   └── .config/
│       └── Code/
│           └── User/
│               └── settings.json
│
├── firefox/                             # package: Firefox theming
│   └── .mozilla/
│       └── firefox/
│           └── PROFILE_NAME/            # user must replace with actual profile dir
│               └── chrome/
│                   ├── userChrome.css
│                   └── userContent.css
│
└── uwsm/                               # package: uwsm env (if using uwsm)
    └── .config/
        └── uwsm/
            ├── env
            └── env-hyprland
```

**Key rules:**
- The internal path inside each package must **exactly mirror** the path from `$HOME`. So `hypr/.config/hypr/hyprland.conf` creates `~/.config/hypr/hyprland.conf`.
- Include the leading dot (`.config`, not `config`).
- One package per logical unit (app, tool, or concern).
- Files that go directly in `$HOME` (like `.zshrc`) go at the package root: `shell/.zshrc`.

### Hyprlock/Hypridle/Hyprpaper placement note

These configs live in `~/.config/hypr/` alongside `hyprland.conf`. You have two options:

**Option A — All in the `hypr/` package**: Simplest. All `~/.config/hypr/` files in one package.

**Option B — Separate packages**: `hyprlock/`, `hypridle/`, `hyprpaper/` each contain `.config/hypr/<their-config>`. This lets you selectively stow them but means multiple packages contribute to the same directory — Stow handles this via tree unfolding, but it adds complexity.

Recommend Option A for most users. Use Option B only if the user explicitly wants to manage components independently (e.g., different lock screen configs on different machines).

### AGS package structure

If using AGS as the shell framework:

```
ags/
└── .config/
    └── ags/
        ├── app.ts
        ├── widget/
        │   ├── Bar.tsx
        │   ├── Notifications.tsx
        │   ├── Launcher.tsx
        │   └── OSD.tsx
        ├── style.scss
        ├── tsconfig.json
        └── env.d.ts
```

---

## Stow Commands Reference <a name="stow-commands"></a>

All commands assume you're `cd`'d into the stow directory (`~/dotfiles`), or using `--dir` / `--target` flags.

```bash
# Stow specific packages (create symlinks)
stow hypr waybar kitty dunst wofi shell scripts

# Stow all packages at once
stow */

# Dry run — see what would happen without doing it
stow -n -v hypr waybar kitty

# Restow — clean up stale symlinks then re-stow (use after adding/removing files)
stow -R hypr

# Unstow — remove symlinks for a package
stow -D hypr

# Stow with explicit target (if not using .stowrc)
stow -t ~ hypr waybar kitty
```

| Flag | Short | Purpose |
|------|-------|---------|
| `--target=DIR` | `-t DIR` | Set target directory (default: parent of stow dir) |
| `--dir=DIR` | `-d DIR` | Set stow directory (default: cwd) |
| `--restow` | `-R` | Unstow then re-stow (prunes obsolete symlinks) |
| `--delete` | `-D` | Remove symlinks (unstow a package) |
| `--adopt` | | Move conflicting real files INTO the package, then stow |
| `--no-folding` | | Disable tree folding (force individual file symlinks) |
| `--simulate` | `-n` | Dry run — show what would happen |
| `--verbose` | `-v` | Increase verbosity (`-vv`, `-vvv` for more) |

---

## The .stowrc File <a name="stowrc"></a>

Place a `.stowrc` at the stow directory root to set default flags so you don't repeat `--target` every time:

```
--target=/home/USERNAME
--no-folding
```

With this in place, `cd ~/dotfiles && stow hypr` is equivalent to `stow --target=/home/USERNAME --no-folding hypr`.

**Important**: The `.stowrc` target must be an absolute path (no `~` expansion). Generate it dynamically in the setup script:

```bash
echo "--target=$HOME" > ~/dotfiles/.stowrc
```

---

## Ignoring Files <a name="ignoring-files"></a>

### .stow-local-ignore

Controls which files Stow skips when creating symlinks. Place at the stow directory root or inside individual packages.

**Important**: Creating this file **replaces** Stow's built-in ignore list. You must re-add the defaults:

```
# .stow-local-ignore — re-add defaults plus custom patterns
\.git
\.gitignore
\.gitmodules
^README.*
^LICENSE.*
^COPYING
\.stowrc

# Custom ignores
^packages\.txt
^setup\.sh
^Makefile
\.md$
```

### .gitignore

Controls what git tracks. Completely separate from `.stow-local-ignore`.

```gitignore
# Secrets — never commit
*.secret
.env
.ssh/
.gnupg/

# Machine-specific overrides (tracked separately or not at all)
**/local.conf

# OS junk
.DS_Store
*.swp
*~
```

---

## Machine-Specific Configs <a name="machine-specific-configs"></a>

Stow has no built-in conditionals or templates. Use one of these strategies:

### Strategy 1: Host-specific packages (recommended for Hyprland)

Create packages per machine for things that differ (monitors, HiDPI, touchpad):

```
~/dotfiles/
├── hypr/                    # shared — keybinds, window rules, animations, etc.
│   └── .config/hypr/
│       ├── keybinds.conf
│       ├── windowrules.conf
│       ├── animations.conf
│       └── autostart.conf
├── hypr-desktop/            # desktop-only — monitors, no touchpad
│   └── .config/hypr/
│       ├── hyprland.conf    # sources shared files + monitors.conf
│       └── monitors.conf
├── hypr-laptop/             # laptop-only — different monitors, touchpad, lid switch
│   └── .config/hypr/
│       ├── hyprland.conf
│       ├── monitors.conf
│       └── input.conf       # touchpad settings
```

On the desktop: `stow hypr hypr-desktop waybar kitty ...`
On the laptop: `stow hypr hypr-laptop waybar kitty ...`

The `hyprland.conf` in each host package sources the shared configs:
```ini
# hypr-desktop/.config/hypr/hyprland.conf
$terminal = kitty
$fileManager = thunar
$menu = wofi --show drun

source = ~/.config/hypr/monitors.conf
source = ~/.config/hypr/autostart.conf
source = ~/.config/hypr/keybinds.conf
source = ~/.config/hypr/windowrules.conf
source = ~/.config/hypr/animations.conf
```

### Strategy 2: Local override file (simpler, less portable)

Keep a `local.conf` that's gitignored but sourced by the tracked config:

```ini
# In hyprland.conf (tracked)
source = ~/.config/hypr/local.conf
```

```ini
# In ~/.config/hypr/local.conf (gitignored, created manually per machine)
monitor = DP-1, 2560x1440@165, 0x0, 1
monitor = HDMI-A-1, 1920x1080@60, 2560x0, 1
```

Simpler but the local file isn't version-controlled, so you lose it if the machine dies.

### Strategy 3: Hostname detection in config

Hyprland doesn't support conditionals natively, but shell scripts can:

```bash
# In a wallpaper script
HOSTNAME=$(hostname)
if [ "$HOSTNAME" = "desktop" ]; then
    swww img ~/wallpapers/ultrawide.jpg
else
    swww img ~/wallpapers/standard.jpg
fi
```

---

## Bootstrap / Setup Script <a name="bootstrap-script"></a>

The setup script replaces the standalone `install.sh` when using a dotfiles repo. It handles cloning, dependency installation, backup of existing configs, and stowing:

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Pre-flight ---
if [ "$(id -u)" -eq 0 ]; then
    error "Do not run as root."
    exit 1
fi

if ! command -v git &>/dev/null; then
    error "git is required. Install it first: sudo pacman -S git"
    exit 1
fi

# --- Clone if needed ---
if [ ! -d "$DOTFILES_DIR" ]; then
    info "Cloning dotfiles..."
    git clone https://github.com/USERNAME/dotfiles.git "$DOTFILES_DIR"
fi

cd "$DOTFILES_DIR"

# --- Install packages ---
if command -v pacman &>/dev/null; then
    info "Installing packages..."
    # Install stow first
    sudo pacman -S --needed --noconfirm stow

    # Install from package list
    if [ -f packages.txt ]; then
        sudo pacman -S --needed --noconfirm - < packages.txt
    fi

    # AUR packages (if yay/paru available)
    if [ -f aur-packages.txt ]; then
        AUR_HELPER=""
        if command -v paru &>/dev/null; then AUR_HELPER="paru"
        elif command -v yay &>/dev/null; then AUR_HELPER="yay"
        fi

        if [ -n "$AUR_HELPER" ]; then
            info "Installing AUR packages with $AUR_HELPER..."
            $AUR_HELPER -S --needed --noconfirm - < aur-packages.txt
        else
            warn "No AUR helper found. Skipping AUR packages."
        fi
    fi
fi

# --- Backup existing configs ---
CONFIGS_TO_BACKUP=(.config/hypr .config/waybar .config/kitty .config/dunst
                   .config/wofi .config/rofi .config/wlogout .config/swaync
                   .config/ags .zshrc .zprofile .config/fish .config/starship.toml)

NEEDS_BACKUP=false
for cfg in "${CONFIGS_TO_BACKUP[@]}"; do
    # Only backup real files/dirs, not existing symlinks (those are from a previous stow)
    if [ -e "$HOME/$cfg" ] && [ ! -L "$HOME/$cfg" ]; then
        NEEDS_BACKUP=true
        break
    fi
done

if [ "$NEEDS_BACKUP" = true ]; then
    info "Backing up existing configs to $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    for cfg in "${CONFIGS_TO_BACKUP[@]}"; do
        if [ -e "$HOME/$cfg" ] && [ ! -L "$HOME/$cfg" ]; then
            mkdir -p "$BACKUP_DIR/$(dirname "$cfg")"
            mv "$HOME/$cfg" "$BACKUP_DIR/$cfg"
            info "  Backed up $cfg"
        fi
    done
fi

# --- Remove stale symlinks ---
# Clean up dead symlinks from a previous stow that might conflict
find "$HOME/.config" -maxdepth 2 -xtype l -delete 2>/dev/null || true

# --- Generate .stowrc ---
echo "--target=$HOME" > "$DOTFILES_DIR/.stowrc"

# --- Stow all packages ---
PACKAGES=(hypr waybar kitty dunst wofi shell scripts)  # adjust to match repo contents

info "Stowing packages..."
for pkg in "${PACKAGES[@]}"; do
    if [ -d "$pkg" ]; then
        stow -v "$pkg" && info "  Stowed $pkg" || warn "  Failed to stow $pkg"
    fi
done

# --- Post-install ---
info "Rebuilding font cache..."
fc-cache -f

info "Done! Log out and back in to Hyprland."
```

### Package list files

Keep package lists as plain text files at the repo root for easy maintenance:

```
# packages.txt — official repo packages (one per line)
hyprland
waybar
kitty
wofi
dunst
hyprlock
hypridle
hyprpaper
stow
```

```
# aur-packages.txt — AUR packages
swww
wlogout
catppuccin-gtk-theme-mocha
catppuccin-cursors-mocha
ttf-jetbrains-mono-nerd
```

---

## Secrets and Sensitive Data <a name="secrets"></a>

Stow has no secret management. Layer on additional tools:

### .gitignore (minimum)

Always gitignore files that might contain secrets:

```gitignore
*.secret
.env
.ssh/
.gnupg/
**/local.conf
```

### git-crypt (transparent encryption)

Encrypts specific files in the repo using GPG. Files are readable locally but encrypted at rest in git:

```bash
git-crypt init
echo "**/*.secret filter=git-crypt diff=git-crypt" >> .gitattributes
```

### Pre-commit hooks

Use `git-secrets` or a pre-commit hook to scan for accidentally committed keys/tokens:

```bash
# Install git-secrets
git secrets --install
git secrets --register-aws  # catches AWS keys
```

---

## Adopting Existing Configs <a name="adopting-existing-configs"></a>

If the user already has configs at `~/.config/hypr/` and wants to bring them into the dotfiles repo:

```bash
# 1. Create the package directory structure
mkdir -p ~/dotfiles/hypr/.config/hypr

# 2. Move existing files into the package
mv ~/.config/hypr/* ~/dotfiles/hypr/.config/hypr/

# 3. Stow to create symlinks back
cd ~/dotfiles && stow hypr
```

**Alternative — stow --adopt**: Moves conflicting real files into the package automatically, then stows:

```bash
# First, create the package structure with placeholder (or real) files
mkdir -p ~/dotfiles/hypr/.config/hypr
touch ~/dotfiles/hypr/.config/hypr/hyprland.conf

# adopt moves the REAL file into the package, replacing the placeholder
cd ~/dotfiles && stow --adopt hypr

# IMPORTANT: immediately check what was adopted
git diff
```

`--adopt` is powerful but risky — always `git diff` immediately after to verify nothing unexpected was pulled in.

---

## Alternatives to Stow <a name="alternatives"></a>

| Tool | Approach | Best for |
|------|----------|----------|
| **GNU Stow** | Symlink farm | Simplicity, no dependencies beyond Perl, reversible, Unix philosophy |
| **chezmoi** | Source-of-truth dir, copies files | Templates, built-in secret management (age/GPG/1Password), cross-platform |
| **yadm** | Git wrapper (bare repo) | Git-native workflow, alternate files per host, encryption |
| **Bare git repo** | `git --work-tree=$HOME` | Zero dependencies, no symlinks — but dangerous (entire HOME is work tree) |
| **dotbot** | YAML-driven symlinker | Declarative config, Python-based |

**Recommend Stow** as the default for Hyprland rices — it's the most common tool in the community, requires only Perl (pre-installed on most distros), and the symlink approach means edits in `~/.config/hypr/` are immediately reflected in the git repo (no copy step needed). Mention chezmoi if the user needs templates or cross-platform support.

---

## Common Pitfalls <a name="pitfalls"></a>

1. **Existing files block stowing**: If `~/.config/hypr/hyprland.conf` already exists as a real file, `stow hypr` will fail with a conflict. Remove or `--adopt` the file first. The setup script should handle this by backing up existing configs before stowing.

2. **Tree folding surprises**: If only one package contributes to `~/.config/`, Stow may symlink the entire `.config` directory. This means non-stowed app configs also appear to live in your dotfiles. Use `--no-folding` in `.stowrc` to prevent this.

3. **Globbing `stow */` stows everything**: Shell glob `*/` will try to stow directories like `screenshots/` or `docs/` that aren't packages. Either list packages explicitly or add non-package dirs to `.stow-local-ignore`.

4. **`.stow-local-ignore` replaces defaults**: If you create this file, Stow's built-in ignore list (which skips `.git`, `README`, etc.) is completely replaced. You must re-add those patterns.

5. **Firefox profile directories**: Firefox uses random profile directory names (`abc123.default-release`). The user must replace the placeholder in the package structure with their actual profile dir name. Find it with `ls ~/.mozilla/firefox/*.default-release`.

6. **Running stow from the wrong directory**: Stow must be run from inside the stow directory, or you must use `--dir` and `--target` flags. Running from `$HOME` without flags will try to stow directories in `/`.

7. **Hyprland variable declaration order**: Variables (`$terminal`, `$fileManager`, `$menu`) must be defined **before** any `source =` lines that reference them. When splitting configs into a dotfiles repo, the main `hyprland.conf` must declare variables at the top before sourcing modular files.

8. **Symlinks and editors**: Most editors follow symlinks transparently. Editing `~/.config/hypr/hyprland.conf` edits the file in `~/dotfiles/hypr/.config/hypr/hyprland.conf` — changes are immediately visible to `git diff` in the dotfiles repo.

9. **Restow after adding files**: When you add new files to a package in the repo, you need to run `stow -R <package>` to create the new symlinks. Just `git pull` doesn't create them.
