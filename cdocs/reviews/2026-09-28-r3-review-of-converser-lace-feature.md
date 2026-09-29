---
review_of: cdocs/proposals/2026-09-28-converser-lace-feature.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-28T10:51:57-07:00
task_list: voice/converser-lace-feature
type: review
state: archived
status: done
tags: [rereview_agent, security, permissions, missing_validation]
---

# Review (round 3): converser lace devcontainer feature

> BLUF(opus/voice/converser-lace-feature): Revise, on one point.
> The round-2 items are addressed, and the document is now 3,909 words, under target.
> But the new write-constraint design, `Edit(//**)` plus `Edit(!//...)` carve-outs, is not merely unverified: the permissions docs rule it out.
> A `!` pattern is always read relative to the current directory, so it "can't reach a rule anchored with" `/`, `~/`, or `//`.
> A carve-out also "can't reopen a file inside a directory that a rule blocks as a whole."
> Phase 0(d) would therefore only confirm a known failure.
> The denylist fallback is incomplete: lace bind-mounts other host-writable paths, such as nvim data and the dotfiles repo, that reach host code execution.
> Recommend removing file-write tools from the converser entirely, in favor of a two-function MCP tool.

## Summary Assessment

Round 3 checks the round-2 fixes and the correctness of the new specifics.
Most landed cleanly:
- the reply channel is specified;
- option E is reworded accurately;
- the uniform-permission-mode assumption is stated;
- `VOICEMODE_TOOLS_ENABLED=converse` is set;
- Phase 0 gates (e)-(g) and a checkable Phase 4 test are added;
- OQ5 is decided;
- `PULSE_SERVER` is in the feature's `containerEnv`;
- the mermaid diagram is present;
- the cuts brought the proposal to 3,909 words.

The one blocking defect is that the mitigation for the design's highest-impact chain relies on a permission-rule construction that the docs say does not work.
Verdict: **Revise**.

## Verification (code.claude.com/docs/en/permissions, "Read and Edit" path rules)

The coordinator asked three questions.

1. **Is a deny list with `!` carve-outs a documented pattern?**
   Yes, but only in a narrow form. "A deny or ask pattern that starts with `!` is a gitignore negation. It carves the paths it matches out of the `path` or `./path` rules listed before it."
   The documented example is `Read(*.env)` followed by `Read(!sample.env)`.
2. **Does it work for negated absolute `Edit` rules?**
   No, and the docs say so explicitly: "Claude Code reads a `!` pattern relative to the current directory even when `/`, `~/`, or `//` follows the `!`, so the pattern can't reach a rule anchored with one of those prefixes. `Read(!~/notes/public/**)` carves nothing out of `Read(~/notes/**)`."
   A second limit applies independently: "A carve-out can't reopen a file inside a directory that a rule blocks as a whole", which is the gitignore rule that a file can't be re-included under an excluded parent.
   `Edit(//**)` blocks every directory as a whole.
   The proposal's block (lines 154-162) is therefore a blanket write deny with no working carve-out: the converser could not write its ledger or its reply files.
   Also, `${_REMOTE_USER}` in line 158 is a feature-build variable, not expanded in a runtime `--settings` file.
3. **Is the reply directory container-local and writable by the converser under the deny?**
   It is container-local: `/run/user/1000` is container filesystem created by `postStartCommand`, with only `pulse/native` bind-mounted inside it.
   It is writable at the OS level by `node`, since the directory is `chown node:node`.
   It is **not writable under the proposed deny**, for the reasons in item 2.
   Nothing creates `converser/replies/` either; the launcher needs a `mkdir -p -m 700`.

## Findings

**B1 [blocking] The write constraint must be redesigned, not gated.**
Phase 0(d) as written tests a construction the docs already say fails.
There are two viable replacements.
- **(a) Recommended: give the converser no file-write tool.**
  Drop `Edit`/`Write` from `--tools`.
  Add a tiny stdio MCP server that the feature installs next to VoiceMode in the converser's `--mcp-config`.
  It exposes exactly `ledger_append(text)` and `reply(question_id, answers)`, and writes only to fixed container-local paths.
  This removes the escalation chain structurally rather than by rule, costs about 50 lines of script, and makes the whole deny discussion unnecessary.
  Under `--strict-mcp-config` the server list stays explicit.
- **(b) Fallback: an `Edit` denylist of absolute or home-anchored rules, with no negation.**
  Those rule forms are valid for deny.
  The list must cover **every host-writable bind mount**, not just `.claude`/`.git/hooks`/`.envrc`.
  - The **entire workspace root**: any file there can be host-executed code, including package scripts, a Makefile, and ordinary source.
  - `~/.claude/**`, which also covers the lace target `~/.claude/.claude.json`, whose `mcpServers` entries are host-executed commands.
  - `~/.local/share/nvim/**`, the neovim feature mount: host plugin code.
  - `//mnt/lace/**`, which includes the dotfiles repo mount.
  - Any project-specific `runArgs` mounts.

  State plainly that the denylist is fragile to future mounts.

Either way, rewrite Background line 59, Proposed Solution lines 150-164, the threat row, and Phase 0(d)/Test Plan 2.
Under (a), the Phase 0 gate becomes "the converser has no Edit/Write tool, and the MCP tool writes only its two paths".

**B2 [blocking, follows from B1] The tool list is internally inconsistent.**
Phase 2's `--tools ListAgents,SendMessage,Edit` omits `Read`, so the ledger can't be read back, yet line 165 discusses `Read` credential denies.
It also omits `Write`.
Edit rules govern `Write`, and creating a new `<question-id>.json` reply file needs a file-creating tool.
Under B1(a) this resolves itself: the tools become `ListAgents,SendMessage` plus the MCP tools, and a `ledger_read` if needed, so line 165 reduces to "no `Read` tool".

**N1 [non-blocking]** The launcher should `mkdir -p -m 700 /run/user/1000/converser/replies`.
The reply-forgery row is correct as written.
If the MCP tool from B1(a) owns the directory, forgery by same-UID processes remains, as the row already states.

**N2 [non-blocking]** Everything else from round 2 is resolved and accurate.
The six-option table and verdict (E is conditional on native Unix-socket listeners), the uniform-mode paragraph, the `-p` exclusion framed as a filter, gates (e)-(g), and the Phase 4 scripted test all check out.
Frontmatter is compliant.
No inline fixes were needed this round.

## Verdict

**Revise.**
The design is otherwise ready.
Only the write-constraint mechanism blocks acceptance, and B1(a) is both simpler and stronger than the current approach.

## Action Items

1. [blocking] Replace `Edit(//**)`/`Edit(!//...)` with B1(a): no file-write tools, and a two-function container-local MCP writer. Alternatively use B1(b): a negation-free `Edit` denylist covering the workspace root, `~/.claude/**`, `~/.local/share/nvim/**`, `//mnt/lace/**`, and project mounts, labeled as fragile. Update Background line 59, Proposed Solution, the threat row, Phase 0(d), and Test Plan 2 to match, and cite the docs' two negation limits.
2. [blocking] Make `--tools` consistent with the chosen design (no `Edit`; resolve `Read` for the ledger), and drop or adjust the `Read`-deny paragraph accordingly.
3. [non-blocking] Have the launcher (or the MCP writer) create the replies directory with mode 700.

## Questions for the Author

1. Converser write path:
   - (a) A container-local MCP writer and no Edit/Write tool (recommended).
   - (b) A comprehensive `Edit` denylist.
