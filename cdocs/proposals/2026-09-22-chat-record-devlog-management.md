---
first_authored:
  by: "@claude-fable-5-1"
  at: 2026-09-22T18:27:04-07:00
task_list: meta/chat-record-devlog-management
type: proposal
state: live
status: review_ready
last_reviewed:
  status: revision_requested
  by: "@claude-opus-5-5"
  at: 2026-10-05T10:08:45-07:00
  round: 7
tags: [meta, tooling, context_persistence, hooks, devlog, orchestration, agent-memory]
---

# Chat Record, Scratchpoint, and Semantic Devlog Splitting

> BLUF(fable-5-1/chat-record-devlog-management): Build both layers.
> A per-session **chat record** under `cdocs/_chat/` holds hook-captured verbatim user turns (stamped at submission) plus one terse agent-written gist bullet per top-level turn (what a successor should know; judgment, not a prohibition list), with a `Stop` hook that appends a `-- <session> at <end time>` sign-off and blocks once when a turn has no entry.
> Two hooks (`UserPromptSubmit`, `Stop`), one script (`plugins/cdocs/bin/chat-record`, on the Bash PATH, record path derived from `CLAUDE_CODE_SESSION_ID`, note text read from a quoted heredoc on stdin), one permission rule written by `/cdocs:init`.
> Only the top-level agent notes; that scoping is rule text, because no environment signal distinguishes a subagent's Bash.
> The record is not compaction-aware; compaction guidance lives in Pillar 2 rules.
> A rolling agent-written **`## Scratchpoint`** in the devlog is the current-state snapshot with a gist per file touched.
> Devlogs split at closed-concern boundaries into `-<concern>` chunks with the root as index.
> This makes the summary's quality irrelevant to resumption; it does not prevent native auto-compaction.

## Summary

This proposal operationalizes the resolved design in [`2026-09-22-chat-record-scratchpoint-design.md`](../reports/2026-09-22-chat-record-scratchpoint-design.md) (the chat-record report) and the devlog-management half of the context-management roadmap (RFP-2).
It does not re-derive the research; it specifies file formats, hook contracts, rule and skill text, and a phased, testable rollout.

Three artifacts, each with exactly one write path:

| Artifact | Author | Cadence | Location |
|---|---|---|---|
| Chat record | hook (user turns, turn-end sign-offs, mechanical) plus the agent (its own gist bullets, via `chat-record note`); all appends go through the one script | every user turn; every top-level agent turn (one bullet minimum, one sign-off) | `cdocs/_chat/YYYY-MM-DD-<session_id>.md`, one file per session |
| Scratchpoint | the overseer or a durable specialist (agent) | every state-changing turn, replaced in place; carries a `files:` gist list (one line per important file: what it was useful for) | `## Scratchpoint` block in the devlog that agent owns |
| Devlog chunks | the devlog's author (agent) | at a handoff boundary when a concern has closed | `cdocs/devlogs/YYYY-MM-DD-<root>-<concern>.md`, root becomes index |

The chat record generalizes nothing that exists; it fills the gap the read-source report names ("`/compact` does not preserve full user history") and, for agent turns, is a chronological record of the one thing per turn a future reader should know, not a transcript and not a changelog.

> NOTE(fable-5-1/chat-record-devlog-management): Revision history of the agent-turn content model and the hook surface.
> Round 1 captured `last_assistant_message` verbatim by hook; round 3 replaced that with one agent-written bullet per action item; round 4 (maintainer, 2026-09-23) made entries judgment-driven and sparse, dropped the `Stop` block, and added a five-quiet-turn advisory.
> Round 5 (maintainer, 2026-10-05) made every turn write one gist bullet with the `Stop` block as enforcer, dropped the `PostToolUse` hook and its `files=` metadata, and moved compaction guidance into rules, keeping `PreCompact` and `SessionEnd` markers and a `SessionStart` path announcement.
> Round 6 (maintainer, 2026-10-05) made the record not compaction-aware (no `PreCompact`, no `SessionStart`, no session start/end markers); timestamps are per turn (submission on `@user`, end on a `Stop`-written stamp carrying the session name); the record path derives from `CLAUDE_CODE_SESSION_ID`; the never-list became a guideline; the script ships in the plugin's `bin/` with an `/cdocs:init`-written permission rule.
> Round 7 (2026-10-05) is the current design: `note` reads its body from stdin, the per-turn rule is scoped to the top-level session by text (Decision 13), and the `--record` override and quoted metadata values are gone.
> The duplication concern from round 1 is resolved by shape: the chat record is a chronological record of curated notes, the Scratchpoint is a current-state snapshot, both are agent-authored, and no hook supplies content.

The scratchpoint generalizes the per-turn `overseer_thinness` columns in [`orchestration-discipline.md`](../../plugins/cdocs/rules/orchestration-discipline.md) (same per-turn, agent-authored, judge-observable pattern) with one deliberate change of storage shape: replace-in-place rather than additive append, because chronology now lives in the chat record and an append-only per-turn log would recreate the devlog-bloat failure mode.

## Objective

Make the compaction summary's quality irrelevant to resumption, and make compaction rare, by ensuring that at any moment durable state exists that is at most one turn stale (capture), and that a fresh or post-compaction window is seeded from that state rather than from an opaque summary (delivery).
See "Relationship to native auto-compaction" for what this does and does not prevent.
Keep devlogs skimmable as workstreams grow by splitting them where the work itself has seams, so a resuming agent reads the one chunk relevant to its task rather than a 40KB chronology.

## Background

Read in this order; this proposal assumes their conclusions:

1. [`2026-09-22-chat-record-scratchpoint-design.md`](../reports/2026-09-22-chat-record-scratchpoint-design.md): resolves that capture (chat record plus scratchpoint) and delivery (compaction wrapping) are complementary, scopes the chat record to the top-level session and the scratchpoint to the overseer plus Pillar-3 durable specialists, and gives the 3-phase rollout adopted here.
2. [`2026-09-20-token-spend-by-role.md`](../reports/2026-09-20-token-spend-by-role.md) workstream 1: names the two capture sub-mechanisms and the hard dependency of cap-and-reseed (workstream 4) on them.
3. [`2026-09-19-devlog-methodology-value.md`](../reports/2026-09-19-devlog-methodology-value.md) recommendations 2 and 3: point compaction at the devlog rather than letting it run as a third summarization layer; past ~10-15KB or ~5 rounds a devlog stops being skimmable and should be split.
4. [`orchestration-discipline.md`](../../plugins/cdocs/rules/orchestration-discipline.md) Pillar 2 (handoff-before-compact, proactive cadence, reseed mechanism) and the Judge-Observable Thinness Signal (the `overseer_ctx_est`/`inline_work` columns this proposal generalizes).
   Pillar 2's reseed guarantee (project-root `CLAUDE.md` and unscoped rules re-inject on auto and manual compaction; `/cdocs:init` materializes cdocs rules unscoped) is what lets this design carry all compaction guidance in rules and none in hooks.
5. [`plugins/cdocs/skills/devlog/SKILL.md`](../../plugins/cdocs/skills/devlog/SKILL.md) and its `template.md`: the convention the scratchpoint block and the split rule extend.
6. The devlog mandate: root `CLAUDE.md` ("IMPORTANT: Always create a devlog") and the "Devlog Convention" section of [`writing-conventions.md`](../../plugins/cdocs/rules/writing-conventions.md).
7. Existing hook plumbing: [`plugins/cdocs/hooks/hooks.json`](../../plugins/cdocs/hooks/hooks.json) and the sandbox-testing recipe in [`plugins/cdocs/README.md`](../../plugins/cdocs/README.md) "Sandbox testing notes"; the plugin reference's `bin/` rule (https://code.claude.com/docs/en/plugins-reference.md: files in a plugin's `bin/` are on the Bash tool's `PATH` while the plugin is enabled, and `CLAUDE_PLUGIN_ROOT` is not exported to Bash-tool commands).
8. [`2026-09-01-devlog-autoflush-hook.md`](2026-09-01-devlog-autoflush-hook.md): an RFP stub whose open questions this proposal answers (can a hook force a write: yes, once per turn, via a `Stop` block bounded by `stop_hook_active`; which devlog is active: not tracked by any hook, recovered by convention from the chat-record path the devlog names); it should be marked `evolved` into this one at Phase 1.
9. [`2026-09-22-shared-retrieval-cache-redundancy-check.md`](../reports/2026-09-22-shared-retrieval-cache-redundancy-check.md): drops the shared-cache RFP and splits its value in two halves.
   The **awareness** half ("was this file already read, and what is the gist") is cheap, proven, and folded into this proposal as the agent-written `read:` notes and the Scratchpoint's `files:` gist list.
   The **token-cost** half (putting agent A's file bytes into agent B's context) has no working mechanism on this platform and is explicitly not solved here; the gist lets an agent decide whether to re-read, it does not make the re-read free.
10. The round-5 review, [`2026-10-05-review-of-chat-record-devlog-management-r5.md`](../reviews/2026-10-05-review-of-chat-record-devlog-management-r5.md): verified on 2.1.289 that `CLAUDE_CODE_SESSION_ID` is exported to the Bash tool and equals the hook's `session_id`, that a plugin's `bin/` is on the Bash PATH, and that an unallowlisted Bash call is denied headless in default permission mode (`DENIED This command requires approval`).
11. The round-6 review, [`2026-10-05-review-of-chat-record-devlog-management-r6.md`](../reviews/2026-10-05-review-of-chat-record-devlog-management-r6.md): a dispatched subagent's Bash carries the parent's `CLAUDE_CODE_SESSION_ID`, and a double-quoted note argument undergoes shell expansion; both are addressed by Decision 13 and checked by Phase-0 run R7 (below).

### Non-Goals

- **Graphify-scoped retrieval.** A separate effort, already in progress elsewhere; nothing here depends on or designs it.
- **Shared retrieval cache and cross-agent read deduplication (the token-cost half).** Dropped per the shared-cache report; this proposal neither designs nor assumes any content-sharing mechanism and makes no claim that the gist notes reduce the measured 97.4% cross-agent re-read figure.
- **Memory-tool integration.** Orthogonal per the chat-record report; a possible future storage backend, not adopted.
- **Post-hoc distillation of devlogs by a cheap model.** Rejected by the devlog-value report.
- **Mechanical capture of files touched.** No `PostToolUse` hook; the only record of which files mattered is the agent's own `read:` notes and Scratchpoint `files:` gists, and the raw transcript is the exhaustive fallback (Decision 11).
- **Compaction awareness in the record.** No compaction hook is registered and no session start, end, or compaction line is written; see Decision 7.
- **Chat records for dispatched subagents, in Phases 1 and 2.** In hook mode the script exits on every event whose payload carries `agent_id`, the field the hooks reference documents as "present only when the hook fires inside a subagent call".
  The agent-invoked `note` path has no such guard (Decision 13), so the per-turn rule says "top-level session only" and every cdocs agent definition repeats it.
  A per-workstream record that includes dispatched legs is a Phase-3 pointer, not built here.
