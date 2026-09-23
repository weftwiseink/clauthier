---
review_of: cdocs/proposals/2026-09-22-haiku-bash-wrapper.md
first_authored:
  by: "@claude-fable-5-1"
  at: 2026-09-23T10:01:09-07:00
task_list: meta/token-spend-attribution
type: review
state: live
status: done
tags: [fresh_agent, runtime_validated, architecture, verification, test_plan, data, hooks, context-management]
---

# Review: Haiku Bash-Output Wrapper: `cdocs:bash-runner` + Deterministic Floor

> BLUF(fable/haiku-bash-wrapper-review): **Revise.**
> The core shape (opt-in haiku runner + settings-level floor, custom `PostToolUse` hook deferred) is right and the four open questions are resolved below.
> Three findings are blocking because they are empirical, not stylistic: (1) the proposal's new Finding 2 is wrong on the installed version, `PreToolUse` `updatedInput` DOES rewrite Bash commands on 2.1.280 (2/2 headless runs), while the `PostToolUse` `updatedToolOutput` regression is confirmed; (2) `bashOutputMaxChars` is not a head/tail clip for valid results, it spills to a file with a ~2,000-char preview plus path, which changes the cap's cost model and the Edge Cases; (3) that same limit applies to the runner's own Bash call, so the runner cannot "read the whole output once" and must capture-to-file-then-extract, which changes its Workflow, Output contract, Constraints, and the containment canary.
> Item 4 (cap range) is now backed by a measured per-call distribution: 4,000-6,000 chars is p90-p95 of 11,531 real Bash results, a defensible outlier boundary; recommend starting at the upper end.

## Summary Assessment

The proposal operationalizes the landscape report into a haiku `cdocs:bash-runner` agent plus a `bashOutputMaxChars` floor delivered as `/cdocs:init` guidance, and it correctly refuses to build anything on `PostToolUse` `updatedToolOutput`.
The document is well-structured, cites its sources with direct links, and its division-of-labor reasoning is sound.
Its weakness is that it reasoned about platform behavior from issue text rather than testing it: one of its two "both channels are inert" claims does not reproduce here, and its model of what the cap does (head/tail truncation) does not match the documented and observed spill-to-file behavior.
Neither error invalidates the design, but both propagate into the agent Workflow, the Output contract, the Edge Cases, and the Verification Methodology, so the proposal needs a revision pass before it is implementation-ready.

## Resolutions to the Investigation Requested Items

### Q1: `Bash`-only vs. `Bash`+`Read` for `cdocs:bash-runner`

**Verdict: `Bash`-only is correct. Keep it, and inline the contract.**

Reasoning:
- The one thing `Read` would buy, reading a spilled output file, is unnecessary once the runner captures to a file itself (see Finding B3): every extraction it needs (`grep -n`, `head`, `tail`, `sed -n`, `wc -c`) is shell.
  `Read` would also be a worse fit: it prepends line numbers and has its own 2,000-line default window, both of which add noise to a haiku extractor.
- Rule-loading has no consumer here.
  The runner emits a fixed-format block and enforces no writing convention, so reading `writing-conventions.md` + `frontmatter-spec.md` (~180 lines) on every dispatch is 2-3k haiku input tokens per call for zero output effect.
  `nit-fix` reads rules because rules ARE its rubric; that does not transfer.
- Cross-target is clean: `scripts/build-opencode.ts` `mapTools` turns `tools: Bash` into `bash: true` with `read/edit/write: false`, so the narrowing survives the OC build (Test Plan "Cross-target" will pass as written).
- CC subagent docs confirm `tools` is an allowlist (a `tools: Bash` agent gets Bash and nothing else, including no MCP tools) and that `haiku` is a valid `model` alias.

Two non-blocking additions to the frontmatter while there: `maxTurns` (as `judge.md` does) to bound a haiku runner that loops on extraction, and consider `omitClaudeMd: true` since the runner has no use for the consuming project's `CLAUDE.md` and it is pure per-dispatch overhead.

### Q2: Should `/cdocs:init` offer to apply `bashOutputMaxChars` with consent?

