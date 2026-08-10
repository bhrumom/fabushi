export const SOURCE_CUSTODY = ["device", "platform-managed", "user-owned"];
export const OFFICIAL_STATUS = ["official", "community", "unverified"];
export const HOSTING_PROVIDERS = [
  "none",
  "github-pages",
  "cloudflare-pages",
  "cloudflare-workers",
  "external",
];

export function createMcpAppIdentity(input) {
  const identity = {
    appId: input.appId,
    pluginId: input.pluginId,
    authorSubjectId: input.authorSubjectId,
    sourceHost: input.sourceHost,
    sourceCustody: input.sourceCustody,
    sourceProvider: input.sourceProvider ?? null,
    sourceActor: input.sourceActor ?? null,
    sourceTransport: input.sourceTransport ?? null,
    repositoryId: input.repositoryId ?? null,
    repositoryOwner: input.repositoryOwner ?? null,
    repositoryName: input.repositoryName ?? null,
    publisherSubjectId: input.publisherSubjectId ?? null,
    officialStatus: input.officialStatus ?? "unverified",
    hostingProvider: input.hostingProvider ?? "none",
    runtimeProfile: input.runtimeProfile,
    deploymentTarget: input.deploymentTarget ?? null,
    lineageId: input.lineageId,
  };
  validateMcpAppIdentity(identity);
  return identity;
}

export function validateMcpAppIdentity(identity) {
  if (!SOURCE_CUSTODY.includes(identity.sourceCustody)) throw new Error("invalid source custody");
  if (!OFFICIAL_STATUS.includes(identity.officialStatus)) throw new Error("invalid official status");
  if (!HOSTING_PROVIDERS.includes(identity.hostingProvider)) throw new Error("invalid hosting provider");
  if (identity.hostingProvider !== "none" && identity.deploymentTarget == null) throw new Error("deployment target required");
  if (identity.sourceHost === "github" && !identity.sourceProvider) throw new Error("github source provider required");
  return true;
}

export function isSourceHosted(identity) {
  return identity.sourceHost === "github";
}

export function isDeployed(identity) {
  return identity.hostingProvider !== "none";
}
