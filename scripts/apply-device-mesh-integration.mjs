import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();

function file(path) {
  return resolve(root, path);
}

function replaceOnce(path, before, after, marker) {
  const target = file(path);
  const source = readFileSync(target, "utf8");
  if (source.includes(marker)) return false;
  if (!source.includes(before)) {
    throw new Error(`Unable to apply ${marker}: source pattern not found in ${path}`);
  }
  const next = source.replace(before, after);
  writeFileSync(target, next);
  return true;
}

let changed = false;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-agent.js",
  'import { createFabushiAccountSessionStore } from "./fabushi-account-session.js";\n',
  'import { createFabushiAccountSessionStore } from "./fabushi-account-session.js";\n' +
    'import {\n' +
    '  buildSignedMeshRegistration,\n' +
    '  defaultMeshIdentityPath,\n' +
    '  loadOrCreateMeshIdentity,\n' +
    '  meshPostureFromEnvironment,\n' +
    '  parseMeshTags,\n' +
    '} from "./device-mesh.js"; // GBF-412 device mesh\n',
  "// GBF-412 device mesh",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-agent.js",
  '    ipFamily: [4, 6].includes(Number(env.DEVICE_GATEWAY_IP_FAMILY)) ? Number(env.DEVICE_GATEWAY_IP_FAMILY) : 0,\n',
  '    ipFamily: [4, 6].includes(Number(env.DEVICE_GATEWAY_IP_FAMILY)) ? Number(env.DEVICE_GATEWAY_IP_FAMILY) : 0,\n' +
    '    meshIdentityPath: defaultMeshIdentityPath(env),\n' +
    '    meshTags: parseMeshTags(env.DEVICE_MESH_TAGS_JSON),\n' +
    '    meshPosture: meshPostureFromEnvironment(env), // GBF-412 mesh config\n',
  "// GBF-412 mesh config",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-agent.js",
  '  const readyWaiters = new Set();\n',
  '  const readyWaiters = new Set();\n' +
    '  const meshIdentity = options.meshIdentity ?? loadOrCreateMeshIdentity(\n' +
    '    config.meshIdentityPath ?? defaultMeshIdentityPath(options.env ?? process.env),\n' +
    '  ); // GBF-412 persistent node identity\n',
  "// GBF-412 persistent node identity",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-agent.js",
  '      const activeGatewayToken = config.getGatewayToken ? await config.getGatewayToken() : config.gatewayToken;\n' +
    '      const socket = new WebSocketImpl(config.gatewayUrl, {\n',
  '      const activeGatewayToken = config.getGatewayToken ? await config.getGatewayToken() : config.gatewayToken;\n' +
    '      const mesh = buildSignedMeshRegistration({\n' +
    '        identity: meshIdentity,\n' +
    '        deviceId: config.deviceId,\n' +
    '        generation: connectionGeneration,\n' +
    '        toolSchemaVersion: local.toolSchemaVersion,\n' +
    '        tags: config.meshTags,\n' +
    '        posture: config.meshPosture,\n' +
    '      }); // GBF-412 signed registration\n' +
    '      const socket = new WebSocketImpl(config.gatewayUrl, {\n',
  "// GBF-412 signed registration",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-agent.js",
  '          leaseSeconds: config.leaseSeconds,\n' +
    '          metadata: config.metadata,\n',
  '          leaseSeconds: config.leaseSeconds,\n' +
    '          metadata: config.metadata,\n' +
    '          mesh, // GBF-412 signed node and relay path state\n',
  "// GBF-412 signed node and relay path state",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-agent.js",
  '          socket.send(JSON.stringify({ type: "heartbeat", at: Date.now() }));\n',
  '          socket.send(JSON.stringify({\n' +
    '            type: "heartbeat",\n' +
    '            at: Date.now(),\n' +
    '            mesh: { activePath: "relay", posture: config.meshPosture ?? {} },\n' +
    '          })); // GBF-412 mesh heartbeat\n',
  "// GBF-412 mesh heartbeat",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  'import { z } from "zod";\n',
  'import { z } from "zod";\n' +
    'import {\n' +
    '  mergeMeshHeartbeat,\n' +
    '  publicMeshState,\n' +
    '  verifyAndNormalizeMeshRegistration,\n' +
    '} from "./device-mesh.js"; // GBF-412 mesh gateway\n',
  "// GBF-412 mesh gateway",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  '    secureInputPublicKey: device.secureInputPublicKey,\n',
  '    secureInputPublicKey: device.secureInputPublicKey,\n' +
    '    mesh: publicMeshState(device.mesh), // GBF-412 public mesh state\n',
  "// GBF-412 public mesh state",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  '    const tools = normalizeToolCatalog(message.tools, capabilities);\n' +
    '    const toolSchemaVersion = toolCatalogVersion(tools);\n' +
    '    const leaseSeconds = Math.min(\n',
  '    const tools = normalizeToolCatalog(message.tools, capabilities);\n' +
    '    const toolSchemaVersion = toolCatalogVersion(tools);\n' +
    '    const generation = String(message.generation ?? "").trim();\n' +
    '    if (message.mesh != null && !/^[A-Za-z0-9_-]{16,128}$/u.test(generation)) {\n' +
    '      rejectSocket(socket, 1008, "signed mesh registration requires a valid generation");\n' +
    '      return;\n' +
    '    }\n' +
    '    let mesh = null;\n' +
    '    try {\n' +
    '      mesh = verifyAndNormalizeMeshRegistration(message.mesh, {\n' +
    '        deviceId: id,\n' +
    '        generation,\n' +
    '        toolSchemaVersion,\n' +
    '      });\n' +
    '    } catch (error) {\n' +
    '      audit(options, { type: "device.mesh_rejected", accountId: socket.accountId, deviceId: id, error: error instanceof Error ? error.message : String(error) });\n' +
    '      rejectSocket(socket, 1008, "invalid signed mesh registration");\n' +
    '      return;\n' +
    '    }\n' +
    '    if (options.requireSignedMesh === true && !mesh) {\n' +
    '      rejectSocket(socket, 1008, "signed mesh registration required");\n' +
    '      return;\n' +
    '    } // GBF-412 signed mesh verification\n' +
    '    const leaseSeconds = Math.min(\n',
  "// GBF-412 signed mesh verification",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  '      toolSchemaVersion,\n' +
    '      metadata,\n' +
    '      secureInputPublicKey,\n',
  '      toolSchemaVersion,\n' +
    '      generation,\n' +
    '      mesh, // GBF-412 stored node/path state\n' +
    '      metadata,\n' +
    '      secureInputPublicKey,\n',
  "// GBF-412 stored node/path state",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  '    socket.send(JSON.stringify({ type: "registered", deviceId: id, expiresAt: new Date(expiresAt).toISOString() }));\n' +
    '    audit(options, { type: "device.registered", accountId: socket.accountId, deviceId: id, metadata });\n',
  '    socket.send(JSON.stringify({\n' +
    '      type: "registered",\n' +
    '      deviceId: id,\n' +
    '      expiresAt: new Date(expiresAt).toISOString(),\n' +
    '      mesh: publicMeshState(mesh),\n' +
    '    }));\n' +
    '    audit(options, {\n' +
    '      type: "device.registered",\n' +
    '      accountId: socket.accountId,\n' +
    '      deviceId: id,\n' +
    '      metadata,\n' +
    '      mesh: { signed: Boolean(mesh), nodeKeyFingerprint: mesh?.nodeKeyFingerprint || "", activePath: mesh?.activePath || "relay" },\n' +
    '    }); // GBF-412 registration response and audit\n',
  "// GBF-412 registration response and audit",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  '      device.lastSeen = Date.now();\n' +
    '      device.status = device.expiresAt > Date.now() ? "online" : "offline";\n',
  '      device.lastSeen = Date.now();\n' +
    '      device.mesh = mergeMeshHeartbeat(device.mesh, message.mesh); // GBF-412 heartbeat posture/path\n' +
    '      device.status = device.expiresAt > Date.now() ? "online" : "offline";\n',
  "// GBF-412 heartbeat posture/path",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  '      toolSchemaVersion: toolCatalogVersion(centralTools),\n' +
    '      metadata: { kind: "central" },\n',
  '      toolSchemaVersion: toolCatalogVersion(centralTools),\n' +
    '      generation: "central",\n' +
    '      mesh: null, // GBF-412 central mesh compatibility\n' +
    '      metadata: { kind: "central" },\n',
  "// GBF-412 central mesh compatibility",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  'const deviceShape = z.object({\n',
  'const meshShape = z.object({\n' +
    '  protocolVersion: z.string().nullable(),\n' +
    '  nodeKeyFingerprint: z.string().optional(),\n' +
    '  signed: z.boolean(),\n' +
    '  supportedPaths: z.array(z.string()),\n' +
    '  preferredPath: z.string(),\n' +
    '  activePath: z.string(),\n' +
    '  features: z.array(z.string()),\n' +
    '  tags: z.array(z.string()),\n' +
    '  posture: z.record(z.string(), z.string()),\n' +
    '  pathChangedAt: z.string().optional(),\n' +
    '}); // GBF-412 mesh output schema\n\n' +
    'const deviceShape = z.object({\n',
  "// GBF-412 mesh output schema",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  '  secureInputPublicKey: z.object({ kty: z.literal("EC"), crv: z.literal("P-256"), x: z.string(), y: z.string() }).nullable(),\n' +
    '  capabilities: z.array(z.string()),\n',
  '  secureInputPublicKey: z.object({ kty: z.literal("EC"), crv: z.literal("P-256"), x: z.string(), y: z.string() }).nullable(),\n' +
    '  mesh: meshShape, // GBF-412 mesh device shape\n' +
    '  capabilities: z.array(z.string()),\n',
  "// GBF-412 mesh device shape",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  '                secureInputPublicKey: { anyOf: [{ type: "object", required: ["kty", "crv", "x", "y"], properties: { kty: { const: "EC" }, crv: { const: "P-256" }, x: { type: "string" }, y: { type: "string" } }, additionalProperties: false }, { type: "null" }] },\n' +
    '                capabilities: { type: "array", items: { type: "string" } },\n',
  '                secureInputPublicKey: { anyOf: [{ type: "object", required: ["kty", "crv", "x", "y"], properties: { kty: { const: "EC" }, crv: { const: "P-256" }, x: { type: "string" }, y: { type: "string" } }, additionalProperties: false }, { type: "null" }] },\n' +
    '                mesh: { type: "object", required: ["protocolVersion", "signed", "supportedPaths", "preferredPath", "activePath", "features", "tags", "posture"], properties: { protocolVersion: { type: ["string", "null"] }, nodeKeyFingerprint: { type: "string" }, signed: { type: "boolean" }, supportedPaths: { type: "array", items: { type: "string" } }, preferredPath: { type: "string" }, activePath: { type: "string" }, features: { type: "array", items: { type: "string" } }, tags: { type: "array", items: { type: "string" } }, posture: { type: "object", additionalProperties: { type: "string" } }, pathChangedAt: { type: "string" } }, additionalProperties: false }, // GBF-412 mesh JSON schema\n' +
    '                capabilities: { type: "array", items: { type: "string" } },\n',
  "// GBF-412 mesh JSON schema",
) || changed;

