# CDocs Orchestration Discipline

The canonical definition of *overseer mode*: the thin-lead behavioral discipline a top-level session adopts when running a `/cdocs:iterate`, `/cdocs:propose-revise`, or `/cdocs:full-send` loop.
"Overseer" names a discipline a session wears, not an artifact type: it is not an `agents/` entry, because the overseer is almost always the top-level session, which a subagent's frontmatter cannot constrain, and a dispatched subagent cannot dispatch its own workers.
This rule is the single source of truth; the loop skills reference it and keep only a short inline floor plus their own carve-outs.

## Pillar 1: The Overseer Role

The overseer is a router and judgment layer, not a workhorse.

### Core responsibilities

The overseer plans, dispatches, interprets returned summaries, makes cross-cutting decisions, and maintains durable state.
Concretely, the overseer does NOT:

- run `npm test` or other test suites itself,
- read full file contents when a returned summary would serve,
- commit code itself,
- run build or dev commands itself.

These are dispatched to subagents.
The overseer holds the plan and the decisions, not the raw work product.

### Dispatch-by-default

Any bulk file read (>1KB or >20 lines), exploratory search sweep, build or test run whose full output is not needed verbatim, or implementation slice goes to a subagent.
A concrete heuristic: if a command's output is more than 10 lines, or if interpreting the output requires domain judgment beyond "did it pass or fail," dispatch it.

The canonical carve-out is "trivial few-liners": single-line edits and one-off checks the overseer may do inline.
A skill may set a STRICTER bar than this default (for example `propose-revise`'s "even trivial ones," which dispatches everything), but never a looser one.
This is the default that `iterate` adopts verbatim; `propose-revise`'s stricter bar is the documented exception.

### Summary absorption

The summary a subagent returns is the contract boundary.
The overseer records what the summary states and does NOT re-read the subagent's files to double-check.
Concretely: if a subagent reports "I read 10 files and found X," the overseer records X; it does not re-read those 10 files.
Re-reading a subagent's source to verify a returned summary is the workhorse anti-pattern this rule exists to prevent.

### Signaling self-check

At each dispatch decision, the overseer asks: "Could a subagent do this better, more cheaply, or more independently?"
If the honest answer is yes, it dispatches.

## Inline Discipline Floor (delivery robustness)

Each of `iterate`, `propose-revise`, and `full-send` MUST keep a 2-3 line inline summary of this discipline in addition to referencing this file.
This is deliberate, small duplication, and it is a correctness floor, not a redundancy to remove.

The reason is a delivery gap: on a marketplace install that has not run `/cdocs:init`, the `SessionStart` hook injects no rule content, only a directive to re-run `/cdocs:init`.
A skill that reduced to a bare reference would then point at content the session never loaded.
The 2-3 line floor (dispatch-by-default with the skill's own carve-out, durable state before compact, fresh reviewer and judge) keeps the discipline alive on an un-init'd install.

> NOTE(claude-opus-4-8/overseer-alignment-round2): Do NOT "deduplicate" the inline floor into a bare reference in a later nit-fix pass.
> The duplication is intentional: a correctness floor beats a clean-but-absent reference.

## Graded Enforcement

Enforcement is graded, not hard: a hard tool-allowlist on the top-level session is not available, since it is the user's own session.
Three layers back the discipline:

1. **Written rule plus self-check.** This file, plus the per-dispatch self-check above.
2. **Judge-remit backstop (iterate-only).** The `judge` agent, fresh each invocation, checks for overseer-as-workhorse and context bloat and can `escalate`.
   This backstop is real only because the overseer logs a thinness signal (the context-estimate and inline-work columns below) and the judge logs its own `overseer_thinness` diagnosis; absent both logged fields this layer reduces to self-policing.
   `propose-revise` and `full-send` have no judge and fall back to the written self-check plus the optional future hook, with no independent enforcer.
3. **Optional `PreToolUse` advisory hook (Phase 5, not built).** A future advisory that warns on long runs of inline `Edit`/`Write`/`Bash` from the top-level session. Advisory only, since a hook cannot reliably detect overseer mode.

## Pillar 1b: On-Resume Liveness Reconciliation

The harness notifies the overseer only when NO live children remain.
A session resumed mid-interruption can therefore hold a stale "child in flight" belief that no longer reflects reality.

Before acting on any resumed loop, the overseer MUST re-derive dispatch and return state from the Iteration Log's dispatch/return event rows, NOT from in-window recollection.
If it believes a child is in flight but no live children exist, that child has terminated: the overseer inspects the child's on-disk artifacts and proceeds from the actual state, rather than waiting on a child that is already gone.
Durable memory alone does not close this gap: a written handoff records what was *decided*, not what is *currently running*.

> NOTE(claude-sonnet-5/overseer-alignment-round2): A full-send orchestrator session hit exactly this and deadlocked, re-reporting "child in flight" on resume although the harness had already returned control because no live children remained.

## Pillar 1b: Single-Writer File Ownership

At most one agent writes a given file or document at a time.

Before dispatching an agent that will `Write` or `Edit` a path, the overseer checks whether another live agent already owns that path (a claim recorded in the Iteration Log or devlog).
If so, it serializes (waits) or re-scopes the dispatch to a different file, rather than dispatching a second concurrent writer.
A named durable specialist that owns a file across turns satisfies this by construction; the convention matters at the moment a *second* agent is dispatched against a path already claimed.

> NOTE(claude-sonnet-5/overseer-alignment-round2): A session dispatched two agents that concurrently wrote the same proposal file, clobbering each other's edits and requiring manual reconciliation.

## Judge-Observable Thinness Signal

Thinness is enforceable only when it is logged.
Two additive fields make it legible in the Iteration Log:

- **Overseer-written (input signal).** The overseer appends an approximate current-context estimate and an "inline-work performed this turn" flag as additive columns.
  Estimate format example: "~150K tokens (30% of turn was inline file reads)," so a trend is visible across rows.
  This is the field the judge reads to key `escalate`; without it the judge cannot see bloat and the judge backstop is inert.
- **Judge-written (output signal).** The judge writes its own named additive field, `overseer_thinness: clean | bloat_detected | signal_missing`, at every invocation.
  This is distinct from the judge's continue/rotate/escalate verdict: a judge may log `bloat_detected` while returning `continue` when a rising-context trend coexists with clear forward progress, keeping the diagnosis auditable independent of whether it alone triggered escalation.
  `signal_missing` is written whenever the overseer's context-estimate/inline-work columns are absent, making an unenforced checkpoint visible in the log rather than only inferable from prose.

This `overseer_thinness` field, not prose guidance, is what makes the judge-backstop layer real and gradeable.

> NOTE(claude-sonnet-5/overseer-alignment-round2): The remaining context-cleanliness discipline (handoff format, proactive compaction cadence, `CLAUDE.md` reseed verification) ships in Phase 2 and references this rule for the enforcement backbone.

## Cross-Target Degradation

Rule *content* delivers to OpenCode cleanly: `/cdocs:init` globs this file into `.opencode/rules/cdocs/` automatically.
Only the *runtime* mechanics of Pillar 1b degrade: if a target lacks `SendMessage`/`fork`/`compact` equivalents, single-writer ownership and on-resume reconciliation fall back to starting a fresh session from the handoff doc plus the Iteration Log's event rows.
The discipline still holds; only the primitive changes.
