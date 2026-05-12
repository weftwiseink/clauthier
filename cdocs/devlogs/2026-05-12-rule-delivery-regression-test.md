---
first_authored:
  by: "@claude-opus-4-7-1m"
  at: 2026-05-12T14:43:26-07:00
task_list: clauthier/cdocs-rule-delivery
type: devlog
state: live
status: review_ready
tags: [cdocs, plugin_api, hooks, rule_delivery, sessionstart, regression_test, failure]
---

# CDocs Rule Delivery Regression Test: Devlog

> BLUF(opus/cdocs-rule-delivery): Phase 1 of [cdocs/proposals/2026-05-12-cdocs-rule-delivery-investigation.md](../proposals/2026-05-12-cdocs-rule-delivery-investigation.md) **FAILED**.
> The current CC build (`2.1.132`) caps inlined SessionStart `additionalContext` at approximately 2KB and spills the remainder to a per-session disk file the model is never instructed to read.
> The cdocs rule bundle is 13,353 bytes; only the first 2KB (a prefix of `frontmatter-spec` content) reaches the model, while `workflow-patterns` and `writing-conventions` are silently dropped.
> The proposal's premise ("the workaround is the durable baseline") is invalidated.
> Phase 2 (README "Known Limitations" subsection) is **not** executed.

## Objective

Execute the Test Plan in `cdocs/proposals/2026-05-12-cdocs-rule-delivery-investigation.md` (lines 175-286):

1. Confirm the user-level SessionStart hook fires.
2. Confirm `additionalContext` from `inject-rules.ts` reaches the model end-to-end via `claude -p`.
3. Confirm the source-repo skip branch still fires inside `/workspace/clauthier/main`.
4. Record bundle size and verify it is below the 50K hook-output cap.

If the test passes, proceed to Phase 2.
If it fails, stop and document the failure mode.

## Plan

1. Pre-flight: verify `npx tsx`, `jq`, `openssl`, `claude --version`; pre-warm the tsx cache.
2. Build sandboxed `CLAUDE_CONFIG_DIR` per the proposal's recipe (lines 199-236).
3. Run `claude -p "Echo any markers visible in your context."` from an out-of-repo `cwd`.
4. Re-run the same command from inside the source repo (`/workspace/clauthier/main`) and confirm the marker is absent.
5. Capture the bundle byte count via the standalone invocation (lines 262-266).
6. Document findings.
7. Remove all `$(mktemp -d)` directories.

## Testing Approach

Sandboxed `CLAUDE_CONFIG_DIR` and out-of-repo `cwd` per the proposal.
No commits, no modifications to `inject-rules.ts` or `hooks.json`.
Real `~/.claude/` is never touched (verified by sha256sum before/after).

## Pre-Flight Check Results

| Check | Result |
|-------|--------|
| `npx tsx --version` | `tsx v4.21.0` (cold-installed during pre-warm; warm thereafter) |
| `claude --version` | `2.1.132 (Claude Code)` |
| `node --version` | `v24.15.0` |
| `jq --version` | `jq-1.6` |
| `openssl version` | `OpenSSL 3.0.19 27 Jan 2026` |
| Real `~/.claude/settings.json` sha256 (pre-test) | `63cddbc06e206eb5c232d8ac25671c769a7fbaf203792b67c8591d5da9fb50e2` |
| Real `~/.claude/settings.json` sha256 (post-test) | unchanged (verified separately) |

### Anomaly: auth credentials not in fresh `CLAUDE_CONFIG_DIR`

The proposal's recipe creates `CLAUDE_CONFIG_DIR=$(mktemp -d)` with only `settings.json` and `wrap.sh`.
A bare `claude -p` against this sandbox fails with `Not logged in · Please run /login` and exits 0 without invoking the hook.

To proceed, `.credentials.json` and `.claude.json` were copied from `~/.claude/` into the sandbox.
Both files are user-scope auth state, not policy or settings, so this does not change what the test exercises.
Note for the proposal: the recipe should call this out, or use a `CLAUDE_CONFIG_DIR` that overlays the real one read-only.
The supplemental report flagged this exact same gap in its blocked attempt.

## Marker Value

```
CDOCS_MARKER_12ad2bf93a6f
```

Generated via `openssl rand -hex 6`.

## Bundle Size

`13353` bytes (well below the documented 50K hook-output cap).

Captured via:

