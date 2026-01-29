---
first_authored:
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-29T12:00:00-08:00
task_list: cdocs/plugin_architecture
type: proposal
state: live
status: review_ready
last_reviewed:
  status: revision_requested
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-29T12:30:00-08:00
  round: 1
tags: [architecture, claude_skills, plugin, future_work]
---

# CDocs Plugin Architecture

> BLUF: Package CDocs as a Claude Code plugin with six skills, shared rules, and a validation hook.
> Any skill can be invoked by the user or auto-invoked by Claude depending on context.
> The "always create a devlog" directive stays as a rule (the trigger); the devlog skill provides the scaffolding (the mechanism).
> Existing README guidelines are absorbed into skills, but `init` generates lightweight READMEs in each `cdocs/` subdir for plugin-less discoverability.
> v1 distribution: git clone + `claude --plugin-dir`.
> Key sources: Claude Code plugin spec (`.claude-plugin/plugin.json`, skills, hooks, rules), existing `cdocs/` READMEs, `cdocs_plan.md`.

## Objective

Transform the current CDocs repo (a collection of markdown guidelines and directory scaffolding copied from a project) into a distributable Claude Code plugin.
The plugin should encode document creation workflows, writing conventions, and formatting enforcement so that any project can adopt CDocs by installing the plugin and running `/cdoc:init`.

## Background

**Current state:**
The repo contains a `cdocs/` directory with READMEs specifying devlog and proposal formats, a `CLAUDE.md` with project-wide writing and workflow directives, and a `cdocs_plan.md` with design notes and future work items.
No skills, hooks, or plugin manifest exist yet.

**Claude Code extension points used by this proposal:**

| Mechanism | Role in CDocs |
|-----------|---------------|
| Plugin manifest (`.claude-plugin/plugin.json`) | Distribution unit, versioning |
| Skills (`skills/<name>/SKILL.md`) | Document creation and management commands |
| Rules (`rules/*.md`) | Ambient writing conventions, workflow patterns, frontmatter spec |
| Hooks (`hooks/hooks.json`) | Formatting validation on cdocs writes |
| MCP server (future) | Doc-as-database querying |

## Proposed Solution

### Plugin Layout

```
cdocs/                                  # repo root = plugin root
├── .claude-plugin/
│   └── plugin.json                     # manifest
├── skills/
│   ├── devlog/
│   │   ├── SKILL.md                    # creation workflow + guidelines
│   │   └── template.md                 # frontmatter + section scaffold
│   ├── propose/
│   │   ├── SKILL.md
│   │   └── template.md
│   ├── review/
│   │   ├── SKILL.md
│   │   └── template.md
│   ├── report/
│   │   ├── SKILL.md
│   │   └── template.md
│   ├── status/
│   │   └── SKILL.md                    # query/update doc metadata
│   └── init/
│       └── SKILL.md                    # scaffold cdocs in a project
├── hooks/
│   ├── hooks.json                      # PostToolUse validation
│   └── cdocs_validate_frontmatter.sh   # validation script
├── rules/
│   ├── writing_conventions.md          # BLUF, brevity, NOTE/TODO/WARN (unscoped)
│   ├── workflow_patterns.md            # parallel agents, subagent dev, checklists (unscoped)
│   └── frontmatter_spec.md            # field definitions + enums (scoped to cdocs/)
├── cdocs/                              # plugin's own dev docs (dogfooding)
│   ├── devlogs/
│   ├── proposals/
│   ├── reviews/
│   ├── reports/
│   └── _media/
├── CLAUDE.md                           # plugin dev instructions (slimmed)
├── README.md
└── LICENSE
```

The `cdocs/` directory at repo root is the plugin's own development documentation (dogfooding).
It does not conflict with plugin component discovery, which only scans `skills/`, `hooks/`, and `rules/` under the plugin root.

### Distribution and Installation

**v1 flow (pre-marketplace):**

```bash
# Clone the plugin repo
git clone https://github.com/weftwiseink/cdocs ~/.claude/cdocs-plugin

# Option A: Per-session (development/evaluation)
claude --plugin-dir ~/.claude/cdocs-plugin

# Option B: Enable in user settings (~/.claude/settings.json)
# Add: "enabledPlugins": { "cdoc": true }
# With plugin path configured

# Option C: Vendor into project (no external dependency)
cp -r ~/.claude/cdocs-plugin/.claude-plugin .claude-plugin
cp -r ~/.claude/cdocs-plugin/skills .claude/skills  # loses namespacing
cp -r ~/.claude/cdocs-plugin/rules .claude/rules
```

