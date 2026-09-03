---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-01T12:00:00-07:00
task_list: cdocs/overseer-consolidation
type: proposal
state: live
status: implementation_accepted
tags: [oversee, agent_orchestration, cdocs_meta, consolidation, iterate, full_send]
last_reviewed:
  status: revision_requested
  by: "@claude-opus-4-8"
  at: 2026-09-03T10:30:00-07:00
  round: 1
  path: cdocs/reviews/2026-09-03-review-of-overseer-consolidation.md
---

# Overseer Proposal Consolidation

> BLUF: Three "overseer" documents overlap in scope but sit at different altitudes and different lifecycle stages.
> [`2026-03-26-rfp-oversee-skill.md`](2026-03-26-rfp-oversee-skill.md) is a request-for-proposal for a multi-proposal `/oversee` skill; its single-proposal-loop scope shipped as `/cdocs:iterate`, and its core multi-proposal-arc ask has now also shipped as `/oversee` (skill `plugins/cdocs/skills/oversee/` plus rule `plugins/cdocs/rules/oversee-arc.md`, proposal [`2026-09-03-overseer-arc.md`](2026-09-03-overseer-arc.md) `implementation_accepted`).
> [`2026-05-13-iterate-skill.md`](2026-05-13-iterate-skill.md) is that shipped single-proposal loop (`status: implementation_accepted`): `plugins/cdocs/skills/iterate/`, `full-send/`, and `plugins/cdocs/agents/judge.md` all exist and match the design.
> [`2026-08-28-overseer-alignment.md`](2026-08-28-overseer-alignment.md) is the canonical overseer-role document: it targets the overseer's own context/model hygiene rather than the loop protocol, is `status: implementation_accepted` (Phases 1-4 shipped, round-6 accepted), and is the document new overseer-scoped work should attach to.
> **Recommendation, now enacted: `overseer-alignment` is canonical for ongoing overseer work; `iterate-skill` is `implementation_accepted` (shipped, do not re-propose); `rfp-oversee-skill` stays live with its remaining multi-proposal-arc scope delivered by `overseer-arc`.**
> This memo is the maintained cross-document map for that workstream; the frontmatter changes it recommended have been applied to the tracked documents.

## Canonical Doc Decision

**`2026-08-28-overseer-alignment.md` is the canonical live document for overseer-role design.**
It is the one document addressing the overseer's own resource discipline (context growth, model tiering) rather than the loop protocol around it, and its accepted design threads the needle on how it relates to `iterate` (build on the Iteration Log, do not replace it) and to `/oversee` (Edge Cases: "the `/oversee` skill's cross-agent coordination layer handles this," multi-overseer coordination delegated to the arc layer).
Future overseer-scoped proposals should read `overseer-alignment` first and extend it rather than restart from the RFP.

## Status of Each Document

**`2026-03-26-rfp-oversee-skill.md`: remaining scope delivered; RFP kept live as the origin record.**
This RFP asked for three things: (1) an `/oversee` skill for multi-proposal project arcs, (2) orchestration rules (verification depth, serialization/parallelization heuristics, troubleshooting budgets, continuation markers, commit discipline), (3) shared cross-agent state (lock files, a progress file, devlog-as-coordination-point).
Item (2) is absorbed: `/cdocs:iterate` shipped the verification-floor mechanism, freshness disciplines, and judge-based loop health, and `overseer-alignment` (plus `orchestration-discipline.md` and `model-tiering.md`) codified the remaining rule-level concerns (thin-lead dispatch discipline, context checkpointing, model tiering) the RFP only gestured at.
Items (1) and (3) shipped as `/oversee`: proposal [`2026-09-03-overseer-arc.md`](2026-09-03-overseer-arc.md) (`implementation_accepted`) delivered the skill `plugins/cdocs/skills/oversee/` and rule `plugins/cdocs/rules/oversee-arc.md`, carrying the arc-state file, claim registry, and cross-agent coordination that `overseer-alignment` explicitly delegated to "the `/oversee` skill's cross-agent coordination layer."
The RFP carries a top NOTE pointing at `iterate-skill`, `overseer-alignment`, and this memo's §A; it now also points at `overseer-arc` as the shipped elaboration of its multi-proposal-arc scope. It stays `state: live` / `status: request_for_proposal` as the origin record for that lineage.

