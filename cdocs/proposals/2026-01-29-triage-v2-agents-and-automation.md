---
first_authored:
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-29T16:00:00-08:00
task_list: cdocs/haiku-subagent
type: proposal
state: live
status: wip
tags: [architecture, workflow_automation, subagent_patterns, plugin_idioms, triage]
---

# Triage v2: Proper Agent Abstraction and Automated Review Flow

> BLUF(mjr/cdocs/haiku-subagent): The v1 triage implementation used a skill to instruct the main agent to spawn a haiku Task subagent with a prompt. This is not idiomatic — Claude Code plugins have a formal `agents/` directory where subagents are defined as markdown files with YAML frontmatter, including enforceable `tools`/`disallowedTools` restrictions. The triage subagent should be a proper agent definition with `disallowedTools: Edit, Write, Task` (enforced at infrastructure, not prompt level). The triage skill should become a thin dispatcher that invokes the registered agent. Additionally, the v1 implementation lacks scaffolding to actually trigger the review subagent flow — the instructions exist but nothing automates the dispatch. This proposal addresses all three issues: agent abstraction, tool enforcement, and review automation.

## Objective

Three problems surfaced during v1 implementation and review:

1. **Wrong abstraction**: Triage is implemented as a skill containing a prompt template that the main agent manually passes to a Task subagent. Plugins support a formal `agents/` directory where subagents are registered with explicit tool restrictions, model selection, and descriptions. Using this mechanism would make triage a first-class agent rather than a prompt embedded in a skill.

2. **Prompt-based safety is unreliable**: V1 testing showed haiku ignoring explicit `CRITICAL: do not edit` instructions — modifying `status` fields and even editing 3 unrelated files it wasn't asked to look at. The workaround (making the subagent fully read-only via prompt instructions) works only because the main agent happens not to provide Edit/Write tools to general-purpose subagents in this context. The `disallowedTools` agent frontmatter field would enforce this at the infrastructure level.

3. **Review automation is documented but not scaffolded**: The triage skill documents a `[REVIEW]` recommendation that should trigger an opus review subagent, but nothing in the plugin actually automates this dispatch. The main agent must read the triage output, decide to act on it, and manually construct a review subagent invocation. In the v1 implementation session, concurrent tasks caused the review skill to use recency-based context rather than the intended subagent flow.

## Background

### Claude Code agent abstraction

Plugins support an `agents/` directory registered in `plugin.json`:

```json
{
  "agents": "./agents/"
}
```

Agent definitions are markdown files with YAML frontmatter:

```yaml
---
name: triage
model: haiku
description: Analyze cdocs frontmatter and recommend changes
tools: Read, Glob, Grep
# or: disallowedTools: Edit, Write, Task
---

[Agent instructions as markdown body]
```

Key properties:
- **`tools`** (allowlist) or **`disallowedTools`** (denylist): enforced at infrastructure level, not prompt level. The agent literally cannot call disallowed tools.
- **`model`**: sets the model for the agent (haiku, sonnet, opus).
- Agents appear in the `/agents` interface and can be auto-invoked by the main agent based on description matching.
- Agents **cannot spawn other subagents** (no Task nesting).

### Built-in read-only agents

Claude Code ships two read-only agent types that validate the pattern:
- **Explore**: haiku model, tools restricted to Read/Glob/Grep. Used for codebase search.
- **Plan**: inherits parent model, read-only. Used for research.

The triage agent is functionally identical to Explore in capability profile (haiku + read-only) but with a domain-specific prompt.

### V1 implementation state

Current structure:
```
plugins/cdocs/
├── skills/triage/SKILL.md    # Skill with embedded prompt template
├── rules/workflow-patterns.md # "End-of-Turn Triage" pattern
└── (no agents/ directory)
```

