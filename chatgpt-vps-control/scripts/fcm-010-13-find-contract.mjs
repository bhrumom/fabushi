export const MAX_FABUSHI_APP_FIND_LIMIT = 100;

export function normalizeDeviceCallArguments(toolName, args = {}) {
  if (toolName !== "fabushi.app.find") return args;

  const requestedLimit = args.limit ?? MAX_FABUSHI_APP_FIND_LIMIT;
  if (!Number.isInteger(requestedLimit) || requestedLimit < 1) {
    throw new Error(`fabushi.app.find limit must be a positive integer, received ${JSON.stringify(requestedLimit)}`);
  }

  return {
    ...args,
    limit: Math.min(requestedLimit, MAX_FABUSHI_APP_FIND_LIMIT),
  };
}

export function serializeDeviceCallArguments(toolName, args = {}) {
  return JSON.stringify(normalizeDeviceCallArguments(toolName, args));
}
