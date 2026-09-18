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
- **Both arms completed** (`TASK_COMPLETED: true`). A invoked `graphify explain` (5 tool uses, 31190 tok); B reconstructed by reading the file + `hooks.json` + root `package.json` (4 tool uses, 31031 tok).
- Confirmed live: dispatched-agent transcripts resolve at `<session-dir>/subagents/agent-<agentId>.jsonl` (the SKILL's documented path shape), and the result payload surfaces `subagent_tokens`/`duration_ms` (metered via the aliases in `ablate.sh meter`).

## Two harness defects surfaced + fixed

1. **`jq-1.6` reserves `label`** → `ablate.sh meter`'s `--arg label` + `$label` was a compile error, breaking every meter call under the environment jq. Fixed: renamed the jq binding to `$armlabel` (commit `4f9b353`); `--label` flag + `arm_label` key unchanged; 49/49 unit tests still pass.
2. **`cli:^graphify ` anchor is wrong for worktree-bound arms** → arms wrap every command as `cd <worktree> && graphify …`, so a `^`-anchored signature matches the leading `cd`, never `graphify`, giving a FALSE `unused` (a false VOID on a run where graphify was demonstrably used — the exact dishonesty the gate exists to prevent). Corrected the run to the SKILL's canonical un-anchored `cli:graphify ` (A=used, B=unused, clean discrimination) and hardened the SKILL.md guidance to recommend a command-boundary anchor over `^` (commit `62ee9a5`).

## Outcome

- **VALID** (both completed + assisted verifiably used graphify). Single-shot ⇒ `gate_admissible: false` (expected, correct).
- **context_gap = 0** (opus evaluator): graphify surfaced no load-bearing information B missed; B even added a correct detail A omitted (`tsx ^4.0.0` devDependency). `divergent_paths = true` (structured graph query vs. direct file read, converging on identical evidence).
- Corroborating deltas (indicative only): tokens +159 (assisted spent marginally MORE), wallclock −2904ms. Both within single-shot noise; neither drives a verdict.
- Honest read: on a single-file "explain + enumerate deps + trigger" task, the file is small enough that direct reading fully substitutes for graph scoping — graphify's win case (large blast-radius fan-out) is not exercised here. This is an indicative negative, not a gate verdict.
- Withhold confirmation (per operational ask): expressed at the prompt layer (Agent dispatch exposes no per-call `--disallowedTools`) and CONFIRMED mechanically — `detect-usage` on B's transcript = `unused`; B never referenced graphify.
- Artifacts in `/tmp/ablate-e2e/probeA/`: `invariants.json`, `A/B.payload.json`, `arm-{assisted,unassisted}.meter.json`, `A/B.diff`, `outcome.json`, `eval.json`, `scorecard.json`, `scorecard.md`. Worktrees torn down.
