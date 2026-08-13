#!/usr/bin/env bash
# Complete, repeatable bootstrap for the portable Arch + Hyprland profile.
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACMAN_LIST="$REPO_ROOT/assets/packages/pacman-explicit.txt"
OPTIONAL_PACMAN_LIST="$REPO_ROOT/assets/packages/pacman-optional.txt"
REQUIRED_AUR_LIST="$REPO_ROOT/assets/packages/aur-required.txt"
OPTIONAL_AUR_LIST="$REPO_ROOT/assets/packages/aur-optional.txt"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/arch-hyprland"
RUN_ID="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$STATE_DIR/install-$RUN_ID.log"
FAILURES_FILE="$STATE_DIR/install-package-failures-$RUN_ID.txt"
SUMMARY_FILE="$STATE_DIR/install-summary-$RUN_ID.txt"
MODE=""
NVIDIA_CHOICE=""
ASSUME_YES=false
SUDO_KEEPALIVE_PID=""
UI_AVAILABLE=false
CURRENT_STEP='initialization'
CRITICAL_FAILURES=0
THEME_WARNINGS=0
OPTIONAL_FAILURES=0

mkdir -p "$STATE_DIR"
touch "$LOG_FILE"
: >"$SUMMARY_FILE"
export ARCH_HYPRLAND_LOG_FILE="$LOG_FILE"

log() { printf '%s [install] %s\n' "$(date --iso-8601=seconds)" "$*" | tee -a "$LOG_FILE"; }

configure_terminal_ui() {
  [[ -n "${NEWT_COLORS:-}" ]] && return 0
  export NEWT_COLORS='
root=white,black
border=cyan,black
window=white,black
shadow=black,black
title=yellow,black
button=black,cyan
actbutton=black,lightgray
textbox=white,black
acttextbox=black,cyan
entry=white,black
label=white,black
listbox=white,black
actlistbox=black,cyan
checkbox=white,black
actcheckbox=black,cyan
'
}

cleanup() {
  if [[ -n "$SUDO_KEEPALIVE_PID" ]]; then
    kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
    wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

show_error() {
  local message="$1"
  printf 'FAIL\t%s\t%s\n' "$CURRENT_STEP" "$message" >>"$SUMMARY_FILE"
  log "ERROR: $message"
  if $UI_AVAILABLE; then
    whiptail --title 'Installation failed' --msgbox "$message\n\nLog: $LOG_FILE\nSummary: $SUMMARY_FILE" 13 78 || true
  fi
}
die() { show_error "$*"; exit 1; }
trap 'die "The step at line $LINENO failed. No successful completion was recorded."' ERR

usage() {
  cat <<'EOF'
Usage: ./install.sh [--mode repair|clean] [--nvidia open|nouveau|skip] [--yes]

Without --yes, an interactive terminal UI displays warnings and choices.
The clean mode resets only paths managed by this project and keeps a backup.
EOF
}

while (($#)); do
  case "$1" in
    --mode) MODE="${2:-}"; shift ;;
    --nvidia) NVIDIA_CHOICE="${2:-}"; shift ;;
    --yes) ASSUME_YES=true ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage; exit 2 ;;
  esac
  shift
done
[[ -z "$MODE" || "$MODE" == repair || "$MODE" == clean ]] || die "Invalid installation mode: $MODE"
[[ -z "$NVIDIA_CHOICE" || "$NVIDIA_CHOICE" == open || "$NVIDIA_CHOICE" == nouveau || "$NVIDIA_CHOICE" == skip ]] || die "Invalid NVIDIA option: $NVIDIA_CHOICE"

require_arch_and_sudo() {
  [[ $EUID -ne 0 ]] || die 'Run this installer as the target user, not as root.'
  [[ -f /etc/arch-release ]] || die 'This installer supports Arch Linux only.'
  command -v sudo >/dev/null 2>&1 || die 'sudo is not installed.'
  printf 'Authenticate once for the entire installation.\n'
  sudo -v || die 'sudo authentication failed.'
  (
    while sudo -n true >/dev/null 2>&1; do
      sleep 45
    done
  ) &
  SUDO_KEEPALIVE_PID=$!
}

