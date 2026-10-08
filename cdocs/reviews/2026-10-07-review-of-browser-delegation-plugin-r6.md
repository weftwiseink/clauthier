---
review_of: cdocs/proposals/2026-09-17-browser-delegation-plugin.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T20:43:06-07:00
task_list: cdocs/browser-delegation
type: review
state: live
status: done
tags: [fresh_agent, iterate_integration, evidence_provenance, runtime_carrier, media_convention]
---

# Review (round 6): Browser Delegation Plugin

> BLUF: Revise, on two narrow blockers in the `_media` evidence change.
> The model and iterate-clause answers are folded in correctly, the framing is history-agnostic, and the rest of the document is unchanged and still consistent.
> The proposed `reviewer.md` clause is not enough: it lets the reviewer commit `_media` files, but nothing at runtime tells the reviewer to copy them, and `reviewer.md` limits Bash to read-only use.
> The delta also drops the scratch-path citation.
> `_media` is shared with implementer devlogs (the devlog skill saves screenshots there under the same naming), so an embedded image no longer proves that this round's reviewer produced it.
> Both fixes are one sentence each.

## Summary Assessment

Commit 2372ad0 records three maintainer answers: no non-Claude model path, the approved iterate `confirmed` clause, and cited screenshots copied to `cdocs/_media/` in v1.
Answers 1 and 2 are implemented cleanly.
Answer 3 is carried consistently through the BLUF, Summary item 4, Scope, the file table, Iterate integration, Phase 2, Phase 3, and the Test Plan.
Answer 3 is not yet implementable as written.
The one `reviewer.md` change it specifies is a commit-rule clause.
The reviewer has no runtime instruction to make the copy, and it is not permitted to make it.
The evidence chain from the embedded image back to this round's delegate report is also lost.
Verdict: **Revise**.

## Delta Verification Against the Settled Answers

| Answer | Status | Where |
|---|---|---|
| 1. Model choice stays with dispatcher and reviewer; no non-Claude path; question closed | Implemented | Non-Goals "No non-Claude model path" (lines 66-67). The Open Questions entry is removed, and no dangling "see Open Questions" reference remains. Background (83-86) still states the Anthropic-only `model:` fact and puts the visual-model choice in the reviewer leg, which matches the answer. |
| 2. One-clause iterate `confirmed` edit approved | Implemented, unchanged | Iterate integration (181-183), file table, Phase 3 first bullet. |
| 3. Screenshots to `cdocs/_media/` in v1, one-clause `reviewer.md` change, one writer per file, reconciled with the cite-and-quote rule | Carried consistently, but under-specified | See B1 and B2. The Phase 5 "Committed iterate evidence" item is correctly removed. |

## Repo Fact Check

- [`reviewer.md`](../../plugins/cdocs/agents/reviewer.md) Constraints:
  - Line 58: "Only `Edit` the target document's `last_reviewed` frontmatter: do not modify any other field, the body content, or any source file."
  - Line 59: "Commit your review file (and the reviewed doc's `last_reviewed` if the review skill says so) by explicit path; run no other mutating VCS command."
  - Line 60: "Use `Bash` for read-only inspection and empirical verification (running tests, starting a dev server, `curl` ...). Do not install dependencies, modify configuration files, run codegen, or run migrations."
  - The file has no instruction about screenshots, media, or embedding.
- [`validate-cdocs-edit-path.sh`](../../plugins/cdocs/hooks/validate-cdocs-edit-path.sh) blocks the `cdocs:reviewer` agent's `Write`/`Edit` outside `cdocs/(devlogs|proposals|reviews|reports)/`, so `cdocs/_media/` is blocked.
  This is moot for PNGs, since `Write` cannot produce a binary file anyway, but it does mean the copy can only be a Bash `cp`, which line 60 does not permit.
