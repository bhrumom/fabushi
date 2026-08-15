// Vendored from the user's Grok Bot 0.16.0 group-chat core.
// Imports that named Grok host tool constants are inlined with their original values.

const SAND_BOX_SHELL_TOOL_NAME = "Shell";
const SAND_BOX_READ_TOOL_NAME = "Read";
const SAND_BOX_AWAIT_SHELL_TOOL_NAME = "AwaitShell";
const SAND_EXTERNAL_SHELL_TOOL_NAME = "ExternalShell";
const SAND_EXTERNAL_READ_TOOL_NAME = "ExternalRead";
const SAND_EXTERNAL_AWAIT_SHELL_TOOL_NAME = "AwaitExternalShell";
export const SAND_HIDDEN_PROMPT_MARKER = "[SAND_HIDDEN_PROMPT]";

export const GROUP_CONFIG_VERSION = 1;

export interface SandGroupRemoteMember {
  readonly ownerAuthId: string;
  readonly agentId: string;
  readonly name: string;
  readonly avatarDataUrl?: string;
}

export interface SandGroupConfig {
  readonly version: number;
  readonly memberIds: readonly string[];
  readonly remoteMembers?: readonly SandGroupRemoteMember[];
  readonly sharedRoomId?: string;
}

export interface SandGroupMember {
  readonly id: string;
  readonly name: string;
  readonly description: string;
}

export type SandGroupSpeaker =
  | { readonly kind: "user"; readonly name?: string }
  | { readonly kind: "member"; readonly id: string; readonly name: string };

export interface SandGroupMessage {
  readonly speaker: SandGroupSpeaker;
  readonly content: string;
}

export interface SandGroupIdentity {
  readonly name: string;
  readonly description: string;
}

export const GROUP_MAX_MEMBER_TURNS = 10;
export const GROUP_MAX_ROUNDS = 3;
export const GROUP_PROMPT_HISTORY_LIMIT = 24;
export const GROUP_MAX_MESSAGES_PER_TURN = 2;
export const SHARED_ROOM_HISTORY_LIMIT = 24;

export function orderRoundSpeakers(memberIds: readonly string[], round: number): readonly string[] {
  if (memberIds.length === 0) return [];
  const offset = ((round % memberIds.length) + memberIds.length) % memberIds.length;
  return [...memberIds.slice(offset), ...memberIds.slice(0, offset)];
}

export function isSameMemberSet(a: readonly string[], b: readonly string[]): boolean {
  if (a.length !== b.length) return false;
  const set = new Set(a);
  for (const id of b) {
    if (!set.has(id)) return false;
  }
  return true;
}

export class SandGroupNestingError extends Error {
  readonly nestedGroupIds: readonly string[];
  constructor(nestedGroupIds: readonly string[]) {
    super(
      "A group chat can only contain individual agents, not other group chats. " +
        `Remove the group chat${nestedGroupIds.length === 1 ? "" : "s"} from the member list.`,
    );
    this.name = "SandGroupNestingError";
    this.nestedGroupIds = [...nestedGroupIds];
  }
}

export function assertMembersAreNotGroups(
  requestedMemberIds: readonly string[],
  isGroupId: (id: string) => boolean,
): void {
  const nested = [...new Set(requestedMemberIds)].filter(isGroupId);
  if (nested.length > 0) throw new SandGroupNestingError(nested);
}

export interface SandGroupMentionTargets {
  readonly isEveryone: boolean;
  readonly memberIds: readonly string[];
}

function memberMentionHandles(name: string): readonly string[] {
  const lower = name.trim().toLowerCase();
  if (lower.length === 0) return [];
  const handles = new Set<string>([lower, lower.replace(/\s+/g, "")]);
  const first = lower.split(/\s+/)[0];
  if (first != null && first.length > 0) handles.add(first);
  return [...handles];
}

const EVERYONE_MENTION = /(?:^|[^a-z0-9])@(everyone|all)\b/;

function isWordChar(char: string | undefined): boolean {
  return char !== undefined && /[a-z0-9]/.test(char);
}

function hasMentionAt(lower: string, handle: string): boolean {
  const needle = `@${handle}`;
  let index = lower.indexOf(needle);
  while (index >= 0) {
    const before = lower[index - 1];
    const after = lower[index + needle.length];
    if (!isWordChar(before) && !isWordChar(after)) return true;
    index = lower.indexOf(needle, index + 1);
  }
  return false;
}

export function parseGroupMentions(
  text: string,
  members: readonly { readonly id: string; readonly name: string }[],
): SandGroupMentionTargets {
  const lower = text.toLowerCase();
  const isEveryone = EVERYONE_MENTION.test(lower);
  const memberIds: string[] = [];
  const seen = new Set<string>();
  for (const member of members) {
    if (seen.has(member.id)) continue;
    for (const handle of memberMentionHandles(member.name)) {
      if (hasMentionAt(lower, handle)) {
        memberIds.push(member.id);
        seen.add(member.id);
        break;
      }
    }
  }
  return { isEveryone, memberIds };
}

