#!/bin/bash
# ==============================================================================
#  Configures monitor profile (Desktop Dual-Monitor vs Laptop Single Monitor)
# ==============================================================================
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$SCRIPT_DIR/.."

if ! source "$SCRIPT_DIR/Global_functions.sh"; then
  echo "Failed to source Global_functions.sh"
  exit 1
fi

LOG="Install-Logs/install-$(date +%d-%H%M%S)_monitors.log"
MONITORS_CONF="$HOME/.config/hypr/monitors.conf"

echo -e "\n${NOTE} Setting up Monitor Profile..." | tee -a "$LOG"

if command -v whiptail &>/dev/null; then
  choice=$(whiptail --title "Monitor Profile Configuration" \
    --radiolist "Select display profile for this system:\n\nNOTE: You can easily switch profiles later in ~/.config/hypr/monitors.conf" 14 75 2 \
    "1" "Laptop / Single Monitor (Auto-detect: monitor=,preferred,auto,1)" "ON" \
    "2" "Desktop Dual-Monitor (DP-3 1440p@240Hz + DP-2 1440p@75Hz vertical)" "OFF" \
    3>&1 1>&2 2>&3)
else
  choice="1"
fi

mkdir -p "$HOME/.config/hypr"

if [ "$choice" == "2" ]; then
  echo "${INFO} Applying Desktop Dual-Monitor Profile..." | tee -a "$LOG"
  cat << 'EOF' > "$MONITORS_CONF"
# Desktop Dual-Monitor Configuration
monitor = DP-3, 2560x1440@239.97, 0x0, 1
monitor = DP-2, 2560x1440@75.00Hz, 2560x0, 1, transform, 3
EOF
else
  echo "${INFO} Applying Laptop / Single Monitor Auto Profile..." | tee -a "$LOG"
  cat << 'EOF' > "$MONITORS_CONF"
# Laptop / Single Monitor Auto Configuration
monitor = , preferred, auto, 1
EOF
fi

echo -e "👌 ${OK} Monitor profile written to ${SKY_BLUE}$MONITORS_CONF${RESET}" | tee -a "$LOG"
