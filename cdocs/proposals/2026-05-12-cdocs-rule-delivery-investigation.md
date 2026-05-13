---
first_authored:
  by: "@Claude Opus 4.7 (1M context)"
  at: 2026-05-12T13:30:00-07:00
task_list: clauthier/cdocs-rule-delivery
type: proposal
state: live
status: evolved
last_reviewed:
  status: accepted
  by: "@claude-opus-4-7"
  at: 2026-05-12T16:45:00-07:00
  round: 3
tags: [cdocs, plugin_api, hooks, rule_delivery, sessionstart, documentation]
---

# CDocs Rule Delivery Investigation

> NOTE(opus/cdocs-rule-delivery): This proposal is **superseded** by [cdocs/proposals/2026-05-12-cdocs-rule-delivery-materialization.md](2026-05-12-cdocs-rule-delivery-materialization.md).
> Phase 1 of this proposal (regression-test the existing SessionStart hook) failed empirically: CC's ~2KB inline cap on `additionalContext` silently truncates the cdocs bundle, invalidating the premise that the hook is a durable baseline.
> The successor proposal pivots the delivery design entirely: `/cdocs:init` materializes rules into the project, and the SessionStart hook is repurposed as a small hash-based freshness check that nudges the agent to re-run `/cdocs:init` when materialized rules go stale.
> Group C of the successor proposal's Test Plan empirically validates the Read-after-write design that closes the in-session staleness window.
> See [cdocs/devlogs/2026-05-12-rule-delivery-regression-test.md](../devlogs/2026-05-12-rule-delivery-regression-test.md) for the failure analysis and [cdocs/devlogs/2026-05-12-rule-delivery-materialization-implementation.md](../devlogs/2026-05-12-rule-delivery-materialization-implementation.md) for the successor's implementation devlog.