bootstrap_ui() {
  if ! command -v whiptail >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm libnewt >>"$LOG_FILE" 2>&1 || \
      log 'Could not install whiptail; continuing with the terminal interface.'
  fi
  if command -v whiptail >/dev/null 2>&1 && [[ -t 0 && -t 1 ]]; then
    configure_terminal_ui
    UI_AVAILABLE=true
  fi
}

collect_choices() {
  if $ASSUME_YES; then
    MODE="${MODE:-repair}"
    return
  fi
  $UI_AVAILABLE || die 'The terminal UI requires an interactive terminal. Use --yes for automation.'

  clear
  printf '\n\033[1;35m'
  printf '    ╦ ╦╦ ╦╔═╗╦═╗╦  ╔═╗╔╗╔╔╦╗\n'
  printf '    ╠═╣╚╦╝╠═╝╠╦╝║  ╠═╣║║║ ║║\n'
  printf '    ╩ ╩ ╩ ╩  ╩╚═╩═╝╩ ╩╝╚╝═╩╝  Arch Linux\n'
  printf '\033[0m\n'
  whiptail --title 'Arch Hyprland — welcome' \
    --yes-button 'Continue' --no-button 'Cancel' \
    --yesno "This installer prepares a complete, portable Hyprland desktop.\n\nIt installs packages, applies the versioned profile, configures Zsh and Code Flow, and enables the greetd/UWSM session. Existing managed files are backed up in:\n$STATE_DIR\n\nOptional AUR apps may fail without blocking the desktop setup." 18 78 \
    || die 'Installation cancelled.'

  MODE="$(whiptail --title 'Installation mode' --menu \
    'Choose how this machine should be prepared:' 15 78 2 \
    repair 'Repair/update — safe to run repeatedly (recommended)' \
    clean 'Clean reinstall — recreate only managed runtime components' \
    3>&1 1>&2 2>&3)" || die 'Installation cancelled.'

  if [[ "$MODE" == clean ]]; then
    whiptail --title 'Clean reinstall' \
      --yes-button 'Reset and reinstall' --no-button 'Go back' \
      --yesno 'Managed configuration, Oh My Zsh, and Code Flow will be moved to a dated backup and recreated. Accounts, personal documents, keys, and unmanaged packages will not be deleted.' 15 76 \
      || die 'Clean reinstall cancelled.'
  fi
}

ui_status() {
  local message="$1"
  log "========== $message =========="
  printf '\n\033[1;36m==> %s\033[0m\n' "$message"
}

begin_step() {
  CURRENT_STEP="$1"
  ui_status "$1"
}

complete_step() {
  printf 'OK\t%s\n' "$CURRENT_STEP" >>"$SUMMARY_FILE"
  CURRENT_STEP='between steps'
}

report() {
  local status="$1" component="$2" message="${3:-}"
  printf '%s\t%s%s\n' "$status" "$component" "${message:+\t$message}" | tee -a "$SUMMARY_FILE"
  log "$status $component${message:+: $message}"
}

detect_nvidia() {
  command -v lspci >/dev/null 2>&1 || return 1
  NVIDIA_GPU="$(lspci -nn | awk 'BEGIN { IGNORECASE=1 } /NVIDIA/ && /(VGA|3D|Display)/ && !found { print; found=1 }')"
  [[ -n "$NVIDIA_GPU" ]]
}

choose_nvidia_driver() {
  detect_nvidia || { NVIDIA_CHOICE=skip; return; }
  local gpu="$NVIDIA_GPU"
  if $ASSUME_YES; then
    NVIDIA_CHOICE="${NVIDIA_CHOICE:-skip}"
    return
  fi
  NVIDIA_CHOICE="$(whiptail --title 'NVIDIA GPU detected' --radiolist \
    "$gpu\n\nChoose a driver. nvidia-open-dkms is recommended for Turing/GTX 16 and newer GPUs." \
    18 84 3 \
    open 'NVIDIA open kernel modules (recommended)' on \
    nouveau 'Driver Nouveau/Mesa' off \
    skip 'Do not change drivers now' off \
    3>&1 1>&2 2>&3)" || die 'Driver selection cancelled.'
}

