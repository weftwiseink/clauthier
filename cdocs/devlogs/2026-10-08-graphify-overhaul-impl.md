---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T10:16:00-07:00
task_list: cdocs/graphify-overhaul
type: devlog
state: live
status: review_ready
part_of: cdocs/devlogs/2026-10-08-graphify-overhaul.md
tags: [graphify, claude_skills]
---

# Graphify Overhaul Implementation: Devlog

> BLUF: Implementation of [`2026-10-08-graphify-overhaul.md`](../proposals/2026-10-08-graphify-overhaul.md) in worktree `graphify-overhaul`, rebased on `main`: Phases 1-5 done, the host stub run passes every check, and the weftwise ablation is VALID with `context_gap` +1 (single-shot, not gate-admissible).
> The wrapper gains the audit's staleness stamp (57 lines): a no-op query skips the about 10 s full rebuild, but the first query after a code edit still costs about 14 s until graphify fixes `update` upstream.
> Deviations: the ignore line is `/cdocs/` (an unanchored `cdocs/` drops `plugins/cdocs/`); the stub run and the ablation used headless branch-plugin overseers rather than subagent dispatchers.

## Objective

Implement the proposal: `cdocs-graphify` replaces `graphify-scope`, `/cdocs:graphify` skill and rule line, `graphify_base_query` wiring, prior proposal superseded, host stub verification, and the weftwise ablation once its container is ready.

## Scratchpoint

- next_steps: overseer's post-accept clauthier devcontainer live run and exclusion check; maintainer reads the ablation's decision-map row (Phase 5, "Weftwise ablation"); upstream graphify issues (Future work).
- graphify_base_query: "how does cdocs-graphify copy the main graph into a worktree index, stamp the graphed tree, run graphify update, and pass query explain path affected through to graphify"
- important_files: `plugins/cdocs/bin/cdocs-graphify`, `plugins/cdocs/hooks/tests/cdocs-graphify.test.sh`, `plugins/cdocs/skills/graphify/SKILL.md`, `plugins/cdocs/rules/tool-use-safeguards.md`, `plugins/cdocs/skills/iterate/SKILL.md` "Base query", `.graphifyignore`, `cdocs/_media/2026-10-08-graphify-ablation-weftwise-scorecard.md`
- callouts:
  - decision: dispatched mode; the overseer owns the top-level devlog.
  - decision: ignore line is `/cdocs/` (root-anchored), not `cdocs/`; see Phase 2.
  - decision: staleness stamp added per the coordinator after the perf audit (Round 3).
  - todo: upstream graphify issues for a manifest-gated no-op `update` and cached JS/TS work (Future work).
  - todo: the base query never matched `currentDocumentRefAtom` in the ablation; a refined query naming the atom is the implementer-refinement path the design relies on.

## Plan

1. Phase 1: time `update` and check output path formats against real graphify 0.9.61 in the `clauthier` container.
2. Phase 2: tests first, then `bin/cdocs-graphify`; delete old script and test; CI, READMEs, `.gitignore`, `.graphifyignore`.
3. Phase 3: skill, rename, rule line, devlog and iterate skills, reviewer, init, README, `CLAUDE.md`.
4. Phase 4: supersede notes on the two prior proposals.
5. Phase 5: host stub run; weftwise ablation if prerequisites pass.

## Testing Approach

TDD for the wrapper: `cdocs-graphify.test.sh` against a `graphify` stub, written before the script.
Docs changes are checked by the removal greps, `npm run test:rules`, and `npm run test:opencode`.
End-to-end behavior by the proposal's host stub run.

## Implementation Notes

### Phase 1: CLI reconciliation (graphify 0.9.61, `clauthier` container)

Both items confirmed; scratch dirs removed afterwards.

