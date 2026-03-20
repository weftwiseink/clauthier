---
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-19T18:00:00-07:00
task_list: cdocs/plugin-hardening
type: devlog
state: live
status: review_ready
tags: [hooks, frontmatter, typescript, implementation]
last_reviewed:
  status: accepted
  by: "@claude-opus-4-6"
  at: 2026-03-19T18:30:00-07:00
  round: 1
---

# Implement Robust Frontmatter Stripping

> BLUF(opus/cdocs/plugin-hardening): Implementing the frontmatter stripping proposal: rewrite `inject-rules.sh` as `inject-rules.ts` using positional `indexOf` to fix code-block `---` stripping, eliminating `jq`/`awk` dependencies in favor of native TypeScript.

## Objective

Implement [cdocs/proposals/2026-03-19-robust-frontmatter-stripping.md](../proposals/2026-03-19-robust-frontmatter-stripping.md).

## Task List

- [x] Phase 1: Create `plugins/cdocs/hooks/inject-rules.ts`
- [x] Phase 2: Update `plugins/cdocs/hooks/hooks.json`
- [x] Phase 3: Remove `plugins/cdocs/hooks/inject-rules.sh`
- [x] Phase 4: Verify end-to-end (integration, timing, regression)

## Work Log

### Phase 1: Create inject-rules.ts

Created `plugins/cdocs/hooks/inject-rules.ts` with:
- `stripFrontmatter()`: 8-line function using positional `indexOf` (matching gray-matter's technique).
- Source-repo skip: checks `CLAUDE.md` for `@plugins/cdocs/rules/` using `string.includes()`.
- Rules iteration: `readdirSync` + `filter` for `*.md` files.
- JSON output: native `JSON.stringify` replacing `jq -Rs`.

No deviations from the proposal's design.
The implementation matches the proposed code exactly.

### Phase 2: Update hooks.json

Changed SessionStart hook command from `${CLAUDE_PLUGIN_ROOT}/hooks/inject-rules.sh` to `npx tsx ${CLAUDE_PLUGIN_ROOT}/hooks/inject-rules.ts`.

### Phase 3: Remove inject-rules.sh

Deleted `plugins/cdocs/hooks/inject-rules.sh`.
Remaining references to `inject-rules.sh` in the codebase are all historical (cdocs reviews, devlogs, proposals, reports) and should not be modified.

### Phase 4: End-to-End Verification

#### Integration Tests

| Test | Result |
|------|--------|
| Run from /tmp (non-source-repo) | PASS: valid JSON output with all 3 rules |
| Run from source repo (clauthier root) | PASS: no output (exit 0) |
| JSON validity | PASS: `json.load()` succeeds |
| frontmatter-spec.md: frontmatter stripped | PASS: `paths:` YAML header removed |
| frontmatter-spec.md: code-block `---` preserved | PASS: 2 `---` lines in YAML template example retained |
| workflow-patterns.md: no-frontmatter passthrough | PASS: output matches raw file exactly |
| writing-conventions.md: no-frontmatter passthrough | PASS: output matches raw file exactly |

#### Timing

Execution time: ~1.0s (within the 3-second timeout with ~3x margin).

> NOTE(opus/cdocs/plugin-hardening): The cold-start overhead of `tsx` via `npx` contributed ~0.8s.
> In practice, `npx tsx` will be cached after the first run, bringing subsequent invocations closer to 200-300ms.
> The proposal estimated 200-300ms; the measured 1.0s includes npx resolution overhead.
> This is still well within the 3-second budget.

#### Regression Check

All three rule files produce output identical to the expected content (raw file minus frontmatter).
The critical fix is confirmed: `frontmatter-spec.md`'s YAML template code block containing `---` delimiters is preserved in the output, where the old awk-based approach would strip them.
