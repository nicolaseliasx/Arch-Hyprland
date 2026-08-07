#!/usr/bin/env bash
set -euo pipefail

pidof rofi >/dev/null && pkill rofi
profiles="$HOME/.config/hypr/Monitor_Profiles"
choice=$(find -L "$profiles" -maxdepth 1 -type f -name '*.lua' -printf '%f\n' 2>/dev/null | sed 's/\.lua$//' | sort -V | rofi -i -dmenu -config "$HOME/.config/rofi/config-Monitors.rasi" -mesg 'Escolha o perfil de monitor')
[[ -n "$choice" ]] || exit 0
cp "$profiles/$choice.lua" "$HOME/.config/hypr/monitors.lua"
hyprctl reload
notify-send -u low -i "$HOME/.config/swaync/images/ja.png" "$choice" 'Monitor Profile Loaded'
