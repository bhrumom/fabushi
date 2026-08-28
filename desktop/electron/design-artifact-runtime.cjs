'use strict';

const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');

const DESIGN_SCHEMA = 'fabushi-design-system/v1';
const ARTIFACT_SCHEMA = 'mahayana-artifact/v1';
const MAX_PREVIEW_BYTES = 2 * 1024 * 1024;
const ALLOWED_ARTIFACT_KINDS = new Set(['miniapp','web','dashboard','document','deck','image','video','audio','data']);
const PREVIEW_BY_KIND = Object.freeze({
  miniapp: 'miniapp-host', web: 'sandboxed-html', dashboard: 'sandboxed-html', document: 'document',
  deck: 'deck', image: 'image', video: 'video', audio: 'audio', data: 'data',
});
const EXPORTERS = Object.freeze({
  miniapp: ['source','zip'], web: ['html','zip','pdf'], dashboard: ['html','pdf'], document: ['pdf','html'],
  deck: ['pptx','pdf','html'], image: ['png','webp'], video: ['mp4'], audio: ['wav','mp3'], data: ['json','csv'],
});
const RUNTIME_PROFILES = Object.freeze([
  { id:'codex', name:'Codex CLI', bins:['codex'], streamFormat:'json-event-stream', capabilities:['resume','cancel','mcp','models'] },
  { id:'grok-build', name:'Grok Build', bins:['grok','grok-build'], streamFormat:'plain', capabilities:['cancel'] },
  { id:'claude', name:'Claude Code', bins:['claude'], streamFormat:'claude-stream-json', capabilities:['resume','cancel','mcp','models'] },
  { id:'deepseek-harness', name:'DeepSeek Harness', bins:['dsh'], streamFormat:'dsh-profile-jsonl', capabilities:['resume','cancel','mcp','models'] },
  { id:'cursor-agent', name:'Cursor Agent', bins:['cursor-agent'], streamFormat:'json-event-stream', capabilities:['cancel','models'] },
]);

