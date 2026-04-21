#!/bin/bash
# Sprite rendering test using half-block (▀) + 24-bit color
# Each cell = 2 vertical pixels (top=fg, bottom=bg)

RESET="\033[0m"
_=0  # transparent (no draw)

# 24-bit color helper: fg(top pixel) + bg(bottom pixel) + ▀
px() {
  local tr="$1" tg="$2" tb="$3"  # top pixel RGB
  local br="$4" bg="$5" bb="$6"  # bottom pixel RGB
  if [ "$tr" -eq 0 ] && [ "$tg" -eq 0 ] && [ "$tb" -eq 0 ] && \
     [ "$br" -eq 0 ] && [ "$bg" -eq 0 ] && [ "$bb" -eq 0 ]; then
    printf " "
  elif [ "$tr" -eq "$br" ] && [ "$tg" -eq "$bg" ] && [ "$tb" -eq "$bb" ]; then
    printf "\033[38;2;%d;%d;%dm█%s" "$tr" "$tg" "$tb" ""
  else
    printf "\033[38;2;%d;%d;%dm\033[48;2;%d;%d;%dm▀" "$tr" "$tg" "$tb" "$br" "$bg" "$bb"
  fi
}

# Render a sprite from pixel array
# Each row = sequence of (R G B) triplets
# Rows are processed in pairs (top row + bottom row → one terminal line)
render_sprite() {
  local -n rows_ref=$1
  local h=${#rows_ref[@]}
  local row=0
  while [ "$row" -lt "$h" ]; do
    local -n top_row="${rows_ref[$row]}"
    local bot_row_name="${rows_ref[$((row+1))]}"
    local -n bot_row="$bot_row_name"
    local w=$(( ${#top_row[@]} / 3 ))
    for ((col=0; col<w; col++)); do
      local i=$((col*3))
      local tr=${top_row[$i]} tg=${top_row[$((i+1))]} tb=${top_row[$((i+2))]}
      local br=${bot_row[$i]} bg=${bot_row[$((i+1))]} bb=${bot_row[$((i+2))]}
      px "$tr" "$tg" "$tb" "$br" "$bg" "$bb"
    done
    printf "${RESET}\n"
    row=$((row+2))
  done
}

echo ""
echo "=== Sprite Test: Half-block (▀) + 24-bit Color ==="
echo ""

# --- Simple heart (8x8) ---
echo "♥ Heart (8×8 pixels = 8 chars × 4 lines):"
# Colors
R_R=220 R_G=40 R_B=60    # red
BG_R=0 BG_G=0 BG_B=0     # black bg

for row in $(seq 0 7); do
  case $row in
    0) pixels=(0 0 0  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  0 0 0  0 0 0  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  0 0 0) ;;
    1) pixels=("$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B") ;;
    2) pixels=("$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B") ;;
    3) pixels=("$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B") ;;
    4) pixels=(0 0 0  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  0 0 0) ;;
    5) pixels=(0 0 0  0 0 0  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  0 0 0  0 0 0) ;;
    6) pixels=(0 0 0  0 0 0  0 0 0  "$R_R" "$R_G" "$R_B"  "$R_R" "$R_G" "$R_B"  0 0 0  0 0 0  0 0 0) ;;
    7) pixels=(0 0 0  0 0 0  0 0 0  0 0 0  0 0 0  0 0 0  0 0 0  0 0 0) ;;
  esac
  rows[$row]="pixels_h_$row"
  eval "pixels_h_$row=(\"\${pixels[@]}\")"
done

row=0
while [ "$row" -lt 8 ]; do
  local_top="pixels_h_$row"
  local_bot="pixels_h_$((row+1))"
  eval "top_arr=(\"\${${local_top}[@]}\")"
  eval "bot_arr=(\"\${${local_bot}[@]}\")"
  printf "  "
  for ((col=0; col<8; col++)); do
    i=$((col*3))
    px "${top_arr[$i]}" "${top_arr[$((i+1))]}" "${top_arr[$((i+2))]}" \
       "${bot_arr[$i]}" "${bot_arr[$((i+1))]}" "${bot_arr[$((i+2))]}"
  done
  printf "${RESET}\n"
  row=$((row+2))
done

echo ""

# --- Soccer player sprite (カルチョビット風, 10x14) ---
echo "⚽ Soccer player (10×14 pixels = 10 chars × 7 lines):"

