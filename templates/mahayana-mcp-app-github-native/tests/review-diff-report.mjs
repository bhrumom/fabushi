import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';

const sha = (path) => crypto.createHash('sha256').update(fs.readFileSync(path)).digest('hex');
const report = {
  permissionsSha256: sha('permissions.json'),
  toolContractSha256: sha('tool-contract.json'),
  artifactDefinitionSha256: sha('mcp-app.yaml'),
};
for (const value of Object.values(report)) assert.match(value, /^[0-9a-f]{64}$/);
fs.mkdirSync('.test-runtime', { recursive: true });
fs.writeFileSync('.test-runtime/review-diff-report.json', JSON.stringify(report, null, 2) + '\n');
