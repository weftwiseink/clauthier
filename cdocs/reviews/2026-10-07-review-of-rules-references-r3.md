---
review_of: cdocs/proposals/2026-10-07-rules-references.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T22:03:47-07:00
task_list: cdocs/rules-references
type: review
state: live
status: done
tags: [rereview_agent, runtime_validated, verification_gate, rules_delivery, test_plan]
---

# Review: Rules References (Round 3)

## Summary Assessment

The revision addresses every round-2 item: `rules_check` is demoted to a no-regression comparison, the gate is a post-compaction canary probe, and all five non-blocking items are done.
Phases 1 and 2 are ready to implement as written.
One problem remains, and a probe run shows it: the canary probe as specified does not discriminate.
Run on Claude Code v2.1.293 with haiku, the compaction summary carried the canary word forward in 2 of 2 runs, even though the conversation never mentioned it, so the proposal's claim "The compaction summary cannot carry a word the conversation never used" is false.
A variant that changes the canary word on disk before `/compact` does discriminate, and it passed: the reply gave the new word while the summary held the old one.
Verdict: **Revise**, with one narrow blocking item (a two-line edit to the probe) that the overseer can check directly without a round 4.

## Round-2 action items

| # | Item | Status |
|---|---|---|
| 1 | Replace the phase 3 gate with a canary probe; `rules_check` only as no-regression | Done in all four places (section 3, Phase 3 step 1, Verification step 2, Test Plan rows 4-5). The probe's design is confounded; see below. |
| 2 | Release coupling of phases 2 and 3 | Resolved (section 3 and the Implementation Phases preamble). |
| 3 | Drop the alphabetical-order change | Resolved: dropped, and "The concatenation order ... unchanged" says so. `chat-record.test.sh:791` ("which step 3 follows") stays accurate. |
| 4 | Drop the `${CLAUDE_PLUGIN_ROOT}/rules/...` allowance | Resolved. |
| 5 | `init_real`'s import assertion is inverted | Resolved (Phase 3 step 4, Test Plan). `:804` and `:821` match the current file. |
| 6 | `rules` job in the `cdocs-hooks.yml` header comment | Resolved. |

The heading-reference convention and the keep-`cdocs.md` / drop-import delivery are settled by the maintainer and are not revisited here.

## Section-by-Section Findings

### Section 3: the canary probe

- **Blocking: the compaction summary carries the canary, so a pass does not show re-injection.**
  In Claude Code the rules are injected into the conversation as context, and the summarizer sees them.
  A trivial first turn does not keep them out of the summary: with little conversation to summarize, the summarizer lists the unused project context.
  The probe was run as specified, outside the suite, in a standalone sandbox (fresh `CLAUDE_CONFIG_DIR`, `--model haiku`, stream-json fifo driver like `drive`, no plugins, `CLAUDE.md` with no import, and a `.claude/rules/cdocs.md` holding an H1, one rule, and "The cdocs canary word is `heliotrope`.").
  The turns were "What is 2 + 2?", then `/compact`, then the proposal's question.
  The summary (`isCompactSummary` entry in the session transcript) read:

  ```text
  - Project context present but unused: CDocs test rules (prefer colons over em-dashes; canary word `heliotrope`), ...
  ```

  A second run produced the same carry-over ("Relevant rules: prefer colons over em-dashes; the cdocs canary word is `heliotrope`").
  So the probe as written passes whether or not the rule file is re-injected, which is the failure round 2 asked the gate to rule out.

- **The fix is a word swap on disk between turn 1 and `/compact`.**
  Start the fixture with word A, and after turn 1 replace A with B in `.claude/rules/cdocs.md`.
  Pass if the post-compaction reply contains B: only the re-injected file contains B, and the summary can only carry A.
  A reply with only A means the summary answered and the file was not re-injected (or was re-injected from a cached copy); either way, keep the import.
  The second run above used this variant (`heliotrope` to `marzipan`) and passed.
  The reply was "The cdocs canary word is `marzipan`. ... The compaction summary said `heliotrope`, but the rule text itself says `marzipan`", and the summary held `heliotrope`.
  That is one run, not a recorded gate, so the implementer still runs it and records it.
  It is strong evidence the gate will pass.
  The swap costs one `sed` line, adds no turns, and makes the optional with-import control run unnecessary.
  Replace section 3 item 3's justification sentence with the swap rationale.

