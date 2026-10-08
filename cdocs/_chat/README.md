# Chat Records

One file per Claude Code session (`YYYY-MM-DD-<session_id>.md`), appended by the cdocs hooks and the top-level agent: each human prompt verbatim, the agent's note of each turn, and a sign-off per turn; do not edit them by hand. Records are committed with the devlogs that list them; to opt out, set `CDOCS_CHAT_RECORD=off` for a session, gitignore `cdocs/_chat/` (records then stay local to one checkout), or delete this directory to stop recording.
