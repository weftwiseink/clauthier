---
review_of: cdocs/reports/2026-09-26-voice-companion-architecture.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-26T14:13:27-07:00
task_list: cdocs/audio-interaction
type: review
state: live
status: done
tags: [fresh_agent, architecture, factual_accuracy, bridge_design, experiment_design, plain_language, brevity]
---

# Review: Voice-companion architecture

## Summary Assessment

The report reframes voice interaction around the user's vision: a fast conversational front (the "talker"), the `/oversee` session doing the work (the "thinker"), and a state model plus bridge between them.
It engages the clunkiness diagnosis directly and does not drift back to input-precision patches; the six-part diagnosis is the strongest section.
It has three structural gaps.
First, it misses Claude Code's own supported state feed, `claude agents --json`, which reports which session is waiting on the user and why.
Second, it recommends `claude -p --resume` against a live overseer as a way to write answers back, which the docs say interleaves transcripts.
Third, the thin-to-thick section never lays out "separate app vs MCP tool vs thin translation layer" as the user asked, so it cannot say which option fixes which problem.
The first experiment has a confound, and its falsifier ("still feels clunky") is not measurable.
Verdict: **Revise**.

## Minor fixes applied directly

Each was checked against a primary source during this review:

- **Weftwise stack:** "built on Y.js/Liveblocks/CodeMirror" became "Loro CRDTs and CodeMirror (it has migrated off Y.js/Liveblocks)". `package.json` runs a `check:no-yjs` gate, the packages are `loro-multiplex` and `loro-repo`, and authorship attribution still exists (`branch_attribution.tsx`, `loro-repo`).
- **VoiceMode listen window:** "default max around 30s, per issue #532" became "2s min / 120s max per the converse parameters reference". Issue #532 is about the hard cut at the maximum and does not state the default.
- **VoiceMode endpointing:** it is WebRTC voice-activity detection (VAD) tuned by `vad_aggressiveness`. The `listen_duration_*` settings only bound the recording window; they are not the endpointer.
- **Moshi:** latency is now "160ms theoretical / ~200ms practical on an L4" and VRAM "24GB unquantized PyTorch per Kyutai's README, with lighter int8 builds". The third-party "~16GB fp16" figure was removed, along with its Unverified-list entry.
- **Unmute:** the claim that it is compatible with "tool-calling" was wrong. The README says tool calling is not implemented and asks for contributions. It also needs a CUDA GPU with 16GB+ of VRAM.
- **Concurrent resume:** the docs do address this. The sessions page says resuming the same session in two places without forking makes "messages from both interleave into one transcript". The Agent SDK bullet is corrected and the "no doc confirms or denies" entry is removed from the Unverified list.
- **Hard gates:** "a scheduling conflict, a proposal too vague to run" became the actual hard gates from `oversee/SKILL.md`: a `reject` verdict, an unresolvable footprint conflict, and deciding the proposal set for `full <topic>`.
- **Jargon:** S2S, STT, TTS and VAD are now spelled out at first use. The link text `getvoicemode.com` became `voicemode.dev` to match its URL.

## Section-by-Section Findings

### BLUF and Context

The BLUF is honest and matches the body.
The framing correctly separates `/voice` (dictation) from VoiceMode's `converse` and names the prior report's failure without dwelling on it.
No issues beyond the jargon expansions above.

### Diagnosing the clunkiness

This is the best part of the report and it answers the user's "endemic clunkiness" point on its own terms.
Two refinements:

- **Non-blocking:** the diagnosis mixes two kinds of cause and should say so.
  Turn-taking, barge-in and latency are fixed by the *audio stack*: the endpointing model, the duplex transport and echo cancellation.
  Coupling and the missing shared state are fixed by the *architecture*: the talker/thinker split and the state view.
  The recommendation's hypothesis depends on keeping these apart (see the experiment findings).
- **Non-blocking:** echo cancellation is missing from the diagnosis.
  Barge-in over laptop speakers needs acoustic echo cancellation (AEC), for example PipeWire's `echo-cancel` module or a headset.
  Without it the assistant hears itself and interrupts itself.
  This is a large source of real-world clunkiness on a Fedora desktop.

