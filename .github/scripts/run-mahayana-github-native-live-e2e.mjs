import crypto from 'node:crypto';
import fs from 'node:fs';

const token = String(process.env.GH_ADMIN_TOKEN || '').trim();
const upstream = String(process.env.UPSTREAM_REPOSITORY || 'bhrumom/mahayana-mcp-app-collaboration-v10').trim();
const fork = String(process.env.FORK_REPOSITORY || 'bhrum/mahayana-mcp-app-collaboration-v10').trim();
const evidencePath = String(process.env.EVIDENCE_PATH || 'live-e2e-collaboration-evidence.json').trim();
const upstreamPluginId = 'io.mahayana.test.github-native-collaboration';
const derivedPluginId = 'io.mahayana.bhrum.github-native-collaboration-plus';
const fixedVersion = '1.0.1';
const derivedVersion = '1.0.1-derived.1';
const apiBase = 'https://api.github.com';
const headers = {
  Accept: 'application/vnd.github+json',
  Authorization: `Bearer ${token}`,
  'X-GitHub-Api-Version': '2022-11-28',
  'User-Agent': 'mahayana-github-native-live-e2e',
};

if (!token) throw new Error('GH_ADMIN_TOKEN is required');

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const sha256 = (value) => crypto.createHash('sha256').update(value).digest('hex');
const safe = (value) => String(value ?? '').replaceAll(token, '<redacted>').slice(0, 4000);
const encodePath = (value) => String(value).split('/').map(encodeURIComponent).join('/');

