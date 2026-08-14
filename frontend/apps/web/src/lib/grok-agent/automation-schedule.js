// Directly reused from Grok Bot 0.16.0
// src/shared/automation-schedule.ts (standalone schedule primitives).
export const EVERY_PATTERN = /^@every\s+(\d+)\s*(s|m|h|d)$/i;

const UNIT_MS = {
  s: 1000,
  m: 60_000,
  h: 3_600_000,
  d: 86_400_000,
};

const CRON_ALIASES = {
  "@hourly": "0 * * * *",
  "@daily": "0 0 * * *",
  "@midnight": "0 0 * * *",
  "@weekly": "0 0 * * 0",
  "@monthly": "0 0 1 * *",
  "@yearly": "0 0 1 1 *",
  "@annually": "0 0 1 1 *",
};

export function normalizeSchedule(raw) {
  return raw.trim().replace(/\s+/g, " ");
}

export function expandAlias(schedule) {
  const lower = schedule.toLowerCase();
  return CRON_ALIASES[lower] ?? schedule;
}

export function parseEveryIntervalMs(schedule) {
  const match = EVERY_PATTERN.exec(schedule.trim());
  if (match == null) return null;
  const amount = Number(match[1]);
  const unit = match[2]?.toLowerCase() ?? "";
  const unitMs = UNIT_MS[unit];
  if (!Number.isFinite(amount) || amount <= 0 || unitMs == null) return null;
  return amount * unitMs;
}
