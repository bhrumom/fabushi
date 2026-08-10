const SAFE_ID = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,191}$/;
const SAFE_OWNER = /^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$/;
const SAFE_REPOSITORY = /^[A-Za-z0-9_.-]{1,100}$/;
const SHA1 = /^[a-f0-9]{40}$/;
const SHA256 = /^[a-f0-9]{64}$/;

export const DEPLOYMENT_TARGETS = Object.freeze([
  'local-only',
  'official-managed-github',
  'user-github',
]);

export const INTERNAL_SOURCE_TARGETS = Object.freeze([
  ...DEPLOYMENT_TARGETS,
  'official-source-github',
]);

export const SOURCE_CUSTODIES = Object.freeze(['device', 'platform-managed', 'user-owned']);
export const SOURCE_PROVIDERS = Object.freeze(['local', 'github']);
export const SOURCE_ACTORS = Object.freeze(['user', 'platform']);
export const SOURCE_TRANSPORTS = Object.freeze(['local-fs', 'github-mcp', 'github-app-api']);
export const HOSTING_PROVIDERS = Object.freeze([
  'none',
  'github-pages',
  'cloudflare-pages',
  'cloudflare-workers',
  'external',
]);
export const RUNTIME_PROFILES = Object.freeze(['local-native', 'local-web-wasm', 'web-static', 'remote-edge']);
export const OFFICIAL_STATUSES = Object.freeze(['official', 'community', 'unverified']);

export const DEPLOYMENT_STATES = Object.freeze([
  'local-only',
  'source-hosted',
  'build-passed',
  'deployed',
  'marketplace-listed',
  'installable',
  'failed',
  'blocked',
]);

const STATE_TRANSITIONS = Object.freeze({
  'local-only': new Set(['source-hosted', 'failed', 'blocked']),
  'source-hosted': new Set(['build-passed', 'failed', 'blocked']),
  'build-passed': new Set(['deployed', 'failed', 'blocked']),
  deployed: new Set(['marketplace-listed', 'failed', 'blocked']),
  'marketplace-listed': new Set(['installable', 'failed', 'blocked']),
  installable: new Set(['blocked']),
  failed: new Set(['local-only', 'source-hosted']),
  blocked: new Set(['local-only', 'source-hosted']),
});

const SECRET_KEY = /(access[_-]?token|refresh[_-]?token|connector[_-]?secret|github[_-]?token|password|authorization|cookie|private[_-]?key)/i;
const SECRET_CONTENT = /(github_pat_[A-Za-z0-9_]+|gh[pousr]_[A-Za-z0-9]+|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|Authorization:\s*Bearer\s+\S+|Set-Cookie:\s*\S+)/i;
const DENY_PATH = /(^|\/)(?:\.git|node_modules|\.dart_tool|\.idea|\.vscode|build|dist|coverage|\.cache|tmp|temp)(?:\/|$)|(^|\/)\.env(?:\.[^/]+)?$|\.(?:sqlite3?|db|log|pem|p12|pfx|key)$/i;

export class MiniAppDeploymentContractError extends Error {
  constructor(code, message, details = {}) {
    super(message);
    this.name = 'MiniAppDeploymentContractError';
    this.code = code;
    this.details = details;
  }
}

function fail(code, message, details = {}) {
  throw new MiniAppDeploymentContractError(code, message, details);
}

function requiredString(value, field, max = 256) {
  const normalized = String(value ?? '').trim();
  if (!normalized || normalized.length > max) {
    fail('field_invalid', `${field} is required`, { field });
  }
  return normalized;
}

function optionalString(value, field, max = 256) {
  if (value == null || value === '') return null;
  return requiredString(value, field, max);
}

function normalizeOfficialStatus(value) {
  const raw = requiredString(value, 'officialStatus').toLowerCase();
  const status = raw === 'user' ? 'community' : raw;
  if (!OFFICIAL_STATUSES.includes(status)) {
    fail('official_status_invalid', 'officialStatus must be official, community, or unverified');
  }
  return status;
}

function normalizeHostingFields(value = {}) {
  let hostingProvider = requiredString(value.hostingProvider ?? 'none', 'hostingProvider').toLowerCase();
  if (hostingProvider === 'cloudflare') hostingProvider = 'cloudflare-workers';
  if (!HOSTING_PROVIDERS.includes(hostingProvider)) {
    fail('hosting_provider_invalid', 'unsupported hosting provider', { hostingProvider });
  }
  const defaultRuntimeProfile = hostingProvider === 'none'
    ? 'local-web-wasm'
    : hostingProvider === 'cloudflare-workers'
      ? 'remote-edge'
      : 'web-static';
  const runtimeProfile = requiredString(value.runtimeProfile ?? defaultRuntimeProfile, 'runtimeProfile').toLowerCase();
  if (!RUNTIME_PROFILES.includes(runtimeProfile)) {
    fail('runtime_profile_invalid', 'unsupported runtime profile', { runtimeProfile });
  }
  if (['github-pages', 'cloudflare-pages'].includes(hostingProvider) && runtimeProfile !== 'web-static') {
    fail('hosting_runtime_mismatch', 'static hosting requires runtimeProfile=web-static', { hostingProvider, runtimeProfile });
  }
  if (hostingProvider === 'cloudflare-workers' && runtimeProfile !== 'remote-edge') {
    fail('hosting_runtime_mismatch', 'Cloudflare Workers requires runtimeProfile=remote-edge', { hostingProvider, runtimeProfile });
  }
  return { hostingProvider, runtimeProfile };
}

