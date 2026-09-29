#!/bin/sh
# SessionStart hook for the converser session only (installed by bin/converser
# through --settings). Records this session's inbox socket path where the
# overseers' Stop hook looks for it. Same run-dir expression as the launcher.
set -eu
[ -n "${CLAUDE_CODE_MESSAGING_SOCKET:-}" ] || exit 0
run="${XDG_RUNTIME_DIR:-/tmp}/converser-$(id -u)"
[ -d "$run" ] && [ ! -L "$run" ] && [ "$(stat -c %u "$run")" = "$(id -u)" ] ||
  { echo "record-sockpath: $run missing or not mine" >&2; exit 1; }
umask 077
printf '%s\n' "$CLAUDE_CODE_MESSAGING_SOCKET" > "$run/converser.sockpath.tmp"
mv -f "$run/converser.sockpath.tmp" "$run/converser.sockpath"
