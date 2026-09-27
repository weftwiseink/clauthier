---
review_of: cdocs/reports/2026-09-27-conversationalist-bridge-design-questions.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-27T11:25:45-07:00
task_list: cdocs/audio-interaction
type: review
state: live
status: done
tags: [fresh_agent, source_verification, docs_verification, hooks, devcontainer, askuserquestion, incrementalism]
---

# Review: conversationalist bridge design questions

## Summary Assessment

The report answers five follow-up questions about a VoiceMode "conversationalist" session that relays to `/oversee` sessions over native cross-session messaging, and it ends with a minimal v0.
The VoiceMode reading (Q0) and the devcontainer empirics (Q1) are careful and mostly accurate.
Three of its load-bearing *rejections* do not hold up against the docs and the binary, though:
- It rejects the `Stop` hook for turn-end reporting because of an "unverified" cross-socket path. The docs describe that path, and the parent reports already rely on it.
- It rejects `PreToolUse` handling of `AskUserQuestion` by misreading third-party bug reports. It also misses the documented `allow` + `updatedInput.answers` mechanism.
- Its v0 quietly drops overseers that run inside lace containers. It also cites the PID-namespace question as "not a blocker", which the docs' send-side endpoint checks contradict.

Verdict: **Revise**. The fixes are local to Q1, Q3, Q4 and the v0 section. The report does not need a rewrite.

## Verification performed

- Pulled `code.claude.com/docs/en/{cross-session-messaging,hooks,errors,channels}.md` raw.
- Read `lace/main/devcontainers/features/src/claude-code/devcontainer-feature.json`.
- Inspected `~/.claude/sessions/3002342.json`, `podman inspect weftwise`, and `podman exec weftwise` (read-only).
- Grepped the installed `claude` binary (2.1.283) for the inbox-socket code paths.
- Read `build/research/voicemode` at `126d15e` for the conch and control-channel claims.
- Fetched the three cited GitHub issues with `gh api`.

## Section-by-Section Findings

### BLUF

It restates the Q3 and Q4 rejections, so it inherits findings 1 and 2.
"Denial-reason propagation is unreliable today" and "`Stop` has no verified path into another session's socket" are both wrong as stated (see below). **Blocking**, fixed together with findings 1 and 2.

### Q0: audio-out and the conch

The claims are accurate against source.
- The `conch.py:1-4` docstring and `Conch` at `:102` are correct.
- The control states are at `control_channel.py:44-51`.
- The `converse()` conch params are at `converse.py:2948-2951`.
- The `voice` and `speed` params are at `:546/:551`.
- PRIVACY is at `:3080`.

The recommendation to keep audio-out single-source is sound.

- **Non-blocking (finding 4).** The hint table (`CONTROL_INTENTS`) is at `control_channel.py:103-108`, not `:96-104`. Lines 90-102 are the security comment.
- **Non-blocking (finding 5).** The "unverified `wait_for_conch=false` fallback" is resolvable from the tool's own docstring, `converse.py:3026-3029`: *"false: If another agent is speaking, return a status immediately WITHOUT queuing ... The status names the holder and tells you how to queue."*
  The cited `3115-3151` range is only argument parsing.
  Remove the item from the Unverified list and from Empirical test 2.
- **Non-blocking (finding 6).** "All four need the control channel" contradicts the same sentence's statement that per-source mute is a skill-level policy with no VoiceMode equivalent. Say "three of four".

### Q1: devcontainers

These parts are verified:
- The lace `claude-code` feature declares exactly two mounts: `~/.claude` and `~/.claude.json`. Neither is `/run/user/1000`.
- The registry entry for `3002342` carries `messagingSocketPath: /run/user/1000/cc-socks/3002342.sock` and a foreign `pidDomain`.
- `podman inspect weftwise` gives `PidMode: private` and `UsernsMode: private`.
- Inside the container, `3002342.sock` exists. On the host it does not.
- The quoted docs line is verbatim, from "Message sessions on other machines": *"A session inside a container and a session on the host can't reach each other."*

The core finding stands. Three problems:

