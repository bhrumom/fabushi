export interface McpSkillResourceDigest {
  uri: string;
  digest: string;
}

export interface McpSkillEntry {
  uri: string;
  frontmatter: Record<string, unknown>;
  resources?: McpSkillResourceDigest[];
}

export interface LoadedMcpSkill {
  identity: string;
  origin: string;
  uri: string;
  content: string;
  digest: string;
  entry: McpSkillEntry;
}

export interface SkillReadResult {
  text: string;
  mimeType?: string;
}

export interface LoadMcpSkillOptions {
  origin: string;
  entry: McpSkillEntry;
  readResource: (uri: string) => Promise<SkillReadResult>;
  maxBytes?: number;
  allowDynamic?: boolean;
}

const DEFAULT_MAX_SKILL_BYTES = 1024 * 1024;

export function mcpSkillIdentity(origin: string, uri: string): string {
  const cleanOrigin = origin.trim();
  const cleanUri = uri.trim();
  if (!cleanOrigin) throw new Error("MCP Skill origin is required");
  if (!cleanUri) throw new Error("MCP Skill URI is required");
  return `${cleanOrigin}::${cleanUri}`;
}

function parseSha256(value: string): string {
  const normalized = value.trim().toLowerCase();
  if (!/^sha256:[a-f0-9]{64}$/.test(normalized)) {
    throw new Error(`Unsupported MCP Skill digest: ${value}`);
  }
  return normalized.slice("sha256:".length);
}

async function sha256Hex(text: string): Promise<string> {
  if (!globalThis.crypto?.subtle) throw new Error("Web Crypto SHA-256 is unavailable");
  const bytes = new TextEncoder().encode(text);
  const digest = await globalThis.crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

export async function verifyMcpSkillResource(text: string, expectedDigest: string): Promise<void> {
  const expected = parseSha256(expectedDigest);
  const actual = await sha256Hex(text);
  if (actual !== expected) throw new Error("MCP Skill resource digest mismatch");
}

export async function loadMcpSkill(options: LoadMcpSkillOptions): Promise<LoadedMcpSkill> {
  const maxBytes = options.maxBytes ?? DEFAULT_MAX_SKILL_BYTES;
  if (!Number.isSafeInteger(maxBytes) || maxBytes <= 0) throw new Error("maxBytes must be a positive safe integer");

  const identity = mcpSkillIdentity(options.origin, options.entry.uri);
  const resources = options.entry.resources;
  if ((!resources || resources.length === 0) && !options.allowDynamic) {
    throw new Error("MCP Skill has no content-bound resource manifest");
  }

  const primary = resources?.find((resource) => resource.uri === options.entry.uri);
  if (resources && resources.length > 0 && !primary) {
    throw new Error("MCP Skill resource manifest does not contain its SKILL.md URI");
  }

  const loaded = await options.readResource(options.entry.uri);
  const byteLength = new TextEncoder().encode(loaded.text).byteLength;
  if (byteLength > maxBytes) throw new Error(`MCP Skill exceeds ${maxBytes} byte read limit`);
  if (primary) await verifyMcpSkillResource(loaded.text, primary.digest);

  return {
    identity,
    origin: options.origin,
    uri: options.entry.uri,
    content: loaded.text,
    digest: primary?.digest ?? "dynamic",
    entry: options.entry,
  };
}

export function assertMcpSkillSupportingResource(entry: McpSkillEntry, uri: string): McpSkillResourceDigest {
  const resource = entry.resources?.find((candidate) => candidate.uri === uri);
  if (!resource) throw new Error(`MCP Skill attempted to read an unlisted supporting resource: ${uri}`);
  return resource;
}
