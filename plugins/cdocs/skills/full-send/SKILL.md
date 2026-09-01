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
Inline floor: honor each composed loop's own dispatch-by-default carve-out; write durable state before compacting; use fresh reviewers and a fresh judge.
On resume, reconstruct child-dispatch liveness from the Iteration Log's dispatch/return event rows before acting on either composed loop: if you believe a child is in flight but the harness has returned control (no live children remain), that child has terminated, so inspect its on-disk artifacts and proceed from the actual state rather than waiting (see `orchestration-discipline.md` Pillar 1b).

The first loop should be entered with a `/propose` if it's an RFP, but review-first if already authored.
If `--first-round` is specified in the latter case, the expensive expert model should also be used for the first revision.

## Invocation

Same as `/cdocs:propose-revise`. If `-f | --first-round` is specified, it should be passed to both loops.