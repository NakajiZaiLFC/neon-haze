Switch the Status Dock color theme.

Usage: /theme [name]
Available themes: neon, cyberpunk, gits, eva, akira

$ARGUMENTS

Execute the theme switch:

1. Run `ls ~/.claude/themes/*.sh | sed 's|.*/||;s|\.sh||'` to list available themes
2. If no argument given, list available themes and show current theme from `cat ~/.claude/state/current-theme 2>/dev/null || echo neon`
3. If argument given, check if `~/.claude/themes/<argument>.sh` exists
   - If yes: `echo <argument> > ~/.claude/state/current-theme`
   - If no: show error and list available themes
4. Respond with the new active theme name: "🎨 テーマ切替: <name>"
