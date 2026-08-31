---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-08-04T11:30:00-07:00
task_list: cdocs/visual-review
type: report
state: live
status: review_ready
tags: [process, visual_review, iterate, review, claude_skills, handoff, flutter]
---

# Visual-review gaps in `/cdocs:review` and `/cdocs:iterate`, and a pixel-grounding handoff (webkit and Flutter)

> BLUF(opus-4.8/visual-review-handoff): The current `/cdocs:review` and `/cdocs:iterate` skills have no discipline specific to UI-rendering work, so a review loop can rack up "confirmed" rows and a `continue` judge verdict while the render is visibly broken to the maintainer.
> This handoff documents the three structural gaps that let that happen (measurement-as-proof-of-absence, no reference-image side-by-side, a judge forbidden from looking), and the pixel-grounding techniques that empirically fixed it in the blockquote-restyle workstream.
> The concrete asks: add a render-only visual pass to the reviewer, tighten the `/iterate` `review_proof` contract to reject measurement-only evidence for visual floors, and give the visual-verdict path an ensemble of fresh lookers plus an ImageMagick pixel-diff gate.
> This is a shared, platform-dual reference: the empirical failure and fixes come from a React/webkit UI, but every recommendation carries an equal-weight Flutter equivalent because this repo's own UI (the `app/` reader) is Flutter, verified on the `avd-up` Android emulator rather than in a browser.
> The core discipline is platform-agnostic and both inherit it: a measurement proves a defect exists, never that none does, so only the rendered pixels can certify a visual floor clear, whether those pixels come from a headless webkit screenshot or an `adb exec-out screencap` of the emulator.
> This consolidates the RFP (`cdocs/proposals/2026-07-30-formalized-visual-review-approach.md`) and the research report (`cdocs/reports/2026-07-30-steering-visual-iterative-dev.md`) into an actionable change spec against the actual skill/agent source.

## Context / Background

The `blockquote-nesting-restyle` workstream ran a `/cdocs:iterate` loop (fresh implementer/reviewer/judge Opus subagents per round) against a maintainer-picked mock.
For four rounds the reviewer reported the marker glyph was the correct lavender (`getComputedStyle` returned the right hex) and measured the five must-fix items to "0px drift," the judge saw monotonic numeric progress and ruled `continue`, and the maintainer rejected every round on sight: "blockquote character colours haven't even changed."

Root cause: the `>` glyph rendered through an inner `.tok-quote .tok-mark` element whose color overrode the outer marker element the reviewer was measuring.
The measured hex was true and irrelevant; the pixels were wrong.
The loop only converged once the review discipline was replaced with a pixel-grounded one (details in "What worked" below).

This report is the maintainer-facing change spec.
It differs from its two companions by citing the exact skill/agent source that permits the failure, so a maintainer can act without re-deriving the diagnosis:
- The RFP argues *that* a DOM-blind reviewer should exist.
- The research report surveys *external* practice and ranks recommendations.
- This report maps those recommendations onto specific lines of the shipped `cdocs` plugin and adds this session's own empirical result.

Source paths below are relative to the cdocs plugin root (`plugins/cdocs/` in the plugin repo; installed under the `clauthier` marketplace checkout).

## Two UIs, one discipline

The originating failure was a React/webkit render inspected through a browser and `getComputedStyle`.
This repo's UI is Flutter (`app/lib/src/features/reader/`, the furigana-ruby, meaning-hint-reveal, anchor-bold reader), inspected through the `avd-up` API-34 Android emulator (`app/tool/avd-up.sh`) and the widget tester, never a DOM.
The gaps and fixes below are stated once for both, because the trap is identical under either stack: an introspection API reports the element is present and correctly-valued, the reviewer trusts that number, and the pixels are wrong anyway.

The platform-agnostic core, stated once and inherited by both:

- **Measurement proves presence, never absence.** A value read from the render tree can prove a defect exists, never that none does. Only the pixels can clear a visual floor.
- **The looker reviews the rendered image, not the tree.** The webkit version is a DOM-blind pass; the Flutter version is a widget-tree-blind pass. Same instruction, different tree.
- **ImageMagick `compare -metric AE` is the objective diff on both.** It operates on PNGs and does not care which stack produced them.

Where the platforms diverge, the recommendation says so at the point of divergence. The concrete tool mapping:

| Concern | React / webkit | Flutter (this repo) |
| --- | --- | --- |
| Render capture | headless-browser screenshot (Playwright) | `matchesGoldenFile` (flutter_test), `integration_test` screenshot on `avd-up`, `flutter screenshot`, `adb exec-out screencap -p` |
| The "it's in the tree" measurement trap | `getComputedStyle` / `getBoundingClientRect` returns the right value | `find.byType` / `find.text` / `find.textContaining` returns `findsOneWidget`; `tester.widget<Text>(...)` reads the right property |
| Objective pixel diff | `compare -metric AE before.png after.png` | same ImageMagick call on the PNGs, plus flutter_test's built-in golden comparison |
| Live render inspector | browser devtools, live DOM | none on the emulator framebuffer (Flutter DevTools inspects the in-process tree, not the on-device pixels) |

> NOTE(opus-4.8/visual-review-handoff): the Flutter examples are grounded in this repo's real setup, cross-linked from the [media-session testing report](2026-08-04-flutter-media-session-testing-without-hardware.md) (the `avd-up` emulator, `record-audio.sh`, `dumpsys media_session`, `adb exec-out screencap`). Where Flutter is materially better or worse than the browser case for visual review, see "Where Flutter differs" below.

## Key Findings

- **`/cdocs:review` has zero visual-work discipline.** `skills/review/SKILL.md` never mentions screenshots, rendering, reference images, or the DOM. Its verification guidance is "Verify claims against available evidence" (`SKILL.md:112`), which for a CSS change is satisfied equally by a screenshot or by a `getComputedStyle` dump. Nothing privileges the pixels.
- **The `reviewer` agent can see the render but is never required to.** `agents/reviewer.md:32` says it "inspects the live system rather than only the diff," and it has full tools (Playwright included). But no instruction forces it to screenshot, forbids measurement-as-proof-of-absence, or makes it compare against the target image. Capability without discipline is what produced four green-but-wrong rounds.
- **The `/iterate` `review_proof` contract has a measurement loophole.** `skills/iterate/SKILL.md:104` admits a `confirmed` row when the reviewer "cited at least one artifact." A `getComputedStyle`/`getBoundingClientRect` log is an artifact. So a measurement-only verification passes the contract for a visual floor. The contract does not distinguish pixel evidence from DOM-number evidence.
- **The judge is structurally blind by design.** `agents/judge.md:42-44`: "Do not read source code. Do not run verification commands. Do not open the live system." The judge rules purely from review prose. When the reviews report monotonic numeric progress, `continue` is the only defensible verdict, so the one role positioned to break a numbers-driven loop is forbidden from looking at the render that would break it.
- **A fresh, unconditioned Claude looker already has the capability.** In this same session, an Opus 4.8 instance with no task context, given only the screenshot and "list the visual rendering bugs," produced a correct, ranked critique. The gap is not model capability; it is that DOM access and checklist-anchoring conditioned the loop's reviewer away from looking. (Full transcript in the RFP, `2026-07-30-formalized-visual-review-approach.md:27-49`.)
- **The Flutter stack has the identical trap, and this repo already relies on the trapping evidence.** The reader's widget tests (`app/test/reader_annotations_test.dart`) assert `find.text('みず') findsOneWidget`, `find.textContaining('と𠮷と犬。', findRichText: true)`, and `tester.widget<Text>(find.text('猫'))`. Each proves a span is in the widget tree with the expected string, exactly as `getComputedStyle` proves a CSS value: it says nothing about whether the ruby sits above its base run, whether a reveal is clipped, or whether an anchor is overpainted. A green `flutter test` on these is the Flutter analogue of the "0px drift" pass that blessed four broken rounds. This repo's default gate (`app/tool/check.sh`) is `flutter analyze --fatal-infos` plus `custom_lint` plus `flutter test`, all widget-tree and static: it contains no pixel assertion and no `matchesGoldenFile`, so nothing in the standing gate looks at a rendered image.

## What worked: the pixel-grounding techniques (empirical, this workstream)

These are not proposals; they are what actually converged the loop and shipped the restyle to `main`.

1. **DOM-blind lookers.** A reviewer given only the rendered screenshot(s) plus the target image, asked the open question "what is wrong with this?" *before* any checklist, and with DOM/measurement tools withheld on that pass. This is the pass that first named the same-hue-glyph-on-bar contrast defect that four measurement rounds missed.
2. **Ensemble over single looker.** Two independent fresh lookers on the aesthetic sign-off caught more than one: a single looker rubber-stamped a wash-inconsistency that a second, independently spawned looker flagged. Cost is low (subagents are non-deterministic, so a second draw is genuine coverage); any strong "this looks wrong" was treated as blocking.
3. **Reference image in the same turn.** The looker was handed the accepted mock alongside the current render and asked for a region-by-region divergence list, rather than relying on a remembered or prose-narrated target.
4. **Measurement is evidence-of-presence only.** DOM/CSS numbers were allowed to *explain* a defect already seen in the pixels, never to certify a defect absent. "0px drift" stopped counting as a pass.
5. **ImageMagick pixel-diff as an objective gate.** For the final merge-cleanup pass, `compare -metric AE before.png after.png` returned `AE=0` (zero differing pixels), which objectively proved the refactor was pixel-identical and let the loop *skip* a redundant visual review. The same tool gates "did this change nothing visually" and "did this change exactly the intended region."

