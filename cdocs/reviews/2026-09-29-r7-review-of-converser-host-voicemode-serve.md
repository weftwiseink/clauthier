---
review_of: cdocs/proposals/2026-09-29-converser-host-voicemode-serve.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-29T15:58:00-07:00
task_list: voice/converser-lace-feature
type: review
state: live
status: done
tags: [fresh_agent, claims_verified, implementability, stage_1, test_harness, tmux, privacy, host_install]
---

# Review (round 7): converser on host `voicemode serve`, hybrid Quadlet STT/TTS

> BLUF(opus/voice/converser-lace-feature): **Revise, small.**
> Both r6 blockers are fixed, and every r6 non-blocking item is applied or explicitly carried.
> The `--excludes` route resolves cleanly (re-checked here), and the `pause_conversation` handling is consistent across the tool lists, the launcher, and the threat table.
> The new 1.4 harness has two defects that a dispatched implementer would hit while the user is away.
> First, the converser has no text-only mode, so typed relays in 1.4 make it call `converse()`, which by default speaks on the host and then opens the host mic. That is exactly the condition r7 moved gate p to 1.5 to avoid.
> Second, `tmux -L converser` loads the user's `~/.config/tmux/tmux.conf`, which sets prefix `M-z` (so the 1.5 script's `Ctrl-b` keys do nothing) and loads tpm with resurrect and continuum, which the user runs for their real sessions.
> Both are one-line fixes.

## Summary Assessment

