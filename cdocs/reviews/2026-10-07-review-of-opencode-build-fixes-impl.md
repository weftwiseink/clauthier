---
review_of: cdocs/devlogs/2026-10-07-opencode-build-fixes-impl.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T18:47:18-07:00
task_list: build/opencode-build-fixes
type: review
state: live
status: done
tags: [fresh_agent, runtime_validated, test_plan, minimal_invasiveness, opencode, multi-target]
---

# Review: OpenCode Build Fixes Implementation (Round 1)

> BLUF(opus-5-5/build/opencode-build-fixes): Accept.
> The implementation of [`2026-10-07-opencode-build-fixes.md`](../proposals/2026-10-07-opencode-build-fixes.md) matches the design and touches nothing under `plugins/`.
> I re-ran the verification floor in the worktree and in scratch roots: the build is clean, `bash-runner` has its full description, wildcard agents load in OpenCode 1.17.5 with `* allow`, no `model:` lines remain, and the test fails on every failure picture I tried.
> All findings are non-blocking.

## Summary Assessment

The work fixes three bugs in `scripts/build-opencode.ts`: the empty multi-line `bash-runner` description, the all-false tools block on `tools: "*"` agents, and the unknown pinned model ids.
It also replaces the CI grep check, which always failed, with a `node:test` regression test.
The code is small and correct: the parser and model changes are net deletions (372 to 365 lines), and the added code is `normalizeTools` plus a per-agent try/catch.
Hard Requirement 1 holds: `git diff --stat main...HEAD -- plugins/` is empty, and every changed path outside `cdocs/` is in the OC build path.
The devlog's verification claims reproduce, including its Phase 1 byte-identity claim.
Verdict: **Accept**, with five non-blocking notes.

## Evidence (reviewer-produced)

All artifacts are under `$R` = `/tmp/claude-1000/-var-home-mjr-code-weft-clauthier-main/63ac45de-462d-4f43-ae1c-4ab6d59049b8/scratchpad/rev-1/`.
Scratch roots (`$R/roots/<name>/`) copy `scripts/`, `plugins/cdocs/`, and `package.json`, and symlink the worktree's `node_modules`.

| check | result | artifact |
|---|---|---|
| `npm ci` | exit 0, lockfile untouched (`git status` clean) | `$R/npm-ci.log` |
| `npm run build:cdocs` | exit 0, `Agents converted: 7`, no `Unknown CC tool` or skip warning | `$R/build.log` |
| `bash-runner.md` description | `description: \|` plus seven body lines, from `Run one expected-verbose ...` to `Responds with a report ...` | `$R/oc-frontmatter.txt` |
| wildcard agents | `implementer`/`proposer`/`reviewer`: `description` and `mode: subagent` only, with no `tools`/`permission` | `$R/oc-frontmatter.txt` |
| pre-change vs post-change | `judge`/`nit-fix`/`triage`/`bash-runner` have the same `tools`/`permission` values. All seven bodies are identical. The only frontmatter diffs are `model` dropped, the wildcard `tools` dropped, and the `bash-runner` description restored. Non-agent output (skills, rules, plugins, package.json) is byte-identical (`diff -rq` lists only the seven agents) | `$R/pre-vs-post.txt`, `$R/pre-vs-post-tree.txt`, `$R/pre-build.log` |
| Phase 1 alone (`46c16cd`) vs pre-change | `diff -r` shows only the seven added `bash-runner` description lines, which confirms the devlog's claim | `$R/pre-vs-phase1.diff` |
| model ids | `grep -l '^model:'` and `grep -rn 'anthropic/'` over the agents: no output (exit 1) | (inline) |
| `npm run test:opencode` | exit 0, `pass 8 fail 0` | `$R/test.log` |
| `npm pack --dry-run` | exit 0, `@weftwise/cdocs-opencode` 0.1.0, 39 files | `$R/pack.log` |
| `tsc --noEmit -p .` | exit 0, 0 errors (strict, includes `scripts/**`) | `$R/tsc-project.log` |
| OpenCode load | `opencode agent list --pure` (1.17.5) exit 0, all seven `(subagent)`. `implementer`'s first rule is `{"permission": "*", "action": "allow"}` with no edit deny. `nit-fix` has `edit ask` and `bash deny` | `$R/oc-agent-list.log` |

Mutation spot-checks of the test:

| mutation | build | test | failures |
|---|---|---|---|
| Ma: new test against pre-change output (`$R/roots/pre`) | exit 0, three `Unknown CC tool ""*""` | exit 1, 1 pass / 7 fail | `OC description must be non-empty` (bash-runner), `unexpected tools block: {"read":false,"edit":false,...}` (wildcard), `unexpected model: "anthropic/claude-..."` (pinned) |
| Mb: `!toolNames.includes("*")` removed | exit 0 | exit 1, 5 / 3 | implementer, proposer, reviewer: `unexpected tools block` |
| Step 8 recipe: second `description: Use when: x` key in `judge.md` | exit 0, `Skipping agent judge.md: frontmatter could not be parsed: Map keys must be unique at line 7, column 1`, six agents | exit 1, 7 / 1 | `.../judge.md was not generated` |

