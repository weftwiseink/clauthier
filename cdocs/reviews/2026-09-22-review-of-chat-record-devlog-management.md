---
review_of: cdocs/proposals/2026-09-22-chat-record-devlog-management.md
first_authored:
  by: "@claude-fable-5-1"
  at: 2026-09-22T18:43:06-07:00
task_list: meta/chat-record-devlog-management
type: review
state: live
status: done
tags: [fresh_agent, runtime_validated, hooks, chat_record, grammar, missing_validation, scope, architecture]
---

# Review: Chat Record, Scratchpoint, and Semantic Devlog Splitting (round 1)

> BLUF(fable-5-1/chat-record-devlog-management-review): **Revise.**
> The design is sound and the load-bearing hook claims are true: I re-derived every Phase-0 result from the raw canary logs and re-ran my own sandboxed canary on Claude Code 2.1.280 (commands and output below), and `PostCompact`, `PreCompact` (manual and auto), `SessionStart(compact)`, `Stop`, `UserPromptSubmit`, `PostToolUse`, and `SessionEnd` all behave as claimed.
> Five things block acceptance: (1) the canary evidence lives only in a garbage-collected session scratchpad and the proposal asserts rather than shows it; (2) `PostToolUse` **does** fire inside dispatched subagents (verified, `agent_id` set), so the proposal's `files=` buffer would silently absorb every subagent read, contradicting its "invisible by construction" claim; (3) the block grammar has a writer/reader regex mismatch and two undefined escapes that the Phase-1 unit test would be written against; (4) commit-by-default has an always-dirty-tree consequence and a secrets exposure the `WARN` understates; (5) "closed concern" does not yet decide one-chunk-or-many.
> Each is a bounded edit, so this is a warm-proposer revision, not a rewrite.

## Summary Assessment

The proposal operationalizes the chat-record report into three single-writer artifacts (hook-written chat record, agent-written Scratchpoint, semantically split devlog chunks) with a phased rollout gated on an A/B.
It is well-structured, honest about what the canary did not exercise (interactive `/compact`, `/clear`), and disciplined about scope: nothing here creeps into graphify or the token-cost half of the shared-cache idea, and the awareness-only framing of the gist log is stated three times so nobody can later cite it as a token saver.
The most important findings are empirical: the evidence behind the design is real but not reproducible from the document, and one hook-scoping assumption is wrong in a way that corrupts the `files=` data the design relies on.
Verdict: **Revise**, with all five blocking items resolvable by the same proposer in one pass.

## Independent Verification

I did not take the devlog's canary summary as ground truth.
I inspected the raw logs (`scratchpad/canary/canary{,2..7}.log`, `run*.in`, `run*.out`, `cfg*/settings.json`) and then ran two fresh sandboxed runs of my own with a recorder that logs `agent_id`/`agent_type` on every event, which the proposer's recorders did not do for `PostToolUse`.

**Re-derived from the proposer's logs (all consistent with the Phase-0 table):**

- Run 2 (`--input-format stream-json`, `/compact` line): `UserPromptSubmit` -> `PreCompact trigger=manual` (keys include `custom_instructions`) -> `SessionStart source=compact` (keys include `model`) -> `PostCompact trigger=manual` with a 2,782-char `compact_summary` -> `UserPromptSubmit` -> `SessionEnd`.
- Run 3 (`--autocompact 100000`): four `PreCompact/SessionStart(compact)/PostCompact` triples, `compact_summary` 6,910 to 9,126 chars, `compact_boundary` `pre_tokens` 71K to 88K.
- Run 4: the model listed `MARKER_SESSIONSTART_COMPACT_3333`, `MARKER_PRECOMPACT_1111`, `MARKER_POSTCOMPACT_2222` post-compaction, so `additionalContext` from all three compaction-adjacent hooks reaches the model.
- `--include-hook-events` emitted `hook_started/hook_response` only for `SessionStart` and `UserPromptSubmit`, never for `PreCompact`/`PostCompact`, exactly as the Verification Methodology says.
- Run 5 (background `Agent`): `UserPromptSubmit` -> `SubagentStart` -> `SubagentStop` -> `Stop` -> `UserPromptSubmit` -> `Stop`; no `UserPromptSubmit` between `SubagentStart` and `SubagentStop`.
  The second `UserPromptSubmit` prompt (read from the sandbox transcript) begins `<task-notification>\n<task-id>...`, so the `@harness` allowlist entry is grounded in a real payload.
