---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-08T11:20:42-07:00
task_list: cdocs/delete-ablate
type: proposal
state: live
status: implementation_ready
tags: [claude_skills, ablation, minimalism]
---

# Delete `/cdocs:ablate`

> BLUF(claude-opus-5-5/cdocs/delete-ablate): Delete the `/cdocs:ablate` skill (`SKILL.md`, `ablate.sh`, `test-ablate.sh`) and every live reference to it.
> Its `detect-usage` subcommand survives unchanged as the repo-internal `scripts/detect-usage.sh`, with its 11 tests moved to `scripts/detect-usage.test.sh`, because the graphify-overhaul verification relies on it and a plain transcript grep false-positives.
> Across three runs the skill changed no decision, and its single-shot scorecards cannot gate anything by construction.
>
> - **Motivated By:** `cdocs/devlogs/2026-10-08-graphify-overhaul.md` (maintainer, 2026-10-08: "If ablate in this case failed to produce any useful information, /cdocs:rfp deleting it."), `cdocs/reviews/2026-10-08-review-of-graphify-overhaul-impl-r2.md`

> NOTE(claude-opus-5-5/cdocs/delete-ablate): Maintainer direction, 2026-10-08: delete `/cdocs:ablate`, and keep `detect-usage` "around as a script for internal use", repo-internal under `scripts/` and not shipped in the plugin.
> The decision is made, so this proposal goes straight to `/cdocs:iterate` without a propose-revise loop.

## Objective

`/cdocs:ablate` (896 lines: `SKILL.md` 291, `ablate.sh` 387, `test-ablate.sh` 218) answers "did this tool help?" with a single-shot A/B scorecard.
Each run needs a top-level session, two arm worktrees, an evaluator, and in practice a container plus a sandboxed headless `claude -p` overseer.
Single-shot scorecards are `gate_admissible: false` by construction, and the multi-trial mode that could gate (Phase 3) does not exist.
Removing the skill cuts a skill, a script, and a test suite that is not wired into CI, none of which has produced a decision.

## Evidence

| Run | Task | Result | Changed a decision? |
|---|---|---|---|
| Probe A, 2026-09-18 ([devlog](../devlogs/2026-09-18-ablate-e2e-probeA-inject-rules.md)) | graphify on `inject-rules.ts`, single file | VALID, `context_gap` 0, n=1 | No. A harness shakeout; it found two harness defects (jq `label`, `^` anchor). Its null was framed as "expected-null, not disconfirming", which only steered later tasks to multi-file shapes. |
| Probe B, 2026-09-18 ([devlog](../devlogs/2026-09-18-ablate-e2e-probeB-void.md)) | trivial `README.md` append | VOID `available_unused`, no evaluator | No. A self-test of the honesty gate. |
| graphify-cdocs-integration spot-check ([devlog](../devlogs/2026-09-23-graphify-cdocs-integration-full-send.md)) | planned "validation of record" on multi-file tasks | never run | No. The proposal reached `implementation_accepted` without it. |
| graphify-overhaul weftwise, 2026-10-08 (`cdocs/_media/2026-10-08-graphify-ablation-weftwise-*`, impl devlog Round 3) | blast radius of `currentDocumentRefAtom` | VALID, `context_gap` +1, n=1, tokens -2% | No. The evaluator credits graphify with 2-3 tail entries, and the base query never matched the target atom. The r2 reviewer places it between decision-map rows 2 and 3, "closer to 2", and recommends a multi-trial repeat that `/cdocs:ablate` cannot run. |

Zero of three executed runs changed a decision.
The `/cdocs:ablate` arc itself ([`2026-09-17-mcp-ablation-iterate.md`](../devlogs/2026-09-17-mcp-ablation-iterate.md)) built and e2e-verified the harness, and that verification is the arc's only output.

## Proposed Solution

Move `detect-usage` out, then delete the skill and every live reference.

**`scripts/detect-usage.sh`:** a standalone bash script holding `cmd_detect_usage` from `ablate.sh` with identical matching behavior.
- Interface: `bash scripts/detect-usage.sh --transcript <jsonl> --tool <sig>`, printing `used` or `unused` and exiting 0 either way; missing or unreadable arguments exit non-zero with a message.
- `<sig>` is an MCP tool name, matched against `tool_use` `.name` exactly or as a `__<name>` suffix, or `cli:<regex>`, matched against Bash `tool_use` `.input.command` per command segment (split at `&&`, `||`, `;`, `|`) and against the whole string.
- It needs only `jq`; the `ablate.sh` assoc-array `parse_args` is replaced by a two-flag `case` loop.
- Its header comment states its purpose (transcript tool-usage check for verification steps) without naming the deleted skill.

