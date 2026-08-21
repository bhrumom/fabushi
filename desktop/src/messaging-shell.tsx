import {
  AppWindow,
  Archive,
  BellOff,
  Bot,
  Bookmark,
  Camera,
  Check,
  ChevronLeft,
  FileText,
  Folder,
  Hash,
  Image,
  Link2,
  Menu,
  MessageCircle,
  Mic,
  MoreVertical,
  Paperclip,
  Phone,
  PhoneCall,
  Pin,
  Plus,
  Radio,
  Search,
  Send,
  Settings,
  ShoppingBag,
  Smile,
  SquarePen,
  UserPlus,
  Users,
  Video,
  WalletCards,
  X,
} from 'lucide-react';
import React, { useEffect, useMemo, useRef, useState, type FormEvent } from 'react';
import HostClient from '../../frontend/apps/web/src/app/host/host-client';
import type {
  BotSummary,
  ConversationSummary,
  GroupSummary,
  RuntimeEvent,
} from '../../frontend/apps/web/src/lib/mahayana-host/contracts';
import { ElectronMahayanaHostTransport, isElectronMahayanaHostAvailable } from '../../frontend/apps/web/src/lib/mahayana-host/electron-transport';
import { MockMahayanaHostTransport } from '../../frontend/apps/web/src/lib/mahayana-host/mock-transport';
import type { MahayanaHostTransport } from '../../frontend/apps/web/src/lib/mahayana-host/transport';
import styles from './messaging-shell.module.css';

type RootSurface = 'ai' | 'messages';
type MessengerSection =
  | 'chats'
  | 'contacts'
  | 'bots'
  | 'groups'
  | 'channels'
  | 'calls'
  | 'saved'
  | 'archive'
  | 'folders'
  | 'miniapps'
  | 'payments'
  | 'settings';

type PeerKind = 'conversation' | 'bot' | 'group' | 'channel' | 'saved';

type PeerItem = {
  key: string;
  id: string;
  conversationId?: string;
  actorId?: string;
  groupId?: string;
  kind: PeerKind;
  title: string;
  subtitle: string;
  unread: number;
  pinned: boolean;
  archived: boolean;
  updatedAtMs: number;
  avatar?: string;
};

type MessengerMessage = {
  id: string;
  role: 'me' | 'peer';
  text: string;
  createdAtMs: number;
};

type InfoTab = 'media' | 'files' | 'links';

type NewDialog =
  | { type: 'group'; name: string; selectedBotIds: Set<string> }
  | { type: 'channel'; name: string; description: string }
  | null;

type LocalCall = {
  kind: 'voice' | 'video';
  title: string;
  status: 'requesting' | 'ready' | 'failed';
  error?: string;
};

const rootSurfaceKey = 'fabushi.desktop.root-surface.v1';
const messengerSettingsKey = 'fabushi.desktop.messenger-settings.v1';
const defaultMiniApps = [
  { id: 'global-dharma', title: '全球法布施', description: '任务、日志与部署' },
  { id: 'faliu-flashcards', title: '法流记忆卡', description: '经文牌组与复习' },
  { id: 'platform-publish', title: '平台发布', description: '内容发布与自动化' },
  { id: 'bot-father', title: 'Bot Father', description: '创建和管理机器人' },
];

function createTransport(): MahayanaHostTransport {
  if (isElectronMahayanaHostAvailable()) return new ElectronMahayanaHostTransport();
  return new MockMahayanaHostTransport({ authenticated: true });
}

function classifyConversation(conversation: ConversationSummary): PeerKind {
  const id = conversation.id.toLowerCase();
  const kind = conversation.kind.toLowerCase();
  if (id.includes('saved') || kind.includes('saved')) return 'saved';
  if (kind.includes('channel')) return 'channel';
  return 'conversation';
}

function avatarText(title: string): string {
  const trimmed = title.trim();
  return trimmed ? Array.from(trimmed)[0] ?? '聊' : '聊';
}

function formatTime(timestamp: number): string {
  if (!timestamp) return '';
  const date = new Date(timestamp);
  const now = new Date();
  if (date.toDateString() === now.toDateString()) {
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }
  return date.toLocaleDateString([], { month: 'numeric', day: 'numeric' });
}

function matchesSection(peer: PeerItem, section: MessengerSection): boolean {
  if (section === 'chats') return !peer.archived;
  if (section === 'contacts') return peer.kind === 'conversation' && peer.id.startsWith('mahayana:contact:');
  if (section === 'bots') return peer.kind === 'bot';
  if (section === 'groups') return peer.kind === 'group';
  if (section === 'channels') return peer.kind === 'channel';
  if (section === 'saved') return peer.kind === 'saved';
  if (section === 'archive') return peer.archived;
  return false;
}

