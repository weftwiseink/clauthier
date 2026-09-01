---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-01T12:00:00-07:00
task_list: cdocs/overseer-consolidation
type: proposal
state: live
status: review_ready
tags: [oversee, agent_orchestration, cdocs_meta, consolidation, iterate, full_send]
---

# Overseer Proposal Consolidation

> BLUF: Three "overseer" documents overlap in scope but sit at different altitudes and different lifecycle stages.
> [`2026-03-26-rfp-oversee-skill.md`](2026-03-26-rfp-oversee-skill.md) is a request-for-proposal for a multi-proposal `/oversee` skill; most of its single-proposal-loop scope shipped as `/cdocs:iterate`, but its core multi-proposal-arc ask is still unbuilt.
> [`2026-05-13-iterate-skill.md`](2026-05-13-iterate-skill.md) is that shipped single-proposal loop: `plugins/cdocs/skills/iterate/`, `full-send/`, and `plugins/cdocs/agents/judge.md` all exist and match the design.
> [`2026-08-28-overseer-alignment.md`](2026-08-28-overseer-alignment.md) is the live frontier: it targets the overseer's own context/model hygiene rather than the loop protocol, is `review_ready` with a round-1 `revision_requested` verdict, and is the document new overseer-scoped work should attach to.
> **Recommendation: treat `overseer-alignment` as canonical for ongoing overseer work; mark `iterate-skill` `implementation_accepted` (shipped, do not re-propose); narrow `rfp-oversee-skill`'s remaining live scope to the multi-proposal-arc concerns that neither shipped doc covers.**
> This memo recommends frontmatter changes only; none are applied here.

## Canonical Doc Decision

**`2026-08-28-overseer-alignment.md` is the canonical live document for overseer-role design.**
It is the only one of the three still under active review, it is the only one addressing the overseer's own resource discipline (context growth, model tiering) rather than the loop protocol around it, and its round-1 review already threads the needle on how it relates to `iterate` (build on the Iteration Log, do not replace it) and to a future `/oversee` (Edge Cases: "the `/oversee` skill's cross-agent coordination layer handles this," multi-overseer coordination explicitly deferred).
Future overseer-scoped proposals should read `overseer-alignment` first and extend it rather than restart from the RFP.

## Status of Each Document

**`2026-03-26-rfp-oversee-skill.md` — partially superseded, remainder still live.**
This RFP asked for three things: (1) an `/oversee` skill for multi-proposal project arcs, (2) orchestration rules (verification depth, serialization/parallelization heuristics, troubleshooting budgets, continuation markers, commit discipline), (3) shared cross-agent state (lock files, a progress file, devlog-as-coordination-point).
Item (2) is largely absorbed: `/cdocs:iterate` shipped the verification-floor mechanism, freshness disciplines, and judge-based loop health, and `overseer-alignment` is in the process of codifying the remaining rule-level concerns (thin-lead dispatch discipline, context checkpointing, model tiering) that the RFP only gestured at.
Items (1) and (3) are **not** shipped and **not** covered by `overseer-alignment`, which explicitly punts multi-overseer coordination to "the `/oversee` skill's cross-agent coordination layer" (its own Edge Cases section).
The RFP already carries a NOTE pointing at `iterate-skill` as informational context; it should stay `state: live` / `status: request_for_proposal` but be narrowed (see recommendation below) so a future elaborator's remaining scope is legible instead of half-shipped.

**`2026-05-13-iterate-skill.md` — shipped, matches design.**
`plugins/cdocs/skills/iterate/SKILL.md`, `plugins/cdocs/skills/iterate/template.md`, `plugins/cdocs/skills/full-send/SKILL.md`, and `plugins/cdocs/agents/judge.md` all exist and implement the proposal's role taxonomy (Overseer/Implementer/Reviewer/Judge), turn-by-turn loop protocol, freshness disciplines, and accept-or-escalate termination.
The shipped skill extends the design in ways the proposal didn't fully specify: `-m|--model` and `-f|--first-round` model-selection flags, a `--dispatched` mode for the implementer, and a `review_proof` column (`confirmed`/`n/a`/`deferred-to-followup`/`skipped`) on the Iteration Log that formalizes "tests-pass-but-reviewer-says-Revise" into an auditable field.
This proposal's frontmatter (`status: review_ready`, `last_reviewed.status: accepted`) is stale relative to the shipped state; it should be updated to `implementation_accepted` per the convention used by the other recently-shipped proposals (`2026-05-18-iterate-agent-capabilities.md`, `2026-05-12-cdocs-rule-delivery-materialization.md`, both `state: live` / `status: implementation_accepted`).

