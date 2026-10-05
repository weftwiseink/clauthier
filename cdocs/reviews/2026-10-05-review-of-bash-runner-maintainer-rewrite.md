---
review_of: plugins/cdocs/agents/bash-runner.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T14:03:13-07:00
task_list: meta/token-spend-attribution
type: review
state: live
status: done
tags: [fresh_agent, maintainer_rewrite, bash_runner, live_canary, capture_collision, dangling_references, opencode_build, consistency]
---

# Review: Maintainer Rewrite of the Bash Runner (commit `6821b43`)

> BLUF(opus-5-5/bash-runner-rewrite-review): The loosened runner works: in 9 live runs every requested list was complete and exact, every report was 0.4-3.0K and named its capture file.
> Fix two runtime defects before it ships: the capture step's "Append" with no naming guidance makes concurrent and repeated runs share one file, in 5 of 9 runs; and the OpenCode build empties the block-scalar `description`.
> The orchestration-discipline diff also deleted the cross-target fallback for Pillars 1b and 3, which `oversee-arc.md` still points to, and left "Bash Output Hygiene" references in two files.
> Verdict: **Revise** (small, mechanical fixes; no restored rigidity).

## Summary Assessment

The rewrite reduces `bash-runner` to "run the command, capture it, summarize it", moves the prompt contract into the agent `description`, reshapes the report, and condenses caller guidance to three cases.
In that spirit it succeeds: the live canary ([`_verify/2026-10-05-bash-runner-rewrite-canary.md`](../devlogs/_verify/2026-10-05-bash-runner-rewrite-canary.md)) shows complete, correct reports without the old excerpt rules (17/17 twice, 64/64, 5/5 twice, 3/3 twice), with no re-runs and no command rewrites.
The most important finding is the capture step: "Append ... to a file in `/tmp/claude-<uid>/`" led runners to pick generic names (`run1.txt`, `out.txt`) at the top of the shared per-uid dir and `>>` into them, so runs polluted each other's captures, and three runners mis-stated which block was theirs.
The other findings are an empty `description` in the OpenCode build, dangling references left by the section deletions, and several typos, including `cdcos:bash-runner`.

## Section-by-Section Findings

### `agents/bash-runner.md`: capture step

**Major (blocking): "Append" plus free naming makes runs share and concatenate captures.**
Step 1 says "Append command stdout and stderr to a file in `/tmp/claude-<uid>/`" and gives no name.
In the canary, 7 of 9 runners used `>>`, and the names were `run.txt`, `run1.txt`, `out.txt` and `lf.txt`, at the top of `/tmp/claude-1000/`, which every session and project for that uid shares.
Five of the nine runs (C3, C5, C6b, C7a, C7b) wrote into a file that already held another run.
No final answer was wrong, because the outputs were identical or only had fewer failures.
But C3 read lines 742-1190, which were its sibling C2's copy, not its own, and reported an `Output:` line count covering two runs.
C6b's `see:` range points into C6a's run, and C7b claimed C7a's run as part of its own.
In a rerun whose new output contradicts the old, a runner that reads the first block would report stale results.
With two concurrent long runs, for example parallel worktrees running one suite, `>>` interleaves both processes' lines in one file, and no one can separate them afterwards.
The capture file is "the primary artifact the dispatcher reads", so its integrity matters.
Suggested fix (one clause, not a template): write with `>` to a fresh unique file, for example `out=$(mktemp /tmp/claude-$(id -u)/bash-runner-XXXXXX.log)`.
If "Append" was meant for stdout plus stderr, "redirect both stdout and stderr" says that.

**Non-blocking: the path itself is fine.**
`/tmp/claude-<uid>/` exists while Claude Code runs on Linux, and every runner ran `mkdir -p` anyway, so a missing dir is not a failure.
Nothing prunes the dir, but a unique-name fix bounds the growth to one file per run.

**Nit: no long-command timeout hint.**
The removed text told the runner to raise the Bash `timeout` (default 2 minutes) for builds and suites.
No canary command ran long enough to test this, and no runner set `timeout`.
A suite longer than 2 minutes would be killed mid-capture.
A half-sentence in step 1 is enough.

