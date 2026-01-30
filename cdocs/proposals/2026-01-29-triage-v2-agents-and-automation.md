---
first_authored:
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-29T16:00:00-08:00
task_list: cdocs/haiku-subagent
type: proposal
state: live
status: wip
tags: [architecture, workflow_automation, subagent_patterns, plugin_idioms, triage, hooks]
---

# Triage v2: Agent Abstraction with Hook-Scoped Edits

> BLUF(mjr/cdocs/haiku-subagent): The v1 triage used a skill containing an inline prompt template for a read-only haiku subagent.
> Three problems: wrong abstraction (skill doing an agent's job), fragile safety (prompt-based read-only instead of infrastructure enforcement), and no automated review dispatch.
> The v2 architecture uses formal agent definitions with infrastructure-enforced tool restrictions, PreToolUse hooks scoping Edit/Write to cdocs document paths, the `skills` frontmatter field to preload review instructions into the reviewer agent (no inlining), and Read-at-runtime for rules (no duplication).
> The triage agent applies mechanical fixes (tags, timestamps, missing fields) directly via hook-scoped Edit, and reports status/workflow recommendations to the dispatcher skill.

## Objective

Three problems surfaced during v1 implementation and review:

1. **Wrong abstraction**: Triage is implemented as a skill containing a prompt template that the main agent manually passes to a Task subagent.
Plugins support a formal `agents/` directory where subagents are registered with explicit tool restrictions, model selection, and descriptions.
Using this mechanism makes triage a first-class agent rather than a prompt embedded in a skill.

2. **Fragile safety model**: V1 testing showed haiku ignoring explicit `CRITICAL: do not edit` instructions: modifying `status` fields and editing 3 unrelated files.
The v1 workaround (making the subagent fully read-only) is overly conservative: it forces the main agent to apply every mechanical edit, wasting top-level context on bookkeeping.
The real problem was giving haiku unrestricted Edit access.
Agent-scoped PreToolUse hooks can restrict Edit to cdocs document paths at the infrastructure level, letting haiku apply mechanical fixes safely.

3. **Review automation is documented but not scaffolded**: The triage skill documents a `[REVIEW]` recommendation that should trigger a review subagent, but nothing automates the dispatch.
In the v1 session, concurrent tasks caused the review to use recency-based context rather than the intended subagent flow.

## Background

### Claude Code agent system

Plugins support an `agents/` directory (auto-discovered or declared in `plugin.json`).
Agent definitions are markdown files with YAML frontmatter:

```yaml
---
name: triage
model: haiku
description: Analyze and fix cdocs frontmatter
tools: Read, Glob, Grep, Edit
hooks:
  PreToolUse:
    - matcher: "Edit"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/hooks/validate-cdocs-edit-path.sh"
skills:
  - cdocs:review
---

[Agent instructions as markdown body]
```

Key properties:
- **`tools`** (allowlist) or **`disallowedTools`** (denylist): enforced at infrastructure level. The agent cannot call tools outside its allowlist.
- **`hooks`**: lifecycle hooks scoped to this agent. PreToolUse hooks fire before each tool call, receive `tool_input` as JSON via stdin, and can block (exit 2) or allow (exit 0). Cleaned up when the agent finishes.
- **`skills`**: skills to preload at startup. Full skill content is injected into the agent's context, eliminating the need to inline skill instructions in the agent body.
- **`model`**: `haiku`, `sonnet`, `opus`, or `inherit`.
- Agents appear in the `/agents` interface and can be auto-invoked by the main agent based on description matching.
- Agents **cannot spawn other subagents** (no Task nesting).

### Context inheritance constraints

Subagents do **not** inherit:
- Plugin rules from `rules/` (there is no `rules` field in the plugin spec).
- Skills from the parent conversation (must be explicitly listed in `skills` frontmatter).
- The full Claude Code system prompt.

Subagents **do** receive:
- Their own system prompt (the agent markdown body).
- Basic environment details (working directory).
- Preloaded skills (via `skills` frontmatter field: full content injected at startup).

This means rules like `frontmatter-spec.md` and `writing-conventions.md` must be provided to agents through one of:
1. **`skills` field**: convert rules to skills or reference existing skills that contain the information.
2. **Read at runtime**: the agent's system prompt instructs it to Read the rule files before starting work. Costs a tool call, but eliminates duplication.
3. **Inline in agent body**: paste rule content directly. Functional but creates maintenance burden.

### V1 implementation state

```
plugins/cdocs/
├── skills/triage/SKILL.md    # Skill with embedded prompt template
├── rules/workflow-patterns.md # "End-of-Turn Triage" pattern
├── hooks/hooks.json           # PostToolUse frontmatter validation
└── (no agents/ directory)
```

Problems:
- The prompt template is instructions to the main agent about how to construct a subagent: a skill doing an agent's job.
- Tool restrictions are prompt-based (`CRITICAL: You are READ-ONLY`), not infrastructure-enforced.
- The read-only approach forces the main agent to apply all mechanical edits, wasting top-level context.
- Review dispatch is documented in the skill but never triggered automatically.

### V1 test results

| Test | Configuration | Result |
|------|--------------|--------|
| 1 | Haiku with Edit access, no guardrails | Edited status + 3 unrelated files |
| 2 | Haiku with Edit access, CRITICAL prohibition | Edited status again |
| 3 | Haiku with prompt-based read-only | Correct behavior, no edits |

Test 3 succeeded but is overly conservative.
The real failure in tests 1-2 was not that haiku edited: it was that haiku edited the wrong things (status, unrelated files).
Hook-scoped Edit addresses this at the right level: haiku can edit, but only cdocs document files, and only the files it was asked to triage.

## Proposed Solution

### Architecture: agent + hook + skill separation

```
plugins/cdocs/
├── agents/
│   ├── triage.md                      # Haiku: hook-scoped Edit for mechanical fixes
│   └── reviewer.md                    # Sonnet: preloads review skill, hook-scoped Write/Edit
├── hooks/
│   ├── hooks.json                     # Existing PostToolUse validation
│   ├── cdocs-validate-frontmatter.sh  # Existing
│   └── validate-cdocs-edit-path.sh    # New: PreToolUse guard for agent Edit/Write
├── skills/
│   └── triage/SKILL.md               # Thin dispatcher: invokes agents, routes actions
└── rules/
    ├── frontmatter-spec.md            # Read at runtime by agents (not inlined)
    ├── writing-conventions.md         # Read at runtime by agents (not inlined)
    └── workflow-patterns.md           # Updated to reflect agent architecture
```

**Three-layer enforcement:**

1. **Tool allowlist** (infrastructure): agents can only call tools in their `tools` list.
2. **PreToolUse hook** (infrastructure): Edit/Write calls are validated against cdocs document paths. Exit code 2 blocks disallowed paths.
3. **Prompt scoping** (defense-in-depth): the agent prompt specifies which files to triage. If haiku edits a different cdocs file, the hook allows it (it's a valid cdocs path) but the damage is limited to the cdocs domain. This is an acceptable blast radius.

### Triage agent definition

```yaml
---
name: triage
model: haiku
description: Analyze cdocs frontmatter and apply mechanical fixes
tools: Read, Glob, Grep, Edit
hooks:
  PreToolUse:
    - matcher: "Edit"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/hooks/validate-cdocs-edit-path.sh"
---
```

Body: the triage analysis prompt, restructured from v1.
The agent:

1. Reads `plugins/cdocs/rules/frontmatter-spec.md` (one Read call, no duplication).
2. Reads each target file.
3. **Applies mechanical fixes directly via Edit**: tags, timestamps, missing required fields.
4. **Reports** status transitions and workflow recommendations (these require orchestration context the agent doesn't have).

The split: mechanical fixes are applied by the agent, semantic decisions are reported to the dispatcher.

### Reviewer agent definition

```yaml
---
name: reviewer
model: sonnet
description: Review cdocs documents with structured findings and verdicts
tools: Read, Glob, Grep, Edit, Write
skills:
  - cdocs:review
hooks:
  PreToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/hooks/validate-cdocs-edit-path.sh"
---
```

Body: minimal instructions directing the agent to follow the preloaded review skill.
The `skills: [cdocs:review]` field injects the full review skill content at startup: no inlining, no duplication, automatically stays current when the skill is updated.

The agent reads `plugins/cdocs/rules/frontmatter-spec.md` and `plugins/cdocs/rules/writing-conventions.md` at runtime for domain context.

> NOTE(mjr/cdocs/haiku-subagent): The reviewer agent needs Write (to create the review document) and Edit (to update the target's `last_reviewed` frontmatter).
> Both are scoped to cdocs paths via the shared hook.

### Hook script: `validate-cdocs-edit-path.sh`

```bash
#!/usr/bin/env bash
# PreToolUse hook: restricts Edit/Write to cdocs document paths.
# Exit 0 = allow, exit 2 = block (stderr sent to agent as error).

set -euo pipefail
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

if [[ ! "$FILE_PATH" =~ cdocs/(devlogs|proposals|reviews|reports)/ ]]; then
  echo "Blocked: this agent can only edit files in cdocs document directories." >&2
  exit 2
fi

exit 0
```

Reused by both agents via `${CLAUDE_PLUGIN_ROOT}/hooks/validate-cdocs-edit-path.sh`.
The regex matches the same paths as the existing `cdocs-validate-frontmatter.sh` hook.

### Triage skill (thin dispatcher)

`skills/triage/SKILL.md` becomes orchestration-only:

1. Collect modified cdocs file paths (from `$ARGUMENTS` or recent Write/Edit operations).
2. Invoke the triage agent via Task tool, passing the file list.
3. The agent applies mechanical fixes directly and returns a report with status/workflow recommendations.
4. The dispatcher applies status recommendations it agrees with.
5. The dispatcher routes workflow actions:
   - `[REVIEW]` → invoke the reviewer agent, passing the document path.
   - `[REVISE]` → main agent revises per review action items.
   - `[ESCALATE]` → present options to the user.
   - `[STATUS]` → apply the recommended status change.
   - `[NONE]` → no action.
6. After review completes, re-triage the review document to validate its frontmatter.

The skill contains **no agent instructions**: agents own their prompts, the skill owns orchestration.

### Automated review dispatch

When the triage report includes a `[REVIEW]` recommendation:

1. The dispatcher invokes the reviewer agent via Task tool, passing the document path.
2. The reviewer agent (with preloaded review skill) reads the document, writes the review to `cdocs/reviews/`, and updates `last_reviewed`.
3. On return, the dispatcher re-runs triage on the review to validate its frontmatter.
4. The dispatcher reports the verdict to the user.

This flow is explicit in the skill's orchestration logic, not merely documented as something the main agent might do.

## Important Design Decisions

### Decision 1: Hook-scoped Edit, not read-only

**Decision:** Give the triage agent Edit access restricted via PreToolUse hooks, rather than making it read-only.

**Why:** The v1 read-only approach was a blunt workaround for a scoping problem.
The real issue in v1 tests was not that haiku edited: it was that haiku edited the wrong things (status field, unrelated files).
PreToolUse hooks address this precisely: the agent can edit, but only files in `cdocs/(devlogs|proposals|reviews|reports)/`.
This lets haiku apply mechanical fixes (tags, timestamps, missing fields) directly, freeing the main agent from bookkeeping.

The split between "mechanical" (agent applies) and "semantic" (agent reports) is:
- **Mechanical**: tag additions/removals, timestamp fixes, adding missing required fields with defaults. These are deterministic corrections.
- **Semantic**: status transitions, workflow actions. These require orchestration context (e.g., knowing whether to trigger a review) that the agent doesn't have.

### Decision 2: `skills` field for context injection, not inlining

**Decision:** The reviewer agent uses `skills: [cdocs:review]` to preload review instructions. Rules are read at runtime via Read tool.

**Why:** Inlining skill content into agent definitions creates duplication that goes stale.
The `skills` frontmatter field injects full skill content at agent startup: the agent gets the review methodology without any copy-paste.
When the review skill is updated, the reviewer agent automatically gets the new version.

For rules (`frontmatter-spec.md`, `writing-conventions.md`), agents read them at runtime.
This costs one Read call per rule file but eliminates all duplication.
The alternative (converting rules to skills) would work but misrepresents their nature: they're reference documents, not action instructions.

### Decision 3: Shared hook script for both agents

**Decision:** A single `validate-cdocs-edit-path.sh` script is used by both the triage and reviewer agents.

**Why:** Both agents need the same constraint: Edit/Write scoped to cdocs document paths.
The regex is identical to the existing `cdocs-validate-frontmatter.sh` path check.
One script, one maintenance point, consistent enforcement.

### Decision 4: Separate triage and reviewer agents

**Decision:** Two agents with different capability profiles.

**Why:**
- Triage is mechanical: read files, check frontmatter, apply fixes. Haiku is sufficient. Tools: Read, Glob, Grep, Edit.
- Reviews require critical analysis and document creation. Sonnet (or opus) is appropriate. Tools: Read, Glob, Grep, Edit, Write.

Combining them would require either over-provisioning model (giving triage sonnet's cost) or under-provisioning tools (giving the reviewer haiku's limitations).

### Decision 5: Triage skill as thin dispatcher

**Decision:** The skill contains orchestration logic only. No agent instructions, no prompt templates.

**Why:** Separation of concerns.
The agent owns its prompt (what to analyze, how to fix).
The skill owns orchestration (when to invoke, how to route results).
V1 conflated these: the skill contained both dispatch logic and the full agent prompt.

### Decision 6: Sonnet default for reviewer

**Decision:** Default the reviewer agent to sonnet.

**Why:** Reviews require critical analysis but don't require opus-level reasoning for most documents.
The dispatcher can override to opus for high-stakes documents (proposals) if warranted.

## Edge Cases / Challenging Scenarios

### 1. Agent registration or hook enforcement fails

If the `agents/` directory isn't picked up, or hooks don't fire for agent-scoped PreToolUse definitions, the architecture falls back to the v1 approach (inline prompt, read-only).

Mitigation: Phase 0 validates both agent registration and hook enforcement before any restructuring.

### 2. `skills` field doesn't resolve plugin-namespaced skills

The `skills: [cdocs:review]` syntax may not work if the field expects bare skill names or paths rather than plugin-namespaced references.

Mitigation: Phase 0 tests skill preloading with different reference formats (`cdocs:review`, `review`, path). If none work, fall back to Read-at-runtime for the review skill content (one extra Read call, still no inlining).

### 3. Triage agent edits wrong cdocs files

The hook restricts Edit to `cdocs/(devlogs|proposals|reviews|reports)/` paths, but haiku might edit a cdocs file it wasn't asked to triage (repeating the v1 "3 unrelated files" issue).

Mitigation: two layers.
Layer 1 (hook): restricts to cdocs document paths. Infrastructure-enforced.
Layer 2 (prompt): the agent prompt says "Edit ONLY the files listed below." Defense-in-depth.
The blast radius of a layer-2 failure is limited: haiku can only touch cdocs documents (layer 1 holds), and the edits are mechanical (tags, timestamps). The worst case is a correct tag being added to a file that wasn't requested: low-severity, easily reverted.

### 4. Triage agent applies incorrect mechanical fixes

Haiku might add wrong tags, set incorrect timestamps, or add fields with bad defaults.

Mitigation: the existing PostToolUse hook (`cdocs-validate-frontmatter.sh`) validates required fields after every Edit. The dispatcher can also re-read files after triage to spot-check changes. Over time, the triage prompt can be refined based on observed errors.

### 5. Review dispatch in a busy session

V1 showed concurrent tasks interfering with review context.

Mitigation: the reviewer agent runs in an isolated context (separate process with its own system prompt). Concurrent main-agent tasks don't affect it. The skill's explicit dispatch (Task tool invocation) replaces the implicit "main agent should decide to review."

### 6. Rules files change without agent awareness

If `frontmatter-spec.md` or `writing-conventions.md` are updated, agents reading them at runtime automatically get the new version. No maintenance action required.

The `skills` field also auto-resolves: if the review skill is updated, the reviewer agent gets the new content on next invocation.

This is a significant improvement over inlining, where stale content requires manual agent definition updates.

## Test Plan

1. **Agent registration**: Add `agents/` directory with triage.md, verify it appears in `/agents` interface.
2. **Hook enforcement**: Invoke triage agent, have it attempt to Edit a non-cdocs file (e.g., `README.md`). Verify the PreToolUse hook blocks with exit code 2.
3. **Hook-scoped Edit works**: Invoke triage agent on a cdocs file with a missing tag. Verify the agent applies the tag fix directly via Edit (hook allows it).
4. **Skills preloading**: Create reviewer agent with `skills: [cdocs:review]`. Verify the agent receives review instructions without inlining. Test alternate formats if needed.
5. **Read-at-runtime**: Invoke triage agent, verify it reads `frontmatter-spec.md` before analyzing documents.
6. **Triage accuracy**: Run triage agent against existing cdocs, compare output to v1 results. Mechanical fixes should be applied directly; status/workflow should be reported.
7. **Review dispatch**: Create a document with `status: review_ready`, run triage, verify `[REVIEW]` recommendation triggers automatic reviewer agent invocation.
8. **End-to-end**: Author a proposal, run triage, verify auto-review, verify review frontmatter (re-triage).
9. **Concurrent isolation**: Run triage while other work is in progress, verify reviewer agent runs without context interference.

## Implementation Phases

### Phase 0: Validate platform affordances

1. Add `"agents": "./agents/"` to `plugins/cdocs/.claude-plugin/plugin.json`.
2. Create a minimal test agent (`agents/test.md`) with `tools: Read, Edit` and a PreToolUse hook that blocks Edit on non-cdocs paths.
3. Reinstall the plugin. Verify the agent appears in `/agents`.
4. Invoke it: confirm tool allowlist is enforced (can Read, cannot Write). Confirm PreToolUse hook blocks Edit on a non-cdocs path. Confirm Edit succeeds on a cdocs path.
5. Test `skills` field: add `skills: [cdocs:review]` (and alternate formats if needed). Verify skill content is injected.
6. Clean up test agent.

**Success criteria:** Agent registration, hook enforcement, and skill preloading all work in the plugin context.

### Phase 1: Create hook script and triage agent

1. Create `plugins/cdocs/hooks/validate-cdocs-edit-path.sh` (the shared PreToolUse guard).
2. Create `plugins/cdocs/agents/triage.md` with:
   - `model: haiku`, `tools: Read, Glob, Grep, Edit`
   - PreToolUse hook referencing the shared script.
   - Body: triage analysis prompt (extracted and restructured from `skills/triage/SKILL.md`), with instructions to Read frontmatter spec at runtime and apply mechanical fixes directly.
3. Refactor `skills/triage/SKILL.md` to thin dispatcher: invoke triage agent, route results.
4. Test: invoke `/cdocs:triage` on existing cdocs, verify mechanical fixes applied by agent, status/workflow reported to dispatcher.

**Success criteria:** Triage agent applies mechanical fixes directly. Edit scoped to cdocs paths via hook. Skill is orchestration-only.

### Phase 2: Create reviewer agent

1. Create `plugins/cdocs/agents/reviewer.md` with:
   - `model: sonnet`, `tools: Read, Glob, Grep, Edit, Write`
   - `skills: [cdocs:review]` (preloaded review instructions).
   - PreToolUse hook referencing the shared script.
   - Body: minimal instructions to follow preloaded skill and read rules at runtime.
2. Test: invoke reviewer agent on a `review_ready` document, verify it produces a well-formed review without inlined context.

**Success criteria:** Reviewer agent creates correct reviews using preloaded skill and runtime-read rules. No inlined content in agent definition.

### Phase 3: Wire automated review dispatch

1. Update `skills/triage/SKILL.md` dispatch logic: on `[REVIEW]`, invoke reviewer agent via Task tool.
2. Add re-triage step after review completes.
3. Add user reporting of review verdict.
4. Test end-to-end: author -> triage -> auto-review -> re-triage -> report.

**Success criteria:** `review_ready` documents automatically get reviewed when triage recommends it.

### Phase 4: Documentation and cleanup

1. Update `rules/workflow-patterns.md` to reflect agent-based architecture (triage applies fixes, not read-only).
2. Update CLAUDE.md if needed.
3. Clean up v1 triage prompt template from skill (replaced by agent definition).
4. Clean up any stale references.

**Success criteria:** Documentation matches implementation. No stale v1 artifacts.
