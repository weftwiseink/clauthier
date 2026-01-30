---
first_authored:
  by: "@claude-sonnet-4-20250514"
  at: 2026-01-30T09:00:00-08:00
task_list: cdocs/mermaid-plugin
type: proposal
state: live
status: request_for_proposal
tags: [diagrams, plugin_architecture, mermaid, marketplace]
---

# RFP: Mermaid Diagram Plugin for CDocs Ecosystem

## BLUF

This RFP proposes a standalone marketplace plugin that integrates claude-code-documentation-skill and beautiful-mermaid to provide diagram generation and enrichment capabilities for CDocs workflows.
The plugin would complement the existing CDocs nit-fix agent by not only detecting ASCII diagrams but actively converting them, generating diagrams from code/architecture descriptions, and ensuring Mermaid syntax quality.
By wrapping or orchestrating these two proven open-source tools, we can provide a specialized mermaid agent that enforces the "Prefer Mermaid Over ASCII" writing convention with automated assistance.

## Objective

Design and implement a CDocs marketplace plugin that leverages existing open-source tooling to:
- Convert ASCII diagrams to Mermaid syntax
- Generate Mermaid diagrams from code and architecture descriptions
- Validate and beautify Mermaid syntax
- Integrate with CDocs nit-fix agent workflow for diagram quality enforcement

## Scope

This proposal should explore:
- Plugin architecture: wrapping vs. orchestrating the two external tools
- Agent definition: how a mermaid-focused subagent would operate within CDocs workflows
- Skill surface: what commands/capabilities to expose (convert, generate, validate, beautify)
- Integration points with CDocs nit-fix agent and document cleanup workflows
- User experience: when to auto-generate vs. assist, how to handle diagram context and placement
- Deployment model: standalone marketplace plugin vs. CDocs extension

## Known External Tools

**claude-code-documentation-skill** (https://github.com/pranavred/claude-code-documentation-skill):
A Claude Code skill/plugin for documentation generation that includes diagram generation from codebases.
Provides codebase analysis and structured documentation output capabilities that could be leveraged for architecture diagram generation.

**beautiful-mermaid** (https://github.com/lukilabs/beautiful-mermaid):
A tool for creating and beautifying Mermaid diagrams.
Provides utilities for generating clean, well-formatted Mermaid syntax and could serve as the validation/beautification layer.

## Known Considerations

- Plugin architecture: determine whether to wrap these tools as dependencies or orchestrate them as external processes
- Agent definition: how a mermaid agent fits into the CDocs subagent model (parallel agent, specialized reviewer, or on-demand skill)
- Auto-generation boundaries: when to automatically convert ASCII diagrams vs. suggest conversions vs. require manual approval
- Syntax validation: how to handle invalid Mermaid syntax, provide feedback, and suggest corrections
- Context preservation: ensuring generated diagrams accurately reflect the code/architecture they document
- Performance: diagram generation can be computationally intensive, need strategy for large codebases
- CDocs integration: how nit-fix agent detects and delegates to mermaid plugin, shared conventions

## Open Questions

1. Should the plugin wrap these tools as dependencies or orchestrate them as external CLI processes?
2. What is the optimal agent architecture: a standalone mermaid agent, a skill set, or both?
3. How should the plugin handle ASCII-to-Mermaid conversion: fully automated, semi-automated with confirmation, or suggestion-only?
4. What diagram types should be prioritized: architecture diagrams, sequence diagrams, flowcharts, class diagrams?
5. How should the plugin integrate with the CDocs nit-fix agent workflow: as a delegated subagent or a separate review pass?
6. What validation and quality checks should be performed on generated Mermaid syntax beyond beautification?
7. How should the plugin handle diagram context: inline code analysis, separate architecture descriptions, or both?
8. What user controls are needed: diagram style preferences, complexity thresholds, auto-generation toggles?
