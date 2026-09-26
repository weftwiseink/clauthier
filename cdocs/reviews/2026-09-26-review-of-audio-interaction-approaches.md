---
review_of: cdocs/reports/2026-09-26-audio-interaction-approaches.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-26T16:30:00-07:00
task_list: cdocs/audio-interaction
type: review
state: live
status: done
tags: [fresh_agent, rereview_agent, factual_accuracy, citations, hooks, oversee_grounding, recommendation_fit, brevity]
---

# Review: Audio interaction approaches for a cdocs power user

## Summary Assessment

The report surveys direct voice paths into Claude, breaks voice-to-agent lossiness into three failure modes, and sketches a user-facing "secretary" layer that mirrors `/oversee`.
The failure-mode framing is sound, and the `/voice` survey matches the official docs closely.
Three problems are load-bearing.
First, the central hook claim is wrong: `UserPromptSubmit` cannot rewrite a prompt, so Option 2 and the mermaid input path do not work as written.
Second, the secretary is cast as a dispatched `resume-by-name` specialist, which contradicts the no-nested-dispatch rule and cannot talk to the human.
Third, the recommendation skips the precision worry the user actually raised, and misses plan mode and Channels, two first-party mechanisms that serve the pattern directly.
Verdict: **Revise**.

## Verification Performed

