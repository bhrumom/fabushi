const SAFE_ID = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,191}$/;
const SAFE_OWNER = /^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$/;
const SAFE_REPOSITORY = /^[A-Za-z0-9_.-]{1,100}$/;
const SHA1 = /^[a-f0-9]{40}$/i;

export const MCP_APP_IDENTITY_SCHEMA_VERSION = 2;
export const MCP_APP_DEPLOYMENT_TARGETS = Object.freeze([
  'local-only',
  'official-managed-github',
  'user-github',
  'official-source-github',
]);
export const MCP_APP_SOURCE_HOSTS = Object.freeze(['local', 'github']);
export const MCP_APP_SOURCE_CUSTODIES = Object.freeze(['device', 'platform-managed', 'user-owned']);
export const MCP_APP_SOURCE_PROVIDERS = Object.freeze(['local', 'github']);
export const MCP_APP_SOURCE_ACTORS = Object.freeze(['user', 'platform']);
export const MCP_APP_SOURCE_TRANSPORTS = Object.freeze(['local-fs', 'github-mcp', 'github-app-api']);
export const MCP_APP_HOSTING_PROVIDERS = Object.freeze([
  'none',
  'github-pages',
  'cloudflare-pages',
  'cloudflare-workers',
  'external',
]);
export const MCP_APP_RUNTIME_PROFILES = Object.freeze([
  'local-native',
  'local-web-wasm',
  'web-static',
  'remote-edge',
]);
export const MCP_APP_OFFICIAL_STATUSES = Object.freeze(['official', 'community', 'unverified']);
export const MCP_APP_SOURCE_STATES = Object.freeze(['local-only', 'source-hosted', 'diverged', 'failed', 'outcome-unknown']);
export const MCP_APP_WEB_DEPLOYMENT_STATES = Object.freeze(['none', 'queued', 'deploying', 'deployed', 'failed', 'rolled-back']);

export class McpAppIdentityError extends Error {
  constructor(code, message, details = {}) {
    super(message);
    this.name = 'McpAppIdentityError';
    this.code = code;
    this.details = details;
  }
}

function fail(code, message, details = {}) {
  throw new McpAppIdentityError(code, message, details);
}

function stringField(value, field, { max = 256, optional = false } = {}) {
  if (value == null || value === '') {
    if (optional) return null;
    fail('field_required', `${field} is required`, { field });
  }
  const normalized = String(value).trim();
  if (!normalized || normalized.length > max) {
    fail('field_invalid', `${field} is invalid`, { field });
  }
  return normalized;
}

function enumField(value, field, allowed, fallback) {
  const normalized = String(value ?? fallback ?? '').trim().toLowerCase();
  if (!allowed.includes(normalized)) {
    fail('enum_invalid', `${field} is invalid`, { field, value: normalized, allowed });
  }
  return normalized;
}

function repositoryIdField(value, required) {
  if (value == null || value === '') {
    if (required) fail('repository_id_required', 'repositoryId is required for GitHub source identities');
    return null;
  }
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id <= 0) {
    fail('repository_id_invalid', 'repositoryId must be a positive safe integer');
  }
  return id;
}

function sourceCommitField(value) {
  if (value == null || value === '') return null;
  const commit = String(value).trim().toLowerCase();
  if (!SHA1.test(commit)) fail('source_commit_invalid', 'sourceCommit must be a 40 character Git commit SHA');
  return commit;
}

function normalizeRepositoryLocator(ownerValue, nameValue, required) {
  if (!required && !ownerValue && !nameValue) return { repositoryOwner: null, repositoryName: null };
  const repositoryOwner = stringField(ownerValue, 'repositoryOwner', { max: 39, optional: !required });
  const repositoryName = stringField(nameValue, 'repositoryName', { max: 100, optional: !required });
  if (repositoryOwner && !SAFE_OWNER.test(repositoryOwner)) {
    fail('repository_owner_invalid', 'repositoryOwner is invalid');
  }
  if (repositoryName && !SAFE_REPOSITORY.test(repositoryName)) {
    fail('repository_name_invalid', 'repositoryName is invalid');
  }
  if ((repositoryOwner == null) !== (repositoryName == null)) {
    fail('repository_locator_incomplete', 'repositoryOwner and repositoryName must be supplied together');
  }
  return { repositoryOwner, repositoryName };
}

