import fs from 'node:fs';

function replaceOnce(source, needle, replacement, label) {
  const first = source.indexOf(needle);
  if (first < 0) throw new Error(`missing marker: ${label}`);
  if (source.indexOf(needle, first + needle.length) >= 0) throw new Error(`duplicate marker: ${label}`);
  return `${source.slice(0, first)}${replacement}${source.slice(first + needle.length)}`;
}

function edit(path, transform) {
  const before = fs.readFileSync(path, 'utf8');
  const after = transform(before);
  if (after === before) throw new Error(`no changes produced for ${path}`);
  fs.writeFileSync(path, after);
}

edit('desktop/src/messaging-shell-v2.tsx', (initial) => {
  let source = initial;

  source = replaceOnce(
    source,
    "import { isTerminalAuthSessionFailure } from './auth-session';",
    "import { isTerminalAuthSessionFailure } from './auth-session';\nimport {\n  installedMiniAppBotProjections,\n  miniAppBotResponseText,\n  type MiniAppBotCommand,\n} from './miniapp-bot-projection';",
    'miniapp projection import',
  );

  source = replaceOnce(
    source,
    "  updatedAtMs: number;\n  avatar?: string;\n};",
    "  updatedAtMs: number;\n  avatar?: string;\n  miniAppId?: string;\n  miniAppCommands?: MiniAppBotCommand[];\n  miniAppMenuButtonText?: string;\n};",
    'PeerItem Mini App fields',
  );

  source = replaceOnce(
    source,
    "  if (section === 'contacts') return peer.source === 'legacy' && peer.kind === 'conversation' && peer.id.startsWith('mahayana:contact:');",
    "  if (section === 'contacts') return Boolean(peer.miniAppId) || (peer.source === 'legacy' && peer.kind === 'conversation' && peer.id.startsWith('mahayana:contact:'));",
    'contacts predicate',
  );

  source = replaceOnce(
    source,
    "  const [miniApp, setMiniApp] = useState<{ id: string; title: string; html: string } | null>(null);\n  const [marketplaceApps, setMarketplaceApps] = useState<MarketplacePluginSummary[]>([]);\n  const [installedMiniApps, setInstalledMiniApps] = useState<Record<string, InstalledPluginPointer>>({});",
    "  const [miniApp, setMiniApp] = useState<{ id: string; title: string; html: string } | null>(null);\n  const miniAppBotThreadsRef = useRef<Record<string, DisplayMessage[]>>({});\n  const [marketplaceApps, setMarketplaceApps] = useState<MarketplacePluginSummary[]>([]);\n  const [miniAppIdentityCatalog, setMiniAppIdentityCatalog] = useState<MarketplacePluginSummary[]>([]);\n  const [installedMiniApps, setInstalledMiniApps] = useState<Record<string, InstalledPluginPointer>>({});",
    'Mini App identity state',
  );

  source = replaceOnce(
    source,
    "          const title = marketplaceApps.find((app) => app.pluginId === event.miniAppId)?.displayName ?? event.miniAppId;",
    "          const title = miniAppIdentityCatalog.find((app) => app.pluginId === event.miniAppId)?.displayName ?? marketplaceApps.find((app) => app.pluginId === event.miniAppId)?.displayName ?? event.miniAppId;",
    'miniapp opened title',
  );

  source = replaceOnce(
    source,
    "    const conversationIds = new Set(conversations.map((conversation) => conversation.id));",
    "    const miniAppBotProjections = installedMiniAppBotProjections(miniAppIdentityCatalog, installedMiniApps);\n    const miniAppByBotId = new Map(miniAppBotProjections.map((projection) => [projection.id, projection]));\n    const conversationIds = new Set(conversations.map((conversation) => conversation.id));",
    'installed Mini App bot projections',
  );

  source = replaceOnce(
    source,
    "        updatedAtMs: 0,\n        avatar: bot.avatar,\n      }));\n    const legacyGroups = groups.map((group): PeerItem => ({",
    "        updatedAtMs: 0,\n        avatar: bot.avatar,\n        miniAppId: miniAppByBotId.get(bot.id)?.miniAppId,\n        miniAppCommands: miniAppByBotId.get(bot.id)?.commands,\n        miniAppMenuButtonText: miniAppByBotId.get(bot.id)?.menuButtonText,\n      }));\n    const existingBotIds = new Set(botPeers.map((peer) => peer.actorId ?? peer.id));\n    const miniAppBotPeers = miniAppBotProjections\n      .filter((projection) => !existingBotIds.has(projection.id))\n      .map((projection): PeerItem => ({\n        key: `miniapp:bot:${projection.miniAppId}`,\n        id: projection.id,\n        source: 'legacy',\n        actorId: projection.id,\n        conversationId: projection.conversationId,\n        kind: 'bot',\n        title: projection.displayName,\n        subtitle: projection.username ? `@${projection.username} · ${projection.description}` : projection.description,\n        unread: 0,\n        pinned: pinnedPeerKeys.has(`miniapp:bot:${projection.miniAppId}`),\n        archived: archivedPeerKeys.has(`miniapp:bot:${projection.miniAppId}`),\n        updatedAtMs: 0,\n        miniAppId: projection.miniAppId,\n        miniAppCommands: projection.commands,\n        miniAppMenuButtonText: projection.menuButtonText,\n      }));\n    const legacyGroups = groups.map((group): PeerItem => ({",
    'Mini App bot peer projection',
  );

  source = replaceOnce(
    source,
    "    return [...legacyConversations, ...botPeers, ...legacyGroups, ...nativePeers].sort((left, right) => {",
    "    return [...legacyConversations, ...botPeers, ...miniAppBotPeers, ...legacyGroups, ...nativePeers].sort((left, right) => {",
    'Mini App peers in canonical list',
  );

  source = replaceOnce(
    source,
    "  }, [conversations, bots, groups, selfConversations, pinnedPeerKeys, archivedPeerKeys]);",
    "  }, [conversations, bots, groups, selfConversations, pinnedPeerKeys, archivedPeerKeys, miniAppIdentityCatalog, installedMiniApps]);",
    'peer projection dependencies',
  );

  source = replaceOnce(
    source,
    "    if (peer.source === 'selfhosted' && peer.conversationId) {",
    "    if (peer.miniAppId) {\n      setMessages(miniAppBotThreadsRef.current[peer.miniAppId] ?? []);\n      return;\n    }\n    if (peer.source === 'selfhosted' && peer.conversationId) {",
    'open Mini App bot conversation',
  );

  source = replaceOnce(
    source,
    "    try {\n      if (activePeer.source === 'selfhosted' && activePeer.conversationId) {",
    "    try {\n      if (activePeer.miniAppId) {\n        const createdAtMs = Date.now();\n        const userMessage: DisplayMessage = {\n          id: nextRequestId('miniapp-bot-user'),\n          source: 'legacy',\n          role: 'me',\n          text,\n          createdAtMs,\n        };\n        const pendingThread = [...(miniAppBotThreadsRef.current[activePeer.miniAppId] ?? []), userMessage];\n        miniAppBotThreadsRef.current = { ...miniAppBotThreadsRef.current, [activePeer.miniAppId]: pendingThread };\n        setMessages(pendingThread);\n        const routed = await invokeNativeDesktop<Record<string, unknown>>('routeMiniAppInput', {\n          pluginId: activePeer.miniAppId,\n          input: text,\n        });\n        const responseMessage: DisplayMessage = {\n          id: nextRequestId('miniapp-bot-response'),\n          source: 'legacy',\n          role: 'peer',\n          text: miniAppBotResponseText(routed),\n          createdAtMs: Date.now(),\n        };\n        const completedThread = [...pendingThread, responseMessage];\n        miniAppBotThreadsRef.current = { ...miniAppBotThreadsRef.current, [activePeer.miniAppId]: completedThread };\n        setMessages(completedThread);\n      } else if (activePeer.source === 'selfhosted' && activePeer.conversationId) {",
    'Mini App bot send route',
  );

  source = replaceOnce(
    source,
    "      const [catalogResult, installedResult] = await Promise.allSettled([\n        transport.marketplaceBrowse(query),\n        transport.pluginListInstalled(),\n      ]);",
    "      const catalogPromise = transport.marketplaceBrowse(query);\n      const identityCatalogPromise = query.trim() ? transport.marketplaceBrowse('') : catalogPromise;\n      const [catalogResult, identityCatalogResult, installedResult] = await Promise.allSettled([\n        catalogPromise,\n        identityCatalogPromise,\n        transport.pluginListInstalled(),\n      ]);",
    'Mini App refresh promises',
  );

  source = replaceOnce(
    source,
    "      if (installedResult.status === 'fulfilled') {",
    "      if (identityCatalogResult.status === 'fulfilled') {\n        setMiniAppIdentityCatalog(identityCatalogResult.value.plugins);\n      } else {\n        setError(identityCatalogResult.reason instanceof Error ? identityCatalogResult.reason.message : String(identityCatalogResult.reason));\n      }\n      if (installedResult.status === 'fulfilled') {",
    'Mini App identity catalog result',
  );

  source = replaceOnce(
    source,
    "      await transport.pluginInstall(release.releaseManifest, 'desktop');\n      await refreshMiniApps(miniAppQuery);",
    "      await transport.pluginInstall(release.releaseManifest, 'desktop');\n      try {\n        await invokeNativeDesktop('addMiniAppToAccount', { pluginId: app.pluginId });\n      } catch (cause) {\n        await transport.pluginUninstall(app.pluginId).catch(() => undefined);\n        throw cause;\n      }\n      await refreshMiniApps(miniAppQuery);",
    'Mini App install account lifecycle',
  );

  source = replaceOnce(
    source,
    "      await transport.pluginUninstall(id);\n      if (miniApp?.id === id) setMiniApp(null);",
    "      await transport.pluginUninstall(id);\n      await invokeNativeDesktop('removeMiniAppFromAccount', { pluginId: id });\n      delete miniAppBotThreadsRef.current[id];\n      if (miniApp?.id === id) setMiniApp(null);",
    'Mini App uninstall account lifecycle',
  );

  source = replaceOnce(
    source,
    "      const title = marketplaceApps.find((app) => app.pluginId === id)?.displayName ?? id;",
    "      const title = miniAppIdentityCatalog.find((app) => app.pluginId === id)?.displayName ?? marketplaceApps.find((app) => app.pluginId === id)?.displayName ?? id;",
    'open Mini App title',
  );

  source = replaceOnce(
    source,
    "              <div className={styles.headerActions}>\n                <button type=\"button\" title=\"语音通话\" onClick={() => void startCall('voice')}><PhoneCall size={18} /></button>",
    "              <div className={styles.headerActions}>\n                {activePeer.miniAppId ? <button type=\"button\" data-testid=\"miniapp-bot-open\" title={activePeer.miniAppMenuButtonText ?? '打开小程序'} onClick={() => void openMiniApp(activePeer.miniAppId!)}><AppWindow size={18} /></button> : null}\n                <button type=\"button\" title=\"语音通话\" onClick={() => void startCall('voice')}><PhoneCall size={18} /></button>",
    'Mini App bot menu button',
  );

  source = replaceOnce(
    source,
    "            {scheduledAtMs ? <div className={extra.composerBanner}><span>⏱</span><div><strong>定时发送</strong><span>{new Date(scheduledAtMs).toLocaleString()}</span></div><button type=\"button\" onClick={() => setScheduledAtMs(undefined)}><X size={14} /></button></div> : null}\n            <form className={styles.composer} onSubmit={(event) => void sendMessage(event)}>",
    "            {scheduledAtMs ? <div className={extra.composerBanner}><span>⏱</span><div><strong>定时发送</strong><span>{new Date(scheduledAtMs).toLocaleString()}</span></div><button type=\"button\" onClick={() => setScheduledAtMs(undefined)}><X size={14} /></button></div> : null}\n            {activePeer.miniAppId && composer.trimStart().startsWith('/') && activePeer.miniAppCommands?.length ? <div className={extra.composerBanner} data-testid=\"miniapp-bot-commands\"><AppWindow size={15} /><div><strong>小程序命令</strong><span>{activePeer.miniAppCommands.map((command) => `/${command.name}`).join(' · ')}</span></div>{activePeer.miniAppCommands.slice(0, 4).map((command) => <button key={command.name} type=\"button\" title={command.description} onClick={() => updateComposer(command.usage)}>{`/${command.name}`}</button>)}</div> : null}\n            <form className={styles.composer} onSubmit={(event) => void sendMessage(event)}>",
    'Mini App slash command picker',
  );

  return source;
});

