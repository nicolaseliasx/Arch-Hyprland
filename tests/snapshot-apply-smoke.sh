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

mkdir -p "$REPO/scripts" "$REPO/assets" "$BASE_HOME/.config/demo" "$BASE_HOME/.config/hypr" "$BASE_HOME/.config/systemd/user/timers.target.wants" "$BASE_HOME/.config/Codex" "$BASE_HOME/.config/anytype" "$BASE_HOME/.config/obsidian" "$BASE_HOME/pictures/wallpapers" "$CLIENT_HOME/.config/stale" "$BIN"
cp "$ROOT/scripts/snapshot.sh" "$ROOT/scripts/apply.sh" "$REPO/scripts/"
cp "$ROOT/assets/snapshot-paths.txt" "$REPO/assets/"
printf 'kept=true\n' >"$BASE_HOME/.config/demo/settings.ini"
printf 'do-not-copy\n' >"$BASE_HOME/.config/demo/api-token.txt"
printf '[Timer]\n' >"$BASE_HOME/.config/systemd/user/arch-hyprland-snapshot.timer"
printf 'source=%s/.config/demo\n' "$BASE_HOME" >"$BASE_HOME/.config/demo/home-path.conf"
printf 'workspace = 1, monitor:DP-3\nworkspace = special:special, gapsin:0\n' >"$BASE_HOME/.config/hypr/workspaces.conf"
printf '    monitor = DP-3\n' >"$BASE_HOME/.config/hypr/hyprlock.conf"
printf '    unlock_cmd = hyprctl dispatch dpms on DP-2\n' >"$BASE_HOME/.config/hypr/hypridle.conf"
printf 'runtime-state\n' >"$BASE_HOME/.config/Codex/Local State"
printf 'runtime-state\n' >"$BASE_HOME/.config/anytype/session.db"
printf 'runtime-state\n' >"$BASE_HOME/.config/obsidian/session.json"
printf 'wallpaper\n' >"$BASE_HOME/pictures/wallpapers/base.jpg"
printf 'old=true\n' >"$CLIENT_HOME/.config/stale/settings.ini"

cat >"$BIN/pacman" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  '-Qqen') printf 'arch-package\n' ;;
  '-Qqem') printf 'aur-package\n' ;;
  '-Qqm') printf 'aur-package\nforeign-dependency\nforeign-dependency-debug\n' ;;
  '-Qqe') printf 'arch-package 1.0-1\n' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$BIN/pacman"

cat >"$BIN/yay" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == '-Qqm' ]] || exit 1
printf 'aur-package\nforeign-dependency\nforeign-dependency-debug\n'
EOF
chmod +x "$BIN/yay"

PATH="$BIN:$PATH" ARCH_HYPRLAND_REPO_ROOT="$REPO" SNAPSHOT_HOME="$BASE_HOME" "$REPO/scripts/snapshot.sh"
[[ -f "$REPO/assets/dotfiles/.config/demo/settings.ini" ]]
[[ ! -e "$REPO/assets/dotfiles/.config/demo/api-token.txt" ]]
[[ ! -e "$REPO/assets/dotfiles/.config/systemd/user/arch-hyprland-snapshot.timer" ]]
[[ ! -e "$REPO/assets/dotfiles/.config/Codex" ]]
[[ ! -e "$REPO/assets/dotfiles/.config/anytype" ]]
[[ ! -e "$REPO/assets/dotfiles/.config/obsidian" ]]
grep -Fqx 'aur-package' "$REPO/assets/packages/aur-explicit.txt"
[[ "$(grep -c 'foreign-dependency' "$REPO/assets/packages/aur-explicit.txt" || true)" -eq 0 ]]
[[ "$(grep -c 'foreign-dependency-debug' "$REPO/assets/packages/aur-explicit.txt" || true)" -eq 0 ]]
grep -qx 'monitor = , preferred, auto, 1' "$REPO/assets/dotfiles/.config/hypr/monitors.conf"
grep -Fqx 'source=$HOME/.config/demo' "$REPO/assets/dotfiles/.config/demo/home-path.conf"
[[ "$(grep -c 'monitor:DP-3' "$REPO/assets/dotfiles/.config/hypr/workspaces.conf" || true)" -eq 0 ]]
grep -Fqx 'workspace = special:special, gapsin:0' "$REPO/assets/dotfiles/.config/hypr/workspaces.conf"
grep -Eq '^[[:space:]]*monitor[[:space:]]*=$' "$REPO/assets/dotfiles/.config/hypr/hyprlock.conf"
grep -Fqx '    unlock_cmd = hyprctl dispatch dpms on' "$REPO/assets/dotfiles/.config/hypr/hypridle.conf"

PATH="$BIN:$PATH" ARCH_HYPRLAND_REPO_ROOT="$REPO" APPLY_HOME="$CLIENT_HOME" XDG_STATE_HOME="$WORK/state" "$REPO/scripts/apply.sh" --yes
[[ -f "$CLIENT_HOME/.config/demo/settings.ini" ]]
[[ ! -e "$CLIENT_HOME/.config/stale" ]]
find "$WORK/state/arch-hyprland/backups" -path '*/.config/stale/settings.ini' -type f -print -quit | grep -q .
printf 'snapshot/apply smoke test passed\n'
