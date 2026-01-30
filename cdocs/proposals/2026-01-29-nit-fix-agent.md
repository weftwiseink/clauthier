---
first_authored:
  by: "@claude-opus-4-5-20251101"
  at: 2026-01-29T16:30:00-08:00
task_list: cdocs/nit-fix-v2
type: proposal
state: live
status: implementation_ready
last_reviewed:
  status: accepted
  by: "@claude-sonnet-4-20250514"
  at: 2026-01-30T09:30:00-08:00
  round: 3
tags: [claude_skills, writing_conventions, subagent_patterns, plugin_idioms]
---

# Nit Fix Agent

> BLUF(mjr/cdocs/nit-fix-v2): A formal CDocs agent (`plugins/cdocs/agents/nit-fix.md`) that reads multiple rule files from `plugins/cdocs/rules/` at runtime and enforces conventions against target documents, applying mechanical fixes via Edit and reporting judgment-required violations.
> Uses the v2 agent architecture: tool allowlist (`Read, Glob, Grep, Edit`), read-at-runtime rules (no hardcoded conventions), and a thin dispatcher skill for orchestration.
> The multi-rule design loads all `rules/*.md` files at startup, enabling modular conventions (e.g., `writing-conventions.md`, `use-mermaid-diagrams.md`) that are independently authored and enforced.
> Supersedes `cdocs/proposals/2026-01-29-nit-fix-skill.md` (status: evolved).

## Objective

CDocs writing conventions (`rules/writing-conventions.md`) are easy to violate and tedious to enforce manually.
Convention violations accumulate during authoring because the authoring agent focuses on content, not formatting.

The v2 agent architecture (established by `cdocs/proposals/2026-01-29-triage-v2-agents-and-automation.md`) provides the right abstraction: a formal agent definition with infrastructure-enforced tool restrictions, read-at-runtime rules, and a thin dispatcher skill.

The nit-fix agent reads all rule files from `plugins/cdocs/rules/` at startup and enforces them.
No conventions are hardcoded in the agent prompt.
Adding a new rule file (e.g., `rules/use-mermaid-diagrams.md`) or a new convention to an existing file extends enforcement automatically.

> NOTE(mjr/cdocs/nit-fix-v2): The multi-rule design is extensible toward project-configured rules from user projects and rules contributed by other plugins.
> See `cdocs/proposals/2026-01-30-nit-fix-project-rules.md` (RFP) for the follow-up scoping that work.
> This proposal covers the cdocs plugin's own rules; project-level extensibility is deferred.

## Background

### V2 agent architecture

The triage-v2 proposal established a pattern for CDocs subagents:

- **Agent definitions** in `plugins/cdocs/agents/`: markdown files with YAML frontmatter (`name`, `model`, `tools`, optionally `skills`).
- **Tool allowlists**: infrastructure-enforced. An agent with `tools: Read, Glob, Grep, Edit` cannot call Write or Bash.
- **Read-at-runtime**: agents read rule files at startup rather than having rules inlined in their prompts. Eliminates duplication, stays current automatically.
- **Skills preloading**: `skills` frontmatter field injects skill content at agent startup. Used when the agent needs a full methodology (e.g., reviewer preloads `cdocs:review`).
- **Thin dispatcher skills**: skills invoke agents and route results. No agent instructions in the skill.

Two agents exist:
- **Triage** (`agents/triage.md`): haiku, `Read/Glob/Grep/Edit`. Reads `frontmatter-spec.md`, applies mechanical frontmatter fixes, reports status/workflow recommendations.
- **Reviewer** (`agents/reviewer.md`): sonnet, `Read/Glob/Grep/Edit/Write`. Preloads `cdocs:review` skill. Reads rules at runtime. Writes review documents.

### What's missing

No agent enforces prose conventions.
Triage handles frontmatter only (explicitly: "Do not modify document body content: only edit YAML frontmatter").
The reviewer catches convention issues in reviews but is heavyweight and produces findings requiring author action.
Authors routinely violate sentence-per-line, callout attribution, and punctuation conventions.

### Prior art: v1 nit-fix proposal

