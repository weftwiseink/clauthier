---
review_of: cdocs/proposals/2026-10-08-graphify-overhaul.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T10:03:56-07:00
task_list: cdocs/graphify-overhaul
type: review
state: live
status: done
tags: [fresh_agent, minimalism, verification_design, ablation, naming]
---

# Review: Graphify overhaul, round 3

> BLUF: Accept.
> The post-acceptance revision (`924b9f1`) applies the 11:45 steering faithfully: the rename to `/cdocs:graphify`, `cdocs-graphify`, and `graphify_base_query` is complete, and all seven r2 action items are resolved.
> The exclusion subsection answers "how is `cdocs/` being ignored" directly.
> The ablation run is the weak spot: its task is one `grep -rln '›'` away from a full answer, so it cannot show graph value on clauthier and can only change the design through VOID.
> Two cheap fixes prevent likely false results: Phase 5's dispatched reviewer resolves `cdocs-graphify` from the *main* checkout's `plugins/cdocs/bin`, not the branch; and the `/cdocs:rfp` step should refresh only an existing main graph.

## Summary Assessment

The revision renames the wrapper, skill, and Scratchpoint field, adds a "How `cdocs/` is kept out of the graph" subsection, hands main-graph refresh to consumers except for one `/cdocs:rfp` step, and adds a `/cdocs:ablate` run to verification.
The rename and the exclusion text are clean, and the r2 container facts are folded into Background accurately.
The ablation as specified would almost certainly return VALID with a `context_gap` near 0 for reasons that say nothing about the design, so its task or venue should change before it runs.
Verdict: **Accept**; every action item below is a text edit, and F3 and F5 should land before the run each one concerns.

## Round 2 action items

| R2 item | Status |
|---|---|
| 1 purge step | Resolved: gone from the table, sketch, tests, and Phase 1; replaced by one sentence ("a plain `update` evicts ignored nodes"). |
| 2 false `update` claims | Resolved: Background, D4, Edge Cases, and the Phase 4 lace NOTE match 0.9.61. |
| 3 drop `.graphify_root` | Resolved: in the Copy row, the sketch, D3, and a test assertion. |
| 4 stamp | Resolved: dropped; NOTE item (1) records the default. |
| 5 smaller trims | Resolved: lock WARN is one Edge Case clause, `CODE_QUERY_MAIN_OUT` and `--budget 2000` are gone, "Main checkout is the caller" is host-only. |
| 6 live-run precondition | Resolved: rebuild step plus the stale-fixture NOTE. |
| 7 Phase 1 scope | Resolved: two items. |

R2 question 1 (missing ignore line) resolved as option (b), the stderr hint, and is flagged as overridable in the NOTE.

## Section-by-Section Findings

### F1 Rename completeness (no action)

- `grep -rn graphify_query plugins/ CLAUDE.md` hits only `skills/devlog/template.md:20` and `skills/iterate/template.md:8`, both listed in the replacement table and Phase 3.
  The done-when grep does not false-match `graphify_base_query` (`graphify_query` is not a substring of it).
- No `code-query`/`code_query` residue in `plugins/` or `CLAUDE.md`; the only `seed` hits (`rfp/SKILL.md:53`, `chat-record.test.sh`) are unrelated.
- The proposal itself has no "seed" or `code-query` left; the two mentions of the old field name are the rename instructions.
- **Non-blocking nit:** the replacement table omits three files Phase 3 changes: `plugins/cdocs/rules/tool-use-safeguards.md` (rule line), `plugins/cdocs/skills/devlog/SKILL.md` (field definition), and the new `plugins/cdocs/skills/graphify/SKILL.md`.
  Phase 3 is complete, so either add the three rows or retitle the table as partial; do not maintain two lists that disagree.

### F2 Exclusion subsection (clear; trims optional)

The five bullets answer the question in the order a reader asks it: which file, who writes it, when graphify reads it, what the wrapper does (nothing), and the measured effect.
"Queries read only the graph" closes the loop on why no per-query filtering exists.