**`2026-05-13-iterate-skill.md`: shipped, matches design.**
`plugins/cdocs/skills/iterate/SKILL.md`, `plugins/cdocs/skills/iterate/template.md`, `plugins/cdocs/skills/full-send/SKILL.md`, and `plugins/cdocs/agents/judge.md` all exist and implement the proposal's role taxonomy (Overseer/Implementer/Reviewer/Judge), turn-by-turn loop protocol, freshness disciplines, and accept-or-escalate termination.
The shipped skill extends the design in ways the proposal didn't fully specify: `-m|--model` and `-f|--first-round` model-selection flags, a `--dispatched` mode for the implementer, and a `review_proof` column (`confirmed`/`n/a`/`deferred-to-followup`/`skipped`) on the Iteration Log that formalizes "tests-pass-but-reviewer-says-Revise" into an auditable field.
This proposal is `state: live` / `status: implementation_accepted`, matching the convention used by the other recently-shipped proposals (`2026-05-18-iterate-agent-capabilities.md`, `2026-05-12-cdocs-rule-delivery-materialization.md`); its frontmatter reflects that the implementation phase is done.

**`2026-08-28-overseer-alignment.md`: accepted and shipped.**
`state: live` / `status: implementation_accepted`, `last_reviewed.status: accepted`, round 6; Phases 1-4 have shipped. The two round-1 blocking gaps were resolved across rounds 2-6: the rule-delivery model now correctly names `/cdocs:init` as the materialization engine (the `SessionStart` hook is a staleness nudge, not a content injector), and Pillar 2's judge-based context-bloat enforcement is backed by named Iteration-Log signals (`overseer_thinness` plus `overseer_ctx_est` / `inline_work`). `model-tiering.md` shipped as its own rule alongside `orchestration-discipline.md`.
This is the canonical home for the still-open overseer questions below (§C).

## Deduplicated Open Questions

Pulled from all three documents' Open Questions sections (plus RFP scope items that were never resolved elsewhere), deduplicated against what has already shipped or been decided.

### A. `/oversee` multi-proposal orchestration (unique to the RFP, shipped as `overseer-arc`)

This scope shipped as `/oversee`: skill `plugins/cdocs/skills/oversee/`, rule `plugins/cdocs/rules/oversee-arc.md`, proposal [`2026-09-03-overseer-arc.md`](2026-09-03-overseer-arc.md) (`implementation_accepted`), whose stated scope boundary draws from this list. It remains the canonical decomposition of that scope; `overseer-arc` points back here as its authoritative scope brief. Where each item landed:

1. **Invocation surface and phase-progression protocol** for chaining multiple proposals (`/oversee chain [...]`, `/oversee full <topic>`), distinct from `full-send`'s fixed propose-then-iterate pairing. Delivered by the `oversee` skill's invocation parsing and per-proposal composition of `full-send`/`iterate`/`propose-revise`.
2. **AFK/autonomous continuation signal at the multi-proposal-arc level.** `/cdocs:iterate` has a per-loop AFK fallback (placeholder verification floor); the arc level needs "continue through all phases of a multi-proposal arc without asking." Delivered as the arc AFK field (seeded by `--afk`) in the arc-state file, conveyed to composed loops as dispatch-brief prose.
3. **Cross-session durability for an interrupted multi-proposal arc**, distinct from `iterate`'s per-loop Iteration Log resumption. Delivered by the durable `.claude/oversee/` arc-state file (schema in `oversee-arc.md`) tracking which proposals in a chain are done.
4. **Shared state / lock files or claim markers** so concurrent agents (or concurrent overseers) don't collide on the same files. Delegated out of `overseer-alignment` v1 and delivered by `oversee-arc.md`'s repo-global claim registry.
5. **Serialization vs. parallelization heuristics with real file-conflict detection.** `overseer-alignment`'s one-specialist-per-workstream bound is adjacent but does not solve "do these two agents touch overlapping files." Delivered by `oversee-arc.md`'s footprint-overlap serialize-vs-interleave test.
6. **Troubleshooting budgets** (isolate-first vs. full-cycle-retry debugging heuristic). Raised in the RFP's "Orchestration Rules" section. Delivered by `oversee-arc.md`'s troubleshooting-budget rule.
7. **Verification depth ladder** (compile-check → unit-test → integration-test → smoke-test → live-validation) as a reusable taxonomy declared per phase/skill, vs. `iterate`'s narrower `review_proof` marker which only distinguishes confirmed/n-a/deferred/skipped for a single loop. Delivered by `oversee-arc.md`'s verification-depth ladder, which generates each proposal's `--verification-floor`.

### B. `/cdocs:iterate` loop refinements (raised in the iterate-skill proposal, not resolved by the shipped skill)

