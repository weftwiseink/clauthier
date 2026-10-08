/**
 * check-rule-refs.ts — Rule reference checker for shipped cdocs content.
 *
 * Shipped content (rules, skills, skill templates, agents) refers to a rule by
 * its heading, never its filename: `"CDocs Workflow Patterns › Completeness"`.
 * Downstream, `/cdocs:init` concatenates the rules into `.claude/rules/cdocs.md`
 * and inlines them into `AGENTS.md`, so only the H1 survives every form.
 *
 * It also checks that every `/cdocs:<name>` resolves to a skill
 * (`skills/<name>/SKILL.md`) or an agent (`agents/<name>.md`), over its own
 * file list that includes the init skill and the top-level docs.
 *
 * Usage:
 *   node --import tsx scripts/check-rule-refs.ts           check the source tree
 *   node --import tsx scripts/check-rule-refs.ts --materialized <proj>  resolve against a
 *       project's `.claude/rules/cdocs.md` and `AGENTS.md` block
 *
 * The test suite is scripts/check-rule-refs.test.ts (`npm run test:rules`).
 */

import { readFileSync, readdirSync, statSync, existsSync } from "fs";
import { join, relative, resolve as resolvePath, dirname } from "path";

export const REPO_ROOT = resolvePath(dirname(new URL(import.meta.url).pathname), "..");
export const RULES_DIR = join(REPO_ROOT, "plugins", "cdocs", "rules");
const SCAN_DIRS = ["rules", "skills", "agents"].map((d) => join(REPO_ROOT, "plugins", "cdocs", d));
/** The materializer must name source rule files, so it is not scanned. */
const SCAN_EXCLUDE = new Set([join(REPO_ROOT, "plugins", "cdocs", "skills", "init", "SKILL.md")]);

export interface RuleDoc {
  title: string;
  headings: string[];
}

export interface Ref {
  path: string;
  line: number;
  text: string;
  title: string;
  section?: string;
}

export interface Hit {
  path: string;
  line: number;
  text: string;
  /** Every offending substring on the line. */
  matches: string[];
  /** The rule files the matches name, deduplicated (empty for globs and unknown names). */
  files: string[];
}

/** Comparison form: no backticks or `*`, whitespace collapsed. */
export function normalize(s: string): string {
  return s.replace(/[`*]/g, "").replace(/\s+/g, " ").trim();
}

/** Lines outside fenced code blocks, with 1-based line numbers. */
function unfencedLines(text: string): Array<[number, string]> {
  const out: Array<[number, string]> = [];
  let fence: string | null = null;
  text.split(/\r?\n/).forEach((line, i) => {
    const m = line.match(/^\s*(`{3,}|~{3,})/);
    if (m) {
      const marker = m[1];
      if (fence === null) fence = marker;
      else if (marker[0] === fence[0] && marker.length >= fence.length) fence = null;
      return;
    }
    if (fence === null) out.push([i + 1, line]);
  });
  return out;
}

