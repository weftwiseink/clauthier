---
review_of: cdocs/devlogs/2026-09-23-graphify-cdocs-integration-full-send.md
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-09-23T10:20:00-08:00
task_list: code-graph/cdocs-integration
type: review
state: live
status: done
tags: [fresh_agent, runtime_validated, architecture, missing_validation, graphify, scoping, recall_parity, test_plan]
---

# Review: Graphify scoping surface (Phase 2 implementation), round 1

> BLUF(claude-opus-4-8/code-graph/cdocs-integration): ACCEPT. The shipped increment is exactly the lean Phase 2 the proposal and Turn-0 brief scope: a thin, CLI-backed, additive-only scoping helper plus flag-gated reviewer wiring, no more.
> I reproduced the test suite (39 passed, 0 failed) and independently probed the fail-safe branches, D4 compliance, and JSON shape-tolerance.
> Every verification-floor branch is real in the code, not merely asserted by a test.
> The one material residual, the ASSUMED graphify CLI shape, is genuinely isolated to a single function AND fails in the safe direction (a shape miss degrades to skip-scope, never to a wrong-and-confident dependent set), so it is correctly deferred to the overseer's live real-graphify ablate spot-check.
> Accepting-round nits only, enumerated below; none block.

## Summary Assessment

The work integrates a pre-indexed code-graph engine (graphify) into the cdocs iterate loop as a stateless, flag-gated scoping surface for the reviewer role.
It comprises `graphify-scope.sh` (a `brief` subcommand that turns a round's changed files into a scoped-context brief), a 39-assertion host test harness driven by a PATH stub, a `--graphify-scope` flag (default OFF) in the iterate skill, and brief-handling instructions in the reviewer agent.
Quality is high: the code is legible, the disciplines the proposal calls non-negotiable (additive-only, skip-scope on every doubt, AID-not-guarantee, the D3 structural CRDT guard) are enforced mechanically rather than by convention, and scope discipline is exemplary (nothing from Phase 1, Phase 3, implementer/judge roll-out, librarian, or adapter leaked in).
The single most important finding is that the primary residual risk (the assumed CLI JSON shape) is both well-isolated and fail-safe, which is what makes a host-testable `confirmed` verdict admissible now while the live shape reconciliation defers cleanly to the overseer.

## Verification performed (empirical)

Reproduced, not trusted:

- **Test suite.** `bash plugins/cdocs/scripts/test-graphify-scope.sh` -> `RESULTS: 39 passed, 0 failed`. All nine test groups green: flag-off (with sentinel proof of zero graphify calls), scoped-brief shape, and the missing-binary / missing-index / stale-index / engine-error / CRDT-near-empty / empty-set fallback branches, plus the healthy co-surfaced-observe case.
- **D4 (no raw `graph.json` ingestion).** The `$index` variable is referenced only by `[ -f "$index" ]` (existence) and `stat -c %Y "$index"` (mtime). The index file's contents are never `cat`/`jq`/`read`. Graph data enters solely through `graphify explain <target> --json` inside `graphify_dependents()`. Confirmed by inspection and grep.
- **Non-blocking exit.** A fallback invocation (`brief --files x.ts`, flag off) prints the labeled `disabled` marker and exits `0`. Skip-scope never blocks a round.
- **JSON shape-tolerance.** I fed a throwaway stub an entirely different, deeply-nested shape (`result.root.path`, `result.edges[].target.file`, `result.edges[].deep.deeper.path`) unlike the test fixture. The helper still resolved all three files (`SCOPE-DEP-COUNT: 3`, `a/one.ts` / `b/two.ts` / `c/three.ts`). The recursive-descent `[.. | (.file? // .path? // empty)]` extraction is genuinely robust to shape drift, as claimed.

## Section-by-Section Findings

### `graphify-scope.sh`: skip-scope / additive-only discipline (floor items 1-2)

Every floor branch is real in the code, at these lines:

- flag off -> `skip "disabled"` at line 127, before any binary or index probing (zero graphify calls, exactly today's behavior);
- no changed files -> `skip "skip-scope" no-changed-files` (146);
- missing binary -> `skip ... no-binary` (149);
- missing index -> `skip ... missing-index` (150);
- stale index -> `skip ... stale-index` (157);
- engine error -> `skip ... engine-error` (172);
- CRDT near-empty trigger -> `skip ... crdt-near-empty-trigger` (197);
- empty set -> `skip ... empty-set` (201).

`skip()` (57-65) emits the `SCOPE-STATUS:` / `SCOPE-REASON:` / `SCOPE-FALLBACK:` labels plus an explicit "this is ADDITIVE fallback, not a narrowing" instruction and `exit 0`. It emits nothing that could narrow context. **Non-blocking.** This is the discipline done right: the mechanism, not a caveat, is what prevents a token-pressured role from receiving a bare set.

### `graphify-scope.sh`: the D3 structural CRDT guard (floor item 2)

Correct and load-bearing. `observe_sites()` (99-106) scans the touched files for `.observe(`/`.subscribe(`. The scoped brief always co-surfaces this channel (218-224), including a "0 sites found (still not a guarantee of no coupling)" line when none are present, so the CRDT channel can never be silently omitted.
The near-empty trigger (196-198) fires when `dep_count <= near_empty` (default 1) AND `site_count > 0`, forcing skip-scope rather than handing back a small confident set. Verified by test 7 and by inspection. **Non-blocking.** The brief never presents the set as exhaustive: the `Resolved dependent set (... NOT exhaustive)` header (215) and the standing AID caveat (226-230) are both structural.

### `graphify-scope.sh`: D4 CLI-first, thin translation isolation (floor item 3)

`graphify_dependents()` (75-93) is genuinely the only graphify-shape-coupled surface: the `explain` subcommand, the `--json` flag, and the JSON parse all live there; `cmd_brief` downstream operates only on plain file-path strings (dedup, input-exclusion, rendering), which are engine-agnostic.
A future swap onto the adapter or MCP transport is therefore a real one-function change, not a rewrite, as D4 requires. **Non-blocking, verified.**

### ASSUMED CLI shape: the main residual (correctly deferred)

graphify is not on the host, so the parser targets an assumed `graphify explain <target> --json` shape. My assessment of the three sub-questions in the floor:

- **Shape tolerance is reasonable AND fail-safe.** Pulling `.file`/`.path` at any depth tolerates nesting and key-position drift (probe C confirms). More importantly, the failure directions are safe: a *total* key miss (real engine uses `.filename`/`.location`) yields an empty set -> `empty-set` or `crdt-near-empty-trigger` skip-scope -> unscoped sweep (no recall loss); a *partial/over-broad* match (a stray `.path` that is not a source file) can only ADD spurious entries, which wastes a little of the reviewer's attention but cannot drop a true dependent. Over-inclusion is the correct failure direction for a scoping aid, and recall parity is preserved either way.
- **Isolation is a genuine one-function fix.** Confirmed above (D4 finding). If the real shape differs, only `graphify_dependents()` changes.
- **Near-empty threshold (=1), staleness rule, target form: sound with caveats.** The `=1` default is a reasonable "0 or 1 dependent counts as near-empty," and it is configurable. The staleness rule (any changed-file mtime > index mtime => stale) is the right direction and fails safe (a `stat` failure yields `0`, which drives toward skip-scope). The default target = changed-file *basenames* passed to `explain` mirrors the probe usage (`graphify explain "inject-rules.ts"`) and is overridable via `--symbols`; whether `explain` keys on a filename vs a symbol/node id is exactly what the live run must confirm.

**Non-blocking, but this is the validation-of-record.** What MUST be reconciled in the overseer's live real-graphify run: (a) that `explain <basename> --json` is the right query and returns dependents (vs requiring a symbol or a different subcommand); (b) that the real JSON carries source paths under a `.file`/`.path`-reachable key (else adjust the one function); (c) that `.path` in real `explain` output denotes source files and not graph-route artifacts (over-inclusion sanity check). What is solid now: the brief shape, all fallback branches, additive-only + flag-gating, and the fail-safe degradation on any shape mismatch.

### Flag wiring: iterate skill + reviewer agent (floor item 4)

Correct end to end. The `--graphify-scope` flag is documented as DEFAULT OFF (SKILL.md 39-40, 58). The "Graphify scoping" section (42-58) runs the helper at Turn N.b only when the flag is on, pastes the brief verbatim into the reviewer dispatch on `SCOPE-STATUS: scoped`, and on `skip-scope`/`disabled` primes nothing and records the labeled status in the Iteration Log. The first-line dispatch on `SCOPE-STATUS: scoped` matches the helper's actual first output line.
`reviewer.md` (43-51) instructs the reviewer to treat the brief as an AID, to attend the observe/subscribe channel, to not narrow on a small/empty set, and to use the CLI query subcommands (never raw `graph.json`) for follow-ups; line 51 makes brief-absence recall-neutral. Flag-off behavior is unchanged (test 1 + line 127 short-circuit). **Non-blocking, verified.**

### Scope discipline (floor item 6)

Exemplary. `git show --stat` across the three commits touches exactly four files: the helper, its test, the iterate skill, and the reviewer agent. No Phase 1 coarse meter, no Phase 3 measured gate, no implementer/judge wiring, no librarian, no adapter. This honors the maintainer's "it should just be prime-context + instruct-agents" intent. **Non-blocking, verified.**

## Accepting-round nits (non-blocking)

1. **Basename-collision over-exclusion (mild recall edge).** Input exclusion (181-184) drops a resolved dependent if its *basename* matches any changed file's basename, even in a different directory (two `index.ts`, two `mod.rs`). In a monorepo this could drop a genuine cross-directory dependent from the brief. Mitigated by the AID caveat and the "do not narrow" instruction, so recall parity is not structurally broken, but since recall parity is THE hard principle, prefer excluding on full-path equality only, or on basename only when the dependent path is not resolvable to a distinct file. Reconcile alongside the live shape check (the real path forms determine the right comparison).
2. **`stat -c %Y` is GNU-specific.** On a BSD/macOS host `stat -c` fails and yields `0` for both index and files, so staleness never triggers there (the loop could scope against a stale index). The target is the Linux devcontainer where graphify itself runs, so this is a portability note, not a live risk; a `stat -f %m` fallback would harden it.
3. **`explain` target-vs-symbol assumption is documented only in a code comment.** The basename-as-target choice and its provenance (probe usage) live in an inline comment (80-81); a one-line note in the iterate skill's "Graphify scoping" section pointing at `--symbols` for engines that key on symbols would help the operator of the live run.

## Verdict

**Accept.**

The increment meets its verification floor on all host-testable behavior: brief shape, every fallback branch, additive-only recall protection, the D3 structural CRDT guard, D4 CLI-only compliance, and flag-gated reviewer wiring with unchanged flag-off behavior, all reproduced empirically (39/39 tests plus independent probes). The sole material residual (assumed CLI shape) is well-isolated, fail-safe, and correctly scoped to the overseer's live real-graphify validation. Scope discipline is exact. The nits are polish, not correctness gaps.

**Deferred validation-of-record (not the dispatched reviewer's to run):** the LIVE real-graphify `/cdocs:ablate` spot-check on real multi-file tasks, run at top level by the overseer in a graphify-equipped devcontainer. A dispatched agent cannot run ablate (it dispatches subagents), so this is `deferred-to-followup` by construction, per the Turn-0 brief. That run is where nits 1-3 and the three shape-reconciliation items above should be checked against real `explain` output.

## Action Items

1. [non-blocking] Reconcile the assumed `explain <basename> --json` query and JSON key shape against real graphify output in the overseer's live ablate run; if the shape differs, fix only `graphify_dependents()`.
2. [non-blocking] Tighten input exclusion (181-184) to avoid dropping a distinct cross-directory dependent that shares a basename with a changed file; decide the right comparison once real path forms are known.
3. [non-blocking] Add a `stat -f %m` fallback so staleness detection is not silently disabled on non-GNU hosts.
4. [non-blocking] Add a one-line pointer to `--symbols` in the iterate skill's "Graphify scoping" section for engines that key `explain` on a symbol rather than a filename.

## Questions for the maintainer (multiple choice)

The following are judgment calls the review surfaces rather than blocks on:

1. **Basename over-exclusion (nit 1):** how should input exclusion behave?
   - (a) Full-path equality only (never exclude on basename): safest for recall, may leave the changed file itself in the set if graphify echoes it under a different path form.
   - (b) Keep basename exclusion (current): cleaner brief, accepts the rare cross-directory collision drop.
   - (c) Defer the decision to the live run and pick once real `explain` path forms are known (my recommendation).
2. **Near-empty threshold default (=1):** is `0 or 1 dependent` the right "near-empty" band for the CRDT trigger, or should it be `0` only (trigger solely on a truly empty set), or a higher band (e.g. `<=2`) on this CRDT-heavy codebase?
   - (a) Keep `1`. (b) `0` only. (c) `<=2`. (d) Decide from the live ablate corpus.