function assertDerivedField(value, field, expected, code) {
  if (value != null && String(value).trim() !== expected) {
    fail(code, `${field} is derived from deploymentTarget and cannot be spoofed`, { expected });
  }
}

function normalizeOwner(value, field) {
  const owner = requiredString(value, field, 39);
  if (!SAFE_OWNER.test(owner)) fail('repository_owner_invalid', `${field} is not a valid GitHub owner`, { field });
  return owner;
}

function normalizeRepositoryName(value, field) {
  const repository = requiredString(value, field, 100);
  if (!SAFE_REPOSITORY.test(repository)) fail('repository_name_invalid', `${field} is not a valid GitHub repository name`, { field });
  return repository;
}

function stableObject(value) {
  if (Array.isArray(value)) return value.map(stableObject);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(Object.keys(value).sort().map((key) => [key, stableObject(value[key])]));
}

export function canonicalJson(value) {
  return JSON.stringify(stableObject(value));
}

export function assertManagedUserAppsOwner(config = {}) {
  const officialSourceOwner = normalizeOwner(config.officialSourceOwner ?? 'bhrumom', 'officialSourceOwner');
  const managedUserAppsOwner = normalizeOwner(config.managedUserAppsOwner, 'managedUserAppsOwner');
  if (managedUserAppsOwner.toLowerCase() === officialSourceOwner.toLowerCase()) {
    fail(
      'managed_owner_trust_boundary',
      'managed user apps must be hosted outside the official source organization',
      { officialSourceOwner, managedUserAppsOwner },
    );
  }
  return { officialSourceOwner, managedUserAppsOwner };
}

export function normalizeMiniAppIdentity(value, config = {}) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    fail('identity_invalid', 'identity must be an object');
  }
  const deploymentTarget = requiredString(value.deploymentTarget, 'deploymentTarget');
  if (!INTERNAL_SOURCE_TARGETS.includes(deploymentTarget)) {
    fail('deployment_target_invalid', 'unsupported deployment target', { deploymentTarget });
  }
  const author = requiredString(value.author, 'author', 160);
  const publisher = requiredString(value.publisher, 'publisher', 160);
  const officialStatus = normalizeOfficialStatus(value.officialStatus);
  const { hostingProvider, runtimeProfile } = normalizeHostingFields(value);

  let sourceHost;
  let sourceCustody;
  let sourceProvider;
  let sourceActor;
  let sourceTransport;
  let repositoryOwner = null;
  let repositoryName = null;
  let repositoryId = null;

  if (deploymentTarget === 'local-only') {
    sourceHost = 'local';
    sourceCustody = 'device';
    sourceProvider = 'local';
    sourceActor = 'user';
    sourceTransport = 'local-fs';
    if (value.repositoryOwner || value.repositoryName || value.repositoryId || value.provider === 'github' || value.sourceProvider === 'github') {
      fail('local_remote_identity_conflict', 'local-only projects cannot claim a remote repository identity');
    }
    if (officialStatus === 'official') {
      fail('official_badge_forbidden', 'local-only user projects cannot claim official status');
    }
  } else {
    sourceHost = 'github';
    sourceProvider = 'github';
    repositoryOwner = normalizeOwner(value.repositoryOwner, 'repositoryOwner');
    repositoryName = normalizeRepositoryName(value.repositoryName, 'repositoryName');
    repositoryId = Number(value.repositoryId);
    if (!Number.isSafeInteger(repositoryId) || repositoryId <= 0) {
      fail('repository_id_invalid', 'repositoryId must be a positive GitHub repository ID');
    }

    if (deploymentTarget === 'official-managed-github') {
      const owners = assertManagedUserAppsOwner(config);
      if (repositoryOwner.toLowerCase() !== owners.managedUserAppsOwner.toLowerCase()) {
        fail('managed_owner_mismatch', 'managed user source must use the configured managed user apps organization');
      }
      if (officialStatus === 'official') {
        fail('official_badge_forbidden', 'managed user apps cannot claim official status');
      }
      sourceCustody = 'platform-managed';
      sourceActor = 'platform';
      sourceTransport = 'github-app-api';
    } else if (deploymentTarget === 'user-github') {
      if (officialStatus === 'official') {
        fail('official_badge_forbidden', 'user GitHub apps cannot claim official status');
      }
      sourceCustody = 'user-owned';
      sourceActor = 'user';
      sourceTransport = 'github-mcp';
    } else {
      const officialSourceOwner = normalizeOwner(config.officialSourceOwner ?? 'bhrumom', 'officialSourceOwner');
      if (repositoryOwner.toLowerCase() !== officialSourceOwner.toLowerCase() || officialStatus !== 'official') {
        fail('official_source_identity_invalid', 'official source identity must be official and owned by the official source organization');
      }
      sourceCustody = 'platform-managed';
      sourceActor = 'platform';
      sourceTransport = 'github-app-api';
    }
  }

  assertDerivedField(value.sourceHost, 'sourceHost', sourceHost, 'source_host_mismatch');
  assertDerivedField(value.sourceCustody, 'sourceCustody', sourceCustody, 'source_custody_mismatch');
  assertDerivedField(value.sourceProvider ?? value.provider, 'sourceProvider', sourceProvider, 'source_provider_mismatch');
  assertDerivedField(value.sourceActor ?? value.actor, 'sourceActor', sourceActor, 'source_actor_mismatch');
  assertDerivedField(value.sourceTransport ?? value.transport, 'sourceTransport', sourceTransport, 'source_transport_mismatch');

  return {
    author,
    sourceHost,
    sourceCustody,
    sourceProvider,
    sourceActor,
    sourceTransport,
    repositoryOwner,
    repositoryName,
    repositoryId,
    publisher,
    officialStatus,
    hostingProvider,
    runtimeProfile,
    deploymentTarget,
  };
}

