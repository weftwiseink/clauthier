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

## End-of-Turn Triage

After completing substantive work on cdocs documents, invoke `/cdocs:triage` to maintain frontmatter accuracy and trigger workflow continuations.

**Invoke when:**
- A new cdocs document was created (devlog, proposal, review, report)
- Significant edits were made to an existing cdocs document
- A revision cycle was completed

**Don't invoke when:**
- Only trivial edits were made (typos, formatting)
- Still mid-authoring (document not yet complete for this turn)
- No cdocs files were touched

**How it works:**
1. The top-level agent spawns a haiku Task subagent with the list of modified cdocs file paths.
2. The haiku agent reads each file (read-only) and returns recommendations for frontmatter fixes (tags, timestamps, missing fields), status transitions, and workflow actions.
3. The top-level agent reviews the triage report, applies recommended edits, and dispatches workflow actions:
   - `[REVIEW]`: spawn an opus/sonnet review subagent.
   - `[REVISE]`: revise inline per review action items.
   - `[ESCALATE]`: present options to the user (round >= 3 without acceptance).
   - `[STATUS]`: apply frontmatter status update.
   - `[NONE]`: no action needed.

**Design rationale:** Haiku is used for triage because the work is mechanical (frontmatter checks, pattern matching). Reviews use opus/sonnet because they require critical analysis. Revisions stay with the top-level agent because it has authoring context. See `/cdocs:triage` skill for full details.

## Completeness and Clarity Checklist

Before completing any task, review:

1. Check relevant checklists for the type of work completed.
   - **Proposals**: See the propose skill for the author checklist.
   - **Devlogs**: Ensure devlog contains sufficient context for work resumption.
   - **Documentation**: Final pass for NOTE(), TODO(), WARN() callouts.
2. Verify adherence to communication guidelines (BLUF, brevity, critical analysis).
3. Ensure no important context is lost (findings, decisions, complications).
4. Verify that all deviations and complications are surfaced front and center.

It is far worse to gloss over a problem and present it as a success than to acknowledge an issue.
