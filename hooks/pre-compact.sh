#!/bin/bash
# pre-compact.sh — Claude Orchestrator v2
# Fires right BEFORE Claude Code performs compaction
# Emergency backup: ensures state is preserved even if stop-check didn't trigger

# Consume stdin (hook protocol requires it)
cat > /dev/null

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
BACKUP_DIR="$PROJECT_DIR/.claude/backups"
HANDOFF_FILE="$PROJECT_DIR/.claude/HANDOFF.md"
QUEUE_FILE="$PROJECT_DIR/.claude/task-queue.json"

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M')

# Archive existing HANDOFF.md
if [ -f "$HANDOFF_FILE" ]; then
    cp "$HANDOFF_FILE" "$BACKUP_DIR/handoff-${TIMESTAMP}.md"
fi

# Archive task queue state
if [ -f "$QUEUE_FILE" ]; then
    cp "$QUEUE_FILE" "$BACKUP_DIR/task-queue-${TIMESTAMP}.json"
fi

# Inject system message to write updated handoff after compaction
echo "{
  \"systemMessage\": \"Context compaction is about to happen. After compaction completes, immediately update .claude/HANDOFF.md with: current plan, what agents have done, remaining TODOs, key decisions, and exact next action including which agents to spawn. This ensures continuity.\"
}"
