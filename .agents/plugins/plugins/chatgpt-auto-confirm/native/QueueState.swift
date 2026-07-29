import ApplicationServices
import Cocoa
import Darwin
import Foundation
import SystemConfiguration

func queueDirectoryURL() -> URL {
  queueStateURL().deletingLastPathComponent().appendingPathComponent("task-queue", isDirectory: true)
}

let currentQueueRuntimeRevision = "mahayana.task-queue.v83"

func queueStateURL() -> URL {
  if let override = ProcessInfo.processInfo.environment["CHATGPT_AUTO_CONFIRM_QUEUE_STATE"],
     !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    return URL(fileURLWithPath: override)
  }
  return stateURL().deletingLastPathComponent().appendingPathComponent("queue-state.json")
}

func queueTraceURL() -> URL {
  queueDirectoryURL().appendingPathComponent("watcher-trace.log")
}

func queueTrace(_ message: String) {
  let url = queueTraceURL()
  try? FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  if !FileManager.default.fileExists(atPath: url.path) {
    _ = FileManager.default.createFile(atPath: url.path, contents: nil)
  }
  guard let handle = try? FileHandle(forWritingTo: url) else { return }
  defer { try? handle.close() }
  if ((try? handle.seekToEnd()) ?? 0) > 262_144 {
    try? handle.truncate(atOffset: 0)
    try? handle.seek(toOffset: 0)
  }
  let timestamp = isoFormatter.string(from: Date())
  handle.write(Data("[\(timestamp)] \(message)\n".utf8))
}

func queueTraceTail() -> [String] {
  guard let data = try? Data(contentsOf: queueTraceURL()),
        let text = String(data: data.suffix(16_384), encoding: .utf8) else { return [] }
  return Array(text.split(separator: "\n").suffix(40)).map(String.init)
}

