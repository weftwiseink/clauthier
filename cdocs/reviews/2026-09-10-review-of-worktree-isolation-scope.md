---
review_of: cdocs/proposals/2026-09-10-worktree-isolation-scope-to-dispatched-agents.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-10T14:30:00-07:00
task_list: clauthier/worktree-isolation-guardrails
type: review
state: live
status: done
tags: [fresh_agent, architecture, orchestration, worktree, dedup, verified_against_tree, accepted]
---

# Review: Scope Worktree-Isolation to Dispatched Agents, Not the Overseer

## Summary Assessment

The proposal makes worktree isolation a dispatched-agent property, stated once canonically in `orchestration-discipline.md`, and turns the loop skills isolation-AWARE (detect + route/warn) rather than isolation-BOUND, so the top-level overseer stays free to land, resolve, and fork.
Every load-bearing claim I spot-checked against the live tree holds: the `de34bee` interim removal, the nested-agent line references, the canonical-home line, the weftwise routing surfaces, and the report's harness-sandbox attribution.
The scope discipline is right (weftwise is document+route, no source edits; the collision is the harness sandbox, not authored confinement), the dedup story respects the intentional inline-floor exception, and the materialization nuance correctly says the RULE change DOES propagate via `/cdocs:init`.
The findings below are all non-blocking: some over-repetition of two framing points, one misattributed line reference, and a genuine but deferrable gap in the Phase-5 detection probe.
**Verdict: Accept.**

## Verification Against the Live Tree

Every cited surface checks out (post-`de34bee` state):

- **`iterate/SKILL.md` L18** — `de34bee` removed "...they should be used to contain the workstream"; the line now reads exactly "Code and cdocs should be committed early and often." Correctly classified RESOLVED/guard, not still-present.
- **`iterate/SKILL.md` L129** — "breach the same freshness/isolation invariant the reviewer and judge are built on" is unambiguously about an in-flight dispatched subagent. NESTED, confirmed.
- **`iterate/SKILL.md` L188-191** — "Sandboxed-runtime trust posture: The reviewer runs with full tools..." binds the dispatched reviewer. NESTED, confirmed.
- **`agents/reviewer.md` L45** — verbatim match ("boundaries ... backed by container isolation, your freshness ... Operators running `/cdocs:iterate` outside a sandboxed runtime should narrow the tool surface"). The proposal's read of this as the strong nested-agent home is correct.
- **`orchestration-discipline.md` L59** — "a hard tool-allowlist on the top-level session is not available, since it is the user's own session," under the "Graded Enforcement" heading (L57), with the Phase-5 `PreToolUse` advisory at L66. Placing the new subsection here is well-motivated: it reinforces the same graded-not-hard claim. The intentional-duplication NOTE the Edge Cases section mirrors is real at L54, and the inline-floor rationale is at L45-52.
- **`oversee-arc.md`** — Claim Registry at L57-81 (fails safe via `stale` reconciliation, on-disk under `.claude/oversee/claims/`), per-proposal `worktree` tracking field at L35, "isolate first, full-cycle second" fault-isolation at L96. All three classifications (promote / CLEAN / CLEAN) are correct by SENSE, as the Edge Cases section demands.
- **`skills/oversee`, `full-send`, `propose-revise`** — grep for `worktree|isolat|contain|sandbox` returns zero matches in all three, confirming the CLEAN rows.
- **weftwise (read-only, separate repo)** — `/resolve-wt` Step 2 performs `git merge <branch>` from the target's own worktree, gated on `pnpm gate` exit 0, Step 3 tears down with `git branch -d`; `scripts/worktree.sh cmd_add` runs `git worktree add -b <name> <target> <base>` (fork off base/`main`); `dogfood-wt.md` exists. The report confirms the `/resolve-wt` collision was the Claude Code harness sandbox ("a Claude Code sandbox behavior, not a clauthier rule"), not authored confinement.

## Section-by-Section Findings

### BLUF / Summary / Background — correct, but the two framing points are over-repeated (non-blocking)
The thesis is served precisely and the attribution is honest.
But two points are each restated four-plus times across the document:
"attribution is split, not singular" appears in the BLUF, Summary, the Background NOTE (L47-50), and Important Design Decisions (L126); the "rule materializes / interim skill fix did not / no weftwise edit" point appears in the Summary NOTE (L31-32), the Downstream section (L120), Important Design Decisions (L129), and Verification check 6 (L161).
Per writing-conventions "Avoid repetition. Say it once, in the right place," this could be tightened to one canonical statement each with pointers.
It is defensible here because both are load-bearing anti-misread guards for an implementer, so I flag it as a nit, not a blocker.

### The principle, stated canonically once (L58-73) — correct and well-placed
Single-source in `orchestration-discipline.md` with skills carrying a thin inline floor plus a reference is exactly consistent with the project's dedup value AND the inline-floor convention that the same file (L45-54) explicitly says NOT to deduplicate away.
The Edge Cases "Un-init'd install" item (L137) correctly protects the floor from collapsing to a bare pointer.
No over-deduplication and no scattering: the balance is right.

