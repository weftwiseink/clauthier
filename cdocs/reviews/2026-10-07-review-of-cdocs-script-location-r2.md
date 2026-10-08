---
review_of: cdocs/proposals/2026-10-07-cdocs-script-location.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T12:59:30-07:00
task_list: cdocs/script-location
type: review
state: archived
status: done
tags: [fresh_agent, runtime_validated, test_plan, documentation]
---

# Review: CDocs Script Location, Round 2

> BLUF(@claude-opus-5-5/cdocs/script-location): Accept.
> B1 is fixed: the new `git grep` lists exactly the six live references today, so it can fail.
> All seven round-1 suggestions are taken, and a simulated move passes 51/51 from the new location.
> One sample value is wrong (`SCOPE-OBSERVE-COUNT: 1`; the real output is `2`), and the implementer fixes it while re-capturing.

## Summary Assessment

The proposal moves `graphify-scope.sh` to `bin/graphify-scope` (on `PATH`) and its test to `hooks/tests/`.
It also switches the `iterate` call to the bare name with a missing-command fallback, adds a Linux-only CI step, and documents the command in `bin/README.md`.
Round 2 resolves the one blocker and all seven non-blocking items without adding mechanism.
I re-checked every factual claim against `bd14c2b` and ran the move in a scratch copy.
The only new defect is a wrong number in the scoped README sample, plus a re-capture step that depends on file order.
Both are implementer-level fixes, and neither touches the design.
Verdict: **Accept**.

## Round-1 Resolution

| R1 item | Status | Evidence |
|---|---|---|
| B1 vacuous grep | Resolved | `git grep -n -e 'scripts/graphify-scope' -e 'graphify-scope\.sh' -e 'test-graphify-scope' -- . ':!cdocs/'` prints exactly `graphify-scope.sh:2,29,357`, `test-graphify-scope.sh:2,17`, `iterate/SKILL.md:48` (exit 0), matching the "six hits" comment. The RFP-specific grep lists line 38 today. Both checks can fail. |
| N1 history in Background | Resolved | Cut to one clause. |
| N2 fallback wording | Resolved | "OpenCode, or a non-CLI install without `bin/`" plus the `[graphify: skip-scope no-command]` label. |
| N3 live RFP | Resolved | Added to the reference table and to commit 2. |
| N4 README tightenings | Resolved | "OpenCode ships neither.", the exit-1 bullet split out, re-capture steps given (see N2 below). |
| N5 build "only" | Resolved | Transformed `agents/` is named. |
| N6 worktrees edge case | Resolved | Dropped; `Bash(graphify-scope:*)` is named. |
| N7 scratch-repo comment | Resolved | Reads "runs outside the source repo" and defers the `PATH` claim to the live `command -v`. |

## Independent Verification

Checked at `bd14c2b`:

- **Reference completeness.** `git grep graphify-scope -- . ':!cdocs/'` also hits `agents/reviewer.md:44` (flag name only) and `SKILL.md:4,37,42` (flag/prose), none of which carry a path. `graphify-scope.sh:35` already prints `graphify-scope:` as its error prefix. `.claude/` has no allowlist entry for the old path. The table is complete.
- **`bin/` on `PATH`.** `command -v chat-record` in this subagent session resolves to `plugins/cdocs/bin/chat-record`.
- **Build.** `build-opencode.ts` copies `skills/`, `rules/`, `hooks/cdocs-hooks.ts`, and only `scripts/postinstall.js` via `copyFile` (lines 351-359), and writes `package.json` with `"scripts/"` and `postinstall: node scripts/postinstall.js` (297, 307). Neither `bin/` nor the helper ships. Claim holds.
- **CI.** `.github/workflows/cdocs-hooks.yml` triggers on `plugins/cdocs/bin/**` and `plugins/cdocs/hooks/**`, so it covers both new paths. Its one job runs a `[ubuntu-latest, macos-latest]` matrix, so the proposed `if: runner.os == 'Linux'` is the right granularity.
- **Simulated move.** In a scratch copy of `plugins/cdocs/`, I did both moves, changed test line 17 to the `PLUGIN=` form, and updated the usage string. `bash hooks/tests/graphify-scope.test.sh` gave `RESULTS: 51 passed, 0 failed`, and `scripts/` held only `postinstall.js`. From a fresh `git init` dir, `PATH="$BIN:$PATH" graphify-scope brief` printed `SCOPE-STATUS: disabled` (exit 0), and a bare `graphify-scope` printed the new usage string (exit 1). The test asserts nothing on the usage text, so renaming it is safe.
- **README samples.** The `disabled` and `no-binary` samples reproduce byte-for-byte from the moved script. The `--diff-base` default ("uncommitted changes against `HEAD`") matches `git diff --name-only HEAD` at line 234. `need jq` at line 37 backs "exits 1 on a missing `jq`".
- **README fit.** The new section copies the shape of `chat-record`: `> BLUF`, What it does, Commands, Examples, More. Commands and flags take one line each, with one sentence per line and no hard wraps, and it is about the same length. The three link targets resolve from `plugins/cdocs/bin/`.

