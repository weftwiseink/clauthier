---
first_authored:
  by: "@claude-opus-4-7"
  at: 2026-05-18T09:22:34-07:00
task_list: cdocs/iterate-skill
type: proposal
state: live
status: implementation_wip
last_reviewed:
  status: accepted
  by: "@claude-opus-4-7"
  at: 2026-05-18T13:05:00-07:00
  round: 3
tags: [iterate, reviewer, implementer, agent_capabilities, tool_surface, subagent_dispatch, empirical_verification, audit_trail]
---

# Expand `/cdocs:iterate` Reviewer Capabilities, Delete Dead Sub-Dispatch, Add Audit Tag

> BLUF(opus/cdocs/iterate-agent-capabilities): `/cdocs:iterate` was authored with a tool-minimal reviewer, but the intended deployment is container-sandboxed general-purpose agents that can drive UIs and dev servers.
> This proposal expands the `cdocs:reviewer` allowlist to full general-purpose tooling (adding `Bash`) with boundary constraints retained as written instructions, deletes the non-executable second-order `Task`-dispatch guidance from `iterate/SKILL.md`, `reviewer.md`, and `implement/SKILL.md`, and replaces it with a two-pattern model (**self-investigate by default; surface to overseer when fresh context is the actual ask**).
> Adds a mandatory `[indep-verify: confirmed | n/a | deferred-to-followup | skipped]` Iteration Log tag, with `confirmed` required to cite an empirical artifact (and inline the excerpt for ephemeral artifacts) in the review document, so the audit trail can witness independent empirical verification without depending on overseer diligence.

## Objective

Close two coupled gaps in `/cdocs:iterate`:

1. The `cdocs:reviewer` agent cannot empirically re-verify UI work because its tool allowlist omits `Bash` and any browser path.
   The independent-verification obligation silently relocates to the overseer, with no protocol turn naming it and no audit-trail column capturing it.
2. The skill and agent text sanction read-only `Task` dispatch from subagents that the platform forbids at runtime (`not available inside subagents`).
   The dead text implies an escape hatch that does not exist and obscures the legitimate paths for cross-subagent investigation.

The shared root cause is that the loop's role configuration was drafted under "reviewers and implementers are tool-minimal auditors", while the actual deployment posture is "general-purpose agents in sandboxed containers".
Aligning the configuration to the deployment is a single small change set.

## Background

Source artifacts:

- Report driving this proposal: [`cdocs/reports/2026-05-18-iterate-agent-capabilities.md`](../reports/2026-05-18-iterate-agent-capabilities.md).
- Prior empirical report from the mermaid-widget loop: [`weftwise/cdocs/reports/2026-05-18-cdocs-reviewer-empirical-verification-gap.md`](file:///var/home/mjr/code/weft/weftwise/main/cdocs/reports/2026-05-18-cdocs-reviewer-empirical-verification-gap.md).
- Loop skill: [`plugins/cdocs/skills/iterate/SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md).
- Reviewer agent: [`plugins/cdocs/agents/reviewer.md`](../../plugins/cdocs/agents/reviewer.md).
- Judge agent: [`plugins/cdocs/agents/judge.md`](../../plugins/cdocs/agents/judge.md) (already acknowledges the platform invariant at lines 91-93).
- Implement skill: [`plugins/cdocs/skills/implement/SKILL.md`](../../plugins/cdocs/skills/implement/SKILL.md) (inherits dead `Task`-dispatch text the iterate override does not currently scrub for `/cdocs:report`).

Key prior decisions to preserve:

- Freshness, not tool restriction, is what makes the reviewer independent ([`SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md) lines 165-171).
- The judge's read-only posture stays as-is: the judge judges the loop, not the work.
- The overseer remains orchestration-restricted; this proposal does not give the overseer Bash or browser tools.
- Container deployment is the assumed runtime; this is what makes the broader reviewer tool surface acceptable.

## Proposed Solution

Four atomic changes, each landable in its own commit.

### 1. Reviewer agent: full general-purpose tools with written-instruction constraints

[`plugins/cdocs/agents/reviewer.md`](../../plugins/cdocs/agents/reviewer.md):