**Nit: the dedupe idiom is quadratic, and it is suggested for the case where that hurts most.**
The `difflib.SequenceMatcher` one-liner compares each line with every kept line.
On diverse `grep -rn` output, 2,000 lines took 56.6s, and 5,000 lines did not finish in 150s.
The text offers it for "_unreasonably_ large" files.
A cheap normaliser such as `sed -E 's/[0-9]+/N/g' | sort | uniq -c | sort -rn | head` (which runner C7b used unprompted), or a `head -n 2000` bound, avoids the trap.

### `agents/bash-runner.md`: frontmatter

**Major (blocking): the OpenCode build empties the `description`.**
YAML parses the block scalar correctly (yq gives the 6-line string), and the Claude Code parent in C1 quoted it in full.
But `scripts/build-opencode.ts` `parseFrontmatter` reads frontmatter one line at a time.
It keeps `description` = `|` and ignores the indented lines, so `build/cdocs/opencode/agents/bash-runner.md` gets `description: |` directly above `mode: subagent`, which parses as an empty string.
OpenCode then has no prompt contract and no trigger text for this agent.
Fix either side: a one-line `description` that keeps the contract, or block-scalar support in `parseFrontmatter`.
This agent is the first to use a multi-line value.

**Nit: `effort: medium`** is dropped by the OC build, which is expected since OC has no equivalent.
This review did not check whether Claude Code honours `effort` on a subagent.

**Nit: missing trailing newline.**
It is harmless to Claude Code and the build: the frontmatter regex does not depend on the end of the file.
Editors and `git diff` flag it, so add it with the other fixes.

### `agents/bash-runner.md`: body and report

- **Nit:** "Alwyas" should be "Always".
- **Nit:** the `Command:` placeholder mixes quotes: `with "...'>`.
- **Nit:** "detect unexpected" is missing a noun ("detect anything unexpected").
- **Nit:** `Output: ... (lines: <n> words: <n>)` counts words.
  Bytes predict read cost against the ~30K-character ceiling better than words do, so consider `wc -lc`.
  Runners followed the field as written.
- **Observation, not a defect:** with no spec, C2 named all 17 failing tests by suite and case, but gave no file:line and values for only 2.
  A caller fixing tests would follow up.
  The new `description` tells callers to say what they need, so this is a deliberate shift onto the caller, consistent with the intent.
- **Observation:** runners put lists in labelled sections or tables outside `Excerpt:` and wrapped excerpts in code fences.
  The loose format allows this, and it read well.

### `rules/orchestration-discipline.md`: new "Bash" section

**Nit (fix first): `cdcos:bash-runner` typo** on the line that names the agent (line 263).
In probe C5, a parent given only this text dispatched `cdocs:bash-runner` correctly, because the Agent tool's listing shows the real name.
It is cheap to fix, and the listing may not help every caller.

**Nits (typos and wording):**
- "You known what you need" should be "You know what you need".
- "if it more context is needed" should be "if more context is needed".
- "command is non-trivial flexibility is wanted" needs a comma: "command is non-trivial, flexibility is wanted".
- "When dispatching commands" means "when running commands".

**Nit: case 1's follow-up is ambiguous.**
"Then have a sonnet subagent extract important info" leaves the caller to guess which agent to use.
Pointing at `cdocs:bash-runner` over the capture file says what was meant.

**Nit: interactive commands.**
"Similar patterns can also be used for interactive or tty-dependent commands" is fine for the caller's own capture.
The runner no longer closes stdin, so if a caller dispatches a prompting command, the runner can block until the Bash timeout.
"Don't dispatch interactive commands" covers it in a few words.

### `rules/orchestration-discipline.md`: deletions

**Major (decision needed): the cross-target runtime fallback for Pillars 1b and 3 now exists nowhere, and `oversee-arc.md` still defers to it.**
The diff deleted the following:

1. **Pillar 3 `### Cross-target degradation`.** Without `SendMessage` or `fork`, durable specialists degrade to a fresh session started from the handoff doc plus the Iteration Log's event rows; the durable state is what makes that restart faithful.
2. **Pillar 3's `NOTE(claude-opus-4-8/overseer-alignment-phase3)`.** Pillar 3 is additive to Pillars 1, 1b and 2, and is discoverable by pointer from `workflow-patterns.md` and the `implement`/`propose` skills.
   Only provenance is lost: those pointers still exist (`workflow-patterns.md:37,55`, `implement/SKILL.md:19`, `propose/SKILL.md:144`).
