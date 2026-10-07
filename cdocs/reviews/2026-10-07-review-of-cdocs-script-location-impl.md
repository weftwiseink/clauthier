---
review_of: cdocs/devlogs/2026-10-07-cdocs-script-location-impl.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T13:05:43-07:00
task_list: cdocs/script-location
type: review
state: live
status: done
tags: [fresh_agent, runtime_validated, documentation, ci]
---

# Review: CDocs Script Location Implementation

## Summary Assessment

The work moves `graphify-scope` from `plugins/cdocs/scripts/` to `plugins/cdocs/bin/` (on `PATH`), moves its suite to `hooks/tests/`, switches `iterate` to the bare command with a missing-command fallback, adds a Linux-only CI step, and documents the helper in `bin/README.md`.
It follows the accepted proposal exactly across commits `b12b0ec`, `784bac6`, `369f3cd`, and `d4f49b7`, and every verification-floor item reproduces on the live system at `3a902c7`.
The README section matches the `chat-record` section in shape and tone, its samples are byte-identical to real output, and the `chat-record` content is preserved apart from heading levels.
Verdict: **Accept**, with three non-blocking polish items (a muddled CI header sentence, flags listed under "Commands", and a macOS bash 3.2 failure mode the fallback text does not name).

## Verification (re-run by the reviewer)

All commands run from `/var/home/mjr/code/weft/clauthier/main` at `3a902c7` (`b8269d3` plus one overseer devlog commit), working tree clean.

```
$ npm run build:cdocs                                          # exit=0
build-opencode: Done.
  Agents converted: 7
$ ls build/cdocs/opencode/scripts
postinstall.js
$ bash plugins/cdocs/hooks/tests/graphify-scope.test.sh        # exit=0
RESULTS: 51 passed, 0 failed
$ bash plugins/cdocs/hooks/tests/chat-record.test.sh --unit    # exit=0
chat-record tests: 95 passed, 0 failed
$ bash plugins/cdocs/hooks/tests/validate-cdocs-edit-path.test.sh   # exit=0
17 passed, 0 failed
$ git ls-files -s plugins/cdocs/bin/graphify-scope plugins/cdocs/hooks/tests/graphify-scope.test.sh
100755 318040f... 0	plugins/cdocs/bin/graphify-scope
100755 14a2ac0... 0	plugins/cdocs/hooks/tests/graphify-scope.test.sh
$ ls plugins/cdocs/scripts
postinstall.js
$ command -v graphify-scope          # live session PATH, no override
/var/home/mjr/code/weft/clauthier/main/plugins/cdocs/bin/graphify-scope
$ git grep -n -e 'scripts/graphify-scope' -e 'graphify-scope\.sh' -e 'test-graphify-scope' -- . ':!cdocs/'
(no output, exit=1)
$ git grep -n 'scripts/graphify-scope' -- cdocs/proposals/2026-09-27-clauthier-improvement-verification.md
(no output, exit=1)
```

README samples, re-captured from scratch directories under `/tmp` (outside the source tree) with no `PATH` override, then diffed against `plugins/cdocs/bin/README.md`:

```
$ graphify-scope brief --files a.ts          # scratch git repo, exit=0
SCOPE-STATUS: disabled
SCOPE-FALLBACK: unscoped-sweep
# graphify scoping did not run this round; this is ADDITIVE fallback, not a narrowing.
# Fall back to your normal unscoped context-gathering sweep -- recall is unchanged.
-> diff against README block: identical

$ graphify-scope brief --enable --diff-base HEAD~1   # scratch repo with two commits, no graphify installed, exit=0
SCOPE-STATUS: skip-scope
SCOPE-REASON: no-binary
SCOPE-FALLBACK: unscoped-sweep
# graphify scoping did not run this round; ...
-> first three lines identical to the README block, which elides the rest with `...`

$ graphify-scope brief --enable --files src/widget.ts --index graph.json   # test stub on PATH, fixture, graph.json written 1s later
SCOPE-STATUS: scoped
SCOPE-DEP-COUNT: 3
SCOPE-OBSERVE-COUNT: 2
...
Resolved dependent set (3 file(s), graph-derived, NOT exhaustive):
  - src/aliases.ts
  - src/app/consumer.ts
  - src/index.ts
-> matches the README's scoped excerpt line for line

$ graphify-scope                              # exit=1
graphify-scope: usage: graphify-scope brief [--enable] [--files "..."] [--diff-base <ref>] ...
```

`chat-record` preservation: the pre-move `bin/README.md` (from `ae88ea0`), with `# ...` rewritten to `` ## `chat-record` `` and `## ` demoted to `### `, diffs empty against lines 6-65 of the new README.

## Section-by-Section Findings

### Move and in-file edits (`b12b0ec`)

Both moves are pure renames (98% similarity) with mode 755 kept.
The helper's header, test-path comment, and usage string drop `.sh` as specified, and the suite's `PLUGIN="$(cd "$HERE/../.." && pwd)"` mirrors `chat-record.test.sh`.
No behavior change to the helper. No findings.

### `iterate/SKILL.md` (`784bac6`)

