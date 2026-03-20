---
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-19T17:45:00-07:00
task_list: cdocs/hook-testing
type: report
state: live
status: done
tags: [testing, hooks, rules-injection, lace, integration, plugin-cache]
---

# Lace Integration Test Results

> BLUF(opus/hook-testing): All 10 tests pass or produce expected warnings.
> The hook scripts are functionally correct: rules inject properly in consumer projects, skip correctly in the source repo, path restrictions work, and frontmatter validation fires.
> Two known issues surfaced: (1) the plugin cache is stale (has old `.sh` hook, source has new `.ts` hook), and (2) no `cdocs@clauthier` entry in `installed_plugins.json` targets lace's local path, meaning CC may not load the plugin for lace sessions without re-registration.

## Part A: Lace Plugin Registration Fix

Removed stale `cdocs@weft-marketplace` from two locations:

- `~/code/weft/lace/main/.claude/settings.json`: removed `"cdocs@weft-marketplace": true` from `enabledPlugins`
- `~/.claude/plugins/installed_plugins.json`: removed the `cdocs@weft-marketplace` entry with container path `projectPath: "/workspace/lace/main"` and `installPath: "/home/node/.claude/plugins/cache/..."`

The `cdocs@clauthier` entry remains intact in both files.

## Part B: Test Results

### Layer 1: Hook Unit Tests

| Test | Description | Result | Notes |
|------|-------------|--------|-------|
| 1.1 | inject-rules output (cached .sh, from /tmp) | PASS | Valid JSON, all 3 rules, 12799 chars, frontmatter stripped |
| 1.2 | inject-rules source-repo skip (.ts, from clauthier) | PASS | No output, exit 0 |
| 1.3a | edit-path: cdocs subagent to cdocs/ path | PASS | Exit 0, allowed |
| 1.3b | edit-path: cdocs subagent outside cdocs/ | PASS | Exit 2, blocked with stderr message |
| 1.3c | edit-path: main session to any path | PASS | Exit 0, allowed |
| 1.3d | edit-path: non-cdocs subagent to any path | PASS | Exit 0, allowed |
| 1.4a | frontmatter: missing state/status fields | PASS | JSON output with warning listing "state status" |
| 1.4b | frontmatter: non-cdocs path | PASS | Silent exit 0, skipped |
| 1.4c | frontmatter: all fields present | PASS | Silent exit 0, no warning |
| 1.4d | frontmatter: no frontmatter at all | PASS | JSON output warning about missing frontmatter |

### Layer 2: Integration Against Lace

| Test | Description | Result | Notes |
|------|-------------|--------|-------|
| 2.1 | SessionStart hook against lace (cached .sh) | PASS | Valid JSON, all 3 rules, 12799 chars |
| 2.1b | SessionStart hook against lace (source .ts) | PASS | Valid JSON, all 3 rules. Also preserves `---` inside code blocks (fixes the .sh awk bug) |
| 2.2 | Lace CLAUDE.md source-repo check | PASS | No `@plugins/cdocs/rules/` string. Uses `@.claude/rules/` imports |
| 2.3 | Plugin registration for lace path | WARN | No cdocs entry targets `/var/home/mjr/code/weft/lace/main`. The `cdocs@clauthier` entry only targets clauthier itself |

### Layer 3: OC Verification

| Test | Description | Result | Notes |
|------|-------------|--------|-------|
| 3.1 | OC skills at flat paths in lace | PASS | 10 skills at flat paths (devlog, propose, review, report, status, triage, init, implement, nit_fix, rfp). No nested `cdocs/` directory |
| 3.2 | OC rules in lace `.claude/rules/` | PASS | All 3 rule files present and non-empty (writing-conventions 3263B, workflow-patterns 5745B, frontmatter-spec 3722B) |
| 3.3 | Scratch-dir OC postinstall | PASS | Flat skill paths in `.opencode/skills/`, no `cdocs/` nesting. Rules copied to `.opencode/rules/cdocs/` |

### Cache Staleness Assessment

The plugin cache at `~/.claude/plugins/cache/clauthier/cdocs/0.1.0/` is stale.

| Aspect | Source | Cache |
|--------|--------|-------|
| SessionStart hook | `inject-rules.ts` (TypeScript, `npx tsx`) | `inject-rules.sh` (Bash, direct execution) |
| hooks.json command | `npx tsx ${CLAUDE_PLUGIN_ROOT}/hooks/inject-rules.ts` | `${CLAUDE_PLUGIN_ROOT}/hooks/inject-rules.sh` |
| Source mtime | 2026-03-19 17:07 | 2026-03-19 14:41 |
| Frontmatter stripping | Correct (preserves `---` inside code blocks) | Known awk bug (strips `---` inside fenced code blocks) |

Both versions produce functionally equivalent output (valid JSON with all 3 rules).
The `.ts` version fixes the cosmetic `---` stripping bug in template examples within frontmatter-spec.md.
The cache will refresh on next CC marketplace update or session start with plugin refresh.

## Known Issues

### 1. No plugin registration targeting lace (Test 2.3)

The `cdocs@clauthier` entry in `installed_plugins.json` has `projectPath: "/var/home/mjr/code/weft/clauthier/main"`.
There is no entry targeting lace at `/var/home/mjr/code/weft/lace/main`.
CC's plugin loader requires exact path match, so the plugin likely does not load for local lace sessions.

Fix: from lace's directory, run `claude plugin marketplace add /var/home/mjr/code/weft/clauthier/main && claude plugin install cdocs@clauthier --scope project`.

> NOTE(opus/hook-testing): This issue was not fixed as part of this task because the instructions said not to modify lace's codebase beyond the settings.json fix, and installing a plugin would modify lace's `.claude/` directory and `installed_plugins.json` further.

### 2. Stale plugin cache

The cached plugin uses the old `.sh` hook while the source has the new `.ts` hook.
Both produce correct output, but the `.ts` version has better frontmatter stripping.
The cache will auto-refresh on next CC plugin update cycle.

### 3. Lace `.claude/rules/` provenance

Lace's `.claude/rules/*.md` files were placed by a prior `/cdocs:init` or manual copy, not by the OC postinstall.
The OC postinstall writes rules to `.opencode/rules/cdocs/`, not `.claude/rules/`.
Both delivery paths coexist: `.claude/rules/` for CC (via CLAUDE.md `@`-imports), `.opencode/rules/cdocs/` for OC.
