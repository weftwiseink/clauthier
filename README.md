# CDocs

A Claude Code plugin for structured development documentation.

CDocs provides skills, rules, and hooks for creating and managing devlogs, proposals, reviews, and reports with consistent formatting, frontmatter metadata, and writing conventions.

## Installation

```bash
# Clone the plugin
git clone https://github.com/weftwiseink/cdocs ~/.claude/cdocs-plugin

# Option A: Per-session
claude --plugin-dir ~/.claude/cdocs-plugin

# Option B: Enable in user settings (~/.claude/settings.json)
# "enabledPlugins": { "cdoc": true }
```

## Quick Start

```
/cdoc:init              # Scaffold cdocs/ in your project
/cdoc:devlog my_feature # Create a devlog (also auto-created by Claude)
/cdoc:propose my_topic # Author a design proposal
/cdoc:review path/to/doc.md  # Review a document
/cdoc:report my_topic   # Generate a report
/cdoc:status            # List all docs with metadata
/cdoc:status --type=proposal --status=wip  # Filter docs
```

## Skills

| Skill | Description |
|-------|-------------|
| `/cdoc:init` | Scaffold `cdocs/` directory structure in a project |
| `/cdoc:devlog` | Create a development log |
| `/cdoc:propose` | Author a design proposal with structured sections |
| `/cdoc:review` | Review a document with findings and verdict |
| `/cdoc:report` | Generate a report (status, investigation, incident, audit, retrospective) |
| `/cdoc:status` | Query and manage document metadata |

Any skill can be invoked by the user or auto-invoked by Claude depending on context.
Devlogs are most commonly auto-invoked; proposals, reviews, and reports are typically user-requested.

## Rules

Loaded automatically when the plugin is active:

- **`writing_conventions.md`:** BLUF, brevity, callout syntax, sentence-per-line, critical analysis.
- **`workflow_patterns.md`:** Parallel agent dispatch, subagent-driven development, completeness checklists.
- **`frontmatter_spec.md`:** YAML frontmatter field definitions and valid values (scoped to `cdocs/**/*.md`).

## Hooks

- **PostToolUse (Write|Edit):** Validates frontmatter on cdocs files. Informational warnings only (non-blocking).

## Document Types

| Type | Directory | Purpose |
|------|-----------|---------|
| Devlog | `cdocs/devlogs/` | Working logs of development sessions |
| Proposal | `cdocs/proposals/` | Design and solution specifications |
| Review | `cdocs/reviews/` | Structured document reviews with verdicts |
| Report | `cdocs/reports/` | Audience-facing findings and analysis |

All documents use `YYYY-MM-DD_snake_case.md` naming and require YAML frontmatter.

## License

MIT
