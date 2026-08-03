import fs from 'node:fs';
import path from 'node:path';

const token = String(process.env.GH_ADMIN_TOKEN || '').trim();
const upstreamOwner = String(process.env.UPSTREAM_OWNER || 'bhrumom').trim();
const forkOwner = String(process.env.FORK_OWNER || 'bhrum').trim();
const repositoryName = String(process.env.TEST_REPOSITORY || 'mahayana-mcp-app-collaboration-v10').trim();
const templateRoot = path.resolve(process.env.TEMPLATE_ROOT || 'templates/mahayana-mcp-app-github-native');
const evidencePath = path.resolve(process.env.EVIDENCE_PATH || 'live-e2e-bootstrap-evidence.json');
const apiBase = 'https://api.github.com';
const upstreamPluginId = 'io.mahayana.test.github-native-collaboration';
const upstreamVersion = '1.0.0';

if (!token) throw new Error('GH_ADMIN_TOKEN is required for trusted live GitHub setup');
if (!fs.statSync(templateRoot).isDirectory()) throw new Error(`template directory does not exist: ${templateRoot}`);

const headers = {
  Accept: 'application/vnd.github+json',
  Authorization: `Bearer ${token}`,
  'X-GitHub-Api-Version': '2022-11-28',
  'User-Agent': 'mahayana-github-native-live-e2e',
};

function safeMessage(text) {
  return String(text || '').replaceAll(token, '<redacted>').slice(0, 4000);
}

