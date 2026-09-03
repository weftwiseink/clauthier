---
review_of: cdocs/proposals/2026-09-01-overseer-consolidation.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-03T10:30:00-07:00
task_list: cdocs/overseer-consolidation
type: review
state: live
status: done
tags: [fresh_agent, lifecycle_staleness, consolidation, agent_orchestration, oversee, frontmatter, overseer_arc]
---

# Review: Overseer Proposal Consolidation Memo (against current on-disk reality)

## Summary Assessment

The memo maps three overlapping "overseer" documents, deduplicates their open questions into a single §A/§B/§C set, and names `overseer-alignment` as the canonical live document for overseer-role design. That analytical core — the dedup and the canonical-doc decision — is accurate and remains valuable, and should be preserved. However, the memo was authored 2026-09-01, and its lifecycle claims have since gone stale: two of the three docs it tracks have advanced to `implementation_accepted`, and the §A scope it calls "fully unbuilt" is now being actively built. As a result several of its recommendations describe work that is already done or already in flight.

The verdict is **Revise**. The memo does not need its reasoning discarded; it needs its lifecycle assertions and "fully unbuilt" framing brought current, and a handful of recommendations reclassified from "pending" to "already satisfied."

## Section-by-Section Findings

### BLUF and Canonical Doc Decision (sound; two stale descriptors)

The canonical-doc reasoning is still correct: `overseer-alignment` is the document overseer-scoped work should attach to, and future proposals should extend it rather than restart from the RFP. Keep this.

**Non-blocking (descriptor drift):** the BLUF calls `overseer-alignment` "`review_ready` with a round-1 `revision_requested` verdict" and instructs the reader to "mark `iterate-skill` `implementation_accepted`." On disk, `overseer-alignment` is `status: implementation_accepted` (`last_reviewed` round 6, `accepted`) and `iterate-skill` is *already* `implementation_accepted`. The BLUF also calls the multi-proposal-arc ask "still unbuilt," which is no longer true (see §A finding).

### "Status of Each Document" — overseer-alignment bullet (blocking staleness)

**Blocking (stale lifecycle claim).** The bullet header reads "live, open, revision pending" and the body says the round-1 review "identifies two blocking gaps the author has not yet revised for." On disk `overseer-alignment` is `state: live` / `status: implementation_accepted`, `last_reviewed.status: accepted`, `round: 6`, and Phases 1-4 have shipped (each with an Accept review dated 2026-09-01). The two round-1 blocking gaps (Iteration-Log thinness signal; rule-delivery pipeline description) were resolved across rounds 2-6. The bullet must be rewritten to reflect the accepted, shipped state and drop the "revision pending" framing.

### "Status of Each Document" — iterate-skill bullet (blocking staleness)

**Blocking (recommendation already satisfied).** The bullet says the frontmatter "(`status: review_ready`, `last_reviewed.status: accepted`) is stale … it should be updated to `implementation_accepted`." On disk it is already `state: live` / `status: implementation_accepted`. The recommended change has been applied; the bullet should record it as done rather than pending.

### "Status of Each Document" — RFP bullet (mostly current; recommendation partly satisfied)

The RFP is correctly still `state: live` / `status: request_for_proposal` (verified on disk), and the "core multi-proposal-arc ask genuinely unshipped" judgment was right as of authoring. Two updates are needed: (1) the memo's recommendation to "add a second NOTE pointing at `overseer-alignment` and this memo's §A" is already satisfied — the RFP's on-disk NOTE (lines 14-15) already references both; (2) that NOTE should now additionally point at `overseer-arc` (`cdocs/proposals/2026-09-03-overseer-arc.md`) as the elaboration of the remaining §A scope.

### §A — "/oversee multi-proposal orchestration … still fully unbuilt" (blocking framing staleness)

**Blocking (framing overtaken by events).** The §A subtitle "unique to the RFP, still fully unbuilt" is no longer accurate. This exact scope is being full-sent this session as `cdocs/proposals/2026-09-03-overseer-arc.md` (tracked in devlog `cdocs/devlogs/2026-09-03-full-send-overseer-arc.md`, `status: wip`), whose stated objective draws its scope boundary from this memo's §A. The seven §A items remain the correct decomposition and should be preserved — but they should be reframed as the scope brief that `overseer-arc` elaborates, with a pointer to that proposal as their home, rather than presented as untouched.

### §B / §C — open-question set (largely durable; several §C items now resolved)

