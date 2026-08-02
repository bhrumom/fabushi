const SHA1 = /^[0-9a-f]{40}$/;
const SHA256 = /^[0-9a-f]{64}$/;
const REPOSITORY = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;
const SAFE_ID = /^[a-z0-9](?:[a-z0-9._-]{0,126}[a-z0-9])?$/;
const SAFE_VERSION = /^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/;
const SAFE_BRANCH = /^[^\s~^:?*\[\\]+$/;
const VALID_VISIBILITY = new Set(['public', 'private', 'internal']);
const VALID_KINDS = new Set(['common', 'native-cli', 'web-wasm']);
const VALID_OSES = new Set(['macos', 'windows', 'linux']);
const VALID_ARCHES = new Set(['arm64', 'x64']);
const VALID_WEB_TARGETS = new Set(['ios', 'android', 'desktop-webview', 'web', 'pwa']);

export const MCP_APPS_STABLE_VERSION = '2026-01-26';
export const MCP_APPS_EXTENSION = 'io.modelcontextprotocol/ui';
export const MCP_APPS_MIME = 'text/html;profile=mcp-app';

function fail(code, message, details = undefined) {
  const error = new Error(message);
  error.code = code;
  if (details !== undefined) error.details = details;
  throw error;
}

function requiredString(value, field, maxLength = 512) {
  const normalized = String(value ?? '').trim();
  if (!normalized || normalized.length > maxLength) {
    fail('manifest_invalid', `${field} is required`, { field });
  }
  return normalized;
}

function exactSha(value, pattern, field) {
  const normalized = requiredString(value, field).toLowerCase();
  if (!pattern.test(normalized)) {
    fail('manifest_invalid', `${field} must be an exact hexadecimal digest`, { field });
  }
  return normalized;
}

function httpsUrl(value, field) {
  let url;
  try {
    url = new URL(requiredString(value, field));
  } catch {
    fail('manifest_invalid', `${field} must be a valid URL`, { field });
  }
  if (url.protocol !== 'https:' || url.username || url.password || url.hash) {
    fail('manifest_invalid', `${field} must be an HTTPS URL without credentials or fragment`, { field });
  }
  return url.toString();
}

function safeSubdirectory(value) {
  const normalized = String(value ?? '.').trim().replace(/\\/g, '/').replace(/^\.\//, '');
  if (!normalized || normalized === '.') return '.';
  if (normalized.startsWith('/') || normalized.endsWith('/') || normalized.split('/').some((part) => !part || part === '.' || part === '..')) {
    fail('source_invalid', 'source.subdirectory must be a repository-relative directory');
  }
  return normalized;
}

function sortedUniqueStrings(value, field, allowed = null) {
  if (!Array.isArray(value) || value.length === 0) {
    fail('manifest_invalid', `${field} must be a non-empty array`, { field });
  }
  const normalized = [...new Set(value.map((item) => requiredString(item, field, 128)))].sort();
  if (allowed && normalized.some((item) => !allowed.has(item))) {
    fail('manifest_invalid', `${field} contains an unsupported value`, { field, values: normalized });
  }
  return normalized;
}

function stableObject(value) {
  if (Array.isArray(value)) return value.map(stableObject);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(Object.keys(value).sort().map((key) => [key, stableObject(value[key])]));
}

export function canonicalJson(value) {
  return JSON.stringify(stableObject(value));
}

export function normalizeGitHubSource(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    fail('source_invalid', 'source must be an object');
  }
  const provider = requiredString(value.provider, 'source.provider').toLowerCase();
  if (provider !== 'github') fail('source_invalid', 'source.provider must be github');
  const repository = requiredString(value.repository, 'source.repository', 200);
  if (!REPOSITORY.test(repository)) fail('source_invalid', 'source.repository must be owner/name');
  const repositoryId = Number(value.repositoryId);
  if (!Number.isSafeInteger(repositoryId) || repositoryId <= 0) {
    fail('source_invalid', 'source.repositoryId must be a positive GitHub repository ID');
  }
  const defaultBranch = requiredString(value.defaultBranch, 'source.defaultBranch', 255);
  if (!SAFE_BRANCH.test(defaultBranch)) fail('source_invalid', 'source.defaultBranch is invalid');
  const visibility = requiredString(value.visibility ?? 'public', 'source.visibility').toLowerCase();
  if (!VALID_VISIBILITY.has(visibility)) fail('source_invalid', 'source.visibility is invalid');
  const licenseSpdx = requiredString(value.licenseSpdx ?? value.license, 'source.licenseSpdx', 64);
  if (licenseSpdx === 'NOASSERTION' || licenseSpdx === 'NONE') {
    fail('license_required', 'a formal public release requires an explicit SPDX license');
  }
  return {
    provider,
    repositoryId,
    repository,
    defaultBranch,
    commit: exactSha(value.commit, SHA1, 'source.commit'),
    treeHash: exactSha(value.treeHash, SHA1, 'source.treeHash'),
    licenseSpdx,
    visibility,
    subdirectory: safeSubdirectory(value.subdirectory),
  };
}

function normalizeArtifact(value, sourceCommit) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    fail('artifact_invalid', 'artifact must be an object');
  }
  const kind = requiredString(value.kind, 'artifact.kind').toLowerCase();
  if (!VALID_KINDS.has(kind)) fail('artifact_invalid', `unsupported artifact kind: ${kind}`);
  const size = Number(value.size);
  if (!Number.isSafeInteger(size) || size <= 0 || size > 2 * 1024 * 1024 * 1024) {
    fail('artifact_invalid', 'artifact.size must be a positive integer below 2 GiB');
  }
  const artifact = {
    id: requiredString(value.id, 'artifact.id', 160),
    kind,
    sourceCommit: exactSha(value.sourceCommit, SHA1, 'artifact.sourceCommit'),
    url: httpsUrl(value.url, 'artifact.url'),
    sha256: exactSha(value.sha256, SHA256, 'artifact.sha256'),
    size,
    mediaType: requiredString(value.mediaType, 'artifact.mediaType', 128),
    sbomUrl: httpsUrl(value.sbomUrl, 'artifact.sbomUrl'),
    attestationUrl: httpsUrl(value.attestationUrl, 'artifact.attestationUrl'),
    minHostVersion: requiredString(value.minHostVersion, 'artifact.minHostVersion', 64),
    requiredCapabilities: Array.isArray(value.requiredCapabilities)
      ? [...new Set(value.requiredCapabilities.map((item) => requiredString(item, 'artifact.requiredCapabilities', 128)))].sort()
      : [],
  };
  if (artifact.sourceCommit !== sourceCommit) {
    fail('source_commit_mismatch', 'every artifact must bind the exact release source commit', {
      artifactId: artifact.id,
      expected: sourceCommit,
      actual: artifact.sourceCommit,
    });
  }
  if (kind === 'common') {
    artifact.platform = 'all';
  } else if (kind === 'native-cli') {
    const os = requiredString(value.os, 'artifact.os').toLowerCase();
    const architecture = requiredString(value.architecture, 'artifact.architecture').toLowerCase();
    if (!VALID_OSES.has(os) || !VALID_ARCHES.has(architecture)) {
      fail('artifact_invalid', 'native-cli requires a supported os and architecture');
    }
    artifact.os = os;
    artifact.architecture = architecture;
  } else {
    artifact.webTargets = sortedUniqueStrings(value.webTargets, 'artifact.webTargets', VALID_WEB_TARGETS);
    artifact.wasmFeatures = Array.isArray(value.wasmFeatures)
      ? [...new Set(value.wasmFeatures.map((item) => requiredString(item, 'artifact.wasmFeatures', 128)))].sort()
      : [];
  }
  return artifact;
}

