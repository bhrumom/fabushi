const TRANSIENT_NETWORK_CODES = new Set([
  "ECONNRESET",
  "ETIMEDOUT",
  "EAI_AGAIN",
  "ENETUNREACH",
  "EHOSTUNREACH",
  "ECONNREFUSED",
  "UND_ERR_CONNECT_TIMEOUT",
  "UND_ERR_HEADERS_TIMEOUT",
  "UND_ERR_BODY_TIMEOUT",
  "UND_ERR_SOCKET",
]);

export function transientNetworkCode(error) {
  let current = error;
  for (let depth = 0; current && depth < 8; depth += 1) {
    const code = String(current?.code || "").trim();
    if (TRANSIENT_NETWORK_CODES.has(code)) return code;
    current = current?.cause;
  }
  return "";
}

export function isTransientNetworkError(error) {
  return Boolean(transientNetworkCode(error));
}

export async function retryTransientNetwork(operation, {
  maxAttempts = 3,
  baseDelayMs = 250,
  sleepFn = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
  onRetry = () => {},
} = {}) {
  if (typeof operation !== "function") throw new Error("transient retry requires an operation");
  if (!Number.isInteger(maxAttempts) || maxAttempts < 1) throw new Error("transient retry maxAttempts must be a positive integer");
  if (!Number.isFinite(baseDelayMs) || baseDelayMs < 0) throw new Error("transient retry baseDelayMs must be non-negative");

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      return await operation({ attempt, maxAttempts });
    } catch (error) {
      const code = transientNetworkCode(error);
      if (!code || attempt >= maxAttempts) throw error;
      const delayMs = Math.min(baseDelayMs * (2 ** (attempt - 1)), 2_000);
      onRetry({ attempt, nextAttempt: attempt + 1, maxAttempts, code, delayMs });
      if (delayMs > 0) await sleepFn(delayMs);
    }
  }
  throw new Error("transient retry exhausted unexpectedly");
}
