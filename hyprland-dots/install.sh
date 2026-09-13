#!/bin/bash
# ============================================
# HARAMchy Linux - Dotfiles Installer
# ============================================

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config/haramchy-backup/$(date +%Y%m%d_%H%M%S)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
TEAL='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${TEAL}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        mkdir -p "$BACKUP_DIR"
        cp "$file" "$BACKUP_DIR/"
        warn "Backed up: $file"
    fi
}

install_file() {
    local src="$1"
    local dst="$2"

    if [ -f "$src" ]; then
        mkdir -p "$(dirname "$dst")"
        backup_file "$dst"
        cp "$src" "$dst"
        success "Installed: $dst"
    else
        warn "Source not found: $src"
    fi
}

install_dir() {
    local src="$1"
    local dst="$2"

    if [ -d "$src" ]; then
        mkdir -p "$dst"
        backup_file "$dst"
        cp -r "$src"/* "$dst/"
        success "Installed: $dst"
    else
        warn "Source directory not found: $src"
    fi
}

echo ""
echo -e "${TEAL}╔═══════════════════════════════════════╗${NC}"
echo -e "${TEAL}║     HARAMchy Dotfiles Installer       ║${NC}"
echo -e "${TEAL}╚═══════════════════════════════════════╝${NC}"
echo ""

info "Installing Hyprland configuration..."
install_file "$DOTFILES_DIR/hyprland.conf" "$HOME/.config/hypr/hyprland.conf"

info "Installing Waybar configuration..."
install_file "$DOTFILES_DIR/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
install_file "$DOTFILES_DIR/waybar/style.css" "$HOME/.config/waybar/style.css"

info "Installing Alacritty configuration..."
install_file "$DOTFILES_DIR/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"

info "Installing Hyprpaper configuration..."
install_file "$DOTFILES_DIR/hyprpaper.conf" "$HOME/.config/hypr/hyprpaper.conf"

info "Installing environment variables..."
if [ -f "$DOTFILES_DIR/environment" ]; then
    grep -q "XDG_CURRENT_DESKTOP" "$HOME/.profile" 2>/dev/null || {
        echo "" >> "$HOME/.profile"
        echo "# HARAMchy Environment" >> "$HOME/.profile"
        cat "$DOTFILES_DIR/environment" >> "$HOME/.profile"
        success "Added environment to ~/.profile"
    }
fi

info "Installing environment for bash_profile..."
if [ -f "$DOTFILES_DIR/environment" ]; then
    grep -q "XDG_CURRENT_DESKTOP" "$HOME/.bash_profile" 2>/dev/null || {
        echo "" >> "$HOME/.bash_profile"
        echo "# HARAMchy Environment" >> "$HOME/.bash_profile"
        cat "$DOTFILES_DIR/environment" >> "$HOME/.bash_profile"
        success "Added environment to ~/.bash_profile"
    }
fi

echo ""
success "Installation complete!"
if [ -d "$BACKUP_DIR" ]; then
    info "Backups saved to: $BACKUP_DIR"
fi
echo ""
info "Please log out and log back in for changes to take effect."
echo ""
