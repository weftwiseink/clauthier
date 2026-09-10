---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-10T11:51:44-07:00
task_list: clauthier/worktree-isolation-guardrails
type: proposal
state: live
status: implementation_ready
footprint:
  - "plugins/cdocs/rules/orchestration-discipline.md"
  - "plugins/cdocs/rules/oversee-arc.md"
  - "plugins/cdocs/agents/reviewer.md"
  - "plugins/cdocs/skills/implement/SKILL.md"
  - "plugins/cdocs/skills/iterate/SKILL.md"
tags: [architecture, orchestration, worktree, clauthier]
last_reviewed:
  status: accepted
  by: "@claude-opus-4-8"
  at: 2026-09-10T14:30:00-07:00
  round: 1
---

# Scope Worktree-Isolation to Dispatched Agents, Not the Overseer

> BLUF: Worktree isolation binds NESTED DISPATCHED agents (implementer, reviewer), NEVER the top-level overseer/session. State this ONCE canonically in `orchestration-discipline.md` (Graded Enforcement, adjacent to the "hard tool-allowlist on the top-level session is not available" line); skills keep only a thin inline floor plus a reference. The one ambiguous authored line (`iterate`'s "contain the workstream") was interim-removed in `de34bee` and must NOT be restored. The report's `/resolve-wt` mid-merge collision was the HARNESS SANDBOX confining the session, not authored confinement, so clauthier's durable contribution is (a) the canonical principle, (b) isolation-AWARE loop skills that surface cross-worktree steps and ROUTE/WARN (route to weftwise's `/resolve-wt`, `/dogfood-wt`) instead of dead-ending, and (c) a harness-advocacy appendix. No weftwise source edit is required.

## Summary

