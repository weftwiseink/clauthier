---
review_of: cdocs/proposals/2026-09-17-browser-delegation-plugin.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-07T20:47:19-07:00
task_list: cdocs/browser-delegation
type: review
state: live
status: done
tags: [fresh_agent, iterate_integration, evidence_provenance, runtime_carrier, media_convention]
---

# Review (round 7): Browser Delegation Plugin

> BLUF: Accept.
> Both r6 blockers are resolved.
> `reviewer.md` now carries the copy instruction and its Bash permission as final text that fits the actual file.
> The inlined `Artifacts` line, the scratch-path captions, and the review-named copies restore provenance and prevent collisions with implementer media.
> The new delegate-description sentence is a sound runtime carrier for the quoting rule.
> Five non-blocking nits remain. The most useful one: GNU `cp -n` exits 0 when it skips an existing target, so the "choose another description" branch needs a check that a silent skip cannot pass.

## Summary Assessment

Commit a6e886d revises the `_media` evidence rule along the lines of the overseer's option A on both r6 questions.
The copy instruction and its permission live only in `reviewer.md`, and copies are named `YYYY-MM-DD-<review-doc-name>-<description>.png` and never overwrite.
The two replacement `reviewer.md` bullets in Phase 3 match lines 59 and 60 of the real file word for word, apart from the appended text, and no hook blocks them.
The rule reads the same everywhere it appears in the proposal, the three r6 nits are resolved, and the framing stays history-agnostic.
Verdict: **Accept**, with non-blocking nits.

## r6 Action Items

| r6 item | Status | Evidence |
|---|---|---|
| 1. [blocking] B1: `reviewer.md` as runtime carrier and permission | Resolved | Phase 3 (386-388) gives the full text of both bullets. The commit-rule bullet tells the reviewer to `cp -n`, embed, caption, and commit. The Bash bullet adds "except that `_media` copy". Scope (55), file table (246), Iterate integration (200), and the Phase 3 constraint (390) all describe the same two-bullet change. |
| 2. [blocking] B2: provenance and collision | Resolved | `Artifacts` is inlined with `Sessions`/`Facts`/`AE score` (193). Only paths in that line are copied, each captioned with its scratch source (194, 196). Copies use review-named files with no overwrite (194-195). All of this is mirrored in the Test Plan (343) and the Phase 3 success criterion (389). |
| 3. [non-blocking] N1: scope item 4 to cdocs | Resolved | "In a cdocs project, the dispatcher (in iterate, the reviewer) copies ..." (40). |
| 4. [non-blocking] N2: default and override | Resolved | Non-Goals (68): "defaults to `model: sonnet`, the dispatcher may override it per dispatch with the Agent tool's `model` parameter (which takes precedence over agent frontmatter ...)". This matches the Agent tool's documented `model` parameter. |
| 5. [non-blocking] N3: evidence lead-in | Resolved | "Evidence has two parts, both committed with the review:" (192). |

## Repo Fact Check: the `reviewer.md` Bullets Against the Real File

- [`reviewer.md`](../../plugins/cdocs/agents/reviewer.md):59 is "Commit your review file (and the reviewed doc's `last_reviewed` if the review skill says so) by explicit path; run no other mutating VCS command."
  The proposed first bullet keeps that sentence verbatim and appends the copy sentence.
  "Include it in this commit" is a commit by explicit path, so it does not conflict with "no other mutating VCS command".
- `reviewer.md`:60 matches the proposed second bullet's prefix verbatim, and "except that `_media` copy" is inserted before "Do not install ...".
  "That" refers to the immediately preceding bullet, so the reference holds.
- `reviewer.md`:58 ("do not modify ... any source file") is not affected, because a new PNG under `cdocs/_media/` is not a source file.
- [`validate-cdocs-edit-path.sh`](../../plugins/cdocs/hooks/validate-cdocs-edit-path.sh) and `hooks.json` match only `Write|Edit`.
  A Bash `cp` into `cdocs/_media/` is unhooked, so the Bash exception is the only gate, and the proposal correctly puts it there.
  No hook constrains reviewer Bash.
- `reviewer.md`:62 ("State these boundaries in any child's prompt") means a reviewer dispatching the delegate relays the new copy sentence too.
  This is harmless: the delegate's body and fixed report confine it to scratch.
- [`iterate/SKILL.md`](../../plugins/cdocs/skills/iterate/SKILL.md) Turn N.b (91-92) and the `confirmed` row (132) are unchanged by the proposal, apart from the `confirmed` clause.
- [`devlog/SKILL.md`](../../plugins/cdocs/skills/devlog/SKILL.md):51 has implementers save to `cdocs/_media/YYYY-MM-DD-description.png`.
  The `<review-doc-name>` infix (for example `2026-10-07-review-of-foo-r2-settings-panel.png`) cannot collide with that unless an implementer happens to choose a description starting with `review-of-`.
- Empirical check: on GNU coreutils 9.10 (this host), `cp -n x y` with `y` present leaves `y` unchanged, prints nothing, and exits 0. See N1.

## The Delegate-Description Addition

"Responds with artifact paths and mechanical facts only; when citing it as evidence, quote its Sessions, Artifacts, Facts, and AE score lines." (128)

This is sound, and it is the right carrier:
- The description is in every dispatcher's Agent tool listing, so the textual-trail half of the evidence rule reaches the iterate reviewer at runtime.
  That is the same reasoning line 190 uses for the fresh-sessions option.
