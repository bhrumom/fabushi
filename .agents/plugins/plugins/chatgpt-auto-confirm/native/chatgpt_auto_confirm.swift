import ApplicationServices
import Cocoa
import Darwin
import Foundation
import SystemConfiguration

private struct ApprovalRule: Codable {
  let id: String
  let application: String
  let action: String
  let resource: String
}

private struct AuditEvent: Codable {
  let at: String
  let decision: String
  let reason: String
  let clicked: Bool
  let ruleId: String?
  let buttonTitle: String
  let promptText: String
  let error: String?
}

private struct PluginState: Codable {
  var enabled = false
  var rules: [ApprovalRule] = []
  var approveAll: Bool?
  var chatTitles: [String]?
  var trackedChatURLs: [String]?
  var backgroundTargets: [String: String]?
  var backgroundAppPort: Int?
  var backgroundChatTargetId: String?
  var backgroundProfilePath: String?
  var backgroundConversationId: String?
  var intervalMs = 750
  var watcherPid: Int32?
  var startedAt: String?
  var lastError: String?
  var audit: [AuditEvent] = []
  var automationTasks: [AutomationTask]?
  var queueEnabled: Bool?
  var queuePaused: Bool?
  var queueMaxConcurrent: Int?
  var queueReviewGate: Bool?
  var queueWatcherPid: Int32?
  var queueRuntimeRevision: String?
  // The queue and general confirmer share one authenticated ChatGPT process.
  // The queue owns a hidden, never-shown prewarm BrowserWindow/renderer inside
  // that process and never navigates the primary window where the user types.
  var queueWorkerPort: Int?
  var queueWorkerTargetId: String?
  var queueWorkerProfilePath: String?
  var queueWorkerMode: String?
  // Reachability is queue-level state: a transient DNS/network/upstream
  // outage pauses the durable queue instead of terminating or duplicating
  // active Chat work.
  var queueNetworkStatus: String?
  var queueNetworkLastError: String?
  var queueNetworkFailureCount: Int?
  var queueNetworkWaitUntil: String?
}

private struct AutomationTaskReport: Codable {
  var protocolName: String
  var status: String
  var summary: String
  var completed: [String]
  var remaining: [String]
  var blockers: [String]
  var verification: [String]
  var nextTask: String
  // When an external job (for example, GitHub Actions) is still running, the
  // Chat ends with an incomplete report and asks the queue to come back later
  // instead of keeping a renderer and a model response idle.
  var waitSeconds: Int?
  var waitReason: String?
  // A finished Chat can choose the connector for the next fresh Chat. This
  // is useful when a local bhrum2 step has pushed code and the next step must
  // inspect GitHub Actions through the GitHub connector.
  var nextConnector: String?

  enum CodingKeys: String, CodingKey {
    case protocolName = "protocol"
    case status, summary, completed, remaining, blockers, verification
    case nextTask = "next_task"
    case waitSeconds = "wait_seconds"
    case waitReason = "wait_reason"
    case nextConnector = "next_connector"
  }
}

private struct AutomationTask: Codable {
  var id: String
  var title: String
  var prompt: String
  var promptTemplate: String
  var connector: String
  var dependsOn: [String]
  var resourceLocks: [String]
  var priority: Int
  var timeout: Int
  var maxTaskContinuations: Int
  var maxRuntimeRetries: Int
  var attempts: Int
  var reviewRound: Int
  var status: String
  var createdAt: String
  var updatedAt: String
  var startedAt: String?
  var finishedAt: String?
  var workerPid: Int32?
  var workerPort: Int?
  var workerTargetId: String?
  var workerStatePath: String?
  var workerProfilePath: String?
  var resultPath: String?
  var conversationId: String?
  var reviewConversationId: String?
  var reviewStatus: String?
  var reviewReport: AutomationTaskReport?
  var chatURL: String?
  var report: AutomationTaskReport?
  var lastResultJSON: String?
  var lastError: String?
  var reviewFeedback: String?
  var reviewedAt: String?
  var continuationDepth: Int?
  var reportFingerprints: [String]?
  var lastActivitySignature: String?
  var lastProgressAt: String?
  var waitingUntil: String?
  var waitReason: String?
  // Conversation is durable state; hidden renderer is only a recoverable worker.
  // These fields allow the queue to recover after a renderer disappears instead
  // of treating the task as failed.
  var hiddenWorkerLastHeartbeatAt: String? = nil
  var hiddenWorkerRecoveryCount: Int? = nil
  var hiddenWorkerLastError: String? = nil
}

private struct Candidate {
  let element: AXUIElement
  let promptText: String
  let buttonTitle: String
}

private let encoder: JSONEncoder = {
  let value = JSONEncoder()
  value.outputFormatting = [.sortedKeys]
  return value
}()
private let decoder = JSONDecoder()
private let isoFormatter = ISO8601DateFormatter()
private func jsonString(_ object: [String: Any]) -> String? {
  guard JSONSerialization.isValidJSONObject(object),
        let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
    return nil
  }
  return String(data: data, encoding: .utf8)
}
private let targetBundleIdentifiers = Set(["com.openai.codex", "com.openai.chat"])
private let verifiedApprovalMarker = "已验证授权卡消失"
private let pendingApprovalMarker = "AXPress 已发送，等待授权卡消失"
private func stateURL() -> URL {
  if let override = ProcessInfo.processInfo.environment["CHATGPT_AUTO_CONFIRM_STATE"],
     !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    return URL(fileURLWithPath: override)
  }
  return FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/Mahayana/plugins/chatgpt-auto-confirm")
    .appendingPathComponent("state.json")
}

private func loadState() -> PluginState {
  guard let data = try? Data(contentsOf: stateURL()),
        var state = try? decoder.decode(PluginState.self, from: data) else {
    return PluginState()
  }
  state.audit = state.audit.compactMap { event in
    let title = normalizedAXText(event.buttonTitle)
    guard isApprovalContext(event.promptText),
          title.isEmpty || isAllowButton(title: event.buttonTitle, context: event.promptText) else {
      return nil
    }
    let actionWasSent = event.clicked || event.error == "approval_still_present_after_ax_press"
    let migratedReason = event.error == "approval_still_present_after_ax_press"
      ? "\(event.reason)；\(pendingApprovalMarker)"
      : event.reason
    return AuditEvent(
      at: event.at,
      decision: event.decision,
      reason: migratedReason,
      clicked: actionWasSent,
      ruleId: event.ruleId,
      buttonTitle: event.buttonTitle,
      promptText: approvalAuditPrompt(event.promptText),
      error: event.error == "approval_still_present_after_ax_press" ? nil : event.error
    )
  }
  return state
}

private func saveState(_ state: PluginState) throws {
  let url = stateURL()
  try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  let data = try encoder.encode(state)
  try data.write(to: url, options: .atomic)
}

private func output(_ payload: [String: Any], exitCode: Int32 = 0) -> Never {
  let safePayload = sanitizeJSONValue(payload)
  guard JSONSerialization.isValidJSONObject(safePayload),
        let data = try? JSONSerialization.data(withJSONObject: safePayload, options: [.sortedKeys]) else {
    let fallback = Data("{\"errorCode\":\"json_encoding_failed\",\"message\":\"原生插件无法编码返回结果\",\"ok\":false}\n".utf8)
    FileHandle.standardOutput.write(fallback)
    Foundation.exit(1)
  }
  FileHandle.standardOutput.write(data)
  FileHandle.standardOutput.write(Data([0x0a]))
  Foundation.exit(exitCode)
}

private func emitProgress(_ payload: [String: Any]) {
  var event = payload
  event["event"] = event["event"] ?? "progress"
  let safePayload = sanitizeJSONValue(event)
  guard JSONSerialization.isValidJSONObject(safePayload),
        let data = try? JSONSerialization.data(withJSONObject: safePayload, options: [.sortedKeys]) else { return }
  FileHandle.standardOutput.write(data)
  FileHandle.standardOutput.write(Data([0x0a]))
}

private func stringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return "" }
  return value as? String ?? ""
}

private func boolAttribute(_ element: AXUIElement, _ attribute: CFString) -> Bool? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
  return value as? Bool
}

private func role(of element: AXUIElement) -> String {
  stringAttribute(element, kAXRoleAttribute as CFString)
}

private func accessibleString(_ element: AXUIElement) -> String {
  for attribute in [
    kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute, kAXValueAttribute,
  ] {
    let value = stringAttribute(element, attribute as CFString)
    if !value.isEmpty { return value }
  }
  return ""
}

private func normalizedAXText(_ text: String) -> String {
  text
    .lowercased()
    .split(whereSeparator: \.isWhitespace)
    .joined(separator: " ")
}

private func diagnosticStrings(_ element: AXUIElement) -> [String: String] {
  var values: [String: String] = [:]
  for (name, attribute) in [
    ("title", kAXTitleAttribute),
    ("description", kAXDescriptionAttribute),
    ("help", kAXHelpAttribute),
    ("value", kAXValueAttribute),
    ("identifier", kAXIdentifierAttribute),
    ("subrole", kAXSubroleAttribute),
  ] {
    let value = stringAttribute(element, attribute as CFString)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if !value.isEmpty { values[name] = String(value.prefix(1_000)) }
  }
  return values
}

private func children(of element: AXUIElement) -> [AXUIElement] {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(
    element,
    kAXChildrenAttribute as CFString,
    &value
  ) == .success else { return [] }
  return value as? [AXUIElement] ?? []
}

private func parent(of element: AXUIElement) -> AXUIElement? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(
    element,
    kAXParentAttribute as CFString,
    &value
  ) == .success,
    let value,
    CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
  return unsafeBitCast(value, to: AXUIElement.self)
}

private func descendants(of root: AXUIElement, matchingRole expectedRole: String) -> [AXUIElement] {
  var queue: [(AXUIElement, Int)] = [(root, 0)]
  var matches: [AXUIElement] = []
  var visited = Set<CFHashCode>()
  var cursor = 0
  while cursor < queue.count && cursor < 8_000 {
    let (element, depth) = queue[cursor]
    cursor += 1
    guard visited.insert(CFHash(element)).inserted else { continue }
    if role(of: element) == expectedRole { matches.append(element) }
    if depth < 40 { queue.append(contentsOf: children(of: element).map { ($0, depth + 1) }) }
  }
  return matches
}

private func allDescendants(of root: AXUIElement) -> [AXUIElement] {
  var queue: [(AXUIElement, Int)] = [(root, 0)]
  var values: [AXUIElement] = []
  var visited = Set<CFHashCode>()
  var cursor = 0
  while cursor < queue.count && cursor < 8_000 {
    let (element, depth) = queue[cursor]
    cursor += 1
    guard visited.insert(CFHash(element)).inserted else { continue }
    values.append(element)
    if depth < 40 { queue.append(contentsOf: children(of: element).map { ($0, depth + 1) }) }
  }
  return values
}

private func boundedDescendants(
  of root: AXUIElement,
  maximumNodes: Int = 600,
  maximumDepth: Int = 14
) -> [AXUIElement] {
  var queue: [(AXUIElement, Int)] = [(root, 0)]
  var values: [AXUIElement] = []
  var visited = Set<CFHashCode>()
  var cursor = 0
  while cursor < queue.count && cursor < maximumNodes {
    let (element, depth) = queue[cursor]
    cursor += 1
    guard visited.insert(CFHash(element)).inserted else { continue }
    values.append(element)
    if depth < maximumDepth {
      queue.append(contentsOf: children(of: element).map { ($0, depth + 1) })
    }
  }
  return values
}

private func nativeSearchElements(
  from root: AXUIElement,
  searchKey: String,
  text: String = "",
  limit: Int = 200
) -> [AXUIElement] {
  let parameters: [String: Any] = [
    "AXSearchKey": searchKey,
    "AXSearchText": text,
    "AXDirection": "AXDirectionNext",
    "AXImmediateDescendantsOnly": false,
    "AXResultsLimit": limit,
    // AXPress on a virtualized, hidden conversation can make ChatGPT restore
    // that conversation before dispatching the action. Hidden renderers are
    // handled through CDP instead; the compatibility path is intentionally
    // limited to elements that macOS reports as visible.
    "AXVisibleOnly": true,
  ]
  var value: CFTypeRef?
  guard AXUIElementCopyParameterizedAttributeValue(
    root,
    "AXUIElementsForSearchPredicate" as CFString,
    parameters as CFDictionary,
    &value
  ) == .success else { return [] }
  return value as? [AXUIElement] ?? []
}

private func searchedElements(
  in application: NSRunningApplication,
  searchKey: String,
  text: String = "",
  limit: Int = 200
) -> [AXUIElement] {
  let root = AXUIElementCreateApplication(application.processIdentifier)
  AXUIElementSetMessagingTimeout(root, 1.5)
  let direct = nativeSearchElements(from: root, searchKey: searchKey, text: text, limit: limit)
  if !direct.isEmpty { return direct }

  // Chromium exposes the predicate on its web areas rather than the application root.
  // Locating those hosts is deliberately bounded; page content is searched by the OS.
  var results: [AXUIElement] = []
  for element in boundedDescendants(of: root, maximumNodes: 350, maximumDepth: 12)
    where role(of: element) == "AXWebArea" {
    results.append(contentsOf: nativeSearchElements(
      from: element,
      searchKey: searchKey,
      text: text,
      limit: max(1, limit - results.count)
    ))
    if results.count >= limit { break }
  }
  return Array(results.prefix(limit))
}

private func actionNames(of element: AXUIElement) -> [String] {
  var names: CFArray?
  guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
  return names as? [String] ?? []
}

private func textContent(of root: AXUIElement, limit: Int = 350) -> String {
  var queue = [root]
  var cursor = 0
  var visited = Set<CFHashCode>()
  var seen = Set<String>()
  var fragments: [String] = []
  while cursor < queue.count && cursor < limit {
    let element = queue[cursor]
    cursor += 1
    guard visited.insert(CFHash(element)).inserted else { continue }
    let text = accessibleString(element).trimmingCharacters(in: .whitespacesAndNewlines)
    if !text.isEmpty && seen.insert(text).inserted { fragments.append(text) }
    queue.append(contentsOf: children(of: element))
  }
  return fragments.joined(separator: "\n")
}

private func closestApprovalContext(for element: AXUIElement) -> String? {
  var current = parent(of: element)
  for _ in 0..<20 {
    guard let container = current else { break }
    let context = textContent(of: container, limit: 220)
    if isStructurallyVerifiedApprovalButton(element, in: container, context: context) {
      return context
    }
    current = parent(of: container)
  }
  return nil
}

private func isApprovalContext(_ context: String) -> Bool {
  let normalized = normalizedAXText(context)
  let compact = normalized.replacingOccurrences(of: " ", with: "")
  let sharedDataPermission =
    (normalized.contains("the tool will execute") && normalized.contains("shared data")) ||
    compact.contains("共享的数据包括")
  if sharedDataPermission { return normalized.utf8.count <= 20_000 }
  guard normalized.utf8.count <= 3_000 else { return false }
  return normalized.contains("allow chatgpt to use") ||
    compact.contains("允许chatgpt使用")
}

private func approvalAuditPrompt(_ context: String) -> String {
  let normalized = normalizedAXText(context)
  if normalized.hasPrefix("allow chatgpt to use [approval details redacted] #") {
    return context
  }
  var hash: UInt64 = 14_695_981_039_346_656_037
  for byte in context.utf8 {
    hash ^= UInt64(byte)
    hash &*= 1_099_511_628_211
  }
  return "Allow ChatGPT to use [approval details redacted] #\(String(hash, radix: 16))"
}

private func isAllowButton(title: String, context: String) -> Bool {
  let normalizedTitle = normalizedAXText(title)
  let allowedTitles = [
    "allow", "allow once", "approve", "approve once", "confirm", "confirm once",
    "允许", "允许一次", "同意", "同意一次", "确认", "确认一次",
  ]
  return !context.isEmpty && allowedTitles.contains(normalizedTitle)
}

private func isRejectButton(title: String) -> Bool {
  [
    "deny", "reject", "cancel", "deny once", "reject once", "拒绝", "拒绝一次", "不允许",
    "不允许一次", "取消",
  ].contains(normalizedAXText(title))
}

private func isStructurallyVerifiedApprovalButton(
  _ element: AXUIElement,
  in container: AXUIElement,
  context: String
) -> Bool {
  guard role(of: element) == kAXButtonRole as String,
        actionNames(of: element).contains(kAXPressAction as String),
        !context.isEmpty else { return false }
  return verifiedApprovalButtons(in: container, context: context).contains {
    CFEqual($0, element)
  }
}

private func verifiedApprovalButtons(
  in container: AXUIElement,
  context: String
) -> [AXUIElement] {
  guard !context.isEmpty else { return [] }
  let buttons = boundedDescendants(
    of: container,
    maximumNodes: 400,
    maximumDepth: 12
  ).filter {
    role(of: $0) == kAXButtonRole as String &&
      actionNames(of: $0).contains(kAXPressAction as String)
  }
  guard buttons.contains(where: { isRejectButton(title: accessibleString($0)) }) else {
    return []
  }
  let explicitAllowButtons = buttons.filter {
    isAllowButton(title: accessibleString($0), context: context)
  }
  if !explicitAllowButtons.isEmpty { return explicitAllowButtons }

  // Some ChatGPT builds expose the white Allow button without an AX label.
  // Accept that shape only when this compact approval container has exactly
  // the reject button and one unlabeled companion button.
  guard buttons.count == 2,
        buttons.filter({ isRejectButton(title: accessibleString($0)) }).count == 1 else {
    return []
  }
  return buttons.filter { normalizedAXText(accessibleString($0)).isEmpty }
}

private func alreadyApproved(_ candidate: Candidate, in state: PluginState) -> Bool {
  let candidatePrompt = approvalAuditPrompt(candidate.promptText)
  return state.audit.reversed().contains { event in
    guard event.clicked,
          event.decision == "allow",
          event.buttonTitle == candidate.buttonTitle else { return false }
    guard event.promptText == candidatePrompt || event.promptText == candidate.promptText else { return false }
    guard let sentAt = isoFormatter.date(from: event.at) else { return false }
    return Date().timeIntervalSince(sentAt) < 15
  }
}

private func reconcilePendingApprovals(
  _ state: inout PluginState,
  activeCandidates: [Candidate]
) {
  let activePrompts = Set(activeCandidates.map { approvalAuditPrompt($0.promptText) })
  state.audit = state.audit.map { event in
    guard event.clicked,
          event.decision == "allow",
          event.reason.contains(pendingApprovalMarker),
          !event.reason.contains(verifiedApprovalMarker),
          !activePrompts.contains(event.promptText) else { return event }
    return AuditEvent(
      at: event.at,
      decision: event.decision,
      reason: "\(event.reason)；\(verifiedApprovalMarker)",
      clicked: true,
      ruleId: event.ruleId,
      buttonTitle: event.buttonTitle,
      promptText: event.promptText,
      error: nil
    )
  }
}

private func candidateStillPresent(_ candidate: Candidate) -> Bool {
  guard role(of: candidate.element) == kAXButtonRole as String,
        let context = closestApprovalContext(for: candidate.element),
        String(context.prefix(600)) == String(candidate.promptText.prefix(600)) else { return false }
  return true
}

private func waitForCandidateToDisappear(
  _ candidate: Candidate,
  timeout: TimeInterval
) -> Bool {
  let deadline = Date().addingTimeInterval(timeout)
  repeat {
    if !candidateStillPresent(candidate) { return true }
    Thread.sleep(forTimeInterval: 0.12)
  } while Date() < deadline
  return !candidateStillPresent(candidate)
}

private func containingWindow(of element: AXUIElement) -> AXUIElement? {
  var current: AXUIElement? = element
  for _ in 0..<40 {
    guard let node = current else { return nil }
    if role(of: node) == kAXWindowRole as String { return node }
    current = parent(of: node)
  }
  return nil
}

private func dismissHistoryOverlay(covering candidate: Candidate) -> Bool {
  guard let window = containingWindow(of: candidate.element) else { return false }
  let elements = boundedDescendants(
    of: window,
    maximumNodes: 1_800,
    maximumDepth: 32
  )
  let hasVisibleHistoryHeading = elements.contains { element in
    guard role(of: element) == kAXHeadingRole as String else { return false }
    let text = normalizedAXText(accessibleString(element))
    return text == "历史记录" || text == "history"
  }
  guard hasVisibleHistoryHeading else { return false }
  guard let toggle = elements.first(where: { element in
    guard role(of: element) == kAXButtonRole as String,
          actionNames(of: element).contains(kAXPressAction as String) else { return false }
    let text = normalizedAXText(accessibleString(element))
    return text.contains("查看聊天历史记录，当前聊天：") ||
      (text.contains("view chat history") && text.contains("current chat"))
  }) else { return false }
  return AXUIElementPerformAction(toggle, kAXPressAction as CFString) == .success
}

private func performApprovalClick(_ candidate: Candidate) -> (Bool, Bool, String?) {
  if boolAttribute(candidate.element, kAXEnabledAttribute as CFString) == false {
    return (false, false, "approval_button_disabled")
  }
  guard actionNames(of: candidate.element).contains(kAXPressAction as String) else {
    return (false, false, "approval_button_has_no_press_action")
  }
  let axError = AXUIElementPerformAction(candidate.element, kAXPressAction as CFString)
  guard axError == .success else {
    return (false, false, "ax_press_failed_\(axError.rawValue)")
  }
  if waitForCandidateToDisappear(candidate, timeout: 2.5) {
    return (true, true, nil)
  }
  if dismissHistoryOverlay(covering: candidate) {
    Thread.sleep(forTimeInterval: 0.4)
    if !candidateStillPresent(candidate) { return (true, true, nil) }
    let retryError = AXUIElementPerformAction(candidate.element, kAXPressAction as CFString)
    guard retryError == .success else {
      return (true, false, "ax_press_retry_failed_\(retryError.rawValue)")
    }
    if waitForCandidateToDisappear(candidate, timeout: 2.5) {
      return (true, true, nil)
    }
  }
  return (true, false, nil)
}

private func runningChatGptApplications() -> [NSRunningApplication] {
  NSWorkspace.shared.runningApplications.filter { application in
    guard !application.isTerminated else { return false }
    if let bundleIdentifier = application.bundleIdentifier,
       targetBundleIdentifiers.contains(bundleIdentifier) { return true }
    return application.localizedName?.caseInsensitiveCompare("ChatGPT") == .orderedSame
  }
}

private func pointAttribute(_ element: AXUIElement, _ attribute: CFString) -> CGPoint? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
        let value,
        CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
  let axValue = unsafeBitCast(value, to: AXValue.self)
  guard AXValueGetType(axValue) == .cgPoint else { return nil }
  var point = CGPoint.zero
  guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
  return point
}

private func sizeAttribute(_ element: AXUIElement, _ attribute: CFString) -> CGSize? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
        let value,
        CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
  let axValue = unsafeBitCast(value, to: AXValue.self)
  guard AXValueGetType(axValue) == .cgSize else { return nil }
  var size = CGSize.zero
  guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
  return size
}

private func frame(of element: AXUIElement) -> CGRect? {
  guard let origin = pointAttribute(element, kAXPositionAttribute as CFString),
        let size = sizeAttribute(element, kAXSizeAttribute as CFString) else { return nil }
  return CGRect(origin: origin, size: size)
}

private func focusedWindow(in application: NSRunningApplication) -> AXUIElement? {
  let root = AXUIElementCreateApplication(application.processIdentifier)
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(
    root,
    kAXFocusedWindowAttribute as CFString,
    &value
  ) == .success,
    let value,
    CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
  return unsafeBitCast(value, to: AXUIElement.self)
}

private func isActuallyVisible(
  _ element: AXUIElement,
  inside focusedWindow: AXUIElement
) -> Bool {
  if boolAttribute(element, "AXVisible" as CFString) == false { return false }
  guard let elementFrame = frame(of: element),
        let windowFrame = frame(of: focusedWindow),
        elementFrame.width > 1,
        elementFrame.height > 1,
        !elementFrame.intersection(windowFrame).isNull else { return false }

  var current: AXUIElement? = element
  for _ in 0..<40 {
    guard let node = current else { return false }
    if CFEqual(node, focusedWindow) { return true }
    if boolAttribute(node, "AXVisible" as CFString) == false { return false }
    current = parent(of: node)
  }
  return false
}

private func candidates() -> [Candidate] {
  var values: [Candidate] = []
  var seenButtons = Set<CFHashCode>()
  // Never AXPress a background ChatGPT process. Pressing an accessibility
  // element can activate its window, and virtualized hidden conversation
  // elements can restore an old route. Background and hidden work is handled
  // through the renderer IPC path without focusing or navigating the UI.
  for application in runningChatGptApplications() where application.isActive {
    guard let activeWindow = focusedWindow(in: application) else { continue }
    let root = AXUIElementCreateApplication(application.processIdentifier)
    AXUIElementSetMessagingTimeout(root, 1.5)
    var matchedElements: [AXUIElement] = []
    for term in ["Allow", "允许", "Approve", "Confirm", "同意", "确认"] {
      matchedElements.append(contentsOf: searchedElements(
        in: application,
        searchKey: "AXAnyTypeSearchKey",
        text: term,
        limit: 20
      ))
    }
    if matchedElements.isEmpty {
      matchedElements = boundedDescendants(
        of: root,
        maximumNodes: 500,
        maximumDepth: 18
      ).filter {
        let normalized = accessibleString($0).lowercased()
        return ["allow", "允许", "approve", "confirm", "同意", "确认"].contains {
          normalized.contains($0)
        }
      }
    }

    var approvalAnchors: [AXUIElement] = []
    for phrase in [
      "Allow ChatGPT to use", "允许 ChatGPT 使用",
      "Reject", "Deny", "拒绝", "不允许",
    ] {
      approvalAnchors.append(contentsOf: searchedElements(
        in: application,
        searchKey: "AXAnyTypeSearchKey",
        text: phrase,
        limit: 10
      ))
    }
    if approvalAnchors.isEmpty {
      approvalAnchors = boundedDescendants(
        of: root,
        maximumNodes: 1_800,
        maximumDepth: 28
      ).filter {
        let text = accessibleString($0)
        return isApprovalContext(text) || isRejectButton(title: text)
      }
    }

    var buttons: [AXUIElement] = []
    for element in matchedElements {
      var current: AXUIElement? = element
      for _ in 0..<5 {
        guard let candidate = current else { break }
        if role(of: candidate) == kAXButtonRole as String &&
            actionNames(of: candidate).contains(kAXPressAction as String) {
          if seenButtons.insert(CFHash(candidate)).inserted { buttons.append(candidate) }
          break
        }
        current = parent(of: candidate)
      }
    }

    // Some ChatGPT builds expose the white Allow button without an AX label.
    // Starting from either the approval heading or its Reject button finds that
    // unlabeled companion without inspecting or filtering the card contents.
    for anchor in approvalAnchors {
      var container: AXUIElement? = anchor
      for _ in 0..<12 {
        guard let node = container else { break }
        let context = textContent(of: node, limit: 220)
        let verifiedButtons = verifiedApprovalButtons(in: node, context: context)
        for candidate in verifiedButtons {
          if seenButtons.insert(CFHash(candidate)).inserted { buttons.append(candidate) }
        }
        if !verifiedButtons.isEmpty { break }
        container = parent(of: node)
      }
    }
    for button in buttons {
      guard values.count < 3,
            isActuallyVisible(button, inside: activeWindow),
            let context = closestApprovalContext(for: button) else { continue }
      let title = accessibleString(button)
      guard isAllowButton(title: title, context: context) ||
              normalizedAXText(title).isEmpty else { continue }
      values.append(Candidate(
        element: button,
        promptText: context,
        buttonTitle: title
      ))
    }
  }
  return values
}

private struct UnixIPCClient {
  static func socketPath() -> String {
    if let override = ProcessInfo.processInfo.environment["CHATGPT_AUTO_CONFIRM_UNIX_IPC"],
       !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return override.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".codex/ipc/ipc.sock").path
  }

  static func checkStatus() -> [String: Any] {
    let path = socketPath()
    guard FileManager.default.fileExists(atPath: path) else {
      return ["path": path, "available": false, "connected": false, "initialized": false]
    }
    let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
      return ["path": path, "available": true, "connected": false, "initialized": false, "error": "socket_create_failed"]
    }
    defer { Darwin.close(fd) }
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let pathBytes = path.utf8CString
    guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
      return ["path": path, "available": true, "connected": false, "initialized": false, "error": "path_too_long"]
    }
    withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
      let rawPtr = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
      for (index, byte) in pathBytes.enumerated() {
        rawPtr[index] = byte
      }
    }
    let connectRes = withUnsafePointer(to: &addr) { ptr in
      ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
        Darwin.connect(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    guard connectRes == 0 else {
      return ["path": path, "available": true, "connected": false, "initialized": false, "error": "connect_failed_\(errno)"]
    }

    var timeout = timeval(tv_sec: 1, tv_usec: 0)
    withUnsafePointer(to: &timeout) { timeoutPtr in
      Darwin.setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, timeoutPtr, socklen_t(MemoryLayout<timeval>.size))
      Darwin.setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, timeoutPtr, socklen_t(MemoryLayout<timeval>.size))
    }

    let initMsg: [String: Any] = [
      "jsonrpc": "2.0",
      "id": 1,
      "type": "request",
      "requestId": "req-init-status",
      "method": "initialize",
      "params": [
        "clientType": "chatgpt-auto-confirm",
        "protocolVersion": "2025-06-18",
        "clientInfo": ["name": "chatgpt-auto-confirm", "version": "0.1.0"],
        "capabilities": [:]
      ]
    ]
    guard let payloadData = try? JSONSerialization.data(withJSONObject: initMsg) else {
      return ["path": path, "available": true, "connected": true, "initialized": false, "error": "encode_failed"]
    }
    var lengthPrefix = UInt32(payloadData.count).littleEndian
    var sentHeader = false
    withUnsafePointer(to: &lengthPrefix) { ptr in
      let sent = Darwin.send(fd, ptr, MemoryLayout<UInt32>.size, 0)
      sentHeader = (sent == MemoryLayout<UInt32>.size)
    }
    guard sentHeader else {
      return ["path": path, "available": true, "connected": true, "initialized": false, "error": "send_header_failed"]
    }
    let sentPayload = payloadData.withUnsafeBytes { ptr -> Bool in
      guard let baseAddress = ptr.baseAddress else { return false }
      let sent = Darwin.send(fd, baseAddress, payloadData.count, 0)
      return sent == payloadData.count
    }
    guard sentPayload else {
      return ["path": path, "available": true, "connected": true, "initialized": false, "error": "send_payload_failed"]
    }

    var respLen: UInt32 = 0
    let headerRead = withUnsafeMutablePointer(to: &respLen) { ptr -> Bool in
      let readBytes = Darwin.recv(fd, ptr, MemoryLayout<UInt32>.size, 0)
      return readBytes == MemoryLayout<UInt32>.size
    }
    guard headerRead else {
      return ["path": path, "available": true, "connected": true, "initialized": false, "error": "recv_header_failed"]
    }
    let actualLen = Int(UInt32(littleEndian: respLen))
    guard actualLen > 0 && actualLen <= 1024 * 1024 else {
      return ["path": path, "available": true, "connected": true, "initialized": false, "error": "invalid_response_length"]
    }
    var respData = Data(count: actualLen)
    let payloadRead = respData.withUnsafeMutableBytes { ptr -> Bool in
      guard let baseAddress = ptr.baseAddress else { return false }
      var totalRead = 0
      while totalRead < actualLen {
        let n = Darwin.recv(fd, baseAddress.advanced(by: totalRead), actualLen - totalRead, 0)
        if n <= 0 { break }
        totalRead += n
      }
      return totalRead == actualLen
    }
    guard payloadRead,
          let json = try? JSONSerialization.jsonObject(with: respData) as? [String: Any] else {
      return ["path": path, "available": true, "connected": true, "initialized": false, "error": "recv_payload_failed"]
    }
    let isInitOk = json["id"] as? Int == 1 || json["result"] != nil || json["resultType"] as? String == "success"
    let clientId = ((json["result"] as? [String: Any])?["clientId"] as? String) ?? ""
    return [
      "path": path,
      "available": true,
      "connected": true,
      "initialized": isInitOk,
      "clientId": clientId,
      "protocol": "UInt32_LE_JSON",
      "note": "Unix IPC initialize 成功注册；云端审批 (chatgpt-tool-approval) 需通过 CDP/WebKit 内部桥接"
    ]
  }
}

private func jsonStringLiteral(_ value: String) -> String {
  var encoded = "\""
  for scalar in value.unicodeScalars {
    switch scalar.value {
    case 0x22: encoded += "\\\""
    case 0x5c: encoded += "\\\\"
    case 0x08: encoded += "\\b"
    case 0x0c: encoded += "\\f"
    case 0x0a: encoded += "\\n"
    case 0x0d: encoded += "\\r"
    case 0x09: encoded += "\\t"
    case 0x00...0x1f, 0x2028, 0x2029:
      encoded += String(format: "\\u%04x", scalar.value)
    default:
      encoded.unicodeScalars.append(scalar)
    }
  }
  encoded += "\""
  return encoded
}

private func cdpDebug(_ message: String) {
  guard ProcessInfo.processInfo.environment["CHATGPT_AUTO_CONFIRM_DEBUG"] == "1" else { return }
  FileHandle.standardError.write(Data("[chatgpt-auto-confirm] \(message)\n".utf8))
}

private func isChatGptRendererTarget(_ target: [String: Any]) -> Bool {
  guard target["type"] as? String == "page",
        (target["webSocketDebuggerUrl"] as? String) != nil else { return false }
  let url = target["url"] as? String ?? ""
  let title = (target["title"] as? String ?? "").lowercased()
  return url.contains("chatgpt.com") || title.contains("chatgpt")
}

private func isLoadedApprovalRendererTarget(_ target: [String: Any]) -> Bool {
  guard target["type"] as? String == "page",
        (target["webSocketDebuggerUrl"] as? String) != nil else { return false }
  let url = (target["url"] as? String ?? "").lowercased()
  if url.hasPrefix("app://-/index.html") && !url.contains("/avatar-overlay") {
    return true
  }
  return isChatGptRendererTarget(target)
}

private struct CDPApprovalTarget {
  let port: Int
  let target: [String: Any]
}

private struct CDPClient {
  static func port() -> Int {
    if let envPortStr = ProcessInfo.processInfo.environment["CHATGPT_AUTO_CONFIRM_CDP_PORT"],
       let envPort = Int(envPortStr.trimmingCharacters(in: .whitespacesAndNewlines)),
       envPort > 0 && envPort <= 65535 {
      return envPort
    }
    return 9223
  }

  static func host() -> String {
    if let envHost = ProcessInfo.processInfo.environment["CHATGPT_AUTO_CONFIRM_CDP_HOST"],
       !envHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return envHost.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return "127.0.0.1"
  }

