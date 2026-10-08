---
review_of: cdocs/proposals/2026-10-06-nested-subagent-workflows.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T17:46:39-07:00
task_list: cdocs/nested-subagent-workflows
type: review
state: archived
status: done
tags: [fresh_agent, runtime_validated, test_plan, harness_safety, minimalism]
---

# Review: Nested Subagent Workflows (Round 2)

> BLUF(opus-5-5/cdocs/nested-subagent-workflows): R1's two design blockers are fixed in-text and well. The third (a runnable Phase 3) now names a harness, but that harness is not confined, and it does not force foreground dispatch below the top level.
> Verdict: **Revise** on one blocking item: run Phase 3 the way `chat-record.test.sh` actually does (a `git init` project outside any repo, a sandboxed `CLAUDE_CONFIG_DIR`, `env -i`, and `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`), not "in a scratch worktree" with a prompt instruction.
> Beyond that, the proposal grew from about 3,240 to 3,560 words, and roughly 700 of them restate decisions made elsewhere in the document.

## Summary Assessment

The revision answers r1 well.
The Nesting text scopes the fallback and "Stay thin" to loop leads, and `/oversee` keeps its run-it-yourself fallback.
The escalation line moved into the Composition contract, and every non-blocking item but one was taken.
What is left is the Phase 3 harness.
As written it would run a `bypassPermissions` `/oversee` inside a worktree of the real repo, with the user's real config dir and the stale installed plugin loaded.
Its foreground instruction also reaches only the top-level session, while the nested sessions are where background dispatch matters.
A headless probe run for this review confirmed the fix, and confirmed that the transcripts' `.meta.json` files make the layer checks exact.

## Round 1 Disposition

| R1 item | Status | Notes |
|---|---|---|
| 1 [blocking] loop lead without `Agent` | Resolved | The Nesting fallback sentence, Section 3's fallback, Edge Cases (`=2` vs `=1`), Section 4, and a design-decision bullet all agree. |
| 2 [blocking] "Stay thin" scope | Resolved | The second Nesting sentence scopes it. See finding 4 for a shorter wording. |
| 3 [blocking] runnable Phase 3 | Partly resolved | A harness, `jq` checks, and a deferral gate are named. The harness itself has the defects in finding 1. |
| 4 escalation into the Down line | Resolved | Includes the note that the question waits for live children. |
| 5 ablate sites and grep | Resolved | All four sites are listed and `inside a subagent` is in the grep. The live grep matches exactly the sites in the edit table, with no extras. |
| 6 reviewer rationale | Resolved | |
| 7 `chat_record` placement | Resolved | |
| 8 trim Nesting | Resolved as asked | The section is still 162 words (finding 4). |
| 9 triage "Top-level agent" column | Not taken, not mentioned | Acceptable, since it was framed as optional. |
| 10 CHANGELOG 2.1.187 and 2.1.217 | Resolved | |
| 11 rfp in Phase 1 | Resolved | |
| 12 nesting-disabled failure picture | Resolved | |

## Verification Performed

- Ran the Test Plan's static grep against today's tree. It hits exactly the sites in Sections 2 and 3, so the edit table is complete.
- Measured the deletion sites: about 235 words would be removed across `implement`, `implementer`, `proposer`, `reviewer`, `iterate`, `propose`, and `triage`.
- Read `plugins/cdocs/hooks/tests/chat-record.test.sh`. Its headless pattern is `mktemp` + `git init` projects "outside any repo", a sandboxed `CLAUDE_CONFIG_DIR` holding only copies of `.credentials.json`/`.claude.json`, `env -i` with plugin bin dirs stripped from `PATH`, and `--plugin-dir`. Its line 641 notes "Agents run in the background by default in 2.1.289", and it forces foreground with `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`. Its line 657 notes forks are gated behind `CLAUDE_CODE_FORK_SUBAGENT=1` in headless.
- Headless probe in that sandbox (`haiku`, `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`, main → child → grandchild). Both nested dispatches recorded `"requestShape":"foreground"`, the child received its grandchild's result synchronously, and the stream had no "Async agent launched". The env var is process-wide, so it does reach nested layers. The copied credentials were deleted afterwards.
- `subagents/agent-*.meta.json` carries `agentType`, `spawnDepth`, `parentAgentId`, and `requestShape`, both in that probe and in this session's own transcripts (a `spawnDepth: 3` general-purpose agent with a `parentAgentId` is present). The `subagents/` directory is flat, so this metadata is the reliable way to tell layers apart.

## Section-by-Section Findings

### Test Plan (live) and Verification Methodology

