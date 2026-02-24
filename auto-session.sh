#!/bin/bash
# auto-session.sh — Claude Orchestrator v3: Auto-Restart Wrapper
#
# Startet Claude Code in einer Schleife. Wenn Claude sich beendet und
# eine HANDOFF.md existiert, startet das Skript automatisch eine neue
# Session. Der Handoff wird von session-start.sh geladen.
#
# Nutzung:
#   cd dein-projekt/
#   ~/claude-orchestrator/auto-session.sh
#
# Mit Projekt-Pfad:
#   ~/claude-orchestrator/auto-session.sh /pfad/zum/projekt
#
# Mit Extra-Flags fuer Claude:
#   ~/claude-orchestrator/auto-session.sh /pfad/zum/projekt --model opus --verbose
#
# Beenden: Ctrl+C oder /exit ohne offene Tasks

set -e

# First arg = project dir (optional, default = cwd)
PROJECT_DIR="${1:-.}"
if [ "$#" -ge 1 ]; then
    shift
fi
EXTRA_FLAGS=("$@")

cd "$PROJECT_DIR"
PROJECT_DIR="$(pwd)"

# Read max_restarts from project config or default
CONFIG_FILE="$PROJECT_DIR/.claude/orchestrator.json"
MAX_RESTARTS=20
if [ -f "$CONFIG_FILE" ]; then
    CUSTOM=$(python3 -c "
import json
try:
    with open('$CONFIG_FILE') as f:
        print(int(json.load(f).get('max_restarts', 20)))
except:
    print(20)
" 2>/dev/null)
    MAX_RESTARTS=${CUSTOM:-20}
fi

RESTART_COUNT=0
SESSION_LOG="$PROJECT_DIR/.claude/sessions.log"
PROTOCOL_TEMPLATE=~/.claude/templates/ORCHESTRATOR-PROTOCOL.md
CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
# Bug 7 Fix: Robusterer Marker-Kommentar statt fragiler Text-Suche
PROTOCOL_MARKER="<!-- ORCHESTRATOR-PROTOCOL-V3 -->"
mkdir -p "$PROJECT_DIR/.claude"

# ── Auto-inject Orchestrator Protocol into CLAUDE.md ──────────────
# Checks if protocol is already present via marker comment.
# This is the "brain" — without it, Claude doesn't write checkpoints
# or delegate to sub-agents. Hooks alone are just infrastructure.
if [ -f "$PROTOCOL_TEMPLATE" ]; then
    if [ ! -f "$CLAUDE_MD" ]; then
        # No CLAUDE.md exists → create with protocol + marker
        echo "$PROTOCOL_MARKER" > "$CLAUDE_MD"
        cat "$PROTOCOL_TEMPLATE" >> "$CLAUDE_MD"
        echo "✅ CLAUDE.md erstellt mit Orchestrator-Protokoll"
    elif ! grep -qF "$PROTOCOL_MARKER" "$CLAUDE_MD" 2>/dev/null; then
        # CLAUDE.md exists but no marker → append
        {
            echo ""
            echo "$PROTOCOL_MARKER"
            cat "$PROTOCOL_TEMPLATE"
        } >> "$CLAUDE_MD"
        echo "✅ Orchestrator-Protokoll in CLAUDE.md ergaenzt"
    fi
fi

echo "╔════════════════════════════════════════════════════╗"
echo "║  Claude Orchestrator v3 — Auto-Session             ║"
echo "║  Projekt: $(basename "$PROJECT_DIR")"
echo "║  Checkpoint → Auto-Handoff → Auto-Restart          ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# Clean up stale handoff-done flags from previous runs
rm -f ~/.claude/handoff-done-* 2>/dev/null

while true; do
    RESTART_COUNT=$((RESTART_COUNT + 1))

    if [ "$RESTART_COUNT" -gt "$MAX_RESTARTS" ]; then
        echo ""
        echo "⚠️  Max restarts ($MAX_RESTARTS) erreicht. Beende."
        echo "    Falls das unerwartet ist: HANDOFF.md manuell loeschen."
        exit 1
    fi

    if [ "$RESTART_COUNT" -gt 1 ]; then
        echo ""
        echo "♻️  Auto-Restart #$((RESTART_COUNT - 1)) — Neue Session startet..."
        echo "   Handoff wird automatisch geladen."
        echo ""
        sleep 2
    fi

    # ── Log session start ─────────────────────────────────────────
    SESSION_START=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$SESSION_START] Session #$RESTART_COUNT started" >> "$SESSION_LOG"

    # ── Start Claude Code ─────────────────────────────────────────
    # Pass extra flags (--model, --verbose, etc.) to claude
    if [ "${#EXTRA_FLAGS[@]}" -gt 0 ]; then
        claude "${EXTRA_FLAGS[@]}" || true
    else
        claude || true
    fi

    # ── Log session end ───────────────────────────────────────────
    SESSION_END=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$SESSION_END] Session #$RESTART_COUNT ended" >> "$SESSION_LOG"

    # ── After Claude exits: check for handoff ─────────────────────
    HANDOFF_FILE="$PROJECT_DIR/.claude/HANDOFF.md"

    if [ -f "$HANDOFF_FILE" ]; then
        # Handoff exists → auto-restart
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  📋 Handoff erkannt — Session wird neu gestartet"
        echo "  Druecke Ctrl+C in 3s zum Abbrechen..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        # Give user a chance to abort
        sleep 3 || {
            echo ""
            echo "Abgebrochen. Handoff bleibt in: $HANDOFF_FILE"
            exit 0
        }

        # Clean up handoff-done flags for fresh session
        rm -f ~/.claude/handoff-done-* 2>/dev/null

        continue
    fi

    # No handoff → clean exit
    echo ""
    echo "Session beendet. Kein Handoff vorhanden."
    break
done
