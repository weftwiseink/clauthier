---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-09T02:40:00-07:00
task_list: cdocs/remove-graphify
type: devlog
state: live
status: wip
tags: [graphify, cleanup]
chat_record:
  - cdocs/_chat/2026-10-07-63ac45de-462d-4f43-ae1c-4ab6d59049b8.md
---

# Remove Graphify: Devlog

> BLUF: Top-level `/cdocs:full-send` removing graphify from cdocs (skill, wrapper, `graphify_base_query`, rules, CI, devcontainer) and from weftwise, plus a `/cdocs:rfp` in lace for deleting its graphify devcontainer feature.
> The assessment (`cdocs/devlogs/2026-10-08-graphify-weftwise-assessment.md`) found no value worth the maintenance and dependency overhead.

## Objective

Fully remove graphify.
Context-load reduction moves to better factoring and code cleanliness later; not in scope.

## Scratchpoint

- next_steps: proposal review round 1 (rev-1). Lace RFP done (`61a65162`, unpushed).
- graphify_base_query:
- important_files: `plugins/cdocs/skills/graphify/`, `plugins/cdocs/bin/cdocs-graphify`, `plugins/cdocs/rules/tool-use-safeguards.md`, `plugins/cdocs/skills/iterate/`, `.devcontainer/devcontainer.json`, `.graphifyignore`, `.github/workflows/cdocs-hooks.yml`, weftwise `.devcontainer/`, weftwise `.graphifyignore`, lace `devcontainers/features/src/graphify/`
- callouts:
  - decision (overseer call): no container rebuilds in this workstream; config changes only, rebuild at the maintainer's convenience.
  - decision (overseer call): plugin stays 0.2.0 (untagged, unpushed), so the removal ships in the same release.
  - decision (overseer call): weftwise `2026-09-15-code-graph-review-plugin-rfp.md` archived, the other two code-graph RFPs deferred, each with a NOTE pointing at the clauthier assessment.
  - todo: maintainer-owned weftwise worktrees (`bocsync-bailout`, `df-to-mount`, `dogfood-sept`, `logical-core`, `loro-branching`, `loro-repo-package`) and `loro/` are never touched.

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
| dispatch | prop-1 (cdocs:proposer, opus) | `cdocs/proposals/2026-10-08-remove-graphify.md` | 2026-10-09T02:42 | removal proposal: clauthier + weftwise |
| dispatch | rfp-lace (general-purpose, sonnet) | lace `cdocs/proposals/2026-10-08-delete-graphify-feature-rfp.md` | 2026-10-09T02:42 | `/cdocs:rfp` deleting lace's graphify feature |
| return | rfp-lace | lace `61a65162` (unpushed) | 2026-10-09T02:50 | lace `cdocs/proposals/2026-10-08-delete-graphify-feature-rfp.md`: delete `devcontainers/features/src/graphify/`, its tests, lace's own devcontainer use; update 2 doc cross-refs; archive the six 2026-09-15 graphify records. Open questions: registry deprecation vs source deletion, other consumers, reuse of the host-cache-mount convention |
| return | prop-1 | `2470c67`, `761a407` | 2026-10-09T02:55 | `review_ready`: 3 phases (clauthier branch `remove-graphify`; weftwise throwaway worktree `remove-graphify` from local main; docs archival on phase-1 branch). Agents and build/test scripts already clean; iterate `[base_query: set|empty]` tag needs separate grep; tracked `.lace/mount-assignments.json` graphify entry; removes `claude-code:1` feature in both devcontainers (added with graphify; clauthier gets claude-code from `lace-fundamentals`); reword `bin/README.md`, CI header; detect-usage examples reworded (`sometool`, `mcp__example__scope`) so shipped grep is zero; `lace validate` as parse check; docs `state: archived`, assessment proposal `evolved`. Leftovers for maintainer: `main/graphify-out/`, `~/.cache/graphify*`, `.claude/oversee/2026-10-08-graphify-interfacer.json`, possible `graphify` MCP registration. Open: weftwise code-graph RFPs |
| dispatch | rev-1 (cdocs:reviewer, opus, fresh) | `cdocs/reviews/2026-10-08-review-of-remove-graphify.md` | 2026-10-09T02:57 | round 1; inventory greps, `claude-code:1` removal safety, proportionality, floor |

## Steering Log

- 2026-10-09T02:38: maintainer: "Ok, let's /cdocs:full-send migration away from graphify including the graphify_base_query, where we added it to weftwise, and /rfp deletion of its feature in the lace cdocs. We'll move to focusing on better factoring and code cleanliness to reduce context load down the line but for now I just want us to fully yeet this misadventure"
