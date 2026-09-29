---
review_of: cdocs/proposals/2026-09-29-converser-host-voicemode-serve.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-29T09:47:08-07:00
task_list: voice/converser-lace-feature
type: review
state: live
status: done
tags: [rereview_agent, fresh_agent, security, networking, claims_verified, runtime_validated, stage_one_implementability, proportionality]
---

# Review (round 2): converser on host `voicemode serve`

> BLUF(opus/voice/converser-lace-feature): Accept.
> Both round-1 blockers are resolved and all nine non-blocking items are addressed.
> The new loopback-unit design leaves one durability gap worth closing before step 1.0 runs: VoiceMode's own whisper/Kokoro units are only "disabled", yet its installers auto-enable and start them by default, and `voicemode whisper model install` starts `voicemode-whisper` even when it is disabled.
> The firewalld rejects cover that gap on the LAN, which makes the rules load-bearing, not optional.
> The Test Plan's `host.containers.internal` probe tests the bind, not the firewall.

## Summary Assessment

This round checks the revision's changes: the round-1 fixes, the design-owned loopback STT/TTS units, firewalld rejects, `ExecStart=/usr/bin/env` pins, the boolean-only conch floor, checkpoint 1.4a, and gates (p)-(t).
Every round-1 action item is resolved, and the new material is mostly correct against VoiceMode source and live inspection of this host.
The most important new finding is that "disabled" is too weak for VoiceMode's own units, because its code paths re-enable or start them (N1).
The next is that the Test Plan's container probe cannot observe the firewall, since host-local traffic arrives on `lo` (N2).
Neither blocks acceptance: the loopback bind is the primary control, and the firewall rejects already cover the LAN side of N1.
Stage 1 stays proportionate, since checkpoint 1.4a answers "is voice usable" before any Stop-hook work.
Verdict: **Accept**.

## Round-1 Action Item Status

| # | Round-1 item | Status | Where |
|---|---|---|---|
| 1 | [blocking] Conch-timeout claim; boolean-only `wait_for_conch`, no holds | **Resolved** | Facts line 78, Design points, Client timeout, 1.4 prompt, threat row. Verified `converse.py:3118-3123` and the signature (`converse.py:2948-2951`: `wait_for_conch`, `conch_mode`, `hold_conch`, `conch_hold_timeout` all exist as named) |
| 2 | [blocking] Durable loopback bind + firewalld second layer | **Resolved, with a gap** (N1) | New "Host: STT/TTS bound to loopback, durably" subsection; firewalld zone evidence cited and re-confirmed live |
| 3 | Pins on `ExecStart=/usr/bin/env` | **Resolved** | Unit and NOTE |
| 4 | Plugin install claim, plugins/org citation, `extraKnownMarketplaces`, no project-settings enablement | **Resolved** | Placement section, WARN narrowed, stage-3 constraints |
| 5 | Relay order | **Resolved** | Send-then-readback, with reasoning |
| 6 | Stage-1a checkpoint, time box, atomic-host toolchain, recreate at a break, `runArgs` commit decision | **Resolved** | Stage-1 defaults, 1.0, 1.3, 1.4a |
| 7 | #521 second-client consequence | **Resolved** | Token-holder threat row |
| 8 | Reconnect limit, post-rebuild check, `~/.voicemode.env` | **Resolved** | Edge cases, gate (s) |
| 9 | Define gates (p)-(t) | **Resolved** | Test Plan preamble |
| 10 | Launcher trap, `WaitForMcpServers` | **Resolved** | Launcher, Test Plan item 5 |
| 11 | History framing | **Mostly resolved** | "The heart of the revision" is gone; see N7 |

## Claim Verification (new material)

| Claim | Result | Evidence |
|---|---|---|
| Default zone `FedoraWorkstation` on `enp3s0` opens `1025-65535/tcp` | **Correct** | Live: `firewall-cmd --get-active-zones`, `--list-all`; firewalld 2.4.0; no rich rules today. A second active zone, `docker` (on `docker0`), exists as well |
| Reject rich rules win over the zone's open port range | **Correct** | firewalld places reject/drop rich rules in the zone's `_deny` sub-chain, which precedes `_allow` (ports, services) |
| Loopback traffic does not traverse the zone, so pasta calls are unaffected | **Correct** | pasta's host side connects to `127.0.0.1:<port>`, so the traffic enters on `lo`, which firewalld accepts before any zone |
| Probe via `host.containers.internal` reaches the host's non-loopback address | **Correct, but it does not test the firewall** | Live: `host.containers.internal` is `169.254.1.2`; pasta runs with `--no-map-gw --map-guest-addr 169.254.1.2` (podman 5.8.2), which maps to `192.168.0.65`. A host connecting to its own address still routes over `lo`. See N2 |
| Whisper flags "copied from the upstream script, host changed" | **Partly** | `start-whisper-server.sh:147-153` also passes `--threads` and `--convert`. Dropping `--convert` is harmless in practice, because VoiceMode uploads WAV to a local endpoint in `STT_COMPRESS=auto` (`converse.py:1076-1081`). An env-file `VOICEMODE_STT_COMPRESS=always` would send mp3 to a whisper that no longer converts. See N4 |
| Kokoro start script copied into VoiceMode's install dir (`kokoro/install.py:235-252`) | **Correct** | It is `start-gpu.sh` on Linux, from the `ai-cora/Kokoro-FastAPI` fork. A custom-port copy is made by string-replacing `--port 8880` |
| A reinstall can rewrite VoiceMode's tree but not the design-owned units | **Correct as stated, but incomplete** | See N1: the reinstall re-enables and starts VoiceMode's own units |
| `VOICEMODE_CONTROL_CHANNEL_ENABLED`, `SERVE_ALLOW_TAILSCALE`/`_ANTHROPIC` key names | **Correct** | `config.py:690,1648,1651` |
| Lace user config supports `containerEnv`, not `runArgs` | **Correct** | `user-config.ts:27`; no `runArgs` field |

