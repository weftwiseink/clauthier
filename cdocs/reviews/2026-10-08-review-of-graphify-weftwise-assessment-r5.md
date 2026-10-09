---
review_of: cdocs/proposals/2026-10-08-graphify-weftwise-assessment.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T17:02:56-07:00
task_list: cdocs/graphify-weftwise-assessment
type: review
state: live
status: done
tags: [fresh_agent, runtime_validated, experiment_design, decision_rule, fairness, graphify, evaluation]
---

# Review: Graphify Weftwise Assessment, Round 5 (Phase 5: Conditioned Re-measurement)

> BLUF: **Revise.** Phase 5 targets the right gaps in Phase 4: it uses opus, runs sessions in weftwise, adds a ceiling arm and two judges, and measures context.
> I probed the mechanics in the container:
> - the 0.2.0 plugin loads;
> - the init event lists `cdocs:graphify`;
> - the grep arm's PATH swap holds inside the agent's Bash tool;
> - `/cdocs:init` writes v0.2.0 rules that carry the graphify line.
>
> Mechanics problems:
> - The session command as written fails: `stream-json` needs `--verbose`.
> - The permission setup it points to ("as the ablation") is recorded nowhere. Without one, headless Bash calls are denied.
> - The rules install leaves CLAUDE.md's `@.claude/rules/cdocs.md` import in place.
>
> The pre-registered rule is not yet fair either way:
> - it has no noise margin, and no grep-vs-grep control to set one;
> - it drops Phase 4's corrected attribution, so the exhaustive ceiling prompt can win on effort alone;
> - it gives no mapping from tasks to roles;
> - the implementer writes the base queries after reading Phase 4's answers.
>
> The motivating NOTE is partly wrong: Phase 4's arms already had the 0.2.0 graphify rule line and the `cdocs:graphify` skill listing in context.

## Summary Assessment

Phase 5 is meant to settle keep or drop for graphify under real cdocs 0.2.0 conditioning.
It compares a grep-only arm, a realistic arm, and a ceiling arm against a decision rule fixed in advance.
The design direction is sound, and most of its environment assumptions hold up under cheap probes.
The decision machinery does not hold up yet: on judge-noisy single runs, "more unique important items than grep" with no margin can return keep or drop by chance.
Nothing in the rule separates the ceiling arm's mandated thoroughness from graphify's own contribution.
These are fixable in text, plus about 10 more arm runs for a control.
Verdict: **Revise**.

## Mechanics Probes (container `weftwise`, reviewer-run)

All probes ran in a container scratch dir `/tmp/rv5-probe`.
- **Inputs:** a `git archive` of clauthier `HEAD`'s `plugins/cdocs`, a sandbox `CLAUDE_CONFIG_DIR` holding a copy of `.credentials.json`, and a `git archive` of weftwise `2791713d`'s `.claude`, `CLAUDE.md`, `AGENTS.md`, and `.graphifyignore`.
- **Untouched:** no weftwise worktree was created or touched.
- **Cleanup:** the scratch dir is deleted; no `.credentials.json` copy remains under container `/tmp`.
- **Real config unchanged:** the container's `~/.claude/.credentials.json`, `~/.claude/.claude.json`, `plugins/`, and `projects/` (76 entries) have the same mtimes as before; weftwise `main` is clean, with 8 worktree entries.

