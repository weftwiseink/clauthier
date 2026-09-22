---
review_of: cdocs/devlogs/2026-09-22-agent-dispatch-labeling.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-22T11:20:00-07:00
task_list: meta/agent-dispatch-labeling
type: review
state: live
status: done
tags: [fresh_agent, meta, tooling, agent-dispatch, runtime_validated, commit_hygiene]
---

# Review: Agent Dispatch Labeling Implementation (Turn 1.b)

## Summary Assessment

This reviews the implementation the dispatched implementer landed for proposal `2026-09-22-label-implementer-proposer-agents.md` (status `implementation_wip`): create `cdocs:implementer` / `cdocs:proposer` agent files with `general-purpose` capability parity, relabel the two dispatch sites, update consistency docs, and pick a `model:`-field option under the proposal's Phase 1 empirical gate.
The implementation is correct, complete, and faithful to the spec: I independently reproduced the `npm run build:cdocs` re-run (6 agents, no model warning, no emitted model line) and every static grep the implementer cited, and all 11 scrutiny points pass on substance.
The only findings are non-blocking hygiene notes: the implementer's commit `1b070a3` swept in an overseer-owned Dispatch/Return Events row (correct content, wrong committer boundary), and a pre-existing out-of-scope inconsistency (`iterate/SKILL.md` line 83 still dispatches `subagent_type: "reviewer"` rather than `cdocs:reviewer`).
**Verdict: Accept.**

## Section-by-Section Findings

Findings are keyed to the 11 scrutiny points, each independently verified against source and (where empirical) re-run.

### 1. Tool allowlist parity — PASS
Both `implementer.md:7` and `proposer.md:7` carry `tools: "*"`, byte-identical to `general-purpose` / `reviewer.md`. No narrowing. Non-blocking.

### 2. Skill preloading — PASS
`implementer.md:8-9` preloads `cdocs:implement`; `proposer.md:8-9` preloads `cdocs:propose`. Matches `reviewer.md`'s `skills: [cdocs:review]` pattern exactly.

### 3. Startup rule-reading pattern — PASS
Both new agents carry the `## Startup` section with the relative-path (`rules/writing-conventions.md`, `rules/frontmatter-spec.md`) then `plugins/cdocs/rules/*.md` fallback and the SessionStart-hook NOTE, matching the `reviewer.md`/`judge.md`/`nit-fix.md`/`triage.md` convention. Not a reinvented pattern. (Minor: the two files list `writing-conventions.md` before `frontmatter-spec.md`, the reverse of `reviewer.md`'s order; both files are present, this follows the proposal's own example ordering, cosmetic only.)

### 4. The `model:` field decision — PASS, empirically re-verified
The implementer chose option (B): omit `model:` entirely, replacing it with a 3-line `#` YAML comment documenting the deliberate no-pin intent.
I independently confirmed the mechanism and the outcome:
- `build-opencode.ts` `MODEL_MAP` (lines 57-61) covers only `haiku`/`sonnet`/`opus`; `generateOCFrontmatter` guards emission with `if (cc.model)` (line 179) and warns on an unmapped alias (lines 181-183). An `inherit` value would therefore both warn and emit an invalid `model: inherit` line, exactly as the earlier proposal review cited.
- The `#` comment is inert to the converter: `parseFrontmatter`'s key regex `^(\w[\w-]*?):` (line 144) does not match a `#` line, so `cc.model` stays undefined and no model line is emitted.
- I re-ran `npm run build:cdocs`: `Converting 6 agents...` / `Agents converted: 6`, and **no** `Unknown model alias` warning. `grep -n '^model:' build/cdocs/opencode/agents/{implementer,proposer}.md` returns nothing (exit 1). The only warnings emitted are the pre-existing `Unknown CC tool ""*""` lines, which `reviewer.md` also produces.

Option (B) is the exact behavioral match for `general-purpose`'s no-pin state and the OC-clean outcome with zero code change. The rejection of option (C) (`inherit` + MODEL_MAP entry) is sound: `inherit` has no concrete OC model to map to. Correct call, correctly justified. Non-blocking.

### 5. Dispatch-site relabeling correctness — PASS
- `iterate/SKILL.md:74` literal is now `subagent_type: "cdocs:implementer"` (grep-confirmed).
- `iterate/SKILL.md:43` (Roles/Implementer) reads `cdocs:implementer` — the description line was updated consistently, not just the literal.
- `propose-revise/SKILL.md:46` (Proposer) reads `cdocs:proposer`, and `:47-48` (Reviser) explicitly reuses `cdocs:proposer` with the reuse rationale folded in. Both roles updated, not just the proposer. The truncated Reviser line was completed as reported.

### 6. Path-restriction hook (the trap) — PASS
`validate-cdocs-edit-path.sh:16` is unchanged: `CDOCS_AGENTS="triage nit-fix reviewer"`, no `implementer`/`proposer` added, `git status --porcelain` clean for the file. The maintenance comment (lines 8-9) that invites adding new agents was correctly NOT followed — confining these repo-wide/proposal-authoring roles would be an out-of-scope capability change. README line 123 correspondingly still describes only `triage, nit-fix, reviewer` as restricted, consistent with the unchanged allowlist.

