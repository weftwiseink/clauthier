---
review_of: cdocs/proposals/2026-09-22-haiku-bash-wrapper.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T12:06:33-07:00
task_list: meta/token-spend-attribution
type: review
state: live
status: done
tags: [fresh_agent, verification, implementation, live_canary, runtime_validated, completeness, overcorrection, no_spec_default, wording_balance]
---

# Review: Bash-Output Wrapper, Completeness-First Revision (r2 Verification)

> BLUF(opus-5-5/haiku-bash-wrapper-impl-final-r2): **Revise (one sentence).**
> All 17 action items from the prior review are applied faithfully, the text is balanced, and nothing overcorrects.
> Spec'd runs list 17/17, 45/45 and 49/49 exactly, as command output, at 1.7-8.2K.
> Pass/fail and passing runs stay under 1K.
> The one blocking gap: with **no spec** and **45** failures, 2 of 3 runs named **none** of the failing tests.
> The cause is that the ~12K allowance is keyed only to a spec that says "every".
> A two-clause patch, tested live on a scratch copy, fixes it in 3 of 3 runs.

## Summary Assessment

This round checks that the completeness-first revision (`786985a`, `54f040c`, `b6818e7`, and the proposal edits swept into `bde47b3`) applies the prior review's 17 action items without overcorrecting.
The text now leads with containment without loss, mentions report size once as a default, and names self-capture as the caller's first cheap path.
It keeps every fidelity rule from r6-r8.
Live canaries ([`_verify/2026-10-05-bash-runner-quality-canary-r2.md`](../devlogs/_verify/2026-10-05-bash-runner-quality-canary-r2.md), 18 runs) confirm that the spec'd path works and that size discipline holds when no list is asked for.
The no-spec default still fails at scale, so the verdict is **Revise** with one blocking wording fix whose wording is already verified; everything else is a nit.

## Canary Results

| run | case | report chars | complete and correct vs ground truth |
|---|---|---|---|
| A1 | 17 failures, "every failing test" spec | 3,642 | 17/17 exact |
| A2 | same | 5,467 | 17/17 exact in `Summary:`; `Excerpt:` locations off by one row (runner slip, disclosed) |
| E1 | 45 failures, same spec | 8,235 | 45/45 exact, labelled lines |
| E2 | same | 7,876 | 45/45 exact, labelled lines |
| B1 | 49 call sites, "complete list" | 1,772 | 49/49 set-exact |
| B2 | same | 1,746 | 49/49 set-exact |
| N1 | 17 failures, no spec | 4,127 | 17/17 exact |
| N1b | same | 2,244 | 17/17 name and location (values in `Truncated:`) |
| N2 | 45 failures, no spec | 1,557 | **0/45 names** |
| N2b | same | 1,724 | **0/45 names** |
| N2c | same | 7,734 | 45/45 name and values, 2/45 locations |
| O1 | 17 failures, "just pass/fail and count" | 815 | correct; no list dumped |
| P1 | all pass, no spec | 667 | correct |
| P2 | all pass, "pass/fail and totals" | 879 | correct |
| X1-X3 | 45 failures, no spec, **patched** copy | 3,795-4,993 | 45/45 name and location in 3/3 (X2 also exact values) |
| XP | all pass, no spec, **patched** copy | 646 | correct; the patch does not inflate passing runs |

## Section-by-Section Findings

### Check 1: the 17 action items

All 17 are applied, and applied faithfully.

| item | where | applied |
|---|---|---|
| 1 purpose | `bash-runner.md` L12-14 | verbatim |
| 2 answer the spec completely | L81-83, first Step 3 bullet | verbatim |
| 3 Summary / Excerpt / command-built lines | L89, L91, L95 | verbatim |
| 4 no-spec default | L84, its own bullet (an improvement: the Input pointer lands on it) | verbatim |
| 5 aggregate sizing; delete the arithmetic | L97-101; the 20/12/120/4,000 arithmetic is gone | yes |
| 6 size | L114-116 | verbatim, 12K per Question A (a) |
| 7 `description` | L4 | verbatim; the built OC agent carries it |
| 8 `grep -n` | L96 | verbatim |
| 9 haiku-era lines | prompt-copy disclaimer and `(such as "1 each: ...")` removed | yes |
| 10 Status flags | L87-88 | verbatim |
| 11 pipes, not temp files | L77 | verbatim; no runner wrote a temp file in 18 runs |
| 12 honest `Truncated:` | L109 | verbatim (but see N2 below) |
| 13 self-capture | `orchestration-discipline.md` L211 | yes, with `<file>` instead of `/tmp/<name>.log`, which is better |
| 14 dispatch test | L215-216 | verbatim |
| 15 dispatch contract | L226-230; runner internals removed | verbatim |
| 16 model-tiering / AGENTS.md | `model-tiering.md` L25-26, `plugins/cdocs/AGENTS.md` L47 | verbatim |
| 17 completeness probe | proposal Test Plan, Verification Methodology, Phase 1 success criteria | yes |

