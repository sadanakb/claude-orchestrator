#!/bin/bash
# auto-session.sh — Claude Orchestrator v2: Auto-Restart Wrapper
#
# Startet Claude Code in einer Schleife. Wenn Claude sich beendet und
# eine HANDOFF.md existiert, startet das Skript automatisch eine neue
# Session. Der Handoff wird von session-start.sh geladen.
#
# Nutzung:
#   cd dein-projekt/
#   ~/claude-orchestrator/auto-session.sh
#
# Oder mit Projekt-Pfad:
#   ~/claude-orchestrator/auto-session.sh /pfad/zum/projekt
#
# Beenden: Ctrl+C oder /exit ohne offene Tasks

set -e

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"
PROJECT_DIR="$(pwd)"

# Max restarts to prevent infinite loops
MAX_RESTARTS=20
RESTART_COUNT=0

echo "╔══════════════════════════════════════════════╗"
echo "║  Claude Orchestrator v2 — Auto-Session       ║"
echo "║  Projekt: $(basename "$PROJECT_DIR")                        "
echo "║  Context-Limit → Auto-Handoff → Auto-Restart ║"
echo "╚══════════════════════════════════════════════╝"
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

    # ── Start Claude Code ──────────────────────────────────────
    # claude exits when user types /exit or Ctrl+D
    claude || true

    # ── After Claude exits: check for handoff ──────────────────
    HANDOFF_FILE="$PROJECT_DIR/.claude/HANDOFF.md"

    if [ -f "$HANDOFF_FILE" ]; then
        # Handoff exists → auto-restart
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  📋 Handoff erkannt — Session wird neu gestartet"
        echo "  Druecke Ctrl+C in 3s zum Abbrechen..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

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
