---
first_authored:
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-30T12:30:00-08:00
task_list: cdocs/process-improvement
type: report
state: live
status: review_ready
tags: [analysis, process, workflow, review, proposals, user_interaction]
---

# Review Question Surfacing Analysis

> BLUF(@claude-opus-4-5-20251101/process-improvement): The review skill explicitly instructs reviewers to surface clarifying questions as multiple-choice options for the user, but zero of the 13 reviews in the project have done this.
> Every review operates as a fully autonomous verdict machine: it analyzes the document, renders findings, issues a verdict, and lists action items, all without ever pausing to ask the user for input on ambiguous decisions.
> The propose skill has the same gap: no proposal in the project paused to ask the user for design direction on ambiguous choices.
> This pattern reduces user control over decision points and leads to rework when the agent's autonomous choices diverge from user intent.

## Context / Background

The review skill (`plugins/cdocs/skills/review/SKILL.md`) contains an explicit instruction for question surfacing:

> IMPORTANT: Doc Reviews should keep an eye out for any underconsidered sections, potential pitfalls, and points in need of clarification.
> Reviewer should surface the latter at the end of the review as multiple choice options.

This instruction was a design goal: reviews should not just render verdicts but also identify decision points that require user input.
The present analysis examines every review and proposal in the project to determine whether this goal has been achieved in practice.

The companion report (`cdocs/reports/2026-01-30-cdocs-process-analysis.md`) identified a related problem: the central agent skips workflow pipeline steps (nit-fix, triage, review dispatch) because cross-cutting rules are not surfaced at the point of action.
This report extends that analysis to a subtler problem: even when reviews and proposals are executed, they operate with too much autonomy and too little user interaction.

## Key Findings

### Finding 1: Zero of 13 reviews surfaced clarifying questions to the user

Every review in `cdocs/reviews/` was analyzed for the presence of user-directed questions.
The results:

| Review | Verdict | Questions to user? | Notes |
|--------|---------|-------------------|-------|
| `review-of-cdocs-plugin-architecture` | Revise | No | 9 action items, all directives to the author |
| `review-of-triage-v2-agents-and-automation` | Revise | No | 11 action items, 4 "underconsidered scenarios" - but framed as findings, not questions |
| `review-of-triage-v2-implementation` | Accept | No | 3 non-blocking action items |
| `review-of-nit-fix-skill` | Revise | No | 9 action items, all directives |
| `review-of-nit-fix-agent` (R1) | Revise | No | 10 action items, all directives |
| `review-of-nit-fix-agent-r2` | Accept | No | 3 non-blocking items; "Underconsidered Sections" present but framed as advice, not questions |
| `review-of-nit-fix-agent-r3` | Accept | No | 6 non-blocking items; "Underconsidered Sections" present but again framed as observations |
| `review-of-haiku-subagent-workflow-automation` | Accept | No | 3 non-blocking items |
| `review-of-haiku-subagent-implementation` | Revise | No | 5 action items, all directives |
| `review-of-rfp-skill` (R1) | Revise | No | 8 action items, all directives |
| `review-of-rfp-skill-round-2` | Accept | No | 1 non-blocking item |
| `review-of-rfp-skill-implementation` | Accept | No | 2 non-blocking items |
| `review-of-archive-formalism` | Revise | No | 7 action items, all directives |

None of these reviews contain language like "I need the user to decide X" or "The user should choose between A and B" or present multiple-choice options for the user.
Every action item is phrased as a directive to the document author (which is itself an agent).

### Finding 2: The "Underconsidered Sections" pattern comes closest but misses

Two reviews (`review-of-nit-fix-agent-r2` and `review-of-nit-fix-agent-r3`) include an "Underconsidered Sections / Points for Clarification" section at the end.
This is the closest any review comes to the skill's instruction to "surface points in need of clarification as multiple choice options."

However, both instances frame these sections as observations and advice to the implementer, not as questions requiring user input:

