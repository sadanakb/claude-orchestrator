Update .claude/CHECKPOINT.md with the current state of this session.

IMPORTANT: This file is your session's safety net. When context reaches the threshold,
CHECKPOINT.md is automatically copied to HANDOFF.md for the next session.
If this file is empty or outdated, the next session starts blind.

Write the file with this EXACT structure — every section MUST have real content:

```markdown
# Checkpoint — [AKTUELLES DATUM UND UHRZEIT EINFUEGEN]

## Ziel
{Das Gesamtziel der aktuellen Aufgabe/des Projekts}

## Erledigt
- [x] {Konkrete Beschreibung} (Dateien: pfad1, pfad2)
- [x] {Konkrete Beschreibung} (Dateien: pfad3)

## Offen
- [ ] {Was noch fehlt — mit Prioritaet}
- [ ] {Naechste Aufgabe}

## Entscheidungen
- {Technische Entscheidung}: {Begruendung}

## Build/Test-Status
- Build: OK/FEHLER {Details}
- Tests: N/M bestanden
- Letzter Commit: {hash} {message}

## Naechster Schritt
{Exakt was als naechstes zu tun ist, inkl. welcher Agent-Typ empfohlen wird}
```

Rules:
- OVERWRITE the entire file (do not append)
- Every section must contain real, specific content — no placeholders
- Include file paths in "Erledigt" so the next session knows what was changed
- "Naechster Schritt" must be specific enough that a fresh session can continue immediately

After writing, confirm the checkpoint was saved and show a brief summary.
