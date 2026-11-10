#!/usr/bin/env bash
#
# block-dangerous-commands.test.sh — tests for .claude/hooks/block-dangerous-commands.sh
#
# Usage: bash tests/hooks/block-dangerous-commands.test.sh
#
# Commands are only passed to the hook as JSON, never run.
#
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

KIT="$PWD"
HOOK="$KIT/.claude/hooks/block-dangerous-commands.sh"
pass=0; fail=0

proj=$(mktemp -d)
trap 'rm -rf "$proj"' EXIT

# run COMMAND → "exit=N|stdout=...|stderr=..."
run() {
  local json out err code tmp
  json=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1")
  tmp=$(mktemp)
  out=$(printf '%s' "$json" | CLAUDE_PROJECT_DIR="$proj" "$HOOK" 2>"$tmp"); code=$?
  err=$(cat "$tmp"); rm -f "$tmp"
  printf 'exit=%s|stdout=%s|stderr=%s' "$code" "$out" "$err"
}

ok()  { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n%s\n' "$1" "$2"; }
blocks() {  # command reason
  local r; r=$(run "$1")
  case "$r" in
    "exit=2|stdout=|stderr=BLOCKED: $2"*) ok "blocks: $1" ;;
    *) bad "blocks: $1" "  expected exit 2, empty stdout, stderr 'BLOCKED: $2'"$'\n'"  got: $r" ;;
  esac
}
allows() {
  local r; r=$(run "$1")
  if [ "$r" = "exit=0|stdout=|stderr=" ]; then ok "allows: $1"; else bad "allows: $1" "  got: $r"; fi
}

# ---- recursive deletes -------------------------------------------------------

blocks 'rm -rf /'                       "Recursive delete on root directory"
blocks 'rm -rf /*'                      "Recursive delete on root directory"
blocks 'rm -rf -- /'                    "Recursive delete on root directory"
blocks 'sudo rm -rf /etc/nginx'         "Recursive delete on a system directory"
blocks 'rm -r -f /usr'                  "Recursive delete on a system directory"
blocks 'rm --recursive --force /Library' "Recursive delete on a system directory"
blocks 'rm -rf ~'                       "Recursive delete on home directory"
blocks 'rm -rf ~/Documents'             "Recursive delete on home directory"
# shellcheck disable=SC2016  # literal $HOME is the point
blocks 'rm -rf $HOME'                   "Recursive delete on home directory"
blocks 'rm -rf /Users/someone'          "Recursive delete on home directory"
blocks 'rm -rf .'                       "Recursive delete on current directory"
blocks 'rm -rf *'                       "Recursive delete with wildcard"
blocks 'rm -rf --no-preserve-root /x'   "rm --no-preserve-root"
allows 'rm -rf node_modules'
allows 'rm -rf ./dist'
allows 'rm -rf ~/proj/dist'
allows 'rm -rf /tmp/build'
allows 'rm -rf /Users/someone/app/node_modules'
allows 'rm notes.txt'

# ---- git, SQL, docker, permissions ------------------------------------------

blocks 'git reset --hard HEAD~1'        "git reset --hard"
blocks 'git clean -fd'                  "git clean -fd"
blocks 'git clean -d -f'                "git clean -fd"
blocks 'psql -c "drop table users"'     "SQL DROP"
blocks 'mysql -e "TRUNCATE TABLE logs"' "SQL TRUNCATE"
blocks 'docker system prune -a'         "Docker system prune -a"
blocks 'sudo chmod -R 777 /'            "Recursive permission change"
blocks 'chown -R me /usr/local'         "Recursive permission change"
allows 'git reset --soft HEAD~1'
allows 'git clean -n'
allows 'chmod -R 755 /var/www/app'
allows 'docker system prune'

# ---- other input -------------------------------------------------------------

out=$(printf '{"tool_name":"Write","tool_input":{"command":"git reset --hard"}}' | CLAUDE_PROJECT_DIR="$proj" "$HOOK" 2>&1); code=$?
if [ "$code" -eq 0 ] && [ -z "$out" ]; then ok "non-Bash tools are ignored"; else bad "non-Bash tools are ignored" "  got exit=$code: $out"; fi

run 'git reset --hard' >/dev/null
if grep -q '"block-dangerous-commands"' "$proj/.hook-state/hook-firings.json" 2>/dev/null; then
  ok "a block bumps the firing counter"
else
  bad "a block bumps the firing counter" "  no counter in $proj/.hook-state/hook-firings.json"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