- `code.claude.com/docs/en/voice-dictation`: hold/tap modes, `autoSubmit`, the 3-word rule, coding-vocab hints, cloud-only transcription, claude.ai-auth requirement, no SSH/cloud support, the Linux native-module/`arecord`/`rec` fallback, 15s silence / 2 min limit, 20 languages, and agent-view peek-and-reply dictation. All **confirmed**.
- `code.claude.com/docs/en/hooks`: `UserPromptSubmit` decision control is `decision: "block"`, `additionalContext`, and `systemMessage` only, with **no `updatedInput` or prompt-replacement field**. The 30s default for command hooks on `UserPromptSubmit` is confirmed (lowered from 600).
- `code.claude.com/docs/en/remote-control` and settings reference: no voice input, "Push when Claude decides" / "Push when actions required", `agentPushNotifEnabled`, and subagent/workflow progress sync all **confirmed**.
- GitHub issues via `gh`: #31599 is open and correctly described. #93778 is open but is an edit-discard bug, not an accuracy issue. #96353 is an open **feature request about the Desktop app's dictation**, not a `/voice` bug. #50720 is closed `NOT_PLANNED` on 2026-06-08. #29399 is closed as a duplicate. `anthropic-sdk-python#1198` is **closed `NOT_PLANNED` on 2026-08-06**, not open.
- Talon: OSnews (2026-05-31, [link](https://www.osnews.com/story/145162/accessibility-input-tool-removes-x11-support-doesnt-want-to-support-wayland-users-caught-in-the-middle/)) reports the maintainer's announcement that Linux support is being removed from public releases and that Wayland is not planned. KDE developers dispute the technical reasoning, not whether the announcement was made.
- The chief-of-staff cookbook exists. It delegates via `Task`, and `permission_mode="plan"` appears only as an optional, commented-out line. The top-level agent also uses Bash/Read/Write directly, so "never does task work itself" is overstated.
- `salimfadhley/agent-inbox` exists, and the "a running LLM turn cannot be interrupted from outside" quote is accurate. arXiv 2607.21268 (pAI-Econ-claude) exists and is on-topic.
- The oversee mechanics were checked against `plugins/cdocs/skills/oversee/SKILL.md`, `template.md`, `rules/oversee-arc.md`, and `rules/orchestration-discipline.md` (see findings 2 and 4).

## Section-by-Section Findings

### BLUF and Key Findings

1. **[blocking] `UserPromptSubmit` "can inject context or block/modify the prompt" is false.**
   Per the hooks reference, the hook can block, add `additionalContext`, or show a `systemMessage`. It cannot replace the prompt text, so Claude always sees the raw transcript.
   This error spreads to the BLUF recommendation ("a `UserPromptSubmit` cleanup hook"), the mermaid edge `B -->|UserPromptSubmit hook: cleanup| S`, the building-block table row, and Option 2 ("rewriting obvious mishears before Claude sees the prompt... transparently").
   A silent rewrite would also cut against the user's control worry: it hides "what got heard" versus "what will be acted on", which is the separation the BLUF says is missing.
   Workable variants: (a) inject `additionalContext` like "possible mishears: `oath` -> `OAuth`; repo symbols: ...", so Claude sees both the raw and the suggested text; or (b) block with a `systemMessage` that shows the corrected text for the user to re-submit, which is a real review gate.
   Also note that the hook input does not say whether a prompt was dictated, so the "scope to voice input" idea needs a user-typed marker.

2. **[blocking] Several citations are misdescribed.**
   - #96353 is a Desktop-app dictation *feature request*, filed against the Claude desktop app rather than `/voice`.
   - #93778 is an edit-loss bug.
   - Neither issue reports "dropped/substituted words" or "accuracy regressions", which is how the Key Findings bullet and the survey table's `/voice` row describe them.
   - `anthropic-sdk-python#1198` is closed as not planned, but the report calls it "open" in Key Findings and Open Questions.
   - Soft/hard gates are attributed to `rules/oversee-arc.md`, but the distinction lives in `skills/oversee/SKILL.md` ("AFK and Escalation Gates"). `oversee-arc.md` does not define it.
   - The chief-of-staff cookbook is described as a top-level agent that "never does task work itself" and "uses `permission_mode="plan"`". Plan mode is optional in that notebook, and the chief does do direct work.
   - Once fixed, drop the "not independently re-verified" caveats in Key Findings and Open Questions, because the issue numbers themselves check out.

3. **[non-blocking] Talon can be resolved rather than left "unverified".**
   The drop announcement is reported by a named secondary source that cites the maintainer, and the KDE dispute is about the reasoning, not the fact.
   For this user it doesn't matter either way: Talon is X11-only, and the user runs GNOME on Wayland.
   Say plainly that Talon is not viable on this machine today. Keep it only as design prior art for deterministic formatters.

### Why Voice-to-Agent Is Lossy

4. **[non-blocking] The irreversibility framing contradicts the report's own `/voice` findings.**
   Failure mode 3 says "voice interfaces mostly skip [the review step]", and the affordance table says "nothing currently separates typing from submission for voice specifically".
   But the report establishes that `/voice` hold mode, the default, waits for `Enter`.
   The honest residual gap is narrower: the review surface is raw text with no structure or diff, and the dimmed-then-finalized transcript can change at finalize (the Desktop-app FR #96353 describes this same two-pass proofreading burden).
   Reword so the doc doesn't argue against itself. The Context paragraph likewise states the user's perception ("they lack a review step") as fact, and the BLUF then contradicts it.

### Direct Approaches Survey

5. **[non-blocking] Wayland caveats are missing for the whisper.cpp wrappers.**
   Typing into the focused window on Wayland needs `ydotool` (uinput permissions) or `wtype`, and `wtype` does not work on GNOME/Mutter, which lacks the virtual-keyboard protocol.
   So "Linux (X11/Wayland)" and Option 1's "available today with no engineering" are optimistic for this user.
   Fedora's `ibus-speech-to-text` avoids this because it is an input method. It is the more natural "Option 1" on Fedora GNOME and deserves the mention.
   Also, for the Claude Code terminal specifically, Option 1 is strictly worse than `/voice` hold mode except on offline operation and privacy. Say that tradeoff explicitly.

6. **[non-blocking] The TTS row's Piper link text and URL disagree.**
   The text names `OHF-Voice/piper1-gpl`, but the link points to `github.com/rhasspy/piper`.

### The Secretary Pattern

7. **[blocking] Casting the secretary as a durable `resume-by-name` specialist contradicts orchestration discipline.**
   Pillar 3 specialists are subagents *dispatched by* an overseer.
   A dispatched subagent cannot dispatch its own workers (no nested dispatch, per `orchestration-discipline.md` and the `/oversee` "TOP-LEVEL ONLY" note), and it cannot hold a live conversation with the human.
   Yet the mermaid diagram has `S` dispatching to the agent team and exchanging `SendMessage` with it, and it has `S` talking to `Human`.
   A human-facing secretary must therefore be a **top-level session**: either the user's own session, with `/oversee` running in a separate top-level session, or a separate process. The two sessions would coordinate over the file bus (arc-state, escalations, pause) and/or Channels (finding 9).
   Option 5 does gesture at this ("careful scoping... nested-dispatch problems"), but the building-block table asserts the opposite.
   This is the main architectural claim of the section, so it must be internally consistent.

8. **[blocking] The escalation-triage return path is not grounded in actual oversee semantics.**
   - The pause marker is a human-to-overseer STOP: `SKILL.md` says the human drops it, and the overseer checks it at each gate and clears it on acknowledgement. A secretary "clearing" it does not unblock anything. A hard-gate `hold` stops the arc, and it resumes only when the human answers in a live overseer session or runs `/oversee resume`.
   - Escalation markers are written **only at hard gates**: a `reject`, a footprint conflict, or scoping the proposal set. Soft gates in non-AFK runs surface as in-session questions and never reach `.claude/oversee/escalations/`. So a read-only watcher sees only the rarest class of event.
   Option 4 needs to state this coverage limit and name the in-session channel (the `Notification` hook and "Push when actions required") that covers the rest.
   Item 3's "routing the human's answer back" needs a real mechanism: `/oversee resume` or a Channels injection.

9. **[blocking] Two first-party mechanisms that directly serve the pattern are missing.**
   - **Plan mode** is Claude Code's built-in "compile, show, approve, then act" gate. `/voice` hold mode plus plan mode already gives rambling speech, then a structured plan, then explicit approval before any tool acts. That is exactly the "cursor still blinking" moment and the slot-filling step the affordance table marks "Not found in any surveyed tool" / "No consumer tool found". The report mentions plan mode only inside the cookbook description.
   - **[Channels](https://code.claude.com/docs/en/channels)** (research preview) are two-way MCP bridges that push messages into an already-running session, with optional permission-prompt relay. That is the missing return leg for a secretary: an answer from phone or chat lands in the live overseer session. `agent-inbox`'s wake-not-interrupt design is independent prior art for the same idea.
   Add both to the mechanics table and the options.

10. **[non-blocking] Prior art carries loose analogues.**
    The "Loose, non-agent-team-facing analogues" paragraph (Speakwise, Otter, Marblism, Lindy) adds little and could be cut to a single sentence.
    The spoken-programming research paragraph is useful but could be two sentences.

### Options and Recommendations

11. **[blocking] The recommended first experiment does not address the user's stated worry.**
    The user's complaint is precision and control on the *input* side.
    The report recommends Option 4 (read-only escalation digests) first, which is a reasonable, low-risk experiment but does nothing for dictation precision. It defers the input side as "adopt piecemeal".
    A minimal, zero-infrastructure input experiment exists and should lead, or at least be co-first: `/voice` hold mode plus plan mode, or a tiny `/brief` skill/command that turns the dictated text into intent / constraints / open questions and waits for approval without calling any tools.
    That directly tests the "compile, don't relay" hypothesis at near-zero cost.
    Option 4 can stay as the output-side companion, with its coverage limit (finding 8) stated.

12. **[non-blocking] Option 3 says "nothing in the current toolset provides this out of the box".**
    Reconcile this with plan mode, and with the `Ctrl+G` external-editor path if you want a richer staging buffer.

### Open Questions

13. **[non-blocking] Several items become stale after the verification above.**
    The Talon, issue-number, and SDK-#1198 items should be resolved or removed.
    The "Lost in Transcription" arXiv note documents something the report does not cite. Delete it rather than preserve a disclaimer.

### Length and Brevity

14. **[non-blocking] The report is about 4,566 words, and about 1,200-1,500 could go without losing substance.**
    - Key Findings restates most of the survey table row by row: `/voice` over three bullets, Claude.ai voice, Remote Control twice, GNOME/Fedora, the commercial tier, Talon, and realtime APIs. Keep about 5 synthesis bullets and let the table carry per-tool detail.
    - The oversee escalation substrate (path, fields, pause marker) is described four times: Key Findings, secretary item 3, the mechanics table, and Option 4. Say it once.
    - The "no public audio API" point appears in both Key Findings and Open Questions.
    - The TTS survey row is peripheral and could shrink to a single line.

## Verdict

**Revise.**
The survey groundwork is solid, but the hook claim is factually wrong, the secretary's placement in the orchestration model contradicts the repo's own rules, and the recommendation does not target the precision/control worry that motivated the report.
All of these can be fixed without restructuring the document.

## Action Items

1. [blocking] Correct every `UserPromptSubmit` claim (BLUF, Key Findings, mermaid, mechanics table, Option 2): it can block, add `additionalContext`, or show a `systemMessage`, but never rewrite. Recast Option 2 as annotate-via-context or block-and-show-correction, and note that the hook input has no voice-origin signal.
2. [blocking] Fix citations: #96353 is a Desktop-app FR, #93778 is an edit-loss bug, and neither is about "dropped/substituted words". `anthropic-sdk-python#1198` is closed not-planned. Cite soft/hard gates to `skills/oversee/SKILL.md`. Soften the chief-of-staff description (plan mode is optional, the chief does direct work). Remove the "not re-verified" caveats.
3. [blocking] Re-place the secretary as a top-level session (not a dispatched `resume-by-name` specialist) coordinating with a separate `/oversee` session over files and/or Channels, and make the mermaid, mechanics table, and Options 4-5 consistent with that.
4. [blocking] Ground the triage return path: the pause marker is a human-to-overseer STOP cleared by the overseer, hard-gate holds resume via a live answer or `/oversee resume`, and escalation markers cover hard gates only. State Option 4's coverage limit and name `Notification` / "Push when actions required" for soft-gate and in-session prompts.
5. [blocking] Add plan mode, as the existing compile-and-approve gate, and Channels, as the two-way push-into-live-session return path, to the mechanics table and options. Correct the affordance-table "not found" cells accordingly.
6. [blocking] Revise the recommended first experiment to lead with, or co-lead with, a zero-infrastructure input-side test (`/voice` hold + plan mode, or a no-tools `/brief` command), keeping Option 4 as the output-side companion.
7. [non-blocking] State plainly that Talon is not viable on Fedora GNOME/Wayland, cite the OSnews report, and drop the Open Question.
8. [non-blocking] Reconcile the irreversibility framing with `/voice` hold mode's Enter gate, and frame the Context paragraph's claims as the user's perception.
9. [non-blocking] Add Wayland input-injection caveats (`ydotool`/`wtype`, Mutter) to the whisper-wrapper row and Option 1, and promote `ibus-speech-to-text` as the Fedora-native Option 1.
10. [non-blocking] Fix the Piper fork link/text mismatch.
11. [non-blocking] Cut about 1,200-1,500 words: collapse Key Findings to about 5 synthesis bullets, describe the escalation substrate once, trim the loose-analogues paragraph and the TTS row, and remove stale Open Questions (including the "Lost in Transcription" note).

## Questions for the Author/User

1. Where should the secretary live?
   (a) The user's own top-level session, with `/oversee` in a second terminal.
   (b) A standalone process (a channel server plus local STT) that injects into sessions via Channels.
   (c) A Remote Control / mobile-first surface, with `/oversee` sessions pushing notifications.
2. For input cleanup, which control model is preferred?
   (a) Annotate only: Claude sees the raw text plus suggested corrections.
   (b) A block-and-confirm gate that shows the corrected text for re-submit.
   (c) Plan-mode compile-then-approve, with no cleanup hook at all.
3. Is cloud transcription acceptable, given that `/voice` and all commercial tools send audio off-machine, or should the report weight local-only options (IBus/Vosk, whisper.cpp) more heavily?

## Round 2

> Reviewed 2026-09-26T17:45:00-07:00 by @claude-opus-5-5 (`rereview_agent`) against the revised report (~3,850 words, new "Decision Points for the User" section).

### Round-1 Action Item Status

1. **Resolved, with a correction applied by the reviewer.** The report no longer claims a prompt rewrite. However, it described blocking as `permissionDecision` (`allow`/`deny`), which does not apply to `UserPromptSubmit`.
   Per the hooks reference "UserPromptSubmit decision control", this hook blocks via top-level `decision: "block"` plus `reason`. The `reason` is shown to the user and is not added to context, and blocking erases the prompt. `additionalContext` goes under `hookSpecificOutput`.
   `permissionDecision` belongs to the tool-permission events (`PreToolUse`, `PermissionRequest`, and similar).
   The reviewer fixed the field names in Key Findings, the mechanics table, and Option 3.
2. **Resolved, with one wording tweak by the reviewer.** #96353 is now framed as a desktop FR, #1198 as closed not-planned, soft/hard gates are cited to `SKILL.md`, the chief-of-staff description is softened, and the caveats are removed.
   The survey table still grouped #96353 under "open bugs", and the reviewer reworded it.
   The reviewer also removed a revision-meta phrase ("this distinction lives in that skill file, not in `oversee-arc.md`").
3. **Resolved.** A new Placement paragraph, mermaid diagram, mechanics table, and Options 4-5 consistently cast the secretary as a second top-level session.
4. **Resolved.** The pause marker is correctly a human-to-overseer STOP, escalations are described as hard-gate-only, the Notification/push path is named, and the return path is `/oversee resume` or Channels.
5. **Resolved, with a caveat added by the reviewer.** Plan Mode and Channels are added, and the claims were verified (`Shift+Tab`, the `/plan` prefix, `Ctrl+G`, Channels as two-way with permission relay).
   The reviewer added one sentence: per the permission-modes docs, in interactive terminal sessions where bypass permissions is available, Plan Mode's edit blocks are not enforced.
   That matters for this user's control worry, since the gate is only advisory in a bypass-capable setup.
6. **Resolved.** The recommendation now co-leads with options 1+2 on the input side, with option 4 as the output-side companion.
7. **Resolved.** Talon is stated as not viable, citing OSnews.
8. **Resolved.** Failure mode 3 is reframed as "thin review, not absent review", and the Context paragraph is framed as the user's perception.
9. **Resolved.** The Wayland `ydotool`/`wtype` caveat is added and `ibus-speech-to-text` is promoted. The reviewer also dropped "local" from the Option 1 heading, because `/voice` is cloud-transcribed.
10. **Resolved.** The Piper link now points to `OHF-Voice/piper1-gpl`.
11. **Partially resolved.** The report went from about 4,566 to about 3,850 words. The escalation substrate is no longer repeated four times, and the stale Open Questions are gone.

### New Findings (all non-blocking)

1. **The revision-history `NOTE` callout under the BLUF breaks history-agnostic framing.** It enumerates what "this revision corrects". The review file already carries that history. Consider deleting the callout.
2. **The Placement paragraph over-attributes a claim.** It credits `orchestration-discipline.md` with "a dispatched agent cannot hold an open-ended conversation with the human", but that rule file covers no-nested-dispatch, not human interaction. Either drop the citation for that half of the sentence or cite the harness behavior generically.
3. **"The GNOME Shell extensions avoid this by running in-process"** (whisper-wrapper row) is plausible but unverified. Soften it or verify it against the Blurt and Speech2Text source.
4. **Remaining trim candidates.** The first Key Findings bullet is about 190 words and restates the `/voice` survey row. The Prior art section is a single dense paragraph that could lose the consumer-product sentence. About 300-500 more words could go.

### Round-2 Verdict

**Accept.**
All round-1 blocking items are resolved.
The one factual slip introduced in revision (`permissionDecision` for `UserPromptSubmit`) and three wording issues were minor, so the reviewer fixed them directly in the report rather than requesting another round.
The four items above are optional polish.

### Reviewer Edits Applied to the Report

- Key Findings, hook bullet: replaced `permissionDecision` (`allow`/`deny`) + `systemMessage` with `decision: "block"` + user-facing `reason`, plus `additionalContext`. Replaced the non-sequitur "which also means the hook input carries no voice-origin signal" with a separate sentence.
- Key Findings, oversee bullet: removed the revision-meta parenthetical about `oversee-arc.md`.
- Key Findings, Plan Mode bullet: added the bypass-permissions enforcement caveat.
- Survey table, `/voice` row: #96353 reworded from "open bugs" to "a related desktop-app feature request".
- Mechanics table and Option 3: corrected the hook field names.
- Option 1 heading: "Zero-engineering local capture" became "Zero-engineering capture".
- Frontmatter: `last_reviewed` set to `accepted`, round 2.
