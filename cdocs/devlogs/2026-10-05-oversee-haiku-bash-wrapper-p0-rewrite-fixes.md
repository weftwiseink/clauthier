---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-10-05T09:01:33-07:00
task_list: meta/token-spend-attribution
type: devlog
state: live
status: done
part_of: cdocs/devlogs/2026-10-05-oversee-haiku-bash-wrapper.md
tags: [meta, orchestration, oversee, haiku, hooks, devlog]
---

# Oversee Arc: p0 Bash-Runner Maintainer Rewrite Fixes

> NOTE(opus-5-5/oversee): Chunk of [2026-10-05-oversee-haiku-bash-wrapper](2026-10-05-oversee-haiku-bash-wrapper.md); see its Chunks table for siblings.

> BLUF(opus-5-5/oversee): The maintainer rewrote `bash-runner.md` and its caller guidance (`6821b43`); rev-bw-rewrite (`299394a`) found capture-file collisions, an OpenCode build that empties the block-scalar description, and typos; the overseer moved captures to `mktemp` (`3b32ae4`, then suffix-free `769664e` for BSD), impl-3 applied the small fixes (`0464785`..`734ef1f`, canary 17/17 exact), and rfp-4 filed the OpenCode build YAML parser RFP (`e740b5d`).

## Dispatch/Return Events

| event | agent_handle | target_files | at | notes |
|---|---|---|---|---|
| inline | overseer | bash-runner.md, orchestration-discipline.md | 2026-10-05T14:09 | committed maintainer rewrite 6821b43 (diff read first) |
| dispatch | rev-bw-rewrite (cdocs:reviewer, fresh) | review + canary evidence files | 2026-10-05T14:10 | review maintainer rewrite in its spirit |
| return | rev-bw-rewrite | `299394a` (review + _verify/2026-10-05-bash-runner-rewrite-canary.md, 9 runs, all correct vs truth) | 2026-10-05T14:40 | REVISE: capture-file collisions (unnamed file + append in shared /tmp/claude-uid), OC build empties block-scalar description, cross-target fallback deleted (oversee-arc dangling); typos (cdcos:), stale Bash Output Hygiene pointers, timeout hint lost, quadratic difflib idiom; proposal stale spots listed |
| inline | overseer | plugins/cdocs/agents/bash-runner.md | 2026-10-05T14:46 | `3b32ae4` mktemp capture (maintainer-requested, sanity-checked) |
| dispatch | rfp-4 (cdocs:proposer, sonnet) | cdocs/proposals/2026-10-05-opencode-build-yaml-parser-rfp.md | 2026-10-05T14:47 | OC build YAML parser RFP |
| dispatch | impl-3 (cdocs:implementer, fresh) | bash-runner.md, orchestration-discipline.md (Bash section), model-tiering.md, plugins/cdocs/AGENTS.md, haiku-bash-wrapper proposal, this devlog (notes) | 2026-10-05T14:47 | rewrite small fixes (iterate) |
| return | rfp-4 | `e740b5d` | 2026-10-05T14:52 | OC build YAML parser RFP filed |
| return | impl-3 | `0464785`..`734ef1f`, notes `52368d1`; build OK; typo grep empty; canary 17/17 exact via fresh mktemp capture | 2026-10-05T15:06 | judgment call: no-spec acceptance bar now names-only |
| dispatch | rev-bw-small (cdocs:reviewer, fresh) | review file | 2026-10-05T15:07 | verify small fixes |
| return | rev-bw-small | `86905aa` | 2026-10-05T15:15 | revise: 1 major (BSD mktemp suffix); names-only no-spec bar endorsed; nits non-blocking |
| inline | overseer | bash-runner.md, haiku-bash-wrapper proposal L142 | 2026-10-05T15:16 | `769664e` suffix-free mktemp template; grep + build verified (reviewer: no new round needed). Runner small-fixes done |

## Implementation Notes (impl-3, rewrite small fixes)

Applies the small, non-blocking fixes from the rewrite review ([`2026-10-05-review-of-bash-runner-maintainer-rewrite.md`](../reviews/2026-10-05-review-of-bash-runner-maintainer-rewrite.md), `299394a`) on top of the maintainer rewrite (`6821b43`) and the `mktemp` capture fix (`3b32ae4`), keeping the rewrite's wording, structure and looseness.

### Changes Made

