#!/usr/bin/env python3
# prompt-guard.py — Claude Orchestrator v2
# Fires on every user message BEFORE Claude sees it.
#
# Three responsibilities:
#   1. Queue management (load/inject next task from queue)
#   2. Complexity analysis (heuristic scoring of prompt complexity)
#   3. Orchestrator injection (inject delegation instructions based on complexity)
#
# Complexity classes:
#   S  (score 0-2)  → pass through, no overhead
#   M  (score 3-5)  → inject delegation hints (recommended, not forced)
#   L  (score 6-8)  → inject orchestrator mode (forced delegation)
#   XL (score 9+)   → multi-phase + forced delegation
#
# Multi-task detection:
#   Heuristic first (regex). Only calls API if heuristic score >= 3 AND
#   complexity score >= 4 to avoid unnecessary API calls.

import json
import sys
import os
import re
import urllib.request
import urllib.error
import tempfile
from datetime import datetime
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class Analysis:
    complexity: str  # S, M, L, XL
    is_multi_task: bool
    tasks: list = field(default_factory=list)
    score: int = 0


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    prompt = data.get("prompt", "").strip()
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())

    # 0. Check if context is already high → nudge user to /clear
    if should_nudge_clear(project_dir):
        inject_clear_nudge()
        sys.exit(0)

    # 1. Check for existing task queue — inject next task if present
    queue = load_queue(project_dir)
    if queue:
        inject_queue_context(queue, project_dir)
        sys.exit(0)

    # 2. Short prompts are never complex — skip entirely
    if len(prompt) < 80:
        sys.exit(0)

    # 3. Complexity analysis (heuristic, no API call)
    analysis = analyze_complexity(prompt)

    # 4. Inject orchestrator instructions based on complexity
    if analysis.is_multi_task and len(analysis.tasks) >= 2:
        # Multiple independent tasks → queue + orchestrator
        remaining = analysis.tasks[1:]
        save_queue(project_dir, remaining)
        inject_orchestrator_instructions(analysis.tasks[0], analysis)
    elif analysis.complexity in ("L", "XL"):
        # Single large task → force orchestrator mode
        inject_orchestrator_instructions_single(analysis)
    elif analysis.complexity == "M":
        # Medium task → recommend delegation
        inject_delegation_hints(analysis)
    # S = pass through silently, no overhead

    sys.exit(0)


# ─── Context Check ──────────────────────────────────────────────────

def should_nudge_clear(project_dir):
    """Check if handoff-done flag exists AND handoff file exists.
    This means stop-check already triggered but user hasn't /clear'd yet."""
    state_file = os.path.expanduser("~/.claude/context-state.json")
    handoff_file = os.path.join(project_dir, ".claude", "HANDOFF.md")

    if not os.path.exists(handoff_file):
        return False

    # Check if any handoff-done flag exists for current session
    claude_dir = os.path.expanduser("~/.claude")
    try:
        for f in os.listdir(claude_dir):
            if f.startswith("handoff-done-"):
                return True
    except OSError:
        pass
    return False


def inject_clear_nudge():
    """Tell Claude the context is full and user should /exit."""
    context = """\
\u26a0\ufe0f CONTEXT-LIMIT ERREICHT — Session beenden!

Der Handoff wurde bereits geschrieben (.claude/HANDOFF.md).
Sage dem User: **Tippe /exit — die Session startet automatisch neu.**
(Falls auto-session.sh nicht l\u00e4uft: /clear und manuell weiter.)
Arbeite NICHT weiter — der Context ist zu voll f\u00fcr qualitative Arbeit."""

    output = {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": context,
        }
    }
    print(json.dumps(output))


# ─── Complexity Analysis ────────────────────────────────────────────