function artifactSelector(artifact) {
  if (artifact.kind === 'common') return 'common';
  if (artifact.kind === 'native-cli') return `native-cli:${artifact.os}:${artifact.architecture}`;
  return `web-wasm:${artifact.webTargets.join(',')}`;
}

function normalizeToolContract(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    fail('tool_contract_invalid', 'toolContract must be an object');
  }
  const tools = sortedUniqueStrings(value.tools, 'toolContract.tools');
  return {
    schemaVersion: Number(value.schemaVersion) || 1,
    sha256: exactSha(value.sha256, SHA256, 'toolContract.sha256'),
    tools,
    errorCodes: Array.isArray(value.errorCodes)
      ? [...new Set(value.errorCodes.map((item) => requiredString(item, 'toolContract.errorCodes', 128)))].sort()
      : [],
  };
}

function normalizeMcpApps(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    fail('mcp_apps_required', 'mcpApps must be an object');
  }
  const specification = requiredString(value.specification, 'mcpApps.specification');
  const extension = requiredString(value.extension, 'mcpApps.extension');
  const mimeType = requiredString(value.mimeType, 'mcpApps.mimeType');
  if (specification !== MCP_APPS_STABLE_VERSION || extension !== MCP_APPS_EXTENSION || mimeType !== MCP_APPS_MIME) {
    fail('mcp_apps_required', 'release must use MCP Apps stable 2026-01-26');
  }
  const resources = sortedUniqueStrings(value.resources, 'mcpApps.resources');
  if (resources.some((resource) => !resource.startsWith('ui://'))) {
    fail('ui_resource_invalid', 'all MCP Apps resources must use ui://');
  }
  return {
    specification,
    extension,
    mimeType,
    resources,
    displayModes: sortedUniqueStrings(value.displayModes ?? ['inline'], 'mcpApps.displayModes'),
    cspSha256: exactSha(value.cspSha256, SHA256, 'mcpApps.cspSha256'),
  };
}