- **Blocking (finding 3a): "PID-namespace liveness is not a blocker" is unsupported, and probably false for `SendMessage`.**
  The docs' errors page ("Refusing to send a cross-session message") lists sender-side endpoint checks:
  - `connected endpoint is not the expected process`
  - `connected endpoint identity could not be read`
  - `connected endpoint is not owned by this user`

  Across a private PID namespace, the host sees the container process under a different PID than the registry's `3002342`.
  Under rootless-podman userns remapping, the owner check can also fail.
  So even with `/run/user/1000/cc-socks` bind-mounted, a host `SendMessage` would plausibly be refused at the sender. That reads as the *mechanism* behind the docs' flat "can't reach each other", not just mount topology.
  The binary also carries explicit foreign-PID-domain handling (`foreign_pid_space`, `isHeldInAnotherPidDomain`), so the report's "it's the mount topology, not the liveness logic" is an overclaim.
  Reframe the mount "fix" as unlikely to work for `SendMessage`, by design.
- **Blocking (finding 3b): the SELinux concern is mis-aimed.**
  Connecting to a unix socket is governed by `unix_stream_socket connectto` between the two *process* domains (`container_t` to the host's `unconfined_t`), not by file relabeling.
  This is the `docker.sock`/`podman.sock` precedent, which on Fedora typically needs `--security-opt label=disable`.
  A raw `socat` post from a hook would skip Claude Code's sender checks but would still hit this.
- **Non-blocking (finding 3c): "own-child ... directly addresses lace's shape" is inaccurate.**
  Claude Code is not PID 1 in lace containers. `weftwise`'s PID 1 is an `sh -c` init loop, so on Linux Claude has `/proc` process evidence for its own children and the token fallback does not apply.
  Also, the `weftwise` container user is `node` (uid 1000), not `ubuntu`, which reads as general to lace. Say which container the `ubuntu` observation came from (`jif`).
- **Remote Control fallback.** The report correctly marks it unverified.
  Add one risk: the host sees the container session's entry in the *shared* `~/.claude/sessions` registry. It may pick the local-socket route and never try Remote Control routing.
  The docs' table routes "another of your machines" via Remote Control, but the shared registry makes the container look local-ish.
  Add this to Empirical test 1: check whether the container session appears once as `Remote Control` or twice.

### Q2: specialist subagent per session

The reasoning is sound, and the orchestration-discipline citations check out: Pillar 3 at `:162`, the single-writer by-construction note at `:189`, and the trivial few-liners carve-out at `:29`.
The docs confirm that `notify_when_idle` and peer delivery target the main conversation.
Subagents are reachable only from inside their own session.
"Ledger file, no specialists" is the right v0.

- **Non-blocking (finding 7).** Add the constraint that actually bounds this design.
  Messages are read "between tool calls during an active turn". While the conversationalist's top level is blocked inside a long `converse()` listen, overseer messages queue no matter what the subagent topology is.
  A specialist cannot shorten that wait. That further supports skipping specialists, and it belongs next to the latency argument.

### Q3: turn-end context flow

- **Blocking (finding 1): the rejection of `Stop`/`Notification` hooks rests on a mischaracterized gap.**
  - The docs' inbox-socket section opens with: *"Read this section ... when you want a script or hook to post into a session"*.
  - It says every socket post goes through the same inbound controls, with the own-child *exception*. That exception is only meaningful if non-child processes post: *"When Claude Code can verify neither way, it treats the message like any other that asserts no permission class."*
  - Nothing in the docs restricts a poster to its own session's socket. The auth-line *token* is scoped to own-session posting, and the auth line is optional on Linux.
  - The parent reports already build on this path. The deep-dive's hotkey wake path is a non-child script posting into the conversationalist's socket, and the messaging report's "direct inbox-socket posting" row covers the same thing. This report's "unverified" is internally inconsistent with its own arc.
  - The residual gap the parent flagged, the message-line wire format, is printed by the binary's own `--debug` log on inbox start: `{ echo '{"type":"auth",...}'; echo '{"type":"user","message":{"role":"user","content":"hello"}}'; } | socat - UNIX-CONNECT:<sock>`. That is from `claude` 2.1.283, via the `[uds-messaging] Inject messages` log line.
  - `Stop` input does include `last_assistant_message`, per the hooks docs: *"use this field rather than reading `transcript_path`"*.

  So a `Stop` hook in the overseer can post the turn's final text into the conversationalist's socket for zero overseer tokens, with the path published by a conversationalist `SessionStart` hook exactly as in the deep-dive.
  The `SendMessage` convention, by contrast, is model-dependent and spends overseer tokens every turn.
  The report must re-evaluate with the real tradeoffs:
  - `Stop` fires on every overseer turn, including each subagent-completion wake in an AFK arc. It needs a filter: post only on a marker, only when the turn ends in a question, or rate-limit, or else let the conversationalist triage.
  - A raw post carries no harness sender name or reply address, so the hook must stamp `From: <overseer name>`.
  - Delivery depends on the conversationalist's `crossSessionInbound: "accept"`, which the deep-dive already sets.
  - It does not cross the lace boundary, the same limitation as `SendMessage`.

  Likely outcome: a `Stop` hook as primary turn-end push (deterministic, cheap, richer payload), with the explicit `SendMessage` convention reserved for things the model judges worth saying: findings, decisions, questions.
  At minimum, present them as peers and move the hook cross-socket test from "load-bearing gap" to "confirm with one `socat` post".
- **Non-blocking (finding 8).** "`Notification` is observational only" conflates two things. It cannot inject into its *own* session, but its script can post to another socket exactly like `Stop`'s can. Its payload is thinner, so the conclusion to prefer `Stop` stands; the stated reason does not.
- **Non-blocking (finding 9).** The `notify_when_idle` cost is understated.
  Each notice *starts a turn* in the idle conversationalist, which then spends a turn re-subscribing.
  Under `hold` on either side, the one-line status is dropped.
  If a `Stop` hook is adopted, `notify_when_idle` becomes redundant for hook-equipped overseers.

### Q4: AskUserQuestion relay

- **Blocking (finding 2): the evidence is misread, and the documented mechanism is missed.**
  - Hooks docs, PreToolUse decision control: `permissionDecisionReason` is *"For `"deny"`, shown to Claude."* Exit-2 blocking routes stderr to Claude the same way.
  - [claude-plugins-official#4260](https://github.com/anthropics/claude-plugins-official/issues/4260) is a bug in the **hookify plugin**, which omits `permissionDecisionReason` in its deny branch. The issue itself cites the docs saying the field reaches the model. It is not evidence that Claude Code drops reasons.
  - [nimbalyst#1577](https://github.com/nimbalyst/nimbalyst/issues/1577) is a rendering bug in **Nimbalyst's Electron UI**, not the Claude Code terminal. It explicitly says "Claude Code honours the deny (the tool result is an error and the agent re-asks)".
  - [CodeIsland#340](https://github.com/wxtsky/CodeIsland/issues/340) is a *closed* bug in a third-party bridge. The docs list `AskUserQuestion` as a PreToolUse matcher target outright, so no empirical detour is needed for "matchable".
  - **Missed:** the docs document answering `AskUserQuestion` from a hook. `permissionDecision: "allow"` plus `updatedInput` that echoes `questions` and adds `answers: {"<question>": "<label>"}` runs the tool without prompting. The `allow` row states that `AskUserQuestion` needs `updatedInput` paired with it. The report's "Not exposed ... by any mechanism found" is therefore wrong.
    A relay hook fits within the 600s default command-hook timeout, which is configurable. It posts the question to the conversationalist's socket, waits on a reply file, and returns `answers`. That is the real v1 relay path, and it keeps the overseer's native tool.
    Caveat: `defer` is `-p`-only, so it is not an option for interactive overseers.
  - A cheap middle option also exists: a roughly 10-line `PreToolUse` deny hook, active only when a conversationalist socket is published. Its reason says "a voice conversationalist is attached; `SendMessage` the question to it instead". This enforces the v0 convention deterministically rather than hoping the skill text is followed.

  The v0 choice of convention may still be right for dev time, but the report must give the correct reasons.
  It should present the three tiers: convention, deny-redirect hook, and `updatedInput.answers` relay.
- **Non-blocking (finding 10).** "1-8 questions/call" conflicts with the hooks docs' "one to four multiple-choice questions". Cite a source or correct it.
- **Non-blocking.** The permission-laundering analysis is good.
  One addition for the `updatedInput.answers` tier: the overseer sees a normal tool result, not a message framed as "from another session". The hook should therefore prefix answers, for example `"<label> (relayed by voice conversationalist; user said: '...')"`, to keep provenance visible.

### Recommended minimal bridge v0

- **Blocking (finding 3, v0 half).** Item 2, "run the conversationalist on the bare host", silently scopes v0 to host-run overseers.
  The user's live `weftwise` session runs inside a lace container, so v0 as written does not reach it.
  The v0 must say so explicitly and pick a stance. Options, cheapest first:
  - (a) Run voice-attached overseers on the host.
  - (b) A file relay through the one thing lace already shares, the `~/.claude` bind mount. The container overseer's `Stop` hook writes to `~/.claude/conversationalist/inbox/`, and a host-side watcher posts raw lines into the conversationalist's socket. The reverse direction needs a tiny container-side poster into the overseer's local socket. This uses only documented socket posting and the existing mount, with no SELinux socket work.
  - (c) Remote Control on both ends, unverified; see Q1.
- Items 4 and 5 should follow the outcomes of findings 1 and 2. "No hooks" is a dev-time choice, not a capability constraint, and the report should say so.
- **Non-blocking.** State the conversationalist's `SessionStart` socket-path publication as a shared prerequisite. Hooks, hotkey, and relay all need it, and it is the single piece of plumbing that v0 should build regardless.

### Empirical tests and Unverified claims

- Test 2 is resolved by finding 5.
- Test 3 shrinks to a single `socat` post of the known line format into a scratch session.
- The "Stop/Notification cross-socket" and "denial-reason propagation" unverified items should be rewritten per findings 1 and 2.
- Add: "whether a host `SendMessage` to a bind-mounted container socket would pass the sender endpoint checks" (finding 3a).

### Conventions

- **Non-blocking (finding 11).** Most sections are multi-sentence paragraphs; writing conventions call for one sentence per line.
- **Non-blocking.** `first_authored.at` (15:40 -07:00) is later than this review's time (11:25 -07:00), which suggests clock or timezone drift in the authoring agent.

## Verdict

**Revise.**
Q0 and Q2 are essentially acceptable. Q1's empirical core is verified.
The report's v0 is currently justified by three incorrect or incomplete claims:
- the cross-socket hook gap
- AskUserQuestion denial and relay
- PID namespaces as a non-blocker, plus the unstated exclusion of container overseers

Correcting them may or may not change the v0 picks, but the tradeoffs have to be stated correctly for the user to decide.

## Action Items

1. [blocking] Q3/BLUF: Replace "Stop has no verified path into another session's socket" with the documented socket-posting model: non-child posters are handled by inbound controls, and the wire format is `{"type":"user","message":{"role":"user","content":...}}` per the binary's debug log. Re-weigh the `Stop` hook with `last_assistant_message` against the `SendMessage` convention on token cost, determinism, noise filtering, and sender stamping.
2. [blocking] Q4/BLUF: Correct the issue readings. #4260 is a hookify bug, #1577 is a Nimbalyst UI bug, and the docs state that a deny reason is shown to Claude. Add the documented `allow` + `updatedInput.answers` path, and present the three tiers: convention, deny-redirect hook, and answer-relay hook.
3. [blocking] Q1/v0: Drop "PID-namespace liveness is not a blocker" and cite the errors-doc sender endpoint checks. Retarget the SELinux concern to `connectto`. Make v0 state that lace-contained overseers are out of reach, and give the cheapest options for them (host-run overseers, a `~/.claude` file relay, or Remote Control).
4. [non-blocking] Fix the `CONTROL_INTENTS` citation to `control_channel.py:103-108`.
5. [non-blocking] Resolve `wait_for_conch=false` from `converse.py:3026-3029`. Remove it from the unverified list and from Empirical test 2.
6. [non-blocking] "All four need the control channel" becomes "three of four" (per-source mute is policy).
7. [non-blocking] Q2: note that inbound messages queue behind a blocking `converse()` listen regardless of specialist topology.
8. [non-blocking] Q3: correct the `Notification` reasoning (it can post like `Stop`, but has a thinner payload), and state `notify_when_idle`'s per-notice turn cost.
9. [non-blocking] Q1: correct the "own-child PID 1 addresses lace" claim (lace PID 1 is an `sh` init), note that the `weftwise` user is `node`, and add a registry-collision check to the Remote Control test.
10. [non-blocking] Q4: reconcile "1-8 questions/call" with the docs' "one to four".
11. [non-blocking] Reflow to sentence-per-line, and check the `first_authored.at` timestamp.

## Questions for the user

1. Where do voice-attached overseers run?
   (a) Always on the host. v0 as written suffices.
   (b) Often inside lace containers such as `weftwise`. v0 needs a cross-boundary option.
   (c) Both. Start host-only and add a `~/.claude` file relay later.
2. Turn-end push mechanism for v0?
   (a) `Stop` hook posting `last_assistant_message` (deterministic, zero overseer tokens, needs filtering).
   (b) `SendMessage` convention in `oversee/SKILL.md` (model-judged, costs overseer tokens).
   (c) Hook for status, convention for findings and questions.
3. AskUserQuestion handling for v0?
   (a) Convention only.
   (b) Convention enforced by a deny-redirect `PreToolUse` hook.
   (c) A full relay hook that answers via `updatedInput.answers` (most dev time, keeps the native tool).