- **Non-blocking: say how the probe is run.**
  `chat-record.test.sh` runs top-level code, so `drive` cannot be sourced on its own.
  "Run through the existing `drive` helper" leaves the implementer to choose between a temporary `--only` extra (a ~10-line function beside `rules_check`, using `hproj`, `init_rules`, and `drive`) and a standalone script.
  Name one; the temporary extra is the smaller change.
  Also say how to get "a fixture from `init_rules` with no import line" before phase 3 step 2 changes `init_rules`, for example `init_rules "$P"; printf '# Project\n' > "$P/CLAUDE.md"`.

- **Non-blocking: check all post-compaction assistant text, not only the final `result`.**
  `drive` loads the cdocs plugin, and with `init_rules` creating `cdocs/_chat/` the Stop hook can block the last turn once and prompt for a `chat-record note`.
  The final `result` can then be the note follow-up, not the answer.
  Grep every assistant text block after the `compact_boundary` for B.

### Section 3 and Phase 3 step 2: `rules_check` as no-regression

- **Non-blocking: name the baseline.**
  "Its results without the import match its results with it" needs a with-import run.
  Phase 3 step 2 changes `init_rules` and then runs `rules_check`, so the with-import run has to come first or be the recorded one.
  Say which: either run `--only rules_check` before editing `init_rules`, or compare against the recorded baseline (3 of 5 assertions fail, [decomposition devlog](../devlogs/2026-10-06-rules-context-decomposition-full-send.md) line 81).
  Haiku runs vary, so compare which assertions pass and fail, not the transcripts.

### Release coupling

- **Non-blocking: define "release" for this marketplace.**
  The marketplace is installed from git, and the nudge is triggered by a hash change, not a version change.
  It is not stated whether "the same plugin release" means one `plugin.json` version bump or one push to `main`.
  The two differ if consumers pick up commits on `main` without a version bump.
  One clause naming the unit (for example "phase 3 lands before the version bump that ships phase 2") would save an implementer from guessing.

### Implementability

Apart from the probe, a fresh implementer can execute the proposal as written.

- Phase 1's success criterion ("the hit list matches the audit; the extractor fixtures pass") is concrete, and the Audit verification gives the expected hit list by `file:line`.
- Phase 2 names every edit site, and its success criterion ties to Verification step 4, whose sentinel test is specific and observable (sentinel fix applied, no rule-path Read or Glob in either transcript).
- Phase 3's steps are ordered, its line references are current, and its success criterion names Verification steps 2, 3, and 5.
  Verification step 2 needs the swap wording from the blocking item.
- Constraints are explicit.

The design is minimal: one check module, no hook change, a two-bullet init edit, and a one-off gate.

## Verdict

**Revise.**
Phases 1 and 2 are accepted as written.
The one blocking item is the gate's discriminator: the summary carries an unmentioned canary (shown twice), so section 3 item 2 needs the on-disk word swap, item 3 needs a pass criterion of the new word, and the false justification sentence has to go.
Verification step 2 and the Test Plan gate row need the same wording.
This is a small textual edit with an observed passing run behind it, so the overseer can check it directly and move to implementation without another review round.

## Action Items

1. [blocking] Section 3 probe: after turn 1, rewrite the canary from word A to word B in `.claude/rules/cdocs.md`. Pass only if a post-compaction reply contains B. Replace "The compaction summary cannot carry a word the conversation never used" with the swap rationale (the summary carries A; only re-injection from disk yields B). Mirror this in Verification step 2 and the Test Plan gate row. The optional control run can be dropped.
2. [non-blocking] Say how the probe is run: a temporary `--only` extra beside `rules_check` (recommended) or a standalone script. Give the no-import fixture recipe (`init_rules`, then overwrite `CLAUDE.md`).
3. [non-blocking] Check every post-`compact_boundary` assistant text block for B, not only the final `result`, since the Stop hook can add a turn.
4. [non-blocking] Phase 3 step 2: run the with-import `rules_check` baseline before editing `init_rules`, or name the recorded baseline. Compare pass/fail per assertion.
5. [non-blocking] Define "same plugin release": one `plugin.json` version bump, or one push to `main`.

## Questions for the author

1. Probe discriminator:
   (a) on-disk word swap between turn 1 and `/compact`, pass on the new word (recommended: one line, observed working);
   (b) keep one word, and pass only if the reply has it and the `isCompactSummary` transcript entry does not (observed: the summary always had it, so this would be inconclusive every time);
   (c) skip the gate and rely on the documented behavior plus the reviewer's one-off run.
2. Probe vehicle:
   (a) temporary `--only` extra in `chat-record.test.sh`, removed after the gate (recommended);
   (b) permanent `--only` extra, which also catches a future Claude Code regression in re-injection;
   (c) standalone script recorded in the devlog.
