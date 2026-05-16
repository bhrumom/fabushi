export type ForumDeploymentStage = "preview" | "production";

const SUPPORTED_DEPLOYMENT_STAGES = new Set<ForumDeploymentStage>(["preview", "production"]);

export interface ForumDeploymentRuntime {
  deploymentStage: ForumDeploymentStage;
  indexingEnabled: boolean;
  publicBaseUrl?: string;
}

export function resolveForumDeploymentStage(): ForumDeploymentStage {
  const configuredStage = process.env.FORUM_DEPLOYMENT_STAGE?.trim().toLowerCase();

  if (!configuredStage) {
    return "preview";
  }

  if (SUPPORTED_DEPLOYMENT_STAGES.has(configuredStage as ForumDeploymentStage)) {
    return configuredStage as ForumDeploymentStage;
  }

  throw new Error(`Unsupported FORUM_DEPLOYMENT_STAGE: ${process.env.FORUM_DEPLOYMENT_STAGE}`);
}

export function resolveForumPublicBaseUrl(): string | undefined {
  const configuredUrl = process.env.FORUM_PUBLIC_BASE_URL?.trim();

  if (!configuredUrl) {
    return undefined;
  }

  const normalizedUrl = configuredUrl.endsWith("/") ? configuredUrl.slice(0, -1) : configuredUrl;
  const parsedUrl = new URL(normalizedUrl);

  if (parsedUrl.protocol !== "http:" && parsedUrl.protocol !== "https:") {
    throw new Error("FORUM_PUBLIC_BASE_URL must start with http:// or https://.");
  }

  return parsedUrl.toString().replace(/\/$/, "");
}

export function getForumDeploymentRuntime(): ForumDeploymentRuntime {
  const deploymentStage = resolveForumDeploymentStage();
  const publicBaseUrl = resolveForumPublicBaseUrl();
  const indexingEnabled = deploymentStage === "production" && Boolean(publicBaseUrl);

  if (publicBaseUrl) {
    return {
      deploymentStage,
      indexingEnabled,
      publicBaseUrl,
    };
  }

  return {
    deploymentStage,
    indexingEnabled,
  };
}
