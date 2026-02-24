#!/bin/bash
# pre-compact.sh — Claude Orchestrator v3
# Fires right BEFORE Claude Code performs compaction
# Emergency backup: ensures state is preserved even if stop-check didn't trigger

# Consume stdin (hook protocol requires it)
cat > /dev/null

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
BACKUP_DIR="$PROJECT_DIR/.claude/backups"
HANDOFF_FILE="$PROJECT_DIR/.claude/HANDOFF.md"
CHECKPOINT_FILE="$PROJECT_DIR/.claude/CHECKPOINT.md"

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M')

# Archive existing HANDOFF.md
if [ -f "$HANDOFF_FILE" ]; then
    cp "$HANDOFF_FILE" "$BACKUP_DIR/handoff-precompact-${TIMESTAMP}.md"
fi

# Archive existing CHECKPOINT.md
if [ -f "$CHECKPOINT_FILE" ]; then
    cp "$CHECKPOINT_FILE" "$BACKUP_DIR/checkpoint-precompact-${TIMESTAMP}.md"
fi

# Bug 4 Fix: systemMessage entfernt (funktioniert nicht zuverlaessig mit async hooks).
# Stattdessen: stderr-Warnung die Claude sieht.
echo "⚠️  Context-Compaction laeuft. Nach Abschluss: .claude/CHECKPOINT.md sofort aktualisieren." >&2
