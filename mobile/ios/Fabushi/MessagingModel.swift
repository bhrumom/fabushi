import Foundation
import Observation

internal enum ConversationKind: String, Identifiable, Sendable {
    case direct
    case group
    case channel
    case savedMessages
    case secret

    var id: String { rawValue }
    var label: String {
        switch self {
        case .direct: "私聊"
        case .group: "群组"
        case .channel: "频道"
        case .savedMessages: "收藏"
        case .secret: "加密聊天"
        }
    }
}

internal struct ConversationSummary: Identifiable, Equatable, Sendable {
    let id: String
    var title: String
    var preview: String
    var time: String
    var badge: String
    var kind: ConversationKind
    var unreadCount: Int
    var isPinned: Bool
    var isMuted: Bool
    var isArchived: Bool
    var lastMessageId: String?
}

internal struct MessagingContact: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let username: String?
    let kind: String
}

internal struct ChatMessage: Identifiable, Equatable, Sendable {
    let id: String
    let conversationId: String
    let text: String
    let isOutgoing: Bool
    let time: String
}

@MainActor
@Observable
final class MessagingModel {
    private(set) var conversations: [ConversationSummary] = []
    private(set) var contacts: [MessagingContact] = []
    private(set) var messagesByConversation: [String: [ChatMessage]] = [:]
    private(set) var typingActorByConversation: [String: String] = [:]
    private(set) var loading = false
    private(set) var errorMessage: String?

    private let host: MahayanaHost
    private var actorId = ""
    private var displayName = "当前用户"
    private let deviceId = "ios:native"
    private let sessionId = "account-session:ios-native"

    init(host: MahayanaHost) {
        self.host = host
    }

