---
name: report
description: Generate a structured report (status, analysis, incident, audit, or retrospective)
argument-hint: "[topic]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# CDocs Report

Generate a structured report.

This is a **deliverable skill** -- the user explicitly requests a report.
Reports are audience-facing documents that summarize findings, status, or analysis.
They differ from devlogs: reports answer "what did we learn/accomplish?"; devlogs answer "how did we do the work?"

## Invocation

1. If `$ARGUMENTS` provides a topic, use it. Otherwise, prompt the user.
2. Determine the report subtype (see below). If ambiguous, ask the user.
3. Determine today's date.
4. Create `cdocs/reports/YYYY-MM-DD_topic.md` using the template below.
5. If `cdocs/reports/` doesn't exist, suggest running `/cdocs:init` first.

## Report Subtypes

A single flexible template supports all subtypes.
Include type-specific optional sections as relevant.

| Subtype | When to Use | Key Focus |
|---------|-------------|-----------|
| **Status** | Regular cadence updates (weekly, sprint, milestone) | Accomplishments, blockers, next steps |
| **Investigation** | Technical feasibility, performance analysis, root cause | Findings, analysis, recommendations |
| **Incident** | After system failures or production issues | Timeline, impact, root cause, prevention |
| **Audit** | Code quality, dependency, compliance reviews | Scope, methodology, severity ratings |
| **Retrospective** | End of sprint, project, or work arc | What went well, what didn't, improvements |

## Template

Use the template in `template.md` alongside this skill file.
Fill in:
- `first_authored.by` with the current model name or `@username`.
- `first_authored.at` with the current timestamp including timezone.
- `task_list` with the relevant workstream path.
- `type: report`, `state: live`, `status: wip`.
- Tags relevant to the report, including the subtype (e.g., `status`, `investigation`, `incident`).

## Required Sections (All Subtypes)

- **BLUF** -- 2-4 sentences: what, why, key finding, main recommendation.
- **Context / Background** -- What prompted this report, relevant history.
- **Key Findings** -- Bulleted discoveries, data, observations.
- **Analysis** -- Interpretation of findings, implications.
- **Recommendations** -- Prioritized action items with owners where applicable.

## Optional Sections (By Subtype)

### Status Reports
- **Accomplishments this period**
- **Blockers / Risks**
- **Plan for next period**
- **Metrics / KPIs**

### Investigation / Analysis Reports
- **Methodology** -- How the investigation was conducted.
- **Data** -- Raw data, measurements, benchmarks.
- **Alternatives considered**

### Incident Reports
- **Timeline of events** -- Chronological sequence.
- **Impact assessment** -- Users affected, duration, severity.
- **Root cause**
- **Preventive measures** -- What changes prevent recurrence.

### Audit Reports
- **Scope and methodology**
- **Compliance checklist**
- **Severity ratings** for findings.
- **Remediation deadlines**

### Retrospectives
- **What went well**
- **What didn't go well**
- **Action items for improvement**

## Reports vs. Devlogs

| Aspect | Report | Devlog |
|--------|--------|--------|
| Audience | Stakeholders, cross-team, future self | Implementers, handoff agents |
| Polish | Edited, conclusions-focused | Stream-of-consciousness during work |
| Focus | What was learned/accomplished | How the work was done |
| Format | Skimmable (BLUF, bullets) | Chronological narrative |
| Lifecycle | Archived as reference | Living document during task |