1. **blocking: the Phase 3 harness is not confined, and its foreground control does not reach nested layers.**
   - *Confinement.* "In a scratch worktree" means a worktree of this bare repo, which shares refs and the object store with `main/`. The run is `bypassPermissions` `/oversee`, whose agents commit, branch, and create implementer worktrees. It reads this repo's `CLAUDE.md`, which tells agents to "run `git merge --ff-only <worktree-branch>`" from `main/`. It also sees the real `cdocs/` corpus, which contaminates the fixture. Without a sandboxed `CLAUDE_CONFIG_DIR`, the user's settings, hooks, and the stale installed `cdocs@clauthier` all load next to the `--plugin-dir` copy. That last one is the very problem the paragraph cites as its reason for using the chat-record pattern. The proposal names the pattern, but its command contradicts it.
   - *Foreground.* "With the prompt telling every lead to dispatch in the foreground" reaches only the top-level session. The sub-overseer's brief comes from the Composition contract, and the implementer's comes from `iterate`, and neither carries it. Headless agents background by default (chat-record.test.sh line 641), and a headless lead does not wait for its children. So the sub-overseer could end before its loop does, and late results would land at the top: the confusion the Edge Cases section describes.
   - *Fix* (replacing the first live paragraph, at about the same length): "Run it with `chat-record.test.sh`'s `claude_run` setup: a `git init` fixture project outside any repo with no remote, a sandboxed `CLAUDE_CONFIG_DIR` holding only copied credentials, `env -i`, `--plugin-dir` at the plugin under test, and `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` (process-wide, so every layer dispatches in the foreground)."
   - Optionally add `--disallowedTools "Bash(git push:*)" "Bash(gh:*)"`. Real `HOME` stays reachable under `env -i`, which the existing harness accepts, but having no remote already removes the push path.

2. **non-blocking: make the checks deterministic, and read the layers from `.meta.json`.**
   - Replace the transcript `jq` with `jq -r '[.spawnDepth, .agentType, (.parentAgentId // "-"), .requestShape] | @tsv' subagents/*.meta.json`. The transcript-content query lists types per file but cannot say which file is layer 1. The metadata says so directly, and also proves foreground dispatch.
   - Check 1, "exactly one `Agent` call", is brittle: under "Stay thin" the arc overseer may legitimately dispatch `triage` or `bash-runner`. Assert the actual failure picture instead: exactly one depth-1 `general-purpose` sub-overseer, and no depth-1 `cdocs:implementer`/`reviewer`/`judge`.
   - Check 3 will often fail on a trivial fixture, because the Nesting text's own "don't nest work of a few lines" tells the implementer to run a quiet test inline. Make the fixture's test command emit a few thousand lines, so the Bash section's `bash-runner` guidance applies (as in the reviewer Story). Drop `fork` from the accepted helpers, or set `CLAUDE_CODE_FORK_SUBAGENT=1`, since forks are gated in headless.
   - Check 4's "the sub-overseer's dispatch and return rows" in the fixture devlog conflicts with Section 1, where `arc_state: in_progress` *is* the sub-overseer's dispatch row. Say "the loop's implementer and reviewer rows".

3. **non-blocking: the escalation failure picture is not exercised.**
   "A sub-overseer stalls looking for `AskUserQuestion`" cannot occur in an `--afk` headless run, and neither can the `SendMessage` resume path.
   Either say that the floor does not cover escalation and leave it to the optional interactive follow-up, or drop the picture.
   An unexercised failure picture reads as coverage that is not there.

### Proposed Solution 1: Nesting text

4. **non-blocking: the section can lose about 50 words with no change in meaning.**
   - "takes one writer per file, durable state for writers it starts, and the Bash section" lists sections that already self-scope: Bash applies to every agent, and one-writer applies to anyone starting writers. The only thing that needs scoping is "Stay thin". Suggested replacement: "'Stay thin' binds loop leads (any overseer, nested or not); any other agent stays the workhorse for its own task."
   - "Nesting stops three layers below the human session by default." is a runtime fact that the next sentence's "Without `Agent`" already handles, and it would rot if the default changed. Cut it.
   - With both cuts, the section is about 110 words.

5. **non-blocking: the "Resume from disk" qualifier and the Nesting scope disagree.**
   The qualifier reads as applying to any dispatcher ("log a child's dispatch and return when a resume would need it"), but the Nesting text does not give non-leads "Resume from disk".
   Finding 4's wording resolves this: every section except "Stay thin" applies wherever it is relevant.

### Summary and Test Plan (static)

6. **non-blocking: the word estimates contradict the `wc -w` gate.**
   The Summary's estimates (-250, +170, +100) sum to +20, yet the text says the gate "holds the implementer to a net reduction".
   Measured: about 235 words come out, and about 250 go in with a 162-word Nesting section, so the gate would likely fail as specified.
   Finding 4's cuts make it pass.
   Fix the estimates, or drop the Words column, which is itself a cut.