The triage SKILL.md contains:
1. A prompt template to pass to a haiku Task subagent (the agent's instructions, inline).
2. A dispatch table for acting on triage recommendations (REVIEW, REVISE, ESCALATE, STATUS, NONE).
3. Review/revision/escalation dispatch details.

Problems:
- The prompt template is instructions to the main agent about how to construct a subagent. This is a skill doing an agent's job.
- Tool restrictions are prompt-based (`CRITICAL: You are READ-ONLY`), not infrastructure-enforced.
- Review dispatch is documented in the skill but never triggered automatically.

### V1 test results

| Test | Configuration | Result |
|------|--------------|--------|
| 1 | Haiku with Edit access, no guardrails | Edited status + 3 unrelated files |
| 2 | Haiku with Edit access, CRITICAL prohibition | Edited status again |
| 3 | Haiku with prompt-based read-only | Correct behavior, no edits |

Test 3 succeeded because the prompt worked, but the enforcement is fragile — it depends on the model following instructions rather than being unable to violate them.

## Proposed Solution

### Architecture: skill + agent separation

```
plugins/cdocs/
├── agents/
│   ├── triage.md              # Haiku agent: read-only frontmatter analysis
│   └── reviewer.md            # Opus/sonnet agent: structured document review
├── skills/
│   └── triage/SKILL.md        # Thin dispatcher: invokes triage agent, acts on report
└── ...
```

**Triage agent** (`agents/triage.md`): contains the analysis prompt (currently embedded in the skill). Registered with `tools: Read, Glob, Grep` — infrastructure-enforced read-only. Model: haiku.

**Reviewer agent** (`agents/reviewer.md`): contains the review prompt (currently in `skills/review/SKILL.md` but not usable by subagents since they don't inherit plugin context). Registered with appropriate tools. Model: sonnet (or configurable).

**Triage skill** (`skills/triage/SKILL.md`): becomes a thin orchestration layer:
1. Collect modified cdocs file paths.
2. Invoke the triage agent (not a raw Task subagent with an inline prompt).
3. Parse the triage report.
4. Apply field recommendations (tags, timestamps, missing fields).
5. Apply status recommendations the agent agrees with.
6. Dispatch workflow actions — including automatically invoking the reviewer agent for `[REVIEW]` recommendations.

### Triage agent definition

```yaml
---
name: triage
model: haiku
description: Analyze cdocs frontmatter accuracy and recommend workflow actions
tools: Read, Glob, Grep
---
```

Body: the current triage prompt template from SKILL.md (the "Your tasks" and "Output format" sections), cleaned up to remove the `CRITICAL: READ-ONLY` instructions (unnecessary when tools enforce it).

The `$FILES` variable is passed via the Task tool's prompt parameter when the skill invokes the agent.

### Reviewer agent definition

```yaml
---
name: reviewer
model: sonnet
description: Review cdocs documents with structured findings and verdicts
tools: Read, Glob, Grep, Write, Edit
---
```

Body: the review skill instructions (from `skills/review/SKILL.md`), the frontmatter spec, and writing conventions — all inlined. This solves Edge Case 4 from the v1 proposal (subagents don't inherit plugin context).

> NOTE(mjr/cdocs/haiku-subagent): The reviewer agent needs Write/Edit to create the review document and update the target's `last_reviewed` frontmatter. This is intentional — reviews are substantive work product, not mechanical bookkeeping.

The reviewer agent should use `AskUserQuestion` if it encounters ambiguity that needs human input, per mjr's note from v1.

### Automated review dispatch

The key missing piece from v1. When the triage skill receives a `[REVIEW]` recommendation:

1. The triage skill (running as the main agent) invokes the reviewer agent via Task tool, passing the document path.
2. The reviewer agent reads the document, writes the review to `cdocs/reviews/`, and updates `last_reviewed`.
3. On return, the triage skill re-runs triage on the review output to validate its frontmatter.
4. The main agent reports the verdict to the user.

This flow is **explicit in the skill's orchestration logic**, not merely documented as something the main agent might do.

### File scoping for triage

The user raised a concern: haiku edited files it wasn't asked to look at. With the agent abstraction, this is addressed at two levels:

1. **Tool restriction**: `tools: Read, Glob, Grep` — the agent literally cannot call Edit or Write. Even if haiku decides to "fix" something, the tool call will fail.
2. **Prompt scoping**: The `$FILES` list tells the agent which files to read. With no Edit capability, reading extra files is harmless — it just wastes tokens. The agent can only produce a report.

This makes the file scoping concern a cost/efficiency question rather than a safety question.

## Important Design Decisions

### Decision 1: Agent directory vs. inline Task prompts

**Decision:** Use `agents/` directory with formal agent definitions.

**Why:** This is the idiomatic Claude Code plugin pattern. Agents defined in `agents/` get:
- Infrastructure-enforced tool restrictions (not prompt-dependent).
- Discoverability in the `/agents` interface.
- Reusability across skills (the reviewer agent can be invoked by triage or directly by the user).
- Clear separation of concerns: the agent owns its instructions, the skill owns orchestration.

The v1 approach (skill containing an inline prompt template) conflates skill instructions with agent instructions, and relies on prompt-based safety rather than infrastructure-enforced safety.

### Decision 2: Separate triage and reviewer agents

**Decision:** Two agents — triage (haiku, read-only) and reviewer (sonnet, read-write).

**Why:** Different capability profiles:
- Triage is mechanical analysis: read files, check frontmatter, pattern-match. Haiku is sufficient. Read-only by design.
- Reviews require critical analysis, judgment, and document creation. Sonnet (or opus) is appropriate. Needs Write/Edit to produce the review.

Combining them into one agent would require either over-provisioning tools (giving the reviewer haiku's limitations) or over-provisioning model (giving triage sonnet's cost).

### Decision 3: Triage skill as thin dispatcher

**Decision:** The triage skill (`SKILL.md`) becomes orchestration-only — it invokes agents and applies results. It does not contain the triage agent's analysis instructions.

**Why:** Separation of concerns. The skill tells the main agent *when* and *how* to orchestrate. The agent definition tells the subagent *what* to analyze. Currently these are mixed: the skill contains both the orchestration instructions and the analysis prompt template.

### Decision 4: Reviewer agent gets inlined plugin context

**Decision:** The reviewer agent's markdown body includes the full review skill instructions, frontmatter spec, and writing conventions — inlined, not referenced.

**Why:** Subagents don't inherit plugin context (documented constraint). The v1 proposal identified this as Edge Case 4 and proposed inlining as the solution. The agent abstraction makes this clean: the agent definition is a self-contained document with everything the reviewer needs.

### Decision 5: Sonnet default for reviewer, not opus

**Decision:** Default the reviewer agent to sonnet.

**Why:** Reviews are critical analysis but don't require opus-level reasoning for most cdocs documents. Sonnet provides strong analytical capability at lower cost and latency. The user or main agent can override to opus for complex proposals where deeper analysis is warranted.

## Edge Cases / Challenging Scenarios

### 1. Agent registration fails or is not recognized

If the `agents/` directory isn't picked up by the plugin system, the triage skill would need a fallback to the v1 inline-prompt approach.

Mitigation: test agent registration as Phase 0 before restructuring. If registration fails, investigate plugin.json configuration. The v1 approach remains as a known-working fallback.

### 2. Reviewer agent creates low-quality reviews

With sonnet as default, reviews might miss nuances that opus would catch.

Mitigation: the triage skill can include a heuristic — use opus for proposals (higher-stakes documents) and sonnet for devlogs/reports. The agent definition can be model-agnostic with the skill selecting model at invocation time.

### 3. Triage agent reads extra files beyond $FILES

With read-only tools, this is harmless but wastes tokens. Haiku might Glob for related files or read referenced documents.

Mitigation: the agent prompt should explicitly state "Read ONLY the files listed below. Do not search for or read other files." This is now defense-in-depth rather than the sole safety mechanism.

### 4. Review dispatch in a busy session

The v1 implementation session showed concurrent tasks interfering with the review flow. The review skill used recency-based context rather than the intended subagent dispatch.

Mitigation: the reviewer agent runs in an isolated context (by definition — agents are separate processes). Concurrent main-agent tasks don't affect it. The skill's orchestration logic explicitly invokes the agent rather than relying on the main agent's judgment about when to review.

### 5. Agent definition maintenance

Two agents means two documents to maintain. If the frontmatter spec or writing conventions change, the reviewer agent's inlined context becomes stale.

Mitigation: document the dependency clearly. When frontmatter-spec.md or writing-conventions.md are updated, the reviewer agent should be updated too. A future enhancement could use file references if the agent system supports them.

## Test Plan

1. **Agent registration**: Add `agents/` directory with triage.md and reviewer.md, verify they appear in `/agents` interface.
2. **Tool enforcement**: Invoke triage agent, attempt to have it edit a file (it should fail at the infrastructure level, not the prompt level). Verify the Edit tool is not available.
3. **Triage accuracy**: Run triage agent against existing cdocs, compare output to v1 results. Should be identical or better (same prompt, now with enforced read-only).
4. **Review dispatch**: Create a document with `status: review_ready`, run triage, verify `[REVIEW]` recommendation triggers automatic reviewer agent invocation and produces a review document.
5. **End-to-end flow**: Author a proposal, run triage, verify automated review, verify review frontmatter is valid (re-triage the review).
6. **Concurrent session**: Run triage while other work is in progress, verify reviewer agent runs in isolation without context interference.
7. **Fallback**: If agent registration doesn't work, verify the v1 inline-prompt approach still functions.

## Implementation Phases

### Phase 0: Validate agent registration in plugins

1. Add `"agents": "./agents/"` to `plugins/cdocs/.claude-plugin/plugin.json`.
2. Create a minimal test agent (e.g., `agents/test.md` with `tools: Read` and a simple prompt).
3. Reinstall the plugin and verify the agent appears in `/agents`.
4. Invoke it and confirm tool restrictions are enforced.

**Success criteria:** A plugin-defined agent is discoverable and has infrastructure-enforced tool restrictions.

### Phase 1: Extract triage agent

1. Create `plugins/cdocs/agents/triage.md` with the triage analysis prompt (extracted from `skills/triage/SKILL.md`), `model: haiku`, `tools: Read, Glob, Grep`.
2. Refactor `skills/triage/SKILL.md` to be a thin dispatcher that invokes the triage agent and acts on results.
3. Remove the inline prompt template from the skill.
4. Test: invoke `/cdocs:triage`, verify it dispatches to the agent and produces correct output.

**Success criteria:** Triage agent is tool-restricted at infrastructure level. Skill is orchestration-only.

### Phase 2: Create reviewer agent

1. Create `plugins/cdocs/agents/reviewer.md` with inlined review instructions, frontmatter spec, and writing conventions. `model: sonnet`, tools include Read, Glob, Grep, Write, Edit.
2. Test: invoke the reviewer agent directly on a `review_ready` document, verify it produces a well-formed review.

**Success criteria:** Reviewer agent creates correct reviews without needing plugin context inheritance.

### Phase 3: Wire automated review dispatch

1. Update `skills/triage/SKILL.md` dispatch logic: on `[REVIEW]` recommendation, automatically invoke the reviewer agent.
2. Add re-triage step after review completes (validate review frontmatter).
3. Add user reporting of review verdict.
4. Test end-to-end: author -> triage -> auto-review -> re-triage -> report.

**Success criteria:** A `review_ready` document automatically gets reviewed when triage recommends it, without manual intervention.

### Phase 4: Documentation and cleanup

1. Update `rules/workflow-patterns.md` to reflect agent-based architecture.
2. Update CLAUDE.md if needed.
3. Clean up any v1 artifacts that are superseded.

**Success criteria:** Documentation matches implementation. No stale v1 references.