3. **`## Cross-Target Degradation`**, which made four points:
   - (a) Rule content reaches OpenCode via the `/cdocs:init` glob. Still covered by the README "Rules Integration" section.
   - (b) Pillar 1b single-writer ownership and on-resume reconciliation fall back to a fresh session from the handoff plus the event rows. **Lost.**
   - (c) The chat record is Claude-Code-only, because its hooks and `bin/` script are not ported, so off Claude Code resumption reads the Scratchpoint and the latest handoff. **Mostly still covered:** Pillar 2 "Chat record" line 168 ("`chat-record` exists nowhere else"), and "Resumption" step 3 line 197 ("Without a record ... read your devlog's `## Scratchpoint` and latest handoff alone"), though step 3 names "a dispatched agent, or a project without `cdocs/_chat/`", not "another target".
   - (d) "The discipline still holds; only the primitive changes." **Lost.**

Dangling references:
- `plugins/cdocs/rules/oversee-arc.md:136`, "Consistent with how [`orchestration-discipline.md`] handles it", now refers to nothing.
- `plugins/cdocs/rules/oversee-arc.md:140`, "the same fallback Pillar 1b / Pillar 3 name", names a fallback neither pillar states any more.
  `skills/oversee/SKILL.md:170-173` defers to this section, so the gap reaches the skill.
- `cdocs/proposals/2026-09-17-target-setup-validation-and-verification.md:319` cites "Orchestration discipline (Cross-Target Degradation, isolation)".
- `cdocs/proposals/2026-09-22-chat-record-devlog-management.md:480` is a Phase 1a deliverable that edits the deleted section.
  It is historical and already implemented, so a NOTE at most.
- `/cdocs:init`, the README, and the other skills have no references to the deleted sections.

If the deletion was intended, `oversee-arc.md` needs its own one-line fallback, since the arc rule is the one that uses it.
If it was not, one sentence under Pillar 1b covers (b) and (d).

**Nit: the renamed section leaves stale pointers.**
"Bash Output Hygiene" no longer exists, but `rules/model-tiering.md:25` and `plugins/cdocs/AGENTS.md:47` still say "see 'Bash Output Hygiene'".

### Consistency: stale descriptions for a follow-up sync (not edited)

`cdocs/proposals/2026-09-22-haiku-bash-wrapper.md`:
- `:19` BLUF: captures "to a file in its own scratchpad".
- `:71`, `:115`: the agent is "modeled on `nit-fix.md`: ... Input, Workflow, Output Format, Constraints". The agent no longer has Input or Constraints sections.
- `:142-143`: the capture form `OUT="<scratchpad>/bash-runner-<ts>.log"`.
- `:151-160`: the old report block (`Exit code:`, `Full output: saved to ... (<bytes> chars, <lines> lines; <lifetime>)`, `Truncated` last).
- `:164-168`: the excerpt rules: command-only `Excerpt:`, the two-command aggregate excerpt, the exactness rules for `Truncated:`, and the ~12K complete-list allowance.
- `:170-171`: scratchpad lifetime.
- `:176`: the NOTE that "capture-first, the one-line `exit/out/bytes/lines/warn` summary, and the concise fixed-format report stay mandatory".
- `:54`, `:202`, `:303`, `:329`, `:364`: the "Bash output hygiene" section name.
- `:282-283`: "interactive commands ... should not be dispatched", which now differs from rules case 1.
- `:296-301`: capture location: scratchpad, `${TMPDIR:-/tmp}` fallback, 24h prune.
- `:339`: test plan capture path.
- `:355`: implementation checklist.
- `:383`: maintainer decision on capture location.

Other files:
- `plugins/cdocs/AGENTS.md:47`: the "Bash Output Hygiene" pointer.
- `plugins/cdocs/rules/model-tiering.md:25`: the "Bash Output Hygiene" pointer.
  `:26` ("a runner that drifts from the capture") is still accurate.
- `plugins/cdocs/README.md:106`: "its capture-then-extract contract is inlined in its prompt" is still broadly true.
  Part of the contract now lives in the `description`, so optionally update it.

