---
review_of: cdocs/proposals/2026-05-13-iterate-skill.md
first_authored:
  by: "@claude-opus-4-7"
  at: 2026-05-13T09:30:00-07:00
task_list: cdocs/iterate-skill
type: review
state: live
status: done
tags: [fresh_agent, iterate_skill, architecture, freshness_heuristics, dispatch_consistency, test_plan]
---

# Review: Proposal for `/cdocs:iterate` Skill

## Summary Assessment

The proposal codifies a recurring overseer pattern (implement -> review -> decide) as a peer skill to `/cdocs:implement` and `/cdocs:review`.
The taxonomy, loop protocol, and freshness rules are well-grounded in the companion report and prior art.
Several concrete inconsistencies undermine the design: the proposal asserts the existing `reviewer` agent runs on sonnet (it runs on opus per `plugins/cdocs/agents/reviewer.md`), conflates the user-as-overseer with an agent-as-overseer in the invocation contract, and leaves the implementer-dispatch mechanism (top-level vs. a yet-to-exist subagent) underspecified.
**Verdict: Revise.** The blockers are local and the design is otherwise sound.

## Section-by-Section Findings

### BLUF and Objective

The BLUF is on target and clearly states peer-status to `/oversee`.
The Objective's phrase "an overseer that never edits code" presumes the overseer is always a subagent.
The Invocation section says the *user* is the overseer (or has delegated one).
These two framings conflict: a user invoking `/cdocs:iterate` cannot be a tools-restricted no-edit agent, and an agent overseer requires a separate dispatch mechanism not yet specified.
**[blocking]** — resolve who runs the skill's orchestration: the top-level agent in whatever session invokes it, with the user as the human supervisor.

### Role Taxonomy

Clear and load-bearing.
The synonyms list is useful, the responsibilities are one-liners, and the mapping to existing skills/agents is direct.
**[non-blocking]** Reviewer responsibility should call out the constraint already encoded in `reviewer.md`: "Only Edit the target document's `last_reviewed` frontmatter."
That constraint is what makes the reviewer's hostility safe.

### Loop Protocol and Iteration Log

The mermaid state diagram matches the report's protocol.
Turn N.c's branching is well-specified.
Two gaps:
- **[blocking]** The `blocking_count` metric is defined nowhere.
  Reviews under the existing `/cdocs:review` template do not produce a numeric `blocking_count`; they produce a numbered Action Items list where each item is tagged `[blocking]` or `[non-blocking]`.
  The skill must specify how it derives `blocking_count` (count of `[blocking]` tags in the action items list, presumably) and how it detects "oscillation" (same issue text recurring across reviews vs. issue count alone).
  Without this, the fatigue and oscillation triggers are unfalsifiable.
- **[non-blocking]** The Iteration Log table has columns `implementer` and `reviewer` populated with model-and-letter handles (`@sonnet-X`, `@opus-Y`).
  Real subagent dispatch does not expose a session identifier the overseer can transcribe.
  Specify what the column actually holds: the model name plus iteration number, or a synthetic handle the skill generates.

### Invocation

The flag set is reasonable but the dispatch mechanism is underspecified.
- **[blocking]** "The top-level agent (or an explicit subagent type) for implementations" (Skill File Surface) leaves the implementer-dispatch question open.
  `/cdocs:implement` is a *slash command skill*, not a subagent.
  The skill must state plainly: does the overseer dispatch a new general-purpose subagent via Task tool and instruct it to follow `/cdocs:implement`, or does the overseer execute `/cdocs:implement` itself in its own context (which would conflict with the no-edit constraint)?
  The companion report's "Implementer dispatch (from overseer)" snippet implies a Task-tool subagent that loads the implement skill, but the proposal does not commit to that.
- **[non-blocking]** `--max-flat-iterations` defaults to 3 with no rationale.
  Companion report says "N=3 is a reasonable default" with equal lack of justification.
  Either justify (e.g., "two flat iterations to trigger implementer rotation, one more to confirm oscillation") or note the value as an empirical knob.

### Important Design Decisions