export function resolveResponders(
  members: readonly SandGroupMember[],
  history: readonly SandGroupMessage[],
): readonly SandGroupMember[] {
  let start = 0;
  for (let index = history.length - 1; index >= 0; index--) {
    if (history[index]?.speaker.kind === "user") {
      start = index;
      break;
    }
  }
  let isEveryone = false;
  const mentioned = new Set<string>();
  for (const message of history.slice(start)) {
    const targets = parseGroupMentions(message.content, members);
    if (targets.isEveryone) isEveryone = true;
    for (const id of targets.memberIds) mentioned.add(id);
  }
  if (isEveryone || mentioned.size === 0) return members;
  return members.filter((member) => mentioned.has(member.id));
}

export function isPassContent(content: string): boolean {
  const trimmed = content.trim();
  if (trimmed.length === 0) return true;
  return /^\(?\s*pass\s*\)?\.?$/i.test(trimmed);
}

export function isPotentialPassPrefix(text: string): boolean {
  const trimmed = text.trim();
  if (trimmed.length === 0) return true;
  if (isPassContent(trimmed)) return true;
  return /^\(?\s*(?:p(?:a(?:s(?:s\s*\)?\.?)?)?)?)?$/i.test(trimmed);
}

export function buildGroupRedriveNote(): string {
  return [
    "",
    "(Redelivery: your previous attempt at this turn was interrupted by a direct message to you. The room has NOT seen any reply from you for the messages above — anything you said or did while handling that direct message stayed in that private chat. If you already did the work, send the result to this room with SendMessage now; otherwise take the turn normally.)",
  ].join("\n");
}

function formatGroupLine(message: SandGroupMessage, viewerId: string): string {
  if (message.speaker.kind === "user") {
    return message.speaker.name != null && message.speaker.name.length > 0
      ? `${message.speaker.name} (user): ${message.content}`
      : `User: ${message.content}`;
  }
  const suffix = message.speaker.id === viewerId ? " (you)" : "";
  return `${message.speaker.name}${suffix}: ${message.content}`;
}

export function formatGroupHistory(
  history: readonly SandGroupMessage[],
  viewerId: string,
  limit: number = GROUP_PROMPT_HISTORY_LIMIT,
): string {
  const recent = history.slice(-limit);
  if (recent.length === 0) return "(no messages yet)";
  return recent.map((message) => formatGroupLine(message, viewerId)).join("\n");
}

export const GROUP_CHAT_TAG_PREFIX = "[Group chat: ";

export function isGroupTurnPromptText(text: string): boolean {
  const body = text.startsWith(SAND_HIDDEN_PROMPT_MARKER)
    ? text.slice(SAND_HIDDEN_PROMPT_MARKER.length)
    : text;
  return body.startsWith(GROUP_CHAT_TAG_PREFIX);
}

function groupDisplayName(group: SandGroupIdentity): string {
  return group.name.trim().length > 0 ? group.name.trim() : "the group";
}

function describeGroup(group: SandGroupIdentity): string {
  const name = groupDisplayName(group);
  const description = group.description.trim();
  return description.length > 0 ? `"${name}" — ${description}` : `"${name}"`;
}

export function formatGroupChatTag(
  group: SandGroupIdentity,
  peers: readonly SandGroupMember[],
): string {
  const withClause = peers.length > 0 ? ` - with ${peers.map((peer) => peer.name).join(", ")}` : "";
  return `${GROUP_CHAT_TAG_PREFIX}"${groupDisplayName(group)}"${withClause}]`;
}

