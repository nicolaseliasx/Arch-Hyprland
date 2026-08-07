#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##

pidof hyprlock >/dev/null && exit 0

if command -v openrgb >/dev/null; then
    openrgb --noautoconnect --device 0 --mode off >/dev/null 2>&1
    openrgb --noautoconnect --device 1 --mode static --color 000000 >/dev/null 2>&1
    openrgb --noautoconnect --device 2 --mode off >/dev/null 2>&1
fi
hyprlock &
lock_pid=$!
kill -0 "$lock_pid" 2>/dev/null || exit 1
hyprctl dispatch dpms off DP-2
wait "$lock_pid"
