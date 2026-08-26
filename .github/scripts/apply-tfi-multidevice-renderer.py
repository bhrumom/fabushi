#!/usr/bin/env python3
from pathlib import Path
import re

PATH = Path('desktop/src/messaging-shell-v2.tsx')
text = PATH.read_text(encoding='utf-8')


def replace_once(old: str, new: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'expected one renderer marker, found {count}: {old[:140]!r}')
    text = text.replace(old, new, 1)


def regex_once(pattern: str, replacement: str, flags=0) -> None:
    global text
    text, count = re.subn(pattern, replacement, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f'expected one renderer regex marker, found {count}: {pattern[:140]!r}')


replace_once(
    """import {
  installedMiniAppBotProjections,
  miniAppBotResponseText,
  type MiniAppBotCommand,
} from './miniapp-bot-projection';
""",
    """import {
  installedMiniAppBotProjections,
  miniAppBotResponseText,
  type MiniAppBotCommand,
} from './miniapp-bot-projection';
import {
  appendMiniAppBotMessages,
  readAccountBots,
  readAccountSync,
  readMiniAppBotMessages,
  readMiniAppCloudStorage,
  reconcileAccountMiniApps,
  writeMiniAppCloudStorage,
  deleteMiniAppCloudStorage,
  type AccountBotMembership,
} from './account-sync-client';
""",
)

# Durable account cursor lives beside the existing Messaging v2 projection.
replace_once(
    "const messengerProjectionKey = 'fabushi.desktop.messenger-projection.v2';\n",
    "const messengerProjectionKey = 'fabushi.desktop.messenger-projection.v2';\nconst accountSyncCursorKey = 'fabushi.desktop.account-sync-cursor.v1';\n",
)

replace_once(
    """async function clearAccountScopedDesktopCaches(): Promise<void> {
""",
    """function readAccountSyncCursor(): string | null {
  if (typeof window === 'undefined') return null;
  try {
    const value = window.localStorage.getItem(accountSyncCursorKey)?.trim();
    return value || null;
  } catch {
    return null;
  }
}

function persistAccountSyncCursor(cursor: string | null): void {
  if (typeof window === 'undefined') return;
  try {
    if (cursor) window.localStorage.setItem(accountSyncCursorKey, cursor);
    else window.localStorage.removeItem(accountSyncCursorKey);
  } catch {
    // Native persistence remains a best-effort durability mirror.
  }
  if (cursor) {
    void invokeNativeDesktop<boolean>('writeClientPersistence', {
      key: accountSyncCursorKey,
      value: { cursor, updatedAtMs: Date.now() },
    }).catch(() => {});
  } else {
    void invokeNativeDesktop<boolean>('removeClientPersistence', { key: accountSyncCursorKey }).catch(() => {});
  }
}

async function clearAccountScopedDesktopCaches(): Promise<void> {
""",
)

replace_once(
    """  try {
    await invokeNativeDesktop<boolean>('removeClientPersistence', { key: messengerProjectionKey });
  } catch {
    // Older/unavailable native edges must not block signing out locally.
  }
}
""",
    """  try {
    await Promise.all([
      invokeNativeDesktop<boolean>('removeClientPersistence', { key: messengerProjectionKey }),
      invokeNativeDesktop<boolean>('removeClientPersistence', { key: accountSyncCursorKey }),
    ]);
  } catch {
    // Older/unavailable native edges must not block signing out locally.
  }
  try { window.localStorage.removeItem(accountSyncCursorKey); } catch {}
}
""",
)

replace_once(
    """  const miniAppBotThreadsRef = useRef<Record<string, DisplayMessage[]>>({});
  const [marketplaceApps, setMarketplaceApps] = useState<MarketplacePluginSummary[]>([]);
""",
    """  const miniAppBotThreadsRef = useRef<Record<string, DisplayMessage[]>>({});
  const [accountBots, setAccountBots] = useState<AccountBotMembership[]>([]);
  const [marketplaceApps, setMarketplaceApps] = useState<MarketplacePluginSummary[]>([]);
""",
)

