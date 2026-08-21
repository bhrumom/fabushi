import assert from 'node:assert/strict';
import fs from 'node:fs';

function read(relative) {
  return fs.readFileSync(new URL(`../${relative}`, import.meta.url), 'utf8');
}

const authUtils = read('auth-utils.js');
const auth = read('src/handlers/auth.js');
const providerVerifier = read('src/utils/provider-token-verifier.js');
const payment = read('src/handlers/payment.js');
const moderation = read('src/handlers/moderation.js');
const worker = read('worker-modular.js');
const requestGate = read('src/security/request-gate.js');
const wrangler = read('wrangler.toml');
const sms = read('src/handlers/sms.js');
const marketplace = read('src/handlers/marketplace.js');

assert.match(authUtils, /resolveJwtSecret/);
assert.match(authUtils, /secret\.length < 32/);
assert.doesNotMatch(authUtils, /env\.JWT_SECRET\s*\|\|\s*['"]dev-secret['"]/);
assert.doesNotMatch(wrangler, /^JWT_SECRET\s*=/m);
assert.doesNotMatch(wrangler, /prod_secret_key|dev_secret_key/i);

assert.match(auth, /verifyAppleIdentityToken/);
assert.match(auth, /verifyFirebaseIdentityToken/);
assert.doesNotMatch(auth, /identityToken\.split\s*\(/);
assert.match(providerVerifier, /appleid\.apple\.com\/auth\/keys/);
assert.match(providerVerifier, /securetoken@system\.gserviceaccount\.com/);
assert.match(providerVerifier, /crypto\.subtle\.verify/);

assert.match(payment, /verifyAlipayNotification/);
assert.match(payment, /verifySign\(/);
assert.match(payment, /params\.app_id !== env\.ALIPAY_APP_ID/);
assert.match(payment, /payment_receipts/);
assert.match(payment, /order\.status === 'PAID'/);
assert.match(payment, /env\.DB\.batch\(statements\)/);

assert.match(worker, /enforceRequestSecurityGate/);
assert.match(requestGate, /'\/migrate-builtin-complete'/);
assert.match(moderation, /isAdmin\(user\.email, env\)/);
assert.match(moderation, /verifyToken/);

assert.doesNotMatch(sms, /Math\.random\s*\(/);
assert.doesNotMatch(sms, /console\.log\([^\n]*code/i);
assert.match(sms, /generateToken/);

assert.match(marketplace, /redirect:\s*'manual'/);
assert.match(marketplace, /isPrivateHost/);
assert.match(marketplace, /169\.254\.169\.254/);
assert.match(marketplace, /MAX_PACKAGE_BYTES/);

console.log('Worker security hardening regression gate passed.');