The proposal's design sections are synchronized too: input contract, output contract, dispatch scope, edge cases, a new "Completeness over brevity" decision, and a dated NOTE recording the maintainer's three defaults.
`plugins/cdocs/README.md` needed no change.
No materialized rule copies are tracked in this repo.

### Check 2: balance, contradictions, leftovers

**Balance is right.**
Completeness is in the first paragraph and the first Step 3 bullet.
Size appears once, in Output Format, as "usually", with a stated exception.
The caller section opens with "without losing relevant information" and asks for "every" when completeness is needed.
The implementer removed size admonitions rather than adding counterweights, which is the minimal-design choice.

**F1 (nit): item 12's wording literally contradicts `Truncated:`'s purpose.**
L109 says "Never list as omitted something you did not report at all".
Read literally, that forbids naming anything of which none was reported, which is exactly what L106 asks `Truncated:` to name.
The intent was narrower: do not imply partial coverage ("names beyond the first 13") when there was none.
Runners mostly read it as intended: N2b, N1b, N2c and X1 all disclosed honestly.
N2 still invented "Tests were cut to the first 3 locations".
Suggested: "Describe omissions exactly: never imply part of something was reported (for example 'beyond the first 13') when none of it was."

**F2 (nit): "no headings, labels, or composed lines" in `Excerpt:` (L94) sits awkwardly with labelled per-item lines.**
The labelled lines are encouraged at L81, L95 and L116 ("never ... unlabelled shorthand"), and the proposal calls them "one labelled line per item".
Field labels produced by an `awk` are command output, and runners understood that (A1, E1, E2, X2), so this is clarity only.
Suggested: "no headings or hand-written lines".

**F3 (nit): the aggregate bullet repeats the general Excerpt rule.**
L102 ("Do not hand-cut lines ... add headings or composed lines inside `Excerpt:`") restates L92-94.
It is harmless, but it is the one remaining duplication in the contract.

**F4 (nit): two proposal NOTEs read as current guidance against the new defaults.**
L175 says "the concise fixed-format report stay[s] mandatory".
L179 says "keeps the verbatim part small enough to copy accurately".
The L194 NOTE already got a "(refined by the completeness-first NOTE above)" parenthetical, and these two need the same pointer.
The proposal's `Full output:` placeholder `(<K> chars)` also lags the agent's `(<bytes> chars, <lines> lines; <lifetime>)`, and the 200-char `Command:` cut has the same lag (pre-existing).

**No haiku-era scaffolding remains** in the agent or the rules.
The haiku references left in `model-tiering.md`, `AGENTS.md` and `workflow-patterns.md` belong to `nit-fix`.

### Check 3: overcorrection

**None observed on the spec'd or passing paths.**
O1 asked only for pass/fail and a count on a 17-failure run and got 815 chars, with the list one `see:` away.
P1, P2 and XP (passing runs) returned 0.6-0.9K of totals.
E1 and E2, the largest spec'd lists, came in at 7.9-8.2K, inside the ~12K allowance and below a quarter of the 68.5K raw output.
The ~4K default still governs when no list is asked for.

**Caller guidance still keeps big output out of the lead's context.**
Self-capture reads `tail -n 20` plus a targeted `grep -n -C3`.
Dispatch is reserved for a distillation.
Line-by-line needs are read "in pieces".
The follow-up path is a bounded read or a narrower re-dispatch, never the raw dump.
Nothing in the section invites pulling a capture whole.

### Check 4: the no-spec default at scale (blocking)

**F5 (major, blocking): with no spec, a run with many failures still drops the failure list.**
At 17 failures the no-spec default works: N1 and N1b named 17/17.
At 45 failures, N2 and N2b named 0/45 after only 3 Bash calls, and N2c named 45/45 but gave only 2 locations.
The text has a gap.
The no-spec bullet (L84) asks for "each distinct error or failing test", but the ~12K allowance (L115) applies only "when the spec asks for a complete list".
At 45 lines a no-spec report cannot meet both the bullet and the "usually under about 4,000" default, and 2 of 3 runs resolved that by dropping the list.
This is the r1 N1 failure again, moved to a higher failure count.
Callers are told to pass a spec "for anything you will act on", so the no-spec path is a fallback, but it is the fallback for exactly the case the prior review's F3 targeted.

