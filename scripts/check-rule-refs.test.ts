/**
 * check-rule-refs.test.ts — Rule references in shipped cdocs content resolve
 * in every delivery form. Run via `npm run test:rules`.
 *
 * Assertions over plugins/cdocs/rules/ and the scanned content
 * (plugins/cdocs/{rules,skills,agents}/**\/*.md minus skills/init/SKILL.md):
 *   1. rule invariants   2. resolution   3. no filename references
 *   4. no omitClaudeMd   5. extractor fixtures
 *   6. every `/cdocs:<name>` resolves to a skill or agent (own file list)
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  parseRules,
  findReferences,
  findFilenameRefs,
  resolve,
  agentsBlock,
  sourceRules,
  ruleFiles,
  ruleInvariantProblems,
  resolutionProblems,
  filenameProblems,
  omitClaudeMdProblems,
  findSkillRefs,
  skillRefProblemsIn,
  skillRefProblems,
  skillRefFiles,
  skillNames,
  REPO_ROOT,
} from "./check-rule-refs.ts";
import { join } from "path";

function report(problems: string[]): string {
  return `\n${problems.join("\n")}\n`;
}

test("1. rule invariants: one unique CDocs H1 per rule, unique headings per rule", () => {
  assert.ok(ruleFiles().length > 0, "no rule files found");
  const problems = ruleInvariantProblems();
  assert.equal(problems.length, 0, report(problems));
});

test("2. resolution: every rule reference resolves against the source rule headings", () => {
  const problems = resolutionProblems(sourceRules());
  assert.equal(problems.length, 0, report(problems));
});

test("3. no filename references: scanned content names no rule file or rules/ path", () => {
  const problems = filenameProblems();
  assert.equal(problems.length, 0, report(problems));
});

test("4. no cdocs agent sets omitClaudeMd", () => {
  const problems = omitClaudeMdProblems();
  assert.equal(problems.length, 0, report(problems));
});

// 5. Extractor fixtures.

const FIXTURE_RULE = [
  "---",
  "paths:",
  '  - "cdocs/**/*.md"',
  "---",
  "",
  "# CDocs Overseer Rules",
  "",
  "## Stay thin",
  "",
  "```md",
  "## Fenced Heading",
  "# CDocs Fenced Title",
  "```",
  "",
  "### `chat_record` (optional, devlogs only)",
  "",
  "## Chat record",
].join("\n");

const rules = parseRules(FIXTURE_RULE);

function refsIn(line: string) {
  return findReferences("fixture.md", line);
}

function resolves(line: string): boolean {
  const refs = refsIn(line);
  assert.equal(refs.length, 1, `expected one reference in: ${line}`);
  return resolve(refs[0], rules) === null;
}

test("5a. parseRules indexes the H1 and headings, skipping fenced code and frontmatter", () => {
  assert.deepEqual(rules, [
    { title: "CDocs Overseer Rules", headings: ["Stay thin", "chat_record (optional, devlogs only)", "Chat record"] },
  ]);
});

test("5b. a misspelled title or section fails with the known names", () => {
  const badTitle = resolve(refsIn('see "CDocs Overseer Rule › Chat record"')[0], rules);
  assert.match(badTitle ?? "", /unknown rule "CDocs Overseer Rule"; rules are: "CDocs Overseer Rules"/);
  const badSection = resolve(refsIn('see "CDocs Overseer Rules › Chat records"')[0], rules);
  assert.match(badSection ?? "", /no heading "Chat records"; its headings are: .*"Chat record"/);
});

test("5c. a heading inside a code fence is not indexed", () => {
  assert.equal(resolves('see "CDocs Overseer Rules › Fenced Heading"'), false);
  assert.equal(resolves('see "CDocs Fenced Title"'), false);
});

test("5d. curly quotes, the ` > ` separator, whole-rule refs, and backticked headings resolve", () => {
  assert.equal(resolves("per “CDocs Overseer Rules › Stay thin”"), true);
  assert.equal(resolves('per "CDocs Overseer Rules > Stay thin"'), true);
  assert.equal(resolves('follow "CDocs Overseer Rules".'), true);
  assert.equal(resolves('see "CDocs Overseer Rules › chat_record (optional, devlogs only)"'), true);
  assert.equal(resolves('see "CDocs Overseer Rules ›  `Chat record`"'), true);
});

test("5e. only quoted strings beginning `CDocs ` are references", () => {
  assert.deepEqual(refsIn('the "Chat record" section of CDocs Overseer Rules'), []);
  assert.equal(refsIn('"CDocs Writing Conventions" and "CDocs Overseer Rules"').length, 2);
});

