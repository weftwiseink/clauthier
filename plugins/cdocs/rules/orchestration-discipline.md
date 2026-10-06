# CDocs Orchestration Discipline

A session leading a loop (`/cdocs:iterate`, `propose-revise`, `full-send`, `oversee`) is the *overseer*: a router and judgment layer, not a workhorse.

## Stay thin

Delegate anything beyond a trivial few-liner (bulk reads, sweeps, builds, tests, implementation) to subagents; you hold the plan and the decisions.
Trust returned summaries: re-reading a subagent's files to double-check it is the pattern this rule exists to prevent.
Keep a workstream's deep context in a named subagent resumed with `SendMessage`, and send one-off side questions to a `fork`.
Stay aware of a warm subagent's context: its reported tokens (`subagent_tokens` in the task notification) track its current context.
Once that passes ~400K after a turn, have it write a handoff beside its Scratchpoint and commit both, then have a fresh subagent continue that devlog from them.
Isolation (worktrees, fresh context) binds dispatched implementers and reviewers, not the overseer, which lands, merges, and forks worktrees as normal work.

## Resume from disk, not memory

Log each dispatch and return (agent, target files) in your devlog as it happens.
The harness notifies you only when *no* children remain live.
After any interruption, re-derive what is in flight from the devlog's dispatch/return rows and on-disk artifacts: if you believe a child is running but control has returned, it has ended, so read what it left and proceed.

## One writer per file

Never dispatch a writer against a path another live agent is writing; wait or re-scope.
Before running writers in parallel, predict the files each will touch; when unsure whether the sets overlap, serialize.
Every agent commits its own work early and often; agents share worktrees and commit concurrently, so stage by explicit path, never `git add -A` or `commit -a`.

## Verification and stuck loops

Give every implementation loop a concrete verification floor at the depth the change needs (it compiles, unit tests pass, the artifact starts and does its job, components work together, it behaves against live state), with at least one picture of what failure looks like.
When a loop is stuck debugging, isolate the fault (minimal repro, bisect, a focused diagnostic `fork`) instead of paying for more full rebuilds or integration runs.

## Durable state

Compaction summaries are lossy, so at each task-unit boundary write a devlog handoff (Completed / Decisions Made / Open Todos) a cold reader can act on, and look for a seam to continue in a new devlog per the devlog skill.
Between handoffs keep your `## Scratchpoint` (as_of, now, next, open, files touched) current after each substantial turn: one per workstream, in the devlog you are writing.

## Chat record

Claude Code top-level session only: `chat-record` exists nowhere else, so never run it if the `Agent` tool dispatched you.
Before ending a turn that began with a human prompt, append one to three one-line bullets (`gist:`, `query:`, `read:`, `follow-up:`); the quoted heredoc keeps the body byte-exact:

```bash
chat-record note --as opus-4-8 <<'EOF'
- gist: reviewer r5 returned revise on two blockers
EOF
```

Test for a bullet: could a successor reading only the prompts and bullets tell where things stand?
The first turn you work on a devlog, add the output of `chat-record path` to its `chat_record:` frontmatter list.
**After a compaction:** run `chat-record path`, read the `## Scratchpoint` and latest handoff of the devlogs that list it, then `tail -n 80` of the record, before trusting the summary.
Commit the record by explicit path with its devlog; never edit files under `cdocs/_chat/`.

## Bash: Avoid context bloat from careless bash commands

When dispatching commands, either:
1. **You know what you need**: Use the pattern `cmd > <file> 2>&1; echo "exit=$? wc=$(wc <file>)"; tail -n 20 <file>`.
   Then have a `cdocs:bash-runner` (or other sonnet) subagent extract important info if more context is needed.
   Similar patterns can also be used for interactive or tty-dependent commands, which are not dispatched (they hang without a terminal).
2. **The command is well known with low-output**, i.e. `git status` or `ls`: run directly.
3. **Output may be large, command is non-trivial, flexibility is wanted, saliency is loosely defined**: Use `cdocs:bash-runner` agents.

Typical `bash-runner` candidates:
- wide `grep -rn` searches, `find`, `git diff`, multi-file `cat` loops.
- build log reads, test suites, `npm install`, linters, `terraform` and other devtool commands, container builds, `git log -p`.
- commands with output whose size the caller cannot predict (an unfamiliar script or repo).

They will include the output file path in the event the report summary is not enough.