Option A or B is recommended.
Option C loses `/cdoc:` namespacing (skills become `/devlog`, `/propose`, etc.) but works without plugin infrastructure.

**Future:** Marketplace distribution via `marketplace.json` entry once the plugin stabilizes.

### Skills

Any skill can be invoked by the user or auto-invoked by Claude depending on context.
Expected usage patterns:

- `/cdoc:devlog`: Most commonly auto-invoked by Claude when starting substantive work (triggered by the "always create a devlog" rule). User can also invoke directly.
- `/cdoc:propose`: Typically user-invoked when a design needs specification. Claude may suggest it when scoping complex work.
- `/cdoc:review`: Typically user-invoked. Claude may suggest it when a document reaches `review_ready`.
- `/cdoc:report`: Typically user-invoked after research or analysis. Claude may suggest it after completing investigative work.
- `/cdoc:status`: User-invoked for doc inventory. Claude may auto-invoke to check document state.
- `/cdoc:init`: User-invoked to scaffold a new project.

#### `/cdoc:devlog`: Create a development log

- **User-invocable:** yes
- **Argument hint:** `[feature_name]`
- **Expected usage:** Most commonly auto-invoked by Claude. The `rules/writing_conventions.md` rule contains the "always create a devlog when starting substantive work" directive. This rule is the *trigger*; the skill is the *mechanism*. The user can also invoke `/cdoc:devlog feature_name` directly.
- **Behavior:**
  1. Determine date and feature name (from arg or prompt).
  2. Create `cdocs/devlogs/YYYY-MM-DD_feature_name.md` with frontmatter and section scaffold from `template.md`.
  3. Set `first_authored.by` to current model, `first_authored.at` to current timestamp with TZ.
  4. Set `status: wip`, `state: live`.
  5. Return context instructing Claude to update the devlog as work proceeds (single source of truth).
- **Skill instructions absorb:** `cdocs/devlogs/README.md` content (structure, best practices, verification requirements, debugging phases).

#### `/cdoc:propose`: Author a proposal

- **User-invocable:** yes
- **Argument hint:** `[topic]`
- **Behavior:**
  1. Create `cdocs/proposals/YYYY-MM-DD_topic.md` with frontmatter and required sections.
  2. Embed the author checklist.
  3. Guide Claude through BLUF-first drafting, design decisions, implementation phases.
- **Skill instructions absorb:** `cdocs/proposals/README.md` content (required sections, implementation phase guidance, author checklist).

#### `/cdoc:review`: Review a document

- **User-invocable:** yes
- **Argument hint:** `<path_to_document>`
- **Expected usage:** Typically user-invoked. Claude may suggest a review when a document reaches `review_ready`.
- **Behavior:**
  1. Read the target document.
  2. Create `cdocs/reviews/YYYY-MM-DD_review_of_{doc_name}.md`.
  3. Set `review_of` frontmatter to the target path.
  4. Structure: summary assessment, section-by-section findings, verdict (accept/revise/reject), action items.
  5. Update target doc's `last_reviewed` field.

> NOTE(claude-opus-4-5/plugin_architecture): Review structure needs research.
> The current repo has no review README.
> Phase 3 includes researching best practices for structured document reviews in Claude-assisted workflows.
> Initial structure above is a reasonable starting point, but should be validated.

#### `/cdoc:report`: Generate a report

- **User-invocable:** yes
- **Argument hint:** `[topic]`
- **Behavior:**
  1. Create `cdocs/reports/YYYY-MM-DD_topic.md` with frontmatter.
  2. Reports are more flexible than other types: they summarize findings, status, or analysis.
  3. Structure: BLUF, scope, findings/analysis, conclusions, recommendations.

> NOTE(claude-opus-4-5/plugin_architecture): Report structure also needs research.
> Reports likely vary more than other types (status report vs. analysis report vs. audit).
> Phase 3 includes researching report taxonomies and deciding whether subtypes warrant separate templates.

#### `/cdoc:status`: Query and manage documents

- **User-invocable:** yes
- **Argument hint:** `[filter]`
- **Expected usage:** User-invoked for doc inventory. Claude may auto-invoke to check state.
- **Behavior:**
  1. Scan `cdocs/` for all `.md` files (excluding READMEs).
  2. Parse frontmatter from each.
  3. Display summary table: filename, type, state, status, last_reviewed, tags.
  4. Accept filters: by type, state, status, tag.
  5. Optionally update a document's state/status when given a path and new value.
