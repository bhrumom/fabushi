const SOURCE_HOSTS = new Set(['local', 'github']);
const CUSTODIES = new Set(['device', 'platform-managed', 'user-owned']);
const HOSTING_PROVIDERS = new Set(['none', 'github-pages', 'cloudflare-pages', 'cloudflare-workers', 'external']);
const SOURCE_PROVIDERS = new Set(['local', 'github']);
const SOURCE_ACTORS = new Set(['user', 'platform']);
const SOURCE_TRANSPORTS = new Set(['local-fs', 'github-mcp', 'github-app-api']);

export function createMcpAppIdentity(input) {
  if (!input?.appId || !input?.pluginId) throw new Error('identity-required');
  if (!SOURCE_HOSTS.has(input.sourceHost)) throw new Error('invalid-source-host');
  if (!CUSTODIES.has(input.sourceCustody)) throw new Error('invalid-source-custody');
  return {
    ...input,
    officialStatus: input.officialStatus ?? 'unverified',
  };
}

export function createSourceBinding(input) {
  if (!SOURCE_PROVIDERS.has(input.provider)) throw new Error('invalid-source-provider');
  if (!SOURCE_ACTORS.has(input.actor)) throw new Error('invalid-source-actor');
  if (!SOURCE_TRANSPORTS.has(input.transport)) throw new Error('invalid-source-transport');
  if (input.provider === 'local' && input.transport !== 'local-fs') throw new Error('local-transport-mismatch');
  if (input.provider === 'github' && !input.repositoryId) throw new Error('github-repository-required');
  return input;
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
