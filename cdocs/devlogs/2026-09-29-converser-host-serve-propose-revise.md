---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-29T11:00:00-07:00
task_list: voice/converser-lace-feature
type: devlog
state: live
status: done
tags: [oversee, propose-revise, voice, converser, architecture]
---

# converser host-serve revision: propose-revise devlog

> NOTE(mjr/converser-migration): Moved from lace cdocs to clauthier cdocs on 2026-09-29; clauthier is the code target.

> BLUF: Overseer log for a propose-revise loop retargeting the accepted in-container `converser` proposal to the host `voicemode serve` (one process per container) design, and deciding where each piece lives (lace feature? clauthier plugin? host-side service owner?).

## User direction (2026-09-29)

- "/propose-revise the proposal to target the host-server design, leaving it up to the first proposer on whether to evolve what we have into a new one or not."
- Resolve placement: if the server is host-side, is a lace feature still needed? Can/should the in-container agent wiring be a new clauthier plugin? Where does host-side server responsibility go ("part of me wants to say lace ... but feels like maybe a shoehorn")?

## Inputs

- Proposal: `cdocs/proposals/2026-09-28-converser-lace-feature.md` (implementation_ready, r4 accepted, in-container design).
- Reports: `2026-09-28-converser-options-vetting.md`, `2026-09-28-host-audio-broker-split.md`, `2026-09-28-voicemode-fork-complexity.md`, `2026-09-29-voicemode-complexity-breakdown.md`; decision artifact `2026-09-28-converser-directions-assets/index.html`.
- 2026-09-29 conversation findings: control channel is a host-side owner-only socket per `VOICEMODE_BASE_DIR` (fits host serve; hotkey needs conch-holder lookup); `audio://` resources are metadata-only, gated on `VOICEMODE_SAVE_AUDIO`, traversal-checked; tmux autofocus is inert under host serve; VoiceMode has no cross-session triage.

## Rounds

- Round 1 proposer (opus) dispatched with placement as the core question.

## Mid-round user direction: interaction style (2026-09-29)

Relayed to the round-1 proposer:
- Drop full input-echo + mandatory confirmation. Converser compiles/cleans speech into the outgoing message, echoes that, sends without asking; confirms only on incongruity/ambiguity.
- Corrections are follow-on utterances; the history view exists for interpretability and after-the-fact correction.
- Human-like prose and formatting in both directions; represent the speaker's meaning and style directly, avoid agent-to-agent house style.
- Deferred: seeding with earlier typed messages; voice fingerprinting; other audio-in security, provenance, speaker attribution.
- Proposal must state the residual risk this accepts honestly (ambient/injected speech relayed without confirmation) and the cheap mitigations left.

## Round 1

- Proposer superseded rather than evolved: new `cdocs/proposals/2026-09-29-converser-host-voicemode-serve.md` (9d818e1); old marked `evolved` (1264c82).
  Mid-run style direction arrived after the first draft; proposer resumed to fold it in (1bbae27).
