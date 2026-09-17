---
review_of: cdocs/proposals/2026-09-17-target-setup-validation-and-verification.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-17T16:10:00-08:00
task_list: cdocs/target-verification
type: review
state: live
status: done
tags: [fresh_agent, architecture, test_plan, verification, orchestration, honesty_gate, runtime_validated]
---

# Review: Target setup-validation and test-verification for cdocs loops

## Summary Assessment

The proposal generalizes cdocs' ad-hoc per-proposal verification into one target-declared capability: the target ships a `cdocs/verify.toml` manifest, cdocs owns the runner and a three-outcome taxonomy (PASS / ABSENT / FAIL) where absence is never coerced to a pass and a PASS must cite an output artifact.
It is faithful to the motivating graphify proposal's discriminator-first / "check absent != check passed" discipline (it carries graphify D3 as its own D2 and cites the source correctly), it is structurally complete for an implementation proposal (design decisions, edge cases, test plan, staged verification, four phased implementations with explicit dependencies), and its honesty core is the right load-bearing bet.
Most importantly, I empirically confirmed the load-bearing honesty claim about lace: `lace --help` in this repo is exactly `doctor | resolve-mounts | up | validate`, and the proposal does NOT invent a container-status or reachability command - it honestly leaves the "is the service up" probe as a target-declared `run` and logs ABSENT when none exists.
**Verdict: Accept.** The design is sound and no architectural flaw blocks it; the one genuinely-open decision (TOML vs JSON manifest format) is an implementation-detail the proposal honestly surfaces as an investigation item rather than paper over, and I route it as a resolve-before-Phase-2 action item with a recommendation, alongside a handful of non-blocking clarifications.

## Empirical Verification Performed

Because this is a `review_proof`-bearing capability, I inspected the live system rather than trusting the prose:

