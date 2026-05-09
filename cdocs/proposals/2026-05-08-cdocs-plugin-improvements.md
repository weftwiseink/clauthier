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
  at: 2026-05-08T16:30:00-07:00
  round: 2
tags: [cdocs, plugin_api, devcontainer, hooks, marketplace]
---

# CDocs Plugin Improvements: May 2026 Round

> BLUF: Five phases.
> Two commitments: Phase 1 polishes the cdocs manifest and release flow against the May-2026 CC plugin API; Phase 2 marks the in-Dockerfile path-mirror symlink as a known stopgap.
> Two scoped investigations: Phase 3 retests issue #16538 to learn whether the SessionStart-hook rule-injection workaround can be retired; Phase 4 surveys CC plugin install-time hook surfaces for an alternative rule-delivery path.
> One deferred ergonomics phase: Phase 5 covers `${CLAUDE_EFFORT}` adaptation and slash-command collision audit, gated on demand.

## Objective

Keep cdocs in step with the CC plugin API surface and tooling that landed March-May 2026, capture a known devcontainer stopgap so it does not become tribal knowledge, and scope the larger rule-delivery rework before committing to a design.

## Background

Two inputs drive this round.

**The May 2026 plugin API surface.**
See [the March-May 2026 CC plugin API report](../reports/2026-05-06-cc-plugin-api-updates.md).
Hook capabilities expanded substantially: PostToolUse `updatedToolOutput`, MCP tool invocation, conditional `if`, PermissionDenied.
Marketplace policy hardened: `blockedMarketplaces`, `strictKnownMarketplaces`, semver tags via `claude plugin tag`.
The skill menu added type-to-filter search with a 250-character description cap.
Issue #16538 (plugin-defined SessionStart hooks not surfacing `additionalContext`) is reported as still unfixed.
The report's `PostInstall` hook recommendation is unverified and may not correspond to a real CC lifecycle event.

