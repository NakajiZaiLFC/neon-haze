#!/usr/bin/env bash
# Generate StatusBarComponent icons from crest PNG.
# iTerm2 requires 16x17pt (1x) and 32x34pt (2x) icons.
set -euo pipefail

SRC="${1:-$HOME/.cache/claude-statusline/sprite-widget.png}"
OUT="${2:-$HOME/.claude/crest}"

if ! command -v magick >/dev/null 2>&1; then
  echo "ERROR: ImageMagick not found" >&2; exit 1
fi

mkdir -p "$OUT"

magick "$SRC" -resize 16x17 -background none -gravity center -extent 16x17 "$OUT/icon_16x17.png"
magick "$SRC" -resize 32x34 -background none -gravity center -extent 32x34 "$OUT/icon_32x34.png"

echo "Generated icons:"
ls -la "$OUT"/icon_*.png
file "$OUT"/icon_*.png