**Verdict: document-only, as proposed. Defer a consent-gated write to a follow-up.**

Reasoning:
- `/cdocs:init` has no JSON-merge, scope-selection, or idempotency machinery for `settings.json`; it materializes markdown with a hash marker.
  A consent-gated write would need all three (project vs. local vs. user scope is itself a policy choice) and would be the first time cdocs touched harness config.
  That is a separate proposal's worth of surface, not a bullet in Phase 2.
- The right value is consumer-specific in a way the data makes concrete (see Q4): the cap is a cliff to a ~2k preview, and its net effect depends on how often that consumer's agents read the spilled file back.
  Documenting the range with the tuning caveat is the honest deliverable; auto-applying a number is not.
- The `update-config` skill already exists for the consumer to apply it; the guidance should say so and include a copy-pasteable snippet.

One concreteness gap, non-blocking but should be fixed in revision: name the carrier file.
`/cdocs:init` step 6 enumerates rule files by name for the `AGENTS.md` block, so a NEW `rules/*.md` file requires editing the init skill, whereas a new section in an existing rule file (for example, a "Bash output hygiene" section in `orchestration-discipline.md`, next to the disposability guidance the proposal already wants to extend) rides the existing pipeline and hash marker with zero init changes.
Recommend the latter; the "init guidance-delivery test" then reduces to "the rule file contains the text and init materializes it."

### Q3: Is dropping the rewrite lever correct, and do mechanisms 1+2 suffice without 3?

**Verdict: 1+2 suffice and mechanism 3 should stay optional/deferred, but the proposal's stated reason is factually wrong and must be replaced.**

The coverage analysis, using the actual (spill-to-file) semantics:

| Case | Covered by | Outcome |
|---|---|---|
| Anticipated verbose, dispatched | 1 (runner) | Parent sees the fixed-format report only |
| Unanticipated verbose, exit 0 | 2 (cap) | Parent sees ~2k preview + file path; bounded, nothing lost, recoverable via read-back |
| Unanticipated verbose, non-zero exit | 2 (cap) | Parent sees a head+tail excerpt, no file path; bounded, but a mid-log error CAN be lost; recovery is a re-run through 1 |

The third row is the only real gap, and mechanism 3 (nudge or rewrite) does not close it: both fire only on a fixed pattern allowlist, and the observed outliers are not on any plausible allowlist.
The 15 largest Bash results in the corpus (all 22k-29k chars) are `git diff`, `grep -rn` sweeps, `find`, and `for f in ...; cat` loops over `cdocs/` and source; none is `npm install`, `docker build`, or `terraform`.
A blind `| tail` rewrite on a `grep` sweep would also destroy the signal (the matches ARE the output), so even a working rewrite lever is a poor fit for the traffic that actually dominates.
So: 1+2 cover it; 3 is redundant with 1's convention and mis-targeted for the whales; keep it deferred.

