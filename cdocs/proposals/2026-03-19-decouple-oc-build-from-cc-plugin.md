---
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-19T14:30:00-07:00
task_list: cdocs/opencode-decoupling
type: proposal
state: live
status: implementation_wip
tags: [opencode, plugin-architecture, cc-plugin, build-pipeline, worktree, postinstall]
last_reviewed:
  status: revision_requested
  by: "@claude-opus-4-6"
  at: 2026-03-19T15:00:00-07:00
  round: 1
---

# Decouple OpenCode Build from Claude Code Plugin Setup

> BLUF(opus/opencode-decoupling): The OC postinstall script leaks into `.claude/` directories (skills and rules), which is wrong -- OC artifacts belong exclusively in `.opencode/`.
> CC cdocs skills are broken because the plugin was registered for the parent directory, not the git worktree.
> The root `package.json` previously had a `file:` dependency that ran the OC postinstall in the CC source repo on every `npm install`; this has been removed, but a source-repo guard prevents regressions.
> Fix all three: confine OC postinstall to `.opencode/` paths only, re-register the marketplace for the worktree path, and guard against postinstall running in the dev environment.
>
> Supersedes/incorporates: `2026-03-19-opencode-skill-path-conventions.md` (OC skill nesting fix, now evolved into this proposal).

## Summary

Four issues surfaced together, but have distinct root causes:

1. **OC postinstall writes to `.claude/` directories**: the postinstall copies skills to `.claude/skills/cdocs/` (fallback path) and rules to `.claude/rules/`.
   OC artifacts must only target `.opencode/` paths.
   Writing to `.claude/` creates cross-tool leakage where OC installation pollutes CC config space.
2. **CC skills not loading**: project path mismatch between `installed_plugins.json` and the git worktree CC runs from.
   The marketplace was registered before the repo adopted a bare-repo + worktree layout.
3. **OC postinstall runs in CC source repo**: the root `package.json` `file:` dependency (now removed) triggered OC artifact generation on `npm install`.
   The source-repo guard prevents regressions if the dependency is ever re-added.
4. **OC skill nesting bug**: postinstall places skills at `.opencode/skills/cdocs/<name>/` but OC discovers at `.opencode/skills/<name>/` (flat).
   This is the subject of the former RFP `2026-03-19-opencode-skill-path-conventions.md`, now evolved into this proposal.

## Objective

Ensure OC artifacts are confined to `.opencode/` directories with zero `.claude/` leakage, restore CC plugin functionality in the clauthier worktree layout, and add defense-in-depth guards against postinstall running in the source repo.

## Background

### The `.claude/` Leakage Problem

The current `postinstall.js` has two `.claude/` leakage paths:

```javascript
// Current: writes skills to .claude/ when .opencode/ doesn't exist
const SKILLS_DEST_CC = join(PROJECT_ROOT, ".claude", "skills", "cdocs");
// ...
if (existsSync(join(PROJECT_ROOT, ".opencode"))) {
  copyIfExists(SKILLS_SRC, SKILLS_DEST_OC, "Skills");
} else {
  copyIfExists(SKILLS_SRC, SKILLS_DEST_CC, "Skills");  // WRONG: creates .claude/ artifacts from OC install
}

// Current: ALWAYS writes rules to .claude/rules/
const RULES_DEST = join(PROJECT_ROOT, ".claude", "rules");
copyIfExists(RULES_SRC, RULES_DEST, "Rules");  // WRONG: OC package should not touch .claude/
```

This is architecturally wrong.
The `@weftwise/cdocs-opencode` package is an OC-specific distribution.
It should never create or modify anything under `.claude/`.
OC reads `.claude/rules/` as a compatibility fallback, but that does not mean OC *packages* should write there.
The rule delivery path for OC is `.opencode/rules/`, with `.claude/rules/` being a user-managed directory that the CC SessionStart hook or `/cdocs:init` populates for CC users.

### Accepted Proposal Alignment

