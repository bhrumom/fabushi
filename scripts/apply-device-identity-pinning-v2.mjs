import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const remoteServerPath = resolve(process.cwd(), "chatgpt-vps-control/lib/fabushi-remote-mcp-server.js");
const persistedIdentityMarker = "// GBF-412 persisted identities";

function normalizePersistedIdentityAnchor() {
  const source = readFileSync(remoteServerPath, "utf8");
  if (source.includes(persistedIdentityMarker)) return false;

  const compactAnchor = "  const output = { clients: [], accessTokens: [], refreshTokens: [] };\n";
  if (!source.includes(compactAnchor)) return false;

  const replacement = "  const output = { clients: [], accessTokens: [], refreshTokens: [], deviceIdentities: [] }; // GBF-412 persisted identities\n";
  writeFileSync(remoteServerPath, source.replace(compactAnchor, replacement));
  return true;
}

const normalized = normalizePersistedIdentityAnchor();
await import("./apply-device-identity-pinning.mjs");
if (normalized) console.log("Normalized compact persisted-identity state anchor before applying integration.");
