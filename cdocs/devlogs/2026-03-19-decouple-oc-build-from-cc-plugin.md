---
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-19T14:30:00-07:00
task_list: cdocs/opencode-decoupling
type: devlog
state: live
status: wip
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

### Remaining Work

- Phase 3 (OC skill path flattening + source-repo guard in postinstall): not yet implemented.
- Phase 4 (documentation + evolve RFPs): not yet done.
