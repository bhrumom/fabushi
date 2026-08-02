import { verifyToken } from '../../auth-utils.js';
import { isAdmin } from '../utils/helpers.js';
import { jsonResponse } from '../utils/response.js';
import { isTestAccountRequest, testAccountUser } from '../utils/test-account.js';
import {
  canonicalJson,
  normalizeReleaseManifest,
  selectMinimalArtifacts,
} from '../marketplace/github-native-contract.js';

const MAX_PACKAGE_BYTES = 50 * 1024 * 1024;
const SAFE_PLUGIN_ID = /^[a-z0-9](?:[a-z0-9._-]{0,126}[a-z0-9])?$/;
const SAFE_VERSION = /^[0-9A-Za-z](?:[0-9A-Za-z.+-]{0,62}[0-9A-Za-z])?$/;
const MARKETPLACE_PLATFORMS = new Set(['cli', 'desktop', 'mobile', 'web']);

function safeSegment(value, pattern) {
  const normalized = String(value || '').trim();
  return pattern.test(normalized) ? normalized : null;
}

async function authenticatedPublisher(request, env, accountDb) {
  if (await isTestAccountRequest(request, env)) {
    return { userId: testAccountUser().userId, admin: false };
  }
  const authorization = request.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) return null;
  const claims = await verifyToken(authorization.slice(7), env);
  const username = claims?.username || claims?.sub;
  if (!username) return null;
  const user = await accountDb.getUser(username);
  if (!user) return null;
  return {
    userId: String(user.id ?? claims.userId ?? username),
    admin: isAdmin(user.email),
  };
}

function safeDeploymentUrl(value) {
  try {
    const url = new URL(String(value || '').trim());
    if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash) {
      return null;
    }
    const hostname = url.hostname.toLowerCase();
    if (hostname === 'localhost' || hostname.endsWith('.localhost') ||
        hostname === '127.0.0.1' || hostname === '::1') {
      return null;
    }
    url.pathname = url.pathname.replace(/\/+$/, '');
    return url.toString().replace(/\/$/, '');
  } catch {
    return null;
  }
}

function deployedBundleUrl(deploymentUrl) {
  return `${deploymentUrl}/mahayana/plugin.tar.gz`;
}

function normalizePlatforms(value) {
  try {
    const parsed = typeof value === 'string' ? JSON.parse(value) : value;
    if (!Array.isArray(parsed)) return null;
    const platforms = [...new Set(parsed.map((platform) => String(platform).trim().toLowerCase()))];
    if (platforms.length === 0 || platforms.some((platform) => !MARKETPLACE_PLATFORMS.has(platform))) {
      return null;
    }
    return platforms;
  } catch {
    return null;
  }
}

export async function handleMarketplaceBrowse(request, env) {
  const url = new URL(request.url);
  const search = url.searchParams.get('q')?.trim();
  const requestedPlatform = url.searchParams.get('platform')?.trim().toLowerCase();
  if (requestedPlatform && !MARKETPLACE_PLATFORMS.has(requestedPlatform)) {
    return jsonResponse({ error: '不支持的市场平台筛选' }, 400);
  }
  const statement = search
    ? env.PLATFORM_DB.prepare(
      `SELECT p.plugin_id, p.display_name, p.description, p.latest_version, p.platforms_json,
              r.package_key, r.package_sha256, r.package_size
         FROM marketplace_plugins p
         JOIN plugin_releases r
           ON r.plugin_id = p.plugin_id AND r.version = p.latest_version
        WHERE p.visibility = 'public' AND p.review_state = 'approved'
          AND (p.plugin_id LIKE ?1 OR p.display_name LIKE ?1 OR p.description LIKE ?1)
        ORDER BY p.updated_at DESC LIMIT 100`,
    ).bind(`%${search}%`)
    : env.PLATFORM_DB.prepare(
      `SELECT p.plugin_id, p.display_name, p.description, p.latest_version, p.platforms_json,
              r.package_key, r.package_sha256, r.package_size
         FROM marketplace_plugins p
         JOIN plugin_releases r
           ON r.plugin_id = p.plugin_id AND r.version = p.latest_version
        WHERE p.visibility = 'public' AND p.review_state = 'approved'
        ORDER BY p.updated_at DESC LIMIT 100`,
    );
  const result = await statement.all();
  const plugins = (result.results || [])
    .map((row) => ({ row, platforms: normalizePlatforms(row.platforms_json) || [] }))
    .filter(({ platforms }) => !requestedPlatform || platforms.includes(requestedPlatform))
    .map(({ row, platforms }) => ({
      pluginId: row.plugin_id,
      displayName: row.display_name,
      description: row.description,
      latestVersion: row.latest_version,
      platforms,
      packageSha256: row.package_sha256,
      packageSize: row.package_size,
      deploymentUrl: row.package_key,
      downloadUrl: deployedBundleUrl(row.package_key),
    }));
  return jsonResponse({ plugins });
}