export function serializeMiniAppIdentity(value, config = {}) {
  return canonicalJson(normalizeMiniAppIdentity(value, config));
}

export function deserializeMiniAppIdentity(serialized, config = {}) {
  return normalizeMiniAppIdentity(JSON.parse(String(serialized)), config);
}

export function assertNoConnectorSecrets(value) {
  const visit = (node, path = '$') => {
    if (typeof node === 'string') {
      if (SECRET_CONTENT.test(node)) {
        fail('connector_secret_forbidden', 'connector credentials must never enter Fabushi payloads or persistence', { path });
      }
      return;
    }
    if (Array.isArray(node)) {
      node.forEach((entry, index) => visit(entry, `${path}[${index}]`));
      return;
    }
    if (!node || typeof node !== 'object') return;
    for (const [key, entry] of Object.entries(node)) {
      const nextPath = `${path}.${key}`;
      if (SECRET_KEY.test(key) && entry != null && String(entry).trim() !== '') {
        fail('connector_secret_forbidden', 'connector credentials must never enter Fabushi payloads or persistence', { path: nextPath });
      }
      visit(entry, nextPath);
    }
  };
  visit(value);
  return true;
}

export function normalizeSourceRegistration(value, { explicitOwnerRequired = true } = {}) {
  assertNoConnectorSecrets(value);
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    fail('source_registration_invalid', 'source registration must be an object');
  }
  const localProjectId = requiredString(value.localProjectId, 'localProjectId', 192);
  if (!SAFE_ID.test(localProjectId)) fail('local_project_id_invalid', 'localProjectId is invalid');
  const target = requiredString(value.target, 'target');
  if (!['official-managed-github', 'user-github'].includes(target)) {
    fail('deployment_target_invalid', 'source registration requires a hosted GitHub target');
  }
  const repository = requiredString(value.repository, 'repository', 200);
  const parts = repository.split('/');
  if (parts.length !== 2) fail('repository_invalid', 'repository must be owner/name');
  const owner = normalizeOwner(parts[0], 'repository.owner');
  const name = normalizeRepositoryName(parts[1], 'repository.name');
  if (target === 'user-github' && explicitOwnerRequired && !value.ownerSelectionConfirmed) {
    fail('explicit_owner_required', 'user GitHub deployment requires explicit owner/repository confirmation');
  }
  const repositoryId = Number(value.repositoryId);
  if (!Number.isSafeInteger(repositoryId) || repositoryId <= 0) fail('repository_id_invalid', 'repositoryId is invalid');
  const defaultBranch = requiredString(value.defaultBranch, 'defaultBranch', 255);
  const commit = requiredString(value.commit, 'commit', 40).toLowerCase();
  const treeHash = requiredString(value.treeHash, 'treeHash', 40).toLowerCase();
  if (!SHA1.test(commit) || !SHA1.test(treeHash)) fail('source_sha_invalid', 'commit and treeHash must be exact Git SHA-1 values');
  return {
    localProjectId,
    target,
    repositoryId,
    repository: `${owner}/${name}`,
    repositoryOwner: owner,
    repositoryName: name,
    defaultBranch,
    commit,
    treeHash,
  };
}

export function transitionDeploymentState(current, next) {
  if (!DEPLOYMENT_STATES.includes(current) || !DEPLOYMENT_STATES.includes(next)) {
    fail('deployment_state_invalid', 'unsupported deployment state', { current, next });
  }
  if (current === next) return next;
  if (!STATE_TRANSITIONS[current]?.has(next)) {
    fail('deployment_state_transition_invalid', `cannot transition deployment from ${current} to ${next}`, { current, next });
  }
  return next;
}

