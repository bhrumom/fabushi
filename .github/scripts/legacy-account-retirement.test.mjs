import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
test('retired provisioning has no production environment, secret or remote D1 capability', () => {
  const text = readFileSync('.github/workflows/provision-mcp-ci-test-account.yml', 'utf8');
  assert.ok(text.includes('exit 1'));
  assert.ok(text.includes('fabushi-backend'));
  assert.ok(!/secrets\.|environment:\s*production|d1 execute|--remote|INSERT INTO|UPDATE users/.test(text));
});
test('archive CI cannot represent product quality or prohibit canonical tests', () => {
  const text = readFileSync('.github/workflows/ci.yml', 'utf8');
  assert.ok(text.includes('NOT_VERIFIED'));
  assert.ok(text.includes('FCM-027'));
  assert.ok(!/behavioral testing is forbidden|no-test policy; no product tests/.test(text));
});
