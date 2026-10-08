---
review_of: cdocs/proposals/2026-10-07-cdocs-script-location.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T12:55:47-07:00
task_list: cdocs/script-location
type: review
state: archived
status: done
tags: [fresh_agent, runtime_validated, architecture, test_plan, missing_validation]
---

# Review: CDocs Script Location (`graphify-scope` Moves to `bin/`)

> BLUF(@claude-opus-5-5/cdocs/script-location): The decision is right and the claims check out, but the verification grep that proves the reference list complete is vacuous (it excludes `plugins/cdocs/` and passes today, before the move).
> One-line fix; everything else is non-blocking polish.

## Summary Assessment

The proposal moves `graphify-scope.sh` into `bin/` (on `PATH`), its test into `hooks/tests/`, fixes the `iterate` call to use the bare name, adds a Linux CI step, and documents the command in `bin/README.md` beside `chat-record`.
The core decision is minimal and well-founded: `bin/` is the one runtime invocation mechanism that works in consumer projects, and the current source-repo-relative call genuinely fails outside this repo.
Every factual claim I checked holds, the README section matches the `chat-record` section's shape and tone, and its three samples reproduce byte-for-byte from the current script.
The one blocking defect is in Verification Methodology: `--exclude-dir=cdocs` matches `plugins/cdocs/` too, so the completeness grep can never fail.
Verdict: **Revise** (light).

## Verified Claims

Checked against the repo at `89132d4`, not taken on trust:

- **Plugin `bin/` is on `PATH`.** `command -v chat-record` in this (subagent) session resolves to `plugins/cdocs/bin/chat-record`, and an installed plugin's cache `bin/` (`rust-analyzer-lsp/1.0.0/bin`) is also on `PATH`. `plugins/cdocs/README.md:140` documents the same for `chat-record note`.
- **Current call fails in consumers.** `iterate/SKILL.md:48` is the literal `plugins/cdocs/scripts/graphify-scope.sh ...`; nothing resolves it outside this checkout, and the skill's fallback bullets key only on a `SCOPE-STATUS` first line, so a 127 "No such file" is unhandled. Claim holds.
- **OpenCode build.** `scripts/build-opencode.ts` copies `skills/`, `rules/`, `hooks/cdocs-hooks.ts`, `scripts/postinstall.js` (and transforms `agents/`); `package.json` `files` lists `scripts/` and `postinstall: node scripts/postinstall.js`. Neither `bin/` nor the helper ships. Claim holds (see N5 for the omission of `agents/`).
- **CI.** `.github/workflows/cdocs-hooks.yml` header and `paths` match the quote; `opencode-build.yml` references no script path. No workflow runs the graphify suite today.
- **Tests.** `bash plugins/cdocs/scripts/test-graphify-scope.sh` gives `RESULTS: 51 passed, 0 failed`. Line 150 runs `PATH="$EMPTYBIN:/usr/bin:/bin" bash "$SH"`, and the helper uses `declare -A`/`mapfile`, so the Linux-only rationale is accurate.
- **Reference list.** `git grep` outside `cdocs/` for the old names hits exactly `graphify-scope.sh:2,29,357`, `test-graphify-scope.sh:2,17`, and `iterate/SKILL.md:48`: the table is complete. `reviewer.md` mentions only the flag, not the path. No `.claude/` or user settings allowlist names the old path.
- **README samples.** The `disabled` and `no-binary` outputs reproduce exactly (exit 0), the usage error exits 1, and every scoped-sample line (`SCOPE-DEP-COUNT`, `SCOPED-CONTEXT BRIEF (...)`, `Resolved dependent set (...)`) is a literal `echo` in the helper; the three paths are the test stub's fixtures.

## Section-by-Section Findings

### BLUF / Summary

Clear and accurate; the table makes the "consolidate runtime commands, not merge folders" resolution obvious at a glance.
No findings.

### Background

**N1 [non-blocking] "Why the split exists" is history, not design.**
Commit hashes, dates, and devlog dispatch rows 85-86 explain how the file got misplaced, which does not affect the decision.
Per the maintainer's "timeless clarity" preference, cut it to one clause ("`graphify-scope.sh` predates `bin/`") or drop it; the devlog already records the provenance.

### Proposed Solution: reference table

**N2 [non-blocking] Fallback bullet wording.**
"count a missing command (OpenCode, plugin disabled) as `skip-scope`": a disabled plugin also has no `iterate` skill, so that case cannot arise.
The real cases are OpenCode and a non-CLI install without `bin/`.
Also name the Iteration Log label (e.g. `[graphify: skip-scope no-command]`) so the instrumentation the existing bullet asks for stays uniform with the helper's own `SCOPE-REASON` values.

**N3 [non-blocking] One live doc keeps the old path.**
`cdocs/proposals/2026-09-27-clauthier-improvement-verification.md:38` (`state: live`, `status: request_for_proposal`) names `plugins/cdocs/scripts/graphify-scope.sh` and is written for downstream adopters.
It is forward-looking, not a historical record, so either update that one line or name it explicitly as left alone; the blanket "historical `cdocs/` records" exemption does not obviously cover it.

