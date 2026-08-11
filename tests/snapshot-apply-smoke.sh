#!/usr/bin/env bash
# Non-privileged integration test for the portable snapshot and exact restore.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT
REPO="$WORK/repo"
BASE_HOME="$WORK/base-home"
CLIENT_HOME="$WORK/client-home"
BIN="$WORK/bin"

mkdir -p "$REPO/scripts" "$REPO/assets" "$BASE_HOME/.config/demo" "$BASE_HOME/.config/hypr" "$BASE_HOME/.config/systemd/user/timers.target.wants" "$BASE_HOME/pictures/wallpapers" "$CLIENT_HOME/.config/stale" "$BIN"
cp "$ROOT/scripts/snapshot.sh" "$ROOT/scripts/apply.sh" "$REPO/scripts/"
cp "$ROOT/assets/snapshot-paths.txt" "$REPO/assets/"
printf 'kept=true\n' >"$BASE_HOME/.config/demo/settings.ini"
printf 'do-not-copy\n' >"$BASE_HOME/.config/demo/api-token.txt"
printf '[Timer]\n' >"$BASE_HOME/.config/systemd/user/arch-hyprland-snapshot.timer"
printf 'wallpaper\n' >"$BASE_HOME/pictures/wallpapers/base.jpg"
printf 'old=true\n' >"$CLIENT_HOME/.config/stale/settings.ini"

cat >"$BIN/pacman" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  '-Qqen') printf 'arch-package\n' ;;
  '-Qqem'|'-Qqm') printf 'aur-package\n' ;;
  '-Qqe') printf 'arch-package 1.0-1\n' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$BIN/pacman"

PATH="$BIN:$PATH" ARCH_HYPRLAND_REPO_ROOT="$REPO" SNAPSHOT_HOME="$BASE_HOME" "$REPO/scripts/snapshot.sh"
[[ -f "$REPO/assets/dotfiles/.config/demo/settings.ini" ]]
[[ ! -e "$REPO/assets/dotfiles/.config/demo/api-token.txt" ]]
[[ ! -e "$REPO/assets/dotfiles/.config/systemd/user/arch-hyprland-snapshot.timer" ]]
grep -qx 'monitor = , preferred, auto, 1' "$REPO/assets/dotfiles/.config/hypr/monitors.conf"

PATH="$BIN:$PATH" ARCH_HYPRLAND_REPO_ROOT="$REPO" APPLY_HOME="$CLIENT_HOME" XDG_STATE_HOME="$WORK/state" "$REPO/scripts/apply.sh" --yes
[[ -f "$CLIENT_HOME/.config/demo/settings.ini" ]]
[[ ! -e "$CLIENT_HOME/.config/stale" ]]
find "$WORK/state/arch-hyprland/backups" -path '*/.config/stale/settings.ini' -type f -print -quit | grep -q .
printf 'snapshot/apply smoke test passed\n'
