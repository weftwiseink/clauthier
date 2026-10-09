---
review_of: cdocs/proposals/2026-10-08-graphify-overhaul.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T10:45:00-07:00
task_list: cdocs/graphify-overhaul
type: review
state: archived
status: done
tags: [fresh_agent, runtime_validated, minimalism, graphify, test_plan, verification_design]
---

# Review: Graphify overhaul implementation, round 1

> BLUF: Revise, on one small blocker.
> The implementation matches the proposal, stays minimal (a 49-line wrapper replacing 362 lines), and passes every floor check I re-ran: the suites, the greps, `test:rules` and `test:opencode`, a fresh host stub run, and real graphify 0.9.61 in the container.
> The blocker is in the runtime-coupling scan, which reads the worktree's own `graph.json` when `query` runs from a subdirectory: graphify then prints an absolute graph path, and that file's `.observe()`/`.subscribe()` method labels show up as coupling hits and can crowd real sites out of the 30-line cap.
> The fix deletes one `^`.
> All four implementer deviations hold up.
> On the update stamp, I recommend keeping no stamp until the weftwise ablation has run.

## Summary Assessment

The round replaces overseer-run `graphify-scope` with `cdocs-graphify`, a per-worktree wrapper that code-reading agents run themselves, plus a thin skill, a rule bullet, base-query wiring, and a root-anchored `.graphifyignore`.
The code, skill text, and deletions match the proposal's Replacement table with no scope creep.
I confirmed by experiment that the wrapper never writes the shared index and that `/cdocs/` drops root `cdocs/` while keeping `plugins/cdocs/`.
One wrapper bug, which the fresh stub-run reviewer raised and I reproduced on real graphify, puts graph-file noise in the coupling section; the fix is one character plus a test.
Verdict: **Revise**.

## Verification (re-run by this reviewer)

`review_proof: confirmed`.
Artifacts were in the session scratchpad (`/tmp/claude-1000/-var-home-mjr-code-weft-clauthier-main/63ac45de-462d-4f43-ae1c-4ab6d59049b8/scratchpad/`: `ctest.out`, `stub-glog.txt`, `stub-report.txt`); excerpts are inlined below because the directory is ephemeral.

| Check | Result |
|---|---|
| `cdocs-graphify.test.sh` | exit 0, 21 passed, 0 failed |
| `chat-record.test.sh --unit` | exit 0, 97 passed |
| `validate-cdocs-edit-path.test.sh` | exit 0, 17 passed |
| Removal grep (`plugins/ .github/ CLAUDE.md scripts/`) | 0 hits |
| `grep -rn graphify_query plugins/ CLAUDE.md` | 0 hits |
| `npm run test:rules` / `npm run test:opencode` | 11/11, 8/8; `build/cdocs/opencode/skills/graphify/SKILL.md` exists |
| `shellcheck`, size | clean; wrapper 49 lines, test 82 |

**Host stub run** (the proposal's methodology, with one change that removes the implementer's main confound).
A headless `claude -p --plugin-dir <repo>/plugins/cdocs` opus overseer ran with a sandbox `CLAUDE_CONFIG_DIR`, `CDOCS_CHAT_RECORD=off`, `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`, `GRAPHIFY_OUT=<sandbox>/maingraph`, and a 30-minute self-expiring marker stub on that session's `PATH` only.
Its working repo was a `git archive` of `293f449` initialized as a fresh repo on `main`, so the reviewer's `isolation: "worktree"` checkout was the branch's own content rather than the older `ec948c4`.
This also avoided any VCS mutation of the clauthier repo.
The overseer dispatched one foreground `cdocs:reviewer` with `graphify_base_query: "how does cdocs-graphify copy the main graph into a worktree index, run graphify update, and pass queries through to graphify"`.
I deleted the sandbox, including its credential copy, afterwards; `command -v graphify` on the host is empty.

| Check | Result |
|---|---|
| Primary: stub log | pass: exactly two lines, `update` then `query` (below) |
| Secondary: `detect-usage --tool 'cli:cdocs-graphify (query\|explain\|path)'` on the reviewer transcript | `used` |
| Positive control | the overseer's single `Agent` `tool_use` (`cdocs:reviewer`, `isolation: worktree`) has a `tool_result` holding the reviewer's report |
| Overseer clean: `grep -c GFY-MARKER-…` on the overseer transcript | `0` (reviewer transcript: `3`) |
| Overseer clean: `detect-usage --tool 'cli:^(cdocs-)?graphify '` on the overseer transcript | `unused` (but see finding 4: this signature also reports `unused` on the reviewer transcript) |
| Fixture main graph | `cksum` unchanged |

