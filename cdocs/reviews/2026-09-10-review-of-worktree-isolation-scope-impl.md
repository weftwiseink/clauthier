---
review_of: cdocs/proposals/2026-09-10-worktree-isolation-scope-to-dispatched-agents.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-10T12:24:53-07:00
task_list: clauthier/worktree-isolation-guardrails
type: review
state: live
status: done
tags: [fresh_agent, implementation, architecture, orchestration, worktree, dedup, verified_against_tree, accepted]
---

# Review: Scope Worktree-Isolation to Dispatched Agents (Implementation)

## Summary Assessment

This reviews the implementation of the accepted proposal (Phases 1-5) across commits `45abcb7..4c72b00`, diffed at `git diff 2881eab..HEAD -- plugins/cdocs/`.
The work encodes one principle: worktree isolation binds only nested DISPATCHED agents (implementer, reviewer); the top-level overseer/session is NEVER isolation-bound and stays free to land, resolve, and fork.
I re-ran all six of the proposal's verification checks independently against the live tree: all six PASS. No refusing guard was introduced anywhere; every enforcement touch is warn-not-refuse. The principle is stated canonically exactly once (`orchestration-discipline.md:69`) with every other mention an anchored pointer, and the required inline discipline floor was preserved.
Verdict: **Accept.** The only findings are non-blocking writing-convention nits (em-dash and semicolon density) and one clarification worth surfacing (repo-specific command names embedded in a downstream-materializing rule).

## Independent Verification of the Six Checks

**Check 1 - Leak grep (PASS).** Grepped `contain the workstream|isolat|sandbox|worktree` across `iterate`, `oversee`, `full-send`, `propose-revise`. `full-send` and `propose-revise`: zero hits. Every surviving hit binds a dispatched agent or explicitly frees the overseer:
- `oversee/SKILL.md:100` - "the arc overseer is NOT isolation-bound and performs it as normal work".
- `iterate/SKILL.md:15` - "binds the dispatched implementer and reviewer, never this overseer session, which stays free to land, resolve, and fork".
- `iterate/SKILL.md:93` - "the overseer is NOT isolation-bound".
- `iterate/SKILL.md:131` - "isolation binds the dispatched subagent, not the overseer session".
- `iterate/SKILL.md:190` - section heading "Sandboxed-runtime trust posture" (label only).
- `iterate/SKILL.md:192` - "these constraints bind the reviewer, not the overseer session".
No surviving hit could be read as confining the top-level session. PASS.

**Check 2 - Canonical single-source + inline floor (PASS).** The full multi-sentence definition appears exactly once, at `orchestration-discipline.md:69-78` (heading + body + routing paragraph). Every other mention is an anchored pointer, not a competing definition: `reviewer.md:45`, `implement/SKILL.md:30`, `oversee-arc.md:63`, `iterate/SKILL.md:15/93/131/192`, `oversee/SKILL.md:100`. `iterate:15` compresses the principle to a thin inline sense and immediately anchors it ("the principle is canonical in ...") - this is the mandated inline floor, not drift. The Inline Discipline Floor section (`orchestration-discipline.md:45-55`) and its anti-dedup NOTE are intact and untouched; `iterate`'s pre-existing floor line (`:13`) is preserved with the isolation floor added alongside. PASS.

**Check 3 - Nested-binding read (PASS).** Each edited nested site names the dispatched agent as the isolation subject:
- `reviewer.md:45` - "Isolation is a property of you, a DISPATCHED agent - not of the top-level overseer session".
- `implement/SKILL.md:30` - "A DISPATCHED implementer works in isolation ... a property of the dispatched agent, not of the top-level invocation".
- `iterate/SKILL.md:131` and `:192` - both scope isolation to the dispatched subagent/reviewer and explicitly exclude the overseer.
None reads as constraining the top-level session. PASS.

**Check 4 - Claim-registry contrast (PASS).** `oversee-arc.md:63` frames the registry as "the FIRST-CLASS overseer clobber-safety mechanism - NOT a session-wide worktree lock" and contrasts any harness lock as "only a coarse backstop, never the primary control". The required contrast sentence is present. PASS.

