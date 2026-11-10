#!/usr/bin/env bash
#
# emit.sh — Shared output helper for Claude Video Kit hooks
#
# Usage:
#
#   source "$HOOK_LIB/emit.sh"
#   emit_context "PostToolUse" "$MESSAGE"
#
# Prints {"hookSpecificOutput":{"hookEventName":...,"additionalContext":...}} to
# stdout. Warn-only hooks must use this and exit 0: at exit 0 Claude never sees
# stderr, so a warning written there is silently lost.
#

emit_context() {
  local event="$1"
  local text="$2"
  [ -z "$text" ] && return 0
  if command -v python3 &>/dev/null; then
    printf '%s' "$text" | python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":sys.argv[1],"additionalContext":sys.stdin.read().rstrip()}}))' "$event"
  elif command -v jq &>/dev/null; then
    printf '%s' "$text" | jq -Rs --arg ev "$event" '{hookSpecificOutput:{hookEventName:$ev, additionalContext:(. | rtrimstr("\n"))}}'
  else
    local escaped
    escaped=$(printf '%s' "$text" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | awk 'BEGIN{ORS=""} {print; printf "\\n"}')
    printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$event" "$escaped"
  fi
}
