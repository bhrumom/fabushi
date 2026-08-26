#!/usr/bin/env python3
from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one marker, found {count}: {old[:120]!r}')
    file_path.write_text(text.replace(old, new, 1), encoding='utf-8')


# Account sync store: expose a safe event append API so existing account-owned
# subsystems can invalidate another device without duplicating payload bytes.
replace_once(
    'ai-backend/src/account_sync_store.js',
    "  currentCursor(accountIdInput) {\n",
    "  recordEvent(accountIdInput, eventTypeInput, entityIdInput, payload = {}) {\n"
    "    const accountId = normalizeAccountId(accountIdInput);\n"
    "    const eventType = String(eventTypeInput ?? '').trim();\n"
    "    const entityId = String(entityIdInput ?? '').trim();\n"
    "    if (!eventType || !entityId) throw new Error('account sync event type and entity id are required');\n"
    "    const sequence = this.#appendEvent(accountId, eventType, entityId, payload);\n"
    "    return { sequence, cursor: encodeCursor(sequence) };\n"
    "  }\n\n"
    "  currentCursor(accountIdInput) {\n",
)

# Platform Mini App message/content APIs already use canonical resolveUser().
# Feed lightweight invalidation events into the same account difference stream.
replace_once(
    'ai-backend/src/platform_api.js',
    "import crypto from 'node:crypto';\n\nimport { publicManifestSummary, validateAgentManifest } from './agent_manifest.js';\n",
    "import crypto from 'node:crypto';\n\nimport { AccountSyncStore } from './account_sync_store.js';\nimport { publicManifestSummary, validateAgentManifest } from './agent_manifest.js';\n",
)
replace_once(
    'ai-backend/src/platform_api.js',
    "export function registerPlatformApi({ app, db, resolveUser, asyncHandler }) {\n  ensurePlatformSchema(db);\n  const s = createStatements(db);\n",
    "export function registerPlatformApi({ app, db, resolveUser, asyncHandler }) {\n  ensurePlatformSchema(db);\n  const s = createStatements(db);\n  const accountSync = new AccountSyncStore({ db });\n",
)
replace_once(
    'ai-backend/src/platform_api.js',
    "      stored += 1;\n    }\n    return ok(res, 200, reqId, { pluginInstanceId, stored });\n",
    "      stored += 1;\n"
    "      accountSync.recordEvent(\n"
    "        user.userId,\n"
    "        'miniapp.bot.message',\n"
    "        `${pluginInstanceId}:${messageId}`,\n"
    "        { miniAppId: pluginInstanceId, messageId, role, createdAt, updatedAt },\n"
    "      );\n"
    "    }\n"
    "    return ok(res, 200, reqId, { pluginInstanceId, stored });\n",
)
replace_once(
    'ai-backend/src/platform_api.js',
    "    s.upsertMiniAppContentState.run({ userId: user.userId, pluginInstanceId, stateJson: asJson(state), updatedAt });\n    return ok(res, 200, reqId, { pluginInstanceId, state, updatedAt });\n",
    "    s.upsertMiniAppContentState.run({ userId: user.userId, pluginInstanceId, stateJson: asJson(state), updatedAt });\n"
    "    accountSync.recordEvent(\n"
    "      user.userId,\n"
    "      'miniapp.content.updated',\n"
    "      pluginInstanceId,\n"
    "      { miniAppId: pluginInstanceId, updatedAt },\n"
    "    );\n"
    "    return ok(res, 200, reqId, { pluginInstanceId, state, updatedAt });\n",
)

