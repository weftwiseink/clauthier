---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T08:53:00-07:00
task_list: cdocs/graphify-overhaul
type: devlog
state: live
status: wip
tags: [graphify, oversight]
chat_record:
  - cdocs/_chat/2026-10-07-63ac45de-462d-4f43-ae1c-4ab6d59049b8.md
---

# Graphify Overhaul: Devlog

> BLUF: Top-level `/cdocs:propose-revise` loop replacing the overseer-run `graphify-scope` brief with a workstream seed query that each fresh implementer or reviewer runs itself.

## Objective

The current integration (`plugins/cdocs/bin/graphify-scope`, iterate `--graphify-scope`, `reviewer.md` "Graphify scoped-context brief") has the overseer run `explain` + recursive `affected` and paste the result into the reviewer prompt.
Maintainer's assessment: it bleeds graph output into the overseer, flattens graphify's subtlety into a recursive symbol dump, and ignores the CLI's useful surface (https://graphify.net/graphify-cli-commands.html).
Target: delete the script; the workstream carries a seed query (Scratchpoint `graphify_query:`), and fresh contexts run `graphify query` / `explain` themselves, possibly through a thin `/cdocs:code-query` skill instead of graphify's own bloated skill.

Maintainer edits pointing at the design: `dba0ac9` (`tool-use-safeguards.md` "Tools and Skills": `/graphify` `query` for initial workstream context, `explain` for entities, preferred over grep and full-file reads), `0832011` and `58bb5fa` (`graphify_query:` Scratchpoint field in the devlog and iterate templates).

## Scratchpoint

- next_steps: dispatch proposer.
- graphify_query:
- important_files: `plugins/cdocs/bin/graphify-scope`, `plugins/cdocs/skills/iterate/SKILL.md` "Graphify scoping", `plugins/cdocs/agents/reviewer.md` "Graphify scoped-context brief", `plugins/cdocs/rules/tool-use-safeguards.md`, `cdocs/proposals/2026-09-17-graphify-cdocs-integration.md`
- callouts:
  - decision: overseer is this top-level session.
  - decision: reviewer dispatches a sonnet explore of cdocs graphify history (proposals, reviews, devlogs, `cdocs/reports/2026-09-17-graphify-mcp-vs-cli-value-add.md`) to test the maintainer's premise.

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
| dispatch | prop-1 (cdocs:proposer, opus) | `cdocs/proposals/2026-10-08-graphify-overhaul.md` | 2026-10-08T08:55 | initial proposal |
| return | prop-1 | `0e2148a` | 2026-10-08T09:01 | `review_ready`. Overseer writes/passes query only; thin `/cdocs:code-query` skill + retargeted rule line; no graphify skill/installer (723 lines, adds overseer-reaching hook); index refresh via `graphify update .` when stale; delete outright; old proposal `evolved`. Premise flags: `/graphify` skill likely absent in lace container; `affected` absent from current docs (0.9.80 vs pinned 0.9.61); container index is shared `/var/cache/graphify`; neither design measured; markdown-heavy repo limits value |
| dispatch | rev-1 (cdocs:reviewer, opus, fresh) | `cdocs/reviews/2026-10-08-review-of-graphify-overhaul.md` | 2026-10-08T09:02 | round 1, with sonnet history explore |

## Steering Log

- 2026-10-08: maintainer: "Recursive symbol search removes all subtlety graphify could supply. We should probably delete the graphify-scope script entirely"; workstream seed query for `graphify query`, possibly wrapped by a new `/cdocs:code-query` since graphify's skill.md seems bloated; fresh contexts run it themselves.
