#!/usr/bin/env bash
# Claude Code status line — synthwave edition

SESSION_ID="${1:-}"
EFFORT="${2:-}"

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

# ── Token / model data ───────────────────────────────────────────────────────
MODEL=""
USED_TOKENS=0
MAX_TOKENS=200000

if [[ -n "$SESSION_ID" ]]; then
  JSONL=$(find "$HOME/.claude/projects" -name "${SESSION_ID}.jsonl" 2>/dev/null | head -1)

  if [[ -f "$JSONL" ]]; then
    # Read last assistant entry — extract model and usage fields
    LAST=$(grep '"type":"assistant"' "$JSONL" 2>/dev/null | tail -1)
    if [[ -n "$LAST" ]]; then
      MODEL=$(echo "$LAST" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
print(d.get('message', {}).get('model', ''))
" 2>/dev/null)

      USED_TOKENS=$(echo "$LAST" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
u = d.get('message', {}).get('usage', {})
total = (u.get('input_tokens', 0)
       + u.get('cache_creation_input_tokens', 0)
       + u.get('cache_read_input_tokens', 0))
print(total)
" 2>/dev/null)
    fi
  fi
fi

# Fallback: if no assistant message yet (new session / after /clear),
# grab the model from the most recent assistant entry across all sessions
if [[ -z "$MODEL" ]]; then
  MODEL=$(python3 -c "
import json, os, glob
files = sorted(
    glob.glob(os.path.expanduser('~/.claude/projects/**/*.jsonl'), recursive=True),
    key=os.path.getmtime, reverse=True
)
for f in files[:10]:
    try:
        with open(f) as fh:
            lines = [l for l in fh if '\"type\":\"assistant\"' in l]
            if lines:
                d = json.loads(lines[-1])
                m = d.get('message', {}).get('model', '')
                if m:
                    print(m)
                    break
    except:
        pass
" 2>/dev/null)
fi

MODEL="${MODEL:-unknown}"
USED_TOKENS="${USED_TOKENS:-0}"

# ── Context bar ───────────────────────────────────────────────────────────────
PCT=$(( USED_TOKENS * 100 / MAX_TOKENS ))
[[ $PCT -gt 100 ]] && PCT=100
FILLED=$(( PCT * 20 / 100 ))
EMPTY=$(( 20 - FILLED ))

# ── 5-hour output usage (approximates Claude app session usage) ───────────────
MAX_HOURLY_TOKENS=75000
HOURLY_OUTPUT=$(python3 -c "
import json, os, glob, datetime
cutoff = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=5)
total = 0
for f in glob.glob(os.path.expanduser('~/.claude/projects/**/*.jsonl'), recursive=True):
    try:
        with open(f) as fh:
            for line in fh:
                try:
                    d = json.loads(line)
                    if d.get('type') != 'assistant':
                        continue
                    ts = d.get('timestamp', '')
                    if not ts:
                        continue
                    t = datetime.datetime.fromisoformat(ts.replace('Z', '+00:00'))
                    if t < cutoff:
                        continue
                    u = d.get('message', {}).get('usage', {})
                    total += u.get('output_tokens', 0)
                except:
                    pass
    except:
        pass
print(total)
" 2>/dev/null)
HOURLY_OUTPUT="${HOURLY_OUTPUT:-0}"
HOURLY_PCT=$(( HOURLY_OUTPUT * 100 / MAX_HOURLY_TOKENS ))
[[ $HOURLY_PCT -gt 100 ]] && HOURLY_PCT=100

HT=$(( HOURLY_PCT * 10 ))
if (( HT <= 500 )); then
  HF=$HT
  HR=$(( 76  + (157 -  76) * HF / 500 ))
  HG=$(( 201 + ( 78 - 201) * HF / 500 ))
  HB=$(( 240 + (221 - 240) * HF / 500 ))
else
  HF=$(( HT - 500 ))
  HR=$(( 157 + (255 - 157) * HF / 500 ))
  HG=$(( 78  + ( 45 -  78) * HF / 500 ))
  HB=$(( 221 + (120 - 221) * HF / 500 ))
fi
HOURLY_COLOR=$(printf '\e[38;2;%d;%d;%dm' $HR $HG $HB)
HOURLY_SEGMENT="  │  Current: ${HOURLY_COLOR}${HOURLY_PCT}%${RST} "

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

  # Deterministic icon from repo name
  ICONS=(◈ ⬡ ✦ ◉ ⊕ ★ ◎ ✧ ⬢ ⊙ ◇ ✴ ♠ ♥ ♦ ♣)
  IDX=$(echo "$REPO_NAME" | cksum | awk "{print \$1 % 16}")
  ICON="${ICONS[$IDX]}"

  # Commits ahead of main / master
  AHEAD=0
  for BASE in main master; do
    if git rev-parse --verify "$BASE" &>/dev/null; then
      AHEAD=$(git rev-list HEAD ^"$BASE" --count 2>/dev/null || echo 0)
      break
    fi
  done

  # Modified + untracked file count
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
  "$HOURLY_SEGMENT" \
  "$GIT_SEGMENT"