### Audit of authored surfaces (L79-92) — accurate, one misattributed line ref (non-blocking)
The table classifies by sense, not keyword, and every row I checked is correct.
One citation slip: the `skills/oversee/SKILL.md` row's parenthetical "(line 60 even treats 'a SECOND top-level `/oversee` in another worktree' as normal)" points at the wrong file. `oversee/SKILL.md` L60 is a composition-mapping table and contains no such phrase; the "SECOND top-level `/oversee` in another worktree" language actually lives in `oversee-arc.md` L60.
The row's substantive conclusion (oversee/SKILL.md is CLEAN, nothing confines the overseer) is independently confirmed by grep, so this is a supporting-evidence pointer error only.

### Materialization nuance — correct
The proposal correctly distinguishes the interim SKILL-only fix (does not materialize downstream, no re-init) from the RULE change (materializes, propagates via the SessionStart freshness nudge to re-run `/cdocs:init`).
Verification check 6 even makes "a claim that the rule change requires no downstream re-init" a FAIL condition. This is the right handling and does not fall into the trap the thesis warned about.

### Graded + cooperative alignment (L96-109) — correct
Clobber-safety leans entirely on the cooperative model (claim registry + single-writer + judge backstop + warn-not-refuse), never a session-wide hard lock, and the canonical subsection is deliberately co-located with the existing "no hard tool-allowlist" statement so it reads as the same shape of graded claim.
The Phase-5 advisory is correctly scoped as a SPEC-NOTE only (build deferred to a dedicated hooks proposal), warn-never-refuse. The "Warn, never refuse" design decision (L127) names re-introducing a refusing guard as exactly the failure being removed. Aligned.

### Isolation-AWARE loop skills (L103-109) — routing is sound; the detection probe is underconsidered (non-blocking)
The route/warn half is robust: surfacing an up-front precondition ("run this land/resolve from an un-isolated `main` session") turns the silent mid-merge wall into a gated precondition, which is the real fix.
The DETECT half (L107) is shakier than the prose implies. It proposes inferring a write-lock by attempting a read-only cross-worktree probe (`git -C <main> status` / `git worktree list`) and treating refusal as "locked."
But the motivating report itself establishes that the lock is (or should be) WRITE-scoped: cross-worktree READS are allowed under it (`git log`, `git diff main...HEAD`, `git worktree list` standalone), and the one refusal observed was a compound-parsing FALSE POSITIVE, not a true read-lock.
So a read-only probe can succeed while writes are still refused (missing the lock), or fail on a compound false-positive while the session is not actually write-locked (false alarm) - it tests the wrong axis to infer write-lock state.
This does not block: the route/warn behavior is correct even with no detection (a skill can surface the precondition whenever a cross-worktree step is due), and L216 already defers the detect/route mechanism to the implementer as a non-blocking residual.
Flagging so the implementer does not build a probe that yields false confidence; a "warn unconditionally at the cross-worktree step" fallback is more reliable than a read-probe heuristic.

### Verification Methodology (L139-161) — real and sufficient
Six grep/read-based checks with a concrete primary failure-picture (check 1: any surviving phrasing a reader would apply to the OVERSEER SESSION).
Checks 2 (single-source), 3 (nested-binding read), 4 (claim-registry contrast sentence), and 6 (no downstream source edit; rule DOES require re-init) each map to a specific proposed change and would catch the target regression - a reader applying isolation to the overseer session.
Sufficient.

### Implementation Phases (L163-196) — ordered, concrete, each verifiable
Phase 1 is correctly the dependency root; 2-5 reference it and each carries a success criterion tied to a verification check. The Constraints block (L191-196) restates the no-refusing-guard / no-weftwise-edit / no-restore boundaries as hard prohibitions. Implementable as written.

## Points Needing Clarification (multiple choice)

1. **Phase-5 detection mechanism** (see the isolation-AWARE finding). How should a locked session be handled?
   - (a) Drop auto-detection; have the loop skills ALWAYS surface the cross-worktree precondition at a land/resolve/fork step, locked or not (most robust, simplest).
   - (b) Keep a probe but make it a WRITE probe (e.g. a dry-run / harmless no-op write to `main`'s worktree) rather than a read probe.
   - (c) Keep the read probe as-is and accept best-effort detection.
   - (d) Leave entirely to the implementer at Phase 5 as the proposal currently does (L216), with no steer from this review.

2. **Framing-point repetition.** Tighten the "split attribution" and "rule-materializes" points to one canonical statement each with pointers (per brevity conventions), or keep the redundancy as deliberate anti-misread guards for the implementer?
   - (a) Tighten both. (b) Keep both as-is. (c) Tighten one, keep the other.

## Action Items

1. [non-blocking] Fix the `skills/oversee/SKILL.md` audit-row citation: the "SECOND top-level `/oversee` in another worktree" evidence is in `oversee-arc.md` L60, not `oversee/SKILL.md` L60.
2. [non-blocking] Add a note to Phase 5 that the route/warn precondition must not depend on a read-only probe correctly detecting a write-lock; prefer unconditional precondition-surfacing at cross-worktree steps (or resolve via the clarification question above).
3. [non-blocking] Optionally consolidate the "split attribution" and "rule materializes" framing points to one canonical mention each with pointers.

## Verdict

**Accept.**
The proposal correctly and canonically states the dispatched-agent isolation principle, keeps the overseer unbound, respects both the dedup value and the intentional inline-floor exception, handles the materialization nuance correctly, and aligns clobber-safety with the cooperative graded model.
All verified claims hold against the live tree.
The three findings are non-blocking nits and one deferrable design clarification; none require rework before implementation.