The distilled rule, from the research report and confirmed here: a measurement can prove a defect *exists*, never that none does; only the pixels can do the latter.

These five techniques are essence-transferable; only their instruments change.
The Flutter translation, grounded in this repo:

1. **Widget-tree-blind lookers.** Hand the looker an emulator screenshot (`adb -s <serial> exec-out screencap -p`, the same call `app/tool/avd-up.sh` already uses to verify the framebuffer is non-blank) plus the target image, and ask "what is wrong with this?" before any checklist, with the widget tester and `find.*` queries withheld on that pass.
2. **Ensemble over single looker.** Same as webkit: two independently spawned fresh lookers on an aesthetic sign-off; non-determinism makes the second draw genuine coverage.
3. **Reference image in the same turn.** Hand the accepted design mock alongside the current render (this session captured reader renders at `cdocs/_media/2026-08-04-capture-review-graded-and-hint.png` and the phase-4 smoke shots under the session scratchpad `phase4-smoke/shots/05-hint-revealed.png`), and ask for a region-by-region divergence list.
4. **Measurement is evidence-of-presence only.** `find.text(...) findsOneWidget` and `tester.widget<Text>(...)` explain a defect already seen in the pixels; they never certify one absent.
5. **ImageMagick pixel-diff as an objective gate.** `compare -metric AE before.png after.png` on two emulator screencaps (or two golden PNGs) works identically to the browser case: `AE=0` proves a refactor changed no pixels, a bounded nonzero `AE` in the intended region proves it changed exactly that region.

Flutter adds one lever the browser case lacks: `matchesGoldenFile` bakes the reference PNG into the test suite so the pixel comparison runs under `flutter test` in CI, with no live emulator required for the regression check.
Its failure mode is the mirror of the webkit trap: a golden recorded from a buggy render blesses the bug forever.
The counter is the same as for any golden: a human or an Opus looker eyes the golden once, against the design reference, at the moment it is first recorded, exactly the R1 pass applied to the blessing step.

## Recommendations

Ranked by leverage-to-cost, each mapped to a specific source edit. All are additive; none change non-visual review behavior.

### R1. Add a DOM-blind visual pass to the reviewer (highest leverage)

For any review whose subject touches UI/CSS/rendering, the `reviewer` agent runs a first pass that is screenshot-only:
- Capture the current render (both focused/unfocused and any edge-case states named in the floor).
- Attach the accepted reference image in the same turn.
- Answer, unprompted by any checklist, "list every visual defect, ranked by how obvious it is to a first-time viewer, region by region against the reference."
- No DOM/measurement tools on this pass.

Only after that answer is recorded does the reviewer run the existing checklist pass, where measurement is permitted *to explain* a named defect.

Source: `skills/review/SKILL.md` (add a "Visual subjects" subsection under Sections) and `agents/reviewer.md` (add to Workflow: for UI subjects, the screenshot-only pass precedes the checklist pass).
Trigger: the review subject is a diff touching `.scss`/`.css`/rendering decorations, or the verification floor mentions render/layout/visual/screenshot.

**Flutter equivalent (equal weight).** The DOM-blind pass becomes a widget-tree-blind pass: the reviewer captures the render and answers the same open question before any `find.*` query.
Capture is one of `adb -s <serial> exec-out screencap -p > shot.png` on the running `avd-up` emulator (the call already in `app/tool/avd-up.sh`), an `integration_test` screenshot, or a `matchesGoldenFile` reference image.
For the reader specifically (`app/lib/src/features/reader/annotated_japanese_text.dart`), the defects this pass must catch are pixel-only: ruby not seated above its base run, a revealed hint clipped or wrapping wrong, an anchor bold that reads as plain, none of which the widget tests can see.
Trigger for Flutter: the diff touches `app/lib/src/features/*/**` render code or a widget/painter, or the floor mentions render/layout/furigana/screenshot.

### R2. Codify "measurement proves presence, never absence" (high leverage, near-zero cost)

Add one rule to both the review skill and the reviewer agent: a `getComputedStyle`/`getBoundingClientRect`/geometry measurement may be cited as evidence that a defect *exists*, never as evidence that no defect exists; the visual verdict comes from the pixels.

