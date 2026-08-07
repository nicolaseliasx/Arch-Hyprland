#!/usr/bin/env bash

# Check if rofi is already running
if pidof rofi > /dev/null; then
    pkill rofi
    exit 0
fi

# Define the options in lowercase
options="lock\nreboot\nshutdown"

# Call rofi with theme overrides to make it very small (just the list)
chosen=$(echo -e "$options" | rofi -dmenu -i -theme-str 'window {width: 9em;} mainbox {children: [listview];} listview {lines: 3;}')

# Execute the corresponding action
case $chosen in
    lock)
        $HOME/.config/hypr/scripts/LockScreen.sh
        ;;
    reboot)
        systemctl reboot
        ;;
    shutdown)
        systemctl poweroff
        ;;
esac
