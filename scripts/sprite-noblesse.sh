#!/bin/bash
# Noblesse Emblem - Scales of Justice + Sword
# 20×20 pixel sprite using half-block rendering
RESET="\033[0m"

# Palette
G=(220 170 50)   # gold background
D=(45 22 12)     # dark brown (border/design)
I=(185 140 45)   # inner circle (lighter gold)
S=(60 30 18)     # sword/scales
T=(150 110 35)   # text band area

# 20x20 pixel grid: G=gold, D=dark, I=inner, S=sword, T=textband
read -r -d '' MAP <<'PIXELS'
G G G G G G G D D D D D D G G G G G G G
G G G G G D D D D D D D D D D G G G G G
G G G G D D T T T T T T T T D D G G G G
G G G D D T T T T T T T T T T D D G G G
G G D D T I I I I S I I I I T T D D G G
G D D T I I I I I S I I I I I T D D G G
G D T I I I I D D S D D I I I I T D G G
D D T I I I D I I S I I D I I I T D D D
D T I I I D D I I S I I D D I I I T D D
D T I I I I D I I S I I D I I I I T D D
D T I I I I D D S S S D D I I I I T D D
D T I I I I I D I S I D I I I I I T D D
D D T I I I I I I S I I I I I I T D D D
G D T I I I I I I S I I I I I I T D G G
G D D T I I I I I S I I I I I T D D G G
G G D D T I I I I I I I I I T D D G G G
G G G D D T T T T T T T T T D D G G G G
G G G G D D T T T T T T T T D D G G G G
G G G G G D D D D D D D D D D G G G G G
G G G G G G G D D D D D D G G G G G G G
PIXELS

# Parse palette letter to RGB
get_rgb() {
  case "$1" in
    G) echo "${G[0]} ${G[1]} ${G[2]}" ;;
    D) echo "${D[0]} ${D[1]} ${D[2]}" ;;
    I) echo "${I[0]} ${I[1]} ${I[2]}" ;;
    S) echo "${S[0]} ${S[1]} ${S[2]}" ;;
    T) echo "${T[0]} ${T[1]} ${T[2]}" ;;
    *) echo "0 0 0" ;;
  esac
}

# Read pixel map into arrays
row_idx=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  eval "ROW_${row_idx}=($line)"
  row_idx=$((row_idx + 1))
done <<< "$MAP"

echo ""
echo "⚔️  Noblesse Emblem (20×20 pixels = 20 chars × 10 lines)"
echo ""

# Render pairs of rows
for ((r=0; r<20; r+=2)); do
  printf "  "
  eval "top_row=(\"\${ROW_${r}[@]}\")"
  eval "bot_row=(\"\${ROW_$((r+1))}[@]}\")"
  # re-eval bot
  br=$((r+1))
  eval "bot_row=(\"\${ROW_${br}[@]}\")"

  for ((c=0; c<20; c++)); do
    top_letter="${top_row[$c]}"
    bot_letter="${bot_row[$c]}"
    read tr tg tb <<< "$(get_rgb "$top_letter")"
    read br2 bg bb <<< "$(get_rgb "$bot_letter")"

    if [ "$tr" -eq "$br2" ] && [ "$tg" -eq "$bg" ] && [ "$tb" -eq "$bb" ]; then
      printf "\033[38;2;%d;%d;%dm█" "$tr" "$tg" "$tb"
    else
      printf "\033[38;2;%d;%d;%dm\033[48;2;%d;%d;%dm▀" "$tr" "$tg" "$tb" "$br2" "$bg" "$bb"
    fi
  done
  printf "${RESET}\n"
done

echo ""

# Now render with more detail - 24x24 version with actual scales
echo "⚔️  Noblesse Emblem v2 (24×24 pixels = 24 chars × 12 lines)"
echo ""

read -r -d '' MAP2 <<'PIXELS'
G G G G G G G G D D D D D D D D G G G G G G G G
G G G G G G D D D D D D D D D D D D G G G G G G
G G G G G D D T T T T T T T T T T D D G G G G G
G G G G D D T T T T T T T T T T T T D D G G G G
G G G D D T T I I I I S I I I I T T T D D G G G
G G D D T T I I I I I S I I I I I T T D D G G G
G G D T T I I I I I I S I I I I I I T T D G G G
G D D T I I I I D D D S D D D I I I I T D D G G
D D T I I I I D I I I S I I I D I I I I T D D D
D T T I I I D D I I I S I I I D D I I I T T D D
D T I I I I D I I I I S I I I I D I I I I T D D
D T I I I I D D I I I S I I I D D I I I I T D D
D T I I I I I D D I S S S I D D I I I I I T D D
D T I I I I I I D D I S I D D I I I I I I T D D
D D T I I I I I I I I S I I I I I I I I T D D D
G D T T I I I I I I I S I I I I I I I T T D G G
G G D T T I I I I I I S I I I I I I T T D G G G
G G D D T T I I I I I I I I I I I T T D D G G G
G G G D D T T T I I I I I I I T T T D D G G G G
G G G G D D T T T T T T T T T T T T D D G G G G
G G G G G D D T T T T T T T T T T D D G G G G G
G G G G G G D D D D D D D D D D D D G G G G G G
G G G G G G G G D D D D D D D D G G G G G G G G
G G G G G G G G G G G G G G G G G G G G G G G G
PIXELS

row_idx=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  eval "R2_${row_idx}=($line)"
  row_idx=$((row_idx + 1))
done <<< "$MAP2"

for ((r=0; r<24; r+=2)); do
  printf "  "
  eval "top_row=(\"\${R2_${r}[@]}\")"
  br=$((r+1))
  eval "bot_row=(\"\${R2_${br}[@]}\")"

  for ((c=0; c<24; c++)); do
    top_letter="${top_row[$c]}"
    bot_letter="${bot_row[$c]}"
    read tr tg tb <<< "$(get_rgb "$top_letter")"
    read br2 bg bb <<< "$(get_rgb "$bot_letter")"

    if [ "$tr" -eq "$br2" ] && [ "$tg" -eq "$bg" ] && [ "$tb" -eq "$bb" ]; then
      printf "\033[38;2;%d;%d;%dm█" "$tr" "$tg" "$tb"
    else
      printf "\033[38;2;%d;%d;%dm\033[48;2;%d;%d;%dm▀" "$tr" "$tg" "$tb" "$br2" "$bg" "$bb"
    fi
  done
  printf "${RESET}\n"
done

echo ""
