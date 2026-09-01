---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-01T09:10:00-08:00
task_list: cdocs/agent-frontmatter-marketplace
type: devlog
state: live
status: done
tags: [subagent, frontmatter, marketplace, best-practices, full-send]
---

# Agent Frontmatter & Marketplace Metadata Adoption: Devlog

## Objective

Full-send (propose-revise -> iterate) a scoped adoption of two Claude-Code best practices for the cdocs plugin:

1. Add `color` / `maxTurns` (and selective `memory: project`) to the four cdocs agents
   (`triage`, `nit-fix`, `reviewer`, `judge`). Withhold `memory` from `reviewer` and `judge`
   to preserve the "fresh eyes, no prior commitment" invariant.
2. Add marketplace `category` / `tags` metadata where the schema supports it.

Out of scope (DEFERRED, do not touch): codex support, non-CC/OpenCode packaging.

Branch: `cdocs/agent-frontmatter-marketplace` (isolated worktree).

## Verification

### `jq` JSON validity

```
$ jq . .claude-plugin/marketplace.json
{
  "$schema": "https://json.schemastore.org/claude-code-marketplace.json",
  "name": "clauthier",
  "owner": { "name": "weft" },
  "metadata": {
    "description": "Claude Code plugin marketplace by weft",
    "version": "0.1.0"
  },
  "plugins": [
    {
      "name": "cdocs",
      "source": "./plugins/cdocs",
      "description": "Documentation framework for structured devlogs, proposals, reviews, and reports",
      "category": "productivity",
      "tags": ["documentation", "devlog", "proposal", "review", "workflow", "subagents"]
    }
  ]
}

$ jq . plugins/cdocs/.claude-plugin/plugin.json
{
  "$schema": "https://json.schemastore.org/claude-code-plugin-manifest.json",
  "name": "cdocs",
  "description": "Documentation framework for organizing development work with structured devlogs, proposals, reviews, and reports.",
  "version": "0.1.0",
  "keywords": ["documentation", "devlog", "proposal", "review", "workflow", "subagents"],
  "author": { "name": "weft" },
  "repository": "https://github.com/weftwiseink/clauthier",
  "license": "MIT"
}
```

Both files parse cleanly; `tags` sits on the per-plugin entry (not top-level/`metadata`), `keywords` sits at top level, matching the schema split verified in the proposal.

### Agent frontmatter (manual re-read + parse)

All four blocks re-read directly: flat scalar keys, no nesting except `reviewer`'s pre-existing `skills:` list, `maxTurns: 10` unquoted integer with correct camelCase key.

```
--- triage ---
name: triage
model: haiku
description: Analyze cdocs frontmatter and apply mechanical fixes
tools: Read, Glob, Grep, Edit
color: green
memory: project

--- nit-fix ---
name: nit-fix
model: haiku
description: Enforce writing conventions on cdocs documents
tools: Read, Glob, Grep, Edit
color: yellow
memory: project

--- reviewer ---
name: reviewer
model: opus
description: Review cdocs documents with structured findings and verdicts
tools: "*"
skills:
  - cdocs:review
color: purple

--- judge ---
name: judge
model: opus
description: Assess implement-review loop meta-health and return continue, rotate-implementer, or escalate with a written rationale
tools: Read, Glob, Grep, Write
color: red
maxTurns: 10
```

### OpenCode build (`npm run build:cdocs`)

```
> build:cdocs
> tsx scripts/build-opencode.ts cdocs

build-opencode: Starting CC-to-OC conversion for plugin "cdocs"...
  Repo root:   .../agent-ad4e508c2da65f781
  Plugin root: .../agent-ad4e508c2da65f781/plugins/cdocs
  Output dir:  .../agent-ad4e508c2da65f781/build/cdocs/opencode
  Version:     0.1.0

  Converting 4 agents...
    judge.md
    nit-fix.md
    reviewer.md
  Warning: Unknown CC tool ""*"" — skipping
    triage.md

  Copying skills...
  Copying rules...
  Copying hand-written OC files...
  Copied OC hooks plugin: cdocs-hooks.ts
  Copied postinstall script: postinstall.js
  Generating package.json...

build-opencode: Done.
  Agents converted: 4
  Output: .../agent-ad4e508c2da65f781/build/cdocs/opencode
```