replace_once(
    """  const messagingCursorRef = useRef<string | null>(startupProjection?.cursor ?? null);
  const syncInFlightRef = useRef(false);
""",
    """  const messagingCursorRef = useRef<string | null>(startupProjection?.cursor ?? null);
  const accountSyncCursorRef = useRef<string | null>(readAccountSyncCursor());
  const syncInFlightRef = useRef(false);
  const accountSyncInFlightRef = useRef(false);
""",
)

# Standard Messaging v2 remains authoritative for normal chat history; run the
# account-domain catch-up immediately after the same account actor is ready.
replace_once(
    """          await selfHosted.ensureCurrentActor(displayName, username);
          await selfHosted.sync(initialSyncLimit, messagingCursorRef.current);
          void webRtcRef.current?.connect().catch(() => {});
""",
    """          await selfHosted.ensureCurrentActor(displayName, username);
          await selfHosted.sync(initialSyncLimit, messagingCursorRef.current);
          await synchronizeAccountState();
          void webRtcRef.current?.connect().catch(() => {});
""",
)

# Account-domain cursor advances on the same foreground/background cadence as
# Messaging v2, while each domain retains independent checkpoints.
replace_once(
    """      if (syncInFlightRef.current) return;
      syncInFlightRef.current = true;
""",
    """      void synchronizeAccountState();
      if (syncInFlightRef.current) return;
      syncInFlightRef.current = true;
""",
)

# Merge stable account Bot memberships into the canonical peer model. A Mini App
# source can appear before local package restoration completes on a new device.
replace_once(
    """    const existingBotIds = new Set(botPeers.map((peer) => peer.actorId ?? peer.id));
    const miniAppBotPeers = miniAppBotProjections
""",
    """    const existingBotIds = new Set(botPeers.map((peer) => peer.actorId ?? peer.id));
    const accountBotPeers = accountBots
      .filter((entry) => entry?.bot?.id && !existingBotIds.has(entry.bot.id))
      .map((entry): PeerItem => {
        const miniAppSource = entry.sources.find((source) => source.source === 'miniapp');
        const projection = miniAppSource
          ? miniAppBotProjections.find((candidate) => candidate.miniAppId === miniAppSource.sourceId)
          : miniAppByBotId.get(entry.bot.id);
        return {
          key: `account:bot:${entry.bot.id}`,
          id: entry.bot.id,
          source: 'legacy',
          kind: 'bot',
          title: entry.bot.displayName ?? entry.bot.username ?? entry.bot.id,
          subtitle: entry.bot.username ? `@${entry.bot.username}` : entry.bot.description ?? 'Bot',
          actorId: entry.bot.id,
          conversationId: entry.bot.conversationId,
          unread: 0,
          pinned: pinnedPeerKeys.has(`account:bot:${entry.bot.id}`),
          archived: archivedPeerKeys.has(`account:bot:${entry.bot.id}`),
          updatedAtMs: entry.updatedAtMs ?? 0,
          miniAppId: miniAppSource?.sourceId,
          miniAppCommands: projection?.commands,
          miniAppMenuButtonText: projection?.menuButtonText ?? (miniAppSource ? '打开小程序' : undefined),
        };
      });
    for (const peer of accountBotPeers) existingBotIds.add(peer.actorId ?? peer.id);
    const miniAppBotPeers = miniAppBotProjections
""",
)
replace_once(
    """    return [...legacyConversations, ...botPeers, ...miniAppBotPeers, ...legacyGroups, ...nativePeers].sort((left, right) => {
""",
    """    return [...legacyConversations, ...botPeers, ...accountBotPeers, ...miniAppBotPeers, ...legacyGroups, ...nativePeers].sort((left, right) => {
""",
)
replace_once(
    """  }, [conversations, bots, groups, selfConversations, pinnedPeerKeys, archivedPeerKeys, miniAppIdentityCatalog, installedMiniApps]);
""",
    """  }, [conversations, bots, accountBots, groups, selfConversations, pinnedPeerKeys, archivedPeerKeys, miniAppIdentityCatalog, installedMiniApps]);
""",
)

