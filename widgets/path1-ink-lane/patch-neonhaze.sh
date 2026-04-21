#!/usr/bin/env bash
# Patch instructions for neonhaze.sh to use Ink-lane widget (Path 1)
#
# This replaces the async_inject signal block with direct Half-block rendering
# through Ink's stdout pipeline (BSU/ESU wrapped = flicker-free).
#
# The patch modifies the sprite rendering section:
#   OLD: writes signal JSON for crest_injector.py daemon
#   NEW: renders Half-block ANSI frames inline in the statusline output
#
# To apply: source this file, then call patch_statusline_for_ink_lane
# To test:  ./patch-neonhaze.sh --dry-run

set -euo pipefail

NEONHAZE="${1:-/Users/nassy/projects/neon-haze/neonhaze.sh}"
CREST_DIR="${HOME}/.claude/crest/frames"

show_diff() {
  echo "=== Ink-lane Patch for neonhaze.sh ==="
  echo ""
  echo "1. Replace async_inject signal block (lines ~948-968) with:"
  echo ""
  cat <<'PATCH'
  # Ink-lane crest widget: render Half-block ANSI via stdout (flicker-free)
  # Goes through Ink's BSU/ESU pipeline, no async_inject needed
  if [ "$_has_sprite" -eq 1 ] && [ "$_use_inject" -eq 1 ]; then
    _CREST_DIR="${HOME}/.claude/crest/frames"
    if [ -d "$_CREST_DIR" ]; then
      _crest_idx=$(( $(date +%s) % 72 ))
      _crest_file="$_CREST_DIR/$(printf '%03d' "$_crest_idx").ansi"
      [ ! -f "$_crest_file" ] && _crest_file="$_CREST_DIR/static.ansi"
      if [ -f "$_crest_file" ]; then
        # Read crest lines into array
        _crest_lines=()
        while IFS= read -r _cl; do
          _crest_lines+=("$_cl")
        done < "$_crest_file"
        # Output crest lines (they'll be part of Ink's BSU-wrapped frame)
        for _cl in "${_crest_lines[@]}"; do
          printf "%s\n" "$_cl"
        done
      fi
    fi
  fi
PATCH
  echo ""
  echo "2. The _use_inject flag now means 'use Ink-lane crest' instead of 'signal daemon'"
  echo "3. crest_injector.py daemon is no longer needed for basic crest display"
  echo "4. For animation: refreshInterval=1 in settings.json makes this 1fps automatically"
}

if [ "${1:-}" = "--dry-run" ]; then
  show_diff
  exit 0
fi

show_diff
