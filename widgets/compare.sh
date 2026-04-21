#!/usr/bin/env bash
# Flicker-free widget comparison runner.
#
# Runs each path and provides instructions for visual comparison.
# Screen capture + flicker analysis for quantitative results.
#
# Usage:
#   ./compare.sh path1        # Test Ink-lane Half-block
#   ./compare.sh path2 [N]    # Test BSU inject pattern N (1-11, default: all)
#   ./compare.sh path3        # Test StatusBarComponent
#   ./compare.sh frames       # Regenerate Half-block frames
#   ./compare.sh deps         # Check/install dependencies
#   ./compare.sh all          # Run all paths sequentially
set -euo pipefail

WIDGETS_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$WIDGETS_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { printf "${CYAN}[info]${NC}  %s\n" "$*"; }
ok()    { printf "${GREEN}[ok]${NC}    %s\n" "$*"; }
warn()  { printf "${YELLOW}[warn]${NC}  %s\n" "$*"; }
fail()  { printf "${RED}[fail]${NC}  %s\n" "$*"; }

check_deps() {
  local missing=0
  for cmd in chafa magick python3; do
    if command -v "$cmd" >/dev/null 2>&1; then
      ok "$cmd: $(command -v $cmd)"
    else
      fail "$cmd: not found"
      missing=1
    fi
  done

  python3 -c "import iterm2" 2>/dev/null && ok "iterm2 python module" || { fail "iterm2: pip install iterm2"; missing=1; }
  python3 -c "import cv2" 2>/dev/null && ok "opencv-python" || warn "opencv-python: pip install opencv-python (optional, for flicker analysis)"
  python3 -c "from skimage.metrics import structural_similarity" 2>/dev/null && ok "scikit-image" || warn "scikit-image: pip install scikit-image (optional, for flicker analysis)"
  python3 -c "from PIL import Image" 2>/dev/null && ok "Pillow" || warn "Pillow: pip install Pillow (optional, for BSU experiment)"

  if [ -f "$HOME/.cache/claude-statusline/sprite-widget.png" ]; then
    ok "crest PNG: ~/.cache/claude-statusline/sprite-widget.png"
  else
    fail "crest PNG not found"
    missing=1
  fi

  if [ -d "$HOME/.claude/crest/frames" ]; then
    local count=$(ls "$HOME/.claude/crest/frames"/*.ansi 2>/dev/null | wc -l | tr -d ' ')
    ok "Half-block frames: $count files"
  else
    warn "Half-block frames not generated. Run: ./compare.sh frames"
  fi

  return $missing
}

run_path1() {
  info "=== Path 1: Ink-lane Half-block Widget ==="
  info "This renders Half-block ANSI via stdout (Ink BSU/ESU pipeline)"
  info ""

  if [ ! -d "$HOME/.claude/crest/frames" ]; then
    warn "Frames not generated. Generating now..."
    bash path1-ink-lane/build-frames.sh
  fi

  info "Static frame preview:"
  cat "$HOME/.claude/crest/frames/static.ansi"
  echo ""

  info "Animated preview (5 frames at 1fps):"
  for i in $(seq 0 4); do
    local idx=$(( ($(date +%s) + i) % 72 ))
    local f="$HOME/.claude/crest/frames/$(printf '%03d' $idx).ansi"
    [ -f "$f" ] && cat "$f"
    echo "  --- frame $idx ---"
    [ "$i" -lt 4 ] && sleep 1
  done

  echo ""
  info "Integration: Add the following to neonhaze.sh (replaces async_inject signal block):"
  info "  See: widgets/path1-ink-lane/patch-neonhaze.sh --dry-run"
  echo ""
  ok "Path 1 demo complete"
  info "Expected result: ZERO flicker (stdout goes through Ink BSU/ESU)"
}

run_path2() {
  local pattern="${1:-interactive}"
  info "=== Path 2: BSU-wrapped async_inject Experiment ==="
  info "Pattern: $pattern"
  info ""

  python3 -c "import iterm2" 2>/dev/null || { fail "iterm2 module not installed"; return 1; }

  if [ "$pattern" = "rotate" ]; then
    info "Running rotation patterns (12-17) — 15s each"
    info "  12: BSU + rotate 5°/f @ 1Hz"
    info "  13: BSU + rotate 5°/f @ 2Hz"
    info "  14: BSU + rotate 5°/f @ 5Hz"
    info "  15: rotate NO BSU @ 1Hz (flicker control)"
    info "  16: BSU + rotate 15°/f @ 1Hz (fast spin)"
    info "  17: BSU + rotate 5°/f @ 10Hz (stress test)"
  fi

  info "Launching experiment (connects to iTerm2 Python API)..."
  python3 path2-bsu-inject/bsu_experiment.py "$pattern"
  echo ""
  ok "Path 2 experiment complete"
}

run_path3() {
  info "=== Path 3: iTerm2 StatusBarComponent ==="
  info ""

  python3 -c "import iterm2" 2>/dev/null || { fail "iterm2 module not installed"; return 1; }

  if [ ! -f "$HOME/.claude/crest/icon_16x17.png" ]; then
    info "Generating icons..."
    bash path3-statusbar/generate-icons.sh
  fi

  info "StatusBarComponent registration:"
  info "  1. The script registers com.neonhaze.crest.statusbar"
  info "  2. Go to iTerm2 → Preferences → Profiles → Session → Configure Status Bar"
  info "  3. Drag 'NeonHaze Crest' into the status bar"
  info ""
  info "Starting component (Ctrl+C to stop)..."
  python3 path3-statusbar/crest_statusbar.py &
  local pid=$!

  sleep 3
  info "Pushing state changes for demo..."
  for state in thinking streaming working idle; do
    info "  state → $state"
    python3 path3-statusbar/push_state.py "$state" 2>/dev/null || true
    sleep 3
  done

  kill "$pid" 2>/dev/null || true
  echo ""
  ok "Path 3 demo complete"
  info "Expected result: ZERO flicker (iTerm2 native AppKit rendering)"
}

run_all() {
  info "=== Running all paths ==="
  echo ""
  run_path1
  echo ""
  echo "---"
  echo ""
  run_path2 "interactive"
  echo ""
  echo "---"
  echo ""
  run_path3
  echo ""
  info "=== Comparison Summary ==="
  echo ""
  printf "  %-25s %-12s %-12s %-15s\n" "Path" "Flicker" "Resolution" "Integration"
  printf "  %-25s %-12s %-12s %-15s\n" "------------------------" "----------" "----------" "-------------"
  printf "  %-25s %-12s %-12s %-15s\n" "1. Ink-lane Half-block"  "ZERO"       "~40x20 cells" "stdout patch"
  printf "  %-25s %-12s %-12s %-15s\n" "2. BSU async_inject"     "reduced"    "144x144 PNG"  "daemon + BSU"
  printf "  %-25s %-12s %-12s %-15s\n" "3. StatusBarComponent"   "ZERO"       "icon + text"  "iTerm2 native"
  echo ""
  info "Recommendation: Path 1 (primary) + Path 3 (secondary)"
}

case "${1:-help}" in
  path1|1)   run_path1 ;;
  path2|2)   run_path2 "${2:-interactive}" ;;
  path3|3)   run_path3 ;;
  frames)    bash path1-ink-lane/build-frames.sh ;;
  deps)      check_deps ;;
  all)       run_all ;;
  help|*)
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  path1, 1       Test Ink-lane Half-block (flicker-free)"
    echo "  path2, 2 [N]   Test BSU inject experiment (pattern 1-11)"
    echo "  path3, 3       Test StatusBarComponent (flicker-free)"
    echo "  frames         Regenerate Half-block ANSI frames"
    echo "  deps           Check dependencies"
    echo "  all            Run all paths"
    echo ""
    echo "Bench:"
    echo "  bash bench/capture.sh 15 output.mkv"
    echo "  python3 bench/flicker_analyze.py output.mkv --csv results.csv"
    ;;
esac