export async function handleMarketplacePublish(request, env, accountDb) {
  const publisher = await authenticatedPublisher(request, env, accountDb);
  if (!publisher) return jsonResponse({ error: '请先登录大乘软件账号' }, 401);

  const form = await request.formData();
  const pluginId = safeSegment(form.get('pluginId'), SAFE_PLUGIN_ID);
  const version = safeSegment(form.get('version'), SAFE_VERSION);
  const deploymentUrl = safeDeploymentUrl(form.get('deploymentUrl'));
  const declaredSha256 = String(form.get('packageSha256') || '').trim().toLowerCase();
  const declaredSize = Number(form.get('packageSize'));
  const platforms = normalizePlatforms(form.get('platforms'));
  if (!pluginId || !version || !deploymentUrl || !/^[0-9a-f]{64}$/.test(declaredSha256) ||
      !Number.isSafeInteger(declaredSize) || declaredSize < 2 || declaredSize > MAX_PACKAGE_BYTES ||
      !platforms) {
    return jsonResponse({
      error: 'pluginId、version、platforms、HTTPS deploymentUrl、packageSha256 和 packageSize 均须合法',
    }, 400);
  }

  const existing = await env.PLATFORM_DB.prepare(
    'SELECT publisher_user_id FROM marketplace_plugins WHERE plugin_id = ?1',
  ).bind(pluginId).first();
  if (existing && String(existing.publisher_user_id) !== publisher.userId && !publisher.admin) {
    return jsonResponse({ error: '插件 ID 已由其他发布者占用' }, 403);
  }
  const duplicate = await env.PLATFORM_DB.prepare(
    'SELECT 1 AS found FROM plugin_releases WHERE plugin_id = ?1 AND version = ?2',
  ).bind(pluginId, version).first();
  if (duplicate) return jsonResponse({ error: '该插件版本已经发布' }, 409);

  const deployedResponse = await fetch(deployedBundleUrl(deploymentUrl), {
    headers: { Accept: 'application/gzip, application/octet-stream' },
    redirect: 'follow',
  });
  if (!deployedResponse.ok) {
    return jsonResponse({ error: '无法从插件部署地址读取安装包' }, 422);
  }
  const packageBytes = new Uint8Array(await deployedResponse.arrayBuffer());
  if (packageBytes.byteLength !== declaredSize || packageBytes.byteLength > MAX_PACKAGE_BYTES ||
      packageBytes[0] !== 0x1f || packageBytes[1] !== 0x8b) {
    return jsonResponse({ error: '部署地址返回的插件包大小或格式不匹配' }, 422);
  }
  const digest = await crypto.subtle.digest('SHA-256', packageBytes);
  const packageSha256 = [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
  if (packageSha256 !== declaredSha256) {
    return jsonResponse({ error: '部署地址返回的插件包 SHA-256 不匹配' }, 422);
  }

  const now = Math.floor(Date.now() / 1000);
  const reviewState = publisher.admin ? 'approved' : 'pending';
  await env.PLATFORM_DB.batch([
      env.PLATFORM_DB.prepare(
        `INSERT INTO marketplace_plugins
           (plugin_id, display_name, description, publisher_user_id, latest_version, platforms_json,
            visibility, review_state, created_at, updated_at)
         VALUES (?1, ?1, ?2, ?3, ?4, ?5, 'public', ?6, ?7, ?7)
         ON CONFLICT(plugin_id) DO UPDATE SET
           latest_version = excluded.latest_version,
           platforms_json = excluded.platforms_json,
           updated_at = excluded.updated_at,
           review_state = CASE
             WHEN marketplace_plugins.review_state = 'approved' THEN 'approved'
             ELSE excluded.review_state
           END`,
      ).bind(
        pluginId,
        `大乘插件 ${pluginId}`,
        publisher.userId,
        version,
        JSON.stringify(platforms),
        reviewState,
        now,
      ),
      env.PLATFORM_DB.prepare(
        `INSERT INTO plugin_releases
           (plugin_id, version, package_key, package_sha256, package_size,
            tuf_target_path, published_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)`,
      ).bind(
        pluginId,
        version,
        deploymentUrl,
        packageSha256,
        packageBytes.byteLength,
        `plugins/${pluginId}/${version}.tar.gz`,
        now,
      ),
  ]);

  return jsonResponse({
    status: reviewState === 'approved' ? 'published' : 'pending_review',
    pluginId,
    version,
    reviewState,
    packageSha256,
    packageSize: packageBytes.byteLength,
    deploymentUrl,
    platforms,
    downloadUrl: reviewState === 'approved'
      ? deployedBundleUrl(deploymentUrl)
      : null,
    publishedAt: now,
  }, 201);
}

export async function handleMarketplaceDownload(request, env) {
  const pathname = new URL(request.url).pathname;
  const match = pathname.match(/^\/v1\/marketplace\/plugins\/([^/]+)\/releases\/([^/]+)\/download$/);
  const pluginId = safeSegment(decodeURIComponent(match?.[1] || ''), SAFE_PLUGIN_ID);
  const version = safeSegment(decodeURIComponent(match?.[2] || ''), SAFE_VERSION);
  if (!pluginId || !version) return jsonResponse({ error: '插件版本路径无效' }, 400);

  const release = await env.PLATFORM_DB.prepare(
    `SELECT r.package_key, r.package_sha256, r.package_size
       FROM plugin_releases r
       JOIN marketplace_plugins p ON p.plugin_id = r.plugin_id
      WHERE r.plugin_id = ?1 AND r.version = ?2
        AND p.visibility = 'public' AND p.review_state = 'approved'`,
  ).bind(pluginId, version).first();
  if (!release) return jsonResponse({ error: '未找到已审核的插件版本' }, 404);
  const deploymentUrl = safeDeploymentUrl(release.package_key);
  if (!deploymentUrl) return jsonResponse({ error: '插件部署地址无效' }, 503);
  return Response.redirect(deployedBundleUrl(deploymentUrl), 307);
}

function contractError(error, fallbackCode = 'manifest_invalid', status = 400) {
  return jsonResponse({
    error: String(error?.message || error || 'Marketplace contract validation failed.'),
    code: String(error?.code || fallbackCode),
    details: error?.details,
  }, status);
}

function v2ReleasePath(request, suffix = '') {
  const escapedSuffix = suffix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = new URL(request.url).pathname.match(new RegExp(
    `^/v2/marketplace/plugins/([^/]+)/releases/([^/]+)${escapedSuffix}$`,
  ));
  return {
    pluginId: safeSegment(decodeURIComponent(match?.[1] || ''), SAFE_PLUGIN_ID),
    version: safeSegment(decodeURIComponent(match?.[2] || ''), SAFE_VERSION),
  };
}

async function sha256Text(value) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function artifactPlatformJson(artifact) {
  if (artifact.kind === 'common') return JSON.stringify({ platform: 'all' });
  if (artifact.kind === 'native-cli') {
    return JSON.stringify({ platform: 'native', os: artifact.os, architecture: artifact.architecture });
  }
  return JSON.stringify({ platform: 'web-wasm', webTargets: artifact.webTargets, wasmFeatures: artifact.wasmFeatures });
}

export async function handleMarketplaceV2Stage(request, env, accountDb) {
  const publisher = await authenticatedPublisher(request, env, accountDb);
  if (!publisher) return jsonResponse({ code: 'unauthorized', error: 'A publisher account is required.' }, 401);

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ code: 'manifest_invalid', error: 'A JSON release manifest is required.' }, 400);
  }
  let manifest;
  try {
    manifest = normalizeReleaseManifest(body?.manifest ?? body);
  } catch (error) {
    return contractError(error);
  }
  const pathname = new URL(request.url).pathname;
  const pathMatch = pathname.match(/^\/v2\/marketplace\/plugins\/([^/]+)\/releases\/stage$/);
  const pathPluginId = safeSegment(decodeURIComponent(pathMatch?.[1] || ''), SAFE_PLUGIN_ID);
  if (!pathPluginId || pathPluginId !== manifest.pluginId) {
    return jsonResponse({ code: 'manifest_mismatch', error: 'Path plugin ID must match the release manifest.' }, 400);
  }

  const existing = await env.PLATFORM_DB.prepare(
    'SELECT publisher_user_id FROM marketplace_plugins WHERE plugin_id = ?1',
  ).bind(manifest.pluginId).first();
  if (existing && String(existing.publisher_user_id) !== publisher.userId && !publisher.admin) {
    return jsonResponse({ code: 'plugin_owner_mismatch', error: 'The plugin ID belongs to another publisher.' }, 403);
  }
  const duplicate = await env.PLATFORM_DB.prepare(
    'SELECT release_status FROM plugin_releases WHERE plugin_id = ?1 AND version = ?2',
  ).bind(manifest.pluginId, manifest.version).first();
  if (duplicate) {
    return jsonResponse({ code: 'version_already_exists', error: 'Plugin versions are immutable.' }, 409);
  }

  const canonicalManifest = canonicalJson(manifest);
  const manifestSha256 = await sha256Text(canonicalManifest);
  const now = Math.floor(Date.now() / 1000);
  const statements = [
    env.PLATFORM_DB.prepare(
      `INSERT INTO marketplace_plugins
         (plugin_id, display_name, description, publisher_user_id, latest_version, platforms_json,
          visibility, review_state, created_at, updated_at, production_version, migration_state)
       VALUES (?1, ?1, ?2, ?3, NULL, ?4, 'private', 'pending', ?5, ?5, NULL, 'ready')
       ON CONFLICT(plugin_id) DO UPDATE SET updated_at = excluded.updated_at`,
    ).bind(
      manifest.pluginId,
      `GitHub-native MCP App ${manifest.pluginId}`,
      publisher.userId,
      JSON.stringify([...new Set(manifest.artifacts.flatMap((artifact) => {
        if (artifact.kind === 'common') return [];
        if (artifact.kind === 'native-cli') return ['cli', 'desktop'];
        return artifact.webTargets;
      }))].sort()),
      now,
    ),
    env.PLATFORM_DB.prepare(
      `INSERT INTO plugin_releases
         (plugin_id, version, package_key, package_sha256, package_size, tuf_target_path,
          published_at, deployment_url, source_json, release_manifest_json,
          release_manifest_sha256, release_status, metadata_version)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, '', ?8, ?9, ?10, 'staged', 3)`,
    ).bind(
      manifest.pluginId,
      manifest.version,
      manifest.artifacts[0].url,
      manifest.parentManifestSha256,
      manifest.artifacts.reduce((total, artifact) => total + artifact.size, 0),
      `plugins/${manifest.pluginId}/${manifest.version}/manifest-v3.json`,
      now,
      canonicalJson(manifest.source),
      canonicalManifest,
      manifestSha256,
    ),
    ...manifest.artifacts.map((artifact) => env.PLATFORM_DB.prepare(
      `INSERT INTO plugin_release_artifacts
         (plugin_id, version, artifact_id, artifact_kind, platform_json, source_commit,
          artifact_url, artifact_sha256, artifact_size, media_type, sbom_url,
          attestation_url, min_host_version, required_capabilities_json, created_at)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15)`,
    ).bind(
      manifest.pluginId,
      manifest.version,
      artifact.id,
      artifact.kind,
      artifactPlatformJson(artifact),
      artifact.sourceCommit,
      artifact.url,
      artifact.sha256,
      artifact.size,
      artifact.mediaType,
      artifact.sbomUrl,
      artifact.attestationUrl,
      artifact.minHostVersion,
      JSON.stringify(artifact.requiredCapabilities),
      now,
    )),
  ];
  await env.PLATFORM_DB.batch(statements);

  return jsonResponse({
    status: 'staged',
    pluginId: manifest.pluginId,
    version: manifest.version,
    source: manifest.source,
    provenance: manifest.provenance,
    manifestSha256,
    artifactIds: manifest.artifacts.map((artifact) => artifact.id),
    totalSize: manifest.artifacts.reduce((total, artifact) => total + artifact.size, 0),
    installable: false,
    reviewRequired: true,
  }, 201);
}

