#!/usr/bin/env bash
# Claude Code status line — synthwave edition

SESSION_ID="${1:-}"
EFFORT="${2:-}"

# ── Colors (truecolor) ──────────────────────────────────────────────────────
c()  { printf '\e[38;2;%s;%s;%sm' "$1" "$2" "$3"; }
rst(){ printf '\e[0m'; }

CYN=$(c 76 201 240)   # #4CC9F0 sky cyan       — model name, bar low
PUR=$(c 191 95 255)   # #BF5FFF neon purple     — effort
DIV=$(c 107 33 168)   # #6B21A8 dim violet      — │ dividers
MID=$(c 157 78 221)   # #9D4EDD purple           — bar mid
HOT=$(c 255 45 120)   # #FF2D78 hot pink         — bar high + !
DRK=$(c 30 10 60)     # #1E0A3C dark navy        — empty bar blocks
GRN=$(c 57 255 20)    # #39FF14 neon green       — repo icon + name
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

MODEL="${MODEL:-unknown}"
USED_TOKENS="${USED_TOKENS:-0}"

# ── Context bar ───────────────────────────────────────────────────────────────
PCT=$(( USED_TOKENS * 100 / MAX_TOKENS ))
[[ $PCT -gt 100 ]] && PCT=100
FILLED=$(( PCT * 20 / 100 ))
EMPTY=$(( 20 - FILLED ))

BAR="["
for (( i=0; i<FILLED; i++ )); do
  BLOCK_PCT=$(( i * 100 / 20 ))
  if   [[ $BLOCK_PCT -lt 40 ]]; then BAR+="${CYN}█${RST}"
  elif [[ $BLOCK_PCT -lt 70 ]]; then BAR+="${MID}█${RST}"
  else                               BAR+="${HOT}█${RST}"
  fi
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

  GIT_SEGMENT=" ${DIV}│${RST}  ${GRN}${ICON} ${REPO_NAME}${RST}  ${GLD}${BRANCH}${RST}  ${SCY}⬆ ${AHEAD}${RST}  ${PNK}± ${MODIFIED}${RST}"
fi

# ── Effort label ──────────────────────────────────────────────────────────────
EFFORT_LABEL="${EFFORT:-?}"

# ── Assemble and print ────────────────────────────────────────────────────────
printf "  ${CYN}%s${RST}  ${PUR}◆ %s${RST}  ${DIV}│${RST}  %s ${PCT}%%%s%s\n" \
  "$MODEL" \
  "$EFFORT_LABEL" \
  "$BAR" \
  "$ALERT" \
  "$GIT_SEGMENT"
