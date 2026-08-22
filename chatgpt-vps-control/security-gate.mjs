import assert from 'node:assert/strict';
import fs from 'node:fs';

const server = fs.readFileSync(new URL('./server.js', import.meta.url), 'utf8');
const gateway = fs.readFileSync(new URL('./secure-entry.js', import.meta.url), 'utf8');
const pkg = JSON.parse(fs.readFileSync(new URL('./package.json', import.meta.url), 'utf8'));

assert.equal(pkg.scripts.start, 'node secure-entry.js');
assert.match(gateway, /redirectUris\.includes\(redirectUri\)/);
assert.match(gateway, /code_challenge_method/);
assert.match(gateway, /!== 'S256'/);
assert.match(gateway, /code_verifier/);
assert.match(gateway, /credentials_must_use_authorization_header/);
assert.match(gateway, /url\.searchParams\.has\('token'\)/);
assert.match(gateway, /OAUTH_CLIENT_STORE_PATH/);
assert.match(gateway, /mode: 0o600/);
assert.match(gateway, /await import\('\.\/server\.js'\)/);
assert.match(server, /listen\(PORT,\s*"127\.0\.0\.1"/);

console.log('Computer-control OAuth security gate passed.');