| Check | Result |
|---|---|
| Proposal's command: `claude -p --model opus --plugin-dir <p> --output-format stream-json` | **exit 1**: "When using --print, --output-format=stream-json requires --verbose" |
| Same with `--verbose` | **pass**. The init event's `plugins` holds `{"name":"cdocs","source":"cdocs@inline","version":"0.2.0"}` plus three builtins. `skills` and `slash_commands` include `cdocs:graphify`, and `agents` includes the cdocs agents. The project's `enabledPlugins` `cdocs@clauthier` does not load (it is not installed in the sandbox), so no 0.1.0 plugin loads. `model` is `claude-opus-5-5`, and each assistant event carries per-request `usage` |
| SessionStart hook with the v0.1.0 rules | Injects "Run `/cdocs:init` now ... rules are stale" into context: a conditioning signal the check does not use |
| Grep arm PATH (`/usr/local/bin` swapped for 25 symlinks, `GRAPHIFY_OUT=`), run as a Bash call inside a haiku session | **pass**. `command -v graphify` fails, and the session's PATH ends with `<plugin>/bin` (Claude Code appends it). `cdocs-graphify query test` prints `graphify not installed; skipping`, and `.bashrc` or `/etc/bash.bashrc` do not restore `/usr/local/bin`. `rg` and `grep` are Claude Code shell functions, so they work without `rg` on PATH. `/usr/local/pipx/venvs/graphifyy/bin/graphify` stays reachable by absolute path |
| `/cdocs:init` (headless sonnet, `bypassPermissions`, in a scratch copy) | **pass, but it changes three files.** The marker is `v0.2.0 hash=14538026...`, and the graphify line is in both `.claude/rules/cdocs.md` and `AGENTS.md`. **CLAUDE.md loses its `@.claude/rules/cdocs.md` line.** The rules file drops from 50 KB to 12 KB and `AGENTS.md` from 50 KB to 13 KB. The run cost $0.30 |
| Default permission mode in `-p` | Bash must be allowed explicitly; my first probe needed `--allowedTools=Bash`. The untracked `.claude/settings.local.json` allow list is not in a fresh worktree |
| OAuth credentials | The access token in the copied credentials expires about 6.8 h after the probe. Each sandbox dir refreshes on its own |

I also checked the Phase 4 arm transcripts (`~/.claude/projects/-var-home-mjr-code-weft-clauthier-main/63ac45de-.../subagents/`, the x2, b1, and c1 graph arms).
Each one carries a `skill_listing` attachment with `cdocs:graphify` and an `instructions` attachment with the 0.2.0 rule line ("agents that read code run the workstream's `graphify_base_query` at startup and `explain` code entities").
None of them called `Skill`; their tool calls were only Bash and Read.

## Section-by-Section Findings

### Phase 5 NOTE: why Phase 4 is insufficient

- **[blocking] The conditioning gap is misstated.**
  The NOTE lists weftwise's v0.1.0 rules and the container's 0.1.0 plugin as conditions of Phase 4's arms.
  Those arms were host subagents of the clauthier session, so they carried clauthier's 0.2.0 rules, including the graphify line, and the `cdocs:graphify` skill listing.
  On top of that, their prompts had an explicit graph-first guideline, and they still used the graph lightly.
  The real differences from a weftwise cdocs session are:
  - sonnet, not opus;
  - a card and `podman exec`, not the wrapper on PATH;
  - clauthier's project context, not weftwise's;
  - no base query.

  This bears directly on the maintainer's hypothesis ("is that maybe because they're not running with a properly setup current version of cdocs"): current rules plus a stronger push than any realistic prompt did not produce heavy use.
  The NOTE should say so and predict light use in the realistic arm, so that a light-use result is not read as a conditioning failure afterwards.
  The stale weftwise 0.1.0 install is still worth fixing, but it is a fact about real weftwise sessions, not about Phase 4.

### Decision rule

- **[blocking] No noise margin, and no control to set one.**
  - "Net reach" is defined as "more unique important items than grep", with no margin.
  - Phase 4 showed judge noise of 1-2 items per task and one outcome flip in four re-judges.
  - Its own Reading concedes that, without a grep-vs-grep baseline, "mixed" cannot be told apart from two runs of the same arm.
  - Two judges reduce judge noise, but not run-to-run arm variance: every arm still runs once.
  - Fix: add a second grep-only arm (grep-B) per task, run alongside the others.
    The null is then grep-B's unique items against grep, and the realistic and ceiling margins must exceed that spread.
    The same control gives the noise floor for peak context.
  - Cost: 10 more opus arms, or 4 if the maintainer accepts a partial control (Q2).

    This is the cheapest change that makes either verdict defensible to someone leaning one way.
