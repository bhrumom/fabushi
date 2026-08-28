'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const {
  safeRelative, readDesignPackage, stageBundle, createArtifactManifest, previewPolicy, previewDocument, createMiniAppHandoff, RUNTIME_PROFILES,
} = require('./design-artifact-runtime.cjs');

test('safeRelative rejects traversal and absolute paths', () => {
  assert.throws(() => safeRelative('../secret'));
  assert.throws(() => safeRelative('/etc/passwd'));
  assert.equal(safeRelative('assets/index.html'), 'assets/index.html');
});

test('Fabushi design package contract validates', async () => {
  const root = path.resolve(__dirname, '..', '..', 'design-systems', 'fabushi');
  const result = await readDesignPackage(root);
  assert.equal(result.manifest.id, 'fabushi');
  assert.match(result.design, /## Accessibility/);
  assert.match(result.tokens, /--fabushi-accent/);
});

test('skill staging makes isolated real copies and rejects symlinks', async () => {
  const temp = await fs.mkdtemp(path.join(os.tmpdir(), 'mda-'));
  const source = path.join(temp, 'source');
  const workspace = path.join(temp, 'workspace');
  await fs.mkdir(source); await fs.mkdir(workspace);
  await fs.writeFile(path.join(source, 'SKILL.md'), '# Skill');
  const staged = await stageBundle({ sourceRoot: source, workspaceRoot: workspace, bundleId: 'demo' });
  assert.equal(staged.isolated, true);
  assert.equal(await fs.readFile(path.join(staged.root, 'SKILL.md'), 'utf8'), '# Skill');
  await fs.writeFile(path.join(staged.root, 'SKILL.md'), '# Changed');
  assert.equal(await fs.readFile(path.join(source, 'SKILL.md'), 'utf8'), '# Skill');

  const linked = path.join(temp, 'linked-source');
  await fs.mkdir(linked);
  await fs.writeFile(path.join(linked, 'real.txt'), 'safe');
  await fs.symlink(path.join(linked, 'real.txt'), path.join(linked, 'escape.txt'));
  await assert.rejects(() => stageBundle({ sourceRoot: linked, workspaceRoot: workspace, bundleId: 'linked' }), /symbolic links/);
  await fs.rm(temp, { recursive: true, force: true });
});

test('artifact manifests route preview/export safely', () => {
  const web = createArtifactManifest({ id:'demo', name:'Demo', kind:'web', entrypoint:'index.html', workspaceId:'agent/demo', exports:['html','pdf'] });
  assert.equal(web.preview.renderer, 'sandboxed-html');
  assert.equal(web.workspaceId, 'agent/demo');
  assert.equal(previewPolicy(web).allowNetwork, 'none-by-default');
  const miniapp = createArtifactManifest({ kind:'miniapp', entrypoint:'index.html' });
  assert.equal(previewPolicy(miniapp).allowNetwork, 'via-webmcp-policy');
  assert.equal(createMiniAppHandoff(miniapp).requiresExistingMarketplacePipeline, true);
  assert.throws(() => createArtifactManifest({ kind:'web', entrypoint:'../outside.html' }));
  assert.throws(() => createArtifactManifest({ kind:'web', entrypoint:'index.html', workspaceId:'../outside' }));
  assert.throws(() => createArtifactManifest({ kind:'image', exports:['exe'] }));
});

test('trusted HTML preview injects CSP and never follows a symlink entrypoint', async () => {
  const temp = await fs.mkdtemp(path.join(os.tmpdir(), 'mda-preview-'));
  const managed = path.join(temp, 'workspaces');
  const workspace = path.join(managed, 'agent', 'demo');
  await fs.mkdir(workspace, { recursive: true });
  await fs.writeFile(path.join(workspace, 'index.html'), '<html><head><title>Demo</title></head><body><script>window.ok=1</script></body></html>');
  const manifest = createArtifactManifest({ id:'preview', name:'Preview', kind:'web', entrypoint:'index.html', workspaceId:'agent/demo' });
  const result = await previewDocument({ managedWorkspaceRoot: managed, manifest });
  assert.equal(result.available, true);
  assert.match(result.html, /Content-Security-Policy/);
  assert.match(result.html, /connect-src 'none'/);

  await fs.writeFile(path.join(workspace, 'outside.html'), '<b>outside</b>');
  await fs.symlink(path.join(workspace, 'outside.html'), path.join(workspace, 'linked.html'));
  const linked = createArtifactManifest({ kind:'web', entrypoint:'linked.html', workspaceId:'agent/demo' });
  await assert.rejects(() => previewDocument({ managedWorkspaceRoot: managed, manifest: linked }), /regular file/);
  await fs.rm(temp, { recursive: true, force: true });
});

test('runtime profiles are declarative and do not own an agent loop', () => {
  assert.ok(RUNTIME_PROFILES.some((profile) => profile.id === 'codex'));
  assert.ok(RUNTIME_PROFILES.some((profile) => profile.id === 'grok-build'));
  for (const profile of RUNTIME_PROFILES) {
    assert.equal(typeof profile.run, 'undefined');
    assert.equal(typeof profile.cancel, 'undefined');
    assert.ok(Array.isArray(profile.bins));
  }
});