Logs: `$R/ma-pre-test.log`, `$R/mb-build.log`, `$R/mb-test.log`, `$R/s8-build.log`, `$R/s8-test.log`.

Edge-case root (`$R/roots/edge`, 13 synthetic agents next to the real seven; outputs in `$R/edge-output.txt`, logs `$R/edge-build.log`, `$R/edge-test.log`):

- Absent `description`: emits no description, matching the proposal. The test flags it with `OC description must be a string`.
- `tools: ""`, `tools:` (null), and `tools: 5`: no tools block. `5` warns `Unrecognized CC tools value 5`.
- `model: inherit` plus a `skills:` sequence: both dropped, as intended.
- `tools: [Read, Bash]` (flow sequence): `read`/`bash` true, the others false.
- `description: "Use when: x # not a comment"` comes out re-quoted and round-trips.
  `description: 42` comes out as `"42"`.
- A `|` description with trailing spaces keeps them in the block scalar.
- Unquoted `description: Use when: x`, scalar frontmatter, CRLF line endings, and a file without a newline after the closing `---` are each skipped with a named warning.
  The build exits 0 with the other 16 converted, and the test reports each skipped agent as `was not generated`.

## Section-by-Section Findings

### Hard Requirement 1: minimal invasiveness, no burden on Claude Code

**Satisfied. This is the explicit finding the maintainer asked for.**

- `git diff --stat main...HEAD -- plugins/` is empty: no change to the CC authoring format, rules, skills, agents, hooks, README, `plugin.json`, or install.
- The changed paths outside `cdocs/` are `.github/workflows/opencode-build.yml`, `package.json`, `package-lock.json`, `scripts/build-opencode.ts`, and `scripts/build-opencode.test.ts`, all in the allowed set.
- `yaml` is a devDependency of the private root `package.json`.
  It is not in the generated OC `package.json` and is not shipped with the CC plugin.
  CC hooks run `npx tsx ${CLAUDE_PLUGIN_ROOT}/...` and do not import it.
  The lockfile diff adds only `node_modules/yaml` and drops an `extraneous` `build/cdocs/opencode` entry, so `tsx` and the other existing devDependencies are unchanged.
- New CI path triggers: `package.json` and `package-lock.json` hold only OC build scripts and devDependencies, and `scripts/build-opencode.test.ts` is OC-only.
  `plugins/cdocs/**` triggered the workflow already.
  Job-level `continue-on-error: true` is kept at line 31.
  The burden on CC-only PRs goes down: the old grep step required `model:` in every agent, so it failed on every run (`implementer`/`proposer` have no model), and it now passes.
  `cdocs-hooks.yml`, the CC workflow, is untouched.
- The new test makes no CC authoring rule.
  Its checks (OC output exists, parses, keeps the description, has no model, maps tools) concern OC output, and failures surface only in non-blocking CI.
- Smallest reasonable fix: yes.
  Nothing is over-built: no build-time guard, no model resolver, no `permission` migration, no unit tests on internals.
  `normalizeTools` handles string, sequence, and null as the proposal specifies.
  Its one extra branch, a warning for other types, is three lines and serves Hard Requirement 2.

### Hard Requirement 2 / Verification step 8: warn and skip

**Satisfied.**
The recipe reproduces exactly: exit 0, one warning naming `judge.md` and the parser error, six agents, and a summary line `Agents skipped (frontmatter parse errors): judge.md`.
The output directory is `rmSync`'d before each build, so a stale OC file cannot hide a skipped agent from assertion 1.

- **Non-blocking: the catch is broader than its label.**
  The try/catch wraps the whole `convertAgent` call: the read, the parse, `generateOCFrontmatter`, and `rewriteBodyPaths`.
  Any error there is reported as `frontmatter could not be parsed` and counted in `Agents skipped (frontmatter parse errors)`.
  That includes a future `TypeError` in the emitter.
  The build stays green and only the test's assertion 1 catches it.
  Rewording both strings to "could not be converted" would make the message accurate at no cost.
  Narrowing the try/catch to `parseFrontmatter` is the alternative, at the cost of a slightly larger change.

### `scripts/build-opencode.ts`: correctness and quality

- `parseFrontmatter`: keeps the delimiter regex, uses `YAML.parse`, and rejects non-mapping results.
  The `CCFrontmatter` type now types `description`/`tools` as `unknown`, which is honest after `YAML.parse`.
  `model` is removed from the interface but still reachable through the index signature, which is fine since it is never read.
