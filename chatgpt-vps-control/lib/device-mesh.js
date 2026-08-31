import {
  createHash,
  createPrivateKey,
  createPublicKey,
  generateKeyPairSync,
  randomBytes,
  sign,
  verify,
} from "node:crypto";
import {
  chmodSync,
  mkdirSync,
  readFileSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { dirname, resolve } from "node:path";

export const DEVICE_MESH_PROTOCOL_VERSION = "fabushi.device-mesh.v1";
export const DEVICE_MESH_RELAY_PATH = "relay";
export const DEVICE_MESH_FEATURES = Object.freeze([
  "account-scoped-discovery",
  "signed-node-identity",
  "lease-heartbeat",
  "relay-fallback",
  "path-observability",
  "capability-catalog",
]);

const MAX_TAGS = 16;
const MAX_TAG_LENGTH = 80;
const MAX_POSTURE_BYTES = 4 * 1024;
const IDENTITY_SCHEMA_VERSION = 1;

function base64Url(buffer) {
  return Buffer.from(buffer).toString("base64url");
}

function safeJwk(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const jwk = {
    kty: String(value.kty || ""),
    crv: String(value.crv || ""),
    x: String(value.x || ""),
    y: String(value.y || ""),
  };
  if (jwk.kty !== "EC" || jwk.crv !== "P-256") return null;
  if (![jwk.x, jwk.y].every((part) => /^[A-Za-z0-9_-]{40,64}$/u.test(part))) return null;
  return jwk;
}

function canonicalJwk(jwk) {
  return `${jwk.kty}:${jwk.crv}:${jwk.x}:${jwk.y}`;
}

export function meshRegistrationPayload({ deviceId, generation, toolSchemaVersion, nonce, nodePublicKey }) {
  const jwk = safeJwk(nodePublicKey);
  if (!jwk) throw new Error("invalid mesh node public key");
  return [
    DEVICE_MESH_PROTOCOL_VERSION,
    String(deviceId || ""),
    String(generation || ""),
    String(toolSchemaVersion || ""),
    String(nonce || ""),
    canonicalJwk(jwk),
  ].join("\n");
}

function publicKeyFingerprint(jwk) {
  return createHash("sha256").update(canonicalJwk(jwk)).digest("base64url").slice(0, 32);
}

function safeTags(value) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.map((item) => String(item).trim()))]
    .filter((item) => /^[a-z0-9][a-z0-9._:/-]{0,79}$/u.test(item))
    .slice(0, MAX_TAGS);
}

function safePosture(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const allowed = [
    "appVersion",
    "buildNumber",
    "deviceClass",
    "deviceModel",
    "osVersion",
    "appState",
    "networkType",
  ];
  const posture = {};
  for (const key of allowed) {
    const text = String(value[key] ?? "").trim().slice(0, 240);
    if (text) posture[key] = text;
  }
  return Buffer.byteLength(JSON.stringify(posture)) <= MAX_POSTURE_BYTES ? posture : {};
}

function validateStoredIdentity(value) {
  const publicKey = safeJwk(value?.publicKey);
  const privateKeyPem = String(value?.privateKeyPem || "");
  if (value?.schemaVersion !== IDENTITY_SCHEMA_VERSION || !publicKey || !privateKeyPem.includes("PRIVATE KEY")) {
    return null;
  }
  try {
    const privateKey = createPrivateKey(privateKeyPem);
    const derived = safeJwk(createPublicKey(privateKey).export({ format: "jwk" }));
    if (!derived || canonicalJwk(derived) !== canonicalJwk(publicKey)) return null;
    return { publicKey, privateKeyPem };
  } catch {
    return null;
  }
}

function createIdentity() {
  const pair = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const publicKey = safeJwk(pair.publicKey.export({ format: "jwk" }));
  if (!publicKey) throw new Error("unable to export Fabushi device mesh public key");
  return {
    publicKey,
    privateKeyPem: pair.privateKey.export({ format: "pem", type: "pkcs8" }).toString(),
  };
}

