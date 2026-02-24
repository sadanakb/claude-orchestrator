#!/bin/bash
# session-start.sh — Claude Orchestrator v2
# Fires at the start of every Claude Code session
# Three jobs:
#   1. If HANDOFF.md exists → inject it into Claude's context
#   2. Check for stale in-progress tasks → reset to pending
#   3. Inject orchestrator hints for continuation

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
HANDOFF_FILE="$PROJECT_DIR/.claude/HANDOFF.md"
QUEUE_FILE="$PROJECT_DIR/.claude/task-queue.json"

LOADED_SOMETHING=false

# -- 1. Load handoff if it exists ------------------------------------
if [ -f "$HANDOFF_FILE" ]; then
    echo "========================================================"
    echo "        HANDOFF FROM PREVIOUS SESSION"
    echo "========================================================"
    echo ""
    cat "$HANDOFF_FILE"
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

# -- 3. Inject orchestrator continuation hints -----------------------
if [ "$LOADED_SOMETHING" = true ]; then
    echo ""
    echo "========================================================"
    echo "Handoff loaded. Continue from 'Next Action' above."
    echo "When this task is done, a new handoff will be written"
    echo "automatically if context is > 60%."
    echo "========================================================"
fi
