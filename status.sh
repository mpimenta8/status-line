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
MUT=$(c 128 128 148)  # #808094 muted gray       — reset countdowns, separators
RST=$(rst)

# ── Vaporwave gradient: T in 0..1000 → truecolor escape (cyan→purple→pink) ───
# Shared by the context bar and the usage-window percentages so they read as one
# palette. Callers choose the mapping: the bar keys T to block position; the
# usage numbers key T to utilization with full pink reached by 90% (see below).
grad() {
  local T=$1 F R G B
  (( T < 0 )) && T=0
  (( T > 1000 )) && T=1000
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
  printf '\e[38;2;%d;%d;%dm' $R $G $B
}

# ── Single python3 call: model, tokens, usage windows ────────────────────────
eval "$(SESSION_ID="$SESSION_ID" STDIN_JSON="$STDIN_JSON" python3 -c '
import json, os, glob, re, datetime, time

home = os.path.expanduser("~")
session_id = os.environ.get("SESSION_ID", "")

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

# ── Pretty model name: "claude-opus-4-8" → "Opus 4.8" ────────────────────────
def pretty_model(model_id):
    if not model_id:
        return "unknown"
    s = model_id[len("claude-"):] if model_id.startswith("claude-") else model_id
    parts = [p for p in s.split("-") if p]
    if not parts:
        return model_id
    family = parts[0][:1].upper() + parts[0][1:]
    version_parts = [p for p in parts[1:] if not re.fullmatch(r"\d{8}", p)]
    version = ".".join(version_parts)
    return f"{family} {version}" if version else family

# ── Usage windows: session (5h) + weekly (7d) from Claude Code’s own cache ────
# Claude Code refreshes ~/.claude.json → cachedUsageUtilization on its own; this
# is the exact data behind the native "X% used <reset>" banner — far cheaper and
# more accurate than scanning every transcript on disk.
usage_ok = 0
sess_pct = week_pct = 0
sess_reset = week_reset = ""

def fmt_reset(iso):
    try:
        ra = datetime.datetime.fromisoformat(iso).timestamp()
    except:
        return ""
    rem = int(ra - time.time())
    if rem < 0:
        rem = 0
    d, r = divmod(rem, 86400)
    h, r = divmod(r, 3600)
    m = r // 60
    if d: return f"{d}d {h}h"
    if h: return f"{h}h {m}m"
    return f"{m}m"

try:
    with open(os.path.join(home, ".claude.json")) as fh:
        util = (json.load(fh).get("cachedUsageUtilization") or {}).get("utilization") or {}
    fh5 = util.get("five_hour") or {}
    d7  = util.get("seven_day") or {}
    if fh5 and d7:
        sess_pct = int(fh5.get("utilization", 0))
        week_pct = int(d7.get("utilization", 0))
        sess_reset = fmt_reset(fh5.get("resets_at", ""))
        week_reset = fmt_reset(d7.get("resets_at", ""))
        usage_ok = 1
except:
    pass

print("MODEL=\"" + pretty_model(model) + "\"")
print("USED_TOKENS=" + str(used_tokens))
print("MAX_TOKENS=" + str(max_tokens or 200000))
print("USAGE_OK=" + str(usage_ok))
print("SESS_PCT=" + str(sess_pct))
print("WEEK_PCT=" + str(week_pct))
print("SESS_RESET=\"" + sess_reset + "\"")
print("WEEK_RESET=\"" + week_reset + "\"")
' 2>/dev/null)"

MODEL="${MODEL:-unknown}"
USED_TOKENS="${USED_TOKENS:-0}"
MAX_TOKENS="${MAX_TOKENS:-200000}"
USAGE_OK="${USAGE_OK:-0}"
SESS_PCT="${SESS_PCT:-0}"
WEEK_PCT="${WEEK_PCT:-0}"

# ── Context bar ───────────────────────────────────────────────────────────────
# MAX_TOKENS comes from the stdin payload's real context_window_size (per-model),
# falling back to 200000 if stdin is unavailable.
PCT=$(( USED_TOKENS * 100 / MAX_TOKENS ))
[[ $PCT -gt 100 ]] && PCT=100
FILLED=$(( PCT * 20 / 100 ))
EMPTY=$(( 20 - FILLED ))

# ── Usage windows: session (5h) + weekly (7d), gradient-scaled ────────────────
# The percent number + "used" carry the shared gradient; T = pct/90 so full pink
# is reached by 90% utilization (and held through 100%) — you see pink before you
# actually max out. Reset countdowns stay muted. Hidden entirely when the cache
# is unavailable, collapsing its divider with it.
USAGE_SEGMENT=""
if [[ "$USAGE_OK" == "1" ]]; then
  ST=$(( SESS_PCT * 1000 / 90 )); (( ST > 1000 )) && ST=1000
  WT=$(( WEEK_PCT * 1000 / 90 )); (( WT > 1000 )) && WT=1000
  USAGE_SEGMENT=" │ $(grad "$ST")${SESS_PCT}% used${RST} ${MUT}${SESS_RESET}${RST} ${MUT}·${RST} $(grad "$WT")${WEEK_PCT}% used${RST} ${MUT}${WEEK_RESET}${RST}"
fi

# ── Context bar (uses the shared gradient, keyed to block position) ──────────
BAR="["
for (( i=0; i<FILLED; i++ )); do
  BAR+="$(grad $(( i * 1000 / 20 )))█${RST}"
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

  GIT_SEGMENT=" │ ${LAV}${ICON} ${REPO_NAME}${RST}  ${BRANCH}  ${SCY}⬆ ${AHEAD}${RST}  ${PNK}± ${MODIFIED}${RST}"
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
printf "  %s  %s │ %s ${PCT}%% context%s%s%s\n" \
  "$MODEL" \
  "$EFFORT_DISPLAY" \
  "$BAR" \
  "$ALERT" \
  "$USAGE_SEGMENT" \
  "$GIT_SEGMENT"
