#!/usr/bin/env bash
# detect-usage.sh - does a Claude Code transcript contain a tool_use of the given tool?
#
# Repo-internal helper for verification steps that must show an agent did (or did not) call a
# tool. A plain grep over the transcript also matches the signature inside dispatch prompts,
# tool results, and quoted reports; this script reads only assistant `tool_use` blocks.
#
# Usage: bash scripts/detect-usage.sh --transcript <jsonl> --tool <sig>
#   Prints "used" or "unused" and exits 0 either way; bad arguments exit non-zero.
#   An errored call still counts as used (presence, not result).
#
# <sig> is EITHER:
#   - an MCP tool name, e.g. "mcp__example__scope" (or a bare trailing name "scope"), matched
#     against tool_use `.name` == <sig> or endswith("__" + <sig>);
#   - "cli:<regex>", e.g. "cli:^sometool ", matched against a Bash tool_use's `.input.command`.
#     The command is split at shell separators (&&, ||, ;, |) and the regex is tested per segment
#     and against the whole string, so a caret anchor matches the real command through a
#     `cd <dir> && ...` prefix while unanchored forms and true negatives are unaffected.
#
# Tests: scripts/detect-usage.test.sh
set -euo pipefail

die() { echo "detect-usage: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "missing dependency: jq"

t="" tool=""
while [ $# -gt 0 ]; do
  case "$1" in
    --transcript) [ $# -ge 2 ] || die "--transcript needs a value"; t="$2"; shift 2 ;;
    --tool)       [ $# -ge 2 ] || die "--tool needs a value"; tool="$2"; shift 2 ;;
    *) die "unexpected argument: $1 (usage: detect-usage.sh --transcript <jsonl> --tool <sig>)" ;;
  esac
done
[ -n "$t" ] || die "--transcript required"
[ -n "$tool" ] || die "--tool required"
[ -f "$t" ] || die "transcript not found: $t"
[ -r "$t" ] || die "transcript not readable: $t"

if [ "${tool#cli:}" != "$tool" ]; then
  sig="${tool#cli:}"
  [ -n "$sig" ] || die "empty cli: signature"
  n="$(jq -r --arg sig "$sig" '
        select(.type=="assistant")
        | .message.content[]? | select(.type=="tool_use") | select(.name=="Bash")
        | (.input.command // "") as $cmd
        | ( [$cmd] + [ $cmd | splits("[ \\t]*(&&|;|\\|)[ \\t]*") ] ) as $segs
        | select( any($segs[]; test($sig)) )
      ' "$t" | wc -l | tr -d ' ')"
else
  n="$(jq -r --arg tool "$tool" '
        select(.type=="assistant")
        | .message.content[]? | select(.type=="tool_use") | .name
        | select(. == $tool or endswith("__" + $tool))
      ' "$t" | wc -l | tr -d ' ')"
fi
if [ "${n:-0}" -gt 0 ]; then echo "used"; else echo "unused"; fi
