---
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-14T12:00:00-07:00
task_list: marketplace/multi-target
type: proposal
state: live
status: results_accepted
revision_round: 5
tags: [architecture, multi-target, opencode, portability, build-system]
last_reviewed:
  status: accepted
  by: "@claude-opus-4-6"
  at: 2026-03-16T18:00:00-07:00
  round: 5
---

# Multi-Target Marketplace: Publishing cdocs to Claude Code and OpenCode

> BLUF: Extend the clauthier marketplace to publish cdocs for both Claude Code (CC) and OpenCode (OC) from a single canonical source.
> CC remains the canonical authoring format.
> A custom build script converts agents to OC format (frontmatter transformation, model mapping, tool expansion); hooks are reimplemented by hand; skills and rules require no conversion.
> The OC output lives in a generated `opencode/` directory within `plugins/cdocs/` and is committed as build artifacts.
> Based on the [multi-target-plugin-strategies report](../reports/2026-03-14-multi-target-plugin-strategies.md), this follows the "author once, convert at build time" pattern.

> NOTE(claude-opus-4-6/multi-target/round-4-revision): Reverted compound-engineering-plugin to a custom build script -- research confirmed compound-engineering is a user-side install tool (deploys to `~/.config/opencode/`), not a build-artifact generator.
> Added `agent_type` guard for Phase 0 hook scoping so path restriction only applies to cdocs subagents.
> Noted Phase 2 overlap with already-completed cross-target rules integration (AGENTS.md already exists).
> Noted OC limitation: OC events lack agent identity in hook payloads, so agent-scoped path restriction is CC-only for now.

## Summary

This proposal covers the full pipeline from CC-canonical sources to a working OC installation: repo structure changes, agent conversion via a custom build script, hook reimplementation strategy, rules integration via AGENTS.md and `.claude/rules/` compatibility paths, npm packaging, CI/CD, and testing.

The approach minimizes maintenance burden by keeping a single source of truth (CC format) and generating the OC target using a lightweight custom build script (~100-200 lines TS).
Skills are the easiest layer: they work as-is in both tools.
Rules are nearly as easy: OC reads `.claude/rules/` as a fallback.
Agents require frontmatter conversion but the mapping is deterministic.
Hooks are the hardest: OC uses JS/TS plugin exports instead of shell commands, so they must be reimplemented (not converted).

> NOTE(claude-opus-4-6/multi-target): The OC plugin ecosystem is younger than CC's.
> Some conventions (like opencode-rules conditional activation) are community plugins, not built-in.
> This proposal targets the stable OC primitives: agents, skills, and JS/TS plugins.

## Objective

Enable users of OpenCode to install and use cdocs with the same skill set, writing conventions, and document workflows available to CC users today, without requiring CC authors to maintain a separate copy of the plugin.

## Background

Key findings from prior research:

- **[Multi-target plugin strategies](../reports/2026-03-14-multi-target-plugin-strategies.md):** The dominant pattern is CC-canonical with build-time conversion.
  Skills are fully portable.
  Rules are nearly portable (OC reads `.claude/rules/`).
  Agents need frontmatter conversion.
  Hooks are not portable.

- **[OpenCode parity report](../reports/2026-03-13-parity-opencode.md):** OC matches or exceeds CC on hook granularity (30+ event types vs 9), model breadth (75+ providers), and LSP integration.
  CC leads on plugin distribution (marketplace), memory, and subagent orchestration depth.

- **[Agent harness executive summary](../reports/2026-03-13-agent-harness-executive-summary.md):** The "reusable rules as org standards" problem is not well-solved by any tool.
  The best strategy is tool-agnostic prose with tool-specific delivery mechanisms.

### Current cdocs Plugin Structure

```
plugins/cdocs/
  .claude-plugin/plugin.json    # CC manifest
  agents/
    triage.md                   # CC agent format
    reviewer.md
    nit-fix.md
  skills/
    devlog/SKILL.md             # Portable (no changes needed)
    propose/SKILL.md
    review/SKILL.md
    report/SKILL.md
    status/SKILL.md
    init/SKILL.md
    triage/SKILL.md
    implement/SKILL.md
    rfp/SKILL.md
    nit_fix/SKILL.md
  rules/
    writing-conventions.md      # Portable (no changes needed)
    workflow-patterns.md
    frontmatter-spec.md
  hooks/
    hooks.json                  # CC hook declarations (2 active hooks)
    inject-rules.sh                 # ACTIVE: SessionStart — injects rule content as additionalContext (54 lines)
    cdocs-validate-frontmatter.sh   # ACTIVE: PostToolUse Write|Edit — validates frontmatter fields (73 lines)
    validate-cdocs-edit-path.sh     # UNWIRED: file exists but not declared in hooks.json (18 lines)
```