function normalizeSnapshotPath(value) {
  const path = requiredString(value, 'snapshot.path', 500).replace(/\\/g, '/').replace(/^\.\//, '');
  if (path.startsWith('/') || path.includes('../') || path === '..' || DENY_PATH.test(path)) {
    fail('snapshot_path_forbidden', 'source snapshot contains a forbidden or unsafe path', { path });
  }
  return path;
}

export function normalizeSourceSnapshot(entries) {
  if (!Array.isArray(entries) || entries.length === 0) fail('snapshot_empty', 'source snapshot must contain files');
  const normalized = entries.map((entry) => {
    if (!entry || typeof entry !== 'object' || Array.isArray(entry)) fail('snapshot_entry_invalid', 'snapshot entry must be an object');
    const path = normalizeSnapshotPath(entry.path);
    const content = String(entry.content ?? '');
    if (SECRET_CONTENT.test(content)) fail('snapshot_secret_detected', 'source snapshot contains credential-like material', { path });
    return { path, content };
  }).sort((a, b) => a.path.localeCompare(b.path));
  const seen = new Set();
  for (const entry of normalized) {
    if (seen.has(entry.path)) fail('snapshot_duplicate_path', 'source snapshot contains a duplicate path', { path: entry.path });
    seen.add(entry.path);
  }
  return normalized;
}

export async function createDeterministicSourceSnapshot(entries) {
  const normalized = normalizeSourceSnapshot(entries);
  const payload = normalized.map((entry) => `${entry.path.length}:${entry.path}:${entry.content.length}:${entry.content}`).join('\n');
  const bytes = new TextEncoder().encode(payload);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  const sourceArchiveSha256 = [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
  return {
    files: normalized,
    sourceArchiveSha256,
    sourceTreeHash: sourceArchiveSha256,
  };
}

export function remoteSyncDecision({ lastPushedCommit, remoteHeadCommit, remoteContainsLastPushedCommit }) {
  const localBase = optionalString(lastPushedCommit, 'lastPushedCommit', 40);
  const remoteHead = optionalString(remoteHeadCommit, 'remoteHeadCommit', 40);
  if (localBase && !SHA1.test(localBase.toLowerCase())) fail('source_sha_invalid', 'lastPushedCommit must be a SHA-1');
  if (remoteHead && !SHA1.test(remoteHead.toLowerCase())) fail('source_sha_invalid', 'remoteHeadCommit must be a SHA-1');
  if (!remoteHead || remoteHead === localBase) return { action: 'push', force: false };
  if (remoteContainsLastPushedCommit === true) return { action: 'rebase-or-merge', force: false };
  return { action: 'compare-before-write', force: false };
}

export function normalizeRuntimeDeployment(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) fail('runtime_deployment_invalid', 'runtime deployment must be an object');
  const requestedHostingProvider = value.hostingProvider ?? value.target ?? 'none';
  const { hostingProvider, runtimeProfile } = normalizeHostingFields({
    hostingProvider: requestedHostingProvider,
    runtimeProfile: value.runtimeProfile,
  });
  if (hostingProvider === 'github-pages') {
    if (value.userConfirmedPublic !== true || value.staticOnly !== true || value.pagesPolicyEligible !== true) {
      fail('github_pages_policy_rejected', 'GitHub Pages requires explicit public consent and a policy-eligible static app');
    }
  }
  if (hostingProvider === 'cloudflare-pages' && value.staticOnly !== true) {
    fail('cloudflare_pages_dynamic_rejected', 'Cloudflare Pages is reserved for static hosting in this deployment contract');
  }
  if (hostingProvider === 'none' && value.publicUrl) fail('runtime_target_invalid', 'hosting provider none cannot claim a public URL');
  return {
    hostingProvider,
    runtimeProfile,
    target: hostingProvider,
    publicUrl: optionalString(value.publicUrl, 'runtime.publicUrl', 2048),
    staticOnly: value.staticOnly === true,
    userConfirmedPublic: value.userConfirmedPublic === true,
    pagesPolicyEligible: value.pagesPolicyEligible === true,
  };
}

export function createTakeoverPlan(value) {
  assertNoConnectorSecrets(value);
  if (value.userConfirmed !== true) fail('takeover_confirmation_required', 'repository takeover requires explicit confirmation');
  if (value.targetWritePermission !== true) fail('takeover_permission_required', 'target GitHub owner requires write permission');
  const source = normalizeSourceRegistration({ ...value.source, ownerSelectionConfirmed: true }, { explicitOwnerRequired: false });
  const targetOwner = normalizeOwner(value.targetOwner, 'targetOwner');
  const targetRepository = normalizeRepositoryName(value.targetRepository, 'targetRepository');
  return {
    sourceRepositoryId: source.repositoryId,
    sourceRepository: source.repository,
    targetRepository: `${targetOwner}/${targetRepository}`,
    preserveGitHistory: true,
    preserveIssuesPullRequestsReleases: value.transferSupported === true,
    mode: value.transferSupported === true ? 'github-transfer' : 'controlled-migration',
    deleteSourceAfterMigration: false,
  };
}

export function evaluateQuota(usage, limits) {
  const keys = ['repositories', 'builds', 'storageBytes', 'requests'];
  const exceeded = keys.filter((key) => Number(usage?.[key] ?? 0) > Number(limits?.[key] ?? Number.POSITIVE_INFINITY));
  return { allowed: exceeded.length === 0, exceeded, localWorkspaceWritable: true };
}

export function aggregateCostEvents(events) {
  if (!Array.isArray(events)) fail('cost_events_invalid', 'cost events must be an array');
  const totals = new Map();
  for (const event of events) {
    const userId = requiredString(event.userId, 'cost.userId', 192);
    const projectId = requiredString(event.projectId, 'cost.projectId', 192);
    const deploymentId = requiredString(event.deploymentId, 'cost.deploymentId', 192);
    const key = `${userId}\u0000${projectId}\u0000${deploymentId}`;
    const current = totals.get(key) ?? { userId, projectId, deploymentId, actionsMinutes: 0, artifactBytes: 0, storageBytes: 0 };
    current.actionsMinutes += Number(event.actionsMinutes ?? 0);
    current.artifactBytes += Number(event.artifactBytes ?? 0);
    current.storageBytes += Number(event.storageBytes ?? 0);
    totals.set(key, current);
  }
  return [...totals.values()].sort((a, b) => `${a.userId}/${a.projectId}/${a.deploymentId}`.localeCompare(`${b.userId}/${b.projectId}/${b.deploymentId}`));
}

export function lifecycleDecision(event) {
  const type = requiredString(event?.type, 'lifecycle.type');
  if (type === 'fabushi-account-delete') {
    return {
      localWorkspaceAction: 'user-choice',
      managedRepositoryAction: 'separate-confirmation-required',
      userGitHubRepositoryAction: 'leave-untouched',
      auditRequired: true,
    };
  }
  if (['archive', 'restore', 'delete-managed-repository'].includes(type)) {
    return { localWorkspaceAction: 'preserve', managedRepositoryAction: type, userGitHubRepositoryAction: 'leave-untouched', auditRequired: true };
  }
  fail('lifecycle_event_invalid', 'unsupported lifecycle event', { type });
}

export function validateReleaseIdentityBinding(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) fail('release_binding_invalid', 'release binding must be an object');
  const sourceCommit = requiredString(value.sourceCommit, 'sourceCommit', 40).toLowerCase();
  const sourceTreeHash = requiredString(value.sourceTreeHash, 'sourceTreeHash', 40).toLowerCase();
  if (!SHA1.test(sourceCommit) || !SHA1.test(sourceTreeHash)) fail('source_sha_invalid', 'release source commit/tree hash are invalid');
  const subjects = Array.isArray(value.subjects) ? value.subjects : [];
  if (subjects.length === 0) fail('release_subjects_missing', 'release must declare artifact/SBOM/attestation subjects');
  for (const subject of subjects) {
    if (String(subject.sourceCommit).toLowerCase() !== sourceCommit || String(subject.sourceTreeHash).toLowerCase() !== sourceTreeHash) {
      fail('provenance_identity_mismatch', 'release subject is not bound to the same source commit/tree', { id: subject.id });
    }
    const digest = String(subject.sha256 ?? '').toLowerCase();
    if (!SHA256.test(digest)) fail('artifact_digest_invalid', 'release subject SHA-256 is invalid', { id: subject.id });
  }
  return { sourceCommit, sourceTreeHash, subjectCount: subjects.length };
}