- **[blocking] "Lower peak context at equal completeness" has no thresholds.**
  - One large `Read` moves a peak by thousands of tokens, so "lower" needs a material bar: for example, a median per-task reduction of at least 15% that also exceeds the grep-B spread.
  - "Equal completeness" also needs a definition, for example within one important item.
  - **Delegation:** subagents are allowed, and a subagent's context is not in the session's peak.
    An arm that delegates to `Explore` lowers its peak without graphify, so a context win that comes from delegation should not count toward row 1.
- **[blocking] Attribution is missing.**
  - Phase 4's review made attribution blocking (item 3). The report now separates graph-only finds from finds the arm's own grep also reached (4 / 4 / 5).
  - Phase 5 drops this step. It matters most for the ceiling arm, whose prompt mandates exhaustive work: `explain` every candidate, `affected` on every subject, `god-nodes`.
    A ceiling win can then come from thoroughness rather than from the graph, and row 2 would credit graphify for it.
  - Fix: count toward the rule only unique items whose first appearance in the arm's transcript is graph output, with no earlier grep or read output naming them, checked mechanically.
    An alternative is a thoroughness-matched grep ceiling arm, which costs more.
- **[blocking] The rule speaks per role, but no task maps to a role.**
  - Every arm answers a discovery investigation, and the table outputs a "recommendation for the role" without saying which tasks stand for which role.
  - Implementers mid-edit are not measured by Phase 5 at all: the arms only investigate, and the tree never changes.
  - Fix:
    - state the mapping: startup is base-query attribution plus orientation and concept; reviewers are blast radius, tests, and cross-package;
    - say the mid-edit verdict stays the Phase 3 runtime verdict;
    - or decide keep or drop once, overall, with per-class notes.
- **[blocking] Row 2 ("keep only with changed steering") promises an untested change.**
  A ceiling win followed by a named but unrun steering change is a keep on faith.
  Either validate the change within Phase 5 (rerun the realistic arm with it on 3-4 tasks; keep only if it then gains), or make row 2 read "drop now; revisit if the change is tried" (Q3).
- **[non-blocking] Cost is absent from the rule.**
  Row 1 keeps graphify on reach even if it costs more.
  The maintainer cited maintenance and dependency overhead.
  At minimum, state that the keep recommendation carries its cost and its prerequisites:
  - the `source` export condition (undecided, and the graph arms depend on it);
  - the stamp-bug fix;
  - `god-nodes` in the wrapper, if the ceiling's orientation result drives the keep.
- **[non-blocking] The search-share bound is understated and under revision.**
  - "4-14% ... bounds what any search tool can save" leaves out exploratory reads.
    The skill pitches graphify as replacing "grep sweeps and full-file reads", and never-edited source reads are 28% (30K) of weftwise implementer reads in the same report.
  - Its review (`d581087`, revise) finds search undercounted 1.6-4x, and puts search plus exploratory reads at about 10-15% of growth to peak.
  - Cite the bound as search plus exploratory reads, from the revised report.

### Environment

- **[blocking] The session command fails, and its permission setup is undefined.**
  - Add `--verbose`.
  - Replace "Same permission setup as the ablation" with explicit flags. The ablation records (overhaul impl devlog Round 3, the `_media` scorecards) do not state one, and in default `-p` mode an arm's Bash calls are denied, which silently turns every arm into a Read-only arm.
  - Suggested: `--permission-mode bypassPermissions --disallowedTools 'Bash(git:*)'`.
  - In the pilot, confirm that the deny rule holds under bypass and that the arm ran at least one Bash call.
- **[blocking] The rules install is not a real 0.2.0 init.**
  - In my probe, `/cdocs:init` changed `CLAUDE.md` (removing the `@.claude/rules/cdocs.md` import) as well as the rules file and the `AGENTS.md` block.
  - Copying only the latter two leaves an import that a 0.2.0 project lacks.
  - Fix:
    - copy every file init changes, except the `cdocs/` scaffolding, which arm worktrees delete anyway;
    - add two conditioning checks: CLAUDE.md has no `@.claude/rules/cdocs.md` line, and the SessionStart `hook_response` carries no "Run `/cdocs:init`" nudge.
