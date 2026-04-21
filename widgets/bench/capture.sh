#!/usr/bin/env bash
# Screen capture helper for flicker benchmarking.
# Records iTerm2 window at 60fps for analysis.
#
# Usage:
#   ./capture.sh [duration_sec] [output_file]
#   ./capture.sh 15 path2_pattern10.mkv
set -euo pipefail

DURATION="${1:-15}"
OUTPUT="${2:-capture_$(date +%Y%m%d_%H%M%S).mkv}"

# Position iTerm2 window consistently
osascript -e 'tell application "iTerm2" to activate' 2>/dev/null || true
sleep 0.5

# Get iTerm2 window ID for targeted capture
WINDOW_ID=$(osascript -e '
tell application "System Events"
  tell process "iTerm2"
    set wid to id of front window
    return wid
  end tell
end tell
' 2>/dev/null || echo "")

echo "=== Screen Capture ==="
echo "  Duration: ${DURATION}s"
echo "  Output:   ${OUTPUT}"
echo "  Window:   ${WINDOW_ID:-full screen}"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ERROR: ffmpeg not found. brew install ffmpeg" >&2
  exit 1
fi

echo "  Starting in 3s..."
sleep 3

# Record using avfoundation (macOS screen capture)
# Device "1:" is typically the main screen
echo "  Recording..."
ffmpeg -y -f avfoundation -capture_cursor 0 -framerate 60 -i "1:" \
  -t "$DURATION" \
  -c:v libx264 -preset ultrafast -qp 0 -pix_fmt yuv420p \
  "$OUTPUT" 2>/dev/null

echo "  Done: $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
echo ""
echo "Analyze with:"
echo "  python3 widgets/bench/flicker_analyze.py '$OUTPUT' --csv results.csv"
echo ""
echo "Crop to prompt region (adjust coordinates for your setup):"
echo "  python3 widgets/bench/flicker_analyze.py '$OUTPUT' --crop 200,1400,1600,120"