What must change is the justification.
**`PreToolUse` `updatedInput` is not dead on the installed version.**
See Finding B1 for the reproduction.
The proposal must stop citing [#79321](https://github.com/anthropics/claude-code/issues/79321) as "confirmed broken here" and instead record: reported broken on 2.1.215 Windows desktop; works on 2.1.280 Linux headless (2/2); status is environment-dependent, gate on the canary.
The table row flips from "Dead" to "Works here; not adopted (redundant with 1+2, allowlist misses observed whales)."

### Q4: Validate the 4,000-6,000 char starting range against per-call data

**Verdict: the range is reasonable, and it is no longer unbacked: it sits at p90-p95 of a measured distribution. Start at the upper end.**

Nothing in `cdocs/reports/` has a per-call Bash distribution (searched; the landscape report and read-source report both say so).
But the read-source report's corpus is local (`~/.claude/projects/*weftwise*` JSONL, main + `subagents/`), so I measured it with the same method (inline `tool_result` chars joined to the `Bash` `tool_use` by `tool_use_id`, same file; window 2026-09-12 onward).
Script in the Appendix; it matches the report's mean (400 vs. 390 tok/result), which validates the join.

**weftwise, 2026-09-12 to 2026-09-23: 2,997 files, 11,531 Bash results, 18.47M chars.**

| Stat | Chars |
|---|---:|
| mean | 1,602 (~400 tok) |
| p50 | 655 |
| p75 | 1,841 |
| p90 | 3,978 |
| p95 | 6,228 |
| p99 | 14,103 |
| max | 29,351 |

| Cap | Results over cap | Chars above cap (share of all Bash chars) |
|---:|---:|---:|
| 2,000 | 2,674 (23.2%) | 7.98M (43.2%) |
| 4,000 | 1,141 (9.9%) | 4.52M (24.5%) |
| 6,000 | 606 (5.3%) | 2.85M (15.4%) |
| 8,000 | 385 (3.3%) | 1.88M (10.2%) |
| 10,000 | 258 (2.2%) | 1.24M (6.7%) |
| 30,000 | 0 | 0 |

Interpretation:
- "Generous enough not to clip ordinary output, tight enough to bound outliers" is now a checkable statement: 4k clips the top 10%, 6k the top 5%.
  Both are defensible outlier boundaries.
- Because a valid over-cap result collapses to a ~2k preview (Finding B2), the inline saving per spilled result is `n - ~2,100`, not `n - cap`, so realized savings are larger than the "chars above cap" column (at 4k, roughly 36% of Bash chars rather than 24.5%) BUT every spilled result is a candidate for a read-back that re-ingests it whole.
  That cliff argues for starting at 6,000 (or 8,000: 3.3% of calls spilled, still a 10% direct cut) rather than 4,000, and for the guidance to say explicitly "if you find agents reading spilled files back, raise the cap."
- Recommend the proposal cite these numbers (or reproduce them) in mechanism 2 in place of "the corpus has no per-call distribution."
- The cross-check on this repo's own transcripts (45 results since 2026-09-12, max 4,958) is too small to inform the number.

## Section-by-Section Findings

### Verification of the Load-Bearing Hook Claim

**B1 [blocking]: Finding 2 does not reproduce on 2.1.280; Finding 3's "presumed live" is wrong for one of the two channels.**

I ran a headless haiku session under a throwaway `--settings` file with a `PreToolUse` Bash hook returning `permissionDecision: allow` + `updatedInput: {command: "echo REWRITE_APPLIED"}` and a `PostToolUse` Bash hook returning `updatedToolOutput: "SENTINEL_REPLACED_OUTPUT"`, prompt "run `echo ORIGINAL_OUTPUT` and reply with the verbatim tool result."
Result, 2/2 runs, `claude 2.1.280`, Linux, `claude -p`:

- Transcript `tool_use.input.command` = `echo ORIGINAL_OUTPUT` (the model's request).
- Transcript `toolUseResult.stdout` = `REWRITE_APPLIED`; model's reply = `REWRITE_APPLIED`.
  The rewritten command executed. **`PreToolUse` `updatedInput` works for Bash here.** [#79321](https://github.com/anthropics/claude-code/issues/79321) is either fixed after 2.1.215 or platform-specific (it was filed from the Windows desktop app).
- The `PostToolUse` hook fired (logged) and the sentinel never reached the model.
  **[#68951](https://github.com/anthropics/claude-code/issues/68951) reproduces: `updatedToolOutput` is inert for Bash.** Finding 1 stands.

Required changes: rewrite Finding 2 and Finding 3 to state the empirical result and its scope (headless, Linux, 2.1.280; interactive mode not tested); fix the BLUF's "the report's proposed `PreToolUse` command-rewrite interim lever is ALSO dead" and "the only viable hook lever is an advisory block-and-nudge"; fix the Summary's "Both hook-based rewrite channels for the built-in Bash tool are inert"; flip the division-of-labor table row.
Keep mechanism 3 deferred on the Q3 grounds above.
Adopt the canary as the documented re-check for BOTH channels (it costs about one cent); the exact procedure is in the Appendix, and the Deferred section's "trigger to pick it back up" should reference it.

### Proposed Solution, mechanism 2 (deterministic floor) and Important Design Decisions

**B2 [blocking]: the cap is modeled as head/tail truncation; for valid results it is spill-to-file with a fixed preview.**

Per the CC tools reference (and observed directly inside this subagent: `seq 1 20000` returned "Output too large (106.3KB). Full output saved to: <path>. Preview (first 2KB): 1 2 3 ..."):

- **Valid result** (exit 0): inline up to the ceiling (~30,000 default; `bashOutputMaxChars` sets it, up to 128,000, v2.1.261+); past it, the model gets a file path plus a preview of up to the first ~2,000 chars, and reads or searches the file if it needs more.
- **Failure result**: inline up to ~10,000; past it, a head-and-tail excerpt cut from the read-back window, no file path.
- `bashOutputMaxChars` sizes the inline ceiling and the read-back window together and makes CC ignore `BASH_MAX_OUTPUT_LENGTH`; the env var only enlarges the read-back window and does not raise the inline ceiling.

Consequences the proposal must absorb:
- "Both narrow the existing head/tail cap" and the Design Decisions bullet "a blind cap ... uses middle-truncation and drops an error line buried in the middle" are wrong for the valid case and only right for the failure case.
  The buried-error argument for the wrapper survives, but its precise form is: for a FAILED verbose command the platform gives a lossy excerpt with no file, so the middle is unrecoverable without a re-run; for a valid one the middle is on disk and costs a read-back.
- The cap is a cliff, not a clip: a 4,100-char result under a 4,000 cap becomes ~2,000 chars + path, and an agent that then `Read`s the file re-ingests it whole (plus line-number overhead).
  Add an Edge Case: "spill-then-read-back can cost more than the uncapped result; the guidance must tell consumers to raise the cap if that pattern shows up."
- Test Plan "Deterministic cap" must assert the spill shape (preview + path), not "truncated to the cap."
- Flag for Phase 2 verification: whether `bashOutputMaxChars` also bounds the failure-path excerpt (docs say the excerpt is "cut from the read-back window," which the setting sizes), and whether the ~2,000-char preview is fixed or scales.

### Proposed Solution, mechanism 1 (`cdocs:bash-runner`)

**B3 [blocking]: the ceiling applies to the runner's own Bash call, so the runner cannot "read the whole output once"; the Workflow must capture-to-file-then-extract.**

Nothing exempts a subagent's Bash tool from the inline ceiling (observed above, inside a subagent).
So dispatching `seq 1 200000` to the runner as specified in Verification Methodology step 2 puts a ~2k preview and a path into the runner's context, and a `Bash`-only runner asked for "the last line" cannot get it from the preview.
The design claim "the haiku agent reads the whole output once in disposable context and returns the buried needle" is false for exactly the outputs the runner exists for.

The fix is small and makes the agent better, so it should be written into the Workflow, not left to the implementer:

1. Run the requested command with capture: `OUT=<scratch>/bash-runner-<ts>.log; <cmd> > "$OUT" 2>&1; echo "exit=$?"`.
   This also keeps the tool result "valid" from the platform's perspective regardless of the command's exit status, so the full output is always on disk and the failure-path excerpt loss never applies.
2. Extract with shell over the file, each call bounded: `wc -c "$OUT"`, `grep -nE '<salience pattern>' "$OUT" | head -n N`, `tail -n N "$OUT"`, `head -n N "$OUT"`.
3. Report.

Knock-on edits:
- **Output contract**: the last line becomes `Full output: saved to <path> (<K> chars)` by default; "discarded (lives only in this subagent transcript)" is no longer accurate, since the runner's transcript holds only excerpts.
  The "do not re-save a second copy" language is moot: the file is the primary capture, not a copy.
  Keep the "nothing is silently destroyed" intent by stating the path and its lifetime (scratch dir; say whether it is cleaned).
- **Constraints**: "run exactly the one requested command" must become "run the requested command exactly once; bounded extraction commands over the capture file are expected; no other commands, no re-runs, no dispatch."
  A haiku agent reading the current text literally will refuse to `grep` its own capture file.
- **Test Plan**: add "runner under a low cap": with `bashOutputMaxChars` set low, the runner still returns the true last line of `seq 1 200000`.
  This is the test that proves the runner is robust to mechanism 2, which the two mechanisms need to be since they ship together.
- **Verification Methodology** step 3-4 stay the containment floor; step 5's negative control must describe the real direct-call outcome (preview + path in the parent, and the cost the wrapper saves is the read-back), not "raw output enters the parent."
- **Edge Cases**: add binary or very-long-line output (`grep -a`, `cut -c1-N` in the extraction step) and the capture file's location/lifetime.

### Proposed Solution, dispatch scope

**N1 [non-blocking]: the "when to dispatch" list is ordered by intuition, not by the observed traffic.**

It leads with build logs, test suites, and package installs; the measured whales are wide `grep -rn`/`find`/`git diff`/multi-file `cat` sweeps.
Reorder to lead with sweeps, and extend the salience-spec examples with aggregate shapes those need ("matches per file, first 3 per file", "changed-file list plus hunk counts"), because for a sweep the matches ARE the signal and a head/tail extract is the wrong default heuristic.

### Implementation Phases

**N2 [non-blocking]: Phase 2 does not name the carrier for the init guidance.** See Q2; recommend a section in an existing rule file.

**N3 [non-blocking]: Phase 1 should list the capture-to-file workflow and `maxTurns` as deliverables** once B3 is folded in, so the implementer's success criteria include the low-cap runner test.

### Frontmatter and writing conventions

Frontmatter is valid and complete.
Direct links, sentence-per-line, and spaced-hyphen usage are compliant.
One mild history-framing point, non-blocking: the Summary and Verification sections narrate the re-verification as an event ("was re-run", "tightens rather than loosens").
After the B1 correction, consider stating the verified facts in present tense and leaving the narrative to the devlog, which already carries it.

## Verdict

**Revise.**

The architecture is accepted in shape: haiku runner as primary, settings cap as floor, custom `PostToolUse` hook deferred, mechanism 3 deferred.
The four open questions are resolved above and should be folded in as decisions, not left as NOTEs.
Blocking items B1-B3 are each a factual correction with mechanical consequences; none requires a new design, and a single revision round should clear them.

## Action Items

1. [blocking] Rewrite Findings 2-3, the BLUF, the Summary, and the division-of-labor row: `PreToolUse` `updatedInput` works for Bash on 2.1.280 Linux headless (2/2); `PostToolUse` `updatedToolOutput` confirmed inert; mechanism 3 stays deferred on redundancy/mis-targeting grounds, not on "broken."
2. [blocking] Replace the head/tail model of `bashOutputMaxChars` with the documented spill-to-file (valid) / head+tail excerpt (failure) semantics in mechanism 2, Design Decisions, Edge Cases (add spill-then-read-back), and the "Deterministic cap" test.
3. [blocking] Specify capture-to-file-then-extract in the runner Workflow; update the Output contract's last line to `saved to <path>` by default; loosen Constraints to permit bounded extraction over the capture file; add the "runner under a low cap" test; fix Verification Methodology steps 2 and 5 accordingly.
4. [non-blocking] Fold the Q1-Q4 resolutions in as decisions: `Bash`-only stays; init is document-only with the carrier file named; cite the measured distribution in mechanism 2 and start the recommended value at 6,000 (state 4,000-8,000 as the tunable band).
5. [non-blocking] Add the hook-channel canary (Appendix) as the documented re-check procedure in the Deferred section.
6. [non-blocking] Reorder the dispatch list to lead with sweeps and add aggregate salience-spec examples.
7. [non-blocking] Add `maxTurns` and consider `omitClaudeMd: true` in the runner frontmatter.

## Questions for the Maintainer

1. Starting cap in the init guidance:
   (a) 4,000 (p90, largest cut, most read-back risk),
   (b) 6,000 (p95, reviewer's recommendation),
   (c) 8,000 (p97, most conservative),
   (d) state only the band and let consumers pick.
2. Mechanism 3, now that the rewrite lever works here:
   (a) keep deferred (reviewer's recommendation),
   (b) promote a tiny rewrite hook for a hand-picked allowlist,
   (c) delete the section entirely.
3. Runner capture-file location:
   (a) the subagent's scratchpad directory,
   (b) `mktemp -d` under `$TMPDIR`,
   (c) a caller-supplied path.

## Appendix: Reproduction Procedures

### Hook-channel canary (both channels, one call, about $0.01 on haiku)

`settings.json` (temporary, passed via `--settings`, never written to the repo):

```json
{"hooks":{
  "PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"node <dir>/pre.mjs","timeout":5}]}],
  "PostToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"node <dir>/post.mjs","timeout":5}]}]}}
```

`pre.mjs` writes `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":{"command":"echo REWRITE_APPLIED"}}}` to stdout; `post.mjs` writes `{"hookSpecificOutput":{"hookEventName":"PostToolUse","updatedToolOutput":"SENTINEL_REPLACED_OUTPUT"}}`.

```sh
env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT claude -p --model haiku --settings ./settings.json \
  --allowedTools "Bash(echo:*)" --output-format json \
  'Run exactly this bash command: echo ORIGINAL_OUTPUT   Then reply with ONLY the verbatim text that the Bash tool returned to you, nothing else.'
```

Read `result`: `ORIGINAL_OUTPUT` means neither channel works; `REWRITE_APPLIED` means `updatedInput` works and `updatedToolOutput` does not; `SENTINEL_REPLACED_OUTPUT` means `updatedToolOutput` works.
Confirm against the session transcript's `tool_use.input.command` and `toolUseResult.stdout`.
Observed on 2.1.280: `REWRITE_APPLIED`, twice.

### Per-call Bash size distribution

Node script, same join as the read-source report (inline `tool_result` chars, matched to the `Bash` `tool_use` by `tool_use_id` within the same JSONL file; walks `<projects-dir>/*<substring>*/**/*.jsonl` including `subagents/`; filters lines by `timestamp >= <since>`).

```js
import { readdirSync, createReadStream } from "node:fs";
import { join } from "node:path";
import { createInterface } from "node:readline";
const [, , root, substr, since] = process.argv;
const sinceTs = since ? Date.parse(since) : 0;
const walk = (d, o = []) => { for (const e of readdirSync(d, { withFileTypes: true })) { const p = join(d, e.name); e.isDirectory() ? walk(p, o) : e.name.endsWith(".jsonl") && o.push(p); } return o; };
const files = readdirSync(root).filter((d) => d.includes(substr)).flatMap((d) => walk(join(root, d)));
const sizes = [];
for (const f of files) {
  const ids = new Map();
  for await (const line of createInterface({ input: createReadStream(f), crlfDelay: Infinity })) {
    let o; try { o = JSON.parse(line); } catch { continue; }
    if (sinceTs && o.timestamp && Date.parse(o.timestamp) < sinceTs) continue;
    const c = o?.message?.content; if (!Array.isArray(c)) continue;
    for (const x of c) {
      if (x?.type === "tool_use" && x.name === "Bash") ids.set(x.id, x.input?.command ?? "");
      else if (x?.type === "tool_result" && ids.has(x.tool_use_id)) {
        const t = typeof x.content === "string" ? x.content : Array.isArray(x.content) ? x.content.map((y) => y?.text ?? "").join("") : "";
        sizes.push(t.length);
      }
    }
  }
}
sizes.sort((a, b) => a - b);
const N = sizes.length, total = sizes.reduce((s, n) => s + n, 0), pct = (p) => sizes[Math.min(N - 1, Math.floor(p * N))];
console.log({ N, total, mean: total / N, p50: pct(.5), p75: pct(.75), p90: pct(.9), p95: pct(.95), p99: pct(.99), max: sizes[N - 1] });
for (const cap of [2000, 4000, 6000, 8000, 10000, 30000]) { const over = sizes.filter((n) => n > cap); console.log(cap, over.length, over.reduce((s, n) => s + n - cap, 0)); }
```

Invocation used: `node bash-size-dist.mjs ~/.claude/projects weftwise 2026-09-12T00:00:00Z`.
