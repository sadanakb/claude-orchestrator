# Orchestrator Protocol v3
# Kopiere diesen Block in die CLAUDE.md deines Projekts.

## Delegation (PFLICHT)

- **Codebase lesen/verstehen:** Explore-Agent (subagent_type=Explore) — NICHT selbst >3 Dateien lesen
- **Code schreiben (>30 Zeilen):** Task-Agent (general-purpose oder spezialisiert)
- **Unabhaengige Aenderungen:** Agents PARALLEL starten (ein Message, mehrere Tool-Calls)
- **Dein Hauptcontext = Denken, Entscheiden, Koordinieren** — NICHT Lesen und Schreiben

## Checkpoint-Protokoll

Nach jeder abgeschlossenen Teilaufgabe: `.claude/CHECKPOINT.md` updaten (ueberschreiben, nicht anhaengen).

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
3. **Ausfuehren** — Pro Schritt: Agent delegieren, Ergebnis pruefen
4. **Verifizieren** — Tests + Build
5. **Checkpoint** — `.claude/CHECKPOINT.md` updaten

## Context-Ampel (StatusLine beachten!)

| StatusLine | Bedeutung | Aktion |
|------------|-----------|--------|
| 🟢 unter 45% | Safe Zone | Normal delegieren, Workflow befolgen |
| 🟡 45-55% | Approaching | Aggressiv delegieren, KEINE Dateien mehr selbst lesen, grosse Agents nutzen |
| 🟠 55%+ | Critical | NUR noch aktuelle Arbeit abschliessen, Checkpoint schreiben, /exit empfehlen |

## Session-Uebergabe

- Checkpoint wird nach jeder Teilaufgabe automatisch aktualisiert
- Bei `/exit` oder Context-Limit: CHECKPOINT.md → HANDOFF.md (automatisch)
- Naechste Session laedt den Stand automatisch
- Starte Claude mit `~/.claude/auto-session.sh` fuer automatische Neustarts