```
<update><<SB>/repo/.claude/worktrees/agent-a43c114faa677ced1> OUT=<SB>/repo/.claude/worktrees/agent-a43c114faa677ced1/graphify-out ...
<query><how does cdocs-graphify copy the main graph into a worktree index, run graphify update, and pass queries through to graphify><--graph><<SB>/repo/.claude/worktrees/agent-a43c114faa677ced1/graphify-out/graph.json> OUT=<SB>/repo/.claude/worktrees/agent-a43c114faa677ced1/graphify-out ...
```

Reviewer behavior (n=1, adding to the implementer's n=1): it ran the base query as its 4th tool call, after one orientation command and reads of the target devlog and the wrapper it was asked to review.
It did not read the stub source, never loaded `/cdocs:graphify`, and never ran `explain` or `path`.
In both runs, the prompt line got the base query run, and neither run's reviewer used the skill's role procedure.
Its verdict was Revise, with the blocker below.
I did not repeat the no-op run.

**Real graphify 0.9.61 (container `clauthier`, temporary `git archive` copies under `/tmp`, removed afterwards).**

| Check | Result |
|---|---|
| Copy plus update from `GRAPHIFY_OUT=/var/cache/graphify` | worktree index created, `.gitignore` is `*`, `git status` clean, `.graphify_root` rewritten to the copy's root |
| Shared index | file list, sizes, mtimes, and directory mtime identical before and after all runs (`SHARED-UNCHANGED`) |
| `/cdocs/` | 736 nodes, 0 root `cdocs/`, 488 `plugins/cdocs/` |
| unanchored `cdocs/` | 248 nodes, 0 root `cdocs/`, **0** `plugins/cdocs/`; hint fires |
| no line | 7458 nodes, 6722 root `cdocs/`, 488 `plugins/cdocs/`; hint fires |
| back to `/cdocs/` | plain `update` restores 736 / 0 / 488 |
| `explain "cdocs-graphify"` | rc 1, `Ambiguous: ... matches 3 nodes`, lists ids (the skill's added line matches) |
| Timing, clauthier | `update` 0.41 s, warm wrapper call 0.56 s |
| Timing, weftwise `864a2789` (archive), `update` | `/cdocs/`: cold 11.9 s, warm no-change 10.4 s and 10.2 s (16129 nodes); no line: warm 34.0 s (49953 nodes, 33822 under `cdocs/`) |

> NOTE(claude-opus-5-5/cdocs/graphify-overhaul): `/var/cache/graphify`'s directory mtime is 10:23 today, and `graph.json` is unchanged since 09-23.
> Something was created and removed in the shared dir at 10:23, which fits a pre-`bcd1491` passthrough inheriting `GRAPHIFY_OUT`.
> After `bcd1491`, my runs left it bit-identical, so the fix is needed and it works.

## Section-by-Section Findings

### 1. `cdocs-graphify` runtime-coupling scan (blocking)

`plugins/cdocs/bin/cdocs-graphify:44` excludes index paths with `grep -v '^graphify-out/'`.
From the worktree root, `query`'s header names `graphify-out/graph.json`, so the filter works.
From a subdirectory, graphify prints the absolute `--graph` path (`Graph: /tmp/cgfy-review3.../graphify-out/graph.json (736 nodes)`).
The filter keeps it, `[ -f ]` passes, and the scan greps the graph itself.
Reproduced on 0.9.61 with a two-file TS fixture, run from `src/`:

```
RUNTIME COUPLING (not in the graph):
/tmp/cgfy-review4.Ikm3av/graphify-out/graph.json:21:      "label": ".observe()",
/tmp/cgfy-review4.Ikm3av/graphify-out/graph.json:27:      "norm_label": ".observe()",
/tmp/cgfy-review4.Ikm3av/graphify-out/graph.json:33:      "label": ".subscribe()",
/tmp/cgfy-review4.Ikm3av/graphify-out/graph.json:39:      "norm_label": ".subscribe()",
src/lib/view.ts:3:  s.observe(() => {})
src/lib/view.ts:4:  s.subscribe(() => {})
```

graphify labels methods `.observe()`, so every such method node puts two lines into the section.
Under the container's locale the absolute path sorted first, as above, so in weftwise these lines can take the 30-line cap before any real site; under other locales they are noise in the section either way.
`graph.json` is pretty-printed, which rules out the stub-run reviewer's whole-file-on-one-line worry.
Fix: drop the anchor, `grep -v 'graphify-out/'`, and add one test that names `$WT/graphify-out/graph.json` (holding `.observe()`) in stub output and expects no coupling hit from it.
Running the passthrough from `$top` would also work, but it changes how relative arguments are read and adds code.

### 2. Implementer deviations

1. **`/cdocs/` anchored: correct.** The container numbers above (0 versus 488 `plugins/cdocs/` nodes) settle it.
   The follow-through is incomplete (finding 3).
2. **Headless `claude -p` overseer: acceptable, arguably stronger.** It puts the branch's rules and plugin in the agents' context, which a subagent of a main-checkout session cannot do.
   My `git archive` variant also removes the `ec948c4` worktree-base confound.
3. **Stub-run wrapper fixes (`93cfc5f`, `bcd1491`): correct.**
   The race cleanup (`rm -rf "$tmp" "$wt_out/${tmp##*/}"`), the dated-backup drop, and the partial-index message read correctly.
   The `bcd1491` passthrough `GRAPHIFY_OUT` is demonstrably needed (NOTE above).
   The partial-index skip has no test, which is acceptable.
4. **Extras: keep both.** The usage guard (exit 2) stops agents from tunnelling `update`, `install`, or `claude install` through the wrapper, for 4 lines.
   The `explain` ambiguity line matches real 0.9.61 output.

### 3. `.graphifyignore` check: init and wrapper disagree (non-blocking)

`init/SKILL.md` step 7 guards with `grep -qxE '/?cdocs/?'`, while the wrapper's hint requires `/cdocs/?`.
A repo with an unanchored `cdocs/` line gets the hint "run /cdocs:init" on every call, and init then does nothing (verified: the file stays `cdocs/`, the hint still fires).
That repo also loses any nested `cdocs` directory from the graph, and the proposal's own weftwise prerequisite (line 384) tells that workstream to write exactly `cdocs/`.
Fix: change init's guard to `'/cdocs/?'`, one character removed.
The implementer devlog's Phase 2 WARN still says "the wrapper's hint check accepts either form", which has been stale since `93cfc5f`.

### 4. Proposal text after the deviation (non-blocking)

The proposal still prescribes an unanchored `cdocs/` in the BLUF, the wrapper table, the sketch (`'/?cdocs/?'`), "How `cdocs/` is kept out", the Replacement table, the Test Plan, and the weftwise Environment bullet.
Following writing conventions, add one NOTE under "How `cdocs/` is kept out of the graph" (line is `/cdocs/`; an unanchored `cdocs/` drops `plugins/cdocs/`) instead of rewriting.
The weftwise Environment bullet especially needs this, because a separate workstream acts on it.

### 5. `detect-usage` signature misses prefixed calls (non-blocking here, fix before the ablation)

The reviewer ran `timeout 60 cdocs-graphify query ...`.
The proposal's signature `cli:^(cdocs-)?graphify ` anchors at segment start, so it reports `unused` on the reviewer transcript, where the wrapper was used.
In this round, the marker count (`0`) is the authoritative overseer-clean check and it passed.
In the weftwise ablation, the same signature confirms the unassisted arm's withhold, so a `timeout`-prefixed call there would be counted as a clean VALID instead of VOID.
Tested replacement: `cli:(^|[ /])(cdocs-)?graphify (query|explain|path|affected|update) `, which matches `timeout 60 cdocs-graphify query`, `/p/bin/cdocs-graphify path`, and `cd /w && graphify explain`, and does not match `grep -rn "graphify " plugins/` or `grep -rn cdocs-graphify plugins/`.
Record it in a NOTE under the proposal's Ablation run "Signature" bullet.

### 6. Text that can go (non-blocking)

- `plugins/cdocs/bin/README.md` "A coupling section" example (about 8 lines): it is the only `.observe(` site in clauthier's graphed files, so every clauthier query that reaches `bin/README.md` appends `plugins/cdocs/bin/README.md:103:src/a.ts:1:a.observe(cb)` (seen in the container).
  The "What it does" bullet already describes the section.
- Optional, zero net lines: write `"$tmp/.gitignore"` before the `cp -R` so an interrupted copy leaves a self-ignored `graphify-out.tmp.*` rather than an untracked directory.
  The `.gitignore` entry `graphify-out/` does not match that name.

### 7. Skill, rule, iterate, devlog, reviewer.md (no findings)

The rule bullet is verbatim from the proposal, and its `CDocs Tool Use Guidance › Tools and Skills` reference resolves (`test:rules`).
The iterate "Base query" section is four lines and does not repeat the rule.
The brief section is gone from `reviewer.md` and no other agent or skill names graphify, matching D6.
The devlog and iterate templates are renamed, and the init step is guarded as proposed.
The skill matches the draft plus one line that real output supports.

### 8. Update cost: stamp or no stamp (recommendation)

Measured: about 10.3 s per no-change call at weftwise scale, about 0.4 s in clauthier.
A content stamp's inputs (`git rev-parse HEAD`, `git diff HEAD`, checksums of untracked non-ignored files) take about 10 ms in weftwise.
A stamp is exact rather than heuristic, unlike the porcelain stamp the proposal rejected, and costs about 2 net lines:

```bash
st=$( { git rev-parse HEAD; git diff HEAD; git ls-files -oz --exclude-standard | xargs -0 cksum; } 2>/dev/null | cksum)
[ "$st" = "$(cat "$wt_out/.stamp" 2>/dev/null)" ] ||
  { GRAPHIFY_OUT="$wt_out" graphify update "$top" >"$wt_out/update.log" 2>&1 && echo "$st" >"$wt_out/.stamp"; } ||
  note "update failed (graphify-out/update.log); querying existing index"
```

Add `.stamp` to the copy's `rm -rf` list too.

**Recommendation: keep no stamp (current) for now.**
The cost is wall time only, never tokens, and `ablate`'s `duration_ms` is indicative-only and never drives a verdict, so the weftwise ablation is not confounded by it.
That ablation decides whether overseers keep writing base queries by default.
If it demotes the base query to opt-in, wrapper calls become rare and the stamp would be code without a payoff.
If it keeps the design, reviewers are mostly repeat callers that never edit, so each reviewer would waste about 10 s per call after the first, and the stamp above earns its 2 lines.
Revisit then, not now.

## Verdict

**Revise.**
Fix the coupling-scan anchor and add its test (finding 1).
Everything else is non-blocking, and most of it is one-line or removal edits that fit the same round.
The weftwise ablation remains an open item routed to the overseer, not a failure of this round.

## Action Items

1. [blocking] `plugins/cdocs/bin/cdocs-graphify:44`: change `grep -v '^graphify-out/'` to `grep -v 'graphify-out/'`; add a `cdocs-graphify.test.sh` case where stub output names the absolute `$WT/graphify-out/graph.json` containing `.observe()` and the coupling section stays absent.
2. [non-blocking] `plugins/cdocs/skills/init/SKILL.md` step 7: guard with `grep -qxE '/cdocs/?'` so init fixes what the wrapper's hint flags; correct the devlog's Phase 2 WARN line "accepts either form".
3. [non-blocking] Proposal: one NOTE under "How `cdocs/` is kept out of the graph" that the line is `/cdocs/` (and why), so the weftwise workstream writes the anchored form.
4. [non-blocking, before the ablation] Proposal: NOTE under the Ablation "Signature" bullet replacing `cli:^(cdocs-)?graphify ` with `cli:(^|[ /])(cdocs-)?graphify (query|explain|path|affected|update) `.
5. [non-blocking] Remove the "A coupling section" example from `plugins/cdocs/bin/README.md`.
6. [non-blocking, optional] Write the temp dir's `.gitignore` before `cp -R`.
7. [deferred] Update stamp: keep none; revisit with the snippet in finding 8 if the weftwise ablation keeps the design.

## Questions for the maintainer

1. Update stamp (finding 8):
   a. No stamp until the ablation decides (recommended).
   b. Add the content stamp now (about 2 lines; about 10 s saved per repeat call at weftwise scale).
2. Reviewers in both stub runs ran the handed base query and nothing else; neither loaded `/cdocs:graphify` or used `explain`/`path`. D6's fallback triggers only on skipping the base query. Should the weftwise ablation also record whether agents go beyond the base query?
   a. Yes, as a note in its scorecard, with no design change.
   b. No, the base query alone is the contract.
