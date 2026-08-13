#!/usr/bin/env bash
set -Eeuo pipefail

choice="${1:-open}"
log_file="${ARCH_HYPRLAND_LOG_FILE:-/dev/null}"

case "$choice" in
  open)
    packages=(nvidia-open-dkms nvidia-utils nvidia-settings libva-nvidia-driver)
    while IFS= read -r pkgbase; do
      [[ -n "$pkgbase" ]] && packages+=("${pkgbase}-headers")
    done < <(find /usr/lib/modules -mindepth 2 -maxdepth 2 -name pkgbase -exec cat {} \; 2>/dev/null | sort -u)
    sudo pacman -S --needed --noconfirm "${packages[@]}" >>"$log_file" 2>&1
    sudo install -d -m 0755 /etc/modprobe.d
    printf '%s\n' 'options nvidia_drm modeset=1 fbdev=1' | sudo tee /etc/modprobe.d/nvidia.conf >/dev/null
    sudo mkinitcpio -P >>"$log_file" 2>&1
    pacman -Q nvidia-open-dkms nvidia-utils >/dev/null
    ;;
  nouveau)
    mapfile -t installed_modules < <(pacman -Qq | grep -xE 'nvidia(-open)?(-dkms)?' || true)
    if ((${#installed_modules[@]})); then
      sudo pacman -Rns --noconfirm "${installed_modules[@]}" >>"$log_file" 2>&1
    fi
    sudo pacman -S --needed --noconfirm mesa vulkan-nouveau >>"$log_file" 2>&1
    sudo rm -f /etc/modprobe.d/nvidia.conf
    if [[ -f /etc/modprobe.d/nouveau.conf ]]; then
      sudo sed -i '/^[[:space:]]*blacklist[[:space:]]\+nouveau[[:space:]]*$/d' /etc/modprobe.d/nouveau.conf
    fi
    if [[ -f /etc/modprobe.d/blacklist.conf ]]; then
      sudo sed -i '\|^[[:space:]]*install[[:space:]]\+nouveau[[:space:]]\+/bin/true[[:space:]]*$|d' /etc/modprobe.d/blacklist.conf
    fi
    sudo mkinitcpio -P >>"$log_file" 2>&1
    ;;
  skip) ;;
  *) printf 'unknown NVIDIA choice: %s\n' "$choice" >&2; exit 1 ;;
esac
