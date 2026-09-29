---
review_of: cdocs/reports/2026-09-28-converser-options-vetting.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-28T11:13:16-07:00
task_list: voice/converser-lace-feature
type: review
state: live
status: done
tags: [fresh_agent, security, isolation, messaging, cross_report_consistency, empirical_verification]
---

# Review: converser options vetting

> BLUF(opus/voice/converser-lace-feature): **Revise.**
> The report's headline correction is right and well evidenced: `label=disable` is a devcontainer CLI default on every podman container, recorded in audit F8, and the proposal's "real new cost" framing is false.
> Four blocking problems remain.
> (1) The "any boundary kills messaging" generalization ignores documented Remote-Control-routed `SendMessage`.
> (2) The separate-OS-user rejection contradicts the report's own own-child analysis: an in-container own-child poster makes a separate UID workable *and* removes the forced-bypass converser.
> (3) Amendment 5's "skip converser-triggered turns" would drop the overseer's answer to the user's own spoken request.
> (4) The report does not flag that the broker report's SELinux gain is void, and it does not reconcile its prototype with the broker's host-`serve` first experiment.

## Summary Assessment

The report is a skeptical vetting of the accepted `converser` proposal: it audits assumptions, adds missing considerations, answers "why do permissions matter", evaluates a separate OS user, and proposes 12 amendments.
Evidence discipline is strong: labels are used consistently, and every live and source claim I re-ran held (see Verification Log).
The weak points are in reasoning, not facts.
Two conclusions about isolation are stated more absolutely than the docs and the report's own Section 3 support.
One amendment is actively harmful, and the cross-report picture is left unreconciled on exactly the point the report is best placed to settle.
Verdict: **Revise**.

## Verification Log

All checks were read-only, or ran in a throwaway user namespace under `/tmp`.

| Claim | Result | Evidence |
|---|---|---|
| 1. CLI 0.87.0 injects `label=disable` (`devContainersSpecCLI.js:473`) | **Holds** | `devcontainer` resolves to linuxbrew 0.87.0. Line 473 holds `s9()`, which returns `["--security-opt","label=disable"]` for every `isPodman && linux` container, plus `--userns=keep-id` only when the remote user is non-root and no `--uidmap`/`--gidmap` is set. `SecurityOpt: ["label=disable"]` appears on all five running containers (whelm, jif, weftwise, dioxus, clauthier). `ps -eZ`: 5 `claude` processes are `spc_t` |
| 1b. Audit F8 exists and says this | **Holds** | lace repo: `cdocs/reports/2026-09-06-sandbox-containment-security-audit.md:202-210`. It covers all four containers then running and names the CLI default as the origin |
| 1c. "All four review rounds missed it" | Holds, understated | Round 1 (`review-of-converser-lace-feature.md:43-45,81`) *asserted the opposite*: it grepped `devcontainer.json` and ran a scratch container, never `podman inspect` on the live ones. Round 2 (`:50`) then marked "`label=disable` is a new cost" as resolved |
| 2. `jif` pulse works; monitors exposed | **Holds** | `pactl info` in jif gives `Server Protocol Version: 35`. `pactl list short sources` lists 5 `.monitor` sources plus mics. jif **already** file-mounts `/run/user/1000/pulse/native` (inode 42, same as host) |
| 3. 12s tier-3 infeasible | Holds, partly grounded | `SILENCE_THRESHOLD_MS=1000` is sourced (`voice_mode/config.py:949`). Other stages are unmeasured, but even an optimistic floor (~3s converser wake + ~5s speaking the question + ~2s think/answer + 1s VAD + ~0.5s STT + ~3s mapping turn ≈ 15s) exceeds 12s, so the conclusion is robust. Missing: `DEFAULT_LISTEN_DURATION=120s` (`config.py:955`) means a converser mid-listen may not read the question for up to 2 minutes |
| 4. Stop-hook volume | Reproduces | My recount over the 40 newest transcripts: active weftwise overseers peak at 24-30 main-chain `end_turn`/hour, typical active sessions at 8-16. The "×5 = 50-150/hour" figure assumes coincident peaks, so it is an upper bound |
| 5. File vs directory bind on restart | **Holds, now verified** | `unshare -Urm` test: after unlink-and-rebind of the source socket, the file bind gives `ConnectionRefusedError` and the directory bind gives `OK`. Caveats: this assumes `pipewire-pulse` does not rmdir `pulse/` (unverified). `Linger=no`, so a full logout tears down `/run/user/1000` and breaks both styles |
| 6. Separate OS user blocked | Socket facts hold; conclusion overreaches | `srw------- node` confirmed. Docs: "restricts the socket to your operating-system user"; no documented socket mode, group, or directory setting. But see F2 |
| 7. Any boundary kills messaging | **Overstated** | Docs (cross-session-messaging, "Message sessions on other machines"): `SendMessage` reaches "Remote Control sessions on other machines" "through Anthropic servers". See F1 |

