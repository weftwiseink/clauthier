# `bin/chat-record`

> BLUF: `chat-record` is one POSIX shell script with two faces: a pair of hooks
> (`UserPromptSubmit`, `Stop`) that write human prompts and turn sign-offs automatically,
> and two agent subcommands (`note`, `path`) the top-level agent calls itself to log a
> gist bullet and to find the record's path.
> It writes one append-only file per Claude Code session at
> `cdocs/_chat/YYYY-MM-DD-<session_id>.md`, never edits an existing line, and is
> top-level-session only: subagents must not call it.
> Full design rationale lives in
> [`cdocs/proposals/2026-09-22-chat-record-devlog-management.md`](../../../cdocs/proposals/2026-09-22-chat-record-devlog-management.md);
> this file documents the shipped script's behavior.

## What it is for, and who writes what

The chat record is a per-session durable log a cold agent (post-compaction, or a fresh
session resuming someone else's work) can read to reconstruct what happened, without
trusting a lossy compaction summary.
Three kinds of line land in the file, from two different writers:

| Marker | Written by | When | Content |
|---|---|---|---|
| `@user: <time>` | `UserPromptSubmit` hook | every human-submitted prompt | the prompt, verbatim (escaped if it would look like a marker) |
| `@<model>: <time>` | the agent, via `chat-record note` | whenever the agent chooses to | one or more gist bullets, free text |
| `-- <token> at <time>` | `Stop` hook | end of every turn that has at least one `@user` or `@<model>` line since the last sign-off | nothing (it is a boundary marker, not a speaker) |

The hooks never ask the agent anything and never block except in one case (see "The Stop
block" below): they write facts (what the human typed, when a turn ended) that the agent
cannot be trusted to transcribe faithfully.
The agent is responsible for the one thing a hook cannot write: a short note of what the
turn actually concluded, decided, or changed.
Harness-generated `UserPromptSubmit` events (a background task's completion notice, an
injected `<system-reminder>`) are not human input: the hook skips any prompt whose first
non-blank text starts with a known harness tag (`<task-notification`, `<system-reminder`),
so no `@user` line and no `Stop` obligation follow from them.

## Usage

### `chat-record note [--as <speaker>]`

Appends `@<speaker>: <timestamp>` followed by the note body, read from stdin, to the
current session's record.
Always use a quoted heredoc so the shell performs no expansion on the body:

```bash
chat-record note --as opus-5-5 <<'EOF'
- gist: reviewer r5 returned revise on two blockers
EOF
```

- `--as <speaker>` (default `assistant`): the model id, normalized by `short_id`
  (lowercased; drops a leading `claude` prefix, a trailing `[...]` suffix, and a trailing
  `-YYYYMMDD` date; dots to dashes), so `Claude Opus 4.6`, `claude-opus-4-6-20251101`, and
  `opus-4-6 [1m]` all normalize to `opus-4-6`.
  Must match `^[a-z0-9][a-z0-9._-]*$` and must not be `user` (reserved for the hook);
  otherwise rejected and nothing is written.
- The body must be non-empty and must come from stdin; the script refuses to run
  interactively (`[ -t 0 ]`) so a forgotten heredoc fails loudly instead of hanging.
- Exits non-zero with a one-line `chat-record: <reason>` on stderr for every failure:
  missing `CLAUDE_CODE_SESSION_ID`, no `cdocs/_chat/` found, bad `--as`, empty body, `jq`
  or `git` missing, or a write failure.

### `chat-record path`

Prints the current session's record path, relative to the git toplevel (the form a
devlog's `chat_record:` list takes), and creates nothing:

```console
$ chat-record path
cdocs/_chat/2026-10-07-7f3a9c21-88e4-4b0a-9d31-1234567890ab.md
```

Takes no arguments; fails the same way `note` does (missing session id, no `cdocs/_chat/`,
etc.) with a non-zero exit and one line on stderr.

### `chat-record UserPromptSubmit` / `chat-record Stop`

Hook-only modes, wired in [`hooks.json`](../hooks/hooks.json), never called directly by an
agent.
They read the hook's JSON payload from stdin, always exit 0, and write diagnostics to
stderr only, so a config problem never surfaces as a blocked turn or model-visible output
(stdout from `UserPromptSubmit` is folded into the model's context, so this mode stays
silent even on error).
`Stop` is the one case that writes to stdout: a `{"decision":"block","reason":"..."}` JSON
line, described below.
Any other first argument prints `usage: chat-record note [--as <model>] <<'EOF' ... EOF |
chat-record path` to stderr and exits 2.

### Locating the record

Both hook and agent modes resolve the same way, from the hook's `cwd` field, the agent's
`$PWD` for `note`/`path`, or `CLAUDE_CODE_SESSION_ID` (an undocumented Claude Code env var,
equal to the hook payload's `session_id`) for the session id:

1. Find the git toplevel (`git rev-parse --show-toplevel`); outside a git work tree,
   nothing activates.
2. Walk up from the starting directory toward that toplevel, stopping at the first `cdocs/`
   directory found (inclusive of the toplevel itself).
3. That directory must contain `cdocs/_chat/` (created by `/cdocs:init`, not
   `--minimal`); if it doesn't, nothing activates.
4. The record file is the earliest-dated `cdocs/_chat/*-<session_id>.md` match, or, if none
   exists yet, `cdocs/_chat/<today>-<session_id>.md` (created lazily on first write).

Because lookup is by glob on the session id rather than by recomputing today's date, a
session resumed on a later day (`--resume`, `--continue`, after `/compact`) keeps
appending to the same file; `/clear` and `--resume <id> --fork-session` mint a new session
id and start a new record.

A hook payload carrying `agent_id` (i.e. a subagent, not the top level) is ignored
unconditionally in both hook modes.
`note` and `path` have no such guard: a subagent's Bash environment is identical to the
top level's (same `CLAUDE_CODE_SESSION_ID`), so a subagent calling `note` would silently
land its note in the top-level record.
**This is why subagents must never call `chat-record`** (stated in the rules, not enforced
by the script).
`CDOCS_CHAT_RECORD=off` disables every mode (hooks silently exit 0, `note`/`path` silently
exit 0): useful for a one-shot non-cdocs `claude -p` invocation.

### The `Stop` block

`Stop` looks at the record's last marker line and decides:

| Last marker | Writes | May block |
|---|---|---|
| an `@<model>` note | sign-off | no |
| `@user`, first `Stop` this turn, not plan mode | nothing | yes, once |
| `@user`, `stop_hook_active` (a second `Stop` after a block) or plan mode | sign-off | no |
| a sign-off, or no marker at all | nothing | no |

The block is a one-shot nudge, not a hard gate: a second `Stop` on the same turn
(`stop_hook_active: true`) always signs off without blocking again, and plan mode (no
writes allowed) never blocks.
A real block, captured from a live run:

```json
{"decision":"block","reason":"No chat-record entry for this turn (record: cdocs/_chat/2026-10-07-7f3a9c21-88e4-4b0a-9d31-1234567890ab.md). Run, then finish:\nchat-record note --as <your model id> <<'EOF'\n- gist: <what a successor should know from this turn>\nEOF"}
```

`<your model id>` is literal text for the agent to fill in; the script fills in only the
record's own path.

## What the resulting file looks like

Path: `cdocs/_chat/YYYY-MM-DD-<session_id>.md`, full session id, dated by the first
prompt recorded, one file per Claude Code session.
It is a plain-text append log, no frontmatter (it is a mechanical asset directory like
`cdocs/_media/`, exempt from cdocs frontmatter validation).

Annotated example, produced by actually running the script end to end in a scratch repo
(two turns: one noted, one left unnoted to show the block, then closed out):

```
@user: 2026-10-07T12:33:06-07:00
Can you add a README for chat-record?

@opus-5-5: 2026-10-07T12:33:06-07:00
- gist: drafting bin/README.md for chat-record; read script, hooks.json, proposal

-- 7f3a9c21 at 2026-10-07T12:33:06-07:00

@user: 2026-10-07T12:33:20-07:00
second prompt, no note will follow

@opus-5-5: 2026-10-07T12:33:28-07:00
- gist: closed out the turn

-- 7f3a9c21 at 2026-10-07T12:33:28-07:00
```

Reading it: each turn is `@user: <time>` + the prompt body, then zero or more
`@<model>: <time>` + note-body blocks, closed by one `-- <token> at <time>` sign-off.
Entries simply accumulate; nothing is ever rewritten in place, so the file is safe to
append to concurrently (each write is a single `printf >>`) and merges cleanly across
worktrees (`/cdocs:init` scaffolds `cdocs/_chat/.gitattributes` with `*.md merge=union`).
A line in a note body that would otherwise look like a marker (starts with `@word:` or
`-- token at <timestamp>`) is escaped with a leading backslash on write and unescaped
nowhere: readers just see the backslash, which is the accepted tradeoff for a one-pass
grammar.

The `-- <token> at <time>` sign-off token is a session title, not a model name: the last
`custom-title` entry in the transcript (set by `/rename`), sanitized to
`[A-Za-z0-9._-]`, or the first 8 hex characters of the session id if there is no title or
the transcript is unreadable.
There is no separate "compaction" or "session end" marker: `/compact`, `--resume`, and
`--continue` keep the same session id, so the record looks the same across them; only a
new session id (`/clear`, `--resume ... --fork-session`) starts a new file.

## Ties to devlogs

A devlog records which sessions worked on it in an optional `chat_record:` frontmatter
list of repo-root-relative paths:

```yaml
chat_record:
  - cdocs/_chat/2026-10-05-3f2a9c1e-....md
```

The first turn a session works on a devlog, append that session's `chat-record path`
output to the list if not already present.
After a compaction, or when picking up a session cold, run `chat-record path`, then read
the `## Scratchpoint` and latest handoff of every devlog that lists that path (newest
`as_of` first), then `tail -n 80` of the record itself, before trusting any summary.
If no devlog lists the path, the record's tail is the session's whole durable state.

Commit the record by explicit path alongside the devlog it belongs to
(`git add cdocs/_chat/<file> cdocs/devlogs/<file>`), never `git add -A` or `commit -a`.
**Never hand-edit a file under `cdocs/_chat/`**: it is a mechanical append log, and editing
it defeats the point of a verbatim record.
Records commit by default with no redaction: a secret pasted into a prompt or echoed into
a note is committed with it; the only opt-outs are `CDOCS_CHAT_RECORD=off` and gitignoring
`cdocs/_chat/` (which trades away cross-worktree durability).

## Troubleshooting

- **`no cdocs/_chat/ between <dir> and the git toplevel (run /cdocs:init)`**: the project
  hasn't opted in. Run `/cdocs:init` (not `--minimal`), which scaffolds `cdocs/_chat/`
  and the rule text together.
- **`CLAUDE_CODE_SESSION_ID is unset (Claude Code top-level session only)`**: a subagent
  called `note`/`path` directly (don't), or the script ran outside a live session.
- **A hook silently writes nothing, no error anywhere**: by design. Hook modes always
  exit 0 and never print to stdout; check stderr, or check the silent-exit conditions:
  `CDOCS_CHAT_RECORD=off`, no `jq`/`git` on `PATH`, no activation (see above), a payload
  carrying `agent_id`, or (for `Stop`) no record file yet exists for this session.
- **`note` hangs instead of returning**: the body wasn't piped or heredoc'd. Interactive
  stdin should instead hit the `[ -t 0 ]` guard and exit non-zero with
  `note body goes on stdin: ...`; a true hang means something else is holding stdin open.
- **`note` is denied, or prompts every turn, in a non-bypass session**: default permission
  mode treats it as an unallowlisted Bash command. Add `Bash(chat-record:*)` to the
  allowlist, or pass it via `--allowedTools`.
- **The `Stop` block reappears every turn**: expected when notes are skipped turn after
  turn, not a bug; the second `Stop` (`stop_hook_active`) always signs off silently.
- **Two copies of every line**: a doubled hook registration, e.g. running
  `--plugin-dir plugins/cdocs` alongside an already-enabled `cdocs@clauthier` install.
  Disable one.

## Tests

`plugins/cdocs/hooks/tests/chat-record.test.sh --unit` runs the pure-shell suite (CI);
`--headless` runs sandboxed `claude -p` scenarios against real credentials.
See [`../README.md`](../README.md) "Sandbox testing notes" for the sandbox recipe.
