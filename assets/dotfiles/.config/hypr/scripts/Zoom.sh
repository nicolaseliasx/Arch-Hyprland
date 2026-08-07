#!/usr/bin/env bash
set -euo pipefail

current=$(hyprctl -j getoption cursor.zoom_factor | jq -r '.float // .int')
factor=${2:-1.5}
if [[ "${1:-}" == out ]]; then
  value=$(awk -v current="$current" -v factor="$factor" 'BEGIN { if (current < 1) current = 1; print current / factor }')
else
  value=$(awk -v current="$current" -v factor="$factor" 'BEGIN { if (current < 1) current = 1; print current * factor }')
fi
hyprctl eval "hl.config({ cursor = { zoom_factor = $value } })"