- Placement: systemd `--user` template supervises; lace binds (port, token, `pasta` forward, RO token mount); clauthier plugin holds behaviour (agent, skill, hooks), default-disabled and force-enabled via container-local managed settings; thin lace feature only at packaging.
- Fresh opus reviewer dispatched for round 1.
- Round-1 review (4a878d9): **revise**. Blocking: numeric `wait_for_conch` overrides the conch timeout (re-opens #522); whisper's `0.0.0.0` bind is hardcoded, so loopback rebind needs a durable mechanism plus a firewalld layer.
  Confirmed: placement split, 60s HTTP MCP timer, `crossSessionInbound` scope, `EnvironmentFile` precedence, serve token/port. Gate (t) largely settled by the plugins/org docs.
- Round-2 revision sent to the warm proposer (moderate changes, same author).

## Round 2

- Revision abc2dae: own loopback whisper/Kokoro units + firewalld reject layer; conch parameter floor (`wait_for_conch` boolean, no `hold_conch`); `ExecStart=/usr/bin/env` pins; checkpoint step 1.4a; gates (p)-(t) defined; step 1.0 time-boxed with whisper-only fallback.
  Author defaults: send-then-readback; stage-1 TTS optional at first checkpoint; `runArgs` as uncommitted local edit (lace has no local devcontainer override).
- Fresh opus reviewer dispatched for round 2.

## Mid-round user direction (during round-2 review)

Queued for the round-2 revision:
- Relay history entries are labelled by Claude Code session name (or an inferred label) plus number, not number alone.
- Confirmation is intent verification, not security: comprehension/sensibility first. Truly destructive actions ask unless the user explicitly signals intent ("destructively", "force remove ..."). Resolves open question on destructive-command confirmation.
- Accepted risk confirmed: treat the audio stream like a keyboard for now.
- Packaging is the proposal's to sort out. VoiceMode's packaging looks awkward (hand wiring of host units, loopback rebinds); a self-contained lace devcontainer feature that mitigates that would be good, if feasible. The proposal should evaluate honestly how much host-side wiring lace can absorb vs. what must stay manual.
- Follow-up on packaging: don't involve lace initially. Explore cleaning up/bundling VoiceMode's host-side install as a self-contained package (e.g. a Linuxbrew formula/tap or install script) that installs whisper/Kokoro/serve as a host-side service with our loopback/token/tool-scoping defaults. Generalized lace host-side service hooks are later work.
- Round-2 review (7fda61c): **accept**, non-blocking N1-N7 (N1: upstream installers auto-enable 0.0.0.0 units and restart them; mask + `--no-auto-enable` + firewall-first).
  Acceptance overtaken by the user direction above; round-3 revision sent to the warm proposer: N1-N7 plus labels, intent-verification confirmation, keyboard framing, and packaging restructure (self-contained host package, e.g. Linuxbrew; lace out of near-term plan; lace host-service hooks to Future Work).

## Round 3

- Revision ef286c1 (full rewrite, retitled "converser: a host voice service and an in-container voice session"): self-contained `converser-host` script package (install / instance add / status / model set / uninstall) with firewall-first, `--no-auto-enable`, masked upstream units; script over brew formula (core whisper.cpp bottle lacks whisper-server; Python apps; `brew services` not per-instance); recommended repo `weftwiseink/converser-host`; labels, intent-verification confirmation, keyboard framing folded in; lace host-service hooks in Future Work.
- Fresh opus reviewer dispatched for round 3.
- Round-3 review (edc4fa7): **revise**. F1: `mask` fails over existing upstream unit files (verified systemd 259); delete + daemon-reload + mask. F6: token handoff must go via stdin (`podman exec -i`), ideally an `instance handoff` subcommand. N1-N7 resolved; plugin-scope claims re-verified live.
- Round-4 revision sent to the warm proposer (small, targeted).

## Round 4

- User direction: no new repo; `converser-host` (small shell CLI + unit templates wrapping VoiceMode's upstream install) lives in the clauthier converser plugin at `plugins/converser/host/`, run from the checkout.
- Revision (5084878, 8c5431f): F1 delete + daemon-reload + mask; F6 `instance handoff` stdin pipe; stage-1 vs 3b command split; early stop check; whisper-server built against brew ggml; firewall as backstop, runtime + permanent without reload; ExecStartPre empty-token check; placement moved to clauthier.
- Fresh opus reviewer dispatched for round 4.
- Round-4 review (40d0ce7): **revise**. F1/F6 verified (scratch systemd root; transient units). New blocker: brew whisper.cpp 1.9.4 bottle already ships `whisper-server` (build flag inert), so `brew install whisper.cpp` replaces the build step. r3 had checked the flag, not the bottle.
- Round-5 revision sent to the warm proposer.

## Round 5

- Revision 65ec5a3: whisper via `brew install whisper.cpp` + `brew pin` + model download (VoiceMode's whisper installer never runs); N3-N9 addressed.
- Fresh opus reviewer dispatched for round 5.
- Round-5 review (8ca444d): **accept**, status `implementation_ready`. Accept-round nits R1-R4 (stale build wording; curl token via `-K -` stdin; Kokoro unit WorkingDirectory/Restart=always/request limit and literal-host guard; pin llama.cpp, throwaway serve on 8800 with temp state, handoff omits `-u`) resolved in 1602119.

## Outcome

Accepted proposal: `cdocs/proposals/2026-09-29-converser-host-voicemode-serve.md` (supersedes `2026-09-28-converser-lace-feature.md`, kept as fallback).
Placement: `converser-host` shell CLI + units in clauthier `plugins/converser/host/` (run from checkout, not wired into the plugin runtime); container side = one `runArgs` line + clauthier converser plugin (stage 3); lace host-service hooks are Future Work.
Next: stage 1 (`converser-host install` on this host; needs the user's sudo for firewall rules), then checkpoint 1.4a.
