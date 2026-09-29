"""Post into a Claude Code session's inbox socket: the one place the wire format lives.

Wire format (claude 2.1.283 `--debug` "[uds-messaging] Inject messages" log line;
undocumented, pinned by gate f): newline-delimited JSON over a Unix stream socket,
an optional `{"type":"auth","token":...}` line (omitted here: it is optional on
Linux and would claim own-child status), then one line per message:

    {"type":"user","message":{"role":"user","content":"<text>"}}

The converser's socket path is recorded by launcher/record-sockpath.sh at
`<run>/converser.sockpath`, where `<run>` is `${XDG_RUNTIME_DIR:-/tmp}/converser-<uid>`.

CLI (gate f's test script):  python3 inbox.py [--socket PATH] [TEXT]   (TEXT or stdin)
"""

from __future__ import annotations

import argparse
import json
import os
import socket
import sys

CONNECT_TIMEOUT = 2.0


def run_dir() -> str:
    """The run dir shared by the launcher, the sockpath recorder, and the Stop hook."""
    return os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", f"converser-{os.getuid()}")


def converser_socket(run: str | None = None) -> str | None:
    """The converser's recorded inbox socket path, or None if none is recorded."""
    path = os.path.join(run or run_dir(), "converser.sockpath")
    try:
        with open(path, encoding="utf-8") as f:
            sock = f.read().strip()
    except OSError:
        return None
    return sock or None


def encode(text: str) -> bytes:
    msg = {"type": "user", "message": {"role": "user", "content": text}}
    return (json.dumps(msg, ensure_ascii=False) + "\n").encode("utf-8")


def is_live(sock_path: str) -> bool:
    """Liveness by connecting: a sockpath left by a crash points at a dead socket."""
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(CONNECT_TIMEOUT)
            s.connect(sock_path)
        return True
    except OSError:
        return False


def post(sock_path: str, text: str) -> None:
    """Send one message; raises OSError if the socket is unreachable."""
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.settimeout(CONNECT_TIMEOUT)
        s.connect(sock_path)
        s.sendall(encode(text))
        s.shutdown(socket.SHUT_WR)


def main() -> int:
    p = argparse.ArgumentParser(description="Post one message into a session inbox socket.")
    p.add_argument("--socket", help="socket path (default: the recorded converser socket)")
    p.add_argument("text", nargs="?", help="message text (default: stdin)")
    a = p.parse_args()
    sock = a.socket or converser_socket()
    if not sock:
        print(f"inbox: no socket given and none recorded in {run_dir()}", file=sys.stderr)
        return 1
    text = a.text if a.text is not None else sys.stdin.read().rstrip("\n")
    if not text.strip():
        print("inbox: empty message", file=sys.stderr)
        return 1
    try:
        post(sock, text)
    except OSError as e:
        print(f"inbox: cannot post to {sock}: {e}", file=sys.stderr)
        return 1
    print(f"inbox: posted {len(text)} characters to {sock}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