clean_managed_runtime() {
  [[ "$MODE" == clean ]] || return 0
  local backup="$STATE_DIR/clean-reset-$RUN_ID"
  mkdir -p "$backup/.local/share" "$backup/.local/bin"
  local path relative
  for path in \
    "$HOME/.oh-my-zsh" \
    "$HOME/.local/share/codex-flow" \
    "$HOME/.local/bin/codex-flow"; do
    [[ -e "$path" || -L "$path" ]] || continue
    relative="${path#"$HOME/"}"
    mkdir -p "$backup/$(dirname "$relative")"
    mv -- "$path" "$backup/$relative"
  done
  log "previous runtime components preserved in $backup"
}

install_yay() {
  command -v yay >/dev/null 2>&1 && return 0
  local build_dir
  build_dir="$(mktemp -d)"
  git clone --depth=1 https://aur.archlinux.org/yay.git "$build_dir/yay" >>"$LOG_FILE" 2>&1
  (cd "$build_dir/yay" && makepkg -si --noconfirm --needed) >>"$LOG_FILE" 2>&1
  rm -rf -- "$build_dir"
  command -v yay >/dev/null 2>&1
}

yay_install() {
  local package="$1" retry=false
  local -a yay_args=(--needed --noconfirm --answerclean All --answerdiff None --cleanmenu=false --diffmenu=false)

  log "installing AUR package $package (normal build)"
  if yay -S "${yay_args[@]}" "$package" >>"$LOG_FILE" 2>&1; then
    return 0
  fi

  # A checksum failure is commonly a stale per-package clone/source cache.  Do
  # not weaken makepkg validation and do not clean Yay's global cache.
  retry=true
  local cache_root cache_path
  cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/yay"
  cache_path="$cache_root/$package"
  if [[ -d "$cache_path" && "$cache_path" == "$cache_root/"* ]]; then
    log "AUR package $package failed; removing only its build cache: $cache_path"
    rm -rf -- "$cache_path"
  else
    log "AUR package $package failed; no default per-package Yay cache was found"
  fi

  if $retry; then
    log "retrying AUR package $package once with refreshed metadata and a clean build"
    yay -Syu --noconfirm --answerclean All --answerdiff None --cleanmenu=false --diffmenu=false >>"$LOG_FILE" 2>&1 || \
      log "metadata refresh reported an error; continuing with the clean build attempt for $package"
    yay -S "${yay_args[@]}" --cleanbuild "$package" >>"$LOG_FILE" 2>&1 && return 0
  fi
  return 1
}

install_package_list() {
  local manager="$1" list_file="$2" criticality="$3" skip_list="${4:-}" package
  [[ -f "$list_file" ]] || die "Package manifest is missing: $list_file"
  while IFS= read -r package || [[ -n "$package" ]]; do
    [[ -z "$package" || "$package" == \#* || "$package" =~ ^(yay|yay-bin|paru)$ ]] && continue
    if [[ -n "$skip_list" && -f "$skip_list" ]] && grep -Fqx "$package" "$skip_list"; then
      continue
    fi
    if pacman -Q "$package" >/dev/null 2>&1; then
      report OK "$package" 'already installed'
      continue
    fi
    log "installing $criticality package $package via $manager"
    if [[ "$manager" == pacman ]]; then
      if ! sudo pacman -S --needed --noconfirm "$package" >>"$LOG_FILE" 2>&1; then
        log "package manager reported a failure for $package"
      fi
    else
      if ! yay_install "$package"; then
        log "AUR installation failed after the clean-build retry for $package"
      fi
    fi
    if pacman -Q "$package" >/dev/null 2>&1; then
      report OK "$package"
      continue
    fi
    printf '%s:%s:%s\n' "$criticality" "$manager" "$package" >>"$FAILURES_FILE"
    case "$criticality" in
      critical) CRITICAL_FAILURES=$((CRITICAL_FAILURES + 1)); report FAIL "$package" 'required package was not installed' ;;
      theme) THEME_WARNINGS=$((THEME_WARNINGS + 1)); report WARN "$package" 'theme package was not installed' ;;
      optional) OPTIONAL_FAILURES=$((OPTIONAL_FAILURES + 1)); report OPTIONAL "$package" 'optional package failed; continuing' ;;
      *) die "Unknown package criticality: $criticality" ;;
    esac
  done <"$list_file"
}