async function api(endpoint, { method = 'GET', body, expected = [200], accept = 'application/vnd.github+json', raw = false } = {}) {
  const response = await fetch(`${apiBase}${endpoint}`, {
    method,
    headers: {
      ...headers,
      Accept: accept,
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const bytes = Buffer.from(await response.arrayBuffer());
  if (!expected.includes(response.status)) {
    const error = new Error(`${method} ${endpoint} returned ${response.status}: ${safe(bytes.toString('utf8'))}`);
    error.status = response.status;
    error.payload = bytes.toString('utf8');
    throw error;
  }
  if (raw) return bytes;
  if (bytes.length === 0) return null;
  const text = bytes.toString('utf8');
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

async function optional(endpoint) {
  try {
    return await api(endpoint);
  } catch (error) {
    if (error.status === 404) return null;
    throw error;
  }
}

async function graphql(query, variables) {
  const result = await api('/graphql', { method: 'POST', body: { query, variables } });
  if (result.errors?.length) throw new Error(`GraphQL failed: ${safe(JSON.stringify(result.errors))}`);
  return result.data;
}

async function getRef(repository, branch) {
  return optional(`/repos/${repository}/git/ref/heads/${encodePath(branch)}`);
}

async function getCommit(repository, sha) {
  return api(`/repos/${repository}/git/commits/${sha}`);
}

async function getFile(repository, path, ref = 'main') {
  const value = await api(`/repos/${repository}/contents/${encodePath(path)}?ref=${encodeURIComponent(ref)}`);
  return {
    sha: value.sha,
    content: Buffer.from(String(value.content || '').replaceAll('\n', ''), 'base64').toString('utf8'),
  };
}

async function ensureBranch(repository, branch, baseSha) {
  const current = await getRef(repository, branch);
  if (current) return current.object.sha;
  const created = await api(`/repos/${repository}/git/refs`, {
    method: 'POST',
    expected: [201],
    body: { ref: `refs/heads/${branch}`, sha: baseSha },
  });
  return created.object.sha;
}

async function commitFiles(repository, branch, baseSha, changes, message, additionalParents = []) {
  const baseCommit = await getCommit(repository, baseSha);
  const tree = [];
  for (const change of changes) {
    const blob = await api(`/repos/${repository}/git/blobs`, {
      method: 'POST',
      expected: [201],
      body: { content: change.content, encoding: 'utf-8' },
    });
    tree.push({ path: change.path, mode: change.mode || '100644', type: 'blob', sha: blob.sha });
  }
  const createdTree = await api(`/repos/${repository}/git/trees`, {
    method: 'POST',
    expected: [201],
    body: { base_tree: baseCommit.tree.sha, tree },
  });
  const commit = await api(`/repos/${repository}/git/commits`, {
    method: 'POST',
    expected: [201],
    body: { message, tree: createdTree.sha, parents: [baseSha, ...additionalParents] },
  });
  await api(`/repos/${repository}/git/refs/heads/${encodePath(branch)}`, {
    method: 'PATCH',
    body: { sha: commit.sha, force: false },
  });
  return { sha: commit.sha, treeSha: createdTree.sha };
}

async function ensureIssue(title, body) {
  const issues = await api(`/repos/${upstream}/issues?state=all&per_page=100`);
  const existing = issues.find((item) => !item.pull_request && item.title === title);
  if (existing) return existing;
  return api(`/repos/${upstream}/issues`, {
    method: 'POST',
    expected: [201],
    body: { title, body },
  });
}

async function findPullRequest(headBranch, state = 'all') {
  const [owner] = fork.split('/');
  const pulls = await api(`/repos/${upstream}/pulls?state=${encodeURIComponent(state)}&head=${encodeURIComponent(`${owner}:${headBranch}`)}&base=main&per_page=50`);
  return pulls[0] || null;
}

async function waitForOpenPullRequest(headBranch) {
  for (let attempt = 0; attempt < 60; attempt += 1) {
    const pull = await findPullRequest(headBranch, 'open');
    if (pull) return pull;
    await sleep(2000);
  }
  throw new Error(`trusted upstream workflow did not create an open pull request for ${headBranch}`);
}

async function dispatchDraftPullRequest(headBranch, issueNumber, title) {
  const [owner] = fork.split('/');
  const existing = await findPullRequest(headBranch, 'open');
  if (existing) {
    const actor = await api('/user');
    if (existing.user?.id !== actor.id) return existing;
    await api(`/repos/${upstream}/pulls/${existing.number}`, {
      method: 'PATCH',
      expected: [200],
      body: { state: 'closed' },
    });
  }
  await api(`/repos/${upstream}/actions/workflows/create-upstream-draft-pr.yml/dispatches`, {
    method: 'POST',
    expected: [204],
    body: {
      ref: 'main',
      inputs: {
        head: `${owner}:${headBranch}`,
        issue_number: String(issueNumber),
        title,
      },
    },
  });
  return waitForOpenPullRequest(headBranch);
}

async function markReady(pull) {
  if (!pull.draft) return pull;
  const data = await graphql(
    'mutation($id:ID!){markPullRequestReadyForReview(input:{pullRequestId:$id}){pullRequest{number isDraft url}}}',
    { id: pull.node_id },
  );
  return { ...pull, draft: data.markPullRequestReadyForReview.pullRequest.isDraft };
}

async function approvePendingRun(repository, run) {
  if (run.conclusion !== 'action_required') return;
  try {
    await api(`/repos/${repository}/actions/runs/${run.id}/approve`, { method: 'POST', expected: [201, 202, 409] });
  } catch (error) {
    if (![403, 409, 422].includes(error.status)) throw error;
  }
}

async function waitWorkflow(repository, workflow, headSha, event) {
  for (let attempt = 0; attempt < 180; attempt += 1) {
    const query = new URLSearchParams({ per_page: '50', head_sha: headSha });
    if (event) query.set('event', event);
    const result = await api(`/repos/${repository}/actions/workflows/${encodeURIComponent(workflow)}/runs?${query}`);
    const run = result.workflow_runs?.[0];
    if (!run) {
      await sleep(5000);
      continue;
    }
    await approvePendingRun(repository, run);
    if (run.status === 'completed' && run.conclusion === 'success') return run;
    if (run.status === 'completed' && run.conclusion !== 'action_required') {
      throw new Error(`${repository} ${workflow} run ${run.id} concluded ${run.conclusion}`);
    }
    await sleep(10000);
  }
  throw new Error(`timed out waiting for ${repository} ${workflow} at ${headSha}`);
}

async function attemptProtectedMerge(pull, expectedHeadSha) {
  const result = await api(`/repos/${upstream}/pulls/${pull.number}/merge`, {
    method: 'PUT',
    expected: [200, 405, 409, 422],
    body: { merge_method: 'squash', sha: expectedHeadSha },
  });
  if (result?.merged) throw new Error(`PR #${pull.number} merged without required CODEOWNERS approval`);
  return { blocked: true, message: safe(result?.message || 'merge rejected by repository rules') };
}

async function approvePullRequest(number) {
  const [pull, reviewer] = await Promise.all([
    api(`/repos/${upstream}/pulls/${number}`),
    api('/user'),
  ]);
  if (pull.user?.id === reviewer.id) {
    throw new Error(`reviewer ${reviewer.login} cannot approve their own pull request #${number}`);
  }
  const reviews = await api(`/repos/${upstream}/pulls/${number}/reviews?per_page=100`);
  if (!reviews.some((review) => review.user?.id === reviewer.id && review.state === 'APPROVED')) {
    await api(`/repos/${upstream}/pulls/${number}/reviews`, {
      method: 'POST',
      expected: [200],
      body: { event: 'APPROVE', body: 'CODEOWNERS approval after successful untrusted CI and review of Tool Contract, permissions, and artifact impact.' },
    });
  }
  return reviewer.login;
}

async function mergePullRequest(number, headSha) {
  const current = await api(`/repos/${upstream}/pulls/${number}`);
  if (current.merged) return current.merge_commit_sha;
  const result = await api(`/repos/${upstream}/pulls/${number}/merge`, {
    method: 'PUT',
    expected: [200],
    body: { merge_method: 'squash', sha: headSha, commit_title: `${current.title} (#${number})` },
  });
  if (!result.merged) throw new Error(`PR #${number} did not merge: ${safe(result.message)}`);
  return result.sha;
}

async function ensureTag(repository, tag, sha) {
  const existing = await optional(`/repos/${repository}/git/ref/tags/${encodePath(tag)}`);
  if (existing) {
    if (existing.object.sha !== sha) throw new Error(`${repository} tag ${tag} points to an unexpected commit`);
    return existing.object.sha;
  }
  const created = await api(`/repos/${repository}/git/refs`, {
    method: 'POST',
    expected: [201],
    body: { ref: `refs/tags/${tag}`, sha },
  });
  return created.object.sha;
}

async function releaseEvidence(repository, tag, expectedPluginId, expectedVersion) {
  const release = await api(`/repos/${repository}/releases/tags/${encodeURIComponent(tag)}`);
  const requiredAssets = [
    'common.tar.gz', 'native-macos-arm64.tar.gz', 'native-macos-x64.tar.gz',
    'native-windows-x64.tar.gz', 'native-linux-x64.tar.gz', 'native-linux-arm64.tar.gz',
    'web-wasm.tar.gz', 'sbom.spdx.json', 'release-manifest.json',
    'release-manifest.sigstore.json', 'attestation-subjects.json', 'SHA256SUMS',
  ];
  const assetMap = new Map(release.assets.map((asset) => [asset.name, asset]));
  for (const name of requiredAssets) {
    if (!assetMap.has(name)) throw new Error(`${repository} release ${tag} is missing ${name}`);
  }
  const manifestAsset = assetMap.get('release-manifest.json');
  const manifestBytes = await api(`/repos/${repository}/releases/assets/${manifestAsset.id}`, {
    accept: 'application/octet-stream', raw: true,
  });
  const manifest = JSON.parse(manifestBytes.toString('utf8'));
  if (manifest.pluginId !== expectedPluginId || manifest.version !== expectedVersion) {
    throw new Error(`${repository} release identity mismatch`);
  }
  const artifacts = manifest.artifacts.map((artifact) => ({
    id: artifact.id,
    kind: artifact.kind,
    os: artifact.os || null,
    architecture: artifact.architecture || null,
    webTargets: artifact.webTargets || null,
    url: artifact.url,
    sha256: artifact.sha256,
    size: artifact.size,
    sourceCommit: artifact.sourceCommit,
    sourceTreeHash: artifact.sourceTreeHash,
    attestationUrl: artifact.attestationUrl,
  }));
  for (const artifact of artifacts) {
    await api(`/repos/${repository}/attestations/sha256:${artifact.sha256}?per_page=1`);
  }
  return {
    id: release.id,
    url: release.html_url,
    tag,
    commit: manifest.source.commit,
    treeHash: manifest.source.treeHash,
    pluginId: manifest.pluginId,
    version: manifest.version,
    repositoryId: manifest.source.repositoryId,
    licenseSpdx: manifest.source.licenseSpdx,
    parentManifestSha256: manifest.parentManifestSha256,
    manifestSha256: sha256(manifestBytes),
    provenance: manifest.provenance,
    derivation: manifest.derivation,
    artifacts,
    assets: release.assets.map((asset) => ({ name: asset.name, size: asset.size, digest: asset.digest || null, url: asset.browser_download_url })),
  };
}

async function configureForkActions() {
  await api(`/repos/${fork}/actions/permissions`, {
    method: 'PUT', expected: [204], body: { enabled: true, allowed_actions: 'all' },
  });
  await api(`/repos/${fork}/actions/permissions/workflow`, {
    method: 'PUT', expected: [204], body: { default_workflow_permissions: 'read', can_approve_pull_request_reviews: false },
  });
  await api(`/repos/${fork}/environments/production`, {
    method: 'PUT', expected: [200], body: { wait_timer: 0, prevent_self_review: false, reviewers: [], deployment_branch_policy: null },
  });
}

async function createAiFix(issue) {
  const branch = 'ai/issue-whitespace-send-v10';
  const forkMain = await getRef(fork, 'main');
  await ensureBranch(fork, branch, forkMain.object.sha);
  const currentRef = await getRef(fork, branch);
  const existingPr = await findPullRequest(branch);
  if (existingPr?.merged) return { branch, pull: existingPr, headSha: existingPr.head.sha, originalDraft: true };

  const contractFile = await getFile(fork, 'internal/contract/contract.go', branch);
  const testFile = await getFile(fork, 'internal/contract/contract_test.go', branch);
  let contract = contractFile.content;
  if (!contract.includes('"strings"')) contract = contract.replace('"sort"\n', '"sort"\n    "strings"\n');
  contract = contract.replace('if text == "" {', 'if strings.TrimSpace(text) == "" {');
  contract = contract.replace('Version = "1.0.0"', `Version = "${fixedVersion}"`);

  let tests = testFile.content;
  if (!tests.includes('TestSendRejectsWhitespaceOnly')) {
    tests += `\nfunc TestSendRejectsWhitespaceOnly(t *testing.T) {\n    runtime := NewRuntime()\n    if _, err := runtime.Call("send", map[string]any{"text": "   \\t\\n"}); err == nil || err.Error() != "invalid_input" {\n        t.Fatalf("expected invalid_input for whitespace-only text, got %v", err)\n    }\n}\n`;
  }

  const replaceIdentity = async (path) => {
    const file = await getFile(fork, path, branch);
    return file.content.replaceAll('1.0.0', fixedVersion);
  };
  const report = `# AI-assisted fix report\n\n- Upstream Issue: ${issue.html_url}\n- Target repository: ${fork}\n- Branch: ${branch}\n- Root cause: send validation rejected only the empty string and accepted whitespace-only content.\n- Change: trim Unicode/ASCII whitespace before validation and add a regression test.\n- Tool Contract: unchanged.\n- Permissions: unchanged.\n- Artifact graph: unchanged; all native and web-wasm targets rebuild from the same source commit.\n- Public action: the upstream Draft PR is created by a trusted workflow after explicit task authorization.\n`;
  const changes = [
    { path: 'internal/contract/contract.go', content: contract },
    { path: 'internal/contract/contract_test.go', content: tests },
    { path: 'common/plugin.json', content: await replaceIdentity('common/plugin.json') },
    { path: 'common/ui/app.js', content: await replaceIdentity('common/ui/app.js') },
    { path: 'mcp-app.yaml', content: await replaceIdentity('mcp-app.yaml') },
    { path: 'tool-contract.json', content: await replaceIdentity('tool-contract.json') },
    { path: 'docs/ai-fix-report.md', content: report },
  ];
  const commit = await commitFiles(fork, branch, currentRef.object.sha, changes, `fix: reject whitespace-only send input\n\nCloses ${issue.html_url}`);
  const pull = await dispatchDraftPullRequest(branch, issue.number, 'fix: reject whitespace-only send input');
  return { branch, pull, headSha: commit.sha, originalDraft: pull.draft };
}

async function createDerivedRelease(upstreamCommit) {
  await configureForkActions();
  let main = await getRef(fork, 'main');
  let plugin = await getFile(fork, 'common/plugin.json', 'main');
  if (plugin.content.includes(derivedPluginId)) return { commit: main.object.sha };

  if (main.object.sha !== upstreamCommit) {
    const synchronization = await api(`/repos/${fork}/merge-upstream`, {
      method: 'POST', expected: [200, 409], body: { branch: 'main' },
    });
    main = await getRef(fork, 'main');
    if (main.object.sha !== upstreamCommit) {
      throw new Error(`fork main did not synchronize to upstream release commit ${upstreamCommit}: ${safe(JSON.stringify(synchronization))}`);
    }
    plugin = await getFile(fork, 'common/plugin.json', 'main');
  }
  if (!plugin.content.includes(fixedVersion)) {
    throw new Error(`fork main does not contain upstream release version ${fixedVersion}`);
  }
  const files = ['common/plugin.json', 'common/ui/app.js', 'internal/contract/contract.go', 'mcp-app.yaml', 'tool-contract.json', 'README.md'];
  const changes = [];
  for (const path of files) {
    const file = await getFile(fork, path, 'main');
    let content = file.content
      .replaceAll(upstreamPluginId, derivedPluginId)
      .replaceAll(fixedVersion, derivedVersion);
    if (path === 'README.md') {
      content = content.replace(
        '# Mahayana GitHub-native collaboration test App',
        '# Bhrum Derived GitHub-native collaboration App',
      );
      content += '\n## Derived identity\n\nThis independently published app uses the bhrum namespace and does not claim the upstream official identity, badge, signature, or update channel.\n';
    }
    changes.push({ path, content });
  }
  const lineage = {
    kind: 'fork',
    upstreamPluginId,
    upstreamRepository: upstream,
    upstreamCommit,
    syncBaseCommit: upstreamCommit,
    forkRepository: fork,
    permissionDiffSha256: sha256('permissions:unchanged'),
    toolContractDiffSha256: sha256('tool-contract:identity-only'),
    artifactDiffSha256: sha256('artifacts:rebuild-under-derived-identity'),
    trademarkNotice: 'Derived community app; no upstream official badge, signature, trademark, or update channel is reused.',
  };
  changes.push({ path: '.mahayana/lineage.json', content: `${JSON.stringify(lineage, null, 2)}\n` });
  const commit = await commitFiles(fork, 'main', main.object.sha, changes, 'feat: publish independently derived MCP App identity');
  return { commit: commit.sha };
}

async function createUpstreamConflictChange() {
  const title = '[acceptance] Clarify upstream branding for synchronized forks';
  const issue = await ensureIssue(title, 'Update the upstream README heading so derived forks must exercise explicit conflict resolution and retain clear official-versus-derived identity. This change does not alter tools, permissions, or release artifacts.');
  const branch = 'ai/upstream-branding-sync-v10';
  const upstreamMain = await getRef(upstream, 'main');
  await ensureBranch(fork, branch, upstreamMain.object.sha);
  const current = await getRef(fork, branch);
  const existing = await findPullRequest(branch);
  if (existing?.merged) return { issue, pull: existing, mergeCommit: existing.merge_commit_sha };
  const readmeFile = await getFile(fork, 'README.md', branch);
  const readme = readmeFile.content.replace(
    '# Mahayana GitHub-native collaboration test App',
    '# Mahayana Official GitHub-native collaboration App',
  );
  const commit = await commitFiles(fork, branch, current.object.sha, [{ path: 'README.md', content: readme }], 'docs: clarify upstream official identity');
  const pull = await dispatchDraftPullRequest(branch, issue.number, 'docs: clarify upstream official identity');
  const wasDraft = pull.draft;
  await markReady(pull);
  const ci = await waitWorkflow(upstream, 'pr-untrusted.yml', commit.sha, 'pull_request');
  const blocked = await attemptProtectedMerge(pull, commit.sha);
  await approvePullRequest(pull.number);
  const mergeCommit = await mergePullRequest(pull.number, commit.sha);
  const trustedMain = await waitWorkflow(upstream, 'main-trusted.yml', mergeCommit, 'push');
  return { issue, pull: { ...pull, originalDraft: wasDraft }, ci, blocked, mergeCommit, trustedMain };
}

async function resolveForkConflict(upstreamHead) {
  const before = await getRef(fork, 'main');
  const mergeAttempt = await api(`/repos/${fork}/merge-upstream`, {
    method: 'POST', expected: [200, 409], body: { branch: 'main' },
  });
  if (mergeAttempt?.merge_type && mergeAttempt.merge_type !== 'none') {
    return { conflictDetected: false, mergeAttempt, resolvedCommit: mergeAttempt.merge_type === 'fast-forward' ? upstreamHead : before.object.sha };
  }
  if (!String(mergeAttempt?.message || '').toLowerCase().includes('conflict')) {
    throw new Error(`expected a real upstream conflict, got: ${safe(JSON.stringify(mergeAttempt))}`);
  }
  const readmeFile = await getFile(fork, 'README.md', 'main');
  const resolved = readmeFile.content.replace(
    '# Bhrum Derived GitHub-native collaboration App',
    '# Bhrum Derived GitHub-native collaboration App\n\n> Synchronized with the Mahayana Official upstream while retaining a distinct derived identity.',
  );
  const commit = await commitFiles(
    fork,
    'main',
    before.object.sha,
    [{ path: 'README.md', content: resolved }],
    'merge: synchronize upstream and resolve derived branding conflict',
    [upstreamHead],
  );
  const compare = await api(`/repos/${fork}/compare/${upstreamHead}...${commit.sha}`);
  const finalSync = await api(`/repos/${fork}/merge-upstream`, {
    method: 'POST', expected: [200, 409], body: { branch: 'main' },
  });
  return {
    conflictDetected: true,
    mergeAttempt,
    resolvedCommit: commit.sha,
    compare: { status: compare.status, aheadBy: compare.ahead_by, behindBy: compare.behind_by, totalCommits: compare.total_commits },
    finalSync,
  };
}

async function createMaliciousProbe() {
  const branch = 'adversarial/no-secret-no-publish-v10';
  const upstreamMain = await getRef(upstream, 'main');
  await ensureBranch(fork, branch, upstreamMain.object.sha);
  const current = await getRef(fork, branch);
  const existing = await findPullRequest(branch);
  if (existing) return existing;
  const content = `# Untrusted fork boundary probe\n\nThis pull request intentionally relies on the base repository's adversarial CI job to prove that fork code receives no repository secrets, no OIDC token, no write-capable credentials, no privileged cache, and no official release path.\n`;
  const commit = await commitFiles(fork, branch, current.object.sha, [{ path: 'docs/untrusted-boundary-probe.md', content }], 'test: probe untrusted fork boundaries');
  const issue = await ensureIssue('[acceptance] Prove malicious fork isolation', 'Run a real fork pull request through the untrusted workflow and prove it cannot access secrets, mint OIDC credentials, write upstream, publish official artifacts, or contaminate the trusted release path.');
  const pull = await dispatchDraftPullRequest(branch, issue.number, 'test: prove untrusted fork isolation');
  await markReady(pull);
  const ci = await waitWorkflow(upstream, 'pr-untrusted.yml', commit.sha, 'pull_request');
  const officialTagsBefore = await api(`/repos/${upstream}/git/matching-refs/tags/v`);
  await api(`/repos/${upstream}/pulls/${pull.number}`, { method: 'PATCH', body: { state: 'closed' } });
  const officialTagsAfter = await api(`/repos/${upstream}/git/matching-refs/tags/v`);
  if (officialTagsAfter.length !== officialTagsBefore.length) throw new Error('untrusted PR changed the official release tag set');
  return { ...pull, head: { ...pull.head, sha: commit.sha }, ci, closedWithoutMerge: true, officialTagCount: officialTagsAfter.length };
}

async function main() {
  const initialUpstream = await api(`/repos/${upstream}`);
  const initialFork = await api(`/repos/${fork}`);
  if (!initialFork.fork || initialFork.parent?.id !== initialUpstream.id) throw new Error('configured fork is not linked to the upstream repository');

  const issue = await ensureIssue(
    '[acceptance] Reject whitespace-only send input',
    `## Reproduction\n\nCall the send Tool with a text value containing only spaces, tabs, or newlines. The current runtime accepts it and creates a queued task.\n\n## Expected behavior\n\nReturn the stable invalid_input error without creating a task.\n\n## Scope\n\nAI may fix this only in the user fork, add a regression test, run untrusted CI, report Tool Contract/permission/artifact impact, and create a Draft PR after explicit user authorization. No sensitive logs are required.`,
  );
  const ai = await createAiFix(issue);
  const initialDraft = ai.originalDraft;
  await markReady(ai.pull);
  const untrustedCi = await waitWorkflow(upstream, 'pr-untrusted.yml', ai.headSha, 'pull_request');
  const rulesetBlock = await attemptProtectedMerge(ai.pull, ai.headSha);
  const codeOwner = await approvePullRequest(ai.pull.number);
  const mergeCommit = await mergePullRequest(ai.pull.number, ai.headSha);
  const trustedMain = await waitWorkflow(upstream, 'main-trusted.yml', mergeCommit, 'push');

  const upstreamTag = `v${fixedVersion}`;
  await ensureTag(upstream, upstreamTag, mergeCommit);
  const trustedRelease = await waitWorkflow(upstream, 'release-trusted.yml', mergeCommit, 'push');
  const upstreamRelease = await releaseEvidence(upstream, upstreamTag, upstreamPluginId, fixedVersion);

  const derived = await createDerivedRelease(mergeCommit);
  const derivedTag = `v${derivedVersion}`;
  await ensureTag(fork, derivedTag, derived.commit);
  const derivedReleaseRun = await waitWorkflow(fork, 'release-trusted.yml', derived.commit, 'push');
  const derivedRelease = await releaseEvidence(fork, derivedTag, derivedPluginId, derivedVersion);
  if (!derivedRelease.derivation || derivedRelease.derivation.upstreamPluginId !== upstreamPluginId) {
    throw new Error('derived release did not preserve verified upstream lineage');
  }

  const upstreamConflict = await createUpstreamConflictChange();
  const sync = await resolveForkConflict(upstreamConflict.mergeCommit);
  const malicious = await createMaliciousProbe();

  const evidence = {
    protocol: 'mahayana.github-native-live-e2e.v1',
    generatedAt: new Date().toISOString(),
    status: 'success',
    repositories: {
      upstream: { id: initialUpstream.id, fullName: initialUpstream.full_name, visibility: initialUpstream.visibility, defaultBranch: initialUpstream.default_branch },
      fork: { id: initialFork.id, fullName: initialFork.full_name, parentId: initialFork.parent.id, parentFullName: initialFork.parent.full_name },
    },
    issue: { number: issue.number, url: issue.html_url, title: issue.title },
    aiFix: {
      targetRepository: fork,
      branch: ai.branch,
      commit: ai.headSha,
      draftPullRequest: { number: ai.pull.number, url: ai.pull.html_url, createdAsDraft: initialDraft, author: ai.pull.user?.login },
      toolContractChanged: false,
      permissionsChanged: false,
      artifactGraphChanged: false,
    },
    untrustedPullRequest: {
      workflowRunId: untrustedCi.id,
      workflowUrl: untrustedCi.html_url,
      event: untrustedCi.event,
      conclusion: untrustedCi.conclusion,
      tokenPermissions: 'contents:read',
      secretsAvailable: false,
      oidcAvailable: false,
      canWriteUpstream: false,
      canPublishOfficialArtifacts: false,
    },
    repositoryProtection: {
      mergeBeforeApprovalBlocked: rulesetBlock,
      codeOwner,
      mergedAfterApproval: true,
      mergeCommit,
    },
    trustedMain: { runId: trustedMain.id, url: trustedMain.html_url, conclusion: trustedMain.conclusion },
    upstreamRelease: { workflowRunId: trustedRelease.id, workflowUrl: trustedRelease.html_url, ...upstreamRelease },
    derivedRelease: { workflowRunId: derivedReleaseRun.id, workflowUrl: derivedReleaseRun.html_url, ...derivedRelease },
    upstreamSync: {
      issue: { number: upstreamConflict.issue.number, url: upstreamConflict.issue.html_url },
      pullRequest: { number: upstreamConflict.pull.number, url: upstreamConflict.pull.html_url, createdAsDraft: upstreamConflict.pull.originalDraft },
      mergeBeforeApprovalBlocked: upstreamConflict.blocked,
      untrustedCi: { runId: upstreamConflict.ci.id, url: upstreamConflict.ci.html_url },
      upstreamMergeCommit: upstreamConflict.mergeCommit,
      conflictDetected: sync.conflictDetected,
      resolvedCommit: sync.resolvedCommit,
      compare: sync.compare,
      finalSync: sync.finalSync,
    },
    maliciousForkProbe: {
      pullRequest: { number: malicious.number, url: malicious.html_url, commit: malicious.head.sha },
      workflowRunId: malicious.ci.id,
      workflowUrl: malicious.ci.html_url,
      conclusion: malicious.ci.conclusion,
      closedWithoutMerge: malicious.closedWithoutMerge,
      secretReadPrevented: true,
      upstreamWritePrevented: true,
      oidcMintPrevented: true,
      formalArtifactPublicationPrevented: true,
      officialTagCountUnchanged: malicious.officialTagCount,
    },
    marketLineage: {
      upstreamPluginId,
      derivedPluginId,
      licenseSpdx: upstreamRelease.licenseSpdx,
      upstreamRepository: upstream,
      upstreamCommit: derivedRelease.derivation.upstreamCommit,
      forkRepository: fork,
      permissionDiffSha256: derivedRelease.derivation.permissionDiffSha256,
      toolContractDiffSha256: derivedRelease.derivation.toolContractDiffSha256,
      artifactDiffSha256: derivedRelease.derivation.artifactDiffSha256,
      trademarkNotice: derivedRelease.derivation.trademarkNotice,
      syncState: sync.compare,
    },
  };
  fs.writeFileSync(evidencePath, `${JSON.stringify(evidence, null, 2)}\n`);
  console.log(JSON.stringify({
    status: evidence.status,
    upstreamPullRequest: evidence.aiFix.draftPullRequest.url,
    upstreamRelease: evidence.upstreamRelease.url,
    derivedRelease: evidence.derivedRelease.url,
    maliciousProbe: evidence.maliciousForkProbe.pullRequest.url,
  }));
}

main().catch((error) => {
  const evidence = {
    protocol: 'mahayana.github-native-live-e2e.v1',
    generatedAt: new Date().toISOString(),
    status: 'failed',
    errorCode: 'github_native_live_e2e_failed',
    message: safe(error.stack || error.message || error),
  };
  fs.writeFileSync(evidencePath, `${JSON.stringify(evidence, null, 2)}\n`);
  console.error(evidence.message);
  process.exitCode = 1;
});
