#!/bin/bash
# install.sh — Claude Orchestrator v2
# One-time global setup. Run once → works for ALL Claude Code sessions.
set -e

echo "Installing Claude Orchestrator v2..."
echo ""

HOOKS_DIR=~/.claude/hooks
SKILLS_DIR=~/.claude/skills/orchestrator
COMMANDS_DIR=~/.claude/commands
SETTINGS_FILE=~/.claude/settings.json
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Verify source files exist ──────────────────────────────────────
echo "Verifying source files..."
MISSING=false
for f in hooks/statusline.sh hooks/stop-check.sh hooks/session-start.sh hooks/pre-compact.sh hooks/prompt-guard.py; do
    if [ ! -f "$SCRIPT_DIR/$f" ]; then
        echo "  ERROR: Missing $SCRIPT_DIR/$f" >&2
        MISSING=true
    fi
done
if [ ! -f "$SCRIPT_DIR/skills/orchestrator.md" ]; then
    echo "  ERROR: Missing $SCRIPT_DIR/skills/orchestrator.md" >&2
    MISSING=true
fi
if [ ! -f "$SCRIPT_DIR/commands/handoff.md" ]; then
    echo "  ERROR: Missing $SCRIPT_DIR/commands/handoff.md" >&2
    MISSING=true
fi
if [ "$MISSING" = true ]; then
    echo "Installation aborted due to missing files." >&2
    exit 1
fi
echo "  All source files present"

# ── Install hooks ──────────────────────────────────────────────────
mkdir -p "$HOOKS_DIR"
echo ""
echo "Installing hooks to $HOOKS_DIR..."
cp "$SCRIPT_DIR/hooks/statusline.sh"    "$HOOKS_DIR/statusline.sh"
cp "$SCRIPT_DIR/hooks/stop-check.sh"    "$HOOKS_DIR/stop-check.sh"
cp "$SCRIPT_DIR/hooks/session-start.sh" "$HOOKS_DIR/session-start.sh"
cp "$SCRIPT_DIR/hooks/pre-compact.sh"   "$HOOKS_DIR/pre-compact.sh"
cp "$SCRIPT_DIR/hooks/prompt-guard.py"  "$HOOKS_DIR/prompt-guard.py"
chmod +x "$HOOKS_DIR"/*.sh "$HOOKS_DIR"/*.py
echo "  Installed 5 hooks (4 shell + 1 python)"

# ── Install orchestrator skill ─────────────────────────────────────
mkdir -p "$SKILLS_DIR"
echo ""
echo "Installing orchestrator skill to $SKILLS_DIR..."
cp "$SCRIPT_DIR/skills/orchestrator.md" "$SKILLS_DIR/orchestrator.md"
echo "  Installed orchestrator skill"

# ── Install slash commands ─────────────────────────────────────────
mkdir -p "$COMMANDS_DIR"
echo ""
echo "Installing slash commands to $COMMANDS_DIR..."
cp "$SCRIPT_DIR/commands/handoff.md" "$COMMANDS_DIR/handoff.md"
echo "  Installed /handoff command (v2 format)"

# ── Configure settings.json ────────────────────────────────────────
echo ""
echo "Configuring $SETTINGS_FILE..."

if [ ! -f "$SETTINGS_FILE" ]; then
    cp "$SCRIPT_DIR/settings.json" "$SETTINGS_FILE"
    echo "  Created new settings.json"
else
    python3 - "$SETTINGS_FILE" "$SCRIPT_DIR/settings.json" << 'PYTHON'
import json, sys

existing_path = sys.argv[1]
new_path = sys.argv[2]

with open(existing_path) as f:
    existing = json.load(f)
with open(new_path) as f:
    new = json.load(f)

# Set statusLine
existing["statusLine"] = new["statusLine"]

# Merge hooks without duplicating
if "hooks" not in existing:
    existing["hooks"] = {}

for event, hook_list in new["hooks"].items():
    if event not in existing["hooks"]:
        existing["hooks"][event] = hook_list
    else:
        existing_cmds = set()
        for group in existing["hooks"][event]:
            for h in group.get("hooks", []):
                existing_cmds.add(h.get("command", ""))
        for group in hook_list:
            for h in group.get("hooks", []):
                if h.get("command", "") not in existing_cmds:
                    existing["hooks"][event].append(group)
                    break  # Only add the group once

with open(existing_path, "w") as f:
    json.dump(existing, f, indent=2)

print("  Merged into existing settings.json")
PYTHON
fi

# ── Add .gitignore entries to current project ──────────────────────
if [ -n "$CLAUDE_PROJECT_DIR" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
    GITIGNORE="$CLAUDE_PROJECT_DIR/.gitignore"
    if [ -f "$GITIGNORE" ]; then
        if ! grep -q "claude-orchestrator" "$GITIGNORE" 2>/dev/null; then
            echo "" >> "$GITIGNORE"
            echo "# Claude Orchestrator state files" >> "$GITIGNORE"
            echo ".claude/HANDOFF.md" >> "$GITIGNORE"
            echo ".claude/task-queue.json" >> "$GITIGNORE"
            echo ".claude/task-queue.md" >> "$GITIGNORE"
            echo ".claude/backups/" >> "$GITIGNORE"
            echo "  Added orchestrator entries to $GITIGNORE"
        fi
    fi
fi

# ── Done ───────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Claude Orchestrator v2 installed!"
echo "============================================"
echo ""
echo "What happens now:"
echo ""
echo "  SMALL tasks (< 80 chars, simple):"
echo "    → Claude works normally, no overhead"
echo ""
echo "  MEDIUM tasks:"
echo "    → Claude gets delegation hints"
echo "    → Encouraged to use Sub-Agents"
echo ""
echo "  LARGE/XL tasks:"
echo "    → Orchestrator mode activates automatically"
echo "    → Claude becomes an Architect, delegates to Sub-Agents"
echo "    → Explore → Plan → Build → Review workflow"
echo ""
echo "  MULTI-TASK requests (3+ separate tasks):"
echo "    → Only task 1 goes to Claude"
echo "    → Tasks 2-N saved to queue"
echo "    → Each session handles one task with full focus"
echo ""
echo "  CONTEXT > threshold:"
echo "    → Handoff written automatically"
echo "    → Next session continues where you left off"
echo ""
echo "Settings: $SETTINGS_FILE"
echo "Hooks:    $HOOKS_DIR/"
echo "Skill:    $SKILLS_DIR/orchestrator.md"
echo ""
echo "To uninstall: $SCRIPT_DIR/uninstall.sh"
