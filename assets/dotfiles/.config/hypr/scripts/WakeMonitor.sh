#!/usr/bin/env bash

echo "[+] Forçando re-detecção da porta DP-2 pelo kernel DRM..."
sudo sh -c 'echo detect > /sys/class/drm/card1-DP-2/status' 2>/dev/null || true
sudo sh -c 'echo on > /sys/class/drm/card1-DP-2/status' 2>/dev/null || true

echo "[+] Re-aplicando configuração do monitor DP-2 no Hyprland..."
hyprctl eval 'hl.monitor({ output = "DP-2", mode = "2560x1440@75.00Hz", position = "2560x0", scale = 1, transform = 3, disabled = false })'

echo "[+] Verificando status dos monitores:"
hyprctl monitors all
