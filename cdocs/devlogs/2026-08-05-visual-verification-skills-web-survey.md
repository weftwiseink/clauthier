---
first_authored:
  by: "@claude-opus-4-8"
  at: 2026-08-05T00:00:00-07:00
task_list: cdocs/visual-review
type: devlog
state: live
status: wip
tags: [research, visual_review, skills, frontend, iterate]
---

# Devlog: web survey of visual frontend verification skills/tools

> BLUF: Dispatched a research subagent to survey off-the-shelf visual-verification skills/tools that could simplify cdocs' bespoke R1-R6 visual-review discipline, then verified its citations.
> Outcome: no product replaces the "is this render correct against a design mock" judgment; recommendation is wrap capture + pixel-diff, own the VLM-looker.

## Work log

- Read the [pixel-grounding handoff](../reports/2026-08-04-visual-review-gaps-and-pixel-grounding-handoff.md) for problem ground truth (four green-but-wrong `/iterate` rounds; measurement-as-proof-of-absence trap; proposed R1-R6).
- Noted the three `2026-07-30-*` companion reports it references are absent from this checkout (likely uncommitted in another worktree), so scoped the agent to fresh web research rather than re-deriving from them.
- Dispatched a `general-purpose` subagent (web-enabled) to survey Anthropic skills, MCP browser servers, baseline-diff regression tools, objective pixel-differs, and VLM-as-judge practice, then write a conforming cdocs report. Forbade git writes.
- Agent produced [the survey report](../reports/2026-08-05-visual-verification-skills-web-survey.md).

## Verification of agent output

Spot-checked the highest-fabrication-risk citations (trust-but-verify on a subagent's web claims):

- [Vision2Web arXiv:2603.26648](https://arxiv.org/abs/2603.26648): real; "Hierarchical Benchmark for Visual Website Development with Agent Verification," uses a VLM-based judge. Accurately characterized.
- [Digital Applied screenshot-driven UI blog](https://www.digitalapplied.com/blog/screenshot-driven-ui-development-vision-models-2026): real (2026-08-02); its limitation matrix (interaction states, motion, below-fold, cross-browser) matches the report.
- Anthropic [`webapp-testing`](https://github.com/anthropics/skills/tree/main/skills/webapp-testing) and [`frontend-design`](https://github.com/anthropics/skills/tree/main/skills/frontend-design) skills: both exist. The verbatim `frontend-design` quote ("a picture is worth 1000 tokens") is exact.

All spot checks passed; no corrections needed.

## Outcome

Headline: the market sells regression (diff against your own history), not correctness (diff against a supplied mock on first render). Only Applitools does perceptual diffing, and it is baseline-bound and paid.
Recommendation carried by the report: delegate R6 (ImageMagick `compare`) and R1's capture leg (browser-driver skill); own R1/R2/R4/R5 VLM-looker discipline as the differentiator.

Report and this devlog left uncommitted for maintainer review.
