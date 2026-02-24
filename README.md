# Claude Orchestrator v3

![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue)
![Claude Code](https://img.shields.io/badge/Claude_Code-Compatible-blueviolet)

**Automatic context management for Claude Code.** Checkpoints after every subtask, auto-handoff when context fills up, seamless session restarts — zero API calls.

---

## The Problem

Claude Code's context window fills up mid-task. You lose progress. Manual handoffs are tedious. Copy-pasting summaries between sessions is error-prone.

## The Solution

Claude Orchestrator turns Claude Code into a **self-managing agent** that:
- Writes checkpoints after every completed subtask
- Auto-hands off when context reaches 55%+
- Restarts itself and picks up exactly where it left off
- Shows a live StatusLine so you always know where things stand

I built this because I kept losing progress during long coding sessions with Claude Code. Instead of manually writing summaries, the orchestrator does it automatically — so every session picks up exactly where the last one left off.

---

## Features

| Feature | Description |
|---------|-------------|
| **Checkpoint System** | After every subtask, Claude writes `.claude/CHECKPOINT.md` with current progress |
| **Auto-Handoff** | At 55%+ context, CHECKPOINT.md becomes HANDOFF.md and the session ends gracefully |
| **Auto-Restart** | `auto-session.sh` detects handoffs and restarts Claude automatically |
| **StatusLine** | Live display: Context% + Checkpoint count + Project name |
| **Zero API Calls** | Pure shell scripts — no ANTHROPIC_API_KEY needed, zero latency |
| **CLAUDE.md Protocol** | Delegation rules, context traffic light, and workflow guidance |

---

## Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│  auto-session.sh │────▶│  Claude Code  │────▶│  CHECKPOINT.md  │
│  (restart loop)  │◀────│  (working)   │     │  (after tasks)  │
└─────────────────┘     └──────────────┘     └─────────────────┘
        ▲                      │                      │
        │                      ▼                      ▼
        │               ┌──────────────┐     ┌─────────────────┐
        └───────────────│  stop-check  │     │   HANDOFF.md    │
                        │  (55%+ exit) │────▶│  (for restart)  │
                        └──────────────┘     └─────────────────┘
```

---

## Installation

```bash
git clone https://github.com/sadanakb/claude-orchestrator.git ~/claude-orchestrator
cd ~/claude-orchestrator
chmod +x install.sh
./install.sh
```

Then copy the orchestrator protocol into your project's CLAUDE.md:

```bash
cat ~/.claude/templates/ORCHESTRATOR-PROTOCOL.md >> /your-project/CLAUDE.md
```

### Optional: Per-Project Config

```bash
cp ~/claude-orchestrator/orchestrator.json.example /your-project/.claude/orchestrator.json
```

```json
{
  "threshold_percent": 55,
  "max_restarts": 20,
  "auto_restart": true
}
```

---

## Usage

```bash
# Always start Claude like this:
~/.claude/auto-session.sh /path/to/project

# With extra flags:
~/.claude/auto-session.sh /path/to/project --model opus --verbose
```

### What Happens

```
Claude working...  🟢 30% | ✓2 | my-project
  → Subtask done → CHECKPOINT.md updated
  → StatusLine:   🟡 48% | ✓5 | my-project
  → Keep working...
  → StatusLine:   🟠 56% | ✓7 | my-project
  → stop-check: Copies CHECKPOINT.md → HANDOFF.md
  → Claude: "Type /exit"
  → You: /exit
  → Wrapper: "Handoff detected, restarting..."
  → New session loads handoff → continues
  → Task complete → /exit → no handoff → wrapper stops
```

### Manual Checkpoint

Any time during work:
```
/checkpoint
```

---

## v2 vs v3

| v2 | v3 |
|----|-----|
| One-time handoff at 55% | Checkpoint after every subtask |
| 5 hooks (incl. API call) | 4 hooks (pure shell, zero latency) |
| Task queue in JSON (buggy) | Checkpoint in Markdown (simple, readable) |
| Hook injection for delegation | CLAUDE.md protocol (more reliable) |
| Empty handoff template on crash | CHECKPOINT.md as handoff basis |

---

## File Structure

```
claude-orchestrator/
├── hooks/
│   ├── statusline.sh             # Context% + Checkpoint count + Project
│   ├── stop-check.sh             # Auto-handoff at threshold
│   ├── session-start.sh          # Load handoff/checkpoint + consume
│   └── pre-compact.sh            # Backup before compaction
├── commands/
│   └── checkpoint.md             # /checkpoint slash command
├── templates/
│   └── ORCHESTRATOR-PROTOCOL.md  # Core protocol → copy into CLAUDE.md
├── auto-session.sh               # Wrapper: auto-restart loop
├── orchestrator.json.example     # Per-project config (optional)
├── settings.json                 # Hook configuration
├── install.sh                    # Installation
├── uninstall.sh                  # Uninstallation
└── README.md
```

---

## Uninstall

```bash
cd ~/claude-orchestrator
./uninstall.sh
```

Project files (`.claude/CHECKPOINT.md`, `.claude/HANDOFF.md`) are **not** deleted.

---

## Author

**Sadan Akbari** — Business Informatics student at Frankfurt University of Applied Sciences

[Portfolio](https://sadanakb.github.io) · [LinkedIn](https://www.linkedin.com/in/sadan-akbari) · [GitHub](https://github.com/sadanakb)

---

## License

MIT — see [LICENSE](LICENSE).

---

Built by a developer who ships with Claude Code.
