# status-line — Project Memory

## What This Is
A single bash script (`status.sh`) that renders a synthwave-styled status bar in Claude Code, wired in via the `statusLine` setting in `~/.claude/settings.json`.

## Design Spec
Full spec: `~/.claude/plans/yes-please-let-s-first-functional-quiche.md`

## Layout
```
  claude-sonnet-4-6  ◆ medium  │  [████████████░░░░░░░░] 61%  │  ✦ my-repo  main  ⬆ 2  ± 4
```

## Color Palette (Synthwave / Truecolor)
| Element | Hex |
|---|---|
| Model name | `#4CC9F0` Sky Cyan |
| Effort `◆` | `#BF5FFF` Neon Purple |
| Dividers `│` | `#6B21A8` Dim Violet |
| Bar 0–40% | `#4CC9F0` Sky Cyan |
| Bar 40–70% | `#9D4EDD` Purple |
| Bar 70–100% + `!` | `#FF2D78` Hot Pink |
| Bar empty | `#1E0A3C` Dark Navy |
| Repo icon + name | `#39FF14` Neon Green |
| Branch | `#FFE600` Gold |
| `⬆` ahead | `#67E8F9` Soft Cyan |
| `±` modified | `#FF6EC7` Pink |

## Repo Icon Pool (deterministic by repo name hash)
```
◈ ⬡ ✦ ◉ ⊕ ★ ◎ ✧ ⬢ ⊙ ◇ ✴ ♠ ♥ ♦ ♣
```

## Settings Entry
```json
"statusLine": {
  "type": "command",
  "command": "/Users/echo/code/status-line/status.sh ${CLAUDE_SESSION_ID} ${CLAUDE_EFFORT}",
  "refreshInterval": 10
}
```

## Key Implementation Notes
- `${CLAUDE_SESSION_ID}` and `${CLAUDE_EFFORT}` are baked into the command string by Claude Code (not env vars)
- Session JSONL path: `~/.claude/projects/<cwd-with-slashes-as-dashes>/<session-id>.jsonl`
- Token count = `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` from last assistant entry
- Max context: 200,000 (hardcoded, all current claude-* models)
- Git "ahead" falls back from `main` → `master` → shows `⬆ 0`
- Git segment omitted silently outside a git repo
