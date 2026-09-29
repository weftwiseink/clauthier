---
review_of: cdocs/proposals/2026-09-28-converser-lace-feature.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-28T10:37:02-07:00
task_list: voice/converser-lace-feature
type: review
state: archived
status: done
tags: [fresh_agent, runtime_validated, architecture, security, networking, missing_validation]
---

# Review: converser lace devcontainer feature

> BLUF(opus/voice/converser-lace-feature): Revise.
> Two of the three claims the design rests on are false, and this reviewer confirmed both empirically.
> First, the devcontainer feature spec has `securityOpt`, `capAdd`, `privileged`, and `mounts` fields, and the devcontainer CLI that lace invokes honors them.
> Second, podman's default pasta invocation passes `-T none`, so a container cannot reach a host `127.0.0.1` port without explicit flags: the proposal's default `sttBaseUrl`/`ttsBaseUrl` would fail as written.
> The third claim, that managed settings are container-scoped and merge hooks additively, holds up, but it has consequences the proposal leaves out.
> These include `crossSessionInbound: "accept"` for every overseer in the container, a converser Stop-hook self-loop, and "first-wins" managed-source precedence.
> The security table has factual errors of its own, and some rows understate the risk.

## Summary Assessment

The proposal packages the 2026-09-27 voice research arc as a lace feature: audio stack, pinned VoiceMode, a launcher, and hooks delivered through container-local managed settings.
The structure is good and follows the graphify template closely.
The managed-settings choice is well reasoned, and the docs support it.
However, the BLUF's main architectural claim ("the feature cannot declare `runArgs`/`--security-opt`") is wrong: the feature spec and the CLI source both show it.
The networking recommendation contradicts the podman manpage the proposal itself cites as "verified/docs", and it also contradicts the source report's own empirical finding.
Several security-table rows are factually wrong (`label=disable` scope, the weftwise precedent) or leave out load-bearing risks.
Verdict: **Revise**.

## Empirical Verification Performed

The reviewer ran these read-only checks on this host (Fedora, SELinux Enforcing, podman 5.8.2, netavark plus pasta):

| Check | Result |
|---|---|
| `grep securityOpt` in `@devcontainers/cli` 0.87.0 `dist/spec-node/devContainersSpecCLI.js` | The CLI picks `capAdd`, `securityOpt`, `entrypoint`, `mounts`, `customizations` from feature metadata, merges them across features, and emits `--security-opt` for each one |
| `man podman-run`, pasta section | "`-T none` and `-U none` are given to disable the same functionality [automatic forwarding based on bound ports] from container to host" |
| Host `python3 -m http.server --bind 127.0.0.1`; `podman run --network pasta` probes `127.0.0.1:<port>` | `ECONNREFUSED` |
| Same probe with `--network pasta:-T,<port>` | `200 OK` |
| Unix-connect to a bind-mounted `/run/user/1000/pulse/native` (`user_tmp_t`, served by `unconfined_t`), without `label=disable` | `EACCES` |
| Same connect with `--security-opt label=disable` | Connects |
| `grep label=disable` in `weftwise/main/.devcontainer/devcontainer.json` | Absent: weftwise's `runArgs` holds only the Wayland `--mount` and `--shm-size=1g` |
| `mount-resolver.ts:351-355` recommendedSource substitution | Only `${lace.projectName}` is substituted, so `<project>` stays literal |
| `code.claude.com/docs/en/managed-settings` | Confirms the `/etc/claude-code/managed-settings.json` path. Also documents a `managed-settings.d/*.json` drop-in directory, default "first-wins" across managed sources (remote/server-managed ranks above file), and "refuses to start" on an invalid-JSON managed file |
| `code.claude.com/docs/en/hooks` | Confirms the additive hook merge quote verbatim and `last_assistant_message` on Stop |
| `code.claude.com/docs/en/settings` | Confirms `crossSessionInbound`: project/local only honored when stricter; managed/`--settings`/user honored |

## Section-by-Section Findings

### BLUF