- [`iterate/SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md):
  - Turn N.b (91-92) has the reviewer "cite at least one artifact path in the review, inlining excerpts for ephemeral artifacts".
  - The `confirmed` definition (132) requires "an artifact it produced".
  - Neither line mentions `_media`, and the proposal's iterate clause is about admissibility only.
- [`devlog/SKILL.md`](../../plugins/cdocs/skills/devlog/SKILL.md):51 has implementers save screenshots to `cdocs/_media/YYYY-MM-DD-description.png`.
  The reviewer's copies therefore land in a directory, and a naming scheme, that implementers already write to.
- [`frontmatter-spec.md`](../../plugins/cdocs/rules/frontmatter-spec.md) "Media" matches the proposal's citation.

## Section-by-Section Findings

### Iterate integration and Phase 3: the `reviewer.md` clause

**B1 [blocking] The `reviewer.md` change permits a commit but does not instruct or permit the copy.**
Phase 3's clause amends only line 59: "Commit your review file, plus the `cdocs/_media/` evidence it embeds ...".
That wording is conditional on evidence the reviewer has already embedded.
At runtime nothing tells the reviewer to embed anything:
- The README is not in its context.
- The delegate's description covers only the fresh-sessions option.
- The iterate clause covers admissibility.
- iterate Turn N.b still says "inlining excerpts for ephemeral artifacts", which is the textual trail alone.

The r4 B1 standard applies here: a rule the reviewer must follow needs a runtime carrier, and "Iterate integration" itself says this about the fresh-sessions line (line 189).
Line 60 also restricts Bash to read-only inspection and empirical verification, and a `cp` into the repo is neither.
A Phase 3 implementer who follows the constraint "no cdocs agent or skill changes beyond these two clauses" ships a reviewer that never copies, and Phase 3's own success criterion ("whose cited screenshot is embedded from `cdocs/_media/`") then fails.
Fix: make the `reviewer.md` change the carrier and the permission in one sentence.
For example, append to line 59:
"When your verdict relies on a screenshot, `cp` it from scratch into `cdocs/_media/` (the media convention), embed it in your review, and include it in this commit."
Then add the matching exception to line 60 ("read-only, except that copy").
Update Phase 3's bullet and constraint, the file table row, and the Scope line to describe this as the `reviewer.md` change, and drop the "one clause" count if it no longer fits.
Putting the carrier in `reviewer.md` rather than iterate N.b is the better choice, because `reviewer.md` is the reviewer's own system prompt and the rule is not specific to browsers.

**B2 [blocking] The embedded image is no longer tied to this round's delegate report, and `_media` is shared with implementers.**
The delta replaces "cites the scratch path and inlines ..." with a textual trail of `Sessions`, `Facts`, and `AE score`, plus an embedded `_media` copy.
That trail never names which scratch artifact was copied: the `Artifacts` line is not inlined, and the copy's source path is not recorded.
Implementers already commit devlog screenshots to `cdocs/_media/YYYY-MM-DD-<description>.png` (devlog skill, line 51).
A review that embeds `_media/2026-10-07-settings-panel.png` therefore looks the same whether the reviewer's `opened` dispatch captured it or the implementer's devlog did.
The overseer has no way to check "an artifact it produced", and a false `confirmed` becomes possible through a mistake rather than bad faith.
The same naming also invites a collision.
A reviewer copying to the date-plus-description name the implementer already used overwrites a committed file that another document embeds, which breaks the "the reviewer alone writes the `_media/` copies" half of the one-writer-per-file claim (line 196).
Fix (this is the reconciliation the cite-and-quote rule needs):
- Add the report's `Artifacts` line to the inlined `Sessions`/`Facts`/`AE score` lines, so the scratch path is still cited.
- Copy only paths listed in that line, and caption each embed with its source scratch path.
- Name copies so that they cannot collide, for example `YYYY-MM-DD-<review-doc-name>-<description>.png`, which keeps the convention's `YYYY-MM-DD-description` shape. Never overwrite an existing `_media` file.
- Mirror these in the Test Plan "Iterate `review_proof`" item and in Phase 3's success criterion.

### Summary item 4

**N1 [non-blocking] Item 4 reads as universal, but the plugin has no cdocs dependency.**
"The dispatcher (in iterate, the reviewer) ... copies only the screenshots it cites into `cdocs/_media/`" applies to every dispatcher.
"Outside iterate, any agent can dispatch the delegate and review the artifacts however it likes" (line 202) and the "No cdocs installed" edge case say otherwise.
Fix: "A cdocs dispatcher (in iterate, the reviewer) copies ...", or "in a cdocs project".

### Non-Goals

**N2 [non-blocking] "Model choice stays entirely with the dispatcher" sits next to a fixed `model: sonnet`.**
A reader could take the frontmatter as a constraint the dispatcher cannot change.
If the dispatcher can override the model per dispatch with the Agent tool's `model` parameter (an Anthropic model), say so in one clause, for example "the delegate defaults to `model: sonnet`".
That makes "stays with the dispatcher" literally true.
If the dispatcher cannot override it, the sentence should say instead that the choice lies with whoever consumes the artifacts.
This only clarifies the settled answer and does not reopen it.

### Iterate integration wording

**N3 [non-blocking] "so it outlives scratch and survives worktrees" (line 191) only holds for the screenshots.**
The textual trail survives because it is in the review.
The `_media` copy survives because it is committed.
Uncited captures, as the text itself says, still do not survive.
This is accurate, but the scope of the opening clause belongs to the second bullet.
Consider "Evidence has two parts, both committed with the review:".

### Consistency sweep

All of the places the evidence rule touches agree with one another, apart from B1's runtime gap and B2's missing provenance:
- BLUF (21)
- Summary item 4 (37-39)
- Scope (54)
- Iterate integration (191-197)
- the README and `reviewer.md` file-table rows (241, 243)
- Phase 2 README bullet (375)
- Phase 3 (382-385)
- Test Plan "Worktree hygiene" and "Iterate `review_proof`" (339-340)

"Worktree hygiene" stays correct.
It measures the delegate's footprint immediately after a dispatch, before any reviewer copy.

### Regressions and framing

- No regressions outside the delta.
  The session-state contract, the fresh-sessions carrier, the depth analysis, D1-D7, and Phases 1, 2, and 4 are unchanged and still agree with r5's sweep.
- The status moved from `implementation_ready` to `review_ready` for this round, which is correct.
- The framing is history-agnostic: the delta adds no "previously", "now", or "no longer" phrasing.
  "Driving stays sonnet in v1" (85) is scoped, not historical.
  The only `--` occurrences are Mermaid edges.
- Sentence-per-line formatting holds.
  The Phase 3 bullet quotes a clause with an ellipsis (`last_reviewed` ...), which is acceptable for a design doc, but B1's rewrite should give the final text in full.

## Verdict

**Revise.**
B1 and B2 are both one-sentence fixes inside the settled answer 3, and neither reopens it.
After them, the evidence rule both reaches the reviewer and can be audited by the overseer.
A narrow re-review, or an overseer check of those two sentences against `reviewer.md`, is enough.

## Action Items

1. [blocking] B1: Specify the `reviewer.md` change as the runtime carrier and the permission.
   On line 59, add: when the verdict relies on a screenshot, `cp` it from scratch into `cdocs/_media/`, embed it, and include it in the review commit.
   On line 60, add "except that copy" to the read-only Bash rule.
   Update the Phase 3 bullet and constraint, the file-table row, and Scope to match, and give the final clause text in full.
2. [blocking] B2: Restore provenance and prevent collisions.
   Inline the report's `Artifacts` line with `Sessions`/`Facts`/`AE score`.
   Copy only paths listed there, and caption each embed with its source scratch path.
   Name copies `YYYY-MM-DD-<review-doc-name>-<description>.png` and never overwrite an existing `_media` file.
   Reflect all of this in the Test Plan "Iterate `review_proof`" item and in Phase 3's success criterion.
3. [non-blocking] N1: Scope Summary item 4's `_media` copy to cdocs dispatchers ("in a cdocs project").
4. [non-blocking] N2: In Non-Goals, say the delegate defaults to `model: sonnet` and the dispatcher may override it per dispatch, if the Agent tool's `model` parameter applies to plugin agents.
5. [non-blocking] N3: Reword line 191's lead-in to "Evidence has two parts, both committed with the review:".

## Questions for the Maintainer

**Q1. Where should the runtime instruction to copy cited screenshots live?** (action item 1)
- **A (recommended):** `reviewer.md` only (the commit-rule sentence plus the Bash exception). It is the reviewer's system prompt, the rule is not specific to browsers, and iterate N.b stays as it is.
- **B:** iterate Turn N.b ("copying cited screenshots to `cdocs/_media/`"), with `reviewer.md` getting only the permission. The overseer must then relay it in every reviewer dispatch prompt.
- **C:** Both, with the same wording in each place.

**Q2. How should a reviewer's `_media` copies be named?** (action item 2)
- **A (recommended):** `YYYY-MM-DD-<review-doc-name>-<description>.png`. It cannot collide with implementer devlog media, and the review is identifiable from the filename.
- **B:** `YYYY-MM-DD-<description>.png` with a no-overwrite rule (`cp -n`, and pick a new description on conflict). This is closer to the bare convention but relies on the reviewer handling the conflict.
