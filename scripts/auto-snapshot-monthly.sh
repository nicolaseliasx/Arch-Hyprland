#!/usr/bin/env bash
# This script is intentionally usable only from the explicitly enabled remote
# timer on the PC base. It never stages arbitrary working-tree changes.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${ARCH_HYPRLAND_REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/arch-hyprland"
LOG_FILE="$STATE_DIR/monthly-snapshot.log"
MANAGED_ARTIFACTS=(assets/dotfiles assets/packages assets/snapshot-metadata.env)

mkdir -p "$STATE_DIR"
log() { printf '%s [monthly-snapshot] %s\n' "$(date --iso-8601=seconds)" "$*" | tee -a "$LOG_FILE"; }
notify() {
  command -v notify-send >/dev/null 2>&1 || return 0
  notify-send "$1" "$2" >/dev/null 2>&1 || true
}
fail() { log "ERROR: $*"; notify 'Snapshot do sistema falhou' "$*"; exit 1; }
on_error() { fail "unexpected error at line $1 (exit $2); see $LOG_FILE"; }
trap 'on_error "$LINENO" "$?"' ERR

require_clean_main() {
  [[ "$(git -C "$REPO_ROOT" branch --show-current)" == main ]] || fail 'the remote timer only runs from branch main'
  [[ -n "$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || true)" ]] || fail 'origin remote is not configured'
  [[ -z "$(git -C "$REPO_ROOT" status --porcelain --untracked-files=all)" ]] || fail 'repository has local changes; resolve them before the scheduled snapshot'
  git -C "$REPO_ROOT" ls-remote --exit-code origin refs/heads/main >/dev/null 2>&1 || fail 'cannot access origin/main through Git/SSH'
  git -C "$REPO_ROOT" fetch --quiet origin main || fail 'could not fetch origin/main'
  local_head="$(git -C "$REPO_ROOT" rev-parse HEAD)"
  remote_head="$(git -C "$REPO_ROOT" rev-parse origin/main)"
  [[ "$local_head" == "$remote_head" ]] || fail 'local main is not synchronized with origin/main; update it manually first'
}

main() {
  require_clean_main
  log 'capturing PC-base profile'
  "$SCRIPT_DIR/snapshot.sh" >>"$LOG_FILE" 2>&1

  git -C "$REPO_ROOT" add -- "${MANAGED_ARTIFACTS[@]}"
  if git -C "$REPO_ROOT" diff --cached --quiet; then
    log 'no profile changes detected'
    notify 'Snapshot do sistema' 'Nenhuma alteração no perfil versionado.'
    return 0
  fi

  git -C "$REPO_ROOT" commit -m "auto-snapshot: $(date +'%Y-%m-%d %H:%M')" >>"$LOG_FILE" 2>&1 || fail 'could not commit generated snapshot artifacts'
  git -C "$REPO_ROOT" push origin HEAD:main >>"$LOG_FILE" 2>&1 || fail 'commit created locally but push to origin/main failed'
  log 'snapshot committed and pushed to origin/main'
  notify 'Snapshot do sistema' 'Perfil mensal enviado ao GitHub com sucesso.'
}

main "$@"