changed = replaceOnce(
  "chatgpt-vps-control/lib/device-gateway.js",
  '              required: ["id", "name", "platform", "status", "lastSeen", "expiresAt", "metadata", "secureInputPublicKey", "capabilities", "toolSchemaCount", "toolSchemaVersion"],\n',
  '              required: ["id", "name", "platform", "status", "lastSeen", "expiresAt", "metadata", "secureInputPublicKey", "mesh", "capabilities", "toolSchemaCount", "toolSchemaVersion"], // GBF-412 mesh required\n',
  "// GBF-412 mesh required",
) || changed;

changed = replaceOnce(
  "desktop/electron/remote-device-agent-supervisor.cjs",
  '          FABUSHI_APP_AGENT_DISCOVERY_FILE: discoveryFile,\n',
  '          FABUSHI_APP_AGENT_DISCOVERY_FILE: discoveryFile,\n' +
    "          DEVICE_MESH_IDENTITY_FILE: path.join(this.app.getPath('userData'), 'remote-device', 'mesh-identity.json'),\n" +
    "          DEVICE_MESH_TAGS_JSON: JSON.stringify(['client:fabushi', 'platform:desktop']),\n" +
    "          FABUSHI_APP_VERSION: typeof this.app.getVersion === 'function' ? this.app.getVersion() : '',\n" +
    "          DEVICE_CLASS: 'desktop',\n" +
    "          DEVICE_APP_STATE: 'running', // GBF-412 desktop mesh posture\n",
  "// GBF-412 desktop mesh posture",
) || changed;

console.log(changed ? "Applied GBF-412 device mesh integration." : "GBF-412 device mesh integration already applied.");
