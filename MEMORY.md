# status-line — Project Memory

## What This Is
A single bash script (`status.sh`) that renders a synthwave-styled status bar in Claude Code, wired in via the `statusLine` setting in `~/.claude/settings.json`. A rendered preview lives at `assets/preview.svg` and is embedded in `README.md`.

## Design Spec
Original spec: `~/.claude/plans/yes-please-let-s-first-functional-quiche.md` (local, not in this repo). The usage-window rework, model-name cleanup, and pipe-spacing changes (below) were designed conversationally (brainstorm → AskUserQuestion → implement) without a separate written spec file — this MEMORY.md is the record of those decisions.

## Layout
```
  Opus 4.8  ◆ high │ [████████████░░░░░░░░] 61% context │ 16% used 1h 57m · 22% used 4d 10h │ ✦ my-repo  main  ⬆ 2  ± 4
```

## Color Palette (Synthwave / Truecolor)
| Element | Hex |
|---|---|
| Model name | `#4CC9F0` Sky Cyan |
| Effort `◆` low | `#EAB308` Amber |
| Effort `◆` medium | `#22C55E` Green |
| Effort `◆` high | `#6366F1` Indigo |
| Effort `◆` xhigh | Pulsing purple animation (`#64201B` base → `#F5E1FF` bright) |
| Effort `◆` max | Rainbow cycle (red → amber → cyan → teal → blue → magenta) |
| Bar 0–50% | `#4CC9F0` → `#9D4EDD` gradient |
| Bar 50–100% + `!` at 70% | `#9D4EDD` → `#FF2D78` gradient |
| Bar empty | `#0C0416` Near-black |
| Session/weekly `% used` | Same bar gradient, scaled so full pink hits at 90% utilization (see Usage Windows) |
| Reset countdowns | `#808094` Muted gray |
| Repo icon + name | `#B7A8ED` Lavender |
| Branch | `#FFE600` Gold *(defined but unused — see Known Gaps)* |
| `⬆` ahead | `#67E8F9` Soft Cyan |
| `±` modified | `#FF6EC7` Pink |

## Usage Windows (replaced the old S:/M: token segments — 2026-07-21)
- Shows Claude Code's **native session (5h)** and **weekly (7d)** rate-limit usage — the same numbers behind its own "X% used" banner — not a self-computed estimate.
- Source: `~/.claude.json` → `cachedUsageUtilization.utilization.{five_hour,seven_day}`, each with `.utilization` (int %) and `.resets_at` (ISO timestamp). Claude Code refreshes this file itself (~1 min cadence); the script only reads it.
- Reset countdown formatted from `resets_at`: `Xd Xh` (≥1 day) / `Xh Xm` / `Xm`.
- **Gradient scaling is deliberately not 1:1.** The percent number is mapped via `T = min(pct * 1000 / 90, 1000)` into the shared `grad()` helper, so full pink is reached at **90%** utilization, not 100% — the warning color shows up before you actually hit the limit. Was: "if the position-based bar gradient would put pink lower than 90%, use the lower value" — since the usage mapping is always ≤ the bar's 100%-based mapping, dividing by 90 automatically satisfies that.
- If `~/.claude.json` is missing or `cachedUsageUtilization` isn't populated yet, the **entire zone is hidden**, including its own leading `│` divider — no fallback to token counts.
- `USAGE_OK`, `SESS_PCT`, `WEEK_PCT`, `SESS_RESET`, `WEEK_RESET` are the eval'd shell vars carrying this from the python block.

## Removed (2026-07-21)
- **`S:`/`M:` token-count segments.** `S:` was session context tokens colored against a hardcoded median (`MEDIAN_SESSION=776512`); `M:` was a monthly token sum scanned across every JSONL transcript under `~/.claude/projects`, cached 60s at `/tmp/claude_monthly_tokens`. Replaced by the Usage Windows above — more accurate (it's Claude's own number) and removes a full-transcript-tree walk from the per-refresh hot path.
- The `fmt()` `##.#K`/`##.#M` token formatter (no longer needed without token counts to format).

## Model Name Formatting (2026-07-23)
- Raw stdin `model.id` (e.g. `claude-opus-4-8`) is prettified by `pretty_model()` in the python block: strip the `claude-` prefix, capitalize the family name, join the remaining parts with `.`, and drop any 8-digit numeric suffix (handles date-suffixed ids like `claude-haiku-4-5-20251001`).
- Examples: `claude-opus-4-8` → `Opus 4.8`, `claude-sonnet-5` → `Sonnet 5`, `claude-sonnet-4-6` → `Sonnet 4.6`, `claude-fable-5` → `Fable 5`.
- `MODEL` is emitted from python **double-quoted** (`MODEL="Opus 4.8"`) since the pretty name contains a space — unquoted, `eval` splits it and tries to run the second word as a command. Same failure mode bit `SESS_RESET`/`WEEK_RESET` (values like `4d 10h`) during the usage-window work; both now use `\"..\"` from python rather than bash `'..'` (the python source itself is inside a single-quoted bash string, so a literal `'` in the printed value closes it early).

## Shared Gradient Helper
- `grad()` (bash function) replaces what used to be an inline two-stop lerp duplicated only in the bar-drawing loop.
- Same cyan(`76,201,240`) → purple(`157,78,221`) → pink(`255,45,120`) two-stop interpolation over `T` in `0..1000`. The context bar keys `T` to block position (0–1000 across 20 blocks); the usage percentages key `T` to utilization scaled to hit pink at 90% (see above). Both draw from the one function so they can't visually drift apart.

