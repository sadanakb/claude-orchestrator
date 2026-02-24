#!/usr/bin/env python3
# prompt-guard.py — Claude Orchestrator v2 (Slim)
#
# Two jobs only:
#   1. Multi-task detection → split into queue (one task per session)
#   2. Post-handoff nudge → tell user to /exit if handoff already written
#
# Everything else (complexity scoring, orchestrator injection, delegation
# hints) has been removed. Those belong in CLAUDE.md, not per-message hooks.

import json
import sys
import os
import re
import urllib.request
import tempfile
from datetime import datetime


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    prompt = data.get("prompt", "").strip()
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())

    # 1. If handoff already written → nudge /exit
    if should_nudge_exit(project_dir):
        inject_exit_nudge()
        sys.exit(0)

    # 2. Load existing queue → inject next task
    queue = load_queue(project_dir)
    if queue:
        inject_queue_context(queue, project_dir)
        sys.exit(0)

    # 3. Short prompts → skip (no multi-task possible)
    if len(prompt) < 80:
        sys.exit(0)

    # 4. Multi-task detection (heuristic first, API only if suspicious)
    multi_score = heuristic_multi_task_score(prompt)
    if multi_score < 3:
        sys.exit(0)

    # Heuristic triggered → verify with API
    result = call_api_analysis(prompt)
    if not result or not result.get("is_multi_task", False):
        sys.exit(0)

    tasks = result.get("tasks", [])
    if len(tasks) < 2:
        sys.exit(0)

    # Save tasks 2..N to queue, inject task 1
    for t in tasks:
        t.setdefault("status", "pending")

    remaining = tasks[1:]
    save_queue(project_dir, remaining)

    first = tasks[0]
    context = f"""\
\u26a0\ufe0f TASK QUEUE ACTIVATED

{len(tasks)} separate Tasks erkannt. Qualitaet geht vor Quantitaet — eins nach dem anderen.

**Jetzt:** {first['title']}
{first['description']}

**Queued ({len(remaining)} weitere):**
""" + "\n".join(f"  {i+1}. {t['title']}" for i, t in enumerate(remaining)) + """

Queue gespeichert in .claude/task-queue.json.
Nach dieser Aufgabe: /exit → naechste Task laedt automatisch.
"""

    output = {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": context,
        }
    }
    print(json.dumps(output))
    sys.exit(0)


# ─── Post-Handoff Nudge ────────────────────────────────────────────

def should_nudge_exit(project_dir):
    """Check if handoff-done flag exists → stop-check already triggered."""
    claude_dir = os.path.expanduser("~/.claude")
    try:
        for f in os.listdir(claude_dir):
            if f.startswith("handoff-done-"):
                return True
    except OSError:
        pass
    return False


def inject_exit_nudge():
    """Context is full, tell Claude to wrap up."""
    context = """\
\u26a0\ufe0f CONTEXT-LIMIT ERREICHT

Der Handoff wurde bereits geschrieben.
Sage dem User: **Tippe /exit — die Session startet automatisch neu.**
Arbeite NICHT weiter."""

    output = {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": context,
        }
    }
    print(json.dumps(output))


# ─── Multi-Task Heuristic ──────────────────────────────────────────

def heuristic_multi_task_score(prompt):
    """Quick regex check for multi-task patterns. Score >= 3 = suspicious."""
    score = 0

    # Numbered lists: "1. ... 2. ... 3. ..."
    numbered = re.findall(r"(?:^|\n)\s*\d+[\.\)]\s+\S", prompt)
    if len(numbered) >= 3:
        score += 3

    # Bullet points
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
    if prompt.count(";") >= 2:
        score += 2

    # Repeated imperative verbs
    imperatives = len(re.findall(
        r"\b(?:build|add|fix|create|implement|refactor|baue|erstelle|fixe|f[uü]ge.*hinzu|implementiere|mach|schreibe)\b",
        prompt, re.IGNORECASE,
    ))
    if imperatives >= 3:
        score += 2

    return score


# ─── API Analysis ──────────────────────────────────────────────────

def call_api_analysis(prompt):
    """Call Claude Haiku to verify multi-task detection."""
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not api_key:
        return None

    system = """You analyze user requests to Claude Code and detect if they contain TOO MANY separate tasks at once.

Only flag as multi-task if there are 3+ truly independent tasks that would each take significant work.

Do NOT flag:
- One task with multiple steps
- A single feature that needs multiple files
- Questions + one task

DO flag:
- "Build feature A, then refactor B, then add tests for C, and also fix bug D"
- Multiple unrelated features in one message

Respond ONLY with valid JSON:
{
  "is_multi_task": true/false,
  "reason": "one sentence",
  "tasks": [{"title": "Short title", "description": "What to do"}, ...]
}"""

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
            text = text.strip("`").strip()
            if text.startswith("json"):
                text = text[4:].strip()
            return json.loads(text)
    except Exception:
        return None


# ─── Queue Management ──────────────────────────────────────────────

def load_queue(project_dir):
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
    queue_dir = os.path.join(project_dir, ".claude")
    os.makedirs(queue_dir, exist_ok=True)

    data = {"created": datetime.now().isoformat(), "tasks": tasks}

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

    md_path = os.path.join(queue_dir, "task-queue.md")
    with open(md_path, "w") as f:
        f.write("# Task Queue\n")
        f.write(f"_Created: {datetime.now().strftime('%Y-%m-%d %H:%M')}_\n\n")
        for i, t in enumerate(tasks, 1):
            status = t.get("status", "pending")
            icon = "\u23f3" if status == "in_progress" else "\u2b1c"
            f.write(f"### {icon} {i}. {t['title']}\n{t['description']}\n\n")


def inject_queue_context(queue, project_dir):
    tasks = queue.get("tasks", [])
    if not tasks:
        return
    next_task = tasks[0]
    remaining = tasks[1:]

    msg = f"""\
\U0001f4cb TASK QUEUE — Naechste Aufgabe

**Jetzt:** {next_task['title']}
{next_task['description']}
"""
    if remaining:
        msg += f"\n**Danach ({len(remaining)} weitere):**\n"
        msg += "\n".join(f"  \u2022 {t['title']}" for t in remaining)

    next_task["status"] = "in_progress"
    save_queue(project_dir, [next_task] + remaining)

    output = {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": msg,
        }
    }
    print(json.dumps(output))


if __name__ == "__main__":
    main()
