# Orchestrator Protocol v3
# Kopiere diesen Block in die CLAUDE.md deines Projekts.

## Delegation (PFLICHT)

- **Codebase lesen/verstehen:** Explore-Agent (subagent_type=Explore) — NICHT selbst >3 Dateien lesen
- **Code schreiben (>30 Zeilen):** Task-Agent (general-purpose oder spezialisiert)
- **Unabhaengige Aenderungen:** Agents PARALLEL starten (ein Message, mehrere Tool-Calls)
- **Dein Hauptcontext = Denken, Entscheiden, Koordinieren** — NICHT Lesen und Schreiben

## Checkpoint-Protokoll (KRITISCH)

**CHECKPOINT.md ist die Lebensversicherung deiner Session.**
Bei ${THRESHOLD:-55}%+ Context wird CHECKPOINT.md automatisch zur HANDOFF.md kopiert.
Wenn die CHECKPOINT.md leer oder veraltet ist, geht der gesamte Session-Fortschritt verloren.

**Regel: Nach JEDER abgeschlossenen Teilaufgabe sofort `.claude/CHECKPOINT.md` updaten.**

Format:
```markdown
# Checkpoint — {Datum} {Uhrzeit}

## Ziel
{Gesamtziel des Projekts/Tasks}

## Erledigt
- [x] Beschreibung (Dateien: pfad1, pfad2)
- [x] Beschreibung (Dateien: pfad3)

## Offen
- [ ] Beschreibung
- [ ] Beschreibung

## Entscheidungen
- Entscheidung: Begruendung

## Build/Test-Status
- Build: OK/FEHLER
- Tests: N/M bestanden
- Letzter Commit: {hash} {message}

## Naechster Schritt
{Exakt was als naechstes zu tun ist, inkl. welcher Agent-Typ}
```

## Phasen-Workflow (pro Aufgabe)

1. **Verstehen** — Explore-Agent(s), Codebase analysieren
2. **Planen** — Kurzer Plan (3-5 Schritte), User bestaetigen lassen falls nicht trivial
3. **Ausfuehren** — Pro Schritt: Agent delegieren, Ergebnis pruefen, **CHECKPOINT updaten**
4. **Verifizieren** — Tests + Build
5. **Checkpoint** — `.claude/CHECKPOINT.md` finalisieren

## Context-Ampel (StatusLine beachten!)

| StatusLine | Bedeutung | Aktion |
|------------|-----------|--------|
| 🟢 unter 45% | Safe Zone | Normal delegieren, Workflow befolgen |
| 🟡 45-55% | Approaching | Aggressiv delegieren, KEINE Dateien selbst lesen, grosse Agents nutzen |
| 🟠 55%+ | Critical | **SOFORT** CHECKPOINT.md finalisieren, dann aktuelle Arbeit abschliessen. Kein neuer Code! |
| 🔴 60%+ | Handoff | Session wird automatisch beendet. CHECKPOINT → HANDOFF ist bereits kopiert. |

**Bei 🟠 (Critical):** ZUERST .claude/CHECKPOINT.md mit komplettem Stand schreiben, DANN den User informieren.
Die CHECKPOINT.md wird automatisch zur HANDOFF.md — du musst nur sicherstellen, dass sie aktuell ist.

## Session-Uebergabe

- CHECKPOINT.md wird nach jeder Teilaufgabe aktualisiert (deine Pflicht!)
- Bei Context-Limit: CHECKPOINT.md → HANDOFF.md (automatisch durch stop-check.sh)
- Naechste Session laedt den Stand automatisch via session-start.sh
- Die vorherige CHECKPOINT.md bleibt als `.claude/.last-checkpoint.md` erhalten
- Starte Claude mit `~/.claude/auto-session.sh` fuer automatische Neustarts
