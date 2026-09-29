---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-29T18:50:00-07:00
task_list: voice/converser-lace-feature
type: devlog
state: live
status: wip
tags: [voice, converser, implementation, podman, systemd]
---

# converser stage 1 implementation

> BLUF: Implementer log for stage 1 of [`2026-09-29-converser-host-voicemode-serve.md`](../proposals/2026-09-29-converser-host-voicemode-serve.md).
> This turn covers 1.0 only: author `plugins/converser/` (host package, launcher, prompt, hooks) and pass the static checks, with no host changes.

## Objective

Implement proposal stage 1.0 ("Author the files (no host changes)").
Overseer: [`2026-09-29-converser-hybrid-full-send.md`](2026-09-29-converser-hybrid-full-send.md).
Later turns (1.1-1.6) follow user asks A-C.

## Plan

1. `plugins/converser/host/`: Quadlet files, `serve@` unit, `uv-excludes.txt`, `converser-host` CLI, `mcp-converse.py`, `README.md`.
2. `plugins/converser/bin/converser`, `launcher/record-sockpath.sh`, `launcher/SYSTEM_PROMPT.md`.
3. `plugins/converser/hooks/inbox.py`, `hooks/stop-post.py`.
4. Static checks: `sh -n`, `shellcheck`, quadlet `--dryrun`, `systemd-analyze --user verify`, plus `python3 -m py_compile`.

## Testing Approach

1.0 is authoring with no host changes, so the proposal's floor is static.
Beyond it, where it can run without touching host state, behavior is exercised in scratch dirs (temp `HOME`, temp run dirs, a fake Unix socket for the hooks).

## Implementation Notes

**1.0 status: complete.** All files authored and committed; static floor passes; behavior exercised in scratch dirs.
Next: the overseer sends asks A-C; 1.1 starts after them.

Design choices within the spec:

- `install` re-executes itself from the installed copy (`--from-installed`, internal, honored only from `~/.local/share/converser-host/src/`), so every install step after the self-install also runs reviewed, committed code, not the checkout.
- Token handling: tokens move only through `0600` files, `export` (builtin), and `printf` (builtin) into `curl -K -`. `mcp_post` passes the token as a shell-function argument, which is shell-internal.
- `render_units` is split from `write_units` so the `--cpu` rewrite (CPU digests, no `AddDevice=`, `base.en`) is testable with the Quadlet generator dry run.
- Re-running `install` restarts a Quadlet unit whose file changed and `try-restart`s `converser-serve@*` when the template changed.
- `stop-post.py` posts directly and treats a refused or missing socket as "no live converser" (one connection instead of a probe plus a post, so the converser's inbox never sees empty connections). `inbox.is_live()` stays for stage 2's `PreToolUse` hook.
- `stop-post.py` creates the run dir (`0700`, owner-checked) if absent, so trace-only counting works before any converser has run.

> NOTE(opus/voice/converser-lace-feature): Deviations from the proposal text, each small:
> 1. Launcher and recorder: `[ -O "$run" ]` became `[ ! -L "$run" ] && [ "$(stat -c %u "$run")" = "$(id -u)" ]`. `test -O` is undefined in POSIX sh (shellcheck SC3067; the container `sh` may be dash), and the symlink refusal matters for the shared `/tmp` fallback. The launcher also `chmod 700`s a pre-existing run dir, since `mkdir -m` applies only on creation. `CDPATH= cd` became `CDPATH='' cd` (SC1007).
> 2. `converser-host` unsets `FORCE_COLOR`/`CLICOLOR_FORCE`, sets `NO_COLOR=1`, and passes `--color never` to parsed `uv` calls. This host exports `FORCE_COLOR=3`, and `uv tool dir --bin` returned ANSI-wrapped paths, which failed the bin-dir check in the first scratch run.
> 3. `--exclude-newer` is pinned to `2026-09-29T00:00:00Z` (start of the verification day; `voice-mode` 8.12.0 was uploaded 2026-07-21). The scratch install resolved and installed with it (89 packages, `fastmcp==3.4.7`, `mcp==1.30.0`, no `simpleaudio`).
> 4. Stop posts carry a second header line, `Kind: stop (turn-end status, not user speech)`, after `From: <label>`; `SYSTEM_PROMPT.md` refers to it. It makes the structural relay rule easier for the converser to apply.
> 5. `stop-post.py` skips posting when the nearest `claude` ancestor's argv contains `-p`/`--print` (the proposal's "never for headless `claude -p` workers"), while still tracing the argv for Open Question 3. The ancestor walk found this session's own `claude.exe` argv in the scratch test.
> 6. The security floor adds `conch_hold_timeout` and `ref_text` to the forbidden `converse` arguments (from the threat table's `hold_conch` and `ref_text` rows).
> 7. `mcp-converse.py` adds `--list-tools` (no audio), `--message`, `--skip-tts`, and `--no-listen`, and caps `--listen` at 120.
> 8. `status` with no arguments checks every instance; the gate-u backend line is reported as `info`/`WARN`, not `FAIL` (the proposal calls those log lines illustrative).
> 9. `install` refuses to `mask` over a regular upstream unit file (the proposal says none exists; this makes that assumption checked).
> 10. `CONVERSER_HOST_SOURCED=1` lets a test harness source the CLI's functions without running `main`.

> WARN(opus/voice/converser-lace-feature): Two facts found by testing that affect later steps:
> - `voicemode --version` (install step 3) runs with the real `HOME` and creates `~/.voicemode/` with a default `voicemode.env` (`VOICEMODE_VOICES=af_sky` plus pronunciation rules). The `serve@` instances create it anyway (the conch lives there), and command-line pins win, but it is a new host file the user should expect.
> - VoiceMode's `BASE_DIR.mkdir` is not recursive: a `serve` whose `VOICEMODE_BASE_DIR` parent does not exist dies at import. `serve@` is fine (`StateDirectory=` creates it) and `install`'s stop-check uses a one-level `$tmp/base`, but Test Plan item 1's 8800 throwaway at 1.5 must `mkdir -p` the parent.

## Changes Made

| file | commit | description |
|---|---|---|
| `plugins/converser/host/converser-whisper.container` | debcbf0 | STT Quadlet, GPU digest, loopback publish |
| `plugins/converser/host/converser-kokoro.container` | debcbf0 | TTS Quadlet, `DOWNLOAD_MODEL=false` |
| `plugins/converser/host/converser-serve@.service` | 58516f7 | per-project `serve`, pins on `ExecStart`, token-length `ExecStartPre` |
| `plugins/converser/host/converser-host`, `uv-excludes.txt` | c624a98, 03c36de, 261ef0e | `install`, `instance add`, `status` |
| `plugins/converser/host/mcp-converse.py` | 1b0bff8 | host MCP test client, token on stdin |
| `plugins/converser/launcher/SYSTEM_PROMPT.md` | 92eaf16 | security floor, then interaction model |
| `plugins/converser/launcher/record-sockpath.sh` | 988609b | `SessionStart` sockpath recorder |
| `plugins/converser/bin/converser` | a0be6cb | launcher |
| `plugins/converser/hooks/inbox.py` | 511ecbb | wire format, run dir, post, liveness, CLI |
| `plugins/converser/hooks/stop-post.py` | 4dd6563 | `Stop` hook with trace |
| `plugins/converser/host/README.md` | c759bc2 | container contract, run dir, review-before-install |

No `.claude-plugin/plugin.json`, no `marketplace.json` entry, nothing under `bin/` but the launcher.

## Verification

### Static floor (proposal Verification Methodology, 1.0)

```
sh -n plugins/converser/host/converser-host plugins/converser/bin/converser   -> exit 0 (and launcher/record-sockpath.sh)
shellcheck 0.11.0 (host, linuxbrew) on converser-host, bin/converser, launcher/*.sh   -> exit 0, no findings
QUADLET_UNIT_DIRS=$PWD/plugins/converser/host .../podman-user-generator --dryrun   -> exit 0, generated converser-kokoro.service and converser-whisper.service
systemd-analyze --user verify plugins/converser/host/converser-serve@.service   -> exit 0, no output (also clean for an instance symlink converser-serve@clauthier.service)
python3 -m py_compile hooks/inbox.py hooks/stop-post.py host/mcp-converse.py   -> exit 0
```

The GPU dry run passes whisper's `Exec=` as one `bash -c` argument (`"whisper-server\x20--host\x200.0.0.0..."`) and publishes `127.0.0.1:2022`/`127.0.0.1:8880`; the `--cpu` render drops `--device`, uses the CPU digests, and loads `ggml-base.en.bin`.
All four images carry `curl` for their `HealthCmd` (read-only `skopeo inspect --config` history).

### Behavior in scratch dirs (no host state touched)

- **`install` pieces**, scratch `HOME` with XDG vars unset: a dirty tree is refused; `self_install` from clean `c624a98` archives to `src/`, links the CLI, records the rev; the installed copy refuses `install`; `--from-installed` from the checkout is refused.
- **`install_voicemode` + `scoping_stopcheck`**, real `uv` install into the scratch `HOME`: `VoiceMode, version 8.12.0`; `ok :8800 unauthenticated POST /mcp answered 401`; `ok :8800 tools/list is exactly 'converse pause_conversation'`; throwaway killed and removed.
  Negative controls: a `serve` without `VOICEMODE_TOOLS_ENABLED` gives `FAIL ... tools/list is 'converse pause_conversation service'`; a wrong token gives `FAIL ... tools/list is ''`; the token appears 0 times in `serve`'s argv.
- **`instance add`** with `systemctl`/`podman` stubs: picks 8766 while 8765 is held; `0600` env and token, `0700` dirs; secret content equals the token file; repair rewrites a deleted `.token` and skips the existing secret; `--port` on an existing project and a bad name are refused; the token appears 0 times across all stub argv; the printed `runArgs` match the proposal.
- **`status demo clauthier`** against a real `serve` started with every `serve@` pin: `active`, `:8766 listens on 127.0.0.1 only`, 401, exact tools, `environment holds the pins`, `no voicemode process has --token on argv`. Stubbed negatives caught: an `enabled` upstream unit, a `CreateCommand` with the wrong forward, a missing `--secret`. The `serve` banner shows only `Bearer token: 8d85...`.
- **`mcp-converse.py --list-tools`** against a throwaway `serve`: `converse pause_conversation`; a wrong token reports `HTTPStatusError: Client error '401 Unauthorized'`; empty stdin is refused. The `converse` call path was not run: it opens the host mic and speakers (1.5, with the user).
- **Launcher** with a fake `claude`, a 401 stub, and a temp `XDG_RUNTIME_DIR`: missing token and `answered '000', expected 401` refusals; the argv matches the proposal; `CONVERSER_SESSION=1`, `ENABLE_TOOL_SEARCH=false`; run dir `700`, `mcp.json` `600`; the token is in `mcp.json` once and in `claude`'s argv 0 times; `timeout` 600000; the `SessionStart` hook wrote `converser.sockpath` (`600`); `CONVERSER_VOICE=off` adds `mcp__voicemode__converse` to the one deny list and appends the voice-off line; a second launcher gets `converser already running`; on exit only `lock` and `settings.json` remain.
- **Hooks** with a fake Unix socket and sessions registry: posts arrive as `{"type":"user","message":{"role":"user","content":"From: clauthier-overseer\nKind: stop ..."}}`; an unknown session falls back to `main (unnamed)`; a 1500-char message becomes 600 chars plus the header; traced actions `skip:no-converser`, `posted`, `skip:background_tasks`, `skip:converser`, `skip:empty`, `trace-only`, `error` (garbage input, exit 0), `skip:no-live-converser` (socket removed); trace mode `600`; the `inbox.py` CLI posts from stdin.

### Host state after the turn

`~/.voicemode`, `~/.config/containers/systemd`, `~/.config/converser-host`, `~/.local/share/converser-host`, `~/.local/bin/{converser-host,voicemode}`, the `serve@` unit, and the `voice-mode` uv tool are all absent; no `converser-*` podman secret; no whisper or Kokoro image; no `voicemode serve` process.
The scratch `HOME` (438 MB) was removed. The host `uv` cache (`~/.cache/uv`) holds the resolved wheels.

### Implementer Notes

- Bugs caught by testing before commit: `mcp_tool_names` clobbered its arguments with `set --`; `host_checks`, `instance_checks`, and `cmd_status` shared the global `rc` (POSIX sh has no `local`), so an instance check would erase a host failure; the SSE parser printed each `data:` line twice; host `FORCE_COLOR` broke the `uv` bin-dir comparison.
- Not verified until 1.1+: real `systemctl`/Quadlet start with `Notify=healthy`, `podman pull`, the model download and checksum, `mask`, `ss`/`podman inspect` against real containers, `podman secret` delivery into the container, and the in-container `claude` behavior (flags, `--settings` hook, `ListAgents`/`SendMessage`).
- Incident: a harness fallback (`command -v dash || podman run koalaman/shellcheck ...`) pulled `docker.io/koalaman/shellcheck:stable` (16 MB) even though host shellcheck exists. I removed it with `podman rmi`; no other image was touched.