8. **Judge trigger cadence**: every-Nth-Revise-and-beyond (current shipped behavior) vs. once-then-overseer-discretion vs. a `--judge-after N --judge-cadence M` hybrid.
9. **Implementer structured-return schema**: freeform markdown vs. a named-header contract (`changes`/`verification_evidence`/`residual_uncertainties`) for judge legibility.
10. **Triage awareness of the Iteration Log / Judge Log**: should `/cdocs:triage` recommend workflow status based on latest review/judge verdicts in a devlog?
11. **User mid-loop participation controls**: `--pause-after N`, `--pause-on-judge`, or a mechanism to override a judge verdict.

### C. `overseer-alignment` frontier (the document's own stated Open Questions; the round-1-review gaps #17-#19 are now resolved by its shipped Phases 1-4)

12. **Rule file granularity, decided.** Pillars 1-3 shipped combined in `orchestration-discipline.md`, with `model-tiering.md` split out as its own rule; `context-discipline.md` was not separated.
13. **Soft loop-cap default and unit** (turns/tokens/iterations) for `iterate`'s judge-observable termination signal; needs an empirical calibration pass.
14. **OpenCode capability parity** for `fork`/`SendMessage`-resume/`/compact` equivalents backing the durable-specialist pattern; degrade-to-fresh-session-plus-handoff is stated as acceptable but unconfirmed.
15. **Specialist naming convention** (`impl-proposal-N` style): formalize in a rule, or leave to overseer discretion?
16. **Handoff format enforcement**: should `/cdocs:triage` (or a future `/cdocs:audit`) enforce the Completed/Decisions Made/Open Todos handoff shape, or is it guidance only?
17. **Judge-observable thinness signal, resolved** (overseer-alignment Phase 2). The iterate Iteration-Log carries an `overseer_thinness` column plus `overseer_ctx_est` and `inline_work` dispatch/return fields; the judge keys `bloat_detected`/`escalate` off them, giving Pillar 2's context-discipline claim real independent backing.
18. **Rule-delivery pipeline description, resolved** (round-6 accepted revision). The proposal correctly names `/cdocs:init` as the materialization engine (the `SessionStart` hook only emits a staleness nudge) and Phase 1's registration steps target the real surfaces (`AGENTS.md` `@rules/` lines, source-repo `CLAUDE.md` imports, `/cdocs:init`'s AGENTS.md template).
19. **Model-tiering vs. consumer blanket-floor precedence, addressed.** `plugins/cdocs/rules/model-tiering.md` shipped as its own rule with the settled default "consumer floor always wins, shape is advisory."

## Frontmatter Changes (enacted)

The frontmatter changes this memo recommended have been applied to the tracked documents.

| Document | Status | Change | Rationale |
|---|---|---|---|
| `2026-03-26-rfp-oversee-skill.md` | `state: live`, `status: request_for_proposal` | **No state/status change (satisfied).** Top NOTE now points at `iterate-skill`, `overseer-alignment`, this memo's §A, and `overseer-arc`. | The `/oversee` multi-proposal-arc ask shipped as `overseer-arc`, not as a supersession of this RFP; keeping it live with cross-references preserves it as the origin record for that lineage. |
| `2026-05-13-iterate-skill.md` | `state: live`, `status: implementation_accepted` | **Satisfied.** Now `implementation_accepted`. | Matches the convention used by the other recently-shipped proposals (`2026-05-18-iterate-agent-capabilities.md`, `2026-05-12-cdocs-rule-delivery-materialization.md`); the shipped skill matches the design (plus documented extensions), and the frontmatter reflects that the implementation phase is done. |
| `2026-08-28-overseer-alignment.md` | `state: live`, `status: implementation_accepted`, `last_reviewed.status: accepted` (round 6) | **Accepted and shipped.** Phases 1-4 landed; the round-1 blocking items (#17-#18 above) were resolved across rounds 2-6. | The canonical overseer-role document; its own review cycle advanced it to accepted, and its frontmatter now reflects the shipped state. |

## Cross-Reference Pointers

- `rfp-oversee-skill.md`: its top NOTE points at `iterate-skill`, `overseer-alignment`, this memo's §A, and `overseer-arc` (the shipped elaboration of its multi-proposal-arc scope).
- `iterate-skill.md`: `implementation_accepted`; it already NOTEs its relationship to the RFP and to `/oversee`.
- `overseer-alignment.md`: optionally a Background bullet noting this memo exists as the cross-document map, for a reader who lands there first.
