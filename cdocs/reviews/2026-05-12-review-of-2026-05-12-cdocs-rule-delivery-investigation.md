---
review_of: cdocs/proposals/2026-05-12-cdocs-rule-delivery-investigation.md
first_authored:
  by: "@claude-opus-4-7"
  at: 2026-05-12T16:45:00-07:00
type: review
state: live
status: done
task_list: clauthier/cdocs-rule-delivery
tags: [rereview_agent, test_plan, sessionstart, rule_delivery, shell_escaping, heredoc, accepted]
---

# Review: CDocs Rule Delivery Investigation (Round 3)

## Summary Assessment

Round 2 returned `revise` with one blocking item (four bugs in the Test Plan wrapper command) and two non-blocking nits.
Round 3 adopts the recommended Option B refactor: the wrapper logic is hoisted into a standalone `wrap.sh` written by its own heredoc, and `settings.json` invokes it with a trivial `bash $CLAUDE_CONFIG_DIR/wrap.sh` command.
Tracing the heredocs character-by-character confirms all four bugs are resolved: the JSON contains no nested quoting; `$out` is quoted; the jq filter uses bare `$m` as a jq variable inside a single-quoted filter (not bash's `\($m)` interpolation - it uses jq's `+` string-concatenation, which is equivalent and arguably clearer); and the bundle-size check sets `CLAUDE_PLUGIN_ROOT` inline.
Verdict: **Accept** (round 3).

## Round-2 Action-Item Disposition

| # | Round 2 finding | Round 3 status | Evidence |
|---|---|---|---|
| 1 [blocking] | Four escaping/quoting bugs in the wrapper command | **Resolved** | Recipe refactored to standalone `wrap.sh` (lines 210-217); see "Heredoc walkthrough" below for line-by-line verification. Bundle-size check (lines 263-266) now sets `CLAUDE_PLUGIN_ROOT` inline. |
| 2 [non-blocking] | In-repo skip case still cites host-specific `/workspace/clauthier/main` path | **Not addressed** | Line 254 unchanged. Acceptable as a residual non-blocking nit since the user-facing flag was "no new content to re-review" in this round, and this would not block a subagent implementer (they can adapt the path to their own checkout location). |
| 3 [non-blocking] | Edge Cases redundancy with Pre-flight Checks | **Not addressed** | Lines 165-170 unchanged. Author inline acknowledgement at line 166 stands. Acceptable. |

## Heredoc walkthrough (verification of round-2 bug fixes)

