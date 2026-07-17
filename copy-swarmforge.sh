#!/usr/bin/env bash
#
# copy-swarmforge.sh — copy the files required to run SwarmForge into a target folder.
#
# Usage:
#   ./copy-swarmforge.sh <target-dir> [--with-scripts] [--force]
#
# Seeds <target-dir> with everything `./swarm` needs to run there:
#   swarm                              (launcher)
#   swarmforge/swarmforge.conf         (window/agent config)
#   swarmforge/constitution.prompt     (constitution entrypoint)
#   swarmforge/constitution/articles/  (constitution articles)
#   swarmforge/roles/                  (agent role prompts)
#
# The swarmforge/scripts/ directory is auto-downloaded by `swarm` on first run.
# Pass --with-scripts to copy a local scripts/ (if present) so the target works
# offline / without a network fetch.
#
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WITH_SCRIPTS=0
FORCE=0
TARGET=""

usage() {
  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

for arg in "$@"; do
  case "$arg" in
    --with-scripts) WITH_SCRIPTS=1 ;;
    --force)        FORCE=1 ;;
    -h|--help)      usage 0 ;;
    -*)             echo "Error: unknown option '$arg'" >&2; usage 1 ;;
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

# Required source pieces — bail early if the source tree is incomplete.
REQUIRED=(
  "swarm"
  "swarmforge/swarmforge.conf"
  "swarmforge/constitution.prompt"
  "swarmforge/constitution/articles"
  "swarmforge/roles"
)
for item in "${REQUIRED[@]}"; do
  if [[ ! -e "$SOURCE_DIR/$item" ]]; then
    echo "Error: required source '$item' not found in $SOURCE_DIR" >&2
    exit 1
  fi
done

mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"

if [[ "$TARGET" == "$SOURCE_DIR" ]]; then
  echo "Error: target is the SwarmForge source directory itself." >&2
  exit 1
fi

# Guard against clobbering an existing install unless --force.
if [[ "$FORCE" -eq 0 && -e "$TARGET/swarmforge" ]]; then
  echo "Error: '$TARGET/swarmforge' already exists. Re-run with --force to overwrite." >&2
  exit 1
fi

copy() {  # copy <relative-path>
  local rel="$1"
  local dest="$TARGET/$rel"
  mkdir -p "$(dirname "$dest")"
  cp -R "$SOURCE_DIR/$rel" "$dest"
  echo "  + $rel"
}

echo "Copying SwarmForge files into: $TARGET"
copy "swarm"
copy "swarmforge/swarmforge.conf"
copy "swarmforge/constitution.prompt"
copy "swarmforge/constitution/articles"
copy "swarmforge/roles"

if [[ "$WITH_SCRIPTS" -eq 1 ]]; then
  if [[ -d "$SOURCE_DIR/swarmforge/scripts" ]]; then
    copy "swarmforge/scripts"
  else
    echo "  ! --with-scripts requested but $SOURCE_DIR/swarmforge/scripts not present; skipping (it will auto-download on first run)"
  fi
fi

chmod +x "$TARGET/swarm" 2>/dev/null || true

# Ensure the target .gitignore ignores SwarmForge's runtime/downloaded files.
GITIGNORE_ENTRIES=(
  ".swarmforge/"
  ".worktrees/"
  "swarmforge/scripts/"
)
gitignore_file="$TARGET/.gitignore"
if [[ ! -f "$gitignore_file" ]]; then
  printf '%s\n' "${GITIGNORE_ENTRIES[@]}" > "$gitignore_file"
  echo "  + .gitignore (created with SwarmForge entries)"
else
  added=0
  for entry in "${GITIGNORE_ENTRIES[@]}"; do
    if ! grep -qxF "$entry" "$gitignore_file"; then
      # Make sure we start on a new line before appending.
      [[ -s "$gitignore_file" && -n "$(tail -c1 "$gitignore_file")" ]] && echo >> "$gitignore_file"
      echo "$entry" >> "$gitignore_file"
      echo "  + .gitignore: added '$entry'"
      added=1
    fi
  done
  [[ "$added" -eq 0 ]] && echo "  = .gitignore: SwarmForge entries already present"
fi

echo "Done. Run SwarmForge with:"
echo "  cd \"$TARGET\" && ./swarm"
