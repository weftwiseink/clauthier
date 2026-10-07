---
review_of: cdocs/proposals/2026-10-06-nested-subagent-workflows.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-06T18:52:00-07:00
task_list: cdocs/nested-subagent-workflows
type: review
state: live
status: done
tags: [fresh_agent, implementation_review, runtime_validated, deletion_completeness, sandbox_confinement]
---

# Review: Nested Subagent Workflows Implementation (Round 5, Iterate 1)

> BLUF: **Accept.** Every section 1 row and the section 2 `/oversee` reason landed as specified, the Constraints held, the static grep is clean, build and unit tests pass, and an independent sandboxed re-run reproduces the floor: a depth-1 `cdocs:implementer` dispatched a depth-2 `cdocs:bash-runner`, both `foreground`, with no permission denials.
> One non-blocking but should-fix finding: the devlog's WARN misdiagnoses the `/tmp` escape.
> `agents/bash-runner.md` hardcodes `/tmp/claude-$(id -u)/`, so passing `TMPDIR` into the sandbox (done in this re-run) does not stop it.

## Summary Assessment

The work deletes cdocs' "subagents cannot dispatch" workarounds across nine `plugins/cdocs` files (commits `5b195ce`..`038eec9`), corrects `/oversee`'s reason, files the OC `tools: "*"` RFP (`791138d`), and records a sandboxed live check in the sub-devlog.
The edits match the proposal text closely, read cleanly, and are history-agnostic.
I re-verified the claims myself, reran the live check with a `TMPDIR` fix, and checked the OC build diff against the implementer's pre-edit snapshot.
The only substantive problem is the devlog's wrong root cause for the bash-runner's out-of-sandbox scratch file, which also makes its suggested harness fix wrong.

## Verification (Reviewer-Run)

Artifacts are under the session scratchpad `/tmp/claude-1000/-var-home-mjr-code-weft-clauthier-main/e3afd4a9-4352-482d-ad1a-444fa834254a/scratchpad/rev1/` (ephemeral, so excerpts are inlined).

### Static checks

- The proposal grep (`Investigation Requested|subagent-from-subagent|cannot dispatch|cannot spawn|no \`Task\`|inside a subagent` over `plugins/cdocs`) gives exit 1, no matches.
- A wider sweep (`unavailable`, `can't dispatch/spawn`, `no Task/Agent tool`, `only the overseer can dispatch`, `depth`, plus the original patterns over the repo outside `cdocs/`, `build/`, and `node_modules`) found nothing relevant.
  The remaining `cdocs/proposals` and `cdocs/reports` hits are all historical (`implementation_accepted`, `evolved`, or report) and are correctly left alone.
- `wc -w` over `plugins/cdocs/**/*.md`: `04e2e51` 24117 -> `a45d647` 23849 (-268), matching the devlog.

### Constraints

- `git diff --stat f8cf9f1..HEAD -- plugins/cdocs/hooks scripts/build-opencode.ts plugins/cdocs/skills/devlog plugins/cdocs/rules plugins/cdocs/skills/propose-revise plugins/cdocs/skills/full-send` is empty.
- No `tools:` line changed in `plugins/cdocs/agents` (the `^[+-]\s*tools:` grep over the diff exits 1).
- `iterate` lost only the dispatch-suppression paragraph (a table row), and `oversee` changed only its reason sentence, so no overseer mechanics changed.
- The implementer did not touch the overseer's top-level devlog: no commit in `fc01594^..a45d647` touches `...-propose-revise.md`.
- No historical review or proposal was edited: the only `cdocs/proposals` commit in range is the new RFP.

### Build and tests (`rev1/build.log`, `rev1/chat-unit.log`, `rev1/vcep.log`)

```text
build exit=0   chat exit=0   vcep exit=0
build-opencode: Done.  Agents converted: 7
      3   Warning: Unknown CC tool ""*"" — skipping
chat-record tests: 95 passed, 0 failed
17 passed, 0 failed
```

`diff -rq` of the implementer's `oc-before/` snapshot against the fresh build touches exactly the nine edited agent and skill files.
A grep of that diff for `tools|mode|model|permission|description|read|edit|write|bash|task:` lines exits 1, which confirms the changes are body prose only.

### Live check (`rev1/live-check-rev.sh`, `rev1/live/`)

