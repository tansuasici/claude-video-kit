#!/usr/bin/env bash
# Runs every check from .github/workflows/validate.yml on this machine.
# Needs jq and shellcheck. The pre-push hook in .githooks/ calls it.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

for tool in jq shellcheck; do
  command -v "$tool" >/dev/null 2>&1 || { echo "validate: $tool is not installed" >&2; exit 1; }
done

step() { printf '\n== %s\n' "$1"; }

step "plugin manifest"
./scripts/check-plugin.sh

step "JSON"
git ls-files -z '*.json' | xargs -0 -n1 jq empty

step "shellcheck"
git ls-files -z '*.sh' | xargs -0 shellcheck

step "AGENTS.md matches CLAUDE.md"
bash scripts/gen-agents-md.sh --check

step "hook tests"
bash tests/hooks/session-start.test.sh
bash tests/hooks/prompt-router.test.sh
bash tests/hooks/branch-protect.test.sh
bash tests/hooks/block-dangerous-commands.test.sh
bash tests/install-other-kit.test.sh

printf '\nvalidate: all checks passed\n'