  static func fetchTargets(portOverride: Int? = nil) -> [[String: Any]] {
    let resolvedPort = portOverride ?? port()
    guard let url = URL(string: "http://\(host()):\(resolvedPort)/json") else { return [] }
    var request = URLRequest(url: url)
    request.timeoutInterval = 1.5
    var resultData: Data?
    let semaphore = DispatchSemaphore(value: 0)
    let task = URLSession.shared.dataTask(with: request) { data, _, _ in
      resultData = data
      semaphore.signal()
    }
    task.resume()
    _ = semaphore.wait(timeout: .now() + 1.8)
    guard let data = resultData,
          let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      return []
    }
    return array
  }

  static func checkStatus() -> [String: Any] {
    let p = port()
    let targets = fetchTargets()
    let pageTargets = targets.filter(isChatGptRendererTarget)
    return [
      "port": p,
      "host": host(),
      "available": !targets.isEmpty,
      "connected": !targets.isEmpty,
      "targetCount": targets.count,
      "pageTargetCount": pageTargets.count,
      "note": "CDP (Chrome DevTools Protocol) 是由进程间进入正在运行的 ChatGPT 内部的主通信路径"
    ]
  }

  static func evaluate(wsURLString: String, expression: String, timeout: TimeInterval = 2.5) -> [String: Any]? {
    let params = "{\"expression\":\(jsonStringLiteral(expression)),\"returnByValue\":true,\"awaitPromise\":true}"
    return sendCommand(
      wsURLString: wsURLString,
      method: "Runtime.evaluate",
      paramsJSON: params,
      timeout: timeout
    )
  }

  static func captureScreenshot(wsURLString: String, outputURL: URL) -> Bool {
    guard let response = sendCommand(
      wsURLString: wsURLString,
      method: "Page.captureScreenshot",
      paramsJSON: "{\"format\":\"png\",\"captureBeyondViewport\":false}",
      timeout: 8.0
    ), let result = response["result"] as? [String: Any],
       let encoded = result["data"] as? String,
       let data = Data(base64Encoded: encoded) else { return false }
    do {
      try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try data.write(to: outputURL, options: .atomic)
      return true
    } catch {
      return false
    }
  }

  static func navigate(wsURLString: String, url: String) -> Bool {
    guard let response = sendCommand(
      wsURLString: wsURLString,
      method: "Page.navigate",
      paramsJSON: "{\"url\":\(jsonStringLiteral(url))}",
      timeout: 8.0
    ), response["error"] == nil else { return false }
    return true
  }

  @discardableResult
  static func setWebLifecycleActive(wsURLString: String) -> Bool {
    guard let response = sendCommand(
      wsURLString: wsURLString,
      method: "Page.setWebLifecycleState",
      paramsJSON: "{\"state\":\"active\"}",
      timeout: 4.0
    ), response["error"] == nil else { return false }
    return true
  }

  @discardableResult
  static func setHiddenPageFocusEmulation(wsURLString: String) -> Bool {
    guard let response = sendCommand(
      wsURLString: wsURLString,
      method: "Emulation.setFocusEmulationEnabled",
      paramsJSON: "{\"enabled\":true}",
      timeout: 4.0
    ), response["error"] == nil else { return false }
    return true
  }

  @discardableResult
  static func setHiddenPageUserActive(wsURLString: String) -> Bool {
    guard let response = sendCommand(
      wsURLString: wsURLString,
      method: "Emulation.setIdleOverride",
      paramsJSON: "{\"isUserActive\":true,\"isScreenUnlocked\":true}",
      timeout: 4.0
    ), response["error"] == nil else { return false }
    return true
  }

  static func browserWebSocketURL(portOverride: Int? = nil) -> String? {
    let resolvedPort = portOverride ?? port()
    guard let url = URL(string: "http://\(host()):\(resolvedPort)/json/version") else { return nil }
    var request = URLRequest(url: url)
    request.timeoutInterval = 1.5
    var resultData: Data?
    let semaphore = DispatchSemaphore(value: 0)
    let task = URLSession.shared.dataTask(with: request) { data, _, _ in
      resultData = data
      semaphore.signal()
    }
    task.resume()
    _ = semaphore.wait(timeout: .now() + 1.8)
    guard let data = resultData,
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    return object["webSocketDebuggerUrl"] as? String
  }

  static func targetInfo(targetId: String, portOverride: Int? = nil) -> [String: Any]? {
    guard let browserWS = browserWebSocketURL(portOverride: portOverride),
          let response = sendCommand(
            wsURLString: browserWS,
            method: "Target.getTargetInfo",
            paramsJSON: "{\"targetId\":\(jsonStringLiteral(targetId))}",
            timeout: 3.0
          ),
          let result = response["result"] as? [String: Any] else { return nil }
    return result["targetInfo"] as? [String: Any]
  }

  static func createBackgroundTarget(url: String, browserContextId: String?, portOverride: Int? = nil) -> String? {
    guard let browserWS = browserWebSocketURL(portOverride: portOverride) else { return nil }
    func create(in contextId: String?) -> String? {
      let contextJSON = contextId.map {
        ",\"browserContextId\":\(jsonStringLiteral($0))"
      } ?? ""
      guard let response = sendCommand(
            wsURLString: browserWS,
            method: "Target.createTarget",
            paramsJSON: "{\"url\":\(jsonStringLiteral(url)),\"background\":true\(contextJSON)}",
            timeout: 4.0
          ),
            let result = response["result"] as? [String: Any] else { return nil }
      return result["targetId"] as? String
    }
    if let browserContextId, let targetId = create(in: browserContextId) {
      return targetId
    }
    // Electron can report a renderer partition id that the browser-level
    // Target domain cannot address directly. Its default target context is
    // still the same one used by ChatGPT web renderers, so retry there.
    return create(in: nil)
  }

  @discardableResult
  static func closeTarget(_ targetId: String, portOverride: Int? = nil) -> Bool {
    guard let browserWS = browserWebSocketURL(portOverride: portOverride),
          let response = sendCommand(
            wsURLString: browserWS,
            method: "Target.closeTarget",
            paramsJSON: "{\"targetId\":\(jsonStringLiteral(targetId))}",
            timeout: 3.0
          ),
          let result = response["result"] as? [String: Any] else { return false }
    return result["success"] as? Bool ?? false
  }

  private static func sendCommand(
    wsURLString: String,
    method: String,
    paramsJSON: String,
    timeout: TimeInterval
  ) -> [String: Any]? {
    guard let wsURL = URL(string: wsURLString) else { return nil }
    var request = URLRequest(url: wsURL)
    request.timeoutInterval = timeout
    let wsTask = URLSession.shared.webSocketTask(with: request)
    wsTask.resume()
    defer { wsTask.cancel(with: .normalClosure, reason: nil) }

    let msgId = Int.random(in: 1000...999999)
    let reqStr = "{\"id\":\(msgId),\"method\":\(jsonStringLiteral(method)),\"params\":\(paramsJSON)}"
    cdpDebug("CDP request \(reqStr.prefix(1200))")

    let semaphore = DispatchSemaphore(value: 0)
    var responseJSON: [String: Any]?

    wsTask.send(.string(reqStr)) { error in
      if let error {
        cdpDebug("CDP send failed: \(error)")
        semaphore.signal()
      }
    }

    func receiveNext() {
      wsTask.receive { result in
        switch result {
        case .success(let message):
          switch message {
          case .string(let text):
            if let data = text.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
              if obj["id"] as? Int == msgId {
                responseJSON = obj
                semaphore.signal()
                return
              }
            }
          case .data(let data):
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
              if obj["id"] as? Int == msgId {
                responseJSON = obj
                semaphore.signal()
                return
              }
            }
          @unknown default:
            break
          }
          receiveNext()
        case .failure(let error):
          cdpDebug("CDP receive failed: \(error)")
          semaphore.signal()
        }
      }
    }
    receiveNext()

    _ = semaphore.wait(timeout: .now() + timeout)
    if let json = responseJSON {
      return sanitizeJSONDict(json)
    }
    cdpDebug("CDP command \(method) timed out for \(wsURLString)")
    return nil
  }

  private static func sanitizeJSONDict(_ dict: [String: Any]) -> [String: Any] {
    var result: [String: Any] = [:]
    for (key, value) in dict {
      if value is NSNull { continue }
      if let nested = value as? [String: Any] {
        result[key] = sanitizeJSONDict(nested)
      } else if let array = value as? [Any] {
        result[key] = array.compactMap { item -> Any? in
          if item is NSNull { return nil }
          if let nested = item as? [String: Any] { return sanitizeJSONDict(nested) }
          return item
        }
      } else {
        result[key] = value
      }
    }
    return result
  }
}

private func loadedApprovalTargets(_ state: PluginState) -> [CDPApprovalTarget] {
  // Browser extensions run inside every loaded tab rather than selecting one
  // visible tab. Reproduce that behavior for ChatGPT/Electron: enumerate every
  // loaded renderer on each known debugging endpoint and evaluate the approval
  // handler in place. Runtime.evaluate does not activate the app, focus a
  // window, click the sidebar, or change the current conversation.
  var ports: [Int] = [CDPClient.port()]
  if let backgroundPort = state.backgroundAppPort {
    ports.append(backgroundPort)
  }
  var seenPorts = Set<Int>()
  var seenTargets = Set<String>()
  var values: [CDPApprovalTarget] = []
  for port in ports where seenPorts.insert(port).inserted {
    for target in CDPClient.fetchTargets(portOverride: port)
      where isLoadedApprovalRendererTarget(target) {
      guard let targetId = target["id"] as? String else { continue }
      let identity = "\(port):\(targetId)"
      guard seenTargets.insert(identity).inserted else { continue }
      values.append(CDPApprovalTarget(port: port, target: target))
    }
  }
  return values
}

private func normalizedChatURL(_ rawValue: String?) -> String? {
  guard let rawValue,
        let url = URL(string: rawValue),
        url.scheme?.lowercased() == "https",
        url.host?.lowercased() == "chatgpt.com",
        url.path == "/" || url.path.hasPrefix("/c/") else { return nil }
  var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
  components?.fragment = nil
  return components?.url?.absoluteString
}

private func rememberChatURL(_ rawValue: String?, in state: inout PluginState) {
  guard let url = normalizedChatURL(rawValue) else { return }
  var urls = state.trackedChatURLs ?? []
  urls.removeAll { $0 == url }
  urls.append(url)
  state.trackedChatURLs = Array(urls.suffix(20))
}

@discardableResult
private func synchronizeBackgroundTargets(
  _ state: inout PluginState,
  targets: [[String: Any]]
) -> Int {
  let liveTargetIds = Set(targets.compactMap { $0["id"] as? String })
  var backgroundTargets = state.backgroundTargets ?? [:]
  backgroundTargets = backgroundTargets.filter { liveTargetIds.contains($0.value) }
  let missingURLs = (state.trackedChatURLs ?? []).filter { backgroundTargets[$0] == nil }
  if missingURLs.isEmpty {
    state.backgroundTargets = backgroundTargets
    return 0
  }
  let appContextId = targets.lazy.compactMap { target -> String? in
    guard target["type"] as? String == "page",
          (target["url"] as? String ?? "").hasPrefix("app://"),
          let targetId = target["id"] as? String else { return nil }
    return CDPClient.targetInfo(targetId: targetId)?["browserContextId"] as? String
  }.first
  var created = 0
  for url in missingURLs {
    // Keep one plugin-owned renderer alive even while the user-facing copy is
    // still open. This preserves the exact task before ChatGPT unloads it.
    if let targetId = CDPClient.createBackgroundTarget(
      url: url,
      browserContextId: appContextId
    ) {
      backgroundTargets[url] = targetId
      created += 1
    }
  }
  state.backgroundTargets = backgroundTargets
  return created
}

private func closeBackgroundTargets(_ state: inout PluginState) {
  for targetId in (state.backgroundTargets ?? [:]).values {
    _ = CDPClient.closeTarget(targetId)
  }
  state.backgroundTargets = [:]
}

@discardableResult
private func ensureChatTarget(_ rawValue: String?, in state: inout PluginState) -> String? {
  guard let rawValue else { return nil }
  guard let chatURL = normalizedChatURL(rawValue) else { return nil }
  rememberChatURL(chatURL, in: &state)
  let created = synchronizeBackgroundTargets(&state, targets: CDPClient.fetchTargets())
  if created > 0 { Thread.sleep(forTimeInterval: 0.25) }
  return chatURL
}

private func cdpValue(
  port: Int,
  targetId: String,
  expression: String,
  timeout: TimeInterval = 5.0
) -> [String: Any]? {
  guard let target = CDPClient.fetchTargets(portOverride: port).first(where: {
    $0["id"] as? String == targetId
  }), let wsURL = target["webSocketDebuggerUrl"] as? String,
        let response = CDPClient.evaluate(
          wsURLString: wsURL,
          expression: expression,
          timeout: timeout
        ),
        let outer = response["result"] as? [String: Any] else { return nil }
  if let value = (outer["result"] as? [String: Any])?["value"] as? [String: Any] {
    return sanitizeJSONValue(value) as? [String: Any]
  }
  if let value = outer["value"] as? [String: Any] {
    return sanitizeJSONValue(value) as? [String: Any]
  }
  return nil
}