`live-check-rev.sh` is the implementer's script with two changes: it creates `$SB/tmp` and passes `TMPDIR="$SB/tmp"` through `env -i`.
The isolation is otherwise identical to `chat-record.test.sh`'s `claude_run`: a `git init` fixture under the scratchpad (outside any repo), a sandboxed `CLAUDE_CONFIG_DIR` holding copied credentials, `--plugin-dir`, `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`, `init_rules`, and `--permission-mode bypassPermissions`.
The run used Claude Code 2.1.292 and `--model opus`.

```text
claude exit=0
creds left: 0
2	cdocs:bash-runner	a652930f067136868	foreground
1	cdocs:implementer	-	foreground

agent-a19f4dc3b8c0c1ee0.meta.json: {"agentType":"cdocs:bash-runner",...,"parentAgentId":"a652930f067136868","spawnDepth":2,"requestShape":"foreground","requestNonInteractive":true}
agent-a652930f067136868.meta.json: {"agentType":"cdocs:implementer",...,"spawnDepth":1,"requestShape":"foreground","requestNonInteractive":true}

result: {"subtype":"success","is_error":false,"num_turns":4,"duration_ms":35732,"permission_denials":[]}
agent-a19f4dc3b8c0c1ee0.jsonl: errors=0 tool_uses=Bash
agent-a652930f067136868.jsonl: errors=0 tool_uses=Bash,Bash,Agent cdocs:bash-runner,Bash
refusal grep (Investigation Requested|cannot dispatch|not available inside) over stream + both transcripts: exit 1
fixture: 9b9e03f docs: add greeting implementation sub-devlog / 8802165 feat: add greeting.txt
```

Implementer return (Agent `tool_result`, excerpt):

```text
**Verification:** as the proposal requires, a `cdocs:bash-runner` subagent ran `./run-tests.sh`, so the noise stayed out of my context.
  - Exit code 0, 3002 lines of output.  - `greeting: PASS`  - `SUMMARY: all passed`
There were no deviations from the proposal, and I didn't start a successor sub-devlog.
  - Raw test output (temporary): /tmp/claude-1000/bash-runner.gsTn6m
```

Each failure picture from the proposal's Verification Methodology was checked: no refusal or `## Investigation Requested`, a `bash-runner` is present (so the cue was strong enough), `permission_denials` is `[]` and the bash-runner's one `Bash` call returned `exit=0`, there is no `background` shape, and the grep is clean.
Credentials: the sandbox `cfg/` holds no `.credentials.json` or `.claude.json` after the run, and a `find` for either name under `rev1/live/sb` counts 0.

The run reproduces the confinement escape despite `TMPDIR`: the bash-runner's command was

```text
mkdir -p /tmp/claude-$(id -u); out=$(mktemp "/tmp/claude-$(id -u)/bash-runner.XXXXXX"); cd .../rev1/live/sb/proj && ./run-tests.sh > $out 2>&1; ...
```

`find /tmp -newer marker` outside the scratchpad listed only `/tmp/claude-1000/bash-runner.gsTn6m` (3002 fixture-noise lines), which I moved to `rev1/live/escaped-bash-runner.gsTn6m`.
Meanwhile Claude Code itself honored `TMPDIR`: `rev1/live/sb/tmp/` contains `claude-1000/`, `node-compile-cache/`, and `tsx-1000/`.

## Section-by-Section Findings

### Section 1 table: per-file edits

All rows match.
- **`implement`**: The Top-level contrast is gone, and the Dispatched bullet keeps its signal and isolation.
  "Questions for the user go in your return." and "Give children you dispatch your worktree path: they inherit your isolation." replace the schema and caller paragraph.
  Step 5 reads "the loop's reviewer reviews", and the "Use cdocs skills" dispatched line is deleted.
  The devlog NOTE explains the placement of the worktree sentence after the isolation sentence, which is sound.
- **`implementer`, `proposer`, `triage`, `iterate`**: These are exact deletions, and the surrounding text still reads.
- **`reviewer`**: The bullet reads correctly in its list ("these boundaries" are the sibling bullets).
  Its claim holds: `validate-cdocs-edit-path.sh` gates on `CDOCS_AGENTS="triage nit-fix reviewer"` by `agent_type`, so a child of another type is unbound.