export function marketplaceSourceLabels(value, config = {}) {
  const identity = normalizeMiniAppIdentity(value, config);
  const repository = identity.repositoryOwner && identity.repositoryName
    ? `${identity.repositoryOwner}/${identity.repositoryName}`
    : null;
  const sourceHosting = identity.deploymentTarget === 'local-only'
    ? 'local-workspace'
    : identity.deploymentTarget === 'official-managed-github'
      ? 'fabushi-managed-github'
      : identity.deploymentTarget === 'user-github'
        ? 'user-github'
        : 'official-github';
  return {
    author: identity.author,
    sourceHosting,
    sourceCustody: identity.sourceCustody,
    repository,
    repositoryId: identity.repositoryId,
    publisher: identity.publisher,
    badge: identity.officialStatus === 'official' ? 'official' : 'user-work',
    officialStatus: identity.officialStatus,
    sourceProvider: identity.sourceProvider,
    sourceActor: identity.sourceActor,
    sourceTransport: identity.sourceTransport,
    hostingProvider: identity.hostingProvider,
    runtimeProfile: identity.runtimeProfile,
  };
}

export function assertReleaseTrustBoundary(value, config = {}) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    fail('release_trust_invalid', 'release trust request must be an object');
  }
  const identity = normalizeMiniAppIdentity(value.identity, config);
  const official = identity.deploymentTarget === 'official-source-github' && identity.officialStatus === 'official';
  const requestedOfficialBadge = value.requestedOfficialBadge === true;
  const requestedOfficialSigning = value.requestedOfficialSigning === true;
  const requestedOfficialOidc = value.requestedOidcTrust === 'official';
  if (!official && (requestedOfficialBadge || requestedOfficialSigning || requestedOfficialOidc)) {
    fail(
      'official_trust_forbidden',
      'user and managed-user sources cannot claim official badge, official signing, or official OIDC trust',
      { deploymentTarget: identity.deploymentTarget },
    );
  }
  return {
    officialBadgeAllowed: official,
    officialSigningAllowed: official,
    oidcTrustDomain: official ? 'official' : identity.deploymentTarget === 'official-managed-github' ? 'managed-user' : 'user',
    identity,
  };
}


export const GITHUB_APP_TOKEN_POLICY = Object.freeze({
  credentialType: 'installation-token',
  clientReceivesCredential: false,
  maxLifetime: 'short-lived',
  forbidden: ['organization-pat', 'personal-access-token'],
});

