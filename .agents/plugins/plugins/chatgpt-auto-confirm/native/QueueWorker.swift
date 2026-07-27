import ApplicationServices
import Cocoa
import Darwin
import Foundation
import SystemConfiguration

let backgroundWindowQueueWorkerMode = "single-process-hidden-prewarm"
let sharedConversationQueueWorkerMode = "single-process-hidden-chat-conversations"
let legacyIsolatedQueueWorkerMode = "isolated-dedicated-process"

enum QueueTargetRuntimeState {
  case missing
  case hidden
  case hiddenNonChat
  case visible
  case suspended
}

func queueUsesBackgroundWindow(_ state: PluginState) -> Bool {
  state.queueWorkerMode == backgroundWindowQueueWorkerMode
    || state.queueWorkerMode == sharedConversationQueueWorkerMode
}

func queueTargetRuntimeState(
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

func queueTargetRuntimeStateName(_ state: QueueTargetRuntimeState) -> String {
  switch state {
  case .missing: return "missing"
  case .hidden: return "hidden-chat"
  case .hiddenNonChat: return "hidden-not-chat"
  case .visible: return "visible"
  case .suspended: return "suspended"
  }
}

func queueTargetIsHidden(port: Int, targetId: String) -> Bool {
  queueTargetRuntimeState(
    port: port,
    targetId: targetId,
    refreshLifecycle: false
  ) == .hidden
}

func generalApprovalStateForQueue() -> PluginState? {
  let url = queueStateURL().deletingLastPathComponent().appendingPathComponent("state.json")
  guard let data = try? Data(contentsOf: url) else { return nil }
  return try? decoder.decode(PluginState.self, from: data)
}

func sharedChatController(
  _ state: inout PluginState
) -> (port: Int, targetId: String, profilePath: String)? {
  let general = generalApprovalStateForQueue()
  let port = configuredHiddenChatPort()
    ?? general?.backgroundAppPort
    ?? state.backgroundAppPort
    ?? hiddenChatPort(state)
  let profilePath = general?.backgroundProfilePath
    ?? state.backgroundProfilePath
    ?? hiddenChatProfilePath()
  let preferredTargetIds = [
    general?.backgroundChatTargetId,
    state.backgroundChatTargetId,
  ].compactMap { $0 }
  // Hosted macOS runners invoke the queue only a few seconds after launching
  // ChatGPT. The preload bridge and entry module can be ready before React has
  // rendered five buttons, so wait for the actual prewarm prerequisites
  // instead of taking one button-count snapshot.
  for _ in 0..<120 {
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
        expression: """
        (() => ({
          bridge: !!window.electronBridge,
          ready: document.readyState,
          entryScripts: [...document.scripts].filter(script =>
            /\\/assets\\/index-[^/]+\\.js$/.test(script.src || '')
          ).length
        }))()
        """,
        timeout: 3.0
      )
      let bridge = (probe?["bridge"] as? NSNumber)?.boolValue ?? false
      let ready = probe?["ready"] as? String
      let entryScripts = (probe?["entryScripts"] as? NSNumber)?.intValue ?? 0
      guard bridge, ready == "complete", entryScripts > 0 else { continue }
      state.backgroundAppPort = port
      state.backgroundChatTargetId = targetId
      state.backgroundProfilePath = profilePath
      return (port, targetId, profilePath)
    }
    Thread.sleep(forTimeInterval: 0.25)
  }
  guard let prepared = ensureHiddenChatTarget(&state),
        prepared["ok"] as? Bool == true,
        let port = prepared["port"] as? Int,
        let targetId = prepared["targetId"] as? String else { return nil }
  return (port, targetId, prepared["profilePath"] as? String ?? hiddenChatProfilePath())
}

