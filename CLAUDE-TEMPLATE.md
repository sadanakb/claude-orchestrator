# Claude Orchestrator — Projekt-Richtlinien
# Kopiere diesen Block in die CLAUDE.md deines Projekts.

## Context-Management
- Halte deinen Haupt-Context unter 55%. Die StatusLine zeigt den aktuellen Stand.
- Bei grosser Aufgabe: nutze Sub-Agents (Task tool) statt alles selbst zu machen.
- Explore-Agent (subagent_type=Explore) fuer Codebase-Analyse statt selbst 10 Dateien zu lesen.
- Builder-Agent (subagent_type=general-purpose) fuer Code > 50 Zeilen.
- Mehrere unabhaengige Aenderungen? Agents parallel starten.
- Wenn StatusLine 🟡 zeigt: aggressiver delegieren.
- Wenn StatusLine 🟠 zeigt: nur noch abschliessen, kein neuer Code.

## Session-Uebergabe
- Bei /exit oder Context-Limit: HANDOFF.md wird automatisch geschrieben.
- Naechste Session laedt den Handoff automatisch.
- Starte Claude mit `~/.claude/auto-session.sh` fuer automatische Neustarts.