function clean(value, limit = 4096) { return String(value ?? '').replace(/\0/g, '').trim().slice(0, limit); }
function ensureInside(root, candidate) {
  const base = path.resolve(root);
  const target = path.resolve(candidate);
  if (target !== base && !target.startsWith(`${base}${path.sep}`)) throw new Error('Path escapes managed root.');
  return target;
}
function safeRelative(value) {
  const input = clean(value, 1000).replace(/\\/g, '/');
  if (!input || input.startsWith('/') || /^[A-Za-z]:\//.test(input)) throw new Error('A safe relative path is required.');
  const normalized = path.posix.normalize(input);
  if (normalized === '..' || normalized.startsWith('../') || normalized.includes('/../')) throw new Error('Path traversal is not allowed.');
  return normalized;
}
function parseJson(text, label) { try { return JSON.parse(text); } catch { throw new Error(`${label} is invalid JSON.`); } }

async function readDesignPackage(root) {
  const manifestPath = ensureInside(root, path.join(root, 'manifest.json'));
  const manifest = parseJson(await fs.readFile(manifestPath, 'utf8'), 'Design manifest');
  if (manifest.schemaVersion !== DESIGN_SCHEMA) throw new Error('Unsupported design-system schema.');
  if (!/^[a-z0-9][a-z0-9-]*$/.test(clean(manifest.id, 120))) throw new Error('Invalid design-system id.');
  const designRel = safeRelative(manifest.files?.design || 'DESIGN.md');
  const tokensRel = safeRelative(manifest.files?.tokens || 'tokens.css');
  const design = await fs.readFile(ensureInside(root, path.join(root, designRel)), 'utf8');
  const tokens = await fs.readFile(ensureInside(root, path.join(root, tokensRel)), 'utf8');
  if (!/^#\s+/m.test(design) || (design.match(/^##\s+/gm) || []).length < 7) throw new Error('DESIGN.md lacks substantive design sections.');
  if (!/:root\s*\{[\s\S]*--fabushi-/m.test(tokens)) throw new Error('tokens.css lacks canonical semantic tokens.');
  return { manifest, design, tokens };
}

async function copyTree(source, target) {
  const sourceReal = await fs.realpath(source);
  await fs.mkdir(target, { recursive: true });
  for (const entry of await fs.readdir(source, { withFileTypes: true })) {
    if (entry.isSymbolicLink()) throw new Error('Skill/design bundles may not contain symbolic links.');
    const from = ensureInside(sourceReal, path.join(sourceReal, entry.name));
    const to = ensureInside(target, path.join(target, entry.name));
    if (entry.isDirectory()) await copyTree(from, to);
    else if (entry.isFile()) await fs.copyFile(from, to);
  }
}

async function stageBundle({ sourceRoot, workspaceRoot, bundleId }) {
  const source = await fs.realpath(sourceRoot);
  const workspace = await fs.realpath(workspaceRoot);
  const id = clean(bundleId, 120);
  if (!/^[a-z0-9][a-z0-9-]*$/.test(id)) throw new Error('Invalid bundle id.');
  const hash = crypto.createHash('sha256').update(source).digest('hex').slice(0, 12);
  const root = ensureInside(workspace, path.join(workspace, '.mahayana', 'staged-skills', `${id}-${hash}`));
  await fs.rm(root, { recursive: true, force: true });
  await copyTree(source, root);
  return { id, root, source, isolated: true };
}

function createArtifactManifest(input = {}) {
  const kind = clean(input.kind, 40).toLowerCase();
  if (!ALLOWED_ARTIFACT_KINDS.has(kind)) throw new Error('Unsupported artifact kind.');
  const entrypoint = safeRelative(input.entrypoint || (kind === 'miniapp' || kind === 'web' || kind === 'dashboard' ? 'index.html' : 'artifact.json'));
  const workspaceId = input.workspaceId ? safeRelative(input.workspaceId) : undefined;
  const exportsRequested = Array.isArray(input.exports) ? input.exports.map((item) => clean(item, 24).toLowerCase()).filter(Boolean) : [];
  const allowed = EXPORTERS[kind] || [];
  for (const format of exportsRequested) if (!allowed.includes(format)) throw new Error(`Exporter ${format} is not available for ${kind}.`);
  return {
    schemaVersion: ARTIFACT_SCHEMA,
    id: clean(input.id, 160) || `artifact-${Date.now()}`,
    name: clean(input.name, 240) || kind,
    kind,
    entrypoint,
    ...(workspaceId ? { workspaceId } : {}),
    preview: { renderer: PREVIEW_BY_KIND[kind], sandboxed: ['miniapp','web','dashboard'].includes(kind) },
    exports: exportsRequested.length ? exportsRequested : allowed,
    designSystemId: clean(input.designSystemId, 120) || 'fabushi',
    miniApp: kind === 'miniapp' ? { publishable: true, runtime: 'fabushi-miniapp', marketplaceHandoff: true } : undefined,
  };
}

function previewPolicy(manifest) {
  if (!manifest || manifest.schemaVersion !== ARTIFACT_SCHEMA) throw new Error('Invalid artifact manifest.');
  const entrypoint = safeRelative(manifest.entrypoint);
  return {
    renderer: PREVIEW_BY_KIND[manifest.kind] || 'none',
    sandboxed: ['miniapp','web','dashboard'].includes(manifest.kind),
    allowNetwork: manifest.kind === 'miniapp' ? 'via-webmcp-policy' : 'none-by-default',
    entrypoint,
    openExternally: !['miniapp','web','dashboard'].includes(manifest.kind),
  };
}

function injectPreviewCsp(html) {
  const csp = "default-src 'none'; img-src data: blob:; media-src data: blob:; font-src data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'none'; form-action 'none'; base-uri 'none'";
  const meta = `<meta http-equiv="Content-Security-Policy" content="${csp}">`;
  if (/<head(?:\s[^>]*)?>/i.test(html)) return html.replace(/<head(?:\s[^>]*)?>/i, (match) => `${match}${meta}`);
  return `<!doctype html><html><head>${meta}</head><body>${html}</body></html>`;
}

async function previewDocument({ managedWorkspaceRoot, manifest }) {
  const policy = previewPolicy(manifest);
  if (!['sandboxed-html'].includes(policy.renderer)) {
    return { ...policy, available: false, reason: policy.renderer === 'miniapp-host' ? 'MiniApps preview through the existing MiniApp host.' : 'This artifact uses a native/file renderer.' };
  }
  if (!manifest.workspaceId) throw new Error('Artifact preview requires a managed workspaceId.');
  const workspaceId = safeRelative(manifest.workspaceId);
  const workspace = ensureInside(managedWorkspaceRoot, path.join(managedWorkspaceRoot, workspaceId));
  const realWorkspace = await fs.realpath(workspace);
  const target = ensureInside(realWorkspace, path.join(realWorkspace, policy.entrypoint));
  const stat = await fs.lstat(target);
  if (!stat.isFile() || stat.isSymbolicLink()) throw new Error('Artifact entrypoint must be a regular file.');
  if (stat.size > MAX_PREVIEW_BYTES) throw new Error('Artifact preview exceeds the size limit.');
  const html = await fs.readFile(target, 'utf8');
  return { ...policy, available: true, html: injectPreviewCsp(html), bytes: stat.size };
}

function createMiniAppHandoff(manifest, options = {}) {
  if (manifest?.kind !== 'miniapp' || manifest?.schemaVersion !== ARTIFACT_SCHEMA) throw new Error('MiniApp artifact required.');
  return {
    type: 'fabushi-miniapp-publish-handoff/v1',
    artifactId: manifest.id,
    entrypoint: manifest.entrypoint,
    workspaceId: manifest.workspaceId || null,
    designSystemId: manifest.designSystemId,
    requestedVisibility: clean(options.visibility, 24) || 'private',
    requiresExistingMarketplacePipeline: true,
    requiresCapabilityReview: true,
  };
}

function wrapNativeCapabilityHandlers(baseFactory) {
  if (typeof baseFactory !== 'function') throw new TypeError('baseFactory must be a function');
  return function createDesignArtifactAwareHandlers(deps) {
    const base = baseFactory(deps);
    const resourcesRoot = process.resourcesPath || path.resolve(__dirname, '..', '..');
    const repoRoot = path.resolve(__dirname, '..', '..');
    const managedWorkspaceRoot = path.join(deps.app.getPath('userData'), 'workspaces');
    const resolveBundled = (relative) => process.defaultApp
      ? path.join(repoRoot, relative)
      : path.join(resourcesRoot, relative);
    return {
      ...base,
      async getDesignSystem(params = {}) {
        const id = clean(params.id, 120) || 'fabushi';
        if (id !== 'fabushi') throw new Error('Only the canonical Fabushi design system is bundled.');
        return readDesignPackage(resolveBundled(path.join('design-systems', id)));
      },
      async listDesignCraft() {
        const root = resolveBundled('craft');
        return (await fs.readdir(root)).filter((name) => name.endsWith('.md')).map((name) => name.slice(0, -3)).sort();
      },
      async getDesignRuntimeProfiles() { return RUNTIME_PROFILES.map((item) => ({ ...item, bins: [...item.bins], capabilities: [...item.capabilities] })); },
      async stageDesignSkill(params = {}) {
        const skillId = clean(params.skillId, 120) || 'fabushi-design';
        if (!/^[a-z0-9][a-z0-9-]*$/.test(skillId)) throw new Error('Invalid skill id.');
        const sourceRoot = resolveBundled(path.join('.agent', 'skills', skillId));
        const workspaceId = safeRelative(params.workspaceId || params.agentId || 'mahayana-assistant');
        const workspaceRoot = ensureInside(managedWorkspaceRoot, path.join(managedWorkspaceRoot, workspaceId));
        await fs.mkdir(workspaceRoot, { recursive: true });
        return stageBundle({ sourceRoot, workspaceRoot, bundleId: skillId });
      },
      async createArtifactManifest(params = {}) { return createArtifactManifest(params); },
      async getArtifactPreviewPolicy(params = {}) { return previewPolicy(params.manifest); },
      async getArtifactPreviewDocument(params = {}) { return previewDocument({ managedWorkspaceRoot, manifest: params.manifest }); },
      async listArtifactExporters(params = {}) {
        const kind = clean(params.kind, 40).toLowerCase();
        if (!ALLOWED_ARTIFACT_KINDS.has(kind)) throw new Error('Unsupported artifact kind.');
        return { kind, formats: [...EXPORTERS[kind]], executionOwner: 'mahayana-host', failClosed: true };
      },
      async createMiniAppPublishHandoff(params = {}) { return createMiniAppHandoff(params.manifest, params); },
    };
  };
}

module.exports = {
  DESIGN_SCHEMA, ARTIFACT_SCHEMA, RUNTIME_PROFILES, EXPORTERS,
  safeRelative, readDesignPackage, stageBundle, createArtifactManifest, previewPolicy, previewDocument, injectPreviewCsp,
  createMiniAppHandoff, wrapNativeCapabilityHandlers,
};
