---
review_of: cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T15:49:31-07:00
task_list: cdocs/graphify-weftwise-assessment
type: review
state: archived
status: done
tags: [fresh_agent, runtime_validated, source_verified, graphify, evaluation_design, fairness, minimality]
---

# Review: Graphify Weftwise Assessment (Round 4, Phase 4)

## Summary Assessment

Phase 4 as revised at `6f6a4df` resolves all ten round-3 action items, including the three blocking ones: the graph arm can no longer silently fall back to grep, leaks inside the worktree are closed, and the grep arm is a real agent without graphify.
The design now seeks graphify's best case without manufacturing a win: every graph-favouring choice is matched by a guard against inflating the graph arm's result.
I ran the capability card's command form in the container: a wrapper call and a raw `god-nodes` call both work against a scratch index, raw calls leave the wrapper stamp valid, and the main graph is untouched.
Two small gaps should be fixed before the arms are dispatched:
- the judge's outcome set has no "both found something the other missed" case;
- the transcript path check would flag every graph arm, and the grep arm has no sanctioned scratch location.

Verdict: **Accept**, with those two fixes applied before dispatch (the overseer can check them by diff; no fifth round).

## Scope and Method

Scope: the diff `af68641..6f6a4df` (Operating rules, BLUF, Phase 4), read against the round-3 review and the overseer devlog's Steering Log and Scratchpoint.
Phases 1-3 are implemented and accepted, so I did not re-review them.

Probes, all read-only toward weftwise and the main graph:
- **Card command form**, in container `weftwise`.
  Setup: a `git clone --shared --no-checkout` of `/workspaces/weftwise/.bare` into container `/tmp/gfy-r4/wt` at `2791713d`, with `cdocs/` and `_archive/` deleted, a scratch copy of `/var/cache/graphify-weftwise` as `GRAPHIFY_OUT`, and the wrapper copied in with the floor's `cat >` form.
  Only the `-w` path differed from the card.
  Removed afterwards.
- **`tsc`**, on the host: `git archive 2791713d packages package.json` into my scratchpad, which reproduces a fresh worktree with no `node_modules`, then main's `node_modules/.bin/tsc` run from it.
- **Collateral**: `graph.json` (`14:09:35.88`), `.graphify_root` (`14:09:36.37`), and `cache/last_query_stamp` (`15:38:55.81`) had the same mtimes before and after.
  `pgrep -af "[g]raphify (update|extract|watch)"` was empty.
  I created no weftwise worktree, and weftwise `main` is clean.

## Round-3 Action Items

| # | Item | Status |
|---|---|---|
| 1 | F3: one container entry point, "skipping" warning, scratch in `/tmp`, pilot, graph-first, rerun when no graphify call | Resolved (Setup › Capability card, Pilot; Arms). Mechanics verified below |
| 2 | F2: no git for both arms, flagged in transcripts; lexical-trace step | Resolved (Arms; Leak check step 2). The overseer chose to run leaked tasks at their pre-investigation commit rather than rephrase them, which keeps good tasks intact |
| 3 | F6: grep arm gets everything except graphify; neither arm uses subagents | Resolved (Arms; a Design Decisions bullet) |
| 4 | F1: inventory additions, no-LLM scope, grep `GRAPH_REPORT.md` by section | Resolved (Feature inventory; NOTE under Goal) |
| 5 | F8: 15-item cap, irrelevant items marked, reach and efficiency split, serendipity commentary-only, normalized blinding | Resolved (Judge) |
| 6 | F5: synthetic tasks outside the tally; two tasks per high-prior class; class merge | Resolved (Scenario classes table with a Tasks column; Done-when) |
| 7 | F4: sampler sees no feature column | Resolved |
| 8 | F9: `jq` transcript checks | Resolved. `jq` is on the host, and subagent `.jsonl` files sit at `<session>/subagents/`, as stated |
| 9 | `last_query_stamp` mechanism | Resolved, but the new closing sentence reads ambiguously (N6) |
| 10 | F7: tokens include the card, wall time includes `podman exec` | Resolved (line 397) |

## Mechanics Verified

**Card command form (works).**

| Call | Result |
|---|---|
| `podman exec -i -u node -e GRAPHIFY_OUT=<scratch> -w <clone> weftwise bash -c '<scratch>/cdocs-graphify explain mergeBranch'`, cold | exit 0, 12.1 s (copy, then full `update`, because the copy has no `.stamp`) |
| same, warm | exit 0, 0.66 s, correct `explain` output |
| `... bash -c 'env GRAPHIFY_OUT=graphify-out graphify god-nodes --graph graphify-out/graph.json'` | exit 0, 0.40 s, god-node list |
| raw `query ... --graph graphify-out/graph.json`, then the wrapper again | 0.48 s: the stamp held. `last_query_stamp` lands in `graphify-out/cache/`, which the wrapper's `*` `.gitignore` hides |

