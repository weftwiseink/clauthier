---
review_of: cdocs/proposals/2026-09-17-graphify-cdocs-integration.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-23T10:05:00-08:00
task_list: code-graph/cdocs-integration
type: review
state: live
status: done
tags: [fresh_agent, lean_track, propose_revise, architecture, recall_parity, cli_first, discriminator, scope_cut]
---

# Review (round 4): Graphify cdocs integration, lean-track re-scope

## Summary Assessment

This is a lean-track re-scope of an already-accepted proposal, so the bar is narrow: are the five re-scope deltas actually landed in the text, is the spine intact, and is the shipped increment (Phase 2) green-lightable without Phase 1 or Phase 3?
All five deltas land, in the text and not merely claimed: Phase 2 is the headline in BLUF/Summary/Phases-intro/Phase-order; Phase 1 is demoted to opt-in instrumentation with every "gate/prerequisite/blocks" hunk removed; Phase 3 stays a deferrable opt-in gate; the librarian (formerly Phase 4) and adapter (formerly Phase 5) are struck into an "Out of scope (dropped)" section with a fresh-proposal pointer; and the non-negotiables (recall parity structural + measured-in-Phase-3, CRDT D3 guard verbatim, AID-not-guarantee, CLI-first, multi-file targeting) are preserved.
I scanned for stale contradicting phrasing ("first increment", "prerequisite gate", "nothing downstream admissible", "Phases 4-5 deferred later increments") and found none surviving as live plan.
Verdict is **Accept**. One should-fix (a real dangling cross-reference: D2 still calls the labeled-corpus sizing "a Phase 1 deliverable" though the corpus now belongs to Phase 3) plus two nits (the lone "Bet 1" heading vs the Summary's "one bet"; the H1 title's "and the librarian question"). None is blocking; all are enumerated below to clear per propose-revise convention.

## Verification of the five deltas

### 1. Phase 2 is the shippable headline - LANDED

Reframed consistently across every headline surface:
- BLUF: "Ship the integration itself (Phase 2): prime a graphify dependent-set brief into the loop ... validated by a `/cdocs:ablate` spot-check on real multi-file tasks."
- Summary: "The shippable deliverable is **Phase 2**."
- Phases intro: "**The shippable HEADLINE is Phase 2: the integration itself.**"
- Phase ordering: Phase 2 is authored first, subtitled "(the headline deliverable)", with "Depends on: nothing (Phase 1 is optional and not a prerequisite)."
The old "shippable FIRST INCREMENT is Phase 1 ... plus Phase 2" framing is fully removed (Summary hunk, Phases-intro hunk, and the deleted FIRST-INCREMENT-BOUNDARY NOTE). No "first increment / first-increment" string survives anywhere (grep-confirmed).

### 2. Phase 1 demoted to OPTIONAL instrumentation - LANDED

The old Phase 1 was a hard gate: "gate; prerequisite for all claims", "Constraint: ... Nothing downstream is admissible until it lands", "Depends on: nothing. Blocks: Phases 2, 3, 4." Every one of those is gone.
The new Phase 1 header reads "Coarse token-accounting baseline (OPTIONAL instrumentation)" and its body opens "Opt-in, for when hard live per-role numbers are wanted. It does NOT block Phase 2 and is not a prerequisite for any claim."
The demotion is echoed in BLUF, Summary (line 40), the Discriminator section (line 107), Test Plan (line 189, "Opt-in; not a gate"), Verification (line 205), and Phases-intro (line 215). The framing is internally consistent: the per-task causal verdict is DELEGATED to `/cdocs:ablate`, and the coarse meter is complementary, not a gate.

### 3. Phase 3 kept as a deferrable opt-in later increment - LANDED

Header: "Phase 3: Formal discriminator gate (deferrable later increment)", body "Opt-in and NOT required to ship Phase 2. This is where recall parity is MEASURED rather than protected only structurally." "Depends on: Phase 2." The measured recall-parity hard gate (D2) is correctly relocated here from the old near-term "roll across roles + measure" phrasing.

### 4. Librarian (Phase 4) and adapter (Phase 5) dropped - LANDED

