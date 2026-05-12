---
first_authored:
  by: "@Claude Opus 4.7 (1M context)"
  at: 2026-05-12T18:00:00-07:00
task_list: clauthier/cdocs-rule-delivery
type: proposal
state: live
status: review_ready
last_reviewed:
  status: accepted
  by: "@claude-opus-4-7-1m"
  at: 2026-05-12T20:45:00-07:00
  round: 2
tags: [cdocs, plugin_api, hooks, rule_delivery, sessionstart, materialization, freshness]
---

# CDocs Rule Delivery via Materialization with Freshness Hook

> BLUF: Drop the SessionStart hook as the primary rule-delivery channel; CC's 2KB inline cap on `additionalContext` silently truncates the 13KB cdocs bundle.
> Make `/cdocs:init`'s materialization (already implemented) the single delivery mechanism.
> Repurpose the SessionStart hook as a tiny version-mismatch check that nudges the agent to re-run `/cdocs:init` when the project's materialized rules go stale.
> Address the in-session staleness gap by having `/cdocs:init` emit a Read-after-write directive against the freshly-rewritten rules file; the design assumes the agent treats the Read result as authoritative over the @-imported stale content, which the Test Plan's Group C validates empirically.
> **Motivated By:** [cdocs/proposals/2026-05-12-cdocs-rule-delivery-investigation.md](2026-05-12-cdocs-rule-delivery-investigation.md), [cdocs/devlogs/2026-05-12-rule-delivery-regression-test.md](../devlogs/2026-05-12-rule-delivery-regression-test.md), [cdocs/reports/2026-05-12-cdocs-rule-evergreening.md](../reports/2026-05-12-cdocs-rule-evergreening.md).

## Objective

Replace the SessionStart-hook rule-injection path (currently silently broken for any payload over ~2KB) with `/cdocs:init`-driven materialization plus a small freshness-check hook.

Downstream projects get cdocs rules at `/cdocs:init` time; the hook detects plugin-version drift on subsequent session starts and nudges the agent to re-run `/cdocs:init`; the refresh directive includes a Read step so the current session's working rules are updated, not just the on-disk copy that the next session will load.

## Background

Three empirical facts from the prior investigation:

1. **The SessionStart hook channel does not deliver cdocs's payload size.**
   CC `2.1.132` caps inlined SessionStart `additionalContext` at approximately 2KB and spills the remainder to a per-session disk file with no read-it directive in the inline preview.
   The cdocs bundle is 13,353 bytes; only a prefix of `frontmatter-spec` reaches the model.
   Empirical observation by both implementer and an independent QA, each using a fresh marker.
   See [cdocs/devlogs/2026-05-12-rule-delivery-regression-test.md](../devlogs/2026-05-12-rule-delivery-regression-test.md).

2. **`/cdocs:init` already materializes the rules into the project.**
   See `plugins/cdocs/skills/init/SKILL.md`: it writes `.claude/rules/cdocs.md` for CC, `.opencode/rules/cdocs/*.md` for OC, and an inlined cdocs section in `AGENTS.md` for cross-tool fallback.
   The project's CLAUDE.md loads the materialized file via standard `@.claude/rules/cdocs.md` import (no caps, no hooks).
   The init skill is idempotent: re-running it refreshes all three artifacts.

3. **CC's CLAUDE.md `@`-imports do not support env var or token substitution.**
   We cannot `@`-import directly against a plugin install path that would update automatically with the plugin.
   Materialization is the only practical delivery mechanism.
   See [cdocs/reports/2026-05-12-cdocs-rule-evergreening.md](../reports/2026-05-12-cdocs-rule-evergreening.md) for the survey and the binary inspection that confirms this.

The remaining design gap is freshness: when the cdocs plugin updates, the materialized rules in each existing project go stale until someone re-runs `/cdocs:init` manually.

> NOTE(opus/cdocs-rule-delivery): The 2KB inline cap is empirically observed in CC `2.1.132`; no public release note for the figure is linked from either source above.
> If a future maintainer audits this claim and finds a citable source, link it.
> The cap should not affect the freshness hook proposed below, since the proposed payload is ~150 bytes.

## Proposed Solution

Three coordinated changes.

### 1. Repurpose `inject-rules.ts` as a freshness check

Replace the current full-bundle injection with a small version-comparison shim.
Behavior:

