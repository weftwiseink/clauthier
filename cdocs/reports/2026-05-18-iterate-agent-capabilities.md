---
first_authored:
  by: "@claude-opus-4-7"
  at: 2026-05-18T00:00:00-07:00
task_list: cdocs/iterate-skill
type: report
state: live
status: wip
tags: [iterate, reviewer, implementer, agent_capabilities, tool_surface, subagent_dispatch, empirical_verification, container_deployment]
---

# `/cdocs:iterate` Agent Capability and Dispatch Gaps

> BLUF(opus/cdocs/iterate-agent-capabilities): `/cdocs:iterate` was built as if reviewer and implementer should be tool-minimal, but the intended deployment is sandboxed containers with general-purpose agents that can drive UIs and dev servers.
> Two gaps follow: (1) the `reviewer` allowlist (`Read, Glob, Grep, Edit, Write` + nominal `Task`) cannot empirically re-verify UI work and pushes that obligation silently onto the overseer, and (2) skill/agent text sanctions read-only `Task` dispatch from subagents that the platform forbids at runtime.
> Recommend expanding the reviewer (and confirming implementer) tool surface to general-purpose capability with explicit empirical-verification framing, deleting the unexecutable second-order-dispatch guidance, and adopting a "subagents surface investigation requests; overseer dispatches" pattern in its place.

## Context / Background

