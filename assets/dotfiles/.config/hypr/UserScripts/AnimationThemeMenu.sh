#!/usr/bin/env bash

theme_dir="$HOME/.config/hypr/animation_profiles"
target="$HOME/.config/hypr/config/animations.lua"

choice=$(printf '%s\n' \
  'Suave — pop discreto e transição fluida' \
  'Cinemático — janelas deslizam, workspaces ganham presença' \
  'Rápido — mínimo atraso e movimento curto' \
  | rofi -dmenu -i -config "$HOME/.config/rofi/config-Animations.rasi" -p 'Animações') || exit 0

case "$choice" in
  Suave*) theme=ncls-smooth.lua ;;
  Cinemático*) theme=ncls-cinematic.lua ;;
  Rápido*) theme=ncls-fast.lua ;;
  *) exit 0 ;;
esac

cp "$theme_dir/$theme" "$target"
hyprctl reload
notify-send -u low 'Animações' "Perfil ${choice%% —*} aplicado"
