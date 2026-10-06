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

## Local Checkout: Bare Repo with Sibling Worktrees

This repo is checked out as a bare repo with sibling worktrees, not a single working copy.
The typical layout:

```
/workspace/clauthier/        (or equivalent on host)
├── .bare/                    bare git repository (config has `bare = true`)
└── main/                     default worktree, checked out on branch `main`
```

Additional worktrees live as siblings of `main/` (paths like `/workspace/clauthier/<branch>/`) or under `main/.claude/worktrees/<name>/` when created via the `EnterWorktree` harness tool.

Consequences worth remembering:

- Untracked files in one worktree are NOT visible in sibling worktrees.
  When a new worktree needs files that exist as untracked in `main/` (drafts, proposals not yet committed), copy them in explicitly before the new worktree session can see them.
- `git status` is per-worktree; `git log` and history are shared via the bare repo.
- The bare repo itself is not a working copy; you do not edit files or run application commands inside `.bare/`.
- To merge a worktree branch back into main: from the `main/` directory, run `git merge --ff-only <worktree-branch>`.
  If the source worktree imported files that already exist as untracked copies in `main/`, remove the untracked copies first or `git` will refuse to fast-forward.

## Marketplace Structure

This repo is a Claude Code marketplace (`clauthier`) containing plugins under `plugins/`.
The CDocs plugin lives at `plugins/cdocs/` — see its [README](plugins/cdocs/README.md) for usage.

Plugin internals (rules, skills, agents, hooks) are documented in their respective files:

- **Writing conventions**: `@plugins/cdocs/rules/writing-conventions.md`
- **Workflow patterns** (parallel agents, subagent dev, checklists): `@plugins/cdocs/rules/workflow-patterns.md`
- **Orchestration discipline** (stay thin, resume from disk, one writer per file, verification floor, durable state, chat record): `@plugins/cdocs/rules/orchestration-discipline.md`
- **Model tiering** (advisory tiers: opus lead/judgment, sonnet search/explore, haiku mechanical; consumer floor wins): `@plugins/cdocs/rules/model-tiering.md`
- **Frontmatter spec**: `@plugins/cdocs/rules/frontmatter-spec.md`
- **Skills**: `plugins/cdocs/skills/{devlog,propose,review,report,status,init,triage,implement,iterate,oversee}/SKILL.md`

Test the marketplace locally: `/plugin marketplace add .` then `/plugin install cdocs@clauthier`

### Cross-Target Rules Architecture

cdocs rules are delivered `/cdocs:init`-first, with graceful degradation:
1. **`/cdocs:init` materialization** (primary) — writes rule content into the consuming project: `.claude/rules/cdocs.md` (loaded via CC `@`-import), `.opencode/rules/cdocs/*.md` (OpenCode), and an inlined block in `AGENTS.md` (cross-tool: Codex, Cursor, Copilot, Aider). Each carries a version + sha256 marker.
   Rule files carry Claude Code guidance only; target-specific guidance is tracked in `cdocs/proposals/2026-10-06-target-specific-guidance-rfp.md`.
2. **CC SessionStart freshness hook** (`inject-rules.ts`) — compares the plugin's rule-content hash to the materialized marker; on mismatch emits a short (<500B) `additionalContext` directive to re-run `/cdocs:init` and `Read` the result. It is a freshness nudge, not a content channel: silent when uninitialized or fresh. Interim workaround pending a plugin-native `rules` field ([#14200](https://github.com/anthropics/claude-code/issues/14200)).
3. **Agent relative paths** — agents try `rules/*.md` from their directory first, falling back to `plugins/cdocs/rules/*.md`.

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
