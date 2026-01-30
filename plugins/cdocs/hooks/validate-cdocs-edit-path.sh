#!/usr/bin/env bash
# PreToolUse hook: restricts Edit/Write to cdocs document paths.
# Exit 0 = allow, exit 2 = block (stderr sent to agent as error).
set -euo pipefail
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

if [[ ! "$FILE_PATH" =~ cdocs/(devlogs|proposals|reviews|reports)/ ]]; then
  echo "Blocked: this agent can only edit files in cdocs document directories." >&2
  exit 2
fi

exit 0