- `tools` frontmatter becomes `Read, Glob, Grep, Edit, Write, Bash, WebFetch`.
  (`Task` is dropped because it is non-functional inside subagents.)
  `WebFetch` is included because Pattern A (self-investigation) explicitly relies on it for external-doc / API-reference lookups, and it is read-only and so fits the same written-constraint regime as `Bash`.
- The "Constraints" section is rewritten to enumerate the boundaries that previously rode on the absent allowlist:
  - The written-instruction trust posture assumes a sandboxed (container or equivalent) runtime; operators running `/cdocs:iterate` outside such a sandbox should consider a narrower reviewer tool surface.
  - Only `Edit` the target document's `last_reviewed` frontmatter; do not modify any other field or any source file.
  - Do not run `git commit`, `git push`, or any mutating VCS command; commit authority rests with the overseer.
  - Bash is allowed for read-only inspection (`ls`, `cat`, `npm test`, `npx playwright test`, starting a dev server for inspection) and for empirical UI verification.
  - Do not install dependencies, do not modify configuration files, do not run codegen or migration commands.
- A new NOTE callout in "Constraints" states that subagents cannot dispatch subagents on this platform, points to the two legitimate patterns (below), and cross-references the judge agent's existing acknowledgement.

### 2. Sub-dispatch model: self-investigate by default; surface to overseer when fresh context is the ask