function normalizeProvenance(value, source) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    fail('provenance_invalid', 'provenance must be an object');
  }
  const repository = requiredString(value.repository, 'provenance.repository', 200);
  if (repository !== source.repository) {
    fail('source_commit_mismatch', 'provenance repository must match release source repository');
  }
  const sourceCommit = exactSha(value.sourceCommit, SHA1, 'provenance.sourceCommit');
  if (sourceCommit !== source.commit) {
    fail('source_commit_mismatch', 'provenance must bind the exact release source commit');
  }
  const event = requiredString(value.event, 'provenance.event', 64);
  if (!['release', 'protected-tag'].includes(event)) {
    fail('provenance_invalid', 'formal release provenance must come from a protected release or tag');
  }
  if (value.oidc !== true) {
    fail('oidc_required', 'formal release provenance requires GitHub Actions OIDC');
  }
  return {
    repository,
    sourceCommit,
    workflowRef: requiredString(value.workflowRef, 'provenance.workflowRef', 512),
    runId: requiredString(value.runId, 'provenance.runId', 64),
    builderId: requiredString(value.builderId, 'provenance.builderId', 512),
    event,
    oidc: true,
    sbomSha256: exactSha(value.sbomSha256, SHA256, 'provenance.sbomSha256'),
    attestationBundleSha256: exactSha(
      value.attestationBundleSha256,
      SHA256,
      'provenance.attestationBundleSha256',
    ),
  };
}