The [cross-target rules integration proposal](2026-03-14-cross-target-rules-integration.md) (accepted) specifies that:
- CC rule delivery uses the SessionStart hook to inject rules as `additionalContext` (Layer 1).
- OC rule delivery uses `.opencode/rules/cdocs/` with OC-enhanced frontmatter, populated by `/cdocs:init` (Layer 3a).
- `.claude/rules/` is the CC path, populated by `/cdocs:init` for CC users.
- AGENTS.md is a cross-tool fallback (Layer 3b/3c).

The current postinstall violates this architecture by having the OC npm package write to `.claude/rules/` directly.
This must stop.

The [multi-target marketplace proposal](2026-03-14-multi-target-marketplace.md) (accepted) specifies that:
- Skills are portable between CC and OC.
- The postinstall copies skills to `.opencode/skills/cdocs/` and rules to `.claude/rules/`.
- This was the original design, but the skill nesting and `.claude/` leakage problems were discovered during implementation.

This proposal amends the postinstall behavior to align with both accepted proposals.

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

### OC Build Coupling (Resolved)

The root `package.json` previously contained a `"@weftwise/cdocs-opencode": "file:build/cdocs/opencode"` dependency.
This has been removed, but the source-repo guard in postinstall prevents regressions.

### Prior Art

- `2026-03-19-opencode-skill-path-conventions.md` (RFP, **evolved** into this proposal): identified the OC skill nesting bug and raised the question of `.opencode/` vs `.claude/` targeting.
- `2026-03-14-multi-target-marketplace.md` (accepted): established the OC build pipeline and postinstall architecture.
- `2026-03-14-cross-target-rules-integration.md` (accepted): established the three-layer rules delivery architecture, specifying `.opencode/rules/cdocs/` for OC users.
- `2026-03-19-opencode-command-wrappers.md` (RFP): proposed OC command wrappers (orthogonal, not affected by this proposal).
- `2026-03-17-build-workspace-reorganization.md`: moved build output to `build/` (gitignored).

## Proposed Solution

### 1. Confine OC Postinstall to `.opencode/` Only (Primary Fix)

Rewrite `postinstall.js` so it only creates artifacts under `.opencode/`.
Remove all `.claude/` write paths.

**Updated postinstall.js:**

```javascript
#!/usr/bin/env node
/**
 * postinstall.js -- Copy cdocs skills and rules to .opencode/ on npm install.
 *
 * This script runs after `npm install @weftwise/cdocs-opencode` and copies:
 * - skills/ -> .opencode/skills/<name>/  (flat, no cdocs/ nesting)
 * - rules/ -> .opencode/rules/cdocs/     (namespaced under cdocs/)
 *
 * IMPORTANT: This script ONLY writes to .opencode/ directories.
 * It NEVER creates or modifies anything under .claude/.
 * CC artifact delivery is handled by the CC plugin system (SessionStart hook,
 * /cdocs:init), not by this OC-specific npm package.
 *
 * Set CDOCS_SKIP_POSTINSTALL=1 to skip this step.
 */

const { cpSync, mkdirSync, existsSync, readdirSync } = require("fs");
const { join, resolve } = require("path");

// Allow users to opt out
if (process.env.CDOCS_SKIP_POSTINSTALL === "1") {
  console.log("cdocs-opencode: postinstall skipped (CDOCS_SKIP_POSTINSTALL=1)");
  process.exit(0);
}

// Source-repo guard: skip when running inside the plugin source repo.
// The source repo has plugins/cdocs/.claude-plugin/plugin.json as a marker.
const PROJECT_ROOT = process.env.INIT_CWD || process.cwd();
const SOURCE_REPO_MARKER = join(PROJECT_ROOT, "plugins", "cdocs", ".claude-plugin", "plugin.json");
if (existsSync(SOURCE_REPO_MARKER)) {
  console.log("cdocs-opencode: source repo detected, skipping postinstall");
  process.exit(0);
}

// Package root is one level up from scripts/
const PKG_ROOT = resolve(__dirname, "..");
const SKILLS_SRC = join(PKG_ROOT, "skills");
const RULES_SRC = join(PKG_ROOT, "rules");

// Destination paths -- ONLY .opencode/, NEVER .claude/
const SKILLS_DEST = join(PROJECT_ROOT, ".opencode", "skills");
const RULES_DEST = join(PROJECT_ROOT, ".opencode", "rules", "cdocs");

/**
 * Copy skill directories to flat .opencode/skills/<name>/ paths.
 * OC discovers skills at .opencode/skills/<name>/SKILL.md (one level).
 * No cdocs/ namespace prefix -- skills are flat in the .opencode/skills/ directory.
 */
function copySkillsFlat(src, dest) {
  if (!existsSync(src)) {
    console.log("cdocs-opencode: skills source not found, skipping");
    return;
  }
  const skills = readdirSync(src, { withFileTypes: true }).filter(d => d.isDirectory());
  for (const skill of skills) {
    const skillSrc = join(src, skill.name);
    const skillDest = join(dest, skill.name);
    mkdirSync(skillDest, { recursive: true });
    cpSync(skillSrc, skillDest, { recursive: true });
  }
  console.log(`cdocs-opencode: ${skills.length} skills copied to ${dest}`);
}

/**
 * Copy rules to .opencode/rules/cdocs/ (namespaced to avoid collisions).
 */
function copyRules(src, dest) {
  if (!existsSync(src)) {
    console.log("cdocs-opencode: rules source not found, skipping");
    return;
  }
  mkdirSync(dest, { recursive: true });
  cpSync(src, dest, { recursive: true });
  console.log(`cdocs-opencode: rules copied to ${dest}`);
}

// Ensure .opencode/ exists
mkdirSync(join(PROJECT_ROOT, ".opencode"), { recursive: true });

copySkillsFlat(SKILLS_SRC, SKILLS_DEST);
copyRules(RULES_SRC, RULES_DEST);
```

