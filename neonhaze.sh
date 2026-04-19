#!/usr/bin/env bash
# Claude Code status line - visual bar graph edition
# 5-hour / weekly usage quota with progress bars

umask 077

input=$(cat)

# --- Tier detection (responsive layout) ---
term_width="${COLUMNS:-$(tput cols 2>/dev/null || echo 120)}"
if [ "$term_width" -ge 140 ] 2>/dev/null; then
  tier="wide"
else
  tier="narrow"
fi
{
  read -r cwd
  read -r model
  read -r used_pct
  read -r cost
} <<< "$(echo "$input" | jq -r '
  (.workspace.current_dir // .cwd // ""),
  (.model.display_name // ""),
  (.context_window.used_percentage // "" | tostring),
  (.cost.total_cost_usd // 0 | tostring)
' | tr -d '\r')"

[[ "$cost" =~ ^[0-9]*\.?[0-9]+$ ]] || cost=0

# --- Git branch, dirty status, and project directory ---
branch=""
dirty=""
dir_name="?"
diff_add=0; diff_del=0
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ] && git -C "$cwd" status --porcelain --no-renames 2>/dev/null | read -r _; then
    dirty=""
  fi
  diff_stats=$(git -C "$cwd" diff --numstat 2>/dev/null)
  if [ -n "$diff_stats" ]; then
    diff_add=$(echo "$diff_stats" | awk '{s+=$1} END {print s+0}')
    diff_del=$(echo "$diff_stats" | awk '{s+=$2} END {print s+0}')
  fi
  main_wt=$(git -C "$cwd" worktree list --porcelain 2>/dev/null | head -1 | sed 's/^worktree //')
  if [ -n "$main_wt" ]; then
    dir_name=$(echo "$main_wt" | sed 's|\\|/|g' | sed 's|/$||' | awk -F/ '{print $NF}')
  fi
fi

if [ "$dir_name" = "?" ] && [ -n "$cwd" ]; then
  dir_name=$(echo "$cwd" | sed 's|\\|/|g' | sed 's|/$||' | awk -F/ '{print $NF}')
  [ -z "$dir_name" ] && dir_name="?"
fi

abbreviate_branch() {
  local b="$1" max_len=25
  local display="$b"
  display="${display#worktree-}"
  display="${display#feature/}"
  display="${display#feat/}"
  display="${display#fix/}"
  display="${display#bugfix/}"
  display="${display#hotfix/}"
  local prefix_indicator=""
  if [ "$display" != "$b" ]; then
    case "$b" in
      worktree-*) prefix_indicator="wt:" ;;
      feature/*|feat/*) prefix_indicator="f/" ;;
      fix/*|bugfix/*) prefix_indicator="x/" ;;
      hotfix/*) prefix_indicator="h/" ;;
    esac
  fi
  local full="${prefix_indicator}${display}"
  if [ ${#full} -gt "$max_len" ]; then
    echo "${full:0:$(( max_len - 1 ))}…"
  else
    echo "$full"
  fi
}

ctx_pct=""
if [ -n "$used_pct" ]; then
  ctx_pct=${used_pct%.*}
fi

# --- Visual bar graph renderer ---
# ▰ bright(filled) → ▰ dim(half) → ▱ gray(empty), cap at 100%
# $1=percentage, $2=bright color, $3=dim color
render_bar() {
  local pct=${1:-0} width=10 color="$2" dim="$3"
  [ "$pct" -gt 100 ] 2>/dev/null && pct=100
  [ "$pct" -lt 0 ] 2>/dev/null && pct=0
  local steps=$(( pct * width * 2 / 100 ))
  local full=$(( steps / 2 ))
  local half=$(( steps % 2 ))
  local empty=$(( width - full - half ))
  local bar="${color}"
  for ((i=0; i<full; i++)); do bar+="▰"; done
  [ "$half" -eq 1 ] && bar+="${dim}▰"
  bar+="${dim}"
  for ((i=0; i<empty; i++)); do bar+="▱"; done
  bar+="\033[0m"
  printf "%b" "$bar"
}

# --- Visual width calculator (ANSI-aware, emoji-aware) ---
# Batch mode: call calc_vis_width_batch with NUL-separated strings, get widths back
_VW_CACHE_IN=""
_VW_CACHE_OUT=""
_vw_batch_done=""

calc_vis_width() {
  if [ -z "$_vw_batch_done" ]; then
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
  else
    local idx="$2"
    echo "$_VW_CACHE_OUT" | sed -n "${idx}p"
  fi
}

calc_vis_width_batch() {
  _VW_CACHE_OUT=$(printf "%s" "$1" | python3 -c "
import sys, unicodedata
lines = sys.stdin.read().split('\x00')
for line in lines:
    total = 0
    for c in line:
        cp = ord(c)
        eaw = unicodedata.east_asian_width(c)
        cat = unicodedata.category(c)
        if eaw in ('W', 'F'): total += 2
        elif cat in ('Mn', 'Me', 'Cf'): pass
        elif cp >= 0x1F000: total += 2
        elif cp >= 0x2600: total += 2
        else: total += 1
    print(total)
")
  _vw_batch_done="1"
}

# --- Left box frame (HUD style) ---
_BOX_COLOR="${T_FRAME:-\033[38;5;46m}"

lbox_line() {
  local color="$1" content="$2" max_w="$3" precomp_w="$4"
  local w
  if [ -n "$precomp_w" ]; then
    w="$precomp_w"
  else
    local content_calc="${content//%%/%}"
    w=$(calc_vis_width "$content_calc")
  fi
  local pad=$((max_w - w))
  local ps=""; [ "$pad" -gt 0 ] && ps=$(printf "%*s" "$pad" "")
  printf "${color}║${RESET} %b%s ${color}║${RESET}" "$content" "$ps"
}

lbox_top() {
  local color="$1" w="$2"
  printf "${color}╔"; for ((i=0; i<w+2; i++)); do printf "═"; done; printf "╗${RESET}"
}

lbox_bot() {
  local color="$1" w="$2"
  printf "${color}╚"; for ((i=0; i<w+2; i++)); do printf "═"; done; printf "╝${RESET}"
}

# --- Weather box (fixed width) ---
W_BOX=36

wb_top() {
  local color="$1"
  printf "${color}╔"; for ((i=0; i<W_BOX; i++)); do printf "═"; done; printf "╗${RESET}"
}

wb_bot() {
  local color="$1"
  printf "${color}╚"; for ((i=0; i<W_BOX; i++)); do printf "═"; done; printf "╝${RESET}"
}

wb_line() {
  local color="$1" icons="$2" hi="$3" lo="$4" spd="$5"
  local tr="${hi}/${lo}"; local tp=$((5-${#tr}))
  local ts=""; [ "$tp" -gt 0 ] && ts=$(printf "%*s" "$tp" "")
  local wt="${spd}km/h"; local wl=$((3+${#wt}))
  local wp=$((9-wl)); local ws=""; [ "$wp" -gt 0 ] && ws=$(printf "%*s" "$wp" "")
  printf "${color}║${RESET} %b │ ${T_TEMP_HI:-\033[38;5;208m}%s${RESET}/${T_TEMP_LO:-\033[38;5;123m}%s${RESET}%s │ ${T_WIND:-\033[38;5;75m}💨 %s${RESET}%s ${color}║${RESET}" \
    "$icons" "$hi" "$lo" "$ts" "$wt" "$ws"
}

# --- Pomodoro box (dynamic width, min W_BOX) ---
pb_top() {
  local color="$1" w="$2"
  printf "${color}╔"; for ((i=0; i<w; i++)); do printf "═"; done; printf "╗${RESET}"
}

pb_bot() {
  local color="$1" w="$2"
  printf "${color}╚"; for ((i=0; i<w; i++)); do printf "═"; done; printf "╝${RESET}"
}

pb_line() {
  local color="$1" time="$2" tom="$3" msg="$4" box_w="$5" precomp_w="$6"
  local inner="  ${T_POMO_TIMER:-\033[38;5;198m}🍅 ${time}${RESET}  ${tom}  ${color}${msg}${RESET}  "
  local iw
  if [ -n "$precomp_w" ]; then
    iw="$precomp_w"
  else
    iw=$(calc_vis_width "$inner")
  fi
  local pad=$((box_w - iw))
  local ps=""; [ "$pad" -gt 0 ] && ps=$(printf "%*s" "$pad" "")
  printf "${color}║${RESET}%b%s${color}║${RESET}" "$inner" "$ps"
}

# --- Fetch 5-hour / weekly usage quota ---

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
mkdir -p "$CACHE_DIR" 2>/dev/null
CACHE_FILE="${CACHE_DIR}/usage-cache"
CACHE_TTL=300
CACHE_TTL_FAIL=600
FAIL_MARKER="${CACHE_DIR}/usage-cache.fail"
LOCK_DIR="${CACHE_DIR}/fetch.lock"

fetch_usage() {
  token=""
  if command -v security >/dev/null 2>&1; then
    local cred_json
    cred_json=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
    if [ -n "$cred_json" ]; then
      token=$(echo "$cred_json" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    fi
  fi
  if [ -z "$token" ]; then
    CRED_FILE="$HOME/.claude/.credentials.json"
    if [ -f "$CRED_FILE" ]; then
      token=$(jq -r '.claudeAiOauth.accessToken // empty' "$CRED_FILE" 2>/dev/null)
    fi
  fi
  if [ -z "$token" ]; then
    touch "$FAIL_MARKER" "$CACHE_FILE" 2>/dev/null
    return 1
  fi
  local _auth="${CACHE_DIR}/.auth-header"
  printf 'Authorization: Bearer %s' "$token" > "$_auth"
  response=$(curl -s --max-time 3 \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H @"$_auth" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "User-Agent: claude-code-statusline/1.0" \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
  rm -f "$_auth" 2>/dev/null
  if echo "$response" | jq -e '.five_hour' > /dev/null 2>&1; then
    echo "$response" > "$CACHE_FILE"
    rm -f "$FAIL_MARKER" 2>/dev/null
    return 0
  fi
  touch "$FAIL_MARKER" 2>/dev/null
  touch "$CACHE_FILE" 2>/dev/null
  return 1
}

fetch_with_lock() {
  if [ -d "$LOCK_DIR" ]; then
    lock_age=$(( $(date +%s) - $(_file_mtime "$LOCK_DIR") ))
    [ "$lock_age" -gt 30 ] && rmdir "$LOCK_DIR" 2>/dev/null
  fi
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    trap 'rmdir "$LOCK_DIR" 2>/dev/null' RETURN
    fetch_usage
  fi
}

_file_mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

active_ttl="$CACHE_TTL"
[ -f "$FAIL_MARKER" ] && active_ttl="$CACHE_TTL_FAIL"

if [ -f "$CACHE_FILE" ]; then
  cache_age=$(( $(date +%s) - $(_file_mtime "$CACHE_FILE") ))
  [ "$cache_age" -gt "$active_ttl" ] && fetch_with_lock
else
  fetch_with_lock
fi

# Parse usage data (Sonnet removed)
five_hour=""
seven_day=""
five_hour_reset=""
seven_day_reset=""
seven_day_opus=""
seven_day_opus_reset=""

if [ -f "$CACHE_FILE" ] && [ -s "$CACHE_FILE" ]; then
  {
    read -r five_hour
    read -r seven_day
    read -r five_hour_reset
    read -r seven_day_reset
    read -r seven_day_opus
    read -r seven_day_opus_reset
  } <<< "$(jq -r '
    (.five_hour.utilization // "" | tostring),
    (.seven_day.utilization // "" | tostring),
    (.five_hour.resets_at // ""),
    (.seven_day.resets_at // ""),
    (.seven_day_opus.utilization // "" | tostring),
    (.seven_day_opus.resets_at // "")
  ' "$CACHE_FILE" 2>/dev/null | tr -d '\r')"
fi

# --- Weather data (Open-Meteo, 10-min cache) ---
WEATHER_CACHE="${CACHE_DIR}/weather-cache"
WEATHER_TTL=600
WEATHER_LAT="${CLAUDE_WEATHER_LAT:-35.6762}"
WEATHER_LON="${CLAUDE_WEATHER_LON:-139.6503}"

fetch_weather() {
  local raw
  raw=$(curl -s --max-time 15 \
    "https://api.open-meteo.com/v1/forecast?latitude=${WEATHER_LAT}&longitude=${WEATHER_LON}&hourly=temperature_2m,weather_code,wind_speed_10m,precipitation_probability&daily=temperature_2m_max,temperature_2m_min&forecast_days=2&timezone=auto" 2>/dev/null)
  [ -z "$raw" ] && return 1
  local cur_hour
  cur_hour=$(date +%-H)
  local parsed
  parsed=$(echo "$raw" | jq -r --argjson h "$cur_hour" '
    {
      hi: (.daily.temperature_2m_max[0] | floor),
      lo: (.daily.temperature_2m_min[0] | floor),
      wind: ((.hourly.wind_speed_10m[$h] // 0) | floor),
      hours: [
        (.hourly.weather_code[$h:$h+5] // []) as $c |
        (.hourly.precipitation_probability[$h:$h+5] // []) as $p |
        range([($c|length),5]|min) |
        {code: ($c[.]//0), precip: ($p[.]//0)}
      ]
    }
  ' 2>/dev/null) || return 1
  echo "$parsed" | jq -e '.hi' >/dev/null 2>&1 || return 1
  local tmpf="${WEATHER_CACHE}.tmp.$$"
  echo "$parsed" > "$tmpf"
  mv -f "$tmpf" "$WEATHER_CACHE"
}

if [ -f "$WEATHER_CACHE" ]; then
  w_cache_age=$(( $(date +%s) - $(_file_mtime "$WEATHER_CACHE") ))
  [ "$w_cache_age" -gt "$WEATHER_TTL" ] && (fetch_weather) &
else
  (fetch_weather) &
fi

w_hi=""; w_lo=""; w_wind=""; w_icons=""; w_box_color=""
if [ -f "$WEATHER_CACHE" ] && [ -s "$WEATHER_CACHE" ]; then
  {
    read -r w_hi
    read -r w_lo
    read -r w_wind
  } <<< "$(jq -r '.hi, .lo, .wind' "$WEATHER_CACHE" 2>/dev/null)"

  w_icons=""
  w_dominant=0
  for i in 0 1 2 3 4; do
    code=$(jq -r ".hours[$i].code // 0" "$WEATHER_CACHE" 2>/dev/null)
    [ "$code" -gt "$w_dominant" ] 2>/dev/null && w_dominant=$code
    local_icon=""
    if [ "$code" -le 0 ]; then local_icon="☀️"
    elif [ "$code" -le 3 ]; then
      [ "$code" -le 1 ] && local_icon="⛅" || local_icon="☁️"
    elif [ "$code" -le 48 ]; then local_icon="🌫️"
    elif [ "$code" -le 67 ]; then local_icon="🌧️"
    elif [ "$code" -le 77 ]; then local_icon="⛄"
    elif [ "$code" -le 82 ]; then local_icon="🌧️"
    elif [ "$code" -le 86 ]; then local_icon="⛄"
    else local_icon="⛈️"
    fi
    [ -n "$w_icons" ] && w_icons+=" "
    w_icons+="$local_icon"
  done

  if [ "$w_dominant" -ge 95 ]; then w_box_color="${T_WEATHER_THUNDER:-\033[38;5;196m}"
  elif [ "$w_dominant" -ge 71 ]; then w_box_color="${T_WEATHER_SNOW:-\033[38;5;159m}"
  elif [ "$w_dominant" -ge 51 ]; then w_box_color="${T_WEATHER_RAIN:-\033[38;5;45m}"
  elif [ "$w_dominant" -ge 45 ]; then w_box_color="${T_WEATHER_FOG:-\033[38;5;103m}"
  elif [ "$w_dominant" -ge 2 ]; then w_box_color="${T_WEATHER_CLOUD:-\033[38;5;214m}"
  else w_box_color="${T_WEATHER_CLEAR:-\033[38;5;118m}"
  fi
fi

# --- Pomodoro timer (inline tick) ---
POMO_DIR="$HOME/.claude/state"
pomo_active=""
pomo_remaining=0
pomo_phase="idle"
pomo_count=0
pomo_box_color=""
pomo_msg=""
pomo_tomatoes=""
pomo_time_str=""

if [ -f "$POMO_DIR/pomo-phase" ]; then
  pomo_active="1"
  pomo_phase=$(cat "$POMO_DIR/pomo-phase" 2>/dev/null || echo "idle")
  pomo_count=$(cat "$POMO_DIR/pomo-count" 2>/dev/null || echo 0)

  # 6am reset
  current_hour=$(date +%H)
  if [ "$current_hour" -ge 6 ]; then
    boundary=$(date -j -f "%Y-%m-%d %H:%M:%S" "$(date +%Y-%m-%d) 06:00:00" +%s 2>/dev/null || date -d "$(date +%Y-%m-%d) 06:00:00" +%s 2>/dev/null)
  else
    boundary=$(date -j -v-1d -f "%Y-%m-%d %H:%M:%S" "$(date -v-1d +%Y-%m-%d) 06:00:00" +%s 2>/dev/null || date -d "yesterday 06:00:00" +%s 2>/dev/null)
  fi
  last_reset=$(cat "$POMO_DIR/pomo-last-reset" 2>/dev/null || echo 0)
  if [ -n "$boundary" ] && [ "$last_reset" -lt "$boundary" ] 2>/dev/null; then
    pomo_count=0
    echo 0 > "$POMO_DIR/pomo-count"
    date +%s > "$POMO_DIR/pomo-last-reset"
  fi

  # Tomato display (shared by active and idle)
  if [ "$pomo_count" -le 0 ]; then
    pomo_tomatoes=""
  elif [ "$pomo_count" -le 9 ]; then
    pomo_tomatoes=""
    for ((t=0; t<pomo_count; t++)); do pomo_tomatoes+="🍅"; done
  else
    pomo_tomatoes="🍅🍅🍅🍅🍅🍅🍅🍅🍅＋"
  fi

  _pomo_pick() { local a=("$@"); echo "${a[$((RANDOM % ${#a[@]}))]}"; }
  _pomo_saved_msg=$(cat "$POMO_DIR/pomo-msg" 2>/dev/null)
  _pomo_saved_count=$(cat "$POMO_DIR/pomo-msg-count" 2>/dev/null)
  _pomo_saved_phase=$(cat "$POMO_DIR/pomo-msg-phase" 2>/dev/null)

  if [ -f "$POMO_DIR/pomo-start" ]; then
    # === Active timer ===
    pomo_start=$(cat "$POMO_DIR/pomo-start" 2>/dev/null)
    pomo_now=$(date +%s)
    pomo_elapsed=$((pomo_now - pomo_start))

    # Phase transition
    case "$pomo_phase" in
      work)
        if [ "$pomo_elapsed" -ge 1500 ]; then
          pomo_count=$((pomo_count + 1))
          echo "$pomo_count" > "$POMO_DIR/pomo-count"
          echo "$pomo_now" > "$POMO_DIR/pomo-start"
          if [ $((pomo_count % 4)) -eq 0 ]; then
            echo "break-long" > "$POMO_DIR/pomo-phase"
            pomo_phase="break-long"
          else
            echo "break-short" > "$POMO_DIR/pomo-phase"
            pomo_phase="break-short"
          fi
          pomo_start=$pomo_now; pomo_elapsed=0
        fi
        ;;
      break-short)
        if [ "$pomo_elapsed" -ge 300 ]; then
          echo "$pomo_now" > "$POMO_DIR/pomo-start"
          echo "work" > "$POMO_DIR/pomo-phase"
          pomo_start=$pomo_now; pomo_elapsed=0; pomo_phase="work"
        fi
        ;;
      break-long)
        if [ "$pomo_elapsed" -ge 900 ]; then
          echo "$pomo_now" > "$POMO_DIR/pomo-start"
          echo "work" > "$POMO_DIR/pomo-phase"
          pomo_start=$pomo_now; pomo_elapsed=0; pomo_phase="work"
        fi
        ;;
    esac

    # Remaining time
    case "$pomo_phase" in
      work) pomo_remaining=$((1500 - pomo_elapsed)); [ "$pomo_remaining" -lt 0 ] && pomo_remaining=0 ;;
      break-short) pomo_remaining=$((300 - pomo_elapsed)); [ "$pomo_remaining" -lt 0 ] && pomo_remaining=0 ;;
      break-long) pomo_remaining=$((900 - pomo_elapsed)); [ "$pomo_remaining" -lt 0 ] && pomo_remaining=0 ;;
    esac
    pomo_min=$((pomo_remaining / 60))
    pomo_sec=$((pomo_remaining % 60))
    pomo_time_str=$(printf "%02d:%02d" "$pomo_min" "$pomo_sec")

    # Stage message (only regenerate when count or phase changes)
    if [ "$_pomo_saved_count" = "$pomo_count" ] && [ "$_pomo_saved_phase" = "$pomo_phase" ] && [ -n "$_pomo_saved_msg" ]; then
      pomo_msg="$_pomo_saved_msg"
    else
      case "$pomo_phase" in
        work)
          if [ "$pomo_count" -le 0 ]; then pomo_msg=$(_pomo_pick "⚡START" "🔌BOOT" "⏻ INIT")
          elif [ "$pomo_count" -le 2 ]; then pomo_msg=$(_pomo_pick "🎯FOCUS" "🔗SYNC" "💭FOCUS")
          elif [ "$pomo_count" -le 3 ]; then pomo_msg=$(_pomo_pick "👍NICE" "🔗LINK" "🔒LOCKED")
          elif [ "$pomo_count" -le 5 ]; then pomo_msg=$(_pomo_pick "🌊FLOW" "🤿DIVE" "🏃Go!Go!" "💨FLOW")
          elif [ "$pomo_count" -le 6 ]; then pomo_msg=$(_pomo_pick "🎯ZONE" "🧠NEURAL" "🤿DEEP")
          else pomo_msg=$(_pomo_pick "🔥FIRE" "⚡OVERCLK" "👹BEAST")
          fi
          ;;
        break-short)
          pomo_msg=$(_pomo_pick "☕BREAK" "❄️COOLDOWN" "🫧BREAK")
          ;;
        break-long)
          pomo_msg=$(_pomo_pick "🔋RECHARGE" "💾DEFRAG" "♻️REBOOT")
          ;;
      esac
      echo "$pomo_msg" > "$POMO_DIR/pomo-msg"
      echo "$pomo_count" > "$POMO_DIR/pomo-msg-count"
      echo "$pomo_phase" > "$POMO_DIR/pomo-msg-phase"
    fi
  else
    # === Idle (stopped) ===
    pomo_time_str="--:--"
    if [ "$_pomo_saved_phase" = "idle" ] && [ -n "$_pomo_saved_msg" ]; then
      pomo_msg="$_pomo_saved_msg"
    else
      pomo_msg=$(_pomo_pick "💤IDLE" "⏸ PAUSE" "🔌STANDBY")
      echo "$pomo_msg" > "$POMO_DIR/pomo-msg"
      echo "$pomo_count" > "$POMO_DIR/pomo-msg-count"
      echo "idle" > "$POMO_DIR/pomo-msg-phase"
    fi
  fi

  # Box color
  case "$pomo_phase" in
    work)
      if [ "$pomo_remaining" -le 300 ]; then
        pomo_box_color="${T_POMO_URGENT:-\033[38;5;196m}"
      elif [ "$pomo_count" -le 2 ]; then
        pomo_box_color="${T_POMO_START:-\033[38;5;201m}"
      elif [ "$pomo_count" -le 3 ]; then
        pomo_box_color="${T_POMO_MID:-\033[38;5;214m}"
      elif [ "$pomo_count" -le 6 ]; then
        pomo_box_color="${T_POMO_FLOW:-\033[38;5;118m}"
      else
        pomo_box_color="${T_POMO_FIRE:-\033[38;5;208m}"
      fi
      ;;
    break-short|break-long)
      pomo_box_color="${T_POMO_BREAK:-\033[38;5;45m}"
      ;;
    idle|*)
      pomo_box_color="${T_POMO_IDLE:-\033[38;5;75m}"
      ;;
  esac
fi

remaining_time() {
  local reset_at="$1"
  if [ -z "$reset_at" ]; then return; fi
  local clean=$(echo "$reset_at" | sed 's/\.[0-9]*//' | sed 's/+00:00$/+0000/' | sed 's/Z$/+0000/')
  local reset_epoch=$(date -d "$clean" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S%z" "$clean" +%s 2>/dev/null)
  if [ -z "$reset_epoch" ]; then return; fi
  local now=$(date +%s)
  local diff=$(( reset_epoch - now ))
  if [ "$diff" -le 0 ]; then echo "now"; return; fi
  local days=$(( diff / 86400 ))
  local hours=$(( (diff % 86400) / 3600 ))
  local mins=$(( (diff % 3600) / 60 ))
  if [ "$days" -gt 0 ]; then
    echo "${days}d${hours}h"
  elif [ "$hours" -gt 0 ]; then
    echo "${hours}h${mins}m"
  else
    echo "${mins}m"
  fi
}

# --- Theme loading ---
RESET="\033[0m"
_THEME_FILE="$HOME/.claude/state/current-theme"
_THEME_DIR="$HOME/.claude/themes"
_active_theme=$(cat "$_THEME_FILE" 2>/dev/null || echo "neon")
if [ -f "$_THEME_DIR/${_active_theme}.sh" ]; then
  source "$_THEME_DIR/${_active_theme}.sh"
else
  source "$_THEME_DIR/neon.sh" 2>/dev/null
fi

CYAN="${T_PROJECT:-\033[38;5;51m}"
BLUE="${T_BRANCH:-\033[38;5;141m}"
RED="${T_BADGE:-\033[38;5;197m}"
YELLOW="${T_DIRTY:-\033[38;5;226m}"
GREEN="${T_SENSEI:-\033[38;5;46m}"
DIM="${T_COST:-\033[38;5;60m}"

_color_for_val() {
  local val=${1%.*}
  if [ "$val" -ge 80 ] 2>/dev/null; then
    _uc="${T_BAR_BAD:-$RED}"; _uc_dim="${T_BAR_BAD_DIM:-\033[38;5;125m}"
  elif [ "$val" -ge 50 ] 2>/dev/null; then
    _uc="${T_BAR_MID:-$YELLOW}"; _uc_dim="${T_BAR_MID_DIM:-\033[38;5;136m}"
  else
    _uc="${T_BAR_GOOD:-$GREEN}"; _uc_dim="${T_BAR_GOOD_DIM:-\033[38;5;28m}"
  fi
}

# --- Sensei state (read early for [N] badge) ---
SENSEI_STATE_DIR="$HOME/.claude/state"
sensei_unreviewed=$(cat "$SENSEI_STATE_DIR/unreviewed_count" 2>/dev/null || echo 0)
sensei_active=""
[ -f "$SENSEI_STATE_DIR/sensei-active" ] && sensei_active="1"

# --- Output (tier-based) ---

print_badge() {
  if [ "$sensei_unreviewed" -gt 0 ] 2>/dev/null; then
    printf "${RED}[%d]${RESET} " "$sensei_unreviewed"
  fi
}

print_dir_git() {
  printf "${CYAN}%s${RESET}" "$dir_name"
  if [ -n "$branch" ]; then
    br_display=$(abbreviate_branch "$branch")
    if [ -n "$dirty" ]; then
      printf " ${BLUE}git:(${RED}%s${BLUE})${RESET} ${YELLOW}%s${RESET}" "$br_display" "$dirty"
    else
      printf " ${BLUE}git:(${RED}%s${BLUE})${RESET}" "$br_display"
    fi
  fi
}

print_sensei_on() {
  [ -n "$sensei_active" ] && printf " ${GREEN}[sensei:ON]${RESET}"
}

if [ "$tier" = "wide" ]; then
  # === Wide: single line ===
  print_badge
  print_dir_git

  [ -n "$model" ] && printf " ${DIM}%s${RESET}" "$model"

  if [ -n "$ctx_pct" ]; then
    _color_for_val "$ctx_pct"
    ctx_bar=$(render_bar "$ctx_pct" "$_uc" "$_uc_dim")
    printf " ctx:%s${_uc}%s%%${RESET}" "$ctx_bar" "$ctx_pct"
  fi

  printf " ${DIM}\$%.2f${RESET}" "$cost"

  if [ -n "$five_hour" ]; then
    five_int=${five_hour%.*}
    printf " ${DIM}|${RESET} "
    _color_for_val "$five_hour"
    five_bar=$(render_bar "$five_int" "$_uc" "$_uc_dim")
    printf "5h:%s${_uc}%s%%${RESET}" "$five_bar" "$five_int"
    five_remain=$(remaining_time "$five_hour_reset")
    [ -n "$five_remain" ] && printf "${DIM}(%s)${RESET}" "$five_remain"
  fi

  if [ -n "$seven_day" ]; then
    seven_int=${seven_day%.*}
    _color_for_val "$seven_day"
    seven_bar=$(render_bar "$seven_int" "$_uc" "$_uc_dim")
    printf " 7d:%s${_uc}%s%%${RESET}" "$seven_bar" "$seven_int"
    seven_remain=$(remaining_time "$seven_day_reset")
    [ -n "$seven_remain" ] && printf "${DIM}(%s)${RESET}" "$seven_remain"
  fi

  if [ -n "$seven_day_opus" ] && [ "$seven_day_opus" != "null" ]; then
    opus_int=${seven_day_opus%.*}
    _color_for_val "$seven_day_opus"
    opus_bar=$(render_bar "$opus_int" "$_uc" "$_uc_dim")
    printf " op:%s${_uc}%s%%${RESET}" "$opus_bar" "$opus_int"
    opus_remain=$(remaining_time "$seven_day_opus_reset")
    [ -n "$opus_remain" ] && printf "${DIM}(%s)${RESET}" "$opus_remain"
  fi

  print_sensei_on

else
  # === Narrow: HUD left box ===
  lc="$_BOX_COLOR"

  # L1: [N] dir git dirty
  L1=""
  if [ "$sensei_unreviewed" -gt 0 ] 2>/dev/null; then
    L1="${RED}[${sensei_unreviewed}]${RESET} "
  fi
  L1+=$(printf "${CYAN}%s${RESET}" "$dir_name")
  if [ -n "$branch" ]; then
    br_display=$(abbreviate_branch "$branch")
    if [ -n "$dirty" ]; then
      L1+=$(printf " ${BLUE}git:(${RED}%s${BLUE})${RESET} ${YELLOW}%s${RESET}" "$br_display" "$dirty")
    else
      L1+=$(printf " ${BLUE}git:(${RED}%s${BLUE})${RESET}" "$br_display")
    fi
  fi

  # L2: model cost [sensei:ON]
  display_model=$(echo "$model" | sed 's/ *([^)]*)//')
  L2=""
  [ -n "$display_model" ] && L2+="$display_model"
  L2+=$(printf " \$%.2f" "$cost")
  [ -n "$sensei_active" ] && L2+=$(printf " ${GREEN}[sensei:ON]${RESET}")

  # L3: ctx bar
  L3=""
  if [ -n "$ctx_pct" ]; then
    _color_for_val "$ctx_pct"
    ctx_bar=$(render_bar "$ctx_pct" "$_uc" "$_uc_dim")
    L3=$(printf "ctx:%b${_uc}%s%%${RESET}" "$ctx_bar" "$ctx_pct")
  fi

  # L4: 5h bar
  L4=""
  if [ -n "$five_hour" ]; then
    five_int=${five_hour%.*}
    _color_for_val "$five_hour"
    five_bar=$(render_bar "$five_int" "$_uc" "$_uc_dim")
    L4=$(printf "5h :%b${_uc}%s%%${RESET}" "$five_bar" "$five_int")
    five_remain=$(remaining_time "$five_hour_reset")
    [ -n "$five_remain" ] && L4+=$(printf "${DIM}(%s)${RESET}" "$five_remain")
  fi

  # L5: 7d bar
  L5=""
  if [ -n "$seven_day" ]; then
    seven_int=${seven_day%.*}
    _color_for_val "$seven_day"
    seven_bar=$(render_bar "$seven_int" "$_uc" "$_uc_dim")
    L5=$(printf "7d :%b${_uc}%s%%${RESET}" "$seven_bar" "$seven_int")
    seven_remain=$(remaining_time "$seven_day_reset")
    [ -n "$seven_remain" ] && L5+=$(printf "${DIM}(%s)${RESET}" "$seven_remain")
  fi

  # L5b: op bar (optional)
  L5b=""
  if [ -n "$seven_day_opus" ] && [ "$seven_day_opus" != "null" ]; then
    opus_int=${seven_day_opus%.*}
    _color_for_val "$seven_day_opus"
    opus_bar=$(render_bar "$opus_int" "$_uc" "$_uc_dim")
    L5b=$(printf "op :%b${_uc}%s%%${RESET}" "$opus_bar" "$opus_int")
    opus_remain=$(remaining_time "$seven_day_opus_reset")
    [ -n "$opus_remain" ] && L5b+=$(printf "${DIM}(%s)${RESET}" "$opus_remain")
  fi

  # L6: diff stats
  L6=""
  if [ "$diff_add" -gt 0 ] || [ "$diff_del" -gt 0 ]; then
    L6=$(printf "${GREEN}+%d${RESET} ${RED}-%d${RESET}" "$diff_add" "$diff_del")
  fi

  # Build pomo inner string for width calculation
  _pomo_inner=""
  if [ -n "$pomo_active" ]; then
    _pomo_inner="  🍅 ${pomo_time_str}  ${pomo_tomatoes}  ${pomo_msg}  "
  fi

  # Calculate max visual width across all lines + pomo (single python3 call)
  _widths=$({ for l in "$L1" "$L2" "$L3" "$L4" "$L5" "$L5b" "$L6"; do
    lc_calc="${l//%%/%}"
    printf "%b\n" "$lc_calc"
  done; printf "%s\n" "$_pomo_inner"; } | sed $'s/\033\[[0-9;]*m//g' | python3 -c "
import sys, unicodedata
for line in sys.stdin:
    line = line.rstrip('\n')
    total = 0
    for c in line:
        cp = ord(c)
        eaw = unicodedata.east_asian_width(c)
        cat = unicodedata.category(c)
        if eaw in ('W', 'F'): total += 2
        elif cat in ('Mn', 'Me', 'Cf'): pass
        elif cp >= 0x1F000: total += 2
        elif cp >= 0x2600: total += 2
        else: total += 1
    print(total)
")

  _w_arr=()
  while IFS= read -r w; do
    _w_arr+=("$w")
  done <<< "$_widths"
  W1="${_w_arr[0]}" W2="${_w_arr[1]}" W3="${_w_arr[2]}" W4="${_w_arr[3]}" W5="${_w_arr[4]}" W5b="${_w_arr[5]}" W6="${_w_arr[6]}" WPOMO="${_w_arr[7]}"

  max_lw=0
  for w in "$W1" "$W2" "$W3" "$W4" "$W5" "$W5b" "$W6"; do
    [ -n "$w" ] && [ "$w" -gt "$max_lw" ] 2>/dev/null && max_lw=$w
  done

  # Render box (with optional weather on right)
  GAP="   "
  if [ -n "$w_hi" ] && [ -n "$w_box_color" ]; then
    printf "%s%s%s\n" "$(lbox_top "$lc" "$max_lw")" "$GAP" "$(wb_top "$w_box_color")"
    printf "%s%s%s\n" "$(lbox_line "$lc" "$L1" "$max_lw" "$W1")" "$GAP" "$(wb_line "$w_box_color" "$w_icons" "$w_hi" "$w_lo" "$w_wind")"
    printf "%s%s%s\n" "$(lbox_line "$lc" "$L2" "$max_lw" "$W2")" "$GAP" "$(wb_bot "$w_box_color")"
  else
    printf "%s\n" "$(lbox_top "$lc" "$max_lw")"
    printf "%s\n" "$(lbox_line "$lc" "$L1" "$max_lw" "$W1")"
    printf "%s\n" "$(lbox_line "$lc" "$L2" "$max_lw" "$W2")"
  fi
  # L3-L5 with optional pomo box on right
  if [ -n "$pomo_active" ]; then
    POMO_W=$W_BOX
    [ -n "$WPOMO" ] && [ "$WPOMO" -gt "$POMO_W" ] 2>/dev/null && POMO_W=$WPOMO

    [ -n "$L3" ] && printf "%s%s%s\n" "$(lbox_line "$lc" "$L3" "$max_lw" "$W3")" "$GAP" "$(pb_top "$pomo_box_color" "$POMO_W")"
    [ -n "$L4" ] && printf "%s%s%s\n" "$(lbox_line "$lc" "$L4" "$max_lw" "$W4")" "$GAP" "$(pb_line "$pomo_box_color" "$pomo_time_str" "$pomo_tomatoes" "$pomo_msg" "$POMO_W" "$WPOMO")"
    [ -n "$L5" ] && printf "%s%s%s\n" "$(lbox_line "$lc" "$L5" "$max_lw" "$W5")" "$GAP" "$(pb_bot "$pomo_box_color" "$POMO_W")"
    [ -n "$L5b" ] && printf "%s\n" "$(lbox_line "$lc" "$L5b" "$max_lw" "$W5b")"
  else
    [ -n "$L3" ] && printf "%s\n" "$(lbox_line "$lc" "$L3" "$max_lw" "$W3")"
    [ -n "$L4" ] && printf "%s\n" "$(lbox_line "$lc" "$L4" "$max_lw" "$W4")"
    [ -n "$L5" ] && printf "%s\n" "$(lbox_line "$lc" "$L5" "$max_lw" "$W5")"
    [ -n "$L5b" ] && printf "%s\n" "$(lbox_line "$lc" "$L5b" "$max_lw" "$W5b")"
  fi
  [ -n "$L6" ] && printf "%s\n" "$(lbox_line "$lc" "$L6" "$max_lw" "$W6")"
  printf "%s\n" "$(lbox_bot "$lc" "$max_lw")"
fi
