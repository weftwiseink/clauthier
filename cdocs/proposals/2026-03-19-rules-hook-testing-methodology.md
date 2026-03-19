---
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-19T15:00:00-07:00
task_list: cdocs/hook-testing
type: proposal
state: live
status: wip
tags: [testing, hooks, rules-injection, plugin-architecture, opencode, cc-plugin]
---

# CDocs Rules Hook Testing Methodology

> BLUF(opus/hook-testing): The cdocs SessionStart hook (`inject-rules.sh`) is the primary delivery mechanism for rules in CC consumer projects, but there is no automated way to verify it works after installation.
> This proposal defines a concrete testing methodology covering three verification layers: (1) hook script unit tests run in isolation, (2) integration tests simulating CC's hook invocation protocol against the real lace project at `~/code/weft/lace/main`, and (3) OC skill discoverability checks validating that the postinstall produces correct flat paths.
> The methodology is designed to run from the clauthier source repo without requiring an interactive CC session.

## Objective

Establish a repeatable, scriptable testing methodology that verifies:
1. CC SessionStart hook injects rule content as `additionalContext` when installed in a consumer project.
2. The hook correctly skips injection in the source repo (where rules load via `@`-imports in CLAUDE.md).
3. CC skills are discoverable after plugin installation.
4. OC postinstall places skills at flat paths (`.opencode/skills/<name>/`) rather than nested (`.opencode/skills/cdocs/<name>/`).
5. OC rules are copied to `.claude/rules/` with correct content.

## Background

### Hook Architecture

The cdocs plugin registers three hooks in `plugins/cdocs/hooks/hooks.json`:
- **SessionStart**: `inject-rules.sh` reads `plugins/cdocs/rules/*.md`, strips YAML frontmatter, and returns JSON with `additionalContext` containing all rule content.
- **PreToolUse** (Write|Edit): `validate-cdocs-edit-path.sh` restricts cdocs subagents to `cdocs/` document directories.
- **PostToolUse** (Write|Edit): `cdocs-validate-frontmatter.sh` warns when cdocs documents lack required frontmatter fields.

The SessionStart hook is the critical path: without it, consumer projects receive no rules, and the agent operates without writing conventions, workflow patterns, or frontmatter knowledge.

### Source-Repo Skip Logic

The hook checks `$PWD/CLAUDE.md` for the string `@plugins/cdocs/rules/`.
If found, it exits silently (rules already loaded via `@`-imports).
The clauthier source repo's CLAUDE.md contains these imports; consumer projects like lace do not.

### Consumer State: lace

The lace project at `~/code/weft/lace/main` has:
- `.claude/settings.json` with `cdocs@clauthier` and `cdocs@weft-marketplace` enabled.
- `CLAUDE.md` containing `@`-imports to `.claude/rules/*.md` (writing-conventions, workflow-patterns, frontmatter-spec): these are static copies, not plugin-injected rules.
- `.opencode/skills/` with flat skill paths (devlog, propose, review, etc.): already at the correct flat structure.
- `.opencode/commands/` with OC command wrappers.
- No `@plugins/cdocs/rules/` string in CLAUDE.md, so the hook should fire.

> NOTE(opus/hook-testing): Lace's `.claude/rules/*.md` files are static copies placed by the OC postinstall, not by the CC hook.
> The CC hook delivers rules via `additionalContext` in the session context, which is ephemeral (not written to disk).
> Both delivery mechanisms coexist: static files for OC, hook injection for CC.

### installed_plugins.json State

The `cdocs@weft-marketplace` entry has `projectPath: "/workspace/lace/main"` which is a container path from a prior Codespace install.
The local lace path is `/var/home/mjr/code/weft/lace/main`.
This mismatch means the plugin may not load for the local lace instance.

> WARN(opus/hook-testing): The path mismatch in `installed_plugins.json` for `cdocs@weft-marketplace` is a known issue.
> The `cdocs@clauthier` entry has no `projectPath` for lace at all: it only targets clauthier itself.
> Verifying hook behavior in lace requires either fixing the plugin registration or simulating the hook outside CC.

### OC Skill Path Nesting Bug

The `postinstall.js` script targets `.opencode/skills/cdocs/` (nested) when `.opencode/` exists.
OC discovers skills at `.opencode/skills/<name>/SKILL.md` (flat, one level).
The nested `cdocs/` prefix makes skills invisible to OC.
Lace currently has flat paths, suggesting someone manually corrected this or a newer postinstall was used.