def analyze_complexity(prompt):
    """Estimate task complexity using heuristics (no API call)."""
    score = 0

    # File references (.tsx, .py, .ts, .jsx, .css, .json, .md etc.)
    file_refs = len(re.findall(
        r"\b[\w/.-]+\.(?:tsx?|jsx?|py|css|json|md|sh|sql|yaml|yml|toml)\b",
        prompt
    ))
    if file_refs >= 5:
        score += 3
    elif file_refs >= 3:
        score += 2
    elif file_refs >= 1:
        score += 1

    # Feature/creation keywords (new features = complex)
    feature_words = len(re.findall(
        r"\b(?:implementiere|baue|erstelle|build|create|add\s+\w+\s+(?:endpoint|page|component|route|feature)|neue[rs]?\s+\w+)\b",
        prompt, re.IGNORECASE
    ))
    score += min(feature_words * 2, 4)

    # Architecture keywords (system design = complex)
    arch_words = len(re.findall(
        r"\b(?:refactor|migrat|redesign|archite|database|authenticat|authoriz|API|schema|migration|pipeline|infrastruktur)\b",
        prompt, re.IGNORECASE
    ))
    score += min(arch_words * 2, 4)

    # Multi-file change indicators
    multi_file = len(re.findall(
        r"\b(?:frontend\s+(?:und|and)\s+backend|mehrere\s+dateien|multiple\s+files|across\s+\w+\s+files|in\s+allen?\b)\b",
        prompt, re.IGNORECASE
    ))
    score += min(multi_file * 2, 3)

    # Length bonus (long prompts usually = complex tasks)
    if len(prompt) > 500:
        score += 2
    elif len(prompt) > 250:
        score += 1

    # Multi-task heuristic score (from v1, enhanced)
    multi_score = heuristic_multi_task_score(prompt)

    # Determine complexity class
    if score <= 2:
        complexity = "S"
    elif score <= 5:
        complexity = "M"
    elif score <= 8:
        complexity = "L"
    else:
        complexity = "XL"

    # Only call API if both multi-task heuristic AND complexity are high
    is_multi = False
    tasks = []
    if multi_score >= 3 and score >= 4:
        api_result = call_api_analysis(prompt)
        if api_result:
            is_multi = api_result.get("is_multi_task", False)
            tasks = api_result.get("tasks", [])
            # Enrich tasks with status
            for t in tasks:
                t.setdefault("status", "pending")

    return Analysis(
        complexity=complexity,
        is_multi_task=is_multi,
        tasks=tasks,
        score=score,
    )


def heuristic_multi_task_score(prompt):
    """Quick regex check for multi-task patterns. Score >= 3 = suspicious."""
    score = 0

    # Numbered lists: "1. ... 2. ... 3. ..."
    numbered = re.findall(r"(?:^|\n)\s*\d+[\.\)]\s+\S", prompt)
    if len(numbered) >= 3:
        score += 3

    # Bullet points: "- ... \n- ... \n- ..."
    bullets = re.findall(r"(?:^|\n)\s*[-*]\s+\S", prompt)
    if len(bullets) >= 3:
        score += 2

    # Chaining conjunctions
    chaining = len(re.findall(
        r"\b(?:und dann|danach|au[sß]erdem|additionally|then also|and also|after that|next|anschlie[sß]end)\b",
        prompt, re.IGNORECASE,
    ))
    score += min(chaining, 3)

    # Semicolons as task separators
    semicolons = prompt.count(";")
    if semicolons >= 2:
        score += 2

    # Repeated imperative verbs (build, add, fix, create...)
    imperatives = len(re.findall(
        r"\b(?:build|add|fix|create|implement|refactor|baue|erstelle|fixe|f[uü]ge.*hinzu|implementiere|mach|schreibe)\b",
        prompt, re.IGNORECASE,
    ))
    if imperatives >= 3:
        score += 2

    return score


# ─── API Analysis (Haiku, only when needed) ─────────────────────────