edit('desktop/electron/native-capability-handlers.cjs', (initial) => replaceOnce(
  initial,
  "    getEffectivePlugins() {\n      return installedPluginPointers();\n    },",
  "    async addMiniAppToAccount(params) {\n      const pluginId = cleanString(params.pluginId ?? params.id, 200);\n      if (!pluginId) throw new Error('Mini App id is required.');\n      return platformRequest('POST', `/v1/marketplace/plugins/${encodeURIComponent(pluginId)}/add`, {\n        body: { platform: 'desktop' },\n      });\n    },\n\n    async removeMiniAppFromAccount(params) {\n      const pluginId = cleanString(params.pluginId ?? params.id, 200);\n      if (!pluginId) throw new Error('Mini App id is required.');\n      return platformRequest('DELETE', `/v1/marketplace/plugins/${encodeURIComponent(pluginId)}/add`);\n    },\n\n    async routeMiniAppInput(params) {\n      const pluginId = cleanString(params.pluginId ?? params.id, 200);\n      const input = cleanString(params.input ?? params.message, 10_000);\n      if (!pluginId) throw new Error('Mini App id is required.');\n      if (!input) throw new Error('Mini App Bot input is required.');\n      return platformRequest('POST', `/v1/marketplace/plugins/${encodeURIComponent(pluginId)}/route`, {\n        body: { input },\n      });\n    },\n\n    getEffectivePlugins() {\n      return installedPluginPointers();\n    },",
  'native Mini App bot lifecycle handlers',
));

