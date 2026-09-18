---
review_of: cdocs/proposals/2026-09-17-mcp-tool-effectiveness-ablation.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-17T18:09:26-07:00
task_list: cdocs/mcp-ablation
type: review
state: live
status: done
tags: [fresh_agent, implementation_review, runtime_validated, test_plan, orchestration, honesty_gate, ablation]
---

# Review: /cdocs:ablate implementation (round 1)

> BLUF(claude-opus-4-8/cdocs/mcp-ablation): The deterministic mechanics and honesty gate meet the verification floor: I re-ran the unit suite (43/43 pass, exit 0), confirmed no bare `git stash`, verified the meter reads the real `totalTokens`/`totalDurationMs` fields with placeholder aliases, and confirmed the VALID/VOID/TASK-FAIL precedence and single-shot `gate_admissible:false` guard. Verdict: **Accept** with non-blocking should-fixes. The one substantive gap is that the Phase-4 graphify CLI-first usage detection is described in the SKILL but not actually executable by `ablate.sh detect-usage` (it inspects `tool_use.name` only, which is `"Bash"` for a CLI call), so that path currently resolves via the documented sentinel fallback only.

## What was reviewed

- Skill spec: [`plugins/cdocs/skills/ablate/SKILL.md`](../../plugins/cdocs/skills/ablate/SKILL.md)
- Helper script: [`plugins/cdocs/skills/ablate/ablate.sh`](../../plugins/cdocs/skills/ablate/ablate.sh)
- Unit tests: [`plugins/cdocs/skills/ablate/test-ablate.sh`](../../plugins/cdocs/skills/ablate/test-ablate.sh)
- Against proposal: [`cdocs/proposals/2026-09-17-mcp-tool-effectiveness-ablation.md`](../proposals/2026-09-17-mcp-tool-effectiveness-ablation.md)
- Rules: [`orchestration-discipline.md`](../../plugins/cdocs/rules/orchestration-discipline.md), [`model-tiering.md`](../../plugins/cdocs/rules/model-tiering.md), [`frontmatter-spec.md`](../../plugins/cdocs/rules/frontmatter-spec.md)

## Verification floor: empirical evidence

### 1. Unit tests re-run by the reviewer (PASS)

I re-ran `bash plugins/cdocs/skills/ablate/test-ablate.sh` from the repo root myself. Result: **43 passed, 0 failed, exit code 0.** Excerpt:

```
=== TEST 1: worktree isolation off a pinned base, stash stack untouched ===
  PASS: arm A write invisible to arm B (fs isolation)
  PASS: stash stack depth UNCHANGED (never touched) (0)
=== TEST 2: meter aggregation from a MOCK Task result payload ===
  PASS: meter tokens from totalTokens (48213)
  PASS: meter aliases subagent_tokens->tokens (100)
=== TEST 3: transcript tool_use detection + outcome decision fixtures ===
  PASS: VOID precedence over TASK-FAIL (VOID)
=== TEST 4: scorecard single-shot gate_admissible guard ===
  PASS: single-shot VALID gate_admissible=false (false)
  PASS: VOID never admissible even at trials>1 (false)
RESULTS: 43 passed, 0 failed
```

**No worktree leak.** `git worktree list` before and after the run was byte-identical (only `.bare` and `main`); the test's `trap 'rm -rf "$SCRATCH"' EXIT` plus `worktree-remove --force` and a `git worktree prune` clean up fully. No temp dirs leaked.

### 2. No bare `git stash`; fresh-worktree reset; dirty guard (PASS)

`grep -n stash ablate.sh` returns only NEVER-touch documentation comments (lines 22-23, 49, 60, 72); there is **no executable `git stash` / `stash pop`**. Reset is fresh-worktree-based per D1: `cmd_worktree_create` runs `git worktree add --detach "$path" "$commit"` (line 65) off a pinned commit, and `cmd_worktree_remove` captures the diff then `git worktree remove --force "$path"` (line 83). The dirty-tree guard is present (lines 57-62): `worktree-create` dies with an explicit "invoking tree is dirty" message unless `--allow-dirty`, and Test 1b confirms both the refusal and the override empirically.

### 3. Meter reads the REAL field names, aliased; no fabrication (PASS)

`cmd_meter` (lines 172-173) reads `$r.totalTokens // $r.subagent_tokens // null` and `$r.totalDurationMs // $r.duration_ms // null`: the live `toolUseResult` names are primary, the proposal's placeholders (`subagent_tokens`/`duration_ms`) are aliased as fallbacks. It unwraps `toolUseResult` when the payload wraps it (line 166). No number is invented: every field comes from the payload or is `null`. Test 2 confirms both the real-name read (`totalTokens` -> `48213`) and the alias path (`subagent_tokens` -> `100`). The SKILL's NOTE (lines 193-196) correctly documents that both naming surfaces genuinely exist, so the aliasing is deliberate, not a bug.