Most decisions are well-justified.
Two flag points:
- **[blocking]** "Defaults match existing cdocs reviewer agent. The reviewer uses the existing `reviewer` agent (sonnet, preloaded with `/cdocs:review`)."
  This is factually wrong: `plugins/cdocs/agents/reviewer.md` declares `model: opus`.
  The Open Questions section then asks whether to add `--reviewer-model opus`, which is incoherent if the default is already opus.
  Fix the factual claim and re-examine whether the open question survives.
- **[non-blocking]** "No second-order subagent dispatch from the loop" is good policy but the `NOTE` callout's example (implementer flagging "the proposal is wrong") needs to also cover the reverse case the companion report raised: may a reviewer dispatch `/cdocs:report` for investigation?
  Open Question 2 says "yes"; the design-decisions section says "no second-order dispatch."
  Reconcile.

### Stories

Stories 1-3 exercise the principal happy path, fatigue rotation, and oscillation.
Story 4 (Reject) and Story 5 (`/oversee` composition) are concise and informative.
**[non-blocking]** Missing a story for "no verification floor specified" — the edge case is documented but not narratively walked, and it is the most-cited failure mode in the parent RFP.

### Edge Cases

Reasonably comprehensive.
**[non-blocking]** Three gaps worth a sentence each:
- What happens if the proposal's `task_list` differs from any existing devlog's `task_list` — does the skill create a new devlog or append to an existing one?
- Token-budget exhaustion mid-iteration: the proposal says "be very patient" but does not say how the loop survives auto-compaction.
- Test-suite-passes-but-verification-floor-not-met: the reviewer's review document is the authority, but the iteration log should distinguish "tests passed but reviewer says Revise" from "tests failed" so future readers can see verification-rigor patterns.

### Test Plan and Verification Methodology

Mechanical verification items 1-3 are checkable.
**[blocking]** Behavioral verification item 4 ("verified by inspecting the dispatched Task call's prompt") is not directly checkable: Task-tool dispatch prompts are not first-class artifacts in any cdocs file.
The verification step needs an observable proxy: e.g., "the devlog's iteration log shows a new `implementer` handle in row 3" or "the implementer turn's structured summary references the iteration log onboarding."
**[non-blocking]** Test plan item 6 (dogfood) is the strongest signal; consider making the dogfood proposal a required Phase 4 deliverable, not a phantom future invocation.

### Implementation Phases

Phase boundaries and dependencies are clear.
**[non-blocking]** Phase 2's file list says "`plugins/cdocs/.claude-plugin/plugin.json` (or equivalent manifest)."
The current `plugin.json` does not register skills explicitly; skills are discovered by directory layout.
Phase 2 likely requires no edit to `plugin.json` and the list should drop it (or confirm by inspection before listing).

### Open Questions

Mostly real open questions.
**[non-blocking]** Question 1 (reviewer model selection) is moot once the sonnet-vs-opus fact is corrected; either keep it as "should `/cdocs:iterate` allow downgrading to sonnet for speed?" or remove.
Question 2 (reviewer dispatching `/cdocs:report`) is decided by the Important Design Decisions section but answered ambiguously across the two locations: pick one and remove the inconsistency.

## Cross-Document Consistency

- **vs. `/cdocs:implement`:** `/cdocs:implement` instructs implementers to "Request `/cdocs:review` from a subagent after each phase."
  Under `/cdocs:iterate`, the implementer is told *not* to dispatch its own reviewer.
  These compose if `/cdocs:iterate` overrides the in-implement review-dispatch directive, but the proposal should state that explicitly to avoid implementer subagents following `/cdocs:implement` verbatim and double-reviewing.
- **vs. `/cdocs:review`:** Consistent. The dispatch path via the formal `reviewer` agent is correct.
- **vs. `/oversee` RFP:** The RFP says `/oversee` "is for a top-level orchestrator" managing "multi-proposal project arcs."
  The proposal's peer-status claim is consistent with this scope.
  However, the RFP describes `/oversee` invoking `/implement`, `/review`, `/propose`, `/report` directly — not invoking `/cdocs:iterate`.
  The proposal asserts `/oversee` will invoke `/cdocs:iterate` per proposal, which is a refinement of the RFP, not a contradiction.
  Worth a one-sentence callout that this proposal *narrows* the RFP's "invokes /implement" gesture into "invokes /cdocs:iterate per proposal."