- **Hook-enforced scratchpoint writing.** The scratchpoint is judgment-bearing; a hook can nudge, never author.
- **Redaction or secret scanning.** Chat records commit by default with no redaction pass; the exposure is accepted and documented (Design Decision 9).
  General redaction and secret scanning for committed cdocs artifacts is scoped separately in [`2026-09-23-chat-record-redaction-scanning-rfp.md`](2026-09-23-chat-record-redaction-scanning-rfp.md) and nothing here attempts it.

## Proposed Solution

### Layer map

```mermaid
sequenceDiagram
    participant U as User
    participant H as chat-record (hook mode)
    participant A as Agent (overseer)
    participant CR as cdocs/_chat/<session>.md
    participant DL as devlog (## Scratchpoint, handoff)
    U->>H: UserPromptSubmit
    H->>CR: create file if absent; append @user: <submit ts> p=<pid8>
    A->>DL: replace ## Scratchpoint incl. files: gists (every state-changing turn)
    A->>H: chat-record note --as model, bullets as quoted heredoc on stdin (every top-level turn; path from CLAUDE_CODE_SESSION_ID)
    H->>CR: append @<model>: <ts> p=<pid8> entry
    A-->>H: Stop
    alt entry with this p= exists, or stop_hook_active
        H->>CR: append sign-off line: -- session at end ts
    else no entry, first Stop
        H-->>A: decision=block, reason names the record path and the exact note command
    end
    Note over A: rules (Pillar 2): at a task-unit boundary write handoff + Scratchpoint, commit, ask user for /compact <steering> or /clear
    Note over A: rules (re-injected after compaction): chat-record path, then re-read Scratchpoint + handoff + record tail, not the summary
```

### Chat record

#### Location and naming

`cdocs/_chat/YYYY-MM-DD-<session_id>.md`, one file per Claude Code session, where `YYYY-MM-DD` is the local date of the session's first recorded prompt and `<session_id>` is the full session id.
Example: `cdocs/_chat/2026-10-05-e3afd4a9-4352-482d-ad1a-444fa834254a.md`.

The script locates the file by glob, `cdocs/_chat/*-<session_id>.md`, never by recomputing the date (a `--resume` the next day must land in the same file), and creates it lazily on the first event that needs it (the first `UserPromptSubmit`, or the first `note` if that comes first).
The full id in the name means no two sessions can ever share a file and no collision check exists.
`cdocs/` is resolved by walking up from the working directory (the payload's `cwd` in hook mode, `$PWD` in `note` and `path` mode) to the nearest directory that contains one.

Who knows the session id: the hook payload on every event, and the agent's Bash environment via `CLAUDE_CODE_SESSION_ID` (verified equal to the hook's `session_id` on 2.1.289, round-5 review run A; undocumented, so Phase 1 asserts the equality in its tests so a rename fails loudly rather than silently).
`chat-record note` and `chat-record path` therefore take no path argument; when the variable is absent they print one stderr line and exit non-zero.
Inside a dispatched subagent the variable holds the parent's id, so a subagent's `note` would land in the top-level record (Decision 13).

Why per session rather than per `task_list`: the script knows `session_id` on every event and knows nothing about workstreams; `--resume` continues a session under the same id (per `claude --help`), so a resumed session keeps appending to the same file; and a session is the unit that compaction acts on.
The link from workstream to chat record is made the other way: on its first turn the agent runs `chat-record path` and writes the result into the devlog's `## Chat Record` section (see Scratchpoint section), and the devlog is found again from the path by `grep -l '<record path>' cdocs/devlogs/*.md`, with no hook state involved.

Why an underscore directory at the top level: `cdocs/_media/` already marks non-document assets; chat records are mechanical artifacts, not authored documents, so they carry no frontmatter and are excluded from the frontmatter-validation regex (`cdocs/(devlogs|proposals|reviews|reports)/`) and from the cdocs-subagent edit-path allowlist, both of which match only the four typed directories.
No frontmatter-spec change is needed; the spec gains one line noting `_chat/` alongside `_media/`.

Chat records are committed, like devlogs, because durable state that must survive a fresh session or a sibling worktree is worthless untracked (the bare-repo layout in `CLAUDE.md` makes this explicit).

**Commit protocol.** The record grows on every turn, so the working tree is dirty at every moment a commit happens.
Therefore: the overseer stages the record by explicit path at each handoff (`git add cdocs/_chat/<file> cdocs/devlogs/<devlog>`), in the same devlog-class bookkeeping commit as the devlog; dispatched agents never stage `cdocs/_chat/` (no `git add -A`, no `git commit -a`, no "commit everything" step touches it), and their briefs say so.
A commit made mid-turn is stale by the next `Stop`; that is expected, the record is append-only and the next handoff commit catches up.
This is the carve-out to Pillar 1's "the overseer does not commit code itself": devlog and chat-record commits are bookkeeping the overseer already performs, not code commits.

> WARN(fable-5-1/chat-record-devlog-management): A committed chat record has two leak channels: text a human pastes into a prompt, and `@<model>` bodies, where an assistant that echoes a `.env` value, a token from a tool result, or a credential path writes it to git with no human paste involved.
> The gist guideline narrows the second channel (a few terse lines per turn, never tool output) but does not close it.
> Maintainer decision (2026-09-23): commit by default, no redaction pass in the hook; the exposure is accepted and documented here rather than mitigated.
> General redaction and secret scanning is deferred to [`2026-09-23-chat-record-redaction-scanning-rfp.md`](2026-09-23-chat-record-redaction-scanning-rfp.md).
> Opt-outs: the script honors `CDOCS_CHAT_RECORD=off` (no writes, no `Stop` block), and a project may add `cdocs/_chat/` to `.gitignore` to keep records local at the cost of cross-worktree and cross-session durability.

#### Block grammar

A chat record is a sequence of blocks.
Each block is a header line at column 0 followed by a body that runs to the next header line or end of file.
Only real speakers get `@` headers; the turn's end is a sign-off line, not a block.

```
HEADER_RE := ^@[A-Za-z0-9][A-Za-z0-9._-]*:          ; the ONE pattern both writer and reader use
record    := block*
block     := header "\n" body
header    := HEADER_RE (" " meta)? "\n"              ; column 0, no leading whitespace
meta      := timestamp (" p=" pid8)?                 ; timestamp is ISO 8601 with offset
body      := line* signoff?                          ; verbatim, may contain blank lines and fences
SIGNOFF_RE:= ^-- [A-Za-z0-9._-]+ at <timestamp>$    ; the Stop hook's turn-end line
signoff   := "-- " session " at " timestamp "\n"     ; session: custom title as a token, or sid8
```

Rules that keep the grammar unambiguous:

- **`HEADER_RE` and `SIGNOFF_RE` are the only split and escape tests.** A line is a header if and only if it matches `HEADER_RE` at column 0 with no preceding backslash; whatever follows the colon on a real header is parsed as `meta` (an empty or malformed `meta` is still a header, with the tail kept as opaque text).
  A line is a sign-off if and only if it matches `SIGNOFF_RE` with no preceding backslash.
  The writer escapes any body line matching `^\\*HEADER_RE` or `^\\*SIGNOFF_RE` by prefixing one backslash, so `@alice: can you look at this`, a LESS `@brand-color: #333;`, a CSS `@page:first {`, a pasted `@user: ...` first line, and a pasted `-- x at 2026-...` line are all escaped; the reader strips exactly one leading backslash from any line matching `^\\+HEADER_RE` or `^\\+SIGNOFF_RE`.
  Both sides use the same patterns, so writer and reader can never disagree about where a block or a turn ends.
  The transform is applied to every body line regardless of fence state, so parsing is stateless and round-trips verbatim.
- **The session name is a plain token.** The writer maps every character of the title outside `[A-Za-z0-9._-]` to `-` (`my canary "v2"` becomes `my-canary--v2-`), so the sign-off never needs quoting or escapes.
- **CRLF is normalized.** The writer converts `\r\n` to `\n` in bodies before the escape pass, so a pasted Windows transcript cannot carry `\r` into the header test.
- **Metadata lives on header and sign-off lines only.** Any other body line is content.
- **Block separation is by header, not by blank line.** The writer emits one blank line after each body for readability; the reader strips trailing blank lines from a body.
  Multi-paragraph and fenced content inside a body needs no delimiter because only the next header ends it.
- **No collision with cdocs markdown.** `#` headings, `>` callouts (`BLUF`, `NOTE`, `WARN`), `|` tables, `-` lists, and fences never begin with `@`, and column-0 `@` is not markdown syntax (it renders as text).
  Chat records are never embedded in other cdocs documents except inside a fenced code block; the devlog skill says so.

Speakers:

| Speaker | Written on | Timestamp means | Body |
|---|---|---|---|
| `@user` | `UserPromptSubmit` with a human prompt | prompt submission | the prompt, verbatim |
| `@harness` | `UserPromptSubmit` whose prompt is a harness envelope (see Edge Cases) | prompt submission | the prompt, verbatim |
| `@<model-short>` (e.g. `@opus-4-8`, `@fable-5-1`, `@haiku-4-5`) | the top-level agent, via `chat-record note`, on every turn | when the note was written | one to three terse gist bullets (below); never a reply, never a log of actions |

