# StatusDock

A multi-panel, themed HUD status dock for Claude Code and terminal applications.

> **Status Dock** — More than a status line. A docked, multi-panel heads-up display with live data, box-drawing frames, and switchable cyberpunk themes.

## What is this?

StatusDock turns your Claude Code status line into a cyberpunk HUD with multiple information panels:

```
╔═════════════════════════╗   ╔════════════════════════════════════╗
║ musubie-net git:(main)  ║   ║ ☁️ ☁️ ⛅ ☀️ ⛅ │ 23/10 │  💨 3km/h   ║
║ Opus 4.7 $24.42         ║   ╚════════════════════════════════════╝
║ ctx:▰▰▰▰▰▱▱▱▱▱47%       ║   ╔════════════════════════════════════╗
║ 5h :▰▰▰▰▱▱▱▱▱▱37%(1h)   ║   ║  🍅 18:32  🍅🍅🍅  🌊FLOW            ║
║ 7d :▰▰▰▱▱▱▱▱▱▱35%(4d)   ║   ╚════════════════════════════════════╝
╚═════════════════════════╝
```

## Features

- **Multi-panel HUD** — Left info box + right data boxes with box-drawing borders
- **5 built-in themes** — Switch instantly with `/theme <name>`
- **Weather panel** — 5-hour forecast from Open-Meteo API (10-min cache)
- **Pomodoro timer** — 25min work + 5min break cycles with stage messages
- **Usage bars** — Context window, 5-hour, 7-day quota with color-coded progress
- **Git integration** — Project name, branch, diff stats (+N -M)
- **Theme engine** — All colors defined in swappable theme files

## Themes

| Theme | Inspiration | Palette |
|-------|-------------|---------|
| `neon` | Gaming / Neon signs | Green frames, cyan/pink/purple accents |
| `cyberpunk` | Blade Runner 2049 | Amber/orange, rain-soaked darkness |
| `gits` | Ghost in the Shell | Matrix green monochrome |
| `eva` | Evangelion EVA-01 | Purple body, green eyes, orange highlights |
| `akira` | AKIRA / Neo-Tokyo | Kaneda red, crimson night city |

Switch themes:
```
/theme gits
```

## Installation

### Claude Code

1. Copy `statusdock.sh` to `~/.claude/statusline-command.sh`
2. Copy `themes/` to `~/.claude/themes/`
3. Copy `commands/` to `~/.claude/commands/`
4. Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh",
    "refreshInterval": 1
  }
}
```

5. Set your theme:
```bash
mkdir -p ~/.claude/state
echo "neon" > ~/.claude/state/current-theme
```

### Weather (optional)

Weather works out of the box with Tokyo coordinates. To change location:

```bash
export CLAUDE_WEATHER_LAT=40.7128   # New York
export CLAUDE_WEATHER_LON=-74.0060
```

### Pomodoro

```
/pomo           # Start 25-min pomodoro
/pomo stop      # Pause (box stays visible)
/pomo done      # Complete manually
/pomo status    # Check state
```

## Creating Themes

Create `~/.claude/themes/mytheme.sh`:

```bash
#!/bin/bash
# Status Dock Theme: My Theme

T_FRAME="\033[38;5;46m"        # box frame color
T_PROJECT="\033[38;5;51m"      # project name
T_BRANCH="\033[38;5;141m"      # git branch
T_BADGE="\033[38;5;197m"       # [N] badge
T_DIRTY="\033[38;5;226m"       # dirty marker
T_SENSEI="\033[38;5;46m"       # sensei badge
T_COST="\033[38;5;60m"         # cost/dim text
T_MODEL="\033[38;5;60m"        # model name

# Bar colors (good <50%, mid 50-80%, bad >80%)
T_BAR_GOOD="\033[38;5;46m"
T_BAR_GOOD_DIM="\033[38;5;28m"
T_BAR_MID="\033[38;5;226m"
T_BAR_MID_DIM="\033[38;5;136m"
T_BAR_BAD="\033[38;5;197m"
T_BAR_BAD_DIM="\033[38;5;125m"

# Weather
T_TEMP_HI="\033[38;5;208m"
T_TEMP_LO="\033[38;5;123m"
T_WIND="\033[38;5;75m"
T_WEATHER_CLEAR="\033[38;5;118m"
T_WEATHER_CLOUD="\033[38;5;214m"
T_WEATHER_FOG="\033[38;5;103m"
T_WEATHER_RAIN="\033[38;5;45m"
T_WEATHER_SNOW="\033[38;5;159m"
T_WEATHER_THUNDER="\033[38;5;196m"

# Pomodoro
T_POMO_TIMER="\033[38;5;198m"
T_POMO_START="\033[38;5;201m"
T_POMO_MID="\033[38;5;214m"
T_POMO_FLOW="\033[38;5;118m"
T_POMO_FIRE="\033[38;5;208m"
T_POMO_BREAK="\033[38;5;45m"
T_POMO_IDLE="\033[38;5;75m"
T_POMO_URGENT="\033[38;5;196m"
```

Then: `/theme mytheme`

## Architecture

```
statusdock/
├── statusdock.sh      # Main status dock script
├── themes/            # Theme files
│   ├── neon.sh
│   ├── cyberpunk.sh
│   ├── gits.sh
│   ├── eva.sh
│   └── akira.sh
├── commands/          # Claude Code slash commands
│   ├── pomo.md        # /pomo command
│   └── theme.md       # /theme command
└── scripts/           # Demo/mock scripts
    └── demo-mock.sh
```

## Roadmap

- [ ] YAML/TOML declarative block definition DSL
- [ ] Plugin system for custom data sources
- [ ] Rust rewrite for <5ms startup
- [ ] Template gallery website
- [ ] Community theme submissions

## License

MIT License - see [LICENSE](LICENSE)

## Author

Created by [@snakajim](https://github.com/snakajim)