# MCP marketplace mutations must use the same account authority as REST/Desktop.
replace_once(
    'ai-backend/src/miniapp_marketplace_mcp.js',
    "export function createMarketplaceMcpServer(store, scopeId, baseUrl) {\n",
    "export function createMarketplaceMcpServer(store, scopeId, baseUrl, accountState = null) {\n",
)
replace_once(
    'ai-backend/src/miniapp_marketplace_mcp.js',
    "    const payload = browseMarketplace(store, { query, platform, limit, scopeId }, baseUrl);\n",
    "    const payload = accountState?.browse\n"
    "      ? accountState.browse({ query, platform, limit }, baseUrl)\n"
    "      : browseMarketplace(store, { query, platform, limit, scopeId }, baseUrl);\n",
)
replace_once(
    'ai-backend/src/miniapp_marketplace_mcp.js',
    "    const added = store.add(miniAppId, scopeId);\n",
    "    const added = accountState?.add ? accountState.add(miniAppId) : store.add(miniAppId, scopeId);\n",
)
replace_once(
    'ai-backend/src/miniapp_marketplace_mcp.js',
    "  }, async ({ miniAppId }) => result('Mini App removed.', store.remove(miniAppId, scopeId)));\n",
    "  }, async ({ miniAppId }) => result(\n"
    "    'Mini App removed.',\n"
    "    accountState?.remove ? accountState.remove(miniAppId) : store.remove(miniAppId, scopeId),\n"
    "  ));\n",
)
replace_once(
    'ai-backend/src/miniapp_marketplace_mcp.js',
    "    apps: store.added(scopeId),\n",
    "    apps: accountState?.added ? accountState.added() : store.added(scopeId),\n",
)
replace_once(
    'ai-backend/src/miniapp_marketplace_mcp.js',
    "    const publisher = { id: scopeId.replace(/^scope-/, 'publisher-').slice(0, 34), displayName: input.publisherName };\n",
    "    const publisher = {\n"
    "      id: String(accountState?.publisherId ?? scopeId.replace(/^scope-/, 'publisher-')).slice(0, 64),\n"
    "      displayName: input.publisherName,\n"
    "    };\n",
)

