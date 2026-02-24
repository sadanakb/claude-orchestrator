#!/bin/bash
# statusline.sh — Claude Orchestrator v2
# Runs on every StatusLine update (continuously during session)
# Shows: Context% + Task Progress + Project Name
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

# Context icon — aligned with handoff thresholds (55-60% used)
#   🟢 = safe zone (under 45%)
#   🟡 = approaching threshold (45-55%) — delegate more
#   🟠 = at threshold (55-60%) — handoff about to trigger
#   🔴 = past threshold (60%+) — should NEVER appear
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

# Task queue progress (if queue exists)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
QUEUE_FILE="$PROJECT_DIR/.claude/task-queue.json"
TASK_INFO=""

if [ -f "$QUEUE_FILE" ]; then
    PROGRESS=$(python3 -c "
import json
try:
    with open('$QUEUE_FILE') as f:
        d = json.load(f)
    tasks = d.get('tasks', [])
    total_orig = len(tasks)
    done = len([t for t in tasks if t.get('status') == 'completed'])
    pending = len([t for t in tasks if t.get('status', 'pending') != 'completed'])
    # Show progress: current / total (total = done so far + remaining)
    current = done + 1
    total = done + pending
    print(f'{current}/{total}')
except:
    print('')
" 2>/dev/null)

    if [ -n "$PROGRESS" ]; then
        TASK_INFO=" | Task $PROGRESS"
    fi
fi

# Project name from directory
PROJ=$(basename "${CLAUDE_PROJECT_DIR:-.}")

echo "$ICON ${USED}%${TASK_INFO} | $PROJ"
