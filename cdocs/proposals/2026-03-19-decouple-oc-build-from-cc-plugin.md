---
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-19T14:30:00-07:00
task_list: cdocs/opencode-decoupling
type: proposal
state: live
status: wip
tags: [opencode, plugin-architecture, cc-plugin, build-pipeline, worktree]
---

# Decouple OpenCode Build from Claude Code Plugin Setup

> BLUF(opus/opencode-decoupling): CC cdocs skills are broken because the plugin was installed for the parent directory `/var/home/mjr/code/weft/clauthier`, not the git worktree at `clauthier/main` where CC actually runs.
> Separately, the OC build introduced a `file:` npm dependency in root `package.json` that runs the OC postinstall in the CC source repo on every `npm install`, leaking OC artifacts into the working tree.
> Fix both: re-register the marketplace for the worktree path, and isolate the OC build into its own workspace so it cannot interfere with CC plugin development.
>
> Supersedes/incorporates: `2026-03-19-opencode-skill-path-conventions.md` (OC skill nesting fix).

## Summary

Three issues surfaced together, but have distinct root causes:

1. **CC skills not loading**: project path mismatch between `installed_plugins.json` and the git worktree CC runs from.
   The marketplace was registered and the plugin installed before the repo adopted a bare-repo + worktree layout.
2. **OC postinstall runs in CC source repo**: the root `package.json` `file:` dependency triggers OC artifact generation on `npm install`.
3. **OC skill nesting bug**: postinstall places skills at `.opencode/skills/cdocs/<name>/` but OC discovers at `.opencode/skills/<name>/` (flat).
   This is the subject of the existing RFP `2026-03-19-opencode-skill-path-conventions.md`, incorporated here.

## Objective

Restore CC plugin functionality in the clauthier worktree layout, and restructure the OC build so it cannot interfere with CC plugin development.

## Background

### Worktree Layout

The clauthier repo uses a bare-repo + worktree structure:
```
clauthier/
  .bare/              # bare git repo
  main/               # git worktree (main branch, primary working dir)
    plugins/cdocs/    # CC plugin source
    build/            # OC build output (gitignored)
    .claude/          # CC project config
    .opencode/        # OC artifacts (gitignored)
```

CC is launched from `clauthier/main/`.
The marketplace was registered pointing to `clauthier/` (the parent).
The plugin install recorded `projectPath: "clauthier/"` in `installed_plugins.json`.
CC's plugin loader requires an exact project path match, so the plugin doesn't load.

### OC Build Coupling

The root `package.json` currently contains:
```json
{
  "type": "module",
  "dependencies": {
    "@weftwise/cdocs-opencode": "file:build/cdocs/opencode"
  }
}
```

The `file:` dependency creates a symlink in `node_modules/` and runs the OC package's `postinstall` script.
That script copies skills and rules into project directories (`.opencode/skills/`, `.claude/rules/`).
In the source repo, this is unwanted: the canonical skills live at `plugins/cdocs/skills/`, and the copied artifacts are noise.

### Prior Art

- `2026-03-19-opencode-skill-path-conventions.md` (RFP): identified the OC skill nesting bug.
- `2026-03-19-opencode-command-wrappers.md` (RFP): proposed OC command wrappers (orthogonal, not affected by this proposal).
- `2026-03-17-build-workspace-reorganization.md`: moved build output to `build/` (gitignored).

## Proposed Solution

### 1. Fix CC Plugin Registration (Manual, One-Time)

Re-register the marketplace and re-install the plugin from within the worktree:

```bash
cd /var/home/mjr/code/weft/clauthier/main

# Remove stale marketplace registration
claude plugin marketplace remove clauthier

# Re-add pointing to the worktree
claude plugin marketplace add .

# Re-install (this updates projectPath and refreshes the cache)
claude plugin install cdocs@clauthier --scope project
```

