const DEFAULT_MAX_ATTEMPTS = 8;

export function isStaleAppSurfaceGeneration(error) {
  return /stale_app_surface_generation/u.test(error instanceof Error ? error.message : String(error));
}

function positiveGeneration(value) {
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : null;
}

function stableAgentId(args) {
  const explicit = String(args?.agentId || "").trim();
  if (explicit) return explicit;
  const ref = String(args?.ref || "").trim();
  const match = ref.match(/^agent:(.+)$/u);
  return match?.[1]?.trim() || "";
}

export async function callGenerationSensitiveAction({
  invokeDeviceCall,
  args,
  maxAttempts = DEFAULT_MAX_ATTEMPTS,
  onRetry = () => {},
}) {
  if (typeof invokeDeviceCall !== "function") throw new TypeError("invokeDeviceCall must be a function");
  if (!Number.isInteger(maxAttempts) || maxAttempts < 1) throw new RangeError("maxAttempts must be a positive integer");

  const agentId = stableAgentId(args);
  let currentArgs = { ...args };
  let lastError = null;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      return await invokeDeviceCall("fabushi.app.action", currentArgs);
    } catch (error) {
      lastError = error;
      if (!isStaleAppSurfaceGeneration(error) || attempt === maxAttempts) throw error;
      if (!agentId) throw error;

      const previousGeneration = positiveGeneration(currentArgs.generation);
      const refreshed = await invokeDeviceCall("fabushi.app.find", { agentId, limit: 2 });
      const refreshedGeneration = positiveGeneration(refreshed?.generation);
      const matches = Array.isArray(refreshed?.matches)
        ? refreshed.matches.filter((candidate) => String(candidate?.agentId || "").trim() === agentId)
        : [];
      if (refreshedGeneration == null || matches.length !== 1) {
        throw new Error(
          `stale_app_surface_generation_rebase_failed: target ${agentId} was not uniquely resolvable on the latest semantic surface`,
          { cause: error },
        );
      }

      currentArgs = {
        ...currentArgs,
        generation: refreshedGeneration,
        agentId,
      };
      delete currentArgs.ref;
      onRetry({
        attempt,
        agentId,
        previousGeneration,
        refreshedGeneration,
      });
    }
  }

  throw lastError || new Error("generation-sensitive action exhausted without a result");
}
