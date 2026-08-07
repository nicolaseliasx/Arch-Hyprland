#!/bin/bash
# ==============================================================================
#  Installs explicit user packages from assets/packages/
# ==============================================================================
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$SCRIPT_DIR/.."

if ! source "$SCRIPT_DIR/Global_functions.sh"; then
  echo "Failed to source Global_functions.sh"
  exit 1
fi

LOG="Install-Logs/install-$(date +%d-%H%M%S)_user-packages.log"
PACMAN_LIST="$PARENT_DIR/assets/packages/pacman-explicit.txt"
AUR_LIST="$PARENT_DIR/assets/packages/aur-explicit.txt"

if [ -f "$PACMAN_LIST" ]; then
  echo -e "\n${NOTE} Installing explicit native pacman packages..." | tee -a "$LOG"
  mapfile -t pacman_pkgs < <(grep -v '^#' "$PACMAN_LIST" | grep -v '^$')
  for pkg in "${pacman_pkgs[@]}"; do
    install_package_pacman "$pkg" "$LOG"
  done
fi

if [ -f "$AUR_LIST" ]; then
  echo -e "\n${NOTE} Installing explicit AUR packages..." | tee -a "$LOG"
  mapfile -t aur_pkgs < <(grep -v '^#' "$AUR_LIST" | grep -v '^$')
  for pkg in "${aur_pkgs[@]}"; do
    install_package "$pkg" "$LOG"
  done
fi

echo -e "👌 ${OK} Explicit user packages installation process finished." | tee -a "$LOG"