- **Allowed tools:** `Glob`, `Read`, `Edit`.
- **This is the lightweight "docs as DB" interface** referenced in `cdocs_plan.md`.
  A future MCP server could replace or augment this with richer queries.
- **Scaling note:** This approach reads every cdocs file to parse frontmatter.
  Practical up to ~100 documents.
  For larger corpora, a frontmatter index file (`cdocs/.index.json`) maintained by the PostToolUse hook would avoid repeated full scans.
  Alternatively, promote the MCP server timeline if this becomes a bottleneck.

#### `/cdoc:init`: Scaffold CDocs in a project

- **User-invocable:** yes
- **Argument hint:** `[--minimal]`
- **Behavior:**
  1. Create directory structure: `cdocs/{devlogs,proposals,reviews,reports,_media}/`.
  2. Generate lightweight READMEs in each subdir with format summaries and a reference to the full skill (e.g., "See `/cdoc:propose` for complete authoring guidelines"). These serve as fallback documentation for non-plugin users and GitHub readers.
  3. Create a `.claude/rules/cdocs.md` rule file with core CDocs writing conventions, or append a CDocs section to the project's `CLAUDE.md`.
  4. Optionally enable the cdocs plugin in `.claude/settings.json`.
  5. `--minimal` flag skips rule file and README creation (bare directory structure only).

### Rules (Ambient Context)

Rules are loaded automatically when the plugin is active.
They provide ambient guidance without requiring explicit skill invocation.

#### `rules/writing_conventions.md` (unscoped)

No `paths` restriction - applies to all files and communication.

Extracted from current `CLAUDE.md` "High-level Communication notes" and "Documentation Updates" sections:
- BLUF convention (when, how)
- Brevity and communicative efficiency
- Sentence-or-thought-per-line formatting
- NOTE(author/workstream), TODO(), WARN() callout syntax
- History-agnostic present-tense framing
- Decouple commentary from technical content
- Critical and detached analysis over false validation
- "Always create a devlog when starting substantive work" directive

#### `rules/workflow_patterns.md` (unscoped)

No `paths` restriction - applies to all work sessions.

Extracted from current `CLAUDE.md` workflow sections:
- Dispatching parallel agents (when, how, documentation requirements)
- Subagent-driven development (5+ task threshold, criteria, anti-patterns)
- Final checklist review (completeness, clarity, deviation surfacing)

These are general workflow patterns, not type-specific.
They apply during any substantive work, not just when authoring a particular doc type.

#### `rules/frontmatter_spec.md` (scoped to `cdocs/**/*.md`)

```yaml
---
paths:
  - "cdocs/**/*.md"
---
```

Scoped so the frontmatter schema only loads into context when working on cdocs documents.

Extracted from `cdocs_plan.md` "frontmatter" section:
- Full field definitions with types and enums
- Required vs optional fields per document type
- `first_authored.by` format (model name or `@user`)
- `first_authored.at` format (ISO 8601 with TZ)
- `task_list` namespacing convention
- `status` valid transitions per type
- `last_reviewed` structure and review round tracking
- `tags` conventions per type

### Hooks

#### PostToolUse: Frontmatter validation

```json
{
  "PostToolUse": [
    {
      "matcher": "Write|Edit",
      "hooks": [
        {
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/hooks/cdocs_validate_frontmatter.sh",
          "timeout": 5
        }
      ]
    }
  ]
}
```

**Script location:** `hooks/cdocs_validate_frontmatter.sh` in the plugin directory, resolved via `${CLAUDE_PLUGIN_ROOT}`.

**Implementation:** Bash script with lightweight YAML parsing (regex-based extraction of frontmatter delimiters and required field names - no external YAML parser dependency).
Full schema validation is out of scope for the hook - the script checks for presence of required fields, not value correctness.

**Behavior:**
- Reads `tool_input.file_path` from stdin JSON.
- Exits immediately (code 0, no output) if path does not match `cdocs/**/*.md`.
- Reads the file from disk, extracts the YAML frontmatter block.
- Checks for required fields (`first_authored`, `type`, `state`, `status`).
- On missing fields: exits 0 with JSON `additionalContext` warning.
- Does NOT block writes (informational only), avoiding disrupting workflow.