configure_greetd() {
  command -v tuigreet >/dev/null 2>&1 || die 'tuigreet is not available.'
  command -v uwsm >/dev/null 2>&1 || die 'uwsm is not available.'
  sudo install -d -m 0755 /etc/greetd
  [[ ! -f /etc/greetd/config.toml ]] || sudo cp -a /etc/greetd/config.toml "/etc/greetd/config.toml.backup-$RUN_ID"
  sudo tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --cmd 'uwsm start hyprland.desktop'"
user = "greeter"
EOF
  sudo chmod 0644 /etc/greetd/config.toml
  id greeter >/dev/null 2>&1 || sudo useradd -r -M -G video greeter
  for manager in sddm gdm lightdm ly; do
    sudo systemctl disable "$manager.service" >/dev/null 2>&1 || true
  done
  sudo systemctl enable greetd >>"$LOG_FILE" 2>&1
  systemctl is-enabled greetd >/dev/null 2>&1
}

main() {
  require_arch_and_sudo
  bootstrap_ui
  collect_choices

  begin_step 'Preparing bootstrap dependencies'
  sudo pacman -Syu --needed --noconfirm base-devel git curl rsync pciutils libnewt >>"$LOG_FILE" 2>&1
  install_yay || die 'Could not install yay.'
  choose_nvidia_driver
  complete_step

  : >"$FAILURES_FILE"
  begin_step 'Installing official repository packages'
  install_package_list pacman "$PACMAN_LIST" critical "$OPTIONAL_PACMAN_LIST"
  (( CRITICAL_FAILURES == 0 )) || die "Required official packages failed. Failure list: $FAILURES_FILE"
  complete_step
  begin_step 'Installing optional repository applications'
  install_package_list pacman "$OPTIONAL_PACMAN_LIST" optional
  complete_step
  begin_step 'Installing theme dependencies from the AUR'
  install_package_list yay "$REQUIRED_AUR_LIST" theme
  complete_step
  begin_step 'Installing optional AUR applications'
  install_package_list yay "$OPTIONAL_AUR_LIST" optional
  complete_step

  clean_managed_runtime

  if [[ "$NVIDIA_CHOICE" != skip ]]; then
    begin_step 'Configuring the selected NVIDIA driver'
    "$REPO_ROOT/install-scripts/nvidia-auto.sh" "$NVIDIA_CHOICE" >>"$LOG_FILE" 2>&1
    complete_step
  fi

  begin_step 'Applying the theme, Hyprland, Waybar, and wallpaper'
  "$REPO_ROOT/scripts/apply.sh" --yes >>"$LOG_FILE" 2>&1
  complete_step

  begin_step 'Configuring Zsh, Powerlevel10k, and plugins'
  "$REPO_ROOT/install-scripts/configure-zsh.sh" >>"$LOG_FILE" 2>&1
  complete_step

  begin_step 'Installing Codex CLI and Code Flow'
  "$REPO_ROOT/install-scripts/code-flow.sh" >>"$LOG_FILE" 2>&1
  complete_step

  begin_step 'Configuring the greetd/UWSM session'
  configure_greetd
  complete_step

  begin_step 'Running final diagnostics'
  "$REPO_ROOT/install-scripts/validate-install.sh" >>"$LOG_FILE" 2>&1
  complete_step

  if (( THEME_WARNINGS || OPTIONAL_FAILURES )); then
    log "installation completed with $THEME_WARNINGS theme warning(s) and $OPTIONAL_FAILURES optional package failure(s)"
  else
    log 'installation completed and validated successfully'
  fi
  if $UI_AVAILABLE; then
    whiptail --title 'Arch Hyprland — complete' --msgbox \
      "The core desktop profile was installed and validated.\n\nRestart to enter the greetd/UWSM Hyprland session.\n\nSummary: $SUMMARY_FILE\nLog: $LOG_FILE\n\nTheme warnings: $THEME_WARNINGS\nOptional app failures: $OPTIONAL_FAILURES" 17 78
  else
    printf '\nInstallation complete. Restart the computer.\nSummary: %s\nLog: %s\n' "$SUMMARY_FILE" "$LOG_FILE"
  fi
}

main "$@"