**[blocking]** The BLUF states two false claims as verified facts: the feature cannot declare security options, and pasta forwards host loopback by default.
The BLUF has to match what the body can support once both claims are corrected (see below).
It is also a single run-on sentence of roughly 90 words on line 14, and the other two lines each carry several sentences.
Per writing conventions, split it into one thought per line.

### Background: "Lace facts, verified against source"

**[blocking] The `runArgs`/`--security-opt` claim is wrong, and it is the crux decision.**
The claim reads: "the devcontainer feature spec itself has no `runArgs` field (only `mounts`, `containerEnv`, `customizations`)".
The spec has no `runArgs` field, which is true, but it does have `securityOpt`, `capAdd`, `privileged`, `init`, `entrypoint`, and a spec-native `mounts` array of `{type, source, target}` bind/volume objects.
The devcontainer CLI lace shells out to merges these fields from every installed feature and emits `--security-opt` for them (verified in the CLI bundle above).
The official `go` feature is the canonical example, with `capAdd: ["SYS_PTRACE"]` and `securityOpt: ["seccomp=unconfined"]`.
`up.ts` not touching feature `runArgs` is irrelevant: lace does not need to, because `devcontainer up` handles feature metadata itself.
The weftwise TODO the proposal cites says the typed *lace* mount resolver rejects sockets, not that features cannot mount sockets.
It is silent on spec-native feature `mounts`.

Consequence: `securityOpt: ["label=disable"]` can go in `converser`'s manifest.
A spec-native `mounts` bind of the pulse socket can too, although that choice has costs.
The source path would be hardcoded (uid 1000), which the spec's variable support may or may not help with, and this must be verified.
Container creation would also hard-fail on hosts without the socket.
Keeping the mount and `label=disable` project-level may still be the right call.
Explicit opt-in to container-wide SELinux weakening is a defensible reason.
The proposal must present that as a *choice with rationale*, not a structural impossibility.
The claim also propagates to the Summary ("structurally cannot"), the Proposed Solution heading "What the feature cannot declare", the README "required copy-paste", and Open Question 1, which frames a lace gap that is at most half-real.
The socket-aware *lace* mount type is real; feature-contributed security options already exist.

**[blocking] The weftwise `label=disable` precedent does not exist.**
The claims "`weftwise` already carries it for Wayland", "a project adding both features pays the cost once", and the security table's "already accepted for Wayland in weftwise" are all false against `weftwise/main/.devcontainer/devcontainer.json`.
For weftwise, Phase 5 is a new, container-wide SELinux relaxation, not a reused one.
It also raises an unexamined question: how does weftwise's Wayland passthrough work without it?
The reviewer's pulse probe got `EACCES` without `label=disable`.
Either the Wayland socket has a different label, or the Wayland path is also broken under Enforcing.
Also, `jif/main/.devcontainer/devcontainer.json` already binds `pulse/native` *without* `label=disable`.
That config is a closer precedent than weftwise's, and by this probe it is likely broken.
Both belong in the Background as accurately described precedent.

**[non-blocking]** The managed-settings facts are accurate and well cited.
This is the proposal's strongest verification.

### Proposed Solution: feature contents

**[blocking] `recommendedSource: "~/.voicemode-<project>"` defeats the per-project isolation it exists for.**
`mount-resolver.ts` substitutes only `${lace.projectName}`.
The literal `<project>` string creates one shared `~/.voicemode-<project>` directory for every project, which is exactly the cross-project transcript leak the Security Analysis claims to prevent.
Use `~/.voicemode-${lace.projectName}`, or omit `recommendedSource` and let lace derive a per-project default.

**[non-blocking] Running `uv tool install` as root during feature build lands in root's `~/.local`.**
The binary would then not be on the remote user's PATH.
Graphify sets `PIPX_HOME=/usr/local/pipx` and `PIPX_BIN_DIR=/usr/local/bin` for exactly this reason.
State `UV_TOOL_DIR`/`UV_TOOL_BIN_DIR` (or equivalent) explicitly rather than leaving it to Phase 1.

**[non-blocking]** The `"PINNED_VERSION"` default is a placeholder that fails at install time if shipped.
Mark it with a `TODO(...)` callout or pick the pin now, since graphify pinned `0.9.61` at proposal time.

