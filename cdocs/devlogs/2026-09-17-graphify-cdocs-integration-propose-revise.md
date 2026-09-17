---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-17T00:00:00-08:00
task_list: cdocs/graphify-integration
type: devlog
state: live
status: wip
tags: [cdocs, tooling, efficiency, subagents, graphify]
---

# Graphify → cdocs integration (propose-revise loop): Devlog

## Objective

Overseer log for a `/cdocs:propose-revise` loop producing a proposal that integrates
**graphify** (code-graph substrate) into cdocs to streamline heavy subagent token usage,
and evaluates bundling it into a **"librarian"-style sonnet subagent** that heavier
opus/fable proposers/implementers/reviewers rely on as an assistant.

Source RFP (weftwise, consumer-side decision trail):
`/var/home/mjr/code/weft/weftwise/main/cdocs/proposals/2026-09-15-code-graph-review-plugin-rfp.md`.
Implementation surface: this repo (`clauthier/cdocs`).

## Plan

Overseer-mode `/cdocs:propose-revise`: dispatch fresh proposer (`/cdocs:propose`), then
alternate fresh `cdocs:reviewer` rounds until accept-or-escalate. AskUserQuestion after 6
unaccepted rounds. Default model tier (opus lead/judgment, sonnet search); consumer floor wins.

## Iteration Log

| Round | Role | Dispatch | Return | Overseer context | Inline work |
|-------|------|----------|--------|------------------|-------------|
| 0 | overseer | scaffolded devlog + briefed proposer | — | ~40K | devlog write only |
| 1 | proposer | /cdocs:propose (dispatched) | review_ready; proposal written | ~55K | devlog edit + commit |
| 1 | reviewer | cdocs:reviewer (fresh) | pending | — | — |

Proposal path: `cdocs/proposals/2026-09-17-graphify-cdocs-integration.md`

Proposer recommendation: ship the stateless role-agnostic graph-scoping tool/MCP first
(Bet 1), defer the durable "librarian" subagent (Bet 2), gate the librarian on
instrumentation. Rationale: a no-model tool sidesteps the consumer-floor "no silent
downgrade" bar; degrades cleanly cross-target; captures the review win without the larger
resident-index bet. Librarian, if built, is a read-only shared *service* (owns no files),
orthogonal to Pillar 3's one-per-workstream bound. Phase 1 = discriminator-first token
instrumentation (gates everything); recall parity = hard reject gate; CRDT blind spot =
inline "scoping AID, not guarantee" caveat + test fixture.

## Decisions Made

- Proposal is a **new** clauthier proposal (not in-place elaboration of the weftwise RFP);
  the RFP is the consumer decision trail, clauthier is where the plugin/agent lands.
- Key framing carried from the RFP into the brief: discriminator-first token accounting is a
  prerequisite; recall parity is non-negotiable; the CRDT blind spot must be surfaced, not hidden.

## Open Todos

- [ ] Proposer round 1 complete; capture output path here.
- [ ] Review round 1.
