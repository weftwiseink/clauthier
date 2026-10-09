---
review_of: cdocs/proposals/2026-10-08-graphify-overhaul.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T11:11:16-07:00
task_list: cdocs/graphify-overhaul
type: review
state: archived
status: done
tags: [rereview_agent, runtime_validated, minimalism, graphify, staleness_stamp, ablation]
---

# Review: Graphify overhaul implementation, round 2

> BLUF: Accept.
> F1-F5 are fixed, the rebase kept the interfacer text, and every floor check passes when I re-run it.
> The staleness stamp is correct for every case the brief lists, and on real graphify it cuts a no-op call at weftwise scale from about 11 s to 0.75 s, for 8 lines.
> It has one cost the proposal leaves out: the stamp hashes `HEAD`, so any commit triggers a full rebuild, even one that only commits code already graphed or a `cdocs/` devlog (11.1 s and 10.9 s at weftwise scale).
> D4's claim that devlog edits avoid rebuilds holds only until the devlog is committed.
> The remaining items are text fixes, two of which delete stale text.
> The ablation reading is sound; a multi-trial run belongs in a follow-up, because `/cdocs:ablate` cannot run one yet and rows 2 and 3 differ by one reversible iterate line.

## Summary Assessment

This round fixes impl-r1's findings, rebases onto `main`, adds the update staleness stamp from the performance audit, and records the weftwise ablation.
The code is small and correct, and the tests and my real-graphify runs agree with it.
The most important finding is the commit cost above, a gap in efficiency and in the docs rather than a correctness bug: the graph is never stale because of it.
There are no blocking issues, so the verdict is **Accept**; the action items are non-blocking and fit in one nit pass.

## Verification (re-run by this reviewer)

`review_proof: confirmed`.
Artifacts are in this session's scratchpad (`.../scratchpad/r2/`), which is ephemeral, so the excerpts below carry the results.

| Check | Result |
|---|---|
| `cdocs-graphify.test.sh` | exit 0, 26 passed, 0 failed |
| `chat-record.test.sh --unit` | exit 0, 97 passed |
| `validate-cdocs-edit-path.test.sh` | exit 0, 17 passed |
| Removal grep (`plugins/ .github/ CLAUDE.md scripts/`) | 0 hits; repo-wide, only historical `cdocs/` documents match |
| `grep -rn graphify_query plugins/ CLAUDE.md` | 0 hits |
| `npm run test:rules` / `npm run test:opencode` | 11/11, 9/9; `build/cdocs/opencode/skills/graphify/SKILL.md` rebuilt |
| `shellcheck`, size | clean; wrapper 57 lines, test 91 |
| `git status` | only the untracked `node_modules` symlink |

**Real graphify 0.9.61 (container `clauthier`).**
I extracted `git archive` copies into `/tmp/r2rev-*` and initialized each as a repo on `main`.
I built each scratch main graph with `GRAPHIFY_OUT=<scratch>/maingraph`, so no run read or wrote `/var/cache/graphify`; that directory's mtime and `graph.json`'s were unchanged before and after (10-08 10:23:22 and 09-23 13:37:52).
The scratch copies are deleted.

| Step | clauthier | weftwise `99475534`, current stamp | weftwise, base-relative variant (finding 2) |
|---|---|---|---|
| first call (copy + update) | 651 ms, update | 11013 ms, update | 11160 ms, update |
| unchanged (x3) | 168-193 ms, skip | 749-754 ms, skip | 752-759 ms, skip |
| untracked `cdocs/` edit | 163 ms, skip | 760 ms, skip | 768 ms, skip |
| tracked code edit | 592 ms, update | 11100 ms, update | 11081 ms, update |
| unchanged after edit | 170 ms, skip | 768 ms, skip | 745 ms, skip |
| commit of that already-graphed edit | **575 ms, update** | **11085 ms, update** | 782 ms, skip |
| commit of a `cdocs/`-only change | **614 ms, update** | **10935 ms, update** | 773 ms, skip |

F1 on real graphify, run from `plugins/cdocs/`: the header names the absolute `.../graphify-out/graph.json`, the coupling section lists the real `.observe(`/`.subscribe(` site, and 0 of its lines name `graph.json`.

**Stamp edge cases (host, graphify stub, `stamp-edge.sh`).** Updates per call, current wrapper:

| Case | Updates | Expected |
|---|---|---|
| first call; main graph holds a `.stamp` | 1; the copied `.stamp` is not main's | yes |
| no `.graphifyignore`: unchanged / `cdocs/` edit / revert | 0 / 1 / 1 | yes (nothing is ignored) |
| `/cdocs/` committed: tracked `cdocs/` edit, untracked `cdocs/` file | 0, 0 | yes |
| untracked code file; repeat edit; delete | 1, 1, 1 | yes |
| staged-only change; repeat edit to a dirty tracked file | 1, 1 | yes |
| HEAD move with a clean tree across a code commit | 1 | yes |
| HEAD move across a `cdocs/`-only commit; commit of graphed code; commit of `cdocs/` only | 1, 1, 1 | ideally 0 (finding 2) |
| repeat edit to a dirty non-ASCII-named file (`café.ts`) | **0** | 1 (finding 3) |
| failed update; next call; then unchanged | 1 (one stderr line), 1 (retry), 0 | yes |
| `.graphifyignore` deleted; then unchanged | 1 (and the hint), 0 | yes |

