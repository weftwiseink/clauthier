---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T11:20:42-07:00
task_list: cdocs/delete-ablate
type: proposal
state: live
status: request_for_proposal
tags: [future_work, claude_skills, ablation, minimalism]
---

# Delete `/cdocs:ablate`

> BLUF(claude-opus-5-5/cdocs/delete-ablate): Delete the `/cdocs:ablate` skill: across three runs it has changed no decision, and its one design-relevant run (graphify weftwise, `context_gap` +1, n=1) landed between two decision-map rows, deferring the answer to a multi-trial Phase 3 that does not exist.
> The open point is `ablate.sh detect-usage`, which the graphify-overhaul verification uses and which a plain transcript grep does not replace faithfully.
>
> - **Motivated By:** `cdocs/devlogs/2026-10-08-graphify-overhaul.md` (maintainer, 2026-10-08: "If ablate in this case failed to produce any useful information, /cdocs:rfp deleting it."), `cdocs/reviews/2026-10-08-review-of-graphify-overhaul-impl-r2.md` (branch `graphify-overhaul`)

## Objective

`/cdocs:ablate` (896 lines: `SKILL.md` 291, `ablate.sh` 387, `test-ablate.sh` 218) answers "did this tool help?" with a single-shot A/B scorecard.
Each run needs a top-level session, two arm worktrees, an evaluator, and in practice a container plus a sandboxed headless `claude -p` overseer.
Single-shot scorecards are `gate_admissible: false` by construction, so no run can gate anything, and the multi-trial mode that could (Phase 3) is deferred.
Removing it cuts a skill, a script, and an untested-in-CI test suite that have produced no decision.

## Evidence

| Run | Task | Result | Changed a decision? |
|---|---|---|---|
| Probe A, 2026-09-18 ([devlog](../devlogs/2026-09-18-ablate-e2e-probeA-inject-rules.md)) | graphify on `inject-rules.ts`, single file | VALID, `context_gap` 0, n=1 | No. A harness shakeout; it found two harness defects (jq `label`, `^` anchor). Its null was framed as "expected-null, not disconfirming", which only steered later tasks to multi-file shapes. |
| Probe B, 2026-09-18 ([devlog](../devlogs/2026-09-18-ablate-e2e-probeB-void.md)) | trivial `README.md` append | VOID `available_unused`, no evaluator | No. A self-test of the honesty gate. |
| graphify-cdocs-integration spot-check ([devlog](../devlogs/2026-09-23-graphify-cdocs-integration-full-send.md)) | planned "validation of record" on multi-file tasks | never run | No. The proposal reached `implementation_accepted` without it. |
| graphify-overhaul weftwise, 2026-10-08 (branch `graphify-overhaul`: `cdocs/_media/2026-10-08-graphify-ablation-weftwise-*`, impl devlog Round 3) | blast radius of `currentDocumentRefAtom` | VALID, `context_gap` +1, n=1, tokens -2% | No. The evaluator credits graphify with 2-3 tail entries, and the base query never matched the target atom. The r2 reviewer places it between decision-map rows 2 and 3, "closer to 2". It recommends a multi-trial repeat, which `/cdocs:ablate` cannot run. Row 2 versus row 3 is still the maintainer's call. |

Zero of three executed runs changed a decision.
The `/cdocs:ablate` arc itself ([`2026-09-17-mcp-ablation-iterate.md`](../devlogs/2026-09-17-mcp-ablation-iterate.md)) built and e2e-verified the harness, and that harness verification is the arc's only output.

## Scope

- Delete `plugins/cdocs/skills/ablate/` (`SKILL.md`, `ablate.sh` and all its subcommands, `test-ablate.sh`).
  `test-ablate.sh` is not wired into `.github/workflows/` or `package.json`, so no CI step changes.
- Remove `ablate` from the `CLAUDE.md` skills list and the `/cdocs:ablate` row in `plugins/cdocs/README.md`.
- OpenCode: `scripts/build-opencode.ts` copies `skills/` generically, so `build/cdocs/opencode/skills/ablate/` drops out on rebuild. Confirm `npm run test:opencode` and `npm run test:rules` stay green.
  `plugins/cdocs/AGENTS.md` and other skills do not reference it.
- `plugins/cdocs/bin/graphify-scope` carries one comment naming the ablate spot-check (on `main` only, since the graphify-overhaul branch deletes the file).
- graphify-overhaul branch: its proposal's Verification uses `ablate.sh detect-usage` for the stub run's Secondary check and both Overseer-clean checks, and it specifies the weftwise ablation. Its impl devlog lists a multi-trial ablation as future work.
  Decide how this deletion is ordered against that branch landing.
- `detect-usage` replacement: a plain `grep` of the transcript also matches the signature where it appears in dispatch prompts, tool results, and quoted reports, so it can false-fail an Overseer-clean check.
  The faithful equivalent is the ~10-line `jq` filter over `Bash` `tool_use` `.input.command`, split at shell separators.
- Proposal states: archive `2026-09-17-mcp-tool-effectiveness-ablation.md`. Add a NOTE to `2026-09-17-graphify-cdocs-integration.md` and `2026-09-27-clauthier-improvement-verification.md` (an RFP that names ablate as its instrument).
  Historical devlogs and reviews stay as written.

## Open Questions

- **Full deletion or keep `detect-usage`?** Options: inline the `jq` filter in the graphify-overhaul Verification; move it to a small `plugins/cdocs/bin/` helper as a general transcript tool-usage check; or drop it and accept a grep with known false positives.
- **Does a lighter manual A/B note in `/cdocs:report` replace it?** For example, an "A/B" analysis shape: the same prompt to two dispatches, a reviewer comparison, and the result stated as n=1 anecdote. Or nothing, given every decision so far was made on design grounds.
- **What happens to the deferred multi-trial Phase 3?** It goes with the skill unless someone wants it as a standalone proposal. If it goes, close the graphify-overhaul multi-trial follow-up (impl-r2 recommendation 5), or turn it into hand-aggregated repeats, and decide row 2 versus row 3 on design grounds.
- **Ordering:** should the deletion wait for graphify-overhaul to land, or should that branch's Verification text be changed first?