> NOTE(opus/opencode-decoupling): This is a one-time fix for the author's local setup.
> Other worktree users would hit the same issue.
> Consider documenting the worktree-aware setup in the plugin README.

### 2. Remove OC Dependency from Root `package.json`

The `file:build/cdocs/opencode` dependency exists only for local OC testing.
Move it to a dedicated workspace or remove it entirely.

**Option A (recommended): Remove the dependency, use direct path testing.**

Delete the `@weftwise/cdocs-opencode` dependency from root `package.json`.
When testing the OC build locally, use `npm pack` + `npm install <tarball>` in the target project, or use a symlink in the target project's `.opencode/`:

```bash
# Build
npm run build:cdocs

# Test in another project
cd /path/to/target-project
npm install /var/home/mjr/code/weft/clauthier/main/build/cdocs/opencode
```

This keeps the CC source repo clean: no OC artifacts in the working tree, no postinstall side effects.

**Option B: npm workspace isolation.**

Add a `workspaces` field to root `package.json` pointing to `build/cdocs/opencode/`.
This isolates the OC package's `node_modules` and prevents its postinstall from targeting the repo root.
More complex to maintain, and the workspace directory is gitignored (must be built first).

> NOTE(opus/opencode-decoupling): Option A is simpler and sufficient.
> The `file:` dependency was likely added for convenience during initial OC development.
> With the build pipeline mature, direct-path testing is adequate.

### 3. Flatten OC Skill Paths in Postinstall

Update `plugins/cdocs/scripts/postinstall.js` to copy skills to flat paths OC can discover.

Change:
```javascript
const SKILLS_DEST_OC = join(PROJECT_ROOT, ".opencode", "skills", "cdocs");
```

To:
```javascript
const SKILLS_DEST_OC = join(PROJECT_ROOT, ".opencode", "skills");
```

This copies each skill directory directly to `.opencode/skills/<name>/SKILL.md` instead of `.opencode/skills/cdocs/<name>/SKILL.md`.

For CC-side copies (the `else` branch), the same flattening applies:
```javascript
const SKILLS_DEST_CC = join(PROJECT_ROOT, ".claude", "skills");
```

> NOTE(opus/opencode-decoupling): This makes skill names globally unique within a project.
> Names like `init`, `report`, `review` could collide with other plugins.
> For now, accept the risk: consumers opt into the plugin explicitly, and collisions are unlikely in practice.
> If collision reports emerge, revisit with a `cdocs-` prefix (e.g., `cdocs-report`).

### 4. Guard Postinstall Against Source Repo

Add a guard to `postinstall.js` that skips execution when running inside the plugin source repo.
The source repo has `plugins/cdocs/.claude-plugin/plugin.json`: if that file exists relative to the project root, the postinstall is running in the source repo and should no-op.

```javascript
// Skip in source repo (CC plugin source has this marker file)
const isSourceRepo = existsSync(join(PROJECT_ROOT, "plugins", "cdocs", ".claude-plugin", "plugin.json"));
if (isSourceRepo) {
  console.log("cdocs-opencode: source repo detected, skipping postinstall");
  process.exit(0);
}
```

This is belt-and-suspenders alongside removing the `file:` dependency (Phase 2).
Even if someone re-adds the dependency, the postinstall won't pollute the source repo.

## Important Design Decisions

**Marketplace re-registration over `installed_plugins.json` editing.**
Manually editing `installed_plugins.json` is fragile and undocumented.
Re-registering via the CLI is the supported path and ensures the cache is refreshed.

**Remove dependency over workspace isolation.**
The `file:` dependency served a purpose during initial OC development (quick `npm install` testing).
With the build pipeline stable, that convenience no longer justifies the coupling.
Direct-path testing in a target project is equally fast and avoids side effects.

**Flat skill paths without prefix.**
OC's discovery model is flat: `skills/*/SKILL.md`.
Adding a `cdocs-` prefix to every skill name changes the invocation UX (`/cdocs-report` instead of `/report`) for a collision risk that hasn't materialized.
Defer prefixing until actual collisions are reported.

