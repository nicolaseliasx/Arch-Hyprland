#!/usr/bin/env bash
set -euo pipefail

passes=$(hyprctl -j getoption decoration.blur.passes | jq -r '.int')
if [[ "$passes" == 2 ]]; then
  hyprctl eval 'hl.config({ decoration = { blur = { size = 2, passes = 1 } } })'
  notify-send -e -u low -i "$HOME/.config/swaync/images/note.png" 'Less Blur'
else
  hyprctl eval 'hl.config({ decoration = { blur = { size = 5, passes = 2 } } })'
  notify-send -e -u low -i "$HOME/.config/swaync/images/ja.png" 'Normal Blur'
fi