The call is the bare `graphify-scope brief --enable --diff-base <base-ref>`, and the fallback bullet adds the missing-command case with the `[graphify: skip-scope no-command]` log label.
The OpenCode build carries the same text; since OpenCode ships no `bin/`, the missing-command fallback is the path it takes, as the proposal intends.

1. **[non-blocking] An unlabeled crash is not named in the fallback.**
   The helper needs bash 4 (`declare -A`, `mapfile`), and moving it onto `PATH` makes it reachable on macOS consumer hosts whose `env bash` may be 3.2.
   There it fails with a bash error rather than a `SCOPE-STATUS` line or "command not found", which the fallback bullet does not literally cover.
   "The overseer never blocks a round on scoping" covers it in spirit, and the flag is default-off and targets the Linux devcontainer, so this is a wording gap, not a defect.
   If the maintainer wants it closed, the cheapest fix is reading the existing clause as "the command is missing or fails" rather than adding mechanism.

### CI workflow (`369f3cd`)

The step is correct (`if: runner.os == 'Linux'`, right path) and the trigger paths already cover `bin/**` and `hooks/**`.

2. **[non-blocking] The header comment's last sentence now misreads.**
   "macOS runs it too, except the Linux-only graphify-scope suite (bash 4+, for the graphify devcontainer): BSD sed, awk, and tr, so GNU-only behavior in bin/ or the suites fails there."
   The colon clause, which explains why macOS runs at all, now hangs off the exclusion parenthetical.
   Suggested: "macOS runs it too (BSD sed, awk, and tr, so GNU-only behavior in bin/ or the suites fails there), except the Linux-only graphify-scope suite (bash 4+)."

The devlog is upfront that the step has not run in GitHub Actions yet; the YAML parses (`yq`) and the suite passes locally, which is the right floor for a one-step addition.

### `bin/README.md` (`d4f49b7`)

Style matches the `chat-record` section: BLUF, What it does, Commands, Examples, More; one sentence per line, no hard wraps, real samples.
The `graphify-scope` section is 63 lines against `chat-record`'s 60, and no bullet repeats another, so there is no bloat to cut.
The H1 `` `bin/` `` plus a two-line BLUF is the minimum a two-command README needs.

3. **[non-blocking] "Commands" mixes commands and flags.**
   `chat-record`'s Commands list is three invocable commands, one per line.
   Here, lines 3-4 are bare flags, and line 4 packs two flag groups (`--index`/`--graph` and `--near-empty-threshold`).
   Relatedly, "(default: uncommitted changes against `HEAD`)" hangs on the `--diff-base` line but describes the no-`--files`, no-`--diff-base` case (script line 234), so it reads as `--diff-base`'s own default.
   Optional tightening: keep the two `brief` lines, then one "Flags:" line for `--symbols`, `--index`/`--graph`, and `--near-empty-threshold`, and move the default to "With neither, it uses uncommitted changes against `HEAD`."
   This text came verbatim from the accepted proposal, so leaving it is defensible.

### Consistency elsewhere

- `plugins/cdocs/README.md`: no stale references; its "Chat record" sentence "`bin/` puts `chat-record` on the Bash tool's `PATH`" stays true. It never mentioned the helper, and nothing requires it to.
- Repo `CLAUDE.md`: only `scripts/build-opencode.ts` (repo-root `scripts/`, unrelated). Consistent.
- `plugins/cdocs/agents/reviewer.md`: describes the brief and the `graphify` CLI only, never the helper's path. Consistent.
- `scripts/build-opencode.ts`, `package.json`, `postinstall.js`, `hooks.json`: untouched, as the proposal requires.
- The `chat-record` section's `../rules/overseers.md` link resolves (the file exists at HEAD). The devlog's open note on a possible rename stays relevant only if the concurrent rules work renames it.

### Devlog

Accurate and complete: the Changes Made table and commit list match `git log ae88ea0^..b8269d3`, the Verification block matches what I reproduced, and the "Not verified" line names the two real gaps (Actions run, marketplace-installed consumer).
The open observation about `brief` silently accepting unknown `--flags` is correctly scoped out ("do not change the helper's behavior").

## Verdict

**Accept.**
Every proposal item landed, every verification-floor command reproduces, the README samples match real output, and nothing outside `cdocs/` points at the old path.
The three findings are wording polish and can be folded into a later touch of these files or dropped.

## Action Items

1. [non-blocking] Reorder the CI header's last sentence so the BSD explanation attaches to "macOS runs it too", not to the graphify-scope exclusion.
2. [non-blocking] In `bin/README.md` "Commands", optionally collapse the flag lines into one "Flags:" line and move the no-argument default off the `--diff-base` line.
3. [non-blocking] Optionally read the `iterate` fallback's missing-command clause as "missing or fails" to cover a bash 3.2 crash on macOS hosts.

## Questions for the Maintainer

- Should the plugin README link `bin/README.md` (for example from "Chat record")? (a) No, leave discovery to the directory, as today. (b) Yes, one link in "Hooks". This is pre-existing for `chat-record` and outside this proposal.
