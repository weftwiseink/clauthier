---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-10T11:50:03-07:00
task_list: clauthier/worktree-isolation-scope
type: devlog
state: live
status: done
tags: [architecture, orchestration, worktree, isolation, overseer, full-send]
---

# Worktree Isolation → Scope to Dispatched Agents, Not the Overseer: Devlog

## Objective

Loosen/remove worktree-isolation constraints so a **top-level session (overseer) is never
isolation-bound**. Isolation is a property of NESTED DISPATCHED agents (implement/review
subagents) only. The overseer must stay free to land (merge into `main` / resolve a worktree)
and fork (create a new worktree off `main`).

Driver: user request + report
`weftwise/main/cdocs/reports/2026-09-10-worktree-isolation-vs-overseer-guardrails.md`.

User correction to the report's framing: the binding constraint is clauthier-**authored** text
on existing commands (whose scope was meant to be nested-agents-only), not primarily the harness
sandbox. Primary work is the clauthier-side re-scope; harness-advocacy items are secondary
(relay/document only).

This is a `/cdocs:full-send`: `/cdocs:propose-revise` (author + review/revise to accept), then
`/cdocs:iterate` (implement-review to accept-or-escalate). I run both AS overseer.

## Plan

1. Devlog (this file). ✅
2. propose-revise loop: dispatch `/cdocs:propose` → review/revise until accept.
3. iterate loop: dispatch implement/review/judge until accept-or-escalate.
4. Land per repo workflow.

## Overseer Iteration Log

| Turn | Phase | Action | Dispatched | Result | Ctx est. | Inline work |
|------|-------|--------|-----------|--------|----------|-------------|
| 0 | setup | grounding read (report + clauthier surfaces), devlog scaffold | — (inline, setup) | devlog created | ~55K | grounding only |
| 1 | propose | author proposal | opus general-purpose | `review_ready`, commit `edfa0b2` | ~70K | none |
| 1b | interim | strip worktree-containment language on clauthier main | sonnet general-purpose | done, commit `de34bee` (iterate:18 clause removed) | ~72K | none |
| 2 | interim | same interim removal in weftwise + map weftwise cross-worktree surfaces | sonnet general-purpose | done: NOTHING to remove in weftwise; surfaces mapped; no commit | ~78K | none |
| 3 | revise | fold weftwise (document+route) + design decisions into proposal | proposer (resumed) | commit `5f3bbfd`, review_ready | ~82K | none |
| 4 | review | fresh review of revised proposal | cdocs:reviewer (opus) | **Accept** r1, 0 blocking, 3 nits; review at cdocs/reviews/2026-09-10-review-of-worktree-isolation-scope.md | ~84K | none |
| 5 | nit-fix | clear 3 accepting-round nits + set implementation_ready | proposer (resumed) | done, commit `2881eab`, **implementation_ready** | ~86K | none |
| 6 | implement | execute accepted proposal (Phases 1-5) | general-purpose (opus), /cdocs:implement --dispatched | done: 6 commits `45abcb7..4c72b00`, all 6 checks pass | ~88K | none |
| 7 | review | fresh review of implementation | cdocs:reviewer (opus) | **ACCEPT** r2, 0 blocking, 4 nits + 1 generalize-rec; review at cdocs/reviews/2026-09-10-review-of-worktree-isolation-scope-impl.md | ~90K | none |
| 8 | nit-fix | clear impl nits (em-dash/semicolon, generalize routing) | implementer (resumed) + overseer footprint one-liner | done, commit `b90818a` | ~90K | footprint 1-liner + devlog (overseer-owned) |
| 9 | finalize | overseer terminal gate + status transitions | — (inline: 3 grep checks, 2 one-line frontmatter edits) | proposal → implementation_accepted; devlog → done | ~92K | terminal gate (allowed) |

## Iterate TERMINAL: Accept (impl round 1 / review round 2)

All 6 checks pass independently. Overseer nit decisions (all non-blocking): (1) 6 em-dashes → colons;
(2) reduce semicolon density in the 3 flagged sentences; (3) tidy "Claim Registry" heading pointer;
(4) add oversee/SKILL.md to proposal footprint — **overseer did this inline** (`2881eab`-descendant, proposal file, single-writer); (5) ADOPT reviewer option B: generalize the routing pattern in the
canonical rule (orchestration-discipline.md) so it does NOT hardcode weftwise command names as the
mechanism (materializes to arbitrary consumers) — demote /resolve-wt,/dogfood-wt,/worktree to an
illustrative example. Implementer applies 1,2,3,5 on the skill/rule files.

