import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const nativeWorkflowPath = new URL('../../.github/workflows/native-mobile.yml', import.meta.url);
const postMainPath = new URL('../../.github/workflows/post-main-delivery.yml', import.meta.url);
const releaseGatePath = new URL('../../.github/scripts/require-release-source-gates.sh', import.meta.url);

async function read(url) {
  return readFile(url, 'utf8');
}

test('native workflow has no second runner whose only job is aggregating platform status', async () => {
  const source = await read(nativeWorkflowPath);
  assert.match(source, /name:\s*\$\{\{ matrix\.check_name \}\}/u);
  assert.match(source, /check_name":"Native Android"/u);
  assert.match(source, /check_name":"Native iOS"/u);
  assert.doesNotMatch(source, /\n  result:\s*\n/u);
  assert.doesNotMatch(source, /name:\s*Native mobile result/u);
  assert.doesNotMatch(source, /Require every native mobile matrix job/u);
});

test('formal release source gate names the real native platform checks directly', async () => {
  const source = await read(releaseGatePath);
  assert.match(source, /android\)[\s\S]*required_checks=\('CI result' 'Native Android'\)/u);
  assert.match(source, /ios\)[\s\S]*required_checks=\('CI result' 'Native iOS'\)/u);
  assert.match(source, /both\)[\s\S]*'Native Android' 'Native iOS'/u);
  assert.doesNotMatch(source, /Native mobile result/u);
});

test('post-main delivery waits on direct Android and iOS checks, not an aggregate runner', async () => {
  const source = await read(postMainPath);
  assert.match(source, /required_checks=\('Native Android' 'Native iOS'\)/u);
  assert.match(source, /- Native Android: success/u);
  assert.match(source, /- Native iOS: success/u);
  assert.doesNotMatch(source, /Native mobile result/u);
  assert.match(source, /--paginate --slurp/u);
  assert.match(source, /map\(\.check_runs\) \| add/u);
});
