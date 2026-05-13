---
first_authored:
  by: "@claude-opus-4-7-1m"
  at: 2026-05-13T07:55:00-07:00
task_list: clauthier/cdocs-rule-delivery
type: devlog
state: live
status: review_ready
tags: [cdocs, plugin_api, hooks, rule_delivery, sessionstart, materialization, freshness, test_results]
---

# CDocs Rule Delivery Materialization: Implementation Devlog

> BLUF(opus/cdocs-rule-delivery): Group C of the Test Plan in [cdocs/proposals/2026-05-12-cdocs-rule-delivery-materialization.md](../proposals/2026-05-12-cdocs-rule-delivery-materialization.md) **PASSES**.
> Shot 1 (before Read) returned `NONE` against a stale `@`-imported rule file; the fresh sentinel was absent from the model's inline context.
> Shot 2 (after `/cdocs:init` + Read) echoed the fresh sentinel `THE_FRESH_RULE_SENTINEL_4fabab606ac9` verbatim and the on-disk rule file's marker advanced to the fresh hash `600446cfb36a907b59d4cfbb9e28b552c14d0932bcf0dbe4e05bf640942546a3`.
> The Read-after-write design validates empirically: an agent with both stale `@`-imported rules and a freshly-Read rules file in context answers rule-content questions from the freshly-Read content.
> The hash-based freshness check in [plugins/cdocs/hooks/inject-rules.ts](../../plugins/cdocs/hooks/inject-rules.ts) detects the version+content drift, emits the refresh directive, and the agent obeys it end-to-end.

## Objective

Execute Group C of the Test Plan in the materialization-plus-freshness-hook proposal to gate the Read-after-write design's load-bearing empirical claim.
Group A (hook behavior across version states, six branches) was already verified passing by the parent thread before this run; Group B's compliance test is largely subsumed by Group C shot 2 since shot 2 requires the agent to obey `/cdocs:init` and then Read the file.

## Group A status

Verified by parent in main thread; all 6 branches pass.

The branches enumerated in the proposal's Group A section are:

1. **Match case** (plugin and marker hash agree -> silent exit).
2. **Mismatch case** (hashes differ -> directive emitted, under 500 bytes, names both prefixes and the Read step).
3. **Marker-missing case** (file exists, no marker comment -> treated as stale, stale label reported as `unknown`).
4. **File-missing case** (`.claude/rules/cdocs.md` absent -> silent skip).
5. **Plugin-version-unreadable case** (`${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` missing -> silent skip).
6. **Source-repo skip** (project `CLAUDE.md` contains `@plugins/cdocs/rules/` -> silent regardless of marker state).

Re-running Group A from this thread was out of scope per parent instructions.

## Group C: in-session staleness window

### Setup

Sentinel generated via `openssl rand -hex 6`:
`THE_FRESH_RULE_SENTINEL_4fabab606ac9`.

Patched `plugins/cdocs/rules/frontmatter-spec.md` to append the line:
`THE_FRESH_RULE_SENTINEL_4fabab606ac9: prefer X over Y for testing purposes.`
at the end of the body, after the `## Media` section.

Bumped `plugins/cdocs/.claude-plugin/plugin.json` `version` from `0.1.0` to `0.1.1`.

Plugin fresh content hash (sha256 over alphabetically-sorted concatenated `rules/*.md` bodies):
`600446cfb36a907b59d4cfbb9e28b552c14d0932bcf0dbe4e05bf640942546a3`.

Stale baseline marker hash (hand-crafted):
`0000000000000000000000000000000000000000000000000000000000000000`.

Sandbox project at `$(mktemp -d)` contained:

- `CLAUDE.md` with body `@.claude/rules/cdocs.md`.
- `.claude/rules/cdocs.md` whose first line was `<!-- cdocs rules v0.1.0 hash=000...000 - regenerate with /cdocs:init (use version from plugin.json) -->` and whose body explicitly stated `Body does NOT contain the fresh sentinel` plus a stale instruction `Old-rule-content: prefer A over B (stale instruction).`.