The fix was tested live on a scratch copy of the plugin (the committed file is untouched):
- L84: "...for a failing build or test run, **every** distinct error or failing test (name, location, message), one line each, **built as a complete list (the complete-list size in Output Format applies)**; ..."
- L115: "When the spec asks for a complete list ("every", "all"), **or a failing run with no spec lists its failures**, include all of it up to about 12,000 characters; ..."

Patched results: X1, X2 and X3 named 45/45 with correct locations, at 3.8-5.0K (X2 also gave exact actual and expected values).
XP, a passing run, stayed at 646 chars.
The proposal's input-contract sentence ("Absent an explicit salience spec ...") and its "Salience: default heuristic" test should get the same change.
The Test Plan's completeness probe should run its no-spec arm on a fixture whose list exceeds the ~4K default (about 40 or more failures): at 17 failures this regression is invisible.

### Runner slips (observations, no text change proposed)

- **A2** saw that its `awk` had shifted every location by one row.
  It pasted the wrong output anyway and hand-wrote a corrected 17-row list in `Summary:`, against L93's "to change what a line shows, change the command".
  The disclosure was honest and the corrected list was exact, but a caller skimming `Excerpt:` gets 16 wrong locations.
  If this recurs, add one clause to L93: "If a command's output is wrong, fix the command and run it again; never correct it in `Summary:`."
- **Summary miscounts:** B1 says "49 calls are in 30 files", where 24 is right. A2 says "7 files" and names 6.
  L90 already requires every number to be supported by the capture or a command, so this is model variance.
- **X3** printed `Truncated: none (... values ... were not extracted)`, which contradicts L107.

### Check 5: build

`npm run build:cdocs` exits 0 with `Agents converted: 7`.
The built `bash-runner.md` keeps `bash: true`, sets `read`/`edit`/`write: false`, and carries the new description.
The only warnings are the existing `Unknown CC tool "*"` skips and a Node `DEP0205` deprecation.

### Process note

`bde47b3` carries the proposal's completeness edits under a chat-record commit message.
The implementer recorded this in the devlog, and leaving shared history unrewritten under a live sibling session is the right call.
No action is needed beyond that NOTE.

## Verdict

**Revise.**
The revision achieves its goal.
With a spec, runners report every item exactly without bending the contract.
Without a list request they stay small.
The caller guidance keeps raw output out of the lead's context with no loss.
One wording gap lets the no-spec default drop a long failure list, which is the outcome this revision exists to prevent.
The fix is two clauses, already verified live.
With it applied, this should be an Accept with no further live round required beyond re-running the no-spec arm once.

## Action Items

1. [blocking] `bash-runner.md` L84 and L115: apply the two no-spec clauses quoted under F5 (verified: 3/3 runs at 45 failures named all 45, and a passing run stayed at 646 chars).
   Mirror the change in the proposal's input-contract sentence and in "Salience: default heuristic".
2. [non-blocking] Proposal Test Plan "Completeness probe": run the no-spec arm on a fixture whose failure list exceeds the ~4K default (for example 45 failures over 9 files), not only the 17-failure fixture.
3. [non-blocking] `bash-runner.md` L109: reword to "Describe omissions exactly: never imply part of something was reported (for example 'beyond the first 13') when none of it was." (F1)
4. [non-blocking] `bash-runner.md` L94: "no headings, labels, or composed lines" -> "no headings or hand-written lines". (F2)
5. [non-blocking] `bash-runner.md` L102: drop the sentence that repeats L92-94, or shorten it to "The rules for `Excerpt:` above apply to both commands". (F3)
6. [non-blocking] Proposal L175 and L179 NOTEs: add a "(refined by the completeness-first NOTE above)" pointer, as at L194. Sync the `Full output:` and `Command:` placeholders with the agent. (F4)
7. [non-blocking, conditional] If a later canary shows another A2-style slip, add to L93: "If a command's output is wrong, fix the command and run it again; never correct it in `Summary:`."

## Questions for the Maintainer

**A. Scope of the no-spec complete list (item 1):**
- (a) Failing builds and test runs only, as patched and tested. Recommended: it is where a caller most often skips the spec and most needs the names.
- (b) Any no-spec run with distinct errors, for example a linter or compiler emitting many diagnostics. This is broader, untested, and risks inflating noisy-but-passing runs.

**B. Must the no-spec list include the failure message (actual vs expected), or are name and location enough?**
- (a) Name and location are enough, with the message one `sed -n` away in `Truncated:`. That is what 2 of the 3 patched runs did, at about 3.8K. Recommended: the caller can act, and it keeps the default lean.
- (b) Require the message too: about 5K at 45 failures (X2), more for verbose assertion messages.
