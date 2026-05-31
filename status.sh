#!/usr/bin/env bash
# Claude Code status line — synthwave edition

SESSION_ID="${1:-}"
EFFORT="${2:-}"

# Claude Code pipes a fresh JSON payload on stdin every refresh; its model.id
# reflects the *currently selected* model, so it updates the instant you /model
# switch (the transcript only gets a new model after the next assistant turn).
STDIN_JSON=$(cat)

# ── Colors (truecolor) ──────────────────────────────────────────────────────
c()  { printf '\e[38;2;%s;%s;%sm' "$1" "$2" "$3"; }
rst(){ printf '\e[0m'; }

CYN=$(c 76 201 240)   # #4CC9F0 sky cyan       — model name, bar low
PUR=$(c 191 95 255)   # #BF5FFF neon purple     — effort
LAV=$(c 183 168 237)  # #B7A8ED soft lavender   — repo icon + name
MID=$(c 157 78 221)   # #9D4EDD purple           — bar mid
HOT=$(c 255 45 120)   # #FF2D78 hot pink         — bar high + !
DRK=$(c 12 4 22)      # #0C0416 near-black purple — empty bar blocks
GLD=$(c 255 230 0)    # #FFE600 gold             — branch
SCY=$(c 103 232 249)  # #67E8F9 soft cyan        — ⬆ ahead
PNK=$(c 255 110 199)  # #FF6EC7 pink             — ± modified
RST=$(rst)

# ── Single python3 call: model, tokens, monthly (cached 60s) ─────────────────
# Median session tokens — update periodically (see MEMORY.md for command)
MEDIAN_SESSION=776512

eval "$(SESSION_ID="$SESSION_ID" STDIN_JSON="$STDIN_JSON" python3 -c '
import json, os, glob, re, datetime, time

home = os.path.expanduser("~")
session_id = os.environ.get("SESSION_ID", "")
cache_path = "/tmp/claude_monthly_tokens"
cache_ttl = 60

# ── Session: model + token count ──────────────────────────────────────────────
model = ""
used_tokens = 0
max_tokens = 0

# Live stdin payload — updates instantly on /model switch and carries the
# authoritative context-window figures Claude Code itself reports (the real
# window size varies by model: e.g. 200K for older models, 1M for Opus 4.8).
try:
    payload = json.loads(os.environ.get("STDIN_JSON", ""))
except:
    payload = {}
model = (payload.get("model") or {}).get("id", "") or ""
cw = payload.get("context_window") or {}
cu = cw.get("current_usage") or {}
if cu:
    used_tokens = (cu.get("input_tokens", 0)
                 + cu.get("cache_creation_input_tokens", 0)
                 + cu.get("cache_read_input_tokens", 0))
max_tokens = cw.get("context_window_size", 0) or 0

def tail_read_last_assistant(path, chunk=8192):
    try:
        size = os.path.getsize(path)
        buf = b""
        with open(path, "rb") as fh:
            pos = size
            while pos > 0:
                read_size = min(chunk, pos)
                pos -= read_size
                fh.seek(pos)
                buf = fh.read(read_size) + buf
                lines = buf.split(b"\n")
                for line in reversed(lines):
                    if b"\"type\":\"assistant\"" in line and line.strip():
                        return line.decode("utf-8", errors="replace")
        return None
    except:
        return None

# Only fall back to the transcript when stdin did not supply what we need —
# skipping the tail-read keeps the common path cheap.
if session_id and (not model or not used_tokens):
    cwd = os.getcwd()
    proj_slug = re.sub(r"[/.]", "-", cwd)
    direct_path = os.path.join(home, ".claude/projects", proj_slug, session_id + ".jsonl")
    if os.path.exists(direct_path):
        candidate_paths = [direct_path]
    else:
        candidate_paths = glob.glob(
            os.path.join(home, ".claude/projects/**/" + session_id + ".jsonl"),
            recursive=True
        )
    if candidate_paths:
        line = tail_read_last_assistant(candidate_paths[0])
        if line:
            try:
                d = json.loads(line, strict=False)
                model = model or d.get("message", {}).get("model", "")
                if not used_tokens:
                    u = d.get("message", {}).get("usage", {})
                    used_tokens = (u.get("input_tokens", 0)
                                 + u.get("cache_creation_input_tokens", 0)
                                 + u.get("cache_read_input_tokens", 0))
            except:
                pass