**Devcontainer plugin loading under lace bare-worktree.**
The lace-managed devcontainer mounts the project at a different absolute path than the host (`/workspace/clauthier/main` versus the host's `/var/home/...`).
Claude Code keys plugin records by absolute project path in `~/.claude/plugins/installed_plugins.json` and `known_marketplaces.json`, both of which are bind-mounted from the host.
Result: a plugin installed on the host fails to load inside the devcontainer because its `installLocation` does not exist there.
A Dockerfile-level symlink from the host path to `/workspace/clauthier` resolves the mismatch.

> NOTE(opus/cdocs-improvements): Issues #14200 and #16538 are related but distinct.
> #14200 is the broader "always-on plugin context" architectural gap.
> #16538 is the specific symptom of plugin-defined SessionStart hooks not surfacing `additionalContext`.
> Resolution of #16538 alone does not close #14200; the always-loaded-rules model is broader than SessionStart injection.

> NOTE(opus/cdocs-improvements): Project-level `extraKnownMarketplaces` is not a viable workaround for the path-mirror need.
> CLI subcommands honor it only partially.
> Settings-sourced overrides require the alias to match the marketplace.json `name` field.
> Existing user-level marketplace entries with the same alias silently win over project overrides.
> The on-disk `.claude/settings.local.json` is shared between host and container via the bind-mount, so absolute-path overrides break one side or the other.

## Proposed Solution

Five phases, ordered by risk-adjusted value.
Phases 1-2 are commitments.
Phases 3-4 are scoped investigations whose outcomes feed a follow-up proposal.
Phase 5 is deferred until demand surfaces.

### Phase 1: Marketplace and release-flow polish

Cheap, mechanical, no behavior change for users.

- Add `$schema` to `.claude-plugin/marketplace.json` and `plugins/cdocs/.claude-plugin/plugin.json`.
  `version` and `description` already exist in both manifests; `$schema` is the genuinely new field.
  The implementer identifies the canonical schema URL during implementation.
  If no canonical URL exists, omit the field rather than invent one.
- Adopt `claude plugin tag` for cdocs releases.
  Document the release procedure in `plugins/cdocs/README.md` under a new "Releasing" section.
  Verify the tool correctly identifies the cdocs plugin in the monorepo layout (plugin nested at `plugins/cdocs/` under a marketplace at the repo root).
- Verify a fresh install of cdocs into a scratch project that has `strictKnownMarketplaces: true` set: install succeeds when the marketplace is registered in `extraKnownMarketplaces`, fails clearly otherwise.
- Audit all skill descriptions in `plugins/cdocs/skills/*/SKILL.md` for the 250-character cap that the type-to-filter skill menu enforces.

### Phase 2: Devcontainer symlink stopgap marker

The Dockerfile creates a symlink from the maintainer's host project path to `/workspace/clauthier` so plugin records keyed by the host path resolve inside the container.
The symlink is hardcoded to a single host layout and exists only because the underlying CC plugin-record-keying behavior makes the mismatch unavoidable for the bind-mounted-config setup.

- Add a `TODO` comment immediately above the symlink `RUN` line marking it as a personal stopgap and pointing at the relevant CC issue (#14200 / #16538) as the upstream blocker.
- Do not parameterize, generalize, or document for outside contributors at this time.

### Phase 3 (investigation): SessionStart-hook replacement viability

Goal: determine whether the cdocs SessionStart-hook rule-injection workaround can be retired or simplified.

- Re-test issue **#16538 specifically** on the latest CC build by writing a minimal plugin with a SessionStart hook emitting `additionalContext: "TEST_MARKER_42"`, installing it, and inspecting whether the marker reaches the model.
  Test all three SessionStart subtypes independently: `SessionStart`, `SessionStart:startup`, `SessionStart:resume`.
  A partial fix is **not** sufficient to trigger a migration; wait for full resolution.
- Independently verify that the existing user-level hook fallback continues to inject cdocs rule content correctly on the build under test.
  A regression in the workaround (e.g., due to the new 50K hook-output cap with disk spillover) would otherwise be invisible.
- If #16538 is fully resolved: scope a follow-up proposal to migrate rules into plugin-native always-loaded files and remove the SessionStart hook.
  Note that #14200 (broader always-on context gap) may remain open even after #16538 closes.
- If still broken or partially fixed: keep the user-level hook fallback and add a "known limitations" subsection to the README.

The investigation outputs a one-page `cdocs/reports/YYYY-MM-DD-sessionstart-hook-retest.md`, not code changes.

### Phase 4 (investigation): install-time rule materialization

If Phase 3 confirms #16538 remains unfixed, investigate alternative delivery mechanisms.

- Survey CC's plugin install-time hook surface generally, not just whether a literal `PostInstall` event exists.
  Frame the question as: "does CC have any plugin install-time hook analogous to npm postinstall?"
  Candidates: `Setup` triggered via `--init`, `SessionStart:startup` on first session after install, lifecycle scripts referenced from `plugin.json`, or any other CC-side mechanism.
- Treat the OpenCode build's `scripts/postinstall.js` as prior art, not as a CC-side mechanism.
  If a CC analogue exists, prototype writing rule files to `~/.claude/rules/` or `.claude/rules/` on install.
  If a CC analogue does not exist but a hybrid (npm postinstall plus CC-side activation) is feasible, scope it via `/cdocs:rfp`.
- If no viable mechanism exists at all, append a one-line conclusion to the Phase 3 report and close the investigation.

### Phase 5 (deferred): skill ergonomics

Lower-priority polish, gated on Phase 1-3 completion and surfaced demand.

- Adopt `${CLAUDE_EFFORT}` in `/cdocs:propose` and `/cdocs:report` to scale verbosity (low effort: brief checklist; high effort: full multi-section template).
- Verify slash command resolution for `cdocs:*` commands does not collide with any other plugin in a downstream user's marketplace set.

## Important Design Decisions

**Defer Phase 3-4 commitments behind investigation.**
The report's recommendations around hook-based rule delivery rest on partly-unverified claims (`PostInstall` hooks, exact #16538 status).
Two short investigations are cheaper than building the wrong thing and ripping it out.

**Treat the symlink as a personal stopgap, not infrastructure.**
The repository has a single maintainer.
A parameterized `HOST_PROJECT_PARENT` arg adds devcontainer surface area for a contributor base of one.
The TODO comment captures the maintenance reality (the symlink is a stopgap) without paying for generality nobody will use.

**Treat the report's `PostInstall` hook recommendation as a hypothesis, not a design.**
Verify in Phase 4 that any plugin install-time hook surface exists before committing to a rule-materialization design.

## Edge Cases / Challenging Scenarios

**Issue #16538 partial fix.**
A fix that handles `SessionStart:startup` but not `SessionStart:resume` (or vice versa) does not justify migrating off the workaround.
Phase 3 explicitly tests all three subtypes.

**Marketplace name collision under `strictKnownMarketplaces`.**
If a downstream user adds the GitHub-hosted `weft-marketplace` and the local `clauthier` marketplace, `cdocs@clauthier` and `cdocs@weft-marketplace` may both appear in `claude plugin list`.
Phase 1's strict-mode test should explicitly cover this.

**`claude plugin tag` and the OpenCode build directory.**
The build script generates artifacts under `build/cdocs/opencode/`.
Verify `claude plugin tag` (which reads `plugin.json` and the enclosing marketplace entry) does not get confused by the generated build directory.
If it does, add `build/` to a tag-time ignore list.

## Test Plan

Phase-by-phase.

**Phase 1.**
- `claude plugin validate plugins/cdocs/.claude-plugin/plugin.json` passes after manifest updates.
- `claude plugin validate .claude-plugin/marketplace.json` passes.
- `claude plugin tag` against a working-tree commit produces a valid `cdocs--v0.1.x` tag without pushing, and correctly resolves the cdocs plugin from the monorepo layout.
- Fresh install in a scratch project with `strictKnownMarketplaces: true`: install succeeds when the marketplace is in `extraKnownMarketplaces`, fails clearly when it isn't.
- All cdocs skill descriptions render fully in the type-to-filter menu (no 250-character truncation).

**Phase 2.**
- Comment present, references the upstream CC issue, and is the only change.

**Phase 3.**
- Minimal repro plugin emits `TEST_MARKER_42` via SessionStart hook.
- Marker presence checked in all three subtypes (`SessionStart`, `SessionStart:startup`, `SessionStart:resume`).
- Existing user-level hook fallback verified to inject rule content correctly on the same build.
- Result documented verbatim in the report.

**Phase 4.**
- Survey of CC docs and source for any install-time hook surface.
- Outcome documented in the Phase 3 report (one-line append) or scoped to `/cdocs:rfp` if a viable mechanism is found.

**Phase 5.**
- `${CLAUDE_EFFORT}` substitution renders correctly in `/cdocs:propose` at low/medium/high.
- No `cdocs:*` slash command name collisions with other commonly-installed plugins.

## Verification Methodology

Per phase, the implementer should:

1. Make the change on a feature branch.
2. Run `claude plugin validate` and `claude plugin list` to confirm the plugin still loads.
3. For Phase 3, capture the SessionStart hook test output verbatim in the report.

The author checklist (`plugins/cdocs/skills/propose/SKILL.md`) gates each phase before merge.

## Implementation Phases

Per-phase content is described in the Proposed Solution section.
This section adds files-touched, constraints, and acceptance criteria only.

### Phase 1

Files touched:
- `.claude-plugin/marketplace.json`
- `plugins/cdocs/.claude-plugin/plugin.json`
- `plugins/cdocs/README.md` (Releasing section)
- `plugins/cdocs/skills/*/SKILL.md` (description-length adjustments only if any exceed 250 characters)

Constraints:
- Do not change `name` or existing semver-incompatible fields.
- Do not touch the OpenCode build script in this phase.

Acceptance: cdocs releases ship via `claude plugin tag` without ad-hoc git tag commands, and all skills surface correctly in the type-to-filter menu.

### Phase 2

Files touched:
- `.devcontainer/Dockerfile` (TODO comment only).

Constraints:
- No parameterization, no generalization, no Dockerfile-arg additions.

Acceptance: a future maintainer reading the Dockerfile understands the symlink is a stopgap and what upstream issue would let it be removed.

### Phase 3

Output:
- `cdocs/reports/YYYY-MM-DD-sessionstart-hook-retest.md`

Constraints:
- Do not modify the existing SessionStart hook implementation while testing.
- Use a separate scratch plugin directory; do not contaminate the cdocs marketplace.

Acceptance: report concludes definitively for each `SessionStart` subtype whether plugin-defined hooks can inject `additionalContext` on the current CC build, and confirms whether the user-level fallback still works.

### Phase 4

Output:
- Either a follow-up RFP for an install-time delivery mechanism, or a one-line conclusion appended to the Phase 3 report stating the option is unavailable.

Constraints:
- No prototype code lands on `main` in this phase.
- If a viable mechanism exists, scope it via `/cdocs:rfp`, not direct implementation.

Acceptance: a clear yes/no on whether install-time delivery is feasible, accounting for hybrid mechanisms (e.g., npm postinstall combined with CC-side activation), not just a literal `PostInstall` hook.

### Phase 5 (deferred)

Trigger: Phases 1-3 complete and at least one user requests adaptive skill verbosity, or a real slash-command collision is reported.

Files touched:
- `plugins/cdocs/skills/{propose,report}/SKILL.md`

Constraints:
- Do not break existing invocations that don't supply `${CLAUDE_EFFORT}`.

Acceptance: skills behave identically when `${CLAUDE_EFFORT}` is unset; no `cdocs:*` command shadows or is shadowed by another commonly-installed plugin.