export function assertGithubAppControlPlane(value = {}) {
  const credentialType = String(value.credentialType ?? '').trim();
  if (credentialType !== GITHUB_APP_TOKEN_POLICY.credentialType) {
    fail('github_app_token_required', 'managed GitHub control plane requires short-lived GitHub App installation tokens');
  }
  if (value.clientReceivesCredential === true) {
    fail('github_app_credential_exposure', 'GitHub App installation credentials cannot be sent to clients');
  }
  if (value.organizationPat === true || value.personalAccessToken === true) {
    fail('github_app_pat_forbidden', 'organization PAT and personal access token are forbidden for managed control plane');
  }
  return { ...GITHUB_APP_TOKEN_POLICY };
}

const EMAIL_LIKE = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i;
const PHONE_LIKE = /(?:\+?\d[\s().-]*){7,}/;

function compactPiiToken(value) {
  return String(value ?? '').toLowerCase().replace(/[^a-z0-9]/g, '');
}

export function createManagedRepositoryName({ slug, publicId, piiValues = [] } = {}) {
  const rawSlug = requiredString(slug, 'slug', 160);
  const rawPublicId = requiredString(publicId, 'publicId', 64);
  if (EMAIL_LIKE.test(rawSlug) || PHONE_LIKE.test(rawSlug)) {
    fail('repository_name_pii', 'managed repository names cannot contain email addresses or phone numbers');
  }
  const safeSlug = rawSlug
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48) || 'app';
  const safePublicId = rawPublicId
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '')
    .slice(0, 16);
  if (!safePublicId) fail('repository_public_id_invalid', 'publicId must contain a non-PII stable identifier');
  const repositoryName = `miniapp-${safeSlug}-${safePublicId}`.slice(0, 100);
  const compactName = compactPiiToken(repositoryName);
  for (const value of piiValues) {
    const token = compactPiiToken(value);
    if (token.length >= 4 && compactName.includes(token)) {
      fail('repository_name_pii', 'managed repository name contains a protected user identifier');
    }
  }
  return normalizeRepositoryName(repositoryName, 'repositoryName');
}

export function selectManagedRepositoryShard(shards, config = {}) {
  if (!Array.isArray(shards) || shards.length === 0) {
    fail('managed_shard_unavailable', 'managed user app repository shards are not configured');
  }
  const officialSourceOwner = normalizeOwner(config.officialSourceOwner ?? 'bhrumom', 'officialSourceOwner');
  const eligible = shards.map((shard, index) => {
    if (!shard || typeof shard !== 'object' || Array.isArray(shard)) {
      fail('managed_shard_invalid', 'managed repository shard must be an object', { index });
    }
    const owner = normalizeOwner(shard.owner, `shards[${index}].owner`);
    if (owner.toLowerCase() === officialSourceOwner.toLowerCase()) {
      fail('managed_owner_trust_boundary', 'managed repository shards cannot use the official source organization', { owner });
    }
    const repositoryCount = Number(shard.repositoryCount);
    const hardStopRepositoryCount = Number(shard.hardStopRepositoryCount);
    if (!Number.isSafeInteger(repositoryCount) || repositoryCount < 0 || !Number.isSafeInteger(hardStopRepositoryCount) || hardStopRepositoryCount <= 0) {
      fail('managed_shard_capacity_invalid', 'managed repository shard capacity must be explicitly configured', { owner });
    }
    return {
      owner,
      repositoryCount,
      hardStopRepositoryCount,
      acceptingNewRepositories: shard.acceptingNewRepositories !== false,
    };
  }).filter((shard) => shard.acceptingNewRepositories && shard.repositoryCount < shard.hardStopRepositoryCount);

  if (eligible.length === 0) {
    fail('managed_shard_capacity_exhausted', 'all managed repository shards are closed or at their safety watermark');
  }
  eligible.sort((left, right) => left.repositoryCount - right.repositoryCount || left.owner.localeCompare(right.owner));
  return eligible[0];
}

function normalizeProvisioningRequest(value, config) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) fail('managed_repo_request_invalid', 'managed repository request must be an object');
  const subjectId = requiredString(value.subjectId, 'subjectId', 192);
  const idempotencyKey = requiredString(value.idempotencyKey, 'idempotencyKey', 192);
  const deploymentId = requiredString(value.deploymentId, 'deploymentId', 192);
  const snapshotSha256 = requiredString(value.snapshotSha256, 'snapshotSha256', 64).toLowerCase();
  if (!SHA256.test(snapshotSha256)) fail('snapshot_sha_invalid', 'snapshotSha256 must be a 64 character SHA-256 digest');
  const shard = selectManagedRepositoryShard(value.shards, config);
  const repositoryName = createManagedRepositoryName({ slug: value.slug, publicId: value.publicId, piiValues: value.piiValues });
  const fingerprint = canonicalJson({ deploymentId, snapshotSha256, owner: shard.owner, repositoryName });
  return {
    subjectId,
    idempotencyKey,
    claimKey: `${subjectId}:${idempotencyKey}`,
    deploymentId,
    snapshotSha256,
    shard,
    repositoryName,
    fingerprint,
  };
}

