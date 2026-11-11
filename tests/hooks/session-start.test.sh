#!/usr/bin/env bash
#
# session-start.test.sh — tests for .claude/hooks/session-start.sh
#
# Usage: bash tests/hooks/session-start.test.sh
#
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

KIT="$PWD"
HOOK="$KIT/.claude/hooks/session-start.sh"
pass=0; fail=0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# start_json PROJECT_DIR [PLUGIN_ROOT] → hook's stdout
start_json() {
  printf '{"hook_event_name":"SessionStart"}' \
    | env -u CLAUDE_PLUGIN_ROOT CLAUDE_PROJECT_DIR="$1" ${2:+CLAUDE_PLUGIN_ROOT="$2"} "$HOOK"
}

ok()  { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n%s\n' "$1" "$2"; }
expect_has() {  # name output needle...
  local name="$1" out="$2"; shift 2
  for needle in "$@"; do
    if ! printf '%s' "$out" | grep -qF -- "$needle"; then bad "$name" "  missing: $needle"$'\n'"  got: $out"; return; fi
  done
  ok "$name"
}
expect_lacks() {
  local name="$1" out="$2"; shift 2
  for needle in "$@"; do
    if printf '%s' "$out" | grep -qF -- "$needle"; then bad "$name" "  unexpected: $needle"$'\n'"  got: $out"; return; fi
  done
  ok "$name"
}

# ---- edit map ----------------------------------------------------------------

# No EDIT_MAP.md: not a video project. The plugin runs this hook in every
# session, so it must print nothing and leave the repo alone.
empty="$tmp/empty"; mkdir -p "$empty"
out=$(start_json "$empty" "/plugin/root")
if [ -z "$out" ] && [ ! -e "$empty/.hook-state" ]; then
  ok "no map: silent, no .hook-state"
else
  bad "no map: silent, no .hook-state" "  got: $out $(ls -a "$empty")"
fi

tpl="$tmp/tpl"; mkdir -p "$tpl"; cp "$KIT/EDIT_MAP.md" "$tpl/"
out=$(start_json "$tpl")
expect_has "a map gives SessionStart JSON" "$out" '"hookEventName": "SessionStart"'
if printf '%s' "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then ok "output is valid JSON"; else bad "output is valid JSON" "  got: $out"; fi

# From here on, check the decoded context text (the JSON escapes → as →).
start() { start_json "$@" | python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])'; }

expect_has "the kit template counts as unfilled" "$(start "$tpl")" "still the template"

filled="$tmp/filled"; mkdir -p "$filled"
cat > "$filled/EDIT_MAP.md" <<'MAP'
## Project
<!-- one line -->
> template hint
- **What this is, in one line:** ep12 podcast → three shorts
## Source footage
## Delivery
| Target | Resolution | fps |
|---|---|---|
| Shorts | 1080x1920 | 30 |
| Square | 1080x1080 | 30 |
## Assets
MAP
out=$(start "$filled")
expect_has "a filled map shows Project and the first Delivery row" "$out" "is filled in" \
  "Project → - **What this is, in one line:** ep12 podcast" "Delivery → | Shorts | 1080x1920 | 30 |"
expect_lacks "comments, quote hints and later rows are skipped" "$out" "one line -->" "template hint" "Square"

# ---- overlay, linear.md, plugin --------------------------------------------

printf 'Product: <...>\n' > "$tpl/CLAUDE.project.md"
expect_has "template overlay" "$(start "$tpl")" "CLAUDE.project.md is still the template"
printf 'Product: Acme\n' > "$filled/CLAUDE.project.md"
expect_has "filled overlay" "$(start "$filled")" "its rules override kit defaults"

cat > "$filled/linear.md" <<'LIN'
## Now
- [ ] one
- [x] done
- [ ] two
- [ ] three
- [ ] four
- [ ] five
- [ ] six
## Next
- [ ] later
LIN
out=$(start "$filled")
expect_has "open Now items are listed" "$out" "linear.md → Now:" "- [ ] one" "- [ ] five"
expect_lacks "done, past-five and Next items are not" "$out" "- [x] done" "- [ ] six" "- [ ] later"

expect_has "plugin install points at the plugin's docs" "$(start "$tpl" "/plugin/root")" "Kit runs as a plugin" "/plugin/root/agent_docs/"
expect_lacks "no plugin note without CLAUDE_PLUGIN_ROOT" "$(start "$tpl")" "Kit runs as a plugin"

# ---- git and state -----------------------------------------------------------

git -C "$filled" init -q -b feat/z
out=$(start "$filled")
expect_has "branch and dirty tree are reported" "$out" "Branch: feat/z" "uncommitted file(s)"

mkdir -p "$filled/.hook-state"; printf '{"branch-protect": 3}' > "$filled/.hook-state/hook-firings.json"
start "$filled" >/dev/null
if [ ! -f "$filled/.hook-state/hook-firings.json" ] && [ -f "$filled/.hook-state/.gitignore" ]; then
  ok "firing counters reset; .hook-state ignores itself"
else
  bad "firing counters reset; .hook-state ignores itself" "  $(ls -a "$filled/.hook-state")"
fi
gitdir=$(mktemp -d); git -C "$gitdir" init -q
cp "$KIT/EDIT_MAP.md" "$gitdir/"
git -C "$gitdir" add EDIT_MAP.md && git -C "$gitdir" -c user.name=t -c user.email=t@t commit -q -m map
start_json "$gitdir" >/dev/null
if [ -z "$(git -C "$gitdir" status --porcelain)" ]; then
  ok ".hook-state stays out of git status"
else
  bad ".hook-state stays out of git status" "  $(git -C "$gitdir" status --porcelain)"
fi
rm -rf "$gitdir"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
