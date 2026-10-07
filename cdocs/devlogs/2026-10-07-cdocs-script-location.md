---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T12:00:00-07:00
task_list: cdocs/script-location
type: devlog
state: live
status: wip
tags: [plugin-architecture, graphify, full_send]
---

# CDocs Script Location (full-send)

> BLUF: Full-send overseer devlog for deciding where `graphify-scope.sh` lives (`plugins/cdocs/scripts/` vs `plugins/cdocs/bin/`) and implementing the decision.

## Objective

`plugins/cdocs/scripts/graphify-scope.sh` sits apart from `plugins/cdocs/bin/` (`chat-record`, `bin/README.md`).
Decide whether to consolidate into one folder, implement the move and reference updates, and document graphify-scope in the resolved folder's README in the style of the chat-record section.
Proposal: `cdocs/proposals/2026-10-07-cdocs-script-location.md`.

## Plan

1. `/cdocs:propose-revise`: dispatch a `cdocs:proposer`, then fresh `cdocs:reviewer`s until `proposal_accepted`.
2. `/cdocs:iterate`: dispatch a `cdocs:implementer` (sub-devlog with `part_of` this devlog), then fresh reviewers until Accept.

Verification floor: `npm run build:cdocs` succeeds, `plugins/cdocs/hooks/tests/chat-record.test.sh --unit` and `validate-cdocs-edit-path.test.sh` pass, any graphify-scope tests pass, and a repo grep for the old path returns only historical cdocs records; failure looks like a skill, test, build script, or OpenCode output still pointing at the old path.

## Defaults Chosen (no AskUserQuestion available)

Nested overseer dispatched by the maintainer's top-level session, without `AskUserQuestion`: each place the skills say to ask the user is decided here and listed below.

- Chat record: not run (nested overseer is a subagent; `overseers.md` reserves `chat-record` for top-level agents, and this checkout has no `cdocs/_chat/`).

## Scratchpoint

- as_of: 2026-10-07 Turn 0
- next_steps: dispatch proposer
- important_files: plugins/cdocs/scripts/graphify-scope.sh, plugins/cdocs/bin/README.md, plugins/cdocs/skills/iterate/SKILL.md, scripts/build-opencode.ts
- callouts:
  - decision: concurrent agent `rules-fixup` edits punctuation in plugins/cdocs/rules/*.md and the devlog skill; do not touch those files' punctuation.

## Workstream Devlogs

| devlog | concern | status | read this when |
|---|---|---|---|

## Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | notes |
|---|---|---|---|---|---|---|

## Judge Log

| judge_iteration | trigger | verdict | rationale |
|---|---|---|---|

## Dispatch/Return Events

| event | agent_handle | target_files | at | notes |
|---|---|---|---|---|
| dispatch | proposer-1 (cdocs:proposer, a84ad7a7) | cdocs/proposals/2026-10-07-cdocs-script-location.md | 2026-10-07T12:05 | propose round 1 |

## Steering Log

## Verification