- R2 lists three items (A, B, C) framed as "aspects that could benefit from consideration during implementation."
  Each item is presented as a recommendation, not as a decision point requiring user choice.
- R3 lists four items (A, B, C, D) framed as "aspects that could benefit from consideration."
  Again, recommendations and observations, not user-facing questions.

The skill instruction says "surface the latter at the end of the review as multiple choice options."
Neither review presents multiple-choice options.
Neither review directs anything to the user as opposed to the author/implementer.

### Finding 3: The review skill's instruction is ambiguous about audience

The review skill's IMPORTANT callout says "Reviewer should surface the latter at the end of the review as multiple choice options."
This instruction has two ambiguities:

1. **Who is the audience?** The skill does not specify that the questions should be directed to the user (human).
   The reviewer could interpret "surface" as meaning "include in the review document for whoever reads it next."
   Since the review document is typically consumed by another agent (the author, following the triage -> review -> revise cycle), the reviewer may reasonably conclude that the "audience" is the revising agent, not the human user.

2. **What are "multiple choice options"?** The instruction does not explain what a well-formed question looks like.
   Should the reviewer present literal A/B/C choices?
   Should it frame them as design decisions with trade-offs?
   The lack of a concrete example or template for this output format means reviewers have no model to follow.

### Finding 4: The review skill implicitly encourages autonomous verdicts

Beyond the single IMPORTANT callout about question surfacing, the entire rest of the review skill is structured around autonomous evaluation:

- The Summary Assessment section asks for "overall quality assessment" and "the most important finding(s)."
- The Section-by-Section Findings section asks the reviewer to "state the issue clearly" and "categorize as blocking or non-blocking."
- The Verdict section offers three choices (Accept, Revise, Reject), all of which are agent decisions, not user decisions.
- The Action Items section asks for "specific tasks" that are "specific enough to act on without re-reading the full review."

The entire flow presumes the reviewer is a decision-maker.
The single IMPORTANT callout about surfacing questions is structurally overwhelmed by the skill's dominant framing as a verdict-rendering system.

### Finding 5: The propose skill does not encourage question surfacing at all

The propose skill (`plugins/cdocs/skills/propose/SKILL.md`) contains no instruction to ask the user clarifying questions during drafting.
Its Drafting Approach section is entirely autonomous:

1. Start with the BLUF.
2. Fill in Objective and Background.
3. Explore possible approaches.
4. Break into phases, write test plans, consider edge cases.
5. Review the author checklist.
6. Revisit and refine the BLUF.

At no point does this flow include a step like "identify ambiguous requirements and ask the user for direction before proceeding."
The Author Checklist similarly contains no item about verifying that key design choices align with user intent.

### Finding 6: Proposals made autonomous design decisions that warranted user input

Several proposals contain design decisions that a thoughtful author would have surfaced to the user:

- **Triage v2 proposal:** Decision 1 (hook-scoped Edit for mechanical fixes) was a fundamental architectural choice that the reviewer later flagged as mischaracterizing the mechanical/semantic boundary.
  The proposing agent chose a position autonomously rather than presenting the trade-off to the user.

- **Nit-fix skill proposal:** The choice between direct-edit and read-only subagent patterns was a significant design fork.
  The proposing agent chose direct-edit, which the reviewer then flagged as conflicting with the accepted triage architecture.
  If the user had been asked "should nit-fix follow the read-only pattern from triage or diverge?", a round of revision could have been avoided.

- **RFP skill proposal:** The Phase 2 scope (modifying the propose skill for in-place elaboration) was a cross-skill architectural decision.
  The proposing agent committed to in-place elaboration without asking the user whether a separate elaboration skill would be preferred.

- **Archive formalism proposal:** The dependency on the CLI RFP was a structural risk.
  The proposing agent could have asked "should we define the convention separately from the CLI automation?" rather than coupling them and having the reviewer flag the coupling as blocking.

In each case, the autonomous choice led to a "Revise" verdict that required rework to address the reviewer's concerns.
If the proposing agent had surfaced the decision point to the user, the first draft might have aligned with user intent.

