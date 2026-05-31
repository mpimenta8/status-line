# Plan Review — "1s refresh interval + MEMORY.md sync"

**Plan reviewed:** `~/.claude/plans/thank-you-can-you-cached-dragon.md`
**Date:** 2026-05-30
**Repo HEAD at review:** `06d8e77` (Consolidate python3 calls into one and cache monthly tokens for 60s)
**Environment when measured:** this repo; `~/.claude/projects` = 118 JSONL files, ~34M total; `python3` warm/cold timings below.

---

## Verdict

The **core change is sound and its premise is confirmed by live numbers** — but the plan is scoped too narrowly, contains a self-contradiction it will bake into the docs, and ignores the public-facing README, which is materially broken. There is also one latent bug in the existing code the plan waves past ("S:/M: already current").

**Live measurements (`status.sh "" "max"`, warm/cold):**

| Run | Cost |
|---|---|
| Cold (cache miss, full 34M scan over 118 files) | ~190 ms |
| Warm (cache hit) | ~82–89 ms |

The plan's "200ms → 80ms" is accurate, and since the expensive scan runs only 1-in-60 refreshes, **1s is affordable.** The animation rationale also holds (see §3). Green-light the idea; tighten the execution.

> **Caveat on the benchmark:** these numbers were taken with an *empty* session id, which skips the single most expensive per-refresh operation in real use (reading the active session JSONL). See §3.

---

## 1. Fix the doc-drift the plan will *create* ⚠️

The plan's Change 1 is correct that the current value is **2** (`settings.json:20`, confirmed live). But:

- **`MEMORY.md:54` says `"refreshInterval": 10`** and **`README.md:50` says `10`** — both already wrong (reality is 2), and the plan's Change 2 (MEMORY update) **does not touch the Settings Entry block**. After executing the plan, MEMORY will document `10` while reality becomes `1`. The plan changes the value but updates a *different* part of the same file. **Add: update `MEMORY.md:54` (and `README.md:50`) to the real value.**
- **Wrong env var in both docs.** `settings.json:19` correctly uses `${CLAUDE_CODE_SESSION_ID}` (commit `c459743` fixed this). But `MEMORY.md:52` and **`README.md:48` still show `${CLAUDE_SESSION_ID}`** — the old, non-expanding name. Anyone copy-pasting the README install snippet gets an empty session id → no `S:` counter, model falls back to the scan-all path. For a repo prepped for public release, this is the highest-impact doc bug, and the plan does not mention README at all.

## 2. The public README is stale and visibly broken on GitHub 🐞

Repo was prepped for public release (commit `6a03a92`), but `git ls-files` tracks only `.gitignore`, `README.md`, `status.sh`. Consequences:

- **Broken hero image.** `README.md:5` embeds `effort-colors/effort_high.png`, but `.gitignore:2` ignores `effort-colors/` — the PNGs exist locally but **aren't committed**, so the image is a broken link on GitHub. Either `git add -f` the images (or a subset) or drop the embed.
- **Describes a removed feature.** `README.md:10` and `:18` still document the old `Current: 34%` / "output tokens in the last 5 hours" segment, which commit `774bf53` *replaced* with `S:`/`M:`.
- **Stale palette.** `README.md:59–68` lists the old single-color effort (`◆ #BF5FFF`), not the per-level amber/green/indigo/pulse/rainbow scheme the code now implements.

If "MEMORY.md sync" is the goal, README is the bigger gap — and it's the one strangers see.

## 3. Is 1s actually safe? Mostly yes — but the benchmark hides the real hot path 🧊

The 80ms warm number was measured (in the plan *and* here) with `status.sh "" "max"` — an **empty session id**, which skips the most expensive per-refresh work in real use:

- **Every refresh** (not cached) the script does a **recursive `**` glob over all of `~/.claude/projects`** (`status.sh:39–42`) and then **reads the entire active session JSONL** to grab only the last assistant line (`status.sh:46` builds a list of *all* assistant lines, keeps `[-1]`). That is **O(session size) every second**, and session files grow without bound.
- **The git segment spawns ~6 subprocesses every refresh** (`status.sh:177–196`: `rev-parse`, `show-toplevel | xargs basename`, `branch`, `rev-parse --verify`, `rev-list`, `status --porcelain`). Free in this tiny repo; in a large monorepo `git status --porcelain` alone can be 100ms+. At 1s with several panes open, that is real continuous load.
- The cold monthly scan grows through the month: **all 118 files were modified since May 1**, so the mtime pre-filter (commit `1a4ebc6`) currently skips **zero** files — it only pays off across month boundaries.

None of this is fatal — caching keeps the *typical* refresh ~85ms — but "1s is safe" rests on a measurement that omits the two things that actually scale. The upgrades in §4 make 1s cheap *everywhere*.