def call_api_analysis(prompt):
    """Call Claude Haiku to verify multi-task detection. Returns dict or None."""
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not api_key:
        return None

    system = """You analyze user requests to Claude Code and detect if they contain TOO MANY separate tasks at once.

Only flag as multi-task if there are 3+ truly independent tasks that would each take significant work and hurt quality if rushed together.

Do NOT flag:
- One task with multiple steps
- A single feature that needs multiple files
- Questions + one task
- Simple requests

DO flag:
- "Build feature A, then refactor B, then add tests for C, and also fix bug D"
- Clearly separate deliverables listed together
- Multiple unrelated features in one message

Respond ONLY with valid JSON, no other text:
{
  "is_multi_task": true/false,
  "reason": "one sentence why",
  "tasks": [
    {"title": "Short title", "description": "What to do"},
    ...
  ]
}

If not multi-task, return: {"is_multi_task": false, "reason": "...", "tasks": []}"""

    body = json.dumps({
        "model": "claude-haiku-4-5-20251001",
        "max_tokens": 800,
        "system": system,
        "messages": [
            {"role": "user", "content": f"Analyze this request:\n\n{prompt}"}
        ],
    }).encode()

    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=body,
        headers={
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            result = json.loads(resp.read())
            text = result["content"][0]["text"].strip()
            # Strip markdown code fences if present
            text = text.strip("`").strip()
            if text.startswith("json"):
                text = text[4:].strip()
            return json.loads(text)
    except Exception:
        return None


# ─── Orchestrator Injection ─────────────────────────────────────────

def inject_orchestrator_instructions(first_task, analysis):
    """Inject orchestrator mode for multi-task scenarios."""
    queued_list = ""
    if len(analysis.tasks) > 1:
        remaining = analysis.tasks[1:]
        queued_list = f"\n## Queued ({len(remaining)} weitere Tasks):\n"
        queued_list += "\n".join(f"  - {t['title']}" for t in remaining)

    context = f"""\
\U0001f3af ORCHESTRATOR MODE ACTIVATED \u2014 Complexity: {analysis.complexity}

Du arbeitest jetzt als ARCHITEKT, nicht als Builder.

## Aktuelle Aufgabe: {first_task['title']}
{first_task['description']}

## Arbeitsweise:
1. **ERFORSCHE** zuerst mit Explore-Agents (Task tool, subagent_type=Explore)
   - Spawne 1-3 Explore-Agents parallel um den Codebase zu verstehen
   - Du selbst liest KEINE Dateien \u2014 die Agents machen das

2. **PLANE** dann mit einem Plan-Agent (Task tool, subagent_type=Plan)
   - Der Plan-Agent entwirft die Implementierung
   - Du reviewst den Plan

3. **DELEGIERE** die Implementierung an Builder-Agents
   - F\u00fcr jede unabh\u00e4ngige \u00c4nderung: 1 Agent (Task tool, subagent_type=general-purpose)
   - Agents arbeiten parallel wo m\u00f6glich
   - Nutze isolation="worktree" nur wenn Agents gleiche Dateien \u00e4ndern

4. **REVIEWE** die Ergebnisse
   - Spawne einen Code-Review Agent (Task tool, subagent_type=code-reviewer)

5. **BERICHTE** dem User

## Context-Budget:
- DEIN Context soll unter 55% bleiben
- Jeder Agent hat sein EIGENES Context-Window
- Delegation = Context-Savings
- Wenn du merkst dass dein Context steigt: SOFORT mehr delegieren

## VERBOTEN in Orchestrator-Mode:
- Selbst gro\u00dfe Dateien lesen (> 100 Zeilen) \u2192 Agent machen lassen
- Selbst Code schreiben (> 20 Zeilen) \u2192 Builder-Agent nutzen
- Exploration im Haupt-Context \u2192 Explore-Agents daf\u00fcr nutzen
{queued_list}"""

    output = {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": context,
        }
    }
    print(json.dumps(output))