function expectedSourceFields(deploymentTarget) {
  switch (deploymentTarget) {
    case 'local-only':
      return {
        sourceHost: 'local',
        sourceCustody: 'device',
        sourceProvider: 'local',
        sourceActor: 'user',
        sourceTransport: 'local-fs',
      };
    case 'official-managed-github':
      return {
        sourceHost: 'github',
        sourceCustody: 'platform-managed',
        sourceProvider: 'github',
        sourceActor: 'platform',
        sourceTransport: 'github-app-api',
      };
    case 'user-github':
      return {
        sourceHost: 'github',
        sourceCustody: 'user-owned',
        sourceProvider: 'github',
        sourceActor: 'user',
        sourceTransport: 'github-mcp',
      };
    case 'official-source-github':
      return {
        sourceHost: 'github',
        sourceCustody: 'platform-managed',
        sourceProvider: 'github',
        sourceActor: 'platform',
        sourceTransport: 'github-app-api',
      };
    default:
      fail('deployment_target_invalid', 'deploymentTarget is invalid', { deploymentTarget });
  }
}

function snakeCaseField(field) {
  return field.replace(/[A-Z]/g, (character) => `_${character.toLowerCase()}`);
}

function assertDerivedSourceField(input, field, expected) {
  const snakeField = snakeCaseField(field);
  const supplied = input[field] ?? input[snakeField];
  if (supplied != null && String(supplied).trim().toLowerCase() !== expected) {
    fail('source_identity_conflict', `${field} conflicts with deploymentTarget`, { field, expected });
  }
}

function defaultRuntimeProfile(hostingProvider) {
  if (hostingProvider === 'github-pages' || hostingProvider === 'cloudflare-pages') return 'web-static';
  if (hostingProvider === 'cloudflare-workers' || hostingProvider === 'external') return 'remote-edge';
  return 'local-web-wasm';
}

function normalizeHosting(input) {
  let hostingProvider = String(input.hostingProvider ?? input.hosting_provider ?? 'none').trim().toLowerCase();
  if (hostingProvider === 'cloudflare') hostingProvider = 'cloudflare-workers';
  hostingProvider = enumField(hostingProvider, 'hostingProvider', MCP_APP_HOSTING_PROVIDERS);
  const runtimeProfile = enumField(
    input.runtimeProfile ?? input.runtime_profile,
    'runtimeProfile',
    MCP_APP_RUNTIME_PROFILES,
    defaultRuntimeProfile(hostingProvider),
  );
  if (['github-pages', 'cloudflare-pages'].includes(hostingProvider) && runtimeProfile !== 'web-static') {
    fail('hosting_runtime_mismatch', 'static hosting requires runtimeProfile=web-static');
  }
  if (hostingProvider === 'cloudflare-workers' && runtimeProfile !== 'remote-edge') {
    fail('hosting_runtime_mismatch', 'Cloudflare Workers requires runtimeProfile=remote-edge');
  }
  const webDeploymentState = enumField(
    input.webDeploymentState ?? input.web_deployment_state,
    'webDeploymentState',
    MCP_APP_WEB_DEPLOYMENT_STATES,
    'none',
  );
  if (hostingProvider === 'none' && !['none', 'failed', 'rolled-back'].includes(webDeploymentState)) {
    fail('web_deployment_without_hosting', 'web deployment state cannot imply a live deployment when hostingProvider=none');
  }
  return { hostingProvider, runtimeProfile, webDeploymentState };
}