# Palette
SK_R=200 SK_G=140 SK_B=90   # skin
HR_R=40  HR_G=30  HR_B=20   # hair
SH_R=255 SH_G=80  SH_B=120  # shirt (pink)
PT_R=255 PT_G=80  PT_B=120  # pants
SO_R=255 SO_G=255 SO_B=255  # socks
BT_R=40  BT_G=40  BT_B=40   # boots
BL_R=255 BL_G=255 BL_B=255  # ball
X_R=0 X_G=0 X_B=0           # empty

declare -a sp_rows
# Row 0-1: hair
sp_rows[0]="$X_R $X_G $X_B  $X_R $X_G $X_B  $X_R $X_G $X_B  $HR_R $HR_G $HR_B  $HR_R $HR_G $HR_B  $HR_R $HR_G $HR_B  $HR_R $HR_G $HR_B  $X_R $X_G $X_B  $X_R $X_G $X_B  $X_R $X_G $X_B"
sp_rows[1]="$X_R $X_G $X_B  $X_R $X_G $X_B  $HR_R $HR_G $HR_B  $HR_R $HR_G $HR_B  $HR_R $HR_G $HR_B  $HR_R $HR_G $HR_B  $HR_R $HR_G $HR_B  $HR_R $HR_G $HR_B  $X_R $X_G $X_B  $X_R $X_G $X_B"
# Row 2-3: face
sp_rows[2]="$X_R $X_G $X_B  $X_R $X_G $X_B  $SK_R $SK_G $SK_B  $SK_R $SK_G $SK_B  $SK_R $SK_G $SK_B  $SK_R $SK_G $SK_B  $SK_R $SK_G $SK_B  $SK_R $SK_G $SK_B  $X_R $X_G $X_B  $X_R $X_G $X_B"
sp_rows[3]="$X_R $X_G $X_B  $X_R $X_G $X_B  $SK_R $SK_G $SK_B  $X_R $X_G $X_B  $SK_R $SK_G $SK_B  $SK_R $SK_G $SK_B  $X_R $X_G $X_B  $SK_R $SK_G $SK_B  $X_R $X_G $X_B  $X_R $X_G $X_B"
# Row 4-5: body
sp_rows[4]="$X_R $X_G $X_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $X_R $X_G $X_B"
sp_rows[5]="$X_R $X_G $X_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $X_R $X_G $X_B"
# Row 6-7: arms + body
sp_rows[6]="$SK_R $SK_G $SK_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SK_R $SK_G $SK_B"
sp_rows[7]="$SK_R $SK_G $SK_B  $X_R $X_G $X_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $SH_R $SH_G $SH_B  $X_R $X_G $X_B  $BL_R $BL_G $BL_B"
# Row 8-9: pants
sp_rows[8]="$X_R $X_G $X_B  $X_R $X_G $X_B  $PT_R $PT_G $PT_B  $PT_R $PT_G $PT_B  $PT_R $PT_G $PT_B  $PT_R $PT_G $PT_B  $PT_R $PT_G $PT_B  $PT_R $PT_G $PT_B  $X_R $X_G $X_B  $BL_R $BL_G $BL_B"
sp_rows[9]="$X_R $X_G $X_B  $X_R $X_G $X_B  $PT_R $PT_G $PT_B  $PT_R $PT_G $PT_B  $X_R $X_G $X_B  $X_R $X_G $X_B  $PT_R $PT_G $PT_B  $PT_R $PT_G $PT_B  $X_R $X_G $X_B  $X_R $X_G $X_B"
# Row 10-11: legs
sp_rows[10]="$X_R $X_G $X_B  $X_R $X_G $X_B  $SO_R $SO_G $SO_B  $SO_R $SO_G $SO_B  $X_R $X_G $X_B  $X_R $X_G $X_B  $SO_R $SO_G $SO_B  $SO_R $SO_G $SO_B  $X_R $X_G $X_B  $X_R $X_G $X_B"
sp_rows[11]="$X_R $X_G $X_B  $X_R $X_G $X_B  $SO_R $SO_G $SO_B  $SO_R $SO_G $SO_B  $X_R $X_G $X_B  $X_R $X_G $X_B  $SO_R $SO_G $SO_B  $SO_R $SO_G $SO_B  $X_R $X_G $X_B  $X_R $X_G $X_B"
# Row 12-13: boots
sp_rows[12]="$X_R $X_G $X_B  $BT_R $BT_G $BT_B  $BT_R $BT_G $BT_B  $BT_R $BT_G $BT_B  $X_R $X_G $X_B  $X_R $X_G $X_B  $BT_R $BT_G $BT_B  $BT_R $BT_G $BT_B  $BT_R $BT_G $BT_B  $X_R $X_G $X_B"
sp_rows[13]="$X_R $X_G $X_B  $BT_R $BT_G $BT_B  $BT_R $BT_G $BT_B  $BT_R $BT_G $BT_B  $X_R $X_G $X_B  $X_R $X_G $X_B  $BT_R $BT_G $BT_B  $BT_R $BT_G $BT_B  $BT_R $BT_G $BT_B  $X_R $X_G $X_B"