The `wrap.sh` heredoc (lines 210-216) uses unquoted `EOF`, so bash performs parameter expansion plus the four backslash escapes `\$`, `\\`, `` \` ``, `\<newline>`. All other `\X` sequences pass through with backslash preserved.

### Line 213: `export CLAUDE_PLUGIN_ROOT="$CDOCS_REPO/plugins/cdocs"`

`$CDOCS_REPO` expands at write time. Written to file as:
```
export CLAUDE_PLUGIN_ROOT="/workspace/clauthier/main/plugins/cdocs"
```
Correct.

### Line 214: `out=\$(npx tsx "$CDOCS_REPO/plugins/cdocs/hooks/inject-rules.ts" 2>/dev/null)`

- `\$` is the only escape; it consumes the `$` and yields a literal `$`.
- The remaining `(npx tsx ...)` is plain text (no leading `$`, so no command substitution at write time).
- `$CDOCS_REPO` (mid-line) expands at write time.

Written to file as:
```
out=$(npx tsx "/workspace/clauthier/main/plugins/cdocs/hooks/inject-rules.ts" 2>/dev/null)
```
This is a deferred command substitution that runs when `wrap.sh` is executed. Correct.

### Line 215: `echo "\$out" | jq --arg m "$MARKER" '.hookSpecificOutput.additionalContext += "\n[" + \$m + "]"'`

Per-token trace:

| Source | Heredoc output |
|---|---|
| `echo "` | `echo "` |
| `\$out` | `$out` |
| `" \| jq --arg m "` | `" \| jq --arg m "` |
| `$MARKER` | `CDOCS_MARKER_<hex>` (expanded) |
| `" '.hookSpecificOutput.additionalContext += "` | `" '.hookSpecificOutput.additionalContext += "` |
| `\n` | `\n` (literal backslash + `n`; not in heredoc escape set) |
| `[" + ` | `[" + ` |
| `\$m` | `$m` |
| ` + "]"'` | ` + "]"'` |

Written to file as:
```
echo "$out" | jq --arg m "CDOCS_MARKER_<hex>" '.hookSpecificOutput.additionalContext += "\n[" + $m + "]"'
```

Verification per round-2 bug:

1. **JSON malformation from `\\\"`**: N/A. There is no JSON-in-bash quoting any more; `wrap.sh` is plain shell. settings.json's `command` field is just `bash $CLAUDE_CONFIG_DIR/wrap.sh` with no internal quoting.
2. **`echo $out` word-splits**: Fixed. `echo "$out"` is properly quoted - bash will pass the captured JSON to `jq` as a single argument.
3. **jq variable interpolation**: Fixed. The single-quoted filter passes `$m` to jq verbatim; jq treats `$m` as a variable reference (bound by `--arg m`) and concatenates with `+`. The filter evaluates to `"\n[<MARKER>]"`. This differs from the round-2 suggested `\($m)` interpolation but is equivalent and slightly more readable.
4. **`CLAUDE_PLUGIN_ROOT` unset in bundle-size**: Fixed. Lines 263-266 set `CLAUDE_PLUGIN_ROOT="$CDOCS_REPO/plugins/cdocs"` inline before `npx tsx`.

### Lines 220-232: `settings.json` heredoc

```
"command": "bash $CLAUDE_CONFIG_DIR/wrap.sh"
```

`$CLAUDE_CONFIG_DIR` expands at write time to the `mktemp -d` path. The resulting JSON is unambiguous: a single shell command string with no nested quoting. CC parses it cleanly, then runs `bash /tmp/tmp.XXXXXX/wrap.sh` at SessionStart. Correct.

### Bundle-size check (lines 263-266)

```bash
CLAUDE_PLUGIN_ROOT="$CDOCS_REPO/plugins/cdocs" \
  npx tsx "$CDOCS_REPO/plugins/cdocs/hooks/inject-rules.ts" 2>/dev/null \
  | jq -r '.hookSpecificOutput.additionalContext | length'
```

`CLAUDE_PLUGIN_ROOT=...` is a per-command env assignment to `npx tsx`. `inject-rules.ts` reads `process.env.CLAUDE_PLUGIN_ROOT` and the non-null assertion succeeds. `2>/dev/null` discards tsx warnings. `jq -r` extracts the byte length. All correct.

## Non-blocking observations (round 3 only)

- **Comment-to-spec drift (line 208-209).** The block comment "Variables marked with \$ stay literal in the written script; unescaped ones expand at heredoc-write time" is technically correct but uses `\$` in prose without code-fence escaping. In rendered markdown the leading backslash is preserved by most parsers; this is fine. Mentioned only for completeness.
- **`set -euo pipefail` inside `wrap.sh` (line 212).** Good defensive default. If `npx tsx` exits non-zero (e.g. when `CLAUDE_PLUGIN_ROOT` were ever unset), `wrap.sh` exits early and CC discards the partial payload. The hook still fails cleanly rather than emitting half-broken JSON.
- **`2>/dev/null` on line 214.** Discards tsx cold-start warnings as documented in Pre-flight Checks. Worth noting that this also discards genuine errors from the script. For a test wrapper this is acceptable since failure manifests as "no marker echoed". For a production wrapper one would want stderr surfaced. Not in scope for this proposal.

## Verdict

**Accept (round 3).**

The Test Plan recipe is now executable as written. All four round-2 bugs are fixed via the standalone-`wrap.sh` refactor. The one residual non-blocking nit (host-specific path on line 254) can be addressed at implementation time by the subagent running the test or in a future doc-polish pass.

The proposal is ready to transition to `implementation_ready`.

## Action Items

None blocking. Optional:

1. **[non-blocking]** At implementation time, reword line 254 to refer to the source repo by its identifying condition (any `cwd` whose `CLAUDE.md` contains `@plugins/cdocs/rules/`) rather than the host-specific `/workspace/clauthier/main` path. Or simply leave it; the implementer can adapt.
2. **[non-blocking]** Consider whether `wrap.sh` should surface stderr on failure (currently discarded by `2>/dev/null` on line 214). For the one-off regression test this is fine; if the wrapper ever becomes recurring, revisit.
