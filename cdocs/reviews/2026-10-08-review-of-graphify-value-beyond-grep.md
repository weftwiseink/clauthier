---
review_of: cdocs/reports/2026-10-08-graphify-weftwise-assessment.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T16:45:00-07:00
task_list: cdocs/graphify-weftwise-assessment
type: review
state: archived
status: done
tags: [fresh_agent, runtime_validated, implementation_review, verification_gate, graphify, evaluation, judge_noise, attribution]
---

# Review: Graphify Value Beyond Grep (Phase 4 Implementation)

> BLUF: Revise, `review_proof: confirmed` (I re-ran the floor; item 3 failed on one of my two tasks).
> - **Conclusion:** mostly fair. Nothing came cheaper, the graph-assisted agent was not better overall, and it contributed real hub-ranking finds on orientation.
> - **Numbers overstated:** the headline numbers carry more precision than judge noise allows. My blind re-judge of b1 (blast radius) flips it from mixed to **graph better (reach)**. Across the four re-judged tasks, the "misled" flags swapped sides on two.
> - **Errors in the graph's favour:**
>   - The scenario map's main example of graph reach on blast radius, `broadcastServerUpdate`, is named in the task text itself, and the grep arm read it.
>   - The 8-of-13 "graph-sourced" count never checks whether the arm's own grep surfaced the same item.
> - **Graph used lightly:** 4 of 8 graph arms made only 2 graph calls. The b1 (blast) and t2 (tests) arms never ran `affected`.
> - **Stamp bug:** reproduced. It affects ordinary long-lived worktrees too, not only mass deletions: the stamp base never advances, and six weeks of weftwise churn reaches the limit.

## Summary Assessment

Phase 4 asks whether graphify gives value beyond grep, and where.
On 10 discovery tasks it compares a graph-assisted sonnet arm against a grep-only arm, each graded by a blind opus judge.
The execution is careful and well recorded:
- prompts are symmetric;
- the leak check is real;
- both the cross-package graph and the older-commit graph reproduce exactly;
- the transcript checks are mechanical;
- collateral is clean.

The qualitative verdict holds: the graph arm is no better overall, it saves nothing, and its own contribution is hub ranking on orientation.
Three things need fixing before the section can be accepted as the maintainer's answer:
- the outcome and "misled" tallies are reported as robust when re-judging shows they are not;
- two attribution errors inflate the graph's blast-radius reach;
- the proposed "skip it for tests" guidance contradicts Phase 2.

Verdict: **Revise**.

## Verification (Phase 4 floor, re-run by the reviewer)

All weftwise work ran in throwaway worktrees (`gfy-rv-floor` at `2791713d` and `gfy-rv-b1` at `3fbd7251`) with a scratch `GRAPHIFY_OUT`. Both worktrees are now removed.

1. **Graph: pass.**
   - `srcpatch.py` on the three packages, then `cdocs/` and `_archive/` deleted, then a raw `update` into a scratch dir gave `Rebuilt: 9744 nodes, 25774 edges, 376 communities` (9.6 s). `gcount.py` reproduces the devlog's relation counts and `xpkg` byte for byte, and Q7's 3-hop directed path is exact.
   - Extra check on the older commit: `3fbd7251` with the generalized patch (`command-deer`, `doltlite-bocsync`, `doltlite-web`, `loro-multiplex`) and main's `.graphifyignore` copied in gives 10,327 / 27,153 with the same cross-package edges as the devlog.
   - Without the copied ignore file the build gives 10,673 / 27,462. The proposal requires the copy, but the devlog's older-commit paragraph does not mention it (A10).
2. **Records: pass, with one gap.** The task table, A/B mapping, card, judge prompt, judged answers, and transcript-check script are all present. The arms' shared `PROMPT.md` (rules, Tools section, the graph-first guideline) is not in the appendix. I recovered it from the arm transcripts: it is symmetric and matches the proposal.
3. **Grades: fails on b1.** I ran fresh opus judges on b1 and o1, built from the appendix's prompt and answers, with A and B swapped relative to the first judging (b1: A=grep; o1: A=graph). Each had read access to a matching worktree.

   | Task | First judging | Re-judge (reviewer) | Same outcome |
   |---|---|---|---|
   | b1 | mixed, unique graph 1 (`sharee_store_harness.ts`) / grep 1; 13/15 each | **graph better (reach)**: graph 1 (`document_store.ts` boot-race guards) / grep 0; graph 13/16, grep 12/16; `sharee_store_harness.ts` rated "true, not relevant" | **no** |
   | o1 | mixed, 4 / 5; misled graph yes, grep no; wrong graph 1, grep 0 | mixed, 5 / 6; misled graph **no**, grep **yes**; wrong graph 1 (`KeybindingService`), grep 1 (`sync_gate.ts`) | yes (flags swapped) |

   Spot checks:
   - `document_store.ts:825,924,939` (`3fbd7251`) carry the `requireRelational` guard comments the re-judge credits.
   - weft has no `command-deer` dependency or import.
   - `document_store_loader.ts:37` imports `@/lib/mounts` as `import type`.