async function loadV2Release(request, env, suffix = '') {
  const { pluginId, version } = v2ReleasePath(request, suffix);
  if (!pluginId || !version) {
    return { response: jsonResponse({ code: 'manifest_invalid', error: 'Invalid plugin release path.' }, 400) };
  }
  const release = await env.PLATFORM_DB.prepare(
    `SELECT release_manifest_json, release_manifest_sha256, release_status,
            revoked_at, revocation_reason
       FROM plugin_releases
      WHERE plugin_id = ?1 AND version = ?2`,
  ).bind(pluginId, version).first();
  if (!release) {
    return { response: jsonResponse({ code: 'marketplace_release_not_found', error: 'Release not found.' }, 404) };
  }
  if (release.release_status === 'revoked') {
    return { response: jsonResponse({
      code: 'release_revoked',
      error: 'Release has been revoked.',
      revokedAt: release.revoked_at,
      reason: release.revocation_reason,
    }, 410) };
  }
  let manifest;
  try {
    manifest = normalizeReleaseManifest(JSON.parse(release.release_manifest_json));
  } catch (error) {
    return { response: contractError(error, 'signature_invalid', 503) };
  }
  return { pluginId, version, release, manifest };
}

export async function handleMarketplaceV2Release(request, env) {
  const loaded = await loadV2Release(request, env);
  if (loaded.response) return loaded.response;
  return jsonResponse({
    releaseStatus: loaded.release.release_status,
    installable: loaded.release.release_status === 'approved',
    manifestSha256: loaded.release.release_manifest_sha256,
    manifest: loaded.manifest,
  });
}

export async function handleMarketplaceV2Resolve(request, env) {
  const loaded = await loadV2Release(request, env, '/download');
  if (loaded.response) return loaded.response;
  if (loaded.release.release_status !== 'approved') {
    return jsonResponse({ code: 'marketplace_release_not_approved', error: 'Release is not approved.' }, 404);
  }
  const url = new URL(request.url);
  let selection;
  try {
    selection = selectMinimalArtifacts(loaded.manifest, {
      platform: url.searchParams.get('platform'),
      os: url.searchParams.get('os'),
      architecture: url.searchParams.get('architecture'),
      hostVersion: url.searchParams.get('hostVersion'),
      capabilities: url.searchParams.getAll('capability'),
    });
  } catch (error) {
    return contractError(error, 'platform_unsupported');
  }
  return jsonResponse({
    ...selection,
    manifestSha256: loaded.release.release_manifest_sha256,
    permissionsSha256: loaded.manifest.permissionsSha256,
    toolContractSha256: loaded.manifest.toolContract.sha256,
    source: loaded.manifest.source,
    provenance: loaded.manifest.provenance,
  });
}
