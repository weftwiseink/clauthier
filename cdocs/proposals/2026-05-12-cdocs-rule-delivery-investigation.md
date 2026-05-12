---
first_authored:
  by: "@Claude Opus 4.7 (1M context)"
  at: 2026-05-12T13:30:00-07:00
task_list: clauthier/cdocs-rule-delivery
type: proposal
state: live
status: wip
tags: [cdocs, plugin_api, hooks, rule_delivery, sessionstart, documentation]
---

# CDocs Rule Delivery Investigation

> BLUF(opus/cdocs-rule-delivery): The cdocs SessionStart-hook rule-injection workaround is the durable baseline.
> Upstream CC issue #16538 is closed as "not planned" and #14200 has no active development, so plugin-native delivery is not viable.
> This proposal commits to two narrow actions: (1) regression-test the existing user-level SessionStart hook on the current CC build, since the supplemental report's live test was blocked and the new 50K hook-output cap with disk spillover could silently break injection; (2) add a "Known Limitations" subsection to `plugins/cdocs/README.md` that names #14200 as the upstream blocker and states what would trigger a migration.
> An optional follow-up is a recurring health-check on #14200.
> **Motivated By:** [cdocs/proposals/2026-05-08-cdocs-plugin-improvements.md](2026-05-08-cdocs-plugin-improvements.md), [cdocs/reports/2026-05-06-cc-plugin-api-updates.md](../reports/2026-05-06-cc-plugin-api-updates.md).
> **Primary input:** [cdocs/reports/2026-05-12-rule-delivery-options.md](../reports/2026-05-12-rule-delivery-options.md).

## Objective

Confirm the existing rule-delivery mechanism still works on the current CC build and document its upstream constraints so future maintainers understand why the workaround exists and when to revisit it.

