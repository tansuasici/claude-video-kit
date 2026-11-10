#!/usr/bin/env bash
#
# session-start.sh — SessionStart hook
#
# Injects Tier 1 context at session start: whether EDIT_MAP.md is filled in,
# its Project line and first Delivery row, the project overlay, linear.md → Now, and
# the branch / dirty tree. Replaces the "Session Boot" rule in CLAUDE.md, which
# depends on the agent remembering it. Output: hookSpecificOutput JSON. Exits 0.
#

set -euo pipefail

cat >/dev/null  # stdin carries nothing this hook needs
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)" || exit 0
# shellcheck source=lib/state-counter.sh
source "$HOOK_LIB/state-counter.sh"
# shellcheck source=lib/emit.sh
source "$HOOK_LIB/emit.sh"

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.hook-state"
mkdir -p "$STATE_DIR" 2>/dev/null || true
[ -f "$STATE_DIR/.gitignore" ] || printf '*\n' >"$STATE_DIR/.gitignore" 2>/dev/null || true
reset_state "$STATE_DIR/hook-firings.json"

CONTEXT=""
append_line() { CONTEXT="${CONTEXT}${1}"$'\n'; }

append_line "[Auto-injected by session-start.sh]"

# First non-empty, non-comment, non-quote line under a "## <Heading>".
section_line() {
  awk -v h="## $2" '
    index($0, h) == 1 { f = 1; next }
    f && /^## / { exit }
    f && /<!--/ { c = 1 }
    f && !c && NF && $0 !~ /^>/ { print; exit }
    f && /-->/ { c = 0 }
  ' "$1" 2>/dev/null || true
}

# First data row of the table under "## <Heading>" (skips header and separator).
table_row() {
  awk -v h="## $2" '
    index($0, h) == 1 { f = 1; next }
    f && /^## / { exit }
    f && /^\|/ { n++; if (n == 3) { print; exit } }
  ' "$1" 2>/dev/null || true
}

# 1. Edit map
MAP="$ROOT/EDIT_MAP.md"
if [ -f "$MAP" ]; then
  PROJECT=$(section_line "$MAP" "Project")
  DELIVERY=$(table_row "$MAP" "Delivery")
  if [ -z "$PROJECT" ] || printf '%s' "$PROJECT" | grep -q '<'; then
    append_line "EDIT_MAP.md is still the template. Fill it in (project, source footage, delivery, assets) before cutting anything."
  else
    append_line "EDIT_MAP.md is filled in. Read it before editing. Source footage listed there is read-only."
    append_line "Project → $PROJECT"
    [ -n "$DELIVERY" ] && ! printf '%s' "$DELIVERY" | grep -q '<' && append_line "Delivery → $DELIVERY"
  fi
else
  append_line "No EDIT_MAP.md. Copy the kit template and fill it in before cutting anything."
fi
# Plugin install: the kit's docs and templates stay in the plugin, not the project.
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ ! -d "$ROOT/agent_docs" ]; then
  append_line "Kit runs as a plugin: read agent_docs/*.md from $CLAUDE_PLUGIN_ROOT/agent_docs/, and copy the EDIT_MAP.md template from $CLAUDE_PLUGIN_ROOT/EDIT_MAP.md."
fi
if [ -f "$ROOT/CLAUDE.project.md" ]; then
  if grep -q '<\.\.\.>' "$ROOT/CLAUDE.project.md" 2>/dev/null; then
    append_line "Project overlay: CLAUDE.project.md is still the template; fill in Product and Owner when you know them."
  else
    append_line "Project overlay: CLAUDE.project.md is present; its rules override kit defaults."
  fi
fi

# 2. Now in linear.md
if [ -f "$ROOT/linear.md" ]; then
  NOW_ITEMS=$(awk '/^## Now/{f=1;next} f && /^## /{exit} f && /^- \[ \]/{print; n++; if(n>=5) exit}' "$ROOT/linear.md" 2>/dev/null || true)
  if [ -n "$NOW_ITEMS" ]; then
    append_line ""
    append_line "linear.md → Now:"
    append_line "$NOW_ITEMS"
  fi
fi

# 3. Branch + dirty tree
if command -v git &>/dev/null && [ -d "$ROOT/.git" ]; then
  BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null || true)
  [ -n "$BRANCH" ] && { append_line ""; append_line "Branch: $BRANCH"; }
  DIRTY=$(git -C "$ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ' || true)
  if [ "${DIRTY:-0}" -gt 0 ]; then
    append_line "Working tree: ${DIRTY} uncommitted file(s). Check they belong to the current task before continuing."
  fi
fi

emit_context "SessionStart" "$CONTEXT"
exit 0
