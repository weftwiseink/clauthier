---
review_of: cdocs/proposals/2026-09-22-chat-record-devlog-management.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T11:36:22-07:00
task_list: meta/chat-record-devlog-management
type: review
state: live
status: done
tags: [fresh_agent, pre_implementation, runtime_validated, hook_mechanics, edge_cases, test_plan, cross_target, phase_ordering]
---

# Review: Chat Record, Scratchpoint, and Semantic Devlog Splitting (round 10, pre-implementation)

> BLUF(opus-5-5/chat-record-devlog-management): The hook contract is sound against current Claude Code behaviour, but one runtime fact breaks a shipped rule: `/clear` mints a new `session_id` (verified on 2.1.289), so resumption step 3 cannot find the devlog after `/clear`, the cdocs skills' sanctioned "hard reset".
> Nine major findings follow: activation boundary, `--as` validation, plan mode, worktree merge conflicts, the OpenCode/`AGENTS.md` rule, the pre-existing compaction cadence, the Phase-1/2 Scratchpoint ordering, long pastes on resume, and test coverage and CI.
> All fixes are small and none touches a settled decision.
> **Verdict: Revise** (one critical, then implementable).

## Summary Assessment

The proposal specifies a per-session chat record built from two hooks and one `bin/` script, a rolling Scratchpoint, and semantic devlog splitting.
It is tight and almost entirely implementable from the text.
I checked the hook mechanics against the hooks reference and against three new headless canary runs (below).
Every fact the `Stop`/`UserPromptSubmit` contract relies on holds.
The critical gap is one the proposal left open as "either outcome acceptable": `/clear` changes the session id and the Bash `CLAUDE_CODE_SESSION_ID` follows it.
Step 3 therefore resolves to a fresh, unlisted record, and Phase 2's arm 3 measures that broken lookup.
Several majors are practical bites:
- records written outside the repo or blocking in projects that never opted in;
- a malformed `--as` silently gluing notes into the human prompt;
- plan-mode turns blocked into an instruction conflict;
- append-only records conflicting on worktree merges;
- the per-turn rule shipping to OpenCode and `AGENTS.md` targets that have no `chat-record`.
Verdict: Revise.

## Runtime Evidence Gathered This Round

Sandboxed `CLAUDE_CONFIG_DIR`, 2.1.289, `--model haiku`, `bypassPermissions`, a canary plugin logging `SessionStart`/`UserPromptSubmit`/`Stop` payloads and a `bin/` script echoing `CLAUDE_CODE_SESSION_ID`, driven turn-by-turn over stream-json.

| Probe | Observed |
|---|---|
| prompt, `/clear`, prompt | `/clear` fires no `UserPromptSubmit`/`Stop`; a new `SessionStart` arrives with a **new `session_id`**; the Bash `CLAUDE_CODE_SESSION_ID` in the next turn equals the new id |
| prompt, `/compact`, prompt | same `session_id` throughout; Bash id matches |
| `--resume <id>`, `--continue` | same `session_id`; Bash id matches |
| `--resume <id> --fork-session` | new `session_id`; Bash id matches the new one |
| second prompt queued while turn 1 runs (stream-json) | its `UserPromptSubmit` fires before turn 1's single `Stop` (headless evidence for interactive check (d)) |

From the hooks reference (code.claude.com/docs/en/hooks.md):
- `UserPromptSubmit` carries `prompt`, and its plain stdout on exit 0 is added to Claude's context.
- `Stop` blocks via `{"decision":"block","reason":...}` on exit 0, or exit 2.
- `Stop` does not fire on API errors (`StopFailure` fires instead).
- Hook `cwd` "follows Claude" after `cd` and after entering a worktree.
- `permission_mode` is a common input field.
- Plugin hooks are not deduplicated against other copies.
- `CLAUDE_PROJECT_DIR` is exported to hooks but is absent from the Bash tool's environment (checked in this session).

## Section-by-Section Findings

### Critical

