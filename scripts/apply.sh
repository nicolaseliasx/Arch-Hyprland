#!/usr/bin/env bash
# ==============================================================================
#  apply.sh - Standalone script to apply dotfiles snapshot and install packages
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DOTFILES_DIR="$REPO_ROOT/assets/dotfiles"
PACKAGES_DIR="$REPO_ROOT/assets/packages"

echo "=== 🚀 Applying Snapshot Dotfiles & Packages ==="

if [ ! -d "$DOTFILES_DIR" ]; then
  echo "Error: $DOTFILES_DIR does not exist!"
  exit 1
fi

BACKUP_DIR="$HOME/.config-hyprland-backups/backup-$(date +%Y%m%d_%H%M%S)"
echo "  [+] Creating safety backup in $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"

if command -v rsync &>/dev/null; then
  rsync -a "$DOTFILES_DIR/" "$HOME/"
else
  cp -a "$DOTFILES_DIR/." "$HOME/"
fi

# Set executable permissions for scripts
if [ -d "$HOME/.config/hypr/scripts" ]; then
  chmod +x "$HOME/.config/hypr/scripts/"* 2>/dev/null || true
fi
if [ -d "$HOME/.config/hypr/UserScripts" ]; then
  chmod +x "$HOME/.config/hypr/UserScripts/"* 2>/dev/null || true
fi

echo "=== 📦 Installing Missing Explicit Packages ==="
if [ -f "$PACKAGES_DIR/pacman-explicit.txt" ]; then
  mapfile -t pacman_pkgs < <(grep -v '^#' "$PACKAGES_DIR/pacman-explicit.txt" | grep -v '^$')
  echo "  [+] Checking ${#pacman_pkgs[@]} pacman packages..."
  sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}" 2>/dev/null || true
fi

if [ -f "$PACKAGES_DIR/aur-explicit.txt" ]; then
  mapfile -t aur_pkgs < <(grep -v '^#' "$PACKAGES_DIR/aur-explicit.txt" | grep -v '^$')
  echo "  [+] Checking ${#aur_pkgs[@]} AUR packages..."
  if command -v yay &>/dev/null; then
    yay -S --needed --noconfirm "${aur_pkgs[@]}" 2>/dev/null || true
  elif command -v paru &>/dev/null; then
    paru -S --needed --noconfirm "${aur_pkgs[@]}" 2>/dev/null || true
  fi
fi

echo "=== ✅ Apply Completed Successfully! ==="
