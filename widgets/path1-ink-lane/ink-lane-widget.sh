#!/usr/bin/env bash
# Path 1: Ink-lane Half-block widget — flicker-free crest rendering
#
# This script is sourced by neonhaze.sh (or run standalone for testing).
# It renders pre-generated Half-block ANSI frames via stdout, which means
# Ink wraps the output in BSU/ESU (Synchronized Output) → zero flicker.
#
# Modes:
#   animate  — rotate through 72 frames at 1fps (unix time % 72)
#   static   — always show frame 000 (no rotation)
#
# Usage (standalone test):
#   CREST_MODE=animate ./ink-lane-widget.sh
#   CREST_MODE=static  ./ink-lane-widget.sh

CREST_MODE="${CREST_MODE:-animate}"
CREST_DIR="${CREST_DIR:-$HOME/.claude/crest/frames}"

ink_lane_render() {
  local mode="${1:-$CREST_MODE}"
  local frames_dir="${2:-$CREST_DIR}"

  if [ ! -d "$frames_dir" ]; then
    return 1
  fi

  local frame_file
  case "$mode" in
    animate)
      local idx=$(( $(date +%s) % 72 ))
      frame_file="$frames_dir/$(printf '%03d' "$idx").ansi"
      ;;
    static)
      frame_file="$frames_dir/static.ansi"
      [ ! -f "$frame_file" ] && frame_file="$frames_dir/000.ansi"
      ;;
    *)
      frame_file="$frames_dir/static.ansi"
      ;;
  esac

  if [ -f "$frame_file" ]; then
    cat "$frame_file"
    return 0
  fi
  return 1
}

# Standalone test mode
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "=== Path 1: Ink-lane Half-block Widget ==="
  echo "Mode: $CREST_MODE"
  echo "Frames dir: $CREST_DIR"
  echo ""
  ink_lane_render "$CREST_MODE" "$CREST_DIR"
  echo ""
  echo "Frame lines: $(ink_lane_render "$CREST_MODE" "$CREST_DIR" | wc -l | tr -d ' ')"

  if [ "$CREST_MODE" = "animate" ]; then
    echo ""
    echo "=== Animation preview (5 seconds) ==="
    for i in $(seq 1 5); do
      printf "\033[11A"  # move up 10 lines + 1 header
      ink_lane_render animate "$CREST_DIR"
      echo "  frame $(( $(date +%s) % 72 ))  (t=$i)"
      sleep 1
    done
  fi
fi
