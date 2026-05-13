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

Three rule files ship with the plugin and are delivered to consuming projects via `/cdocs:init`:

- **`writing-conventions.md`:** BLUF, brevity, callout syntax, sentence-per-line, critical analysis, direct links for external references.
- **`workflow-patterns.md`:** Parallel agent dispatch, subagent-driven development, completeness checklists.
- **`frontmatter-spec.md`:** YAML frontmatter field definitions and valid values (scoped to `cdocs/**/*.md`).

### Rules Integration

Rule delivery is `/cdocs:init`-driven: the skill materializes rule content into the consuming project and standard `@`-imports load it on session start.

1. **`/cdocs:init` materialization** (primary path).
   `/cdocs:init` writes the rule content into the consuming project at three locations: `.claude/rules/cdocs.md` for Claude Code, `.opencode/rules/cdocs/*.md` for OpenCode, and an inlined section delimited by `<!-- cdocs-rules-start -->` / `<!-- cdocs-rules-end -->` in `AGENTS.md` for cross-tool fallback (Codex, Cursor, Copilot, Aider, and others).
   Each materialized file carries a marker comment naming the plugin version and a sha256 hash of the source rule content: `<!-- cdocs rules vX.Y.Z hash=<sha256> - regenerate with /cdocs:init ... -->`.
   The project's `CLAUDE.md` loads `.claude/rules/cdocs.md` via a standard `@`-import.
   This path uses canonical CC mechanics: no caps, no hook payload, no model-must-Read-an-injected-file dynamics.

2. **SessionStart freshness check** (freshness mechanism, not a content channel).
   The plugin's `inject-rules.ts` hook computes the plugin's current rule-content hash and compares it against the marker hash in `.claude/rules/cdocs.md`.
   - If the marker file does not exist, the hook exits silently: cdocs has not been initialized in this project, and the hook does not nag.
   - If the hashes match, the hook exits silently.
   - If the hashes differ, the hook emits a short `additionalContext` directive (under 500 bytes) telling the agent to run `/cdocs:init` and then `Read` the rewritten `.claude/rules/cdocs.md` so the session's working context picks up the fresh rules.
   - The hook also skips inside the cdocs source repo by grepping for `@plugins/cdocs/rules/` in the project's `CLAUDE.md`; rules in this repo come from the source paths directly.

3. **Read-after-write directive** (closes the in-session staleness window).
   When the agent runs `/cdocs:init`, the skill emits a final-line directive instructing the agent to `Read .claude/rules/cdocs.md` next.
   The `Read` tool result populates the session's context with the current rule content; the agent treats the read content as authoritative over the `@`-imported version baked into the system prompt at session start.

Hash-based comparison (rather than version-based) avoids spurious refresh nudges on version-only bumps where the rule content did not change.

### Known Limitations

The delivery path makes two empirical assumptions that future CC behavior could disturb:

- **Directive obedience.** The freshness hook's effect depends on the agent honoring an injected `<system-reminder>`-framed instruction to run `/cdocs:init` and then `Read` the rewritten file. Compliance is high in practice (verified end-to-end in [cdocs/devlogs/2026-05-12-rule-delivery-materialization-implementation.md](../../cdocs/devlogs/2026-05-12-rule-delivery-materialization-implementation.md)) but not guaranteed. If the agent ignores the directive, materialized rules remain stale and the user must run `/cdocs:init` manually.
- **Read-result authority.** Group C of the proposal's Test Plan validates that when the agent has both a stale `@`-imported copy and a freshly-`Read` copy of the rules in context, it answers rule questions from the freshly-`Read` content. This is empirically observed but is a model-attention property, not a framework guarantee.

Additional notes:

- **`/cdocs:init` is opt-in per project.** Projects that never run it get no rules at all; the freshness hook silently skips them. This is intentional: cdocs is workflow tooling, not a global default.
- **Migration trigger.** The "When CC #14200 Lands" subsection below sketches the path from this freshness-hook design to a plugin-native `rules` declaration in `plugin.json`. The freshness hook is a workaround for the current lack of always-on plugin context, not a permanent fixture.
- **First-time `/cdocs:init` Read overhead.** The Read-after-write directive fires on first-time init too. Harmless (no prior `@`-import to supersede) but costs one tool call.

### Cross-tool delivery

`/cdocs:init` handles the other CC-adjacent ecosystems in the same idempotent run:

- **OpenCode:** When `opencode.json` exists or a `.opencode/` directory is present, `/cdocs:init` creates `.opencode/rules/cdocs/` with rule copies enhanced with OC-specific frontmatter (`globs: ["cdocs/**/*.md"]`, `keywords: [...]`). These activate conditionally via the `opencode-rules` plugin.
- **AGENTS.md** (Codex, Cursor, Copilot, Aider, and others): `/cdocs:init` creates or updates a project-level AGENTS.md with inlined rule content between `<!-- cdocs-rules-start -->` / `<!-- cdocs-rules-end -->` markers for idempotent re-runs.

The `opencode-rules` plugin is not required: rules fall back to `.claude/rules/` (which OC reads natively) or AGENTS.md.

### Agent path resolution

