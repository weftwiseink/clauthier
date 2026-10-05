---
first_authored:
  by: "@claude-fable-5-1"
  at: 2026-09-22T18:27:04-07:00
task_list: meta/chat-record-devlog-management
type: proposal
state: live
status: implementation_ready
last_reviewed:
  status: accepted
  by: "@claude-opus-5-5"
  at: 2026-10-05T10:25:58-07:00
  round: 8
tags: [meta, tooling, context_persistence, hooks, devlog, orchestration, agent-memory]
---

# Chat Record, Scratchpoint, and Semantic Devlog Splitting

> BLUF(fable-5-1/chat-record-devlog-management): A per-session **chat record** under `cdocs/_chat/` holds hook-captured verbatim user turns plus one terse agent-written gist bullet per top-level turn, each turn closed by a `Stop`-written `-- <session> at <time>` sign-off; `Stop` blocks once when a turn has no entry.
> Two hooks, one script (`plugins/cdocs/bin/chat-record`, note text on stdin via quoted heredoc), one `/cdocs:init` permission rule; compaction guidance lives in rules, not hooks.
> A rolling devlog **`## Scratchpoint`** holds current state; devlogs split at closed-concern boundaries.

## Summary

This proposal operationalizes [`2026-09-22-chat-record-scratchpoint-design.md`](../reports/2026-09-22-chat-record-scratchpoint-design.md) and the devlog-management half of the context-management roadmap (RFP-2): file formats, hook contract, rule and skill text, and a phased rollout.

| Artifact | Author | Cadence | Location |
|---|---|---|---|
| Chat record | hook (user turns, sign-offs) plus the top-level agent (gist bullets via `chat-record note`); one script does every append | every turn | `cdocs/_chat/YYYY-MM-DD-<session_id>.md` |
| Scratchpoint | the overseer or a durable specialist | every state-changing turn, replaced in place | `## Scratchpoint` in the devlog that agent owns |
| Devlog chunks | the devlog's author | at a handoff when a concern has closed | `cdocs/devlogs/YYYY-MM-DD-<root>-<concern>.md`, root becomes index |

The chat record is chronology (what a successor should know, in the order it was learned); the Scratchpoint is a bounded current-state snapshot; both are agent-authored and terse, and no hook supplies content.
How the design reached this shape, the approaches it rejected, and the runtime evidence behind each platform fact are in the supplemental [`2026-10-05-chat-record-design-history.md`](../reports/2026-10-05-chat-record-design-history.md).

## Objective

Make the compaction summary's quality irrelevant to resumption: at any moment, durable state exists that is at most one turn stale, and a fresh or post-compaction window is seeded from that state rather than from a summary.
Keep devlogs skimmable by splitting them where the work has seams, so a resuming agent reads one relevant chunk rather than a 40KB chronology.

## Background

1. [`2026-09-22-chat-record-scratchpoint-design.md`](../reports/2026-09-22-chat-record-scratchpoint-design.md): capture and delivery are complementary; scoping; 3-phase rollout.
2. [`2026-09-20-token-spend-by-role.md`](../reports/2026-09-20-token-spend-by-role.md) workstream 1 (the capture mechanisms) and workstream 4 (cap-and-reseed, which depends on them).
3. [`2026-09-19-devlog-methodology-value.md`](../reports/2026-09-19-devlog-methodology-value.md) recommendations 2 and 3: point compaction at the devlog; split past ~10-15KB or ~5 rounds.
4. [`orchestration-discipline.md`](../../plugins/cdocs/rules/orchestration-discipline.md) Pillar 2 (handoff-before-compact, cadence, reseed: unscoped rules re-inject on every compaction) and the judge-observable thinness columns this proposal generalizes.
5. [`plugins/cdocs/skills/devlog/SKILL.md`](../../plugins/cdocs/skills/devlog/SKILL.md) and `template.md`, which the Scratchpoint and split rule extend.
6. [`plugins/cdocs/hooks/hooks.json`](../../plugins/cdocs/hooks/hooks.json), the README's "Sandbox testing notes", and the plugin reference's `bin/` rule (a plugin's `bin/` is on the Bash tool's `PATH` while enabled; `CLAUDE_PLUGIN_ROOT` is not exported to Bash-tool commands).
7. [`2026-09-01-devlog-autoflush-hook.md`](2026-09-01-devlog-autoflush-hook.md): RFP stub answered here (a hook can force a write once per turn via a `Stop` block; the active devlog is recovered from the chat-record path it names); marked `evolved` at Phase 1.
8. [`2026-09-22-shared-retrieval-cache-redundancy-check.md`](../reports/2026-09-22-shared-retrieval-cache-redundancy-check.md): the file-awareness half is folded in as `read:` notes and Scratchpoint `files:` gists; the token-cost half is out of scope.
9. [`2026-10-05-chat-record-design-history.md`](../reports/2026-10-05-chat-record-design-history.md): design history, rejected approaches, and platform evidence.

### Non-Goals

