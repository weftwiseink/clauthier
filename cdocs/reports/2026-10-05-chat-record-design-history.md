---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T10:23:14-07:00
task_list: meta/chat-record-devlog-management
type: report
state: live
status: review_ready
tags: [meta, hooks, chat_record, context_persistence, runtime_validated]
---

# Chat Record Design History and Evidence

> BLUF(opus-5-5/chat-record-devlog-management): Supplemental to [`2026-09-22-chat-record-devlog-management.md`](../proposals/2026-09-22-chat-record-devlog-management.md).
> It holds what the proposal no longer carries: how the design reached its current shape over eleven review rounds, the approaches it rejected and why, and the runtime evidence (Phase-0 canary runs, review runs, R7, R8) behind each platform fact the script depends on.
> Read it to re-litigate a decision or re-run a check; the proposal alone is enough to implement.

## Context

The proposal went through eleven propose-revise rounds between 2026-09-22 and 2026-10-05.
Round-by-round detail lives in the propose-revise devlog ([`2026-09-22-chat-record-devlog-management-propose-revise.md`](../devlogs/2026-09-22-chat-record-devlog-management-propose-revise.md)), its `-canary` chunk ([`2026-09-22-chat-record-devlog-management-propose-revise-canary.md`](../devlogs/2026-09-22-chat-record-devlog-management-propose-revise-canary.md)), the continuation devlog from round 5 ([`2026-10-05-chat-record-devlog-management-revise-r5.md`](../devlogs/2026-10-05-chat-record-devlog-management-revise-r5.md)), and the reviews under `cdocs/reviews/*chat-record-devlog-management*`.
This report is the condensed index of that history.

## Design Evolution

| Round | Driver | Change |
|---|---|---|
| 1 | initial draft | hook captures `last_assistant_message` verbatim per turn |
| 2 | review | accepted with nits; marked `implementation_ready` |
| 3 | maintainer, 2026-09-23 (reopened after acceptance) | verbatim capture replaced by one agent-written bullet per action item |
| 4 | maintainer, 2026-09-23 | entries judgment-driven and sparse; `Stop` block dropped; five-quiet-turn advisory added; commit-by-default with no redaction |
| 5 | maintainer, 2026-10-05 | every turn writes one gist bullet, `Stop` block restored as the enforcer; `PostToolUse` hook and its `files=` metadata dropped; compaction guidance moved into rules; `PreCompact`/`SessionEnd` markers and a `SessionStart` path announcement kept |
| 6 | maintainer, 2026-10-05; r5 review | record not compaction-aware (no `PreCompact`, `SessionStart`, `SessionEnd`, no session markers); per-turn timestamps; record path from `CLAUDE_CODE_SESSION_ID`; never-list became a guideline; script moved to the plugin's `bin/`; `/cdocs:init` permission rule |
| 7 | r6 review; maintainer steer | note body on stdin via quoted heredoc; top-level-only scoping by rule text; `--record` and quoted metadata values dropped; turn end became a `-- <session> at <ts>` sign-off instead of an `@end:` speaker block |
| 8 | r7 review; maintainer | proposal made timeless (history and evidence moved here); `Stop` table made three-row; subagent-guard rationale corrected and the `if`-scoped `PreToolUse` named as fallback |
| 9 | maintainer, 2026-10-05 (minimal mechanism, judgment over hard rules) | record pointer became devlog `chat_record:` frontmatter; `p=` correlation dropped for marker-order turns (`Stop` reads the last marker); `@harness` dropped, only human-initiated turns checked; no `/cdocs:init` permission merge; guard reduced to the per-turn rule's scope sentence; all agent-side compaction requests, steering, `/cdocs:compact`, and `ctx:` removed; Scratchpoint limits soft |
| 10 | r10 review (runtime-validated on 2.1.289); maintainer answers, 2026-10-05 | `/clear` and `--fork-session` treated as a fresh start (new id, new record, no lookup of the old one), resumption step 3 covers compaction only, and the A/B loses its `/clear` arm; Phase 1 removes cdocs' existing compaction cadence, loop-skill compact steps, and `overseer_ctx_est`; activation bounded by the git toplevel and gated on `cdocs/_chat/`; `--as` sanitized; no block in plan mode; `_chat/.gitattributes` union merge; per-turn rule scoped to Claude Code; record read bounded to `tail -n 80`; Scratchpoint moved into Phase 1; `--unit` test mode in CI |
| 11 | r11 review; overseer defaults favouring minimal design, 2026-10-05 | Scratchpoint written only by the devlog's owner (the overseer in `iterate`; the implementer keeps none); judge thinness reads `inline_work` alone; `triage.md` describes the dropped column without its name; residual context-budget phrases added to the removal list and the success grep widened; Phase 1 split into text-only 1a and capture 1b; `--as` validated against the `HEADER_RE` speaker form, `user` rejected in any case; `--minimal` init creates no `cdocs/_chat/`; a record may be listed in several devlogs; portable title lookup and timestamp; CI path filter covers its own workflow |
| 12 | r12 review | Phase-1a greps scoped to `plugins/cdocs/{rules,skills,agents}` so 1b's tests and README may name `/compact` and `/clear`; 1a gains a one-line Scratchpoint reader rule that 1b's step 3 replaces; Scratchpoint writers are any agent that owns its devlog |