- **[non-blocking] Model and effort realism (Q1).**
  - `--model opus` resolves to `claude-opus-5-5`.
  - Weftwise's CLAUDE.md says "Default all dispatched/subagent work to Opus 4.8", and the search report's weftwise implementers ran Opus 4.8 or Fable.
  - The container's user settings set `"model": "opus[1m]"` and `effortLevel: high`. The sandbox config dir drops both, so arms run at the default effort, and with a smaller window an arm can compact, which distorts peak context.
  - Pass the model and effort explicitly, for example `--model 'opus[1m]'` plus `--settings '{"effortLevel":"high"}'`, or Opus 4.8 if the maintainer prefers weftwise's policy.
- **[non-blocking] The plugin `bin/` PATH step is redundant, and one check runs in the wrong place.**
  - Claude Code appends `<plugin-dir>/bin` to the session PATH itself.
  - `command -v cdocs-graphify` is therefore only meaningful inside the session, or under `bash -ic` with the arm's environment.
  - Drop the manual step, and run the grep arm's `command -v graphify` check the same way. The pilot verifies it once in-session.
- **[non-blocking] Unstated environment for the graph arms.**
  - Say that graph-arm sessions keep `GRAPHIFY_OUT` pointed at the scratch copy, as in Phase 4's safety net.
    Otherwise they inherit the container default, the main graph, and a raw `graphify god-nodes` without `--graph` reads and stamps it.
  - Give the ceiling block the exact raw `god-nodes` form.
- **[non-blocking] Credentials.**
  - Use one sandbox config dir for all arms rather than one per arm: transcripts are per session anyway.
  - Check the copied token's expiry before a multi-hour batch. Each sandbox dir that refreshes rotates its own copy, and whether that invalidates the maintainer's container login is untested; I did not test it.
  - Copy the session and subagent `.jsonl` files out to host scratch before deleting the dir. The ablation lost its transcripts this way ("transcript paths ... point at the deleted sandbox").
- **[non-blocking] Realism gaps to state, not fix.**
  - The arms are top-level `-p` sessions, not `cdocs:implementer` or `cdocs:reviewer` subagents.
  - The project's marketplace plugins (typescript-lsp, code-simplifier, and others) do not load in the sandbox. LSP is inert anyway: the container has no `typescript-language-server`.
  - The graph is the `source`-conditions graph, which weftwise does not ship.

### Arms, tasks, and the flagged overrides

- **[blocking] The base queries can leak Phase 4's answers.**
  - "Phase 5's implementer writes that line ... from the task text only." But that implementer will have read the report, whose task table and scenario map name the answer entities (`document_store.ts`, `sharee_store_harness.ts`, `subscribeRevocations`, `MountsContainer`, ...).
  - A base query that names them inflates both graph arms.
  - Fix: a fresh agent that sees only the task text and the iterate skill's "Base query" paragraph writes the base queries, and they are logged before any arm runs.
- **No synthetic rerun: accept.**
  - d1 and y1 sit outside the tally.
  - y1's grep win is structural: Import Cycles stops at 5 files and counts `import type`, so conditioning cannot change it.
  - d1 compared two equivalent methods.
- **Subagents allowed: accept, with guards.**
  - It is realistic; the search report counted 0 `Explore` dispatches across 167 implementers and reviewers, so it will rarely fire.
  - Record delegation per arm, and exclude delegation-driven context wins (see Decision rule).
  - Rewrite the transcript checks for Phase 5. Phase 4's checks flag any `Agent` call, so they must now:
    - allow `Agent`;
    - read the subagent transcripts too;
    - flag grep-arm access to `/usr/local/pipx/venvs/graphifyy/`, `/var/cache/graphify-weftwise`, or any `graph.json`.

    "Run the transcript checks" currently points at checks that would void every delegating arm.
