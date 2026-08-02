import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  normalizeAiContributionPlan,
  normalizeReleaseManifest,
  selectMinimalArtifacts,
  validateRepositoryTemplate,
  validateTrustedReleaseWorkflow,
  validateUntrustedPullRequestWorkflow,
} from '../src/marketplace/github-native-contract.js';

const SHA1 = 'a'.repeat(40);
const SHA256 = 'b'.repeat(64);
const TREE_SHA1 = 'c'.repeat(40);
const REPOSITORY_ROOT = fileURLToPath(new URL('../../..', import.meta.url));

function artifact(overrides = {}) {
  return {
    id: 'common',
    kind: 'common',
    sourceCommit: SHA1,
    sourceTreeHash: TREE_SHA1,
    url: 'https://github.com/example/app/releases/download/v1/common.tar.gz',
    sha256: SHA256,
    size: 1024,
    mediaType: 'application/gzip',
    sbomUrl: 'https://github.com/example/app/releases/download/v1/common.spdx.json',
    attestationUrl: 'https://github.com/example/app/attestations/1',
    minHostVersion: '1.0.0',
    requiredCapabilities: [],
    ...overrides,
  };
}

function manifest(overrides = {}) {
  return {
    pluginId: 'io.mahayana.example.app',
    version: '1.0.0',
    source: {
      provider: 'github',
      repositoryId: 123456,
      repository: 'example/app',
      defaultBranch: 'main',
      commit: SHA1,
      treeHash: TREE_SHA1,
      licenseSpdx: 'Apache-2.0',
      visibility: 'public',
      subdirectory: '.',
    },
    toolContract: {
      schemaVersion: 1,
      sha256: SHA256,
      tools: ['status', 'send'],
      errorCodes: ['invalid_input'],
    },
    mcpApps: {
      specification: '2026-01-26',
      extension: 'io.modelcontextprotocol/ui',
      mimeType: 'text/html;profile=mcp-app',
      resources: ['ui://io.mahayana.example.app/main'],
      displayModes: ['inline', 'fullscreen'],
      cspSha256: SHA256,
    },
    permissionsSha256: SHA256,
    parentManifestSha256: SHA256,
    provenance: {
      repository: 'example/app',
      sourceCommit: SHA1,
      workflowRef: '.github/workflows/release.yml@refs/tags/v1.0.0',
      runId: '123',
      builderId: 'github-actions',
      event: 'release',
      oidc: true,
      sbomSha256: SHA256,
      attestationBundleSha256: SHA256,
    },
    artifacts: [
      artifact(),
      artifact({
        id: 'native-linux-x64',
        kind: 'native-cli',
        os: 'linux',
        architecture: 'x64',
        url: 'https://github.com/example/app/releases/download/v1/native-linux-x64.tar.gz',
      }),
      artifact({
        id: 'web-wasm',
        kind: 'web-wasm',
        webTargets: ['ios', 'android', 'web', 'pwa'],
        wasmFeatures: ['simd'],
        url: 'https://github.com/example/app/releases/download/v1/web-wasm.tar.gz',
      }),
    ],
    ...overrides,
  };
}

test('normalizes a single-identity multi-artifact MCP App release', () => {
  const normalized = normalizeReleaseManifest(manifest());
  assert.equal(normalized.protocol, 'mahayana.mcp-app-release.v3');
  assert.equal(normalized.source.repositoryId, 123456);
  assert.deepEqual(normalized.artifacts.map((item) => item.id), [
    'common',
    'native-linux-x64',
    'web-wasm',
  ]);
  assert.ok(normalized.artifacts.every((item) => item.sourceCommit === SHA1));
});

test('rejects an artifact built from a different source commit', () => {
  const value = manifest();
  value.artifacts[2].sourceCommit = 'd'.repeat(40);
  assert.throws(() => normalizeReleaseManifest(value), (error) => {
    assert.equal(error.code, 'source_commit_mismatch');
    return true;
  });
});

test('rejects public source without an explicit SPDX license', () => {
  const value = manifest();
  value.source.licenseSpdx = 'NOASSERTION';
  assert.throws(() => normalizeReleaseManifest(value), (error) => {
    assert.equal(error.code, 'license_required');
    return true;
  });
});

