---
review_of: cdocs/proposals/2026-09-29-converser-host-voicemode-serve.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-29T16:05:48-07:00
task_list: voice/converser-lace-feature
type: review
state: live
status: done
tags: [fresh_agent, claims_verified, implementability, stage_1, test_harness, tmux, podman_exec, text_only_mode]
---

# Review (round 8): converser on host `voicemode serve`, hybrid Quadlet STT/TTS

> BLUF(opus/voice/converser-lace-feature): **Revise, one line.**
> r8 resolves both r7 blockers and all seven r7 non-blocking items correctly. The launcher's `CONVERSER_VOICE=off` construction, the `-f /dev/null` harness, and the prefix-free attach all check out when run.
> One new procedural defect would derail 1.5: killing a tmux pane that runs `podman exec -it` does **not** end the process in the container (verified/live).
> `respawn-window -k` therefore leaves the voice-off converser holding the launcher's `flock`, so the voice-on converser exits with "converser already running". Gate p's "close the window so only one client talks to `serve`" is false for the same reason.
> The fix is to exit the session (`/exit`) and check the lock, instead of killing the pane.

## Summary Assessment

The proposal specifies a host `voicemode serve` per container plus an in-container converser session, and stage 1 ends in a headset sitting in `clauthier`.
r8 is a targeted revision.
It adds a mechanical text-only mode, isolates the tmux harness from the user's config, and fixes seven smaller procedural and wording issues from r7.
All of those fixes are correct, and the new launcher code runs as written.
One new error remains: the harness assumes that killing a pane stops the converser in the container, and a live test shows that it does not.
Verdict: **Revise**. It is a one-line fix in two places, and the next round should be a quick confirm.

## Verification Log

Scratch work ran under a job temp dir, which was removed afterwards.
The tmux checks used a separate `TMUX_TMPDIR` and socket.
The podman check used a separate `--root`/`--runroot`/`--tmpdir` store, read `node:24` from the user's store as an additional read-only image store, and removed its container afterwards.
None of the user's containers, tmux servers, `~/.voicemode`, or units were modified.
One stray no-op `podman exec clauthier true` was run by mistake; it changes nothing.

| Claim | Result | Evidence |
|---|---|---|
| Launcher builds `deny` and `prompt.md` correctly in both modes | Confirmed | Ran lines 407-412 verbatim under `sh` (bash): voice on gives the two-entry deny list; off appends `,mcp__voicemode__converse` and the prompt line with the apostrophe intact. `prompt.md` is `0600` under `umask 077`. Trap and `cp` both come after `flock`, so a refused second launch cannot clobber the first's files. |
| `tmux -L <x> -f /dev/null` gives default keys | Confirmed | `show -gv prefix` prints `C-b`; `@continuum-restore` is unset. |
| `attach -t converser:converser` lands in that window with no prefix key | Confirmed | Attached under `script(1)`; `list-clients` shows the client on window `converser`. |
| Killing the attached window moves the client to `overseer`; `new-window` + `select-window` brings it back | Confirmed | Same scratch server. |
| Killing a pane running `podman exec -it` ends the in-container process | **No** | `kill-window`, `respawn-window -k`, and a killed pane running an interactive `bash` child each left the exec'd process running in the container. `podman-exec(1)` describes exec sessions as detachable. See B1. |
| `--exclude-newer` on `uv tool install` in uv 0.11.23 | Confirmed | `uv tool install --help`. |
| `uv pip freeze --python <interp>` | Confirmed | `uv pip freeze --help`. |
| `flock -n ~/.voicemode/conch true` detects a live conch | Confirmed | VoiceMode's `file_lock.lock_exclusive` is `fcntl.flock(fd, LOCK_EX|LOCK_NB)` on the whole file, the same lock type `flock(1)` takes. |
| `claude --tools ''` disables built-ins only | Confirmed | `claude --help` (2.1.285 on the host): "Use "" to disable all tools" from the built-in set. MCP tools remain. See N1. |

## r7 Action Items