The §B iterate-loop refinements (#8-#11) remain open and correctly stated; no over-reach there. In §C, however, the round-1-review-gap items are now resolved by the shipped Phases 1-4 and should be moved out of "open":
- **#17 (judge-observable thinness signal) — resolved.** The iterate Iteration-Log now carries an `overseer_thinness` column plus `overseer_ctx_est` and `inline_work` dispatch/return fields; the judge keys `bloat_detected`/`escalate` off them (Phase 2 review: Accept).
- **#18 (rule-delivery pipeline description) — resolved** in the accepted revision (round 6).
- **#19 (model-tiering vs. consumer floor) — addressed;** `plugins/cdocs/rules/model-tiering.md` shipped as its own rule.
- **#12 (rule-file granularity) — decided:** Pillars 1-3 shipped combined in `orchestration-discipline.md`, with `model-tiering.md` split out; context-discipline was not separated.

The "[Blocking, pending author revision]" tags on #17/#18 are stale and should be dropped.

### Recommended Frontmatter Changes table (blocking staleness)

**Blocking.** The `iterate-skill` row lists "Current: `status: review_ready`" and recommends changing to `implementation_accepted`; on disk it is already `implementation_accepted`, so this row should be marked done/already-satisfied. The `overseer-alignment` row ("No change … correctly represents 'live, under revision'") is now wrong — it is accepted and shipped; update the row. The RFP row's "add a second NOTE" recommendation is already satisfied and should be re-pointed at `overseer-arc`.

## Verdict

**Revise.** Preserve the dedup set and the canonical-doc decision; update the stale lifecycle claims (overseer-alignment and iterate-skill both `implementation_accepted`), the §A "fully unbuilt" framing (now `overseer-arc` in flight), and reclassify the already-satisfied recommendations. None of the memo's analysis is wrong in substance — it has simply been overtaken by shipped work.

## Action Items

1. [blocking] BLUF (lines 14-18): update overseer-alignment to `implementation_accepted`; reframe the iterate-skill "mark implementation_accepted" as already-done; note the multi-proposal-arc ask is now being built as `2026-09-03-overseer-arc.md`.
2. [blocking] "Status of Each Document" → overseer-alignment bullet (lines 40-44): change "live, open, revision pending" to `implementation_accepted` (Phases 1-4 shipped, round-6 accepted); drop the round-1 revision-pending framing and the "two blocking gaps not yet revised" text.
3. [blocking] "Status of Each Document" → iterate-skill bullet (line 38): the "frontmatter is stale, should be updated to implementation_accepted" claim is itself stale; on disk it is already implementation_accepted — record as done.
4. [blocking] Recommended Frontmatter Changes table (line 85): iterate-skill row "Current: status: review_ready" is wrong (it's implementation_accepted) — mark the recommendation satisfied; update the overseer-alignment row from "No change / under revision" to accepted+shipped.
5. [blocking] §A header (line 50) "still fully unbuilt": rewrite to reflect `2026-09-03-overseer-arc.md` (full-send in progress, devlog `2026-09-03-full-send-overseer-arc.md`); reframe items 1-7 as the scope brief overseer-arc elaborates. Preserve the item list.
6. [blocking] RFP bullet (lines 29-33) and RFP table row (line 84): the "add a second NOTE pointing at overseer-alignment and §A" recommendation is already satisfied on disk (RFP NOTE lines 14-15); update it to additionally point at overseer-arc. Confirm RFP stays live / request_for_proposal.
7. [non-blocking] §C #17/#18/#19 and their "[Blocking, pending author revision]" tags: mark resolved by Phases 1-4 (Iteration-Log `overseer_thinness` + `overseer_ctx_est`/`inline_work`; corrected rule-delivery model; `model-tiering.md` shipped).
8. [non-blocking] §C #12: mark decided — combined `orchestration-discipline.md` plus separate `model-tiering.md`; context-discipline not split.
9. [non-blocking] Memo frontmatter (line 8, status: review_ready): reviser's call on moving the memo to a settled/reference status now that it is a living cross-document map.
10. [preserve] Do not discard the §A/§B/§C dedup or the Canonical-Doc Decision — both remain accurate and are the memo's durable worth.

## Clarifications Requested (multiple choice)

**A. Once the lifecycle facts are refreshed, what status should the memo itself carry?**
1. Keep `review_ready` (treat it as still-in-review).
2. Move to `implementation_accepted` / a reference status, since it is now a maintained cross-document map rather than a proposal awaiting a build.
3. Fold the memo's living-map role into `overseer-arc` / `overseer-alignment` and mark the memo `evolved`.

**B. Where should the §A open-question set live going forward?**
1. Keep it in this memo as the canonical dedup, with `overseer-arc` pointing back to it.
2. Migrate §A into `overseer-arc` and leave a pointer here.
