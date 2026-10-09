---
review_of: cdocs/proposals/2026-09-17-graphify-cdocs-integration.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-22T15:30:00-07:00
task_list: code-graph/cdocs-integration
type: review
state: archived
status: done
tags: [fresh_agent, scoping_revision, architecture, recall_parity, cli_first, discriminator, first_increment]
---

# Review (round 3): Graphify cdocs integration, scoping revision

## Summary Assessment

This is a Path-A scoping re-aim of an already-accepted proposal, so the bar is narrow: are the four re-aim points cleanly integrated, is the spine intact, and is the new first-increment boundary actionable?
All four points land, cleanly and consistently, not bolted on: the discriminator is now split (per-task causal verdict DELEGATED to the accepted `/cdocs:ablate` harness, coarse per-role meter owned in Phase 1) with the fragile per-phase meter explicitly dropped and guarded against resurrection; the near-term surface is locked CLI-first with the MCP/adapter preserved as the Phase-5 seam; multi-file blast-radius targeting is threaded through the design, D2, Test Plan, Verification, and Phase 3, grounded in the real Probe A `context_gap 0` finding; and the license is stated RESOLVED (Apache-2.0, sourced) with only a per-pin spot-check residual.
The spine is verifiably untouched: D1, D3, and D5 carry zero diff hunks, and D2's recall-parity gate gained only an additive multi-file-corpus constraint.
Verdict is **Accept**. One non-blocking should-fix (the first-increment "recall parity gated" claim is under-specified in Phase 2's own success criteria) plus two nits, none of which should hold the first increment.

## Verification of the four re-aim points

### 1. Phase 1 shrunk + discriminator delegated - INTEGRATED

The division of labor is explicit and consistent everywhere it needs to be.
The Discriminator-first section states it directly: per-task causal verdict = `/cdocs:ablate` (DELEGATED), live per-role baseline = the Phase 1 coarse meter (owned here), and it names the per-phase meter as "the design's fragile point [...] dropped from the critical path."
Phase 1 reinforces this ("Per-phase attribution is explicitly OUT of Phase 1's critical path [...] a later phase may add finer resolution, but it must not be resurrected onto the critical path").
Test Plan, Verification step 1, and Investigation Requested item 1 all echo the same split, and item 1 explicitly asks a reviewer to confirm "no downstream gate silently reintroduces a dependence on true per-phase attribution" - exactly the consistency guard this point needed.
I scanned for stale per-phase-meter-on-critical-path phrasing and found none: every mention is in the past-tense "dropped / do not resurrect" framing.
The claim that Phase 1 reuses the ablate harness's metering path (per-subagent tokens from the dispatched-agent result payload) is technically grounded, not hand-waved.

### 2. CLI-first locked - INTEGRATED

D4, Bet 1, Phase 2, Phase 5, and the mermaid diagram are mutually consistent on CLI-first.
The diagram's query node changed to "Query engine CLI"; Bet 1 is now "Engine-behind-CLI now, adapter-ready later"; D4's title and body say "CLI-backed now" with the CLI as the default, not merely a fallback; Phase 2 is "(CLI-backed)" and wires the contract "over the CLI subcommands (`query`/`explain`/`path`), never raw `graph.json` ingestion."
The eventual seam is preserved, not deleted: Phase 5 migrates "CLI now, MCP if later adopted" onto the engine-agnostic adapter, and D4's NOTE keeps the transport-agnostic one-to-one CLI-to-MCP mapping.
This all matches the backing report (`cdocs/reports/2026-09-17-graphify-mcp-vs-cli-value-add.md`), which concludes the three CLI subcommands fully cover the scoping queries and recommends exactly the "constrain the wrapper to query subcommands" guard the proposal adopted.
No stale MCP-first-as-near-term-surface phrasing remains. (The one residual "MCP tool" exemplar in D1 is a transport-general cross-target argument, not a near-term-surface claim; see nit N1.)

### 3. Multi-file / blast-radius targeting - INTEGRATED

Coherently threaded, not appended.
A new NOTE after the diagram establishes the principle and its provenance (Probe A, single-file `explain` -> `context_gap 0`, honestly scored rather than manufactured), and it is picked up consistently in: D2's corpus (multi-file constraint, single-file retained only as expected-null controls), the Test Plan's new "Task-shape targeting" row, Verification steps 1-2, Phase 3's discriminator gate, and the "tiny diff" edge case.
The framing is disciplined in both directions: single-file/trivial is EXPECTED-NULL and "inadmissible as evidence that scoping does not pay," which correctly prevents the Probe A null from being read as a disconfirmation while also not overclaiming.
The Probe A finding is real: `cdocs/devlogs/2026-09-18-ablate-e2e-probeB-void.md` records "Complements probeA (VALID, context_gap 0)."

### 4. License resolved, not gated - INTEGRATED

Stated as RESOLVED in all three required places (D4, Phase 2 precondition, Open Questions) with a consistent residual: only a per-pin `0.9.61` LICENSE spot-check, explicitly "not a first-increment blocker."
The claim is internally consistent and sourced: PyPI `graphifyy` built from public `Graphify-Labs/graphify` (Apache-2.0 root LICENSE via the GitHub license API), distinct from the unrelated npm `graphify` random-graph generator, with the residual framed as a packaging gap (missing SPDX classifier), not a license ambiguity.
Per the review brief I did not deep-verify the external repo; the claim looks sound and is well-attributed (commit `0819da8`), so I accept it.

## Spine integrity

Confirmed UNTOUCHED against the `cdd20b4..bf181ef` diff:

- **Bet 1 as core** - preserved; only the transport wording moved from MCP to CLI.
- **Bet 2 / Phase 4 librarian, deferred + conditional (D1)** - zero diff hunks in the D1 body; the read-only-shared-service reconciliation with Pillar 3 and the bounded-context gate are intact.
- **Recall-parity HARD gate (D2)** - the three-part discriminator (ground-truth labeling, sized corpus, pass-rule-under-noise) is unchanged; the only edit is one additive line constraining the corpus to multi-file shapes, which narrows rather than weakens the gate.
- **CRDT blind-spot honesty (D3)** - zero diff hunks; the structural guard (co-surfaced observe/subscribe channel + near-empty-set skip-scope trigger) survives verbatim.
- **Index provisioning / staleness (D5)** - zero diff hunks.

The prior round-2 review's resolved blocking items (D1 consumer-floor reframe, D2 operationalized gate, D3 structural guard) are therefore carried forward intact. No silent drift.

## First-increment boundary

The boundary is clearly demarcated in four coordinated places: the BLUF ("Ship a FIRST INCREMENT"), the Summary, the Phases intro ("FIRST INCREMENT (green-lightable on its own): Phase 1 + Phase 2"), and a NOTE after Phase 2 marking the cut line.
Dependencies make it genuinely full-sendable: Phase 1 depends on nothing, Phase 2 depends only on Phase 1, Phase 2's sole precondition (license) is resolved, and Phases 3-5 are each gated on the prior.
A maintainer could green-light just Phase 1 + Phase 2 without inheriting the roll-out, the librarian, or the adapter. This is coherent and actionable.

## Section-by-Section Findings

### SHOULD-FIX (non-blocking): "recall parity gated" is under-specified in the first increment

The first-increment intro promises the slice ships "with recall parity gated," but Phase 2's own success criteria name only "reviewer receives a correct dependent set [...] briefs carry the caveat" - no recall-parity check.
The measured recall discriminator (Test Plan "Recall parity" row, Verification step 3 gate) reads as a Phase 3 activity ("Roll scoping across roles + measure").
In the first increment recall parity is protected STRUCTURALLY (scoping is additive, behind a flag, with skip-scope guaranteeing the baseline floor), and the labeled corpus with missed-dependent labels is a Phase 1 deliverable, so a measured reviewer-only recall check is in fact possible after Phase 1.
The gap is expectational: a maintainer full-sending Phase 1+2 on the strength of "recall parity gated" should know whether they get a MEASURED recall result (reviewer, on the Phase-1 corpus) or only the structural additive+skip-scope guarantee.
Reasoning: this is the one place the first-increment boundary's headline promise outruns the phase text, and the boundary's whole value is being honestly actionable. Non-blocking because the structural guarantee is real and the correctness is unaffected; it is a clarity fix, not a design fix.
Fix: add a recall-parity line to Phase 2's success criteria (reviewer recall >= unscoped baseline on the Phase-1 corpus), or qualify the intro's "recall parity gated" as "recall parity structurally guaranteed (additive + skip-scope), measured discriminator in Phase 3."

### NIT N1: D1 cross-target paragraph leans on "stateless MCP tool" as the exemplar

D1's cross-target-degradation argument still says "A stateless MCP tool degrades cleanly: MCP is cross-target" and earlier "expose the graph as a stateless retrieval tool/MCP."
D1 was correctly left untouched as spine, and the argument is transport-general (MCP remains the legitimate Phase-5 seam and IS cross-target), so this is not stale MCP-first-as-near-term phrasing.
But post-CLI-first re-aim, a reader could find the MCP-as-exemplar mildly dated. Neutralizing to "a stateless tool (CLI or MCP) degrades cleanly" would fully align D1 with the new near-term surface without touching its logic. Non-blocking and optional.

### NIT N2: the top scoping-revision NOTE is dense

The opening "targeted re-aim / WHY re-aimed" NOTE is a permitted proposals-exception to history-agnostic framing and genuinely orients a reviewer, but it packs four re-aim points plus a restructure into one dense callout with inline arrows.
It is within convention; a light trim would improve scannability. Cosmetic only.

## Verdict

**Accept.**

The four re-aim points are correctly and consistently integrated, the spine is verifiably intact (D1/D3/D5 unchanged, D2 only narrowed), and the first-increment boundary is actionable.
The single should-fix is a clarity qualification, not a blocker, and the two nits are cosmetic.
Status should advance from `review_ready` toward implementation of the first increment.

## Action Items

1. [should-fix, non-blocking] Reconcile the first-increment "recall parity gated" claim with Phase 2's success criteria: either add a reviewer-recall-parity check to Phase 2 success (measured on the Phase-1 corpus), or qualify the intro to say recall parity is structurally guaranteed in the first increment with the measured discriminator landing in Phase 3.
2. [nit] Neutralize D1's "stateless MCP tool degrades cleanly" / "retrieval tool/MCP" exemplar to "stateless tool (CLI or MCP)" so the spine section aligns with the CLI-first near-term surface.
3. [nit] Optionally trim the top scoping-revision NOTE for scannability.

## Clarifications for the maintainer (multiple choice)

On action item 1, how should the first increment treat recall parity?

- (a) Make it MEASURED in Phase 2: add a reviewer-recall-parity >= baseline check on the Phase-1 corpus to Phase 2 success criteria (strongest honesty; a small extra Phase 2 deliverable).
- (b) Keep it STRUCTURAL in the first increment: qualify the intro to "recall parity structurally guaranteed (additive + skip-scope); measured discriminator in Phase 3" (lightest; leaves measurement where the roll-out is).
- (c) Leave as-is: treat the additive+skip-scope guarantee plus the existing Test Plan row as sufficiently clear (accept the minor expectational gap).
