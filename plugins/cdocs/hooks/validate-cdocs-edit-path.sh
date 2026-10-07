#!/usr/bin/env bash
# PreToolUse hook: restricts Edit/Write to cdocs document paths.
# Exit 0 = allow, exit 2 = block (stderr sent to agent as error).
#
# Scoped to cdocs subagents only via agent_type guard.
# The main session (no agent_type) is never restricted.
#
# IMPORTANT: When adding new cdocs agents to plugins/cdocs/agents/,
# also add their bare name to the CDOCS_AGENTS allowlist below.
set -euo pipefail
INPUT=$(cat)

# --- agent_type guard ---
# Only restrict known cdocs subagents. Main session has no agent_type field.
# For a plugin-registered agent, Claude Code reports agent_type as the
# plugin-scoped name (e.g. "cdocs:triage"), not the bare agent name
# (confirmed empirically: a dispatched cdocs:triage subagent's PreToolUse
# payload carries agent_type="cdocs:triage"). Match both forms so the guard
# works whether the agent was dispatched as a cdocs plugin agent or under a
# bare name (e.g. a non-plugin or locally-registered agent of the same name).
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty')
CDOCS_AGENTS="triage nit-fix reviewer"

if [ -z "$AGENT_TYPE" ]; then
  # Main session: allow all operations
  exit 0
fi

# Check if agent_type is a known cdocs subagent, bare or "cdocs:"-prefixed.
BARE_AGENT_TYPE="${AGENT_TYPE#cdocs:}"
IS_CDOCS_AGENT=false
for agent in $CDOCS_AGENTS; do
  if [ "$BARE_AGENT_TYPE" = "$agent" ]; then
    IS_CDOCS_AGENT=true
    break
  fi
done

if [ "$IS_CDOCS_AGENT" = false ]; then
  # Not a cdocs subagent: allow all operations
  exit 0
fi

# --- path restriction (cdocs subagents only) ---
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

if [[ ! "$FILE_PATH" =~ cdocs/(devlogs|proposals|reviews|reports)/ ]]; then
  echo "Blocked: this agent can only edit files in cdocs document directories." >&2
  exit 2
fi

exit 0
