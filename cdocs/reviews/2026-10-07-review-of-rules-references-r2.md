---
review_of: cdocs/proposals/2026-10-07-rules-references.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T21:59:08-07:00
task_list: cdocs/rules-references
type: review
state: live
status: done
tags: [rereview_agent, rules_delivery, test_plan, verification_gate, proportionality]
---

# Review: Rules References (Round 2)

## Summary Assessment

The revision fixes both round-1 blocking items.
Phase 3 is now "keep `cdocs.md`, drop the import", the hook is unchanged, and the check resolves against source headings, with `--materialized` run on real init output.
Phases 1 and 2 are ready.
The unrequested removal of the TypeScript init-list assertion is correct: the bash guard already covers that invariant, and the widened CI paths now trigger it.
One new problem blocks acceptance: phase 3's gate is "`rules_check` passes with no import line", and recorded runs show `rules_check` failing 3 of 5 assertions *with* the import (0 of 6 runs pass on haiku or sonnet).
As written, the gate stops phase 3 every time, for a reason unrelated to the import.
Verdict: **Revise**, with one narrow blocking item (replace the gate) and a few nits.

## Round-1 action items

| # | Item | Status |
|---|---|---|
| 1 | Phase 3 to "keep `cdocs.md`, drop the import"; fix table attribution; per-file as follow-up | Resolved. The table charges import dedup and the `CLAUDE.md` edit to the import column; per-file is a recorded follow-up. |
| 2 | Remove simulated materialization; resolve against source; `--materialized` in `init_real` | Resolved (section 2, "Source headings in CI, real output in `init_real`"). |
| 3 | Accept ` > `; reword "bans nothing" | Resolved: both separators are accepted, and "These are rejected outright" / "It rejects only what cannot resolve downstream" now agree with assertion 3. |
| 4 | Keep `inject-rules.test.ts` contingent; do not settle the RFP question | Resolved: the hook is untouched, and the RFP keeps its scope ("This proposal leaves all of it there"). |
| 5 | State the no-import `rules_check` gate | Done as asked, but the gate itself does not work; see the blocking finding below. That part of the round-1 advice was wrong: it did not check `rules_check`'s baseline. |
| 6 | Scope `nit-fix` to two rules; list `nit-fix.md:26,82` | Resolved, and `:37` was added. |
| 7 | Sentinel proof | Resolved (Verification step 4); step 3 is now a `/context` check, not an em-dash proxy. |
| 8 | NOTEs for `build-opencode.ts` and report section 13; trim fixtures | Resolved: section 4 bullets; assertion 5 has the three fixtures plus a positive ` > ` case. |
| 9 | Why not `opencode-build.yml` | Resolved (section 2, last paragraph). |

## Section-by-Section Findings

### Removal of the TypeScript init-list assertion

The claim holds.

- `chat-record.test.sh:129-130` is in `unit_suite` and checks `init_rule_order | sort` against `ls *.md | sort` in `rules/`.
  `init_rule_order` (`:792`) extracts the `[Full content of X.md, frontmatter stripped]` lines of init step 6.
  Sorted-list equality catches a missing file, an extra or stale name, and a duplicate.
  A future filename outside `[a-z-]` would make the extractor drop it and the check fail loudly, never pass silently.
- `cdocs-hooks.yml` runs `chat-record.test.sh --unit` (blocking, ubuntu and macOS), but today its `paths` cover only `bin/**`, `hooks/**`, and the workflow file, so a rule rename or an edit to `skills/init/SKILL.md` does not trigger it.
  Phase 2 widens `paths` to `plugins/cdocs/**`, which covers both.
  Phases 1 and 2 land together, so no window opens.
- After phase 3, step 3 concatenates a glob and step 5 copies "each rule file", so step 6 is the only enumerated list, and that list is exactly what the bash guard checks.
- Assertion 2's argument ("the existing guard keeps init's rule list equal to `rules/`, so source headings are the materialized headings") is therefore sound, and `--materialized` in `init_real` checks real output.

Keeping one guard rather than moving it into TypeScript is the more minimal choice, and the revision should keep it.

### Phase 3 gate (section 3, Phase 3 step 1, Verification step 2)

- **Blocking: the gate cannot pass, and it would not prove re-injection if it did.**
  `rules_check` tests resumption behavior: `chat-record path` first, devlog read, record tail read.
  It does not test whether the rules are in context.
  Recorded runs: "fails 3 of 5 assertions ... identically on the pre-change tree (0 of 6 runs pass across haiku and sonnet, baseline and new)" ([decomposition devlog](../devlogs/2026-10-06-rules-context-decomposition-full-send.md) line 81), and the [resumption RFP](../proposals/2026-10-05-post-compaction-resumption-rfp.md) tracking that failure is `deferred`.
  The gate as written ("If it fails, revert the fixture ... and stop") therefore ends phase 3 with the import still in place, for a reason unrelated to the import.
  It also fails in the other direction: the compaction summary can carry "run `chat-record path`" forward, so a pass would not show that unscoped rules were re-injected.
  Replace it with a direct presence probe that the summary cannot carry.
  Put a canary line in the fixture's `.claude/rules/cdocs.md` with no import (for example "The cdocs canary word is `<random>`."), never mention it before compaction, and run one trivial turn, `/compact`, then "Without tools, what is the cdocs canary word? Say UNKNOWN if it is not in your context."
  Pass if the reply contains the word.
  This costs three short turns on haiku through the existing `drive` helper.
  Run it once as a one-off probe recorded in the devlog, like the rows-1-and-4 probes in the Background NOTE, rather than as a new suite scenario.
  A control run with the import line is optional; it costs one more run and rules out a broken probe.
  `rules_check` can stay in the phase as a no-regression check (the same assertions pass with and without the import), not as the gate.