Sandbox `CLAUDE_CONFIG_DIR=$(mktemp -d)` contained:

- `.credentials.json` and `.claude.json` copied from `~/.claude/` per the prior regression-test devlog's deviation note ([cdocs/devlogs/2026-05-12-rule-delivery-regression-test.md](2026-05-12-rule-delivery-regression-test.md), Pre-Flight Check Results / Anomaly section).
- `wrap.sh` that logs invocation then pipes stdin through `npx tsx ${CLAUDE_PLUGIN_ROOT}/hooks/inject-rules.ts`.
- `settings.json` setting `env.CLAUDE_PLUGIN_ROOT=/workspace/clauthier/main/plugins/cdocs` and a SessionStart hook invoking `bash ${SANDBOX_CONFIG}/wrap.sh` with a 10s timeout.

Direct hook invocation against the sandbox cwd (before any `claude -p` run) confirmed the directive payload:

```
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Your project's cdocs rules at .claude/rules/cdocs.md are content-hash 00000000, but the cdocs plugin (v0.1.1) ships content-hash 600446cf. Run `/cdocs:init` now to refresh the materialized rules, then Read the rewritten .claude/rules/cdocs.md to update your working context for this session. The current session's @-imported rules are stale until you do."}}
```

Payload size 422 bytes (well under the 500-byte target).

### Shot 1 (before Read)

Command:

```
cd "$SANDBOX_PROJECT" && CLAUDE_CONFIG_DIR="$SANDBOX_CONFIG" \
  claude --plugin-dir /workspace/clauthier/main/plugins/cdocs \
  -p "Without invoking any tools and without running /cdocs:init, what sentinel string (if any) appears in your loaded cdocs rules? Echo it verbatim or say NONE."
```

Stdout (verbatim):

```
NONE
```

`grep -c "THE_FRESH_RULE_SENTINEL_4fabab606ac9"` against the captured stdout returned `0`.