> NOTE(claude-opus-4-5/plugin_architecture): The markdown formatting automation (table alignment, diagram padding) mentioned in `cdocs_plan.md` is deferred to future work.
> It's a non-trivial text processing task that deserves its own proposal.

### CLAUDE.md Slimming

The current `CLAUDE.md` contains content that should migrate into plugin components:

| Current CLAUDE.md Section | Destination |
|---------------------------|-------------|
| "Devlog Format" | `skills/devlog/SKILL.md` |
| "Documentation Updates" | `rules/writing_conventions.md` |
| "High-level Communication notes" | `rules/writing_conventions.md` |
| "Dispatching Parallel Agents" | `rules/workflow_patterns.md` |
| "Subagent-Driven Development" | `rules/workflow_patterns.md` |
| "Final Checklist Review" | `rules/workflow_patterns.md` |
| "Workflow" (conventional commits) | Stays in `CLAUDE.md` (project-specific, not CDocs) |
| "Guidelines" (dedup) | `rules/writing_conventions.md` |
| "Always create a devlog" directive | `rules/writing_conventions.md` |

Post-migration, `CLAUDE.md` retains only:
- Plugin development workflow (conventional commits, etc.)
- Reference to CDocs plugin for guidelines (`@rules/writing_conventions.md`)
- Any project-specific directives not covered by the plugin

## Important Design Decisions

### Plugin vs. bare skills

**Decision:** Full plugin (`.claude-plugin/plugin.json`).

**Why:** A plugin gives us namespaced skills (`/cdoc:devlog` vs `/devlog`), bundled hooks and rules, a versioned manifest for distribution, and a clean boundary between CDocs concerns and project concerns.
Bare skills in `.claude/skills/` would work for single-project use but don't distribute.

### Skills absorb READMEs; init generates fallback READMEs

**Decision:** Canonical guidelines move into `SKILL.md` files. The `init` skill generates lightweight READMEs in each `cdocs/` subdir.

**Why:** The current READMEs serve as instructions for Claude, which is exactly what `SKILL.md` files do.
Keeping both creates duplication and drift risk.
However, removing READMEs entirely makes `cdocs/` opaque to non-plugin users, GitHub readers, and team members without the plugin.
The `init`-generated READMEs provide a minimal fallback: format summary + pointer to the skill.
These are project artifacts, not plugin source, so they don't create a maintenance burden.

### Rules for conventions vs. embedding in each skill

**Decision:** Shared rules files for cross-cutting conventions.

**Why:** Writing conventions, workflow patterns, and frontmatter specs apply to all doc types.
Duplicating them in each skill's `SKILL.md` violates the deduplication guideline.
Rules are loaded as ambient context, so skills can reference them implicitly.

### General workflow patterns as rules, not type-specific skills

**Decision:** Parallel agent dispatch, subagent-driven development, and completion checklists go into `rules/workflow_patterns.md`, not into individual skills.

**Why:** These are general workflow patterns.
You dispatch parallel agents when debugging across subsystems, not when writing a devlog.
You use subagent-driven development for any complex plan, not just proposals.
Embedding them in type-specific skills means they only load during skill invocation, losing their general applicability.

### Informational hooks vs. blocking hooks

