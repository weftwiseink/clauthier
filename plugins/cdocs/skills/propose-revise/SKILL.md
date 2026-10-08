---
name: propose-revise
description: >
  Have the proposal written using the /propose skill, then have a /review / revise loop run as the overseer.
argument-hint: "[topic | path] [-m | --model \"<model_description>\"] [-f | --first-round [\"<model_description>\"]]"
---

# CDocs Propose/Revise Loop

Have a proposal written by a subagent using `/cdocs:propose`,
then run an iterative propose-review loop on that proposal until the reviewer accepts it.
Any minor issues or nits that come along with the accepting round should still be resolved.

The invoking session agent enters *overseer mode*, restricting itself to orchestration:
it dispatches subagents in alternation, terminates on accept-or-escalate, and should AskUserQuestion if the proposal hasn't been accepted after 6 rounds.
Before dispatching, invoke `/cdocs:oversee-workstream` (skip if its text is already in context).

The overseer dispatches subagents for all tasks aside from top-level devlog edits.

Propose-revise loop state should be tracked in the workstream's top-level devlog by the overseer; proposers, revisers, and reviewers write no devlog.
Add its log sections from [`../iterate/template.md`](../iterate/template.md); a later `/cdocs:iterate` on the proposal continues the same devlog.
When logging a review round to the devlog's Iteration Log, an accepted round is `review_verdict: proposal_accepted` for specificity.

The overseer should feel empowered to AskUserQuestion for feedback and guidance unless otherwise strongly stated.
The human user is the supervisor: they invoke the skill and receive escalations; the agent runs the loop.

ON "REVISION:"
The Overseer is responsible for deciding whether a request for revisions should be done by the previous `/propose` subagent or a fresh one,
except when `--first-round` was specified and has been completed.
Generally, we only need a fresh author to take a look if the requested revisions are extreme and the prior one's context is at 50%.

Unless stated explicitly by the user, cdocs docs should be committed early and often in a targeted way, even on main.

## Invocation

```
/cdocs:propose-revise <proposal_path> [--verification-floor "<sentence>"] [-f | --first-round ["<model_description>"]]
```

- `topic | path` is required: Passed through to first `/cdocs:propose` invocation (resulting path is used thereafter)
- `-m | --model "<model_description>"`: Which model & config to have the proposal and review rounds done with.
  Defaults to preferred model in CLAUDE.md or elsewhere, or the current session's config if none is specified.
- `-f | --first-round ["<model_description>"]`: Use a different model config for the first round proposal and review.
  If this flag is passed without a value, any preferred expert expensive model in CLAUDE.md or elsewhere is used.
  If no such preference exists, the overseer selects an appropriate larger model+config, like fable to lead an opus loop (a common pattern).
  For default tiers, see "CDocs Workflow Patterns › Model Tiering".

## Roles

- **Overseer**: top-level agent, restricted to orchestration; owns dispatch, freshness, termination.
- **Proposer**: fresh initial `cdocs:proposer` subagent dispatched with `/cdocs:propose`; executes the proposal and self-verifies before reporting done.
- **Reviewer**: fresh `cdocs:reviewer` subagent each iteration; reads the proposal's output with fresh context and produces a review document with a verdict.
- **Reviser**: `cdocs:proposer` subagent dispatched with `/cdocs:propose` to make requested revisions. Reuses the `cdocs:proposer` type (same skill, same tools, same proposal-authoring activity as the initial proposer); whether it is fresh or the prior warm proposer is the overseer's per-dispatch context-freshness call (see "ON REVISION"), orthogonal to the agent type.