- Built-in `/compact` sent as a user line did **not** fire `UserPromptSubmit` (run 2), so slash-command turns are not uniformly captured (see non-blocking finding below).

**My own runs (2026-09-22, CC 2.1.280, `--model haiku`, sandboxed `CLAUDE_CONFIG_DIR`, hooks on `UserPromptSubmit`, `PostToolUse` matcher `Read|Edit|Write`, `Stop`, `SubagentStart`, `SubagentStop`):**

Run A, foreground `Agent` dispatch whose subagent `Read`s `./a.txt`:

```
{"ev":"UserPromptSubmit","agent_id":null,"agent_type":null,...,"sid":"eb26e17e"}
{"ev":"SubagentStart","agent_id":"a4594b2d6044776a4","agent_type":"general-purpose",...}
{"ev":"PostToolUse","agent_id":"a4594b2d6044776a4","agent_type":"general-purpose","tool":"Read","path":".../rv/proj/a.txt",...}
{"ev":"SubagentStop","agent_id":"a4594b2d6044776a4",...,"lam":"sub-ok",...}
{"ev":"Stop","agent_id":null,"agent_type":null,...,"lam":"parent-ok",...}
```

Two facts: `UserPromptSubmit` fired once (the subagent's prompt did not fire it, confirming the scoping claim on the foreground path the proposer did not test), and **`PostToolUse` fired for the subagent's `Read` with `agent_id` set**.
The official hooks reference says the same: "When a subagent calls a tool, tool events such as `PreToolUse` and `PostToolUse` fire the same configured hooks as in the main conversation, and the input carries the `agent_id` and `agent_type`" (https://code.claude.com/docs/en/hooks.md).

Run B, `claude -p "/echo hello-world"` with a project command `.claude/commands/echo.md`:

```
{"ev":"UserPromptSubmit",...,"prompt":"/echo hello-world",...}
{"ev":"Stop",...,"lam":"SKILL_RAN hello-world",...}
```

Skill invocations fire `UserPromptSubmit` with the raw `/cmd args` string (not the expanded skill body); built-in `/compact` does not (run 2).

**External state checked:** [#13572](https://github.com/anthropics/claude-code/issues/13572) is closed as not planned (stale), not open; [#14258](https://github.com/anthropics/claude-code/issues/14258) is closed and `PostCompact` is in the official hooks lifecycle table with `manual|auto` matchers.
`claude --help` on 2.1.280 says `--resume <session-id>` "continues that session ... under the same ID", which supports the same-file-on-resume claim; `/clear` remains unverified as the proposal says.

## Section-by-Section Findings

### BLUF, Summary, and the Phase-0 NOTE

**[non-blocking] Cite the platform, not only the canary, for `PostCompact`.**
The correction to the chat-record report is right, but the strongest citation is the official hooks reference, which lists `PostCompact` with `manual|auto` matchers; the canary then confirms payload shape (`compact_summary`, `trigger`).
Also state that #13572 is closed-stale and #14258 is closed, since both are cited as if live; the report's caveat was precautionary and the proposal should say the precaution no longer has an open issue behind it (it can keep the ranking on the interactive-path gap alone).

### Chat record: location and naming

**[blocking, part of the grammar item] File lookup and collision handling are unspecified.**
The filename date is "the local date of the session's first recorded event", so on a `--resume` the next day the hook cannot reconstruct the filename from today's date.
Specify: locate by glob `cdocs/_chat/*-<sid8>.md`; create only when the glob is empty.
Record the full `session_id` on the `@session ... start` line (`sid=<uuid>`) so a same-day `sid8` collision (birthday-bound negligible at 32 bits, but the hook must not silently append to a stranger's file) is detectable: if the glob hits a file whose first line carries a different `sid=`, fall back to the full id in the filename.

**[blocking] Commit-by-default is under-analyzed on two axes (judgment call (a)).**
The `WARN` covers "anything pasted into a prompt".
It does not cover:

1. `@<model>` bodies and `@compact` summaries: an assistant that echoes a `.env` value, a token from a tool result, or a credential path lands it in git via the hook, with no human paste involved.
   The compaction summarizer in particular condenses tool outputs the proposal explicitly says compaction should drop, and run 3 shows those summaries are 7-9KB each.
2. The always-dirty tree: the record grows on every turn, so `cdocs/_chat/<file>` is modified at every moment a commit happens.
   Any agent in the same worktree that runs `git add -A`, `git commit -a`, or a "commit everything" step (implementer subagents routinely do) sweeps a half-turn chat record into an unrelated commit, and every commit made by the overseer itself is stale the moment the next `Stop` fires.
   This interacts with the repo's "each logical unit of work is its own commit" rule.

Verdict on (a): keep writing on by default (the hook's value is in never depending on discipline), but the proposal must (i) name both exposures in the `WARN`, (ii) specify the commit protocol as explicit-path adds by the overseer at handoff (`git add cdocs/_chat/<file>` alongside the devlog) with a one-line rule that dispatched agents never stage `cdocs/_chat/`, and (iii) either add a cheap redaction pass in the hook (a small regex set for common token shapes, applied before the `printf`, documented as best-effort) or state plainly that redaction is out of scope and the maintainer accepts the exposure.
A `.gitignore`-by-default alternative is legitimate for repos with untrusted pastes and should be offered as the documented opt-out it already is, with the worktree caveat kept.
See the options at the end of this review.

**[non-blocking] Pillar 1 says the overseer does not commit code; say that devlog-class commits are the carve-out.**
The proposal assigns commit responsibility to the overseer.
`orchestration-discipline.md` Pillar 1 lists "commit code itself" as a thing the overseer does not do.
In practice overseers commit devlogs; add a clause that chat-record commits are devlog-class bookkeeping commits, so a future nit-fix does not read the two texts as contradictory.

### Chat record: block grammar

**[blocking] The header-detection regex is not pinned, and the writer and reader are specified against different patterns.**
The bullet says the writer escapes "any body line that would match `header`", where `header := "@" speaker ":" (" " meta)? "\n"` requires either end-of-line or a space followed by a valid timestamp.
The reader is specified against the loose prefix `^\\+@[A-Za-z0-9][A-Za-z0-9._-]*:`.
A pasted Slack line `@alice: can you look at this`, a LESS variable `@brand-color: #333;`, a CSS `@page:first {`, or a Razor `@Model:` line does not match the strict `header` production (the text after the colon is not a timestamp), so a writer following the strict reading would not escape it, while a reader following the loose reading would split a block there.
Fix: define one regex, `HEADER_RE = ^@[A-Za-z0-9][A-Za-z0-9._-]*:`, and state that both the writer's escape test and the reader's split test use exactly that prefix, with everything after the colon on a real header parsed as meta.
The escape/unescape rule itself (add one backslash to any line matching `^\\*HEADER_RE`, strip one from any line matching `^\\+HEADER_RE`) is correct and round-trips; only the trigger pattern is ambiguous.

**[blocking, same item] Two value escapes are undefined.**
`value := ... "\"" (escaped chars) "\""` never says what is escaped; `files=` values contain paths that can include `"` and `,`, and `instructions="<custom_instructions>"` carries the steering text, which is 300+ chars in the proposal's own example and can contain newlines when a user pastes it.
A newline inside a quoted value breaks "metadata lives on the header line only".
Specify: inside quotes, `\\` and `\"` are the only escapes, and `\n`/`\r` in a value are written as the two-character sequences `\n`/`\r`; a reader unescapes those four.
Add the multi-line-`instructions` case and a path containing `"` to the adversarial fixture.

**[non-blocking] Say what a body line is when the prompt itself begins with a header-shaped line.**
Covered by the escape rule, but worth one sentence in the Edge Cases entry so the fixture includes "prompt whose first line is `@user: ...`" (a user pasting a chat record starts exactly this way).

**[non-blocking] CRLF and trailing whitespace.**
State that the writer normalizes `\r\n` to `\n` in bodies or that the reader tolerates `\r` before `\n`; a pasted Windows transcript otherwise carries `\r` into the header regex's `$`.

### Chat record: hook contract

**[blocking] `PostToolUse` fires inside subagents; the turn buffer needs an `agent_id` guard.**
The contract says "a dispatched haiku-wrapper read never reaches the buffer" and Edge Cases says subagent reads are "invisible here by construction".
Run A above shows the opposite: a subagent's `Read` produced a `PostToolUse` event with `agent_id` and `agent_type` populated, and the docs say this is by design.
As specified, an overseer turn that dispatches a reviewer would end with `files="r:<every file the reviewer read>"` on the overseer's `@<model>` block, which is exactly the wrong signal for the awareness use (the overseer did not read them) and would make the Scratchpoint's "hook list is the exhaustive complement" statement false in the other direction.
Fix: the hook exits early on every event whose payload carries `agent_id` (the documented "present only when the hook fires inside a subagent call" field), which is also the cleaner mechanical basis for the overseer-only scoping claim in Non-Goals than "`UserPromptSubmit` does not fire in subagents" (true, but an observation about one event rather than a documented guard).
Add a test-plan scenario: an `Agent` dispatch whose subagent reads a file, asserting the parent's `@<model>` block carries no `files=` for it.
Whether subagent reads should instead be recorded somewhere (with an `agent=` tag) is the Phase-3 question in the "Subagent-Level Capture" section below; for Phase 1, exclude them.

**[non-blocking] `NotebookEdit` uses `notebook_path`, not `file_path`.**
The buffer append should read `.tool_input.file_path // .tool_input.notebook_path`.

**[non-blocking] `last_assistant_message` is the final text block of the turn, not everything the user saw.**
In a multi-tool turn the model emits text between tool calls; `Stop` delivers only the last text.
State this, and add one line to the rule text: the overseer ends each turn with a short turn summary as its final message, so the captured block is summary-shaped by construction (this is also the answer to the maintainer's steering, below).

**[non-blocking] Slash-command turns are captured as the invocation string, and built-in commands are not captured at all.**
Run B: `/echo hello-world` fires `UserPromptSubmit` with `prompt="/echo hello-world"`, not the expanded skill body.
Run 2: `/compact` fires no `UserPromptSubmit` (the `compact-begin` line covers that one).
In this repo most substantive user turns are `/cdocs:*` invocations, so the record will contain `/cdocs:propose-revise --first-round ...` lines, which is fine and arguably ideal (short, exact), but the proposal should say so and add a test-plan assertion for a user-defined command; the Phase-1 implementer should also check `/clear` and `/resume` for `UserPromptSubmit` side effects.

**[non-blocking] Model identity: `SessionStart(compact)` carries `model`.**
Canary runs 2 and 3 show `model` in the `SessionStart source=compact` payload.
The hook can cache that per session (in the runtime dir) as a second source for `<model-short>` when the transcript lags, reducing `@assistant` fallbacks.

### Post-compaction reseed pointer and the mtime heuristic (judgment call (c))

**[non-blocking, strongly recommended] Replace the checkout-wide mtime heuristic with session-scoped tracking the hook already has.**
Verdict on (c): reject as the primary mechanism, keep as the last fallback.
The `PostToolUse` hook is already wired on `Edit|Write`; when `agent_id` is null and `tool_input.file_path` matches `cdocs/devlogs/*.md`, record that path in `${XDG_RUNTIME_DIR}/cdocs-chat/<session_id>.devlog`.
That is "the devlog this session last wrote", which is exactly the "active devlog" the autoflush RFP asked how to find, and it is per-session, so two sessions on one checkout cannot cross-contaminate.
Second fallback: `grep -l "<sid8>" cdocs/devlogs/*.md`, which finds the devlog whose `## Chat Record` section the agent wrote (the proposal already has the agent record the path there).
Third fallback: the mtime heuristic as written.
This costs nothing beyond one `case` branch and resolves the "two sessions" edge case rather than documenting it.

### Compaction steering

**[non-blocking] Clarify the steering string is for humans to type.**
Under Phase 3 the proposal correctly notes agent-invokable compaction does not exist ([#71803](https://github.com/anthropics/claude-code/issues/71803)).
The Compaction Steering section says "the overseer ... runs `/compact ...`", which an agent cannot do; say "the user runs, or the `/cdocs:compact` skill prints for the user to run".

### Scratchpoint

**[non-blocking] Sound; two small tightenings.**
The `files:` gist list and its awareness-only framing are exactly what the mid-round steering asked for and are consistent with the redundancy-check report.
(1) Bound the block explicitly ("roughly fifteen lines" appears once; make it a rule: at most 15 lines, at most 8 `files:` entries, older entries roll into the handoff).
(2) The staleness rule ("older than two iterations is `signal_missing`-equivalent") should name the judge field it maps to so the judge agent can be updated mechanically in Phase 2.

### Devlog splitting

**[blocking] "Closed concern" needs a closure test and a one-vs-many rule.**
Two agents given the same 20KB devlog would not reliably produce the same split today:

- Phase 2 deliverable 3 says "split at the most recent closed concern"; "Where to cut" says a chunk is *a* closed concern and moves everything belonging to it.
  If three phases have closed since the last split, is that one chunk or three?
- Nothing says how closure is recognized.
  A "resolved investigation" can be a paragraph; a "finished sub-loop of rounds" can be a table slice.

Proposed rule to adopt: a concern is closed when (i) it has a heading of its own (H2 or H3), (ii) every Open Todo in the most recent handoff that names it is done or has been moved to the root's current handoff, and (iii) no live table in the root still receives rows for it.
At a split, move **every** closed concern, one chunk per closed concern, except that concerns under ~3KB merge into the adjacent closed chunk (a chunk should be worth opening alone).
Rows in shared tables (Changes Made, Verification) move with the concern that produced them; a row that belongs to two concerns stays in the root.
This turns the split into a decision two agents make the same way and makes the Phase-2 dry-run scoreable.

**[non-blocking] `part_of` on the chunk and `status` semantics.**
Say what `status` a chunk carries (`done`, since it is a closed concern by definition) so `/cdocs:triage` does not flag chunks as stale `wip`.

### Edge Cases, Test Plan, Verification Methodology

**[blocking] The Phase-0 evidence is asserted, not shown, and lives in a session scratchpad.**
The document reproduces the recorder script and a sketch of the commands (`<prompt>`, "a `{...}` line"), and the results table is a summary.
The seven `settings.json` files, the exact command lines, the two `run*.in` stream-json inputs, the per-event payload-key lines, and the run-4 marker output exist only under `/tmp/claude-1000/.../scratchpad/canary/`, which is session-scoped and will be collected.
The proposal's own Verification Methodology says a failing assertion must show the actual shape; a reviewer in a week could not check any row of the Phase-0 table.
Fix: write `cdocs/devlogs/_verify/2026-09-22-chat-record-hook-canary.md` (the `_verify/` precedent the proposal itself cites) containing, per run: the `settings.json`, the exact `claude` invocation, the `run.in` where used, and the canary-log lines with `transcript_path` and `cwd` elided; link it from Phase 0.
Also: Phase 0 says "Six headless runs", the BLUF and devlog say seven, and there are seven configs; and the "real payloads from the Phase-0 canary" example is a composite (prompt_id `407cc386` is from run 2, the timestamps are run 4's, `files="r:a.txt,rw:b.txt"` is run 7's, and no run wired `UserPromptSubmit` together with `PreCompact`).
Label it "composite of runs 2, 4, and 7" rather than "real payloads".

**[non-blocking] Test plan additions from this review.**
Add: subagent `Read` produces no `files=` on the parent block (Run A); user-defined slash command captured as invocation string (Run B); `instructions=` with an embedded newline round-trips; `SessionStart(compact)` `model` field present.

### Important Design Decisions

Decisions 1 through 11 are internally consistent and follow from the report.
Decision 7 (steering primary, hooks secondary) is fine to keep, but its rationale should be updated per the #13572 finding above: the interactive path is unverified, not "reported broken".

### Non-Goals and scope discipline

Confirmed: graphify is named out of scope with no dependency; the shared-cache token-cost half is named out of scope with an explicit "makes no claim that the gist log reduces the 97.4% figure"; memory tool and cheap-model distillation are excluded with citations; the interactive `/compact` path is a named Phase-1 manual check in three places (NOTE, Decision 7, Test Plan).
No scope creep.
The one wording fix: the subagent-scoping non-goal should rest on the `agent_id` guard (documented) rather than on the `UserPromptSubmit` observation alone (see the blocking hook-contract item).

## Judgment Call (b): `Stop`-Captured Assistant Turns, Verbatim via Hook vs Summarized via Skill Convention

The coordinator relayed a maintainer preference: capture at the turn-handback point, agent turns summarized rather than verbatim, user turns verbatim via hook; and if hook wiring is unreliable, make agent-turn capture a skill convention like devlog maintenance.

Verdict: **keep the `Stop`-hook verbatim capture of `last_assistant_message`; do not switch to a skill-convention summary.**
Reasoning:

1. `Stop` *is* the turn-handback point.
   It fires exactly when the turn is about to return to the user (run 5 and Run A show it after the last tool call, after `SubagentStop`), so the maintainer's trigger preference is satisfied mechanically, with no mid-turn writes.
2. What `Stop` captures is already summary-shaped.
   `last_assistant_message` is the final text block of the turn: not tool calls, not tool results, not intermediate reasoning, not file contents (Decision 10 already excludes those).
   In an overseer session that final message is the agent's own report of the turn to the user, typically a few hundred to two thousand characters.
   The file-size concern is real but misattributed: in run 3 four `@compact` bodies totaled ~33KB in three minutes, while the `Stop` bodies were one line each.
   If anything needs bounding it is `@compact`, and the fix there is not truncation but noting that auto-compaction summaries are the size driver and are re-readable by offset.
3. A skill-convention summary per agent turn would be a third summary layer.
   The Scratchpoint is the agent-written, judgment-bearing, per-turn summary of *state* (replace-in-place); the devlog handoff is the per-task-unit summary of *decisions*; the devlog-value report rejects adding another summarization pass, and the autoflush RFP names the exact failure mode of convention-only capture (the model does not write it when it matters most).
   Asking the agent to also write a per-turn narrative summary into a hook-owned file would additionally break single-writer ownership (Decision 4) or require a fourth file.
4. Cost.
   The hook capture is zero LLM tokens; a per-turn convention summary costs an LLM write every turn and competes with the Scratchpoint for the same discipline budget.

What the proposal should change in response: (i) state explicitly that `last_assistant_message` is the final text block only, and (ii) add a one-line rule that the overseer ends each turn with a short turn summary as its final message, so the hook-captured block is a summary by construction rather than by luck.
That gives the maintainer "summarized agent turns at the handback point" without a new convention to enforce.
Degradation: if the `Stop` hook proves unreliable interactively (the Phase-1 check), the fallback is the Scratchpoint plus that end-of-turn-summary rule, not a new per-turn artifact.

## Strategic Question: Does This Obviate Native Auto-Compaction?

The coordinator asked for an explicit position.
**No, not for the top-level session, and the proposal should say so in one section rather than leave the report's "negate the utility of `/compact`" framing implicit.**

- Compaction cannot be prevented by the agent today.
  Agent-invokable compaction does not exist ([#71803](https://github.com/anthropics/claude-code/issues/71803)); `/compact` and `/clear` are user actions.
  In AFK `oversee` runs and headless `-p` sessions nobody types either, so auto-compaction is the *only* trimming mechanism, and run 3 shows it firing four times in three minutes under a 100K window.
- Context growth is not fully agent-controlled: tool results, harness notifications, and reseeded rules arrive unbidden.
- Durable specialists (Pillar 3) are the exception: their "compaction" is the ~1M sawtooth reset, and Phase 3's cap-and-reseed is a dispatch-level primitive the overseer does control, so for subagents the system genuinely can make compaction never run.

What the system does achieve, and how the ambition should be restated: it makes the *content* of the compaction summary irrelevant.
With a Scratchpoint at most one turn stale, a handoff, a chat-record tail, and a `SessionStart(compact)` pointer that says "read those, not the summary", compaction becomes a mechanical trimming event whose summary quality no longer determines resumption quality.
The proposal's goal sentence ("make lossy cold compaction unnecessary") should become "make the compaction summary's quality irrelevant to resumption, and make compaction rare at task-unit boundaries", which is what the design actually delivers.

One concrete recommendation that follows: the Phase-2 A/B has two arms (durable-state resume vs summary-only resume).
Add a third arm, `/clear` followed by reseed from durable state, with no summary at all.
If that arm ties the scratchpoint arm, then for the interactive path a hard reset is strictly cheaper than steered compaction (no summarizer call, no 30-second pause, no 7-9KB `@compact` block), and `/cdocs:compact` should print `/clear` plus a resume pointer instead of `/compact <steering>`.
That is the closest this design can get to obviating compaction: auto-compaction stays as the safety net for unmanaged sessions, and its role shrinks to "trim when nobody checkpointed", which the Scratchpoint staleness signal makes visible to the judge.

## Subagent-Level Capture: A Phase-3 Open Question, Not a Round-1 Requirement

The coordinator asked whether chat-record-like capture should extend below the overseer.
Assessment, split by subagent kind, because the answer differs:

- **One-shot legs (reviewer, judge, most implementer legs, forks).**
  Already covered for free: the dispatch brief is written by the overseer (and, inside `iterate`, logged in the Dispatch/Return Events table), and the leg's return summary is its checkpoint at the only agent-controllable eviction boundary.
  Nothing to add, and the report's reasoning holds.
- **Durable specialists carried warm across rounds.**
  This is where the maintainer's instinct is right that the need does not stop at the human boundary, and the Scratchpoint already *is* the state half: the proposal names durable specialists as Scratchpoint writers in the devlog they own.
  What the Scratchpoint does not give them is the chronology half: which dispatches they received in which order and what they returned each time, which is what a compaction-equivalent sawtooth reset loses.
  The mechanical pieces exist and are cheap, and I verified them: `SubagentStart` and `SubagentStop` fire per leg with `agent_id`/`agent_type`, `SubagentStop` carries `last_assistant_message` (the return, already a summary by construction) and `agent_transcript_path` (the sandbox shows subagent transcripts at `<session>/subagents/agent-<id>.jsonl`, whose first user message is the dispatch prompt), and `PostToolUse` fires inside the subagent with `agent_id`, so a per-agent `files=` list is the same buffer keyed by `agent_id` instead of `session_id`.
  A `cdocs/_chat/YYYY-MM-DD-<sid8>-<agent8>.md` record with `@dispatch` (from the transcript's first user message, or a summary of it) and `@<model>` (from `last_assistant_message`) blocks is therefore the same script with one more `case` branch, not a new mechanism.

Recommendation: add it to the proposal as an explicitly scoped Phase-3 investigation item ("subagent chronology record for durable specialists"), gated on two things: the Phase-1 `agent_id` guard landing (it is the same dispatch), and evidence that durable specialists are actually kept warm across enough rounds in practice to lose chronology (the token-spend report's 18-round implementer is one data point).
Do not design it now; do say why one-shot legs are excluded (return summary suffices) and that the Scratchpoint already covers the state half, so a subagent record would be additive chronology only, in the same way the gist log turned out to be the non-redundant half of the shared-cache idea.

## Verdict

**Revise.**
The architecture, scoping, and phasing are right, and the hook results are true (I reproduced the ones that matter).
The blocking items are all bounded edits to specification text plus one evidence file; none reopens a design decision.
Route to the same proposer.

## Action Items

1. [blocking] Write `cdocs/devlogs/_verify/2026-09-22-chat-record-hook-canary.md` with per-run `settings.json`, exact `claude` command lines, `run*.in` inputs, and the canary-log lines (paths elided); link it from Phase 0; fix "six" vs seven runs; relabel the example record as a composite of runs 2, 4, and 7.
2. [blocking] Add an `agent_id` guard to every chat-record event (exit early when present); correct the "invisible by construction" statements about subagent reads; rest the Non-Goals scoping claim on the documented `agent_id` field; add the subagent-`Read` test scenario.
3. [blocking] Pin the grammar: one `HEADER_RE` prefix used by both writer and reader; define quoted-value escapes (`\\`, `\"`, `\n`, `\r`); specify file lookup by `*-<sid8>.md` glob and a full `sid=` on the start line for collision detection; extend the adversarial fixture accordingly.
4. [blocking] Commit-by-default: extend the `WARN` to assistant bodies and compaction summaries; specify explicit-path staging at handoff and "dispatched agents never stage `cdocs/_chat/`"; choose and state a redaction stance (best-effort regex pass in the hook, or explicitly accepted exposure).
5. [blocking] Define "closed concern" with the three-part closure test and the move-every-closed-concern, one-chunk-per-concern, ~3KB-merge rule; say chunks carry `status: done`.
6. [non-blocking] Replace the mtime heuristic with session-scoped tracking (last `cdocs/devlogs/*.md` this session `Edit`/`Write`'d, recorded by the already-wired `PostToolUse` hook), then `grep -l <sid8>`, then mtime.
7. [non-blocking] State that `last_assistant_message` is the final text block only, and add the rule that the overseer's final message each turn is its turn summary; keep `Stop` capture verbatim (judgment call (b) verdict).
8. [non-blocking] Add a "Relationship to native auto-compaction" section per the strategic section above, restating the objective as "make the summary's quality irrelevant and compaction rare", and add a `/clear`-plus-reseed third arm to the Phase-2 A/B.
9. [non-blocking] Add "subagent chronology record for durable specialists" as a scoped Phase-3 investigation item with the mechanical sketch above and the one-shot-leg exclusion rationale.
10. [non-blocking] Note #13572 is closed-stale and #14258 closed; cite the hooks reference for `PostCompact`; update Decision 7's rationale to "unverified interactive path", not "reported broken".
11. [non-blocking] `NotebookEdit` path field is `notebook_path`; README deliverable says "six entries" for seven events; slash-command turns are captured as the invocation string and built-in `/compact` is not captured (say so, add a test); cache `model` from `SessionStart(compact)` as a second source for `<model-short>`; clarify that the steering string is typed by the user or printed by `/cdocs:compact`.
12. [non-blocking] Bound the Scratchpoint numerically and name the judge field its staleness maps to; add the Pillar 1 "devlog-class commit" carve-out sentence.

## Questions for the Maintainer

The proposer flagged these for pushback; my verdicts are above. Where the choice is genuinely the maintainer's, the options are:

1. Chat-record commit policy (action item 4):
   - (a) committed by default, explicit-path staging at handoff, best-effort regex redaction in the hook (my recommendation);
   - (b) committed by default, no redaction, exposure accepted and documented;
   - (c) written by default but `cdocs/_chat/` gitignored by `/cdocs:init`, with commit as the opt-in (loses cross-worktree durability, which the proposal correctly says matters in the bare-repo layout).
2. Subagent reads in the `files=` list (action item 2): (a) exclude via `agent_id` guard in Phase 1 (my recommendation); (b) include with an `agent=<type>` prefix from Phase 1, accepting that the overseer's block then lists files it did not read.
3. Phase-2 A/B third arm (action item 8): (a) add `/clear`-plus-reseed as a third arm now; (b) keep the two-arm design and revisit after Phase 2.