- **Output path formats** (tiny 3-file TS repo):
  - `query`: `NODE x [src=src/app/view.ts loc=L2 ...]`, `EDGE ... at=src/app/consumer.ts:L2`; header names `graphify-out/graph.json`.
  - `explain`: `Source:    src/lib/atoms.ts L2`, connections end `src/app/consumer.ts:L1`.
  - `affected`: `- useMount() [calls] src/app/consumer.ts:L2`.
  - `path`: labels only (`renderView() --calls [EXTRACTED]--> useMount()`), no file paths, so the coupling section never fires on `path`.
  - Extraction: `grep -oE '[A-Za-z0-9_./@+-]+\.[A-Za-z0-9]+'` yields the bare relative path from each form (`src=`, `at=`, `:L2` drop out); file-less labels such as `consumer.ts` are filtered by an existence test; `graphify-out/` paths are excluded.
- **`update` at weftwise scale** (`git archive` of weftwise `1caa585d`, 1228 TS files, 16129 nodes, in the `clauthier` container): cold 13.1 s, warm no-change 11.0 s, one-file edit 11.2 s; `--no-cluster` 10.7 s and strips communities, so it buys nothing.
- **Update prunes deleted files** without `--force` (7 nodes to 5), and writes a dated backup dir inside the output dir when the graph shrinks.

> WARN(claude-opus-5-5/cdocs/graphify-overhaul): The no-stamp default costs about 11 s on every `cdocs-graphify` call at weftwise scale (clauthier: about 2.4 s), since `update` walks the whole corpus even when nothing changed.
> Kept per the proposal; a content stamp (HEAD plus `git diff HEAD` plus untracked-file checksums) would make no-change calls free, at a few more wrapper lines.
> Maintainer decision.

> NOTE(claude-opus-5-5/cdocs/graphify-overhaul): weftwise's `docs/*.md` headings are graphed and surfaced as query start nodes (`Hooks [src=docs/style_guide.md]`) for the proposal's base query.
> The weftwise `.graphifyignore` may want more than `cdocs/`; not in this workstream's scope.

### Phase 2: `cdocs-graphify` replaces `graphify-scope`

- Tests first (`48d4a65`, 15 of 20 failing with no script), then the wrapper (`91b3c1a`): 20/20.
  Mutations each caught (dropping the `.graphify_root` delete, choosing the first worktree instead of branch `main`, zeroing the coupling cap, discarding the passthrough exit code).
- The fixture mirrors this repo: a bare repo with worktrees `aaa` (listed first), `main`, and `wt`.
- Passthrough writes to a `mktemp` file and `cat`s it, so stdout is byte-exact and the coupling grep reads the same bytes.
- Usage errors (subcommand not in `query|explain|path|affected`) exit 2: the proposal does not specify this case.
- Real graphify smoke test (container, this worktree, `GRAPHIFY_OUT=/var/cache/graphify` holding the stale 73-node fixture): copy + update + query 0.58 s, result identical in size to a fresh build (248 nodes), `/var/cache/graphify/graph.json` mtime unchanged, `git status` clean.

> WARN(claude-opus-5-5/cdocs/graphify-overhaul): Deviation: the ignore line is `/cdocs/`, not the proposal's `cdocs/`.
> In gitignore syntax an unanchored `cdocs/` matches a `cdocs` directory at any depth, so graphify dropped `plugins/cdocs/` entirely (0 of its nodes; graph 248 nodes).
> With `/cdocs/`: 732 nodes, 484 under `plugins/cdocs/`, 0 under root `cdocs/`, and a plain `update` on the existing worktree index restored them.
> The wrapper's hint and init's guard both require the anchored form (`/cdocs/?`), so an unanchored `cdocs/` line draws the hint and init adds `/cdocs/`.

### Phase 3: base-query wiring

- iterate: flag and "Graphify scoping" replaced by a four-line "Base query" section; reviewer brief section dropped; Scratchpoint field renamed in both templates and defined in the devlog skill; rule bullet replaced verbatim from the proposal.
- `/cdocs:graphify` skill is the proposal's draft plus one line from the smoke test: `explain` on an ambiguous name (`cdocs-graphify` matched a README heading and the script) lists ids, so the skill says to rerun with one.
- init step 7 writes `/cdocs/` behind the proposal's guard; running the snippet twice on a file holding `dist/` left exactly one `/cdocs/` line.
- No other skill or agent names graphify (propose, propose-revise, full-send, oversee, implement, review, agents), per D6.

