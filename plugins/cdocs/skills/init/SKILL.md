---
name: init
description: Scaffold CDocs directory structure in a project
argument-hint: "[--minimal]"
---

# CDocs Init

Scaffold the CDocs documentation structure in the current project.

## Behavior

1. Create directory structure:
   - `cdocs/devlogs/`
   - `cdocs/proposals/`
   - `cdocs/reviews/`
   - `cdocs/reports/`
   - `cdocs/_media/`

2. Generate a lightweight README.md in each document subdir with:
   - A brief description of the doc type's purpose.
   - A format summary (required sections, naming convention).
   - A reference to the full skill: "See `/cdocs:<type>` for complete authoring guidelines."

3. Create or update `.claude/rules/cdocs.md` with the content of every `${CLAUDE_PLUGIN_ROOT}/rules/*.md` file, frontmatter stripped, in the section order of the AGENTS.md block in step 6.
   This is the file Claude Code loads and re-injects after every compaction, so it must carry every rule file in full.
   If `.claude/rules/` doesn't exist, create it.
   Do not add an `@.claude/rules/cdocs.md` import to CLAUDE.md: Claude Code auto-loads every unscoped `.md` under `.claude/rules/`, gives it to subagents, and re-injects it after compaction.
   If the project's CLAUDE.md contains the exact line `@.claude/rules/cdocs.md`, remove that line.

   Immediately after any frontmatter and before the body, write the version-and-hash marker comment in the canonical form:
   ```markdown
   <!-- cdocs rules vX.Y.Z hash=<sha256> - regenerate with /cdocs:init (use version from plugin.json) -->
   ```
   - Use the version from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`.
   - Compute `<sha256>` as the sha256 hex digest of the alphabetically-sorted, concatenated raw bodies of `${CLAUDE_PLUGIN_ROOT}/rules/*.md`. Bash one-liner: `(cd "$CLAUDE_PLUGIN_ROOT/rules" && ls *.md | sort | xargs cat) | sha256sum | awk '{print $1}'`.
   - The freshness-check hook (`plugins/cdocs/hooks/inject-rules.ts`) reads this marker on subsequent session starts; hash-based comparison avoids spurious refresh nudges on version-only bumps. The marker shape must match exactly so the hook's opaque-string compare stabilizes on re-runs.

4. Scaffold the chat record directory `cdocs/_chat/` (Claude Code's `UserPromptSubmit` and `Stop` hooks record nothing until it exists):
   - `cdocs/_chat/README.md` from the template below.
   - `cdocs/_chat/.gitattributes` containing exactly `*.md merge=union`, so appends made to one record in two checkouts merge or rebase without conflict.

   If `$ARGUMENTS` includes `--minimal`, skip README generation, rules file creation, and this step: create only the five directories of step 1 and no `cdocs/_chat/`, so the hooks never run in a project without the rule text.

5. **OpenCode detection and rule deployment:**
   If `opencode.json` exists in the project root OR a `.opencode/` directory exists, also perform:

   a. Create `.opencode/rules/cdocs/` directory.
   b. Copy each rule file from the plugin's `rules/` directory into `.opencode/rules/cdocs/` with OC-enhanced frontmatter prepended:
      ```yaml
      ---
      globs:
        - "cdocs/**/*.md"
      keywords:
        - "cdocs"
        - "cdocs devlog"
        - "cdocs proposal"
        - "cdocs review"
        - "cdocs report"
      ---
      ```
      Strip any existing YAML frontmatter from the source rule file before prepending the OC frontmatter.
      Add a version-and-hash comment after the frontmatter: `<!-- cdocs rules vX.Y.Z hash=<sha256> - regenerate with /cdocs:init (use version from plugin.json) -->` (same shape as `.claude/rules/cdocs.md`; see Step 3 for hash computation)
   c. Delete any file in `.opencode/rules/cdocs/` that has no source rule file, so a removed rule does not linger.
   d. The OC-enhanced frontmatter activates rules conditionally via the `opencode-rules` plugin: they load only when editing cdocs files or mentioning cdocs-specific terms.

6. **AGENTS.md creation (cross-tool fallback):**
   Create or update an `AGENTS.md` in the project root with inlined rule content (not `@`-imports, for maximum tool compatibility).

   - If AGENTS.md does not exist, create it with a header and the inlined cdocs rules section.
   - If AGENTS.md already exists, check for `<!-- cdocs-rules-start -->` / `<!-- cdocs-rules-end -->` delimiters:
     - If found, replace the content between the delimiters with the current rule content.
     - If not found, append the cdocs rules section at the end of the file.
   - The cdocs rules section uses this structure:
     ```markdown
     <!-- cdocs-rules-start -->
     ## CDocs Writing Conventions

     [Full content of writing-conventions.md, frontmatter stripped]

     ## CDocs Workflow Patterns

     [Full content of workflow-patterns.md, frontmatter stripped]

     ## CDocs Overseer Rules

     [Full content of overseers.md, frontmatter stripped]

     ## CDocs Tool Use Guidance

     [Full content of tool-use-safeguards.md, frontmatter stripped]

     ## CDocs Frontmatter Specification

     [Full content of frontmatter-spec.md, frontmatter stripped]
     <!-- cdocs-rules-end -->
     ```
   - Add a version-and-hash comment inside the delimiters: `<!-- cdocs rules vX.Y.Z hash=<sha256> - regenerate with /cdocs:init (use version from plugin.json) -->` (same shape as `.claude/rules/cdocs.md`; see Step 3 for hash computation)
   - This is idempotent: running init multiple times updates the content between delimiters without duplication.

## README Templates

### devlogs/README.md
```
# Development Logs

