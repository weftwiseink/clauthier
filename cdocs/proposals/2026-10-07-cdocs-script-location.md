---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T12:52:25-07:00
task_list: cdocs/script-location
type: proposal
state: live
status: review_ready
last_reviewed:
  status: revision_requested
  by: "@claude-opus-5-5"
  at: 2026-10-07T12:55:47-07:00
  round: 1
tags: [claude_skills, architecture]
---

# CDocs Script Location: `graphify-scope` Moves to `bin/`

> BLUF: Move `plugins/cdocs/scripts/graphify-scope.sh` to `plugins/cdocs/bin/graphify-scope` and its test to `plugins/cdocs/hooks/tests/graphify-scope.test.sh`.
> `bin/` holds agent-invoked runtime commands, which Claude Code puts on `PATH`; `scripts/` keeps only `postinstall.js`, an OpenCode npm install-time script.
> The move also fixes a latent bug: `iterate` calls the helper by the source-repo-relative path `plugins/cdocs/scripts/graphify-scope.sh`, which does not exist in any consumer project.
> `bin/README.md` gains a terse `graphify-scope` section beside `chat-record`.

## Summary

The two folders hold different kinds of file, and only one of them is misplaced:

| File | Invoked by | When | Right home |
|---|---|---|---|
| `bin/chat-record` | hooks (`${CLAUDE_PLUGIN_ROOT}/bin/...`) and agents (bare name on `PATH`) | CC runtime | `bin/` |
| `scripts/graphify-scope.sh` | the `iterate` overseer, by relative path | CC runtime | `bin/` |
| `scripts/test-graphify-scope.sh` | a human or reviewer | dev time | `hooks/tests/`, beside the `chat-record` suite |
| `scripts/postinstall.js` | npm, via `build/cdocs/opencode/package.json` | OC install time | `scripts/` (unchanged) |

So the resolution is "consolidate runtime commands into `bin/`", not "merge the folders": `scripts/` survives with one well-defined occupant.

## Objective

Give every agent-invoked cdocs command one home that resolves in consumer projects, and document it where its sibling is documented.

## Background

- **Why the split exists.** `graphify-scope.sh` predates `bin/`, and nothing in the [graphify integration proposal](2026-09-17-graphify-cdocs-integration.md) constrains its location.
- **How `bin/` resolves.** Claude Code adds an enabled plugin's `bin/` to the Bash tool's `PATH` (this session: `command -v chat-record` resolves to `plugins/cdocs/bin/chat-record`).
  The plugin README already relies on this for `chat-record note` ("Chat record" section).
- **How `scripts/` resolves.** It does not, at runtime: nothing puts it on `PATH`, and `iterate/SKILL.md` line 48 runs `plugins/cdocs/scripts/graphify-scope.sh`, a path relative to this source repo's root.
  In a consumer project the plugin lives under `~/.claude/plugins/...`, so the call fails with "No such file or directory" (not a labeled `SCOPE-STATUS`).
  The flag is default-off and has only been exercised in this repo, which is why the bug is latent.
- **OpenCode.** `scripts/build-opencode.ts` copies `skills/`, `rules/`, `hooks/cdocs-hooks.ts`, and `scripts/postinstall.js`, and writes transformed `agents/`; neither `bin/` nor `graphify-scope.sh` reaches `build/cdocs/opencode/`.
  OpenCode has no plugin-`bin/` `PATH` mechanism, and the README already states OpenCode keeps no chat record.
  The ported `iterate` skill therefore cannot run the helper on OpenCode today, before or after this move.
- **Tests and CI.** `hooks/tests/` already tests a `bin/` script (`chat-record.test.sh` resolves `$PLUGIN/bin/chat-record` from its own directory).
  `.github/workflows/cdocs-hooks.yml` triggers on `plugins/cdocs/bin/**` and `plugins/cdocs/hooks/**` and describes itself as "CI for the cdocs Claude Code hooks and bin/ scripts".
  `test-graphify-scope.sh` runs in no CI workflow today (51/51 passing locally).