# Central Mini App Bot history + account-domain difference coordinator.
replace_once(
    """  async function refreshMiniApps(query = miniAppQuery) {
""",
    """  async function loadMiniAppBotThread(miniAppId: string): Promise<DisplayMessage[]> {
    const page = await readMiniAppBotMessages(miniAppId, '', 500);
    const thread = (page.messages ?? []).map((message): DisplayMessage => ({
      id: message.messageId,
      role: message.role === 'user' ? 'me' : 'peer',
      text: message.text,
      createdAtMs: Number.isFinite(Date.parse(message.createdAt)) ? Date.parse(message.createdAt) : Date.now(),
      source: 'legacy',
    }));
    miniAppBotThreadsRef.current = { ...miniAppBotThreadsRef.current, [miniAppId]: thread };
    const active = peersRef.current.find((peer) => peer.key === activePeerKeyRef.current);
    if (active?.miniAppId === miniAppId) setMessages(thread);
    return thread;
  }

  async function synchronizeAccountState(): Promise<void> {
    if (accountSyncInFlightRef.current) return;
    accountSyncInFlightRef.current = true;
    try {
      let cursor = accountSyncCursorRef.current;
      let reconcileApps = false;
      let refreshBots = false;
      const changedMiniAppThreads = new Set<string>();
      for (let pageIndex = 0; pageIndex < 16; pageIndex += 1) {
        const envelope = await readAccountSync(cursor, 200);
        cursor = envelope.cursor;
        if (envelope.mode === 'snapshot') {
          reconcileApps = true;
          refreshBots = true;
        }
        for (const event of envelope.events ?? []) {
          if (event.type.startsWith('miniapp.') && !event.type.startsWith('miniapp.bot.message') && !event.type.startsWith('miniapp.content.')) {
            reconcileApps = true;
          }
          if (event.type === 'bot.added' || event.type === 'bot.updated' || event.type === 'bot.removed') refreshBots = true;
          if (event.type === 'miniapp.bot.message') {
            const miniAppId = typeof event.payload?.miniAppId === 'string' ? event.payload.miniAppId : '';
            if (miniAppId) changedMiniAppThreads.add(miniAppId);
          }
        }
        if (!envelope.hasMore) break;
      }
      accountSyncCursorRef.current = cursor;
      persistAccountSyncCursor(cursor);
      if (reconcileApps) {
        await reconcileAccountMiniApps();
        await refreshMiniApps(miniAppQuery, false);
      }
      if (refreshBots || accountBots.length === 0) {
        setAccountBots(await readAccountBots());
      }
      const active = peersRef.current.find((peer) => peer.key === activePeerKeyRef.current);
      if (active?.miniAppId && changedMiniAppThreads.has(active.miniAppId)) {
        await loadMiniAppBotThread(active.miniAppId);
      }
    } catch {
      // Offline/account bootstrap failures must not block the local Messenger.
      // The next periodic tick will retry from the last durable cursor.
    } finally {
      accountSyncInFlightRef.current = false;
    }
  }

  async function refreshMiniApps(query = miniAppQuery, reconcileAccount = true) {
""",
)
replace_once(
    """    setMiniAppLoading(true);
    try {
      const catalogPromise = transport.marketplaceBrowse(query);
""",
    """    setMiniAppLoading(true);
    try {
      if (reconcileAccount) await reconcileAccountMiniApps().catch(() => undefined);
      const catalogPromise = transport.marketplaceBrowse(query);
""",
)

# Opening a Mini App Bot shows local cache instantly and replaces it with the
# account-authoritative timeline as soon as the network read completes.
replace_once(
    """      setMessages(miniAppBotThreadsRef.current[peer.miniAppId] ?? []);
      return;
""",
    """      setMessages(miniAppBotThreadsRef.current[peer.miniAppId] ?? []);
      void loadMiniAppBotThread(peer.miniAppId).catch(() => {});
      return;
""",
)

