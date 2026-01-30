---
first_authored:
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-29T16:00:00-08:00
last_reviewed:
  status: revision_requested
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-29T17:30:00-08:00
  round: 1
task_list: cdocs/haiku-subagent
type: proposal
state: live
status: review_ready
tags: [architecture, workflow_automation, subagent_patterns, plugin_idioms, triage]
---

# Triage v2: Formal Agent Abstraction and Automated Review Flow

> BLUF(mjr/cdocs/haiku-subagent): The v1 triage used a skill containing an inline prompt template for a read-only haiku subagent.
> Three problems: wrong abstraction (skill doing an agent's job), overly conservative safety (full read-only when the real issue was unrestricted tool access), and no automated review dispatch.
> Phase 0 validation confirmed that plugin agents support infrastructure-enforced tool allowlists, skills preloading, and model override, but agent-scoped hooks do not work.
> The v2 architecture uses formal agent definitions with tool allowlists (no Write/Bash for triage), the `skills` frontmatter field to inject review instructions into the reviewer agent (no inlining), and read-at-runtime for rules (no duplication).
> The triage agent applies mechanical fixes (tags, timestamps, missing fields) directly and reports status/workflow recommendations to a thin dispatcher skill.
> Edit scoping relies on prompt guidance rather than hooks, which is acceptable given the constrained tool surface.

## Objective

Three problems surfaced during v1 implementation and review:

1. **Wrong abstraction**: Triage is implemented as a skill containing a prompt template that the main agent manually passes to a Task subagent.
Plugins support a formal `agents/` directory where subagents are registered with explicit tool restrictions, model selection, and descriptions.
Using this mechanism makes triage a first-class agent rather than a prompt embedded in a skill.

2. **Overly conservative safety model**: V1 testing showed haiku ignoring explicit `CRITICAL: do not edit` instructions: modifying `status` fields and editing 3 unrelated files.
The v1 workaround (making the subagent fully read-only) is overly conservative: it forces the main agent to apply every mechanical edit, wasting top-level context on bookkeeping.
The real problem was giving haiku unrestricted tool access with no infrastructure guardrails.
Plugin agents enforce tool allowlists at the infrastructure level: a triage agent with `tools: Read, Glob, Grep, Edit` cannot call Write or Bash, limiting the blast radius.
File-level scoping relies on prompt guidance, which is acceptable when the tool surface is already constrained.

3. **Review automation is documented but not scaffolded**: The triage skill documents a `[REVIEW]` recommendation that should trigger a review subagent, but nothing automates the dispatch.
In the v1 session, concurrent tasks caused the review to use recency-based context rather than the intended subagent flow.

## Background

### Claude Code agent system (validated)

> NOTE(opus/cdocs/haiku-subagent): This section reflects empirical findings from Phase 0 validation.
> See `cdocs/devlogs/2026-01-29-phase0-agent-validation.md` for test methodology and evidence.

Plugins support an `agents/` directory discovered by convention at the plugin root.
No `plugin.json` field is needed (adding `"agents"` causes validation failure).
Agent definitions are markdown files with YAML frontmatter:

```yaml
---
name: triage
model: haiku
description: Analyze and fix cdocs frontmatter
tools: Read, Glob, Grep, Edit
skills:
  - cdocs:review
---

[Agent instructions as markdown body]
```

**Confirmed working** (Phase 0):
- **`tools`** (allowlist): enforced at infrastructure level. The agent cannot call tools outside its allowlist. Confirmed: agent with `tools: Read, Edit, Glob` could not access Bash or WebSearch.
- **`model`**: selects the agent's model. Confirmed: `model: haiku` dispatched to `claude-haiku-4-5-20251001`.
- **`skills`**: preloads skill content at startup. Full SKILL.md content is injected into the agent's system prompt. Confirmed: `skills: [cdocs:review]` caused agent to quote review instructions verbatim.
- **Agent naming**: agents are registered as `{plugin}:{agent}` (e.g., `cdocs:triage`) and available via Task tool `subagent_type`.
- **Auto-discovery**: the `agents/` directory is scanned automatically; no `plugin.json` manifest entry required.

**Confirmed not working** (Phase 0):
- **`hooks` in agent frontmatter**: agent-scoped PreToolUse/PostToolUse hooks are ignored. Debug logs show `Found 0 hook matchers in settings` when subagent calls tools. Hooks only load from `hooks/hooks.json` globally.
- **`--agent` CLI flag for plugin agents**: does not load the agent's system prompt or model. Only works for subagent dispatch via Task tool.

### Context inheritance constraints

Subagents do **not** inherit:
- Plugin rules from `rules/` (no `rules` field in the plugin spec).
- Skills from the parent conversation (must be explicitly listed in `skills` frontmatter).
- The full Claude Code system prompt.

Subagents **do** receive:
- Their own system prompt (the agent markdown body).
- Basic environment details (working directory).
- Preloaded skills (via `skills` frontmatter field: full content injected at startup).

This means rules like `frontmatter-spec.md` and `writing-conventions.md` must be provided to agents through:
1. **`skills` field**: reference existing skills that contain the information (confirmed working).
2. **Read at runtime**: the agent's system prompt instructs it to Read the rule files before starting work. Costs a tool call but eliminates duplication.

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
The real failure in tests 1-2 was that haiku had unrestricted tool access (Edit, Write, Bash) with no infrastructure guardrails.
The v2 approach constrains the tool surface (Edit only, no Write/Bash) and uses prompt guidance for file scoping.

## Proposed Solution

### Architecture: agent + skill separation

```
plugins/cdocs/
├── agents/
│   ├── triage.md              # Haiku: Edit for mechanical fixes, no Write/Bash
│   └── reviewer.md            # Sonnet: preloads review skill, Edit + Write for reviews
├── hooks/
│   ├── hooks.json             # Existing PostToolUse frontmatter validation (global)
│   └── cdocs-validate-frontmatter.sh
├── skills/
│   └── triage/SKILL.md        # Thin dispatcher: invokes agents, routes actions
└── rules/
    ├── frontmatter-spec.md    # Read at runtime by agents (not inlined)
    ├── writing-conventions.md # Read at runtime by agents (not inlined)
    └── workflow-patterns.md   # Updated to reflect agent architecture
```

**Two-layer enforcement:**

1. **Tool allowlist** (infrastructure): agents can only call tools in their `tools` list. The triage agent has `tools: Read, Glob, Grep, Edit` — no Write (cannot create files), no Bash (cannot run commands). This is enforced by the platform, not the prompt.
2. **Prompt guidance** (behavioral): the agent prompt specifies which files to triage and instructs it to edit only those files. If haiku edits a different file, the edit is constrained to the tool surface (Edit only) and the existing PostToolUse hook validates frontmatter integrity after every edit.

> NOTE(opus/cdocs/haiku-subagent): Agent-scoped PreToolUse hooks were planned as a third enforcement layer but Phase 0 confirmed they are not supported.
> Global hooks would restrict the main agent too, which is unacceptable.
> The two-layer model (tool allowlist + prompt guidance) is sufficient: the tool allowlist prevents the most dangerous actions (file creation, command execution), and prompt guidance scopes edits to target files.
> The existing global PostToolUse hook provides informational validation after edits.

### Triage agent definition

```yaml
---
name: triage
model: haiku
description: Analyze cdocs frontmatter and apply mechanical fixes
tools: Read, Glob, Grep, Edit
---
```

Body: the triage analysis prompt, restructured from v1.
The agent:

1. Reads `plugins/cdocs/rules/frontmatter-spec.md` (one Read call, no duplication).
2. Reads each target file.
3. **Applies mechanical fixes directly via Edit**: tags, timestamps, missing required fields.
4. **Reports** status transitions and workflow recommendations (these require orchestration context the agent doesn't have).

The split: mechanical fixes are applied by the agent, semantic decisions are reported to the dispatcher.

> NOTE(opus/cdocs/haiku-subagent): Tag analysis involves judgment, not pure determinism.
> Deciding whether a document about "hook enforcement" warrants tags like `hooks`, `enforcement`, or `security` requires content interpretation.
> This is accepted: incorrect tags on the right file are low-severity (easily noticed, easily reverted via git), and the alternative (reporting all tag changes to the dispatcher) wastes main-agent context on bookkeeping.
> The triage prompt instructs conservatism: "only change tags clearly supported by document content."

### Reviewer agent definition

```yaml
---
name: reviewer
model: sonnet
description: Review cdocs documents with structured findings and verdicts
tools: Read, Glob, Grep, Edit, Write
skills:
  - cdocs:review
---
```

Body: minimal instructions directing the agent to follow the preloaded review skill and read rules at runtime.
The `skills: [cdocs:review]` field injects the full review skill content at startup: no inlining, no duplication, automatically stays current when the skill is updated.

The agent reads `plugins/cdocs/rules/frontmatter-spec.md` and `plugins/cdocs/rules/writing-conventions.md` at runtime for domain context.

> NOTE(mjr/cdocs/haiku-subagent): The reviewer agent needs Write (to create the review document) and Edit (to update the target's `last_reviewed` frontmatter).

### Triage skill (thin dispatcher)

`skills/triage/SKILL.md` becomes orchestration-only:

1. Collect modified cdocs file paths (from `$ARGUMENTS` or recent Write/Edit operations).
2. Invoke the triage agent via Task tool with `subagent_type: "triage"`, passing the file list.
3. The agent applies mechanical fixes directly and returns a report with status/workflow recommendations.
4. The main agent (following dispatcher instructions) applies status recommendations it judges appropriate.
5. The main agent routes workflow actions:
   - `[REVIEW]` → invoke the reviewer agent via Task tool with `subagent_type: "reviewer"`, passing the document path.
   - `[REVISE]` → main agent revises per review action items.
   - `[ESCALATE]` → present options to the user.
   - `[STATUS]` → apply the recommended status change.
   - `[NONE]` → no action.
6. After review completes, re-triage the review document to validate its frontmatter (dispatched by the main agent, since agents cannot spawn subagents).

The skill contains **no agent instructions**: agents own their prompts, the skill owns orchestration.

### Automated review dispatch

When the triage report includes a `[REVIEW]` recommendation:

1. The main agent (following dispatcher instructions) invokes the reviewer agent via Task tool, passing the document path.
2. The reviewer agent (with preloaded review skill) reads the document, writes the review to `cdocs/reviews/`, and updates `last_reviewed`.
3. On return, the main agent re-runs triage on the review to validate its frontmatter.
4. The main agent reports the verdict to the user.

This flow is explicit in the skill's orchestration logic, not merely documented as something the main agent might do.

## Important Design Decisions

### Decision 1: Tool-constrained Edit, not read-only

**Decision:** Give the triage agent `tools: Read, Glob, Grep, Edit` — infrastructure-enforced tool allowlist with no Write or Bash.

**Why:** The v1 read-only approach was a blunt workaround for an unrestricted-tool-access problem.
The real issue in v1 tests was that haiku had access to Edit, Write, and Bash with no infrastructure constraints.
The tool allowlist addresses this at the right level: Edit is available (mechanical fixes can be applied directly), but Write (file creation) and Bash (command execution) are not.

File-level scoping (which specific files to edit) relies on prompt guidance.
This is acceptable because:
- The tool allowlist already prevents the most dangerous actions.
- Incorrect edits to cdocs documents are low-severity and easily reverted.
- The existing PostToolUse hook validates frontmatter after every edit.
- The alternative (read-only + dispatcher applies everything) wastes main-agent context on mechanical bookkeeping.

### Decision 2: `skills` field for context injection, not inlining

**Decision:** The reviewer agent uses `skills: [cdocs:review]` to preload review instructions. Rules are read at runtime via Read tool.

**Why:** Inlining skill content into agent definitions creates duplication that goes stale.
The `skills` frontmatter field injects full skill content at agent startup (confirmed in Phase 0): the agent gets the review methodology without any copy-paste.
When the review skill is updated, the reviewer agent automatically gets the new version.

For rules (`frontmatter-spec.md`, `writing-conventions.md`), agents read them at runtime.
This costs one Read call per rule file but eliminates all duplication.
The alternative (converting rules to skills) would work but misrepresents their nature: they're reference documents, not action instructions.

### Decision 3: Separate triage and reviewer agents

**Decision:** Two agents with different capability profiles.

**Why:**
- Triage is mechanical: read files, check frontmatter, apply fixes. Haiku is sufficient. Tools: Read, Glob, Grep, Edit.
- Reviews require critical analysis and document creation. Sonnet (or opus) is appropriate. Tools: Read, Glob, Grep, Edit, Write.

A third option (single agent with model selection at invocation time) was considered.
This was rejected because the tool profiles differ: triage should not have Write, and artificially removing Write at invocation time is not supported by the agent system (tool restrictions are defined in the agent frontmatter, not at dispatch time).

### Decision 4: Triage skill as thin dispatcher

**Decision:** The skill contains orchestration logic only. No agent instructions, no prompt templates.

**Why:** Separation of concerns.
The agent owns its prompt (what to analyze, how to fix).
The skill owns orchestration (when to invoke, how to route results).
V1 conflated these: the skill contained both dispatch logic and the full agent prompt.

### Decision 5: Sonnet default for reviewer

**Decision:** Default the reviewer agent to sonnet.

**Why:** Reviews require critical analysis but don't require opus-level reasoning for most documents.
For high-stakes documents (proposals), the dispatcher can note this in the Task prompt to encourage deeper analysis, though the model itself is fixed in the agent definition.

## Edge Cases / Challenging Scenarios

### 1. Triage agent edits wrong files

Haiku might edit cdocs files it wasn't asked to triage, repeating the v1 "3 unrelated files" issue.

The tool allowlist prevents Write (no new files) and Bash (no commands).
The prompt instructs the agent to "Edit ONLY the files listed below."
If haiku violates the prompt, the edits are constrained to existing files via Edit and the existing PostToolUse hook validates frontmatter after each edit.
The worst case: haiku applies a mechanical fix (tag, timestamp) to an untargeted cdocs file.
This is low-severity and easily noticed in commit diffs.

> NOTE(opus/cdocs/haiku-subagent): V1 Test 1 showed haiku modifying status fields and content on unrelated files, not just adding tags.
> The tool allowlist mitigates this: Edit can modify existing content but cannot create files or run commands.
> Status modifications to untargeted files would be visible in commit diffs and caught by the normal review process.

### 2. Triage agent applies incorrect mechanical fixes

Haiku might add wrong tags, set incorrect timestamps, or add fields with bad defaults.

Tag analysis involves content judgment (see Decision 1 NOTE).
The triage prompt instructs conservatism ("only change tags clearly supported by document content"), but errors will occur.
The existing PostToolUse hook validates field presence (not correctness).
Over time, the triage prompt can be refined based on observed errors.

### 3. Review dispatch in a busy session

V1 showed concurrent tasks interfering with review context.

The reviewer agent runs in an isolated context (separate process with its own system prompt, confirmed by Phase 0).
Concurrent main-agent tasks don't affect it.
The skill's explicit dispatch (Task tool invocation) replaces the implicit "main agent should decide to review."

### 4. Rules files change without agent awareness

Agents reading rules at runtime automatically get the new version. No maintenance action required.
The `skills` field also auto-resolves: if the review skill is updated, the reviewer agent gets the new content on next invocation.

### 5. Frontmatter spec adds new required fields

If the spec adds new required fields, the triage agent will start flagging (and potentially fixing) all existing documents.
This is correct behavior but could cause a burst of mechanical edits across many files.
The triage skill should be invoked on specific files, not on the entire corpus, to limit the scope of changes per invocation.

## Test Plan

1. **Triage agent creation**: Create `agents/triage.md`, verify it appears as `cdocs:triage` subagent type.
2. **Tool restriction**: Invoke triage agent, confirm it cannot call Write or Bash (infrastructure-enforced).
3. **Mechanical fixes**: Invoke triage agent on a cdocs file with a missing tag. Verify the agent applies the tag fix directly via Edit.
4. **Prompt scoping**: Invoke triage agent on file A with file B also present. Verify agent only edits file A (prompt-based).
5. **Skills preloading**: Invoke reviewer agent with `skills: [cdocs:review]`. Verify review methodology is available without inlining.
6. **Read-at-runtime**: Invoke triage agent, verify it reads `frontmatter-spec.md` before analyzing documents.
7. **Triage accuracy**: Run triage agent against existing cdocs, compare output to v1 results. Mechanical fixes should be applied directly; status/workflow should be reported.
8. **Review dispatch**: Run triage on a `review_ready` document, verify `[REVIEW]` recommendation triggers automatic reviewer agent invocation and produces a review document.
9. **End-to-end**: Author a proposal, run triage, verify auto-review, verify review frontmatter (re-triage).
10. **Concurrent isolation**: Run triage while other work is in progress, verify reviewer agent runs without context interference.

## Implementation Phases

> NOTE(opus/cdocs/haiku-subagent): Phase 0 (platform validation) is complete.
> Results are documented in `cdocs/devlogs/2026-01-29-phase0-agent-validation.md`.
> All required affordances work (agent registration, tool restriction, model override, skills preloading).
> Agent-scoped hooks do not work; the architecture has been adjusted accordingly.

### Phase 1: Create triage agent

1. Create `plugins/cdocs/agents/triage.md` with:
   - `model: haiku`, `tools: Read, Glob, Grep, Edit`
   - Body: triage analysis prompt (extracted and restructured from `skills/triage/SKILL.md`), with instructions to Read frontmatter spec at runtime and apply mechanical fixes directly.
2. Refactor `skills/triage/SKILL.md` to thin dispatcher: invoke triage agent via Task tool with `subagent_type: "triage"`, route results.
3. Test: invoke `/cdocs:triage` on existing cdocs, verify mechanical fixes applied by agent, status/workflow reported to dispatcher.

**Success criteria:** Triage agent applies mechanical fixes directly. Tool allowlist enforced at infrastructure level. Skill is orchestration-only.

### Phase 2: Create reviewer agent

1. Create `plugins/cdocs/agents/reviewer.md` with:
   - `model: sonnet`, `tools: Read, Glob, Grep, Edit, Write`
   - `skills: [cdocs:review]` (preloaded review instructions).
   - Body: minimal instructions to follow preloaded skill and read rules at runtime.
2. Test: invoke reviewer agent on a `review_ready` document, verify it produces a well-formed review without inlined context.

**Success criteria:** Reviewer agent creates correct reviews using preloaded skill and runtime-read rules. No inlined content in agent definition.

### Phase 3: Wire automated review dispatch

1. Update `skills/triage/SKILL.md` dispatch logic: on `[REVIEW]`, invoke reviewer agent via Task tool with `subagent_type: "reviewer"`.
2. Add re-triage step after review completes (dispatched by main agent).
3. Add user reporting of review verdict.
4. Test end-to-end: author -> triage -> auto-review -> re-triage -> report.

**Success criteria:** `review_ready` documents automatically get reviewed when triage recommends it, without manual intervention.

### Phase 4: Documentation and cleanup

1. Update `rules/workflow-patterns.md` to reflect agent-based architecture.
2. Update CLAUDE.md if needed.
3. Clean up v1 triage prompt template from skill (replaced by agent definition).
4. Clean up any stale references.

**Success criteria:** Documentation matches implementation. No stale v1 artifacts.
