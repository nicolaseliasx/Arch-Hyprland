#!/usr/bin/env bash
# Start the available wallpaper daemon and apply a deterministic portable
# wallpaper. Safe to run repeatedly during the same session.
set -Eeuo pipefail

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

rofi_wallpaper="$HOME/.config/rofi/.current_wallpaper"
current_wallpaper="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
default_wallpaper="${ARCH_HYPRLAND_WALLPAPER:-$HOME/pictures/wallpapers/583256.jpg}"
log_file="${XDG_CACHE_HOME:-$HOME/.cache}/hypr/wallpaper-daemon.log"
mkdir -p "$(dirname "$log_file")" "$(dirname "$current_wallpaper")" "$(dirname "$rofi_wallpaper")"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" >>"$log_file"
}

wallpaper_bin=""
daemon_bin=""
if command -v awww >/dev/null 2>&1 && command -v awww-daemon >/dev/null 2>&1; then
  wallpaper_bin="awww"
  daemon_bin="awww-daemon"
elif command -v swww >/dev/null 2>&1 && command -v swww-daemon >/dev/null 2>&1; then
  wallpaper_bin="swww"
  daemon_bin="swww-daemon"
fi

if [[ -z "$wallpaper_bin" ]]; then
  log 'missing awww/swww wallpaper daemon'
  exit 1
fi

start_daemon() {
  if [[ "$daemon_bin" == swww-daemon ]]; then
    "$daemon_bin" --format xrgb >/dev/null 2>&1 &
  else
    "$daemon_bin" --quiet >/dev/null 2>&1 &
  fi
}

if ! "$wallpaper_bin" query >/dev/null 2>&1; then
  pgrep -x "$daemon_bin" >/dev/null 2>&1 || start_daemon
  for _ in {1..50}; do
    "$wallpaper_bin" query >/dev/null 2>&1 && break
    sleep 0.1
  done
fi
"$wallpaper_bin" query >/dev/null 2>&1 || { log "$daemon_bin did not become ready"; exit 1; }

wallpaper_path=""
if [[ -e "$rofi_wallpaper" ]]; then
  wallpaper_path="$(readlink -f "$rofi_wallpaper" 2>/dev/null || true)"
fi
[[ -f "$wallpaper_path" ]] || wallpaper_path="$current_wallpaper"
[[ -f "$wallpaper_path" ]] || wallpaper_path="$default_wallpaper"
[[ -f "$wallpaper_path" ]] || { log "wallpaper not found: $default_wallpaper"; exit 1; }

ln -sfn "$wallpaper_path" "$rofi_wallpaper"
cp -f "$wallpaper_path" "$current_wallpaper"
log "applying $wallpaper_path"
"$wallpaper_bin" img --transition-type none "$wallpaper_path" >/dev/null 2>&1 || {
  log 'wallpaper application failed'
  exit 1
}

wallust_script="$HOME/.config/hypr/scripts/WallustSwww.sh"
[[ -x "$wallust_script" ]] && "$wallust_script" "$wallpaper_path" >/dev/null 2>&1 || true
