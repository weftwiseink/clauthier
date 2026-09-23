---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-22T10:00:00-08:00
task_list: code-graph/cdocs-integration
type: devlog
state: live
status: done
tags: [cdocs, propose-revise, graphify, token_efficiency, scoping]
---

# graphify-cdocs-integration scoping revision (propose-revise): Devlog

## Objective

Overseer log for a `/cdocs:propose-revise` loop that RE-AIMS the accepted-but-unbuilt core proposal
[`cdocs/proposals/2026-09-17-graphify-cdocs-integration.md`](../proposals/2026-09-17-graphify-cdocs-integration.md)
against what changed under it since it was written, so the maintainer can `/full-send` a reduced first
increment. This is "Path A": a short scoping revision, NOT a rewrite — the proposal's spine (recall-parity
hard gate D2; CRDT blind spot D3; librarian deferred D1) stays intact.

## Turn 0 Brief — the four re-aim points

1. **Reconcile Phase 1 against the now-accepted ablation harness.** `/cdocs:ablate`
   ([`cdocs/proposals/2026-09-17-mcp-tool-effectiveness-ablation.md`](../proposals/2026-09-17-mcp-tool-effectiveness-ablation.md),
   `implementation_accepted`, e2e-verified) already answers the per-task "does scoping pay?" discriminator
   via assisted-vs-unassisted A/B. So Phase 1 should NOT build the risky per-PHASE token-attribution meter;
   restructure it to (a) lean on the ablation harness for the discriminator verdict, and (b) reduce its own
   live instrumentation to the proposal's already-documented COARSE fallback (per-role totals + read-token
   proxy). This shrinks the riskiest phase.
2. **Lock CLI-first throughout.** The proposal was authored MCP-first; we've since established CLI-first
   (graphify MCP is shadowed by the config over-mount bug; report
   [`cdocs/reports/2026-09-17-graphify-mcp-vs-cli-value-add.md`](../reports/2026-09-17-graphify-mcp-vs-cli-value-add.md)
   concluded CLI-sufficient; D4 NOTE already added). Reframe Phase 2's "tool/MCP surface" as a CLI-backed
   scoping surface; the engine-agnostic adapter (Phase 5) stays the eventual seam.
3. **Multi-file task targeting (from real e2e data).** The ablate e2e Probe A (single-file `explain` task)
   scored `context_gap 0` — graphify bought nothing, honestly. graphify's value is multi-file BLAST-RADIUS /
   dependent-set navigation, not single-file lookups. The scoping surface AND the discriminator gate (Phase 3)
   must target dependent-set task shapes; single-file lookups are expected-null and must not be read as
   "no value." Fold this into the design + Test Plan.
4. **Settle the license precondition.** graphify license re-verification is an explicit Phase 2 precondition
   (Open Questions). Sharpen it: state it crisply and resolve if determinable, else keep it as a hard gating
   precondition (do not bury it).

**Deliverable:** a revised proposal that makes an explicit **reduced FIRST INCREMENT to full-send** —
Phase 1 (coarse) + Phase 2 (reviewer scoping surface, CLI-backed) — with P3 measurement, P4 librarian, and
P5 adapter deferred/conditional (largely already deferred). Loop to accept, then HOLD: the maintainer
decides the full-send.

## Iteration Log

| Round | Role | Dispatch | Return | Overseer ctx | Inline |
|-------|------|----------|--------|--------------|--------|
| 0 | overseer | scaffolded devlog + briefed reviser | — | ~120K | devlog write |
| 1 | reviser | cdocs:proposer (Path-A revision, dispatched) | done; 5 commits cdd20b4..bf181ef; status→review_ready; license RESOLVED Apache-2.0; first-increment boundary added | ~130K | devlog edit + commit |
| 1 | reviewer | cdocs:reviewer (fresh, dispatched) | ACCEPT round 3; all 4 points integrated, spine intact, boundary actionable; 1 should-fix + 2 nits | ~140K | devlog edit |
| 2 | reviser | cdocs:proposer (resumed, clear accepting-round items) | done; 3 commits 1b86e58/22fac05/220936e; recall framing qualified, D1 nit neutralized, status→implementation_ready | ~150K | overseer-verified |

**LOOP COMPLETE — scoping revision ACCEPTED (r3), accepting-round items cleared.** Overseer verified:
`status: implementation_ready`, proposal tree clean, no stale MCP-first / per-phase-meter phrasing, recall
parity reads structural-in-increment-1 / measured-at-Phase-3, license RESOLVED Apache-2.0 (residual = pin
spot-check only). First-increment boundary (Phase 1 coarse meter + delegated `/cdocs:ablate` discriminator;
Phase 2 reviewer-first CLI-backed scoping surface) is green-lightable on its own; Phases 3–5 deferred, each
gated on the prior. HELD for maintainer full-send decision.

Review 1: `cdocs/reviews/2026-09-22-review-of-graphify-cdocs-integration-scoping-revision.md` (ACCEPT r3).
Accepting-round items routed to reviser: [should-fix] qualify first-increment intro — recall parity is
STRUCTURALLY protected in incr 1 (additive + skip-scope + flag), MEASURED at Phase 3 (do NOT pull a recall
check into Phase 2 = scope inflation); [nit N1] neutralize D1 exemplar to "CLI or MCP"; [nit N2] dense top
NOTE — leave (permitted). Then status → implementation_ready. Overseer chose the qualify-intro option over
adding a Phase-2 recall check (keeps the first increment lean + honest); flagged to maintainer, overridable.

## Decisions Made

- Path A (scoping revision), not a rewrite; spine preserved.

## Open Todos

- [x] Reviser round 1 (5 commits); Review round 1 (ACCEPT r3); accepting-round items cleared (3 commits).
- [x] Proposal at `implementation_ready`, overseer-verified.
- [ ] HOLD: maintainer full-send decision on the first increment (Phase 1 + Phase 2). Loop does not
  proceed to `/full-send` without explicit go.
