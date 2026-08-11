#!/usr/bin/env bash
# Remote snapshots are opt-in and intended only for the PC base.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_NAME='arch-hyprland-snapshot.service'
TIMER_NAME='arch-hyprland-snapshot.timer'
SERVICE_DEST="$SYSTEMD_USER_DIR/$SERVICE_NAME"
TIMER_DEST="$SYSTEMD_USER_DIR/$TIMER_NAME"
SERVICE_TEMPLATE="$REPO_ROOT/assets/systemd/$SERVICE_NAME"
TIMER_TEMPLATE="$REPO_ROOT/assets/systemd/$TIMER_NAME"

log() { printf '[snapshot-timer] %s\n' "$*"; }
die() { printf '[snapshot-timer] error: %s\n' "$*" >&2; exit 1; }

check_remote_access() {
  [[ "$(git -C "$REPO_ROOT" branch --show-current)" == main ]] || die 'remote snapshots can only be enabled from branch main'
  local remote_url
  remote_url="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || true)"
  [[ "$remote_url" == git@*:* || "$remote_url" == ssh://* ]] || die 'origin must use SSH; configure an SSH remote first'
  git -C "$REPO_ROOT" ls-remote --exit-code origin refs/heads/main >/dev/null 2>&1 || die 'cannot read origin/main with the configured SSH key'
  git -C "$REPO_ROOT" push --dry-run origin HEAD:refs/heads/main >/dev/null 2>&1 || die 'configured SSH key cannot push to origin/main'
}

enable_remote() {
  [[ -f "$SERVICE_TEMPLATE" && -f "$TIMER_TEMPLATE" ]] || die 'systemd templates are missing'
  check_remote_access
  mkdir -p "$SYSTEMD_USER_DIR"
  # Escape sed's replacement syntax while preserving the real absolute path
  # that systemd must execute.
  local escaped_exec
  escaped_exec="$(printf '%s' "$REPO_ROOT/scripts/auto-snapshot-monthly.sh" | sed 's/[&|\\]/\\&/g')"
  sed "s|^ExecStart=.*|ExecStart=$escaped_exec|" "$SERVICE_TEMPLATE" >"$SERVICE_DEST"
  install -m 0644 "$TIMER_TEMPLATE" "$TIMER_DEST"
  systemctl --user daemon-reload
  systemctl --user enable --now "$TIMER_NAME"
  log 'remote monthly snapshot timer enabled for this PC base'
  systemctl --user status "$TIMER_NAME" --no-pager || true
}

disable_timer() {
  systemctl --user disable --now "$TIMER_NAME" 2>/dev/null || true
  rm -f -- "$SERVICE_DEST" "$TIMER_DEST"
  systemctl --user daemon-reload
  log 'snapshot timer removed'
}

status() {
  if [[ -f "$TIMER_DEST" ]]; then
    systemctl --user status "$TIMER_NAME" --no-pager || true
  else
    log 'not installed (this is the expected state on non-base machines)'
  fi
}

case "${1:-}" in
  --enable-remote) enable_remote ;;
  --disable) disable_timer ;;
  --status) status ;;
  --run-now)
    [[ -f "$SERVICE_DEST" ]] || die 'timer is not configured; use --enable-remote on the PC base first'
    systemctl --user start "$SERVICE_NAME"
    ;;
  *)
    cat <<EOF
Usage: $0 --enable-remote | --disable | --status | --run-now

Only --enable-remote creates a timer. It validates origin/main over SSH and a
dry-run push before writing any systemd unit. Do not run it on client machines.
EOF
    exit 2
    ;;
esac
