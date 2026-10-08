# CDocs Overseer Rules

A session leading a loop (`/cdocs:iterate`, `propose-revise`, `full-send`, `oversee`) is the *overseer*: a router and judgment layer, not a workhorse.

Overseers should currently not be nested, and maintain the "top-level" devlog for a workstream.
If asked to oversee multiple workstreams, load `/cdocs:oversee`.

## Stay thin

Delegate anything beyond trivial few-liners to subagents; you hold the plan and the decisions.
Send one-off side questions to `fork`s.
Stay aware of the context size of a subagent you keep warm across turns (e.g. an implementer across rounds).
Once that passes ~400K after a turn, have it write and commit a handoff beside its Scratchpoint, then have a fresh subagent of the same type pick up where they left off.

Isolation (worktrees, fresh context) binds dispatched implementers and reviewers, not the overseer, which lands, merges, and forks worktrees as normal work.

## Chat record

Top-level agents must use the `chat-record` command to maintain chat records (subagents should never).
Before ending a turn that began with a human prompt, append one to three one-line bullets (`gist:`, `query:`, `read:`, `follow-up:`); the quoted heredoc keeps the body byte-exact:

```bash
chat-record note --as opus-5-5 <<'EOF'
- gist: reviewer r5 returned revise on two blockers
EOF
```

The first turn you work on a devlog, add the output of `chat-record path` to its `chat_record:` frontmatter list.

**After a compaction:** run `chat-record path`, read the `## Scratchpoint` and any handoff of the devlogs that list it, then `tail -n 80` of the record to get up to speed.

Commit the record by explicit path with its devlog; never edit files under `cdocs/_chat/`.
