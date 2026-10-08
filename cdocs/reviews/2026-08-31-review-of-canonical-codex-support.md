---
review_of: cdocs/proposals/2026-08-31-canonical-codex-support.md
first_authored:
  by: "@gpt-5.6-sol"
  at: 2026-08-31T11:51:48-07:00
task_list: cdocs/codex-support
type: review
state: archived
status: done
tags: [fresh_agent, architecture, codex, portability, missing_validation]
---

# Review: Canonical Codex Support for CDocs

> BLUF(codex/cdocs-support-review): Revise before implementation.
> The repository bundle is the correct default and the cleanup inventory is accurate, but the plugin translation path, custom-agent model and skill loading, and shared `AGENTS.md` ownership remain unresolved design decisions.

## Summary Assessment

The proposal establishes a strong repository-first architecture, correctly rejects cross-repository symlinks, and separates repository discovery from user-local plugin state.
The live Clauthier and Weftwise trees confirm both the need for generated Codex translations and the exact experimental cleanup inputs.
The design is not yet executable without implementer invention because its direct plugin package bypasses those translations, its agent configuration contradicts Codex precedence, and its removal contract can delete pre-existing cross-tool rules.
Verdict: **Revise**.

## Evidence Reviewed

- Clauthier contains 13 canonical skills, four formal agent definitions, three rule files, and an OpenCode builder whose `mapTools()` path treats reviewer `tools: "*"` as unknown.
- The Weftwise experiment is wholly untracked at `.agents/`, `plugins/`, and its audit devlog, while Codex CLI 0.151.0 reports only `cdocs@personal` under marketplace `personal` and the proposal's exact cache version.
- Weftwise already has a versioned `cdocs-rules-start` through `cdocs-rules-end` block in root `AGENTS.md`, plus the same rule hash in `.claude/rules/cdocs.md`.
- Official OpenAI documentation confirms repository skill discovery and symlink behavior in [Build skills](https://learn.chatgpt.com/docs/build-skills), project custom-agent loading and precedence in [Subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents), supported lifecycle events in [Hooks](https://learn.chatgpt.com/docs/hooks), and plugin contents and marketplace state in [Package your plugin](https://developers.openai.com/plugins/build/plugins).

## Section-by-Section Findings

### One canonical source and canonical plugin package

**Blocking:** The two sections define incompatible delivery paths.
The plugin manifest points directly to `plugins/cdocs/skills/`, while the Codex adapter rewrites names, invocations, Claude `Task` terminology, model roles, and paths only in generated repository output.
The live Weftwise experiment confirms this is not theoretical: seven skill files and all four agent bodies require Codex-specific changes to run beyond discovery.
A direct manifest therefore packages Claude-oriented bodies, while a generated plugin payload needs a committed self-contained location that the proposal does not define.
Choose whether canonical skill prose becomes host-neutral or whether both Codex surfaces consume one generated Codex skill payload, then specify how a Git marketplace obtains that payload without relying on ignored local build output.

**Non-blocking:** The proposed narrow shared utilities are appropriately scoped.
Phase 1 should preserve the current OpenCode warning as a characterized failure rather than treating unchanged bytes as proof of correct behavior.

### Plugin scope versus repository scope

**Blocking:** The optional plugin is presented as a complete cross-project CDocs path, but the documented plugin package supports skills, MCP resources, assets, and hooks, not installation of project or personal custom-agent TOML files.
The repository bundle supplies `.codex/agents/`, while the plugin section supplies no equivalent reviewer, judge, triage, or nit-fix dispatch contract.
Either define a tested generic-subagent fallback that loads bundled role instructions, or state that the plugin is skills-only and that formal orchestration requires the repository bundle.

**Blocking:** Invocation language is not stable enough for user documentation or snapshots.
Official OpenAI documentation uses `$skill` or `/skills` for standalone Codex skills and `@` for selecting a plugin or bundled skill, while the current experiment's `cdocs:propose` output is an inventory name rather than proof of a supported typed selector.
The proposal must name and runtime-test the actual explicit invocation on each supported surface instead of treating namespace display text as command syntax.

### Named-agent mapping and workflow portability

**Blocking:** The promised model override precedence contradicts current Codex behavior.
Official documentation states that `model` and `model_reasoning_effort` in a custom-agent file take precedence over an explicit spawn value.
Generated TOML cannot both pin `gpt-5.6` or `gpt-5.6-luna` and allow `--model` to override it.
Specify one mechanism, such as omitting model fields from TOML and having the orchestrating skill pass either the role default or the user override explicitly.

**Blocking:** The reviewer role's required skill loading has no Codex-native design.
Canonical `reviewer.md` relies on `skills: [cdocs:review]` being preloaded, while Codex `skills.config` controls availability and does not establish the same preload contract.
Define whether generated `developer_instructions` embed the review method, require the reviewer to read `.agents/skills/cdocs-review/SKILL.md`, or receive the selected skill in every dispatch prompt.
Add an assertion that a fresh reviewer receives the complete review methodology before it writes anything.

### Rules delivery and deployment ownership

**Blocking:** The deployer's ownership model is unsafe for an already initialized CDocs repository.
Weftwise's root CDocs marker block predates the proposed Codex bundle and is shared by Codex, Cursor, and OpenCode, while Claude loads the parallel `.claude/rules/cdocs.md` copy.
Treating that block as a Codex-managed path means `--remove` can delete configuration still required by other hosts, and updating only that block can leave the Claude materialization on a different hash.
Define adoption versus creation in the target manifest, restoration or retention behavior on removal, and whether shared rule refresh updates all existing target materializations or deliberately leaves them untouched.

**Non-blocking:** Refusing unmanaged collisions and excluding a force mode are sound defaults.
The prior target manifest should remain the authority for detecting removed canonical skills so an upgrade can delete obsolete managed paths without touching new unmanaged files.

### Hooks boundary

**Blocking validation, not blocking hook implementation:** Shipping no Codex hook remains a defensible first release, but the acceptance language overstates the resulting enforcement.
Current Codex supports repository and plugin hooks, including `PreToolUse`, `SubagentStart`, and `SubagentStop`, yet a workspace-write custom agent has no path-level restriction merely because its instructions say to edit only CDocs files.
Document the Claude infrastructure-enforced versus Codex instruction-enforced boundary and add a deliberate out-of-scope edit probe whose result is recorded as a known gap.
If equivalent prevention is required for acceptance, it needs a separately validated Codex hook as the proposal already anticipates.

### Failure pictures, verification, and phase ordering

**Blocking:** The failure suite does not cover the architecture's highest-risk false positives.
Add fail-loud pictures for a plugin skill loading untranslated Claude mechanisms, a reviewer starting without the review methodology, a model override being ignored by pinned TOML, and `--remove` deleting a pre-existing CDocs marker.
These failures can otherwise pass skill enumeration, TOML parsing, and the current minimal delegation probe.

**Blocking:** Phase 2 accepts direct plugin packaging before a translated plugin payload exists, and no later phase explicitly replaces that payload or runs formal orchestration through the plugin surface.
Establish the shared Codex transformation contract before accepting plugin packaging, then run at least review and iterate smoke tests independently through both the repository bundle and the optional plugin fallback.
Also test coexistence with Clauthier's existing `.claude-plugin/marketplace.json`, because Codex recognizes that path as a legacy marketplace source and the proposal adds a second catalog.

### Cleanup and migration

**Non-blocking:** The machine-local cleanup inventory, stop conditions, CLI-first removal, and exact cache target match the live system.
The ordering correctly defers cleanup until a replacement is ready.
The shared `AGENTS.md` ownership blocker above must be resolved before `--remove` can be considered safe.

## Verdict

**Revise.**
The proposal may not transition to `implementation_ready` until the plugin artifact architecture, agent precedence and skill-loading contract, and shared rule ownership are explicit and covered by failure-first tests.
The repository-only architecture and exact experimental cleanup plan are otherwise suitable foundations.

## Action Items

1. [blocking] Define one self-contained translated Codex skill payload and state exactly how both the plugin marketplace package and repository bundle consume it from a fresh clone.
2. [blocking] Define the optional plugin's formal-agent capability boundary and runtime-test its chosen reviewer and iterate behavior.
3. [blocking] Reconcile custom-agent model defaults with Codex precedence, and specify how every fresh reviewer receives the complete review skill.
4. [blocking] Add an ownership model for pre-existing `AGENTS.md` CDocs blocks and parallel Claude or OpenCode rule materializations, including safe `--remove` behavior.
5. [blocking] Expand failure pictures and runtime tests for untranslated plugin bodies, missing reviewer methodology, ignored model overrides, out-of-scope agent writes, shared-marker removal, and dual marketplace catalogs.
6. [blocking] Reorder phase acceptance so transformations precede a usable plugin claim and both Codex surfaces receive independent workflow verification.
7. [non-blocking] Preserve and characterize the OpenCode wildcard-tool capability loss while extracting shared builder utilities.

## Design Choice Required

Select one plugin strategy before revision:

1. **Generated shared payload (recommended):** Generate one Codex skill tree used by both surfaces, add project custom agents only in repository deployment, and give the plugin a documented generic-agent role fallback.
2. **Host-neutral canonical bodies:** Rewrite canonical skill prose so the direct plugin and Claude package share bodies, leaving adapters to translate only metadata and agent configuration.
3. **Repository-only first release:** Defer the optional plugin until Codex has a fully specified orchestration path, and ship the repository bundle as the sole accepted Codex surface.