## Proposed Solution

1. `git mv plugins/cdocs/scripts/graphify-scope.sh plugins/cdocs/bin/graphify-scope` (drop `.sh` to match `chat-record`, keeping the executable bit).
2. `git mv plugins/cdocs/scripts/test-graphify-scope.sh plugins/cdocs/hooks/tests/graphify-scope.test.sh`.
3. Update references (complete list, with historical `cdocs/` records keeping their original paths):

| Path | Change |
|---|---|
| `plugins/cdocs/skills/iterate/SKILL.md` (line 48) | `graphify-scope brief --enable --diff-base <base-ref>` (bare name, on `PATH`). In the fallback bullet, count a missing command (OpenCode, or a non-CLI install without `bin/`) as `skip-scope`, logged as `[graphify: skip-scope no-command]`. |
| `plugins/cdocs/bin/graphify-scope` | Header line 2 and line 29 comment (`test-graphify-scope.sh` -> `hooks/tests/graphify-scope.test.sh`); usage string (line 357) `graphify-scope.sh brief` -> `graphify-scope brief`. |
| `plugins/cdocs/hooks/tests/graphify-scope.test.sh` | Line 2 comment; line 17 becomes `PLUGIN="$(cd "$HERE/../.." && pwd)"` and `SH="$PLUGIN/bin/graphify-scope"`, mirroring `chat-record.test.sh`. |
| `.github/workflows/cdocs-hooks.yml` | Add a `graphify-scope unit suite` step, `if: runner.os == 'Linux'` (see Design Decisions); mention it in the header comment. |
| `plugins/cdocs/bin/README.md` | Restructure and add the section below. |
| `cdocs/proposals/2026-09-27-clauthier-improvement-verification.md` (line 38) | `plugins/cdocs/scripts/graphify-scope.sh` -> `plugins/cdocs/bin/graphify-scope`: a live RFP written for adopters, not a historical record. |

4. `bin/README.md` becomes a two-command reference.
   The H1 becomes `` # `bin/` ``, with a one-line BLUF ("Runtime commands Claude Code puts on the Bash tool's `PATH` while the plugin is enabled. OpenCode ships neither.").
   The existing content moves under `## chat-record` unchanged (its `##` subsections demote to `###`).
   A new `## graphify-scope` section follows, in the same terse style:

````md
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
SCOPE-OBSERVE-COUNT: 1

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
````

The `disabled` and `no-binary` samples come from running the current script, and the implementer re-runs them against `bin/graphify-scope`.
The scoped sample was captured against the `graphify` stub that `graphify-scope.test.sh` writes to its temporary directory.
To re-capture it, copy the stub heredoc out of the test into a directory on `PATH`, then run the command in a workspace holding the test's `src/widget.ts` fixture and an empty-object `graph.json`.
Every line shown is a literal `echo` in the helper or a stub fixture path, so the suite's assertions also cover it.

## Important Design Decisions

- **`bin/`, not `scripts/`.** `PATH` is the one invocation mechanism that already works in consumer projects and that this plugin already depends on.
  Moving `chat-record` into `scripts/` instead would take it off `PATH` and break `chat-record note` for every agent.
- **Bare name on `PATH`, not `${CLAUDE_PLUGIN_ROOT}/...`.** `${CLAUDE_PLUGIN_ROOT}` is documented for hook and MCP config, not for skill text an agent copies into a Bash call, and it means nothing on OpenCode.
  The bare name matches how agents already call `chat-record`.
- **Keep `scripts/`.** `postinstall.js` is an install-time artifact named by the generated `package.json` (`"postinstall": "node scripts/postinstall.js"`) and copied by `build-opencode.ts`; it is not an agent command and must not be on `PATH`.
  Moving it would churn the OC package layout for no benefit.
- **Test in `hooks/tests/`, not beside the script.** Anything in `bin/` is on `PATH`, so a test there would become a command.
  `hooks/tests/` is already where `bin/` scripts are tested and is already watched by CI.