### What refined voice looks like today

The spot-checks mostly held up:

- **VoiceMode:** a single primary `converse` tool, with local whisper.cpp and Kokoro via OpenAI-compatible endpoints. The blocking character is inferred from the tool shape rather than stated in the README.
  - **Non-blocking:** `wait_for_response=false` turns `converse` into speak-only. That weakens "every `converse` invocation freezes the whole agentic loop" for announcements.
  - **Non-blocking:** Claude Code now auto-backgrounds any MCP tool call that runs longer than 2 minutes (`CLAUDE_CODE_MCP_AUTO_BACKGROUND_MS`). That changes the blocking-tool analysis in both the latency paragraph and the MCP-bridge bullet.
- **OpenAI `semantic_vad`:** correct. The `eagerness` options are low, medium, high and auto.
- **Pipecat Smart Turn:** correct. It judges from audio (a Whisper-Tiny base with a classifier, about 8M parameters) and runs after Silero VAD detects silence.
- **LiveKit turn detector:** correct at 135M parameters, based on SmolLM v2 and working from text over the last four turns. It is text-based, so it inherits STT latency; worth one clause.
  The claim that adaptive interruption is cloud-gated is confirmed by issue #6033.
- **Anthropic speech-to-speech:** "no public developer S2S API" is consistent with everything found. The TechCrunch article confirms the stack is undisclosed.
- **Non-blocking:** the comparison table's "Unmute: yes" for barge-in is not supported by Unmute's README. Mark it unverified or remove it.
- **Non-blocking (brevity):** VoiceMode's blocking, silence-timeout behavior is described four times: the walkie-talkie paragraph, the latency paragraph, "VoiceMode MCP, in depth", and the table.
  The framework and full-duplex prose largely restates the table.
  Keep the table plus one line of caveats per row and cut this section by roughly 40%.

### The architecture the user is imagining

1. **Blocking: the report misses `claude agents --json`, Claude Code's own supported "what's running / what's waiting on me" feed.**
   - The agent-view docs call it "the supported way to read session state from outside Claude Code, for example from a status bar". It reports `state` (`working`, `blocked`, `done`), `status`, and `waitingFor` (`permission prompt`, `input needed` for a question from Claude or an MCP server, `sandbox request`, `dialog open`).
   - `claude logs <id>` prints a session's recent output, and agent view's peek panel already accepts dictated replies.
   - This directly contradicts the report's statement that softer questions "only surface as an in-session question or a Claude Code `Notification` hook".
   - It is the thinnest possible read feed for the talker. It requires running `/oversee` as a background session (`claude --bg`), which the report should state as a condition.
   - Fold it into "What state the companion reads", the thin-to-thick options, and the first experiment.

2. **Blocking: the "how answers get back in" analysis lists four mechanisms but not which ones work against a *live* overseer.**
   - `claude -p --resume <id>` against a running `/oversee` session interleaves into one transcript. The live process does not see those messages, and the transcript gets corrupted. Yet options (b) and (c) and the Recommendation all name "`claude -p --resume` polling" as the write-back.
   - Resume with `--fork-session` is safe, but only for *read-only* questions ("summarize where you are").
   - **Channels** is the only documented push into a live session. It has three constraints the report omits:
     - A custom channel must be loaded with `--dangerously-load-development-channels` during the preview, because `--channels` only accepts allowlisted plugins.
     - Events queue while Claude is mid-turn and arrive on the next turn, so reply latency is bounded by the overseer's turn length.
     - Channels can declare a *permission relay* capability that forwards permission prompts to the channel. That is exactly the "make user-facing requests legible" hook the vision needs.
   - **Missing option: the companion hosts the overseer.** Instead of a sidecar attaching to someone else's session, the companion *is* the harness. It runs `/oversee` through the Agent SDK with streaming input, and receives every permission request and `AskUserQuestion` through the SDK's in-loop user-input callbacks. This is the cleanest answer to "bridge to the overseer session to make user-facing requests legible".
   - **Wording error:** the MCP bullet conflates two things. Elicitation dialogs are answered *in the Claude Code terminal*, so they do not route to a companion. What the report describes is simply a tool whose call blocks while the companion collects an answer, and that call is subject to the 2-minute auto-backgrounding.
   - Restructure the bridge section as a small matrix: mechanism × (read or write) × (works against a live session?) × maturity.

