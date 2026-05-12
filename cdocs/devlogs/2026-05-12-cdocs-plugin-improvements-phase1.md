---
first_authored:
  by: "@claude-opus-4-7-1m"
  at: 2026-05-12T13:45:14-07:00
task_list: clauthier/cdocs-improvements
type: devlog
state: live
status: ready_for_review
tags: [cdocs, plugin_api, marketplace, release_flow]
---

# CDocs Plugin Improvements Phase 1: Devlog

## Objective

Implement Phase 1 of `cdocs/proposals/2026-05-08-cdocs-plugin-improvements.md`:
four mechanical sub-items.

1. Add `$schema` to plugin manifests (if a canonical URL exists).
2. Document `claude plugin tag` release flow in `plugins/cdocs/README.md`.
3. Smoke-test cdocs install under `strictKnownMarketplaces`.
4. Audit skill descriptions for the 250-character menu cap.

## Plan

1. Locate canonical `$schema` URLs for both manifests; edit if found, omit if not.
2. Run `claude plugin validate` on both manifests.
3. Verify `claude plugin tag --help` output verbatim; write the README "Releasing" section.
4. Run strict-mode install test under sandboxed `CLAUDE_CONFIG_DIR`.
5. Audit each `plugins/cdocs/skills/*/SKILL.md` description.

## Testing Approach

Manual verification per sub-item.
Capture command output verbatim.
Do not commit; leave changes in the working tree for the parent agent.

## Implementation Notes

### 1. `$schema` URLs

Both manifests now have a canonical `$schema` from SchemaStore:

- `https://json.schemastore.org/claude-code-plugin-manifest.json`
- `https://json.schemastore.org/claude-code-marketplace.json`

Discovery path: SchemaStore catalog at `https://www.schemastore.org/api/json/catalog.json` lists both schemas (entries "Claude Code Plugin Manifest" and "Claude Code Plugin Marketplace").
Both URLs return HTTP 200 and contain a top-level `$id` pointing back to the same `json.schemastore.org/claude-code-*.json` URL — the canonical `$id` form is the value used.
The downloaded schemas explicitly document a `$schema` property: "JSON Schema reference for editor autocomplete/validation; ignored at load time."

`claude plugin validate` accepts the field; both manifests pass post-edit.

### 2. `claude plugin tag` workflow

`claude plugin tag --help` output documented verbatim in the README "Releasing" section.

Verified plugin resolution in the monorepo:

```
$ claude plugin tag --dry-run --force plugins/cdocs
Plugin:  cdocs
Version: 0.1.0 (from plugin.json)
Marketplace entry: plugins[0] in /workspace/clauthier/main/.claude-plugin/marketplace.json
Tag:     cdocs--v0.1.0

✔ Dry run — would create tag cdocs--v0.1.0 at HEAD in /workspace/clauthier/main
  git -C /workspace/clauthier/main tag -f -a cdocs--v0.1.0 -m "cdocs 0.1.0"
  git -C /workspace/clauthier/main push --force origin refs/tags/cdocs--v0.1.0
```

Behaviors worth noting (captured in README):

- `claude plugin tag` from the repo root with no path argument fails with `No plugin manifest found. Expected /…/.claude-plugin/plugin.json.` because the tool looks at the working dir, not the enclosing marketplace.
- `build/cdocs/opencode/` does not contain a `.claude-plugin/plugin.json` (only a `package.json`), so the tool is not confused by the generated build directory.

### 3. `strictKnownMarketplaces` smoke test

**Schema discovery.**
Binary inspection of `claude-code-linux-x64/claude` shows `strictKnownMarketplaces` is `z.array(...)` (not boolean) and is read only from `policySettings` (managed enterprise settings at `/etc/claude-code/managed-settings.json` on Linux).
There is no env-var to redirect the managed-settings path.
The proposal's `"strictKnownMarketplaces": true` in a project `.claude/settings.json` therefore does not exercise the enforcement code path — that setting in project settings is effectively ignored.

**Adjusted smoke test.**
To exercise the real enforcement path, the test writes a temporary `/etc/claude-code/managed-settings.json` (via passwordless sudo on this devcontainer), then cleans it up afterward.
This is the deviation from the proposal flagged in the final report.

Cases run with `CLAUDE_CONFIG_DIR=/tmp/cdocs-strict-mode-test-config` and project at `/tmp/cdocs-strict-mode-test`:

- **Success:** managed `strictKnownMarketplaces` includes `pathPattern: "^/workspace/clauthier/main$"` AND project `extraKnownMarketplaces` pre-registers `clauthier`. `marketplace add` and `plugin install` both succeed (exit 0).
- **Failure:** managed `strictKnownMarketplaces` only allows `pathPattern: "^/opt/approved-marketplaces/"`. `marketplace add /workspace/clauthier/main` fails with `Marketplace source 'dir:/workspace/clauthier/main' is blocked by enterprise policy. Allowed sources: pathPattern:^/opt/approved-marketplaces/` (exit 1); subsequent `plugin install cdocs@clauthier` fails with "not found" (exit 1).

Verbatim outputs captured in the final reply to parent.