- **Drop `.sh`.** `PATH` commands carry no extension, and `chat-record` sets the convention.
- **Linux-only CI step.** The helper uses `declare -A` and `mapfile` (bash 4+) and targets the graphify devcontainer; the suite's no-binary case runs `bash` under `PATH=...:/usr/bin:/bin`, which is bash 3.2 on macOS.
  Porting the helper to bash 3.2 is not worth it for a Linux-container tool.
- **No OpenCode port.** Shipping `bin/` to OpenCode needs a new delivery mechanism (no plugin-`bin/` `PATH` there); the skill's one-line "missing command counts as `skip-scope`" fallback is enough for a default-off flag.

## Edge Cases / Challenging Scenarios

- **Name collision.** Another `graphify-scope` earlier on `PATH` would shadow the plugin's.
  The `graphify` package ships only `graphify` and `graphify-mcp`, so the risk is low; rename to `cdocs-graphify-scope` only if a collision is reported.
- **Permission prompts.** In default permission mode an unallowlisted `graphify-scope` call prompts, as `chat-record` does, unless `Bash(graphify-scope:*)` is allowed. This is unchanged from calling the old path.
- **Plugin installed outside the CLI.** Per the README, a plugin with `bin/` does not install through claude.ai or Cowork; there the command is missing and the skill falls back to `skip-scope`.

## Test Plan

- `plugins/cdocs/hooks/tests/graphify-scope.test.sh` passes 51/51 from its new location (proves the path rewrite and that the script runs under its new name).
- `chat-record.test.sh --unit` and `validate-cdocs-edit-path.test.sh` still pass (regression floor for the shared CI job).
- From a scratch git repo outside this checkout, `graphify-scope brief` resolves on `PATH` and prints `SCOPE-STATUS: disabled` (proves the consumer-path bug is fixed).

## Verification Methodology

Run from the repo root; each command's failure picture is stated.

```sh
npm run build:cdocs                       # fails: build error; check: build/cdocs/opencode/scripts/ holds only postinstall.js
bash plugins/cdocs/hooks/tests/graphify-scope.test.sh       # want: RESULTS: 51 passed, 0 failed
bash plugins/cdocs/hooks/tests/chat-record.test.sh --unit   # want: all pass
bash plugins/cdocs/hooks/tests/validate-cdocs-edit-path.test.sh  # want: all pass
test -x plugins/cdocs/bin/graphify-scope && ls plugins/cdocs/scripts   # want: executable; scripts/ lists only postinstall.js
BIN="$PWD/plugins/cdocs/bin"; (cd "$(mktemp -d)" && git init -q && PATH="$BIN:$PATH" graphify-scope brief | head -1)
# want: SCOPE-STATUS: disabled (runs outside the source repo; the live command -v check below proves Claude Code's PATH)
git grep -n -e 'scripts/graphify-scope' -e 'graphify-scope\.sh' -e 'test-graphify-scope' -- . ':!cdocs/'
# want: no output (before the move this lists six hits)
git grep -n 'scripts/graphify-scope' -- cdocs/proposals/2026-09-27-clauthier-improvement-verification.md   # want: no output
```

In a live Claude Code session with the plugin enabled, `command -v graphify-scope` resolves to the plugin's `bin/`.

## Implementation Phases

One phase; each numbered item is its own conventional commit, staged by explicit path.

1. `refactor(cdocs): move graphify-scope to bin/ and its test to hooks/tests` - both `git mv`s plus the in-file path, header, and usage edits, so the tree is green at this commit.
2. `fix(iterate): call graphify-scope from PATH` - `iterate/SKILL.md` invocation and missing-command fallback, plus the live RFP's path (line 38).
3. `ci(cdocs): run the graphify-scope suite on Linux` - workflow step and header comment.
4. `docs(bin): document graphify-scope` - `bin/README.md` restructure and section, with re-captured samples.

Do not change: `scripts/postinstall.js`, `scripts/build-opencode.ts`, `hooks/hooks.json`, `plugins/cdocs/rules/*.md`, any `cdocs/` historical record, or the helper's behavior.
