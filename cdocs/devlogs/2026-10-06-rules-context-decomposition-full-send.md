---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T09:50:00-07:00
task_list: cdocs/rules-context-decomposition
type: devlog
state: live
status: wip
tags: [rules, architecture, orchestration_discipline, init, full_send]
---

# Rules Context Decomposition: Full Send

> BLUF(opus-5-5/cdocs/rules-context-decomposition): Full-send loop (arc p2 of [the arc devlog](2026-10-05-oversee-haiku-bash-wrapper.md)) taking [the RFP](../proposals/2026-10-05-rules-context-decomposition-rfp.md) through propose-revise then iterate: compress the overseer rules, decompose the always-loaded rules context, delete non-Claude-Code blocks, and file the reintroduction RFP.

## Brief

Scope:
1. Compress the overseer rules per [the simplification review](../reviews/2026-10-06-review-of-overseer-rules-simplification.md) and the maintainer's 2026-10-06 steering (arc devlog "Steering (2026-10-06)"): `oversee-arc.md` guidance moves skill-side, loaded on demand by the oversight skills; delete the thinness signal; delete the claim registry; Steering Log becomes free text plus "a message arriving mid-dispatch is queued, never injected".
2. Decompose the rules context: compress first, then decide layout.
3. Delete non-Claude-Code (cross-target/OpenCode) blocks from rules, skills, agents; file a follow-up RFP on reintroducing target-specific guidance without bloating context.

Principles: lean on agent intuition, fewer formalisms; keep rules that encode an observed failure; sizes in lines/words.
Verification floor: after the change, `npm run build:cdocs` exits 0; the frontmatter validator and `plugins/cdocs/hooks/tests/chat-record.test.sh --unit` pass; a grep shows no remaining references to deleted constructs (thinness columns, claim registry, `oversee-arc.md` as a rule, Cross-Target sections); and a live smoke run (`claude -p --plugin-dir plugins/cdocs --model sonnet`) of a small `/cdocs:iterate` or propose-revise turn shows the compressed rules still produce delegation, a dispatch/return row, and explicit-path staging. Failure picture: a lead that does the work inline, leaves no dispatch rows, or `git add -A`s.

### Optional input: devlog-splitting friction (first real split, 2026-10-06)

Address only with minimal wording, if at all:
- A terminal loop's Iteration Log is all "finished rows", so the root's tables empty out and lose the at-a-glance verdict history.
- A single closed concern over the ~1,500-word trigger has no guidance (the splitter cut at a natural round boundary).
- Chunk frontmatter source (`first_authored`, `state`, `tags`) is unstated; the splitter copied the root's.
- Moved text like "this devlog" / "tables above" can read wrong after a move; inbound references from other docs are not mentioned.

## Scratchpoint

- as_of: 2026-10-06T09:50
- now: propose round 1 (RFP elaboration)
- open: none
- next: review round 1
- files: this devlog, the RFP

## Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | inline_work | notes |
|---|---|---|---|---|---|---|---|

## Dispatch/Return Events

| event | agent_handle | target_files | at | notes |
|---|---|---|---|---|
| dispatch | prop-1 (cdocs:proposer) | cdocs/proposals/2026-10-05-rules-context-decomposition-rfp.md | 2026-10-06T09:51 | elaborate RFP in place |
| return | prop-1 | same | 2026-10-06T10:10 | `1d0734f` review_ready; oversee-arc deleted (3 lessons to orchestration rule, arc-only to oversee skill); always-loaded ~797/8,054 -> ~296/2,120 lines/words; 7 phases; 3 maintainer questions (init steps 5/6, Phase 5 scope, CLAUDE.md edit) |
| dispatch | rev-1 (cdocs:reviewer) | cdocs/reviews/2026-10-06-review-of-rules-context-decomposition-r1.md | 2026-10-06T10:11 | proposal review r1 |

## Steering Log

| at | kind | target | content | applied_at_iteration |
|---|---|---|---|---|
| 2026-10-06T09:45 | steer-implementer | prop-1 | Maintainer answers on the simplification review (see Brief scope 1). | 1 |
| 2026-10-06T09:58 | steer-implementer | prop-1 | Maintainer: oversee-arc split by tacit use, not references. Generic lessons (verification floor depth, isolate fault before costly full-cycle retries, serialize when overlap unsure) compress into the always-loaded orchestration rule; arc-only material goes skill-side on demand. | 1 |
| 2026-10-06T10:14 | steer-implementer | next reviser + implementer | Maintainer: root CLAUDE.md edit approved as drafted (Phase 2 ungated); init steps 5-6 kept with stale-file cleanup fix, future left to the follow-up RFP; Phase 5 (model-tiering + workflow-patterns compression) included. | pending |
