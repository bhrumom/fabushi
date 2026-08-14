/**
 * Directly reused from Grok Bot 0.16.0:
 * packages/agent/dist/utils/token-estimate.js
 */
/**
 * Estimate token count for a string.
 * Uses the simple heuristic of characters / 4, matching the OAL implementation.
 */
export function estimateStringTokenCount(str) {
    return Math.round(str.length / 4);
}
