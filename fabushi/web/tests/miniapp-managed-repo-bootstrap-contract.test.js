import test from 'node:test';
import assert from 'node:assert/strict';

import {
  buildManagedRepositoryBootstrapPlan,
  validateManagedRepositoryBootstrapEvidence,
} from '../src/miniapps/managed-repo-bootstrap.js';

const TRUSTED_REF = 'a'.repeat(40);
const REQUIRED_CHECK = 'v12 / T03.4 managed-repo-bootstrap';

function plan() {
  return buildManagedRepositoryBootstrapPlan({
    repositoryId: 88001,
    repositoryOwner: 'mahayana-hosted-01',
    repositoryName: 'miniapp-lotus-7f31ab',
    defaultBranch: 'main',
    requiredChecks: [REQUIRED_CHECK, 'v12 / T05.1 untrusted-pr-boundary'],
    trustedReleaseWorkflow: {
      repository: 'bhrumom/fabushi',
      path: '.github/workflows/mahayana-managed-release.yml',
      ref: TRUSTED_REF,
    },
  }, { platformSecurityOwner: '@fabushi/security' });
}

function evidence(overrides = {}) {
  const base = {
    repositoryId: 88001,
    repositoryOwner: 'mahayana-hosted-01',
    repositoryName: 'miniapp-lotus-7f31ab',
    files: [
      '.github/CODEOWNERS',
      '.github/workflows/pr-untrusted.yml',
      '.github/workflows/release-trusted.yml',
      'mcp-app.yaml',
    ],
    codeowners: {
      entries: [
        { pattern: '/.github/workflows/', owners: ['@fabushi/security'] },
        { pattern: '/.github/CODEOWNERS', owners: ['@fabushi/security'] },
        { pattern: '/mcp-app.yaml', owners: ['@fabushi/security'] },
        { pattern: '/permissions.json', owners: ['@fabushi/security'] },
      ],
    },
    workflows: {
      untrustedPullRequest: {
        events: ['pull_request'],
        permissions: { contents: 'read' },
        secretNames: [],
        environment: null,
      },
      trustedRelease: {
        uses: `bhrumom/fabushi/.github/workflows/mahayana-managed-release.yml@${TRUSTED_REF}`,
        ref: TRUSTED_REF,
        hasUserControlledRunSteps: false,
        environment: 'production',
      },
    },
    ruleset: {
      requirePullRequest: true,
      requiredApprovals: 1,
      dismissStaleApprovals: true,
      blockForcePushes: true,
      restrictDeletions: true,
      requiredChecks: [REQUIRED_CHECK, 'v12 / T05.1 untrusted-pr-boundary'],
    },
    productionEnvironment: {
      requiredReviewers: 1,
      preventSelfReview: true,
      protectedBranchesOnly: true,
    },
    pages: { enabled: false },
    externalReceipts: [
      'github:repository',
      'github:ruleset',
      'github:workflows',
      'github:codeowners',
    ],
    auditEvents: [
      'managed_repo.bootstrap.requested',
      'managed_repo.bootstrap.applied',
      'managed_repo.bootstrap.verified',
    ],
  };
  return { ...base, ...overrides };
}

test('managed repository bootstrap plan keeps user source outside official org and Pages off by default', () => {
  const result = plan();
  assert.equal(result.repositoryOwner, 'mahayana-hosted-01');
  assert.equal(result.pages.enabled, false);
  assert.equal(result.workflows.untrustedPullRequest.event, 'pull_request');
  assert.match(result.workflows.trustedRelease.uses, /@[a-f0-9]{40}$/);
  assert.throws(() => buildManagedRepositoryBootstrapPlan({
    repositoryId: 9,
    repositoryOwner: 'bhrumom',
    repositoryName: 'user-app',
    requiredChecks: [REQUIRED_CHECK],
    trustedReleaseWorkflow: { repository: 'bhrumom/fabushi', path: '.github/workflows/release.yml', ref: TRUSTED_REF },
  }), (error) => error.code === 'managed_owner_trust_boundary');
});

test('managed repository bootstrap evidence requires ruleset, CODEOWNERS, untrusted PR isolation and pinned trusted release', () => {
  const result = validateManagedRepositoryBootstrapEvidence(evidence(), plan());
  assert.deepEqual(result, {
    repositoryId: 88001,
    repository: 'mahayana-hosted-01/miniapp-lotus-7f31ab',
    protected: true,
    pagesEnabled: false,
    trustedReleasePinned: true,
    auditComplete: true,
  });

  assert.throws(() => validateManagedRepositoryBootstrapEvidence(evidence({
    workflows: {
      ...evidence().workflows,
      untrustedPullRequest: {
        events: ['pull_request_target'],
        permissions: { contents: 'write', 'id-token': 'write' },
        secretNames: ['PRODUCTION_TOKEN'],
        environment: 'production',
      },
    },
  }), plan()), (error) => error.code === 'bootstrap_untrusted_ci_invalid');

  assert.throws(() => validateManagedRepositoryBootstrapEvidence(evidence({
    workflows: {
      ...evidence().workflows,
      trustedRelease: {
        ...evidence().workflows.trustedRelease,
        hasUserControlledRunSteps: true,
      },
    },
  }), plan()), (error) => error.code === 'bootstrap_trusted_release_user_controlled');
});

test('Pages enablement is fail-closed until policy, public and license consent are all observed', () => {
  assert.throws(() => validateManagedRepositoryBootstrapEvidence(evidence({
    pages: { enabled: true, policyEligible: true, publicConsent: false, licenseConsent: true },
  }), plan()), (error) => error.code === 'bootstrap_pages_policy_violation');

  const enabled = validateManagedRepositoryBootstrapEvidence(evidence({
    pages: { enabled: true, policyEligible: true, publicConsent: true, licenseConsent: true },
  }), plan());
  assert.equal(enabled.pagesEnabled, true);
});

test('missing protected checks, environment policy or audit events fail the bootstrap gate', () => {
  assert.throws(() => validateManagedRepositoryBootstrapEvidence(evidence({
    ruleset: { ...evidence().ruleset, requiredChecks: [REQUIRED_CHECK] },
  }), plan()), (error) => error.code === 'bootstrap_required_check_missing');

  assert.throws(() => validateManagedRepositoryBootstrapEvidence(evidence({
    productionEnvironment: { requiredReviewers: 0, preventSelfReview: false, protectedBranchesOnly: false },
  }), plan()), (error) => error.code === 'bootstrap_production_environment_invalid');

  assert.throws(() => validateManagedRepositoryBootstrapEvidence(evidence({
    externalReceipts: [
      'github:repository',
      'github:ruleset',
      'github:workflows',
      'github:codeowners',
    ],
    auditEvents: ['managed_repo.bootstrap.requested', 'managed_repo.bootstrap.applied'],
  }), plan()), (error) => error.code === 'bootstrap_audit_event_missing');
});
