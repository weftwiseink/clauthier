#!/usr/bin/env -S npx tsx
/**
 * build-opencode.ts — Convert CC-canonical plugin agents to OpenCode format.
 *
 * This script is the single build step for multi-target marketplace support.
 * It reads CC agent files from plugins/<name>/agents/, transforms frontmatter
 * to OC format, copies skills/rules into the output directory, copies
 * hand-written OC files (hooks, postinstall), and generates package.json
 * with version synced from plugin.json.
 *
 * Usage:
 *   npm run build:cdocs
 *   npx tsx scripts/build-opencode.ts [plugin-name]
 *
 * Output: build/<plugin-name>/opencode/
 *
 * The build/ directory is gitignored. Do not commit build output.
 */

import { readFileSync, writeFileSync, mkdirSync, readdirSync, existsSync, cpSync, rmSync } from "fs";
import { join, resolve, dirname } from "path";
import YAML from "yaml";

// ---------------------------------------------------------------------------
// Paths - resolved from repo root (one level up from scripts/)
// ---------------------------------------------------------------------------

const REPO_ROOT = resolve(dirname(new URL(import.meta.url).pathname), "..");
const pluginName = process.argv[2] || "cdocs";
const PLUGIN_ROOT = join(REPO_ROOT, "plugins", pluginName);

if (!existsSync(PLUGIN_ROOT)) {
  console.error(`build-opencode: Plugin directory not found: ${PLUGIN_ROOT}`);
  process.exit(1);
}

const AGENTS_DIR = join(PLUGIN_ROOT, "agents");
const SKILLS_DIR = join(PLUGIN_ROOT, "skills");
const RULES_DIR = join(PLUGIN_ROOT, "rules");
const PLUGIN_JSON = join(PLUGIN_ROOT, ".claude-plugin", "plugin.json");

// Hand-written OC files at their canonical source locations
const HOOKS_SRC = join(PLUGIN_ROOT, "hooks", "cdocs-hooks.ts");
const POSTINSTALL_SRC = join(PLUGIN_ROOT, "scripts", "postinstall.js");

// Output: build/<plugin>/opencode/
const OUTPUT_DIR = join(REPO_ROOT, "build", pluginName, "opencode");
const OUT_AGENTS = join(OUTPUT_DIR, "agents");
const OUT_SKILLS = join(OUTPUT_DIR, "skills");
const OUT_RULES = join(OUTPUT_DIR, "rules");
const OUT_PLUGINS = join(OUTPUT_DIR, "plugins");
const OUT_SCRIPTS = join(OUTPUT_DIR, "scripts");

// ---------------------------------------------------------------------------
// Model mapping: CC short alias -> OC full provider/model path
// ---------------------------------------------------------------------------

const MODEL_MAP: Record<string, string> = {
  haiku: "anthropic/claude-3-5-haiku-20241022",
  sonnet: "anthropic/claude-sonnet-4-20250514",
  opus: "anthropic/claude-opus-4-20250514",
};

// ---------------------------------------------------------------------------
// Tool mapping: CC tool name -> OC tool fields
// ---------------------------------------------------------------------------

interface OCToolConfig {
  read?: boolean;
  edit?: boolean;
  write?: boolean;
  bash?: boolean;
}

interface OCPermission {
  edit?: string;
  write?: string;
}

/**
 * Normalize CC `tools` to a list of names: a string splits on commas, a YAML
 * sequence is used as-is, and null/absent is an empty list (all tools).
 */
function normalizeTools(ccTools: unknown): string[] {
  let names: unknown[];
  if (ccTools === undefined || ccTools === null) {
    names = [];
  } else if (typeof ccTools === "string") {
    names = ccTools.split(",");
  } else if (Array.isArray(ccTools)) {
    names = ccTools;
  } else {
    console.warn(`  Warning: Unrecognized CC tools value ${JSON.stringify(ccTools)} — treating as all tools`);
    names = [];
  }
  return names.map((t) => String(t).trim()).filter((t) => t.length > 0);
}