    func refresh() async {
        loading = true
        defer { loading = false }
        do {
            try await ensureIdentity()
            _ = try await execute(command: ["type": "sync", "cursor": NSNull(), "limit": 1000])
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createDirect(contact: MessagingContact) async throws -> ConversationSummary? {
        try await ensureIdentity()
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let id = "direct:\(UUID().uuidString.lowercased())"
        let participants: [[String: Any]] = [
            ["actorId": actorId, "role": "owner", "joinedAtMs": now, "mutedUntilMs": NSNull()],
            ["actorId": contact.id, "role": "member", "joinedAtMs": now, "mutedUntilMs": NSNull()],
        ]
        let conversation = conversationPayload(id: id, kind: .direct, title: contact.displayName, description: "", participants: participants, now: now)
        _ = try await execute(command: ["type": "createConversation", "conversation": conversation])
        return conversations.first(where: { $0.id == id })
    }

    func createConversation(kind: ConversationKind, title: String, description: String = "") async throws -> ConversationSummary? {
        guard kind == .group || kind == .channel else {
            throw MahayanaHost.HostError.requestFailed("私聊请从联系人列表发起")
        }
        try await ensureIdentity()
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let id = "\(kind.rawValue):\(UUID().uuidString.lowercased())"
        let participants: [[String: Any]] = [["actorId": actorId, "role": "owner", "joinedAtMs": now, "mutedUntilMs": NSNull()]]
        let conversation = conversationPayload(id: id, kind: kind, title: title.trimmingCharacters(in: .whitespacesAndNewlines), description: description, participants: participants, now: now)
        _ = try await execute(command: ["type": "createConversation", "conversation": conversation])
        return conversations.first(where: { $0.id == id })
    }

    func sendText(conversationId: String, text: String, replyToMessageId: String? = nil) async throws {
        try await ensureIdentity()
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        _ = try await execute(command: [
            "type": "sendMessage",
            "conversationId": conversationId,
            "clientMessageId": "ios:\(UUID().uuidString.lowercased())",
            "content": ["type": "text", "data": ["text": ["text": value, "entities": []]]],
            "replyToMessageId": replyToMessageId ?? NSNull(),
            "threadRootMessageId": NSNull(),
            "scheduledAtMs": NSNull(),
            "silent": false,
            "protectedContent": false,
        ])
    }

    func setPinned(_ conversationId: String, pinned: Bool) async {
        try? await executeAfterIdentity(["type": "pinConversation", "conversationId": conversationId, "pinned": pinned])
    }

    func setArchived(_ conversationId: String, archived: Bool) async {
        try? await executeAfterIdentity(["type": "archiveConversation", "conversationId": conversationId, "archived": archived])
    }

    func setMuted(_ conversationId: String, muted: Bool) async {
        let until: Any = muted ? Int64.max / 4 : NSNull()
        try? await executeAfterIdentity([
            "type": "setConversationNotifications",
            "conversationId": conversationId,
            "settings": ["mutedUntilMs": until, "sound": NSNull(), "showPreview": true, "notifyMentions": true],
        ])
    }

    func markRead(_ conversationId: String) async {
        guard let last = conversations.first(where: { $0.id == conversationId })?.lastMessageId else { return }
        try? await executeAfterIdentity(["type": "markRead", "conversationId": conversationId, "messageId": last])
    }

    func editText(conversationId: String, messageId: String, text: String) async throws {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        try await executeAfterIdentity([
            "type": "editMessage",
            "conversationId": conversationId,
            "messageId": messageId,
            "content": ["type": "text", "data": ["text": ["text": value, "entities": []]]],
        ])
    }

    func deleteMessage(conversationId: String, messageId: String, forEveryone: Bool = true) async {
        try? await executeAfterIdentity(["type": "deleteMessages", "conversationId": conversationId, "messageIds": [messageId], "forEveryone": forEveryone])
    }

    func setReaction(conversationId: String, messageId: String, reaction: String, enabled: Bool) async {
        try? await ensureIdentity()
        try? await execute(command: [
            "type": "setReaction",
            "conversationId": conversationId,
            "messageId": messageId,
            "reaction": ["reaction": reaction, "count": enabled ? 1 : 0, "chosenByMe": enabled, "recentActorIds": enabled ? [actorId] : []],
        ])
    }

    func forwardMessage(sourceConversationId: String, messageId: String, destinationConversationId: String) async {
        try? await executeAfterIdentity([
            "type": "forwardMessage",
            "sourceConversationId": sourceConversationId,
            "messageId": messageId,
            "destinationConversationId": destinationConversationId,
            "clientMessageId": "ios:\(UUID().uuidString.lowercased())",
        ])
    }

    func startTyping(_ conversationId: String) async {
        try? await executeAfterIdentity(["type": "startTyping", "conversationId": conversationId, "action": "typing"])
    }

    func stopTyping(_ conversationId: String) async {
        try? await executeAfterIdentity(["type": "stopTyping", "conversationId": conversationId])
    }

    private func executeAfterIdentity(_ command: [String: Any]) async throws {
        try await ensureIdentity()
        _ = try await execute(command: command)
    }

    private func ensureIdentity() async throws {
        guard actorId.isEmpty else { return }
        let auth = try await host.request(method: "feature.auth.status")
        if let object = auth.value as? [String: Any], let user = object["user"] as? [String: Any] {
            displayName = (user["nickname"] as? String) ?? (user["username"] as? String) ?? displayName
        }
        let access = try await host.request(
            method: "feature.messaging.access.issue",
            params: ["deviceId": deviceId, "sessionId": sessionId, "scopes": ["messaging", "calls", "blobsRead", "blobsWrite", "payments", "miniApps"]]
        )
        guard let object = access.value as? [String: Any], let resolvedActor = object["actorId"] as? String, !resolvedActor.isEmpty else {
            throw MahayanaHost.HostError.invalidResponse
        }
        actorId = resolvedActor
        _ = try await execute(command: [
            "type": "upsertProfile",
            "actor": [
                "id": actorId,
                "kind": "human",
                "displayName": displayName,
                "username": NSNull(),
                "avatarUrl": NSNull(),
                "bio": NSNull(),
                "capabilities": ["messages", "groups", "channels", "calls", "payments", "miniApps"],
                "presence": ["status": "online", "lastSeenAtMs": Int64(Date().timeIntervalSince1970 * 1000), "statusText": NSNull()],
                "verified": false,
            ],
        ])
    }

    @discardableResult
    private func execute(command: [String: Any]) async throws -> [[String: Any]] {
        let requestId = "ios-messaging-\(UUID().uuidString.lowercased())"
        let envelope: [String: Any] = [
            "protocolVersion": 2,
            "context": [
                "requestId": requestId,
                "deviceId": deviceId,
                "actorId": actorId,
                "sessionId": sessionId,
                "sentAtMs": Int64(Date().timeIntervalSince1970 * 1000),
            ],
            "command": command,
        ]
        let result = try await host.request(method: "feature.messaging.execute", params: ["requestId": requestId, "envelope": envelope])
        guard let root = result.value as? [String: Any], let envelopes = root["envelopes"] as? [[String: Any]] else {
            throw MahayanaHost.HostError.invalidResponse
        }
        apply(envelopes)
        return envelopes
    }

    private func apply(_ envelopes: [[String: Any]]) {
        for envelope in envelopes {
            guard let event = envelope["event"] as? [String: Any], let type = event["type"] as? String else { continue }
            switch type {
            case "syncBatch":
                let rows = (event["conversations"] as? [[String: Any]] ?? []).compactMap(parseConversation)
                conversations = rows
                contacts = (event["actors"] as? [[String: Any]] ?? []).compactMap(parseContact)
                let messages = (event["messages"] as? [[String: Any]] ?? []).compactMap(parseMessage)
                messagesByConversation = Dictionary(grouping: messages, by: \.conversationId)
            case "conversationChanged":
                if let raw = event["conversation"] as? [String: Any], let conversation = parseConversation(raw) { upsert(conversation) }
            case "messageAdded", "messageChanged":
                if let raw = event["message"] as? [String: Any], let message = parseMessage(raw) {
                    var list = messagesByConversation[message.conversationId] ?? []
                    if let index = list.firstIndex(where: { $0.id == message.id }) { list[index] = message } else { list.append(message) }
                    messagesByConversation[message.conversationId] = list.sorted { $0.time < $1.time }
                }
            case "messagesDeleted":
                guard let id = event["conversationId"] as? String, let ids = event["messageIds"] as? [String] else { continue }
                messagesByConversation[id]?.removeAll { ids.contains($0.id) }
            case "typingChanged":
                guard let conversationId = event["conversationId"] as? String, let typingActorId = event["actorId"] as? String else { continue }
                if typingActorId == actorId || event["action"] is NSNull || event["action"] == nil {
                    typingActorByConversation.removeValue(forKey: conversationId)
                } else {
                    typingActorByConversation[conversationId] = contacts.first(where: { $0.id == typingActorId })?.displayName ?? "对方"
                }
            default:
                break
            }
        }
        hydratePreviews()
    }

    private func upsert(_ conversation: ConversationSummary) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) { conversations[index] = conversation }
        else { conversations.append(conversation) }
    }