export function createMcpAppIdentity(input = {}) {
  const appId = stringField(input.appId ?? input.app_id, 'appId', { max: 192 });
  if (!SAFE_ID.test(appId)) fail('app_id_invalid', 'appId contains unsupported characters');
  const pluginId = stringField(input.pluginId ?? input.plugin_id ?? appId, 'pluginId', { max: 192 });
  if (!SAFE_ID.test(pluginId)) fail('plugin_id_invalid', 'pluginId contains unsupported characters');

  const deploymentTarget = enumField(
    input.deploymentTarget ?? input.deployment_target,
    'deploymentTarget',
    MCP_APP_DEPLOYMENT_TARGETS,
    'local-only',
  );
  const expected = expectedSourceFields(deploymentTarget);
  for (const [field, value] of Object.entries(expected)) assertDerivedSourceField(input, field, value);

  const remote = expected.sourceHost === 'github';
  const repositoryId = repositoryIdField(input.repositoryId ?? input.repository_id, remote);
  const { repositoryOwner, repositoryName } = normalizeRepositoryLocator(
    input.repositoryOwner ?? input.repository_owner,
    input.repositoryName ?? input.repository_name,
    false,
  );
  if (!remote && (repositoryId || repositoryOwner || repositoryName)) {
    fail('local_remote_identity_conflict', 'local-only identities cannot contain GitHub repository identity');
  }

  let officialStatus = String(input.officialStatus ?? input.official_status ?? 'unverified').trim().toLowerCase();
  if (officialStatus === 'user') officialStatus = 'community';
  officialStatus = enumField(officialStatus, 'officialStatus', MCP_APP_OFFICIAL_STATUSES);
  if (deploymentTarget !== 'official-source-github' && officialStatus === 'official') {
    fail('official_status_forbidden', 'only official source GitHub identities may be marked official');
  }

  const author = stringField(input.author ?? input.authorSubjectId ?? input.author_subject_id ?? 'unknown', 'author', { max: 160 });
  const publisher = stringField(
    input.publisher ?? input.publisherSubjectId ?? input.publisher_subject_id ?? author,
    'publisher',
    { max: 160 },
  );
  const lineageId = stringField(input.lineageId ?? input.lineage_id ?? appId, 'lineageId', { max: 192 });
  const sourceCommit = sourceCommitField(input.sourceCommit ?? input.source_commit);
  const { hostingProvider, runtimeProfile, webDeploymentState } = normalizeHosting(input);
  const sourceState = enumField(
    input.sourceState ?? input.source_state,
    'sourceState',
    MCP_APP_SOURCE_STATES,
    remote ? 'source-hosted' : 'local-only',
  );
  if (!remote && sourceState === 'source-hosted') {
    fail('source_state_invalid', 'local-only identities cannot be source-hosted');
  }

  return Object.freeze({
    schemaVersion: MCP_APP_IDENTITY_SCHEMA_VERSION,
    appId,
    pluginId,
    author,
    sourceHost: expected.sourceHost,
    sourceCustody: expected.sourceCustody,
    sourceProvider: expected.sourceProvider,
    sourceActor: expected.sourceActor,
    sourceTransport: expected.sourceTransport,
    // Keep source lineage and deployment facts independently observable for
    // API projections. A GitHub source is not itself a web deployment.
    sourceIdentity: Object.freeze({
      host: expected.sourceHost,
      custody: expected.sourceCustody,
      provider: expected.sourceProvider,
      actor: expected.sourceActor,
      transport: expected.sourceTransport,
    }),
    repositoryId,
    repositoryOwner,
    repositoryName,
    sourceCommit,
    publisher,
    officialStatus,
    hostingProvider,
    runtimeProfile,
    deploymentTarget,
    lineageId,
    sourceState,
    webDeploymentState,
  });
}

