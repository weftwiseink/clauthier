---
review_of: cdocs/proposals/2026-05-13-iterate-skill.md
first_authored:
  by: "@claude-opus-4-7"
  at: 2026-05-13T11:15:00-07:00
task_list: cdocs/iterate-skill
type: review
state: live
status: done
tags: [fresh_agent, rereview_agent, iterate_skill, round_2, consistency_check]
---

# Review (Round 2): Proposal for `/cdocs:iterate` Skill

## Summary Assessment

The author has addressed all 12 round 1 action items.
Factual errors are corrected (reviewer model is now opus throughout), the user-vs-agent overseer framing is reconciled in a clear NOTE at the top, `blocking_count` and oscillation handling are defined, implementer dispatch is specified, second-order-dispatch policy is reconciled, and behavioral verification is now artifact-based.
Stories 4-6, edge-case additions (token compaction, divergent `task_list`, tests-pass-but-Revise, AFK no-floor), and the `/cdocs:implement` override callout all land cleanly.
**Verdict: Accept.**

## Verification of Round 1 Action Items

1. **[blocking] User-vs-overseer reconciliation** - addressed. New NOTE under Objective and the Role Taxonomy entry both state plainly that the top-level agent in the invoking session is the overseer; the user is the supervisor.
2. **[blocking] Define `blocking_count` and oscillation** - addressed. New "Metric definitions" subsection in Loop Protocol defines `blocking_count` as the literal count of `[blocking]`-tagged action items; "flat" and "decreasing" are defined; oscillation text-matching is explicitly deferred to v2 in a NOTE.
3. **[blocking] Implementer dispatch mechanism** - addressed. Role Taxonomy entry and Turn N.a both commit to: fresh `general-purpose` subagent via Task tool, instructed to follow `/cdocs:implement` for a single iteration. The v2 note acknowledges a future formal `implementer` agent.
4. **[blocking] Reviewer-model factual correction** - addressed. Reviewer is now correctly described as opus throughout; Open Question 1 is recast as "downgrade to sonnet for speed?" with a reasoned default-no answer.
5. **[blocking] Test Plan item 4 observability** - addressed. Now reads "checkable from artifacts, not from in-flight Task prompts" and specifies concrete artifact checks (`implementer` column references `general-purpose`, `review_path` points to a real review file with matching `review_of`).
6. **[non-blocking] `/cdocs:implement` review-dispatch override** - addressed. New "Important Design Decisions" entry explicitly states the override and explains the rationale; Turn N.a also restates it inline.
7. **[non-blocking] Reviewer second-order dispatch reconciliation** - addressed. The "Asymmetric second-order subagent dispatch" entry is now the single source of truth: write-side dispatch forbidden, read-side `/cdocs:report` allowed for reviewers. The trailing NOTE in Open Questions confirms the prior ambiguity is resolved.
8. **[non-blocking] Justify `--max-flat-iterations=3`** - addressed. Termination Conditions item 3 now gives the rationale: two flat-or-growing iterations trigger implementer rotation, the third triggers escalation after giving rotation a chance.
9. **[non-blocking] Iteration log column semantics** - addressed. New paragraph after the table specifies synthetic per-loop handles (`impl-N` / `rev-N`) with subagent type in parentheses, plus `review_path` for cross-verification.
10. **[non-blocking] Drop or confirm `plugin.json` from Phase 2** - addressed. Phase 2 now states "no manifest edits are required" and notes skills are discovered by directory layout; the file list correctly omits `plugin.json`.
11. **[non-blocking] Token-compaction and divergent `task_list` edge cases** - addressed. Both are explicit Edge Cases subsections with concrete behavior.
12. **[non-blocking] Story for no-verification-floor path** - addressed. Story 6 walks the AFK no-floor case end-to-end, consistent with the Edge Cases entry.

All 12 round 1 items: addressed.

## New Issues Surfaced in Revision

### Loop Protocol - state diagram edge labelling

The mermaid diagram uses two `Review --> Implement` edges with different labels (`revision_requested (carry context forward)` and `fatigue, dispatch fresh implementer`).
This is technically valid mermaid but visually conflates two distinct decisions made in different places (Turn N.c branches).
**[non-blocking]** Consider an intermediate `Decide` state to make the branch points unambiguous. Minor diagrammatic preference, not a blocker.

### `blocking_count` window for "flat" vs `--max-flat-iterations`