3. **Non-blocking:** the plain-language descriptions of the arc-state file, devlog handoff and escalations are good and accurate against `oversee-arc.md` and `orchestration-discipline.md` Pillar 2.
   Remaining unexplained terms: `fork_session`, "elicitation", "footprint conflict", "Haiku-class".
   The "talker/thinker" label would benefit from a citation. DeepMind's Talker-Reasoner paper ("Agents Thinking Fast and Slow", 2024) is the closest prior art. Also note the name clash with Qwen2.5-Omni's internal Thinker-Talker, which means something different.

4. **Non-blocking:** "triages context" in the user's vision is underdeveloped.
   The report covers what the talker *reads*, but not its policy for *when to speak up unprompted*. Key questions: what interrupts the user, how several blocked items are batched and prioritized, and what stays silent until asked.
   A deliberate budget for unprompted speech is a large part of what makes a voice assistant feel refined rather than chatty. Give it a short subsection.

### Thin to thick: four build options

5. **Blocking: the options do not map onto the user's actual question ("separate app vs MCP tool vs thinner translation layer").**
   - (a) and (b) are both "VoiceMode plus Claude-as-talker". (b) in particular spends a second full Claude session as secretary, which is heavier than a real thin layer and still inherits walkie-talkie turn-taking.
   - Absent entirely are the two options the user named:
     - **Thin translation layer:** a small sidecar that polls arc-state, the latest handoff and `claude agents --json`, and speaks through a Pipecat pipeline. It reads with forked resumes and replies through a custom Channel, or by having the human answer in the agent-view peek panel.
     - **MCP tool / channel as the product surface:** the companion exposed to the overseer as a Channel with reply and permission-relay tools.
   - Also absent is the SDK-hosted overseer from finding 2.
   - Replace the prose effort/fixes paragraphs with one table: option × {turn-taking, barge-in, latency, coupling, state legibility, request legibility} × effort. This answers "what each can and can't fix" in a scannable way.
   - It will also show that the audio problems are fixed by the Pipecat/LiveKit choice in *any* sidecar option. They are not unique to the weeks-long option (c).

6. **Non-blocking:** option (d) calls itself the most speculative, but Weftwise already has a proposal pointing this way.
   `weftwise/main/cdocs/proposals/2026-08-24-cm-native-claude-code-interface.md` (status `wip`) proposes running a headless Agent SDK session behind a host-agnostic session interface inside CodeMirror.
   That is the SDK-hosted bridge from finding 2, in Weftwise, already being designed. Cite it.
   It makes (d) less speculative and suggests the companion's state view and harness could converge there instead of in a throwaway standalone window.

7. **Non-blocking (Fedora/Wayland):** option (c)'s "simple always-on-top status window" is not generally available to regular clients on GNOME Wayland.
   KDE can do it via window rules; GNOME needs an extension. Alternatives are a panel indicator or notifications.
   Say which surface is intended, or pick a browser tab or Weftwise pane.

### Recommendation / first experiment

8. **Blocking: the experiment has a confound, and its falsifier is not measurable.**
   - It allows "VoiceMode's own local backends ... *or* a small Pipecat pipeline with Smart Turn". These test different things.
   - With VoiceMode, turn-taking stays silence-based, so a "still clunky" result cannot separate "the state model doesn't help" from "turn-taking is still bad".
   - **Fix:** pick Pipecat + Smart Turn + a Haiku model, and point it at VoiceMode's already-installed OpenAI-compatible whisper.cpp and Kokoro servers. That reuses the setup cheaply as intended. Use a headset (or enable AEC).
   - Feed it arc-state, the latest handoff, and `claude agents --json`.
   - Make the comparison attributable: run it with Smart Turn on and off (a config toggle), and against a baseline of plain VoiceMode inside the overseer.
   - Define the falsifier before running it: over two or three real `/oversee` arcs, count
     - how often the user breaks out to the terminal to check state,
     - how many re-asks and restatements there are,
     - time-to-first-audio,

     plus a 1-5 felt-refinement score per session against the baseline, with thresholds written down in advance.
   - Read-only is the right scope for step one. Name the write-back next step concretely (a custom Channel), not "Channels or `claude -p --resume` polling".

