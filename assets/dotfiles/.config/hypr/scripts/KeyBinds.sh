#!/usr/bin/env bash
# Search the bindings that are actually loaded, regardless of config provider.
pkill yad 2>/dev/null || true
pidof rofi >/dev/null && pkill rofi

hyprctl -j binds | jq -r '
  .[] | select(.has_description and (.description | length > 0)) |
  "\(.description)  ·  \(.key)  →  \(.dispatcher) \(.arg)"
' | sort -fu | rofi -dmenu -i -config "$HOME/.config/rofi/config-keybinds.rasi" \
  -mesg '☣️ NOTE ☣️: Clicking with Mouse or Pressing ENTER will have NO function'
