#!/usr/bin/env bash
set -Eeuo pipefail

log_file="${ARCH_HYPRLAND_LOG_FILE:-/dev/null}"
zsh_bin="$(command -v zsh)"
[[ -n "$zsh_bin" ]] || { printf 'zsh executable not found\n' >&2; exit 1; }
backup_root="${XDG_STATE_HOME:-$HOME/.local/state}/arch-hyprland/component-backups/configure-zsh-$(date +%Y%m%d_%H%M%S)-$$"

clone_once() {
  local repository="$1" destination="$2" expected_file="$3"
  if [[ -d "$destination/.git" && -f "$destination/$expected_file" ]]; then
    return 0
  fi
  if [[ -e "$destination" || -L "$destination" ]]; then
    mkdir -p "$backup_root"
    mv -- "$destination" "$backup_root/$(basename "$destination")"
  fi
  git clone --depth=1 "$repository" "$destination" >>"$log_file" 2>&1
}

clone_once https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" oh-my-zsh.sh
mkdir -p "$HOME/.oh-my-zsh/custom/themes" "$HOME/.oh-my-zsh/custom/plugins"
clone_once https://github.com/romkatv/powerlevel10k.git "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" powerlevel10k.zsh-theme

for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
  source_dir="/usr/share/zsh/plugins/$plugin"
  target_dir="$HOME/.oh-my-zsh/custom/plugins/$plugin"
  [[ -d "$source_dir" ]] || { printf 'zsh plugin files not found: %s\n' "$source_dir" >&2; exit 1; }
  if [[ -e "$target_dir" || -L "$target_dir" ]]; then
    if [[ -L "$target_dir" && "$(readlink -f "$target_dir")" == "$source_dir" ]]; then
      continue
    fi
    mkdir -p "$backup_root/plugins"
    mv -- "$target_dir" "$backup_root/plugins/$plugin"
  fi
  ln -sfnT "$source_dir" "$target_dir"
done

zsh -n "$HOME/.zshrc"
sudo usermod --shell "$zsh_bin" "$USER"
[[ "$(getent passwd "$USER" | cut -d: -f7)" == "$zsh_bin" ]] || {
  printf 'could not set zsh as the default shell\n' >&2
  exit 1
}
