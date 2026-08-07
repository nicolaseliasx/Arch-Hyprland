#!/bin/bash
# ==============================================================================
#  Applies embedded snapshot dotfiles to $HOME
# ==============================================================================
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || exit 1

if ! source "$SCRIPT_DIR/Global_functions.sh"; then
  echo "Failed to source Global_functions.sh"
  exit 1
fi

DOTFILES_DIR="$PARENT_DIR/assets/dotfiles"
LOG="Install-Logs/install-$(date +%d-%H%M%S)_dotfiles-apply.log"

if [ ! -d "$DOTFILES_DIR" ]; then
  echo -e "${ERROR} Dotfiles snapshot directory not found at $DOTFILES_DIR" | tee -a "$LOG"
  exit 1
fi

echo -e "\n${NOTE} Applying local snapshot dotfiles from ${SKY_BLUE}$DOTFILES_DIR${RESET} to ${SKY_BLUE}$HOME${RESET}..." | tee -a "$LOG"

# Backup existing config to ~/.config-hyprland-backups/
BACKUP_DIR="$HOME/.config-hyprland-backups/backup-$(date +%d-%H%M%S)"
echo "  [+] Creating backup at $BACKUP_DIR..." | tee -a "$LOG"
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

echo -e "👌 ${OK} Dotfiles snapshot successfully applied!" | tee -a "$LOG"
