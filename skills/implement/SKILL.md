---
name: implement
description: Implement an accepted proposal with structured execution, devlog tracking, and frequent commits
argument-hint: "[proposal_path]"
---

# CDocs Implement

Implement an accepted proposal.

**Usage:** User-invoked when a proposal has been reviewed and accepted (`status: implementation_ready`).
Claude may also suggest implementation when it encounters an `implementation_ready` proposal.

## Invocation

### With a proposal path
```
/cdoc:implement cdocs/proposals/2026-01-29_topic.md
```
Directly begin implementing the specified proposal.

### Without arguments
```
/cdoc:implement
```
Scan `cdocs/proposals/` for documents with `status: implementation_ready`.
Present the list to the user and ask which proposal to implement.
If no proposals are `implementation_ready`, report that and suggest checking `/cdoc:status --type=proposal`.

## Behavior

1. **Select proposal**: resolve from `$ARGUMENTS` or scan and present `implementation_ready` proposals.
2. **Read the proposal fully**: understand the objective, design decisions, implementation phases, and test plan.
3. **Create a devlog**: invoke `/cdoc:devlog` (or scaffold manually) for the implementation session.
   - Set `task_list` to match the proposal's `task_list`.
   - Reference the proposal path in the devlog's Objective section.
4. **Create a task list**: break the proposal's implementation phases into trackable tasks.
5. **Execute implementation phases** following the proposal's plan:
   - Work through phases sequentially (or in parallel per `rules/workflow_patterns.md` when applicable).
   - Commit frequently using conventional commit format.
   - Update the devlog as work proceeds (decisions, complications, deviations from the plan).
6. **On completion**: update the devlog with verification results, mark it `status: review_ready`.

## Implementation Conventions

The implementor should follow these conventions throughout:

### Commit frequently
- Use conventional commit format (`feat:`, `fix:`, `refactor:`, `docs:`, etc.).
- Commit after each logical unit of work, not just at the end.
- Commits should be small and focused: one concern per commit.

### Maintain the devlog
- The devlog is the single source of truth for the implementation session.
- Update it as you go, not retroactively.
- Document: what was done, why decisions were made, what deviated from the plan, what didn't work.

### Use cdoc skills as appropriate
- `/cdoc:review` when implementation is complete and ready for evaluation.
- `/cdoc:report` if the implementation reveals findings worth documenting separately.
- `/cdoc:status` to update proposal status as work progresses.

### Note deviations from the proposal
- If the implementation diverges from the proposal's design, document why in the devlog.
- Use `NOTE(author/workstream):` callouts in the devlog for deviations.
- Do not silently change the approach: surface deviations front and center.

## Status Transitions

The implement skill drives these proposal status transitions:

```
implementation_ready -> (implementation in progress, devlog tracks work)
                     -> implementation_accepted (after implementation review accepted)
                     -> evolved (if implementation reveals need for new/revised proposal)
```

After implementation is complete and the devlog is reviewed:
- If the implementation review is accepted, update the proposal to `status: implementation_accepted`.
- If the implementation reveals the design needs rethinking, update the proposal to `status: evolved` and create a follow-up proposal.