**C1. Resumption step 3 fails after `/clear`.**
Step 3 runs `chat-record path`, which after `/clear` names the new session's record.
No devlog lists that record, and the fallback "create or resume one and add it" asks an agent with no context to pick a devlog.
The likely outcome is a new, fragmented devlog.
`/clear` is not exotic: Pillar 2's cadence, `iterate` ("then compact (`/compact`, or `/clear` for a hard reset)"), and `oversee` all prescribe it, and Phase 2's arm 3 is "/clear plus step 3".
The Edge Cases line "`/clear` and `/resume` effects are a Phase-1 test, and either outcome is acceptable" is now known to be the bad outcome for step 3.
Fix: give step 3 an explicit fallback for an unlisted path.
Take the newest other record (`ls -t cdocs/_chat/*.md`), read its tail and the devlog that lists it, then add the new path to that devlog's `chat_record:`.
Confirm with the user when several records are recent (concurrent sessions).
Also restate the `/clear` and `--fork-session` outcomes as facts in Edge Cases.

### Major

**M1. Activation boundary: unbounded walk-up, and blocking before opt-in.**
"`cdocs/` is found by walking up from the payload's `cwd`" crosses repository boundaries.
On this machine `~/cdocs/` exists (dotfiles devlogs, not a git repo), so any cdocs-enabled session under `$HOME` whose project lacks `cdocs/` would write its record into `~/cdocs/_chat/` and block every human turn.
Separately, a project that has `cdocs/` but has not re-run `/cdocs:init` after the update gets `Stop` blocks with no rule asking for proactive notes, which costs one extra round trip per turn until init.
Fix (pick one or both):
- stop the walk at `git rev-parse --show-toplevel`;
- gate every mode on `cdocs/_chat/` existing, which deliverable 3 already scaffolds, so the hook and the rule arrive together.

**M2. `--as` is unvalidated, which silently corrupts the record.**
The agent supplies `<model-short>`, and plausible values do not match `HEADER_RE`: `opus-4-6[1m]` (the 1M-context id suffix), `Opus 5.5`, or a typo with a space.
The writer emits such a header unescaped and the reader classifies it as body, so the note is glued into the preceding `@user` prompt.
`Stop` still sees `@user` last and blocks; the agent repeats the same `--as`; the turn ends with no parseable entry, every turn.
`--as user` would also forge a human header.
Fix: map `--as` through the session-token rule (characters outside `[A-Za-z0-9._-]` become `-`), reject `user` and an empty result loudly, and add both to the unit tests.

**M3. Plan mode turns are blocked into an instruction conflict.**
In plan mode the harness tells the model to make no writes, while the block reason tells it to run `note`.
Every human plan-mode turn then costs a block plus a turn that either refuses or violates plan mode.
The payload carries `permission_mode`.
Fix: in `Stop`, treat `permission_mode == "plan"` like `stop_hook_active` (sign-off, no block); add a test.

**M4. Same-named records diverge across worktrees and conflict on merge.**
The accepted edge case "working directory moves to another worktree: a second file with the same name starts there" ignores the merge.
`EnterWorktree` moves the hook `cwd` and the Bash `$PWD` into `.claude/worktrees/<name>/`, which carries the committed record from main.
Appends in both checkouts then conflict when the branch merges back, and an uncommitted record gives an add/add conflict instead.
Either way the repo's `git merge --ff-only` flow breaks on an append-only file.
Fix: `/cdocs:init` scaffolds `cdocs/_chat/.gitattributes` containing `*.md merge=union` beside the README (no root or settings file touched).
Also state which file `note` uses when the glob matches more than one (for example, the earliest date).

**M5. The per-turn rule ships to targets with no `chat-record`.**
`build-opencode.ts` copies `rules/` wholesale into the OC package, and `/cdocs:init` copies every rule into `.opencode/rules/cdocs/` and inlines `orchestration-discipline.md` into `AGENTS.md` (Codex, Cursor, Copilot).
Those agents would be told to run a command that does not exist, on every turn and after every reset.
The Edge Case "the per-turn bullet is rule-only there" contradicts Pillar 2's "never `Edit` or `Write` `cdocs/_chat/`", because the only rule-only way to write an entry is a direct edit.
Fix: make the existing scope sentence read "Claude Code top-level session only" (or add "when `chat-record` is on PATH"), and have the Edge Case say other targets keep no record.
No build-script change is needed: `bin/` and `hooks.json` are not copied, and that is correct.
Update the "NOT ported" header in `cdocs-hooks.ts` to list the chat-record hooks.