Source: `skills/review/SKILL.md:106-116` ("What Makes a Good Review") and `agents/reviewer.md:45-53` (Constraints).
This is the single cheapest fix for the exact failure this workstream lived through.

**Flutter equivalent (equal weight).** The identical rule, phrased for the widget tree: a `find.byType`/`find.text`/`find.textContaining` match, or a property read via `tester.widget<Text>(...)`, proves the widget is *in the tree*, never that it is visible, on-screen, correctly sized, painted, or not overpainted by a later layer.
The blockquote failure was an inner element overpainting the measured one; the Flutter form is a widget that is present in the tree but offstage, clipped, zero-opacity, sized to zero, or drawn under a sibling.
`findsOneWidget` is not "it renders correctly"; the visual verdict comes from the screenshot or golden.
This rule is platform-agnostic and stated once above; both the review skill and the reviewer agent should carry the DOM and widget-tree phrasings side by side.

### R3. Tighten the `/iterate` `review_proof` contract for visual floors (high leverage)

Split or qualify the `confirmed` definition so a visual floor cannot be satisfied by a measurement-only artifact.
Concretely: when the floor mentions render/layout/visual, a `confirmed` row requires a cited *screenshot* artifact (and, where a reference exists, a stated pixel-diff or region-by-region divergence result), not merely "at least one artifact."

Source: `skills/iterate/SKILL.md:102-109` (`review_proof` column definition).
Add a visual-floor clause to the `confirmed` bullet; measurement logs alone become `skipped` (fail-loud) for visual floors.

**Flutter equivalent (equal weight).** What makes a Flutter `confirmed` admissible on a visual floor is an emulator screenshot (`adb exec-out screencap -p`) or a golden-image diff, never a green `flutter test` alone.
A passing `flutter test` here is precisely the measurement-only artifact: `find.text(...) findsOneWidget` cites an artifact, but a widget-tree one.
The lock-screen and media-session verification already models the admissible-artifact shape for this repo: the [media-session testing report](2026-08-04-flutter-media-session-testing-without-hardware.md) treats a `dumpsys media_session` dump plus an `adb exec-out screencap -p` of the keyguard as the evidence, not a green unit test.
Apply the same standard to visual floors: the `confirmed` row must cite a rendered PNG (screenshot or golden), and where a reference mock exists, a region-by-region divergence or a `compare -metric AE` result against it.

### R4. Let the judge look on visual loops (medium-high leverage)

The judge's blindness (`agents/judge.md:42-44`) is correct for logic/architecture loops but wrong for visual ones: it guarantees the loop's numeric self-report is never checked against the render.
Narrowly relax it: on a loop whose floor is visual, the judge opens the latest screenshot before ruling, and is told a reviewer's numeric evidence table is not sufficient grounds for `continue` on its own.
Keep the source-code and verification-command prohibitions intact; this adds only "view the latest screenshot," not "re-run the work."

Source: `agents/judge.md:42-44` and the `continue` verdict definition (`judge.md:54-56`).

**Flutter equivalent (equal weight).** Identical relaxation, different image source: on a visual Flutter loop the judge opens the latest emulator screencap or golden PNG before ruling, and a reviewer's `find.*`/`flutter test` evidence table alone is not grounds for `continue`.
"View the latest screenshot" reads a PNG the same way whether it came from a browser or `adb exec-out screencap`; the source-code and verification-command prohibitions stay intact for both stacks.

### R5. Ensemble lookers for aesthetic sign-off (medium leverage, higher cost)

For subjective/aesthetic accept rounds specifically (not mechanical-correctness rounds), the overseer spawns two independent fresh lookers with the R1 open-question prompt and treats disagreement as an escalation trigger rather than averaging it away.
This is what caught the wash inconsistency here.

Source: `skills/iterate/SKILL.md` Turn N.b (Review) and Freshness disciplines: note the ensemble option for aesthetic floors.

**Flutter equivalent (equal weight).** The ensemble is stack-neutral: the two fresh lookers receive emulator screenshots (or goldens) instead of browser captures, with the same R1 open-question prompt and the same disagreement-is-escalation rule.
For a subjective reader surface (does the furigana density feel readable, is the hint-reveal legible), two independent draws over the same screencap catch the wash-inconsistency class of defect a single looker rubber-stamps.

### R6. Adopt ImageMagick pixel-diff as a first-class artifact (medium leverage)

