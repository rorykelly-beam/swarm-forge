#!/usr/bin/env bash
#
# remove-swarmforge.sh — remove the SwarmForge files from a target folder.
#
# Usage:
#   ./remove-swarmforge.sh <target-dir> [--clean-gitignore] [--force]
#
# Removes everything copy-swarmforge.sh seeds plus the runtime files `swarm`
# creates, so you can re-seed the folder from a different SwarmForge branch:
#   swarm                   (launcher)
#   swarmforge/             (config, constitution, roles, downloaded scripts)
#   .swarmforge/            (runtime state)
#   .worktrees/             (agent worktrees)
# The SwarmForge entries this tool added to the target's .gitignore are kept
# by default (they stay valid across branches); pass --clean-gitignore to
# strip them too.
#
# Options:
#   --clean-gitignore  also remove the SwarmForge entries from .gitignore.
#   --force            skip the confirmation prompt.
#
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLEAN_GITIGNORE=0
FORCE=0
TARGET=""

usage() {
  sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

for arg in "$@"; do
  case "$arg" in
    --clean-gitignore) CLEAN_GITIGNORE=1 ;;
    --force)           FORCE=1 ;;
    -h|--help)        usage 0 ;;
    -*)               echo "Error: unknown option '$arg'" >&2; usage 1 ;;
    *)
      if [[ -n "$TARGET" ]]; then
        echo "Error: multiple target dirs given ('$TARGET' and '$arg')" >&2
        usage 1
      fi
      TARGET="$arg"
      ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "Error: no target directory provided." >&2
  usage 1
fi

if [[ ! -d "$TARGET" ]]; then
  echo "Error: target directory '$TARGET' does not exist." >&2
  exit 1
fi

TARGET="$(cd "$TARGET" && pwd)"

if [[ "$TARGET" == "$SOURCE_DIR" ]]; then
  echo "Error: target is the SwarmForge source directory itself; refusing to remove it." >&2
  exit 1
fi

# Paths copy-swarmforge.sh installs plus the runtime dirs `swarm` creates.
REMOVABLE=(
  "swarm"
  "swarmforge"
  ".swarmforge"
  ".worktrees"
)

# Figure out what's actually present so we only report / delete real files.
present=()
for rel in "${REMOVABLE[@]}"; do
  [[ -e "$TARGET/$rel" ]] && present+=("$rel")
done

GITIGNORE_ENTRIES=(
  ".swarmforge/"
  ".worktrees/"
  "swarmforge/scripts/"
)
gitignore_file="$TARGET/.gitignore"

if [[ "${#present[@]}" -eq 0 ]]; then
  echo "Nothing to remove: no SwarmForge files found in $TARGET"
  exit 0
fi

echo "About to remove SwarmForge from: $TARGET"
for rel in "${present[@]}"; do
  echo "  - $rel"
done
[[ "$CLEAN_GITIGNORE" -eq 1 && -f "$gitignore_file" ]] && \
  echo "  - .gitignore: SwarmForge entries (if present)"

if [[ "$FORCE" -eq 0 ]]; then
  read -r -p "Proceed? [y/N] " reply
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

for rel in "${present[@]}"; do
  rm -rf "$TARGET/$rel"
  echo "  x $rel"
done

# Strip the SwarmForge entries this tool added to the target's .gitignore.
if [[ "$CLEAN_GITIGNORE" -eq 1 && -f "$gitignore_file" ]]; then
  removed=0
  for entry in "${GITIGNORE_ENTRIES[@]}"; do
    if grep -qxF "$entry" "$gitignore_file"; then
      tmp="$(mktemp)"
      grep -vxF "$entry" "$gitignore_file" > "$tmp"
      mv "$tmp" "$gitignore_file"
      echo "  x .gitignore: removed '$entry'"
      removed=1
    fi
  done
  # Drop the .gitignore entirely if we emptied it out.
  if [[ ! -s "$gitignore_file" ]]; then
    rm -f "$gitignore_file"
    echo "  x .gitignore (now empty, removed)"
  elif [[ "$removed" -eq 0 ]]; then
    echo "  = .gitignore: no SwarmForge entries to remove"
  fi
fi

echo "Done. $TARGET no longer contains SwarmForge."
echo "Re-seed from another branch with:"
echo "  ./copy-swarmforge.sh \"$TARGET\""
