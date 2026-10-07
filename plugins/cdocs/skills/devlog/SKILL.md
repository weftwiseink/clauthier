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
- **Scratchpoint:** Short current state, updated at the end of each turn, including an optional handoff subsection
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

### The Scratchpoint Section
This both orients the next turn of work and communicates to other actors how the workstream is evolving.

The callouts list should include any important notes still relevant to this specific workstream, i.e. if a decision was made as a result of debugging, an env issue is preventing certain testing or tool use, or a bug/issue needs to be revisited after a subsequent stage.
Each item in the callouts list should be type-prefixed, and types are an open set (add more beyond deferred/todo/decision/blocker as needed).

The scratchpoint can include content for orienting the next turn beyond the structured schema, but should remain forward-looking (they are not append only logs.)

### Handoffs
Optional scratchpoint subsection with expanded context/files, with context and references to earlier docs, as well as ongoing or unresolved concerns.
They should include specifics (Completed / Decisions Made / Open Todos) a cold reader can act on.

Handoff subsections should be written when:
1. A major phase of a proposal is completed.
2. The implementer is exiting a turn with above 300K token context.

If a handoff section is present when picking up a workstream, delete it before beginning new work.

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

Larger workstreams often warrant chunked devlogs to manage context bloat, keep current work focused, and ease more fine-grained retrieval of detailed info in the future.
Consider creating a new devlog when a new large phase is begun or the current devlog is over 1500 words long and reaches a natural breakpoint.
Often a context handoff coincides with such points, but not always.

Top-level overseer devlogs should never be split.

## Devlog Heirarchies

Chunked devlogs are enabled by `part_of` references in frontmatter, with the main devlog maintained by an overseer agent.
The lead agent's devlog (no `part_of`) holds the Brief, the lead's Scratchpoint, the loop tables, handoffs, and an index the lead keeps:
```md
## Workstream Devlogs

| devlog | concern | status | read this when |
|---|---|---|---|
| [-canary](2026-09-22-x-iterate-canary.md) | hook canary | done | you need a hook's payload fields |
```

**Sub-devlogs** follow the convention `cdocs/devlogs/YYYY-MM-DD-<top-level-slug>-<concern-slug>.md` using the top-level's date, with `part_of: <top-level path>` in frontmatter.
Each is a normal devlog with its own Scratchpoint, and short concerns share one.