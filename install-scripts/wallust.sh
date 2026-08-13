#!/usr/bin/env bash
# Install Wallust without bypassing makepkg integrity checks.  This compatibility
# entry point is used by the legacy component scripts; install.sh uses the same
# retry policy for its theme stage.
set -Eeuo pipefail

log_file="${ARCH_HYPRLAND_LOG_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/arch-hyprland/wallust-install.log}"
cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/yay"
cache_path="$cache_root/wallust"
yay_args=(--needed --noconfirm --answerclean All --answerdiff None --cleanmenu=false --diffmenu=false)

mkdir -p "$(dirname "$log_file")"
log() { printf '[wallust] %s\n' "$*" | tee -a "$log_file"; }

command -v yay >/dev/null 2>&1 || {
  printf 'yay is required to install wallust\n' >&2
  exit 1
}

if pacman -Q wallust >/dev/null 2>&1 && command -v wallust >/dev/null 2>&1; then
  log "Wallust is already installed: $(wallust --version 2>/dev/null || pacman -Q wallust)"
  exit 0
fi

log 'Installing Wallust with normal package integrity verification.'
if yay -S "${yay_args[@]}" wallust >>"$log_file" 2>&1; then
  command -v wallust >/dev/null 2>&1
  exit 0
fi

# A stale Yay clone can retain an obsolete PKGBUILD/source checksum.  Only this
# package cache is removed, then one clean rebuild is tried; checksums remain on.
if [[ -d "$cache_path" && "$cache_path" == "$cache_root/"* ]]; then
  log "Removing failed Wallust build cache: $cache_path"
  rm -rf -- "$cache_path"
fi
log 'Retrying Wallust once after metadata refresh and clean build.'
yay -Syu --noconfirm --answerclean All --answerdiff None --cleanmenu=false --diffmenu=false >>"$log_file" 2>&1 || \
  log 'Metadata refresh failed; attempting the clean build with the currently available metadata.'
yay -S "${yay_args[@]}" --cleanbuild wallust >>"$log_file" 2>&1
command -v wallust >/dev/null 2>&1 || {
  printf 'wallust was not available after the clean-build retry\n' >&2
  exit 1
}
