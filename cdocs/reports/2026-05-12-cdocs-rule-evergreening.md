---
first_authored:
  by: "Claude Haiku 4.5"
  at: 2026-05-12T21:30:00-07:00
task_list: clauthier/cdocs-rule-delivery
type: report
state: live
status: final
tags: [cdocs, plugin_api, hooks, rule_delivery, freshness, maintenance]
---

# CDocs Rule Evergreening: Mechanism Evaluation and Recommendations

> BLUF(haiku/cdocs-rule-evergreening): The regression test confirmed CC `2.1.132` caps SessionStart `additionalContext` inline at ~2KB with 13.1KB spillover to disk.
> The version-marker hook + `/cdocs:init` directive is viable (payload < 100 bytes) and empirically testable but requires model instruction-following.
> @-import direct substitution does not exist in documented CC behavior.
> Recommended path: implement the version-marker hook as lowest-cost intervention; investigate spillover-fetch directive as faster mitigation; defer materialization-based alternatives pending proof that hook-injected directives work reliably.

## Context / Background

The cdocs rule-delivery mechanism faces a freshness problem that surfaced during regression testing.

**The failure:**
CC `2.1.132` truncates SessionStart `additionalContext` to ~2KB inline, spilling the remaining 11.1KB to disk without instructing the model to read it ([devlog](2026-05-12-rule-delivery-regression-test.md), Run 3).
Downstream projects receive only a 2KB fragment (the start of `frontmatter-spec`) instead of the three complete rules.
The workaround described in the proposal (SessionStart hook as primary delivery) is non-functional for most users.

**The freshness question:**
Even if the spillover issue is resolved (via model instruction, configurable cap, or future CC fix), existing projects with materialized rules via `/cdocs:init` will go stale when the plugin updates.
Choosing `/cdocs:init` materialization as the primary delivery mechanism trades the hook's breakage for a staleness problem: how to keep `.claude/rules/cdocs.md`, `.opencode/rules/cdocs/`, and `AGENTS.md` current across plugin updates?

The maintainer's proposed mitigation is a SessionStart hook that compares plugin version against a project-local marker and emits a directive to re-run `/cdocs:init` if versions diverge.
This report evaluates that candidate, surveys alternatives, and provides a specific recommendation.

## Key Findings

### Finding 1: The Version-Marker Hook + /cdocs:init Directive is Mechanically Feasible

**Mechanism sketch:**

1. Plugin version stored in `.claude-plugin/plugin.json` (currently `0.1.0`).
2. Marker file location: `cdocs/.plugin_version` or `cdocs/.last_init` (user choice; recommend `.plugin_version`).
3. SessionStart hook reads both, compares, emits payload:
   ```json
   {
     "hookSpecificOutput": {
       "hookEventName": "SessionStart",
       "additionalContext": "CDocs plugin version has changed (was X.Y.Z, now W.X.Y). Run `/cdocs:init` to refresh rules. This message occurs once per session."
     }
   }
   ```
4. Hook payload is ~150 bytes, well under 2KB inline cap.
5. Marker file is created/updated by `/cdocs:init` with a version comment: `<!-- cdocs rules vX.Y.Z - regenerate with /cdocs:init -->`.

**Cap math:**
- Plugin version string: 10-20 bytes.
- Marker comparison logic: 100-120 bytes in hook output.
- Total payload: 150-160 bytes.
- 2KB inline cap: 2,048 bytes.
- Safety margin: 12x.

**Failure modes:**
- Marker absent (first-time install): hook detects this and emits directive (correct behavior).
- Marker malformed: hook defaults to "unknown version" and emits directive (safe).
- Plugin version unreadable: hook emits warning and continues (non-blocking).
- Agent ignores directive: user must manually run `/cdocs:init` (degraded, not broken).

### Finding 2: Model Instruction-Following is the Load-Bearing Assumption