function normalizeDerivation(value, pluginId, source) {
  if (value == null) return null;
  if (typeof value !== 'object' || Array.isArray(value)) {
    fail('derivation_invalid', 'derivation must be an object');
  }
  const upstreamPluginId = requiredString(value.upstreamPluginId, 'derivation.upstreamPluginId', 128);
  if (!SAFE_ID.test(upstreamPluginId)) fail('derivation_invalid', 'upstreamPluginId is invalid');
  if (upstreamPluginId === pluginId) {
    fail('derived_plugin_id_reuse', 'a derived app must use a different plugin ID');
  }
  const upstreamRepository = requiredString(value.upstreamRepository, 'derivation.upstreamRepository', 200);
  if (!REPOSITORY.test(upstreamRepository) || upstreamRepository === source.repository) {
    fail('derivation_invalid', 'derived source must identify a distinct fork repository');
  }
  const upstreamCommit = exactSha(value.upstreamCommit, SHA1, 'derivation.upstreamCommit');
  const syncBaseCommit = exactSha(value.syncBaseCommit ?? value.upstreamCommit, SHA1, 'derivation.syncBaseCommit');
  return {
    upstreamPluginId,
    upstreamRepository,
    upstreamCommit,
    syncBaseCommit,
    permissionDiffSha256: exactSha(value.permissionDiffSha256, SHA256, 'derivation.permissionDiffSha256'),
    toolContractDiffSha256: exactSha(value.toolContractDiffSha256, SHA256, 'derivation.toolContractDiffSha256'),
    artifactDiffSha256: exactSha(value.artifactDiffSha256, SHA256, 'derivation.artifactDiffSha256'),
    trademarkNotice: requiredString(value.trademarkNotice, 'derivation.trademarkNotice', 512),
  };
}

export function normalizeReleaseManifest(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    fail('manifest_invalid', 'release manifest must be an object');
  }
  const pluginId = requiredString(value.pluginId, 'pluginId', 128);
  if (!SAFE_ID.test(pluginId)) fail('manifest_invalid', 'pluginId is invalid');
  const version = requiredString(value.version, 'version', 64);
  if (!SAFE_VERSION.test(version)) fail('manifest_invalid', 'version must be semantic versioning');
  const source = normalizeGitHubSource(value.source);
  if (!Array.isArray(value.artifacts) || value.artifacts.length < 2) {
    fail('artifact_invalid', 'release requires common plus at least one executable artifact');
  }
  const artifacts = value.artifacts.map((artifact) => normalizeArtifact(artifact, source.commit));
  const selectors = artifacts.map(artifactSelector);
  if (new Set(selectors).size !== selectors.length) {
    fail('artifact_selector_ambiguous', 'artifact platform selectors must not overlap', { selectors });
  }
  if (artifacts.filter((artifact) => artifact.kind === 'common').length !== 1) {
    fail('artifact_invalid', 'release requires exactly one common artifact');
  }
  if (!artifacts.some((artifact) => artifact.kind === 'native-cli' || artifact.kind === 'web-wasm')) {
    fail('artifact_invalid', 'release requires native-cli or web-wasm');
  }
  const manifest = {
    schemaVersion: 3,
    protocol: 'mahayana.mcp-app-release.v3',
    pluginId,
    version,
    source,
    provenance: normalizeProvenance(value.provenance, source),
    toolContract: normalizeToolContract(value.toolContract),
    mcpApps: normalizeMcpApps(value.mcpApps),
    permissionsSha256: exactSha(value.permissionsSha256, SHA256, 'permissionsSha256'),
    parentManifestSha256: exactSha(value.parentManifestSha256, SHA256, 'parentManifestSha256'),
    artifacts: artifacts.sort((left, right) => left.id.localeCompare(right.id)),
    derivation: normalizeDerivation(value.derivation, pluginId, source),
  };
  return manifest;
}

