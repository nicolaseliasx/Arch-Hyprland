#!/usr/bin/env bash
# Validate the installed profile, not merely the exit status of installer steps.
set -Eeuo pipefail

export PATH="$HOME/.local/bin:$HOME/.codex/bin:$PATH"
critical_failures=()
warnings=()

ok() { printf 'OK\t%s\n' "$1"; }
fail() { printf 'FAIL\t%s\t%s\n' "$1" "$2" >&2; critical_failures+=("$1: $2"); }
warn() { printf 'WARN\t%s\t%s\n' "$1" "$2" >&2; warnings+=("$1: $2"); }

require_command() {
  local label="$1" command_name="$2" severity="${3:-critical}"
  if command -v "$command_name" >/dev/null 2>&1; then
    ok "$label"
  elif [[ "$severity" == warning ]]; then
    warn "$label" "command not found: $command_name"
  else
    fail "$label" "command not found: $command_name"
  fi
}

require_file() {
  local label="$1" path="$2" severity="${3:-critical}"
  if [[ -f "$path" ]]; then
    ok "$label"
  elif [[ "$severity" == warning ]]; then
    warn "$label" "file missing: $path"
  else
    fail "$label" "file missing: $path"
  fi
}

require_link_target() {
  local label="$1" path="$2"
  if [[ -e "$path" ]]; then
    ok "$label"
  else
    fail "$label" "missing or dangling selector: $path"
  fi
}

require_command 'Hyprland' Hyprland
require_command 'UWSM' uwsm
require_command 'Waybar' waybar
require_command 'Zsh' zsh
require_command 'Eza' eza
if ! command -v awww >/dev/null 2>&1 && ! command -v swww >/dev/null 2>&1; then
  fail 'Wallpaper backend' 'neither awww nor swww is installed'
else
  ok 'Wallpaper backend'
fi
require_command 'Wallust' wallust warning
require_command 'Code Flow' codex-flow
require_command 'Codex CLI' codex

require_file 'Screen shader' "$HOME/.config/hypr/shaders/digital-vibrance-90.frag"
require_file 'Default wallpaper' "$HOME/pictures/wallpapers/583256.jpg"
require_file 'GTK theme' "$HOME/.themes/NCLS-Black-Waybar/gtk-3.0/gtk.css"
require_file 'Wallust Hyprland palette' "$HOME/.config/hypr/wallust/wallust-hyprland.conf" warning
require_file 'Wallust Waybar palette' "$HOME/.config/waybar/wallust/colors-waybar.css" warning
require_file 'Wallpaper daemon script' "$HOME/.config/hypr/scripts/WallpaperDaemon.sh"
require_link_target 'Waybar config selector' "$HOME/.config/waybar/config"
require_link_target 'Waybar style selector' "$HOME/.config/waybar/style.css"
require_link_target 'Wallpaper selector' "$HOME/.config/rofi/.current_wallpaper"
require_file 'Oh My Zsh' "$HOME/.oh-my-zsh/oh-my-zsh.sh"
require_file 'Powerlevel10k' "$HOME/.oh-my-zsh/custom/themes/powerlevel10k/powerlevel10k.zsh-theme"
require_file 'Code Flow shell integration' "$HOME/.local/share/codex-flow/shell/init.zsh"
require_file 'Hyprland session entry' '/usr/share/wayland-sessions/hyprland.desktop'

if command -v zsh >/dev/null 2>&1; then
  if zsh -n "$HOME/.zshrc"; then ok 'Zsh configuration'; else fail 'Zsh configuration' 'syntax check failed'; fi
fi
if command -v Hyprland >/dev/null 2>&1; then
  if Hyprland --verify-config -c "$HOME/.config/hypr/hyprland.lua"; then ok 'Hyprland Lua configuration'; else fail 'Hyprland Lua configuration' 'verification failed'; fi
  if Hyprland --verify-config -c "$HOME/.config/hypr/hyprland.conf"; then ok 'Hyprland fallback configuration'; else fail 'Hyprland fallback configuration' 'verification failed'; fi
fi
if grep -Fqx 'monitor = , preferred, auto, 1' "$HOME/.config/hypr/monitors.conf" && \
   grep -Fq 'output = "", mode = "preferred", position = "auto", scale = 1' "$HOME/.config/hypr/monitors.lua"; then
  ok 'Portable monitor scale'
else
  fail 'Portable monitor scale' 'a scale-1 fallback is missing'
fi
if command -v zsh >/dev/null 2>&1 && [[ "$(getent passwd "$USER" | cut -d: -f7)" == "$(command -v zsh)" ]]; then
  ok 'Default shell'
else
  fail 'Default shell' 'the target user is not configured to use zsh'
fi
if systemctl is-enabled greetd >/dev/null 2>&1; then ok 'greetd service'; else fail 'greetd service' 'not enabled'; fi
if grep -Fq 'uwsm start hyprland.desktop' /etc/greetd/config.toml; then ok 'greetd UWSM session'; else fail 'greetd UWSM session' 'expected command is missing'; fi

if ((${#warnings[@]})); then
  printf 'Validation completed with %d warning(s).\n' "${#warnings[@]}" >&2
fi
if ((${#critical_failures[@]})); then
  printf 'Installation validation failed with %d critical issue(s).\n' "${#critical_failures[@]}" >&2
  exit 1
fi
printf 'All critical installation checks passed.\n'
