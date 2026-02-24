# Claude Orchestrator v2 (Slim)

Automatisches Context-Management fuer Claude Code. Wenn der Context voll wird, passiert alles von alleine: Handoff schreiben, Session beenden, neu starten, weitermachen.

## Was es macht

1. **Auto-Handoff** — Bei 55% Context schreibt `stop-check.sh` automatisch eine HANDOFF.md
2. **Auto-Restart** — `auto-session.sh` startet Claude neu wenn ein Handoff existiert
3. **Task-Queue** — Bei 3+ Tasks in einer Nachricht: eins nach dem anderen, nicht alles auf einmal
4. **StatusLine** — Zeigt live: Context% + Task-Progress + Projekt

## Was es NICHT macht (bewusst entfernt)

- ~~Komplexitaets-Scoring~~ — Regex kann Intent nicht verstehen
- ~~Orchestrator-Injection~~ — Claude ignoriert injizierte Anweisungen oft
- ~~Erzwungene Delegation~~ — Gehoert in CLAUDE.md, nicht in per-Message-Hooks

## Installation

```bash
git clone <repo-url> ~/claude-orchestrator
cd ~/claude-orchestrator
chmod +x install.sh
./install.sh
```

## Nutzung

```bash
# Starte Claude immer so:
~/.claude/auto-session.sh /pfad/zum/projekt
```

Was passiert:
```
Claude arbeitet... 🟢 30% → 🟡 48% → 🟠 56%
  → stop-check: Schreibt HANDOFF.md automatisch
  → Claude: "Tippe /exit"
  → Du: /exit
  → Wrapper: "Handoff erkannt, starte neu..."
  → Neue Session laedt Handoff → weiter geht's
  → Aufgabe fertig → /exit → kein Handoff → Wrapper stoppt
```

## Dateien

```
claude-orchestrator/
├── hooks/
│   ├── prompt-guard.py      # Multi-Task-Queue + Post-Handoff-Nudge
│   ├── statusline.sh        # Context% + Task-Progress
│   ├── session-start.sh     # Handoff laden + konsumieren
│   ├── stop-check.sh        # Auto-Handoff bei 55%
│   └── pre-compact.sh       # State-Backup vor Compaction
├── commands/
│   └── handoff.md           # /handoff Slash-Command
├── auto-session.sh          # Wrapper: Auto-Restart-Loop
├── CLAUDE-TEMPLATE.md       # Copy-paste fuer deine CLAUDE.md
├── settings.json            # Hook-Konfiguration
├── install.sh               # Installation
└── uninstall.sh             # Deinstallation
```

## Optional: CLAUDE.md Richtlinien

Kopiere den Inhalt von `CLAUDE-TEMPLATE.md` in die CLAUDE.md deines Projekts. Das gibt Claude Richtlinien fuer Sub-Agent-Nutzung — ohne per-Message-Overhead.

## Deinstallation

```bash
cd ~/claude-orchestrator
./uninstall.sh
```