export function validateUntrustedPullRequestWorkflow(workflowText) {
  const text = String(workflowText ?? '');
  const failures = [];
  if (!/(?:^|\n)on:\s*(?:\n\s+)?pull_request\s*:/m.test(text) && !/(?:^|\n)on:\s*\[?\s*pull_request/m.test(text)) {
    failures.push('workflow must run on pull_request');
  }
  if (/pull_request_target\s*:/m.test(text)) failures.push('pull_request_target is forbidden for untrusted code');
  if (/secrets\s*\.|\$\{\{\s*secrets\./m.test(text)) failures.push('fork PR workflow must not read secrets');
  if (/id-token\s*:\s*write/m.test(text)) failures.push('fork PR workflow must not mint OIDC tokens');
  if (/contents\s*:\s*write/m.test(text)) failures.push('fork PR workflow must use read-only contents permission');
  if (!/permissions\s*:\s*\n(?:\s+[^\n]+\n)*?\s+contents\s*:\s*read/m.test(text)) {
    failures.push('workflow must explicitly set contents: read');
  }
  if (/gh\s+release\s+create|npm\s+publish|wrangler\s+deploy|actions\/attest|upload-artifact@/m.test(text)) {
    failures.push('untrusted workflow must not publish, deploy, attest, or export reusable artifacts');
  }
  return { valid: failures.length === 0, failures };
}

export function validateTrustedReleaseWorkflow(workflowText) {
  const text = String(workflowText ?? '');
  const failures = [];
  if (/pull_request(?:_target)?\s*:/m.test(text)) failures.push('trusted release workflow must not execute on pull requests');
  if (!/id-token\s*:\s*write/m.test(text)) failures.push('trusted release workflow requires id-token: write');
  if (!/attestations\s*:\s*write/m.test(text)) failures.push('trusted release workflow requires attestations: write');
  if (!/SOURCE_COMMIT\s*:\s*\$\{\{\s*github\.sha\s*\}\}/m.test(text)) failures.push('workflow must bind SOURCE_COMMIT to github.sha');
  if (!/actions\/attest-build-provenance@/m.test(text)) failures.push('workflow must create GitHub artifact attestations');
  if (!/release\s*:\s*\n\s+types\s*:\s*\[published\]/m.test(text) && !/tags\s*:/m.test(text)) {
    failures.push('workflow must be protected release or tag triggered');
  }
  return { valid: failures.length === 0, failures };
}

function compareSemver(left, right) {
  const parse = (value) => String(value).split('-', 1)[0].split('.').map((part) => Number(part));
  const a = parse(left);
  const b = parse(right);
  for (let index = 0; index < 3; index += 1) {
    if ((a[index] || 0) !== (b[index] || 0)) return (a[index] || 0) - (b[index] || 0);
  }
  return 0;
}

export function selectMinimalArtifacts(value, target) {
  const manifest = normalizeReleaseManifest(value);
  if (!target || typeof target !== 'object' || Array.isArray(target)) {
    fail('platform_unsupported', 'target platform descriptor is required');
  }
  const platform = requiredString(target.platform, 'target.platform', 64).toLowerCase();
  const hostVersion = requiredString(target.hostVersion, 'target.hostVersion', 64);
  const capabilities = new Set(Array.isArray(target.capabilities) ? target.capabilities.map(String) : []);
  const common = manifest.artifacts.find((artifact) => artifact.kind === 'common');
  let candidates;
  let executionLocation;
  if (platform === 'desktop' || platform === 'cli') {
    const os = requiredString(target.os, 'target.os', 64).toLowerCase();
    const architecture = requiredString(target.architecture, 'target.architecture', 64).toLowerCase();
    candidates = manifest.artifacts.filter((artifact) => (
      artifact.kind === 'native-cli' && artifact.os === os && artifact.architecture === architecture
    ));
    executionLocation = 'local-native';
  } else if (['ios', 'android', 'desktop-webview', 'web', 'pwa'].includes(platform)) {
    candidates = manifest.artifacts.filter((artifact) => (
      artifact.kind === 'web-wasm' && artifact.webTargets.includes(platform)
    ));
    executionLocation = 'local-web';
  } else {
    fail('platform_unsupported', `unsupported target platform: ${platform}`);
  }
  candidates = candidates.filter((artifact) => (
    compareSemver(hostVersion, artifact.minHostVersion) >= 0 &&
    artifact.requiredCapabilities.every((capability) => capabilities.has(capability))
  ));
  if (candidates.length !== 1) {
    fail(candidates.length === 0 ? 'platform_unsupported' : 'artifact_selector_ambiguous',
      candidates.length === 0
        ? 'no compatible executable artifact exists for the target platform'
        : 'multiple executable artifacts match the target platform');
  }
  const artifacts = [common, candidates[0]];
  return {
    pluginId: manifest.pluginId,
    version: manifest.version,
    executionLocation,
    artifacts: artifacts.map((artifact) => ({
      id: artifact.id,
      kind: artifact.kind,
      url: artifact.url,
      sha256: artifact.sha256,
      size: artifact.size,
      sourceCommit: artifact.sourceCommit,
    })),
    totalSize: artifacts.reduce((total, artifact) => total + artifact.size, 0),
  };
}

export function validateRepositoryTemplate(files) {
  const entries = files && typeof files === 'object' && !Array.isArray(files) ? files : {};
  const required = [
    'LICENSE',
    'CONTRIBUTING.md',
    'SECURITY.md',
    'mcp-app.yaml',
    'tools.json',
    'permissions.json',
    '.github/CODEOWNERS',
    '.github/ISSUE_TEMPLATE/bug.yml',
    '.github/PULL_REQUEST_TEMPLATE.md',
    '.github/workflows/pr-untrusted.yml',
    '.github/workflows/main-trusted.yml',
    '.github/workflows/release-trusted.yml',
  ];
  const failures = required.filter((path) => !String(entries[path] ?? '').trim())
    .map((path) => `missing required repository file: ${path}`);
  const codeowners = String(entries['.github/CODEOWNERS'] ?? '');
  for (const protectedPath of ['/.github/workflows/', '/.github/CODEOWNERS', '/mcp-app.yaml', '/permissions.json', '/tools.json']) {
    if (!codeowners.includes(protectedPath)) failures.push(`CODEOWNERS must protect ${protectedPath}`);
  }
  const untrusted = validateUntrustedPullRequestWorkflow(entries['.github/workflows/pr-untrusted.yml']);
  failures.push(...untrusted.failures.map((failure) => `pr-untrusted.yml: ${failure}`));
  const trusted = validateTrustedReleaseWorkflow(entries['.github/workflows/release-trusted.yml']);
  failures.push(...trusted.failures.map((failure) => `release-trusted.yml: ${failure}`));
  const manifest = String(entries['mcp-app.yaml'] ?? '');
  for (const value of [MCP_APPS_STABLE_VERSION, MCP_APPS_EXTENSION, MCP_APPS_MIME, 'common', 'native-cli', 'web-wasm']) {
    if (!manifest.includes(value)) failures.push(`mcp-app.yaml must declare ${value}`);
  }
  return { valid: failures.length === 0, failures };
}

export function normalizeAiContributionPlan(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    fail('ai_plan_invalid', 'AI contribution plan must be an object');
  }
  const upstreamRepository = requiredString(value.upstreamRepository, 'upstreamRepository', 200);
  const forkRepository = requiredString(value.forkRepository, 'forkRepository', 200);
  if (!REPOSITORY.test(upstreamRepository) || !REPOSITORY.test(forkRepository) || upstreamRepository === forkRepository) {
    fail('ai_target_invalid', 'AI changes must target a distinct user fork repository');
  }
  const branch = requiredString(value.branch, 'branch', 255);
  if (!SAFE_BRANCH.test(branch) || ['main', 'master'].includes(branch)) {
    fail('ai_target_invalid', 'AI changes require a dedicated non-default branch');
  }
  const issueUrl = httpsUrl(value.issueUrl, 'issueUrl');
  if (!issueUrl.includes(`github.com/${upstreamRepository}/issues/`)) {
    fail('ai_plan_invalid', 'contribution plan must link a real upstream Issue');
  }
  if (value.userConfirmedPublicAction !== true || value.draftPullRequest !== true) {
    fail('user_confirmation_required', 'public contribution requires confirmation and a Draft Pull Request');
  }
  const tests = sortedUniqueStrings(value.tests, 'tests');
  return {
    upstreamRepository,
    forkRepository,
    branch,
    issueUrl,
    draftPullRequest: true,
    userConfirmedPublicAction: true,
    tests,
    permissionDiffSha256: exactSha(value.permissionDiffSha256, SHA256, 'permissionDiffSha256'),
    toolContractDiffSha256: exactSha(value.toolContractDiffSha256, SHA256, 'toolContractDiffSha256'),
    artifactDiffSha256: exactSha(value.artifactDiffSha256, SHA256, 'artifactDiffSha256'),
  };
}