export default function DesktopShell() {
  const [surface, setSurface] = useState<RootSurface>(() => {
    try {
      return window.localStorage.getItem(rootSurfaceKey) === 'messages' ? 'messages' : 'ai';
    } catch {
      return 'ai';
    }
  });

  useEffect(() => {
    try {
      window.localStorage.setItem(rootSurfaceKey, surface);
    } catch {
      // Storage failure must not block the desktop shell.
    }
  }, [surface]);

  return (
    <div className={styles.desktopRoot} data-testid="desktop-shell">
      <nav className={styles.productRail} aria-label="Fabushi 主视图">
        <button type="button" data-active={surface === 'ai'} onClick={() => setSurface('ai')} title="AI 工作区">
          <span className={styles.brandOrb}>法</span>
          <small>AI</small>
        </button>
        <button data-testid="open-messenger" type="button" data-active={surface === 'messages'} onClick={() => setSurface('messages')} title="消息">
          <MessageCircle size={21} />
          <small>消息</small>
        </button>
      </nav>
      <div className={styles.productSurface}>
        {surface === 'ai' ? <HostClient /> : <MessengerWorkspace onOpenAi={() => setSurface('ai')} />}
      </div>
    </div>
  );
}

function MessengerWorkspace({ onOpenAi }: { onOpenAi: () => void }) {
  const transport = useMemo(() => createTransport(), []);
  const [hostReady, setHostReady] = useState(false);
  const [section, setSection] = useState<MessengerSection>('chats');
  const [conversations, setConversations] = useState<ConversationSummary[]>([]);
  const [bots, setBots] = useState<BotSummary[]>([]);
  const [groups, setGroups] = useState<GroupSummary[]>([]);
  const [activePeerKey, setActivePeerKey] = useState<string | null>(null);
  const [messages, setMessages] = useState<MessengerMessage[]>([]);
  const [composer, setComposer] = useState('');
  const [search, setSearch] = useState('');
  const [conversationSearchOpen, setConversationSearchOpen] = useState(false);
  const [infoOpen, setInfoOpen] = useState(true);
  const [infoTab, setInfoTab] = useState<InfoTab>('media');
  const [pendingSend, setPendingSend] = useState(false);
  const [newDialog, setNewDialog] = useState<NewDialog>(null);
  const [localCall, setLocalCall] = useState<LocalCall | null>(null);
  const [miniApp, setMiniApp] = useState<{ id: string; html?: string } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [mutedPeerKeys, setMutedPeerKeys] = useState<Set<string>>(() => new Set());
  const [pinnedPeerKeys, setPinnedPeerKeys] = useState<Set<string>>(() => new Set());
  const [archivedPeerKeys, setArchivedPeerKeys] = useState<Set<string>>(() => new Set());
  const mediaStreamRef = useRef<MediaStream | null>(null);
  const localVideoRef = useRef<HTMLVideoElement>(null);
  const activePeerKeyRef = useRef<string | null>(null);

  useEffect(() => {
    activePeerKeyRef.current = activePeerKey;
  }, [activePeerKey]);

  useEffect(() => {
    try {
      const stored = JSON.parse(window.localStorage.getItem(messengerSettingsKey) || '{}') as {
        muted?: string[];
        pinned?: string[];
        archived?: string[];
      };
      setMutedPeerKeys(new Set(stored.muted || []));
      setPinnedPeerKeys(new Set(stored.pinned || []));
      setArchivedPeerKeys(new Set(stored.archived || []));
    } catch {
      // Ignore malformed previous settings.
    }
  }, []);

  useEffect(() => {
    try {
      window.localStorage.setItem(messengerSettingsKey, JSON.stringify({
        muted: [...mutedPeerKeys],
        pinned: [...pinnedPeerKeys],
        archived: [...archivedPeerKeys],
      }));
    } catch {
      // Persistence is a convenience; runtime messaging remains available.
    }
  }, [mutedPeerKeys, pinnedPeerKeys, archivedPeerKeys]);

  useEffect(() => {
    let closed = false;
    const unsubscribe = transport.subscribe((event) => {
      if (closed) return;
      handleRuntimeEvent(event);
    });
    void transport.initialize({ profileId: 'desktop-messenger', mode: 'production' })
      .then(() => {
        if (closed) return;
        setHostReady(true);
        refreshLists();
      })
      .catch((cause: unknown) => setError(cause instanceof Error ? cause.message : String(cause)));
    return () => {
      closed = true;
      unsubscribe();
      mediaStreamRef.current?.getTracks().forEach((track) => track.stop());
      void transport.close();
    };
  }, [transport]);

  function nextRequestId(prefix: string): string {
    return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  }

  function execute(command: Parameters<MahayanaHostTransport['execute']>[0]) {
    return transport.execute(command).catch((cause: unknown) => {
      setError(cause instanceof Error ? cause.message : String(cause));
      throw cause;
    });
  }

  function refreshLists() {
    void Promise.all([
      execute({ type: 'conversation.list', requestId: nextRequestId('conversation-list') }),
      execute({ type: 'bot.list', requestId: nextRequestId('bot-list') }),
      execute({ type: 'group.list', requestId: nextRequestId('group-list') }),
    ]).catch(() => {});
  }

  function handleRuntimeEvent(event: RuntimeEvent) {
    switch (event.type) {
      case 'host.ready':
        setHostReady(true);
        break;
      case 'conversation.listed':
        setConversations(event.conversations);
        if (!activePeerKeyRef.current && event.conversations[0]) {
          const key = `conversation:${event.conversations[0].id}`;
          setActivePeerKey(key);
          void execute({ type: 'conversation.open', requestId: nextRequestId('conversation-open'), conversationId: event.conversations[0].id });
        }
        break;
      case 'conversation.opened':
        if (activePeerKeyRef.current === `conversation:${event.conversationId}`) {
          setMessages(event.messages.map((message) => ({
            id: message.id,
            role: message.role === 'user' ? 'me' : 'peer',
            text: message.text,
            createdAtMs: message.createdAtMs,
          })));
        }
        break;
      case 'bot.listed':
        setBots(event.bots);
        break;
      case 'bot.changed':
        setBots((current) => event.action === 'deleted'
          ? current.filter((bot) => bot.id !== event.bot.id)
          : [...current.filter((bot) => bot.id !== event.bot.id), event.bot]);
        break;
      case 'group.listed':
        setGroups(event.groups);
        break;
      case 'group.changed':
        setGroups((current) => event.action === 'deleted'
          ? current.filter((group) => group.id !== event.group.id)
          : [...current.filter((group) => group.id !== event.group.id), event.group]);
        if (activePeerKeyRef.current === `group:${event.group.id}`) {
          setMessages(groupMessages(event.group));
        }
        break;
      case 'chat.message':
        setPendingSend(false);
        setMessages((current) => [...current, {
          id: event.operationId || nextRequestId('message'),
          role: event.role === 'user' ? 'me' : 'peer',
          text: event.text,
          createdAtMs: Date.now(),
        }]);
        break;
      case 'chat.delta':
        setPendingSend(false);
        setMessages((current) => {
          const index = current.findIndex((message) => message.id === event.operationId);
          if (index < 0) return [...current, { id: event.operationId, role: 'peer', text: event.delta, createdAtMs: Date.now() }];
          return current.map((message, messageIndex) => messageIndex === index ? { ...message, text: `${message.text}${event.delta}` } : message);
        });
        break;
      case 'miniapp.opened':
        setMiniApp({ id: event.miniAppId, html: event.html });
        break;
      case 'operation.failed':
        setPendingSend(false);
        setError(event.message);
        break;
      case 'host.closed':
        setHostReady(false);
        break;
      default:
        break;
    }
  }

  function groupMessages(group: GroupSummary): MessengerMessage[] {
    return group.messages.map((message) => ({
      id: message.id,
      role: message.speaker.kind === 'user' ? 'me' : 'peer',
      text: message.content,
      createdAtMs: message.createdAtMs,
    }));
  }

  const peers = useMemo<PeerItem[]>(() => {
    const conversationPeers = conversations.map((conversation): PeerItem => ({
      key: `conversation:${conversation.id}`,
      id: conversation.id,
      conversationId: conversation.id,
      kind: classifyConversation(conversation),
      title: conversation.title,
      subtitle: conversation.kind,
      unread: conversation.unreadCount,
      pinned: conversation.pinned || pinnedPeerKeys.has(`conversation:${conversation.id}`),
      archived: archivedPeerKeys.has(`conversation:${conversation.id}`),
      updatedAtMs: conversation.updatedAtMs,
    }));
    const conversationIds = new Set(conversations.map((conversation) => conversation.id));
    const botPeers = bots
      .filter((bot) => !bot.conversationId || !conversationIds.has(bot.conversationId))
      .map((bot): PeerItem => ({
        key: `bot:${bot.id}`,
        id: bot.id,
        actorId: bot.id,
        conversationId: bot.conversationId,
        kind: 'bot',
        title: bot.name,
        subtitle: bot.description || bot.title || 'AI Bot',
        unread: bot.unread ? 1 : 0,
        pinned: pinnedPeerKeys.has(`bot:${bot.id}`),
        archived: archivedPeerKeys.has(`bot:${bot.id}`),
        updatedAtMs: 0,
        avatar: bot.avatar,
      }));
    const groupPeers = groups.map((group): PeerItem => ({
      key: `group:${group.id}`,
      id: group.id,
      groupId: group.id,
      kind: 'group',
      title: group.name,
      subtitle: `${group.memberIds.length} 个成员`,
      unread: 0,
      pinned: pinnedPeerKeys.has(`group:${group.id}`),
      archived: archivedPeerKeys.has(`group:${group.id}`),
      updatedAtMs: group.updatedAtMs,
    }));
    return [...conversationPeers, ...botPeers, ...groupPeers].sort((left, right) => {
      if (left.pinned !== right.pinned) return left.pinned ? -1 : 1;
      return right.updatedAtMs - left.updatedAtMs;
    });
  }, [conversations, bots, groups, pinnedPeerKeys, archivedPeerKeys]);

  const activePeer = peers.find((peer) => peer.key === activePeerKey) ?? null;
  const visiblePeers = peers.filter((peer) => {
    if (!matchesSection(peer, section) && ['chats', 'contacts', 'bots', 'groups', 'channels', 'saved', 'archive'].includes(section)) return false;
    const query = search.trim().toLowerCase();
    return !query || `${peer.title} ${peer.subtitle}`.toLowerCase().includes(query);
  });

  async function openPeer(peer: PeerItem) {
    setActivePeerKey(peer.key);
    setConversationSearchOpen(false);
    setError(null);
    if (peer.kind === 'group' && peer.groupId) {
      const group = groups.find((item) => item.id === peer.groupId);
      setMessages(group ? groupMessages(group) : []);
      return;
    }
    if (peer.conversationId) {
      setMessages([]);
      await execute({ type: 'conversation.open', requestId: nextRequestId('conversation-open'), conversationId: peer.conversationId });
      return;
    }
    setMessages([]);
  }

  async function sendMessage(event: FormEvent) {
    event.preventDefault();
    const text = composer.trim();
    if (!text || !activePeer || pendingSend) return;
    setComposer('');
    setPendingSend(true);
    const optimistic: MessengerMessage = { id: nextRequestId('local'), role: 'me', text, createdAtMs: Date.now() };
    setMessages((current) => [...current, optimistic]);
    try {
      if (activePeer.kind === 'group' && activePeer.groupId) {
        await execute({ type: 'group.send', requestId: nextRequestId('group-send'), id: activePeer.groupId, text });
      } else {
        await execute({
          type: 'chat.send',
          requestId: nextRequestId('chat-send'),
          text,
          conversationId: activePeer.conversationId,
          agentId: activePeer.actorId,
        });
      }
    } catch {
      setMessages((current) => current.filter((message) => message.id !== optimistic.id));
      setComposer(text);
      setPendingSend(false);
    }
  }

  function toggleSet(setter: React.Dispatch<React.SetStateAction<Set<string>>>, key: string) {
    setter((current) => {
      const next = new Set(current);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  }

  async function startCall(kind: 'voice' | 'video') {
    if (!activePeer) return;
    mediaStreamRef.current?.getTracks().forEach((track) => track.stop());
    setLocalCall({ kind, title: activePeer.title, status: 'requesting' });
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true, video: kind === 'video' });
      mediaStreamRef.current = stream;
      setLocalCall({ kind, title: activePeer.title, status: 'ready' });
      window.setTimeout(() => {
        if (localVideoRef.current) {
          localVideoRef.current.srcObject = stream;
          void localVideoRef.current.play().catch(() => {});
        }
      }, 0);
    } catch (cause) {
      setLocalCall({ kind, title: activePeer.title, status: 'failed', error: cause instanceof Error ? cause.message : String(cause) });
    }
  }

  function endCall() {
    mediaStreamRef.current?.getTracks().forEach((track) => track.stop());
    mediaStreamRef.current = null;
    setLocalCall(null);
  }

  async function saveNewDialog() {
    if (!newDialog || !newDialog.name.trim()) return;
    if (newDialog.type === 'group') {
      await execute({
        type: 'group.create',
        requestId: nextRequestId('group-create'),
        name: newDialog.name.trim(),
        description: '',
        memberIds: [...newDialog.selectedBotIds],
      });
      setNewDialog(null);
      setSection('groups');
      return;
    }
    setError('频道 UI 已落地；频道服务端命令正在切换到 Fabushi 自研消息协议，当前不会伪装成已创建。');
  }

  async function openMiniApp(id: string) {
    await execute({ type: 'miniapp.open', requestId: nextRequestId('miniapp-open'), miniAppId: id });
  }

  const sectionIsPeerList = ['chats', 'contacts', 'bots', 'groups', 'channels', 'saved', 'archive'].includes(section);

  return (
    <main className={styles.messenger} data-testid="messenger-workspace">
      <aside className={styles.navRail}>
        <button className={styles.railBrand} type="button" onClick={onOpenAi} title="返回 AI 工作区">法</button>
        <RailButton icon={<MessageCircle />} label="聊天" active={section === 'chats'} onClick={() => setSection('chats')} />
        <RailButton icon={<Users />} label="联系人" active={section === 'contacts'} onClick={() => setSection('contacts')} />
        <RailButton icon={<Bot />} label="Bots" active={section === 'bots'} onClick={() => setSection('bots')} />
        <RailButton icon={<Users />} label="群组" active={section === 'groups'} onClick={() => setSection('groups')} />
        <RailButton icon={<Radio />} label="频道" active={section === 'channels'} onClick={() => setSection('channels')} />
        <RailButton icon={<Phone />} label="通话" active={section === 'calls'} onClick={() => setSection('calls')} />
        <RailButton icon={<Bookmark />} label="收藏" active={section === 'saved'} onClick={() => setSection('saved')} />
        <RailButton icon={<Archive />} label="归档" active={section === 'archive'} onClick={() => setSection('archive')} />
        <RailButton icon={<Folder />} label="文件夹" active={section === 'folders'} onClick={() => setSection('folders')} />
        <div className={styles.railSpacer} />
        <RailButton icon={<AppWindow />} label="Mini Apps" active={section === 'miniapps'} onClick={() => setSection('miniapps')} />
        <RailButton icon={<WalletCards />} label="支付" active={section === 'payments'} onClick={() => setSection('payments')} />
        <RailButton icon={<Settings />} label="设置" active={section === 'settings'} onClick={() => setSection('settings')} />
      </aside>

      <aside className={styles.chatList}>
        <header className={styles.listHeader}>
          <button type="button" className={styles.iconButton} aria-label="菜单"><Menu size={19} /></button>
          <strong>{sectionTitle(section)}</strong>
          <button type="button" className={styles.iconButton} aria-label="新建" onClick={() => setNewDialog({ type: 'group', name: '', selectedBotIds: new Set() })}><SquarePen size={18} /></button>
        </header>
        <label className={styles.searchBox}>
          <Search size={16} />
          <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="搜索消息、联系人和 Bot" />
          {search ? <button type="button" onClick={() => setSearch('')}><X size={14} /></button> : null}
        </label>
        {sectionIsPeerList ? (
          <div className={styles.peerList}>
            <div className={styles.quickActions}>
              <button type="button" onClick={() => setNewDialog({ type: 'group', name: '', selectedBotIds: new Set() })}><Users size={17} /><span>新建群组</span></button>
              <button type="button" onClick={() => setNewDialog({ type: 'channel', name: '', description: '' })}><Radio size={17} /><span>新建频道</span></button>
            </div>
            {visiblePeers.map((peer) => (
              <button data-testid={`peer-${peer.key}`} key={peer.key} type="button" className={peer.key === activePeerKey ? styles.peerActive : styles.peer} onClick={() => void openPeer(peer)}>
                <span className={styles.avatar}>{peer.avatar ? <img src={peer.avatar} alt="" /> : avatarText(peer.title)}<i data-kind={peer.kind} /></span>
                <span className={styles.peerCopy}>
                  <span><strong>{peer.title}</strong><time>{formatTime(peer.updatedAtMs)}</time></span>
                  <small>{peer.subtitle}</small>
                </span>
                <span className={styles.peerMeta}>
                  {peer.pinned ? <Pin size={12} /> : null}
                  {mutedPeerKeys.has(peer.key) ? <BellOff size={12} /> : null}
                  {peer.unread ? <b>{peer.unread}</b> : null}
                </span>
              </button>
            ))}
            {!visiblePeers.length ? <EmptyList section={section} /> : null}
          </div>
        ) : (
          <SectionPanel section={section} bots={bots} peers={peers} onOpenMiniApp={openMiniApp} onCreateGroup={() => setNewDialog({ type: 'group', name: '', selectedBotIds: new Set() })} />
        )}
      </aside>

      <section className={styles.chatWorkspace}>
        {activePeer && sectionIsPeerList ? (
          <>
            <header className={styles.chatHeader}>
              <div className={styles.chatIdentity}>
                <span className={styles.avatar}>{avatarText(activePeer.title)}<i data-kind={activePeer.kind} /></span>
                <div><strong>{activePeer.title}</strong><small>{activePeer.subtitle}{hostReady ? ' · 在线' : ' · 正在连接'}</small></div>
              </div>
              <div className={styles.headerActions}>
                <button type="button" title="语音通话" onClick={() => void startCall('voice')}><PhoneCall size={18} /></button>
                <button type="button" title="视频通话" onClick={() => void startCall('video')}><Video size={18} /></button>
                <button type="button" title="搜索当前会话" data-active={conversationSearchOpen} onClick={() => setConversationSearchOpen((value) => !value)}><Search size={18} /></button>
                <button type="button" title={pinnedPeerKeys.has(activePeer.key) ? '取消置顶' : '置顶'} onClick={() => toggleSet(setPinnedPeerKeys, activePeer.key)}><Pin size={18} /></button>
                <button type="button" title={mutedPeerKeys.has(activePeer.key) ? '开启通知' : '静音'} onClick={() => toggleSet(setMutedPeerKeys, activePeer.key)}><BellOff size={18} /></button>
                <button type="button" title="资料" data-active={infoOpen} onClick={() => setInfoOpen((value) => !value)}><MoreVertical size={18} /></button>
              </div>
            </header>
            {conversationSearchOpen ? (
              <label className={styles.inChatSearch}><Search size={15} /><input placeholder="在当前会话中搜索" autoFocus /><button type="button" onClick={() => setConversationSearchOpen(false)}><X size={14} /></button></label>
            ) : null}
            {error ? <div className={styles.errorBanner} role="alert"><span>{error}</span><button type="button" onClick={() => setError(null)}><X size={14} /></button></div> : null}
            <div className={styles.messageArea}>
              <div className={styles.dayDivider}>今天</div>
              {messages.map((message) => (
                <article key={message.id} className={message.role === 'me' ? styles.messageMine : styles.messagePeer}>
                  <p>{message.text}</p>
                  <small>{formatTime(message.createdAtMs)} {message.role === 'me' ? <Check size={12} /> : null}</small>
                </article>
              ))}
              {!messages.length ? (
                <div className={styles.chatEmpty}>
                  <span className={styles.avatarLarge}>{avatarText(activePeer.title)}</span>
                  <strong>{activePeer.title}</strong>
                  <p>联系人和 AI Bot 使用同一套 Fabushi Rust 消息框架。</p>
                </div>
              ) : null}
            </div>
            <form className={styles.composer} onSubmit={(event) => void sendMessage(event)}>
              <button type="button" title="附件"><Paperclip size={20} /></button>
              <textarea data-testid="messenger-input" value={composer} onChange={(event) => setComposer(event.target.value)} onKeyDown={(event) => { if (event.key === 'Enter' && !event.shiftKey) { event.preventDefault(); event.currentTarget.form?.requestSubmit(); } }} placeholder="消息" rows={1} />
              <button type="button" title="表情"><Smile size={20} /></button>
              {composer.trim() ? <button data-testid="messenger-send" className={styles.sendButton} type="submit" disabled={!hostReady || pendingSend}><Send size={19} /></button> : <button type="button" title="语音消息"><Mic size={20} /></button>}
            </form>
          </>
        ) : (
          <FeatureWorkspace section={section} bots={bots} groups={groups} onOpenMiniApp={openMiniApp} onCreateGroup={() => setNewDialog({ type: 'group', name: '', selectedBotIds: new Set() })} />
        )}
      </section>

      {infoOpen && activePeer && sectionIsPeerList ? (
        <aside className={styles.infoPanel}>
          <header><strong>资料</strong><button type="button" onClick={() => setInfoOpen(false)}><X size={17} /></button></header>
          <div className={styles.profileCard}>
            <span className={styles.avatarHuge}>{avatarText(activePeer.title)}</span>
            <strong>{activePeer.title}</strong>
            <small>{activePeer.subtitle}</small>
            <div>
              <button type="button" onClick={() => void startCall('voice')}><PhoneCall size={18} /><span>通话</span></button>
              <button type="button" onClick={() => void startCall('video')}><Video size={18} /><span>视频</span></button>
              <button type="button" onClick={() => setConversationSearchOpen(true)}><Search size={18} /><span>搜索</span></button>
            </div>
          </div>
          <div className={styles.profileActions}>
            <button type="button" onClick={() => toggleSet(setMutedPeerKeys, activePeer.key)}><BellOff size={17} /><span>{mutedPeerKeys.has(activePeer.key) ? '开启通知' : '静音通知'}</span></button>
            <button type="button" onClick={() => toggleSet(setPinnedPeerKeys, activePeer.key)}><Pin size={17} /><span>{pinnedPeerKeys.has(activePeer.key) ? '取消置顶' : '置顶会话'}</span></button>
            <button type="button" onClick={() => { toggleSet(setArchivedPeerKeys, activePeer.key); setSection('archive'); }}><Archive size={17} /><span>{archivedPeerKeys.has(activePeer.key) ? '移出归档' : '归档会话'}</span></button>
          </div>
          <nav className={styles.infoTabs}>
            <button type="button" data-active={infoTab === 'media'} onClick={() => setInfoTab('media')}>媒体</button>
            <button type="button" data-active={infoTab === 'files'} onClick={() => setInfoTab('files')}>文件</button>
            <button type="button" data-active={infoTab === 'links'} onClick={() => setInfoTab('links')}>链接</button>
          </nav>
          <div className={styles.infoContent}>
            {infoTab === 'media' ? <><Image size={30} /><strong>共享媒体</strong><p>图片、视频和动画会按消息索引显示在这里。</p></> : null}
            {infoTab === 'files' ? <><FileText size={30} /><strong>共享文件</strong><p>文档、音频和附件统一由 Rust 媒体层管理。</p></> : null}
            {infoTab === 'links' ? <><Link2 size={30} /><strong>共享链接</strong><p>链接会从富文本实体中建立可搜索索引。</p></> : null}
          </div>
        </aside>
      ) : null}

      {newDialog ? (
        <div className={styles.backdrop} onMouseDown={() => setNewDialog(null)}>
          <section className={styles.dialog} onMouseDown={(event) => event.stopPropagation()}>
            <header><div><strong>{newDialog.type === 'group' ? '新建群组' : '新建频道'}</strong><small>{newDialog.type === 'group' ? '联系人和 Bot 可以在同一群组中协作' : '面向大量订阅者的广播会话'}</small></div><button type="button" onClick={() => setNewDialog(null)}><X size={17} /></button></header>
            <label><span>名称</span><input autoFocus value={newDialog.name} onChange={(event) => setNewDialog((current) => current ? { ...current, name: event.target.value } : current)} placeholder={newDialog.type === 'group' ? '群组名称' : '频道名称'} /></label>
            {newDialog.type === 'channel' ? <label><span>描述</span><textarea value={newDialog.description} onChange={(event) => setNewDialog((current) => current?.type === 'channel' ? { ...current, description: event.target.value } : current)} rows={3} placeholder="频道简介" /></label> : null}
            {newDialog.type === 'group' ? (
              <div className={styles.memberPicker}>
                <span>选择 Bot 成员</span>
                {bots.map((bot) => {
                  const checked = newDialog.selectedBotIds.has(bot.id);
                  return <button type="button" data-selected={checked} key={bot.id} onClick={() => setNewDialog((current) => {
                    if (!current || current.type !== 'group') return current;
                    const selectedBotIds = new Set(current.selectedBotIds);
                    if (selectedBotIds.has(bot.id)) selectedBotIds.delete(bot.id); else selectedBotIds.add(bot.id);
                    return { ...current, selectedBotIds };
                  })}><span className={styles.avatarSmall}>{avatarText(bot.name)}</span><div><strong>{bot.name}</strong><small>{bot.description}</small></div>{checked ? <Check size={16} /> : <Plus size={16} />}</button>;
                })}
              </div>
            ) : null}
            <footer><button type="button" onClick={() => setNewDialog(null)}>取消</button><button type="button" className={styles.primaryButton} disabled={!newDialog.name.trim()} onClick={() => void saveNewDialog()}>{newDialog.type === 'group' ? '创建群组' : '创建频道'}</button></footer>
          </section>
        </div>
      ) : null}

      {localCall ? (
        <div className={styles.backdrop}>
          <section className={styles.callDialog}>
            <header><span className={styles.avatarHuge}>{avatarText(localCall.title)}</span><strong>{localCall.title}</strong><small>{localCall.status === 'requesting' ? '正在请求麦克风/摄像头…' : localCall.status === 'ready' ? `${localCall.kind === 'video' ? '视频' : '语音'}会话已准备` : '无法启动媒体'}</small></header>
            {localCall.kind === 'video' && localCall.status === 'ready' ? <video ref={localVideoRef} muted playsInline className={styles.localVideo} /> : null}
            {localCall.error ? <p>{localCall.error}</p> : null}
            <div className={styles.callActions}><button type="button"><Mic size={20} /></button>{localCall.kind === 'video' ? <button type="button"><Camera size={20} /></button> : null}<button type="button" className={styles.hangup} onClick={endCall}><Phone size={21} /></button></div>
            <p className={styles.callNote}>本机媒体链路已经真实启用；远端信令与群组通话正在接入 Fabushi 自研实时协议，不会回退 Telegram API。</p>
          </section>
        </div>
      ) : null}

      {miniApp ? (
        <div className={styles.backdrop} onMouseDown={() => setMiniApp(null)}>
          <section className={styles.miniAppDialog} onMouseDown={(event) => event.stopPropagation()}>
            <header><div><strong>{defaultMiniApps.find((app) => app.id === miniApp.id)?.title ?? miniApp.id}</strong><small>Mini App · 受控宿主容器</small></div><button type="button" onClick={() => setMiniApp(null)}><X size={17} /></button></header>
            {miniApp.html ? <iframe title={miniApp.id} sandbox="allow-scripts allow-forms" srcDoc={miniApp.html} /> : <div className={styles.miniAppEmpty}><AppWindow size={38} /><strong>Mini App 已由 Host 打开</strong><p>该应用没有返回内联 HTML；生产构建会使用受控 WebView/页面容器。</p></div>}
          </section>
        </div>
      ) : null}
    </main>
  );
}

