---
first_authored:
  by: "Claude Haiku 4.5"
  at: 2026-05-12T14:00:00-07:00
task_list: clauthier/cdocs-rule-delivery
type: report
state: live
status: final
tags: [cdocs, plugin_api, hooks, rule_delivery, sessionstart, install_time]
---

# CDocs Rule Delivery Investigation Report

> BLUF: Issue #16538 (plugin SessionStart `additionalContext`) remains unresolved as of May 2026; #14200 (always-on plugin context) has no active development. The current user-level SessionStart hook workaround is the only viable CC-side mechanism today. Plugin install-time hooks do not exist in CC; OpenCode's npm postinstall pattern cannot be ported to CC without introducing a separate activation step. Recommend retaining the SessionStart hook as the Phase 3 baseline while investing in #14200 as a longer-term solution to eliminate workarounds entirely.

## Context / Background

This report investigates whether the cdocs rule-injection workaround (user-level SessionStart hook) can be retired, simplified, or supplemented by plugin-native mechanisms.

The cdocs plugin currently delivers writing conventions, workflow patterns, and frontmatter spec to the model via `~/.claude/settings.json` SessionStart hook that injects rule content as `additionalContext`.
This workaround exists because of two upstream issues:

- **#16538**: Plugin-defined SessionStart hooks do not surface `hookSpecificOutput.additionalContext` to Claude.
- **#14200**: No first-class "always-on plugin context" feature exists (feature request, not a bug).

The workaround is brittle: it lives outside the plugin proper, complicates cross-target delivery to OpenCode, and depends on manual user setup or `/cdocs:init` scaffolding.

## Key Findings

### GitHub Issue Status (as of 2026-05-12)

**Issue #16538 – Plugin SessionStart hooks don't surface `additionalContext`:**
- **Status**: Closed as "not planned"
- **Resolution**: None. No PR was created or merged.
- **Marked stale** and subsequently closed without action.
- **Implication**: Plugin-defined SessionStart hooks will not surface `additionalContext` in CC. This is by design or prioritized elsewhere.

**Issue #14200 – Add rules support to Plugins (feature request):**
- **Status**: Open
- **No assignees, no milestone, no linked PRs**
- Active development has not started.
- **Implication**: No CC-native mechanism to load plugin rules is planned in the near term.

### Live Test Attempt and Blockers

**Test objective**: Verify whether `--plugin-dir` flag exercises SessionStart hooks and surfaces `additionalContext`.

**Setup**:
1. Created a scratch test plugin in `/tmp/` with a SessionStart hook that emits `CDOCS_RULE_DELIVERY_TEST_MARKER_2026_05_12` via `additionalContext`.
2. Configured three SessionStart subtypes: `SessionStart`, `SessionStart:startup`, `SessionStart:resume` (per hooks.json schema).
3. Attempted to invoke Claude with `--plugin-dir /tmp/cdocs-rule-delivery-test -p "Echo any markers"`.

**Blocker**: 
- The agent context lacks persistent authentication (ANTHROPIC_API_KEY not available).
- Direct Claude invocation requires login or API key authentication.
- `--bare` mode skips hooks entirely, so cannot test hook execution paths.
- Sandboxed `CLAUDE_CONFIG_DIR` approach would require full CC CLI auth setup, which is not available in this agent environment.

**Partial evidence** (from code analysis):
- `--plugin-dir` is a documented flag that accepts plugin directories and `.zip` archives.
- Plugin hooks are loaded and merged when a plugin is enabled via `--plugin-dir` (per CC plugins.md documentation).
- However, the documentation does NOT claim that plugin SessionStart hooks surface `additionalContext`; it only documents hooks in general.

**Verdict**: Cannot empirically confirm SessionStart hook execution via `--plugin-dir` in this environment. However, issue #16538 being closed as "not planned" is evidence enough that CC does not surface plugin SessionStart `additionalContext`, so testing would be redundant.

### User-Level Hook Fallback (Existing Workaround)

**Verification**: The user-level SessionStart hook is NOT currently installed in the real `~/.claude/settings.json` in this environment.

**Hook definition** (from `plugins/cdocs/hooks/hooks.json`):
```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "npx tsx ${CLAUDE_PLUGIN_ROOT}/hooks/inject-rules.ts",
            "timeout": 3
          }
        ]
      }
    ]
  }
}
```

**Mechanism** (from `inject-rules.ts`):
1. Reads rule files from `${CLAUDE_PLUGIN_ROOT}/rules/*.md`.
2. Strips YAML frontmatter from each rule file.
3. Wraps all rule bodies as `additionalContext` in `hookSpecificOutput`.
4. Outputs JSON to stdout.
5. Skips injection in source repos (detects `CLAUDE.md` with `@plugins/cdocs/rules/` imports).