# Persist both sides of a Mini App Bot exchange centrally; the React ref is only
# an optimistic cache, not the source of truth anymore.
replace_once(
    """        const pendingThread = [...(miniAppBotThreadsRef.current[activePeer.miniAppId] ?? []), userMessage];
        miniAppBotThreadsRef.current = { ...miniAppBotThreadsRef.current, [activePeer.miniAppId]: pendingThread };
        setMessages(pendingThread);
        const routed = await invokeNativeDesktop<Record<string, unknown>>('routeMiniAppInput', {
          pluginId: activePeer.miniAppId,
          input: text,
        });
""",
    """        const pendingThread = [...(miniAppBotThreadsRef.current[activePeer.miniAppId] ?? []), userMessage];
        miniAppBotThreadsRef.current = { ...miniAppBotThreadsRef.current, [activePeer.miniAppId]: pendingThread };
        setMessages(pendingThread);
        await appendMiniAppBotMessages(activePeer.miniAppId, [{
          messageId: userMessage.id,
          role: 'user',
          text: userMessage.text,
          createdAt: new Date(userMessage.createdAtMs).toISOString(),
        }]);
        const routed = await invokeNativeDesktop<Record<string, unknown>>('routeMiniAppInput', {
          pluginId: activePeer.miniAppId,
          input: text,
        });
""",
)
replace_once(
    """        const completedThread = [...pendingThread, responseMessage];
        miniAppBotThreadsRef.current = { ...miniAppBotThreadsRef.current, [activePeer.miniAppId]: completedThread };
        setMessages(completedThread);
""",
    """        const completedThread = [...pendingThread, responseMessage];
        miniAppBotThreadsRef.current = { ...miniAppBotThreadsRef.current, [activePeer.miniAppId]: completedThread };
        setMessages(completedThread);
        await appendMiniAppBotMessages(activePeer.miniAppId, [{
          messageId: responseMessage.id,
          role: 'assistant',
          text: responseMessage.text,
          createdAt: new Date(responseMessage.createdAtMs).toISOString(),
        }]);
""",
)

# A device that has the account entitlement but not yet the local package repairs
# the local runtime before declaring the app unavailable.
replace_once(
    """      const installed = installedMiniApps[id] ?? await transport.pluginActive(id);
      if (!installed) throw new Error('请先从在线 Mini App 市场安装此应用');
""",
    """      let installed = installedMiniApps[id] ?? await transport.pluginActive(id);
      if (!installed) {
        await reconcileAccountMiniApps().catch(() => undefined);
        installed = await transport.pluginActive(id);
      }
      if (!installed) throw new Error('请先从在线 Mini App 市场安装此应用');
""",
)

