---
first_authored:
  by: "@claude-fable-5-1"
  at: 2026-09-22T18:27:04-07:00
task_list: meta/chat-record-devlog-management
type: proposal
state: live
status: implementation_ready
last_reviewed:
  status: revision_requested
  by: "@claude-opus-5-5"
  at: 2026-10-05T11:36:22-07:00
  round: 11
tags: [meta, tooling, context_persistence, hooks, devlog, orchestration, agent-memory]
---

# Chat Record, Scratchpoint, and Semantic Devlog Splitting

> BLUF(fable-5-1/chat-record-devlog-management): A per-session **chat record** under `cdocs/_chat/` holds hook-captured verbatim human prompts plus at least one terse agent-written gist bullet per human-initiated turn, each turn closed by a `Stop`-written `-- <session> at <time>` sign-off; `Stop` blocks once when such a turn has no entry.
> Two hooks and one script (`plugins/cdocs/bin/chat-record`, note text on stdin via quoted heredoc); a devlog lists its records in `chat_record:` frontmatter; post-compaction re-reading lives in rules, not hooks.
> A rolling devlog **`## Scratchpoint`** holds current state; devlogs split at closed-concern boundaries.
> cdocs' existing agent-side compaction cadence and context self-estimates are removed; handoffs stay at task-unit boundaries.

## Summary

This proposal operationalizes [`2026-09-22-chat-record-scratchpoint-design.md`](../reports/2026-09-22-chat-record-scratchpoint-design.md) and the devlog-management half of the context-management roadmap (RFP-2): file formats, hook contract, rule and skill text, and a phased rollout.

| Artifact | Author | Cadence | Location |
|---|---|---|---|
| Chat record | hook (human prompts, sign-offs) plus the top-level agent (gist bullets via `chat-record note`); one script does every append | every human-initiated turn | `cdocs/_chat/YYYY-MM-DD-<session_id>.md` |
| Scratchpoint | the overseer or a durable specialist | every state-changing turn, replaced in place | `## Scratchpoint` in the devlog that agent owns |
| Devlog chunks | the devlog's author | at a handoff when a concern has closed | `cdocs/devlogs/YYYY-MM-DD-<root>-<concern>.md`, root becomes index |

The chat record is chronology (what a successor should know, in the order it was learned); the Scratchpoint is a short current-state snapshot; both are agent-authored and terse, and no hook supplies content.
The session id ties a record together and block order delimits its turns.
The hooks stay silent in a project until `/cdocs:init` creates `cdocs/_chat/`.
Compaction is left to the user and the harness: Phase 1 removes cdocs' existing instructions for agents to compact or estimate their own context (Pillar 2's cadence, the loop skills' compact steps, the `overseer_ctx_est` column) and keeps the durable writes that make any compaction lossless.
How the design reached this shape, the approaches it rejected, and the runtime evidence behind each platform fact are in the supplemental [`2026-10-05-chat-record-design-history.md`](../reports/2026-10-05-chat-record-design-history.md).

## Objective

Make the compaction summary's quality irrelevant to resumption: at any moment, durable state exists that is at most one turn stale, and a fresh or post-compaction window is seeded from that state rather than from a summary.
Keep devlogs skimmable by splitting them where the work has seams, so a resuming agent reads one relevant chunk rather than a 40KB chronology.

## Background

