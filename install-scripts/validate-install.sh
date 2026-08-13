#!/usr/bin/env bash
set -Eeuo pipefail

export PATH="$HOME/.local/bin:$HOME/.codex/bin:$PATH"
failures=()

require_command() {
  command -v "$1" >/dev/null 2>&1 || failures+=("command:$1")
}
require_file() {
  [[ -f "$1" ]] || failures+=("file:$1")
}
require_path() {
  [[ -e "$1" ]] || failures+=("path:$1")
}

for command_name in Hyprland uwsm waybar zsh eza zoxide code codex codex-flow; do
  require_command "$command_name"
done
if ! command -v awww >/dev/null 2>&1 && ! command -v swww >/dev/null 2>&1; then
  failures+=("command:awww-or-swww")
fi

require_file "$HOME/.config/hypr/shaders/digital-vibrance-90.frag"
require_file "$HOME/pictures/wallpapers/583256.jpg"
require_file "$HOME/.themes/NCLS-Black-Waybar/gtk-3.0/gtk.css"
require_path "$HOME/.config/waybar/config"
require_path "$HOME/.config/waybar/style.css"
require_path "$HOME/.config/rofi/.current_wallpaper"
require_file "$HOME/.oh-my-zsh/oh-my-zsh.sh"
require_file "$HOME/.oh-my-zsh/custom/themes/powerlevel10k/powerlevel10k.zsh-theme"
require_file "$HOME/.local/share/codex-flow/shell/init.zsh"
require_file "/usr/share/wayland-sessions/hyprland.desktop"

zsh -n "$HOME/.zshrc" >/dev/null 2>&1 || failures+=("config:zsh")
Hyprland --verify-config -c "$HOME/.config/hypr/hyprland.lua" >/dev/null 2>&1 || failures+=("config:hyprland")
grep -Fq 'output = "", mode = "preferred", position = "auto", scale = 1' "$HOME/.config/hypr/monitors.lua" || failures+=("config:monitor-scale")
[[ "$(getent passwd "$USER" | cut -d: -f7)" == "$(command -v zsh)" ]] || failures+=("shell:zsh")
systemctl is-enabled greetd >/dev/null 2>&1 || failures+=("service:greetd")
grep -Fq "uwsm start hyprland.desktop" /etc/greetd/config.toml 2>/dev/null || failures+=("config:greetd-uwsm")

if ((${#failures[@]})); then
  printf 'Installation validation failed:\n' >&2
  printf '  - %s\n' "${failures[@]}" >&2
  exit 1
fi

printf 'All installation checks passed.\n'