export function buildGroupMemberSystemPrompt(
  member: SandGroupMember,
  group: SandGroupIdentity,
  peers: readonly SandGroupMember[],
  options: { readonly isSharedRoom?: boolean } = {},
): string {
  const lines = [
    `You are ${member.name}, one participant in a group chat (${describeGroup(group)}).`,
  ];
  if (member.description.trim().length > 0) {
    lines.push(`Your persona: ${member.description.trim()}`);
  }
  if (peers.length > 0) {
    lines.push("", "Other participants in the room:");
    for (const peer of peers) {
      const peerDescription =
        peer.description.trim().length > 0 ? ` (${peer.description.trim()})` : "";
      lines.push(`- ${peer.name}${peerDescription}`);
    }
  }
  const roomRightNow =
    peers.length > 0
      ? `Right now you are speaking in this group chat, with ${peers
          .map((peer) => peer.name)
          .join(", ")}.`
      : "Right now you are speaking in this group chat.";
  lines.push("", roomRightNow);
  if (options.isSharedRoom === true) {
    lines.push(
      `This is a cross-user room turn, and you have your own user's machines in it: ${SAND_BOX_SHELL_TOOL_NAME}, ${SAND_BOX_READ_TOOL_NAME}, and ${SAND_BOX_AWAIT_SHELL_TOOL_NAME} on your own box, plus ${SAND_EXTERNAL_SHELL_TOOL_NAME}, ${SAND_EXTERNAL_READ_TOOL_NAME}, ${SAND_EXTERNAL_AWAIT_SHELL_TOOL_NAME} on your user's computer, and the read-only Screenshot. When the room asks for real work (debugging an issue, checking logs, running a command), do the work before you answer: tool calls and plain text are private scratch space the room never sees, so work first, then deliver the result with SendMessage — only its plain text is delivered to the room.`,
      "You still cannot access private 1:1 history, memory, web, connectors, subagents, cloud agents, or account actions here. Never claim or infer private context you don't have.",
    );
  } else {
    lines.push(
      `Your conversation history is unified across all your chats: it may include your private 1:1 DM with your user and your turns in other group chats. Every group-chat turn is tagged like ${GROUP_CHAT_TAG_PREFIX}"..."]; an untagged user message is from your private DM. Only this room sees what you send now.`,
      "",
      "You have your full toolkit in this room — the same Shell, box, web, MCP connector, subagent, and cloud-agent tools as your private chat, with no reduced limits. When the conversation calls for real work (looking something up, running a command, checking a connected service), do the work before you answer: tool calls and plain text are private scratch space the room never sees, so work first, then deliver the result with SendMessage. Never claim you lack a tool or can't do something here that you could do in your 1:1 chat.",
      "Your history in this room is long-lived, so an MCP tool's schema may have drifted since you last used it. If a connector call fails or comes back suspiciously empty, refetch its descriptor with GetMcpTools and compare: if it changed, rebuild the arguments from the fresh schema and retry; if not, treat the call as broken rather than retrying blindly. Before re-running anything that writes (posting a message, creating an issue), read back whether it already took effect so you don't double-fire.",
    );
  }
  lines.push(
    "",
    "Several distinct participants share this room. Stay fully in character as " +
      `${member.name}. Never speak or write as another participant or as the user, and never narrate the conversation from the outside.`,
    "",
    "How you talk in the room:",
    "- The ONLY way to say something the room can see is the SendMessage tool. Plain assistant text is invisible scratch space, so a turn with no SendMessage means you stayed silent.",
    "- Keep each message short and conversational — usually one to three sentences, the way people actually chat. Do not monologue or summarize the whole thread.",
    "- React to what was just said: build on it, agree, disagree, or ask a pointed question. Address others by name when it helps.",
    "- Mentions: write @Name to direct your message at a specific teammate, or @everyone for the whole room. If you are @-mentioned you are being asked to weigh in, so respond; to pull a specific teammate into the conversation, @-mention them.",
    "- Do not repeat points already made, and do not restate other people's messages back to them.",
    `- If you have nothing new worth adding right now, send exactly "(pass)". Staying quiet is good — it lets the conversation settle instead of spinning forever.`,
    "- Say your piece in one turn, then stop. Never role-play other participants' replies.",
    "",
    "Conversations are private to the people in them: what you and the user discuss in your one-on-one chat stays there. Never quote, summarize, or reveal it in this room, and never go looking for a teammate's private chats, memory, or files.",
  );
  return lines.join("\n");
}

export function messagesSinceMemberLastSpoke(
  history: readonly SandGroupMessage[],
  memberId: string,
): readonly SandGroupMessage[] {
  for (let index = history.length - 1; index >= 0; index--) {
    const speaker = history[index]?.speaker;
    if (speaker?.kind === "member" && speaker.id === memberId) {
      return history.slice(index + 1);
    }
  }
  return history;
}

export interface BuildGroupTurnPromptArgs {
  readonly member: SandGroupMember;
  readonly group: SandGroupIdentity;
  readonly peers: readonly SandGroupMember[];
  readonly newMessages: readonly SandGroupMessage[];
}

export function buildGroupTurnPrompt(args: BuildGroupTurnPromptArgs): string {
  const { member, group, peers, newMessages } = args;
  const lines: string[] = [formatGroupChatTag(group, peers)];
  if (newMessages.length === 0) {
    lines.push("No new messages in the room since your last turn.");
  } else {
    lines.push("New messages in the room (oldest first):");
    lines.push(formatGroupHistory(newMessages, member.id));
  }
  lines.push(
    "",
    `It's your turn, ${member.name}. Reply in character with a single SendMessage if you have something worth adding, or send "(pass)" if you don't.`,
  );
  return lines.join("\n");
}
