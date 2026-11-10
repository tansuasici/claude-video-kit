#!/usr/bin/env bash
#
# install.sh — Claude Video Kit installer
#
# Copies the kit into a product repo. Run from inside a kit checkout:
#
#   bash install.sh [TARGET_DIR] [flags]
#
# Flags:
#   --upgrade     Update kit-managed files; never overwrite your overlay
#                 (CLAUDE.project.md, EDIT_MAP.md, linear.md)
#   --gitignore   Add kit files to the target's .gitignore (keep the kit local)
#   --dry-run     Print what would happen; change nothing
#   --force       Replace existing kit-managed files (the overlay is never
#                 overwritten; .claude/settings.json is merged, not replaced)
#
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
TARGET="$PWD"
UPGRADE=0; GITIGNORE=0; DRYRUN=0; FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --upgrade) UPGRADE=1; shift ;;
    --gitignore) GITIGNORE=1; shift ;;
    --dry-run) DRYRUN=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "Unknown flag: $1" >&2; exit 2 ;;
    *) TARGET="$1"; shift ;;
  esac
done

TARGET="$(cd "$TARGET" 2>/dev/null && pwd || echo "$TARGET")"
if [ "$SRC" = "$TARGET" ]; then
  echo "install: refusing to install the kit into itself ($SRC)." >&2
  echo "Run this from your product repo, pointing at a kit checkout:" >&2
  echo "  bash /path/to/claude-video-kit/install.sh \"\$PWD\"" >&2
  exit 2
fi

# Another Claude kit here uses the same CLAUDE.md and hook names. The map alone
# isn't enough to refuse: a repo can have its own DESIGN_MAP.md and no kit. So
# each kit is two files only it ships; session-start.sh won't do, because this
# kit installs one too. The Code Kit's minimal profile has no CODEBASE_MAP.md,
# so that kit is two of its hooks.
for pair in DESIGN_MAP.md:.claude/hooks/motion-gate.sh .claude/hooks/secret-scan.sh:.claude/hooks/commit-gate.sh MANUSCRIPT_MAP.md:.claude/hooks/citation-gate.sh MARKETING_MAP.md:.claude/hooks/publish-gate.sh; do
  mark="${pair%%:*}"; hook="${pair#*:}"
  [ -e "$TARGET/$mark" ] && [ -e "$TARGET/$hook" ] || continue
  echo "install: this folder already has another Claude kit ($mark and $hook). Nothing was changed." >&2
  echo "Both kits use CLAUDE.md and the same hook names, so one kit's rules and checks would replace the other's, with or without --force." >&2
  echo "Install into a subfolder, and open Claude Code in that subfolder:" >&2
  echo "  bash \"$SRC/install.sh\" \"$TARGET/video\"" >&2
  exit 2
done

say() { printf '%s\n' "$1"; }
do_cp() {  # do_cp SRC_REL [overlay]  (file or dir); overlay files are never replaced; honors --dry-run
  local rel="$1" overlay="${2:-0}"
  local from="$SRC/$rel" to="$TARGET/$rel"
  [ -e "$from" ] || return 0
  if [ -d "$from" ]; then  # per file, so a user's own files in the same folder don't block the kit's
    local f
    while IFS= read -r f; do do_cp "${f#"$SRC"/}" "$overlay"; done < <(find "$from" -type f | sort)
    return 0
  fi
  if [ "$overlay" = "1" ] && [ -e "$to" ]; then
    say "  skip (overlay, kept)   $rel"; return 0
  fi
  if [ -e "$to" ] && [ "$FORCE" = "0" ] && [ "$UPGRADE" = "0" ]; then
    say "  exists (use --force / --upgrade to replace)  $rel"; return 0
  fi
  if [ "$DRYRUN" = "1" ]; then say "  would copy  $rel"; return 0; fi
  mkdir -p "$(dirname "$to")"
  cp "$from" "$to"
  say "  copied  $rel"
}

say ""
say "Claude Video Kit → $TARGET"
say "  source: $SRC"
[ "$DRYRUN" = "1" ] && say "  (dry run — no changes)"
say ""

