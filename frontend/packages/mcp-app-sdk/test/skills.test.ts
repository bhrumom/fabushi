import assert from "node:assert/strict";
import crypto from "node:crypto";
import test from "node:test";

import {
  assertMcpSkillSupportingResource,
  loadMcpSkill,
  mcpSkillIdentity,
  verifyMcpSkillResource,
  type McpSkillEntry,
} from "../src/skills.ts";

function digest(text: string): string {
  return `sha256:${crypto.createHash("sha256").update(Buffer.from(text, "utf8")).digest("hex")}`;
}

const content = "---\nname: safe-run\ndescription: Safe run\n---\n\n# Safe run";
const entry: McpSkillEntry = {
  uri: "skill://fabushi/example/safe-run/SKILL.md",
  frontmatter: { name: "safe-run", description: "Safe run" },
  resources: [{ uri: "skill://fabushi/example/safe-run/SKILL.md", digest: digest(content) }],
};

test("Skill identity is scoped by MCP server origin", () => {
  assert.notEqual(
    mcpSkillIdentity("server-a", entry.uri),
    mcpSkillIdentity("server-b", entry.uri),
  );
});

test("loader reads Skill lazily and verifies the advertised digest", async () => {
  let reads = 0;
  const loaded = await loadMcpSkill({
    origin: "fabushi-miniapp:example",
    entry,
    readResource: async (uri) => {
      reads += 1;
      assert.equal(uri, entry.uri);
      return { text: content, mimeType: "text/markdown" };
    },
  });
  assert.equal(reads, 1);
  assert.equal(loaded.identity, `fabushi-miniapp:example::${entry.uri}`);
  assert.equal(loaded.content, content);
});

test("digest mismatch and unlisted supporting resources are rejected", async () => {
  await assert.rejects(
    verifyMcpSkillResource(content + " changed", entry.resources![0].digest),
    /digest mismatch/,
  );
  assert.throws(
    () => assertMcpSkillSupportingResource(entry, "skill://fabushi/example/safe-run/scripts/run.sh"),
    /unlisted supporting resource/,
  );
});

test("static content binding is required unless dynamic Skills are explicitly allowed", async () => {
  const dynamicEntry: McpSkillEntry = { uri: entry.uri, frontmatter: entry.frontmatter };
  await assert.rejects(
    loadMcpSkill({ origin: "server", entry: dynamicEntry, readResource: async () => ({ text: content }) }),
    /no content-bound resource manifest/,
  );
  const loaded = await loadMcpSkill({
    origin: "server",
    entry: dynamicEntry,
    allowDynamic: true,
    readResource: async () => ({ text: content }),
  });
  assert.equal(loaded.digest, "dynamic");
});