test("5f. the AGENTS.md block and concatenated file parse to the same rules", () => {
  const body = "# CDocs Overseer Rules\n\n## Stay thin\n\n## Chat record\n";
  const block = agentsBlock(
    `# Project\n\n<!-- cdocs-rules-start -->\n<!-- cdocs rules v1 hash=x -->\n## CDocs Overseer Rules\n\n${body}\n## CDocs Writing Conventions\n\n# CDocs Writing Conventions\n\n## BLUF\n<!-- cdocs-rules-end -->\n`,
  );
  assert.ok(block);
  const concatenated = `<!-- cdocs rules v1 hash=x -->\n${body}\n# CDocs Writing Conventions\n\n## BLUF\n`;
  const expected = [
    { title: "CDocs Overseer Rules", headings: ["Stay thin", "Chat record"] },
    { title: "CDocs Writing Conventions", headings: ["BLUF"] },
  ];
  assert.deepEqual(parseRules(block), expected);
  assert.deepEqual(parseRules(concatenated), expected);
});

test("5g. filename references are found; the literal .claude/rules/cdocs.md is not", () => {
  const files = ["overseers.md", "workflow-patterns.md"];
  const hits = (line: string) => findFilenameRefs("f.md", line, files);
  assert.deepEqual(
    hits("per [`overseers.md`](../../rules/overseers.md)").map((h) => [h.matches, h.files]),
    [[["rules/overseers.md"], ["overseers.md"]]],
  );
  assert.equal(hits("see `rules/*.md`").length, 1);
  assert.equal(hits("see rules/deleted-rule.md").length, 1);
  assert.equal(hits("Glob `plugins/cdocs/rules/` first").length, 1);
  assert.equal(hits("written to `.claude/rules/cdocs.md`").length, 0);
  assert.equal(hits("written to `.claude/rules/other.md`").length, 1);
  assert.equal(hits("written to `.opencode/rules/cdocs.md`").length, 1);
  assert.equal(hits("copied to `.opencode/rules/cdocs/overseers-x.md`").length, 0);
  assert.equal(hits("my-overseers.md and overseers.mdx").length, 0);
});

// 6. Skill references: every `/cdocs:<name>` resolves to a skill or an agent.

test("6. skill references: every /cdocs:<name> in checked files resolves to a skill or agent", () => {
  const problems = skillRefProblems();
  assert.equal(problems.length, 0, report(problems));
});

const NAMES = new Set(["oversee-many", "iterate", "bash-runner"]);

function skillProblems(text: string, path = "fixture.md"): string[] {
  return skillRefProblemsIn([[path, text]], NAMES);
}

test("6a. a /cdocs:<name> missing from the skill set fails, naming the file and line", () => {
  const problems = skillProblems("intro\nrun `/cdocs:oversee resume` to continue");
  assert.equal(problems.length, 1);
  assert.match(problems[0], /^fixture\.md:2: \/cdocs:oversee: no skill or agent named "oversee"/);
});

test("6b. an existing skill name resolves, without partial matches", () => {
  assert.deepEqual(skillProblems("run `/cdocs:oversee-many resume`."), []);
  assert.deepEqual(findSkillRefs("f.md", "/cdocs:oversee-many").map((r) => r.name), ["oversee-many"]);
});

test("6c. an agent name resolves through agents/", () => {
  assert.deepEqual(skillProblems("use `/cdocs:bash-runner` for verbose commands"), []);
  assert.ok(skillNames().has("bash-runner"), "real tree: bash-runner agent not indexed");
  assert.ok(skillNames().has("iterate"), "real tree: iterate skill not indexed");
});

test("6d. placeholders /cdocs:<type> and /cdocs:* yield no references", () => {
  assert.deepEqual(findSkillRefs("f.md", "`/cdocs:<type>` and `/cdocs:*` and /cdocs: alone"), []);
});

test("6e. a reference inside fenced code is checked", () => {
  const problems = skillProblems("```\n/cdocs:oversee my-arc\n```\n");
  assert.equal(problems.length, 1);
  assert.match(problems[0], /^fixture\.md:2: /);
});

test("6f. the check's file list includes init/SKILL.md and the top-level docs", () => {
  const files = skillRefFiles();
  for (const f of [
    join("plugins", "cdocs", "skills", "init", "SKILL.md"),
    join("plugins", "cdocs", "README.md"),
    join("plugins", "cdocs", "AGENTS.md"),
    join("plugins", "cdocs", "bin", "README.md"),
    "CLAUDE.md",
    "README.md",
  ]) {
    assert.ok(files.includes(join(REPO_ROOT, f)), `skill-ref file list lacks ${f}`);
  }
  assert.ok(files.some((f) => f.endsWith(join("rules", "writing-conventions.md"))), "rules not in file list");
  assert.ok(files.some((f) => f.endsWith(join("agents", "implementer.md"))), "agents not in file list");
});
