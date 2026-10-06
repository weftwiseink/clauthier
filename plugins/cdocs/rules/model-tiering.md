# CDocs Model Tiering

Advisory default model tiers for dispatched work, chosen by reasoning load; a consumer's own model policy always wins.

- **Lead, overseer, and judgment (opus-class):** orchestration, review, and the `judge`, whose job is spotting meta-patterns such as a stuck implementer or a reviewer and implementer talking past each other. Do not downgrade these.
- **Search, explore, and research aggregation (sonnet):** find-and-summarize work the lead validates, including `bash-runner`, whose saving is the raw output kept out of the lead's context.
- **Mechanical fan-out (haiku):** work with a clear pass/fail signal against a fixed rubric, such as `nit-fix`.

A consumer with a blanket floor (for example "do not silently downgrade dispatched work") keeps it until it adds a named carve-out above it, as weftwise does with "always use sonnet for search, explore, and research aggregation".