## Section-by-Section Findings

### Host: STT/TTS bound to loopback, durably

The approach is right: own the bind in units this design controls, and use VoiceMode's installers only to fetch and build.

**N1 [non-blocking, highest priority]: "disabled" does not keep VoiceMode's own units off, and step 1.0's order opens an exposure window.**
Three code paths start the upstream `0.0.0.0` units:
- `voicemode whisper install` and `kokoro install` auto-enable and start their units by default. `SERVICE_AUTO_ENABLE` defaults to `True` (`config.py:927`), and `enable_service` runs `systemctl --user enable` and then `start` (`tools/service.py:733-742`). Step 1.0 runs the installers first and disables the units afterwards, so whisper listens on the LAN in between.
- `voicemode whisper model install` restarts whisper whenever `pgrep -f whisper-server` matches, and the design's own `converser-whisper` process matches. The restart is `systemctl --user start voicemode-whisper.service` (`whisper_model_unified.py:169-179`, `service.py:431-437`), which starts a disabled unit without complaint.
- `VOICEMODE_AUTO_START_KOKORO=true` in any env file makes VoiceMode start its Kokoro service (`shared.py:44`); it defaults to off.

While the design's units hold ports 2022 and 8880, the upstream wildcard bind most likely fails with `EADDRINUSE`.
After a crash or at boot, whichever unit starts first gets the port.

Fix, three lines in 1.0:
- `firewall-cmd` rules first;
- installers with `--no-auto-enable` (the flag exists: `cli.py:810,981,1144`);
- `systemctl --user mask voicemode-whisper voicemode-kokoro` instead of disable. A masked unit refuses `start`, so all three paths fail loudly.

Also note that a model change means editing `converser-whisper.service`, since `voicemode whisper model install` no longer reaches the running server.

**N3 [non-blocking]: the firewalld rules are IPv4-only and zone-specific.**
Since `family=ipv4` is not needed for a port-only rich rule, dropping it makes the rule cover both families, at no cost.
The rules also bind only to `FedoraWorkstation`.
If a Wi-Fi or VPN interface lands in another zone, or traffic arrives from the `docker` zone (target `ACCEPT`), the rejects do not apply.
The loopback bind covers all of these, so one sentence saying "the zone rules cover `enp3s0` only; the bind is the control" is enough.

**N4 [non-blocking]: make the whisper and Kokoro command lines faithful copies.**
For whisper, keep `--threads` and either keep `--convert` (which needs `ffmpeg` on the host) or pin `VOICEMODE_STT_COMPRESS=never` among the `ExecStart` pins.
The second option is cheaper, and it also closes the env-file path to mp3 uploads.
For Kokoro, prefer the "copy of its start script, host changed" option over a bare `uvicorn` invocation.
Upstream Kokoro-FastAPI's `start-gpu.sh` sets the project environment (model and voice dirs, `PYTHONPATH`, GPU flags) before launching `uvicorn`, so a bare entry point would likely start misconfigured.
This is from memory of upstream, which is not installed here, so it is plausible rather than verified.
Pick one option and say so; the text currently offers both.

### Host: `serve` instance per container

The `ExecStart=/usr/bin/env` unit is correct:
- `%S` resolves to `~/.local/state` for a user unit;
- `${VOICEMODE_SERVE_PORT}` is substituted from the `EnvironmentFile=`;
- the backslash continuations are valid;
- a missing env file fails the unit, which is the right behavior here.

The NOTE's reasoning is sound.
One precision point: the pins win only for the keys they name.
An env file can still set unpinned keys such as `VOICEMODE_SERVE_ALLOWED_IPS`, `VOICEMODE_STT_COMPRESS`, or `VOICEMODE_AUTO_START_KOKORO`.
`ALLOWED_IPS` is inert behind the token under pasta, and the rest are covered by N1 and N4.
So "no env-file line can re-widen tools or URLs" is accurate; the threat row's "win over any env file" should say "for the pinned keys". This is a one-word edit.

### Test Plan and gates (p)-(t)

The gate list is clear.
Items 9 and 10 map cleanly to gates (r) and (s).
The note that item 9 runs before 7 and 10 fixes the ordering ambiguity.

