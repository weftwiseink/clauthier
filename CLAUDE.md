# Clauthier Development
> BLUF(mjr/setup-docs): Always create a devlog, value brevity and technical precision.

IMPORTANT: Always create a devlog.
IMPORTANT: Follow instructions here and read documentation carefully.
IMPORTANT: Your context window will be automatically compacted as it approaches its limit. Never stop tasks early due to token budget concerns. Always complete tasks fully, even if the end of your budget is approaching.

## Workflow

- Commit early and often using the "conventional commit" format.
  Each logical unit of work is its own commit; do not batch unrelated changes.
  A single feature, a single fix, a single doc cross-reference: each warrants its own commit.
  Frequent semantic commits make review, bisection, and revert cheap.
- Deduplicating code and docs with the same semantic content is highly desirable.

## Marketplace Structure

This repo is a Claude Code marketplace (`clauthier`) containing plugins under `plugins/`.
The CDocs plugin lives at `plugins/cdocs/` — see its [README](plugins/cdocs/README.md) for usage.

Plugin internals (rules, skills, agents, hooks) are documented in their respective files:

- **Writing conventions**: `@plugins/cdocs/rules/writing-conventions.md`
- **Workflow patterns** (parallel agents, subagent dev, checklists): `@plugins/cdocs/rules/workflow-patterns.md`
- **Frontmatter spec**: `@plugins/cdocs/rules/frontmatter-spec.md`
- **Skills**: `plugins/cdocs/skills/{devlog,propose,review,report,status,init,triage,implement,iterate}/SKILL.md`

Test the marketplace locally: `/plugin marketplace add .` then `/plugin install cdocs@clauthier`

### Cross-Target Rules Architecture

cdocs rules are delivered via three layers with graceful degradation:
1. **CC SessionStart hook** — injects rule content as `additionalContext` for marketplace installs (workaround for [#14200](https://github.com/anthropics/claude-code/issues/14200)).
2. **Agent relative paths** — agents try `rules/*.md` from their directory first, falling back to `plugins/cdocs/rules/*.md`.
3. **AGENTS.md** — cross-tool fallback at `plugins/cdocs/AGENTS.md` using `@`-imports; `/cdocs:init` creates project-level inlined version.

See `plugins/cdocs/README.md` "Rules Integration" for full details.

### Multi-Target Marketplace

The cdocs plugin publishes for both Claude Code and OpenCode from a single canonical source.
CC is the authoring format; a build script generates OC artifacts in `build/cdocs/opencode/`.

- **Build command**: `npm run build:cdocs`
- **Build script**: `scripts/build-opencode.ts`
- **Generated output**: `build/cdocs/opencode/` (gitignored, built on demand)
- **OC npm package**: `@weftwise/cdocs-opencode`
- **CI**: `.github/workflows/opencode-build.yml` builds, validates, and optionally publishes

See `plugins/cdocs/README.md` "OpenCode Installation" for user-facing docs.