### Phase 4: supersede the prior proposal

- `2026-09-17-graphify-cdocs-integration.md`: `status: evolved`, `state: archived`, NOTE under the title (coupling guard kept, near-empty fallback dropped).
- `2026-09-17-graphify-lace-devcontainer-enablement.md`: NOTE after D3 (agents never write the shared index).
- `cdocs:triage` on both: 0 frontmatter issues, 0 fixes, no status recommendations.

### Phase 5: verification

**Host stub run** (headless, after Phases 1-4 at `f392af7`; script and sandbox in the session scratchpad, removed afterwards).

> NOTE(claude-opus-5-5/cdocs/graphify-overhaul): Deviation from the Verification Methodology's mechanics, same checks.
> The dispatcher is a headless `claude -p --plugin-dir <branch>/plugins/cdocs` top-level session (opus, sandboxed `CLAUDE_CONFIG_DIR` with credential copies, `CDOCS_CHAT_RECORD=off`, `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`) in a detached worktree of this branch, acting as overseer, rather than a subagent of this session.
> That puts the branch's rules, skill, and plugin in the agents' context; this session's own plugin is the main checkout's.
> The stub and the `cdocs-graphify` symlink sit in a sandbox `bin/` prepended to that session's `PATH` (the main checkout's plugin `bin/` dropped), not in `~/.local/bin`, so nothing leaks to concurrent sessions; the stub still self-expired at 30 minutes.
> The fixture main graph is `GRAPHIFY_OUT=<sandbox>/maingraph` (the container's shape) rather than `main/graphify-out/`, so this dispatched implementer writes nothing into the `main` checkout.

The dispatcher sent a foreground `cdocs:reviewer` with `isolation: "worktree"` the prompt "Review cdocs/devlogs/2026-10-08-graphify-overhaul-impl.md ... focusing on its Phase 2 section" plus `graphify_base_query: "how does cdocs-graphify copy the main graph into a worktree index and pass queries through to graphify"`.

| Check | Result |
|---|---|
| Primary: stub log | pass: exactly 2 lines, `<update></…/.bare/.claude/worktrees/agent-aa4c…>` with `OUT=<that worktree>/graphify-out`, then `<query><base query><--graph><that worktree>/graphify-out/graph.json>` |
| Secondary: `detect-usage --tool 'cli:cdocs-graphify (query\|explain\|path)'` on the reviewer transcript | `used` |
| Positive control: dispatcher transcript | the `Agent` `tool_use` (`isolation: worktree`, prompt carries the base query) has a `tool_result` holding the reviewer's report |
| Overseer clean: `grep -c GFY-MARKER` on the dispatcher transcript | `0` (reviewer transcript: 2) |
| Overseer clean: `detect-usage --tool 'cli:^(cdocs-)?graphify '` on the dispatcher transcript | `unused` |
| Fixture main graph | `cksum` unchanged |
| No-op run (stub and fixture removed, wrapper still on `PATH`) | reviewer completed (verdict returned); no install, pip, pipx, or build command; ran `command -v graphify` once and never called the wrapper; its review mentions graphify's absence in 0 lines |

No failure picture appeared: the base query ran, no marker reached the dispatcher, the shared fixture was not written, and the no-op run made no install attempt.

> WARN(claude-opus-5-5/cdocs/graphify-overhaul): Confounds, so read the primary pass as "an agent handed the line runs it", not "at startup, cleanly".
> - The harness based both reviewer isolation worktrees on `ec948c4` (an older `main`), not on this branch, under `.bare/.claude/worktrees/`; the target devlog was absent there, so each reviewer read it via `git show f392af7:` and the sandbox path.
> - The primary reviewer spent 4 commands orienting, including `head -20` of the stub's own source (which holds the marker), before running the base query as its 5th command; it never loaded `/cdocs:graphify` via the Skill tool.
> - One trial each (n=1).

Both stub-run reviewers (independently, `f392af7`) returned Revise with wrapper findings, all applied: an unanchored `cdocs/` line drew no hint; a lost rename race nested the temp dir and a partial `graphify-out/` skipped forever without naming the fix; dated backup dirs were copied (`93cfc5f`); passthrough inherited the container's `GRAPHIFY_OUT` (`bcd1491`).
Not applied, reported to the overseer: the `main` branch name is fixed (repos on `master` need `GRAPHIFY_OUT`, per the proposal), and the 30-hit coupling cap has no truncation marker.
Their review files lived only in the throwaway worktrees and were deleted with them; they are test artifacts, not loop reviews.

Final wrapper re-smoked against real graphify 0.9.61 in the container: query 0.8 s, `explain` by the ambiguous name's id works, `/var/cache/graphify/graph.json` mtime unchanged, the copied dated backup dropped, 0 root `cdocs/` nodes, `graphify-out/` removed afterwards.

**Weftwise ablation: not run.** Prerequisite check at 10:30: `podman exec -u node weftwise graphify --version` fails (`command not found`), `GRAPHIFY_OUT` is unset, the container is 5 weeks old (not yet rebuilt by the separate workstream).
Per the overseer's instruction, reported back rather than skipped or moved.

**Routed to the overseer (post-accept):** the clauthier devcontainer live run and the exclusion check.

### Round 2: rebase and impl-r1 fixes

Review: [`2026-10-08-review-of-graphify-overhaul-impl-r1.md`](../reviews/2026-10-08-review-of-graphify-overhaul-impl-r1.md) (revise, `review_proof: confirmed`).

- **Rebase** onto `main` (`ebccbcc`, which includes the interfacer landing `70e48fc`): all 24 commits applied with no conflicts.
  Git's three-way merge kept both sides in `plugins/cdocs/agents/reviewer.md` (interfacer text present, graphify brief section absent) and `plugins/cdocs/skills/iterate/SKILL.md` (interfacer text present, "Base query" present, no `--graphify-scope`); the removal and `graphify_query` greps stayed at 0.
- **F1 (blocking):** coupling filter is `grep -v 'graphify-out/'`, so an absolute graph path (graphify prints one when `query` runs from a subdirectory) is not scanned; new test case with `.observe()` in the worktree's `graph.json` named by absolute path (failed before the fix, 21/22).
  Real graphify from `plugins/cdocs/`: header names the absolute graph path, 0 coupling lines naming `graph.json`, `/var/cache/graphify` dir mtime unchanged.
- **F2:** init's guard is `grep -qxE '/cdocs/?'`; on a file holding `cdocs/`, two runs leave `cdocs/` plus exactly one `/cdocs/`.
- **F3:** proposal NOTE under "How `cdocs/` is kept out of the graph"; weftwise Environment bullet names the anchored `/cdocs/` line.
- **F4:** ablation and overseer-clean signature is `cli:(^|[ /])(cdocs-)?graphify (query|explain|path|affected|update) ` at all three proposal sites, with a NOTE under "Signature"; checked with `detect-usage`: `used` for `timeout 60 cdocs-graphify query`, `/p/bin/cdocs-graphify path`, `cd /w && graphify explain`, `cdocs-graphify affected`; `unused` for `grep -rn "graphify " plugins/`, `grep -rn cdocs-graphify plugins/`, `command -v graphify`.
  Reviews and this devlog's Phase 5 table keep the old signature because they record what was run.
- **F5:** "A coupling section" example removed from `bin/README.md`.
- Not done: impl-r1's optional item 6 (write the temp `.gitignore` before `cp -R`) and the update stamp, both held for the overseer's direction.

> NOTE(claude-opus-5-5/cdocs/graphify-overhaul): impl-r1 saw `/var/cache/graphify`'s directory mtime at 10:23.
> That fits this devlog's Phase 2 container smoke test (10:2x, pre-`bcd1491`), whose passthrough inherited `GRAPHIFY_OUT=/var/cache/graphify`; the Phase 2 note checked only `graph.json`'s mtime, which was unchanged.

### Round 3: weftwise ablation and the staleness stamp

**Weftwise ablation** (container `weftwise`, base `99475534`, at or after the `.graphifyignore` commit `0268293a`; hand-off read from weftwise `cdocs/devlogs/2026-10-08-graphify-devcontainer-feature.md`).

Prerequisites, checked first: `graphify --version` = 0.9.61; `$GRAPHIFY_OUT` = `/var/cache/graphify-weftwise`, `graph.json` 16129 nodes, 0 under `cdocs/`, 6058 under `_archive/`; the branch's `cdocs-graphify` was not on `PATH` (the container mounts clauthier `main`, not this worktree), so the branch's `plugins/cdocs` (`git archive` of `31cb617`) went to a container scratch dir whose `bin/` led `PATH`.

> NOTE(claude-opus-5-5/cdocs/graphify-overhaul): How it ran: a headless `claude -p --model opus --plugin-dir <scratch plugin>` session inside the container, with a sandbox `CLAUDE_CONFIG_DIR` holding credential copies and `CDOCS_CHAT_RECORD=off`, ran `/cdocs:ablate` as the top-level overseer the skill asks for.
> It dispatched two sonnet `general-purpose` arms (foreground) in detached worktrees under the scratch dir, and one opus evaluator.
> The evaluator got the coordinator's `affected` calibration (26 depth-1 files, all grep-confirmed; depth 2 adds 7 real re-export hops and about 43 false positives).
> Overseer deviation: it built the arm payloads from the dispatch usage summaries rather than a `toolUseResult` object; the token and tool-call counts come from those summaries.

| | Assisted (A) | Unassisted (B) |
|---|---|---|
| tokens | 64,362 | 65,870 (delta -1,508, corroborating only) |
| tool calls | 8 (Skill `cdocs:graphify`, then the base query as call 2, then grep and sed) | 5 (grep, cat, sed) |
| duration | 61.3 s | 32.3 s (indicative only; A's first call paid the copy plus an about 11 s update) |
| `detect-usage` (new signature) | `used` (re-run by me) | `unused` (re-run by me), so the withhold held |
| answer | 46 entries, 0 refuted by grep | 54 entries, 8 refuted by grep (for example `vite.config.ts`) |

- **Outcome: VALID**, `void_reason` null, **`context_gap` +1**, `gate_admissible: false` (single-shot).
- Evaluator: both arms found `currentDocumentRefAtom` and the same grep-driven core (about 27 importers, the layout facade, the `store.sub` mirror, derived atoms, the same tests).
  graphify added marginal tail entries (`tabs/list_ops.ts`, `tabs/types.ts`, and the coupling line `atoms.ts:350`); its output also named three relevant files A did not use, and A wrongly ruled the palette out, missing `currentMountIdAtom` -> last-visited mirror -> `palette/create_document.ts`, which B listed.
  Neither arm listed graphify's depth-2 false positives.
- First agent in any run to load `/cdocs:graphify` via the Skill tool; it ran only the base query, with no `explain`, `path`, or `affected`.
- `_archive/` crowding: the base query was truncated to 51 of 942 nodes, 3 of them `_archive/`, so crowding was mild; the worse problem was the start nodes (3 of 11 were `_archive/` docs, others a style guide and a test helper) and `currentDocumentRefAtom` never appeared.
- The dispatching overseer's transcript: `detect-usage` `unused` (re-run by me).
- `$GRAPHIFY_OUT/graph.json` mtime `2026-10-08 10:46:05.603399155 -0700` before and after.
- Artifacts: [`scorecard.md`](../_media/2026-10-08-graphify-ablation-weftwise-scorecard.md), [`scorecard.json`](../_media/2026-10-08-graphify-ablation-weftwise-scorecard.json), [`eval.json`](../_media/2026-10-08-graphify-ablation-weftwise-eval.json), [`step0.json`](../_media/2026-10-08-graphify-ablation-weftwise-step0.json); transcript paths inside them point at the deleted sandbox.
- Cleanup: both arm worktrees removed by `ablate.sh worktree-remove` and pruned; the scratch dir (plugin copy, credential copies, run dir, transcripts) deleted; weftwise `main` `git status` empty, no `gfy`/`tmp` worktrees from host or container.

**Decision-map row:** literally the third ("VALID with a positive `context_gap` ... keep the design; consider passing the base query to the judge too"), but on a +1 from one draw with a 2% token delta.

> WARN(claude-opus-5-5/cdocs/graphify-overhaul): Read this as "no harm, marginal help", not as evidence for the design.
> +1 is the smallest positive score, from a single draw (`gate_admissible: false`), and it sits next to the second row (`context_gap` at or below 0, no token saving).
> The base query, written before anyone knew the atom, matched none of `currentDocumentRefAtom`'s nodes; the design's answer is the implementer-refined query, which this ablation does not exercise.
> The arms differ in tool-call count partly because A loaded the skill.
> A multi-trial run (Phase 3 of `/cdocs:ablate`) with a base query naming the atom would settle it.

**Staleness stamp** (coordinator direction, after the [perf audit](../reports/2026-10-08-graphify-update-performance-audit.md) on `main` at `697b3df`, not yet on this branch).

- The audit's A2 sketch, verbatim, plus `.stamp` in the copy's drop list and a shorter header comment: the wrapper is 57 lines.
- Suite at 26 checks: an unchanged tree skips `update`; an edit under the ignored `/cdocs/` skips it; a code edit runs it; a failed update leaves the stamp stale so the next call retries.
  Mutations caught: no ignore filter, no skip, stamp written on failure, names hashed without contents (each 2-4 failures).
- Real graphify (clauthier container, this worktree): first call 744 ms (update ran), unchanged 153 ms, untracked `cdocs/` file 141 ms (skipped), untracked `scripts/*.ts` 675 ms (update ran), unchanged again 146 ms; probe files and `graphify-out/` removed.
- Proposal D4 and the wrapper steps describe the stamp (`1bd77c9`); `bin/README.md` too.

> WARN(claude-opus-5-5/cdocs/graphify-overhaul): The first query after a code edit still costs a full rebuild, about 14 s at weftwise scale (13.8-14.3 s in the audit), until graphify fixes `update` upstream.
> Also from the audit: a graphify upgrade does not change the stamp, so a stale graph survives until the next code edit.

### Future work (upstream graphify, from the perf audit, not filed)

1. Gate `update` on its own AST manifest: call `detect_incremental(kind="ast")`, exit early when nothing changed (expected no-op about 0.7 s); the gate must also cover `tsconfig*.json` and `package.json` workspace maps.
2. Cache per-file JS/TS extraction and `_SymbolResolutionFacts` by content hash, running only the cross-file join each time (about 5 s of the 10 s); depends on [#3326](https://github.com/Graphify-Labs/graphify/issues/3326) splitting the cache-bypass set from the resolution gate.
3. Make incremental `changed_paths` rebuilds match full rebuilds for TS (they currently drop external-module nodes and import/call edges), then route `update` through them.
4. Optional `update --no-report` that skips `suggest_questions`, `GRAPH_REPORT.md`, and `graph.html` (about 2-3 s of an edited update).

Once (1) ships, the wrapper's stamp is redundant and can go.

Floor after round 3 (at `15c14c9`):

```
cdocs-graphify.test.sh exit=0 26 passed, 0 failed
chat-record.test.sh --unit exit=0 chat-record tests: 97 passed, 0 failed
validate-cdocs-edit-path.test.sh exit=0 17 passed, 0 failed
removal grep hits: 0
graphify_query hits: 0
test:rules exit=0 tests 11 pass 11 fail 0 
test:opencode exit=0 tests 9 pass 9 fail 0 
cdocs-graphify 57 lines, test 91 lines, shellcheck clean
```

Floor after round 2:

```
cdocs-graphify.test.sh exit=0 22 passed, 0 failed
chat-record.test.sh --unit exit=0 97 passed, 0 failed
validate-cdocs-edit-path.test.sh exit=0 17 passed, 0 failed
removal grep hits: 0
graphify_query hits: 0
test:rules exit=0 tests 11 pass 11 fail 0
test:opencode exit=0 tests 9 pass 9 fail 0   (build/cdocs/opencode/skills/graphify/SKILL.md exists)
cdocs-graphify 49 lines, test 84 lines, shellcheck clean
```

## Changes Made

| File | Description |
|------|-------------|
| `plugins/cdocs/bin/cdocs-graphify` | new: per-worktree graphify wrapper with a staleness stamp (57 lines) |
| `plugins/cdocs/hooks/tests/cdocs-graphify.test.sh` | new: 26-check suite against a graphify stub, bare-repo fixture |
| `plugins/cdocs/bin/graphify-scope`, `plugins/cdocs/hooks/tests/graphify-scope.test.sh` | deleted |
| `.github/workflows/cdocs-hooks.yml` | cdocs-graphify step on Linux and macOS; header comments |
| `plugins/cdocs/bin/README.md` | `## cdocs-graphify` section replaces `## graphify-scope` |
| `plugins/cdocs/README.md` | commands line; skills table gains `/cdocs:graphify` |
| `plugins/cdocs/skills/graphify/SKILL.md` | new skill (proposal draft plus one ambiguity line) |
| `plugins/cdocs/rules/tool-use-safeguards.md` | `/graphify` bullet replaced by the `/cdocs:graphify` rule line |
| `plugins/cdocs/skills/iterate/SKILL.md` | flag and "Graphify scoping" replaced by "Base query" |
| `plugins/cdocs/agents/reviewer.md` | brief section dropped |
| `plugins/cdocs/skills/devlog/SKILL.md` | defines `graphify_base_query` |
| `plugins/cdocs/skills/devlog/template.md`, `plugins/cdocs/skills/iterate/template.md` | `graphify_query:` renamed `graphify_base_query:` |
| `plugins/cdocs/skills/init/SKILL.md` | step 7: `/cdocs/` in `.graphifyignore` |
| `CLAUDE.md` | skills list gains `graphify` |
| `.gitignore`, `.graphifyignore` | `graphify-out/`; `/cdocs/` |
| `cdocs/proposals/2026-09-17-graphify-cdocs-integration.md` | `evolved`/`archived`, supersede NOTE |
| `cdocs/proposals/2026-09-17-graphify-lace-devcontainer-enablement.md` | D3 NOTE |
| `cdocs/proposals/2026-10-08-graphify-overhaul.md` | `implementation_wip`; round 2 NOTEs on `/cdocs/` and the ablation signature; D4 and wrapper steps describe the stamp |
| `cdocs/_media/2026-10-08-graphify-ablation-weftwise-*` | weftwise ablation scorecard, eval, and Step 0 record |

## Verification

Final floor at `bcd1491`:

```
cdocs-graphify.test.sh exit=0 21 passed, 0 failed
chat-record.test.sh --unit exit=0 chat-record tests: 97 passed, 0 failed
validate-cdocs-edit-path.test.sh exit=0 17 passed, 0 failed
removal grep hits: 0
graphify_query hits: 0
test:rules exit=0 tests 11 pass 11 fail 0
test:opencode exit=0 tests 8 pass 8 fail 0   (build/cdocs/opencode/skills/graphify/SKILL.md exists)
.graphifyignore: 1 line: /cdocs/
cdocs-graphify 49 lines, test 82 lines, shellcheck clean
```

Host stub run: primary, secondary, positive control, overseer-clean, and no-op all pass (Phase 5 table).
Unverified: macOS/BSD and bash 3.2 (CI covers on push; no macOS host here), the clauthier devcontainer live run and exclusion check (post-accept), and the weftwise ablation (prerequisites unmet).
