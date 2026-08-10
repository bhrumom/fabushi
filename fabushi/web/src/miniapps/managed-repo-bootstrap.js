const SAFE_OWNER = /^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$/;
const SAFE_REPOSITORY = /^[A-Za-z0-9_.-]{1,100}$/;
const SHA1 = /^[a-f0-9]{40}$/;

export class ManagedRepositoryBootstrapError extends Error {
  constructor(code, message, details = {}) {
    super(message);
    this.name = 'ManagedRepositoryBootstrapError';
    this.code = code;
    this.details = details;
  }
}

function fail(code, message, details = {}) {
  throw new ManagedRepositoryBootstrapError(code, message, details);
}

function requiredString(value, field, max = 256) {
  const normalized = String(value ?? '').trim();
  if (!normalized || normalized.length > max) fail('field_invalid', `${field} is required`, { field });
  return normalized;
}

function normalizeOwner(value, field) {
  const owner = requiredString(value, field, 39);
  if (!SAFE_OWNER.test(owner)) fail('repository_owner_invalid', `${field} is invalid`, { owner });
  return owner;
}

function normalizeRepositoryName(value) {
  const name = requiredString(value, 'repositoryName', 100);
  if (!SAFE_REPOSITORY.test(name)) fail('repository_name_invalid', 'repositoryName is invalid', { name });
  return name;
}

function normalizeRepositoryId(value) {
  const repositoryId = Number(value);
  if (!Number.isSafeInteger(repositoryId) || repositoryId <= 0) {
    fail('repository_id_invalid', 'repositoryId must be a stable positive GitHub repository ID');
  }
  return repositoryId;
}

function normalizePinnedWorkflow(value = {}) {
  const repository = requiredString(value.repository, 'trustedReleaseWorkflow.repository', 200);
  const path = requiredString(value.path, 'trustedReleaseWorkflow.path', 300);
  const ref = requiredString(value.ref, 'trustedReleaseWorkflow.ref', 40).toLowerCase();
  if (!SHA1.test(ref)) fail('trusted_release_ref_unpinned', 'trusted release workflow must be pinned to an exact commit SHA');
  if (!path.startsWith('.github/workflows/')) {
    fail('trusted_release_workflow_invalid', 'trusted release workflow must live under .github/workflows');
  }
  return { repository, path, ref, uses: `${repository}/${path}@${ref}` };
}

export const MANAGED_REPOSITORY_BOOTSTRAP_POLICY = Object.freeze({
  pagesDefaultEnabled: false,
  untrustedPullRequestEvent: 'pull_request',
  forbiddenPullRequestEvent: 'pull_request_target',
  untrustedTokenPermission: 'read',
  productionEnvironment: 'production',
  requiredAuditEvents: Object.freeze([
    'managed_repo.bootstrap.requested',
    'managed_repo.bootstrap.applied',
    'managed_repo.bootstrap.verified',
  ]),
});