4. **No collateral: pass.**
   - `main` is at `2791713d` and clean.
   - The six maintainer worktrees and `loro/` have the HEADs and dirty counts of the devlog's baseline.
   - The main graph's `graph.json`, `.graphify_root`, and `last_query_stamp` mtimes are unchanged.
   - `no-graphify`.
   - No `gfy*` worktree, branch, or container `/tmp` entry remains.

Combined with the implementer's two re-judges (c1, b2), the record is:
- **Outcomes:** 3 of 4 reproduce, and 1 flips toward the graph.
- **Misled flags:** these moved on b2 and o1. Those are 2 of the 3 tasks behind the report's "would mislead: graph 3".

## Section-by-Section Findings

### Value Beyond Grep: headline and tally

- **[blocking] The tally is presented as more stable than it is.**
  - "Over 8 tallied tasks the graph never won" and "graph better 0" rest on one judge per task, and b1 flips to graph better on re-judge.
  - The report generalizes from c1 and b2 that "per-item counts carry judge noise of a few items per task" while outcomes are stable. b1 shows outcomes move too.
  - "Wrong items: graph 2, grep 1; would mislead: graph 3, grep 1" are weaker still. The misled flags swapped sides on both re-judged tasks that had them (b2, o1), and o1's re-judge finds a grep-side wrong item as well.
  - The honest reading: neither arm reliably beats the other on any tallied task. Mixed is the usual result, as it would likely be for two runs of the same arm.
  - Report the 4 re-judges (3 same, 1 flipped) and either drop the misled and wrong counts or caveat them.
- **[blocking] Internal contradiction.**
  - Line 101 says "grep's side found as much or more on every class".
  - The scenario map's blast-radius row is graph 5 / grep 4, and the b1 re-judge widens that.
- **[non-blocking] No grep-vs-grep baseline.**
  - Without one, "mixed" cannot be told apart from run-to-run variance, and "differently biased second searcher" stays a hypothesis.
  - Add one line under Not Verified at minimum. A grep-vs-grep control on two tasks would calibrate it cheaply (Q1).
- **[non-blocking] The 15-item cap shapes "unique" counts.**
  - Example: b1's grep arm folded ten tests into one item, which the first judge counted as a unique item and the re-judge counted as shared.
  - Unique items partly measure ranking under the cap, not discovery. Worth one clause in the Method.

### Attribution and scenario map

- **[blocking] `broadcastServerUpdate` is not graph reach.**
  - The b2 task names it (`AuthoritativeServer.broadcastServerUpdate`).
  - The grep arm grepped and read its implementation (transcript calls at `authoritative_server.ts:718`), then chose not to list it.
  - Yet it is one of the two examples behind "Graph reach is real here: `explain` neighbour lists surfaced callers on INFERRED call edges (`subscribeRevocations`, `broadcastServerUpdate`)".
- **[blocking] The attribution method favours the graph.**
  - An item counts as graph-sourced if it appears anywhere in graph output, even when the arm's own grep surfaced it too.
  - b1's `sharee_store_harness.ts`:
    - it was in the `explain mount_store.ts` importer list, and also in the graph arm's own `grep "relational authority not armed"` (transcript line 1061);
    - the grep arm missed it only because it filtered `/loro/__tests__/`;
    - the re-judge rates it not relevant.
  - x1's `identity.test.ts` and b2's `subscribeRevocations` also appear in the arm's non-graph output (a grep result, and a comment at `acl_doc.ts:133`).
  - I checked the transcripts: o1's five graph-unique items in my re-judge are the cleanly graph-sourced ones (`god-nodes` and `explain` only).
  - Redo the count with an "also in the arm's own grep or read output" column. On this evidence the blast-radius claim weakens to "one or two leads, mostly also reachable by grep", and orientation (one task) is the graph's solid row.
- **[non-blocking] The named-entity row's "graph better (efficiency)" uses a different metric.**
  - Phase 2 measured graphify output bytes against grep totals that include reading, and the Usefulness section itself notes "it only locates".
  - Phase 4's definition (agent-level tokens at equal completeness) found no efficiency win anywhere.
  - As the map's only "graph better" label, it should say which metric it uses.

### Did the graph arm use graphify well?