test('derived release must use a new plugin ID and fork repository', () => {
  const value = manifest({
    derivation: {
      upstreamPluginId: 'io.mahayana.example.app',
      upstreamRepository: 'upstream/app',
      upstreamCommit: SHA1,
      syncBaseCommit: SHA1,
      forkRepository: 'example/app',
      permissionDiffSha256: SHA256,
      toolContractDiffSha256: SHA256,
      artifactDiffSha256: SHA256,
      trademarkNotice: 'Unofficial derivative; not endorsed by upstream.',
    },
  });
  assert.throws(() => normalizeReleaseManifest(value), (error) => {
    assert.equal(error.code, 'derived_plugin_id_reuse');
    return true;
  });

  value.pluginId = 'io.mahayana.fork.app';
  const normalized = normalizeReleaseManifest(value);
  assert.equal(normalized.derivation.upstreamPluginId, 'io.mahayana.example.app');
});

test('untrusted fork CI forbids secrets, write permission and publishing', () => {
  const safe = `name: Fork CI
on:
  pull_request:
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false
      - run: npm test
`;
  assert.deepEqual(validateUntrustedPullRequestWorkflow(safe), { valid: true, failures: [] });

  const unsafe = `${safe}\n      - run: wrangler deploy --api-token \${{ secrets.CLOUDFLARE_API_TOKEN }}\npermissions:\n  contents: write\n  id-token: write\n`;
  const result = validateUntrustedPullRequestWorkflow(unsafe);
  assert.equal(result.valid, false);
  assert.ok(result.failures.some((failure) => failure.includes('secrets')));
  assert.ok(result.failures.some((failure) => failure.includes('publish')));
});

test('trusted release requires OIDC, attestations and exact source commit', () => {
  const workflow = `name: Trusted release
on:
  release:
    types: [published]
permissions:
  contents: read
  id-token: write
  attestations: write
env:
  SOURCE_COMMIT: \${{ github.sha }}
jobs:
  release:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false
          ref: \${{ github.sha }}
      - run: cosign sign-blob --yes release-manifest.json
      - uses: actions/attest-build-provenance@v2
`;
  assert.deepEqual(validateTrustedReleaseWorkflow(workflow), { valid: true, failures: [] });
  assert.equal(validateTrustedReleaseWorkflow(workflow.replace('id-token: write', 'id-token: read')).valid, false);
});


test('rejects an artifact built from a different source tree', () => {
  const value = manifest();
  value.artifacts[1].sourceTreeHash = 'd'.repeat(40);
  assert.throws(() => normalizeReleaseManifest(value), (error) => {
    assert.equal(error.code, 'source_tree_mismatch');
    return true;
  });
});

test('selects only common plus the minimal compatible platform artifact', () => {
  const value = manifest();
  const desktop = selectMinimalArtifacts(value, {
    platform: 'desktop',
    os: 'linux',
    architecture: 'x64',
    hostVersion: '1.0.0',
    capabilities: [],
  });
  assert.equal(desktop.executionLocation, 'local-native');
  assert.deepEqual(desktop.artifacts.map((item) => item.id), ['common', 'native-linux-x64']);

  const mobile = selectMinimalArtifacts(value, {
    platform: 'ios',
    hostVersion: '1.0.0',
    capabilities: [],
  });
  assert.equal(mobile.executionLocation, 'local-web');
  assert.deepEqual(mobile.artifacts.map((item) => item.id), ['common', 'web-wasm']);
});

test('the checked-in repository template is executable and supply-chain protected', () => {
  const templateRoot = path.join(REPOSITORY_ROOT, 'templates', 'mahayana-mcp-app-github-native');
  const files = {};
  const collect = (directory) => {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const absolute = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        collect(absolute);
      } else {
        files[path.relative(templateRoot, absolute).split(path.sep).join('/')] = fs.readFileSync(absolute, 'utf8');
      }
    }
  };
  collect(templateRoot);
  assert.deepEqual(validateRepositoryTemplate(files), { valid: true, failures: [] });
});

test('AI contribution plans are confined to a confirmed fork branch and Draft PR', () => {
  const value = normalizeAiContributionPlan({
    upstreamRepository: 'publisher/app',
    forkRepository: 'alice/app',
    branch: 'ai/fix-real-issue',
    issueUrl: 'https://github.com/publisher/app/issues/42',
    draftPullRequest: true,
    userConfirmedPublicAction: true,
    tests: ['Untrusted PR / contract', 'Untrusted PR / adversarial boundaries'],
    permissionDiffSha256: SHA256,
    toolContractDiffSha256: SHA256,
    artifactDiffSha256: SHA256,
  });
  assert.equal(value.forkRepository, 'alice/app');
  assert.equal(value.draftPullRequest, true);
  assert.throws(() => normalizeAiContributionPlan({ ...value, forkRepository: value.upstreamRepository }), (error) => {
    assert.equal(error.code, 'ai_target_invalid');
    return true;
  });
});
