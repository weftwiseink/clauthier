---
review_of: cdocs/reports/2026-09-28-host-audio-broker-split.md
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-28T11:25:49-07:00
task_list: voice/converser-lace-feature
type: review
state: live
status: done
tags: [rereview_agent, security, consistency, conch, options_ladder]
---

# Review (round 2): Splitting converser: a host-side audio broker

## Summary Assessment

The revision resolves every round-1 blocking item.
- **Access control:** the report now states the access-control model correctly (loopback-peer under `pasta:-T`, the token as the only discriminator, token visibility across the container).
- **Tool scoping:** it adds a correct host-side tool-scoping subsection.
- **Security gain:** it rewrites the security gain as "loses raw audio and pulse control, keeps room transcription and TTS".
- **Android:** it fixes the Home Assistant/Wyoming premise and adds VoiceMode Connect.
- **Options ladder:** it rebalances option 0 against option 2 fairly.

It is also consistent with the accepted vetting report's finding A14 (`label=disable` applies to every container).
One new factual error affected section 2 and decision point 3. The report treated sharing the conch as opt-in. In fact the conch path is hardcoded to `$HOME/.voicemode` and ignores `VOICEMODE_BASE_DIR`, so the conch is shared by default. I fixed this inline, together with several minor items.
Verdict: **Accept**.

## Round-1 action items

1. Serve auth defaults: resolved (section 1, BLUF).
2. `pasta:-T` peer is `127.0.0.1`, token container-wide, one `serve` per container: resolved.
3. Tool scoping, `service` tool, OpenAI fallback, required host env: resolved (new subsection).
4. Security gain restated, choke-point claim qualified, Unix-socket `label=disable` note: resolved. The vetting report's A14 now supersedes the `label=disable` point, and the report reflects that correctly.
5. Home Assistant Companion is not a Wyoming client: resolved (sections 3 and 4).
6. VoiceMode Connect and the upstream roadmap: resolved.
7. Options ladder rebalanced and reconciled with fork report option (a): resolved.
8. Smallest experiment fixed (throwaway container, 401 / `tools/list` / conch checks, allowlist-failure reading dropped): resolved.
9. Pipecat list, PWA HTTPS, Tailscale scope, OS-dictation rung: resolved.
10. Unverified-claims list updated: resolved. The BLUF is still eight lines, but each line now carries one claim.

## New findings

- **N1 [was blocking, fixed inline]** Section 2 and decision point 3 framed cross-project conch sharing as something to opt into deliberately. Decision point 3 also recommended per-project state "matching today's isolation" and used a nonexistent `VOICEMODE_HOME`.
  Source check:
  - `Conch.LOCK_FILE = Path.home() / ".voicemode" / "conch"` (`conch.py:133`).
  - The queue and grant files are its siblings (`conch_queue.py:131-136`), and none of these reads `VOICEMODE_BASE_DIR`.
  - The real override variable is `VOICEMODE_BASE_DIR` (`config.py:545`). It moves transcripts, audio and logs (`:548-550`), but not the conch.

  So same-user host `serve` processes share the conch automatically, and a per-project `VOICEMODE_BASE_DIR` still isolates transcripts.
  I rewrote the section 2 paragraph, the section 5 table cell and summary line, and decision point 3.
  Decision point 3 now offers: (a) share everything; (b) per-project `VOICEMODE_BASE_DIR` with the conch shared; (c) a per-process `HOME` override that splits the conch.
  It recommends (b), which keeps the accepted proposal's transcript isolation (proposal `:190`) and closes the accepted vetting report's double-capture gap (vetting `:89`).
  The previous recommendation would have contradicted that accepted finding.
- **N2 [fixed inline]** The tool-default citation was `tools/__init__.py:117-121`. The default branch is at `:116-120` (comment at 116, `default_tools = {"converse", "service"}` at 119). The coordinator's `111-116` from the fork report's round 2 is also slightly off. The claim itself, that the default loads only `converse` and `service`, is correct.
- **N3 [fixed inline]** History-agnostic framing: removed three references to the "original draft" or "round-1 review" (Context, the Home Assistant paragraph, section 6). The Links section keeps the round-1 review link, which is appropriate.
- **N4 [fixed inline]** Added a link for [#546](https://github.com/mbailey/voicemode/issues/546) on first mention.
- **N5 [fixed inline]** Consistency with the vetting report. Its first experiment is option S: host `serve`, and `weftwise` gets one `pasta:-T,8765` line and no audio stack. Section 6 now names its own throwaway-container test as a pre-check for option S, not a competing plan.
  Decision point 1's "(c) near-peers, let the experiment decide" is compatible with the vetting report's recommendation (c) ("host `serve` first, in-container only if needed"), since both run host `serve` first.
- **N6 [non-blocking]** The VoiceMode Connect claims match `.claude/skills/voicemode-connect/SKILL.md`: MCP to `voicemode.dev`, clients over WebSocket, an iOS app and a web app, OAuth. Android comes only from the #546 roadmap quote, and the report labels it that way.
- **N7 [non-blocking]** The Unix-socket `connectto` discussion and its unverified-claims bullet are now mostly moot, because `label=disable` applies universally (A14). They are harmless, but could be cut in a later pass.

## Verdict

**Accept.**
All round-1 blocking items are resolved. The one new substantive error (N1) was a source-checkable fact, and I corrected it inline in line with the already-accepted vetting report.

## Action Items

1. [non-blocking] The author should confirm that the inline rewrite of decision point 3 (N1) matches their intent. The recommendation changed as a consequence of the source fact.
2. [non-blocking] Consider trimming the section 1 `connectto` material now that A14 settles `label=disable` (N7).