The version-marker hook relies on the model obeying a hook-injected directive to run `/cdocs:init`.

**Empirical status:**
- The regression test devlog (Run 3, Run 4) shows CC `2.1.132` does present hook content to the model inline (within 2KB framing).
- The devlog does not test whether the model actually obeys a hook-injected "please run /cdocs:init" directive in a fresh session.
- QA confirmation verified spillover-file content is readable via explicit Read tool invocation, proving the data path is intact.

**Risk:**
- Hook directive is not a system-prompt-level constraint; it is context text that Claude reads and may choose to ignore, especially if the directive competes with the user's request.
- In interactive mode (not `claude -p`), the directive appears after the user's message; Claude may prioritize the user's request.
- Oneshot mode (`claude -p`) may be more reliable because the hook directive is the primary context; needs empirical test.

**Recommendation:**
Implement version-marker hook; empirically test in both oneshot (`claude -p`) and interactive modes via sandbox.
If compliance is reliable (>90%), proceed. If not, fallback to auto-rewrite hook (Finding 4).

### Finding 3: @-Import Variable Substitution Does Not Exist in CC

**Investigation:**
Fetched [CC memory.md documentation](https://code.claude.com/docs/en/memory.md) which fully documents @-import syntax.

**Findings:**
- @-imports support relative paths (resolved relative to the importing file) and absolute paths (filesystem roots).
- No documentation of environment variable expansion (e.g., `@${CLAUDE_PLUGIN_ROOT}/rules/...`).
- No documented token substitution or path templating.
- Binary string search for "env var", "plugin root", "@import" yielded CSS-related matches and literal CLAUDE.md file references, but no expansion mechanism.

**Implication:**
`@${CLAUDE_PLUGIN_ROOT}/rules/writing-conventions.md` in CLAUDE.md will be treated as a literal path and fail to resolve.
Direct @-imports against plugin-managed paths are not feasible without absolute filesystem paths (which are fragile across machines/devcontainers).

### Finding 4: Auto-Rewrite Hook is the Fastest Remediation for Current Breakage

The 2KB truncation is a CC `2.1.132` issue that breaks rule injection today.

**Option A (auto-rewrite hook):**
SessionStart hook itself re-materializes `.claude/rules/cdocs.md` from plugin source on every session start when marker indicates staleness.
- Pro: zero user action; rules are always fresh.
- Con: silent mutation of project files; potential conflict with manual edits; requires hook to write files (permission/trust concern).
- Payload: ~200 bytes for version check + file write logic.
- UX: transparent; users never see the directive.

**Option B (directive + user action):**
Hook emits `<system-reminder>` text asking user to run `/cdocs:init`.
- Pro: explicit, auditable, user controls when refresh happens.
- Con: requires user to act; depends on model compliance.
- Payload: ~150 bytes.
- UX: directive appears in context; needs empirical validation.

**Option C (spillover-fetch directive):**
Add a one-line instruction to the top of the injected rule content: "Read the full rule bundle at the spillover file path shown above."
This is a no-hooks change; just modify `inject-rules.ts` to prepend a synthetic instruction within the first 2KB.
- Pro: no marker, no version logic, no new mechanism; fixes breakage immediately for existing installs.
- Con: requires model to follow instruction; model may not have access to the path without explicit framing.
- Payload: no new hook; ~50 bytes prepended to rule output.
- UX: automatic; no user interaction needed.
- Blocker: path framing depends on CC's spillover message format (documented in regression test as "Output too large ... Full output saved to: /path/to/file").

**Verdict:**
Options A and C both address the immediate 2KB truncation issue.
Option C (spillover-fetch directive) is the fastest path to recovery; Option A (auto-rewrite) is the most durable.
Option B (version-marker + user directive) is orthogonal; it addresses staleness, not the immediate breakage.

The report's primary candidate (version-marker hook) is for staleness mitigation, not for fixing the spillover issue.
They can coexist: the version-marker hook defers to Option C for immediate delivery.

### Finding 5: Alternative Mechanisms Have Clear Trade-offs

Surveyed each alternative with mechanism, pros/cons, and complexity:

**Auto-rewrite hook:**
- Hook compares versions and invokes TypeScript to re-materialize `.claude/rules/cdocs.md` from plugin source.
- Pros: zero user action, rules always current, no directive-following dependency.
- Cons: silent file writes, manual-edit conflicts, permission concern, slightly higher hook overhead.
- Freshness: automatic, every session.
- Complexity: moderate (TypeScript file I/O in hook).
- Devcontainer-safe: yes (rewrites are local to project).
- OpenCode interaction: no impact (OC has native rules discovery).
- Blocker: CC hooks have no mechanism to refuse permission; a hook that writes files without user consent may violate trust expectations.

**Hash-check hook:**
- Hook compares SHA-256 hash of plugin rule content against manifest stored next to materialized rules.
- Pros: detects off-version edits, pre-release moves, catches corrupted files.
- Cons: more complex than version number, requires hash manifest generation in `/cdocs:init`.
- Freshness: exact match; no fuzzy freshness.
- Complexity: high (hash computation, manifest format).
- Devcontainer-safe: yes.
- OpenCode interaction: yes, `.opencode/rules/` would need separate hash manifest.
- Verdict: over-engineered for the problem. Version number is sufficient.

**Symlink from .claude/rules/cdocs.md to plugin path:**
- `/cdocs:init` writes symlink instead of copy: `ln -s $CLAUDE_PLUGIN_ROOT/rules/writing-conventions.md .claude/rules/cdocs.md`.
- Pros: trivially evergreen; no freshness logic needed.
- Cons: fragile across devcontainers (different mount paths), Windows (requires admin/dev mode), CI checkouts (symlinks may not be preserved).
- Freshness: automatic, zero latency.
- Complexity: low (one symlink per rule file).
- Devcontainer-safe: **no** (host path `/var/home/...` vs. container path `/workspace/...`; symlink breaks).
- Windows-safe: **no** (requires admin/dev mode).
- CI-safe: **no** (git can store symlinks, but clone-time preservation is fragile).
- Verdict: viable for developer machines but fails the documented devcontainer pain point (project memory section).

**External CI/cron freshness check:**
- Scheduled job (GitHub Actions, cron, etc.) re-runs `/cdocs:init` in consuming projects.
- Pros: works for any project that opts in; centralized control.
- Cons: heavyweight setup; cross-project coordination; delayed freshness (depends on cron interval).
- Freshness: periodic (1/day, 1/week, on-demand webhook).
- Complexity: high (CI setup, webhook, coordination).
- Devcontainer-safe: yes.
- OpenCode interaction: yes, though OC project maintainers must opt in.
- Verdict: viable for enterprises but overkill for small plugins; requires separate RFP and CI setup.

**Version comment + manual discipline:**
- `/cdocs:init` writes version comment; users grep periodically.
- Pros: zero automation, clear semantics, auditable.
- Cons: manual, low value, easy to forget.
- Freshness: manual, user-dependent.
- Complexity: none.
- Verdict: status quo if no automation is desired; not recommended.

**PostUpdate / install-lifecycle hook (if CC supports it):**
- Would fire when plugin is updated/installed.
- Status: CC does not support this (investigated in supplemental report).
- Verdict: not viable.

**Direct @-imports against plugin path (if substitution existed):**
- CLAUDE.md: `@${CLAUDE_PLUGIN_ROOT}/rules/writing-conventions.md`.
- Status: CC @-imports do not support environment variable expansion (documented behavior).
- Verdict: not viable.

### Finding 6: Devcontainer Bind-Mount Interaction is Critical

User memory notes mention a devcontainer issue: plugins installed under host `/var/home/...` don't activate when the container opens `/workspace/...`.

**Implication for each mechanism:**

| Mechanism | Devcontainer Impact | Mitigation |
|-----------|-------------------|-----------|
| Version-marker hook | Hook runs in container; marker file is local. Portable. | None needed. |
| Auto-rewrite hook | Same as above. | None needed. |
| Symlink to plugin path | **Broken.** Symlink points to host path; container sees different mount. | Requires symlink-to-relative-path or post-init adjustment. |
| External CI check | Runs on GitHub; fetches latest from remote. Portable. | None needed. |
| @-import substitution (if it existed) | Would depend on plugin path; broken if plugin doesn't activate in container. | Would require container-aware path expansion. |

**Verdict:**
Version-marker and auto-rewrite hooks are devcontainer-safe because they read plugin version from within the container and compare against a local marker.
Symlinks are devcontainer-unsafe unless resolved to relative paths or post-init adjusted.

## Analysis

### The Freshness Problem is Real and Persistent

Once the immediate 2KB spillover issue is resolved (via spillover-fetch directive or CC fix), projects that use materialized rules will accumulate staleness.
The proposed version-marker hook is a lightweight mechanism to detect and notify about staleness.
However, it only works if:
1. Hook executes reliably (not blocked by permissions or hooks.json misconfig).
2. Hook payload reaches the model inline (not lost in spillover; regression test confirms this).
3. Model obeys the directive (empirically unvalidated; high risk).

### Conflicting Priorities: Evergreening vs. User Trust

The auto-rewrite hook trades silent file mutations for zero user friction.
The version-marker hook trades complexity for explicit user control.
The spillover-fetch directive trades model instruction-following for zero new mechanism.

The right choice depends on the maintainer's tolerance for:
- Silent file writes (auto-rewrite) vs. user awareness (directive).
- Model instruction-following (both hooks require this) vs. explicit code (spillover-fetch).
- Aggressive freshness (every session) vs. lazy freshness (only on init).

### OpenCode Parity

OpenCode has native rules discovery via `.opencode/rules/cdocs/` (created by `/cdocs:init` + postinstall).
The version-marker hook is CC-only; OpenCode cannot use it.
This is acceptable because OpenCode projects can benefit from materialization freshness checks via their own tooling (e.g., a GitHub Actions workflow).

The cross-target story remains: CC hooks + materialized rules; OpenCode postinstall + materialized rules; both with parallel freshness strategies.

## Recommendations

### Primary Recommendation: Implement Version-Marker Hook + Spillover-Fetch Directive

**Rationale:**
This two-part approach decouples immediate breakage fix (spillover-fetch) from longer-term staleness mitigation (version-marker).

**Phase 1: Spillover-Fetch Directive (Immediate Fix)**
- Modify `inject-rules.ts` to prepend a one-line instruction within the first 2KB: `Read the complete rule bundle from the spillover file path shown in your context preamble.`
- This instruction must be a synthetic rule section (e.g., first in alphabetical order) so it appears in the 2KB inline preview.
- Tests empirically on CC `2.1.132` with the sandbox recipe from the regression test.
- Estimated complexity: **low** (edit `inject-rules.ts`, test with `claude -p`).
- If successful: rules are delivered end-to-end immediately without waiting for model instruction-following validation.

**Phase 2: Version-Marker Hook + /cdocs:init Directive (Staleness Mitigation)**
- If Phase 1 succeeds, add version-marker hook as a safeguard against staleness.
- Hook implementation: read `cdocs/.plugin_version`, compare against `plugin.json` version, emit directive if stale.
- `/cdocs:init` writes `cdocs/.plugin_version` with the current version comment.
- Empirically validate model compliance (hook-injected directives in both oneshot and interactive modes).
- Estimated complexity: **low** (hook + init update).

**Phase 3: Auto-Rewrite Hook (If Directive Compliance Fails)**
- If empirical testing shows model compliance is <90%, implement auto-rewrite hook instead.
- Hook materializes `.claude/rules/cdocs.md` from plugin source on every session start when marker is stale.
- No user interaction needed.
- Trade-off: silent file mutations vs. guaranteed freshness.

### Fallback Recommendation: Auto-Rewrite Hook Only

If spillover-fetch directive cannot be implemented or fails testing, jump directly to auto-rewrite hook (Phase 3 above).
This is the most durable mechanism (guaranteed freshness) with the clearest failure modes (file mutations are observable).

### Anti-Recommendation: Symlink Approach

Do not use symlinks for devcontainer environments. The bind-mount issue (documented in project memory) makes symlinks unreliable. Symlinks are viable only for single-machine developers without devcontainers.

## Open Questions

### Q1: Does Hook-Injected Directive Get Obeyed by Claude?

**Status:** Empirically unvalidated.

**Test plan:**
- Sandbox with `CLAUDE_CONFIG_DIR=$(mktemp -d)`, create a hook that emits: `Run /cdocs:init to refresh rules.`
- Call `claude -p "What is your first action?"` and check if model reports seeing the directive and runs the skill.
- Repeat in interactive mode: `echo "What is your first action?" | claude`.
- Success threshold: >90% compliance in both modes.

**Blocker for:**
Version-marker hook + directive approach (Phase 2).

**If unresolved:**
Proceed to auto-rewrite hook (Phase 3) or spillover-fetch directive only (Phase 1).

### Q2: Can the Spillover-Fetch Directive Be Framed to Reliably Trigger Model Action?

**Status:** Empirically unvalidated.

**Test plan:**
- Modify `inject-rules.ts` to prepend: `INSTRUCTIONS: Read the complete cdocs rule bundle from the spillover file path shown above in your context.`
- Test with `claude -p "Search your context for cdocs rules content and describe what you find."` to see if model proactively reads the spillover file.
- If passive instruction fails, try explicit prompt: `claude -p "Use the Read tool to fetch the file at the path shown for hook-output spillover and report its contents."`

**Blocker for:**
Phase 1 implementation.

**If unresolved:**
Option C (spillover-fetch) is not viable; revert to version-marker hook (Phase 2) or auto-rewrite (Phase 3).

### Q3: Do CC Hooks Have a Permission/Trust Mechanism for File Writes?

**Status:** Assumed not, but unvalidated.

**Finding needed:**
- Review CC permissions documentation for any hook-level write restrictions.
- Check whether a hook that writes `.claude/rules/cdocs.md` requires user approval or is silently permitted.

**Impact:**
- If hooks have no write permissions: auto-rewrite hook requires escalation to general hook permissions.
- If hooks have implicit write permissions: auto-rewrite hook is straightforward.

**Blocker for:**
Phase 3 (auto-rewrite hook) contingency.

### Q4: Is the 2KB Inline Cap Configurable in hooks.json or Via CC Settings?

**Status:** Not documented; unvalidated.

**Test plan:**
- Search `hooks.json` schema for `maxInlineBytes`, `spilloverThreshold`, `contextLimit` fields.
- Check CC settings documentation for `hookOutputInlineLimit` or similar.
- If found, test whether increasing the cap preserves full rule bundle inline.

**Impact:**
- If configurable: users could opt into larger inline payload, eliminating spillover entirely.
- If not: spillover is a hard limit; spillover-fetch directive is necessary.

**Blocker for:**
Decision between spillover-fetch (Phase 1) and waiting for CC fix.

### Q5: Will CC #14200 Resolution Eliminate the Entire Problem?

**Status:** Open upstream; no ETA.

**Finding needed:**
- Monitor [CC #14200](https://github.com/anthropics/claude-code/issues/14200) for activity, PRs, or milestones.
- If resolved, revisit plugin.json `rules` field; migration from hooks is trivial.

**Impact:**
- If #14200 lands: hook workaround can be retired; manifest declaration takes over.
- If #14200 remains open: hooks are the indefinite baseline.

**Blocker for:**
None. This is a watch-and-wait item, not a blocker for Phase 1–3.

## Judgment Calls and Caveats

### Judgment 1: Prioritized Spillover-Fetch Over Version-Marker as Phase 1

**Rationale:**
The regression test revealed an immediate breakage (2KB truncation) that affects all current users.
The version-marker hook addresses future staleness, which is a lower-priority problem because fresh installs of `/cdocs:init` will get current rules anyway.

**Risk:**
If spillover-fetch directive fails testing, Phase 1 becomes blocked and we must jump to Phase 3 (auto-rewrite).
This is a sunk effort if directive compliance is <50%.

**Mitigations:**
Run the spillover-fetch empirical test immediately as a go/no-go gate for the overall approach.

### Judgment 2: Assumed Model Instruction-Following is >90%

**Rationale:**
Hook-injected directives are context text, not system-prompt constraints.
Claude is known to follow directives in context (e.g., "use JSON format", "search your context"), but there is no empirical data on whether a SessionStart hook directive will reliably trigger action in fresh sessions.

**Risk:**
If actual compliance is 50–70%, users will frequently ignore the directive and rules will go stale.

**Mitigations:**
Empirical testing in Phase 2 with clear go/no-go criteria (>90% compliance).
Fallback to auto-rewrite hook (Phase 3) if compliance is insufficient.

### Judgment 3: Did Not Recommend Symlink Approach Despite Its Simplicity

**Rationale:**
Project memory documents a devcontainer bind-mount issue where plugins installed on the host do not activate in the container.
Symlinks would exacerbate this because they would resolve to host-only paths, breaking completely in the container.

**Risk:**
Symlinks work for single-machine development (where devcontainers are not used).
Excluding symlinks may limit flexibility for projects that don't use containers.

**Mitigations:**
Recommend symlinks as an optional, unsupported path for developers who explicitly want them and understand the devcontainer limitation.
Document the limitation clearly.

### Judgment 4: Deferred Full Devcontainer Testing

**Rationale:**
The regression test was run on a single host machine.
Devcontainer bind-mount behavior (host `/var/home/...` vs. container `/workspace/...`) is documented in project memory but not empirically tested in this investigation.

**Risk:**
The version-marker hook may fail in container contexts if the marker file path or plugin version read depends on host-side paths.

**Mitigations:**
Test Phase 1 (spillover-fetch) first in a devcontainer to confirm the hook itself fires correctly in container contexts.
If Phase 1 passes, devcontainer safety is confirmed.

## Final Recommendation

Proceed with the two-part approach:

1. **Phase 1 (Immediate):** Implement spillover-fetch directive in `inject-rules.ts` and empirically test with `claude -p` in a sandboxed CLAUDE_CONFIG_DIR.
   Go/no-go gate: Does the model fetch and report the spillover file content?
   If yes, ship this as a bug fix to unblock rule injection.

2. **Phase 2 (Follow-up):** If Phase 1 succeeds, implement version-marker hook + `/cdocs:init` update.
   Empirically test directive compliance in both oneshot and interactive modes.
   Go/no-go gate: >90% compliance in at least one mode.
   If yes, ship as staleness mitigation.

3. **Phase 3 (Contingency):** If Phase 2 directive compliance fails, implement auto-rewrite hook instead.
   This eliminates the model instruction-following dependency at the cost of silent file mutations.

The key unknowns are:
- Whether the spillover-fetch directive can be framed to trigger model action.
- Whether hook-injected directives achieve >90% compliance in practice.
- Whether the 2KB inline cap is configurable.

All three can be answered with empirical testing in sandboxed environments (no real config mutation, no commits, cleanup via `rm -rf`).

---

**Report date:** 2026-05-12  
**Status:** Final  
**Next step:** Execute Phase 1 spillover-fetch directive test per Q2 above. File results in a new devlog.