func quickChatPrewarmServiceJS(_ action: String) -> String {
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

func openBackgroundQueueWindow(
  port: Int,
  controllerTargetId: String,
  failure: inout String?
) -> String? {
  let existingTargetIds = Set(CDPClient.fetchTargets(portOverride: port).compactMap {
    $0["id"] as? String
  })
  guard existingTargetIds.contains(controllerTargetId) else {
    failure = "prewarm_controller_target_missing"
    return nil
  }
  let reset = cdpValue(
    port: port,
    targetId: controllerTargetId,
    expression: quickChatPrewarmServiceJS("reset-prewarm"),
    timeout: 8.0
  )
  guard reset?["ok"] as? Bool == true else {
    failure = "prewarm_reset_failed:\(reset?["error"] as? String ?? "no_result")"
    return nil
  }

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
  guard let targetId else {
    failure = "prewarm_target_not_created"
    return nil
  }

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
    failure = "prewarm_renderer_not_loaded"
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
    failure = "prewarm_renderer_ready_not_acknowledged"
    _ = CDPClient.closeTarget(targetId, portOverride: port)
    return nil
  }
  // Let the main process consume rendererReady before replacing the prewarm
  // route. Navigating immediately can leave the quick-chat shell unclaimed.
  Thread.sleep(forTimeInterval: 1.0)
  // The bare quick-chat route is intentionally only a prewarm shell:
  // QuickChatWindowPage reports rendererReady(null) and renders no body until
  // a client conversation id is present. Give the hidden window the same
  // client-generated UUID shape used by the official Quick Chat popover so it
  // mounts a usable new-conversation composer without ever showing the window.
  let conversationUUID = UUID().uuidString.lowercased()
  let conversationId = "local-chatgpt:\(conversationUUID)"
  let quickChatURL =
    "app://-/index.html?initialRoute=%2Fchatgpt%2Fquick-chat%2Flocal-chatgpt%3A\(conversationUUID)"
  guard
        let target = CDPClient.fetchTargets(portOverride: port).first(where: {
          $0["id"] as? String == targetId
        }),
        let wsURL = target["webSocketDebuggerUrl"] as? String,
        CDPClient.navigate(
          wsURLString: wsURL,
          url: quickChatURL
        ) else {
    failure = "prewarm_navigation_failed"
    _ = CDPClient.closeTarget(targetId, portOverride: port)
    return nil
  }
  // Electron deprioritizes show:false pages so aggressively that the Chat
  // surface may need over a minute to mount. Keep the actual BrowserWindow
  // hidden while asking Chromium to run this renderer at active lifecycle
  // priority. document.visibilityState remains hidden and is rechecked below.
  Thread.sleep(forTimeInterval: 0.5)
  guard wakeHiddenRenderer(port: port, targetId: targetId, wsURL: wsURL) else {
    failure = "prewarm_renderer_wake_failed"
    _ = CDPClient.closeTarget(targetId, portOverride: port)
    return nil
  }

  // A show:false renderer is intentionally deprioritized by Electron. On
  // current ChatGPT builds the full Chat surface can take more than 30 seconds
  // to mount even though its document and preload bridge are already ready.
  var lastReady: [String: Any]?
  for _ in 0..<600 {
    let ready = cdpValue(
      port: port,
      targetId: targetId,
      expression: "(() => ({bridge: !!window.electronBridge, ready: document.readyState, scripts: document.scripts.length, buttons: document.querySelectorAll('button').length, inputs: document.querySelectorAll('textarea, [contenteditable=\"true\"]').length, text: (document.body?.innerText || '').length, html: (document.body?.innerHTML || '').length, visibility: document.visibilityState, href: location.href}))()",
      timeout: 3.0
    )
    lastReady = ready
    let bridge = (ready?["bridge"] as? NSNumber)?.boolValue ?? false
    let buttons = (ready?["buttons"] as? NSNumber)?.intValue ?? 0
    let textLength = (ready?["text"] as? NSNumber)?.intValue ?? 0
    let visibility = ready?["visibility"] as? String
    let href = ready?["href"] as? String
    if bridge,
       buttons > 5,
       textLength > 100,
       visibility == "hidden",
       href?.hasPrefix("app://-/index.html") == true,
       href?.contains(conversationUUID) == true {
      return targetId
    }
    Thread.sleep(forTimeInterval: 0.1)
  }
  failure = [
    "prewarm_hidden_chat_surface_timeout",
    "bridge=\((lastReady?["bridge"] as? NSNumber)?.boolValue ?? false)",
    "ready=\(lastReady?["ready"] as? String ?? "none")",
    "scripts=\((lastReady?["scripts"] as? NSNumber)?.intValue ?? -1)",
    "buttons=\((lastReady?["buttons"] as? NSNumber)?.intValue ?? -1)",
    "inputs=\((lastReady?["inputs"] as? NSNumber)?.intValue ?? -1)",
    "text=\((lastReady?["text"] as? NSNumber)?.intValue ?? -1)",
    "html=\((lastReady?["html"] as? NSNumber)?.intValue ?? -1)",
    "visibility=\(lastReady?["visibility"] as? String ?? "none")",
    "routeMatches=\((lastReady?["href"] as? String ?? "").contains(conversationUUID))",
  ].joined(separator: ":")
  _ = CDPClient.closeTarget(targetId, portOverride: port)
  return nil
}