# ── Model fallback: most recent session with an assistant entry ───────────────
if not model:
    files = sorted(
        glob.glob(os.path.join(home, ".claude/projects/**/*.jsonl"), recursive=True),
        key=os.path.getmtime, reverse=True
    )
    for f in files[:10]:
        try:
            with open(f) as fh:
                lines = [l for l in fh if "\"type\":\"assistant\"" in l]
            if lines:
                d = json.loads(lines[-1], strict=False)
                m = d.get("message", {}).get("model", "")
                if m:
                    model = m
                    break
        except:
            pass

# ── Format helper ─────────────────────────────────────────────────────────────
def fmt(t):
    if t >= 1000000: return f"{t/1000000:.1f}M"
    if t >= 1000:    return f"{t/1000:.1f}K"
    return str(t)

# ── Monthly tokens (cached in /tmp, recalculated every 60s) ──────────────────
monthly_raw = 0
try:
    if os.path.exists(cache_path) and (time.time() - os.path.getmtime(cache_path)) < cache_ttl:
        with open(cache_path) as fh:
            monthly_raw = int(fh.read().strip())
    else:
        now = datetime.datetime.now(datetime.timezone.utc)
        month_start = datetime.datetime(now.year, now.month, 1, tzinfo=datetime.timezone.utc)
        month_ts = month_start.timestamp()
        for f in glob.glob(os.path.join(home, ".claude/projects/**/*.jsonl"), recursive=True):
            try:
                if os.path.getmtime(f) < month_ts:
                    continue
                with open(f) as fh:
                    for line in fh:
                        try:
                            d = json.loads(line, strict=False)
                            if d.get("type") != "assistant":
                                continue
                            ts = d.get("timestamp", "")
                            if not ts:
                                continue
                            t = datetime.datetime.fromisoformat(ts.replace("Z", "+00:00"))
                            if t < month_start:
                                continue
                            u = d.get("message", {}).get("usage", {})
                            monthly_raw += (u.get("input_tokens", 0)
                                         + u.get("output_tokens", 0)
                                         + u.get("cache_creation_input_tokens", 0)
                                         + u.get("cache_read_input_tokens", 0))
                        except:
                            pass
            except:
                pass
        with open(cache_path, "w") as fh:
            fh.write(str(monthly_raw))
except:
    pass

print("MODEL=" + (model or "unknown"))
print("USED_TOKENS=" + str(used_tokens))
print("MAX_TOKENS=" + str(max_tokens or 200000))
print("SESSION_FMT=" + fmt(used_tokens))
print("MONTHLY_FMT=" + fmt(monthly_raw))
' 2>/dev/null)"

MODEL="${MODEL:-unknown}"
USED_TOKENS="${USED_TOKENS:-0}"
MAX_TOKENS="${MAX_TOKENS:-200000}"
SESSION_FMT="${SESSION_FMT:-0}"
MONTHLY_FMT="${MONTHLY_FMT:-0}"

# ── Context bar ───────────────────────────────────────────────────────────────
# MAX_TOKENS comes from the stdin payload's real context_window_size (per-model),
# falling back to 200000 if stdin is unavailable.
PCT=$(( USED_TOKENS * 100 / MAX_TOKENS ))
[[ $PCT -gt 100 ]] && PCT=100
FILLED=$(( PCT * 20 / 100 ))
EMPTY=$(( 20 - FILLED ))

# ── Session token color (vs median) ──────────────────────────────────────────
SESSION_PCT=$(( USED_TOKENS * 100 / MEDIAN_SESSION ))
if   (( SESSION_PCT < 50  )); then SESSION_COLOR=$(c 76 201 240)   # cyan     — light
elif (( SESSION_PCT < 100 )); then SESSION_COLOR=$(c 183 168 237)  # lavender — normal
elif (( SESSION_PCT < 200 )); then SESSION_COLOR=$(c 255 45 120)   # hot pink — heavy
else                               SESSION_COLOR=$(c 255 230 0)    # gold     — deep work
fi

TOKEN_SEGMENT="  │  S: ${SESSION_COLOR}${SESSION_FMT}${RST}  M: ${LAV}${MONTHLY_FMT}${RST} "

# ── Context bar gradient ──────────────────────────────────────────────────────
BAR="["
for (( i=0; i<FILLED; i++ )); do
  T=$(( i * 1000 / 20 ))
  if (( T <= 500 )); then
    F=$T
    R=$(( 76  + (157 -  76) * F / 500 ))
    G=$(( 201 + ( 78 - 201) * F / 500 ))
    B=$(( 240 + (221 - 240) * F / 500 ))
  else
    F=$(( T - 500 ))
    R=$(( 157 + (255 - 157) * F / 500 ))
    G=$(( 78  + ( 45 -  78) * F / 500 ))
    B=$(( 221 + (120 - 221) * F / 500 ))
  fi
  BAR+="$(printf '\e[38;2;%d;%d;%dm█\e[0m' $R $G $B)"
