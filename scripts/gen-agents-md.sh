#!/usr/bin/env bash
#
# gen-agents-md.sh — build AGENTS.md from CLAUDE.md
#
#   bash scripts/gen-agents-md.sh          write AGENTS.md
#   bash scripts/gen-agents-md.sh --check  exit 1 if AGENTS.md is out of date
#
set -euo pipefail
cd "$(dirname "$0")/.."

render() {
  cat <<'HEAD'
<!--
  Generated from CLAUDE.md — DO NOT EDIT BY HAND.
  CLAUDE.md is the single source of truth for Claude Video Kit.
  Regenerate with: bash scripts/gen-agents-md.sh
-->

HEAD
  cat CLAUDE.md
}

if [ "${1:-}" = "--check" ]; then
  if ! diff -u AGENTS.md <(render); then
    echo "AGENTS.md is out of date. Run: bash scripts/gen-agents-md.sh" >&2
    exit 1
  fi
  echo "AGENTS.md matches CLAUDE.md"
  exit 0
fi

render > AGENTS.md
echo "wrote AGENTS.md"