def inject_orchestrator_instructions_single(analysis):
    """For L/XL single tasks: force delegation workflow."""
    context = f"""\
\U0001f3af ORCHESTRATOR MODE \u2014 Gro\u00dfe Aufgabe erkannt (Complexity: {analysis.complexity}, Score: {analysis.score})

Diese Aufgabe ist zu gro\u00df f\u00fcr direktes Arbeiten im Haupt-Context.

## Pflicht-Workflow:
1. Spawne einen Explore-Agent der den relevanten Code analysiert
2. Spawne einen Plan-Agent der die Implementierung plant
3. Teile die Implementierung in 2-4 unabh\u00e4ngige Teile
4. Spawne f\u00fcr jeden Teil einen Builder-Agent (parallel wo m\u00f6glich)
5. Reviewe die Ergebnisse mit einem Code-Review Agent
6. Berichte dem User

## Context-Budget:
- Dein Haupt-Context ist NUR f\u00fcr Koordination
- NICHT f\u00fcr Implementierung
- Ziel: unter 55% Context-Nutzung bleiben"""

    output = {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": context,
        }
    }
    print(json.dumps(output))


def inject_delegation_hints(analysis):
    """For M tasks: recommend delegation, don't force it."""
    context = f"""\
\U0001f4a1 DELEGATION EMPFOHLEN \u2014 Mittlere Aufgabe erkannt (Score: {analysis.score})

F\u00fcr bessere Context-Effizienz:
- Nutze Explore-Agents f\u00fcr Codebase-Analyse statt selbst zu lesen
- Nutze Builder-Agents f\u00fcr Implementierungen > 50 Zeilen
- Dein Haupt-Context sollte unter 55% bleiben"""

    output = {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": context,
        }
    }
    print(json.dumps(output))


# ─── Queue Management (enhanced from v1) ────────────────────────────

def load_queue(project_dir):
    """Load task queue, return data dict or None if empty/missing."""
    path = os.path.join(project_dir, ".claude", "task-queue.json")
    if not os.path.exists(path):
        return None
    try:
        with open(path) as f:
            data = json.load(f)
        tasks = data.get("tasks", [])
        active = [t for t in tasks if t.get("status", "pending") != "completed"]
        if not active:
            os.remove(path)
            md = os.path.join(project_dir, ".claude", "task-queue.md")
            if os.path.exists(md):
                os.remove(md)
            return None
        data["tasks"] = active
        return data
    except Exception:
        return None


def save_queue(project_dir, tasks):
    """Atomically save task queue to JSON + human-readable MD."""
    queue_dir = os.path.join(project_dir, ".claude")
    os.makedirs(queue_dir, exist_ok=True)

    data = {"created": datetime.now().isoformat(), "tasks": tasks}

    # Atomic write
    json_path = os.path.join(queue_dir, "task-queue.json")
    fd, tmp_path = tempfile.mkstemp(dir=queue_dir, suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, indent=2)
        os.replace(tmp_path, json_path)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise

    # Human-readable version
    md_path = os.path.join(queue_dir, "task-queue.md")
    with open(md_path, "w") as f:
        f.write("# Task Queue\n")
        f.write(f"_Created: {datetime.now().strftime('%Y-%m-%d %H:%M')}_\n\n")
        f.write("## Pending Tasks\n\n")
        for i, t in enumerate(tasks, 1):
            status = t.get("status", "pending")
            icon = "\u23f3" if status == "in_progress" else "\u2b1c"
            f.write(
                f"### {icon} {i}. {t['title']}\n"
                f"Status: {status}\n"
                f"{t['description']}\n\n"
            )


def inject_queue_context(queue, project_dir):
    """Inject next task from queue into Claude's context."""
    tasks = queue.get("tasks", [])
    if not tasks:
        return
    next_task = tasks[0]
    remaining = tasks[1:]

    msg = f"""\
\U0001f4cb TASK QUEUE \u2014 Loading next task

**Current task:** {next_task['title']}
{next_task['description']}

\U0001f4a1 Nutze Sub-Agents (Task tool) f\u00fcr Exploration und Implementierung.
Halte deinen Haupt-Context lean.
"""
    if remaining:
        msg += f"\n**Still queued after this ({len(remaining)} more):**\n"
        msg += "\n".join(f"  \u2022 {t['title']}" for t in remaining)

    # Mark current task as in_progress
    next_task["status"] = "in_progress"
    all_tasks = [next_task] + remaining
    save_queue(project_dir, all_tasks)

    output = {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": msg,
        }
    }
    print(json.dumps(output))


if __name__ == "__main__":
    main()
