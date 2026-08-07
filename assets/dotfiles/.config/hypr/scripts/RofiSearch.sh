#!/usr/bin/env bash
set -euo pipefail

command -v jq >/dev/null || { notify-send -u low 'Rofi Search' 'jq is required for URL encoding.'; exit 1; }
search_engine="${HYPR_SEARCH_ENGINE:-https://www.google.com/search?q={}}"
pidof rofi >/dev/null && pkill rofi
query=$(printf '' | rofi -dmenu -config "$HOME/.config/rofi/config-search.rasi" -mesg '‼️ **note** ‼️ search via default web browser')
[[ -n "$query" ]] || exit 0
xdg-open "${search_engine}$(printf '%s' "$query" | jq -sRr @uri)" >/dev/null 2>&1 &