`cdocs/proposals/2026-01-29-nit-fix-skill.md` (now `status: evolved`) proposed a haiku subagent spawned via Task tool from a skill-embedded prompt template.
The core design (rules-reading enforcement agent, mechanical/judgment boundary) requires Phase 0 validation with haiku before implementation.
The delivery mechanism (prompt template in a skill) is the wrong abstraction per v2 findings.

## Proposed Solution

### Agent definition

```yaml
---
name: nit-fix
model: haiku
description: Enforce writing conventions on cdocs documents
tools: Read, Glob, Grep, Edit
---
```

The agent body instructs nit-fix to:
1. Glob `plugins/cdocs/rules/*.md` to discover all rule files.
2. Read each rule file at startup.
3. For each convention found (across all rule files), classify it as mechanical (fixable without authorial intent) or judgment-required (detection only).
4. Read each target document.
5. Apply mechanical fixes via Edit.
6. Report judgment-required violations to the dispatcher.

No conventions are listed in the agent body.
The agent discovers and learns them from rule files at runtime.
Adding a new rule file to `plugins/cdocs/rules/` extends enforcement with no agent changes.

### Tool allowlist rationale

`Read, Glob, Grep, Edit`: identical to triage.

- **Read**: reads rules file and target documents.
- **Glob/Grep**: finds files in batch mode.
- **Edit**: applies mechanical fixes to document prose.
- **No Write**: nit-fix modifies existing documents, never creates new ones.
- **No Bash**: no command execution needed.

### Thin dispatcher skill

`skills/nit_fix/SKILL.md` handles orchestration:

1. Collect file paths from `$ARGUMENTS` or scan `cdocs/**/*.md`.
2. Invoke the nit-fix agent via Task tool with `subagent_type: "nit-fix"`.
3. Receive the report.
4. Present judgment-required violations to the caller for manual resolution.

The skill contains no agent instructions.

### Mechanical vs. judgment-required classification

The agent classifies conventions at runtime using a prompt-guided heuristic.
The agent body provides the classification principle (not the specific classifications):

> A convention is **mechanical** if the fix preserves meaning: the text says the same thing after the edit.
> A convention is **judgment-required** if fixing it requires understanding what the author meant: the fix could change meaning or requires choosing among alternatives.

The agent reads each `##` heading in `writing-conventions.md`, applies the principle, and decides per-convention.
This is a heuristic: haiku may misclassify edge cases.
The conservative default (Decision 5) mitigates this: when uncertain, report rather than fix.

> NOTE(mjr/cdocs/nit-fix-v2): Phase 0 validates that haiku can perform this classification correctly.
> If Phase 0 shows haiku misclassifying conventions (e.g., attempting to rewrite prose for brevity), the fallback is to add explicit `<!-- MECHANICAL -->` or `<!-- JUDGMENT -->` HTML comments to `writing-conventions.md`.
> This preserves the "no hardcoded rules" constraint while giving the agent clearer signals.

The expected classification for current conventions:

**Mechanical (fix directly):**
- **Sentence-per-line**: split multi-sentence lines. Fix preserves meaning.
- **Callout attribution**: add `(workstream)` to bare `NOTE:`, `TODO:`, `WARN:`. Fix preserves meaning.
- **Punctuation**: replace em-dashes with colons or spaced hyphens. Fix preserves meaning.
- **Emoji removal**: strip emojis from prose. Fix preserves meaning.

**Judgment-required (report only):**
- **History-agnostic framing**: keyword detection is mechanical, but rewriting the sentence requires understanding context. Fix could change meaning.
- **BLUF quality**: whether the BLUF matches the body requires comprehension. No mechanical fix possible.
- **Brevity**: whether content is verbose requires editorial judgment. Fix would change meaning.
- **Commentary decoupling**: whether prose should be a NOTE callout requires authorial intent. Fix could change meaning.
- **Critical analysis quality**: subjective assessment. No mechanical fix possible.
- **Diagram format**: detecting ASCII art is mechanical, converting to mermaid requires judgment. Reported as judgment-required with detection note.

### Protected zones

The agent must not modify content inside protected zones.
Detection is prompt-guided (not infrastructure-enforced), consistent with how triage handles its "do not modify document body" constraint.
If the agent modifies a protected zone, the blast radius is limited to Edit (no Write/Bash), and the error is visible in diffs.

