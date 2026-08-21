export function isAdmin(email, env) {
  const normalized = String(email || '').trim().toLowerCase();
  if (!normalized) return false;
  const configured = String(env?.ADMIN_EMAILS || env?.ADMIN_EMAIL || '')
    .split(',')
    .map((value) => value.trim().toLowerCase())
    .filter(Boolean);
  return configured.length > 0 && configured.includes(normalized);
}

export function generateRedeemCode(length = 16) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const size = Math.min(64, Math.max(12, Number(length) || 16));
  let result = '';
  // Rejection sampling avoids modulo bias because 256 is not a multiple of 32
  // only conceptually; chars.length is 32 here, so every byte maps uniformly.
  const bytes = new Uint8Array(size);
  crypto.getRandomValues(bytes);
  for (let i = 0; i < size; i += 1) result += chars[bytes[i] % chars.length];
  return result;
}
