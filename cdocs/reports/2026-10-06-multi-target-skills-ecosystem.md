---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-10-06T12:00:00-07:00
task_list: cdocs/multi-target-skills-ecosystem
type: report
state: live
status: review_ready
tags: [opencode, agent_skills, cross_tool, build, architecture, multi_target]
---

# Multi-Target Skills Ecosystem: What Changed, What It Means for cdocs' OpenCode Build

> BLUF(sonnet-5/cdocs/multi-target-skills-ecosystem): The Agent Skills format (SKILL.md) is now an adopted open standard that OpenCode reads verbatim from `.claude/skills/`; cdocs already copies skills byte-for-byte with no transform, so the real simplification is distribution, not conversion: materialize skills into the project's `.claude/skills/` via `/cdocs:init` and retire the `@weftwise/cdocs-opencode` npm package for that piece.
> Agents, tools, permissions, and model ids have **not** standardized: no adopted cross-tool subagent-frontmatter spec exists, OpenCode's agent format and tool vocabulary differ from Claude Code's, and OpenCode requires fully-qualified `provider/model-id` strings with no tier-alias pass-through, so `build-opencode.ts`'s agent/model conversion stays load-bearing.
> Rules are a wash: OpenCode reads `AGENTS.md`/`CLAUDE.md` natively but only as flat, unscoped files; path/keyword-scoped loading needs a third-party plugin (`opencode-rules`) that is not bundled, and OpenCode core has its own open issue for glob-scoped rules.
> Claude Code's plugin-native `rules` field ([#14200](https://github.com/anthropics/claude-code/issues/14200)) has not landed (still open, no PR, a duplicate was just filed as [#21163](https://github.com/anthropics/claude-code/issues/21163)), so the freshness-hook workaround stays necessary.

## Context / Background

cdocs ships one CC-canonical source (`plugins/cdocs/{agents,skills,rules}/`) and converts it for OpenCode two ways: a build script (`scripts/build-opencode.ts`) that rewrites agent frontmatter into an npm package (`@weftwise/cdocs-opencode`), and a `/cdocs:init` skill that materializes rules into `.opencode/rules/cdocs/` and an `AGENTS.md` block. Three open RFPs target pieces of this: a YAML-parser fix for the build script's frontmatter scanner, a model-mapping freshness problem, and a target-specific-guidance question about where OC/cross-tool differences should live. This report asks whether anything in the wider ecosystem (new standards, new native support in OpenCode or Claude Code) has moved since those RFPs were written, such that the build/init machinery can shrink.

Current-state files read: `scripts/build-opencode.ts`, `plugins/cdocs/scripts/postinstall.js`, `plugins/cdocs/skills/init/SKILL.md` (steps 5-6), `plugins/cdocs/README.md` ("OpenCode Installation", "Rules Integration"), repo `CLAUDE.md` ("Multi-Target Marketplace"), and the three RFPs: `2026-10-06-target-specific-guidance-rfp.md`, `2026-10-05-opencode-build-yaml-parser-rfp.md`, `2026-10-05-opencode-model-mapping-rfp.md`.

## Key Findings

### Agent Skills is now an open, broadly-adopted standard

