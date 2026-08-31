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
  '    signed: true,\n    pathChangedAt: Date.now(),\n',
  '    signed: true,\n    identityStatus: "self-signed",\n    identityBindingVersion: null, // GBF-412 initial mesh identity trust\n    pathChangedAt: Date.now(),\n',
  "// GBF-412 initial mesh identity trust",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-mesh.js",
  '      signed: false,\n      supportedPaths: [DEVICE_MESH_RELAY_PATH],\n',
  '      signed: false,\n      identityStatus: "legacy",\n      identityBindingVersion: null, // GBF-412 legacy identity state\n      supportedPaths: [DEVICE_MESH_RELAY_PATH],\n',
  "// GBF-412 legacy identity state",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-mesh.js",
  '    signed: mesh.signed === true,\n    supportedPaths: [...mesh.supportedPaths],\n',
  '    signed: mesh.signed === true,\n    identityStatus: String(mesh.identityStatus || "self-signed"),\n    identityBindingVersion: Number.isSafeInteger(mesh.identityBindingVersion) ? mesh.identityBindingVersion : null, // GBF-412 public identity continuity\n    supportedPaths: [...mesh.supportedPaths],\n',
  "// GBF-412 public identity continuity",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  'function handleAgentMessage(socket, raw, options) {\n',
  'async function handleAgentMessage(socket, raw, options) { // GBF-412 serialized async identity authorization\n',
  "// GBF-412 serialized async identity authorization",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  '    if (options.requireSignedMesh === true && !mesh) {\n' +
    '      rejectSocket(socket, 1008, "signed mesh registration required");\n' +
    '      return;\n' +
    '    } // GBF-412 signed mesh verification\n' +
    '    const leaseSeconds = Math.min(\n',
  '    if (options.requireSignedMesh === true && !mesh) {\n' +
    '      rejectSocket(socket, 1008, "signed mesh registration required");\n' +
    '      return;\n' +
    '    } // GBF-412 signed mesh verification\n' +
    '    const meshMetadata = safeMetadata(message.metadata);\n' +
    '    if (mesh) {\n' +
    '      if (typeof options.authorizeMeshIdentity === "function") {\n' +
    '        let authorization;\n' +
    '        try {\n' +
    '          authorization = await options.authorizeMeshIdentity({\n' +
    '            accountId: socket.accountId,\n' +
    '            deviceId: id,\n' +
    '            nodeKeyFingerprint: mesh.nodeKeyFingerprint,\n' +
    '            platform,\n' +
    '            name,\n' +
    '            metadata: meshMetadata,\n' +
    '          });\n' +
    '        } catch (error) {\n' +
    '          audit(options, { type: "device.identity_authorization_failed", accountId: socket.accountId, deviceId: id, error: error instanceof Error ? error.message : String(error) });\n' +
    '          rejectSocket(socket, 1011, "device identity authorization failed");\n' +
    '          return;\n' +
    '        }\n' +
    '        if (!authorization?.accepted) {\n' +
    '          audit(options, {\n' +
    '            type: "device.identity_rejected",\n' +
    '            accountId: socket.accountId,\n' +
    '            deviceId: id,\n' +
    '            nodeKeyFingerprint: mesh.nodeKeyFingerprint,\n' +
    '            code: String(authorization?.code || "device_identity_rejected").slice(0, 120),\n' +
    '          });\n' +
    '          rejectSocket(socket, 1008, "device identity approval required");\n' +
    '          return;\n' +
    '        }\n' +
    '        const identityStatus = String(authorization.status || "verified");\n' +
    '        mesh.identityStatus = ["enrolled", "verified", "rotated"].includes(identityStatus) ? identityStatus : "verified";\n' +
    '        mesh.identityBindingVersion = Number.isSafeInteger(authorization.bindingVersion) ? authorization.bindingVersion : 1;\n' +
    '      } else if (options.requirePinnedMesh === true) {\n' +
    '        rejectSocket(socket, 1011, "device identity registry unavailable");\n' +
    '        return;\n' +
    '      }\n' +
    '    } // GBF-412 persistent node identity authorization\n' +
    '    const leaseSeconds = Math.min(\n',
  "// GBF-412 persistent node identity authorization",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  '    const metadata = safeMetadata(message.metadata);\n',
  '    const metadata = meshMetadata; // GBF-412 reuse identity-authorized metadata\n',
  "// GBF-412 reuse identity-authorized metadata",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  '    socket.isAlive = true;\n    socket.on("pong", () => {\n',
  '    socket.isAlive = true;\n    socket.messageChain = Promise.resolve(); // GBF-412 serialize registration and calls\n    socket.on("pong", () => {\n',
  "// GBF-412 serialize registration and calls",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  '    socket.on("message", (raw) => handleAgentMessage(socket, raw, options));\n',
  '    socket.on("message", (raw) => {\n' +
    '      socket.messageChain = socket.messageChain\n' +
    '        .then(() => handleAgentMessage(socket, raw, options))\n' +
    '        .catch((error) => {\n' +
    '          audit(options, { type: "device.message_failed", accountId: socket.accountId, deviceId: socket.deviceId || "", error: error instanceof Error ? error.message : String(error) });\n' +
    '          rejectSocket(socket, 1011, "device message handling failed");\n' +
    '        });\n' +
    '    }); // GBF-412 serialized device message queue\n',
  "// GBF-412 serialized device message queue",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  'export function listRegisteredDevices(accountId) {\n',
  'export function disconnectRegisteredDevice(accountId, deviceId, reason = "device identity trust changed") {\n' +
    '  const key = registryKey(String(accountId || "").trim(), String(deviceId || "").trim());\n' +
    '  const device = devices.get(key);\n' +
    '  if (!device || device.central) return false;\n' +
    '  const socket = device.socket;\n' +
    '  device.status = "offline";\n' +
    '  device.socket = null;\n' +
    '  device.lastSeen = Date.now();\n' +
    '  if (socket) {\n' +
    '    rejectPendingForSocket(socket, `Device ${device.id} identity trust changed before the call completed.`);\n' +
    '    rejectSocket(socket, 4004, String(reason || "device identity trust changed").slice(0, 120));\n' +
    '  }\n' +
    '  return true;\n' +
    '} // GBF-412 identity rotation disconnect\n\n' +
    'export function listRegisteredDevices(accountId) {\n',
  "// GBF-412 identity rotation disconnect",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  '  signed: z.boolean(),\n  supportedPaths: z.array(z.string()),\n',
  '  signed: z.boolean(),\n  identityStatus: z.enum(["legacy", "self-signed", "enrolled", "verified", "rotated"]),\n  identityBindingVersion: z.number().int().positive().nullable(), // GBF-412 mesh identity schema\n  supportedPaths: z.array(z.string()),\n',
  "// GBF-412 mesh identity schema",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  '                mesh: { type: "object", required: ["protocolVersion", "signed", "supportedPaths", "preferredPath", "activePath", "features", "tags", "posture"], properties: { protocolVersion: { type: ["string", "null"] }, nodeKeyFingerprint: { type: "string" }, signed: { type: "boolean" }, supportedPaths: { type: "array", items: { type: "string" } }, preferredPath: { type: "string" }, activePath: { type: "string" }, features: { type: "array", items: { type: "string" } }, tags: { type: "array", items: { type: "string" } }, posture: { type: "object", additionalProperties: { type: "string" } }, pathChangedAt: { type: "string" } }, additionalProperties: false }, // GBF-412 mesh JSON schema\n',
  '                mesh: { type: "object", required: ["protocolVersion", "signed", "identityStatus", "identityBindingVersion", "supportedPaths", "preferredPath", "activePath", "features", "tags", "posture"], properties: { protocolVersion: { type: ["string", "null"] }, nodeKeyFingerprint: { type: "string" }, signed: { type: "boolean" }, identityStatus: { type: "string", enum: ["legacy", "self-signed", "enrolled", "verified", "rotated"] }, identityBindingVersion: { type: ["integer", "null"], minimum: 1 }, supportedPaths: { type: "array", items: { type: "string" } }, preferredPath: { type: "string" }, activePath: { type: "string" }, features: { type: "array", items: { type: "string" } }, tags: { type: "array", items: { type: "string" } }, posture: { type: "object", additionalProperties: { type: "string" } }, pathChangedAt: { type: "string" } }, additionalProperties: false }, // GBF-412 pinned mesh JSON schema\n',
  "// GBF-412 pinned mesh JSON schema",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/fabushi-remote-mcp-server.js",
  'import { attachDeviceGateway, registerDeviceTools } from "./device-gateway.js";\n',
  'import { attachDeviceGateway, disconnectRegisteredDevice, registerDeviceTools } from "./device-gateway.js";\n' +
    'import { createDeviceIdentityRegistry } from "./device-identity-registry.js"; // GBF-412 persistent node registry\n',
  "// GBF-412 persistent node registry",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/fabushi-remote-mcp-server.js",
  '  refreshTokens: 5_000,\n});\n',
  '  refreshTokens: 5_000,\n  deviceIdentities: 10_000,\n  identityClaims: 1_000, // GBF-412 identity capacity\n});\n',
  "// GBF-412 identity capacity",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/fabushi-remote-mcp-server.js",
  'const WRITE_SECURITY_SCHEMES = [{ type: "oauth2", scopes: ["devices.control"] }];\n',
  'const WRITE_SECURITY_SCHEMES = [{ type: "oauth2", scopes: ["devices.control"] }];\n\n' +
    'const deviceIdentityBindingShape = z.object({\n' +
    '  version: z.number().int().positive(),\n' +
    '  deviceId: z.string(),\n' +
    '  nodeKeyFingerprint: z.string(),\n' +
    '  status: z.enum(["active", "revoked"]),\n' +
    '  platform: z.string(),\n' +
    '  name: z.string(),\n' +
    '  firstSeenAt: z.string(),\n' +
    '  lastSeenAt: z.string(),\n' +
    '  rotatedAt: z.string().nullable(),\n' +
    '  revokedAt: z.string().nullable(),\n' +
    '  rotationCount: z.number().int().nonnegative(),\n' +
    '});\n' +
    'const deviceIdentityClaimShape = z.object({\n' +
    '  claimId: z.string(),\n' +
    '  deviceId: z.string(),\n' +
    '  currentFingerprint: z.string().nullable(),\n' +
    '  requestedFingerprint: z.string(),\n' +
    '  reason: z.string(),\n' +
    '  platform: z.string(),\n' +
    '  name: z.string(),\n' +
    '  createdAt: z.string(),\n' +
    '  expiresAt: z.string(),\n' +
    '}); // GBF-412 identity MCP shapes\n',
  "// GBF-412 identity MCP shapes",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/fabushi-remote-mcp-server.js",
  '  refreshTokens: [],\n  };\n',
  '  refreshTokens: [],\n    deviceIdentities: [], // GBF-412 persisted identities\n  };\n',
  "// GBF-412 persisted identities",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/fabushi-remote-mcp-server.js",
  '  for (const token of payload?.refreshTokens ?? []) {\n',
  '  output.deviceIdentities = Array.isArray(payload?.deviceIdentities) ? payload.deviceIdentities : []; // GBF-412 load identity snapshot\n  for (const token of payload?.refreshTokens ?? []) {\n',
  "// GBF-412 load identity snapshot",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/fabushi-remote-mcp-server.js",
  '    refreshTokens: positiveLimit(options.limits?.refreshTokens, DEFAULT_LIMITS.refreshTokens),\n  };\n',
  '    refreshTokens: positiveLimit(options.limits?.refreshTokens, DEFAULT_LIMITS.refreshTokens),\n    deviceIdentities: positiveLimit(options.limits?.deviceIdentities, DEFAULT_LIMITS.deviceIdentities),\n    identityClaims: positiveLimit(options.limits?.identityClaims, DEFAULT_LIMITS.identityClaims), // GBF-412 identity limits\n  };\n',
  "// GBF-412 identity limits",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/fabushi-remote-mcp-server.js",
  '  const rateBuckets = new Map();\n  let saveChain = Promise.resolve();\n',
  '  const rateBuckets = new Map();\n' +
    '  const identityRegistry = createDeviceIdentityRegistry({\n' +
    '    now,\n' +
    '    maxBindings: limits.deviceIdentities,\n' +
    '    maxClaims: limits.identityClaims,\n' +
    '  }); // GBF-412 account node continuity\n' +
    '  let saveChain = Promise.resolve();\n',
  "// GBF-412 account node continuity",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/fabushi-remote-mcp-server.js",
  '    const normalized = normalizeStatePayload(payload);\n    for (const client of normalized.clients.slice(-limits.clients)) clients.set(client.clientId, { redirectUris: client.redirectUris, createdAt: client.createdAt || now() });\n',
  '    const normalized = normalizeStatePayload(payload);\n' +
    '    identityRegistry.load(normalized.deviceIdentities); // GBF-412 restore identity continuity\n' +
    '    for (const client of normalized.clients.slice(-limits.clients)) clients.set(client.clientId, { redirectUris: client.redirectUris, createdAt: client.createdAt || now() });\n',
  "// GBF-412 restore identity continuity",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/fabushi-remote-mcp-server.js",
  '        refreshTokens: [...refreshTokens.values()],\n      };\n',
  '        refreshTokens: [...refreshTokens.values()],\n        deviceIdentities: identityRegistry.snapshot(), // GBF-412 save identity continuity\n      };\n',
  "// GBF-412 save identity continuity",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/fabushi-remote-mcp-server.js",
  '  function cleanupExpired() {\n    const timestamp = now();\n',
  '  function cleanupExpired() {\n    const timestamp = now();\n    identityRegistry.cleanup(); // GBF-412 expire identity claims\n',
  "// GBF-412 expire identity claims",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/fabushi-remote-mcp-server.js",
  '    const authError = (scope) => ({\n' +
    '      isError: true,\n' +
    '      content: [{ type: "text", text: `The Fabushi MCP token does not grant ${scope}.` }],\n' +
    '    });\n' +
    '    registerDeviceTools(server, {\n',
  '    const authError = (scope) => ({\n' +
    '      isError: true,\n' +
    '      content: [{ type: "text", text: `The Fabushi MCP token does not grant ${scope}.` }],\n' +
    '    });\n' +
    '    server.registerTool("list_device_identities", {\n' +
    '      title: "List device identity bindings",\n' +
    '      description: "List persistent signed-node bindings and pending replacement claims for this Fabushi account.",\n' +
    '      inputSchema: {},\n' +
    '      outputSchema: { bindings: z.array(deviceIdentityBindingShape), pendingClaims: z.array(deviceIdentityClaimShape) },\n' +
    '      annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false, idempotentHint: true },\n' +
    '      securitySchemes: READ_SECURITY_SCHEMES,\n' +
    '    }, async () => {\n' +
    '      if (!readAllowed) return authError("devices.read");\n' +
    '      const result = {\n' +
    '        bindings: identityRegistry.listBindings(account.accountId),\n' +
    '        pendingClaims: identityRegistry.listClaims(account.accountId),\n' +
    '      };\n' +
    '      return { structuredContent: result, content: [{ type: "text", text: JSON.stringify(result) }] };\n' +
    '    });\n' +
    '    server.registerTool("approve_device_identity_rotation", {\n' +
    '      title: "Approve device identity rotation",\n' +
    '      description: "Approve one short-lived signed-node replacement claim after verifying the device id, platform, name, and requested fingerprint.",\n' +
    '      inputSchema: { claimId: z.string().min(24).max(128) },\n' +
    '      outputSchema: { binding: deviceIdentityBindingShape, previousFingerprint: z.string() },\n' +
    '      annotations: { readOnlyHint: false, destructiveHint: true, openWorldHint: false, idempotentHint: false },\n' +
    '      securitySchemes: WRITE_SECURITY_SCHEMES,\n' +
    '    }, async ({ claimId }) => {\n' +
    '      if (!writeAllowed) return authError("devices.control");\n' +
    '      const result = identityRegistry.approve(account.accountId, claimId);\n' +
    '      await saveState();\n' +
    '      disconnectRegisteredDevice(account.accountId, result.binding.deviceId, "device identity rotated");\n' +
    '      await audit({ type: "device.identity_rotation_approved", accountRef: safeAccountRef(account.accountId), deviceId: result.binding.deviceId, nodeKeyFingerprint: result.binding.nodeKeyFingerprint });\n' +
    '      return { structuredContent: result, content: [{ type: "text", text: `Approved signed-node rotation for ${result.binding.deviceId}.` }] };\n' +
    '    });\n' +
    '    server.registerTool("revoke_device_identity", {\n' +
    '      title: "Revoke a device identity",\n' +
    '      description: "Revoke the persistent signed-node binding for a device. Reconnection requires an explicit approval claim; revocation never silently re-enrolls the old key.",\n' +
    '      inputSchema: { deviceId: z.string().min(1).max(128) },\n' +
    '      outputSchema: { revoked: z.boolean(), binding: deviceIdentityBindingShape.nullable() },\n' +
    '      annotations: { readOnlyHint: false, destructiveHint: true, openWorldHint: false, idempotentHint: true },\n' +
    '      securitySchemes: WRITE_SECURITY_SCHEMES,\n' +
    '    }, async ({ deviceId }) => {\n' +
    '      if (!writeAllowed) return authError("devices.control");\n' +
    '      const result = identityRegistry.revoke(account.accountId, deviceId);\n' +
    '      if (result.changed) await saveState();\n' +
    '      if (result.revoked) disconnectRegisteredDevice(account.accountId, deviceId, "device identity revoked");\n' +
    '      await audit({ type: "device.identity_revoked", accountRef: safeAccountRef(account.accountId), deviceId, revoked: result.revoked });\n' +
    '      return { structuredContent: { revoked: result.revoked, binding: result.binding }, content: [{ type: "text", text: result.revoked ? `Revoked signed-node identity for ${deviceId}.` : `No signed-node identity was bound to ${deviceId}.` }] };\n' +
    '    }); // GBF-412 identity management tools\n' +
    '    registerDeviceTools(server, {\n',
  "// GBF-412 identity management tools",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/fabushi-remote-mcp-server.js",
  '    maxLeaseSeconds: Number(options.maxLeaseSeconds ?? process.env.DEVICE_MAX_LEASE_SECONDS ?? 4 * 60 * 60),\n  });\n',
  '    maxLeaseSeconds: Number(options.maxLeaseSeconds ?? process.env.DEVICE_MAX_LEASE_SECONDS ?? 4 * 60 * 60),\n' +
    '    requireSignedMesh: options.requireSignedMesh ?? /^(1|true|yes)$/iu.test(String(process.env.DEVICE_REQUIRE_SIGNED_MESH || "")),\n' +
    '    requirePinnedMesh: true,\n' +
    '    authorizeMeshIdentity: async (request) => {\n' +
    '      const decision = identityRegistry.authorize(request);\n' +
    '      if (decision.accepted && decision.changed) await saveState();\n' +
    '      await audit({\n' +
    '        type: decision.accepted ? "device.identity_authorized" : "device.identity_claimed",\n' +
    '        accountRef: safeAccountRef(request.accountId),\n' +
    '        deviceId: request.deviceId,\n' +
    '        nodeKeyFingerprint: request.nodeKeyFingerprint,\n' +
    '        status: decision.status,\n' +
    '        code: decision.code,\n' +
    '      });\n' +
    '      return decision;\n' +
    '    }, // GBF-412 enforce persistent signed-node continuity\n' +
    '  });\n',
  "// GBF-412 enforce persistent signed-node continuity",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/tests/device-mesh.test.js",
  '    signed: false,\n    supportedPaths: ["relay"],\n',
  '    signed: false,\n    identityStatus: "legacy",\n    identityBindingVersion: null, // GBF-412 legacy identity test\n    supportedPaths: ["relay"],\n',
  "// GBF-412 legacy identity test",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/tests/fabushi-remote-mcp-server.test.js",
  '  assert.deepEqual(listedTools.tools.map((tool) => tool.name), ["fabushi_account", "list_devices", "describe_device_tool", "device_call"]);\n',
  '  assert.deepEqual(listedTools.tools.map((tool) => tool.name), ["fabushi_account", "list_device_identities", "approve_device_identity_rotation", "revoke_device_identity", "list_devices", "describe_device_tool", "device_call"]); // GBF-412 identity tools\n',
  "// GBF-412 identity tools",
) || changed;

console.log(changed ? "Applied persistent device identity pinning integration." : "Persistent device identity pinning already applied.");