export function createManagedRepositoryProvisioner({ claims, github, officialSourceOwner = 'bhrumom' } = {}) {
  if (!claims || typeof claims.get !== 'function' || typeof claims.claim !== 'function' || typeof claims.update !== 'function') {
    fail('managed_repo_claim_store_required', 'managed repository provisioning requires a persistent idempotency claim store');
  }
  if (!github || typeof github.createRepository !== 'function' || typeof github.reconcileRepository !== 'function') {
    fail('managed_repo_github_adapter_required', 'managed repository provisioning requires GitHub create and reconcile adapters');
  }
  const inflight = new Map();

  async function finishFromRepository(request, repository) {
    const repositoryId = Number(repository?.repositoryId ?? repository?.id);
    if (!Number.isSafeInteger(repositoryId) || repositoryId <= 0) {
      fail('managed_repo_receipt_invalid', 'GitHub repository receipt is missing a stable repository ID');
    }
    const receipt = {
      state: 'created',
      repositoryId,
      repositoryOwner: request.shard.owner,
      repositoryName: request.repositoryName,
      deploymentId: request.deploymentId,
      snapshotSha256: request.snapshotSha256,
      fingerprint: request.fingerprint,
    };
    await claims.update(request.claimKey, receipt);
    return receipt;
  }

  async function provisionOnce(value) {
    const request = normalizeProvisioningRequest(value, { officialSourceOwner });
    let existing = await claims.get(request.claimKey);
    if (existing && existing.fingerprint !== request.fingerprint) {
      fail('idempotency_conflict', 'idempotency key was already used for a different managed repository request');
    }
    if (existing?.repositoryId) return existing;

    if (!existing) {
      const claimed = await claims.claim(request.claimKey, {
        state: 'claimed',
        fingerprint: request.fingerprint,
        deploymentId: request.deploymentId,
        snapshotSha256: request.snapshotSha256,
        repositoryOwner: request.shard.owner,
        repositoryName: request.repositoryName,
      });
      existing = claimed?.claim ?? claimed;
      if (existing?.fingerprint !== request.fingerprint) {
        fail('idempotency_conflict', 'idempotency key was concurrently claimed for a different managed repository request');
      }
      if (existing?.repositoryId) return existing;
      if (claimed?.created === false) {
        const reconciled = await github.reconcileRepository({ owner: request.shard.owner, name: request.repositoryName, deploymentId: request.deploymentId });
        if (reconciled) return finishFromRepository(request, reconciled);
        fail('managed_repo_provision_in_progress', 'managed repository creation is already in progress for this idempotency key');
      }
    } else {
      const reconciled = await github.reconcileRepository({ owner: request.shard.owner, name: request.repositoryName, deploymentId: request.deploymentId });
      if (reconciled) return finishFromRepository(request, reconciled);
      if (existing.state === 'outcome-unknown' || existing.state === 'creating' || existing.state === 'claimed') {
        fail('managed_repo_outcome_unknown', 'repository create outcome is unknown; reconciliation must complete before retrying creation');
      }
    }

    await claims.update(request.claimKey, { state: 'creating' });
    try {
      const repository = await github.createRepository({
        owner: request.shard.owner,
        name: request.repositoryName,
        visibility: 'private',
        deploymentId: request.deploymentId,
        idempotencyKey: request.idempotencyKey,
      });
      return await finishFromRepository(request, repository);
    } catch (error) {
      if (error?.outcomeUnknown === true || error?.code === 'outcome-unknown') {
        await claims.update(request.claimKey, { state: 'outcome-unknown' });
        const reconciled = await github.reconcileRepository({ owner: request.shard.owner, name: request.repositoryName, deploymentId: request.deploymentId });
        if (reconciled) return finishFromRepository(request, reconciled);
        fail('managed_repo_outcome_unknown', 'GitHub create result is unknown and no repository could be reconciled');
      }
      await claims.update(request.claimKey, { state: 'failed' });
      throw error;
    }
  }

  return async function provisionManagedRepository(value) {
    const subjectId = requiredString(value?.subjectId, 'subjectId', 192);
    const idempotencyKey = requiredString(value?.idempotencyKey, 'idempotencyKey', 192);
    const key = `${subjectId}:${idempotencyKey}`;
    if (inflight.has(key)) return inflight.get(key);
    const promise = provisionOnce(value).finally(() => inflight.delete(key));
    inflight.set(key, promise);
    return promise;
  };
}

