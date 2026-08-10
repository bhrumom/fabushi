export const MCP_APP_SOURCE_TYPES = Object.freeze([
  'local-workspace',
  'managed-github',
  'user-github',
]);

export const MCP_APP_DEPLOYMENT_TARGETS = Object.freeze([
  'local-only',
  'github-pages',
  'cloudflare',
]);

export function createMcpAppIdentity(input) {
  if (!input?.appId) {
    throw new Error('appId is required');
  }
  return {
    appId: input.appId,
    repositoryId: input.repositoryId ?? null,
    sourceCommit: input.sourceCommit ?? null,
    sourceType: input.sourceType ?? 'local-workspace',
    deploymentTarget: input.deploymentTarget ?? 'local-only',
  };
}
