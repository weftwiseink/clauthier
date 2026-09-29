"""Host MCP test client for a converser `serve` instance (Test Plan item 1).

Run with the VoiceMode tool venv's interpreter, which has the `mcp` package,
from the installed copy (never the container-writable checkout). The bearer
token is read from stdin, so it never appears on a command line:

    ~/.local/share/uv/tools/voice-mode/bin/python \
      ~/.local/share/converser-host/src/mcp-converse.py --port 8765 --listen 30 \
      < ~/.config/converser-host/instances/clauthier.token

Without --list-tools this makes ONE `converse` call, which speaks through the
host speakers and opens the host microphone: run it only with the user present.
`wait_for_conch` stays false, so a call while another process holds the conch
returns "conch held" at once.
"""

import argparse
import asyncio
import sys
import time

import httpx
from mcp import ClientSession
from mcp.client.streamable_http import streamable_http_client


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--port", type=int, default=8765)
    p.add_argument("--listen", type=float, default=30.0,
                   help="listen_duration_max in seconds (max 120)")
    p.add_argument("--message", default="Converser test. Please say a short sentence.",
                   help="text spoken before listening")
    p.add_argument("--skip-tts", action="store_true", help="do not speak the message")
    p.add_argument("--no-listen", action="store_true",
                   help="speak only (wait_for_response=false)")
    p.add_argument("--list-tools", action="store_true",
                   help="print the tool names and exit; touches no audio")
    a = p.parse_args()
    if not 0 < a.listen <= 120:
        p.error("--listen must be in (0, 120]")
    return a


def read_token() -> str:
    if sys.stdin.isatty():
        sys.exit("mcp-converse: pipe the token on stdin (< <project>.token)")
    tok = sys.stdin.read().strip()
    if len(tok) < 32:
        sys.exit("mcp-converse: token on stdin is empty or shorter than 32 characters")
    return tok


async def run(a: argparse.Namespace, token: str) -> int:
    url = f"http://127.0.0.1:{a.port}/mcp"
    # Read timeout well above the longest bounded converse() (conch wait,
    # playback, listen, STT): the same reasoning as the converser's 600 s.
    timeout = httpx.Timeout(600.0, connect=10.0)
    async with httpx.AsyncClient(headers={"Authorization": f"Bearer {token}"},
                                 timeout=timeout) as http:
        async with streamable_http_client(url, http_client=http) as (read, write, _):
            async with ClientSession(read, write) as session:
                await session.initialize()
                if a.list_tools:
                    tools = await session.list_tools()
                    print(" ".join(sorted(t.name for t in tools.tools)))
                    return 0
                args = {
                    "message": a.message,
                    "wait_for_response": not a.no_listen,
                    "listen_duration_max": a.listen,
                    "skip_tts": a.skip_tts,
                    "wait_for_conch": False,
                }
                t0 = time.monotonic()
                result = await session.call_tool("converse", args)
                dt = time.monotonic() - t0
                for block in result.content:
                    print(getattr(block, "text", block))
                print(f"[mcp-converse] port {a.port}: {dt:.1f}s, isError={result.isError}",
                      file=sys.stderr)
                return 1 if result.isError else 0


def main() -> int:
    a = parse_args()
    token = read_token()
    try:
        return asyncio.run(run(a, token))
    except Exception as e:  # noqa: BLE001 - report transport failures plainly
        # anyio task groups wrap the real cause (e.g. a 401) in ExceptionGroups.
        while isinstance(e, BaseExceptionGroup) and e.exceptions:
            e = e.exceptions[0]
        print(f"mcp-converse: {type(e).__name__}: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
