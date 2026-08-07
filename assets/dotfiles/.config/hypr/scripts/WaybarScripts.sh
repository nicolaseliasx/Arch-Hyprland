#!/usr/bin/env bash
set -euo pipefail

term="${TERMINAL:-kitty}"
files="${HYPR_FILE_MANAGER:-thunar}"
case "${1:-}" in
  --btop) "$term" --title btop sh -c btop ;;
  --nvtop) "$term" --title nvtop sh -c nvtop ;;
  --nmtui) "$term" nmtui ;;
  --term) "$term" & ;;
  --files) "$files" & ;;
  *) echo "Usage: $0 [--btop | --nvtop | --nmtui | --term | --files]"; exit 2 ;;
esac
