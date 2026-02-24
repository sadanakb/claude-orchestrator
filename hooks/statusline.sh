#!/bin/bash
# statusline.sh — Claude Orchestrator v3
# Runs on every StatusLine update (continuously during session)
# Shows: Context% + Checkpoint-Count + Project Name
# Writes context state to ~/.claude/context-state.json for other hooks

INPUT=$(cat)

# Extract remaining_percentage from context_window object
REMAINING=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    cw = d.get('context_window', {})
    val = cw.get('remaining_percentage', 100)
    print(int(val) if val is not None else 100)
except:
    print(100)
" 2>/dev/null)
REMAINING=${REMAINING:-100}

SESSION_ID=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('session_id', 'unknown'))
except:
    print('unknown')
" 2>/dev/null)
SESSION_ID=${SESSION_ID:-unknown}

# Atomic write to state file
STATE_FILE=~/.claude/context-state.json
TMP_FILE=$(mktemp ~/.claude/context-state.XXXXXX.tmp 2>/dev/null || echo "${STATE_FILE}.tmp")
echo "{\"remaining\": $REMAINING, \"session_id\": \"$SESSION_ID\"}" > "$TMP_FILE"
mv -f "$TMP_FILE" "$STATE_FILE"

# Context icon
USED=$((100 - REMAINING))
if [ "$USED" -ge 60 ]; then
    ICON="🔴"
elif [ "$USED" -ge 55 ]; then
    ICON="🟠"
elif [ "$USED" -ge 45 ]; then
    ICON="🟡"
else
    ICON="🟢"
fi

# Checkpoint count (count [x] entries in CHECKPOINT.md)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CHECKPOINT_FILE="$PROJECT_DIR/.claude/CHECKPOINT.md"
DONE_COUNT=0

if [ -f "$CHECKPOINT_FILE" ]; then
    DONE_COUNT=$(grep -c '\[x\]' "$CHECKPOINT_FILE" 2>/dev/null || echo 0)
fi

# Project name from directory
PROJ=$(basename "${CLAUDE_PROJECT_DIR:-.}")

echo "$ICON ${USED}% | ✓${DONE_COUNT} | $PROJ"