export function buildManagedRepositoryBootstrapPlan(value = {}, config = {}) {
  const repositoryId = normalizeRepositoryId(value.repositoryId);
  const repositoryOwner = normalizeOwner(value.repositoryOwner, 'repositoryOwner');
  const repositoryName = normalizeRepositoryName(value.repositoryName);
  const officialSourceOwner = normalizeOwner(config.officialSourceOwner ?? 'bhrumom', 'officialSourceOwner');
  if (repositoryOwner.toLowerCase() === officialSourceOwner.toLowerCase()) {
    fail('managed_owner_trust_boundary', 'managed user repositories cannot be bootstrapped in the official source organization');
  }
  const defaultBranch = requiredString(value.defaultBranch ?? 'main', 'defaultBranch', 255);
  const platformSecurityOwner = requiredString(config.platformSecurityOwner ?? '@fabushi/security', 'platformSecurityOwner', 120);
  if (!platformSecurityOwner.startsWith('@')) {
    fail('codeowners_owner_invalid', 'platformSecurityOwner must be a GitHub CODEOWNERS owner');
  }
  const trustedReleaseWorkflow = normalizePinnedWorkflow(value.trustedReleaseWorkflow);
  const requiredChecks = [...new Set((value.requiredChecks ?? []).map((entry) => requiredString(entry, 'requiredCheckName', 160)))].sort();
  if (requiredChecks.length === 0) fail('required_checks_missing', 'managed repository bootstrap requires protected branch checks');

  return {
    repositoryId,
    repositoryOwner,
    repositoryName,
    defaultBranch,
    pages: { enabled: false },
    ruleset: {
      target: 'branch',
      include: [`refs/heads/${defaultBranch}`],
      requirePullRequest: true,
      requiredApprovals: 1,
      dismissStaleApprovals: true,
      blockForcePushes: true,
      restrictDeletions: true,
      requiredChecks,
    },
    productionEnvironment: {
      name: MANAGED_REPOSITORY_BOOTSTRAP_POLICY.productionEnvironment,
      requiredReviewers: 1,
      preventSelfReview: true,
      protectedBranchesOnly: true,
    },
    codeowners: {
      path: '.github/CODEOWNERS',
      requiredOwners: [platformSecurityOwner],
      protectedPatterns: [
        '/.github/workflows/',
        '/.github/CODEOWNERS',
        '/mcp-app.yaml',
        '/permissions.json',
      ],
    },
    workflows: {
      untrustedPullRequest: {
        path: '.github/workflows/pr-untrusted.yml',
        event: MANAGED_REPOSITORY_BOOTSTRAP_POLICY.untrustedPullRequestEvent,
        permissions: { contents: 'read' },
        secrets: false,
        productionEnvironment: false,
      },
      trustedRelease: {
        path: '.github/workflows/release-trusted.yml',
        uses: trustedReleaseWorkflow.uses,
        pinnedRef: trustedReleaseWorkflow.ref,
        productionEnvironment: MANAGED_REPOSITORY_BOOTSTRAP_POLICY.productionEnvironment,
      },
    },
    auditEvents: [...MANAGED_REPOSITORY_BOOTSTRAP_POLICY.requiredAuditEvents],
  };
}

function stringSet(values, field) {
  if (!Array.isArray(values)) fail('bootstrap_evidence_invalid', `${field} must be an array`, { field });
  return new Set(values.map((value) => requiredString(value, field, 300)));
}

