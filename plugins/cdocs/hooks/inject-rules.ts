#!/usr/bin/env -S npx tsx
import { readdirSync, readFileSync, existsSync } from 'fs';
import { join, basename } from 'path';

const RULES_DIR = join(process.env.CLAUDE_PLUGIN_ROOT!, 'rules');

// Skip injection in source repo (rules already loaded via CLAUDE.md @-imports)
const projectClaudeMd = join(process.cwd(), 'CLAUDE.md');
if (existsSync(projectClaudeMd)) {
  const claudeMd = readFileSync(projectClaudeMd, 'utf-8');
  if (claudeMd.includes('@plugins/cdocs/rules/')) {
    process.exit(0);
  }
}

function stripFrontmatter(content: string): string {
  if (!content.startsWith('---')) return content;
  const closeIdx = content.indexOf('\n---', 3);
  if (closeIdx === -1) return content;
  const bodyStart = content.indexOf('\n', closeIdx + 4);
  if (bodyStart === -1) return '';
  return content.slice(bodyStart + 1);
}

let context = '';

const files = readdirSync(RULES_DIR).filter(f => f.endsWith('.md'));
for (const file of files) {
  const filePath = join(RULES_DIR, file);
  const raw = readFileSync(filePath, 'utf-8');
  const body = stripFrontmatter(raw);
  const name = basename(file, '.md');
  context += `\n\n## [cdocs rule: ${name}]\n\n${body}\n`;
}

if (context) {
  const output = {
    hookSpecificOutput: {
      hookEventName: 'SessionStart',
      additionalContext: context,
    },
  };
  console.log(JSON.stringify(output));
}