The worktree index carries a full `GRAPH_REPORT.md` (1,636 lines) with God Nodes, Surprising Connections, Import Cycles, Communities, Knowledge Gaps, and Suggested Questions, so the inventory's claims hold for the arm's own index.
The unpatched clone built 9,731 nodes and 25,160 edges, which matches the report's cleaned fresh-worktree shape (main's 25,121 plus the known 39 edges).

**`tsc` from a fresh worktree path (runs, with caveats; see N3).**
Main's `node_modules/.bin/tsc` reports 5.9.3 and type-checks `packages/weft` in 3.1 s.
In a fresh worktree it reports about 4,000 errors, 1,662 of them TS2307, all for external packages (`vitest`, `react`, `@codemirror/*`, `loro-crdt`, ...).
Relative and `@/` imports resolve, so `--listFiles`, `--explainFiles`, and `--traceResolution` still give the internal import graph.
`packages/weft/tsconfig.json` sets `incremental: true`, so the run writes `tsconfig.tsbuildinfo` into the worktree.
That file is gitignored, so the wrapper stamp is unaffected.

## Fairness: Does Phase 4 Seek the Best Case Without Manufacturing a Win?

Yes.
The maintainer's complaint was that the assessment "will always look inferior and pointless" when graded against grep's best case.
Phase 4 addresses it on every axis Phase 2 was capped on.

What seeks graphify's best case:
- the `source` graph, which carries the cross-package edges;
- a capability card that goes beyond the shipped skill text, plus a pilot to fix it before any task;
- a graph-first rule, and a graph arm that may also grep, so a graph win measures value added on top of grep;
- classes chosen for a graph, with two tasks each for the high-prior ones;
- tasks phrased from problem statements;
- a lexical-trace screen that removes grep-only shortcuts;
- leaked tasks run at their pre-investigation commit, not weakened by rephrasing;
- a reference built from the union of both answers, not from grep's answer;
- reach kept apart from efficiency.

What keeps the result from being manufactured:
- the grep arm has scripts and `tsc`;
- synthetic tasks stay outside the tally;
- the sampler never sees the feature column;
- answers are capped at 15 items, and items that are true but irrelevant are marked;
- serendipity is commentary only;
- the judge is blind, and answers are normalized.

Residual biases, all small:
- **Toward neither, but distorting:** the missing mixed outcome (N1).
- **Toward the graph:** the wrapper's RUNTIME COUPLING appendix is a grep (`.observe(`/`.subscribe(`) bolted onto graph output (N4).
- **Toward grep, acknowledged:** community labels are hub names. This is scoped in the no-LLM NOTE and recorded as something that could change the verdict.
- **Noise, acknowledged:** one run per arm, and about 8-10 tallied tasks.

## Section-by-Section Findings

### Judge

**N1 (non-blocking; apply before dispatch): the outcome set has no mixed case.**
The outcome per task is exactly one of graph better (reach), graph better (efficiency), tie, grep better (reach), or grep better (efficiency).
On blast-radius and tests tasks, with 15-item answers, the likeliest outcome is that each arm finds an important item the other missed.
A judge forced to pick one label hides one side's reach, and that reach is exactly what the maintainer asked about.
The judge already records unique important items per answer, so the fix is one line:
- add a "mixed" outcome (each arm has at least one unique important item);
- have the scenario map count unique important items per arm, not only the winner labels.

### Arms and transcript checks

**N2 (non-blocking; apply before dispatch): scratch locations and the path allowlist.**
- **The grep arm has nowhere to put scripts.** It may write ad hoc scripts (F6) but not inside its worktree, and "No reading outside the task's worktree" leaves it no other location.
  An arm that reads this literally falls back to heredoc one-liners, or skips the scanner and weakens itself on the cycle and dead-code rows.
- **The path check flags every graph arm.** It flags "paths outside the worktree, beyond the allowed `.bin`".
  Every graph-arm call contains `/workspaces/weftwise/...`, the scratch wrapper path, `<scratch source graph>`, and `/tmp/gfy-arm-<task>/`.
  The rule as written voids every graph arm, and the rerun would be voided again.
- **The graph arm's container `/tmp` is awkward.** The arm's Write tool is on the host, so it can only create scripts in the container through `podman exec ... cat >`.
  The host has `python3`, `node`, `rg`, and `jq`, and that is enough for scripting over `graph.json`.

Fix:
- each arm gets one scratch dir outside its worktree, for example host `/tmp/gfy-arm-<task>-<arm>/`, using container `/tmp` only for a script that needs graphify's Python;
- the transcript check allowlists that dir, the card's fixed paths, and the `.bin` exception;
- "outside the worktree" is checked on read targets (Read/Grep/Glob paths, and file arguments to `cat`/`rg`/`sed`).

**N3 (non-blocking): one `tsc` line in the shared prompt.**
"Expect TS2307 for external packages, because there is no `node_modules`; relative imports resolve. Pass `--incremental false`."
Without that flag, `tsc` writes `tsconfig.tsbuildinfo` into the worktree, which breaks the no-writes rule.
The transcript check cannot see that write.
The write does not affect the stamp, because the file is gitignored.