export function validateManagedRepositoryBootstrapEvidence(evidence = {}, plan) {
  if (!evidence || typeof evidence !== 'object' || Array.isArray(evidence)) {
    fail('bootstrap_evidence_invalid', 'managed repository bootstrap evidence must be an object');
  }
  if (!plan || typeof plan !== 'object' || Array.isArray(plan)) {
    fail('bootstrap_plan_required', 'managed repository bootstrap validation requires the applied plan');
  }

  if (normalizeRepositoryId(evidence.repositoryId) !== plan.repositoryId) {
    fail('bootstrap_repository_mismatch', 'bootstrap evidence repositoryId does not match the planned repository');
  }
  if (normalizeOwner(evidence.repositoryOwner, 'evidence.repositoryOwner').toLowerCase() !== plan.repositoryOwner.toLowerCase()) {
    fail('bootstrap_repository_mismatch', 'bootstrap evidence owner does not match the planned managed repository');
  }
  if (normalizeRepositoryName(evidence.repositoryName) !== plan.repositoryName) {
    fail('bootstrap_repository_mismatch', 'bootstrap evidence repository name does not match the plan');
  }

  const files = stringSet(evidence.files, 'files');
  for (const path of [
    '.github/CODEOWNERS',
    '.github/workflows/pr-untrusted.yml',
    '.github/workflows/release-trusted.yml',
  ]) {
    if (!files.has(path)) fail('bootstrap_required_file_missing', 'managed repository is missing a required bootstrap file', { path });
  }

  const codeowners = evidence.codeowners ?? {};
  const patterns = new Map((codeowners.entries ?? []).map((entry) => [entry.pattern, new Set(entry.owners ?? [])]));
  for (const pattern of plan.codeowners.protectedPatterns) {
    const owners = patterns.get(pattern);
    if (!owners || !plan.codeowners.requiredOwners.every((owner) => owners.has(owner))) {
      fail('bootstrap_codeowners_invalid', 'sensitive managed repository paths must be owned by platform security', { pattern });
    }
  }

  const untrusted = evidence.workflows?.untrustedPullRequest ?? {};
  const untrustedEvents = stringSet(untrusted.events ?? [], 'untrustedPullRequest.events');
  if (!untrustedEvents.has('pull_request') || untrustedEvents.has('pull_request_target')) {
    fail('bootstrap_untrusted_ci_invalid', 'Fork CI must use pull_request and must not execute on pull_request_target');
  }
  if (untrusted.permissions?.contents !== 'read' || untrusted.permissions?.['id-token'] === 'write') {
    fail('bootstrap_untrusted_ci_privileged', 'Fork CI must use a read-only token and cannot request OIDC publishing authority');
  }
  if ((untrusted.secretNames ?? []).length > 0 || untrusted.environment) {
    fail('bootstrap_untrusted_ci_secret_exposure', 'Fork CI cannot receive repository secrets or production environments');
  }

  const trusted = evidence.workflows?.trustedRelease ?? {};
  if (trusted.uses !== plan.workflows.trustedRelease.uses || trusted.ref !== plan.workflows.trustedRelease.pinnedRef) {
    fail('bootstrap_trusted_release_unpinned', 'managed repository release must call the platform-controlled reusable workflow at the pinned commit');
  }
  if (trusted.hasUserControlledRunSteps === true) {
    fail('bootstrap_trusted_release_user_controlled', 'managed repository user code cannot control production release steps');
  }
  if (trusted.environment !== plan.productionEnvironment.name) {
    fail('bootstrap_production_environment_missing', 'trusted release must use the protected production environment');
  }

  const ruleset = evidence.ruleset ?? {};
  const requiredChecks = stringSet(ruleset.requiredChecks ?? [], 'ruleset.requiredChecks');
  if (ruleset.requirePullRequest !== true || Number(ruleset.requiredApprovals) < plan.ruleset.requiredApprovals || ruleset.dismissStaleApprovals !== true) {
    fail('bootstrap_ruleset_invalid', 'managed default branch must require reviewed pull requests and stale approval dismissal');
  }
  if (ruleset.blockForcePushes !== true || ruleset.restrictDeletions !== true) {
    fail('bootstrap_ruleset_invalid', 'managed default branch must block force pushes and protected branch deletion');
  }
  for (const check of plan.ruleset.requiredChecks) {
    if (!requiredChecks.has(check)) fail('bootstrap_required_check_missing', 'managed repository ruleset is missing a required check', { check });
  }

  const production = evidence.productionEnvironment ?? {};
  if (Number(production.requiredReviewers) < plan.productionEnvironment.requiredReviewers || production.preventSelfReview !== true || production.protectedBranchesOnly !== true) {
    fail('bootstrap_production_environment_invalid', 'production environment must require independent approval from protected branches');
  }

  const pages = evidence.pages ?? {};
  if (pages.enabled === true) {
    if (pages.policyEligible !== true || pages.publicConsent !== true || pages.licenseConsent !== true) {
      fail('bootstrap_pages_policy_violation', 'GitHub Pages may only be enabled after policy eligibility and explicit public/license consent');
    }
  } else if (pages.enabled !== false) {
    fail('bootstrap_pages_state_unknown', 'managed repository Pages state must be explicitly observed');
  }

  const receipts = stringSet(evidence.externalReceipts ?? [], 'externalReceipts');
  for (const receipt of ['github:repository', 'github:ruleset', 'github:workflows', 'github:codeowners']) {
    if (!receipts.has(receipt)) {
      fail('bootstrap_external_receipt_missing', 'managed repository bootstrap requires GitHub provider receipts', { receipt });
    }
  }

  const auditEvents = stringSet(evidence.auditEvents ?? [], 'auditEvents');
  for (const event of plan.auditEvents) {
    if (!auditEvents.has(event)) fail('bootstrap_audit_event_missing', 'managed repository bootstrap is missing a required audit event', { event });
  }

  return {
    repositoryId: plan.repositoryId,
    repository: `${plan.repositoryOwner}/${plan.repositoryName}`,
    protected: true,
    pagesEnabled: pages.enabled,
    trustedReleasePinned: true,
    auditComplete: true,
  };
}