The cdocs plugin delivers writing conventions, workflow patterns, and frontmatter spec to the model via a user-level SessionStart hook that injects rule content as `additionalContext`.
This is a workaround for upstream CC issue #14200 (no first-class "always-on plugin context").
Plugin-defined SessionStart hooks specifically do not surface `additionalContext` (CC issue #16538, closed as "not planned" with no PR).

The investigation behind this proposal closed the broader migration question.
What remains is a narrow regression check and a documentation update.

## Scope

In scope:

- Regression-test the user-level SessionStart hook on the current CC build, including verification that the rule bundle does not trip the 50K hook-output cap or disk spillover.
- Add a "Known Limitations" subsection to `plugins/cdocs/README.md` citing #14200 and #16538 and stating the migration trigger.
- Optionally, establish a lightweight recurring health-check on #14200.

Out of scope:

- Migrating off the SessionStart hook.
- Building a hybrid npm-postinstall plus CC-side activation mechanism.
- Changes to AGENTS.md, the OpenCode cross-target fallback, or `build/cdocs/opencode/`.
- New plugin features that depend on plugin-native rule injection.

## Background

The user-level SessionStart hook in `~/.claude/settings.json` invokes `plugins/cdocs/hooks/inject-rules.ts`.
The script reads `${CLAUDE_PLUGIN_ROOT}/rules/*.md`, strips frontmatter, and emits the concatenated content as `hookSpecificOutput.additionalContext`.
It skips injection in the source repo by detecting `@plugins/cdocs/rules/` imports in the project's CLAUDE.md.

Three upstream facts shape this proposal:

1. **CC issue #16538** (plugin SessionStart hooks do not surface `additionalContext`) was closed as "not planned" with no PR.
   Anthropic has signaled they will not fix it.
   Plugin-native SessionStart context injection is therefore unavailable indefinitely.

2. **CC issue #14200** (always-on plugin context, e.g. a `rules` field in `plugin.json`) is open with no assignees, no milestone, and no linked PRs.
   It is the only realistic migration trigger.

3. **No CC plugin install-time hook surface exists** analogous to npm postinstall.
   The candidate types surveyed (literal `PostInstall`, `Setup` via `--init`, `SessionStart:startup` heuristic, `plugin.json` lifecycle scripts) either do not exist, are scoped to dependency setup rather than rule materialization, or fire at session-start rather than install-time.

The supplemental report attempted a live empirical retest of #16538 but was blocked by an auth issue in the report subagent's sandbox.
Conclusions rest primarily on GitHub-issue closure status, not in-environment repro.
Specifically, the user-level SessionStart hook fallback was not empirically re-verified on the current CC build.
This gap is the motivation for the regression-test action below.

A separate risk emerged from the broader investigation: CC recently introduced a 50K hook-output cap with disk spillover.
The current rule bundle is approximately 10-12KB and should be well under the cap, but the spillover behavior has not been tested with `additionalContext` injection.
If spillover redirects `additionalContext` to disk in a way Claude does not read at session start, the workaround would silently fail.

## Proposed Solution

Two narrow actions, plus one optional follow-up.

### 1. Regression-test the user-level SessionStart hook

Verify on the current CC build that:

- The user-level hook in `~/.claude/settings.json` still fires at SessionStart.
- The hook output reaches Claude as `additionalContext` for all three subtypes that are configured (`SessionStart`, `SessionStart:startup`, `SessionStart:resume`).
- The current rule bundle (approximately 10-12KB) does not trigger the 50K hook-output cap or disk spillover behavior.
- The hook's source-repo detection (grep for `@plugins/cdocs/rules/` in CLAUDE.md) still correctly skips injection in this repo.

The test is a one-off: a small marker string is appended to the injected `additionalContext`, a fresh session is started, and Claude is asked to echo any markers it sees.
Success is a verbatim echo of the marker; failure is silence or a partial echo.

### 2. Add a "Known Limitations" subsection to `plugins/cdocs/README.md`

The subsection lives under the existing "Rules Integration" section.
It states:

- The plugin's rule delivery on Claude Code depends on a user-level SessionStart hook because plugin-defined SessionStart hooks do not surface `additionalContext` (CC issue #16538, closed as "not planned").
- The hook is installed at user scope, fires on every SessionStart with mild overhead, and the rules are not visible in the IDE rule-picker.
- The migration trigger is resolution of CC issue #14200 (always-on plugin context).
  When #14200 lands, the SessionStart hook can be replaced with a `rules` declaration in `plugin.json` (the README's existing "When CC #14200 Lands" subsection already sketches this transition).
- OpenCode is unaffected: it discovers rules natively via `.opencode/rules/cdocs/` (delivered by `scripts/postinstall.js`) and via the AGENTS.md fallback.

### 3. (Optional) Recurring #14200 health-check

A quarterly reminder to check #14200's status (assignees, linked PRs, milestone).
Low cost of inclusion, minimal urgency.
If included, it is a calendar entry or a `cdocs:status` query against a tracking devlog, not a new automation surface.

Include this only if the maintainer judges the maintenance burden trivial.
Otherwise leave it to a follow-up RFP.

## Important Design Decisions

### Why keep the SessionStart hook rather than migrate

CC issue #16538 is closed as "not planned" with no PR.
Plugin-native SessionStart context injection is therefore unavailable indefinitely.
Migration paths surveyed (install-time hook, `.claude/rules/` discovery, hybrid npm-postinstall) either do not exist in CC or add complexity without reducing user setup burden.
See the supplemental report's "Why Migration Paths Are Blocked" section for the full matrix.

### Why regression-test now rather than wait

The supplemental report's live test was blocked by sandbox auth.
The user-level hook fallback was last empirically verified on an earlier CC build.
The 50K hook-output cap with disk spillover is a recent CC feature whose interaction with `additionalContext` is unverified.
Confirming the workaround still works is cheap and removes the largest empirical gap left by the investigation.

### Why a README "Known Limitations" subsection rather than inline NOTEs

The constraints affect users (hook scope, IDE visibility) and contributors (migration trigger).
Both audiences read the README before the hook source.
Inline NOTEs in `inject-rules.ts` would be discoverable only to contributors who are already debugging the hook.

### Why no automation around #14200

The cost of a missed signal on #14200 is small: the SessionStart hook continues to work, and migration is an opportunistic improvement rather than an urgent one.
A quarterly manual check is sufficient.

## Edge Cases

- **Rule bundle grows past 50K.**
  Unlikely in the near term (current bundle is approximately 10-12KB), but the regression test should record the bundle size so a future maintainer can compare.
  If the bundle ever approaches the cap, the hook should be revisited to either prune content or paginate across multiple hooks.

- **User-level hook is uninstalled or never installed.**
  This is expected for fresh installs prior to `/cdocs:init`.
  The README "Known Limitations" subsection should make clear that the hook is required for CC and is installed by `/cdocs:init`.

- **Source-repo detection false positive or false negative.**
  If a project's CLAUDE.md happens to contain the substring `@plugins/cdocs/rules/` without actually importing them, the hook skips injection incorrectly.
  Conversely, a restructured import path would cause duplicate injection.
  Both modes are noted in the existing README and remain unchanged.

- **#16538 reopens or a parallel CC feature lands.**
  The "Known Limitations" subsection identifies #14200 as the migration trigger; if #16538 or another mechanism becomes viable, the subsection's text gives a future maintainer the context to evaluate it.

## Test Plan

The regression test is the only test in scope.

1. Install the user-level SessionStart hook fresh (or confirm the current install).
2. Modify `inject-rules.ts` locally (or wrap via a temporary hook) to append a unique marker token to the `additionalContext` payload.
3. Start a fresh CC session in a non-source-repo directory.
4. Prompt: "Echo any markers visible in your context."
5. Pass criterion: Claude echoes the marker verbatim.
6. Fail criterion: silence, partial echo, or an error.

Additionally:

- Record the rule bundle's serialized size and confirm it is well below 50K.
- Run the test for all three subtypes that are configured in the user-level hook.
  If only `SessionStart` is configured, only that subtype is exercised.
- Confirm in-repo execution still skips injection.

If the test fails, file the failure mode in a new devlog and reopen this proposal's scope.
A failed regression test is the only condition that promotes this proposal beyond a documentation update.

## Implementation Phases

### Phase 1: Regression test

Run the test plan above.
Capture results in a devlog under `cdocs/devlogs/`.
If the test passes, proceed to Phase 2.
If it fails, stop and reassess: the proposal's premise (the workaround is the durable baseline) is invalidated and a new RFP is needed.

### Phase 2: README "Known Limitations" subsection

Add the subsection to `plugins/cdocs/README.md` under the existing "Rules Integration" heading.
Content per the Proposed Solution section above.
Cross-link to the existing "When CC #14200 Lands" subsection so the migration trigger and the migration sketch are reachable from each other.

### Phase 3 (optional): Recurring #14200 health-check

If included: create a single tracking devlog or calendar entry referencing #14200.
No new automation surface, no recurring scheduled job.

Phases 1 and 2 are independent and may run in either order, though Phase 1 is the cheaper de-risking step.

## Open Questions

1. **Does the regression test pass on the current CC build?**
   Unresolved: the supplemental report's live test was blocked.
   This is the proposal's only load-bearing open question.

2. **Is the optional recurring #14200 health-check worth establishing?**
   Maintainer judgement.
   The supplemental report's "For Phase 4 (Longer-term)" recommendation already names #14200 as the trigger to watch, so any health-check is reinforcement rather than novel scope.

> NOTE(opus/cdocs-rule-delivery): The original RFP's four open questions on migration triggers, hybrid scope, OpenCode parity, and backwards compatibility are resolved by the supplemental report.
> The investigation found no viable migration path and no need for a coexistence story, so those questions are dropped.
