---
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-18T10:00:00-07:00
task_list: marketplace/build-workspace
type: devlog
state: live
status: wip
tags: [architecture, build-system, workspace, opencode, implementation]
---

# Build Workspace Reorganization: Devlog

## Objective

Implement the accepted proposal `cdocs/proposals/2026-03-17-build-workspace-reorganization.md`.
Move OC build output from committed `plugins/cdocs/opencode/` to gitignored `build/cdocs/opencode/`, add root workspace config, relocate build script and hand-written files, and update CI/docs.

## Plan

### Phase 1: Workspace setup and build script relocation
1. Add root `package.json` with `build` and `build:cdocs` npm scripts.
2. Add root `tsconfig.json` scoped to `scripts/`.
3. Move `plugins/cdocs/scripts/build-opencode.ts` to `scripts/build-opencode.ts`.
4. Move `plugins/cdocs/opencode/scripts/postinstall.js` to `plugins/cdocs/scripts/postinstall.js`.
5. Move `plugins/cdocs/opencode/plugins/cdocs-hooks.ts` to `plugins/cdocs/hooks/cdocs-hooks.ts`.
6. Refactor build script: new output dir, plugin arg, clean slate, copy hand-written files.
7. Update `.gitignore` (add `build/`, `node_modules/`).
8. Simplify `.gitattributes`.
9. Delete `plugins/cdocs/opencode/`.
10. Verify: `npm install && npm run build:cdocs`.

### Phase 2: CI and documentation updates
1. Update `.github/workflows/opencode-build.yml`.
2. Update `CLAUDE.md`.
3. Update `plugins/cdocs/README.md`.
4. Final build verification.

### Phase 3: Self-usage verification
1. Add built OC plugin to clauthier project config.
2. Launch nested opencode CLI to verify skills, rules, agents load.

## Testing Approach

Build verification: `npm install && npm run build:cdocs` must succeed, output must match prior `plugins/cdocs/opencode/` content structurally.
`npm pack --dry-run` in build output must succeed.
Self-usage: install the built plugin into this project's opencode config and verify via CLI.

## Implementation Notes

## Changes Made

| File | Description |
|------|-------------|

## Verification