Key changes from current postinstall:
- **Skills target `.opencode/skills/<name>/`** (flat) instead of `.opencode/skills/cdocs/<name>/` (nested).
  OC discovers skills at `skills/*/SKILL.md`, one directory level.
  The `cdocs/` nesting prefix prevented OC from finding any skills.
- **Rules target `.opencode/rules/cdocs/`** instead of `.claude/rules/`.
  OC reads `.opencode/rules/` natively.
  The `cdocs/` namespace under rules avoids collisions with other rule sources.
- **No `.claude/` write paths at all.**
  The OC package has no business creating CC artifacts.
  CC rule delivery is handled by the SessionStart hook and `/cdocs:init`.
- **Source-repo guard** at the top prevents the postinstall from running in the plugin development environment.
- **Always creates `.opencode/`** if it does not exist.
  The previous conditional logic (check for `.opencode/` existence, fall back to `.claude/`) is removed.
  An OC-specific package should always create OC-specific directories.

### 2. Fix CC Plugin Registration (Manual, One-Time)

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

### 3. Source-Repo Guard in Postinstall

The source-repo guard is included in the Section 1 postinstall rewrite (see the `SOURCE_REPO_MARKER` check near the top of the updated script).
It detects the source repo by checking for `plugins/cdocs/.claude-plugin/plugin.json` relative to the project root.
If found, the postinstall exits immediately with a "source repo detected" message.

This is belt-and-suspenders alongside the already-removed `file:` dependency.
Even if someone re-adds the dependency, the postinstall won't pollute the source repo.

### 4. Build Script Alignment

The build script (`scripts/build-opencode.ts`) copies the postinstall into the build output.
No changes needed to the build script itself -- it copies `plugins/cdocs/scripts/postinstall.js` as-is.
The fix is entirely in `postinstall.js`.

Verify after changes: `npm run build:cdocs` produces a `build/cdocs/opencode/scripts/postinstall.js` that matches the updated source.

## Important Design Decisions

**OC artifacts exclusively in `.opencode/`, never in `.claude/`.**
The `@weftwise/cdocs-opencode` package is an OC-specific distribution channel.
It should not create or modify anything in `.claude/`, which is CC's config space.
OC reads `.claude/rules/` as a compatibility fallback, but that is a *read* path, not a *write* target for OC packages.
The accepted cross-target rules integration proposal specifies that `/cdocs:init` (not the OC postinstall) is responsible for populating `.claude/rules/` for CC users and `.opencode/rules/cdocs/` for OC users.
The postinstall's job is narrower: deliver the OC package's bundled skills and rules to `.opencode/` on `npm install`.

