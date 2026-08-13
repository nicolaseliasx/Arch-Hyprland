#!/usr/bin/env bash
# Non-privileged regression checks for repeatable Zsh and Code Flow setup.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT
TEST_HOME="$WORK/home"
TEST_BIN="$WORK/bin"
TEST_STATE="$WORK/state"
mkdir -p "$TEST_HOME" "$TEST_BIN" "$TEST_STATE"
cp "$ROOT/assets/dotfiles/.zshrc" "$ROOT/assets/dotfiles/.p10k.zsh" "$TEST_HOME/"

cat >"$TEST_BIN/git" <<'EOF'
#!/usr/bin/env bash
set -e
destination="${@: -1}"
mkdir -p "$destination/.git"
case "$destination" in
  */.oh-my-zsh) touch "$destination/oh-my-zsh.sh" ;;
  */powerlevel10k) touch "$destination/powerlevel10k.zsh-theme" ;;
  *) exit 1 ;;
esac
EOF

cat >"$TEST_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat >"$TEST_BIN/getent" <<'EOF'
#!/usr/bin/env bash
printf 'tester:x:1000:1000::%s:/usr/bin/zsh\n' "$HOME"
EOF

cat >"$TEST_BIN/codex" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat >"$TEST_BIN/gh" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$TEST_BIN"/*

component_env=(
  HOME="$TEST_HOME"
  USER=tester
  XDG_STATE_HOME="$TEST_STATE"
  PATH="$TEST_BIN:/usr/bin"
  ARCH_HYPRLAND_LOG_FILE="$TEST_STATE/components.log"
)

env "${component_env[@]}" "$ROOT/install-scripts/configure-zsh.sh"
env "${component_env[@]}" "$ROOT/install-scripts/configure-zsh.sh"
[[ -L "$TEST_HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]]
[[ -L "$TEST_HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]]
[[ -f "$TEST_HOME/.oh-my-zsh/custom/themes/powerlevel10k/powerlevel10k.zsh-theme" ]]

env "${component_env[@]}" "$ROOT/install-scripts/code-flow.sh"
env "${component_env[@]}" "$ROOT/install-scripts/code-flow.sh"
[[ -x "$TEST_HOME/.local/bin/codex-flow" ]]
[[ -f "$TEST_HOME/.local/share/codex-flow/shell/init.zsh" ]]
[[ "$(grep -c '^# >>> codex-flow managed >>>$' "$TEST_HOME/.zshrc")" -eq 1 ]]

printf 'installer component smoke test passed\n'
