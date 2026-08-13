#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Script for Random Wallpaper ( CTRL ALT W)

wallDIR="$HOME/pictures/wallpapers"
SCRIPTSDIR="$HOME/.config/hypr/scripts"

focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')

# Resolve wallpaper commands after package rename (swww -> awww on some distros)
WALLPAPER_BIN=""
WALLPAPER_DAEMON_BIN=""
if command -v swww >/dev/null 2>&1; then
  WALLPAPER_BIN="swww"
elif command -v awww >/dev/null 2>&1; then
  WALLPAPER_BIN="awww"
fi

if command -v swww-daemon >/dev/null 2>&1; then
  WALLPAPER_DAEMON_BIN="swww-daemon"
elif command -v awww-daemon >/dev/null 2>&1; then
  WALLPAPER_DAEMON_BIN="awww-daemon"
fi

if [[ -z "$WALLPAPER_BIN" || -z "$WALLPAPER_DAEMON_BIN" ]]; then
  notify-send "Wallpaper daemon missing" "Install swww or awww"
  exit 1
fi

start_wallpaper_daemon() {
  if [[ "$WALLPAPER_DAEMON_BIN" == "swww-daemon" ]]; then
    "$WALLPAPER_DAEMON_BIN" --format xrgb &
  else
    "$WALLPAPER_DAEMON_BIN" --quiet &
  fi
}

ensure_wallpaper_daemon() {
  "$WALLPAPER_BIN" query >/dev/null 2>&1 && return 0
  start_wallpaper_daemon
  for _ in {1..50}; do
    "$WALLPAPER_BIN" query >/dev/null 2>&1 && return 0
    sleep 0.1
  done
  return 1
}

mapfile -d '' -t PICS < <(find -L "$wallDIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.pnm" -o -iname "*.tga" -o -iname "*.tiff" -o -iname "*.webp" -o -iname "*.bmp" -o -iname "*.farbfeld" -o -iname "*.gif" \) -print0)
if ((${#PICS[@]} == 0)); then
  notify-send "Wallpaper directory is empty" "$wallDIR"
  exit 1
fi
RANDOMPICS="${PICS[RANDOM % ${#PICS[@]}]}"


# Transition config
FPS=30
TYPE="random"
DURATION=1
BEZIER=".43,1.19,1,.4"
SWWW_PARAMS="--transition-fps $FPS --transition-type $TYPE --transition-duration $DURATION --transition-bezier $BEZIER"


ensure_wallpaper_daemon || exit 1
"$WALLPAPER_BIN" img -o "$focused_monitor" "${RANDOMPICS}" $SWWW_PARAMS
"$SCRIPTSDIR/WallustSwww.sh" "$RANDOMPICS"
sleep 2
"$SCRIPTSDIR/Refresh.sh"