function mapTools(toolNames: string[]): { tools: OCToolConfig; permission: OCPermission } {
  const tools: OCToolConfig = {
    read: false,
    edit: false,
    write: false,
    bash: false,
  };
  const permission: OCPermission = {};

  for (const tool of toolNames) {
    switch (tool) {
      case "Read":
        tools.read = true;
        break;
      case "Edit":
        tools.edit = true;
        permission.edit = "ask";
        break;
      case "Write":
        tools.write = true;
        permission.write = "ask";
        break;
      case "Bash":
        tools.bash = true;
        break;
      // Glob and Grep have no direct OC equivalent; always available
      case "Glob":
      case "Grep":
        break;
      default:
        console.warn(`  Warning: Unknown CC tool "${tool}" — skipping`);
    }
  }

  return { tools, permission };
}

// ---------------------------------------------------------------------------
// Frontmatter parsing (YAML, via the `yaml` package)
// ---------------------------------------------------------------------------

interface CCFrontmatter {
  name?: string;
  model?: string;
  description?: unknown;
  tools?: unknown;
  skills?: string[];
  [key: string]: unknown;
}

function parseFrontmatter(content: string): { frontmatter: CCFrontmatter; body: string } {
  const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) {
    throw new Error("No frontmatter found");
  }

  const parsed: unknown = YAML.parse(match[1]);
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Frontmatter is not a YAML mapping");
  }

  return { frontmatter: parsed as CCFrontmatter, body: match[2] };
}

// ---------------------------------------------------------------------------
// OC frontmatter generation
// ---------------------------------------------------------------------------

function generateOCFrontmatter(cc: CCFrontmatter): string {
  const oc: Record<string, unknown> = {};

  // description (String() only when present: String(undefined) would emit "undefined")
  if (cc.description !== undefined && cc.description !== null) {
    oc.description = String(cc.description);
  }

  // mode: subagent (all cdocs agents are subagents)
  oc.mode = "subagent";

  // model: expand short alias
  if (cc.model) {
    const fullModel = MODEL_MAP[cc.model] || cc.model;
    if (!MODEL_MAP[cc.model]) {
      console.warn(`  Warning: Unknown model alias "${cc.model}" — passing through as-is`);
    }
    oc.model = fullModel;
  }

  // tools: absent, empty, or "*" emits no tools/permission block, which OC
  // documents as all tools enabled (CC "*" = deliberately not narrowed).
  // An explicit list expands to a boolean object.
  const toolNames = normalizeTools(cc.tools);
  if (toolNames.length > 0 && !toolNames.includes("*")) {
    const { tools, permission } = mapTools(toolNames);
    oc.tools = tools;

    // permission block
    if (Object.keys(permission).length > 0) {
      oc.permission = permission;
    }
  }

  // Dropped fields: name (OC infers from filename), skills (OC has no equivalent)

  // lineWidth: 0 disables folding: single-line values stay on one line,
  // multi-line strings become `|` block scalars, unsafe values get quoted.
  return "---\n" + YAML.stringify(oc, { lineWidth: 0 }) + "---";
}

// ---------------------------------------------------------------------------
// Path rewriting in agent body content
// ---------------------------------------------------------------------------

function rewriteBodyPaths(body: string): { rewritten: string; warnings: string[] } {
  const warnings: string[] = [];
  let rewritten = body;

  // Rewrite absolute plugin paths to relative paths from agents/
  // e.g., plugins/cdocs/rules/frontmatter-spec.md -> ../rules/frontmatter-spec.md
  rewritten = rewritten.replace(
    /plugins\/cdocs\/(rules|skills)\//g,
    (_match, subdir) => {
      return `../${subdir}/`;
    }
  );

  // Warn on any remaining absolute-looking paths that reference plugins/
  const absolutePathMatches = rewritten.match(/plugins\/[^\s)]+/g);
  if (absolutePathMatches) {
    for (const p of absolutePathMatches) {
      warnings.push(`Unrewritten absolute path: ${p}`);
    }
  }

  return { rewritten, warnings };
}

// ---------------------------------------------------------------------------
// Convert a single agent file
// ---------------------------------------------------------------------------

function convertAgent(inputPath: string): string {
  const content = readFileSync(inputPath, "utf-8");
  const { frontmatter, body } = parseFrontmatter(content);

  const ocFrontmatter = generateOCFrontmatter(frontmatter);
  const { rewritten, warnings } = rewriteBodyPaths(body);

  for (const w of warnings) {
    console.warn(`  ${w}`);
  }

  return ocFrontmatter + "\n" + rewritten;
}

// ---------------------------------------------------------------------------
// Copy directory recursively (skills, rules)
// ---------------------------------------------------------------------------

