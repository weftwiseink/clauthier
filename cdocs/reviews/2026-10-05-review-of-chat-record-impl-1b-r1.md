---
review_of: cdocs/proposals/2026-09-22-chat-record-devlog-management.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T13:20:54-07:00
task_list: cdocs/chat-record-devlog-management
type: review
state: live
status: done
tags: [fresh_agent, implementation_review, phase_1b, runtime_validated, hooks, portability, rules_check, test_plan]
---

# Review: Chat-Record Phase 1b Implementation (r1)

> BLUF(opus-5-5/cdocs/chat-record-devlog-management): **Revise.** `bin/chat-record`, the hooks, the tests, and the Pillar 2 text are faithful to the proposal and hold up under re-run: `--unit` 75/75, 26/26 headless assertions on the failure-picture scenarios, and an independently inspected 20-turn record with every `@user` closed by an entry and exactly one sign-off.
> Two blocking items: `escape_body`'s `sed 's/\r$//'` is very likely wrong on stock macOS sed, which CI cannot see, and the rules check fails.
> The rules check is a placement and salience problem, not an inherent one: the harness's compaction summary ends with "Resume directly... Pick up the last task", and step 3 sits mid-way through a 60KB imported rules file.
> A short "After a compaction" block outside that file moved haiku from 0 of 2 to 2 of 3 full passes in a small A/B run here, so the recommendation is that rules-side fix, not a hook.

## Scope and method

- Implementation: `git diff e3ea115..42e0b93 -- plugins .github` (`f3b4806`..`42e0b93`, 17 commits), the proposal, and the "Implementation Notes (impl-2, Phase 1b)" section of `cdocs/devlogs/2026-10-05-chat-record-devlog-management-iterate-phase1b.md`.
- Every run used sandboxes under this session's scratchpad (the suite's own `claude_run`/`drive` method, `env -i`, copied credentials, `--plugin-dir` at this worktree), Claude Code 2.1.289.
  Every credential copy was deleted afterwards, including the two stale `r7canary`/`r8canary` `.claude.json` copies the implementer flagged.
- Rules-check A/B arms ran against scratch copies of the plugin; no file in this worktree was edited.
- `plugins/cdocs/rules/orchestration-discipline.md` shows an uncommitted maintainer edit to "Bash Output Hygiene" (mtime 13:16, after `42e0b93`); it is unrelated to chat-record and was not reviewed or touched.

## Verification floor (re-run)

**Unit suite.** `plugins/cdocs/hooks/tests/chat-record.test.sh --unit` from the worktree:

```
chat-record tests: 75 passed, 0 failed
```

The same command from a fresh clone at `42e0b93` under `env -i HOME=<empty> PATH=/usr/bin:/bin` also gives `75 passed, 0 failed`, so CI's clean environment needs no local state.

**Headless subset.** `--headless --only '^(block_recover|plan_mode|uninitialized|top_level_only|compact|clear|background|no_tools)$'`, haiku: `chat-record tests: 26 passed, 0 failed`.

| scenario | artifact |
|---|---|
| `block_recover` | canary Stops `{"a":false}` then `{"a":true}`; record `@user`, `@Haiku-4.5` entry, `-- 4959a4e9` sign-off |
| `no_tools` | 2 Stops, 1 block, `U S` |
| `plan_mode` | one Stop `{"a":false,"pm":"plan"}`, no decision; record `@user` then `-- 5ff1b759` |
| `uninitialized` | `cdocs/` without `_chat/`: empty; outside git: no file; one Stop each, no decision |
| `top_level_only` | `cdocs:proposer` and `fork` dispatched; the proposer wrote and edited `cdocs/proposals/2026-10-05-verbose-flag.md` and ran Bash; the only `PreToolUse` chat-record call has `agent_id: null`; first Stop blocked |
| `compact` | `U A S U A S`, no line mentions compaction, `compact_boundary` present |
| `clear` | two records; the Bash id after `/clear` is new (`f051f5a8-...`); the first record ends at its sign-off |
| `background` | the envelope reached `UserPromptSubmit` but not the record; 2 Stops, 0 decisions |