- **lace command set (the honesty crux).** Ran `lace --help`: output is `USAGE lace doctor|resolve-mounts|up|validate`, exactly the four commands the Background claims, with `validate` = "validate devcontainer config without starting a container" and `doctor` = "diagnose and reset lace-owned host state." Confirmed: no lace command answers "container up AND in-container service reachable." The proposal's Open Questions and the `container-and-service` target-declared probe are honest, not hand-waving.
- **Target files exist.** `.lace/{devcontainer.json,devcontainer-lock.json,mount-assignments.json,port-assignments.json,runtime-fingerprint}` and `.devcontainer/{devcontainer.json,Dockerfile}` are all present, so the Phase 4 file-presence assertions are grounded in real artifacts.
- **Glob-collision risk (Investigation item 1).** cdocs doc-scanning globs are `cdocs/**/*.md` (status SKILL scans `cdocs/**/*.md` excluding READMEs; triage keys on `cdocs/**/*.md`). `cdocs/verify.toml` is `.toml`, so it never matches a doc-scanning glob. **This concern resolves in the proposal's favor: no collision.**
- **Cited surfaces are accurately characterized.** propose SKILL line 93/95 does frame Verification Methodology as an iterative direct method and suggests `/cdocs:rfp` absent an established convention (the proposal's "this IS that convention" is fair). implement SKILL lines 67-70 is the "equipped to verify vs shoot from the hip" retrospective the proposal names. Both citations check out.
- **BLUF length.** Measured at 534 bytes (raw, including `> ` markers), modestly over the ~500 propose-skill guideline and over the ~510 the author self-reported. Minor.
- **Punctuation/emoji conventions.** No em-dashes in prose and no emojis; the only `--` hits are legitimate CLI flags (`--workspace-folder`, `--reset`) inside command strings. Clean.

## Section-by-Section Findings

### Summary / Objective / Background
Accurate and well-scoped. The NOTE separating this capability from the graphify plugin and the lace-graphify devcontainer edit (line 32-34) is the right boundary and prevents scope creep. The lace CLI Background (line 55-57) is precisely the confirmed command set. **Non-blocking:** the Background is long; the four-command lace paragraph and the surrounding NOTEs restate the same "validate is static, doctor is host-state, neither is a reachability probe" point three times (Background, the D-adapter section, Open Questions). One canonical statement plus pointers would tighten it, consistent with the project's deduplication value.

### The three-outcome taxonomy (honesty core) - D2
This is the strongest part of the proposal and correctly identified as load-bearing. PASS-must-cite-an-artifact mirrors iterate's `confirmed`-needs-a-reviewer-produced-artifact rule (iterate SKILL line 164-168), and ABSENT-as-a-typed-state that no code path coerces to PASS is the right structural (not merely conventional) enforcement. The WARN callout naming the exact failure mode (a token-pressured role reporting "verified" on an unrun check) is apt.
**Non-blocking observation, not a defect:** the taxonomy trusts the target's declared command - a check that runs `exit 0` while doing no real work is a PASS by construction. This is inherent to "cdocs owns the runner, not the commands" and is fine, but the Test Plan's "a PASS with no captured artifact is rejected" is the only structural guard; it cannot catch a hollow-but-exiting-0 command. Worth one sentence acknowledging that the artifact requirement guards against unrun checks, not against vacuous ones (the latter is the target's responsibility).

### Manifest shape and format - D1 (Investigation item 1)
Location `cdocs/verify.toml` is defensible: discoverable beside docs the loops already read, no new search path, and (confirmed above) no glob collision.
**Format (TOML vs JSON) is the one genuinely-unresolved decision, and it is load-bearing for Phase 2 (parsing).** The proposal writes every example in TOML but never justifies TOML over JSON, and itself notes JSON "matches the plugin's TS/build tooling." TOML buys human-authorability (comments, less punctuation noise) at the cost of a parser dependency the TS toolchain does not otherwise need; JSON is native, zero-dep, and `cdocs/verify.json` collides with the doc globs no more than the `.toml` does. The design is format-agnostic - taxonomy, gates, and policies are unchanged either way - so this does not block accepting the DESIGN, but Phase 2 cannot start without deciding it. **Recommendation: default to JSON (native to the plugin's TS/build tooling, no new dependency) unless the human-authorability of TOML with inline `# policy` comments is judged worth the parser dep; either way, decide and record it before Phase 2.** Non-blocking for design acceptance; blocking for Phase 2 start.

### Two gates and where they plug in - D3
The env-precondition vs smoke/test-verification split with decoupled policy is clean, and mapping outcomes onto iterate's existing `review_proof` column (PASS->confirmed, ABSENT->skipped/n-a, FAIL->revise) reuses the right machinery instead of inventing a parallel one.
**Non-blocking clarification:** ABSENT maps to `skipped` OR `n/a` (line 155, 277), but iterate defines `skipped` as fail-loud ("overseer justifies in notes") and `n/a` as "floor does not require empirical evidence" (iterate SKILL line 164-170). Which ABSENT maps to which is left to prose; state the rule (e.g. ABSENT-because-not-applicable -> `n/a`; ABSENT-because-expected-but-missing -> `skipped` with justification) so the mapping is deterministic in the runner.

### Failure semantics (per-check policy) - D3
Four policies decoupled from the logged outcome is the right decomposition, and "policy never changes the logged outcome" keeps the audit trail honest even when the loop proceeds. `reprovision` attempt-once-then-block correctly avoids a provision spin.
**Non-blocking gap:** `skip-with-note` is defined only for the ABSENT/not-applicable case - "it proceeds past ABSENT, never past FAIL" - but a `skip-with-note` check that actually FAILs has undefined behavior (does it then block? warn?). Specify it (most naturally: a `skip-with-note` FAIL degrades to `warn`, since the target declared it non-blocking), or the runner has an unhandled branch.

### Block-vs-warn default (Investigation item 2)
**The default is defensible; I confirm it.** A DECLARED `env`/`test` check is the target's explicit statement "this must hold," so `block` honors that intent, while the floor is GUESSED and correctly defaults to `warn` (the D-floor NOTE is exactly right: auto-detection blocking on an inferred command is a worse failure than a logged WARN). The transient-environment dead-end risk the author flags is real but adequately mitigated: `reprovision` self-heals a merely-down environment, and the overseer surfaces a blocked precondition rather than the loop dying silently.
**Non-blocking, but worth making explicit:** the escape hatch for a `block` env check with NO `reprovision` command that fails transiently. Today the text says such a FAIL "blocks the loop"; it should say the block surfaces to the overseer/human as a precondition escalation (an `AskUserQuestion`-style route, matching iterate's overseer-asks-the-user posture), not a terminal loop death. A one-line addition to Gate 1 or the `block` policy definition closes it.

### Runner ownership and overseer-thinness (Investigation item 3)
**The split is consistent with orchestration-discipline, with one clarification needed.** Routing host-state env work to the un-isolated overseer and smoke/test to the isolated child is exactly "Isolation is a dispatched-agent property": an isolated child mutating shared host state would violate isolation, and the Edge Cases line 229 correctly says host-state ops are "the overseer's cross-worktree concern... not run blindly inside an isolated child." Good.
**Non-blocking tension to resolve in Phase 3:** line 150 says the overseer "dispatches a thin precondition-check subagent," while line 229 says host-state ops must not run inside an isolated child. These are reconcilable but not currently distinguished: env READ-checks (`lace validate`, reading `.lace/*.json`) are isolation-safe and dispatchable to a thin subagent; env MUTATE-actions (`lace up`, `lace doctor --reset` under `reprovision`) are host-state and must route through the overseer's isolation-aware precondition surfacing (the same warn-not-refuse routing iterate uses for a land/merge), never a dispatched child. Phase 3 should split the env gate into read-checks (dispatchable) and mutate-actions (overseer-routed) so the runner-ownership boundary is crisp rather than implied. This does not put mutation in the implementer today (the design is correct); it just needs to say so in the runner's dispatch logic.

### Self-referential verification (Investigation item 4)
**The staged methodology adequately breaks circularity; it is not hand-wavy.** Phase 1 verifies the runner against externally-authored per-outcome fixtures (ground truth independent of the loop), and Phase 3's "drive a real `/cdocs:iterate` with a deliberately-broken change that must produce a FAIL blocking Accept; do not simulate" is a genuine falsification: a vacuously-green cdocs-verifying-cdocs would let the broken change through, and the test asserts it does not. The residual risk - the same effort authors both the runner and its fixtures, so a shared blind spot could infect both - is real but bounded by the end-to-end broken-change test, which does not depend on the fixtures. **Adequate as written.** Optional strengthening: have the deliberately-broken-change test in Phase 3 be authored by/reviewed under fresh context (the fresh-reviewer discipline already in the loop) so the falsifier is not built by the same hand as the runner.

### The lace/devcontainer adapter (Investigation item 5 / Open Questions)
**Confirmed honest and a genuine strength.** Every command the adapter names (`lace validate`, `lace doctor`, `lace up`) is in the confirmed set; the file-presence assertions target files that exist; and the container-up/service-reachable probe is explicitly left as a target-declared `run` with NO invented lace subcommand, logged ABSENT when the target provides none (D2). This is exactly the discipline the whole proposal preaches, applied to itself. The Open Questions correctly flag "confirm against a newer `lace --help` before assuming a status command exists" and prefer a future real status command over the `.lace/runtime-fingerprint` heuristic. Nothing to fix.

### Test Plan / Implementation Phases
Test Plan is thorough and maps one-to-one onto the design (per-outcome fixtures, malformed-vs-absent manifest, gate placement, per-policy semantics, reprovision-attempt-once, floor detection, lace adapter on this repo, cross-target parity). Phases are well-ordered with explicit `Depends`/`Blocks`, and Phase 1 carries an explicit what-not-to-change constraint ("NO manifest parsing and NO loop wiring").
**Non-blocking:** only Phase 1 has an explicit what-not-to-change guard; Phases 2-4 have Depends/Blocks but no equivalent negative constraint. Adding a one-line "does not touch X" to Phases 2-4 (e.g. Phase 3 "does not add new verification vocabulary to the skills; points at the runner") would match Phase 1's rigor and reinforce D5's deduplication intent.

## Verdict

**Accept.**

The design is sound, faithful to the graphify discipline it inherits, internally consistent, and complete for an implementation proposal. The honesty core (three-outcome taxonomy, PASS-cites-artifact, ABSENT-never-PASS) is the right load-bearing bet and is structurally enforced rather than conventional. The lace reachability gap - the sharpest place this could have gone wrong - is handled with exactly the honesty the proposal demands elsewhere, and I verified that empirically. No finding rises to blocking for design acceptance. The action items below are one resolve-before-Phase-2 decision (manifest format) plus clarifications and nits that can be folded in during implementation.

## Action Items

1. [resolve-before-Phase-2] Decide the manifest format (TOML vs JSON) and record the rationale in D1. Recommendation: JSON, native to the plugin's TS/build tooling and zero-dependency, unless TOML's inline-comment authorability is judged worth a parser dep. Design is format-agnostic, so this does not block acceptance, but Phase 2 (parsing) cannot start without it.
2. [non-blocking] Specify `skip-with-note` behavior on a FAIL (currently only defined for ABSENT). Suggest: degrade to `warn`.
3. [non-blocking] Make the ABSENT -> `review_proof` mapping deterministic: ABSENT-not-applicable -> `n/a`, ABSENT-expected-but-missing -> `skipped` (justified).
4. [non-blocking] Add the human/overseer escalation escape hatch for a `block` env check with no `reprovision` that fails transiently: surface as a precondition escalation, not a terminal loop death.
5. [non-blocking] In Phase 3, split the env gate into READ-checks (dispatchable to a thin subagent) and MUTATE-actions (`lace up`/`doctor --reset`, routed through the overseer's isolation-aware precondition surfacing), resolving the line-150-vs-229 tension so the runner-ownership boundary is explicit.
6. [nit] Trim the BLUF to under ~500 chars (currently ~534).
7. [nit] Deduplicate the "validate is static / doctor is host-state / neither is a reachability probe" statement (repeated in Background, the adapter section, and Open Questions) to one canonical statement plus pointers.
8. [nit] Give Phases 2-4 an explicit what-not-to-change constraint, matching Phase 1.

## Clarifications Surfaced for the Author (multiple choice)

These are decisions the reviewer cannot make unilaterally; the author or overseer should pick:

1. **Manifest format** (Action Item 1):
   - (a) JSON - native to TS tooling, zero-dep, my recommendation.
   - (b) TOML - human-authorable with inline `# policy` comments, accept the parser dep.
   - (c) Support both, detect by extension (more surface, more test burden).
2. **`skip-with-note` on FAIL** (Action Item 2):
   - (a) Degrade to `warn` (log FAIL, proceed) - my recommendation, matches the target's non-blocking intent.
   - (b) Escalate to `block` - treats a declared-skippable check that actively fails as a real problem.
3. **A blocked `env` precondition's terminal behavior** (Action Item 4):
   - (a) Surface to the human via an overseer `AskUserQuestion` (route-around allowed) - my recommendation.
   - (b) Hard-block the loop with a logged precondition FAIL and no route-around.