async function api(endpoint, { method = 'GET', body, expected = [200] } = {}) {
  const response = await fetch(`${apiBase}${endpoint}`, {
    method,
    headers: body === undefined ? headers : { ...headers, 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let payload = null;
  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      payload = text;
    }
  }
  if (!expected.includes(response.status)) {
    const error = new Error(`${method} ${endpoint} returned ${response.status}: ${safeMessage(text)}`);
    error.status = response.status;
    error.payload = payload;
    throw error;
  }
  return payload;
}

function isEmptyGitRepository(error) {
  return error?.status === 409
    && String(error?.payload?.message || '').trim().toLowerCase() === 'git repository is empty.';
}

async function optional(endpoint, { allowEmptyRepository = false } = {}) {
  try {
    return await api(endpoint);
  } catch (error) {
    if (error.status === 404 || (allowEmptyRepository && isEmptyGitRepository(error))) return null;
    throw error;
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function listFiles(directory, prefix = '') {
  const output = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) output.push(...listFiles(absolute, relative));
    else if (entry.isFile()) output.push({ relative, absolute });
  }
  return output.sort((a, b) => a.relative.localeCompare(b.relative));
}

function customize(relative, content) {
  let value = content
    .replaceAll('io.mahayana.example.github-native-app', upstreamPluginId)
    .replaceAll('0.1.0', upstreamVersion)
    .replace('# Mahayana GitHub-native MCP App template', '# Mahayana GitHub-native collaboration test App');
  if (relative === 'README.md') {
    value += `\n## Live acceptance identity\n\n- Upstream repository: ${upstreamOwner}/${repositoryName}\n- Plugin ID: ${upstreamPluginId}\n- Initial version: ${upstreamVersion}\n- Fork PRs are untrusted and cannot publish official artifacts.\n`;
  }
  return value;
}

const createDraftPrWorkflow = `name: Create Upstream Draft PR
run-name: Create Draft PR for \${{ inputs.head }}
on:
  workflow_dispatch:
    inputs:
      head:
        description: Fork branch in owner:branch form
        required: true
        type: string
      issue_number:
        description: Linked upstream issue number
        required: true
        type: string
      title:
        description: Pull request title
        required: true
        type: string

permissions:
  contents: read
  pull-requests: write

jobs:
  create:
    runs-on: ubuntu-latest
    steps:
      - name: Create user-confirmed Draft Pull Request
        uses: actions/github-script@v7
        env:
          PR_HEAD: \${{ inputs.head }}
          ISSUE_NUMBER: \${{ inputs.issue_number }}
          PR_TITLE: \${{ inputs.title }}
        with:
          script: |
            const head = String(process.env.PR_HEAD || '');
            const issueNumber = String(process.env.ISSUE_NUMBER || '');
            const title = String(process.env.PR_TITLE || '');
            if (!head || !issueNumber || !title) throw new Error('head, issue_number, and title are required');
            const body = [
              'Closes #' + issueNumber,
              '',
              'AI-assisted change created in the user fork after explicit confirmation.',
              '',
              '## Required report',
              '- Reproduction and root cause are documented in the linked Issue.',
              '- Untrusted pull_request CI runs with read-only contents and no secrets.',
              '- Tool Contract, permissions, and artifact impact are reviewed before merge.',
              '- Merge does not publish; a separate trusted release is required.'
            ].join('\\n');
            const response = await github.rest.pulls.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              head,
              base: 'main',
              title,
              body,
              draft: true,
              maintainer_can_modify: false
            });
            core.summary.addHeading('Draft PR created').addLink(response.data.html_url, response.data.html_url).write();
`;

async function ensureRepository() {
  let repository = await optional(`/repos/${upstreamOwner}/${repositoryName}`);
  if (!repository) {
    repository = await api(`/orgs/${upstreamOwner}/repos`, {
      method: 'POST',
      expected: [201],
      body: {
        name: repositoryName,
        description: 'Public acceptance repository for GitHub-native multi-artifact MCP Apps collaboration.',
        homepage: 'https://github.com/bhrumom/fabushi',
        private: false,
        has_issues: true,
        has_projects: false,
        has_wiki: false,
        auto_init: false,
      },
    });
  }
  if (repository.visibility !== 'public' || repository.archived) {
    throw new Error(`acceptance repository must be public and active: ${repository.full_name}`);
  }
  return repository;
}

async function initializeEmptyRepository(repository) {
  const readme = listFiles(templateRoot).find((file) => file.relative === 'README.md');
  if (!readme) throw new Error(`template README.md does not exist: ${templateRoot}`);
  const content = customize(readme.relative, fs.readFileSync(readme.absolute, 'utf8'));
  await api(`/repos/${repository.full_name}/contents/README.md`, {
    method: 'PUT',
    expected: [201],
    body: {
      message: 'chore: initialize GitHub-native MCP App acceptance repository',
      content: Buffer.from(content, 'utf8').toString('base64'),
      branch: 'main',
    },
  });

  for (let attempt = 0; attempt < 20; attempt += 1) {
    const currentRef = await optional(`/repos/${repository.full_name}/git/ref/heads/main`, { allowEmptyRepository: true });
    if (currentRef) return currentRef;
    await sleep(1000);
  }
  throw new Error(`initialized repository did not expose refs/heads/main: ${repository.full_name}`);
}

async function writeTemplate(repository) {
  let currentRef = await optional(`/repos/${repository.full_name}/git/ref/heads/main`, { allowEmptyRepository: true });
  if (!currentRef) currentRef = await initializeEmptyRepository(repository);
  const parentSha = currentRef.object.sha;
  const parentCommit = await api(`/repos/${repository.full_name}/git/commits/${parentSha}`);
  const elements = [];
  for (const file of listFiles(templateRoot)) {
    const text = customize(file.relative, fs.readFileSync(file.absolute, 'utf8'));
    const blob = await api(`/repos/${repository.full_name}/git/blobs`, {
      method: 'POST',
      expected: [201],
      body: { content: text, encoding: 'utf-8' },
    });
    elements.push({
      path: file.relative,
      mode: file.relative.startsWith('scripts/') && file.relative.endsWith('.sh') ? '100755' : '100644',
      type: 'blob',
      sha: blob.sha,
    });
  }
  const draftBlob = await api(`/repos/${repository.full_name}/git/blobs`, {
    method: 'POST',
    expected: [201],
    body: { content: createDraftPrWorkflow, encoding: 'utf-8' },
  });
  elements.push({ path: '.github/workflows/create-upstream-draft-pr.yml', mode: '100644', type: 'blob', sha: draftBlob.sha });

  const tree = await api(`/repos/${repository.full_name}/git/trees`, {
    method: 'POST',
    expected: [201],
    body: {
      ...(parentCommit?.tree?.sha ? { base_tree: parentCommit.tree.sha } : {}),
      tree: elements,
    },
  });
  if (parentCommit?.tree?.sha === tree.sha) {
    return { commitSha: parentSha, treeSha: tree.sha, changed: false };
  }
  const commit = await api(`/repos/${repository.full_name}/git/commits`, {
    method: 'POST',
    expected: [201],
    body: {
      message: 'chore: refresh GitHub-native MCP App acceptance repository',
      tree: tree.sha,
      parents: [parentSha],
    },
  });
  await api(`/repos/${repository.full_name}/git/refs/heads/main`, {
    method: 'PATCH',
    expected: [200],
    body: { sha: commit.sha, force: false },
  });
  await api(`/repos/${repository.full_name}`, {
    method: 'PATCH',
    expected: [200],
    body: { default_branch: 'main', has_issues: true, allow_auto_merge: false, delete_branch_on_merge: false },
  });
  return { commitSha: commit.sha, treeSha: tree.sha, changed: true };
}

async function configureActions(repository) {
  await api(`/repos/${repository.full_name}/actions/permissions`, {
    method: 'PUT',
    expected: [204],
    body: { enabled: true, allowed_actions: 'all' },
  });
  // GitHub exposes one repository switch for both Actions-created PRs and
  // Actions-submitted approvals. The trusted workflow only creates a Draft PR;
  // CODEOWNERS/rulesets still require a distinct maintainer approval before merge.
  await api(`/repos/${repository.full_name}/actions/permissions/workflow`, {
    method: 'PUT',
    expected: [204],
    body: { default_workflow_permissions: 'read', can_approve_pull_request_reviews: true },
  });
  await api(`/repos/${repository.full_name}/environments/production`, {
    method: 'PUT',
    expected: [200],
    body: { wait_timer: 0, prevent_self_review: false, reviewers: [], deployment_branch_policy: null },
  });
}

const mainRuleset = {
  name: 'protect-main',
  target: 'branch',
  enforcement: 'active',
  bypass_actors: [],
  conditions: { ref_name: { include: ['refs/heads/main'], exclude: [] } },
  rules: [
    { type: 'deletion' },
    { type: 'non_fast_forward' },
    { type: 'required_linear_history' },
    {
      type: 'pull_request',
      parameters: {
        required_approving_review_count: 1,
        dismiss_stale_reviews_on_push: true,
        require_code_owner_review: true,
        require_last_push_approval: false,
        required_review_thread_resolution: true,
        allowed_merge_methods: ['squash'],
      },
    },
    {
      type: 'required_status_checks',
      parameters: {
        strict_required_status_checks_policy: true,
        do_not_enforce_on_create: false,
        required_status_checks: [
          { context: 'Untrusted PR / contract' },
          { context: 'Untrusted PR / adversarial boundaries' },
        ],
      },
    },
  ],
};

const tagRuleset = {
  name: 'protect-release-tags',
  target: 'tag',
  enforcement: 'active',
  bypass_actors: [],
  conditions: { ref_name: { include: ['refs/tags/v*'], exclude: [] } },
  rules: [{ type: 'deletion' }, { type: 'non_fast_forward' }],
};

async function findRuleset(repository, name) {
  const rulesets = await api(`/repos/${repository.full_name}/rulesets`);
  return rulesets.find((item) => item.name === name) || null;
}

async function upsertRuleset(repository, ruleset) {
  const existing = await findRuleset(repository, ruleset.name);
  if (existing) {
    return await api(`/repos/${repository.full_name}/rulesets/${existing.id}`, {
      method: 'PUT',
      expected: [200],
      body: ruleset,
    });
  }
  return await api(`/repos/${repository.full_name}/rulesets`, {
    method: 'POST',
    expected: [201],
    body: ruleset,
  });
}

async function ensureFork(upstream) {
  let fork = await optional(`/repos/${forkOwner}/${repositoryName}`);
  if (!fork) {
    await api(`/repos/${upstream.full_name}/forks`, { method: 'POST', expected: [202], body: {} });
    for (let attempt = 0; attempt < 40 && !fork; attempt += 1) {
      await sleep(3000);
      fork = await optional(`/repos/${forkOwner}/${repositoryName}`);
    }
  }
  if (!fork) throw new Error(`fork was not created: ${forkOwner}/${repositoryName}`);
  if (!fork.fork || fork.parent?.id !== upstream.id) {
    throw new Error(`${fork.full_name} exists but is not a fork of ${upstream.full_name}`);
  }
  const merge = await api(`/repos/${fork.full_name}/merge-upstream`, {
    method: 'POST',
    expected: [200, 409],
    body: { branch: 'main' },
  });
  return { fork, merge };
}

const actor = await api('/user');
const upstream = await ensureRepository();
const existingMainRuleset = await findRuleset(upstream, mainRuleset.name);
if (existingMainRuleset?.enforcement === 'active') {
  await upsertRuleset(upstream, { ...mainRuleset, enforcement: 'disabled' });
}
let source;
try {
  source = await writeTemplate(upstream);
} finally {
  if (existingMainRuleset) await upsertRuleset(upstream, mainRuleset);
}
await configureActions(upstream);
const configuredMainRuleset = await upsertRuleset(upstream, mainRuleset);
const configuredTagRuleset = await upsertRuleset(upstream, tagRuleset);
const { fork, merge } = await ensureFork(upstream);
const forkMain = await api(`/repos/${fork.full_name}/git/ref/heads/main`);

const evidence = {
  protocol: 'mahayana.github-native-live-e2e.bootstrap.v1',
  generatedAt: new Date().toISOString(),
  actor: { login: actor.login, id: actor.id },
  upstream: {
    id: upstream.id,
    fullName: upstream.full_name,
    url: upstream.html_url,
    visibility: upstream.visibility,
    defaultBranch: 'main',
    sourceCommit: source.commitSha,
    sourceTreeHash: source.treeSha,
    pluginId: upstreamPluginId,
    version: upstreamVersion,
    licenseSpdx: 'Apache-2.0',
  },
  fork: {
    id: fork.id,
    fullName: fork.full_name,
    url: fork.html_url,
    parentId: fork.parent.id,
    parentFullName: fork.parent.full_name,
    mainCommit: forkMain.object.sha,
    sync: merge,
  },
  rulesets: [
    { id: configuredMainRuleset.id, name: configuredMainRuleset.name, target: configuredMainRuleset.target, enforcement: configuredMainRuleset.enforcement },
    { id: configuredTagRuleset.id, name: configuredTagRuleset.name, target: configuredTagRuleset.target, enforcement: configuredTagRuleset.enforcement },
  ],
  trust: {
    forkPullRequestWorkflow: 'pull_request with contents:read and no secrets or id-token',
    officialReleaseWorkflow: 'protected tag plus production environment, OIDC, SBOM, signature, and attestations',
    pullRequestMergePublishes: false,
  },
};
fs.writeFileSync(evidencePath, `${JSON.stringify(evidence, null, 2)}\n`);
console.log(JSON.stringify({
  upstream: evidence.upstream.fullName,
  upstreamCommit: evidence.upstream.sourceCommit,
  fork: evidence.fork.fullName,
  forkCommit: evidence.fork.mainCommit,
  rulesets: evidence.rulesets.map((item) => item.id),
  evidencePath,
}, null, 2));