Cleanup: removed `/etc/claude-code/managed-settings.json` (then `rmdir /etc/claude-code`) and both `/tmp/cdocs-strict-mode-test*` directories.

### 4. Skill description audit

All 10 skill descriptions (`plugins/cdocs/skills/*/SKILL.md`) are well under 250 characters.
Longest is `implement` at 95 chars; shortest is `nit_fix` at 46.
No edits needed.

## Changes Made

| File | Description |
|------|-------------|
| `.claude-plugin/marketplace.json` | Add `$schema` field (SchemaStore canonical URL). |
| `plugins/cdocs/.claude-plugin/plugin.json` | Add `$schema` field (SchemaStore canonical URL). |
| `plugins/cdocs/README.md` | New "Releasing" section documenting `claude plugin tag` workflow + monorepo notes. |
| `cdocs/devlogs/2026-05-12-cdocs-plugin-improvements-phase1.md` | This devlog. |

## Verification

### Manifest validation

```
$ claude plugin validate .claude-plugin/marketplace.json
Validating marketplace manifest: /workspace/clauthier/main/.claude-plugin/marketplace.json
✔ Validation passed

$ claude plugin validate plugins/cdocs/.claude-plugin/plugin.json
Validating plugin manifest: /workspace/clauthier/main/plugins/cdocs/.claude-plugin/plugin.json
✔ Validation passed
```

### `claude plugin tag` dry-run

```
$ claude plugin tag --dry-run --force plugins/cdocs
Plugin:  cdocs
Version: 0.1.0 (from plugin.json)
Marketplace entry: plugins[0] in /workspace/clauthier/main/.claude-plugin/marketplace.json
Tag:     cdocs--v0.1.0

✔ Dry run — would create tag cdocs--v0.1.0 at HEAD in /workspace/clauthier/main
  git -C /workspace/clauthier/main tag -f -a cdocs--v0.1.0 -m "cdocs 0.1.0"
  git -C /workspace/clauthier/main push --force origin refs/tags/cdocs--v0.1.0
```

### Strict-mode smoke test

**Success case** (`strictKnownMarketplaces` allows path, `extraKnownMarketplaces` pre-registers):

```
$ cd /tmp/cdocs-strict-mode-test && CLAUDE_CONFIG_DIR=/tmp/cdocs-strict-mode-test-config claude plugin marketplace add /workspace/clauthier/main
Adding marketplace…✔ Successfully added marketplace: clauthier (declared in user settings)

$ cd /tmp/cdocs-strict-mode-test && CLAUDE_CONFIG_DIR=/tmp/cdocs-strict-mode-test-config claude plugin install cdocs@clauthier --scope project
Installing plugin "cdocs@clauthier"...✔ Successfully installed plugin: cdocs@clauthier (scope: project)
```

**Failure case** (`strictKnownMarketplaces` rejects path):

```
$ cd /tmp/cdocs-strict-mode-test && CLAUDE_CONFIG_DIR=/tmp/cdocs-strict-mode-test-config claude plugin marketplace add /workspace/clauthier/main
✘ Failed to add marketplace: Marketplace source 'dir:/workspace/clauthier/main' is blocked by enterprise policy. Allowed sources: pathPattern:^/opt/approved-marketplaces/
Adding marketplace…

$ cd /tmp/cdocs-strict-mode-test && CLAUDE_CONFIG_DIR=/tmp/cdocs-strict-mode-test-config claude plugin install cdocs@clauthier --scope project
Installing plugin "cdocs@clauthier"...✘ Failed to install plugin "cdocs@clauthier": Plugin "cdocs" not found in marketplace "clauthier". Your local copy may be out of date — try `claude plugin marketplace update clauthier`.
```

### Skill description lengths

```
devlog       len= 66
implement    len= 95
init         len= 47
nit_fix      len= 46
propose      len= 75
report       len= 82
review       len= 62
rfp          len= 48
status       len= 71
triage       len= 79
```

All under 250.

## Deviations & Notes for Reviewer

1. **`strictKnownMarketplaces` is `policySettings`-only and an array, not a project-level boolean.**
   The proposal's "fresh `.claude/settings.json` declaring `strictKnownMarketplaces: true`" cannot exercise the enforcement code path because CC reads this setting only from managed settings (`/etc/claude-code/managed-settings.json` on Linux) and expects an array of source pattern objects.
   The smoke test instead wrote a temporary managed-settings file (passwordless sudo), exercised both success and failure paths, and cleaned up.
   Worth updating the proposal's wording if anyone reruns this.

2. **`$schema` URLs found via SchemaStore.**
   The proposal said "omit if none exists." Canonical URLs do exist (SchemaStore), so both manifests now have them.

3. **No skill descriptions exceeded 250 characters.**
   Audit found 46–95 chars across all 10 skills, no edits needed.

4. **Concurrent subagent untracked files.**
   `cdocs/devlogs/2026-05-12-rule-delivery-investigation.md` and `cdocs/reports/2026-05-12-rule-delivery-options.md` appeared in `git status` during this session; they belong to the parallel subagent and were not touched.