# Expose account/difference, Bot membership, Mini App message history, CloudStorage,
# and local-package reconciliation through the existing authenticated native edge.
native_marker = """    async routeMiniAppInput(params) {
      const pluginId = cleanString(params.pluginId ?? params.id, 200);
      const input = cleanString(params.input ?? params.message, 10_000);
      if (!pluginId) throw new Error('Mini App id is required.');
      if (!input) throw new Error('Mini App Bot input is required.');
      return platformRequest('POST', `/v1/marketplace/plugins/${encodeURIComponent(pluginId)}/route`, {
        body: { input },
      });
    },

    getEffectivePlugins() {
"""
native_replacement = """    async routeMiniAppInput(params) {
      const pluginId = cleanString(params.pluginId ?? params.id, 200);
      const input = cleanString(params.input ?? params.message, 10_000);
      if (!pluginId) throw new Error('Mini App id is required.');
      if (!input) throw new Error('Mini App Bot input is required.');
      return platformRequest('POST', `/v1/marketplace/plugins/${encodeURIComponent(pluginId)}/route`, {
        body: { input },
      });
    },

    async getAccountSync(params) {
      const cursor = cleanString(params.cursor, 160);
      const limit = Math.max(1, Math.min(1000, Number(params.limit) || 200));
      return platformRequest('GET', '/v1/account/sync', {
        query: { ...(cursor ? { cursor } : {}), limit },
      });
    },

    getAccountMiniApps() {
      return platformRequest('GET', '/v1/marketplace/added');
    },

    getAccountBots() {
      return platformRequest('GET', '/v1/account/bots');
    },

    async addBotToAccount(params) {
      const botId = cleanString(params.botId ?? params.id, 160);
      if (!botId) throw new Error('Bot id is required.');
      const bot = params.bot && typeof params.bot === 'object' ? params.bot : params;
      return platformRequest('POST', `/v1/account/bots/${encodeURIComponent(botId)}/add`, { body: { bot } });
    },

    async removeBotFromAccount(params) {
      const botId = cleanString(params.botId ?? params.id, 160);
      if (!botId) throw new Error('Bot id is required.');
      return platformRequest('DELETE', `/v1/account/bots/${encodeURIComponent(botId)}/add`);
    },

    async getMiniAppBotMessages(params) {
      const pluginId = cleanString(params.pluginId ?? params.id, 200);
      if (!pluginId) throw new Error('Mini App id is required.');
      const after = cleanString(params.after, 160);
      const limit = Math.max(1, Math.min(1000, Number(params.limit) || 500));
      return platformRequest('GET', `/api/miniapps/${encodeURIComponent(pluginId)}/messages`, {
        query: { ...(after ? { after } : {}), limit },
      });
    },

    async appendMiniAppBotMessages(params) {
      const pluginId = cleanString(params.pluginId ?? params.id, 200);
      if (!pluginId) throw new Error('Mini App id is required.');
      const messages = Array.isArray(params.messages) ? params.messages : [];
      if (!messages.length || messages.length > 100) throw new Error('Mini App Bot messages must contain 1-100 entries.');
      return platformRequest('POST', `/api/miniapps/${encodeURIComponent(pluginId)}/messages`, { body: { messages } });
    },

    async getMiniAppCloudStorage(params) {
      const pluginId = cleanString(params.pluginId ?? params.id, 200);
      if (!pluginId) throw new Error('Mini App id is required.');
      const key = cleanString(params.key, 128);
      return platformRequest('GET', `/v1/miniapps/${encodeURIComponent(pluginId)}/cloud-storage`, {
        query: key ? { key } : undefined,
      });
    },

    async setMiniAppCloudStorage(params) {
      const pluginId = cleanString(params.pluginId ?? params.id, 200);
      if (!pluginId) throw new Error('Mini App id is required.');
      const values = params.values && typeof params.values === 'object' && !Array.isArray(params.values) ? params.values : {};
      return platformRequest('PUT', `/v1/miniapps/${encodeURIComponent(pluginId)}/cloud-storage`, { body: { values } });
    },

    async deleteMiniAppCloudStorage(params) {
      const pluginId = cleanString(params.pluginId ?? params.id, 200);
      const key = cleanString(params.key, 128);
      if (!pluginId || !key) throw new Error('Mini App id and CloudStorage key are required.');
      return platformRequest('DELETE', `/v1/miniapps/${encodeURIComponent(pluginId)}/cloud-storage`, { query: { key } });
    },

    async reconcileAccountMiniApps() {
      const account = await this.getAccountMiniApps();
      const apps = Array.isArray(account?.apps) ? account.apps : [];
      const desired = new Map(apps.map((entry) => [cleanString(entry?.id ?? entry?.pluginId, 200), entry]).filter(([id]) => id));
      const installed = new Map((await installedPluginPointers()).map((entry) => [entry.pluginId, entry]));
      const state = await readNativeState();
      const previousManaged = new Set(Array.isArray(state.accountManagedMiniApps) ? state.accountManagedMiniApps.map((id) => cleanString(id, 200)).filter(Boolean) : []);
      const installedNow = [];
      const removedNow = [];
      const failures = [];

      for (const [pluginId, entry] of desired) {
        if (installed.has(pluginId)) continue;
        const version = cleanString(entry?.version ?? entry?.latestVersion, 100);
        if (!version) {
          failures.push({ pluginId, reason: 'account Mini App has no version' });
          continue;
        }
        try {
          const release = await host.request('feature.marketplace.release', { pluginId, version });
          const pointer = await host.request('feature.plugin.install', { release, platform: 'desktop' });
          installedNow.push({ pluginId, version, pointer });
        } catch (error) {
          failures.push({ pluginId, reason: error instanceof Error ? error.message : String(error) });
        }
      }

      for (const pluginId of previousManaged) {
        if (desired.has(pluginId) || !installed.has(pluginId)) continue;
        try {
          await host.request('feature.plugin.uninstall', { pluginId });
          removedNow.push(pluginId);
        } catch (error) {
          failures.push({ pluginId, reason: error instanceof Error ? error.message : String(error) });
        }
      }

      await mutateNativeState((current) => ({
        ...current,
        accountManagedMiniApps: [...desired.keys()].sort(),
      }));
      return {
        accountSynchronized: account?.accountSynchronized === true,
        cursor: account?.cursor ?? null,
        desired: [...desired.keys()],
        installed: installedNow,
        removed: removedNow,
        failures,
      };
    },

    getEffectivePlugins() {
"""
replace_once('desktop/electron/native-capability-handlers.cjs', native_marker, native_replacement)