1. [`2026-09-22-chat-record-scratchpoint-design.md`](../reports/2026-09-22-chat-record-scratchpoint-design.md): capture and delivery are complementary; scoping; 3-phase rollout.
2. [`2026-09-20-token-spend-by-role.md`](../reports/2026-09-20-token-spend-by-role.md) workstream 1 (the capture mechanisms) and workstream 4 (cap-and-reseed, which depends on them).
3. [`2026-09-19-devlog-methodology-value.md`](../reports/2026-09-19-devlog-methodology-value.md) recommendations 2 and 3: point post-compaction resumption at the devlog; split past ~10-15KB or ~5 rounds.
4. [`orchestration-discipline.md`](../../plugins/cdocs/rules/orchestration-discipline.md) Pillar 2 (handoff format, reseed: unscoped rules re-inject on every compaction) and the judge-observable thinness columns.
5. [`plugins/cdocs/skills/devlog/SKILL.md`](../../plugins/cdocs/skills/devlog/SKILL.md) and `template.md`, which the `chat_record:` field, the Scratchpoint, and the split rule extend.
6. [`plugins/cdocs/hooks/hooks.json`](../../plugins/cdocs/hooks/hooks.json), the README's "Sandbox testing notes", and the plugin reference's `bin/` rule (a plugin's `bin/` is on the Bash tool's `PATH` while enabled; `CLAUDE_PLUGIN_ROOT` is not exported to Bash-tool commands).
7. [`2026-09-01-devlog-autoflush-hook.md`](2026-09-01-devlog-autoflush-hook.md): RFP stub answered here (a hook can force a write once per turn via a `Stop` block; the active devlog is the one whose `chat_record:` lists the session's record); marked `evolved` at Phase 1.
8. [`2026-09-22-shared-retrieval-cache-redundancy-check.md`](../reports/2026-09-22-shared-retrieval-cache-redundancy-check.md): the file-awareness half is folded in as `read:` notes and Scratchpoint `files:` gists; the token-cost half is out of scope.
9. [`2026-10-05-chat-record-design-history.md`](../reports/2026-10-05-chat-record-design-history.md): design history, rejected approaches, and platform evidence.

### Non-Goals

- Graphify-scoped retrieval; memory-tool integration; post-hoc devlog distillation by a cheap model.
- Cross-agent content sharing: the gists give awareness, not cheaper re-reads, and make no claim on the measured 97.4% cross-agent re-read figure.
- Mechanical capture of files touched (no `PostToolUse` hook).
- Compaction awareness in the record: no compaction hook, no session start, end, or compaction lines.
- Agent-side compaction management: no cdocs text asks the user to compact, schedules or times compaction, or has an agent estimate its own context usage; Phase 1 removes the existing instructions that did, and the rules act only after a compaction has happened.
- Recording harness envelopes (task notifications, system reminders).
- Chat records for dispatched subagents (Phase 3 pointer only).
- Hook-authored scratchpoints: a hook can nudge, never author.
- Permission or settings edits by `/cdocs:init`.
- Redaction or secret scanning, scoped in [`2026-09-23-chat-record-redaction-scanning-rfp.md`](2026-09-23-chat-record-redaction-scanning-rfp.md).

## Proposed Solution

### Layer map

```mermaid
sequenceDiagram
    participant U as User
    participant H as chat-record (hook)
    participant N as chat-record note
    participant A as Agent (top-level)
    participant CR as cdocs/_chat/<session>.md
    participant DL as devlog (chat_record, Scratchpoint, handoff)
    U->>H: UserPromptSubmit (human prompt; harness envelopes skipped)
    H->>CR: create file if absent; append @user: <submit ts>
    A->>DL: replace ## Scratchpoint (every state-changing turn)
    A->>N: bullets as quoted heredoc on stdin
    N->>CR: append @<model>: <ts> entry
    A-->>H: Stop
    alt last marker is an agent header
        H->>CR: append sign-off: -- session at end ts
    else last marker is @user, first Stop
        H-->>A: decision=block, reason names the record path and the note command
    else last marker is @user, stop_hook_active or plan mode
        H->>CR: append sign-off
    else last marker is a sign-off (turn not begun by a human prompt, no note)
        Note over H: writes nothing
    end
    Note over A: rules (re-injected after compaction): chat-record path, then Scratchpoint + handoff + record tail
```

### Chat record

#### Location and naming

- Path: `cdocs/_chat/YYYY-MM-DD-<session_id>.md`, full session id, date of the first recorded prompt; one file per Claude Code session.
- Lookup is by glob `cdocs/_chat/*-<session_id>.md`, never by recomputing the date, so `--resume` on a later day appends to the same file.
- Created lazily by the first `UserPromptSubmit` or `note`.
- **Activation.** The script walks up from the payload's `cwd` (hook mode) or `$PWD` (`note`, `path`) to the git toplevel (`git rev-parse --show-toplevel`), stopping at the first `cdocs/`; it never looks above the toplevel, and outside a git work tree it finds nothing.
  The record directory is that `cdocs/_chat/`, which `/cdocs:init` creates, so a project records nothing until it opts in and receives the rule text in the same step.
- **Multiple matches.** If the glob matches more than one file (one session's record started separately in two checkouts on different days), every mode uses the earliest-dated name.
- The session id comes from the hook payload, and in the agent's Bash from `CLAUDE_CODE_SESSION_ID` (undocumented; equal to the hook's `session_id`, asserted by a Phase-1 test).
- `_chat/` is a mechanical asset directory like `_media/`: no frontmatter, outside the frontmatter-validation and edit-path regexes (which match only the four typed directories); `frontmatter-spec.md` gains one line saying so.

**Devlog link.** A devlog names the records of every session that worked on it in an optional `chat_record:` frontmatter list of repo-root paths (`review_of` path semantics), appended once per session:

```yaml
chat_record:
  - cdocs/_chat/2026-10-05-3f2a9c1e-....md
```

A list because a devlog outlives sessions; a frontmatter field because it is metadata, machine-readable, and stays in the root when a devlog splits.
The devlog for a record is `grep -l '<record path>' cdocs/devlogs/*.md`; chunks do not carry the field, so the match is the root.

**Commit protocol.** Records are committed, because untracked durable state does not cross worktrees or sessions.
The record grows every turn, so the top-level session stages it by explicit path whenever it commits a devlog that lists it (`git add cdocs/_chat/<file> cdocs/devlogs/<devlog>`): at each handoff in a loop, and with any devlog commit in a plain session.
A session that never works on a devlog leaves its record untracked; nothing points to it, so nothing is lost.
Dispatched agents never stage `cdocs/_chat/` (no `git add -A`, no `commit -a`).
This is a carve-out to Pillar 1's "the overseer does not commit code itself": record and devlog commits are bookkeeping.
`/cdocs:init` scaffolds `cdocs/_chat/.gitattributes` containing `*.md merge=union`, so appends made to one record in two checkouts merge or rebase without conflict, including the add/add case of a record that was uncommitted when a worktree was entered.

> WARN(fable-5-1/chat-record-devlog-management): A committed record leaks two ways: text a human pastes into a prompt, and agent bullets that echo a secret from a tool result.
> The gist guideline narrows the second; neither is closed.
> Maintainer decision: commit by default, no redaction; opt-outs are `CDOCS_CHAT_RECORD=off` and gitignoring `cdocs/_chat/` (losing cross-worktree durability).

#### Format

A record is a sequence of blocks, each a header line followed by a body; only real speakers get `@` headers, and a turn ends with a sign-off line.
Header and sign-off lines are the record's **markers**; turns are delimited by marker order alone.

```
HEADER_RE  := ^@[A-Za-z0-9][A-Za-z0-9._-]*:
SIGNOFF_RE := ^-- [A-Za-z0-9._-]+ at [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:[0-9]{2}$
header     := HEADER_RE (" " timestamp)?          ; timestamp: date -Iseconds
signoff    := "-- " session " at " timestamp
body       := any line matching neither pattern (after unescape)
```

- **Escape.** The writer prefixes one backslash to any body line matching `^\\*` followed by `HEADER_RE` or `SIGNOFF_RE` (minus the anchor), so a pasted `@user: ...`, `@alice: hi`, a CSS `@page:first {`, or a pasted sign-off stay body text; the reader strips exactly one leading backslash from such lines.
  Writer and reader use the same two patterns, applied to every line regardless of fences, so parsing is stateless and round-trips verbatim.
  The writer normalizes CRLF to LF first.
- **Parse order.** The reader classifies each line as header, sign-off, or body (unescaping body lines); a header opens a block, a sign-off closes the turn; then blank lines at the end of a body are stripped (the writer puts one blank line after each body, so one precedes every sign-off).
- **Session token.** The title is the last `custom-title` line in the transcript (`tac "$transcript_path" | grep -m1 '"type":"custom-title"'`, field `customTitle`, set by `/rename`); every character outside `[A-Za-z0-9._-]` maps to `-`; an empty or absent title, or an unreadable transcript, falls back to the first 8 hex of `session_id`.
- Column-0 `@` and `-- x at` lines are not cdocs markdown syntax; records are embedded in other cdocs documents only inside fences.

| Speaker | Written by | Timestamp | Body |
|---|---|---|---|
| `@user` | `UserPromptSubmit`, human prompt | submission | the prompt, verbatim |
| `@<model-short>` (`@opus-4-8`, `@fable-5-1`) | the top-level agent via `note --as <model-short>` (default `assistant`) | note time | at least one gist bullet; aim for one to three |

`<model-short>` is the model id without `claude-` and any `-YYYYMMDD` suffix; the agent supplies it, since no hook payload carries a model.
The sign-off carries the end time and session name and closes the turn by position; a turn's duration is its `@user` time to its sign-off.

**Gist entries.** Aim for one to three bullets per turn, one line each, under ~120 characters, each with a category prefix (no prefix reads as `gist:`):

- `gist:` what the turn concluded, decided, or changed, phrased for a successor: `gist: Stop block is the enforcer; reviewer r5 returned revise on two blockers`.
- `query:` a search or retrieval that proved useful and what it found: `query: graphify query "hook events" surfaced the matcher table; reuse before grepping`.
- `read:` a high-salience file and why: `read: plugins/cdocs/hooks/validate-cdocs-edit-path.sh: the jq stdin-parse and silent-exit pattern`.
- `follow-up:` an open thread: `follow-up: interrupt behavior of Stop unverified; needs a real-session check`.

The test for a bullet: would a successor reading only the `@user` blocks and these bullets know where things stand.
Guideline, not prohibition: do not log every commit, test run, edit, or tool output, and do not paste the reply; but a commit that closes a long thread or a test result that changes the plan may be the turn's gist.
The shape to avoid is the enumerated log (`- edited X - ran tests - committed abc`); the shape to produce is the one-line state of play.
Slash commands are recorded as the raw invocation string; built-in commands (`/compact`, `/clear`, `/model`, `/effort`, `/rename`, `/config`, and the like) fire no `UserPromptSubmit` and leave no trace.

Example (user lines from a canary run; entries illustrative):

```
@user: 2026-09-22T18:20:54-07:00
Reply with exactly the word: alpha

@fable-5-1: 2026-09-22T18:20:56-07:00
- query: `jq -c '{hook_event_name, stop_hook_active}'` on the canary log shows one Stop per turn
- read: plugins/cdocs/README.md "Sandbox testing notes": the credential-copy recipe every headless canary needs
- follow-up: whether Stop fires on an interrupted turn; check in a real session before Phase 1 ships

-- hook-canary at 2026-09-22T18:20:57-07:00

@user: 2026-09-22T18:21:05-07:00
Reply with exactly the word: beta.

@fable-5-1: 2026-09-22T18:21:07-07:00
- gist: replied beta; no state change

-- hook-canary at 2026-09-22T18:21:08-07:00
```

#### Script: `plugins/cdocs/bin/chat-record`

Bash plus `jq` (both hooks are on every turn's critical path; `npx tsx` startup is measurable), in the plugin's `bin/` so the agent runs it as the bare command `chat-record`.

| Mode | Invocation | Behavior |
|---|---|---|
| hook | `${CLAUDE_PLUGIN_ROOT}/bin/chat-record UserPromptSubmit` (from `hooks.json`, timeout 5s) | append `@user` for a human prompt; skip harness envelopes (Edge Cases); never blocks |
| hook | `${CLAUDE_PLUGIN_ROOT}/bin/chat-record Stop` (timeout 5s) | per the table below |
| agent | `chat-record note [--as <speaker>]`, bullets on stdin | append `@<speaker>: <current time>` and the body |
| agent | `chat-record path` | print the record path relative to the git toplevel (`cdocs/_chat/...`), the form `chat_record:` takes; never create the file |

The note body is read from stdin only, and the one documented form is the quoted heredoc, which performs no expansion:

```bash
chat-record note --as fable-5-1 <<'EOF'
- query: `rg -n "stop_hook_active"` found the one-shot guard; didn't need the binary
EOF
```

A double-quoted argument would execute backticks and `$(...)` and expand `$VAR`; a single-quoted one breaks on apostrophes.
The heredoc form delivers the body byte-exact (history report, run R7).

`--as` passes through the session-token mapping (characters outside `[A-Za-z0-9._-]` become `-`), so `opus-4-6[1m]` becomes `opus-4-6-1m-` and `Opus 5.5` becomes `Opus-5.5`.
A result that is empty, starts with `.` or `-`, or equals `user` is rejected: `note` exits non-zero and writes nothing, so a malformed speaker can neither glue the note into the preceding prompt nor forge a human header.

`Stop` reads the record's last marker (`grep -E` on the two patterns, last match; escaped body lines never match), after the guards below:

| Last marker | Writes | Emits |
|---|---|---|
| an agent header: a note was appended since the turn's `@user` or the previous sign-off | sign-off | nothing |
| `@user`, first `Stop` of the turn, `permission_mode` not `plan` | nothing | `{"decision":"block","reason":"<block text>"}` |
| `@user`, and `stop_hook_active` is true or `permission_mode` is `plan` | sign-off | nothing |
| a sign-off, or none: the turn did not begin with a human prompt and has no note | nothing | nothing |

Block text, with only the record path substituted; `<your model>` stays literal for the agent to fill in (under 300 bytes):

```
No chat-record entry for this turn (record: cdocs/_chat/2026-10-05-<session_id>.md). Run, then finish:
chat-record note --as <your model> <<'EOF'
- gist: <what a successor should know from this turn>
EOF
```

Guards and invariants:

- **Silent exits, hook mode.** Exit 0 with no write and no block when: the payload carries `agent_id` (in `UserPromptSubmit` and `Stop`); `CDOCS_CHAT_RECORD=off`; `jq` or `git` is missing; activation finds no `cdocs/_chat/`; or (for `Stop`) no record file exists.
  Hook mode always exits 0 and writes errors to stderr only.
- **Stdout.** Hook mode writes nothing to stdout except the `Stop` block JSON, because plain stdout from `UserPromptSubmit` is added to the model's context.
- **Agent modes fail loudly.** `note` and `path` exit non-zero with a one-line stderr reason when `CLAUDE_CODE_SESSION_ID` is unset, activation finds no `cdocs/_chat/`, `jq` is missing, `--as` is rejected, or the write fails; `CDOCS_CHAT_RECORD=off` is a silent exit 0.
- **Never loops.** `stop_hook_active=true` is never blocked, so a turn costs at most one extra short turn; an agent that ignores the block ends the turn with no entry, and the gap shows as a `@user` followed directly by its sign-off.
- **One append path.** Every write is a single `printf ... >>` of a whole block or line (`O_APPEND`), so concurrent appends normally interleave at block granularity; a block larger than the shell's write buffer may span several `write()` calls, which is harmless because concurrent writers to one record are rare.
  Agents read records (`tail`, offset `Read`) and never `Edit` or `Write` them.
- **No state beyond the record.** `last_assistant_message` is never written, `Stop` reads one marker line and never content, and no runtime-directory files exist.

**Per-turn rule and cost.** Pillar 2 carries the rule as one paragraph, its scope sentence first:

> Claude Code top-level session only: `chat-record` exists nowhere else, and if you were dispatched by the `Agent` tool (including as a fork), never run it.
> In the top-level session, whether or not you are overseeing a loop, before ending a turn that began with a human prompt, append at least one gist bullet with `chat-record note` (quoted heredoc form), issued in the same parallel tool batch as the turn's last action when the outcome is known.
> Other turns (a background agent finishing) may note when they change the state of play; `Stop` does not require it.

The common case then costs no extra round trip; a turn with no other tool call pays one.
The `Stop` block is the backstop, not the mechanism; with every block ignored the record still holds verbatim human prompts and sign-offs.

**Permissions.** `/cdocs:init` edits no settings.
Under skip-permissions nothing is needed; in default permission mode an unallowlisted `note` prompts every turn (and is denied headless), so the README carries one line: allow `Bash(chat-record:*)` in settings or via `--allowedTools`.

#### Top-level only

The chat record is the top-level session's.
Hook mode is guarded by `agent_id`; `note` sees no payload, and a subagent's Bash environment, including `CLAUDE_CODE_SESSION_ID`, is identical to the top level's (history report, run R7), so a subagent's `note` would land in the top-level record and satisfy its `Stop` check.
The guard is the scope sentence that opens the per-turn rule: it sits beside the instruction it limits and also reaches forks, which inherit the parent transcript and no agent definition.
If the Phase-1 subagent or fork scenario shows a leak, the fallback is a `PreToolUse` mode scoped by `"if": "Bash(chat-record:*)"` that denies when the payload carries `agent_id` (history report, run R8).

> NOTE(opus-5-5/chat-record-devlog-management): Attributed subagent notes and any tiered/per-workstream record are deferred to [`2026-10-05-tiered-chat-records-rfp.md`](2026-10-05-tiered-chat-records-rfp.md).

### Resumption guidance (rules only)

Compaction happens when the user runs `/compact` or the harness auto-compacts ([#71803](https://github.com/anthropics/claude-code/issues/71803)); this proposal does not schedule, request, or anticipate it.
Compaction, `--resume`, and `--continue` keep the session id, so the session keeps its record.
`/clear` and `--fork-session` start a new session with a new id and a new record; nothing carries over, which is what starting fresh means, and they are not resumption.
Its guidance lives where it survives compaction: Pillar 2 of `orchestration-discipline.md`, which `/cdocs:init` writes into `.claude/rules/cdocs.md` and which re-injects on every compaction.
Pillar 2 gains three steps:

1. **First turn a session works on a devlog:** run `chat-record path` and append the result to the devlog's `chat_record:` list if absent.
2. **At each handoff:** refresh the Scratchpoint, and commit devlog and record by explicit path.
3. **After a compaction:** run `chat-record path`; read the `## Scratchpoint` and latest handoff of the devlog that lists that path, then the record's last 80 lines (`tail -n 80`, widened with an offset read if one long paste fills them); do not re-derive state from the summary.
   If no devlog lists the path, the session kept none and the record tail is its whole durable state.

The steps make compaction a trimming event whose summary quality no longer decides resumption quality; for durable specialists, Phase 3's cap-and-reseed avoids compaction entirely.

### Scratchpoint

One `## Scratchpoint` section in the devlog the agent owns, replaced in place on every state-changing turn; aim for at most ~15 lines and ~8 `files:` entries, moving anything older into a handoff:

```markdown
## Scratchpoint

- as_of: 2026-09-22T18:40:11-07:00
- now: wiring the Stop check; block reason text not final
- since_handoff: Stop decides from the record's last marker line alone
- open: interrupt behavior of Stop
- next: run interactive canary, then commit hooks.json entry
- files:
  - plugins/cdocs/hooks/hooks.json (rw): the two shell-hook entries are the template for the new ones
  - plugins/cdocs/hooks/validate-cdocs-edit-path.sh (r): the jq stdin-parse and silent-exit guards to copy
```

- **Fields:** `as_of` (timestamp), `now`, `since_handoff` (facts not yet in a handoff), `open`, `next` (the single next action), `files`.
- **`files:`** one line per file read in full or edited since the last handoff, shape `- <path> (<r|w|rw>): <what it was useful for>`; files skimmed for a search hit do not belong.
  It gives awareness ("does this gist cover me, or do I need the bytes"), not cheaper re-reads; tasks needing exact content re-read regardless.
  At each handoff the list rolls into the handoff's Completed subsection and restarts empty.
- **Writers:** the overseer of any loop (`iterate`, `propose-revise`, `full-send`, `oversee`) and any Pillar-3 durable specialist; one-shot legs do not (their return summary is their checkpoint).
- **Versus the chat record:** the record accumulates, the Scratchpoint is overwritten; a post-compaction reader takes the Scratchpoint first and the record tail second.
- **Versus the thinness signal:** the judge reads the per-row `inline_work` column and the Scratchpoint's freshness; a Scratchpoint whose `as_of` is older than two Iteration Log rows, or absent, is reported as `overseer_thinness: signal_missing`.

Raw evidence (settings, commands, log lines) goes in the devlog's existing `## Verification` section, which splits as a standard chunk once its campaign lands.

### Devlog splitting at closed-concern boundaries

- **Trigger.** At every handoff, past ~12KB or ~5 loop rounds, the author looks for a boundary; size prompts the look, never chooses the cut.
- **Closed concern.** A completed phase, finished sub-loop, resolved investigation, or landed verification campaign that (i) has its own H2 or H3, (ii) has no open todo in the latest handoff (done or moved into the root's handoff), and (iii) feeds no live table in the root.
- **Cut.** Move every closed concern, one chunk each, with everything belonging to it (notes, debugging, its Changes Made and Verification rows, finished Iteration Log rows); merge a concern under ~3KB into an adjacent chunk; rows shared by two concerns, open concerns, and live tables stay in the root.
  No closed concern means no split.
- **Naming.** Flat siblings `cdocs/devlogs/YYYY-MM-DD-<root-slug>-<concern-slug>.md` with the root's date prefix and a concern-named slug (`-canary`, `-phase2-hooks`, `-iterate-r1-r5`).
- **Root as index.** The root keeps frontmatter (including `chat_record:`), Objective, `## Scratchpoint`, current handoff, live tables, and gains:

  ```markdown
  ## Chunks

  | chunk | concern | status | read this when |
  |---|---|---|---|
  | [-canary](2026-09-22-x-canary.md) | Phase-0 hook canary | done | you need a hook's exact payload fields |
  ```
- **Chunks stand alone.** Full frontmatter with the same `task_list`, `status: done`, new optional `part_of: cdocs/devlogs/<root>.md` (repo-root path, `review_of` semantics, grouped by `/cdocs:status` and `/cdocs:triage`), and no `chat_record:`; a standalone BLUF; a first-line `> NOTE(author/workstream): Chunk of [<root>](<root>.md); see its Chunks table for siblings.`

## Important Design Decisions

1. **Both capture and delivery.** Without capture, a post-compaction window seeds from a devlog up to a task unit stale; without delivery, captured state is never read.
2. **Line-delimited markdown, not JSONL.** The readers are a post-compaction agent and a human with `tail`; one regex per line type suffices.
3. **One file per session, full id in the name.** `session_id` is the only key both hooks and the agent have, sessions are the compaction unit, and the full id has no collision case.
4. **Turns delimited by marker order, no correlation ids.** The session id ties the record together and a sign-off closes each turn, so `Stop` decides from one line; ids would add a token to every header and a flag to every note for no reader.
5. **One append path; end time as a sign-off.** A single `>>` routine shared by hook and agent means nothing rewrites the file under a racing append; the end time is an appended sign-off because `@` headers mean attribution and the hook is not a speaker.
6. **Human prompts only; only human-initiated turns are checked.** A harness envelope is not something a successor needs verbatim, and the turn it triggers is reflected in the agent's own note when it matters; checking only turns that open with `@user` keeps the `Stop` rule one line.
7. **Record pointer in devlog frontmatter.** It is metadata about the devlog, a list fits multiple sessions, and frontmatter stays with the root when a devlog splits.
8. **Scratchpoint replace-in-place, soft size.** History is the record's job; appending state per turn would rebuild the devlog bloat the split rule exists to fix; the size is a target because the agent judges what current state needs.
9. **Semantic split, flat naming, root index.** A closed concern is a unit someone reads alone; flat names keep every path assumption intact.
10. **Resumption guidance in rules only; no agent-side compaction or context tracking.** Pillar 2 re-injects on every compaction and the record path is available from the environment, so no hook carries anything across the boundary.
    Compaction belongs to the user and the harness, and a pillar that both schedules compaction and disclaims it contradicts itself, so the existing cadence, compact steps, and self-estimated context column go.
    What made compaction safe was never its timing but the durable writes at task-unit boundaries, which stay; the judge reads thinness from `inline_work` and Scratchpoint freshness, which are observed rather than estimated.
11. **Two hooks and one `bin/` script; no settings edits.** `bin/` is the documented way to run a plugin file as a bare command; the cost is that a plugin with `bin/` is not installable through claude.ai or Cowork, which a CLI and OpenCode plugin accepts.
    `/cdocs:init` stays non-invasive; skip-permissions users need nothing and default-mode users add one rule.
12. **Committed by default, explicit-path staging.** Durability across worktrees outweighs the accepted leak channels in the WARN.
13. **One gist bullet per human-initiated turn, guided, backed by a one-shot block.** Every such turn has at least its outcome to note; a guideline rather than a prohibition list lets the agent note the occasional commit or test result that matters; the hook checks presence, never content.
14. **Agent-authored file awareness only.** A mechanical file list is relevance-blind; the agent's `read:` notes and `files:` gists carry relevance, and the transcript is the exhaustive fallback.
15. **Per-turn timestamps, no session markers.** Submission time on prompts and end time on sign-offs show durations and pauses; the first `@user` and last sign-off are the bookends; the title comes from the transcript so no third hook is needed.
16. **Top-level scoping by one rule sentence, with a named mechanical fallback.** The sentence sits beside the per-turn instruction, so every reader of the instruction reads the scope; the `if`-scoped `PreToolUse` deny is cheap and exact and ships only if Phase 1 shows a leak.
17. **Note body on stdin only.** Every argument form either expands or breaks on common text.

## Edge Cases

- **Harness prompts.** A background subagent's completion arrives as a `UserPromptSubmit` with no human input; a prompt whose first non-blank token is a known harness tag (`<task-notification`, `<system-reminder`, plus any the implementer observes) is not recorded, anything else (including pasted HTML) is `@user`.
  The turn it triggers starts after a sign-off, so `Stop` neither blocks nor writes unless the agent noted, in which case the note is followed by a sign-off.
- **Turns with no other tool call** (an answer, a dispatch-only turn) owe a bullet when human-initiated, the gist of the outcome; `note` is then the turn's one extra round trip.
- **Plan mode.** The harness forbids writes in plan mode, so `Stop` never blocks there; the turn gets its sign-off, and a note is optional.
- **Headless `-p`.** The block is honored; in default permission mode `note` needs the allow rule; a one-shot non-cdocs invocation should set `CDOCS_CHAT_RECORD=off`.
- **Interrupted turn.** If `Stop` does not fire, the turn has no entry and no sign-off, which is right for an abandoned turn.
  If interactive check (b) shows `Stop` fires on Escape and finds a payload field that marks the interruption, that field joins the `Stop` table's sign-off row, since resurrecting the agent after Escape defies the user; until then row 3 keys on `stop_hook_active` and plan mode alone.
  An empty `last_assistant_message` is not that signal: a turn whose final message is tool calls only may carry empty text too, and would silently skip the block.
  An interrupted human turn with no `Stop` leaves an unsigned `@user`, so the next harness-triggered turn's `Stop` blocks once; harmless, since a note then closes both.
- **Prompt typed mid-turn.** A queued prompt fires `UserPromptSubmit` before the running turn's single `Stop` (observed headless; interactive check (d) confirms), so the second `@user` lands inside the turn; marker order then reads both prompts as one turn, and `Stop` requires a note after the later one.
  Accepted: the note covers both.
- **Session id changes.** `/compact`, `--resume`, and `--continue` keep `session_id`, so appends continue in the same file.
  `/clear` and `--resume <id> --fork-session` mint a new `session_id`, and the Bash `CLAUDE_CODE_SESSION_ID` follows it, so the next prompt starts a new record and the old one ends at its last sign-off.
  That is the intended fresh start: no rule looks for the previous record.
  A user who wants continuity names the devlog, and step 1 adds the new record to its `chat_record:` list.
- **Working directory moves.** Hook `cwd` and the Bash `$PWD` both follow the agent, so `note` and `Stop` always resolve the same record.
  After `EnterWorktree` that is the worktree's copy of the record (committed from main) or a same-named new file; the union merge attribute reconciles the two when the branch merges or rebases.
  A `cd` into another directory with its own `cdocs/_chat/` moves the turn's note and sign-off there and leaves the original `@user` unsigned; accepted.
- **Double hooks.** Plugin hooks are not deduplicated, so a developer running `--plugin-dir` beside the enabled `cdocs@clauthier` gets doubled `@user` blocks and sign-offs; the README says to disable one.
- **Devlog at 20KB with no closed concern:** do not split; tighten prose and split landed verification evidence as its own chunk.
- **Chunk needed while a sub-loop's table is live:** only finished rows move; the live table stays with a pointer to the chunk.
- **OpenCode and other targets** (`.opencode/rules/`, `AGENTS.md` readers): hooks and `bin/` are Claude-Code-only and not ported, so these targets keep no chat record.
  The per-turn paragraph reaches them through `/cdocs:init` and is inert by its scope sentence; resumption there reads the devlog's Scratchpoint and latest handoff.

## Test Plan

`plugins/cdocs/hooks/tests/chat-record.test.sh` carries both suites.
`--unit` runs the pure-shell tests (no `claude`, no credentials) and runs in CI; the default mode also runs the headless scenarios, a manual Phase-1 gate because they need credentials.

**Phase 1 headless scenarios.**
Headless sandbox per the README recipe (sandboxed `CLAUDE_CONFIG_DIR` with copied credentials, empty `cdocs/` in an out-of-repo `cwd`, `--model haiku`, never `--bare`, `--plugin-dir <worktree under test>/plugins/cdocs`), run with `--permission-mode bypassPermissions` unless marked *default mode*.
*Default mode* scenarios run with `--permission-mode default` and are optional: they document the README allow rule and are not Phase-1 gates.
Each scenario is setup, then assertion on the record and the `--include-hook-events` stream (the sandbox project is a `git init`ed directory with `cdocs/_chat/`):

- `command -v chat-record` -> resolves into the worktree under test.
- read a file, then note `- read: a.txt: canary fixture` -> one `@user`, one `@haiku-4-5` entry with that body, one sign-off `-- <sid8> at <ts>`, in that order; one `Stop`, no `decision`.
- note body with a backtick span, `$HOME`, `$(date)`, an apostrophe, double quotes, a backslash -> body byte-exact.
- *default mode*, `Bash(chat-record:*)` allowed: the previous scenario -> no `permission_denials`.
- *default mode*, no allow rule -> `note` in `permission_denials`; first `Stop` blocks, second silent; `@user` then sign-off, no entry.
- read a file, told not to note -> first `Stop` blocks with the real path and the heredoc command; model notes; second `Stop` silent; one entry then sign-off.
- all tools forbidden -> first `Stop` blocks, second (`stop_hook_active`) writes the sign-off, no third `Stop`.
- minimal turn ("reply ok, then note it") -> one entry, one `Stop`, no block.
- two stream-json prompts, each noted -> `@user`, entry, sign-off, twice, timestamps non-decreasing.
- `note` twice in one turn -> two entries, one sign-off, no block.
- `note` without `--as` -> speaker `assistant`.
- `echo $CLAUDE_CODE_SESSION_ID` -> equals the stream's `session_id` and the filename suffix.
- `chat-record path` -> prints the path, creates nothing.
- background `Agent` dispatch, the notification turn told not to note -> no line of the envelope in the record; that turn's `Stop` emits no `decision` and writes nothing.
  Variant, the notification turn told to note -> its entry follows the previous sign-off and is followed by its own sign-off.
- foreground `Agent` dispatch that reads a file -> one `@user`; nothing written for any event with `agent_id`.
- top-level only: copy the init-produced `.claude/rules/cdocs.md` and the `CLAUDE.md` import line into the sandbox project; the top-level prompt is told not to note and dispatches (a) a foreground `cdocs:proposer` on a multi-round task and (b) a fork, where the installed version offers `subagent_type: "fork"` -> a test-only `PreToolUse` canary (`"if": "Bash(chat-record:*)"`) logs no `chat-record` call with non-null `agent_id`, and the top-level's first `Stop` still blocks.
- `/echo hello-world` from `.claude/commands/echo.md` -> one `@user` whose body is `/echo hello-world`.
- stream-json `/compact` between two prompts -> nothing between the first sign-off and the second `@user`; no line mentions compaction.
- stream-json `/clear` then a prompt -> a second file named by the new `session_id`; `echo $CLAUDE_CODE_SESSION_ID` in that turn prints the new id; the first file is unchanged after its last sign-off.
- `claude -p --resume <id>` and `--continue` -> new `@user` in the same file; `--resume <id> --fork-session` -> a new file.
- `/rename my-canary` (or an injected `custom-title` line), then two prompts -> the second turn's sign-off is `-- my-canary at <ts>` (the transcript is written asynchronously, so the first may lag).
- `--permission-mode plan`, one prompt -> one `Stop`, no `decision`; `@user` then sign-off.
- a turn that `cd`s into a sibling directory with its own `cdocs/_chat/` and notes there -> the note and the sign-off land in the sibling's record; one `Stop`, no `decision`.
- `CDOCS_CHAT_RECORD=off`, told not to note -> no file; one `Stop`, no `decision`.
- `cdocs/` without `_chat/`, and a directory outside any git work tree -> no file, no block.
- payload shape -> `prompt`, `stop_hook_active`, `transcript_path`, `session_id`, `cwd` present.

**Phase 1 unit tests (`--unit`).**

- Grammar: the test carries a ~10-line awk reference splitter sourcing `HEADER_RE` and `SIGNOFF_RE` from the script; round-trip on a fixture of a header-shaped first line, `@alice: hey`, LESS and CSS at-rules, headers inside fences, `\@` lines, a sign-off-shaped body line, an empty body, and CRLF input recovers every body and sign-off exactly; title `my canary "v2"` maps to `my-canary--v2-` and `""` to sid8.
- `Stop` decision: synthetic payloads against fixture records whose last marker is an agent header, `@user`, `@user` with `stop_hook_active`, a sign-off, and none; plus a record whose last line is an escaped `\@user: x` body line after an agent header -> outputs match the `Stop` table row for row.
- Harness skip: `UserPromptSubmit` payloads starting `<task-notification` and `<system-reminder` (after leading blanks) write nothing; `<div>` and `hello <task-notification` write `@user`.
- Exit codes: `CLAUDE_CODE_SESSION_ID` unset -> `note` and `path` exit non-zero, write nothing; `CDOCS_CHAT_RECORD=off` -> both exit 0, write nothing.
- Speaker: `--as 'opus-4-6[1m]'` -> header `@opus-4-6-1m-:`; `--as 'Opus 5.5'` -> `@Opus-5.5:`; `--as user`, `--as ''`, `--as -x` -> non-zero exit, nothing written.
- Stdout: `UserPromptSubmit` mode, recorded and skipped prompts alike, emits empty stdout; `Stop` emits only the block JSON.
- Plan mode: a `Stop` payload with `permission_mode: "plan"` against a record ending in `@user` -> sign-off, no output.
- Activation: a fixture with `cdocs/_chat/` above the git toplevel (the `~/cdocs/` case) and none inside -> no file; `cdocs/` without `_chat/` -> no file, no output; `path` relative to the toplevel prints `cdocs/_chat/...`.
- Multiple matches: two files for one session id -> `note` and `Stop` use the earliest-dated.
- Merge: in a scratch repo with the init-scaffolded `.gitattributes`, two branches each appending a turn to one committed record, and two branches each creating the same record -> merge and rebase finish without conflict and keep every block.

**Phase 1 interactive check** (once, recorded in the devlog with a record excerpt): (a) a forgotten note is blocked and recovered in one turn; (b) Escape mid-tool-call: whether `Stop` fires, its payload, whether it blocked; (c) `/rename` shows in the next sign-off; (d) a message typed mid-turn: whether `UserPromptSubmit` fires before the turn's `Stop` (see Edge Cases).

**Phase 1 rules check.** The `.claude/rules/cdocs.md` that `/cdocs:init` writes contains the per-turn rule's scope sentence; then a sandboxed session with those rules is compacted mid-task, and its first post-compaction tool calls are `chat-record path` and reads of the Scratchpoint and record tail, with no hook emitting `additionalContext`.

**Phase 1 usefulness sample.** A fresh reviewer scores twenty random entries from the real-session record on the successor test; pass at 80%.

**Phase 2.**

- Resumption A/B (gate for Phase 3), on three real workstreams with a `/compact` forced between handoffs: arm 1 resumes with step 3 of the resumption guidance removed from the rules, arm 2 with step 3 present; a fresh reviewer scores correct next action, no re-litigated decision, no redundant re-read.
  Pass: arm 2 wins or ties arm 1 on all three.
- Split dry-run on `2026-09-22-agent-dispatch-labeling.md` and `2026-05-12-rule-delivery-regression-test.md`: a fresh agent given only the root answers three task questions opening at most one chunk each.
- `/cdocs:triage` and `/cdocs:status` group chunks by `part_of`.

## Verification Methodology

Verify hooks by reading what they wrote, not by trusting that they ran; the canary recorder in the history report logs every event's full payload when an assertion needs the actual shape.

```bash
cd "$SANDBOX/proj" && CLAUDE_CONFIG_DIR="$SANDBOX/cfg" claude -p "<prompt>" --model haiku \
  --plugin-dir "$WORKTREE/plugins/cdocs" --permission-mode bypassPermissions \
  --output-format stream-json --verbose --include-hook-events > out.jsonl
```

The stream (`hook_response` decisions, `num_turns`, `permission_denials`) and the record file are independent evidence channels; the A/B and dry-run are scored by a fresh agent, never the author.

## Implementation Phases

### Phase 0: hook canary (done)

Evidence for every platform fact is in the history report's Platform Evidence table.
The script depends on: one `Stop` per top-level turn, never for a subagent; a single honored `Stop` block followed by `stop_hook_active=true`; `UserPromptSubmit` firing on a background agent's completion with the harness envelope as the prompt; `CLAUDE_CODE_SESSION_ID` in the Bash environment equal to the hook's `session_id`; a plugin's `bin/` on the Bash `PATH`; and no environment signal separating a subagent's Bash from the top level's.
Also established: `/clear` and `--fork-session` mint a new `session_id` that the Bash variable follows, while `/compact`, `--resume`, and `--continue` keep it; a prompt queued mid-turn fires `UserPromptSubmit` before the turn's single `Stop` (headless).
Unverified, and owned by Phase 1: `Stop` on interrupt, mid-turn prompts in an interactive session, `agent_id` on fork tool calls.

### Phase 1: capture, per-turn rule, resumption guidance

Deliverables:

1. `plugins/cdocs/bin/chat-record` per the Script section, committed as mode `100755` like the existing hook scripts (the directory marketplace runs it from the working tree); `hooks.json` entries for `UserPromptSubmit` and `Stop`.
2. `plugins/cdocs/hooks/tests/chat-record.test.sh` with the headless scenarios and the `--unit` suite; a CI workflow `.github/workflows/cdocs-hooks.yml`, path-filtered to `plugins/cdocs/bin/**` and `plugins/cdocs/hooks/**`, running `--unit` on `ubuntu-latest` (bash, `jq`, `git`).
3. `/cdocs:init`: scaffold `cdocs/_chat/README.md` (one paragraph: hook-written, do not edit, opt-outs) and `cdocs/_chat/.gitattributes` (`*.md merge=union`); write `orchestration-discipline.md` Pillar 2 into `.claude/rules/cdocs.md`, the file Claude Code loads (today only `AGENTS.md` inlines it).
4. `frontmatter-spec.md`: one line on `_chat/`, and the optional devlog field `chat_record:` (list of repo-root record paths).
   README "Hooks": the two hooks, activation (git toplevel, `cdocs/_chat/`), block semantics, the one-line allow-rule note for default permission mode, the `bin/` installability trade-off, opt-outs, and one line on doubled hooks under `--plugin-dir` beside the installed plugin.
   `plugins/cdocs/hooks/cdocs-hooks.ts`: its "NOT ported from CC" header lists the chat-record hooks (OpenCode keeps no record).
5. `orchestration-discipline.md` Pillar 2: the per-turn rule paragraph (Script section), the three resumption steps, the commit protocol and Pillar 1 carve-out, and "never `Edit` or `Write` `cdocs/_chat/`".
6. Remove agent-side compaction instructions and context self-estimates everywhere in the plugin, keeping each durable-state write at its task-unit boundary so a user-run or automatic compaction loses nothing:
   - `plugins/cdocs/rules/orchestration-discipline.md`: delete Pillar 2's "Proactive compaction cadence" subsection (the `/compact`/`/clear` instruction, the 3-to-5-iteration trigger, the ~150K target); the Pillar 2 lead says the overseer keeps durable state current instead of "checkpointing and compacting deliberately"; "Handoff-before-compact format" becomes "Handoff format", written at each task-unit boundary, without "BEFORE compacting" or the compact-without-handoff sentence; the reseed subsection's "aggressive compaction" becomes "compaction"; the inline-floor line's "durable state before compact" becomes "durable state at task-unit boundaries", and the NOTE listing "proactive compaction cadence" drops that item; "Judge-Observable Thinness Signal" keeps `inline_work` as the overseer-written signal and drops the context estimate and its example; Cross-Target Degradation replaces the compaction-cadence sentence with "off Claude Code there is no chat record; resumption reads the devlog's Scratchpoint and latest handoff".
   - `plugins/cdocs/rules/oversee-arc.md`: the arc-state write happens at every arc-level transition, without "BEFORE compacting"; "handoff-before-compact" becomes "handoff"; the "Where `/compact` is absent" degradation bullet is deleted.
   - `plugins/cdocs/skills/iterate/SKILL.md`: the inline floor's "before compacting" becomes "at task-unit boundaries"; "Checkpoint (handoff-before-compact)" becomes "Checkpoint (handoff)", firing at each judge assessment and on Accept, without the 3-to-5-iteration trigger, "THEN compact (`/compact`, or `/clear` for a hard reset)", or "compacting without it is a failure"; Termination's soft-budget sentence drops "Overseer context trending past the ~150K target"; the Iteration Log paragraph drops `overseer_ctx_est`.
   - `plugins/cdocs/skills/iterate/template.md`: the `overseer_ctx_est` column leaves both table headers, the field list, and the example row; `signal_missing` keys on the `inline_work` column.
   - `plugins/cdocs/skills/oversee/SKILL.md` and `plugins/cdocs/skills/oversee/template.md`: the inline floor, the "Transition-write BEFORE compact" bullet, and "Checkpoint (proposal boundary)" lose "before compacting", "then compact (`/compact`, or `/clear` for a hard reset)", and "compacting without them is a failure"; the concurrency cap drops "against the overseer's ~150K-token budget"; Cross-Target Degradation drops the "absent `/compact`" clause.
   - `plugins/cdocs/skills/propose-revise/SKILL.md`, `plugins/cdocs/skills/full-send/SKILL.md`, `plugins/cdocs/skills/ablate/SKILL.md`: "before compacting" becomes "at task-unit boundaries".
   - `plugins/cdocs/agents/judge.md`: `overseer_thinness` and the escalate weighing read the `inline_work` column; the `overseer_ctx_est` trend and "context trending past target" go, leaving loop length as the soft cap.
   - `plugins/cdocs/agents/triage.md`: the schema-drift note gives the template's current column count and names `overseer_ctx_est` as a column older devlogs may carry (reading by header name already copes).

   Descriptive mentions stay: the reseed subsection, `triage/SKILL.md` "Context Management", and the resumption steps.
7. `plugins/cdocs/skills/devlog/SKILL.md` and `template.md`: name the optional `chat_record:` field and point to Pillar 2's per-turn rule for how it is filled; records quoted only in fences; `## Verification` as the evidence home.
   No `chat-record` command, heredoc, or bullet categories there: dispatched implementers read the devlog skill, and the top-level scope sentence is not beside it.
8. The interactive check, rules check, and usefulness sample, recorded in the devlog with the interrupt and mid-turn decisions written down.
9. Mark `2026-09-01-devlog-autoflush-hook.md` `status: evolved` with a pointer here.

Success criteria: the `--unit` suite green in CI and every non-optional headless scenario green locally; a real session of at least twenty turns in this repo commits a record in which every `@user` is followed by at least one top-level entry and exactly one sign-off before the next `@user`, with gist-shaped bullets and a passing usefulness sample; the interactive and rules checks pass.
If the top-level-only scenario shows a subagent or fork entry, the `PreToolUse` fallback ships before Phase 1 closes.

Constraints: do not touch `inject-rules.ts`, `validate-cdocs-edit-path.sh`, or `cdocs-validate-frontmatter.sh`; do not add `_chat/` to either path regex; add no hook entries beyond `UserPromptSubmit` and `Stop` (and the named fallback, if triggered); no runtime-directory files; the only `decision: block` is the `Stop` one-shot; `/cdocs:init` writes no settings file; `plugins/cdocs/agents/*.md`, skills, and templates gain no `chat-record` command text (only Pillar 2 carries it, behind its scope sentence); after Phase 1 no plugin file tells an agent to run, request, or time `/compact` or `/clear` or to estimate its own context (`grep -rn 'ctx_est\|150K' plugins/cdocs` is empty and every `compact` hit is descriptive), while `inline_work` and `overseer_thinness` keep their names.

### Phase 2: scratchpoint and semantic splitting

Depends on Phase 1 (the resumption steps name the Scratchpoint).

1. `orchestration-discipline.md`: a Scratchpoint subsection under Pillar 2 (format, soft size, writers, cadence, staleness rule); the handoff's Completed subsection gains `files:` gists; Pillar 3 says durable specialists keep one.
2. Devlog `template.md` gains `## Scratchpoint`; `iterate`, `propose-revise`, `full-send`, `oversee`, and `implement` reference the rule in one line each; `agents/implementer.md` tells a warm implementer to maintain it.
3. Devlog `SKILL.md`: "Splitting a devlog" with the trigger, closure test, cut and merge rules, naming, Chunks table, chunk frontmatter and backlink; Pillar 2's handoff step adds the size check.
4. `frontmatter-spec.md`: optional `part_of`; `triage` and `status` group by it; `agents/judge.md` gains the Scratchpoint staleness condition.
5. The A/B and split dry-run, results in the devlog.

Success criteria: the A/B pass bar; the dry-run's one-chunk bar; `cdocs-validate-frontmatter.sh` accepts chunks unchanged.
Constraints: no directory-per-workstream layout.

### Phase 3 (gated on the Phase-2 A/B)

1. **Cap-and-reseed durable specialists:** at a cutoff on the specialist's harness-reported usage (tentatively ~0.4-0.6M tokens), the overseer has the specialist write a final Scratchpoint and handoff, then dispatches a fresh leg seeded from them; dispatch-level, needing no compaction.
2. **Per-workstream record:** scoped in [`2026-10-05-tiered-chat-records-rfp.md`](2026-10-05-tiered-chat-records-rfp.md).

Success criteria: a reseeded specialist continues without re-reading its predecessor's files.
