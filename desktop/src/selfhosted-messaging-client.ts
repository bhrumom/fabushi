import type { RuntimeCommand, RuntimeEvent } from '../../frontend/apps/web/src/lib/mahayana-host/contracts';
import type { MahayanaHostTransport } from '../../frontend/apps/web/src/lib/mahayana-host/transport';

export const FABUSHI_MESSAGING_PROTOCOL_VERSION = 1 as const;

export type MessagingActorKind = 'human' | 'assistant' | 'bot' | 'service';
export type MessagingConversationKind = 'direct' | 'group' | 'channel' | 'savedMessages' | 'secret';
export type MessagingParticipantRole = 'owner' | 'admin' | 'member' | 'restricted';

export interface MessagingActor {
  id: string;
  kind: MessagingActorKind;
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
  role: MessagingParticipantRole;
  joinedAtMs: number;
  mutedUntilMs?: number;
}

export interface MessagingConversation {
  id: string;
  kind: MessagingConversationKind;
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

export type MessagingTextContent = {
  type: 'text';
  data: {
    text: {
      text: string;
      entities: Array<unknown>;
    };
  };
};

export interface MessagingRequestContext {
  requestId: string;
  deviceId: string;
  actorId: string;
  sessionId: string;
  sentAtMs: number;
}

export interface MessagingClientEnvelope {
  protocolVersion: typeof FABUSHI_MESSAGING_PROTOCOL_VERSION;
  context: MessagingRequestContext;
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

function bridgeCommand(requestId: string, envelope: MessagingClientEnvelope): RuntimeCommand {
  return {
    type: 'messaging.execute',
    requestId,
    envelope,
  } as unknown as RuntimeCommand;
}

export function isMessagingHostEvent(event: RuntimeEvent): event is RuntimeEvent & MessagingHostEvent {
  return (event as { type?: string }).type === 'messaging.event';
}

export class SelfHostedMessagingClient {
  readonly actorId: string;
  readonly deviceId: string;
  readonly sessionId: string;
  private readonly transport: MahayanaHostTransport;

  constructor(
    transport: MahayanaHostTransport,
    options: {
      actorId?: string;
      deviceId?: string;
      sessionId?: string;
    } = {},
  ) {
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

  async ensureCurrentActor(displayName = '当前用户'): Promise<void> {
    const actor: MessagingActor = {
      id: this.actorId,
      kind: 'human',
      displayName,
      capabilities: ['messages', 'groups', 'channels', 'calls', 'payments', 'miniApps'],
      presence: {
        status: 'online',
        lastSeenAtMs: Date.now(),
      },
      verified: false,
    };
    await this.execute({ type: 'upsertProfile', actor });
  }

  async sync(limit = 500): Promise<void> {
    await this.execute({ type: 'sync', cursor: null, limit });
  }

  async createChannel(title: string, description = ''): Promise<MessagingConversation> {
    const now = Date.now();
    const safeTitle = title.trim();
    if (!safeTitle) throw new Error('频道名称不能为空');
    await this.ensureCurrentActor();
    const conversation: MessagingConversation = {
      id: `channel:${crypto.randomUUID()}`,
      kind: 'channel',
      title: safeTitle,
      description: description.trim() || undefined,
      participants: [
        {
          actorId: this.actorId,
          role: 'owner',
          joinedAtMs: now,
        },
      ],
      ownerId: this.actorId,
      unreadCount: 0,
      mentionCount: 0,
      pinnedMessageIds: [],
      notificationSettings: {
        showPreview: true,
        notifyMentions: true,
      },
      permissions: {
        canSendMessages: true,
        canSendMedia: true,
        canSendPolls: true,
        canAddMembers: true,
        canPinMessages: true,
        canManageTopics: true,
        canManageCalls: true,
      },
      historyVisibility: 'allMembers',
      topics: [],
      folderIds: [],
      archived: false,
      pinned: false,
      markedUnread: false,
      createdAtMs: now,
      updatedAtMs: now,
    };
    await this.execute({ type: 'createConversation', conversation });
    return conversation;
  }

  async sendText(conversationId: string, text: string): Promise<void> {
    const trimmed = text.trim();
    if (!trimmed) return;
    await this.ensureCurrentActor();
    await this.execute({
      type: 'sendMessage',
      conversationId,
      clientMessageId: `desktop:${crypto.randomUUID()}`,
      content: {
        type: 'text',
        data: {
          text: {
            text: trimmed,
            entities: [],
          },
        },
      } satisfies MessagingTextContent,
      replyToMessageId: null,
      threadRootMessageId: null,
      scheduledAtMs: null,
      silent: false,
      protectedContent: false,
    });
  }

  async editText(conversationId: string, messageId: string, text: string): Promise<void> {
    await this.execute({
      type: 'editMessage',
      conversationId,
      messageId,
      content: {
        type: 'text',
        data: { text: { text, entities: [] } },
      } satisfies MessagingTextContent,
    });
  }

  async deleteMessages(conversationId: string, messageIds: string[], forEveryone = true): Promise<void> {
    await this.execute({
      type: 'deleteMessages',
      conversationId,
      messageIds,
      forEveryone,
    });
  }

  async markRead(conversationId: string, messageId: string): Promise<void> {
    await this.execute({ type: 'markRead', conversationId, messageId });
  }

  async setReaction(
    conversationId: string,
    messageId: string,
    reaction: string,
    count = 1,
  ): Promise<void> {
    await this.execute({
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

  async pinMessage(conversationId: string, messageId: string, pinned: boolean): Promise<void> {
    await this.execute({ type: 'pinMessage', conversationId, messageId, pinned });
  }

  async createInvoice(input: {
    conversationId: string;
    id?: string;
    title: string;
    description?: string;
    currency: string;
    amountMinor: number;
    providerId: string;
  }): Promise<string> {
    await this.ensureCurrentActor();
    const id = input.id ?? `invoice:${crypto.randomUUID()}`;
    await this.execute({
      type: 'createInvoice',
      invoice: {
        id,
        conversationId: input.conversationId,
        sellerId: this.actorId,
        title: input.title,
        description: input.description ?? '',
        kind: 'oneTime',
        currency: input.currency.toUpperCase(),
        prices: [
          {
            label: input.title,
            amount: {
              currency: input.currency.toUpperCase(),
              amountMinor: input.amountMinor,
            },
          },
        ],
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
    return id;
  }
}
