#!/usr/bin/env bash
set -euo pipefail

state="$HOME/.config/hypr/wallpaper_effects/live_wallpaper"
if [[ -s "$state" && -x "$(command -v mpvpaper || true)" ]]; then
  mpvpaper '*' -o 'load-scripts=no no-audio --loop' "$(<"$state")" &
else
  exec "$HOME/.config/hypr/scripts/WallpaperDaemon.sh"
fi
