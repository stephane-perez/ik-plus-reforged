#!/bin/bash
# Début de session Claude Code sur le web : installe les outils
# (scripts/setup-dev.sh). Rien à faire sur une machine locale.
set -euo pipefail
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi
sh "$CLAUDE_PROJECT_DIR/scripts/setup-dev.sh"