## Section-by-Section Findings

### BLUF and Section 1 (assumption audit)

**F0 (non-blocking) A14 is correct and the report's best contribution.**
Add two details.
First, `s9()` is unconditional for podman on Linux, so no project `runArgs` removes it: podman receives the CLI's flag before `runArgs`, and override semantics are untested.
Second, round 1 actively asserted the false claim after grepping config rather than inspecting runtime state.
That is the transferable lesson: check `podman inspect`, not `devcontainer.json`.
The BLUF phrase "(verified/source and live)" should read "(verified/source, verified/live)".

### Section 2 (missing considerations)

**F5 (non-blocking) Pulse inode pinning is now verified. Upgrade the label, and add three caveats.**
(a) jif already carries the file mount, so the flaw is live today, not hypothetical.
(b) The directory fix assumes `pipewire-pulse` recreates only the socket, not the directory, and a logout (`Linger=no`) defeats both mount styles.
(c) "The same flaw affects `wayland-0`" is true, but the fix does not transfer: `wayland-0`'s parent is `/run/user/1000` itself, which cannot be bind-mounted without colliding with container-local `cc-socks`.
A compositor restart usually means a session restart anyway.

**F6 (non-blocking) Latency table.**
The tier-3 chain is argued in prose with no per-stage rows, which is why "20-40s" reads as asserted.
Add the tier-3 stages to the table, and state the floor argument: even optimistic figures exceed 12s.
Also add the 120s listen-window blocking (`DEFAULT_LISTEN_DURATION`) next to the "two overseers ask at once" bullet.
That bullet is the stronger form of the problem, since a single question can also wait behind an open listen.

**F7 (non-blocking) Volume.**
Label 50-150/hour as a coincident-peak upper bound.
Also note that peak-hour sessions in the sample are largely user-driven, and the user is at the keyboard for those turns.

### Section 2b (why permissions matter)

This section answers the user's question well.
The class-laundering and cross-overseer-laundering analysis is correct and matches the docs' own-child and "asserts no permission class" text.
"Permission mode is not the control, tool surface is" is right for the converser *as actor*.

**F2 (blocking) The separate-OS-user rejection contradicts the report's own mechanism.**
Row H relies on the docs' own-child exemption: when no `crossSessionInbound` value applies, a message the receiver verifies came from its own child processes is delivered.
On Linux, the receiver verifies by process evidence.
Here `claude` is not PID 1 (verified: PID 1 is the devcontainer `sh` loop), so that evidence is available.
The separate-user table then says a non-Claude `node`-side relay's posts "carry no permission class and bypass overseers hold them".
That is wrong for a relay that is each overseer's own child, which is exactly H's poster, run inside the container.
The design:
- a `SessionStart`-spawned poster per overseer (uid `node`) reads a group-writable inbox directory and posts to its parent's socket;
- a mirror poster under the converser (uid 1001) reads a directory the `Stop` hook writes.

That restores both directions across a UID boundary, and the converser **no longer needs bypass**.
The report's own analysis says forced bypass is the root of its exposure.
The costs match H's: anything that can write the inbox directory gets delivered, and routing uses the relay's own names, not `ListAgents`.
Revise the verdict row, and soften 2b's closing claim that "*no* process-level boundary can sit between converser and overseers, and tool-surface restriction is the only isolation available".
Keep "reject for v0" if desired, but on cost grounds (two relay processes, a new inbox-injection surface), not on "can't".

