# `bin/`

> BLUF: Runtime commands Claude Code puts on the Bash tool's `PATH` while the plugin is enabled.
> OpenCode ships neither.

## `chat-record`

> BLUF: Hooks write human prompts and turn sign-offs automatically.
> The agent adds judgment with `chat-record note`.
> The result is one append-only file per session at `cdocs/_chat/YYYY-MM-DD-<session_id>.md`.

### What it does

- `UserPromptSubmit` hook appends `@user: <time>` plus the prompt, verbatim.
- `Stop` hook appends a `-- <token> at <time>` sign-off.
- `Stop` blocks once, instead, if a human-initiated turn has no agent note yet.
- The agent runs `chat-record note --as <model>` to append its own `@<model>: <time>` bullet.
- It is top-level-session only (keyed on `CLAUDE_CODE_SESSION_ID`): subagents must never call it.
- The record lives in `cdocs/_chat/`, found by walking up from the working directory to the git toplevel; `/cdocs:init` creates it.

### Commands

- `chat-record note [--as <speaker>]`: append a note; body on stdin via a quoted heredoc.
- `chat-record path`: print the record's path, relative to the git toplevel.
- `chat-record UserPromptSubmit` / `chat-record Stop`: hook-only modes, wired in `hooks.json`.

### Examples

A `note` call and the record it produces:

```console
$ echo "- gist: drafting bin/README.md" | CLAUDE_CODE_SESSION_ID=7f3a9c21-... chat-record note --as opus-5-5
```
```
@opus-5-5: 2026-10-07T12:33:06-07:00
- gist: drafting bin/README.md

-- 7f3a9c21 at 2026-10-07T12:33:06-07:00
```

`path`, run from inside a session:

```console
$ chat-record path
cdocs/_chat/2026-10-07-7f3a9c21-88e4-4b0a-9d31-1234567890ab.md
```

The error when a project has not opted in:

```console
$ chat-record path
chat-record: no cdocs/_chat/ between /some/dir and the git toplevel (run /cdocs:init)
```

A real `Stop` block, from a turn with no note yet:

```json
{"decision":"block","reason":"No chat-record entry for this turn (record: cdocs/_chat/2026-10-07-7f3a9c21-....md). Run, then finish:\nchat-record note --as <your model id> <<'EOF'\n- gist: <what a successor should know from this turn>\nEOF"}
```

### More

Design rationale: [`cdocs/proposals/2026-09-22-chat-record-devlog-management.md`](../../../cdocs/proposals/2026-09-22-chat-record-devlog-management.md).
Usage rule for agents: [`../rules/overseers.md`](../rules/overseers.md) "Chat record".
Hook wiring, permissions, and opt-outs: [`../README.md`](../README.md) "Chat record".

## `graphify-scope`

> BLUF: Turns a round's changed files into a graphify-resolved dependent-set brief for the `/cdocs:iterate --graphify-scope` reviewer.
> It is additive only: every non-scoped outcome prints a labeled `SCOPE-STATUS` and tells the role to run its normal sweep.

### What it does

- `explain`s each changed file for its `[contains]` symbols, then `affected`s each symbol for its dependents, via the `graphify` CLI.
- Prints `SCOPE-STATUS: scoped` plus the brief, or `skip-scope` (with a `SCOPE-REASON`) or `disabled`, and exits 0.
- Exits 1 on a usage error or a missing `jq`.
- Co-surfaces `.observe`/`.subscribe` sites in the touched files, which the graph cannot see.
- Needs `jq`, and `graphify` with a built index for a scoped result.

### Commands

- `graphify-scope brief --enable --diff-base <ref>`: brief for files changed since `<ref>` (default: uncommitted changes against `HEAD`).
- `graphify-scope brief --enable --files "<path> ..."`: brief for named files.
- `--symbols "<label> ..."`: skip `explain`, run `affected` on known symbols.
- `--index <path>` / `--graph <path>`, `--near-empty-threshold <n>`: index location and the near-empty skip threshold.

### Examples

Without `--enable` (the iterate flag is off):

```console
$ graphify-scope brief --files a.ts
SCOPE-STATUS: disabled
SCOPE-FALLBACK: unscoped-sweep
# graphify scoping did not run this round; this is ADDITIVE fallback, not a narrowing.
# Fall back to your normal unscoped context-gathering sweep -- recall is unchanged.
```

With no `graphify` installed:

```console
$ graphify-scope brief --enable --diff-base HEAD~1
SCOPE-STATUS: skip-scope
SCOPE-REASON: no-binary
SCOPE-FALLBACK: unscoped-sweep
...
```

A scoped brief, head only (run against the test suite's `graphify` stub):

```console
$ graphify-scope brief --enable --files src/widget.ts --index graph.json
SCOPE-STATUS: scoped
SCOPE-DEP-COUNT: 3
SCOPE-OBSERVE-COUNT: 2

SCOPED-CONTEXT BRIEF (graphify-resolved; an AID, never a completeness guarantee)
...
Resolved dependent set (3 file(s), graph-derived, NOT exhaustive):
  - src/aliases.ts
  - src/app/consumer.ts
  - src/index.ts
```

### More

Design: [`cdocs/proposals/2026-09-17-graphify-cdocs-integration.md`](../../../cdocs/proposals/2026-09-17-graphify-cdocs-integration.md).
Loop wiring: [`../skills/iterate/SKILL.md`](../skills/iterate/SKILL.md) "Graphify scoping".
Tests: `bash plugins/cdocs/hooks/tests/graphify-scope.test.sh`.
