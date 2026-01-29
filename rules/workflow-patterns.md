# CDocs Workflow Patterns

General workflow patterns for development sessions.
These apply to all substantive work, not just specific doc types.

## Dispatching Parallel Agents (Tactical Use)

When 3+ independent failures occur, investigate in parallel instead of sequentially.

**Use when:**
- 3+ test failures across different files/subsystems
- Each failure's domain is clearly identifiable (e.g., editor sync, authorship tracking, UI components)
- Failures appear independent (different root causes)
- No shared state between investigations

**Don't use when:**
- Single failure or 2 related failures
- Root cause unclear (need exploratory debugging first)
- Failures likely share underlying cause
- Agents would edit same files (conflict risk)

**Document in devlog:** Synthesize parallel agent findings into coherent narrative in "Issues Encountered and Solved" section.

## Subagent-Driven Development (Complex Multi-Task Plans)

Use for structured execution of complex implementation plans with 5+ tasks.

**Use when:**
- Proposal has 5+ implementation phases
- Tasks are largely independent
- Each task has clear success criteria
- Implementation is well-understood upfront

**Don't use when:**
- Exploratory implementation (learning as you go)
- Tightly coupled tasks requiring cross-task context
- Simple 1-3 task changes
- Heavy UI/collaboration work requiring manual verification

**Critical requirements:**
- Maintain devlog as single source of truth (synthesize subagent findings)
- Always perform final manual verification via dev server
- Document high-level technical decisions in devlog
- Capture emergent issues that required deviation from plan

## Completeness and Clarity Checklist

Before completing any task, review:

1. Check relevant checklists for the type of work completed.
   - **Proposals**: See the proposal skill for the author checklist.
   - **Devlogs**: Ensure devlog contains sufficient context for work resumption.
   - **Documentation**: Final pass for NOTE(), TODO(), WARN() callouts.
2. Verify adherence to communication guidelines (BLUF, brevity, critical analysis).
3. Ensure no important context is lost (findings, decisions, complications).
4. Verify that all deviations and complications are surfaced front and center.

It is far worse to gloss over a problem and present it as a success than to acknowledge an issue.
