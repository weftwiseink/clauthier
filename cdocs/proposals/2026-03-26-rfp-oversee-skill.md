---
first_authored:
  by: "@claude-opus-4-6-20250725"
  at: 2026-03-26T16:00:00-07:00
task_list: cdocs/oversee-skill
type: proposal
state: live
status: request_for_proposal
tags: [architecture, claude_skills, workflow, agent_orchestration]
---

# RFP: `/oversee` Skill and Autonomous Orchestration Rules

> BLUF(opus/cdocs/oversee-skill): Users repeatedly specify the same multi-phase orchestration pattern: "propose, review, revise, implement, verify against real state, continue through all phases autonomously."
> A dedicated `/oversee` skill and supporting rules would codify this pattern, ensuring agents drive work forward through validation loops and phase transitions without requiring manual nudges at each step.
>
> - **Motivated By:** Recurring friction in multi-proposal implementation sessions where agents stall between phases, skip real-world verification, or report completion without validating against live system state.

## Objective

Agents acting as orchestrators (overseers) frequently need to:
1. Dispatch subagents for proposals, reviews, and implementations.
2. Ensure each deliverable goes through review/revision cycles before proceeding.
3. Drive implementations through all phases sequentially, committing and verifying at each step.
4. Validate results against live system state (running containers, actual CLI output, real file contents), not just test suites.
5. Continue autonomously through multiple phases when the user has indicated they'll be AFK.

Currently, users must manually specify all of this in each prompt.
When they don't, common failure modes emerge:
- Agents report completion without verifying against real-world state (tests pass but the actual feature is broken).
- Agents stop between phases and wait for user input instead of continuing.
- Parallel agents modify the same files, creating conflicts.
- Verification loops are shallow (only `cargo test` / `pnpm test`, not "does the container actually start?").
- Troubleshooting agents enter expensive retry loops instead of isolating the problem first.

The `/oversee` skill and related rules would provide a structured protocol that agents follow by default, reducing the prompt engineering burden on users and improving autonomous reliability.

## Scope

### 1. `/oversee` Skill

A new skill that wraps the propose-review-implement lifecycle.
The proposer should explore:
- **Invocation patterns**: `/oversee implement cdocs/proposals/...` (single proposal), `/oversee chain [proposal1, proposal2, ...]` (sequenced proposals), `/oversee full <topic>` (propose + review + implement end-to-end).
- **Phase progression protocol**: How the overseer decides to advance from one phase to the next. What constitutes "verified" for each phase type (proposal, review, implementation).
- **Verification contracts**: Each phase declares what "verified" means. For proposals, it's review acceptance. For implementations, it's both test passage AND real-world validation (the skill should require specifying what "real-world" means for the given work).
- **AFK/autonomous mode**: A mechanism for the user to signal "continue through all phases without asking me." Could be a marker file (e.g., `.claude/oversee-continue`), an env var, a flag on invocation, or a session-level setting. The proposer should research what mechanisms are available and durable across agent boundaries.
- **Escalation protocol**: When should the overseer stop and ask the user? Failed verification after N retries, blocking review findings, resource contention, unexpected scope expansion.

### 2. Orchestration Rules

Rules that any agent (not just the overseer) can reference when managing subagent work.
The proposer should explore:

- **Verification depth ladder**: Define levels of verification (compile-check, unit-test, integration-test, smoke-test, live-validation) and when each is required. Implementation phases should specify their level.
- **Serialization vs parallelization heuristics**: When is it safe to run agents in parallel vs when must they be serialized? Key signal: do they touch overlapping files? The current "Dispatching Parallel Agents" pattern in workflow-patterns.md is a start but doesn't address the conflict detection problem.
- **Troubleshooting budgets**: When an agent is debugging, how many full-cycle iterations (e.g., container rebuilds) should it attempt before switching to a targeted isolation strategy? The rule should encourage "isolate first, full-cycle second."
- **Continuation markers**: How does an overseer or subagent know it should keep going vs stop and wait? This interacts with the AFK mode above but also applies to implementation agents that finish a phase: should they proceed to the next phase by default?
- **Commit discipline**: Require commits at phase boundaries. Define what a "phase boundary" is for different work types.

### 3. Shared State for Cross-Agent Coordination

When multiple agents work in the same repo, they need awareness of each other.
The proposer should explore:

- **Lock files or claim markers**: Could agents write a `.claude/agent-claims/<file_pattern>` marker to signal "I'm working on these files"? Other agents check before modifying.
- **Progress files**: A structured file (e.g., `.claude/oversee-state.json`) tracking which phases are complete, which agent owns what, and what verification has passed. This would let a continuation agent pick up where a crashed agent left off.
- **Devlog as coordination point**: The devlog is already the "single source of truth" for a work session. Could it serve double duty as the coordination mechanism?

## Open Questions

1. **Skill vs rule vs both?** Should `/oversee` be a skill that actively drives work, or a set of rules that any agent references? Or both: a skill that invokes the rules-aware pattern?

2. **Cross-session durability**: If the user starts an `/oversee` session and the conversation is interrupted (rate limit, API error, user closes terminal), how does the next conversation know to resume? The progress file approach addresses this, but the proposer should consider edge cases.

3. **Scope creep guard**: `/oversee` could become a "do everything" skill. How do we keep it focused on orchestration rather than reimplementing `/implement`, `/propose`, and `/review`? The answer is probably composition: `/oversee` invokes those skills rather than duplicating them.

4. **Agent model selection**: Should the overseer run on a specific model (opus for judgment, sonnet for speed)? Should it be configurable? The current workflow-patterns.md doesn't address this.

5. **Verification specification format**: How does a proposal or implementation phase declare its verification requirements in a way the overseer can parse and execute? Structured frontmatter? A `## Verification` section with executable commands? A separate manifest?

6. **Interaction with existing implement skill**: The current `/implement` skill already has phase execution, devlog tracking, and review loops. Is `/oversee` a wrapper around `/implement`, or does it replace it? The proposer should carefully analyze the boundary.