func loadQueueState() -> PluginState {
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

func saveQueueState(_ state: PluginState) throws {
  try writePluginState(state, to: queueStateURL())
}

func withQueueStateLock<T>(
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

func writePluginState(_ state: PluginState, to url: URL) throws {
  try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try encoder.encode(state).write(to: url, options: .atomic)
}

func normalizedTaskId(_ rawValue: String?) -> String? {
  guard let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
        !value.isEmpty,
        value.range(
          of: "^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$",
          options: .regularExpression
        ) != nil else { return nil }
  return value
}

func normalizedConnector(_ rawValue: String?) -> String? {
  guard let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
        !value.isEmpty,
        value.count <= 256,
        !value.contains("\n"),
        !value.contains("\r") else { return nil }
  return value
}

struct QueueNetworkProbe {
  let reachable: Bool
  let detail: String
}

func queueNetworkProbe() -> QueueNetworkProbe {
  guard let reachability = SCNetworkReachabilityCreateWithName(nil, "api.github.com") else {
    return QueueNetworkProbe(
      reachable: true,
      detail: "无法创建 GitHub 路由预检；按实际请求结果判断网络状态"
    )
  }
  var flags = SCNetworkReachabilityFlags()
  guard SCNetworkReachabilityGetFlags(reachability, &flags) else {
    return QueueNetworkProbe(
      reachable: true,
      detail: "无法读取 GitHub 路由预检；按实际请求结果判断网络状态"
    )
  }
  let isReachable = flags.contains(.reachable)
  let needsConnection = flags.contains(.connectionRequired)
  let canConnectAutomatically = flags.contains(.connectionOnDemand)
    || flags.contains(.connectionOnTraffic)
  let online = isReachable && (!needsConnection || canConnectAutomatically)
  // SCNetworkReachability is deprecated on current macOS and can report
  // false negatives on ephemeral GitHub-hosted runners. A negative preflight
  // must not leave every task queued forever. Start the task and let the
  // existing networkRecoverySignal path handle an actual request failure.
  return QueueNetworkProbe(
    reachable: true,
    detail: online
      ? "GitHub 网络路由可达"
      : "GitHub 路由预检不确定（flags=\(flags.rawValue)）；按实际请求结果判断"
  )
}

func networkRecoverySignal(_ value: String) -> String? {
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

func queueNetworkRecovery(
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

func taskPromptPrefix(_ template: String) -> String {
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

func chatOnlyInstruction(_ value: String) -> String {
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

func automationTaskMessage(_ task: AutomationTask) -> String {
  var sections = [
    taskPromptPrefix(task.promptTemplate),
    "模型要求：执行复杂开发、发布、修复和验收任务时，优先选择 GPT-5.6 Sol 模型，并将推理强度设置为 High。不要自动降级到低推理模式；若模型选择失败，继续尝试选择目标模型后再开始工作。",
    "执行边界：实际工作只允许在 Chat 页面完成；不要点击或进入 Work 页面。",
    "连接器路由：当前新 Chat 选用「\(task.connector)」。已在云端 GitHub 的代码、仓库、PR、Actions、构件、发布和合并状态必须使用 GitHub 连接器；不要改用本地 gh 来替代云端证据。本地 checkout、Git/gh 元数据与安全同步必须使用 bhrum2；同步前先读取 status、远端和分支，只允许干净工作树上的 fast-forward，不得覆盖本地改动。若本轮从 bhrum2 推送到云端，最终报告 next_connector 填 GitHub，让小程序为下一新 Chat 切换到 GitHub 连接器。",
    "资源策略：项目的测试、构建、打包、安装、发布验证和安装包生成一律在 GitHub Actions 中执行并以 Actions 日志或构件为准。本机只做 Git/gh 元数据与代码阅读；不要在本机运行任何项目测试、构建、打包、安装、依赖下载或会生成缓存/产物的命令。",
    "提交策略：提交前逐项选择源代码、配置和必要文档，禁止 git add -A。不要提交或等待上传无关的大文件、缓存、node_modules、构建输出、本地安装包或无关 LFS 对象；除非某个大文件是任务明确必需的发布资产。",
    "持续执行规则：不要在说明『下一步要做什么』后停止，也不要只汇报阶段性进度。没有完成目标不要停，一直工作下去直到实现目标！直接执行所有可行步骤，持续处理失败、评审意见、Actions、部署和构件检查，直到原始目标真正完成。",
    "等待规则：对于 GitHub Actions、部署、发布审核、网络恢复或其他需要时间跑的异步操作，Chat 会话必须自己运行 bash `sleep` 睡眠命令（例如执行 `sleep 60`）。睡眠之后起来看是否完成，还没有完成就继续执行 sleep 睡眠等待直到有结果，然后立刻继续；绝对不要用回复等待秒数、预计时间或让用户稍后再来结束本轮。",
    "遇到重复卡点时不要只重复同一条失败命令：先诊断根因并尝试可行的替代路径（本机工具、备用命令、认证方式或连接方式）。只有出现当前权限与工具确实无法绕过的真实阻塞，或平台硬性终止本次会话时，才允许结束未完成任务，并在未完成续作模板中准确列出具体所需权限、账号、工具、环境变量、具体命令或外部恢复条件。",
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

func automationReviewMessage(
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

func startAutomationReview(
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
    expression: sendMessageJS(
      message: outbound,
      connector: task.connector,
      newChat: false,
      expectedConversationId: normalizedConversationId(prepared["conversationId"] as? String)
    ),
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

func dependencyCycle(in tasks: [AutomationTask]) -> [String]? {
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

func automationReport(_ raw: Any?) -> AutomationTaskReport? {
  guard let raw = raw as? [String: Any],
        JSONSerialization.isValidJSONObject(raw),
        let data = try? JSONSerialization.data(withJSONObject: raw),
        let report = try? decoder.decode(AutomationTaskReport.self, from: data),
        report.protocolName == "mahayana.task-report.v1",
        ["complete", "incomplete", "blocked"].contains(report.status) else { return nil }
  return report
}

func decodeLastJSONLine(at path: String?) -> (String, [String: Any])? {
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

func taskPublicPayload(_ task: AutomationTask, includeResult: Bool = false) -> [String: Any] {
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
    "watchdogLastRecoveryAt": task.watchdogLastRecoveryAt as Any,
    "watchdogRecoveryCount": task.watchdogRecoveryCount ?? 0,
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

func queueStatusPayload(_ state: PluginState) -> [String: Any] {
  let tasks = state.automationTasks ?? []
  let requestedMaxConcurrent = min(4, max(1, state.queueMaxConcurrent ?? 2))
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
  let activeWorkers = tasks.filter { $0.status == "running" }.map { task in
    let runtimeState: QueueTargetRuntimeState? = {
      guard let port = task.workerPort, let targetId = task.workerTargetId else { return nil }
      return queueTargetRuntimeState(port: port, targetId: targetId, refreshLifecycle: false)
    }()
    return [
      "taskId": task.id,
      "port": task.workerPort as Any,
      "targetId": task.workerTargetId as Any,
      "conversationId": task.conversationId as Any,
      "runtimeState": runtimeState.map(queueTargetRuntimeStateName) ?? "not-started",
      "visibilityVerified": runtimeState == .hidden,
    ] as [String: Any]
  }
  return [
    "ok": true,
    "enabled": state.queueEnabled == true,
    "paused": state.queuePaused == true,
    "running": state.queueEnabled == true && watcherIsAlive(state.queueWatcherPid),
    "watcherPid": state.queueWatcherPid as Any,
    "maxConcurrent": requestedMaxConcurrent,
    "effectiveMaxConcurrent": requestedMaxConcurrent,
    "requestedMaxConcurrent": requestedMaxConcurrent,
    "executionMode": "parallel-dedicated-hidden-chat-processes",
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
      "sharedProcess": queueUsesBackgroundWindow(state)
        && state.queueWorkerMode != parallelDedicatedProcessQueueWorkerMode,
      "sameApplicationProcess": queueUsesBackgroundWindow(state)
        && state.queueWorkerMode != parallelDedicatedProcessQueueWorkerMode,
      "isolatedFromVisiblePage": workerIsHidden,
      "visibilityVerified": workerIsHidden,
      "runtimeState": workerRuntimeState.map(queueTargetRuntimeStateName) ?? "not-started",
      "separateApplicationProcess":
        state.queueWorkerMode == parallelDedicatedProcessQueueWorkerMode,
    ],
    "activeWorkers": activeWorkers,
    "watcherTrace": queueTraceTail(),
    "reviewGate": state.queueReviewGate != false,
    "counts": counts,
    "tasks": tasks.map { taskPublicPayload($0) },
    "attention": attention.map { taskPublicPayload($0, includeResult: true) },
    "recoverable": true,
    "statePath": queueStateURL().path,
  ]
}

func startQueueWatcher(_ state: inout PluginState) throws {
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
