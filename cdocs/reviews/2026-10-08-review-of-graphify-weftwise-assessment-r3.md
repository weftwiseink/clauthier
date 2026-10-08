---
review_of: cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T15:40:55-07:00
task_list: cdocs/graphify-weftwise-assessment
type: review
state: live
status: done
tags: [fresh_agent, source_verified, runtime_validated, graphify, evaluation_design, fairness, leakage]
---

# Review: Graphify Weftwise Assessment (Round 3, Phase 4)

## Summary Assessment

Phase 4 (commit `0931be5`) answers the maintainer's complaint that Phase 2 capped graphify at a tie with grep.
It does this with two independent sonnet arms per task (graph-assisted and grep-only), tasks phrased from problem statements rather than conclusions, a blind opus judge grading against the verified union of both answers, and scenario classes chosen to favour a graph.
The design is right in shape, and every capability it names exists in graphify 0.9.61.
Three gaps remain, and each one could decide the outcome on its own:
- **The graph arm can silently become a second grep arm.** On the host, `cdocs-graphify` resolves to the plugin's wrapper but graphify is not installed, so the wrapper prints "skipping" and the skill says to continue without the graph. The wrapper also rejects `god-nodes`.
- **Leaks inside the worktree are open.** The deleted `cdocs/` can be read back with `git show HEAD:` or restored with `git checkout`. Code at `2791713d` also holds comments and test names that the fix itself wrote, which hands grep a lexical shortcut.
- **The grep arm is weaker than a real agent without graphify.** It is limited to grep/find/read, while the graph arm may script. That would manufacture graph wins on the cycle and dead-code classes.

Verdict: **Revise**. The three fixes are small, and with them the design is fair in both directions.

## Scope and Method

Scope: the Phase 4 additions in `0931be5` (BLUF, Summary item 4, Objective, the Phase 2 NOTE, `### Phase 4`, the design decisions, edge cases, the test plan, the Phase 4 floor, and the implementation phase).
Phases 1-3 are implemented and accepted (impl-r2), so they are not re-reviewed.
I read the report's Usefulness section, the overseer devlog's Steering Log, the skill, and the wrapper.

Container probes (read-only, scratch `GRAPHIFY_OUT`):
- `graphify --help` on 0.9.61;
- `analyze.py`, `report.py`, `affected.py`, `serve.py`, and `cli.py` source;
- `god-nodes --top 3`, `affected mergeBranch --relation calls --depth 3`, and `query "branch merge" --dfs --context call --budget 300` against the main graph;
- edge `context`/`relation` counts and the main `GRAPH_REPORT.md` section list;
- host checks of `cdocs-graphify`/`graphify` on `PATH`, weftwise tracked files, and installed analysis tools.

> WARN(claude-opus-5-5/cdocs/graphify-weftwise-assessment): My `query` probe passed `--graph /var/cache/graphify-weftwise/graph.json` with a scratch `GRAPHIFY_OUT`, and it still rewrote `/var/cache/graphify-weftwise/cache/last_query_stamp` (now `1791499135.81`, mtime 15:38).
> `_touch_query_stamp` (cli.py:687) writes next to `--graph`, not into `GRAPHIFY_OUT`.
> The file is an 18-byte TTL marker that only graphify's strict PreToolUse hook reads, and no graphify hook is installed (weftwise `.claude/settings*.json` and `~/.claude/settings.json` have none).
> `graph.json` mtime is unchanged (`14:09:35.88`), so the Phase 4 floor's collateral check still holds.
> Its previous contents are not recoverable.
> See F3: this same mechanism applies to the graph arm.

## Section-by-Section Findings

### Capability inventory (Setup › Feature inventory)

Every named capability exists in 0.9.61:
- `god-nodes [--top N] [--json]`;
- `query --dfs/--context/--budget`, where `--context` filters edges on their `context` attribute (main graph: `import` 10,253, `call` 4,742, `re-export` 1,088, `export` 257, `parameter_type` 173, ...);
- `affected --relation/--depth` (default depth 2; default relations `calls`, `indirect_call`, `references`, `imports`, `imports_from`, `dynamic_import`, ...);
- `export callflow-html`, `tree`;
- `GRAPH_REPORT.md` with God Nodes, Surprising Connections, Communities, and Suggested Questions.

The probes ran cleanly on the cleaned graph.

**F1 (non-blocking): the inventory misses things that change class design.**
- `GRAPH_REPORT.md` also has **Import Cycles**, precomputed by `find_import_cycles` (cycles of 5 files or fewer, shortest first). The main report already lists 14 3-5-file cycles in `weft/src`.
  The cycles class is therefore a lookup, not "possibly by scripting".
  That makes it a graph win almost by construction, and it should be read that way (see F5).