function copyDir(src: string, dest: string): void {
  if (existsSync(dest)) {
    rmSync(dest, { recursive: true });
  }
  cpSync(src, dest, { recursive: true });
}

// ---------------------------------------------------------------------------
// Copy a single file to a destination directory
// ---------------------------------------------------------------------------

function copyFile(src: string, destDir: string, label: string): void {
  if (!existsSync(src)) {
    console.warn(`  Warning: ${label} not found at ${src} — skipping`);
    return;
  }
  mkdirSync(destDir, { recursive: true });
  const filename = src.split("/").pop()!;
  cpSync(src, join(destDir, filename));
  console.log(`  Copied ${label}: ${filename}`);
}

// ---------------------------------------------------------------------------
// Generate package.json
// ---------------------------------------------------------------------------

function generatePackageJson(version: string): object {
  return {
    name: "@weftwise/cdocs-opencode",
    version,
    description: "CDocs documentation framework for OpenCode",
    main: "plugins/cdocs-hooks.ts",
    files: [
      "agents/",
      "plugins/",
      "skills/",
      "rules/",
      "scripts/",
      "package.json",
    ],
    keywords: ["opencode", "plugin", "documentation", "cdocs"],
    license: "MIT",
    repository: {
      type: "git",
      url: "https://github.com/weftwiseink/clauthier",
    },
    scripts: {
      postinstall: "node scripts/postinstall.js",
    },
  };
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main(): void {
  console.log(`build-opencode: Starting CC-to-OC conversion for plugin "${pluginName}"...`);
  console.log(`  Repo root:   ${REPO_ROOT}`);
  console.log(`  Plugin root: ${PLUGIN_ROOT}`);
  console.log(`  Output dir:  ${OUTPUT_DIR}`);

  // Read plugin version
  const pluginJson = JSON.parse(readFileSync(PLUGIN_JSON, "utf-8"));
  const version: string = pluginJson.version || "0.0.0";
  console.log(`  Version:     ${version}`);

  // Clean the entire output directory for a fresh build
  if (existsSync(OUTPUT_DIR)) {
    console.log("\n  Cleaning previous build output...");
    rmSync(OUTPUT_DIR, { recursive: true });
  }

  // Create output directories
  for (const dir of [OUT_AGENTS, OUT_SKILLS, OUT_RULES, OUT_PLUGINS, OUT_SCRIPTS]) {
    mkdirSync(dir, { recursive: true });
  }

  // Convert agents
  const agentFiles = readdirSync(AGENTS_DIR).filter((f) => f.endsWith(".md"));
  console.log(`\n  Converting ${agentFiles.length} agents...`);
  const skipped: string[] = [];
  for (const file of agentFiles) {
    const inputPath = join(AGENTS_DIR, file);
    const outputPath = join(OUT_AGENTS, file);
    console.log(`    ${file}`);
    // CC may tolerate frontmatter strict YAML rejects: warn, skip this agent, keep building.
    let converted: string;
    try {
      converted = convertAgent(inputPath);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      console.warn(`  Warning: Skipping agent ${file}: frontmatter could not be parsed: ${message}`);
      skipped.push(file);
      continue;
    }
    writeFileSync(outputPath, converted);
  }

  // Copy skills and rules (bundled in npm package)
  console.log("\n  Copying skills...");
  copyDir(SKILLS_DIR, OUT_SKILLS);

  console.log("  Copying rules...");
  copyDir(RULES_DIR, OUT_RULES);

  // Copy hand-written OC files from canonical locations
  console.log("\n  Copying hand-written OC files...");
  copyFile(HOOKS_SRC, OUT_PLUGINS, "OC hooks plugin");
  copyFile(POSTINSTALL_SRC, OUT_SCRIPTS, "postinstall script");

  // Generate package.json (version synced from plugin.json)
  console.log("\n  Generating package.json...");
  const packageJson = generatePackageJson(version);
  writeFileSync(join(OUTPUT_DIR, "package.json"), JSON.stringify(packageJson, null, 2) + "\n");

  // Summary
  console.log(`\nbuild-opencode: Done.`);
  console.log(`  Agents converted: ${agentFiles.length - skipped.length}`);
  if (skipped.length > 0) {
    console.warn(`  Agents skipped (frontmatter parse errors): ${skipped.join(", ")}`);
  }
  console.log(`  Output: ${OUTPUT_DIR}`);
}

main();
