#!/usr/bin/env bash
# Complete, repeatable bootstrap for the portable Arch + Hyprland profile.
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACMAN_LIST="$REPO_ROOT/assets/packages/pacman-explicit.txt"
AUR_LIST="$REPO_ROOT/assets/packages/aur-explicit.txt"
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

mkdir -p "$STATE_DIR"
touch "$LOG_FILE"
: >"$SUMMARY_FILE"
export ARCH_HYPRLAND_LOG_FILE="$LOG_FILE"

log() { printf '%s [install] %s\n' "$(date --iso-8601=seconds)" "$*" | tee -a "$LOG_FILE"; }

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
    dialog --clear --title 'Falha na instalação' --msgbox "$message\n\nLog: $LOG_FILE" 12 72 || true
  fi
}
die() { show_error "$*"; exit 1; }
trap 'die "A etapa na linha $LINENO falhou. Nenhuma conclusão de sucesso foi registrada."' ERR

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
[[ -z "$MODE" || "$MODE" == repair || "$MODE" == clean ]] || die "Modo inválido: $MODE"
[[ -z "$NVIDIA_CHOICE" || "$NVIDIA_CHOICE" == open || "$NVIDIA_CHOICE" == nouveau || "$NVIDIA_CHOICE" == skip ]] || die "Opção NVIDIA inválida: $NVIDIA_CHOICE"

require_arch_and_sudo() {
  [[ $EUID -ne 0 ]] || die 'Execute como usuário normal, não como root.'
  [[ -f /etc/arch-release ]] || die 'Este instalador suporta somente Arch Linux.'
  command -v sudo >/dev/null 2>&1 || die 'sudo não está instalado.'
  printf 'Autentique uma vez para toda a instalação.\n'
  sudo -v || die 'A autenticação sudo falhou.'
  (
    while sudo -n true >/dev/null 2>&1; do
      sleep 45
    done
  ) &
  SUDO_KEEPALIVE_PID=$!
}

bootstrap_ui() {
  sudo pacman -S --needed --noconfirm dialog >/dev/null 2>>"$LOG_FILE" || true
  if command -v dialog >/dev/null 2>&1 && [[ -t 0 && -t 1 ]]; then
    UI_AVAILABLE=true
  fi
}

collect_choices() {
  if $ASSUME_YES; then
    MODE="${MODE:-repair}"
    return
  fi
  $UI_AVAILABLE || die 'A interface TUI requer um terminal interativo. Use --yes para automação.'

  dialog --clear --title 'Arch Hyprland Setup' \
    --yes-label 'Continuar' --no-label 'Cancelar' \
    --yesno 'Este instalador modifica pacotes, configurações do usuário, shell padrão e gerenciador de login. Um backup datado será criado antes de substituir qualquer configuração gerenciada.' 14 72 \
    || die 'Instalação cancelada.'

  MODE="$(dialog --stdout --clear --title 'Modo de instalação' --menu \
    'Escolha como deseja prosseguir:' 15 76 2 \
    repair 'Reparar/atualizar — reaplica tudo de forma idempotente' \
    clean 'Reinstalação limpa — zera componentes gerenciados e reinstala')" || die 'Instalação cancelada.'

  if [[ "$MODE" == clean ]]; then
    dialog --clear --title 'Atenção: reinstalação limpa' \
      --yes-label 'Zerar e reinstalar' --no-label 'Voltar' \
      --yesno 'As configurações gerenciadas, Oh My Zsh e Code Flow serão movidos para um backup datado e recriados. Contas, documentos pessoais, chaves e pacotes não gerenciados não serão apagados.' 15 76 \
      || die 'Reinstalação limpa cancelada.'
  fi
}

ui_status() {
  local message="$1"
  log "$message"
  $UI_AVAILABLE && dialog --clear --title 'Arch Hyprland Setup' --infobox "$message\n\nOs detalhes estão sendo gravados em:\n$LOG_FILE" 9 72 || true
}

begin_step() {
  CURRENT_STEP="$1"
  ui_status "$1"
}