## Analysis

### The autonomy bias

Both the review and propose skills exhibit what might be called an "autonomy bias": they are structured to produce complete, self-contained outputs without interruption.
This bias is understandable: agents are optimized for task completion, and pausing to ask questions feels like a failure to deliver.
But the result is that agents make judgment calls on ambiguous matters, present those calls as conclusions, and only discover misalignment when a reviewer (another agent) flags problems.

The current pipeline looks like:

```
User request -> Agent writes proposal (autonomous) -> Agent reviews (autonomous) -> Agent revises (autonomous) -> User sees finished product
```

A question-surfacing pipeline would look like:

```
User request -> Agent identifies decision points -> User makes key choices -> Agent writes proposal (informed) -> Agent reviews (flags remaining ambiguities to user) -> User resolves -> Done
```

The second pipeline has more user touchpoints but likely fewer revision cycles.

### When questions genuinely need user input vs. when they would slow things down

Not every ambiguity warrants a user question.
The distinction:

**Genuinely needs user input:**
- Design direction choices with multiple valid approaches and no clear technical winner (e.g., read-only vs. direct-edit subagent pattern).
- Priority and scope decisions (e.g., should this proposal also cover the CLI integration, or scope it to the convention only?).
- Cross-cutting architectural choices that affect multiple skills or components.
- Risk tolerance decisions (e.g., "the blast radius of this approach includes X; is that acceptable?").
- Requirements that are ambiguous in the user's original request.

**Does not need user input (would slow things down):**
- Formatting choices within established conventions.
- Implementation details with clear best practices (file naming, frontmatter field ordering).
- Obvious architectural decisions where one option is clearly superior.
- Test plan details that follow established patterns.
- Non-blocking suggestions that the author can evaluate independently.

The current system treats everything as the second category.
The improvement needed is not "ask about everything" but "identify the first category and escalate it."

### The structural problem with the review-as-autonomous-verdict model

The review skill's structure actively works against question surfacing.
Consider the reviewer's cognitive flow:

1. Read the document.
2. Evaluate each section.
3. Identify issues.
4. Classify as blocking or non-blocking.
5. Render a verdict.
6. Write action items.

At no point in this flow does the reviewer think "is this a question for the user?"
The flow is entirely focused on the reviewer's own judgment.
When the reviewer encounters an ambiguity, the natural action within this framework is to form an opinion and express it as a finding, not to escalate it as a question.

The skill's IMPORTANT callout attempts to inject question surfacing into this flow, but it is a single instruction competing against a six-step methodology that rewards autonomous analysis.

## Recommendations

### Recommendation 1: Add a "Questions for the User" section to the review template

Add a required section to the review template (`plugins/cdocs/skills/review/template.md`):

```markdown
## Questions for the User

<!-- Required. If the reviewer has no questions, write "No questions: all decision points are clear." -->
<!-- For each question, present 2-3 options with brief trade-off analysis. -->
```

Making this a structural section rather than a buried instruction forces the reviewer to explicitly consider whether any decision points should be escalated.
The "no questions" fallback prevents the section from being a blocker when genuinely not needed.

### Recommendation 2: Revise the review skill's IMPORTANT callout with concrete guidance

Replace the current callout:

```
> IMPORTANT: Doc Reviews should keep an eye out for any underconsidered sections, potential pitfalls, and points in need of clarification.
> Reviewer should surface the latter at the end of the review as multiple choice options.
```

With something more directive and specific:

```
> IMPORTANT: Before rendering a verdict, identify any decision points where the user (human) should choose the direction.
> These include: design choices with multiple valid approaches, scope/priority decisions, risk tolerance questions, and ambiguous requirements.
> Surface these in the "Questions for the User" section as numbered items, each with 2-3 options and a brief trade-off summary.
> The reviewer may state a recommendation but must present alternatives.
> Do NOT autonomously resolve ambiguities that affect project direction: escalate them.
```