**N4 (non-blocking): attribute RUNTIME COUPLING hits.**
The wrapper appends `grep -nE '\.(observe|subscribe)\('` hits from the files graph output names.
If a graph arm's unique important item came only from that appendix, the task row should say so, and the scenario map should not count it as reach.
It is a grep the wrapper ships, which is a fine thing for the skill to keep, but it is not the graph's value.
Fold this into "graphify features used".

### Setup

**N5 (non-blocking, ceremony): the separate scratch `source` build duplicates the wrapper's warm-up.**
The wrapper copies `$GRAPHIFY_OUT` without `.stamp`, so the warm-up call always runs a full `update` in the worktree (12.1 s in the probe).
The arm's index is that rebuild, not the scratch build.
The scratch dir in `-e GRAPHIFY_OUT` is still worth keeping, because it is the safety net for an arm's raw call that forgets the inner `env`.
It can be a plain copy of the main graph.
Counts are then read from the worktree index, which saves one build per worktree pair.
Optional.

### Operating rules

**N6 (non-blocking): the last sentence reads as a contradiction.**
"The `last_query_stamp` marker is harmless: a read-only probe that points at the main graph changes it, so it is not part of the check" sits directly under "never at `/var/cache/graphify-weftwise`".
Suggested wording: "It is excluded from no-collateral checks: it is an 18-byte TTL marker that no installed hook reads, and any read-only probe at the main graph changes it."

### Executability

One opus implementer can run Phase 4 in a session.
Dispatches:
- 1 sampler and 1 pilot;
- 20-24 arms, plus reruns;
- 10-12 judges.

That is about 35-40 dispatches, plus one worktree pair and a 12 s warm build for each pre-investigation commit.
The implementer's context holds answers, `jq` summaries, and grades, not transcripts.
The serial arm pairs dominate wall time (1-2 h).
The mechanics are verified: the container command form works, `jq` and the transcript location exist, `tsc` is runnable, and the floor's re-judge of two tasks reproduces cheaply.

### Ceremony

At 604 lines and about 7,300 words, most of the length is the accepted Phases 1-3 design.
Phase 4 itself is about 184 lines, which is proportionate for a blinded two-arm experiment with leak controls.
Cutting Phases 1-3 is a lifecycle choice (for example, compressing them to a pointer at the report once Phase 4 is accepted), not a Phase 4 defect.
Within Phase 4, about 25 lines restate rules stated once already, and can go without weakening fairness:
- the Edge Cases "Phase 4 leaks", "graph arm degenerating", and "arm scratch files" bullets repeat Arms, the card, and the transcript checks;
- the Test Plan's Phase 4 bullet repeats the transcript-check flags and the floor's "Records present";
- the Design Decisions bullet "run leaked tasks at their pre-investigation commit" repeats the NOTE under Leak check;
- the NOTE after the Phase 4 floor, on the Phases 1-3 floor's `last_query_stamp`, is history.

Keep the variance bullet, which is unique.
None of these cuts changes a rule.

## Verdict

**Accept.**
Every round-3 item is resolved, and the capability card's mechanics work as written.
The design is fair in both directions, with each graph-favouring choice matched by a guard.
Apply N1 and N2 before the arms are dispatched: both are one-line prompt or rule changes.
Without N1 the tally misreports reach.
Without N2 the check voids every graph arm and starves the grep arm of a scratch dir.
The rest is optional polish.
Setting `implementation_ready` is the overseer's flip.

## Action Items

1. [non-blocking, before dispatch] N1: Add a "mixed" judge outcome (each arm has a unique important item), and have the scenario map count unique important items per arm.
2. [non-blocking, before dispatch] N2: Give each arm a scratch dir outside its worktree (host `/tmp/gfy-arm-<task>-<arm>/`; container `/tmp` only when a script needs graphify's Python). Allowlist it, the card's fixed paths, and `.bin` in the transcript check, and apply "outside the worktree" to read targets.
3. [non-blocking] N3: Add one shared-prompt line on `tsc`: expect TS2307 for external packages, and pass `--incremental false`.
4. [non-blocking] N4: Record when a graph arm's unique item came only from the wrapper's RUNTIME COUPLING appendix, and do not count it as graph reach.
5. [non-blocking] N6: Reword the Operating rules' `last_query_stamp` closing sentence.
6. [non-blocking] N5: Optionally drop the separate scratch `source` build: keep a scratch copy as `-e GRAPHIFY_OUT`, and read counts from the wrapper-warmed worktree index.
7. [non-blocking] Ceremony: cut the roughly 25 restated Phase 4 lines listed under Ceremony.

## Questions for the Maintainer

1. Proposal length once Phase 4 is accepted:
   - (a) Leave Phases 1-3 as the accepted design record (reviewer's recommendation for now: it costs nothing during execution).
   - (b) After Phase 4 is implemented and accepted, compress Phases 1-3 to a short pointer at the report's floor and decisions.
2. Mixed outcomes in the headline (N1):
   - (a) Report reach per class as unique important items per arm, with winner labels secondary (reviewer's recommendation).
   - (b) Keep winner labels as the headline and add "mixed" as a sixth label.
