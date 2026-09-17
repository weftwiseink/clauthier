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
| 1 | reviewer | cdocs:reviewer (fresh) | pending | — | — |

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