- `generateOCFrontmatter`: the key order (`description`, `mode`, `tools`, `permission`) matches the previous output.
  `lineWidth: 0` keeps single-line output identical, which Phase 1 byte-identity confirms.
  The `String()` guard on `undefined`/`null` is correct.
- Body preservation: `ocFrontmatter + "\n" + body` is unchanged, and all seven bodies are byte-identical to the pre-change build.
- **Non-blocking: CRLF agents are skipped.**
  The unchanged delimiter regex `^---\n...\n---\n` does not match CRLF files, so with `core.autocrlf=true` (common on Windows) every agent would be skipped with `No frontmatter found`.
  Before this change the same input crashed the whole build, so this is an improvement in line with Hard Requirement 2.
  `\r?\n` in both the build regex and the test regex would close it.
  It is outside the three bugs, so leaving it is defensible.
- **Non-blocking, contrived: a non-scalar `description`** (an accidental YAML mapping) becomes `"[object Object]"`.
  The test's oracle uses the same `String(cc.description)`, so it would not flag this.
  No real agent is close to this shape.

### `scripts/build-opencode.test.ts`

- It covers assertions 1-5 as specified: one test per agent plus a non-empty guard, and type-clean under the repo `tsconfig.json`.
- It catches every named failure picture: the empty description (Ma), the all-false tools on wildcard agents (Ma, Mb), any `model:` (Ma), and a skipped agent (step 8).
- Its tools normalization is written separately from the build's, which is the right call.
- **Non-blocking: the oracle shares two design assumptions with the build.** Both treat `tools: ""` as "all tools", and both coerce `description` with `String()`.
  The test checks agreement with the design, not CC semantics.
  The proposal chose "empty means all tools" on purpose, and no real agent has `tools: ""`.
  Whether CC treats an empty string as "no tools" or "all tools" was not checked against CC docs here.
  If CC means "no tools", an empty value would over-grant on OC.
- REPO_ROOT uses `new URL(import.meta.url).pathname`, the same pattern as the build script.
  It breaks on paths that need percent-encoding, which is pre-existing and harmless for CI.

### `.github/workflows/opencode-build.yml`

- The steps are consistent: checkout, setup-node 22, `npm ci`, `npm run test:opencode` (build plus test, one build), then `npm pack --dry-run` in `build/cdocs/opencode`.
  The header comment has been updated for the new triggers.
- **Non-blocking:** not exercised on GitHub Actions or Node 22 (local is Node 26).
  `yaml` needs Node `>= 14.6` and `tsx --test` works on 22, so the risk is low, and the first PR run will confirm it.
- The "optionally publishes" header stays, deferred per the proposal.

### Model omission (Decision 3)

This is implemented as designed.
OpenCode's agent listing does not show the resolved model, so inheritance rests on the OC docs.
I could not observe it empirically either, which matches the devlog's own caveat.
The proposal accepted this risk, and it still goes to the maintainer as a judgment call.

### Sub-devlog quality

The devlog is accurate and resumable, and its claims reproduce: the Phase 1 byte-identity, the mutation table, the step 8 warning text, and the OC load.
It lists the incidental npm normalizations (dropping `"dependencies": {}` and the extraneous lock entry) and the lockfile `name` reset.
"No deviations from the proposal's design" is fair.
The extras (rejecting non-mapping frontmatter, the unrecognized-tools warning, the skipped-count summary) are small applications of Hard Requirement 2 and are described in the Implementation Notes.

## Verdict

**Accept.**
All three bugs are fixed, and both hard requirements hold under independent verification.
The test detects the failure pictures, and nothing under `plugins/` changes.
The items below are optional polish.

## Action Items

1. [non-blocking] Reword the per-agent catch warning and summary line from "frontmatter could not be parsed" to "could not be converted", or narrow the try/catch to `parseFrontmatter`.
2. [non-blocking] Consider `\r?\n` in the build and test delimiter regexes so CRLF checkouts are not skipped wholesale. This is outside the three bugs and can be deferred.
3. [non-blocking] Confirm CC's semantics for `tools: ""` (empty string). If CC means "no tools", map it to the explicit-list path (all false) instead of omission. No current agent is affected.
4. [non-blocking] Watch the first GitHub Actions run (Node 22) on the PR to confirm `npm run test:opencode` and `npm pack --dry-run` pass there.
5. [non-blocking, maintainer] Decision 3 (omit `model`) and the deferred `plugins/cdocs/README.md` "model mapping" phrase remain maintainer calls, as the proposal states.

## Questions for the maintainer

- **`tools: ""` semantics on OC:** (a) keep omission, meaning all tools, as implemented; (b) treat it as explicit-empty, meaning all four OC tools false; (c) warn and keep omission.
- **CRLF tolerance:** (a) leave as is, so CRLF agents are skipped with a warning; (b) accept `\r?\n` in the delimiter regexes now, a one-line change in each of the two files.