row=0
while [ "$row" -lt 14 ]; do
  eval "top_arr=(${sp_rows[$row]})"
  eval "bot_arr=(${sp_rows[$((row+1))]})"
  printf "  "
  for ((col=0; col<10; col++)); do
    i=$((col*3))
    px "${top_arr[$i]}" "${top_arr[$((i+1))]}" "${top_arr[$((i+2))]}" \
       "${bot_arr[$i]}" "${bot_arr[$((i+1))]}" "${bot_arr[$((i+2))]}"
  done
  printf "${RESET}\n"
  row=$((row+2))
done

echo ""

# --- Show it next to a mock status box ---
echo "📦 Status line に配置したイメージ:"
echo ""

FC="\033[38;5;46m"  # frame color (neon green)
LB="\033[38;5;37m"  # label
UC="\033[38;5;46m"  # value

# Build sprite lines into array
sprite_lines=()
row=0
while [ "$row" -lt 14 ]; do
  eval "top_arr=(${sp_rows[$row]})"
  eval "bot_arr=(${sp_rows[$((row+1))]})"
  line=""
  for ((col=0; col<10; col++)); do
    i=$((col*3))
    line+=$(px "${top_arr[$i]}" "${top_arr[$((i+1))]}" "${top_arr[$((i+2))]}" \
              "${bot_arr[$i]}" "${bot_arr[$((i+1))]}" "${bot_arr[$((i+2))]}")
  done
  line+="${RESET}"
  sprite_lines+=("$line")
  row=$((row+2))
done

# Mock status lines
printf "${FC}╔══════════════════════════╗${RESET}   "
printf "${FC}╔════════════╗${RESET}\n"

printf "${FC}║${RESET} ${LB}model${RESET}:${UC}opus-4.6${RESET}           ${FC}║${RESET}   "
printf "${FC}║${RESET}%b${FC}  ║${RESET}\n" "${sprite_lines[0]}"

printf "${FC}║${RESET}  ${UC}\$1.23${RESET}                   ${FC}║${RESET}   "
printf "${FC}║${RESET}%b${FC}  ║${RESET}\n" "${sprite_lines[1]}"

printf "${FC}║${RESET} ${LB}ctx${RESET}:${UC}▰▰▰▰▰▱▱▱▱▱ 42%%${RESET}    ${FC}║${RESET}   "
printf "${FC}║${RESET}%b${FC}  ║${RESET}\n" "${sprite_lines[2]}"

printf "${FC}║${RESET} ${LB}5h${RESET} :${UC}▰▰▰▰▰▰▱▱▱▱ 60%%${RESET}    ${FC}║${RESET}   "
printf "${FC}║${RESET}%b${FC}  ║${RESET}\n" "${sprite_lines[3]}"

printf "${FC}║${RESET} ${LB}7d${RESET} :${UC}▰▰▰▰▰▱▱▱▱▱ 45%%${RESET}    ${FC}║${RESET}   "
printf "${FC}║${RESET}%b${FC}  ║${RESET}\n" "${sprite_lines[4]}"

printf "${FC}║${RESET} ${UC}■ 25c${RESET} ${LB}theme${RESET}:${UC}neon${RESET}        ${FC}║${RESET}   "
printf "${FC}║${RESET}%b${FC}  ║${RESET}\n" "${sprite_lines[5]}"

printf "${FC}╚══════════════════════════╝${RESET}   "
printf "${FC}║${RESET}%b${FC}  ║${RESET}\n" "${sprite_lines[6]}"

printf "                                "
printf "${FC}╚════════════╝${RESET}\n"

echo ""
echo "Done. Sprite = 10 chars wide × 7 terminal lines."
