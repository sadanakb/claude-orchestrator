#!/bin/bash
# install.sh — Claude Orchestrator v2 (Slim)
# One-time global setup. Run once → works for ALL Claude Code sessions.
set -e

echo "Installing Claude Orchestrator v2 (Slim)..."
echo ""

HOOKS_DIR=~/.claude/hooks
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
for f in commands/handoff.md auto-session.sh; do
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
echo "  Installed 5 hooks"

# ── Install slash command ──────────────────────────────────────────
mkdir -p "$COMMANDS_DIR"
echo ""
echo "Installing /handoff command..."
cp "$SCRIPT_DIR/commands/handoff.md" "$COMMANDS_DIR/handoff.md"
echo "  Installed /handoff"

# ── Install auto-session wrapper ───────────────────────────────────
echo ""
echo "Installing auto-session wrapper..."
cp "$SCRIPT_DIR/auto-session.sh" ~/.claude/auto-session.sh
chmod +x ~/.claude/auto-session.sh
echo "  Installed ~/.claude/auto-session.sh"

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

existing["statusLine"] = new["statusLine"]

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
                    break

with open(existing_path, "w") as f:
    json.dump(existing, f, indent=2)

print("  Merged into existing settings.json")
PYTHON
fi

# ── Show CLAUDE.md template ────────────────────────────────────────
echo ""
echo "============================================"
echo "  Claude Orchestrator v2 (Slim) installed!"
echo "============================================"
echo ""
echo "Starte Claude ab jetzt mit:"
echo "  ~/.claude/auto-session.sh /pfad/zum/projekt"
echo ""
echo "Was passiert:"
echo "  3+ Tasks in einer Nachricht → Queue (eins nach dem anderen)"
echo "  Context > 55% → Handoff → /exit → Auto-Restart"
echo "  StatusLine zeigt: 🟢 Context% | Task 2/5 | projekt"
echo ""
echo "OPTIONAL: Kopiere diese Zeilen in die CLAUDE.md deines Projekts"
echo "fuer bessere Sub-Agent-Nutzung:"
echo ""
cat "$SCRIPT_DIR/CLAUDE-TEMPLATE.md"
echo ""
echo ""
echo "To uninstall: $SCRIPT_DIR/uninstall.sh"