**[blocking] Step 5 (jq-merge into `managed-settings.json`) is the wrong mechanism.**
The docs document `/etc/claude-code/managed-settings.d/*.json`, merged alphabetically, with list keys (including `hooks`) unioned.
Write `/etc/claude-code/managed-settings.d/50-converser.json` instead.
This resolves Open Question 5 outright, and it removes the idempotency risk.
The risk matters: an invalid-JSON managed file makes Claude Code *refuse to start*, so a botched merge bricks every session in the container.

### Proposed Solution: where hooks and settings live

The container-scoping argument is sound: the file is baked into the image, never bind-mounted, and hooks merge additively.
The following consequences are missing:

- **[blocking] `crossSessionInbound: "accept"` in managed settings applies to every session in the container, not just the converser.**
  The deep-dive report puts `accept` in the converser's own `--settings` specifically because "user settings would apply to every session".
  Managed has the same breadth.
  This disables the bypass-mode inbound hold for every bypass-mode overseer in the container, so any same-container session's `SendMessage` is taken without prompting.
  Per the messaging report, overseers do not need `accept` to receive from a bypass-mode converser: a bypass-mode sender already passes the hold.
  Move `accept` into the launcher's `--settings`, or justify the container-wide scope and add it as a threat-table row.
- **[blocking] The Stop hook fires in the converser session itself.**
  Managed hooks cannot be disabled from the converser's `--settings` (`disableAllHooks` outside managed has no effect on managed hooks).
  So every converser turn-end posts its own `last_assistant_message` to its own inbox, a self-wake loop.
  The hook script needs an explicit self-exclusion (for example, an env marker set by the `converser` launcher) and a test for it.
- **[non-blocking] "First-wins" managed-source precedence.**
  If the user's claude.ai org delivers server-managed settings, Claude Code ignores the container file entirely and shows no warning.
  That silently disables all three settings.
  Document this, and add a `/status` "Setting sources" check to the Test Plan.
- **[non-blocking] Parent settings.**
  A managed file also causes Claude Code to ignore SDK/IDE-host parent settings by default.
  This is minor, but it is a side effect on every session in the container and should be noted.
- **[non-blocking] Headless sessions.**
  "Every session" includes headless `claude -p` workers (for example, dispatched `/cdocs:iterate` sessions), whose turn-ends would be pushed and voiced.
  Say whether that is intended, or filter it in the hook.

### Proposed Solution: networking and firewall

**[blocking] The recommended default is contradicted by the cited source and by the source report's empirical data.**
The `podman-run` manpage, which the proposal lists as "verified/docs", states that podman passes `-T none` and `-U none` to pasta by default, disabling container-to-host auto-forwarding.
The passt.top quote describes standalone pasta, not pasta as podman invokes it.
The clauthier containerized report (line 89) already recorded "verified/empirical: from `weftwise`, `curl` ... is refused for ones bound to `127.0.0.1`".
The proposal's statement that "loopback-to-loopback pasta forwarding, specifically, has not been run" therefore misstates the evidence.
The reviewer's probe settles it: the default fails, and `--network pasta:-T,<port>` succeeds.

The recommendation is salvageable, and still better than firewalld.
Keep loopback-only binds and add `"--network", "pasta:-T,2022,-T,8880"` to the required project `runArgs`.
The spec has no feature-level network field, so this one genuinely is project-only.
Alternatively, set `pasta_options` in the host `containers.conf`, which is host-wide.
New Phase 0 gate: confirm that overriding `--network` does not break lace's port publishing or portless ingress.
weftwise's portless pin comment shows ingress on rootless pasta is fragile.
Phase 0(c) as written ("no explicit `-T`/`-t` flags") tests the path that is now known to fail.

**[non-blocking]** The firewalld cost/risk paragraph (line 148) is a single ~130-word sentence, and it makes an unverified claim that "container-to-host traffic reaches the host as the host itself" under pasta.
Mark that claim as unverified or cite it.
The "accept-above-reject depends on rule ordering" point is correct in spirit, but firewalld rich-rule ordering is by priority/type, not by insertion order.
Word it precisely or drop it.