> NOTE(claude-opus-4-6/multi-target): Two hooks are active in `hooks.json`: `inject-rules.sh` (SessionStart) and `cdocs-validate-frontmatter.sh` (PostToolUse Write|Edit).
> The `validate-cdocs-edit-path.sh` script exists as a file but has no corresponding entry in `hooks.json`.
> See the Phase 0 step below for the decision on wiring it up with an `agent_type` guard.

## Proposed Solution

### Repo Structure After Implementation

```
plugins/cdocs/
  .claude-plugin/plugin.json        # CC manifest (canonical, unchanged)
  agents/                           # CC format (canonical, unchanged)
    triage.md
    reviewer.md
    nit-fix.md
  skills/                           # Shared: works in both CC and OC
    devlog/SKILL.md
    propose/SKILL.md
    review/SKILL.md
    report/SKILL.md
    status/SKILL.md
    init/SKILL.md
    triage/SKILL.md
    implement/SKILL.md
    rfp/SKILL.md
    nit_fix/SKILL.md
  rules/                            # Shared: OC reads .claude/rules/ path
    writing-conventions.md
    workflow-patterns.md
    frontmatter-spec.md
  hooks/                            # CC-specific
    hooks.json
    inject-rules.sh                 # ACTIVE: SessionStart rule injection (CC workaround for #14200)
    cdocs-validate-frontmatter.sh   # ACTIVE: PostToolUse frontmatter validation
    validate-cdocs-edit-path.sh     # Wired in Phase 0 with agent_type guard
  AGENTS.md                         # Cross-tool root rules (uses @-imports for CC)
  opencode/                         # GENERATED: do not edit manually
    agents/
      triage.md                     # OC format (converted frontmatter)
      reviewer.md
      nit-fix.md
    skills/                         # Copied from ../skills/ by build script (bundled in npm)
    rules/                          # Copied from ../rules/ by build script (bundled in npm)
    plugins/
      cdocs-hooks.ts                # OC hook implementations (hand-written)
    scripts/
      postinstall.js                # Copies skills/rules to project paths on npm install
    package.json                    # npm manifest for OC distribution
  scripts/
    build-opencode.ts               # Custom build script: CC-to-OC agent conversion + post-processing
```

### Layer-by-Layer Portability

#### 1. Skills: No Changes Needed

Both CC and OC read SKILL.md files from `.claude/skills/` paths.
OC's discovery hierarchy includes `.claude/skills/<name>/SKILL.md` at priority 2 (after `.opencode/skills/`).
The cdocs SKILL.md frontmatter uses only `name` and `description`, which both tools recognize.
Extra OC-recognized fields (`license`, `compatibility`, `metadata`) can be added later without breaking CC (it ignores unknown fields).

No conversion, no duplication, no build step.

#### 2. Rules: Minor Addition

OC reads `.claude/rules/` as a compatibility fallback.
The three cdocs rule files (`writing-conventions.md`, `workflow-patterns.md`, `frontmatter-spec.md`) are pure markdown with optional `paths:` frontmatter.
OC ignores the `paths:` field but still loads the rule content.

An `AGENTS.md` file already exists at `plugins/cdocs/AGENTS.md` (created by the [cross-target rules integration](2026-03-14-cross-target-rules-integration.md) implementation) that imports the rules for tools that rely on AGENTS.md as the primary entry point:

```markdown
# CDocs Agent Instructions

@rules/writing-conventions.md
@rules/workflow-patterns.md
@rules/frontmatter-spec.md
```

CC understands `@`-imports natively and follows them to inject the referenced content.

> NOTE(claude-opus-4-6/multi-target): OC and most other tools (Codex, Cursor, Copilot) likely do NOT follow `@`-imports.
> They read the AGENTS.md content as opaque markdown, meaning `@rules/writing-conventions.md` appears as literal text, not an inclusion directive.
> This plugin-level AGENTS.md uses `@`-imports for CC compatibility.
> The project-level AGENTS.md (managed by the companion [cross-target rules integration proposal](2026-03-14-cross-target-rules-integration.md) via its `/cdocs:init` extension) uses inlined content for cross-tool safety.
> This proposal defers to the rules proposal for the project-level AGENTS.md artifact and `/cdocs:init` OC extensions.
> For OC specifically, the primary rules delivery path is `.claude/rules/` directory reading, not AGENTS.md.

> NOTE(claude-opus-4-6/multi-target): If OC's opencode-rules plugin is installed by the user, they get richer conditional activation (keywords, model, agent, branch, OS, CI) beyond CC's `paths:` scoping.
> This is a user-side enhancement, not something the plugin needs to configure.

#### 3. Agents: Frontmatter Conversion

The three CC agents (`triage.md`, `reviewer.md`, `nit-fix.md`) use CC-specific frontmatter that must be converted for OC.

CC format (example: `triage.md`):

