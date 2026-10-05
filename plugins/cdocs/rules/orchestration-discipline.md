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
The 2-3 line floor (dispatch-by-default with the skill's own carve-out, durable state at task-unit boundaries, fresh reviewer and judge) keeps the discipline alive on an un-init'd install.

> NOTE(claude-opus-4-8/overseer-alignment-round2): Do NOT "deduplicate" the inline floor into a bare reference in a later nit-fix pass.
> The duplication is intentional: a correctness floor beats a clean-but-absent reference.

## Graded Enforcement

Enforcement is graded, not hard: a hard tool-allowlist on the top-level session is not available, since it is the user's own session.
Three layers back the discipline:

1. **Written rule plus self-check.** This file, plus the per-dispatch self-check above.
2. **Judge-remit backstop (iterate-only).** The `judge` agent, fresh each invocation, checks for overseer-as-workhorse and context bloat and can `escalate`.
   This backstop is real only because the overseer logs a thinness signal (the inline-work column below) and the judge logs its own `overseer_thinness` diagnosis; absent both logged fields this layer reduces to self-policing.
   `propose-revise` and `full-send` have no judge and fall back to the written self-check plus the optional future hook, with no independent enforcer.
3. **Optional `PreToolUse` advisory hook (Phase 5, not built).** A future advisory that warns on long runs of inline `Edit`/`Write`/`Bash` from the top-level session. Advisory only, since a hook cannot reliably detect overseer mode.
   Spec note (documentation only; hook build deferred to a dedicated hooks proposal): the same advisory MAY also warn, never refuse, on a cross-worktree or `main` write from the top-level session, surfacing it to the overseer and judge. Warn-not-refuse keeps the overseer in control and matches the graded philosophy. A refusing guard on the top-level session is exactly the mid-merge dead-end this discipline removes.

### Isolation is a dispatched-agent property

Worktree/filesystem isolation and the fresh-context freshness invariant bind DISPATCHED agents (the implementer, the reviewer), never the top-level overseer session.
A dispatched agent is isolated so its verdict is trustworthy and it cannot clobber a sibling workstream.
The overseer is deliberately NOT isolated: it must land branches into `main`, resolve worktrees, and fork new worktrees off `main` as normal cross-worktree work.
Overseer clobber-safety is COOPERATIVE (the claim registry plus single-writer ownership; see the "Claim Registry" section of [`oversee-arc.md`](./oversee-arc.md)), not a session-wide lock, consistent with the graded-not-hard enforcement above.

**Isolation-aware routing.** When a loop skill reaches a cross-worktree step (a land, merge, or resolve into the base branch, or a fork of a new worktree off the base), it surfaces that step UNCONDITIONALLY as an up-front precondition and routes it to an un-isolated top-level (overseer) session to perform, warning rather than refusing.
This is not probe-gated. A read-only cross-worktree probe tests the wrong axis, since cross-worktree reads are allowed even under a write-scoped lock, so the skill always surfaces the precondition up front rather than dead-ending mid-merge. A cheap probe may only tailor the wording.
The overseer performs the step by driving the consuming repo's own cross-worktree commands, which are that consumer's commands and not part of this definition (e.g. in the weftwise repo: `/resolve-wt`, `/dogfood-wt`, `/worktree`). The loop skill routes to them; it never reimplements or refuses them.

> NOTE(claude-opus-4-8/worktree-isolation): This principle is load-bearing and MUST NOT be softened back into a session-wide containment claim.
> Do NOT re-add "contain the workstream [in a worktree]" or any equivalent isolation restriction to an overseer/top-level skill (`iterate`, `oversee`, `full-send`, `propose-revise`); isolation binds the dispatched implementer/reviewer only, and the overseer must stay free to land, resolve, and fork.
> This mirrors the intentional-duplication NOTE above: a well-meaning nit-fix must not delete or dilute it.

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

- **Overseer-written (input signal).** The overseer appends an "inline-work performed this turn" flag, the `inline_work` column, so a run of inline-work turns is visible across rows.
  This is the field the judge reads to key `escalate`; without it the judge cannot see bloat and the judge backstop is inert.
- **Judge-written (output signal).** The judge writes its own named additive field, `overseer_thinness: clean | bloat_detected | signal_missing`, at every invocation.
  This is distinct from the judge's continue/rotate/escalate verdict: a judge may log `bloat_detected` while returning `continue` when a run of inline-work turns coexists with clear forward progress, keeping the diagnosis auditable independent of whether it alone triggered escalation.
  `signal_missing` is written whenever the overseer's `inline_work` column is absent, making an unenforced checkpoint visible in the log rather than only inferable from prose.

This `overseer_thinness` field, not prose guidance, is what makes the judge-backstop layer real and gradeable.

> NOTE(claude-sonnet-5/overseer-alignment-round2): The remaining context-cleanliness discipline (handoff format, `CLAUDE.md` reseed verification) ships in Phase 2 and references this rule for the enforcement backbone.

## Pillar 2: Context Persistence and Cleanliness

The overseer keeps its own turns thin across a long loop and keeps its durable state current, so a compaction or a fresh session resumes from written state rather than from a lossy summary.
The thinness column and the judge's `overseer_thinness` verdict (see "Judge-Observable Thinness Signal" above) make bloat legible; this pillar is the discipline that keeps the signal clean.

### Handoff format

At each task-unit boundary the overseer writes a handoff into the devlog.
The checkpoint is not complete until the handoff is written: a compaction's summary is lossy, and the hand-written handoff is what a resuming reader trusts.

The handoff is a markdown section with exactly three subsections:

- **Completed**: what this task unit finished, including the files touched as `files:` gists rolled over from the Scratchpoint (below).
- **Decisions Made**: cross-cutting choices and their rationale, so they are not re-litigated after a compaction or in a fresh session.
- **Open Todos**: what remains, phrased so the next reader can pick it up cold.

A fresh reader must be able to orient from the handoff in under 30 seconds.

### Scratchpoint

A devlog's owner keeps one `## Scratchpoint` section of current state, replaced in place on every state-changing turn; history belongs in handoffs.

```markdown
## Scratchpoint

- as_of: 2026-10-05T12:40:11-07:00
- now: iteration 3 implementer dispatched on the parser fix
- since_handoff: reviewer r2 accepted the schema change; the parser still rejects CRLF input
- open: whether the CLI flag stays in this phase
- next: on the implementer's return, dispatch a fresh reviewer
- files:
  - plugins/cdocs/skills/iterate/template.md (r): Iteration Log column order for the new rows
```

- **Fields:** `as_of` (timestamp), `now`, `since_handoff` (facts not yet in a handoff), `open`, `next` (the single next action), `files`.
- **`files:`** one line per file read in full or edited since the last handoff, shape `- <path> (<r|w|rw>): <what it was useful for>`; files skimmed for a search hit do not belong.
  It gives awareness ("does this gist cover me, or do I need the bytes"), not cheaper re-reads; tasks needing exact content re-read regardless.
  At each handoff the list rolls into the handoff's Completed subsection and restarts empty.
- **Size:** aim for at most ~15 lines and ~8 `files:` entries; move anything older into a handoff.
- **Writers:** the devlog's owner alone, such as the overseer of a loop (`iterate`, `propose-revise`, `full-send`, `oversee`), a top-level `implement` or plain session, or a durable specialist that keeps its own devlog (Pillar 3).
  An agent writing into another agent's devlog keeps none: the `iterate` implementer writes only `## Changes Made` and `### Implementer Notes`, and its return summary is its checkpoint, as it is for one-shot legs.
- **Not a thinness input:** the judge's `overseer_thinness` reads the `inline_work` column alone.

Raw evidence (settings, commands, log lines) goes in the devlog's `## Verification` section, not the Scratchpoint.
After a compaction, re-read your devlog's `## Scratchpoint` and latest handoff before acting.

### CLAUDE.md reseed mechanism

The reseed is what makes compaction safe: it restores the discipline the compact would otherwise drop.
Project-root `CLAUDE.md` and *unscoped* rules (`.claude/rules/*.md` with no `paths:` frontmatter) are re-injected from disk on both auto-compaction and manual `/compact`.
Source: https://code.claude.com/docs/en/context-window.md ("What survives compaction").

CAVEAT: **path-scoped** rules (rules with `paths:` frontmatter) and **nested** `CLAUDE.md` files do NOT reliably reseed.
They reload only when Claude next reads a matching file, so overarching discipline must live in project-root `CLAUDE.md` or unscoped rules for the reseed guarantee to hold.
cdocs' own `frontmatter-spec.md` is path-scoped (`paths: ["cdocs/**/*.md"]`), a concrete in-repo instance of the caveat: it reseeds only when a `cdocs/**/*.md` file is next read, which is why this discipline ships unscoped instead.

This lands for cdocs because `/cdocs:init` materializes rules as an unscoped `.claude/rules/cdocs.md`, and source repos deliver the discipline via root `CLAUDE.md` `@`-imports: both are in the auto-reseeded set.
A consumer who path-scopes or nests the cdocs rules loses the guarantee.
A `SessionStart` hook with a `compact` matcher can additionally re-inject context after a compaction (source: https://code.claude.com/docs/en/hooks-guide.md), but the root-`CLAUDE.md`/unscoped-rules path is the primary guarantee.

> NOTE(claude-opus-4-8/overseer-alignment-phase2): The reseed behavior above is verified against current Claude Code behavior: project-root `CLAUDE.md` and unscoped rules re-inject on compaction, while path-scoped rules and nested `CLAUDE.md` files do not reliably reseed.
> Source: https://code.claude.com/docs/en/context-window.md ("What survives compaction").

## Pillar 3: Durable Specialists

Deep per-workstream context belongs in a named, resumable specialist subagent, not absorbed into the overseer's window.
This is the mechanism that keeps the overseer thin while a workstream still carries its full history: the retained context lives in the specialist, addressable by name, rather than in ever-growing overseer turns.
It extends the graded enforcement and judge backstop of Pillar 1 (see "Graded Enforcement"), it does not restate them: a proliferation of specialists is a bloat pattern the same judge layer flags.

### Resume-by-name

One specialist per active workstream, resumed by name via `SendMessage`, so the specialist IS the retained context: addressable rather than re-explained.
The overseer routes work to a specialist by name and a one-line pointer to its devlog, never by repeating the workstream's accumulated context.
This generalizes the pattern `iterate` already half-encodes: the implementer is kept across iterations unless the judge returns `rotate-implementer`, because an implementer mid-task carries valuable context that a fresh dispatch would discard.
That implementer is already a durable specialist; this pillar names the pattern and extends it beyond the implement loop, so an overseer running several workstreams keeps one warm specialist per stream rather than re-briefing a fresh subagent each turn.

### Fork for side-context

A `fork` subagent is the tool for a side-investigation that needs full parent context WITHOUT growing the parent thread.
The overseer forks a fresh agent that inherits the current context, gets a short answer, and resumes the main thread; the fork's context is disposable and ends when the fork completes.
This is distinct from a named specialist: a `fork` is for a one-off question that would otherwise bloat the overseer, a specialist is for a workstream carried across turns.

### One-per-workstream bound

N parallel large-context specialists recreate the cost problem this discipline exists to prevent.
The bound is explicit: at most one durable specialist per active workstream, not one-per-subtask and not workstream-count plus advisory specialists.
An overseer managing ten workstreams spawns ten specialists maximum; if the workstream count grows past what one overseer can hold, it escalates to a parent overseer or re-scopes the work rather than spawning more.

### File ownership by construction

A durable specialist that owns its OWN files satisfies the "Pillar 1b: Single-Writer File Ownership" guarantee BY CONSTRUCTION: the single writer of those paths is the one named specialist across turns, so no second concurrent writer is ever dispatched against them.
See that section for the guarantee itself; this pillar supplies the constructive case where it holds automatically rather than by per-dispatch check.
The same applies to the Scratchpoint (Pillar 2): a durable specialist keeps one only in a devlog it owns, never in the overseer's.

### Cross-target degradation

Where a target lacks `SendMessage`/`fork` equivalents, this pattern degrades to starting a fresh session from the handoff doc plus the Iteration Log's event rows, the same runtime fallback the "Cross-Target Degradation" section names for Pillar 1b.
The discipline still holds; only the primitive changes, and the durable state (handoff plus event rows) is what makes the fresh-session restart faithful.

> NOTE(claude-opus-4-8/overseer-alignment-phase3): This pillar is additive to Pillars 1, 1b, and 2 and restates none of them.
> It is discoverable from `workflow-patterns.md` and the `implement`/`propose` skills by pointer, keeping the canonical prose here per the project's deduplication value.

## Bash Output Hygiene

Verbose Bash output is a large share of what lands in a lead's context, and it is re-sent on every later turn.
The goal is to keep that output out of the lead's context without losing relevant information: a result the lead cannot act on forces a re-run or a follow-up, which costs more than the context it saved.
Any agent, not only an overseer, can do this itself by capturing output to a file, or can delegate a context-bloating command to the `cdocs:bash-runner` agent; which path fits is a judgment call, not a reflex.
A runner dispatch is the same disposable-context shape as "Fork for side-context" applied to a single command: the runner captures the full output to a file in its own scratchpad, reads what the caller needs out of that file, and returns a fixed-format `BASH RUNNER REPORT` naming the capture file.

### When to dispatch

Start with the cheapest path that keeps what you need:

- **Known need: bound what you read, not what you keep.** When you know exactly what you need (pass/fail, the last few lines), capture to a file and read just that: `cmd > <file> 2>&1; echo "exit=$?"; tail -n 20 <file>`, with `<file>` in your scratchpad or `/tmp`. The exit code survives (`cmd | tail -n 5` reports `tail`'s status, not `cmd`'s), and if the run fails, the details are one `grep -n -C3 <pattern> <file>` away, with no re-run. Pipe straight into `grep -c`/`grep -q` only when the count or match is the whole answer.
- **Trivial or known-small commands** (`git status`, a one-line `ls`) run directly: the subagent round-trip costs more than it saves.
- **Interactive or TTY-dependent commands** are never dispatched: the runner closes stdin.

Dispatch when a command's output is large or unpredictable and what you need from it is a distillation: which tests failed and why, every call site, whether the build warned.
When you need every line itself (a diff you will review line by line), read it yourself in pieces: a relay adds a round trip and nothing else.

Typical dispatch candidates, listed by observed weight in past transcripts (the heaviest results were sweeps), not as a mandatory order:

- **Sweeps**: wide `grep -rn` searches, `find`, `git diff`, multi-file `cat` loops.
- **Builds, tests, installs**: build logs, test suites, `npm install`, linters, `terraform plan`/`apply`, container builds, `git log -p`.
- **Unboundable commands**: output whose size the caller cannot predict (an unfamiliar script or repo).

### Dispatch contract

The Task prompt gives the exact command and, for anything you will act on, a salience spec saying what you need, since a runner misjudging "salient" is the main failure mode.
Say when you need completeness ("every failing test with file:line and expected vs actual", "every call site as file:line"): the runner then lists every item instead of sampling.
For sweeps, a per-file shape ("matches per file, first 3 per file") beats a blind head/tail, which destroys a sweep's signal.
The report carries `Status`, a short `Summary:`, verbatim `Excerpt:` lines, a `Truncated:` field with a ready-to-run `see:` command, and the capture path.
If the report is not enough, do not act on a partial picture and do not re-run the command: run the `see:` command, read a bounded range of the capture (`sed -n`, `grep -n -C`), or dispatch the runner again with a narrower spec over the capture file.

This is a convention for an agent's dispatch decision, not something tooling enforces.
An undispatched verbose command falls back to the platform's built-in Bash output ceiling, an accepted residual risk.

## Cross-Target Degradation

Rule *content* delivers to OpenCode cleanly: `/cdocs:init` globs this file into `.opencode/rules/cdocs/` automatically.
Only the *runtime* mechanics of Pillar 1b degrade: if a target lacks `SendMessage`/`fork` equivalents, single-writer ownership and on-resume reconciliation fall back to starting a fresh session from the handoff doc plus the Iteration Log's event rows.
Likewise, off Claude Code, resumption reads the devlog's Scratchpoint and latest handoff.
The discipline still holds; only the primitive changes.
