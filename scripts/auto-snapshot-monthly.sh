#!/usr/bin/env bash
# ==============================================================================
#  auto-snapshot-monthly.sh - Monthly Automated Snapshot & Git Push
#  Executes system snapshot, commits changes, and pushes to remote fork.
#  Displays a GUI error dialog on any failure.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Ensure DISPLAY & WAYLAND_DISPLAY environment variables exist for GUI dialogs
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

LOG_DIR="$REPO_ROOT/Install-Logs"
mkdir -p "$LOG_DIR"
ERROR_LOG="$LOG_DIR/monthly-snapshot-error.log"

show_error_popup() {
  local exit_code="$1"
  local line_no="$2"
  local err_msg="Ocorreu um erro ao tirar o snapshot do sistema (Linha $line_no, Código $exit_code).\n\nVerifique as conexões, chaves SSH do Git ou a permissão de arquivos.\nLog: $ERROR_LOG"

  echo -e "[ERROR] Snapshot failed at line $line_no with exit code $exit_code" >&2

  # 1. Try YAD (GUI Dialog)
  if command -v yad &>/dev/null; then
    yad --error \
      --title="Erro ao tirar snapshot do sistema" \
      --text="<b><span foreground='red'>❌ Erro ao tirar snapshot do sistema</span></b>\n\n$err_msg" \
      --button="Fechar:0" \
      --width=550 \
      --height=220 \
      --center \
      --window-icon="error" 2>/dev/null || true
  # 2. Fallback to Rofi
  elif command -v rofi &>/dev/null; then
    rofi -e "❌ Erro ao tirar snapshot do sistema!\n\nCheck log: $ERROR_LOG" 2>/dev/null || true
  # 3. Fallback to notify-send
  elif command -v notify-send &>/dev/null; then
    notify-send -u critical "Erro ao tirar snapshot do sistema" "$err_msg" 2>/dev/null || true
  fi
}

trap 'show_error_popup $? $LINENO' ERR

echo "=== 🔄 Running Monthly Snapshot & Git Backup ===" | tee "$ERROR_LOG"

# 1. Run main snapshot script
echo "  [1/3] Extracting dotfiles & package lists..." | tee -a "$ERROR_LOG"
"$SCRIPT_DIR/snapshot.sh" >> "$ERROR_LOG" 2>&1

cd "$REPO_ROOT"

# 2. Check for changes in git
if [ -n "$(git status --porcelain)" ]; then
  echo "  [2/3] Changes detected. Committing to git..." | tee -a "$ERROR_LOG"
  git add -A >> "$ERROR_LOG" 2>&1
  git commit -m "auto-snapshot: $(date +'%Y-%m-%d %H:%M')" >> "$ERROR_LOG" 2>&1

  echo "  [3/3] Pushing changes to remote fork..." | tee -a "$ERROR_LOG"
  git push origin main >> "$ERROR_LOG" 2>&1

  if command -v notify-send &>/dev/null; then
    notify-send -u normal "Snapshot do Sistema" "Snapshot mensal realizado e enviado com sucesso ao GitHub!" 2>/dev/null || true
  fi
  echo "=== ✅ Auto-snapshot complete and pushed! ===" | tee -a "$ERROR_LOG"
else
  echo "=== ℹ️ System snapshot up-to-date. No changes to commit. ===" | tee -a "$ERROR_LOG"
  if command -v notify-send &>/dev/null; then
    notify-send -u low "Snapshot do Sistema" "Sistema verificado: nenhuma alteração recente para enviar." 2>/dev/null || true
  fi
fi