Build succeeds. The `"Unknown CC tool \"*\"" ` warning is pre-existing behavior for `reviewer`'s `tools: "*"` and unrelated to this change.

Inspected the generated OC frontmatter for all four agents: `color`, `maxTurns`, and `memory` are absent from every one, confirming `generateOCFrontmatter`'s fixed allowlist (`description`, `mode`, `model`, `tools`, `skills`) drops them by design — no build breakage, no accidental parity, freshness invariant trivially holds on OC too (no agent gets `memory`).

```
--- OC judge ---
description: Assess implement-review loop meta-health and return continue, rotate-implementer, or escalate with a written rationale
mode: subagent
model: anthropic/claude-opus-4-20250514
tools: {read: true, edit: false, write: true, bash: false}
permission: {write: ask}

--- OC nit-fix ---
description: Enforce writing conventions on cdocs documents
mode: subagent
model: anthropic/claude-3-5-haiku-20241022
tools: {read: true, edit: true, write: false, bash: false}
permission: {edit: ask}

--- OC reviewer ---
description: Review cdocs documents with structured findings and verdicts
mode: subagent
model: anthropic/claude-opus-4-20250514
tools: {read: false, edit: false, write: false, bash: false}

--- OC triage ---
description: Analyze cdocs frontmatter and apply mechanical fixes
mode: subagent
model: anthropic/claude-3-5-haiku-20241022
tools: {read: true, edit: true, write: false, bash: false}
permission: {edit: ask}
```

### CI-equivalent checks (`.github/workflows/opencode-build.yml`, replicated locally)

Frontmatter delimiter/required-field check against all 4 generated OC agents:

```
Validating: build/cdocs/opencode/agents/judge.md
  OK
Validating: build/cdocs/opencode/agents/nit-fix.md
  OK
Validating: build/cdocs/opencode/agents/reviewer.md
  OK
Validating: build/cdocs/opencode/agents/triage.md
  OK
```

`npm pack --dry-run` in `build/cdocs/opencode`: succeeded, 29 files, 35.9 kB tarball, no errors.

No other plugin-validation/lint script exists in `package.json` beyond `build`/`build:cdocs`; no other CI workflow references plugin content.

### Not run

`/plugin marketplace add .` / `/plugin install cdocs@clauthier` round-trip: this requires an interactive CC session against the worktree and was not run in this non-interactive agent session. All static checks (JSON schema shape, YAML frontmatter shape, OC build, CI-equivalent script) pass; this is the one verification step from the proposal's methodology left to a human or CC-session follow-up.: field support (gating research)

### Subagent frontmatter fields (source: https://code.claude.com/docs/en/sub-agents.md)

All three target fields are REAL and currently supported:

| field | supported | type / values |
|---|---|---|
| `color` | YES | one of: red, blue, green, yellow, purple, orange, pink, cyan |
| `maxTurns` | YES | integer (camelCase — NOT `max_turns`); marks output partial when hit |
| `memory` | YES | one of: `user`, `project`, `local` |

Full supported optional set includes: tools, disallowedTools, model, permissionMode, maxTurns,
skills, mcpServers, hooks, memory, background, effort, isolation, color, initialPrompt, experimental.
Note: plugin subagents cannot use `hooks`, `mcpServers`, or `permissionMode`.

### Marketplace / plugin manifest fields

Verified against schemastore draft-07 schemas (generated 2026-04-23), both `additionalProperties`-lenient:

- **marketplace.json** per-plugin entry: `category` (string, no enum) and `tags`
  (array of strings, no enum) both valid. `category: "productivity"` already present; `tags` can be ADDED.
  Neither `category` nor `tags` is valid at top-level or in `metadata`.
- **plugin.json** (plugin-manifest) top-level: `category` ABSENT, `tags` ABSENT — NOT valid.
  `keywords` (array of strings, no enum) IS valid top-level. So the manifest gets `keywords`,
  NOT category/tags. Dropped: `category`/`tags` on plugin.json (unsupported by schema).

## Plan

- Turn 0: research/verify fields (done for subagents; schema pending).
- Propose-revise loop: dispatch proposer -> reviewer until accept.
- Iterate loop: dispatch implementer -> reviewer (-> judge) until accept.
- Verify final YAML/JSON validity; commit per logical unit.

## Testing Approach

