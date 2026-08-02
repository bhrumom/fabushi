import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const required = (name) => {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`missing ${name}`);
  return value;
};
const digest = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const digestJson = (value) => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
const size = (file) => fs.statSync(file).size;
const readJson = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));
const repository = required('GITHUB_REPOSITORY');
const repositoryId = Number(required('GITHUB_REPOSITORY_ID'));
const sourceCommit = required('SOURCE_COMMIT');
const sourceTreeHash = required('SOURCE_TREE_HASH');
const version = required('VERSION');
const tag = required('GITHUB_REF_NAME');
const plugin = readJson('common/plugin.json');
const toolContract = readJson('tool-contract.json');
const pluginId = requiredString(plugin.pluginId, 'common/plugin.json pluginId');
const base = `https://github.com/${repository}/releases/download/${tag}`;
const sbom = 'dist/sbom.spdx.json';
const sbomSha256 = digest(sbom);
const toolContractSha256 = digest('tool-contract.json');

function requiredString(value, field) {
  const result = String(value ?? '').trim();
  if (!result) throw new Error(`missing ${field}`);
  return result;
}

function optionalDerivation() {
  const file = '.mahayana/lineage.json';
  if (!fs.existsSync(file)) return null;
  const lineage = readJson(file);
  const upstreamPluginId = requiredString(lineage.upstreamPluginId, 'lineage.upstreamPluginId');
  if (upstreamPluginId === pluginId) throw new Error('derived app must use a new pluginId');
  return {
    upstreamPluginId,
    upstreamRepository: requiredString(lineage.upstreamRepository, 'lineage.upstreamRepository'),
    upstreamCommit: requiredString(lineage.upstreamCommit, 'lineage.upstreamCommit'),
    syncBaseCommit: requiredString(lineage.syncBaseCommit ?? lineage.upstreamCommit, 'lineage.syncBaseCommit'),
    forkRepository: repository,
    permissionDiffSha256: requiredString(lineage.permissionDiffSha256, 'lineage.permissionDiffSha256'),
    toolContractDiffSha256: requiredString(lineage.toolContractDiffSha256, 'lineage.toolContractDiffSha256'),
    artifactDiffSha256: requiredString(lineage.artifactDiffSha256, 'lineage.artifactDiffSha256'),
    trademarkNotice: requiredString(lineage.trademarkNotice, 'lineage.trademarkNotice'),
  };
}

const artifactSpecs = [
  ['common', 'common', {}],
  ['native-macos-arm64', 'native-cli', { os: 'macos', architecture: 'arm64' }],
  ['native-macos-x64', 'native-cli', { os: 'macos', architecture: 'x64' }],
  ['native-windows-x64', 'native-cli', { os: 'windows', architecture: 'x64' }],
  ['native-linux-x64', 'native-cli', { os: 'linux', architecture: 'x64' }],
  ['native-linux-arm64', 'native-cli', { os: 'linux', architecture: 'arm64' }],
  ['web-wasm', 'web-wasm', { webTargets: ['ios', 'android', 'desktop-webview', 'web', 'pwa'], wasmFeatures: [] }],
];
const artifacts = artifactSpecs.map(([id, kind, extra]) => {
  const filename = `${id}.tar.gz`;
  const file = path.join('dist', filename);
  return {
    id, kind, ...extra,
    sourceCommit,
    sourceTreeHash,
    url: `${base}/${filename}`,
    sha256: digest(file),
    size: size(file),
    mediaType: 'application/gzip',
    sbomUrl: `${base}/sbom.spdx.json`,
    attestationUrl: `https://github.com/${repository}/attestations`,
    minHostVersion: '0.1.0',
    requiredCapabilities: [],
  };
});
const attestationSubjects = artifacts.map(({ id, sha256, size: bytes }) => ({ id, sha256, size: bytes }));
fs.writeFileSync('dist/attestation-subjects.json', JSON.stringify(attestationSubjects, null, 2) + '\n');
const graph = {
  pluginId,
  version,
  source: { repositoryId, repository, sourceCommit, sourceTreeHash },
  toolContractSha256,
  permissionsSha256: digest('permissions.json'),
  sbomSha256,
  artifacts: attestationSubjects,
};
const manifest = {
  schemaVersion: 3,
  protocol: 'mahayana.mcp-app-release.v3',
  pluginId,
  version,
  source: {
    provider: 'github', repositoryId, repository,
    defaultBranch: process.env.GITHUB_DEFAULT_BRANCH || 'main',
    commit: sourceCommit, treeHash: sourceTreeHash,
    licenseSpdx: 'Apache-2.0', visibility: 'public', subdirectory: '.',
  },
  provenance: {
    repository, sourceCommit,
    workflowRef: required('GITHUB_WORKFLOW_REF'),
    runId: required('GITHUB_RUN_ID'),
    builderId: `https://github.com/${repository}/actions/runs/${required('GITHUB_RUN_ID')}`,
    event: 'protected-tag', oidc: true, sbomSha256,
    attestationBundleSha256: digest('dist/attestation-subjects.json'),
  },
  toolContract: {
    schemaVersion: Number(toolContract.schemaVersion) || 1,
    sha256: toolContractSha256,
    tools: [...toolContract.tools].sort(),
    errorCodes: [...toolContract.errorCodes].sort(),
  },
  mcpApps: {
    specification: '2026-01-26', extension: 'io.modelcontextprotocol/ui',
    mimeType: 'text/html;profile=mcp-app',
    resources: [`ui://${pluginId}/main`],
    displayModes: ['inline', 'fullscreen'],
    cspSha256: digest('common/ui/index.html'),
  },
  permissionsSha256: graph.permissionsSha256,
  parentManifestSha256: digestJson(graph),
  artifacts,
  derivation: optionalDerivation(),
};
fs.writeFileSync('dist/release-manifest.json', JSON.stringify(manifest, null, 2) + '\n');
