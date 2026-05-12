---
first_authored:
  by: "@Claude Opus 4.7 (1M context)"
  at: 2026-05-08T13:30:00-07:00
task_list: clauthier/cdocs-improvements
type: proposal
state: live
status: review_ready
last_reviewed:
  status: review_ready
  by: "@claude-opus-4-7-1m"
  at: 2026-05-12T13:30:00-07:00
  round: 3
tags: [cdocs, plugin_api, marketplace, release_flow]
---

# CDocs Plugin Improvements: May 2026 Round (Phase 1)

> BLUF: Cheap manifest and release-flow polish so cdocs stays in step with the March-May 2026 Claude Code plugin API surface.
> Four mechanical sub-items: add `$schema` to the manifests, document `claude plugin tag` as the release procedure, smoke-test cdocs install under `strictKnownMarketplaces`, and audit skill descriptions for the 250-character menu cap.
> Larger investigations (rule delivery, skill ergonomics) are scoped in separate RFPs.

## Objective

Keep cdocs current against the CC plugin API surface and tooling that landed March-May 2026.
Land low-risk wins without touching the SessionStart-hook rule-delivery architecture or skill verbosity behavior.

## Background

The CC plugin API moved meaningfully between March and May 2026 (see [the cdocs CC plugin API report](../reports/2026-05-06-cc-plugin-api-updates.md)):

- The validator accepts `$schema` in both `marketplace.json` and `plugin.json`.
- `claude plugin tag` provides semver-validating release tags as a first-class CLI flow.
- `strictKnownMarketplaces` and `blockedMarketplaces` enforce marketplace policy on install.
- The skill menu introduced a type-to-filter search with a 250-character description cap.

Without this round, cdocs drifts: releases stay ad-hoc, manifests skip new optional fields, and skill descriptions risk truncation in the new menu UI.

The broader rule-delivery and skill-ergonomics questions raised by the same May 2026 report are scoped separately:

- [Rule delivery investigation RFP](2026-05-12-cdocs-rule-delivery-investigation.md): SessionStart hook viability and install-time alternatives.
- [Skill ergonomics RFP](2026-05-12-cdocs-skill-ergonomics.md): `${CLAUDE_EFFORT}` adaptation and slash-command collision audit.

A separate Dockerfile path-mirror symlink stopgap (for the lace bare-worktree devcontainer plugin-load issue) is captured by an in-file TODO referencing the rule-delivery RFP; no further action in this proposal.

## Proposed Solution

Four mechanical sub-items, no behavior change for end users.

### 1. Add `$schema` to plugin manifests

`version` and `description` already exist in both `.claude-plugin/marketplace.json` and `plugins/cdocs/.claude-plugin/plugin.json`.
`$schema` is the genuinely new field accepted by the validator.

The implementer identifies the canonical schema URL during implementation.
If no canonical URL exists at time of implementation, omit the field rather than invent one.

### 2. Document `claude plugin tag` as the release flow

Add a "Releasing" section to `plugins/cdocs/README.md` describing the `claude plugin tag` workflow.
Verify the tool correctly identifies the cdocs plugin in the monorepo layout (plugin nested at `plugins/cdocs/` under a marketplace at the repo root).

### 3. Smoke-test cdocs install under `strictKnownMarketplaces`

`strictKnownMarketplaces` is a managed-enterprise allowlist (array of source-pattern objects) read only from `policySettings`, not a project-level boolean.
On Linux it lives at `/etc/claude-code/managed-settings.json`; project-level entries are silently ignored.
The companion `extraKnownMarketplaces` field (project-level object) is what registers marketplace sources.

Smoke-test by writing a temporary managed-settings file with a source allowlist and running install against a sandboxed `CLAUDE_CONFIG_DIR`.
Confirm:
- Install succeeds when the clauthier marketplace path matches the allowlist and the project registers it in `extraKnownMarketplaces`.
- Marketplace add (and downstream install) fails with the enterprise-policy error when the path does not match the allowlist.

