---
name: propose-revise
description: >
  Have the proposal written using the /propose skill, then have a /review / revise loop run as the overseer.
argument-hint: "[topic | path] [-m | --model \"<model_description\"] [-f | --first-round [\"<model_description>\"]]"
---

# CDocs Propose/Revise Loop

Have a proposal written by a subagent using `/cdocs:propose`,
then run an iterative propose-review loop on that proposal until the reviewer accepts it.
Any minor issues or nits that come along with the accepting round should still be resolved.

The invoking session agent enters *overseer mode* and restricts itself to orchestration: it dispatches subagents in alternation,
terminates on accept-or-escalate, and should AskUserQuestion if the proposal hasn't been accepted after 6 rounds.

Overseers should aim to use subagents for all tasks, even trivial ones,
and should feel empowered to AskUserQuestion for feedback and guideance unless otherwise strongly stated.

The overseer is a behavioral mode the top-level session agent enters when invoking this skill.
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
- `-m | --model "<model_description"`: Which model & config to have the proposal and review rounds done with.
  Defaults to preferred model in CLAUDE.md or elsewhere, or the current session's config if none is specified.
- `-f | --first-round ["<model_description"]`: Use a different model config for the first round prroposal and review.
  If this flag is passed without a value, any preferred expert expensive model in CLAUDE.md or elsewhere is used.
  If no such preference exists, the overseer selects an appropriate larger model+config, like fable to lead an opus loop (a common pattern).

## Roles

- **Overseer**: top-level agent, restricted to orchestration; owns dispatch, freshness, termination.
- **Proposer**: fresh initial `general-purpose` subagent dispatched with `/cdocs:propose`; executes the proposal and self-verifies before reporting done.
- **Reviewer**: fresh `cdocs:reviewer` subagent each iteration; reads the proposal's output with fresh context and produces a review document with a verdict.
- **Reviser**: subagents dispatched with `/cdocs:propose` to make requested revisions. May be fresh