No automated test suite covers agent frontmatter or manifest content directly.
Verification is: (1) direct inspection of frontmatter blocks for valid, flat YAML with correct key casing;
(2) `jq .` parsing of both JSON manifests; (3) running the actual multi-target build (`npm run build:cdocs`)
and inspecting its generated output; (4) replicating the CI workflow's (`opencode-build.yml`) frontmatter
and `npm pack --dry-run` checks locally against the build output.

## Implementation Notes

- Colors assigned: `triage`=green, `nit-fix`=yellow, `reviewer`=purple, `judge`=red — all four distinct, all in-enum.
- `maxTurns` lands only on `judge` (`10`); `triage`/`nit-fix`/`reviewer` stay uncapped per the (reaffirmed) round-1 design.
  A mid-session attempt to raise `triage`/`nit-fix` to `maxTurns: 60` was made, then explicitly reverted after an
  overseer course-correction restored the original "omit for corpus-scaled batch work" principle — the proposal
  and implementation both reflect the omitted state, not the 60 draft.
- `memory: project` added to `triage`/`nit-fix` only; withheld from `reviewer`/`judge` to preserve the `/cdocs:iterate`
  freshness invariant (see proposal's "Important Design Decisions").
- All four agent edits are purely additive: no existing frontmatter key or body content was touched.
- `tags`/`keywords` term lists are identical across `marketplace.json` and `plugin.json` by design.

## Changes Made

| File | Description |
|------|-------------|
| `cdocs/proposals/2026-09-01-agent-frontmatter-marketplace-metadata.md` | Round-2 revision: closed all 5 round-1 review action items; `last_reviewed` bumped to round 2 / accepted; `status: implementation_ready`. |
| `plugins/cdocs/agents/triage.md` | Add `color: green`, `memory: project`. |
| `plugins/cdocs/agents/nit-fix.md` | Add `color: yellow`, `memory: project`. |
| `plugins/cdocs/agents/reviewer.md` | Add `color: purple`. |
| `plugins/cdocs/agents/judge.md` | Add `color: red`, `maxTurns: 10`. |
| `.claude-plugin/marketplace.json` | Add `tags` array to the cdocs per-plugin entry. |
| `plugins/cdocs/.claude-plugin/plugin.json` | Add `keywords` array at top level. |

## Iteration Log

| iteration | implementer | reviewer | review_verdict | review_proof | review_path | notes |
|---|---|---|---|---|---|---|
| 1 | impl-1 (fork/full-send) | rev-1 (cdocs:reviewer) | revise | confirmed | cdocs/reviews/2026-09-01-review-of-agent-frontmatter-marketplace-metadata.md | Revise (light): 5 non-blocking findings, all reconciled in round 2 (see notes below); no factual claim was wrong. |
| 2 | impl-1 (light-revision, same session) | n/a (directive-driven acceptance, no fresh reviewer dispatched) | accepted | confirmed | cdocs/proposals/2026-09-01-agent-frontmatter-marketplace-metadata.md (`last_reviewed`) | Round-1 action items applied directly (see "Round-1 action items closed" below) rather than through a fresh `/cdocs:iterate` reviewer dispatch; the overseer accepted the round-2 diff and directed implementation to proceed. |

## Judge Log

| judge_iteration | trigger | verdict | rationale | judge_path |
|---|---|---|---|---|

(Not applicable: this session executed a directed light-revision + implementation pass rather than a full `/cdocs:iterate` loop, so no judge dispatch occurred.)

## Round-1 action items closed

1. `maxTurns`/batch-mode tension (`triage`/`nit-fix`): resolved by extending the reviewer's own "a cap that bites is worse than no cap" argument to both batch agents — left uncapped (matches the field table's original `(omitted)` value; a mid-session `maxTurns: 60` draft was tried and then explicitly reverted per overseer course-correction before implementation).
2. OpenCode-build verification: added to Verification Methodology; `npm run build:cdocs` run and confirmed clean (see Verification below).
3. Minimum-CC-version note: already present in the Background NOTE (v2.1.246+ for `maxTurns` partial-marking; harmless degradation on older CC), tightened for clarity.
4. Background NOTE tightened to distinguish `tags`/`keywords` as explicitly DECLARED schema properties from fields that would merely survive `additionalProperties` leniency.
5. `$schema`/schemastore references converted to direct HTTP links; two incidental semicolons split into separate sentences.