### 7. README updates — PASS
`README.md:104` lists all six agents (`nit-fix`, `triage`, `reviewer`, `judge`, `implementer`, `proposer`) in the path-resolution sentence; `README.md:170` OC-support table reads `6 agents converted to OC frontmatter format` (was 4).

### 8. Completeness / residue check — PASS, characterization accurate
`grep -rn 'general-purpose' plugins/cdocs/` returns only: the two new agent files' intentional prose/comment documenting the catch-all they replace (`implementer.md:4,38`, `proposer.md:4,39`), and `ablate/SKILL.md:95-96` (an unrelated tool-gating discussion, not an implementer/proposer/reviser dispatch). No stray `subagent_type: "general-purpose"` for these roles survives anywhere. The implementer's characterization is exact.

### 9. Devlog hygiene / single-writer ownership — PASS with a non-blocking commit-hygiene caveat
The implementer correctly authored only implementer-owned content: it appended the iterate-phase `## Changes Made` rows, added the `### Implementer Notes` subsection, and filled `## Verification`. It did NOT edit the Iteration Log, Judge Log, or Steering Log (all still overseer-managed).
**Caveat:** commit `1b070a3` (the implementer's own commit, carrying its Notes and Verification) also introduced a `dispatch` row into the overseer-owned `## Dispatch/Return Events` table (the Turn 1.a `impl-1` row, timestamp `10:50`). The row's content is unambiguously overseer-voiced and dispatch-time-stamped, so the most likely story is that the overseer wrote it into the working tree at dispatch and the implementer's commit swept in the uncommitted change, rather than the implementer authoring an overseer table. The matching `return` row and the `rev-1` dispatch were cleanly committed separately by the overseer in `e0104bd`. Either way this is a commit-boundary blur with correct content, not a content breach. Recommend the overseer commit its own Dispatch/Return rows before dispatching so the ownership boundary stays legible in history. Non-blocking.

### 10. Commit hygiene — PASS
All 7 reported commits exist (`2987f74`, `21ea8cc`, `ae91a18`, `815655f`, `5cad16a`, `9ea3d77`, `1b070a3`), each is small and single-purpose (1-2 files apart from the devlog commit), uses conventional-commit prefixes (`feat`/`docs` scoped `agent-dispatch-labeling`), and ends with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`. The `feat` vs `docs` split (new capability files as `feat`, doc-consistency as `docs`) is appropriate. Commit bodies are technically precise and brief per repo convention.

### 11. Proposal status — PASS
Proposal frontmatter `status: implementation_wip` (set by `2987f74`), not prematurely `implementation_accepted`. Correct: only a human sets the accept transition.

## Additional Observations (non-blocking, out of scope)

- **Stale `reviewer` literal (pre-existing).** `iterate/SKILL.md:83` still dispatches `subagent_type: "reviewer"`, whereas the Roles line (`:44`), the template (`cdocs:reviewer`), and the live dispatch registry all use `cdocs:reviewer`. `git log -S` attributes this literal to `c942196`, well before this change, and `ae91a18` did not touch it — so it is genuinely pre-existing and correctly out of scope for a proposal that scoped `reviewer` out. It is nonetheless a real inconsistency (and, since the registered type is `cdocs:reviewer`, a possibly-nonresolving literal) worth a one-line follow-up fix in a separate change.
- **Iteration Log still empty.** The overseer-owned `## Iteration Log` table has no row yet for this iteration. That is an overseer responsibility at the Decide turn, not an implementer gap, and outside this implementation-review's target; flagging only so the overseer populates it on accept.
- **`tools: "*"` OC mapping (pre-existing).** The converter maps `tools: "*"` to `read/edit/write/bash: false` and warns `Unknown CC tool ""*""` — the new agents inherit `reviewer.md`'s exact (imperfect) behavior. Correctly identified as pre-existing and out of scope by the implementer.

## Verdict

**Accept.**

The implementation is complete and faithful to the accepted proposal across all four phases. Every substantive scrutiny point passes, the one non-obvious design decision (model-field omission) is the correct, empirically-validated choice, and I reproduced the build and grep evidence rather than taking it on report. The two findings are non-blocking hygiene items that do not require a revision round: the commit-boundary blur (item 9) has correct content, and the `reviewer`-literal inconsistency is pre-existing and explicitly out of scope. The proposal is correctly parked at `implementation_wip` for the human accept transition and the deferred live `usage.db` self-classification smoke test (a separate top-level invocation).

## Action Items

1. [non-blocking] Overseer: commit Dispatch/Return Events rows in overseer-authored commits (not swept into the implementer's commit) so the single-writer boundary stays legible in git history. Going forward.
2. [non-blocking][out-of-scope follow-up] Fix the pre-existing `iterate/SKILL.md:83` `subagent_type: "reviewer"` literal to `cdocs:reviewer` in a separate change, matching the Roles/template/registry naming.
3. [non-blocking] Overseer: populate the `## Iteration Log` row for this iteration at the Decide turn before recording Accept.
4. [deferred] Run the proposal's live-dispatch + `usage.db` model/agent_type check as a separate top-level `/cdocs:iterate` (or `/cdocs:propose-revise`) invocation to confirm the labels reach the DB; this cannot run inside a dispatched subagent (no `Task`).
