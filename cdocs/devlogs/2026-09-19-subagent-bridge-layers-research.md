---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-19T10:00:00-07:00
task_list: cdocs/subagent-bridge-layers
type: devlog
state: live
status: wip
tags: [research, subagents, a2a, multi_provider, orchestration]
---

# Subagent bridge layers research: Devlog

## Objective

Problem: CC subagents lack dynamic per-invocation model-tier/effort overrides; some tasks suit other providers/harnesses; dropping in a full third-party harness with a Claude subscription violates TOS.
Question: which projects act as omni-harness bridge layers (A2A-style, preserving interrupts and incremental exchange, not bash-substitution), and how do they compare to native subagents?

## Plan

1. Report A (sonnet): breadth survey of bridge-layer projects, features, tradeoffs.
2. Report B (sonnet): in-depth breakdown of CC subagent features/benefits (parallel with A).
3. Report A supplemental: deeper pro/con vs native for A's top 2 picks.
4. Report C: synthesis with tables and inline SVG diagrams (110ch width, terse).

## Implementation Notes

- 2026-09-19: devlog created; dispatching A and B in parallel.

## Changes Made

| File | Description |
|------|-------------|

## Verification
