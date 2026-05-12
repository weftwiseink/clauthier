---
review_of: cdocs/proposals/2026-05-12-cdocs-rule-delivery-materialization.md
first_authored:
  by: "@claude-opus-4-7-1m"
  at: 2026-05-12T19:30:00-07:00
task_list: clauthier/cdocs-rule-delivery
type: review
state: live
status: done
tags: [fresh_agent, rereview_agent, architecture, test_plan, freshness, sessionstart, materialization, directive_compliance]
---

# Review: CDocs Rule Delivery via Materialization with Freshness Hook

## Summary Assessment

The proposal correctly pivots away from the broken SessionStart-as-content-channel design that the Phase 1 regression test invalidated and recenters delivery on `/cdocs:init` materialization plus a tiny version-mismatch hook.
The Phases, Edge Cases, and Important Design Decisions sections are mostly sound and address the user's first concern (no spillover dance).
The proposal's main load-bearing weakness is Group C of the Test Plan: it sketches the right experiment but does not specify the artifacts concretely enough for a subagent implementer, and the proposal does not surface the recursive directive-compliance risk that the "agent treats the Read result as authoritative" assertion silently inherits.
Verdict (round 1): **Revise** with targeted edits to Group C, the Read-after-write framing, and phase ordering.

> NOTE(claude-opus-4-7-1m/cdocs-rule-delivery): Round 2 verdict is **Accept**; see "Round 2 Re-Review" section below.
> Round 1 findings retained verbatim above for the evolution trail.

## Section-by-Section Findings

### BLUF

The BLUF previews the three changes (drop the hook as content channel, materialize via `/cdocs:init`, repurpose hook as freshness check) and explicitly names the Read-after-write directive as the in-session-staleness fix.
This matches the body without surprises. **Non-blocking:** "currently silently broken" reads as accurate but skirts present-tense framing: rephrasing to "CC's 2KB inline cap silently truncates the 13KB cdocs bundle" (drop "on the current build" qualifier or move it to a NOTE) keeps the doc history-agnostic.

### Background

The three empirical facts are correctly attributed to the prior investigation, regression-test devlog, and evergreening report.
The NOTE on the 2KB cap is appropriate and direct.

**Non-blocking finding:** "The current SessionStart hook is broken" is fine in present tense, but the framing in fact 1 ("Both implementer and an independent QA confirmed this") is mildly history-leaning. Consider "Empirical observation: ..." rather than "confirmed this".

### Proposed Solution

#### Section 1 (Repurpose `inject-rules.ts`)

The behavior table is concrete enough to implement.
The directive payload sample correctly tells the agent both (a) run `/cdocs:init` AND (b) Read the rewritten file.

**Blocking finding (1.A):** The hook directive instructs the agent to "Run `/cdocs:init` now to refresh the materialized rules, then Read the rewritten .claude/rules/cdocs.md." This couples Phase 2 (hook rewrite) to Phase 3 (init's Read-after-write directive) by routing the Read instruction through the hook payload. If Phase 2 ships before Phase 3, the hook tells the agent to Read the file after running init, but init won't have emitted its own Read-after-write reminder, and the rule content the agent Reads is the just-materialized content (correct outcome by accident). If Phase 3 ships before Phase 2, init has the Read-after-write directive but the hook is still broken: the agent never gets the freshness nudge in the first place. The proposal's Implementation Phases section claims "Phases are independent except where noted" but never notes this coupling. Address by: explicitly documenting that the in-session-staleness closure requires both Phase 2 and Phase 3, and either (a) ordering the phases as 1 -> 3 -> 2 -> 4 -> 5 (so init's directive lands before the hook starts referring to it), or (b) noting that the hook payload's Read instruction is itself sufficient if the agent obeys it (in which case Phase 3 is redundant).

