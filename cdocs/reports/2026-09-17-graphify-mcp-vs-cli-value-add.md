---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-17T15:42:00-08:00
task_list: code-graph/cdocs-integration
type: report
state: archived
status: review_ready
tags: [analysis, tooling, code_graph, mcp, cli, integration]
---

# Graphify MCP vs CLI: value-add for the cdocs graph-scoping surface

> BLUF(claude-opus-4-8/code-graph/cdocs-integration): For the cdocs scoping integration the CLI is sufficient. The three graphify CLI subcommands (`query`, `explain`, `path`) map one-to-one onto the MCP tools (`query_graph`, `get_node`, `shortest_path`) over the same deterministic AST engine, so the MCP is a transport convenience, not a distinct capability. Nothing in the accepted design fundamentally requires the MCP; resolving the MCP over-mount is not worth it for this integration point now. Recommend proceeding CLI-only and adding a NOTE to the integration proposal that its scoping surface is CLI-backable.

## Context / Background

The accepted proposal `cdocs/proposals/2026-09-17-graphify-cdocs-integration.md` integrates graphify as a stateless graph-scoping surface: given a change's changed symbols, hand the implementer, reviewer, and judge a resolved dependent set (barrel re-exports, aliased re-exports, multi-hop chains) as a compact brief. It names MCP query tools (`query_graph`, `get_node`, `shortest_path`) as the delivery vehicle. Phase 4 confirmed the graphify CLI is live in-container (`graphify update .` builds `graph.json`, ~3694 nodes) while the MCP is currently shadowed by a host-config over-mount (a separate lace RFP covers that). This report pressure-tests the maintainer's suspicion that the MCP does not matter for our integration point.

## Key Findings

- **Concrete operations the loop roles need** (from the proposal's Bet 1): resolve a changed symbol's dependent set following barrel and aliased re-exports and multi-hop chains, returned as a compact brief. That is three graph reads: a scoped traversal from a symbol, a node's neighbors, and a path between two nodes. The observe/subscribe co-surfacing (D3) is a non-graph AST/grep scan of touched files, so it is served by neither surface and is irrelevant to this trade.
- **The CLI exposes exactly those operations.** Per the lace feature README, the CLI provides `graphify query "..."` (BFS traversal for a question), `graphify explain "X"` (a node and its neighbors), and `graphify path "A" "B"` (shortest path). These map one-to-one onto the MCP's `query_graph` / `get_node` / `shortest_path`.
- **Same engine behind both surfaces.** graphify is a deterministic tree-sitter AST graph with zero API calls. The MCP server (`graphify-mcp`) and the CLI are two transports over the identical index (`graph.json` under `GRAPHIFY_OUT`). There is no query the MCP can answer that the CLI cannot, because they read the same graph.
- **The design is already transport-agnostic.** Bet 1 is defined as "a stateless graph-scoping surface" with a "thin translation layer," and D4 says keep the loop-side contract thin for a later adapter swap. MCP was the assumed vehicle, not a load-bearing requirement.
- **Availability asymmetry favors the CLI now.** The CLI is confirmed live at zero additional cost. The MCP is shadowed by an over-mount whose fix is another repo's RFP. Choosing the MCP imports that dependency for no capability gain.

## Analysis

**MCP vs CLI for this use case.** The consumers are dispatched subagents (implementer, reviewer, judge) that already hold Bash and Read. The scoping pattern computes a dependent set up front and feeds it in as a brief, so a thin wrapper (skill or script) can shell out to `graphify query`/`path`/`explain`, format the brief, and hand it to the role. The MCP's genuine edge is structured in-context tool calls a model issues mid-reasoning without authoring shell; that edge does not bind here, because the design's shape is brief-up-front, not ad-hoc-query-during-reasoning. Determinism is identical (same AST engine). Latency is comparable (a persistent stdio server vs a short-lived CLI process over the same cached index). Token cost is a brief-format concern, not a transport one, with one caveat: a subagent must use the CLI query subcommands, which return scoped answers, and must not pull raw `graph.json` (~3694 nodes) into context. Using the subcommands keeps CLI token cost on par with the MCP.

**Does the design require the MCP?** No. Every capability the scoping brief needs is present in the CLI subcommands over the same index. The MCP would be preferable only if the loop later wanted the model itself to issue unplanned graph queries inside its reasoning turn rather than receive a precomputed brief. That is a different design than the accepted one, and if it ever arises it is a Phase 3+ instrumentation finding, not a present requirement.

## Recommendations

- **Proceed CLI-only for the cdocs integration point.** Resolving the MCP over-mount is not worth it for this consumer: it buys no capability the CLI lacks and imports a cross-repo dependency.
- **Add a NOTE to `2026-09-17-graphify-cdocs-integration.md`** that the scoping surface is CLI-backable, and soften D4's "engine-behind-MCP now" to "engine behind the CLI or MCP; both are transports over the same index," so the thin translation layer targets `graphify query`/`explain`/`path` for the first cut.
- **Constrain the CLI wrapper** to the query subcommands (never raw `graph.json` ingestion) to keep the brief compact and token cost on par with the MCP.
- **No MCP-specific blocker exists.** If a future need for in-reasoning ad-hoc graph queries surfaces from Phase 3 instrumentation, revisit the MCP then; it is not needed to ship Bet 1.