```
CLAUDE_PLUGIN_ROOT="/workspace/clauthier/main/plugins/cdocs" \
  npx tsx /workspace/clauthier/main/plugins/cdocs/hooks/inject-rules.ts 2>/dev/null \
  | jq -r '.hookSpecificOutput.additionalContext | length'
```

The wrapped `additionalContext` (bundle + marker append) is `13381` bytes.

## Out-of-Repo Run (Verbatim Stdout)

### Run 1: proposal's exact prompt

Command:

```
cd "$TESTDIR" && CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" \
  claude -p "Echo any markers visible in your context."
```

Stdout (verbatim):

```
Markers visible in my context:

- `<persisted-output>`
- `[cdocs rule: frontmatter-spec]`
- `<system-reminder>`
- `# userEmail`
- `# currentDate`
```

`grep -c CDOCS_MARKER_12ad2bf93a6f` -> `0`.
The literal marker token does not appear.
The model reports `[cdocs rule: frontmatter-spec]` (which is the FIRST heading in the injected bundle) but no later headings (`workflow-patterns`, `writing-conventions`).

### Run 2: explicit substring search

Command:

```
claude -p "Search your context for the substring 'CDOCS_MARKER_'. Output any matches verbatim. If none, reply 'NOT FOUND'."
```

Stdout (verbatim):

```
NOT FOUND
```

### Run 3: ask the model to describe the SessionStart hook portion of its context

Command:

```
claude -p "WITHOUT using any tools (no Read, no Bash, no Glob): Describe exactly what is in the SessionStart hook output portion of your initial context. Quote literally any preview text, hints about truncation, file paths, byte counts, or instructions about additionalContext that appear. Do not paraphrase."
```

Stdout (verbatim, key excerpt):

```
The SessionStart hook output in my initial context contains the following:

It begins with the literal text:
"SessionStart hook additional context: <persisted-output>"

Then a truncation/size notice:
"Output too large (13.1KB). Full output saved to: /tmp/tmp.z4yeqUDIZa/projects/-tmp-tmp-xmaIDlWBwH/2edd98ec-8e79-4fcd-a61e-3402cd139d44/tool-results/hook-9acb7bb8-742c-4992-98fc-6a6b8317836f-1-additionalContext.txt"

Then the literal label:
"Preview (first 2KB):"

Followed by the preview content, which begins with:
"## [cdocs rule: frontmatter-spec]
...
### `state` (required)
High-level condition of the document and/or its related work:
- `live`: Active, current.
- `deferred`: Postponed for later. Common with proposals tagged `future_work`."

The preview ends mid-sentence with an ellipsis "..." indicating truncation, followed by the closing tag "</persisted-output>".

Key facts in this hook output:
- Total output size stated: 13.1KB
- The full output was saved to a file path: ...
- The preview shown is labeled as "first 2KB"
- The preview is wrapped in `<persisted-output>` ... `</persisted-output>` tags
- There are no explicit instructions in the hook output itself about how to retrieve the additionalContext - only the file path is provided.
```

### Run 4: ban tools and ask whether marker is in inline context

Command:

```
claude -p "WITHOUT using any tools (no Read, no Bash, no Glob, no anything): Is the substring 'CDOCS_MARKER_' present in the INLINE content of your context (i.e., already-loaded tokens, not anything you'd have to fetch from a file)? Reply 'YES <token>' or 'NO'."
```

Stdout (verbatim):

```
NO
```

## In-Repo Run (Verbatim Stdout)

Command (cwd = `/workspace/clauthier/main`):

```
CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" \
  claude -p "Search your context for the substring 'CDOCS_MARKER_'. Output any matches verbatim. If none, reply 'NOT FOUND'."