function RailButton({ icon, label, active, onClick }: { icon: React.ReactNode; label: string; active: boolean; onClick: () => void }) {
  return <button type="button" data-active={active} onClick={onClick} title={label}><span>{icon}</span><small>{label}</small></button>;
}

function sectionTitle(section: MessengerSection): string {
  const labels: Record<MessengerSection, string> = {
    chats: '聊天', contacts: '联系人', bots: 'AI Bots', groups: '群组', channels: '频道', calls: '通话', saved: '收藏', archive: '已归档', folders: '聊天文件夹', miniapps: 'Mini Apps', payments: '支付', settings: '消息设置',
  };
  return labels[section];
}

function EmptyList({ section }: { section: MessengerSection }) {
  const copy: Partial<Record<MessengerSection, string>> = {
    contacts: '联系人会通过 Mahayana Social Provider 出现在这里。',
    bots: '创建 Bot 后，它会和联系人出现在同一消息框架中。',
    groups: '创建一个群组，让人类和 Bot 一起协作。',
    channels: '频道将使用 Fabushi 自研广播协议。',
    archive: '没有已归档会话。',
    saved: '收藏消息会出现在这里。',
  };
  return <div className={styles.emptyList}><MessageCircle size={27} /><strong>暂无内容</strong><p>{copy[section] || '开始一个新的会话。'}</p></div>;
}

