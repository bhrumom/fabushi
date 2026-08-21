import {
  AppWindow,
  Archive,
  BellOff,
  Bot,
  Bookmark,
  Check,
  Copy,
  Edit3,
  FileText,
  Folder,
  Forward,
  Image,
  Link2,
  MapPin,
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
  Reply,
  Search,
  Send,
  Settings,
  ShoppingBag,
  Smile,
  SquarePen,
  Trash2,
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
import {
  SelfHostedMessagingClientV2,
  asMessagingHostEvent,
  messagingText,
  type MessagingConversation,
  type MessagingMessage,
} from './selfhosted-messaging-client-v2';
import styles from './messaging-shell.module.css';
import extra from './messaging-shell-v2.module.css';

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
type PeerSource = 'legacy' | 'selfhosted';

type PeerItem = {
  key: string;
  id: string;
  source: PeerSource;
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

type DisplayMessage = {
  id: string;
  source: PeerSource;
  role: 'me' | 'peer';
  text: string;
  createdAtMs: number;
  pinned?: boolean;
  reactions?: string[];
};

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

type MessageMenu = { message: DisplayMessage; x: number; y: number } | null;
type ForwardDialogState = { sourceConversationId: string; message: DisplayMessage } | null;
type InfoTab = 'media' | 'files' | 'links';

const rootSurfaceKey = 'fabushi.desktop.root-surface.v2';
const messengerSettingsKey = 'fabushi.desktop.messenger-settings.v2';
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

function avatarText(title: string): string {
  const value = title.trim();
  return value ? Array.from(value)[0] ?? '聊' : '聊';
}

function formatTime(timestamp: number): string {
  if (!timestamp) return '';
  const date = new Date(timestamp);
  if (date.toDateString() === new Date().toDateString()) {
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }
  return date.toLocaleDateString([], { month: 'numeric', day: 'numeric' });
}

function legacyKind(conversation: ConversationSummary): PeerKind {
  const key = `${conversation.id} ${conversation.kind}`.toLowerCase();
  if (key.includes('saved')) return 'saved';
  if (key.includes('channel')) return 'channel';
  return 'conversation';
}

function selfKind(conversation: MessagingConversation): PeerKind {
  if (conversation.kind === 'channel') return 'channel';
  if (conversation.kind === 'group') return 'group';
  if (conversation.kind === 'savedMessages') return 'saved';
  return 'conversation';
}

function sectionTitle(section: MessengerSection): string {
  return {
    chats: '聊天',
    contacts: '联系人',
    bots: 'AI Bots',
    groups: '群组',
    channels: '频道',
    calls: '通话',
    saved: '收藏',
    archive: '已归档',
    folders: '聊天文件夹',
    miniapps: 'Mini Apps',
    payments: '支付',
    settings: '消息设置',
  }[section];
}

function matchesSection(peer: PeerItem, section: MessengerSection): boolean {
  if (section === 'chats') return !peer.archived;
  if (section === 'contacts') return peer.source === 'legacy' && peer.kind === 'conversation' && peer.id.startsWith('mahayana:contact:');
  if (section === 'bots') return peer.kind === 'bot';
  if (section === 'groups') return peer.kind === 'group';
  if (section === 'channels') return peer.kind === 'channel';
  if (section === 'saved') return peer.kind === 'saved';
  if (section === 'archive') return peer.archived;
  return false;
}

function upsertById<T extends { id: string }>(items: T[], item: T): T[] {
  return [...items.filter((current) => current.id !== item.id), item];
}

export default function DesktopShellV2() {
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
      // The shell remains usable when storage is unavailable.
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
  const selfHosted = useMemo(() => new SelfHostedMessagingClientV2(transport), [transport]);
  const [hostReady, setHostReady] = useState(false);
  const [section, setSection] = useState<MessengerSection>('chats');
  const [conversations, setConversations] = useState<ConversationSummary[]>([]);
  const [bots, setBots] = useState<BotSummary[]>([]);
  const [groups, setGroups] = useState<GroupSummary[]>([]);
  const [selfConversations, setSelfConversations] = useState<MessagingConversation[]>([]);
  const [selfMessages, setSelfMessages] = useState<Record<string, MessagingMessage[]>>({});
  const [activePeerKey, setActivePeerKey] = useState<string | null>(null);
  const [messages, setMessages] = useState<DisplayMessage[]>([]);
  const [composer, setComposer] = useState('');
  const [replyTo, setReplyTo] = useState<DisplayMessage | null>(null);
  const [silentSend, setSilentSend] = useState(false);
  const [scheduledAtMs, setScheduledAtMs] = useState<number | undefined>();
  const [search, setSearch] = useState('');
  const [conversationSearchOpen, setConversationSearchOpen] = useState(false);
  const [infoOpen, setInfoOpen] = useState(true);
  const [infoTab, setInfoTab] = useState<InfoTab>('media');
  const [pendingSend, setPendingSend] = useState(false);
  const [newDialog, setNewDialog] = useState<NewDialog>(null);
  const [messageMenu, setMessageMenu] = useState<MessageMenu>(null);
  const [forwardDialog, setForwardDialog] = useState<ForwardDialogState>(null);
  const [attachmentMenuOpen, setAttachmentMenuOpen] = useState(false);
  const [attachmentProgress, setAttachmentProgress] = useState<string | null>(null);
  const [localCall, setLocalCall] = useState<LocalCall | null>(null);
  const [miniApp, setMiniApp] = useState<{ id: string; html?: string } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [mutedPeerKeys, setMutedPeerKeys] = useState<Set<string>>(() => new Set());
  const [pinnedPeerKeys, setPinnedPeerKeys] = useState<Set<string>>(() => new Set());
  const [archivedPeerKeys, setArchivedPeerKeys] = useState<Set<string>>(() => new Set());
  const activePeerKeyRef = useRef<string | null>(null);
  const mediaStreamRef = useRef<MediaStream | null>(null);
  const localVideoRef = useRef<HTMLVideoElement>(null);
  const mediaInputRef = useRef<HTMLInputElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

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
      setMutedPeerKeys(new Set(stored.muted ?? []));
      setPinnedPeerKeys(new Set(stored.pinned ?? []));
      setArchivedPeerKeys(new Set(stored.archived ?? []));
    } catch {
      // Ignore malformed old settings.
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
      // Persistence is a convenience only.
    }
  }, [mutedPeerKeys, pinnedPeerKeys, archivedPeerKeys]);

  useEffect(() => {
    let closed = false;
    const unsubscribe = transport.subscribe((event) => {
      if (!closed) handleRuntimeEvent(event);
    });
    void transport.initialize({ profileId: 'desktop-messenger-v2', mode: 'production' })
      .then(async () => {
        if (closed) return;
        setHostReady(true);
        refreshLegacy();
        try {
          await selfHosted.ensureCurrentActor();
          await selfHosted.sync();
        } catch (cause) {
          setError(cause instanceof Error ? cause.message : String(cause));
        }
      })
      .catch((cause: unknown) => setError(cause instanceof Error ? cause.message : String(cause)));
    return () => {
      closed = true;
      unsubscribe();
      mediaStreamRef.current?.getTracks().forEach((track) => track.stop());
      void transport.close();
    };
  }, [transport, selfHosted]);

  function nextRequestId(prefix: string): string {
    return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  }

  function execute(command: Parameters<MahayanaHostTransport['execute']>[0]) {
    return transport.execute(command).catch((cause: unknown) => {
      setError(cause instanceof Error ? cause.message : String(cause));
      throw cause;
    });
  }

  function refreshLegacy() {
    void Promise.all([
      execute({ type: 'conversation.list', requestId: nextRequestId('conversation-list') }),
      execute({ type: 'bot.list', requestId: nextRequestId('bot-list') }),
      execute({ type: 'group.list', requestId: nextRequestId('group-list') }),
    ]).catch(() => {});
  }

  function displaySelfMessage(message: MessagingMessage): DisplayMessage {
    return {
      id: message.id,
      source: 'selfhosted',
      role: message.senderId === selfHosted.actorId ? 'me' : 'peer',
      text: messagingText(message),
      createdAtMs: message.createdAtMs,
      pinned: message.pinned,
      reactions: message.reactions.map((reaction) => `${reaction.reaction} ${reaction.count}`),
    };
  }

  function showSelfConversation(conversationId: string) {
    setMessages((selfMessages[conversationId] ?? []).filter((message) => !message.deleted).map(displaySelfMessage));
  }

  function handleSelfHostedEvent(runtimeEvent: RuntimeEvent): boolean {
    const hostEvent = asMessagingHostEvent(runtimeEvent);
    if (!hostEvent) return false;
    const event = hostEvent.envelope.event;
    switch (event.type) {
      case 'syncBatch': {
        const payload = event as unknown as {
          conversations?: MessagingConversation[];
          messages?: MessagingMessage[];
        };
        const nextConversations = payload.conversations ?? [];
        const grouped: Record<string, MessagingMessage[]> = {};
        for (const message of payload.messages ?? []) {
          (grouped[message.conversationId] ??= []).push(message);
        }
        for (const list of Object.values(grouped)) list.sort((a, b) => a.createdAtMs - b.createdAtMs);
        setSelfConversations(nextConversations);
        setSelfMessages(grouped);
        const active = activePeerKeyRef.current;
        if (active?.startsWith('selfhosted:')) {
          const conversationId = active.slice('selfhosted:'.length);
          setMessages((grouped[conversationId] ?? []).filter((message) => !message.deleted).map(displaySelfMessage));
        }
        break;
      }
      case 'conversationChanged': {
        const conversation = (event as unknown as { conversation: MessagingConversation }).conversation;
        setSelfConversations((current) => upsertById(current, conversation));
        break;
      }
      case 'messageAdded':
      case 'messageChanged': {
        const message = (event as unknown as { message: MessagingMessage }).message;
        setSelfMessages((current) => {
          const list = upsertById(current[message.conversationId] ?? [], message)
            .sort((a, b) => a.createdAtMs - b.createdAtMs);
          const next = { ...current, [message.conversationId]: list };
          if (activePeerKeyRef.current === `selfhosted:${message.conversationId}`) {
            setMessages(list.filter((item) => !item.deleted).map(displaySelfMessage));
          }
          return next;
        });
        setPendingSend(false);
        break;
      }
      case 'messagesDeleted': {
        const payload = event as unknown as { conversationId: string; messageIds: string[] };
        setSelfMessages((current) => {
          const list = (current[payload.conversationId] ?? []).filter((message) => !payload.messageIds.includes(message.id));
          if (activePeerKeyRef.current === `selfhosted:${payload.conversationId}`) {
            setMessages(list.map(displaySelfMessage));
          }
          return { ...current, [payload.conversationId]: list };
        });
        break;
      }
      default:
        break;
    }
    return true;
  }

  function handleRuntimeEvent(event: RuntimeEvent) {
    if (handleSelfHostedEvent(event)) return;
    switch (event.type) {
      case 'host.ready':
        setHostReady(true);
        break;
      case 'conversation.listed':
        setConversations(event.conversations);
        if (!activePeerKeyRef.current && event.conversations[0]) {
          const conversation = event.conversations[0];
          setActivePeerKey(`legacy:conversation:${conversation.id}`);
          void execute({ type: 'conversation.open', requestId: nextRequestId('conversation-open'), conversationId: conversation.id });
        }
        break;
      case 'conversation.opened':
        if (activePeerKeyRef.current === `legacy:conversation:${event.conversationId}`) {
          setMessages(event.messages.map((message) => ({
            id: message.id,
            source: 'legacy',
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
          : upsertById(current, event.bot));
        break;
      case 'group.listed':
        setGroups(event.groups);
        break;
      case 'group.changed':
        setGroups((current) => event.action === 'deleted'
          ? current.filter((group) => group.id !== event.group.id)
          : upsertById(current, event.group));
        if (activePeerKeyRef.current === `legacy:group:${event.group.id}`) {
          setMessages(event.group.messages.map((message) => ({
            id: message.id,
            source: 'legacy',
            role: message.speaker.kind === 'user' ? 'me' : 'peer',
            text: message.content,
            createdAtMs: message.createdAtMs,
          })));
          setPendingSend(false);
        }
        break;
      case 'chat.message':
        setPendingSend(false);
        setMessages((current) => {
          const id = event.operationId || nextRequestId('message');
          if (current.some((message) => message.id === id && message.text === event.text)) return current;
          return [...current, {
            id,
            source: 'legacy',
            role: event.role === 'user' ? 'me' : 'peer',
            text: event.text,
            createdAtMs: Date.now(),
          }];
        });
        break;
      case 'chat.delta':
        setPendingSend(false);
        setMessages((current) => {
          const index = current.findIndex((message) => message.id === event.operationId);
          if (index < 0) return [...current, { id: event.operationId, source: 'legacy', role: 'peer', text: event.delta, createdAtMs: Date.now() }];
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

  const peers = useMemo<PeerItem[]>(() => {
    const legacyConversations = conversations.map((conversation): PeerItem => ({
      key: `legacy:conversation:${conversation.id}`,
      id: conversation.id,
      source: 'legacy',
      conversationId: conversation.id,
      kind: legacyKind(conversation),
      title: conversation.title,
      subtitle: conversation.kind,
      unread: conversation.unreadCount,
      pinned: conversation.pinned || pinnedPeerKeys.has(`legacy:conversation:${conversation.id}`),
      archived: archivedPeerKeys.has(`legacy:conversation:${conversation.id}`),
      updatedAtMs: conversation.updatedAtMs,
    }));
    const conversationIds = new Set(conversations.map((conversation) => conversation.id));
    const botPeers = bots
      .filter((bot) => !bot.conversationId || !conversationIds.has(bot.conversationId))
      .map((bot): PeerItem => ({
        key: `legacy:bot:${bot.id}`,
        id: bot.id,
        source: 'legacy',
        actorId: bot.id,
        conversationId: bot.conversationId,
        kind: 'bot',
        title: bot.name,
        subtitle: bot.description || bot.title || 'AI Bot',
        unread: bot.unread ? 1 : 0,
        pinned: pinnedPeerKeys.has(`legacy:bot:${bot.id}`),
        archived: archivedPeerKeys.has(`legacy:bot:${bot.id}`),
        updatedAtMs: 0,
        avatar: bot.avatar,
      }));
    const legacyGroups = groups.map((group): PeerItem => ({
      key: `legacy:group:${group.id}`,
      id: group.id,
      source: 'legacy',
      groupId: group.id,
      kind: 'group',
      title: group.name,
      subtitle: `${group.memberIds.length} 个 AI / 成员`,
      unread: 0,
      pinned: pinnedPeerKeys.has(`legacy:group:${group.id}`),
      archived: archivedPeerKeys.has(`legacy:group:${group.id}`),
      updatedAtMs: group.updatedAtMs,
    }));
    const nativePeers = selfConversations.map((conversation): PeerItem => ({
      key: `selfhosted:${conversation.id}`,
      id: conversation.id,
      source: 'selfhosted',
      conversationId: conversation.id,
      kind: selfKind(conversation),
      title: conversation.title,
      subtitle: conversation.description || ({ channel: '频道', group: '群组', saved: '收藏消息', conversation: '私聊', bot: 'Bot' } as const)[selfKind(conversation)],
      unread: conversation.unreadCount,
      pinned: conversation.pinned,
      archived: conversation.archived,
      updatedAtMs: conversation.updatedAtMs,
      avatar: conversation.avatarUrl,
    }));
    return [...legacyConversations, ...botPeers, ...legacyGroups, ...nativePeers].sort((left, right) => {
      if (left.pinned !== right.pinned) return left.pinned ? -1 : 1;
      return right.updatedAtMs - left.updatedAtMs;
    });
  }, [conversations, bots, groups, selfConversations, pinnedPeerKeys, archivedPeerKeys]);

  const activePeer = peers.find((peer) => peer.key === activePeerKey) ?? null;
  const visiblePeers = peers.filter((peer) => {
    if (['chats', 'contacts', 'bots', 'groups', 'channels', 'saved', 'archive'].includes(section) && !matchesSection(peer, section)) return false;
    const query = search.trim().toLowerCase();
    return !query || `${peer.title} ${peer.subtitle}`.toLowerCase().includes(query);
  });
  const sectionIsPeerList = ['chats', 'contacts', 'bots', 'groups', 'channels', 'saved', 'archive'].includes(section);

  async function openPeer(peer: PeerItem) {
    setActivePeerKey(peer.key);
    setReplyTo(null);
    setError(null);
    setConversationSearchOpen(false);
    if (peer.source === 'selfhosted' && peer.conversationId) {
      showSelfConversation(peer.conversationId);
      const list = selfMessages[peer.conversationId] ?? [];
      const last = list.filter((message) => !message.deleted).at(-1);
      if (last) void selfHosted.markRead(peer.conversationId, last.id).catch(() => {});
      return;
    }
    if (peer.kind === 'group' && peer.groupId) {
      const group = groups.find((item) => item.id === peer.groupId);
      setMessages(group?.messages.map((message) => ({
        id: message.id,
        source: 'legacy',
        role: message.speaker.kind === 'user' ? 'me' : 'peer',
        text: message.content,
        createdAtMs: message.createdAtMs,
      })) ?? []);
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
    setPendingSend(true);
    setComposer('');
    try {
      if (activePeer.source === 'selfhosted' && activePeer.conversationId) {
        await selfHosted.sendText(activePeer.conversationId, text, {
          replyToMessageId: replyTo?.id,
          scheduledAtMs,
          silent: silentSend,
        });
      } else if (activePeer.kind === 'group' && activePeer.groupId) {
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
      setReplyTo(null);
      setScheduledAtMs(undefined);
    } catch (cause) {
      setComposer(text);
      setPendingSend(false);
      setError(cause instanceof Error ? cause.message : String(cause));
    }
  }

  async function saveNewDialog() {
    if (!newDialog || !newDialog.name.trim()) return;
    try {
      if (newDialog.type === 'channel') {
        const conversation = await selfHosted.createChannel(newDialog.name, newDialog.description);
        setSelfConversations((current) => upsertById(current, conversation));
        setNewDialog(null);
        setSection('channels');
        await openPeer({
          key: `selfhosted:${conversation.id}`,
          id: conversation.id,
          source: 'selfhosted',
          conversationId: conversation.id,
          kind: 'channel',
          title: conversation.title,
          subtitle: conversation.description || '频道',
          unread: 0,
          pinned: false,
          archived: false,
          updatedAtMs: conversation.updatedAtMs,
        });
        return;
      }
      await execute({
        type: 'group.create',
        requestId: nextRequestId('group-create'),
        name: newDialog.name.trim(),
        description: '',
        memberIds: [...newDialog.selectedBotIds],
      });
      setNewDialog(null);
      setSection('groups');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    }
  }

  async function ensureSavedMessages() {
    try {
      const existing = selfConversations.find((conversation) => conversation.kind === 'savedMessages');
      const conversation = existing ?? await selfHosted.ensureSavedMessages();
      if (!existing) setSelfConversations((current) => upsertById(current, conversation));
      setSection('saved');
      await openPeer({
        key: `selfhosted:${conversation.id}`,
        id: conversation.id,
        source: 'selfhosted',
        conversationId: conversation.id,
        kind: 'saved',
        title: conversation.title,
        subtitle: '收藏消息',
        unread: conversation.unreadCount,
        pinned: conversation.pinned,
        archived: conversation.archived,
        updatedAtMs: conversation.updatedAtMs,
      });
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    }
  }

  async function sendAttachmentFile(file: File) {
    if (!activePeer?.conversationId || activePeer.source !== 'selfhosted') {
      setError('附件需要发送到 Fabushi 自建会话。');
      return;
    }
    setAttachmentMenuOpen(false);
    setPendingSend(true);
    setAttachmentProgress(`正在上传 ${file.name}…`);
    try {
      await selfHosted.sendAttachment(
        activePeer.conversationId,
        file,
        { replyToMessageId: replyTo?.id, scheduledAtMs, silent: silentSend },
        (uploaded, total) => setAttachmentProgress(`正在上传 ${file.name} · ${Math.round((uploaded / total) * 100)}%`),
      );
      setReplyTo(null);
      setScheduledAtMs(undefined);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    } finally {
      setPendingSend(false);
      setAttachmentProgress(null);
    }
  }

  async function sendPoll() {
    if (!activePeer?.conversationId || activePeer.source !== 'selfhosted') {
      setError('投票使用 Fabushi 自研消息协议；请先打开自建群组或频道。');
      return;
    }
    const question = window.prompt('投票问题');
    if (!question) return;
    const raw = window.prompt('选项（用 | 分隔，至少两个）', '选项一 | 选项二');
    if (!raw) return;
    try {
      await selfHosted.sendPoll(activePeer.conversationId, question, raw.split('|'));
      setAttachmentMenuOpen(false);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    }
  }

  async function sendLocation() {
    if (!activePeer?.conversationId || activePeer.source !== 'selfhosted') {
      setError('位置消息需要自建会话。');
      return;
    }
    if (!navigator.geolocation) {
      setError('当前平台没有提供定位能力。');
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (position) => void selfHosted.sendContent(activePeer.conversationId!, {
        type: 'location',
        data: { latitude: position.coords.latitude, longitude: position.coords.longitude },
      }).catch((cause: unknown) => setError(cause instanceof Error ? cause.message : String(cause))),
      (positionError) => setError(positionError.message),
    );
    setAttachmentMenuOpen(false);
  }

  async function createInvoiceForActivePeer() {
    if (!activePeer?.conversationId || activePeer.source !== 'selfhosted') {
      setError('账单需要发送到 Fabushi 自建会话。');
      return;
    }
    const title = window.prompt('账单名称', '订单');
    if (!title) return;
    const amount = Number(window.prompt('金额（例如 9.99）', '9.99'));
    if (!Number.isFinite(amount) || amount < 0) {
      setError('金额无效。');
      return;
    }
    try {
      await selfHosted.createInvoice({
        conversationId: activePeer.conversationId,
        title,
        currency: 'USD',
        amountMinor: Math.round(amount * 100),
        providerId: 'fabushi-pay',
      });
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    }
  }

  async function handleMessageAction(action: 'copy' | 'reply' | 'forward' | 'edit' | 'delete' | 'react' | 'pin') {
    const target = messageMenu?.message;
    if (!target || !activePeer) return;
    setMessageMenu(null);
    if (action === 'copy') {
      await navigator.clipboard.writeText(target.text);
      return;
    }
    if (action === 'reply') {
      setReplyTo(target);
      return;
    }
    if (action === 'forward') {
      if (activePeer.source !== 'selfhosted' || !activePeer.conversationId || target.source !== 'selfhosted') {
        setError('转发需要源消息已迁移到 Fabushi 自建协议。');
        return;
      }
      setForwardDialog({ sourceConversationId: activePeer.conversationId, message: target });
      return;
    }
    if (activePeer.source !== 'selfhosted' || !activePeer.conversationId || target.source !== 'selfhosted') {
      setError('该消息来自旧会话适配器；修改类操作正在统一迁移到 Fabushi 自建协议。');
      return;
    }
    try {
      if (action === 'delete') await selfHosted.deleteMessages(activePeer.conversationId, [target.id]);
      if (action === 'react') await selfHosted.setReaction(activePeer.conversationId, target.id, '👍');
      if (action === 'pin') await selfHosted.pinMessage(activePeer.conversationId, target.id, !target.pinned);
      if (action === 'edit') {
        const text = window.prompt('编辑消息', target.text);
        if (text && text !== target.text) await selfHosted.editText(activePeer.conversationId, target.id, text);
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    }
  }

  async function forwardToPeer(peer: PeerItem) {
    if (!forwardDialog || peer.source !== 'selfhosted' || !peer.conversationId) return;
    try {
      await selfHosted.forwardMessage(
        forwardDialog.sourceConversationId,
        forwardDialog.message.id,
        peer.conversationId,
      );
      setForwardDialog(null);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    }
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

  function toggleLocalSet(setter: React.Dispatch<React.SetStateAction<Set<string>>>, key: string) {
    setter((current) => {
      const next = new Set(current);
      if (next.has(key)) next.delete(key); else next.add(key);
      return next;
    });
  }

  async function togglePinConversation(peer: PeerItem) {
    if (peer.source === 'selfhosted' && peer.conversationId) {
      await selfHosted.pinConversation(peer.conversationId, !peer.pinned);
      return;
    }
    toggleLocalSet(setPinnedPeerKeys, peer.key);
  }

  async function toggleArchiveConversation(peer: PeerItem) {
    if (peer.source === 'selfhosted' && peer.conversationId) {
      await selfHosted.archiveConversation(peer.conversationId, !peer.archived);
      return;
    }
    toggleLocalSet(setArchivedPeerKeys, peer.key);
  }

  async function toggleMuteConversation(peer: PeerItem) {
    if (peer.source === 'selfhosted' && peer.conversationId) {
      const muted = mutedPeerKeys.has(peer.key);
      await selfHosted.setConversationNotifications(peer.conversationId, muted ? undefined : Date.now() + 365 * 24 * 60 * 60 * 1000);
    }
    toggleLocalSet(setMutedPeerKeys, peer.key);
  }

  async function openMiniApp(id: string) {
    await execute({ type: 'miniapp.open', requestId: nextRequestId('miniapp-open'), miniAppId: id });
  }

  return (
    <main className={styles.messenger} data-testid="messenger-workspace" onClick={() => setMessageMenu(null)}>
      <aside className={styles.navRail}>
        <button className={styles.railBrand} type="button" onClick={onOpenAi} title="返回 AI 工作区">法</button>
        <RailButton icon={<MessageCircle />} label="聊天" active={section === 'chats'} onClick={() => setSection('chats')} />
        <RailButton icon={<Users />} label="联系人" active={section === 'contacts'} onClick={() => setSection('contacts')} />
        <RailButton icon={<Bot />} label="Bots" active={section === 'bots'} onClick={() => setSection('bots')} />
        <RailButton icon={<Users />} label="群组" active={section === 'groups'} onClick={() => setSection('groups')} />
        <RailButton icon={<Radio />} label="频道" active={section === 'channels'} onClick={() => setSection('channels')} />
        <RailButton icon={<Phone />} label="通话" active={section === 'calls'} onClick={() => setSection('calls')} />
        <RailButton icon={<Bookmark />} label="收藏" active={section === 'saved'} onClick={() => void ensureSavedMessages()} />
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
                <span className={styles.peerMeta}>{peer.pinned ? <Pin size={12} /> : null}{mutedPeerKeys.has(peer.key) ? <BellOff size={12} /> : null}{peer.unread ? <b>{peer.unread}</b> : null}</span>
              </button>
            ))}
            {!visiblePeers.length ? <EmptyList section={section} /> : null}
          </div>
        ) : (
          <SectionPanel section={section} onOpenMiniApp={openMiniApp} onInvoice={() => void createInvoiceForActivePeer()} />
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
                {activePeer.source === 'selfhosted' ? <button type="button" title="发送账单" onClick={() => void createInvoiceForActivePeer()}><WalletCards size={18} /></button> : null}
                <button type="button" title="搜索当前会话" data-active={conversationSearchOpen} onClick={() => setConversationSearchOpen((value) => !value)}><Search size={18} /></button>
                <button type="button" title={activePeer.pinned ? '取消置顶' : '置顶'} onClick={() => void togglePinConversation(activePeer)}><Pin size={18} /></button>
                <button type="button" title={mutedPeerKeys.has(activePeer.key) ? '开启通知' : '静音'} onClick={() => void toggleMuteConversation(activePeer)}><BellOff size={18} /></button>
                <button type="button" title="资料" data-active={infoOpen} onClick={() => setInfoOpen((value) => !value)}><MoreVertical size={18} /></button>
              </div>
            </header>
            {conversationSearchOpen ? <label className={styles.inChatSearch}><Search size={15} /><input placeholder="在当前会话中搜索" autoFocus /><button type="button" onClick={() => setConversationSearchOpen(false)}><X size={14} /></button></label> : null}
            {error ? <div className={styles.errorBanner} role="alert"><span>{error}</span><button type="button" onClick={() => setError(null)}><X size={14} /></button></div> : null}
            <div className={styles.messageArea}>
              <div className={styles.dayDivider}>今天</div>
              {messages.map((message) => (
                <article
                  key={`${message.source}:${message.id}`}
                  className={message.role === 'me' ? styles.messageMine : styles.messagePeer}
                  onContextMenu={(event) => {
                    event.preventDefault();
                    event.stopPropagation();
                    setMessageMenu({ message, x: event.clientX, y: event.clientY });
                  }}
                >
                  {message.pinned ? <Pin size={11} /> : null}
                  <p>{message.text}</p>
                  {message.reactions?.length ? <div className={extra.reactions}>{message.reactions.map((reaction) => <span key={reaction}>{reaction}</span>)}</div> : null}
                  <small>{formatTime(message.createdAtMs)} {message.role === 'me' ? <Check size={12} /> : null}</small>
                </article>
              ))}
              {!messages.length ? <div className={styles.chatEmpty}><span className={styles.avatarLarge}>{avatarText(activePeer.title)}</span><strong>{activePeer.title}</strong><p>联系人、AI Bot、群组和频道使用同一个 Fabushi 消息产品层。</p></div> : null}
            </div>
            {replyTo ? <div className={extra.composerBanner}><Reply size={15} /><div><strong>回复</strong><span>{replyTo.text}</span></div><button type="button" onClick={() => setReplyTo(null)}><X size={14} /></button></div> : null}
            {scheduledAtMs ? <div className={extra.composerBanner}><span>⏱</span><div><strong>定时发送</strong><span>{new Date(scheduledAtMs).toLocaleString()}</span></div><button type="button" onClick={() => setScheduledAtMs(undefined)}><X size={14} /></button></div> : null}
            <form className={styles.composer} onSubmit={(event) => void sendMessage(event)}>
              <div className={extra.attachmentAnchor}>
                <button type="button" title="附件" onClick={() => setAttachmentMenuOpen((value) => !value)}><Paperclip size={20} /></button>
                {attachmentMenuOpen ? <AttachmentMenu onMedia={() => mediaInputRef.current?.click()} onFile={() => fileInputRef.current?.click()} onPoll={() => void sendPoll()} onLocation={() => void sendLocation()} onSchedule={() => {
                  const minutes = Number(window.prompt('多少分钟后发送？', '10'));
                  if (Number.isFinite(minutes) && minutes > 0) setScheduledAtMs(Date.now() + minutes * 60_000);
                  setAttachmentMenuOpen(false);
                }} /> : null}
              </div>
              <input ref={mediaInputRef} type="file" accept="image/*,video/*" hidden onChange={(event) => { const file = event.currentTarget.files?.[0]; event.currentTarget.value = ''; if (file) void sendAttachmentFile(file); }} />
              <input ref={fileInputRef} type="file" hidden onChange={(event) => { const file = event.currentTarget.files?.[0]; event.currentTarget.value = ''; if (file) void sendAttachmentFile(file); }} />
              {attachmentProgress ? <span className={extra.uploadProgress}>{attachmentProgress}</span> : null}
              <textarea data-testid="messenger-input" value={composer} onChange={(event) => setComposer(event.target.value)} onKeyDown={(event) => { if (event.key === 'Enter' && !event.shiftKey) { event.preventDefault(); event.currentTarget.form?.requestSubmit(); } }} placeholder="消息" rows={1} />
              <button type="button" title="表情"><Smile size={20} /></button>
              <button type="button" data-active={silentSend} title={silentSend ? '关闭静默发送' : '静默发送'} onClick={() => setSilentSend((value) => !value)}><BellOff size={19} /></button>
              {composer.trim() ? <button data-testid="messenger-send" className={styles.sendButton} type="submit" disabled={!hostReady || pendingSend}><Send size={19} /></button> : <button type="button" title="语音消息"><Mic size={20} /></button>}
            </form>
          </>
        ) : (
          <FeatureWorkspace section={section} onOpenMiniApp={openMiniApp} onInvoice={() => void createInvoiceForActivePeer()} />
        )}
      </section>

      {infoOpen && activePeer && sectionIsPeerList ? (
        <aside className={styles.infoPanel}>
          <header><strong>资料</strong><button type="button" onClick={() => setInfoOpen(false)}><X size={17} /></button></header>
          <div className={styles.profileCard}>
            <span className={styles.avatarHuge}>{avatarText(activePeer.title)}</span>
            <strong>{activePeer.title}</strong><small>{activePeer.subtitle}</small>
            <div><button type="button" onClick={() => void startCall('voice')}><PhoneCall size={18} /><span>通话</span></button><button type="button" onClick={() => void startCall('video')}><Video size={18} /><span>视频</span></button><button type="button" onClick={() => setConversationSearchOpen(true)}><Search size={18} /><span>搜索</span></button></div>
          </div>
          <div className={styles.profileActions}>
            <button type="button" onClick={() => void toggleMuteConversation(activePeer)}><BellOff size={17} /><span>{mutedPeerKeys.has(activePeer.key) ? '开启通知' : '静音通知'}</span></button>
            <button type="button" onClick={() => void togglePinConversation(activePeer)}><Pin size={17} /><span>{activePeer.pinned ? '取消置顶' : '置顶会话'}</span></button>
            <button type="button" onClick={() => { void toggleArchiveConversation(activePeer); setSection('archive'); }}><Archive size={17} /><span>{activePeer.archived ? '移出归档' : '归档会话'}</span></button>
          </div>
          <nav className={styles.infoTabs}><button type="button" data-active={infoTab === 'media'} onClick={() => setInfoTab('media')}>媒体</button><button type="button" data-active={infoTab === 'files'} onClick={() => setInfoTab('files')}>文件</button><button type="button" data-active={infoTab === 'links'} onClick={() => setInfoTab('links')}>链接</button></nav>
          <div className={styles.infoContent}>{infoTab === 'media' ? <><Image size={30} /><strong>共享媒体</strong><p>图片、视频和动画按消息索引展示。</p></> : null}{infoTab === 'files' ? <><FileText size={30} /><strong>共享文件</strong><p>文档、音频和附件由 Rust 媒体层管理。</p></> : null}{infoTab === 'links' ? <><Link2 size={30} /><strong>共享链接</strong><p>富文本 URL 建立可搜索索引。</p></> : null}</div>
        </aside>
      ) : null}

      {messageMenu ? <MessageContextMenu menu={messageMenu} onAction={(action) => void handleMessageAction(action)} /> : null}
      {forwardDialog ? <ForwardMessageDialog message={forwardDialog.message} peers={peers.filter((peer) => peer.source === 'selfhosted' && Boolean(peer.conversationId) && peer.conversationId !== forwardDialog.sourceConversationId)} onClose={() => setForwardDialog(null)} onSelect={(peer) => void forwardToPeer(peer)} /> : null}
      {newDialog ? <NewConversationDialog dialog={newDialog} bots={bots} onChange={setNewDialog} onClose={() => setNewDialog(null)} onSave={() => void saveNewDialog()} /> : null}
      {localCall ? <CallDialog call={localCall} videoRef={localVideoRef} onEnd={endCall} /> : null}
      {miniApp ? <MiniAppDialog app={miniApp} onClose={() => setMiniApp(null)} /> : null}
    </main>
  );
}

function RailButton({ icon, label, active, onClick }: { icon: React.ReactNode; label: string; active: boolean; onClick: () => void }) {
  return <button type="button" data-active={active} onClick={onClick} title={label}><span>{icon}</span><small>{label}</small></button>;
}

function EmptyList({ section }: { section: MessengerSection }) {
  return <div className={styles.emptyList}><MessageCircle size={27} /><strong>暂无{sectionTitle(section)}</strong><p>新建会话后会显示在这里。</p></div>;
}

function AttachmentMenu({ onMedia, onFile, onPoll, onLocation, onSchedule }: { onMedia: () => void; onFile: () => void; onPoll: () => void; onLocation: () => void; onSchedule: () => void }) {
  return <div className={extra.popover} onClick={(event) => event.stopPropagation()}>
    <button type="button" onClick={onMedia}><Image size={17} />图片或视频</button>
    <button type="button" onClick={onFile}><FileText size={17} />文件</button>
    <button type="button" onClick={onPoll}><span>📊</span>投票</button>
    <button type="button" onClick={onLocation}><MapPin size={17} />位置</button>
    <button type="button" onClick={onSchedule}><span>⏱</span>定时发送</button>
  </div>;
}

function MessageContextMenu({ menu, onAction }: { menu: NonNullable<MessageMenu>; onAction: (action: 'copy' | 'reply' | 'forward' | 'edit' | 'delete' | 'react' | 'pin') => void }) {
  return <div className={extra.contextMenu} style={{ left: menu.x, top: menu.y }} onClick={(event) => event.stopPropagation()}>
    <button type="button" onClick={() => onAction('reply')}><Reply size={16} />回复</button>
    <button type="button" onClick={() => onAction('copy')}><Copy size={16} />复制</button>
    <button type="button" onClick={() => onAction('react')}><Smile size={16} />👍 反应</button>
    {menu.message.role === 'me' ? <button type="button" onClick={() => onAction('edit')}><Edit3 size={16} />编辑</button> : null}
    <button type="button" onClick={() => onAction('pin')}><Pin size={16} />{menu.message.pinned ? '取消置顶' : '置顶'}</button>
    <button type="button" onClick={() => onAction('forward')}><Forward size={16} />转发</button>
    <button type="button" onClick={() => onAction('delete')}><Trash2 size={16} />删除</button>
  </div>;
}

function ForwardMessageDialog({ message, peers, onClose, onSelect }: { message: DisplayMessage; peers: PeerItem[]; onClose: () => void; onSelect: (peer: PeerItem) => void }) {
  return <div className={styles.backdrop} onMouseDown={onClose}><section className={styles.dialog} onMouseDown={(event) => event.stopPropagation()}>
    <header><div><strong>转发消息</strong><small>{message.text || '媒体消息'}</small></div><button type="button" onClick={onClose}><X size={17} /></button></header>
    <div className={extra.forwardList}>
      {peers.length ? peers.map((peer) => <button key={peer.key} type="button" onClick={() => onSelect(peer)}><span className={styles.avatar}>{avatarText(peer.title)}</span><span><strong>{peer.title}</strong><small>{peer.subtitle}</small></span><Forward size={16} /></button>) : <p>暂无可转发的自建会话，请先创建群组、频道或收藏消息。</p>}
    </div>
  </section></div>;
}

function NewConversationDialog({ dialog, bots, onChange, onClose, onSave }: { dialog: Exclude<NewDialog, null>; bots: BotSummary[]; onChange: React.Dispatch<React.SetStateAction<NewDialog>>; onClose: () => void; onSave: () => void }) {
  return <div className={styles.backdrop} onMouseDown={onClose}><section className={styles.dialog} onMouseDown={(event) => event.stopPropagation()}>
    <header><div><strong>{dialog.type === 'group' ? '新建群组' : '新建频道'}</strong><small>{dialog.type === 'group' ? '现有 AI 群组 Host 会执行 Bot 多轮协作' : 'Fabushi 自建广播会话'}</small></div><button type="button" onClick={onClose}><X size={17} /></button></header>
    <label><span>名称</span><input autoFocus value={dialog.name} onChange={(event) => onChange((current) => current ? { ...current, name: event.target.value } : current)} placeholder={dialog.type === 'group' ? '群组名称' : '频道名称'} /></label>
    {dialog.type === 'channel' ? <label><span>描述</span><textarea value={dialog.description} onChange={(event) => onChange((current) => current?.type === 'channel' ? { ...current, description: event.target.value } : current)} rows={3} placeholder="频道简介" /></label> : null}
    {dialog.type === 'group' ? <div className={styles.memberPicker}><span>选择 AI Bot</span>{bots.map((bot) => {
      const selected = dialog.selectedBotIds.has(bot.id);
      return <button key={bot.id} type="button" data-selected={selected} onClick={() => onChange((current) => {
        if (!current || current.type !== 'group') return current;
        const selectedBotIds = new Set(current.selectedBotIds);
        if (selectedBotIds.has(bot.id)) selectedBotIds.delete(bot.id); else selectedBotIds.add(bot.id);
        return { ...current, selectedBotIds };
      })}><span className={styles.avatarSmall}>{avatarText(bot.name)}</span><div><strong>{bot.name}</strong><small>{bot.description}</small></div>{selected ? <Check size={16} /> : <Plus size={16} />}</button>;
    })}</div> : null}
    <footer><button type="button" onClick={onClose}>取消</button><button type="button" className={styles.primaryButton} disabled={!dialog.name.trim()} onClick={onSave}>{dialog.type === 'group' ? '创建群组' : '创建频道'}</button></footer>
  </section></div>;
}

function CallDialog({ call, videoRef, onEnd }: { call: LocalCall; videoRef: React.RefObject<HTMLVideoElement | null>; onEnd: () => void }) {
  return <div className={styles.backdrop}><section className={styles.callDialog}><header><span className={styles.avatarHuge}>{avatarText(call.title)}</span><strong>{call.title}</strong><small>{call.status === 'requesting' ? '正在请求麦克风/摄像头…' : call.status === 'ready' ? `${call.kind === 'video' ? '视频' : '语音'}媒体已准备` : '无法启动本机媒体'}</small></header>{call.kind === 'video' && call.status === 'ready' ? <video ref={videoRef} muted playsInline className={styles.localVideo} /> : null}{call.error ? <p>{call.error}</p> : null}<div className={styles.callActions}><button type="button"><Mic size={20} /></button>{call.kind === 'video' ? <button type="button"><Video size={20} /></button> : null}<button type="button" className={styles.hangup} onClick={onEnd}><Phone size={21} /></button></div><p className={styles.callNote}>本机 WebRTC 采集已启用；Rust realtime 已定义 Invite/SDP/ICE/群组通话状态，远端 SFU/TURN 传输仍需生产部署。</p></section></div>;
}

function MiniAppDialog({ app, onClose }: { app: { id: string; html?: string }; onClose: () => void }) {
  return <div className={styles.backdrop} onMouseDown={onClose}><section className={styles.miniAppDialog} onMouseDown={(event) => event.stopPropagation()}><header><div><strong>{defaultMiniApps.find((item) => item.id === app.id)?.title ?? app.id}</strong><small>Mini App · 受控宿主容器</small></div><button type="button" onClick={onClose}><X size={17} /></button></header>{app.html ? <iframe title={app.id} sandbox="allow-scripts allow-forms" srcDoc={app.html} /> : <div className={styles.miniAppEmpty}><AppWindow size={38} /><strong>Mini App 已由 Host 打开</strong><p>生产构建将使用受控页面/WebView 容器。</p></div>}</section></div>;
}

function SectionPanel({ section, onOpenMiniApp, onInvoice }: { section: MessengerSection; onOpenMiniApp: (id: string) => Promise<void>; onInvoice: () => void }) {
  if (section === 'miniapps') return <div className={styles.sectionList}>{defaultMiniApps.map((app) => <button type="button" key={app.id} onClick={() => void onOpenMiniApp(app.id)}><span className={styles.appIcon}><AppWindow size={18} /></span><div><strong>{app.title}</strong><small>{app.description}</small></div></button>)}</div>;
  if (section === 'payments') return <div className={styles.sectionList}><div className={styles.panelHint}><WalletCards size={24} /><strong>Fabushi Pay</strong><p>Invoice/Order/Wallet/Entitlement 已由 Rust 自建域管理。</p></div><button type="button" onClick={onInvoice}><ShoppingBag size={17} /><div><strong>在当前会话创建账单</strong><small>账单会作为消息发送</small></div></button></div>;
  if (section === 'folders') return <div className={styles.sectionList}><div className={styles.panelHint}><Folder size={24} /><strong>聊天文件夹</strong><p>按联系人、Bot、群组、频道、未读和静音状态组织。</p></div></div>;
  if (section === 'calls') return <div className={styles.sectionList}><div className={styles.panelHint}><Phone size={24} /><strong>最近通话</strong><p>从会话顶部发起语音/视频。</p></div></div>;
  return <div className={styles.sectionList}><div className={styles.panelHint}><Settings size={24} /><strong>{sectionTitle(section)}</strong><p>该功能入口已合并进统一 Messenger。</p></div></div>;
}

function FeatureWorkspace({ section, onOpenMiniApp, onInvoice }: { section: MessengerSection; onOpenMiniApp: (id: string) => Promise<void>; onInvoice: () => void }) {
  if (section === 'miniapps') return <div className={styles.featureWorkspace}><AppWindow size={54} /><h2>Mini Apps</h2><p>Mini App 与 Bot、会话、支付共享身份和权限上下文。</p><div className={styles.featureGrid}>{defaultMiniApps.map((app) => <button type="button" key={app.id} onClick={() => void onOpenMiniApp(app.id)}><AppWindow size={22} /><strong>{app.title}</strong><small>{app.description}</small></button>)}</div></div>;
  if (section === 'payments') return <div className={styles.featureWorkspace}><WalletCards size={54} /><h2>Fabushi Pay</h2><p>支付不依赖 Telegram Payments；账单、订单和权益都由 Fabushi Rust 域管理。</p><button type="button" className={styles.primaryButton} onClick={onInvoice}><ShoppingBag size={17} />在当前会话创建账单</button></div>;
  if (section === 'calls') return <div className={styles.featureWorkspace}><Phone size={54} /><h2>通话</h2><p>本机媒体已接通，Rust realtime 已具备一对一/群组通话信令状态。</p></div>;
  return <div className={styles.featureWorkspace}><MessageCircle size={54} /><h2>{sectionTitle(section)}</h2><p>联系人、Bot、群组和频道正在统一到同一个 Fabushi Actor/Conversation 模型。</p></div>;
}