| # | r7 item | Status |
|---|---|---|
| 1 | [blocking] Text-only mode | **Resolved.** `CONVERSER_VOICE=off` adds `mcp__voicemode__converse` to one `--disallowedTools` value (no reliance on repeated-flag merging) and appends one prompt line. All of 1.4 runs with it, and "Nothing in 1.4 opens a listen" is replaced by the mechanism. Listen gating now defines typed text with voice on (`listen` opens a listen; any other line is the request itself), and readbacks use `wait_for_response=false`. |
| 2 | [blocking] tmux config isolation | **Resolved.** `-f /dev/null` is on the first command, which starts the server, and later `$T` commands reuse it. 1.5 attaches with `attach -t converser:converser`, the implementer switches windows, and detach is by closing the terminal or `detach-client`. |
| 3 | Flock ordering; gate p driver | Ordering **resolved** (headless checks first). The gate p procedure is specified, but see B1 (closing the window does not free the lock or the MCP client) and N1 (permissions). |
| 4 | Conch-check `HOME`; detecting the listen | Resolved (real `HOME`, temp `VOICEMODE_BASE_DIR`, `flock -n` poll). See N3 for two small gaps. |
| 5 | `mcp-converse.py` runtime and command | Resolved (tool-venv interpreter, installed copy, token on stdin). |
| 6 | Typed `listen` | Resolved in Listen gating and in 1.5 steps 4 and 7. |
| 7 | `pause_conversation` threat row | Resolved; the Impact is raised and the wording is accurate. |
| 8 | BLUF "`converse` module" | Resolved. |
| 9 | Transitive pinning | Resolved: `--exclude-newer` plus a recorded `installed-deps` freeze, and reproduction is honestly marked plausible. |

## Section-by-Section Findings

### B1 [blocking] Stage 1.5 and gate p: killing the pane leaves the converser running in the container

`podman exec -it` exec sessions outlive their client.
When tmux kills a pane, the host-side `podman` process dies, but the `claude` in the container keeps running under conmon (verified/live, above).
Two steps depend on the opposite assumption:

- **1.5 prep:** `$T respawn-window -k -t converser:converser "$X clauthier .../converser"`.
  The voice-off converser from 1.4 survives and holds `$run/lock`.
  The new voice-on launcher prints "converser already running" and exits, so the respawned window closes.
  This is the path to stage 1's target end state, and it breaks just before the user sits down.
  The orphan also stays registered as `converser` for `ListAgents` and keeps its MCP session to `serve`.
- **Gate p, second half:** "the implementer closes the converser window first, so only one client talks to `serve` (#521) and the launcher's lock is free."
  Neither part holds.
  The no-`timeout` run then shares `serve` with the orphaned voice-on converser, which is the multi-client condition #521 describes, and that could confound a wedge observation.

Neither case is a mic or speaker risk: the orphan has no input, and listen gating keeps it idle.

Fix, in both places: end the session rather than the pane.
For example, `say converser /exit`, then wait until the window closes, then confirm in the container that the lock is free: `podman exec clauthier flock -n /tmp/converser-1000/lock true`.
Keep `podman exec clauthier pkill -f -- '--name converser'` as a fallback.
Only then use `$T new-window -t converser -n converser "$X clauthier .../converser"` (plus `select-window`).
The Edge Cases entry "Converser started twice" could add one line: a killed `podman exec -it` pane leaves the process running.

### Stage 1.4, 1.5, and gate p (non-blocking)

- **N1. Gate p's no-`timeout` run needs a permission grant.**
  `claude -p ... --tools '' --disallowedTools mcp__voicemode__pause_conversation` has no `--permission-mode` and no `--allowedTools`.
  Unless the container's user settings already allow `mcp__voicemode__converse`, headless mode denies the call, and the 60 s abort is never observed.
  Add `--allowedTools mcp__voicemode__converse`, which is narrower than bypass.
- **N2. Gate p's first half is typed into a pane whose prompt says typed lines are relayed.**
  Listen gating says "Any other typed line is the user's request itself, relayed like speech".
  A typed "Call converse with listen_duration_max=90 ..." may be read as a message to relay.
  Phrase it as addressed to the converser ("Do not relay. Call your converse tool with ..."), or let the prompt say that a line addressed to the converser itself is an instruction.
  The requested parameters are within the security floor (`listen_duration_max` ≤ 90).
