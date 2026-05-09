---
first_authored:
  by: "@claude-opus-4-6-20250725"
  at: 2026-03-27T15:30:00-07:00
task_list: cdocs/oversee-skill
type: report
state: live
status: review_ready
tags: [oversee, prompt_engineering, agent_orchestration, verification]
---

# Overseer Prompt Engineering: Patterns and Lessons

> BLUF: Writing effective overseer prompts is an exercise in restraint: say what only the prompt can say, reference everything else.
> A first draft of an overseer prompt for the whelm MTG spike included 40+ lines of environment setup, execution rules, and gotchas that were already covered by project CLAUDE.md, cdocs rules, and the referenced proposals.
> After a revision pass guided by user feedback, the prompt shrank to ~20 lines and became more effective by focusing on intent, verification rigor, and references to authoritative documents.
> This report captures the specific patterns, the before/after, and the underlying principles for future `/oversee` skill design.

## Context

During the whelm MTG spike design session, a complete design phase produced:
- A research report, three implementation proposals, and an implementation roadmap
- Cross-coherence reviews resolving 10 blocking issues
- A handoff devlog for an overseer agent to begin implementation

The final task was writing the starter prompt that would kick off the overseer.
The first attempt was comprehensive but redundant; the revision was concise and effective.
This report documents what changed and why.

## The Conversation

### First Draft

The initial overseer prompt was ~50 lines covering nine areas: handoff reference, job description, proposal list, execution rules (8 numbered items), environment setup (7 bullets), reference data, key gotchas (6 bullets), and the wezterm validation workflow.

User feedback:

> Mmm - this is good, but should reference the cdocs slash commands explicitly and provide more guidance on how to oversee work and ensure it's verified. I'll paste an example from elsewhere although note this agent will be in a container and not have access to /var/mjr. Also, consider what is unnecessary here based on what rules and guidance are provided by default in our project docs and CLAUDE.md.
>
> Also what is the bit about wezterm? wezterm shouldn't factor in here, right?

The user provided this reference example from a different project:

> ```
> Please oversee the /implement'ation of @cdocs/proposals/2026-03-27-sprack-session-resolution-test-harness.md
> (oversee guidance is here:/var/home/mjr/code/weft/clauthier/main/cdocs/proposals/2026-03-26-rfp-oversee-skill.md).
> We want to obtain the ability for sprack implementation agents and overseers to reliably verify their
> outputs autonomously. Make sure and have the work /review'd and verify that it is complete.
>
> Once you feel that is complete, dogfood the work by having another subagent workflow /implement and verify
> @cdocs/proposals/2026-03-27-sprack-session-liveness-naming-state.md. These are perfect cases to dogfood on
> because while we made some progress last session, they were particularly hard for agents to properly inspect
> the state of. So, be extra, extra rigorous and critical in your acceptance criteria for this SoW. The harness
> is supposed to enable us to do highly accurate verification autonomously, so if you end your turn and come
> back thinking we've verified the results, and I open sprack and find the same issues, it will mean we've
> missed something very important in how the harness is supposed to improve things.
>
> Please take a moment to digest all that and prepare, then AskUserQuestion for anything you feel needs
> clarification. Once you begin overseeing the first implementation it is important that you continue
> autonomously through to the end of verifying the final proposal.
> ```

### What Changed

The revised prompt:

> ```
> Please oversee the /implement'ation of the MTG spike for whelm. The handoff devlog at
> cdocs/devlogs/2026-03-27-mtg-spike-implementation-handoff.md has the full context,
> including the original user brief and links to all design documents.
>
> The implementation roadmap at cdocs/proposals/2026-03-27-mtg-spike-implementation-roadmap.md
> sequences 13 phases across three proposals into 9 steps with verification gates,
> parallelization strategy, file ownership, and escalation triggers. Execute it as written.
>
> The three proposals to /implement are:
> - cdocs/proposals/2026-03-27-card-templating-system.md (4 phases)
> - cdocs/proposals/2026-03-27-card-explorer.md (4 phases)
> - cdocs/proposals/2026-03-27-gameplay-interface.md (5 phases)
>
> Create branch `feat/mtg-spike` from main before writing any code.
>
> Each step's work should be /review'd before moving on. The roadmap defines verification
> depth levels L1-L5: L4+ requires visual verification via Playwright MCP against the
> running dev server, not just passing tests. Be rigorous about this: the whole point of
> the verification framework is that agents actually look at what they built rather than
> trusting test output alone. If you finish a step and claim it's verified but the cards
> don't render, the borders are invisible, or the zones are misaligned, we've missed the
> point entirely.
>
> The roadmap has specific escalation triggers (ReactFlow reparenting, SCSS border-image,
> sample data balance, two-retry gate failures). Honor them: stop and ask rather than
> working around the problem.
>
> Please take a moment to read the handoff devlog and roadmap, then AskUserQuestion for
> anything you feel needs clarification. Once you begin implementation it is important that
> you continue autonomously through to completing and verifying all 9 steps.
> ```

## Key Findings