- **[blocking] Disclose how lightly the graph was used.**
  - Graph calls per tallied arm: c1 5, b1 2, b2 8, t1 2, t2 4, x1 2, x2 2, o1 17.
  - b1, the blast task, grepped first despite the graph-first guideline, ran two `explain`s, and never ran `affected`, which the card lists for blast radius.
  - t2, a tests task, never ran `affected`, which the card lists for "tests that reach X". Phase 2's Q6 is a hit from exactly that command.
  - The verdict is fair as "sonnet with a card, as it actually behaves". It does not measure the graph's best case on blast radius or tests, which is the maintainer's concern ("otherwise it will always look inferior").
  - Say so in the Reading. Q2 offers a cheap rerun.
- **[non-blocking] Card quality is good overall.**
  - It covers the one command form, ambiguity retries, the dynamic-import gap from the pilot, and output reading.
  - One gap: it does not say `god-nodes` is repo-wide, which produced o1's `KeybindingService` error. The proposed guidance fixes this.
- **Setup handicaps checked, none material:**
  - **The generalized `source` patch helps the graph, as intended.** b1 would lack `weft -> doltlite-bocsync` without it.
  - **Delivering prompts as files is symmetric.**
  - **y1's late start and d1's scripting-only arm are outside the tally.**
  - **The sampler's 7 Explore subagents cost tokens but leaked nothing.** Their prompts carry class shapes only, with no feature column.
  - **Python in place of `jq` is equivalent.** The script is in the appendix.
  - **The `general-purpose` judges are fine.** Their prompt overrides the loaded rules, and mine behaved the same.

### Guidance for `/cdocs:graphify`

- **[blocking] "When to skip it: which tests cover a behaviour" contradicts the evidence.**
  - Phase 2 found `affected` is "a good test-impact list" (Q6).
  - In t2 the graph output listed the tests the arm missed, and the arm never ran `affected`.
  - Better: "Tests: grep test names and `describe`/`it` strings, and run `affected` on the subject for test-file leads."
- **[non-blocking] The rest is supported:**
  - **Orientation via `god-nodes` filtered to the package:** supported by o1 in both judgings, and by the `KeybindingService` error.
  - **Read listed files whose names fit:** supported by serendipity in t2, o1, and y1.
  - **Cycles:** supported by y1.
  - **Cross-package importers via `rg`:** supported by x2.
  - **Caveat:** the blast-radius bullet rests on weaker evidence than it implies (see Attribution). The guidance as a whole is untested, which the report says.

### Wrapper stamp-filter bug (report line 180, devlog Setup WARN)

- **Reproduced.** I set up a scratch git repo with a stub `graphify` that logs `update` calls, `.graphifyignore` = `/cdocs/`, and a stamp taken on the initial commit:

  | Ignored changes since the stamp base | Then a code edit |
  |---|---|
  | 100 `cdocs/` deletions (6.8 KB) | update runs |
  | 2,500 deletions (174 KB) | **no update**; stamp stays `... 8b137891` (blob of `"\n"`, the empty change set) |
  | 100 additions | update runs |
  | 2,500 additions | **no update**, same stamp |

  Cause, as reported:
  - `grep -vxF -e "$ign"` exceeds `MAX_ARG_STRLEN` (131,072 bytes for one argument);
  - the `2>/dev/null` around the whole block hides the `E2BIG`;
  - `chg` comes out empty.

  The empty-set stamp also equals a clean tree's stamp, so nothing looks wrong.
- **[blocking] It bites ordinary worktrees too.** The report's wording ("seen with 3,825 deleted `cdocs/` files") understates this.
  - The stamp's base commit never advances: line 36 reuses the old stamp's base, and line 37 writes it back. The repro kept `797fa925` across commits.
  - So ignored-path changes accumulate for the life of a worktree that merges main.
  - Measured on weftwise `main` history: ignored-path churn into `2791713d` is 2.5 KB over 2 weeks, 52.5 KB over 1 month, and 127.4 KB over about 6 weeks.
  - That last figure is at the limit. A worktree first queried six weeks ago and kept current goes silently stale for good. So does any worktree after an archive sweep.
  - Fix the one-line description and give it the weight of a silent-staleness bug.
  - Fix sketch, for the maintainer's call:
    - select non-ignored paths in one pass (`git check-ignore --no-index --stdin -v -n` and keep `::` lines), or pass `-f` a file;
    - stop swallowing stderr there;
    - advance the base to `HEAD` when writing a fresh stamp after a successful update.

### Report readability (BLUF and section)

- **[non-blocking] The BLUF's Value Beyond Grep paragraph is three sentences, which is right.**
  - Its precise counts ("unique important finds: graph 13, grep 19") are exactly the judge-noisy part.
  - Lead with the qualitative answer instead: the graph arm is no better and no cheaper, and adds hub-ranking leads on orientation.