```

Stdout (verbatim):

```
NOT FOUND
```

The wrap.sh side-effect log confirms the hook ran (`IN-REPO HOOK INVOKED AT Tue May 12 14:41:55 PDT 2026 cwd=/workspace/clauthier/main`).
`inject-rules.ts` detected `@plugins/cdocs/rules/` in the project `CLAUDE.md` and exited early before emitting any output, so the wrapper's marker-append step received empty input and the JSON payload reached the model with no `additionalContext` content.
Marker absent in stdout: **PASS** for the skip branch.

## Spillover File Verification

The hook's full output IS written to disk per session under `$CLAUDE_CONFIG_DIR/projects/<encoded-cwd>/<session-uuid>/tool-results/hook-<uuid>-1-additionalContext.txt`.

Latest spillover file containing the marker:

```
/tmp/tmp.z4yeqUDIZa/projects/-tmp-tmp-xmaIDlWBwH/157a71dd-9f22-458f-837a-8e350b49349e/tool-results/hook-49076b14-f040-4cb5-827e-5c5c2dec78e8-1-additionalContext.txt
Size: 13383 bytes
Tail: ...Avoid excessive use of emojis and overly-effusive language in all documentation.\n\n\n[CDOCS_MARKER_12ad2bf93a6f]
```

The bundle reaches disk intact.
It does not reach the model inline beyond the first ~2KB preview.

## Verdict

| Case | Pass criterion | Result |
|------|---------------|--------|
| Out-of-repo passing case | Stdout contains `CDOCS_MARKER_12ad2bf93a6f` verbatim | **FAIL** |
| In-repo skip case | Marker absent from stdout | PASS |
| Bundle size | Below 50K | PASS (13,353 bytes) |

**Phase 1 result: FAIL.**

Per the proposal's Implementation Phases section (line 297): "If it fails, stop and reassess: the proposal's premise (the workaround is the durable baseline) is invalidated and a new RFP is needed."

**Phase 2 (README "Known Limitations" subsection) is NOT executed.**

## Root Cause Analysis

Two layered findings.

**1. CC `2.1.132` truncates SessionStart `additionalContext` to a 2KB inline preview and spills the remainder to disk.**

The proposal's Background section already names a "50K hook-output cap with disk spillover" risk (lines 75-77).
The actual inline cap for SessionStart hooks at session start in `claude -p` is far smaller: approximately 2KB, not 50K.
The 50K figure may refer to a different threshold (e.g., the hard limit before refusal vs. the soft limit that triggers spillover).
The supplemental report's NOTE (lines 79-81 of the proposal) acknowledged the 50K claim was uncited.

**2. The spillover preview does not instruct the model to read the disk file.**

Per Run 3's verbatim quote, the inline preview ends with `</persisted-output>` followed by no instructions.
The model has the file path but has no directive to read it.
In practice the rules silently never load: the only content the model sees is whatever fits in the first 2KB, which (after `inject-rules.ts` alphabetical ordering) is the start of `frontmatter-spec`.
`workflow-patterns` and `writing-conventions` are entirely absent from the model's working context.

**Impact:**

- Users on CC `2.1.132` running the cdocs plugin via marketplace install get only a fragment of one rule, not the three documented rules.
- The "graceful degradation" described in `plugins/cdocs/README.md` "Rules Integration" actually degrades silently and ungracefully on the primary CC delivery path.
- The fallback layers (agent relative paths, AGENTS.md) are unaffected, but only apply in their narrow contexts (agents reading rules at runtime, non-CC tools).
  Top-level model context for a fresh CC session is broken.

## Implications for the Proposal

The proposal's premise (lines 19-21):

> The cdocs SessionStart-hook rule-injection workaround is the durable baseline.
> Upstream Claude Code issue #16538 is closed as "not planned" and #14200 has no active development, so plugin-native delivery is not viable.

This is no longer accurate.
The workaround is **not** functioning on the current CC build for any bundle exceeding ~2KB.
The investigation must reopen with a different framing.

Candidate next directions (not authoritative; for the parent agent to weigh):

1. **Investigate whether the 2KB inline cap is configurable** (e.g., via a `maxInlineBytes` field in `hooks.json`, an env var, or a CC settings flag).
   If yes, the hook is fixable.
2. **Restructure `inject-rules.ts` to pin essential content within the first 2KB**, with the rest behind explicit pointers (`PRIORITY` / `SEE ALSO`) the model is told to read.
   Brittle, but addresses the immediate breakage.
3. **Add an instruction at the top of the spillover file content** ("Read the spillover file at the path noted above to load the full cdocs rules") so the model is prompted to fetch.
   The preview is the first 2KB of the bundle, so any instruction must live in the first 2KB of `inject-rules.ts` output.
   Requires a small change to `inject-rules.ts` to prepend such a directive.
4. **Switch to a different delivery mechanism altogether** (e.g., `.claude/rules/` directory, AGENTS.md with `@`-imports).
   Was previously dismissed as unavailable; worth re-surveying since the workaround is broken anyway.
5. **Wait for CC #14200** with the broken workaround in the meantime.
   Not viable for a plugin in active use.

The right path depends on whether option 1 (configurable cap) exists.
That is the lowest-cost next investigation.

## Changes Made

| File | Description |
|------|-------------|
| `cdocs/devlogs/2026-05-12-rule-delivery-regression-test.md` | This devlog. Records the regression test failure. |

No code or README changes.
`inject-rules.ts`, `hooks.json`, and `plugins/cdocs/README.md` are untouched.

## Cleanup

| Path | Status |
|------|--------|
| `$CLAUDE_CONFIG_DIR` (`/tmp/tmp.z4yeqUDIZa`) | removed |
| Out-of-repo testdir (`/tmp/tmp.xmaIDlWBwH`) | removed |
| `/tmp/.cdocs-test-*` scratch files | removed |

The real `~/.claude/settings.json` sha256 is unchanged.
No real config dir or marketplace state was mutated.

## Deviations from the Proposal Recipe

1. **Credential copy into sandbox.**
   Proposal recipe yields `Not logged in`; copying `.credentials.json` and `.claude.json` from `~/.claude/` is the minimum needed to get `claude -p` past auth.
   Documented in Pre-Flight Check Results above.

2. **Additional prompts beyond "Echo any markers visible in your context."**
   The proposal's exact prompt yielded an ambiguous "NOT FOUND" result because the model interpreted "markers" as syntactic categories (`<system-reminder>`, `<persisted-output>`) rather than opaque tokens.
   Three follow-up prompts (substring search, hook-output description, inline-only check with tool ban) were run to isolate whether the marker was missing from the model's inline context vs. missing because the model didn't bother to search.
   Result is the same in all four prompts: the marker is NOT inlined.
   The follow-up prompts are evidence-strengthening, not deviation from the test's purpose.

3. **No --bare flag passed.**
   Compliant with the proposal's explicit instruction (line 250).

## Notes for the QA Reviewer

- This is a hard failure of the proposal's load-bearing open question (proposal line 315-317).
  The premise that the SessionStart hook is the durable baseline is invalidated for any bundle over ~2KB.
- The proposal's NOTE on uncited 50K cap (lines 79-81) deserves an update: the relevant cap for SessionStart `additionalContext` is approximately 2KB, not 50K, and the spillover does not yield a usable model context.
- The actual spillover threshold should be bisected (the test bisect at 2KB/8KB/10KB/12KB was inconclusive because the prompt was wrong; with the corrected prompt only the 2KB run definitively passes).
  A follow-up should pin the threshold precisely and check whether it is documented anywhere.
- Phase 2 was correctly skipped per the proposal's failure-handling instruction.
- No git operations were performed.
  The devlog is the only file modified.

## Independent QA Confirmation

A fresh QA subagent re-ran the out-of-repo case with an independently-generated marker (`CDOCS_MARKER_bf16720a61ab`) on a clean sandbox.

**Verdict: `confirm_failure`.** All load-bearing claims above are reproduced exactly, including the marker being absent across four further prompt variations.

The QA also ran two additional checks that produced new constructive findings:

1. **Spillover-fetch viability.** When the model is prompted to invoke the `Read` tool against the persisted-output path shown in the SessionStart hook framing, it retrieves the full bundle and echoes the marker verbatim (`[CDOCS_MARKER_bf16720a61ab]`). The data path is intact end-to-end; the failure is purely about default inline visibility.

2. **No auto-attach.** The session jsonl confirms the spillover file is never auto-attached as a tool result; only the truncated preview (the `hook_additional_context` entry, ~2,332 chars including framing) is model-visible by default. The `hook_success` entry holds the full stdout for transcript purposes but its `content` field is empty.

**Constructive implication:** a one-line addition to `inject-rules.ts` that prepends a Read-the-spillover directive within the first 2KB of output would let the model self-fetch the full bundle. The directive must sort before any rule content (e.g., as a synthetic alphabetically-first section). This is a cheap mitigation worth scoping in a follow-up proposal.

The QA also confirmed:
- The 2KB framing is precise: spillover wraps the first ~2,048 bytes of stdout in `<persisted-output>` with a fixed `Output too large (Xkb)... Preview (first 2KB):` preamble. Total inline `content` reaches the model at approximately 2.3KB.
- The cap-vs-bundle math: 13,353-byte bundle plus 30-byte marker append equals the 13,383 bytes the QA observed on disk.
- The cap may differ between `claude -p` oneshot and interactive sessions; interactive remains untested.
- The real `~/.claude/settings.json` SHA-256 was unchanged across both runs.