A new "### Out of scope (dropped)" section strikes both with correct historical framing ("formerly Phase 4", "formerly Phase 5") and the required "revisit via a FRESH proposal" pointer. Grep confirms "Phase 4"/"Phase 5" appear ONLY inside those two struck bullets, never as live plan.
The drop is threaded through the body, not just appended: the "Bet 2" section is retitled "The librarian (considered, dropped from scope)"; D1 is collapsed to the tool-first bet with the deep librarian analysis moved into a NOTE that points to "Out of scope"; the Objective's secondary line now "lands on the tool; the librarian is out of scope (see D1)"; the "Librarian, if built, on OpenCode" edge case is deleted; the Test Plan "Librarian (only if Phase 4 proceeds)" row is deleted; and the "Bounded shared-librarian context" Investigation item is deleted.

### 5. Non-negotiables preserved - LANDED

- **Recall parity.** Still a hard principle: structural in the shipped increment (additive-only + skip-scope + flag), measured gate deferred to Phase 3. The BLUF's "a token win that misses a dependent is a regression" survives. D2's three-part gate (labeling protocol, sized corpus, pass-rule-under-noise) is otherwise unchanged.
- **CRDT blind spot (D3).** Zero diff hunks; the structural guard (co-surfaced observe/subscribe channel + near-empty-set skip-scope trigger) survives verbatim, including the WARN.
- **AID-not-guarantee.** Bet 1's "AID, not guarantee" property and the brief caveat survive intact.
- **CLI-first (D4).** Untouched except the "first increment" -> "Phase 2" wording swap; the transport-agnostic CLI-to-MCP mapping and the CLI-backed-by-default rationale are intact.
- **Multi-file blast-radius targeting.** The Probe-A-grounded "where scoping plugs in" NOTE, D2's multi-file corpus constraint, the Test Plan task-shape row, and the expected-null single-file framing are all intact.

## Shipped increment is self-contained

Phase 2 is genuinely green-lightable without Phase 1 or Phase 3, and the dependency claims are honest:
- Phase 2 "Depends on: nothing"; its sole precondition (license) is RESOLVED (Apache-2.0), with only a per-pin `0.9.61` spot-check residual that "would block adoption at that pin, nothing more."
- Phase 2's body is complete on its own: provision an index, wire the thin CLI contract, prime the brief, wire skip-scope, integrate reviewer-first behind a flag, validate with the ablate spot-check.
- Recall parity in the increment rests only on structural mechanisms Phase 2 itself ships (additive + skip-scope + flag), not on the deferred measured gate.
This also closes the round-3 review's lone should-fix (the "recall parity gated" claim outran Phase 2's success criteria): the lean track now states plainly "Recall parity is protected STRUCTURALLY here, not measured", so the expectational gap is gone.

## Ablate spot-check as validation of record - adequately honest

The framing is honest about what the spot-check does and does not prove. It supplies the per-task causal "does scoping pay" verdict on "a couple of real MULTI-FILE tasks" (harness already built and e2e-verified), and the proposal is explicit that this is NOT a corpus-measured recall gate (that is deferred to Phase 3) and NOT a before/after coarse baseline (that is the optional Phase 1). Investigation Requested item 1 asks a reviewer to confirm the spot-check plus the structural guard carry the increment and that "no gate silently reintroduces a dependence on the optional Phase 1 meter."
Caveat worth stating plainly: "a couple of tasks" proves scoping pays on those tasks, not corpus-wide, and the honest load-bearing safety net is the structural recall guard (scoping only ever adds context), not the spot-check's breadth. The proposal says exactly this, so the honesty bar is met. The one place this discipline slips is the D2 cross-reference in the should-fix below.

## Pressure-testing the reviser's four flagged judgment calls