A lesser missed option, worth one line: a same-UID OS sandbox for the converser (bubblewrap without PID-namespace unsharing, or Landlock) preserves native messaging.
It can hide the workspace, AWS credentials, nvim data, and dotfiles.
It cannot hide `~/.claude` (auth, registry, transcripts), and since the converser already lacks file tools, it is defense in depth against a tool-restriction bypass only.
Group-shared sockets are not an option: no documented setting exists, and Claude Code refuses directories another user owns.

### Section 3 (alternatives)

**F1 (blocking) The "any boundary breaks messaging" generalization, and row H's "only workable relay", miss Remote-Control-routed messaging.**
The docs list "Your Remote Control sessions on other machines" as `SendMessage` targets, delivered "Through Anthropic servers, arriving over that machine's Remote Control connection".
They also list cloud sessions.
The "container and host can't reach each other" sentence describes the local socket path.
Whether a host converser can reach an RC-connected in-container overseer as an "other machine" is **unverified**, not ruled out.
The same question applies to a separate-UID converser.
The docs' Remote Control page also says each interactive process registers its own remote session under auto-connect, and server mode runs up to 32.
Unknowns worth a gate:
- whether same-host container sessions appear as distinct machines;
- how a bypass receiver classes a cross-machine message (hold or deliver);
- in-container RC (already flagged unverified).

Costs: traffic leaves the host through Anthropic servers, it needs a claude.ai login in every overseer, and `isolatePeerMachines` interacts with it.
Scope the BLUF and 2b to "the local socket transport", and add this path to row H as an unverified variant with a Phase 0 spike.

**F8 (non-blocking) RC row accuracy.**
"Low: one session at a time" is wrong per the docs' "Limitations": one remote session *per interactive process*, with auto-connect for every session and server mode for many.
Also mention `CLAUDE_CLIENT_PRESENCE_FILE` (Remote Control page, push notifications).
It is a first-party presence marker that bears directly on the presence-gating question in the latency section and amendment 3.

**F4 (blocking) Cross-report consistency: the broker report's SELinux gain is void, and the report should say so.**
The broker report claims its split means the container "never runs with `label=disable`, SELinux type enforcement stays intact" (`host-audio-broker-split.md:41,64,73,145-146,158`).
Given A14, that half of the gain is zero: every container keeps `label=disable` regardless.
The broker's real remaining gain is removing the pulse socket: mic capture, **monitor-source capture** (this report's own privacy finding), and plausible module loading.
This report's evidence *strengthens* that gain.
The report describes the broker accurately ("removes the pulse socket"), but as the only document holding the A14 evidence, it should state the correction explicitly, so the broker report gets fixed.

**F3a (blocking, same item) Prototype ordering conflicts across the three reports.**
- This report's Phase 0.5 hand-wires *in-container* VoiceMode, adding the pulse mount to weftwise.
- The broker report's smallest experiment is `voicemode serve` *on the host* with an unmodified weftwise container.
- The fork report recommends upstream-as-is over HTTP, which is the same host-`serve` shape.