## Implementation landed (impl round 1)

Files touched (all `plugins/cdocs/`): `rules/orchestration-discipline.md` (P1 canonical subsection L69-82;
P5 routing L76-78 + advisory spec-note L67), `rules/oversee-arc.md` (P4 claim-registry contrast L63),
`agents/reviewer.md` (P3 L45), `skills/implement/SKILL.md` (P3 L30), `skills/iterate/SKILL.md` (P2 L15
floor+pointer; P3 L131/L190-192; P5 routing pointer L93), `skills/oversee/SKILL.md` (P5 routing pointer L100).
Commits: 45abcb7 (P1), 66b9c4f (P2), 861985c (P3), 6c5a349 (P4), 4c72b00 (P5). Canonical principle stated
ONCE in orchestration-discipline.md; all else pointers. No weftwise edit. build:cdocs re-run warranted
before next OC publish (rules changed), not required in-commit; output gitignored.

## Loop 2 (iterate) started

Proposal `2881eab` implementation_ready. Verification-floor: post-edit leak grep on overseer-facing
skills yields no overseer-applicable containment phrasing (FAIL = a surviving "contain the workstream"
bound to the session); principle defined exactly once in orchestration-discipline.md with skills as
pointers only (FAIL = two full statements); no weftwise edit (FAIL = any weftwise change).
Implementer instructed NOT to touch this devlog (overseer owns it, single-writer) — reports Changes
Made in its summary.

## Propose-revise TERMINAL: Accept (round 1)

Reviewer verified every load-bearing claim against live tree + weftwise (read-only). Overseer
decisions on the 3 nits (all non-blocking): (1) fix misattributed line ref; (2) adopt reviewer rec —
replace read-only isolation probe with UNCONDITIONAL precondition-surfacing/routing (probe tests the
wrong axis: reads are allowed under a write-scoped lock); (3) tighten the two 4×-repeated framing
points to one statement each (brevity), preserving the required inline floor. Then status →
implementation_ready for the iterate loop.

NOTE: proposer correction — the interim SKILL-only fix needed no re-init, but the proposal's canonical
principle lands in a RULE (orchestration-discipline.md), which DOES materialize; implementing it
propagates to consumers via /cdocs:init freshness. Distinct from the interim fix's containment.

## Turn-2 finding (decisive)

weftwise has **no** session-confining worktree language. The offending sentence lived ONLY in
clauthier `iterate/SKILL.md`; per the plugin's Rules Integration, **only `rules/*.md` materialize
downstream, never skill content**, so it never reached weftwise. The immediate disruption is fully
resolved by `de34bee`. Materialized-rules markers in weftwise (`v0.1.0`, hash `4f7ec2ba…`) match the
plugin and are unaffected by a skill-only fix → **no `/cdocs:init` re-run needed** for this fix.

weftwise cross-worktree commands are all legitimate KEEP (their PURPOSE is cross-worktree):
- `/resolve-wt` (`.claude/commands/resolve-wt.md`): Step 2 (~L73-96) runs `git merge <branch>` FROM the target's worktree, gated on `pnpm gate` exit 0.
- `/dogfood-wt`, `scripts/worktree.sh cmd_add` (fork off base via `git worktree add -b`), `/worktree`,`/wt`.

⇒ The report's `/resolve-wt` collision was the **harness sandbox**, not authored confinement.
Weftwise's role in the proposal is therefore DOCUMENT + ROUTE (isolation-aware skills) + the
harness-advocacy appendix — NOT code removal.

## Overseer design decisions (fed to reviser)

