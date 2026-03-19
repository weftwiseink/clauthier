---
first_authored:
  by: "@claude-opus-4-6"
  at: 2026-03-19T00:00:00-07:00
task_list: cdocs/opencode-integration
type: proposal
state: live
status: request_for_proposal
tags: [opencode, commands, skills, ux]
---

# Generate OpenCode Command Wrappers for CDocs Skills

> BLUF: OpenCode skills are agent-side tools (loaded via `skill()`) and are not user-facing TUI slash commands.
> Users expect `/propose`, `/report`, etc. to autocomplete in the TUI prompt.
> The cdocs-opencode build should generate `.opencode/commands/<name>.md` wrapper files that delegate to the corresponding skills, bridging the UX gap.
>
> - Motivated By: first real-world install of cdocs-opencode into the lace project, where skills were invisible in the TUI command palette.

## Objective

Extend the `build-opencode.ts` pipeline and `postinstall.js` to produce and install OC command files alongside skills and rules, so that cdocs skills are accessible as `/slash` commands in the OpenCode TUI.

## Scope

- **Command file format:** OC commands are markdown files in `.opencode/commands/<name>.md` with YAML frontmatter (`description`) and a prompt body.
  Each command should instruct the agent to load the corresponding skill and pass through `$ARGUMENTS`.
- **Build pipeline:** `build-opencode.ts` should auto-generate command wrappers from skill metadata (name, description, argument-hint).
  The command template is mechanical and can be derived entirely from the skill's SKILL.md frontmatter.
- **Postinstall:** `postinstall.js` should copy the generated commands to `.opencode/commands/` in the target project.
  Must handle idempotent re-runs (overwrite existing cdocs commands, don't clobber user commands).
- **Naming:** Commands should use the same names as skills (e.g., `propose.md`, `report.md`).
  Evaluate whether a `cdocs-` prefix is needed to avoid collisions with user-defined or built-in commands.

## Open Questions

- Should commands use a namespace prefix like `cdocs-propose` to avoid colliding with built-in `/init` or user-defined commands?
  OC docs say custom commands can override built-ins, which may surprise users.
- Should the command wrapper specify an `agent` in frontmatter, or leave it as the current agent?
- Should any commands use `subtask: true` to avoid polluting the primary context (e.g., `triage`, `nit_fix`)?
- Is there a convention for distinguishing plugin-installed commands from user-authored ones during cleanup/uninstall?