complete_step() {
  printf 'OK\t%s\n' "$CURRENT_STEP" >>"$SUMMARY_FILE"
  CURRENT_STEP='between steps'
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
  NVIDIA_CHOICE="$(dialog --stdout --clear --title 'GPU NVIDIA detectada' --radiolist \
    "$gpu\n\nEscolha o driver. nvidia-open-dkms é recomendado para GPUs Turing/GTX 16 e mais novas." \
    18 84 3 \
    open 'NVIDIA open kernel modules (recomendado)' on \
    nouveau 'Driver Nouveau/Mesa' off \
    skip 'Não alterar drivers agora' off)" || die 'Seleção de driver cancelada.'
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
  log "componentes de runtime anteriores preservados em $backup"
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

install_package_list() {
  local manager="$1" list_file="$2" package
  [[ -f "$list_file" ]] || die "Manifesto ausente: $list_file"
  while IFS= read -r package || [[ -n "$package" ]]; do
    [[ -z "$package" || "$package" == \#* || "$package" =~ ^(yay|yay-bin|paru)$ ]] && continue
    if pacman -Q "$package" >/dev/null 2>&1; then
      continue
    fi
    log "instalando pacote $package via $manager"
    if [[ "$manager" == pacman ]]; then
      sudo pacman -S --needed --noconfirm "$package" >>"$LOG_FILE" 2>&1 || true
    else
      yay -S --needed --noconfirm "$package" >>"$LOG_FILE" 2>&1 || true
    fi
    pacman -Q "$package" >/dev/null 2>&1 || printf '%s:%s\n' "$manager" "$package" >>"$FAILURES_FILE"
  done <"$list_file"
}

configure_greetd() {
  command -v tuigreet >/dev/null 2>&1 || die 'tuigreet não está disponível.'
  command -v uwsm >/dev/null 2>&1 || die 'uwsm não está disponível.'
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

  begin_step 'Preparando dependências básicas'
  sudo pacman -Syu --needed --noconfirm base-devel git curl rsync pciutils dialog >>"$LOG_FILE" 2>&1
  install_yay || die 'Não foi possível instalar o yay.'
  choose_nvidia_driver
  complete_step

  : >"$FAILURES_FILE"
  begin_step 'Instalando pacotes oficiais'
  install_package_list pacman "$PACMAN_LIST"
  complete_step
  begin_step 'Instalando pacotes do AUR'
  install_package_list yay "$AUR_LIST"
  if [[ -s "$FAILURES_FILE" ]]; then
    die "Alguns pacotes falharam. A configuração não foi aplicada. Lista: $FAILURES_FILE"
  fi
  rm -f -- "$FAILURES_FILE"
  complete_step

  clean_managed_runtime

  if [[ "$NVIDIA_CHOICE" != skip ]]; then
    begin_step 'Configurando o driver NVIDIA selecionado'
    "$REPO_ROOT/install-scripts/nvidia-auto.sh" "$NVIDIA_CHOICE" >>"$LOG_FILE" 2>&1
    complete_step
  fi

  begin_step 'Aplicando tema, Hyprland, Waybar e wallpaper'
  "$REPO_ROOT/scripts/apply.sh" --yes >>"$LOG_FILE" 2>&1
  complete_step

  begin_step 'Configurando Zsh, Powerlevel10k e plugins'
  "$REPO_ROOT/install-scripts/configure-zsh.sh" >>"$LOG_FILE" 2>&1
  complete_step

  begin_step 'Instalando Codex CLI e Code Flow'
  "$REPO_ROOT/install-scripts/code-flow.sh" >>"$LOG_FILE" 2>&1
  complete_step

  begin_step 'Configurando a sessão greetd/UWSM'
  configure_greetd
  complete_step

  begin_step 'Executando diagnóstico final'
  "$REPO_ROOT/install-scripts/validate-install.sh" >>"$LOG_FILE" 2>&1
  complete_step

  log 'instalação concluída e validada com sucesso'
  if $UI_AVAILABLE; then
    dialog --clear --title 'Instalação concluída' --msgbox \
      "Hyprland, Waybar, tema, wallpaper, Zsh, Eza e Code Flow foram instalados e validados.\n\nReinicie o computador para entrar pela sessão greetd/UWSM.\n\nResumo: $SUMMARY_FILE\nLog: $LOG_FILE" 16 78
  else
    printf '\nInstalação concluída. Reinicie o computador.\nResumo: %s\nLog: %s\n' "$SUMMARY_FILE" "$LOG_FILE"
  fi
}

main "$@"