The `/cdocs:iterate` skill ([`SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md)) runs an implement-review loop where a top-level overseer dispatches fresh implementer, reviewer, and judge subagents until accept-or-escalate.
Live `/cdocs:iterate` runs (most recently the mermaid-rendering-widget loop, captured in [the empirical-verification-gap report](file:///var/home/mjr/code/weft/weftwise/main/cdocs/reports/2026-05-18-cdocs-reviewer-empirical-verification-gap.md)) surfaced that the reviewer cannot drive a browser or dev server, so independent empirical verification of UI work has no first-class home in the protocol.

That earlier report concluded with a hybrid recommendation that preserved the reviewer's read-only posture and introduced a dedicated `cdocs:verifier` subagent.
This report revisits the problem under explicit, stated intent: agents in this ecosystem run in containers, the reviewer and implementer are meant to be highly general-purpose (UI testing included), and the prior tool-minimalism on the reviewer was a deviation from intent rather than a chosen invariant.
We also expand scope to the more general "subagents cannot spawn subagents" constraint, which surfaced in the same run and affects more than the reviewer.

The relevant artifacts:

- [`plugins/cdocs/skills/iterate/SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md): loop protocol, "Asymmetric second-order dispatch" section, Subagent Dispatch Reference table.
- [`plugins/cdocs/agents/reviewer.md`](../../plugins/cdocs/agents/reviewer.md): reviewer agent definition, `tools: Read, Glob, Grep, Edit, Write, Task`, the `Task`-for-read-only-`/cdocs:report` clause.
- [`plugins/cdocs/agents/judge.md`](../../plugins/cdocs/agents/judge.md): judge agent definition, already explicit that "subagents cannot dispatch subagents" is a platform invariant.
- [`plugins/cdocs/skills/implement/SKILL.md`](../../plugins/cdocs/skills/implement/SKILL.md): implementer skill text that requests subagent-driven review and report dispatch, which `/cdocs:iterate` already overrides.

## Key Findings

### 1. The reviewer's tool surface was set as if the role were a paper auditor, not a container-deployed QA engineer

The `cdocs:reviewer` allowlist is `Read, Glob, Grep, Edit, Write, Task` ([`reviewer.md`](../../plugins/cdocs/agents/reviewer.md) line 5).
The iterate dispatch table further trims `Task` ([`SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md) line 233 shows `Read, Glob, Grep, Edit, Write`).
There is no Bash and no browser path, so the reviewer cannot start a dev server, run the project's Playwright, inspect rendered DOM, or pull console/network logs.

The user's stated intent is the opposite of this posture: agents run in sandboxed containers, and the reviewer is meant to be highly general-purpose, including UI testing.
The current allowlist enforces a detachment that nothing in the deployment model actually requires.
The reviewer's "independence" is preserved by *being a fresh subagent with no implementer context*, not by *being unable to type a command*.

### 2. The second-order-dispatch guidance in skill and agent text is not executable on this platform

[`SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md) "Asymmetric second-order dispatch" (lines 186-188) says "a reviewer may dispatch `/cdocs:report` to investigate a recurring bug class without leaving the review turn".
[`reviewer.md`](../../plugins/cdocs/agents/reviewer.md) lines 47-49 sanction `Task` for that exact purpose.
At runtime, `Task` from inside any subagent errors with `not available inside subagents`: a dispatched subagent cannot itself dispatch a subagent on the platform.

The judge agent's documentation already acknowledges this as a hard invariant ([`judge.md`](../../plugins/cdocs/agents/judge.md) lines 91-93: "Your toolset omits Task by design"), but the reviewer agent and the iterate skill text were written as if read-side dispatch from a subagent works.
The consequence is that the reviewer's "if you need to investigate something, dispatch `/cdocs:report`" escape hatch is dead text.
Worse, its presence implies a valid path that does not exist, masking the fact that cross-subagent investigation has nowhere to legitimately originate.

The implementer side has an analogous shape.
[`/cdocs:implement`](../../plugins/cdocs/skills/implement/SKILL.md) lines 43-44 instructs implementers to "Request `/cdocs:review` from a subagent after each phase" and "Request `/cdocs:report` for research topics".
`/cdocs:iterate` already overrides the review-dispatch sentence ([`SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md) lines 173-177), but the report-dispatch sentence is silently inherited and is similarly non-executable from inside a dispatched implementer.

### 3. The empirical-verification obligation has no first-class place to live

Reviews of UI proposals state a need ("the live behavior is empirically verified in a real browser") that the role assigned to producing the verification cannot meet.
The mandate then relocates: in the mermaid run the overseer absorbed it via two ad-hoc Playwright sessions documented in `### Overseer synthesis` prose.
That worked because the overseer was diligent; it would not work if the overseer were less so, and the audit trail (Iteration Log + Judge Log) would not reveal the omission either way.

This is the most load-bearing finding for any remedy.
The whole value of `/cdocs:iterate` is its structured audit trail.
A diligence-dependent step in the loop's most evidence-sensitive path is the kind of failure the skill exists to prevent in other places.

### 4. The implementer is closer to the user's intended posture than the reviewer

[`SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md) line 232 lists the implementer as `subagent_type: general-purpose`, tools = "full".
That already matches "highly general-purpose, can do UI testing".
The implementer's gap is not capability but the inherited dead `Task`-dispatches-`/cdocs:report` text from `/cdocs:implement`.
Confirming the implementer's full-tools posture and explicitly framing UI verification as part of its self-verification floor brings its setup into line with the reviewer changes proposed below.

## Analysis

### Why the prior remedy (preserve reviewer detachment + add a verifier subagent) is not the right shape under this intent

The earlier report's hybrid recommendation kept the reviewer read-only and added a `cdocs:verifier` subagent dispatched by the overseer.
Under "reviewers are paper auditors", that minimizes blast radius and preserves a clean role separation.
Under the user's actually-stated intent ("reviewer should be highly general-purpose, including UI testing, in a sandboxed container"), the same design becomes machinery to work around a tool restriction that was never wanted in the first place.

Three concrete costs of the verifier-subagent design under this intent:

- An extra agent definition, an extra artifact type, and an extra dispatch step the overseer must remember and the audit trail must accommodate.
  All to recover capability the reviewer was supposed to have.
- A division between "the role that judges the work" and "the role that produces the empirical evidence the judgement rests on", which inverts the reviewer's purpose (the reviewer is supposed to *be* the independence anchor, not consume one).
- A persistent foot-gun: an overseer that forgets to dispatch the verifier reproduces the original silent-relocation failure.

The container deployment changes the original trade-off.
The blast-radius worry that motivated tool restriction (a reviewer running mutating commands erodes the implement/review boundary) is materially weaker when the agent is in a throwaway container and is *also* a fresh subagent with no implementer context.
Freshness, not tool restriction, is what makes the reviewer independent.

### The "subagents cannot spawn subagents" constraint, generalized

The platform invariant applies to every dispatched subagent (implementer, reviewer, judge), not just the reviewer.
Any guidance that says "subagent X may dispatch subagent Y" is non-executable.
There are two clean ways to handle this in the loop, both compatible with the broader capability expansion above:

- **Self-investigation.** A subagent with `Read, Glob, Grep, Bash, WebFetch, etc.` can do most of what `/cdocs:report` does without dispatching anything.
  The "report" framing was a vehicle for "do focused research in a fresh context"; a general-purpose subagent already has fresh context and now has the tools.
  Investigation results can be inlined into the review or the implementer summary, or written to `cdocs/reports/` directly.
- **Surface-to-overseer.** A subagent that genuinely needs *another* fresh context (e.g., the reviewer wants a *separate* agent to look at a recurring bug class without that work polluting the review's context budget) returns a structured "investigation requested" item in its output.
  The overseer reads it and either dispatches a `/cdocs:report` subagent or rolls the request into the next implementer's brief.
  This mirrors how implementers already surface "I think this proposal is wrong" as structured uncertainty ([`SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md) lines 190-191).

The two paths are complementary, not exclusive.
Self-investigation is the default; surface-to-overseer is the fallback when fresh context is the actual ask.
Either way, the existing skill/agent text that pretends second-order `Task` works should be deleted.

### Tool-surface options, framed under the actual intent

#### Option A: Full general-purpose tools for the reviewer (matches stated intent)

`reviewer.md` allowlist becomes `Read, Glob, Grep, Edit, Write, Bash` (plus the project's browser path, e.g., Playwright via Bash), with the existing constraints retained as *instructions* rather than tool restrictions:

- Only Edit the target document's `last_reviewed` frontmatter.
- Do not modify implementation source files.
- Do not commit (the overseer owns commit authority).
- Treat the review document as the single mutating artifact you author.

This restores empirical capability where the role conceptually owns independence, removes a layer of indirection, and keeps the audit trail simple (the review document is where the empirical evidence lives, where it is already supposed to live).

- Pros: directly matches stated intent; smallest amount of new machinery; reviewer is the agent best positioned to interpret its own empirical findings; container deployment makes the historical blast-radius worry weak.
- Cons: relies on the reviewer following written constraints (not running mutating commands, not committing) rather than tool-level enforcement.
  This is the explicit trade.
  Mitigated by: container isolation, the fresh-context discipline, and the overseer's freedom to discard a review that violates constraints.
- Cons: every reviewer invocation now warms up empirical tooling even for non-UI proposals; small constant overhead per loop.

#### Option B: Carve out a narrower capability bundle (Bash-but-no-Edit, or browser-only)

A middle ground: give the reviewer Bash and browser tools but explicitly not Edit, with the review document written via Write only.

- Pros: tool-level enforcement of "no implementation edits".
- Cons: more complicated than Option A under the container-deployed intent and still leaves the "no commit", "no mutating dev commands" guidance as instruction rather than tool-level.
  The honest line, given containers and a written constraint list, is Option A.

#### Option C: Status quo + a dedicated verifier subagent (the prior report's recommendation)

Already analyzed above as the recommended option in the prior report.
Under the stated intent it has a worse cost/benefit than Option A.

### Implementer-side implications

Three follow-on changes are needed in lockstep regardless of which reviewer option is chosen:

- The implementer's tool surface is already `full` ([`SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md) line 232).
  No allowlist change required; just an explicit confirmation in the dispatch table that "full" includes browser tooling for UI work, and a directive in the dispatch prompt to use it as part of self-verification.
- The implementer's inherited dead text from `/cdocs:implement` ("Request `/cdocs:report` from a subagent...") needs the same suppression treatment that `/cdocs:iterate` already applies to the inherited review-dispatch instruction.
- Both implementer and reviewer dispatch prompts gain a short "subagents cannot dispatch subagents on this platform; investigate inline or surface investigation requests in your structured output" NOTE.

### The audit-trail question, regardless of capability shape

Even with Option A, the loop needs a way for an auditor reading only the Iteration Log to tell whether independent empirical verification happened.
The cheapest move is a mandatory notes-tag convention on the Iteration Log row: `[indep-verify: confirmed | n/a | skipped]`.
`confirmed` requires the review document to cite a specific empirical artifact (screenshot path, Playwright run output, dev-server log excerpt).
`n/a` is for proposals whose verification floor does not require empirical browser evidence.
`skipped` is an explicit fail-loud value the overseer must justify in the iteration notes or before Accept.

This is a strict superset of the prior report's audit-column proposal and pairs with Option A; it does not require Option C.

## Recommendations

Adopt Option A (full general-purpose reviewer, retained constraints as written instruction), with the dispatch-guidance cleanup and audit-trail tag applied in lockstep.

Concrete next steps, sized as one proposal:

1. **Reviewer agent definition.**
   Expand [`reviewer.md`](../../plugins/cdocs/agents/reviewer.md) `tools` to include `Bash` and the project browser path.
   Convert the existing `Task`-for-`/cdocs:report` clause into a "subagents cannot dispatch subagents" NOTE that points to the surface-to-overseer pattern.
   Keep "only Edit the target's `last_reviewed` frontmatter", "do not commit", and "do not run mutating dev commands beyond what is required to inspect the live system" as explicit *constraints* the reviewer must honor.

2. **Iterate skill text.**
   Update [`SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md) Subagent Dispatch Reference table to reflect the new reviewer allowlist.
   Delete the "Asymmetric second-order dispatch" sentence that sanctions reviewer/implementer second-order `Task`; replace with a "Subagents cannot dispatch subagents" subsection that names the two legitimate patterns (self-investigation, surface-to-overseer).
   Add a Turn N.b directive that the reviewer empirically re-runs the verification floor for UI/empirical proposals before issuing a verdict, and cites the empirical artifact in the review document.

3. **Implementer dispatch.**
   Add the implementer-side override to suppress the inherited `/cdocs:report`-via-subagent instruction from `/cdocs:implement`, parallel to the existing review-dispatch override.
   Add the same "subagents cannot dispatch subagents" NOTE to the implementer dispatch prompt template.

4. **Audit-trail tag.**
   Add a mandatory `[indep-verify: confirmed | n/a | skipped]` notes-tag convention on the Iteration Log row.
   `confirmed` requires the review to cite an empirical artifact; `skipped` is fail-loud and the overseer must justify it inline before Accept.

5. **`/cdocs:implement` skill text (optional follow-on).**
   The dead `Task`-dispatches-subagent text in [`implement/SKILL.md`](../../plugins/cdocs/skills/implement/SKILL.md) lines 43-44 also fails outside the iterate loop whenever `/cdocs:implement` itself is dispatched as a subagent (which it commonly is).
   Worth normalizing the same "self-investigate or surface to caller" language across the implement skill, not only the iterate override.
   Out of scope for the loop fix; flagged here as a sibling cleanup.

The success measure is operational, not aesthetic: the next live UI `/cdocs:iterate` run should record `[indep-verify: confirmed]` with a real empirical artifact cited *by the reviewer itself*, without the overseer needing to absorb a verification turn that the protocol does not name.