**Multi-turn record.** `--only multi_turn` (20 resumed haiku turns under materialized rules, never told how to note): PASS on both gates.
An independent awk walk over the record (not the suite's `markers`) gives `users=20 ok_turns=20 bad=0 stray_notes=0 final_state=closed`.
Stop sequence: `U S S* U S U S S* ...`, 7 of 20 turns blocked once, never twice. 8 of 20 bullets exceed ~120 characters.

```
@user: 2026-10-05T13:15:16-07:00
Make cli.py exit with status 2 and a message on stderr when the file is missing; test it.

@haiku: 2026-10-05T13:15:24-07:00
- gist: Changed missing file error exit code from 1 to 2; verified with test of nonexistent.txt

-- 1abfef60 at 2026-10-05T13:15:25-07:00
```

**Failure picture:** no double block or loop (`block_recover`, `no_tools`, 20-turn sequence); no block in an uninitialized project, outside git, or in plan mode; no subagent or fork `chat-record` call, with a subagent that demonstrably did Bash and Write work under the rules.

## Section-by-Section Findings

### 1. `bin/chat-record` against the proposal

- **Stop logic: correct.** Last marker `@user:` blocks unless `stop_hook_active` or `plan`, falls through to the sign-off otherwise; any other `@` header signs off; a sign-off or no marker writes nothing.
  This matches the four table rows exactly, and escaped `\@user:` lines never match the anchored `grep -E`.
- **Escaping and header mimicry: correct on GNU.** Probes: `@user : x`, ` @user: y` (leading space), and a sign-off with a colonless offset stay body text, correctly unescaped; the round-trip fixture covers fences, `\@`, `\\@`, CSS at-rules, and CRLF.
- **[blocking] macOS portability of `escape_body`** (line 36): `sed -E -e 's/\r$//'`.
  POSIX leaves `\r` in a basic or extended RE undefined; GNU sed reads it as CR, while stock macOS (BSD) sed is generally reported to read it as a literal `r`.
  If so, on macOS every prompt and note line ending in `r` loses that letter ("use the bar" becomes "use the ba") and CRs survive: silent corruption of the verbatim record.
  I could not run BSD sed here, so this is unverified, but the fix is portable either way: `sed -E -e $'s/\r$//' ...`, using bash ANSI-C quoting so sed receives a literal CR.
  The existing round-trip test ("no CR survives") would catch it on a `macos-latest` runner. Everything else checked is portable: no `tac`, `date +%z` plus the `sed` colon insert, `tr -c`, `pwd -P`, `grep -E`, and bash-3.2-safe arrays and parameter expansion.
- **`--as` validation: correct.** `user`/`User`/`''`/`-x`/`_x` rejected; `'user '` maps to `@user-:`, which is not `@user:`, so it cannot forge a human turn or satisfy the `@user` case.
- **Activation gates: correct.** Walk stops at the first `cdocs/` and at the toplevel; `_chat/` above the toplevel is ignored; a `session_id` like `../../x` is rejected by `valid_sid`.
- **Stdout discipline: correct** for every real path (all `jq`/`git`/`cd` output captured or sent to stderr; `CDPATH` unset).
- **[non-blocking] Empty hook payload** (line 95): `printf '' | chat-record Stop` prints `f[0]: unbound variable` and exits 1, because `jq` emits nothing on empty input and `set -u` trips.
  The harness always sends a payload, so the impact is nil in practice, but it breaks the stated "hook mode always exits 0" invariant; guard with `[ -n "$meta" ] || return 0`.
- **Error handling: good.** Hook-mode write failures go to stderr with exit 0; agent modes `die` with one line; unparseable payloads are reported and skipped.

### 2. Test quality and CI

- The unit suite would catch most regressions that matter: grammar sourced from the script's own regexes, a reference splitter round trip, the Stop table row by row, stdout emptiness, speaker rules, activation, multiple matches, and union merge and rebase including add/add.
- **[non-blocking] CI has never run.** The workflow is not on the default branch (`gh run list` returns 404), so the success criterion "`--unit` green in CI" is satisfied only by the local clean-clone run above.
  The path filter (`plugins/cdocs/bin/**`, `plugins/cdocs/hooks/**` including `tests/`, the workflow itself) matches the proposal and covers everything the unit suite reads.
  Add `macos-latest` to a job matrix: it is the cheap verification for the blocking sed item.
- **[non-blocking] `rules_check` over-credits a lookup as a read.** Its devlog regex accepts `Bash ... grep ... cdocs/devlogs/`, so `grep -l "$p" cdocs/devlogs/*.md` counts as "Scratchpoint read".
  Two sonnet runs here passed that gate without ever opening the devlog. Require a `Read` of, or a `cat`/`sed`/`head` on, a devlog file path.
- **[non-blocking] `init_rules` order differs from `/cdocs:init`.** The test concatenates rule files alphabetically (frontmatter-spec first); init step 3 uses the AGENTS.md order (writing-conventions first).
  Since the rules-check result depends on where step 3 sits, the harness should materialize in init's order.
- **[non-blocking] `top_level_only` has no positive control.** In 2.1.289 `-p`, both "foreground" dispatches returned "Async agent launched successfully".
  The run here is still valid because the proposer wrote a file and ran Bash, but the scenario would pass vacuously if the subagents did nothing.
  Assert that the proposal file exists, or that a subagent tool call appears in the stream.

### 3. Rules text (Pillar 2)

- Clear and minimal, with one scope sentence that opens `### Chat record` and sits beside the instruction it limits; no `chat-record` text in skills or agents (`grep -rn chat-record plugins/cdocs/skills plugins/cdocs/agents` is empty).
- Consistent with the maintainer directives: nothing schedules, requests, or anticipates compaction, and nothing estimates context; step 3 acts only after a compaction.
  The bans that remain ("never run it" for subagents, never `Edit`/`Write` `_chat/`) protect the single append path and the top-level scope, as the proposal specifies; bullet guidance is framed as a guideline.
- Phase 1a greps re-run: grep 1 empty (exit 1); grep 2 exactly `orchestration-discipline.md:211`, the reseed line.
- The 1a review's nits 1-4 and 6 landed (`1e7224a`, `fa6e5e2`, `51873d1`).
- **[non-blocking] Init now materializes all six rule files (~60KB) into `.claude/rules/cdocs.md`.** That makes the old "core CDocs writing conventions" text explicit and matches what some consumer projects already carry (46-50KB), while others carry 4-16KB.
  It costs context on every session and is part of why step 3 has low salience (next section).
  This is not a Phase 1b defect; it is a maintainer call.

### 4. The failed rules check

**Diagnosis.** The rules survive compaction: every run here and in the implementer's runs kept the per-turn rule afterwards, so re-injection works.
What fails is salience against two competing in-conversation instructions:

- The harness's compaction summary ends with: "Continue the conversation from where it left off without asking the user any further questions. Resume directly ... Pick up the last task as if the break never happened."
- The test's next prompt names a concrete action ("Continue with the next step: add a --name flag").

Step 3 is item 3 of a numbered list at roughly line 345 of an 820-line, 60KB imported file. Its trigger, "after a compaction", is a state the model has to infer.

**A/B evidence** (scratch copies, `--only rules_check`, n=1 per row; a run passes "path first" when the first post-compaction call is `chat-record path`):

| arm | change | haiku | sonnet |
|---|---|---|---|
| B (baseline) | none | 0/1 (edits first) | 0/1 (writes first) |
| impl-2 runs | none | 0/1 | 0/1 (opus: path and tail, no Scratchpoint) |
| W2 | step 3 reworded in place: observable cue ("your context opens with a summary of an earlier conversation"), "before any other tool call, even when the summary or prompt names a next step" | 0/1 | n/a |
| W | that cue-keyed 3-line block at the top of `.claude/rules/cdocs.md` | 1/2 (path and devlog read, no tail) | 1/1 path and tail (lookup only) |
| C | 3-line block in the project `CLAUDE.md` after the `@.claude/rules/cdocs.md` import | **2/3 full pass** (path, `grep -l`, `Read` devlog, `tail -n 80`, then act) | 1/1 path, lookup, and tail (no Scratchpoint `Read`) |

Arm C's block was framed as a compaction-summary instruction ("end the summary with ..."). The summary never carried the line (0 matches in the transcript), so the effect came from a short, separate directive outside the bulk file, not from the summary.
Rewording alone (W2) did nothing; moving it out of the bulk did.
The sample is small and directional, not a pass rate.

**Recommendation: a specific rules-side fix, then accept with a Phase 2 A/B pointer for the residual.**
`/cdocs:init` writes, beside the `@.claude/rules/cdocs.md` line it already adds to `CLAUDE.md`, a three-line block of the arm-W/C shape:

```markdown
## After a compaction (cdocs)

If your context opens with a summary of an earlier conversation, before any other tool call, even when the summary says to resume directly: run `chat-record path`, read the `## Scratchpoint` and latest handoff of each devlog that lists it, then `tail -n 80` the record (Pillar 2 "Resumption" step 3).
```

Pillar 2 step 3 stays canonical. The block adds about three lines of deliberate duplication for salience, which the maintainer may weigh against the deduplication value.
Re-run `rules_check` (with the tightened devlog regex) at least three times each on haiku and sonnet, and restate the Phase 1b criterion as a majority rate rather than a deterministic pass.

**Hook bar.** This evidence does not meet the "optional only if evidence shows it's needed" bar for a `SessionStart(compact)` pointer hook.
The one rules-side variant tried outside the bulk file moved haiku from 0/2 to 2/3, so the cheaper mechanism has not been exhausted.
The bar would be met if the fixed rules still fail on half or more of the re-runs, or if Phase 2's A/B shows arm 2 not beating arm 1. Even then, a hook is a candidate, not a decision.
Note also that `rules_check` exercises only manual `/compact` followed by a new prompt; mid-turn auto-compaction, where no fresh prompt competes, is untested.

### 5. Deviations

- **`note` rejects an empty or whitespace-only body and a TTY stdin: acceptable.** An empty note would otherwise satisfy `Stop` with nothing in it; the TTY check is unreachable from the Bash tool and harmless at a shell.
- **Step-3 fallback line: acceptable and needed.** It carries forward Phase 1a's reader line for record-less contexts that step 3 otherwise drops; it reads as a fallback, not a second scope guard.
- **Header path `plugins/cdocs/hooks/cdocs-hooks.ts`: correct.** The proposal names this path; the dispatch's `scripts/` path does not exist.
- **No `PreToolUse` fallback: acceptable.** The trigger ("a subagent or fork entry") did not fire in the implementer's run or in the run here, and the run here had a positive control.

### 6. Other observations (non-blocking)

- The block text's `--as <your model>` yields drifting speakers (`Haiku-4.5`, `haiku`, `haiku-4-5` across runs).
  Within the 300-byte budget, `<your model id without claude->` would steer it.
- Seven of 20 haiku turns needed the block in both 20-turn runs, so the backstop does real work at haiku tier; watch the rate in the real opus session.
- The implementer's open items stand as written: the one-off plugin `bin/` PATH miss in `default_allowed`, and the same-second union-merge collapse (negligible).

## Interactive checks and usefulness sample: what the maintainer must run

Setup, once: an interactive `claude` in a scratch git project with `cdocs/_chat/` (and `.gitattributes` `*.md merge=union`), running this worktree's plugin once, not also `--plugin-dir` beside the installed copy, with `Bash(chat-record:*)` allowed or skip-permissions.
For payload capture in (b) and (d): run `CHAT_RECORD_KEEP=1 plugins/cdocs/hooks/tests/chat-record.test.sh --headless --only cmdv`, take `<kept>/headless/canary-plugin`, delete `<kept>/headless/cfg` at once, and start `CANARY_LOG=/tmp/canary.jsonl claude --plugin-dir <canary-plugin>`.

1. **(a) Forgotten note:** prompt "Read README.md and summarize it in one line. Do not run chat-record unless a hook tells you to." Expect one visible block, a note, and turn end; `tail -n 12 cdocs/_chat/*.md` shows `@user`, one entry, one sign-off.
2. **(b) Escape mid-tool-call:** prompt "Run `sleep 60` with Bash"; press Escape while it runs.
   Record: whether a `Stop` appears in `/tmp/canary.jsonl`, its full payload (look for any interrupt field), whether a block fired and the agent resumed, and whether the record ends in an unsigned `@user` or a sign-off.
   Decide per the proposal's Edge Cases: if `Stop` fires with an interrupt field and the block resurrects the agent, that field joins the sign-off row.
3. **(c) `/rename`:** `/rename review-canary`, then two short prompts; the second turn's sign-off reads `-- review-canary at <ts>`.
4. **(d) Mid-turn prompt:** prompt "Run `sleep 30` with Bash, then reply done"; while it runs, submit "also say hi".
   Expect canary order `UserPromptSubmit`, `UserPromptSubmit`, then `Stop`, and a record with two `@user` blocks, entries, and one sign-off, with at most one block.
5. **20-turn real session and usefulness sample:** create `cdocs/_chat/` (with the `.gitattributes`) in this repo, whose `CLAUDE.md` already imports Pillar 2, and work at least 20 real turns (Phase 2 under `/cdocs:iterate` is a natural fit).
   Step 1 lists the record in the devlog's `chat_record:`, and the record is committed with the devlog by explicit path.
   Check structure with: `awk -v H='^@[A-Za-z0-9][A-Za-z0-9._-]*:' -v S='^-- [A-Za-z0-9._-]+ at ' '$0~H{if($0~/^@user:/){if(st=="open"||st=="agent")bad++;st="open";u++}else if(st=="open"||st=="agent")st="agent";else x++}$0~S{if(st=="agent")ok++;else bad++;st="closed"}END{print u,ok,bad+0,x+0}' <record>` (want `N N 0 0`).
   Then dispatch a fresh reviewer to score 20 random entries (`grep -E '^- ' <record> | shuf -n 20`) on the successor test; pass at 16/20.
6. Write the results and a record excerpt into the devlog, with the interrupt and mid-turn decisions stated.

## Verdict

**Revise.** The implementation is careful and largely correct, and the failure picture is clean under independent re-run.
Two items block acceptance: the macOS CR-strip portability fix (with a macOS CI leg to prove it), and the rules-check gap.
For the rules check, the recommended fix is the short `CLAUDE.md`-adjacent block plus a rate-based re-run; the maintainer may instead accept the gap explicitly with a Phase 2 A/B pointer.
The interactive checks, the 20-turn real session, and the usefulness sample remain maintainer-run closure gates for Phase 1b, not implementer defects.

## Action Items

1. [blocking] `bin/chat-record` `escape_body`: replace `'s/\r$//'` with a CR that does not depend on sed escape support (`$'s/\r$//'`), and add `macos-latest` to the `cdocs-hooks.yml` job so the existing round-trip test verifies it.
2. [blocking] Rules check: either (a) have `/cdocs:init` write the three-line "After a compaction (cdocs)" block beside the `CLAUDE.md` import line and re-run `rules_check` at least 3x each on haiku and sonnet against a rate-based criterion, or (b) record the maintainer's explicit acceptance of the gap with a pointer to the Phase 2 A/B. The reviewer recommends (a).
3. [non-blocking] `hook_main`: return 0 when `meta` is empty, so an empty payload cannot exit 1 under `set -u`.
4. [non-blocking] `rules_check`: count only an actual devlog read (a `Read` of, or a `cat`/`sed`/`head` on, the devlog path), not `grep -l`.
5. [non-blocking] `init_rules`: concatenate rule files in `/cdocs:init`'s AGENTS.md order.
6. [non-blocking] `top_level_only`: assert that the proposer actually produced its file, so the no-leak check cannot pass vacuously.
7. [non-blocking] Block text: hint the `--as` format (`<your model id without claude->`) within 300 bytes.
8. [non-blocking] Maintainer: weigh the ~60KB always-loaded `.claude/rules/cdocs.md` that init step 3 now specifies.
9. [non-blocking] Maintainer: run the interactive checks (a)-(d), the 20-turn real session, and the usefulness sample per the list above, and record them in the devlog.

## Questions for the Overseer

1. Rules-check disposition:
   - (a) Apply the `CLAUDE.md`-adjacent block now and re-run at a rate criterion (recommended).
   - (b) Put the block at the top of `.claude/rules/cdocs.md` instead (no `CLAUDE.md` edit beyond the import line; weaker in this sample, 1/2 on haiku).
   - (c) Accept as-is with a Phase 2 A/B pointer.
2. Should the macOS CI leg be permanent, or a one-off verification of action item 1?