- The report also has **Knowledge Gaps**: 2,488 isolated nodes, many of them `package.json` keys (`name`, `description`, `license`).
  In-degree-0 dead-code answers will be noisy; the card should say so, and the judge will mark the false positives.
- **Community labels are hub names** (`geometry.ts`, `shape_ops.ts`, `loadCanvasLoroDoc`), because labels come from `label_communities_by_hub` with no LLM.
  The "concept discovery via communities" and "orientation" rows therefore get file-name information, which grep already has.
  Graphify's actual concept features are LLM community naming (`graphify label`) and semantic `extract --backend ...`. The container has `claude` on `PATH`, and graphify has a claude-cli backend.
  The proposal neither includes nor excludes them, so a negative result on those classes could be over-generalized. See Question 1.
- `tree` and `export callflow-html` emit HTML, which an agent cannot use well. `serve.py` is an MCP server with `query_graph`, `get_neighbors`, `god_nodes`, and `shortest_path`, but it needs `mcp`, which is not installed. The inventory should record both as unavailable to the arm, so the report does not later read as "never tried".
- The main `GRAPH_REPORT.md` is 1,642 lines (about 80 KB, roughly 20k tokens).
  The card should tell the arm to grep it by section, not read it whole, or the orientation class pays a token penalty that no agent would choose to pay.

### Tasks (Sampling, Synthetic tasks, Leak check)

Sampling from problem statements, rephrasing to remove unknown entity names, recording provenance, and keeping the sampler from answering all directly fix Phase 2's leak.

**F2 (blocking): leaks inside the worktree remain open.**
- **Git history.** `cdocs/` and `_archive/` are deleted, uncommitted, in a git worktree.
  `git status` shows thousands of deleted devlogs, and `git show HEAD:cdocs/devlogs/<file>` or `git checkout -- cdocs` returns them.
  `git log` subjects for the fix commits name the answer entities.
  The edge-case check voids only reads *outside* the worktree, so none of these is caught.
