---
first_authored:
  by: "@claude-fable-5-1"
  at: 2026-09-22T18:27:04-07:00
task_list: meta/chat-record-devlog-management
type: proposal
state: live
status: review_ready
last_reviewed:
  status: accepted
  by: "@claude-opus-4-8"
  at: 2026-09-23T13:20:00-07:00
  round: 4
tags: [meta, tooling, context_persistence, hooks, devlog, orchestration, agent-memory]
---

# Chat Record, Scratchpoint, and Semantic Devlog Splitting

> BLUF(fable-5-1/chat-record-devlog-management): Build both layers.
> A per-session **chat record** under `cdocs/_chat/` holds hook-captured verbatim user turns plus one terse agent-written gist bullet per top-level turn (what a successor should know, never an action log), backed by a `Stop` hook that blocks once when a turn has no entry.
> A rolling agent-written **`## Scratchpoint`** in the devlog is the current-state snapshot with a gist per file touched.
> Compaction is guided by rules, not hooks: handoff and commit at a task-unit boundary, then ask the user for `/compact <steering>` or `/clear`; after compaction, re-read Scratchpoint, handoff, and chat-record tail, not the summary.
> Hook surface: `SessionStart`, `UserPromptSubmit`, `Stop`, plus `PreCompact` and `SessionEnd` markers, all canary-verified on 2.1.280.
> Devlogs split at closed-concern boundaries into `-<concern>` chunks with the root as index.
> This makes the summary's quality irrelevant to resumption; it does not prevent native auto-compaction.

## Summary

This proposal operationalizes the resolved design in [`2026-09-22-chat-record-scratchpoint-design.md`](../reports/2026-09-22-chat-record-scratchpoint-design.md) (the chat-record report) and the devlog-management half of the context-management roadmap (RFP-2).
It does not re-derive the research; it specifies file formats, hook contracts, rule and skill text, and a phased, testable rollout.

Three artifacts, each with exactly one write path:

| Artifact | Author | Cadence | Location |
|---|---|---|---|
| Chat record | hook (user turns, session markers, mechanical) plus the agent (its own gist bullets, via `chat-record.sh note`); all appends go through the one script | every user turn; every top-level agent turn (one bullet minimum); a marker line at compaction start and session end | `cdocs/_chat/YYYY-MM-DD-<sid8>.md`, one file per session |
| Scratchpoint | the overseer or a durable specialist (agent) | every state-changing turn, replaced in place; carries a `files:` gist list (one line per important file: what it was useful for) | `## Scratchpoint` block in the devlog that agent owns |
| Devlog chunks | the devlog's author (agent) | at a handoff boundary when a concern has closed | `cdocs/devlogs/YYYY-MM-DD-<root>-<concern>.md`, root becomes index |

The chat record generalizes nothing that exists; it fills the gap the read-source report names ("`/compact` does not preserve full user history") and, for agent turns, is a chronological record of the one thing per turn a future reader should know, not a transcript and not a changelog.

> NOTE(fable-5-1/chat-record-devlog-management): Revision history of the agent-turn content model and the hook surface.
> Round 1 captured `last_assistant_message` verbatim by hook; round 3 replaced that with one agent-written bullet per action item; round 4 (maintainer, 2026-09-23) made entries judgment-driven and sparse ("bullet point" was directional, not a per-action mandate; "absolutely no commit records"), dropped the `Stop` block, and added a five-quiet-turn advisory.
> Round 5 (maintainer, 2026-10-05) is the current design: every turn writes one gist bullet, the `Stop` block returns as the enforcer, the `PostToolUse` hook and its `files=` header metadata, active-devlog tracking, and `acted` mark are dropped (agent notes name salient files themselves), the `PostCompact` summary capture and `PreCompact` nudge are dropped in favor of rules-driven compaction guidance, and `SessionEnd` is a bookend only.
> The duplication concern from round 1 is resolved by shape: the chat record is a chronological record of curated notes, the Scratchpoint is a current-state snapshot, both are agent-authored, and no hook supplies content.

The scratchpoint generalizes the per-turn `overseer_thinness` columns in [`orchestration-discipline.md`](../../plugins/cdocs/rules/orchestration-discipline.md) (same per-turn, agent-authored, judge-observable pattern) with one deliberate change of storage shape: replace-in-place rather than additive append, because chronology now lives in the chat record and an append-only per-turn log would recreate the devlog-bloat failure mode.