| commit | file(s) | change |
|---|---|---|
| `0464785` | `plugins/cdocs/agents/bash-runner.md`, `plugins/cdocs/rules/orchestration-discipline.md` | Review item 4: `cdcos:` -> `cdocs:`, "You known", "if it more", missing comma; "Alwyas", the `"...'>` quote, "detect anything unexpected", trailing newline |
| `5637323` | `plugins/cdocs/rules/model-tiering.md`, `plugins/cdocs/AGENTS.md` | Item 5: "Bash Output Hygiene" pointers name the current "Bash: Avoid context bloat from careless bash commands" heading |
| `9e86779` | `plugins/cdocs/agents/bash-runner.md` | Item 6: one line under step 1, raise the Bash `timeout` up to 600000 for builds, suites, installs |
| `22023d2` | `plugins/cdocs/agents/bash-runner.md` | Item 7: the quadratic `difflib` one-liner becomes one line of linear idioms: a number-normalising `sort \| uniq -c` for near-duplicates, `awk '!seen[$0]++'` for exact repeats |
| `62c6c38` | `plugins/cdocs/rules/orchestration-discipline.md` | Item 8: case 1 names "a `cdocs:bash-runner` (or other sonnet) subagent"; interactive or TTY commands "are not dispatched (they hang without a terminal)" |
| `59c08ac` | `plugins/cdocs/agents/bash-runner.md` | Item 9: `Output:` reports `bytes: <byte_count>` instead of words |
| `734ef1f` | proposal | Item 10: input and output contracts, workflow, capture location, section name, edge cases, test plan, Phase 1-2 and the capture-location decision synced to the rewrite; obsolete excerpt and size rules, the scratchpad fallback and its impl-1 NOTE, and the superseded relaxed-reading NOTE dropped; one dated NOTE (`opus-5-5/impl-3`, 2026-10-05) records the loosening steer. Status stays `implementation_accepted` |

### Implementer Notes

- **Linear dedupe timing.** On 50,000 diverse `grep -rn` lines, the normalise-then-`sort | uniq -c` line took 0.56s and `awk '!seen[$0]++'` 0.06s; the review measured the `difflib` line at 56.6s for 2,000 lines.
- **Proposal NOTEs.** The completeness-first NOTE keeps its steer and evidence but loses its "defaults chosen" lines (the ~12K allowance, the `Excerpt:`-only list, the no-spec complete list), which the rewrite dropped. The relaxed-reading NOTE is dropped whole: its conclusion is now the body text, and its "mandatory one-line summary" claim is obsolete. The report-contract-v2 NOTE stays without its "refined by" line.
- **No-spec acceptance bar loosened in the proposal.** The test plan and acceptance bar ask the no-spec run to name every failing test, not to give its location, matching the rewrite's shift of that choice onto the caller (review "Observation", C2).
- **Not done (out of scope per brief).** The OpenCode build still emits `description: |` with an empty value (`build/cdocs/opencode/agents/bash-runner.md`); `oversee-arc.md:136,140` still point at the deleted cross-target text; "When dispatching commands" ("when running commands") is left as written.

### Verification

- `npm run build:cdocs` -> exit 0, `Agents converted: 7`; warnings unchanged (three `Unknown CC tool "*"` skips, Node `DEP0205`).
- `grep -rn 'cdcos\|Alwyas\|Bash Output Hygiene' plugins/cdocs` -> no matches.
- **Live canary (17 failures, "every failing test" spec)**, method from [`_verify/2026-10-05-bash-runner-rewrite-canary.md`](_verify/2026-10-05-bash-runner-rewrite-canary.md): fixtures regenerated with the same seeded `gen.py` in the session scratchpad (`F`: 6 `node --test` files, 360 tests, 17 failures, 1,184 lines, exit 1).
  `claude -p --plugin-dir <abs>/plugins/cdocs --model sonnet --output-format stream-json`, run from `F/`, plugin at `734ef1f`, Claude Code 2.1.289, parent and runner `claude-sonnet-5-5`, $0.12.
  The parent made one call, `Agent cdocs:bash-runner`, and relayed the report; the runner made 4 Bash calls and set no `timeout` (the suite runs in under a second).
  - **Capture:** `/tmp/claude-1000/bash-runner-czXzIF.log`, created by `mktemp -p "/tmp/claude-$(id -u)"` with `>` (no `bash-runner-*.log` existed there beforehand), 1,184 lines, identical to a direct run apart from timings, and named in `Output:` with `lines: 1184 bytes: 49230`.
  - **Report:** 2,714 chars, `Status: FAILED (returncode: 1)`, `Truncated: none`, a labelled 17-row table (name, file:line, expected total, actual total) and a ready-to-run `sed -n` follow-up.
  - **Ground truth** (Python matcher over `truth_F.json`): **17/17 exact** on name, `it` line, expected and actual.
  - **Containment:** no raw output line (`setup fixture`) appears in any parent-level event.
  - **Credentials:** the normal `HOME` was used, so no credential copies were made; a `find` over the scratchpad run dir and `/tmp/claude-1000` found none.