- **N3. Conch check details.**
  (a) The 8800 call needs the throwaway token on stdin too; only the 8765 command is written out.
  (b) Give the 8800 throwaway the same `ExecStart` pins (`VOICEMODE_STT_BASE_URLS`/`TTS_BASE_URLS` and the rest). If the first call ends early and the second acquires the floor, it would otherwise run with VoiceMode's defaults under the real `HOME`'s `voicemode.env`.
  (c) The `flock -n` probe itself takes the conch for an instant. Poll with a short sleep. If the 8765 call reports "conch held", re-run it.
- **N4. Nested tmux.**
  1.5 step 3 says to attach "in any host terminal".
  The user runs tmux, and `tmux attach` from inside a tmux client refuses ("sessions should be nested with care") whatever the `-L` name.
  Say "a terminal outside tmux", or give `TMUX= tmux -L converser attach -t converser:converser`.
  Prefixes do not collide (inner `C-b`, outer `M-z`).
- **N5. The OQ2 test is not a launcher run.**
  1.4 step 1 says both headless checks run as `converser -p ...`, but the `${VAR}` expansion test needs its own `--mcp-config` holding a `${...}` reference.
  That is a bare `claude -p --strict-mcp-config --mcp-config <variant>`, which takes no `flock` anyway.
  Say so, and note that the token goes in through the environment (`podman exec -e` reading the secret file inside the container, never on argv).

### Other nits (non-blocking)

- **N6.** Links: "the `-r2-` through `-r5-` rounds" is stale; there are rounds r6-r8.
- **N7.** Test Plan item 5 has several sentences on one line, and the "which confirms everything below except ..., which is absent by design" clause is hard to parse. Split it: the voice-off run checks the list below minus `converse`; item 3's `tools/list` and `/mcp` in the voice-on pane cover `converse`.

## Verdict

**Revise.**
Every r7 finding is resolved correctly, and the new launcher and tmux mechanics work when run.
One verified procedural error remains: the harness stops the converser by killing its pane, which leaves it running in the container.
That breaks the 1.5 voice-on respawn and invalidates gate p's single-client premise.
The fix is a short edit in two places.
With it applied, stage 1 is implementable by a dispatched implementer as written, and N1-N7 can be folded into the same pass or left to the implementer.

## Action Items

1. [blocking] 1.5 prep and gate p's second half: replace `respawn-window -k` and "closes the converser window" with ending the session (`say converser /exit`), confirming the in-container lock is free (`flock -n /tmp/converser-1000/lock true`, with `pkill` as a fallback), then `new-window` + `select-window`. Note in Edge Cases that a killed `podman exec -it` pane leaves the process running.
2. [non-blocking] Gate p's no-`timeout` command: add `--allowedTools mcp__voicemode__converse`.
3. [non-blocking] Gate p's first half: phrase the typed instruction as addressed to the converser (not a relay), or add that exception to the prompt.
4. [non-blocking] Item 1 conch check: 8800 token on stdin, the same `ExecStart` pins on the 8800 throwaway, and a poll interval plus retry for the probe race.
5. [non-blocking] 1.5 step 3: attach from outside tmux, or with `TMUX=` cleared.
6. [non-blocking] 1.4 step 1: the OQ2 test is a bare `claude -p` with a variant config and the token from the environment, not a launcher run.
7. [non-blocking] Links: update the review-round range. Item 5: split the long line.

## Questions for the Author

1. Stopping the converser between modes:
   (a) `/exit` typed into the pane, then an in-container lock check, with `pkill` as a fallback (recommended: clean exit, and the trap removes `mcp.json`);
   (b) `podman exec clauthier pkill -f -- '--name converser'` only (simpler to script, but it skips the TUI's clean shutdown);
   (c) add a `converser --stop` mode to the launcher (more code for a stage-1 harness).
2. Gate p's first-half driver:
   (a) a typed instruction explicitly addressed to the converser (recommended);
   (b) a prompt rule that lines starting with a marker (for example `!`) are instructions to the converser;
   (c) run both halves as bare `claude -p` with two configs, leaving the converser out of gate p.