export function upgradeLegacyMcpAppIdentity(input = {}) {
  const sourceType = String(input.sourceType ?? input.source_type ?? 'local-workspace').trim().toLowerCase();
  const legacyDeploymentTarget = String(input.deploymentTarget ?? input.deployment_target ?? 'local-only').trim().toLowerCase();
  const deploymentTarget = sourceType === 'managed-github'
    ? 'official-managed-github'
    : sourceType === 'user-github'
      ? 'user-github'
      : sourceType === 'official-github'
        ? 'official-source-github'
        : 'local-only';
  const hostingProvider = legacyDeploymentTarget === 'github-pages'
    ? 'github-pages'
    : legacyDeploymentTarget === 'cloudflare'
      ? 'cloudflare-workers'
      : 'none';
  return createMcpAppIdentity({
    appId: input.appId ?? input.app_id,
    pluginId: input.pluginId ?? input.plugin_id ?? input.appId ?? input.app_id,
    author: input.author ?? 'unknown',
    publisher: input.publisher ?? input.author ?? 'unknown',
    officialStatus: input.officialStatus ?? input.official_status ?? 'unverified',
    deploymentTarget,
    repositoryId: input.repositoryId ?? input.repository_id,
    repositoryOwner: input.repositoryOwner ?? input.repository_owner,
    repositoryName: input.repositoryName ?? input.repository_name,
    sourceCommit: input.sourceCommit ?? input.source_commit,
    hostingProvider,
    lineageId: input.lineageId ?? input.lineage_id ?? input.appId ?? input.app_id,
    sourceState: deploymentTarget === 'local-only' ? 'local-only' : 'source-hosted',
    webDeploymentState: 'none',
  });
}

export function serializeMcpAppIdentity(input) {
  return JSON.stringify(createMcpAppIdentity(input));
}

export function deserializeMcpAppIdentity(serialized) {
  const parsed = typeof serialized === 'string' ? JSON.parse(serialized) : serialized;
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    fail('identity_invalid', 'serialized identity must decode to an object');
  }
  if (parsed.schemaVersion == null && (parsed.sourceType != null || parsed.source_type != null)) {
    return upgradeLegacyMcpAppIdentity(parsed);
  }
  if (Number(parsed.schemaVersion ?? MCP_APP_IDENTITY_SCHEMA_VERSION) !== MCP_APP_IDENTITY_SCHEMA_VERSION) {
    fail('schema_version_unsupported', 'unsupported MCP app identity schema version');
  }
  return createMcpAppIdentity(parsed);
}

export function toMcpAppIdentityRow(input) {
  const value = createMcpAppIdentity(input);
  return {
    schema_version: value.schemaVersion,
    app_id: value.appId,
    plugin_id: value.pluginId,
    author: value.author,
    source_host: value.sourceHost,
    source_custody: value.sourceCustody,
    source_provider: value.sourceProvider,
    source_actor: value.sourceActor,
    source_transport: value.sourceTransport,
    repository_id: value.repositoryId,
    repository_owner: value.repositoryOwner,
    repository_name: value.repositoryName,
    source_commit: value.sourceCommit,
    publisher: value.publisher,
    official_status: value.officialStatus,
    hosting_provider: value.hostingProvider,
    runtime_profile: value.runtimeProfile,
    deployment_target: value.deploymentTarget,
    lineage_id: value.lineageId,
    source_state: value.sourceState,
    web_deployment_state: value.webDeploymentState,
    source_identity_json: serializeMcpAppIdentity(value),
  };
}

export function fromMcpAppIdentityRow(row = {}) {
  if (row.schema_version == null && row.source_type != null) return upgradeLegacyMcpAppIdentity(row);
  return createMcpAppIdentity(row);
}

export function assertMcpAppIdentityRoundTrip(input) {
  const identity = createMcpAppIdentity(input);
  const restored = deserializeMcpAppIdentity(serializeMcpAppIdentity(identity));
  const canonical = serializeMcpAppIdentity(identity);
  const restoredCanonical = serializeMcpAppIdentity(restored);
  if (restoredCanonical !== canonical) {
    fail('identity_round_trip_failed', 'MCP app identity serialization round-trip failed', {
      expected: canonical,
      actual: restoredCanonical,
    });
  }
  return restored;
}
