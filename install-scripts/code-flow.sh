#!/usr/bin/env bash
set -Eeuo pipefail

log_file="${ARCH_HYPRLAND_LOG_FILE:-/dev/null}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_dir="${CODEX_FLOW_SOURCE:-$script_dir/../assets/code-flow}"

export PATH="$HOME/.local/bin:$PATH"

if ! command -v codex >/dev/null 2>&1; then
  printf 'Installing the official OpenAI Codex CLI...\n'
  curl -fsSL https://chatgpt.com/codex/install.sh | sh >>"$log_file" 2>&1
  export PATH="$HOME/.local/bin:$HOME/.codex/bin:$PATH"
fi
command -v codex >/dev/null 2>&1 || { printf 'Codex CLI installation failed\n' >&2; exit 1; }

[[ -x "$source_dir/bin/codex-flow" ]] || { printf 'bundled codex-flow installer is missing\n' >&2; exit 1; }
[[ -r "$source_dir/shell/init.zsh" ]] || { printf 'bundled codex-flow shell integration is missing\n' >&2; exit 1; }
"$source_dir/bin/codex-flow" install >>"$log_file" 2>&1

command -v codex-flow >/dev/null 2>&1 || { printf 'codex-flow executable not found after installation\n' >&2; exit 1; }
[[ -r "$HOME/.local/share/codex-flow/shell/init.zsh" ]] || { printf 'codex-flow shell integration is missing\n' >&2; exit 1; }
codex-flow doctor >>"$log_file" 2>&1 || printf 'codex-flow doctor reported optional account/configuration warnings; see the log\n'
