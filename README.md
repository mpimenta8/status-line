# status-line

A synthwave-styled status bar for [Claude Code](https://claude.ai/code) that shows model, effort level, context usage, and git state at a glance.

![Status line showing model, effort, context bar, and git info](effort-colors/effort_high.png)

## What it shows

```
  claude-sonnet-4-6  ◆ high  │  [████████████░░░░░░░░] 61% of context  │  Current: 34%  │  ✦ my-repo  main  ⬆ 2  ± 4
```

| Segment | Description |
|---|---|
| Model name | Active Claude model |
| `◆ effort` | Current effort level (`low` / `medium` / `high` / `xhigh` / `max`) |
| Context bar | Token usage vs. 200k context window, gradient cyan → purple → hot pink |
| Current % | Output tokens in the last 5 hours as a % of the hourly rate limit |
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
  "command": "/path/to/status-line/status.sh ${CLAUDE_SESSION_ID} ${CLAUDE_EFFORT}",
  "refreshInterval": 10
}
```

Replace `/path/to/status-line` with wherever you cloned it (e.g. `~/status-line`).

4. Restart Claude Code. The status line appears at the bottom of the terminal.

## Color palette

| Element | Color |
|---|---|
| Model name | `#4CC9F0` sky cyan |
| Effort `◆` | `#BF5FFF` neon purple |
| Bar 0–50% | cyan → purple gradient |
| Bar 50–100% | purple → `#FF2D78` hot pink |
| Bar empty | `#0C0416` near-black |
| Branch | `#FFE600` gold |
| Commits ahead `⬆` | `#67E8F9` soft cyan |
| Modified `±` | `#FF6EC7` pink |