**`2026-08-28-overseer-alignment.md` — live, open, revision pending.**
`review_ready` with a round-1 `revision_requested` verdict ([`2026-08-28-review-of-overseer-alignment.md`](../reviews/2026-08-28-review-of-overseer-alignment.md)).
The review is sound and identifies two blocking gaps the author has not yet revised for: (1) the rule-delivery model is mischaracterized (the `SessionStart` hook is a staleness nudge, not a content injector; `/cdocs:init` is the actual materialization engine and is currently unmentioned in Phase 1); (2) Pillar 2's judge-based context-bloat enforcement has no named logged signal, so "independent backing" is currently aspirational rather than real.
Four non-blocking items (judge-is-iterate-only scope, the weftwise model-tiering conflict, the CLAUDE.md-reseed assumption, and BLUF attribution) are also outstanding.
This is the document that should absorb the still-open overseer questions below; no state/status change is recommended here beyond what the pending revision already implies.

## Deduplicated Open Questions

Pulled from all three documents' Open Questions sections (plus RFP scope items that were never resolved elsewhere), deduplicated against what has already shipped or been decided.

### A. `/oversee` multi-proposal orchestration (unique to the RFP, still fully unbuilt)

1. **Invocation surface and phase-progression protocol** for chaining multiple proposals (`/oversee chain [...]`, `/oversee full <topic>`), distinct from `full-send`'s fixed propose-then-iterate pairing.
2. **AFK/autonomous continuation signal at the multi-proposal-arc level.** `/cdocs:iterate` has a per-loop AFK fallback (placeholder verification floor); nothing exists for "continue through all phases of a multi-proposal arc without asking."
3. **Cross-session durability for an interrupted multi-proposal arc**, distinct from `iterate`'s per-loop Iteration Log resumption. Needs a progress file or equivalent tracking which proposals in a chain are done.
4. **Shared state / lock files or claim markers** so concurrent agents (or concurrent overseers) don't collide on the same files. Explicitly out of scope for `overseer-alignment` v1 (its Edge Cases: "serialize: only one overseer runs at a time... the `/oversee` skill's cross-agent coordination layer handles this").
5. **Serialization vs. parallelization heuristics with real file-conflict detection.** `overseer-alignment`'s one-specialist-per-workstream bound is adjacent but does not solve "do these two agents touch overlapping files."
6. **Troubleshooting budgets** (isolate-first vs. full-cycle-retry debugging heuristic). Raised in the RFP's "Orchestration Rules" section; never addressed by `iterate` or `overseer-alignment`.
7. **Verification depth ladder** (compile-check → unit-test → integration-test → smoke-test → live-validation) as a reusable taxonomy declared per phase/skill, vs. `iterate`'s narrower `review_proof` marker which only distinguishes confirmed/n-a/deferred/skipped for a single loop.

### B. `/cdocs:iterate` loop refinements (raised in the iterate-skill proposal, not resolved by the shipped skill)

8. **Judge trigger cadence**: every-Nth-Revise-and-beyond (current shipped behavior) vs. once-then-overseer-discretion vs. a `--judge-after N --judge-cadence M` hybrid.
9. **Implementer structured-return schema**: freeform markdown vs. a named-header contract (`changes`/`verification_evidence`/`residual_uncertainties`) for judge legibility.
10. **Triage awareness of the Iteration Log / Judge Log**: should `/cdocs:triage` recommend workflow status based on latest review/judge verdicts in a devlog?
11. **User mid-loop participation controls**: `--pause-after N`, `--pause-on-judge`, or a mechanism to override a judge verdict.

