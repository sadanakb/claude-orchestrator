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
    cp "$HANDOFF_FILE" "$BACKUP_DIR/handoff-${TIMESTAMP}.md"
fi

# Archive existing CHECKPOINT.md
if [ -f "$CHECKPOINT_FILE" ]; then
    cp "$CHECKPOINT_FILE" "$BACKUP_DIR/checkpoint-${TIMESTAMP}.md"
fi

# Inject system message to write updated checkpoint after compaction
echo "{
  \"systemMessage\": \"Context compaction is about to happen. After compaction completes, immediately update .claude/CHECKPOINT.md with: current goal, completed items with file paths, remaining TODOs, key decisions, build/test status, and exact next action. This ensures continuity.\"
}"
