---
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-01T00:00:00-07:00
task_list: cdocs/hook-testing
type: proposal
state: live
status: request_for_proposal
tags: [testing, hooks, rules-delivery, materialization, plugin-architecture]
---

# CDocs Rules Hook Testing Methodology v2

> BLUF(claude-sonnet-5/hook-testing): There is still no automated way to verify cdocs's rule-delivery mechanism works after install or after a plugin update, this time for the current hash-based freshness/materialization design rather than the retired content-injection design.
> **Motivated By:** `cdocs/proposals/2026-03-19-rules-hook-testing-methodology.md` (predecessor, archived — its premise, testing `inject-rules.sh`'s content injection, was invalidated when that mechanism was replaced), `cdocs/proposals/2026-05-12-cdocs-rule-delivery-materialization.md` (the redesign this proposal targets).

## Objective

Define a concrete, scriptable testing methodology for the current rule-delivery pipeline:

1. `/cdocs:init` materializes rule content into a consumer project's `.claude/rules/cdocs.md`, including a `<!-- cdocs rules vX.Y.Z hash=<sha256> - regenerate with /cdocs:init ... -->` marker comment.
2. `plugins/cdocs/hooks/inject-rules.ts` runs on every `SessionStart`, computes a sha256 over the plugin's own alphabetically-sorted `rules/*.md` bodies, compares it (opaque string compare) against the marker hash in the project's materialized file, and — on any mismatch, including a missing/malformed marker — emits a short (<500 byte) directive telling the agent to re-run `/cdocs:init` and then `Read` the rewritten file.
3. The hook silently exits (no output) when: `CLAUDE_PLUGIN_ROOT` is unset, the project's `CLAUDE.md` contains `@plugins/cdocs/rules/` (source-repo skip), `.claude/rules/cdocs.md` does not exist (cdocs not initialized here), the plugin manifest or rules directory can't be read, or the hashes match.

No test suite exists for this hook or for `/cdocs:init`'s materialization+marker-writing behavior.

## Scope

The full proposal should explore:

- **Hook unit tests**: invoke `inject-rules.ts` directly with controlled `CWD`/`CLAUDE_PLUGIN_ROOT`/fixture files, covering each branch enumerated in the hook's own doc comment (source-repo skip, marker-file-absent skip, manifest/rules-dir-unreadable skip, marker-absent-or-malformed stale, hash-match silent exit, hash-mismatch directive).
- **Marker generation tests**: verify `/cdocs:init` writes a correct hash marker (matches a sha256 computed independently over the plugin's `rules/*.md`) and that the marker format the hook's regex expects stays in sync with what init actually writes.
- **Round-trip / integration test**: run `/cdocs:init` in a scratch project, mutate a plugin rule file (or bump `plugin.json` version with unchanged content, to exercise the hash-not-version distinction), start a new session, and assert the directive fires or doesn't fire as expected.
- **Directive size/format test**: assert the emitted `additionalContext` stays under the ~500 byte budget the hook's doc comment claims, and under CC's ~2KB `additionalContext` inline cap that motivated this whole redesign (see the materialization proposal's BLUF).
- **CI-appropriateness**: which of the above can run hermetically (no real CC session, no lace dependency) vs. require an interactive session or a real consumer project — the predecessor proposal leaned heavily on a real consumer project (`lace`) and an interactive-session verification step that couldn't be fully automated; assess whether that's still necessary here or whether the smaller hook surface makes full hermetic coverage feasible.
- Whether to also cover the `/cdocs:init` Read-after-write directive (Phase 3 of the materialization proposal) that's meant to keep the *current* session's working context fresh, not just the next session's.

## Open Questions

- Is a real consumer project (like `lace`) still needed for integration-level confidence, or does the hash-comparison design (much smaller surface than the old content-injection hook) make a scratch/fixture project sufficient?
- Should tests live under `scripts/test-hooks.sh` (per the predecessor's convention) or somewhere more TypeScript-native, given `inject-rules.ts` is now TS rather than bash?
- How should tests assert on the exact marker-regex the hook uses (`/<!--\s*cdocs rules v[^\s]+\s+hash=([a-f0-9]+)\s*-\s*regenerate with \/cdocs:init/`) without hardcoding a copy that can drift from the hook source — read the regex from the hook file itself, or accept the duplication with a comment linking the two?
- Does this warrant CI integration (predecessor's Phase 4), and if so, is the full test suite now small/hermetic enough to run entirely in CI rather than splitting into local-only layers?

## Prior Art

- `cdocs/proposals/2026-03-19-rules-hook-testing-methodology.md` — predecessor (archived), same objective for the retired content-injection hook. Its three-layer structure (unit / integration / OC-verification) and lace-based approach may or may not still be the right shape here.
- `cdocs/proposals/2026-05-12-cdocs-rule-delivery-materialization.md` — the accepted, implemented redesign this proposal's target hook comes from. Includes an empirical Test Plan (Groups A/B/C) run during its own implementation; worth checking whether that already covers some of this ground and this RFP should focus on filling gaps or hardening into a durable regression suite.
- `cdocs/devlogs/2026-05-12-rule-delivery-materialization-implementation.md` — implementation devlog referenced by the hook's own doc comment for the hash-vs-version empirical finding.