7. **non-blocking: the static grep will trip on the proposal's own wording.**
   Section 3 tells the implementer to write "run the loop itself when a sub-overseer returns that it cannot dispatch" into `oversee/SKILL.md`, which matches `cannot dispatch`.
   Word it as "returns without dispatching".
   Separately, the grep's `` no \`Task\` `` cannot be written inside a markdown code span: backslash escapes do not work there, so the span breaks. Use a fenced block, or a double-backtick span.

### Minimalism (whole document)

8. **non-blocking: about 700 words restate decisions made elsewhere.**
   In order of yield:
   - **Resolved Questions** (about 90 words): all three restate body decisions, and they are r1's answers, which is history the review and devlog already hold. Delete.
   - **What cdocs assumes today** (about 170 words): the first six sentences re-list Section 2's edit table file by file. Keep only the `/oversee` cost sentences.
   - **Stories** (about 200 words): "Four-proposal arc" and "Sub-overseer escalation" restate Section 3, and the implementer and reviewer stories restate the Nesting text. Keep at most the reviewer story, which justifies the `bash-runner` guidance.
   - **Important Design Decisions**: the "loop lead returns" and "Reviewers delegate reads" bullets restate Section 1 and the reviewer row. The "Agent depth is not devlog depth" bullet partly repeats Section 3. Keep the bullets that carry a rejected alternative (no schema, `/oversee` only, `tools:` not prose, keep `--dispatched`).
   - **Headless** appears three times (table row, Background NOTE, Edge Case). With finding 1 the NOTE can shrink to one sentence: background work does not outlive a headless lead, so the harness forces foreground.
   - Phase 3's "Check that the OC build still succeeds" repeats a static Test Plan item.

### Soundness spot checks (no finding)

- Depth budget, fallback, and devlog ownership are consistent across Sections 1 and 3, Edge Cases, and the design decisions.
- A `general-purpose` sub-overseer has `Agent` (`tools: *`), and resumed agents keep their spawn depth (2.1.187), so the `SendMessage` resume path holds.
- `full-send` staying unsplit, and leaves staying leaves by `tools:`, remain right.

## Verdict

**Revise.**
One blocking item: confine Phase 3 and force foreground dispatch process-wide (finding 1), which is a sentence-level replacement.
The design is accept-quality.
The minimalism cuts (findings 4, 6, and 8) are non-blocking, but they are the cheapest way to meet the proposal's own `wc -w` gate and the maintainer's preference for fewer words.

## Action Items

1. [blocking] Replace "In a scratch worktree, run ... with the prompt telling every lead to dispatch in the foreground" with the actual `chat-record.test.sh` `claude_run` setup: a `git init` fixture outside any repo with no remote, a sandboxed `CLAUDE_CONFIG_DIR` holding copied credentials only, `env -i`, `--plugin-dir`, and `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`.
2. [non-blocking] Read layers and foreground from `subagents/*.meta.json` (`spawnDepth`, `agentType`, `parentAgentId`, `requestShape`). Make check 1 "one depth-1 sub-overseer and no depth-1 implementer, reviewer, or judge". Give the fixture a verbose test command so the helper dispatch is warranted. Drop `fork` or set `CLAUDE_CODE_FORK_SUBAGENT=1`. Reword check 4 to "the loop's rows".
3. [non-blocking] Mark escalation and `SendMessage` resume as outside the headless floor, or drop that failure picture.
4. [non-blocking] Trim the Nesting text: replace the section list with "'Stay thin' binds loop leads; any other agent stays the workhorse for its own task", and cut "Nesting stops three layers ... by default".
5. [non-blocking] Reconcile the Summary's word estimates with the `wc -w` gate, or drop the Words column.
6. [non-blocking] Reword the oversee fallback to avoid `cannot dispatch` (the static grep matches it), and fix the grep's broken code span.
7. [non-blocking] Cut Resolved Questions, most of "What cdocs assumes today", most Stories, the duplicate design-decision bullets, and the headless repetitions (finding 8), aiming at about 2,800 words.

## Questions for the Author

1. Phase 3 floor and escalation coverage:
   - (a) The headless floor covers dispatch shape, depth, and fallback only. Escalation and resume go to the optional interactive follow-up (recommended).
   - (b) Add a second headless fixture, without `--afk`, built to hit a hard gate, and check that the sub-overseer returns the question instead of stalling.
2. The `wc -w` gate:
   - (a) Keep it as a strict reduction, and take the finding 4 cuts so it passes (recommended).
   - (b) Relax it to "not higher".
