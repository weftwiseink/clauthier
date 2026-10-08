# CDocs Conventions

Follow these conventions when working with CDocs documentation.

## Writing Conventions

@rules/writing-conventions.md

## Workflow Patterns

@rules/workflow-patterns.md

## Overseers

@rules/overseers.md

## Tool Use Guidance

@rules/tool-use-safeguards.md

## Frontmatter Specification

@rules/frontmatter-spec.md

## Skills

Dispatcher skills live in `plugins/cdocs/skills/`.
Key skills for workflow composition:

- `/cdocs:implement`: implement a single proposal.
- `/cdocs:review`: review a cdocs document.
- `/cdocs:iterate`: run an implement-review loop on a proposal with overseer-mode orchestration and periodic judge meta-assessment.
- `/cdocs:oversee-many`: drive an ARC of proposals through their lifecycle by composing `full-send`/`iterate`/`propose-revise`, with a durable resumable arc-state file.

## Formal Agents

Formal agents in `plugins/cdocs/agents/` with explicit tool allowlists:

- `reviewer`: structured document reviews (opus).
- `proposer`: authors or revises a cdocs design proposal with structured sections and implementation phases (no model pin; all tools).
- `implementer`: implements an accepted cdocs proposal with structured execution and frequent commits (no model pin; all tools).
- `judge`: meta-assessment of `/cdocs:iterate` loop health (opus; no Edit, Bash, or Task).
- `triage`: frontmatter analysis, mechanical fixes, and iterate-devlog log-state mapping (sonnet).
- `nit-fix`: writing-convention enforcement (haiku).
- `bash-runner`: runs one expected-verbose command, captures its output to a file, and returns a fixed-format report (sonnet; Bash only). See "Bash: Avoid context bloat from careless bash commands" in `rules/tool-use-safeguards.md`.
- `interfacer`: testing assistant that drives the app or interface under test with the project's own tooling, captures media, and writes a brief report; each follow-up check is a fresh dispatch naming its instance directory (sonnet; inherits all tools, including the project's MCP servers).