## Section-by-Section Findings

### 1. impl-r1 action items: all addressed

- **F1** (`a7db3b3`): `grep -v 'graphify-out/'` plus a test naming the absolute index path; confirmed on real graphify above.
- **F2** (`19332cb`): init's guard is `grep -qxE '/cdocs/?'`, matching the wrapper's hint.
- **F3** (`137f8e9`): NOTE under "How `cdocs/` is kept out of the graph"; the weftwise Environment bullet names `/cdocs/`.
- **F4** (`137f8e9`): the widened signature at all three proposal sites, with the NOTE under "Signature".
- **F5** (`f003b09`): the coupling example is gone; no `.observe(`/`.subscribe(` text remains in `plugins/` outside the test.
- Item 6 (write the temp `.gitignore` before `cp -R`) was held back; that is fine, since it was optional.

### 2. Stamp: commits always rebuild (non-blocking; text fix recommended)

The stamp hashes `git rev-parse HEAD`, so committing triggers a full rebuild even when the graphed tree is unchanged.
Agents in this workflow commit early and often, so an implementer that edits, queries, commits, and queries again pays the rebuild twice; a devlog commit costs the same.
D4 says that leaving `.graphifyignore` paths out means "a `cdocs/` devlog edit ... does not trigger a rebuild"; that is true only until the edit is committed.
Reviewers, who mostly commit once at the end, are barely affected.

Two options; I recommend (a):
- **(a) Fix the text (recommended).** In D4, after "any code edit, new file, or deletion does", add "and so does any commit, because the stamp includes `HEAD`".
  This keeps the stamp as the audit specified it; it is temporary anyway, since it goes once graphify gates `update` itself (devlog Future work 1).
- **(b) Make the stamp commit-invariant** by diffing against a base commit that the stamp records, rather than against `HEAD` (+1 line, 58 total; the suite passes 26/26 and shellcheck is clean; timings are in the table above):

  ```bash
  # Skip the refresh when the graphed tree, as a diff from the base commit the stamp records, is unchanged.
  base=$(git rev-parse -q --verify "$(cut -d' ' -f1 "$wt_out/.stamp" 2>/dev/null)^{commit}" || git rev-parse HEAD)
  stamp="$base "$(cd "$top" && {
    chg=$({ git -c core.quotePath=false diff "$base" --name-only; git -c core.quotePath=false ls-files -o --exclude-standard; } | sort -u)
    # ign line unchanged; drop `git rev-parse HEAD;` from the next line; the rest unchanged
  ```

  Cost: the base stays fixed until a copy or gc resets it, so the stamp's diff grows with the branch.
  Measured in weftwise: 22 ms at base `HEAD`, 130-180 ms at 100-300 commits back, 720 ms at 1000.
  That is fine for a per-workstream worktree, but it degrades for the container's long-lived `main` copy, and it adds state to a mechanism slated for removal.

### 3. Stamp: non-ASCII file names (non-blocking, optional)