**Flat skills, namespaced rules: asymmetric namespacing by discovery model.**
OC discovers skills via the directory name (`skills/*/SKILL.md`), so nesting under `skills/cdocs/<name>/` is invisible to OC's one-level scanner.
Skills must be flat.
Adding a `cdocs-` prefix to every skill name changes the invocation UX (`/cdocs-report` instead of `/report`) for a collision risk that hasn't materialized.
Defer prefixing until actual collisions are reported.
Rules, by contrast, do not have a name-collision discovery problem -- OC loads all files under `.opencode/rules/` recursively.
Namespacing rules under `.opencode/rules/cdocs/` groups related rule files and avoids filename collisions with other rule sources, at no cost to discoverability.

**Postinstall delivers baseline rules; `/cdocs:init` enhances them.**
Both the postinstall and `/cdocs:init` write to `.opencode/rules/cdocs/`.
This is intentional progressive enhancement:
the postinstall copies plain rule files (no OC-specific frontmatter) so that rules are available immediately after `npm install`.
`/cdocs:init` overwrites these copies with OC-enhanced versions that include `globs:` and `keywords:` frontmatter for conditional activation via the `opencode-rules` plugin.
If a user only runs `npm install` (no init), they get baseline rules that are always active.
If they also run `/cdocs:init`, they get conditionally-scoped rules.
This aligns with the accepted cross-target rules integration proposal's progressive enhancement model (Layer 3a).

**Marketplace re-registration over `installed_plugins.json` editing.**
Manually editing `installed_plugins.json` is fragile and undocumented.
Re-registering via the CLI is the supported path and ensures the cache is refreshed.

**Source-repo guard in postinstall.**
Defense in depth.
The primary fix was removing the `file:` dependency, but the guard costs one `existsSync` call and prevents future accidents.

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
- **Existing `.claude/skills/cdocs/` artifacts from prior OC installs**: users who installed `@weftwise/cdocs-opencode` before this fix will have stale artifacts in `.claude/skills/cdocs/`.
  The postinstall does not clean these up.
  Document in the upgrade notes that users should remove `.claude/skills/cdocs/` after upgrading.
- **Existing `.claude/rules/` artifacts from prior OC installs**: similarly, rules previously written to `.claude/rules/` by the OC postinstall should be cleaned up manually.
  Future OC installs will write to `.opencode/rules/cdocs/` instead.
- **`.opencode/` directory does not exist**: the updated postinstall creates `.opencode/` if needed.
  This is safe: OC expects this directory to exist and creates it on first run anyway.
- **Skill name collisions in flat namespace**: generic names like `init`, `report`, `review` could collide with skills from other OC packages.
  Accept the risk: consumers opt into the plugin explicitly, and collisions are unlikely given OC's young ecosystem.
  If collision reports emerge, revisit with a `cdocs-` prefix.
- **Dual CC+OC installation in the same project**: a user may have both CC (cdocs via marketplace) and OC (cdocs-opencode via npm) installed.
  CC uses `.claude/` paths; the OC package uses `.opencode/` paths.
  The two do not interfere: CC reads `.claude/skills/` and `.claude/rules/`, OC reads `.opencode/skills/` and `.opencode/rules/`.
  This non-interference is the intended outcome of `.opencode/`-only confinement.

## Test Plan

1. **No `.claude/` leakage**: after running `npm install @weftwise/cdocs-opencode` in a test project, verify that no files or directories were created under `.claude/`.
   ```bash
   ls -la .claude/ 2>/dev/null  # Should not exist or be unchanged from before install
   ```
2. **Skills at flat paths**: verify skills land at `.opencode/skills/<name>/SKILL.md` (flat).
   ```bash
   ls .opencode/skills/devlog/SKILL.md    # Should exist
   ls .opencode/skills/cdocs/ 2>/dev/null  # Should NOT exist (no nesting)
   ```
3. **Rules at `.opencode/rules/cdocs/`**: verify rules land in the OC rules directory.
   ```bash
   ls .opencode/rules/cdocs/writing-conventions.md  # Should exist
   ls .claude/rules/ 2>/dev/null                     # Should NOT have been created by postinstall
   ```
