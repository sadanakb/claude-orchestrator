#!/bin/bash
# session-start.sh — Claude Orchestrator v2
# Fires at the start of every Claude Code session
# Three jobs:
#   1. If HANDOFF.md exists → inject into context, then CONSUME it (rename)
#   2. Check for stale in-progress tasks → reset to pending
#   3. Inject continuation hints

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
HANDOFF_FILE="$PROJECT_DIR/.claude/HANDOFF.md"
QUEUE_FILE="$PROJECT_DIR/.claude/task-queue.json"
BACKUP_DIR="$PROJECT_DIR/.claude/backups"

LOADED_SOMETHING=false

# -- 1. Load handoff if it exists, then CONSUME it --------------------
# "Consume" = rename to .loaded so auto-session.sh doesn't loop forever.
# If Claude needs to hand off again, stop-check.sh writes a NEW one.
if [ -f "$HANDOFF_FILE" ]; then
    echo "========================================================"
    echo "        HANDOFF FROM PREVIOUS SESSION"
    echo "========================================================"
    echo ""
    cat "$HANDOFF_FILE"

    # Archive and consume
    mkdir -p "$BACKUP_DIR"
    TIMESTAMP=$(date '+%Y-%m-%d_%H-%M')
    cp "$HANDOFF_FILE" "$BACKUP_DIR/handoff-${TIMESTAMP}.md"
    rm "$HANDOFF_FILE"

    LOADED_SOMETHING=true
fi

# -- 2. Reset stale in-progress tasks to pending --------------------
if [ -f "$QUEUE_FILE" ]; then
    python3 -c "
import json, os, tempfile

queue_path = '$QUEUE_FILE'
try:
    with open(queue_path) as f:
        data = json.load(f)
    tasks = data.get('tasks', [])
    changed = False
    for t in tasks:
        if t.get('status') == 'in_progress':
            t['status'] = 'pending'
            changed = True
    if changed:
        dir_name = os.path.dirname(queue_path)
        fd, tmp = tempfile.mkstemp(dir=dir_name, suffix='.tmp')
        with os.fdopen(fd, 'w') as f:
            json.dump(data, f, indent=2)
        os.replace(tmp, queue_path)
except Exception:
    pass
" 2>/dev/null
    LOADED_SOMETHING=true
fi

# -- 3. Inject continuation hints ------------------------------------
if [ "$LOADED_SOMETHING" = true ]; then
    echo ""
    echo "========================================================"
    echo "Handoff loaded and consumed. Continue from 'Next Action'."
    echo ""
    echo "When this task is DONE: just /exit — no restart happens."
    echo "When context gets full: handoff is written automatically"
    echo "  and /exit triggers a fresh restart."
    echo "========================================================"
fi