With git's default `core.quotePath`, `git diff --name-only` and `ls-files` print non-ASCII names quoted (`"caf\303\251.ts"`).
Line 39's `[ -f "$f" ]` then fails, so only the name is hashed.
The first edit to such a file triggers an update, but further edits while it stays dirty do not, which leaves the graph stale.
Neither clauthier nor weftwise tracks any such path (0 quoted names in `git ls-files`), so this is theoretical.
The fix adds no lines: put `-c core.quotePath=false` on the two listing commands in line 36, as in (b).
Names containing `"`, `\`, or control characters stay quoted even then.
Also outside the stamp: `assume-unchanged`/`skip-worktree` files and graphify upgrades (the latter is already in the devlog's WARN).

### 4. Stamp: weighed against the maintainer's minimalism preference

There are 8 net lines (49 to 57), within the proposal's "about 60" cap.
They save about 10 s on every repeat call at weftwise scale, which matters for reviewers, the heaviest repeat callers, and costs tokens nowhere.
I found nothing to cut without losing a case the brief requires: the check-ignore pass is what keeps devlog edits from rebuilding, and the per-file `[ -f ]` loop is needed because `hash-object --stdin-paths` aborts on a deleted path.
`.stamp` in the copy's drop list costs no line; it is defensive, since only a host `main` checkout's index can hold one.
No test covers that drop or an untracked code file (`ls-files -o`); each would be a one-line case, and I do not require either.

### 5. Proposal and devlog text left stale by the stamp (non-blocking)

Proposal:
- Line 35 and D3 (line 274): "kept current by `graphify update` on every call": delete "on every call", or say "when the graphed tree changed".
- Test Plan (line 337): "Second call: no copy ...; `update` runs again" contradicts the implemented test ("second call, unchanged tree: no copy, no update").
  Change it to "no copy, no update", and add one bullet: an ignored `cdocs/` edit skips the update, a code edit runs it, and a failed update retries.
- The core sketch (line 141) still runs `update` unconditionally; the Stamp and Update rows of the step table now cover the behavior, so the sketch can stay as an illustration, or its `update` line can go.

Devlog (`2026-10-08-graphify-overhaul-impl.md`):
- The closing "Verification" section is two rounds stale: it shows the `bcd1491` floor (21 tests, 49 lines) and lists "the weftwise ablation (prerequisites unmet)" as unverified.
  Delete its floor block (the Round 3 floor supersedes it), and drop the ablation from its "Unverified" line.

### 6. Rebase (no findings)

`git diff main -- plugins/cdocs/agents/reviewer.md plugins/cdocs/skills/iterate/SKILL.md` shows only this branch's removals (the brief section, the flag, "Graphify scoping") and the "Base query" section; the interfacer text is intact in both files.
No graphify-scope reference remains outside historical `cdocs/` documents.
`main` has moved past this branch's base (`ebccbcc`) only in `cdocs/` files that the branch does not touch, so landing will be clean.

**D4's audit link.** `../reports/2026-10-08-graphify-update-performance-audit.md` does not resolve on the branch, and the devlog's link has the same problem.
This does not matter: the target is on `main` (`697b3df`), landing requires being current with `main` (`--ff-only`), and no CI step checks links.
It is dangling only for someone reading the branch on its own before it lands.

### 7. Weftwise ablation (no findings on the run; reading endorsed)

The run is clean.
The withhold held (`unused` on B), the overseer stayed clean, the shared graph's mtime was unchanged, the artifacts are committed, and the cleanup is recorded.

The implementer's reading is sound, and if anything slightly generous.
The evaluator credits graphify with only two or three tail entries (`tabs/list_ops.ts`, `tabs/types.ts`, the `atoms.ts:350` coupling line).
A's precision edge (0 versus 8 refuted entries) is not attributed to graphify.
A also missed the palette chain, whose files the graph output named.
The token delta is 2%, within noise.
So the result sits between rows 2 and 3 of the decision map, closer to 2 on substance.

Should a multi-trial run come before acceptance? No; it is a follow-up:
- The proposal itself makes the multi-file ablation "a follow-up, not a gate" (Summary NOTE).
- `/cdocs:ablate` does not run multiple trials yet: `--trials>1` is its deferred Phase 3, so the run means either building that or repeating single-shot runs and aggregating by hand.
- Rows 2 and 3 differ only in whether iterate writes `graphify_base_query` by default (one sentence in iterate's "Base query" section), and the wrapper, skill, and rule ship either way.
  The decision is cheap to reverse later.

The follow-up is worth recommending to the maintainer, with three changes:
1. Name the atom in the task (`currentDocumentRefAtom`) for both arms. A base query that names it under the current task would hand arm A part of the answer, since the task asks agents to find the most-imported atom.
2. Have weftwise's `.graphifyignore` exclude `_archive/` first: 3 of the base query's 11 start nodes were `_archive/` docs. Otherwise the run measures weftwise's ignore file as much as the design.
3. Run at least 3 trials per arm, once ablate Phase 3 exists.

## Verdict

**Accept.**
No blocking issues remain.
Finding 2's D4 text fix and finding 5's stale lines are worth doing before `implementation_accepted`, but none of them changes behavior.

## Action Items

1. [non-blocking] Proposal D4: add that any commit triggers a rebuild, because the stamp includes `HEAD` (finding 2a).
2. [non-blocking] Proposal line 35 and D3: drop "on every call"; Test Plan line 337: "no copy, no update", plus one stamp bullet.
3. [non-blocking] Devlog: delete the stale closing "Verification" floor block, and drop "the weftwise ablation (prerequisites unmet)" from its "Unverified" line.
4. [non-blocking, optional] `cdocs-graphify` line 36: `-c core.quotePath=false` on the `diff` and `ls-files` calls (finding 3).
5. [follow-up, maintainer] A multi-trial weftwise ablation, with the atom named in the task, `_archive/` ignored, and N ≥ 3 once ablate Phase 3 lands (finding 7).

## Questions for the maintainer

1. Commit-triggered rebuilds (finding 2):
   a. Keep the stamp as is and document the cost in D4 (recommended: no code, and the stamp is temporary).
   b. Adopt the base-relative stamp (+1 line; commits of graphed code or `cdocs/` stop rebuilding; the stamp's cost grows with distance from its base).
2. Weftwise ablation follow-up (finding 7):
   a. Accept now, and schedule the multi-trial run after ablate Phase 3, with the atom named and `_archive/` ignored (recommended).
   b. Hold `implementation_accepted` until a hand-aggregated three-run repeat settles row 2 against row 3.
   c. Take row 2 now: make the base query opt-in in iterate, and skip the follow-up.
