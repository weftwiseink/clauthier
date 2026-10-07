---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T13:00:00-07:00
task_list: cdocs/script-location
type: devlog
state: live
status: review_ready
part_of: cdocs/devlogs/2026-10-07-cdocs-script-location.md
tags: [plugin-architecture, graphify]
---

# CDocs Script Location: Implementation

> BLUF: Implements `cdocs/proposals/2026-10-07-cdocs-script-location.md` (dispatched by the iterate overseer): `graphify-scope` moves to `plugins/cdocs/bin/`, its test to `plugins/cdocs/hooks/tests/`, `iterate` calls it from `PATH`, CI runs its suite on Linux, and `bin/README.md` documents it.

## Objective

Implement the accepted proposal `cdocs/proposals/2026-10-07-cdocs-script-location.md` in full (reviews: `cdocs/reviews/2026-10-07-review-of-cdocs-script-location.md`, `-r2.md`).

## Scratchpoint

- as_of: 2026-10-07T13:04:00-07:00
- now: all four proposal commits landed; verification floor passes (evidence below); devlog `review_ready`.
- next: the loop's reviewer reviews; the overseer owns acceptance and the proposal's final status (left at `implementation_wip`).
- open:
  - observation: `brief` accepts unknown `--flags` silently (only a stray positional argument or a bad subcommand exits 1); out of scope ("do not change the helper's behavior"), and the README's "Exits 1 on a usage error" stays true for those cases.
  - observation: the `chat-record` section's link to `../rules/overseers.md` is carried over unchanged; if the concurrent rules work renames that file (the repo `CLAUDE.md` already names `orchestration-discipline.md`), that link and `plugins/cdocs/README.md` line 140 need the new name.
- files touched: see Changes Made.

## Plan

One phase, four commits per the proposal's Implementation Phases:

1. `refactor(cdocs): move graphify-scope to bin/ and its test to hooks/tests`
2. `fix(iterate): call graphify-scope from PATH`
3. `ci(cdocs): run the graphify-scope suite on Linux`
4. `docs(bin): document graphify-scope`

## Testing Approach

The existing 51-case suite is the regression floor; it runs from its new location after commit 1.
The consumer-path fix is proven by running the bare command from a scratch git repo outside this checkout.
Constraint: another agent is editing `plugins/cdocs/rules/*.md` and the devlog skill concurrently, so those files are not touched here.

## Implementation Notes

No deviation from the proposal: the four commits, file list, and README section text follow it as written.
Minor choices within its latitude:

- The `chat-record` heading is `` ## `chat-record` `` (backticked) to match the proposal's `` ## `graphify-scope` ``; its body is otherwise unchanged apart from the `##` to `###` demotion.
- `iterate/SKILL.md` names where the bare command comes from ("on `PATH` from the plugin's `bin/`") in the sentence introducing the call, and the missing-command case joins the existing fallback bullet rather than a new bullet.
- The CI header comment is rewrapped to fit the added suite and the "except the Linux-only graphify-scope suite" qualifier.
- The workflow YAML was checked with `yq` (no Python `yaml` or `actionlint` on the host); the workflow itself has not run in GitHub Actions yet.

README samples were captured by running `bin/graphify-scope` on `PATH` from scratch directories outside the repo, and match the proposal's text byte for byte (elided lines marked `...`):

- `disabled`: `graphify-scope brief --files a.ts` from `/tmp`.
- `no-binary`: `graphify-scope brief --enable --diff-base HEAD~1` in a scratch git repo with two commits (`graphify` is not installed on this host).
- `scoped`: the stub heredoc extracted from `graphify-scope.test.sh` onto `PATH`, the test's `src/widget.ts` fixture, and `graph.json` written one second after it; full output starts `SCOPE-STATUS: scoped` / `SCOPE-DEP-COUNT: 3` / `SCOPE-OBSERVE-COUNT: 2` and lists `src/aliases.ts`, `src/app/consumer.ts`, `src/index.ts`.

## Changes Made

