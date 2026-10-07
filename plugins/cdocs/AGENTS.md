# CDocs Conventions

Follow these conventions when working with CDocs documentation.

## Writing Conventions

@rules/writing-conventions.md

## Workflow Patterns

@rules/workflow-patterns.md

## Overseers

@rules/overseers.md

## Tool Use Safeguards

@rules/tool-use-safeguards.md

## Frontmatter Specification

@rules/frontmatter-spec.md

## Skills

Dispatcher skills live in `plugins/cdocs/skills/`.
Key skills for workflow composition:

- `/cdocs:implement`: implement a single proposal.
- `/cdocs:review`: review a cdocs document.
- `/cdocs:iterate`: run an implement-review loop on a proposal with overseer-mode orchestration and periodic judge meta-assessment.
- `/cdocs:oversee`: drive an ARC of proposals through their lifecycle by composing `full-send`/`iterate`/`propose-revise`, with a durable resumable arc-state file.

## Formal Agents

Formal agents in `plugins/cdocs/agents/` with explicit tool allowlists:

- `reviewer`: structured document reviews (opus).
- `judge`: meta-assessment of `/cdocs:iterate` loop health (opus; no Edit, Bash, or Task).
- `triage`: frontmatter analysis, mechanical fixes, and iterate-devlog log-state mapping (sonnet).
- `nit-fix`: writing-convention enforcement (haiku).
- `bash-runner`: runs one expected-verbose command, captures its output to a file, and returns a fixed-format report (sonnet; Bash only). See "Bash: Avoid context bloat from careless bash commands" in `rules/tool-use-safeguards.md`.