- **Fix-era lexical traces.** The worktree is `2791713d`, after every source devlog's fix.
  The fixes left comments and test names that echo the problem statement (for example, Phase 2's Q5 answer is an authz test named `LEGACY-OWNER-SPARE`).
  Grepping a distinctive phrase from the task can land on the fix site directly.
  This shortcut did not exist when the question was really asked, and it helps only grep-style search, because the graph indexes symbols, not comments.
  It biases toward grep, and toward ties, on exactly the concept-discovery tasks.

Fix (cheap):
1. The shared prompt forbids git commands for both arms, and the transcript check flags any `git` call (the wrapper's internal git is not an arm call).
2. The leak check adds one step: grep each task's two or three distinctive phrases in `gfy-value-grep`.
   If a top hit is a comment or test name the source devlog's work added (date via `git log -1 --format=%cs -S'<phrase>'`, run by the implementer), rephrase the task away from that wording or replace it.
   Log the result alongside the existing leak-check result.

Running each task on its pre-investigation commit is more faithful but much heavier (Question 2).

**F4 (non-blocking): the sampler should not see the "Graphify feature likely to matter" column.**
Give it class names and task shapes only.
With the feature column it may shape tasks toward what the graph does well, which is the manufactured-win risk in its mildest form.

**F5 (non-blocking): synthetic tasks and n=1 per class.**
- Report synthetic tasks (dead code, cycles) in the table but outside the headline tally, because a precomputed cycle list against a tool-limited grep arm (F6) is not evidence about weftwise work.
- With 8 classes and 10-12 tasks, most classes rest on one task, so one badly phrased task decides a class.
  Prefer two tasks for the high-prior classes (transitive blast radius, cross-package dependents, tests covering a behaviour).
  Fund them by merging "implementers and users" into "cross-package dependents": the main graph has only 31 `implements` edges and 410 `references`, so that class is thin.
  Optionally, fold dead code and cycles into one synthetic "whole-graph structure" row.

### Arms

**F3 (blocking): the graph arm needs one safe, working entry point, and the card needs one validation run.**
- **Silent degeneration.** The arm runs on the host (`/var/home/mjr/code/weft/weftwise/<worktree>`), where `command -v cdocs-graphify` finds the plugin's wrapper and `command -v graphify` finds nothing.
  If the arm follows `/cdocs:graphify` literally, the wrapper prints `graphify not installed; skipping` and exits 0, and the skill text says "continue without the graph".
  The graph arm then becomes a grep arm, and the task scores a tie.
  Phase 4's "Graph arm: has `/cdocs:graphify` through the wrapper" invites this path.
- **The wrapper rejects `god-nodes`, `tree`, and `export`** (its `case` allows only `query|explain|path|affected`, otherwise usage and exit 2).
  The inventory's features need raw calls.
- **Raw calls write next to `--graph`.** `query`, `explain`, and `path` touch `<dir of --graph>/cache/last_query_stamp` whatever `GRAPHIFY_OUT` says (see the WARN above).
  The container default `GRAPHIFY_OUT` is the main graph, and a sonnet arm writing raw commands is now a raw caller.
  The Operating rules' sentence "even `query` writes `cache/last_query_stamp` there" points at the wrong mechanism.
- **Scratch files.** A script the arm writes inside `gfy-value-graph` is an untracked, non-ignored file. It changes the wrapper's stamp and triggers a 10 s `update` mid-run, possibly concurrently.

Fix:
1. The card gives one command form, for example `podman exec -i -u node -e GRAPHIFY_OUT=<scratch> -w /workspaces/weftwise/gfy-value-graph weftwise bash -c '<scratch>/cdocs-graphify explain X'`, and a raw form whose `--graph` is the worktree's `graphify-out/graph.json`.
   Scripts and scratch output go under the container `/tmp`.
   The card states that a "skipping" line means the call was wrong, not that the graph is unavailable.
2. Before dispatching any arm, one pilot graph arm runs on a held-out question (not a task; for example, a Phase 2 named-entity question).
   It confirms that sonnet can drive the card: entry point, ambiguous-id retry, reading `affected` and `path` output.
   Fix the card from what the pilot stumbles on.
   This is the direct answer to "sonnet knows grep, not this CLI".
3. A graph-first guideline in the graph arm's prompt: begin with the graph command that fits the task, then grep as needed.
   A graph arm that ran no graphify command is rerun once, as with a voided task.
   Without this, a tie can mean "the graph was never consulted".

**F6 (blocking): the grep arm should be "everything except graphify", not "grep, find, and read only".**
The graph arm may script over `graph.json`; the grep arm, as written, may not script over source.
A real agent without graphify writes a 20-line import scanner for cycles or unused exports, or runs installed project tooling (weftwise has `tsc` in `node_modules/.bin`; no `madge`, `knip`, or `ts-prune`).
As written, the cycles and dead-code classes compare a precomputed report against an arm forbidden to compute, so the win is manufactured.
Fix: the grep arm may use Bash, ad hoc scripts, and installed project tools, but no graphify, no `graphify-out/`, no `graph.json`, and no new installs.
Both arms: no git (F2) and no subagents.
- **Why no subagents**: an arm dispatching `Explore` or `cdocs:bash-runner` (the cdocs rules both arms load recommend `bash-runner`) hides tool calls and tokens from the per-arm usage and breaks the efficiency comparison.

**F7 (non-blocking): the token metric.**
"Total tokens from the Agent result's usage" counts the card in the graph arm's context. That is fair, since it is the real cost, but the report should say so in one line.
Wall time includes about 0.5 s of `podman exec` plus wrapper per graph call, which is also a real cost.

### Judge and outcome

Blind A/B, random order, a reference built from the verified union, and wrong items marked wrong are all sound, and they keep grep's answer from being the reference.

**F8 (non-blocking): guard against a win made of unrequested output.**
- `affected --depth 3` or a god-node list can put 30+ true-but-marginal items into an answer.
  Completeness as "verified items found out of the reference" rewards that.
  Cap the answer format at about 10-15 ranked items. Have the judge also mark items "true but not relevant to the task", and grade completeness on the items the judge rates important.
- Split "graph better" into **reach** (found an important item the other missed) and **efficiency** (matched completeness at half the tokens or time or less).
  The map should keep them apart: the maintainer's question is mostly about reach, and Phase 2 already showed efficiency on named entities.
- The serendipity read after unblinding is commentary only, and it must not change an outcome. Say so.
- Blinding: graph-derived answers carry node-label tells (`.method()`, `[EXTRACTED]`, snake-case ids).
  The implementer normalizes both answers to `file:entity` during scrubbing; the answer format already asks for that.

### Deliverable, design decisions, and edge cases

Putting the result as a section in the existing report, with the BLUF and Verdict per Role updated if the map moves them, is right, and so is "if graphify wins nowhere, say so with evidence its best case was tried".
The design-decision bullets are accurate.
The edge cases cover cross-worktree leaks and symmetric contention, but not the in-worktree leaks (F2) or the arms writing scratch files (F3).

**F9 (non-blocking): transcript checks need a mechanism.**
"Check every transcript's paths" across 24 arm runs of up to about 40 calls each is too much to read whole in one implementer context.
Extract per-arm tool calls mechanically from the subagent `.jsonl` transcripts under `~/.claude/projects/<project>/<session>/subagents/`: tool names, `file_path`/`path`/`pattern` inputs, Bash commands, `git` calls, and paths outside the worktree, with a `jq` one-liner or a `cdocs:bash-runner`.
Read graph outputs in full only for the serendipity pass.

### Ceremony and executability

The Phase 4 text is about 100 lines and proportionate.
Dispatch count: 1 sampler, about 24 arms, 10-12 judges, and with F3 one pilot, about 38 in all, which one opus implementer can run in a session if transcripts are checked mechanically (F9).
The Phase 4 floor is minimal, and its re-judge of two tasks is the right reproducibility check.
The suggested class merges (F5) trim rather than add.
Nothing here needs a new phase or a second implementer.

### Accuracy spot checks

- Expected `source` graph: 9,744 nodes and 25,774 edges matches report floor step 6. Deleting `cdocs/` and `_archive/` cannot change it, because both are ignored.
- Main graph mtime `2026-10-08 14:09:35.88 -0700`: confirmed unchanged after my probes.
- Leak surface besides `cdocs/` and `_archive/`: `.claude/oversee/` and `WORKTREE_CONTEXT.md` are untracked in `main`, so they are absent from fresh worktrees. The tracked `docs/` guides are legitimate project context.

## Verdict

**Revise.**
The design genuinely looks for graphify's best case: the `source` graph, a capability card beyond the skill, a graph arm that may also grep, discovery-phrased tasks, a union reference, and a blind judge.
F3 and F2 are structural biases toward grep (the graph arm silently degenerating, and lexical and git shortcuts), and F6 is a manufactured-win path the other way.
All three are prompt or leak-check changes, not redesigns.

## Action Items

1. [blocking] F3: Give the graph arm one container entry point (wrapper and raw forms with `-e GRAPHIFY_OUT=<scratch>`, raw `--graph` on the worktree index, scratch files in container `/tmp`), and state in the card that "skipping" means a wrong invocation.
   Run one pilot graph arm on a held-out question and fix the card before dispatch.
   Add a graph-first guideline, and rerun a graph arm that made no graphify call.
2. [blocking] F2: Forbid git commands for both arms and flag them in the transcript check.
   Add a lexical-trace step to the leak check: grep each task's distinctive phrases, and rephrase or replace tasks whose top hit is a comment or test name written by the source devlog's fix.
3. [blocking] F6: Define the grep arm as everything except graphify: Bash, ad hoc scripts, and installed project tools are allowed; no graphify artefacts and no installs.
   Both arms: no subagents.
4. [non-blocking] F1: Add to the inventory `GRAPH_REPORT.md` Import Cycles (precomputed) and Knowledge Gaps (2,488 isolated nodes, noisy for dead code), hub-name community labels, HTML-only `tree`/`callflow-html`, and `serve.py` needing the absent `mcp`.
   State the no-LLM scope (see Question 1). The card says to grep `GRAPH_REPORT.md` by section.
5. [non-blocking] F8: Cap answers at about 10-15 ranked items, have the judge mark true-but-irrelevant items, split "graph better" into reach and efficiency, and state that serendipity does not change outcomes.
6. [non-blocking] F5: Report synthetic tasks outside the headline tally. Give two tasks to the high-prior classes, funded by merging "implementers and users" into "cross-package dependents".
7. [non-blocking] F4: The sampler sees class names and task shapes, not the graphify-feature column.
8. [non-blocking] F9: Check transcripts mechanically with `jq` over the subagent `.jsonl` files, not by reading them whole.
9. [non-blocking] Operating rules: correct the `last_query_stamp` sentence. It is written next to `--graph`, whatever `GRAPHIFY_OUT` is set to.
10. [non-blocking] F7: One line in the report noting that graph-arm tokens include the card, and that wall time includes `podman exec`.

## Questions for the Maintainer

1. LLM features for concept discovery and orientation (F1):
   - (a) Scope them out, and state in the report that the verdict covers the no-LLM, code-only config weftwise runs (reviewer's recommendation: minimal, and it matches deployment).
   - (b) Add one variant: `graphify label` via the claude-cli backend on the scratch graph, used only by the graph arm on concept and orientation tasks, with labelling cost recorded.
   - (c) Also run semantic `extract --backend claude`. This is the costliest, and it changes what the graph contains.
2. Code state for tasks (F2):
   - (a) Keep `2791713d` and add the lexical-trace screen (reviewer's recommendation).
   - (b) Run each task's pair of worktrees at its source devlog's starting commit, with the current `.graphifyignore` copied in and a per-task graph build (about 10 s each). This is most faithful, but it adds 10-12 worktree pairs and builds, and it loosens the floor's single-commit pinning.
3. Grep-arm tools (F6):
   - (a) Everything except graphify, with no installs and no subagents (reviewer's recommendation).
   - (b) Keep "grep, find, read only" as written, and label the cycle and dead-code rows as "graph vs a tool-limited agent" outside the scenario map.
