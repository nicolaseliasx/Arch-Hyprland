#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# source https://wiki.archlinux.org/title/Hyprland#Using_a_script_to_change_wallpaper_every_X_minutes

# This script will randomly go through the files of a directory, setting it
# up as the wallpaper at regular intervals
#
# NOTE: this script uses bash (not POSIX shell) for the RANDOM variable

wallust_refresh=$HOME/.config/hypr/scripts/RefreshNoWaybar.sh

focused_monitor=$(hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}')

# Resolve wallpaper commands after package rename (swww -> awww on some distros)
WALLPAPER_BIN=""
WALLPAPER_DAEMON_BIN=""
if command -v swww >/dev/null 2>&1; then
	WALLPAPER_BIN="swww"
elif command -v awww >/dev/null 2>&1; then
	WALLPAPER_BIN="awww"
fi

if command -v swww-daemon >/dev/null 2>&1; then
	WALLPAPER_DAEMON_BIN="swww-daemon"
elif command -v awww-daemon >/dev/null 2>&1; then
	WALLPAPER_DAEMON_BIN="awww-daemon"
fi

if [[ -z "$WALLPAPER_BIN" || -z "$WALLPAPER_DAEMON_BIN" ]]; then
	echo "Wallpaper daemon missing. Install swww or awww."
	exit 1
fi

start_wallpaper_daemon() {
	if [[ "$WALLPAPER_DAEMON_BIN" == "swww-daemon" ]]; then
		"$WALLPAPER_DAEMON_BIN" --format xrgb &
	else
		"$WALLPAPER_DAEMON_BIN" --quiet &
	fi
}

ensure_wallpaper_daemon() {
	"$WALLPAPER_BIN" query >/dev/null 2>&1 && return 0
	start_wallpaper_daemon
	for _ in {1..50}; do
		"$WALLPAPER_BIN" query >/dev/null 2>&1 && return 0
		sleep 0.1
	done
	return 1
}

if [[ $# -lt 1 ]] || [[ ! -d $1   ]]; then
	echo "Usage:
	$0 <dir containing images>"
	exit 1
fi

# Edit below to control the images transition
export SWWW_TRANSITION_FPS=60
export SWWW_TRANSITION_TYPE=simple

# This controls (in seconds) when to switch to the next image
INTERVAL=1800

ensure_wallpaper_daemon || exit 1

while true; do
	find "$1" \
		| while read -r img; do
			echo "$((RANDOM % 1000)):$img"
		done \
		| sort -n | cut -d':' -f2- \
		| while read -r img; do
			"$WALLPAPER_BIN" img -o "$focused_monitor" "$img"
			# Regenerate colors from the exact image path to avoid cache races
			$HOME/.config/hypr/scripts/WallustSwww.sh "$img"
			# Refresh UI components that depend on wallust output
			$wallust_refresh
			sleep $INTERVAL
			
		done
done
