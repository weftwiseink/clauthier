# CDocs Model Tiering

Default model selection for dispatched work, organized by the reasoning load of the task rather than by the task's name.
The shape is advisory: it names a sensible default tier per workload class so an overseer does not reflexively run everything on the strongest (and most expensive) model.
A consumer's own model policy always wins over this shape; see "Precedence" below.

The tiering assumes the consumer is optimizing for value per token.
Running an entire long loop on an opus-class model is expensive; running the lead and judgment turns on opus and the bulk of dispatched turns on cheaper models is far cheaper for the same delivered work.
Concretely, 100 overseer turns on opus plus 9,900 subagent turns on cheaper models is an order of magnitude cheaper than 10,000 opus turns, and the overseer still validates every returned summary.

## Lead / Overseer / Judgment Tier (opus-class, strong model)

Orchestration and adjudication are reasoning-heavy, so the lead, the overseer, and any judgment call default to a strong model.
The `reviewer` and `judge` agents are the canonical judgment cases: both are `model: opus` in `plugins/cdocs/agents/`.
The judge is the quintessential opus case, because it must spot subtle meta-patterns the raw work does not surface: an implementer stuck in a local optimum, or a reviewer and implementer talking past each other.
Sonnet can read an iteration log; opus is what reasons about the meta-pattern behind it.
Do not downgrade lead or judgment work.

## Search / Explore / Research-Aggregation Tier (sonnet)

When the workload is "find information and summarize it" rather than "reason deeply about trade-offs," sonnet is the default.
It is cheaper and fast enough for this class, and the overseer validates the returned summary before acting on it.
This tier covers exploratory search sweeps, codebase reconnaissance, and straightforward research aggregation.

## Mechanical / Deterministic Fan-Out Tier (haiku, cheapest capable model)

When the task has a clear pass/fail signal and needs no reasoning flexibility, the cheapest capable model is the default.
The `nit-fix` agent is the canonical case: it is `model: haiku` in `plugins/cdocs/agents/`.
These tasks fan out mechanically against a deterministic rubric, so a stronger model buys nothing.

The `bash-runner` agent (`cdocs:bash-runner`) is a second named case: it is `model: haiku`, runs one expected-verbose command with output captured to a scratch file, and returns a bounded fixed-format extract (see "Bash Output Hygiene" in `orchestration-discipline.md` for when to dispatch it).
Like every tier here it is a named carve-out a consumer must bless, not an automatic override: a consumer with a blanket opus floor keeps that floor for this dispatch until it explicitly opts `bash-runner` down to haiku (see "Precedence").

The `triage` agent's base mechanical-fix workload (frontmatter fields, timestamps, tags) fits this tier, but the agent is `model: sonnet` (not haiku) because its iterate-aware analysis step sits in the Search/Explore tier: it globs `cdocs/devlogs/*.md`, filters by frontmatter `task_list` and by body citation, tie-breaks candidates, then parses two header-keyed markdown tables and applies a precedence mapping.
Since `triage.md` carries a single `model:` field, the whole agent runs at the higher tier the parse/reasoning step requires; this is the accepted tradeoff of a model bump over splitting the skill.

## Precedence

This tiering shape is ADVISORY, and a consumer's own model policy ALWAYS WINS.
Where a consumer sets a blanket floor, the shape collapses toward that floor unless the consumer opts a tier back down.
For example, weftwise's "do not silently downgrade dispatched work" floor forbids exactly the search/explore downgrade to sonnet, so under that floor the search/explore tier does not apply until the consumer chooses to re-enable it.

The intended adoption path is a consumer adding a NAMED CARVE-OUT above its floor.
weftwise's `CLAUDE.md` doing precisely this, "always use sonnet for search, explore, and research aggregation" above its Opus floor, is the model to follow.
This rule ships those carve-outs as ready-to-adopt guidance, NOT as an automatic override that dictates a downgrade a consumer's floor forbids.
A consumer with no such floor can adopt the tiers directly; a consumer with a floor keeps the floor until it writes a carve-out of its own.

## Cross-Target Degradation

Rule content delivers to OpenCode cleanly: `/cdocs:init` globs this file into `.opencode/rules/cdocs/` automatically, so the tiering guidance ships cross-target with no runtime dependency.
