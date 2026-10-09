---
review_of: cdocs/proposals/2026-10-08-remove-graphify.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T17:37:05-07:00
task_list: cdocs/remove-graphify
type: review
state: live
status: done
tags: [fresh_agent, cleanup, verification, round_2]
---

# Review: Remove Graphify from CDocs and Weftwise (Round 2)

## Summary Assessment

Round 2 of the graphify removal plan, reviewed at `d48c41d` (the proposal is unchanged at HEAD `a524b61`).
The revision resolves all three round-1 blocking items and all six non-blocking ones, and it matches the overseer devlog's Scratchpoint decisions.
I checked the inventories and verification commands against both repos, and found nothing that would send implementation wrong.
Verdict: **Accept.**

## Round-1 Action Items

| # | Item | Status |
|---|---|---|
| 1 | claude-code rationale (host `user.json`, not `lace-fundamentals`) | Resolved: Important Design Decisions now cites `mergeUserFeatures` and the pre-graphify commits. |
| 2 | Step 5 self-match | Resolved: `':!cdocs/*remove-graphify*'` added. |
| 3 | Weftwise code-graph RFP disposition | Resolved: review-plugin RFP archived, spike-comparison and canvas RFPs deferred, each with a NOTE pointing at the clauthier assessment, and the canvas NOTE scoped to agent-context value. Phase 2's "Do not touch" is narrowed to match. |
| 4 | `.lace/` commit rule | Resolved: in the inventory row and in Edge Cases. |
| 5 | `aws-config` trailing comma | Resolved. |
| 6 | Step 1 pathspec `':!cdocs'` | Resolved. |
| 7 | detect-usage comment wording | Resolved. |
| 8 | MCP edge case trimmed | Resolved. |
| 9 | Checkpoint devlog archival | Resolved: archived, matching the Scratchpoint decision. |

Both round-1 maintainer questions are answered by Scratchpoint decisions: detect-usage stays with reworded examples, and the checkpoint devlog is archived.

## Spot Checks

- **Clauthier step 5** run at HEAD lists exactly the Docs disposition set (4 proposals, 5 reports, 7 devlogs, 20 reviews) and excludes this review, so it is both satisfiable and complete.
- **Clauthier step 1** still lists the 18 inventoried files.
- **Weftwise docs:** all seven listed records exist, are `live`, and the three `review-of-graphify-devcontainer-feature*` reviews match the glob.
- **Weftwise `devcontainer.json`:** `GRAPHIFY_OUT` is not the last `containerEnv` key (Wayland vars follow), so the two named trailing commas are the only ones this edit exposes.
  `.graphifyignore` is tracked.

## Non-blocking Notes

These are for the implementer to keep in mind and need no revision.

- Weftwise verification has no counterpart to clauthier step 5.
  Phase 2's implementer can check its doc edits with `git grep -lE '^state: live' -- 'cdocs/*graphify-devcontainer-feature*' 'cdocs/*code-graph-review-plugin*' 'cdocs/*code-graph-chain-checkpoint*'`, which should return nothing.
- Phase 2's "archive the weftwise docs listed under Docs disposition" covers two deferrals as well.
  The per-file `state` values in Docs disposition are authoritative.
- From round 1: clauthier step 4 assumes `lace validate` prints mounts.
  If it does not, confirm the removal in `.lace/mount-assignments.json` instead.

## Verdict

**Accept.** The plan is ready for `/cdocs:iterate`.

## Action Items

1. [non-blocking] Phase 2 implementer: run the weftwise `state: live` grep above as a self-check on the doc archival.
2. [non-blocking] Phase 1 implementer: if `lace validate` output omits mounts, verify `graphify/index` absence in `.lace/mount-assignments.json`.