**[non-blocking]** "Verified/docs" is used for claims whose docs describe a different invocation context.
Tighten this to "verified/docs (standalone pasta)" versus "verified/empirical (podman here)".

### Important Design Decisions

**[blocking, follows from the above]** "Loopback STT/TTS + pasta forwarding" must be restated with the explicit `-T` flags and the added project `runArgs` cost.
"Reverses the source report's WARN-flagged default" is prior-approach framing in body text.
Move it to a `NOTE()` callout per history-agnostic framing.

**[non-blocking]** Add a decision entry for "security options stay project-level by choice", with the rationale (explicit SELinux opt-in, host-specific socket path, hard failure on socket-less hosts).
This replaces the "cannot" framing.

### Security Analysis

The table covers the required threats in breadth, but several rows are not detached enough:

- **[blocking] The `label=disable` row is factually wrong on scope.** The mitigation says "Scoped to the one socket mount, not the whole container".
  `--security-opt label=disable` runs the entire container process unconfined by SELinux (no `container_t` separation), not per-mount.
  The impact is also understated: it removes SELinux as a container-escape layer for every process in the container, not just `connectto`.
  The "precedent" cell is false (see Background).
- **[blocking] The converser permission-mode row overstates containment.** It claims bypass mode "has no meaningful blast radius beyond the ledger file".
  The `Write` tool is not path-restricted.
  A bypass-mode converser, driven by acoustic injection (the row directly above), can write `~/.claude/settings.json` on the *shared bind mount* and plant a user-scope hook, which gives code execution on the host and in every container.
  That is the highest-impact chain in the design, and the table rates it as contained.
  Mitigations include a `permissions.deny`/path-scoped allow for `Write` in the converser's `--settings`, or dropping `Write` for a ledger-append MCP tool or hook.
- **[blocking] A row is missing for `accept` breadth.** Per the section above, managed `accept` removes the bypass-hold for all overseers in the container.
- **[non-blocking] A row is missing for content exposure through the Stop hook.** Every overseer's `last_assistant_message` (which can contain secrets, tokens, or file contents) is pushed to the converser, may be spoken aloud, and is retained in VoiceMode logs.
- **[non-blocking] A row is missing for cloud fallback.** VoiceMode's default base-URL lists include an OpenAI fallback (per the source report).
  The single-URL options remove it, but that is a security property that should be stated, with a guard against a user appending the fallback while `OPENAI_API_KEY` is present.
- **[non-blocking]** The inbox-injection row is fair.
  The acoustic-injection row should note that "verbatim echo before relay" is a prompt-level control, which the converser model can be talked out of, not an enforcement.

### Test Plan and Implementation Phases

**[blocking]** Phase 0 needs these revisions:
- (c) must test the explicit `-T` path plus lace ingress compatibility, not the default path.
- Add a test of feature-level `securityOpt` through `lace up`, if the design moves it into the feature or wants to keep that option open.
- Add a check on whether weftwise's Wayland path currently works under Enforcing without `label=disable`, which informs the Phase 5 SELinux cost.

**[non-blocking]** Phase 3 should add a converser-self-exclusion test and a `/status` managed-source check.
It should also test that a malformed drop-in does not ship: validate with `jq empty` at install time.

**[non-blocking]** The phases otherwise agree with the Proposed Solution, and the Phase 0 "reshape before building" framing is good.

### Writing conventions and frontmatter

- **[non-blocking]** There is an em-dash on line 194 ("(c) the pasta loopback-forwarding test — bind ...").
- **[non-blocking]** Sentence-per-line is widely violated: BLUF lines 14-16, lines 116-118, 124, 148, 153, and 161-167 each carry several sentences.
- **[non-blocking]** A mermaid sequence diagram would earn its place for the message topology (overseer Stop hook to converser inbox, converser `SendMessage` to overseer, `AskUserQuestion` relay with timeout fallback).
- **[non-blocking]** `first_authored.by: "@claude-sonnet-5"` should be a full API-valid model id per the frontmatter spec.
  `first_authored.at` (10:40) is later than this review (10:37), so check the clock.
