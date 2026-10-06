---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-10-06T11:07:01-07:00
task_list: cdocs/rules-context-decomposition
type: report
state: live
status: wip
tags: [orchestration_discipline, durable_specialists, context_budget, agent_memory, rules]
---

# Durable Specialists and Removed Guidance: Rules-Context-Decomposition Audit

> BLUF: The rules-context decomposition (`209ec08..6c6f5cc`) cut always-loaded rules from 797 to 297 lines (2,145 words), and almost every cut is traceable to an explicit decision in the proposal or its input review; the undocumented-loss bucket (c) is small, limited mainly to a quantified dispatch heuristic in `workflow-patterns.md` that predates any incident.
> "Durable specialist" (Pillar 3, added 2026-09-01 in `04ba25d`) was deliberately compressed to one clause in `orchestration-discipline.md` "Stay thin" (line 9) and its vocabulary was deliberately erased (the proposal's own dead-reference grep checks for zero hits of "Durable Specialist"); the substance (named `SendMessage`-resumed subagent, `fork` for side-questions) survives, the one-per-workstream bound and the "satisfies single-writer by construction" cross-link do not.
> The maintainer's cap-and-restart idea already exists, unbuilt: `cdocs/reports/2026-09-20-token-spend-by-role.md` workstream 4 proposed a ~0.2-0.6M token cutoff in September, and `cdocs/proposals/2026-09-22-chat-record-devlog-management.md` Phase 3 ("Cap-and-reseed durable specialists", line 542) is gated on an unresolved RFP.
> Dispatched implementers write no Scratchpoint today (`orchestration-discipline.md:32`, `devlog/SKILL.md:43`, `implement/SKILL.md:85` all say "keeps none"); per maintainer direction mid-report, the recommended fix generalizes Scratchpoint ownership from "the devlog" to "the section you own", so an implementer keeps one inside its own `### Implementer Notes`.
> The harness signal for "~250K context" is `totalTokens` on the dispatch result (`subagent_tokens` on the async notification surface): a devlog measurement confirms it reflects the agent's final-turn usage, not a cumulative sum across turns, so it is already the resident-context reading the new rule needs, with no extra instrumentation.

## Context / Background

A `/cdocs:full-send` loop (`cdocs/proposals/2026-10-05-rules-context-decomposition-rfp.md`) compressed the always-loaded cdocs rules per the review `cdocs/reviews/2026-10-06-review-of-overseer-rules-simplification.md`.
The diff spans `209ec08` (first compression commit) through `a57c78e`, plus three nits in `127c312..31cd610`; current `HEAD` is `6c6f5cc`.
Net change across `plugins/cdocs/rules/`, `skills/`, `agents/`, `README.md`: 24 files, +172/-986 lines.
The maintainer is concerned that "durable specialist" guidance went missing and is designing a cap-and-restart rule for a warm subagent observed at ~250K+ context, triggering this audit.

## 1. Removal Inventory

Diffed `209ec08^` against `HEAD` for the four target paths; cross-checked every loss against the proposal's cut-rationale paragraphs and the review's per-section table (`orchestration-discipline.md` lines 74-92, `oversee-arc.md` lines 94-104 of the review).

### (a) Removed on purpose (terse)

All of the following have an explicit decision trail (review table entry, proposal cut-rationale sentence, or the maintainer's blanket Open-Questions sign-off):

- Overseer thinness signal: `inline_work`/`overseer_thinness`/`signal_missing` columns, Graded Enforcement's 3-layer scheme, and the unbuilt Phase 5 `PreToolUse` hook spec. Review: "a self-report... no stronger than the self-check" (line 86, 111). Dropped from the rule, `iterate/SKILL.md`, `iterate/template.md`, `judge.md` (`54160e7`, `dfbf5c0`).
- Claim registry, AFK/interleaving machinery (`skip-blocked`, pause marker, `--max-parallel`), five-kind Steering Log, troubleshooting-budget counter, verification-depth-ladder table: never used (review "Method and Evidence", lines 34-39); cut or folded into `oversee/SKILL.md` prose.
- `oversee-arc.md` deleted whole (`5d0abae`); its generic lessons (liveness, single-writer, verification floor) folded into the rule, its arc-only material (arc state, resume, concurrency) into `oversee/SKILL.md` (`3ff2310`).
- Numeric dispatch-by-default thresholds (">1KB or >20 lines", ">10 lines"): review calls them "false precision a model will not measure" (line 78).
- "Signaling self-check" ("could a subagent do this better"): review, "restates dispatch-by-default as a question" (line 80).
- Inline Discipline Floor rationale and CLAUDE.md reseed mechanism: cut from the rule, relocated to README "Rules Integration" as two sentences (review lines 81, 90; confirmed landed in `plugins/cdocs/README.md` diff).
- Cross-Target Degradation blocks (all files): deleted outright per the proposal, tracked by a dedicated follow-up, `cdocs/proposals/2026-10-06-target-specific-guidance-rfp.md` (status `request_for_proposal`).
- Pillar-numbering ("Pillar 1/1b/2/3") replaced by descriptive headings: review, "numbered references across many files did not [survive edits]" (proposal "Important Design Decisions").

### (b) Relocated

- `oversee-arc.md` content → `oversee/SKILL.md` and `template.md` (arc state, concurrency, resume).
- Liveness-reconciliation and single-writer incident citations → now live only in the review doc (`cdocs/reviews/2026-10-06-review-of-overseer-rules-simplification.md:209-210`), citing `cdocs/devlogs/2026-09-01-oversight-proposals-and-cc-features.md` and `cdocs/devlogs/2026-09-18-delegate-model-benchmark-deepening.md`; the rule itself keeps the lesson but not the anecdote.
- `triage` "How it works" routing table → lives solely in `skills/triage/SKILL.md` (already did; `workflow-patterns.md` pointer removed as duplicate).
- Judge output format → compressed one-line instruction in `judge.md`, verdict vocabulary unchanged.

### (c) Removed or weakened without an explicit decision (exhaustive)

1. **`workflow-patterns.md` quantified dispatch trigger and its "Don't use when" list.** Old: "When 3+ independent failures occur... Don't use when: ... Failures likely share underlying cause... Agents would edit same files (conflict risk)". New "Parallel investigation" section (lines 3-6) keeps the qualitative gist ("look independent... no shared files... debug one first") but drops the "3+" number and the enumerated don't-use cases. Not named in the proposal's cut-rationale paragraph (which lists only the four-role restatement, the triage routing table, and the agent-Architecture list as reasons for this file's cuts). Traced via `git log -S "3+ independent failures"` to `078f053` (2026-01-29), the file's original content; it does not encode a later observed failure. A capable model would likely still parallelize independent failures and serialize same-file writers on its own judgment (the latter is also stated plainly elsewhere, in "One writer per file"), so the loss is low-stakes, but it is a genuine gap in the decision trail.
2. **Scratchpoint's `since_handoff` field.** Old fields: `as_of, now, since_handoff, open, next, files`. New: `as_of, now, next, open, files` (orchestration-discipline.md:32, template.md diffs). The review's call ("compress to 2L... a model keeps a now/next/open block without a schema", line 88) covers dropping the schema generally but never names `since_handoff` specifically; it is the one field whose loss removes a distinction (current state vs. facts not yet in a handoff) rather than just compressing prose.

No other loss found in the diff lacks a traceable decision; the process was unusually well-documented for a compression of this size (85% of the pre-change bulk, per the review's own estimate).

## 2. Durable Specialists

**Origin.** Introduced 2026-09-01 in `04ba25d` ("feat(cdocs): add Pillar 3 durable-specialist section to orchestration-discipline"), with discoverability pointers added in the same commit batch by `c5aa4c7`. Both implement Phase 5 of `cdocs/proposals/2026-08-28-overseer-alignment.md`, tracked in `cdocs/devlogs/2026-09-01-overseer-alignment-phase3.md`.
Four subsections: Resume-by-name (one specialist per workstream, addressable via `SendMessage`), Fork for side-context (disposable, full-context, one-off), One-per-workstream bound (N specialists recreate the cost problem the discipline exists to prevent; escalate to a parent overseer rather than spawn more), File ownership by construction (a specialist owning its files satisfies "Pillar 1b: Single-Writer File Ownership" automatically).

**Why.** The commit message states the motive directly: keep the overseer thin "while a workstream still carries its full history: the retained context lives in the specialist, addressable by name, rather than in ever-growing overseer turns." It generalized a pattern `iterate` already half-encoded (the implementer kept warm across rounds unless the judge rotates it) to any multi-turn workstream, not just the implement loop. It addresses re-brief cost (naming beats re-explaining), an explicit per-overseer bound (N workstreams, N specialists, no more), and ties into single-writer file ownership "by construction."
The later `cdocs/reports/2026-09-20-token-spend-by-role.md` ("Token Spend by Role") quantifies the cost the pattern was managing: the top warm implementer reached 966K tokens and alone accounted for 11.3% of a week's cache-read spend (Open Follow-ups #3); workstream 4, "Cap-and-reseed the warm implementer", proposed capping a specialist's resident context at a tentative ~0.2M (later revised toward ~0.4-0.6M) and reseeding from a durable summary rather than carrying indefinitely, explicitly naming this as the mechanism-level answer the durable-specialist pattern was missing.

**Current text.** `orchestration-discipline.md` "Stay thin" (line 9): "Keep a workstream's deep context in a named subagent resumed with `SendMessage`, and send one-off side questions to a `fork`." That is the entire surviving text; no heading, no "specialist" or "durable" vocabulary anywhere in the five always-loaded rules. `workflow-patterns.md` line 11 carries the same one-clause pointer for multi-phase plans.

**What's lost, and whether it was decided.** The review's per-section table explicitly called for compressing Pillar 3 "to 2L" with the recommended wording "Resume a named specialist via `SendMessage`; fork for a side question" (review line 91), and explicitly OK'd dropping the one-per-workstream bound and the file-ownership-by-construction cross-link as "restat[ing] other sections or formaliz[ing] the obvious." The proposal's own test plan (`grep -rnE '...|Durable Specialist|...'`) asserts zero hits for the term, confirming the vocabulary erasure was intentional, not accidental. What shipped diverges slightly from even the review's own suggested wording: it drops the word "specialist" (and "durable") in favor of "named subagent," so the concept is no longer independently citable anywhere, only reconstructable from the "Stay thin" clause and the `iterate` implementer-rotation behavior it generalized. The one-per-workstream bound (an explicit ceiling, "N parallel large-context specialists recreate the cost problem... at most one... per active workstream") is gone with no replacement; nothing in current rules caps how many warm subagents an overseer may keep simultaneously.

## 3. Do Implementers Write Scratchpoints Today?

No. Three current files agree: `orchestration-discipline.md:32` ("an agent writing into another agent's devlog keeps none"), `devlog/SKILL.md:43` (identical clause), `implement/SKILL.md:85` ("a dispatched implementer writes into the overseer's devlog and keeps none").
`iterate/SKILL.md:113` restates it for the loop specifically: "keep the Scratchpoint current between handoffs (the dispatched implementer keeps none)."
`agents/implementer.md:39` is the ownership boundary that produced this rule: "Commit authority and the devlog's Iteration/Judge/Dispatch/Steering tables belong to the overseer; append only to the devlog's `## Changes Made` table and your own `### Implementer Notes` subsection."
So the dispatched implementer's only owned section in the overseer's devlog is `### Implementer Notes` (plus rows in the shared `## Changes Made` table), and its only other durable artifact is its end-of-turn return summary to the overseer, which is not committed or structured.
This design predates the current rules: the chat-record proposal (`cdocs/proposals/2026-09-22-chat-record-devlog-management.md:309-310`) states the same split explicitly ("any agent that owns its devlog... keeps [a Scratchpoint]... An agent writing into another agent's devlog keeps none: the `iterate` implementer writes only `## Changes Made` and `### Implementer Notes`, and its return summary is its checkpoint"), and that proposal's own Phase 3 (line 542, gated on the still-open `cdocs/proposals/2026-10-05-post-compaction-resumption-rfp.md`) is the direct ancestor of the maintainer's current ask: "the overseer has the specialist write a final handoff (and Scratchpoint, if it owns a devlog), then dispatches a fresh leg seeded from them."
That phase is unimplemented; it is explicitly blocked on an RFP still in `request_for_proposal` status.
A dispatched agent's natural handoff artifact today is therefore its freeform `### Implementer Notes` entries plus its final return summary, neither of which is a structured, diffable checkpoint.

## 4. Observable Context Signal

**Field names, verified.** Two surfaces exist and both are confirmed in devlogs, not just the proposal that first named them. The synchronous `Agent` tool result carries `toolUseResult.totalTokens` and `totalDurationMs` (plus `usage`, `agentId`, `status`, `totalToolUseCount`); the async `task_notification` surface (a backgrounded dispatch) carries the differently-named `subagent_tokens`/`duration_ms`.
`plugins/cdocs/skills/ablate/SKILL.md:197`: "The real Claude Code result payload surfaces `toolUseResult.totalTokens` and `toolUseResult.totalDurationMs`... NOT `subagent_tokens`/`duration_ms`."
`cdocs/devlogs/2026-09-17-mcp-ablation-iterate.md:166`: "those are the notification-surface names; both surfaces exist."
So the user's `tool_uses` is the real field `totalToolUseCount`, and `subagent_tokens`/`duration_ms` are real but notification-only, aliased from `totalTokens`/`totalDurationMs` in `ablate.sh`'s meter reader.

**Resident vs. cumulative, verified for a short-lived agent.** `cdocs/devlogs/_verify/2026-10-05-bash-runner-live-canary-r6.md:49`: "`subagent_tokens` comes from the parent's `Agent` tool result (`tool_use_result.totalTokens`, which matches the runner's final-turn usage)."
That is a direct cross-check (ground-truth capture files vs. the reported number) for six two-call runner dispatches, and it establishes the field as a snapshot of the agent's final-turn usage (effectively its resident context at that point: Claude's per-turn `usage` already includes the full re-sent history as `input_tokens` plus `cache_read_input_tokens`), not an accumulator summed across every turn of the dispatch.

**Inferred, not independently re-verified for a long-lived warm agent.** No devlog directly measured `totalTokens`'s trajectory across many rounds of a resumed `SendMessage` specialist; the canary above only covers single-shot, two-call dispatches, where resident and "total ever spent" are nearly the same number and so don't discriminate the question.
The separate `cdocs/reports/2026-09-20-token-spend-by-role.md` "Iterate-loop context-carry dataviz" follow-up (#3) independently supports the same reading by construction: it describes "per-round peak context grew 155k to 966k" for a warm implementer by summing `cache_read` *per turn* from `usage.db`'s `turns` table (a different reconstruction path than `totalTokens`), which is consistent with the same API semantics (each turn's usage reflects what was resident at that turn, not a running total), but it is a separate measurement, not a confirmation of the `totalTokens` field itself at scale.
Given the API mechanism is the same regardless of how many prior turns a `SendMessage`-resumed agent has had, the resident-not-cumulative reading should generalize, but this is inference from mechanism, not a devlog that measured it directly on a many-round specialist.

**Simplest reliable signal.** Read `totalTokens` off the dispatch result (sync) or `subagent_tokens` off the `task_notification` (async) after every turn of a named, resumed specialist; no extra instrumentation is needed, since the number already reflects context at that turn rather than a lifetime sum.

## 5. Recommendation

**Scratchpoint ownership (per maintainer direction).** The current "keeps none" rule exists to preserve single-writer-per-section, but it conflated "owns the devlog" with "owns a section of it," when the implementer already owns `### Implementer Notes` by construction (`agents/implementer.md:39`).
Generalize `orchestration-discipline.md:32` from devlog-level to section-level ownership:

> Between handoffs, keep a short Scratchpoint (as_of, now, next, open, files touched) current in the devlog section you own: your own `## Scratchpoint` if you own the devlog, or a nested Scratchpoint inside the one subsection that is yours (e.g. a dispatched implementer's `### Implementer Notes`) otherwise.

This keeps single-writer-per-section intact (the implementer still never touches the overseer's `## Scratchpoint` or tables) while giving the implementer a rolling, diffable "state of me" that updates on every substantial turn, not just at rotation.
`devlog/SKILL.md:43` and `implement/SKILL.md:85` get the matching one-clause edit; `agents/implementer.md` gains "keep a nested Scratchpoint in your Implementer Notes, updated each turn."

**Cap-and-restart wording.** Place the trigger in `orchestration-discipline.md` under "Stay thin" (general to any named, `SendMessage`-resumed specialist, not iterate-only), and let `iterate/SKILL.md` carry the concrete cutoff as a tunable (matching workstream 4's own "tentative, to be tuned" framing):

> When a named subagent's reported context (`totalTokens`/`subagent_tokens`) is at or above ~250K after a turn, either cold-start a fresh one from the devlog, or have it write a handoff into its owned section and restart a fresh leg seeded from that handoff.
> Commit the triggering turn's Scratchpoint alongside the handoff, by explicit path, so the Scratchpoint-to-handoff delta is diffable later.

That is 2 statements, matching the file's existing one-clause-per-lesson density.
The cutoff number itself stays out of the rule (consistent with "no numeric thresholds a model won't measure", the review's own rationale for cutting the old dispatch-by-default thresholds); ~250K is a loop-specific, empirically-tunable parameter, so `iterate/SKILL.md` is the right home for the literal number, with the rule carrying only the mechanism.

**What must be committed for the later analysis.** Both artifacts, by explicit path, in the same commit as the triggering turn: the Scratchpoint entry as it stood immediately before the restart decision (not overwritten by the next turn), and the handoff the specialist writes when asked to checkpoint instead of being cold-started.
Committing both lets a later pass diff "what the Scratchpoint already said" against "what the handoff added," which is the empirical question workstream 4 left open (how much carry-value a reseed loses) and that no current devlog has measured.