A `/oversee` session locked to its own worktree ran a full overseer arc fine but could not LAND it: the resolve step's merge into `main` and a fork of a new worktree off `main` are cross-worktree writes the lock refused (motivating report, `weftwise` repo: `cdocs/reports/2026-09-10-worktree-isolation-vs-overseer-guardrails.md`).
Attribution is split (see the Background NOTE); the separate ambiguous authored line (`iterate`'s "contain the workstream", which a reader could apply to the overseer session) was interim-removed in `de34bee` and must not be restored.

The durable clauthier contribution is threefold: state the isolation principle canonically once, make the loop skills isolation-AWARE (detect + route/warn, never refuse), and relay the harness asks as advocacy.
Isolation is what makes a fresh reviewer's verdict trustworthy and keeps an implementer from clobbering a sibling; the overseer's clobber-safety comes from the cooperative claim registry plus single-writer ownership, NOT from a session-wide lock.
No weftwise SOURCE edit is needed: its cross-worktree commands are legitimate and are the routing targets an un-isolated overseer drives.
> NOTE(opus/clauthier/worktree-isolation): The "no `/cdocs:init` re-run" property holds cleanly for the interim SKILL-only fix (`de34bee`), because only `plugins/cdocs/rules/*.md` materialize downstream (README "Rules Integration") and SKILL content never does, so weftwise's rules markers (v0.1.0) stayed valid.
> This proposal's canonical principle, by contrast, lands in a RULE (`orchestration-discipline.md`), which DOES materialize: applying it changes the rule-content hash, so the SessionStart freshness hook will nudge downstream consumers to re-run `/cdocs:init` and pick it up. That is the intended delivery path, not extra weftwise work.

## Objective

A top-level session running `/oversee`, `/iterate`, `/full-send`, `/propose-revise`, or a resolve/land/fork step must NEVER carry a worktree-isolation restriction.
Isolation is intended to bind only nested dispatched agents.
An ambiguous authored line risked being read as confining the overseer (interim-removed in `de34bee`).
Neither authored prose nor the harness sandbox should confine the overseer's legitimate cross-worktree work: landing a branch into `main`, resolving a worktree, and forking a new worktree off `main`.

Goal: make the isolation principle explicit and single-sourced, audit every authored surface for phrasing that a reader could apply to the overseer (positively re-scoping, not merely deleting), and align the loop skills with clauthier's already-designed graded + cooperative safety model.

## Background

- **Motivating report** (authoritative observation set): `weftwise` repo, `cdocs/reports/2026-09-10-worktree-isolation-vs-overseer-guardrails.md` (a sibling repo, not linkable relative from here).
  Its 5 recommendations (prefer the cooperative model, make loop skills isolation-aware, surgical harness guard, build the Phase-5 advisory, separate the two guardrail intents) are input here, re-framed around the nested-vs-overseer scoping thesis.
  > NOTE(opus/clauthier/worktree-isolation): Attribution is split, not singular.
  > (1) An ambiguous authored line (`iterate`'s "contain the workstream") could be read as confining the overseer; it was interim-removed in `de34bee`.
  > (2) The report's actual `/resolve-wt` mid-merge collision was the harness sandbox (Appendix A), a real but out-of-scope-to-change concern.
  > clauthier's durable fix is the canonical principle plus isolation-aware skills, plus advocacy for the harness.

- **Existing graded enforcement** ([orchestration-discipline.md](../../plugins/cdocs/rules/orchestration-discipline.md) "Graded Enforcement", line 59): "a hard tool-allowlist on the top-level session is not available, since it is the user's own session." Three graded layers back overseer discipline (written rule + self-check; judge-remit backstop; an optional unbuilt Phase-5 `PreToolUse` advisory). A session-wide worktree lock contradicts this model: it is a HARD control in a GRADED system.

- **Existing cooperative model** ([oversee-arc.md](../../plugins/cdocs/rules/oversee-arc.md) "Claim Registry", lines 57-81): `.claude/oversee/claims/` plus Pillar 1b single-writer ownership already give cross-session, cross-worktree clobber-safety WITHOUT locking a session to one worktree. This is the overseer-controlled guardrail the user is asking for; it just needs promotion to first-class in prose.

## Proposed Solution

### The principle, stated canonically once

Isolation binds DISPATCHED agents; the overseer/top-level session is NEVER isolation-bound.

Canonical home: a short new subsection in [orchestration-discipline.md](../../plugins/cdocs/rules/orchestration-discipline.md) under "Graded Enforcement", since that file is already the single source of truth for overseer mode and already establishes that the top-level session cannot be hard-locked.
Everything else references it; nothing restates it (deduplication is a project value).

Draft canonical prose (final wording an implementer detail):

> **Isolation is a dispatched-agent property.**
> Worktree/filesystem isolation and the fresh-context freshness invariant bind DISPATCHED agents (the implementer, the reviewer), never the top-level overseer session.
> A dispatched agent is isolated so its verdict is trustworthy and it cannot clobber a sibling workstream.
> The overseer is deliberately NOT isolated: it must land branches into `main`, resolve worktrees, and fork new worktrees off `main` as normal cross-worktree work.
> Overseer clobber-safety is COOPERATIVE (the claim registry + single-writer ownership), not a session-wide lock, consistent with graded-not-hard enforcement above.

The two guardrail intents the report separates map cleanly onto this: protecting a sibling agent's in-flight worktree is the claim registry's job (cross-session cooperative); keeping the overseer thin is the discipline/judge's job. Neither is served by a blanket session lock, and the lock breaks the legitimate third case (landing/forking).

### Audit of authored surfaces

Every match for `worktree|isolat|contain|sandbox` across `skills/`, `agents/`, `rules/` was inspected against LIVE tree state (post-`de34bee`). Classification: RESOLVED (leak-prone phrasing already interim-removed; guard against restoration), NESTED (correctly binds a dispatched agent, confirm/tighten), CANONICAL (should host or reference the principle), CLEAN (no action).

| Surface | Line | Current intent | Class | Edit intent |
|---|---|---|---|---|
| `skills/iterate/SKILL.md` | 18 | containment clause **interim-removed in `de34bee`**; line now reads "Code and cdocs should be committed early and often." | **RESOLVED / guard** | Do NOT restore the confining "contain the workstream" phrasing. Keep `iterate` free of overseer-confinement; the positive principle lives canonically in `orchestration-discipline.md`, and `iterate` carries only a thin inline floor plus a reference. Any re-introduction must be scoped to the dispatched implementer/reviewer, never the overseer session. |
| `skills/iterate/SKILL.md` | 129 | in-flight subagent "freshness/isolation invariant" (no reinjection) | NESTED | Correct: isolation here is the dispatched subagent's. Confirm; optionally point the word "isolation" at the canonical subsection so it is unambiguous this is the nested-agent invariant, not a session lock. |
| `skills/iterate/SKILL.md` | 188-191 | "Sandboxed-runtime trust posture"; reviewer runs full tools under written constraints | NESTED | Correct: about the dispatched reviewer. Confirm; ensure it reads as bounding the REVIEWER, not the overseer session. |
| `agents/reviewer.md` | 45 | "boundaries … backed by container isolation, your freshness … Operators … outside a sandboxed runtime should narrow the tool surface" | **NESTED / CANONICAL-REF** | The RIGHT home for isolation language: it binds the dispatched reviewer. Tighten to name the principle explicitly ("isolation is a property of you, a dispatched agent") and reference the canonical subsection. This is where isolation SHOULD live, so promote its framing rather than dilute it. |
| `skills/implement/SKILL.md` | boundaries / Invocation Modes (18-28, 70-88) | dispatched vs top-level implementer; no explicit isolation language | NESTED (gap) | Add a one-line statement that the DISPATCHED implementer works in isolation (worktree + no cross-worktree writes), referencing the canonical subsection, symmetric with `reviewer.md`. The TOP-LEVEL implementer is not isolation-bound. Do NOT add isolation language that could read as binding the top-level invocation. |
| `rules/orchestration-discipline.md` | Graded Enforcement (57-66) | states the overseer cannot be hard-locked; 3 graded layers | **CANONICAL** | Host the new "Isolation is a dispatched-agent property" subsection here. Optionally extend the Phase-5 advisory (line 66) to WARN (never refuse) on cross-worktree / `main` writes from the top-level session. |
| `rules/oversee-arc.md` | Claim Registry (57-81) | cross-arc single-writer via `.claude/oversee/claims/` | **CANONICAL (promote)** | Promote the claim registry to the FIRST-CLASS overseer clobber-safety mechanism in prose: cross-worktree safety comes from cooperative claims + single-writer, explicitly NOT from any session-wide worktree lock. Add one sentence making that contrast. |
| `skills/oversee/SKILL.md` | whole file | arc overseer; references cross-worktree `/oversee` as normal | CLEAN | Confirmed: nothing confines the overseer to a worktree; `oversee-arc.md:60` even treats "a SECOND top-level `/oversee` in another worktree" as normal. No edit needed beyond referencing the principle if a natural anchor exists. |
| `skills/full-send/SKILL.md` | whole file | composes propose-revise + iterate as overseer | CLEAN | Confirmed: nothing confines the overseer. No edit. |
| `skills/propose-revise/SKILL.md` | whole file | overseer loop | CLEAN | Confirmed by grep: no worktree/isolation/contain/sandbox language. No edit. |
| `skills/oversee/template.md` L25, `rules/oversee-arc.md` L35 | per-proposal `worktree` field | CLEAN | This is per-proposal worktree TRACKING in the arc-state file, not a session lock. No edit. |
| `rules/oversee-arc.md` L96-104 | "isolate first, full-cycle second" troubleshooting budget | CLEAN | Unrelated sense of "isolate" (fault isolation, not filesystem). No edit. |

The one leak-prone authored line (`iterate` line 18) is already interim-removed; the remaining work is positive (state the principle canonically, tighten the nested bindings, promote the claim registry) plus a guard against re-introduction. Everything else is a correct nested binding, a canonical home, or clean.

### Alignment with the graded + cooperative model

The overseer stays clobber-safe via the claim registry + single-writer ownership, NOT via any session-wide lock:

- **Promote the claim registry to first-class** ([oversee-arc.md](../../plugins/cdocs/rules/oversee-arc.md) lines 57-81). It already fails safe (a stale claim reconciles to `stale` on resume) and is legible (files on disk under `.claude/oversee/claims/`). Prose should name it as THE overseer clobber-safety mechanism and frame any harness lock as a coarse backstop, not the primary control.
- **Keep enforcement graded.** The canonical subsection lives beside the existing statement that a hard tool-allowlist on the top-level session is not available; the isolation principle is the same shape of claim (the overseer session is not hard-constrained; discipline is cooperative + judged).

### Isolation-AWARE, not isolation-BOUND, loop skills

Loop skills surface cross-worktree steps as explicit preconditions and route them; they NEVER refuse or dead-end, and they do NOT gate this behavior on detecting a lock.

- **Surface unconditionally.** When a step is cross-worktree (a resolve's merge into `main`, a fork off `main`), the skill ALWAYS surfaces it as an explicit precondition and routes it ("run this land/resolve/fork from an un-isolated `main` session"), warning not refusing, the same way skills already gate on other preconditions. This turns a silent mid-merge wall into an up-front routing instruction.
- **Why unconditional, not probe-gated.** A read-only cross-worktree probe tests the wrong axis: the report establishes that cross-worktree READS are allowed under the write-scoped lock, and the single observed refusal was a compound-parsing false positive, so a read probe cannot reliably detect the write confinement. A cheap probe may optionally tailor the wording, but it is NOT the trigger.
- **Phase-5 advisory:** the unbuilt `PreToolUse` advisory in [orchestration-discipline.md](../../plugins/cdocs/rules/orchestration-discipline.md) line 66 MAY warn (never refuse) on a cross-worktree or `main` write from the top-level session, surfacing it to the overseer and judge. Warn-not-refuse keeps the overseer in control and matches the graded philosophy. Per the overseer's decision this is a SPEC-NOTE ONLY here (optional, non-blocking); the hook build is deferred to a dedicated hooks proposal.

### Downstream (weftwise) surfaces and routing

No weftwise SOURCE edit is required. Its cross-worktree commands are LEGITIMATE (their whole purpose is cross-worktree) and are exactly the surfaces an UN-isolated top-level session drives. The isolation-aware loop skills ROUTE to them, never dead-end:

- `/resolve-wt` (`.claude/commands/resolve-wt.md`): Step 2 (~L73-96) runs `git merge <branch>` FROM the target's own worktree, gated on `pnpm gate` exit 0; Step 3 tears down and `git branch -d`.
- `/dogfood-wt` (`.claude/commands/dogfood-wt.md`) and `scripts/worktree.sh` `cmd_add` (~L103-149: `git worktree add -b <name> <target> <base>`, a fork off base/`main`), wrapped by `/worktree` and `/wt`.

Routing example: when a locked session needs to land, the skill surfaces "run `/resolve-wt <branch>` from an un-isolated `main` session" rather than attempting the cross-worktree merge itself. The commands are correct as-is.

This proposal's rule edit propagates downstream via the normal `/cdocs:init` materialization path, while the interim skill-only fix needed no re-init (see the Summary NOTE); no weftwise source edit either way.

## Important Design Decisions

- **Single canonical statement, referenced elsewhere.** The principle is stated once in `orchestration-discipline.md` (the overseer-mode source of truth), adjacent to the existing "a hard tool-allowlist on the top-level session is not available" line (~L59) since it reinforces that same graded-enforcement point. It is referenced from `reviewer.md`, `implement/SKILL.md`, and `iterate` (a thin inline floor plus a pointer). Scattering the same claim across skills violates the project's deduplication value and invites drift.
- **`reviewer.md` is the right home for the strong isolation language**, because the reviewer IS the canonical dispatched agent whose trustworthiness depends on isolation + freshness. The edit STRENGTHENS its framing (names the principle) rather than diluting it.
- **Durable contribution, not deletion.** The report's 5 recommendations remain sound; clauthier's contribution is the canonical principle plus isolation-aware skills plus advocacy. The authored confinement was already removed in `de34bee`.
- **Warn, never refuse.** Every proposed enforcement touch is advisory. A refusing guard on the top-level session is exactly the failure this proposal removes; re-introducing one (even a "smart" one) would recreate the mid-merge dead-end.
- **Phase-5 advisory is spec-note only.** The warn-not-refuse `PreToolUse` advisory is documented here as an optional spec note; the hook build is deferred to a dedicated hooks proposal, so this proposal does not block on hook implementation.
- **`footprint:` frontmatter is declared** so an `/oversee` arc reading this proposal can serialize correctly against its touched paths ([oversee-arc.md](../../plugins/cdocs/rules/oversee-arc.md) "Footprint-Overlap Serialization Heuristic" reads a proposal frontmatter `footprint:` field).

## Edge Cases / Challenging Scenarios

- **A word matches but the sense differs.** "isolate first, full-cycle second" (oversee-arc.md L96) is fault-isolation, not filesystem isolation; the per-proposal `worktree` arc-state field is tracking, not a lock. The audit must classify by SENSE, not by keyword match, or it will "fix" clean prose.
- **Tightening a nested binding into ambiguity.** When editing `iterate` line 129 / 188 and `reviewer.md` line 45, the risk is making them read as overseer constraints. Each edit must keep the subject unambiguously the dispatched agent.
- **A future reader re-introduces containment.** A nit-fix or a well-meaning edit could re-add "contain the workstream in a worktree" to an overseer skill. Mitigation: a `> NOTE` callout at the canonical subsection stating the principle is load-bearing and MUST NOT be softened back into a session-wide containment claim (mirrors the existing intentional-duplication NOTE at orchestration-discipline.md line 54).
- **Un-init'd install.** Per the inline-discipline-floor rationale (orchestration-discipline.md line 45-52), a skill reduced to a bare reference points at content a non-init'd session never loaded. The `iterate` line-18 rewrite must keep a short inline sense of the principle, not collapse to a pure pointer.

## Verification Methodology

These are prose/skill changes, not code; verification is doc-grep/read-based.

1. **Leak grep (primary failure-picture).** After edits, grep the overseer-facing skills for containment language:
   ```sh
   grep -niE "contain the workstream|isolat|sandbox|worktree" \
     plugins/cdocs/skills/iterate/SKILL.md \
     plugins/cdocs/skills/oversee/SKILL.md \
     plugins/cdocs/skills/full-send/SKILL.md \
     plugins/cdocs/skills/propose-revise/SKILL.md
   ```
   FAIL: any surviving phrasing a reader would apply to the OVERSEER SESSION (e.g. "contain the workstream [in a worktree]" attached to the top-level session). Each remaining match must be manually confirmed to bind a DISPATCHED agent or to be an unrelated sense.

2. **Canonical single-source + references check.** `grep -n "dispatched-agent property\|Isolation is a dispatched"` across `rules/` and `skills/` returns exactly ONE definition (in `orchestration-discipline.md`); the loop skills (`iterate`, `implement`, `reviewer.md`) each carry a POINTER to it, not a restatement. FAIL: two full statements of the principle (drift), or a skill that states the discipline with no canonical anchor to reference.

3. **Nested-binding read.** Manually read the edited `reviewer.md` L45, `implement/SKILL.md` boundaries, and `iterate` L129/L188: each must name the dispatched agent as the isolation subject. FAIL: any reads as constraining the top-level session.

4. **Claim-registry promotion read.** `oversee-arc.md` "Claim Registry" prose explicitly frames the registry as the overseer's clobber-safety mechanism and contrasts it against a session-wide lock. FAIL: the contrast sentence is absent.

5. **Cross-reference integrity.** Every reference to the canonical subsection resolves to a real heading. FAIL: a dangling reference.

6. **No downstream source edit.** Confirm the implementation touches only clauthier `plugins/cdocs/skills/` and `plugins/cdocs/rules/` paths (plus this proposal's own cdocs); no edit lands in the weftwise repo or its command surfaces. Note that the rule edit is expected to propagate downstream via the normal `/cdocs:init` freshness path, NOT via a manual weftwise change. FAIL: any weftwise-repo edit, or a claim that the rule change requires no downstream re-init (it does, by design).

## Implementation Phases

Phase 1 is the load-bearing core (the canonical anchor); 2-5 are guard, alignment, and routing, each referencing Phase 1. Phases 2-5 can proceed largely independently once Phase 1 lands.

### Phase 1: Canonical principle (dependency for all others)
- Add the "Isolation is a dispatched-agent property" subsection under "Graded Enforcement" in `orchestration-discipline.md`, with a `> NOTE` guarding it against future re-softening.
- Success: subsection exists; grep check 2 returns exactly one definition.

### Phase 2: Guard against re-introduction (the leak is already interim-removed)
- The `iterate/SKILL.md` line-18 containment clause was removed in `de34bee`; do NOT restore it.
- Ensure `iterate` carries only a thin inline floor plus a pointer to the Phase-1 canonical principle, so a future nit-fix cannot re-add overseer-confining phrasing without contradicting the referenced canon.
- Success: grep check 1 shows no overseer-applicable containment phrasing in the overseer-facing skills.

### Phase 3: Tighten nested bindings
- `reviewer.md` L45: strengthen to name the principle and reference Phase 1 (the strong home for isolation language).
- `implement/SKILL.md`: add a one-line dispatched-implementer isolation statement, symmetric with `reviewer.md`; leave top-level mode unbound.
- `iterate/SKILL.md` L129, L188-191: confirm/tighten so the subject is unambiguously the dispatched subagent.
- Success: grep check 3 passes.

### Phase 4: Promote the claim registry
- Add prose to `oversee-arc.md` "Claim Registry" framing it as the FIRST-CLASS overseer clobber-safety mechanism, contrasted against a session-wide lock.
- Success: grep check 4 passes.

### Phase 5: Isolation-aware routing + advisory spec-note
- Fold isolation-AWARE route/warn guidance (unconditional precondition-surfacing, not probe-gated) into the loop skills where they perform cross-worktree steps, naming the real weftwise routing targets (`/resolve-wt`, `/dogfood-wt`, `/worktree`/`/wt`) so a session gets an up-front precondition instead of a mid-merge dead-end.
- In `orchestration-discipline.md` line 66, add a spec note that the (unbuilt) `PreToolUse` advisory MAY warn (never refuse) on cross-worktree / `main` writes from the top-level session. Documentation only; the hook build is deferred to a dedicated hooks proposal.
- Success: routing prose names real commands; advisory is a spec note; no refusing guard introduced anywhere.

### Constraints (what NOT to change)
- Do NOT add any REFUSING guard to a top-level/overseer skill.
- Do NOT restore the `iterate` line-18 containment phrasing, and do NOT add overseer-confining isolation language to any skill.
- Do NOT edit the weftwise repo or its command surfaces (`/resolve-wt`, `/dogfood-wt`, `worktree.sh`): they are correct as-is and are routing targets, not fix sites.
- Do NOT touch the per-proposal `worktree` arc-state field or the "isolate first" troubleshooting-budget prose (unrelated senses).
- Do NOT implement a harness sandbox change or the `PreToolUse` hook (out of scope; Appendix A and a future hooks proposal).

## Appendix A: Harness-sandbox advocacy (out of scope, documented)

Relayed from the motivating report as asks clauthier CANNOT change directly and should ADVOCATE for; the proposal does NOT block on any of them:

- **Write-scoped, not read-scoped.** Cross-worktree READS (`git log`, `git diff main...HEAD`, `git worktree list`) are safe and constantly needed; only cross-worktree WRITES (`merge`, `commit`, `checkout`, `worktree add/remove`, `branch -d`) are the hazard.
- **Compound-aware parsing.** Refusing an `&&`/subshell chain because it "cannot be verified to stay inside the worktree" is over-refusal; parse the pipeline and judge each git invocation, or allow when every git subcommand is individually read-only. The observed `git worktree list` false-positive is the canonical case.
- **Per-operation, logged unlock** for vetted workflows instead of the all-or-nothing `dangerouslyDisableSandbox`, which trains operators to disable the sandbox wholesale.

These belong in a harness-facing issue with the motivating case attached, not in the clauthier prose changes above.

## Resolved Decisions (overseer)

The three questions raised during authoring are resolved and folded above; recorded here so they are not re-opened:

1. **Phase-5 advisory scope** → SPEC-NOTE ONLY in this proposal (optional, non-blocking); the hook build is deferred to a dedicated hooks proposal.
2. **Canonical location** → the principle "isolation binds dispatched agents; the top-level overseer/session is NEVER isolation-bound" is stated ONCE in `orchestration-discipline.md`, adjacent to the "hard tool-allowlist on the top-level session is not available" line (~L59); skills carry a thin inline floor plus a reference.
3. **Routing targets** → the `/resolve-wt` and off-`main` fork surfaces live in the `weftwise` repo (`.claude/commands/resolve-wt.md`, `.claude/commands/dogfood-wt.md`, `scripts/worktree.sh`) and are LEGITIMATE cross-worktree commands; the isolation-aware skills ROUTE to them (see "Downstream (weftwise) surfaces and routing"). No weftwise edit.

One residual implementer detail (non-blocking): whether the unconditional route/warn logic lives inline in each loop skill or in a shared rule both reference. Leaning shared-rule to honor deduplication, but the loop skills currently keep only thin inline floors; the implementer decides at Phase 5.
