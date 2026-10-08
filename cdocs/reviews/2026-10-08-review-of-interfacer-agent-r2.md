---
review_of: cdocs/proposals/2026-10-08-interfacer-agent.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T09:24:46-07:00
task_list: cdocs/interfacer-agent
type: review
state: live
status: done
tags: [fresh_agent, architecture, subagents, over_specification]
---

# Review: Interfacer Agent (Round 2)

## Summary Assessment

The proposal deletes the `browser-delegate` plugin and adds one 69-line sonnet agent, `cdocs:interfacer`, with one-clause edits to the reviewer, iterate, implement, and devlog surfaces.
Both round 1 blockers are resolved as deletions: `agentId` is the only handle, and every dispatcher tears tooling down before it returns.
All seven non-blocking items are applied, and the revision adds no new failure mode.
It matches the maintainer's brief (one general agent in `bash-runner`'s style, project tooling only, tmp-dir media plus `report.md`, durable by default, plugin deleted) and is implementable as written.
Verdict: **Accept**, with optional nits that all remove or swap text.

## Round 1 Action Items

| # | Item | Status |
|---|---|---|
| 1 | `agentId` handle, no `name` | Resolved: description line, "Warm agent" bullet, sequence diagram, canary pass criteria. The naming convention and the "Name collision" edge case are gone. |
| 2 | Tear down before every return | Resolved: the description says "say "tear down" before you return"; "Ending" has one rule; D5, D6, and Override 3 agree. |
| 3 | One final-message sentence | Resolved (line 139). |
| 4 | Cut the duplicate verdict intro | Resolved. |
| 5 | Setup parenthetical, `"fresh"` option | Resolved. |
| 6 | "prefer dispatching" | Resolved (line 187). |
| 7 | Edit-path hook in "Do not touch" | Resolved (line 294). |
| 8 | Record foreground or background | Resolved (line 281). |
| 9 | "Context limit" bullet, `state: archived` | Resolved (lines 63, 310). |

## Verified

- The agent block (proposal lines 73-141) is 69 lines, against `bash-runner`'s 65.
  Its frontmatter parses with the repo's `yaml` package to the keys `name, model, effort, description, color, maxTurns`, the same key set round 1 ran through `npm run test:opencode`, so that result still holds.
- The references hold: `reviewer.md:50` is the `_media` clause; iterate lines 89 and 130 are Turn N.b and the `confirmed` row; implement step 5 has the "Follow verification" bullet; devlog line 51 is the Screenshots bullet; `plugins/cdocs/README.md:119,210` carry "follows no rules" and "7 agents converted".
- Subagents report line 132 supports "nested Agent tools have no `name`", and this reviewer's own depth-1 Agent schema confirms it.
  Report line 78 supports the "`maxTurns`: partial and resumable" claim.

## Findings

All findings are non-blocking.

### Phase 4 fallback depends on a parameter nested dispatchers lack

The WARN (line 255) and Phase 4 say that if foreground process lifetime fails, the description should tell dispatchers to "run it in the background".
That fallback does not work for the dispatchers that matter.
The implementer and the reviewer dispatch from depth 1, and the same report line 132 that rules out `name` also rules out `run_in_background`: neither is in the nested schema.
The robust fix sits on the interfacer's side.
It should start long-lived things detached, using the tool's own daemon or `setsid`/`nohup`, rather than through Bash `run_in_background`, so they outlive its turn whatever mode it runs in.
Suggested swap, with no added text:
- Line 178: "(a tool's own daemon such as a browser CLI's session, or a detached process)".
- Phase 4 fallback: "If foreground lifetime fails, make the 'outlive' rule say detached (`setsid`/`nohup`), not Bash `run_in_background`, and re-run."

The canary would surface this anyway, so it does not block.

### Length targets disagree

Four places give a target, and they disagree:
- the BLUF says "~65-line";
- line 70 says "about `bash-runner`'s";
- the Test Plan says "under ~70";
- Phase 1 success says "under ~80 lines".

Keep line 70 and the Test Plan bullet, change Phase 1 to "under ~70", and change the BLUF to "~70-line" or drop the number.

### Text that can go

- **Maintainer Overrides items 2 and 3** restate D3 and D6 word for word.
  Item 1's rejected readings (a)-(c) are the only content found nowhere else.
  Keep the NOTE header and item 1, and make items 2 and 3 a single "D3 and D6 are likewise overridable" clause.
- **Edge case "Reviewer's media in a review"** (line 257) restates the Callers bullet at line 191. Cut it.
- **D5's last sentence** (line 238) repeats the "Ending" bullet's rationale (line 181). Either one is enough.

## Verdict

**Accept.**
The blocking items are resolved without new problems, and the agent body is close to `bash-runner` in shape, tone, and length.
The nits are optional, and the implementer can apply them in Phase 1 or Phase 4.

## Action Items

1. [non-blocking] Swap the Phase 4 and WARN fallback from dispatcher-side background dispatch, which nested Agent tools cannot request, to interfacer-side detached processes. Adjust line 178 to match.
2. [non-blocking] Unify the length target at about 70 lines: the BLUF and Phase 1 success.
3. [non-blocking] Trim Maintainer Overrides items 2 and 3 to one clause, cut the "Reviewer's media in a review" edge case, and drop D5's last sentence.

## Questions for the Maintainer

- **Q1. Fallback if a foreground interfacer's processes die when it returns.** (a) The interfacer starts long-lived things detached (recommended: it works at any depth). (b) Dispatchers run it in the background (unavailable to depth-1 implementers and reviewers). (c) Drop warm tooling and restart per check, keeping only the warm agent.