> NOTE(fable-5-1/chat-record-devlog-management): The chat-record report treated `PostCompact` as an open feature request ([#14258](https://github.com/anthropics/claude-code/issues/14258)) and a `PreCompact` reliability gap on manual `/compact` ([#13572](https://github.com/anthropics/claude-code/issues/13572)) as reasons to keep hooks secondary.
> Both are closed upstream; the canary showed `PostCompact` delivering the full `compact_summary` on 2.1.280.
> This design records neither (Decision 7): the summary is the artifact whose quality the design makes irrelevant, so writing it to git would be 7-9KB per auto-compaction of exactly the content a resuming agent is told not to trust.

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
   Pillar 2's reseed guarantee (project-root `CLAUDE.md` and unscoped rules re-inject on auto and manual compaction; `/cdocs:init` materializes cdocs rules unscoped) is what lets this design carry compaction guidance in rules rather than hooks.
5. [`plugins/cdocs/skills/devlog/SKILL.md`](../../plugins/cdocs/skills/devlog/SKILL.md) and its `template.md`: the convention the scratchpoint block and the split rule extend.
6. The devlog mandate: root `CLAUDE.md` ("IMPORTANT: Always create a devlog") and the "Devlog Convention" section of [`writing-conventions.md`](../../plugins/cdocs/rules/writing-conventions.md).
   The brief named `cdocs/rules/cdocs.md` as a candidate location; that path does not exist in this repo (the source repo loads rules via `@plugins/cdocs/rules/` imports), so the mandate is cited from its actual locations.
7. Existing hook plumbing: [`plugins/cdocs/hooks/hooks.json`](../../plugins/cdocs/hooks/hooks.json), [`inject-rules.ts`](../../plugins/cdocs/hooks/inject-rules.ts) (the `additionalContext` nudge pattern), and the sandbox-testing recipe in [`plugins/cdocs/README.md`](../../plugins/cdocs/README.md) "Sandbox testing notes".
8. [`2026-09-01-devlog-autoflush-hook.md`](2026-09-01-devlog-autoflush-hook.md): an RFP stub whose open questions this proposal answers (can a hook force a write: yes, once per turn, via a `Stop` block bounded by `stop_hook_active`; which devlog is active: not tracked by any hook, recovered by convention from the chat-record path the devlog names); it should be marked `evolved` into this one at Phase 1.
9. [`2026-09-22-shared-retrieval-cache-redundancy-check.md`](../reports/2026-09-22-shared-retrieval-cache-redundancy-check.md): drops the shared-cache RFP and splits its value in two halves.
   The **awareness** half ("was this file already read, and what is the gist") is cheap, proven, and folded into this proposal as the agent-written `read:` notes and the Scratchpoint's `files:` gist list.
   The **token-cost** half (putting agent A's file bytes into agent B's context) has no working mechanism on this platform and is explicitly not solved here; the gist lets an agent decide whether to re-read, it does not make the re-read free.

### Non-Goals

- **Graphify-scoped retrieval.** A separate effort, already in progress elsewhere; nothing here depends on or designs it.
- **Shared retrieval cache and cross-agent read deduplication (the token-cost half).** Dropped per the shared-cache report; this proposal neither designs nor assumes any content-sharing mechanism and makes no claim that the gist notes reduce the measured 97.4% cross-agent re-read figure.
- **Memory-tool integration.** Orthogonal per the chat-record report; a possible future storage backend, not adopted.
- **Post-hoc distillation of devlogs by a cheap model.** Rejected by the devlog-value report.
- **Mechanical capture of files touched.** No `PostToolUse` hook; the only record of which files mattered is the agent's own `read:` notes and Scratchpoint `files:` gists, and the raw transcript is the exhaustive fallback (Decision 11).
- **Compaction-summary capture.** `PostCompact` is not registered; see Decision 7.
- **Chat records for dispatched subagents, in Phases 1 and 2.** The hook exits on every event whose payload carries `agent_id`, the field the hooks reference documents as "present only when the hook fires inside a subagent call", so top-level-only scoping rests on a documented guard rather than on the (also observed) fact that `UserPromptSubmit` does not fire for a subagent's dispatch prompt.
  A per-workstream record that includes dispatched legs is a Phase-3 design sketch, not built here.
- **Hook-enforced scratchpoint writing.** The scratchpoint is judgment-bearing; a hook can nudge, never author.
- **Redaction or secret scanning.** Chat records commit by default with no redaction pass; the exposure is accepted and documented (Design Decision 9).
  General redaction and secret scanning for committed cdocs artifacts is scoped separately in [`2026-09-23-chat-record-redaction-scanning-rfp.md`](2026-09-23-chat-record-redaction-scanning-rfp.md) and nothing here attempts it.

## Proposed Solution

### Layer map

```mermaid
sequenceDiagram
    participant U as User
    participant H as chat-record.sh (hook)
    participant A as Agent (overseer)
    participant CR as cdocs/_chat/<session>.md
    participant DL as devlog (## Scratchpoint, handoff)
    A-->>H: SessionStart (any source)
    H->>CR: create on first event; append @session start line
    H-->>A: additionalContext: chat record is <path> (source=...)
    U->>H: UserPromptSubmit
    H->>CR: append @user: block (p=<pid8>)
    A->>DL: replace ## Scratchpoint incl. files: gists (every state-changing turn)
    A->>H: chat-record.sh note --as <model> <record> "- gist: ..." (every turn, at least one bullet)
    H->>CR: append @<model>: entry (p=<pid8>)
    A-->>H: Stop
    H->>H: entry with this p= present? yes: silent. no and stop_hook_active=false: block once
    Note over A: rules: at a task-unit boundary write handoff + Scratchpoint, commit, ask user for /compact <steering> or /clear
    A-->>H: PreCompact
    H->>CR: append @session: compact-begin line (trigger, instructions)
    A-->>H: SessionStart(source=compact)
    H-->>A: additionalContext: chat record is <path> (source=compact)
    Note over A: rules (re-injected): re-read Scratchpoint + handoff + chat-record tail, not the summary
    A-->>H: SessionEnd
    H->>CR: append @session: end line
```

### Chat record

#### Location and naming

`cdocs/_chat/YYYY-MM-DD-<sid8>.md`, one file per Claude Code session, where `YYYY-MM-DD` is the local date of the session's first recorded event and `<sid8>` is the first eight hex characters of `session_id`.
Example: `cdocs/_chat/2026-09-22-13ee1efb.md`.

The hook locates the file by glob, `cdocs/_chat/*-<sid8>.md`, never by recomputing the date (a `--resume` the next day must land in the same file), and creates it only when the glob is empty.
The first line of every file is `@session: <ts> start source=startup sid=<full session_id> cwd=<cwd>`; when the glob hits a file whose first line carries a different `sid=`, the hook falls back to the full id in the filename (`YYYY-MM-DD-<session_id>.md`) rather than appending to a stranger's record.
A same-day 32-bit prefix collision is negligible in probability, but the hook must never be silently wrong about it.

Why per session rather than per `task_list`: the hook knows `session_id` on every event and knows nothing about workstreams; `--resume` continues a session under the same id (per `claude --help`), so a resumed session keeps appending to the same file; and a session is the unit that compaction acts on.
The link from workstream to chat record is made the other way: the hook tells the agent its chat-record path via `additionalContext` on every `SessionStart` (startup, resume, clear, compact), and the agent records it in the devlog (`## Chat Record` pointer in the index devlog, see Scratchpoint section).
That pointer is also how the devlog is found again after compaction: `grep -l '<record path>' cdocs/devlogs/*.md` returns the devlog this session owns, with no hook state involved.

Why an underscore directory at the top level: `cdocs/_media/` already marks non-document assets; chat records are mechanical artifacts, not authored documents, so they carry no frontmatter and are excluded from the frontmatter-validation regex (`cdocs/(devlogs|proposals|reviews|reports)/`) and from the cdocs-subagent edit-path allowlist, both of which match only the four typed directories.
No frontmatter-spec change is needed; the spec gains one line noting `_chat/` alongside `_media/`.

Chat records are committed, like devlogs, because durable state that must survive a fresh session or a sibling worktree is worthless untracked (the bare-repo layout in `CLAUDE.md` makes this explicit).

**Commit protocol.** The record grows on every turn, so the working tree is dirty at every moment a commit happens.
Therefore: the overseer stages the record by explicit path at each handoff (`git add cdocs/_chat/<file> cdocs/devlogs/<devlog>`), in the same devlog-class bookkeeping commit as the devlog; dispatched agents never stage `cdocs/_chat/` (no `git add -A`, no `git commit -a`, no "commit everything" step touches it), and their briefs say so.
A commit made mid-turn is stale by the next `Stop`; that is expected, the record is append-only and the next handoff commit catches up.
This is the carve-out to Pillar 1's "the overseer does not commit code itself": devlog and chat-record commits are bookkeeping the overseer already performs, not code commits.

> WARN(fable-5-1/chat-record-devlog-management): A committed chat record has two leak channels: text a human pastes into a prompt, and `@<model>` bodies, where an assistant that echoes a `.env` value, a token from a tool result, or a credential path writes it to git with no human paste involved.
> The gist rule narrows the second channel (one terse line per turn, never tool output) but does not close it.
> Maintainer decision (2026-09-23): commit by default, no redaction pass in the hook; the exposure is accepted and documented here rather than mitigated.
> General redaction and secret scanning is deferred to [`2026-09-23-chat-record-redaction-scanning-rfp.md`](2026-09-23-chat-record-redaction-scanning-rfp.md).
> Opt-outs: the hook honors `CDOCS_CHAT_RECORD=off` (no writes, no `Stop` block), and a project may add `cdocs/_chat/` to `.gitignore` to keep records local at the cost of cross-worktree and cross-session durability.

#### Block grammar

A chat record is a sequence of blocks.
Each block is a header line at column 0 followed by a body that runs to the next header line or end of file.

```
HEADER_RE := ^@[A-Za-z0-9][A-Za-z0-9._-]*:          ; the ONE pattern both writer and reader use
record    := block*
block     := header "\n" body
header    := HEADER_RE (" " meta)? "\n"              ; column 0, no leading whitespace
meta      := timestamp (" " key "=" value)*          ; timestamp is ISO 8601 with offset
value     := bare-token | "\"" qchar* "\""           ; quote when the value has spaces, "=", "," or "\""
qchar     := any char except "\"" "\\" LF CR | "\\\\" | "\\\"" | "\\n" | "\\r"
body      := line*                                   ; verbatim, may contain blank lines and fences
```

Rules that keep the grammar unambiguous:

- **`HEADER_RE` is the single split and escape test.** A line is a header if and only if it matches `HEADER_RE` at column 0 with no preceding backslash; whatever follows the colon on a real header is parsed as `meta` (an empty or malformed `meta` is still a header, with the tail kept as opaque text).
  The writer escapes any body line matching `^\\*HEADER_RE` by prefixing one backslash, so `@alice: can you look at this`, a LESS `@brand-color: #333;`, a CSS `@page:first {`, and a pasted `@user: ...` first line are all escaped even though none carries a timestamp; the reader strips exactly one leading backslash from any line matching `^\\+HEADER_RE`.
  Both tests use the same prefix, so writer and reader can never disagree about where a block ends.
  The transform is applied to every body line regardless of fence state, so parsing is stateless and round-trips verbatim.
- **Quoted values have exactly four escapes.** Inside `"..."`, `\\` and `\"` are the only escapes for `\` and `"`, and a literal newline or carriage return in a value (a pasted multi-line `/compact` instruction, a path with a quote) is written as the two-character sequences `\n` and `\r`.
  The reader unescapes those four and nothing else.
  This is what keeps "metadata lives on the header line only" true.
- **CRLF is normalized.** The writer converts `\r\n` to `\n` in bodies before the escape pass, so a pasted Windows transcript cannot carry `\r` into the header test.
- **Metadata lives on the header line only.** A body never carries metadata; a following line is always content.
  This keeps the header regex the single thing a reader needs.
- **Block separation is by header, not by blank line.** The writer emits one blank line after each body for readability; the reader strips trailing blank lines from a body.
  Multi-paragraph and fenced content inside a body needs no delimiter because only the next header ends it.
- **No collision with cdocs markdown.** `#` headings, `>` callouts (`BLUF`, `NOTE`, `WARN`), `|` tables, `-` lists, and fences never begin with `@`, and column-0 `@` is not markdown syntax (it renders as text).
  Chat records are never embedded in other cdocs documents except inside a fenced code block; the devlog skill says so.

Speakers:

| Speaker | Written on | Body |
|---|---|---|
| `@user` | `UserPromptSubmit` with a human prompt | the prompt, verbatim |
| `@harness` | `UserPromptSubmit` whose prompt is a harness envelope (see Edge Cases) | the prompt, verbatim |
| `@<model-short>` (e.g. `@opus-4-8`, `@fable-5-1`, `@haiku-4-5`) | the agent, via `chat-record.sh note`, on every top-level turn | one to three terse gist bullets in the named categories (below); never a reply, never an action log |
| `@session` | `SessionStart`, `PreCompact`, `SessionEnd` | empty; the header's metadata is the content |

`<model-short>` is the model id with the `claude-` prefix and any trailing `-YYYYMMDD` stripped: `claude-haiku-4-5-20251001` becomes `haiku-4-5`, `claude-opus-4-8` becomes `opus-4-8`.
The agent passes its own speaker (`note --as fable-5-1`; it knows its model from its system prompt); when omitted, the script writes `assistant`.
No payload the hook sees on a non-compaction event carries a model id (`SessionStart(startup)` has none, Phase-0 run 1), and the transcript is not scraped for one.

**Agent gist entries.** Every top-level turn ends with an entry: one bullet minimum, three at most, one line each, under about 120 characters, in these categories, with a category prefix so entries are greppable (a bullet with no prefix is read as `gist:`):

- `gist:` the default: what this turn concluded, decided, or changed in the state of play, phrased as what a successor should know, not as what was done.
  `gist: Stop block is the enforcer; five-turn advisory dropped (maintainer 2026-10-05)`; `gist: reviewer r5 returned accept; next is merge`; `gist: answered why Stop fires top-level only; no state change`.
- `query:` a retrieval or search query that turned out useful and what it surfaced, for example `query: graphify query "hook events" surfaced the PostCompact matcher table; reuse before grepping the binary`.
  This is the oldest idea in this roadmap: the "this graphify query was useful for context" note that the token-spend report's workstream 1 asks a dense per-turn record to carry ([`2026-09-20-token-spend-by-role.md`](../reports/2026-09-20-token-spend-by-role.md), "Dense per-turn agent summary ... the most important points"), and that the context roadmap carried into RFP-2.
- `read:` a high-salience file a successor should read, and why, for example `read: plugins/cdocs/hooks/inject-rules.ts: the additionalContext emit shape every new hook copies`.
  This is also where the agent names files that mattered; nothing mechanical records them.
- `follow-up:` an opened thread to revisit later, for example `follow-up: interactive TUI /compact path still unverified; needs a real-session check before Phase 1 ships`.

The test for a bullet is "would a successor reading only the `@user` blocks and these bullets know where things stand": a routine turn earns a one-line `gist:` of its outcome, a turn that learned something transferable earns a `query:` or `read:`, a turn that opened a thread earns a `follow-up:`.
What is never written: an action log (a list of commits, edits, test runs, tool calls, or dispatches), reasoning, tool output, file contents, or the agent's user-facing reply.
The distinction is shape, not subject: `gist: hooks.json gains Stop; tests green` is a state-of-play line, `- edited hooks.json - ran tests - committed abc123` is an action log; a commit hash never appears.
The `read:` note and the Scratchpoint's `files:` gist list overlap on purpose and differ in lifetime: the Scratchpoint line is current-state awareness that rolls into the next handoff, the chat-record note is the durable, chronological trace of when and why a file became salient.
Slash-command turns are captured as the raw invocation string (`/cdocs:propose-revise --first-round ...`), not the expanded skill body, which is short and exact; built-in `/compact` fires no `UserPromptSubmit` at all and is represented by the `compact-begin` line instead.

Header metadata, all optional after the timestamp: `n=<ordinal of this speaker's blocks in the file>`, `p=<first 8 hex of prompt_id>` (correlates a `@user` block with its `@<model>` entry and is what the `Stop` check keys on), `trigger=manual|auto` and `instructions="<custom_instructions>"` on `compact-begin`, `source=startup|resume|compact|clear` and `reason=` on `@session`.

Example (session and user lines are a composite of Phase-0 runs 2 and 4; the agent entries are illustrative, written as this proposal's own author would have noted that stretch of work; bodies abbreviated):

```
@session: 2026-09-22T18:24:38-07:00 start source=startup sid=9b824e82-4f57-44b8-8668-d0852f2f5f63 cwd=/tmp/.../proj4

@user: 2026-09-22T18:24:39-07:00 n=1 p=c76c22bb
Reply with exactly the word: alpha

@fable-5-1: 2026-09-22T18:24:40-07:00 p=c76c22bb
- query: `strings claude.exe | grep -E "PreCompact|PostCompact"` lists every hook event on 2.1.280; PostCompact exists
- read: plugins/cdocs/README.md "Sandbox testing notes": the credential-copy recipe every headless canary needs
- follow-up: interactive TUI /compact path unverified; check in a real session before Phase 1 ships

@session: 2026-09-22T18:24:40-07:00 compact-begin trigger=manual

@session: 2026-09-22T18:24:52-07:00 start source=compact

@user: 2026-09-22T18:24:53-07:00 n=2 p=ab2a3ea6
WITHOUT using any tools: list every string of the form MARKER_<WORD>_<DIGITS> ...

@fable-5-1: 2026-09-22T18:24:55-07:00 p=ab2a3ea6
- gist: both markers survived compaction (PreCompact additionalContext reaches the post-compact window)
```

The second agent entry is the minimal case: a turn that did one thing and has one line to say about it.
There is no entry-less turn; a turn with nothing more to say than its outcome still writes that outcome.

#### Hook contract: `plugins/cdocs/hooks/chat-record.sh`

One bash script with two entry modes: hook mode, dispatched by event name as its first argument and registered in `hooks.json` under five events; and `note` mode, invoked by the agent from `Bash` as `chat-record.sh note [--as <speaker>] <record-path> "<bullets>"`.
`note` appends a `@<model-short>` entry: header timestamp, `p=` from the current prompt id (stashed per session by `UserPromptSubmit` in `${XDG_RUNTIME_DIR:-/tmp}/cdocs-chat/<session_id>.prompt`; the session id is recovered from the record's first-line `sid=`), and the bullets as body after the escape pass.
The agent knows `<record-path>` because the hook announces it on every `SessionStart`, and the devlog's `## Chat Record` section repeats it.
Bash plus `jq`, not `tsx`: `UserPromptSubmit` and `Stop` run on the critical path of every turn and `npx tsx` startup is measurable, while the existing shell hooks show the pattern.

| Event | Matcher | Writes | Emits |
|---|---|---|---|
| `SessionStart` | (all) | `@session ... start source=<source>`; creates the file on first event | `additionalContext`, under 200 bytes, on every source: "Chat record for this session: `<path>` (source=<source>). Rules say what to do with it." |
| `UserPromptSubmit` | (all) | `@user` or `@harness` block with `p=`; stashes `prompt_id` in `<session_id>.prompt` | nothing (never `decision: block`) |
| `Stop` | (all) | nothing | if `stop_hook_active` is true: nothing. Else if the record has no `@<speaker>` block with `p=<pid8>` for a speaker other than `user`, `harness`, `session`: `{"decision":"block","reason":"<the block text below>"}`. Else nothing |
| `PreCompact` | `manual\|auto` | `@session ... compact-begin trigger=<trigger> instructions="<custom_instructions>"` (the `instructions=` key only when non-null) | nothing |
| `SessionEnd` | (all) | `@session ... end reason=<reason>`; removes `<session_id>.prompt` | nothing |

`Stop` block text (under 300 bytes):

> This turn has no chat-record entry. Append one gist bullet (what a successor should know from this turn; never an action log) with `chat-record.sh note --as <model> <record path> "- gist: ..."`, then finish.

Invariants:

- **`agent_id` guard, first thing on every event.** If the payload carries `agent_id`, exit 0 before any read or write.
  No Phase-1 event carries `agent_id` in practice (plain `Stop` fires only for the top-level agent with `agent_id: null`, run 5, and a subagent's turn end is `SubagentStop`, which is not registered), so the guard is defensive; it is also the documented statement that the chat record is top-level-only, and the Phase-3 sketch is where it is relaxed.
- **`stop_hook_active` guard, before any `Stop` decision.** A `Stop` with `stop_hook_active=true` is the agent's second stop after a block; the hook never blocks it, so a turn costs at most one extra short turn (run 8: three turns total) and can never loop.
  An agent that ignores the block and stops again without an entry simply ends the turn; the gap stands in the record and nothing retries.
- Always exit 0; a chat-record failure never blocks or slows the user.
  Errors go to stderr only.
  The only `decision: block` in the design is the `Stop` one-shot above, and it is suppressed whenever the hook cannot do its job: `CDOCS_CHAT_RECORD=off`, `jq` missing, no `cdocs/` under `cwd`, no record file for this session, or no `prompt_id` in the payload.
- No `cdocs/` directory under `cwd`, or `CDOCS_CHAT_RECORD=off`: exit silently before any write, mirroring `inject-rules.ts`.
- Appends use `>>` (`O_APPEND`) with the whole block written in one `printf`, so concurrent events (a `Stop` racing a `SessionEnd`) interleave at block granularity, not mid-line.
- `chat-record.sh` is the chat record's only write path.
  Two authors (the hook for user and session blocks; the agent for its own gist entries) share one append routine (a single `printf` under `>>`), so blocks never interleave mid-line and no `Edit`-style rewrite ever races an append.
  Agents read chat records (`tail`, `Read` with an offset) and never `Edit` or `Write` them; a cdocs subagent cannot even path-wise (`_chat/` is outside the edit-path allowlist), and the rule text says so for the main session.
- `last_assistant_message` is never written to the record and never read by the hook; `Stop`'s check is keyed on `prompt_id` and the presence of a `p=<pid8>` entry, nothing else.
- Only the top-level agent calls `note` in Phases 1 and 2; dispatched legs do not (their briefs say so), and Phase 3's per-workstream sketch is where leg chronology enters.
- The one runtime-dir file, `<session_id>.prompt`, holds the current `prompt_id` for `note`; it is overwritten on every `UserPromptSubmit`, removed on `SessionEnd`, and a stale one after a crash is harmless (the next prompt overwrites it).

**The per-turn rule and why a hook backs it.** The rule (Pillar 2 text, Phase-1 deliverable 5) is: before ending a turn, the agent appends at least one gist bullet via `note`.
The `Stop` block is the backstop for the turn the agent forgets, not the primary mechanism, and it is bounded on both sides: it fires at most once per turn (`stop_hook_active`), and it fires only when the record provably has no entry for this `prompt_id`, which the hook checks mechanically (`Stop.prompt_id` equals the turn's `UserPromptSubmit.prompt_id`, run 6).
It never inspects content, so it cannot coerce a particular bullet; the `gist:` category exists so that a compliant minimal bullet is always available and honest.
Even with the block ignored on every turn the record still carries verbatim user history and session markers, which is strictly more than today; agent entries are additive over that floor, and the block raises the floor rather than being the only thing holding the design up.

### Compaction guidance (rules, not hooks)

Compaction is a user action: an agent cannot invoke `/compact` ([#71803](https://github.com/anthropics/claude-code/issues/71803) is open), and the hooks around compaction (`PreCompact`, `SessionStart(compact)`, `PostCompact`) can only observe it.
So the guidance that makes compaction safe lives where it survives compaction: in `orchestration-discipline.md` Pillar 2, delivered unscoped by `/cdocs:init` and re-injected on every compaction per the reseed guarantee.
Pillar 2 gains two concrete steps.

**At a task-unit boundary** (after every 3 to 5 loop iterations, or when a judge returns, per the existing cadence) the overseer writes the handoff, refreshes the Scratchpoint, commits devlog and chat record by explicit path, and ends its turn by asking the user to run either:

```
/compact Preserve verbatim from cdocs/devlogs/<devlog>.md: the ## Scratchpoint block and the latest Completed / Decisions Made / Open Todos handoff. Keep the paths cdocs/devlogs/<devlog>.md and cdocs/_chat/<record>.md and the last three user turns verbatim. Drop tool outputs and file contents; they are re-readable.
```

or `/clear`, when the handoff is complete enough that no summary is needed (the Phase-2 A/B's third arm decides which the Phase-3 `/cdocs:compact` skill prints by default).
The `custom_instructions` field arrives in the `PreCompact` payload (verified, Phase 0), so the `compact-begin` marker records the steering text used, which makes steering discipline auditable from the chat record.

**After any compaction or clear** (the agent can tell: the window opens on a summary or on nothing, and the `SessionStart` announcement names `source=compact|clear`), before doing anything else: read `## Scratchpoint` and the latest handoff in the devlog, then the last five blocks of the chat record; do not re-derive state from the summary.
The devlog is found from the announced record path (`grep -l '<record path>' cdocs/devlogs/*.md`), the record path having been written into the devlog's `## Chat Record` section on the session's first turn; if the grep misses (no devlog yet), the agent creates or resumes one per the devlog convention and writes the pointer.

**Why `SessionStart(compact)` keeps a one-line announcement and nothing more.** Rules carry the instructions, but rules cannot carry the chat-record path: it derives from `session_id`, which only the hook has, and the post-compaction window is exactly where the agent must not trust the summary to have kept it.
The announcement is the same code path as the startup one (one `additionalContext` line, under 200 bytes, naming the path and the source), so keeping it costs nothing and no per-source logic exists.
Evidence that this split is sufficient: `SessionStart(compact)` `additionalContext` is visible to the model after compaction (Phase-0 runs 2 and 4), and unscoped rules re-inject on both compaction paths (Pillar 2, verified against the context-window docs).
What was dropped and why: the three-tier active-devlog resolution needed `PostToolUse` state and could cross sessions at its mtime tier; the grep recipe is per-session by construction and needs no state.

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
- since_handoff: Stop.prompt_id matches UserPromptSubmit.prompt_id (run 6); SessionStart(startup) has no model field
- open: interactive /compact check (#13572); /clear and /resume effect on session_id
- next: run interactive canary, then commit hooks.json entry
- files:
  - plugins/cdocs/hooks/hooks.json (rw): only three events wired today; SessionStart entry is the template for the new ones
  - plugins/cdocs/hooks/inject-rules.ts (r): the additionalContext emit shape and silent-exit guards to copy
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

The index devlog also carries a two-line `## Chat Record` section: the path the hook announced (which is also the `<record-path>` argument the agent passes to `note`, and the string the post-compaction grep recovers the devlog by), and the `@user` ordinal at the last handoff (so a resuming reader knows which tail to read).

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
| [-phase1-hooks](2026-09-22-chat-record-devlog-management-phase1-hooks.md) | chat-record.sh and hooks.json | done | you are touching the hook script or its tests |
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
3. **One file per session at `cdocs/_chat/`.** The only key the hook has is `session_id`; sessions are the compaction unit; `_`-prefix marks a mechanical asset outside the typed-document directories, so no frontmatter and no validation or edit-path changes.
4. **One append path for the chat record; agent-only writer for the devlog.** Single-writer ownership (Pillar 1b) applied to artifacts: the chat record has two authors (hook and agent) but exactly one write routine, `chat-record.sh`'s `>>` append, so nothing ever `Edit`-rewrites the file under a racing append.
   This is why the Scratchpoint lives in the devlog (a file the agent rewrites freely), not in the chat record.
5. **Scratchpoint is replace-in-place.** History is the chat record's job; the scratchpoint is a bounded "current state" block so the devlog does not grow per turn.
   It generalizes the thinness-column pattern, keeps the columns, and changes only the storage shape.
6. **Semantic split, flat naming, root as index, `part_of` link.** A byte-count cut produces chunks that are meaningless to navigate; a closed concern is a unit someone will actually want to read alone.
   Flat naming keeps every existing path assumption intact; the `read this when` column replaces a directory hierarchy.
7. **Compaction is guided by rules; hooks only mark it.** Maintainer decision (2026-10-05): the handoff-then-ask step and the post-compaction re-read belong in Pillar 2, which `/cdocs:init` materializes unscoped and the platform re-injects on every compaction, so no hook has to carry instructions across the boundary.
   `PreCompact` writes a `compact-begin` marker because `custom_instructions` is free and audits steering; `PostCompact` is not registered because the summary is the artifact the design distrusts, costs 7-9KB per auto-compaction in git, and is the content a resuming agent is told to ignore; `SessionStart(compact)` emits the same one-line path announcement as every other source because the path is the one fact rules cannot carry (see "Compaction guidance").
   The interactive TUI `/compact` path remains unverified by the canary; the only hook that observes it is the marker, so an unfired `PreCompact` costs an audit line, never state.
8. **Bash plus `jq`, not `tsx`.** `UserPromptSubmit` and `Stop` run on every turn; `npx tsx` startup is measurable latency on the interactive path, and two of the three existing hooks are already shell.
9. **Committed by default, no redaction, explicit-path staging.** Untracked durable state does not cross worktrees or sessions.
   The two leak channels (pastes, assistant bodies) are named in the `WARN` and accepted by maintainer decision; redaction is a separate workstream ([`2026-09-23-chat-record-redaction-scanning-rfp.md`](2026-09-23-chat-record-redaction-scanning-rfp.md)).
   The always-dirty tree is handled by protocol (overseer stages by explicit path at handoff; dispatched agents never stage `_chat/`), not by gitignoring.
10. **One gist bullet per turn, agent-written, backed by a one-shot `Stop` block.** Maintainer decision (2026-10-05): every top-level turn has something a successor should know, if only its outcome, so a turn with no entry is a lapse, not a correct silence; the `gist:` category exists so the minimal honest bullet is always available.
    The bullet is still a gist, not an action log: the never-list bans the shape (enumerating commits, edits, tests, tool calls, replies), and a commit record is never written.
    A hook can only capture raw text, and raw text is the wrong shape for orientation, so content stays agent-authored; the hook checks presence by `prompt_id`, never content, blocks at most once per turn, and is suppressed whenever it cannot locate the record.
    Floor: with every block ignored, the record still carries verbatim user history and session markers, so a lapsing agent degrades the record gradually rather than zeroing it.
    (Reverses round 4's "silence is usually correct" and five-quiet-turn advisory, which rested on the premise that most turns have no gist; round 5 rejects that premise. Round 1's verbatim capture and round 3's bullet-per-action remain rejected; see the NOTE in the Summary.)
11. **The gist log is agent-authored only and claims only awareness.** Maintainer decision (2026-10-05): no `PostToolUse` hook; the agent's `read:` notes and Scratchpoint `files:` gists know relevance and can forget a file, and the raw transcript remains the exhaustive fallback, per the devlog-value report's recommendation 5.
    A mechanical `files=` list was free but relevance-blind, pulled in a tool matcher with unverified members (`NotebookEdit`, `Bash`, `Agent`), and was the only reason the hook needed per-turn state; the file-awareness value the redundancy-check report found cheap is delivered by the judgment half alone.
    The token-cost half (content reuse without a re-read) is out of scope and unclaimed; the read-source report's transcript-granularity re-read measurement is the instrument to re-run after Phase 2 if anyone wants to check that the 97.4% figure moves (the report predicts it will not, materially).
12. **`SessionEnd` is kept as a bookend.** It writes one `@session ... end reason=` line and removes the runtime-dir prompt file.
    Dropping it would lose only the ability to tell a clean exit from a crash when reading a record; it carries no semantic content and never emits.

## Edge Cases / Challenging Scenarios

- **Harness-generated prompts fire `UserPromptSubmit`.** Canary run 5 showed a background subagent's completion notification arrived as a second `UserPromptSubmit` with no human input; its prompt begins `<task-notification>` / `<task-id>...` (see the loop devlog's `-canary` chunk).
  The payload has no field distinguishing it, so the hook classifies by shape: a prompt whose first non-blank token is an opening tag from a known harness set (`<task-notification`, `<system-reminder`, and whatever the Phase-1 implementer observes) is `@harness`; anything else, including a human pasting HTML, is `@user`.
  Allowlist, not "starts with `<`", to avoid mislabeling humans.
  A harness-prompted turn owes a bullet like any other, and the `Stop` check treats it identically: a leg's return is usually the most gist-worthy moment of the turn (`gist: reviewer r5 returned accept; next: merge`), and a notification that changed nothing still has a one-line state of play.
- **Pure-chat turns.** A turn with no tool use (an answer, a clarification) owes a bullet: the gist of the answer, so a successor reading the `@user` question is not left without the conclusion (`gist: explained Stop fires top-level only; no state change`).
- **Dispatch-only turns.** A turn that launches a background subagent and ends fires `Stop` (run 5); its bullet is the state of play, not the dispatch as an action: `gist: reviewer r5 in flight (background); nothing to do until it returns`.
- **Headless `-p` sessions.** `Stop` fires and the block is honored under `-p` (run 8 was a `-p` run), so the rule holds in AFK `oversee` and other headless uses at the cost of one extra short turn on any turn the agent forgets; the rule text makes that rare, and a one-shot headless invocation that is not a cdocs session should run with `CDOCS_CHAT_RECORD=off`.
- **`CDOCS_CHAT_RECORD=off`.** No file is created, no `.prompt` is written, `note` exits 0 with a stderr line, and `Stop` never blocks; the rule still asks for the bullet but nothing enforces it and nothing records it.
- **Slash commands.** A user-defined or plugin command fires `UserPromptSubmit` with the raw invocation string and is recorded as such; built-in `/compact` fires none (run 2) and is represented by `compact-begin`; `/clear` and `/resume` side effects on `UserPromptSubmit` and `session_id` are a Phase-1 verification item.
- **Body content that looks like a header.** A user pasting a chat record (whose very first line is `@user: ...`), or an assistant quoting one, is handled by the backslash escape; round-trip is a Phase-1 unit test with adversarial input (a prompt whose first line matches `HEADER_RE`, headers inside fences, lines starting with `\@`, empty bodies, a multi-line `instructions=` value, CRLF input).
- **Agent writes an entry, then keeps working in the same turn.** The convention is to note at the end of the turn; if `note` is called again for the same `p=`, a second entry is appended and the reader tolerates several per prompt.
  The `Stop` check is satisfied by the first.
- **The agent ignores the block.** The second `Stop` carries `stop_hook_active=true`, the hook stays silent, the turn ends with no entry; the gap is visible in the record (a `@user` with no following `@<model>` for its `p=`) and the Phase-1 real-session criterion counts such gaps.
- **`Stop` with no matching `@user`.** A turn whose prompt the hook never saw (hook enabled mid-session, or the first turn after `--resume` if the harness replays without `UserPromptSubmit`): the check finds no entry and blocks once; `note` then takes `p=` from `<session_id>.prompt` if present, else omits `p=`, and the next `Stop` is `stop_hook_active=true` and silent.
  Nothing loops, nothing is lost beyond the correlation key for that one turn.
- **User interrupts a turn.** Whether `Stop` fires on an interrupted turn is unverified; if it does not, no block occurs and the turn simply has no entry, which is correct for an abandoned turn.
- **`--resume` and `/clear`.** Resume keeps `session_id` and appends to the same file with a `@session ... start source=resume` line.
  `/clear` fires `SessionStart` with `source=clear`; whether the id changes is a Phase-1 verification item; either way the record is correct (same file continues, or a new one starts) and the announcement names whichever path applies.
- **Two sessions on one checkout.** Per-session files never collide, and the devlog is recovered by grepping for the session's own record path, so nothing cross-session exists to confuse; two sessions that both name the same devlog in `## Chat Record` are a single-writer violation the devlog convention already forbids.
- **Very large prompts.** Written verbatim; the file is read by tail and offset, never whole.
  No cap: truncation would defeat "lossless by construction".
- **Hook timeout or `jq` missing.** Timeout 5s on every entry; the script checks for `jq` and exits 0 silently without it, printing one stderr line; `Stop` never blocks in that state.
- **Not a cdocs project.** No `cdocs/` under `cwd`: silent exit, no directory created, no block.
- **Devlog with no closed concern at 20KB.** Do not split; tighten prose, move landed verification evidence into a `-verification` chunk via the standard split (a landed campaign is a closed concern even when the phase around it is not), and note in the Scratchpoint that a further split is pending the next phase close.
- **Chunk needed while a sub-loop's tables are still live.** Only rows for finished rounds move; the live table stays in the root with a one-line pointer to the chunk holding earlier rows.
- **OpenCode and other targets.** The hook is Claude-Code-only; `build-opencode.ts` does not port it (no equivalent event surface is assumed).
  Rule and skill text (per-turn bullet, scratchpoint, splitting, boundary steps) delivers to OpenCode via `/cdocs:init` unchanged; without the hook the per-turn bullet is rule-only, and where a target lacks `/compact`, Pillar 2's existing degradation ("start a fresh session from the handoff") also says "and the chat record if one exists".

## Test Plan

**Phase 1, hook tests (`plugins/cdocs/hooks/tests/chat-record.test.sh`):**

- Headless sandbox run per the README recipe (sandboxed `CLAUDE_CONFIG_DIR` with copied credentials, out-of-repo `cwd` containing an empty `cdocs/`, `--model haiku`, never `--bare`), asserting after each scenario on the produced `cdocs/_chat/*.md` and the `--include-hook-events` stream:
  - single prompt that instructs the model to read a file and then call `chat-record.sh note --as haiku-4-5 <record> "- read: a.txt: canary fixture"`: one `@session start`, one `@user` (verbatim prompt, `p=` set), one `@haiku-4-5` entry whose body is exactly `- read: a.txt: canary fixture` and whose `p=` matches the `@user` block, one `@session end`; exactly one `Stop` in the stream, with no `decision`.
  - single prompt that reads a file and is told not to call `note`: the first `Stop` `hook_response` carries `decision: block` with the reason text; the model then calls `note`; the second `Stop` has no `decision`; the record has exactly one `@<model>` entry with the turn's `p=`; `last_assistant_message` text appears nowhere in the record.
  - single prompt that forbids any tool use (so the model cannot comply): first `Stop` blocks, second `Stop` (`stop_hook_active=true`) is silent, the run ends with no `@<model>` entry and no third `Stop` (the never-loops property).
  - pure-chat prompt ("reply with the word ok, then note it"): one `@<model>` entry, one `Stop`, no block.
  - two stream-json prompts, each noted: two `@user` blocks with distinct `p=`, two entries whose `p=` match pairwise, no block.
  - `note` called twice in one turn: two entries with the same `p=`, no block.
  - `note` with no `--as`: speaker is `assistant`.
  - manual compaction via `--input-format stream-json` with a `/compact Keep X` message: `@session compact-begin trigger=manual instructions="Keep X"`, then `@session start source=compact`, no `@compact` block, no `@user` block for the `/compact` line, and the `SessionStart(compact)` `hook_response` carries the path announcement with `source=compact`.
  - auto compaction via `--autocompact 100000` and ~100K tokens of `Read`s: at least one `compact-begin trigger=auto` line with no `instructions=` key.
  - `Agent` dispatch: exactly one `@user` block (the subagent's prompt is absent), one entry, and no event in the stream for which the hook wrote anything with `agent_id` set.
  - a project command `.claude/commands/echo.md` invoked as `/echo hello-world`: one `@user` block whose body is exactly `/echo hello-world`.
  - `CDOCS_CHAT_RECORD=off`: no file created, and a prompt that is told not to `note` produces one `Stop` with no `decision`.
  - no `cdocs/` in `cwd`: no file created, no block.
  - `SessionEnd`: `@session ... end reason=<reason>` is the last line and `<session_id>.prompt` is gone from the runtime dir.
- Grammar unit test (pure shell, no Claude): escape/unescape round-trip on the adversarial fixture listed under Edge Cases (header-shaped first line, `@alice: hey`, LESS and CSS at-rules, headers inside fences, `\@` lines, empty body, multi-line `instructions=`, CRLF); a reader that splits on `HEADER_RE` recovers exactly the input bodies and metadata values.
- Payload-shape guard: each event's required fields (`prompt`, `prompt_id` on `UserPromptSubmit` and `Stop`, `stop_hook_active`, `trigger`, `custom_instructions`, `source`, `reason`) present, so a Claude Code upgrade that renames a field fails loudly in the test rather than silently in production; `prompt_id` equality between a turn's `UserPromptSubmit` and its `Stop` is asserted explicitly.

**Phase 1, interactive check (manual, once, recorded in the devlog with the resulting chat-record excerpt):** in a real interactive session with the plugin installed, (a) type `/compact` and confirm the `compact-begin` and `start source=compact` lines appear and the path announcement is visible (the [#13572](https://github.com/anthropics/claude-code/issues/13572) check the headless canary could not perform); (b) end a turn without noting and confirm the block reason is shown and the agent recovers in one extra turn; (c) run `/clear` and `--resume` and record their effect on `session_id` and the record file.

**Phase 1, rules check:** after the Pillar 2 text lands, a sandboxed session with the rules materialized by `/cdocs:init` is compacted mid-task; the post-compaction turn's first tool calls must be reads of the devlog's Scratchpoint and the chat-record tail (asserted from the stream), with no hook other than the path announcement having emitted `additionalContext`.

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
# canary.sh <Event>: append {"event","at","stdin"} to $CANARY_LOG; optionally emit additionalContext.
EV="$1"; IN="$(cat)"
printf '{"event":"%s","at":"%s","stdin":%s}\n' "$EV" "$(date -Is)" \
  "$(printf '%s' "$IN" | jq -c .)" >> "$CANARY_LOG"
exit 0
```

```bash
# Sandbox: fresh CLAUDE_CONFIG_DIR with settings.json wiring canary.sh to every event under test,
# plus copies of ~/.claude/.credentials.json and ~/.claude/.claude.json (README "Sandbox testing notes").
cd "$SANDBOX/proj" && CLAUDE_CONFIG_DIR="$SANDBOX/cfg" claude -p "<prompt>" --model haiku \
  --output-format stream-json --verbose --include-hook-events > out.jsonl
# manual compaction: --input-format stream-json with a {"type":"user",...,"content":"/compact"} line
# auto compaction:   --autocompact 100000 --permission-mode bypassPermissions and ~100K tokens of Reads
```

Two independent evidence channels, and they disagree in one useful way: the `--include-hook-events` stream emitted `hook_started`/`hook_response` for `SessionStart`, `UserPromptSubmit`, and `Stop` but not for `PreCompact`, even though the canary log proves it ran.
The canary log is the ground truth for the `compact-begin` marker; the stream's `compact_boundary` system message (`pre_tokens`, `post_tokens`, `trigger`) corroborates that a compaction happened, and the stream is the ground truth for the `Stop` block (run 8: `decision` visible in `hook_response`, and the `num_turns` count shows the one-turn cost).

For the rules-driven post-compaction behavior, the instrument is the stream itself: the tool calls the model makes in the first post-compaction turn are the evidence that the rules, not a hook, directed the re-read.
For the scratchpoint and splitting, verification is the A/B and the split dry-run above, both scored by a fresh agent, never by the author.

## Implementation Phases

### Phase 0: hook canary (done in this environment, 2026-09-22 and 2026-09-23, Claude Code 2.1.280)

Prerequisite the brief required before Phase 1: confirm the hooks this design needs actually fire and behave, given three separate hook gaps surfaced in one session (`PostToolUse updatedToolOutput` and `PreToolUse updatedInput` dead for built-in Bash, and the then-open [#13572](https://github.com/anthropics/claude-code/issues/13572)).
Eight headless runs in a sandboxed `CLAUDE_CONFIG_DIR` with `--model haiku`; per-run `settings.json`, exact commands, stream-json inputs, canary-log lines, and model results are in the loop devlog's `-canary` chunk, [`2026-09-22-chat-record-devlog-management-propose-revise-canary.md`](../devlogs/2026-09-22-chat-record-devlog-management-propose-revise-canary.md), and the round-1 review independently re-derived every row and added two runs of its own ([`2026-09-22-review-of-chat-record-devlog-management.md`](../reviews/2026-09-22-review-of-chat-record-devlog-management.md), "Independent Verification").
Rows this design relies on:

| Hook | How triggered | Fired | Payload facts relied on |
|---|---|---|---|
| `SessionStart` (startup) | `claude -p` | yes | `session_id`, `cwd`, `source=startup`; no `model`; `additionalContext` reaches the model |
| `SessionStart` (compact) | both compaction paths | yes, between `PreCompact` and `PostCompact` | `source=compact`; `additionalContext` visible to the model after compaction |
| `UserPromptSubmit` | `claude -p "<prompt>"` | yes | `prompt` verbatim, `prompt_id`, `session_id` |
| `UserPromptSubmit` inside a dispatched subagent | `Agent` tool dispatch | **no** (only the main-thread prompt fired) | scoping to the top-level session is mechanical |
| `UserPromptSubmit` on a background-subagent completion | background `Agent` | yes, a second firing with no human input | motivates the `@harness` speaker |
| `UserPromptSubmit` on a user-defined slash command | review Run B: `claude -p "/echo hello-world"` | yes | `prompt` is the raw invocation string, not the expanded body |
| `Stop` | turn end, including a turn that only launched a background subagent | yes, top-level only (`agent_id: null`) | `prompt_id` equal to the turn's `UserPromptSubmit.prompt_id` (run 6), `stop_hook_active`; `last_assistant_message` present but unused |
| `Stop` returning `decision: block` once | run 8 (2026-09-23): hook blocks while `stop_hook_active=false` and a marker file is absent | yes: the agent ran the requested command, a second `Stop` fired with `stop_hook_active=true`, the hook stayed silent, three turns total | the per-turn check: available, bounded, honored headless under `-p` |
| `PreCompact` (manual) | `/compact` via `--input-format stream-json` | yes | `trigger=manual`, `custom_instructions` (null when unsteered); [#13572](https://github.com/anthropics/claude-code/issues/13572) did not reproduce headless |
| `PreCompact` (auto) | `--autocompact 100000`, ~72K `pre_tokens` | yes, four times in one run | `trigger=auto` |
| `SessionEnd` | process exit | yes | `reason` |

Also verified but not relied on by this design: `PostToolUse` fires once per `Read`/`Edit` call with `tool_input.file_path`, and inside dispatched subagents with `agent_id` and `agent_type` set (review Run A); `SubagentStart`/`SubagentStop` fire with `agent_id`, `agent_type`, and (on stop) `agent_transcript_path` and `last_assistant_message`; `PostCompact` fires on both compaction paths with `trigger` and the full `compact_summary`.
The Phase-3 sketch is the only consumer of those rows.

Result: **confirmed working** for every hook Phase 1 uses.
Built-in `/compact` sent as a user line fired no `UserPromptSubmit` but consumed a `prompt_id` (run 2).
Not verified: the interactive TUI `/compact` path, behavior of `/clear` and `/resume` on `session_id` and `UserPromptSubmit`, and whether `Stop` fires on a user-interrupted turn (all Phase-1 manual checks).

### Phase 1: capture, per-turn rule, compaction guidance

Deliverables:

1. `plugins/cdocs/hooks/chat-record.sh` implementing the hook contract above (`agent_id` guard first, `stop_hook_active` guard before any `Stop` decision) plus the `note` entry mode; `hooks.json` entries for `SessionStart`, `UserPromptSubmit`, `Stop`, `PreCompact` (matcher `manual|auto`), `SessionEnd` (timeouts 5s); the single per-session `<session_id>.prompt` file in the runtime dir.
2. `plugins/cdocs/hooks/tests/chat-record.test.sh` per the Test Plan, plus the grammar round-trip fixture.
3. `/cdocs:init` scaffolds `cdocs/_chat/` with a one-paragraph `README.md` (what it is, hook-written, do not edit, opt-outs).
4. `frontmatter-spec.md`: one line under "Media" noting `cdocs/_chat/` as hook-written, frontmatter-free, like `_media/`; `plugins/cdocs/README.md` "Hooks" gains the five entries, the `Stop` block semantics, and the opt-outs.
5. `orchestration-discipline.md` Pillar 2, in this order: the per-turn gist rule (before ending any turn, append at least one bullet with `chat-record.sh note --as <model> <record> "- gist|query|read|follow-up: ..."`; one line of what a successor should know, never an action log, never a commit record; the `Stop` hook blocks once if forgotten); the `## Chat Record` pointer the agent writes into its devlog on the first turn; the task-unit-boundary step (handoff, Scratchpoint, commit devlog and chat record by explicit path, then ask the user for `/compact <steering>` or `/clear`, with the steering string and who types it); the post-compaction step (re-read Scratchpoint, latest handoff, last five chat-record blocks; recover the devlog by `grep -l '<record path>' cdocs/devlogs/*.md`; never re-derive state from the summary); the commit protocol and Pillar 1 carve-out sentence; and the rule that agents never `Edit` or `Write` `cdocs/_chat/`.
6. `plugins/cdocs/skills/devlog/SKILL.md`: `## Chat Record` pointer section with the `note` command and the four categories; chat records are quoted only inside fences; the `## Verification` section is the evidence home, split as a standard chunk when large.
7. Interactive checks (a)-(c) from the Test Plan and the rules check, recorded in the devlog.
8. Mark `2026-09-01-devlog-autoflush-hook.md` `status: evolved` with a pointer here.

Success criteria: all hook tests green, including the block-and-recover, never-loops, dispatch, slash-command, and opt-out scenarios; a real session in this repo produces a committed `cdocs/_chat/` file whose `@user` blocks match what was typed, in which every `@user`/`@harness` block is followed by at least one `@<model>` entry with the matching `p=` (zero gaps over a session of at least twenty turns), whose entries are gist bullets in the named categories with no reply text, no commit hashes, and no action lists; the interactive check shows the `compact-begin` line, the path announcement, and a block recovered in one turn; the rules check shows the post-compaction re-read driven by rules alone.

Constraints: do not touch `inject-rules.ts`, `validate-cdocs-edit-path.sh`, or `cdocs-validate-frontmatter.sh`; do not add `_chat/` to either path regex; do not register `PostToolUse`, `PostCompact`, `SubagentStart`, or `SubagentStop`; the only `decision: block` is the `Stop` one-shot, and it must be unreachable when `stop_hook_active` is true.

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
3. **Per-workstream chat record (design sketch, not built here).** Maintainer direction (2026-09-23): nested chat records will be wanted soon, scoped per workstream, one record for the set of proposer, reviewer, and implementer legs working the same `task_list`, not one per subagent, because the point is context preservation for a workstream.
   The sketch below uses only mechanics Phase 1 ships or the canary verified; the gating items are at the end.

   *Scoping unit and key.* The key is `task_list`, read from the frontmatter of the devlog that names this session's record path (the same `grep -l '<record path>' cdocs/devlogs/*.md` the post-compaction rule uses), so a session learns its workstream once the agent has written the `## Chat Record` pointer.
   Nothing new is written by an agent; the hook remains the only mechanical writer.

   *File layout: derive the workstream record, do not relocate files.* A session's file stays `cdocs/_chat/YYYY-MM-DD-<sid8>.md` (moving it after the key is learned would break the glob lookup and any devlog pointer already written).
   When the hook first learns the workstream it appends `@session: <ts> workstream ws=<task_list>`; the workstream record is then the ordered set `grep -l 'ws=<task_list>' cdocs/_chat/*.md`, which also covers a workstream resumed the next day in a new session, and it merges cleanly across worktrees because each session's file is distinct.
   A `cdocs/_chat/<task_list-slug>/` directory per workstream was considered and rejected for the relocation reason; `_chat/` is a mechanical asset directory, so the flat-naming argument from devlogs is not what decides this, the glob stability is.

   *Who writes the legs' blocks, and when.* Dispatched legs' events arrive in the parent session's hook process carrying the parent's `session_id` plus `agent_id`/`agent_type`, so the parent session's file is the natural home for their chronology and there is still exactly one writer.
   Phase 3 would register `SubagentStart` and `SubagentStop` and relax the `agent_id` guard to a `case` on the event: `SubagentStart` appends `@dispatch: <ts> agent=<agent_type>/<agent_id8>` with the dispatch prompt as body; `SubagentStop` appends `@return: <ts> agent=<agent_type>/<agent_id8>` with `last_assistant_message` as body.
   This is the one place a hook-captured message is proposed as content, and only because a leg's return is by contract its summary to the overseer (the `iterate` skill's "summary absorption" boundary), already compact; a leg whose return is not compact is a brief problem to fix at dispatch, and the Phase-3 design should re-examine whether legs should instead call `note --agent` themselves, consistent with the top-level per-turn rule.
   No per-leg file list is captured (Decision 11 applies to legs as to the top level); a leg's salient files are in its return summary if they mattered.
   Sourcing the `@dispatch` body is the unsettled step: `PreToolUse` on the `Agent` tool would carry the brief as `tool_input.prompt` but no `agent_id`, while `SubagentStart` carries `agent_id` but (per run 5's key list) neither the prompt nor `agent_transcript_path`, which only `SubagentStop` delivers.
   So either the prompt is correlated from `PreToolUse` to the next `SubagentStart` (by dispatch ordering or a shared tool-use id, unspecified until canaried), or the `@dispatch` block is written lazily at `SubagentStop` time from the transcript's first user message, with `PreToolUse` as an optimization; gating canary (c) decides.

   *What this adds beyond the Scratchpoint.* Chronology only: which briefs were dispatched in which order and what each returned.
   The state half for durable specialists is already the Scratchpoint in the devlog they own; one-shot legs need nothing more than their `@dispatch`/`@return` pair, which is exactly the Dispatch/Return Events table's content captured mechanically rather than by the overseer's hand.

   *Gating and the Phase-3 canary.* (a) Phase 1's `agent_id` guard and the `## Chat Record` pointer convention landed (the key resolution depends on the pointer); (b) a canary confirming that a durable specialist resumed by `SendMessage` fires a fresh `SubagentStart`/`SubagentStop` pair with the same `agent_id` (unverified; if it does not, the specialist's later turns need a different anchor); (c) `PreToolUse` on the `Agent` tool delivering `tool_input.prompt` in the parent, and how that prompt is correlated to the later `SubagentStart`'s `agent_id` given that `SubagentStart` carries neither the prompt nor `agent_transcript_path` (unverified; the answer picks between eager correlation and lazy write-at-`SubagentStop`); (d) evidence that workstreams actually span enough legs and sessions to need the derived record, which the Phase-1 records themselves will show.

Success criteria: a specialist reseeded at the cutoff continues without re-reading files its predecessor already read (measured by the reviewer on the next round); `/cdocs:compact` followed by the printed line produces a post-compaction or post-clear turn that acts on `next` from the Scratchpoint without re-orientation; the per-workstream sketch's canary items (b) and (c) have answers recorded before any implementation of item 3 begins.