The metric definitions say "flat" means "consecutive `blocking_count` values differ by 0" without specifying the window size.
Story 3 and Termination Condition 3 use "flat or growing for `--max-flat-iterations` consecutive reviews".
The Turn N.c rule says "≥2 consecutive reviews" triggers implementer rotation while `--max-flat-iterations=3` triggers escalation.
The two windows (2 for rotation, N for escalation) are coherent on close reading but the prose mixes "flat" the predicate with "flat for N" the trigger.
**[non-blocking]** A single sentence in Metric Definitions clarifying "`flat` is a pairwise predicate; rotation uses a window of 2, escalation uses `--max-flat-iterations`" would prevent future confusion.

### `blocking_count` derivation depends on review template stability

The skill parses `[blocking]` tags directly from the review document's Action Items.
The `/cdocs:review` template at `plugins/cdocs/skills/review/template.md` does not enforce a fixed Action Items section or tag syntax; it is documented in `SKILL.md` by example only.
If a reviewer omits the tag (writes "1. Reconcile X" without `[blocking]`), `blocking_count` silently drops.
**[non-blocking]** Phase 2 should add a line to `plugins/cdocs/skills/review/SKILL.md` requiring the `[blocking]` / `[non-blocking]` tag prefix on Action Items so `/cdocs:iterate`'s parser has a stable target. Not blocking because the existing convention is already followed in practice.

### AFK placeholder verification floor risks gaming the loop

Edge Cases and Story 6 both specify a placeholder floor of "verification was not specified; tests pass and the proposal's stated objective is met" when AFK.
A literal reviewer reading that string may rubber-stamp Accept on a single passing test.
The prepended `> WARN` callout in the final summary is the user-visible mitigation, but the iteration log itself does not surface the placeholder distinctly.
**[non-blocking]** Have the iteration log's `notes` column on placeholder-floor rows include `[placeholder-floor]` so dogfood retrospectives can find them.

### Phase 4 dogfood phrasing

Round 1 action item 5 suggested making dogfood a *required* Phase 4 deliverable.
Phase 4 now exists and reads "Use `/cdocs:iterate` on at least one real subsequent proposal" with concrete success criteria.
Good. **[non-blocking]** Consider naming a specific candidate proposal (e.g., the MTG spike from Story 1) so Phase 4 is not deferred indefinitely.

## Form / Writing Conventions

- BLUF still informative; the added "peer to future `/oversee`" line is a useful addition.
- Sentence-per-line: clean throughout.
- Em-dash avoidance: clean.
- History-agnostic framing: holds; revision additions read as if always-present.
- NOTE callouts: appropriately used; the trailing NOTE in Open Questions correctly retires the previously-open items as decided.

## Cross-Document Consistency

- vs. `reviewer.md`: now consistent on opus + safety constraint.
- vs. `/cdocs:implement`: the override is documented and the rationale matches the actual SKILL.md text I confirmed ("Request `/cdocs:review` from a subagent after each phase").
- vs. `/oversee` RFP: the narrowing-not-contradiction framing is now explicit in a NOTE.
- vs. `frontmatter-spec.md`: iteration log is a devlog section, not a frontmatter field, consistent with the spec.

## Verdict

**Accept.**

All round 1 blockers are addressed. The new findings are minor polish suggestions, none rising to blocker status.
The proposal is ready to transition to `implementation_ready`.

## Action Items

1. **[non-blocking]** Clarify the "flat" predicate window vs. `--max-flat-iterations` trigger window in Metric Definitions (one sentence).
2. **[non-blocking]** During Phase 2 (or as a small companion edit), tighten `/cdocs:review`'s Action Items convention to require the `[blocking]` / `[non-blocking]` tag, so `blocking_count` parsing has a stable contract.
3. **[non-blocking]** Mark placeholder-floor iteration log rows with a `[placeholder-floor]` tag in the `notes` column.
4. **[non-blocking]** Optional: introduce an intermediate `Decide` state in the mermaid diagram to disambiguate Turn N.c branches.
5. **[non-blocking]** Optional: name a concrete candidate proposal for the Phase 4 dogfood run.

## Questions for the Author (Multiple Choice)

A. For Action Item 2 (review template tag enforcement):
   1. Add the requirement to `/cdocs:review`'s SKILL.md in Phase 2 of this proposal.
   2. Spin out a separate one-line proposal/devlog to tighten the review convention.
   3. Defer to v2 and rely on existing review-author discipline.

B. For Action Item 3 (placeholder-floor row marker):
   1. Add `[placeholder-floor]` tag in `notes`.
   2. Add a dedicated column to the iteration log table.
   3. Rely on the final-summary `> WARN` callout alone (status quo).
