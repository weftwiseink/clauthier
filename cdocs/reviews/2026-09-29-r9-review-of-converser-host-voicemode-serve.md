---
review_of: cdocs/proposals/2026-09-29-converser-host-voicemode-serve.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-29T16:10:56-07:00
task_list: voice/converser-lace-feature
type: review
state: live
status: done
tags: [fresh_agent, confirm_round, claims_verified, stage_1, test_harness, tmux, podman_exec]
---

# Review (round 9): converser on host `voicemode serve`, hybrid Quadlet STT/TTS

> BLUF(opus/voice/converser-lace-feature): **Accept.**
> r9 resolves the r8 blocker: every converser swap now ends the session (`/exit`, then an in-container `flock` check, then a `pkill` fallback) and never kills the pane.
> A scratch simulation of `stop_converser`/`start_converser` behaves as specified on both paths. Each path frees the lock, runs the launcher's trap, and closes the window.
> All seven r8 nits (N1-N7) are applied correctly.
> What remains are four small non-blocking nits. The most useful is a tmux target-resolution race in `start_converser`: when the old window still exists, `new-window -t converser` resolves to that window and fails (verified/live). The failure is visible and harmless, and the fix is one character.

## Summary Assessment

The proposal specifies a host `voicemode serve` per container and an in-container converser session.
Stage 1 ends with a headset sitting in `clauthier`.
r9 is a targeted revision of the tmux harness.
It adds `lockfree`, `stop_converser`, and `start_converser`, and uses them in 1.4 step 3, in 1.5 prep, and in gate p.
It also applies N1-N7 from r8.
The new helpers are correct: the default exec user is `node`, `/exit` and `pkill` each free the lock, and no stale `respawn-window` or "close the window" step remains.
None of the safety properties (unattended mic or speaker, token on argv, the user's tmux, wezterm, or config) is weakened.
Verdict: **Accept**, with the nits below left to the implementer.

## Verification Log

Scratch work ran under `/home/mjr/.claude/jobs/b6b80a14/tmp/rev-r9*` with private `TMUX_TMPDIR` and `-L` sockets, and was removed afterwards.
No `podman exec` was run, and no user container, tmux server, `~/.voicemode`, or unit was touched.

| Claim | Result | Evidence |
|---|---|---|
| `podman exec clauthier ...` (no `-u`) in `lockfree`, `pkill`, and the OQ2 test runs as `node` | Confirmed | `podman inspect clauthier --format '{{.Config.User}}'` prints `node`. The lock probe, the `pkill`, and the OQ2 `claude -p` therefore run as the launcher's user with its `~/.claude` credentials. |
| `/exit` path: the lock frees once the session exits, the trap runs, and the window closes | Confirmed | A fake launcher (same `exec 9>`/`flock -n 9`/trap shape, with a child named `claude --name <probe>` that exits on `/exit`) in a `-f /dev/null` tmux window. `stop_converser` returned 0, `mcp.json` was removed, and only `overseer` remained. |
| `pkill` fallback: `pkill -f -- '--name <x>'` parses `--` and frees the lock | Confirmed | procps-ng 4.0.6. After the kill, `flock -n` succeeds, the trap has removed `mcp.json`, and the window has closed. |
| `pkill -f` matches any process whose command line contains the pattern | Confirmed, relevant | My first probe killed its own invoking shell, whose `bash -c` string contained the pattern. In the proposal, `pkill` runs inside the container's PID namespace, so host shells are out of reach. See N3. |
| `new-window -t converser` when a window named `converser` exists | **Fails** | `create window failed: index 1 in use`, rc 1: a bare `-t converser` resolves to the window before the session. `-t converser:` succeeds. See N1. |
| `claude --allowedTools <tools...>` exists | Confirmed | `claude --help` on the host. |
| No stale pane-kill step remains | Confirmed | `grep` finds `respawn`/`kill-window` only in 1.5's "Never `respawn-window -k` or `kill-window`". |

## r8 Action Items

| # | r8 item | Status |
|---|---|---|
| 1 | [blocking] End the session instead of killing the pane | **Resolved.** `stop_converser` in the harness is used in 1.5 prep (`stop_converser && start_converser ""`, gated on success) and in gate p's second half. Gate p's step-6 user script matches ("you see it quit"). The Edge Cases entry "Converser started twice" now states the orphaning behavior and both remedies. |
| 2 | Gate p variant permission | Resolved: `--allowedTools mcp__voicemode__converse`. |
| 3 | Gate p typed instruction relayed | Resolved: Listen gating adds the "Converser, do not relay:" prefix, and item 4 uses it. See N2. |
| 4 | 8800 token, pins, and probe race | Resolved: the throwaway gets the `serve@` pins and a `mktemp` token, the client reads it on stdin, polling is every 0.5 s, and the 8765 call is re-run on the probe race. |
| 5 | Nested tmux | Resolved: attach from outside tmux, or use `TMUX= tmux -L converser attach ...`. |
| 6 | OQ2 test is not a launcher run | Resolved: a bare `claude -p` with `${CONVERSER_TOKEN}` in the variant header, the token read inside the container into the environment only, and no `flock`. |
| 7 | Links range; item 5 split | Resolved. |

## Section-by-Section Findings

### Stage 1.4 harness (non-blocking)

- **N1. `start_converser` can hit a lingering window.**
  The lock is freed when the in-container `sh` exits.
  The tmux window closes a moment later, when the host-side `podman exec` client sees the session end.
  If `start_converser` runs in that gap, `new-window -t converser` resolves `converser` to the still-open window named `converser` and fails with "index N in use" (verified/live).
  `select-window -t converser:converser` then selects the dying window, or fails as ambiguous.
  The failure is visible, and a retry succeeds, so this does not derail 1.5.
  Fix: use `new-window -t converser:` (the trailing colon names the session), and optionally end `stop_converser` by waiting until `$T list-windows -F '#W' | grep -qx converser` is false.
  The same `-t converser:` form suits the first `new-window` in 1.4.

### Listen gating and the security floor (non-blocking)

- **N2. Scope of the "Converser, do not relay:" exception.**
  Listen gating now has one exception to "any other typed line is the request", but the next sentence still says "With `CONVERSER_VOICE=off`, every typed line is a request", and the voice-off prompt line says the same.
  Nothing in 1.4 uses the prefix, so this has no effect on the run. It is only a wording inconsistency.
  Two clarifications are worth making in `SYSTEM_PROMPT.md`.
  First, the prefix applies to typed lines only, not to transcribed speech.
  Second, an instruction to the converser is still bound by the security floor (call-shape bounds, no configuration or permission changes).
  Gate p's request (`listen_duration_max=90`) is within the floor.

### Stage 1.5 prep (non-blocking)

- **N3. `pkill -f` breadth.** The pattern `--name converser` matches any in-container process whose command line contains it.
  An overseer's Bash tool command that contains the string would match, as it did for my probe's shell.
  This is harmless in stage 1: the only other long-lived process is `claude --name clauthier-overseer`, which does not match.
  A tighter pattern such as `'^[^ ]*claude .*--name converser( |$)'` would be more exact. Leave that to the implementer.
- **N4. The voice-on converser starts in prep, before the user is at the desk.**
  The ordering is unchanged from r8.
  An idle voice-on converser opens nothing by itself.
  A stray inbound `SendMessage` from the overseer could make it speak, and a question in reply could open a listen, since listen gating allows one "immediately after it asked the user something".
  Stage 1.5 has no Stop hook, and 1.4's overseer is idle by then, so the likelihood is negligible.
  To remove the window entirely, run `stop_converser && start_converser ""` after the user confirms that the sitting has started, just before script step 3.

### Trivia

- Item 1: "A `mktemp` token file is passed to it through `VOICEMODE_SERVE_TOKEN`" means the file's value, not the file itself.
- Links: "`-r2-` through `-r8-`" goes stale with this review.

## Verdict

**Accept.**
The r8 blocker is fixed correctly and consistently in every place it applied, and the helpers behave as specified when simulated.
All r8 non-blocking items are applied.
The remaining nits are cosmetic, or they fail visibly and recoverably during implementation. None threatens the stage-1 path or a safety property.

## Action Items

1. [non-blocking] `start_converser` (and 1.4's first `new-window`): target `converser:` rather than `converser`; optionally have `stop_converser` wait for the window to close.
2. [non-blocking] Listen gating and the voice-off prompt line: reconcile "every typed line" with the do-not-relay prefix; scope the prefix to typed lines and state that the security floor still applies.
3. [non-blocking] Optionally tighten the `pkill -f` pattern to the `claude` argv.
4. [non-blocking] Optionally start the voice-on converser only once the user confirms that the sitting has started.
5. [non-blocking] Trivia: "token file ... through `VOICEMODE_SERVE_TOKEN`" wording; the Links review range.

## Questions for the Author

1. Where the voice-on converser starts in 1.5:
   (a) keep it in prep (current; negligible risk);
   (b) start it right after the user confirms that they are present, before script step 3 (recommended: no idle voice-on window at all);
   (c) have the user start it by typing into the attached pane.