- **vs. `workflow-patterns.md`:** The "Subagent-Driven Development" pattern says "Maintain devlog as single source of truth (synthesize subagent findings)."
  This proposal restates that and adds the iteration-log convention.
  Consistent.

## Form / Writing Conventions

- BLUF present and informative.
- Sentence-per-line: mostly followed.
- Em-dash avoidance: clean (uses colons throughout).
- Mermaid usage: appropriate.
- Direct external links: present and clickable.
- History-agnostic framing: holds.
- **[non-blocking]** A few NOTE callouts repeat content already in the body text (the iteration-log NOTE re-states the bullet immediately above it). Consider trimming.

## Verdict

**Revise.** The proposal's structure and intent are accepted.
The blockers are factual or definitional (`blocking_count` derivation, reviewer-model claim, implementer-dispatch mechanism, user-vs-agent overseer ambiguity, test-plan checkability).
All are local edits.

## Action Items

1. **[blocking]** Reconcile "user is the overseer" (Invocation) with "overseer never edits code" (Objective/Role Taxonomy). State plainly: the top-level agent in the invoking session orchestrates; the user remains the human supervisor for escalation.
2. **[blocking]** Define `blocking_count` precisely (count of `[blocking]`-tagged action items in the review document) and define "oscillation" detection (same issue text recurring vs. count parity).
3. **[blocking]** Specify the implementer dispatch mechanism explicitly: Task-tool subagent loaded with `/cdocs:implement`, top-level execution, or new subagent type. State which.
4. **[blocking]** Correct the claim that the existing reviewer agent runs on sonnet — it runs on opus per `plugins/cdocs/agents/reviewer.md`. Re-examine Open Question 1.
5. **[blocking]** Make Test Plan item 4 ("verified by inspecting the dispatched Task call's prompt") observable: switch to an artifact-based check (iteration log row, structured summary content).
6. **[non-blocking]** Add a sentence to the Important Design Decisions section noting that `/cdocs:iterate` overrides `/cdocs:implement`'s in-skill instruction to dispatch its own reviewer.
7. **[non-blocking]** Reconcile reviewer second-order dispatch: Open Question 2 says yes, "No second-order subagent dispatch" says no. Pick one.
8. **[non-blocking]** Justify or empirically flag `--max-flat-iterations=3` default.
9. **[non-blocking]** Define what the Iteration Log's `implementer`/`reviewer` columns actually hold (model + iteration index, or generated handle).
10. **[non-blocking]** Drop or confirm `plugin.json` from Phase 2's file list (current manifest does not register skills).
11. **[non-blocking]** Add an edge-case sentence for token-budget/compaction mid-loop and for divergent `task_list` vs. existing devlog.
12. **[non-blocking]** Add a story (or expand an existing one) walking the "no verification floor specified" path end-to-end.

## Questions for the Author (Multiple Choice)

A. For the implementer dispatch in Action Item 3, which does the proposal commit to?
   1. Task-tool dispatch of a fresh subagent instructed to follow `/cdocs:implement`.
   2. A new formal `implementer` agent in `plugins/cdocs/agents/` analogous to `reviewer.md`.
   3. The top-level agent executes `/cdocs:implement` directly (incompatible with no-edit overseer).

B. For `blocking_count` (Action Item 2):
   1. Literal count of `[blocking]` tags in the review's Action Items.
   2. Count of distinct issue topics flagged as blocking.
   3. Reviewer-declared scalar field added to the review template.

C. For oscillation detection (Action Item 2):
   1. Same issue text appearing in N consecutive reviews after being marked resolved.
   2. Count flatness alone (already partly captured by `--max-flat-iterations`).
   3. Heuristic deferred to a v2; v1 escalates only on Reject or N flat iterations.