/** Every H1 line outside code fences, as its text. */
export function h1s(text: string): string[] {
  return unfencedLines(text)
    .map(([, l]) => l.match(/^# (.+)$/))
    .filter((m): m is RegExpMatchArray => m !== null)
    .map((m) => normalize(m[1]));
}

/**
 * Split text at `# CDocs ` H1 lines into rules, each with its sub-headings.
 * `## CDocs ` lines are wrapper headings (the `AGENTS.md` block) and are ignored,
 * so a source rule, the concatenated `.claude/rules/cdocs.md`, and the
 * `AGENTS.md` block all parse the same way. Fenced code is skipped.
 */
export function parseRules(text: string): RuleDoc[] {
  const rules: RuleDoc[] = [];
  let current: RuleDoc | null = null;
  for (const [, line] of unfencedLines(text)) {
    const h1 = line.match(/^# (CDocs .+)$/);
    if (h1) {
      current = { title: normalize(h1[1]), headings: [] };
      rules.push(current);
      continue;
    }
    const h = line.match(/^#{2,6} (.+)$/);
    if (!h || /^## CDocs /.test(line)) continue;
    if (current) current.headings.push(normalize(h[1]));
  }
  return rules;
}

const SEPARATOR = /\s+(?:›|>)\s+/;
const QUOTED = /["“](CDocs [^"“”]*)["”]/g;

/** Every double-quoted (straight or curly) string beginning `CDocs `. */
export function findReferences(path: string, text: string): Ref[] {
  const refs: Ref[] = [];
  text.split(/\r?\n/).forEach((line, i) => {
    for (const m of line.matchAll(QUOTED)) {
      const parts = m[1].split(SEPARATOR);
      const title = normalize(parts[0]);
      const section = parts.length > 1 ? normalize(parts.slice(1).join(" › ")) : undefined;
      refs.push({ path, line: i + 1, text: m[0], title, ...(section !== undefined ? { section } : {}) });
    }
  });
  return refs;
}

function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Rule-filename references: a `<rule-file>.md` name, any `rules/<name>.md`
 * path (including globs and deleted rules), and any `plugins/cdocs/rules` path.
 * The literal `.claude/rules/cdocs.md`, the materialized file that exists
 * downstream, is not flagged. One hit per line.
 */
export function findFilenameRefs(path: string, text: string, ruleFiles: string[]): Hit[] {
  const hits: Hit[] = [];
  const nameRes = ruleFiles.map((f) => ({ file: f, re: new RegExp(`(?<![\\w.-])${escapeRegExp(f)}(?![\\w-])`) }));
  text.split(/\r?\n/).forEach((line, i) => {
    const matches: Array<{ match: string; file?: string }> = [];
    for (const { file, re } of nameRes) {
      const m = line.match(re);
      if (m) matches.push({ match: m[0], file });
    }
    for (const m of line.matchAll(/rules\/([\w*.-]+\.md)/g)) {
      const before = line.slice(0, m.index);
      if (/[\w-]$/.test(before) || (m[1] === "cdocs.md" && before.endsWith(".claude/"))) continue;
      matches.push({ match: m[0], file: ruleFiles.includes(m[1]) ? m[1] : undefined });
    }
    for (const m of line.matchAll(/plugins\/cdocs\/rules[\w\/*.-]*/g)) matches.push({ match: m[0] });
    if (matches.length === 0) return;
    // Drop matches contained in a longer match (`overseers.md` inside `rules/overseers.md`).
    const strs = [...new Set(matches.map((x) => x.match))];
    const kept = strs.filter((a) => !strs.some((b) => b !== a && b.includes(a)));
    const files = [...new Set(matches.flatMap((x) => (x.file ? [x.file] : [])))];
    hits.push({ path, line: i + 1, text: line.trim(), matches: kept, files });
  });
  return hits;
}

/** `null` when the reference resolves, else an error message with a fix. */
export function resolve(ref: Ref, rules: RuleDoc[]): string | null {
  const rule = rules.find((r) => r.title === ref.title);
  if (!rule) {
    return `unknown rule "${ref.title}"; rules are: ${rules.map((r) => `"${r.title}"`).join(", ")}`;
  }
  if (ref.section === undefined) return null;
  if (rule.headings.includes(ref.section)) return null;
  return `"${rule.title}" has no heading "${ref.section}"; its headings are: ${rule.headings.map((h) => `"${h}"`).join(", ")}`;
}

// ---------------------------------------------------------------------------
// Tree-level checks, shared by the test suite and the CLI.

export function ruleFiles(): string[] {
  return readdirSync(RULES_DIR).filter((f) => f.endsWith(".md")).sort();
}

/** Source rule file name to its H1 title. */
export function ruleTitles(): Map<string, string> {
  return new Map(ruleFiles().map((f) => [f, h1s(readFileSync(join(RULES_DIR, f), "utf-8"))[0] ?? f]));
}

export function sourceRules(): RuleDoc[] {
  return ruleFiles().flatMap((f) => parseRules(readFileSync(join(RULES_DIR, f), "utf-8")));
}

function walk(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const p = join(dir, name);
    return statSync(p).isDirectory() ? walk(p) : [p];
  });
}

/** Scanned content: `plugins/cdocs/{rules,skills,agents}/**\/*.md` minus the init skill. */
export function scannedFiles(): string[] {
  return SCAN_DIRS.flatMap(walk)
    .filter((p) => p.endsWith(".md") && !SCAN_EXCLUDE.has(p))
    .sort();
}

function rel(p: string): string {
  return relative(REPO_ROOT, p);
}

export function allReferences(): Ref[] {
  return scannedFiles().flatMap((p) => findReferences(rel(p), readFileSync(p, "utf-8")));
}

/** Assertion 1: one `CDocs ` H1 per rule, unique titles, unique headings per rule. */
export function ruleInvariantProblems(): string[] {
  const problems: string[] = [];
  const seen = new Map<string, string>();
  for (const f of ruleFiles()) {
    const text = readFileSync(join(RULES_DIR, f), "utf-8");
    const titles = h1s(text);
    if (titles.length !== 1) problems.push(`${f}: expected exactly one H1 outside code fences, found ${titles.length}`);
    for (const t of titles) {
      if (!t.startsWith("CDocs ")) problems.push(`${f}: H1 "${t}" does not begin "CDocs "`);
      if (seen.has(t)) problems.push(`${f}: H1 "${t}" duplicates ${seen.get(t)}`);
      seen.set(t, f);
    }
    for (const rule of parseRules(text)) {
      const dup = rule.headings.filter((h, i) => rule.headings.indexOf(h) !== i);
      for (const h of new Set(dup)) problems.push(`${f}: heading "${h}" is not unique within "${rule.title}"`);
    }
  }
  return problems;
}

/** Assertion 2: every reference resolves against `rules`. */
export function resolutionProblems(rules: RuleDoc[], refs: Ref[] = allReferences()): string[] {
  return refs.flatMap((r) => {
    const err = resolve(r, rules);
    return err ? [`${r.path}:${r.line}: ${r.text}: ${err}`] : [];
  });
}

/** Assertion 3: no rule-filename references in scanned content. */
export function filenameProblems(): string[] {
  const files = ruleFiles();
  const titles = ruleTitles();
  return scannedFiles().flatMap((p) =>
    findFilenameRefs(rel(p), readFileSync(p, "utf-8"), files).map((h) => {
      const fix = h.files.length
        ? h.files.map((f) => `use "${titles.get(f)}" for ${f}`).join("; ")
        : `name the rule by its H1, one of: ${[...titles.values()].map((t) => `"${t}"`).join(", ")}`;
      return `${h.path}:${h.line}: ${h.matches.map((m) => `\`${m}\``).join(", ")} in: ${h.text}\n    fix: ${fix}`;
    }),
  );
}

/** Assertion 4: no cdocs agent sets `omitClaudeMd`. */
export function omitClaudeMdProblems(): string[] {
  const dir = join(REPO_ROOT, "plugins", "cdocs", "agents");
  return walk(dir)
    .filter((p) => p.endsWith(".md") && /omitClaudeMd/.test(readFileSync(p, "utf-8")))
    .map((p) => `${rel(p)}: sets omitClaudeMd; cdocs agents rely on rules arriving with the CLAUDE.md hierarchy`);
}

// ---------------------------------------------------------------------------
// Skill references: `/cdocs:<name>` must name a skill or an agent.

const PLUGIN_DIR = join(REPO_ROOT, "plugins", "cdocs");
const SKILL_REF = /\/cdocs:([A-Za-z0-9][A-Za-z0-9_-]*)/g;

export interface SkillRef {
  path: string;
  line: number;
  name: string;
}

/** Every `/cdocs:<name>`, fenced code included; `/cdocs:<type>` and `/cdocs:*` do not match. */
export function findSkillRefs(path: string, text: string): SkillRef[] {
  const refs: SkillRef[] = [];
  text.split(/\r?\n/).forEach((line, i) => {
    for (const m of line.matchAll(SKILL_REF)) refs.push({ path, line: i + 1, name: m[1] });
  });
  return refs;
}

/** Skill directory names with a `SKILL.md`, plus agent file basenames. */
export function skillNames(): Set<string> {
  const skillsDir = join(PLUGIN_DIR, "skills");
  const skills = readdirSync(skillsDir).filter((d) => existsSync(join(skillsDir, d, "SKILL.md")));
  const agents = readdirSync(join(PLUGIN_DIR, "agents"))
    .filter((f) => f.endsWith(".md"))
    .map((f) => f.slice(0, -3));
  return new Set([...skills, ...agents]);
}

/**
 * The skill-reference check's own file list: every `.md` under
 * `plugins/cdocs/{rules,skills,agents}` (the init skill included), the plugin's
 * README, AGENTS.md and bin/README.md, and the repo's CLAUDE.md and README.md.
 */
export function skillRefFiles(): string[] {
  const docs = [
    join(PLUGIN_DIR, "README.md"),
    join(PLUGIN_DIR, "AGENTS.md"),
    join(PLUGIN_DIR, "bin", "README.md"),
    join(REPO_ROOT, "CLAUDE.md"),
    join(REPO_ROOT, "README.md"),
  ].filter((p) => existsSync(p));
  return [...SCAN_DIRS.flatMap(walk).filter((p) => p.endsWith(".md")), ...docs].sort();
}

/** Problems for `[path, text]` entries against a set of known names. */
export function skillRefProblemsIn(entries: Array<[string, string]>, names: Set<string>): string[] {
  const known = [...names].sort().join(", ");
  return entries.flatMap(([path, text]) =>
    findSkillRefs(path, text)
      .filter((r) => !names.has(r.name))
      .map((r) => `${r.path}:${r.line}: /cdocs:${r.name}: no skill or agent named "${r.name}"; known: ${known}`),
  );
}

/** Assertion 6: every `/cdocs:<name>` in the check's files resolves. */
export function skillRefProblems(): string[] {
  return skillRefProblemsIn(
    skillRefFiles().map((p) => [rel(p), readFileSync(p, "utf-8")]),
    skillNames(),
  );
}

/** The text between the `AGENTS.md` cdocs delimiters, or null. */
export function agentsBlock(text: string): string | null {
  const m = text.match(/<!-- cdocs-rules-start -->([\s\S]*?)<!-- cdocs-rules-end -->/);
  return m ? m[1] : null;
}

/**
 * Assertion 2 against a real project: resolve every scanned reference against
 * `.claude/rules/cdocs.md` and against the `AGENTS.md` cdocs block.
 */
export function materializedProblems(project: string): string[] {
  const problems: string[] = [];
  const refs = allReferences();
  const forms: Array<[string, string | null]> = [];
  const claudeRules = join(project, ".claude", "rules", "cdocs.md");
  forms.push([".claude/rules/cdocs.md", existsSync(claudeRules) ? readFileSync(claudeRules, "utf-8") : null]);
  const agents = join(project, "AGENTS.md");
  forms.push(["AGENTS.md cdocs block", existsSync(agents) ? agentsBlock(readFileSync(agents, "utf-8")) : null]);
  const expected = sourceRules().map((r) => r.title);
  for (const [name, text] of forms) {
    if (text === null) {
      problems.push(`${name}: missing`);
      continue;
    }
    const rules = parseRules(text);
    const titles = rules.map((r) => r.title);
    for (const t of expected) if (!titles.includes(t)) problems.push(`${name}: rule "${t}" not found`);
    problems.push(...resolutionProblems(rules, refs).map((p) => `${name}: ${p}`));
  }
  return problems;
}

function main(argv: string[]): number {
  let problems: string[];
  if (argv[0] === "--materialized") {
    if (!argv[1]) {
      console.error("usage: check-rule-refs.ts --materialized <project>");
      return 2;
    }
    problems = materializedProblems(resolvePath(argv[1]));
  } else {
    const rules = sourceRules();
    problems = [
      ...ruleInvariantProblems(),
      ...resolutionProblems(rules),
      ...filenameProblems(),
      ...omitClaudeMdProblems(),
      ...skillRefProblems(),
    ];
  }
  for (const p of problems) console.error(p);
  console.error(problems.length === 0 ? "rule references OK" : `${problems.length} rule reference problem(s)`);
  return problems.length === 0 ? 0 : 1;
}

if (process.argv[1] && resolvePath(process.argv[1]) === resolvePath(new URL(import.meta.url).pathname)) {
  process.exit(main(process.argv.slice(2)));
}
