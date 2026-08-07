#!/bin/bash
# ==============================================================================
#  setup-monthly-timer.sh - Setup & Manage Monthly Systemd Snapshot Timer
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"

SERVICE_SRC="$REPO_ROOT/assets/systemd/arch-hyprland-snapshot.service"
TIMER_SRC="$REPO_ROOT/assets/systemd/arch-hyprland-snapshot.timer"

SERVICE_DEST="$SYSTEMD_USER_DIR/arch-hyprland-snapshot.service"
TIMER_DEST="$SYSTEMD_USER_DIR/arch-hyprland-snapshot.timer"

install_timer() {
  echo "=== ⏰ Installing Monthly Systemd User Timer ==="
  echo "  [+] Service file: $SERVICE_DEST"
  echo "  [+] Timer file:   $TIMER_DEST"

  # Dynamically set REPO_ROOT path in systemd service file
  sed "s|ExecStart=.*|ExecStart=$REPO_ROOT/scripts/auto-snapshot-monthly.sh|" "$SERVICE_SRC" > "$SERVICE_DEST"
  cp -a "$TIMER_SRC" "$TIMER_DEST"

  systemctl --user daemon-reload
  systemctl --user enable --now arch-hyprland-snapshot.timer

  echo "=== ✅ Monthly Snapshot Timer Activated Successfully! ==="
  systemctl --user status arch-hyprland-snapshot.timer --no-pager || true
}

disable_timer() {
  echo "=== 🛑 Disabling Monthly Systemd User Timer ==="
  systemctl --user disable --now arch-hyprland-snapshot.timer 2>/dev/null || true
  rm -f "$SERVICE_DEST" "$TIMER_DEST"
  systemctl --user daemon-reload
  echo "=== ✅ Timer disabled and removed. ==="
}

run_now() {
  echo "=== 🚀 Manually Triggering Auto-Snapshot Service ==="
  "$REPO_ROOT/scripts/auto-snapshot-monthly.sh"
}

case "${1:-}" in
  --disable)
    disable_timer
    ;;
  --run-now)
    run_now
    ;;
  *)
    install_timer
    ;;
esac