**Non-blocking finding (1.B):** "Read the current plugin version from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`" is reasonable, but Open Question #3 raises the alternative of comparing rule-content hashes. Given that the user explicitly worried about "directive noise" and the user's earlier "agents will almost certainly do the action if they can in their context" framing implies a high cost to false-positive nags, Q3 deserves more weight than its current "deferred to a follow-up" status. Consider: emit a hash of the concatenated rule bodies into the version comment alongside the version number, and compare the hash rather than the version. The marginal complexity is small (one sha256 call in init, one comparison in the hook) and it removes the entire class of patch-bump nags. I would not block on this, but the proposal should escalate Q3 from "deferred unless empirical noise proves disruptive" to "evaluate during Phase 2 implementation; defer only if the version-only path tests cleanly across a simulated patch-bump scenario".

#### Section 2 (Update `/cdocs:init`)

The marker addition is straightforward and explicitly aligned with the existing OC and AGENTS.md markers (good).
The Read-after-write directive sample names the path explicitly and the language ("disregarded in favor of the freshly Read content") is appropriate.

**Blocking finding (2.A):** The proposal asserts "the agent treats the Read result as authoritative" but does not flag that this assertion has the same directive-compliance dependency as the hook's refresh nudge. The Read-after-write design assumes that (a) the agent obeys the directive to invoke Read, AND (b) when the agent's working context contains both an @-imported version of the rules and a freshly-Read version of the rules, the agent treats the latter as authoritative. Step (b) is empirically untested and is not the same property as directive obedience. An agent may Read the file (obeying the directive) but then continue to answer rule-related questions from the @-imported content because it appears earlier in context. The proposal's Group C test does sketch this exact verification, but the design section asserts the outcome as if it were established. Resolve by softening "the agent treats the Read result as authoritative" to "the design assumes the agent treats the most-recently-Read rule content as authoritative; Group C of the Test Plan validates this assumption", and add a brief mention to the Known Limitations subsection (Phase 4) that calls this out as a second layer of model-instruction-following risk distinct from directive obedience.

**Non-blocking finding (2.B):** The Read-after-write directive lives in the skill's response output. If the skill is invoked outside a freshness-hook-triggered context (e.g. a user runs `/cdocs:init` manually for a first-time setup or because they want to refresh), the directive still fires. That is harmless in most cases but may be noisy on first-time init where there is no prior @-imported rule content to supersede. Add a Phase 3 constraint: "Directive appears only when the rule file actually changed during the run (idempotency)" already addresses the no-op case, but consider also suppressing the directive on first-time creation (where there is no prior in-context state to override). Or simply note that the directive is harmless even on first-time runs because the agent's Read then matches what the @-import will load on next session start. Either is fine; the proposal currently says nothing.

#### Section 3 (Update the README architecture section)

"Honest framing: one delivery mechanism" is good and matches the writing convention against history-agnostic framing while still being accurate.
Known Limitations bullets are appropriate.

**Non-blocking finding (3.A):** The README change should also note that the directive obedience and the Read-then-treat-as-authoritative behavior are both empirical assumptions (per finding 2.A above), not properties guaranteed by the CC framework.

### Important Design Decisions

Strong section overall. Each "Why" is direct and the alternatives are named.

**Non-blocking finding:** "Why no backwards-compat for the old hook behavior" cleanly handles the in-plugin migration. Open Question #4 raises the user-level hook installed by a prior `/cdocs:init` (the old delivery path some users may have configured). The decision section should briefly acknowledge that user-level hooks are out of scope (matching Q4) so a contributor reading only this section understands the boundary.

### Edge Cases / Challenging Scenarios

Comprehensive list. **Blocking finding:** The "Marker present but malformed" case says "A `.claude/rules/cdocs.md` with the comment in an unexpected format (e.g. older comment shape, missing version number) is treated as stale." This treats malformed-and-missing as the same case (both emit refresh directive). That is fine, but the case omits the failure mode where the comment LOOKS valid but contains a version string that cannot be compared (e.g., a non-semver string). Should that case fall through to "treat as stale" too? Specify the comparison rule explicitly: "the hook compares versions as opaque strings; any mismatch (including non-parseable values on either side) is treated as stale." Currently the proposal implies but does not state this.

