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

mkdir -p "$REPO/scripts" "$REPO/assets" "$BASE_HOME/.config/demo" "$BASE_HOME/.config/hypr/shaders" "$BASE_HOME/.config/waybar/configs" "$BASE_HOME/.config/waybar/style" "$BASE_HOME/.config/rofi" "$BASE_HOME/.config/systemd/user/timers.target.wants" "$BASE_HOME/.config/Codex" "$BASE_HOME/.config/anytype" "$BASE_HOME/.config/obsidian" "$BASE_HOME/.themes/NCLS-Black-Waybar/gtk-3.0" "$BASE_HOME/pictures/wallpapers" "$CLIENT_HOME/.config/stale" "$BIN"
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
printf 'return true\n' >"$BASE_HOME/.config/hypr/hyprland.lua"
printf 'shader\n' >"$BASE_HOME/.config/hypr/shaders/digital-vibrance-90.frag"
printf '{}\n' >"$BASE_HOME/.config/waybar/configs/default"
printf '* {}\n' >"$BASE_HOME/.config/waybar/style/default.css"
ln -s "$BASE_HOME/.config/waybar/configs/default" "$BASE_HOME/.config/waybar/config"
ln -s "$BASE_HOME/.config/waybar/style/default.css" "$BASE_HOME/.config/waybar/style.css"
printf 'theme\n' >"$BASE_HOME/.themes/NCLS-Black-Waybar/gtk-3.0/gtk.css"
printf 'wallpaper\n' >"$BASE_HOME/pictures/wallpapers/583256.jpg"
ln -s "$BASE_HOME/pictures/wallpapers/583256.jpg" "$BASE_HOME/.config/rofi/.current_wallpaper"
printf '# zsh\n' >"$BASE_HOME/.zshrc"
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
grep -Fqx 'breeze-icons' "$REPO/assets/packages/pacman-explicit.txt"
grep -Fqx 'eza' "$REPO/assets/packages/pacman-explicit.txt"
[[ "$(grep -c 'foreign-dependency' "$REPO/assets/packages/aur-explicit.txt" || true)" -eq 0 ]]
[[ "$(grep -c 'foreign-dependency-debug' "$REPO/assets/packages/aur-explicit.txt" || true)" -eq 0 ]]
grep -qx 'monitor = , preferred, auto, 1' "$REPO/assets/dotfiles/.config/hypr/monitors.conf"
grep -Fqx 'source=$HOME/.config/demo' "$REPO/assets/dotfiles/.config/demo/home-path.conf"
[[ "$(grep -c 'monitor:DP-3' "$REPO/assets/dotfiles/.config/hypr/workspaces.conf" || true)" -eq 0 ]]
grep -Fqx 'workspace = special:special, gapsin:0' "$REPO/assets/dotfiles/.config/hypr/workspaces.conf"
grep -Eq '^[[:space:]]*monitor[[:space:]]*=$' "$REPO/assets/dotfiles/.config/hypr/hyprlock.conf"
grep -Fqx '    unlock_cmd = hyprctl dispatch dpms on' "$REPO/assets/dotfiles/.config/hypr/hypridle.conf"
[[ -L "$REPO/assets/dotfiles/.config/waybar/config" ]]
[[ -L "$REPO/assets/dotfiles/.config/waybar/style.css" ]]
[[ -L "$REPO/assets/dotfiles/.config/rofi/.current_wallpaper" ]]

PATH="$BIN:$PATH" ARCH_HYPRLAND_REPO_ROOT="$REPO" APPLY_HOME="$CLIENT_HOME" XDG_STATE_HOME="$WORK/state" "$REPO/scripts/apply.sh" --yes
[[ -f "$CLIENT_HOME/.config/demo/settings.ini" ]]
[[ -e "$CLIENT_HOME/.config/waybar/config" ]]
[[ -e "$CLIENT_HOME/.config/waybar/style.css" ]]
[[ -e "$CLIENT_HOME/.config/rofi/.current_wallpaper" ]]
[[ ! -e "$CLIENT_HOME/.config/stale" ]]
find "$WORK/state/arch-hyprland/backups" -path '*/.config/stale/settings.ini' -type f -print -quit | grep -q .

# A second application must remain valid and must not duplicate or corrupt
# selectors. This is the non-privileged regression check for repair mode.
PATH="$BIN:$PATH" ARCH_HYPRLAND_REPO_ROOT="$REPO" APPLY_HOME="$CLIENT_HOME" XDG_STATE_HOME="$WORK/state" "$REPO/scripts/apply.sh" --yes
[[ "$(find "$CLIENT_HOME/.config/waybar" -maxdepth 1 -name config -type l | wc -l)" -eq 1 ]]
[[ "$(find "$CLIENT_HOME/.config/waybar" -maxdepth 1 -name style.css -type l | wc -l)" -eq 1 ]]
[[ "$(find "$CLIENT_HOME/.config/rofi" -maxdepth 1 -name .current_wallpaper -type l | wc -l)" -eq 1 ]]
[[ "$(find "$WORK/state/arch-hyprland/backups" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 2 ]]
printf 'snapshot/apply smoke test passed\n'
