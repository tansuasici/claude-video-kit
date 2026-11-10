#!/usr/bin/env bash
#
# uninstall.sh — remove Claude Video Kit from a product repo
#
#   bash uninstall.sh [TARGET_DIR] [flags]
#
# Removes only the files the kit installs (listed from this kit checkout), so
# your own skills, agents and hooks under .claude/ stay.
#
# Flags:
#   --dry-run        Show what would be removed; change nothing
#   --keep-project   Preserve overlay (CLAUDE.project.md, EDIT_MAP.md, linear.md)
#   --force          Remove without confirmation
#
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
TARGET="$PWD"; DRYRUN=0; KEEP_PROJECT=0; FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRYRUN=1; shift ;;
    --keep-project) KEEP_PROJECT=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "Unknown flag: $1" >&2; exit 2 ;;
    *) TARGET="$1"; shift ;;
  esac
done

TARGET="$(cd "$TARGET" 2>/dev/null && pwd || echo "$TARGET")"
if [ "$SRC" = "$TARGET" ]; then
  echo "uninstall: refusing to uninstall the kit from its own checkout." >&2
  exit 2
fi

# Files are removed by name, and another Claude kit uses the same names for its
# CLAUDE.md and hooks. Removing them here would switch that kit's checks off.
# Each kit is two files only it ships, as in install.sh.
for pair in DESIGN_MAP.md:.claude/hooks/motion-gate.sh .claude/hooks/secret-scan.sh:.claude/hooks/commit-gate.sh MANUSCRIPT_MAP.md:.claude/hooks/citation-gate.sh MARKETING_MAP.md:.claude/hooks/publish-gate.sh; do
  mark="${pair%%:*}"; hook="${pair#*:}"
  [ -e "$TARGET/$mark" ] && [ -e "$TARGET/$hook" ] || continue
  echo "uninstall: this folder also has another Claude kit ($mark and $hook). Nothing was removed." >&2
  echo "Both kits use CLAUDE.md and the same hook names, so this would delete that kit's rules and hooks too." >&2
  echo "To remove this kit and keep the other: move $mark out of the folder, rerun this with --keep-project (the overlay files are shared), move $mark back, then rerun the other kit's install.sh with --force (the Code kit's with --upgrade) to restore its files. EDIT_MAP.md stays, so delete it if you no longer want it." >&2
  exit 2
done

# Kit-managed files, file by file, from the kit's own tree.
to_remove=( "CLAUDE.md" )
while IFS= read -r f; do to_remove+=( "${f#"$SRC"/}" ); done < <(
  find "$SRC/.claude/agents" "$SRC/.claude/hooks" "$SRC/.claude/skills" -type f 2>/dev/null | sort
)
if [ -d "$SRC/agent_docs" ]; then
  while IFS= read -r f; do to_remove+=( "${f#"$SRC"/}" ); done < <(find "$SRC/agent_docs" -type f | sort)
fi
[ "$KEEP_PROJECT" = "0" ] && to_remove+=( "CLAUDE.project.md" "EDIT_MAP.md" "linear.md" )

# settings.json goes only if it is still exactly the kit's copy.
SETTINGS_NOTE=""
if [ -e "$TARGET/.claude/settings.json" ]; then
  if cmp -s "$SRC/.claude/settings.json" "$TARGET/.claude/settings.json"; then
    to_remove+=( ".claude/settings.json" )
  else
    SETTINGS_NOTE="  keep    .claude/settings.json (changed since install; remove the kit's \"hooks\" entries by hand)"
  fi
fi

echo ""
echo "Claude Video Kit uninstall → $TARGET"
[ "$DRYRUN" = "1" ] && echo "  (dry run)"
echo ""
n=0
for rel in "${to_remove[@]}"; do
  [ -e "$TARGET/$rel" ] || continue
  echo "  remove  $rel"; n=$((n + 1))
done
[ -n "$SETTINGS_NOTE" ] && echo "$SETTINGS_NOTE"
[ -d "$TARGET/.hook-state" ] && echo "  remove  .hook-state/"
[ "$n" = "0" ] && [ ! -d "$TARGET/.hook-state" ] && { echo "  nothing to remove"; exit 0; }

if [ "$DRYRUN" = "1" ]; then echo ""; echo "Dry run — nothing removed."; exit 0; fi
if [ "$FORCE" = "0" ]; then
  printf "\nProceed? [y/N] "; read -r ans || ans=n
  case "$ans" in y|Y|yes) ;; *) echo "Aborted."; exit 0 ;; esac
fi

for rel in "${to_remove[@]}"; do rm -f "${TARGET:?}/$rel"; done
rm -rf "${TARGET:?}/.hook-state"
# Drop directories the kit created, but only once they are empty.
find "$TARGET/.claude" "$TARGET/agent_docs" -depth -type d -empty -delete 2>/dev/null || true
echo ""
echo "Removed."