Agents (`nit-fix`, `triage`, `reviewer`) try relative paths first (`rules/*.md` from the agent's directory), falling back to `plugins/cdocs/rules/*.md` for source-repo contexts.
This is experimental belt-and-suspenders alongside the `/cdocs:init` materialization path.

### When CC #14200 Lands

See "Known Limitations" above for the current constraint detail.

When Claude Code adds a `rules` field to `plugin.json` ([#14200](https://github.com/anthropics/claude-code/issues/14200)), the freshness hook and `/cdocs:init` materialization both become unnecessary: rules can ship directly via a single manifest declaration:

```json
{ "rules": "./rules" }
```

Migration: add the manifest field, delete `hooks/inject-rules.ts`, remove the `SessionStart` entry from `hooks.json`, and simplify `/cdocs:init` to skip the `.claude/rules/cdocs.md` materialization step (the OpenCode and AGENTS.md materialization paths remain since they handle non-CC tools).
The freshness hook and Read-after-write directive are workarounds for the current lack of always-on plugin context; the manifest approach restores `paths:` scoping and `/memory` visibility and removes both layers of model-instruction-following risk documented in Known Limitations.

## Hooks

- **SessionStart:** Hash-based freshness check. Compares the plugin's current rule-content sha256 against the marker in `.claude/rules/cdocs.md` and emits a refresh directive on mismatch. Silent skip in the source repo and in projects without `.claude/rules/cdocs.md`. See "Rules Integration" above.
- **PreToolUse (Write|Edit):** Restricts cdocs subagents (triage, nit-fix, reviewer) to editing only `cdocs/` document directories. Main session is unaffected. CC-only (OC lacks agent identity in events).
- **PostToolUse (Write|Edit):** Validates frontmatter on cdocs files. Informational warnings only (non-blocking).

### Sandbox testing notes

Future agents testing the hooks (especially the freshness check and the Read-after-write directive) need a sandboxed `CLAUDE_CONFIG_DIR` so the test does not pollute the maintainer's real `~/.claude/` state. Two non-obvious flags matter for `claude -p` against a sandbox:

- **`--plugin-dir <plugin_path>`** (e.g. `--plugin-dir /workspace/clauthier/main/plugins/cdocs`).
  A sandboxed `CLAUDE_CONFIG_DIR` inherits no marketplace state, so `/cdocs:*` skills do not resolve by default. Pass the plugin directory explicitly so the skills load.
- **`--permission-mode bypassPermissions`**.
  Sandbox CC has no permission allowlist; the agent's first `Write` tool call blocks otherwise. Use this only inside `mktemp -d` test sandboxes, never against real project state.
- **`~/.claude/.credentials.json` and `~/.claude/.claude.json` copies into the sandbox** so `claude -p` can authenticate. Documented in [cdocs/devlogs/2026-05-12-rule-delivery-regression-test.md](../../cdocs/devlogs/2026-05-12-rule-delivery-regression-test.md) as a known deviation; the alternative is "Not logged in - run /login" failures.
- **Do not pass `--bare`.** It skips hooks entirely and yields false-negative test results.

Reference recipe: [cdocs/devlogs/2026-05-12-rule-delivery-materialization-implementation.md](../../cdocs/devlogs/2026-05-12-rule-delivery-materialization-implementation.md) (Group C test setup).

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

## Releasing

Use `claude plugin tag` to cut a release tag.
It reads `plugins/cdocs/.claude-plugin/plugin.json`, validates that the enclosing `.claude-plugin/marketplace.json` entry agrees, and creates an annotated `cdocs--v{version}` git tag at HEAD.

### Workflow

1. Bump `version` in `plugins/cdocs/.claude-plugin/plugin.json` on a clean working tree and commit (conventional-commit style).
2. Dry-run from the repo root to confirm the tag the tool intends to create:

    ```bash
    claude plugin tag --dry-run plugins/cdocs
    ```

    Expected output: a `Plugin / Version / Marketplace entry / Tag` summary followed by `Dry run — would create tag cdocs--v{version}`.
3. Create the tag (still local-only):

    ```bash
    claude plugin tag plugins/cdocs
    ```
4. Push the tag when ready:

    ```bash
    claude plugin tag --push plugins/cdocs           # tag + push in one step
    # or, if the tag already exists locally:
    git push origin cdocs--v{version}
    ```

### Flags worth knowing

- `--dry-run` — print what would be tagged without creating it.
- `-m, --message <msg>` — override the default annotation (`%s` interpolates the version).
- `--push` — push the tag to `--remote` (default `origin`) after creating it.
- `--remote <name>` — push target for `--push`.
- `-f, --force` — skip the dirty-working-tree and tag-already-exists checks. Used in CI or to retag.

### Monorepo notes

- Always pass `plugins/cdocs` as the path; running `claude plugin tag` from the repo root with no argument errors out (`No plugin manifest found. Expected /…/.claude-plugin/plugin.json.`) because it looks for the plugin manifest at the working directory, not the enclosing marketplace.
- `claude plugin tag` is unconfused by the generated `build/cdocs/opencode/` output: the build directory contains a `package.json` but no `.claude-plugin/plugin.json`, so the tool resolves the canonical manifest under `plugins/cdocs/` without ambiguity.
- The OpenCode npm package version in `build/cdocs/opencode/package.json` is regenerated from `plugin.json` by `scripts/build-opencode.ts`, so bumping the plugin manifest version is sufficient to keep both targets in sync.