**Zone detection logic (specified in the agent prompt):**

1. **YAML frontmatter**: the first block delimited by `---` on its own line at the very start of the file (line 1 must be `---`, the closing `---` ends the frontmatter). Triage's domain: nit-fix skips everything from line 1 to the closing `---` inclusive.
2. **Fenced code blocks**: lines starting with `` ``` `` (with optional language identifier). Everything between an opening `` ``` `` and the next `` ``` `` on its own line is protected. This covers standard fenced blocks, mermaid diagrams, and YAML examples.
3. **Indented code blocks**: lines indented 4+ spaces or 1+ tab that follow a blank line. These are uncommon in CDocs (fenced blocks are preferred) but the agent should not modify them.
4. **Inline code**: text between single backticks (`` ` ``). The agent should not modify text inside inline code spans.
5. **Tables**: lines starting with `|`. The agent should not reformat table content (sentence-per-line does not apply inside table cells).
6. **HTML comments**: `<!-- ... -->` blocks. These may contain metadata (like the proposed classification markup fallback) and should not be modified.

> NOTE(mjr/cdocs/nit-fix-v2): Nested code blocks (code blocks inside blockquotes) are rare in CDocs.
> The agent handles these by treating any line matching `` > ``` `` as a code block delimiter within a blockquote context.
> This is a best-effort heuristic, not a full markdown parser.

### Output format

```
NIT FIX REPORT
==============
Files processed: N
Rule files loaded: F
Conventions found: M
Mechanical fixes applied: K

FIXES APPLIED:
- <path>:
  [line N] <convention>: <description of fix>
  (or "no fixes needed")

JUDGMENT REQUIRED:
- <path>:
  [line N] <convention>: <violation description with context>
  (or "none")