## Divider Spacing (2026-07-23)
- Every `│` segment divider is a single space on each side (`" │ "`), down from two (`"  │  "`).
- Non-pipe spacing elsewhere (model↔effort gap, and inside the git segment between repo-name/branch/ahead/modified) is untouched — only pipe-adjacent padding was tightened.
- `USAGE_SEGMENT` carries its own leading `" │ "` and ends with **no trailing space** — if it also had a trailing space, it would stack with `GIT_SEGMENT`'s leading `" │ "` into a double space. When the usage zone is hidden (`USAGE_OK=0`), `GIT_SEGMENT`'s leading pipe attaches directly after the context label with no orphaned double-space.

## README Preview Image (2026-07-23)
- `assets/preview.svg` — not a real terminal screenshot. Generated by capturing `status.sh`'s actual stdout (with a representative stdin payload), parsing the `\x1b[38;2;R;G;Bm...\x1b[0m` truecolor runs, and re-emitting them as `<tspan fill="rgb(...)">` chunks inside one `<text>` element (SVG auto-flows sequential tspans, so no manual monospace-width math was needed) inside a mock terminal window (rounded dark panel + mac traffic-light dots).
- The generator script was **not** committed — it was a one-off in a scratch dir. To regenerate after a future format change: capture output → regex-parse the ANSI runs → emit tspans → wrap in the terminal-chrome SVG shell (background gradient `#160B26`→`#0B0614`, 3 traffic-light circles top-left, monospace font stack `SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', monospace`).
- `file://` URLs are blocked in the Chrome automation extension for previewing — serve over local `python3 -m http.server` (with `run_in_background: true`, not a bare `&`, or the harness reaps the process) and navigate the browser tab there. Also: navigating directly to an `.svg` URL hits Chrome's internal image viewer, which the extension can't screenshot — wrap it in a trivial `<img>` HTML page and navigate to that instead.

## Repo Icon Pool (deterministic by repo name hash)
```
◈ ⬡ ✦ ◉ ⊕ ★ ◎ ✧ ⬢ ⊙ ◇ ✴ ♠ ♥ ♦ ♣
```

## Settings Entry
```json
"statusLine": {
  "type": "command",
  "command": "/path/to/status-line/status.sh ${CLAUDE_CODE_SESSION_ID} ${CLAUDE_EFFORT}",
  "refreshInterval": 1
}
```

## Key Implementation Notes
- `${CLAUDE_CODE_SESSION_ID}` and `${CLAUDE_EFFORT}` are baked into the command string by Claude Code (not env vars)
- `refreshInterval` is 1s — smooth `max` animation. With the monthly scan removed, the python block is now just one `~/.claude.json` read plus (usually skipped) transcript fallbacks — cheaper per refresh than before, not more expensive.
- Session JSONL path: `~/.claude/projects/<cwd-with-slashes-as-dashes>/<session-id>.jsonl`
  - Slug formula: `re.sub(r"[/.]", "-", cwd)` — leading `/` becomes a leading `-`, do NOT strip it
  - Script tries the direct path first; falls back to recursive glob if it misses (different cwd than session origin)
  - Last assistant entry read via tail-from-end byte seek (O(chunk) not O(filesize)) to stay fast as sessions grow
- All python3 work (model, tokens, usage windows) runs in a single invocation; output `eval`'d as shell variables
- The python3 block lives inside a shell single-quoted string — Python string literals **and comments** must use `"..."` not `'...'` (an apostrophe in a comment like `didn't` silently breaks shell quoting → `unexpected EOF` at the bottom of the file). Same rule bit the `MODEL=`/`SESS_RESET=`/`WEEK_RESET=` print lines when their *values* (not just source code) contained characters that mattered to the outer shell — see Model Name Formatting above.
- Model is read from the **stdin JSON payload** (`model.id`) that Claude Code pipes on every refresh — this reflects the *currently selected* model, so it updates the instant you `/model` switch (the transcript's `message.model` only changes after the next assistant turn, which caused a 1–2 prompt lag). Stdin is captured once at the top of the script (`STDIN_JSON=$(cat)`) and passed to python via env var.
  - Fallbacks if stdin is empty: last assistant entry in session JSONL → most recent assistant entry across all sessions (handles new session / post-`/clear` state)
  - Other useful stdin fields not yet surfaced: `cost`, `session_name`, `workspace.repo`
- Context bar token count = `input_tokens + cache_creation_input_tokens + cache_read_input_tokens`, taken from `context_window.current_usage` in the stdin payload; falls back to the last assistant entry's `usage` if stdin is unavailable
- When stdin supplies both model and token count, the transcript tail-read is skipped entirely (cheaper common path)
- Alert `!` appears in hot pink when context bar hits 70%
- Max context: **dynamic** — read from stdin `context_window.context_window_size` (200K for older models, **1M** for Opus 4.8); falls back to 200000 when stdin is unavailable
- Git "ahead" falls back from `main` → `master` → shows `⬆ 0`
- Git segment omitted silently outside a git repo
- MEMORY.md is tracked in this repo — it's the design record, so it lives with the code it describes

## Known Gaps (deferred)
- **Branch not rendered in gold** — `GLD` is defined but `BRANCH` has no color wrapper; trivial one-liner fix
- **No automated tests** — all verification so far has been manual (`bash -n`, running the script against sample stdin payloads and a fake `HOME` for the cache-miss path)
