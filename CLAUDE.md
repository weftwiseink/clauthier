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

Plugin internals (rules, skills, agents, hooks) are documented in their respective files.
The rules below are real `@`-imports (no code span), so sessions in this repo load the source rules directly; consuming projects get them through `/cdocs:init`.

- **Writing conventions** (BLUF, sentence-per-line, callouts, history-agnostic framing): @plugins/cdocs/rules/writing-conventions.md
- **Workflow patterns** (parallel investigation, loops and multi-phase plans, before review, completeness): @plugins/cdocs/rules/workflow-patterns.md
- **Orchestration discipline** (stay thin, resume from disk, one writer per file, verification and stuck loops, durable state, chat record, Bash output): @plugins/cdocs/rules/orchestration-discipline.md
- **Model tiering** (advisory: opus lead/judgment, sonnet search/explore, haiku mechanical; consumer policy wins): @plugins/cdocs/rules/model-tiering.md
- **Frontmatter spec**: @plugins/cdocs/rules/frontmatter-spec.md
- **Skills**: `plugins/cdocs/skills/<name>/SKILL.md` (ablate, devlog, full-send, implement, init, iterate, nit_fix, oversee, propose, propose-revise, report, review, rfp, status, triage)

Test the marketplace locally: `/plugin marketplace add .` then `/plugin install cdocs@clauthier`

### Rules Delivery

Rule files carry Claude Code guidance only; target-specific guidance is tracked in `cdocs/proposals/2026-10-06-target-specific-guidance-rfp.md`.

1. **`/cdocs:init` materialization** (primary): writes the rules into the consuming project as `.claude/rules/cdocs.md` (loaded by a CLAUDE.md `@`-import), plus `.opencode/rules/cdocs/*.md` and an inlined `AGENTS.md` block for other tools. Each carries a version + sha256 marker.
2. **SessionStart freshness hook** (`inject-rules.ts`): on a hash mismatch with the marker, a short directive to re-run `/cdocs:init` and `Read` the result; silent when uninitialized, fresh, or in this source repo. Interim until a plugin-native `rules` field ([#14200](https://github.com/anthropics/claude-code/issues/14200)).
3. **Agent fallback**: agents that read rules try `rules/*.md` beside the agent, then `plugins/cdocs/rules/*.md`.

See `plugins/cdocs/README.md` "Rules Integration" for details.

### Multi-Target Marketplace

The cdocs plugin publishes for both Claude Code and OpenCode from a single canonical source.
CC is the authoring format; a build script generates OC artifacts in `build/cdocs/opencode/`.

- **Build command**: `npm run build:cdocs`
- **Build script**: `scripts/build-opencode.ts`
- **Generated output**: `build/cdocs/opencode/` (gitignored, built on demand)
- **OC npm package**: `@weftwise/cdocs-opencode`
- **CI**: `.github/workflows/opencode-build.yml` builds, validates, and optionally publishes

See `plugins/cdocs/README.md` "OpenCode Installation" for user-facing docs.