**Check 5 - Cross-reference integrity (PASS).** Every pointer targets the exact heading text `Isolation is a dispatched-agent property`, which resolves to the real `### Isolation is a dispatched-agent property` at `orchestration-discipline.md:69`. Relative link paths are correct from each file's location (`../rules/` from `agents/`, `../../rules/` from `skills/*/`, `./oversee-arc.md` within `rules/`). The `(Isolation-aware routing)` parentheticals resolve to the bold sub-label within the same subsection. PASS. (Minor: the two references to `oversee-arc.md` "Claim Registry" quote a prefix of the full heading `Claim Registry (extends Pillar 1b to cross-arc altitude)`; unambiguous, resolves fine - see nit 3.)

**Check 6 - No downstream/out-of-scope edit (PASS).** `git diff --name-only 2881eab..HEAD` touches only six `plugins/cdocs/{rules,skills,agents}` files. No weftwise edit (correctly - weftwise commands are routing targets, not fix sites). The per-proposal `worktree` arc-state field (`oversee-arc.md:35`) and the "isolate first, full-cycle second" troubleshooting prose (`oversee-arc.md:98`) are both untouched. A refusing-guard scan of the added lines returns only lines that explicitly say "never refuse"/"warning rather than refusing"/"warning never refusing"; no refusing guard was introduced. PASS.

## Section-by-Section Findings

### Canonical subsection - `orchestration-discipline.md:69-82` (blocking: none)
Clear and correct. It states plainly that the overseer "is deliberately NOT isolated: it must land branches into `main`, resolve worktrees, and fork new worktrees off `main`", ties clobber-safety to the cooperative claim registry, and places itself under Graded Enforcement adjacent to the "hard tool-allowlist ... is not available" line, exactly as the proposal specified. The guarding NOTE (`:80-82`) explicitly forbids re-adding "contain the workstream" to `iterate`, `oversee`, `full-send`, `propose-revise` and mirrors the intentional-duplication NOTE, addressing the proposal's "future reader re-introduces containment" edge case. Placement as a `###` under `## Graded Enforcement` matches the proposal's "short new subsection under Graded Enforcement".

### Routing prose - `orchestration-discipline.md:76-78`, `iterate:93`, `oversee:100` (non-blocking nit 4)
Routing is unconditional and warn-not-refuse, as required: "surfaces that step UNCONDITIONALLY as an explicit precondition", "This is not probe-gated ... always surfaces the precondition up front rather than dead-ending mid-merge". The probe rationale correctly matches the proposal (a read-only probe tests the wrong axis under a write-scoped lock). The canonical paragraph holds the routing logic and the loop skills point to it with `(Isolation-aware routing)`, which is the implementer's noted non-material shared-rule decision - consistent with the proposal's stated shared-rule lean (Resolved Decisions, residual item). Faithful.

### reviewer.md strengthening - `reviewer.md:45` (non-blocking nit 1/5)
Reads naturally and strengthens rather than dilutes: it now names the principle ("Isolation is a property of you, a DISPATCHED agent"), anchors to canon, and preserves the original trust rationale ("make your verdict trustworthy and keep you from clobbering the workstream"). The one cost is length: it is now a dense multi-clause sentence joined by a semicolon (see nits).

### implement/SKILL.md - `implement:30` (blocking: none)
Adds the symmetric dispatched-implementer isolation line inside the Invocation Modes discussion, anchored to both canon and `reviewer.md`, and explicitly leaves the top-level invocation unbound. Matches Phase 3 intent.

### oversee-arc.md claim-registry promotion - `oversee-arc.md:63` (non-blocking nit 3)
Promotes the registry to first-class with the required contrast. Correct placement immediately after the cross-arc extension prose.

### oversee/SKILL.md - `oversee:100` (informational, non-blocking)
The audit table classified `oversee` as CLEAN ("No edit needed beyond referencing the principle if a natural anchor exists"), and Phase 5 says to fold routing into "the loop skills where they perform cross-worktree steps". `oversee` is such a loop skill (it lands/forks between proposals), so this edit is consistent with Phase 5 intent even though `oversee/SKILL.md` was not in the declared `footprint:` frontmatter. Footprint is an advisory serialization hint, not a hard allowlist, so this is not a scope violation - noted only for completeness.

## Faithfulness to the Accepted Proposal