CLEAN:
- <path>: no violations
```

## Important Design Decisions

### Decision 1: No hardcoded rules in the agent body

**Decision:** The agent prompt contains no specific conventions. It instructs the agent to read `rules/writing-conventions.md` and enforce what it finds.

**Why:** Adding a new convention to the rules file extends enforcement with no agent changes.
This is the explicit design constraint from the user, and it's architecturally correct: separating policy (the rules file) from mechanism (the agent).

### Decision 2: Formal agent, not skill-embedded prompt

**Decision:** Define nit-fix as `plugins/cdocs/agents/nit-fix.md` rather than a prompt template inside a skill.

**Why:** The v2 architecture established that agents own their prompts and skills own orchestration.
The v1 nit-fix proposal used the old pattern (skill containing a prompt template).
Using a formal agent definition provides infrastructure-enforced tool restrictions and follows the pattern established by triage and reviewer.

### Decision 3: Same tool profile as triage

**Decision:** `tools: Read, Glob, Grep, Edit`. No Write, no Bash.

**Why:** Nit-fix modifies existing document prose.
It never creates files (no Write) or runs commands (no Bash).
The tool surface matches triage: the same reasoning about blast radius applies.
Edit-only access means the worst case is an incorrect prose fix to an existing file, which is low-severity and visible in diffs.

### Decision 4: Separate agent from triage

**Decision:** Nit-fix is its own agent, not integrated into the triage agent.

**Why:**
- Different domains: triage handles frontmatter, nit-fix handles prose.
- Different rules files: triage reads `frontmatter-spec.md`, nit-fix reads `writing-conventions.md`.
- Different protected zones: triage edits only frontmatter and must not touch body content. Nit-fix edits only body content and must not touch frontmatter.
- Different invocation timing: triage runs end-of-turn (automatic). Nit-fix is primarily deliberate (author invokes before review) but can also be triggered by the triage dispatcher as part of the pre-review pipeline (see Story 4).
- Single responsibility per agent keeps each prompt focused and reduces the chance of haiku scope-creeping.

### Decision 5: Conservative mechanical fixes

**Decision:** When uncertain whether something is a violation, report it as judgment-required rather than fixing.

**Why:** False positive fixes (altering meaning while trying to fix formatting) are worse than false negative reports (missing a violation that a human can catch).
Haiku's judgment on boundary cases is less reliable than sonnet/opus.
The report format makes judgment-required violations easy for the caller to address.

### Decision 6: Multi-rule loading via glob discovery

**Decision:** The agent globs `plugins/cdocs/rules/*.md` at startup rather than reading a single hardcoded path.

**Why:** Modular rule files enable independent authoring and targeted enforcement.
A standalone rule like `use-mermaid-diagrams.md` (see `cdocs/proposals/2026-01-30-use-mermaid-diagrams.md`) provides detailed detection heuristics and classification guidance that would clutter the monolithic `writing-conventions.md`.
Glob-based discovery means adding a new rule file extends enforcement with no agent changes.
This design is the foundation for future project-level and cross-plugin rule extensibility (see `cdocs/proposals/2026-01-30-nit-fix-project-rules.md` RFP).

The rule file format is simple: markdown with `##` headings per convention.
Rule files may include a `## Classification` section that explicitly marks conventions as mechanical or judgment-required, overriding the agent's heuristic classification.
Files without classification sections use the agent's default heuristic (Decision 1's principle).

## Stories

### Story 1: Pre-review nit-fix pass

Agent finishes writing a proposal.
Invokes `/cdocs:nit_fix cdocs/proposals/2026-01-29-foo.md`.
The dispatcher invokes the nit-fix agent.
The agent globs `rules/*.md`, reads `writing-conventions.md` and `use-mermaid-diagrams.md`, reads the proposal, finds 3 multi-sentence lines, 1 bare `TODO:`, and 2 em-dashes.
Applies 6 mechanical fixes.
Reports 1 history-agnostic framing violation ("previously, this was handled by...").
The dispatcher presents the judgment-required violation.
The author rewrites the sentence, then marks `review_ready`.

### Story 2: New convention auto-enforcement

A new convention is added to `writing-conventions.md`: "Avoid passive voice in BLUFs."
The next nit-fix invocation reads the updated file.
The agent classifies this as judgment-required (rewriting passive to active requires understanding meaning).
It flags passive-voice BLUFs in its report.
No agent definition changes required.

### Story 2b: New rule file auto-discovery

A new rule file `plugins/cdocs/rules/use-mermaid-diagrams.md` is added to the rules directory.
The next nit-fix invocation globs `rules/*.md` and discovers it alongside `writing-conventions.md`.
The agent reads both files, finds the Mermaid convention with its detection heuristics and explicit `## Classification` section marking it as judgment-required.
When processing a document containing an ASCII box diagram, the agent reports it as a judgment-required violation with detection context (box-drawing characters, line count).
No agent definition changes required: glob discovery handles the new file automatically.

### Story 3: Batch mode across all cdocs

User invokes `/cdocs:nit_fix` without arguments.
The dispatcher globs `cdocs/**/*.md` and passes all paths to the agent.
The agent produces a consolidated report: fixes applied per file, judgment-required violations grouped by convention.

### Story 4: Nit-fix + triage + review pipeline

The workflow: author -> nit-fix -> triage -> review.
Nit-fix cleans up prose conventions.
Triage validates frontmatter and recommends `review_ready`.
The dispatcher updates status and triggers the reviewer agent.
The reviewer sees a clean document and focuses on substance.

## Edge Cases

### 1. Nit-fix edits wrong files

Two-layer mitigation (same as triage):
- **Tool allowlist** (infrastructure): no Write (cannot create files), no Bash (cannot run commands). Constrains the blast radius to Edit on existing files.
- **Prompt guidance** (behavioral): "Edit ONLY the files listed in your Task prompt."

If haiku violates the prompt, the worst case is a mechanical prose fix (punctuation, line split) on an untargeted cdocs file.
This is low-severity: visible in diffs, easily reverted, and the existing PostToolUse hook validates frontmatter after any edit.

### 2. Sentence splitting in ambiguous contexts

Abbreviations ("e.g.", "i.e.", "Dr."), URLs, and inline code can contain periods that aren't sentence boundaries.

The agent prompt specifies sentence boundary detection rules:
- A sentence boundary is: period (or `!` or `?`) followed by a space followed by a capital letter.
- **Skip if**: the period follows a known abbreviation (`e.g.`, `i.e.`, `etc.`, `vs.`, `Dr.`, `Mr.`, `Mrs.`, `St.`, `No.`, `Vol.`).
- **Skip if**: the period is inside inline code (between backticks).
- **Skip if**: the period is inside a URL (preceded by `://` or followed by a TLD-like pattern).
- **Skip if**: the line is inside a protected zone (code block, table, frontmatter).
- **When uncertain**: report as judgment-required rather than splitting.

