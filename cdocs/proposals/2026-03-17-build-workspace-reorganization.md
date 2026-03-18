---
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-17T00:55:00-07:00
task_list: marketplace/build-workspace
type: proposal
state: live
status: implementation_wip
tags: [architecture, build-system, workspace, gitignore, ci, npm]
last_reviewed:
  status: accepted
  by: "@claude-opus-4-6"
  at: 2026-03-17T14:00:00-07:00
  round: 1
---

# Build Workspace Reorganization

> BLUF(mjr+claude-opus-4-6/build-workspace): Move OC build output from committed `plugins/cdocs/opencode/` to gitignored `build/cdocs/opencode/`, add root `package.json` + `tsconfig.json` for build tooling, relocate the build script to `scripts/build-opencode.ts`, and replace the CI dirty-check with a build+validate+publish workflow.
> This eliminates the duplication of skills/rules in version control while preserving them in the npm tarball for standalone installs.
> The `build/<plugin>/opencode/` directory structure accommodates future plugins.
>
> - **Motivated By:** `cdocs/proposals/2026-03-14-multi-target-marketplace.md` (results_accepted) -- the current implementation commits generated OC artifacts inside `plugins/cdocs/opencode/`, coupling build output to plugin source.
> - **Key decisions already made:** Build artifacts are gitignored (not committed). Tooling is npm + tsx (no bun dependency). Skills/rules are bundled in the npm tarball. Multi-plugin ready via `build/<plugin>/opencode/` pattern.

## Objective

Separate build output from plugin source so that:

1. Generated OC artifacts (agents, skills, rules, package.json) are not committed to version control.
2. The build script has a proper execution context (root `package.json`, `tsconfig.json`).
3. The directory structure supports adding future plugins without restructuring.
4. CI builds and optionally publishes the npm package instead of enforcing a dirty check on committed artifacts.

## Background

The multi-target marketplace proposal (`2026-03-14-multi-target-marketplace.md`, results_accepted) established the CC-to-OC build pipeline.
Its implementation placed the generated `opencode/` directory inside `plugins/cdocs/`, committed to git, with a CI dirty check to keep it in sync.

This worked as a pragmatic first pass, but creates ongoing friction:

- **24 generated files committed** alongside canonical source files, distinguished only by `.gitattributes` `linguist-generated` markers and a "DO NOT EDIT" comment.
- **Skills and rules are fully duplicated** in version control: `plugins/cdocs/skills/` (canonical) and `plugins/cdocs/opencode/skills/` (generated copy). Same for `rules/`.
- **The build script** (`plugins/cdocs/scripts/build-opencode.ts`) runs via `npx tsx` with no `tsconfig.json`, no type checking, and no declared dependencies.
- **CI validates staleness** rather than building fresh, which is fragile (developers must remember to regenerate and commit).

### Current file layout (relevant parts)

```
plugins/cdocs/
  agents/            # CC canonical agents
  skills/            # CC canonical skills
  rules/             # CC canonical rules
  scripts/
    build-opencode.ts  # Build script (tsx)
  opencode/          # GENERATED, committed
    agents/          # Converted OC agents
    skills/          # Copy of skills/
    rules/           # Copy of rules/
    plugins/         # OC hooks plugin (hand-written)
    scripts/         # postinstall.js
    package.json     # Generated
```

### Target file layout

```
scripts/
  build-opencode.ts    # Relocated build script
package.json           # Root: npm scripts for build
tsconfig.json          # Root: TS config for build scripts
build/                 # GITIGNORED
  cdocs/
    opencode/          # Generated OC output
      agents/
      skills/
      rules/
      plugins/
      scripts/
      package.json
.gitignore             # build/ added
```

## Proposed Solution

### Root workspace configuration

Add a root `package.json` with npm scripts wrapping the build:

```json
{
  "private": true,
  "scripts": {
    "build": "tsx scripts/build-opencode.ts",
    "build:cdocs": "tsx scripts/build-opencode.ts cdocs"
  },
  "devDependencies": {
    "tsx": "^4.0.0",
    "typescript": "^5.0.0"
  }
}
```

