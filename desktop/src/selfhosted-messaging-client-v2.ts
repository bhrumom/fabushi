import type { RuntimeCommand, RuntimeEvent } from '../../frontend/apps/web/src/lib/mahayana-host/contracts';
import type { MahayanaHostTransport } from '../../frontend/apps/web/src/lib/mahayana-host/transport';

export const FABUSHI_MESSAGING_PROTOCOL_VERSION = 1 as const;

export type ActorKind = 'human' | 'assistant' | 'bot' | 'service';
export type ConversationKind = 'direct' | 'group' | 'channel' | 'savedMessages' | 'secret';
export type ParticipantRole = 'owner' | 'admin' | 'member' | 'restricted';

export interface MessagingActor {
  id: string;
  kind: ActorKind;
  displayName: string;
  username?: string;
  avatarUrl?: string;
  bio?: string;
  capabilities: string[];
  presence: {
    status: 'offline' | 'online' | 'away' | 'doNotDisturb';
    lastSeenAtMs?: number;
    statusText?: string;
  };
  verified: boolean;
}

export interface MessagingParticipant {
  actorId: string;
  role: ParticipantRole;
  joinedAtMs: number;
  mutedUntilMs?: number;
}

export interface MessagingConversation {
  id: string;
  kind: ConversationKind;
  title: string;
  description?: string;
  avatarUrl?: string;
  participants: MessagingParticipant[];
  ownerId?: string;
  lastMessageId?: string;
  lastReadMessageId?: string;
  unreadCount: number;
  mentionCount: number;
  pinnedMessageIds: string[];
  notificationSettings: {
    mutedUntilMs?: number;
    sound?: string;
    showPreview: boolean;
    notifyMentions: boolean;
  };
  permissions: {
    canSendMessages: boolean;
    canSendMedia: boolean;
    canSendPolls: boolean;
    canAddMembers: boolean;
    canPinMessages: boolean;
    canManageTopics: boolean;
    canManageCalls: boolean;
  };
  historyVisibility: 'newMembersOnly' | 'allMembers';
  topics: Array<{
    id: string;
    title: string;
    icon?: string;
    createdBy: string;
    closed: boolean;
    hidden: boolean;
  }>;
  folderIds: string[];
  archived: boolean;
  pinned: boolean;
  markedUnread: boolean;
  createdAtMs: number;
  updatedAtMs: number;
}

export interface MessagingMessage {
  id: string;
  conversationId: string;
  senderId: string;
  content: Record<string, unknown> & { type: string };
  replyToMessageId?: string;
  threadRootMessageId?: string;
  forwardOrigin?: string;
  reactions: Array<{
    reaction: string;
    count: number;
    chosenByMe: boolean;
    recentActorIds: string[];
  }>;
  deliveryState: Record<string, unknown> & { state: string };
  createdAtMs: number;
  editedAtMs?: number;
  scheduledAtMs?: number;
  silent: boolean;
  protectedContent: boolean;
  pinned: boolean;
  deleted: boolean;
}

export interface MessagingClientEnvelope {
  protocolVersion: typeof FABUSHI_MESSAGING_PROTOCOL_VERSION;
  context: {
    requestId: string;
    deviceId: string;
    actorId: string;
    sessionId: string;
    sentAtMs: number;
  };
  command: Record<string, unknown> & { type: string };
}

export interface MessagingServerEnvelope {
  protocolVersion: typeof FABUSHI_MESSAGING_PROTOCOL_VERSION;
  cursor?: string;
  serverTimeMs: number;
  event: Record<string, unknown> & { type: string };
}

export interface MessagingHostEvent {
  type: 'messaging.event';
  timestamp: string;
  requestId: string;
  envelope: MessagingServerEnvelope;
}

export type MessagingContent =
  | { type: 'text'; data: { text: { text: string; entities: unknown[] } } }
  | {
      type: 'poll';
      data: {
        question: { text: string; entities: unknown[] };
        options: Array<{ id: string; text: string; voterCount: number; chosen: boolean; correct?: boolean }>;
        anonymous: boolean;
        multipleAnswers: boolean;
        quiz: boolean;
      };
    }
  | { type: 'contact'; data: { actorId?: string; displayName: string; phoneNumber?: string } }
  | { type: 'location'; data: { latitude: number; longitude: number; liveUntilMs?: number } }
  | { type: 'invoice'; data: { invoiceId: string } }
  | { type: 'miniApp'; data: { miniAppId: string; title: string; startParameter?: string } };

export function asMessagingHostEvent(event: RuntimeEvent): MessagingHostEvent | null {
  const candidate = event as unknown as MessagingHostEvent;
  return candidate.type === 'messaging.event' ? candidate : null;
}