**Non-blocking, removes text:** the material is now stated in several places.
- The 90% figure appears in Summary, D9, and the subsection; keep it in the subsection only.
- D9's first sentence restates the Summary bullet; D9 can shrink to its one unique point (the ignore lives in the repo because the main-graph refresh bypasses the wrapper) plus the pointer.
- The missing-line hint is described in the wrapper table, the sketch, NOTE item (2), the subsection, and Edge Cases; the Edge Case bullet can drop its middle clause, which repeats the subsection.

### F3 [non-blocking, before the ablate run] The ablation task cannot discriminate on clauthier

Verified on this tree:
- `grep -rln '›' plugins/ scripts/ CLAUDE.md` returns 11 files, which is the produce/parse/test set: `scripts/check-rule-refs.ts` (`SEPARATOR = /\s+(?:›|>)\s+/`, line 102), its test, the rule file that carries references, the skills that quote references, the README, and `CLAUDE.md`.
- `plugins/cdocs/hooks/inject-rules.ts` contains no `›` and does no reference parsing; it compares content hashes.
  The proposal's claim that the task spans it is wrong, which will also muddy the evaluator's ground truth.
- The references live in markdown *body* text, and graphify graphs markdown as headings only, so the graph cannot surface the files that produce references; only `check-rule-refs.ts` has code edges, and it is one file.

So the unassisted arm finds everything with one grep and one file read, and the assisted arm cannot do better.
The expected outcome is VALID with `context_gap` around 0, which the decision map routes to "repeat on a weftwise task before deciding".
On clauthier, then, only VOID can change the design, and Phase 5's primary check (the stub log shows `query <q>`) already tests the same thing more cheaply.
The run as written measures cost, not value.

This matches the proposal's own Edge Case: clauthier is docs-heavy, and the overseer "may leave the base query empty for pure-prose workstreams".
The design's value claim (call edges, `.observe`/`.subscribe` coupling, a repo too large to grep-and-read) lives in weftwise.

Recommended (see Question 1): run the single ablation on a weftwise task whose answer crosses import edges and has no single literal to grep, and delete the clauthier task and the "repeat on a weftwise task" clause.
If weftwise is not reachable for this workstream, keep clauthier but call the run a usage-and-cost smoke test and delete the decision branches it cannot trigger (the VALID ≤ 0 and VALID > 0 bullets), which removes text.

### F4 [non-blocking, rewording] The arms' prompts differ, which `/cdocs:ablate` treats as a confound

`/cdocs:ablate` passes "one pinned prompt string ... VERBATIM to both arms (D4)", and its Step 0 says anything beyond the one recorded tool-set entry "is a confound that invalidates the comparison".
Here the assisted arm adds the `graphify_base_query` line and the unassisted arm adds a withhold line.
That is the right design: the CLI shares `PATH` with `Bash`, so an allowlist cannot withhold it, and the base query is the treatment being measured.
The text should say so, so the evaluator does not flag it: reword the existing bullet to "Step 0 records the arm difference as these two prompt lines instead of a tool-allowlist entry, since a CLI on the shared `PATH` cannot be withheld by allowlist."
The extra `detect-usage` on the unassisted transcript is correctly called out as a manual step; `ablate.sh decide` does not check that arm.

### F5 [non-blocking, before Phase 5] The host stub run finds the main checkout's `cdocs-graphify`, not the branch's

Plugin `bin/` on this host's `PATH` is `/var/home/mjr/code/weft/clauthier/main/plugins/cdocs/bin` (entry 14), with `~/.local/bin` ahead of it (entries 2 and 11).
A reviewer dispatched with `isolation: "worktree"` from a branch where Phases 2-3 are not yet in main's working tree finds no `cdocs-graphify` at all.
The stub log then shows no `query` line, which the failure pictures read as "agents ignore the base query", and Phase 5's done-when would apply the D6 fallback for the wrong reason.
Fix (one clause in step 1): run Phase 5 once Phases 2-3 are in main's tree, or symlink the branch's `cdocs-graphify` into the stub's `~/.local/bin` and remove it with the stub.
The devcontainer runs are post-accept, after landing, so they are unaffected if the container loads the plugin the same way (worth one glance at `echo $PATH` there).