```yaml
---
name: triage
model: haiku
description: Analyze cdocs frontmatter and apply mechanical fixes
tools: Read, Glob, Grep, Edit
---
```

OC format (converted):

```yaml
---
description: Analyze cdocs frontmatter and apply mechanical fixes
mode: subagent
model: anthropic/claude-3-5-haiku-20241022
tools:
  read: true
  edit: true
  write: false
  bash: false
permission:
  edit: ask
---
```

> NOTE(claude-opus-4-6/multi-target): Model IDs shown are current as of March 2026.
> The build script's model mapping table should be kept up to date as new model versions are released.
> The `anthropic/claude-3-5-haiku-20241022` ID for `haiku` is from late 2024 and may need updating.

Key transformations (handled by the custom build script):
- `model` short alias expanded to full provider/model path
- `tools` comma-separated string expanded to boolean object with OC tool names
- `mode: subagent` added (all cdocs agents are subagents)
- `permission` block added based on the tool set (agents with Edit get `edit: ask`)
- `name` field dropped (OC infers name from filename)
- `skills` field dropped (OC does not have an equivalent frontmatter field; skills are available globally)

CC-to-OC tool mapping:

| CC Tool | OC Tool Field | Notes |
|---------|---------------|-------|
| `Read` | `read: true` | Direct mapping |
| `Glob` | (available by default) | No direct OC equivalent; always available |
| `Grep` | (available by default) | No direct OC equivalent; always available |
| `Edit` | `edit: true` + `permission: { edit: ask }` | OC separates edit from write |
| `Write` | `write: true` + `permission: { write: ask }` | OC separates write from edit |

The body content (markdown instructions) is copied verbatim.

#### 4. Hooks: Reimplementation Required

CC hooks are shell commands triggered by 9 event types, declared in `hooks.json`.
OC hooks are JS/TS plugin functions triggered by 30+ event types, exported from a plugin module.

The cdocs hooks:

