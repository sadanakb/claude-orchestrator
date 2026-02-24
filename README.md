# Claude Orchestrator v2

Ein Meta-System das Claude Code von einem Solo-Entwickler in einen Lead-Architekten verwandelt. Statt alles selbst zu machen, delegiert Claude an Sub-Agents, haelt seinen Context lean, und arbeitet wie eine Software-Entwicklungsfirma.

## Was ist anders als v1 (claude-session-handoff)?

| Aspekt | v1 | v2 |
|--------|----|----|
| Aufgaben-Modus | Sequenziell | Parallel (Sub-Agents) |
| Claude's Rolle | Builder (macht alles) | Architekt (delegiert) |
| Context-Management | Passiv (60% Threshold) | Aktiv (proaktive Delegation) |
| Exploration | Im Haupt-Context | Via Explore-Agents |
| Implementierung | Im Haupt-Context | Via Builder-Agents |
| Code-Review | Keins | Via Review-Agents |
| Task-Splitting | Nur Multi-Task | + Komplexitaets-Analyse |
| Threshold | Statisch 60% | Dynamisch 50-60% |

## Installation

```bash
git clone <repo-url> ~/claude-orchestrator
cd ~/claude-orchestrator
chmod +x install.sh
./install.sh
```

## Wie es funktioniert

### 1. Prompt Guard (prompt-guard.py)

Analysiert JEDE User-Nachricht bevor Claude sie sieht:

- **Kurze Prompts** (< 80 Zeichen): Durchlassen, kein Overhead
- **Mittlere Aufgaben** (Score 3-5): Delegation empfohlen
- **Grosse Aufgaben** (Score 6-8): Orchestrator-Modus erzwungen
- **XL Aufgaben** (Score 9+): Multi-Phase + erzwungene Delegation
- **Multi-Task** (3+ unabhaengige Tasks): Queue + sequentielle Abarbeitung

### 2. Orchestrator Skill (orchestrator.md)

Definiert Claude's Verhalten im Orchestrator-Modus:

```
Explore (Agents) -> Plan (Agent) -> Build (Agents) -> Review (Agent) -> Report
```

- Explore-Agents untersuchen den Codebase
- Plan-Agent entwirft die Implementierung
- Builder-Agents implementieren parallel
- Review-Agent prueft auf Bugs/Security
- Claude koordiniert und berichtet

### 3. Dynamic Context Management

- **StatusLine**: Zeigt Context%, Task-Progress, Projekt
- **Stop-Check**: Dynamischer Threshold basierend auf Queue-Groesse
- **Pre-Compact**: Sichert State vor Compaction
- **Session-Start**: Laedt Handoff + Queue automatisch

## Dateistruktur

```
claude-orchestrator/
├── hooks/
│   ├── prompt-guard.py      # Komplexitaets-Analyse + Orchestrierung
│   ├── statusline.sh        # Context% + Task-Progress
│   ├── session-start.sh     # Handoff + Queue laden
│   ├── stop-check.sh        # Dynamischer Threshold
│   └── pre-compact.sh       # State Backup
├── skills/
│   └── orchestrator.md      # Orchestrator-Verhalten
├── commands/
│   └── handoff.md           # /handoff Slash-Command
├── settings.json            # Hook-Konfiguration
├── install.sh               # Installation
└── uninstall.sh             # Deinstallation
```

## Komplexitaets-Scoring

Der Prompt Guard bewertet jede Nachricht nach:

- **Datei-Referenzen** (.tsx, .py, etc.): 1-3 Punkte
- **Feature-Keywords** (implementiere, baue, erstelle): bis 4 Punkte
- **Architektur-Keywords** (refactor, migrate, database): bis 4 Punkte
- **Multi-File-Indikatoren**: bis 3 Punkte
- **Laenge** (> 250 Zeichen): 1-2 Punkte

Klassen: S (0-2), M (3-5), L (6-8), XL (9+)

## Deinstallation

```bash
cd ~/claude-orchestrator
./uninstall.sh
```

## Voraussetzungen

- Claude Code CLI
- Python 3.6+
- ANTHROPIC_API_KEY (nur fuer Multi-Task-Erkennung via API, optional)