r7 closes the r6 blockers: `install` drops `simpleaudio` with `uv tool install --excludes`, and stage 1.4 gets an implementer-driven host `tmux` harness plus an exact headset script in 1.5.
It also handles the `pause_conversation` tool that `VOICEMODE_TOOLS_ENABLED=converse` exposes, and it applies all the r6 non-blocking items except the design-map regeneration, which the NOTE still flags as stale.
The document is accurate and internally consistent in most places.
The new harness text, however, claims "Nothing in 1.4 opens a listen" without a mechanism behind it, and it inherits the user's tmux configuration.
There are also some smaller procedural gaps in 1.4 and 1.5 (the flock versus headless runs, the conch-sharing throwaway, the MCP client's dependencies and stdin).
Verdict: **Revise**. The next round should be a quick confirm.

## Verification Log

All checks were read-only, except one scratch `uv pip compile` whose `HOME` and cache pointed at a job temp dir, which was then removed.

| Claim | Result | Evidence |
|---|---|---|
| `uv tool install --excludes <file>` exists in uv 0.11.23 | Confirmed | `uv tool install --help`: "Exclude packages from resolution using the given requirements files". |
| Excluding `simpleaudio` still resolves `voice-mode==8.12.0` | Confirmed | Scratch `uv pip compile --python-version 3.12 --excludes` resolves without `simpleaudio`, and with `sounddevice==0.5.6`, `pydub`, `fastmcp==3.4.7`, and `mcp==1.30.0`. The proposer's scratch install covers import and 401. |
| `pause_conversation` comes with the `converse` module and cannot be removed server-side | Confirmed | Tools load per module file (`tools/__init__.py:load_tool`), and `VOICEMODE_TOOLS_ENABLED`/`_DISABLED` both name modules. `pause_conversation` is a second `@mcp.tool()` in `converse.py:4528`. |
| `pause_conversation` hold ends "at the idle-expiry valve or a restart" | **Partly wrong** | The loop re-stamps the hold every half-TTL for the full `seconds` (`converse.py:4590-4612`), so idle-expiry cannot clear it during the pause. Only the end of the pause or the death of the `serve` PID (restart) frees it. See N1. |
| The conch path follows `HOME` | Confirmed | `conch.py:133`: `LOCK_FILE = Path.home() / ".voicemode" / "conch"`. See N3. |
| `converse()` listens by default | Confirmed | `wait_for_response: ... = True` (`converse.py:4312`). `skip_tts` only skips speech. See B1. |
| tmux 3.6a on the host | Confirmed | `tmux -V`. |
| The user's tmux config applies to a `-L converser` server | Confirmed (config), plausible (effects) | `~/.config/tmux/tmux.conf` sets `prefix M-z`, runs tpm, and loads `tmux-resurrect` and `tmux-continuum` (`@continuum-restore 'on'`, 15-minute saves). tmux loads that file on every server start, whatever the `-L` name. The user's resurrect snapshots in `~/.local/share/tmux/resurrect/` are live (latest 2026-09-29 09:22). See B2. |
| Bypass prompt will not block the overseer pane | Confirmed | Shared user settings carry `skipDangerousModePermissionPrompt: true`. The workspace-trust dialog may still appear the first time; the implementer can answer it with `look`/`say`. |
| Host `python3` can run an MCP-SDK client | **No** | `python3 -c 'import mcp'` fails on the host. See N4. |
| `clauthier` still has `claude` 2.1.274 and no `tmux` | Confirmed | `podman exec` (read-only). |

## r6 Action Items

| # | r6 item | Status |
|---|---|---|
| 1 | [blocking] `simpleaudio` route | **Resolved.** `--excludes` with a packaged `uv-excludes.txt`, the Facts line is corrected, `install` prints the failing `uv` lines, and ask B is still the only `sudo`. |
| 2 | [blocking] 1.4 operator model | **Resolved as to who and how** (host `tmux`, `podman exec -it` panes, `wezterm cli` explicitly avoided, headless coverage named). The new harness has its own defects (B1, B2). |
| 3 | Kokoro digest-only; `Cmd` wording | Resolved. |
| 4 | Upgrade two "plausible" items | Resolved (baked model; launcher comment cites `TokenAuthMiddleware`). |
| 5 | `instance add` re-run semantics | Resolved: repair semantics, `--port` refused on an existing project, and the failure picture names both routes. |
| 6 | GPU gate first; `HealthStartPeriod` | Resolved (both containers). |
| 7 | Gate p procedure and placement | Resolved in substance: it moves to ask D. See N2 for the flock interaction. |
| 8 | Batch A-C; `claude --version` re-check; `podman start` edge case | Resolved. |
| 9 | "r5 backstop" wording; design map | Wording resolved. The map is still stale and flagged in the NOTE. Acceptable while the NOTE stays. |

## Section-by-Section Findings

### B1 [blocking] Stage 1.4: nothing keeps the converser off the host mic and speakers while the user is away

1.4 says "Nothing in 1.4 opens a listen: the converser prompt's listen gating plus typed text keeps the mic closed."
The interaction model says the opposite.
In stage 1, *typing into the converser's terminal is how the user starts an exchange*, and each relay ends with a *spoken* readback.
`converse()` defaults to `wait_for_response=True`, so a readback, or a response to `say converser "Send clauthier-overseer: ping ..."`, speaks through the host speakers and then opens the host mic for up to 90 s.
The implementer runs this without the user present.
Item 8's "with `skip_tts`" suppresses only the speech and still listens.
This is the away-from-desk mic condition that r7 moved gate p into ask D to avoid, and it will happen repeatedly across items 6 and 8.

Fix: give 1.4 a mechanical text-only mode rather than relying on the prompt. For example:
- `CONVERSER_VOICE=off` in the launcher appends `mcp__voicemode__converse` to `--disallowedTools` and adds one line to the system prompt ("voice is off: treat each typed line as the user's speech; print the readback instead of speaking it"), or
- pass `--disallowedTools` through `"$@"`, but only after confirming that a second `--disallowedTools` merges with the first rather than replacing it.

With `converse` removed, the preflight and the MCP connection are still exercised, and gates e, f, b and the text half of item 8 run without any audio.
The SYSTEM_PROMPT should also say explicitly how typed text is treated when voice is on (as a trigger to listen, or as the request itself), because 1.5 step 5 and 1.4 currently assume different answers.

### B2 [blocking] The `tmux -L converser` server inherits the user's tmux config

tmux loads `~/.config/tmux/tmux.conf` for every new server, whatever the `-L` socket name.
The user's config:
- sets `prefix M-z`, so 1.5 steps 4 and 9 (`Ctrl-b n`, `Ctrl-b d`) do nothing for this user;
- runs tpm with `tmux-resurrect` and `tmux-continuum` (`@continuum-restore 'on'`, saves every 15 minutes).
  Continuum can restore the user's saved sessions into the new server on start, and its saves write to the same resurrect directory as the user's real sessions. They could then replace the user's `last` snapshot with the two-pane `converser` session (plausible, not exercised here);
- installs an `after-new-session` hook and `lace-split` bindings.

The harness's own behavior (send-keys, capture-pane) is not affected, but the user's tmux state is, and the user never asked for that.
Fix: start the server with `tmux -L converser -f /dev/null new-session ...`. Every later `-L converser` command then talks to that server and uses its default `C-b` prefix.
Better still, make the script prefix-agnostic. The user attaches with `tmux -L converser attach -t converser:converser`, the implementer switches windows with `tmux -L converser select-window -t converser:overseer`, and the user detaches with `tmux -L converser detach-client` from another terminal, or by closing the terminal window.

### Stage 1.4 and 1.5 procedure (non-blocking)

- **N2. The flock blocks headless runs while the pane is up.** The launcher takes `flock -n` on `$run/lock`, and 1.4 starts the converser pane first. After that, "the headless `converser -p ...` form covers item 5 ... and Open Question 2" fails with "converser already running". The same applies to gate p in 1.5 step 7 if the implementer runs it as `converser -p`. Say to run item 5 and the OQ2 test before creating the converser window. For gate p, either drive the 600 s run through the converser pane (a typed instruction) or stop the pane first. The no-`timeout` half needs a separate `claude -p --strict-mcp-config --mcp-config <variant>` with the token written by the builtin `printf`, as the launcher does. State that too, so the token handling stays argv-free.
- **N3. The item 1 throwaway must share the conch.** The install stop-check points the throwaway's `HOME` at a temp dir. That throwaway's conch is then `<tmp>/.voicemode/conch`, not `~/.voicemode/conch`, and 1.5 step 3 would *never* see "conch held". Say that the item 1 throwaway on 8800 keeps the real `HOME` (with a temp `VOICEMODE_BASE_DIR`), unlike the stop-check. Also say how the implementer knows step 2 is listening: for example, poll `flock -n ~/.voicemode/conch true` until it fails, or have the implementer start step 2's call as well so the user only speaks.
- **N4. The `mcp-converse.py` runtime and invocation.** Host `python3` has no `mcp` package. Specify either stdlib only (urllib plus SSE parsing) or running it with the tool venv's interpreter (`~/.local/share/uv/tools/voice-mode/bin/python`, which has `mcp` 1.30). The 1.5 step 2 command `python3 <item-1 client> --instance clauthier` gives no stdin, while 1.0 says the token comes "on stdin". Write the full command, including `< ~/.config/converser-host/instances/clauthier.token` and the installed-copy path. The checkout copy is container-writable, which is the same reason `install` self-installs.
- **N5. An empty Enter does not submit in Claude Code.** 1.5 step 5 ("Press Enter in the converser pane") and the listen-gating paragraph ("Enter, or "listen"") rely on an empty submit, which the TUI ignores. Use "type `listen` and press Enter" in both places.

### Facts, BLUF, and the threat table (non-blocking)

- **N1.** The `pause_conversation` threat row says the floor is held "until the idle-expiry valve or a restart". The pause re-stamps the hold throughout `seconds`, so only the end of the pause or a `serve@` restart frees it (the dead PID fails the liveness check). Reword it, and raise Impact to reflect that the hold is unbounded until a restart.
- **N6.** The BLUF still says "`converse` tool only". Say "`converse` module only (`converse`, `pause_conversation`)" or similar, to match Facts and `status`.
- **N7.** `voice-mode==8.12.0` pins only the top level. Transitive packages float (`fastmcp` 3.4.7 today), so a re-install on another day can resolve differently from the verified set. Consider `--exclude-newer <date>` alongside the pin, or record `uv pip freeze --python ~/.local/share/uv/tools/voice-mode/bin/python` as `installed-deps` next to `installed-rev`. This is not new in r7, and it is not required for stage 1.

### Writing conventions

The r7 NOTE uses "now" several times. NOTE callouts may reference revisions, so this is fine.
The body stays in present tense.

## Verdict

**Revise.**
r7 resolves both r6 blockers and all nine r6 action items (the design map is still stale but is flagged).
Two defects remain in the new 1.4 harness, and both affect things outside the implementer's sandbox while the user is away: the host mic and speakers (B1), and the user's tmux state and keybindings (B2).
Each is a one-line fix, and the non-blocking items N2-N5 are short procedural clarifications in the same two subsections.
Once they are fixed, stage 1 should be implementable by a dispatched implementer as written.

## Action Items

1. [blocking] 1.4: add a mechanical text-only mode (for example `CONVERSER_VOICE=off` → `converse` added to `--disallowedTools`, plus one prompt line) and use it for items 6 and 8. Correct "Nothing in 1.4 opens a listen" to name the mechanism. State in SYSTEM_PROMPT how typed text is treated when voice is on.
2. [blocking] 1.4/1.5: start the harness with `tmux -L converser -f /dev/null ...`. Make the 1.5 attach, window-switch, and detach steps prefix-agnostic, or name the `C-b` prefix that `-f /dev/null` guarantees.
3. [non-blocking] 1.4: run item 5 and the OQ2 test before starting the converser window (flock). Specify how gate p's two runs are driven given the flock, including the argv-free token handling for the no-`timeout` variant config.
4. [non-blocking] Item 1 / 1.5 step 3: the conch-check throwaway keeps the real `HOME`. Say how the implementer detects that the user's listen is active.
5. [non-blocking] `mcp-converse.py`: stdlib only or tool-venv interpreter. Give the full 1.5 step 2 command with the token on stdin and the installed-copy path.
6. [non-blocking] Replace "press Enter" with "type `listen` and press Enter" (1.5 step 5 and Listen gating).
7. [non-blocking] Threat table: the `pause_conversation` hold lasts the full `seconds`, and only a restart ends it early.
8. [non-blocking] BLUF: "`converse` tool only" → the `converse` module (two tools).
9. [non-blocking] Consider pinning transitive deps (`--exclude-newer`) or recording the resolved set at install.

## Questions for the Author

1. The text-only mode for 1.4:
   (a) a launcher env switch that disallows `mcp__voicemode__converse` and adds one prompt line (recommended: mechanical, and still exercises the MCP connection);
   (b) a `--disallowedTools` passthrough via `"$@"`, only if a repeated flag merges;
   (c) accept audio in 1.4 and move items 6 and 8 into ask D (makes the sitting much longer).
2. The tmux harness config:
   (a) `-f /dev/null`, with default keys named in the script (recommended);
   (b) the user's config, with the script written for `M-z`, accepting the resurrect and continuum side effects.
3. Gate p driver:
   (a) the 600 s run through the converser pane by typed instruction, and the no-`timeout` run as a separate `claude -p` with a variant config (recommended);
   (b) stop the converser pane and run both as `claude -p` with two configs.
