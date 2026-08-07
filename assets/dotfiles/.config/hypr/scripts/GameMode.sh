#!/usr/bin/env bash
set -euo pipefail

if [[ "$(hyprctl -j getoption animations.enabled | jq -r '.int')" == 1 ]]; then
  hyprctl eval 'hl.config({ animations = { enabled = false }, decoration = { shadow = { enabled = false }, blur = { enabled = false }, rounding = 0 }, general = { gaps_in = 0, gaps_out = 0, border_size = 1 } })'
  hyprctl eval 'hl.window_rule({ name = "gamemode-opaque", match = { class = ".*" }, opacity = "1 override 1 override 1 override" })'
  swww kill
  notify-send -e -u low -i "$HOME/.config/swaync/images/ja.png" 'Gamemode:' enabled
else
  swww-daemon --format xrgb && swww img "$HOME/.config/rofi/.current_wallpaper" &
  "$HOME/.config/hypr/scripts/WallustSwww.sh"
  hyprctl reload
  "$HOME/.config/hypr/scripts/Refresh.sh"
  notify-send -e -u normal -i "$HOME/.config/swaync/images/ja.png" 'Gamemode:' disabled
fi
