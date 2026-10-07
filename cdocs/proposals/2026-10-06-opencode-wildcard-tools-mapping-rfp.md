---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T19:20:00-07:00
task_list: build/opencode-wildcard-tools
type: proposal
state: live
status: request_for_proposal
tags: [build, opencode, multi-target]
---

# OpenCode Build Wildcard Tools Mapping

> BLUF(opus-5-5/build/opencode-wildcard-tools): `scripts/build-opencode.ts` `mapTools` treats CC `tools: "*"` as an unknown tool name, so the generated OC `implementer`, `reviewer`, and `proposer` ship with `read`, `edit`, `write`, and `bash` all `false`; decide how a wildcard (and an omitted `tools:`) should map to OC.
>
> - **Motivated By:** [`2026-10-06-nested-subagent-workflows.md`](2026-10-06-nested-subagent-workflows.md) (out-of-scope NOTE), [`2026-10-06-nested-subagent-workflows-implementation.md`](../devlogs/2026-10-06-nested-subagent-workflows-implementation.md)

## Objective

`mapTools` (~L79) starts every OC tool at `false` and enables one per recognized CC name (`Read`, `Edit`, `Write`, `Bash`).
`"*"` falls through to the `default` branch, which only warns (`Unknown CC tool "*"`), so the three full-tool cdocs agents get every mapped tool disabled.
OC consumers therefore get an implementer that cannot edit or run commands, the opposite of its CC definition.

## Scope

- Quote stripping: the warning prints `""*""`, so the YAML quotes survive frontmatter parsing and the fix must strip them before matching `*`.
- The OC equivalent of "all tools": omit the `tools:` block, enable every known key, or an OC wildcard form if one exists.
- What `permission` an all-tools agent should carry (today `Edit`/`Write` map to `ask`), consistent with the CC definitions' "deliberately not narrowed" intent.
- Whether `task` (OC subagent dispatch) belongs in the mapping, given CC `tools: "*"` includes `Agent` and cdocs relies on nested dispatch (see the motivating proposal's OpenCode section).
- A build-time guard: fail, rather than warn, when a mapped agent ends up with every tool disabled.
- A regression check in `.github/workflows/opencode-build.yml` or a unit test over the generated agents.

## Open Questions

- Does OpenCode treat an absent `tools:` block as "all tools enabled", and is that stable across OC versions?
- Does OC expose a `task` tool key, and does a subagent with it nest, or is depth undocumented (see the motivating proposal's Background)?
- Should an unknown CC tool name stay a warning, or become an error so the next new CC tool cannot silently drop?
