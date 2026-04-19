#!/bin/bash
PM="\033[38;5;201m"; PC="\033[38;5;51m"; PG="\033[38;5;46m"
PW="\033[1;37m"; DM="\033[38;5;240m"; R="\033[0m"
RED="\033[0;31m"; CYAN="\033[0;36m"; BLUE="\033[1;34m"
GREEN="\033[0;32m"; YELLOW="\033[0;33m"
PR="\033[1;38;5;196m"; PB="\033[38;5;39m"

W_BOX=36

calc_vis_width() {
  printf "%b" "$1" | sed $'s/\033\[[0-9;]*m//g' | python3 -c "
import sys, unicodedata
s = sys.stdin.read()
total = 0
for c in s:
    cp = ord(c)
    eaw = unicodedata.east_asian_width(c)
    cat = unicodedata.category(c)
    if eaw in ('W', 'F'): total += 2
    elif cat in ('Mn', 'Me', 'Cf'): pass
    elif cp >= 0x1F000: total += 2
    elif cp >= 0x2600: total += 2
    else: total += 1
print(total)"
}

# Left box line: ║ content (padded to max_lw) ║
lbox_line() {
  local color="$1" content="$2" max_w="$3"
  local content_calc="${content//%%/%}"
  local w=$(calc_vis_width "$content_calc")
  local pad=$((max_w - w))
  local ps=""; [ "$pad" -gt 0 ] && ps=$(printf "%*s" "$pad" "")
  printf "${color}║${R} %b%s ${color}║${R}" "$content" "$ps"
}

# Left box border
lbox_top() {
  local color="$1" w="$2"
  printf "${color}╔"; for ((i=0; i<w+2; i++)); do printf "═"; done; printf "╗${R}"
}
lbox_bot() {
  local color="$1" w="$2"
  printf "${color}╚"; for ((i=0; i<w+2; i++)); do printf "═"; done; printf "╝${R}"
}

# Weather
wb()  { printf "$1╔"; for ((i=0; i<W_BOX; i++)); do printf "═"; done; printf "╗${R}"; }
wbb() { printf "$1╚"; for ((i=0; i<W_BOX; i++)); do printf "═"; done; printf "╝${R}"; }
wl() {
  local color="$1" icons="$2" ipad="$3" hi="$4" lo="$5" spd="$6"
  local tr="${hi}/${lo}"; local tp=$((5-${#tr}))
  local ts=""; [ "$tp" -gt 0 ] && ts=$(printf "%*s" "$tp" "")
  local wt="${spd}m/s"; local wl=$((3+${#wt}))
  local wp=$((9-wl)); local ws=""; [ "$wp" -gt 0 ] && ws=$(printf "%*s" "$wp" "")
  printf "${color}║${R} %b%s │ ${PR}%s${R}/${PB}%s${R}%s │ ${PW}💨 %s${R}%s ${color}║${R}" \
    "$icons" "$ipad" "$hi" "$lo" "$ts" "$wt" "$ws"
}

# Pomo
calc_pomo_w() {
  local inner="  🍅 $1  $2  $3  "
  POMO_W=$(calc_vis_width "$inner")
  [ "$POMO_W" -lt "$W_BOX" ] && POMO_W=$W_BOX
}
pwb()  { printf "$1╔"; for ((i=0; i<POMO_W; i++)); do printf "═"; done; printf "╗${R}"; }
pwbb() { printf "$1╚"; for ((i=0; i<POMO_W; i++)); do printf "═"; done; printf "╝${R}"; }
pl() {
  local color="$1" time="$2" tom="$3" msg="$4"
  local inner="  ${PW}🍅 ${time}${R}  ${tom}  ${color}${msg}${R}  "
  local iw=$(calc_vis_width "$inner")
  local pad=$((POMO_W - iw))
  local ps=""; [ "$pad" -gt 0 ] && ps=$(printf "%*s" "$pad" "")
  printf "${color}║${R}%b%s${color}║${R}" "$inner" "$ps"
}

pick() { local a=("$@"); echo "${a[$((RANDOM % ${#a[@]}))]}"; }

clear

# Content
L1="${RED}[3]${R} ${CYAN}musubie-net${R} ${BLUE}git:(main)${R}"
L2="Opus 4.7 \$24.42 ${GREEN}[sensei:ON]${R}"
L3="ctx:▰▰▰▰▰▱▱▱▱▱47%%"
L4="5h :▰▱▱▱▱▱▱▱▱▱13%%(2h38m)"
L5="7d :▰▰▰▱▱▱▱▱▱▱18%%(4d19h)"
L6="${PG}+42${R} ${RED}-7${R}"

# Max left width
max_lw=0
for l in "$L1" "$L2" "$L3" "$L4" "$L5" "$L6"; do
  lc_calc="${l//%%/%}"
  w=$(calc_vis_width "$lc_calc")
  [ "$w" -gt "$max_lw" ] && max_lw=$w
done

lc="$PC"  # left box color
wc="$PG"  # weather color
pc="$PG"  # pomo color
pm=$(pick "🌊 FLOW" "🤿 DIVE" "🏃 Go!Go!" "💨 FLOW")
calc_pomo_w "18:32" "🍅🍅🍅🍅🍅" "$pm"

printf "\n  ═══ 全体像 ═══\n\n"

# L1: left ╔ + right weather ╔
printf "$(lbox_top "$lc" "$max_lw")   $(wb "$wc")\n"
# L2: left ║content║ + right weather ║content║
printf "$(lbox_line "$lc" "$L1" "$max_lw")   $(wl "$wc" "☀️ ☀️ ☀️ ⛅ ⛅" "" "28" "22" "3")\n"
# L3: left ║content║ + right weather ╚
printf "$(lbox_line "$lc" "$L2" "$max_lw")   $(wbb "$wc")\n"
# L4: left ║content║ + right pomo ╔
printf "$(lbox_line "$lc" "$L3" "$max_lw")   $(pwb "$pc")\n"
# L5: left ║content║ + right pomo ║content║
printf "$(lbox_line "$lc" "$L4" "$max_lw")   $(pl "$pc" "18:32" "🍅🍅🍅🍅🍅" "$pm")\n"
# L6: left ║content║ + right pomo ╚
printf "$(lbox_line "$lc" "$L5" "$max_lw")   $(pwbb "$pc")\n"
# L7: left ║content║
printf "$(lbox_line "$lc" "$L6" "$max_lw")\n"
# L8: left ╚
printf "$(lbox_bot "$lc" "$max_lw")\n"

printf "\n"
