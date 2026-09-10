---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-10T11:51:44-07:00
task_list: clauthier/worktree-isolation-guardrails
type: proposal
state: live
status: review_ready
footprint:
  - "plugins/cdocs/rules/orchestration-discipline.md"
  - "plugins/cdocs/rules/oversee-arc.md"
  - "plugins/cdocs/agents/reviewer.md"
  - "plugins/cdocs/skills/implement/SKILL.md"
  - "plugins/cdocs/skills/iterate/SKILL.md"
tags: [architecture, orchestration, worktree, clauthier]
---

# Scope Worktree-Isolation to Dispatched Agents, Not the Overseer

> BLUF: Worktree isolation is a property of NESTED DISPATCHED agents (the implementer, the reviewer), never of the top-level overseer/session. State that principle canonically ONCE in `orchestration-discipline.md`'s Graded Enforcement section and reference it elsewhere. Fix the one authored line that leaks isolation onto the overseer (`iterate` line 18's "contain the workstream"), tighten the two lines that correctly bind nested agents, and promote the claim registry to the first-class clobber-safety mechanism. Loop skills become isolation-AWARE (detect and WARN/route), never isolation-BOUND (refuse). Harness-sandbox asks are a documented appendix, not a blocker.

## Summary

A `/oversee` session locked to its own worktree ran a full overseer arc fine but could not LAND it: the resolve step's merge into `main` and a fork of a new worktree off `main` are cross-worktree writes the lock refuses.
The motivating report (`weftwise` repo: `cdocs/reports/2026-09-10-worktree-isolation-vs-overseer-guardrails.md`) attributes the binding constraint to a Claude Code harness sandbox "clauthier cannot change."
This proposal corrects that framing: the constraint that actually confines the workflow is clauthier-AUTHORED, and it is fixable here.

The primary work is a clauthier-side prose re-scope: locate the authored isolation/containment language and bind it EXPLICITLY to dispatched agents, leaving the overseer flexible.
Isolation is what makes a fresh reviewer's verdict trustworthy and keeps an implementer from clobbering a sibling; the overseer's clobber-safety comes from the cooperative claim registry plus single-writer ownership, NOT from a session-wide lock.
Harness-side asks (write-scoped, compound-aware, per-op-unlockable sandbox) are relayed as an out-of-scope appendix; the proposal does not block on them.

## Objective

A top-level session running `/oversee`, `/iterate`, `/full-send`, `/propose-revise`, or a resolve/land/fork step must NEVER carry a worktree-isolation restriction.
The isolation constraint was intended to bind only nested dispatched agents; it is leaking onto the overseer through ambiguous authored prose and impeding fluid cross-worktree work: landing a branch into `main`, resolving a worktree, and forking a new worktree off `main`.

Goal: make the isolation principle explicit and single-sourced, audit and fix every authored surface that leaks it onto the overseer, and align the loop skills with clauthier's already-designed graded + cooperative safety model.

## Background

- **Motivating report** (authoritative observation set): `weftwise` repo, `cdocs/reports/2026-09-10-worktree-isolation-vs-overseer-guardrails.md` (a sibling repo, not linkable relative from here).
  Its 5 recommendations (prefer the cooperative model, make loop skills isolation-aware, surgical harness guard, build the Phase-5 advisory, separate the two guardrail intents) are input here, re-framed around the nested-vs-overseer scoping thesis.
  > NOTE(opus/clauthier/worktree-isolation): The report over-attributes the binding lock to a harness sandbox "clauthier cannot change."
  > The user's correction: the constraint that confines THIS workflow is clauthier-AUTHORED prose. The harness sandbox is a real but SECONDARY concern (see Appendix A). This proposal acts on the authored surface first.

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

Every match for `worktree|isolat|contain|sandbox` across `skills/`, `agents/`, `rules/` was inspected. Classification: LEAK (confines the overseer, must fix), NESTED (correctly binds a dispatched agent, confirm/tighten), CANONICAL (should host or reference the principle), CLEAN (no action).