The three agree on "experiment before lace feature" but not on which experiment.
The host-`serve` experiment also avoids four of this report's own concerns: the pulse inode flaw, monitor-source exposure, multi-container double capture, and one of the two in-container install surfaces.
Its known limit, the one-client conch wedge (#521/#522), is harmless for a one-project prototype.
Either justify in-container first (for example, `converser-io` write-scoping needs a local process) or reorder.
"P remains the cheapest path to hearing something" should be weighed against the broker report's "hours to a day, config only".

### Section 4 (risk register, gates, amendments)

**F3 (blocking) Amendment 5 and gate (k): "skip turns triggered by converser messages" breaks the core use case.**
When the user speaks a request, the converser relays it, and the overseer's resulting turn-end *is the answer the user is waiting to hear*.
Dropping it silences voice exactly when it matters.
It is also not implementable as stated: `Stop` input carries no "triggered by" field, so the hook would need to parse the transcript.
Replace it with these, relying on the docs' loop throttling as a backstop:
- the converser never acknowledges status posts (already in amendment 6);
- the hook drops only a turn whose `last_assistant_message` is short and content-free;
- or the converser suppresses speech for posts that answer nothing it asked.

**F9 (non-blocking) Amendments are mostly proportionate but internally inconsistent and unstaged.**
- (g): amendment 1 says "remove Phase 0(g)", while "Phase 0 gates missing" says "(g) **Replace**" with a `SecurityOpt` check. Pick one. The check is trivial, so fold it into (a).
- (h) and (l) exist only for tier 3, which amendment 3 defers. Move them with tier 3.
- (m) needs two containers, which contradicts the one-container Phase 0.5. Defer it to post-prototype.
- Amendments 7, 8, 10, and 11 (flock, stable names, `status` subcommand, recurring canary) are packaging-phase concerns. A one-week prototype needs 3, 4, 5 (guards), 6, 9, and a trace file. Tag each amendment "prototype" or "packaging" so the list reads as a sequence rather than 12 co-equal prerequisites.

No amendment contradicts another beyond (g) and F3.

**Recommendation follows?**
Mostly.
"Amend, prototype first" follows from the dominant uncertainties: latency, volume, and whether voice gets used at all.
But "the core bet survives vetting" is asserted before F1 and F2's alternatives are weighed.
Both of those can remove the forced-bypass converser, which the report itself identifies as the root exposure.

## Verdict

**Revise.**
Resolve F1-F4, including F3a.
The factual core (A14, A13/A15, monitor sources, inode pinning, volume) is sound and should be kept as is.

## Action Items

1. [blocking] Scope the BLUF, 2b's closing rule, and row H's "only workable relay" to the local socket transport. Add Remote-Control-routed `SendMessage` (host or separate-UID converser to RC-connected in-container overseers) as an unverified variant, with a Phase 0 spike covering container-as-machine visibility and bypass-receiver hold behavior (F1).
2. [blocking] Rewrite the separate-OS-user table's "Replace or complement?" row and verdict. An in-container own-child poster relay (process evidence works since `claude` is not PID 1) restores both directions and removes the converser's bypass requirement. Reject it for v0 on cost, not feasibility, if at all. Add one line on the same-UID bwrap/Landlock option and its `~/.claude` limit (F2).
3. [blocking] Replace amendment 5's and gate (k)'s "skip converser-triggered turns" with ack suppression that preserves replies to user-originated requests (F3).
4. [blocking] State explicitly that the broker report's "`label=disable` removed, SELinux intact" gain is void under A14, and that its remaining gain (pulse socket, including monitor sources) is strengthened by this report. Reconcile Phase 0.5 (in-container) against the broker and fork reports' host-`voicemode serve` first experiment, and justify or reorder (F4, F3a).
5. [non-blocking] Resolve the (g) remove-vs-replace inconsistency. Move gates (h) and (l) with deferred tier 3, and (m) to post-prototype. Tag amendments as prototype or packaging (F9).
6. [non-blocking] Upgrade inode pinning to verified (namespace test in this review). Note that jif already has the file mount, add the directory-recreation and logout (`Linger=no`) caveats, and note that the `wayland-0` fix does not transfer (F5).
7. [non-blocking] Add tier-3 rows and the floor argument to the latency table, and the 120s `DEFAULT_LISTEN_DURATION` blocking (F6).
8. [non-blocking] Label 50-150 wakes/hour as a coincident-peak upper bound (F7).
9. [non-blocking] Fix the RC row's "one session at a time", and cite `CLAUDE_CLIENT_PRESENCE_FILE` as a first-party presence signal (F8).
10. [non-blocking] In A14, note that `s9()` is unconditional and that round 1 grepped config instead of inspecting runtime. Fix the "(verified/source and live)" wording (F0).

## Questions for the User

1. Which first experiment should the arc run?
   (a) This report's in-container hand-wired prototype.
   (b) The broker report's host `voicemode serve` with an unmodified container.
   (c) (b) first, then (a) only if a local `converser-io` process proves necessary.
2. Given F2, is a non-bypass converser worth a v0 spike?
   (a) Yes, the in-container own-child relay with a separate UID.
   (b) Yes, but same-UID own-child relay only (no second login).
   (c) No, keep the bypass converser with the tool-surface restriction for v0.
3. Should RC-routed messaging (F1) get a Phase 0 spike, given it sends inter-session traffic through Anthropic servers?
   (a) Yes. (b) Only if (2a/2b) fail. (c) No, local-only by policy.