- **`propose`**: The replacement line is clear, and the following "See `/cdocs:implement` Invocation Modes" line still makes sense.
- **`ablate`**: All five sites follow the table, and the graphify container is named only on the dogfood item.
  **Non-blocking:** The NOTE says to run from "a lead with two dispatch layers below it", while the WARN and the "Deferred to the top-level e2e test" section still say "the overseer's top-level e2e test" and "a top-level overseer run".
  The proposal prescribed both texts, so this is not an implementation defect.
  Still, a reader could take "top-level" as a hard requirement that the NOTE no longer imposes.
  The NOTE also does not say why two layers are needed: the arms' own helpers.
- **`implement`, worktree sentence (non-blocking):** "they inherit your isolation" can be read as an automatic platform behavior rather than an obligation the parent creates by passing the path.
  The r4 review raised this point, and the text is as prescribed.
  "they are bound by your isolation" would be unambiguous.
  Neither live run exercised worktree inheritance (both used "no worktree"), as the devlog's evidence-limits NOTE says.

### Section 2: `/oversee`

The text is exact: TOP-LEVEL ONLY and declines-or-advisory are kept, and the reason is now the human gate.
The sentence is history-agnostic.

### Phase 1: RFP stub (`2026-10-06-opencode-wildcard-tools-mapping-rfp.md`)

The stub is adequate: BLUF, Motivated By links, a concrete Objective, a Scope that covers the mapping, permission, `task`, a build-time guard, and CI regression, and Open Questions.
I verified its claims: `mapTools` is at L79, `Edit`/`Write` map to `ask` (L96, L100), and the generated `build/cdocs/opencode/agents/implementer.md` has `read/edit/write/bash: false`.
**Non-blocking:** The RFP quotes the warning as `Unknown CC tool "*"`, but the build prints `""*""`.
`mapTools` receives the YAML value with its quotes intact, so a fix must strip the quotes before matching `*`, or the parser should unquote.
This is worth one line in the RFP's Scope.

### Phase 2: live check and the devlog record

The live check is sound, and my independent re-run agrees on every check, so the floor is met twice.
**Non-blocking, should fix before close:** The devlog WARN says the bash-runner's `mktemp` "falls back to `/tmp/claude-$(id -u)` because `env -i` leaves `TMPDIR` unset", and recommends passing `TMPDIR=$SB/tmp`.
Both statements are wrong: `plugins/cdocs/agents/bash-runner.md:28` hardcodes `mktemp "/tmp/claude-$(id -u)/bash-runner.XXXXXX"`, and my run with `TMPDIR` set still wrote there.
For a sandboxed harness, the leak is in the leaf's prose, not in the harness.
The content is harmless fixture noise, but a future harness author following the WARN would believe the leak is closed.
The fix to `bash-runner.md`, for example `${TMPDIR:-/tmp}/claude-$(id -u)`, which matches what Claude Code itself does, is outside this proposal's scope and belongs in a follow-up.

### Devlog quality

The devlog is clear and resumable, with per-commit tables, baselines, failure pictures, and stated evidence limits.
Its three wording deviations are surfaced in a NOTE.
Apart from the WARN above, every claim I checked (the grep, `wc`, the OC diff, the test counts, constraint adherence) reproduced.

## Verdict

**Accept.**
The implementation faithfully executes the accepted proposal, its Constraints held, and the verification floor reproduces independently.
The findings are non-blocking, and the first one is a cheap correction to the record that should land before the loop closes.

## Action Items

1. [non-blocking, should fix before close] In the sub-devlog's Phase 2 WARN, replace the `TMPDIR` root cause and recommendation: `agents/bash-runner.md:28` hardcodes `/tmp/claude-$(id -u)/`, and a reviewer re-run with `TMPDIR=$SB/tmp` still escaped.
2. [non-blocking] File a follow-up (rfp or small fix) to have `bash-runner` honor `TMPDIR` (`${TMPDIR:-/tmp}/claude-$(id -u)`), so sandboxed runs stay confined.
3. [non-blocking] Add one Scope line to the OC wildcard RFP: the parsed value is the quoted `"*"` (the warning prints `""*""`), so unquoting is part of the fix.
4. [non-blocking] Optionally align `ablate`'s "top-level e2e test" and "top-level overseer run" wording with its NOTE ("a lead with two dispatch layers below it"), and say why two layers are needed.
5. [non-blocking] Optionally reword "they inherit your isolation" to "they are bound by your isolation" in `implement`.

## Questions for the Maintainer

- How should the bash-runner `/tmp` escape be handled?
  (a) A devlog correction only.
  (b) A devlog correction plus a one-line `bash-runner.md` fix in a follow-up commit.
  (c) A devlog correction plus an rfp covering scratch-path confinement for all agents.
