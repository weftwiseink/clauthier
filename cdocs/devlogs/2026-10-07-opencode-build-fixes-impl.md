---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T18:39:32-07:00
task_list: build/opencode-build-fixes
type: devlog
state: live
status: wip
part_of: cdocs/devlogs/2026-10-07-opencode-build-fixes.md
tags: [build, opencode, yaml, multi-target]
---

# OpenCode Build Fixes: Implementation

> BLUF(opus-5-5/build/opencode-build-fixes): Implementation sub-devlog for [`2026-10-07-opencode-build-fixes.md`](../proposals/2026-10-07-opencode-build-fixes.md), all three phases, on branch `opencode-build-fixes`.

## Objective

Implement the accepted proposal `cdocs/proposals/2026-10-07-opencode-build-fixes.md` (round 2 accept: `cdocs/reviews/2026-10-07-review-of-opencode-build-fixes-r2.md`).
Changes stay in the OC build path: `scripts/build-opencode.ts`, `scripts/build-opencode.test.ts`, root `package.json`/`package-lock.json`, `.github/workflows/opencode-build.yml`.
Nothing under `plugins/` changes.

## Scratchpoint

- next_steps: Phase 1 (yaml parse/emit).
- important_files: `scripts/build-opencode.ts`, `scripts/build-opencode.test.ts`, `.github/workflows/opencode-build.yml`, `package.json`
- callouts:
  - decision: base commit for the `plugins/` diff check is `1d1695c`.
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

## Changes Made

| file | change |
|---|---|

## Verification

Scratch dir (`$S`): `/tmp/claude-1000/-var-home-mjr-code-weft-clauthier-main/63ac45de-462d-4f43-ae1c-4ab6d59049b8/scratchpad`.

**Step 0 (baseline, pre-Phase 1, HEAD `1857fcd`):** `npm run build:cdocs` exit 0, log `$S/step0-build.log`, agents copied to `$S/baseline-agents/`.
Baseline shows the three bugs: `bash-runner.md` has `description: |` then `mode: subagent`; `implementer.md` has `read/edit/write/bash: false` with warning `Unknown CC tool ""*""` (three times); `judge.md` has `model: anthropic/claude-opus-4-20250514`.