All five phases are faithfully implemented with no silent deviation:
- Phase 1: canonical subsection + guarding NOTE (`orchestration-discipline.md:69-82`).
- Phase 2: `iterate` containment not restored; thin floor + pointer at `iterate:15`.
- Phase 3: `reviewer.md:45`, `implement:30`, `iterate:131/192` tightened to name the dispatched agent.
- Phase 4: claim-registry promotion + contrast at `oversee-arc.md:63`.
- Phase 5: routing prose (canonical + `iterate:93` + `oversee:100`) and the `PreToolUse` advisory spec-note at `orchestration-discipline.md:67`, documentation-only with the hook build deferred.

The one implementer decision flagged as non-material - routing prose canonical in `orchestration-discipline.md` with skills pointing to it - is consistent with the proposal's shared-rule lean and its deduplication value. Confirmed non-material.

## Non-Blocking Nits

1. **Em-dash usage against convention.** `writing-conventions.md` says to prefer colons/commas/periods over em-dashes and use them sparingly. The new prose introduces six em-dashes: `orchestration-discipline.md:67` ("warn - never refuse"), `:76` (two, around the cross-worktree-step clause), `oversee-arc.md:63` ("mechanism - NOT"), `implement:30` ("sibling workstream - a property"), `oversee:100` (around "cross-worktree step"). Convert to colons/commas or spaced hyphens on a future nit-fix pass. Rides along with accept.
2. **Semicolon density.** Several added sentences chain independent clauses with semicolons (`reviewer.md:45`, `oversee-arc.md:63`, `orchestration-discipline.md:77`). Conventions ask that semicolons be used sparingly; a couple could be split into two sentences for readability. Non-blocking.
3. **Partial heading quote for "Claim Registry".** `orchestration-discipline.md:74` and `oversee-arc.md:63` reference `oversee-arc.md` "Claim Registry", while the exact heading is "Claim Registry (extends Pillar 1b to cross-arc altitude)". It resolves unambiguously (prefix match), so this is cosmetic precision only.
4. **Sentence length in canonical routing paragraph.** `orchestration-discipline.md:76` is a long single sentence carrying the step definition, the routing targets, and the warn-not-refuse qualifier. It is accurate; splitting the routing-target list off would improve scan-ability. Non-blocking.

## Verdict

**Accept.** All six verification checks pass independently against the live tree. The principle is single-sourced and correctly scoped, the inline floor is preserved, no refusing guard was added, no out-of-scope or weftwise edit occurred, and the implementation is faithful to all five phases. Remaining findings are writing-convention nits that can ride along.

## Action Items

```
1. [non-blocking] Replace the six em-dashes in the new prose (orchestration-discipline.md:67,76; oversee-arc.md:63; implement:30; oversee:100) with colons/commas/spaced-hyphens per writing-conventions.md.
2. [non-blocking] Split the longest semicolon-joined sentences (reviewer.md:45, oversee-arc.md:63, orchestration-discipline.md:76) for readability.
3. [non-blocking] Optionally quote the full "Claim Registry (...)" heading, or leave the prefix quote as-is.
4. [non-blocking] Consider whether oversee/SKILL.md should be added to the proposal's footprint frontmatter for accurate arc serialization (informational; not required).
```

## Clarification to Surface

The canonical rule (`orchestration-discipline.md:76`) and the loop-skill pointers name repo-specific weftwise commands (`/resolve-wt`, `/dogfood-wt`, `/worktree` / `/wt`) inside a rule that materializes DOWNSTREAM into arbitrary consuming projects via `/cdocs:init` (README "Rules Integration"). A downstream project that is not weftwise will not have these commands. The prose hedges with "in the weftwise source repo", so this is not a correctness defect, but it does ship one repo's command names into every consumer's materialized rule.

How should this be handled?
- (A) Leave as-is: the "weftwise source repo" hedge is sufficient; the names are illustrative of the routing pattern. (Least churn; current state.)
- (B) Generalize the canonical prose to "the repo's cross-worktree land/resolve/fork commands" and demote the concrete weftwise names to an example parenthetical, so a non-weftwise consumer reads the pattern, not foreign command names.
- (C) Move the concrete command names entirely into the weftwise-side routing docs and keep only the pattern in the materializing clauthier rule.

My recommendation is (B): it preserves the routing intent for every consumer while keeping the concrete example, and is a small non-blocking follow-up that need not hold the accept.
