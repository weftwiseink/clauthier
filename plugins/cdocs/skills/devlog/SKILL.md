---
name: devlog
description: Create and scaffold a development log for the current work session
argument-hint: "[feature-name]"
---

# CDocs Devlog

Create a development log for the current work session.

**Usage:** Claude should auto-invoke this skill when starting substantive work (triggered by the "always create a devlog" writing convention).
The user can also invoke it directly.
Model auto-invocation is the most common entry point.

## Invocation

1. If `$ARGUMENTS` provides a feature name, use it. Otherwise, infer from context or prompt the user.
2. Determine today's date.
3. Create `cdocs/devlogs/YYYY-MM-DD-feature-name.md` using the template below.
4. If `cdocs/devlogs/` doesn't exist, suggest running `/cdocs:init` first.

## Template

Use the template in `template.md` alongside this skill file.
Fill in:
- `first_authored.by` with the current model name (e.g., `@claude-opus-4-5-20251101`) or `@username` for human authors.
- `first_authored.at` with the current timestamp including timezone.
- `task_list` with the relevant workstream path.
- `type: devlog`, `state: live`, `status: wip`.
- Tags relevant to the work.
- `chat_record:` (optional): repo-root paths of the chat records of the sessions that worked on this devlog, one appended per session as [`orchestration-discipline.md`](../../rules/orchestration-discipline.md) "Chat record" describes; an agent writing into another agent's devlog leaves it alone.

Quote a chat record only inside a code fence: its column-0 `@` header and `--` sign-off lines are not cdocs markdown.

## Sections

All devlogs should include an Objective, Plan, and Verification section.
Most devlogs should include the other sections as well, but use your judgement (a quick config change doesn't need a debugging process section).
You should also include novel sections as is appropriate/useful for your work.

- **Objective:** What needs to be accomplished and why.
- **Scratchpoint:** Short current state (`as_of`, `now`, `next`, `open`, `files`), replaced in place by the devlog's owner between handoffs; see [`orchestration-discipline.md`](../../rules/orchestration-discipline.md) "Durable state".
  An agent writing into another agent's devlog keeps none.
- **Plan:** Step-by-step approach.
- **Testing Approach:** TDD? Integration tests? Manual verification? State it upfront.
  - Skipping test-first for prototyping? Acknowledge it: "Rapid prototyping without test-first, will add coverage after."
  > NOTE: _Strongly_ lean away from skipping testing or relying on manual testing.
- **Implementation Notes:** Technical decisions (why, brief summaries of what) and issues solved.
- **Debugging Process:** Systematic debugging using the 4-phase approach below.
- **Changes Made:** Table of files modified/created with brief descriptions.
- **Testing:** Build verification and test results.
- **Screenshots:** Visual changes with captions. Save to `cdocs/_media/YYYY-MM-DD-description.png`.
- **Documentation Updated:** Checklist of docs changed.
- **Verification:** Fresh evidence of completion. No completion claims without pasted evidence.
  This is the home for raw evidence (settings, commands, log lines), not the Scratchpoint.

## Debugging Process (Bug Fixes)

When fixing bugs, document systematic debugging phases:

**Phase 1 - Root Cause Investigation:**
- Evidence gathered at each component boundary.
- Race condition timing captured.

**Phase 2 - Pattern Analysis:**
- What works vs. what's broken.
- Similar working examples compared.

**Phase 3 - Hypothesis Tested:**
- One hypothesis at a time with instrumentation.
- Results of each test.

**Phase 4 - Fix Implemented:**
- Final fix with verification.
- If 3+ fixes failed: architectural questions raised.

## Verification Section

No completion claims without pasted evidence.

**Build & Lint:**
```
[Paste full build/lint output]
```

**Tests:**
```
[Paste test output with pass counts]
```

**Runtime Verification:**
- Screenshot or description of actual behavior.
- For UI changes: before/after screenshots.

Remember:
- A task is not complete until its been fully tested and the test output has been verified.
- Incomplete or deferred work, while best avoided, _must at least_ be surfaced at a high-level so it isn't buried or forgotten about. 

## Parallel Agent Documentation

When dispatching parallel agents for multi-failure debugging, document in "Issues Encountered and Solved":

```markdown
### Multi-subsystem failures after [CHANGE]
- N failures across M subsystems
- Dispatched N parallel agents to investigate independently
- Agent 1 (subsystem): [findings and fix]
- Agent 2 (subsystem): [findings and fix]
- All fixes integrated, full suite green
```

## Best Practices

- Start the devlog when beginning work. Update as you go, not at the end.
- Be concise but sufficiently detailed on decisions. Explain WHY, not just what.
- Note what didn't work and why.
- Make the devlog the single source of truth for the work session.
- Ensure the devlog contains enough context for another agent to resume the work.

## Splitting a devlog

A long devlog splits where its work has seams, so a reader opens one relevant chunk instead of the whole chronology.

- **Trigger.** At each handoff, past ~1,500 words (`wc -w`) or ~5 loop rounds, look for a closed concern; size prompts the look, never chooses the cut.
- **Closed concern.** A completed phase, finished sub-loop, resolved investigation, or landed verification campaign that has its own H2 or H3, has no open todo in the latest handoff (done, or moved into the root's handoff), and feeds no live table in the root.
- **Cut.** Move each closed concern into its own chunk with everything belonging to it: notes, debugging, its Changes Made and Verification rows, finished Iteration Log rows.
  Merge a concern under ~400 words into an adjacent chunk; split a single oversized concern at a natural round or phase boundary.
  Rows shared by two concerns, open concerns, and live tables stay in the root; a live table whose finished rows moved gets a line below it (not a row) pointing to their chunk, plus a one-line summary (such as the verdict sequence) when every row moved.
  No closed concern means no split: tighten prose instead.
- **Naming.** Flat siblings `cdocs/devlogs/YYYY-MM-DD-<root-slug>-<concern-slug>.md`, with the root's date and a concern-named slug (`-canary`, `-phase2-hooks`, `-iterate-r1-r5`).
- **Root as index.** The root keeps its frontmatter (including `chat_record:`), Objective, `## Scratchpoint`, current handoff, and live tables, and gains a `## Chunks` table:

  ```markdown
  ## Chunks

  | chunk | concern | status | read this when |
  |---|---|---|---|
  | [-canary](2026-09-22-x-canary.md) | Phase-0 hook canary | done | you need a hook's exact payload fields |
  ```
- **Chunks stand alone.** Frontmatter copied from the root, with `status: done`, `part_of: cdocs/devlogs/<root>.md`, and no `chat_record:`; a backlink as the first line under the title, `> NOTE(author/workstream): Chunk of [<root>](<root>.md); see its Chunks table for siblings.`; then a standalone BLUF.
  Reword relative phrases ("this devlog", "the table above") in moved text.

## Handoff devlogs

Some work prepped from the initial planner or an earlier implementer with context and references to earlier docs.
When these are written and read, it should be kept in mind that they should _not_ try to cover every point themselves, but _should_ provide enough context and references to do so as needed.
