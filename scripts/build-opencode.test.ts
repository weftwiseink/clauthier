/**
 * build-opencode.test.ts — Regression test for the CC-to-OC agent conversion.
 *
 * Reads the existing build output, so run it via `npm run test:opencode`
 * (which builds first). For every CC agent in plugins/cdocs/agents/, checks
 * the generated OC agent's frontmatter against the CC source.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync, existsSync } from "fs";
import { join, resolve, dirname } from "path";
import YAML from "yaml";

const REPO_ROOT = resolve(dirname(new URL(import.meta.url).pathname), "..");
const CC_AGENTS = join(REPO_ROOT, "plugins", "cdocs", "agents");
const OC_AGENTS = join(REPO_ROOT, "build", "cdocs", "opencode", "agents");

function frontmatter(path: string): Record<string, unknown> {
  const match = readFileSync(path, "utf-8").match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n/);
  assert.ok(match, `${path}: no frontmatter delimiters`);
  const parsed: unknown = YAML.parse(match[1]);
  assert.ok(parsed && typeof parsed === "object" && !Array.isArray(parsed), `${path}: frontmatter is not a mapping`);
  return parsed as Record<string, unknown>;
}

/** CC tools as a name list: comma string, YAML sequence, or absent (empty). */
function ccToolNames(tools: unknown): string[] {
  if (tools === undefined || tools === null) return [];
  const names: unknown[] = typeof tools === "string" ? tools.split(",") : Array.isArray(tools) ? tools : [];
  return names.map((t) => String(t).trim()).filter((t) => t.length > 0);
}

const agentFiles = readdirSync(CC_AGENTS).filter((f) => f.endsWith(".md"));

test("plugins/cdocs/agents has agents to check", () => {
  assert.ok(agentFiles.length > 0);
});

for (const file of agentFiles) {
  test(`OC agent ${file}`, () => {
    const ccPath = join(CC_AGENTS, file);
    const ocPath = join(OC_AGENTS, file);

    // 1. A generated OC file exists (catches an agent skipped on a parse error).
    assert.ok(existsSync(ocPath), `${ocPath} was not generated`);

    // 2. OC frontmatter parses, and mode is subagent.
    const cc = frontmatter(ccPath);
    const oc = frontmatter(ocPath);
    assert.equal(oc.mode, "subagent");

    // 3. description is a non-empty string equal to the CC description.
    assert.equal(typeof oc.description, "string", "OC description must be a string");
    assert.notEqual((oc.description as string).trim(), "", "OC description must be non-empty");
    assert.equal(oc.description, String(cc.description), "OC description must round-trip the CC description");

    // 4. No model key: OC subagents inherit the invoking agent's model.
    assert.ok(!("model" in oc), `unexpected model: ${JSON.stringify(oc.model)}`);

    // 5. Absent or "*" tools: no tools/permission block (OC default: all tools).
    //    Otherwise each mapped OC tool is enabled iff the CC list names it.
    const names = ccToolNames(cc.tools);
    if (names.length === 0 || names.includes("*")) {
      assert.ok(!("tools" in oc), `unexpected tools block: ${JSON.stringify(oc.tools)}`);
      assert.ok(!("permission" in oc), `unexpected permission block: ${JSON.stringify(oc.permission)}`);
    } else {
      const tools = oc.tools as Record<string, unknown> | undefined;
      assert.ok(tools && typeof tools === "object", "explicit CC tools list must produce an OC tools block");
      for (const [ocKey, ccName] of [["read", "Read"], ["edit", "Edit"], ["write", "Write"], ["bash", "Bash"]]) {
        assert.equal(tools[ocKey], names.includes(ccName), `tools.${ocKey} must be ${names.includes(ccName)}`);
      }
    }
  });
}
