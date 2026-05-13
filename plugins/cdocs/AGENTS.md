# CDocs Conventions

Follow these conventions when working with CDocs documentation.

## Writing Conventions

@rules/writing-conventions.md

## Workflow Patterns

@rules/workflow-patterns.md

## Frontmatter Specification

@rules/frontmatter-spec.md

## Skills

Dispatcher skills live in `plugins/cdocs/skills/`.
Key skills for workflow composition:

- `/cdocs:implement`: implement a single proposal.
- `/cdocs:review`: review a cdocs document.
- `/cdocs:iterate`: run an implement-review loop on a proposal with overseer-mode orchestration and periodic judge meta-assessment.

## Formal Agents

Formal agents in `plugins/cdocs/agents/` with explicit tool allowlists:

- `reviewer`: structured document reviews (opus).
- `judge`: meta-assessment of `/cdocs:iterate` loop health (opus; no Edit, Bash, or Task).
- `triage`: frontmatter analysis and mechanical fixes (haiku).
- `nit-fix`: writing-convention enforcement (haiku).