export function defaultMeshIdentityPath(env = process.env) {
  const explicit = String(env.DEVICE_MESH_IDENTITY_FILE || "").trim();
  if (explicit) return resolve(explicit);
  const ciRoot = String(env.FABUSHI_CI_SESSION_DIR || "").trim();
  if (ciRoot) return resolve(ciRoot, "device-mesh-identity.json");
  const home = String(env.HOME || env.USERPROFILE || process.cwd()).trim();
  return resolve(home, ".fabushi", "device-mesh-identity.json");
}

export function loadOrCreateMeshIdentity(path) {
  const destination = resolve(path);
  try {
    const current = validateStoredIdentity(JSON.parse(readFileSync(destination, "utf8")));
    if (current) return { ...current, path: destination, fingerprint: publicKeyFingerprint(current.publicKey) };
  } catch {
    // Missing or invalid identity is replaced atomically below.
  }

  const identity = createIdentity();
  const directory = dirname(destination);
  mkdirSync(directory, { recursive: true, mode: 0o700 });
  try { chmodSync(directory, 0o700); } catch {}
  const temporary = `${destination}.${process.pid}.${Date.now()}.${randomBytes(6).toString("hex")}.tmp`;
  const serialized = `${JSON.stringify({
    schemaVersion: IDENTITY_SCHEMA_VERSION,
    publicKey: identity.publicKey,
    privateKeyPem: identity.privateKeyPem,
    createdAt: new Date().toISOString(),
  }, null, 2)}\n`;
  try {
    writeFileSync(temporary, serialized, { encoding: "utf8", mode: 0o600, flag: "wx" });
    try { chmodSync(temporary, 0o600); } catch {}
    renameSync(temporary, destination);
    try { chmodSync(destination, 0o600); } catch {}
  } catch (error) {
    try { rmSync(temporary, { force: true }); } catch {}
    throw error;
  }
  return { ...identity, path: destination, fingerprint: publicKeyFingerprint(identity.publicKey) };
}

export function buildSignedMeshRegistration({
  identity,
  deviceId,
  generation,
  toolSchemaVersion,
  tags = [],
  posture = {},
}) {
  const nonce = randomBytes(24).toString("base64url");
  const payload = meshRegistrationPayload({
    deviceId,
    generation,
    toolSchemaVersion,
    nonce,
    nodePublicKey: identity.publicKey,
  });
  const signature = sign("sha256", Buffer.from(payload), createPrivateKey(identity.privateKeyPem)).toString("base64url");
  return {
    protocolVersion: DEVICE_MESH_PROTOCOL_VERSION,
    nodePublicKey: identity.publicKey,
    nonce,
    signature,
    features: [...DEVICE_MESH_FEATURES],
    supportedPaths: [DEVICE_MESH_RELAY_PATH],
    preferredPath: DEVICE_MESH_RELAY_PATH,
    activePath: DEVICE_MESH_RELAY_PATH,
    tags: safeTags(tags),
    posture: safePosture(posture),
  };
}