- `reviewer.md`'s new sentence covers the copy, and the description covers the quoting, so neither file repeats the other's content.
- It is generic: nothing in it assumes cdocs, so the "no dependency on cdocs" claim (205) holds.
- It keeps D6 intact, because it tells the consumer what to quote, not what to conclude.

Two gaps, both non-blocking:
- It omits the `Status` line (see N2).
- The proposal body never names the description as the carrier for the textual trail (see N3).

## Consistency Sweep

The evidence rule agrees across the document:
- BLUF (21) and Summary item 4 (37-40)
- Scope (55)
- the agent description (128)
- Iterate integration (192-200)
- the README and `reviewer.md` file-table rows (244, 246)
- the Phase 2 README bullet (378)
- Phase 3's bullets, success criterion, and constraint (386-390)
- the Test Plan "Iterate `review_proof`" item (343)

The four quoted line names are listed identically in 128, 193, 244, 343, and 378.
The naming pattern is identical in 194, 343, 387, and 389.
"Worktree hygiene" (342) is still correct, since it measures the delegate's footprint before any reviewer copy.

## Regressions and Framing

- No regressions outside the delta.
  The session-state contract, the fresh-sessions carrier, the depth analysis, D1-D7, and Phases 1, 2, and 4 are unchanged.
- Settled decisions are respected: no non-Claude path, the approved `confirmed` clause, reviewer- or dispatcher-made `_media` copies, and a delegate that writes only to scratch.
- The framing is history-agnostic: the text has no "previously", "now", or "no longer" phrasing.
  The only ` -- ` occurrences are Mermaid edges.
  Sentence-per-line formatting holds, apart from the two quoted `reviewer.md` bullets, which reproduce that file's own multi-sentence bullet style. That is correct for final text.

## Section-by-Section Findings (all non-blocking)

**N1. `cp -n` does not signal a skipped copy.**
The Phase 3 bullet says "`cp -n` it to ... (...; if that name exists, choose another description, never overwrite)".
`cp -n` guarantees the "never overwrite" half.
The "choose another description" half depends on the reviewer noticing that the name exists, and GNU `cp -n` exits 0 without output when it skips.
Suppose two same-day rounds review the same document under a review file name with no round suffix (iterate does not mandate `-rN`), and both use the same description.
The second reviewer's `cp -n` then silently keeps the first round's image and embeds it with a caption naming this round's scratch path.
The verdict itself is still sound, because the reviewer looked at the scratch file, but the committed evidence would be stale and its caption false.
Fix: make the check one that a silent skip cannot pass. For example, "`cp -n` it ..., then `cmp` the copy against its source (on a mismatch the name was taken: choose another description)".
`cmp` is portable and also catches a copy that failed.

**N2. The quoted lines omit `Status`.**
The description (128), Iterate integration (193), the README rows (244, 378), and the Test Plan (343) quote `Sessions`, `Artifacts`, `Facts`, and `AE score`, but not `Status`.
`WARNINGS` is how the report says that `compare` was absent, and that is why `AE score` reads `n/a`.
`FAILED` with partial artifacts is a case an auditor should see.
Consider adding `Status` to the list, or saying "quote every report line except `Truncated`".

**N3. Name the description as the textual trail's carrier.**
Line 190 credits the description for the fresh-sessions rule, and line 200 credits `reviewer.md` for the copy.
No sentence says that the description's new clause is what tells the reviewer to inline the four lines.
Add one clause to 190 or 200, for example "and its citing clause carries the quoting rule".
Optionally soften 205 ("review the artifacts however it likes") to account for the description's quoting guidance.

**N4. "Turn N.b is unchanged apart from the `confirmed` clause" (200) misplaces the clause.**
Line 184 and the file table put the clause on the `confirmed` row (iterate:132), not in Turn N.b.
Suggest: "iterate changes only by the `confirmed` clause, and Turn N.b is unchanged."

**N5. `cdocs/_media/` may be absent in a fresh worktree.**
`/cdocs:init` creates it, but git does not track empty directories, and this repo has no tracked `_media` files.
In a fresh worktree the reviewer's `cp` would fail on the missing directory, and `mkdir -p` falls outside "except that `_media` copy" if the bullet is read literally.
Consider "except that `_media` copy (and `mkdir -p cdocs/_media`)".
A reasonable agent would do this anyway, so this is a precision nit.

## Verdict

**Accept.**
B1 and B2 are resolved within the settled answer, the `reviewer.md` text fits the actual file and its hooks, and the delegate-description addition is a sound runtime carrier.
N1-N5 are optional precision fixes that the implementer can fold into Phases 2 and 3 without another review round.

## Action Items

1. [non-blocking] N1: In the Phase 3 `reviewer.md` copy sentence, follow `cp -n` with a `cmp` against the source (a mismatch means the name was taken: choose another description), so a silent skip cannot embed a stale image under this round's caption.
   Mirror this in the Iterate integration bullet (194-195) if desired.
2. [non-blocking] N2: Add `Status` to the quoted report lines in the agent description (128), Iterate integration (193), the README rows (244, 378), and the Test Plan (343), or say "every report line except `Truncated`".
3. [non-blocking] N3: In Iterate integration (190 or 200), state that the description's citing clause carries the quoting rule, and optionally qualify line 205.
4. [non-blocking] N4: Reword line 200 so that the `confirmed` clause sits on the `confirmed` row, not in Turn N.b.
5. [non-blocking] N5: Extend the Bash exception to cover `mkdir -p cdocs/_media`.

## Questions for the Maintainer

None of these need the maintainer.
N1-N5 are wording fixes within settled decisions, and the implementer can apply or decline each one.
