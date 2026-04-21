#!/usr/bin/env bash
# Generate rotated Half-block ANSI frames from crest PNG.
# Requires: chafa (brew install chafa), ImageMagick (brew install imagemagick)
# Usage: ./build-frames.sh [source.png] [output_dir] [frame_count] [cols x rows]
set -euo pipefail

SRC="${1:-$HOME/.cache/claude-statusline/sprite-widget.png}"
OUT="${2:-$HOME/.claude/crest/frames}"
FRAMES="${3:-72}"
SIZE="${4:-20x10}"

if ! command -v chafa >/dev/null 2>&1; then
  echo "ERROR: chafa not found. brew install chafa" >&2; exit 1
fi
if ! command -v magick >/dev/null 2>&1; then
  echo "ERROR: ImageMagick not found. brew install imagemagick" >&2; exit 1
fi
if [ ! -f "$SRC" ]; then
  echo "ERROR: Source image not found: $SRC" >&2; exit 1
fi

mkdir -p "$OUT"

DEG_STEP=$(( 360 / FRAMES ))
echo "Generating $FRAMES frames (${DEG_STEP}°/frame) from $SRC → $OUT"
echo "chafa size: $SIZE"

for i in $(seq 0 $((FRAMES - 1))); do
  deg=$(( i * DEG_STEP ))
  out_file="$OUT/$(printf '%03d' "$i").ansi"
  magick "$SRC" -background none -rotate "$deg" \
    -trim +repage -resize "${SIZE%%x*}x$((${SIZE##*x} * 2))" png:- \
    | chafa -f symbols --symbols half --size "$SIZE" -c full - \
    > "$out_file"
  printf "\r  frame %03d/%03d (%3d°)" "$((i+1))" "$FRAMES" "$deg"
done
echo ""

# Also generate a static frame (no rotation) for comparison
magick "$SRC" -resize "${SIZE%%x*}x$((${SIZE##*x} * 2))" png:- \
  | chafa -f symbols --symbols half --size "$SIZE" -c full - \
  > "$OUT/static.ansi"

COUNT=$(ls "$OUT"/*.ansi 2>/dev/null | wc -l | tr -d ' ')
echo "Done: $COUNT files in $OUT"
echo "Static frame: $OUT/static.ansi"

# Preview static frame
echo "--- Preview (static.ansi) ---"
cat "$OUT/static.ansi"
