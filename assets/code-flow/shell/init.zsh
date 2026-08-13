#!/usr/bin/env zsh

export CODEX_FLOW_HOME="${CODEX_FLOW_HOME:-$HOME/.local/share/codex-flow}"

if [[ -f "$CODEX_FLOW_HOME/shell/core.zsh" ]]; then
  source "$CODEX_FLOW_HOME/shell/core.zsh"
fi

if [[ -f "$CODEX_FLOW_HOME/config/pec.env" ]]; then
  source "$CODEX_FLOW_HOME/config/pec.env"
  if [[ -f "$CODEX_FLOW_HOME/profiles/pec/shell/pec.zsh" ]]; then
    source "$CODEX_FLOW_HOME/profiles/pec/shell/pec.zsh"
  fi
fi

