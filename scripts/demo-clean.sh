#!/bin/bash
# Clean demo: just show themed output, no commands visible
FIXTURE='{"workspace":{"current_dir":"/demo/my-project"},"model":{"display_name":"Opus 4.7"},"context_window":{"used_percentage":47},"cost":{"total_cost_usd":24.42}}'
SCRIPT="$(dirname "$0")/../neonhaze.sh"
STATE="$HOME/.claude/state/current-theme"
mkdir -p "$HOME/.claude/state"

for theme in neon cyberpunk gits eva akira; do
  clear
  echo "$theme" > "$STATE"
  printf "\n"
  echo "$FIXTURE" | COLUMNS=90 bash "$SCRIPT" 2>/dev/null
  printf "\n  \033[38;5;240m▸ /theme %s\033[0m\n" "$theme"
  sleep 2.5
done
echo "neon" > "$STATE"