export function messagingText(message: MessagingMessage): string {
  if (message.deleted) return '消息已删除';
  if (message.content.type === 'text') {
    const data = message.content.data as { text?: { text?: string } } | undefined;
    return data?.text?.text ?? '';
  }
  if (message.content.type === 'poll') {
    const data = message.content.data as { question?: { text?: string } } | undefined;
    return `📊 ${data?.question?.text ?? '投票'}`;
  }
  if (message.content.type === 'location') return '📍 位置';
  if (message.content.type === 'contact') return '👤 联系人';
  if (message.content.type === 'invoice') return '🧾 账单';
  if (message.content.type === 'miniApp') return '▣ Mini App';
  return `[${message.content.type}]`;
}

function bridgeCommand(requestId: string, envelope: MessagingClientEnvelope): RuntimeCommand {
  return { type: 'messaging.execute', requestId, envelope } as unknown as RuntimeCommand;
}

function defaultPermissions() {
  return {
    canSendMessages: true,
    canSendMedia: true,
    canSendPolls: true,
    canAddMembers: true,
    canPinMessages: true,
    canManageTopics: true,
    canManageCalls: true,
  };
}

export class SelfHostedMessagingClientV2 {
  readonly actorId: string;
  readonly deviceId: string;
  readonly sessionId: string;
  private readonly transport: MahayanaHostTransport;

  constructor(transport: MahayanaHostTransport, options: { actorId?: string; deviceId?: string; sessionId?: string } = {}) {
    this.transport = transport;
    this.actorId = options.actorId ?? 'human:desktop:current';
    this.deviceId = options.deviceId ?? 'desktop:electron';
    this.sessionId = options.sessionId ?? `messenger:${Date.now().toString(36)}`;
  }

