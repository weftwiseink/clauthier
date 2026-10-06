# CDocs Workflow Patterns

## Parallel investigation

When several failures look independent (different subsystems, no shared state, no shared files), investigate them with parallel agents; when they may share a root cause, debug one first.
Synthesize the agents' findings into the devlog.

## Loops and multi-phase plans

For work whose verification depends on real-world state (UI, integration, end-to-end behavior), run `/cdocs:iterate`.
For a plan with several independent, well-specified phases, dispatch per phase and keep each workstream's context in one named subagent (see `orchestration-discipline.md`).

## Before review

Pipeline: author, then `/cdocs:nit_fix` (mechanical convention fixes, so the reviewer focuses on substance), then `/cdocs:triage`, then review.
After substantive cdocs edits (a new document, a significant edit, a finished revision cycle), run `/cdocs:triage` to fix frontmatter and act on its workflow recommendations; skip it for trivial edits or mid-authoring.

## Completeness

Before completing a task, run the relevant checklist (the `/cdocs:propose` author checklist; a devlog a cold reader could resume from), check BLUF, brevity, and critical analysis, and surface every deviation and complication up front.
It is far worse to gloss over a problem and present it as a success than to acknowledge an issue.