- The rest of the gate's shape is fine: it comes first, it is cheap, it fails safe (phase 3 stops and phases 1-2 are unaffected), and "revert the fixture, record, stop" is clear.

### Hash-change nudge (section 3)

Acceptable.
The SessionStart nudge on a hash change is the designed delivery mechanism, and any rule edit triggers it, including the uncommitted `overseers.md` edit in this tree.
The cost is one `/cdocs:init` run per initialized project, which the user can ignore.
Leaving the hook untouched is the right call for a minimal design.

- **Non-blocking: the story depends on release coupling.** "A consumer upgrades the plugin ... `/cdocs:init` ... removes the import line" holds only if phase 3 ships in the same plugin release as phase 2's rule edits.
  If phase 3 ships later, it changes no rule body and so no hash, and projects that already re-ran init keep the import until the next rule edit.
  That is harmless (the probe shows the file loads once), but the proposal should say it: ship phases 2 and 3 in one release when the gate passes, or accept the lag.

### Remaining over-engineering

The design is now close to minimal.
OpenCode is touched only by a comment in `build-opencode.ts`, and removing the skill relative links fixes dead OpenCode links as a side effect.
Two small items remain:

- **Non-blocking: the alphabetical concatenation change has a weak rationale.** "(the hook's hash order)" does not matter: the hash covers raw sorted files and ignores the order of `cdocs.md`.
  The real benefit is that step 3 no longer refers forward to step 6, which is reasonable, but it is optional churn.
  Either drop it or state that reason.
  If it stays, phase 3 should also switch `init_rules` (`:802`) to `ls *.md | sort` and fix the comment at `:791` ("its AGENTS.md block, which step 3 follows"), or the fixture stops matching real init.
- **Non-blocking: the `${CLAUDE_PLUGIN_ROOT}/rules/...` exception is unused.** No scanned file uses it (only the excluded `init/SKILL.md` does), and allowing it contradicts "Agents rely on context, with no fallback read".
  Dropping the exception simplifies assertion 3 and removes an unverified claim that Claude Code substitutes the variable in agent bodies.

### Test Plan and phases

- **Non-blocking:** phase 3 step 3 should state that `init_real`'s existing assertion `"CLAUDE.md imports the rules"` (`chat-record.test.sh:821`) is inverted, not added to.
- **Non-blocking:** the header comment of `cdocs-hooks.yml` lists the suites it runs; the new `rules` job should be added to it.
- Phase 1's "hit list matches the audit" is still achievable: no double-quoted or curly-quoted `CDocs ` string exists in scanned content today, so the extractor starts with no false positives.
  Every rule has exactly one H1 outside fences and no duplicate headings, so assertion 1 passes on the current tree.

## Verdict

**Revise.**
Phases 1 and 2 and the delivery design are acceptable as written, and so is the removal of the init-list assertion.
The single blocking item is the phase 3 gate: `rules_check` fails on the baseline with the import, so it cannot gate removing the import, and it does not measure re-injection.
Replacing it with a canary presence probe is a one-paragraph change.
The overseer can verify that change directly without a full review round.

## Action Items

1. [blocking] Replace the phase 3 gate (section 3 paragraph 4, Phase 3 step 1, Verification step 2, Test Plan row 4): a one-off post-compaction canary probe in a no-import fixture, passing when the model reports a rule-file canary it never saw before `/compact`. Keep `rules_check` only as a no-regression comparison against the with-import baseline.
2. [non-blocking] State that phase 3 should ship in the same plugin release as phase 2's rule edits, or that consumers keep a harmless import line until the next rule change.
3. [non-blocking] Drop the alphabetical-order change, or justify it as removing step 3's forward reference to step 6; if kept, update `init_rules` (`:802`) and the comment at `:791`.
4. [non-blocking] Drop the `${CLAUDE_PLUGIN_ROOT}/rules/...` allowance from assertion 3.
5. [non-blocking] Phase 3 step 3: say that `init_real`'s "CLAUDE.md imports the rules" assertion (`:821`) is inverted.
6. [non-blocking] Mention the `rules` job in the `cdocs-hooks.yml` header comment.

## Questions for the author

1. Phase 3 gate:
   (a) one-off canary probe, recorded in the devlog (recommended);
   (b) canary probe added to `chat-record.test.sh` as a permanent `--only` scenario;
   (c) defer phase 3 until the resumption RFP fixes `rules_check`.
2. Concatenation order:
   (a) keep step 6 order and drop the change (recommended, least churn);
   (b) alphabetical, with the fixture updated to match.