4. **CC skills restored**: after re-registering marketplace and re-installing plugin, verify `/cdocs:propose`, `/cdocs:devlog`, etc. appear in the system prompt's available skills list.
5. **Hooks active**: verify SessionStart hook injects rules (check for rule content in session context).
6. **Source-repo guard**: temporarily add the `file:` dependency back, run `npm install`, verify postinstall skips with "source repo detected" message.
7. **No OC artifacts in source repo**: after running `npm install` in the source repo (with the guard active), verify `.opencode/skills/` is not created/modified.
8. **OC postinstall in target project**: run `npm install @weftwise/cdocs-opencode` (from tarball) in a test project, verify full artifact set.
   ```bash
   mkdir /tmp/test-cdocs-oc && cd /tmp/test-cdocs-oc
   npm init -y
   npm install /var/home/mjr/code/weft/clauthier/main/build/cdocs/opencode
   ls .opencode/skills/         # Should show flat: devlog/, propose/, review/, etc.
   ls .opencode/rules/cdocs/    # Should show: writing-conventions.md, etc.
   ls .claude/ 2>/dev/null      # Should NOT exist
   ```
9. **Postinstall-then-init rule enhancement**: in a test project, run `npm install @weftwise/cdocs-opencode` then `/cdocs:init`.
   Verify that `.opencode/rules/cdocs/` files contain OC-enhanced frontmatter (`globs:`, `keywords:`) after init runs, overwriting the plain copies from the postinstall.

## Verification Methodology

For the CC plugin fix, the definitive test is starting a new CC session in the worktree and checking the system prompt for cdocs skills.
There is no programmatic way to verify this: it requires launching a new `claude` session.

For the postinstall changes, use a scratch directory:
```bash
mkdir /tmp/test-cdocs-oc && cd /tmp/test-cdocs-oc
npm init -y
npm install /var/home/mjr/code/weft/clauthier/main/build/cdocs/opencode
# Positive checks
ls .opencode/skills/devlog/SKILL.md      # Should exist
ls .opencode/rules/cdocs/writing-conventions.md  # Should exist
# Negative checks (no .claude/ leakage)
test -d .claude && echo "FAIL: .claude/ created" || echo "PASS: no .claude/ leakage"
```

## Implementation Phases

### Phase 1: Confine Postinstall to `.opencode/` (Primary Fix)

1. Rewrite `plugins/cdocs/scripts/postinstall.js`:
   - Remove all `.claude/` write paths (`SKILLS_DEST_CC`, `RULES_DEST` pointing to `.claude/`).
   - Change `SKILLS_DEST_OC` from `.opencode/skills/cdocs/` to `.opencode/skills/` (flat).
   - Add `RULES_DEST` pointing to `.opencode/rules/cdocs/` (namespaced).
   - Add source-repo detection guard at top of script.
   - Always create `.opencode/` if it does not exist.
   - Copy skills using flat directory iteration (each skill dir to `.opencode/skills/<name>/`).
2. Rebuild: `npm run build:cdocs` (copies updated postinstall into build output).
3. Test in scratch directory per verification methodology.
4. Verify no `.claude/` artifacts are created.

### Phase 2: Fix CC Plugin Registration (Manual, Immediate)

Re-register marketplace and re-install plugin from within the `main` worktree.
Verify skills appear in next CC session.

No code changes required.

### Phase 3: Update Documentation and Evolve RFP

1. Mark `2026-03-19-opencode-skill-path-conventions.md` as `status: evolved` with `evolved_into` pointing to this proposal.
2. Add a NOTE to the [multi-target marketplace proposal](2026-03-14-multi-target-marketplace.md) (Section 5, Plugin Manifest and npm Packaging) referencing this proposal as an amendment to the postinstall behavior.
   The marketplace proposal's description of postinstall writing to `.opencode/skills/cdocs/` and `.claude/rules/` is now stale; the NOTE should clarify that postinstall targets `.opencode/skills/<name>/` (flat) and `.opencode/rules/cdocs/` exclusively.
3. Add worktree setup instructions to `plugins/cdocs/README.md`.
4. Add upgrade notes documenting cleanup of stale `.claude/skills/cdocs/` and `.claude/rules/` artifacts from prior OC installs.
5. Add a note about `claude plugin install` cache refresh after source changes.