## Section-by-Section Findings

### BLUF, Summary, Objective, Background

Accurate and timeless.
No findings.

### Proposed Solution: reference table and `iterate` edit

Complete (see above).
The missing-command clause is the minimum needed for the bare-name call to degrade cleanly.
No findings.

### Proposed Solution: `bin/README.md` section

**N1 [non-blocking, implementer must fix] The scoped sample's `SCOPE-OBSERVE-COUNT` is wrong.**
The sample shows `SCOPE-OBSERVE-COUNT: 1`.
Following the proposal's own re-capture steps, the helper prints `SCOPE-OBSERVE-COUNT: 2`, because the `widget.ts` fixture has both `store.observe(...)` and `bus.subscribe(...)`.
The text under the block says "Every line shown is a literal `echo` in the helper or a stub fixture path, so the suite's assertions also cover it".
That is not true of the counts: line 308 echoes the computed `$site_count`, and the suite asserts only `SCOPE-OBSERVE-COUNT: [1-9]`.
Phase 4 already says to use "re-captured samples", so the fix is to paste the real output (`2`).
Because the claim is not what keeps the README honest, this does not block.

**N2 [non-blocking] The re-capture steps depend on file order.**
The helper reports `stale-index` when a changed file is newer than the index.
I wrote `widget.ts` after `graph.json` (one second later) and got `SCOPE-STATUS: skip-scope` / `SCOPE-REASON: stale-index` instead of `scoped`.
The test avoids this by writing `graph.json` last (and by `touch -d '2000-01-01'`).
The implementer should create `graph.json` after the fixture.

### Important Design Decisions

All proportionate.
The CI step stays a single guarded step in the existing job and adds no new job, no new workflow, and no bash-3.2 port.
I see no over-engineering.

**N3 [non-blocking] CI header comment.**
The workflow header says "macOS runs it too: BSD sed, awk, and tr, so GNU-only behavior in bin/ or the suites fails there."
Once `bin/graphify-scope` is in `bin/` but runs on Linux only, that sentence overclaims.
The implementer should qualify it in the header edit the proposal already plans (e.g. "except the Linux-only graphify-scope suite").

### Edge Cases

**N4 [non-blocking] Sentence-per-line.**
"Permission prompts" puts two sentences on one line ("...is allowed. This is unchanged...").
This is a proposal-only formatting nit.

### Test Plan / Verification Methodology

Sound, and every check has a failure picture.

**N5 [non-blocking] The build check cannot catch this change.**
`npm run build:cdocs` with "`scripts/` holds only `postinstall.js`" passes before and after the move, because the build copies `postinstall.js` by name and never copies `scripts/` wholesale.
It is a harmless regression floor, so keep it or drop it.
It proves nothing about the move.

### Implementation Phases

Four commits by explicit path, with an explicit do-not-change list.
Between commits 1 and 2, `iterate/SKILL.md` points at a path that no longer exists, but the tests are green and the commits land together.
No findings.

## Verdict

**Accept.**
B1 and all of round 1 are resolved, the claims hold against the repo, and the move works in simulation.
N1 must be fixed during implementation (paste the real count), and the rest are nits.

## Action Items

1. [non-blocking, implementer] Re-capture the scoped README sample and use the real `SCOPE-OBSERVE-COUNT: 2`. Do not carry over the proposal's `1`.
2. [non-blocking, implementer] When re-capturing, write `graph.json` after `src/widget.ts` (or backdate the fixture), or the helper reports `stale-index`.
3. [non-blocking, implementer] In the `cdocs-hooks.yml` header edit, qualify "macOS runs it too" so it excludes the Linux-only graphify-scope suite.
4. [non-blocking] Split the two sentences in the "Permission prompts" edge case onto separate lines.
5. [non-blocking] The `npm run build:cdocs` check is a pure regression floor that cannot fail because of this move. Keep or drop it.

## Questions for the Maintainer

None: round 1's two questions (keep the Linux CI step; update the live RFP line) were settled in the revision the way the reviewer leaned.