**M6. Pre-existing compaction cadence contradicts the settled no-agent-side-compaction decision.**
Pillar 2 keeps "Proactive compaction cadence": "Run `/compact` ... after every 3 to 5 iterations", "keeping overseer turns under roughly 150K tokens".
`iterate`, `oversee`, `propose-revise`, and `full-send` also carry "then compact" and "before compacting" lines.
The proposal adds its rules to that same pillar, and its Phase-1 constraint covers only "text this proposal adds".
The shipped Pillar 2 would therefore both forbid and prescribe agent-side compaction and context tracking.
See Question 1.

**M7. Phase 1 references the Scratchpoint that Phase 2 defines.**
Phase 1 deliverable 5 ships steps 2-3 ("refresh the Scratchpoint", "read the `## Scratchpoint`"), and the Phase-1 rules check asserts reads of a Scratchpoint.
The Scratchpoint subsection, its format, and the template section are Phase 2 deliverables 1-2.
Between phases, live agents are told to refresh an undefined section, and the Phase-1 rules check needs a fixture whose shape is not yet specified.
Fix: move the Scratchpoint subsection and template line into Phase 1, which is a small move, and leave splitting in Phase 2.
Alternatively, have Phase 1's steps name only the handoff and record tail, with Phase 2 adding the Scratchpoint.

**M8. Long pasted prompts re-enter context on every resume.**
Step 3 reads "the last five blocks of the record", and `@user` bodies are verbatim.
A pasted 2,000-line log in a recent prompt is pulled back in right after a compaction, the moment context is most precious.
Fix: bound the read (for example `tail -n 80` of the record, or "skim `@user` bodies longer than ~40 lines to their first lines").
Verbatim capture stays settled; only the reader changes.

**M9. Test coverage and CI.**
The suite misses the regressions most likely to bite:
- `/clear` gives a new file, and the Bash id equals the new hook id;
- `--fork-session` gives a new file;
- a sanitized and a rejected `--as`;
- `UserPromptSubmit` mode emits empty stdout (any stray stdout is injected into model context);
- plan-mode `Stop` does not block;
- a `cd` into a sibling directory with its own `cdocs/` keeps the note and the `Stop` check on one file;
- `.gitattributes` union merge of two divergent records.
Nothing runs the suite automatically.
`opencode-build.yml` only builds, and the headless scenarios need credentials.
Fix: give `chat-record.test.sh` a `--unit` mode (pure shell, no `claude`) and run it in CI; keep the headless scenarios as a manual Phase-1 gate.

### Nits

- **N1. Stdout discipline.** State in the Script section that hook mode never writes to stdout except the `Stop` block JSON, because plain stdout becomes model context on `UserPromptSubmit`.
- **N2. Interrupt row.** Implement row 3 on `stop_hook_active` alone until check (b) shows `Stop` fires on interrupt; the reference lists `Stop` only for finished turns.
  Do not adopt the "empty `last_assistant_message`" candidate without evidence: a turn whose final message is tool calls only may also carry an empty text and would silently skip the block.
- **N3. `path` output form.** Say `chat-record path` prints the repo-root-relative path (`cdocs/_chat/...`), since step 1 appends it verbatim to `chat_record:`.
- **N4. Executable bit.** Deliverable 1: commit `bin/chat-record` as mode `100755`, like the existing hook scripts.
  The directory marketplace runs it straight from the working tree.
- **N5. Built-in commands.** Generalize "built-in `/compact` and `/clear` fire no `UserPromptSubmit`" to local built-ins (`/effort`, `/model`, `/rename`, `/config`) rather than naming two.
- **N6. Title lag.** The transcript is written asynchronously, so the `/rename` scenario may see the new title one sign-off late; assert on the sign-off of the turn after the rename.
- **N7. Non-loop sessions.** Records are staged only "at each handoff"; a session with no handoff leaves an untracked record.
  Say whether that is intended or whether such sessions stage the record with their devlog commit.
