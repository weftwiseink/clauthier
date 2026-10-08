---
name: chat-record
description: Chat record upkeep for the top-level session only
---

# CDocs Chat Record

Top-level session only.
If the Agent tool started you, or you are a fork, stop: your dispatcher owns the record.

Maintain the session's chat record with the `chat-record` command.
Before ending a turn that began with a human prompt, note the most important things you are about to tell the user, in at most 300 words of bullets, each at most 100 words.
The quoted heredoc keeps the body byte-exact:

```bash
chat-record note --as opus-5-5 <<'EOF'
- Reviewer r5 returned revise on two blockers; the retry cap is yours to decide.
EOF
```

The first turn you work on a devlog, add the output of `chat-record path` to its `chat_record:` frontmatter list.

**After a compaction:** run `chat-record path`, read the `## Scratchpoint` and any handoff of the devlogs that list it, then `tail -n 80` of the record to get up to speed.

Commit the record by explicit path with its devlog; never edit files under `cdocs/_chat/`.
