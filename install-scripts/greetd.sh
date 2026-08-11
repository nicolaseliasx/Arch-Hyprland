#!/bin/bash
# ==================================================
#  nclsDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# greetd Log-in Manager with tuigreet #

greetd_pkgs=(
  greetd
  greetd-tuigreet
)

# login managers to attempt to disable
login=(
  lightdm
  gdm3
  gdm
  lxdm
  lxdm-gtk3
  sddm
)

## WARNING: DO NOT EDIT BEYOND THIS LINE IF YOU DON'T KNOW WHAT YOU ARE DOING! ##
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change the working directory to the parent directory of the script
PARENT_DIR="$SCRIPT_DIR/.."
cd "$PARENT_DIR" || {
  echo "${ERROR} Failed to change directory to $PARENT_DIR"
  exit 1
}

# Source the global functions script
if ! source "$(dirname "$(readlink -f "$0")")/Global_functions.sh"; then
  echo "Failed to source Global_functions.sh"
  exit 1
fi

# Set the name of the log file to include the current date and time
LOG="Install-Logs/install-$(date +%d-%H%M%S)_greetd.log"

printf "${NOTE} Installing greetd and dependencies........\n" | tee -a "$LOG"
for package in "${greetd_pkgs[@]}"; do
  install_package "$package" "$LOG" || install_package "tuigreet" "$LOG"
done

printf "\n%.0s" {1..1}

# Check if other login managers installed and disable their services
for login_manager in "${login[@]}"; do
  if pacman -Qs "$login_manager" >/dev/null 2>&1; then
    sudo systemctl disable "$login_manager.service" >>"$LOG" 2>&1 || true
    echo "$login_manager disabled." >>"$LOG" 2>&1
  fi
done

# Double check with systemctl
for manager in "${login[@]}"; do
  if systemctl is-active --quiet "$manager" >/dev/null 2>&1; then
    echo "$manager is active, disabling it..." >>"$LOG" 2>&1
    sudo systemctl disable "$manager" --now >>"$LOG" 2>&1 || true
  fi
done

printf "\n%.0s" {1..1}

# Ensure /etc/greetd directory exists
if [ ! -d "/etc/greetd" ]; then
  sudo mkdir -p /etc/greetd 2>&1 | tee -a "$LOG"
fi

# Backup existing config if present
if [ -f "/etc/greetd/config.toml" ]; then
  sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.bak 2>&1 | tee -a "$LOG"
fi

# Write greetd configuration with tuigreet
printf "${INFO} Configuring greetd with tuigreet greeter...\n" | tee -a "$LOG"
cat <<'EOF' | sudo tee /etc/greetd/config.toml >/dev/null
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --cmd Hyprland"
user = "greeter"
EOF

# Ensure greeter user exists
if ! id "greeter" &>/dev/null; then
  echo "${INFO} Creating greeter user..." | tee -a "$LOG"
  sudo useradd -M -G video greeter 2>&1 | tee -a "$LOG" || true
fi

# Ensure correct permissions on /etc/greetd
sudo chmod 644 /etc/greetd/config.toml 2>&1 | tee -a "$LOG"

printf "${INFO} Activating greetd service........\n" | tee -a "$LOG"
sudo systemctl enable greetd 2>&1 | tee -a "$LOG"

echo "${OK} greetd with tuigreet successfully installed and configured!" | tee -a "$LOG"
