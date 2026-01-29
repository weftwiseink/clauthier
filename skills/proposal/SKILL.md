---
name: proposal
description: Author a design proposal with structured sections and implementation phases
argument-hint: "[topic]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# CDocs Proposal

Author a design proposal document.

This is a **deliverable skill** -- the user explicitly requests a proposal.
Proposals specify designs and solutions, outlining implementation phases.
They should retain a "timeless" quality: design changes are noted in NOTE callouts or by reference to another document, not by rewriting.

## Invocation

1. If `$ARGUMENTS` provides a topic, use it. Otherwise, prompt the user.
2. Determine today's date.
3. Create `cdocs/proposals/YYYY-MM-DD_topic.md` using the template below.
4. If `cdocs/proposals/` doesn't exist, suggest running `/cdocs:init` first.

## Template

Use the template in `template.md` alongside this skill file.
Fill in:
- `first_authored.by` with the current model name or `@username`.
- `first_authored.at` with the current timestamp including timezone.
- `task_list` with the relevant workstream path.
- `type: proposal`, `state: live`, `status: wip`.
- Tags relevant to the proposal.

## Sections

All proposals should always include a BLUF, and almost always an objective and background section.
Most proposals should include the other sections as well, but use your judgement (ie a high-level architecture proposal does not need unit test plans).
You may also include novel sections not specified - again, use your judgement and think critically to the best of your ability when crafting the proposal.

- **> BLUF:** Bottom line summary at top. Must clearly state the approach without surprises and line up with the final settled approach. Reference the most important sources.
- **Objective:** Problem or improvement goal.
- **Background:** Important docs, links, prior art. Context needed to understand the proposal.
- **Proposed Solution:** Architecture or approach. The core of the proposal.
- **Important Design Decisions:** Each decision with "Decision" and "Why" subsections. Explain rationale, not just the choice.
- **Stories:** User or logical scenarios to consider
- **Edge Cases:** What could go wrong, how to handle it.
- **Phases:** Detailed unless otherwise requested, should usually include testing plans, should never include time estimates. More guidance below

## Implementation Phase Guidance

**For standard iterative development:**
- Break into logical phases.
- Focus on high-level steps, not prescriptive details.
- Trust developer judgment on approach.
- Document constraints and "what NOT to change."

**For subagent-driven development (5+ task threshold):**
When the proposal has 5+ largely independent phases with clear success criteria:
- Each phase independently executable.
- Clear success criteria per phase (how to verify completion).
- Dependencies between phases noted explicitly.
- Constraints specified (what files/systems NOT to modify).
- Expected inputs/outputs documented.

## Drafting Approach

1. Start with the BLUF. Write it first, even if rough.
2. Fill in Objective and Background for context.
3. Explore and consider possible approaches if applicable.
4. For decision proposals, stay at a medium level of depth, analyze options, and recommend a decision/approach.
5. For implementation proposals:
   - Break the solution into phases.
   - Write test plan and acceptance criteria for each phase.
   - Consider edge cases and refine the above based on them.
6. Reviewing the author checklist
7. Revisit and refine the BLUF and frontmatter based on completed draft.

## Author Checklist

Before marking status as `review_ready`:
- [ ] BLUF clearly states the approach without surprises, and lines up with the final settled approach.
- [ ] All relevant documentation and sources listed, most important emphasized in the BLUF.
- [ ] Technical decisions explain "why" not just "what."
- [ ] Follow writing conventions: critical/detached analysis, brevity, commentary decoupled from technical content.
- [ ] NOTE/TODO/WARN callouts added where future readers need context.
- [ ] With fresh eyes, review:
  - [ ] whether someone unfamiliar with the context could follow the proposal.
  - [ ] whether there is anything inconsitent or missing from the initial draft.

> NOTE: "Review" here is not a full-fledged review doc or worthy of frontmatter, but rather a professional courtesy to make the review process easier.

## Revisions

When revising a proposal:
- Per our writing convention, proposals should retain History-Agnostic Framing, with past states only mentioned in `> NOTE` callouts if at all.
- Proposals with `status: evolved` have been superseded by a follow-up proposal.
  This approach should be preferred when a proposal is already being worked on.
- An ammended proposal MUST be returned to `status: review_ready`.
