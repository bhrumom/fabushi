export const EVERY_PATTERN: RegExp;
export function normalizeSchedule(raw: string): string;
export function expandAlias(schedule: string): string;
export function parseEveryIntervalMs(schedule: string): number | null;
