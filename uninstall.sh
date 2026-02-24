#!/bin/bash
# uninstall.sh — Claude Orchestrator v3
set -e

echo "Uninstalling Claude Orchestrator v3..."
echo ""

HOOKS_DIR=~/.claude/hooks
SETTINGS_FILE=~/.claude/settings.json

# ── Remove hooks ─────────────────────────────────────────────────
echo "Removing hooks..."
for f in statusline.sh stop-check.sh session-start.sh pre-compact.sh; do
    if [ -f "$HOOKS_DIR/$f" ]; then
        rm "$HOOKS_DIR/$f"
        echo "  Removed $f"
    fi
done

# Remove old v2 files if still present
for f in prompt-guard.py; do
    if [ -f "$HOOKS_DIR/$f" ]; then
        rm "$HOOKS_DIR/$f"
        echo "  Removed old $f"
    fi
done

# ── Remove auto-session wrapper ──────────────────────────────────
if [ -f ~/.claude/auto-session.sh ]; then
    rm ~/.claude/auto-session.sh
    echo "  Removed auto-session.sh"
fi

# ── Remove slash commands ────────────────────────────────────────
for f in checkpoint.md handoff.md; do
    if [ -f ~/.claude/commands/$f ]; then
        rm ~/.claude/commands/$f
        echo "  Removed /$(basename $f .md) command"
    fi
done

# ── Remove template ─────────────────────────────────────────────
if [ -f ~/.claude/templates/ORCHESTRATOR-PROTOCOL.md ]; then
    rm ~/.claude/templates/ORCHESTRATOR-PROTOCOL.md
    echo "  Removed orchestrator protocol template"
fi

# ── Remove old orchestrator skill (if exists from v2-full) ──────
if [ -d ~/.claude/skills/orchestrator ]; then
    rm -rf ~/.claude/skills/orchestrator
    echo "  Removed old orchestrator skill"
fi

# ── Remove state files ──────────────────────────────────────────
echo ""
echo "Cleaning up state files..."
rm -f ~/.claude/context-state.json
rm -f ~/.claude/handoff-done-*
echo "  Done"

# ── Clean settings.json ─────────────────────────────────────────
echo ""
if [ -f "$SETTINGS_FILE" ]; then
    python3 - "$SETTINGS_FILE" << 'PYTHON'
import json, sys

path = sys.argv[1]
with open(path) as f:
    settings = json.load(f)

sl = settings.get("statusLine", {})
if isinstance(sl, dict) and "statusline.sh" in sl.get("command", ""):
    del settings["statusLine"]

our_commands = {"session-start.sh", "stop-check.sh", "pre-compact.sh", "prompt-guard.py"}
hooks = settings.get("hooks", {})

# Remove UserPromptSubmit entirely (was prompt-guard.py)
if "UserPromptSubmit" in hooks:
    del hooks["UserPromptSubmit"]

for event in list(hooks.keys()):
    groups = hooks[event]
    filtered = []
    for group in groups:
        group_hooks = group.get("hooks", [])
        remaining = [h for h in group_hooks if not any(cmd in h.get("command", "") for cmd in our_commands)]
        if remaining:
            group["hooks"] = remaining
            filtered.append(group)
    if filtered:
        hooks[event] = filtered
    else:
        del hooks[event]

if not hooks and "hooks" in settings:
    del settings["hooks"]

with open(path, "w") as f:
    json.dump(settings, f, indent=2)
print("  Cleaned settings.json")
PYTHON
fi

echo ""
echo "Uninstalled. Project files (.claude/CHECKPOINT.md, .claude/HANDOFF.md) were NOT removed."
