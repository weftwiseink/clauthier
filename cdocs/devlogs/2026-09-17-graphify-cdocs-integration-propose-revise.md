---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-17T00:00:00-08:00
task_list: cdocs/graphify-integration
type: devlog
state: live
status: done
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
| 1 | reviewer | cdocs:reviewer (fresh) | REVISE: 3 must-fix, 6 nits; direction sound | ~70K | devlog edit + commit |
| 2 | reviser | same proposer resumed (revisions narrow, not extreme) | done; all 3 must-fix + 6 nits resolved, spine unchanged | ~85K | devlog edit + commit |
| 2 | reviewer | cdocs:reviewer (fresh; 1st instance mis-stopped, re-dispatched) | ACCEPT; 3 non-blocking nits | ~95K | devlog edit + commit |
| 3 | reviser | same proposer resumed (clear accepting-round nits) | done; N1/N2 fixed, N3 included | ~100K | devlog edit + commit |

**LOOP COMPLETE — proposal ACCEPTED.** N1 (Investigation block reframed timeless),
N2 (Edge Cases CRDT bullet aligned to hardened D3 guard), N3 (Phase 1 fallback notes
read/generate split proxies "reasoning/writing unmoved"). Status: accepted, 2 review rounds.

Review 2 (ACCEPT): `cdocs/reviews/2026-09-17-review-of-graphify-cdocs-integration-r2.md`.
All 3 round-1 must-fixes verified genuinely closed; spine intact. Target frontmatter set
`last_reviewed.round: 2 / status: accepted` by reviewer. Accepting-round nits to clear:
N1 Investigation Requested opens as a changelog (history-agnostic miss) — restate directly;
N2 Edge Cases L161 still says CRDT guard is "caveat plus instruction", lagging hardened D3 —
align wording; N3 (optional) Phase 1 fallback: note read/generate split also proxies the
"reasoning/writing unmoved" half.

Revision 2: all must-fix settled — F1 D1 reframed ("no model = no carve-out negotiation",
live librarian question is warm-agent cost not tier); F3 recall gate operationalized
(candidate-union labeling + CRDT label from non-graph signals + noise policy by miss-class);
F5 per-phase attribution named PRIMARY Phase 1 risk w/ mechanism + coarser fallback. Nits
F4/F2/F6/F7(triage dropped)/F8(license re-added)/F9 all folded. Author Qs answered by
judgment. Investigation block now lists 3 forward-looking items only.

Review 1: `cdocs/reviews/2026-09-17-review-of-graphify-cdocs-integration.md`
Must-fix: (1) consumer-floor asymmetry overstated — reframe as "no model = no carve-out
negotiation," reconcile w/ weftwise's existing search/explore sonnet carve-out + Phase 4;
(2) recall-parity hard gate not operationalized — needs ground-truth labeling protocol
(esp. CRDT), corpus size, tolerance policy; (3) Phase 1 per-phase token attribution
asserted not designed — name as primary Phase 1 risk + fallback. Nits 4-9 minor.
Decision: route to same proposer (narrow revisions, affirmed direction). No fresh author.

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