| File | Change |
|---|---|
| `plugins/cdocs/scripts/graphify-scope.sh` -> `plugins/cdocs/bin/graphify-scope` | `git mv` (mode 755 kept); header line 2, line 29 test path, usage string drop `.sh` |
| `plugins/cdocs/scripts/test-graphify-scope.sh` -> `plugins/cdocs/hooks/tests/graphify-scope.test.sh` | `git mv`; line 2 comment; `PLUGIN="$(cd "$HERE/../.." && pwd)"`, `SH="$PLUGIN/bin/graphify-scope"` |
| `plugins/cdocs/skills/iterate/SKILL.md` | bare `graphify-scope brief --enable --diff-base <base-ref>`; missing command counts as `skip-scope`, logged `[graphify: skip-scope no-command]` |
| `cdocs/proposals/2026-09-27-clauthier-improvement-verification.md` | line 38 path -> `plugins/cdocs/bin/graphify-scope` |
| `.github/workflows/cdocs-hooks.yml` | `graphify-scope unit suite` step with `if: runner.os == 'Linux'`; header comment |
| `plugins/cdocs/bin/README.md` | H1 `` `bin/` `` + BLUF; `chat-record` content under its own `##`; new `graphify-scope` section |

Commits:

- `ae88ea0` docs(devlogs): start script-location implementation sub-devlog
- `b12b0ec` refactor(cdocs): move graphify-scope to bin/ and its test to hooks/tests
- `784bac6` fix(iterate): call graphify-scope from PATH
- `369f3cd` ci(cdocs): run the graphify-scope suite on Linux
- `d4f49b7` docs(bin): document graphify-scope

## Verification

Run from the repo root at `d4f49b7`:

```
$ npm run build:cdocs                                   # exit=0
  Agents converted: 7
  Output: /var/home/mjr/code/weft/clauthier/main/build/cdocs/opencode
$ ls build/cdocs/opencode/scripts
postinstall.js
$ bash plugins/cdocs/hooks/tests/graphify-scope.test.sh  # exit=0
RESULTS: 51 passed, 0 failed
$ bash plugins/cdocs/hooks/tests/chat-record.test.sh --unit   # exit=0
chat-record tests: 95 passed, 0 failed
$ bash plugins/cdocs/hooks/tests/validate-cdocs-edit-path.test.sh   # exit=0
17 passed, 0 failed
$ test -x plugins/cdocs/bin/graphify-scope && echo executable && ls plugins/cdocs/scripts
executable
postinstall.js
$ BIN="$PWD/plugins/cdocs/bin"; D=$(mktemp -d); (cd "$D" && git init -q && PATH="$BIN:$PATH" command -v graphify-scope && PATH="$BIN:$PATH" graphify-scope brief | head -1)
/var/home/mjr/code/weft/clauthier/main/plugins/cdocs/bin/graphify-scope
SCOPE-STATUS: disabled
$ command -v graphify-scope        # live Claude Code session PATH, no PATH override
/var/home/mjr/code/weft/clauthier/main/plugins/cdocs/bin/graphify-scope
$ git grep -n -e 'scripts/graphify-scope' -e 'graphify-scope\.sh' -e 'test-graphify-scope' -- . ':!cdocs/'
(no output; six hits before the move)
$ git grep -n 'scripts/graphify-scope' -- cdocs/proposals/2026-09-27-clauthier-improvement-verification.md
(no output)
$ graphify-scope            # usage string after the rename, exit=1
graphify-scope: usage: graphify-scope brief [--enable] [--files "..."] [--diff-base <ref>] [--symbols "..."] [--graph <path> | --index <path>] [--near-empty-threshold <n>]
$ yq -o=json '.jobs."chat-record-unit".steps[-1]' .github/workflows/cdocs-hooks.yml
{"name": "graphify-scope unit suite", "if": "runner.os == 'Linux'", "run": "bash plugins/cdocs/hooks/tests/graphify-scope.test.sh"}
```

Not verified: the CI step in GitHub Actions itself (it runs on the next push touching `plugins/cdocs/bin/**`), and a consumer project with the plugin installed from the marketplace (the live `command -v` above is this source-repo session, where the plugin's `bin/` is already on `PATH`).
