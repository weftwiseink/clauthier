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
- `chat_record:` (optional): repo-root paths of the chat records of the sessions that worked on this devlog, one appended per session as [`orchestration-discipline.md`](../../rules/orchestration-discipline.md) "Chat record" describes.

Quote a chat record only inside a code fence: its column-0 `@` header and `--` sign-off lines are not cdocs markdown.

## Sections

All devlogs should include an Objective, Plan, and Verification section.
Most devlogs should include the other sections as well, but use your judgement (a quick config change doesn't need a debugging process section).
You should also include novel sections as is appropriate/useful for your work.

- **Objective:** What needs to be accomplished and why.
- **Scratchpoint:** Short current state (`as_of`, `now`, `next`, `open`, `files`), replaced in place between handoffs by whoever is writing the devlog, one live per writer per workstream (see [`orchestration-discipline.md`](../../rules/orchestration-discipline.md) "Durable state").
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

## Continuing in a new devlog

Devlogs grow forward: at a seam, start a new devlog instead of moving written text.

- **When.** Look at each return or handoff: a new concern big enough to stand alone (a phase, a fix round, a verification campaign), or a devlog past ~1,500 words (`wc -w`) reaching a natural seam.
  Size prompts the look, and the content chooses the cut.
  A restart, rotation, new turn, or full context is not a seam: continue the open concern's devlog from its Scratchpoint and latest handoff, replacing the Scratchpoint.
- **Who.** Whoever is writing at the seam closes the devlog it leaves (handoff, `status: done`, `next:` naming the successor) and starts the next.
  A dispatched agent writes the sub-devlog its lead names and reports any successor it starts.
  When the next concern goes to another writer, the leaving writer marks the finished devlog `done`, else the lead does.
- **Top-level.** The lead's devlog (no `part_of`) holds the Brief, the lead's Scratchpoint, the loop tables, handoffs, and an index the lead keeps:

  ```markdown
  ## Workstream Devlogs

  | devlog | concern | status | read this when |
  |---|---|---|---|
  | [-canary](2026-09-22-x-iterate-canary.md) | hook canary | done | you need a hook's payload fields |
  ```
- **Sub-devlogs.** `cdocs/devlogs/YYYY-MM-DD-<top-level-slug>-<concern>.md` (the top-level's date), with `part_of: <top-level path>` (one level deep) and a first line under the title, `> NOTE(author/workstream): Sub-devlog of [<top-level>](<top-level>.md); see its Workstream Devlogs table for siblings.`
  Each is a normal devlog with its own Scratchpoint, and short concerns share one.
- **Tables.** Loop tables stay in the top-level, and their rows do not count toward its size.
  Continuing them forward is a judgment call at a loop or phase boundary: the continuation holds only the tables (no Scratchpoint), and a line under each top-level table points to it.
  Iteration numbers keep increasing across the workstream.

## Handoff devlogs

Some work prepped from the initial planner or an earlier implementer with context and references to earlier docs.
When these are written and read, it should be kept in mind that they should _not_ try to cover every point themselves, but _should_ provide enough context and references to do so as needed.