> NOTE(opus/hook-testing): The `2026-03-19-decouple-oc-build-from-cc-plugin.md` proposal covers the postinstall fix.
> This testing methodology validates the fix's correctness rather than proposing the fix itself.

## Proposed Solution

A three-layer test suite run from the clauthier source repo.

### Layer 1: Hook Script Unit Tests (Isolated)

Test each hook script in isolation by invoking it with controlled environment variables and stdin, without requiring CC or a real project.

**Test 1.1: inject-rules.sh produces valid JSON with rule content**

```bash
#!/usr/bin/env bash
# test-inject-rules-produces-json.sh
# Run from clauthier/main

set -euo pipefail

PLUGIN_ROOT="$(pwd)/plugins/cdocs"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

# Use a temp directory as PWD to simulate a consumer project (no CLAUDE.md with @plugins/ imports)
CONSUMER_DIR=$(mktemp -d)
trap 'rm -rf "$CONSUMER_DIR"' EXIT

pushd "$CONSUMER_DIR" > /dev/null
OUTPUT=$("$PLUGIN_ROOT/hooks/inject-rules.sh")
popd > /dev/null

# Validate JSON structure
if ! echo "$OUTPUT" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' > /dev/null 2>&1; then
  echo "FAIL: Output is not valid SessionStart hook JSON"
  echo "Output: $OUTPUT"
  exit 1
fi

# Validate rule content is present
CONTEXT=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.additionalContext')

for rule in writing-conventions workflow-patterns frontmatter-spec; do
  if ! echo "$CONTEXT" | grep -q "\[cdocs rule: ${rule}\]"; then
    echo "FAIL: Missing rule '${rule}' in additionalContext"
    exit 1
  fi
done

# Validate frontmatter was stripped (no leading --- block in rule content)
if echo "$CONTEXT" | grep -q '^first_authored:'; then
  echo "FAIL: Frontmatter was not stripped from rule content"
  exit 1
fi

echo "PASS: inject-rules.sh produces valid JSON with all rules, frontmatter stripped"
```

**Test 1.2: inject-rules.sh skips in source repo**

```bash
#!/usr/bin/env bash
# test-inject-rules-skips-source.sh

set -euo pipefail

PLUGIN_ROOT="$(pwd)/plugins/cdocs"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

# Run from clauthier/main itself (CLAUDE.md has @plugins/cdocs/rules/)
OUTPUT=$("$PLUGIN_ROOT/hooks/inject-rules.sh" || true)

if [ -n "$OUTPUT" ]; then
  echo "FAIL: Hook should produce no output in source repo, got: $OUTPUT"
  exit 1
fi

echo "PASS: inject-rules.sh correctly skips in source repo"
```

