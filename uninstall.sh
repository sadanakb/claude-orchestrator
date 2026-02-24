#!/bin/bash
# uninstall.sh — Claude Orchestrator v2
# Cleanly removes all hooks, skills, commands, and settings entries
set -e

echo "Uninstalling Claude Orchestrator v2..."
echo ""

HOOKS_DIR=~/.claude/hooks
SKILLS_DIR=~/.claude/skills/orchestrator
COMMANDS_DIR=~/.claude/commands
SETTINGS_FILE=~/.claude/settings.json

# ── Remove hook files ──────────────────────────────────────────────
echo "Removing hooks..."
HOOK_FILES=(
    "$HOOKS_DIR/statusline.sh"
    "$HOOKS_DIR/stop-check.sh"
    "$HOOKS_DIR/session-start.sh"
    "$HOOKS_DIR/pre-compact.sh"
    "$HOOKS_DIR/prompt-guard.py"
)

for f in "${HOOK_FILES[@]}"; do
    if [ -f "$f" ]; then
        rm "$f"
        echo "  Removed $f"
    fi
done

# ── Remove orchestrator skill ─────────────────────────────────────
echo ""
echo "Removing orchestrator skill..."
if [ -d "$SKILLS_DIR" ]; then
    rm -rf "$SKILLS_DIR"
    echo "  Removed $SKILLS_DIR"
fi

# ── Remove slash command ───────────────────────────────────────────
echo ""
echo "Removing slash commands..."
if [ -f "$COMMANDS_DIR/handoff.md" ]; then
    rm "$COMMANDS_DIR/handoff.md"
    echo "  Removed /handoff command"
fi

# ── Remove auto-session wrapper ────────────────────────────────────
if [ -f ~/.claude/auto-session.sh ]; then
    rm ~/.claude/auto-session.sh
    echo "  Removed auto-session.sh"
fi

# ── Remove state files ─────────────────────────────────────────────
echo ""
echo "Cleaning up state files..."
rm -f ~/.claude/context-state.json
rm -f ~/.claude/handoff-done-*
echo "  Cleaned up global state files"

# ── Clean hooks from settings.json ─────────────────────────────────
echo ""
echo "Cleaning settings.json..."
if [ -f "$SETTINGS_FILE" ]; then
    python3 - "$SETTINGS_FILE" << 'PYTHON'
import json, sys

path = sys.argv[1]
with open(path) as f:
    settings = json.load(f)

# Remove statusLine if it points to our script
sl = settings.get("statusLine", {})
if isinstance(sl, dict) and "statusline.sh" in sl.get("command", ""):
    del settings["statusLine"]

# Remove our hooks from each event
our_commands = {
    "prompt-guard.py",
    "session-start.sh",
    "stop-check.sh",
    "pre-compact.sh",
}

hooks = settings.get("hooks", {})
for event in list(hooks.keys()):
    groups = hooks[event]
    filtered = []
    for group in groups:
        group_hooks = group.get("hooks", [])
        remaining = [
            h for h in group_hooks
            if not any(cmd in h.get("command", "") for cmd in our_commands)
        ]
        if remaining:
            group["hooks"] = remaining
            filtered.append(group)
    if filtered:
        hooks[event] = filtered
    else:
        del hooks[event]

if not hooks:
    if "hooks" in settings:
        del settings["hooks"]

with open(path, "w") as f:
    json.dump(settings, f, indent=2)

print("  Cleaned settings.json")
PYTHON
fi

# ── Done ───────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Claude Orchestrator v2 uninstalled!"
echo "============================================"
echo ""
echo "Note: Project-level files were NOT removed."
echo "Delete them manually if you want:"
echo "  rm your-project/.claude/HANDOFF.md"
echo "  rm your-project/.claude/task-queue.json"
echo "  rm your-project/.claude/task-queue.md"
echo "  rm -rf your-project/.claude/backups/"
