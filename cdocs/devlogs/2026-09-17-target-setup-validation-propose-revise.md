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
| 2 | reviser | CANCELLED — user redirected direction | superseded | ~95K | devlog edit + commit |
| 1' | proposer | /cdocs:propose (dispatched, REDIRECTED) | review_ready; new proposal `mcp-tool-effectiveness-ablation.md` | ~150K | devlog edit + commit |
| 1' | reviewer | cdocs:reviewer (fresh) | REVISE: 3 must-fix (cheap), direction sound | ~165K | devlog edit + commit |
| 2' | reviser | same proposer resumed (narrow) | pending | — | — |

Review 1' (REVISE): `cdocs/reviews/2026-09-17-review-of-mcp-tool-effectiveness-ablation.md`.
Must-fix: (1) single-shot admissibility guard missing from scorecard.json (machine) though D7
gate consumes it -> add `trials`+`gate_admissible`, single-shot indicative-only never
gate-consumable; (2) tool-invocation detection self-contradictory (names transcript AND payload)
-> commit to full-transcript `tool_use` blocks, define "invoked" crisply (error calls count;
decide aborted case); (3) two load-bearing capabilities (single-tool per-subagent gating D4;
per-tool-call transcript visibility) asserted not de-risked -> name as Phase 1 preconditions
with fallbacks. Verified SOUND: per-arm metering attribution, reset-safety (fresh worktrees),
frontmatter (old proposal evolved+pointer), blinding ceiling. Nits: token-delta framing,
worktree teardown --force, dirty-base semantics, CC-only-v1 posture, evaluator input size.

Redirected proposal: `cdocs/proposals/2026-09-17-mcp-tool-effectiveness-ablation.md` (BLUF 466 chars).
`/cdocs:ablate` skill, two arms (assisted/unassisted) each in a FRESH worktree off same base
commit (no `git stash`); usage precondition -> VOID if tool not actually invoked; outcomes
VALID/VOID/TASK-FAIL (salvaged PASS/ABSENT/FAIL); opus evaluator w/ partial blinding ->
scorecard.json+.md (token delta, indicative wallclock, signed -10..+10 context-gap, qualitative).
Variance: single-shot-caveat (Ph1-2) then N-trials default 3 (Ph3). Metering: harness payload
subagent_tokens/duration_ms (CONFIRMED real by overseer — present in every subagent completion
payload). Old proposal set `evolved` w/ pointer. Investigation Requested: tool-invocation
detection robustness, path-divergence confound, evaluator blinding ceiling, single-shot admissibility.

**USER REDIRECT (2026-09-17):** The accepted declarative-manifest direction is NOT what the
user wants. Quote: "why would we need this? Seems like the wrong direction. Verification
should be like, a cli util or slash command that verifies our workflows get access to and use
the expected mcp setup and they are effective based on some comparison with an unassisted
request." New framing: an ON-DEMAND CLI util / slash command (not an in-loop per-target test
manifest) that verifies cdocs workflows (a) have ACCESS to the expected MCP setup, (b) actually
USE it, and (c) are EFFECTIVE vs an unassisted baseline (assisted-vs-unassisted ablation).
This operationalizes the graphify proposal's discriminator-first "prove it helped" thesis.
Accepting-round nit-polish on the old proposal is MOOT — do not run reviser round 2.
The old proposal (`...-target-setup-validation-and-verification.md`, accepted R1) will be
marked superseded/evolved once the redirected proposal exists; salvage its reusable parts
(PASS/ABSENT/FAIL outcome taxonomy; the lace command/reachability findings).
Blocked pending user answer on the effectiveness dimension (what the A/B comparison measures),
then dispatch a FRESH proposer for the redirected proposal.

**RESOLVED — user's concrete design (2026-09-17, "composite"):** an on-demand CLI util /
slash command that runs an assisted-vs-unassisted ABLATION for a given MCP tool (graphify
first) and emits a scorecard. Mechanism (verbatim intent):
1. One subagent GETS the tool result (graphify) and rolls out to the end of its turn (assisted arm).
2. Write token usage + overall speed (wallclock) to a file.
3. STASH the work (reset workspace to identical baseline).
4. Do the same WITHOUT the tool (unassisted arm), meter again.
5. EVALUATOR compares the two, producing a scorecard:
   - token usage; - speed (wallclock);
   - context gap: signed scale, +10 = tool surfaced critical info the agent would have missed,
     -10 = tool result confused the agent / cost time or context;
   - qualitative result assessed by the evaluator.
Precondition (from earlier requirement): verify the assisted arm actually HAS ACCESS to and
USES the tool, else the comparison is void (report void, not "no effect"). Reset safety: the
shared git stash is cross-worktree-hazardous -> design reset via fresh worktree or WIP commit,
NOT bare `git stash`. Metering source: harness already surfaces subagent_tokens + duration_ms
in Task results. Fresh proposer dispatched for a NEW proposal; old accepted manifest proposal
-> mark `evolved` (superseded), salvage its PASS/ABSENT/FAIL honesty taxonomy + lace findings.

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
