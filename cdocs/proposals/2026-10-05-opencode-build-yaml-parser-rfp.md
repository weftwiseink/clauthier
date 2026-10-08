---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T14:12:19-07:00
task_list: build/opencode-yaml-frontmatter
type: proposal
state: live
status: evolved
tags: [build, opencode, yaml, frontmatter, multi-target]
---

# OpenCode Build: Real YAML Parser for Frontmatter

> BLUF(claude-opus-5-5/build-opencode-yaml-frontmatter): `scripts/build-opencode.ts` parses CC frontmatter with a hand-rolled line scanner that cannot handle YAML block scalars; `description: |` on `bash-runner.md` comes out empty in the generated OC agent. Replace the scanner with a real YAML parser.
> Motivated By: `cdocs/reviews/2026-10-05-review-of-bash-runner-maintainer-rewrite.md` (299394a), `cdocs/devlogs/2026-10-05-oversee-haiku-bash-wrapper.md`

> NOTE(opus-5-5/build/opencode-build-fixes): Evolved into [`2026-10-07-opencode-build-fixes.md`](2026-10-07-opencode-build-fixes.md), which resolves this RFP's scope and open questions.

## Objective

`parseFrontmatter` in `scripts/build-opencode.ts` (lines 130-161) reads CC agent/skill/rule frontmatter with a per-line regex state machine instead of a YAML library. It handles flat `key: value` pairs and one special-cased list (`skills:` plus `  - item` lines), but has no concept of YAML's actual grammar: block scalars (`|`, `>`), flow sequences (`[a, b]`), quoted strings, multiline folded text, or nested maps.

Confirmed broken: `plugins/cdocs/agents/bash-runner.md` frontmatter uses a `description: |` block scalar:

```yaml
description: |
  Run one expected-verbose shell command, capture its output to a scratch file, and return a fixed-format report without the raw output.
  Prompt with:
  - Exact or approximate command
  ...
```

`parseFrontmatter` matches `description: |` as a key/value pair with value `|`, then `generateOCFrontmatter` (line 172) writes it straight back out: `description: ${cc.description}`. The generated `build/cdocs/opencode/agents/bash-runner.md` has:

```yaml
description: |
mode: subagent
```

The entire block-scalar body is silently dropped — the continuation lines each fail the `kvMatch` regex (no top-level `key:`) and the list-match regex (requires `skills` context), so they are discarded with no warning. Claude Code's own frontmatter loader parses the same source file correctly; only the OC build is affected. The maintainer's review (`cdocs/reviews/2026-10-05-review-of-bash-runner-maintainer-rewrite.md`) flags this as a broken build, not a cosmetic gap, and wants an actual YAML parser used instead of continuing to patch the line scanner.

## Scope

The full proposal should resolve:

- **Parser choice.** `yaml` vs `js-yaml`, added only as a dependency of the build script (not shipped to either plugin's runtime). Compare maintenance activity, bundle/install cost for a dev-only dependency, and TypeScript type support.
- **Round-tripping.** Decide whether OC frontmatter generation should also move off hand-built `lines.push(...)` string assembly and onto the same YAML library's stringify/dump, or whether only parsing changes. Cover how each transformed field survives the round trip: `model` (alias expansion via `MODEL_MAP`), `tools` (string to boolean object plus `permission` block), `skills` (dropped field), and any block scalar or multiline `description`.
- **Audit of other hand-rolled parsing in `scripts/build-opencode.ts`.** Beyond `parseFrontmatter`, check for other ad hoc YAML handling — list items, quoted values, the `tools` string format — that a real parser would subsume or that needs to stay bespoke (e.g., `mapTools`'s own domain-specific transform, which is not frontmatter parsing per se).
- **Regression coverage.** A test or CI check that parses every agent, skill, and rule's CC frontmatter and the generated OC frontmatter for the same file, and compares the fields that should round-trip. Decide where this lives (unit test in the build script's test suite vs. a CI step in `.github/workflows/opencode-build.yml`) and what it asserts for fields that are intentionally dropped or transformed.
- **Interaction with `cdocs/proposals/2026-10-05-opencode-model-mapping-rfp.md`.** That RFP also touches `MODEL_MAP` and `generateOCFrontmatter`. Decide sequencing: land the YAML-parser swap first (since it changes how `cc.model` is read) or land model-mapping fixes first, and whether either proposal should fold the other's scope in.
- **Published package rebuild.** Whether `@weftwise/cdocs-opencode` has already published artifacts built with the broken parser, and if so, whether this fix requires a version bump and republish independent of other pending OC build changes.

## Open Questions

- Does switching the parser change the shape of `CCFrontmatter` or `generateOCFrontmatter`'s output for any currently-correct field, risking a regression in fields that work today?
- Should the regression check (comparing CC and OC frontmatter) be a blocking CI gate on every PR touching `plugins/cdocs/{agents,skills,rules}/**` or `scripts/build-opencode.ts`, or an on-demand script?
- Are there other frontmatter fields across existing agents/skills/rules that use YAML features (flow sequences, anchors, multiline folded `>`) not yet exercised by `bash-runner.md`, that should be added as fixtures for the regression check?