- **No devlog for arms: accept, with a guard.**
  - Weftwise's CLAUDE.md says "IMPORTANT: Always create a devlog", and `cdocs/` is deleted, so an arm that obeys it writes an untracked file into the worktree.
  - In a graph worktree that file changes the stamp and triggers a refresh of about 10 s. In a worktree reused across tasks it leaks to later arms.
  - Fix: compare `git status --porcelain` before and after each arm, and void any arm that wrote.
- **Judge agreement rule: accept the intent; the tally mechanics are underspecified.**
  - "Same label, counts within 1" is reasonable, but the rule does not say which counts enter the tally when the judges agree (one judge's, the mean?), or what "majority" means for counts when a third judge breaks a tie.
  - Simpler, more conservative, and fair both ways: an item counts as important and unique only when both judges rate it so. Both judges see the same normalized `file:entity` items, so matching is mechanical.
    The agreement rate is reported, split items are listed and left out, and the third-judge round goes away.

### Execution and ceremony

- **[non-blocking] Executable by one implementer in one session, if scripted.**
  - The run is about 30 arms (40 with grep-B), 20-30 judges, a 3-arm pilot, and a sampler.
  - The headless arms keep their tokens out of the implementer's context. Judge returns, if dispatched as subagents, do not: about 25 returns of 2K or more each.
  - Recommend:
    - a per-task driver script that creates the worktrees, warms them, runs the checks, launches the arms with `stream-json` written to files, and extracts the measures with `jq`;
    - judges as headless sessions that write their matrices as JSON files, so the implementer sees only summaries.
  - Wall time is roughly 3-5 h, with tasks run one at a time and arms in parallel. Add a cost estimate: opus arms at about $2-5 each puts the run near $100-200.
  - If context gets heavy, split the work into two dispatches: setup and pilot, then the runs and the report.
- **[non-blocking] Worktree count is inconsistent.**
  - The Environment section says "one throwaway detached worktree per arm per code state". The Implementation Phases section says "For each task: create three worktrees".
  - Arms are read-only, so realistic and ceiling can share one graph worktree. With the `git status` guard, a pair per code state suffices (4-5 pairs, not 30 worktrees).
  - Keep the cwd distinct per task if auto-memory stays on, or check that the memory dir is empty at arm start. `memory_paths.auto` is keyed by cwd.
- **[non-blocking] Ceremony that can go without weakening rigor.**
  - The Phase 5 NOTE restates Summary item 5 and the BLUF. After correcting it (above), keep about 3 lines and leave the maintainer's words to the Steering Log.
  - Drop the manual plugin-`bin/` PATH step, and the third-judge round if item-level consensus is adopted.
  - Phase 5 floor item 1, "a reviewer re-runs the check for one arm's environment", requires rebuilding a torn-down sandbox. Re-check from the saved init events and transcripts instead.
  - Inline the 4 Phase 4 items Phase 5 inherits: allowed paths with container paths substituted (including `/workspaces/weftwise/main/node_modules/.bin`), answer format, normalization, and leak check. The implementer then need not translate Phase 4's host paths.
  - Phases 1-4 (about 340 lines) are executed and recorded in the report and devlogs. Their length is not itself a problem, but Phase 5 is clearer when it does not depend on them for mechanics.
  - The additions above cost about 15 lines, against roughly 15-20 cut.

## Verdict

**Revise.**
Phase 5's direction, environment, and measures are right, and the environment largely works as assumed (probed).
Before any arm runs:
- fix the two mechanics breaks (`--verbose`, explicit permissions) and complete the rules install;
- correct the NOTE;
- give the decision rule a control-based margin, graph attribution, a mapping to roles, and a defined path for row 2;
- blind the base queries.

These keep a single noisy draw from deciding keep or drop in either direction.

## Action Items

1. [blocking] Write the full session command:
   - add `--verbose`;
   - replace "same permission setup as the ablation" with explicit flags (for example `--permission-mode bypassPermissions --disallowedTools 'Bash(git:*)'`);
   - in the pilot, confirm that the deny rule holds and that Bash runs.
2. [blocking] Install the rules as a real 0.2.0 init: copy every file `/cdocs:init` changes, including CLAUDE.md's `@`-import removal.
   Add two conditioning checks: no `@.claude/rules/cdocs.md` line in CLAUDE.md, and no `/cdocs:init` nudge in the SessionStart `hook_response`.
3. [blocking] Correct the Phase 5 NOTE:
   - Phase 4 arms had the 0.2.0 graphify rule line, the `cdocs:graphify` skill listing, and a graph-first guideline;
   - they differed in model, card plus `podman exec`, project context, and base query;
   - predict light realistic-arm use.
4. [blocking] Add a grep-B control arm (all 10 tasks, or at least 4; Q2). Define net reach and the context win as margins beyond the grep-B spread, with "equal completeness" and a material context threshold stated, and delegation-driven wins excluded.
5. [blocking] Add mechanical graph attribution for realistic and ceiling unique items: only items first seen in graph output count toward the rule.
6. [blocking] Map task classes to roles, or decide once overall. State that the mid-edit verdict stays Phase 3's.
7. [blocking] Make row 2 either validated (rerun the realistic arm with the named change on 3-4 tasks) or "drop now, revisit" (Q3).
8. [blocking] Have a fresh agent that sees only the task text write the base queries, logged before any arm runs.
9. [non-blocking] Pass the model and effort explicitly (`opus[1m]` or Opus 4.8, and `effortLevel: high`; Q1).
10. [non-blocking] Rewrite the transcript checks for Phase 5:
    - allow `Agent` and include subagent transcripts;
    - flag grep-arm access to the pipx graphify path, `/var/cache/graphify-weftwise`, and `graph.json`;
    - void any arm whose `git status --porcelain` changed.
11. [non-blocking] Replace the third-judge majority with item-level consensus, or specify which counts enter the tally.
12. [non-blocking] Restate the search-share bound as search plus exploratory reads, citing the revised search report.
13. [non-blocking] Make the environment explicit and simpler:
    - graph-arm `GRAPHIFY_OUT` stays the scratch copy;
    - the ceiling block gives the exact raw `god-nodes` form;
    - drop the manual plugin-`bin/` PATH step, and run the PATH checks in-session or under `bash -ic`;
    - use one sandbox config dir, check token expiry first, and copy the transcripts out before deletion.
14. [non-blocking] Reconcile the worktree count: one pair per code state, realistic and ceiling sharing the graph worktree, with distinct cwds or an empty memory dir.
15. [non-blocking] State the realism gaps (top-level sessions, no marketplace plugins, the `source` graph), the keep prerequisites (the `source` condition, the stamp fix, `god-nodes` in the wrapper), and a cost estimate.
16. [non-blocking] Make the work executable in one session:
    - script the per-task driver;
    - run judges headless with file outputs;
    - make floor item 1 a records re-check;
    - apply the NOTE and inline-dependency cuts.

## Questions for the Maintainer

1. Which model should the arms run?
   - (a) `opus[1m]` (Opus 5.5), the container's user setting, at high effort.
   - (b) Opus 4.8, as weftwise's CLAUDE.md mandates for dispatched work, which matches the weftwise implementers the search report measured.
2. How large should the grep-vs-grep control be?
   - (a) A grep-B arm on all 10 tasks (+10 arms), which gives a per-task null.
   - (b) On 4 tasks, one per main class (+4 arms), which gives a rough spread.
   - (c) None; the rule's margins are then set by judgment, which weakens either verdict.
3. If only the ceiling arm gains (row 2), what follows?
   - (a) Validate the named steering change within Phase 5 on 3-4 tasks, and keep only if the realistic arm then gains.
   - (b) Drop now, and record the change as a revisit condition.
   - (c) Keep conditionally, as written.