func createQueueWorkerTarget(
  _ state: inout PluginState
) -> (port: Int, targetId: String, profilePath: String)? {
  // Reuse the plugin-owned hidden Chat renderer. Model responses continue on
  // ChatGPT's service after the renderer moves to another conversation, so
  // several tasks can run concurrently while page dispatch and monitoring are
  // serialized through this one authenticated renderer.
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

  let general = generalApprovalStateForQueue()
  let port = configuredHiddenChatPort()
    ?? general?.backgroundAppPort
    ?? state.backgroundAppPort
    ?? hiddenChatPort(state)
  let profilePath = general?.backgroundProfilePath
    ?? state.backgroundProfilePath
    ?? hiddenChatProfilePath()
  let preferredTargetIds = [
    general?.backgroundChatTargetId,
    state.backgroundChatTargetId,
  ].compactMap { $0 }
  let targets = CDPClient.fetchTargets(portOverride: port).sorted { lhs, rhs in
    let lhsId = lhs["id"] as? String ?? ""
    let rhsId = rhs["id"] as? String ?? ""
    return (preferredTargetIds.firstIndex(of: lhsId) ?? Int.max)
      < (preferredTargetIds.firstIndex(of: rhsId) ?? Int.max)
  }
  for target in targets {
    guard target["type"] as? String == "page",
          (target["url"] as? String ?? "") == "app://-/index.html",
          let targetId = target["id"] as? String,
          queueTargetRuntimeState(
            port: port,
            targetId: targetId,
            refreshLifecycle: true
          ) == .hidden else { continue }
    let prepared = cdpValue(
      port: port,
      targetId: targetId,
      expression: prepareBackgroundChatJS(newChat: false),
      timeout: 5.0
    )
    guard prepared?["ok"] as? Bool == true else { continue }
    state.backgroundAppPort = port
    state.backgroundChatTargetId = targetId
    state.backgroundProfilePath = profilePath
    state.queueWorkerPort = port
    state.queueWorkerTargetId = targetId
    state.queueWorkerProfilePath = profilePath
    state.queueWorkerMode = sharedConversationQueueWorkerMode
    return (port, targetId, profilePath)
  }

  // A fresh hosted runner normally has only ChatGPT's visible primary window.
  // Ask that authenticated renderer's official quick-chat service to create
  // the show:false prewarm BrowserWindow, then turn it into the queue-owned
  // hidden Chat surface. Previously this implementation existed but was never
  // called, so the queue could only reuse a hidden target created elsewhere.
  var prewarmFailure: String?
  if let controller = sharedChatController(&state),
     let hiddenTargetId = openBackgroundQueueWindow(
       port: controller.port,
       controllerTargetId: controller.targetId,
       failure: &prewarmFailure
     ) {
    let chatSelection = cdpValue(
      port: controller.port,
      targetId: hiddenTargetId,
      expression: clickChatJS(),
      timeout: 4.0
    )
    var hiddenPrepared = false
    var lastHiddenPrepare: [String: Any]?
    for _ in 0..<80 {
      let prepared = cdpValue(
        port: controller.port,
        targetId: hiddenTargetId,
        expression: prepareBackgroundChatJS(newChat: false),
        timeout: 5.0
      )
      lastHiddenPrepare = prepared
      if prepared?["ok"] as? Bool == true,
         queueTargetRuntimeState(
           port: controller.port,
           targetId: hiddenTargetId,
           refreshLifecycle: true
         ) == .hidden {
        hiddenPrepared = true
        break
      }
      Thread.sleep(forTimeInterval: 0.25)
    }
    if hiddenPrepared {
      state.backgroundAppPort = controller.port
      state.backgroundChatTargetId = hiddenTargetId
      state.backgroundProfilePath = controller.profilePath
      state.queueWorkerPort = controller.port
      state.queueWorkerTargetId = hiddenTargetId
      state.queueWorkerProfilePath = controller.profilePath
      state.queueWorkerMode = sharedConversationQueueWorkerMode
      return (controller.port, hiddenTargetId, controller.profilePath)
    }
    _ = CDPClient.closeTarget(hiddenTargetId, portOverride: controller.port)
    let selectionError = chatSelection?["error"] as? String ?? "none"
    let prepareError = lastHiddenPrepare?["error"] as? String ?? "no_result"
    let workComposer = lastHiddenPrepare?["workComposer"] as? Bool ?? false
    let hasInput = lastHiddenPrepare?["hasInput"] as? Bool ?? false
    let chatModel = lastHiddenPrepare?["chatModel"] as? Bool ?? false
    prewarmFailure = [
      "prewarm_hidden_target_not_chat",
      "selection=\(selectionError)",
      "prepare=\(prepareError)",
      "hasInput=\(hasInput)",
      "chatModel=\(chatModel)",
      "workComposer=\(workComposer)",
    ].joined(separator: ":")
  }
  let prewarmCreationFailure = prewarmFailure ?? "prewarm_controller_unavailable"
  state.lastError = prewarmCreationFailure

  let fallback = ensureHiddenChatTarget(&state)
  guard let prepared = fallback,
        prepared["ok"] as? Bool == true,
        let preparedPort = prepared["port"] as? Int,
        let targetId = prepared["targetId"] as? String,
        queueTargetRuntimeState(
          port: preparedPort,
          targetId: targetId,
          refreshLifecycle: true
        ) == .hidden else {
    state.lastError = prewarmCreationFailure
    return nil
  }
  let preparedProfilePath = prepared["profilePath"] as? String ?? profilePath
  state.queueWorkerPort = preparedPort
  state.queueWorkerTargetId = targetId
  state.queueWorkerProfilePath = preparedProfilePath
  state.queueWorkerMode = sharedConversationQueueWorkerMode
  return (preparedPort, targetId, preparedProfilePath)
}

