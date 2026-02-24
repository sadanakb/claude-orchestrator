#!/bin/bash
# install.sh — Claude Orchestrator v3
# One-time global setup. Run once → works for ALL Claude Code sessions.
set -e

echo "Installing Claude Orchestrator v3..."
echo ""

HOOKS_DIR=~/.claude/hooks
COMMANDS_DIR=~/.claude/commands
TEMPLATES_DIR=~/.claude/templates
SETTINGS_FILE=~/.claude/settings.json
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Verify source files exist ──────────────────────────────────────
echo "Verifying source files..."
MISSING=false
for f in hooks/statusline.sh hooks/stop-check.sh hooks/session-start.sh hooks/pre-compact.sh; do
    if [ ! -f "$SCRIPT_DIR/$f" ]; then
        echo "  ERROR: Missing $SCRIPT_DIR/$f" >&2
        MISSING=true
    fi
done
for f in commands/checkpoint.md auto-session.sh templates/ORCHESTRATOR-PROTOCOL.md; do
    if [ ! -f "$SCRIPT_DIR/$f" ]; then
        echo "  ERROR: Missing $SCRIPT_DIR/$f" >&2
        MISSING=true
    fi
done
if [ "$MISSING" = true ]; then
    echo "Installation aborted." >&2
    exit 1
fi
echo "  All source files present"

# ── Remove old v2 files if present ────────────────────────────────
if [ -f "$HOOKS_DIR/prompt-guard.py" ]; then
    rm "$HOOKS_DIR/prompt-guard.py"
    echo "  Removed old prompt-guard.py"
fi
if [ -f "$COMMANDS_DIR/handoff.md" ]; then
    rm "$COMMANDS_DIR/handoff.md"
    echo "  Removed old /handoff command (replaced by /checkpoint)"
fi

# ── Install hooks ──────────────────────────────────────────────────
mkdir -p "$HOOKS_DIR"
echo ""
echo "Installing hooks to $HOOKS_DIR..."
cp "$SCRIPT_DIR/hooks/statusline.sh"    "$HOOKS_DIR/statusline.sh"
cp "$SCRIPT_DIR/hooks/stop-check.sh"    "$HOOKS_DIR/stop-check.sh"
cp "$SCRIPT_DIR/hooks/session-start.sh" "$HOOKS_DIR/session-start.sh"
cp "$SCRIPT_DIR/hooks/pre-compact.sh"   "$HOOKS_DIR/pre-compact.sh"
chmod +x "$HOOKS_DIR"/*.sh
echo "  Installed 4 hooks"

# ── Install slash command ──────────────────────────────────────────
mkdir -p "$COMMANDS_DIR"
echo ""
echo "Installing /checkpoint command..."
cp "$SCRIPT_DIR/commands/checkpoint.md" "$COMMANDS_DIR/checkpoint.md"
echo "  Installed /checkpoint"

# ── Install template ──────────────────────────────────────────────
mkdir -p "$TEMPLATES_DIR"
echo ""
echo "Installing orchestrator protocol template..."
cp "$SCRIPT_DIR/templates/ORCHESTRATOR-PROTOCOL.md" "$TEMPLATES_DIR/ORCHESTRATOR-PROTOCOL.md"
echo "  Installed to $TEMPLATES_DIR/ORCHESTRATOR-PROTOCOL.md"

# ── Install auto-session wrapper ──────────────────────────────────
echo ""
echo "Installing auto-session wrapper..."
cp "$SCRIPT_DIR/auto-session.sh" ~/.claude/auto-session.sh
chmod +x ~/.claude/auto-session.sh
echo "  Installed ~/.claude/auto-session.sh"

# ── Configure settings.json ──────────────────────────────────────
echo ""
echo "Configuring $SETTINGS_FILE..."

# Backup existing settings before modifying
if [ -f "$SETTINGS_FILE" ]; then
    cp "$SETTINGS_FILE" "${SETTINGS_FILE}.backup"
    echo "  Backed up existing settings to settings.json.backup"
fi

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

# Update statusLine
existing["statusLine"] = new["statusLine"]

if "hooks" not in existing:
    existing["hooks"] = {}

# Remove old UserPromptSubmit hook (prompt-guard.py)
if "UserPromptSubmit" in existing.get("hooks", {}):
    del existing["hooks"]["UserPromptSubmit"]

# Merge new hooks
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
                    break

with open(existing_path, "w") as f:
    json.dump(existing, f, indent=2)

print("  Merged into existing settings.json")
PYTHON
fi

# ── Final output ─────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Claude Orchestrator v3 installed!"
echo "============================================"
echo ""
echo "Starte Claude ab jetzt mit:"
echo "  ~/.claude/auto-session.sh /pfad/zum/projekt"
echo ""
echo "Was passiert:"
echo "  Nach jeder Teilaufgabe → Checkpoint (.claude/CHECKPOINT.md)"
echo "  Context > 55% → Handoff → /exit → Auto-Restart"
echo "  StatusLine zeigt: 🟢 35% | ✓3 | projekt-name"
echo ""
echo "WICHTIG: Kopiere den Inhalt von"
echo "  $TEMPLATES_DIR/ORCHESTRATOR-PROTOCOL.md"
echo "in die CLAUDE.md deines Projekts:"
echo ""
echo "  cat $TEMPLATES_DIR/ORCHESTRATOR-PROTOCOL.md"
echo ""
echo "Optional: .claude/orchestrator.json erstellen fuer eigene Thresholds:"
echo "  cp $SCRIPT_DIR/orchestrator.json.example /dein-projekt/.claude/orchestrator.json"
echo ""
echo "Deinstallation: $SCRIPT_DIR/uninstall.sh"