export function verifyAndNormalizeMeshRegistration(mesh, registration) {
  if (mesh == null) return null;
  if (!mesh || typeof mesh !== "object" || Array.isArray(mesh)) {
    throw new Error("invalid mesh registration");
  }
  if (mesh.protocolVersion !== DEVICE_MESH_PROTOCOL_VERSION) {
    throw new Error("unsupported mesh protocol version");
  }
  const nodePublicKey = safeJwk(mesh.nodePublicKey);
  const nonce = String(mesh.nonce || "");
  const signature = String(mesh.signature || "");
  if (!nodePublicKey || !/^[A-Za-z0-9_-]{24,128}$/u.test(nonce) || !/^[A-Za-z0-9_-]{64,256}$/u.test(signature)) {
    throw new Error("invalid signed mesh identity");
  }
  const payload = meshRegistrationPayload({
    deviceId: registration.deviceId,
    generation: registration.generation,
    toolSchemaVersion: registration.toolSchemaVersion,
    nonce,
    nodePublicKey,
  });
  let verified = false;
  try {
    verified = verify(
      "sha256",
      Buffer.from(payload),
      createPublicKey({ key: nodePublicKey, format: "jwk" }),
      Buffer.from(signature, "base64url"),
    );
  } catch {
    verified = false;
  }
  if (!verified) throw new Error("mesh registration signature verification failed");
  const supportedPaths = Array.isArray(mesh.supportedPaths)
    ? [...new Set(mesh.supportedPaths.map(String))].filter((path) => path === DEVICE_MESH_RELAY_PATH)
    : [];
  if (!supportedPaths.includes(DEVICE_MESH_RELAY_PATH)) supportedPaths.push(DEVICE_MESH_RELAY_PATH);
  return {
    protocolVersion: DEVICE_MESH_PROTOCOL_VERSION,
    nodeKeyFingerprint: publicKeyFingerprint(nodePublicKey),
    nodePublicKey,
    features: DEVICE_MESH_FEATURES.filter((feature) => Array.isArray(mesh.features) && mesh.features.includes(feature)),
    supportedPaths,
    preferredPath: DEVICE_MESH_RELAY_PATH,
    activePath: DEVICE_MESH_RELAY_PATH,
    tags: safeTags(mesh.tags),
    posture: safePosture(mesh.posture),
    signed: true,
    pathChangedAt: Date.now(),
  };
}

export function publicMeshState(mesh) {
  if (!mesh) {
    return {
      protocolVersion: null,
      signed: false,
      supportedPaths: [DEVICE_MESH_RELAY_PATH],
      preferredPath: DEVICE_MESH_RELAY_PATH,
      activePath: DEVICE_MESH_RELAY_PATH,
      features: ["account-scoped-discovery", "lease-heartbeat", "relay-fallback", "capability-catalog"],
      tags: [],
      posture: {},
    };
  }
  return {
    protocolVersion: mesh.protocolVersion,
    nodeKeyFingerprint: mesh.nodeKeyFingerprint,
    signed: mesh.signed === true,
    supportedPaths: [...mesh.supportedPaths],
    preferredPath: mesh.preferredPath,
    activePath: mesh.activePath,
    features: [...mesh.features],
    tags: [...mesh.tags],
    posture: { ...mesh.posture },
    pathChangedAt: new Date(mesh.pathChangedAt).toISOString(),
  };
}

export function mergeMeshHeartbeat(mesh, update) {
  if (!mesh || !update || typeof update !== "object" || Array.isArray(update)) return mesh;
  const posture = safePosture(update.posture);
  return {
    ...mesh,
    activePath: DEVICE_MESH_RELAY_PATH,
    preferredPath: DEVICE_MESH_RELAY_PATH,
    posture: Object.keys(posture).length ? { ...mesh.posture, ...posture } : mesh.posture,
  };
}

export function parseMeshTags(value) {
  if (!value) return [];
  try {
    return safeTags(JSON.parse(value));
  } catch {
    throw new Error("DEVICE_MESH_TAGS_JSON must be a JSON string array.");
  }
}

export function meshPostureFromEnvironment(env = process.env) {
  return safePosture({
    appVersion: env.FABUSHI_APP_VERSION,
    buildNumber: env.FABUSHI_BUILD_NUMBER,
    deviceClass: env.GITHUB_ACTIONS === "true" ? "ci-runner" : (env.DEVICE_CLASS || "desktop"),
    deviceModel: env.DEVICE_MODEL,
    osVersion: env.DEVICE_OS_VERSION,
    appState: env.DEVICE_APP_STATE || "running",
    networkType: env.DEVICE_NETWORK_TYPE,
  });
}

export function meshIdentityFingerprint(jwk) {
  const normalized = safeJwk(jwk);
  return normalized ? publicKeyFingerprint(normalized) : "";
}

export function randomMeshGeneration() {
  return base64Url(randomBytes(24));
}
