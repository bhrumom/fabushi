import process from 'node:process';

const production = process.env.NODE_ENV === 'production';
const adapterSecret = String(process.env.CODEX_DEEPSEEK_ADAPTER_SECRET || '').trim();
const deepSeekKey = String(process.env.DEEPSEEK_API_KEY || '').trim();
const openClawToken = String(process.env.OPENCLAW_GATEWAY_TOKEN || '').trim();
const corsOrigin = String(process.env.CORS_ORIGIN || '').trim();

if (production) {
  if (![adapterSecret, deepSeekKey, openClawToken].some((value) => value.length >= 24)) {
    throw new Error('Production AI backend requires an explicit secret/token of at least 24 characters');
  }
  if (!corsOrigin || corsOrigin === '*') {
    throw new Error('Production AI backend requires an explicit CORS_ORIGIN allowlist');
  }
  if (!process.env.TRUST_PROXY_HOPS) {
    throw new Error('Production AI backend requires explicit TRUST_PROXY_HOPS');
  }
}

if (adapterSecret && adapterSecret.length < 24) {
  throw new Error('CODEX_DEEPSEEK_ADAPTER_SECRET must be at least 24 characters');
}

await import('./server.js');
