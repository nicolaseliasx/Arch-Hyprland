# Bundled Code Flow core

This directory contains the portable, credential-free Code Flow core used by
`install-scripts/code-flow.sh`. It intentionally includes only the core shell
runtime and generic global skills. Personal project profiles, credentials,
tokens, review artifacts and repository-specific context are not bundled.

Set `CODEX_FLOW_SOURCE=/path/to/codex-flow-installer` when running the main
installer to use another compatible source tree.