**Test 1.3: validate-cdocs-edit-path.sh blocks cdocs subagent writes outside cdocs/**

```bash
#!/usr/bin/env bash
# test-edit-path-restriction.sh

set -euo pipefail

PLUGIN_ROOT="$(pwd)/plugins/cdocs"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

# Subagent writing to cdocs path: should allow (exit 0)
echo '{"agent_type":"triage","tool_input":{"file_path":"cdocs/devlogs/2026-03-19-test.md"}}' \
  | "$PLUGIN_ROOT/hooks/validate-cdocs-edit-path.sh"
echo "PASS: Allowed cdocs subagent write to cdocs/ path"

# Subagent writing outside cdocs: should block (exit 2)
set +e
echo '{"agent_type":"triage","tool_input":{"file_path":"src/main.ts"}}' \
  | "$PLUGIN_ROOT/hooks/validate-cdocs-edit-path.sh" 2>/dev/null
EXIT_CODE=$?
set -e

if [ "$EXIT_CODE" -ne 2 ]; then
  echo "FAIL: Expected exit 2 for blocked write, got $EXIT_CODE"
  exit 1
fi
echo "PASS: Blocked cdocs subagent write outside cdocs/"

# Main session (no agent_type): should allow anything
echo '{"tool_input":{"file_path":"src/main.ts"}}' \
  | "$PLUGIN_ROOT/hooks/validate-cdocs-edit-path.sh"
echo "PASS: Allowed main session write to any path"
```

**Test 1.4: cdocs-validate-frontmatter.sh warns on missing fields**

```bash
#!/usr/bin/env bash
# test-frontmatter-validation.sh

set -euo pipefail

PLUGIN_ROOT="$(pwd)/plugins/cdocs"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

TMPFILE=$(mktemp --suffix=.md)
trap 'rm -f "$TMPFILE"' EXIT

# Create a file with missing frontmatter fields at a cdocs path
CDOCS_PATH="cdocs/devlogs/2026-03-19-test.md"
mkdir -p "$(dirname "$CDOCS_PATH")"
cat > "$CDOCS_PATH" << 'HEREDOC'
---
first_authored:
  by: "@test"
  at: 2026-03-19T00:00:00-07:00
type: devlog
---
# Test
HEREDOC

OUTPUT=$(echo "{\"tool_input\":{\"file_path\":\"$(pwd)/$CDOCS_PATH\"}}" \
  | "$PLUGIN_ROOT/hooks/cdocs-validate-frontmatter.sh")

if ! echo "$OUTPUT" | grep -q "missing required frontmatter"; then
  echo "FAIL: Should warn about missing state and status fields"
  echo "Output: $OUTPUT"
  rm "$CDOCS_PATH"
  exit 1
fi

rm "$CDOCS_PATH"
echo "PASS: Frontmatter validation warns on missing fields"
```

### Layer 2: Integration Tests Against lace

Test hook behavior in the context of a real consumer project.
These tests simulate what CC does when it invokes the hook, without requiring an interactive CC session.

**Test 2.1: Simulate SessionStart hook against lace**

```bash
#!/usr/bin/env bash
# test-hook-against-lace.sh
# Simulates CC invoking the SessionStart hook in lace's directory

set -euo pipefail

# Use the cached plugin (what CC actually runs), not the source
CACHE_DIR="/home/mjr/.claude/plugins/cache/clauthier/cdocs/0.1.0"

if [ ! -d "$CACHE_DIR" ]; then
  echo "SKIP: Plugin not installed (cache dir missing). Run: claude plugin install cdocs@clauthier"
  exit 0
fi

export CLAUDE_PLUGIN_ROOT="$CACHE_DIR"
LACE_DIR="/home/mjr/code/weft/lace/main"

pushd "$LACE_DIR" > /dev/null
OUTPUT=$("$CACHE_DIR/hooks/inject-rules.sh")
popd > /dev/null

# Validate JSON
if ! echo "$OUTPUT" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' > /dev/null 2>&1; then
  echo "FAIL: Hook did not produce valid SessionStart JSON in lace context"
  echo "Output was: $(echo "$OUTPUT" | head -c 200)"
  exit 1
fi

CONTEXT=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.additionalContext')

# Check each rule is present
EXPECTED_RULES=("writing-conventions" "workflow-patterns" "frontmatter-spec")
for rule in "${EXPECTED_RULES[@]}"; do
  if ! echo "$CONTEXT" | grep -q "\[cdocs rule: ${rule}\]"; then
    echo "FAIL: Rule '${rule}' not found in hook output for lace"
    exit 1
  fi
done

# Verify rule content has substance (not empty after frontmatter strip)
CONTEXT_LENGTH=${#CONTEXT}
if [ "$CONTEXT_LENGTH" -lt 500 ]; then
  echo "FAIL: additionalContext suspiciously short (${CONTEXT_LENGTH} chars). Rules may not have loaded."
  exit 1
fi

echo "PASS: SessionStart hook injects all ${#EXPECTED_RULES[@]} rules into lace (${CONTEXT_LENGTH} chars)"
```

**Test 2.2: Verify lace CLAUDE.md does not trigger source-repo skip**

```bash
#!/usr/bin/env bash
# test-lace-not-source-repo.sh

set -euo pipefail

LACE_CLAUDE_MD="/home/mjr/code/weft/lace/main/CLAUDE.md"

if grep -q '@plugins/cdocs/rules/' "$LACE_CLAUDE_MD" 2>/dev/null; then
  echo "FAIL: Lace CLAUDE.md contains '@plugins/cdocs/rules/' -- hook will skip injection"
  echo "This string should only appear in the cdocs source repo."
  exit 1
fi

echo "PASS: Lace CLAUDE.md does not contain source-repo marker string"
```

**Test 2.3: Verify plugin registration covers lace project path**

```bash
#!/usr/bin/env bash
# test-plugin-registration.sh
# Checks installed_plugins.json for a cdocs entry matching lace's local path

set -euo pipefail

PLUGINS_FILE="/home/mjr/.claude/plugins/installed_plugins.json"
LACE_PATH="/var/home/mjr/code/weft/lace/main"

if [ ! -f "$PLUGINS_FILE" ]; then
  echo "FAIL: installed_plugins.json not found"
  exit 1
fi

# Check if any cdocs plugin entry has a projectPath matching lace's local path
MATCHING=$(jq -r '
  [.plugins | to_entries[] | select(.key | startswith("cdocs@")) |
   .value[] | select(.projectPath == "'"$LACE_PATH"'")] | length
' "$PLUGINS_FILE")

if [ "$MATCHING" -eq 0 ]; then
  echo "WARN: No cdocs plugin entry with projectPath='$LACE_PATH'"
  echo "  The cdocs@weft-marketplace entry has projectPath='/workspace/lace/main' (container path)."
  echo "  The hook may not fire in local lace sessions."
  echo "  Fix: cd $LACE_PATH && claude plugin marketplace add /var/home/mjr/code/weft/clauthier/main && claude plugin install cdocs@clauthier --scope project"
  exit 1
fi

echo "PASS: cdocs plugin registered for lace at $LACE_PATH"
```

### Layer 3: OC Skill and Rule Verification

Validate that the OC postinstall produces correct artifacts in lace and in a scratch directory.

**Test 3.1: OC skills at flat paths in lace**

```bash
#!/usr/bin/env bash
# test-oc-skill-paths.sh

set -euo pipefail

LACE_OC_SKILLS="/home/mjr/code/weft/lace/main/.opencode/skills"

if [ ! -d "$LACE_OC_SKILLS" ]; then
  echo "SKIP: .opencode/skills/ not found in lace"
  exit 0
fi

# Check for flat structure: skills/<name>/SKILL.md
EXPECTED_SKILLS=("devlog" "propose" "review" "report" "status" "triage" "init" "implement" "rfp" "nit_fix")
MISSING=()
for skill in "${EXPECTED_SKILLS[@]}"; do
  if [ ! -f "$LACE_OC_SKILLS/$skill/SKILL.md" ]; then
    MISSING+=("$skill")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "FAIL: Missing skills at flat paths: ${MISSING[*]}"
  exit 1
fi

# Check for nested cdocs/ prefix (the bug)
if [ -d "$LACE_OC_SKILLS/cdocs" ]; then
  echo "WARN: Nested .opencode/skills/cdocs/ directory exists. This is the nesting bug."
  echo "  Skills at this path are invisible to OC. Contents:"
  ls "$LACE_OC_SKILLS/cdocs/" 2>/dev/null
fi

echo "PASS: All ${#EXPECTED_SKILLS[@]} OC skills found at flat paths"
```

**Test 3.2: OC rules deployed to lace**

```bash
#!/usr/bin/env bash
# test-oc-rules.sh

set -euo pipefail

LACE_RULES="/home/mjr/code/weft/lace/main/.claude/rules"

EXPECTED_RULES=("writing-conventions.md" "workflow-patterns.md" "frontmatter-spec.md")
MISSING=()
EMPTY=()

for rule in "${EXPECTED_RULES[@]}"; do
  RULE_PATH="$LACE_RULES/$rule"
  if [ ! -f "$RULE_PATH" ]; then
    MISSING+=("$rule")
  elif [ ! -s "$RULE_PATH" ]; then
    EMPTY+=("$rule")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "FAIL: Missing rule files: ${MISSING[*]}"
  exit 1
fi

if [ ${#EMPTY[@]} -gt 0 ]; then
  echo "FAIL: Empty rule files: ${EMPTY[*]}"
  exit 1
fi

echo "PASS: All ${#EXPECTED_RULES[@]} rule files present and non-empty in lace"
```

**Test 3.3: Scratch-directory OC postinstall test (validates nesting fix)**

```bash
#!/usr/bin/env bash
# test-oc-postinstall-scratch.sh
# Tests postinstall behavior in a clean directory

set -euo pipefail

BUILD_DIR="/var/home/mjr/code/weft/clauthier/main/build/cdocs/opencode"

if [ ! -d "$BUILD_DIR" ]; then
  echo "SKIP: OC build output not found. Run: npm run build:cdocs"
  exit 0
fi

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

pushd "$SCRATCH" > /dev/null

# Initialize a minimal project with .opencode/ to trigger OC path
mkdir .opencode
npm init -y --silent > /dev/null 2>&1
npm install "$BUILD_DIR" --silent > /dev/null 2>&1

# Check: skills should be at flat paths
if [ -d ".opencode/skills/cdocs" ]; then
  echo "FAIL: Postinstall created nested .opencode/skills/cdocs/ (the nesting bug)"
  ls -R .opencode/skills/cdocs/
  popd > /dev/null
  exit 1
fi

# Check: at least one skill exists at flat path
if [ ! -f ".opencode/skills/propose/SKILL.md" ]; then
  echo "FAIL: Expected .opencode/skills/propose/SKILL.md not found"
  echo "  Actual .opencode/skills/ contents:"
  find .opencode/skills/ -type f 2>/dev/null | head -20
  popd > /dev/null
  exit 1
fi

# Check: rules copied
if [ ! -f ".claude/rules/writing-conventions.md" ]; then
  echo "FAIL: Expected .claude/rules/writing-conventions.md not found"
  popd > /dev/null
  exit 1
fi

popd > /dev/null
echo "PASS: OC postinstall produces flat skill paths and copies rules"
```

## Important Design Decisions

**Simulate hooks outside CC rather than requiring interactive sessions.**
CC provides no programmatic way to introspect what `additionalContext` a hook injected.
The only way to verify hook behavior is to invoke the script directly with the same environment CC provides (`CLAUDE_PLUGIN_ROOT`, `PWD`).
This is a faithful simulation: the hook scripts are plain bash with no CC-specific runtime dependencies.

**Test against both source-repo source and cached plugin.**
Layer 1 tests the source files directly (fast iteration during development).
Layer 2 tests the cached copy CC actually uses (catches stale-cache issues after source changes).
Both perspectives are necessary: a passing Layer 1 test with a failing Layer 2 test indicates the plugin cache needs refreshing.

**Use lace as the canonical consumer project rather than a scratch directory.**
Lace is the real consumer with real configuration.
Its CLAUDE.md, settings.json, and directory structure exercise the actual paths the hook encounters.
Scratch directories (Layer 3) complement this by testing clean-slate OC installs.

**Test the nesting bug's presence, not its fix.**
Test 3.1 checks for the nested `cdocs/` directory and warns rather than failing, since the fix is proposed in a separate document.
Test 3.3 validates the fix by running the postinstall in a scratch directory where the bug would manifest.

## Edge Cases / Challenging Scenarios

**Stale plugin cache.**
After modifying hook scripts in the source repo, the cached version at `~/.claude/plugins/cache/clauthier/cdocs/0.1.0/` does not update automatically.
Layer 2 tests will pass against stale cache even if the source has bugs.
Mitigation: the test runner should warn when the cache is older than the source.

```bash
# Add to test-hook-against-lace.sh
SOURCE_MTIME=$(stat -c %Y plugins/cdocs/hooks/inject-rules.sh)
CACHE_MTIME=$(stat -c %Y "$CACHE_DIR/hooks/inject-rules.sh")
if [ "$SOURCE_MTIME" -gt "$CACHE_MTIME" ]; then
  echo "WARN: Source hook is newer than cached copy. Run: claude plugin install cdocs@clauthier"
fi
```

**Container vs local path mismatch.**
The `cdocs@weft-marketplace` entry in `installed_plugins.json` has `projectPath: "/workspace/lace/main"`, a Codespace path.
Locally, lace is at `/var/home/mjr/code/weft/lace/main`.
CC's plugin loader requires exact path match, so the weft-marketplace plugin likely does not load for local lace sessions.
Test 2.3 detects this.

**CLAUDE.md with partial @-import strings.**
If a consumer project's CLAUDE.md contained `@plugins/cdocs/rules/` for any reason (copy-paste from source repo docs), the hook would incorrectly skip injection.
The skip logic uses a simple `grep -q` on the exact string.
This is unlikely but worth documenting.

**`jq` unavailability.**
The inject-rules hook depends on `jq` for JSON escaping.
If `jq` is not installed, the hook fails silently (set -e causes immediate exit).
The test scripts also depend on `jq`.
Not a realistic concern for development environments, but worth noting for CI.

**OC postinstall without `.opencode/` directory.**
When `.opencode/` does not exist, the postinstall falls back to `.claude/skills/cdocs/`.
This is also nested and would be invisible to OC if OC checks `.claude/skills/` with the same flat convention.
Test 3.3 creates `.opencode/` to exercise the OC path; a separate test could exercise the CC fallback.

## Test Plan

The tests themselves are the deliverable.
Meta-testing: run the full suite and verify each test produces expected output for known-good and known-bad scenarios.

| Test | Target | Passes When |
|------|--------|-------------|
| 1.1 | inject-rules.sh | Valid JSON, all 3 rules present, frontmatter stripped |
| 1.2 | inject-rules.sh | No output when run from clauthier source repo |
| 1.3 | validate-cdocs-edit-path.sh | Blocks subagent writes outside cdocs/, allows main session |
| 1.4 | cdocs-validate-frontmatter.sh | Warns on missing state/status fields |
| 2.1 | Hook + lace | SessionStart JSON with all rules, >500 chars |
| 2.2 | lace CLAUDE.md | No `@plugins/cdocs/rules/` string |
| 2.3 | installed_plugins.json | cdocs entry with matching lace projectPath |
| 3.1 | lace .opencode/skills/ | All 10 skills at flat paths, warn if cdocs/ nested dir exists |
| 3.2 | lace .claude/rules/ | All 3 rule files present and non-empty |
| 3.3 | Scratch dir postinstall | Flat skill paths, no cdocs/ nesting, rules copied |

## Verification Methodology

Run the test runner from the clauthier source repo:

```bash
cd /var/home/mjr/code/weft/clauthier/main
./scripts/test-hooks.sh
```

All tests should produce `PASS` or `SKIP` (for optional dependencies like build output).
Any `FAIL` or `WARN` indicates a real issue requiring attention.

For the CC-side SessionStart behavior specifically, the definitive verification remains starting a new `claude` session in lace and checking for rule content in the system context.
The unit/integration tests provide high confidence but cannot prove CC's plugin loader actually invokes the hook.

To verify CC loads the plugin in lace at all:
```bash
cd /home/mjr/code/weft/lace/main
claude --print-system-prompt 2>/dev/null | grep -c "cdocs rule:"
# Should return 3 (one per rule)
```

> TODO(opus/hook-testing): Investigate whether `claude --print-system-prompt` exists or if there is another CLI flag to dump the session context.
> If not, consider proposing a `/cdocs:status` enhancement that checks for rule injection markers.

## Implementation Phases

### Phase 1: Create Test Runner Script

Create `scripts/test-hooks.sh` as an executable bash script that orchestrates all tests.

1. Create `scripts/test-hooks.sh` with a simple runner that sources each test function and reports results.
2. Implement Tests 1.1 through 1.4 (hook unit tests) as functions within the runner.
3. Verify all Layer 1 tests pass from the clauthier source repo.

**Success criteria**: `./scripts/test-hooks.sh` runs all unit tests, reports pass/fail per test.

### Phase 2: Add Integration Tests Against lace

1. Implement Tests 2.1 through 2.3 in the test runner.
2. Run and verify against lace's current state.
3. Fix any plugin registration issues discovered (Test 2.3 is likely to surface the path mismatch).

**Success criteria**: All Layer 2 tests pass, or produce actionable WARN/SKIP messages for known issues.

**Depends on**: Phase 1 (test runner exists).

### Phase 3: Add OC Verification Tests

1. Implement Tests 3.1 and 3.2 (lace-specific OC checks).
2. Implement Test 3.3 (scratch-directory postinstall test).
3. Run `npm run build:cdocs` if needed to produce build output for Test 3.3.

**Success criteria**: Layer 3 tests pass. If the nesting bug exists in postinstall.js, Test 3.3 reports FAIL (confirming the bug exists and the test detects it).

**Depends on**: Phase 1 (test runner exists). Independent of Phase 2.

### Phase 4: CI Integration

1. Add a GitHub Actions workflow step that runs `./scripts/test-hooks.sh` with Layer 1 tests only (Layer 2/3 require local filesystem state).
2. Layer 1 tests are self-contained and can run in CI without lace or plugin cache.
3. Tag Layer 2/3 tests with a `--local` flag so they only run when explicitly requested.

**Success criteria**: CI runs Layer 1 tests on every PR. Local developers can run the full suite with `./scripts/test-hooks.sh --all`.

## Summary

This methodology provides three verification layers with increasing scope: isolated hook scripts, real consumer project simulation, and OC artifact validation.
The key insight is that CC hook scripts are plain bash: they can be tested outside CC by providing the same environment variables (`CLAUDE_PLUGIN_ROOT`, `PWD`) that CC sets.
The main gap is verifying CC's plugin loader actually invokes the hook for a given project, which requires either an interactive session or a CC CLI introspection flag that may not exist.

Related proposals:
- `2026-03-19-decouple-oc-build-from-cc-plugin.md`: covers the postinstall nesting fix and source-repo guard.
- `2026-03-19-opencode-skill-path-conventions.md`: original RFP for the OC skill nesting bug.
