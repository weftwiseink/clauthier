---
name: full-send
description: >
  Have the given or described proposal written or fleshed out using /propose-revise, then have it /iterate'd to completion.
argument-hint: "[topic | path] [-m | --model \"<model_description\"] [-f | --first-round [\"<model_description>\"]]"
---

# CDocs Full Send

Full Sending means to take up a described topic, proposal rfp, or full proposal,
oversee a `/cdocs:propose-revise` loop on it, then oversee a `/cdocs:iterate` loop.

Both composed loop skills run in *overseer mode*, defined canonically in [`orchestration-discipline.md`](../../rules/orchestration-discipline.md); this skill references it rather than restating it.
Inline floor: honor each composed loop's own dispatch-by-default carve-out; write durable state at task-unit boundaries; use fresh reviewers and a fresh judge.
The overseer keeps the `## Scratchpoint` of each devlog it owns current per `orchestration-discipline.md` "Durable state".
On resume, follow `orchestration-discipline.md` "Resume from disk, not memory" before acting on either composed loop.

The first loop should be entered with a `/propose` if it's an RFP, but review-first if already authored.
If `--first-round` is specified in the latter case, the expensive expert model should also be used for the first revision.

## Invocation

Same as `/cdocs:propose-revise`. If `-f | --first-round` is specified, it should be passed to both loops.