**`scripts/detect-usage.test.sh`:** the `detect-usage` fixtures and 11 checks from `test-ablate.sh` TEST 3 (MCP full and bare name, CLI used/unused/no-false-positive/regex, caret anchor through a `cd` prefix, and the mid-string-argument negative), self-locating `detect-usage.sh` beside it.
The worktree, meter, decide, and scorecard tests go with the skill.

**Footprint:**

| File | Change |
|---|---|
| `plugins/cdocs/skills/ablate/` | Delete (`SKILL.md`, `ablate.sh`, `test-ablate.sh`). |
| `plugins/cdocs/skills/oversee-workstream/SKILL.md` line 8 | Drop `ablate` from the loop list: `` (`/cdocs:iterate`, `propose-revise`, `full-send`, `oversee-many`) ``. |
| `CLAUDE.md` Skills line | Drop `ablate` from the skill list. |
| `plugins/cdocs/README.md` | Drop the `/cdocs:ablate` row from the skills table. |
| `cdocs/proposals/2026-10-08-graphify-overhaul.md` Verification Methodology | Add one NOTE after the host-stub check list: `detect-usage` now lives at `scripts/detect-usage.sh` (same flags, same matching); the step text stays as written. |
| `cdocs/proposals/2026-09-27-clauthier-improvement-verification.md` | Add one NOTE under the BLUF: `/cdocs:ablate` is deleted (link this proposal), so an elaborator picks a different instrument. |

Confirmed absent, so no change: the `graphify-scope` comment (`plugins/cdocs/bin/graphify-scope` is gone from `main`), `.github/`, `package.json`, `plugins/cdocs/AGENTS.md`, `plugins/cdocs/bin/README.md`, `plugins/cdocs/rules/`, and the root `README.md`.
`scripts/build-opencode.ts` copies `skills/` generically, so the OpenCode build drops `skills/ablate/` on rebuild with no code change.
`2026-09-17-mcp-tool-effectiveness-ablation.md` is already `archived`/`evolved`; historical devlogs, reviews, and accepted proposals stay as written.

## Design Decisions

- **`scripts/`, not `plugins/cdocs/bin/`:** the only consumer is this repo's own verification text, and `bin/` would put it on every consuming project's `PATH` as a supported command.
- **Keep the jq filter rather than a grep:** a plain grep also matches the signature inside dispatch prompts, tool results, and quoted reports, so it false-fails the graphify-overhaul "Overseer clean" check.
- **No CI or npm wiring for the moved tests:** `test-ablate.sh` was never wired, and adding a pipeline step for an internal helper is scope this deletion does not need.
- **A NOTE, not a rewrite, in graphify-overhaul:** that proposal is `implementation_accepted`; its verification records what ran, so only the path pointer is new.
- **No replacement A/B shape:** every decision so far was made on design grounds; a lighter `/cdocs:report` A/B section can be proposed if a need appears.
- **Phase 3 and the graphify multi-trial follow-up go with the skill:** decision-map row 2 versus row 3 for graphify is the maintainer's call on design grounds, outside this proposal.

## Test Plan

1. `bash scripts/detect-usage.test.sh`: all 11 checks pass, and the exit status is 0.
2. `npm run test:rules`: green, including assertion 6 (every `/cdocs:<name>` in plugin content, `CLAUDE.md`, and the READMEs resolves to a skill or agent), so no stale `/cdocs:ablate` remains.
3. `npm run test:opencode`: green, and `build/cdocs/opencode/skills/ablate/` is absent after the build.
4. `grep -rn ablate plugins scripts .github CLAUDE.md README.md` prints nothing.
   The listed exceptions are only paths outside that set: historical `cdocs/` documents and the gitignored `build/`.

## Implementation Phases

### Phase 1: Move `detect-usage` to `scripts/`

Create `scripts/detect-usage.sh` and `scripts/detect-usage.test.sh` per Proposed Solution, and add the graphify-overhaul NOTE.
Do not delete `plugins/cdocs/skills/ablate/` yet.
Done when Test Plan step 1 passes and `scripts/detect-usage.sh` matches `ablate.sh detect-usage` output on every moved fixture.
Commit: `feat(scripts): detect-usage as a repo-internal script`.

### Phase 2: Delete the skill and its references

Delete `plugins/cdocs/skills/ablate/`, apply the remaining footprint rows, and run Test Plan steps 1-4.
Commit the deletion and the reference edits separately (`refactor(cdocs): delete /cdocs:ablate`, `docs(cdocs): drop ablate from skill lists`).

## Open Questions

None remain; the RFP's questions are resolved above.

> NOTE(claude-opus-5-5/cdocs/delete-ablate): The RFP's questions resolved as follows: keep `detect-usage` as a repo-internal script (maintainer); no replacement A/B shape; Phase 3 goes with the skill; the deletion follows the `oversee-workstream` landing, so it edits that skill's loop list instead of conflicting with its `ablate/SKILL.md` edit.
