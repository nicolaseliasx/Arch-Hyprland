#!/usr/bin/env bash
# ==============================================================================
#  snapshot.sh - Takes an exact snapshot of active user dotfiles & packages
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DOTFILES_DIR="$REPO_ROOT/assets/dotfiles"
PACKAGES_DIR="$REPO_ROOT/assets/packages"

echo "=== 📸 Starting System Snapshot ==="
echo "Repo root: $REPO_ROOT"
echo "Dotfiles destination: $DOTFILES_DIR"

# Clean target dotfiles dir
rm -rf "$DOTFILES_DIR"
mkdir -p "$DOTFILES_DIR"
mkdir -p "$PACKAGES_DIR"

# Paths to snapshot relative to $HOME
TARGET_PATHS=(
  ".config/hypr"
  ".config/waybar"
  ".config/rofi"
  ".config/quickshell"
  ".config/kitty"
  ".config/ghostty"
  ".config/wezterm"
  ".config/nvim"
  ".config/fastfetch"
  ".config/btop"
  ".config/cava"
  ".config/swaync"
  ".config/wlogout"
  ".config/wallust"
  ".config/gtk-3.0"
  ".config/gtk-4.0"
  ".config/qt5ct"
  ".config/qt6ct"
  ".config/Kvantum"
  ".config/swappy"
  ".config/Thunar"
  ".config/xfce4"
  ".config/xsettingsd"
  ".config/environment.d"
  ".config/mimeapps.list"
  ".config/pavucontrol.ini"
  ".config/user-dirs.dirs"
  ".zshrc"
  ".p10k.zsh"
  ".gitconfig"
  ".gtkrc-2.0"
  ".Xresources"
  "pictures/wallpapers"
)

copy_clean() {
  local src="$1"
  local dest="$2"

  mkdir -p "$(dirname "$dest")"
  if [ -d "$src" ] && [ ! -L "$src" ]; then
    mkdir -p "$dest"
    cp -a "$src/." "$dest/"
  else
    cp -a "$src" "$dest"
  fi
}

for rel_path in "${TARGET_PATHS[@]}"; do
  src_path="$HOME/$rel_path"
  dest_path="$DOTFILES_DIR/$rel_path"

  if [ -e "$src_path" ] || [ -L "$src_path" ]; then
    echo "  [+] Copying $rel_path..."
    copy_clean "$src_path" "$dest_path"
  else
    echo "  [-] Skipping (not found): $rel_path"
  fi
done

echo "=== 🧹 Cleaning Cache & Duplicates from Snapshot ==="
find "$DOTFILES_DIR" -type d -name ".git" -exec rm -rf {} + 2>/dev/null || true
find "$DOTFILES_DIR" -type d -name ".cache" -exec rm -rf {} + 2>/dev/null || true
find "$DOTFILES_DIR" -type d -name ".local" -exec rm -rf {} + 2>/dev/null || true
find "$DOTFILES_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "$DOTFILES_DIR" -name "*.log" -delete 2>/dev/null || true
find "$DOTFILES_DIR" -name "*.pyc" -delete 2>/dev/null || true
find "$DOTFILES_DIR" -name ".zsh_history" -delete 2>/dev/null || true

# Remove nested duplicates
rm -rf "$DOTFILES_DIR/.config/rofi/themes/themes"
rm -rf "$DOTFILES_DIR/.config/hypr/UserConfigs/UserConfigs"
rm -rf "$DOTFILES_DIR/.config/hypr/UserScripts/UserScripts"
rm -rf "$DOTFILES_DIR/.config/hypr/animations/animations"
rm -rf "$DOTFILES_DIR/.config/hypr/Monitor_Profiles/Monitor_Profiles"

echo "=== 📦 Exporting Package Lists ==="
pacman -Qqen | sort > "$PACKAGES_DIR/pacman-explicit.txt"
if command -v yay &>/dev/null; then
  yay -Qqm | sort > "$PACKAGES_DIR/aur-explicit.txt"
elif command -v paru &>/dev/null; then
  paru -Qqm | sort > "$PACKAGES_DIR/aur-explicit.txt"
else
  pacman -Qqem | sort > "$PACKAGES_DIR/aur-explicit.txt"
fi

echo "  [+] Native packages: $(wc -l < "$PACKAGES_DIR/pacman-explicit.txt")"
echo "  [+] AUR packages: $(wc -l < "$PACKAGES_DIR/aur-explicit.txt")"

echo "=== ✅ Snapshot Completed Successfully! ==="
