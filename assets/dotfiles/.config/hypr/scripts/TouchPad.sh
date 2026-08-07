#!/usr/bin/env bash
set -euo pipefail

device="${HYPR_TOUCHPAD_DEVICE:-asue1209:00-04f3:319f-touchpad}"
state_file="${XDG_RUNTIME_DIR:-/tmp}/touchpad.status"
enabled=false
[[ -f "$state_file" && "$(<"$state_file")" == true ]] || enabled=true
printf '%s' "$enabled" > "$state_file"
device_lua=$(printf '%s' "$device" | jq -Rs .)
hyprctl eval "hl.device({ name = $device_lua, enabled = $enabled })"
notify-send -u low -i "$HOME/.config/swaync/images/ja.png" "Touchpad" "$([[ "$enabled" == true ]] && echo Enabling || echo Disabling)"