### 4. Outcome logic and precedence (PASS)

`cmd_decide` (lines 199-225) implements the taxonomy exactly:
- **VOID/unavailable**: `tool_granted == false`.
- **VOID/available_unused**: granted but `tool_invocation_confirmed != true`.
- **TASK-FAIL**: treatment occurred but `(A.task_completed != false) and (U.task_completed != false)` is false.
- **VALID**: both complete and tool used.

**VOID precedence over TASK-FAIL is structural**, not incidental: the `elif` chain tests both VOID reasons before the completion test, so an unused-AND-incomplete assisted arm resolves VOID. Test 3 Case E confirms this directly (`VOID precedence over TASK-FAIL (VOID)`). `cmd_scorecard` sets `gate_admissible = ($valid and ($trials > 1))` (line 261), so VOID, TASK-FAIL, and single-shot VALID all yield `false`; every path still emits `scorecard.json` + `scorecard.md`. Test 4 confirms a VOID run emits a scorecard with `gate_admissible:false` and `context_gap:null`, and stays non-admissible even at `trials 3`.

### 5. Overseer thinness (PASS)

SKILL lines 17-30 ("Overseer discipline") instruct the invoking session to DISPATCH the two arms and the evaluator as subagents and explicitly forbid inline arm work, citing the contamination rationale ("Doing an arm's work inline would ... contaminate the ablation with the overseer's own tokens"). Only `ablate.sh` mechanics run inline. This obeys `orchestration-discipline.md` Pillar 1 (dispatch-by-default, judgment in subagents). The evaluator defaults to opus (SKILL line 200, "dispatch ONE evaluator subagent on opus (D5)"), matching `model-tiering.md`'s judgment tier with the consumer-floor caveat noted.

### 6. Transcript tool-use detection (PASS for `mcp__`, GAP for CLI-first)

`cmd_detect_usage` (lines 124-137) matches the proposal's definition for MCP tools: it counts `tool_use` blocks whose `.name == $tool or endswith("__" + $tool)`, so an errored call still counts (it inspects presence, not result), and a bare tool name matches the `mcp__<server>__<tool>` form. Test 3 confirms used/unused/bare-name detection. This is the general case and it is solid.

**The graphify CLI-first path is the gap (see should-fix S1).** SKILL Phase 4 (lines 260-262) says the usage check for a CLI-shaped tool "detects the CLI invocation in the transcript (a `Bash` `tool_use` running the graphify CLI)" and instructs the caller to "pass the CLI's invocation signature as `--tool`." But `detect-usage` only reads `tool_use.name`, which for a shell-out is `"Bash"`: the graphify command lives in `.input.command`, which the jq never inspects. So passing a graphify CLI signature as `--tool` matches nothing and returns `unused` (a false VOID), and passing `--tool Bash` would match *every* Bash call indiscriminately. The described primary CLI-detection mechanism is therefore not executable by the helper as written; only the documented sentinel-marker fallback would work for the graphify dogfood.

## Section-by-section findings

### Deterministic mechanics (`ablate.sh`)
The script is well-scoped to the D6 mandate (mechanics only, judgment deferred to subagents), defensively coded (`set -euo pipefail`, `need git; need jq`, explicit `die` on missing inputs), and the jq transforms are readable and correct. **Non-blocking.** Two minor robustness notes:
- `decide` treats a `null` `task_completed` as "not false" => completed (line 208). If the overseer forgets to pass `--task-completed`, an arm silently defaults to completed, which could mask a TASK-FAIL. A stricter default (null => unknown => refuse) would be safer, but the SKILL does instruct the overseer to record it per arm, so this is a nit.
- `resolve-transcript` falls back to the newest sidechain transcript when the agentId prefix does not resolve (lines 110-112). For the assisted arm that fallback could resolve the *wrong* arm's transcript and corrupt the usage gate. Low risk since `agentId` comes from the payload, but worth a guard or a loud warning on fallback.

### Honesty gate (usage precondition)
Faithful to the proposal's central discipline: "treatment absent != no effect." VOID is a distinct logged state with a `void_reason` distinguishing `unavailable` from `available_unused` (fix differs, per proposal Edge Cases). This is the load-bearing property and it is correct and tested. **Non-blocking.**