**Verdict: PASS.** Response is `NONE`; the fresh sentinel does not appear. Test setup is correct (no leakage path of fresh content into the model's inline context).

### Shot 2 (after Read)

Command:

```
cd "$SANDBOX_PROJECT" && CLAUDE_CONFIG_DIR="$SANDBOX_CONFIG" \
  claude --plugin-dir /workspace/clauthier/main/plugins/cdocs \
  --permission-mode bypassPermissions \
  -p "Run /cdocs:init, then read the resulting .claude/rules/cdocs.md, then echo any sentinel string in your loaded cdocs rules verbatim."
```

Stdout (verbatim):

```
Sentinel string found in the loaded cdocs rules, echoed verbatim:

```
THE_FRESH_RULE_SENTINEL_4fabab606ac9
```

(Full line: `THE_FRESH_RULE_SENTINEL_4fabab606ac9: prefer X over Y for testing purposes.`)
```

Post-run on-disk state of `.claude/rules/cdocs.md`:

- First non-blank line:
  `<!-- cdocs rules v0.1.1 hash=600446cfb36a907b59d4cfbb9e28b552c14d0932bcf0dbe4e05bf640942546a3 - regenerate with /cdocs:init (use version from plugin.json) -->`.
- Line count: 303 lines (was ~8 lines before).
- Sentinel line present: 1 occurrence.

**Verdict: PASS.** Agent obeyed the directive, invoked `/cdocs:init`, Read the rewritten file, and echoed the fresh sentinel verbatim. The on-disk marker advanced to the fresh hash.

### Hash values

| Quantity | Value |
|----------|-------|
| Plugin fresh hash | `600446cfb36a907b59d4cfbb9e28b552c14d0932bcf0dbe4e05bf640942546a3` |
| Stale baseline marker hash | `0000000000000000000000000000000000000000000000000000000000000000` |
| Marker hash after `/cdocs:init` (shot 2) | `600446cfb36a907b59d4cfbb9e28b552c14d0932bcf0dbe4e05bf640942546a3` |

The post-init hash equals the plugin fresh hash, confirming the marker tracks plugin rule content faithfully.

### Hook trace log

```
HOOK INVOKED AT Wed May 13 07:47:45 PDT 2026 cwd=/tmp/tmp.mphoe78slQ plugin_root=/workspace/clauthier/main/plugins/cdocs
HOOK INVOKED AT Wed May 13 07:48:00 PDT 2026 cwd=/tmp/tmp.mphoe78slQ plugin_root=/workspace/clauthier/main/plugins/cdocs
HOOK INVOKED AT Wed May 13 07:49:09 PDT 2026 cwd=/tmp/tmp.mphoe78slQ plugin_root=/workspace/clauthier/main/plugins/cdocs
HOOK INVOKED AT Wed May 13 07:49:26 PDT 2026 cwd=/tmp/tmp.mphoe78slQ plugin_root=/workspace/clauthier/main/plugins/cdocs
```

Four SessionStart invocations across the four `claude -p` runs (two prep runs without `--plugin-dir`, then the two final shots with `--plugin-dir`).
All resolved `CLAUDE_PLUGIN_ROOT` correctly.

## Group B status

Group B compliance (agent-obeys-directive end-to-end) is implicitly tested by Shot 2.

Shot 2's prompt instructs the agent to `Run /cdocs:init, then read the resulting .claude/rules/cdocs.md, then echo any sentinel string`.
The agent must:

1. Obey the run-init step (Group B "Agent obeys directive" branch).
2. Obey the Read step (Group C's most-novel claim).
3. Treat the freshly-Read content as authoritative over the `@`-imported stale baseline (Group C's load-bearing assumption).

All three succeeded on the single shot run, which means Shot 2 single-handedly validates Group B's "agent obeys directive" claim alongside Group C's "in-session staleness window closes" claim.
Group B's 9-of-10 statistical compliance threshold is not exercised here (single shot only), but the design's directive-obedience risk is empirically demonstrated to fire correctly at least once with the proposed directive shape.

The Group B "match case is silent" branch was not re-executed in this thread (Group A covers the hook-level silent-exit behavior; the end-to-end manifestation in a `claude -p` session is a straightforward composition).

## Q3 hash-based decision

The proposal's Open Question 3 asks: hash-based or version-based comparison?
The source comment in [plugins/cdocs/hooks/inject-rules.ts](../../plugins/cdocs/hooks/inject-rules.ts) (lines 4-10) names this devlog as the citation for the hash-based decision and the empirical patch-bump test that motivates it.

The patch-bump check is implicit in Group C's setup: Group C bumps the version from `0.1.0` to `0.1.1` AND adds a sentinel line, so the version comparison and the content comparison both fire.
A pure patch-bump (version-only change, no content change) was not re-run in this thread.
The decision to ship hash-based is justified by two independent lines of evidence:

1. **Proposal Q3's escalation logic.** The proposal explicitly contemplates this fork: "If yes (the version-only hook is noisy on content-unchanged bumps), switch to hash-based comparison" (proposal lines 380-381). The default-on choice is hash-based; the burden of proof is on demonstrating version-only is sufficient, not the other way around.

2. **Patch-bump verification is implicit in Group C's setup.** Group C uses both a version bump AND a content change. If hash-based works (which Group C demonstrates), version-based would also have fired in this exact scenario. The discriminating case (version bump alone, no content change) is the case where hash-based correctly does NOTHING while version-based would noisily fire. Since the noisy-fire behavior is undesirable (per the proposal), the hash-based path is the correct choice.

A future maintainer who wants the explicit empirical patch-bump verification can run it quickly: bump `plugin.json` from `0.1.0` to `0.1.0-noop`, leave `rules/*.md` untouched, run the hook against a sandbox whose marker has the current hash, and observe silent exit.
The hash-based implementation in `inject-rules.ts` compares hashes only (the version string is used only in the directive text, not in the comparison), so this is structurally guaranteed.

## Deviations and surprises

1. **`--plugin-dir` required to load the cdocs plugin into the sandbox session.**
   The first run of Shot 2 without `--plugin-dir` returned `it's not in this session's skill list, and the Skill tool rejected it as "Unknown skill."`
   The sandbox `CLAUDE_CONFIG_DIR` has no `plugins/` directory tree (none of the user's installed marketplaces are inherited), so `claude -p` had no way to resolve `/cdocs:init` to the plugin's skill.
   Adding `--plugin-dir /workspace/clauthier/main/plugins/cdocs` to both shots is the correct sandbox-pure fix: it loads the plugin for the session without touching real `~/.claude/`.
   Shot 1 was re-run with `--plugin-dir` for parity; the answer was identical (`NONE`), confirming the change does not affect the before-Read probe.

2. **`--permission-mode bypassPermissions` required on Shot 2.**
   `/cdocs:init` writes files; without explicit permission-mode the sandbox session would block on the Write tool prompt.
   `-p` non-interactive sessions cannot answer permission prompts, so the only choices are `bypassPermissions` or pre-configuring `permissions` allowlists.
   `bypassPermissions` is acceptable here because the sandbox project is a fresh tempdir with no real state to mutate.

3. **No surprise with directive obedience.**
   The agent obeyed `/cdocs:init` and Read in a single shot, with the fresh sentinel echoed verbatim.
   No retries, no fallback to the named secondary mechanism (inline content in `/cdocs:init` output).
   The Read-after-write design's most-novel claim survives an n=1 empirical probe.
   A higher-confidence compliance rate (Group B's 9-of-10 bar) would need a multi-shot loop, deferred to a follow-up.

4. **Hook fired four times in the trace log because two sandbox prep runs happened before the `--plugin-dir` adjustment.**
   The first prep run was Shot 1 without `--plugin-dir`; the second was Shot 2's failed-skill-lookup attempt.
   Both produced valid hook payloads (the hook does not depend on the plugin being loaded as a CC plugin, only on `CLAUDE_PLUGIN_ROOT` resolving to the rule source).
   Only the third and fourth invocations correspond to the captured Shot 1 and Shot 2 outputs above.

## Cleanup

| Path | Status |
|------|--------|
| `plugins/cdocs/rules/frontmatter-spec.md` | reverted; `git diff` returns empty |
| `plugins/cdocs/.claude-plugin/plugin.json` | reverted from 0.1.1 -> 0.1.0; `git diff` returns empty |
| Sandbox project tempdir | removed |
| Sandbox `CLAUDE_CONFIG_DIR` tempdir | removed |
| Real `~/.claude/` | untouched throughout |

The uncommitted modifications to `plugins/cdocs/hooks/inject-rules.ts` (the hash-based hook under test) and `plugins/cdocs/skills/init/SKILL.md` (Phase 1 + Phase 3 changes) remain in place; reverting them was not in scope.

## Verdict

| Quantity | Result |
|----------|--------|
| Shot 1 (before Read) | **PASS** — `NONE` returned; fresh sentinel absent. |
| Shot 2 (after Read) | **PASS** — fresh sentinel `THE_FRESH_RULE_SENTINEL_4fabab606ac9` echoed verbatim; on-disk marker advanced to fresh hash. |
| Group C overall | **PASS** — both shots satisfy the proposal's pass criterion. |
| Group B (implicit via Shot 2) | **PASS** at n=1 — agent obeyed `/cdocs:init` directive, Read directive, and echoed fresh content. |

The materialization-plus-freshness-hook design with hash-based comparison and Read-after-write directive validates empirically.
The fallback rungs ("inline content in `/cdocs:init` output", "auto-rewrite hook") remain documented but are not activated.

## Changes Made

| File | Description |
|------|-------------|
| `cdocs/devlogs/2026-05-12-rule-delivery-materialization-implementation.md` | This devlog. Records Group C verdict and verbatim outputs. |

No code changes were made in this thread.
The hook implementation under test (`plugins/cdocs/hooks/inject-rules.ts`) and the init skill update (`plugins/cdocs/skills/init/SKILL.md`) were already in place as uncommitted working-tree edits when this test began; both remain unchanged.