- Read the current plugin version from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`.
- Read the project's materialized rule version from a marker in `<project>/.claude/rules/cdocs.md` (written by `/cdocs:init`; see section 2).
- If the materialized rule file does not exist, exit silently: cdocs has not been initialized in this project, and the hook should not nag users who have the plugin installed but have not opted in here.
- If the marker is absent but the file exists, treat as stale (a project initialized by an older `/cdocs:init` that did not write the marker).
- If both versions are readable and match, exit silently.
- If versions differ, emit an `additionalContext` payload of approximately the form:

  ```
  Your project's cdocs rules at .claude/rules/cdocs.md are version <stale>,
  but the cdocs plugin is now version <current>.
  Run `/cdocs:init` now to refresh the materialized rules, then Read the
  rewritten .claude/rules/cdocs.md to update your working context for this
  session. The current session's @-imported rules are stale until you do.
  ```

The payload is well under any plausible cap.
Keep the source-repo skip from the current hook (the grep for `@plugins/cdocs/rules/` in the project's `CLAUDE.md`): inside this repo, rules come from the source paths directly and the freshness check is irrelevant.

### 2. Update `/cdocs:init` to write a version marker and emit a Read-after-write directive

Two additions to `plugins/cdocs/skills/init/SKILL.md`:

**Marker.**
The init skill already adds a version comment to `.opencode/rules/cdocs/*.md` and to the inlined `AGENTS.md` section, but not to `.claude/rules/cdocs.md`.
Extend it to write the same form there:

```markdown
<!-- cdocs rules vX.Y.Z - regenerate with /cdocs:init (use version from plugin.json) -->
```

immediately after any frontmatter and before the body.
The hook's version-check reads this comment.

**Read-after-write directive.**
After rewriting all materialized files, the init skill's response output ends with a directive of the form:

```
RULES_REFRESHED: cdocs/.claude/rules/cdocs.md has been updated to version X.Y.Z.
Read that file now to refresh your in-context rules. The @-imported version
loaded at session start is stale and should be disregarded in favor of the
freshly Read content.
```

The agent's next tool call is a `Read` against the file path; the result populates the context with the current rule content.
The design assumes that for the rest of the session, the agent treats the most-recently-Read rule content as authoritative over the @-imported version baked into the system prompt at session start.

This is an empirical assumption distinct from directive obedience: an agent could obey the Read directive (invoke the tool) yet continue to answer rule-questions from the @-imported content because it appears earlier in context.
Group C of the Test Plan validates this assumption with a sentinel-string probe.
If Group C fails, the proposal falls back to a named alternative (see "Fallback if Group C fails" below).

Without the Read-after-write directive at all, the on-disk rules are current but the session's working context still carries the old @-import, which would persist until the next session.

### Fallback if Group C fails

If the Read-after-write directive does not update in-session behavior (Group C shot 2 fails to surface the fresh sentinel), the proposal switches to a named secondary mechanism: `/cdocs:init` emits the new rule content inline in its response output rather than just naming the file path.

The agent has the new content directly in the message stream (more recent than the system-prompt-baked @-imports), and no Read tool call is required.
The cost is approximately 13KB of additional output per `/cdocs:init` invocation, which is acceptable since invocations are infrequent (only on plugin updates).

A deeper fallback, used only if both Read-after-write and inline-content fail to update in-session behavior, is the auto-rewrite hook variant from [cdocs/reports/2026-05-12-cdocs-rule-evergreening.md](../reports/2026-05-12-cdocs-rule-evergreening.md): the hook itself rewrites `.claude/rules/cdocs.md` on stale detection, with no agent action required.
This fixes on-disk staleness without user intervention but does not close the in-session staleness window; subsequent sessions load fresh rules via the standard @-import.

The fallback ladder is: Read-after-write directive (primary) -> inline content in `/cdocs:init` output (secondary) -> auto-rewrite hook with documented one-session lag (tertiary).
Group C results determine which rung is active in the shipped design.

### 3. Update the README architecture section

Reframe `plugins/cdocs/README.md`'s "Cross-Target Rules Architecture" section.

Today's framing: three layers (hook, relative paths, AGENTS.md) with "graceful degradation."
Honest framing: one delivery mechanism (`/cdocs:init` materializes rules locally; CLAUDE.md `@`-imports them); the hook is a small freshness check, not a content channel.

Add a "Known Limitations" subsection covering:

- The hook's directive depends on the agent honoring an injected `<system-reminder>`-framed instruction. Compliance is high in practice but not guaranteed; if the agent ignores the directive, materialized rules go stale and the user must run `/cdocs:init` manually.
- **Two layers of model-instruction-following risk:** (a) directive obedience for the refresh nudge and the Read-after-write step, and (b) the agent's willingness to treat the most-recently-Read rule content as authoritative over the @-imported content baked into the system prompt at session start. Both are empirical assumptions, not framework guarantees. The Test Plan validates each independently.
- The in-session staleness window: between the SessionStart hook firing and the agent completing the Read-after-write step, the agent's working context still has the old rules. For most workflows this is fine; for back-to-back cdocs operations starting immediately after a plugin update, expect one transitional session with stale-rules behavior.
- `/cdocs:init` is opt-in per project. Projects that never run it get no rules at all (intentional: cdocs is per-project workflow tooling, not a global default).
- The migration trigger for retiring the hook entirely is resolution of [CC issue #14200](https://github.com/anthropics/claude-code/issues/14200) (always-on plugin context with first-class manifest-declared rules). When #14200 lands, the freshness hook can be replaced with a `rules` field in `plugin.json`.

## Important Design Decisions

### Why /cdocs:init as the only content channel

The SessionStart hook channel is broken for cdocs's payload size and is constrained by an upstream cap that Anthropic has indicated they will not raise.
Spillover-fetch (instruct the model to Read the per-session disk file) was ruled out earlier in this thread as more convoluted than the value warranted: it relies on the model obeying a hook-injected directive AND making a stateful tool call against a fragile path AND treating the file content as authoritative rules.
The materialization-plus-freshness-hook design uses the hook for what it can reliably deliver (a tiny directive) and routes content through the canonical CC mechanism (`@`-imports of materialized files).

### Why a version marker in `.claude/rules/cdocs.md` rather than a dedicated marker file

Reusing the existing version-comment convention (already established for OC files and AGENTS.md) keeps the storage scheme uniform across the three materialization targets.
A dedicated marker file like `cdocs/.plugin_version` would be marginally more robust against accidental edits but adds another file that the init skill must manage.
The version comment lives inside an HTML comment in markdown, which is invisible to readers, ignored by `@`-import processing, and easy to grep.

### Why a Read-after-write directive rather than expecting the user to start a new session

`/cdocs:init` is typically invoked mid-workflow when the freshness hook fires.
Forcing a session restart after every refresh disrupts ongoing work.
The Read-after-write directive lets the agent self-update in place; the cost is one Read tool call per refresh.

### Why silent skip when `.claude/rules/cdocs.md` is absent

cdocs is opt-in per project.
A user who has the plugin installed globally but has not run `/cdocs:init` in this project does not want a hook nagging them on every session start.
Silent skip is the polite default.
Users who actively want cdocs in a project will run `/cdocs:init`, which creates the file, which lets the hook start tracking freshness.

### Why keep the source-repo skip from the current hook

Inside the cdocs source repo (this one), rules are loaded by the source `CLAUDE.md`'s `@plugins/cdocs/rules/*.md` imports directly.
The materialized `.claude/rules/cdocs.md` is not used here; there is no marker to compare against.
The existing skip heuristic (grep for `@plugins/cdocs/rules/` in `CLAUDE.md`) is correct and should be preserved.

### Why no backwards-compat for the old hook behavior

The old hook attempted to inject the full bundle as `additionalContext`.
The 2KB inline cap silently truncates that for cdocs's payload size.
Replacing it with the freshness check is strictly better: nothing the old hook delivered correctly is lost; what it delivered incorrectly is replaced by a deterministic Read-after-write of the materialized file.

### User-level hook removal is out of scope

Some users may have installed a user-level SessionStart hook from an earlier cdocs setup that invoked `inject-rules.ts` directly from `~/.claude/settings.json` rather than via the plugin's `hooks.json`.
Cleaning up such user-level installs is the user's responsibility; this proposal addresses only the plugin's own `hooks.json`.
The Phase 4 README update notes this for affected users (see also Open Question 4).

## Edge Cases / Challenging Scenarios

**Plugin version unreadable.**
If `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` is missing or malformed, the hook exits silently (no directive).
The user would notice rule drift via normal cdocs use and can re-run `/cdocs:init` manually.
A debug log entry is acceptable but not required.

**Marker present but malformed.**
The hook compares versions as opaque strings.
Any mismatch (including a missing version number, an unparseable value, a non-semver string, or a comment-shape that doesn't match the canonical pattern) is treated as stale and emits the standard refresh directive.
`/cdocs:init` rewrites the file with the canonical marker shape and the comparison stabilizes on the next session.

**Agent ignores the directive.**
Compliance with injected directives is high in practice but not guaranteed.
If the agent ignores the directive, the materialized rules remain stale and the agent operates with stale rules in context.
Mitigation: the README "Known Limitations" subsection documents this; users who notice rule drift can re-run `/cdocs:init` manually.
A future enhancement could add an auto-rewrite mode where the hook performs the rewrite itself (no directive required), but that introduces silent file mutation and is deferred.

**Agent runs `/cdocs:init` but does not Read the new file.**
The on-disk rules are current but the session's working context is still stale.
This is the same outcome as today's status quo (no automatic refresh) but limited to the current session.
The next session loads fresh rules via the standard `@`-import.

**Plugin version regresses (e.g. user pins an older version).**
Hook detects version mismatch and emits the refresh directive.
`/cdocs:init` rewrites to the older version's content.
This is the intended behavior: the marker reflects what the plugin currently delivers, not a monotone version number.

**Multiple SessionStart events per session.**
CC may fire `SessionStart`, `SessionStart:startup`, and `SessionStart:resume` for different lifecycle moments.
The current `hooks.json` matcher is bare `SessionStart` only, so in practice only one event fires per session.
If subtype matchers are added later, duplicate firings are harmless: emitting the same directive twice in a session is benign duplication, and if the agent has acted on the first directive before the second fires the second fire sees the now-current marker and exits silently.
The fallback property is "duplicate-safe," not strictly "exits silently on subsequent fires," since the second-fire-sees-current-marker chain depends on agent compliance with the first directive.

**Hook fires in a session where the agent cannot execute tool calls (e.g. raw stream API call).**
The directive appears in the context but no Read or `/cdocs:init` invocation happens.
The agent operates with stale rules for that interaction.
Same fallback as the "agent ignores the directive" case: user notices, runs `/cdocs:init` manually.

**`/cdocs:init` invoked with `--minimal`.**
The minimal mode skips rules-file creation entirely, so there is no marker to compare against in subsequent sessions.
The hook's silent-skip-on-missing-file branch covers this.

**OpenCode parity.**
`/cdocs:init` already maintains `.opencode/rules/cdocs/*.md` and `AGENTS.md` in step with `.claude/rules/cdocs.md`.
Re-running `/cdocs:init` from the freshness directive refreshes all three.
No OC-specific changes required.

## Test Plan

Three test groups, all automatable in a sandboxed `CLAUDE_CONFIG_DIR`.

### Group A: hook behavior across version states

Sandbox setup: a scratch project with `.claude/rules/cdocs.md` containing a version marker.
The new `inject-rules.ts` is invoked directly (not through `claude -p` initially) so payload behavior is testable in isolation.

- **Match case.** Plugin version `0.1.0`, marker version `0.1.0`. Hook output is empty `additionalContext` (or absent payload entirely). Exit code 0.
- **Mismatch case.** Plugin version `0.2.0`, marker version `0.1.0`. Hook output contains the refresh directive, names both versions, mentions the Read step. Payload size under 500 bytes.
- **Marker-missing case.** `.claude/rules/cdocs.md` exists but has no version comment. Hook output treats as stale. Same shape as mismatch case but the stale version is reported as "unknown" or similar.
- **File-missing case.** `.claude/rules/cdocs.md` does not exist. Hook output is empty. Silent skip.
- **Plugin-version-unreadable case.** `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` missing. Hook output is empty. Silent skip; debug log entry acceptable.
- **Source-repo skip.** Project's `CLAUDE.md` contains `@plugins/cdocs/rules/`. Hook output is empty regardless of marker state.

### Group B: end-to-end via `claude -p`

Sandbox setup per the recipe in [cdocs/proposals/2026-05-12-cdocs-rule-delivery-investigation.md](2026-05-12-cdocs-rule-delivery-investigation.md)'s Test Plan section (the wrap.sh + settings.json pattern), adapted for the new hook.

- **Mismatch fires directive.** Set up a stale marker, run `claude -p "What is the cdocs rule freshness state?"`. Verify the response references the version mismatch and the `/cdocs:init` action. Pass threshold: single-shot pass is sufficient (the directive's presence in the inline context is deterministic from the hook output).
- **Agent obeys directive.** Run `claude -p "Run /cdocs:init then summarize the cdocs writing conventions."` against a stale marker. Verify the agent invokes the `/cdocs:init` skill, then issues a Read against `.claude/rules/cdocs.md`, then summarizes the conventions. Verify `.claude/rules/cdocs.md`'s marker is updated to the plugin version after the run. Pass threshold: at least 9 of 10 runs succeed, matching the evergreening report's compliance bar. If compliance is below 90%, escalate per Open Question 1.
- **Match case is silent.** Set up a match marker, run `claude -p "Anything notable about your context?"`. Verify the response does not mention rule freshness or `/cdocs:init`. Single-shot pass.

### Group C: in-session staleness window

This is the load-bearing test for the Read-after-write design's most-novel claim: that an agent who has both @-imported (stale) rules and freshly-Read (current) rules in context will answer rule-related questions from the fresh content.

**Setup:**

1. Plant a sentinel phrase in the plugin's source rule content. Patch one of `plugins/cdocs/rules/*.md` (pick the alphabetically-first file, `frontmatter-spec.md`) to include a line like:
   ```
   THE_FRESH_RULE_SENTINEL_<rand>: prefer X over Y for testing purposes.
   ```
   Bump `plugins/cdocs/.claude-plugin/plugin.json` `version` to a new value (e.g., `0.1.1` if currently `0.1.0`).

2. Set up a sandbox project with a deliberately stale `.claude/rules/cdocs.md`: write the file by hand (or run an older `/cdocs:init`) so its content does NOT contain the sentinel phrase, and so its marker comment names the prior plugin version. The project's `CLAUDE.md` should `@.claude/rules/cdocs.md` so the stale content gets @-imported into the system prompt.

3. Run the proposed freshness hook against this sandbox via the wrap.sh + settings.json pattern. The hook should detect the version mismatch and emit the refresh directive.

**Two-shot probe structure:**

- **Shot 1 (before Read):** Run `claude -p "Without invoking any tools and without running /cdocs:init, what sentinel string (if any) appears in your loaded cdocs rules? Echo it verbatim or say NONE."` Pass criterion: response is `NONE` or echoes a non-fresh sentinel; the fresh sentinel must NOT appear. Failure of this shot means the test setup is broken (the agent is somehow already seeing the fresh content via a path other than @-import).
- **Shot 2 (after Read):** Run `claude -p "Run /cdocs:init, then read the resulting .claude/rules/cdocs.md, then echo any sentinel string in your loaded cdocs rules verbatim."` Pass criterion: response echoes the fresh sentinel (`THE_FRESH_RULE_SENTINEL_<rand>: prefer X over Y for testing purposes.`) verbatim. Failure of this shot means the Read step did not update working context.

**Pass criterion (overall):** Shot 1 returns `NONE` or a non-fresh sentinel; Shot 2 echoes the fresh sentinel verbatim.

**Cleanup:** Revert the sentinel patch in `plugins/cdocs/rules/*.md` and the version bump in `plugin.json` (they are local-only changes for the test, not commits).

**Failure response:** If Group C fails (Shot 2 does not echo the fresh sentinel even though the agent ran `/cdocs:init` and Read the file), the design falls back to the named alternative in "Fallback if Group C fails" above. Phase 4's Known Limitations subsection must reflect whichever rung of the fallback ladder ships.

## Verification Methodology

Per phase, the implementer:

1. Makes the change on a feature branch.
2. Runs `claude plugin validate plugins/cdocs/.claude-plugin/plugin.json` and `claude plugin validate .claude-plugin/marketplace.json` after touching `hooks.json` or `inject-rules.ts`. Both commands exist on the current CC build (verified during the prior Phase 1 manifest-polish work).
3. Runs Group A tests as unit-level checks of the hook behavior.
4. Runs Group B tests in a sandboxed `CLAUDE_CONFIG_DIR` end-to-end.
5. Runs Group C as the gating test for the Read-after-write mechanism.
6. Captures verbatim outputs in a devlog at `cdocs/devlogs/YYYY-MM-DD-rule-delivery-materialization.md`.

## Implementation Phases

Phase 1 is independent. **Phase 2 and Phase 3 must ship together** (single PR), because Phase 2's hook payload instructs the agent to Read the file written by Phase 3's directive-emitting init skill, and shipping Phase 2 alone leaves the in-session staleness gap dependent only on the agent honoring the hook's inline Read instruction without `/cdocs:init`'s reinforcement. Phase 4 and Phase 5 are independent of the others except that **Phase 5 (mark prior proposal as evolved) happens only after Group B and Group C tests have passed**, not speculatively.

### Phase 1: Update `/cdocs:init` to write the `.claude/rules/cdocs.md` version marker

Files touched:
- `plugins/cdocs/skills/init/SKILL.md` (Step 3 extended to include the version comment).

Constraints:
- Do not change the OC or AGENTS.md marker formats.
- Preserve the skill's idempotency.

Acceptance: a fresh `/cdocs:init` run produces a `.claude/rules/cdocs.md` whose first non-frontmatter line is the `<!-- cdocs rules vX.Y.Z ... -->` comment with the current plugin version.

### Phase 2: Rewrite `inject-rules.ts` as a freshness check

Files touched:
- `plugins/cdocs/hooks/inject-rules.ts` (full rewrite).
- `plugins/cdocs/hooks/hooks.json` (timeout adjustment if needed; matcher unchanged).

Constraints:
- Keep the source-repo skip heuristic.
- Hook stdout must be valid JSON (CC discards otherwise).
- Total payload under 500 bytes in the mismatch case.

Acceptance: Group A tests pass.

### Phase 3: Update `/cdocs:init` to emit the Read-after-write directive

Files touched:
- `plugins/cdocs/skills/init/SKILL.md` (skill body output extended with the directive).

Constraints:
- Directive appears only when the rule file actually changed during the run (idempotency).
- Directive is concise (one sentence) and names the file path explicitly.

Acceptance: Group C tests pass.

### Phase 4: Update the README architecture section

Files touched:
- `plugins/cdocs/README.md`.

Constraints:
- The new "Known Limitations" subsection lives near the architecture section, not buried in a tail.
- The migration trigger (#14200) is named.
- The cross-link between the architecture description and the Known Limitations subsection is bidirectional.

Acceptance: a contributor reading the README understands the delivery is `/cdocs:init`-driven with a small freshness hook, not the prior three-layer-graceful-degradation framing.

### Phase 5: Mark the prior proposal as evolved

Files touched:
- `cdocs/proposals/2026-05-12-cdocs-rule-delivery-investigation.md` (frontmatter `status: evolved`; brief NOTE callout pointing here).

Constraints:
- Do not rewrite the body of the prior proposal; preserve it as the evolution trail.

Acceptance: the prior proposal's frontmatter and a single NOTE callout reflect supersession; no other content changes.

## Open Questions

1. **Directive compliance rate.**
   The design assumes the agent obeys the refresh directive (invokes `/cdocs:init`) and the Read-after-write directive (invokes `Read` against the rules path).
   Compliance is high in practice but unmeasured here.
   Group B and Group C tests will establish a working data point; if compliance is poor, the fallback is the auto-rewrite hook variant ([cdocs/reports/2026-05-12-cdocs-rule-evergreening.md](../reports/2026-05-12-cdocs-rule-evergreening.md) covers this).

2. **Devcontainer behavior.**
   The freshness hook reads `${CLAUDE_PLUGIN_ROOT}` and the project's `.claude/rules/cdocs.md`.
   Under the lace bare-worktree setup, plugin install records key on the host's absolute path; the in-Dockerfile symlink stopgap papers over this for the host install case.
   The hook test should exercise the in-devcontainer path explicitly to confirm `${CLAUDE_PLUGIN_ROOT}` resolves correctly inside the container.

3. **Hash-based vs version-based comparison: decision required during Phase 2.**
   The current sketch emits the directive on any version mismatch.
   Patch-level bumps that touch only the build pipeline could spam the directive without delivering new rule content.
   An alternative is to compare the rule-content hash rather than the plugin version: only emit when rules actually change.
   This is more robust but adds complexity (the hash must be computed in `/cdocs:init` and stored alongside the version comment, and re-computed by the hook on the plugin source).

   **Go/no-go criterion for Phase 2:** During Phase 2 implementation, the implementer runs a simulated patch-bump test: bump `plugin.json` version without modifying any `rules/*.md` content, and check whether the version-based hook emits a refresh directive against an otherwise-current project.
   If yes (the version-only hook is noisy on content-unchanged bumps), switch to hash-based comparison: extend the marker comment to `<!-- cdocs rules vX.Y.Z hash=<sha256> ... -->`, have the hook compute the current sha256 of the concatenated plugin rule bodies, and compare hashes instead of versions.
   If no (the version-only path tests cleanly), keep version-based and document the decision in the implementation devlog.

4. **Backward compatibility for projects with the old hook installed.**
   Users who installed the old user-level SessionStart hook may have a stale invocation in `~/.claude/settings.json` after the plugin updates.
   The plugin's `hooks.json` is the canonical place; user-level installs are out of scope for this proposal.
   A README note ("if you have a user-level cdocs hook from before May 2026, remove it") would close this gap; whether to include that in Phase 4 is the maintainer's call.