This revision:
- Specifies the audience (the human user, not the revising agent).
- Lists the categories of questions that warrant escalation.
- Provides a concrete output format.
- Distinguishes between recommending and deciding.

### Recommendation 3: Add a "Decision Points" step to the propose skill's drafting approach

Insert a step between the current steps 3 and 4 in the propose skill's Drafting Approach:

```markdown
3.5. Identify decision points where user input would prevent rework.
   For each ambiguous design choice, scope question, or priority trade-off:
   - Present 2-3 options with trade-offs.
   - Ask the user to choose before proceeding with detailed design.
   - If the user is unavailable, document the choice and rationale as a Design Decision
     with a NOTE callout flagging it as "author's choice, not user-directed."
```

This step ensures that proposing agents do not silently resolve ambiguities.
The "user unavailable" fallback preserves the ability to complete work autonomously when necessary, while still flagging the autonomous choice for later review.

### Recommendation 4: Add a "user_input_needed" workflow action to the triage system

The triage skill's dispatch table currently has five actions: REVIEW, REVISE, ESCALATE, STATUS, NONE.
Add a sixth: USER_INPUT_NEEDED.

This action would be triggered when:
- A review contains items in its "Questions for the User" section.
- A proposal is marked `review_ready` but contains NOTE callouts flagging author's choices that were not user-directed.

The triage dispatcher would surface these to the user rather than proceeding to the next automated step.

### Recommendation 5: Add question-surfacing examples to the review skill

The review skill lacks any example of what a good question looks like.
Add a brief example section:

```markdown
### Example: Questions for the User

1. **Subagent edit model**: The proposal uses direct Edit for the nit-fix agent.
   The triage agent uses a read-only model. Which pattern should nit-fix follow?
   - (a) Read-only (consistent with triage, lower risk, requires dispatcher to apply fixes)
   - (b) Direct Edit (faster, lower latency, but diverges from triage precedent)
   - (c) Defer decision to Phase 0 validation results
   Reviewer recommendation: (a), for consistency. But this is a project-direction choice.

2. **Scope coupling**: The proposal couples the archive convention with CLI automation.
   Should these be separable?
   - (a) Keep coupled (single coherent proposal, but blocked on CLI RFP)
   - (b) Separate (convention is adoptable now, CLI is future work)
   Reviewer recommendation: (b). But the user may prefer the holistic approach.
```

Concrete examples are more effective than abstract instructions for guiding agent behavior.

### Recommendation 6: Distinguish "reviewer findings" from "user questions" in action items

Currently, all review findings go into Action Items as directives.
Split into two categories:

- **Action Items**: things the author/implementer should fix (formatting, consistency, missing sections).
  These do not require user input.
- **Questions for the User**: things that require a human decision.
  These should be presented as choices, not directives.

This structural separation makes it explicit which items can be resolved autonomously and which cannot.

## Synthesis

The central concern is that the cdocs agent pipeline operates as a closed loop of autonomous agents: one agent writes, another reviews, the first revises, and the cycle repeats until convergence.
The user is absent from this loop except as the initial requestor and the final consumer.

This is efficient when the user's intent is clear and the design space has one obvious path.
It breaks down when:
- Multiple valid approaches exist and the "right" one depends on user preferences, priorities, or context that agents do not have.
- Cross-cutting architectural decisions affect the project's direction in ways the user should control.
- Risk tolerance varies by stakeholder and cannot be determined by technical analysis alone.

The review skill's original design included question surfacing as a mechanism to bring the user back into the loop at these decision points.
That mechanism has never been exercised.
The recommendations above aim to make question surfacing structural (template sections, workflow actions) rather than incidental (a single IMPORTANT callout), so that agents are guided toward escalation as naturally as they are currently guided toward autonomous verdicts.

The goal is not to make agents less autonomous.
It is to make agents deliberately autonomous: agents that know when they are making a judgment call, flag it as such, and give the user the opportunity to override it before work proceeds.
