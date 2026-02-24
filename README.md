# Claude Orchestrator v3

Automatisches Context-Management fuer Claude Code. Checkpoint-System statt einmaligem Handoff, CLAUDE.md als Orchestrator statt Hook-Injections, Zero API-Calls.

## Was sich gegenueber v2 geaendert hat

| v2 | v3 |
|----|-----|
| Einmaliger Handoff bei 55% | Checkpoint nach jeder Teilaufgabe |
| 5 Hooks (inkl. prompt-guard.py mit API-Call) | 4 Hooks (reine Shell-Skripte, Zero Latency) |
| Task-Queue in JSON (buggy) | Checkpoint in Markdown (einfach, lesbar) |
| Hook-Injection fuer Delegation | CLAUDE.md-Protokoll (zuverlaessiger) |
| Leeres Handoff-Template bei Crash | CHECKPOINT.md als Handoff-Basis |

## Was es macht

1. **Checkpoint-System** — Nach jeder Teilaufgabe schreibt Claude `.claude/CHECKPOINT.md` mit dem aktuellen Stand
2. **Auto-Handoff** — Bei 55%+ Context wird CHECKPOINT.md zur HANDOFF.md kopiert und die Session beendet
3. **Auto-Restart** — `auto-session.sh` startet Claude neu wenn ein Handoff existiert
4. **StatusLine** — Zeigt live: Context% + Checkpoint-Count + Projekt

## Was es NICHT macht (bewusst entfernt)

- ~~API-Calls~~ — Kein Haiku, kein ANTHROPIC_API_KEY noetig
- ~~Task-Queue~~ — War buggy (alle in_progress Tasks wurden nach jeder Antwort completed)
- ~~Hook-Injection fuer Delegation~~ — Claude ignoriert injizierte Anweisungen oft
- ~~Komplexitaets-Scoring~~ — Regex kann Intent nicht verstehen

## Installation

```bash
git clone <repo-url> ~/claude-orchestrator
cd ~/claude-orchestrator
chmod +x install.sh
./install.sh
```

### CLAUDE.md konfigurieren

Der wichtigste Schritt: Kopiere das Orchestrator-Protokoll in die CLAUDE.md deines Projekts:

```bash
cat ~/.claude/templates/ORCHESTRATOR-PROTOCOL.md >> /dein-projekt/CLAUDE.md
```

Das Protokoll gibt Claude Anweisungen fuer:
- **Delegation** — Wann Sub-Agents nutzen (Explore, Build, Parallel)
- **Checkpoints** — Wann und wie `.claude/CHECKPOINT.md` schreiben
- **Context-Ampel** — Was bei 🟢🟡🟠🔴 zu tun ist

### Optionale Konfiguration

Erstelle `.claude/orchestrator.json` in deinem Projekt fuer eigene Werte:

```bash
cp ~/claude-orchestrator/orchestrator.json.example /dein-projekt/.claude/orchestrator.json
```

```json
{
  "threshold_percent": 55,
  "max_restarts": 20,
  "auto_restart": true
}
```

## Nutzung

```bash
# Starte Claude immer so:
~/.claude/auto-session.sh /pfad/zum/projekt

# Mit Extra-Flags:
~/.claude/auto-session.sh /pfad/zum/projekt --model opus --verbose
```

### Was passiert

```
Claude arbeitet... 🟢 30% | ✓2 | projekt
  → Teilaufgabe fertig → CHECKPOINT.md aktualisiert
  → StatusLine: 🟡 48% | ✓5 | projekt
  → Weiter arbeiten...
  → StatusLine: 🟠 56% | ✓7 | projekt
  → stop-check: Kopiert CHECKPOINT.md → HANDOFF.md
  → Claude: "Tippe /exit"
  → Du: /exit
  → Wrapper: "Handoff erkannt, starte neu..."
  → Neue Session laedt Handoff → weiter geht's
  → Aufgabe fertig → /exit → kein Handoff → Wrapper stoppt
```

### Manueller Checkpoint

Jederzeit waehrend der Arbeit:
```
/checkpoint
```

Claude schreibt den aktuellen Stand in `.claude/CHECKPOINT.md`.

## Dateien

```
claude-orchestrator/
├── hooks/
│   ├── statusline.sh           # Context% + Checkpoint-Count + Projekt
│   ├── stop-check.sh           # Auto-Handoff bei Threshold
│   ├── session-start.sh        # Handoff/Checkpoint laden + konsumieren
│   └── pre-compact.sh          # Backup vor Compaction
├── commands/
│   └── checkpoint.md           # /checkpoint Slash-Command
├── templates/
│   └── ORCHESTRATOR-PROTOCOL.md  # Herzstuck → in CLAUDE.md kopieren
├── auto-session.sh             # Wrapper: Auto-Restart-Loop
├── orchestrator.json.example   # Per-Projekt Config (optional)
├── settings.json               # Hook-Konfiguration
├── install.sh                  # Installation
├── uninstall.sh                # Deinstallation
└── README.md                   # Diese Datei
```

## Deinstallation

```bash
cd ~/claude-orchestrator
./uninstall.sh
```

Projekt-Dateien (`.claude/CHECKPOINT.md`, `.claude/HANDOFF.md`) werden NICHT geloescht.
