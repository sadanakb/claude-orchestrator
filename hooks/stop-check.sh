#!/bin/bash
# stop-check.sh — Claude Orchestrator v3
# Fires when Claude finishes a response
# Single job: If context exceeds threshold → trigger handoff

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('session_id', 'unknown'))
except:
    print('unknown')
" 2>/dev/null)
SESSION_ID=${SESSION_ID:-unknown}

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_FILE=~/.claude/context-state.json

# Bug 2 Fix: Unique handoff flag per session + project (prevents cross-project collisions)
PROJECT_HASH=$(echo "$PROJECT_DIR" | md5sum 2>/dev/null | cut -c1-8 || echo "$PROJECT_DIR" | md5 -q 2>/dev/null | cut -c1-8 || echo "nohash")
HANDOFF_FLAG=~/.claude/handoff-done-${SESSION_ID}-${PROJECT_HASH}

HANDOFF_FILE="$PROJECT_DIR/.claude/HANDOFF.md"
CHECKPOINT_FILE="$PROJECT_DIR/.claude/CHECKPOINT.md"
CONFIG_FILE="$PROJECT_DIR/.claude/orchestrator.json"

# Already triggered this session? Skip.
if [ -f "$HANDOFF_FLAG" ]; then
    exit 0
fi

if [ ! -f "$STATE_FILE" ]; then
    exit 0
fi

# Read threshold from project config or default to 55%
THRESHOLD=55
if [ -f "$CONFIG_FILE" ]; then
    CUSTOM=$(python3 -c "
import json
try:
    with open('$CONFIG_FILE') as f:
        print(int(json.load(f).get('threshold_percent', 55)))
except:
    print(55)
" 2>/dev/null)
    THRESHOLD=${CUSTOM:-55}
fi

# Read current context remaining
REMAINING=$(python3 -c "
import json
try:
    with open('$STATE_FILE') as f:
        d = json.load(f)
    print(int(d.get('remaining', 100)))
except:
    print(100)
" 2>/dev/null)
REMAINING=${REMAINING:-100}

USED=$((100 - REMAINING))

# Check if over threshold
if [ "$USED" -lt "$THRESHOLD" ] 2>/dev/null; then
    exit 0
fi

# ── THRESHOLD EXCEEDED — Trigger Handoff ──────────────────────────
touch "$HANDOFF_FLAG"
mkdir -p "$PROJECT_DIR/.claude"

# Bug 1+8 Fix: CHECKPOINT → HANDOFF sofort kopieren (beste verfügbare Daten)
if [ -f "$CHECKPOINT_FILE" ] && [ -s "$CHECKPOINT_FILE" ]; then
    # Checkpoint existiert und ist nicht leer → als Handoff verwenden
    cp "$CHECKPOINT_FILE" "$HANDOFF_FILE"
    {
        echo ""
        echo "---"
        echo "_Session beendet bei ${USED}% Context — naechste Session uebernimmt._"
    } >> "$HANDOFF_FILE"

    # Tell Claude to finalize (but handoff is already safe)
    echo "
⚠️  CONTEXT BEI ${USED}% — AUTOMATISCHER HANDOFF

Die CHECKPOINT.md wurde als HANDOFF.md gesichert.

1. Aktualisiere JETZT .claude/CHECKPOINT.md mit dem aktuellen Stand:
   - Was wurde in dieser Session erledigt (Dateien + Zusammenfassung)
   - Was ist noch offen (TODOs mit Prioritaet)
   - Exakter naechster Schritt

2. Die aktualisierte CHECKPOINT.md wird automatisch als HANDOFF.md uebernommen.

3. Sage dem User: Die Session ist bei ${USED}% Context — bitte /exit tippen fuer automatischen Neustart.

WICHTIG: Kein neuer Code mehr. Nur Checkpoint finalisieren.
" >&2

elif [ ! -f "$HANDOFF_FILE" ]; then
    # Kein Checkpoint vorhanden — Claude muss HANDOFF direkt schreiben
    # Bug 1 Fix: KEINE leeren Platzhalter, sondern klare Anweisung
    echo "
⚠️  CONTEXT BEI ${USED}% — AUTOMATISCHER HANDOFF (KEIN CHECKPOINT VORHANDEN)

Es existiert keine CHECKPOINT.md. Du MUSST jetzt .claude/HANDOFF.md schreiben.

Schreibe die Datei .claude/HANDOFF.md mit ECHTEM INHALT — KEINE Platzhalter:

# Handoff — $(date '+%Y-%m-%d %H:%M')

## Ziel
{Das Gesamtziel dieser Session — was wurde beauftragt?}

## Erledigt
- [x] {Konkret was du gemacht hast, mit Dateipfaden}

## Offen
- [ ] {Was noch fehlt}

## Entscheidungen
- {Welche technischen Entscheidungen wurden getroffen}

## Naechster Schritt
{Exakt was die naechste Session als erstes tun soll}

Sage dem User: Bitte /exit tippen fuer automatischen Neustart.

WICHTIG: Die Sektionen MUESSEN echten Inhalt haben. Schreibe auf, was du weisst.
" >&2
fi

exit 2
