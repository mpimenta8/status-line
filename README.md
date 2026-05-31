# status-line

A synthwave-styled status bar for [Claude Code](https://claude.ai/code) that shows model, effort level, context usage, and git state at a glance.

> Synthwave-styled status bar rendered at the bottom of Claude Code's terminal.

## What it shows

```
  claude-sonnet-4-6  ◆ high  │  [████████████░░░░░░░░] 61% of context  │  S: 84.2K  M: 2.1M  │  ✦ my-repo  main  ⬆ 2  ± 4
```

| Segment | Description |
|---|---|
| Model name | Active Claude model |
| `◆ effort` | Current effort level (`low` / `medium` / `high` / `xhigh` / `max`) |
| Context bar | Token usage vs. 200k context window, gradient cyan → purple → hot pink |
| `S:` | Session context tokens (input + cache), colored by usage vs. median |
| `M:` | All tokens this calendar month, resets on the 1st |
| Git | Repo icon (deterministic), branch, commits ahead of main, modified files |

The context bar and effort display animate at higher levels — `xhigh` pulses, `max` cycles through rainbow colors.

## Requirements

- macOS or Linux with a truecolor terminal
- `python3` (standard on both)
- Claude Code with `statusLine` support

## Installation

1. Clone the repo somewhere permanent:

```bash
git clone https://github.com/matthewpimenta/status-line.git ~/status-line
```

2. Make the script executable:

```bash
chmod +x ~/status-line/status.sh
```

3. Add this to your `~/.claude/settings.json` under the top-level object:

```json
"statusLine": {
  "type": "command",
  "command": "/path/to/status-line/status.sh ${CLAUDE_CODE_SESSION_ID} ${CLAUDE_EFFORT}",
  "refreshInterval": 1
}
```

Replace `/path/to/status-line` with wherever you cloned it (e.g. `~/status-line`).

4. Restart Claude Code. The status line appears at the bottom of the terminal.

## Color palette

| Element | Color |
|---|---|
| Model name | `#4CC9F0` sky cyan |
| `◆ low` | `#EAB308` amber |
| `◆ medium` | `#22C55E` green |
| `◆ high` | `#6366F1` indigo |
| `◆ xhigh` | Pulsing purple animation |
| `◆ max` | Rainbow cycle (red → amber → cyan → teal → blue → magenta) |
| Bar 0–50% | `#4CC9F0` → `#9D4EDD` gradient |
| Bar 50–100% | `#9D4EDD` → `#FF2D78` gradient |
| Bar empty | `#0C0416` near-black |
| `S:` session tokens | Cyan / lavender / hot pink / gold by usage level |
| `M:` monthly tokens | `#B7A8ED` lavender |
| Branch | `#FFE600` gold |
| Commits ahead `⬆` | `#67E8F9` soft cyan |
| Modified `±` | `#FF6EC7` pink |
