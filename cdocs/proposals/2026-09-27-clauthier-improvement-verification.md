---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-27T10:00:00-08:00
task_list: clauthier/improvement-verification
type: proposal
state: live
status: request_for_proposal
tags: [verification, efficacy, downstream, graphify, token_efficiency, meta]
---

# Clauthier improvement verification

> BLUF(claude-opus-4-8/clauthier/improvement-verification): A standing, umbrella framework for downstream tasks and repos to ADOPT and VALIDATE the efficacy of clauthier/cdocs improvements — so a shipped improvement (graphify scoping first) is proven to pay in a real consuming project, not just accepted in the abstract.
> Motivated By:
> - [`cdocs/proposals/2026-09-17-graphify-cdocs-integration.md`](./2026-09-17-graphify-cdocs-integration.md) (graphify scoping, `implementation_accepted`; functional live-verify done, efficacy A/B deferred)
> - [`cdocs/proposals/2026-09-17-mcp-tool-effectiveness-ablation.md`](./2026-09-17-mcp-tool-effectiveness-ablation.md) (`/cdocs:ablate`, the built efficacy harness)
> - [`cdocs/devlogs/2026-09-23-graphify-cdocs-integration-full-send.md`](../devlogs/2026-09-23-graphify-cdocs-integration-full-send.md) (full-send record; the "efficacy not yet measured" gap this RFP closes)

> NOTE(claude-opus-5-5/cdocs/delete-ablate): `/cdocs:ablate` is deleted per [`2026-10-08-delete-ablate-rfp.md`](./2026-10-08-delete-ablate-rfp.md), so an elaborator picks a different measurement instrument than the `/cdocs:ablate` default named below.

## Objective

cdocs improvements get built and accepted inside clauthier, but their PAYOFF is realized in DOWNSTREAM consuming repos and tasks (weftwise, lace, and others). Today there is no standing way for a downstream consumer to (a) adopt a shipped improvement cleanly and (b) generate honest, comparable evidence that it actually helps on their real work.

This RFP asks for a lightweight, reusable verification framework: a per-improvement "how to adopt + how to prove it pays here" contract that any downstream task or repo can follow, with results that roll back up to inform whether an improvement graduates, stays opt-in, or is dropped. It is deliberately an UMBRELLA — the graphify-scoping section below is the first entry; other improvements get their own sections as we formalize them.

## Scope

The full proposal should explore, at the umbrella level:

- **A common verification contract.** What does each improvement's "verification section" need? Candidate shape: (1) adoption steps for a downstream repo; (2) the efficacy question stated as a falsifiable claim + its failure-picture; (3) the measurement instrument (default: `/cdocs:ablate`); (4) task-shape targeting (which task shapes are expected to win vs expected-null); (5) a pass/hold/drop rule; (6) where results are recorded so they roll up.
- **Who runs verification, and where.** Downstream consumers run it in their own environment (the improvement's real habitat), since efficacy is context-dependent — the graphify single-file `context_gap 0` vs multi-file result is the cautionary example. How do results flow back to clauthier without coupling clauthier to any one consumer?
- **Standing vs one-shot.** Is verification a one-time graduation gate, or a standing regression check re-run when the improvement or the consuming codebase changes materially?
- **Structural constraints that shape the framework.** `/cdocs:ablate` dispatches subagents, so a full efficacy run needs a TOP-LEVEL session in the consuming environment (a dispatched agent cannot drive it) — the framework must name this so downstream runners plan for it.
- **Graduation semantics.** What does a passing verification entitle an improvement to (default-on, tier-downgrade permission, removal of a flag)? What does a failing one trigger?

### Section: graphify scoping efficacy (downstream adoption + validation) — SEED

The first concrete improvement to verify. Shipped as `implementation_accepted` (Phase 2, lean track): the CLI-backed scoping surface (`plugins/cdocs/bin/graphify-scope` + flag-gated reviewer wiring), functionally live-verified against real graphify 0.9.61, but its **efficacy A/B was explicitly deferred** — this section is where a downstream repo closes that gap.

- **Adoption (downstream repo).** Install the graphify devcontainer feature (`ghcr.io/weftwiseink/devcontainer-features/graphify`); provision an index (`graphify update <tree> --no-cluster`, LLM-free); turn on `--graphify-scope` (default OFF) in the iterate/review loop. Confirm the helper's graph-path resolution finds the index in the consumer's environment (default cache is `/var/cache/graphify/graph.json`).
- **Efficacy claim (falsifiable).** On MULTI-FILE dependent-set / blast-radius tasks, priming a graphify scoping brief cuts the reviewer's (then implementer/judge's) context-gathering burn while holding recall. Failure-picture: no positive context-gap on multi-file tasks, OR any recall regression versus the unscoped baseline.
- **Instrument.** `/cdocs:ablate` with `--tool cli:^graphify`, run TOP-LEVEL in a graphify-equipped container, on a couple of real multi-file tasks. Corroborate the signed context-gap verdict with the token delta.
- **Task-shape targeting.** Multi-file/blast-radius shapes are the intended win; single-file/trivial changes are EXPECTED-NULL (grounded: ablate e2e Probe A single-file → `context_gap 0`) and are inadmissible as evidence that scoping does not pay.
- **What "passing" would entitle.** Evidence of positive multi-file context-gap with held recall would justify (a) flipping `--graphify-scope` on by default for that consumer, and (b) the model-tiering downgrade the core proposal hypothesizes — each still gated on the consumer's own model-policy floor.
- **Known limitations to hold under test.** `explain` truncates its connection list (~20; the helper emits a `SCOPE-TRUNCATED` warning); the graph is blind to CRDT `.observe`/`.subscribe` coupling (D3 structural guard); recall is protected structurally (additive + skip-scope + flag) but MEASURED only in the core proposal's deferrable Phase 3.

<!-- Additional improvement sections go here. Suggested shape per section:
### Section: <improvement name> (downstream adoption + validation)
- Adoption (downstream repo): ...
- Efficacy claim (falsifiable) + failure-picture: ...
- Instrument: ...
- Task-shape targeting: ...
- What "passing" entitles: ...
- Known limitations to hold under test: ...
-->

## Open Questions

- **Results roll-up mechanism.** Where do downstream verification results live so clauthier sees them without depending on any one consumer repo? (A cdocs report per consumer? A shared registry? A back-reference from the improvement's proposal?)
- **Graduation authority.** Who decides an improvement graduates from opt-in to default-on — the consuming repo's maintainer, clauthier's, or a passing-evidence threshold?
- **Comparability across consumers.** Different repos have different codebases and task mixes; how comparable must their evidence be, and does the umbrella need a common minimal task-shape set?
- **Standing regression cadence.** If verification is standing, what triggers a re-run (improvement version bump, consuming-codebase drift, engine pin change)?
- **Which improvements come next.** Beyond graphify scoping, which shipped/in-flight clauthier improvements warrant their own verification section (the coarse per-role meter, model-tiering downgrades, others TBD)?
