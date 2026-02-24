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
HANDOFF_FLAG=~/.claude/handoff-done-${SESSION_ID}
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

# If CHECKPOINT.md exists → use it as handoff base (much better than empty template)
if [ -f "$CHECKPOINT_FILE" ] && [ ! -f "$HANDOFF_FILE" ]; then
    cp "$CHECKPOINT_FILE" "$HANDOFF_FILE"
    # Append session-end marker
    echo "" >> "$HANDOFF_FILE"
    echo "---" >> "$HANDOFF_FILE"
    echo "_Session beendet bei ${USED}% Context — naechste Session uebernimmt._" >> "$HANDOFF_FILE"
elif [ ! -f "$HANDOFF_FILE" ]; then
    # No checkpoint exists → write minimal template
    cat > "$HANDOFF_FILE" << HANDOFF_EOF
# Handoff — $(date '+%Y-%m-%d %H:%M') (auto-generated)

## Ziel
[Session wurde automatisch beendet — Context bei ${USED}%]

## Erledigt
[Claude soll diese Sektion beim naechsten Start ergaenzen]

## Offen
[Aus dem letzten Gespraech ableiten]

## Entscheidungen
[Aus dem letzten Gespraech ableiten]

## Naechster Schritt
[Aus dem letzten Gespraech ableiten]
HANDOFF_EOF
fi

# Tell Claude: finalize checkpoint and exit
echo "
⚠️  CONTEXT BEI ${USED}% — AUTOMATISCHER HANDOFF

1. Finalisiere JETZT .claude/CHECKPOINT.md mit dem echten Stand:
   - Was wurde gemacht (Dateien + Zusammenfassung)
   - Was ist noch offen (TODOs mit Prioritaet)
   - Exakter naechster Schritt

2. Sage dem User: **Tippe /exit — die Session startet automatisch neu.**

WICHTIG: Kein neuer Code mehr. Nur Checkpoint finalisieren und Session beenden.
" >&2
exit 2
