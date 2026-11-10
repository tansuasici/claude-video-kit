#!/usr/bin/env bash
#
# prompt-router.test.sh — tests for .claude/hooks/prompt-router.sh
#
# Usage: bash tests/hooks/prompt-router.test.sh
#
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

HOOK="$PWD/.claude/hooks/prompt-router.sh"
pass=0; fail=0

# route PROMPT → hook's stdout
route() {
  python3 -c 'import json,sys; print(json.dumps({"hook_event_name":"UserPromptSubmit","prompt":sys.argv[1]}))' "$1" | "$HOOK"
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
expect_empty() {
  if [ -z "$2" ]; then ok "$1"; else bad "$1" "  expected no output, got: $2"; fi
}

out=$(route "Make a short from this interview")
expect_has "editing work gets the map reminder" "$out" '"hookEventName": "UserPromptSubmit"' "[Map first]" "EDIT_MAP.md"
expect_lacks "only the matching reminder" "$out" "[Licence]" "[Render QC]" "[Cost]" "[No publishing]"

expect_has "trimming gets the source rule" "$(route "Trim the first ten seconds")" "[Source read-only]" "renders/"
expect_has "music gets the licence rule" "$(route "Add background music")" "[Licence]"
expect_has "export gets render QC" "$(route "Export the final file")" "[Render QC]" "ffprobe"
expect_has "generation gets the cost rule" "$(route "Generate a b-roll shot with Higgsfield")" "[Cost]"
expect_has "subtitles get the claims rule" "$(route "Burn in subtitles")" "[Subtitle claims]" "[NEEDS PROOF]"
expect_has "upload gets the no-publishing rule" "$(route "Upload it to YouTube")" "[No publishing]"
expect_has "matching ignores case" "$(route "RENDER THE REEL")" "[Render QC]" "[Map first]"

out=$(route "Cut a reel with music and subtitles, then render and publish it")
expect_has "several reminders stack" "$out" "[Map first]" "[Source read-only]" "[Licence]" "[Render QC]" "[Subtitle claims]" "[No publishing]"

expect_empty "whole words only: editor, cutter, rendering" "$(route "Fix the editorconfig cutter rendering bug")"
expect_empty "unrelated prompts are silent" "$(route "Rename the variable in install.sh")"
expect_empty "an empty prompt is silent" "$(route "")"
expect_empty "bad JSON is silent" "$(printf 'nope' | "$HOOK" 2>/dev/null)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
