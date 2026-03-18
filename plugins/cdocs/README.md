# CDocs
Circumlocutory Docs:
A Claude Code plugin for structured development process docs.

CDocs provides skills, rules, and hooks for creating and managing devlogs, proposals, reviews, and reports with consistent formatting, frontmatter metadata, and writing conventions.

> NOTE(mjr): This plugin currently has a few loose workflows but nothing is rigidly codified or reliable.
> Not yet for general consumption, although IDK if folks/orgs should really be using process plugins like this they didn't write themselves anyhow

## Installation

Project level recommended:
```bash
claude plugin marketplace add weftwiseink/clauthier
claude plugin install cdocs@clauthier --scope project
```

## Quick Start

```
/cdocs:init              # Scaffold cdocs/ in your project
/cdocs:devlog my_feature # Create a devlog (also auto-created by Claude)
/cdocs:propose my_topic  # Author a design proposal
/cdocs:review path/to/doc.md  # Review a document
/cdocs:report my_topic   # Generate a report
/cdocs:status            # List all docs with metadata
/cdocs:status --type=proposal --status=wip  # Filter docs
```

## Skills

| Skill | Description |
|-------|-------------|
| `/cdocs:init` | Scaffold `cdocs/` directory structure in a project |
| `/cdocs:devlog` | Create a development log |
| `/cdocs:propose` | Author a design proposal with structured sections |
| `/cdocs:review` | Review a document with findings and verdict |
| `/cdocs:report` | Generate a report (status, investigation, incident, audit, retrospective) |
| `/cdocs:status` | Query and manage document metadata |

Any skill can be invoked by the user or auto-invoked by Claude depending on context.
Devlogs are most commonly auto-invoked; proposals, reviews, and reports are typically user-requested.

## Rules

Loaded automatically when the plugin is active:

- **`writing-conventions.md`:** BLUF, brevity, callout syntax, sentence-per-line, critical analysis.
- **`workflow-patterns.md`:** Parallel agent dispatch, subagent-driven development, completeness checklists.
- **`frontmatter-spec.md`:** YAML frontmatter field definitions and valid values (scoped to `cdocs/**/*.md`).

### Rules Integration

Rules are delivered via three complementary layers with graceful degradation:

1. **CC SessionStart hook** (external installs): A `SessionStart` hook reads all `rules/*.md` files from the plugin directory, strips YAML frontmatter, and injects the combined content as `additionalContext` at session start.
   This is the primary delivery mechanism for CC marketplace installs where `@`-imports in CLAUDE.md cannot resolve plugin-cache paths.
   The hook skips injection in the source repo (where rules are already loaded via CLAUDE.md `@`-imports) by grepping for `@plugins/cdocs/rules/` in the project's CLAUDE.md.
   This detection is best-effort: if imports are restructured, the hook may inject duplicate rules, causing slightly larger context but no incorrect behavior.

