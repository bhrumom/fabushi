import ApplicationServices
import Cocoa
import Darwin
import Foundation
import SystemConfiguration

let backgroundWindowQueueWorkerMode = "single-process-hidden-prewarm"
let sharedConversationQueueWorkerMode = "single-process-hidden-chat-conversations"
let parallelHiddenWindowQueueWorkerMode = "single-process-hidden-chat-windows"
let parallelDedicatedProcessQueueWorkerMode = "parallel-dedicated-hidden-chat-processes"
let legacyIsolatedQueueWorkerMode = "isolated-dedicated-process"
// Electron stays alive after its executable is launched. Keep the launcher
// objects alive for the lifetime of each dedicated worker; otherwise releasing
// `Process` can tear down the child before its CDP endpoint is ready.
var dedicatedQueueChatLaunchers: [Int: Process] = [:]

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
    || state.queueWorkerMode == parallelHiddenWindowQueueWorkerMode
    || state.queueWorkerMode == parallelDedicatedProcessQueueWorkerMode
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
    const quickChatRoot = document.querySelector(
      '[data-pip-obstacle="quick-chat"], [data-quick-chat-drag-handle]'
    )?.closest('[role="dialog"], section, div');
    const textarea = quickChatRoot?.querySelector(
      '#prompt-textarea, [contenteditable="true"]'
    ) || document.querySelector('#prompt-textarea')
      || document.querySelector('[contenteditable="true"]');
    // Quick Chat is rendered above the existing Work page. The Work composer
    // remains mounted behind the overlay and must not disqualify the active
    // Quick Chat surface.
    const currentChatGPTMode = !!window.__mahayanaConfirmedChatGPTMode;
    const workComposer = !quickChatRoot
      && !!document.querySelector('[data-codex-composer="true"]');
    const chatModel = [...document.querySelectorAll('button')].some(button => {
      const label = button.getAttribute('aria-label') || '';
      return label.includes('ChatGPT 模型') || /select chatgpt model/i.test(label);
    });
    const chatMode = (!!quickChatRoot || chatModel || currentChatGPTMode)
      && !!textarea && !workComposer;
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
  if bridge && visibility == "hidden"
      && href.hasPrefix("app://-/index.html")
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

func queueTargetIsReady(port: Int, targetId: String) -> Bool {
  switch queueTargetRuntimeState(port: port, targetId: targetId, refreshLifecycle: true) {
  case .hidden, .visible:
    return true
  case .missing, .hiddenNonChat, .suspended:
    return false
  }
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
  let profilePath = configuredHiddenChatProfilePath()
    ?? general?.backgroundProfilePath
    ?? state.backgroundProfilePath
    ?? hiddenChatProfilePath()
  let preferredTargetIds = [
    general?.backgroundChatTargetId,
    state.backgroundChatTargetId,
  ].compactMap { $0 }
  let queueOwnedTargetIds = Set(
    (state.automationTasks ?? []).compactMap(\.workerTargetId)
      + [state.queueWorkerTargetId].compactMap { $0 }
  )
  queueTrace("worker-create stage=controller-discovery begin port=\(port)")
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
            !queueOwnedTargetIds.contains(targetId) else { continue }
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
      queueTrace("worker-create stage=controller-discovery complete target=\(targetId)")
      return (port, targetId, profilePath)
    }
    Thread.sleep(forTimeInterval: 0.25)
  }
  guard let prepared = ensureHiddenChatTarget(&state),
        prepared["ok"] as? Bool == true,
        let port = prepared["port"] as? Int,
        let targetId = prepared["targetId"] as? String else { return nil }
  queueTrace("worker-create stage=controller-fallback complete target=\(targetId)")
  return (
    port,
    targetId,
    prepared["profilePath"] as? String
      ?? configuredHiddenChatProfilePath()
      ?? hiddenChatProfilePath()
  )
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

