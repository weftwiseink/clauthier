---
name: full-send
description: >
  Have the given or described proposal written or fleshed out using /propose-revise, then have it /iterate'd to completion.
argument-hint: "[topic | path] [-m | --model \"<model_description\"] [-f | --first-round [\"<model_description>\"]]"
---

# CDocs Full Send

Full Sending means to take up a described topic, proposal rfp, or full proposal,
oversee a `/cdocs:propose-revise` loop on it, then oversee a `/cdocs:iterate` loop.

Both loop skills describes the *overseer mode*. 
The first loop should be entered with a `/propose` if it's an RFP, but review-first if already authored.
If `--first-round` is specified in the latter case, the expensive expert model should also be used for the first revision.

## Invocation

Same as `/cdocs:propose-revise`. If `-f | --first-round` is specified, it should be passed to both loops.