Document `compare -metric AE` as the canonical objective visual artifact in the `/iterate` verification vocabulary: `AE=0` proves a change is pixel-identical (justifying a *skipped* visual re-review on a proven-inert refactor), and a bounded nonzero `AE` confined to the intended region proves a change did exactly what was intended and nothing else.

Source: `skills/iterate/SKILL.md` `review_proof` notes and `agents/reviewer.md` Workflow (list `compare -metric AE` as an available read-only verification, alongside tests and dev server).

**Flutter equivalent (equal weight).** `compare -metric AE` is genuinely platform-agnostic: it diffs two PNGs and does not know or care that they came from `adb exec-out screencap` rather than a headless browser.
`AE=0` on two emulator screencaps proves an inert refactor (justifying a skipped visual re-review); a bounded nonzero `AE` confined to the reader's changed region proves the change did exactly what was intended.
Flutter also offers a second, more first-class form of this gate: `matchesGoldenFile` performs the pixel comparison inside `flutter test`, so a golden regression is caught in CI on `check.sh` with no live emulator. This repo does not yet use `matchesGoldenFile` (its only `test/golden/` files are wire-contract JSON, not images), so adopting an image golden for the reader is net-new work, but it is the cheapest standing pixel gate available to the Flutter side.

## Where Flutter differs from the webkit case

Stated plainly, so neither side is oversold:

- **Flutter is better at the standing pixel gate.** `matchesGoldenFile` makes image goldens a first-class, CI-runnable part of `flutter test`; a typical webkit setup needs a separate screenshot harness bolted on. The Flutter side can put a real pixel assertion in `check.sh` where the browser side usually cannot put one in its unit run.
- **Flutter is worse at live inspection.** The browser has devtools and a live DOM the reviewer can poke on the rendered surface. Flutter DevTools inspects the in-process widget tree, not the emulator's framebuffer, so on the actual pixels there is no inspector at all: the only artifact is the screenshot. This makes the R1 render-only pass more necessary on Flutter, not less, since there is no fallback introspection of what actually painted.
- **Emulator render fidelity has a CJK caveat the browser case does not carry.** The [media-session testing report](2026-08-04-flutter-media-session-testing-without-hardware.md) already flags that emulator text rendering can diverge from a real device on Han-unification glyph forms (Japanese titles under an English UI locale). A golden or screencap blessed on the emulator can therefore certify a glyph shape a real device renders differently, so for CJK-glyph-sensitive review the emulator pixel is a strong first signal, not the final authority; the residual device check stays in scope.

## Sequencing and risk

R1-R3 are the core and are mutually reinforcing; ship them together.
R2 and R3 are text-only additions with no behavioral risk to non-visual reviews.
R1 adds a pass (latency cost on UI reviews only).
R4 is a scoped relaxation of a deliberate constraint: keep it gated strictly to visual floors so logic-loop judges stay blind as designed.
R5 raises token cost and should stay opt-in for aesthetic rounds.
R6 is pure vocabulary plus a documented command; no risk.

None of these require a new agent type, though R1 could later be hardened into an infra-enforced tool-allowlisted "looker" agent (the RFP's open question, `2026-07-30-formalized-visual-review-approach.md:69`); the written-instruction form above is sufficient to capture the wins observed here and is the cheaper first step.

## Prior art in this corpus

- `cdocs/proposals/2026-07-30-formalized-visual-review-approach.md`: the RFP this operationalizes; holds the verbatim fresh-looker transcript and the infra-enforcement open question.
- `cdocs/reports/2026-07-30-steering-visual-iterative-dev.md`: external practice (Anthropic's own `frontend-design`/`webapp-testing` skills, blind-A/B judging, fresh-context review) and the ranked recommendation set R1-R6 draw from.
- `cdocs/reports/2026-07-30-kimi-k3-visual-styling-subagent.md`: the alt-model escalation, positioned as later-if-needed; its Stage-0 recommendation is R2.
- `cdocs/reports/2026-05-18-cdocs-reviewer-empirical-verification-gap.md`: the earlier, general finding that the reviewer role cannot structurally self-verify in a browser; R1/R4 are the visual-specific concretization of its proposed (unimplemented) verifier role.
- `cdocs/reports/2026-08-04-flutter-media-session-testing-without-hardware.md`: this repo's catalog of device-free Flutter verification (the `avd-up` emulator, `record-audio.sh`, `dumpsys media_session`, `adb exec-out screencap`, `integration_test`); the source of every Flutter idiom cited above and of the Han-unification glyph-fidelity caveat.
- `app/tool/check.sh` and `app/test/reader_annotations_test.dart`: the standing Flutter gate and the reader widget tests that concretely exhibit the widget-tree measurement trap this report is about.
