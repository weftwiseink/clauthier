---
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-18T10:00:00-07:00
task_list: marketplace/build-workspace
type: devlog
state: live
status: review_ready
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

### Phase 1 deviation: `type: module` and `@types/node`
The proposal's `package.json` lacked `"type": "module"` which is required for `tsc --noEmit` to accept `import.meta.url` in the build script.
Added `"type": "module"` and `@types/node` as a devDependency.
This is a minor addition to the proposal's spec: the proposal mentioned `tsconfig.json` but did not detail the `type` field or node types.

### Phase 3 deviation: cdocs-hooks.ts API rewrite
> NOTE(opus/marketplace/build-workspace): The original `cdocs-hooks.ts` used a CC-style plugin API (`export default { setup(plugin) { plugin.on(...) } } satisfies Plugin`) with `import type { Plugin } from "opencode"`.
> OC's actual plugin API expects an async function returning a hook map: `const plugin: Plugin = async (ctx) => { return { "tool.execute.after": async (input, output) => { ... } } }` with `import type { Plugin } from "@opencode-ai/plugin"`.
> This was a pre-existing bug in the multi-target marketplace implementation, not a defect introduced by this reorganization.
> The fix was straightforward: rewrite the export shape and import path.

### Phase 3 deviation: local plugin loading
The proposal's README docs suggest `npm install @weftwise/cdocs-opencode` then `"plugin": ["@weftwise/cdocs-opencode"]` in `opencode.json`.
In practice, OC's npm plugin resolution uses its own Bun-based cache (`~/.cache/opencode/node_modules/`), not the project's `node_modules/`.
For local development, the correct approach is:
1. `npm install ./build/cdocs/opencode` (triggers postinstall to copy skills/rules)
2. Copy hooks file to `.opencode/plugins/cdocs-hooks.ts` (auto-loaded by OC)
This is documented but could be made smoother with a build script post-step.

## Changes Made

| File | Description |
|------|-------------|
| `package.json` | New: root workspace config with build scripts, type: module |
| `package-lock.json` | New: lockfile for reproducible builds |
| `tsconfig.json` | New: TS config scoped to scripts/ |
| `scripts/build-opencode.ts` | Moved from `plugins/cdocs/scripts/`, refactored for new output dir |
| `plugins/cdocs/scripts/postinstall.js` | Moved from `plugins/cdocs/opencode/scripts/` |
| `plugins/cdocs/hooks/cdocs-hooks.ts` | Moved from `plugins/cdocs/opencode/plugins/`, rewritten for OC plugin API |
| `.gitignore` | Added `build/`, `node_modules/`, `.opencode/skills/`, `.opencode/plugins/` |
| `.gitattributes` | Simplified: removed `linguist-generated` markers |
| `.github/workflows/opencode-build.yml` | Replaced dirty-check with build+validate, updated paths |
| `CLAUDE.md` | Updated Multi-Target Marketplace section |
| `plugins/cdocs/README.md` | Updated Building OC artifacts section |
| `opencode.json` | Kept minimal (no plugin array for local dev) |
| `plugins/cdocs/opencode/` | Deleted: 24 committed generated files |

## Verification

### Build from clean state
```
$ rm -rf build/cdocs && npm run build:cdocs
build-opencode: Starting CC-to-OC conversion for plugin "cdocs"...
  Agents converted: 3
  Output: /var/home/mjr/code/weft/clauthier/main/build/cdocs/opencode
```

### Type checking
```
$ npx tsc --noEmit
(no errors)
```

### npm pack validation
```
$ npm pack --dry-run (in build/cdocs/opencode/)
24 files, 75.0 kB unpacked
```

### OC plugin loading (opencode run --log-level DEBUG)
```
service=plugin path=file:///.opencode/plugins/cdocs-hooks.ts loading plugin
(no errors - previously errored with "fn3 is not a function" before API rewrite)
```

### Skills registration
All 10 skills registered with permissions:
triage, status, rfp, review, report, propose, nit_fix, init, implement, devlog

### Skill execution test
```
$ opencode run "Use the /cdocs:status skill to list all cdocs documents"
- Loaded /cdocs:status and /cdocs:devlog skills
- Dispatched 3 parallel subagents to parse 87 documents
- Created a properly-formatted devlog with correct frontmatter
- Completed successfully
```

### Commit history
```
5ce8e9c refactor: move OC build output to gitignored build/ directory
8324a9b docs: update CI workflow and documentation for new build layout
4e50688 fix: add type: module and @types/node for tsc --noEmit type checking
a5715f2 fix: rewrite cdocs-hooks.ts to use OC plugin API format
eafa78b chore: update gitignore for OC artifacts, revert opencode.json plugin entry
```