Add a root `tsconfig.json` providing type checking for build scripts:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["scripts/**/*.ts"]
}
```

> NOTE: This `tsconfig.json` scopes to `scripts/` only. It does not cover plugin source files (which are markdown, shell scripts, and the hand-written OC hooks TS file).

> NOTE: The generated `package-lock.json` should be committed for reproducible `npm ci` builds in CI.

### Build script relocation and refactoring

Move `plugins/cdocs/scripts/build-opencode.ts` to `scripts/build-opencode.ts`.

Key changes to the script:

1. **Output directory**: Change from `join(PLUGIN_ROOT, "opencode")` to `join(REPO_ROOT, "build", pluginName, "opencode")`.
2. **Plugin root resolution**: Accept a plugin name argument (defaulting to `cdocs`) and resolve `plugins/<name>/` from the repo root.
3. **Repo root**: Resolve from the script's own location (`resolve(dirname(...), "..")`).
4. **OC hooks file**: The hand-written `cdocs-hooks.ts` currently lives at `plugins/cdocs/opencode/plugins/cdocs-hooks.ts`. Since `opencode/` is being gitignored, this file needs a canonical home. Move it to `plugins/cdocs/hooks/cdocs-hooks.ts` and have the build script copy it into the output. This is the one file in the current `opencode/` directory that is hand-written, not generated.

### OC hooks file relocation

The `cdocs-hooks.ts` file is currently the only hand-written file inside the generated `opencode/` directory.
It needs a canonical source location that is committed to git.

Place it at `plugins/cdocs/hooks/cdocs-hooks.ts` alongside the existing CC hook shell scripts.
The build script copies it into `build/cdocs/opencode/plugins/`.
Similarly, `postinstall.js` is hand-written and currently lives at `plugins/cdocs/opencode/scripts/postinstall.js`.
Move it to `plugins/cdocs/scripts/postinstall.js` (it can coexist with `build-opencode.ts` until the build script moves to the root).

> NOTE: After the build script moves to `scripts/build-opencode.ts`, `plugins/cdocs/scripts/` will contain only `postinstall.js` and any other plugin-specific scripts.

### Gitignore and gitattributes changes

Add `build/` to `.gitignore`.
Remove or simplify `.gitattributes` -- the `linguist-generated` markers for `plugins/cdocs/opencode/**` are no longer needed since those files will not be committed.

### CI workflow update

Replace the current dirty-check workflow with build+validate+publish:

```yaml
name: OpenCode Build

on:
  push:
    branches: [main]
    paths:
      - "plugins/cdocs/**"
      - "scripts/build-opencode.ts"
      - ".github/workflows/opencode-build.yml"
  pull_request:
    paths:
      - "plugins/cdocs/**"
      - "scripts/build-opencode.ts"
      - ".github/workflows/opencode-build.yml"

jobs:
  build-and-validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
      - run: npm ci
      - run: npm run build:cdocs

      - name: Validate generated agent frontmatter
        run: |
          for agent in build/cdocs/opencode/agents/*.md; do
            # ... same validation as today ...
          done

      - name: Validate npm package
        working-directory: build/cdocs/opencode
        run: npm pack --dry-run

```

Publishing is manual via `npm publish` from `build/cdocs/opencode/` after a successful build.
Automated CI publishing can be added later if release cadence warrants it.

### Documentation updates

Update `CLAUDE.md` "Multi-Target Marketplace" section:
- Build script path: `scripts/build-opencode.ts`
- Generated output: `build/cdocs/opencode/` (gitignored, never committed)
- Build command: `npm run build:cdocs`
- Remove "committed, never edit manually" language; replace with "gitignored, built on demand"

Update `plugins/cdocs/README.md` "Building OC artifacts from source" section:
- New build command: `npm run build:cdocs` (or `npx tsx scripts/build-opencode.ts`)
- New output location: `build/cdocs/opencode/`
- Remove reference to committed generated files

## Important Design Decisions

### Decision: Build artifacts are gitignored, not committed

**Why:** Committed build artifacts create duplication in version control (24 files that are derivable from source), require developers to remember to regenerate, and blur the distinction between source and output.
Gitignoring the build output is cleaner: `build/` is transient, CI builds fresh on every run, and `npm publish` produces the tarball from the build output.
The tradeoff is that consumers cannot browse generated OC files in the GitHub repo, but this is acceptable since the canonical source is CC-format and OC consumers install via npm.

### Decision: npm + tsx, no bun dependency

**Why:** The repo currently has no JS/TS tooling at the root.
npm is ubiquitous, `tsx` handles TypeScript execution without a compilation step, and adding `typescript` as a devDependency enables `tsc --noEmit` for type checking.
Bun may be adopted later, but introducing it now adds an unnecessary dependency for CI and contributors.

### Decision: Skills/rules bundled in the npm tarball

**Why:** The postinstall script copies skills and rules from the package to project paths.
For standalone npm installs (outside the monorepo), the canonical `plugins/cdocs/skills/` tree is not available.
The build script must copy skills and rules into the build output so they are included in the npm tarball.
This is not duplication in the meaningful sense: the copies exist only in `build/` (gitignored) and the npm tarball (a distribution artifact), never in committed source.

### Decision: Multi-plugin ready via `build/<plugin>/opencode/`

**Why:** If future plugins are added to the marketplace (e.g., a `changelog` plugin), each would need its own OC build output.
Using `build/<plugin>/opencode/` rather than `build/opencode/` avoids restructuring later.
The build script accepts a plugin name argument, making it straightforward to add support for new plugins.

### Decision: Hand-written OC files move to canonical locations under `plugins/cdocs/`

**Why:** The `cdocs-hooks.ts` OC plugin and `postinstall.js` are hand-written files that currently live inside the generated `opencode/` directory.
When `opencode/` becomes gitignored, these files need committed canonical locations.
Placing them under `plugins/cdocs/hooks/` and `plugins/cdocs/scripts/` respectively keeps them co-located with the plugin source they belong to, and the build script copies them into the output.

## Edge Cases

### First-time setup

A new contributor cloning the repo will not have `build/` populated.
Running `npm install && npm run build` must work from a clean clone.
The CI workflow validates this on every PR.

### Version bump coordination

The npm package version comes from `plugins/cdocs/.claude-plugin/plugin.json`.
If the version is not bumped, `npm publish` will fail with "version already exists" (the `continue-on-error` in CI handles this gracefully).
This is the same behavior as today -- no change needed.

### Empty build directory

If `build/` does not exist, the build script creates it (it already uses `mkdirSync({ recursive: true })`).
No special handling needed.

### postinstall.js portability

The postinstall script uses `__dirname`-relative paths to find skills/rules in the npm package.
Since the build output structure (`skills/`, `rules/`, `scripts/postinstall.js`) is unchanged, the postinstall script works identically from `build/cdocs/opencode/` as it does from `plugins/cdocs/opencode/`.
No changes to postinstall logic are needed.

### Partial builds

If the build script fails mid-execution (e.g., a malformed agent file), the `build/` directory may contain stale partial output.
The build script should clean the output directory at the start of each run (it already does `rmSync` on subdirectories).
Extending this to `rmSync` the entire `build/cdocs/opencode/` at the top of `main()` ensures a clean slate.

## Implementation Phases

### Phase 1: Workspace setup and build script relocation

**What:**
- Add root `package.json` with `build` and `build:cdocs` npm scripts.
- Add root `tsconfig.json` scoped to `scripts/`.
- Move `plugins/cdocs/scripts/build-opencode.ts` to `scripts/build-opencode.ts` (clears `plugins/cdocs/scripts/` for plugin-specific scripts only).
- Move `plugins/cdocs/opencode/scripts/postinstall.js` to `plugins/cdocs/scripts/postinstall.js`.
- Move `plugins/cdocs/opencode/plugins/cdocs-hooks.ts` to `plugins/cdocs/hooks/cdocs-hooks.ts`.
- Update the build script to:
  - Accept a plugin name argument (default: `cdocs`).
  - Resolve plugin root from repo root as `plugins/<name>/`.
  - Output to `build/<name>/opencode/`.
  - Clean the entire output directory at the start.
  - Copy `cdocs-hooks.ts` and `postinstall.js` from their canonical locations.
- Add `build/` to `.gitignore`.
- Remove or simplify `.gitattributes` (remove `linguist-generated` markers for `plugins/cdocs/opencode/`).
- Delete `plugins/cdocs/opencode/` (the committed generated directory).

**Verification:**
- `npm install && npm run build:cdocs` succeeds from a clean state.
- `build/cdocs/opencode/` contains the same files that `plugins/cdocs/opencode/` previously contained.
- `npm pack --dry-run` in `build/cdocs/opencode/` succeeds.
- `build/` is gitignored and `plugins/cdocs/opencode/` no longer exists in version control.

### Phase 2: CI and documentation updates

**What:**
- Update `.github/workflows/opencode-build.yml`:
  - Replace `tsx plugins/cdocs/scripts/build-opencode.ts` with `npm ci && npm run build:cdocs`.
  - Remove the dirty-check step.
  - Update validation paths from `plugins/cdocs/opencode/` to `build/cdocs/opencode/`.
  - Update trigger paths to include `scripts/build-opencode.ts`.
- Update `CLAUDE.md` "Multi-Target Marketplace" section with new paths and commands.
- Update `plugins/cdocs/README.md` "Building OC artifacts from source" and "OpenCode Installation" sections.
- Run `npm run build:cdocs` to verify end-to-end after all changes.

**Verification:**
- CI workflow syntax is valid (`act` or manual inspection).
- Documentation references are internally consistent (no stale paths).
- A full build from clean clone produces a valid npm package.

## Open Questions

None remaining. Publishing is manual for now; automated CI publishing deferred to a future proposal if release cadence warrants it.
