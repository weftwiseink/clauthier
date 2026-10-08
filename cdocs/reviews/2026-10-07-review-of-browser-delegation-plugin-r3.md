---
review_of: cdocs/proposals/2026-09-17-browser-delegation-plugin.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T18:33:56-07:00
task_list: cdocs/browser-delegation
type: review
state: live
status: done
tags: [fresh_agent, architecture, iterate_integration, evidence_independence, test_plan]
---

# Review (round 3): Browser Delegation Plugin

> BLUF: Revise, narrowly.
> All 11 round-2 items are resolved, verified against the repo, and both reviser deviations (dropping `sync`, the generic `confirmed` clause) are sound.
> Two new one-sentence blockers sit in the iterate integration: the reviewer's delegate reuses the implementer's browser session by default, and the `cdocs/_media/` durability advice steers reviewers outside `reviewer.md`'s write/commit boundary.
> The rest are non-blocking precision fixes, several grounded in the `@playwright/cli` README.

## Summary Assessment

The proposal specifies a minimal, agent-only, Claude Code-only plugin: one sonnet leaf that drives `@playwright/cli` named sessions and returns a fixed, verdict-free report, with iterate's reviewer dispatching it so the artifacts count as reviewer-produced.
The revision is clean, history-agnostic, and implements every settled maintainer decision (no R1-R6 dependency, bash-runner shape, no skills or rules files, no OpenCode dependency, sonnet driving with the pluggable-model question left open, one delegate driving N sessions).
The most important new finding is that branch-derived default session names make the reviewer's "independent re-run" land in the implementer's live browser, which weakens the very `review_proof` rule the proposal edits cdocs to accommodate.
Verdict: **Revise**, two small blocking edits. A round 4 can be a targeted check of those edits.

## Round-2 Item Resolution

Each item was checked against the cited repo fact, not the proposal's description of it.

