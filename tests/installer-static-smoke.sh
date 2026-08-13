#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

bash -n install.sh scripts/*.sh install-scripts/*.sh tests/*.sh
zsh -n assets/dotfiles/.zshrc
grep -Fqx eza assets/packages/pacman-explicit.txt
grep -Fqx breeze-icons assets/packages/pacman-explicit.txt
grep -Fqx wallust assets/packages/aur-required.txt
grep -Fqx stremio assets/packages/aur-optional.txt
grep -Fqx firefox assets/packages/pacman-optional.txt
! grep -Eq '^(nvidia|nvidia-open|nvidia-open-dkms|nvidia-settings|libva-nvidia-driver)$' assets/packages/pacman-explicit.txt
! grep -Fq -- '--skipchecksums' install.sh install-scripts/wallust.sh
grep -Fq -- '--cleanbuild' install.sh install-scripts/wallust.sh
grep -Fq -- '--answerclean All' install.sh install-scripts/wallust.sh
grep -Fq 'whiptail --title' install.sh
grep -Fq 'output = "", mode = "preferred", position = "auto", scale = 1' assets/dotfiles/.config/hypr/monitors.lua
grep -Fq 'screen_shader = home .. "/.config/hypr/shaders/digital-vibrance-90.frag"' assets/dotfiles/.config/hypr/config/settings.lua
grep -Fq 'wallDIR="$HOME/pictures/wallpapers"' assets/dotfiles/.config/hypr/UserScripts/WallpaperRandom.sh
grep -Fq 'WallustSwww.sh" "$image_path"' assets/dotfiles/.config/hypr/UserScripts/WallpaperSelect.sh
[[ -e assets/dotfiles/.config/waybar/config ]]
[[ -e assets/dotfiles/.config/waybar/style.css ]]
[[ -e assets/dotfiles/.config/rofi/.current_wallpaper ]]
[[ -x assets/code-flow/bin/codex-flow ]]
./install.sh --help >/dev/null

printf 'installer static smoke test passed\n'
