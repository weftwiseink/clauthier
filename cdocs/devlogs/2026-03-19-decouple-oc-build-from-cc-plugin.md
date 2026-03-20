---
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-19T14:30:00-07:00
task_list: cdocs/opencode-decoupling
type: devlog
state: live
status: review_ready
tags: [opencode, plugin-architecture, cc-plugin, build-pipeline]
---

# Decouple OC Build from CC Plugin Setup

> BLUF(opus/opencode-decoupling): CC cdocs skills were not loading due to a stale marketplace registration pointing to the parent directory instead of the `main` git worktree.
> Fixed by re-registering the marketplace, removing the OC `file:` dependency from `package.json`, gitignoring `.claude/rules/` (redundant with CLAUDE.md @-imports), and authoring a proposal for the remaining OC decoupling work.

## Investigation

### CC Skills Not Loading

Observed: system prompt lists only `keybindings-help` and `claude-developer-platform`, no cdocs skills.

Checked:
- `plugins/cdocs/.claude-plugin/plugin.json` exists and is valid.
- `plugins/cdocs/skills/*/SKILL.md` all present (10 skills).
- `.claude/settings.json` has `"cdocs@clauthier": true`.
- `hooks.json` properly references hook scripts.

Found the issue in `~/.claude/plugins/installed_plugins.json`:
```
"cdocs@clauthier": [{
  "projectPath": "/var/home/mjr/code/weft/clauthier",
  "installPath": "/home/mjr/.claude/plugins/cache/clauthier/cdocs/0.1.0",
  "gitCommitSha": "3e35e19b81e80ba87e92419e955b46127b1dd8b9"
}]
```

The plugin was installed for `/var/home/mjr/code/weft/clauthier` (parent directory).
The repo uses git worktrees: bare repo at `clauthier/.bare`, main worktree at `clauthier/main`.
CC is running from `clauthier/main`, which has no matching entry in `installed_plugins.json`.

The marketplace registration in `known_marketplaces.json` also points to the parent:
```
"clauthier": {
  "source": { "source": "directory", "path": "/var/home/mjr/code/weft/clauthier" },
  "installLocation": "/var/home/mjr/code/weft/clauthier"
}
```

The plugin cache is pinned to commit `3e35e19` from January 30th: 2 months stale.

### OC Build Coupling

The OC build work introduced these to root `package.json`:
- `"type": "module"` (for tsx/build script)
- `"@weftwise/cdocs-opencode": "file:build/cdocs/opencode"` dependency

Running `npm install` in the CC source repo:
1. Symlinks `node_modules/@weftwise/cdocs-opencode` -> `build/cdocs/opencode`
2. Runs the OC postinstall, which detects `.opencode/` exists and copies skills to `.opencode/skills/cdocs/` (wrong nesting, per existing RFP)
3. Copies rules to `.claude/rules/` (overlapping with repo-committed rules)

## Changes Made

### Proposal Authored

Created `cdocs/proposals/2026-03-19-decouple-oc-build-from-cc-plugin.md` with 4 phases covering CC plugin fix, OC dependency removal, skill path flattening, and documentation updates.

### CC Plugin Re-registration (Phase 1: Done)

```bash
claude plugin marketplace remove clauthier
claude plugin marketplace add ./
claude plugin install cdocs@clauthier --scope project
```

Result: marketplace now points to `clauthier/main/`, plugin installed with `projectPath: "/var/home/mjr/code/weft/clauthier/main"`, cache refreshed to `c91e817`.
Skills will appear in next CC session.

### OC Dependency Removed (Phase 2: Done)

- Removed `"@weftwise/cdocs-opencode": "file:build/cdocs/opencode"` from root `package.json`.
- Cleaned up `node_modules/@weftwise/` symlink.
- Regenerated `package-lock.json`.

### Gitignore and Rules Cleanup

- Added `.claude/rules/` to `.gitignore` (rules are loaded via CLAUDE.md @-imports in source repo, or injected by SessionStart hook in external installs).
- Removed committed `.claude/rules/*.md` files from git tracking and disk (they were redundant copies doubling rule content in context).
- Fixed `.lace` gitignore entry to `.lace/` (trailing slash for directory).

### Phase 3: Postinstall Rewrite (OC-Only Confinement)

Rewrote `plugins/cdocs/scripts/postinstall.js` to confine all output to `.opencode/`:

**Key changes:**
- Skills now copy to `.opencode/skills/<name>/` (flat, no `cdocs/` nesting).
  OC discovers skills at `skills/*/SKILL.md` -- one directory level.
- Rules now copy to `.opencode/rules/cdocs/` (namespaced under cdocs/ to avoid collisions).
- Removed all `.claude/` write paths (`SKILLS_DEST_CC`, `RULES_DEST` pointing to `.claude/`).
- Added source-repo guard: detects `plugins/cdocs/.claude-plugin/plugin.json` and skips execution.
- Always creates `.opencode/` if it does not exist.

**Verification (scratch directory `/tmp/test-postinstall/`):**
```
npm init -y && npm install /path/to/build/cdocs/opencode

# PASS: Skills at flat paths
ls .opencode/skills/devlog/SKILL.md    # exists
ls .opencode/skills/cdocs/             # does not exist (no nesting)

# PASS: Rules at .opencode/rules/cdocs/
ls .opencode/rules/cdocs/writing-conventions.md  # exists

# PASS: No .claude/ leakage
test -d .claude && echo FAIL || echo PASS   # PASS

# PASS: Source-repo guard
INIT_CWD=/path/to/source/repo node postinstall.js
# Output: "cdocs-opencode: source repo detected, skipping postinstall"

# PASS: Build script produces matching postinstall
diff plugins/cdocs/scripts/postinstall.js build/cdocs/opencode/scripts/postinstall.js
# (no differences)
```

All 10 skills discovered as flat directories.
All 3 rule files in `.opencode/rules/cdocs/`.
Zero `.claude/` artifacts created.

### Phase 4: Documentation Updates

- Added amendment NOTE to `cdocs/proposals/2026-03-14-multi-target-marketplace.md` (Section 5, Plugin Manifest and npm Packaging) documenting the stale postinstall description and referencing this proposal.
- Updated inline text in the marketplace proposal to reflect the new `.opencode/`-only paths.
- RFP `2026-03-19-opencode-skill-path-conventions.md` was already marked as `status: evolved` with `evolved_into` reference (done in prior session).