Replaces the "Asymmetric second-order dispatch" section in [`plugins/cdocs/skills/iterate/SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md) (lines 179-191).
The replacement section is named "Subagents cannot dispatch subagents" and contains:

- A statement of the platform invariant.
- **Pattern A — Self-investigation (default):** the dispatched subagent uses its own tools (`Read`, `Grep`, `Bash`, `WebFetch` where available) to do the investigation inline.
  Findings land in the review document (for reviewers), the implementation summary (for implementers), or a `cdocs/reports/` artifact written directly by the subagent if the finding is durably useful.
- **Pattern B — Surface to overseer (fallback):** the subagent returns a structured "investigation requested" item in its output when a *separate fresh context* is the actual ask.
  The overseer reads it and dispatches `/cdocs:report` itself, or rolls the request into the next implementer's brief.
  This mirrors how implementers already surface "I think this proposal is wrong" as structured uncertainty.
  The structured request is a fenced block with an `## Investigation Requested` header, a one-sentence question, and a "context this would unblock" line; Phase 1 lands this literal example in the skill text and the schema can crystallize further in follow-up.
- A short example of each pattern.

### 3. Implementer dispatch override and dead-Task scrub in `/cdocs:implement`

Two coupled changes:

- [`plugins/cdocs/skills/iterate/SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md) Turn N.a directive list gains an explicit instruction to suppress the inherited "Request `/cdocs:report` from a subagent" text from `/cdocs:implement`, parallel to the existing review-dispatch suppression at lines 173-177.
  The dispatch prompt also includes the "subagents cannot dispatch subagents" NOTE so the implementer does not waste a turn discovering the runtime error.
- [`plugins/cdocs/skills/implement/SKILL.md`](../../plugins/cdocs/skills/implement/SKILL.md) lines 43-44 *and* lines 69-72 (the `### Use cdocs skills as appropriate` block) are rewritten to drop the "from a subagent" framing and adopt the same self-investigate / surface-to-caller language.
  Both call-sites currently encourage `/cdocs:report` dispatch without distinguishing top-level from subagent invocation; both are scrubbed in lockstep.
  This is the cross-cutting cleanup: `/cdocs:implement` is commonly itself a subagent invocation, so the dead text fails outside `/cdocs:iterate` too.

### 4. Iteration Log audit tag

[`plugins/cdocs/skills/iterate/SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md) Iteration Log table conventions gain a mandatory notes-tag convention:

- Every Iteration Log row's `notes` column carries one of `[indep-verify: confirmed]`, `[indep-verify: n/a]`, `[indep-verify: deferred-to-followup]`, or `[indep-verify: skipped]`.
- The overseer assigns the tag for each row based on the verification floor stated at Turn 0 and the iteration's actual content; the per-value rules below describe what the overseer must do to justify each value.
- `confirmed` requires the corresponding review document to cite at least one empirical artifact path (screenshot, Playwright run output, dev-server log excerpt, curl/HTTP response capture) AND, for ephemeral artifacts (test runner output, browser screenshots in `/tmp`), inline the relevant excerpt into the review body so the citation remains resolvable after the artifact rotates or is cleaned up.
  The reviewer is the cite-er; the overseer does not author the citation.
- `n/a` is for proposals whose verification floor does not require empirical browser/runtime evidence (pure documentation changes, internal refactors verified by unit tests alone).
- `deferred-to-followup` is for proposals whose verification floor *does* require empirical evidence but cannot be exercised inside the loop reviewing them (typically self-referential changes to `/cdocs:iterate` itself, or proposals whose smoke test requires a separate top-level invocation).
  The notes must include a pointer to where the deferred verification will be recorded (a follow-up devlog path or a tracking task identifier).
  This is distinct from `skipped`: deferral is a structural carve-out with a named follow-up; skipping is a fail-loud absence requiring overseer justification.
  The follow-up pointer is checked at row-write time but resolution of the pointed-at follow-up is not enforced inside the loop; an unresolved `deferred-to-followup` pointer is the next audit-trail bug class and a candidate for a future `/cdocs:audit` or `/cdocs:status` enforcement vector.
- `skipped` is fail-loud: the overseer must justify it in the iteration row's notes or in the `### Overseer synthesis` subsection before Accept.
  An auditor reading only the Iteration Log can immediately spot `skipped` rows.

The template at [`plugins/cdocs/skills/iterate/template.md`](../../plugins/cdocs/skills/iterate/template.md) is updated so the example row demonstrates the tag.

## Important Design Decisions

### Why Option A (full reviewer tools) over the prior report's verifier-subagent recommendation

Already analyzed in [`cdocs/reports/2026-05-18-iterate-agent-capabilities.md`](../reports/2026-05-18-iterate-agent-capabilities.md) "Why the prior remedy is not the right shape under this intent".
Summary: a verifier subagent is machinery to recover capability the reviewer was supposed to have under the container-deployed general-purpose intent.
It costs an extra agent definition, an extra artifact type, an extra dispatch turn, and a foot-gun where a forgetful overseer reproduces the original silent-relocation failure.
Freshness is the independence mechanism; tool restriction was redundant under the container deployment.

The specific guarantee being traded is the verifier-subagent design's separation of *evidence producer* from *verdict issuer*: the verifier had no verdict authority, and the reviewer issued the verdict by citing the verifier's artifact.
This proposal collapses both roles into the reviewer.
The trade is acceptable because (a) the reviewer is fresh per iteration, so it has no prior commitment to a verdict to cherry-pick evidence for, and (b) the empirical artifact lives in the review document (with ephemeral excerpts inlined) where the overseer and any future re-reviewer can re-inspect it.
A future deployment posture that weakens either condition is the right time to revisit the verifier-subagent design.

### Why constraints become written instructions rather than tool-level restrictions

Tool-level enforcement is *only* meaningful here for tools that have no read-only mode.
`Bash` does not split into a "read-only Bash"; restricting it eliminates empirical verification entirely.
The honest trade is: trust the reviewer to follow written constraints, backed by container isolation, by the reviewer's freshness (it has no prior commitment to the implementation), and by the overseer's freedom to discard a review that violates constraints.
The same trade is already implicit in giving the implementer `full` tools, and is structurally identical to the trade the loop already makes for the reviewer's existing `Edit`: today's reviewer has `Edit` with a written-only-`last_reviewed`-frontmatter constraint, and the `Bash`/`WebFetch` posture extends that precedent rather than inventing a new one.

### Why drop `Task` from the reviewer's allowlist entirely

`Task` from any subagent fails at runtime.
Listing it in the agent frontmatter implies a working capability that does not exist.
Dropping it from the allowlist makes the agent's frontmatter honest and forces the legitimate sub-dispatch patterns (Pattern A and Pattern B) into the foreground.

### Why `/cdocs:implement` skill text gets the same cleanup, not just the iterate override

`/cdocs:implement` is commonly dispatched as a subagent outside `/cdocs:iterate` (the user's normal workflow, the implementer subagent inside iterate, parallel-agent patterns described in [`rules/workflow-patterns.md`](../../plugins/cdocs/rules/workflow-patterns.md)).
The dead text fails identically in those contexts.
Bundling the cleanup with the iterate fix keeps the related changes in one proposal and prevents the implement-side text from drifting out of sync.

### Why a notes-tag rather than a new Iteration Log column

The Iteration Log already carries `notes` and the tag fits naturally there.
A new column expands the table width without buying schema; the bracketed tag is already a precedent in the skill (`[placeholder-floor]` at [`SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md) line 25).
A grep for `[indep-verify:` over devlogs is the auditor query and is easy.

### What this proposal explicitly does NOT change

- The overseer's orchestration-only posture.
  The overseer does not gain Bash or browser tools.
- The judge's read-only posture.
  The judge still does not read source or run commands.
- The implementer's tool surface.
  `general-purpose` with `full` tools already matches intent; the only implementer-side change is dead-text removal and an explicit UI-verification directive in the dispatch prompt.
- The freshness disciplines.
  Reviewers stay fresh every iteration; implementers stay fresh on judge-call rotation.
- The verdict taxonomy (Accept / Revise / Reject).

## Edge Cases / Challenging Scenarios

### Reviewer runs a command that mutates state despite the written constraint

The constraint is written, not tool-enforced.
A reviewer that runs `git commit` or installs a dependency has violated its instructions.
Mitigation:

- Container isolation: the work is recoverable by re-instantiating the container.
- The overseer is empowered to discard a review that violates constraints and dispatch a fresh reviewer.
- The reviewer's review document is the audit artifact: a reviewer that mutates state should declare it; one that does not declare it but is caught by the overseer's pre-Accept check is grounds for `rotate-implementer`-style escalation (a `rotate-reviewer` concept may follow but is not in scope here).

### `[indep-verify: n/a]` is used as a default to dodge empirical work

The overseer is the assigner.
The verification floor at Turn 0 determines whether `n/a` is admissible.
Verification floors that mention browser, dev server, integration, end-to-end, or live behavior cannot be `n/a`; the verification floor at Turn 0 and the row's tag are both in the devlog, so the mismatch is grep-visible to an auditor, and the overseer's pre-Accept check is the in-loop enforcement point.
The judge's role is intentionally not extended to police this: the judge judges loop meta-health (progress, thrashing, structural stuckness), not tag policy.
Extending the judge here would re-implement the overseer's job at the wrong layer, the same anti-pattern [`judge.md` lines 91-93](../../plugins/cdocs/agents/judge.md) already names for second-order dispatch.

### Reviewer wants a separately-contexted investigation mid-review

Pattern B applies: the reviewer surfaces a structured "investigation requested" item in its review.
The current review proceeds without blocking on the request.
The overseer chooses whether to dispatch `/cdocs:report` immediately, roll the request into the next implementer's brief, or note it as deferred follow-up.
The review document records the request inline so the audit trail captures the decision.

### Reviewer's empirical check breaks the dev server or test database

Containers limit blast radius.
The reviewer's written constraints already prohibit migrations, codegen, and dependency installs.
Read-only inspection that crashes the dev server is recoverable by container reset; the reviewer documents the crash in its review and the overseer either dispatches a fresh reviewer or treats the crash as a finding.

### Empirical artifact path drifts (screenshot deleted, log rotated) between review and audit

Resolved by the `confirmed` definition in Proposed Solution item 4 above: the reviewer inlines the relevant excerpt into the review body for ephemeral artifacts so the audit trail is self-contained.
The reviewer's startup instructions (updated in Phase 2) repeat the rule so the reviewer cannot land a `confirmed` row without it.

### Round-N+1 reviewer reuses round-N's empirical artifact citation

In a multi-round loop, the round-N+1 reviewer may be tempted to re-cite round-N's empirical artifact rather than producing its own.
The freshness discipline says the reviewer is fresh per iteration, so re-citing is not literally self-citation, but the audit-trail value of successive `confirmed` rows weakens if they all rest on the same upstream evidence.

Rule: a `[indep-verify: confirmed]` row must rest on an empirical artifact the round-N reviewer produced *during its own review turn*.
Re-citing a prior reviewer's artifact is permitted as supplementary evidence but does not on its own justify `confirmed`.
The independence the tag witnesses is *per-row*, not loop-aggregate.

### `/cdocs:implement` invoked standalone (no overseer) hits the dead text after cleanup

After step 3 lands, standalone `/cdocs:implement` no longer instructs the agent to dispatch `/cdocs:report` from a subagent.
A standalone (non-dispatched) `/cdocs:implement` *can* use `Task`, so the new text is "investigate inline using your own tools; if you need a separate fresh context, you may dispatch `/cdocs:report` (only available at the top level)".
The text is true in both contexts: subagent invocations self-investigate, top-level invocations may dispatch.

## Test Plan

This is a documentation-and-configuration change; testing is largely artifact-level inspection plus one live-loop smoke test.

### Per-file inspection

- [`reviewer.md`](../../plugins/cdocs/agents/reviewer.md) frontmatter `tools` line matches the new allowlist exactly.
  No `Task` in the list; `Bash` present.
- [`reviewer.md`](../../plugins/cdocs/agents/reviewer.md) Constraints section enumerates each boundary as written instruction with the rationale; the "subagents cannot dispatch subagents" NOTE is present and cross-references [`judge.md`](../../plugins/cdocs/agents/judge.md) lines 91-93.
- [`SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md) old "Asymmetric second-order dispatch" section is gone; new "Subagents cannot dispatch subagents" section is present with both patterns and an example each.
- [`SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md) Turn N.a directive list includes the `/cdocs:report` suppression and the NOTE.
- [`SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md) Subagent Dispatch Reference table reflects the new reviewer allowlist.
- [`SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md) Iteration Log convention names the `[indep-verify: ...]` tag, lists each of the four values (`confirmed`, `n/a`, `deferred-to-followup`, `skipped`), states the `confirmed`-requires-citation-and-ephemeral-inline rule, names the overseer as assigner, states the `deferred-to-followup` follow-up-pointer requirement, and shows an example.
- [`implement/SKILL.md`](../../plugins/cdocs/skills/implement/SKILL.md) lines 43-44 are rewritten to the self-investigate / top-level-only-dispatch framing, including the top-level-vs-dispatched detection signal.
- [`implement/SKILL.md`](../../plugins/cdocs/skills/implement/SKILL.md) lines 69-72 (the `### Use cdocs skills as appropriate` block) are rewritten with the same framing as lines 43-44.
- [`iterate/template.md`](../../plugins/cdocs/skills/iterate/template.md) example Iteration Log row demonstrates the tag.

### Grep-level invariants

- `rg "Task" plugins/cdocs/agents/reviewer.md` returns no allowlist hit.
- `rg "from a subagent" plugins/cdocs/skills/` returns no hits in the iterate skill or implement skill bodies.
- `rg "Asymmetric second-order dispatch" plugins/cdocs/` returns no hits.
- `rg "/cdocs:report" plugins/cdocs/skills/implement/SKILL.md` is inspected to confirm every hit is qualified for top-level-vs-dispatched context (mirrors Phase 3's verification; catches half-applied Phase 3 even when neither call-site uses the "from a subagent" phrase).
- `rg "indep-verify" plugins/cdocs/skills/iterate/` returns hits in both `SKILL.md` and `template.md`.

### Live smoke test

Run `/cdocs:iterate` on a small UI proposal (a one-component change in a project with a Playwright setup, e.g., a "change the dashboard heading" proposal in the mermaid-widget project or a similar repo).
Acceptance criteria:

- The reviewer subagent reports running Playwright (or equivalent browser tooling) itself, with output excerpts inlined in the review document.
- The Iteration Log row's notes column ends with `[indep-verify: confirmed]` and the review document cites at least one empirical artifact.
- No runtime `not available inside subagents` errors appear in the implementer or reviewer transcripts.
- The `### Overseer synthesis` section, if present, does not contain empirical-verification evidence the reviewer should have produced (i.e., the overseer is not acting as a verifier-of-last-resort the way it did in the mermaid loop).
  The overseer is permitted to author that section for other reasons: judge invocation summary, terminal decision rationale, or cross-iteration context the iteration log row cannot fit.

A non-UI proposal (a documentation-only edit) is also exercised:

- The Iteration Log row's notes column ends with `[indep-verify: n/a]`, and the verification floor that justifies `n/a` is visible either inline in the row's notes (preferred) or in a one-line `### Overseer synthesis` entry for that iteration.

## Verification Methodology

The proposal's text-level invariants are verified by reading the four touched files after each phase and running the grep invariants listed in Test Plan.
The behavioral invariants are verified by the live smoke test, which is the only way to catch "the agent ignored the new instructions in practice".

If the smoke test fails because the reviewer subagent does not actually pick up the new `Bash` capability in its dispatched run (an agent-loading bug), the verification floor for this proposal is not met and the proposal returns to revision.
If the smoke test fails because the reviewer ran Bash but did not cite an artifact (a prompt-following weakness), the reviewer's startup instructions are tightened until citation is reliable.

> NOTE(opus/cdocs/iterate-agent-capabilities): the smoke test must be run by a top-level agent invocation (not as a sub-task inside this proposal's review loop), because `/cdocs:iterate` itself cannot be dispatched from inside a subagent (the same platform invariant this proposal addresses).
> The review loop for *this proposal* uses single `/cdocs:review` dispatches against the proposal document only; the live smoke test is a separate top-level run.
> Per the taxonomy this proposal introduces, this proposal's own implementation devlog should be tagged `[indep-verify: deferred-to-followup]` with a pointer to the smoke-test devlog (the Verification step below).
> This is the prototypical case the `deferred-to-followup` value exists to cover: a self-referential change to `/cdocs:iterate` whose verification floor cannot run inside its own review loop.

## Implementation Phases

Each phase is one atomic commit using conventional commit format.
Phases are ordered for safe partial rollout: Phase 1 makes the new patterns documented (Proposed Solution item 2), Phase 2 expands the reviewer (item 1), Phase 3 propagates the cleanup (item 3), Phase 4 closes the audit-trail loop (item 4).
The Verification phase below is a separate top-level invocation, not a commit.

### Phase 1: Replace second-order dispatch text with the two-pattern model

Files: [`plugins/cdocs/skills/iterate/SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md).

- Delete the "Asymmetric second-order dispatch" section (lines 179-191).
- Insert "Subagents cannot dispatch subagents" subsection in the same location with: invariant statement, Pattern A (self-investigation, default), Pattern B (surface to overseer, fallback), one example each, cross-reference to [`judge.md`](../../plugins/cdocs/agents/judge.md) lines 91-93 as the existing acknowledgement of the invariant.

Verification: grep invariants on the section title; manual read of the two patterns.
Commit: `docs(cdocs): replace dead second-order Task guidance with two-pattern model in /cdocs:iterate`.

### Phase 2: Expand reviewer agent allowlist and rewrite constraints

Files: [`plugins/cdocs/agents/reviewer.md`](../../plugins/cdocs/agents/reviewer.md).

- Update `tools` frontmatter to `Read, Glob, Grep, Edit, Write, Bash, WebFetch` (per Proposed Solution item 1: `WebFetch` is included so Pattern A's external-doc / API-reference lookups land without scope creep).
- Rewrite the "Constraints" section to enumerate the boundaries as written instructions (only-edit-last_reviewed, no-commit, no-mutating-dev-commands, no-dep-install, no-codegen, no-migrations, Bash-for-read-only-inspection-and-UI-verification).
- Add the "subagents cannot dispatch subagents" NOTE pointing at the two patterns and the judge agent's acknowledgement.

Verification: grep invariants; manual read of the constraints list; spot-check that no allowlist line includes `Task`.
Commit: `feat(cdocs): expand cdocs:reviewer to full general-purpose tools with written constraints`.

### Phase 3: Implementer dispatch override and `/cdocs:implement` dead-text cleanup

Files: [`plugins/cdocs/skills/iterate/SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md), [`plugins/cdocs/skills/implement/SKILL.md`](../../plugins/cdocs/skills/implement/SKILL.md).

- In `iterate/SKILL.md` Turn N.a, append a directive to suppress the inherited `/cdocs:report`-from-subagent text from `/cdocs:implement`, parallel to the existing review-dispatch suppression.
- In `iterate/SKILL.md` Turn N.a, append a NOTE that subagents cannot dispatch subagents and the dispatched implementer should self-investigate or surface investigation requests in its summary.
- In `implement/SKILL.md` lines 43-44, rewrite to: "Investigate inline using your own tools when you hit unknowns. If you need a separate fresh context for the investigation, dispatch `/cdocs:report` (only available when `/cdocs:implement` itself runs at the top level; subagent-dispatched `/cdocs:implement` should self-investigate or surface the request to its caller). Treat yourself as dispatched if your invocation included an explicit dispatch prompt from a parent agent; treat yourself as top-level if you were invoked directly by the user."
- In `implement/SKILL.md` lines 69-72 (the `### Use cdocs skills as appropriate` block), rewrite the `/cdocs:report` line with the same self-investigate / top-level-only-dispatch framing so both call-sites are consistent.

Verification: grep invariants on `from a subagent` and on every `/cdocs:report` call-site in `implement/SKILL.md` (each must be qualified for subagent-vs-top-level context); manual read.
Commit: `docs(cdocs): scrub dead Task-from-subagent text from /cdocs:implement and iterate override`.

### Phase 4: Iteration Log `[indep-verify]` tag convention

Files: [`plugins/cdocs/skills/iterate/SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md), [`plugins/cdocs/skills/iterate/template.md`](../../plugins/cdocs/skills/iterate/template.md).

- In `SKILL.md` "Iteration Log and Judge Log" section, add a paragraph defining the `[indep-verify: confirmed | n/a | deferred-to-followup | skipped]` tag, its four values, the `confirmed`-cites-artifact-and-inlines-excerpt rule, the overseer's assignment authority for `n/a`, the `deferred-to-followup` follow-up-pointer requirement, and the fail-loud semantics for `skipped`.
- In `SKILL.md` Turn N.b, add a directive that the reviewer empirically re-runs the verification floor for proposals whose floor requires empirical evidence, and cites at least one artifact in the review document.
- In `SKILL.md` Conventions section, add a one-sentence note that `/cdocs:iterate`'s tool-surface trust posture (reviewer with `Bash`/`WebFetch` under written constraints) assumes a sandboxed runtime, with a pointer to the reviewer agent's Constraints section for detail.
- In `template.md`, update the example Iteration Log row to demonstrate the tag.

Verification: grep invariants on `indep-verify` (must appear in both `SKILL.md` and `template.md`); manual read of the convention paragraph; template example present.
Commit: `feat(cdocs): require [indep-verify] audit tag on iterate Iteration Log rows`.

### Verification: Smoke test (live, separate top-level invocation; not a commit)

A verification step, not a commit.
Run `/cdocs:iterate` on a UI proposal in a project with Playwright (mermaid-widget or equivalent), and on a non-UI documentation-only proposal.
Confirm acceptance criteria from the Test Plan are met for both.
If issues surface, the failing phase is revised and Verification reruns.
The smoke-test devlog is the artifact `deferred-to-followup` in this proposal's implementation devlog points to.

## Summary

This proposal aligns `/cdocs:iterate`'s agent configuration with its actual deployment model (container-sandboxed general-purpose agents), removes runtime-dead guidance that hides the legitimate cross-subagent investigation paths, and adds the smallest possible audit-trail signal so independent empirical verification is grep-visible rather than diligence-dependent.

The four phases are intentionally small and ordered so each is reviewable on its own.
The smoke test in the Verification step is the only behavioral check; everything else is artifact-level invariants verifiable from the diff.

> NOTE(opus/cdocs/iterate-agent-capabilities): the verifier-subagent option from [the prior empirical-verification-gap report](file:///var/home/mjr/code/weft/weftwise/main/cdocs/reports/2026-05-18-cdocs-reviewer-empirical-verification-gap.md) is intentionally not adopted here.
> The user's stated intent (general-purpose agents in containers) makes the reviewer the natural home for empirical verification, not a sibling agent.
> If a future deployment posture reverses that intent (e.g., reviewers run outside containers with full host access), the verifier-subagent design is the right escape hatch and this proposal's reviewer-tool expansion is the part to revisit.
