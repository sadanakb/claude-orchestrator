#!/bin/bash
# session-start.sh — Claude Orchestrator v3
# Fires at the start of every Claude Code session
# Two jobs:
#   1. If HANDOFF.md or CHECKPOINT.md exists → inject into context, then consume
#   2. Increment session counter

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
HANDOFF_FILE="$PROJECT_DIR/.claude/HANDOFF.md"
CHECKPOINT_FILE="$PROJECT_DIR/.claude/CHECKPOINT.md"
LAST_CHECKPOINT="$PROJECT_DIR/.claude/.last-checkpoint.md"
BACKUP_DIR="$PROJECT_DIR/.claude/backups"
SESSION_COUNT_FILE="$PROJECT_DIR/.claude/session-count"

LOADED_SOMETHING=false
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M')

# -- 1. Load handoff or checkpoint (priority: HANDOFF > CHECKPOINT) ----
# HANDOFF.md is written by stop-check.sh when context is full.
# CHECKPOINT.md is updated after every sub-task by Claude.
# If both exist, HANDOFF is more recent (it was generated FROM the checkpoint).

if [ -f "$HANDOFF_FILE" ]; then
    echo "========================================================"
    echo "        HANDOFF FROM PREVIOUS SESSION"
    echo "========================================================"
    echo ""
    cat "$HANDOFF_FILE"

    # Archive and consume HANDOFF
    mkdir -p "$BACKUP_DIR"
    cp "$HANDOFF_FILE" "$BACKUP_DIR/handoff-${TIMESTAMP}.md"
    rm "$HANDOFF_FILE"

    # Bug 3 Fix: CHECKPOINT nicht loeschen, sondern als Referenz behalten
    if [ -f "$CHECKPOINT_FILE" ]; then
        cp "$CHECKPOINT_FILE" "$BACKUP_DIR/checkpoint-${TIMESTAMP}.md"
        mv "$CHECKPOINT_FILE" "$LAST_CHECKPOINT"
    fi

    LOADED_SOMETHING=true

elif [ -f "$CHECKPOINT_FILE" ]; then
    echo "========================================================"
    echo "        CHECKPOINT FROM PREVIOUS SESSION"
    echo "========================================================"
    echo ""
    cat "$CHECKPOINT_FILE"

    # Bug 3 Fix: Archivieren + umbenennen statt loeschen
    mkdir -p "$BACKUP_DIR"
    cp "$CHECKPOINT_FILE" "$BACKUP_DIR/checkpoint-${TIMESTAMP}.md"
    mv "$CHECKPOINT_FILE" "$LAST_CHECKPOINT"

    LOADED_SOMETHING=true
fi

# -- 2. Increment session counter -------------------------------------
if [ -f "$SESSION_COUNT_FILE" ]; then
    COUNT=$(cat "$SESSION_COUNT_FILE" 2>/dev/null)
    COUNT=${COUNT:-0}
    echo $((COUNT + 1)) > "$SESSION_COUNT_FILE"
else
    mkdir -p "$PROJECT_DIR/.claude"
    echo "1" > "$SESSION_COUNT_FILE"
fi

# -- 3. Inject continuation hints --------------------------------------
if [ "$LOADED_SOMETHING" = true ]; then
    echo ""
    echo "========================================================"
    echo "Handoff loaded. Continue from 'Naechster Schritt' above."
    echo ""
    echo "When this task is done, update .claude/CHECKPOINT.md."
    echo "At ${THRESHOLD:-55}%+ context, CHECKPOINT becomes HANDOFF automatically."
    echo "========================================================"
fi