No permanent config change to the cdocs source or to the maintainer's real `~/.claude/` state.
This is a one-shot verification, not a recurring test.

### 4. Audit skill descriptions for the 250-character menu cap

Iterate over `plugins/cdocs/skills/*/SKILL.md` and check the `description` frontmatter field.
Any description over 250 characters gets shortened so the type-to-filter skill menu renders the full text without truncation.

## Important Design Decisions

**Treat the optional fields as additive.**
The `$schema` field is omitted if no canonical URL exists.
Do not invent a URL or point at a placeholder; absence is preferable to bad data.

**Do not touch the OpenCode build script.**
The OC build pipeline (`scripts/build-opencode.ts`) is out of scope.
Any manifest changes must work through the existing build unchanged.

**Defer larger items to the RFPs.**
Rule delivery and skill ergonomics are the more interesting and higher-risk threads from the May 2026 report.
They live in their own RFPs so this proposal stays mechanical and shippable in a single session.

## Edge Cases / Challenging Scenarios

**Marketplace name collision under `strictKnownMarketplaces`.**
If a downstream user adds both the GitHub-hosted `weft-marketplace` and the local `clauthier` marketplace, `cdocs@clauthier` and `cdocs@weft-marketplace` may both appear in `claude plugin list`.
The strict-mode smoke test should exercise this case explicitly.

**`claude plugin tag` and the OpenCode build directory.**
`scripts/build-opencode.ts` generates artifacts under `build/cdocs/opencode/`.
Verify `claude plugin tag` (which reads `plugin.json` and the enclosing marketplace entry) does not get confused by the generated build directory.
If it does, the README "Releasing" section documents `build/` exclusion at tag time.

**Skill descriptions referenced from documentation.**
Shortening descriptions may invalidate any documentation that quotes them verbatim.
Grep for the current descriptions before editing.

## Test Plan

- `claude plugin validate plugins/cdocs/.claude-plugin/plugin.json` passes.
- `claude plugin validate .claude-plugin/marketplace.json` passes.
- `claude plugin tag` against the current commit produces a valid `cdocs--v0.1.x` tag without pushing, and correctly resolves the cdocs plugin from the monorepo layout.
- Fresh install in a scratch project against a sandboxed `CLAUDE_CONFIG_DIR` with a temporary managed-settings `strictKnownMarketplaces` source-pattern allowlist: install succeeds when the allowlist covers the clauthier path and the project registers it in `extraKnownMarketplaces`; marketplace add fails with the enterprise-policy error when the path is excluded.
- All `plugins/cdocs/skills/*/SKILL.md` `description` fields are at most 250 characters.

## Verification Methodology

1. Make the changes on a feature branch.
2. Run `claude plugin validate` on both manifests.
3. Run `claude plugin tag --help` and confirm the documented release flow in the README matches actual tool behavior.
4. Run the strict-mode install test in a scratch directory.
5. `awk -v RS='---\n' 'NR==2 {print length}' plugins/cdocs/skills/*/SKILL.md` (or equivalent) to spot any description over 250 characters.
6. `claude plugin list` confirms cdocs still loads after manifest updates.

## Implementation Phases

A single phase given the small surface.

Files touched:
- `.claude-plugin/marketplace.json` (`$schema` only).
- `plugins/cdocs/.claude-plugin/plugin.json` (`$schema` only).
- `plugins/cdocs/README.md` (new "Releasing" section).
- `plugins/cdocs/skills/*/SKILL.md` (description-length adjustments only if any exceed 250 characters).

Constraints:
- Do not change `name` or any existing semver-incompatible fields.
- Do not touch the OpenCode build script.
- Do not modify skill content beyond description-field length, except as needed to keep meaning intact when shortening.

Acceptance:
- All test-plan items pass.
- A contributor reading the README can release a new cdocs version using `claude plugin tag` without ad-hoc git tag commands.
- All cdocs skills render fully in the type-to-filter menu.