No file still says "capture template".

### Not updated: `last_reviewed`

The subject is a commit to plugin files, and this review was told not to edit plugin files or the proposal, so no document's `last_reviewed` was updated.

## Canary Results

| run | fixture / spec | report body chars | correct vs ground truth | capture (shared?) |
|---|---|---|---|---|
| C1 | all-pass suite / "pass? totals" | 448 | yes (OK, 360/360) | `run.txt`, `>` |
| C2 | 17 failures / no spec | 1,344 | 17/17 named; 0 file:line; 2 values | `run1.txt`, `>>`, first writer |
| C3 | 17 failures / "every failing test" | 2,953 | 17/17 exact | `run1.txt`, shared; read C2's copy |
| C4 | grep sweep / "every real call site" | 1,647 | 64/64 set-exact | `lf.txt`, `>` |
| C5 | 17 failures / rules text only (typo probe) | 2,986 | 17/17 exact; dispatched the right name | `run1.txt`, shared |
| C6a | 5 failures / "every failing test" | 2,263 | 5/5 exact | `out.txt`, fresh |
| C6b | same, sequential | 2,009 | 5/5 exact; wrong `see:` range | `out.txt`, shared |
| C7a | 3 failures / same | 2,110 | 3/3 exact | `out.txt`, shared |
| C7b | same, sequential | 2,166 | 3/3 exact; mis-stated own block | `out.txt`, shared |

## Verdict

**Revise.**
The design direction is sound, and the live runs support it.
Before acceptance, the capture step must stop runs sharing a file, the OpenCode `description` must survive the build, and the maintainer must say whether the cross-target deletions were intended, which decides how `oversee-arc.md` gets fixed.
Everything else is a typo or a one-line sync.

## Action Items

1. [blocking] `bash-runner.md` step 1: write with `>` to a fresh unique file (for example `mktemp /tmp/claude-$(id -u)/bash-runner-XXXXXX.log`) instead of "Append ... to a file".
2. [blocking] Make the OpenCode `description` non-empty: either a one-line `description`, or block-scalar support in `scripts/build-opencode.ts` `parseFrontmatter`.
3. [blocking] Decide on the cross-target deletions. Then either restore one sentence for the Pillar 1b/3 fallback, or give `oversee-arc.md:136,140` its own wording and drop "Consistent with how `orchestration-discipline.md` handles it".
4. [non-blocking] Fix typos in `orchestration-discipline.md` (`cdcos:` to `cdocs:`, "You known", "if it more", the missing comma) and in `bash-runner.md` ("Alwyas", the `"...'>` quotes, "detect unexpected"), and add the trailing newline.
5. [non-blocking] Point `model-tiering.md:25` and `AGENTS.md:47` at the renamed "Bash" section.
6. [non-blocking] Add a half-sentence on raising the Bash `timeout` for commands over 2 minutes.
7. [non-blocking] Replace or bound the `difflib` dedupe idiom (quadratic: 2,000 diverse lines took 57s).
8. [non-blocking] Rules case 1: name `cdocs:bash-runner` as the follow-up extractor; add "don't dispatch interactive commands".
9. [non-blocking] Consider `wc -lc` (bytes) over words in `Output:`.
10. [non-blocking] Sync the proposal's stale spots listed under "Consistency", or add one NOTE pointing to `6821b43` as the current contract.

## Questions for the Maintainer

1. Were the Pillar 3 "Cross-target degradation" subsection and the "## Cross-Target Degradation" section meant to go?
   - (a) Yes: drop the back-reference in `oversee-arc.md` and state the fallback there.
   - (b) No: restore one sentence under Pillar 1b covering the fresh-session fallback and "the discipline still holds".
   - (c) Yes, and the cross-target story moves to the README or `oversee-arc.md` wholesale.
2. Was "Append" meant as "redirect both stdout and stderr", or as appending across runs?
   - (a) Redirect both streams: say "redirect" and use a unique file.
   - (b) Appending across runs is wanted: then the runner needs a per-run delimiter, and the report must give line offsets for its own run.
3. How should the OpenCode `description` be fixed?
   - (a) One-line `description`.
   - (b) Teach `build-opencode.ts` block scalars.
   - (c) Accept an empty `description` on OpenCode.