# Mini App CloudStorage bridge. The iframe never chooses another app id: the
# parent binds every request to app.id, preserving cross-app isolation.
mini_dialog_old = """function MiniAppDialog({ app, onClose }: { app: { id: string; title: string; html: string }; onClose: () => void }) {
  return <div className={styles.backdrop} onMouseDown={onClose}><section className={styles.miniAppDialog} onMouseDown={(event) => event.stopPropagation()}><header><div><strong>{app.title}</strong><small>Mini App · 已安装线上包 · 受控宿主容器</small></div><button type=\"button\" onClick={onClose}><X size={17} /></button></header><iframe title={app.id} sandbox=\"allow-scripts allow-forms\" srcDoc={app.html} /></section></div>;
}
"""
mini_dialog_new = r'''function miniAppCloudBridgeDocument(html: string): string {
  const bootstrap = `<script>(function(){
    const protocol='fabushi.miniapp.storage.v1';
    let sequence=0; const pending=new Map();
    function request(action,payload){return new Promise((resolve,reject)=>{const requestId='storage-'+Date.now()+'-'+(++sequence);pending.set(requestId,{resolve,reject});window.parent.postMessage({protocol,requestId,action,...(payload||{})},'*');});}
    window.addEventListener('message',(event)=>{const data=event.data||{};if(data.protocol!==protocol||!data.requestId||!pending.has(data.requestId))return;const task=pending.get(data.requestId);pending.delete(data.requestId);if(data.ok)task.resolve(data.data);else task.reject(new Error(data.error||'CloudStorage request failed'));});
    const api={
      getItem:async(key,callback)=>{const data=await request('get',{key});const value=data&&data.item?String(data.item.value??''):'';if(typeof callback==='function')callback(null,value);return value;},
      setItem:async(key,value,callback)=>{await request('set',{values:{[key]:String(value)}});if(typeof callback==='function')callback(null,true);return true;},
      getItems:async(keys,callback)=>{const data=await request('list');const wanted=new Set(Array.isArray(keys)?keys:[]);const values=Object.fromEntries((data.items||[]).filter(item=>wanted.size===0||wanted.has(item.key)).map(item=>[item.key,item.value]));if(typeof callback==='function')callback(null,values);return values;},
      setItems:async(values,callback)=>{await request('set',{values:values||{}});if(typeof callback==='function')callback(null,true);return true;},
      removeItem:async(key,callback)=>{await request('delete',{key});if(typeof callback==='function')callback(null,true);return true;},
      getKeys:async(callback)=>{const data=await request('list');const keys=(data.items||[]).map(item=>item.key);if(typeof callback==='function')callback(null,keys);return keys;}
    };
    window.FabushiMiniApp=Object.assign({},window.FabushiMiniApp||{},{CloudStorage:api});
  })();</script>`;
  return html.includes('</head>') ? html.replace('</head>', `${bootstrap}</head>`) : `${bootstrap}${html}`;
}

function MiniAppDialog({ app, onClose }: { app: { id: string; title: string; html: string }; onClose: () => void }) {
  const frameRef = useRef<HTMLIFrameElement>(null);
  useEffect(() => {
    const onMessage = (event: MessageEvent) => {
      if (event.source !== frameRef.current?.contentWindow) return;
      const data = event.data as { protocol?: string; requestId?: string; action?: string; key?: string; values?: Record<string, string> } | null;
      if (!data || data.protocol !== 'fabushi.miniapp.storage.v1' || !data.requestId) return;
      const respond = (ok: boolean, payload: unknown) => frameRef.current?.contentWindow?.postMessage({
        protocol: 'fabushi.miniapp.storage.v1', requestId: data.requestId, ok,
        ...(ok ? { data: payload } : { error: payload instanceof Error ? payload.message : String(payload) }),
      }, '*');
      void (async () => {
        try {
          if (data.action === 'get') respond(true, await readMiniAppCloudStorage(app.id, data.key));
          else if (data.action === 'list') respond(true, await readMiniAppCloudStorage(app.id));
          else if (data.action === 'set') respond(true, await writeMiniAppCloudStorage(app.id, data.values ?? {}));
          else if (data.action === 'delete' && data.key) respond(true, await deleteMiniAppCloudStorage(app.id, data.key));
          else throw new Error('Unsupported Mini App CloudStorage operation');
        } catch (cause) { respond(false, cause); }
      })();
    };
    window.addEventListener('message', onMessage);
    return () => window.removeEventListener('message', onMessage);
  }, [app.id]);
  return <div className={styles.backdrop} onMouseDown={onClose}><section className={styles.miniAppDialog} onMouseDown={(event) => event.stopPropagation()}><header><div><strong>{app.title}</strong><small>Mini App · 已安装线上包 · 账号云同步</small></div><button type="button" onClick={onClose}><X size={17} /></button></header><iframe ref={frameRef} title={app.id} sandbox="allow-scripts allow-forms" srcDoc={miniAppCloudBridgeDocument(app.html)} /></section></div>;
}
'''
replace_once(mini_dialog_old, mini_dialog_new)

PATH.write_text(text, encoding='utf-8')
print('Applied desktop account sync coordinator, Mini App Bot history, and CloudStorage bridge.')