### 1. Don't Repeat What the Environment Already Provides

The first draft included:
- How to start the dev server (`.sculptor/background_devserver.sh`)
- The SCSS naming convention (plain `.scss`, not `.module.scss`)
- CI variable rules (`CI=true` for install, not for e2e)
- Playwright MCP configuration
- pnpm command names

All of this is in CLAUDE.md, which every agent reads automatically.
Repeating it in the prompt wastes tokens, creates drift risk if CLAUDE.md changes, and dilutes the signal-to-noise ratio.

**Principle:** The prompt should contain only information that cannot be derived from the project's existing documentation.

### 2. Don't Repeat What the Referenced Documents Cover

The first draft included:
- The 9-step implementation sequence (summarized from the roadmap)
- File ownership boundaries (from the roadmap)
- Commit message format (from the roadmap)
- Verification depth descriptions (from the roadmap)

The roadmap is the authoritative source for all of this.
Summarizing it in the prompt means the agent reads it twice (once in the prompt, once in the document) and must reconcile any differences.

**Principle:** Reference the document, state what it is, say "execute it as written."

### 3. Reference cdocs Skills Explicitly

The first draft said "each step must pass its verification gate before committing."
The revised version says "each step's work should be `/review`'d before moving on."

The difference: the first is a vague instruction; the second invokes a specific cdocs skill that the agent knows how to dispatch.
Similarly, `/implement`'ation (with the apostrophe) signals that the agent should use the `/cdocs:implement` skill, not ad-hoc execution.

**Principle:** Name the skills. The cdocs workflow (implement, review, triage, nit-fix) exists to codify these patterns. Telling the agent to use them is more precise than describing what they do.

### 4. Express Verification Rigor as Consequences, Not Rules

The first draft listed rules: "L4+ gates require dev-server visual checks. Do not skip visual verification."

The revised version frames it as stakes:

> If you finish a step and claim it's verified but the cards don't render, the borders are invisible, or the zones are misaligned, we've missed the point entirely.

This is more effective because it gives the agent a mental model of what failure looks like, not just a checklist item to tick.
The reference example does the same thing: "if I open sprack and find the same issues, it will mean we've missed something very important."

**Principle:** Paint the picture of what "not good enough" looks like. Rules get followed mechanically; consequences get internalized.

### 5. Remove Context Bleed from Unrelated Systems

The first draft included a bullet about wezterm's `act.Multiple` validation timing.
This was context from the parent chezmoi repo's CLAUDE.md, which has extensive wezterm configuration guidance.
It has zero relevance to the MTG spike implementation.

**Principle:** Before finalizing a prompt, audit every line for relevance. Context bleed from parent/sibling configurations is easy to miss and confusing to the recipient.

### 6. Ask the Agent to Prepare Before Starting

Both the reference example and the revised prompt end with:

> Please take a moment to read [references], then AskUserQuestion for anything you feel needs clarification. Once you begin [work] it is important that you continue autonomously through to the end.

This pattern serves two purposes:
- It forces the agent to load all context before making decisions, reducing mid-flight misunderstandings.
- It sets the expectation of autonomous continuation: once started, don't stop between phases to ask for permission.

**Principle:** Separate preparation from execution. Let the agent ask questions before committing to an autonomous run.

### 7. Handoff Devlogs Are the Bridge

The handoff devlog is the connecting document between the design session and the implementation session.
It exists because the overseer agent starts a fresh conversation with no prior context.

A good handoff devlog:
- Contains the original user brief (verbatim) so the overseer understands intent, not just spec
- Links to all design documents with one-line descriptions
- States what has been done and what hasn't
- Notes cross-coherence issues already resolved (so the overseer doesn't re-discover them)
- Does NOT repeat proposal content: it points to proposals

The prompt then references the handoff devlog rather than restating its contents.

## Recommendations

### For `/oversee` Skill Design

1. **Prompt template**: The skill should generate prompts following the pattern above: handoff reference, document list with skill verbs (`/implement`, `/review`), verification stakes framed as consequences, escalation triggers, and the prepare-then-execute ending.

2. **Environment deduplication**: The skill should explicitly NOT include environment setup (CLAUDE.md), cdocs conventions (rules/), or proposal internals (the proposals themselves) in generated prompts.

3. **Verification emphasis**: The oversee RFP identifies "agents report completion without verifying against real-world state" as a top failure mode. The prompt pattern of framing stakes as consequences (not rules) is the most effective mitigation observed so far.

4. **Handoff devlog generation**: The skill should either generate or require a handoff devlog as part of its setup phase. The devlog anchors the overseer's context without bloating the prompt.

### For Prompt Authors

- Start with the reference example's structure: intent, documents, skills, stakes, autonomy expectation.
- Delete anything that appears in CLAUDE.md or project rules.
- Delete anything that appears in the referenced documents.
- What remains should be: the specific task, the specific verification expectations, and the specific failure modes you're worried about.
- Read the prompt as if you have no prior context. Does it tell you where to find everything? Does it tell you what "done" looks like? Does it tell you when to stop and ask?