func createIndependentQueueWorkerTarget(
  _ state: inout PluginState
) -> (port: Int, targetId: String, profilePath: String)? {
  // Tasks own different conversation ids, not different Electron renderers.
  // The single hidden renderer dispatches and samples them in short turns.
  return createQueueWorkerTarget(&state)
}

func stopQueueWorker(_ state: inout PluginState) {
  // Close only the hidden queue window. The primary window and the shared
  // ChatGPT process remain available to the user and the general confirmer.
  if state.queueWorkerMode == backgroundWindowQueueWorkerMode {
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

func startAutomationTask(
  _ task: inout AutomationTask,
  state: inout PluginState
) throws {
  // Page actions are serialized through one hidden renderer, while each task
  // owns a distinct Chat conversation whose response runs independently.
  var prepared: [String: Any]?
  var port: Int?
  var targetId: String?
  var workerProfilePath: String?
  guard let worker = createIndependentQueueWorkerTarget(&state) else {
    let detail = state.lastError ?? "unknown"
    throw NSError(
      domain: "chatgpt-auto-confirm",
      code: 33,
      userInfo: [
        NSLocalizedDescriptionKey: "当前 ChatGPT 实例没有可用的隐藏 Chat 页面（\(detail)）"
      ]
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
    expression: sendMessageJS(
      message: outbound,
      connector: task.connector,
      newChat: false,
      expectedConversationId: normalizedConversationId(prepared["conversationId"] as? String)
    ),
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

func terminateDedicatedChatProcess(profilePath: String) {
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

func stopAutomationWorker(_ task: AutomationTask, state: PluginState) {
  if let statePath = task.workerStatePath,
     let data = FileManager.default.contents(atPath: statePath),
     let workerState = try? decoder.decode(PluginState.self, from: data),
     watcherIsAlive(workerState.watcherPid),
     let pid = workerState.watcherPid {
    kill(pid, SIGTERM)
  }
  if state.queueWorkerMode != sharedConversationQueueWorkerMode,
     let targetId = task.workerTargetId {
    _ = CDPClient.closeTarget(targetId, portOverride: task.workerPort)
  }
  if let profilePath = task.workerProfilePath {
    terminateDedicatedChatProcess(profilePath: profilePath)
  }
}

func closeDedicatedAutomationTarget(
  _ task: AutomationTask,
  state: PluginState
) {
  // Multi-conversation tasks share the plugin-owned hidden renderer. A task
  // may stop or replace only its conversation binding, never that renderer.
  if state.queueWorkerMode != sharedConversationQueueWorkerMode,
     let targetId = task.workerTargetId {
    _ = CDPClient.closeTarget(targetId, portOverride: task.workerPort)
  }
}

func finishAutomationTask(_ task: inout AutomationTask, state: PluginState) {
  let now = isoFormatter.string(from: Date())
  defer {
    stopAutomationWorker(task, state: state)
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