**Animation rationale (correct):** the `max` color is keyed to whole-second `date +%s … % 6` (`status.sh:225,233`). At `refreshInterval:2` you sample every other frame → choppy; at `1` you see every frame → smooth. Corollary: **1s is the floor that helps** — sub-second intervals buy nothing because the animation only changes on whole-second boundaries. >1fps animation would require sub-second time (`$EPOCHREALTIME`) *and* a sub-second interval. Also worth a 30-second check that CC honors `1` specifically (it clearly honors `2`; there may be a sub-2s floor).

## 4. Implementation upgrades that make 1s genuinely cheap 🚀

In rough value order:

1. **Drop the recursive session glob for direct path construction.** The project dir is deterministic: `/Users/echo/code/status-line` → `-Users-echo-code-status-line`. So `proj = ~/.claude/projects/ + cwd.replace('/','-').replace('.','-')`, then stat `proj/<session>.jsonl` directly; keep the glob as a fallback. Turns an O(118-dir walk) into one stat. `MEMORY.md:59` already documents this path formula — the code just doesn't use it.
2. **Tail the session file instead of reading it whole.** Seek from the end, scan backward for the last `"type":"assistant"` line. Removes the O(filesize)/second cost.
3. **Make the monthly-cache write atomic.** `status.sh:117–118` does `open(path,"w")`; at `refreshInterval:1` with multiple panes, two processes can cross the 60s boundary together and a reader can hit a half-written file → `int(fh.read().strip())` (`:87`) raises → bare `except` → `M:` flickers to `0`. Write to `path.tmp` then `os.replace()`, and guard the int parse.
4. **Cache/cheapen the git segment.** A short TTL cache keyed on repo+HEAD, or at minimum tune `git status` (`-uno` / `--no-optional-locks`). This is the dominant cost in real repos at 1s.

## 5. Latent bug the plan calls "already current": the `S:` color is dead 🟡

`S:` displays `used_tokens` = the **context snapshot** (`input + cache_creation + cache_read` of the last entry, ≤ ~200K), but colors it against **`MEDIAN_SESSION=776512`** (`status.sh:24,141`). A 200K-capped snapshot reaches at most `200000/776512 ≈ 26%`, so it is **always below the 50% threshold → always cyan**. The lavender / hot-pink / gold branches (`status.sh:143–145`, the four-row scale in `MEMORY.md:26–29`) are unreachable dead code. Decide the intent:

- If `S:` should mean *cumulative* session usage, sum usage across the session's entries (scales toward 776K, colors come alive); **or**
- If `S:` is the context snapshot, recalibrate the baseline to snapshot scale (~120–150K), not 776K.

Related: `MAX_TOKENS=200000` (`status.sh:134`) hard-caps the bar at 100% — for 1M-context models the bar saturates exactly when usage gets interesting.

## 6. Smaller notes 🔧

- **Branch isn't gold.** `status.sh:195` interpolates `${BRANCH}` with no color (confirmed: `main` renders default), yet `MEMORY.md:32` / `README.md:66` claim gold. `GLD` (`:17`) is defined but unused — wrap the branch in `${GLD}…${RST}`. (`CYN`, `PUR`, `MID` are also defined-but-unused; `shellcheck` SC2034 would catch all four — it's **not installed**, worth `brew install shellcheck` + a lint pass.)
- **`eval "$(python3 …)"`** (`status.sh:26,126`) executes stdout as shell. Safe today (model id, integers), but a `mapfile`/`read` parse avoids the eval-injection smell.
- **Silent-by-design** (`2>/dev/null` + bare `except: pass`) is right for a status line but hides failures — a `STATUSLINE_DEBUG` env gate that unsuppresses would help debugging.
- **`xargs basename`** (`status.sh:178`) breaks on repo paths with spaces; use `basename "$(…)"`.
- **Month boundary is UTC** (`status.sh:89–90`); `M:` resets at UTC midnight on the 1st, not local. Fine if intended; worth one word of doc.

---

## Revised plan

Keep Change 1, but make it precise and complete:

- **Change 1:** `settings.json` → `statusLine.refreshInterval: 2 → 1` (specify the *nested* key). Verify 1s is honored.
- **Change 2 (docs — expand):** in `MEMORY.md` *and* `README.md`, fix the `refreshInterval` value **and** the `${CLAUDE_SESSION_ID}` → `${CLAUDE_CODE_SESSION_ID}` typo; in README, replace the dead `Current %` segment + old palette, and fix/remove the broken image embed.
- **Verification (strengthen):** `time` a run with a **real** session id *inside a large repo* (not `"" "max"`); confirm `M:` doesn't flicker to 0 across a cache expiry with two panes open; run `shellcheck`.
- **Optional but high-value:** fold in §4.1–4.2 (direct path + tail read) so 1s is cheap regardless of session/repo size, and decide the §5 `S:` semantics.

## Recommended next actions (tiers)

1. **Minimal:** corrected plan (interval + all doc fixes) — small, safe, ships the smooth animation today.
2. **Minimal + perf:** add §4.1–4.2 (direct path + tail read) so 1s is genuinely cheap.
3. **Full pass:** the above plus the §5 `S:` color fix, branch-gold fix, atomic cache, and a `shellcheck` cleanup.