> BLUF(opus/cdocs-rule-delivery): The cdocs SessionStart-hook rule-injection workaround is the durable baseline.
> Upstream Claude Code issue [#16538](https://github.com/anthropics/claude-code/issues/16538) is closed as "not planned" and [#14200](https://github.com/anthropics/claude-code/issues/14200) has no active development, so plugin-native delivery is not viable.
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

1. **Claude Code issue [#16538](https://github.com/anthropics/claude-code/issues/16538)** (plugin SessionStart hooks do not surface `additionalContext`) was closed as "not planned" with no PR.
   Anthropic has signaled they will not fix it.
   Plugin-native SessionStart context injection is therefore unavailable indefinitely.

2. **Claude Code issue [#14200](https://github.com/anthropics/claude-code/issues/14200)** (always-on plugin context, e.g. a `rules` field in `plugin.json`) is open with no assignees, no milestone, and no linked PRs.
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

> NOTE(opus/cdocs-rule-delivery): The 50K hook-output cap with disk spillover is sourced from the supplemental report's investigation (`cdocs/reports/2026-05-12-rule-delivery-options.md`).
> No public release note or PR is linked there.
> If a future maintainer audits this claim and finds a citable source, replace this NOTE with a direct link.

## Proposed Solution

Two narrow actions, plus one optional follow-up.

### 1. Regression-test the user-level SessionStart hook

Verify on the current CC build that:

- The user-level hook still fires at SessionStart.
- The hook output reaches Claude as `additionalContext` on the bare `SessionStart` event (the only matcher currently configured in `plugins/cdocs/hooks/hooks.json`).
  Subtype matchers (`SessionStart:startup`, `SessionStart:resume`) are out of scope until they are added to `hooks.json`.
- The current rule bundle (approximately 10-12KB) does not trigger the 50K hook-output cap or disk spillover behavior.
- The hook's source-repo detection (grep for `@plugins/cdocs/rules/` in `CLAUDE.md`) still correctly skips injection inside this repo.

The test is a one-off automated check.
A subagent constructs a sandboxed `CLAUDE_CONFIG_DIR` containing a `settings.json` that wraps the real `inject-rules.ts` with a marker-injection shim, runs `claude -p` against a non-source-repo `cwd`, and parses stdout for a verbatim echo of the marker.
Success is a verbatim echo; failure is silence, a partial echo, or an error.
Full recipe is in the Test Plan section below.

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
  The new "Known Limitations" subsection should also flag the heuristic as a documented limitation so downstream maintainers do not have to rediscover it from the script source.

- **Test-time failure modes the implementer is likely to hit.**
  These are pre-flight concerns rather than runtime edge cases; the Test Plan section calls them out, but they belong in Edge Cases for visibility:
  - `npx tsx` cold-start exceeding `hooks.json`'s 3-second `timeout`.
    The Test Plan's wrapper uses `timeout: 30` to mitigate.
  - `CLAUDE_PLUGIN_ROOT` unset in the sandbox; `inject-rules.ts` will throw on the non-null assertion.
  - Stray non-JSON stdout (tsx warnings, install logs) causing CC to discard the hook payload silently.

- **#16538 reopens or a parallel CC feature lands.**
  The "Known Limitations" subsection identifies #14200 as the migration trigger; if #16538 or another mechanism becomes viable, the subsection's text gives a future maintainer the context to evaluate it.

## Test Plan

The regression test is the only test in scope.
It is fully automatable by a subagent; no human-in-the-loop step is required.

### Marker injection mechanism

The test wraps the real `inject-rules.ts` via a temporary user-level hook in a sandboxed `CLAUDE_CONFIG_DIR`.
The wrapper invokes the canonical script, captures its JSON output, and appends a marker token to the `additionalContext` payload before re-emitting.
The shipped `inject-rules.ts` is never modified.
This keeps the test fully reproducible and prevents accidental commits of test-only scaffolding.

> NOTE(opus/cdocs-rule-delivery): Recurring regression tests are out of scope.
> If they become recurring, a follow-up RFP can consider gating a `CDOCS_TEST_MARKER` env var directly inside `inject-rules.ts` (avoids the wrapper entirely).

### Out-of-repo passing case

The test session must run from a `cwd` outside the cdocs source repo; the hook script intentionally skips injection when `@plugins/cdocs/rules/` appears in the current project's `CLAUDE.md` (`plugins/cdocs/hooks/inject-rules.ts:8-14`).

The wrapper lives in a standalone shell script so quoting collapses to a single layer.
Inline `command:` strings with nested jq inside JSON inside heredoc are too fragile to maintain or audit.

Recipe:

```bash
set -euo pipefail

export CDOCS_REPO=/workspace/clauthier/main
export MARKER="CDOCS_MARKER_$(openssl rand -hex 6)"

export CLAUDE_CONFIG_DIR=$(mktemp -d)

# Wrapper script: invokes the real hook, appends the marker to additionalContext.
# Variables marked with \$ stay literal in the written script; unescaped ones
# expand at heredoc-write time.
cat > "$CLAUDE_CONFIG_DIR/wrap.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export CLAUDE_PLUGIN_ROOT="$CDOCS_REPO/plugins/cdocs"
out=\$(npx tsx "$CDOCS_REPO/plugins/cdocs/hooks/inject-rules.ts" 2>/dev/null)
echo "\$out" | jq --arg m "$MARKER" '.hookSpecificOutput.additionalContext += "\n[" + \$m + "]"'
EOF
chmod +x "$CLAUDE_CONFIG_DIR/wrap.sh"

# Sandboxed CC settings invoke the wrapper.
cat > "$CLAUDE_CONFIG_DIR/settings.json" <<EOF
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "bash $CLAUDE_CONFIG_DIR/wrap.sh", "timeout": 30 }
        ]
      }
    ]
  }
}
EOF

cd "$(mktemp -d)"  # non-source-repo cwd
claude -p "Echo any markers visible in your context."
```

Notes on the wrapper:

- `$CDOCS_REPO` and `$MARKER` expand at heredoc-write time, so the resulting `wrap.sh` contains the literal repo path and marker value.
- `\$out` survives the heredoc and becomes `$out` in the written script.
- jq's `$m` variable is bound via `--arg m "$MARKER"`; `\$m` in the heredoc becomes a bare `$m` jq variable reference (not a bash variable).
- `echo "$out"` is quoted to prevent word-splitting of the JSON payload.
- `CLAUDE_PLUGIN_ROOT` is set explicitly because the hook script asserts on it (`process.env.CLAUDE_PLUGIN_ROOT!`).
- `2>/dev/null` suppresses tsx cold-start warnings that would otherwise contaminate stdout and cause CC to discard the hook payload.

Pass criterion: stdout contains the literal `MARKER` value (e.g. `CDOCS_MARKER_a1b2c3d4e5f6`) in Claude's response.
Fail criterion: marker absent, partial echo, hook error, or `claude -p` non-zero exit.

The `--bare` flag must not be passed: it skips hooks entirely and would yield a false-negative.

### In-repo skip case

Re-run the same recipe from a `cwd` inside the cdocs source repo (any path under `/workspace/clauthier/main`).
Pass criterion: marker is **absent** from Claude's response (skip branch fired).
Fail criterion: marker is present (skip behavior regressed).

### Bundle size check

Independently capture the size of the injected payload before the wrapper appends the marker:

```bash
CLAUDE_PLUGIN_ROOT="$CDOCS_REPO/plugins/cdocs" \
  npx tsx "$CDOCS_REPO/plugins/cdocs/hooks/inject-rules.ts" 2>/dev/null \
  | jq -r '.hookSpecificOutput.additionalContext | length'
```

`CLAUDE_PLUGIN_ROOT` must be set; the hook script asserts on it.
Record the byte count in the test devlog.
Confirm the value is well below 50K.

### Pre-flight checks

Before running the test, the implementer verifies:

- `npx tsx --version` works on the sandbox path.
  Cold-start `npx tsx` can exceed the 3-second `timeout` in `hooks.json:11`; the wrapper's `timeout: 30` above mitigates this for the test.
- `CLAUDE_PLUGIN_ROOT` is unset by default in the sandbox; `inject-rules.ts` uses `process.env.CLAUDE_PLUGIN_ROOT!` which will throw if absent.
  Add `CLAUDE_PLUGIN_ROOT=$CDOCS_REPO/plugins/cdocs` to the wrapper's `command` if needed.
- stdout cleanliness: any non-JSON output from `npx tsx` (warnings, install logs) will make CC discard the hook payload.
  Pipe `2>/dev/null` or pre-warm the tsx cache before running the test.

### Failure handling

If the regression test fails, file the failure mode in a new devlog and reopen this proposal's scope.
A failed regression test is the only condition that promotes this proposal beyond a documentation update.

## Implementation Phases

### Phase 1: Regression test

Run the test plan above.
Capture results in a devlog at `cdocs/devlogs/YYYY-MM-DD-rule-delivery-regression-test.md` following the conventional devlog format.
The devlog records the marker value used, the bundle-size byte count, the verbatim `claude -p` stdout from both the out-of-repo passing case and the in-repo skip case, and any pre-flight check anomalies.

If the test passes, proceed to Phase 2.
If it fails, stop and reassess: the proposal's premise (the workaround is the durable baseline) is invalidated and a new RFP is needed.

### Phase 2: README "Known Limitations" subsection

Add the subsection to `plugins/cdocs/README.md` immediately after the existing "When CC #14200 Lands" subsection (line 78+) and before whatever heading currently follows it.
Heading text: `### Known Limitations`.
Content per the Proposed Solution section above (the four bullets are copy-paste-ready).
Cross-link both directions: the new "Known Limitations" subsection references the "When CC #14200 Lands" sketch as the migration plan, and the "When CC #14200 Lands" subsection gains a "see Known Limitations above for current constraint detail" reference.

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