edit('desktop/electron/native-capability-handlers.test.cjs', (initial) => replaceOnce(
  initial,
  "test('local tool permission cannot exceed the administrator ceiling', async () => {",
  "test('Mini App bot lifecycle uses authenticated marketplace platform routes', async () => {\n  const calls = [];\n  const host = {\n    async request(method, params = {}) {\n      calls.push([method, params]);\n      if (method !== 'platform.request') throw new Error(`unexpected Host method ${method}`);\n      return { ok: true, data: { method: params.method, path: params.path, body: params.body ?? null } };\n    },\n  };\n  await harness(async ({ handlers }) => {\n    const added = await handlers.addMiniAppToAccount({ pluginId: 'global-dharma' });\n    assert.equal(added.path, '/v1/marketplace/plugins/global-dharma/add');\n    const routed = await handlers.routeMiniAppInput({ pluginId: 'global-dharma', input: '/global-dharma:open' });\n    assert.equal(routed.path, '/v1/marketplace/plugins/global-dharma/route');\n    assert.equal(routed.body.input, '/global-dharma:open');\n    const removed = await handlers.removeMiniAppFromAccount({ pluginId: 'global-dharma' });\n    assert.equal(removed.path, '/v1/marketplace/plugins/global-dharma/add');\n  }, { host });\n  assert.deepEqual(calls.map(([, params]) => params.method), ['POST', 'POST', 'DELETE']);\n  assert.ok(calls.every(([method]) => method === 'platform.request'));\n});\n\ntest('local tool permission cannot exceed the administrator ceiling', async () => {",
  'native Mini App lifecycle test',
));

console.log('TFI OpenMaus/Mini App deterministic transform applied successfully.');