| r2 item | Status | Evidence |
|---|---|---|
| Frontmatter `status: accepted` invalid | Resolved | `status: review_ready`. |
| 1. D2 MCP-inheritance premise false | Resolved | D2 drops reachability ("Reachability is not the reason") and re-grounds on named sessions, lead-context hygiene, and plugin agents ignoring `mcpServers` (subagents report §8, §13 confirm both). Test Plan item is a current-behavior check. The Background NOTE cites `ablate/SKILL.md:189` correctly. |
| 2. R1-R6 not in code | Resolved | R1-R6 appear only in Phase 5 as an independent cdocs reviewer change. |
| 3. Verdict handoff vs iterate proof rule | Resolved | "Iterate integration" has the reviewer dispatch the delegate. Matches `iterate/SKILL.md` Turn N.b and the `confirmed` row. Two new gaps in this section (F1, F2). |
| 4. Delegate writing devlog tables | Resolved | Commitment 4 and the `Sessions` lines: the dispatcher owns durable state. |
| 5. Mirror bash-runner | Resolved | "Prompt with:" description, `model: sonnet`, `effort: medium`, `maxTurns`, no `Agent`, fixed report, `${TMPDIR:-/tmp}/claude-$(id -u)` scratch path, all matching `plugins/cdocs/agents/bash-runner.md`. `tools: Bash, Read` (not r2's suggested `Write`) is justified in the body. |
| 6. Rules files never reach the lead | Resolved | Non-Goals and D7, with the [#14200](https://github.com/anthropics/claude-code/issues/14200) link. |
| 7. Marketplace + OpenCode | Resolved | File table includes `.claude-plugin/marketplace.json`. `npm run build:cdocs` passes `cdocs` explicitly and `.github/workflows/opencode-build.yml` triggers only on `plugins/cdocs/**`, so a sibling plugin is invisible to OC CI, as the Non-Goal claims. The "degrades cleanly" edge case is gone. |
| 8. Dead rule references | Resolved | `workflow-patterns.md` "Model Tiering", `overseers.md` "Stay thin" (~400K), `tool-use-safeguards.md` "One writer per file" all exist. No `model-tiering.md`, `orchestration-discipline.md`, or "durable specialist" remains. |
| 9. Nesting depth | Resolved | "Depth" paragraph. One overgeneralization (F7). |
| 10. Model comparison report | Resolved | Background entry. Benchmark figures match the report (MT-Web2Code, 1D-Bench multi-round 80.4 vs 79.5, DiffSpot best 40.7%). Open Question frames the pluggable-model choice for the maintainer. |
| 11. Sync simplification | Resolved | One delegate drives N sessions by default. Parallel delegates only for independent driving. |

## Reviser Deviations

**(a) `sync` skill dropped entirely: sound.**
r2 item 9 asked that `sync` stay a skill rather than a wrapper agent, but r2 item 11 and the maintainer's one-delegate-N-sessions default leave such a skill with nothing to do beyond forwarding a multi-session prompt, which is exactly D7's argument against `drive`.
The depth hazard r2 item 9 guarded against is still covered by the "Depth" paragraph's no-intermediate-agent rule.
The agent description's "Sessions: one or more roles" line carries the multi-client contract.

**(b) Generic `confirmed`-row clause in `iterate/SKILL.md`: sound, with one wording note.**
The current row text ("cited an artifact it produced") is ambiguous for subagent-produced artifacts, and the clause resolves it generically (it equally covers a reviewer-dispatched `bash-runner` capture file), so cdocs gains no dependency on this plugin.
It matches the accepted nested-subagent-workflows proposal, which lets reviewers dispatch freely.
It does not open a loophole: the artifact must be *produced* by the reviewer's own child this round, so re-citing an implementer's capture still fails.
The edit touches `plugins/cdocs/**` and so triggers the OC build workflow, but it is prose only and needs no build-script change.
Its effectiveness does, however, depend on F1: "produced this round" is only meaningful if the child re-ran the floor on fresh state.

## Section-by-Section Findings

### Iterate integration

**F1 [blocking] The reviewer's delegate reuses the implementer's session by default.**
Default names are `<sanitized-branch>-<role>`, and the workflow says "Open or reuse each named session".
In an iterate round the implementer (which "self-verifies before reporting done", per iterate's Roles) and the reviewer run on the same branch, so a reviewer dispatching `Sessions: preview` lands in the implementer's still-live browser, with its cookies, `localStorage`, page state, and any `eval` the implementer ran.
The report would say `reused`, but nothing tells the reviewer that this undermines independence, and Turn N.b's "empirically re-runs the floor" assumes fresh state.
Fix (one sentence in "Iterate integration", echoed in the README): the reviewer's delegate runs on fresh sessions, either via a reviewer-specific role suffix (e.g. `<branch>-review-<role>`) or by closing and re-opening the named session first, and a `reused` session never backs a `confirmed` row.

**F2 [blocking] `cdocs/_media/` durability advice conflicts with `reviewer.md`.**
"A reviewer that needs them durable passes an output dir under `cdocs/_media/`" has two readings, and both fail.
If the media stay uncommitted, they are not durable (untracked files do not cross worktrees, per this repo's CLAUDE.md).
If the reviewer commits them, it violates `reviewer.md`'s "Write exactly one review document" and "Commit your review file (and `last_reviewed`) by explicit path; run no other mutating VCS command", which Phase 3's "no other cdocs agent or skill changes" forbids amending.
Iterate already covers ephemeral artifacts ("inlining excerpts for ephemeral artifacts"): for a screenshot, the excerpt is the report's `Facts`/`AE score` lines plus the reviewer's own description of what it saw.
Fix: replace the sentence with that, or pick option B in the question below and add `reviewer.md` to the file table and Phase 3.

**F3 [non-blocking] Turn N.b vs the `confirmed` row.**
The clause lands on the `confirmed` row only, while Turn N.b says "the reviewer empirically re-runs the floor".
The row clause is sufficient, but a reader of Turn N.b alone could still read "re-runs" as "personally".
Optional: put the clause in Turn N.b and have the row point to it, or put it in both.

### The agent

**F4 [non-blocking] `@playwright/cli` writes into the working tree by default.**
Per the [`@playwright/cli` README](https://github.com/microsoft/playwright-cli), every command emits an auto-snapshot to `.playwright-cli/page-<timestamp>.yml` relative to the cwd, and config loads from `.playwright/cli.config.json` in the cwd.
Run from a reviewer's worktree, the delegate leaves untracked `.playwright-cli/` files there, contrary to "the delegate edits nothing".
The agent body should say how this is contained (an explicit `--filename=<abs out dir>/...` for captures, and either running from `$out` or deleting `.playwright-cli/`), and Phase 1 should record whether session namespaces are cwd/workspace-scoped (the README's dashboard groups sessions "by workspace"), since `cd "$out"` might change which session `-s=<name>` addresses.

**F5 [non-blocking] Convergence polling and `maxTurns: 40`.**
"Poll at a fixed interval until every session agrees" as one Bash call per poll would exhaust 40 turns on a modest timeout (e.g. 60s at a 2s interval is 30 polls, before any setup).
State that polling runs inside one Bash invocation (a shell loop over `playwright-cli -s=<name> eval ...` per session, bounded by the timeout), which also keeps poll output out of the delegate's context.

**F6 [non-blocking] Unchecked secondary dependency and multi-artifact AE.**
`compare -metric AE` needs ImageMagick, which the availability check does not cover, and `compare` errors on size-mismatched images.
The report has one `AE score` line while N sessions can each produce a screenshot.
Fix: check `compare` only when a baseline is given (`WARNINGS` with the fact if absent), report a size mismatch as a fact, and allow one `AE score` line per compared artifact.

### Depth

**F7 [non-blocking] "Any wrapper agent ... would push the delegate past the limit" is true only under a nested overseer.**
Under a top-level overseer the chain main, reviewer (1), wrapper (2), delegate (3) is within the default limit (subagents report §10).
The no-wrapper conclusion is still the right rule, so reword to "under a nested overseer, any wrapper pushes the delegate past the limit, so ...".

### D2 and Phase 1

**F8 [non-blocking] "Gated on a SIGTRAP spike" overstates what the spike gates.**
D2's own point 3 adopts the CLI whether or not it shares the SIGTRAP exposure, so the spike gates README pinning guidance only.
The BLUF's "a Phase 1 spike gates the toolset default" and D2's heading imply more.
Align both with Phase 1's heading ("gate on default-toolset claims only") and Phase 2's "README default wording only".
Separately, named-session isolation is listed as gating D5's isolation claim, but if it fails the agent body's naming changes too, not only the README, so Phase 2's "Depends on: Phase 1 for README default wording only" should mention it.

**F9 [non-blocking] Spike command flag.**
`playwright-cli open --headless <url>`: the CLI is headless by default and its README documents only `--headed`.
Use `playwright-cli open <url>` so the gating spike does not fail on an unknown flag.

**F10 [non-blocking] Local `npx playwright cli` as an availability path.**
The CLI README says to prefer `npx playwright cli` when a project has a local Playwright.
weftwise has one, pinned in lockstep with its Dockerfile browsers, which bears directly on D2 point 3: a project-local CLI may inherit the project's existing pin rather than a second one.
Add to Phase 1: whether the delegate should prefer `npx --no-install playwright cli` over a global `playwright-cli`, and fold the answer into the availability check.

**F11 [non-blocking] D2 point 2 nuance.**
MCP tools are deferred by default (subagents report §8), so a session-level Playwright MCP server costs the lead its tool names rather than full schemas.
The surviving argument is the one D2 already makes second: MCP tools in the lead's pool invite the lead to drive directly.
Consider leading with that and softening "schemas stay out of the lead's context".

### Session reuse across turns

**F12 [non-blocking] "The browser state carries over" holds only while the session lives.**
Per the CLI README, profiles are in-memory by default and a headless session shuts down after an hour idle, so a fresh delegate past that window gets a `reopened` session with empty cookies and storage.
Iterate rounds can easily exceed an hour.
Note it (or have long flows pass `--idle-timeout` at open), and keep `--persistent` out of the default since it would weaken the isolation test.

### Test Plan

**F13 [non-blocking] Two design behaviors lack a test.**
The killed/expired-session re-open path (Edge Cases) and the AE baseline diff (Proposed Solution) have no Test Plan item, and Phase 2's success criterion omits a baseline.
Add a `playwright-cli -s=<name> close` then re-dispatch check expecting `reopened`, and one dispatch with a baseline expecting an `AE score` line.
After F1, the iterate item should also confirm the reviewer's sessions report `opened`, not `reused`.

### Framing and conventions

History-agnostic: no "previously/now/revised/no longer" in the body ("D4: Named-subagent reuse now" means "in v1", not history, and could read "in v1" to avoid the ambiguity).
Sentence-per-line, Mermaid, linked external references, and colon-over-em-dash conventions are followed.
BLUF matches the body except for F8's gating language.
The file table matches Phases 2 and 3 exactly.

## Verdict

**Revise.**
F1 and F2 are each a one- or two-sentence edit to "Iterate integration" (plus README wording and the iterate Test Plan item for F1).
No r2 item regressed, and no design-level rework is needed.

## Action Items

1. [blocking] F1: In "Iterate integration", require the reviewer's delegate to run on fresh sessions (reviewer-specific role suffix, or close-and-reopen first), state that a `reused` session never backs a `confirmed` row, and mirror this in the README and the iterate Test Plan item.
2. [blocking] F2: Replace the `cdocs/_media/` durability sentence with iterate's existing ephemeral-artifact rule (cite the scratch path and inline the report's `Facts`/`AE score` lines plus the reviewer's own observation), or adopt maintainer option B below and add `reviewer.md` to the file table and Phase 3.
3. [non-blocking] F4: Specify how the agent contains `.playwright-cli/` auto-snapshots and cwd config, and add workspace/cwd session scoping to Phase 1's isolation spike.
4. [non-blocking] F5: State that convergence polling runs inside one bounded Bash loop.
5. [non-blocking] F6: Check ImageMagick `compare` only when a baseline is given, report size mismatch as a fact, and allow one `AE score` line per compared artifact.
6. [non-blocking] F7: Scope the wrapper-depth sentence to the nested-overseer case.
7. [non-blocking] F8: Align the BLUF and D2 heading with "the spike gates README pinning guidance", and note that a failed isolation spike also changes the agent body.
8. [non-blocking] F9: Drop `--headless` from the Phase 1 spike command.
9. [non-blocking] F10: Add a Phase 1 item on preferring a project-local `npx --no-install playwright cli` over a global install.
10. [non-blocking] F11: Lead D2 point 2 with "invites the lead to drive directly" and soften the schema-context claim given deferred MCP tools.
11. [non-blocking] F12: Qualify "browser state carries over" with the in-memory profile and one-hour idle timeout.
12. [non-blocking] F13: Add Test Plan items for the re-open path and a baseline AE diff.
13. [non-blocking] F3: Optionally place the reviewer-dispatched-subagent clause in iterate's Turn N.b as well as the `confirmed` row.

## Questions for the Maintainer

**Q1. Where do durable screenshot artifacts live for an iterate `confirmed` row?** (governs action item 2)
- **A (recommended):** Scratch only. The reviewer cites the scratch path and inlines the report's facts and its own observation, per iterate's existing ephemeral-artifact rule. No `reviewer.md` change.
- **B:** The reviewer passes `cdocs/_media/YYYY-MM-DD-*.png` as the output dir and commits those files alongside its review. This needs a one-clause `reviewer.md` amendment ("and any `cdocs/_media/` artifacts it cites") and lifts Phase 3's "no other cdocs agent changes" constraint.
- **C:** Defer. Drop the durability sentence for v1 and revisit once a real iterate round shows whether scratch citations suffice.
