import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const path = resolve(process.cwd(), "chatgpt-vps-control/lib/device-direct-path.js");
let source = readFileSync(path, "utf8");
let changed = false;
function replaceOnce(before, after, marker) {
  if (source.includes(marker)) return;
  if (!source.includes(before)) throw new Error(`Missing direct hysteresis anchor: ${marker}`);
  source = source.replace(before, after);
  changed = true;
}

replaceOnce(
  'const DEFAULT_HEALTH_TTL_MS = 45_000;\n',
  'const DEFAULT_HEALTH_TTL_MS = 45_000;\n' +
    'const DEFAULT_PROMOTE_SUCCESSES = 2;\n' +
    'const DEFAULT_DEMOTE_FAILURES = 2; // GBF-412 route hysteresis thresholds\n',
  '// GBF-412 route hysteresis thresholds',
);

replaceOnce(
  '  const healthTtlMs = Number(options.healthTtlMs) || DEFAULT_HEALTH_TTL_MS;\n  const devices = new Map();\n',
  '  const healthTtlMs = Number(options.healthTtlMs) || DEFAULT_HEALTH_TTL_MS;\n' +
    '  const promoteSuccesses = Math.max(1, Number(options.promoteSuccesses) || DEFAULT_PROMOTE_SUCCESSES);\n' +
    '  const demoteFailures = Math.max(1, Number(options.demoteFailures) || DEFAULT_DEMOTE_FAILURES);\n' +
    '  const devices = new Map(); // GBF-412 hysteresis configuration\n',
  '// GBF-412 hysteresis configuration',
);

replaceOnce(
  '    const health = sameGeneration ? current.health : new Map();\n    const entry = {\n',
  '    const health = sameGeneration ? current.health : new Map();\n' +
    '    const route = sameGeneration ? (current.route ?? { path: RELAY_PATH, candidateId: null, changedAt: timestamp }) : { path: RELAY_PATH, candidateId: null, changedAt: timestamp };\n' +
    '    const entry = {\n',
  'const route = sameGeneration ?',
);

replaceOnce(
  '      candidates: normalizedCandidates,\n      health,\n      expiresAt:',
  '      candidates: normalizedCandidates,\n' +
    '      health,\n' +
    '      route, // GBF-412 preserve route hysteresis across heartbeats\n' +
    '      expiresAt:',
  '// GBF-412 preserve route hysteresis across heartbeats',
);

replaceOnce(
  '    entry.health.set(id, {\n      reachable: reachable === true,\n      latencyMs: Math.max(0, Math.min(60_000, Number(latencyMs) || 0)),\n      loss: Math.max(0, Math.min(1, Number(loss) || 0)),\n      checkedAt: now(),\n    });\n',
  '    const previous = entry.health.get(id);\n' +
    '    const isReachable = reachable === true;\n' +
    '    entry.health.set(id, {\n' +
    '      reachable: isReachable,\n' +
    '      latencyMs: Math.max(0, Math.min(60_000, Number(latencyMs) || 0)),\n' +
    '      loss: Math.max(0, Math.min(1, Number(loss) || 0)),\n' +
    '      checkedAt: now(),\n' +
    '      successStreak: isReachable ? Math.min(1000, (previous?.successStreak || 0) + 1) : 0,\n' +
    '      failureStreak: isReachable ? 0 : Math.min(1000, (previous?.failureStreak || 0) + 1),\n' +
    '    }); // GBF-412 track route health streaks\n',
  '// GBF-412 track route health streaks',
);

replaceOnce(
  '    const scored = entry.candidates.map((candidate) => {\n      const health = entry.health.get(candidate.id);\n      const fresh = health && health.checkedAt + healthTtlMs > timestamp;\n      if (!fresh || !health.reachable) return null;\n      const score = candidate.priority - Math.min(50_000, health.latencyMs) - Math.round(health.loss * 100_000);\n      return { candidate, health, score };\n    }).filter(Boolean).sort((left, right) => right.score - left.score);\n    if (!scored.length) return { path: RELAY_PATH, reason: "no-healthy-direct-candidate", candidate: null };\n    return { path: DIRECT_PATH, reason: "healthy-authenticated-direct-candidate", candidate: scored[0].candidate, health: scored[0].health };\n',
  '    const scored = entry.candidates.map((candidate) => {\n' +
    '      const health = entry.health.get(candidate.id);\n' +
    '      const fresh = health && health.checkedAt + healthTtlMs > timestamp;\n' +
    '      if (!fresh || !health.reachable) return null;\n' +
    '      const score = candidate.priority - Math.min(50_000, health.latencyMs) - Math.round(health.loss * 100_000);\n' +
    '      return { candidate, health, score };\n' +
    '    }).filter(Boolean).sort((left, right) => right.score - left.score);\n' +
    '    if (entry.route?.path === DIRECT_PATH && entry.route.candidateId) {\n' +
    '      const previousCandidate = entry.candidates.find((candidate) => candidate.id === entry.route.candidateId);\n' +
    '      const previousHealth = previousCandidate ? entry.health.get(previousCandidate.id) : null;\n' +
    '      const fresh = previousHealth && previousHealth.checkedAt + healthTtlMs > timestamp;\n' +
    '      if (previousCandidate && fresh && (previousHealth.failureStreak || 0) < demoteFailures) {\n' +
    '        return { path: DIRECT_PATH, reason: previousHealth.reachable ? "direct-route-held" : "direct-route-hysteresis-hold", candidate: previousCandidate, health: previousHealth };\n' +
    '      }\n' +
    '      entry.route = { path: RELAY_PATH, candidateId: null, changedAt: timestamp };\n' +
    '    }\n' +
    '    const promoted = scored.find((item) => (item.health.successStreak || 0) >= promoteSuccesses);\n' +
    '    if (!promoted) return { path: RELAY_PATH, reason: scored.length ? "direct-route-awaiting-stability" : "no-healthy-direct-candidate", candidate: null };\n' +
    '    entry.route = { path: DIRECT_PATH, candidateId: promoted.candidate.id, changedAt: timestamp };\n' +
    '    return { path: DIRECT_PATH, reason: "healthy-authenticated-direct-candidate", candidate: promoted.candidate, health: promoted.health }; // GBF-412 route hysteresis selection\n',
  '// GBF-412 route hysteresis selection',
);

if (changed) writeFileSync(path, source);
console.log(changed ? "Applied direct path route hysteresis." : "Direct path route hysteresis already applied.");
