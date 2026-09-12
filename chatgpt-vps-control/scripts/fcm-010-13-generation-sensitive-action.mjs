// Keep retries bounded and fail-closed, but allow enough semantic re-resolution
// for production App Surface churn. The previous budget of 8 was exhausted by
// a real query-only action even though every stale attempt correctly re-found
// the latest generation-bound target.
const DEFAULT_MAX_ATTEMPTS = 32;

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

function uniqueStableMatch(value, agentId) {
  const matches = Array.isArray(value)
    ? value.filter((candidate) => String(candidate?.agentId || "").trim() === agentId)
    : [];
  return matches.length === 1 ? matches[0] : null;
}

function resolvedTargetArgs(target) {
  const agentId = String(target?.agentId || "").trim();
  if (agentId) return { agentId };
  const ref = String(target?.ref || "").trim();
  if (ref) return { ref };
  return null;
}

export async function callGenerationSensitiveAction({
  invokeDeviceCall,
  args,
  maxAttempts = DEFAULT_MAX_ATTEMPTS,
  onRetry = () => {},
  resolveLatestTarget = null,
}) {
  if (typeof invokeDeviceCall !== "function") throw new TypeError("invokeDeviceCall must be a function");
  if (!Number.isInteger(maxAttempts) || maxAttempts < 1) throw new RangeError("maxAttempts must be a positive integer");
  if (resolveLatestTarget != null && typeof resolveLatestTarget !== "function") throw new TypeError("resolveLatestTarget must be a function when provided");

  const agentId = stableAgentId(args);
  let currentArgs = { ...args };
  let lastError = null;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      return await invokeDeviceCall("fabushi.app.action", currentArgs);
    } catch (error) {
      lastError = error;
      if (!isStaleAppSurfaceGeneration(error) || attempt === maxAttempts) throw error;

      const previousGeneration = positiveGeneration(currentArgs.generation);
      if (resolveLatestTarget) {
        const resolved = await resolveLatestTarget({
          invokeDeviceCall,
          attempt,
          previousArgs: { ...currentArgs },
          error,
        });
        const refreshedGeneration = positiveGeneration(resolved?.generation);
        const targetArgs = resolvedTargetArgs(resolved?.target);
        if (refreshedGeneration == null || !targetArgs) {
          throw new Error("stale_app_surface_generation_query_rebase_failed: semantic query did not uniquely resolve a current target", { cause: error });
        }
        currentArgs = {
          ...currentArgs,
          generation: refreshedGeneration,
          ...targetArgs,
        };
        if (targetArgs.agentId) delete currentArgs.ref;
        else delete currentArgs.agentId;
        onRetry({
          attempt,
          resolver: "semantic-query",
          agentId: targetArgs.agentId || null,
          previousGeneration,
          findGeneration: refreshedGeneration,
          refreshedGeneration,
        });
        continue;
      }

      if (!agentId) throw error;
      const found = await invokeDeviceCall("fabushi.app.find", { agentId, limit: 2 });
      const findGeneration = positiveGeneration(found?.generation);
      const foundTarget = uniqueStableMatch(found?.matches, agentId);
      if (findGeneration == null || !foundTarget) {
        throw new Error(
          `stale_app_surface_generation_rebase_failed: target ${agentId} was not uniquely resolvable by find`,
          { cause: error },
        );
      }

      // Capture the latest full semantic surface as a stable lease before retrying.
      // The desktop App Surface can then perform its own bounded stable-target rebase
      // if generation advances again between this controller refresh and the action.
      const surface = await invokeDeviceCall("fabushi.app.snapshot", { maxElements: 500, includeText: true });
      const refreshedGeneration = positiveGeneration(surface?.generation);
      const surfaceTarget = uniqueStableMatch(surface?.elements, agentId);
      if (refreshedGeneration == null || !surfaceTarget) {
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
        resolver: "stable-agent",
        agentId,
        previousGeneration,
        findGeneration,
        refreshedGeneration,
      });
    }
  }

  throw lastError || new Error("generation-sensitive action exhausted without a result");
}
