const SOURCE_HOSTS = new Set(['local', 'github']);
const CUSTODIES = new Set(['device', 'platform-managed', 'user-owned']);
const HOSTING_PROVIDERS = new Set(['none', 'github-pages', 'cloudflare-pages', 'cloudflare-workers', 'external']);

export function createMcpAppIdentity(input) {
  if (!input?.appId || !input?.pluginId) throw new Error('identity-required');
  if (!SOURCE_HOSTS.has(input.sourceHost)) throw new Error('invalid-source-host');
  if (!CUSTODIES.has(input.sourceCustody)) throw new Error('invalid-source-custody');
  return {
    ...input,
    officialStatus: input.officialStatus ?? 'unverified',
  };
}

export function createWebDeployment(input) {
  if (!HOSTING_PROVIDERS.has(input.hostingProvider)) throw new Error('invalid-hosting-provider');
  return input;
}

export function isSourceHosted(identity) {
  return Boolean(identity.repositoryId && identity.sourceHost === 'github');
}

export function isDeployed(deployment) {
  return Boolean(deployment && deployment.hostingProvider !== 'none' && deployment.state === 'deployed');
}