- **[non-blocking]** Frontmatter is otherwise compliant: type, state, and `status: review_ready` are correct, and the tags are focused.

## Verdict

**Revise.**
The managed-settings approach is sound, and the document is well structured.
The two other load-bearing premises are false and empirically disproven: the feature-spec capability and pasta's default forwarding under podman.
The security table contains a scope error (`label=disable`), a false precedent, and an understated privilege-escalation chain.
None of this invalidates the overall design, but the BLUF, the crux decisions, and the default option values all have to change.

## Action Items

1. [blocking] Correct the feature-spec claim everywhere (BLUF, Summary, Background, the "cannot declare" section, README guidance, Open Question 1): features *can* declare `securityOpt`/`capAdd`/`privileged`/spec-native `mounts`, and the devcontainer CLI honors them. If security options stay project-level, reframe that as a deliberate choice with rationale.
2. [blocking] Remove the false weftwise `label=disable` precedent. Describe weftwise (Wayland mount, no `label=disable`) and jif (pulse mount, no `label=disable`) accurately, and treat `label=disable` as a new, container-wide cost for weftwise.
3. [blocking] Fix the networking recommendation: podman passes `-T none`, so add `--network pasta:-T,2022,-T,8880` (or a host `containers.conf` `pasta_options`) to the required setup. Rewrite Phase 0(c) to test that path plus lace port-publishing/portless ingress compatibility. Correct "loopback forwarding has not been run" against the source report's empirical refusal.
4. [blocking] Change `recommendedSource` to `~/.voicemode-${lace.projectName}`, since the literal `<project>` shares one directory across all projects.
5. [blocking] Deliver settings via `/etc/claude-code/managed-settings.d/50-converser.json`, not a jq merge. Validate the JSON at install time, since an invalid managed file stops Claude Code from starting. Close Open Question 5.
6. [blocking] Move `crossSessionInbound: "accept"` to the converser launcher's `--settings`, or justify the container-wide scope and add a threat row for the removed bypass-hold on all overseers.
7. [blocking] Add converser self-exclusion to the managed Stop hook (managed hooks cannot be disabled from `--settings`), and add a test for it.
8. [blocking] Security table: correct the `label=disable` scope (whole container) and impact. Correct the converser-permission row: unrestricted `Write` plus bypass allows writing the shared `~/.claude/settings.json`, which is a host-code-exec chain. Add a path-scoped `Write` restriction or drop `Write`.
9. [non-blocking] Add threat rows for Stop-hook content exposure (secrets spoken or logged) and cloud STT/TTS fallback.
10. [non-blocking] Document "first-wins" managed-source precedence (server-managed settings silently override the container file), and add a `/status` check to the Test Plan.
11. [non-blocking] Specify system-wide `uv` tool dirs (mirroring graphify's `PIPX_HOME`/`PIPX_BIN_DIR`), and replace the `PINNED_VERSION` placeholder or flag it with a `TODO()` callout.
12. [non-blocking] Writing conventions: remove the em-dash on line 194, split multi-sentence lines (especially the BLUF and line 148), move the "Reverses the source report's default" framing into a `NOTE()` callout, consider a mermaid sequence diagram for the message flow, and use a full model id in `first_authored.by`.

## Questions for the Author

1. Where should `label=disable` and the pulse mount live?
   - (a) Project `runArgs` as an explicit opt-in (current shape, reframed as a choice).
   - (b) `securityOpt` in the feature manifest, with the mount still project-level.
   - (c) Both in the feature via spec-native `mounts` plus `securityOpt`, accepting hard failure on hosts without the socket.
2. Host STT/TTS reachability:
   - (a) Project `runArgs` `--network pasta:-T,2022,-T,8880`.
   - (b) Host-wide `containers.conf` `pasta_options`.
   - (c) Fall back to a non-loopback bind plus firewalld.
3. Scope of `crossSessionInbound: "accept"`:
   - (a) Converser-only via launcher `--settings` (recommended).
   - (b) Container-wide via managed settings, with the threat documented.
4. Should the Stop-hook push skip headless `claude -p` sessions, or voice every turn-end in the container?