function SectionPanel({ section, bots, peers, onOpenMiniApp, onCreateGroup }: { section: MessengerSection; bots: BotSummary[]; peers: PeerItem[]; onOpenMiniApp: (id: string) => Promise<void>; onCreateGroup: () => void }) {
  if (section === 'miniapps') {
    return <div className={styles.sectionList}>{defaultMiniApps.map((app) => <button type="button" key={app.id} onClick={() => void onOpenMiniApp(app.id)}><span className={styles.appIcon}><AppWindow size={18} /></span><div><strong>{app.title}</strong><small>{app.description}</small></div></button>)}</div>;
  }
  if (section === 'calls') {
    return <div className={styles.sectionList}><div className={styles.panelHint}><Phone size={24} /><strong>最近通话</strong><p>语音、视频和群组通话入口已经统一到 Messenger。打开一个会话后可从顶部发起。</p></div></div>;
  }
  if (section === 'folders') {
    return <div className={styles.sectionList}><div className={styles.panelHint}><Folder size={24} /><strong>聊天文件夹</strong><p>按联系人、Bot、群组、频道、未读和静音状态组织会话。</p></div><button type="button"><Plus size={17} /><div><strong>新建文件夹</strong><small>自定义包含和排除规则</small></div></button></div>;
  }
  if (section === 'payments') {
    return <div className={styles.sectionList}><div className={styles.panelHint}><WalletCards size={24} /><strong>支付与账单</strong><p>Invoice、Order、订阅、数字商品权益已经落到 Fabushi Rust 支付域；Host 支付 provider 接线后会在这里展示订单。</p></div><button type="button"><ShoppingBag size={17} /><div><strong>创建支付 Bot</strong><small>通过 Bot/联系人会话发送账单</small></div></button></div>;
  }
  if (section === 'settings') {
    return <div className={styles.sectionList}><button type="button"><BellOff size={17} /><div><strong>通知</strong><small>每个会话独立设置声音与预览</small></div></button><button type="button"><Image size={17} /><div><strong>聊天外观</strong><small>主题、壁纸和消息密度</small></div></button><button type="button"><FileText size={17} /><div><strong>数据与存储</strong><small>媒体自动下载、缓存与加密存储</small></div></button></div>;
  }
  return <div className={styles.sectionList}><div className={styles.panelHint}><Users size={24} /><strong>{bots.length} 个 Bot · {peers.length} 个会话</strong><p>联系人、AI Bot、群组和频道共享同一 Actor/Conversation 模型。</p></div><button type="button" onClick={onCreateGroup}><UserPlus size={17} /><div><strong>创建协作群</strong><small>把 AI Bot 与联系人放进同一个群聊</small></div></button></div>;
}