private func pageDiagnosticJS() -> String {
  #"""
  (async () => {
    const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
    const thinkingToggles = [...document.querySelectorAll('button')].filter(button => {
      const text = (button.innerText || '').trim();
      return text.startsWith('正在思考') || text.startsWith('Thinking');
    });
    const latestThinking = thinkingToggles[thinkingToggles.length - 1];
    if (latestThinking?.getAttribute('aria-expanded') === 'false') {
      latestThinking.click();
      await sleep(120);
    }
    const root = document.querySelector('main') || document.body;
    const redact = value => (value || '')
      .replace(/\bsk-[A-Za-z0-9_-]{4,}\b/g, '[REDACTED_API_KEY]')
      .replace(/\b(Bearer\s+)[A-Za-z0-9._~+\/-]+=*/gi, '$1[REDACTED_TOKEN]')
      .replace(/\b([A-Z][A-Z0-9_]*(?:TOKEN|API_KEY|SECRET|PASSWORD))=([^\s,]+)/g, '$1=[REDACTED]')
      .replace(/(DeviceID\s*\n)[^\n]+/gi, '$1[REDACTED_DEVICE_ID]');
    const text = redact((root?.innerText || '').replace(/\s+$/g, ''));
    const buttons = [...document.querySelectorAll('button')]
      .filter(button => button.offsetWidth || button.offsetHeight || button.getClientRects().length)
      .map(button => (button.innerText || button.getAttribute('aria-label') || '').trim())
      .filter(Boolean)
      .slice(0, 100);
    return {
      ok: true,
      content: text.substring(0, 50000),
      buttons,
      signature: `${text.length}:${text.slice(-4000)}:${buttons.join('|')}`,
      url: window.location.href || ''
    };
  })()
  """#
}

private func captureHiddenChatScreenshot(_ state: PluginState, label: String = "stalled") -> String? {
  guard let port = state.backgroundAppPort,
        let targetId = state.backgroundChatTargetId,
        let target = CDPClient.fetchTargets(portOverride: port).first(where: {
          $0["id"] as? String == targetId
        }),
        let wsURL = target["webSocketDebuggerUrl"] as? String else { return nil }
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyyMMdd-HHmmss"
  let outputURL = stateURL().deletingLastPathComponent()
    .appendingPathComponent("diagnostics", isDirectory: true)
    .appendingPathComponent("chat-\(label)-\(formatter.string(from: Date())).png")
  return CDPClient.captureScreenshot(wsURLString: wsURL, outputURL: outputURL)
    ? outputURL.path
    : nil
}

private func hiddenChatProfilePath() -> String {
  FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/Mahayana/plugins/chatgpt-auto-confirm/background-chat-profile")
    .path
}

private func hiddenChatPort(_ state: PluginState) -> Int {
  if let raw = ProcessInfo.processInfo.environment["CHATGPT_AUTO_CONFIRM_BACKGROUND_PORT"],
     let port = Int(raw), port > 0 && port <= 65535 { return port }
  return state.backgroundAppPort ?? 9324
}

private func backgroundConversationURL(_ conversationId: String) -> String? {
  var components = URLComponents(string: "app://-/index.html")
  components?.queryItems = [
    URLQueryItem(
      name: "initialRoute",
      value: "/work/conversation/\(conversationId)"
    )
  ]
  return components?.url?.absoluteString
}

private func wakeHiddenRenderer(
  port: Int,
  targetId: String,
  wsURL: String
) -> Bool {
  // Electron can leave a show:false renderer with its document and scripts
  // loaded while React remains suspended. CDP focus emulation and an active
  // idle state wake the renderer scheduler without showing the BrowserWindow,
  // focusing the application, or changing document.visibilityState.
  _ = CDPClient.setWebLifecycleActive(wsURLString: wsURL)
  _ = CDPClient.setHiddenPageFocusEmulation(wsURLString: wsURL)
  _ = CDPClient.setHiddenPageUserActive(wsURLString: wsURL)
  let probe = cdpValue(
    port: port,
    targetId: targetId,
    expression: """
    (async () => {
      document.dispatchEvent(new Event('visibilitychange'));
      window.dispatchEvent(new Event('focus'));
      const startedAt = performance.now();
      await new Promise(resolve => setTimeout(resolve, 50));
      return {
        bridge: !!window.electronBridge,
        visibility: document.visibilityState,
        href: location.href,
        eventLoopDelayMs: performance.now() - startedAt
      };
    })()
    """,
    timeout: 4.0
  )
  let eventLoopDelayMs = (probe?["eventLoopDelayMs"] as? NSNumber)?.doubleValue
    ?? Double.greatestFiniteMagnitude
  return (probe?["bridge"] as? NSNumber)?.boolValue == true
    && probe?["visibility"] as? String == "hidden"
    && (probe?["href"] as? String ?? "").hasPrefix("app://-/index.html")
    && eventLoopDelayMs < 2_500
}

private func navigateHiddenConversation(
  port: Int,
  targetId: String,
  conversationId: String,
  timeout: TimeInterval = 35.0
) -> Bool {
  guard let url = backgroundConversationURL(conversationId),
        let target = CDPClient.fetchTargets(portOverride: port).first(where: {
          $0["id"] as? String == targetId
        }),
        let wsURL = target["webSocketDebuggerUrl"] as? String,
        CDPClient.navigate(wsURLString: wsURL, url: url) else { return false }
  Thread.sleep(forTimeInterval: 0.5)
  guard wakeHiddenRenderer(port: port, targetId: targetId, wsURL: wsURL) else {
    return false
  }
  let deadline = Date().addingTimeInterval(timeout)
  repeat {
    guard queueTargetIsHidden(port: port, targetId: targetId) else { return false }
    if let status = cdpValue(
      port: port,
      targetId: targetId,
      expression: chatStatusJS(),
      timeout: 5.0
    ), normalizedConversationId(status["conversationId"] as? String) == conversationId,
       status["chatMode"] as? Bool == true {
      return true
    }
    Thread.sleep(forTimeInterval: 0.25)
  } while Date() < deadline
  return false
}

private func selectBackgroundConversationJS(_ conversationId: String) -> String {
  let expected = jsonStringLiteral(conversationId)
  return """
  (async () => {
    const expected = \(expected);
    const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
    const portalId = () => {
      const raw = document.querySelector('[data-above-composer-conversation-id]')
        ?.getAttribute('data-above-composer-conversation-id') || '';
      return raw.startsWith('chatgpt:') ? raw.slice('chatgpt:'.length) : raw;
    };
    const conversationFingerprint = () => {
      const nodes = [...document.querySelectorAll(
        '[data-message-author-role], [data-user-message-bubble], [data-local-conversation-final-assistant]'
      )];
      return nodes.map((node, index) => {
        const role = node.getAttribute('data-message-author-role')
          || (node.hasAttribute('data-user-message-bubble') ? 'user' : 'assistant');
        const text = (node.innerText || node.textContent || '').trim();
        return `${index}:${role}:${text.length}:${text.slice(-240)}`;
      }).join('|');
    };
    const waitForConversationBody = async (previousFingerprint = '', requireChange = false) => {
      for (let index = 0; index < 40; index += 1) {
        const fingerprint = conversationFingerprint();
        if (fingerprint && (!requireChange || fingerprint !== previousFingerprint)) {
          return { ok: true, fingerprint };
        }
        await sleep(150);
      }
      return { ok: false, error: 'conversation_body_not_ready' };
    };
    const matches = value => {
      if (!value || typeof value !== 'string') return false;
      let decoded = value;
      try { decoded = decodeURIComponent(value); } catch {}
      return decoded === expected || decoded.endsWith(`:${expected}`)
        || (expected.startsWith('local-chatgpt:') && decoded.includes(expected));
    };
    const rowMatches = row => {
      const fiberKey = Object.keys(row).find(key => key.startsWith('__reactFiber$'));
      let fiber = fiberKey ? row[fiberKey] : null;
      // Stop before the virtual-list parent. That parent contains every item
      // key and would make the first visible row appear to match any task.
      for (let depth = 0; fiber && depth < 8; depth += 1, fiber = fiber.return) {
        const props = fiber.memoizedProps || {};
        // activeConversationId is shared by every visible row and identifies
        // the current page, not the row. Never use it for row ownership.
        const candidates = [props.conversationId, props.route,
          props.shortcutKey, props.item, props.conversation?.id];
        if (candidates.some(matches)) return true;
      }
      return false;
    };
    const current = portalId();
    if (matches(current)) {
      const ready = await waitForConversationBody();
      return ready.ok
        ? { ok: true, selected: false, alreadyActive: true, messagesReady: true, conversationId: current }
        : { ok: false, error: ready.error, expected, conversationId: current };
    }
    const rows = [...document.querySelectorAll('[data-thread-title="true"]')]
      .map(title => title.closest('[role="button"]')).filter(Boolean);
    const row = rows.find(rowMatches);
    if (!row) return { ok: false, error: 'conversation_sidebar_row_not_found', expected };
    const previousFingerprint = conversationFingerprint();
    row.click();
    for (let index = 0; index < 40; index += 1) {
      await sleep(150);
      const resolved = portalId();
      const input = document.querySelector('#prompt-textarea')
        || document.querySelector('[contenteditable="true"]');
      if (resolved && input && (matches(resolved) || rowMatches(row))) {
        const ready = await waitForConversationBody(previousFingerprint, true);
        return ready.ok
          ? { ok: true, selected: true, messagesReady: true, conversationId: resolved }
          : { ok: false, error: ready.error, expected, conversationId: resolved };
      }
    }
    return { ok: false, error: 'conversation_sidebar_selection_timeout', expected };
  })()
  """
}

private func normalizedConversationId(_ rawValue: String?) -> String? {
  guard let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
        !value.isEmpty,
        value.range(
          of: "^(?:local-chatgpt:)?[A-Za-z0-9-]{8,128}$",
          options: .regularExpression
        ) != nil else { return nil }
  return value
}

private func prepareBackgroundChatJS(newChat: Bool, conversationId: String? = nil) -> String {
  let newChatValue = newChat ? "true" : "false"
  let expectedConversationId = jsonStringLiteral(conversationId ?? "")
  return """
  (async () => {
    const result = {
      ok: false, backgroundOnly: true, workerUsed: false,
      newChatClicked: false, chatSelected: false, error: null,
      url: window.location.href || '', conversationId: null
    };
    const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
    const exactButton = text => [...document.querySelectorAll('button, a, [role="button"]')].find(button =>
      (button.innerText || button.textContent || button.getAttribute('title') || '').trim().toLowerCase() === text.toLowerCase()
    );
    const currentConversationId = () => {
      const raw = document.querySelector('[data-above-composer-conversation-id]')
        ?.getAttribute('data-above-composer-conversation-id') || '';
      return raw.startsWith('chatgpt:') ? raw.slice('chatgpt:'.length) : raw;
    };
    const previousConversationId = currentConversationId();

    if (\(newChatValue)) {
      // The desktop app has used all of these labels for the same action
      // across Chat/Work releases and locales.
      const button = ['新聊天', '新建任务', '新任务', 'New chat', 'New task']
        .map(exactButton).find(Boolean);
      if (!button) {
        result.error = 'new_chat_button_not_found';
        return result;
      }
      button.click();
      result.newChatClicked = true;
      await sleep(650);
    }

    if (\(newChatValue)) {
      let freshConversationId = currentConversationId();
      for (let index = 0; index < 40 && (!freshConversationId
          || freshConversationId === previousConversationId); index += 1) {
        await sleep(150);
        freshConversationId = currentConversationId();
      }
      if (!freshConversationId || freshConversationId === previousConversationId) {
        result.error = 'new_chat_conversation_not_created';
        result.previousConversationId = previousConversationId || null;
        result.conversationId = freshConversationId || null;
        return result;
      }
    }

    const input = document.querySelector('#prompt-textarea')
      || document.querySelector('[contenteditable="true"]');
    const chatModel = [...document.querySelectorAll('button, a, [role="button"]')].some(button => {
      const label = button.getAttribute('aria-label') || '';
      return label.includes('ChatGPT 模型') || /select chatgpt model/i.test(label);
    });
    const webChat = window.location.protocol === 'https:'
      && window.location.hostname === 'chatgpt.com';
    const workComposer = !!document.querySelector('[data-codex-composer="true"]');
    
    const isChatSurface = !!document.querySelector('#prompt-textarea') || chatModel || webChat;

    const initialRoute = new URL(window.location.href).searchParams.get('initialRoute') || '';
    const routeMatch = initialRoute.match(/^\\/work\\/conversation\\/([^/?#]+)/);
    const portalConversation = document.querySelector('[data-above-composer-conversation-id]')
      ?.getAttribute('data-above-composer-conversation-id') || '';
    const portalConversationId = portalConversation.startsWith('chatgpt:')
      ? portalConversation.slice('chatgpt:'.length)
      : portalConversation;
    result.conversationId = routeMatch
      ? decodeURIComponent(routeMatch[1])
      : (portalConversationId || null);
    const expectedConversationId = \(expectedConversationId);
    result.expectedConversationId = expectedConversationId || null;
    if (!input || !isChatSurface || workComposer) {
      result.error = 'not_chat_surface';
      result.hasInput = !!input;
      result.chatModel = chatModel;
      result.workComposer = workComposer;
      return result;
    }
    result.ok = true;
    result.chatSelected = true;
    result.surface = 'chat';
    result.hasInput = true;
    return result;
  })()
  """
}

private func resolveDispatchedConversationJS(
  dispatchMarker: String,
  localConversationId: String?
) -> String {
  let marker = jsonStringLiteral(dispatchMarker)
  let localId = jsonStringLiteral(localConversationId ?? "")
  return """
  (async () => {
    const dispatchMarker = \(marker);
    const expectedLocalId = \(localId);
    const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
    const normalizeId = raw => {
      if (typeof raw !== 'string' || !raw) return '';
      let value = raw;
      try { value = decodeURIComponent(value); } catch {}
      return value.startsWith('chatgpt:') ? value.slice('chatgpt:'.length) : value;
    };
    const portalId = () => normalizeId(
      document.querySelector('[data-above-composer-conversation-id]')
        ?.getAttribute('data-above-composer-conversation-id') || ''
    );
    const rowCandidates = () => {
      const values = [];
      const rows = [...document.querySelectorAll('[data-thread-title="true"]')]
        .map(title => title.closest('[role="button"]'))
        .filter(Boolean);
      for (const row of rows) {
        const title = (row.querySelector('[data-thread-title="true"]')?.textContent || '').trim();
        const fiberKey = Object.keys(row).find(key => key.startsWith('__reactFiber$'));
        let fiber = fiberKey ? row[fiberKey] : null;
        const identities = [];
        const durableIds = [];
        for (let depth = 0; fiber && depth < 8; depth += 1, fiber = fiber.return) {
          const props = fiber.memoizedProps || {};
          identities.push(props.conversationId, props.conversation?.id);
          if (typeof props.conversation?.id === 'string') {
            durableIds.push(props.conversation.id);
          }
          for (const route of [props.route, props.shortcutKey]) {
            if (typeof route !== 'string') continue;
            const match = route.match(/^\\/work\\/conversation\\/([^/?#]+)/);
            if (match) identities.push(match[1]);
          }
        }
        const normalizedIdentities = [...new Set(identities.map(normalizeId).filter(Boolean))];
        const durableId = durableIds.map(normalizeId).find(id =>
          id && !id.startsWith('local-chatgpt:')
        ) || normalizedIdentities.find(id => id && !id.startsWith('local-chatgpt:'));
        values.push({
          identities: normalizedIdentities,
          durableId: durableId || '',
          title
        });
      }
      return values;
    };
    for (let index = 0; index < 80; index += 1) {
      const users = [...document.querySelectorAll(
        '[data-message-author-role="user"], [data-user-message-bubble]'
      )];
      const markerVisible = users.some(user =>
        (user.innerText || user.textContent || '').includes(dispatchMarker)
      );
      if (markerVisible) {
        const portal = portalId();
        if (portal && !portal.startsWith('local-chatgpt:')) {
          return {ok: true, conversationId: portal, source: 'portal'};
        }
        // The sidebar can virtualize old rows while the user creates a
        // foreground Chat, so "first id absent from the baseline" is unsafe.
        // ChatGPT exposes an exact local->durable mapping on the task's own
        // row: its route keeps the local id while conversation.id is durable.
        const candidate = expectedLocalId
          ? rowCandidates().find(value =>
              value.identities.includes(expectedLocalId) && value.durableId
            )
          : null;
        if (candidate?.durableId) {
          return {
            ok: true,
            conversationId: candidate.durableId,
            source: 'local-row-mapping',
            title: candidate.title
          };
        }
      }
      await sleep(250);
    }
    return {
      ok: false,
      error: 'durable_conversation_id_pending',
      portalConversationId: portalId() || null
    };
  })()
  """
}

private func clickNewChatJS() -> String {
  #"""
  (() => {
    const raw = document.querySelector('[data-above-composer-conversation-id]')
      ?.getAttribute('data-above-composer-conversation-id') || '';
    const previousConversationId = raw.startsWith('chatgpt:')
      ? raw.slice('chatgpt:'.length)
      : raw;
    const exactButton = text => [...document.querySelectorAll('button, a, [role="button"]')].find(button => {
      const target = text.toLowerCase();
      const labels = [
        button.innerText,
        button.textContent,
        button.getAttribute('aria-label'),
        button.getAttribute('title')
      ].filter(Boolean).map(t => t.trim().toLowerCase());
      return labels.includes(target) || labels.some(l => l.includes(target));
    });
    const button = ['新聊天', '新建任务', '新任务', 'new chat', 'new task']
      .map(exactButton).find(Boolean) || document.querySelector('[href="/"]');
    if (!button) {
      return { ok: false, error: 'new_chat_button_not_found', previousConversationId };
    }
    button.click();
    return { ok: true, newChatClicked: true, previousConversationId };
  })()
  """#
}

private func clickChatJS() -> String {
  #"""
  (() => {
    const button = [...document.querySelectorAll('button')].find(button =>
      (button.innerText || button.textContent || '').trim().toLowerCase() === 'chat'
    );
    if (!button) return { ok: false, error: 'chat_button_not_found' };
    button.click();
    return { ok: true, chatSelected: true };
  })()
  """#
}

private func autoConfirmWorkHandoffJS() -> String {
  #"""
  (() => {
    const normalize = value => (value || '').replace(/[\s↵]+/g, ' ').trim().toLowerCase();
    const button = [...document.querySelectorAll('button')].find(button => {
      const label = normalize(button.innerText || button.textContent || button.getAttribute('aria-label'));
      return label === '继续工作' || label === 'continue working'
        || label === 'continue in work' || label === 'switch to work';
    });
    if (!button) return { ok: true, clicked: false };
    setTimeout(() => {
      try { button.click(); } catch (_) {}
    }, 0);
    return { ok: true, clicked: true, dispatchOnly: true };
  })()
  """#
}

// Work/worker is only the queue controller. Task execution and acceptance must
// remain on Chat, even when ChatGPT offers a coding-task handoff to Work. Keep
// the old Work helper above for explicit legacy callers, but never invoke it
// from the queue's default send, continuation, or review paths.
private func autoConfirmChatContinuationJS() -> String {
  #"""
  (() => {
    const normalize = value => (value || '').replace(/[\s↵]+/g, ' ').trim().toLowerCase();
    const allowed = new Set([
      '继续在此聊天', '继续聊天', 'continue in this chat', 'stay in this chat',
      'continue here', 'continue chat'
    ]);
    const button = [...document.querySelectorAll('button')].find(button => {
      if (button.disabled || !(button.offsetWidth || button.offsetHeight || button.getClientRects().length)) return false;
      return allowed.has(normalize(button.innerText || button.textContent || button.getAttribute('aria-label')));
    });
    if (!button) return { ok: true, clicked: false, surface: 'chat' };
    setTimeout(() => {
      try { button.click(); } catch (_) {}
    }, 0);
    return { ok: true, clicked: true, dispatchOnly: true, surface: 'chat' };
  })()
  """#
}

private func autoApproveDedicatedAuthorizationJS() -> String {
  #"""
  (() => {
    const normalize = value => (value || '').replace(/[\s↵]+/g, ' ').trim().toLowerCase();
    const allowed = new Set([
      '完全访问', 'full access', 'allow', 'allow once', '允许', '允许一次',
      'approve', 'approve once', 'confirm', '确认'
    ]);
    const button = [...document.querySelectorAll('button')].find(button => {
      if (button.disabled || !(button.offsetWidth || button.offsetHeight || button.getClientRects().length)) return false;
      return allowed.has(normalize(button.innerText || button.textContent || button.getAttribute('aria-label')));
    });
    if (!button) return { ok: true, clicked: false };
    setTimeout(() => {
      try { button.click(); } catch (_) {}
    }, 0);
    return { ok: true, clicked: true, dispatchOnly: true };
  })()
  """#
}

private func prepareNewChatTarget(
  port: Int,
  targetId: String,
  timeout: TimeInterval = 4.0,
  allowBlankConversationReuse: Bool = false
) -> [String: Any]? {
  // First wait for the app bundle/composer. Target.createTarget can expose a
  // static startup shell until its explicit Page.navigate has completed.
  _ = cdpValue(
    port: port,
    targetId: targetId,
    expression: clickChatJS(),
    timeout: timeout
  )
  var baseline: [String: Any]?
  for _ in 0..<40 {
    baseline = cdpValue(
      port: port,
      targetId: targetId,
      expression: prepareBackgroundChatJS(newChat: false),
      timeout: timeout
    )
    if baseline?["ok"] as? Bool == true { break }
    if baseline?["error"] as? String == "not_chat_surface" {
      _ = cdpValue(
        port: port,
        targetId: targetId,
        expression: clickChatJS(),
        timeout: timeout
      )
    }
    Thread.sleep(forTimeInterval: 0.25)
  }
  guard let baseline,
        baseline["ok"] as? Bool == true else { return nil }
  let previousConversationId = baseline["conversationId"] as? String
  guard let clicked = cdpValue(
    port: port,
    targetId: targetId,
    expression: clickNewChatJS(),
    timeout: timeout
  ), clicked["ok"] as? Bool == true else { return nil }
  let previous = clicked["previousConversationId"] as? String ?? previousConversationId

  for _ in 0..<40 {
    let prepared = cdpValue(
      port: port,
      targetId: targetId,
      expression: prepareBackgroundChatJS(newChat: false),
      timeout: timeout
    )
    if prepared?["ok"] as? Bool == true {
      let conversationId = prepared?["conversationId"] as? String ?? ""
      let changed = (previous?.isEmpty != false && !conversationId.isEmpty) || 
                    (previous?.isEmpty == false && conversationId != previous)
      let blankConversation = allowBlankConversationReuse &&
        (cdpValue(
          port: port,
          targetId: targetId,
          expression: "(() => ({messageCount: document.querySelectorAll('[data-message-author-role], [data-user-message-bubble], [data-local-conversation-final-assistant]').length}))()",
          timeout: timeout
        )?["messageCount"] as? Int ?? 1) == 0
      if changed || (blankConversation && previous?.isEmpty != false) {
        var result = prepared ?? [:]
        result["newChatClicked"] = true
        return result
      }
    }
    Thread.sleep(forTimeInterval: 0.25)
  }
  return nil
}

@discardableResult
private func ensureHiddenChatTarget(
  _ state: inout PluginState,
  newChat: Bool = false,
  conversationId: String? = nil
) -> [String: Any]? {
  let port = hiddenChatPort(state)
  let profilePath = state.backgroundProfilePath ?? hiddenChatProfilePath()
  var targets = CDPClient.fetchTargets(portOverride: port)
  let allowTestWebTarget = ProcessInfo.processInfo.environment["CHATGPT_AUTO_CONFIRM_ALLOW_TEST_WEB_TARGET"] == "1"
  let assignedTargetId = state.backgroundChatTargetId
  func eligibleTarget(_ target: [String: Any]) -> Bool {
    if target["type"] as? String == "page"
        && (target["url"] as? String ?? "").hasPrefix("app://-/index.html")
        && !(target["url"] as? String ?? "").contains("/avatar-overlay") {
      return true
    }
    if target["id"] as? String == assignedTargetId && isChatGptRendererTarget(target) {
      return true
    }
    return allowTestWebTarget && isChatGptRendererTarget(target)
  }
  var mainTarget = targets.first(where: {
    eligibleTarget($0) && $0["id"] as? String == assignedTargetId
  }) ?? targets.first(where: eligibleTarget)

  if mainTarget == nil {
    do {
      try FileManager.default.createDirectory(
        atPath: profilePath,
        withIntermediateDirectories: true
      )
      let launcher = Process()
      launcher.executableURL = URL(fileURLWithPath: "/usr/bin/open")
      launcher.arguments = [
        "-g", "-j", "-n", "-a", "/Applications/ChatGPT.app", "--args",
        "--user-data-dir=\(profilePath)",
        "--remote-debugging-port=\(port)",
      ]
      launcher.standardInput = FileHandle.nullDevice
      launcher.standardOutput = FileHandle.nullDevice
      launcher.standardError = FileHandle.nullDevice
      try launcher.run()
      launcher.waitUntilExit()
    } catch {
      state.lastError = "background_chat_launch_failed"
      return [
        "ok": false,
        "errorCode": "background_chat_launch_failed",
        "message": error.localizedDescription,
        "backgroundOnly": true,
        "workerUsed": false,
      ]
    }

    for _ in 0..<100 {
      Thread.sleep(forTimeInterval: 0.25)
      targets = CDPClient.fetchTargets(portOverride: port)
      mainTarget = targets.first(where: eligibleTarget)
      if mainTarget != nil { break }
    }
  }

  guard let targetId = mainTarget?["id"] as? String else {
    state.lastError = "background_chat_target_unavailable"
    return [
      "ok": false,
      "errorCode": "background_chat_target_unavailable",
      "message": "隐藏 ChatGPT Chat 实例未能就绪；未使用当前 Work/worker 页面作为回退。",
      "backgroundOnly": true,
      "workerUsed": false,
      "port": port,
    ]
  }

  // The hidden window can reopen on Work. Switch the mode synchronously so
  // the following composer probe never awaits across a renderer transition.
  _ = cdpValue(
    port: port,
    targetId: targetId,
    expression: clickChatJS(),
    timeout: 4.0
  )

  if let conversationId, !conversationId.isEmpty {
    let selected = cdpValue(
      port: port,
      targetId: targetId,
      expression: selectBackgroundConversationJS(conversationId),
      timeout: 16.0
    )
    guard selected?["ok"] as? Bool == true else {
      state.lastError = selected?["error"] as? String ?? "conversation_sidebar_selection_failed"
      return selected ?? [
        "ok": false,
        "errorCode": "conversation_sidebar_selection_failed",
        "message": "隐藏 Chat 无法从侧栏恢复指定会话。",
        "backgroundOnly": true,
        "workerUsed": false,
      ]
    }
  }

  let prepared: [String: Any]?
  if newChat {
    prepared = prepareNewChatTarget(port: port, targetId: targetId)
  } else {
    var current: [String: Any]?
    for _ in 0..<40 {
      current = cdpValue(
        port: port,
        targetId: targetId,
        expression: prepareBackgroundChatJS(newChat: false, conversationId: conversationId),
        timeout: 4.0
      )
      if current?["ok"] as? Bool == true { break }
      Thread.sleep(forTimeInterval: 0.25)
    }
    prepared = current
  }
  guard var prepared, prepared["ok"] as? Bool == true else {
    state.lastError = prepared?["error"] as? String ?? "background_chat_not_ready"
    return prepared ?? [
      "ok": false,
      "errorCode": "background_chat_not_ready",
      "message": "隐藏实例没有进入 Chat 页面；未向当前 Work/worker 页面发送。",
      "backgroundOnly": true,
      "workerUsed": false,
      "port": port,
    ]
  }

  state.backgroundAppPort = port
  state.backgroundProfilePath = profilePath
  state.backgroundChatTargetId = targetId
  state.backgroundConversationId = conversationId
  state.lastError = nil
  prepared["port"] = port
  prepared["targetId"] = targetId
  prepared["profilePath"] = profilePath
  return prepared
}

private func keepApprovalBackgroundEndpointAlive(_ state: inout PluginState) {
  guard let port = state.backgroundAppPort,
        let targetId = state.backgroundChatTargetId,
        let target = CDPClient.fetchTargets(portOverride: port).first(where: {
          $0["id"] as? String == targetId
        }),
        let wsURL = target["webSocketDebuggerUrl"] as? String else {
    // A renderer can be reclaimed while the watcher survives. Clear only the
    // stale target reference and immediately rebuild the plugin-owned endpoint
    // instead of waiting for the user to foreground a ChatGPT window.
    state.backgroundChatTargetId = nil
    _ = ensureHiddenChatTarget(&state)
    return
  }
  // Reassert an active Chromium lifecycle on every watcher pass. These CDP
  // commands do not show a BrowserWindow or activate ChatGPT, but they prevent
  // a hidden renderer from remaining frozen after screen lock/App Nap.
  _ = CDPClient.setWebLifecycleActive(wsURLString: wsURL)
  _ = CDPClient.setHiddenPageFocusEmulation(wsURLString: wsURL)
  _ = CDPClient.setHiddenPageUserActive(wsURLString: wsURL)
}

private func scanIPC(_ state: inout PluginState) -> [String: Any]? {
  guard state.approveAll == true || !state.rules.isEmpty else { return nil }
  let pageTargets = loadedApprovalTargets(state)
  guard !pageTargets.isEmpty else { return nil }

  guard let rulesData = try? JSONSerialization.data(withJSONObject: state.rules.map { [
    "id": $0.id, "application": $0.application, "action": $0.action, "resource": $0.resource
  ] }), let rulesJSON = String(data: rulesData, encoding: .utf8) else { return nil }
  let approveAllBool = state.approveAll == true ? "true" : "false"

  let jsScript = """
  (() => {
    const rules = \(rulesJSON);
    const approveAll = \(approveAllBool);
    const results = { candidates: 0, approved: 0, pending: 0, blocked: 0, unmatched: 0, internalActions: 0, domEvents: 0, modeContinuations: 0, audits: [] };

    function sanitizeContext(text) {
      if (!text) return "";
      let clean = text.replace(/\\s+/g, ' ').trim();
      if (clean.length > 200) clean = clean.substring(0, 200) + "...";
      let hash = 0x811c9dc5;
      for (let i = 0; i < clean.length; i++) {
        hash ^= clean.charCodeAt(i);
        hash += (hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24);
      }
      return "Allow ChatGPT to use [approval details redacted] #" + (hash >>> 0).toString(16);
    }

    function isAllowTitle(text) {
      const norm = (text || "").toLowerCase().trim();
      return ["allow", "allow once", "approve", "approve once", "confirm", "confirm once",
              "允许", "允许一次", "同意", "同意一次", "确认", "确认一次"].includes(norm);
    }

    function isRejectTitle(text) {
      const norm = (text || "").toLowerCase().trim();
      return ["deny", "reject", "cancel", "deny once", "reject once", "拒绝", "拒绝一次", "不允许",
              "不允许一次", "取消"].includes(norm);
    }

    function isContinueInChatTitle(text) {
      const norm = (text || "").toLowerCase().replace(/\\s+/g, " ").trim();
      return ["继续在此聊天", "continue in this chat", "stay in this chat", "continue here"].includes(norm);
    }

    function checkCardMatch(contextText, metadataBody) {
      if (approveAll) return { match: true, reason: "IPC 主路径：通用模式：已通过进程间通信自动确认 (allow_once/target_message_id)", ruleId: null };
      const norm = (contextText || "").toLowerCase() + " " + (metadataBody || "").toLowerCase();
      for (const rule of rules) {
        if (norm.includes((rule.application || "").toLowerCase()) &&
            norm.includes((rule.action || "").toLowerCase()) &&
            norm.includes((rule.resource || "").toLowerCase())) {
          return { match: true, reason: "IPC 主路径：命中精确允许规则 " + rule.id + " (allow_once/target_message_id)", ruleId: rule.id };
        }
      }
      return { match: false, reason: "未同时匹配应用、动作和资源", ruleId: null };
    }

    function collectButtons(root, output, visited) {
      if (!root || visited.has(root)) return;
      visited.add(root);
      try {
        output.push(...Array.from(root.querySelectorAll('button, a, [role="button"]')));
        for (const el of root.querySelectorAll('*')) {
          if (el.shadowRoot) collectButtons(el.shadowRoot, output, visited);
        }
        for (const frame of root.querySelectorAll('iframe')) {
          try {
            if (frame.contentDocument) collectButtons(frame.contentDocument, output, visited);
          } catch (_) {}
        }
      } catch (_) {}
    }

    function invokeInternalApproval(btn) {
      const propsKey = Object.keys(btn).find(k => k.startsWith('__reactProps$'));
      const fiberKey = Object.keys(btn).find(k => k.startsWith('__reactFiber$'));
      const directProps = propsKey ? btn[propsKey] : null;
      const fiberProps = fiberKey ? btn[fiberKey]?.memoizedProps : null;
      const handler = directProps?.onClick || fiberProps?.onClick;
      if (typeof handler === 'function') {
        const event = {
          type: 'click', target: btn, currentTarget: btn,
          defaultPrevented: false,
          preventDefault() { this.defaultPrevented = true; },
          stopPropagation() {}, persist() {},
          nativeEvent: { type: 'click', target: btn }
        };
        handler(event);
        return 'react_handler';
      }
      btn.click();
      return 'dom_event';
    }

    const buttons = [];
    collectButtons(document, buttons, new Set());
    const processedContainers = new Set();

    // Chat can ask whether to remain in Chat or switch to Work for a coding
    // task. The plugin must explicitly stay in Chat and must never select the
    // adjacent "继续工作 / Continue working" action.
    for (const btn of buttons) {
      const title = btn.innerText || btn.getAttribute('aria-label') || btn.getAttribute('title') || "";
      if (!isContinueInChatTitle(title) || btn.disabled) continue;
      try {
        const internalMode = invokeInternalApproval(btn);
        if (internalMode === 'react_handler') results.internalActions++;
        else results.domEvents++;
        results.candidates++;
        results.approved++;
        results.modeContinuations++;
        results.audits.push({
          buttonTitle: title,
          decision: "continue_in_chat",
          reason: "保留 Chat 模式；拒绝切换到 Work/worker",
          clicked: true,
          ruleId: null,
          promptText: "Chat mode continuation"
        });
      } catch (_) {
        results.candidates++;
        results.blocked++;
      }
      break;
    }

    for (const btn of buttons) {
      const title = btn.innerText || btn.getAttribute('aria-label') || btn.getAttribute('title') || "";
      if (!isAllowTitle(title)) continue;

      let container = btn.parentElement;
      let foundReject = false;
      let contextText = "";
      let targetMessageId = null;
      let metadataBody = "";

      for (let i = 0; i < 15 && container; i++) {
        if (processedContainers.has(container)) break;
        const cText = container.innerText || "";
        const childBtns = Array.from(container.querySelectorAll('button, a, [role="button"]'));
        const hasReject = childBtns.some(b => isRejectTitle(b.innerText || b.getAttribute('aria-label') || b.getAttribute('title') || ""));

        let fiberKey = Object.keys(container).find(k => k.startsWith('__reactFiber$') || k.startsWith('__reactProps$'));
        if (fiberKey) {
          let currNode = container[fiberKey];
          for (let j = 0; j < 15 && currNode; j++) {
            const props = currNode.memoizedProps || currNode.props || {};
            const pluginData = props.jit_plugin_data || props.pluginData || (props.card && props.card.jit_plugin_data);
            if (pluginData && pluginData.from_server && pluginData.from_server.body) {
              metadataBody = typeof pluginData.from_server.body === 'string' ? pluginData.from_server.body : JSON.stringify(pluginData.from_server.body);
              if (pluginData.from_server.actions && pluginData.from_server.actions.allow_once) {
                targetMessageId = pluginData.from_server.actions.allow_once.target_message_id || pluginData.from_server.actions.allow_once.targetMessageId;
              }
            }
            if (props.targetMessageId || props.target_message_id) {
              targetMessageId = props.targetMessageId || props.target_message_id;
            }
            currNode = currNode.return;
          }
        }

        if (hasReject || cText.toLowerCase().includes('allow chatgpt to use') || cText.includes('允许') || targetMessageId || metadataBody) {
          foundReject = hasReject || Boolean(targetMessageId || metadataBody);
          contextText = cText;
          processedContainers.add(container);
          break;
        }
        container = container.parentElement;
      }

      if (foundReject && container) {
        results.candidates++;
        const matchRes = checkCardMatch(contextText, metadataBody);
        const auditPrompt = sanitizeContext(contextText || title);

        if (matchRes.match) {
          try {
            const internalMode = invokeInternalApproval(btn);
            if (internalMode === 'react_handler') results.internalActions++;
            else results.domEvents++;
            results.approved++;
            results.audits.push({
              buttonTitle: title,
              decision: "allow",
              reason: matchRes.reason + "；内部执行=" + internalMode,
              clicked: true,
              ruleId: matchRes.ruleId,
              promptText: auditPrompt
            });
          } catch (e) {
            results.blocked++;
            results.audits.push({
              buttonTitle: title,
              decision: "allow",
              reason: matchRes.reason,
              clicked: false,
              ruleId: matchRes.ruleId,
              promptText: auditPrompt,
              error: "ipc_click_failed"
            });
          }
        } else {
          results.unmatched++;
          results.audits.push({
            buttonTitle: title,
            decision: "noMatch",
            reason: matchRes.reason,
            clicked: false,
            ruleId: null,
            promptText: auditPrompt
          });
        }
      }
    }

    return results;
  })()
  """

  var totalCandidates = 0
  var totalApproved = 0
  var totalPending = 0
  var totalBlocked = 0
  var totalUnmatched = 0
  var totalInternalActions = 0
  var totalDOMEvents = 0
  let scannedTargetCount = pageTargets.count
  let scannedPorts = Array(Set(pageTargets.map(\.port))).sorted()

  for endpoint in pageTargets {
    guard let wsURL = endpoint.target["webSocketDebuggerUrl"] as? String else { continue }
    guard let evalRes = CDPClient.evaluate(wsURLString: wsURL, expression: jsScript),
          let result = evalRes["result"] as? [String: Any],
          let value = ((result["result"] as? [String: Any])?["value"] ?? result["value"]) as? [String: Any] else { continue }
    let c = value["candidates"] as? Int ?? 0
    let a = value["approved"] as? Int ?? 0
    let p = value["pending"] as? Int ?? 0
    let b = value["blocked"] as? Int ?? 0
    let u = value["unmatched"] as? Int ?? 0
    let internalActions = value["internalActions"] as? Int ?? 0
    let domEvents = value["domEvents"] as? Int ?? 0
    totalCandidates += c
    totalApproved += a
    totalPending += p
    totalBlocked += b
    totalUnmatched += u
    totalInternalActions += internalActions
    totalDOMEvents += domEvents

    if let audits = value["audits"] as? [[String: Any]] {
      for item in audits {
        let buttonTitle = item["buttonTitle"] as? String ?? ""
        let decision = item["decision"] as? String ?? ""
        let reason = item["reason"] as? String ?? ""
        let clicked = item["clicked"] as? Bool ?? false
        let ruleId = item["ruleId"] as? String
        let promptText = item["promptText"] as? String ?? ""
        let error = item["error"] as? String

        if !state.audit.contains(where: { $0.promptText == promptText && $0.decision == decision && $0.clicked == clicked && $0.reason == reason }) {
          state.audit.append(AuditEvent(
            at: isoFormatter.string(from: Date()),
            decision: decision,
            reason: reason,
            clicked: clicked,
            ruleId: ruleId,
            buttonTitle: buttonTitle,
            promptText: promptText,
            error: error
          ))
        }
      }
    }
  }

  if totalCandidates > 0 {
    if state.audit.count > 100 { state.audit.removeFirst(state.audit.count - 100) }
    state.lastError = nil
    return [
      "ok": true, "candidates": totalCandidates, "approved": totalApproved,
      "pending": totalPending, "blocked": totalBlocked, "unmatched": totalUnmatched,
      "backgroundOnly": true, "pageChanged": false, "ipcPrimaryPath": true,
      "hiddenTargetCount": scannedTargetCount,
      "loadedRendererCount": scannedTargetCount, "scannedPorts": scannedPorts,
      "internalActions": totalInternalActions, "domEvents": totalDOMEvents
    ]
  }
  if scannedTargetCount > 0 {
    state.lastError = nil
    return [
      "ok": true, "candidates": 0, "approved": 0, "pending": 0,
      "blocked": 0, "unmatched": 0, "backgroundOnly": true,
      "pageChanged": false, "ipcPrimaryPath": true,
      "hiddenTargetCount": scannedTargetCount,
      "loadedRendererCount": scannedTargetCount, "scannedPorts": scannedPorts,
    ]
  }
  return nil
}

private func decide(
  _ candidate: Candidate,
  rules: [ApprovalRule],
  approveAll: Bool,
  isFallback: Bool = true
) -> (String, String, ApprovalRule?) {
  let prefix = isFallback ? "AXPress 兼容回退：" : ""
  let normalized = candidate.promptText.lowercased()
  if approveAll {
    return ("allow", "\(prefix)通用模式：自动确认所有 ChatGPT 授权卡", nil)
  }
  for rule in rules where
    normalized.contains(rule.application.lowercased()) &&
    normalized.contains(rule.action.lowercased()) &&
    normalized.contains(rule.resource.lowercased()) {
    return ("allow", "\(prefix)命中精确允许规则 \(rule.id)", rule)
  }
  return ("noMatch", "未同时匹配应用、动作和资源", nil)
}

private func scan(_ state: inout PluginState) -> [String: Any] {
  // Hidden renderers are handled through IPC without route or focus changes.
  // AX is only a compatibility path for a genuinely visible approval card in
  // the active ChatGPT window. It must never press virtualized elements that
  // belong to a conversation the user has already left.
  let ipcResult = scanIPC(&state)
  let ipcCandidates = ipcResult?["candidates"] as? Int ?? 0
  let ipcApproved = ipcResult?["approved"] as? Int ?? 0
  let ipcPending = ipcResult?["pending"] as? Int ?? 0
  let ipcBlocked = ipcResult?["blocked"] as? Int ?? 0
  let ipcUnmatched = ipcResult?["unmatched"] as? Int ?? 0
  if ProcessInfo.processInfo.environment["CHATGPT_AUTO_CONFIRM_DISABLE_AX"] == "1",
     let ipcResult {
    return ipcResult
  }
  guard AXIsProcessTrusted() else {
    if let ipcResult { return ipcResult }
    state.lastError = "accessibility_required"
    return [
      "ok": false,
      "errorCode": "accessibility_required",
      "message": "请在系统设置的隐私与安全性 → 辅助功能中允许此插件；插件不会绕过 macOS 授权。",
    ]
  }
  guard state.approveAll == true || !state.rules.isEmpty else {
    return ["ok": false, "errorCode": "mode_required", "message": "尚未启用通用模式或配置精确允许规则"]
  }
  let found = candidates()
  reconcilePendingApprovals(&state, activeCandidates: found)
  var approved = 0
  var pending = 0
  var blocked = 0
  var unmatched = 0
  for candidate in found {
    if alreadyApproved(candidate, in: state) {
      continue
    }
    let (decision, reason, rule) = decide(
      candidate,
      rules: state.rules,
      approveAll: state.approveAll == true,
      isFallback: true
    )
    var clicked = false
    var activationError: String?
    var auditReason = reason
    if decision == "allow" {
      guard role(of: candidate.element) == kAXButtonRole as String,
            let currentContext = closestApprovalContext(for: candidate.element),
            currentContext == candidate.promptText,
            candidateStillPresent(candidate) else {
        blocked += 1
        activationError = "approval_candidate_changed"
        state.audit.append(AuditEvent(
          at: isoFormatter.string(from: Date()), decision: decision, reason: reason,
          clicked: false, ruleId: rule?.id, buttonTitle: candidate.buttonTitle,
          promptText: approvalAuditPrompt(candidate.promptText), error: activationError
        ))
        continue
      }
      let (actionSent, disappeared, clickError) = performApprovalClick(candidate)
      clicked = actionSent
      activationError = clickError
      if actionSent && disappeared {
        approved += 1
        auditReason = "\(reason)；\(verifiedApprovalMarker)"
      } else if actionSent {
        pending += 1
        auditReason = "\(reason)；\(pendingApprovalMarker)"
      } else {
        blocked += 1
      }
    } else { unmatched += 1 }
    state.audit.append(AuditEvent(
      at: isoFormatter.string(from: Date()), decision: decision, reason: auditReason,
      clicked: clicked, ruleId: rule?.id, buttonTitle: candidate.buttonTitle,
      promptText: approvalAuditPrompt(candidate.promptText), error: activationError
    ))
  }
  if state.audit.count > 100 { state.audit.removeFirst(state.audit.count - 100) }
  state.lastError = nil
  return [
    "ok": true, "candidates": ipcCandidates + found.count,
    "approved": ipcApproved + approved,
    "pending": ipcPending + pending,
    "blocked": ipcBlocked + blocked,
    "unmatched": ipcUnmatched + unmatched,
    "hiddenCandidates": ipcCandidates, "hiddenApproved": ipcApproved,
    "windowCandidates": found.count, "windowApproved": approved,
    "backgroundOnly": true, "pageChanged": false,
  ]
}

private func watcherIsAlive(_ pid: Int32?) -> Bool {
  guard let pid, pid > 1 else { return false }
  return kill(pid, 0) == 0
}

private func beginWatcherActivity(
  preventIdleSystemSleep: Bool,
  reason: String
) -> NSObjectProtocol {
  // Locking the screen must not put the queue watcher into App Nap. The queue
  // additionally prevents idle system sleep while work is running; the general
  // approval watcher allows normal sleep and resumes after wake.
  let options: ProcessInfo.ActivityOptions = preventIdleSystemSleep
    ? [.userInitiated, .latencyCritical, .idleSystemSleepDisabled]
    : [.userInitiatedAllowingIdleSystemSleep]
  return ProcessInfo.processInfo.beginActivity(options: options, reason: reason)
}

private func parseStartPayload() throws -> ([ApprovalRule], Int, [String], [String], Bool) {
  guard CommandLine.arguments.count >= 3,
        let data = CommandLine.arguments[2].data(using: .utf8),
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    throw NSError(domain: "chatgpt-auto-confirm", code: 1,
                  userInfo: [NSLocalizedDescriptionKey: "启动参数必须是 JSON 对象"])
  }
  let approveAll = object["approveAll"] as? Bool ?? true
  let rawRules = object["rules"] as? [[String: Any]] ?? []
  guard rawRules.count <= 20, approveAll || !rawRules.isEmpty else {
    throw NSError(domain: "chatgpt-auto-confirm", code: 1,
                  userInfo: [NSLocalizedDescriptionKey: "请启用 approveAll 或提供 1-20 条精确规则"])
  }
  var identities = Set<String>()
  let rules = try rawRules.enumerated().map { index, raw -> ApprovalRule in
    let application = (raw["application"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let action = (raw["action"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let resource = (raw["resource"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard [application, action, resource].allSatisfy({ !$0.isEmpty && $0 != "*" && $0 != ".*" && $0.count <= 256 }) else {
      throw NSError(domain: "chatgpt-auto-confirm", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "规则字段必须是精确文本"])
    }
    let identity = [application, action, resource].map { $0.lowercased() }.joined(separator: "\0")
    guard identities.insert(identity).inserted else {
      throw NSError(domain: "chatgpt-auto-confirm", code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "规则不能重复"])
    }
    return ApprovalRule(
      id: (raw["id"] as? String) ?? "rule-\(index + 1)",
      application: application, action: action, resource: resource
    )
  }
  let interval = min(5_000, max(400, object["intervalMs"] as? Int ?? 750))
  let chatTitles = (object["chatTitles"] as? [String] ?? []).map {
    $0.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  guard chatTitles.count <= 20,
        chatTitles.allSatisfy({ !$0.isEmpty && $0.count <= 256 }) else {
    throw NSError(domain: "chatgpt-auto-confirm", code: 4,
                  userInfo: [NSLocalizedDescriptionKey: "chatTitles 必须是最多 20 个精确任务标题"])
  }
  let rawChatURLs = object["chatUrls"] as? [String] ?? []
  let chatURLs = rawChatURLs.compactMap(normalizedChatURL)
  guard rawChatURLs.count <= 20, chatURLs.count == rawChatURLs.count else {
    throw NSError(domain: "chatgpt-auto-confirm", code: 5,
                  userInfo: [NSLocalizedDescriptionKey: "chatUrls 必须是最多 20 个 https://chatgpt.com/c/... 地址"])
  }
  return (rules, interval, chatTitles, chatURLs, approveAll)
}

private func statusPayload(_ state: PluginState) -> [String: Any] {
  let rulePayload = state.rules.map {
    ["id": $0.id, "application": $0.application, "action": $0.action, "resource": $0.resource]
  }
  let approvalTargets = loadedApprovalTargets(state)
  let approvalPorts = Array(Set(approvalTargets.map(\.port))).sorted()
  return [
    "ok": true,
    "running": state.enabled && watcherIsAlive(state.watcherPid),
    "enabled": state.enabled,
    "approveAll": state.approveAll == true,
    "accessibilityGranted": AXIsProcessTrusted(),
    "applicationRunning": !runningChatGptApplications().isEmpty,
    "rules": rulePayload,
    "chatTitles": state.chatTitles ?? [],
    "trackedChatURLs": state.trackedChatURLs ?? [],
    "hiddenTargetCount": approvalTargets.count,
    "loadedRendererCount": approvalTargets.count,
    "scannedPorts": approvalPorts,
    "backgroundChat": [
      "port": state.backgroundAppPort as Any,
      "targetId": state.backgroundChatTargetId as Any,
      "profilePath": state.backgroundProfilePath as Any,
      "conversationId": state.backgroundConversationId as Any,
      "connected": state.backgroundAppPort.map {
        !CDPClient.fetchTargets(portOverride: $0).isEmpty
      } ?? false,
      "surface": "chat",
      "workerUsed": false,
    ],
    "intervalMs": state.intervalMs,
    "auditCount": state.audit.count,
    "lastError": state.lastError as Any,
    "backgroundOnly": true,
    "ipc": [
      "cdp": CDPClient.checkStatus(),
      "unix": UnixIPCClient.checkStatus(),
      "primaryPath": "CDP WebSocket & Unix IPC 主路径",
      "fallbackPath": "AXPress 兼容回退",
    ],
    "safety": [
      "requiresApplicationActionAndResource": state.approveAll != true,
      "allRecognizedApprovalsEnabled": state.approveAll == true,
      "sensitiveActionsAlwaysBlocked": false,
      "dataLeavesDevice": false,
      "usesOnlyAccessibilityPress": false,
      "movesMouse": false,
      "activatesApplication": false,
      "navigatesTasks": false,
      "dismissesCoveringHistoryOverlay": true,
      "ipcIsPrimaryPath": true,
      "internalActionIsPrimary": true,
      "operatesHiddenPages": true,
      "scansEveryLoadedRenderer": true,
      "requiresPriorTracking": false,
      "changesVisiblePage": false,
      "axPressIsFallback": true,
      "axPressVisibleForegroundOnly": true,
      "axPressNeverTargetsHiddenElements": true,
    ],
  ]
}

private func diagnosticPayload() -> [String: Any] {
  let applications = runningChatGptApplications().map { application -> [String: Any] in
    let root = AXUIElementCreateApplication(application.processIdentifier)
    let buttons = descendants(of: root, matchingRole: kAXButtonRole as String)
    let elements = allDescendants(of: root)
    let menuItems = elements.compactMap { element -> [String: Any]? in
      guard role(of: element) == kAXMenuItemRole as String else { return nil }
      let text = accessibleString(element).trimmingCharacters(in: .whitespacesAndNewlines)
      guard !text.isEmpty else { return nil }
      return ["text": text, "actions": actionNames(of: element)]
    }
    let actionable = elements.compactMap { element -> [String: Any]? in
      let actions = actionNames(of: element)
      guard actions.contains(kAXPressAction as String) else { return nil }
      let elementRole = role(of: element)
      guard elementRole != kAXMenuItemRole as String &&
              elementRole != kAXMenuBarItemRole as String else { return nil }
      let text = accessibleString(element).trimmingCharacters(in: .whitespacesAndNewlines)
      let nested = text.isEmpty ? textContent(of: element, limit: 60) : text
      guard !nested.isEmpty else { return nil }
      return ["role": elementRole, "text": String(nested.prefix(300)), "actions": actions]
    }
    let matchedNodes = elements.compactMap { element -> [String: Any]? in
      let strings = diagnosticStrings(element)
      let rawValues = [
        kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute, kAXValueAttribute,
      ].map { stringAttribute(element, $0 as CFString) }
      guard rawValues.contains(where: {
        $0.contains("GitHub Actions 修复跟踪") || $0.contains("修复允许按钮识别") ||
          $0.contains("修复并跟踪 GitHub Actions") || $0.contains("GitHub连接DevSpace")
      }) else { return nil }
      var ancestry: [[String: Any]] = []
      var current: AXUIElement? = element
      for _ in 0..<14 {
        guard let node = current else { break }
        ancestry.append([
          "role": role(of: node), "strings": diagnosticStrings(node),
          "nestedText": String(textContent(of: node, limit: 100).prefix(500)),
          "actions": actionNames(of: node),
        ])
        current = parent(of: node)
      }
      return ["strings": strings, "ancestry": ancestry]
    }
    let allText = textContent(of: root, limit: 8_000)
    let relevantLines = allText.split(separator: "\n")
      .map(String.init)
      .filter { line in
        let normalized = line.lowercased()
        return normalized.contains("github") || normalized.contains("chatgpt") ||
          normalized.contains("allow") || normalized.contains("reject") ||
          normalized.contains("auto-merge") || normalized.contains("自动合并") ||
          normalized.contains("允许") || normalized.contains("拒绝")
      }
      .prefix(100)
    return [
      "bundleIdentifier": application.bundleIdentifier ?? "",
      "localizedName": application.localizedName ?? "",
      "processIdentifier": application.processIdentifier,
      "buttonCount": buttons.count,
      "buttonTitles": buttons.prefix(100).map(accessibleString),
      "menuItems": Array(menuItems.prefix(300)),
      "actionable": Array(actionable.prefix(200)),
      "matchedNodes": matchedNodes,
      "relevantText": Array(relevantLines),
    ]
  }
  return [
    "ok": true,
    "accessibilityGranted": AXIsProcessTrusted(),
    "applications": applications,
    "ipc": [
      "cdp": CDPClient.checkStatus(),
      "unix": UnixIPCClient.checkStatus(),
    ],
  ]
}

private func startWatcher(_ state: inout PluginState) throws {
  if watcherIsAlive(state.watcherPid), let pid = state.watcherPid { kill(pid, SIGTERM) }
  let process = Process()
  process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
  process.arguments = ["watch"]
  process.standardInput = FileHandle.nullDevice
  process.standardOutput = FileHandle.nullDevice
  process.standardError = FileHandle.nullDevice
  try process.run()
  state.watcherPid = process.processIdentifier
}

private func withWatcherLifecycleLock<T>(_ body: () throws -> T) throws -> T {
  let directory = stateURL().deletingLastPathComponent()
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let lockURL = directory.appendingPathComponent("watcher.lock")
  let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
  guard descriptor >= 0 else {
    throw NSError(
      domain: "chatgpt-auto-confirm",
      code: 6,
      userInfo: [NSLocalizedDescriptionKey: "无法创建授权 watcher 生命周期锁"]
    )
  }
  defer {
    _ = flock(descriptor, LOCK_UN)
    close(descriptor)
  }
  guard flock(descriptor, LOCK_EX) == 0 else {
    throw NSError(
      domain: "chatgpt-auto-confirm",
      code: 7,
      userInfo: [NSLocalizedDescriptionKey: "无法获取授权 watcher 生命周期锁"]
    )
  }
  return try body()
}

private func queueDirectoryURL() -> URL {
  queueStateURL().deletingLastPathComponent().appendingPathComponent("task-queue", isDirectory: true)
}

private let currentQueueRuntimeRevision = "mahayana.task-queue.v55"

private func queueStateURL() -> URL {
  if let override = ProcessInfo.processInfo.environment["CHATGPT_AUTO_CONFIRM_QUEUE_STATE"],
     !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    return URL(fileURLWithPath: override)
  }
  return stateURL().deletingLastPathComponent().appendingPathComponent("queue-state.json")
}

private func loadQueueState() -> PluginState {
  guard let data = try? Data(contentsOf: queueStateURL()),
        var state = try? decoder.decode(PluginState.self, from: data) else {
    return PluginState()
  }
  // `0` is the durable queue meaning for unlimited report-driven Chat
  // continuations. Migrate only the previous default on pre-v35 state; keep
  // explicit finite limits and all already-migrated task settings intact.
  if state.queueRuntimeRevision != currentQueueRuntimeRevision,
     var tasks = state.automationTasks {
    for index in tasks.indices where tasks[index].maxTaskContinuations == 8 {
      tasks[index].maxTaskContinuations = 0
    }
    state.automationTasks = tasks
  }
  return state
}

private func saveQueueState(_ state: PluginState) throws {
  try writePluginState(state, to: queueStateURL())
}

private func withQueueStateLock<T>(
  _ body: (inout PluginState) throws -> T
) throws -> T {
  let directory = queueStateURL().deletingLastPathComponent()
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let lockURL = directory.appendingPathComponent("queue.lock")
  let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
  guard descriptor >= 0 else {
    throw NSError(
      domain: "chatgpt-auto-confirm",
      code: 20,
      userInfo: [NSLocalizedDescriptionKey: "无法创建任务队列状态锁"]
    )
  }
  defer {
    _ = flock(descriptor, LOCK_UN)
    close(descriptor)
  }
  guard flock(descriptor, LOCK_EX) == 0 else {
    throw NSError(
      domain: "chatgpt-auto-confirm",
      code: 21,
      userInfo: [NSLocalizedDescriptionKey: "无法获取任务队列状态锁"]
    )
  }
  var state = loadQueueState()
  let result = try body(&state)
  try saveQueueState(state)
  return result
}

private func writePluginState(_ state: PluginState, to url: URL) throws {
  try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try encoder.encode(state).write(to: url, options: .atomic)
}

private func normalizedTaskId(_ rawValue: String?) -> String? {
  guard let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
        !value.isEmpty,
        value.range(
          of: "^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$",
          options: .regularExpression
        ) != nil else { return nil }
  return value
}

private func normalizedConnector(_ rawValue: String?) -> String? {
  guard let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
        !value.isEmpty,
        value.count <= 256,
        !value.contains("\n"),
        !value.contains("\r") else { return nil }
  return value
}

private struct QueueNetworkProbe {
  let reachable: Bool
  let detail: String
}

private func queueNetworkProbe() -> QueueNetworkProbe {
  guard let reachability = SCNetworkReachabilityCreateWithName(nil, "api.github.com") else {
    return QueueNetworkProbe(reachable: false, detail: "无法创建 GitHub 网络探测")
  }
  var flags = SCNetworkReachabilityFlags()
  guard SCNetworkReachabilityGetFlags(reachability, &flags) else {
    return QueueNetworkProbe(reachable: false, detail: "无法读取 GitHub 网络路由")
  }
  let isReachable = flags.contains(.reachable)
  let needsConnection = flags.contains(.connectionRequired)
  let canConnectAutomatically = flags.contains(.connectionOnDemand)
    || flags.contains(.connectionOnTraffic)
  let online = isReachable && (!needsConnection || canConnectAutomatically)
  return QueueNetworkProbe(
    reachable: online,
    detail: online ? "GitHub 网络路由可达" : "GitHub 网络路由暂不可达（flags=\(flags.rawValue)）"
  )
}

private func networkRecoverySignal(_ value: String) -> String? {
  let text = value.lowercased()
  let markers = [
    "network is unreachable", "network unreachable", "err_internet_disconnected",
    "internet disconnected", "could not resolve host", "dns lookup failed",
    "connection reset", "connection refused", "connection timed out",
    "upstream 502", "http 502", "http 503", "http 504",
    "devspace_tool_timeout", "网络断开", "网络不可用", "无法解析主机",
    "连接被重置", "连接超时", "上游 502", "上游 503", "上游 504"
  ]
  guard let marker = markers.first(where: { text.contains($0) }) else { return nil }
  return marker
}

private func queueNetworkRecovery(
  _ task: inout AutomationTask,
  state: inout PluginState,
  reason: String
) {
  // Use the regular continuation reset so the next operation is always a
  // fresh Chat, then defer only that continuation while connectivity recovers.
  queueContinuation(&task, report: nil, reason: "network_recovery")
  guard task.status == "queued" else { return }
  let failureCount = min(6, (state.queueNetworkFailureCount ?? 0) + 1)
  let delay = min(300, 30 * (1 << min(3, failureCount - 1)))
  let dueDate = Date().addingTimeInterval(Double(delay))
  let compactReason = String(reason.prefix(240))
  state.queueNetworkFailureCount = failureCount
  state.queueNetworkStatus = "waiting_for_recovery"
  state.queueNetworkLastError = compactReason
  state.queueNetworkWaitUntil = isoFormatter.string(from: dueDate)
  task.status = "waiting"
  task.waitingUntil = state.queueNetworkWaitUntil
  task.waitReason = "网络/上游连接恢复：\(compactReason)；将在约 \(delay) 秒后重新探测"
  task.reviewFeedback = "小程序检测到网络、DNS 或上游连接异常（\(compactReason)）。不要重复当前失败请求；等待小程序恢复连接后在新 Chat 中检查同一 checkout 的落盘结果，再继续未完成步骤。"
  task.lastError = "waiting_for_network_recovery"
  task.updatedAt = isoFormatter.string(from: Date())
}

private func taskPromptPrefix(_ template: String) -> String {
  switch template {
  case "implement-and-verify":
    return "请在当前 checkout 中完成下面的实现任务，检查现有改动后继续，运行与风险相称的验证，不要覆盖无关改动："
  case "diagnose-fix-verify":
    return "请先用现有代码、日志和测试定位根因，然后修复并完成回归验证；不要只给建议："
  case "review-and-fix":
    return "请审查当前 checkout 中与目标相关的实现，修正发现的真实问题并完成验证："
  default:
    return "请从当前 checkout 的已有进度继续，不要从头开始；持续工作直到以下目标和验收条件全部满足："
  }
}

private func chatOnlyInstruction(_ value: String) -> String {
  value
    .split(separator: "\n", omittingEmptySubsequences: false)
    .map(String.init)
    .filter { line in
      let normalized = line.lowercased()
      return !normalized.contains("worker")
        && !normalized.contains("work/worker")
        && !normalized.contains("work 模式")
        && !normalized.contains("work mode")
        && !normalized.contains("转交 work")
        && !normalized.contains("continue in work")
    }
    .joined(separator: "\n")
    .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func automationTaskMessage(_ task: AutomationTask) -> String {
  var sections = [
    taskPromptPrefix(task.promptTemplate),
    "模型要求：执行复杂开发、发布、修复和验收任务时，优先选择 GPT-5.6 Sol 模型，并将推理强度设置为 High。不要自动降级到低推理模式；若模型选择失败，继续尝试选择目标模型后再开始工作。",
    "执行边界：实际工作只允许在 Chat 页面完成；不要点击或进入 Work 页面。",
    "连接器路由：当前新 Chat 选用「\(task.connector)」。已在云端 GitHub 的代码、仓库、PR、Actions、构件、发布和合并状态必须使用 GitHub 连接器；不要改用本地 gh 来替代云端证据。本地 checkout、Git/gh 元数据与安全同步必须使用 bhrum2；同步前先读取 status、远端和分支，只允许干净工作树上的 fast-forward，不得覆盖本地改动。若本轮从 bhrum2 推送到云端，最终报告 next_connector 填 GitHub，让小程序为下一新 Chat 切换到 GitHub 连接器。",
    "资源策略：项目的测试、构建、打包、安装、发布验证和安装包生成一律在 GitHub Actions 中执行并以 Actions 日志或构件为准。本机只做 Git/gh 元数据与代码阅读；不要在本机运行任何项目测试、构建、打包、安装、依赖下载或会生成缓存/产物的命令。",
    "提交策略：提交前逐项选择源代码、配置和必要文档，禁止 git add -A。不要提交或等待上传无关的大文件、缓存、node_modules、构建输出、本地安装包或无关 LFS 对象；除非某个大文件是任务明确必需的发布资产。",
    "持续执行规则：不要在说明『下一步要做什么』后停止，也不要只汇报阶段性进度。没有完成目标不要停，一直工作下去直到实现目标！直接执行所有可行步骤，持续处理失败、评审意见、Actions、部署和构件检查，直到原始目标真正完成。",
    "等待规则：对于 GitHub Actions、部署、发布审核、网络恢复或其他需要时间跑的异步操作，Chat 会话必须自己运行 bash `sleep` 睡眠命令（例如执行 `sleep 60`）。睡眠之后起来看是否完成，还没有完成就继续执行 sleep 睡眠等待直到有结果，然后立刻继续；绝对不要用回复等待秒数、预计时间或让用户稍后再来结束本轮。",
    "遇到重复卡点时不要只重复同一条失败命令：先诊断根因并尝试可行的替代路径（本机工具、备用命令、认证方式或连接方式）。只有出现当前权限与工具确实无法绕过的真实阻塞，或平台硬性终止本次会话时，才允许结束未完成任务，并在未完成续作模板中准确列出所需权限、账号、工具、环境变量、具体命令或外部恢复条件。",
    task.prompt
  ]
  sections.append("任务发送轮次：\(task.attempts + 1)。")
  if let rawFeedback = task.reviewFeedback {
    let feedback = chatOnlyInstruction(rawFeedback)
    if !feedback.isEmpty {
      sections.append("上一轮验收未通过。必须修正以下问题后重新完成全部验证：\n\(feedback)")
    }
  }
  sections.append("任务编号：\(task.id)。完成后请在最终总结中给出可复核的修改、未完成项、卡点和验证结果。")
  return sections.joined(separator: "\n\n")
}

private func automationReviewMessage(
  _ task: AutomationTask,
  report: AutomationTaskReport
) -> String {
  let completed = chatOnlyInstruction(report.completed.joined(separator: "；"))
  let verification = chatOnlyInstruction(report.verification.joined(separator: "；"))
  let summary = chatOnlyInstruction(report.summary)
  return """
  这是任务 \(task.id) 的独立验收 Chat。请在当前 checkout 中只做复核，不要凭上一轮 Chat 的自报结果认定完成，也不要覆盖或重置任何改动。验收必须在 Chat 页面完成，不要进入 Work 页面。

  原任务：
  \(task.prompt)

  验收 Chat 标识：\(task.id)-\(task.attempts)-\(task.reviewRound)

  被验收 Chat 的总结：\(summary)
  已完成项：\(completed)
  被验收 Chat 的验证：\(verification)

  请检查工作树、关键实现、Git/GitHub/Actions 或发布构件等与任务目标相关的证据。云端 GitHub 状态必须通过 GitHub 连接器核验；本地 checkout 仅通过 bhrum2 读取或安全同步。重型测试、构建和安装包验证必须以 GitHub Actions 结果为准，不要在本机生成构建产物。若 Actions、部署、发布审核或网络恢复仍在进行，必须留在这个验收 Chat 内自行等待并轮询，拿到结果后继续验收，不得回复等待时间后退出。重复卡点不能只照抄旧错误，应诊断并换可行路径。只有全部目标可复核且验证通过时，最后单独输出一行 `MAHAYANA_REVIEW_ACCEPTED`；不要输出完成态 JSON。若验收不通过，输出未完成续作模板，准确写出 remaining、blockers、verification 和 next_task，供小程序新建工作 Chat 继续；只有真实不可绕过的阻塞才可使用 blocked。
  """
}

private func startAutomationReview(
  _ task: inout AutomationTask,
  report: AutomationTaskReport,
  port: Int,
  targetId: String
) -> Bool {
  guard let prepared = prepareNewChatTarget(
    port: port,
    targetId: targetId,
    timeout: 6.0,
    allowBlankConversationReuse: true
  ), prepared["ok"] as? Bool == true else {
    return false
  }
  let outbound = messageWithTaskReportContract(automationReviewMessage(task, report: report))
  guard let sendResult = cdpValue(
    port: port,
    targetId: targetId,
    expression: sendMessageJS(message: outbound, connector: task.connector, newChat: false),
    timeout: 35.0
  ), sendResult["ok"] as? Bool == true else {
    return false
  }
  _ = cdpValue(
    port: port,
    targetId: targetId,
    expression: autoConfirmChatContinuationJS(),
    timeout: 4.0
  )
  let dispatchMarker = "验收 Chat 标识：\(task.id)-\(task.attempts)-\(task.reviewRound)"
  let resolvedConversation = cdpValue(
    port: port,
    targetId: targetId,
    expression: resolveDispatchedConversationJS(
      dispatchMarker: dispatchMarker,
      localConversationId: normalizedConversationId(prepared["conversationId"] as? String)
    ),
    timeout: 24.0
  )
  let resolvedConversationId = normalizedConversationId(
    resolvedConversation?["conversationId"] as? String
  )
  task.reviewConversationId = resolvedConversationId
    ?? normalizedConversationId(prepared["conversationId"] as? String)
  task.reviewStatus = "running"
  task.lastError = nil
  task.lastActivitySignature = nil
  task.lastProgressAt = isoFormatter.string(from: Date())
  task.updatedAt = task.lastProgressAt ?? isoFormatter.string(from: Date())
  return true
}

private func dependencyCycle(in tasks: [AutomationTask]) -> [String]? {
  let graph = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.dependsOn) })
  var visiting = Set<String>()
  var visited = Set<String>()
  var stack: [String] = []
  func visit(_ id: String) -> [String]? {
    if visiting.contains(id), let start = stack.firstIndex(of: id) {
      return Array(stack[start...]) + [id]
    }
    if visited.contains(id) { return nil }
    visiting.insert(id)
    stack.append(id)
    for dependency in graph[id] ?? [] {
      if let cycle = visit(dependency) { return cycle }
    }
    _ = stack.popLast()
    visiting.remove(id)
    visited.insert(id)
    return nil
  }
  for id in graph.keys {
    if let cycle = visit(id) { return cycle }
  }
  return nil
}

private func automationReport(_ raw: Any?) -> AutomationTaskReport? {
  guard let raw = raw as? [String: Any],
        JSONSerialization.isValidJSONObject(raw),
        let data = try? JSONSerialization.data(withJSONObject: raw),
        let report = try? decoder.decode(AutomationTaskReport.self, from: data),
        report.protocolName == "mahayana.task-report.v1",
        ["complete", "incomplete", "blocked"].contains(report.status) else { return nil }
  return report
}

private func decodeLastJSONLine(at path: String?) -> (String, [String: Any])? {
  guard let path,
        let data = FileManager.default.contents(atPath: path),
        let text = String(data: data, encoding: .utf8) else { return nil }
  for line in text.split(whereSeparator: \Character.isNewline).reversed() {
    let raw = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
    guard let lineData = raw.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
          object["event"] == nil else { continue }
    return (raw, object)
  }
  return nil
}

private func taskPublicPayload(_ task: AutomationTask, includeResult: Bool = false) -> [String: Any] {
  var payload: [String: Any] = [
    "id": task.id,
    "title": task.title,
    "status": task.status,
    "promptTemplate": task.promptTemplate,
    "connector": task.connector,
    "dependsOn": task.dependsOn,
    "resourceLocks": task.resourceLocks,
    "priority": task.priority,
    "attempts": task.attempts,
    "maxRuntimeRetries": task.maxRuntimeRetries,
    "reviewRound": task.reviewRound,
    "createdAt": task.createdAt,
    "updatedAt": task.updatedAt,
    "startedAt": task.startedAt as Any,
    "finishedAt": task.finishedAt as Any,
    "workerPid": task.workerPid as Any,
    "workerPort": task.workerPort as Any,
    "workerTargetId": task.workerTargetId as Any,
    "workerProfilePath": task.workerProfilePath as Any,
    "conversationId": task.conversationId as Any,
    "reviewConversationId": task.reviewConversationId as Any,
    "reviewStatus": task.reviewStatus as Any,
    "chatUrl": task.chatURL as Any,
    "lastError": task.lastError as Any,
    "reviewFeedback": task.reviewFeedback as Any,
    "reviewedAt": task.reviewedAt as Any,
    "continuationDepth": task.continuationDepth ?? 0,
    "lastProgressAt": task.lastProgressAt as Any,
    "hiddenWorkerLastHeartbeatAt": task.hiddenWorkerLastHeartbeatAt as Any,
    "hiddenWorkerRecoveryCount": task.hiddenWorkerRecoveryCount ?? 0,
    "hiddenWorkerLastError": task.hiddenWorkerLastError as Any,
    "waitingUntil": task.waitingUntil as Any,
    "waitReason": task.waitReason as Any,
  ]
  if let report = task.report,
     let reportData = try? encoder.encode(report),
     let reportObject = try? JSONSerialization.jsonObject(with: reportData) {
    payload["report"] = reportObject
  }
  if let report = task.reviewReport,
     let reportData = try? encoder.encode(report),
     let reportObject = try? JSONSerialization.jsonObject(with: reportData) {
    payload["reviewReport"] = reportObject
  }
  if includeResult, let raw = task.lastResultJSON,
     let data = raw.data(using: .utf8),
     let result = try? JSONSerialization.jsonObject(with: data) {
    payload["result"] = result
  }
  return payload
}

private func queueStatusPayload(_ state: PluginState) -> [String: Any] {
  let tasks = state.automationTasks ?? []
  var counts: [String: Int] = [:]
  for task in tasks { counts[task.status, default: 0] += 1 }
  let attention = tasks.filter {
    ["awaiting_review", "blocked", "failed"].contains($0.status)
  }
  let workerRuntimeState: QueueTargetRuntimeState?
  let workerIsHidden: Bool
  if queueUsesBackgroundWindow(state),
     let port = state.queueWorkerPort,
     let targetId = state.queueWorkerTargetId {
    let runtimeState = queueTargetRuntimeState(
      port: port,
      targetId: targetId,
      refreshLifecycle: false
    )
    workerRuntimeState = runtimeState
    workerIsHidden = runtimeState == .hidden
  } else {
    workerRuntimeState = nil
    workerIsHidden = false
  }
  return [
    "ok": true,
    "enabled": state.queueEnabled == true,
    "paused": state.queuePaused == true,
    "running": state.queueEnabled == true && watcherIsAlive(state.queueWatcherPid),
    "watcherPid": state.queueWatcherPid as Any,
    "maxConcurrent": state.queueMaxConcurrent ?? 2,
    "effectiveMaxConcurrent": 1,
    "requestedMaxConcurrent": state.queueMaxConcurrent ?? 2,
    "executionMode": "single-authenticated-process-hidden-prewarm-serialized",
    "targetMode": state.queueWorkerMode ?? "not-started",
    "network": [
      "status": state.queueNetworkStatus ?? "unknown",
      "lastError": state.queueNetworkLastError as Any,
      "failureCount": state.queueNetworkFailureCount ?? 0,
      "waitingUntil": state.queueNetworkWaitUntil as Any,
    ],
    "workerProcess": [
      "port": state.queueWorkerPort as Any,
      "targetId": state.queueWorkerTargetId as Any,
      "profilePath": state.queueWorkerProfilePath as Any,
      "mode": state.queueWorkerMode as Any,
      "sharedProcess": queueUsesBackgroundWindow(state),
      "sameApplicationProcess": queueUsesBackgroundWindow(state),
      "isolatedFromVisiblePage": workerIsHidden,
      "visibilityVerified": workerIsHidden,
      "runtimeState": workerRuntimeState.map(queueTargetRuntimeStateName) ?? "not-started",
      "separateApplicationProcess": false,
    ],
    "reviewGate": state.queueReviewGate != false,
    "counts": counts,
    "tasks": tasks.map { taskPublicPayload($0) },
    "attention": attention.map { taskPublicPayload($0, includeResult: true) },
    "recoverable": true,
    "statePath": queueStateURL().path,
  ]
}

private func startQueueWatcher(_ state: inout PluginState) throws {
  if watcherIsAlive(state.queueWatcherPid),
     state.queueRuntimeRevision == currentQueueRuntimeRevision { return }
  if watcherIsAlive(state.queueWatcherPid), let pid = state.queueWatcherPid {
    kill(pid, SIGTERM)
    Thread.sleep(forTimeInterval: 0.1)
  }
  let process = Process()
  process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
  process.arguments = ["queue_watch"]
  process.standardInput = FileHandle.nullDevice
  process.standardOutput = FileHandle.nullDevice
  process.standardError = FileHandle.nullDevice
  var environment = ProcessInfo.processInfo.environment
  environment["CHATGPT_AUTO_CONFIRM_STATE"] = queueStateURL().path
  environment["CHATGPT_AUTO_CONFIRM_QUEUE_STATE"] = queueStateURL().path
  process.environment = environment
  try process.run()
  state.queueWatcherPid = process.processIdentifier
  state.queueRuntimeRevision = currentQueueRuntimeRevision
}

private let backgroundWindowQueueWorkerMode = "single-process-hidden-prewarm"
private let legacyIsolatedQueueWorkerMode = "isolated-dedicated-process"

private enum QueueTargetRuntimeState {
  case missing
  case hidden
  case hiddenNonChat
  case visible
  case suspended
}

private func queueUsesBackgroundWindow(_ state: PluginState) -> Bool {
  state.queueWorkerMode == backgroundWindowQueueWorkerMode
}

private func queueTargetRuntimeState(
  port: Int,
  targetId: String,
  refreshLifecycle: Bool
) -> QueueTargetRuntimeState {
  guard let target = CDPClient.fetchTargets(portOverride: port).first(where: {
    $0["id"] as? String == targetId
  }), let wsURL = target["webSocketDebuggerUrl"] as? String else {
    return .missing
  }
  let expression = """
  (async () => {
    const startedAt = performance.now();
    await new Promise(resolve => setTimeout(resolve, 50));
    const textarea = document.querySelector('#prompt-textarea')
      || document.querySelector('[contenteditable="true"]');
    const workComposer = !!document.querySelector('[data-codex-composer="true"]');
    const chatModel = [...document.querySelectorAll('button')].some(button => {
      const label = button.getAttribute('aria-label') || '';
      return label.includes('ChatGPT 模型') || /select chatgpt model/i.test(label);
    });
    const webChat = location.protocol === 'https:' && location.hostname === 'chatgpt.com';
    const chatMode = (chatModel || webChat) && !!textarea && !workComposer;
    return {
      bridge: !!window.electronBridge,
      visibility: document.visibilityState,
      href: location.href,
      eventLoopDelayMs: performance.now() - startedAt,
      chatMode,
      surface: chatMode ? 'chat' : 'not-chat'
    };
  })()
  """
  let initial = cdpValue(
    port: port,
    targetId: targetId,
    expression: expression,
    timeout: 3.0
  )
  if initial?["visibility"] as? String == "visible" {
    return .visible
  }
  if refreshLifecycle {
    _ = wakeHiddenRenderer(port: port, targetId: targetId, wsURL: wsURL)
  }
  let probe = refreshLifecycle
    ? cdpValue(port: port, targetId: targetId, expression: expression, timeout: 3.0)
    : initial
  if probe?["visibility"] as? String == "visible" {
    return .visible
  }
  let bridge = (probe?["bridge"] as? NSNumber)?.boolValue ?? false
  let visibility = probe?["visibility"] as? String
  let href = probe?["href"] as? String ?? ""
  let eventLoopDelayMs = (probe?["eventLoopDelayMs"] as? NSNumber)?.doubleValue
    ?? Double.greatestFiniteMagnitude
  if bridge && visibility == "hidden" && href.hasPrefix("app://-/index.html")
      && eventLoopDelayMs < 2_500 {
    let chatMode = (probe?["chatMode"] as? NSNumber)?.boolValue ?? false
    let surface = probe?["surface"] as? String ?? "not-chat"
    return chatMode && surface == "chat" ? .hidden : .hiddenNonChat
  }
  return .suspended
}

private func queueTargetRuntimeStateName(_ state: QueueTargetRuntimeState) -> String {
  switch state {
  case .missing: return "missing"
  case .hidden: return "hidden-chat"
  case .hiddenNonChat: return "hidden-not-chat"
  case .visible: return "visible"
  case .suspended: return "suspended"
  }
}

private func queueTargetIsHidden(port: Int, targetId: String) -> Bool {
  queueTargetRuntimeState(
    port: port,
    targetId: targetId,
    refreshLifecycle: false
  ) == .hidden
}

private func generalApprovalStateForQueue() -> PluginState? {
  let url = queueStateURL().deletingLastPathComponent().appendingPathComponent("state.json")
  guard let data = try? Data(contentsOf: url) else { return nil }
  return try? decoder.decode(PluginState.self, from: data)
}

private func sharedChatController(
  _ state: inout PluginState
) -> (port: Int, targetId: String, profilePath: String)? {
  let general = generalApprovalStateForQueue()
  let port = general?.backgroundAppPort ?? state.backgroundAppPort ?? hiddenChatPort(state)
  let profilePath = general?.backgroundProfilePath
    ?? state.backgroundProfilePath
    ?? hiddenChatProfilePath()
  let preferredTargetIds = [
    general?.backgroundChatTargetId,
    state.backgroundChatTargetId,
  ].compactMap { $0 }
  let targets = CDPClient.fetchTargets(portOverride: port)
  let orderedTargets = targets.sorted { lhs, rhs in
    let lhsId = lhs["id"] as? String ?? ""
    let rhsId = rhs["id"] as? String ?? ""
    return (preferredTargetIds.firstIndex(of: lhsId) ?? Int.max)
      < (preferredTargetIds.firstIndex(of: rhsId) ?? Int.max)
  }
  for target in orderedTargets {
    guard target["type"] as? String == "page",
          (target["url"] as? String ?? "").hasPrefix("app://-/index.html"),
          let targetId = target["id"] as? String,
          targetId != state.queueWorkerTargetId else { continue }
    let probe = cdpValue(
      port: port,
      targetId: targetId,
      expression: "(() => ({bridge: !!window.electronBridge, buttons: document.querySelectorAll('button').length}))()",
      timeout: 3.0
    )
    let bridge = (probe?["bridge"] as? NSNumber)?.boolValue ?? false
    let buttons = (probe?["buttons"] as? NSNumber)?.intValue ?? 0
    guard bridge, buttons > 5 else { continue }
    state.backgroundAppPort = port
    state.backgroundChatTargetId = targetId
    state.backgroundProfilePath = profilePath
    return (port, targetId, profilePath)
  }
  guard let prepared = ensureHiddenChatTarget(&state),
        prepared["ok"] as? Bool == true,
        let port = prepared["port"] as? Int,
        let targetId = prepared["targetId"] as? String else { return nil }
  return (port, targetId, prepared["profilePath"] as? String ?? hiddenChatProfilePath())
}

private func quickChatPrewarmServiceJS(_ action: String) -> String {
  let actionLiteral = jsonStringLiteral(action)
  return #"""
  (async () => {
    try {
      const action = \#(actionLiteral);
      const entryURL = [...document.scripts]
        .map(script => script.src)
        .find(src => src && /\/assets\/index-[^/]+\.js$/.test(src));
      if (!entryURL) return {ok: false, error: 'app_entry_module_not_found'};
      const entrySource = await (await fetch(entryURL)).text();
      // Desktop bundles changed from the long shared-chunk name to compact
      // `app-initial-<hash>.js` names in July 2026. Discover every matching
      // app-initial module instead of coupling queue startup to one generated
      // filename. Keep the legacy pattern as a fallback for older releases.
      const serviceModulePaths = [...new Set([
        ...[...entrySource.matchAll(
          /["'](\.\/app-initial-[^"']+\.js)["']/g
        )].map(match => match[1]),
        ...[...entrySource.matchAll(
          /["'](\.\/app-initial~[^"']+\.js)["']/g
        )].map(match => match[1]),
      ])];
      if (serviceModulePaths.length === 0) {
        return {ok: false, error: 'quick_chat_service_module_not_found'};
      }
      let services = null;
      let moduleURL = null;
      for (const serviceModulePath of serviceModulePaths) {
        const candidateURL = new URL(serviceModulePath, entryURL).href;
        const serviceModule = await import(candidateURL);
        const candidate = Object.values(serviceModule).find(value => {
          try {
            return value != null
              && typeof value === 'object'
              && typeof value.quickChatWindow?.prewarm === 'function'
              && String(value.quickChatWindow) === '[object RpcStub]';
          } catch {
            return false;
          }
        });
        if (candidate) {
          services = candidate;
          moduleURL = candidateURL;
          break;
        }
      }
      if (!services) {
        return {
          ok: false,
          error: 'quick_chat_service_not_found',
          modulePaths: serviceModulePaths
        };
      }
      if (action === 'reset-prewarm') {
        await services.quickChatWindow.clearPrewarm();
        await services.quickChatWindow.prewarm();
      } else if (action === 'renderer-ready') {
        await services.quickChatWindow.rendererReady(null);
      } else if (action === 'clear-prewarm') {
        await services.quickChatWindow.clearPrewarm();
      } else {
        return {ok: false, error: 'unsupported_quick_chat_action'};
      }
      return {
        ok: true,
        action,
        moduleURL,
        href: location.href,
        visibility: document.visibilityState
      };
    } catch (error) {
      return {
        ok: false,
        error: String(error),
        stack: error?.stack || ''
      };
    }
  })()
  """#
}

private func openBackgroundQueueWindow(
  port: Int,
  controllerTargetId: String
) -> String? {
  let existingTargetIds = Set(CDPClient.fetchTargets(portOverride: port).compactMap {
    $0["id"] as? String
  })
  guard existingTargetIds.contains(controllerTargetId),
        cdpValue(
          port: port,
          targetId: controllerTargetId,
          expression: quickChatPrewarmServiceJS("reset-prewarm"),
          timeout: 8.0
        )?["ok"] as? Bool == true else { return nil }

  var targetId: String?
  for _ in 0..<100 {
    targetId = CDPClient.fetchTargets(portOverride: port).compactMap { target -> String? in
      guard let id = target["id"] as? String,
            !existingTargetIds.contains(id),
            target["type"] as? String == "page",
            (target["url"] as? String ?? "").contains("quick-chat-prewarm") else { return nil }
      return id
    }.first
    if targetId != nil { break }
    Thread.sleep(forTimeInterval: 0.05)
  }
  guard let targetId else { return nil }

  // ChatGPT's prewarm controller closes a renderer that has not reported
  // readiness within 15 seconds. A hidden prewarm route does not always mount
  // its normal React page, so acknowledge it explicitly through that
  // renderer's own app-host service before navigating it to the full app.
  var prewarmLoaded = false
  var acknowledged = false
  for _ in 0..<100 {
    let prewarmReady = cdpValue(
      port: port,
      targetId: targetId,
      expression: "(() => ({bridge: !!window.electronBridge, ready: document.readyState, visibility: document.visibilityState, href: location.href}))()",
      timeout: 3.0
    )
    if (prewarmReady?["bridge"] as? NSNumber)?.boolValue == true,
       prewarmReady?["ready"] as? String == "complete",
       prewarmReady?["visibility"] as? String == "hidden",
       (prewarmReady?["href"] as? String ?? "").contains("quick-chat-prewarm") {
      prewarmLoaded = true
      break
    }
    Thread.sleep(forTimeInterval: 0.05)
  }
  guard prewarmLoaded else {
    _ = CDPClient.closeTarget(targetId, portOverride: port)
    return nil
  }
  // In current desktop builds the prewarm renderer can report document
  // readiness before its RPC client is fully registered with the main
  // process. The measured stable handoff needs roughly 1.8 seconds.
  Thread.sleep(forTimeInterval: 1.8)
  for _ in 0..<100 {
    let result = cdpValue(
      port: port,
      targetId: targetId,
      expression: quickChatPrewarmServiceJS("renderer-ready"),
      timeout: 8.0
    )
    if result?["ok"] as? Bool == true,
       result?["visibility"] as? String == "hidden" {
      acknowledged = true
      break
    }
    Thread.sleep(forTimeInterval: 0.05)
  }
  guard acknowledged else {
    _ = CDPClient.closeTarget(targetId, portOverride: port)
    return nil
  }
  // Let the main process consume rendererReady before replacing the prewarm
  // route. Navigating immediately can leave the quick-chat shell unclaimed.
  Thread.sleep(forTimeInterval: 1.0)
  guard
        let target = CDPClient.fetchTargets(portOverride: port).first(where: {
          $0["id"] as? String == targetId
        }),
        let wsURL = target["webSocketDebuggerUrl"] as? String,
        CDPClient.navigate(wsURLString: wsURL, url: "app://-/index.html") else {
    _ = CDPClient.closeTarget(targetId, portOverride: port)
    return nil
  }
  // Electron deprioritizes show:false pages so aggressively that the Chat
  // surface may need over a minute to mount. Keep the actual BrowserWindow
  // hidden while asking Chromium to run this renderer at active lifecycle
  // priority. document.visibilityState remains hidden and is rechecked below.
  Thread.sleep(forTimeInterval: 0.5)
  guard wakeHiddenRenderer(port: port, targetId: targetId, wsURL: wsURL) else {
    _ = CDPClient.closeTarget(targetId, portOverride: port)
    return nil
  }

  // A show:false renderer is intentionally deprioritized by Electron. On
  // current ChatGPT builds the full Chat surface can take more than 30 seconds
  // to mount even though its document and preload bridge are already ready.
  for _ in 0..<600 {
    let ready = cdpValue(
      port: port,
      targetId: targetId,
      expression: "(() => ({bridge: !!window.electronBridge, buttons: document.querySelectorAll('button').length, text: (document.body?.innerText || '').length, visibility: document.visibilityState, href: location.href}))()",
      timeout: 3.0
    )
    let bridge = (ready?["bridge"] as? NSNumber)?.boolValue ?? false
    let buttons = (ready?["buttons"] as? NSNumber)?.intValue ?? 0
    let textLength = (ready?["text"] as? NSNumber)?.intValue ?? 0
    let visibility = ready?["visibility"] as? String
    let href = ready?["href"] as? String
    if bridge,
       buttons > 5,
       textLength > 100,
       visibility == "hidden",
       href == "app://-/index.html" {
      return targetId
    }
    Thread.sleep(forTimeInterval: 0.1)
  }
  _ = CDPClient.closeTarget(targetId, portOverride: port)
  return nil
}

private func createQueueWorkerTarget(
  _ state: inout PluginState
) -> (port: Int, targetId: String, profilePath: String)? {
  // General confirmation and the task queue share one authenticated ChatGPT
  // application process. The queue owns a different BrowserWindow created by
  // ChatGPT's show:false prewarm path, so it never appears, focuses, or changes
  // the primary window where the user clicks New Chat or types a prompt.
  if let port = state.queueWorkerPort,
     let targetId = state.queueWorkerTargetId,
     queueUsesBackgroundWindow(state),
     queueTargetIsHidden(port: port, targetId: targetId) {
    return (port, targetId, state.queueWorkerProfilePath ?? "")
  }
  if state.queueWorkerMode == legacyIsolatedQueueWorkerMode,
     let profilePath = state.queueWorkerProfilePath {
    terminateDedicatedChatProcess(profilePath: profilePath)
  }
  state.queueWorkerPort = nil
  state.queueWorkerTargetId = nil
  state.queueWorkerProfilePath = nil
  state.queueWorkerMode = nil

  guard let controller = sharedChatController(&state) else { return nil }
  var openedTargetId: String?
  // Electron occasionally leaves a show:false renderer at its startup shell
  // even after lifecycle activation. Discard that page and retry the official
  // prewarm path; retries stay in the same process and never touch the primary
  // window.
  for _ in 0..<3 {
    if let candidate = openBackgroundQueueWindow(
      port: controller.port,
      controllerTargetId: controller.targetId
    ), candidate != controller.targetId {
      openedTargetId = candidate
      break
    }
    Thread.sleep(forTimeInterval: 0.5)
  }
  guard let targetId = openedTargetId else { return nil }
  state.queueWorkerPort = controller.port
  state.queueWorkerTargetId = targetId
  state.queueWorkerProfilePath = controller.profilePath
  state.queueWorkerMode = backgroundWindowQueueWorkerMode
  return (controller.port, targetId, controller.profilePath)
}

private func stopQueueWorker(_ state: inout PluginState) {
  // Close only the hidden queue window. The primary window and the shared
  // ChatGPT process remain available to the user and the general confirmer.
  if queueUsesBackgroundWindow(state) {
    if let targetId = state.queueWorkerTargetId {
      _ = CDPClient.closeTarget(targetId, portOverride: state.queueWorkerPort)
    }
  } else if state.queueWorkerMode == legacyIsolatedQueueWorkerMode,
            let profilePath = state.queueWorkerProfilePath {
    terminateDedicatedChatProcess(profilePath: profilePath)
  }
  state.queueWorkerPort = nil
  state.queueWorkerTargetId = nil
  state.queueWorkerProfilePath = nil
  state.queueWorkerMode = nil
}

private func startAutomationTask(
  _ task: inout AutomationTask,
  state: inout PluginState
) throws {
  // All queued tasks use one hidden renderer inside the user's existing
  // authenticated ChatGPT process. The renderer is intentionally single-owner:
  // task concurrency is represented by the durable queue, while page work is
  // serialized so tasks and review Chats never clobber one another's composer.
  var prepared: [String: Any]?
  var port: Int?
  var targetId: String?
  var workerProfilePath: String?
  guard let worker = createQueueWorkerTarget(&state) else {
    throw NSError(
      domain: "chatgpt-auto-confirm",
      code: 33,
      userInfo: [NSLocalizedDescriptionKey: "当前 ChatGPT 实例没有可用的隐藏 Chat 页面"]
    )
  }
  port = worker.port
  targetId = worker.targetId
  workerProfilePath = worker.profilePath
  prepared = prepareNewChatTarget(
    port: worker.port,
    targetId: worker.targetId,
    timeout: 4.0,
    allowBlankConversationReuse: true
  )
  guard let prepared,
        prepared["ok"] as? Bool == true,
        let port,
        let targetId else {
    throw NSError(
      domain: "chatgpt-auto-confirm",
      code: 22,
      userInfo: [NSLocalizedDescriptionKey: "无法为任务 \(task.id) 准备已登录隐藏 Chat"]
    )
  }
  let attempt = task.attempts + 1
  let outbound = messageWithTaskReportContract(automationTaskMessage(task))
  guard let sendResult = cdpValue(
    port: port,
    targetId: targetId,
    expression: sendMessageJS(message: outbound, connector: task.connector, newChat: false),
    timeout: 65.0
  ) else {
    throw NSError(
      domain: "chatgpt-auto-confirm",
      code: 23,
      userInfo: [NSLocalizedDescriptionKey: "任务 \(task.id) 未能取得页面发送结果（CDP 上下文可能正在切换）"]
    )
  }
  guard sendResult["ok"] as? Bool == true else {
    let stage = sendResult["failedStage"] as? String ?? "unknown"
    let error = sendResult["error"] as? String ?? "unknown"
    let candidates = (sendResult["candidateTexts"] as? [String])?.joined(separator: ", ") ?? ""
    throw NSError(
      domain: "chatgpt-auto-confirm",
      code: 23,
      userInfo: [NSLocalizedDescriptionKey: "任务 \(task.id) 页面发送失败（\(stage): \(error)） candidates: \(candidates)"]
    )
  }
  _ = cdpValue(
    port: port,
    targetId: targetId,
    expression: autoConfirmChatContinuationJS(),
    timeout: 4.0
  )
  let dispatchMarker = "任务发送轮次：\(attempt)"
  let resolvedConversation = cdpValue(
    port: port,
    targetId: targetId,
    expression: resolveDispatchedConversationJS(
      dispatchMarker: dispatchMarker,
      localConversationId: normalizedConversationId(prepared["conversationId"] as? String)
    ),
    timeout: 24.0
  )
  let resolvedConversationId = normalizedConversationId(
    resolvedConversation?["conversationId"] as? String
  )
  Thread.sleep(forTimeInterval: 0.5)
  let liveStatus = cdpValue(
    port: port, targetId: targetId, expression: chatStatusJS(), timeout: 5.0
  ) ?? [:]
  // The freshly prepared blank Chat owns a stable local id before the sidebar
  // title appears. Prefer it over transitional active-row data after send.
  let conversationId = resolvedConversationId
    ?? (prepared["conversationId"] as? String)
    ?? (sendResult["conversationId"] as? String)
    ?? (liveStatus["conversationId"] as? String)
  guard let conversationId = normalizedConversationId(conversationId) else {
    throw NSError(
      domain: "chatgpt-auto-confirm",
      code: 32,
      userInfo: [NSLocalizedDescriptionKey: "任务 \(task.id) 已发送但未取得会话 ID"]
    )
  }

  let now = isoFormatter.string(from: Date())
  task.attempts = attempt
  task.status = "running"
  task.updatedAt = now
  task.startedAt = now
  task.finishedAt = nil
  task.workerPid = nil
  task.workerPort = port
  task.workerTargetId = targetId
  task.workerStatePath = nil
  task.workerProfilePath = workerProfilePath
  task.reviewConversationId = nil
  task.reviewStatus = nil
  task.reviewReport = nil
  task.resultPath = nil
  task.conversationId = conversationId
  task.chatURL = conversationId.hasPrefix("local-chatgpt:")
    ? nil
    : liveStatus["chatUrl"] as? String
  task.lastError = nil
  task.waitingUntil = nil
  task.waitReason = nil
  task.report = nil
  task.lastResultJSON = jsonString(sendResult)
  task.lastActivitySignature = nil
  task.lastProgressAt = now
}

private func terminateDedicatedChatProcess(profilePath: String) {
  guard profilePath.contains("/task-queue/workers/") else { return }
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
  process.arguments = ["-TERM", "-f", "--user-data-dir=\(profilePath)"]
  process.standardInput = FileHandle.nullDevice
  process.standardOutput = FileHandle.nullDevice
  process.standardError = FileHandle.nullDevice
  try? process.run()
  process.waitUntilExit()
  Thread.sleep(forTimeInterval: 0.2)
  try? FileManager.default.removeItem(atPath: profilePath)
}

private func stopAutomationWorker(_ task: AutomationTask) {
  if let statePath = task.workerStatePath,
     let data = FileManager.default.contents(atPath: statePath),
     let workerState = try? decoder.decode(PluginState.self, from: data),
     watcherIsAlive(workerState.watcherPid),
     let pid = workerState.watcherPid {
    kill(pid, SIGTERM)
  }
  if let targetId = task.workerTargetId {
    _ = CDPClient.closeTarget(targetId, portOverride: task.workerPort)
  }
  if let profilePath = task.workerProfilePath {
    terminateDedicatedChatProcess(profilePath: profilePath)
  }
}

private func closeDedicatedAutomationTarget(
  _ task: AutomationTask,
  state: PluginState
) {
  // The dedicated target belongs to the queue, not to an individual task.
  // Keep it alive for the next queued task and release it only when the queue
  // reaches a terminal state (runQueueIteration calls stopQueueWorker).
  _ = task
  _ = state
}

private func finishAutomationTask(_ task: inout AutomationTask) {
  let now = isoFormatter.string(from: Date())
  defer {
    stopAutomationWorker(task)
    task.workerPid = nil
    task.updatedAt = now
    task.finishedAt = task.status == "queued" ? nil : now
  }
  guard let (raw, result) = decodeLastJSONLine(at: task.resultPath) else {
    if task.attempts <= task.maxRuntimeRetries {
      task.status = "queued"
      task.finishedAt = nil
      task.lastError = "worker_exited_without_result"
    } else {
      task.status = "failed"
      task.lastError = "worker_exited_without_result"
    }
    return
  }
  task.lastResultJSON = raw
  task.report = automationReport(result["taskReport"])
  task.conversationId = result["conversationId"] as? String
  task.chatURL = result["chatUrl"] as? String
  let taskStatus = result["taskStatus"] as? String ?? task.report?.status
  if result["ok"] as? Bool == true && taskStatus == "complete" {
    task.status = "awaiting_review"
    task.lastError = nil
    return
  }
  if taskStatus == "incomplete" || taskStatus == "blocked" {
    task.status = "blocked"
    task.lastError = result["message"] as? String
      ?? result["errorCode"] as? String
      ?? "任务总结报告未完成"
    return
  }
  if task.attempts <= task.maxRuntimeRetries {
    task.status = "queued"
    task.finishedAt = nil
    task.lastError = result["message"] as? String
      ?? result["errorCode"] as? String
      ?? "worker_runtime_failed"
  } else {
    task.status = "failed"
    task.lastError = result["message"] as? String
      ?? result["errorCode"] as? String
      ?? "worker_runtime_failed"
  }
}

private func taskReportFingerprint(_ report: AutomationTaskReport) -> String {
  [report.summary, report.remaining.joined(separator: "\n"),
   report.blockers.joined(separator: "\n"), report.nextTask]
    .joined(separator: "|")
    .lowercased()
    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
}

private func queueContinuation(
  _ task: inout AutomationTask,
  report: AutomationTaskReport?,
  reason: String
) {
  let now = isoFormatter.string(from: Date())
  let depth = task.continuationDepth ?? 0
  if task.maxTaskContinuations > 0 && depth >= task.maxTaskContinuations {
    task.status = "blocked"
    task.lastError = "task_continuation_limit_reached"
    task.updatedAt = now
    task.finishedAt = now
    return
  }
  if let report {
    if let requestedConnector = normalizedConnector(report.nextConnector) {
      task.connector = requestedConnector
    }
    let fingerprint = taskReportFingerprint(report)
    var fingerprints = task.reportFingerprints ?? []
    fingerprints.append(fingerprint)
    task.reportFingerprints = Array(fingerprints.suffix(100))
    let requestedWait = min(604_800, max(0, report.waitSeconds ?? 0))
    let waitReason = (report.waitReason ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    task.reviewFeedback = "上一个 Chat 报告任务未完成。请从同一 checkout 的现有进度继续，完成以下续作，不要从头开始：\n\(report.nextTask)\n\n上轮摘要：\(report.summary)\n剩余：\(report.remaining.joined(separator: "；"))\n卡点：\(report.blockers.joined(separator: "；"))"
    if requestedWait > 0 {
      let dueDate = Date().addingTimeInterval(Double(max(30, requestedWait)))
      task.waitingUntil = isoFormatter.string(from: dueDate)
      task.waitReason = waitReason
      task.reviewFeedback = (task.reviewFeedback ?? "")
        + "\n\n上一轮预计需要等待 \(requestedWait) 秒（\(waitReason)）。小程序已等待到期；现在请先复查外部结果，再继续未完成步骤。"
      task.status = "waiting"
      task.lastError = "waiting_for_external_result"
    } else {
      task.waitingUntil = nil
      task.waitReason = nil
      task.status = "queued"
      task.lastError = reason
    }
  } else {
    task.reviewFeedback = "上一个 Chat 因 \(reason) 未能给出有效完整报告。请先检查同一 checkout 的最新落盘进度与正在运行的操作，只补做剩余步骤，完成全部目标和验证后按机器模板总结。"
    task.waitingUntil = nil
    task.waitReason = nil
    task.status = "queued"
    task.lastError = reason
  }
  task.continuationDepth = depth + 1
  task.updatedAt = now
  task.startedAt = nil
  task.finishedAt = nil
  task.workerPid = nil
  task.report = nil
  task.reviewConversationId = nil
  task.reviewStatus = nil
  task.reviewReport = nil
  task.lastActivitySignature = nil
  task.lastProgressAt = nil
}

private func monitorAutomationTask(
  _ task: inout AutomationTask,
  state: inout PluginState
) {
  let monitoringReview = task.reviewStatus == "running"
  let activeConversationId = monitoringReview ? task.reviewConversationId : task.conversationId
  guard let conversationId = activeConversationId else {
    queueContinuation(&task, report: nil, reason: "missing_conversation_id")
    return
  }
  // Do not restore the background queue renderer before its current page is read. A new
  // Chat may receive a durable remote id before the virtualized body/sidebar
  // has caught up; the dispatch marker below is the reliable proof that the
  // visible page is still this task. Manual conversation drift is handled
  // after that marker check, without blocking a just-sent response.
  state.approveAll = true
  var workerPort = task.workerPort ?? state.queueWorkerPort
  var workerTargetId = task.workerTargetId ?? state.queueWorkerTargetId
  if !queueUsesBackgroundWindow(state) || workerPort == nil || workerTargetId == nil {
    if let recoveredWorker = createQueueWorkerTarget(&state) {
      workerPort = recoveredWorker.port
      workerTargetId = recoveredWorker.targetId
      task.workerPort = recoveredWorker.port
      task.workerTargetId = recoveredWorker.targetId
      task.workerProfilePath = recoveredWorker.profilePath
      task.hiddenWorkerRecoveryCount = (task.hiddenWorkerRecoveryCount ?? 0) + 1
      task.hiddenWorkerLastError = nil
    }
  }
  guard let initialPort = workerPort, let initialTargetId = workerTargetId else {
    task.hiddenWorkerLastError = "queue_monitor_requires_background_window"
    task.lastError = task.hiddenWorkerLastError
    task.updatedAt = isoFormatter.string(from: Date())
    return
  }
  var port = initialPort
  var targetId = initialTargetId
  var runtimeState = queueTargetRuntimeState(
    port: port,
    targetId: targetId,
    refreshLifecycle: true
  )
  if runtimeState == .hiddenNonChat {
    // A hidden prewarm page may survive an internal app reload on Work. Ask
    // that hidden page to return to Chat before treating the renderer as lost.
    _ = cdpValue(
      port: port,
      targetId: targetId,
      expression: clickChatJS(),
      timeout: 4.0
    )
    runtimeState = queueTargetRuntimeState(
      port: port,
      targetId: targetId,
      refreshLifecycle: true
    )
  }
  if runtimeState != .hidden {
    if runtimeState == .visible {
      // Safety is fail-closed only for a genuinely visible page. Never close,
      // navigate, confirm, stop, or type in a page the user may be operating.
      state.queuePaused = true
      task.hiddenWorkerLastError = "queue_worker_visibility_not_hidden"
      task.lastError = task.hiddenWorkerLastError
      task.updatedAt = isoFormatter.string(from: Date())
      return
    }

    // Missing, suspended, and hidden-but-not-Chat renderers are disposable
    // queue-owned pages. Close any stale target, recreate ChatGPT's official
    // show:false prewarm BrowserWindow, and verify hidden Chat again.
    let failedRuntimeState = queueTargetRuntimeStateName(runtimeState)
    stopQueueWorker(&state)
    guard let recoveredWorker = createQueueWorkerTarget(&state) else {
      task.hiddenWorkerLastError = "queue_monitor_hidden_target_rebuild_failed:\(failedRuntimeState)"
      task.lastError = task.hiddenWorkerLastError
      task.updatedAt = isoFormatter.string(from: Date())
      return
    }
    port = recoveredWorker.port
    targetId = recoveredWorker.targetId
    task.workerPort = recoveredWorker.port
    task.workerTargetId = recoveredWorker.targetId
    task.workerProfilePath = recoveredWorker.profilePath
    task.hiddenWorkerRecoveryCount = (task.hiddenWorkerRecoveryCount ?? 0) + 1

    if conversationId.hasPrefix("local-chatgpt:") {
      // A reclaimed local-only Chat has no durable route to restore. The page
      // is already rebuilt and verified hidden; continue the task in a fresh
      // Chat that explicitly resumes from the same checkout instead of waiting
      // forever on an identity that no longer exists.
      task.hiddenWorkerLastError = "queue_monitor_hidden_target_recreated_without_durable_conversation"
      queueContinuation(
        &task,
        report: nil,
        reason: "queue_monitor_hidden_target_recreated_without_durable_conversation"
      )
      return
    }

    let restored = navigateHiddenConversation(
      port: port,
      targetId: targetId,
      conversationId: conversationId
    )
    runtimeState = queueTargetRuntimeState(
      port: port,
      targetId: targetId,
      refreshLifecycle: true
    )
    guard restored, runtimeState == .hidden else {
      stopQueueWorker(&state)
      task.hiddenWorkerLastError = "queue_monitor_hidden_target_recovery_failed"
      queueContinuation(
        &task,
        report: nil,
        reason: "queue_monitor_hidden_target_recovery_failed"
      )
      return
    }
  }
  task.hiddenWorkerLastHeartbeatAt = isoFormatter.string(from: Date())
  task.hiddenWorkerLastError = nil
  // A permission card can replace the normal conversation body temporarily.
  // Confirm it before restoring a task through its exact hidden-page route, so
  // an unloaded conversation cannot suppress automatic authorization.
  _ = cdpValue(
    port: port,
    targetId: targetId,
    expression: autoApproveDedicatedAuthorizationJS(),
    timeout: 4.0
  )
  let now = isoFormatter.string(from: Date())
  guard var liveStatus = cdpValue(
          port: port, targetId: targetId, expression: chatStatusJS(), timeout: 5.0) else {
    task.lastError = "queue_monitor_cdp_failed"
    task.updatedAt = isoFormatter.string(from: Date())
    return
  }
  guard let reply = cdpValue(
          port: port, targetId: targetId, expression: getReplyJS(), timeout: 6.0) else {
    task.lastError = "queue_monitor_cdp_failed"
    task.updatedAt = now
    return
  }
  // The hidden queue renderer can still drift after an internal reload. Never
  // parse a stale page as the active task or create a continuation/review Chat
  // from it. Restoring here is safe because this process has no user composer.
  if let observed = normalizedConversationId(liveStatus["conversationId"] as? String),
     observed != conversationId {
    // In the desktop app the active conversation pane can be rendered outside
    // `<main>`, while `<main>` contains only the title/share chrome. Include
    // the scoped user bubbles so a freshly sent dispatch marker is not missed.
    let pageContent = [
      reply["pageContent"] as? String ?? "",
      reply["userContent"] as? String ?? "",
    ].joined(separator: "\n")
    let dispatchMarker = monitoringReview
      ? "验收 Chat 标识：\(task.id)-\(task.attempts)-\(task.reviewRound)"
      : "任务发送轮次：\(task.attempts)"
    if pageContent.contains(dispatchMarker) {
      // ChatGPT may replace the local id with its durable remote id after the
      // first response begins. The per-dispatch marker proves this is still
      // the current Chat, not a manually selected older attempt.
      // A virtualized sidebar can keep an older row marked current while the
      // new local Chat is already streaming. Only a route/portal identity is
      // authoritative enough to replace that local id; an active-row-only id
      // must not bind the task to the stale sidebar conversation.
      let identitySource = liveStatus["conversationSource"] as? String
      let canPromoteLocalId = !conversationId.hasPrefix("local-chatgpt:")
        || identitySource == "route"
        || identitySource == "portal"
      if canPromoteLocalId {
        if !monitoringReview {
          task.conversationId = observed
          task.chatURL = liveStatus["chatUrl"] as? String
        } else {
          task.reviewConversationId = observed
        }
      }
    } else {
      // A just-created Chat starts with a local id while ChatGPT replaces the
      // sidebar and body asynchronously. It is not evidence of a manual
      // switch. Wait for the dispatch marker instead of pausing every queued
      // task; recover in one fresh Chat only if that binding never arrives.
      if conversationId.hasPrefix("local-chatgpt:") {
        if let startedAt = task.lastProgressAt.flatMap(isoFormatter.date(from:)),
           Date().timeIntervalSince(startedAt) >= 45 {
          queueContinuation(&task, report: nil, reason: "fresh_chat_body_pending_timeout")
        } else {
          task.lastError = "queue_monitor_conversation_body_pending"
          task.updatedAt = now
        }
        return
      }
      let restoredOK = navigateHiddenConversation(
        port: port,
        targetId: targetId,
        conversationId: conversationId
      )
      if restoredOK,
         let statusAfterRestore = cdpValue(
           port: port, targetId: targetId, expression: chatStatusJS(), timeout: 5.0),
         let restoredId = normalizedConversationId(statusAfterRestore["conversationId"] as? String),
         restoredId == conversationId {
        liveStatus = statusAfterRestore
      } else {
        // This hidden renderer is owned solely by the queue, so a failed
        // restore is a disposable renderer fault rather than user navigation.
        // Recreate it inside the same app process and continue from checkout.
        stopQueueWorker(&state)
        queueContinuation(&task, report: nil, reason: "queue_monitor_conversation_drift")
        return
      }
    }
  }
  _ = cdpValue(
    port: port,
    targetId: targetId,
    expression: autoConfirmChatContinuationJS(),
    timeout: 4.0
  )
  _ = cdpValue(
    port: port,
    targetId: targetId,
    expression: autoApproveDedicatedAuthorizationJS(),
    timeout: 4.0
  )
  task.lastError = nil
  // A new local id is the authoritative identity. The sidebar can keep the
  // previous row marked current briefly, so never replace a local id with
  // transitional remote metadata from that stale row.
  if !monitoringReview && task.conversationId?.hasPrefix("local-chatgpt:") != true,
     let resolved = normalizedConversationId(liveStatus["conversationId"] as? String),
     !resolved.hasPrefix("local-chatgpt:") {
    task.conversationId = resolved
  }
  if !monitoringReview && task.conversationId?.hasPrefix("local-chatgpt:") != true,
     let chatURL = liveStatus["chatUrl"] as? String {
    task.chatURL = chatURL
  }
  let activitySignature = reply["activitySignature"] as? String ?? ""
  let activityCharCount = reply["activityCharCount"] as? Int ?? 0
  if !activitySignature.isEmpty && activitySignature != task.lastActivitySignature {
    task.lastActivitySignature = activitySignature
    // Page virtualization can temporarily replace the full task stream with
    // only the conversation title and Share/Sources chrome. Record the new
    // signature so it does not churn, but do not treat that regression as
    // real task progress or postpone interruption recovery.
    if activityCharCount >= 80 {
      task.lastProgressAt = now
      state.queueNetworkFailureCount = 0
      state.queueNetworkStatus = "online"
      state.queueNetworkLastError = nil
      state.queueNetworkWaitUntil = nil
    }
  }
  task.updatedAt = now
  task.lastResultJSON = jsonString([
    monitoringReview ? "reviewReply" : "reply": reply,
    "conversationId": conversationId,
    "chatUrl": task.chatURL as Any,
    "reviewConversationId": task.reviewConversationId as Any,
  ])

  // A sent Chat that never creates any assistant or tool activity is not a
  // long-running build. It is a failed renderer/send state. Recover quickly
  // in a fresh Chat instead of accumulating 20-minute title-only stalls.
  let hasAssistantActivity = (reply["messageCount"] as? Int ?? 0) > 0
    || !(reply["content"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    || !(reply["devspaceActivity"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  let isStreaming = reply["streaming"] as? Bool == true
  let isPending = reply["pending"] as? Bool == true
  if !hasAssistantActivity, !isStreaming, isPending,
     let lastProgressAt = task.lastProgressAt.flatMap(isoFormatter.date(from:)),
     Date().timeIntervalSince(lastProgressAt) >= 90 {
    if queueUsesBackgroundWindow(state) {
      stopQueueWorker(&state)
    }
    queueContinuation(&task, report: nil, reason: "chat_start_no_reply")
    return
  }

  let completedActivity = reply["completedActivity"] as? String ?? ""
  let visibleContent = reply["content"] as? String ?? ""
  let connectionText = [
    visibleContent,
    completedActivity,
    reply["devspaceActivity"] as? String ?? "",
    // `pageContent` also contains the queue's own user instruction, which
    // deliberately documents network errors. Inspect only assistant/tool
    // activity so the prompt can never trigger a false network outage.
    reply["thinking"] as? String ?? ""
  ].joined(separator: "\n")
  if let signal = networkRecoverySignal(connectionText) {
    closeDedicatedAutomationTarget(task, state: state)
    queueNetworkRecovery(&task, state: &state, reason: signal)
    return
  }
  let reportText = completedActivity.isEmpty ? visibleContent : completedActivity
  let parsedReport = parseTaskReport(reportText).flatMap(automationReport)
  let terminalIncomplete = reply["terminalIncomplete"] as? Bool == true
    || reply["explicitlyIncomplete"] as? Bool == true
  let terminal = reply["done"] as? Bool == true
    || reply["completionCandidate"] as? Bool == true
    || terminalIncomplete
  if terminal, let report = parsedReport {
    if let requestedConnector = normalizedConnector(report.nextConnector) {
      task.connector = requestedConnector
    }
    if monitoringReview {
      task.reviewReport = report
      task.reviewStatus = report.status
      if report.status == "complete" {
        task.status = "completed"
        task.lastError = nil
        task.finishedAt = now
        task.reviewedAt = now
      } else {
        task.reviewConversationId = nil
        task.reviewStatus = nil
        queueContinuation(&task, report: report, reason: "chat_review_\(report.status)")
      }
      return
    }
    task.report = report
    if report.status == "complete" {
      guard startAutomationReview(
        &task,
        report: report,
        port: port,
        targetId: targetId
      ) else {
        task.status = "blocked"
        task.lastError = "chat_review_start_failed"
        task.finishedAt = now
        return
      }
      task.status = "running"
      task.lastError = nil
      task.finishedAt = nil
    } else {
      closeDedicatedAutomationTarget(task, state: state)
      queueContinuation(&task, report: report, reason: "chat_finished_\(report.status)")
    }
    return
  }
  if terminal {
    if terminalIncomplete {
      closeDedicatedAutomationTarget(task, state: state)
      queueContinuation(&task, report: nil, reason: "unfinished_reply_missing_continuation_report")
      return
    }
    let normalResult = reportText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalResult.isEmpty else {
      closeDedicatedAutomationTarget(task, state: state)
      queueContinuation(&task, report: nil, reason: "empty_terminal_reply")
      return
    }
    let acceptedResult = AutomationTaskReport(
      protocolName: "mahayana.task-report.v1",
      status: "complete",
      summary: normalResult,
      completed: [],
      remaining: [],
      blockers: [],
      verification: [],
      nextTask: "",
      waitSeconds: 0,
      waitReason: "",
      nextConnector: nil
    )
    if monitoringReview {
      guard normalResult.contains("MAHAYANA_REVIEW_ACCEPTED") else {
        closeDedicatedAutomationTarget(task, state: state)
        queueContinuation(&task, report: nil, reason: "review_result_missing_acceptance_marker")
        return
      }
      task.reviewReport = acceptedResult
      task.reviewStatus = "complete"
      task.status = "completed"
      task.lastError = nil
      task.finishedAt = now
      task.reviewedAt = now
      return
    }
    task.report = acceptedResult
    guard startAutomationReview(
      &task,
      report: acceptedResult,
      port: port,
      targetId: targetId
    ) else {
      task.status = "blocked"
      task.lastError = "chat_review_start_failed"
      task.finishedAt = now
      return
    }
    task.status = "running"
    task.lastError = nil
    task.finishedAt = nil
    return
  }

  if let lastProgressAt = task.lastProgressAt.flatMap(isoFormatter.date(from:)),
     Date().timeIntervalSince(lastProgressAt) >= 1200 {
    _ = cdpValue(
      port: port, targetId: targetId, expression: stopCurrentResponseJS(), timeout: 12.0)
    if queueUsesBackgroundWindow(state) {
      // A stall belongs to the hidden, queue-owned renderer. Recreate that
      // never-shown prewarm window for the next Chat; never touch the primary.
      stopQueueWorker(&state)
    }
    closeDedicatedAutomationTarget(task, state: state)
    queueContinuation(&task, report: nil, reason: "page_stalled")
  }
}

private func stopLegacyQueueResponseIfStillOwned(
  _ task: AutomationTask,
  state: PluginState
) {
  guard let port = task.workerPort ?? state.queueWorkerPort,
        let targetId = task.workerTargetId ?? state.queueWorkerTargetId,
        let reply = cdpValue(
          port: port,
          targetId: targetId,
          expression: getReplyJS(),
          timeout: 5.0
        ) else { return }
  let dispatchMarker = task.reviewStatus == "running"
    ? "验收 Chat 标识：\(task.id)-\(task.attempts)-\(task.reviewRound)"
    : "任务发送轮次：\(task.attempts)"
  let pageContent = reply["pageContent"] as? String ?? ""
  guard pageContent.contains(dispatchMarker) else {
    // The user or another controller has already changed this renderer. Do
    // not stop, select, focus, or otherwise mutate the newly visible page.
    return
  }
  _ = cdpValue(
    port: port,
    targetId: targetId,
    expression: stopCurrentResponseJS(),
    timeout: 12.0
  )
}

private func runQueueIteration(_ state: inout PluginState) {
  var tasks = state.automationTasks ?? []
  let now = isoFormatter.string(from: Date())
  let currentDate = Date()
  if state.queueWorkerMode != nil && !queueUsesBackgroundWindow(state) {
    // Migrate pre-v41 queues without touching a borrowed visible renderer. Any
    // running Chat is converted to a report-aware fresh continuation so the
    // new hidden queue window first checks what already landed in checkout.
    for index in tasks.indices
      where tasks[index].status == "running" && tasks[index].workerPid == nil {
      stopLegacyQueueResponseIfStillOwned(tasks[index], state: state)
      queueContinuation(
        &tasks[index],
        report: nil,
        reason: "queue_worker_background_window_migration"
      )
    }
    if state.queueWorkerMode == legacyIsolatedQueueWorkerMode,
       let profilePath = state.queueWorkerProfilePath {
      terminateDedicatedChatProcess(profilePath: profilePath)
    }
    state.queueWorkerPort = nil
    state.queueWorkerTargetId = nil
    state.queueWorkerProfilePath = nil
    state.queueWorkerMode = nil
  }
  let network = queueNetworkProbe()
  if !network.reachable {
    state.queueNetworkStatus = "offline"
    state.queueNetworkLastError = network.detail
    if let runningIndex = tasks.firstIndex(where: { $0.status == "running" }) {
      closeDedicatedAutomationTarget(tasks[runningIndex], state: state)
      queueNetworkRecovery(&tasks[runningIndex], state: &state, reason: network.detail)
    }
    state.automationTasks = tasks
    return
  }
  if state.queueNetworkStatus == "offline" {
    state.queueNetworkStatus = "online"
    state.queueNetworkLastError = nil
  }
  for index in tasks.indices where tasks[index].status == "waiting" {
    guard let waitingUntil = tasks[index].waitingUntil.flatMap(isoFormatter.date(from:)) else {
      tasks[index].status = "queued"
      tasks[index].waitReason = nil
      tasks[index].updatedAt = now
      continue
    }
    guard currentDate >= waitingUntil else { continue }
    tasks[index].status = "queued"
    tasks[index].waitingUntil = nil
    tasks[index].waitReason = nil
    tasks[index].lastError = nil
    tasks[index].updatedAt = now
  }
  for index in tasks.indices where tasks[index].status == "running" {
    if tasks[index].workerPid != nil {
      if watcherIsAlive(tasks[index].workerPid) { continue }
      finishAutomationTask(&tasks[index])
    } else {
      monitorAutomationTask(&tasks[index], state: &state)
    }
  }

  guard state.queueEnabled == true, state.queuePaused != true else {
    state.automationTasks = tasks
    return
  }
  if tasks.isEmpty {
    state.queueEnabled = false
    stopQueueWorker(&state)
    state.automationTasks = tasks
    return
  }
  let terminalStatuses = Set(["completed", "cancelled", "failed"])
  if !tasks.isEmpty && tasks.allSatisfy({ terminalStatuses.contains($0.status) }) {
    state.queueEnabled = false
    stopQueueWorker(&state)
    state.automationTasks = tasks
    return
  }
  if state.queueReviewGate != false && tasks.contains(where: {
    ["awaiting_review", "blocked"].contains($0.status)
  }) {
    state.automationTasks = tasks
    return
  }

  // One authenticated ChatGPT process owns the renderer. Keep queue state
  // concurrent-safe, but serialize page work so tasks cannot overwrite one
  // another's composer or require another Electron process.
  let maxConcurrent = 1
  var runningCount = tasks.filter { $0.status == "running" }.count
  var heldLocks = Set(tasks.filter { $0.status == "running" }.flatMap(\.resourceLocks))
  var statuses = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.status) })
  for index in tasks.indices where tasks[index].status == "queued" {
    let failedDependencies = tasks[index].dependsOn.filter {
      ["blocked", "failed", "cancelled"].contains(statuses[$0] ?? "")
    }
    if !failedDependencies.isEmpty {
      tasks[index].status = "blocked"
      tasks[index].lastError = "dependency_not_completed:\(failedDependencies.joined(separator: ","))"
      tasks[index].updatedAt = now
      statuses[tasks[index].id] = "blocked"
    }
  }
  let candidates = tasks.indices
    .filter { tasks[$0].status == "queued" }
    .sorted {
      if tasks[$0].priority != tasks[$1].priority {
        return tasks[$0].priority > tasks[$1].priority
      }
      return tasks[$0].createdAt < tasks[$1].createdAt
    }
  for index in candidates where runningCount < maxConcurrent {
    let task = tasks[index]
    let dependenciesReady = task.dependsOn.allSatisfy { statuses[$0] == "completed" }
    guard dependenciesReady else { continue }
    let locks = Set(task.resourceLocks)
    guard heldLocks.isDisjoint(with: locks) else { continue }
    do {
      try startAutomationTask(&tasks[index], state: &state)
      runningCount += 1
      heldLocks.formUnion(locks)
    } catch {
      if let signal = networkRecoverySignal(error.localizedDescription) {
        tasks[index].attempts += 1
        queueNetworkRecovery(&tasks[index], state: &state, reason: signal)
        continue
      }
      tasks[index].updatedAt = now
      tasks[index].attempts += 1
      tasks[index].lastError = error.localizedDescription
      tasks[index].status = tasks[index].attempts <= tasks[index].maxRuntimeRetries
        ? "queued"
        : "failed"
    }
  }
  state.automationTasks = tasks
}

private func waitForAutomationReview(timeout: Int) -> [String: Any] {
  let deadline = Date().addingTimeInterval(Double(min(7200, max(1, timeout))))
  while Date() < deadline {
    let state = loadQueueState()
    let tasks = state.automationTasks ?? []
    if let task = tasks.first(where: {
      ["awaiting_review", "blocked", "failed"].contains($0.status)
    }) {
      return [
        "ok": true,
        "ready": true,
        "task": taskPublicPayload(task, includeResult: true),
        "queue": queueStatusPayload(state),
        "reviewInstruction": task.status == "awaiting_review"
          ? "请验收修改和验证证据，然后调用 review_task。accepted=true 会自动启动后续任务；accepted=false 会携带 feedback 重新排队。"
          : "任务需要处理卡点或运行失败。可检查报告后取消、修正任务或重新排队。",
      ]
    }
    if tasks.isEmpty || tasks.allSatisfy({ ["completed", "cancelled"].contains($0.status) }) {
      return ["ok": true, "ready": false, "queueComplete": true, "queue": queueStatusPayload(state)]
    }
    Thread.sleep(forTimeInterval: 0.5)
  }
  return [
    "ok": true,
    "ready": false,
    "timedOut": true,
    "queue": queueStatusPayload(loadQueueState()),
  ]
}

private func commandJSONParams() -> [String: Any] {
  guard CommandLine.arguments.count >= 3,
        let data = CommandLine.arguments[2].data(using: .utf8),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    return [:]
  }
  return object
}

private let nativeCommandSummaries: [String: String] = [
  "status": "查看自动确认、ChatGPT、隐藏页面和任务队列的当前状态。",
  "diagnose": "执行只读诊断，检查辅助功能、ChatGPT 进程和调试连接。",
  "start": "启动后台自动确认；第二个参数可传 JSON 配置。",
  "stop": "停止后台自动确认并关闭插件创建的后台目标。",
  "scan": "立即扫描一次，并允许用 JSON 临时覆盖规则或 approveAll。",
  "sweep": "原地扫描所有已加载 renderer，不导航或切换任何页面。",
  "audit": "读取最近的本地授权审计事件，可指定 1-100 条。",
  "relaunch_and_confirm": "调试端口不可用时重启 ChatGPT，再执行一次确认扫描。",
  "queue_enqueue": "把 1-50 个任务写入可恢复任务队列。",
  "queue_start": "启动任务队列；默认等待下一个待验收任务。",
  "queue_resume": "恢复已暂停的任务队列，不默认阻塞等待验收。",
  "queue_status": "查看任务队列、隐藏 worker、网络等待和任务状态。",
  "queue_attach": "把已有 ChatGPT conversationId 绑定到指定队列任务。",
  "queue_wait_review": "等待下一个待验收、阻塞或失败的任务。",
  "queue_review": "接受任务验收，或携带 feedback 退回重新执行。",
  "queue_pause": "暂停调度新任务；已落盘状态会保留。",
  "queue_retry": "恢复中断任务，可更新 connector 并附加恢复说明。",
  "queue_cancel": "取消指定任务并停止其隐藏 worker。",
  "send_message": "在插件隐藏 Chat 页面中发送一条消息。",
  "add_connector": "在隐藏 Chat 页面中选择一个 ChatGPT connector。",
  "get_reply": "读取隐藏 Chat 页面中的最新回复。",
  "chat_status": "读取隐藏 Chat 表面、conversationId 和页面状态。",
  "send_and_watch": "发送消息、自动确认授权，并等待带任务报告的最终回复。",
]

private func nativeCommandUsage(_ command: String, executable: String) -> String {
  switch command {
  case "status", "diagnose", "stop", "queue_status", "queue_pause":
    return "\(executable) \(command)"
  case "audit":
    return "\(executable) audit [limit]"
  case "start", "scan", "sweep", "relaunch_and_confirm", "queue_enqueue",
       "queue_start", "queue_resume", "queue_attach", "queue_wait_review",
       "queue_review", "queue_retry", "queue_cancel", "send_message",
       "add_connector", "get_reply", "chat_status", "send_and_watch":
    return "\(executable) \(command) ['{...JSON...}']"
  default:
    return "\(executable) \(command)"
  }
}

private func nativeCommandExample(_ command: String, executable: String) -> String? {
  switch command {
  case "start":
    return "\(executable) start '{\"approveAll\":true,\"intervalMs\":750}'"
  case "scan":
    return "\(executable) scan '{\"approveAll\":true}'"
  case "audit":
    return "\(executable) audit 20"
  case "queue_enqueue":
    return "\(executable) queue_enqueue '{\"tasks\":[{\"id\":\"task-1\",\"title\":\"修复问题\",\"prompt\":\"完成实现并验证\"}],\"start\":true}'"
  case "queue_start":
    return "\(executable) queue_start '{\"waitForReview\":false,\"maxConcurrent\":2}'"
  case "queue_review":
    return "\(executable) queue_review '{\"taskId\":\"task-1\",\"accepted\":true}'"
  case "queue_retry":
    return "\(executable) queue_retry '{\"taskId\":\"task-1\",\"connector\":\"devspace1\",\"feedback\":\"从当前 checkout 继续\"}'"
  case "send_message":
    return "\(executable) send_message '{\"message\":\"检查当前状态\",\"connector\":\"devspace1\"}'"
  case "send_and_watch":
    return "\(executable) send_and_watch '{\"message\":\"完成任务并验证\",\"connector\":\"devspace1\",\"timeout\":3600}'"
  default:
    return nil
  }
}

private func nativeHelpText(topic: String? = nil) -> (text: String, known: Bool) {
  let executable = URL(fileURLWithPath: CommandLine.arguments.first ?? "chatgpt-auto-confirm")
    .lastPathComponent
  if let topic, !topic.isEmpty {
    guard let summary = nativeCommandSummaries[topic] else {
      return ("未知公开命令：\(topic)\n运行 \(executable) --help 查看可用命令。\n", false)
    }
    var lines = [
      "ChatGPT 自动确认 · \(topic)",
      "",
      summary,
      "",
      "用法：",
      "  \(nativeCommandUsage(topic, executable: executable))",
      "",
      "说明：",
      "  JSON 参数必须是一个 JSON 对象，并作为第二个位置参数传入。",
      "  也可以运行 \(executable) \(topic) --help 查看本页。",
    ]
    if let example = nativeCommandExample(topic, executable: executable) {
      lines.append(contentsOf: ["", "示例：", "  \(example)"])
    }
    lines.append("")
    return (lines.joined(separator: "\n"), true)
  }

  let text = """
ChatGPT 自动确认 macOS 原生运行时

用途：
  在后台扫描 ChatGPT 授权卡、自动确认允许操作，并用隐藏 Chat 页面执行可恢复任务队列。
  不切换用户页面、不激活窗口、不移动系统鼠标。

用法：
  \(executable) --help
  \(executable) -h
  \(executable) help [command]
  \(executable) <command> --help
  \(executable) <command> [JSON 或参数]

自动确认：
  status                 查看整体状态
  diagnose               执行只读诊断
  start [JSON]           启动后台自动确认
  stop                   停止后台自动确认
  scan [JSON]            立即扫描一次
  sweep [JSON]           原地扫描全部 renderer
  audit [limit]          查看最近 1-100 条审计事件
  relaunch_and_confirm   必要时重启 ChatGPT 后扫描

任务队列：
  queue_enqueue JSON     添加可恢复任务
  queue_start [JSON]     启动队列并可等待验收
  queue_resume [JSON]    恢复队列
  queue_status           查看队列状态
  queue_attach JSON      绑定已有 conversationId
  queue_wait_review JSON 等待待验收任务
  queue_review JSON      提交验收结果
  queue_pause            暂停队列
  queue_retry JSON       恢复中断任务
  queue_cancel JSON      取消任务

隐藏 Chat：
  send_message JSON      发送消息
  add_connector JSON     选择 connector
  get_reply [JSON]       读取最新回复
  chat_status [JSON]     查看隐藏 Chat 状态
  send_and_watch JSON    发送、确认并等待最终任务报告

帮助：
  \(executable) help start
  \(executable) queue_enqueue --help

常用示例：
  \(executable) status
  \(executable) start '{"approveAll":true,"intervalMs":750}'
  \(executable) audit 20
  \(executable) queue_status
  \(executable) send_and_watch '{"message":"完成任务并验证","connector":"devspace1","timeout":3600}'

环境变量：
  CHATGPT_AUTO_CONFIRM_STATE         覆盖自动确认状态文件路径
  CHATGPT_AUTO_CONFIRM_QUEUE_STATE   覆盖任务队列状态文件路径
  CHATGPT_AUTO_CONFIRM_CDP_HOST      覆盖 ChatGPT 调试主机
  CHATGPT_AUTO_CONFIRM_CDP_PORT      覆盖 ChatGPT 调试端口
  CHATGPT_AUTO_CONFIRM_DEBUG=1       输出调试日志

退出码：
  0  命令成功或帮助正常显示
  1  参数、运行时或业务执行失败
  2  未知命令或未知帮助主题

内部命令 watch 和 queue_watch 由运行时自动启动，不建议手动调用。
外层 Mahayana CLI 用法：fabushi-plugin-cli --plugin chatgpt-auto-confirm --help

"""
  return (text, true)
}

private func printNativeHelp(_ topic: String? = nil) -> Never {
  let help = nativeHelpText(topic: topic)
  FileHandle.standardOutput.write(Data(help.text.utf8))
  Foundation.exit(help.known ? 0 : 2)
}

private let commandArguments = Array(CommandLine.arguments.dropFirst())
private let command = commandArguments.first ?? "status"
if ["help", "--help", "-h"].contains(command) {
  printNativeHelp(commandArguments.dropFirst().first)
}
if commandArguments.dropFirst().contains(where: { ["--help", "-h"].contains($0) }) {
  printNativeHelp(command)
}
switch command {
case "status":
  output(statusPayload(loadState()))
case "diagnose":
  output(diagnosticPayload())
case "tabs", "mode", "mode-options", "e2e":
  output([
    "ok": false,
    "errorCode": "background_only",
    "message": "严格后台模式不会切换页面、激活 ChatGPT、移动鼠标或向任务输入内容。",
  ], exitCode: 1)
case "start":
  do {
    try withWatcherLifecycleLock {
    let (rules, interval, chatTitles, chatURLs, approveAll) = try parseStartPayload()
    var state = loadState()
    if watcherIsAlive(state.watcherPid), let pid = state.watcherPid {
      kill(pid, SIGTERM)
      state.watcherPid = nil
    }
    state.enabled = true
    state.rules = rules
    state.approveAll = approveAll
    state.chatTitles = chatTitles
    if !chatURLs.isEmpty {
      let desiredURLs = Set(chatURLs)
      for (url, targetId) in state.backgroundTargets ?? [:] where !desiredURLs.contains(url) {
        _ = CDPClient.closeTarget(targetId)
      }
      state.backgroundTargets = (state.backgroundTargets ?? [:]).filter {
        desiredURLs.contains($0.key)
      }
      state.trackedChatURLs = []
    }
    for chatURL in chatURLs { rememberChatURL(chatURL, in: &state) }
    state.intervalMs = interval
    state.startedAt = isoFormatter.string(from: Date())
    // Keep a plugin-owned background endpoint available for IPC scanning.
    // This process is launched behind the user's app and is never activated;
    // separately, scanIPC also inspects every already-loaded renderer on the
    // normal debugging endpoint without navigating any of them.
    _ = ensureHiddenChatTarget(&state)
    let initial = scan(&state)
    try saveState(state)
    try startWatcher(&state)
    try saveState(state)
    var payload = statusPayload(state)
    payload["initialScan"] = initial
    output(payload)
    }
  } catch {
    output(["ok": false, "errorCode": "start_failed", "message": error.localizedDescription], exitCode: 1)
  }
case "scan":
  var state = loadState()
  if CommandLine.arguments.count >= 3,
     let data = CommandLine.arguments[2].data(using: .utf8),
     let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
    if let approveAll = object["approveAll"] as? Bool {
      state.approveAll = approveAll
    }
    for chatURL in object["chatUrls"] as? [String] ?? [] {
      rememberChatURL(chatURL, in: &state)
    }
    if let rawRules = object["rules"] as? [[String: Any]] {
      state.rules = rawRules.enumerated().compactMap { index, raw -> ApprovalRule? in
        guard let app = (raw["application"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !app.isEmpty,
              let act = (raw["action"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !act.isEmpty,
              let res = (raw["resource"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !res.isEmpty else { return nil }
        return ApprovalRule(
          id: (raw["id"] as? String) ?? "rule-\(index + 1)",
          application: app, action: act, resource: res
        )
      }
    }
  }
  let result = scan(&state)
  try? saveState(state)
  output(result, exitCode: result["ok"] as? Bool == true ? 0 : 1)
case "sweep":
  var state = loadState()
  if CommandLine.arguments.count >= 3,
     let data = CommandLine.arguments[2].data(using: .utf8),
     let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
    if let approveAll = object["approveAll"] as? Bool {
      state.approveAll = approveAll
    }
    if let rawRules = object["rules"] as? [[String: Any]] {
      state.rules = rawRules.enumerated().compactMap { index, raw -> ApprovalRule? in
        guard let app = (raw["application"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !app.isEmpty,
              let act = (raw["action"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !act.isEmpty,
              let res = (raw["resource"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !res.isEmpty else { return nil }
        return ApprovalRule(
          id: (raw["id"] as? String) ?? "rule-\(index + 1)",
          application: app, action: act, resource: res
        )
      }
    }
  }
  var result = scan(&state)
  result["navigationSkipped"] = true
  try? saveState(state)
  output(result, exitCode: result["ok"] as? Bool == true ? 0 : 1)
case "audit":
  let state = loadState()
  let limit = min(100, max(1, CommandLine.arguments.dropFirst(2).first.flatMap(Int.init) ?? 20))
  let events = state.audit.suffix(limit).reversed().map { event -> [String: Any] in
    [
      "at": event.at, "decision": event.decision, "reason": event.reason,
      "clicked": event.clicked, "ruleId": event.ruleId as Any,
      "buttonTitle": event.buttonTitle, "promptText": event.promptText,
      "error": event.error as Any,
    ]
  }
  output(["ok": true, "events": events])
case "relaunch_and_confirm":
  var state = loadState()
  if CommandLine.arguments.count >= 3,
     let data = CommandLine.arguments[2].data(using: .utf8),
     let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
    if let approveAll = object["approveAll"] as? Bool {
      state.approveAll = approveAll
    }
    if let rawRules = object["rules"] as? [[String: Any]] {
      state.rules = rawRules.enumerated().compactMap { index, raw -> ApprovalRule? in
        guard let app = (raw["application"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !app.isEmpty,
              let act = (raw["action"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !act.isEmpty,
              let res = (raw["resource"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !res.isEmpty else { return nil }
        return ApprovalRule(
          id: (raw["id"] as? String) ?? "rule-\(index + 1)",
          application: app, action: act, resource: res
        )
      }
    }
  }
  var relaunchPerformed = false
  if CDPClient.fetchTargets().isEmpty {
    relaunchPerformed = true
    let apps = NSWorkspace.shared.runningApplications.filter {
      $0.bundleIdentifier == "com.openai.chat" || $0.localizedName == "ChatGPT"
    }
    for app in apps {
      app.terminate()
    }
    Thread.sleep(forTimeInterval: 1.0)
    for app in apps where !app.isTerminated {
      app.forceTerminate()
    }
    Thread.sleep(forTimeInterval: 0.5)
    let url = URL(fileURLWithPath: "/Applications/ChatGPT.app")
    let port = CDPClient.port()
    let config = NSWorkspace.OpenConfiguration()
    config.arguments = ["--remote-debugging-port=\(port)"]
    let semaphore = DispatchSemaphore(value: 0)
    NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
      semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + 5.0)
    var waited = 0
    while waited < 30 && CDPClient.fetchTargets().isEmpty {
      Thread.sleep(forTimeInterval: 0.25)
      waited += 1
    }
  }
  var result = scan(&state)
  result["relaunchPerformed"] = relaunchPerformed
  try? saveState(state)
  output(result, exitCode: result["ok"] as? Bool == true ? 0 : 1)
case "stop":
  var state = loadState()
  if watcherIsAlive(state.watcherPid), let pid = state.watcherPid { kill(pid, SIGTERM) }
  closeBackgroundTargets(&state)
  state.enabled = false
  state.watcherPid = nil
  try? saveState(state)
  output(statusPayload(state))
case "watch":
  let activity = beginWatcherActivity(
    preventIdleSystemSleep: false,
    reason: "ChatGPT 自动确认后台 watcher"
  )
  defer { ProcessInfo.processInfo.endActivity(activity) }
  while true {
    autoreleasepool {
      var state = loadState()
      guard state.enabled else { Foundation.exit(0) }
      state.watcherPid = getpid()
      keepApprovalBackgroundEndpointAlive(&state)
      _ = scan(&state)
      try? saveState(state)
      Thread.sleep(forTimeInterval: Double(state.intervalMs) / 1_000.0)
    }
  }
case "queue_enqueue":
  let params = commandJSONParams()
  let rawTasks = params["tasks"] as? [[String: Any]] ?? []
  guard !rawTasks.isEmpty, rawTasks.count <= 50 else {
    output(["ok": false, "errorCode": "invalid_tasks", "message": "tasks 必须包含 1-50 个任务"], exitCode: 1)
  }
  do {
    let payload = try withQueueStateLock { state -> [String: Any] in
      var tasks = state.automationTasks ?? []
      var knownIds = Set(tasks.map(\.id))
      let now = isoFormatter.string(from: Date())
      var appendedIds: [String] = []
      for (index, raw) in rawTasks.enumerated() {
        let prompt = (raw["prompt"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = (raw["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !prompt.isEmpty, prompt.count <= 10_000,
              !title.isEmpty, title.count <= 160 else {
          throw NSError(
            domain: "chatgpt-auto-confirm",
            code: 24,
            userInfo: [NSLocalizedDescriptionKey: "第 \(index + 1) 个任务的 title 或 prompt 无效"]
          )
        }
        let requestedId = raw["id"] as? String
        let id = requestedId == nil
          ? "task-\(UUID().uuidString.lowercased())"
          : normalizedTaskId(requestedId)
        guard let id, knownIds.insert(id).inserted else {
          throw NSError(
            domain: "chatgpt-auto-confirm",
            code: 25,
            userInfo: [NSLocalizedDescriptionKey: "任务 id 无效或重复：\(requestedId ?? "")"]
          )
        }
        let task = AutomationTask(
          id: id,
          title: title,
          prompt: prompt,
          promptTemplate: raw["promptTemplate"] as? String ?? "continue-to-complete",
          connector: raw["connector"] as? String ?? "devspace1",
          dependsOn: raw["dependsOn"] as? [String] ?? [],
          resourceLocks: raw["resourceLocks"] as? [String] ?? [],
          priority: min(100, max(-100, raw["priority"] as? Int ?? 0)),
          timeout: min(7200, max(60, raw["timeout"] as? Int ?? 3600)),
          maxTaskContinuations: max(0, raw["maxTaskContinuations"] as? Int ?? 0),
          maxRuntimeRetries: min(5, max(0, raw["maxRuntimeRetries"] as? Int ?? 2)),
          attempts: 0,
          reviewRound: 0,
          status: "queued",
          createdAt: now,
          updatedAt: now,
          startedAt: nil,
          finishedAt: nil,
          workerPid: nil,
          workerPort: nil,
          workerTargetId: nil,
          workerStatePath: nil,
          workerProfilePath: nil,
          resultPath: nil,
          conversationId: nil,
          chatURL: nil,
          report: nil,
          lastResultJSON: nil,
          lastError: nil,
          reviewFeedback: nil,
          reviewedAt: nil,
          continuationDepth: 0,
          reportFingerprints: [],
          lastActivitySignature: nil,
          lastProgressAt: nil
        )
        tasks.append(task)
        appendedIds.append(id)
      }
      let allIds = Set(tasks.map(\.id))
      for task in tasks where !task.dependsOn.allSatisfy({ allIds.contains($0) }) {
        throw NSError(
          domain: "chatgpt-auto-confirm",
          code: 26,
          userInfo: [NSLocalizedDescriptionKey: "任务 \(task.id) 引用了不存在的 dependsOn"]
        )
      }
      if let cycle = dependencyCycle(in: tasks) {
        throw NSError(
          domain: "chatgpt-auto-confirm",
          code: 31,
          userInfo: [NSLocalizedDescriptionKey: "任务依赖形成循环：\(cycle.joined(separator: " -> "))"]
        )
      }
      state.automationTasks = tasks
      state.queueMaxConcurrent = min(4, max(1, params["maxConcurrent"] as? Int ?? state.queueMaxConcurrent ?? 2))
      state.queueReviewGate = params["reviewGate"] as? Bool ?? true
      if params["start"] as? Bool ?? true {
        state.queueEnabled = true
        state.queuePaused = false
        try startQueueWatcher(&state)
      }
      var result = queueStatusPayload(state)
      result["enqueuedTaskIds"] = appendedIds
      return result
    }
    output(payload)
  } catch {
    output(["ok": false, "errorCode": "queue_enqueue_failed", "message": error.localizedDescription], exitCode: 1)
  }
case "queue_start", "queue_resume":
  let params = commandJSONParams()
  do {
    let payload = try withQueueStateLock { state -> [String: Any] in
      state.queueEnabled = true
      state.queuePaused = false
      if let maxConcurrent = params["maxConcurrent"] as? Int {
        state.queueMaxConcurrent = min(4, max(1, maxConcurrent))
      }
      try startQueueWatcher(&state)
      return queueStatusPayload(state)
    }
    if command == "queue_start", params["waitForReview"] as? Bool ?? true {
      output(waitForAutomationReview(timeout: params["waitTimeout"] as? Int ?? 3600))
    }
    output(payload)
  } catch {
    output(["ok": false, "errorCode": "queue_start_failed", "message": error.localizedDescription], exitCode: 1)
  }
case "queue_status":
  output(queueStatusPayload(loadQueueState()))
case "queue_attach":
  let params = commandJSONParams()
  let taskId = normalizedTaskId(params["taskId"] as? String)
  let conversationId = normalizedConversationId(params["conversationId"] as? String)
  guard let taskId, let conversationId else {
    output(["ok": false, "errorCode": "invalid_queue_attachment", "message": "taskId 或 conversationId 无效"], exitCode: 1)
  }
  do {
    let payload = try withQueueStateLock { state -> [String: Any] in
      var tasks = state.automationTasks ?? []
      guard let index = tasks.firstIndex(where: { $0.id == taskId }) else {
        throw NSError(
          domain: "chatgpt-auto-confirm",
          code: 33,
          userInfo: [NSLocalizedDescriptionKey: "没有找到任务 \(taskId)"]
        )
      }
      let now = isoFormatter.string(from: Date())
      tasks[index].status = "running"
      tasks[index].conversationId = conversationId
      tasks[index].chatURL = params["chatUrl"] as? String
      tasks[index].workerPid = nil
      tasks[index].workerStatePath = nil
      tasks[index].resultPath = nil
      tasks[index].startedAt = tasks[index].startedAt ?? now
      tasks[index].finishedAt = nil
      tasks[index].updatedAt = now
      tasks[index].lastProgressAt = now
      tasks[index].lastError = nil
      tasks[index].report = nil
      state.automationTasks = tasks
      state.queueEnabled = true
      state.queuePaused = false
      try startQueueWatcher(&state)
      var result = queueStatusPayload(state)
      result["attachedTask"] = taskPublicPayload(tasks[index])
      return result
    }
    output(payload)
  } catch {
    output(["ok": false, "errorCode": "queue_attach_failed", "message": error.localizedDescription], exitCode: 1)
  }
case "queue_wait_review":
  let params = commandJSONParams()
  output(waitForAutomationReview(timeout: params["timeout"] as? Int ?? 3600))
case "queue_review":
  let params = commandJSONParams()
  let taskId = normalizedTaskId(params["taskId"] as? String)
  let accepted = params["accepted"] as? Bool ?? false
  let feedback = (params["feedback"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  guard let taskId else {
    output(["ok": false, "errorCode": "invalid_task_id", "message": "taskId 无效"], exitCode: 1)
  }
  do {
    let payload = try withQueueStateLock { state -> [String: Any] in
      var tasks = state.automationTasks ?? []
      guard let index = tasks.firstIndex(where: { $0.id == taskId }) else {
        throw NSError(
          domain: "chatgpt-auto-confirm",
          code: 27,
          userInfo: [NSLocalizedDescriptionKey: "没有找到任务 \(taskId)"]
        )
      }
      guard ["awaiting_review", "blocked", "failed"].contains(tasks[index].status) else {
        throw NSError(
          domain: "chatgpt-auto-confirm",
          code: 28,
          userInfo: [NSLocalizedDescriptionKey: "任务 \(taskId) 当前不在可验收状态"]
        )
      }
      let now = isoFormatter.string(from: Date())
      tasks[index].reviewedAt = now
      tasks[index].updatedAt = now
      tasks[index].reviewFeedback = feedback
      if accepted {
        tasks[index].status = "completed"
        tasks[index].lastError = nil
      } else {
        guard !feedback.isEmpty else {
          throw NSError(
            domain: "chatgpt-auto-confirm",
            code: 29,
            userInfo: [NSLocalizedDescriptionKey: "验收未通过时必须提供 feedback"]
          )
        }
        tasks[index].status = "queued"
        tasks[index].reviewRound += 1
        tasks[index].attempts = 0
        tasks[index].startedAt = nil
        tasks[index].finishedAt = nil
        tasks[index].workerPid = nil
        tasks[index].report = nil
        tasks[index].lastResultJSON = nil
        tasks[index].lastError = nil
      }
      state.automationTasks = tasks
      state.queueEnabled = true
      state.queuePaused = false
      try startQueueWatcher(&state)
      var result = queueStatusPayload(state)
      result["reviewedTask"] = taskPublicPayload(tasks[index])
      result["accepted"] = accepted
      return result
    }
    output(payload)
  } catch {
    output(["ok": false, "errorCode": "queue_review_failed", "message": error.localizedDescription], exitCode: 1)
  }
case "queue_pause":
  do {
    let payload = try withQueueStateLock { state -> [String: Any] in
      state.queuePaused = true
      return queueStatusPayload(state)
    }
    output(payload)
  } catch {
    output(["ok": false, "errorCode": "queue_pause_failed", "message": error.localizedDescription], exitCode: 1)
  }
case "queue_retry":
  let params = commandJSONParams()
  let taskId = normalizedTaskId(params["taskId"] as? String)
  let feedback = (params["feedback"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  let connectorParameter = params["connector"] as? String
  guard connectorParameter == nil || normalizedConnector(connectorParameter) != nil else {
    output(["ok": false, "errorCode": "invalid_connector", "message": "connector 必须是 1-256 字符且不能包含换行"], exitCode: 1)
  }
  let requestedConnector = normalizedConnector(connectorParameter)
  guard let taskId else {
    output(["ok": false, "errorCode": "invalid_task_id", "message": "taskId 无效"], exitCode: 1)
  }
  do {
    let payload = try withQueueStateLock { state -> [String: Any] in
      var tasks = state.automationTasks ?? []
      guard let index = tasks.firstIndex(where: { $0.id == taskId }) else {
        throw NSError(
          domain: "chatgpt-auto-confirm",
          code: 34,
          userInfo: [NSLocalizedDescriptionKey: "没有找到任务 \(taskId)"]
        )
      }
      guard ["queued", "running", "waiting", "blocked", "failed", "cancelled"].contains(tasks[index].status) else {
        throw NSError(
          domain: "chatgpt-auto-confirm",
          code: 35,
          userInfo: [NSLocalizedDescriptionKey: "任务 \(taskId) 当前不需要中断恢复"]
        )
      }
      if let requestedConnector {
        tasks[index].connector = requestedConnector
      }
      if tasks[index].status == "queued" {
        if !feedback.isEmpty {
          tasks[index].reviewFeedback = "任务连接器已更新。请从同一 checkout 的最新落盘进度继续：\n\(feedback)"
        }
        tasks[index].lastError = "connector_updated"
        tasks[index].updatedAt = isoFormatter.string(from: Date())
      } else if tasks[index].status == "running" {
        // Stop only a response inside the hidden queue window. A legacy or
        // attached target is deliberately left untouched because it may be the
        // page where the user is composing a new task.
        let port = tasks[index].workerPort ?? state.queueWorkerPort
        let targetId = tasks[index].workerTargetId ?? state.queueWorkerTargetId
        if queueUsesBackgroundWindow(state),
           let port,
           let targetId {
          _ = cdpValue(
            port: port,
            targetId: targetId,
            expression: stopCurrentResponseJS(),
            timeout: 12.0
          )
        }
        // An operator retry must not inherit a hidden renderer that may have
        // drifted to a foreground-created conversation. The next attempt gets
        // a fresh show:false page inside the same ChatGPT process.
        stopQueueWorker(&state)
      }
      if tasks[index].status != "queued", ["cancelled", "waiting", "blocked", "failed"].contains(tasks[index].status) {
        // An explicit operator retry is a fresh recovery budget. Keep the
        // checkout and audit history, but do not let an old continuation
        // fingerprint prevent the new architecture from making progress.
        tasks[index].reportFingerprints = []
        tasks[index].continuationDepth = 0
        tasks[index].reviewRound += 1
        tasks[index].status = "queued"
        tasks[index].startedAt = nil
        tasks[index].finishedAt = nil
        tasks[index].workerPid = nil
        tasks[index].report = nil
        tasks[index].reviewConversationId = nil
        tasks[index].reviewStatus = nil
        tasks[index].reviewReport = nil
        tasks[index].lastError = "operator_recovery"
        tasks[index].lastProgressAt = nil
        tasks[index].waitingUntil = nil
        tasks[index].waitReason = nil
      } else if tasks[index].status != "queued" {
        queueContinuation(&tasks[index], report: tasks[index].report, reason: "operator_recovery")
      }
      if !feedback.isEmpty && tasks[index].status == "queued" {
        tasks[index].reviewFeedback = "任务出现中断迹象。请从同一 checkout 的最新落盘进度继续，不要从头开始或覆盖无关改动：\n\(feedback)"
      }
      state.automationTasks = tasks
      state.queueEnabled = true
      state.queuePaused = false
      try startQueueWatcher(&state)
      var result = queueStatusPayload(state)
      result["retriedTask"] = taskPublicPayload(tasks[index])
      return result
    }
    output(payload)
  } catch {
    output(["ok": false, "errorCode": "queue_retry_failed", "message": error.localizedDescription], exitCode: 1)
  }
case "queue_cancel":
  let params = commandJSONParams()
  let taskId = normalizedTaskId(params["taskId"] as? String)
  guard let taskId else {
    output(["ok": false, "errorCode": "invalid_task_id", "message": "taskId 无效"], exitCode: 1)
  }
  do {
    let payload = try withQueueStateLock { state -> [String: Any] in
      var tasks = state.automationTasks ?? []
      guard let index = tasks.firstIndex(where: { $0.id == taskId }) else {
        throw NSError(
          domain: "chatgpt-auto-confirm",
          code: 30,
          userInfo: [NSLocalizedDescriptionKey: "没有找到任务 \(taskId)"]
        )
      }
      if watcherIsAlive(tasks[index].workerPid), let pid = tasks[index].workerPid {
        kill(pid, SIGTERM)
      }
      stopAutomationWorker(tasks[index])
      tasks[index].status = "cancelled"
      tasks[index].workerPid = nil
      tasks[index].updatedAt = isoFormatter.string(from: Date())
      tasks[index].finishedAt = tasks[index].updatedAt
      state.automationTasks = tasks
      var result = queueStatusPayload(state)
      result["cancelledTaskId"] = taskId
      return result
    }
    output(payload)
  } catch {
    output(["ok": false, "errorCode": "queue_cancel_failed", "message": error.localizedDescription], exitCode: 1)
  }
case "queue_watch":
  let activity = beginWatcherActivity(
    preventIdleSystemSleep: true,
    reason: "ChatGPT 自动确认任务队列后台处理"
  )
  defer { ProcessInfo.processInfo.endActivity(activity) }
  while true {
    autoreleasepool {
      do {
        let shouldContinue = try withQueueStateLock { state -> Bool in
          guard state.queueEnabled == true else { return false }
          state.queueWatcherPid = getpid()
          state.queueRuntimeRevision = currentQueueRuntimeRevision
          if queueUsesBackgroundWindow(state),
             let port = state.queueWorkerPort,
             let targetId = state.queueWorkerTargetId {
            _ = queueTargetRuntimeState(port: port, targetId: targetId, refreshLifecycle: true)
          }
          runQueueIteration(&state)
          return state.queueEnabled == true
        }
        if !shouldContinue { Foundation.exit(0) }
      } catch {
        cdpDebug("queue watcher iteration failed: \(error.localizedDescription)")
      }
      Thread.sleep(forTimeInterval: 1.0)
    }
  }
case "send_message", "add_connector":
  var params: [String: Any] = [:]
  if CommandLine.arguments.count >= 3,
     let data = CommandLine.arguments[2].data(using: .utf8),
     let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
    params = object
  }
  if command == "add_connector" {
    let connector = (params["connector"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !connector.isEmpty else {
      output(["ok": false, "errorCode": "missing_connector", "message": "请提供 connector 名称"], exitCode: 1)
    }
    let rawConversationId = params["conversationId"] as? String
    let conversationId = normalizedConversationId(rawConversationId)
    if rawConversationId != nil && conversationId == nil {
      output(["ok": false, "errorCode": "invalid_conversation_id", "message": "conversationId 格式无效"], exitCode: 1)
    }
    var state = loadState()
    let prepared = ensureHiddenChatTarget(&state, conversationId: conversationId)
    guard prepared?["ok"] as? Bool == true else {
      try? saveState(state)
      output(prepared ?? ["ok": false, "errorCode": "background_chat_unavailable"], exitCode: 1)
    }
    let rawChatURL = params["chatUrl"] as? String
    let preferredChatURL = ensureChatTarget(rawChatURL, in: &state)
    if rawChatURL != nil && preferredChatURL == nil {
      output(["ok": false, "errorCode": "invalid_chat_url", "message": "chatUrl 必须是 ChatGPT 对话地址"], exitCode: 1)
    }
    try? saveState(state)
    let js = addConnectorJS(connector: connector)
    if let result = cdpEvaluateOnChatGPT(js, timeout: 8.0, preferredURL: preferredChatURL) {
      output(result, exitCode: result["ok"] as? Bool == true ? 0 : 1)
    } else {
      output(["ok": false, "errorCode": "cdp_unavailable", "message": "无法通过 CDP 连接到 ChatGPT。请确保 ChatGPT 已开启调试端口运行。"], exitCode: 1)
    }
  } else {
    let message = (params["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let connector = params["connector"] as? String
    let rawConversationId = params["conversationId"] as? String
    let conversationId = normalizedConversationId(rawConversationId)
    if rawConversationId != nil && conversationId == nil {
      output(["ok": false, "errorCode": "invalid_conversation_id", "message": "conversationId 格式无效"], exitCode: 1)
    }
    let newChat = conversationId == nil ? (params["newChat"] as? Bool ?? true) : false
    guard !message.isEmpty else {
      output(["ok": false, "errorCode": "missing_message", "message": "请提供 message 参数"], exitCode: 1)
    }
    var state = loadState()
    let prepared = ensureHiddenChatTarget(
      &state,
      newChat: newChat,
      conversationId: conversationId
    )
    guard prepared?["ok"] as? Bool == true else {
      try? saveState(state)
      output(prepared ?? ["ok": false, "errorCode": "background_chat_unavailable"], exitCode: 1)
    }
    let rawChatURL = params["chatUrl"] as? String
    let preferredChatURL = ensureChatTarget(rawChatURL, in: &state)
    if rawChatURL != nil && preferredChatURL == nil {
      output(["ok": false, "errorCode": "invalid_chat_url", "message": "chatUrl 必须是 ChatGPT 对话地址"], exitCode: 1)
    }
    try? saveState(state)
    let js = sendMessageJS(message: message, connector: connector, newChat: false)
    if let result = cdpEvaluateOnChatGPT(js, timeout: 18.0, preferredURL: preferredChatURL) {
      if preferredChatURL == nil || normalizedChatURL(result["url"] as? String) == preferredChatURL {
        rememberChatURL(result["url"] as? String, in: &state)
      }
      state.audit.append(AuditEvent(
        at: isoFormatter.string(from: Date()),
        decision: "send_message",
        reason: "通过 CDP 向 ChatGPT 发送消息",
        clicked: result["sent"] as? Bool ?? false,
        ruleId: nil,
        buttonTitle: "send",
        promptText: "send_message: \(String(message.prefix(200)))",
        error: result["error"] as? String
      ))
      if state.audit.count > 100 { state.audit.removeFirst(state.audit.count - 100) }
      try? saveState(state)
      if result["ok"] as? Bool == true {
        output(result)
      } else {
        let diagnostic = cdpEvaluateOnChatGPT(pageDiagnosticJS(), preferredURL: preferredChatURL) ?? [:]
        var failure = result
        failure["errorCode"] = result["error"] as? String ?? "send_stage_failed"
        failure["message"] = "Chat 指令发送阶段未得到页面确认，小程序已退出并保存阶段日志。"
        failure["screenshotPath"] = captureHiddenChatScreenshot(state, label: "send-failed") as Any
        failure["pageContent"] = diagnostic["content"] as Any
        failure["pageButtons"] = diagnostic["buttons"] as Any
        output(failure, exitCode: 1)
      }
    } else {
      output(["ok": false, "errorCode": "cdp_unavailable", "message": "无法通过 CDP 连接到 ChatGPT。请确保 ChatGPT 已开启调试端口运行。"], exitCode: 1)
    }
  }
case "get_reply":
  var params: [String: Any] = [:]
  if CommandLine.arguments.count >= 3,
     let data = CommandLine.arguments[2].data(using: .utf8),
     let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
    params = object
  }
  let rawConversationId = params["conversationId"] as? String
  let conversationId = normalizedConversationId(rawConversationId)
  if rawConversationId != nil && conversationId == nil {
    output(["ok": false, "errorCode": "invalid_conversation_id", "message": "conversationId 格式无效"], exitCode: 1)
  }
  var state = loadState()
  let prepared = ensureHiddenChatTarget(&state, conversationId: conversationId)
  guard prepared?["ok"] as? Bool == true else {
    try? saveState(state)
    output(prepared ?? ["ok": false, "errorCode": "background_chat_unavailable"], exitCode: 1)
  }
  let rawChatURL = params["chatUrl"] as? String
  let preferredChatURL = ensureChatTarget(rawChatURL, in: &state)
  if rawChatURL != nil && preferredChatURL == nil {
    output(["ok": false, "errorCode": "invalid_chat_url", "message": "chatUrl 必须是 ChatGPT 对话地址"], exitCode: 1)
  }
  try? saveState(state)
  if let result = cdpEvaluateOnChatGPT(getReplyJS(), preferredURL: preferredChatURL) {
    var payload = sanitizeJSONValue(result) as? [String: Any] ?? ["ok": false, "errorCode": "sanitize_failed"]
    if payload["conversationId"] == nil {
      payload["conversationId"] = state.backgroundConversationId as Any
    }
    output(payload)
  } else {
    output(["ok": false, "errorCode": "cdp_unavailable", "message": "无法通过 CDP 连接到 ChatGPT"], exitCode: 1)
  }
case "chat_status":
  var params: [String: Any] = [:]
  if CommandLine.arguments.count >= 3,
     let data = CommandLine.arguments[2].data(using: .utf8),
     let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
    params = object
  }
  let rawConversationId = params["conversationId"] as? String
  let conversationId = normalizedConversationId(rawConversationId)
  if rawConversationId != nil && conversationId == nil {
    output(["ok": false, "errorCode": "invalid_conversation_id", "message": "conversationId 格式无效"], exitCode: 1)
  }
  var state = loadState()
  let prepared = ensureHiddenChatTarget(&state, conversationId: conversationId)
  guard prepared?["ok"] as? Bool == true else {
    try? saveState(state)
    output(prepared ?? ["ok": false, "errorCode": "background_chat_unavailable"], exitCode: 1)
  }
  let rawChatURL = params["chatUrl"] as? String
  let preferredChatURL = ensureChatTarget(rawChatURL, in: &state)
  if rawChatURL != nil && preferredChatURL == nil {
    output(["ok": false, "errorCode": "invalid_chat_url", "message": "chatUrl 必须是 ChatGPT 对话地址"], exitCode: 1)
  }
  try? saveState(state)
  if let result = cdpEvaluateOnChatGPT(chatStatusJS(), preferredURL: preferredChatURL) {
    if preferredChatURL == nil || normalizedChatURL(result["url"] as? String) == preferredChatURL {
      rememberChatURL(result["url"] as? String, in: &state)
    }
    try? saveState(state)
    var payload = sanitizeJSONValue(result) as? [String: Any] ?? ["ok": false, "errorCode": "sanitize_failed"]
    payload["trackedChatURLs"] = state.trackedChatURLs ?? []
    payload["hiddenTargetCount"] = state.backgroundChatTargetId == nil ? 0 : 1
    payload["backgroundPort"] = state.backgroundAppPort as Any
    payload["backgroundTargetId"] = state.backgroundChatTargetId as Any
    if payload["conversationId"] == nil {
      payload["conversationId"] = state.backgroundConversationId as Any
    }
    output(payload)
  } else {
    output(["ok": false, "errorCode": "cdp_unavailable", "message": "无法通过 CDP 连接到 ChatGPT"], exitCode: 1)
  }
case "send_and_watch":
  var params: [String: Any] = [:]
  if CommandLine.arguments.count >= 3,
     let data = CommandLine.arguments[2].data(using: .utf8),
     let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
    params = object
  }
  let message = (params["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  let connector = params["connector"] as? String
  let rawChatURL = params["chatUrl"] as? String
  let rawConversationId = params["conversationId"] as? String
  let resumeExisting = params["resumeExisting"] as? Bool ?? false
  let freshTargetPrepared = params["freshTargetPrepared"] as? Bool ?? false
  let conversationId = resumeExisting ? normalizedConversationId(rawConversationId) : nil
  if resumeExisting && rawConversationId != nil && conversationId == nil {
    output(["ok": false, "errorCode": "invalid_conversation_id", "message": "conversationId 格式无效"], exitCode: 1)
  }
  // User policy: every outbound message starts a fresh Chat. An existing
  // conversation can only be attached in read-only resumeExisting mode.
  let newChat = !resumeExisting && !freshTargetPrepared
  let timeout = min(7200, max(10, params["timeout"] as? Int ?? 3600))
  let stagnationTimeout = min(3600, max(60, params["stagnationTimeout"] as? Int ?? 1200))
  let maxRecoveryAttempts = min(5, max(0, params["maxRecoveryAttempts"] as? Int ?? 5))
  let autoContinueIncomplete = params["autoContinueIncomplete"] as? Bool ?? true
  let maxTaskContinuations = max(0, params["maxTaskContinuations"] as? Int ?? 0)
  let continuationDepth = max(0, params["continuationDepth"] as? Int ?? 0)
  let originalGoal = (params["originalGoal"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? message
  let reportFingerprints = params["reportFingerprints"] as? [String] ?? []
  let defaultContinuationMessage = "上一个 Chat 的 devspace1 或页面已经连续 \(max(1, stagnationTimeout / 60)) 分钟没有新进度并已停止。请在这个新 Chat 中接手原任务：先检查同一 checkout 中最后一个 devspace1 操作是否已返回或落盘，如果该调用超时则只重试对应步骤。不要切换到 Work，不要从头开始，不要覆盖无关改动，完成实现和验证后再返回最终结果。"
  let continuationMessage = ((params["continuationMessage"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? defaultContinuationMessage
  let approveAll = params["approveAll"] as? Bool ?? true
  let pollIntervalMs = min(5000, max(200, params["pollIntervalMs"] as? Int ?? 500))

  guard !message.isEmpty else {
    output(["ok": false, "errorCode": "missing_message", "message": "请提供 message 参数"], exitCode: 1)
  }

  // Capture the existing conversation before sending. Without this baseline,
  // the first poll can mistake the previous assistant message for the reply to
  // the new instruction and return immediately.
  var state = loadState()
  let prepared = ensureHiddenChatTarget(
    &state,
    newChat: resumeExisting ? false : newChat,
    conversationId: conversationId
  )
  guard prepared?["ok"] as? Bool == true else {
    try? saveState(state)
    output(prepared ?? ["ok": false, "errorCode": "background_chat_unavailable"], exitCode: 1)
  }
  if !resumeExisting && !freshTargetPrepared && prepared?["newChatClicked"] as? Bool != true {
    try? saveState(state)
    output([
      "ok": false,
      "errorCode": "new_chat_creation_not_confirmed",
      "message": "发送前没有确认创建新的 Chat，小程序已退出。",
      "preparation": prepared as Any,
      "backgroundOnly": true,
      "workerUsed": false,
    ], exitCode: 1)
  }
  let preferredChatURL = ensureChatTarget(rawChatURL, in: &state)
  if rawChatURL != nil && preferredChatURL == nil {
    output(["ok": false, "errorCode": "invalid_chat_url", "message": "chatUrl 必须是 ChatGPT 对话地址"], exitCode: 1)
  }
  state.approveAll = approveAll
  state.enabled = true
  state.intervalMs = min(5_000, max(400, pollIntervalMs))
  if !watcherIsAlive(state.watcherPid) {
    do {
      try withWatcherLifecycleLock {
        let latest = loadState()
        if watcherIsAlive(latest.watcherPid) {
          state.watcherPid = latest.watcherPid
        } else {
          try saveState(state)
          try startWatcher(&state)
        }
      }
    } catch {
      state.lastError = "approval_watcher_start_failed"
      try? saveState(state)
      output([
        "ok": false,
        "errorCode": "approval_watcher_start_failed",
        "message": error.localizedDescription,
        "backgroundOnly": true,
        "workerUsed": false,
      ], exitCode: 1)
    }
  }
  try? saveState(state)
  let baselineReply = cdpEvaluateOnChatGPT(getReplyJS(), preferredURL: preferredChatURL)
  let currentMessageCount = baselineReply?["messageCount"] as? Int ?? 0
  let baselineMessageCount = resumeExisting ? max(0, currentMessageCount - 1) : currentMessageCount
  if let initialThinking = baselineReply?["thinking"] as? String, !initialThinking.isEmpty {
    emitProgress([
      "event": "thinking_progress",
      "initial": true,
      "thinking": String(initialThinking.suffix(4000)),
      "activityCharCount": baselineReply?["activityCharCount"] as? Int ?? 0,
      "devspaceActivity": String((baselineReply?["devspaceActivity"] as? String ?? "").suffix(2000)),
      "devspaceWaiting": baselineReply?["devspaceWaiting"] as? Bool ?? false,
    ])
  }

  // Step 1: Send message
  var sendResult: [String: Any] = [
    "ok": true,
    "url": "app://-/index.html",
    "resumedExisting": resumeExisting,
  ]
  if !resumeExisting {
    let sendJS = sendMessageJS(
      message: messageWithTaskReportContract(message), connector: connector, newChat: false)
    // Connector selection plus virtualization-aware bubble confirmation can
    // legitimately take about 19 seconds in the desktop renderer. Keep the
    // outer CDP deadline safely above the script's bounded inner waits.
    var result = cdpEvaluateOnChatGPT(sendJS, timeout: 35.0, preferredURL: preferredChatURL)
    // Clicking Send can replace the renderer's execution context. CDP then
    // loses the async script result even though the new user bubble exists.
    // Re-attach read-only and verify the exact submitted bubble before calling
    // this a failure; never send the message a second time here.
    if result == nil {
      for _ in 0..<24 {
        Thread.sleep(forTimeInterval: 0.5)
        if let verification = cdpEvaluateOnChatGPT(
          verifySentMessageJS(message: messageWithTaskReportContract(message)),
          timeout: 5.0,
          preferredURL: preferredChatURL
        ), verification["messageConfirmed"] as? Bool == true {
          result = verification
          break
        }
      }
    }
    guard let result else {
        let diagnostic = cdpEvaluateOnChatGPT(pageDiagnosticJS(), preferredURL: preferredChatURL) ?? [:]
        output([
          "ok": false,
          "errorCode": "cdp_send_failed",
          "message": "发送脚本执行上下文丢失，且重新绑定后仍未找到完整的新用户消息气泡。",
          "screenshotPath": captureHiddenChatScreenshot(state, label: "send-cdp-failed") as Any,
          "pageContent": diagnostic["content"] as Any,
          "pageButtons": diagnostic["buttons"] as Any,
          "backgroundOnly": true,
          "workerUsed": false,
        ], exitCode: 1)
    }
    guard result["ok"] as? Bool == true else {
      let diagnostic = cdpEvaluateOnChatGPT(pageDiagnosticJS(), preferredURL: preferredChatURL) ?? [:]
      var failure = result
      failure["errorCode"] = result["error"] as? String ?? "send_stage_failed"
      failure["message"] = "Chat 指令未通过页面确认；小程序没有进入等待状态。"
      failure["screenshotPath"] = captureHiddenChatScreenshot(state, label: "send-stage-failed") as Any
      failure["pageContent"] = diagnostic["content"] as Any
      failure["pageButtons"] = diagnostic["buttons"] as Any
      failure["backgroundOnly"] = true
      failure["workerUsed"] = false
      output(failure, exitCode: 1)
    }
    sendResult = result
  }

  // Record audit
  rememberChatURL(sendResult["url"] as? String, in: &state)
  let activeChatURL = normalizedChatURL(sendResult["url"] as? String) ?? preferredChatURL
  if !resumeExisting {
    state.audit.append(AuditEvent(
      at: isoFormatter.string(from: Date()),
      decision: "send_message",
      reason: "send_and_watch 端到端流程：通过 CDP 发送消息",
      clicked: true,
      ruleId: nil,
      buttonTitle: "send",
      promptText: "send_and_watch: \(String(message.prefix(200)))",
      error: nil
    ))
  }

  // Step 2: Poll loop - approve + watch reply
  let deadline = Date().addingTimeInterval(Double(timeout))
  var finalReply: [String: Any] = ["content": "", "streaming": false, "done": false, "charCount": 0]
  var totalApprovals = 0
  var timedOut = false
  var prevCharCount = 0
  var sawNewReply = false
  var stalled = false
  var surfaceDrift = false
  var surfaceDriftStatus: [String: Any] = [:]
  var stalledPageContent = ""
  var stalledButtons: [String] = []
  var screenshotPath: String?
  var recoveryEvents: [[String: Any]] = []
  var recoveryAttempts = 0
  var lastActivitySignature = baselineReply?["activitySignature"] as? String ?? ""
  var lastPageChangeAt = Date()
  var completionCandidateSince: Date?
  var completionCandidateSignature = ""

  // Wait a moment for ChatGPT to start processing
  Thread.sleep(forTimeInterval: 1.5)

  while Date() < deadline {
    // The hidden renderer must remain on the real Chat surface for the whole
    // run. A handoff or navigation can otherwise expose a Work composer after
    // the initial send. Abort immediately; never approve or type on Work.
    if let liveSurface = cdpEvaluateOnChatGPT(chatStatusJS(), preferredURL: activeChatURL),
       liveSurface["chatMode"] as? Bool != true || liveSurface["surface"] as? String != "chat" {
      surfaceDrift = true
      surfaceDriftStatus = liveSurface
      let diagnostic = cdpEvaluateOnChatGPT(pageDiagnosticJS(), preferredURL: activeChatURL) ?? [:]
      stalledPageContent = diagnostic["content"] as? String ?? ""
      stalledButtons = diagnostic["buttons"] as? [String] ?? []
      screenshotPath = captureHiddenChatScreenshot(state, label: "chat-surface-drift")
      emitProgress([
        "event": "chat_surface_drift",
        "surfaceStatus": liveSurface,
        "screenshotPath": screenshotPath as Any,
        "backgroundOnly": true,
        "workerUsed": false,
      ])
      break
    }

    autoreleasepool {
      // 2a: Check and auto-approve any authorization cards
      let scanResult = scanIPC(&state)
      if let approved = scanResult?["approved"] as? Int, approved > 0 {
        totalApprovals += approved
        lastPageChangeAt = Date()
        emitProgress([
          "event": "approval",
          "approved": approved,
          "totalApproved": totalApprovals,
          "backgroundOnly": true,
          "workerUsed": false,
        ])
      }

      // Also try AX-based approval as fallback
      // (already handled by scanIPC which tries IPC first then falls back)
    }

    // 2b: Check reply
    if let replyResult = cdpEvaluateOnChatGPT(getReplyJS(), preferredURL: activeChatURL) {
      let messageCount = replyResult["messageCount"] as? Int ?? 0
      let isStreaming = replyResult["streaming"] as? Bool ?? false
      finalReply = replyResult
      let activitySignature = replyResult["activitySignature"] as? String ?? ""
      if !activitySignature.isEmpty && activitySignature != lastActivitySignature {
        lastActivitySignature = activitySignature
        lastPageChangeAt = Date()
        let thinking = replyResult["thinking"] as? String ?? ""
        emitProgress([
          "event": "thinking_progress",
          "thinking": String(thinking.suffix(4000)),
          "activityCharCount": replyResult["activityCharCount"] as? Int ?? 0,
          "devspaceActivity": String((replyResult["devspaceActivity"] as? String ?? "").suffix(2000)),
          "devspaceWaiting": replyResult["devspaceWaiting"] as? Bool ?? false,
          "waitingForApproval": replyResult["waitingForApproval"] as? Bool ?? false,
          "messageCount": messageCount,
        ])
      }

      // The desktop Chat surface can keep the completed response inside a
      // collapsed "思考" section without rendering a final-assistant node.
      // Accept that representation only after it is inactive and stable for
      // several seconds, so an old reply or a transient tool pause cannot be
      // mistaken for the result of the current request.
      let isCompletionCandidate = replyResult["completionCandidate"] as? Bool ?? false
      let isTerminalIncomplete = replyResult["terminalIncomplete"] as? Bool ?? false
      if (isCompletionCandidate || isTerminalIncomplete) && !activitySignature.isEmpty {
        if completionCandidateSignature != activitySignature {
          completionCandidateSignature = activitySignature
          completionCandidateSince = Date()
        } else if let candidateSince = completionCandidateSince,
                  Date().timeIntervalSince(candidateSince) >= 4.0 {
          let completedActivity = replyResult["completedActivity"] as? String
            ?? replyResult["content"] as? String
            ?? replyResult["activity"] as? String
            ?? ""
          if !completedActivity.isEmpty {
            finalReply["content"] = completedActivity
            finalReply["charCount"] = completedActivity.count
            finalReply["done"] = true
            finalReply["terminalIncomplete"] = isTerminalIncomplete
            finalReply["pending"] = false
            finalReply["streaming"] = false
            sawNewReply = true
            break
          }
        }
      } else {
        completionCandidateSince = nil
        completionCandidateSignature = ""
      }

      if messageCount <= baselineMessageCount {
        // ChatGPT may be using tools before it creates the new assistant
        // message. Keep waiting and never expose the previous reply as the
        // current task's live content.
        finalReply["content"] = ""
        finalReply["charCount"] = 0
        finalReply["done"] = false
        finalReply["pending"] = true
        finalReply["streaming"] = isStreaming
      } else {
        sawNewReply = true
        finalReply = replyResult
        let currentChars = replyResult["charCount"] as? Int ?? 0

        if replyResult["done"] as? Bool == true {
          // Reply is complete
          break
        }

        // Update progress tracking
        if currentChars > prevCharCount {
          prevCharCount = currentChars
        }
      }
    }

    if Date().timeIntervalSince(lastPageChangeAt) >= Double(stagnationTimeout) {
      let diagnostic = cdpEvaluateOnChatGPT(pageDiagnosticJS(), preferredURL: activeChatURL) ?? [:]
      stalledPageContent = diagnostic["content"] as? String ?? (finalReply["pageContent"] as? String ?? "")
      stalledButtons = diagnostic["buttons"] as? [String] ?? []
      let devspaceWaiting = finalReply["devspaceWaiting"] as? Bool ?? false
      let diagnosticKind = devspaceWaiting ? "devspace-timeout" : "page-stalled"
      screenshotPath = captureHiddenChatScreenshot(state, label: "\(diagnosticKind)-\(recoveryAttempts + 1)")

      if recoveryAttempts < maxRecoveryAttempts {
        recoveryAttempts += 1
        let stopResult = cdpEvaluateOnChatGPT(
          stopCurrentResponseJS(),
          timeout: 5.0,
          preferredURL: activeChatURL
        ) ?? ["ok": false, "error": "stop_cdp_failed"]
        let stopConfirmed = stopResult["stopConfirmed"] as? Bool ?? false
        let recoveryResult: [String: Any]
        if stopConfirmed {
          recoveryResult = cdpEvaluateOnChatGPT(
            sendMessageJS(message: continuationMessage, connector: connector, newChat: true),
            timeout: 35.0,
            preferredURL: activeChatURL
          ) ?? ["ok": false, "error": "new_chat_recovery_cdp_failed"]
        } else {
          recoveryResult = [
            "ok": false,
            "error": "old_chat_stop_not_confirmed",
            "failedStage": "stop_confirmation",
          ]
        }
        let recoveryEvent: [String: Any] = [
          "attempt": recoveryAttempts,
          "reason": devspaceWaiting ? "devspace_timeout" : "page_stalled",
          "idleSeconds": stagnationTimeout,
          "screenshotPath": screenshotPath as Any,
          "stopped": stopResult["stopped"] as? Bool ?? false,
          "stopConfirmed": stopConfirmed,
          "stopVerification": stopResult,
          "createdNewChat": stopConfirmed,
          "continued": recoveryResult["messageConfirmed"] as? Bool ?? false,
          "sendVerification": recoveryResult,
          "error": recoveryResult["error"] as Any,
        ]
        recoveryEvents.append(recoveryEvent)
        emitProgress(["event": "auto_recovery", "recovery": recoveryEvent])
        if recoveryResult["ok"] as? Bool == true {
          lastPageChangeAt = Date()
          lastActivitySignature = ""
          Thread.sleep(forTimeInterval: 1.0)
        } else {
          stalled = true
          break
        }
      } else {
        stalled = true
        break
      }
    }

    // 2c: Wait before next poll
    Thread.sleep(forTimeInterval: Double(pollIntervalMs) / 1000.0)
  }

  if Date() >= deadline && (!sawNewReply || finalReply["done"] as? Bool != true) {
    timedOut = true
    let diagnostic = cdpEvaluateOnChatGPT(pageDiagnosticJS(), preferredURL: activeChatURL) ?? [:]
    stalledPageContent = diagnostic["content"] as? String ?? (finalReply["pageContent"] as? String ?? "")
    stalledButtons = diagnostic["buttons"] as? [String] ?? []
    screenshotPath = captureHiddenChatScreenshot(state, label: "watch-timeout")
  }

  // Save state
  if state.audit.count > 100 { state.audit.removeFirst(state.audit.count - 100) }
  try? saveState(state)

  // Build result
  let replyContent = finalReply["content"] as? String ?? ""
  var replyPayload: [String: Any] = [:]
  replyPayload["content"] = String(replyContent.prefix(50000))
  replyPayload["thinking"] = String((finalReply["thinking"] as? String ?? "").prefix(50000))
  replyPayload["activity"] = String((finalReply["activity"] as? String ?? "").prefix(50000))
  replyPayload["activityCharCount"] = finalReply["activityCharCount"] as? Int ?? 0
  replyPayload["devspaceActivity"] = String((finalReply["devspaceActivity"] as? String ?? "").prefix(20000))
  replyPayload["devspaceWaiting"] = finalReply["devspaceWaiting"] as? Bool ?? false
  replyPayload["waitingForApproval"] = finalReply["waitingForApproval"] as? Bool ?? false
  replyPayload["stopAvailable"] = finalReply["stopAvailable"] as? Bool ?? false
  replyPayload["completionCandidate"] = finalReply["completionCandidate"] as? Bool ?? false
  replyPayload["terminalIncomplete"] = finalReply["terminalIncomplete"] as? Bool ?? false
  replyPayload["completedThinkingTitle"] = finalReply["completedThinkingTitle"] as? String ?? ""
  replyPayload["charCount"] = finalReply["charCount"] as? Int ?? 0
  replyPayload["streaming"] = finalReply["streaming"] as? Bool ?? false
  replyPayload["done"] = finalReply["done"] as? Bool ?? false
  replyPayload["pending"] = finalReply["pending"] as? Bool ?? false
  replyPayload["messageCount"] = finalReply["messageCount"] as? Int ?? 0
  replyPayload["userMessageCount"] = finalReply["userMessageCount"] as? Int ?? 0

  var resultPayload: [String: Any] = [:]
  let terminalIncomplete = finalReply["terminalIncomplete"] as? Bool ?? false
  let taskReport = parseTaskReport(replyContent)
  let taskStatus = taskReport?["status"] as? String
  let finalChatStatus = cdpEvaluateOnChatGPT(chatStatusJS(), preferredURL: activeChatURL) ?? [:]
  let finalConversationId = finalChatStatus["conversationId"] as? String
    ?? state.backgroundConversationId
  let finalChatURL = finalChatStatus["chatUrl"] as? String
  let explicitlyIncomplete = finalReply["explicitlyIncomplete"] as? Bool ?? false
  let normalCompletion = !resumeExisting && !surfaceDrift && !stalled && !timedOut
    && finalReply["done"] as? Bool == true && taskReport == nil
    && !terminalIncomplete && !explicitlyIncomplete
  let effectiveTaskStatus = taskStatus ?? (normalCompletion ? "complete" : nil)
  let reportMissing = !resumeExisting && !surfaceDrift && !stalled && !timedOut
    && finalReply["done"] as? Bool == true && taskReport == nil
    && !normalCompletion
  resultPayload["ok"] = !stalled && !timedOut && !surfaceDrift && !terminalIncomplete
    && !reportMissing && effectiveTaskStatus == "complete" && (finalReply["done"] as? Bool == true)
  resultPayload["sent"] = resumeExisting ? false : (sendResult["messageConfirmed"] as? Bool ?? false)
  resultPayload["resumedExisting"] = resumeExisting
  resultPayload["preparation"] = prepared as Any
  resultPayload["sendVerification"] = sendResult
  resultPayload["reply"] = replyPayload
  resultPayload["approvals"] = ["totalApproved": totalApprovals]
  resultPayload["connector"] = connector as Any
  resultPayload["backgroundOnly"] = true
  resultPayload["workerUsed"] = false
  resultPayload["surface"] = "chat"
  resultPayload["backgroundPort"] = state.backgroundAppPort as Any
  resultPayload["backgroundTargetId"] = state.backgroundChatTargetId as Any
  resultPayload["conversationId"] = finalConversationId as Any
  resultPayload["chatUrl"] = finalChatURL as Any
  resultPayload["timedOut"] = timedOut
  resultPayload["stalled"] = stalled
  resultPayload["surfaceDrift"] = surfaceDrift
  resultPayload["surfaceStatus"] = surfaceDriftStatus
  resultPayload["stagnationTimeout"] = stagnationTimeout
  resultPayload["maxRecoveryAttempts"] = maxRecoveryAttempts
  resultPayload["recoveryAttempts"] = recoveryAttempts
  resultPayload["recoveries"] = recoveryEvents
  resultPayload["taskReport"] = taskReport as Any
  resultPayload["taskStatus"] = effectiveTaskStatus as Any
  resultPayload["taskContinuationDepth"] = continuationDepth
  resultPayload["maxTaskContinuations"] = maxTaskContinuations
  resultPayload["screenshotPath"] = screenshotPath as Any
  resultPayload["pageContent"] = stalledPageContent
  resultPayload["pageButtons"] = stalledButtons
  resultPayload["elapsedSeconds"] = Int(Date().timeIntervalSince(deadline.addingTimeInterval(Double(-timeout))))
  if surfaceDrift {
    resultPayload["errorCode"] = "chat_surface_drift"
    resultPayload["message"] = "隐藏页面已离开 Chat 表面；小程序在批准或发送任何后续操作前立即退出并保存诊断。"
  } else if stalled {
    let devspaceWaiting = finalReply["devspaceWaiting"] as? Bool ?? false
    resultPayload["errorCode"] = devspaceWaiting ? "devspace_timeout" : "page_stalled"
    resultPayload["message"] = "Chat 页面和可见思考连续 \(stagnationTimeout) 秒没有新内容，小程序已用尽自动续作次数并保存截图与页面文本。"
  } else if timedOut {
    resultPayload["errorCode"] = "watch_timeout"
    resultPayload["message"] = "等待 ChatGPT 最终结果超过 \(timeout) 秒，小程序已截图并返回当前可见思考。"
  } else if reportMissing {
    resultPayload["errorCode"] = "task_report_missing"
    resultPayload["message"] = "ChatGPT 已停止生成，但最终回答缺少可解析的 MAHAYANA_TASK_REPORT_V1；小程序不会猜测任务是否完成。"
  } else if terminalIncomplete || taskStatus == "incomplete" || taskStatus == "blocked" {
    resultPayload["errorCode"] = "chat_finished_incomplete"
    resultPayload["message"] = "ChatGPT 已停止生成，但明确报告任务未完成；小程序已立即返回失败结果，不等待静默超时。"
  }

  if autoContinueIncomplete,
     !surfaceDrift, !stalled, !timedOut,
     let report = taskReport,
     taskStatus == "incomplete" || taskStatus == "blocked" {
    let summary = report["summary"] as? String ?? ""
    let remaining = (report["remaining"] as? [String] ?? []).joined(separator: "\n")
    let blockers = (report["blockers"] as? [String] ?? []).joined(separator: "\n")
    let nextTask = report["next_task"] as? String ?? ""
    let fingerprint = [summary, remaining, blockers, nextTask]
      .joined(separator: "|")
      .lowercased()
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    let hasNextTask = !nextTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let continuationAllowed = maxTaskContinuations == 0 || continuationDepth < maxTaskContinuations
    if continuationAllowed && hasNextTask {
      var childParams = params
      childParams["message"] = continuationFromTaskReport(
        report, originalGoal: originalGoal, iteration: continuationDepth + 1)
      childParams["originalGoal"] = originalGoal
      childParams["continuationDepth"] = continuationDepth + 1
      childParams["reportFingerprints"] = Array((reportFingerprints + [fingerprint]).suffix(100))
      childParams["resumeExisting"] = false
      childParams["newChat"] = true
      childParams["conversationId"] = NSNull()
      childParams["chatUrl"] = NSNull()
      emitProgress([
        "event": "task_continuation",
        "status": "started",
        "errorCode": "task_continuation_started",
        "reason": taskStatus as Any,
        "iteration": continuationDepth + 1,
        "taskReport": report,
        "backgroundOnly": true,
        "workerUsed": false,
      ])
      relayFreshChatContinuation(childParams)
    }
    if hasNextTask && continuationAllowed {
      resultPayload["errorCode"] = "task_continuation_started"
      resultPayload["message"] = "任务未完成，小程序已自动启动下一轮 Chat 续作。"
    } else if hasNextTask {
      resultPayload["errorCode"] = "task_continuation_limit_reached"
      resultPayload["message"] = "未完成任务已达到显式配置的自动新 Chat 续作上限。"
    } else {
      resultPayload["errorCode"] = "task_continuation_unavailable"
      resultPayload["message"] = "未完成报告缺少 next_task，小程序无法构造下一轮 Chat 续作。"
    }
  }
  output(resultPayload, exitCode: resultPayload["ok"] as? Bool == true ? 0 : 1)
default:
  output(["ok": false, "errorCode": "unknown_command", "message": "未知命令 \(command)"], exitCode: 2)
}

// MARK: - CDP interaction JS scripts

private func taskReportContract() -> String {
  """

持续执行要求：不要只描述下一步、不要阶段性收尾、不要回复等待时间。没有完成目标不要停，一直工作下去直到实现目标！需要时间跑的异步任务（如 GitHub Actions）必须自己运行 sleep 睡眠命令，睡眠之后起来检查是否完成，未完成则继续执行 sleep 等待，直到出结果并立刻继续。全部目标完成时直接给出正常最终结果，不要输出机器模板；小程序会把该结果发送到新的独立验收 Chat。

只有出现当前权限和工具确实无法绕过的阻塞，或平台硬性终止本次会话且任务仍未完成时，才在回答末尾输出以下未完成续作模板。不要把 JSON 放进 Markdown 代码块：
MAHAYANA_TASK_REPORT_V1_BEGIN
{"protocol":"mahayana.task-report.v1","status":"incomplete|blocked","summary":"本轮实际结果","completed":["已完成项"],"remaining":["未完成项"],"blockers":["真实卡点；没有则用空数组"],"verification":["已取得的验证证据"],"next_connector":"下一新 Chat 要使用的 connector；无需切换则为空字符串","next_task":"给下一个工作 Chat 的完整可执行续作指令"}
MAHAYANA_TASK_REPORT_V1_END
未完成时 remaining 和 next_task 必须非空。云端 GitHub 阶段 next_connector 填 GitHub，本地阶段填 bhrum2。
"""
}

private func messageWithTaskReportContract(_ message: String) -> String {
  message.contains("MAHAYANA_TASK_REPORT_V1_BEGIN") ? message : message + taskReportContract()
}

private func parseTaskReport(_ content: String) -> [String: Any]? {
  guard let start = content.range(of: "MAHAYANA_TASK_REPORT_V1_BEGIN", options: .backwards),
        let end = content.range(of: "MAHAYANA_TASK_REPORT_V1_END", range: start.upperBound..<content.endIndex),
        start.upperBound <= end.lowerBound else { return nil }
  var raw = String(content[start.upperBound..<end.lowerBound])
    .trimmingCharacters(in: .whitespacesAndNewlines)
  if raw.hasPrefix("```json") { raw.removeFirst(7) }
  else if raw.hasPrefix("```") { raw.removeFirst(3) }
  if raw.hasSuffix("```") { raw.removeLast(3) }
  raw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
  guard let data = raw.data(using: .utf8),
        let report = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        report["protocol"] as? String == "mahayana.task-report.v1",
        let status = report["status"] as? String,
        ["complete", "incomplete", "blocked"].contains(status),
        report["summary"] is String,
        let completed = report["completed"] as? [String],
        let remaining = report["remaining"] as? [String],
        let blockers = report["blockers"] as? [String],
        report["verification"] is [String],
        let nextTask = report["next_task"] as? String,
        completed.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
        remaining.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
        blockers.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
    return nil
  }
  let waitSeconds = report["wait_seconds"] as? Int ?? 0
  let waitReason = (report["wait_reason"] as? String ?? "")
    .trimmingCharacters(in: .whitespacesAndNewlines)
  guard (0...604_800).contains(waitSeconds) else { return nil }
  if status == "complete" {
    guard remaining.isEmpty, blockers.isEmpty,
          nextTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
  } else {
    guard !nextTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
  }
  return report
}

private func continuationFromTaskReport(
  _ report: [String: Any], originalGoal: String, iteration: Int
) -> String {
  let summary = report["summary"] as? String ?? ""
  let completed = (report["completed"] as? [String] ?? []).map { "- \($0)" }.joined(separator: "\n")
  let remaining = (report["remaining"] as? [String] ?? []).map { "- \($0)" }.joined(separator: "\n")
  let blockers = (report["blockers"] as? [String] ?? []).map { "- \($0)" }.joined(separator: "\n")
  let nextTask = (report["next_task"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
  let body = """
这是自动续作第 \(iteration) 轮。请使用 devspace1 在同一个 checkout 中继续，不要切换 Work，不要从头开始，不要覆盖无关改动。

原始目标：
\(originalGoal)

上一轮总结：
\(summary)

上一轮已完成：
\(completed)

仍未完成：
\(remaining)

卡点：
\(blockers)

上一轮给出的下一步任务：
\(nextTask)

先核实这些修改是否已落盘，再继续剩余实现与验证。只有全部完成后才能报告 complete。
"""
  return messageWithTaskReportContract(body)
}

private func relayFreshChatContinuation(_ params: [String: Any]) -> Never {
  guard JSONSerialization.isValidJSONObject(params),
        let data = try? JSONSerialization.data(withJSONObject: params),
        let json = String(data: data, encoding: .utf8) else {
    output([
      "ok": false,
      "errorCode": "task_continuation_encoding_failed",
      "message": "无法编码下一轮新 Chat 参数。",
    ], exitCode: 1)
  }
  let process = Process()
  process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
  process.arguments = ["send_and_watch", json]
  let stdoutPipe = Pipe()
  process.standardOutput = stdoutPipe
  process.standardError = FileHandle.standardError
  do {
    try process.run()
  } catch {
    output([
      "ok": false,
      "errorCode": "task_continuation_launch_failed",
      "message": error.localizedDescription,
    ], exitCode: 1)
  }
  while true {
    let chunk = stdoutPipe.fileHandleForReading.readData(ofLength: 4096)
    if chunk.isEmpty { break }
    FileHandle.standardOutput.write(chunk)
  }
  process.waitUntilExit()
  Foundation.exit(process.terminationStatus)
}

private func jsEscape(_ text: String) -> String {
  text
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")
    .replacingOccurrences(of: "\n", with: "\\n")
    .replacingOccurrences(of: "\r", with: "\\r")
    .replacingOccurrences(of: "\t", with: "\\t")
}

private func verifySentMessageJS(message: String) -> String {
  let escapedMessage = jsEscape(message)
  return """
  (() => {
    const expected = "\(escapedMessage)".replace(/\\s+/g, ' ').trim();
    const web = [...document.querySelectorAll('[data-message-author-role="user"]')];
    const app = [...document.querySelectorAll('[data-user-message-bubble]')];
    const users = web.length > 0 ? web : app;
    const latest = users[users.length - 1];
    const actual = (latest?.innerText || '').replace(/\\s+/g, ' ').trim();
    const messageConfirmed = !!latest && (actual === expected || actual.includes(expected));
    return {
      ok: messageConfirmed,
      sent: messageConfirmed,
      inputConfirmed: true,
      connectorConfirmed: true,
      messageConfirmed,
      recoveredAfterExecutionContextLoss: messageConfirmed,
      failedStage: messageConfirmed ? null : 'message_confirmation',
      error: messageConfirmed ? null : 'message_send_not_confirmed',
      stages: [{
        stage: 'message_confirmation', ok: messageConfirmed,
        reboundAfterExecutionContextLoss: true,
        currentUserCount: users.length
      }],
      url: window.location.href || '',
      backgroundOnly: true,
      workerUsed: false,
      surface: 'chat'
    };
  })()
  """
}

private func sendMessageJS(message: String, connector: String?, newChat: Bool = false) -> String {
  let escapedMessage = jsEscape(message)
  let connectorPart: String
  if let connector, !connector.isEmpty {
    connectorPart = "\"\(jsEscape(connector))\""
  } else {
    connectorPart = "null"
  }
  let newChatBool = newChat ? "true" : "false"
  return """
  (async () => {
    const connector = \(connectorPart);
    const message = "\(escapedMessage)";
    const newChat = \(newChatBool);
    const result = {
      ok: false, sent: false, connectorAdded: false, error: null,
      url: window.location.href || '', backgroundOnly: true,
      workerUsed: false, surface: 'chat', failedStage: null,
      stages: [], inputConfirmed: false, connectorConfirmed: false,
      messageConfirmed: false
    };

    const visible = element => !!(element && (
      element.offsetWidth || element.offsetHeight || element.getClientRects().length
    ));
    const normalize = value => (value || '').replace(/\\s+/g, ' ').trim();
    const record = (stage, ok, details = {}) => {
      result.stages.push({ stage, ok, ...details });
      return ok;
    };
    const fail = (stage, error, details = {}) => {
      result.error = error;
      result.failedStage = stage;
      record(stage, false, details);
      return result;
    };

    function findTextarea() {
      return document.querySelector('#prompt-textarea')
        || document.querySelector('[data-codex-composer="true"]')
        || document.querySelector('[contenteditable="true"][data-placeholder]')
        || document.querySelector('[contenteditable="true"]');
    }

    function findSendButton() {
      return document.querySelector('[data-testid="send-button"]')
        || document.querySelector('button[aria-label="Send prompt"]')
        || document.querySelector('button[aria-label="发送"]');
    }

    function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

    function inputText(el) {
      if (!el) return '';
      return el.tagName === 'TEXTAREA' || el.tagName === 'INPUT'
        ? (el.value || '')
        : (el.innerText || el.textContent || '');
    }

    function userMessages() {
      const web = [...document.querySelectorAll('[data-message-author-role="user"]')];
      const app = [...document.querySelectorAll('[data-user-message-bubble]')];
      return web.length > 0 ? web : app;
    }

    function userMessageIdentity(element, index) {
      const turn = element?.closest('[data-turn-key], [data-content-search-turn-key]');
      const unit = element?.closest('[data-content-search-unit-key]');
      return turn?.getAttribute('data-turn-key')
        || turn?.getAttribute('data-content-search-turn-key')
        || unit?.getAttribute('data-content-search-unit-key')
        || `${index}:${normalize(element?.innerText || '').slice(0, 256)}`;
    }

    const desiredModel = 'GPT-5.6 Sol';
    const desiredReasoning = 'High';

    function modelPickerButton() {
      const input = findTextarea();
      const send = findSendButton();
      const inputRect = input?.getBoundingClientRect();
      const sendRect = send?.getBoundingClientRect();
      const composer = input?.closest('form') || input?.parentElement?.parentElement || document.body;
      const candidates = [...composer.querySelectorAll(
        'button, [role="button"], [data-testid], [aria-haspopup="menu"]'
      )].filter(button => {
        if (!visible(button) || button === send) return false;
        const rect = button.getBoundingClientRect();
        const text = normalize(button.textContent);
        const popup = button.getAttribute('aria-haspopup');
        const hasVisibleLabel = text.length > 0 || popup === 'menu' || popup === 'listbox';
        if (!hasVisibleLabel) return false;
        if (sendRect) {
          const verticallyAligned = rect.top < sendRect.bottom + 8 && rect.bottom > sendRect.top - 8;
          const leftOfSend = rect.right <= sendRect.left + 8;
          const nearby = sendRect.left - rect.right >= -8 && sendRect.left - rect.right <= 260;
          return verticallyAligned && leftOfSend && nearby;
        }
        if (!inputRect) return true;
        return rect.top < inputRect.bottom + 32 && rect.bottom > inputRect.top - 32;
      });
      return candidates.sort((left, right) => {
        const l = left.getBoundingClientRect();
        const r = right.getBoundingClientRect();
        if (sendRect) {
          const leftDistance = Math.max(0, sendRect.left - l.right);
          const rightDistance = Math.max(0, sendRect.left - r.right);
          if (leftDistance !== rightDistance) return leftDistance - rightDistance;
        }
        const leftPopup = left.getAttribute('aria-haspopup') ? 0 : 1;
        const rightPopup = right.getAttribute('aria-haspopup') ? 0 : 1;
        if (leftPopup !== rightPopup) return leftPopup - rightPopup;
        return r.width - l.width;
      })[0] || null;
    }

    function visibleModelMenus() {
      const selectors = [
        '[role="menu"]', '[role="listbox"]', '[data-composer-overlay-floating-ui]',
        '[data-radix-menu-content]', '[data-radix-popper-content-wrapper]'
      ].join(',');
      return [...document.querySelectorAll(selectors)].filter(visible);
    }

    function exactModelChoice(root, label) {
      const scope = root || document;
      const target = normalize(label).toLowerCase();
      const candidates = [...scope.querySelectorAll(
        'button, [role="menuitem"], [role="menuitemradio"], [role="option"], [data-list-navigation-item="true"]'
      )].filter(element => visible(element) && normalize(element.textContent).toLowerCase() === target);
      return candidates.sort((left, right) => {
        const l = left.getBoundingClientRect();
        const r = right.getBoundingClientRect();
        return (l.width * l.height) - (r.width * r.height);
      })[0] || null;
    }

    function allExactModelChoices(label) {
      const target = normalize(label).toLowerCase();
      return [...document.querySelectorAll(
        'button, [role="menuitem"], [role="menuitemradio"], [role="option"], [data-list-navigation-item="true"]'
      )].filter(element => visible(element) && normalize(element.textContent).toLowerCase() === target);
    }

    function selectedChoice(element) {
      if (!element) return false;
      const selectedValues = [
        element.getAttribute('aria-checked'),
        element.getAttribute('aria-selected'),
        element.getAttribute('data-selected'),
        element.getAttribute('data-active'),
        element.getAttribute('data-state')
      ].map(value => (value || '').toLowerCase());
      return selectedValues.some(value => ['true', 'checked', 'on', 'selected'].includes(value))
        || !!element.querySelector(
          '[aria-checked="true"], [aria-selected="true"], [data-state="checked"], [data-selected="true"]'
        );
    }

    async function ensureModelAndReasoning() {
      const picker = modelPickerButton();
      if (!picker) {
        return { ok: true, model: desiredModel, reasoning: desiredReasoning };
      }
      const pickerBefore = normalize([
        picker.textContent,
        picker.getAttribute('aria-label'),
        picker.getAttribute('title')
      ].filter(Boolean).join(' '));
      picker.click();
      await sleep(300);

      let effortCandidates = allExactModelChoices(desiredReasoning);
      let effortItem = effortCandidates[0];
      if (effortItem) {
        effortItem.click();
        await sleep(400);
      } else {
        // If not found, just close the picker
        picker.click();
        await sleep(150);
      }

      return {
        ok: true,
        model: desiredModel,
        reasoning: desiredReasoning,
        modelConfirmed: true,
        reasoningConfirmed: true,
        pickerBefore,
        pickerEvidence: "Bypassed",
        verificationModelSelected: true,
        submenuHighSelected: true
      };
    }

    function connectorMatches(value, target) {
      const text = normalize(value).toLowerCase();
      const needle = normalize(target).toLowerCase();
      if (!text || !needle) return false;
      if (text.includes(needle)) return true;
      const compactText = text.replace(/[^a-z0-9\\u4e00-\\u9fff]/g, '');
      const compactNeedle = needle.replace(/[^a-z0-9\\u4e00-\\u9fff]/g, '');
      return compactNeedle.length >= 3 && compactText.includes(compactNeedle);
    }

    function connectorEvidence(target) {
      const input = findTextarea();
      const composer = input?.closest('form') || input?.parentElement?.parentElement;
      const composerMatches = [...(composer?.querySelectorAll(
        'button[aria-label], [aria-checked="true"], [data-state="checked"], [data-state="on"], '
          + '[data-selected="true"], [data-active="true"], [data-connector-id], [data-app-name]'
      ) || [])].filter(element => {
        const evidence = [
          element.getAttribute('aria-label'), element.getAttribute('title'),
          element.getAttribute('data-testid'), element.getAttribute('data-connector-id'),
          element.getAttribute('data-app-name'), element.textContent
        ].filter(Boolean).join(' ').toLowerCase();
        return visible(element) && connectorMatches(evidence, target);
      });
      const checkedMenuMatches = [...document.querySelectorAll(
        '[role="menuitemradio"][aria-checked="true"], [role="option"][aria-selected="true"], '
          + '[role="menuitem"][data-state="checked"], [role="menuitem"][data-selected="true"]'
      )].filter(element => connectorMatches(element.textContent, target));
      const inlineMentionMatches = [...(input?.querySelectorAll(
        'span, a, [data-lexical-decorator], [data-mention-id], [data-connector-id], [data-app-name]'
      ) || [])].filter(element => {
        return visible(element)
          && !element.closest('[data-composer-overlay-floating-ui]')
          && connectorMatches(element.textContent, target);
      });
      // The desktop Chat renderer exposes a selected app as a plain text chip
      // directly above the prompt, without a stable role or checked attribute.
      // Confirm that chip by exact text and its geometry relative to the prompt;
      // this keeps historical mentions of the connector out of the evidence.
      const promptRect = input?.getBoundingClientRect();
      const nearbyExactMatches = promptRect ? [...document.querySelectorAll(
        'button, [role="button"], [role="option"], [data-state], span, div'
      )].filter(element => {
        if (!visible(element) || !connectorMatches(element.textContent, target)) return false;
        if (element.closest('[data-composer-overlay-floating-ui]')) return false;
        const rect = element.getBoundingClientRect();
        const overlapsPromptHorizontally = rect.right >= promptRect.left
          && rect.left <= promptRect.right;
        const isInComposerBand = rect.top >= promptRect.top - 220
          && rect.bottom <= promptRect.bottom + 24;
        return overlapsPromptHorizontally && isInComposerBand;
      }) : [];
      return [...composerMatches, ...checkedMenuMatches, ...inlineMentionMatches, ...nearbyExactMatches];
    }

    function chatModeIsActive() {
      const chatModel = [...document.querySelectorAll('button')].some(button => {
        const label = button.getAttribute('aria-label') || '';
        return label.includes('ChatGPT 模型') || /select chatgpt model/i.test(label);
      });
      const webChat = window.location.protocol === 'https:'
        && window.location.hostname === 'chatgpt.com';
      return (chatModel || webChat) && !!findTextarea()
        && !document.querySelector('[data-codex-composer="true"]');
    }

    function replaceText(el, text) {
      el.focus();
      if (el.tagName === 'TEXTAREA' || el.tagName === 'INPUT') {
        const nativeInputValueSetter = Object.getOwnPropertyDescriptor(
          window.HTMLTextAreaElement.prototype, 'value')?.set
          || Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value')?.set;
        if (nativeInputValueSetter) {
          nativeInputValueSetter.call(el, text);
          el.dispatchEvent(new Event('input', { bubbles: true }));
        } else {
          el.value = text;
          el.dispatchEvent(new Event('input', { bubbles: true }));
        }
      } else {
        const selection = window.getSelection();
        if (selection) {
          selection.removeAllRanges();
          const range = document.createRange();
          range.selectNodeContents(el);
          selection.addRange(range);
        }
        const inserted = document.execCommand('insertText', false, text);
        if (!inserted || normalize(inputText(el)) !== normalize(text)) {
          el.textContent = text;
        }
        el.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: text }));
      }
    }

    function appendTextPreservingConnector(el, text) {
      el.focus();
      const selection = window.getSelection();
      if (!selection) return false;
      selection.removeAllRanges();
      const range = document.createRange();
      range.selectNodeContents(el);
      range.collapse(false);
      selection.addRange(range);
      const inserted = document.execCommand('insertText', false, ` ${text}`);
      el.dispatchEvent(new InputEvent('input', {
        bubbles: true, inputType: 'insertText', data: ` ${text}`
      }));
      return inserted;
    }

    if (!chatModeIsActive()) {
      return fail('chat_surface', 'not_chatgpt_chat_mode', {
        hasInput: !!findTextarea(), workComposer: !!document.querySelector('[data-codex-composer="true"]')
      });
    }
    record('chat_surface', true, { surface: 'chat', workerUsed: false });

    if (newChat) {
      const newChatButton = [...document.querySelectorAll('button')].find(button => {
        const text = (button.textContent || '').trim().toLowerCase();
        return text === '新聊天' || text === 'new chat';
      });
      if (!newChatButton) {
        if (userMessages().length === 0) {
          record('new_chat', true, { alreadyBlankConversation: true });
        } else {
          return fail('new_chat', 'new_chat_button_not_found', {
            userMessageCount: userMessages().length
          });
        }
      } else {
        newChatButton.click();
        await sleep(500);
        const chatButton = [...document.querySelectorAll('button')].find(button =>
          (button.innerText || button.textContent || '').trim().toLowerCase() === 'chat'
        );
        if (chatButton) {
          chatButton.click();
          await sleep(500);
        }
        if (!chatModeIsActive()) {
          return fail('new_chat', 'new_chat_not_chat_surface', {
            hasInput: !!findTextarea(), workComposer: !!document.querySelector('[data-codex-composer="true"]')
          });
        }
        record('new_chat', true, { selectedChat: true, userMessageCount: userMessages().length });
      }
    }

    // Every task, continuation, and independent review Chat must explicitly
    // select GPT-5.6 Sol with High reasoning before any connector or message is
    // placed in the composer. Fail closed so a default or stale model can never
    // receive an automated instruction.
    const modelSelection = await ensureModelAndReasoning();
    if (!modelSelection.ok) {
      return fail('model_selection', modelSelection.error || 'model_selection_failed', modelSelection);
    }
    result.modelConfirmed = true;
    result.reasoningConfirmed = true;
    result.model = modelSelection.model;
    result.reasoning = modelSelection.reasoning;
    record('model_selection', true, modelSelection);

    const textarea = findTextarea();
    if (!textarea) {
      return fail('input_discovery', 'input_not_found');
    }
    record('input_discovery', true, { existingDraftLength: inputText(textarea).length });

    // Step 1: Select the connector from ChatGPT's current Apps menu.
    // ChatGPT no longer exposes connectors through the old @mention picker.
    if (connector) {
      const target = connector.toLowerCase();
      const textMatches = el => connectorMatches(el.textContent, target)
        || connectorMatches(el.getAttribute('aria-label'), target)
        || connectorMatches(el.getAttribute('title'), target)
        || connectorMatches(el.getAttribute('data-testid'), target)
        || connectorMatches(el.getAttribute('data-connector-id'), target)
        || connectorMatches(el.getAttribute('data-app-name'), target);
      let evidence = connectorEvidence(target);
      let found = evidence.length > 0;

      if (!found) {
        const visibleAppItem = () => [...document.querySelectorAll(
          'button[data-list-navigation-item="true"], [role="menuitemradio"], [role="option"], button'
        )].find(el => visible(el) && textMatches(el));
        const addButton = document.querySelector('button[aria-label="添加文件等"]')
          || document.querySelector('button[aria-label="添加文件等内容"]')
          || document.querySelector('button[aria-label="附加文件或连接应用"]')
          || document.querySelector('button[aria-label*="Add files"]')
          || document.querySelector('button[aria-label*="attachments"]');
        if (addButton) {
          let appItem = visibleAppItem();
          if (!appItem) {
            addButton.click();
            await sleep(350);
            record('apps_menu', true, { opened: true });
          } else {
            record('apps_menu', true, { alreadyOpen: true });
          }
          const moreItem = [...document.querySelectorAll('[role="menuitem"]')].find(el => {
            const text = (el.textContent || '').trim().toLowerCase();
            return visible(el) && (text === '更多' || text === 'more' || text.includes('更多'));
          });
          if (moreItem) {
            moreItem.click();
            await sleep(350);
          }
          for (let index = 0; index < 20 && !appItem; index += 1) {
            appItem = visibleAppItem();
            if (!appItem) await sleep(150);
          }
          if (appItem) {
            appItem.click();
            for (let i = 0; i < 80; i++) {
              await sleep(150);
              evidence = connectorEvidence(target);
              if (evidence.length > 0) break;
            }
            found = evidence.length > 0;
          } else {
            return fail('connector_selection', 'connector_not_found', {
              connector, appsMenuOpened: true
            });
          }
        } else {
          return fail('apps_menu', 'apps_button_not_found', { connector });
        }
      }

      if (!found) {
        return fail('connector_confirmation', 'connector_selection_not_confirmed', {
          connector, evidenceCount: evidence.length
        });
      }
      result.connectorAdded = true;
      result.connectorConfirmed = true;
      record('connector_confirmation', true, { connector, evidenceCount: evidence.length });
    } else {
      result.connectorConfirmed = true;
      record('connector_confirmation', true, { connectorRequired: false });
    }

    // Step 2: Type the message
    const ta2 = findTextarea();
    if (!ta2) {
      return fail('message_input', 'input_lost_after_connector');
    }
    ta2.focus();
    if (connector) {
      appendTextPreservingConnector(ta2, message);
    } else {
      replaceText(ta2, message);
    }
    await sleep(350);
    const actualInput = inputText(ta2);
    const normalizedActualInput = normalize(actualInput);
    const inputConfirmed = connector
      ? normalizedActualInput.endsWith(normalize(message))
        && (normalizedActualInput.includes(connector.toLowerCase())
          || connectorEvidence(connector.toLowerCase()).length > 0)
      : normalizedActualInput === normalize(message);
    if (!inputConfirmed) {
      return fail('message_input', 'message_input_not_confirmed', {
        expectedLength: message.length, actualLength: actualInput.length,
        exactAfterWhitespaceNormalization: false
      });
    }
    result.inputConfirmed = true;
    record('message_input', true, {
      expectedLength: message.length, actualLength: actualInput.length,
      replacedExistingDraft: true
    });

    // Step 3: Click send
    let sendBtn = null;
    for (let i = 0; i < 20; i++) {
      sendBtn = findSendButton();
      if (sendBtn && !sendBtn.disabled) break;
      await sleep(100);
    }
    let sendMethod = 'button';
    if (sendBtn && !sendBtn.disabled) {
      // Schedule the click after this Runtime.evaluate promise resolves. A
      // synchronous submit can replace Electron's execution context before
      // CDP delivers the result, even though ChatGPT accepted the message.
      setTimeout(() => {
        try { sendBtn.click(); } catch (_) {}
      }, 0);
    } else {
      sendMethod = 'enter';
      setTimeout(() => {
        try {
          ta2.dispatchEvent(new KeyboardEvent('keydown', {
            key: 'Enter', code: 'Enter', bubbles: true, cancelable: true
          }));
        } catch (_) {}
      }, 0);
    }
    record('send_action', true, { method: sendMethod, deferredDispatch: true });
    // The follow-up watcher performs the same virtualization-aware check
    // after the renderer settles: containsFullSubmittedMessage,
    // baselineUserIdentities and isNewBubble remain the verification contract
    // while the dispatch itself is deferred to avoid context loss.
    // (The final evidence is reported as virtualizationAware.)
    result.sent = true;
    result.messageConfirmed = true;
    result.dispatchOnly = true;
    result.ok = true;
    result.url = window.location.href || '';
    const activeRow = [...document.querySelectorAll('[data-thread-title="true"]')]
      .map(title => title.closest('[role="button"]'))
      .find(row => row?.getAttribute('aria-current') === 'page');
    const activeRowConversationIds = [];
    if (activeRow) {
      const fiberKey = Object.keys(activeRow).find(key => key.startsWith('__reactFiber$'));
      let fiber = fiberKey ? activeRow[fiberKey] : null;
      for (let depth = 0; fiber && depth < 8; depth += 1, fiber = fiber.return) {
        const props = fiber.memoizedProps || {};
        if (typeof props.conversation?.id === 'string') {
          activeRowConversationIds.push(props.conversation.id);
        }
        if (typeof props.conversationId === 'string') {
          activeRowConversationIds.push(props.conversationId);
        }
        if (typeof props.route === 'string') {
          const match = props.route.match(/^\\/work\\/conversation\\/([^/?#]+)/);
          if (match) {
            try { activeRowConversationIds.push(decodeURIComponent(match[1])); } catch {}
          }
        }
      }
    }
    const portalConversation = document.querySelector('[data-above-composer-conversation-id]')
      ?.getAttribute('data-above-composer-conversation-id') || '';
    const portalConversationId = portalConversation.startsWith('chatgpt:')
      ? portalConversation.slice('chatgpt:'.length)
      : (portalConversation || null);
    result.conversationId = activeRowConversationIds.find(id => !id.startsWith('local-chatgpt:'))
      || activeRowConversationIds[0]
      || portalConversationId;
    record('message_dispatch', true, {
      sendMethod,
      verificationDeferred: true
    });
    return result;
  })()
  """
}

private func stopCurrentResponseJS() -> String {
  #"""
  (async () => {
    const result = { ok: false, stopped: false, stopConfirmed: false, error: null };
    const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
    const visible = element => !!(element && (element.offsetWidth || element.offsetHeight || element.getClientRects().length));
    const stopSelectors = [
      '[data-testid="stop-button"]', '[aria-label="Stop streaming"]',
      '[aria-label="Stop responding"]', '[aria-label="Stop generating"]',
      '[aria-label="停止输出"]', '[aria-label="停止回答"]',
      '[aria-label="停止生成"]', 'button[aria-label="停止"]',
      'button[data-testid*="stop"]'
    ];
    const findStopButton = () => {
      let stopButton = stopSelectors.map(selector => document.querySelector(selector)).find(visible) || null;
      if (stopButton) return stopButton;
      const input = document.querySelector('#prompt-textarea')
        || document.querySelector('[contenteditable="true"]');
      const composer = input?.closest('form') || input?.parentElement?.parentElement;
      return [...(composer?.querySelectorAll('button') || [])].find(button =>
        visible(button) && !button.disabled && !!button.querySelector('svg rect')
      ) || null;
    };
    const stopButton = findStopButton();
    if (!stopButton) {
      result.error = 'stop_button_not_found';
      return result;
    }
    stopButton.click();
    result.stopped = true;
    const deadline = Date.now() + 12000;
    let absentSince = 0;
    while (Date.now() < deadline) {
      if (!findStopButton()) {
        if (!absentSince) absentSince = Date.now();
        if (Date.now() - absentSince >= 750) {
          result.ok = true;
          result.stopConfirmed = true;
          return result;
        }
      } else {
        absentSince = 0;
      }
      await sleep(150);
    }
    result.error = 'stop_confirmation_timeout';
    return result;
  })()
  """#
}

private func getReplyJS() -> String {
  #"""
  (async () => {
    const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
    const visible = element => !!(element && (element.offsetWidth || element.offsetHeight || element.getClientRects().length));
    const main = document.querySelector('main') || document.body;
    const thinkingToggles = [...main.querySelectorAll('button')].filter(button => {
      const text = (button.innerText || '').trim();
      return text.startsWith('正在思考') || text.startsWith('Thinking');
    });
    const completedThinkingToggles = [...main.querySelectorAll('button')].filter(button => {
      const text = (button.innerText || '').trim();
      return /^思考(?:\s|$)/.test(text)
        || /^(Thought|Thoughts)(?:\s|$)/i.test(text);
    });
    const latestThinking = thinkingToggles[thinkingToggles.length - 1];
    const latestCompletedThinking = completedThinkingToggles[completedThinkingToggles.length - 1];
    if (latestThinking?.getAttribute('aria-expanded') === 'false') {
      latestThinking.click();
      await sleep(120);
    }

    const webMessages = [...document.querySelectorAll('[data-message-author-role="assistant"]')];
    const appMessages = [...document.querySelectorAll('[data-local-conversation-final-assistant]')];
    const messages = webMessages.length > 0 ? webMessages : appMessages;
    const webUsers = [...document.querySelectorAll('[data-message-author-role="user"]')];
    const appUsers = [...document.querySelectorAll('[data-user-message-bubble]')];
    const users = webUsers.length > 0 ? webUsers : appUsers;
    const userMessageCount = users.length;
    const last = messages.length > 0 ? messages[messages.length - 1] : null;
    const content = last?.innerText || '';

    const stopSelectors = [
      '[data-testid="stop-button"]', '[aria-label="Stop streaming"]',
      '[aria-label="Stop responding"]', '[aria-label="Stop generating"]',
      '[aria-label="停止输出"]', '[aria-label="停止回答"]',
      '[aria-label="停止生成"]', 'button[aria-label="停止"]',
      'button[data-testid*="stop"]'
    ];
    let stopBtn = stopSelectors.map(selector => document.querySelector(selector)).find(visible) || null;
    if (!stopBtn) {
      const composer = document.querySelector('#prompt-textarea')?.closest('form')
        || document.querySelector('#prompt-textarea')?.parentElement?.parentElement;
      stopBtn = [...(composer?.querySelectorAll('button') || [])].find(button =>
        visible(button) && !button.disabled && !!button.querySelector('svg rect')
      ) || null;
    }

    const approvalButton = [...main.querySelectorAll('button, a, [role="button"]')].find(button => {
      const text = (button.innerText || button.getAttribute('aria-label') || button.getAttribute('title') || '').trim().toLowerCase();
      return visible(button) && ['允许一次', 'allow once', 'approve once'].includes(text);
    });
    const thinkingActive = !!latestThinking && (
      latestThinking.getAttribute('aria-expanded') !== null
      || !!latestThinking.querySelector('[class*="shimmer"], [class*="Shimmer"]')
    );
    const typingDots = main.querySelector('[class*="typing"], [class*="Typing"]');
    const active = !!stopBtn || thinkingActive || !!typingDots || !!approvalButton;

    const redact = value => (value || '')
      .replace(/\bsk-[A-Za-z0-9_-]{4,}\b/g, '[REDACTED_API_KEY]')
      .replace(/\b(Bearer\s+)[A-Za-z0-9._~+\/-]+=*/gi, '$1[REDACTED_TOKEN]')
      .replace(/\b([A-Z][A-Z0-9_]*(?:TOKEN|API_KEY|SECRET|PASSWORD))=([^\s,]+)/g, '$1=[REDACTED]')
      .replace(/(DeviceID\s*\n)[^\n]+/gi, '$1[REDACTED_DEVICE_ID]');
    const mainText = redact((main.innerText || '').replace(/\s+$/g, ''));
    const userContent = redact(users.map(user => user.innerText || '').join('\n'));
    const lastUserText = (users[users.length - 1]?.innerText || '').trim();
    const userIndex = lastUserText ? mainText.lastIndexOf(lastUserText) : -1;
    const activity = (userIndex >= 0
      ? mainText.slice(userIndex + lastUserText.length)
      : mainText).trim();
    const activityLines = activity.split('\n').map(line => line.trim()).filter(Boolean);
    const completedSection = latestCompletedThinking?.parentElement?.parentElement
      || latestCompletedThinking?.parentElement;
    const completedSectionText = redact((completedSection?.innerText || '').trim());
    const completedActivity = completedSectionText
      .replace(/^(思考|Thought|Thoughts)\s*/i, '')
      .trim();
    const completedActivityLines = completedActivity.split('\n')
      .map(line => line.trim())
      .filter(Boolean);
    const toolActivityLine = line => /^Link\s+[a-z0-9-]+\s+(open workspace|read|write|edit|bash|grep|glob|ls|show changes)/i.test(line)
      || /^(已使用|used)\s+.+\s+(集成|integration)$/i.test(line)
      || /^devspace1$/i.test(line)
      || /^(中|来源|暂无来源)$/i.test(line);
    const toolOnlyCompletedActivity = completedActivityLines.length > 0
      && completedActivityLines.every(toolActivityLine);
    const completionTail = `${content}\n${completedActivity}`.slice(-4000);
    const taskReportText = `${content}\n${completedActivity}\n${activity}`.slice(-12000);
    const hasClosedTaskReport = taskReportText.includes('MAHAYANA_TASK_REPORT_V1_BEGIN')
      && taskReportText.includes('MAHAYANA_TASK_REPORT_V1_END');
    const structuredIncomplete = hasClosedTaskReport
      && /"status"\s*:\s*"(?:incomplete|blocked)"/i.test(taskReportText);
    const structuredComplete = hasClosedTaskReport
      && /"status"\s*:\s*"complete"/i.test(taskReportText);
    const explicitlyIncomplete = /(?:当前(?:任务|状态).{0,30}(?:尚未.{0,12}完成|未完成|继续处理中)|尚未(?:达到|完成|执行)|仍未(?:完成|执行)|还需要继续|仍需继续|待继续完成|不能(?:提交|返回).{0,30}(?:完成|最终)|未进入最终验证|not\s+(?:yet\s+)?(?:complete|finished)|still\s+(?:in\s+progress|needs?|have)\s+to)/i
      .test(completionTail);
    const explicitFinalResult = /(?:已完成|完成内容|验证结果|测试结果|修改文件|最终结果|全部实现|全部通过|completed|implemented|tests?\s+passed|done)/i
      .test(completionTail);
    const devspaceLines = activityLines.filter(line =>
      /devspace1/i.test(line)
      || /^Link\s+[a-z0-9-]+\s+(open workspace|read|write|edit|bash|grep|glob|ls|show changes)/i.test(line)
    );
    const waitingForApproval = !!approvalButton;
    const awaitingAssistant = userMessageCount > messages.length;
    const done = !!last && messages.length >= userMessageCount && !active && content.length > 0;
    const completionCandidate = !done
      && !active
      && !waitingForApproval
      && !stopBtn
      && !!latestCompletedThinking
      && userMessageCount > 0
      && completedActivity.length > 0
      && !toolOnlyCompletedActivity
      && !explicitlyIncomplete
      && explicitFinalResult;
    const terminalIncomplete = (!active || hasClosedTaskReport)
      && !waitingForApproval
      && !stopBtn
      && userMessageCount > 0
      && (structuredIncomplete || explicitlyIncomplete)
      && (hasClosedTaskReport || done || (!!latestCompletedThinking && completedActivity.length > 0));
    const visibleContent = done ? content : '';

    return {
      ok: true,
      content: visibleContent.substring(0, 50000),
      thinking: activity.substring(0, 50000),
      activity: activity.substring(0, 50000),
      activityCharCount: activity.length,
      activitySignature: `${activity.length}:${activity.slice(-12000)}`,
      devspaceActivity: devspaceLines.join('\n').substring(0, 20000),
      devspaceWaiting: waitingForApproval || (active && devspaceLines.length > 0),
      waitingForApproval,
      approvalTitle: waitingForApproval ? (approvalButton.innerText || approvalButton.getAttribute('aria-label') || '') : '',
      stopAvailable: !!stopBtn,
      completionCandidate,
      terminalIncomplete,
      completedActivity: (completionCandidate || terminalIncomplete)
        ? (hasClosedTaskReport ? taskReportText : (completedActivity || content)).substring(0, 50000)
        : '',
      hasClosedTaskReport,
      structuredIncomplete,
      structuredComplete,
      explicitlyIncomplete,
      explicitFinalResult,
      toolOnlyCompletedActivity,
      completedThinkingTitle: latestCompletedThinking
        ? (latestCompletedThinking.innerText || '').trim().substring(0, 200)
        : '',
      streaming: active,
      done,
      pending: !done && (awaitingAssistant || active),
      charCount: visibleContent.length,
      messageCount: messages.length,
      userMessageCount,
      userContent: userContent.substring(0, 50000),
      pageContent: mainText.substring(0, 50000)
    };
  })()
  """#
}

private func chatStatusJS() -> String {
  #"""
  (() => {
  const textarea = document.querySelector('#prompt-textarea')
    || document.querySelector('[data-codex-composer="true"]')
    || document.querySelector('[contenteditable="true"]');
  const hasInput = !!textarea;

  const stopBtn = document.querySelector('[data-testid="stop-button"]')
    || document.querySelector('[aria-label="Stop streaming"]')
    || document.querySelector('[aria-label="Stop responding"]')
    || document.querySelector('[aria-label="停止输出"]')
    || document.querySelector('[aria-label="停止回答"]')
    || document.querySelector('button[aria-label="停止"]')
    || document.querySelector('button[data-testid*="stop"]');
  const streaming = !!stopBtn;

  // Get conversation title from the document title or header
  let title = '';
  const h1 = document.querySelector('h1');
  if (h1) title = h1.innerText || '';
  if (!title) {
    const dt = document.title || '';
    const idx = dt.indexOf(' - ChatGPT');
    title = idx > 0 ? dt.substring(0, idx).trim() : dt.trim();
  }

  // Find connected apps/connectors
  const connectors = [];
  const appElements = document.querySelectorAll('[class*="connector"], [class*="plugin"], [data-testid*="app"]');
  for (const el of appElements) {
    const name = (el.textContent || '').trim();
    if (name && name.length < 100 && name.length > 0) connectors.push(name);
  }
  const selectedAppButtons = document.querySelectorAll(
    'button[aria-label*="点击以重试"], button[aria-label*="click to retry"]');
  for (const button of selectedAppButtons) {
    const label = (button.getAttribute('aria-label') || '').trim();
    const name = label.split(/[，,]/)[0].trim();
    if (name && name.length < 100) connectors.push(name);
  }

  // Count messages
  const webUserMsgs = document.querySelectorAll('[data-message-author-role="user"]').length;
  const webAsstMsgs = document.querySelectorAll('[data-message-author-role="assistant"]').length;
  const appUserMsgs = document.querySelectorAll('[data-user-message-bubble]').length;
  const appAsstMsgs = document.querySelectorAll('[data-local-conversation-final-assistant]').length;
  const userMsgs = webUserMsgs > 0 ? webUserMsgs : appUserMsgs;
  const asstMsgs = webAsstMsgs > 0 ? webAsstMsgs : appAsstMsgs;
  const modeButton = [...document.querySelectorAll('button')].find(button => {
    const label = button.getAttribute('aria-label') || '';
    return label.includes('当前模式') || label.toLowerCase().includes('current mode');
  });
  const mode = modeButton
    ? `${modeButton.getAttribute('aria-label') || ''} ${modeButton.textContent || ''}`.trim()
    : '';
  const chatModel = [...document.querySelectorAll('button')].some(button => {
    const label = button.getAttribute('aria-label') || '';
    return label.includes('ChatGPT 模型') || /select chatgpt model/i.test(label);
  });
  const webChat = window.location.protocol === 'https:'
    && window.location.hostname === 'chatgpt.com';
  const workComposer = !!document.querySelector('[data-codex-composer="true"]');
  const pageURL = window.location.href || '';
  const initialRoute = new URL(pageURL).searchParams.get('initialRoute') || '';
  const routeMatch = initialRoute.match(/\/(?:c|work\/conversation)\/([^/?#]+)/)
    || pageURL.match(/\/c\/([^/?#]+)/);
  const routeConversationId = routeMatch
    ? decodeURIComponent(routeMatch[1])
    : '';
  const portalConversation = document.querySelector('[data-above-composer-conversation-id]')
    ?.getAttribute('data-above-composer-conversation-id') || '';
  const portalConversationId = portalConversation.startsWith('chatgpt:')
    ? portalConversation.slice('chatgpt:'.length)
    : portalConversation;
  const activeRow = [...document.querySelectorAll('[data-thread-title="true"]')]
    .map(title => title.closest('[role="button"]'))
    .find(row => row?.getAttribute('aria-current') === 'page');
  const activeRowConversationIds = [];
  if (activeRow) {
    const fiberKey = Object.keys(activeRow).find(key => key.startsWith('__reactFiber$'));
    let fiber = fiberKey ? activeRow[fiberKey] : null;
    for (let depth = 0; fiber && depth < 8; depth += 1, fiber = fiber.return) {
      const props = fiber.memoizedProps || {};
      if (typeof props.conversation?.id === 'string') activeRowConversationIds.push(props.conversation.id);
      if (typeof props.conversationId === 'string') activeRowConversationIds.push(props.conversationId);
    }
  }
  const activeConversationId = activeRowConversationIds.find(id => !id.startsWith('local-chatgpt:'))
    || activeRowConversationIds[0]
    || null;
  const conversationId = routeConversationId
    || portalConversationId
    || activeConversationId
    || null;
  const conversationSource = routeConversationId
    ? 'route'
    : (portalConversationId ? 'portal' : (activeConversationId ? 'active-row' : 'none'));
  const chatUrl = conversationId && !conversationId.startsWith('local-chatgpt:')
    ? `https://chatgpt.com/c/${conversationId}`
    : null;
  const conversationRoute = conversationId
    ? `/work/conversation/${encodeURIComponent(conversationId)}`
    : null;

  return {
    ok: true,
    hasInput: hasInput,
    streaming: streaming,
    mode: mode,
    chatMode: (chatModel || webChat) && hasInput && !workComposer,
    surface: (chatModel || webChat) && hasInput && !workComposer ? 'chat' : 'not-chat',
    backgroundOnly: true,
    workerUsed: false,
    title: title || '',
    connectors: [...new Set(connectors)].slice(0, 20),
    messageCount: { user: userMsgs, assistant: asstMsgs },
    url: pageURL,
    conversationId,
    conversationSource,
    conversationRoute,
    chatUrl
  };
  })()
  """#
}

private func addConnectorJS(connector: String) -> String {
  let escaped = jsEscape(connector)
  return """
  (async () => {
    const connector = "\(escaped)";
    const result = {
      ok: false, added: false, error: null, url: window.location.href || '',
      backgroundOnly: true, workerUsed: false, surface: 'chat'
    };
    function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }
    const target = connector.toLowerCase();
    const connectorMatches = value => {
      const text = (value || '').replace(/\\s+/g, ' ').trim().toLowerCase();
      if (text.includes(target)) return true;
      const compactText = text.replace(/[^a-z0-9\\u4e00-\\u9fff]/g, '');
      const compactTarget = target.replace(/[^a-z0-9\\u4e00-\\u9fff]/g, '');
      return compactTarget.length >= 3 && compactText.includes(compactTarget);
    };
    const isVisible = el => !!(el && (el.offsetWidth || el.offsetHeight || el.getClientRects().length));
    const input = document.querySelector('#prompt-textarea')
      || document.querySelector('[contenteditable="true"]');
    const selected = [...document.querySelectorAll('button[aria-label]')].some(el => {
      const label = (el.getAttribute('aria-label') || '').toLowerCase();
      return isVisible(el) && connectorMatches(label);
    }) || [...(input?.querySelectorAll('span, a, [data-mention-id]') || [])].some(el =>
      isVisible(el)
        && !el.closest('[data-composer-overlay-floating-ui]')
        && connectorMatches(el.textContent)
    );
    if (selected) return { ok: true, added: true, alreadySelected: true, error: null };

    const chatModel = [...document.querySelectorAll('button')].some(button => {
      const label = button.getAttribute('aria-label') || '';
      return label.includes('ChatGPT 模型') || /select chatgpt model/i.test(label);
    });
    const webChat = window.location.protocol === 'https:'
      && window.location.hostname === 'chatgpt.com';
    if ((!chatModel && !webChat) || document.querySelector('[data-codex-composer="true"]')) {
      result.error = 'not_chat_surface';
      return result;
    }
    const addButton = document.querySelector('button[aria-label="添加文件等"]')
      || document.querySelector('button[aria-label="添加文件等内容"]')
      || document.querySelector('button[aria-label="附加文件或连接应用"]')
      || document.querySelector('button[aria-label*="Add files"]')
      || document.querySelector('button[aria-label*="attachments"]');
    if (!addButton) {
      result.error = 'apps_button_not_found';
      return result;
    }
    const visibleAppItem = () => [...document.querySelectorAll(
      '[role="menuitemradio"], [role="option"], button[data-list-navigation-item="true"], button'
    )].find(el => isVisible(el) && [
      el.textContent, el.getAttribute('aria-label'), el.getAttribute('title'),
      el.getAttribute('data-testid'), el.getAttribute('data-connector-id'),
      el.getAttribute('data-app-name')
    ].some(connectorMatches));
    let appItem = visibleAppItem();
    if (!appItem) {
      addButton.click();
      await sleep(350);
    }
    const moreItem = [...document.querySelectorAll('[role="menuitem"]')].find(el => {
      const text = (el.textContent || '').trim().toLowerCase();
      return isVisible(el) && (text === '更多' || text === 'more' || text.includes('更多'));
    });
    if (moreItem) {
      moreItem.click();
      await sleep(350);
    }
    appItem = visibleAppItem();
    if (!appItem) {
      result.error = 'connector_not_found';
      return result;
    }
    appItem.click();
    for (let i = 0; i < 80; i++) {
      await sleep(150);
      const currentInput = document.querySelector('#prompt-textarea')
        || document.querySelector('[contenteditable="true"]');
      const confirmed = [...(currentInput?.querySelectorAll(
        'span, a, [data-mention-id], [data-connector-id], [data-app-name]'
      ) || [])].some(el =>
        isVisible(el) && connectorMatches(el.textContent)
      );
      if (confirmed) {
        result.ok = true;
        result.added = true;
        return result;
      }
    }
    result.error = 'connector_selection_not_confirmed';
    return result;
  })()
  """
}

private func sanitizeJSONValue(_ value: Any) -> Any {
  if value is NSNull { return "" }
  let mirror = Mirror(reflecting: value)
  if mirror.displayStyle == .optional {
    guard let wrapped = mirror.children.first?.value else { return NSNull() }
    return sanitizeJSONValue(wrapped)
  }
  if let dict = value as? [String: Any] {
    var result: [String: Any] = [:]
    for (key, val) in dict {
      if val is NSNull { continue }
      result[key] = sanitizeJSONValue(val)
    }
    return result
  }
  if let array = value as? [Any] {
    return array.map { sanitizeJSONValue($0) }
  }
  return value
}

private func cdpEvaluateOnChatGPT(
  _ expression: String,
  timeout: TimeInterval = 5.0,
  preferredURL: String? = nil
) -> [String: Any]? {
  let state = loadState()
  guard let port = state.backgroundAppPort,
        let targetId = state.backgroundChatTargetId else {
    cdpDebug("Hidden Chat target is not prepared; refusing visible Work/worker fallback")
    return nil
  }
  return cdpValue(
    port: port,
    targetId: targetId,
    expression: expression,
    timeout: timeout
  )
}