# Kit-managed (updated by --upgrade)
do_cp "CLAUDE.md"
do_cp ".claude/agents"
do_cp ".claude/hooks"
do_cp ".claude/skills"
do_cp "agent_docs"

# .claude/settings.json: merge the kit's hooks into an existing file instead of
# skipping it (hooks never wired) or replacing it (user permissions lost).
SETTINGS=".claude/settings.json"
if [ ! -e "$TARGET/$SETTINGS" ]; then
  do_cp "$SETTINGS"
elif [ "$DRYRUN" = "1" ]; then
  say "  would merge kit hooks into  $SETTINGS"
elif command -v python3 >/dev/null 2>&1; then
  if python3 - "$SRC/$SETTINGS" "$TARGET/$SETTINGS" <<'PY'
import json, sys
kit = json.load(open(sys.argv[1]))
path = sys.argv[2]
user = json.load(open(path))
before = json.dumps(user, sort_keys=True)
hooks = user.setdefault("hooks", {})
for event, groups in kit.get("hooks", {}).items():
    have = {h.get("command") for g in hooks.get(event, []) for h in g.get("hooks", [])}
    for g in groups:
        new = [h for h in g.get("hooks", []) if h.get("command") not in have]
        if new:
            hooks.setdefault(event, []).append(dict(g, hooks=new))
if json.dumps(user, sort_keys=True) != before:
    with open(path, "w") as f:
        json.dump(user, f, indent=2)
        f.write("\n")
PY
  then say "  merged kit hooks into  $SETTINGS"
  else say "  WARNING: could not parse $SETTINGS; add the \"hooks\" block from $SRC/$SETTINGS by hand"
  fi
else
  say "  WARNING: $SETTINGS exists and python3 is missing; add the \"hooks\" block from $SRC/$SETTINGS by hand"
fi

# CLAUDE.md that isn't the kit's means the kit's rules never load.
if [ -e "$TARGET/CLAUDE.md" ] && ! cmp -s "$SRC/CLAUDE.md" "$TARGET/CLAUDE.md" && [ "$FORCE" = "0" ] && [ "$UPGRADE" = "0" ]; then
  say "  WARNING: your own CLAUDE.md was kept, so the kit's rules will not load."
  say "           Move your rules into CLAUDE.project.md, then rerun with --force."
fi

# Project overlay (never overwritten once it exists)
do_cp "CLAUDE.project.md" 1
do_cp "EDIT_MAP.md" 1

# linear.md: the kit's own task list stays in the kit; the target gets an empty one.
if [ ! -e "$TARGET/linear.md" ]; then
  if [ "$DRYRUN" = "1" ]; then
    say "  would create  linear.md"
  else
    cat > "$TARGET/linear.md" <<'EOF'
# linear.md

> Open video work for this project. **Now** is this session's work; **Next**
> is queued; **Later** is ideas noticed in passing. Single task file; don't
> create `tasks/todo.md`.

## Now

## Next

## Later
EOF
    say "  created  linear.md"
  fi
else
  say "  skip (overlay, kept)   linear.md"
fi

# Hooks must stay executable
if [ "$DRYRUN" = "0" ] && [ -d "$TARGET/.claude/hooks" ]; then
  chmod +x "$TARGET"/.claude/hooks/*.sh 2>/dev/null || true
fi

if [ "$GITIGNORE" = "1" ] && [ "$DRYRUN" = "0" ]; then
  GI="$TARGET/.gitignore"
  for line in "CLAUDE.md" ".claude/" "agent_docs/" "EDIT_MAP.md" "CLAUDE.project.md" "linear.md"; do
    grep -qxF "$line" "$GI" 2>/dev/null || echo "$line" >> "$GI"
  done
  # Always ignore transient state
  for line in ".hook-state/" "reports/" "work/" "renders/"; do
    grep -qxF "$line" "$GI" 2>/dev/null || echo "$line" >> "$GI"
  done
  say "  updated .gitignore"
fi

say ""
say "Done. Next steps:"
say "  1. Start a Claude Code session; session-start.sh reports the edit map state."
say "  2. Fill in EDIT_MAP.md: project, source footage, style, delivery, assets."
say "  3. Ask for a cut in plain words; outputs land in renders/, source footage is never touched."
say ""