### Unverified claims

9. **Non-blocking:** the star-count bullet is not flagged inline anywhere and does not bear on any conclusion. Drop it.
   Two entries were removed as fixed (see above).

### Frontmatter

10. **Non-blocking:** `first_authored.at` (15:30) is later than this review (14:13) on the same day. Probably a clock or timezone slip; worth correcting.

## Verdict

**Revise.**
The report does engage the user's vision and the clunkiness diagnosis, and it is a large improvement over its predecessor.
Four structural problems must be fixed before it can guide a build decision:

- the missing `claude agents --json` state feed,
- a write-back recommendation that the docs show would interleave transcripts,
- a thin-to-thick section that does not map onto the user's app / MCP / thin-layer framing,
- an experiment whose outcome cannot be attributed.

## Action Items

1. [blocking] Add `claude agents --json` (and `claude logs`, agent-view peek-reply with dictation) to the state section as the supported "waiting on you" feed. Note that `/oversee` must run as a background session. Correct the claim that soft questions only surface in-session.
2. [blocking] Rewrite "How answers get back in" as a matrix: mechanism × read/write × safe against a live session × maturity.
   - Mark `claude -p --resume` without fork as unsafe against a live overseer; forked resume is read-only.
   - Add the Channels constraints: development-channel flag, events queued to the next turn, permission relay.
   - Add the Agent-SDK-hosted overseer option.
   - Fix the elicitation conflation and mention MCP auto-backgrounding.
3. [blocking] Restructure the thin-to-thick section around the user's three named options: thin translation sidecar, MCP/Channel surface, standalone app, plus Weftwise. Include an option × problem table showing what each fixes and what it cannot. Remove "`claude -p --resume` polling" as a write-back everywhere.
4. [blocking] Pin the first experiment to Pipecat + Smart Turn + Haiku on VoiceMode's local servers with a headset. Add the Smart Turn on/off and VoiceMode-baseline comparison, and write concrete, pre-registered falsifier metrics.
5. [non-blocking] In the diagnosis, separate audio-stack causes from architecture causes, and add acoustic echo cancellation.
6. [non-blocking] Add a short "triage policy" subsection: when the talker speaks unprompted, how it batches and prioritizes, and what stays silent.
7. [non-blocking] Cite `weftwise/main/cdocs/proposals/2026-08-24-cm-native-claude-code-interface.md` in option (d) as existing Agent SDK hosting work.
8. [non-blocking] Resolve the always-on-top surface for GNOME Wayland, or pick a different surface.
9. [non-blocking] Cut the refined-voice section to the table plus caveats, dedupe the four VoiceMode descriptions, and drop the star-count bullet.
10. [non-blocking] Mark the table's Unmute barge-in cell unverified. Add the `wait_for_response=false` nuance. Note that the LiveKit detector is text-based and inherits STT latency.
11. [non-blocking] Explain or cut `fork_session`, "elicitation", "footprint conflict" and "Haiku-class". Cite Talker-Reasoner prior art and note the Qwen-Omni name clash.
12. [non-blocking] Fix the `first_authored.at` timestamp.

## Questions for the user

1. Which bridge direction should the revision favor?
   - (A) Sidecar companion that attaches to an overseer you launch yourself (Channels plus `claude agents --json`).
   - (B) Companion *hosts* the overseer through the Agent SDK. It is cleaner, but you would stop launching `/oversee` from a normal terminal.
   - (C) Keep both and let the experiment decide.
2. For the first experiment, are you willing to use a headset? The alternative is getting PipeWire echo cancellation working first, which is needed for barge-in over speakers.
   - (A) Headset is fine.
   - (B) Speakers required; include the AEC setup in the experiment.
3. Should Weftwise be the state surface from day one, given the existing `cm-native-claude-code-interface` proposal, or stay deferred?
   - (A) Defer until the standalone slice is proven.
   - (B) Build the state view as a Weftwise pane from the start.
   - (C) Revisit after that proposal lands.