- Q1 Phase-5 warn-not-refuse advisory → **spec-note only**, build deferred to a dedicated hooks proposal.
- Q2 canonical location → state the principle **once** in `orchestration-discipline.md` (beside "hard
  tool-allowlist … not available"), referenced by skills via thin inline floor. Dedup convention.
- Q3 weftwise scope → RESOLVED above (document+route, nothing to remove).

## Interim hotfix (user-requested, parallel to the loop)

User: downstream work is disrupted; remove the isolation levels entirely on `main` until the
proposal resolves. Dispatched a sonnet agent to strip the authored worktree-CONTAINMENT language
(prime suspect `iterate/SKILL.md:18`), keeping review-integrity/freshness boundaries, single-writer,
and the claim registry intact. Footprint `plugins/cdocs/{skills,agents,rules}/**` — disjoint from
the proposer (which owns `cdocs/proposals/**` + this devlog). The proper fix (re-introduce isolation
scoped to dispatched agents) is the proposal; this removal is temporary.

RECONCILE LATER: the interim removal changes the exact text the proposal cites (`iterate:18`).
Reviewer/iterate must reconcile against LIVE tree state, not the proposal's "before" citations.

## Proposer open questions (for review/iterate)

1. Phase-5 warn-not-refuse advisory: spec-note now vs defer to a hooks proposal (proposal defaults to spec-note-only, optional).
2. Isolation-detect probe: inline in skills vs a shared rule both reference (leaning shared-rule).
3. `/resolve-wt` + off-`main` fork surfaces named by the report were NOT found in THIS repo (likely live in `weftwise`) — routing guidance must target a real surface. **RESOLVED (user):** if weftwise skills have the same problem, fix them now AND include weftwise in the proposal's scope. Turn-2 agent investigates + interim-removes in weftwise.

## Key surfaces (grounding, for the proposer brief)

- `plugins/cdocs/skills/iterate/SKILL.md:18` — "worktree usage practices … contain the workstream" (ambiguous scope).
- `plugins/cdocs/agents/reviewer.md:45,49-51` — nested-agent boundaries (correct home for isolation language).
- `plugins/cdocs/rules/orchestration-discipline.md:59` — "a hard tool-allowlist on the top-level session is not available"; graded enforcement (3 layers); Phase-5 advisory hook (not built).
- `plugins/cdocs/rules/oversee-arc.md:57-81` — claim registry (cooperative clobber-safety to promote to first-class).
- `plugins/cdocs/skills/{oversee,full-send}/SKILL.md` — confirm nothing confines the overseer to a worktree.

## Decisions Made

- Thesis fixed by the user; the proposal must not re-open whether the overseer should be isolated.

## Verification

Overseer terminal gate re-run against the live tree at HEAD `b90818a` (all PASS):

**Check 1 — leak grep** (`iterate`, `oversee`, `full-send`, `propose-revise`): `full-send`/`propose-revise`
zero hits. Every `iterate`/`oversee` hit binds the DISPATCHED agent or explicitly states the overseer
is NOT isolation-bound (`iterate:15,93,131,192`; `oversee:100`). No overseer-session containment survives.

**Check 2 — canonical single-source**: exactly ONE definition heading —
`plugins/cdocs/rules/orchestration-discipline.md:69 ### Isolation is a dispatched-agent property`.
Every other occurrence is a section-reference pointer.

**Check 6 — scope**: `git diff --name-only 45abcb7~1 HEAD` touches only the 6 `plugins/cdocs/{rules,skills,agents}`
files. The 3 "weftwise" strings in the diff are the illustrative routing EXAMPLES (`e.g. in weftwise: …`),
not edits to the weftwise repo (which was never modified).

## Outcome (full-send complete)

- **Interim unblock (user's urgent ask):** clauthier `main` `de34bee` removed the one session-confining
  line; weftwise needed no change (skills don't materialize; only `rules/*` do). Downstream unblocked.
- **Durable fix (this proposal), landed directly on `main`:** commits `45abcb7 66b9c4f 861985c 6c5a349
  4c72b00 b90818a`. Principle canonical once in `orchestration-discipline.md`; skills carry thin floor +
  pointers; claim registry promoted to first-class overseer clobber-safety; loop skills isolation-AWARE
  (unconditional route/warn, never refuse); harness-advocacy in Appendix A; Phase-5 PreToolUse advisory
  is a spec-note (build deferred to a future hooks proposal).
- **No branch to land:** all work is on `main` (session is on `main`; subagents share the worktree), so
  no `/resolve-wt`/merge step was needed.

### Follow-ups (non-blocking)
- `npm run build:cdocs` before the next OpenCode publish (rules changed; output gitignored/CI-built).
- Consumers get nudged to re-run `/cdocs:init` via the SessionStart freshness hook (rule-content hash changed).
- Harness-facing issue for Appendix A asks (write-scoped lock, compound-aware parsing, per-op unlock) — optional.
- Reviewer's deferred Phase-5 note: a dedicated hooks proposal to actually build the warn-not-refuse advisory.