function FeatureWorkspace({ section, bots, groups, onOpenMiniApp, onCreateGroup }: { section: MessengerSection; bots: BotSummary[]; groups: GroupSummary[]; onOpenMiniApp: (id: string) => Promise<void>; onCreateGroup: () => void }) {
  if (section === 'miniapps') {
    return <div className={styles.featureWorkspace}><AppWindow size={54} /><h2>Mini Apps</h2><p>Mini App 与 Bot、会话、支付共用同一身份和权限上下文。</p><div className={styles.featureGrid}>{defaultMiniApps.map((app) => <button type="button" key={app.id} onClick={() => void onOpenMiniApp(app.id)}><AppWindow size={22} /><strong>{app.title}</strong><small>{app.description}</small></button>)}</div></div>;
  }
  if (section === 'payments') {
    return <div className={styles.featureWorkspace}><WalletCards size={54} /><h2>Fabushi Pay</h2><p>自研支付域已经包含账单、订单、订阅/数字商品、退款状态和权益模型，不依赖 Telegram Payments。</p><div className={styles.featureGrid}><button type="button"><ShoppingBag size={22} /><strong>账单</strong><small>在会话中发送 Invoice</small></button><button type="button"><WalletCards size={22} /><strong>钱包</strong><small>余额与待结算资金</small></button><button type="button"><Check size={22} /><strong>权益</strong><small>数字商品与订阅授权</small></button></div></div>;
  }
  if (section === 'calls') {
    return <div className={styles.featureWorkspace}><Phone size={54} /><h2>通话</h2><p>从任意联系人、Bot 或群组会话顶部发起语音/视频；桌面媒体权限和预览已经接通。</p></div>;
  }
  if (section === 'folders') {
    return <div className={styles.featureWorkspace}><Folder size={54} /><h2>聊天文件夹</h2><p>把联系人、Bot、群组与频道按工作流组织成同一套导航。</p><button className={styles.primaryButton} type="button"><Plus size={17} /> 新建文件夹</button></div>;
  }
  if (section === 'settings') {
    return <div className={styles.featureWorkspace}><Settings size={54} /><h2>消息设置</h2><p>通知、隐私、安全、存储、主题、快捷键与设备会逐步统一在这里。</p></div>;
  }
  return <div className={styles.featureWorkspace}><MessageCircle size={54} /><h2>{sectionTitle(section)}</h2><p>{bots.length} 个 Bot，{groups.length} 个群组已经连接到统一消息 Host。</p><button className={styles.primaryButton} type="button" onClick={onCreateGroup}><Users size={17} /> 创建群组</button></div>;
}
