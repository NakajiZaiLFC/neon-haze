Start, stop, or check a pomodoro timer.

Usage: /pomo [start|stop|done|status]
- No argument or "start": Start a 25-minute pomodoro
- "stop": Cancel current pomodoro
- "done": Manually complete current pomodoro
- "status": Show current state

$ARGUMENTS

Please execute the pomodoro command based on the argument:

If no argument or "start":
- Run: `mkdir -p ~/.claude/state && date +%s > ~/.claude/state/pomo-start && echo work > ~/.claude/state/pomo-phase`
- If `~/.claude/state/pomo-count` doesn't exist, create it with `echo 0 > ~/.claude/state/pomo-count`
- Respond: "🍅 ポモドーロ開始。25分間集中。"

If "stop":
- Run: `rm -f ~/.claude/state/pomo-start && echo idle > ~/.claude/state/pomo-phase`
- Respond: "⏹ ポモドーロ中断。"

If "done":
- Read current count from `~/.claude/state/pomo-count` (default 0), increment by 1, write back
- Run: `rm -f ~/.claude/state/pomo-start && echo idle > ~/.claude/state/pomo-phase`
- Respond: "✅ ポモドーロ完了。今日 N 回目。"

If "status":
- Read `pomo-phase`, `pomo-count`, and if `pomo-start` exists, calculate remaining time
- Respond with current state summary

Always ensure `~/.claude/state/` directory exists first: `mkdir -p ~/.claude/state`