- **[non-blocking] The section restates its result about five times:** in the BLUF, the intro paragraph, the tally, the Reading, and the Verdict per Role note.
  - Keep it in the BLUF, one tally, and the scenario map's "Why" column.
  - Cut or merge the Reading's first two sentences into the map.
  - The 10-column task table could drop the tokens and wall columns to the devlog, since no efficiency outcome occurred. The tally keeps the totals.
- **[non-blocking] Not Verified should name the light graph use and the b1 flip.**
  - The current text says "two tasks re-judged (same outcomes...)".

### Sub-devlog

- **[non-blocking] Missing records.**
  - Add the arm `PROMPT.md` template, with its two Tools variants (about 30 lines), to the appendix.
  - Note that the older-commit builds had main's `.graphifyignore` copied in.
- **[non-blocking] Update the BLUF and the Judges › Re-judge section.**
  - They should say outcomes reproduce on c1 and b2 but not on b1 (this review).
  - "Outcomes are stable on these two" is accurate but should not carry over to the report as a general claim.

## Verdict

**Revise.**
The measurement is sound and the qualitative conclusion is fair: no efficiency win, no overall reach win, and orientation is the graph's clearest contribution.
The headline tally, the attribution, and one guidance line need correcting so the maintainer's answer neither overstates graph reach on blast radius nor presents judge-noisy counts as settled.
No new runs are required to accept this round. The fixes are text, plus a re-attribution pass over existing transcripts.

## Action Items

1. [blocking] Report the re-judge record:
   - outcomes match on c1, b2, and o1, and b1 flips mixed -> graph better (reach);
   - misled flags moved on b2 and o1.

   Then reframe the headline and BLUF away from "graph never won" with exact counts, toward "neither arm reliably wins; mixed is the usual outcome".
   Drop or caveat the misled and wrong tallies.
   Reword floor item 3's "should match the table" to expect occasional disagreement, and record it when it happens.
2. [blocking] Fix line 101 ("grep's side found as much or more on every class"), which contradicts the blast-radius row (graph 5 / grep 4).
3. [blocking] Remove `broadcastServerUpdate` as graph reach: the task names it, and the grep arm read it.
   Redo the graph-sourced attribution with an "also in the arm's own grep or read output" check (b1 `sharee_store_harness.ts`, x1 `identity.test.ts`, b2 `subscribeRevocations`).
   Restate the blast-radius scenario row and the Reading to match. Orientation (o1, one task) is the solid graph-sourced row.
4. [blocking] In the Reading or Method, state graph-call counts per arm. Note that b1 (blast) and t2 (tests) never ran `affected` and b1 grepped first.
   The verdict measures typical sonnet-with-card use, not the graph's best case on those classes.
5. [blocking] Replace the guidance's "skip it for which tests cover a behaviour" with "grep test names and strings, and run `affected` on the subject for test-file leads" (Phase 2 Q6, t2 serendipity).
6. [blocking] Restate the stamp bug in the report and devlog:
   - the base never advances, so ignored changes accumulate per worktree;
   - weftwise churn reaches the 128 KB single-argument limit in about six weeks, or at once after an archive sweep;
   - the failure is silent and permanent.
7. [non-blocking] Relabel the named-entity row's "graph better (efficiency)" as Phase 2's output-token metric (locate only), not Phase 4's efficiency outcome.
8. [non-blocking] Add to Not Verified:
   - no grep-vs-grep baseline;
   - the 15-item cap shapes unique counts;
   - orientation and concept rest on one task each, and the BLUF names orientation as a graph-reach scenario.
9. [non-blocking] Trim the repeated tally (BLUF, intro, tally, Reading, Verdict note) to one statement plus the map.
   Consider moving the tokens and wall columns out of the task table.
10. [non-blocking] Devlog changes:
    - append the arm `PROMPT.md` template;
    - note that main's `.graphifyignore` was copied into the older-commit worktrees;
    - update the BLUF and the Re-judge section with the b1 flip.

## Questions for the Maintainer

1. How should judge noise be handled?
   - (a) Report the re-judge spread and soften the headline (action item 1; cheapest).
   - (b) Add a second blind judge to every tallied task and tally only agreed outcomes (about 8 more judge runs).
   - (c) Also run a grep-vs-grep control on two tasks, to show what "mixed" looks like between identical arms (about 4 more arm runs).
2. Should the graph's best case on blast radius and tests be tested?
   - (a) Accept the current "typical use" reading, disclosed.
   - (b) Rerun the b1 and t2 graph arms with the proposed guidance (`explain` and `affected` on the subject before grepping), judged blind against the existing grep answers. This also tests the guidance itself.
3. When should the stamp bug be fixed?
   - (a) Fix it now in `cdocs-graphify`: a one-pass ignore filter, stderr no longer swallowed, and the base advanced on a fresh stamp. It is a silent-staleness bug in shipped code.
   - (b) Keep it as a report recommendation alongside the `god-nodes` change.
