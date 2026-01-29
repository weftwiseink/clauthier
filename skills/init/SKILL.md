---
name: init
description: Scaffold CDocs directory structure in a project
argument-hint: "[--minimal]"
allowed-tools: Bash, Read, Write, Edit, Glob
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

3. Create or update `.claude/rules/cdocs.md` with core CDocs writing conventions.
   If `.claude/rules/` doesn't exist, create it.
   If the project has a CLAUDE.md, add a reference line: `@.claude/rules/cdocs.md`

4. If `$ARGUMENTS` includes `--minimal`, skip README generation and rules file creation.
   Only create the bare directory structure.

## README Templates

### devlogs/README.md
```
# Development Logs

Detailed logs of development work.
See `/cdocs:devlog` for complete authoring guidelines.

**Naming:** `YYYY-MM-DD_feature_name.md`

**Required sections:** Objective, Plan, Implementation Notes, Changes Made, Verification (mandatory).
```

### proposals/README.md
```
# Proposals

Design and solution proposals.
See `/cdocs:proposal` for complete authoring guidelines.

**Naming:** `YYYY-MM-DD_topic.md`

**Required sections:** BLUF, Objective, Background, Proposed Solution, Design Decisions, Edge Cases, Test Plan, Implementation Phases.
```

### reviews/README.md
```
# Reviews

Document reviews with structured findings and verdicts.
See `/cdocs:review` for complete authoring guidelines.

**Naming:** `YYYY-MM-DD_review_of_{doc_name}.md`

**Required sections:** Summary Assessment, Section-by-Section Findings, Verdict, Action Items.
```

### reports/README.md
```
# Reports

Findings, status updates, and analysis.
See `/cdocs:report` for complete authoring guidelines.

**Naming:** `YYYY-MM-DD_topic.md`

**Required sections:** BLUF, Scope, Findings/Analysis, Conclusions, Recommendations.
```

## Notes

- Do not overwrite existing files. If `cdocs/` already exists, only create missing subdirectories and files.
- Use `mkdir -p` for directory creation (idempotent).
- Check for existing content before writing READMEs to avoid clobbering user modifications.