  async execute(command: MessagingClientEnvelope['command']): Promise<void> {
    const requestId = `messaging-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const envelope: MessagingClientEnvelope = {
      protocolVersion: FABUSHI_MESSAGING_PROTOCOL_VERSION,
      context: {
        requestId,
        deviceId: this.deviceId,
        actorId: this.actorId,
        sessionId: this.sessionId,
        sentAtMs: Date.now(),
      },
      command,
    };
    await this.transport.execute(bridgeCommand(requestId, envelope));
  }

  async ensureActor(actor: MessagingActor): Promise<void> {
    await this.execute({ type: 'upsertProfile', actor });
  }

  async ensureCurrentActor(displayName = '当前用户'): Promise<void> {
    await this.ensureActor({
      id: this.actorId,
      kind: 'human',
      displayName,
      capabilities: ['messages', 'groups', 'channels', 'calls', 'payments', 'miniApps'],
      presence: { status: 'online', lastSeenAtMs: Date.now() },
      verified: false,
    });
  }

  async sync(limit = 1000): Promise<void> {
    await this.execute({ type: 'sync', cursor: null, limit });
  }

  async createConversation(kind: ConversationKind, title: string, description = '', participantActorIds: string[] = []): Promise<MessagingConversation> {
    await this.ensureCurrentActor();
    const now = Date.now();
    const id = `${kind}:${crypto.randomUUID()}`;
    const participantIds = [this.actorId, ...participantActorIds.filter((id) => id !== this.actorId)];
    const conversation: MessagingConversation = {
      id,
      kind,
      title: title.trim(),
      description: description.trim() || undefined,
      participants: participantIds.map((actorId, index) => ({
        actorId,
        role: index === 0 ? 'owner' : 'member',
        joinedAtMs: now,
      })),
      ownerId: this.actorId,
      unreadCount: 0,
      mentionCount: 0,
      pinnedMessageIds: [],
      notificationSettings: { showPreview: true, notifyMentions: true },
      permissions: defaultPermissions(),
      historyVisibility: 'allMembers',
      topics: [],
      folderIds: [],
      archived: false,
      pinned: false,
      markedUnread: false,
      createdAtMs: now,
      updatedAtMs: now,
    };
    if (!conversation.title) throw new Error('会话名称不能为空');
    await this.execute({ type: 'createConversation', conversation });
    return conversation;
  }

  createChannel(title: string, description = ''): Promise<MessagingConversation> {
    return this.createConversation('channel', title, description);
  }

  createGroup(title: string, participantActorIds: string[] = []): Promise<MessagingConversation> {
    return this.createConversation('group', title, '', participantActorIds);
  }

  async ensureSavedMessages(): Promise<MessagingConversation> {
    await this.ensureCurrentActor();
    const now = Date.now();
    const conversation: MessagingConversation = {
      id: `saved:${this.actorId}`,
      kind: 'savedMessages',
      title: '收藏消息',
      participants: [{ actorId: this.actorId, role: 'owner', joinedAtMs: now }],
      ownerId: this.actorId,
      unreadCount: 0,
      mentionCount: 0,
      pinnedMessageIds: [],
      notificationSettings: { showPreview: true, notifyMentions: false },
      permissions: defaultPermissions(),
      historyVisibility: 'allMembers',
      topics: [],
      folderIds: [],
      archived: false,
      pinned: true,
      markedUnread: false,
      createdAtMs: now,
      updatedAtMs: now,
    };
    await this.execute({ type: 'createConversation', conversation });
    return conversation;
  }

  async sendContent(
    conversationId: string,
    content: MessagingContent,
    options: {
      replyToMessageId?: string;
      threadRootMessageId?: string;
      scheduledAtMs?: number;
      silent?: boolean;
      protectedContent?: boolean;
    } = {},
  ): Promise<void> {
    await this.ensureCurrentActor();
    await this.execute({
      type: 'sendMessage',
      conversationId,
      clientMessageId: `desktop:${crypto.randomUUID()}`,
      content,
      replyToMessageId: options.replyToMessageId ?? null,
      threadRootMessageId: options.threadRootMessageId ?? null,
      scheduledAtMs: options.scheduledAtMs ?? null,
      silent: options.silent ?? false,
      protectedContent: options.protectedContent ?? false,
    });
  }

  sendText(conversationId: string, text: string, options: Parameters<SelfHostedMessagingClientV2['sendContent']>[2] = {}): Promise<void> {
    const trimmed = text.trim();
    if (!trimmed) return Promise.resolve();
    return this.sendContent(
      conversationId,
      { type: 'text', data: { text: { text: trimmed, entities: [] } } },
      options,
    );
  }

  sendPoll(conversationId: string, question: string, optionTexts: string[], anonymous = true, multipleAnswers = false): Promise<void> {
    const options = optionTexts.map((text, index) => ({
      id: `option:${index + 1}`,
      text: text.trim(),
      voterCount: 0,
      chosen: false,
    })).filter((option) => option.text);
    if (!question.trim() || options.length < 2) throw new Error('投票至少需要一个问题和两个选项');
    return this.sendContent(conversationId, {
      type: 'poll',
      data: {
        question: { text: question.trim(), entities: [] },
        options,
        anonymous,
        multipleAnswers,
        quiz: false,
      },
    });
  }

  async editText(conversationId: string, messageId: string, text: string): Promise<void> {
    await this.execute({
      type: 'editMessage',
      conversationId,
      messageId,
      content: { type: 'text', data: { text: { text, entities: [] } } },
    });
  }

  deleteMessages(conversationId: string, messageIds: string[], forEveryone = true): Promise<void> {
    return this.execute({ type: 'deleteMessages', conversationId, messageIds, forEveryone });
  }

  markRead(conversationId: string, messageId: string): Promise<void> {
    return this.execute({ type: 'markRead', conversationId, messageId });
  }

  setReaction(conversationId: string, messageId: string, reaction: string, count = 1): Promise<void> {
    return this.execute({
      type: 'setReaction',
      conversationId,
      messageId,
      reaction: {
        reaction,
        count,
        chosenByMe: count > 0,
        recentActorIds: count > 0 ? [this.actorId] : [],
      },
    });
  }

  pinMessage(conversationId: string, messageId: string, pinned: boolean): Promise<void> {
    return this.execute({ type: 'pinMessage', conversationId, messageId, pinned });
  }

  archiveConversation(conversationId: string, archived: boolean): Promise<void> {
    return this.execute({ type: 'archiveConversation', conversationId, archived });
  }

  pinConversation(conversationId: string, pinned: boolean): Promise<void> {
    return this.execute({ type: 'pinConversation', conversationId, pinned });
  }

  setConversationNotifications(conversationId: string, mutedUntilMs?: number): Promise<void> {
    return this.execute({
      type: 'setConversationNotifications',
      conversationId,
      settings: {
        mutedUntilMs: mutedUntilMs ?? null,
        sound: null,
        showPreview: true,
        notifyMentions: true,
      },
    });
  }

  async createInvoice(input: {
    conversationId: string;
    title: string;
    description?: string;
    currency: string;
    amountMinor: number;
    providerId: string;
  }): Promise<string> {
    await this.ensureCurrentActor();
    const id = `invoice:${crypto.randomUUID()}`;
    const currency = input.currency.toUpperCase();
    await this.execute({
      type: 'createInvoice',
      invoice: {
        id,
        conversationId: input.conversationId,
        sellerId: this.actorId,
        title: input.title,
        description: input.description ?? '',
        kind: 'oneTime',
        currency,
        prices: [{ label: input.title, amount: { currency, amountMinor: input.amountMinor } }],
        payload: id,
        providerId: input.providerId,
        requestName: false,
        requestEmail: false,
        requestPhone: false,
        requestShippingAddress: false,
        flexibleShipping: false,
        createdAtMs: Date.now(),
      },
    });
    await this.sendContent(input.conversationId, { type: 'invoice', data: { invoiceId: id } });
    return id;
  }
}