### Dispatch instructions coherence (SKILL Step 2 + gating)
SKILL Step 2 (line 88) says "Dispatch both arms as `general-purpose` subagents," but the "Per-arm single-tool gating" section (lines 165-179) requires each arm to carry an explicit allowlist differing by exactly the one target entry. `general-purpose` is a fixed `tools: *` agent type: dispatching both arms as `general-purpose` would grant the MCP tool to BOTH arms, so the withhold is not expressible that way. The WARN block (lines 176-179) honestly flags that the exact per-dispatch grant expression is unconfirmed and defers it to the top-level e2e test, which is the correct posture for a subagent-authored round. But the two passages are in tension as written and an e2e executor will need them reconciled. **Non-blocking (should-fix S2), because the live dispatch is legitimately deferred.**

### Scope correctly deferred
The three-subagent live dispatch and the graphify dogfood are correctly deferred to a top-level e2e test (SKILL lines 269-277): a subagent cannot call `Task`, so this is out of reach by design and is NOT penalized. Phase 3 (N-trials) is deferred with `trials`/`spread` present as forward-compatible stubs (scorecard schema carries both; `spread` is `null`). This matches the round's stated scope.

### Proposal frontmatter
The proposal was flipped to `status: implementation_wip` (proposal line 8). That value is **not in the enumerated `frontmatter-spec.md` status set** (valid: `request_for_proposal`, `wip`, `review_ready`, `implementation_ready`, `evolved`, `implementation_accepted`, `done`). It reads intuitively, but it is off-spec. Either revert to `wip` (losing the accepted-design signal, though `last_reviewed` preserves it) or add `implementation_wip` to the spec deliberately. **Non-blocking (should-fix S3), a triage/frontmatter item.**

## Verdict

**Accept.**

The round-1 scope is the deterministic mechanics, the honesty gate, and coherent dispatch instructions for a later e2e test. Every verification-floor item passes under my own re-run: 43/43 tests, no bare `git stash`, real-field metering with correct aliasing, VALID/VOID/TASK-FAIL with VOID precedence, universal `scorecard.json` emission, single-shot `gate_admissible:false`, opus evaluator, and `mcp__` tool-use detection. No finding is blocking for this round. The should-fixes below should be resolved before the Phase-4 graphify e2e relies on the CLI-detection path.

## Action Items

1. **[should-fix] Make graphify CLI-first usage detection executable (S1).** Either extend `ablate.sh detect-usage` to inspect `tool_use.input.command` (match the graphify CLI signature inside a `Bash` block) in addition to `.name`, OR make the SKILL Phase-4 text commit to the sentinel-marker fallback as the graphify usage signal rather than implying `--tool <cli-sig>` works with the current matcher. As written the described primary path returns a false `unused`.
2. **[should-fix] Reconcile "dispatch as general-purpose" with single-tool gating (S2).** SKILL Step 2 names `general-purpose` (fixed `tools: *`, grants the MCP tool to both arms) while the gating section requires explicit per-arm allowlists differing by one entry. Clarify the concrete grant/withhold expression the e2e executor should use, or note that a custom agent definition / per-dispatch allowlist is required and `general-purpose` is illustrative only.
3. **[should-fix] Resolve the `implementation_wip` frontmatter status (S3).** It is off the `frontmatter-spec.md` enum. Revert to `wip` or add the value to the spec deliberately.
4. **[nit] Harden `decide` null-completion default.** `task_completed == null` currently reads as completed; consider treating a missing completion flag as unknown and refusing rather than silently passing.
5. **[nit] Guard `resolve-transcript` newest-sidechain fallback.** Emit a loud warning (or refuse) when the agentId prefix does not resolve, since the fallback could bind the wrong arm's transcript into the usage gate.

## Clarifications for the overseer (multiple choice)

- **On S1 (graphify CLI detection), which resolution does the workstream want?**
  1. Extend `detect-usage` to scan `.input.command` for a caller-supplied CLI signature (keeps a uniform "invoked?" mechanism across MCP and CLI tools).
  2. Commit graphify to the sentinel-marker fallback and adjust the SKILL Phase-4 text accordingly (smaller change, but leans on arm-behavior instrumentation the proposal's Investigation Requested flagged as a potential confound).
  3. Defer both to the e2e round and only annotate the current mismatch as a known gap now.

- **On S3 (frontmatter status), preference?**
  1. Add `implementation_wip` to `frontmatter-spec.md` as a first-class in-progress-implementation status.
  2. Revert the proposal to `wip` and rely on `last_reviewed.status: accepted` to carry the design-accepted signal.