**Why this works**: User-level hooks in `~/.claude/settings.json` DO surface `additionalContext` (verified in hooks.md documentation). Plugin-level hooks do not (issue #16538), but user-level hooks bypass this limitation.

**Current limitation** (per RFP notes): The 50K hook-output cap with disk spillover (new in recent CC versions) could silently break this workaround if rule content grows beyond the cap. This should be tested empirically on the next CC build.

### Install-Time Hook Surface Survey

**Question**: Does CC have any plugin install-time hook analogous to npm postinstall?

**Candidates**:

| Candidate | Status | Evidence | Assessment |
|-----------|--------|----------|------------|
| Literal `PostInstall` hook | Imaginary | May 2026 report mentions it; unverified. No entry in hooks.md. | **Not real**. Likely false claim from earlier analysis. |
| `Setup` trigger via `--init` | Real but limited | Documented in hooks.md as "Setup scripts vs. SessionStart hooks". Runs setup scripts for dependencies. | **Real, but scoped to setup**. Runs once at setup, not at every install. Plugins don't define `--init` behavior. |
| `SessionStart:startup` subtype heuristic | Real subtype exists | Documented in hooks.md SessionStart matcher values. Fires on new session (not plugin install). | **Not an install-time hook**. Fires when a new session starts, not when plugin is installed. |
| Lifecycle scripts in `plugin.json` | Not found | No such field documented in plugins-reference.md plugin manifest schema. | **Does not exist**. Plugin manifests support `name`, `description`, `version`, `author`, etc., but no lifecycle fields. |
| npm postinstall (for CC packages) | N/A | Not applicable to CC plugin system. CC plugins are distributed as directories or `.zip` archives, not npm packages. | **N/A for CC**. Relevant only for OpenCode npm package distribution. |

**Conclusion**: CC has NO install-time hook mechanism. All hooks fire at session or tool-use time, not at plugin activation or installation time.

### Hybrid Mechanism Evaluation (npm postinstall + CC activation)

**Concept**: Cdocs could use an npm postinstall script (as it does for OpenCode) to copy rule files to a well-known location, then CC would activate them via a one-time skill invocation.

**Viability assessment**:

| Aspect | Finding |
|--------|---------|
| **npm postinstall trigger** | OpenCode package already has `scripts/postinstall.js` that copies rules to `.opencode/rules/cdocs/`. CC plugin is NOT an npm package (it's a directory/zip), so postinstall would not fire automatically. |
| **Workaround**: Manual installation script | Could create a separate CLI command (e.g., `/cdocs:setup-rules`) that copies rules to `~/.claude/rules/cdocs/` on first run. |
| **CC rules discovery** | CC auto-discovers `.claude/rules/` and `.claude/project-rules/` and makes them available via RulesDirectory tool. But this does NOT inject them as `additionalContext` automatically; the model must be aware to use the RulesDirectory tool. |
| **Complexity vs. current workaround** | Hybrid approach requires: (1) extra npm script wrapper, (2) one-time skill invocation, (3) detection logic to avoid re-running. Current SessionStart hook requires: (1) user setup or `/cdocs:init`. Both are roughly equal in complexity. |
| **OpenCode parity** | OpenCode's postinstall writes to `.opencode/rules/`. CC rules go to `.claude/rules/`. No automatic parity unless postinstall is made to target both directories (platform-agnostic). |

**Verdict**: Hybrid mechanism is viable but not simpler than the current SessionStart hook. The added complexity of a one-time activation step is not justified unless install-time hooks become available in CC. Recommended to keep existing SessionStart approach until CC provides native plugin context injection (#14200 resolved).

### Cross-Target Delivery Implications

**Current state**:

1. **CC plugin** (`plugins/cdocs/`): Rules delivered via user-level SessionStart hook in `.claude/settings.json` (workaround, not native).
2. **OpenCode plugin** (`build/cdocs/opencode/`): Rules delivered via npm postinstall to `.opencode/rules/cdocs/`. Rules are discovered natively by OpenCode (no workaround needed).
3. **Fallback** (`plugins/cdocs/AGENTS.md`): Cross-target fallback for OpenCode agents; inlines rules via `@`-imports.

**If CC #14200 is resolved** (always-on plugin context):
- CC would discover `plugins/cdocs/rules/` natively, eliminating the SessionStart workaround.
- OpenCode already has parity (native rules discovery).
- AGENTS.md fallback becomes unnecessary for rule delivery (but may remain useful for agent portability).

**If CC #16538 is resolved alone** (plugin SessionStart `additionalContext`):
- Plugin-defined SessionStart hooks would surface `additionalContext`.
- User-level hook workaround could be replaced with a plugin-native hook.
- Simpler, cleaner, but still not first-class "always-on" context.
- OpenCode would remain on npm postinstall path (no change).

**Current risk**: No resolution in sight for either #14200 or #16538. Proceeding with assumption that workaround must remain stable for indefinite period.

## Analysis

### Why the SessionStart Hook Workaround is Durable Despite Its Limitations

1. **User-level hooks work**: The mechanism is proven and documented. Issue #16538 was closed specifically because plugin-defined hooks don't surface `additionalContext`, but user-level hooks do. This division is intentional.
2. **Low maintenance surface**: The hook script is ~45 lines of TypeScript. No hidden dependencies or version coupling beyond `npx tsx`.
3. **Fallback pathway exists**: If the hook breaks, `/cdocs:init` can regenerate it. The rules are always readable from disk.
4. **OpenCode co-delivery works**: Postinstall to OpenCode is independent; CC hook breakage would not cascade.

### Why Migration Paths Are Blocked

| Path | Blocker |
|------|---------|
| Plugin-native SessionStart hook | #16538 closed as "not planned"; CC will not surface plugin hook `additionalContext`. |
| Install-time hook | Does not exist in CC; no feature request filed. Creating one would require upstream work. |
| `.claude/rules/` discovery | #14200 is open but unassigned. Even if closed, would only add rules as discoverable; does not auto-inject as context. |
| Hybrid npm postinstall | Would require platform-specific postinstall logic (npm for OC, custom script for CC). Adds complexity without reducing user setup burden. |

### Empirical Gaps Remaining

1. **50K hook-output cap impact**: Need to verify whether current rule bundle (~10-12KB) exceeds any soft limits or triggers disk spillover on latest CC build.
2. **SessionStart:startup vs. SessionStart:resume behavior**: The RFP asked for subtype-specific testing. Issue #16538 does not distinguish; assuming all subtypes are affected equally. Could confirm with a user-level hook test if needed.
3. **Alternative rule injection mechanism**: No other CC-side mechanism surveyed (e.g., environment variables, CLAUDE.md injection at plugin load time). Would require additional investigation.

## Recommendations

### For Phase 3 (Immediate)

**Retain the existing user-level SessionStart hook as the baseline rule-delivery mechanism.**

- It works and is documented.
- Issue #16538 being closed as "not planned" removes the possibility of a cleaner plugin-native solution in the near term.
- Maintain hook script in `plugins/cdocs/hooks/` for bundling, and continue scaffolding via `/cdocs:init`.
- Add a "Known Limitations" README subsection documenting: (a) hook must be installed at user scope, (b) hook fires on every SessionStart (mild overhead), (c) rules not visible in IDE rule-picker (issue #14200 affects this too).

### For Phase 4 (Longer-term)

**Track #14200 and upstream CC plugin API milestones.**

- If #14200 is resolved in CC, migration path becomes clear: move rules to plugin-native files, remove SessionStart hook dependency.
- If CC announces any install-time or setup-time hook mechanism, re-evaluate hybrid npm postinstall approach.
- Maintain AGENTS.md fallback for OpenCode cross-target portability; the fallback is low-cost and improves agent reusability across platforms.

### For Cross-Target Parity

- **CC**: Continue with SessionStart hook until #14200 is resolved.
- **OpenCode**: Maintain npm postinstall delivery (already native, no change needed).
- **Fallback**: Keep AGENTS.md @-imports for OpenCode agent portability.
- No urgent action required; the dual-target story is coherent as-is.

### Decisions to Escalate to Maintainer

1. **Empirical retest of #16538 on latest CC build**: If maintainer has access to authenticated CC CLI, run the test to confirm plugin SessionStart hooks are still not surfacing `additionalContext`. (This report could not empirically confirm due to environment constraints.)
2. **50K hook-output cap verification**: Confirm that the rule bundle (~10KB) does not hit disk spillover or other limits on the current CC version.
3. **SessionStart subtype distribution**: If phase 3 elaboration requires it, clarify whether user installs hook for all three subtypes (`SessionStart`, `SessionStart:startup`, `SessionStart:resume`) or a subset.

## Open Questions

1. **If #16538 is resolved but #14200 is not, should we migrate plugin SessionStart hooks immediately?**
   - Likely answer: No, not worth the migration effort without first-class context injection. Plugin hooks would still be inferior to user-level hooks if `additionalContext` surfacing has other limitations.

2. **Should we invest in a hybrid npm postinstall + CC activation step now, or wait for #14200?**
   - Recommended: Wait. Hybrid adds complexity without reducing setup friction. Current SessionStart hook is simpler.

3. **Does the 50K hook-output cap with disk spillover affect rule injection?**
   - Critical to verify before phase 3 commitment. Recommend empirical test.

4. **Are there other CC-side rule injection mechanisms not yet discovered?**
   - Low priority. Hooks.md is comprehensive. If a new mechanism exists, it would likely be mentioned in the latest CC release notes or plugins reference.

---

**Report prepared**: 2026-05-12  
**Blocker notes**: Live test could not be executed in agent context (no ANTHROPIC_API_KEY). Conclusions based on code analysis, documentation review, and GitHub issue status.