- **N8. Double hooks.** Plugin hooks are not deduplicated, so a developer running `--plugin-dir` alongside the enabled `cdocs@clauthier` would get doubled `@user` blocks and sign-offs; one README line.
- **N9. Rule reach.** The per-turn paragraph lives in the "overseer mode" document; add "whether or not you are overseeing a loop" to its second sentence so a plain session does not read it as overseer-only.
- **N10. Append atomicity.** "A single `printf ... >>` ... interleave at block granularity" holds only up to the shell's write buffer; a large paste may be several `write()` calls.
  This is harmless because concurrent writers to one file are rare, but soften the claim.

## Probes That Came Up Clean

- **`AskUserQuestion`:** the answer returns as a tool result inside the turn, with no `UserPromptSubmit` and no `Stop`, so it creates no false positive.
- **Skill and slash-command turns:** recorded as the raw invocation (review Run B) and noted like any human turn.
- **Concurrent sessions on one day:** separate files by full id.
- **Midnight:** the glob lookup keeps the first-prompt date stable, and `--resume`/`--continue` keep the id (verified).
- **Prompts mimicking markers:** covered by the stateless escape, and the unit fixture exercises it.
- **Interrupted or `StopFailure` turns:** leave an unsigned `@user` that the next note closes, with no loop.
- **Blocking every forgetful human turn once:** the settled design, and its cost is bounded by `stop_hook_active`.
- **`hooks.json` shape, `${CLAUDE_PLUGIN_ROOT}`, `bin/` on PATH** (`.../clauthier/main/plugins/cdocs/bin` is on this session's PATH before the directory exists), **`CLAUDE_PLUGIN_ROOT` absent from Bash:** all as the proposal states.
- **OpenCode build:** `build-opencode.ts` needs no change for `bin/` or the hooks.
  The only cross-target impact is the rule text (M5).

## Verdict

**Revise.**
C1 must be fixed before implementation: step 3 and the `/clear` edge case need the newest-other-record fallback.
M1-M5 and M8 are one- or two-line spec changes that prevent wrong behaviour in practice.
M7 is a deliverable move.
M6 needs a maintainer answer.
M9 adds test lines and one CI step.
None reopens a settled decision.
A verification pass over these edits should suffice.

## Action Items

1. [blocking] C1: add a step-3 fallback for an unlisted record path (newest other `cdocs/_chat/` record, then its devlog; confirm when ambiguous), and replace "either outcome is acceptable" with the observed `/clear` and `--fork-session` new-id behaviour.
2. [blocking] M1: bound the `cdocs/` walk-up at the git toplevel, or gate all modes on `cdocs/_chat/` existing.
3. [blocking] M2: sanitize `--as` with the session-token mapping; reject `user` and empty values.
4. [blocking] M3: `Stop` does not block when `permission_mode` is `plan`.
5. [blocking] M4: scaffold `cdocs/_chat/.gitattributes` with `*.md merge=union`; define the multi-match choice for the glob.
6. [blocking] M5: scope the per-turn rule to Claude Code (or to `chat-record` on PATH); fix the OpenCode edge case; update the `cdocs-hooks.ts` "NOT ported" header.
7. [blocking] M6: resolve the existing compaction-cadence text per Question 1.
8. [blocking] M7: move the Scratchpoint subsection and template line into Phase 1, or drop Scratchpoint references from Phase-1 steps.
9. [non-blocking] M8: bound the step-3 record read.
10. [non-blocking] M9: add the listed scenarios; add a `--unit` mode run in CI.
11. [non-blocking] N1-N10 as listed.

## Questions for the Maintainer

1. Pillar 2's "Proactive compaction cadence" and the loop skills' "then compact (`/compact` or `/clear`)" lines predate this proposal and contradict its no-agent-side-compaction stance. What should Phase 1 do?
   - (a) Remove the cadence subsection, the 150K target, and the skills' compact instructions, keeping "handoff before any compaction".
   - (b) Leave them, and narrow this proposal's non-goal to "this proposal adds no ...".
   - (c) Defer to a separate cleanup RFP.
2. For C1, if several recent records exist after `/clear`, which should the fallback do?
   - (a) Ask the user.
   - (b) Take the newest record by mtime without asking.
   - (c) Take the newest record whose devlog has an open handoff.
3. For M1, which activation gate should the script use?
   - (a) The git toplevel only.
   - (b) `cdocs/_chat/` existing only (opt-in via init).
   - (c) Both.