**Sign-off.** Whenever `Stop` does not block, it appends `-- <session> at <end timestamp>` after the turn's last block (normally the agent's note), so the turn ends with a sign-off rather than a speaker the reader must discount.
It carries no `p=`: it belongs to the turn by adjacency (the turn's `Stop` runs before the next prompt is processed; whether a message typed mid-turn breaks that is interactive check (e)), and the `Stop` check, which does need correlation, keys on the agent header's `p=`.

`<model-short>` is the model id with the `claude-` prefix and any trailing `-YYYYMMDD` stripped: `claude-haiku-4-5-20251001` becomes `haiku-4-5`, `claude-opus-4-8` becomes `opus-4-8`.
The agent passes its own speaker (`note --as fable-5-1`; it knows its model from its system prompt); when omitted, the script writes `assistant`.
No payload the hooks see carries a model id, and the transcript is not scraped for one.

Header metadata, optional after the timestamp: `p=<first 8 hex of prompt_id>` on every speaker (correlates the `@user` block with the agent's entry, and is what the `Stop` check keys on).
The sign-off's session is the custom title as a token, or the first 8 hex of `session_id` when none is set.
The title comes from the transcript (`transcript_path` is a common hook input field): the last line of type `custom-title`, whose `customTitle` field is the name set by `/rename` (observed on 2.1.289; the line is rewritten over the session, so the last occurrence wins), read from the end (`tac "$transcript" | grep -m1 '"type":"custom-title"'`) because transcripts reach megabytes and `Stop` runs every turn; `SessionStart` also delivers it as `session_title`, but that event is not registered.
A turn's duration is the difference between its `@user` timestamp and its sign-off; a session's name at any point is the nearest sign-off.

**Agent gist entries.** Every top-level turn ends with an entry: one bullet minimum, three at most, one line each, under about 120 characters, with a category prefix so entries are greppable (a bullet with no prefix is read as `gist:`):

- `gist:` the default: what this turn concluded, decided, or changed in the state of play, phrased as what a successor should know.
  `gist: Stop block is the enforcer; five-turn advisory dropped (maintainer 2026-10-05)`; `gist: reviewer r5 returned revise on two blockers (script path, permissions)`; `gist: answered why Stop fires top-level only; no state change`.
- `query:` a retrieval or search query that turned out useful and what it surfaced, for example `query: graphify query "hook events" surfaced the PostCompact matcher table; reuse before grepping the binary`.
  This is the oldest idea in this roadmap: the "this graphify query was useful for context" note that the token-spend report's workstream 1 asks a dense per-turn record to carry ([`2026-09-20-token-spend-by-role.md`](../reports/2026-09-20-token-spend-by-role.md), "Dense per-turn agent summary ... the most important points"), and that the context roadmap carried into RFP-2.
- `read:` a high-salience file a successor should read, and why, for example `read: plugins/cdocs/hooks/validate-cdocs-edit-path.sh: the jq stdin-parse and silent-exit pattern the shell hooks share`.
  This is also where the agent names files that mattered; nothing mechanical records them.
- `follow-up:` an opened thread to revisit later, for example `follow-up: interactive TUI /compact path still unverified; needs a real-session check before Phase 1 ships`.

The test for a bullet is "would a successor reading only the `@user` blocks and these bullets know where things stand".
**Guideline, not prohibition.** Do not note every commit, do not fill the record with test-run details, routine edits, tool calls, or tool output, and do not paste the reply; the record is a gist, and the devlog and git already hold the actions.
But the agent judges: a commit that closes a long thread, a test result that changes the plan, or a tool output that is the whole finding may be the gist of its turn, and then it is noted (`gist: landed the hooks.json wiring; interactive /compact check is the last Phase-1 item`).
The shape to avoid is the enumerated log (`- edited X - ran tests - committed abc123`); the shape to produce is the one-line state of play.
The `read:` note and the Scratchpoint's `files:` gist list overlap on purpose and differ in lifetime: the Scratchpoint line is current-state awareness that rolls into the next handoff, the chat-record note is the durable, chronological trace of when and why a file became salient.
Slash-command turns are captured as the raw invocation string (`/cdocs:propose-revise --first-round ...`), not the expanded skill body, which is short and exact; built-in commands such as `/compact` and `/clear` fire no `UserPromptSubmit` (run 2) and leave no trace in the record, by design.

Example (user lines are from Phase-0 run 2; the agent entries and stamps are illustrative, written as this proposal's own author would have noted that stretch of work):

```
@user: 2026-09-22T18:20:54-07:00 p=c76c22bb
Reply with exactly the word: alpha

@fable-5-1: 2026-09-22T18:20:56-07:00 p=c76c22bb
- query: `strings claude.exe | grep -E "PreCompact|PostCompact"` lists every hook event on 2.1.280; PostCompact exists
- read: plugins/cdocs/README.md "Sandbox testing notes": the credential-copy recipe every headless canary needs
- follow-up: interactive TUI /compact path unverified; check in a real session before Phase 1 ships

-- hook-canary at 2026-09-22T18:20:57-07:00

@user: 2026-09-22T18:21:05-07:00 p=ab2a3ea6
Reply with exactly the word: beta. Then on a second line say whether you remember an earlier word you replied with, and what it was.

@fable-5-1: 2026-09-22T18:21:07-07:00 p=ab2a3ea6
- gist: alpha survived the compaction between these turns; steering text reached the summarizer

-- hook-canary at 2026-09-22T18:21:08-07:00
```

The second agent entry is the minimal case: a turn that did one thing and has one line to say about it.
There is no entry-less turn; a turn with nothing more to say than its outcome still writes that outcome.
The compaction that happened between the two turns is visible only as the fact that the rules were followed; the record does not mark it (Decision 7).

#### Script contract: `plugins/cdocs/bin/chat-record`

One bash script, shipped in the plugin's `bin/` so it is on the Bash tool's PATH as the bare command `chat-record`, with four modes:

- `chat-record UserPromptSubmit` and `chat-record Stop`: hook mode, registered in `hooks.json` as `${CLAUDE_PLUGIN_ROOT}/bin/chat-record <Event>` (the placeholder is expanded in hook commands, not in Bash-tool commands), payload on stdin.
- `chat-record note [--as <speaker>] [--p <pid8>]`, bullets on stdin: invoked by the top-level agent from `Bash`; appends a `@<speaker>` entry with the current timestamp, `p=` from `--p` or else from the last `@user`/`@harness` header in the record (omitted when there is none), and the bullets as body after the escape pass; creates the record if absent.
- `chat-record path`: prints the record path and nothing else, and never creates the file; used by the agent to write the devlog's `## Chat Record` pointer and to find the tail after compaction.

The body is read from stdin, never from an argument, and the one documented form is the quoted heredoc, which performs no expansion:

```bash
chat-record note --as fable-5-1 <<'EOF'
- query: `rg -n "prompt_id"` found the Stop/UserPromptSubmit correlation; didn't need the binary
EOF
```

A double-quoted argument would execute backtick spans and `$(...)` and expand `$VAR`, and a single-quoted one breaks on an apostrophe; both are shapes agents write routinely.
Phase-0 run R7 showed the heredoc body arriving byte-exact (backticks, `$HOME`, `$(date)`, an apostrophe, double quotes, backslashes) and the call matching `Bash(chat-record:*)` in default permission mode with no denial.

Bash plus `jq`, not `tsx`: `UserPromptSubmit` and `Stop` run on the critical path of every turn and `npx tsx` startup is measurable, while the existing shell hooks show the pattern.

| Event | Matcher | Writes | Emits |
|---|---|---|---|
| `UserPromptSubmit` | (all) | creates the file if absent; `@user` or `@harness` block, timestamp = now, `p=` from `prompt_id` | nothing (never `decision: block`) |
| `Stop` | (all) | if `stop_hook_active` is true, or the record has a block with `p=<pid8>` whose speaker is not `user` or `harness`: the sign-off `-- <title token or sid8> at <now>`. Otherwise nothing | in the "otherwise" case only: `{"decision":"block","reason":"<block text>"}` |

`Stop` block text, with the real values substituted (under 300 bytes):

```
No chat-record entry for this turn (record: cdocs/_chat/2026-10-05-<session_id>.md). Run, then finish:
chat-record note --p ab2a3ea6 --as <your model> <<'EOF'
- gist: <what a successor should know from this turn>
EOF
```

Invariants:

- **`agent_id` guard, first thing on every hook event.** If the payload carries `agent_id`, exit 0 before any read or write.
  Neither registered event carries `agent_id` in practice (plain `Stop` fires only for the top-level agent with `agent_id: null`, run 5, and a subagent's turn end is `SubagentStop`, which is not registered), so the guard is defensive; it covers hook mode only, since `note` sees no payload.
- **`stop_hook_active` guard, before any `Stop` decision.** A `Stop` with `stop_hook_active=true` is the agent's second stop after a block; the hook never blocks it, so a turn costs at most one extra short turn (run 8: three turns total) and can never loop.
  An agent that ignores the block and stops again without an entry simply ends the turn; the sign-off is still written, the gap is visible in the record (a `@user` body followed directly by its sign-off), and nothing retries.
- Hook mode always exits 0; a chat-record failure never blocks or slows the user.
  Errors go to stderr only.
  `note` and `path` exit non-zero with a one-line stderr reason on any failure (no `CLAUDE_CODE_SESSION_ID`, no `cdocs/`, `jq` missing, write error), so the agent learns at once that nothing was written rather than from a later `Stop` block; `CDOCS_CHAT_RECORD=off` is the one silent exit 0.
  The only `decision: block` in the design is the `Stop` one-shot above, and it is suppressed whenever the script cannot do its job: `CDOCS_CHAT_RECORD=off`, `jq` missing, no `cdocs/` under `cwd`, no record file for this session (no prompt has been seen), or no `prompt_id` in the payload.
- No `cdocs/` directory, or `CDOCS_CHAT_RECORD=off`: no write in any mode.
- Appends use `>>` (`O_APPEND`) with the whole block written in one `printf`, so a `note` racing a `Stop` interleaves at block granularity, not mid-line.
- `chat-record` is the chat record's only write path.
  Two authors (the hook for user blocks and sign-offs; the agent for its own gist entries) share one append routine, so blocks never interleave mid-line and no `Edit`-style rewrite ever races an append.
  Agents read chat records (`tail`, `Read` with an offset) and never `Edit` or `Write` them; a cdocs subagent cannot even path-wise (`_chat/` is outside the edit-path allowlist), and the rule text says so for the main session.
- `last_assistant_message` is never written to the record; `Stop`'s check is keyed on `prompt_id` and the presence of a `p=<pid8>` entry, nothing else.
- No runtime-directory state.
  The record file is the only state: `note` derives `p=` from the record's last prompt header, and the block reason supplies `--p` explicitly for the case where that header is missing or stale.
- **Only the top-level agent calls `note`, by rule.** A subagent's Bash has the same `CLAUDE_CODE_SESSION_ID` and, per run R7, an identical `CLAUDE*`/`AI_AGENT` environment, so `note` cannot tell who called it; a subagent's note would land in the top-level record and, taking `p=` from the overseer's in-flight `@user` header, would satisfy the overseer's `Stop` check.
  The guard is text in three places: the per-turn rule opens with "top-level session only; if you were dispatched by the `Agent` tool, never run `chat-record`", every `plugins/cdocs/agents/*.md` carries the same line, and dispatch briefs inherit it from the agent definition.
  A Phase-1 scenario tests it (Test Plan).

**Permissions.** `note` is a Bash tool call on every turn.
In default permission mode an unallowlisted command prompts the user interactively and is denied outright headless (round-5 review run C: `DENIED This command requires approval`), which would turn the per-turn rule into one wasted block-and-deny round trip per turn and an empty record.
So `/cdocs:init` merges `"Bash(chat-record:*)"` into `permissions.allow` in the project's `.claude/settings.json` (creating the file or the key as needed, never removing other entries), the README documents the same rule for installs that skip init and the per-invocation form for ad-hoc runs (`claude -p --allowedTools "Bash(chat-record:*)" ...`), and the Phase-1 tests exercise the block-and-recover path in default mode with the rule present.
The rule matches the heredoc form unchanged (run R7: `permission_denials` empty in default mode).
Run 8, the evidence that the block is honored, ran under `bypassPermissions`; the default-mode scenario is what shows the rule makes the path work where people actually run.

**The per-turn rule, its cost, and why a hook backs it.** The rule (Pillar 2 text, Phase-1 deliverable 5) is: in the top-level session only, before ending a turn, the agent appends at least one gist bullet via `chat-record note`.
The compliant path costs one Bash tool call per turn, which is one extra model inference when issued alone; the rule therefore says to issue `note` in the same parallel tool batch as the turn's last action whenever the outcome is already known, so the common case costs no extra round trip, and a pure-chat turn pays the one call.
The `Stop` block is the backstop for the turn the agent forgets, not the primary mechanism, and it is bounded on both sides: at most once per turn (`stop_hook_active`), and only when the record provably has no entry for this `prompt_id`, which the hook checks mechanically (`Stop.prompt_id` equals the turn's `UserPromptSubmit.prompt_id`, run 6).
It never inspects content, so it cannot coerce a particular bullet; the `gist:` category exists so that a compliant minimal bullet is always available and honest.
Even with the block ignored on every turn the record still carries verbatim user history and per-turn sign-offs, which is strictly more than today; agent entries are additive over that floor.

### Compaction guidance (rules only)

The chat record is not compaction-aware: nothing in it says when a compaction happened, and no compaction hook is registered.
A record of compaction gains its reader nothing, because the reader is either the same instance (which already knows) or a different one (for which the boundary is irrelevant); what both need is the state, and that is the Scratchpoint, the handoff, and the record tail.
Compaction is a user action (an agent cannot invoke `/compact`; [#71803](https://github.com/anthropics/claude-code/issues/71803) is open), so the guidance lives where it survives compaction: `orchestration-discipline.md` Pillar 2, delivered unscoped by `/cdocs:init` and re-injected on every compaction per the reseed guarantee.
Pillar 2 gains three concrete steps.

**On the first turn of a session** the agent runs `chat-record path` and writes the result into its devlog's `## Chat Record` section.

**At a task-unit boundary** (after every 3 to 5 loop iterations, or when a judge returns, per the existing cadence) the overseer writes the handoff, refreshes the Scratchpoint, commits devlog and chat record by explicit path, and ends its turn by asking the user to run either:

```
/compact Preserve verbatim from cdocs/devlogs/<devlog>.md: the ## Scratchpoint block and the latest Completed / Decisions Made / Open Todos handoff. Keep the paths cdocs/devlogs/<devlog>.md and cdocs/_chat/<record>.md and the last three user turns verbatim. Drop tool outputs and file contents; they are re-readable.
```

or `/clear`, when the handoff is complete enough that no summary is needed (the Phase-2 A/B's third arm decides which the Phase-3 `/cdocs:compact` skill prints by default).

**After any compaction or clear** (the window opens on a summary or on nothing), before doing anything else: run `chat-record path`; read `## Scratchpoint` and the latest handoff in the devlog that names that path (`grep -l '<record path>' cdocs/devlogs/*.md`), then the last five blocks of the record; do not re-derive state from the summary.
If the grep misses (no devlog yet), the agent creates or resumes one per the devlog convention and writes the pointer.

Why no `SessionStart` hook: its only remaining job would have been to announce the record path, and `chat-record path` answers that from the environment on demand.

### Relationship to native auto-compaction

This design does not obviate native auto-compaction for the top-level session, and it should not be read as trying to:

- Compaction cannot be prevented by the agent.
  `/compact` and `/clear` are user actions; agent-invokable compaction does not exist.
  In AFK `oversee` runs and headless `-p` sessions nobody types either, so auto-compaction is the only trimming mechanism there, and Phase-0 run 3 shows it firing four times in three minutes under a 100K window.
- Context growth is not fully agent-controlled: tool results, harness notifications, and reseeded rules arrive unbidden.
- Durable specialists (Pillar 3) are the exception.
  Their "compaction" is the ~1M sawtooth reset, and Phase 3's cap-and-reseed is a dispatch-level primitive the overseer does control, so for subagents the system genuinely can keep compaction from ever running.

What the design achieves instead: with a Scratchpoint at most one turn stale, a handoff, a chat-record tail with one bullet per turn, and a re-injected rule that says "read those, not the summary", compaction becomes a mechanical trimming event whose summary quality no longer determines resumption quality.
Auto-compaction stays as the safety net for unmanaged stretches, and its role shrinks to "trim when nobody checkpointed", which the Scratchpoint staleness signal makes visible to the judge.
Whether a hard `/clear` plus reseed from durable state beats steered `/compact` on the interactive path (no summarizer call, no 30-second pause) is an empirical question the Phase-2 A/B's third arm answers; if it ties, `/cdocs:compact` prints `/clear` plus a resume pointer instead of a steering string.

### Scratchpoint

A single `## Scratchpoint` H2 section in the devlog the agent owns, replaced in place on every state-changing turn, bounded by rule to at most 15 lines and at most 8 `files:` entries (older entries roll into the handoff at the next boundary):

```markdown
## Scratchpoint

- as_of: 2026-09-22T18:40:11-07:00 ctx: ~140K (10% inline)
- now: wiring the Stop check; hook blocks once but the reason text is not yet final
- since_handoff: Stop.prompt_id matches UserPromptSubmit.prompt_id (run 6); custom-title lines are in the transcript
- open: interactive /compact check (#13572); /clear and /resume effect on session_id
- next: run interactive canary, then commit hooks.json entry
- files:
  - plugins/cdocs/hooks/hooks.json (rw): the two shell-hook entries are the template for the new ones
  - plugins/cdocs/hooks/validate-cdocs-edit-path.sh (r): the jq stdin-parse and silent-exit guards to copy
  - plugins/cdocs/README.md#sandbox-testing-notes (r): the credential-copy recipe; nothing else in the README matters here
```

Fields: `as_of` (timestamp plus the context estimate that iterate's `overseer_ctx_est` column already asks for), `now` (current subtask), `since_handoff` (facts and decisions not yet in a handoff), `open` (threads), `next` (the single next action), and `files` (the gist log).

**`files:` (the gist log).** One line per important file read in full or edited since the last handoff, in the fixed shape `- <path> (<r|w|rw>): <one-line gist of what it was useful for or why it mattered here>`.
Its job is awareness, per the shared-cache report: a sibling or successor agent reads the gist and decides "does this cover me, or do I need the bytes", instead of re-reading blind.
It is not a token saver and must not be described as one; when a task needs real content (review, exact edits, verification), the agent re-reads regardless.
"Important" is the author's call: files skimmed for a `Glob` or `Grep` hit do not belong; nothing mechanical records the rest, and the raw transcript is the exhaustive fallback (Decision 11).
At each handoff the current `files:` list rolls into the handoff's Completed subsection ("files touched" gains the gist one-liners), and the Scratchpoint's list restarts empty.
Writers: the overseer of any loop (`iterate`, `propose-revise`, `full-send`, `oversee`) and any Pillar-3 durable specialist, in the devlog it owns; a specialist that owns no devlog writes to the file its dispatch brief names.
Not writers: one-shot dispatched legs (their returned summary is their checkpoint, per the chat-record report).

Relationship to the chat record's agent entries, stated plainly: different shapes, not the same job at two granularities.
The chat record's `@<model>` entries are an append-only chronological record of curated notes ("what a successor should know, in the order it was learned": outcomes, useful queries, salient files, open follow-ups); the Scratchpoint is a bounded, replace-in-place snapshot ("where am I right now": current subtask, facts since the handoff, open threads, next action).
Both are agent-authored, both are judgment-bearing, and both are terse; they do not duplicate because a note is never restated as state and a state line is never restated as history, and because the Scratchpoint is overwritten while the record accumulates, so the same salient file may appear once in each with different lifetimes (the Scratchpoint line dies at the next handoff, the note persists).
A post-compaction reader takes the Scratchpoint first and the last few entries second.

Relationship to the existing thinness columns, stated plainly: this generalizes that pattern.
The columns are the per-turn, agent-written, judge-observable precedent; the Scratchpoint carries the same `ctx` estimate plus actual working state, outside the iterate loop as well as inside it.
The columns are not removed or replaced: inside `iterate` they remain the judge's bloat signal per row, and the Scratchpoint's `as_of` staleness becomes an additional input to the judge's existing `overseer_thinness` field: a Scratchpoint whose `as_of` is older than two Iteration Log rows, or absent, is written as `overseer_thinness: signal_missing`, the same value the judge already writes when the thinness columns are absent, so the judge agent's update in Phase 2 is one added condition, not a new field.
The one deviation from the precedent is storage shape: replace-in-place, not additive rows, because per-turn history is now the chat record's job and appending working state every turn would push the devlog toward the append-only chronology the devlog-value report identifies as the failure mode.

The index devlog also carries a two-line `## Chat Record` section: the path `chat-record path` printed (the string the post-compaction grep recovers the devlog by), and the timestamp of the last handoff (so a resuming reader knows which tail to read).

**Evidence lives in the devlog's `## Verification` section.** Raw reproducible evidence (exact `settings.json`, command lines, log lines, fixture generators) goes where the devlog skill already puts it, the `## Verification` section that predates this proposal; when that section outgrows the root it is a landed verification campaign, which is a closed concern, and it splits as a standard `-<concern>` chunk (`-verification`, `-canary`) with `part_of`, the backlink NOTE, and a `## Chunks` row like any other.
No evidence-specific directory or index exists.
This proposal's own canary evidence is the first instance: [`2026-09-22-chat-record-devlog-management-propose-revise-canary.md`](../devlogs/2026-09-22-chat-record-devlog-management-propose-revise-canary.md), a chunk of the loop devlog.

### Devlog splitting at closed-concern boundaries

**When to look for a split.** At every handoff-before-compact boundary the author checks devlog size.
Past ~12KB (the midpoint of the devlog-value report's 10-15KB band) or past ~5 loop rounds, the author must look for a boundary.
The size is the prompt to look, never the place to cut.

**What a closed concern is.** A concern is a completed phase, a finished sub-loop of rounds, a resolved investigation or debugging arc, or a landed verification campaign.
It is *closed* when all three hold: (i) it has a heading of its own (H2 or H3) in the devlog; (ii) every Open Todo in the most recent handoff that names it is done, or has been moved into the root's current handoff; and (iii) no live table in the root still receives rows for it.
Two agents applying this test to the same devlog get the same answer, which is what makes the Phase-2 dry-run scoreable.

**Where to cut.** At a split, move **every** closed concern, one chunk per closed concern; a closed concern under ~3KB merges into the adjacent closed chunk, because a chunk should be worth opening alone.
Everything belonging to a concern moves with it: its Implementation Notes, Debugging Process, Changes Made rows, Verification evidence, and Iteration Log rows for a finished sub-loop.
Rows in shared tables (Changes Made, Verification) move with the concern that produced them; a row that belongs to two concerns stays in the root.
Open concerns and live tables (Iteration Log, Judge Log, Dispatch/Return Events, Steering Log for the active loop) stay in the root.
If no concern has closed, do not split: a large live section beats an arbitrary cut; keep pasted evidence in the `## Verification` section and split that section as its own chunk once the campaign it records has landed.

**Naming.** Chunk files are flat siblings: `cdocs/devlogs/YYYY-MM-DD-<root-slug>-<concern-slug>.md`, sharing the root's date prefix so chunks sort adjacent to their root (the existing `2026-09-01-overseer-alignment-phase{1..4}.md` precedent), with `first_authored.at` carrying the chunk's real creation time.
Concern slugs name the concern, not a number: `-phase2-hooks`, `-canary`, `-iterate-r1-r5`, `-debug-transcript-lag`.
No directory-per-workstream: the `{date}-{slug}.md` convention, the hook path regexes, and `/cdocs:status` all assume flat typed directories, and the index table below does the grouping job a directory would.

**The root becomes the index.** It keeps its frontmatter, Objective, `## Chat Record`, `## Scratchpoint`, the current handoff, live tables, and gains a `## Chunks` table:

```markdown
## Chunks

| chunk | concern | status | read this when |
|---|---|---|---|
| [-canary](2026-09-22-chat-record-devlog-management-canary.md) | Phase-0 hook canary, payload shapes | done | you need a hook's exact payload fields or the sandbox recipe |
| [-phase1-hooks](2026-09-22-chat-record-devlog-management-phase1-hooks.md) | chat-record and hooks.json | done | you are touching the script or its tests |
```

The `read this when` column is the navigation contract: a resuming agent reads the root (index, Scratchpoint, handoff) and opens only the chunk whose trigger matches its task.

**Each chunk stands alone.** It has full frontmatter (same `task_list`, `status: done` because a closed concern is done by definition, so `/cdocs:triage` never flags a chunk as stale `wip`, plus `part_of: cdocs/devlogs/<root>.md`), an opening BLUF that does not depend on the root, and a first-line `> NOTE(author/workstream): Chunk of [<root>](<root>.md); see its Chunks table for siblings.` backlink.
`part_of` is a new optional frontmatter field with `review_of` semantics (a repo-root path); `/cdocs:status` and `/cdocs:triage` group by it.

## Important Design Decisions

1. **Both layers, firmly.** Compaction guidance is delivery; chat record and scratchpoint are capture.
   Without capture, a post-compaction window seeds from a devlog that is up to a task unit stale; without delivery, captured state is never read.
   Neither is redundant with the other, with `CLAUDE.md` reseed (static discipline, not dynamic state), or with the Dispatch/Return Events table and arc-state file (orchestration bookkeeping for a second session, not one agent's working notes).
2. **Turn-delimited markdown, not a schema.** `@speaker:` headers with inline metadata are readable by a human with `tail`, appendable by a shell one-liner, and parseable with one regex.
   JSONL would be easier for a program and worse for the two actual readers (a post-compaction agent and a human).
3. **One file per session at `cdocs/_chat/`, full session id in the name.** The only key the hooks have is `session_id`, and the agent has the same key in its environment; sessions are the compaction unit; the full id removes the collision case an eight-character prefix would need to handle; `_`-prefix marks a mechanical asset outside the typed-document directories, so no frontmatter and no validation or edit-path changes.
4. **One append path for the chat record; agent-only writer for the devlog.** Single-writer ownership (Pillar 1b) applied to artifacts: the chat record has two authors (hook and agent) but exactly one write routine, `chat-record`'s `>>` append, so nothing ever `Edit`-rewrites the file under a racing append.
   This is why the Scratchpoint lives in the devlog (a file the agent rewrites freely), not in the chat record, and why the turn-end time is a separate appended sign-off line rather than a completion of the agent's header: it fits an append-only file with no state, and the agent's header stays what the agent wrote.
   It is a sign-off, not an `@end` speaker block (maintainer, 2026-10-05), because `@` headers mean attribution and the hook is not a speaker.
5. **Scratchpoint is replace-in-place.** History is the chat record's job; the scratchpoint is a bounded "current state" block so the devlog does not grow per turn.
   It generalizes the thinness-column pattern, keeps the columns, and changes only the storage shape.
6. **Semantic split, flat naming, root as index, `part_of` link.** A byte-count cut produces chunks that are meaningless to navigate; a closed concern is a unit someone will actually want to read alone.
   Flat naming keeps every existing path assumption intact; the `read this when` column replaces a directory hierarchy.
7. **The record is not compaction-aware; compaction guidance is rules only.** Maintainer decision (2026-10-05): a compaction line in the record informs no reader, the handoff-then-ask step and the post-compaction re-read belong in Pillar 2 (unscoped, re-injected on every compaction), and the record path is available to the agent from `CLAUDE_CODE_SESSION_ID` on demand, so no hook has to carry anything across the boundary.
   `PreCompact`, `PostCompact`, and `SessionStart` are not registered; the unverified interactive `/compact` path affects nothing in the record.
8. **Two hooks, one script in `bin/`, bash plus `jq`, one permission rule.** Maintainer decision (2026-10-05) on the net target; round-5 review blockers on the invocation path and permissions.
   `UserPromptSubmit` and `Stop` run on every turn, so the script is shell; it ships in the plugin's `bin/` because that is the one documented way an agent can run a plugin file as a bare command (`CLAUDE_PLUGIN_ROOT` is not exported to Bash-tool commands), at the cost that a plugin with a `bin/` directory is not installable through claude.ai or Cowork, which cdocs (a CLI and OpenCode plugin whose hooks are Claude-Code-only) accepts; the alternative of an `/cdocs:init`-materialized project-local shim was rejected because the shim embeds a version-specific cache path and goes stale on plugin update.
   `/cdocs:init` writes `Bash(chat-record:*)` into `permissions.allow` because a per-turn Bash call that prompts or is denied is a per-turn failure, not a one-time inconvenience.
9. **Committed by default, no redaction, explicit-path staging.** Untracked durable state does not cross worktrees or sessions.
   The two leak channels (pastes, assistant bodies) are named in the `WARN` and accepted by maintainer decision; redaction is a separate workstream ([`2026-09-23-chat-record-redaction-scanning-rfp.md`](2026-09-23-chat-record-redaction-scanning-rfp.md)).
   The always-dirty tree is handled by protocol (overseer stages by explicit path at handoff; dispatched agents never stage `_chat/`), not by gitignoring.
10. **One gist bullet per turn, agent-written, guided not prohibited, backed by a one-shot `Stop` block.** Maintainer decision (2026-10-05): every top-level turn has something a successor should know, if only its outcome, so a turn with no entry is a lapse, not a correct silence; the `gist:` category exists so the minimal honest bullet is always available.
    Content is a judgment call under a guideline (do not log every commit, test run, or tool output; note the one that matters), because a prohibition list either bans the occasionally noteworthy commit or grows exceptions until it is a guideline anyway.
    A hook can only capture raw text, and raw text is the wrong shape for orientation, so content stays agent-authored; the hook checks presence by `prompt_id`, never content, blocks at most once per turn, and is suppressed whenever it cannot locate the record.
    Floor: with every block ignored, the record still carries verbatim user history and per-turn sign-offs, so a lapsing agent degrades the record gradually rather than zeroing it.
    (Round 4's "silence is usually correct" rested on the premise that most turns have no gist; rejected. Round 5's never-list is replaced by the guideline. Round 1's verbatim capture and round 3's bullet-per-action remain rejected; see the NOTE in the Summary.)
11. **The gist log is agent-authored only and claims only awareness.** Maintainer decision (2026-10-05): no `PostToolUse` hook; the agent's `read:` notes and Scratchpoint `files:` gists know relevance and can forget a file, and the raw transcript remains the exhaustive fallback, per the devlog-value report's recommendation 5.
    A mechanical file list was free but relevance-blind and was the only reason the hook needed per-turn state; the file-awareness value the redundancy-check report found cheap is delivered by the judgment half alone.
    The token-cost half (content reuse without a re-read) is out of scope and unclaimed; the read-source report's transcript-granularity re-read measurement is the instrument to re-run after Phase 2 if anyone wants to check that the 97.4% figure moves (the report predicts it will not, materially).
12. **Timestamps per turn, no session markers.** Maintainer decision (2026-10-05): session start and end lines add no information (the first `@user` and the last sign-off are the bookends), while a submission time on every prompt, model and prompt id on every agent header, and an end time and session name on every turn's sign-off let a reader see turn duration, pauses, and which named session produced which stretch.
    The session name is read from the transcript's `custom-title` line at `Stop` time rather than from `SessionStart`'s `session_title`, because that is the only way to get it without registering a third hook; the unnamed case falls back to the short session id.
13. **Agent write path: stdin heredoc, top-level by rule text.** Decided 2026-10-05 on the round-6 review's two blockers.
    The note body comes from a quoted heredoc on stdin because every argument form either expands (`"..."`: backticks, `$(...)`, `$VAR`) or breaks on common text (`'...'`: apostrophes); run R7 confirmed byte-exact delivery and that `Bash(chat-record:*)` still matches in default mode.
    Top-level scoping is rule text, not code, because run R7 found no mechanical signal: a foreground subagent's Bash and the top-level's Bash had identical `CLAUDE*` and `AI_AGENT` variables, including the same `CLAUDE_CODE_SESSION_ID` and `CLAUDE_CODE_CHILD_SESSION=1` in both.
    A `PreToolUse` hook on `Bash` would see `agent_id` and could deny `chat-record` inside subagents, but it is a third hook on every Bash call of every session to police one command; rejected unless the Phase-1 subagent scenario shows the rule text failing.
    `--record` and the absent-variable fallback were dropped with it: the Phase-1 equality test catches a rename, and `note`/`path` fail loudly instead.

## Edge Cases / Challenging Scenarios

- **Harness-generated prompts fire `UserPromptSubmit`.** Canary run 5 showed a background subagent's completion notification arrived as a second `UserPromptSubmit` with no human input; its prompt begins `<task-notification>` / `<task-id>...` (see the loop devlog's `-canary` chunk).
  The payload has no field distinguishing it, so the hook classifies by shape: a prompt whose first non-blank token is an opening tag from a known harness set (`<task-notification`, `<system-reminder`, and whatever the Phase-1 implementer observes) is `@harness`; anything else, including a human pasting HTML, is `@user`.
  Allowlist, not "starts with `<`", to avoid mislabeling humans.
  A harness-prompted turn owes a bullet like any other, and the `Stop` check treats it identically: a leg's return is usually the most gist-worthy moment of the turn (`gist: reviewer r5 returned revise; two blockers`), and a notification that changed nothing still has a one-line state of play.
- **Pure-chat turns.** A turn with no tool use (an answer, a clarification) owes a bullet: the gist of the answer, so a successor reading the `@user` question is not left without the conclusion (`gist: explained Stop fires top-level only; no state change`).
  This is the one turn type where `note` is necessarily an extra round trip.
- **Dispatch-only turns.** A turn that launches a background subagent and ends fires `Stop` (run 5); its bullet is the state of play: `gist: reviewer r5 in flight (background); nothing to do until it returns`.
- **Headless `-p` sessions.** `Stop` fires and the block is honored under `-p` (run 8), but run 8 ran under `bypassPermissions`; in default mode the `note` call is denied unless `Bash(chat-record:*)` is allowed (project `settings.json` via `/cdocs:init`, or `--allowedTools` on the invocation).
  With the rule, AFK `oversee` and other headless uses follow the per-turn rule at the cost of one extra short turn on any turn the agent forgets; a one-shot headless invocation that is not a cdocs session should run with `CDOCS_CHAT_RECORD=off`.
- **`CDOCS_CHAT_RECORD=off`.** No file is created, `note` and `path` exit 0 silently, and `Stop` never blocks; the rule still asks for the bullet but nothing enforces it and nothing records it.
- **`CLAUDE_CODE_SESSION_ID` absent.** `path` and `note` print a stderr line and exit non-zero; hook mode is unaffected (it has the payload), so user blocks and sign-offs continue and the `Stop` block still fires on noteless turns.
  The Phase-1 equality test is what catches a rename.
- **A dispatched subagent runs `note`.** Nothing mechanical stops it (Decision 13): the entry lands in the top-level record under the subagent's `--as` speaker with the overseer's in-flight `p=`, and the overseer's `Stop` check passes.
  The rule text and agent definitions are the guard; the Phase-1 subagent scenario measures whether they hold, and a lapse shows in the record as an entry whose speaker is not the top-level model.
- **Session changes directory into another worktree.** `cdocs/` is resolved from `$PWD` in `note` and from the payload's `cwd` in hook mode, so after `EnterWorktree` or a `cd` into a sibling worktree with its own `cdocs/`, a second file with the same name starts there.
  Accepted: each worktree's record is then the history of the work done in it, and the devlog pointer names whichever one the agent wrote.
- **Slash commands.** A user-defined or plugin command fires `UserPromptSubmit` with the raw invocation string and is recorded as such; built-in `/compact` and `/clear` fire none (run 2) and leave no trace; `/clear` and `/resume` effects on `session_id` are a Phase-1 test item, and either outcome is correct (same file continues, or a new one starts on the next prompt).
- **Body content that looks like a header.** A user pasting a chat record (whose very first line is `@user: ...`), or an assistant quoting one, is handled by the backslash escape; round-trip is a Phase-1 unit test with adversarial input (a prompt whose first line matches `HEADER_RE`, headers inside fences, lines starting with `\@`, a body line shaped like a sign-off, empty bodies, CRLF input); a session title with spaces or quotes is a token-mapping test, not a grammar case.
- **Agent writes an entry, then keeps working in the same turn.** The convention is to note at the end of the turn, batched with the last action; if `note` is called again for the same `p=`, a second entry is appended and the reader tolerates several per prompt.
  The `Stop` check is satisfied by the first.
- **The agent ignores the block.** The second `Stop` carries `stop_hook_active=true`, the hook writes the sign-off and stays silent, the turn ends with no entry; the gap is visible in the record and the Phase-1 real-session criterion counts such gaps.
- **`Stop` with no `@user` for this turn.** A turn whose prompt the hook never saw (hook enabled mid-session; a resume that replays without `UserPromptSubmit`): the check finds no entry and blocks once with `--p <pid8>` in the reason, so the agent's note correlates correctly even though the record's last prompt header is stale; the second `Stop` is silent and writes the sign-off.
  A `Stop` with no record file at all (no prompt ever seen) does nothing.
- **User interrupts a turn.** Whether `Stop` fires on an interrupted turn is unverified (the hooks reference says only "when Claude finishes responding").
  If it does not fire: no sign-off, no block, the turn has no entry, which is correct for an abandoned turn.
  If it does fire: a block would resurrect the agent for one short turn after the user pressed Escape, which is the opposite of what the user asked for, so the block must be suppressed on interrupted turns and only the sign-off written; interactive check (c) establishes whether it fires and which payload signal distinguishes the case (candidate: an empty `last_assistant_message`), and the implementer records the decision in the devlog.
- **`--resume`.** Keeps `session_id` (per `claude --help`) and so appends to the same file; the gap between the previous sign-off and the next `@user` is the only trace, which is all a reader needs.
- **Two sessions on one checkout.** Per-session files never collide, and the devlog is recovered by grepping for the session's own record path, so nothing cross-session exists to confuse; two sessions that both name the same devlog in `## Chat Record` are a single-writer violation the devlog convention already forbids.
- **Very large prompts.** Written verbatim; the file is read by tail and offset, never whole.
  No cap: truncation would defeat "lossless by construction".
- **Transcript unreadable at `Stop`.** the sign-off falls back to the short session id and is still written.
- **Hook timeout or `jq` missing.** Timeout 5s on both entries; the script checks for `jq` and exits 0 silently without it, printing one stderr line; `Stop` never blocks in that state.
- **Not a cdocs project.** No `cdocs/` under `cwd`: silent exit, no directory created, no block.
- **Devlog with no closed concern at 20KB.** Do not split; tighten prose, move landed verification evidence into a `-verification` chunk via the standard split (a landed campaign is a closed concern even when the phase around it is not), and note in the Scratchpoint that a further split is pending the next phase close.
- **Chunk needed while a sub-loop's tables are still live.** Only rows for finished rounds move; the live table stays in the root with a one-line pointer to the chunk holding earlier rows.
- **OpenCode and other targets.** The hooks are Claude-Code-only; `build-opencode.ts` does not port them (no equivalent event surface is assumed).
  Rule and skill text (per-turn bullet, scratchpoint, splitting, boundary steps) delivers to OpenCode via `/cdocs:init` unchanged; without the hooks the per-turn bullet is rule-only, and where a target lacks `/compact`, Pillar 2's existing degradation ("start a fresh session from the handoff") also says "and the chat record if one exists".

## Test Plan

**Phase 1, hook tests (`plugins/cdocs/hooks/tests/chat-record.test.sh`):**

- Headless sandbox runs per the README recipe (sandboxed `CLAUDE_CONFIG_DIR` with copied credentials, out-of-repo `cwd` containing an empty `cdocs/`, `--model haiku`, never `--bare`), with the plugin enabled via `--plugin-dir <worktree under test>/plugins/cdocs` and a first assertion that `command -v chat-record` resolves into that worktree (an installed copy of the plugin puts `main/`'s `bin/` on PATH too), asserting after each scenario on the produced `cdocs/_chat/*.md` and the `--include-hook-events` stream.
  Unless stated, scenarios run in default permission mode with `"Bash(chat-record:*)"` in the sandbox's `permissions.allow`:
  - prompt that instructs the model to read a file and then run `chat-record note --as haiku-4-5` with the body `- read: a.txt: canary fixture` as a quoted heredoc: one `@user` (verbatim prompt, `p=` set), one `@haiku-4-5` entry whose body is exactly `- read: a.txt: canary fixture` and whose `p=` matches, then the sign-off `-- <sid8> at <ts>` as the last line; exactly one `Stop` in the stream with no `decision`; no `permission_denials` entry.
  - shell-expansion round trip: the heredoc body contains a backtick span, `$HOME`, `$(date)`, an apostrophe, double quotes, and a backslash; the entry's body equals the input byte-exact and `permission_denials` is empty (run R7's shape, against the real script).
  - the same with the allow rule removed: the `note` call appears in `permission_denials`, the first `Stop` blocks, the second is silent, the record has `@user` followed directly by its sign-off and no entry (documents the failure the rule prevents).
  - prompt that reads a file and is told not to call `note`: the first `Stop` `hook_response` carries `decision: block` with a reason containing the real record path and `--p <this turn's pid8>`; the model then runs the command; the second `Stop` has no `decision`; the record has exactly one entry with the turn's `p=` followed by the sign-off.
  - prompt that forbids any tool use (so the model cannot comply): first `Stop` blocks, second `Stop` (`stop_hook_active=true`) is silent and writes the sign-off, no third `Stop` (the never-loops property).
  - pure-chat prompt ("reply with the word ok, then note it"): one entry, one `Stop`, no block.
  - two stream-json prompts, each noted: two `@user` blocks with distinct `p=`, two entries whose `p=` match their `@user` pairwise, each followed by one sign-off, timestamps non-decreasing down the file.
  - `note` called twice in one turn: two entries with the same `p=`, one sign-off after the second, no block.
  - `note` with no `--as`: speaker is `assistant`.
  - `echo $CLAUDE_CODE_SESSION_ID` as the prompt's action: the printed value equals the `session_id` in the hook stream and the record filename ends in it.
  - `chat-record path` as the prompt's action: prints exactly the record path and creates no second file.
  - background `Agent` dispatch (run 5's shape): two `UserPromptSubmit` events, the second classified `@harness` with its own `p=`, and each turn's entry satisfies its own `Stop`.
  - foreground `Agent` dispatch whose subagent `Read`s a file: exactly one `@user` block (the subagent's prompt is absent) and nothing written by any event carrying `agent_id`.
  - top-level-only rule: rules materialized by `/cdocs:init` and the plugin's agent definitions loaded; the top-level prompt is told not to note, and dispatches a foreground `cdocs:proposer` (or `general-purpose` with the rules) on a task that takes several tool rounds; assert the record has no entry with a speaker other than the top-level's, and that the top-level's first `Stop` still blocks.
  - a project command `.claude/commands/echo.md` invoked as `/echo hello-world`: one `@user` block whose body is exactly `/echo hello-world`.
  - manual compaction via `--input-format stream-json` with a `/compact` line between two prompts: no block of any kind between the first turn's sign-off and the second `@user`; the record has no line mentioning compaction.
  - `/clear` as a stream-json line, then a prompt: recorded behavior of `session_id` (same file continues, or a new file appears) written into the test's expected output once observed.
  - `claude -p --resume <session_id> "<prompt>"` against a previous scenario's session: the new `@user` lands in the same file.
  - `--rename`-equivalent: after a `/rename my-canary` line (if it is accepted as a stream-json user line; otherwise a pre-written `custom-title` line injected into the transcript), the next sign-off reads `-- my-canary at <ts>`.
  - `CDOCS_CHAT_RECORD=off`: no file created, and a prompt that is told not to `note` produces one `Stop` with no `decision`.
  - no `cdocs/` in `cwd`: no file created, no block.
- Grammar unit test (pure shell, no Claude): escape/unescape round-trip on the adversarial fixture listed under Edge Cases (header-shaped first line, `@alice: hey`, LESS and CSS at-rules, headers inside fences, `\@` lines, a `-- x at 2026-10-05T10:00:00-07:00` body line, empty body, CRLF); a reader that splits on `HEADER_RE` and `SIGNOFF_RE` recovers exactly the input bodies and sign-offs; a title `my canary "v2"` maps to `my-canary--v2-`.
- Exit-code unit test (pure shell): with `CLAUDE_CODE_SESSION_ID` unset, `note` and `path` exit non-zero with one stderr line and write nothing; with `CDOCS_CHAT_RECORD=off`, both exit 0 and write nothing; `path` on a session with no record prints the path and creates no file.
- Payload-shape guard: each event's required fields (`prompt`, `prompt_id` on `UserPromptSubmit` and `Stop`, `stop_hook_active`, `transcript_path`, `session_id`, `cwd`) present, so a Claude Code upgrade that renames a field fails loudly in the test rather than silently in production; `prompt_id` equality between a turn's `UserPromptSubmit` and its `Stop` is asserted explicitly.

**Phase 1, interactive check (manual, once, recorded in the devlog with the resulting chat-record excerpt):** in a real interactive session with the plugin installed and the rule in `settings.json`, (a) confirm `note` runs without a permission prompt; (b) end a turn without noting and confirm the block reason is shown and the agent recovers in one extra turn; (c) interrupt a turn mid-tool-call with Escape and record whether `Stop` fired, what the payload carried, and whether a block occurred; (d) `/rename` the session and confirm the next sign-off carries the name; (e) type a message while a turn is running and record whether it fires `UserPromptSubmit` mid-turn (which would move `note`'s default `p=`).

**Phase 1, rules check:** after the Pillar 2 text lands, a sandboxed session with the rules materialized by `/cdocs:init` is compacted mid-task; the post-compaction turn's first tool calls must be `chat-record path` and reads of the devlog's Scratchpoint and the chat-record tail (asserted from the stream), and the post-compaction context must contain the Pillar 2 boundary text, with no hook having emitted `additionalContext`.
A static check precedes it: the `.claude/rules/cdocs.md` that `/cdocs:init` writes contains the Pillar 2 marker string (the per-turn rule's first line).

**Phase 1, usefulness sample:** from the real-session record in the success criteria, a fresh reviewer scores twenty random `@<model>` entries on "would a successor reading only the `@user` blocks and this bullet know where things stand"; pass bar 80%.

**Phase 2, scratchpoint and splitting:**

- Resumption-quality A/B (the gate for Phase 3), modeled on the Factory.ai anchored-iterative-summarization eval the devlog-value report cites: three real workstreams, a reset forced mid-task-unit (between handoffs), three arms per workstream: (1) carry indefinitely, i.e. resume from the native compaction summary alone; (2) steered `/compact` then resume from Scratchpoint plus handoff plus chat-record tail; (3) `/clear` then reseed from the same durable state with no summary at all.
  A fresh reviewer scores each resume on "correct next action, no re-litigated decision, no re-read of already-read files".
  Pass: arm 2 wins or ties arm 1 on all three workstreams.
  Decision rule for `/cdocs:compact`: if arm 3 ties arm 2, the skill prints `/clear` plus a resume pointer rather than a steering string, since a hard reset is then strictly cheaper.
- Split dry-run on the two largest existing devlogs (`2026-09-22-agent-dispatch-labeling.md`, 19KB; `2026-05-12-rule-delivery-regression-test.md`, 17KB): a fresh agent, given only the root index, is asked three task-scoped questions and must answer each by opening at most one chunk.
- `/cdocs:triage` and `/cdocs:status` recognize `part_of` and group chunks under their root.

**Phase 3:** covered under Implementation Phases, gated on the Phase-2 A/B.

## Verification Methodology

The implementer verifies hooks by reading the artifact they write, not by trusting the hook ran.
The canary recorder below is the reusable instrument; it logs every event with its full stdin payload, so a failing assertion shows the actual shape.

```bash
# canary.sh <Event>: append {"event","at","stdin"} to $CANARY_LOG.
EV="$1"; IN="$(cat)"
printf '{"event":"%s","at":"%s","stdin":%s}\n' "$EV" "$(date -Is)" \
  "$(printf '%s' "$IN" | jq -c .)" >> "$CANARY_LOG"
exit 0
```

```bash
# Sandbox: fresh CLAUDE_CONFIG_DIR with settings.json wiring canary.sh to every event under test,
# plus copies of ~/.claude/.credentials.json and ~/.claude/.claude.json (README "Sandbox testing notes").
# Default permission mode with the allow rule, not bypassPermissions, except where a scenario says otherwise.
cd "$SANDBOX/proj" && CLAUDE_CONFIG_DIR="$SANDBOX/cfg" claude -p "<prompt>" --model haiku \
  --plugin-dir "$WORKTREE/plugins/cdocs" --allowedTools "Bash(chat-record:*)" \
  --output-format stream-json --verbose --include-hook-events > out.jsonl
# manual compaction: --input-format stream-json with a {"type":"user",...,"content":"/compact"} line
```

Two independent evidence channels: the `--include-hook-events` stream (`hook_started`/`hook_response` for `UserPromptSubmit` and `Stop`, including the `Stop` block's `decision` and the `num_turns` count that shows the one-turn cost, run 8) and the record file itself.
The stream's `permission_denials` array is the ground truth for the permission scenarios.

For the rules-driven post-compaction behavior, the instrument is the stream itself: the tool calls the model makes in the first post-compaction turn are the evidence that the rules, not a hook, directed the re-read.
For the scratchpoint and splitting, verification is the A/B and the split dry-run above, both scored by a fresh agent, never by the author.

## Implementation Phases

### Phase 0: hook canary (done, 2026-09-22 to 2026-10-05, Claude Code 2.1.280 and 2.1.289)

Prerequisite the brief required before Phase 1: confirm the hooks this design needs actually fire and behave.
Eight headless runs on 2.1.280 in a sandboxed `CLAUDE_CONFIG_DIR` with `--model haiku`, with per-run `settings.json`, exact commands, canary-log lines, and model results in the loop devlog's `-canary` chunk, [`2026-09-22-chat-record-devlog-management-propose-revise-canary.md`](../devlogs/2026-09-22-chat-record-devlog-management-propose-revise-canary.md); the round-1 review re-derived every row and added two runs ([`2026-09-22-review-of-chat-record-devlog-management.md`](../reviews/2026-09-22-review-of-chat-record-devlog-management.md)); the round-5 review added three runs on 2.1.289 ([`2026-10-05-review-of-chat-record-devlog-management-r5.md`](../reviews/2026-10-05-review-of-chat-record-devlog-management-r5.md), "Verification performed"); run R7 (2026-10-05, 2.1.289, default permission mode) is recorded in the `## Round 7` section of [`2026-10-05-chat-record-devlog-management-revise-r5.md`](../devlogs/2026-10-05-chat-record-devlog-management-revise-r5.md).
Rows this design relies on:

| Fact | How established | Relied on for |
|---|---|---|
| `UserPromptSubmit` fires with `prompt` verbatim, `prompt_id`, `session_id`, `cwd` | run 1 | the `@user` block and its `p=` |
| `UserPromptSubmit` does not fire for a subagent's dispatch prompt | runs 5 and 6, review Run A | top-level-only scoping |
| `UserPromptSubmit` fires a second time, with no human input, on a background subagent's completion | run 5 | the `@harness` speaker |
| `UserPromptSubmit` on a user-defined slash command carries the raw invocation string | review Run B | slash-command turns |
| Built-in `/compact` as a user line fires no `UserPromptSubmit` | run 2 | built-in commands leave no trace |
| `Stop` fires top-level only (`agent_id: null`), including for a turn that only launched a background subagent, with `prompt_id` equal to the turn's `UserPromptSubmit.prompt_id`, `stop_hook_active`, `transcript_path` | runs 5 and 6 | the per-turn check, `p=` correlation, the sign-off, the session title lookup |
| `Stop` returning `decision: block` once is honored; the second `Stop` carries `stop_hook_active=true`; three turns total | run 8 (2026-09-23, under `bypassPermissions`) | the one-shot block |
| `CLAUDE_CODE_SESSION_ID` is exported to the Bash tool and equals the hook's `session_id`; `CLAUDE_PLUGIN_ROOT` is not exported | r5 review run A (2.1.289) | path derivation in `note` and `path` |
| A plugin's `bin/` is on the Bash tool's PATH while enabled | plugin reference; r5 review's own session; this revision's session (`.../plugins/cdocs/bin` present on PATH before the directory exists) | the bare `chat-record` command |
| An unallowlisted Bash script call is denied in headless default mode (`DENIED This command requires approval`) | r5 review run C | the permission rule |
| A quoted-heredoc body reaches the script's stdin byte-exact (backticks, `$HOME`, `$(date)`, apostrophe, quotes, backslashes), and the call matches `Bash(chat-record:*)` in default mode (`permission_denials: []`) | run R7 (2026-10-05, 2.1.289, haiku, stub `chat-record` that logs stdin) | the stdin `note` body |
| A foreground subagent's Bash has the parent's `CLAUDE_CODE_SESSION_ID` and an environment identical to the top-level's in every `CLAUDE*`/`AI_AGENT` variable (`CLAUDE_CODE_CHILD_SESSION=1` and `AI_AGENT=claude-code_2-1-289_agent` in both) | r6 review; run R7 (same run, the subagent ran the stub too) | Decision 13: no mechanical subagent guard |
| The transcript carries `{"type":"custom-title","customTitle":"<name>","sessionId":"<id>"}` lines, rewritten over the session; `SessionStart` is the only hook payload documented to carry a title (`session_title`) | this revision's session (2.1.289); hooks reference | the session name in the sign-off |

Also verified but not relied on: `SessionStart` (all sources, `additionalContext` reaching the model), `PreCompact` (manual and auto, `custom_instructions` present), `PostCompact` (full `compact_summary`), `SessionEnd` (`reason`), `PostToolUse` (per call, and inside subagents with `agent_id`), `SubagentStart`/`SubagentStop`.
Phase 3's per-workstream pointer is the only prospective consumer of the last two.

Not verified: whether `Stop` fires on a user-interrupted turn; `/clear` and `/resume` effects on `session_id`; whether `/rename` is accepted as a stream-json line; a non-null `custom_instructions` value (irrelevant now that `PreCompact` is unregistered).

### Phase 1: capture, per-turn rule, permissions, compaction guidance

Deliverables:

1. `plugins/cdocs/bin/chat-record` implementing the script contract above (`agent_id` guard first, `stop_hook_active` guard before any `Stop` decision, `note` with its body on stdin, `path` that never creates, non-zero exits for `note`/`path` failures, no runtime-directory state); `hooks.json` entries for `UserPromptSubmit` and `Stop` invoking `${CLAUDE_PLUGIN_ROOT}/bin/chat-record <Event>` (timeouts 5s).
2. `plugins/cdocs/hooks/tests/chat-record.test.sh` per the Test Plan, plus the grammar round-trip and exit-code unit tests.
3. `/cdocs:init`: scaffolds `cdocs/_chat/` with a one-paragraph `README.md` (what it is, hook-written, do not edit, opt-outs), merges `"Bash(chat-record:*)"` into `permissions.allow` in `.claude/settings.json` (create the file or key if absent; never remove entries; idempotent), and writes `orchestration-discipline.md` Pillar 2 verbatim into `.claude/rules/cdocs.md` (the file Claude Code loads; today step 3 writes only the writing conventions there, and only the `AGENTS.md` block inlines `orchestration-discipline.md`), with the rules-check presence test asserting it.
4. `frontmatter-spec.md`: one line under "Media" noting `cdocs/_chat/` as hook-written, frontmatter-free, like `_media/`; `plugins/cdocs/README.md` "Hooks" gains the two entries, the `Stop` block semantics, the permission rule in both forms (`settings.json`, `--allowedTools`), the `bin/` installability trade-off, and the opt-outs.
5. `orchestration-discipline.md` Pillar 2, in this order: the per-turn gist rule (opening "top-level session only; if you were dispatched by the `Agent` tool, never run `chat-record`"; before ending any turn, append at least one `gist|query|read|follow-up:` bullet with `chat-record note --as <model>` and the bullets in a quoted heredoc (`<<'EOF'` ... `EOF`), never as an argument, batched with the turn's last tool call where possible; one line of what a successor should know; the guideline on commits, test runs, and tool output; the `Stop` hook blocks once if forgotten); the first-turn step (`chat-record path` into the devlog's `## Chat Record`); the task-unit-boundary step (handoff, Scratchpoint, commit devlog and chat record by explicit path, then ask the user for `/compact <steering>` or `/clear`, with the steering string and who types it); the post-compaction step (`chat-record path`, `grep -l` for the devlog, re-read Scratchpoint, latest handoff, last five record blocks; never re-derive state from the summary); the commit protocol and Pillar 1 carve-out sentence; and the rule that agents never `Edit` or `Write` `cdocs/_chat/`.
6. `plugins/cdocs/skills/devlog/SKILL.md`: `## Chat Record` pointer section with the `path` command, the heredoc `note` form, and the four categories; chat records are quoted only inside fences; the `## Verification` section is the evidence home, split as a standard chunk when large.
7. One line in each agent definition, `plugins/cdocs/agents/{bash-runner,implementer,judge,nit-fix,proposer,reviewer,triage}.md`: "You are a dispatched subagent: never run `chat-record`; the chat record is the top-level session's."
8. Interactive checks (a)-(e), the rules check, and the usefulness sample from the Test Plan, recorded in the devlog, with the interrupt decision written down.
9. Mark `2026-09-01-devlog-autoflush-hook.md` `status: evolved` with a pointer here.

Success criteria: all hook tests green in default permission mode, including block-and-recover, shell-expansion round trip, never-loops, denial-without-rule, harness, dispatch, top-level-only, slash-command, resume, environment-variable equality, and opt-out scenarios; a real session in this repo produces a committed `cdocs/_chat/` file in which every `@user`/`@harness` block is followed by at least one `@<model>` entry and exactly one sign-off before the next prompt (zero gaps over a session of at least twenty turns), whose entries are gist bullets in the named categories with no reply text and no enumerated action lists, and whose usefulness sample passes the 80% bar; the interactive checks show no permission prompt, a block recovered in one turn, the interrupt behavior recorded, and the session name in the sign-off; the rules check shows the post-compaction re-read driven by rules alone.

Constraints: do not touch `inject-rules.ts`, `validate-cdocs-edit-path.sh`, or `cdocs-validate-frontmatter.sh`; do not add `_chat/` to either path regex; do not register any hook other than `UserPromptSubmit` and `Stop`; no runtime-directory files; the only `decision: block` is the `Stop` one-shot, and it must be unreachable when `stop_hook_active` is true.

### Phase 2: scratchpoint and semantic splitting

Depends on Phase 1 (the Pillar 2 post-compaction step and the steering string name the Scratchpoint).

Deliverables:

1. `orchestration-discipline.md`: a "Scratchpoint" subsection under Pillar 2 with the block format (including the `files:` gist list and its awareness-only framing), writer set, cadence, and the judge-observable staleness rule; the handoff format's Completed subsection gains the gist one-liners for files touched; Pillar 3 says durable specialists keep one in the devlog they own.
2. `plugins/cdocs/skills/devlog/template.md` gains `## Scratchpoint` and `## Chat Record`; `iterate`, `propose-revise`, `full-send`, `oversee`, and `implement` skills reference the rule (one line each, no restating); `agents/implementer.md` tells a warm implementer to maintain it.
3. `plugins/cdocs/skills/devlog/SKILL.md`: "Splitting a devlog" section with the trigger, the three-part closure test, the move-every-closed-concern and ~3KB-merge rules, naming, the Chunks table, chunk frontmatter (`status: done`, `part_of`) and backlink; Pillar 2's handoff step adds "check size; if past ~12KB, split every closed concern".
4. `frontmatter-spec.md`: optional `part_of` for chunks; `triage` and `status` skills group by it; `agents/judge.md` gains the Scratchpoint-staleness condition for `overseer_thinness: signal_missing`.
5. The three-arm resumption-quality A/B and the split dry-run from the Test Plan, results in the devlog.

Success criteria: A/B arm 2 wins or ties arm 1 on all three workstreams, and the arm-3 result is recorded as the `/cdocs:compact` decision input; the split dry-run answers each task question with at most one chunk opened; `cdocs-validate-frontmatter.sh` accepts chunk files unchanged.

Constraints: the `overseer_ctx_est`/`inline_work` columns and the judge's `overseer_thinness` field are not removed or renamed; the Scratchpoint is additive to them.
Do not introduce a directory-per-workstream layout.

### Phase 3 (gated on the Phase-2 A/B): cap-and-reseed and `cdocs:compact`

1. **Cap-and-reseed durable specialists** (token-spend workstream 4): Pillar 3 and the `iterate` skill gain a cutoff (starting value per that report's own caution, ~0.4-0.6M, tentative) at which the overseer has the specialist write a final Scratchpoint and handoff, then dispatches a fresh leg seeded from them plus a one-line pointer, instead of letting the specialist run to the ~1M sawtooth reset.
   This is fully agent-controllable today: no compaction primitive is involved, only dispatch.
2. **`/cdocs:compact` skill**: user-invoked; performs the Pillar 2 boundary step (Scratchpoint, handoff, commit of devlog plus chat record) and then prints the exact line for the user to run: `/compact <steering>`, or `/clear` plus a resume pointer if the Phase-2 arm-3 result says a hard reset ties, because agent-invokable compaction does not exist ([#71803](https://github.com/anthropics/claude-code/issues/71803) open).
   It relies on no hook: it is the rule's boundary step packaged as a command, and when the compaction primitive ships its last step becomes the invocation itself.
3. **Per-workstream chat record (pointer, not designed here).** Maintainer direction (2026-09-23): nested chat records scoped per `task_list`, one record for the proposer, reviewer, and implementer legs of a workstream rather than one per subagent.
   Likely mechanism: register `SubagentStart`/`SubagentStop` and relax the `agent_id` guard, keeping the script the only writer; the open questions (whether a `SendMessage`-resumed specialist fires a fresh start/stop pair, how a dispatch prompt correlates to `agent_id`, and whether workstreams span enough legs to need it) need a canary and a separate proposal before any build.

Success criteria: a specialist reseeded at the cutoff continues without re-reading files its predecessor already read (measured by the reviewer on the next round); `/cdocs:compact` followed by the printed line produces a post-compaction or post-clear turn that acts on `next` from the Scratchpoint without re-orientation.
