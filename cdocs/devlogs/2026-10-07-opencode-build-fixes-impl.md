---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T18:39:32-07:00
task_list: build/opencode-build-fixes
type: devlog
state: live
status: review_ready
part_of: cdocs/devlogs/2026-10-07-opencode-build-fixes.md
tags: [build, opencode, yaml, multi-target]
---

# OpenCode Build Fixes: Implementation

> BLUF(opus-5-5/build/opencode-build-fixes): All three phases of [`2026-10-07-opencode-build-fixes.md`](../proposals/2026-10-07-opencode-build-fixes.md) are implemented on branch `opencode-build-fixes` (`4ded3b7..` this devlog's final commit), with Verification steps 0-8 passing.
> `bash-runner` gets its full description, wildcard agents emit no `tools`/`permission` block, no agent emits `model:`, and an unparseable agent is skipped with a warning.
> The new `node:test` regression test passes 8/8 and fails on the pre-fix output and on each reverted fix.
> Nothing under `plugins/` changed.
> No deviations from the proposal's design.

## Objective

Implement the accepted proposal `cdocs/proposals/2026-10-07-opencode-build-fixes.md` (round 2 accept: `cdocs/reviews/2026-10-07-review-of-opencode-build-fixes-r2.md`).
Changes stay in the OC build path: `scripts/build-opencode.ts`, `scripts/build-opencode.test.ts`, root `package.json`/`package-lock.json`, `.github/workflows/opencode-build.yml`.
Nothing under `plugins/` changes.

## Scratchpoint

- next_steps: loop reviewer reviews code and the Verification evidence below; implementation complete, no open work.
- important_files: `scripts/build-opencode.ts`, `scripts/build-opencode.test.ts`, `.github/workflows/opencode-build.yml`, `package.json`
- callouts:
  - decision: base commit for the `plugins/` diff check is `1d1695c` (the branch's merge base with `main` is earlier; `git diff --stat main...HEAD -- plugins/` is also empty).
  - decision: `package-lock.json` top-level `name` reset to `main` after `npm i` rewrote it to the worktree directory name `opencode-build-fixes`.
  - note: `npm i` also dropped the lock's extraneous `build/cdocs/opencode` entry and the empty `"dependencies": {}` in `package.json`; both are npm's own normalization, harmless to `npm ci`.
  - todo (maintainer, out of scope per HR1): `plugins/cdocs/README.md` still says the build does "model mapping".
  - blocker:

## Plan

1. Step 0 baseline: build, snapshot `build/cdocs/opencode/agents/` to scratch.
2. Phase 1: `yaml` devDependency, `YAML.parse` in `parseFrontmatter`, per-agent warn-and-skip, `YAML.stringify` emitter.
3. Phase 2: normalize `tools`, omit for absent/`*`; delete `MODEL_MAP`.
4. Phase 3: `scripts/build-opencode.test.ts`, `test:opencode` script, workflow update.
5. Verification steps 1-8, including revert-each-fix mutation checks.

## Testing Approach

Phases 1-2 are checked against the step 0 baseline by parsing old and new frontmatter and diffing values.
Phase 3 adds the `node:test` regression test over all real agents, then each fix is reverted in turn to confirm the matching assertion fails.

## Implementation Notes

- **Parse (Phase 1).** `parseFrontmatter` keeps the delimiter regex and calls `YAML.parse`, throwing if the result is not a mapping (a scalar or list frontmatter would otherwise be treated as an object).
  `main` wraps `convertAgent` per agent in try/catch: any conversion error (no delimiters, YAML error, non-mapping) warns `Skipping agent <file>: frontmatter could not be parsed: <message>`, the agent is skipped, and the summary reports converted and skipped counts.
- **Emit (Phase 1).** `generateOCFrontmatter` builds `{description, mode, tools?, permission?}` and returns `"---\n" + YAML.stringify(oc, { lineWidth: 0 }) + "---"`.
  `description` is set via `String(...)` only when it is neither `undefined` nor `null`.
  Phase 1 output is byte-identical to the step 0 baseline for six agents; `bash-runner.md` differs only by its seven restored description lines.
- **Tools (Phase 2).** New `normalizeTools(unknown): string[]`: string splits on commas, array used as-is, `null`/absent is empty; anything else warns and is treated as absent.
  Names are trimmed and empties dropped.
  Empty or containing `*` emits no block; otherwise `mapTools` (now taking `string[]`, mapping body unchanged) emits the four booleans and `permission`.
- **Model (Phase 2).** `MODEL_MAP`, the `model:` emission, and the unknown-alias warning are deleted; the "Dropped fields" comment now lists `model` with the inheritance rationale.
- **Test (Phase 3).** `scripts/build-opencode.test.ts` parses CC and OC frontmatter with `yaml` and checks assertions 1-5 per agent, one `test()` per agent plus a guard that at least one CC agent exists.
  Its tools-normalization is written independently of the build's (an oracle, not a shared helper), per the proposal's "no unit tests on internals".
- **CI (Phase 3).** One `npm run test:opencode` step replaces "Build OC artifacts" and the bash grep step; path triggers gain the test, `package.json`, `package-lock.json`; `continue-on-error: true` and `npm pack --dry-run` unchanged.
  The workflow header still says "optionally publishes" (left as-is, per the proposal's Deferred list).

## Changes Made

| file | change |
|---|---|
| `package.json` | `yaml` ^2.9.1 devDependency; `test:opencode` script |
| `package-lock.json` | `yaml` 2.9.1 entry; npm dropped the extraneous `build/cdocs/opencode` entry |
| `scripts/build-opencode.ts` | `YAML.parse`/`YAML.stringify`, per-agent warn-and-skip, `normalizeTools` with wildcard/absent omission, `MODEL_MAP` deleted |
| `scripts/build-opencode.test.ts` | new `node:test` regression test (assertions 1-5) |
| `.github/workflows/opencode-build.yml` | `npm run test:opencode` replaces build + grep steps; path triggers extended |
| `cdocs/proposals/2026-10-07-opencode-build-fixes.md` | `status: implementation_wip` (frontmatter only) |

Commits: `4ded3b7` (devlog start), `076dfef` (yaml dep), `46c16cd` (Phase 1), `10af277` (tools), `7427e9d` (model), `33f0a73` (test), `74b74a2` (CI).

## Verification

Scratch dir (`$S`): `/tmp/claude-1000/-var-home-mjr-code-weft-clauthier-main/63ac45de-462d-4f43-ae1c-4ab6d59049b8/scratchpad`.

**Step 0 (baseline, pre-Phase 1, HEAD `1857fcd`):** `npm run build:cdocs` exit 0, log `$S/step0-build.log`, agents copied to `$S/baseline-agents/`.
Baseline shows the three bugs: `bash-runner.md` has `description: |` then `mode: subagent`; `implementer.md` has `read/edit/write/bash: false` with warning `Unknown CC tool ""*""` (three times); `judge.md` has `model: anthropic/claude-opus-4-20250514`.

**Phase checks against baseline:** `$S/cmp.mjs` parses both trees' frontmatter with `yaml` and compares values and bodies.
- After Phase 1 (`$S/phase1-agents/`): only `bash-runner.md` frontmatter differs (description `""` -> the seven-line text); all bodies identical; `diff -r` shows only the seven added description lines.
- After Phase 2 (`$S/phase2-build.log`): vs baseline, every agent loses `model`; `implementer`/`proposer`/`reviewer` lose `tools`; `bash-runner` gains its description; `judge`/`nit-fix`/`triage`/`bash-runner` `tools`/`permission` values are unchanged; all bodies identical.

**Step 1:** `npm ci` exit 0 (`$S/step1-ci.log`); `npm run build:cdocs` exit 0 (`$S/step1-build.log`), `Agents converted: 7`.
No `Unknown CC tool` or skip warning; the only warning line is Node's pre-existing `[DEP0205] module.register()` deprecation from tsx.

**Step 2:** `build/cdocs/opencode/agents/bash-runner.md`:
```
---
description: |
  Run one expected-verbose shell command, capture its output to a scratch file, and return a fixed-format report without the raw output.
  Prompt with:
  - Exact or approximate command
  - What return info is wanted (say "every" if needed: "every failing test with file:line and expected vs actual", "every call site as file:line")
  - Specify salient info/results if applicable

  Responds with a report with all required info for follow-ups, rereads, etc.
mode: subagent
```

**Step 3:** `grep -nE '^(tools|permission):'` over `implementer.md proposer.md reviewer.md`: no matches (exit 1).
`judge`/`nit-fix`/`triage`/`bash-runner` `tools`/`permission` equal the baseline (cmp above).

**Step 4:** `grep -l '^model:' build/cdocs/opencode/agents/*.md`: no output (exit 1); `grep -rn 'anthropic/claude' build/cdocs/opencode/agents`: no output (exit 1).

**Step 5:** `npm run test:opencode` exit 0, `pass 8 fail 0` (`$S/step5-test.log`, `$S/step6-test.log`).
Revert-each-fix, each in a scratch root built by `$S/mkroot.sh` (copies `scripts/`, `plugins/cdocs/`, `package.json`, symlinks `node_modules`), build then `tsx --test`:

| mutation | build | test | failing agents | assertion message |
|---|---|---|---|---|
| m0: pre-fix output (`$S/baseline-agents/`) | n/a | exit 1, 1 pass / 7 fail | all seven | `OC description must be non-empty` (bash-runner), `unexpected tools block` (wildcard), `unexpected model: ...` (pinned) |
| m1: old line scanner restored | exit 0 | exit 1, 4/4 | bash-runner, implementer, proposer, reviewer | `OC description must round-trip` (bash-runner emits `description: "\|"`), `unexpected tools block` (`"*"` keeps its quotes) |
| m2: `*` check removed | exit 0 | exit 1, 5/3 | implementer, proposer, reviewer | `unexpected tools block: {"read":false,"edit":false,"write":false,"bash":false}` |
| m3: model map restored | exit 0 | exit 1, 3/5 | bash-runner, judge, nit-fix, reviewer, triage | `unexpected model: "anthropic/claude-..."` |
| m4: duplicate `description` key in `judge.md` | exit 0, 6 agents | exit 1, 7/1 | judge | `.../judge.md was not generated` |

Logs: `$S/m{0..4}-*-test.log`, `$S/m{1..4}-*-build.log`; roots under `$S/roots/`.

**Step 6:** `npm run test:opencode` exit 0; `(cd build/cdocs/opencode && npm pack --dry-run)` exit 0, `@weftwise/cdocs-opencode` 0.1.0, 39 files (`$S/step6-pack.log`).
`grep -n continue-on-error .github/workflows/opencode-build.yml` -> `31:    continue-on-error: true`.
Parsed with `yaml`: steps are checkout, setup-node, `npm ci`, "Build OC artifacts and run regression test", "Validate npm package".
Not run on GitHub Actions itself (Node 22 there, Node 26 locally).

**Step 7:** `git diff --stat 1d1695c..HEAD -- plugins/` is empty.
Changed paths outside `cdocs/`: `.github/workflows/opencode-build.yml`, `package-lock.json`, `package.json`, `scripts/build-opencode.test.ts`, `scripts/build-opencode.ts`, all in the allowed set.

**Step 8:** scratch root `$S/roots/m4-skip/`, `judge.md` with `description: Use when: x` appended as a second key; `npx tsx $S/roots/m4-skip/scripts/build-opencode.ts` exit 0, six agents generated, warnings:
```
  Warning: Skipping agent judge.md: frontmatter could not be parsed: Map keys must be unique at line 7, column 1:
  Agents skipped (frontmatter parse errors): judge.md
```

**Extra (beyond floor): OpenCode load.** Generated agents copied to `$S/oc-load/.opencode/agent/`; `opencode agent list --pure` (OpenCode 1.17.5) exit 0, all seven listed as `(subagent)`, no errors (`$S/oc-agent-list.log`).
`implementer`'s resolved rules equal built-in `general`'s minus `general`'s own `todowrite deny`; `bash-runner` resolves to `read * deny`, `edit * deny`, `bash * allow`.
The listing does not show the effective model, so model inheritance rests on the OC docs.