**Source-repo guard in postinstall.**
Defense in depth.
The primary fix is removing the `file:` dependency, but the guard costs one `existsSync` call and prevents future accidents.

## Edge Cases

- **Worktree path changes**: if the user moves the worktree, the marketplace registration and plugin install path become stale again.
  CC has no worktree-aware path resolution.
  Document in README that worktree users must register the marketplace from within the worktree they use with CC.
- **Multiple worktrees**: each worktree is a separate CC project.
  The plugin must be installed separately for each worktree where CC will be used.
  This is a CC limitation, not a cdocs issue.
- **Stale plugin cache after source changes**: CC caches plugins at install time.
  After modifying skills/hooks/rules in the source repo, run `claude plugin install cdocs@clauthier` to refresh the cache.
  This is standard CC behavior but worth documenting.
- **`build/` directory not present**: if `build/cdocs/opencode/` doesn't exist when `npm install` runs, the `file:` dependency fails.
  This is another reason to remove it: the build is on-demand, not a prerequisite for CC development.

## Test Plan

1. **CC skills restored**: after re-registering marketplace and re-installing plugin, verify `/cdocs:propose`, `/cdocs:devlog`, etc. appear in the system prompt's available skills list.
2. **Hooks active**: verify SessionStart hook injects rules (check for rule content in session context).
3. **No OC artifacts in source repo**: after removing the `file:` dependency and running `npm install`, verify `.opencode/skills/` is not created/modified.
4. **OC postinstall works in target project**: run `npm install @weftwise/cdocs-opencode` (from tarball or registry) in a test project, verify skills land at `.opencode/skills/<name>/SKILL.md` (flat).
5. **Source-repo guard**: add the `file:` dependency back temporarily, run `npm install`, verify postinstall skips with "source repo detected" message.

## Verification Methodology

For the CC plugin fix, the definitive test is starting a new CC session in the worktree and checking the system prompt for cdocs skills.
There is no programmatic way to verify this: it requires launching a new `claude` session.

For the postinstall changes, use a scratch directory:
```bash
mkdir /tmp/test-cdocs-oc && cd /tmp/test-cdocs-oc
npm init -y
npm install /var/home/mjr/code/weft/clauthier/main/build/cdocs/opencode
ls .opencode/skills/  # Should show flat: devlog/, propose/, review/, etc.
ls .opencode/skills/cdocs/ 2>/dev/null  # Should NOT exist
```

## Implementation Phases

### Phase 1: Fix CC Plugin (Manual, Immediate)

Re-register marketplace and re-install plugin from within the `main` worktree.
Verify skills appear in next CC session.

No code changes required.

### Phase 2: Remove OC Dependency from Root `package.json`

1. Remove `"@weftwise/cdocs-opencode": "file:build/cdocs/opencode"` from `dependencies`.
2. Remove the `node_modules/@weftwise/` symlink.
3. Clean up `.opencode/skills/cdocs/` (generated by the postinstall).
4. Run `npm install` to regenerate `package-lock.json`.
5. Verify `npm install` no longer produces OC artifacts.

### Phase 3: Fix OC Skill Paths and Add Source-Repo Guard

1. Update `plugins/cdocs/scripts/postinstall.js`:
   - Change `SKILLS_DEST_OC` and `SKILLS_DEST_CC` to flat paths (remove `"cdocs"` segment).
   - Add source-repo detection guard at top of script.
2. Rebuild: `npm run build:cdocs` (copies updated postinstall into build output).
3. Test in scratch directory per verification methodology.

### Phase 4: Update Documentation and Evolve RFPs

1. Mark `2026-03-19-opencode-skill-path-conventions.md` as `status: evolved` with a NOTE referencing this proposal.
2. Add worktree setup instructions to `plugins/cdocs/README.md`.
3. Add a note about `claude plugin install` cache refresh after source changes.