- Anthropic released the Agent Skills format as an open standard on **December 18, 2025**, with a canonical spec site at [agentskills.io](https://agentskills.io) and an open repo/discussion at [github.com/agentskills/agentskills](https://github.com/agentskills/agentskills). The spec is deliberately minimal: a folder with a `SKILL.md` carrying two required frontmatter fields (`name`, `description`) plus a Markdown body, discovered in three stages (name+description at startup, full body on activation, bundled files on execution).
- The spec's client showcase (fetched 2026-10-06) lists 40+ adopting products, including **OpenCode, Cursor, GitHub Copilot, VS Code, OpenAI Codex/ChatGPT, Gemini CLI, Amp, Goose, Roo Code, Claude Code, and Claude.ai**. Source: [agentskills.io](https://agentskills.io).
- **OpenCode reads SKILL.md natively**, with no conversion, from six locations ([opencode.ai/docs/skills/](https://opencode.ai/docs/skills/), last updated 2026-10-06): `.opencode/skills/`, `~/.config/opencode/skills/`, **`.claude/skills/<name>/SKILL.md`** (project), `~/.claude/skills/<name>/SKILL.md` (global), `.agents/skills/`, `~/.agents/skills/`. Recognized frontmatter is `name`, `description`, `license`, `compatibility`, `metadata`; unknown fields are ignored (not an error).
- **Claude Code itself reads project skills from `.claude/skills/<name>/SKILL.md`** directly, independent of plugin-delivered skills (plugin, personal, project, and enterprise are four distinct skill sources). Source: [code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills).
- `scripts/build-opencode.ts`'s skill handling is **already** a verbatim copy (`copyDir(SKILLS_DIR, OUT_SKILLS)`, no frontmatter rewrite), and `postinstall.js`'s `copySkillsFlat` likewise just `cpSync`s directories. The machinery around this copy (an npm package, a postinstall script, a publish/version-sync step) exists only to get identical bytes onto an OC-visible filesystem path, not to transform them.

### Agents, tools, and model ids: no standard, conversion still required

- No adopted cross-tool subagent-frontmatter spec exists. A draft, [`enulus/OpenPackage`'s `agents-frontmatter.md`](https://github.com/enulus/OpenPackage/blob/main/specs/agents-frontmatter.md), proposes one but is unadopted by any real tool: it documents hoped-for alignment, not shipped behavior.
- OpenCode's own agent format ([opencode.ai/docs/agents/](https://opencode.ai/docs/agents/)) differs from Claude Code's on every axis `build-opencode.ts` already converts: a `permission` object with `ask`/`allow`/`deny` instead of a tool list, a `read`/`edit`/`write`/`bash` boolean vocabulary instead of `Read`/`Edit`/`Write`/`Bash` names, and no native reader for `.claude/agents/`.
- OpenCode requires **fully-qualified `provider/model-id` strings**; the docs show no support for tier aliases or a `-latest` suffix. This directly answers `2026-10-05-opencode-model-mapping-rfp.md`'s open question ("What model-id forms does OpenCode's Anthropic provider accept?"): pinned, dated ids only: a CC-alias pass-through is not an option, so the RFP's "single source of truth, kept fresh" scope is the only viable path, not a stopgap.

### Rules: native file reading, but no native scoping

- OpenCode reads `AGENTS.md` natively, with `CLAUDE.md` as a compatibility fallback when no `AGENTS.md` exists ([opencode.ai/docs/rules/](https://opencode.ai/docs/rules/)). Neither is scoped: no frontmatter-driven conditional loading is documented in OpenCode core.
- The `opencode-rules` plugin cdocs' README and `/cdocs:init` treat as optional enhancement is confirmed real but third-party and unbundled: [github.com/frap129/opencode-rules](https://github.com/frap129/opencode-rules), "An opencode plugin to dynamically inject rules into context, like cursor." cdocs' own framing ("not required... falls back to `.claude/rules/`... or AGENTS.md") is consistent with this, though the README's claim that OC reads `.claude/rules/` natively is not corroborated by OpenCode's own rules doc, which only documents `AGENTS.md`/`CLAUDE.md` file-level reading; worth a follow-up check, flagged here rather than silently corrected.
- OpenCode core has its own **open, unresolved** feature request for Cursor-style glob-scoped rules ([anomalyco/opencode#37463](https://github.com/anomalyco/opencode/issues/37463)), so native path-scoping is not imminent.

### Claude Code's own standards posture moved, modestly

- Claude Code added native `AGENTS.md` support as a **fallback when no `CLAUDE.md` is present** (reported at CC v2.1.277, 2026-09-18, via multiple independent secondary sources; not independently re-verified against the primary changelog text in this session, so treat as high-confidence but secondary-sourced). It is a fallback, not a merge: a project with both files still reads only `CLAUDE.md`. Since cdocs' `/cdocs:init` writes a `CLAUDE.md` `@`-import, this does not change CC-side rule delivery for cdocs-initialized projects.
- `AGENTS.md` itself was donated by OpenAI to the Linux Foundation's Agentic AI Foundation in December 2025 and is read by 30+ tools and 60,000+ projects, per secondary-source aggregation; vendor-neutral governance, no primary registry consulted directly.
- **Confirmed directly against the current plugin manifest reference** ([code.claude.com/docs/en/plugins-reference](https://code.claude.com/docs/en/plugins-reference)): there is still no `rules` field in `plugin.json`. The field list is exhaustive and does not include one. The docs explicitly state: *"A `CLAUDE.md` at the plugin root isn't loaded as context... To include instructions that load into Claude's context, put them in a skill."* This is Anthropic's own sanctioned workaround, and it is a skill (progressively disclosed: name+description only until invoked), not an always-loaded rule; it does not solve what the freshness hook solves.
- [#14200](https://github.com/anthropics/claude-code/issues/14200) (opened 2025-12-16) is still open with no assignee, no PR, no maintainer comment. A near-duplicate, [#21163](https://github.com/anthropics/claude-code/issues/21163), has since been filed asking for the same `rules` field. The README's "When CC #14200 Lands" migration section remains purely aspirational; there is no signal it is close.
- A new, unrelated plugin capability, **Claude Mods** (CC v2.1.287, 2026-10-01), lets a plugin run TypeScript functions that intercept tool calls, prompts, permission requests, and renders. It is conceivable a mod could inject always-on context as a workaround for #14200, but nothing in the research confirms this is a supported use, and it was not evaluated further; flagged as a candidate for a future spike, not a decision input here.

## Mapping: cdocs Build/Init Pieces vs. Ecosystem State

| Piece | Status | Basis |
|---|---|---|
| Skills (`plugins/cdocs/skills/*`) | **Now native elsewhere** | OpenCode and Claude Code both read `SKILL.md` verbatim from `.claude/skills/<name>/`; cdocs' existing copy step already does no transformation. |
| Agents (`plugins/cdocs/agents/*.md`, `convertAgent`) | **Still needs conversion** | No adopted cross-tool agent-frontmatter spec; OpenCode's tool/permission vocabulary and `mode` differ from CC's. |
| Model ids (`MODEL_MAP`) | **Still needs conversion, confirmed unavoidable** | OpenCode requires fully-qualified `provider/model-id`; no alias or `-latest` pass-through found. |
| Frontmatter parser (regex scanner in `build-opencode.ts`) | **Unrelated to ecosystem change, bug stands** | Block-scalar (`description: \|`) handling is a parser bug independent of any standard; fixing it is orthogonal to the skills/agents findings above. |
| Rules (`.opencode/rules/cdocs/*`, AGENTS.md inlining) | **Partially native, partially unsupported** | OC reads `AGENTS.md`/`CLAUDE.md` natively but unscoped; path/keyword scoping needs the third-party `opencode-rules` plugin (confirmed real, unbundled) or waits on OC's own open glob-scoping issue. |
| CC plugin-native `rules` field | **Unsupported, not landed** | [#14200](https://github.com/anthropics/claude-code/issues/14200) open 10+ months, no PR; duplicate [#21163](https://github.com/anthropics/claude-code/issues/21163) filed. |
| Freshness hook (`inject-rules.ts`) | **Still needed** | Direct consequence of the row above. |
| `postinstall.js` / `@weftwise/cdocs-opencode` npm package | **Obsoletable for its skills portion** | Exists mainly to place skills+rules under `.opencode/`; the skills half can move to a `/cdocs:init`-driven copy into the shared `.claude/skills/` path instead. |

## Recommendations

Ranked by payoff and risk; each lists the RFP(s) it touches.

1. **(High payoff, low risk) Materialize skills into `.claude/skills/` from `/cdocs:init` instead of (or ahead of) the npm package.** Both Claude Code (project skills) and OpenCode (`.claude/skills/` is a documented native path) discover the identical, untransformed files. This lets the skills-copy portion of `scripts/build-opencode.ts` and `postinstall.js`'s `copySkillsFlat` retire, and shrinks or removes the case for publishing `@weftwise/cdocs-opencode` at all for users who only need skills. Does not directly touch the three open RFPs' text, but removes the "published package rebuild" concern the YAML-parser RFP's scope raises (`2026-10-05-opencode-build-yaml-parser-rfp.md`, "Published package rebuild" bullet) for the skills half of that package, and shrinks the surface `2026-10-06-target-specific-guidance-rfp.md` has to reason about.
2. **(Medium payoff, low risk) Resolve `2026-10-05-opencode-model-mapping-rfp.md` with the confirmed answer: pinning is mandatory, not optional.** The RFP's first open question is answered: OpenCode needs fully-qualified dated ids, no alias pass-through exists. The RFP should proceed straight to "single source of truth + CI freshness check" (its own second scope bullet) rather than exploring an alias-based escape hatch.
3. **(Medium payoff, low-medium risk) Proceed with `2026-10-05-opencode-build-yaml-parser-rfp.md` as scoped.** Research found no ecosystem shortcut that obsoletes it: the block-scalar bug is a parser defect, not a standards gap, and no agent-frontmatter standard exists to delegate the parsing problem to.
4. **(Low new information, but answers open questions) Treat `2026-10-06-target-specific-guidance-rfp.md`'s first open question as answered "yes."** OpenCode's lack of native path/keyword-scoped rules (core feature request still open: [anomalyco/opencode#37463](https://github.com/anomalyco/opencode/issues/37463); scoping only available via the unbundled third-party `opencode-rules` plugin) is itself the load-bearing target difference that justifies cdocs' separate `.opencode/rules/cdocs/*` materialization. Its other two open questions (build-time injection vs. `/cdocs:init`, drift detection) are not resolved by anything found here and remain cdocs-side design decisions.
5. **(Do not act on yet) Do not plan around Claude Code's plugin-native `rules` field.** [#14200](https://github.com/anthropics/claude-code/issues/14200) shows no sign of landing soon, and a duplicate ([#21163](https://github.com/anthropics/claude-code/issues/21163)) was just filed against it. Keep the README's "When CC #14200 Lands" section as a dormant migration note, not a near-term plan. Separately, Claude Mods (shipped 2026-10-01) is new and might offer an alternate path to always-on context injection, but this is unconfirmed and should be a research spike of its own before it enters any proposal.

## Open Items Not Resolved by This Research

- Whether OpenCode actually reads `.claude/rules/` natively, as the cdocs README currently asserts: OpenCode's own rules doc only documents `AGENTS.md`/`CLAUDE.md` file-level reading, not a `.claude/rules/` directory. Worth a direct runtime check before trusting either source.
- Whether a skill-delivered-context approach (Anthropic's documented workaround for plugin-root `CLAUDE.md`) could supplement, not replace, the freshness hook for any always-loaded-adjacent use case: not explored here.
- Current exact dated model ids for Sonnet 5 / Opus 5.5 / Haiku 4.5 / Fable 5.1 on OpenCode's Anthropic provider: not looked up, left to the model-mapping RFP's own implementation.
