---
name: graphify
description: Load code context from a graphify code graph (base query, entities, paths) through the cdocs-graphify command
argument-hint: "[question]"
---

# CDocs Graphify

Load code context from a graphify graph instead of grep sweeps and full-file reads.
`cdocs-graphify` keeps this worktree's index current and passes its arguments to `graphify` unchanged; if it prints a "skipping" line, continue without the graph.

## Commands

- `cdocs-graphify query "<question>"`: concept-level context around the matched nodes; `--dfs` traces one chain.
- `cdocs-graphify explain "<entity>"`: an entity and its neighbors.
- `cdocs-graphify path "<A>" "<B>"`: how two entities connect.
- `cdocs-graphify affected "<symbol>"` (versions that have it): reverse dependents of one symbol, one at a time.

If a query matches nothing, retry once with entity names (files, functions, types), then proceed without it.
If `explain` reports an ambiguous name, rerun it with one of the listed ids.

## Reading the output

The graph is static structure.
The appended runtime-coupling sites are the floor, not the ceiling: before concluding a change is contained, grep the changed code for the project's other runtime idioms (event emitters, registries, dynamic dispatch, config).

## By role

- Base query: when your prompt or workstream Scratchpoint carries `graphify_base_query:`, run it before reading code.
- Implementers: `explain` an entity before changing it; when your work reveals sharper terms, end your report with `graphify_base_query: "<refined>"`.
- Reviewers: `explain` each changed entity; `path` to check relationships the change assumes.

Report conclusions and file paths, not raw graph output.
