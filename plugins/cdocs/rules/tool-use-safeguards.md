# CDocs Tool Use Guidance

## Tools and Skills
- `/cdocs:bash-runner` for any supported command whose output is not guaranteed to be trivially small.
- `/cdocs:report` for external research or sweeping investigations.
- Top-level session only (not started by the Agent tool, and not a fork): invoke `/cdocs:chat-record` with the Skill tool, and again after a compaction when its text is not in context.
- `/cdocs:graphify` when graphify is installed: agents that read code run the workstream's `graphify_base_query` at startup and `explain` code entities, preferring it when practical over `grep` and full-file reads.
  Overseers write `graphify_base_query`, pass it in prompts to agents that read code, and never run graph queries themselves.

## One writer per file

Never dispatch a writer against a path another live agent is writing; wait or re-scope.
Before running writers in parallel, predict the files each will touch; when unsure whether the sets overlap, serialize.

Every agent should commit its own work early and often, and should do so by exact paths to avoid potential collisions with other actors.

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
