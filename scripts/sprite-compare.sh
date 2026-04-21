#!/bin/bash
# Compare different rendering methods for pixel art in terminal
IMG="${1:-/Users/nassy/.claude/image-cache/95743819-5921-4fee-a7b4-2b7152b28f92/3.png}"

echo ""
echo "========================================="
echo " Rendering Method Comparison"
echo "========================================="
echo ""

# Force chafa to use symbols mode (not iTerm2 inline images)
export TERM_PROGRAM=""

# --- Method 1: Half-block ---
echo "【1】Half-block (▀) + 24-bit color  [1文字=1×2px, フルカラー]"
echo ""
echo "  20 chars:                30 chars:"
paste <(chafa -f symbols --symbols block --colors full --size 20 "$IMG" 2>/dev/null) \
      <(chafa -f symbols --symbols block --colors full --size 30 "$IMG" 2>/dev/null) \
  2>/dev/null || {
    echo "  20 chars:"
    chafa -f symbols --symbols block --colors full --size 20 "$IMG" 2>/dev/null
    echo ""
    echo "  30 chars:"
    chafa -f symbols --symbols block --colors full --size 30 "$IMG" 2>/dev/null
  }
echo ""

# --- Method 2: Braille ---
echo "【2】Braille  [1文字=2×4ドット, ドット感]"
echo ""
echo "  20 chars:"
chafa -f symbols --symbols braille --colors full --size 20 "$IMG" 2>/dev/null
echo ""
echo "  30 chars:"
chafa -f symbols --symbols braille --colors full --size 30 "$IMG" 2>/dev/null
echo ""

# --- Method 3: All symbols mixed ---
echo "【3】Block + Braille mixed  [chafa自動選択]"
echo ""
echo "  20 chars:"
chafa -f symbols --symbols all --colors full --size 20 "$IMG" 2>/dev/null
echo ""
echo "  30 chars:"
chafa -f symbols --symbols all --colors full --size 30 "$IMG" 2>/dev/null
echo ""

# --- Method 4: Sixel ---
echo "【4】Sixel  [本物のピクセル, 対応ターミナルのみ]"
echo ""
echo "  150px:"
img2sixel -w 150 "$IMG" 2>/dev/null
echo ""
echo "  250px:"
img2sixel -w 250 "$IMG" 2>/dev/null
echo ""

# --- Method 5: 256 color fallback ---
echo "【5】Half-block + 256色  [互換性重視]"
echo ""
chafa -f symbols --symbols block --colors 256 --size 20 "$IMG" 2>/dev/null
echo ""

echo "========================================="
echo " NeonHaze配置サイズの目安:"
echo "  天気 box  = ~38文字 × 3行"
echo "  ポモ box  = ~38文字 × 3行"
echo "  スプライト = 12-20文字 × 6-10行 が理想"
echo "========================================="