### C. `overseer-alignment` frontier (live, the document's own stated Open Questions plus round-1-review gaps still pending author action)

12. **Rule file granularity**: keep `orchestration-discipline.md` combining Pillars 1-3, or split `context-discipline.md` out now vs. only if it grows unwieldy.
13. **Soft loop-cap default and unit** (turns/tokens/iterations) for `iterate`'s judge-observable termination signal; needs an empirical calibration pass.
14. **OpenCode capability parity** for `fork`/`SendMessage`-resume/`/compact` equivalents backing the durable-specialist pattern; degrade-to-fresh-session-plus-handoff is stated as acceptable but unconfirmed.
15. **Specialist naming convention** (`impl-proposal-N` style): formalize in a rule, or leave to overseer discretion?
16. **Handoff format enforcement**: should `/cdocs:triage` (or a future `/cdocs:audit`) enforce the Completed/Decisions Made/Open Todos handoff shape, or is it guidance only?
17. **[Blocking, pending author revision] Judge-observable thinness signal.** Pillar 2 claims the judge independently backs overseer context discipline, but the judge's permitted inputs (Iteration Log, review docs; no `usage.db`, no source) carry no context-size field today. A concrete additive Iteration-Log column (per-turn context estimate, dispatch ratio, or inline-work-performed flag) must be named before the enforcement claim is sound.
18. **[Blocking, pending author revision] Rule-delivery pipeline description.** The proposal must correctly name `/cdocs:init` as the materialization engine (not the `SessionStart` hook, which only emits a staleness nudge) and rewrite Phase 1's registration steps to the real surfaces (`AGENTS.md` `@rules/` lines, source-repo `CLAUDE.md` imports, `/cdocs:init`'s hardcoded AGENTS.md template).
19. **Model-tiering vs. consumer blanket-floor precedence.** The weftwise example currently contradicts the tiering shape it's cited to support (a blanket "never downgrade" floor, not a per-tier pin); the review's recommended default is "consumer floor always wins, shape is advisory," pending author confirmation.

## Recommended Frontmatter Changes

Recommendations only; not applied by this memo.

| Document | Current | Recommended | Rationale |
|---|---|---|---|
| `2026-03-26-rfp-oversee-skill.md` | `state: live`, `status: request_for_proposal` | **No state/status change.** Add a second NOTE (alongside the existing `iterate-skill` NOTE) pointing at `overseer-alignment` as covering the rule-level half of "Orchestration Rules," and at this memo's §A for the RFP's still-unbuilt scope. | The core `/oversee` ask (multi-proposal arcs, shared state, cross-agent coordination) is genuinely unshipped; marking it `evolved` would misrepresent it as superseded. Narrowing via cross-reference keeps it live and honest about remaining scope. |
| `2026-05-13-iterate-skill.md` | `status: review_ready`, `last_reviewed.status: accepted` (round 3) | `status: implementation_accepted` | Matches the convention used by the other two most-recently-shipped proposals (`2026-05-18-iterate-agent-capabilities.md`, `2026-05-12-cdocs-rule-delivery-materialization.md`), both `state: live` / `status: implementation_accepted`. The shipped skill matches the design (plus documented extensions); frontmatter should reflect that the implementation phase is done, not merely design-reviewed. |
| `2026-08-28-overseer-alignment.md` | `state: live`, `status: review_ready`, `last_reviewed.status: revision_requested` (round 1) | **No change.** Correctly represents "live, under revision." | This is the canonical live document; its own review cycle (blocking items #17-#18 above) is the right mechanism to advance it, not a consolidation-driven relabel. |

## Cross-Reference Pointers (optional, not applied)

If a maintainer wants pointers inline rather than only in this memo:
- `rfp-oversee-skill.md`: one NOTE line after the existing `iterate-skill` NOTE, naming `overseer-alignment` and this memo.
- `iterate-skill.md`: none needed beyond the frontmatter status change; it already NOTEs its relationship to the RFP and to a future `/oversee`.
- `overseer-alignment.md`: optionally a Background bullet noting this memo exists as the cross-document map, for a reader who lands there first.
