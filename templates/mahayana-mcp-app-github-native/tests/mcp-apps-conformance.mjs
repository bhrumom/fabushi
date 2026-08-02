import assert from 'node:assert/strict';
import fs from 'node:fs';

const html = fs.readFileSync('common/ui/index.html', 'utf8');
const app = fs.readFileSync('common/ui/app.js', 'utf8');
const manifest = fs.readFileSync('mcp-app.yaml', 'utf8');
assert.match(html, /Content-Security-Policy/);
assert.match(html, /default-src 'none'/);
assert.doesNotMatch(html, /unsafe-eval|https?:\/\//);
assert.match(app, /ui\/initialize/);
assert.match(app, /ui\/notifications\/initialized/);
assert.match(app, /ui\/resource-teardown/);
assert.match(app, /event\.source !== window\.parent/);
assert.match(app, /event\.origin !== 'null'/);
assert.match(manifest, /io\.modelcontextprotocol\/ui/);
assert.match(manifest, /2026-01-26/);
assert.match(manifest, /text\/html;profile=mcp-app/);
assert.match(manifest, /ui:\/\/io\.mahayana\.example\.github-native-app\/main/);
