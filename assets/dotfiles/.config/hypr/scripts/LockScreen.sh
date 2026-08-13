#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##

pidof hyprlock >/dev/null && exit 0

# Launch hyprlock immediately for instant response
hyprlock &
lock_pid=$!

# Disable DP-2 secondary monitor output via Hyprland native API (Keeps HPD alive)
hyprctl dispatch dpms off

# OpenRGB commands in background subshell so they don't delay locking
if command -v openrgb >/dev/null 2>&1; then
    (
        openrgb --noautoconnect --device 0 --mode off >/dev/null 2>&1
        openrgb --noautoconnect --device 1 --mode static --color 000000 >/dev/null 2>&1
        openrgb --noautoconnect --device 2 --mode off >/dev/null 2>&1
    ) &
fi

# Wait for hyprlock to exit (unlocked)
wait "$lock_pid"

# Re-enable DP-2 secondary monitor output via Hyprland native API
hyprctl dispatch dpms on
