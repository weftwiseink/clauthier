---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-18T00:00:00-07:00
task_list: cdocs/mcp-ablation
type: devlog
state: live
status: wip
tags: [ablation, e2e, graphify, mcp-effectiveness, overseer, scorecard, cli-first]
---

# Devlog: /cdocs:ablate e2e — probeA (graphify on inject-rules.ts blast radius)

> BLUF: First live top-level overseer run of `/cdocs:ablate`. Target = `cli:^graphify ` (graphify is CLI-first here; MCP shadowed). Task = explain `plugins/cdocs/hooks/inject-rules.ts`, enumerate its imports/deps, and identify its trigger, written to `ANSWER.md`. Two isolated worktree arms off pinned base `4bd7bcf`, tool GRANTED vs WITHHELD, single-shot (`trials=1`, `gate_admissible:false` expected). Run dir: `/tmp/ablate-e2e/probeA`.

## Setup / invariants (Step 0)

- Pinned base: `4bd7bcf94d9734063a03ceddb78b8d5fe055d256` (HEAD). Invoking tree has unrelated `.lace/*.json` + devlog WIP → `worktree-create --allow-dirty` (tests committed base, excludes WIP per D1).
- One verbatim task prompt to both arms (D4). Base model identical: **sonnet** both arms; evaluator **opus** (D5).
- Tool-set diff (the single variable): assisted arm = graphify CLI available + surfaced; unassisted arm = graphify withheld.
- **Withhold expression (recorded per operational ask):** the Agent dispatch tool in this harness exposes no per-call `--disallowedTools`/allowlist parameter, so the single-tool withhold is expressed at the **prompt/instruction layer** — the unassisted arm's dispatch prompt states graphify is unavailable and forbids invoking it — and is **confirmed mechanically** by `ablate.sh detect-usage` returning `unused` on the unassisted transcript. Every other tool (Read/Bash/Write/Glob/Grep) is identical across arms. Full text in `/tmp/ablate-e2e/probeA/invariants.json`.
- graphify graph resolves globally via `GRAPHIFY_OUT=/var/cache/graphify`; smoke test `graphify explain "inject-rules.ts"` returns the target node + 5 neighbors (the canonical "what does this touch" win case).

## Work log

- Read `ablate.sh`; confirmed subcommand surface (worktree-create/-remove, resolve-transcript, detect-usage, meter, decide, scorecard) and the single-shot `gate_admissible=(VALID && trials>1)` guard.
- Pinned invariants → `invariants.json`. Created two detached worktrees at `4bd7bcf`: `arm-A` (assisted), `arm-B` (unassisted).
- Dispatched both arms as background sonnet subagents, each bound to its worktree cwd, verbatim task, tool line the only difference.
