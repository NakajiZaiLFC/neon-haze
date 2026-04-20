#!/bin/bash
# Theme comparison: render all 9 themes side by side
FIXTURE='{"workspace":{"current_dir":"/demo/project"},"model":{"display_name":"Opus 4.6 (1M context)"},"context_window":{"used_percentage":63},"cost":{"total_cost_usd":42.00}}'
SCRIPT="$HOME/.claude/statusline-command.sh"
STATE="$HOME/.claude/state/current-theme"
mkdir -p "$HOME/.claude/state"

# Remove weather/pomo to show pure theme colors
WEATHER_CACHE="$HOME/.cache/claude-statusline/weather-cache"
POMO_START="$HOME/.claude/state/pomo-start"
_w_backup=""; _p_backup=""
[ -f "$WEATHER_CACHE" ] && _w_backup=$(cat "$WEATHER_CACHE") && rm -f "$WEATHER_CACHE"
[ -f "$POMO_START" ] && _p_backup=$(cat "$POMO_START") && rm -f "$POMO_START"

# Set mock GitHub pushes
echo "7" > "$HOME/.cache/claude-statusline/github-pushes"

THEMES=(neon cyberpunk gits eva akira hitchhiker bladerunner eden tachikoma)

if [ "$1" = "loop" ]; then
  # Cycling mode: one at a time, 3 seconds each
  for theme in "${THEMES[@]}"; do
    clear
    echo "$theme" > "$STATE"
    printf "\n  \033[1;37m── %s ──\033[0m\n\n" "$theme"
    echo "$FIXTURE" | COLUMNS=90 bash "$SCRIPT" 2>/dev/null
    printf "\n"
    sleep 3
  done
else
  # Grid mode: all themes listed
  clear
  printf "\n  \033[1;37m═══ Neon Haze Theme Comparison ═══\033[0m\n"
  for theme in "${THEMES[@]}"; do
    echo "$theme" > "$STATE"
    printf "\n  \033[38;5;240m── %s ──\033[0m\n" "$theme"
    echo "$FIXTURE" | COLUMNS=90 bash "$SCRIPT" 2>/dev/null
  done
  printf "\n"
fi

# Restore
echo "neon" > "$STATE"
[ -n "$_w_backup" ] && echo "$_w_backup" > "$WEATHER_CACHE"
[ -n "$_p_backup" ] && echo "$_p_backup" > "$POMO_START"