async function digestHex(algorithm, bytes) {
  const digest = await crypto.subtle.digest(algorithm, bytes);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

async function gitBlobSha1(content) {
  const contentBytes = new TextEncoder().encode(String(content));
  const headerBytes = new TextEncoder().encode(`blob ${contentBytes.byteLength}\0`);
  const payload = new Uint8Array(headerBytes.byteLength + contentBytes.byteLength);
  payload.set(headerBytes, 0);
  payload.set(contentBytes, headerBytes.byteLength);
  return digestHex('SHA-1', payload);
}

export async function verifyManagedInitialSourcePush({
  provisioning,
  snapshotEntries,
  pushReceipt,
  remoteTree,
  officialSourceOwner = 'bhrumom',
} = {}) {
  if (!provisioning || typeof provisioning !== 'object' || Array.isArray(provisioning)) {
    fail('managed_repo_provisioning_receipt_required', 'managed initial source push requires the repository provisioning receipt');
  }
  if (!pushReceipt || typeof pushReceipt !== 'object' || Array.isArray(pushReceipt)) {
    fail('managed_source_push_receipt_required', 'managed initial source push requires a GitHub push receipt');
  }
  if (!remoteTree || typeof remoteTree !== 'object' || Array.isArray(remoteTree) || !Array.isArray(remoteTree.files)) {
    fail('managed_source_remote_tree_required', 'managed initial source push requires the GitHub repository tree');
  }

  const repositoryId = Number(pushReceipt.repositoryId);
  const provisionedRepositoryId = Number(provisioning.repositoryId);
  if (!Number.isSafeInteger(repositoryId) || repositoryId <= 0 || repositoryId !== provisionedRepositoryId) {
    fail('managed_source_repository_mismatch', 'initial source push must target the exact provisioned repository ID');
  }

  const repositoryOwner = normalizeOwner(pushReceipt.repositoryOwner, 'pushReceipt.repositoryOwner');
  const provisionedOwner = normalizeOwner(provisioning.repositoryOwner, 'provisioning.repositoryOwner');
  const officialOwner = normalizeOwner(officialSourceOwner, 'officialSourceOwner');
  if (repositoryOwner.toLowerCase() !== provisionedOwner.toLowerCase()) {
    fail('managed_source_repository_mismatch', 'initial source push owner does not match the provisioned repository owner');
  }
  if (repositoryOwner.toLowerCase() === officialOwner.toLowerCase()) {
    fail('managed_owner_trust_boundary', 'managed user source cannot be pushed into the official source organization');
  }

  const repositoryName = normalizeRepositoryName(pushReceipt.repositoryName, 'pushReceipt.repositoryName');
  const provisionedName = normalizeRepositoryName(provisioning.repositoryName, 'provisioning.repositoryName');
  if (repositoryName !== provisionedName) {
    fail('managed_source_repository_mismatch', 'initial source push repository name does not match the provisioned repository');
  }

  const managedOrgId = requiredString(pushReceipt.managedOrgId, 'managedOrgId', 192);
  const defaultBranch = requiredString(pushReceipt.defaultBranch, 'defaultBranch', 255);
  const commit = requiredString(pushReceipt.commit, 'commit', 40).toLowerCase();
  const treeHash = requiredString(pushReceipt.treeHash, 'treeHash', 40).toLowerCase();
  if (!SHA1.test(commit) || !SHA1.test(treeHash)) {
    fail('source_sha_invalid', 'managed source push commit and treeHash must be exact Git SHA-1 values');
  }

  const remoteTreeHash = requiredString(remoteTree.treeHash, 'remoteTree.treeHash', 40).toLowerCase();
  if (!SHA1.test(remoteTreeHash) || remoteTreeHash !== treeHash) {
    fail('managed_source_tree_mismatch', 'GitHub tree does not match the commit tree recorded by the push receipt');
  }

  const snapshot = await createDeterministicSourceSnapshot(snapshotEntries);
  const snapshotSha256 = requiredString(pushReceipt.snapshotSha256, 'snapshotSha256', 64).toLowerCase();
  if (!SHA256.test(snapshotSha256) || snapshotSha256 !== snapshot.sourceArchiveSha256) {
    fail('managed_source_snapshot_mismatch', 'GitHub push receipt is not bound to the exact deterministic source snapshot');
  }
  if (provisioning.snapshotSha256 && String(provisioning.snapshotSha256).toLowerCase() !== snapshotSha256) {
    fail('managed_source_snapshot_mismatch', 'repository provisioning claim and initial source push use different source snapshots');
  }

  const expected = new Map();
  for (const file of snapshot.files) {
    expected.set(file.path, await gitBlobSha1(file.content));
  }

  const actual = new Map();
  for (const entry of remoteTree.files) {
    if (!entry || typeof entry !== 'object' || Array.isArray(entry)) {
      fail('managed_source_tree_entry_invalid', 'GitHub tree entry must be an object');
    }
    const path = normalizeSnapshotPath(entry.path);
    if (String(entry.type ?? 'blob') !== 'blob') {
      fail('managed_source_tree_entry_invalid', 'initial source tree must contain only snapshot file blobs', { path });
    }
    const sha = requiredString(entry.sha, `remoteTree.files[${path}].sha`, 40).toLowerCase();
    if (!SHA1.test(sha)) fail('managed_source_tree_entry_invalid', 'GitHub blob SHA is invalid', { path });
    if (actual.has(path)) fail('managed_source_tree_entry_invalid', 'GitHub tree contains a duplicate file path', { path });
    actual.set(path, sha);
  }

  if (actual.size !== expected.size) {
    fail('managed_source_tree_mismatch', 'GitHub repository file count differs from the source snapshot', {
      expected: expected.size,
      actual: actual.size,
    });
  }
  for (const [path, sha] of expected) {
    if (actual.get(path) !== sha) {
      fail('managed_source_tree_mismatch', 'GitHub repository bytes differ from the source snapshot', { path });
    }
  }

  return {
    managedOrgId,
    repositoryId,
    repositoryOwner,
    repositoryName,
    defaultBranch,
    commit,
    treeHash,
    snapshotSha256,
    sourceState: 'hosted',
    sourceProvider: 'github',
    sourceActor: 'platform',
    sourceTransport: 'github-app-api',
    sourceCustody: 'platform-managed',
    hostingProvider: 'none',
    hostingState: 'none',
    officialStatus: 'community',
  };
}