# Native bridge contract coverage for the newly account-scoped routes/reconcile.
test_marker = """test('local tool permission cannot exceed the administrator ceiling', async () => {
"""
test_block = """test('account sync native capabilities reconcile remote Mini Apps and expose Bot history/cloud routes', async () => {
  const calls = [];
  const installed = new Map();
  const host = {
    async request(method, params = {}) {
      calls.push([method, params]);
      if (method === 'platform.request') {
        if (params.path === '/v1/marketplace/added') {
          return { ok: true, data: { accountSynchronized: true, cursor: 'as1:2', apps: [{ id: 'global-dharma', version: '1.0.0' }] } };
        }
        return { ok: true, data: { method: params.method, path: params.path, query: params.query ?? null, body: params.body ?? null } };
      }
      if (method === 'feature.marketplace.browse') {
        return { plugins: [{ pluginId: 'global-dharma', displayName: 'Global Dharma', latestVersion: '1.0.0' }] };
      }
      if (method === 'feature.plugin.active') return installed.get(params.pluginId) ?? null;
      if (method === 'feature.marketplace.release') return { pluginId: params.pluginId, version: params.version, releaseManifest: { pluginId: params.pluginId, version: params.version } };
      if (method === 'feature.plugin.install') {
        const pointer = { pluginId: params.release.pluginId, version: params.release.version, installedPath: '/tmp/test' };
        installed.set(pointer.pluginId, pointer);
        return pointer;
      }
      if (method === 'feature.plugin.uninstall') {
        installed.delete(params.pluginId);
        return { pluginId: params.pluginId, removed: true };
      }
      throw new Error(`unexpected Host method ${method}`);
    },
  };
  await harness(async ({ handlers, getState }) => {
    const sync = await handlers.getAccountSync({ cursor: 'as1:1', limit: 20 });
    assert.equal(sync.path, '/v1/account/sync');
    assert.equal(sync.query.cursor, 'as1:1');
    const reconciliation = await handlers.reconcileAccountMiniApps({});
    assert.deepEqual(reconciliation.desired, ['global-dharma']);
    assert.equal(reconciliation.installed[0].pluginId, 'global-dharma');
    assert.deepEqual(getState().accountManagedMiniApps, ['global-dharma']);
    const history = await handlers.getMiniAppBotMessages({ pluginId: 'global-dharma', after: '2026-01-01', limit: 50 });
    assert.equal(history.path, '/api/miniapps/global-dharma/messages');
    const appended = await handlers.appendMiniAppBotMessages({ pluginId: 'global-dharma', messages: [{ messageId: 'm1', role: 'user', text: 'hello' }] });
    assert.equal(appended.path, '/api/miniapps/global-dharma/messages');
    const cloud = await handlers.setMiniAppCloudStorage({ pluginId: 'global-dharma', values: { mode: 'local' } });
    assert.equal(cloud.path, '/v1/miniapps/global-dharma/cloud-storage');
    const bots = await handlers.getAccountBots({});
    assert.equal(bots.path, '/v1/account/bots');
  }, { host });
  assert.ok(calls.some(([method]) => method === 'feature.plugin.install'));
});

test('local tool permission cannot exceed the administrator ceiling', async () => {
"""
replace_once('desktop/electron/native-capability-handlers.test.cjs', test_marker, test_block)

print('Applied TFI multi-device account synchronization backend/native integration.')