done
for (( i=0; i<EMPTY; i++ )); do
  BAR+="${DRK}░${RST}"
done
BAR+="]"

ALERT=""
[[ $PCT -ge 70 ]] && ALERT=" ${HOT}!${RST}"

# ── Git segment ───────────────────────────────────────────────────────────────
GIT_SEGMENT=""
if git rev-parse --git-dir &>/dev/null; then
  REPO_NAME=$(git rev-parse --show-toplevel 2>/dev/null | xargs basename)
  BRANCH=$(git branch --show-current 2>/dev/null)

  ICONS=(◈ ⬡ ✦ ◉ ⊕ ★ ◎ ✧ ⬢ ⊙ ◇ ✴ ♠ ♥ ♦ ♣)
  IDX=$(echo "$REPO_NAME" | cksum | awk "{print \$1 % 16}")
  ICON="${ICONS[$IDX]}"

  AHEAD=0
  for BASE in main master; do
    if git rev-parse --verify "$BASE" &>/dev/null; then
      AHEAD=$(git rev-list HEAD ^"$BASE" --count 2>/dev/null || echo 0)
      break
    fi
  done

  MODIFIED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

  GIT_SEGMENT=" │  ${LAV}${ICON} ${REPO_NAME}${RST}  ${BRANCH}  ${SCY}⬆ ${AHEAD}${RST}  ${PNK}± ${MODIFIED}${RST}"
fi

# ── Effort display ────────────────────────────────────────────────────────────
case "${EFFORT:-}" in
  low)
    EFFORT_DISPLAY="$(printf '\e[38;2;234;179;8m◆ low\e[0m')"
    ;;
  medium)
    EFFORT_DISPLAY="$(printf '\e[38;2;34;197;94m◆ medium\e[0m')"
    ;;
  high)
    EFFORT_DISPLAY="$(printf '\e[38;2;99;102;241m◆ high\e[0m')"
    ;;
  xhigh)
    SEC=$(( $(date +%s) / 2 ))
    BRIGHT=$(( SEC % 5 ))
    XCHARS=("x" "h" "i" "g" "h")
    EFFORT_DISPLAY="$(printf '\e[38;2;100;30;180m◆ \e[0m')"
    for i in 0 1 2 3 4; do
      DIST=$(( i - BRIGHT ))
      [[ $DIST -lt 0 ]] && DIST=$(( -DIST ))
      if   [[ $DIST -eq 0 ]]; then CR=245; CG=225; CB=255
      elif [[ $DIST -eq 1 ]]; then CR=185; CG=110; CB=255
      else                         CR=100; CG=30;  CB=180
      fi
      EFFORT_DISPLAY+="$(printf '\e[38;2;%d;%d;%dm%s\e[0m' $CR $CG $CB "${XCHARS[$i]}")"
    done
    ;;
  max)
    SEC=$(date +%s)
    MCHARS=("m" "a" "x")
    RR=(255 255 200 0   0   148)
    RG=(0   140 220 220 0   0  )
    RB=(0   0   0   0   255 211)
    IDX0=$(( SEC % 6 ))
    EFFORT_DISPLAY="$(printf '\e[38;2;%d;%d;%dm◆ \e[0m' "${RR[$IDX0]}" "${RG[$IDX0]}" "${RB[$IDX0]}")"
    for i in 0 1 2; do
      IDX=$(( (SEC + i * 2) % 6 ))
      EFFORT_DISPLAY+="$(printf '\e[38;2;%d;%d;%dm%s\e[0m' "${RR[$IDX]}" "${RG[$IDX]}" "${RB[$IDX]}" "${MCHARS[$i]}")"
    done
    ;;
  *)
    EFFORT_DISPLAY="$(printf '\e[38;2;191;95;255m◆ %s\e[0m' "${EFFORT:-?}")"
    ;;
esac

# ── Assemble and print ────────────────────────────────────────────────────────
printf "  %s  %s  │  %s ${PCT}%% of context%s%s%s\n" \
  "$MODEL" \
  "$EFFORT_DISPLAY" \
  "$BAR" \
  "$ALERT" \
  "$TOKEN_SEGMENT" \
  "$GIT_SEGMENT"
