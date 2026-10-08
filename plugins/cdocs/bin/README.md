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
$ echo "- Drafting bin/README.md: examples for each mode." | CLAUDE_CODE_SESSION_ID=7f3a9c21-... chat-record note --as opus-5-5
```
```
@opus-5-5: 2026-10-07T12:33:06-07:00
- Drafting bin/README.md: examples for each mode.

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
{"decision":"block","reason":"No chat-record entry for this turn (record: cdocs/_chat/2026-10-07-7f3a9c21-....md). Run, then finish:\nchat-record note --as <your model id> <<'EOF'\n- <the most important thing you are telling the user>\nEOF"}
```

### More

Design rationale: [`cdocs/proposals/2026-09-22-chat-record-devlog-management.md`](../../../cdocs/proposals/2026-09-22-chat-record-devlog-management.md).
Usage rule for agents: [`../rules/overseers.md`](../rules/overseers.md) "Chat record".
Hook wiring, permissions, and opt-outs: [`../README.md`](../README.md) "Chat record".

## `cdocs-graphify`

> BLUF: Runs a graphify `query`, `explain`, `path`, or `affected` against the calling worktree's own index, kept current on every call.
> Agents use it through the `/cdocs:graphify` skill; overseers never run it.

### What it does

- Copies the main graph into `<toplevel>/graphify-out/` if that has no `graph.json`: from `$GRAPHIFY_OUT` when set (the devcontainer's shared index), else from the `main` worktree's `graphify-out/`.
  The copy drops `.graphify_root` and graphify's dated backup dirs, and ignores itself (`.gitignore` of `*`).
- Runs `graphify update <toplevel>` into that index (AST-only, no LLM), logging to `graphify-out/update.log`; on failure it says so and queries the existing index.
- Passes its arguments to `graphify` with `--graph <worktree index>`, stdout and exit code unchanged.
- Appends `.observe`/`.subscribe` sites (up to 30) from files the output names, which the graph cannot see.
- Without `graphify`, a git worktree, or any index: one `skipping` line on stderr, exit 0.
- When `cdocs/` exists and `.graphifyignore` lacks a root-anchored `/cdocs/` line: a one-line hint to run `/cdocs:init`.

### Examples

```console
$ cdocs-graphify query "how does the iterate overseer dispatch reviewers"
$ cdocs-graphify explain "readMount()"
$ cdocs-graphify path "renderView()" "readMount()"
```

Without graphify:

```console
$ cdocs-graphify query "anything"
cdocs-graphify: graphify not installed; skipping
```

### More

Design: [`cdocs/proposals/2026-10-08-graphify-overhaul.md`](../../../cdocs/proposals/2026-10-08-graphify-overhaul.md).
Agent usage: [`../skills/graphify/SKILL.md`](../skills/graphify/SKILL.md).
Tests: `bash plugins/cdocs/hooks/tests/cdocs-graphify.test.sh`.