Detailed logs of development work.
See `/cdocs:devlog` for complete authoring guidelines.

**Naming:** `YYYY-MM-DD-feature-name.md`

**Key sections:** Objective, Plan, Implementation Notes, Changes Made, Verification.
```

### proposals/README.md
```
# Proposals

Design and solution proposals.
See `/cdocs:propose` for complete authoring guidelines.
See `/cdocs:rfp` to scaffold a lightweight request-for-proposal stub.

**Naming:** `YYYY-MM-DD-topic.md`

**Full proposals** — BLUF, Objective, Background, Proposed Solution, Design Decisions, Edge Cases, Phases.
**RFP stubs** (`status: request_for_proposal`) — BLUF, Objective, Scope, Open Questions. Elaborate into a full proposal with `/cdocs:propose path/to/stub.md`.
```

### reviews/README.md
```
# Reviews

Document reviews with structured findings and verdicts.
See `/cdocs:review` for complete authoring guidelines.

**Naming:** `YYYY-MM-DD-review-of-{doc-name}.md`

**Key sections:** Summary Assessment, Section-by-Section Findings, Verdict, Action Items.
```

### reports/README.md
```
# Reports

Findings, status updates, and analysis.
See `/cdocs:report` for complete authoring guidelines.

**Naming:** `YYYY-MM-DD-topic.md`

**Key sections:** BLUF, Context/Background, Key Findings, Analysis, Recommendations.
```

### _chat/README.md
```
# Chat Records

One file per Claude Code session name (`YYYY-MM-DD-<name>-<session_id>.md`, or `YYYY-MM-DD-<session_id>.md` while unnamed; `/rename` starts a new file), appended by the cdocs hooks and the top-level agent: each human prompt verbatim, the agent's note of each turn, and a sign-off per turn; do not edit them by hand. Records are committed with the devlogs that list them; to opt out, set `CDOCS_CHAT_RECORD=off` for a session, gitignore `cdocs/_chat/` (records then stay local to one checkout), or delete this directory to stop recording.
```

## Read-after-write directive

After all materialization steps complete, if `.claude/rules/cdocs.md` (or its OC/AGENTS.md counterparts) was actually rewritten during this run, the final line of the skill's response output must be the literal directive:

```
RULES_REFRESHED: .claude/rules/cdocs.md has been updated to version X.Y.Z. Read that file now to refresh your in-context rules. The version loaded at session start is stale and should be disregarded in favor of the freshly Read content.
```

Substitute the plugin version for `X.Y.Z`. The directive primes the next tool call to be a `Read` against the rewritten file so the session's working context reflects the current rules rather than the stale copy loaded into the system prompt at session start.

Idempotency: emit the directive only when the rule file content actually changed during the run. On a no-op re-run (file already matches plugin source), suppress it.

First-time init note: when there is no prior `.claude/rules/cdocs.md` to supersede (initial scaffolding), the directive is technically harmless (no cdocs rules were loaded at session start), but it is still emitted on the assumption that the freshly written rules are not yet in working context. The Read costs one tool call.

## Notes

- Do not overwrite existing files. If `cdocs/` already exists, only create missing subdirectories and files.
- Use `mkdir -p` for directory creation (idempotent).
- Check for existing content before writing READMEs to avoid clobbering user modifications.
