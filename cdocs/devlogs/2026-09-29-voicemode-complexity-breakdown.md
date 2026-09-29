---
first_authored:
  by: "@claude-opus-5-5"
  at: 2026-09-29T10:00:00-07:00
task_list: voice/converser-lace-feature
type: devlog
state: live
status: done
tags: [voice, converser, research, voicemode]
---

# VoiceMode complexity breakdown: devlog

> NOTE(mjr/converser-migration): Moved from lace cdocs to clauthier cdocs on 2026-09-29; clauthier is the code target.

> BLUF: Follow-up to the fork-complexity report: a sonnet per-subsystem LOC breakdown of VoiceMode (non-test), answering where its ~44K lines actually go (conch/multi-agent, multi-provider, CLI, installers, etc.).

## User direction (2026-09-29)

- "Did we look deeper into where the complexity load in the voicemode repo comes from? A sonnet analysis could be useful - ie, how many LoC go into multiagent conch handling, multi audio model handling, etc (excluding tests)? ... give a table breaking it down."

## Prior coverage

`2026-09-28-voicemode-fork-complexity.md` gave totals (~43,600 non-test LOC) and sizes for a handful of hard-won subsystems (conch ~1,800, streaming 1,241, CLI ~5,900), but no exhaustive bucketed breakdown summing to the total.

## Work

- Dispatched a sonnet agent to classify every non-test file into subsystem buckets (raw + code-only LOC), sub-split `tools/converse.py`, and quantify core-vs-sprawl.
  Output: `cdocs/reports/2026-09-29-voicemode-complexity-breakdown.md`.
- Spot-checked: `voice_mode/` raw total 40,030 and conch files 1,978 raw match; bucket code-LOC sum to 23,946.
  Fixed one contradictory sentence ("19%, well under the 17%").
  Not put through a formal review round: a measurement report with checked arithmetic.
