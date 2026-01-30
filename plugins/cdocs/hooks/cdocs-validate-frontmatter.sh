#!/usr/bin/env bash
# CDocs frontmatter validation hook (PostToolUse on Write|Edit)
#
# Checks if a written/edited cdocs file has required frontmatter fields.
# Informational only: warns via additionalContext, never blocks.
#
# Dependencies: bash, jq (for JSON parsing of stdin)
# No external YAML parser - uses regex-based field detection.

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Extract file path from tool_input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Exit silently if no file path (shouldn't happen, but be safe)
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Only validate cdocs markdown files
if [[ ! "$FILE_PATH" =~ cdocs/(devlogs|proposals|reviews|reports)/ ]]; then
  exit 0
fi

# Skip README files
BASENAME=$(basename "$FILE_PATH")
if [ "$BASENAME" = "README.md" ]; then
  exit 0
fi

# Check if file exists
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Read the file and check for frontmatter
CONTENT=$(head -50 "$FILE_PATH")

# Check for frontmatter delimiters
if ! echo "$CONTENT" | grep -q '^---$'; then
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"CDocs: File $FILE_PATH is missing YAML frontmatter. All cdocs documents require frontmatter with: first_authored, type, state, status fields.\"}}"
  exit 0
fi

# Check required fields (regex-based, not full YAML parsing)
MISSING=""

if ! echo "$CONTENT" | grep -q '^first_authored:'; then
  MISSING="${MISSING} first_authored"
fi

if ! echo "$CONTENT" | grep -q '^type:'; then
  MISSING="${MISSING} type"
fi

if ! echo "$CONTENT" | grep -q '^state:'; then
  MISSING="${MISSING} state"
fi

if ! echo "$CONTENT" | grep -q '^status:'; then
  MISSING="${MISSING} status"
fi

# Report missing fields
if [ -n "$MISSING" ]; then
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"CDocs: File $FILE_PATH is missing required frontmatter fields:${MISSING}. See frontmatter spec for requirements.\"}}"
fi

exit 0
