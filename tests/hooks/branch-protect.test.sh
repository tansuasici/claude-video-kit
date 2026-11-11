#!/usr/bin/env bash
#
# branch-protect.test.sh — tests for .claude/hooks/branch-protect.sh
#
# Usage: bash tests/hooks/branch-protect.test.sh
#
# Bare `git push` and `push origin HEAD` read the current branch, so those
# cases run inside a throwaway repo.
#
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

KIT="$PWD"
HOOK="$KIT/.claude/hooks/branch-protect.sh"
pass=0; fail=0

repo=$(mktemp -d); nolib=$(mktemp -d)
trap 'rm -rf "$repo" "$nolib"' EXIT
git -C "$repo" init -q -b main
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init

# run COMMAND [DIR] [HOOK] → "exit=N|stdout=...|stderr=..."
run() {
  local json out err code tmp
  json=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1")
  tmp=$(mktemp)
  out=$(cd "${2:-$KIT}" && printf '%s' "$json" | CLAUDE_PROJECT_DIR="${2:-$KIT}" "${3:-$HOOK}" 2>"$tmp"); code=$?
  err=$(cat "$tmp"); rm -f "$tmp"
  printf 'exit=%s|stdout=%s|stderr=%s' "$code" "$out" "$err"
}

ok()  { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n%s\n' "$1" "$2"; }
blocks() {  # name result needle
  case "$2" in
    "exit=2|stdout=|stderr="*"$3"*) ok "$1" ;;
    *) bad "$1" "  expected exit 2, empty stdout, stderr with: $3"$'\n'"  got: $2" ;;
  esac
}
allows() {
  if [ "$2" = "exit=0|stdout=|stderr=" ]; then ok "$1"; else bad "$1" "  expected a silent pass, got: $2"; fi
}

# ---- explicit protected branch ----------------------------------------------

blocks "push origin main"                 "$(run 'git push origin main')"                 "Direct push to main/master"
blocks "push -u origin master"            "$(run 'git push -u origin master')"            "Direct push to main/master"
blocks "push --set-upstream origin main"  "$(run 'git push --set-upstream origin main')"  "Direct push to main/master"
blocks "refspec HEAD:main"                "$(run 'git push origin HEAD:main')"            "Direct push to main/master"
blocks "global options before push"       "$(run 'git -c color.ui=always push origin main')" "Direct push to main/master"
blocks "chained after another command"    "$(run 'git add -A && git push origin main')"   "Direct push to main/master"
allows "refspec main:feature pushes to a feature branch" "$(run 'git push origin main:feature')"
allows "feature branch push"              "$(run 'git push -u origin feat/x')"
allows "a branch named main-docs"         "$(run 'git push origin main-docs')"

# ---- only the push segment counts --------------------------------------------
# Text after `&&`, `||`, `;` or `|` belongs to another command, not the push.

allows "push then gh pr create --base main" "$(run 'git push -u origin feat/x && gh pr create --base main --title x')"
allows "push then echo main"              "$(run 'git push origin feat/x; echo main')"
allows "push piped to grep main"          "$(run 'git push origin feat/x 2>&1 | grep main')"
allows "push or echo master"              "$(run 'git push origin feat/x || echo master')"
allows "push then rm -f elsewhere"        "$(run 'git push origin feat/x && rm -f out.log')"
blocks "cd then push origin main"         "$(run 'cd x && git push origin main')"         "Direct push to main/master"
blocks "feature push then main push"      "$(run 'git push origin feat/x && git push origin main')" "Direct push to main/master"
blocks "push origin main then gh pr"      "$(run 'git push origin main && gh pr create --base main')" "Direct push to main/master"
blocks "cd then force push"               "$(run 'cd x && git push --force origin feat/x')" "Force push"

# ---- force push --------------------------------------------------------------

blocks "--force"                          "$(run 'git push --force origin feat/x')"       "Force push"
blocks "-f"                               "$(run 'git push -f origin feat/x')"            "Force push"
allows "--force-with-lease"               "$(run 'git push --force-with-lease origin feat/x')"

# ---- current branch ----------------------------------------------------------

blocks "bare push on main"                "$(run 'git push' "$repo")"                     "bare 'git push'"
blocks "push -u origin on main"           "$(run 'git push -u origin' "$repo")"           "bare 'git push'"
blocks "push origin HEAD on main"         "$(run 'git push origin HEAD' "$repo")"         "resolves to protected branch 'main'"
blocks "chained bare push on main"        "$(run 'git add -A && git push' "$repo")"       "bare 'git push'"
git -C "$repo" checkout -q -b feat/y
allows "bare push on a feature branch"    "$(run 'git push' "$repo")"
allows "push origin HEAD on a feature branch" "$(run 'git push origin HEAD' "$repo")"

# ---- other input -------------------------------------------------------------

allows "commands that are not pushes"     "$(run 'git status')"
out=$(cd "$KIT" && printf '{"tool_name":"Write","tool_input":{"command":"git push origin main"}}' | "$HOOK" 2>&1); code=$?
if [ "$code" -eq 0 ] && [ -z "$out" ]; then ok "non-Bash tools are ignored"; else bad "non-Bash tools are ignored" "  got exit=$code: $out"; fi

cp "$HOOK" "$nolib/branch-protect.sh"
blocks "missing lib/ fails closed"        "$(run 'git status' "$KIT" "$nolib/branch-protect.sh")" "cannot load .claude/hooks/lib/"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
