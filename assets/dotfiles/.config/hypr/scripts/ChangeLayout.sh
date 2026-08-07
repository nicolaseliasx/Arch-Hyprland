#!/usr/bin/env bash
set -euo pipefail

[[ "${1:-}" == init ]] && exit 0
layout=$(hyprctl -j getoption general.layout | jq -r '.str')
if [[ "$layout" == master ]]; then
  hyprctl eval 'hl.config({ general = { layout = "dwindle" } })'
  notify-send -e -u low -i "$HOME/.config/swaync/images/ja.png" 'Dwindle Layout'
else
  hyprctl eval 'hl.config({ general = { layout = "master" } })'
  notify-send -e -u low -i "$HOME/.config/swaync/images/ja.png" 'Master Layout'
fi
