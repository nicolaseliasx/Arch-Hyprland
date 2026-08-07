#!/usr/bin/env bash
set -euo pipefail

pidof rofi >/dev/null && pkill rofi
profiles="$HOME/.config/hypr/animation_profiles"
target="$HOME/.config/hypr/config/animations.lua"
choice=$(find -L "$profiles" -maxdepth 1 -type f -name '*.lua' -printf '%f\n' 2>/dev/null | sed 's/\.lua$//' | sort -V | rofi -i -dmenu -config "$HOME/.config/rofi/config-Animations.rasi" -mesg 'Escolha a animação do Hyprland')
[[ -n "$choice" ]] || exit 0
cp "$profiles/$choice.lua" "$target"
hyprctl reload
notify-send -u low -i "$HOME/.config/swaync/images/ja.png" "$choice" 'Hyprland Animation Loaded'