func continueHiddenOnboardingJS() -> String {
  #"""
  (() => {
    const normalize = value => (value || '').replace(/\s+/g, ' ').trim().toLowerCase();
    const preferred = [
      'continue', '继续', 'next', '下一步', 'done', '完成',
      'go to chatgpt', '前往 chatgpt', '进入 chatgpt',
      'skip', '跳过'
    ];
    const nodes = [...document.querySelectorAll('button, a, [role="button"]')];
    const labelsFor = node => [
        node.innerText,
        node.textContent,
        node.getAttribute('aria-label'),
        node.getAttribute('title')
      ].map(normalize).filter(Boolean);
    const button = preferred
      .map(label => nodes.find(node => labelsFor(node).includes(label)))
      .find(Boolean);
    if (!button) return {ok: true, clicked: false};
    const label = normalize(
      button.innerText || button.getAttribute('aria-label') || button.getAttribute('title')
    );
    button.click();
    return {ok: true, clicked: true, label};
  })()
  """#
}

func openBackgroundQueueWindow(
  port: Int,
  controllerTargetId: String,
  failure: inout String?
) -> String? {
  queueTrace("worker-create stage=prewarm-open begin controller=\(controllerTargetId)")
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
    failure = "desktop_prewarm_reset_failed:\(reset?["error"] as? String ?? "no_result")"
    return nil
  }
  queueTrace("worker-create stage=prewarm-reset complete")

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
  queueTrace("worker-create stage=prewarm-target complete target=\(targetId)")

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
  queueTrace("worker-create stage=prewarm-renderer-loaded")
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
  queueTrace("worker-create stage=prewarm-renderer-acknowledged")
  // Let the main process consume rendererReady before replacing the prewarm
  // route. Navigating immediately can leave the quick-chat shell unclaimed.
  Thread.sleep(forTimeInterval: 1.0)
  // Quick Chat itself is feature-gated per account. The official prewarm
  // service is still the supported way to obtain a show:false BrowserWindow,
  // but hosted accounts without that gate must mount the normal authenticated
  // app root in the same hidden window before selecting Chat.
  let hiddenAppURL = "app://-/index.html?initialRoute=%2F"
  guard
        let target = CDPClient.fetchTargets(portOverride: port).first(where: {
          $0["id"] as? String == targetId
        }),
        let wsURL = target["webSocketDebuggerUrl"] as? String,
        CDPClient.navigate(
          wsURLString: wsURL,
          url: hiddenAppURL
        ) else {
    failure = "prewarm_navigation_failed"
    _ = CDPClient.closeTarget(targetId, portOverride: port)
    return nil
  }
  queueTrace("worker-create stage=prewarm-navigation complete target=\(targetId)")
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
  queueTrace("worker-create stage=prewarm-renderer-awake")

  // A show:false renderer is intentionally deprioritized by Electron. On
  // current ChatGPT builds the full Chat surface can take more than 30 seconds
  // to mount even though its document and preload bridge are already ready.
  var lastReady: [String: Any]?
  for _ in 0..<600 {
    let ready = cdpValue(
      port: port,
      targetId: targetId,
      expression: """
      (() => {
        const redact = value => (value || '')
          .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}/gi, '[email]')
          .replace(/[0-9a-f]{8}-[0-9a-f-]{27,}/gi, '[id]')
          .replace(/\\s+/g, ' ')
          .trim();
        const buttonLabels = [...document.querySelectorAll('button, a, [role="button"]')]
          .flatMap(node => [
            node.innerText,
            node.getAttribute('aria-label'),
            node.getAttribute('title')
          ])
          .map(redact)
          .filter(Boolean)
          .slice(0, 12);
        return {
          bridge: !!window.electronBridge,
          ready: document.readyState,
          scripts: document.scripts.length,
          buttons: document.querySelectorAll('button').length,
          buttonLabels,
          inputs: document.querySelectorAll('textarea, [contenteditable="true"]').length,
          text: (document.body?.innerText || '').length,
          safeText: redact(document.body?.innerText).slice(0, 800),
          html: (document.body?.innerHTML || '').length,
          visibility: document.visibilityState,
          href: location.href
        };
      })()
      """,
      timeout: 3.0
    )
    lastReady = ready
    let bridge = (ready?["bridge"] as? NSNumber)?.boolValue ?? false
    let buttons = (ready?["buttons"] as? NSNumber)?.intValue ?? 0
    let textLength = (ready?["text"] as? NSNumber)?.intValue ?? 0
    let visibility = ready?["visibility"] as? String
    let href = ready?["href"] as? String
    if bridge,
       buttons >= 1,
       textLength > 100,
       visibility == "hidden",
       href?.hasPrefix("app://-/index.html") == true,
       href?.contains("initialRoute=%2F") == true {
      queueTrace("worker-create stage=hidden-shell-ready target=\(targetId)")
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
    "routeMatches=\((lastReady?["href"] as? String ?? "").contains("initialRoute=%2F"))",
    "labels=\((lastReady?["buttonLabels"] as? [String] ?? []).joined(separator: "|"))",
    "safeText=\(lastReady?["safeText"] as? String ?? "none")",
  ].joined(separator: ":")
  _ = CDPClient.closeTarget(targetId, portOverride: port)
  return nil
}

func selectChatOnPrimaryController(
  port: Int,
  targetId: String
) -> [String: Any]? {
  var selection: [String: Any]?
  let forced = cdpValue(
    port: port,
    targetId: targetId,
    expression: forcePrimaryChatModeJS(),
    timeout: 5.0
  )
  queueTrace(
    "worker-create stage=primary-chat-selection force-persisted-mode "
      + "ok=\(forced?["ok"] as? Bool ?? false) "
      + "error=\(forced?["error"] as? String ?? "none")"
  )
  Thread.sleep(forTimeInterval: 1.2)
  _ = resetStaleChatModeIfNeeded(
    port: port,
    targetId: targetId,
    stage: "primary-chat-selection"
  )
  for _ in 0..<20 {
    selection = cdpValue(
      port: port,
      targetId: targetId,
      expression: clickChatJS(),
      timeout: 4.0
    )
    if selection?["alreadySelected"] as? Bool == true { return selection }
    if selection?["retryAfterModeSwitch"] as? Bool == true {
      Thread.sleep(forTimeInterval: 0.8)
      continue
    }
    if selection?["dispatchOnly"] as? Bool == true {
      // The primary Chat/Work control is a React text toggle. Its click can
      // replace the renderer after Runtime.evaluate returns, so re-probe the
      // same target instead of trusting the dispatch result.
      Thread.sleep(forTimeInterval: 0.8)
      continue
    }
    Thread.sleep(forTimeInterval: 0.35)
  }
  return selection
}

@discardableResult
func resetStaleChatModeIfNeeded(
  port: Int,
  targetId: String,
  stage: String
) -> [String: Any]? {
  let initial = cdpValue(
    port: port,
    targetId: targetId,
    expression: composerSurfaceStateJS(),
    timeout: 5.0
  )
  guard initial?["workComposer"] as? Bool == true else { return initial }

  // The hosted shell can persist "chat" while the mounted composer is still
  // Work. Re-selecting ChatGPT is then a no-op because the atom already has
  // that value. Use the real compact mode menu to cross the state boundary
  // through Codex once, then return to Chat before creating the hidden window.
  queueTrace("worker-create stage=\(stage) reset-stale-mode begin")
  var codexSelection: [String: Any]?
  for _ in 0..<12 {
    codexSelection = cdpValue(
      port: port,
      targetId: targetId,
      expression: clickCodexModeJS(),
      timeout: 5.0
    )
    if codexSelection?["dispatchOnly"] as? Bool == true { break }
    if codexSelection?["retryAfterModeSwitch"] as? Bool == true {
      Thread.sleep(forTimeInterval: 0.6)
      continue
    }
    Thread.sleep(forTimeInterval: 0.35)
  }
  queueTrace(
    "worker-create stage=\(stage) reset-stale-mode codex "
      + "ok=\(codexSelection?["ok"] as? Bool ?? false) "
      + "selectedLabel=\(codexSelection?["selectedLabel"] as? String ?? "none") "
      + "error=\(codexSelection?["error"] as? String ?? "none")"
  )
  guard codexSelection?["dispatchOnly"] as? Bool == true else { return initial }
  Thread.sleep(forTimeInterval: 1.2)

  var chatSelection: [String: Any]?
  for _ in 0..<20 {
    chatSelection = cdpValue(
      port: port,
      targetId: targetId,
      expression: clickChatJS(),
      timeout: 5.0
    )
    if chatSelection?["alreadySelected"] as? Bool == true { break }
    if chatSelection?["retryAfterModeSwitch"] as? Bool == true
        || chatSelection?["dispatchOnly"] as? Bool == true {
      Thread.sleep(forTimeInterval: 0.8)
      continue
    }
    Thread.sleep(forTimeInterval: 0.35)
  }
  queueTrace(
    "worker-create stage=\(stage) reset-stale-mode chat "
      + "ok=\(chatSelection?["ok"] as? Bool ?? false) "
      + "alreadySelected=\(chatSelection?["alreadySelected"] as? Bool ?? false) "
      + "selectedLabel=\(chatSelection?["selectedLabel"] as? String ?? "none") "
      + "error=\(chatSelection?["error"] as? String ?? "none")"
  )
  return cdpValue(
    port: port,
    targetId: targetId,
    expression: composerSurfaceStateJS(),
    timeout: 5.0
  )
}

func dedicatedQueueWorkerPort() -> Int? {
  for port in 9330..<9380 where CDPClient.fetchTargets(portOverride: port).isEmpty {
    return port
  }
  return nil
}

func copyProfileForDedicatedQueueWorker(
  source: String,
  destination: String
) -> Bool {
  do {
    try FileManager.default.createDirectory(
      atPath: destination,
      withIntermediateDirectories: true
    )
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/rsync")
    process.arguments = [
      "-a",
      "--exclude=Singleton*",
      "--exclude=Lockfile",
      "--exclude=lockfile",
      "--exclude=DevToolsActivePort",
      source.hasSuffix("/") ? source : source + "/",
      destination.hasSuffix("/") ? destination : destination + "/",
    ]
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus == 0
  } catch {
    return false
  }
}

func launchDedicatedQueueChatProcess(profilePath: String, port: Int) -> Bool {
  do {
    let existingApplicationPids = Set(
      NSWorkspace.shared.runningApplications.compactMap { application -> pid_t? in
        guard let bundleIdentifier = application.bundleIdentifier,
              targetBundleIdentifiers.contains(bundleIdentifier) else { return nil }
        return application.processIdentifier
      }
    )
    func hideNewDedicatedApplication(
      preferredProcessId: pid_t?,
      attempts: Int
    ) -> Bool {
      for _ in 0..<attempts {
        let application = NSWorkspace.shared.runningApplications.first { candidate in
          guard !candidate.isTerminated else { return false }
          if candidate.processIdentifier == preferredProcessId { return true }
          guard let bundleIdentifier = candidate.bundleIdentifier else { return false }
          return targetBundleIdentifiers.contains(bundleIdentifier)
            && !existingApplicationPids.contains(candidate.processIdentifier)
        }
        if let application {
          _ = application.hide()
          for _ in 0..<80 {
            if application.isHidden {
              queueTrace(
                "worker-create stage=dedicated-process-hidden "
                  + "port=\(port) pid=\(application.processIdentifier)"
              )
              return true
            }
            Thread.sleep(forTimeInterval: 0.05)
          }
        }
        Thread.sleep(forTimeInterval: 0.05)
      }
      return false
    }
    let launcher = Process()
    // Launch the Electron executable directly. LaunchServices can coalesce
    // `open -n` requests into the visible controller process on hosted macOS,
    // which leaves the dedicated CDP port empty forever.
    launcher.executableURL = URL(
      fileURLWithPath: "/Applications/ChatGPT.app/Contents/MacOS/ChatGPT"
    )
    launcher.arguments = [
      "--user-data-dir=\(profilePath)",
      "--remote-debugging-port=\(port)",
    ]
    launcher.standardInput = FileHandle.nullDevice
    launcher.standardOutput = FileHandle.nullDevice
    launcher.standardError = FileHandle.nullDevice
    try launcher.run()
    dedicatedQueueChatLaunchers[port] = launcher
    // Do not wait for Electron to exit: it is the long-lived worker process.
    // Waiting here blocked the queue scheduler until the smoke action timed out.
    Thread.sleep(forTimeInterval: 0.25)
    if !launcher.isRunning && launcher.terminationStatus != 0 {
      dedicatedQueueChatLaunchers.removeValue(forKey: port)
      return false
    }
    let launchedProcessId = launcher.processIdentifier

    // Direct Electron launch creates a dedicated instance, but the renderer
    // still reports `document.visibilityState == visible` until it is hidden.
    // Hide the newly created application process explicitly. This is the same
    // transition used by the successful local hidden-Chat probe: the full
    // Chat renderer stays mounted while its visibility changes to `hidden`.
    // Hosted runners can take substantially longer than a local launch to
    // register a fresh Electron application with LaunchServices. Prefer the
    // exact process we launched even before its bundle metadata is available.
    if hideNewDedicatedApplication(preferredProcessId: launchedProcessId, attempts: 1_200) {
      return true
    }

    // On some hosted macOS images the direct Electron executable becomes a
    // short-lived launcher and never registers an NSRunningApplication. Use
    // LaunchServices only as a bounded fallback, retaining the isolated
    // profile and CDP port; subsequent code still requires a hidden Chat page.
    queueTrace("worker-create stage=dedicated-process-launchservices-fallback begin port=\(port)")
    let fallbackLauncher = Process()
    fallbackLauncher.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    fallbackLauncher.arguments = [
      // `-g -j` keeps the new app out of the foreground while `-n` forces a
      // separate instance. This is the same LaunchServices path used by the
      // background worker and avoids the hosted runner coalescing the launch
      // into the already-visible controller instance.
      "-g", "-j", "-n", "-a", "/Applications/ChatGPT.app", "--args",
      "--user-data-dir=\(profilePath)",
      "--remote-debugging-port=\(port)",
    ]
    fallbackLauncher.standardInput = FileHandle.nullDevice
    fallbackLauncher.standardOutput = FileHandle.nullDevice
    fallbackLauncher.standardError = FileHandle.nullDevice
    try fallbackLauncher.run()
    dedicatedQueueChatLaunchers[port] = fallbackLauncher
    // `open` is only a short-lived LaunchServices request; wait for that
    // request to be accepted before polling for the registered app and its
    // hidden renderer. Never wait on the ChatGPT process itself.
    fallbackLauncher.waitUntilExit()
    queueTrace(
      "worker-create stage=dedicated-process-launchservices-fallback complete "
        + "port=\(port) status=\(fallbackLauncher.terminationStatus)"
    )
    return hideNewDedicatedApplication(preferredProcessId: nil, attempts: 400)
  } catch {
    return false
  }
}

func dedicatedQueueChatTarget(port: Int) -> String? {
  for _ in 0..<240 {
    let targets = CDPClient.fetchTargets(portOverride: port)
    for target in targets {
      guard target["type"] as? String == "page",
            (target["url"] as? String ?? "").hasPrefix("app://-/index.html"),
            let targetId = target["id"] as? String else { continue }
      let loaded = cdpValue(
        port: port,
        targetId: targetId,
        expression: """
        (() => ({
          bridge: !!window.electronBridge,
          ready: document.readyState,
          buttons: document.querySelectorAll('button').length,
          text: (document.body?.innerText || '').length,
          visibility: document.visibilityState,
          href: location.href
        }))()
        """,
        timeout: 3.0
      )
      let bridge = (loaded?["bridge"] as? NSNumber)?.boolValue ?? false
      let ready = loaded?["ready"] as? String
      let textLength = (loaded?["text"] as? NSNumber)?.intValue ?? 0
      let visibility = loaded?["visibility"] as? String
      if bridge, ready == "complete", textLength > 100, visibility == "hidden" {
        return targetId
      }
    }
    Thread.sleep(forTimeInterval: 0.25)
  }
  return nil
}

func createDedicatedParallelQueueWorkerTarget(
  _ state: inout PluginState
) -> (port: Int, targetId: String, profilePath: String)? {
  let general = generalApprovalStateForQueue()
  let sourceProfile = configuredHiddenChatProfilePath()
    ?? general?.backgroundProfilePath
    ?? state.backgroundProfilePath
    ?? hiddenChatProfilePath()
  guard FileManager.default.fileExists(atPath: sourceProfile) else {
    state.lastError = "dedicated_source_profile_missing"
    return nil
  }
  guard let port = dedicatedQueueWorkerPort() else {
    state.lastError = "dedicated_worker_port_unavailable"
    return nil
  }
  let profilePath = queueDirectoryURL()
    .appendingPathComponent("workers", isDirectory: true)
    .appendingPathComponent(UUID().uuidString.lowercased(), isDirectory: true)
    .path
  queueTrace("worker-create stage=dedicated-profile-copy begin port=\(port)")
  guard copyProfileForDedicatedQueueWorker(
    source: sourceProfile,
    destination: profilePath
  ) else {
    state.lastError = "dedicated_profile_copy_failed"
    terminateDedicatedChatProcess(profilePath: profilePath)
    return nil
  }
  queueTrace("worker-create stage=dedicated-process-launch begin port=\(port)")
  guard launchDedicatedQueueChatProcess(profilePath: profilePath, port: port),
        let targetId = dedicatedQueueChatTarget(port: port) else {
    state.lastError = "dedicated_hidden_chat_process_not_ready"
    terminateDedicatedChatProcess(profilePath: profilePath)
    return nil
  }
  queueTrace(
    "worker-create stage=dedicated-process-launch complete port=\(port) target=\(targetId)"
  )
  let selection = selectChatOnPrimaryController(port: port, targetId: targetId)
  var prepared: [String: Any]?
  for _ in 0..<80 {
    prepared = cdpValue(
      port: port,
      targetId: targetId,
      expression: prepareBackgroundChatJS(
        newChat: false,
        confirmedChatMode: selection?["alreadySelected"] as? Bool == true
      ),
      timeout: 5.0
    )
    let runtimeState = queueTargetRuntimeState(
      port: port,
      targetId: targetId,
      refreshLifecycle: true
    )
    if prepared?["ok"] as? Bool == true, runtimeState == .hidden {
      state.queueWorkerPort = port
      state.queueWorkerTargetId = targetId
      state.queueWorkerProfilePath = profilePath
      state.queueWorkerMode = parallelDedicatedProcessQueueWorkerMode
      state.lastError = nil
      queueTrace(
        "worker-create stage=dedicated-chat-ready port=\(port) target=\(targetId)"
      )
      return (port, targetId, profilePath)
    }
    _ = cdpValue(
      port: port,
      targetId: targetId,
      expression: clickChatJS(),
      timeout: 4.0
    )
    Thread.sleep(forTimeInterval: 0.25)
  }
  let prepareError = prepared?["error"] as? String ?? "no_result"
  state.lastError = "dedicated_hidden_target_not_chat:\(prepareError)"
  _ = captureHiddenChatScreenshot(
    port: port,
    targetId: targetId,
    label: "dedicated-not-chat"
  )
  terminateDedicatedChatProcess(profilePath: profilePath)
  return nil
}

func createQueueWorkerTarget(
  _ state: inout PluginState,
  reuseExisting: Bool = true
) -> (port: Int, targetId: String, profilePath: String)? {
  // A compatibility caller may reuse the plugin-owned hidden Chat renderer.
  // Parallel task dispatch always passes reuseExisting=false so every running
  // task owns a different hidden BrowserWindow and never has to navigate away
  // from another task while that Chat is streaming.
  if reuseExisting,
     let port = state.queueWorkerPort,
     let targetId = state.queueWorkerTargetId,
     queueUsesBackgroundWindow(state),
     queueTargetIsHidden(port: port, targetId: targetId) {
    return (port, targetId, state.queueWorkerProfilePath ?? "")
  }
  if reuseExisting {
    if state.queueWorkerMode == legacyIsolatedQueueWorkerMode,
       let profilePath = state.queueWorkerProfilePath {
      terminateDedicatedChatProcess(profilePath: profilePath)
    }
    state.queueWorkerPort = nil
    state.queueWorkerTargetId = nil
    state.queueWorkerProfilePath = nil
    state.queueWorkerMode = nil
  }

  let general = generalApprovalStateForQueue()
  let port = configuredHiddenChatPort()
    ?? general?.backgroundAppPort
    ?? state.backgroundAppPort
    ?? hiddenChatPort(state)
  let profilePath = configuredHiddenChatProfilePath()
    ?? general?.backgroundProfilePath
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
  queueTrace(
    "worker-create stage=reuse-scan enabled=\(reuseExisting) targets=\(targets.count)"
  )
  for target in reuseExisting ? targets : [] {
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

  // A fresh runner normally has only ChatGPT's visible primary window.
  // Ask that authenticated renderer's official quick-chat service to create
  // the show:false prewarm BrowserWindow, then turn it into the queue-owned
  // hidden Chat surface. Previously this implementation existed but was never
  // called, so the queue could only reuse a hidden target created elsewhere.
  var prewarmFailure: String?
  queueTrace("worker-create stage=new-hidden-window begin")
  if let controller = sharedChatController(&state),
     let controllerSelection = selectChatOnPrimaryController(
       port: controller.port,
       targetId: controller.targetId
     ) {
    queueTrace(
      "worker-create stage=primary-chat-selection complete "
        + "alreadySelected=\(controllerSelection["alreadySelected"] as? Bool ?? false) "
        + "selectedLabel=\(controllerSelection["selectedLabel"] as? String ?? "none")"
    )
  }
  if let controller = sharedChatController(&state),
     let hiddenTargetId = openBackgroundQueueWindow(
       port: controller.port,
       controllerTargetId: controller.targetId,
       failure: &prewarmFailure
     ) {
    queueTrace("worker-create stage=new-hidden-window complete target=\(hiddenTargetId)")
    _ = resetStaleChatModeIfNeeded(
      port: controller.port,
      targetId: hiddenTargetId,
      stage: "hidden-chat-selection"
    )
    // A fresh hosted runner can restore authentication before completing the
    // desktop app's informational onboarding. Advance only neutral navigation
    // buttons, then select Chat once the real app shell is available.
    var chatSelection: [String: Any]?
    for _ in 0..<12 {
      queueTrace("worker-create stage=chat-selection attempt")
      chatSelection = cdpValue(
        port: controller.port,
        targetId: hiddenTargetId,
        expression: clickChatJS(),
        timeout: 4.0
      )
      if chatSelection?["ok"] as? Bool == true { break }
      if chatSelection?["retryAfterModeSwitch"] as? Bool == true {
        Thread.sleep(forTimeInterval: 0.8)
        continue
      }
      let onboarding = cdpValue(
        port: controller.port,
        targetId: hiddenTargetId,
        expression: continueHiddenOnboardingJS(),
        timeout: 4.0
      )
      guard onboarding?["clicked"] as? Bool == true else { break }
      Thread.sleep(forTimeInterval: 0.8)
    }
    queueTrace(
      "worker-create stage=chat-selection complete ok=\(chatSelection?["ok"] as? Bool ?? false)"
    )
    var workerPrepared = false
    var lastHiddenPrepare: [String: Any]?
    for _ in 0..<80 {
      queueTrace("worker-create stage=chat-prepare attempt")
      let prepared = cdpValue(
        port: controller.port,
        targetId: hiddenTargetId,
        expression: prepareBackgroundChatJS(
          newChat: false,
          // clickChatJS returns dispatchOnly before the top Chat/Work switch
          // has actually changed. Only an already-selected Chat state may be
          // carried across a renderer replacement.
          confirmedChatMode: chatSelection?["alreadySelected"] as? Bool == true
        ),
        timeout: 5.0
      )
      lastHiddenPrepare = prepared
      if prepared?["error"] as? String == "not_chat_surface" {
        // A dispatch-only Chat click can replace the renderer asynchronously.
        // Retry against the fresh top-level Chat/Work switch until the new
        // renderer proves it is actually Chat; never accept the stale Work
        // composer just because the previous page set a transient flag.
        let retrySelection = cdpValue(
          port: controller.port,
          targetId: hiddenTargetId,
          expression: clickChatJS(),
          timeout: 4.0
        )
        if retrySelection?["alreadySelected"] as? Bool == true {
          chatSelection = retrySelection
        }
      }
      let state = queueTargetRuntimeState(
        port: controller.port,
        targetId: hiddenTargetId,
        refreshLifecycle: true
      )
      queueTrace("worker-create stage=chat-prepare state=\(queueTargetRuntimeStateName(state))")
      if prepared?["ok"] as? Bool == true,
         (state == .hidden || state == .visible) {
        workerPrepared = true
        queueTrace("worker-create stage=chat-prepare complete")
        break
      }
      Thread.sleep(forTimeInterval: 0.25)
    }
    if workerPrepared {
      state.backgroundAppPort = controller.port
      state.backgroundChatTargetId = hiddenTargetId
      state.backgroundProfilePath = controller.profilePath
      state.queueWorkerPort = controller.port
      state.queueWorkerTargetId = hiddenTargetId
      state.queueWorkerProfilePath = controller.profilePath
      state.queueWorkerMode = sharedConversationQueueWorkerMode
      return (controller.port, hiddenTargetId, controller.profilePath)
    }
    let surfaceDiagnostic = cdpValue(
      port: controller.port,
      targetId: hiddenTargetId,
      expression: pageDiagnosticJS(),
      timeout: 5.0
    )
    let diagnosticButtons = (surfaceDiagnostic?["buttons"] as? [String] ?? [])
      .joined(separator: "|")
    let diagnosticModes = (surfaceDiagnostic?["modeNodes"] as? [[String: Any]] ?? [])
      .map { node in
        let text = node["text"] as? String ?? ""
        let tag = node["tag"] as? String ?? ""
        let role = node["role"] as? String ?? ""
        let selected = node["ariaSelected"] as? String ?? ""
        let pressed = node["ariaPressed"] as? String ?? ""
        let className = node["className"] as? String ?? ""
        return "\(text)@\(tag)#\(role)[selected=\(selected),pressed=\(pressed)]{\(className)}"
      }
      .joined(separator: "|")
    let diagnosticURL = surfaceDiagnostic?["url"] as? String ?? "none"
    let diagnosticScreenshot = captureHiddenChatScreenshot(
      port: controller.port,
      targetId: hiddenTargetId,
      label: "prewarm-not-chat"
    ) ?? captureHiddenChatScreenshot(
      port: controller.port,
      targetId: controller.targetId,
      label: "primary-not-chat"
    ) ?? "none"
    queueTrace(
      "worker-create stage=chat-prepare diagnostics url=\(diagnosticURL) "
        + "buttons=\(diagnosticButtons) modes=\(diagnosticModes) "
        + "screenshot=\(diagnosticScreenshot)"
    )
    _ = CDPClient.closeTarget(hiddenTargetId, portOverride: controller.port)
    let selectionError = chatSelection?["error"] as? String ?? "none"
    let selectionLabels = (chatSelection?["candidateLabels"] as? [String] ?? [])
      .joined(separator: "|")
    let prepareError = lastHiddenPrepare?["error"] as? String ?? "no_result"
    let workComposer = lastHiddenPrepare?["workComposer"] as? Bool ?? false
    let hasInput = lastHiddenPrepare?["hasInput"] as? Bool ?? false
    let chatModel = lastHiddenPrepare?["chatModel"] as? Bool ?? false
    prewarmFailure = [
      "prewarm_hidden_target_not_chat",
      "selection=\(selectionError)",
      "selectionLabels=\(selectionLabels)",
      "prepare=\(prepareError)",
      "hasInput=\(hasInput)",
      "chatModel=\(chatModel)",
      "workComposer=\(workComposer)",
    ].joined(separator: ":")
  }
  let prewarmCreationFailure = prewarmFailure ?? "prewarm_controller_unavailable"
  queueTrace("worker-create stage=prewarm-failed error=\(prewarmCreationFailure)")
  state.lastError = prewarmCreationFailure

  // A fresh parallel task must never fall back to a renderer that already
  // belongs to another running Chat. That fallback was the reason task B
  // tried to press New Chat inside task A's streaming page.
  guard reuseExisting else {
    state.lastError = prewarmCreationFailure
    return nil
  }
  let fallback = ensureHiddenChatTarget(&state)
  guard let prepared = fallback,
        prepared["ok"] as? Bool == true,
        let preparedPort = prepared["port"] as? Int,
        let targetId = prepared["targetId"] as? String,
        queueTargetIsReady(port: preparedPort, targetId: targetId) else {
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
  // Reuse the authenticated ChatGPT desktop process and ask its official
  // prewarm service to create a fresh hidden app renderer.
  guard let worker = createQueueWorkerTarget(&state, reuseExisting: false) else {
    return nil
  }
  state.queueWorkerMode = parallelHiddenWindowQueueWorkerMode
  return worker
}

func stopQueueWorker(_ state: inout PluginState) {
  // Close only queue-owned hidden windows. The primary window and the shared
  // ChatGPT process remain available to the user and the general confirmer.
  if state.queueWorkerMode == parallelDedicatedProcessQueueWorkerMode {
    for task in state.automationTasks ?? [] {
      if let targetId = task.workerTargetId {
        _ = CDPClient.closeTarget(targetId, portOverride: task.workerPort)
      }
      if let profilePath = task.workerProfilePath {
        terminateDedicatedChatProcess(profilePath: profilePath)
      }
    }
    if let profilePath = state.queueWorkerProfilePath,
       !(state.automationTasks ?? []).contains(where: {
         $0.workerProfilePath == profilePath
       }) {
      terminateDedicatedChatProcess(profilePath: profilePath)
    }
  } else if state.queueWorkerMode == parallelHiddenWindowQueueWorkerMode {
    let taskTargets = Set((state.automationTasks ?? []).compactMap { task -> String? in
      guard let port = task.workerPort,
            let targetId = task.workerTargetId,
            queueTargetIsHidden(port: port, targetId: targetId) else { return nil }
      _ = CDPClient.closeTarget(targetId, portOverride: port)
      return targetId
    })
    if let targetId = state.queueWorkerTargetId,
       !taskTargets.contains(targetId),
       let port = state.queueWorkerPort,
       queueTargetIsHidden(port: port, targetId: targetId) {
      _ = CDPClient.closeTarget(targetId, portOverride: port)
    }
  } else if state.queueWorkerMode == backgroundWindowQueueWorkerMode {
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
  // Each parallel task owns a fresh hidden Chat BrowserWindow inside the same
  // authenticated ChatGPT process. This preserves the proven real Chat UI path
  // without navigating away from another task's streaming conversation.
  var prepared: [String: Any]?
  var preparationFailure: String?
  var port: Int?
  var targetId: String?
  var workerProfilePath: String?
  var taskOwnsTarget = false
  let previousConversationId = (task.continuationDepth ?? 0) > 0
    ? normalizedConversationId(task.conversationId)
    : nil
  defer {
    if !taskOwnsTarget, let port, let targetId {
      _ = CDPClient.closeTarget(targetId, portOverride: port)
    }
    if !taskOwnsTarget, let workerProfilePath {
      terminateDedicatedChatProcess(profilePath: workerProfilePath)
    }
  }
  if state.queueWorkerMode == parallelDedicatedProcessQueueWorkerMode,
     let staleProfilePath = task.workerProfilePath {
    terminateDedicatedChatProcess(profilePath: staleProfilePath)
  } else if state.queueWorkerMode == parallelHiddenWindowQueueWorkerMode,
     let staleTargetId = task.workerTargetId,
     let stalePort = task.workerPort,
     queueTargetIsReady(port: stalePort, targetId: staleTargetId) {
    _ = CDPClient.closeTarget(staleTargetId, portOverride: stalePort)
  }
  task.workerPort = nil
  task.workerTargetId = nil
  task.workerProfilePath = nil
  queueTrace("task=\(task.id) stage=create-worker begin")
  guard var worker = createIndependentQueueWorkerTarget(&state) else {
    let detail = state.lastError ?? "unknown"
    throw NSError(
      domain: "chatgpt-auto-confirm",
      code: 33,
      userInfo: [
        NSLocalizedDescriptionKey: "当前 ChatGPT 实例没有可用的隐藏 Chat 页面（\(detail)）"
      ]
    )
  }
  queueTrace("task=\(task.id) stage=create-worker complete target=\(worker.targetId)")
  port = worker.port
  targetId = worker.targetId
  workerProfilePath = worker.profilePath
  if let previousConversationId {
    queueTrace(
      "task=\(task.id) stage=prepare-continuation begin "
        + "previousConversation=\(previousConversationId)"
    )
    let restoration = restoreHiddenConversation(
      port: worker.port,
      targetId: worker.targetId,
      conversationId: previousConversationId
    )
    let restorationSucceeded = restoration["ok"] as? Bool == true
    if restorationSucceeded {
      prepared = cdpValue(
        port: worker.port,
        targetId: worker.targetId,
        expression: continueInNewTaskJS(expectedConversationId: previousConversationId),
        timeout: 35.0
      )
    } else {
      prepared = [
        "ok": false,
        "error": restoration["error"] as? String
          ?? "continuation_conversation_click_failed",
        "conversationId": previousConversationId,
      ]
    }
    queueTrace(
      "task=\(task.id) stage=prepare-continuation "
        + "restored=\(restorationSucceeded) "
        + "strategy=\(restoration["strategy"] as? String ?? "none") "
        + "conversationClick=\(restoration["clickStrategy"] as? String ?? "none") "
        + "clicked=\(prepared?["continuationClicked"] as? Bool == true) "
        + "continuationLabel=\(prepared?["continuationLabel"] as? String ?? "none") "
        + "newConversation=\(prepared?["conversationId"] as? String ?? "none") "
        + "error=\(prepared?["error"] as? String ?? "none")"
    )
    if prepared?["ok"] as? Bool != true {
      let continuationError = prepared?["error"] as? String ?? "continuation_no_result"
      preparationFailure = continuationError
      let screenshot = captureHiddenChatScreenshot(
        port: worker.port,
        targetId: worker.targetId,
        label: "continuation-fallback"
      )
      queueTrace(
        "task=\(task.id) stage=prepare-continuation fallback=new-chat "
          + "reason=\(continuationError) "
          + "screenshot=\(screenshot ?? "none")"
      )
      let staleTargetId = worker.targetId
      let stalePort = worker.port
      let staleClosed = CDPClient.closeTarget(staleTargetId, portOverride: stalePort)
      queueTrace(
        "task=\(task.id) stage=prepare-continuation fallback=recreate-worker "
          + "begin staleTarget=\(staleTargetId) closed=\(staleClosed)"
      )
      port = nil
      targetId = nil
      workerProfilePath = nil
      if let replacement = createIndependentQueueWorkerTarget(&state) {
        worker = replacement
        port = replacement.port
        targetId = replacement.targetId
        workerProfilePath = replacement.profilePath
        queueTrace(
          "task=\(task.id) stage=prepare-continuation fallback=recreate-worker "
            + "complete target=\(replacement.targetId)"
        )
        if var fallback = prepareNewChatTarget(
          port: replacement.port,
          targetId: replacement.targetId,
          timeout: 4.0,
          allowBlankConversationReuse: true
        ) {
          fallback["continuationFallback"] = true
          fallback["continuationFailure"] = continuationError
          fallback["previousConversationId"] = previousConversationId
          fallback["replacementTarget"] = true
          prepared = fallback
        } else {
          preparationFailure = "continuation_fallback_new_chat_failed"
          prepared = nil
        }
      } else {
        preparationFailure = "continuation_fallback_worker_create_failed"
        prepared = nil
      }
    }
  } else {
    queueTrace("task=\(task.id) stage=prepare-new-chat begin")
    prepared = prepareNewChatTarget(
      port: worker.port,
      targetId: worker.targetId,
      timeout: 4.0,
      allowBlankConversationReuse: true
    )
  }
  guard let prepared,
        prepared["ok"] as? Bool == true,
        let port,
        let targetId else {
    throw NSError(
      domain: "chatgpt-auto-confirm",
      code: 22,
      userInfo: [
        NSLocalizedDescriptionKey:
          "无法为任务 \(task.id) 准备已登录 Chat（\(preparationFailure ?? "unknown")）"
      ]
    )
  }
  queueTrace(
    "task=\(task.id) stage=\(previousConversationId == nil ? "prepare-new-chat" : "prepare-continuation") complete"
  )
  let attempt = task.attempts + 1
  task.appliedRevision = max(1, task.currentRevision ?? 1)
  task.appliedSpecDigest = task.specDigest
  task.pendingRevision = nil
  let outbound = messageWithTaskReportContract(automationTaskMessage(task))
  queueTrace("task=\(task.id) stage=send begin")
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
    let stageDetails: String
    if let stages = sendResult["stages"],
       JSONSerialization.isValidJSONObject(stages),
       let data = try? JSONSerialization.data(withJSONObject: stages),
       let json = String(data: data, encoding: .utf8) {
      stageDetails = json
    } else {
      stageDetails = "[]"
    }
    throw NSError(
      domain: "chatgpt-auto-confirm",
      code: 23,
      userInfo: [
        NSLocalizedDescriptionKey: "任务 \(task.id) 页面发送失败（\(stage): \(error)） candidates: \(candidates) stages: \(stageDetails)"
      ]
    )
  }
  queueTrace("task=\(task.id) stage=send complete")
  _ = cdpValue(
    port: port,
    targetId: targetId,
    expression: autoConfirmChatContinuationJS(),
    timeout: 4.0
  )
  let dispatchMarker = "任务发送轮次：\(attempt)"
  queueTrace("task=\(task.id) stage=resolve-conversation begin")
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
  taskOwnsTarget = true
  queueTrace("task=\(task.id) stage=running conversation=\(conversationId)")
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
  dedicatedQueueChatLaunchers = dedicatedQueueChatLaunchers.filter { _, launcher in
    launcher.isRunning
  }
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
  // Parallel tasks own separate hidden windows, so a task may close only the
  // target recorded on that task. Keep the legacy shared-renderer guard for
  // queues created by an older runtime during migration.
  if state.queueWorkerMode != sharedConversationQueueWorkerMode,
     let targetId = task.workerTargetId {
    _ = CDPClient.closeTarget(targetId, portOverride: task.workerPort)
  }
  if state.queueWorkerMode == parallelDedicatedProcessQueueWorkerMode,
     let profilePath = task.workerProfilePath {
    terminateDedicatedChatProcess(profilePath: profilePath)
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
