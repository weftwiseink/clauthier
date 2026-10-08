# Ablation scorecard: cli:(^|[ /])(cdocs-)?graphify (query|explain|path|affected|update) 

> **Outcome: VALID**
>
> WARN: SINGLE-SHOT, INDICATIVE ONLY: deltas are ONE draw, not an estimate; a sign flip on a small delta is within noise. NOT admissible as a downstream gate verdict (D3).
>
> gate_admissible: `false` (a downstream gate MUST refuse a non-admissible scorecard).

## Metered deltas

| axis | assisted | unassisted | delta | weight |
|---|---|---|---|---|
| tokens | 64362 | 65870 | -1508 | corroborating |
| wallclock (ms) | 61317 | 32276 | 29041 | INDICATIVE only |

## Context gap (PRIMARY causal axis): `1` in [-10,+10]

## Qualitative assessment

Both arms identified currentDocumentRefAtom and recovered essentially the same grep-derived core (about 27 code importers, the layout facade source, the store.sub mirror, derived tab/selection/metadata atoms, and the same test and e2e set), so the core blast radius was driven by grep in both arms, not graphify. A's graphify base query (truncated to 51 of 942 nodes, 3 of them _archive/) contributed only marginal tail entries: lib/tabs/list_ops.ts, lib/tabs/types.ts/TabDescriptor, and the atoms.ts:350 runtime-coupling line appear in A's transcript only via the graphify output; tab_strip.tsx, active_pane.ts, and tabs/index.ts A got from its own activeTabAtom grep. Graphify also surfaced use_editor_view_pool.ts, document_editor_pane.tsx, and use_palette_results.ts, which A did not use; A instead asserted palette is unaffected, missing the real currentMountIdAtom -> wireLastVisitedMountMirror -> resolvedTargetMountAtom -> palette/create_document.ts chain (B listed that file, though with a wrong reason). A is the more precise answer (0 grep-refuted entries vs 8 for B), while B has slightly broader coverage of pane-slice readers, the DocumentRef type file, and the README. Token cost was near-identical (64.4K vs 65.9K), so graphify neither materially helped nor cost context: a small positive effect.

_The assisted arm is identifiable by its tool calls; the blind is PARTIAL (D5)._
