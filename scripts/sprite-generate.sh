#!/bin/bash
# Pre-generate sprite frames as sixel data for statusline embedding
# Usage: sprite-generate.sh [sprite_name] [frame_count]
SPRITE="${1:-noblesse}"
FRAMES="${2:-1}"
SPRITE_DIR="$HOME/.cache/claude-statusline/sprites"
mkdir -p "$SPRITE_DIR"

case "$SPRITE" in
  noblesse)
    python3 "$(dirname "$0")/emblem-layered.py" frames 2>/dev/null
    # Convert frames to sixel text files
    for f in /tmp/noblesse_frames/frame_*.png; do
      base=$(basename "$f" .png)
      img2sixel -w 120 "$f" > "$SPRITE_DIR/${base}.sixel" 2>/dev/null
    done
    echo "$FRAMES" > "$SPRITE_DIR/frame_count"
    echo "noblesse" > "$SPRITE_DIR/current_sprite"
    echo "Generated $(ls "$SPRITE_DIR"/*.sixel 2>/dev/null | wc -l | tr -d ' ') sixel frames"
    ;;
  static)
    python3 "$(dirname "$0")/emblem-layered.py" static 2>/dev/null
    img2sixel -w 120 /tmp/emblem_final.png > "$SPRITE_DIR/frame_00.sixel" 2>/dev/null
    echo "1" > "$SPRITE_DIR/frame_count"
    echo "noblesse" > "$SPRITE_DIR/current_sprite"
    echo "Generated static sprite"
    ;;
esac