## Rejected Approaches

| Approach | Rejected because |
|---|---|
| Hook-captured `last_assistant_message` as the agent entry (round 1) | raw reply text is the wrong shape for orientation and duplicates the transcript |
| One bullet per action item (round 3) | produces an enumerated log, the shape the gist guideline exists to avoid |
| Sparse, judgment-only entries with a quiet-turn advisory (round 4) | rested on "most turns have no gist"; the maintainer rejected that premise: every turn has at least its outcome |
| A prohibition ("never") list for entry content (round 5) | either bans the occasionally noteworthy commit or grows exceptions until it is a guideline |
| `PostToolUse` mechanical file list (rounds 1-4) | relevance-blind, and the only reason the hook needed per-turn runtime state |
| `SessionStart` hook announcing the record path (rounds 1-5) | `chat-record path` answers from `CLAUDE_CODE_SESSION_ID` on demand |
| `PreCompact`/`PostCompact`/`SessionEnd` marker lines (rounds 1-5) | a compaction or session-end line informs no reader; the first `@user` and last sign-off are the bookends |
| Eight-hex session id in the filename with a collision check | the full id removes the collision case |
| `n=` turn ordinals | no reader needs a turn count; timestamps order turns |
| `.prompt` runtime file for `p=` | `note` reads the last prompt header; the `Stop` reason passes `--p` explicitly (later moot: `p=` itself dropped) |
| `p=` prompt-id correlation on headers and sign-offs (rounds 1-8) | the session id ties the record and marker order delimits turns; ids added a token per header, a `--p` flag, and mid-turn special cases for no reader |
| `@harness` speaker for harness envelopes (rounds 5-8) | the envelope is not something a successor needs verbatim; the agent's own note reflects a finished subagent |
| `## Chat Record` devlog section with last-handoff time | the pointer is metadata: a `chat_record:` frontmatter list, which also fits multi-session devlogs |
| `/cdocs:init` merging `Bash(chat-record:*)` into `permissions.allow` | makes init invasive; the maintainer runs skip-permissions in containers; a README line serves default-mode users |
| A `chat-record` guard line in each `plugins/cdocs/agents/*.md` | duplicates the rule's scope sentence, which already sits beside the instruction and is the only guard forks see |
| Agent-side compaction management (ask for `/compact <steering>`, `/cdocs:compact`, Scratchpoint `ctx:`) | compaction is the user's or the harness's; rules act only after one happens |
| Hard Scratchpoint caps (15 lines, 8 files) | the agent judges what current state needs; the limits are targets |
| `Stop` writes the agent block from a staging file | adds a runtime file, a crash-loss case, and an orphan-flush case |
| Completing the agent header with the end time at `Stop` | rewrites an append-only file |
| `@end:` speaker block for the turn end (round 6) | `@` headers mean attribution; the hook is not a speaker (maintainer, 2026-10-05) |
| Two blocks per turn, agent note time standing in for turn end (r6 option) | the maintainer asked for a true end time |
| Quoted metadata values with four escapes | the only free-text value was the session name; mapping it to a token removes quoting |
| `--record <path>` override and silent fallback when the session variable is absent | the Phase-1 equality test catches a rename; failing loudly is simpler |
| Positional or double-quoted note argument | shell expansion of backticks, `$(...)`, `$VAR`; single quotes break on apostrophes |
| `/cdocs:init`-materialized project-local shim instead of `bin/` | embeds a version-specific plugin cache path that goes stale on update |
| Per-workstream `cdocs/_chat/<task_list>/` directory | relocating a session file after its workstream is learned breaks the glob lookup and devlog pointers |
| Newest-other-record fallback for step 3 after `/clear` (r10 review's C1 fix) | `/clear` starts an entirely new chat, so there is nothing to hand off; resumption covers only compaction, `--resume`, and `--continue`, which keep the id (maintainer, 2026-10-05) |
| `/clear` plus step 3 as a Phase-2 A/B arm | measured a lookup that `/clear` is not meant to perform; the two `/compact` arms are enough to gate Phase 3 |
| Keeping Pillar 2's compaction cadence (3-5 iterations, ~150K target) and the loop skills' "then compact" steps alongside a non-goal that only covered new text | the shipped pillar would both prescribe and disclaim agent-side compaction; the durable writes at task-unit boundaries are what make compaction safe, so they stay and the cadence goes |
| Overseer-estimated context column `overseer_ctx_est` | agent-side context tracking; the judge's thinness signal keeps `inline_work`, which is observed rather than estimated |
| Unbounded `cdocs/` walk-up from `cwd` | crosses repository boundaries (a `~/cdocs/` outside any repo would collect records); bounded at the git toplevel |
| Recording and blocking in any project with `cdocs/` | blocks every human turn in a project whose rules lack the per-turn paragraph; gating on `cdocs/_chat/` makes the hook and the rule arrive together via `/cdocs:init` |
| Empty `last_assistant_message` as the interrupt signal | a turn ending in tool calls only may also carry empty text, silently skipping the block; row 3 keys on `stop_hook_active` and plan mode until the interactive check finds a real signal |
| Scratchpoint defined in Phase 2 while Phase-1 resumption steps read it | live agents would be told to refresh an undefined section between phases; moving it into Phase 1 also shares one edit pass with the compaction-text removal in the same files |
| Scratchpoint freshness as a judge thinness input (round 10: `as_of` older than two Iteration Log rows) | the Iteration Log has no timestamps, so the rule cannot be computed; keying it on Dispatch/Return `at` values (r11 review) adds a judge read for a signal `inline_work` already covers |
| A warm `iterate` implementer maintaining its own Scratchpoint | it writes into the overseer's devlog, so it would either overwrite the owner's section or add a second one; its return summary and `### Implementer Notes` suffice |
| Excluding `agents/triage.md` from the success grep so it can keep naming the old column | an exception in the acceptance check; describing "a context-estimate column" without its name keeps the grep exception-free |
| One Phase 1 holding both the text edits and the capture work | its reviewers would judge runtime evidence and a dozen prose edits together; 1a is verified by grep and a consistency read, 1b by runtime evidence |
| `tac` for the session-title lookup and `date -Iseconds` for timestamps | `tac` is GNU-only and `date -I` is missing from older macOS `date`; `grep \| tail -n 1` and `date +%z` with an inserted colon do the same on BSD and macOS |
| Directory-per-workstream for devlog chunks | the `{date}-{slug}.md` convention, hook path regexes, and `/cdocs:status` assume flat typed directories |

## Platform Evidence

Facts the design depends on, with where each was established.
Runs 1-8 are in the `-canary` chunk (2.1.280, headless, sandboxed `CLAUDE_CONFIG_DIR`, `--model haiku`); review runs A-C are in the round-1 and round-5 reviews.

| Fact | How established | Relied on for |
|---|---|---|
| `UserPromptSubmit` fires with `prompt` verbatim, `prompt_id`, `session_id`, `cwd` | run 1 | the `@user` block |
| `UserPromptSubmit` does not fire for a subagent's dispatch prompt | runs 5 and 6, review Run A | top-level-only scoping |
| `UserPromptSubmit` fires a second time, with no human input, on a background subagent's completion | run 5 | skipping harness envelopes |
| `UserPromptSubmit` on a user-defined slash command carries the raw invocation string | review Run B | slash-command turns |
| Built-in `/compact` as a user line fires no `UserPromptSubmit` | run 2 | built-in commands leave no trace |
| `Stop` fires top-level only (`agent_id: null`), including for a turn that only launched a background subagent, with `prompt_id` equal to the turn's `UserPromptSubmit.prompt_id`, `stop_hook_active`, `transcript_path` | runs 5 and 6 | the per-turn check, the sign-off, the session title lookup (`prompt_id` equality no longer relied on) |
| `Stop` returning `decision: block` once is honored; the second `Stop` carries `stop_hook_active=true`; three turns total | run 8 (2026-09-23, under `bypassPermissions`) | the one-shot block |
| `CLAUDE_CODE_SESSION_ID` is exported to the Bash tool and equals the hook's `session_id`; `CLAUDE_PLUGIN_ROOT` is not exported | r5 review run A (2.1.289) | path derivation in `note` and `path` |
| A plugin's `bin/` is on the Bash tool's PATH while enabled | plugin reference; r5 review's own session; the round-6 revision's session (`.../plugins/cdocs/bin` present on PATH before the directory exists) | the bare `chat-record` command |
| An unallowlisted Bash script call is denied in headless default mode (`DENIED This command requires approval`) | r5 review run C | the README allow-rule note for default mode |
| A quoted-heredoc body reaches the script's stdin byte-exact (backticks, `$HOME`, `$(date)`, apostrophe, quotes, backslashes), and the call matches `Bash(chat-record:*)` in default mode (`permission_denials: []`) | run R7 (2026-10-05, 2.1.289, haiku, stub `chat-record` that logs stdin) | the stdin `note` body |
| A foreground subagent's Bash has the parent's `CLAUDE_CODE_SESSION_ID` and an environment identical to the top-level's in every `CLAUDE*`/`AI_AGENT` variable (`CLAUDE_CODE_CHILD_SESSION=1` and `AI_AGENT=claude-code_2-1-289_agent` in both) | r6 review; run R7 (same run, the subagent ran the stub too) | no environment-based subagent guard; top-level scoping is rule text with the `PreToolUse` fallback |
| The transcript carries `{"type":"custom-title","customTitle":"<name>","sessionId":"<id>"}` lines, rewritten over the session; `SessionStart` is the only hook payload documented to carry a title (`session_title`) | the round-6 revision's session (2.1.289); hooks reference | the session name in the sign-off |
| `/clear` fires no `UserPromptSubmit` or `Stop`, then a `SessionStart` arrives with a new `session_id`, and the next turn's Bash `CLAUDE_CODE_SESSION_ID` equals the new id; `--resume <id> --fork-session` likewise mints a new id; `/compact`, `--resume <id>`, and `--continue` keep it | r10 review (2026-10-05, 2.1.289, headless stream-json canary) | `/clear` as a fresh start; resumption covers compaction only |
| A second prompt queued while turn 1 runs fires its `UserPromptSubmit` before turn 1's single `Stop` | r10 review (headless stream-json) | the mid-turn prompt edge case |
| Hook `cwd` follows the agent after `cd` and after entering a worktree; `permission_mode` is a common hook input field; plugin hooks are not deduplicated; `CLAUDE_PROJECT_DIR` is absent from the Bash tool's environment | hooks reference; r10 review's session | the working-directory edge case, plan-mode sign-off, the double-hooks README line |
| `*.md merge=union` in `cdocs/_chat/.gitattributes` lets a rebase of divergent appends to one committed record, and a merge of the same record created on two branches (add/add), finish without conflict and keep every block (adjacent blank separators may collapse, which the line grammar ignores) | round-10 revision, scratch repo, git 2.54.0 | the union-merge scaffold |
| A `PreToolUse` handler with `"if": "Bash(chat-record:*)"` runs only on `chat-record` calls (not on `echo` calls in the same session) and sees `agent_id` (null at top level, set in a foreground subagent) | run R8 (2026-10-05, 2.1.289) | the named fallback guard |

Also verified, not relied on: `SessionStart` (all sources, `additionalContext` reaching the model), `PreCompact` (manual and auto), `PostCompact` (full `compact_summary`), `SessionEnd` (`reason`), `PostToolUse` (per call, and inside subagents with `agent_id`), `SubagentStart`/`SubagentStop`.

Not verified: whether `Stop` fires on a user-interrupted turn; whether `/rename` is accepted as a stream-json line; whether a message typed mid-turn in an interactive session fires `UserPromptSubmit` before the turn's `Stop` (headless queued prompts do); whether a forked agent's tool calls carry `agent_id` (`subagent_type: "fork"` was not available in the R8 sandbox: "Agent type 'fork' not found").

### Runs R7 and R8

Both: 2.1.289, `--model haiku`, default permission mode, sandboxed `CLAUDE_CONFIG_DIR` with copied credentials, `env -i` so the parent session's variables do not leak, and a stub `chat-record` on PATH that logs argv, stdin, and `env | grep -E '^(CLAUDE|AI_AGENT)'`.

- **R7.** Allow rule `Bash(chat-record:*)`.
  The top-level agent ran a quoted-heredoc note whose body held a backtick span, `$HOME`, `$(date)`, an apostrophe, double quotes, and backslashes; a foreground `general-purpose` subagent ran a second note.
  Result: stdin `cmp`-identical to the expected body; `permission_denials: []`; the two env dumps identical, both with the top-level `CLAUDE_CODE_SESSION_ID`, `CLAUDE_CODE_CHILD_SESSION=1`, and `AI_AGENT=claude-code_2-1-289_agent`.
  `/proc/$CLAUDE_PID/environ` of a running session holds none of those variables, so Claude Code injects them into every Bash child.
- **R8.** Same, plus a `PreToolUse` hook `{"matcher":"Bash","hooks":[{"type":"command","if":"Bash(chat-record:*)","command":"pre.sh"}]}` logging `agent_id`, `agent_type`, and the command.
  The session ran `echo plain-top` twice and `echo plain-sub` once besides the two notes; the hook log has exactly the two `chat-record` calls: `agent_id: null` at top level, `agent_id: "a1d03f4c6b83e84e9", agent_type: "general-purpose"` in the subagent.
  The `fork` dispatch failed with "Agent type 'fork' not found".

## Canary Recorder

The reusable instrument for hook verification: it logs every event with its full stdin payload, so a failing assertion shows the actual shape.

```bash
# canary.sh <Event>: append {"event","at","stdin"} to $CANARY_LOG.
EV="$1"; IN="$(cat)"
printf '{"event":"%s","at":"%s","stdin":%s}\n' "$EV" "$(date -Is)" \
  "$(printf '%s' "$IN" | jq -c .)" >> "$CANARY_LOG"
exit 0
```
