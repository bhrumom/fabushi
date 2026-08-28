import fs from 'node:fs';

const path = new URL('../src/messaging-shell-v2.tsx', import.meta.url);
let source = fs.readFileSync(path, 'utf8');

function replaceOnce(label, before, after) {
  const first = source.indexOf(before);
  if (first < 0) throw new Error(`GBF-508 patch anchor missing: ${label}`);
  if (source.indexOf(before, first + before.length) >= 0) throw new Error(`GBF-508 patch anchor is not unique: ${label}`);
  source = source.slice(0, first) + after + source.slice(first + before.length);
}

replaceOnce(
  'contact-group import',
  "} from './account-sync-client';\n",
  "} from './account-sync-client';\nimport {\n  SidebarContactGroupManager,\n  projectSidebarContactGroups,\n  useSidebarContactGroups,\n} from './sidebar-contact-groups';\n",
);

replaceOnce(
  'contact-group controller state',
  "  const [archivedPeerKeys, setArchivedPeerKeys] = useState<Set<string>>(() => new Set());\n",
  "  const [archivedPeerKeys, setArchivedPeerKeys] = useState<Set<string>>(() => new Set());\n  const contactGroups = useSidebarContactGroups();\n",
);

replaceOnce(
  'rendered peer projection',
  "  const renderedPeers = visiblePeers.slice(0, peerRenderCount);\n  const matchingMessages = messages;\n  const renderedMessages = matchingMessages.slice(Math.max(0, matchingMessages.length - messageRenderCount));\n",
  `  const renderedPeers = visiblePeers.slice(0, peerRenderCount);\n  const renderedContactGroups = ['chats', 'contacts'].includes(section) && contactGroups.groups.length\n    ? projectSidebarContactGroups(renderedPeers, contactGroups.groups, Boolean(search.trim()))\n    : [];\n  const matchingMessages = messages;\n  const renderedMessages = matchingMessages.slice(Math.max(0, matchingMessages.length - messageRenderCount));\n\n  function renderPeerRow(peer: PeerItem) {\n    return <button data-testid={\`peer-\${peer.key}\`} key={peer.key} type=\"button\" className={peer.key === activePeerKey ? styles.peerActive : styles.peer} onClick={() => void openPeer(peer)}>\n      <BotMark\n        botId={\`peer:\${peer.kind}:\${peer.actorId ?? peer.id}\`}\n        state={isAgentPeer(peer) ? botMarkStateForPeer(peer, selfBotExecutions, peer.key === activePeerKey && pendingSend, hostReady) : peer.unread ? 'notifying' : 'idle'}\n        size={48}\n        className={styles.agentAvatarMark}\n        label={peer.title}\n      />\n      <span className={styles.peerCopy}>\n        <span><strong>{peer.title}</strong><time>{formatTime(peer.updatedAtMs)}</time></span>\n        <small>{desktopPreferences.messagePreview ? peer.subtitle : peer.unread ? '有新消息' : '消息预览已关闭'}</small>\n      </span>\n      <span className={styles.peerMeta}>{peer.pinned ? <Pin size={12} /> : null}{mutedPeerKeys.has(peer.key) ? <BellOff size={12} /> : null}{peer.unread ? <b>{peer.unread}</b> : null}</span>\n    </button>;\n  }\n`,
);

replaceOnce(
  'create menu group entry',
  "              <button type=\"button\" onClick={() => { setCreateMenuOpen(false); setNewDialog({ type: 'channel', name: '', description: '' }); }}><Radio size={16} /><span>新建频道</span></button>\n",
  "              <button type=\"button\" onClick={() => { setCreateMenuOpen(false); setNewDialog({ type: 'channel', name: '', description: '' }); }}><Radio size={16} /><span>新建频道</span></button>\n              {['chats', 'contacts'].includes(section) ? <button type=\"button\" data-testid=\"open-contact-groups\" onClick={() => { setCreateMenuOpen(false); contactGroups.openManager(); }}><Folder size={16} /><span>联系人分组</span></button> : null}\n",
);

replaceOnce(
  'flat peer list',
  `            {renderedPeers.map((peer) => (\n              <button data-testid={\`peer-\${peer.key}\`} key={peer.key} type=\"button\" className={peer.key === activePeerKey ? styles.peerActive : styles.peer} onClick={() => void openPeer(peer)}>\n                <BotMark\n                  botId={\`peer:\${peer.kind}:\${peer.actorId ?? peer.id}\`}\n                  state={isAgentPeer(peer) ? botMarkStateForPeer(peer, selfBotExecutions, peer.key === activePeerKey && pendingSend, hostReady) : peer.unread ? 'notifying' : 'idle'}\n                  size={48}\n                  className={styles.agentAvatarMark}\n                  label={peer.title}\n                />\n                <span className={styles.peerCopy}>\n                  <span><strong>{peer.title}</strong><time>{formatTime(peer.updatedAtMs)}</time></span>\n                  <small>{desktopPreferences.messagePreview ? peer.subtitle : peer.unread ? '有新消息' : '消息预览已关闭'}</small>\n                </span>\n                <span className={styles.peerMeta}>{peer.pinned ? <Pin size={12} /> : null}{mutedPeerKeys.has(peer.key) ? <BellOff size={12} /> : null}{peer.unread ? <b>{peer.unread}</b> : null}</span>\n              </button>\n            ))}\n`,
  `            {renderedContactGroups.length ? renderedContactGroups.map((group) => (\n              <section className=\"fabushi-contact-group\" data-testid={\`contact-group-\${group.id}\`} key={group.id}>\n                <button\n                  type=\"button\"\n                  className=\"fabushi-contact-group__header\"\n                  data-collapsed={group.isCollapsed}\n                  data-synthetic={group.isSynthetic}\n                  aria-expanded={!group.isCollapsed}\n                  onClick={() => { if (!group.isSynthetic) contactGroups.toggleCollapsed(group.id); }}\n                >\n                  <span>›</span><strong>{group.name}</strong><em>{group.peers.length}</em>\n                </button>\n                {!group.isCollapsed ? group.peers.map(renderPeerRow) : null}\n              </section>\n            )) : renderedPeers.map(renderPeerRow)}\n`,
);

replaceOnce(
  'manager dialog mount',
  "      {messageMenu ? <MessageContextMenu menu={messageMenu} onAction={(action) => void handleMessageAction(action)} /> : null}\n",
  `      {contactGroups.managerOpen ? <SidebarContactGroupManager\n        peers={peers.filter((peer) => !peer.archived && (peer.kind === 'conversation' || peer.kind === 'bot')).map((peer) => ({ key: peer.key, title: peer.title, subtitle: peer.subtitle, pinned: peer.pinned }))}\n        groups={contactGroups.groups}\n        onCreate={contactGroups.create}\n        onUpdate={contactGroups.update}\n        onRemove={contactGroups.remove}\n        onMove={contactGroups.move}\n        onClose={contactGroups.closeManager}\n      /> : null}\n      {messageMenu ? <MessageContextMenu menu={messageMenu} onAction={(action) => void handleMessageAction(action)} /> : null}\n`,
);

fs.writeFileSync(path, source);
console.log('GBF-508 sidebar contact grouping patch applied');
// This script is intentionally deterministic and fails closed if the canonical renderer anchors move.
