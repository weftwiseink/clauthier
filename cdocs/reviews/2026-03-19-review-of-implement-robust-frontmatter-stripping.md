---
review_of: cdocs/devlogs/2026-03-19-implement-robust-frontmatter-stripping.md
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-19T18:30:00-07:00
task_list: cdocs/plugin-hardening
type: review
state: live
status: done
tags: [self, runtime_validated, hooks, frontmatter, typescript, implementation]
---

# Review: Implement Robust Frontmatter Stripping

## Summary Assessment

This devlog documents the implementation of the frontmatter stripping proposal: rewriting `inject-rules.sh` as `inject-rules.ts` with an 8-line `stripFrontmatter()` function.
The implementation matches the proposal's design exactly, with no deviations.
All four phases were completed and verified with a thorough integration test table.
The critical fix is confirmed: `frontmatter-spec.md`'s code-block `---` lines are preserved in the output.

Verdict: **Accept** with two non-blocking observations.

## Section-by-Section Findings

### Code: `inject-rules.ts`

The implementation is a faithful 1:1 port of the proposal's code (lines 88-133 of the proposal).
Verified against the diff: every line matches.

The `stripFrontmatter()` function correctly handles:
- Files with frontmatter (strips `---`-delimited header, preserves body).
- Files without frontmatter (early return on `startsWith` check).
- Files with only frontmatter and no body (returns empty string).
- Files with `---` inside code blocks (positional `indexOf` stops at the first `\n---` after the opener).

One subtlety worth noting: `indexOf('\n---', 3)` matches any line starting with `---`, including `----` or `---stuff`.
The proposal acknowledged this explicitly (section "Frontmatter with trailing content") and accepted it as correct for cdocs files.
This is a reasonable decision; cdocs frontmatter always uses bare `---`.

The source-repo skip logic is clean: `existsSync` + `readFileSync` + `includes` replaces the `grep -q` subprocess.
The `process.exit(0)` early return is correct.

The non-null assertion on `process.env.CLAUDE_PLUGIN_ROOT!` is intentional; the proposal documents the failure mode (Node throws at `join(undefined, 'rules')`).

**Non-blocking**: The file lacks the executable bit (`-rw-r--r--`), so the shebang line cannot be used for direct execution via `./inject-rules.ts`.
This is cosmetic since `hooks.json` invokes via `npx tsx`, not direct execution.
Adding `chmod +x` would make manual testing marginally easier.

### Configuration: `hooks.json`

The command change from `${CLAUDE_PLUGIN_ROOT}/hooks/inject-rules.sh` to `npx tsx ${CLAUDE_PLUGIN_ROOT}/hooks/inject-rules.ts` matches the proposal's specification.
The timeout remains at 3 seconds, which the timing test confirmed is sufficient (~1.0s execution).

### Deletion: `inject-rules.sh`

Correctly removed.
The grep for remaining references shows only historical cdocs documents (reviews, proposals, devlogs, reports), which should not be modified.

### Proposal Status

Updated to `implementation_wip`, which is correct per the implement skill's conventions.

### Verification: Phase 4

The integration test table covers all seven test cases from the proposal's test plan:
1. Non-source-repo execution (valid JSON).
2. Source-repo skip (no output).
3. JSON validity.
4. frontmatter-spec.md frontmatter stripped.
5. frontmatter-spec.md code-block `---` preserved.
6. workflow-patterns.md passthrough.
7. writing-conventions.md passthrough.

The timing result (~1.0s) is higher than the proposal's estimate (200-300ms) but well within the 3-second budget.
The NOTE callout correctly attributes the discrepancy to `npx` resolution overhead on cold start.

**Non-blocking**: The proposal's Verification Methodology section (lines 259-264) calls for a "before/after" diff comparing old shell script output to new TypeScript output.
The devlog does not include this diff because the shell script was deleted before the comparison could be captured.
The regression check section states that "all three rule files produce output identical to the expected content," which is a reasonable substitute.
However, a stricter interpretation would have captured the old output first, then deleted the script.
This is a minor process observation, not a correctness concern: the per-file content comparison against raw file contents achieves the same assurance.

### Devlog Quality

The devlog follows cdocs conventions: BLUF, sentence-per-line, task list with checkboxes, structured work log sections.
The NOTE callout on timing is properly attributed.
The devlog provides sufficient context for work resumption.

## Verdict

**Accept.**
The implementation is a clean, exact port of the proposal's design.
All test cases pass.
The core bug (code-block `---` stripping) is fixed.
No deviations from the proposal.

## Action Items

1. [non-blocking] Consider adding executable permission to `inject-rules.ts` (`chmod +x`) to enable direct `./inject-rules.ts` execution for manual testing, consistent with the shebang line.
2. [non-blocking] Future implementations could capture the "before" output of the replaced component before deleting it, to enable the before/after diff comparison specified in the proposal's Verification Methodology.