### Proposed Solution: `bin/README.md`

The restructure (`` # `bin/` `` H1, one-line BLUF, `chat-record` content demoted one level unchanged) is the minimal way to hold two commands without two H1s.
The `graphify-scope` section mirrors `chat-record`'s shape (BLUF, What it does, Commands, Examples, More), keeps commands to one line each, uses real captured samples, and is about the same length.
Good fit for the maintainer's stated taste.

**N4 [non-blocking] Small README tightenings.**
- The folder BLUF "...while the plugin is enabled; OpenCode ports neither." reads awkwardly; "OpenCode ships neither." or a second sentence is cleaner and avoids the semicolon.
- The "Prints ..." bullet joins two thoughts with a semicolon; split the exit-1 case onto its own bullet for sentence-per-line.
- The re-capture instruction cannot be followed literally for the scoped sample: the stub lives in the test's `mktemp` scratch and is deleted on exit. Say how to re-capture it (e.g. "copy the stub out of `graphify-scope.test.sh`") or say the scoped sample is checked against the test's assertions rather than re-run.

### Important Design Decisions

All sound and proportionate: `bin/` over `scripts/`, bare name over `${CLAUDE_PLUGIN_ROOT}` (matches `chat-record` precedent and degrades cleanly on OpenCode), keep `scripts/` for `postinstall.js`, test outside `bin/` so it is not a command, drop `.sh`.

The CI step is mild scope growth for a "where does it live" proposal, but it is three lines, the suite has no CI today, and moving it into a directory CI already watches while leaving it unrun would be odd.
Not over-engineering.

**N5 [non-blocking] Accuracy nit.**
Background says the build copies four things "only"; it also writes transformed `agents/`.
Irrelevant to the decision, but "only" invites a correction.

### Edge Cases

**N6 [non-blocking] Drop "Untracked copies in sibling worktrees".**
`git mv` creates no untracked files, so this is a generic repo fact, not an edge case of this change.
"Name collision" and "Plugin installed outside the CLI" earn their place; "Permission prompts" could add the allow pattern (`Bash(graphify-scope:*)`) the main README already gives for `chat-record`, or stay as is.

### Test Plan / Verification Methodology

**B1 [blocking] The completeness grep is vacuous.**
`grep -rn ... --exclude-dir=cdocs .` excludes every directory named `cdocs` at any depth, including `plugins/cdocs/`, where all six live references are.
Run today, before any move, it prints nothing (exit 1), so it "passes" whether or not the references are updated.
This is the proposal's only mechanical proof that the reference list is complete, and an implementer would trust it.
Fix with a pathspec that excludes only the top-level records:

```sh
git grep -n -e 'scripts/graphify-scope' -e 'graphify-scope\.sh' -e 'test-graphify-scope' -- . ':!cdocs/'
# want: no output
```

(Verified: today this lists exactly the six expected hits.)

**N7 [non-blocking] The `PATH="$BIN:$PATH"` scratch-repo check proves less than its comment says.**
Prepending `bin/` manually shows the helper has no source-repo-relative dependencies, which is worth checking, but not that Claude Code puts it on `PATH`; the live `command -v graphify-scope` line is the real proof.
Reword the comment to "runs outside the source repo" so the two checks are not conflated.

### Implementation Phases

Four conventional commits, each green, with an explicit do-not-touch list.
Proportionate.
No findings.

## Verdict

**Revise.**
The design is accepted in substance; only B1 must change, a one-line swap in Verification Methodology.
The non-blocking items are polish the proposer can take or leave; a re-review after B1 should be a quick accept.

## Action Items

1. [blocking] Replace the Verification Methodology grep with `git grep ... -- . ':!cdocs/'` (or an equivalent that does not exclude `plugins/cdocs/`); keep "want: no output".
2. [non-blocking] Trim Background "Why the split exists" to one clause or drop it (history belongs in the devlog).
3. [non-blocking] In the `iterate` fallback edit, replace "plugin disabled" with "a non-CLI install without `bin/`" and name the Iteration Log label for a missing command.
4. [non-blocking] Update or explicitly exempt `cdocs/proposals/2026-09-27-clauthier-improvement-verification.md:38`.
5. [non-blocking] README: rephrase the folder BLUF without the semicolon, split the exit-1 bullet, and say how to re-capture the stub-backed scoped sample.
6. [non-blocking] Add `agents/` (transformed) to the build-script description or drop "only".
7. [non-blocking] Drop the sibling-worktrees edge case; optionally add the `Bash(graphify-scope:*)` allow pattern to "Permission prompts".
8. [non-blocking] Reword the scratch-repo check's comment to "runs outside the source repo"; the live `command -v` line carries the `PATH` claim.

## Questions for the Maintainer

1. CI step for the moved suite:
   (a) keep it, Linux-only, as proposed (reviewer's lean);
   (b) drop it and keep this proposal strictly to location.
2. Live RFP `2026-09-27-clauthier-improvement-verification.md` path reference:
   (a) update the one line in this change (reviewer's lean);
   (b) leave all `cdocs/` documents untouched, live or not.
