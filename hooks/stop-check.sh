#!/bin/bash
# stop-check.sh — Claude Orchestrator v2
# Fires when Claude finishes a response
# Four jobs:
#   1. Mark completed in-progress tasks in the queue
#   2. Notify about remaining task queue
#   3. Dynamic threshold based on queue size
#   4. If context exceeds threshold → force handoff

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('session_id', 'unknown'))
except:
    print('unknown')
" 2>/dev/null)
SESSION_ID=${SESSION_ID:-unknown}

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_FILE=~/.claude/context-state.json
HANDOFF_FLAG=~/.claude/handoff-done-${SESSION_ID}
QUEUE_FILE="$PROJECT_DIR/.claude/task-queue.json"

# -- 1. Mark in-progress tasks as completed --------------------------
if [ -f "$QUEUE_FILE" ]; then
    python3 -c "
import json, sys, os, tempfile

queue_path = '$QUEUE_FILE'
try:
    with open(queue_path) as f:
        data = json.load(f)
    tasks = data.get('tasks', [])
    updated = []
    for t in tasks:
        if t.get('status') == 'in_progress':
            t['status'] = 'completed'
        if t.get('status', 'pending') != 'completed':
            updated.append(t)
    data['tasks'] = updated

    # Atomic write
    dir_name = os.path.dirname(queue_path)
    fd, tmp = tempfile.mkstemp(dir=dir_name, suffix='.tmp')
    with os.fdopen(fd, 'w') as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, queue_path)

    # Clean up if queue is empty
    if not updated:
        os.remove(queue_path)
        md = queue_path.replace('.json', '.md')
        if os.path.exists(md):
            os.remove(md)
except Exception:
    pass
" 2>/dev/null
fi

# -- 2. Notify about remaining queue --------------------------------
QUEUE_SIZE=0
if [ -f "$QUEUE_FILE" ]; then
    QUEUE_SIZE=$(python3 -c "
import json
try:
    with open('$QUEUE_FILE') as f:
        d = json.load(f)
    print(len([t for t in d.get('tasks', []) if t.get('status', 'pending') != 'completed']))
except:
    print(0)
" 2>/dev/null)
    QUEUE_SIZE=${QUEUE_SIZE:-0}

    if [ "$QUEUE_SIZE" -gt "0" ] 2>/dev/null; then
        NEXT_TITLE=$(python3 -c "
import json
try:
    with open('$QUEUE_FILE') as f:
        d = json.load(f)
    tasks = [t for t in d.get('tasks', []) if t.get('status', 'pending') != 'completed']
    if tasks:
        print(tasks[0].get('title', 'Next task'))
except:
    print('Next queued task')
" 2>/dev/null)
        echo "
📋 Task queue: ${QUEUE_SIZE} task(s) remaining. Next: \"$NEXT_TITLE\"
The next task will load automatically when you start the next session.
" >&2
    fi
fi

# -- 3. Check if handoff already written this session ----------------
if [ -f "$HANDOFF_FLAG" ]; then
    exit 0
fi

if [ ! -f "$STATE_FILE" ]; then
    exit 0
fi

# -- 4. Dynamic threshold based on queue size ------------------------
# Handoff at 55-60% used. auto-session.sh restarts automatically.
# Queue empty  → 45% remaining (55% used)
# Queue 1-2    → 42% remaining (58% used)
# Queue 3+     → 40% remaining (60% used)
if [ "$QUEUE_SIZE" -gt 2 ] 2>/dev/null; then
    THRESHOLD=40
elif [ "$QUEUE_SIZE" -gt 0 ] 2>/dev/null; then
    THRESHOLD=42
else
    THRESHOLD=45
fi

REMAINING=$(python3 -c "
import json
try:
    with open('$STATE_FILE') as f:
        d = json.load(f)
    print(int(d.get('remaining', 100)))
except:
    print(100)
" 2>/dev/null)
REMAINING=${REMAINING:-100}

if [ "$REMAINING" -le "$THRESHOLD" ] 2>/dev/null; then
    USED=$((100 - REMAINING))
    touch "$HANDOFF_FLAG"

    # ── AUTO-WRITE HANDOFF ──────────────────────────────────────
    # Don't ask Claude to write it — write a template NOW so state
    # is saved even if the session crashes. Claude will enrich it.
    HANDOFF_FILE="$PROJECT_DIR/.claude/HANDOFF.md"
    mkdir -p "$PROJECT_DIR/.claude"

    # Only write auto-handoff if no handoff exists yet
    if [ ! -f "$HANDOFF_FILE" ]; then
        cat > "$HANDOFF_FILE" << HANDOFF_EOF
# Handoff — $(date '+%Y-%m-%d %H:%M') (auto-generated)

## Current Plan
[Session wurde automatisch beendet — Context bei ${USED}%]

## Completed This Session
[Claude soll diese Sektion beim naechsten Start ergaenzen]

## Remaining TODOs
[Aus dem letzten Gespraech ableiten]

## Key Decisions Made
[Aus dem letzten Gespraech ableiten]

## Next Action
[Aus dem letzten Gespraech ableiten]
HANDOFF_EOF
    fi

    # ── TELL CLAUDE: Write real handoff, then exit ──────────────
    echo "
⚠️  CONTEXT BEI ${USED}% — AUTOMATISCHER HANDOFF + NEUSTART

1. Schreibe JETZT .claude/HANDOFF.md mit dem echten Stand:
   - Was wurde gemacht (Dateien + Zusammenfassung)
   - Was ist noch offen (TODOs mit Prioritaet)
   - Exakter naechster Schritt + welche Agents zuerst spawnen

2. Sage dem User: **Tippe /exit — die Session startet automatisch neu.**
   (Wenn auto-session.sh laeuft, passiert der Neustart von alleine.
    Wenn nicht: /clear und dann manuell weiter.)

WICHTIG: Kein neuer Code mehr. Nur Handoff schreiben und Session beenden.
" >&2
    exit 2
fi

exit 0