| Hook | CC Event | CC Status | CC Behavior | OC Equivalent |
|------|----------|-----------|-------------|---------------|
| `inject-rules.sh` (54 lines) | SessionStart | **Active** (declared in hooks.json) | Reads `rules/*.md`, strips frontmatter, injects as `additionalContext` for external CC installs | **Not needed for OC.** OC reads `.claude/rules/` natively; the SessionStart hook is a CC-specific workaround for [#14200](https://github.com/anthropics/claude-code/issues/14200). |
| `cdocs-validate-frontmatter.sh` (73 lines) | PostToolUse (Write\|Edit) | **Active** (declared in hooks.json) | Validates frontmatter fields; returns warnings in `additionalContext` | `tool.execute.after` event handler; inspect tool output for cdocs paths; validate frontmatter |
| `validate-cdocs-edit-path.sh` (18 lines) | PreToolUse (Write\|Edit) | **Unwired** (file exists, not declared in hooks.json) | Blocks edits outside `cdocs/` directories (exit 2) | `tool.execute.before` event handler; return error to block (CC-only: OC lacks agent context in events) |

> NOTE(claude-opus-4-6/multi-target): The `inject-rules.sh` hook is a CC-specific workaround for the plugin rules gap ([#14200](https://github.com/anthropics/claude-code/issues/14200)).
> OC reads `.claude/rules/` natively, so the rule injection functionality does not need an OC equivalent.
> When CC adds a `rules` field to `plugin.json` (#14200), this hook can be retired.

> NOTE(claude-opus-4-6/multi-target): The `validate-cdocs-edit-path.sh` script is an agent safety guard that exists as a file but is not wired in `hooks.json`.
> **Decision: wire it up in CC first as a Phase 0 prerequisite** with an `agent_type` guard so it only restricts cdocs subagents.
> OC cannot replicate this because OC events lack agent identity (see Phase 3 and edge case: "Cross-target parity gap").

The OC plugin file (`opencode/plugins/cdocs-hooks.ts`) will be hand-written (not generated), since the logic translates concepts, not syntax.

Sketch:

```typescript
// opencode/plugins/cdocs-hooks.ts
import type { Plugin } from "opencode";

export default {
  name: "cdocs-hooks",
  version: "0.1.0",

  setup(plugin: Plugin) {
    // Path restriction (equivalent to PreToolUse Write|Edit)
    plugin.on("tool.execute.before", async (event) => {
      const filePath = event.input?.file_path;
      if (!filePath) return;
      if (!filePath.match(/cdocs\/(devlogs|proposals|reviews|reports)\//)) {
        return { error: "Blocked: this agent can only edit files in cdocs document directories." };
      }
    });

    // Frontmatter validation (equivalent to PostToolUse Write|Edit)
    plugin.on("tool.execute.after", async (event) => {
      const filePath = event.output?.file_path;
      if (!filePath?.match(/cdocs\/(devlogs|proposals|reviews|reports)\//)) return;
      // ... frontmatter validation logic (port from bash) ...
    });
  }
} satisfies Plugin;
```

> NOTE(claude-opus-4-6/multi-target): The OC event object shape (`event.input?.file_path`, `event.output?.file_path`) is assumed based on the parity report's description of typed event objects.
> The exact shape of `tool.execute.after` and `tool.execute.before` events should be verified against OC source during implementation.

#### 5. Plugin Manifest and npm Packaging

OC plugins are distributed as npm packages referenced in `opencode.json`.
The generated `opencode/package.json`:

```json
{
  "name": "@weftwise/cdocs-opencode",
  "version": "0.1.0",
  "description": "CDocs documentation framework for OpenCode",
  "main": "plugins/cdocs-hooks.ts",
  "files": [
    "agents/",
    "plugins/",
    "skills/",
    "rules/",
    "scripts/",
    "package.json"
  ],
  "keywords": ["opencode", "plugin", "documentation", "cdocs"],
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/weftwiseink/clauthier"
  },
  "scripts": {
    "postinstall": "node scripts/postinstall.js"
  }
}
```

> NOTE(claude-opus-4-6/multi-target): The postinstall script (`scripts/postinstall.js`) copies skills to `.opencode/skills/cdocs/` and rules to `.claude/rules/` from the bundled copies in the npm package.
> Skills and rules are included in the `files` array so they ship with the package (no `__dirname/..` parent traversal needed).
> Set `CDOCS_SKIP_POSTINSTALL=1` to skip the postinstall copy.
>
> NOTE(opus/opencode-decoupling): **Amended by [decouple-oc-build-from-cc-plugin](2026-03-19-decouple-oc-build-from-cc-plugin.md).**
> The postinstall description above is stale.
> The postinstall now targets `.opencode/skills/<name>/` (flat, no `cdocs/` nesting) and `.opencode/rules/cdocs/` exclusively.
> It no longer writes to `.claude/` directories at all.
> A source-repo guard skips execution when run inside the plugin development environment.

> NOTE(claude-opus-4-6/multi-target): The `.ts` entry point (`plugins/cdocs-hooks.ts`) requires a Bun-compatible runtime.
> OC auto-installs plugins via Bun, so this works in the standard OC installation path.
> Node-based OC installations (if any exist) would fail to load a `.ts` entry point.
> This is a known constraint; the workaround is to add a build step that compiles to JS, but this is deferred until there is evidence of Node-based OC usage.

Users install via:

```json
// In their opencode.json:
{
  "plugin": ["@weftwise/cdocs-opencode"]
}
```

Skills and rules are bundled in the npm package and the `postinstall` script copies them into the project's `.opencode/` directories automatically (skills to `.opencode/skills/<name>/`, rules to `.opencode/rules/cdocs/`).

> NOTE(claude-opus-4-6/multi-target): The npm package delivers hooks, converted agents, skills, and rules as a complete bundle.
> The postinstall uses `__dirname`-relative paths (pointing to the bundled copies within the package) rather than parent directory traversal, so it works correctly for both in-repo and standalone npm installs.

## Important Design Decisions

### Decision: CC remains the canonical authoring format

**Why:** CC is the primary development tool for this project.
Its plugin system (marketplace, `plugin.json`, hooks.json, agent frontmatter) is the format authors interact with.
Fighting the primary tool's conventions creates friction disproportionate to any portability gain.
OC output is generated, not maintained.

### Decision: Commit the generated `opencode/` output

**Why:** Keeps the build output co-located with the source.
Committing the generated output allows users to consume the OC format without running the build script and makes CI validation straightforward (build, diff, fail if dirty).
A separate repo would require cross-repo synchronization.

If the generated output ever needs regeneration (e.g., OC changes its agent format), the fix path is always: update the build script, re-run, commit.
Never manually edit files in `opencode/`.

### Decision: Hand-write OC hooks, do not attempt mechanical conversion

**Why:** CC hooks are bash scripts consuming JSON on stdin and emitting JSON on stdout.
OC hooks are TypeScript plugin exports with typed event objects.
The impedance mismatch is conceptual, not syntactic: translating one shell script line-by-line into TypeScript would produce unidiomatic, fragile code.
The two hooks are small enough (73 and 18 lines of bash) that hand-writing the TypeScript equivalents is faster and produces better results.

### Decision: Use a custom build script for artifact generation; recommend compound-engineering for user-side installation

**Why:** Research confirmed that `compound-engineering-plugin` (`@every-env/compound-plugin`) is a **user-side install tool** that deploys to user config directories (`~/.config/opencode/`), not a build-artifact generator that produces committed output.
Our use case needs committed build artifacts in `opencode/` -- a fundamentally different workflow.

A custom build script (~100-200 lines TS) handles the deterministic agent conversion:
- Read CC agent frontmatter and transform to OC format (model mapping, tool expansion, permission generation).
- Copy agent body content verbatim.
- Handle path rewriting in agent body content.
- Synchronize version from `plugin.json` to `package.json`.
- Generate output in `plugins/cdocs/opencode/`.

The conversion for 3 agents is trivial and well-scoped.
The [multi-target strategies report](../reports/2026-03-14-multi-target-plugin-strategies.md) originally recommended this approach.

compound-engineering remains a valid recommendation for **users** who want to install CC plugins into their OC config directory.
Phase 6 (README) documents it as an alternative user-side install path.

### Decision: Do not switch the canonical format to AGENTS.md

**Why:** Per the multi-target report's recommendation, the cost of maintaining both is low, and CC's plugin system, marketplace, `@`-mentions, and hook lifecycle all depend on `.claude/` conventions.
An `AGENTS.md` file is added as a cross-tool compatibility shim, not as the primary source of truth.
The project-level AGENTS.md (with inlined content for cross-tool safety) is owned by the [cross-target rules integration proposal](2026-03-14-cross-target-rules-integration.md) and its `/cdocs:init` extension.

### Decision: Use Bun as the build runtime

**Why:** Bun handles TypeScript natively without a compile step, enabling the build script to be written in TS and run directly via `bun run`.
Bun is already in the OC ecosystem (OC auto-installs plugins via Bun) and has fast startup for build tooling.

### Decision: Wire `validate-cdocs-edit-path.sh` in CC before porting to OC

**Why:** The path-restriction hook exists as a file but is not declared in `hooks.json`.
Wiring it up in CC first (adding a `PreToolUse` entry to `hooks.json`) ensures the hook logic is tested in the simpler CC environment before the more complex OC reimplementation.
This is a Phase 0 prerequisite.

### Decision: Use relative paths in agent body content

**Why:** The `triage.md` agent body references `plugins/cdocs/rules/frontmatter-spec.md` (absolute from repo root).
This path is CC-relative (from the plugin cache root) and would not resolve in OC's agent loading context.
Update the CC source to use a relative path (`./rules/frontmatter-spec.md` from agents/) that works in both environments.
The build script's post-processing step verifies that referenced paths resolve in both contexts.

### Decision: Derive `package.json` version from `plugin.json` version

**Why:** The CC plugin version lives in `.claude-plugin/plugin.json` (currently `0.1.0`).
The OC npm package version in `opencode/package.json` must match.
The build script copies the version field from `plugin.json` to `package.json` on each run.
This prevents version drift between the two manifests.

## Edge Cases / Challenging Scenarios

### Agent body content referencing CC-specific paths

The `triage.md` agent body says "read the frontmatter specification: `plugins/cdocs/rules/frontmatter-spec.md`".
This path is CC-relative (from the plugin cache root).
In OC, the agent is loaded from a different location.

**Mitigation:** Update the CC source agent body to use relative paths (`./rules/frontmatter-spec.md` from agents/).
The build script's post-processing step verifies that all path references in agent body content resolve in both the CC plugin directory tree and the OC output directory tree.

### Skills referencing templates via relative paths

Some SKILL.md files reference `template.md` alongside the skill file.
This works because both CC and OC resolve template paths relative to the SKILL.md location, and skills are not converted (same files, same directory structure).

No action needed.

### OC version drift

OC's agent frontmatter format has been stable since late 2025 but tool permission fields have evolved.

**Mitigation:** When OC changes its agent format, update the build script's transformation logic and regenerate.
Add a CI check that validates the generated agent files against OC's expected schema (if one exists) or against a snapshot.
Never manually edit files in `opencode/`.
The fix path is always: update the build script, re-run, commit.

### CC `skills:` frontmatter in agents

The `reviewer.md` agent declares `skills: - cdocs:review` in its frontmatter.
OC does not have an equivalent frontmatter field for preloading skills into an agent context.

**Mitigation:** The build script drops unrecognized CC-specific fields (including `skills:`) during conversion.
In OC, skills are globally available via slash commands; the agent body instructions already tell the reviewer to "follow the preloaded `cdocs:review` skill," which works because OC makes skills available to all agents.

### Hook input/output format differences

CC hooks receive a JSON blob on stdin with `tool_input`, `tool_result`, etc.
OC event handlers receive a typed event object.
The shape of tool metadata (file paths, tool names) differs.

**Mitigation:** The hand-written OC hooks abstract over this: they extract the file path from the OC event structure and apply the same validation logic.
This is why mechanical conversion is not attempted.

### Future cdocs agents and the agent_type allowlist

The Phase 0 path-restriction hook uses an allowlist of known cdocs agent types (`triage`, `nit-fix`, `reviewer`) to scope path restriction.
If new cdocs agents are added in the future, they must also be added to the `agent_type` allowlist in `validate-cdocs-edit-path.sh`.
Forgetting to add a new agent means it will not be path-restricted.

**Mitigation:** Document the allowlist requirement in the hook script comments.
Add a CI check or test that verifies all agents declared in `plugins/cdocs/agents/` have corresponding entries in the hook's allowlist.

### Cross-target parity gap: agent-scoped path restriction is CC-only

OC's event system does not include agent identity in hook payloads.
The path-restriction hook (`tool.execute.before`) cannot distinguish between a cdocs subagent and the main session in OC.
This means agent-scoped path restriction is a CC-only capability for now.

**Mitigation:** Accept the parity gap.
The OC hooks plugin can implement path restriction globally (all edits to non-cdocs paths are blocked when the plugin is active) or skip path restriction entirely.
The recommendation is to skip it in OC and rely on the OC permission system (`permission: { edit: ask }`) as a softer guard.
Revisit if OC adds agent context to event payloads.

## Test Plan

### Unit Tests for the Build Script

Unit tests cover the custom build script's transformation and post-processing logic:

1. **Frontmatter transformation:** Assert the build script correctly converts CC frontmatter to OC format (model alias expansion, tool string to boolean object, permission block generation, mode insertion, field dropping).
2. **Version synchronization:** Assert the build script copies the version from `plugin.json` to `package.json`.
3. **Path rewriting:** Assert the build script rewrites absolute paths (e.g., `plugins/cdocs/rules/frontmatter-spec.md`) to relative paths in agent body content.
4. **Path verification:** Assert the build script warns on agent body content containing unrewritten absolute paths.
5. **Body content integrity:** Assert agent body markdown (minus rewritten paths) is otherwise identical before and after the build script runs.

### Integration Tests

1. **Generated agent file validity:** After running the build script, validate each generated OC agent file has well-formed YAML frontmatter.
2. **Idempotency:** Running the build script twice produces identical output.
3. **Dirty-check in CI:** After building, `git diff --exit-code opencode/` passes (no uncommitted changes to generated files).
4. **Auto-discovery:** Adding a new `.md` file to `agents/` and rebuilding produces a corresponding OC agent file in `opencode/agents/`.

### AGENTS.md Integration Tests

1. **CC `@`-import resolution:** In a CC session with the cdocs plugin installed, verify the agent receives imported rule content (expected: agent response references BLUF, sentence-per-line, and callout syntax from the imported rules).
   Pass: agent output demonstrates awareness of all three rule files' content.
   Fail: agent treats `@rules/...` lines as literal text or ignores them.

2. **OC AGENTS.md handling:** In an OC session with the plugin-level AGENTS.md present, verify whether OC follows `@`-imports or treats them as literal text (expected: OC treats `@`-imports as literal text, confirming the need for the inlined approach from the rules proposal).
   Pass: test confirms the expected behavior (literal text) and the `.claude/rules/` fallback delivers rule content.
   Fail: OC unexpectedly follows `@`-imports (a positive surprise that simplifies the architecture).

3. **`.claude/rules/` fallback in OC:** In an OC session with rules files in `.claude/rules/`, verify OC loads the rule content (expected: agent response includes references to BLUF, sentence-per-line, and callout syntax when asked about writing conventions).
   Pass: agent output demonstrates awareness of writing conventions from `.claude/rules/`.
   Fail: OC does not read `.claude/rules/` as a fallback.

### Manual Validation

1. **OC agent loading:** Start OC in a test project with the generated agents in `.opencode/agents/` and verify they appear in the agent list.
   Expected: all 3 agents (triage, reviewer, nit-fix) appear by name in OC's agent selection menu.
   Fail: any agent is missing or has malformed metadata.

2. **Skill availability:** Verify cdocs skills appear in OC's skill menu when `.claude/skills/` is populated.
   Expected: all 10 skills (devlog, propose, review, report, status, init, triage, implement, rfp, nit_fix) appear by name.
   Fail: any skill is missing or not invocable.

3. **Rules loading:** Verify OC loads the rules from `.claude/rules/` or via `AGENTS.md` references.
   Expected: agent response includes references to BLUF, sentence-per-line, and callout syntax when asked "what writing conventions are you following?"
   Fail: agent has no awareness of cdocs writing conventions.

4. **Hook execution:** Trigger the PostToolUse equivalent by writing a cdocs file in OC and checking for validation output.
   Expected: writing a cdocs file with missing frontmatter fields triggers a validation warning naming the missing fields.
   Fail: no validation feedback appears, or the validation produces false positives/negatives.

## Verification Methodology

The primary verification loop:

1. Run the build script (`scripts/build-opencode.ts`) and confirm clean exit.
2. Diff `opencode/agents/*.md` against expected snapshots.
3. In a test project, install the OC plugin:
   - Copy `opencode/agents/` to `.opencode/agents/`
   - Copy `skills/` to `.claude/skills/` (or `.opencode/skills/`)
   - Copy `rules/` to `.claude/rules/`
   - Add `AGENTS.md` at project root (with inlined content per the rules proposal)
   - Add plugin to `opencode.json`
4. Start OC and verify:
   - `/cdocs:devlog test` creates a devlog with correct frontmatter
   - Agent list shows triage, reviewer, nit-fix
   - Rules content appears in agent context (check via a prompt like "what writing conventions are you following?")

> NOTE(claude-opus-4-6/multi-target): Full automated integration testing of OC is currently limited by the lack of a headless OC mode for CI environments.
> Manual verification is required for the initial implementation.
> A future CI step could use the OC HTTP API for automated validation.

## Implementation Phases

### Phase 0: Wire Up Path-Restriction Hook in CC with Agent Scoping

**Scope:** Activate the existing but unwired `validate-cdocs-edit-path.sh` hook in CC and modify it to scope path restriction to cdocs subagents only.

1. Add a `PreToolUse` entry to `hooks.json` matching `Write|Edit` that invokes `validate-cdocs-edit-path.sh`.
2. **Modify `validate-cdocs-edit-path.sh`** to check the `agent_type` field from the JSON input (~5 lines added):
   - Parse `agent_type` from the hook's stdin JSON.
   - If `agent_type` is absent (main session) or is not one of `triage`, `nit-fix`, `reviewer`, exit 0 immediately (allow the operation).
   - Only apply path restriction when `agent_type` matches a known cdocs subagent.
3. Test the hook in a CC session:
   - Attempt to edit a file outside `cdocs/` directories **from a cdocs subagent** and verify the edit is blocked.
   - Test that edits to files inside `cdocs/` directories are permitted from a subagent.
   - **Verify that the main session can still edit any file** when the cdocs plugin is installed (the `agent_type` guard must not block the main session).

**Success criteria:** `hooks.json` declares both hooks.
Editing a non-cdocs file from a cdocs subagent triggers the path-restriction block.
Editing a cdocs file from a subagent proceeds normally.
Main session Write/Edit operations proceed unblocked.
Only cdocs subagent operations are path-restricted.

**Constraints:** Do not modify agent files.
Do not modify any other hook scripts besides `validate-cdocs-edit-path.sh`.

### Phase 1: Agent Conversion via Custom Build Script

**Scope:** Write a custom build script (~100-200 lines TS) to convert CC agents to OC format.

1. **Create the build script** at `plugins/cdocs/scripts/build-opencode.ts`:
   - Read CC agent frontmatter from `agents/*.md` and transform to OC format:
     - **Model mapping:** expand short aliases (`haiku`, `sonnet`, `opus`) to full provider/model paths (`anthropic/claude-3-5-haiku-20241022`, etc.).
     - **Tool expansion:** convert comma-separated tool string (`Read, Glob, Grep, Edit`) to OC boolean object (`read: true`, `edit: true`, etc.).
     - **Permission generation:** add permission block based on the tool set (agents with Edit get `edit: ask`, agents with Write get `write: ask`).
     - **Mode insertion:** add `mode: subagent` (all cdocs agents are subagents).
     - **Field dropping:** drop CC-specific fields (`name`, `skills`) that OC does not recognize.
   - Copy agent body content verbatim.
   - Handle **path rewriting** in agent body content (e.g., rewrite `plugins/cdocs/rules/frontmatter-spec.md` to `./rules/frontmatter-spec.md` from agents/).
   - **Version synchronization** from `.claude-plugin/plugin.json` to `opencode/package.json`.
   - **Validation** that agent body path references resolve in both CC and OC contexts (warn on absolute paths).
   - **Copy skills and rules** into `opencode/skills/` and `opencode/rules/` so they are bundled in the npm package.
   - Generate output in `plugins/cdocs/opencode/`.

2. Create `opencode/` directory structure (agents, skills, rules, plugins, scripts).
3. Run the build script and verify output for all three agents.
4. Add unit tests for the frontmatter transformation and post-processing.

**Success criteria:** The build script produces three valid OC agent files.
Diffing the generated frontmatter against hand-crafted expected output shows no differences.
The script is ~100-200 lines TS (excluding comments and tests).

**Constraints:** Do not modify any CC-format files (except updating agent body paths from absolute to relative if needed).
Do not modify skills or rules.

### Phase 2: AGENTS.md and Rules Integration (Verification)

**Scope:** Verify the existing cross-target rules integration is sufficient for OC support.

> NOTE(claude-opus-4-6/multi-target): `plugins/cdocs/AGENTS.md` already exists from the completed cross-target rules integration implementation.
> It contains `@`-imports for the three rule files.
> The README already documents rules integration.
> This phase verifies the existing work rather than creating new files.

1. Verify CC reads rules via `@`-imports in `AGENTS.md` (expected: already working).
2. Verify OC reads the rules via the `.claude/rules/` fallback.
3. Test OC's handling of `@`-imports in AGENTS.md (expected: treated as literal text, confirming the need for the inlined approach).
4. Document any gaps between CC and OC rules delivery.

The project-level AGENTS.md (with inlined content for cross-tool safety) is owned by the [cross-target rules integration proposal](2026-03-14-cross-target-rules-integration.md).
This proposal defers to that proposal for the AGENTS.md approach used in `/cdocs:init` and project-level configuration.

**Success criteria:** Both CC and OC load the writing conventions, workflow patterns, and frontmatter spec rules when the plugin is installed (CC via `@`-imports or `.claude/rules/`, OC via `.claude/rules/` fallback).

**Constraints:** Do not modify existing rule files or AGENTS.md.
This phase is verification-only unless gaps are found.

### Phase 3: OC Hooks Plugin

**Scope:** Hand-write the OC TypeScript plugin implementing hook equivalents.
Only the frontmatter validation hook can be fully ported.
The path-restriction hook cannot be agent-scoped in OC.
The rule injection hook (`inject-rules.sh`) does not need an OC equivalent since OC reads `.claude/rules/` natively.

> NOTE(claude-opus-4-6/multi-target): OC's event system does NOT include agent identity in hook payloads.
> The `tool.execute.before` event does not carry an `agent_type` field, so the path-restriction hook cannot distinguish between a cdocs subagent and the main session.
> Only the frontmatter validation hook (`tool.execute.after`) can be ported to OC.
> The agent-scoped path restriction is CC-only for now (see edge case: "Cross-target parity gap").

1. Create `opencode/plugins/cdocs-hooks.ts`:
   - Implement frontmatter validation on `tool.execute.after` for Write/Edit to cdocs paths (port from `cdocs-validate-frontmatter.sh`, 73 lines of bash).
   - **Do not port path restriction** (`validate-cdocs-edit-path.sh`) -- OC lacks agent context in events, so it cannot be scoped to cdocs subagents without blocking the main session.
2. Test the hooks manually in an OC session:
   - Write a cdocs file with missing frontmatter and verify the validation warning appears.
3. Document any behavioral differences from the CC hooks (e.g., output format, error messaging).

**Success criteria:** Writing a cdocs file in OC triggers frontmatter validation feedback.
The hook correctly identifies missing required fields.

**Constraints:** This is hand-written code, not generated by the build script.
Keep the implementation minimal: match CC hook behavior, do not add new functionality.

### Phase 4: npm Packaging

**Scope:** Create the npm package manifest and publish workflow.

1. Create `opencode/package.json` with appropriate metadata (version derived from `plugin.json` by the build script).
2. Add a `files` field to control what ships in the package.
3. Implement the postinstall script that copies skills and rules (with `CDOCS_SKIP_POSTINSTALL` opt-out).
4. Test local installation: `npm pack` in `opencode/`, then reference the tarball in a test project's `opencode.json`.
5. Set up npm publishing (scoped under `@weftwise`).

**Success criteria:** `npm pack` produces a valid tarball.
A test project can reference the local tarball and OC loads the plugin, agents, and hooks.
The postinstall copies skills and rules to the correct paths.

**Constraints:** Do not publish to npm until the build output is validated and the plugin works end-to-end.

### Phase 5: CI/CD

**Scope:** Automate build, validation, and optionally publishing.

1. Add a GitHub Actions workflow:
   - Step 1: Run `scripts/build-opencode.ts` (custom build script).
   - Step 2: `git diff --exit-code opencode/` (dirty check: fail if generated files are stale).
   - Step 3: YAML lint on generated agent files.
   - Step 4: (Optional) `npm pack` in `opencode/` (package validation).
2. On tagged releases, optionally publish the npm package.
3. Add a `Makefile` or `package.json` script at the repo root for local convenience: `make build-opencode` or `npm run build:opencode`.

Use a separate GitHub Actions job with path filters (`plugins/cdocs/**`) and `continue-on-error: true` so CC-only PRs are not blocked by OC build failures.

**Success criteria:** CI catches stale generated files on PRs.
Tagged releases produce a valid npm package.

### Phase 6: Documentation and README Updates

**Scope:** Update the cdocs README and clauthier CLAUDE.md to document multi-target support.

1. Add an "OpenCode Installation" section to `plugins/cdocs/README.md`.
2. Document the build script usage (`bun run scripts/build-opencode.ts`), including auto-discovery of new agents.
3. Document `compound-engineering-plugin` as an alternative user-side install path for users who want to deploy CC plugins directly to their OC config directory (`~/.config/opencode/`).
4. Add a brief note in `CLAUDE.md` about the multi-target structure.
5. Add a `.gitattributes` or comment header in generated files marking them as auto-generated.

**Success criteria:** A new user can follow the README to install cdocs in either CC or OC.

**Constraints:** Do not restructure existing documentation.
Add sections, do not rewrite.
