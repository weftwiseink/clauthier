---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-17T15:00:00-08:00
task_list: cdocs/target-setup-validation
type: devlog
state: live
status: wip
tags: [cdocs, verification, testing, devcontainer, tooling]
---

# Target setup-validation and test-verification (propose-revise loop): Devlog

## Objective

Overseer log for a `/cdocs:propose-revise` loop producing a proposal for a general cdocs
capability: **basic test verification and setup/environment validation of a given target
repo/environment**. Motivated by cdocs loops now producing/executing actual code (the
accepted graphify-cdocs integration; the lace-graphify devcontainer work running in
parallel), not just documents. cdocs needs a reusable way to confirm a target's environment
is correctly set up and its basic tests pass before/within an implement-review loop, rather
than hand-rolling verification per target.

Runs in PARALLEL with Workstream A (lace graphify -> clauthier lace devcontainer via
/iterate), which is the motivating concrete first consumer.

## Plan

Overseer-mode `/cdocs:propose-revise`: fresh proposer (`/cdocs:propose`), then alternate
fresh `cdocs:reviewer` rounds until accept-or-escalate. AskUserQuestion after 6 rounds.

## Iteration Log

| Round | Role | Dispatch | Return | Overseer context | Inline work |
|-------|------|----------|--------|------------------|-------------|
| 0 | overseer | scaffolded devlog + briefed proposer | — | ~60K | devlog write |
| 1 | proposer | /cdocs:propose (dispatched) | review_ready; proposal written | ~75K | devlog edit + commit |
| 1 | reviewer | cdocs:reviewer (fresh) | ACCEPT round 1; 1 must-resolve + 4 non-blocking + 3 nits | ~90K | devlog edit + commit |
| 2 | reviser | same proposer (clear accepting-round items) | pending | — | — |

Review 1 (ACCEPT): `cdocs/reviews/2026-09-17-review-of-target-setup-validation-and-verification.md`.
Reviewer set target `last_reviewed.status: accepted` round 1. Empirically confirmed lace
invents no reachability cmd; no glob collision; cited surfaces accurate.
Accepting-round items to clear:
1 [must-resolve-before-Phase2] manifest format TOML vs JSON — reviewer rec JSON (zero-dep TS);
  ROUTED TO USER (public hand-authored contract).
2 skip-with-note on FAIL undefined -> degrade to warn.
3 ABSENT -> review_proof mapping nondeterministic (skipped OR n/a) -> pin the rule.
4 add human/overseer escalation hatch for a block env check w/ no reprovision that fails transiently.
5 Phase 3 split env gate READ-checks (dispatchable) vs MUTATE-actions (lace up/doctor --reset, overseer-routed).
6 BLUF ~534 chars (>500). 7 dedup thrice-repeated validate/doctor statement. 8 Phases 2-4 what-not-to-change.

Proposal: `cdocs/proposals/2026-09-17-target-setup-validation-and-verification.md`
Design: target declares verification in `cdocs/verify.toml` (groups env/smoke/test);
cdocs owns runner + outcome taxonomy PASS/ABSENT/FAIL (ABSENT never coerced to PASS; PASS
cites artifact). 4 failure policies (block/warn/reprovision/skip-with-note) decoupled from
outcome. Gate1 env = precondition (Turn 0 / pre-phase); Gate2 smoke per-phase + full test
pre-accept, maps onto iterate `review_proof`. Manifest-absent -> warn-floor (npm test, lace
validate). 4 phases. Lace: confirmed cmds doctor|resolve-mounts|up|validate (v0.1.0); NO
confirmed in-container health/reachability query -> left as target-declared probe (do-not-invent).
Watch: BLUF ~510 chars (>~500 guideline); Investigation Requested = manifest fmt/location,
block-vs-warn default, runner/overseer-thinness boundary, self-referential-verification risk.

## Decisions Made

- New clauthier proposal (cdocs capability), parallel to the lace-devcontainer workstream.

## Open Todos

- [ ] Proposer round 1; capture path.
- [ ] Review round 1.