### F6 [non-blocking, wording] `/cdocs:rfp` step: refresh only an existing main graph

Placement as step 6, after the collision check, is right: the stub exists before any side effect, and RFP is where a workstream begins.
Two wording problems:
- "If `graphify` is installed" builds a graph from nothing in a repo that never opted in, writing an output directory into the main checkout when `GRAPHIFY_OUT` is unset, and without the wrapper's self-ignoring `.gitignore` (unless graphify ignores its own output, which is unverified).
  It also contradicts the wrapper, which skips when no index exists.
  Condition it on an existing main graph instead: "If a main graphify graph exists (`$GRAPHIFY_OUT`, or `graphify-out/` in the main checkout), run `graphify update .` in the main checkout, output discarded, ...".
- "on the main checkout" leaves open whether it means "pass the main checkout as the scan path" or "run from it", and the two give different output directories on a host.
  "In the main checkout" settles it.

The step's value is small by the proposal's own account (D3: a stale main graph "only costs a larger first update"; each copier's `update` repairs it), so it is kept only because the maintainer asked for it; see Question 3.

### F7 [non-blocking, one character] Anchor the overseer-clean signature

`detect-usage` tests the whole command string as well as each segment, so the unanchored `cli:(cdocs-)?graphify ` matches any `Bash` command containing `graphify ` followed by a space, such as `command -v graphify >/dev/null`, which iterate's Turn-0 rule invites.
Use `cli:^(cdocs-)?graphify ` as the ablation's `--tool` already does.

## Verdict

**Accept.**
The revision applies the steering correctly and the rename is complete.
None of the findings reopens a decision.
F3 and F5 prevent results that would be misread (a non-discriminating ablation; a stub run that fails for a `PATH` reason), so apply them before those runs; the rest are wording and trims.

## Action Items

1. [non-blocking, before the ablate run] Move the ablation to a weftwise task with cross-import recall and no single grep-able literal, deleting the clauthier task and the "repeat on weftwise" clause; or keep clauthier as a smoke test and delete the decision branches it cannot trigger. Either way, drop the `inject-rules.ts` claim (F3).
2. [non-blocking] Reword the arm-difference bullet so Step 0 records the two prompt lines as the treatment (F4).
3. [non-blocking, before Phase 5] Make `cdocs-graphify` resolvable for the dispatched reviewer: run after Phases 2-3 are in main's tree, or symlink the branch script next to the stub (F5).
4. [non-blocking] `/cdocs:rfp` step: condition on an existing main graph, and say "in the main checkout" (F6).
5. [non-blocking] Overseer-clean check: `cli:^(cdocs-)?graphify ` (F7).
6. [non-blocking] Replacement table: add the rule file, devlog `SKILL.md`, and new graphify `SKILL.md`, or mark it partial (F1).
7. [non-blocking] Trims: the 90% figure once, D9 to its unique point, the Edge Case hint bullet's repeated clause (F2).

## Questions for the maintainer

1. Where should the single ablation run?
   (a) A weftwise task with call-edge recall, the design's target (recommended);
   (b) clauthier, relabeled as a usage-and-cost smoke test;
   (c) as written.
2. Steering 11:45 put "not clear on how cdocs path is being ignored" and "an ablate seems like a good idea" in one sentence. Was the ablation meant to:
   (a) measure the base-query design as a whole, as the proposal reads it (recommended; the exclusion is checked mechanically by node counts);
   (b) measure the exclusion itself (graph with versus without the `cdocs/` line)?
3. The `/cdocs:rfp` refresh step:
   (a) keep it, conditioned on an existing main graph (recommended, since you asked for it);
   (b) drop it, since each worktree's first `update` already repairs a stale copy.
