---
title: "/cdocs:ablate e2e probeB — VOID honesty path (available_unused)"
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-18T00:00:00-07:00
task_list: cdocs/mcp-ablation
type: devlog
state: live
status: done
tags: [ablation, e2e, graphify, mcp-effectiveness, overseer, void, honesty-gate]
---

# BLUF

Ran `/cdocs:ablate` as top-level overseer for the **VOID honesty-path** probe: a
trivial task (append `<!-- checked -->` to `README.md`) that does NOT need graphify.
The assisted arm HAD graphify on PATH but, correctly, never invoked it. The harness
resolved **VOID / `available_unused`** — not a false "no effect" — with
`gate_admissible: false`. Evaluator skipped per protocol (non-VALID run).

Run dir: `/tmp/ablate-e2e/probeB`.

# What ran

- **Base (D1):** `1708dd8` (HEAD), tested despite unrelated `.lace/*.json` + devlog WIP
  via `--allow-dirty`; WIP deliberately excluded.
- **Task prompt (D4):** passed verbatim to both arms.
- **Tool diff (D4):** target `cli:^graphify `. Assisted = base + graphify CLI on PATH
  (`/usr/local/bin/graphify`, `GRAPHIFY_OUT=/var/cache/graphify`); unassisted = base
  minus graphify.
- **Both arms** dispatched as general-purpose capability, each bound to its own detached
  worktree at the pinned base. Both completed; **byte-identical diffs** (blob `acd5303`).

## How the withhold was expressed (CLI-first tool)

graphify is CLI-first (its MCP is shadowed by the lace over-mount bug), so it surfaces
as a `Bash` shell-out, not a gateable `mcp__` tool. A single-tool `tools:`-allowlist
withhold is therefore **not expressible at CLI granularity** — both arms necessarily
hold `Bash`. Per precondition (a)'s profile-omission fallback, the withhold was
expressed at the **instruction level**: the unassisted arm was told graphify is
unavailable and must not be invoked; the assisted arm was told it is available. Every
other capability identical. Recorded in `invariants.json`.

# Honesty gate detail

- `detect-usage --tool 'cli:^graphify '` → **`unused`**.
- Cross-checked with the SKILL-recommended safe form `cli:graphify ` → also `unused`.
  The `^`-anchor bug (a `cd <wt> && graphify` prefix yielding a false `unused`) is a
  concern only when the tool WAS used; here the assisted arm's only two `tool_use`
  blocks were `cat` and `printf` on `README.md`, so `unused` is correct on the merits
  and the two signatures agree.
- `decide` precedence: granted=true, invoked=false → **VOID / available_unused**
  (treatment absent ≠ no effect). Completion asymmetry never consulted (VOID beats
  TASK-FAIL).

# Scorecard (single-shot, INDICATIVE only)

| axis | assisted | unassisted | delta | weight |
|---|---|---|---|---|
| tokens | 21104 | 21170 | -66 | corroborating |
| wallclock (ms) | 8137 | 12200 | -4063 | INDICATIVE only |

- `context_gap`: null (not rendered — VALID+evaluator only).
- `gate_admissible`: **false** (`trials==1`), as expected.

# Outcome

The VOID honesty path holds end-to-end: a present-but-unused tool reports VOID with a
reason, never a spurious "no effect," and the single-shot guard keeps the run
non-admissible. Complements probeA (VALID, context_gap 0). No harness defects surfaced
this run; the `^`-anchor sharp edge remains documented (SKILL Phase 4 + probeA warning).