**N2 [non-blocking]: item 2 and the subsection's parenthetical overstate what the container probe shows.**
`curl http://host.containers.internal:2022/` from `weftwise` reaches `192.168.0.65` through pasta's `--map-guest-addr`, but the host-side connect runs over `lo`.
It proves the loopback bind (a `127.0.0.1` listener refuses the global address) and says nothing about the firewalld rejects.
Nothing on this host can exercise those rules.
Fix:
- reword the parenthetical to "unaffected (plausible: pasta's host side connects over `lo`)", with Test Plan item 3 as the check that the forward still works;
- in item 2, label the container probe as the bind check and the `--list-rich-rules` listing as the firewall check;
- optionally, add a probe from another LAN device (for example `nc -zv 192.168.0.65 2022` from a phone or laptop) as the only real end-to-end firewall test.

The Test Plan preamble says each item "names ... the stage-1 step that runs it", but the items name gates only.
The steps name their items instead, so drop that clause or add the step numbers.

### Implementation Phases and proportionality

Stage 1 stays cheap and incremental.
The new host-side pieces are two small units and three firewall commands, all inside the step already time-boxed.
Checkpoint 1.4a puts "is voice usable" ahead of the AFK-arc Stop-hook dry run, which was the main proportionality concern in round 1.
The overrun fallback ("whisper-only, `skip_tts`") is sensible.

**N5 [non-blocking]: step 1.4a does not say how the user opens a listen in stage 1.**
Listen gating allows a listen only after "a wake, later a push-to-talk hotkey", but stage 1 has neither.
Until something else exists, the practical wake is the user typing into the converser's terminal (for example Enter, or "listen").
State that, so the checkpoint is runnable as written and the Test Plan 8 transcripts have a defined trigger.

**N6 [non-blocking]: the uncommitted `runArgs` edit sits in a checkout whose agents commit often.**
Container overseers work in the same `weftwise` checkout, run in bypass mode, and commit frequently, so a broad `git add` will eventually sweep the edit into a commit.
`git update-index --skip-worktree .devcontainer/devcontainer.json` for stages 1-2 (undone before any intended edit) or an explicit caution in the 1.3 step prevents it.
Context: weftwise already commits host-specific `runArgs` (the `/run/user/1000/wayland-0` bind), so an accidental commit is recoverable, not a disaster.

### Writing conventions

**N7 [non-blocking]:** a few history-framed phrases remain outside NOTE callouts:
- "(review round 1, author's call)" in Stage-1 defaults;
- "(verified/live, round-1 review)" or similar, in three places;
- "The round-4 design got all-or-nothing from one feature carrying everything".

Evidence labels can stay `verified/live`; drop the review-round provenance, and move the round-4 line into the existing Summary NOTE or rephrase it in the present tense.

## Verdict

**Accept.**
Both round-1 blockers are resolved against source.
The design, placement, interaction model, and residual-risk statement still match the user's requirements, and stage 1 is cheaper to learn from than in round 1.
N1 should be folded in before step 1.0 is executed, because it changes the order of the most security-relevant step.
It does not need another review round.

## Action Items

1. [non-blocking, do before 1.0] Reorder 1.0: firewalld rejects first, then installers with `--no-auto-enable`, then `systemctl --user mask voicemode-whisper voicemode-kokoro` (not disable). Note that model changes go through `converser-whisper.service`.
2. [non-blocking] Reword the "checked by the Test Plan ... `host.containers.internal`" parenthetical and Test Plan item 2: the container probe checks the bind, the rich-rule listing checks the firewall config, and an off-host probe is the only end-to-end firewall test.
3. [non-blocking] Drop `family=ipv4` from the rich rules; add one sentence that the rules cover `enp3s0`'s zone only and the bind is the primary control.
4. [non-blocking] Whisper unit: keep `--threads`; keep `--convert` or pin `VOICEMODE_STT_COMPRESS=never` among the `ExecStart` pins. Kokoro: commit to the copied start script with the host changed.
5. [non-blocking] Threat row "Env file re-widens tools or URLs": "win over any env file for the pinned keys".
6. [non-blocking] Name the stage-1 listen trigger (typed input in the converser terminal) in Listen gating or 1.4a.
7. [non-blocking] In 1.3, protect the uncommitted `runArgs` edit from overseer commits (`git update-index --skip-worktree`) or add a caution.
8. [non-blocking] Test Plan preamble: drop "and the stage-1 step that runs it" or add step numbers.
9. [non-blocking] Remove review-round provenance from the body; move or rephrase the round-4 all-or-nothing line.

## Questions for the Author

1. VoiceMode's own whisper/Kokoro units:
   (a) mask them (recommended; refuses every start path);
   (b) disable them and rely on the firewalld rejects;
   (c) delete the unit files after install (a reinstall recreates them).
2. Whisper input conversion:
   (a) pin `VOICEMODE_STT_COMPRESS=never` and drop `--convert` (recommended; no host `ffmpeg` needed);
   (b) keep `--convert` as upstream does, which requires host `ffmpeg`.
3. Firewall verification:
   (a) the rich-rule listing only (config check);
   (b) plus a one-off `nc` probe from another LAN device at step 1.0 (recommended; the only end-to-end test).
