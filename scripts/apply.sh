#!/usr/bin/env bash
# Apply the versioned profile exactly. Only paths declared in
# assets/snapshot-paths.txt are ever deleted or overwritten.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${ARCH_HYPRLAND_REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
TARGET_HOME="${APPLY_HOME:-$HOME}"
DOTFILES_DIR="$REPO_ROOT/assets/dotfiles"
PATHS_FILE="$REPO_ROOT/assets/snapshot-paths.txt"
BACKUP_ROOT="${XDG_STATE_HOME:-$TARGET_HOME/.local/state}/arch-hyprland/backups"
ASSUME_YES=false

log() { printf '[apply] %s\n' "$*"; }
die() { printf '[apply] error: %s\n' "$*" >&2; exit 1; }
valid_relative_path() { [[ "$1" != /* && "$1" != *".."* && "$1" != "." && -n "$1" ]]; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) ASSUME_YES=true ;;
    -h|--help)
      printf 'Usage: %s [--yes]\n' "$0"
      exit 0
      ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

[[ -d "$DOTFILES_DIR" ]] || die "snapshot directory does not exist: $DOTFILES_DIR"
[[ -f "$PATHS_FILE" ]] || die "path manifest does not exist: $PATHS_FILE"

for required_path in \
  .config/hypr/hyprland.lua \
  .config/hypr/shaders/digital-vibrance-90.frag \
  .config/waybar/config \
  .config/waybar/style.css \
  .config/rofi/.current_wallpaper \
  .themes/NCLS-Black-Waybar/gtk-3.0/gtk.css \
  pictures/wallpapers/583256.jpg \
  .zshrc; do
  [[ -e "$DOTFILES_DIR/$required_path" ]] || die "required profile artifact is missing: $required_path"
done

if ! "$ASSUME_YES"; then
  cat <<EOF
This will overwrite every path in $PATHS_FILE under $TARGET_HOME.
It does not roll back automatically. A manual backup will be created first.
Type OVERWRITE to continue:
EOF
  read -r confirmation
  [[ "$confirmation" == 'OVERWRITE' ]] || die 'cancelled'
fi

mkdir -p "$BACKUP_ROOT"
backup_dir="$(mktemp -d "$BACKUP_ROOT/backup-$(date +%Y%m%d_%H%M%S).XXXXXX")"
printf 'source=%s\ncreated_at=%s\n' "$REPO_ROOT" "$(date --iso-8601=seconds)" >"$backup_dir/manifest.env"

while IFS= read -r relative_path || [[ -n "$relative_path" ]]; do
  [[ -z "$relative_path" || "$relative_path" == \#* ]] && continue
  valid_relative_path "$relative_path" || die "unsafe path in manifest: $relative_path"
  source_path="$DOTFILES_DIR/$relative_path"
  target_path="$TARGET_HOME/$relative_path"
  backup_path="$backup_dir/$relative_path"

  [[ "$target_path" != "$TARGET_HOME" ]] || die 'refusing to replace the home directory'
  if [[ -e "$target_path" || -L "$target_path" ]]; then
    log "backing up $relative_path"
    mkdir -p "$(dirname "$backup_path")"
    cp -a -- "$target_path" "$backup_path"
  fi

  log "mirroring $relative_path"
  rm -rf -- "$target_path"
  if [[ -d "$source_path" ]]; then
    mkdir -p "$target_path"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --safe-links --delete "$source_path/" "$target_path/"
    else
      cp -a -- "$source_path/." "$target_path/"
    fi
  elif [[ -e "$source_path" ]]; then
    mkdir -p "$(dirname "$target_path")"
    cp -a -- "$source_path" "$target_path"
  else
    log "base profile does not contain $relative_path; target removed"
  fi
done <"$PATHS_FILE"

# Links that intentionally cross from ~/.config to another managed profile
# path are rejected by rsync --safe-links when .config is copied in isolation.
# Recreate only audited links whose resolved source target remains inside the
# versioned profile and exists on the installed target.
restore_profile_link() {
  local relative_path="$1"
  local source_link="$DOTFILES_DIR/$relative_path"
  local target_link="$TARGET_HOME/$relative_path"
  local link_value resolved_source resolved_target
  [[ -L "$source_link" ]] || die "expected profile selector is not a symlink: $relative_path"
  link_value="$(readlink "$source_link")"
  resolved_source="$(realpath -m "$(dirname "$source_link")/$link_value")"
  [[ "$resolved_source" == "$DOTFILES_DIR/"* ]] || die "profile selector escapes snapshot: $relative_path"
  resolved_target="$(realpath -m "$(dirname "$target_link")/$link_value")"
  [[ "$resolved_target" == "$TARGET_HOME/"* && -e "$resolved_target" ]] || die "profile selector target is missing: $relative_path"
  mkdir -p "$(dirname "$target_link")"
  ln -sfn "$link_value" "$target_link"
}

restore_profile_link .config/waybar/config
restore_profile_link .config/waybar/style.css
restore_profile_link .config/rofi/.current_wallpaper

for scripts_dir in "$TARGET_HOME/.config/hypr/scripts" "$TARGET_HOME/.config/hypr/UserScripts"; do
  [[ -d "$scripts_dir" ]] || continue
  find "$scripts_dir" -type f -name '*.sh' -exec chmod u+x {} +
done

log "profile applied; manual backup: $backup_dir"
