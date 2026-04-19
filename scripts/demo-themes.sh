#!/bin/bash
# Neon Haze — Theme Demo (screen record this with Cmd+Shift+5)
FIXTURE='{"workspace":{"current_dir":"/Users/nassy/projects/neon-haze"},"model":{"display_name":"Opus 4.7"},"context_window":{"used_percentage":47},"cost":{"total_cost_usd":24.42}}'
SCRIPT="$(dirname "$0")/../neonhaze.sh"
STATE="$HOME/.claude/state/current-theme"

mkdir -p "$HOME/.claude/state"

for theme in neon cyberpunk gits eva akira; do
  clear
  echo "$theme" > "$STATE"
  printf "\n  \033[38;5;240m── theme: \033[1;37m%s \033[38;5;240m──\033[0m\n\n" "$theme"
  echo "$FIXTURE" | COLUMNS=90 bash "$SCRIPT" 2>/dev/null
  printf "\n"
  sleep 3
done

# Restore neon
echo "neon" > "$STATE"
clear
printf "\n  \033[38;5;46m✓ Demo complete. Theme restored to neon.\033[0m\n\n"