    private func hydratePreviews() {
        for index in conversations.indices {
            let conversation = conversations[index]
            if let last = messagesByConversation[conversation.id]?.last {
                conversations[index].preview = last.text
                conversations[index].time = last.time
            }
        }
    }

    private func conversationPayload(id: String, kind: ConversationKind, title: String, description: String, participants: [[String: Any]], now: Int64) -> [String: Any] {
        [
            "id": id, "kind": kind.rawValue, "title": title,
            "description": description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NSNull() : description.trimmingCharacters(in: .whitespacesAndNewlines),
            "avatarUrl": NSNull(), "participants": participants, "ownerId": actorId,
            "lastMessageId": NSNull(), "lastReadMessageId": NSNull(), "unreadCount": 0, "mentionCount": 0, "pinnedMessageIds": [],
            "notificationSettings": ["mutedUntilMs": NSNull(), "sound": NSNull(), "showPreview": true, "notifyMentions": true],
            "permissions": ["canSendMessages": true, "canSendMedia": true, "canSendPolls": true, "canAddMembers": true, "canPinMessages": true, "canManageTopics": true, "canManageCalls": true],
            "historyVisibility": "allMembers", "topics": [], "folderIds": [], "archived": false, "pinned": false, "markedUnread": false,
            "createdAtMs": now, "updatedAtMs": now,
        ]
    }

    private func parseContact(_ raw: [String: Any]) -> MessagingContact? {
        guard let id = raw["id"] as? String, id != actorId, let name = raw["displayName"] as? String, !name.isEmpty else { return nil }
        return MessagingContact(id: id, displayName: name, username: raw["username"] as? String, kind: raw["kind"] as? String ?? "human")
    }

    private func parseConversation(_ raw: [String: Any]) -> ConversationSummary? {
        guard let id = raw["id"] as? String, let title = raw["title"] as? String else { return nil }
        let kind = ConversationKind(rawValue: raw["kind"] as? String ?? "direct") ?? .direct
        let mutedUntil = (raw["notificationSettings"] as? [String: Any])?["mutedUntilMs"] as? NSNumber
        let updatedAt = (raw["updatedAtMs"] as? NSNumber)?.int64Value ?? 0
        let initial = title.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "✦"
        return ConversationSummary(
            id: id,
            title: title,
            preview: (raw["description"] as? String) ?? "",
            time: Self.timeLabel(updatedAt),
            badge: initial,
            kind: kind,
            unreadCount: (raw["unreadCount"] as? NSNumber)?.intValue ?? 0,
            isPinned: raw["pinned"] as? Bool ?? false,
            isMuted: (mutedUntil?.int64Value ?? 0) > Int64(Date().timeIntervalSince1970 * 1000),
            isArchived: raw["archived"] as? Bool ?? false,
            lastMessageId: raw["lastMessageId"] as? String
        )
    }

    private func parseMessage(_ raw: [String: Any]) -> ChatMessage? {
        guard let id = raw["id"] as? String,
              let conversationId = raw["conversationId"] as? String,
              let senderId = raw["senderId"] as? String,
              let content = raw["content"] as? [String: Any]
        else { return nil }
        let text: String
        switch content["type"] as? String {
        case "text": text = (((content["data"] as? [String: Any])?["text"] as? [String: Any])?["text"] as? String) ?? ""
        case "photo": text = "🖼 图片"
        case "video": text = "🎬 视频"
        case "document": text = "📎 文件"
        case "location": text = "📍 位置"
        case "contact": text = "👤 联系人"
        case "invoice": text = "🧾 账单"
        case "miniApp": text = "▣ Mini App"
        default: text = "消息"
        }
        let createdAt = (raw["createdAtMs"] as? NSNumber)?.int64Value ?? 0
        return ChatMessage(id: id, conversationId: conversationId, text: text, isOutgoing: senderId == actorId, time: Self.timeLabel(createdAt))
    }

    private static func timeLabel(_ milliseconds: Int64) -> String {
        guard milliseconds > 0 else { return "" }
        let date = Date(timeIntervalSince1970: Double(milliseconds) / 1000)
        return date.formatted(date: .omitted, time: .shortened)
    }
}
