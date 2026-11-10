#!/usr/bin/env bash
#
# prompt-router.sh — UserPromptSubmit hook
#
# Looks at the user's prompt and injects the matching video-editing reminder
# when the task touches a known failure point (source footage, licences,
# render checks, paid generation, subtitle claims, publishing). Emits nothing
# when no keyword matches. Always exits 0.
#

set -euo pipefail

INPUT=$(cat)
HOOK_LIB="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)" || exit 0
# shellcheck source=lib/json-parse.sh
source "$HOOK_LIB/json-parse.sh"
# shellcheck source=lib/emit.sh
source "$HOOK_LIB/emit.sh"

PROMPT=$(parse_json_field "prompt")
[ -z "$PROMPT" ] && exit 0
LOWER=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')

REMINDERS=""
append() { REMINDERS="${REMINDERS}${1}"$'\n'; }
# Whole words only: "postgres" is not "post".
has() { printf '%s' "$LOWER" | grep -qE "(^|[^a-z])($1)([^a-z]|$)"; }

# Editing work of any kind: the map comes first
if has 'edit|cut|trim|clips?|videos?|shorts?|reels?|highlights?|montage|footage|timeline|b-roll'; then
  append "[Map first] Read EDIT_MAP.md → Source footage, Style and Delivery before editing. If the map is the empty template, fill it in first."
fi

# Anything that could change the source files
if has 'trim|cut|delete|remove|overwrite|replace|re-?encode|transcode|convert|compress|normali[sz]e|denoise'; then
  append "[Source read-only] Never modify, move or overwrite source footage. Write intermediates to work/ and outputs to renders/."
fi

# Third-party assets
if has 'music|songs?|tracks?|sfx|sound effects?|fonts?|stock|b-roll|logos?|images?|overlays?|assets?'; then
  append "[Licence] An asset enters a render only with a line in EDIT_MAP.md → Assets (source, licence, attribution). No line, no render."
fi

# Rendering and export
if has 'render|export|encode|deliver|final cut|master'; then
  append "[Render QC] A render is done only after frame samples, ffprobe and a loudness measurement match EDIT_MAP.md → Delivery. Report the numbers."
fi

# Paid generation
if has 'generate|generation|text-to-video|image-to-video|ai video|higgsfield|voice ?clone|tts|upscale'; then
  append "[Cost] Paid generation needs the cost shown and the user's yes in this session before the call."
fi

# Words on screen
if has 'subtitles?|captions?|srt|lower thirds?|titles?|text overlays?|on-screen text'; then
  append "[Subtitle claims] Numbers and claims in subtitles or on-screen text need a source. Mark a gap [NEEDS PROOF] and ask."
fi

# Publishing
if has 'publish|upload|post (it|this|now)|schedule|go live'; then
  append "[No publishing] This kit stops at renders/. Publishing goes through Claude Marketing Kit's approval gate or the user."
fi

[ -z "$REMINDERS" ] && exit 0
emit_context "UserPromptSubmit" "$REMINDERS"
exit 0
