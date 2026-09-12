import type { ConversationSummary } from "./contracts";

export const MAHAYANA_ASSISTANT_CONVERSATION_ID = "mahayana-ai:agent:assistant";

export function ensureMahayanaAssistantConversation(
  conversations: ConversationSummary[],
  observedAtMs = Date.now(),
): ConversationSummary[] {
  if (conversations.some((conversation) => conversation.id === MAHAYANA_ASSISTANT_CONVERSATION_ID)) {
    return conversations;
  }
  return [
    {
      id: MAHAYANA_ASSISTANT_CONVERSATION_ID,
      title: "大乘助手",
      kind: "agent",
      pinned: false,
      unreadCount: 0,
      updatedAtMs: observedAtMs,
    },
    ...conversations,
  ];
}