- **(a) H1 title still says "... and the librarian question".** Acceptable to keep, optional to trim. The document genuinely still resolves the librarian question (D1 weighs it and lands tool-first; the Objective's secondary goal is exactly this adjudication), so the title is not false. But with the librarian struck from scope, "Graphify integration into cdocs loops" would read cleaner. Non-blocking NIT; author's call.
- **(b) Librarian residue kept in D1/Bet-2.** Coherent, not confusing. The retitled section plus the D1 NOTE make the disposition unambiguous: considered, dropped, analysis preserved by pointer to "Out of scope", reopenable via fresh proposal. The residue is the right amount: enough to explain WHY the bet was dropped without carrying dead plan. PASS.
- **(c) Lone "Bet 1" heading with no numbered "Bet 2".** A real minor inconsistency. The Summary now says "The proposal's one bet is ...", yet the Proposed Solution heading is still "### Bet 1: a stateless graph-scoping surface (core)" and the top NOTE still says "Bet 1 as core." With only one bet, the ordinal is orphaned. NIT (see action item 2).
- **(d) D5 index-provisioning moved from "decided in Phase 3" to "Phase 2 picks the simplest workable option".** Correct and consistent, and in fact necessary. Phase 3 is no longer the near-term roll-out phase, and Phase 2 must provision an index to function, so the decision has to move into Phase 2. D5, the Open Questions D5 entry, and Phase 2's "Provision a graphify index" step now agree. The staleness contract ("stale/missing means skip-scope") is untouched. PASS.

## Section-by-Section Findings

### SHOULD-FIX (non-blocking): D2 still calls the labeled-corpus sizing "a Phase 1 deliverable"

D2, Corpus bullet (line 132): "... the corpus is sized and its case-mix recorded before any gate reading is admissible; exact size is a **Phase 1 deliverable**, floored at enough per-category fixtures ..."
This is a stale cross-reference the re-scope missed. The labeled recall corpus is the substrate of the MEASURED recall-parity gate, which now lives in Phase 3. The old Phase 1 body used to "Capture the BEFORE baseline on the labeled corpus (D2), including missed-dependent labels" - that line was correctly deleted, so the new (optional) Phase 1 builds only the per-role token meter and no longer produces a corpus. Attributing corpus-sizing to "a Phase 1 deliverable" therefore (i) points at a deliverable Phase 1 no longer contains, and (ii) subtly re-couples the deferred measured gate to the now-optional Phase 1 - the exact "gate silently reintroduces a dependence on the optional Phase 1 meter" failure Investigation Requested item 1 tells a reviewer to guard against.
Non-blocking because it is a labeling error inside a section (D2) whose gate is itself deferred to Phase 3, so it cannot affect the shipped increment. But it is a genuine internal inconsistency and the one substantive residue of the re-scope.
Fix: change "exact size is a Phase 1 deliverable" to "exact size is a Phase 3 deliverable" (or "is sized in Phase 3, before the measured gate reads").

### NIT: "Bet 1" ordinal vs "one bet"

See judgment call (c). With a single bet, drop the ordinal: retitle "### Bet 1: a stateless graph-scoping surface (core)" to e.g. "### The graph-scoping surface (core)", and soften the top NOTE's "Bet 1 as core" to "the scoping surface as core." Cosmetic; improves internal consistency with the Summary's "one bet."

### NIT: H1 title's "and the librarian question"

See judgment call (a). Optional trim to "Graphify integration into cdocs loops." Defensible either way.

## Verdict

**Accept.**

All five re-scope deltas are landed in the document text, the spine is verifiably intact (D3 zero-diff; recall parity, AID, CLI-first, multi-file targeting preserved), Phase 2 is self-contained and honestly green-lightable without Phase 1 or Phase 3, and the ablate spot-check is framed with honest limits. The single should-fix is a dangling phase label in a deferred section, not a design defect; the two nits are cosmetic. Status stays `implementation_ready`; the propose-revise loop can close and proceed to the iterate phase, clearing the items below.

## Action Items

1. [should-fix, non-blocking] In D2's Corpus bullet, change "exact size is a Phase 1 deliverable" to attribute corpus-sizing to Phase 3 (the phase that owns the measured recall gate), so no deferred gate re-couples to the now-optional Phase 1.
2. [nit] Drop the orphaned "Bet 1" ordinal: retitle the Proposed Solution heading to a numberless "The graph-scoping surface (core)" and soften the top NOTE's "Bet 1 as core" to match the Summary's "one bet."
3. [nit] Optionally trim the H1 title's "and the librarian question" now that the librarian is out of scope.

## Clarifications for the maintainer (multiple choice)

On action item 1 (the D2 corpus-sizing label), how should it be reconciled?

- (a) Re-attribute to Phase 3: "exact size is a Phase 3 deliverable, sized before the measured gate reads" (cleanest; corpus lives with the gate it feeds).
- (b) Detach from any phase: "exact size is sized before any gate reading is admissible" (drops the phase pointer entirely; safe but less specific).
- (c) Leave as-is (accept the minor mislabel, since the whole D2 gate is deferred and cannot affect the shipped increment).
