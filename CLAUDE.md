# CDocs Plugin Development
> BLUF(mjr/setup-docs): Always create a devlog, value brevity and technical precision.

IMPORTANT: Always create a devlog.
IMPORTANT: Follow instructions here and read documentation carefully.
IMPORTANT: Your context window will be automatically compacted as it approaches its limit. Never stop tasks early due to token budget concerns. Always complete tasks fully, even if the end of your budget is approaching.

## Workflow

- Commit regularly using the "conventional commit" format.
- Deduplicating code and docs with the same semantic content is highly desirable.

## CDocs Plugin

This repo is a Claude Code plugin.
Writing conventions, workflow patterns, frontmatter spec, and doc-type guidelines are in plugin components:

- **Writing conventions**: `@rules/writing_conventions.md`
- **Workflow patterns** (parallel agents, subagent dev, checklists): `@rules/workflow_patterns.md`
- **Frontmatter spec**: `@rules/frontmatter_spec.md`
- **Skills**: `skills/{devlog,propose,review,report,status,init}/SKILL.md`

Test the plugin locally: `claude --plugin-dir .`
