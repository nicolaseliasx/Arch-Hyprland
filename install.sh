#!/usr/bin/env bash
# Install the complete versioned PC-base profile on a clean Arch Linux system.
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACMAN_LIST="$REPO_ROOT/assets/packages/pacman-explicit.txt"
AUR_LIST="$REPO_ROOT/assets/packages/aur-explicit.txt"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/arch-hyprland"
LOG_FILE="$STATE_DIR/install-$(date +%Y%m%d_%H%M%S).log"
FAILURES_FILE="$STATE_DIR/install-package-failures-$(date +%Y%m%d_%H%M%S).txt"

mkdir -p "$STATE_DIR"
log() { printf '%s [install] %s\n' "$(date --iso-8601=seconds)" "$*" | tee -a "$LOG_FILE"; }
die() { log "ERROR: $*"; exit 1; }

require_clean_arch() {
  [[ $EUID -ne 0 ]] || die 'run this script as the target user, not root'
  [[ -f /etc/arch-release ]] || die 'this bootstrap supports Arch Linux only'
  command -v sudo >/dev/null 2>&1 || die 'sudo is required'
  sudo -v || die 'sudo authentication failed'
}

confirm_overwrite() {
  cat <<'EOF'
This installs the full versioned PC-base profile.
Every path declared in assets/snapshot-paths.txt will be overwritten exactly.
A dated backup is created, but rollback is manual. No snapshot timer is created
on this machine.
EOF
  printf 'Type INSTALL to continue: '
  read -r answer
  [[ "$answer" == INSTALL ]] || die 'installation cancelled'
}

install_yay() {
  if command -v yay >/dev/null 2>&1; then
    return 0
  fi
  log 'installing yay AUR helper'
  local build_dir
  build_dir="$(mktemp -d)"
  git clone --depth=1 https://aur.archlinux.org/yay.git "$build_dir/yay" >>"$LOG_FILE" 2>&1 || die 'could not clone yay from AUR'
  if ! (cd "$build_dir/yay" && makepkg -si --noconfirm --needed) >>"$LOG_FILE" 2>&1; then
    rm -rf -- "$build_dir"
    die 'could not build/install yay'
  fi
  rm -rf -- "$build_dir"
  command -v yay >/dev/null 2>&1 || die 'yay installation did not produce an executable'
}

install_list() {
  local manager="$1"
  local list_file="$2"
  [[ -f "$list_file" ]] || die "package manifest missing: $list_file"
  while IFS= read -r package || [[ -n "$package" ]]; do
    [[ -z "$package" || "$package" == \#* ]] && continue
    [[ "$package" =~ ^(yay|yay-bin|paru)$ ]] && continue
    log "installing $package via $manager"
    if [[ "$manager" == pacman ]]; then
      sudo pacman -S --needed --noconfirm "$package" >>"$LOG_FILE" 2>&1 || printf '%s\n' "$package" >>"$FAILURES_FILE"
    else
      yay -S --needed --noconfirm "$package" >>"$LOG_FILE" 2>&1 || printf '%s\n' "$package" >>"$FAILURES_FILE"
    fi
  done <"$list_file"
}

configure_greetd() {
  pacman -Q greetd >/dev/null 2>&1 || return 0
  pacman -Q greetd-tuigreet >/dev/null 2>&1 || { log 'greetd-tuigreet is unavailable; login manager was not enabled'; return 0; }
  log 'configuring greetd with tuigreet'
  sudo install -d -m 0755 /etc/greetd
  sudo cp -a /etc/greetd/config.toml "/etc/greetd/config.toml.backup-$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
  sudo tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --cmd Hyprland"
user = "greeter"
EOF
  id greeter >/dev/null 2>&1 || sudo useradd -r -M -G video greeter >>"$LOG_FILE" 2>&1 || log 'could not create greeter user; see install log'
  sudo systemctl enable greetd >>"$LOG_FILE" 2>&1 || log 'could not enable greetd; see install log'
}

main() {
  require_clean_arch
  confirm_overwrite
  log "starting bootstrap from $REPO_ROOT"
  sudo pacman -Syu --needed --noconfirm base-devel git rsync >>"$LOG_FILE" 2>&1 || die 'could not install bootstrap dependencies'
  install_yay
  : >"$FAILURES_FILE"
  install_list pacman "$PACMAN_LIST"
  install_list yay "$AUR_LIST"
  "$REPO_ROOT/scripts/apply.sh" --yes >>"$LOG_FILE" 2>&1 || die 'could not apply the versioned profile'
  configure_greetd
  if [[ -s "$FAILURES_FILE" ]]; then
    log "installation completed with unavailable packages listed in $FAILURES_FILE"
  else
    rm -f -- "$FAILURES_FILE"
    log 'installation completed successfully'
  fi
  log 'no monthly snapshot timer was created; only enable it explicitly on the PC base with install-scripts/setup-monthly-timer.sh --enable-remote'
  log 'reboot before starting the new Hyprland session'
}

main "$@"