**Non-blocking finding:** "Multiple SessionStart events per session" claims idempotency because "the second hook fires see the now-current marker and exit silently." This is true ONLY IF the first hook's directive actually got the agent to run `/cdocs:init` (and the marker got updated) before the second hook fires. If the user has not yet been prompted, or if SessionStart:resume fires before the agent has a chance to act on SessionStart:startup's directive, both hook firings will emit the directive. Two directives in close succession in the same context are still harmless, but the "exit silently" claim is conditional. Either weaken the claim to "harmless duplication" or specify that the matcher remains bare `SessionStart` (per the hook's current config) so only one event fires per session.

### Test Plan

Group A (hook unit cases) is concrete and complete.
Group B (end-to-end via `claude -p`) is concrete enough and references the prior proposal's sandbox recipe correctly.

**Blocking finding (TC.1, Group C is underspecified):** This is the load-bearing test for the design's most-novel claim, and it is the least concrete section of the proposal. The current text says: "The test plants a deliberate difference between the stale and fresh rule content (e.g., a marker phrase in the fresh version only) and verifies the agent surfaces the new phrase after the Read step." A subagent implementer needs the following specified:

1. **What file is being modified?** The fresh rule content lives in `${CLAUDE_PLUGIN_ROOT}/rules/*.md` (so the plugin's source rules need a temporary marker phrase planted) AND/OR in `.claude/rules/cdocs.md` post-rewrite. Specify which one and how the test plants the difference (e.g., "patch one of `rules/*.md` to include `BLUF_TEST_TOKEN_<rand>: fresh rule content here.` before running the sandbox").
2. **What is the "stale" state in the test?** The agent's @-imported rules are the system-prompt-baked-in version. Whose version is "stale"? Is the sandbox initialized with a prior version of the rule file (e.g., the test writes a stale `.claude/rules/cdocs.md` with an older version marker, then bumps the plugin version, then runs the sandbox)? Specify the setup.
3. **What probe question reliably surfaces the difference?** "What does the cdocs writing-conventions BLUF rule say?" is vague: the BLUF rule's actual content does not have a single-line answer, and the agent's response may paraphrase. Use a sentinel: plant a phrase like `THE_FRESH_RULE_SENTINEL_<rand>: prefer X over Y` and probe with `claude -p "What sentinel string appears in your loaded cdocs rules? Echo it verbatim."`.
4. **How is "before the Read step" tested without giving the agent a chance to Read?** The test plan implies a comparison "before" and "after" but in a single `claude -p` invocation the agent will either Read or not. Spell out the two-shot structure: shot 1 is `claude -p "Without running /cdocs:init and without using any tools, what sentinel string appears in your loaded cdocs rules?"`; shot 2 is `claude -p "Run /cdocs:init then echo any sentinel string in your loaded cdocs rules."`. The fail condition is shot 1 echoing the fresh sentinel (which would mean either the test is broken or @-imports already see the fresh version) OR shot 2 NOT echoing the fresh sentinel (which would mean the Read step does not update working context).
5. **What is the pass criterion?** State explicitly: "shot 1 echoes the stale sentinel or NOT FOUND; shot 2 echoes the fresh sentinel verbatim."

Without this level of detail, Group C is not actionable and the design's most-novel assumption remains empirically unvalidated. **Resolve by rewriting Group C with the four-element setup above.**

**Non-blocking finding (TC.2):** The Verification Methodology section says Group C is the gating test for Phase 3, but Group C's outcome also bears on the README's Known Limitations subsection (Phase 4). If Group C fails, the README needs to document the failure mode and the fallback (auto-rewrite hook). Note this back-edge: a failed Group C feeds Phase 4 content updates and may trigger the auto-rewrite fallback design.

**Non-blocking finding (TC.3):** Group B's "Agent obeys directive" test verifies the agent invokes `/cdocs:init` after seeing the freshness directive. This is the equivalent of the report's Q1 (hook-injected directive compliance). The proposal should state the pass threshold explicitly (single-shot pass? >90% across N runs?). The report set a 90% bar; the proposal should either inherit that or justify a different bar. As written, "verify the agent invokes" reads as a single-shot pass, which is too lenient for a load-bearing assumption.

### Verification Methodology

Concise and correct. **Non-blocking finding:** Step 2 says "Runs `claude plugin validate` on the plugin manifest after touching `hooks.json` or `inject-rules.ts`." Confirm this command exists in the current CC build (the proposal's prior investigations did not exercise it); if it does not exist, replace with the equivalent validation step the implementer should perform.

### Implementation Phases

**Blocking finding (IP.1, phase coupling):** The proposal says "Phases are independent except where noted" but never notes the coupling between Phase 2 and Phase 3 that I identified in finding 1.A. Either:
- Order phases as **Phase 1 (marker) -> Phase 3 (Read-after-write directive) -> Phase 2 (hook rewrite) -> Phase 4 (README) -> Phase 5 (supersession)**, so init's directive is in place before the hook starts referring to it.
- OR explicitly state: "Phase 2 and Phase 3 must ship together; do not merge the hook rewrite (Phase 2) until init's Read-after-write directive (Phase 3) is also ready."

Currently a subagent implementer is invited to ship Phase 2 alone, which leaves the in-session staleness gap open for any session where the agent ignores the hook's inline Read instruction (which itself relies on the same directive obedience that Phase 3's directive depends on, but without the init skill reinforcing it).

**Non-blocking finding (IP.2):** Phase 5 (mark prior proposal as evolved) is correctly out of the implementation-validation critical path but should still be ordered last so it is not done speculatively. The proposal already has Phase 5 last; this is fine. Just confirm: Phase 5 happens only after Group B and Group C tests pass.

### Open Questions

Q1 (directive compliance) is the right open question and is properly flagged as load-bearing.
Q2 (devcontainer) is appropriately noted given the project memory entry.
Q4 (backward compatibility for user-level hooks) is correctly out of scope.

**Blocking finding (OQ.3):** As noted in 1.B above, Q3 (hash-based comparison) deserves more weight than "deferred to a follow-up unless empirical noise proves disruptive." The user's stated concern about directive noise from patch-level bumps elevates this above a deferral. Recommend escalating Q3 to a decision the implementer makes during Phase 2 with a concrete test: in the sandbox, simulate a patch bump that changes only `plugin.json` version (no rule content change). If the version-only hook emits a refresh directive in that scenario, switch to hash-based comparison; if the implementer can suppress the directive when content is unchanged via some other means (e.g., the marker already contains a content hash and the hook compares that), document the choice in the devlog.

### Writing Conventions

- BLUF: present and accurate.
- Sentence-per-line: followed consistently.
- Em-dashes: I see none in the proposal body. Good.
- History-agnostic framing: mostly followed; see the BLUF and Background nits above.
- Direct links: #14200 is linked correctly on first mention. #16538 is not mentioned in this proposal body (it is referenced via the linked prior proposal); not a defect.
- Callouts: NOTE callout in Background is correctly attributed (`opus/cdocs-rule-delivery`).

## Verdict

**Revise.**

The design is sound and addresses the user's stated concerns at the architectural level (no spillover-fetch dance; the Read-after-write directive does target in-session staleness; Group C is the empirical gate for the behavior-change claim).
The blocking issues are concrete and localized: phase coupling between 2 and 3, underspecification of Group C, the unflagged second layer of directive-compliance risk inside the "Read result is authoritative" assertion, and the elevation of Open Question #3 from "deferred" to "evaluated during Phase 2".
All four are addressable with edits to existing sections rather than redesign.

## Action Items

1. [blocking] Document the Phase 2 / Phase 3 coupling in Implementation Phases. Either reorder phases as 1 -> 3 -> 2 -> 4 -> 5, or add an explicit "Phase 2 and Phase 3 must ship together" constraint. See finding 1.A and IP.1.

2. [blocking] Rewrite Group C of the Test Plan with the four-element specification: (a) which file the fresh-content marker lives in; (b) how the test plants the stale baseline; (c) the sentinel-string probe that surfaces the difference; (d) the two-shot structure that separates "before Read" from "after Read"; (e) explicit pass criteria. See finding TC.1.

3. [blocking] Soften the "agent treats the Read result as authoritative" assertion in Section 2 to call out that this is an empirical assumption validated by Group C, distinct from directive obedience. Add a Known Limitations bullet in Phase 4 covering the same. See finding 2.A.

4. [blocking] Clarify the marker comparison rule in Edge Cases: "the hook compares versions as opaque strings; any mismatch (including non-parseable values) is treated as stale." See Edge Cases finding.

5. [blocking] Escalate Open Question #3 (hash-based vs. version-based comparison) from "deferred unless noise proves disruptive" to "evaluated during Phase 2 with a simulated patch-bump test." Specify the go/no-go criterion (e.g., if the version-only hook emits a directive on a content-unchanged patch bump, switch to hash). See finding 1.B and OQ.3.

6. [non-blocking] Specify a pass threshold for Group B's "Agent obeys directive" test (single-shot? N-of-M? >=90%?) consistent with the evergreening report's compliance bar. See finding TC.3.

7. [non-blocking] Add a brief note that Phase 5 happens only after Group B and Group C tests pass, not speculatively. See finding IP.2.

8. [non-blocking] Address the multiple-SessionStart-events idempotency caveat: weaken to "harmless duplication" rather than "exit silently" since the second-fire-sees-current-marker chain depends on agent compliance with the first directive. See Edge Cases.

9. [non-blocking] Soften BLUF and Background phrasing slightly to be more history-agnostic (drop "currently silently broken" or "confirmed this"). See BLUF and Background findings.

10. [non-blocking] Note in Important Design Decisions that user-level hook removal is out of scope (matching Open Question #4) so contributors reading only that section see the boundary. See Important Design Decisions finding.

11. [non-blocking] Confirm `claude plugin validate` exists on the target CC build, or replace with the equivalent validation step. See Verification Methodology finding.

## Multi-Choice Clarifications for the Author

These are non-blocking decisions where reasonable people would split:

**Q-A: How tight is the Phase 2 / Phase 3 coupling?**

- **A1:** Strict coupling: ship them in a single PR.
- **A2:** Reorder so Phase 3 lands first (init emits the directive; hook continues to be broken but the materialization path is unchanged in the meantime).
- **A3:** Phase 2 alone is acceptable: the hook's inline Read instruction is sufficient to close in-session staleness even without Phase 3's init-side directive, and Phase 3 is "defense in depth".

**Q-B: How aggressive is the hash-based comparison adoption?**

- **B1:** Implement hash-based from day one (Phase 2 incorporates the hash in the marker).
- **B2:** Implement version-based first; switch to hash only if the simulated-patch-bump test produces noise (the proposal's current stance, with Q3 escalated to a Phase 2 decision per action item 5).
- **B3:** Keep Q3 deferred entirely; ship version-based and revisit only if real-world users report noise.

**Q-C: What is the failure response if Group C fails?**

- **C1:** Halt: switch to the auto-rewrite-hook fallback per Open Question #1.
- **C2:** Ship anyway, with a stronger Known Limitations bullet acknowledging the staleness window will not close mid-session.
- **C3:** Ship with an inline content output in `/cdocs:init` (the proposal's last-paragraph alternative in Group C: "an alternative is to have `/cdocs:init` output the new rule content directly inline rather than expecting a follow-up Read"). This is a third path not enumerated as a fallback design; it deserves either escalation to a named fallback or removal.

---

# Round 2 Re-Review

**Reviewer:** @claude-opus-4-7-1m
**At:** 2026-05-12T20:45:00-07:00
**Round:** 2
**Prior verdict:** Revise (4 blocking + 7 non-blocking action items, 3 multi-choice questions).
**Author's choices:** Q-A=A1 (ship together), Q-B=B2 (version-first, Phase-2 go/no-go), Q-C=hybrid C3-primary + C1-secondary (inline content fallback, then auto-rewrite hook).

## Round 2 Summary Assessment

All four blocking items and all seven non-blocking items land cleanly in the round-2 revision.
Group C is now actionable end-to-end for a subagent implementer: file targets, stale-baseline construction, sentinel-string probe, two-shot structure, pass criteria, and cleanup instructions are all explicit.
The Phase 2/3 coupling is unambiguous in the Implementation Phases preamble (line 303) and is structurally implied by Section 1's payload referring to Section 2's marker (line 67) and by the new "Fallback if Group C fails" subsection sitting inside the Proposed Solution.
The Read-after-write authoritativeness claim is now correctly framed as an empirical assumption validated by Group C, and the Known Limitations bullet (line 141) calls out the two layers of model-instruction-following risk independently.
Verdict: **Accept**.

## Round 2 Verification of Action Items

1. **Phase 2/3 coupling (blocking #1).** Resolved. Lines 301-303 explicitly state "Phase 2 and Phase 3 must ship together (single PR)" with the reasoning. The prior "phases are independent except where noted" wording is gone. Phase-5-only-after-Group-B-and-C addendum is in the same paragraph.

2. **Group C four-element specification (blocking #2).** Resolved. Lines 263-288 now include:
   - (a) Target file: `plugins/cdocs/rules/frontmatter-spec.md`, with the explicit instruction to patch the "alphabetically first file" (line 269). The version bump in `plugin.json` is named (line 273).
   - (b) Stale baseline: hand-written or older-init-generated `.claude/rules/cdocs.md` lacking the sentinel and naming the prior plugin version, with project `CLAUDE.md` `@`-importing it (lines 275-276).
   - (c) Sentinel probe: literal sentinel string `THE_FRESH_RULE_SENTINEL_<rand>: prefer X over Y for testing purposes.` (line 271) probed verbatim in both shots.
   - (d) Two-shot structure: shot 1 (no tools, no `/cdocs:init`) on line 281, shot 2 (`/cdocs:init` then Read then echo) on line 282.
   - Pass criterion: shot 1 returns NONE or non-fresh sentinel; shot 2 echoes fresh sentinel verbatim (line 284).
   - Cleanup: revert patch and version bump (line 286).
   - Failure response cross-references "Fallback if Group C fails" (line 288).

3. **Soften "Read result is authoritative" (blocking #3).** Resolved. Lines 110-114 now read "The design assumes that for the rest of the session, the agent treats the most-recently-Read rule content as authoritative..." followed by an explicit "empirical assumption distinct from directive obedience" sentence and a Group C cross-reference. Known Limitations bullet 2 (line 141) lists the two layers of risk with the (a)/(b) split.

4. **Marker malformation edge case (blocking #4).** Resolved. Lines 198-201 now say: "The hook compares versions as opaque strings. Any mismatch (including a missing version number, an unparseable value, a non-semver string, or a comment-shape that doesn't match the canonical pattern) is treated as stale and emits the standard refresh directive." Coverage spans all four malformed-marker subcases.

5. **Q3 escalation with concrete pass/fail (blocking #5).** Resolved. Lines 374-382 reframe Q3 as "decision required during Phase 2" with an explicit go/no-go: bump `plugin.json` version without modifying any `rules/*.md` content, run the version-based hook against an otherwise-current project, and switch to hash-based if a refresh directive fires. The hash-variant marker format (`<!-- cdocs rules vX.Y.Z hash=<sha256> ... -->`) is specified.

6. **Group B pass threshold (non-blocking #6).** Resolved. Line 260 names the 9-of-10 bar explicitly and cites the evergreening report. Match-case and mismatch-fires-directive tests retain single-shot thresholds, which is appropriate since hook payload presence is deterministic.

7. **Phase 5 not speculative (non-blocking #7).** Resolved. Line 303 includes "Phase 5 (mark prior proposal as evolved) happens only after Group B and Group C tests have passed, not speculatively."

8. **Multiple-SessionStart idempotency rephrasing (non-blocking #8).** Resolved. Lines 222-223 rewrite the claim to "duplicate-safe" with the explicit acknowledgment that the second-fire-sees-current-marker chain depends on agent compliance with the first directive.

9. **BLUF and Background phrasing (non-blocking #9).** Partially resolved. The Background's "confirmed this" is replaced by "Empirical observation by both implementer and an independent QA, each using a fresh marker" (line 38). The BLUF (line 19) retains "currently silently broken" qualifier as the prefix of the cap statement. This is borderline acceptable: the qualifier modifies a present-tense factual claim about the cap, not the hook's design history. Not blocking.

10. **User-level hook out of scope (non-blocking #10).** Resolved. Lines 185-189 add a dedicated "User-level hook removal is out of scope" subsection in Important Design Decisions, cross-referencing Open Question 4 and Phase 4.

11. **`claude plugin validate` confirmation (non-blocking #11).** Resolved. Line 295 names both commands explicitly (`claude plugin validate plugins/cdocs/.claude-plugin/plugin.json` and `claude plugin validate .claude-plugin/marketplace.json`) and confirms existence on the current CC build via prior Phase 1 work.

## Round 2 Verification of Multi-Choice Decisions

**Q-A (A1, single PR coupling):** Implemented. Implementation Phases preamble (line 303) states the constraint plainly. The constraint is also implicit in Proposed Solution Section 1 (line 67 references "see section 2" for the marker) and Section 2 (which defines the marker that Section 1's hook reads). Someone reading only Proposed Solution sees the structural coupling; someone reading only Implementation Phases sees the explicit shipping constraint. The "Three coordinated changes" heading on line 59 is not the strongest possible cue but is sufficient given the structural references.

**Q-B (B2, version-first with Phase-2 go/no-go):** Implemented. Open Question 3 (lines 374-382) now reads as a Phase-2 decision item with a concrete simulated-patch-bump test, not a deferred follow-up. The marker-format change for the hash variant is documented.

**Q-C (hybrid C3-primary + C1-secondary):** Implemented as a three-rung ladder:
- Primary (Read-after-write directive) per Section 2.
- Secondary (inline content in `/cdocs:init` output) named in the new "Fallback if Group C fails" subsection at lines 118-123.
- Tertiary (auto-rewrite hook with documented one-session lag) at lines 125-126.
The ladder is internally consistent and lines 128-129 state explicitly that "Group C results determine which rung is active in the shipped design." The fallback subsection cross-references the evergreening report.

## Round 2 Findings on the Revision

### Group C Implementer Walkthrough

I walked through Group C step-by-step as a subagent implementer would:

1. **Patch `plugins/cdocs/rules/frontmatter-spec.md`** with a sentinel line. Clear.
2. **Bump `plugins/cdocs/.claude-plugin/plugin.json` version**, e.g., 0.1.0 -> 0.1.1. Clear.
3. **Sandbox project setup:** hand-write `.claude/rules/cdocs.md` without the sentinel and with the prior version marker; add `CLAUDE.md` with `@.claude/rules/cdocs.md`. Clear.
4. **Wire the hook via wrap.sh + settings.json** per the prior proposal's recipe. Clear (the recipe is referenced by direct link).
5. **Shot 1:** invoke with explicit "no tools, no `/cdocs:init`" prompt. Confirm sentinel does not appear. Clear.
6. **Shot 2:** invoke with explicit "/cdocs:init then Read then echo" prompt. Confirm sentinel appears verbatim. Clear.
7. **Cleanup:** revert source patch and `plugin.json` version. Clear.

One minor ambiguity worth surfacing as a non-blocking observation: in Shot 1, the user prompt explicitly tells the agent NOT to use tools, but the SessionStart hook's `additionalContext` still injects the freshness directive. If the agent prioritizes the freshness directive over the user's "no tools" instruction (a known directive-vs-user-instruction conflict), Shot 1 may fail for reasons unrelated to the test's intent. The implementer should be prepared to retry Shot 1 with stronger user instructions if this happens, but the cleanup-then-retry path is implicit in any test loop. Not blocking; surface in the devlog if observed.

### Phase 2/3 Coupling Visibility From Different Reading Orders

- **Implementation Phases only:** line 303 states the coupling explicitly and includes the reasoning. Clear.
- **Proposed Solution only:** Section 1's payload (lines 73-79) instructs the agent to Read the rewritten `.claude/rules/cdocs.md`, but the rewriting is described in Section 2. Line 67 explicitly refers to "see section 2" for the marker. Section 2 in turn defines both the marker and the Read-after-write directive that Section 1's payload depends on. A reader of Proposed Solution alone sees Section 1 mention Section 2's marker, Section 2 add both the marker and the directive, and the "Fallback if Group C fails" subsection sit between them. The coupling is structurally implicit and well-supported, even if "must ship together" is not phrased verbatim.
- **BLUF only:** the BLUF previews the hook (freshness check) and the Read-after-write directive as separate components but does not state coupling. This is OK: the BLUF is a teaser, not a constraints document.

### Fallback Subsection Consistency

Lines 118-129 describe the three-rung ladder; lines 141 (Known Limitations bullet 2) and 288 (Group C failure response) both cross-reference the fallback. The ladder is self-consistent: primary -> secondary -> tertiary with explicit failure-mode triggers. The tertiary (auto-rewrite hook) is cross-linked to the evergreening report.

One minor observation: the Phase 4 README acceptance criterion (lines 350) says "a contributor reading the README understands the delivery is `/cdocs:init`-driven with a small freshness hook, not the prior three-layer-graceful-degradation framing." The Phase 4 known-limitations bullets don't explicitly enumerate the fallback ladder, but the cross-reference from Group C ("Phase 4's Known Limitations subsection must reflect whichever rung of the fallback ladder ships") implies the README will be updated post-Group-C. Acceptable for the proposal's current scope.

### Writing Conventions

- BLUF: present and now drops the "on the current build" qualifier; "currently silently broken" remains as a prefix modifying a present-tense cap claim. Acceptable.
- Sentence-per-line: followed in all new content. Bullets occasionally pack multiple sentences (e.g., Known Limitations bullets, Edge Cases bullets), which is conventional for bullet lists.
- Em-dashes: none in the revised content. Hyphenated compound modifiers (e.g., "Read-after-write") are correct.
- History-agnostic framing: Background's "Empirical observation" is direct. Important Design Decisions and Edge Cases are present-tense throughout. Implementation Phases narrate forward-looking work, which is intrinsic to the section.
- Direct links: #14200 linked on first mention. The prior proposal, devlog, and report are all linked directly.
- Callouts: NOTE in Background is correctly attributed.

### Q3 Pass/Fail Concreteness

Lines 380-382 specify a single-shot patch-bump simulation as the go/no-go: bump `plugin.json` version without modifying any `rules/*.md` content, run the version-based hook, observe directive fire/no-fire. If fires: switch to hash. If doesn't fire: keep version-based and document in devlog. This is concrete and actionable.

## Round 2 Verdict

**Accept.**

All 11 round-1 action items are addressed with edits that land in the right sections.
The author's choices on Q-A (A1), Q-B (B2), and Q-C (hybrid C3+C1) are implemented faithfully.
Group C is actionable for a subagent implementer; the fallback ladder is internally consistent; the Phase 2/3 coupling is unambiguous from any sensible reading order; the Q3 escalation has a concrete simulated-patch-bump test.
Writing conventions are clean.

Two non-blocking observations the author may carry forward as devlog notes during implementation (not action items, not gates on acceptance):

1. Group C Shot 1's "no tools" user instruction may collide with the freshness directive's "run /cdocs:init" instruction. If the agent prioritizes the system-reminder over the user instruction, Shot 1 fails for a reason unrelated to the test's intent. Surface in the devlog if observed.

2. Section 2's Read-after-write directive fires unconditionally on every `/cdocs:init` invocation including first-time setup, where there is no prior @-imported content to supersede. Harmless but slightly noisy; either suppress on first-time creation or document that the noise is benign (the agent's Read result will match the about-to-be-loaded @-import on the next session). Phase 3 acceptance criteria already require idempotency on no-op runs, which covers the most common case.

## Round 2 Action Items

None blocking.

Two non-blocking observations carried forward as devlog hints (see "Round 2 Verdict" above for context):

1. [non-blocking, devlog hint] Group C Shot 1 may collide with the freshness directive on user-instruction-vs-system-reminder priority. If observed, surface in the implementation devlog and consider whether the test prompt needs strengthening.

2. [non-blocking, devlog hint] Section 2's Read-after-write directive fires on first-time `/cdocs:init` runs as well. Either suppress on first-time creation or document the benign-no-op case in the skill body. Phase 3's idempotency-on-no-op acceptance criterion already covers re-runs.
