#!/usr/bin/env bash
set -euo pipefail

layout=$(hyprctl -j getoption general.layout | jq -r '.str')
case "${1:-}" in
  next) [[ "$layout" == master ]] && hyprctl dispatch layoutmsg cyclenext || hyprctl dispatch cyclenext ;;
  prev) [[ "$layout" == master ]] && hyprctl dispatch layoutmsg cycleprev || hyprctl dispatch cyclenext prev ;;
  split) [[ "$layout" == dwindle ]] && hyprctl dispatch layoutmsg togglesplit ;;
  *) exit 2 ;;
esac
