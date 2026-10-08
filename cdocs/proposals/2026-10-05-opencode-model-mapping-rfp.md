---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T10:33:29-07:00
task_list: build/opencode-model-mapping
type: proposal
state: live
status: evolved
tags: [build, opencode, models, multi-target]
---

# OpenCode Build Model Mapping

> BLUF(opus-5-5/build/opencode-model-mapping): The OpenCode build pins every cdocs agent to a stale model id (e.g. `sonnet` -> `claude-sonnet-4-20250514`, `haiku` -> `claude-3-5-haiku-20241022`); decide how CC tier aliases should resolve for OC so the mapping stays current without hand edits.
>
> - **Motivated By:** [`2026-10-05-oversee-haiku-bash-wrapper.md`](../devlogs/2026-10-05-oversee-haiku-bash-wrapper.md) (noticed while moving `cdocs:bash-runner` to `model: sonnet`)

> NOTE(opus-5-5/build/opencode-build-fixes): Evolved into [`2026-10-07-opencode-build-fixes.md`](2026-10-07-opencode-build-fixes.md), which resolves this RFP's scope and open questions.

## Objective

`scripts/build-opencode.ts` (`MODEL_MAP`, ~L57) translates the CC short aliases in agent frontmatter (`haiku`, `sonnet`, `opus`) into full OC `provider/model` ids.
The ids are hard-coded and several generations old (current: Haiku 4.5, Sonnet 5, Opus 5.5, Fable 5.1), so OC consumers silently run cdocs agents on older models than CC consumers.
The build warns only on an unknown alias, never on a stale id.

## Scope

- Whether OC accepts tier aliases or "latest" ids directly, which would let the build pass the alias through instead of pinning.
- If pinning is required: a single source of truth for current ids (a config file, `package.json` field, or CI-checked constant) and how it is kept fresh (CI check against a published model list, a release-checklist item, or a documented manual bump).
- Whether a consumer should be able to override the mapping (e.g. an OC-side config or env var), consistent with [`model-tiering.md`](../../plugins/cdocs/rules/model-tiering.md)'s "consumer floor wins".
- Coverage for aliases not in the map today (`fable`, `inherit`) and what the build should do with them.
- Whether the CI workflow (`.github/workflows/opencode-build.yml`) should fail on, or warn about, a stale mapping.

## Open Questions

- What model-id forms does OpenCode's Anthropic provider accept (dated ids only, undated aliases, `-latest`)?
- Is a stale-but-valid id worse than an alias that might change behavior between builds?
- Should the published npm package (`@weftwise/cdocs-opencode`) be rebuilt when the mapping changes, and how is that triggered?
