"""Overseer `Stop` hook: post the turn's final text to the converser, and trace it.

Runs `async: true` from the container's managed settings file for every overseer
session, never for the converser itself (CONVERSER_SESSION=1) and never posting
from a headless `claude -p` worker. Always exits 0: it must never block a Stop.

    python3 stop-post.py [--trace-only]      (hook input JSON on stdin)

Each event appends one JSON line to `<run>/stop-trace.jsonl`, including the
parent `claude` argv (Open Question 3: is argv a reliable headless signal?).
--trace-only records would-be posts without posting (gate j).
"""

from __future__ import annotations

import argparse
import datetime
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import inbox  # noqa: E402  (sibling module; the one place the wire format lives)

MAX_CHARS = 600
TRUNC_MARK = " [truncated]"


def claude_argv() -> list[str] | None:
    """argv of the nearest ancestor that looks like the claude CLI, if any."""
    pid = os.getppid()
    for _ in range(8):
        if pid <= 1:
            return None
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                argv = [a.decode("utf-8", "replace") for a in f.read().split(b"\0") if a]
            with open(f"/proc/{pid}/stat", encoding="utf-8") as f:
                ppid = int(f.read().rsplit(")", 1)[1].split()[1])
        except (OSError, ValueError, IndexError):
            return None
        if any(os.path.basename(a) == "claude" or a.endswith("/claude") or "claude-code" in a
               for a in argv[:2]):
            return argv
        pid = ppid
    return None


def is_headless(argv: list[str] | None) -> bool:
    return bool(argv) and any(a in ("-p", "--print") for a in argv)


def session_label(session_id: str, cwd: str) -> str:
    """Session name from the (undocumented) sessions registry; cwd basename fallback."""
    config = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
    for path in glob.glob(os.path.join(config, "sessions", "*.json")):
        try:
            with open(path, encoding="utf-8") as f:
                entry = json.load(f)
        except (OSError, ValueError):
            continue
        if isinstance(entry, dict) and entry.get("sessionId") == session_id and entry.get("name"):
            return str(entry["name"])
    return f"{os.path.basename(cwd.rstrip('/')) or cwd or 'unknown'} (unnamed)"


def truncate(text: str) -> str:
    text = text.strip()
    if len(text) <= MAX_CHARS:
        return text
    return text[: MAX_CHARS - len(TRUNC_MARK)].rstrip() + TRUNC_MARK


def ensure_run_dir(run: str) -> bool:
    """Create the run dir 0700 if absent; refuse one that is a symlink or not ours."""
    try:
        os.mkdir(run, 0o700)
    except FileExistsError:
        pass
    except OSError:
        return False
    st = os.lstat(run)
    return not os.path.islink(run) and st.st_uid == os.getuid()


def trace(run: str, record: dict) -> None:
    fd = os.open(os.path.join(run, "stop-trace.jsonl"),
                 os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
    with os.fdopen(fd, "a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")


def handle(hook: dict, trace_only: bool) -> dict:
    """Decide and act; returns the trace record."""
    session_id = str(hook.get("session_id") or "")
    cwd = str(hook.get("cwd") or os.getcwd())
    argv = claude_argv()
    message = hook.get("last_assistant_message") or ""
    background = hook.get("background_tasks") or []
    rec = {
        "ts": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
        "session_id": session_id,
        "cwd": cwd,
        "argv": argv,
        "msg_chars": len(message) if isinstance(message, str) else None,
        "background_tasks": len(background) if isinstance(background, list) else background,
        "stop_hook_active": hook.get("stop_hook_active"),
    }
    if os.environ.get("CONVERSER_SESSION") == "1":
        rec["action"] = "skip:converser"
        return rec
    if is_headless(argv):
        rec["action"] = "skip:headless"
        return rec
    if background:
        rec["action"] = "skip:background_tasks"
        return rec
    if not isinstance(message, str) or not message.strip():
        rec["action"] = "skip:empty"
        return rec
    label = session_label(session_id, cwd)
    rec["label"] = label
    text = f"From: {label}\nKind: stop (turn-end status, not user speech)\n\n{truncate(message)}"
    sock = inbox.converser_socket()
    rec["socket"] = sock
    if trace_only:
        rec["action"] = "trace-only"
        return rec
    if not sock:
        rec["action"] = "skip:no-converser"
        return rec
    # Liveness by construction: a dead converser's socket refuses or is gone.
    try:
        inbox.post(sock, text)
        rec["action"] = "posted"
    except (FileNotFoundError, ConnectionRefusedError):
        rec["action"] = "skip:no-live-converser"
    except OSError as e:
        rec["action"] = "error"
        rec["error"] = str(e)
    return rec


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--trace-only", action="store_true")
    a = p.parse_args()
    run = inbox.run_dir()
    try:
        hook = json.load(sys.stdin)
        if not isinstance(hook, dict):
            raise ValueError("hook input is not a JSON object")
        rec = handle(hook, a.trace_only)
    except Exception as e:  # noqa: BLE001 - never fail the Stop
        rec = {"ts": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
               "action": "error", "error": f"{type(e).__name__}: {e}"}
    try:
        if ensure_run_dir(run):
            trace(run, rec)
    except OSError:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
