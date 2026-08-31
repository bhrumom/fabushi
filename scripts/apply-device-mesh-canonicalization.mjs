import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

function replaceOnce(path, before, after, marker) {
  const target = resolve(process.cwd(), path);
  const source = readFileSync(target, "utf8");
  if (source.includes(marker)) return false;
  if (!source.includes(before)) throw new Error(`Missing source pattern for ${marker} in ${path}`);
  writeFileSync(target, source.replace(before, after));
  return true;
}

let changed = false;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-mesh.js",
  'function base64Url(buffer) {\n  return Buffer.from(buffer).toString("base64url");\n}\n',
  'function base64Url(buffer) {\n  return Buffer.from(buffer).toString("base64url");\n}\n\n' +
    '/** RFC-8785-style deterministic JSON subset used by every platform when\n' +
    ' * binding a dynamic tool catalog to a signed device registration. */\n' +
    'export function canonicalMeshJson(value) {\n' +
    '  if (value === null) return "null";\n' +
    '  if (typeof value === "string") return JSON.stringify(value);\n' +
    '  if (typeof value === "boolean") return value ? "true" : "false";\n' +
    '  if (typeof value === "number") {\n' +
    '    if (!Number.isFinite(value)) throw new Error("mesh canonical JSON rejects non-finite numbers");\n' +
    '    return JSON.stringify(value);\n' +
    '  }\n' +
    '  if (Array.isArray(value)) return `[${value.map(canonicalMeshJson).join(",")}]`;\n' +
    '  if (value && typeof value === "object") {\n' +
    '    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonicalMeshJson(value[key])}`).join(",")}}`;\n' +
    '  }\n' +
    '  throw new Error("mesh canonical JSON received an unsupported value");\n' +
    '} // GBF-412 canonical tool catalog\n',
  "// GBF-412 canonical tool catalog",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-agent.js",
  '  buildSignedMeshRegistration,\n  defaultMeshIdentityPath,\n',
  '  buildSignedMeshRegistration,\n  canonicalMeshJson, // GBF-412 canonical agent catalog\n  defaultMeshIdentityPath,\n',
  "// GBF-412 canonical agent catalog",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-agent.js",
  '    const toolSchemaVersion = createHash("sha256").update(JSON.stringify(toolDescriptors)).digest("hex");\n',
  '    const toolSchemaVersion = createHash("sha256").update(canonicalMeshJson(toolDescriptors)).digest("hex"); // GBF-412 canonical agent schema hash\n',
  "// GBF-412 canonical agent schema hash",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  '  mergeMeshHeartbeat,\n  publicMeshState,\n',
  '  canonicalMeshJson, // GBF-412 canonical gateway catalog\n  mergeMeshHeartbeat,\n  publicMeshState,\n',
  "// GBF-412 canonical gateway catalog",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  '  return tools.length ? createHash("sha256").update(JSON.stringify(tools)).digest("hex") : "";\n',
  '  return tools.length ? createHash("sha256").update(canonicalMeshJson(tools)).digest("hex") : ""; // GBF-412 canonical gateway schema hash\n',
  "// GBF-412 canonical gateway schema hash",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/tests/device-mesh-gateway.test.js",
  '  buildSignedMeshRegistration,\n  loadOrCreateMeshIdentity,\n',
  '  buildSignedMeshRegistration,\n  canonicalMeshJson, // GBF-412 canonical gateway fixture\n  loadOrCreateMeshIdentity,\n',
  "// GBF-412 canonical gateway fixture",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/tests/device-mesh-gateway.test.js",
  'createHash("sha256").update(JSON.stringify([descriptor])).digest("hex")',
  'createHash("sha256").update(canonicalMeshJson([descriptor])).digest("hex") // GBF-412 canonical gateway fixture hash',
  "// GBF-412 canonical gateway fixture hash",
) || changed;

console.log(changed ? "Applied cross-platform mesh catalog canonicalization." : "Mesh catalog canonicalization already applied.");
