---
review_of: cdocs/proposals/2026-09-17-browser-delegation-plugin.md
first_authored:
  by: "@claude-sonnet-5"
  at: 2026-09-17T15:10:00-07:00
task_list: cdocs/browser-delegation
type: review
state: live
status: wip
tags: [fresh_agent, architecture, model_tiering, isolation, browser, unverified_claims]
---

# Review: Browser Delegation Plugin: a sonnet-tier delegate for browser driving, UI verification, and multi-client sync testing

## Summary Assessment

The proposal turns two well-sourced Sonnet reports into a lean, faithful v1 plugin design: a `browser-delegate` sonnet-tier agent that drives `@playwright/cli` via `Bash`, captures artifacts, and hands verdicts off unmodified to the existing `reviewer`/R1-R6 discipline. Every load-bearing v1 default traces to a claim the grounding reports actually verified (subagent MCP-tool non-inheritance, `.lace`'s container-feature-level port scoping, Playwright maintainers closing the one-server-many-sessions request), and every genuinely unconfirmed fact (browser-use GA/availability, `@playwright/cli`'s SIGTRAP exposure, Healer's `claude` integration) is correctly gated behind a Phase 1 spike or Phase 5, never wired into a v1 default. Scope discipline is real: non-goals are argued, not asserted, and the phase graph's "gates only the 'default' label, not the scaffold" framing is internally consistent. Findings below are all non-blocking sharpening; nothing found undermines the design or its faithfulness to the source reports.

**Verdict: Accept.**

## Section-by-Section Findings

### Architecture / "who holds the loop" thesis
The Task/Agent-dispatch diagram and the "reviewer never touches a browser" framing genuinely move the loop off the lead for the bounded-action-list case the proposal designs for (a fixed navigate/act/capture list, or a fixed sync-role dispatch). **Non-blocking gap**: Report A's own Open Questions asked "what is the concrete latency/round-trip budget past which a delegate stops being cheaper than the lead just looking itself" — this question is dropped, not carried into the proposal's Open Questions. It doesn't threaten v1 (every v1 skill invocation is a single bounded dispatch, not an interactive exploration loop), but an iterative/exploratory use case (a lead refining actions across several delegate dispatches based on prior reports) would re-approach the lead-holds-the-loop failure mode one level up, just at dispatch granularity instead of tool-call granularity. Worth naming explicitly rather than leaving implicit in "a fresh delegate dispatch is sufficient and cheaper" (line ~117).

### Toolset default (`@playwright/cli` over `@playwright/mcp`) and D2
Correctly structured: the subagent-inheritance argument is verified independently (weftwise's own `docs/playwright_mcp_usage.md`, cited by both reports) and stands alone regardless of the SIGTRAP spike's outcome. The proposal is explicit that the version-pin argument is "corroborating, not load-bearing" (D2) — this is the single most important discipline in the whole document and it holds up under scrutiny. No blocking issue.

### D5 / isolation design vs. Assumptions Needing Confirmation
The `portless`/`worktree.sh`-mirroring claim is verified directly against this repo's own `.lace/port-assignments.json` and `.lace/mount-assignments.json`: both are keyed by devcontainer *feature* (`lace-fundamentals/sshPort`, `wezterm-server/hostSshPort`), confirming Report B's "container-feature-scoped, not per-worktree" finding and D5's conclusion that no new lace feature is needed for session naming. Good, load-bearing claim, independently checked.

**Non-blocking clarification requested**: the fourth item in "Assumptions Needing Confirmation" ("unique user-data-dir per client root dir... gates the isolation claim underlying D5") carries forward language written about `@playwright/mcp`'s *default, unnamed* profile isolation (Report B's open question was specifically about `@playwright/mcp` colliding across worktrees). But `@playwright/cli`'s isolation primitive is its *named session* mechanism itself (`-s=<name>`, in-memory by default), which Report B describes as a ready-made per-agent identity primitive independent of the user-data-dir question. As written, it's ambiguous whether Phase 1's spike is re-testing the same user-data-dir question for `@playwright/cli`'s internals (legitimate: does its named-session implementation still bottom out in a shared default path that could collide?) or whether this assumption is stale copy-forward that no longer applies once named sessions are the isolation mechanism. Recommend Phase 1 (or `toolset-selection.md`) state explicitly which of these two things is being spiked.

### Multi-client sync coordination and the role→session registry
Workable as specified. The in-devlog table (D5, matching cdocs's devlog-as-durable-state convention) is proportionate to v1's needs, and the "claimed session, serialize or suffix" discipline correctly extends Pillar 1b's single-writer convention rather than inventing new machinery — though note this relies on the lead actually checking the registry table before a second dispatch, the same advisory-not-enforced posture the rest of cdocs already accepts for file ownership. Not a new risk this proposal introduces.

**Non-blocking implementation-detail gap**: the branch-derived session-naming convention (`<branch>-sharer`) doesn't address branch names containing characters unsafe for a CLI session-name argument (e.g., `/` in `feature/foo`), a realistic case `worktree.sh`'s own routing already has to handle for its host-name-derived routes. Worth a one-line sanitization note in `rules/session-isolation.md` when Phase 2 writes it; not a proposal-level blocker.

### Delegate vs. reviewer separation (D1, D6)
Clean. D6's structural argument (the report schema has no verdict-shaped field, rather than relying on prompt discipline alone) is the strongest single design decision in the document and is consistent with `reviewer.md`'s existing no-source-edits precedent. No issue.

### Non-goals and phasing
All five non-goals are argued with a specific rationale tied to the reports (fixer-persona deferral cites the unconfirmed Healer `claude`-integration claim by name; A2A deferral correctly distinguishes cross-org boundary-crossing from same-org session reuse; the `workers: 1` non-goal correctly identifies the serialization as a server-state problem, not a browser problem). Phase 1's "gates only the 'default' language, scaffold may proceed in parallel" framing is coherent and matches the sibling `graphify` proposal's discriminator-first structural pattern (verified by reading that proposal directly). No issue.

### Frontmatter and writing conventions
Frontmatter is spec-compliant: all required fields present and valid (`type: proposal`, `state: live`, `status: review_ready`, ISO-8601 timestamps with TZ, correctly namespaced `task_list`). Two non-blocking writing-convention nits:
- Sentence-per-line is violated in numerous paragraphs (multiple sentences sharing one source line throughout Background, Proposed Solution, and the Design Decisions section) — mechanical, nit-fixable.
- Two em-dashes appear in the agent/skill-surface table (rows for `skills/drive/SKILL.md` and `skills/sync/SKILL.md`); convention prefers colons.
- The `future_work` tag on a `status: review_ready`/`state: live` proposal (only Phase 5 is actually deferred future work; v1 itself is meant to ship) is a minor tagging-precision nit, not a miscategorization worth blocking on.

## Verdict

**Accept.** No blocking issues. The proposal is faithful to both grounding reports, does not let any unconfirmed fact become load-bearing for a v1 default, and phases/scopes leanly while reusing existing cdocs infrastructure (reviewer, R1-R6, Pillar 3, model-tiering) rather than duplicating it.

## Action Items

1. [non-blocking] Add back Report A's dropped open question (delegate-dispatch round-trip budget vs. lead driving directly) to the proposal's Open Questions, scoped to the iterative/exploratory use case v1's bounded-action-list skills don't cover.
2. [non-blocking] Clarify the fourth "Assumptions Needing Confirmation" item: state explicitly whether Phase 1 re-tests `@playwright/mcp`'s user-data-dir default for `@playwright/cli`'s internals, or whether this assumption is superseded once named sessions are the isolation primitive.
3. [non-blocking] Note branch-name sanitization (e.g., `/` in `feature/foo`) as a Phase 2 implementation detail for `rules/session-isolation.md`.
4. [non-blocking] Run a nit-fix pass for sentence-per-line formatting and the two table em-dashes.
5. [non-blocking] Reconsider the `future_work` tag's precision given `state: live`/`status: review_ready`.

## Questions for the Overseer (positions taken, not blocking)

- **cdocs hard dependency?** Standalone-with-integration (the proposal's own assumption) is correct: a marketplace plugin should not force-install a sibling plugin, and the documented inline-fallback verdict path is a real degradation, not a stub.
- **Registry ceremony (devlog table vs. JSON)?** Devlog table is right for v1; revisit only once a second, non-human/non-agent-readable consumer actually needs to query it programmatically.
- **Phase 1/2 parallel or serialized?** Parallel is fine as designed — the SIGTRAP spike outcome only changes documentation (D2), never the scaffold's shape, so there is no rework risk from proceeding in parallel.
- **Plugin name (`browser-delegate` vs. `cdocs-browser`)?** Keep `browser-delegate`. Namespacing it under `cdocs-` would misstate the standalone-with-integration relationship the proposal deliberately chose.
- **Hardcode sync to a pair of roles, or design for N from v1?** Design for N from v1. `/browser-delegate:sync` already dispatches "one `browser-delegate` invocation per logical role" — generalizing the loop to N named roles instead of a hardcoded pair costs little beyond the example in the proposal text, and hardcoding to two now would be arbitrary narrowing that a real 3+-client scenario would immediately need to undo.