**Decision:** PostToolUse hooks are informational (warn, don't block).

**Why:** Blocking on frontmatter issues mid-workflow would be disruptive.
A warning in context lets Claude self-correct without interrupting the user.
Future: could add a `PreToolUse` blocking hook for CI/review workflows if needed.

### "Always create a devlog" enforcement

**Decision:** Encode as a rule (ambient reminder), not a hard hook.

**Why:** A `SessionStart` hook that forces devlog creation would be too aggressive, since not every session needs one (e.g., quick status checks, reviews).
The rule makes it a strong convention that Claude follows by default but that can be overridden by context.
The devlog skill is the mechanism Claude uses when the rule triggers.

### Status skill vs. MCP server for doc queries

**Decision:** Start with a skill - evolve to MCP later.

**Why:** A skill using `Glob`+`Read` is sufficient for scanning a `cdocs/` directory up to ~100 documents.
An MCP server adds operational complexity (process management, transport) that isn't justified until the query interface needs to be richer (cross-repo queries, full-text search, aggregation) or the corpus exceeds the skill's practical limits.
The skill establishes the UX - the MCP server can replace it transparently later.

## Unaccounted-for Process Conventions

The following conventions are likely in use but not yet codified.
They should be captured during implementation and may warrant additional skills or rule content.

1. **Template prompts for proposals and reviews:** The user likely has conversational patterns for requesting these. Could become skill argument presets or prompt templates.
2. **Review workflow state machine:** Request review -> conduct review -> revision cycle -> accept. The `last_reviewed` field tracks this, but the workflow isn't encoded anywhere.
3. **Devlog-as-session-anchor:** Convention of creating/opening a devlog at session start and updating throughout. Documented in the devlog skill's invocation model section.
4. **Media management:** Screenshot capture, naming (`YYYY-MM-DD_description.png`), embedding. Currently manual - could be partially automated.
5. **Task list <-> frontmatter connection:** How `task_list` in frontmatter relates to Claude's task tracking system. Needs specification.
6. **Document state transitions:** Valid transitions (e.g., `wip` -> `review_ready` -> `done`) are implied but not enforced. Could be a validation hook.
7. **Cross-document references:** Proposals spawning sub-proposals, devlogs referencing proposals. No linking convention exists.
8. **Conventional commit integration:** Commits that correspond to doc state changes (e.g., committing a devlog with the work it documents).

## Edge Cases / Challenging Scenarios

1. **Multiple devlogs per day:** Naming collision when the same feature name is used twice on the same date. Mitigation: append a sequence number or require distinct names.
2. **Plugin active but no `cdocs/` directory:** Skills should detect this and prompt `init`, not fail silently.
3. **Frontmatter drift across doc types:** Different types have different valid statuses. The frontmatter spec must be type-aware, and the validation hook must dispatch accordingly.
4. **Plugin dogfooding:** The plugin repo itself uses CDocs for its own development. The plugin's own `cdocs/` does not conflict with plugin component discovery, which only scans `skills/`, `hooks/`, and `rules/`.
5. **Rule conflicts with project CLAUDE.md:** If a project has its own writing conventions that conflict with CDocs rules, the project's rules win. Claude Code's loading precedence is: project scope > plugin scope, so project `CLAUDE.md` and `.claude/rules/` override plugin-provided rules.
6. **Review of a review:** Technically valid (reviewing a review document). The review skill should handle `review_of` pointing to any doc type, including reviews.
7. **Plugin-less usage:** Team members without the plugin see `init`-generated READMEs in `cdocs/` subdirs. These provide format guidance and can be followed manually. Full skill automation requires the plugin.
8. **Status skill at scale:** Beyond ~100 documents, Glob+Read becomes expensive. Mitigation path: frontmatter index file or MCP server (see Status skill section).

## Test Plan

Testing is primarily manual/interactive given the skill-based nature:

1. **Skill invocation:** For each skill, verify it creates a correctly named file with valid frontmatter and complete section scaffolding.
2. **Devlog auto-invocation:** Start a substantive task without explicitly invoking `/cdoc:devlog` -> verify Claude creates one automatically.
3. **Frontmatter validation hook:** Write a cdocs file with missing frontmatter -> verify warning appears in context. Write a non-cdocs file -> verify no warning.
4. **Status skill:** Create several docs with varied states -> verify status output is accurate and filterable.
5. **Init skill:** Run in a clean directory -> verify full scaffolding and READMEs created. Run in a directory with existing `cdocs/` -> verify no destructive overwrites.
6. **Rule loading:** Verify writing conventions appear for all work (unscoped). Verify frontmatter spec only appears when editing cdocs files (scoped).
7. **Cross-skill consistency:** Create a devlog and a proposal -> verify both follow the same frontmatter spec and writing conventions.
8. **Plugin development testing:** Use `claude --plugin-dir .` from the repo root to test during development.
9. **Fallback READMEs:** Disable the plugin and verify `cdocs/` subdirs contain usable format documentation.

## Implementation Phases

### Phase 1: Foundation (plugin skeleton + rules + init)

- Create `.claude-plugin/plugin.json` manifest.
- Write `rules/writing_conventions.md` (extracted from CLAUDE.md).
- Write `rules/workflow_patterns.md` (extracted from CLAUDE.md).
- Write `rules/frontmatter_spec.md` with `paths: ["cdocs/**/*.md"]` scoping (extracted from `cdocs_plan.md`).
- Implement `skills/init/SKILL.md` with directory scaffolding and README generation.
- **Success criteria:** `claude --plugin-dir .` loads the plugin. Rules appear in ambient context. `/cdoc:init` creates the directory structure with READMEs in a test project.
- **Constraints:** Do not modify existing `cdocs/` content or CLAUDE.md yet.

### Phase 2: Core skills (devlog + proposal)

- Write `skills/devlog/SKILL.md` absorbing `cdocs/devlogs/README.md`. Include invocation model, template, best practices, verification requirements, debugging phases.
- Write `skills/devlog/template.md` with frontmatter and section scaffold.
- Write `skills/propose/SKILL.md` absorbing `cdocs/proposals/README.md`. Include author checklist, implementation phase guidance.
- Write `skills/propose/template.md`.
- **Success criteria:** `/cdoc:devlog my_feature` creates a well-formed devlog. `/cdoc:propose my_topic` creates a well-formed proposal. Starting substantive work without explicit invocation triggers devlog auto-creation.
- **Depends on:** Phase 1 (plugin structure and frontmatter spec exist).
- **Parallel-safe:** Devlog and proposal skills can be developed concurrently.

### Phase 3: Research skills (review + report)

- Research best practices for structured document reviews in Claude-assisted workflows.
- Define review structure, verdict categories, action item format, multi-round workflow.
- Write `skills/review/SKILL.md` and `skills/review/template.md`.
- Implement `review_of` frontmatter linkage and `last_reviewed` update on target doc.
- Research report taxonomies (status, analysis, audit, summary).
- Decide whether subtypes warrant separate templates or a single flexible template.
- Write `skills/report/SKILL.md` and `skills/report/template.md`.
- **Success criteria:** `/cdoc:review path/to/doc.md` creates a linked review and updates the target. `/cdoc:report my_topic` creates a well-formed report.
- **Depends on:** Phase 1.
- **Research needed:** Review structure, verdict taxonomy, report subtypes, level of structure vs. flexibility.

### Phase 4: Management, hooks, and cleanup

- Write `skills/status/SKILL.md` with Glob+Read-based doc scanning, filtering, and inline updates.
- Write `hooks/hooks.json` and `hooks/cdocs_validate_frontmatter.sh` (bash, regex-based YAML field detection, no external dependencies).
- Slim the repo's `CLAUDE.md` by removing content that migrated to rules and skills.
- Remove the original `cdocs/devlogs/README.md` and `cdocs/proposals/README.md` (absorbed into skills).
- Write `README.md` with installation and usage instructions.
- Dogfood: verify all skills, hooks, and rules work together via `claude --plugin-dir .`.
- **Success criteria:** `/cdoc:status` shows accurate doc inventory with filtering. Frontmatter validation hook warns on missing fields. No duplicated content between CLAUDE.md, skills, and rules. Plugin README documents all skills and installation options.
- **Depends on:** Phases 2 and 3 (all skills exist before cleanup removes READMEs).

## Recommended Claude Tasks

```
cdocs/plugin_architecture                          # top-level workstream
cdocs/plugin_architecture/foundation               # Phase 1: skeleton + rules + init
cdocs/plugin_architecture/core_skills              # Phase 2: devlog + proposal
cdocs/plugin_architecture/research_skills          # Phase 3: review + report (research)
cdocs/plugin_architecture/management_cleanup       # Phase 4: status + hooks + migration + docs
```

Phases 2 and 3 can run in parallel once Phase 1 is complete.

## Future Work (Out of Scope)

These items from `cdocs_plan.md` are acknowledged but deferred:

- **Markdown formatting automation:** Table alignment, diagram padding. Deserves its own proposal, likely a `prettier` plugin or custom formatter invoked via hook.
- **MCP server for doc queries:** Replaces/augments the `status` skill with richer capabilities (cross-repo, full-text search, aggregation). Warranted when the skill UX proves limiting or the corpus exceeds ~100 docs.
- **Plugin marketplace distribution:** Package for a marketplace once the plugin stabilizes. Requires `marketplace.json` entry and possibly a separate hosting repo.
- **Metadata/taxonomy extension mechanism:** A way to overlay new conventions or fields experimentally before integrating them permanently. Could be a `rules/` override pattern.
- **Template prompt library:** Capture common conversational patterns for requesting docs (e.g., "review this proposal focusing on architecture"). Could become skill argument presets.
- **Frontmatter index file:** `cdocs/.index.json` maintained by hooks to accelerate status queries at scale.