2. **Agent path resolution**: Agents (nit-fix, triage, reviewer) try relative paths first (`rules/*.md` from the agent's directory), falling back to `plugins/cdocs/rules/*.md` for source-repo contexts.
   This is experimental belt-and-suspenders alongside the SessionStart hook.

3. **AGENTS.md cross-tool fallback**: The plugin includes an `AGENTS.md` with `@`-imports for the three rule files.
   CC follows the imports; other agent tools (OpenCode, Codex, Cursor, Copilot, Aider, and 17+ others) read the file directly.
   For tools that do not follow `@`-imports, `/cdocs:init` creates a project-level AGENTS.md with inlined rule content.

### Rules in OpenCode

When `/cdocs:init` detects an OpenCode project (via `opencode.json` or `.opencode/` directory), it additionally:

- Creates `.opencode/rules/cdocs/` with rule copies enhanced with OC-specific frontmatter (`globs: ["cdocs/**/*.md"]`, `keywords: ["cdocs", "cdocs devlog", ...]`).
  These activate conditionally via the `opencode-rules` plugin, loading only when editing cdocs files or mentioning cdocs-specific terms.
- Creates or updates the project AGENTS.md with inlined rule content delimited by `<!-- cdocs-rules-start -->` / `<!-- cdocs-rules-end -->` markers for idempotent re-runs.

The `opencode-rules` plugin is not required: rules fall back to `.claude/rules/` (which OC reads natively) or AGENTS.md.

### When CC #14200 Lands

When Claude Code adds a `rules` field to `plugin.json` ([#14200](https://github.com/anthropics/claude-code/issues/14200)), the SessionStart hook can be replaced with a single manifest declaration:

```json
{ "rules": "./rules" }
```

Migration: add the manifest field, delete `hooks/inject-rules.sh`, remove the `SessionStart` entry from `hooks.json`.
The hook was designed as a temporary workaround; the manifest approach restores `paths:` scoping and `/memory` visibility.

## Hooks

- **SessionStart:** Injects rule file content as `additionalContext` for CC external installs. Skips injection in the source repo. See "Rules Integration" above.
- **PreToolUse (Write|Edit):** Restricts cdocs subagents (triage, nit-fix, reviewer) to editing only `cdocs/` document directories. Main session is unaffected. CC-only (OC lacks agent identity in events).
- **PostToolUse (Write|Edit):** Validates frontmatter on cdocs files. Informational warnings only (non-blocking).

## OpenCode Installation

CDocs is also available for [OpenCode](https://opencode.ai) via an npm package.

### Install via npm

```bash
npm install @weftwise/cdocs-opencode
```

The postinstall script copies skills and rules to project paths automatically.
Set `CDOCS_SKIP_POSTINSTALL=1` to skip the copy step.

Then add the plugin to your `opencode.json`:

```json
{
  "plugin": ["@weftwise/cdocs-opencode"]
}
```

### Alternative: compound-engineering

Users who prefer to deploy CC plugins directly to their OC config directory (`~/.config/opencode/`) can use [compound-engineering-plugin](https://github.com/every-env/compound-plugin) as a user-side install tool.

### What works in OpenCode

| Feature | OC Support | Notes |
|---------|-----------|-------|
| Skills | Full | All 10 skills work as-is via `.opencode/skills/` or `.claude/skills/` |
| Rules | Full | Loaded via `.claude/rules/` (OC reads this natively) |
| Agents | Full | 3 agents converted to OC frontmatter format |
| Hooks (frontmatter validation) | Full | Ported as `tool.execute.after` handler in TypeScript |
| Hooks (path restriction) | Not available | OC events lack agent identity; cannot scope to cdocs subagents |
| Hooks (rule injection) | Not needed | OC reads `.claude/rules/` natively |

### Building OC artifacts from source

Build output lives in `build/cdocs/opencode/` (gitignored, not committed).
To build after modifying CC source files:

```bash
npm run build:cdocs
# or: npx tsx scripts/build-opencode.ts
```

The build script (`scripts/build-opencode.ts`):
- Converts CC agent frontmatter to OC format (model mapping, tool expansion, permission generation)
- Copies skills and rules into the build output for npm packaging
- Copies hand-written OC files (`plugins/cdocs/hooks/cdocs-hooks.ts`, `plugins/cdocs/scripts/postinstall.js`)
- Syncs the version from `.claude-plugin/plugin.json` to the output `package.json`
- Cleans the output directory before each build for a fresh slate
- Accepts a plugin name argument (default: `cdocs`) for multi-plugin support
- Auto-discovers new agents: adding a `.md` file to `agents/` and rebuilding produces a corresponding OC agent

## Document Types

| Type | Directory | Purpose |
|------|-----------|---------|
| Devlog | `cdocs/devlogs/` | Working logs of development sessions |
| Proposal | `cdocs/proposals/` | Design and solution specifications |
| Review | `cdocs/reviews/` | Structured document reviews with verdicts |
| Report | `cdocs/reports/` | Audience-facing findings and analysis |

All documents use `YYYY-MM-DD-dash-case.md` naming and require YAML frontmatter.
