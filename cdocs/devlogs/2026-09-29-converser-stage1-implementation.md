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

## Changes Made

| file | commit | description |
|---|---|---|

## Verification

### Implementer Notes