- Graphify-scoped retrieval; memory-tool integration; post-hoc devlog distillation by a cheap model.
- Cross-agent content sharing: the gists give awareness, not cheaper re-reads, and make no claim on the measured 97.4% cross-agent re-read figure.
- Mechanical capture of files touched (no `PostToolUse` hook).
- Compaction awareness in the record: no compaction hook, no session start, end, or compaction lines.
- Chat records for dispatched subagents (Phase 3 pointer only).
- Hook-authored scratchpoints: a hook can nudge, never author.
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
    participant DL as devlog (## Scratchpoint, handoff)
    U->>H: UserPromptSubmit
    H->>CR: create file if absent; append @user: <submit ts> p=<pid8>
    A->>DL: replace ## Scratchpoint (every state-changing turn)
    A->>N: bullets as quoted heredoc on stdin (every turn)
    N->>CR: append @<model>: <ts> p=<pid8> entry
    A-->>H: Stop
    alt entry with this p= exists, stop_hook_active, or block suppressed
        H->>CR: append sign-off line: -- session at end ts
    else no entry, first Stop
        H-->>A: decision=block, reason names the record path and the note command
    end
    Note over A: rules (Pillar 2): at a task-unit boundary write handoff + Scratchpoint, commit, ask user for /compact or /clear
    Note over A: rules (re-injected after compaction): chat-record path, then Scratchpoint + handoff + record tail
```

### Chat record

#### Location and naming

- Path: `cdocs/_chat/YYYY-MM-DD-<session_id>.md`, full session id, date of the first recorded prompt; one file per Claude Code session.
- Lookup is by glob `cdocs/_chat/*-<session_id>.md`, never by recomputing the date, so `--resume` on a later day appends to the same file.
- Created lazily by the first `UserPromptSubmit` or `note`.
- `cdocs/` is found by walking up from the payload's `cwd` (hook mode) or `$PWD` (`note`, `path`).
- The session id comes from the hook payload, and in the agent's Bash from `CLAUDE_CODE_SESSION_ID` (undocumented; equal to the hook's `session_id`, asserted by a Phase-1 test).
- The workstream link runs the other way: on its first turn the agent writes `chat-record path`'s output into its devlog's `## Chat Record` section, and the devlog is recovered by `grep -l '<record path>' cdocs/devlogs/*.md`.
- `_chat/` is a mechanical asset directory like `_media/`: no frontmatter, outside the frontmatter-validation and edit-path regexes (which match only the four typed directories); `frontmatter-spec.md` gains one line saying so.

**Commit protocol.** Records are committed, because untracked durable state does not cross worktrees or sessions.
The record grows every turn, so the overseer stages it by explicit path at each handoff (`git add cdocs/_chat/<file> cdocs/devlogs/<devlog>`) in the devlog bookkeeping commit; dispatched agents never stage `cdocs/_chat/` (no `git add -A`, no `commit -a`).
This is a carve-out to Pillar 1's "the overseer does not commit code itself": record and devlog commits are bookkeeping.

> WARN(fable-5-1/chat-record-devlog-management): A committed record leaks two ways: text a human pastes into a prompt, and agent bullets that echo a secret from a tool result.
> The gist guideline narrows the second; neither is closed.
> Maintainer decision: commit by default, no redaction; opt-outs are `CDOCS_CHAT_RECORD=off` and gitignoring `cdocs/_chat/` (losing cross-worktree durability).

#### Format

A record is a sequence of blocks, each a header line followed by a body; only real speakers get `@` headers, and a turn ends with a sign-off line.

```
HEADER_RE  := ^@[A-Za-z0-9][A-Za-z0-9._-]*:
SIGNOFF_RE := ^-- [A-Za-z0-9._-]+ at [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:[0-9]{2}( p=[0-9a-f]{8})?$
header     := HEADER_RE (" " timestamp (" p=" pid8)?)?    ; timestamp: date -Iseconds
signoff    := "-- " session " at " timestamp (" p=" pid8)?   ; p= only per Edge Cases
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
| `@harness` | `UserPromptSubmit`, harness envelope (Edge Cases) | submission | the prompt, verbatim |
| `@<model-short>` (`@opus-4-8`, `@fable-5-1`) | the top-level agent via `note --as <model-short>` (default `assistant`) | note time | one to three gist bullets |

`<model-short>` is the model id without `claude-` and any `-YYYYMMDD` suffix; the agent supplies it, since no hook payload carries a model.
`p=` is the first 8 hex of `prompt_id`; it correlates a turn's prompt and entry and is what the `Stop` check keys on.
The sign-off carries the end time and session name and belongs to its turn by position; a turn's duration is its `@user` time to its sign-off.

**Gist entries.** One to three bullets per turn, one line each, under ~120 characters, each with a category prefix (no prefix reads as `gist:`):

- `gist:` what the turn concluded, decided, or changed, phrased for a successor: `gist: Stop block is the enforcer; reviewer r5 returned revise on two blockers`.
- `query:` a search or retrieval that proved useful and what it found: `query: graphify query "hook events" surfaced the matcher table; reuse before grepping`.
- `read:` a high-salience file and why: `read: plugins/cdocs/hooks/validate-cdocs-edit-path.sh: the jq stdin-parse and silent-exit pattern`.
- `follow-up:` an open thread: `follow-up: interrupt behavior of Stop unverified; needs a real-session check`.

The test for a bullet: would a successor reading only the `@user` blocks and these bullets know where things stand.
Guideline, not prohibition: do not log every commit, test run, edit, or tool output, and do not paste the reply; but a commit that closes a long thread or a test result that changes the plan may be the turn's gist.
The shape to avoid is the enumerated log (`- edited X - ran tests - committed abc`); the shape to produce is the one-line state of play.
Slash commands are recorded as the raw invocation string; built-in `/compact` and `/clear` fire no `UserPromptSubmit` and leave no trace.

Example (user lines from a canary run; entries illustrative):

```
@user: 2026-09-22T18:20:54-07:00 p=c76c22bb
Reply with exactly the word: alpha

@fable-5-1: 2026-09-22T18:20:56-07:00 p=c76c22bb
- query: `jq -c '{prompt_id}'` on the canary log shows Stop and UserPromptSubmit share prompt_id
- read: plugins/cdocs/README.md "Sandbox testing notes": the credential-copy recipe every headless canary needs
- follow-up: whether Stop fires on an interrupted turn; check in a real session before Phase 1 ships

-- hook-canary at 2026-09-22T18:20:57-07:00

@user: 2026-09-22T18:21:05-07:00 p=ab2a3ea6
Reply with exactly the word: beta.

@fable-5-1: 2026-09-22T18:21:07-07:00 p=ab2a3ea6
- gist: replied beta; no state change

-- hook-canary at 2026-09-22T18:21:08-07:00
```

#### Script: `plugins/cdocs/bin/chat-record`

Bash plus `jq` (both hooks are on every turn's critical path; `npx tsx` startup is measurable), in the plugin's `bin/` so the agent runs it as the bare command `chat-record`.

| Mode | Invocation | Behavior |
|---|---|---|
| hook | `${CLAUDE_PLUGIN_ROOT}/bin/chat-record UserPromptSubmit` (from `hooks.json`, timeout 5s) | append `@user` or `@harness`, `p=` from `prompt_id`; never blocks |
| hook | `${CLAUDE_PLUGIN_ROOT}/bin/chat-record Stop` (timeout 5s) | per the table below |
| agent | `chat-record note [--as <speaker>] [--p <pid8>]`, bullets on stdin | append `@<speaker>` with current time, `p=` from `--p`, else from the last `@user`/`@harness` header, else omitted |
| agent | `chat-record path` | print the record path; never create the file |

The note body is read from stdin only, and the one documented form is the quoted heredoc, which performs no expansion:

```bash
chat-record note --as fable-5-1 <<'EOF'
- query: `rg -n "prompt_id"` found the Stop/UserPromptSubmit correlation; didn't need the binary
EOF
```

A double-quoted argument would execute backticks and `$(...)` and expand `$VAR`; a single-quoted one breaks on apostrophes.
The heredoc form matches the permission rule `Bash(chat-record:*)` and delivers the body byte-exact (history report, run R7).

`Stop` behavior, after the guards below:

| Condition | Writes | Emits |
|---|---|---|
| the record has a non-`user`/`harness` block with `p=<pid8>`, or `stop_hook_active` is true | sign-off | nothing |
| no entry, and the block is not suppressed | nothing | `{"decision":"block","reason":"<block text>"}` |
| no entry, and the block is suppressed: interrupted turn (signal per interactive check (c)) or no `prompt_id` in the payload | sign-off | nothing |

Block text, real values substituted (under 300 bytes):

```
No chat-record entry for this turn (record: cdocs/_chat/2026-10-05-<session_id>.md). Run, then finish:
chat-record note --p ab2a3ea6 --as <your model> <<'EOF'
- gist: <what a successor should know from this turn>
EOF
```

Guards and invariants:

- **Silent exits, hook mode.** Exit 0 with no write and no block when: the payload carries `agent_id` (in `UserPromptSubmit` and `Stop`); `CDOCS_CHAT_RECORD=off`; `jq` is missing; no `cdocs/` above `cwd`; or (for `Stop`) no record file exists.
  Hook mode always exits 0 and writes errors to stderr only.
- **Agent modes fail loudly.** `note` and `path` exit non-zero with a one-line stderr reason when `CLAUDE_CODE_SESSION_ID` is unset, no `cdocs/` is found, `jq` is missing, or the write fails; `CDOCS_CHAT_RECORD=off` is a silent exit 0.
- **Never loops.** `stop_hook_active=true` is never blocked, so a turn costs at most one extra short turn; an agent that ignores the block ends the turn with no entry, and the gap shows as a `@user` followed directly by its sign-off.
- **One append path.** Every write is a single `printf ... >>` of a whole block or line (`O_APPEND`), so a `note` racing a `Stop` interleaves at block granularity; agents read records (`tail`, offset `Read`) and never `Edit` or `Write` them.
- **No state beyond the record.** `last_assistant_message` is never written, `Stop` checks presence by `p=` and never content, and no runtime-directory files exist.

**Per-turn rule and cost.** Pillar 2 says: in the top-level session, before ending a turn, append at least one bullet with `chat-record note`, issued in the same parallel tool batch as the turn's last action when the outcome is known.
The common case then costs no extra round trip; a turn with no other tool call pays one.
The `Stop` block is the backstop, not the mechanism; with every block ignored the record still holds verbatim user turns and sign-offs.

**Permissions.** `/cdocs:init` merges `"Bash(chat-record:*)"` into `permissions.allow` in `.claude/settings.json` (creating file or key, never removing entries), because an unallowlisted per-turn call prompts interactively and is denied headless.
The README documents the same rule and the per-invocation form (`claude -p --allowedTools "Bash(chat-record:*)"`).

#### Top-level only

The chat record is the top-level session's.
Hook mode is guarded by `agent_id`; `note` sees no payload, and inside a subagent `CLAUDE_CODE_SESSION_ID` is the parent's id and the `CLAUDE*`/`AI_AGENT` environment is identical to the top level's (history report, run R7).
A subagent's `note` would therefore land in the top-level record and, taking `p=` from the overseer's in-flight `@user`, satisfy the overseer's `Stop` check.

- **Phase-1 guard: rule text.** Pillar 2's per-turn rule opens "Top-level session only: if you were dispatched by the `Agent` tool (including as a fork), never run `chat-record`", and each `plugins/cdocs/agents/*.md` carries one line saying the same.
  Forks inherit the parent transcript, including its `note` habit, and no agent definition applies to them, so the Pillar 2 line is their only guard.
- **Named fallback: a `PreToolUse` deny.** If the Phase-1 subagent or fork scenario shows a leak, add `{"matcher": "Bash", "hooks": [{"type": "command", "if": "Bash(chat-record:*)", "command": "${CLAUDE_PLUGIN_ROOT}/bin/chat-record PreToolUse"}]}`, a mode that denies with a one-line reason when the payload carries `agent_id`.
  The `if` field limits it to `chat-record` calls (verified on 2.1.289, run R8), so its cost is one entry and roughly one process spawn per turn; it is held back only to keep the two-hook surface.

> NOTE(opus-5-5/chat-record-devlog-management): Top-level scoping is via rule text (an agent knows whether it is top-level) with the `PreToolUse` deny as a named fallback; attributed subagent notes and any tiered/per-workstream record are deferred to [`2026-10-05-tiered-chat-records-rfp.md`](2026-10-05-tiered-chat-records-rfp.md).

### Compaction guidance (rules only)

Compaction is a user action ([#71803](https://github.com/anthropics/claude-code/issues/71803)), so the guidance lives where it survives compaction: Pillar 2 of `orchestration-discipline.md`, which `/cdocs:init` writes into `.claude/rules/cdocs.md` and which re-injects on every compaction.
Pillar 2 gains three steps:

1. **First turn of a session:** run `chat-record path` and write the result into the devlog's `## Chat Record` section.
2. **Task-unit boundary** (every 3-5 loop iterations, or when a judge returns): write the handoff, refresh the Scratchpoint, commit devlog and record by explicit path, and end the turn asking the user to run `/clear`, or:

   ```
   /compact Preserve verbatim from cdocs/devlogs/<devlog>.md: the ## Scratchpoint block and the latest Completed / Decisions Made / Open Todos handoff. Keep the paths cdocs/devlogs/<devlog>.md and cdocs/_chat/<record>.md and the last three user turns verbatim. Drop tool outputs and file contents; they are re-readable.
   ```
3. **After any compaction or clear:** run `chat-record path`; read the `## Scratchpoint` and latest handoff of the devlog that names that path, then the last five blocks of the record; do not re-derive state from the summary.
   If no devlog names the path, create or resume one and write the pointer.

This does not prevent auto-compaction: in AFK and headless sessions nobody types `/compact`, and context growth is not fully agent-controlled.
It makes compaction a trimming event whose summary quality no longer decides resumption quality; for durable specialists, Phase 3's cap-and-reseed avoids compaction entirely.

### Scratchpoint

One `## Scratchpoint` section in the devlog the agent owns, replaced in place on every state-changing turn, at most 15 lines and 8 `files:` entries:

```markdown
## Scratchpoint

- as_of: 2026-09-22T18:40:11-07:00 ctx: ~140K (10% inline)
- now: wiring the Stop check; block reason text not final
- since_handoff: Stop.prompt_id matches UserPromptSubmit.prompt_id
- open: interrupt behavior of Stop; /clear effect on session_id
- next: run interactive canary, then commit hooks.json entry
- files:
  - plugins/cdocs/hooks/hooks.json (rw): the two shell-hook entries are the template for the new ones
  - plugins/cdocs/hooks/validate-cdocs-edit-path.sh (r): the jq stdin-parse and silent-exit guards to copy
```

- **Fields:** `as_of` (timestamp and the context estimate `overseer_ctx_est` already asks for), `now`, `since_handoff` (facts not yet in a handoff), `open`, `next` (the single next action), `files`.
- **`files:`** one line per file read in full or edited since the last handoff, shape `- <path> (<r|w|rw>): <what it was useful for>`; files skimmed for a search hit do not belong.
  It gives awareness ("does this gist cover me, or do I need the bytes"), not cheaper re-reads; tasks needing exact content re-read regardless.
  At each handoff the list rolls into the handoff's Completed subsection and restarts empty.
- **Writers:** the overseer of any loop (`iterate`, `propose-revise`, `full-send`, `oversee`) and any Pillar-3 durable specialist; one-shot legs do not (their return summary is their checkpoint).
- **Versus the chat record:** the record accumulates, the Scratchpoint is overwritten; a post-compaction reader takes the Scratchpoint first and the record tail second.
- **Versus the thinness columns:** the columns stay as the judge's per-row bloat signal; a Scratchpoint whose `as_of` is older than two Iteration Log rows, or absent, is reported as the judge's existing `overseer_thinness: signal_missing`.

The devlog also carries a two-line `## Chat Record` section: the record path and the time of the last handoff.
Raw evidence (settings, commands, log lines) goes in the devlog's existing `## Verification` section, which splits as a standard chunk once its campaign lands.

### Devlog splitting at closed-concern boundaries

- **Trigger.** At every handoff, past ~12KB or ~5 loop rounds, the author looks for a boundary; size prompts the look, never chooses the cut.
- **Closed concern.** A completed phase, finished sub-loop, resolved investigation, or landed verification campaign that (i) has its own H2 or H3, (ii) has no open todo in the latest handoff (done or moved into the root's handoff), and (iii) feeds no live table in the root.
- **Cut.** Move every closed concern, one chunk each, with everything belonging to it (notes, debugging, its Changes Made and Verification rows, finished Iteration Log rows); merge a concern under ~3KB into an adjacent chunk; rows shared by two concerns, open concerns, and live tables stay in the root.
  No closed concern means no split.
- **Naming.** Flat siblings `cdocs/devlogs/YYYY-MM-DD-<root-slug>-<concern-slug>.md` with the root's date prefix and a concern-named slug (`-canary`, `-phase2-hooks`, `-iterate-r1-r5`).
- **Root as index.** The root keeps frontmatter, Objective, `## Chat Record`, `## Scratchpoint`, current handoff, live tables, and gains:

  ```markdown
  ## Chunks

  | chunk | concern | status | read this when |
  |---|---|---|---|
  | [-canary](2026-09-22-x-canary.md) | Phase-0 hook canary | done | you need a hook's exact payload fields |
  ```
- **Chunks stand alone.** Full frontmatter with the same `task_list`, `status: done`, and new optional `part_of: cdocs/devlogs/<root>.md` (repo-root path, `review_of` semantics, grouped by `/cdocs:status` and `/cdocs:triage`); a standalone BLUF; a first-line `> NOTE(author/workstream): Chunk of [<root>](<root>.md); see its Chunks table for siblings.`

## Important Design Decisions

1. **Both capture and delivery.** Without capture, a post-compaction window seeds from a devlog up to a task unit stale; without delivery, captured state is never read.
2. **Line-delimited markdown, not JSONL.** The readers are a post-compaction agent and a human with `tail`; one regex per line type suffices.
3. **One file per session, full id in the name.** `session_id` is the only key both hooks and the agent have, sessions are the compaction unit, and the full id has no collision case.
4. **One append path; end time as a sign-off.** A single `>>` routine shared by hook and agent means nothing rewrites the file under a racing append; the end time is an appended sign-off because `@` headers mean attribution and the hook is not a speaker.
5. **Scratchpoint replace-in-place.** History is the record's job; appending state per turn would rebuild the devlog bloat the split rule exists to fix.
6. **Semantic split, flat naming, root index.** A closed concern is a unit someone reads alone; flat names keep every path assumption intact.
7. **Compaction guidance in rules only.** Pillar 2 re-injects on every compaction and the record path is available from the environment, so no hook carries anything across the boundary.
8. **Two hooks, one `bin/` script, one permission rule.** `bin/` is the documented way to run a plugin file as a bare command; the cost is that a plugin with `bin/` is not installable through claude.ai or Cowork, which a CLI and OpenCode plugin accepts.
9. **Committed by default, explicit-path staging.** Durability across worktrees outweighs the accepted leak channels in the WARN.
10. **One gist bullet per turn, guided, backed by a one-shot block.** Every turn has at least its outcome to note; a guideline rather than a prohibition list lets the agent note the occasional commit or test result that matters; the hook checks presence, never content.
11. **Agent-authored file awareness only.** A mechanical file list is relevance-blind; the agent's `read:` notes and `files:` gists carry relevance, and the transcript is the exhaustive fallback.
12. **Per-turn timestamps, no session markers.** Submission time on prompts and end time on sign-offs show durations and pauses; the first `@user` and last sign-off are the bookends; the title comes from the transcript so no third hook is needed.
13. **Top-level scoping by rule text, with a named mechanical fallback.** See "Top-level only": rule text keeps the two-hook surface; the `if`-scoped `PreToolUse` deny is cheap and exact and ships if Phase 1 shows a leak.
14. **Note body on stdin only.** Every argument form either expands or breaks on common text.

## Edge Cases

- **Harness prompts.** A background subagent's completion arrives as a `UserPromptSubmit` with no human input; a prompt whose first non-blank token is a known harness tag (`<task-notification`, `<system-reminder`, plus any the implementer observes) is `@harness`, anything else (including pasted HTML) is `@user`.
  A harness turn owes a bullet like any other; a leg's return is usually the turn's gist.
- **Turns with no other tool call** (an answer, a dispatch-only turn) owe a bullet, the gist of the outcome; `note` is then the turn's one extra round trip.
- **Headless `-p`.** The block is honored; `note` needs the permission rule; a one-shot non-cdocs invocation should set `CDOCS_CHAT_RECORD=off`.
- **Interrupted turn.** If `Stop` does not fire, the turn has no entry and no sign-off, which is right for an abandoned turn.
  If it fires, the block is suppressed (resurrecting the agent after Escape defies the user) and the sign-off is written; interactive check (c) finds the distinguishing signal (candidate: empty `last_assistant_message`).
- **Prompt typed mid-turn.** If interactive check (e) shows it fires `UserPromptSubmit` mid-turn, the record reads `@user A`, `@user B`, entries; `note` defaults to B's `p=`, `Stop(A)` blocks and the recovery note carries `--p A`, and the sign-off lands after B's block.
  In that case the sign-off gains a trailing ` p=<pid8>` and readers correlate by `p=`, not position.
- **`Stop` without a matching `@user`, record present** (hook enabled mid-session): the check finds no entry and blocks once with `--p` in the reason, so the note correlates despite a stale last header.
- **`--resume`** keeps `session_id` and appends to the same file; `/clear` and `/resume` effects are a Phase-1 test, and either outcome is acceptable.
- **Working directory moves to another worktree** with its own `cdocs/`: a second file with the same name starts there; accepted, each worktree's record covers the work done in it.
- **Devlog at 20KB with no closed concern:** do not split; tighten prose and split landed verification evidence as its own chunk.
- **Chunk needed while a sub-loop's table is live:** only finished rows move; the live table stays with a pointer to the chunk.
- **OpenCode and other targets:** hooks are Claude-Code-only and not ported; rule and skill text deliver via `/cdocs:init`, so the per-turn bullet is rule-only there, and Pillar 2's no-`/compact` degradation adds "and the chat record if one exists".

## Test Plan

**Phase 1 hook tests, `plugins/cdocs/hooks/tests/chat-record.test.sh`.**
Headless sandbox per the README recipe (sandboxed `CLAUDE_CONFIG_DIR` with copied credentials, empty `cdocs/` in an out-of-repo `cwd`, `--model haiku`, never `--bare`, `--plugin-dir <worktree under test>/plugins/cdocs`), default permission mode with `Bash(chat-record:*)` allowed unless stated.
Each scenario is setup, then assertion on the record and the `--include-hook-events` stream:

- `command -v chat-record` -> resolves into the worktree under test.
- read a file, then note `- read: a.txt: canary fixture` -> one `@user` with `p=`, one `@haiku-4-5` entry with that body and `p=`, one sign-off `-- <sid8> at <ts>`; one `Stop`, no `decision`; no `permission_denials`.
- note body with a backtick span, `$HOME`, `$(date)`, an apostrophe, double quotes, a backslash -> body byte-exact; no `permission_denials`.
- same as the second scenario without the allow rule -> `note` in `permission_denials`; first `Stop` blocks, second silent; `@user` then sign-off, no entry.
- read a file, told not to note -> first `Stop` blocks with the real path and `--p <pid8>`; model notes; second `Stop` silent; one entry then sign-off.
- all tools forbidden -> first `Stop` blocks, second (`stop_hook_active`) writes the sign-off, no third `Stop`.
- minimal turn ("reply ok, then note it") -> one entry, one `Stop`, no block.
- two stream-json prompts, each noted -> two `@user` with distinct `p=`, matching entries, two sign-offs, timestamps non-decreasing.
- `note` twice in one turn -> two entries with one `p=`, one sign-off, no block.
- `note` without `--as` -> speaker `assistant`.
- `echo $CLAUDE_CODE_SESSION_ID` -> equals the stream's `session_id` and the filename suffix.
- `chat-record path` -> prints the path, creates nothing.
- background `Agent` dispatch -> second `UserPromptSubmit` recorded as `@harness` with its own `p=`; each turn's entry satisfies its own `Stop`.
- foreground `Agent` dispatch that reads a file -> one `@user`; nothing written for any event with `agent_id`.
- top-level only: copy the init-produced `.claude/rules/cdocs.md` and the `CLAUDE.md` import line into the sandbox project and load the plugin's agent definitions; the top-level prompt is told not to note and dispatches (a) a foreground `cdocs:proposer` on a multi-round task and (b) a fork, where the installed version offers `subagent_type: "fork"` -> a test-only `PreToolUse` canary (`"if": "Bash(chat-record:*)"`) logs no `chat-record` call with non-null `agent_id`, every entry's `p=` belongs to a top-level `@user`, and the top-level's first `Stop` still blocks (speaker names are not asserted, since a subagent may share the top-level model).
- `/echo hello-world` from `.claude/commands/echo.md` -> one `@user` whose body is `/echo hello-world`.
- stream-json `/compact` between two prompts -> nothing between the first sign-off and the second `@user`; no line mentions compaction.
- stream-json `/clear` then a prompt -> observed `session_id` behavior recorded as the expected output.
- `claude -p --resume <id>` -> new `@user` in the same file.
- `/rename my-canary` (or an injected `custom-title` line) -> next sign-off `-- my-canary at <ts>`.
- `CDOCS_CHAT_RECORD=off`, told not to note -> no file; one `Stop`, no `decision`.
- no `cdocs/` -> no file, no block.
- payload shape -> `prompt`, `prompt_id` (equal across a turn's `UserPromptSubmit` and `Stop`), `stop_hook_active`, `transcript_path`, `session_id`, `cwd` present.

**Phase 1 unit tests (pure shell).**

- Grammar: the test carries a ~10-line awk reference splitter sourcing `HEADER_RE` and `SIGNOFF_RE` from the script; round-trip on a fixture of a header-shaped first line, `@alice: hey`, LESS and CSS at-rules, headers inside fences, `\@` lines, a sign-off-shaped body line, an empty body, and CRLF input recovers every body and sign-off exactly; title `my canary "v2"` maps to `my-canary--v2-` and `""` to sid8.
- Exit codes: `CLAUDE_CODE_SESSION_ID` unset -> `note` and `path` exit non-zero, write nothing; `CDOCS_CHAT_RECORD=off` -> both exit 0, write nothing.

**Phase 1 interactive check** (once, recorded in the devlog with a record excerpt): (a) `note` runs without a permission prompt; (b) a forgotten note is blocked and recovered in one turn; (c) Escape mid-tool-call: whether `Stop` fires, its payload, whether it blocked; (d) `/rename` shows in the next sign-off; (e) a message typed mid-turn: whether `UserPromptSubmit` fires before the turn's `Stop` (see Edge Cases).

**Phase 1 rules check.** The `.claude/rules/cdocs.md` that `/cdocs:init` writes contains the per-turn rule's first line; then a sandboxed session with those rules is compacted mid-task, and its first post-compaction tool calls are `chat-record path` and reads of the Scratchpoint and record tail, with no hook emitting `additionalContext`.

**Phase 1 usefulness sample.** A fresh reviewer scores twenty random entries from the real-session record on the successor test; pass at 80%.

**Phase 2.**

- Resumption A/B (gate for Phase 3), on three real workstreams with a reset forced between handoffs: arm 1 resumes from the native summary, arm 2 from steered `/compact` plus Scratchpoint, handoff, and record tail, arm 3 from `/clear` plus the same durable state; a fresh reviewer scores correct next action, no re-litigated decision, no redundant re-read.
  Pass: arm 2 wins or ties arm 1 on all three; if arm 3 ties arm 2, `/cdocs:compact` prints `/clear` plus a resume pointer.
- Split dry-run on `2026-09-22-agent-dispatch-labeling.md` and `2026-05-12-rule-delivery-regression-test.md`: a fresh agent given only the root answers three task questions opening at most one chunk each.
- `/cdocs:triage` and `/cdocs:status` group chunks by `part_of`.

## Verification Methodology

Verify hooks by reading what they wrote, not by trusting that they ran; the canary recorder in the history report logs every event's full payload when an assertion needs the actual shape.

```bash
cd "$SANDBOX/proj" && CLAUDE_CONFIG_DIR="$SANDBOX/cfg" claude -p "<prompt>" --model haiku \
  --plugin-dir "$WORKTREE/plugins/cdocs" --allowedTools "Bash(chat-record:*)" \
  --output-format stream-json --verbose --include-hook-events > out.jsonl
```

The stream (`hook_response` decisions, `num_turns`, `permission_denials`) and the record file are independent evidence channels; the A/B and dry-run are scored by a fresh agent, never the author.

## Implementation Phases

### Phase 0: hook canary (done)

Evidence for every platform fact is in the history report's Platform Evidence table.
The script depends on: `Stop.prompt_id` equal to the turn's `UserPromptSubmit.prompt_id`; a single honored `Stop` block followed by `stop_hook_active=true`; `CLAUDE_CODE_SESSION_ID` in the Bash environment equal to the hook's `session_id`; a plugin's `bin/` on the Bash `PATH`; and no environment signal separating a subagent's Bash from the top level's.
Unverified, and owned by Phase 1: `Stop` on interrupt, `/clear` and `/resume` effects on `session_id`, mid-turn prompts, `agent_id` on fork tool calls.

### Phase 1: capture, per-turn rule, permissions, compaction guidance

Deliverables:

1. `plugins/cdocs/bin/chat-record` per the Script section; `hooks.json` entries for `UserPromptSubmit` and `Stop`.
2. `plugins/cdocs/hooks/tests/chat-record.test.sh` with the hook and unit tests.
3. `/cdocs:init`: scaffold `cdocs/_chat/README.md` (one paragraph: hook-written, do not edit, opt-outs); merge the permission rule into `.claude/settings.json` (idempotent); write `orchestration-discipline.md` Pillar 2 into `.claude/rules/cdocs.md`, the file Claude Code loads (today only `AGENTS.md` inlines it).
4. `frontmatter-spec.md`: one line on `_chat/`; README "Hooks": the two hooks, block semantics, permission rule in both forms, the `bin/` installability trade-off, opt-outs.
5. `orchestration-discipline.md` Pillar 2: the per-turn rule with its top-level-only opening line and heredoc form (Script and Top-level only sections), the three compaction steps, the commit protocol and Pillar 1 carve-out, and "never `Edit` or `Write` `cdocs/_chat/`".
6. `plugins/cdocs/skills/devlog/SKILL.md`: `## Chat Record` section (the `path` command, the heredoc `note` form, the four categories); records quoted only in fences; `## Verification` as the evidence home.
7. One line in each of `plugins/cdocs/agents/{bash-runner,implementer,judge,nit-fix,proposer,reviewer,triage}.md`: "You are a dispatched subagent: never run `chat-record`; the chat record is the top-level session's."
8. The interactive check, rules check, and usefulness sample, recorded in the devlog with the interrupt and mid-turn decisions written down.
9. Mark `2026-09-01-devlog-autoflush-hook.md` `status: evolved` with a pointer here.

Success criteria: all tests green in default permission mode; a real session of at least twenty turns in this repo commits a record in which every `@user`/`@harness` is followed by at least one top-level entry and exactly one sign-off before the next prompt, with gist-shaped bullets and a passing usefulness sample; the interactive and rules checks pass.
If the top-level-only scenario shows a subagent or fork entry, the `PreToolUse` fallback ships before Phase 1 closes.

Constraints: do not touch `inject-rules.ts`, `validate-cdocs-edit-path.sh`, or `cdocs-validate-frontmatter.sh`; do not add `_chat/` to either path regex; add no hook entries beyond `UserPromptSubmit` and `Stop` (and the named fallback, if triggered); no runtime-directory files; the only `decision: block` is the `Stop` one-shot.

### Phase 2: scratchpoint and semantic splitting

Depends on Phase 1 (the Pillar 2 steps name the Scratchpoint).

1. `orchestration-discipline.md`: a Scratchpoint subsection under Pillar 2 (format, writers, cadence, staleness rule); the handoff's Completed subsection gains `files:` gists; Pillar 3 says durable specialists keep one.
2. Devlog `template.md` gains `## Scratchpoint` and `## Chat Record`; `iterate`, `propose-revise`, `full-send`, `oversee`, and `implement` reference the rule in one line each; `agents/implementer.md` tells a warm implementer to maintain it.
3. Devlog `SKILL.md`: "Splitting a devlog" with the trigger, closure test, cut and merge rules, naming, Chunks table, chunk frontmatter and backlink; Pillar 2's handoff step adds the size check.
4. `frontmatter-spec.md`: optional `part_of`; `triage` and `status` group by it; `agents/judge.md` gains the Scratchpoint staleness condition.
5. The A/B and split dry-run, results in the devlog.

Success criteria: the A/B pass bar and the recorded arm-3 result; the dry-run's one-chunk bar; `cdocs-validate-frontmatter.sh` accepts chunks unchanged.
Constraints: the `overseer_ctx_est`/`inline_work` columns and `overseer_thinness` are not removed or renamed; no directory-per-workstream layout.

### Phase 3 (gated on the Phase-2 A/B)

1. **Cap-and-reseed durable specialists:** at a cutoff (tentatively ~0.4-0.6M tokens) the overseer has the specialist write a final Scratchpoint and handoff, then dispatches a fresh leg seeded from them; dispatch-level and agent-controllable today.
2. **`/cdocs:compact`:** user-invoked; performs the Pillar 2 boundary step and prints the line for the user to run (`/compact <steering>`, or `/clear` plus a resume pointer per the arm-3 result).
3. **Per-workstream record:** scoped in [`2026-10-05-tiered-chat-records-rfp.md`](2026-10-05-tiered-chat-records-rfp.md).

Success criteria: a reseeded specialist continues without re-reading its predecessor's files; `/cdocs:compact` plus the printed line yields a turn that acts on the Scratchpoint's `next` without re-orientation.