| Surface | Line | Current intent | Class | Edit intent |
|---|---|---|---|---|
| `skills/iterate/SKILL.md` | 18 | "If the repo has worktree usage practices … they should be used to contain the workstream" | **LEAK** | A reader applies "contain the workstream" to the overseer session itself. Rewrite so isolation is explicitly a DISPATCHED-agent property: the overseer dispatches implementers/reviewers that work in worktrees and commits early/often, while the overseer itself stays free to land, resolve, and fork across worktrees. Reference the canonical subsection. |
| `skills/iterate/SKILL.md` | 130 | in-flight subagent "freshness/isolation invariant" (no reinjection) | NESTED | Correct: isolation here is the dispatched subagent's. Confirm; optionally point the word "isolation" at the canonical subsection so it is unambiguous this is the nested-agent invariant, not a session lock. |
| `skills/iterate/SKILL.md` | 189-192 | "Sandboxed-runtime trust posture"; reviewer runs full tools under written constraints | NESTED | Correct: about the dispatched reviewer. Confirm; ensure it reads as bounding the REVIEWER, not the overseer session. |
| `agents/reviewer.md` | 45 | "boundaries … backed by container isolation, your freshness … Operators … outside a sandboxed runtime should narrow the tool surface" | **NESTED / CANONICAL-REF** | The RIGHT home for isolation language: it binds the dispatched reviewer. Tighten to name the principle explicitly ("isolation is a property of you, a dispatched agent") and reference the canonical subsection. This is where isolation SHOULD live, so promote its framing rather than dilute it. |
| `skills/implement/SKILL.md` | boundaries / Invocation Modes (18-28, 70-88) | dispatched vs top-level implementer; no explicit isolation language | NESTED (gap) | Add a one-line statement that the DISPATCHED implementer works in isolation (worktree + no cross-worktree writes), referencing the canonical subsection, symmetric with `reviewer.md`. The TOP-LEVEL implementer is not isolation-bound. Do NOT add isolation language that could read as binding the top-level invocation. |
| `rules/orchestration-discipline.md` | Graded Enforcement (57-66) | states the overseer cannot be hard-locked; 3 graded layers | **CANONICAL** | Host the new "Isolation is a dispatched-agent property" subsection here. Optionally extend the Phase-5 advisory (line 66) to WARN (never refuse) on cross-worktree / `main` writes from the top-level session. |
| `rules/oversee-arc.md` | Claim Registry (57-81) | cross-arc single-writer via `.claude/oversee/claims/` | **CANONICAL (promote)** | Promote the claim registry to the FIRST-CLASS overseer clobber-safety mechanism in prose: cross-worktree safety comes from cooperative claims + single-writer, explicitly NOT from any session-wide worktree lock. Add one sentence making that contrast. |
| `skills/oversee/SKILL.md` | whole file | arc overseer; references cross-worktree `/oversee` as normal | CLEAN | Confirmed: nothing confines the overseer to a worktree (line 60 even treats "a SECOND top-level `/oversee` in another worktree" as normal). No edit needed beyond referencing the principle if a natural anchor exists. |
| `skills/full-send/SKILL.md` | whole file | composes propose-revise + iterate as overseer | CLEAN | Confirmed: nothing confines the overseer. No edit. |
| `skills/propose-revise/SKILL.md` | whole file | overseer loop | CLEAN | Confirmed by grep: no worktree/isolation/contain/sandbox language. No edit. |
| `skills/oversee/template.md` L25, `rules/oversee-arc.md` L35 | per-proposal `worktree` field | CLEAN | This is per-proposal worktree TRACKING in the arc-state file, not a session lock. No edit. |
| `rules/oversee-arc.md` L96-104 | "isolate first, full-cycle second" troubleshooting budget | CLEAN | Unrelated sense of "isolate" (fault isolation, not filesystem). No edit. |

The single hard LEAK is `iterate` line 18. Everything else is either a correct nested binding to confirm/tighten, a canonical home, or clean.

### Alignment with the graded + cooperative model

The overseer stays clobber-safe via the claim registry + single-writer ownership, NOT via any session-wide lock:

- **Promote the claim registry to first-class** ([oversee-arc.md](../../plugins/cdocs/rules/oversee-arc.md) lines 57-81). It already fails safe (a stale claim reconciles to `stale` on resume) and is legible (files on disk under `.claude/oversee/claims/`). Prose should name it as THE overseer clobber-safety mechanism and frame any harness lock as a coarse backstop, not the primary control.
- **Keep enforcement graded.** The canonical subsection lives beside the existing statement that a hard tool-allowlist on the top-level session is not available; the isolation principle is the same shape of claim (the overseer session is not hard-constrained; discipline is cooperative + judged).

### Isolation-AWARE, not isolation-BOUND, loop skills

Loop skills DETECT isolation and route/WARN; they NEVER refuse or dead-end.

- **Detect** worktree isolation up front via a cheap read-only cross-worktree probe (e.g. attempt a read-only `git -C <main> status` / `git worktree list`; if refused, the session is locked).
- **Route or warn**, never dead-end: if a cross-worktree step (a resolve's merge into `main`, a fork off `main`) is needed and the session is locked, surface a clear precondition ("run this land/resolve from an un-isolated `main` session") the same way skills already gate on other preconditions - turning a silent mid-merge wall into an up-front routing instruction.
- **Phase-5 advisory (only if it fits):** extend the unbuilt `PreToolUse` advisory in [orchestration-discipline.md](../../plugins/cdocs/rules/orchestration-discipline.md) line 66 to WARN (never refuse) on a cross-worktree or `main` write from the top-level session, surfacing it to the overseer and judge. Warn-not-refuse keeps the overseer in control and matches the graded philosophy. This is a documentation/spec addition, not a build task in this proposal; keep it optional so the proposal does not block on hook implementation.

## Important Design Decisions

- **Single canonical statement, referenced elsewhere.** The principle is stated once in `orchestration-discipline.md` (the overseer-mode source of truth) and referenced from `reviewer.md`, `implement/SKILL.md`, and `iterate` line 18. Scattering the same claim across skills violates the project's deduplication value and invites drift.
- **`reviewer.md` is the right home for the strong isolation language**, because the reviewer IS the canonical dispatched agent whose trustworthiness depends on isolation + freshness. The edit STRENGTHENS its framing (names the principle) rather than diluting it.
- **Correct the report's harness attribution without discarding its recommendations.** The report's 5 recommendations are sound; only its root-cause attribution ("clauthier cannot change the lock") is corrected. The binding constraint is authored prose; the harness sandbox is a real but secondary, advocate-not-change concern (Appendix A).
- **Warn, never refuse.** Every proposed enforcement touch is advisory. A refusing guard on the top-level session is exactly the failure this proposal removes; re-introducing one (even a "smart" one) would recreate the mid-merge dead-end.
- **`footprint:` frontmatter is declared** so an `/oversee` arc reading this proposal can serialize correctly against its touched paths ([oversee-arc.md](../../plugins/cdocs/rules/oversee-arc.md) "Footprint-Overlap Serialization Heuristic" reads a proposal frontmatter `footprint:` field).

## Edge Cases / Challenging Scenarios

- **A word matches but the sense differs.** "isolate first, full-cycle second" (oversee-arc.md L96) is fault-isolation, not filesystem isolation; the per-proposal `worktree` arc-state field is tracking, not a lock. The audit must classify by SENSE, not by keyword match, or it will "fix" clean prose.
- **Tightening a nested binding into ambiguity.** When editing `iterate` line 130 / 189 and `reviewer.md` line 45, the risk is making them read as overseer constraints. Each edit must keep the subject unambiguously the dispatched agent.
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

2. **Canonical single-source check.** `grep -n "dispatched-agent property\|Isolation is a dispatched"` across `rules/` and `skills/` returns exactly ONE definition (in `orchestration-discipline.md`); other hits are references/pointers, not restatements. FAIL: two full statements of the principle (duplication/drift).

3. **Nested-binding read.** Manually read the edited `reviewer.md` L45, `implement/SKILL.md` boundaries, and `iterate` L130/L189: each must name the dispatched agent as the isolation subject. FAIL: any reads as constraining the top-level session.

4. **Claim-registry promotion read.** `oversee-arc.md` "Claim Registry" prose explicitly frames the registry as the overseer's clobber-safety mechanism and contrasts it against a session-wide lock. FAIL: the contrast sentence is absent.

5. **Cross-reference integrity.** Every reference to the canonical subsection resolves to a real heading. FAIL: a dangling reference.

## Implementation Phases

Phases 1-2 are the load-bearing core; 3-5 are alignment and confirmation. Phases can proceed largely independently after Phase 1 lands the canonical anchor (2-5 all reference it).

### Phase 1: Canonical principle (dependency for all others)
- Add the "Isolation is a dispatched-agent property" subsection under "Graded Enforcement" in `orchestration-discipline.md`, with a `> NOTE` guarding it against future re-softening.
- Success: subsection exists; grep check 2 returns exactly one definition.

### Phase 2: Fix the leak
- Rewrite `iterate/SKILL.md` line 18 so worktree isolation is a dispatched-agent property and the overseer is explicitly free to land/resolve/fork; keep a short inline sense (not a bare pointer) and reference Phase 1.
- Success: grep check 1 shows no overseer-applicable containment phrasing at line 18.

### Phase 3: Tighten nested bindings
- `reviewer.md` L45: strengthen to name the principle and reference Phase 1 (the strong home for isolation language).
- `implement/SKILL.md`: add a one-line dispatched-implementer isolation statement, symmetric with `reviewer.md`; leave top-level mode unbound.
- `iterate/SKILL.md` L130, L189-192: confirm/tighten so the subject is unambiguously the dispatched subagent.
- Success: grep check 3 passes.

### Phase 4: Promote the claim registry
- Add prose to `oversee-arc.md` "Claim Registry" framing it as the FIRST-CLASS overseer clobber-safety mechanism, contrasted against a session-wide lock.
- Success: grep check 4 passes.

### Phase 5 (optional, spec-only): Phase-5 advisory extension
- In `orchestration-discipline.md` line 66, note that the (unbuilt) `PreToolUse` advisory MAY warn (never refuse) on cross-worktree / `main` writes from the top-level session. Documentation only; do not implement the hook here.
- Also fold isolation-AWARE detect/route/warn guidance into the loop skills where they perform cross-worktree steps.
- Success: prose present; no refusing guard introduced anywhere.

### Constraints (what NOT to change)
- Do NOT add any REFUSING guard to a top-level/overseer skill.
- Do NOT touch the per-proposal `worktree` arc-state field or the "isolate first" troubleshooting-budget prose (unrelated senses).
- Do NOT implement a harness sandbox change (out of scope; Appendix A).
- Do NOT collapse the `iterate` line-18 inline sense into a bare reference (un-init'd-install floor).

## Appendix A: Harness-sandbox advocacy (out of scope, documented)

Relayed from the motivating report as asks clauthier CANNOT change directly and should ADVOCATE for; the proposal does NOT block on any of them:

- **Write-scoped, not read-scoped.** Cross-worktree READS (`git log`, `git diff main...HEAD`, `git worktree list`) are safe and constantly needed; only cross-worktree WRITES (`merge`, `commit`, `checkout`, `worktree add/remove`, `branch -d`) are the hazard.
- **Compound-aware parsing.** Refusing an `&&`/subshell chain because it "cannot be verified to stay inside the worktree" is over-refusal; parse the pipeline and judge each git invocation, or allow when every git subcommand is individually read-only. The observed `git worktree list` false-positive is the canonical case.
- **Per-operation, logged unlock** for vetted workflows instead of the all-or-nothing `dangerouslyDisableSandbox`, which trains operators to disable the sandbox wholesale.

These belong in a harness-facing issue with the motivating case attached, not in the clauthier prose changes above.

## Open Questions

1. **Phase-5 advisory scope.** Include the warn-not-refuse cross-worktree advisory as a spec note now (Phase 5), or defer to a dedicated hooks proposal? Default: spec note only, no implementation, keep it optional.
2. **Isolation-detect probe placement.** Should the detect/route/warn logic live inline in `iterate`/`oversee`, or in a shared rule referenced by both? Leaning shared-rule to avoid duplication, but the loop skills currently keep only thin inline floors.
3. **`resolve-wt` / land step location.** The motivating report names `/resolve-wt` and an off-`main` fork step. Those command surfaces were not located in this repo's grep; confirm whether they live elsewhere (weftwise) or are yet-unbuilt, so the routing guidance targets a real surface rather than a hypothetical one.
