---
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-19T00:00:00-07:00
task_list: cdocs/opencode-integration
type: proposal
state: live
status: evolved
evolved_into: 2026-03-19-decouple-oc-build-from-cc-plugin.md
tags: [opencode, skills, postinstall, path-conventions]
---

> NOTE(opus/opencode-decoupling): This RFP has been evolved into the [OC decoupling proposal](2026-03-19-decouple-oc-build-from-cc-plugin.md), which incorporates the skill nesting fix alongside the broader `.opencode/`-only confinement and source-repo guard.

# Migrate cdocs-opencode Postinstall to Use OpenCode-Native Skill Paths

> BLUF: The `@weftwise/cdocs-opencode` postinstall script places skills at `.claude/skills/cdocs/<name>/SKILL.md`, but OpenCode discovers skills at `.claude/skills/<name>/SKILL.md` (flat, one directory level).
> The `cdocs/` nesting prefix prevents OC from discovering any skills.
> The postinstall should target `.opencode/skills/<name>/` as the canonical OC path.
>
> - Motivated By: first real-world install of cdocs-opencode into the lace project, where skills were invisible to OC until manually moved.

## Objective

Update the `postinstall.js` script and the `build-opencode.ts` build pipeline so that the OC build produces skills at paths OpenCode can discover, without requiring manual intervention by the consumer.

## Scope

- **Postinstall skill destination:** Change from `.claude/skills/cdocs/<name>/` to `.opencode/skills/<name>/` (or `.claude/skills/<name>/` flat, but `.opencode/` is preferred to avoid collision with CC-specific config).
- **OC skill discovery model:** OpenCode searches `skills/*/SKILL.md` in `.opencode/`, `.claude/`, and `.agents/` directories. It does not recurse into `skills/*/*/SKILL.md`. The `cdocs/` namespace prefix is invisible to OC.
- **Name collision risk:** Skill names like `init`, `report`, `review`, `status` are generic. Evaluate whether the skill `name` field should be prefixed (e.g., `cdocs-report`) or if the flat namespace is acceptable given that consumers opt in to the plugin.
- **Rule path conventions:** Rules at `.claude/rules/` work correctly for both CC and OC. Evaluate whether `.opencode/rules/` with OC frontmatter (globs/keywords) should be the canonical target.
- **Build pipeline impact:** `build-opencode.ts` produces the `skills/` directory structure that the postinstall copies. The nesting convention needs to change at the build level, not just the postinstall.

## Open Questions

- Should skill names be prefixed with `cdocs-` to avoid namespace collisions in the flat `.opencode/skills/` directory? This would change invocation from `/report` to `/cdocs-report`.
- Should the postinstall detect whether `.opencode/` or `.claude/` is the project's preferred config directory and target accordingly, or always use `.opencode/`?
- Should the postinstall also create `.opencode/rules/cdocs/` with OC-enhanced frontmatter (globs, keywords) as the init skill specifies?
- Is there a mechanism for OC plugins to register skills programmatically (via the plugin API) rather than copying files into the project? This would be the cleanest long-term solution.