Expected behavior examples:
- `"This is wrong. This should split."` -> two lines.
- `"Use e.g. this pattern."` -> no split (abbreviation).
- `"See https://example.com. Then do this."` -> split after URL period (the period after `.com` ends the URL, the next period + space + capital is a boundary). This is a tricky case: if Phase 0 shows haiku mishandling it, the agent can report URL-adjacent splits as judgment-required.

### 3. Callout attribution inference

Bare `NOTE:` becomes `NOTE(cdocs/nit-fix-v2):` using the document's `task_list` value.
If `task_list` is missing, the agent reports the violation instead of guessing.

### 4. Frontmatter/body boundary

The agent must not edit YAML frontmatter (triage's domain).
The agent prompt explicitly excludes content between `---` delimiters at the start of the file (see Protected Zones detection logic).
If the agent edits frontmatter anyway:
- The tool allowlist constrains it to Edit (no destructive actions).
- The existing global PostToolUse hook (`hooks/cdocs-validate-frontmatter.sh`) validates frontmatter field presence after every Edit call. It checks that required fields exist, not that their values are semantically correct.
- Nit-fix prose changes (punctuation, line splits) applied to frontmatter YAML would likely break parsing, which the hook would catch immediately.

### 5. Code blocks containing prose-like content

A code block might contain example text with em-dashes or multi-sentence lines.
The agent skips all content between `` ``` `` delimiters.
This is enforced by the protected zone detection logic, not by per-convention judgment.
The agent's classification step (mechanical vs. judgment-required) operates only on conventions.
Protected zone skipping operates on document structure and is applied before convention checking: the agent identifies protected zones first, then only checks non-protected prose against conventions.

### 6. Protected zone detection failures

The agent might fail to detect a code block or frontmatter boundary (e.g., unusual indentation, blockquote-nested fenced blocks).
Mitigation: the agent's protected zone detection is prompt-guided heuristics, not a full markdown parser.
The blast radius of a detection failure is a mechanical prose fix applied inside a code block (e.g., splitting a line or changing punctuation in example text).
This is low-severity and visible in diffs.
Phase 0 should include a test document with nested code blocks, indented code, and blockquote-nested fences to validate detection accuracy.

## Test Plan

### Phase 0 validation tests

These tests validate the core design assumption before implementation begins.
Run with a haiku agent using `tools: Read, Edit` and the proposed agent prompt.

1. **Convention classification**: provide haiku with `writing-conventions.md` and ask it to classify each convention as mechanical or judgment-required using the principle in the agent prompt. **Expected**: mechanical = sentence-per-line, callout attribution, punctuation, emoji removal. Judgment-required = history-agnostic framing, BLUF quality, brevity, commentary decoupling, critical analysis, diagram format. **Failure mode**: haiku classifies brevity or commentary decoupling as mechanical (would attempt prose rewriting).
2. **Mechanical fix application**: provide a test document with 1 multi-sentence line, 1 bare `NOTE:`, 1 em-dash. Ask haiku to apply mechanical fixes. **Expected**: line split, attribution added, em-dash replaced. Document meaning unchanged. **Failure mode**: haiku modifies content inside a code block, rewrites prose beyond the fix, or changes meaning.
3. **Judgment-required reporting**: provide a test document with "previously, this was handled by..." and an ASCII diagram. Ask haiku to report violations without fixing. **Expected**: two judgment-required items in the report, zero edits. **Failure mode**: haiku rewrites the sentence or converts the diagram.
4. **Protected zone respect**: provide a test document with an em-dash inside a code block, a multi-sentence line in a table, and a bare `NOTE:` inside frontmatter. Ask haiku to process it. **Expected**: zero fixes (all violations are inside protected zones). **Failure mode**: haiku edits the code block, table, or frontmatter.

If Phase 0 tests 1-4 pass, proceed to Phase 1 implementation.
If test 1 fails (misclassification), add explicit `<!-- MECHANICAL -->` / `<!-- JUDGMENT -->` markup to `writing-conventions.md` and re-test.
If tests 2-4 fail, evaluate whether prompt refinement can address the failure or whether a higher-tier model is needed.

### Implementation tests

5. **Agent registration**: create `agents/nit-fix.md`, verify it's available as `subagent_type: "nit-fix"`.
6. **Tool restriction**: invoke the agent, confirm Write and Bash are unavailable (infrastructure-enforced).
7. **Rules reading**: verify the agent reads `writing-conventions.md` before processing documents (first tool call should be Read on the rules file).
8. **Mechanical fix accuracy**: test document with known violations. Input: `"This is sentence one. This is sentence two."` on one line, `NOTE: something important`, `content — with em-dash`. Expected output: two lines for sentence split, `NOTE(cdocs/test):` with attribution, `content: with em-dash` replaced. Ground truth: compare output to hand-edited expected file.
9. **Judgment-required detection**: test document with `"Previously, this was handled by a script."` and a 10-line ASCII box diagram. Expected: report lists both as judgment-required, zero edits to those lines.
10. **Protected zones**: test document with violations inside each zone type (frontmatter, fenced code, indented code, inline code, table, HTML comment). Expected: zero modifications to protected content. Verify by diffing the file before and after.
11. **Conservative splitting**: test cases:
    - `"Use e.g. this approach. Then verify."` -> no split at `e.g.`, split at `approach.` (expected: 1 split).
    - `"See \`foo.Bar\` for details. It works."` -> no split inside backticks, split at `details.` (expected: 1 split).
    - `"Visit https://example.com. Then continue."` -> split after URL (expected: 1 split).
12. **Batch mode**: invoke without arguments, verify all `cdocs/**/*.md` files are processed.
13. **Rules evolution**: add `## Test Convention\nAlways capitalize "cdocs" as "CDocs".` to rules file, invoke nit-fix, verify it classifies as mechanical and fixes lowercase "cdocs" instances in prose. Remove the test convention after.
14. **Pipeline**: author -> nit-fix -> triage -> review end-to-end. Verify each step produces expected output.

## Implementation Phases

### Phase 0: Validate core design assumption

Validate that haiku can read `writing-conventions.md` and correctly classify conventions as mechanical vs. judgment-required, apply mechanical fixes, and respect protected zones.

1. Run Phase 0 validation tests 1-4 from the Test Plan.
2. If classification test fails, add explicit markup to `writing-conventions.md` and re-test.
3. Document results in a devlog.

**Success criteria:** haiku correctly classifies all 11 conventions, applies mechanical fixes without collateral damage, and respects all protected zone types.
**Failure path:** if prompt refinement cannot achieve correct classification, evaluate `<!-- MECHANICAL -->` markup in the rules file or escalate to sonnet model.

### Phase 1: Agent definition

1. Create `plugins/cdocs/agents/nit-fix.md` with `model: haiku`, `tools: Read, Glob, Grep, Edit`.
2. Write the agent body per Appendix A (refined based on Phase 0 findings).
3. Test: invoke via Task tool, verify agent reads `writing-conventions.md` and produces a structured report.

**Success criteria:** agent reads rules at runtime, applies mechanical fixes, reports judgment-required violations. Implementation tests 5-11 pass.

### Phase 2: Dispatcher skill

1. Create `plugins/cdocs/skills/nit_fix/SKILL.md` as a thin dispatcher.
2. Orchestration: collect paths, invoke agent, present results.
3. Test: invoke `/cdocs:nit_fix` end-to-end.

**Success criteria:** skill invokes agent and surfaces results to the caller. Implementation test 12 passes.

### Phase 3: Workflow integration

1. Add "Pre-Review Nit Fix" pattern to `rules/workflow-patterns.md`.
2. Document the author -> nit-fix -> triage -> review pipeline.
3. Test end-to-end pipeline (implementation test 14).

**Success criteria:** nit-fix is integrated into the documented workflow.

## Appendix A: Agent Body (Draft)

This is the proposed content for `plugins/cdocs/agents/nit-fix.md` (markdown body below the YAML frontmatter).
The final version may be refined based on Phase 0 findings.

````markdown
# CDocs Nit Fix Agent

You enforce writing conventions on cdocs documents.
You are a "rules stickler": you read rule files to learn what to enforce, then check documents against those rules.
You do NOT have hardcoded knowledge of the conventions.

## Startup

Before processing any documents, discover and read all rule files:

1. Use the Glob tool to find all files matching `plugins/cdocs/rules/*.md`.
2. Read each discovered rule file using the Read tool.
3. Each rule file contains one or more conventions organized under `##` headings.
4. Aggregate all conventions from all rule files into your working set.

These files are the source of truth for all conventions you enforce.
Adding a new rule file to `plugins/cdocs/rules/` extends your enforcement surface with no prompt changes.

## Input

Your Task prompt provides a list of file paths to check.
Edit ONLY the files listed in your Task prompt. Do not edit any other files.

## Classification Principle

For each convention (identified by `##` headings across all rule files), classify it:

- **MECHANICAL**: the fix preserves meaning. The text says the same thing after the edit.
  Examples: splitting a line at a sentence boundary, adding callout attribution syntax, replacing punctuation, removing emojis.
- **JUDGMENT-REQUIRED**: fixing requires understanding what the author meant. The fix could change meaning or requires choosing among alternatives.
  Examples: rewriting for history-agnostic framing, improving brevity, decoupling commentary, improving critical analysis.

## Protected Zones

Identify and skip these zones before checking conventions.
Do NOT modify any content inside protected zones.

1. **YAML frontmatter**: the block between `---` on line 1 and the next `---` on its own line. Skip entirely.
2. **Fenced code blocks**: everything between a line starting with ` ``` ` and the next line starting with ` ``` `. Skip entirely.
3. **Indented code blocks**: lines indented 4+ spaces following a blank line. Skip.
4. **Inline code**: text between single backticks. Do not modify text inside backticks.
5. **Tables**: lines starting with `|`. Do not modify.
6. **HTML comments**: `<!-- ... -->` blocks. Do not modify.

## Processing Steps

For each target file:

1. Read the file completely.
2. Identify all protected zones.
3. For non-protected prose, check each MECHANICAL convention:
   a. **Sentence-per-line**: split lines containing multiple sentences. A sentence boundary is a period, `!`, or `?` followed by a space and a capital letter. Skip if the period follows a known abbreviation (e.g., i.e., etc., vs., Dr., Mr., Mrs., St., No., Vol.) or is inside inline code or a URL.
   b. **Callout attribution**: find bare `NOTE:`, `TODO:`, `WARN:` without parenthetical attribution. Add `(task_list_value)` using the document's frontmatter `task_list` field. If `task_list` is missing, report instead of fixing.
   c. **Punctuation**: replace em-dashes (`—` or ` -- `) with colons or spaced hyphens (` - `).
   d. **Emoji removal**: remove emoji characters from prose.
   e. Apply each fix via the Edit tool. Record in your report.
4. For non-protected prose, check each JUDGMENT-REQUIRED convention:
   a. Report likely violations with line numbers and surrounding context.
   b. Do NOT apply any fixes.

## Output Format

Return EXACTLY this structure:

NIT FIX REPORT
==============
Files processed: N
Rule files loaded: F
Conventions found: M
Mechanical fixes applied: K

FIXES APPLIED:
- <path>:
  [line N] <convention>: <description of fix>
  (or "no fixes needed")

JUDGMENT REQUIRED:
- <path>:
  [line N] <convention>: <violation description with context>
  (or "none")

CLEAN:
- <path>: no violations

Use repo-root-relative paths. Do not editorialize.

## Constraints

- Edit ONLY the files listed in your Task prompt.
- Do not create new files.
- Do not modify protected zones (frontmatter, code blocks, inline code, tables, HTML comments).
- When uncertain whether something is a violation, report it as judgment-required rather than fixing.
````
