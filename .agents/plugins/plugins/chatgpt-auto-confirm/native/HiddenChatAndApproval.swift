import ApplicationServices
import Cocoa
import Darwin
import Foundation
import SystemConfiguration

func loadedApprovalTargets(_ state: PluginState) -> [CDPApprovalTarget] {
  // The general watcher may act only on the exact renderer it created and
  // proved hidden. Scanning the primary debugging endpoint also included the
  // user's visible Chat, so startup could click controls on the displayed page
  // while still reporting `backgroundOnly=true`.
  // Runtime.evaluate does not activate the app, but renderer ownership and
  // hidden-window state are still mandatory before any page script may run.
  guard let port = state.backgroundAppPort,
        let targetId = state.backgroundChatTargetId,
        queueTargetRuntimeState(
          port: port,
          targetId: targetId,
          refreshLifecycle: false
        ) == .hidden,
        let target = CDPClient.fetchTargets(portOverride: port).first(where: {
          $0["id"] as? String == targetId && isLoadedApprovalRendererTarget($0)
        }) else { return [] }
  return [CDPApprovalTarget(port: port, target: target)]
}

func normalizedChatURL(_ rawValue: String?) -> String? {
  guard let rawValue,
        let url = URL(string: rawValue),
        url.scheme?.lowercased() == "https",
        url.host?.lowercased() == "chatgpt.com",
        url.path == "/" || url.path.hasPrefix("/c/") else { return nil }
  var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
  components?.fragment = nil
  return components?.url?.absoluteString
}

func rememberChatURL(_ rawValue: String?, in state: inout PluginState) {
  guard let url = normalizedChatURL(rawValue) else { return }
  var urls = state.trackedChatURLs ?? []
  urls.removeAll { $0 == url }
  urls.append(url)
  state.trackedChatURLs = Array(urls.suffix(20))
}

@discardableResult
func synchronizeBackgroundTargets(
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

func closeBackgroundTargets(_ state: inout PluginState) {
  for targetId in (state.backgroundTargets ?? [:]).values {
    _ = CDPClient.closeTarget(targetId)
  }
  state.backgroundTargets = [:]
}

@discardableResult
func ensureChatTarget(_ rawValue: String?, in state: inout PluginState) -> String? {
  guard let rawValue else { return nil }
  guard let chatURL = normalizedChatURL(rawValue) else { return nil }
  rememberChatURL(chatURL, in: &state)
  let created = synchronizeBackgroundTargets(&state, targets: CDPClient.fetchTargets())
  if created > 0 { Thread.sleep(forTimeInterval: 0.25) }
  return chatURL
}

func cdpValue(
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

func pageDiagnosticJS() -> String {
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
    const normalizeModeText = value => (value || '').replace(/\s+/g, ' ').trim();
    const modeNodes = [...document.querySelectorAll('body *')]
      .filter(node => node.children.length === 0)
      .filter(node => ['Chat', 'Work', '聊天', '工作'].includes(normalizeModeText(node.innerText || node.textContent)))
      .filter(node => node.offsetWidth || node.offsetHeight || node.getClientRects().length)
      .slice(0, 40)
      .map(node => ({
        text: normalizeModeText(node.innerText || node.textContent),
        tag: node.tagName || '',
        role: node.getAttribute('role') || '',
        ariaSelected: node.getAttribute('aria-selected') || '',
        ariaPressed: node.getAttribute('aria-pressed') || '',
        className: normalizeModeText(node.className),
        parent: node.parentElement?.outerHTML?.slice(0, 600) || ''
      }));
    return {
      ok: true,
      content: text.substring(0, 50000),
      buttons,
      modeNodes,
      signature: `${text.length}:${text.slice(-4000)}:${buttons.join('|')}`,
      url: window.location.href || ''
    };
  })()
  """#
}

func captureHiddenChatScreenshot(
  port: Int,
  targetId: String,
  label: String = "stalled"
) -> String? {
  guard let target = CDPClient.fetchTargets(portOverride: port).first(where: {
          $0["id"] as? String == targetId
        }),
        let wsURL = target["webSocketDebuggerUrl"] as? String else { return nil }
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
  let outputURL = stateURL().deletingLastPathComponent()
    .appendingPathComponent("diagnostics", isDirectory: true)
    .appendingPathComponent("chat-\(label)-\(formatter.string(from: Date())).png")
  _ = CDPClient.setWebLifecycleActive(wsURLString: wsURL)
  return CDPClient.captureScreenshot(wsURLString: wsURL, outputURL: outputURL)
    ? outputURL.path
    : nil
}

func captureHiddenChatScreenshot(_ state: PluginState, label: String = "stalled") -> String? {
  guard let port = state.backgroundAppPort,
        let targetId = state.backgroundChatTargetId else { return nil }
  return captureHiddenChatScreenshot(port: port, targetId: targetId, label: label)
}

func hiddenChatProfilePath() -> String {
  FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/Mahayana/plugins/chatgpt-auto-confirm/background-chat-profile")
    .path
}

func configuredHiddenChatProfilePath() -> String? {
  guard let raw = ProcessInfo.processInfo.environment["CHATGPT_AUTO_CONFIRM_PROFILE_PATH"]?
          .trimmingCharacters(in: .whitespacesAndNewlines),
        !raw.isEmpty else { return nil }
  return raw
}

func hiddenChatPort(_ state: PluginState) -> Int {
  if let raw = ProcessInfo.processInfo.environment["CHATGPT_AUTO_CONFIRM_BACKGROUND_PORT"],
     let port = Int(raw), port > 0 && port <= 65535 { return port }
  return state.backgroundAppPort ?? 9324
}

func configuredHiddenChatPort() -> Int? {
  guard let raw = ProcessInfo.processInfo.environment["CHATGPT_AUTO_CONFIRM_BACKGROUND_PORT"],
        let port = Int(raw), port > 0 && port <= 65535 else { return nil }
  return port
}

func backgroundConversationURL(_ conversationId: String) -> String? {
  var components = URLComponents(string: "app://-/index.html")
  components?.queryItems = [
    URLQueryItem(
      name: "initialRoute",
      value: "/work/conversation/\(conversationId)"
    )
  ]
  return components?.url?.absoluteString
}

func wakeHiddenRenderer(
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

func navigateHiddenConversation(
  port: Int,
  targetId: String,
  conversationId: String,
  timeout: TimeInterval = 35.0,
  allowVisible: Bool = false
) -> Bool {
  guard let url = backgroundConversationURL(conversationId),
        let target = CDPClient.fetchTargets(portOverride: port).first(where: {
          $0["id"] as? String == targetId
        }),
        let wsURL = target["webSocketDebuggerUrl"] as? String,
        CDPClient.navigate(wsURLString: wsURL, url: url) else { return false }
  Thread.sleep(forTimeInterval: 0.5)
  let initialRuntimeState = queueTargetRuntimeState(
    port: port,
    targetId: targetId,
    refreshLifecycle: false
  )
  switch initialRuntimeState {
  case .hidden, .hiddenNonChat:
    guard wakeHiddenRenderer(port: port, targetId: targetId, wsURL: wsURL) else {
      return false
    }
  case .visible:
    guard allowVisible else { return false }
  case .missing, .suspended:
    return false
  }
  let deadline = Date().addingTimeInterval(timeout)
  repeat {
    let runtimeState = queueTargetRuntimeState(
      port: port,
      targetId: targetId,
      refreshLifecycle: true
    )
    switch runtimeState {
    case .hidden, .hiddenNonChat:
      break
    case .visible:
      if !allowVisible { return false }
    case .missing, .suspended:
      return false
    }
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

func restoreHiddenConversation(
  port: Int,
  targetId: String,
  conversationId: String,
  timeout: TimeInterval = 35.0,
  allowVisible: Bool = false
) -> [String: Any] {
  // Prefer the live sidebar. A direct Page.navigate on the hosted desktop
  // renderer can leave the app on its startup spinner, which also poisons the
  // subsequent fresh-chat fallback.
  let sidebar = cdpValue(
    port: port,
    targetId: targetId,
    expression: selectBackgroundConversationJS(conversationId),
    timeout: min(timeout, 20.0)
  )
  if sidebar?["ok"] as? Bool == true,
     let status = cdpValue(
       port: port,
       targetId: targetId,
       expression: chatStatusJS(),
       timeout: 5.0
     ), normalizedConversationId(status["conversationId"] as? String) == conversationId,
        status["chatMode"] as? Bool == true {
    var result = sidebar ?? [:]
    result["ok"] = true
    result["strategy"] = "sidebar"
    return result
  }

  let sidebarError = sidebar?["error"] as? String
    ?? "continuation_sidebar_selection_failed"
  let navigated = navigateHiddenConversation(
    port: port,
    targetId: targetId,
    conversationId: conversationId,
    timeout: timeout,
    allowVisible: allowVisible
  )
  return [
    "ok": navigated,
    "error": navigated ? "" : "continuation_route_navigation_failed",
    "strategy": "route",
    "sidebarError": sidebarError,
    "conversationId": conversationId,
  ]
}

func selectBackgroundConversationJS(_ conversationId: String) -> String {
  let expected = jsonStringLiteral(conversationId)
  return """
  (async () => {
    const expected = \(expected);
    const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
    const rendered = element => !!(element
      && (element.offsetWidth || element.offsetHeight || element.getClientRects().length));
    const dispatchPointerClick = element => {
      const rect = element.getBoundingClientRect?.();
      const clientX = rect ? rect.left + Math.max(1, rect.width / 2) : 1;
      const clientY = rect ? rect.top + Math.max(1, rect.height / 2) : 1;
      const pressed = {
        bubbles: true, cancelable: true, composed: true,
        button: 0, buttons: 1, clientX, clientY
      };
      element.dispatchEvent(new PointerEvent('pointerdown', {
        ...pressed, pointerId: 1, pointerType: 'mouse', isPrimary: true
      }));
      element.dispatchEvent(new MouseEvent('mousedown', pressed));
      element.dispatchEvent(new PointerEvent('pointerup', {
        ...pressed, buttons: 0, pointerId: 1, pointerType: 'mouse', isPrimary: true
      }));
      element.dispatchEvent(new MouseEvent('mouseup', { ...pressed, buttons: 0 }));
      element.dispatchEvent(new MouseEvent('click', { ...pressed, buttons: 0 }));
    };
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
        || decoded.endsWith(`/c/${expected}`)
        || decoded.endsWith(`/work/conversation/${expected}`)
        || (expected.startsWith('local-chatgpt:') && decoded.includes(expected));
    };
    const rowMatches = row => {
      const domCandidates = [
        row.getAttribute?.('href'), row.getAttribute?.('data-conversation-id'),
        row.getAttribute?.('data-thread-id'), row.getAttribute?.('data-testid')
      ];
      if (domCandidates.some(matches)) return true;
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
    const directLinks = [...document.querySelectorAll(
      `a[href*="/c/${expected}"], a[href*="/work/conversation/${expected}"], `
        + `[data-conversation-id="${expected}"], [data-thread-id="${expected}"]`
    )];
    const titledRows = [...document.querySelectorAll('[data-thread-title="true"]')]
      .map(title => title.closest('a, button, [role="button"]')).filter(Boolean);
    const rows = [...new Set([...directLinks, ...titledRows])].filter(rendered);
    const row = rows.find(rowMatches);
    if (!row) {
      return {
        ok: false,
        error: 'conversation_sidebar_row_not_found',
        expected,
        candidateRowCount: rows.length,
        directLinkCount: directLinks.length
      };
    }
    const previousFingerprint = conversationFingerprint();
    const clickStrategy = directLinks.includes(row) ? 'direct-link' : 'sidebar-row';
    dispatchPointerClick(row);
    for (let index = 0; index < 40; index += 1) {
      await sleep(150);
      const resolved = portalId();
      const input = document.querySelector('#prompt-textarea')
        || document.querySelector('[contenteditable="true"]');
      if (resolved && input && (matches(resolved) || rowMatches(row))) {
        const exactConversation = matches(resolved);
        const ready = await waitForConversationBody(previousFingerprint, !exactConversation);
        return ready.ok
          ? {
              ok: true, selected: true, messagesReady: true,
              conversationId: resolved, clickStrategy,
              candidateRowCount: rows.length, directLinkCount: directLinks.length
            }
          : {
              ok: false, error: ready.error, expected,
              conversationId: resolved, clickStrategy,
              candidateRowCount: rows.length, directLinkCount: directLinks.length
            };
      }
    }
    return {
      ok: false,
      error: 'conversation_sidebar_selection_timeout', expected, clickStrategy,
      candidateRowCount: rows.length, directLinkCount: directLinks.length
    };
  })()
  """
}

func normalizedConversationId(_ rawValue: String?) -> String? {
  guard let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
        !value.isEmpty,
        value.range(
          of: "^(?:local-chatgpt:)?[A-Za-z0-9-]{8,128}$",
          options: .regularExpression
        ) != nil else { return nil }
  return value
}

func prepareBackgroundChatJS(
  newChat: Bool,
  conversationId: String? = nil,
  confirmedChatMode: Bool = false
) -> String {
  let newChatValue = newChat ? "true" : "false"
  let confirmedChatModeValue = confirmedChatMode ? "true" : "false"
  let expectedConversationId = jsonStringLiteral(conversationId ?? "")
  return """
  (async () => {
    const result = {
      ok: false, backgroundOnly: true, workerUsed: false,
      newChatClicked: false, chatSelected: false, error: null,
      url: window.location.href || '', conversationId: null
    };
    const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
    const confirmedChatMode = \(confirmedChatModeValue);
    // Selecting ChatGPT can replace the Electron renderer and erase transient
    // window globals. The native caller carries that verified selection across
    // the replacement and reseeds the new renderer before surface detection.
    if (confirmedChatMode) window.__mahayanaConfirmedChatGPTMode = true;
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

    const quickChatRoot = document.querySelector(
      '[data-pip-obstacle="quick-chat"], [data-quick-chat-drag-handle]'
    )?.closest('[role="dialog"], section, div');
    const input = quickChatRoot?.querySelector(
      '#prompt-textarea, [contenteditable="true"]'
    ) || document.querySelector('#prompt-textarea')
      || document.querySelector('[contenteditable="true"]');
    const chatModel = [...document.querySelectorAll('button, a, [role="button"]')].some(button => {
      const label = button.getAttribute('aria-label') || '';
      return label.includes('ChatGPT 模型') || /select chatgpt model/i.test(label);
    });
    const currentChatGPTMode = window.__mahayanaConfirmedChatGPTMode === true
      || [...document.querySelectorAll('button, a, [role="button"]')]
      .some(button => {
        const label = [
          button.innerText,
          button.textContent,
          button.getAttribute('aria-label'),
          button.getAttribute('title')
        ].filter(Boolean).join(' ').toLowerCase();
        return label.includes('current mode: chatgpt')
          || (label.includes('当前模式') && label.includes('chatgpt'));
      });
    const webChat = window.location.protocol === 'https:'
      && window.location.hostname === 'chatgpt.com';
    // The top-level Chat/Work switch is authoritative. A stale mode flag must
    // not make the Work composer look like Chat after a renderer replacement.
    const workComposer = !quickChatRoot
      && !!document.querySelector('[data-codex-composer="true"]');
    
    const isChatSurface = !!quickChatRoot
      || !!document.querySelector('#prompt-textarea')
      || chatModel
      || currentChatGPTMode
      || webChat
      || window.location.protocol === 'chatgpt:';

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
    result.messageCount = document.querySelectorAll(
      '[data-message-author-role], [data-user-message-bubble], [data-local-conversation-final-assistant]'
    ).length;
    result.inputTextLength = (
      input?.tagName === 'TEXTAREA' || input?.tagName === 'INPUT'
        ? (input.value || '')
        : (input?.innerText || input?.textContent || '')
    ).trim().length;
    const expectedConversationId = \(expectedConversationId);
    result.expectedConversationId = expectedConversationId || null;
    if (!input || !isChatSurface || workComposer) {
      result.error = 'not_chat_surface';
      result.hasInput = !!input;
      result.chatModel = chatModel;
      result.workComposer = workComposer;
      result.html = document.body ? document.body.innerHTML.slice(0, 50000) : '';
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

func resolveDispatchedConversationJS(
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
      const rows = [...new Set(
        [...document.querySelectorAll(
          '[data-thread-title="true"], a[href*="/c/"], a[href*="/work/conversation/"]'
        )]
          .map(element => element.closest('[role="button"], a[href]'))
          .filter(Boolean)
      )];
      for (const row of rows) {
        const title = (
          row.querySelector('[data-thread-title="true"]')?.textContent
            || row.textContent || ''
        ).trim();
        const fiberKey = Object.keys(row).find(key => key.startsWith('__reactFiber$'));
        let fiber = fiberKey ? row[fiberKey] : null;
        const identities = [];
        const durableIds = [];
        for (const attribute of ['data-conversation-id', 'data-thread-id']) {
          identities.push(row.getAttribute(attribute));
        }
        const routeValues = [
          row.getAttribute('href'),
          ...[...row.querySelectorAll('a[href]')].map(anchor => anchor.getAttribute('href'))
        ];
        for (const route of routeValues) {
          if (typeof route !== 'string') continue;
          const match = route.match(/\\/(?:c|work\\/conversation)\\/([^/?#]+)/);
          if (match) identities.push(match[1]), durableIds.push(match[1]);
        }
        for (let depth = 0; fiber && depth < 8; depth += 1, fiber = fiber.return) {
          const props = fiber.memoizedProps || {};
          identities.push(props.conversationId, props.conversation?.id);
          if (typeof props.conversation?.id === 'string') {
            durableIds.push(props.conversation.id);
          }
          for (const route of [props.route, props.shortcutKey]) {
            if (typeof route !== 'string') continue;
            const match = route.match(/\\/(?:c|work\\/conversation)\\/([^/?#]+)/);
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

func clickNewChatJS() -> String {
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
      const isMac = window.location.protocol === 'chatgpt:';
      window.location.href = isMac ? 'chatgpt://work/' : '/';
      return { ok: true, newChatClicked: true, previousConversationId, fallbackNavigated: true };
    }
    button.click();
    return { ok: true, newChatClicked: true, previousConversationId };
  })()
  """#
}

func clickChatJS() -> String {
  #"""
  (async () => {
    const normalize = value => (value || '').replace(/\s+/g, ' ').trim().toLowerCase();
    const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
    const candidates = () => [...document.querySelectorAll(
      'button, a, [role="button"], [role="menuitem"], '
        + '[role="menuitemradio"], [role="option"], [role="tab"]'
    )];
    const labelsFor = candidate => [
      candidate.innerText,
      candidate.textContent,
      candidate.getAttribute('aria-label'),
      candidate.getAttribute('title')
    ].map(normalize).filter(Boolean);
    const dispatchPointerClick = candidate => {
      const rect = candidate.getBoundingClientRect?.();
      const clientX = rect ? rect.left + Math.min(12, Math.max(1, rect.width / 2)) : 1;
      const clientY = rect ? rect.top + Math.min(12, Math.max(1, rect.height / 2)) : 1;
      const pressed = {
        bubbles: true,
        cancelable: true,
        composed: true,
        button: 0,
        buttons: 1,
        clientX,
        clientY
      };
      // Radix's compact mode trigger opens on pointerdown. HTMLElement.click()
      // emits only click, so the hosted app silently stayed on the Codex/Work
      // composer even though the dispatch itself reported success.
      candidate.dispatchEvent(new PointerEvent('pointerdown', {
        ...pressed,
        pointerId: 1,
        pointerType: 'mouse',
        isPrimary: true
      }));
      candidate.dispatchEvent(new MouseEvent('mousedown', pressed));
      candidate.dispatchEvent(new PointerEvent('pointerup', {
        ...pressed,
        buttons: 0,
        pointerId: 1,
        pointerType: 'mouse',
        isPrimary: true
      }));
      candidate.dispatchEvent(new MouseEvent('mouseup', { ...pressed, buttons: 0 }));
      candidate.dispatchEvent(new MouseEvent('click', { ...pressed, buttons: 0 }));
    };
    const visible = candidate => {
      const rect = candidate.getBoundingClientRect?.();
      return !!rect && (rect.width > 0 || rect.height > 0 || candidate.offsetParent !== null);
    };
    const isSelected = candidate => {
      const selectedValues = [
        candidate.getAttribute('aria-selected'),
        candidate.getAttribute('aria-pressed'),
        candidate.getAttribute('data-state'),
        candidate.getAttribute('data-selected'),
        candidate.getAttribute('data-active')
      ].map(normalize);
      if (selectedValues.some(value => ['true', 'active', 'selected', 'on'].includes(value))) {
        return true;
      }
      return /(?:^|[ _-])(active|selected|current|chosen)(?:$|[ _-])/.test(
        normalize(candidate.className)
      );
    };
    // Do not treat labels such as "Chat sidebar options" as the Chat mode.
    // The Work composer exposes that sidebar label even when the top-level
    // Chat/Work switch is absent, which previously produced a false success.
    const isChatLabel = label => label === 'chat' || label === '聊天';
    const isWorkLabel = label => label === 'work' || label === '工作';
    // The compact desktop layout replaces the top Chat/Work tabs with a mode
    // popup whose real Chat choice is named "ChatGPT". Accept that exact label
    // only when it is a menu/list choice, never from the sidebar heading or a
    // model button.
    const isChatGPTMenuChoice = candidate => {
      const role = normalize(candidate.getAttribute('role'));
      const choiceRole = role === 'menuitem'
        || role === 'menuitemradio'
        || role === 'option';
      const insideChoicePopup = !!candidate.closest('[role="menu"], [role="listbox"]');
      const hasExactChatGPTChild = [...candidate.querySelectorAll('*')].some(child =>
        child.children.length === 0 && normalize(child.textContent) === 'chatgpt'
      );
      return (choiceRole || insideChoicePopup)
        && (labelsFor(candidate).some(label => label === 'chatgpt')
          || hasExactChatGPTChild);
    };
    const modeTabScore = candidate => {
      const rect = candidate.getBoundingClientRect?.();
      const role = normalize(candidate.getAttribute('role'));
      const labels = labelsFor(candidate);
      let score = 0;
      if (role === 'tab' || role === 'option' || role.startsWith('menuitem')) score += 100;
      if (isSelected(candidate)) score += 50;
      if (visible(candidate)) score += 10;
      if (rect && rect.top >= -20 && rect.top < 180) score += 20;
      if (rect && window.innerWidth > 0
          && rect.left > window.innerWidth * 0.25
          && rect.right < window.innerWidth * 0.8) score += 10;
      if (labels.some(label => isChatLabel(label) || isWorkLabel(label))
          || isChatGPTMenuChoice(candidate)) score += 5;
      return score;
    };
    const textModeNodes = () => [...document.querySelectorAll('body *')]
      .filter(candidate => candidate.children.length === 0 && visible(candidate))
      .filter(candidate => labelsFor(candidate).some(label => isChatLabel(label) || isWorkLabel(label)));
    const modeTabs = () => [...new Set([...candidates(), ...textModeNodes()])]
      .filter(candidate => visible(candidate))
      .filter(candidate =>
        labelsFor(candidate).some(label => isChatLabel(label) || isWorkLabel(label))
          || isChatGPTMenuChoice(candidate)
      );
    const modeControls = modeTabs().map(candidate => ({
      label: labelsFor(candidate)[0] || '',
      tag: candidate.tagName || '',
      role: candidate.getAttribute('role') || '',
      className: normalize(candidate.className),
      selected: isSelected(candidate),
      score: modeTabScore(candidate)
    }));
    const chatSurface = () => {
      const quickChatRoot = document.querySelector(
        '[data-pip-obstacle="quick-chat"], [data-quick-chat-drag-handle]'
      )?.closest('[role="dialog"], section, div');
      const input = quickChatRoot?.querySelector(
        '#prompt-textarea, [contenteditable="true"]'
      ) || document.querySelector('#prompt-textarea')
        || document.querySelector('[contenteditable="true"]');
      const chatModel = [...document.querySelectorAll('button, a, [role="button"]')].some(button => {
        const label = [
          button.getAttribute('aria-label'),
          button.getAttribute('title'),
          button.innerText,
          button.textContent
        ].filter(Boolean).map(normalize).join(' ');
        return label.includes('chatgpt model') || label.includes('chatgpt 模型')
          || label.includes('select chatgpt model') || label.includes('选择 chatgpt 模型');
      });
      const workComposer = !quickChatRoot
        && !!document.querySelector('[data-codex-composer="true"]');
      const webChat = location.protocol === 'https:' && location.hostname === 'chatgpt.com';
      return {
        active: !!input && !workComposer && (!!quickChatRoot || chatModel || webChat),
        hasInput: !!input,
        chatModel,
        workComposer,
        quickChatRoot: !!quickChatRoot,
        webChat
      };
    };
    const surface = chatSurface();
    if (surface.active) {
      window.__mahayanaConfirmedChatGPTMode = true;
      return {
        ok: true,
        chatSelected: false,
        alreadySelected: true,
        selectedLabel: 'chat-surface-validated',
        surface,
        modeControls
      };
    }
    const currentChatGPTMode = candidates().find(candidate =>
      labelsFor(candidate).some(label =>
        label.includes('current mode: chatgpt')
        || (label.includes('当前模式') && label.includes('chatgpt'))
      )
    );
    if (currentChatGPTMode && surface.hasInput && !surface.workComposer) {
      window.__mahayanaConfirmedChatGPTMode = true;
      return {
        ok: true,
        chatSelected: false,
        alreadySelected: true,
        selectedLabel: labelsFor(currentChatGPTMode)[0] || 'chatgpt',
        surface,
        modeControls
      };
    }
    const exactChat = () => modeTabs()
      .filter(candidate =>
        labelsFor(candidate).some(label => isChatLabel(label))
          || isChatGPTMenuChoice(candidate)
      )
      .sort((lhs, rhs) => modeTabScore(rhs) - modeTabScore(lhs))[0];
    let button = exactChat();
    if (!button) {
      const modeSwitch = candidates().find(candidate =>
        labelsFor(candidate).some(label =>
          label.includes('switch mode, current mode:')
          || label.includes('切换模式')
          || label.includes('当前模式')
        )
      );
      if (modeSwitch) {
        // Opening the switcher can itself replace the renderer. Return before
        // dispatching the click, then let the caller evaluate the new page and
        // select the ChatGPT menu item in a fresh execution context.
        window.__mahayanaChatModeSwitchAttempted = true;
        setTimeout(() => {
          try { dispatchPointerClick(modeSwitch); } catch (_) {}
        }, 0);
        return {
          ok: false,
          error: 'mode_switch_dispatched',
          retryAfterModeSwitch: true
        };
      }
    }
    if (!button) {
      button = candidates().find(candidate =>
        labelsFor(candidate).some(label =>
          label === 'quick chat' || label === '快速聊天'
        )
      );
    }
    if (!button) {
      const visibleCandidates = candidates();
      return {
        ok: false,
        error: 'chat_button_not_found',
        candidateLabels: visibleCandidates.flatMap(candidate => [
          candidate.innerText,
          candidate.getAttribute('aria-label'),
          candidate.getAttribute('title')
        ]).map(normalize).filter(Boolean).slice(0, 60)
      };
    }
    // Selecting ChatGPT can replace the renderer immediately. Dispatch the
    // click after this evaluation returns so a destroyed execution context is
    // not mistaken for a failed mode selection. The caller independently
    // waits for and validates the resulting hidden Chat surface.
    setTimeout(() => {
      try { button.click(); } catch (_) {}
    }, 0);
    return {
      ok: true,
      chatSelected: true,
      dispatchOnly: true,
      selectedLabel: normalize(
        button.innerText || button.getAttribute('aria-label') || button.getAttribute('title')
      ),
      surface,
      modeControls
    };
  })()
  """#
}

func clickCodexModeJS() -> String {
  #"""
  (() => {
    const normalize = value => (value || '').replace(/\s+/g, ' ').trim().toLowerCase();
    const candidates = () => [...document.querySelectorAll(
      'button, [role="button"], [role="menuitem"], [role="menuitemradio"], '
        + '[role="option"], [role="tab"]'
    )];
    const labelsFor = candidate => [
      candidate.innerText,
      candidate.textContent,
      candidate.getAttribute('aria-label'),
      candidate.getAttribute('title')
    ].map(normalize).filter(Boolean);
    const visible = candidate => {
      const rect = candidate.getBoundingClientRect?.();
      return !!rect && (rect.width > 0 || rect.height > 0 || candidate.offsetParent !== null);
    };
    const dispatchPointerClick = candidate => {
      const rect = candidate.getBoundingClientRect?.();
      const clientX = rect ? rect.left + Math.min(12, Math.max(1, rect.width / 2)) : 1;
      const clientY = rect ? rect.top + Math.min(12, Math.max(1, rect.height / 2)) : 1;
      const pressed = {
        bubbles: true,
        cancelable: true,
        composed: true,
        button: 0,
        buttons: 1,
        clientX,
        clientY
      };
      candidate.dispatchEvent(new PointerEvent('pointerdown', {
        ...pressed,
        pointerId: 1,
        pointerType: 'mouse',
        isPrimary: true
      }));
      candidate.dispatchEvent(new MouseEvent('mousedown', pressed));
      candidate.dispatchEvent(new PointerEvent('pointerup', {
        ...pressed,
        buttons: 0,
        pointerId: 1,
        pointerType: 'mouse',
        isPrimary: true
      }));
      candidate.dispatchEvent(new MouseEvent('mouseup', { ...pressed, buttons: 0 }));
      candidate.dispatchEvent(new MouseEvent('click', { ...pressed, buttons: 0 }));
    };
    const isCodexMenuChoice = candidate => {
      const role = normalize(candidate.getAttribute('role'));
      const choiceRole = role === 'menuitem'
        || role === 'menuitemradio'
        || role === 'option';
      const insideChoicePopup = !!candidate.closest('[role="menu"], [role="listbox"]');
      const hasExactCodexChild = [...candidate.querySelectorAll('*')].some(child =>
        child.children.length === 0 && normalize(child.textContent) === 'codex'
      );
      return (choiceRole || insideChoicePopup)
        && (labelsFor(candidate).some(label => label === 'codex')
          || hasExactCodexChild);
    };
    let target = candidates().find(candidate =>
      visible(candidate) && isCodexMenuChoice(candidate)
    );
    if (!target) {
      target = candidates().find(candidate => {
        const role = normalize(candidate.getAttribute('role'));
        return visible(candidate)
          && role === 'tab'
          && labelsFor(candidate).some(label => label === 'work' || label === '工作');
      });
    }
    if (target) {
      setTimeout(() => {
        try { target.click(); } catch (_) {}
      }, 0);
      return {
        ok: true,
        dispatchOnly: true,
        selectedLabel: normalize(
          target.innerText || target.getAttribute('aria-label') || target.getAttribute('title')
        )
      };
    }
    const modeSwitch = candidates().find(candidate =>
      labelsFor(candidate).some(label =>
        label.includes('switch mode, current mode:')
        || label.includes('切换模式')
        || label.includes('当前模式')
      )
    );
    if (modeSwitch) {
      setTimeout(() => {
        try { dispatchPointerClick(modeSwitch); } catch (_) {}
      }, 0);
      return {
        ok: false,
        error: 'mode_switch_dispatched',
        retryAfterModeSwitch: true
      };
    }
    return {
      ok: false,
      error: 'codex_mode_choice_not_found',
      candidateLabels: candidates().flatMap(candidate => labelsFor(candidate)).slice(0, 60)
    };
  })()
  """#
}

func composerSurfaceStateJS() -> String {
  #"""
  (() => {
    const normalize = value => (value || '').replace(/\s+/g, ' ').trim().toLowerCase();
    const quickChatRoot = document.querySelector(
      '[data-pip-obstacle="quick-chat"], [data-quick-chat-drag-handle]'
    )?.closest('[role="dialog"], section, div');
    const input = quickChatRoot?.querySelector(
      '#prompt-textarea, [contenteditable="true"]'
    ) || document.querySelector('#prompt-textarea')
      || document.querySelector('[contenteditable="true"]');
    const chatModel = [...document.querySelectorAll('button, a, [role="button"]')].some(button => {
      const label = [
        button.getAttribute('aria-label'),
        button.getAttribute('title'),
        button.innerText,
        button.textContent
      ].filter(Boolean).map(normalize).join(' ');
      return label.includes('chatgpt model') || label.includes('chatgpt 模型')
        || label.includes('select chatgpt model') || label.includes('选择 chatgpt 模型');
    });
    const workComposer = !quickChatRoot
      && !!document.querySelector('[data-codex-composer="true"]');
    const currentMode = [...document.querySelectorAll('button, [role="button"]')]
      .flatMap(candidate => [
        candidate.getAttribute('aria-label'),
        candidate.getAttribute('title'),
        candidate.innerText
      ])
      .map(normalize)
      .find(label =>
        label.includes('switch mode, current mode:')
        || label.includes('切换模式')
        || label.includes('当前模式')
      ) || '';
    return {
      ok: true,
      hasInput: !!input,
      chatModel,
      workComposer,
      quickChatRoot: !!quickChatRoot,
      currentMode
    };
  })()
  """#
}

func forcePrimaryComposerModeJS(_ requestedMode: String) -> String {
  let mode = requestedMode == "work" ? "work" : "chat"
  let modeLiteral = jsonStringLiteral(mode)
  return #"""
  (async () => {
    const key = 'home-composer-mode-v1';
    const value = \#(modeLiteral);
    const message = {
      type: 'persisted-atom-update',
      key,
      value,
      deleted: false
    };
    try {
      if (!window.electronBridge?.sendMessageFromView) {
        return { ok: false, error: 'electron_bridge_unavailable' };
      }
      await window.electronBridge.sendMessageFromView(message);
      // The host broadcasts this event to other renderers, but the source
      // renderer may not receive its own update while it is in Work mode.
      // Deliver the same official persisted-atom event locally as well.
      window.postMessage({
        type: 'persisted-atom-updated',
        key,
        value,
        deleted: false
      }, '*');
      // Keep the legacy renderer store aligned too. New renderers receive the
      // authoritative value from the host, while older ones still bootstrap
      // from this localStorage key.
      try {
        window.localStorage.setItem(`codex:persisted-atom:${key}`, JSON.stringify(value));
      } catch (_) {}
      return { ok: true, dispatched: true, key, value };
    } catch (error) {
      return {
        ok: false,
        error: String(error?.message || error || 'persisted_atom_update_failed')
      };
    }
  })()
  """#
}

func forcePrimaryChatModeJS() -> String {
  forcePrimaryComposerModeJS("chat")
}

func autoConfirmWorkHandoffJS() -> String {
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
func autoConfirmChatContinuationJS() -> String {
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

func detectDedicatedAuthorizationJS() -> String {
  #"""
  (() => {
    const normalize = value => (value || '').replace(/[\s↵⏎]+/g, ' ').trim().toLowerCase();
    const fingerprint = value => {
      let hash = 2166136261;
      for (const character of value) {
        hash ^= character.codePointAt(0);
        hash = Math.imul(hash, 16777619);
      }
      return `fnv1a32:${(hash >>> 0).toString(16).padStart(8, '0')}`;
    };
    const approvalRequestIdentity = element => {
      let domNode = element;
      for (let ancestorIndex = 0; ancestorIndex < 15 && domNode; ancestorIndex += 1) {
        const reactKeys = Object.keys(domNode).filter(key =>
          key.startsWith('__reactFiber$') || key.startsWith('__reactProps$')
        );
        for (const reactKey of reactKeys) {
          let reactNode = domNode[reactKey];
          for (let fiberIndex = 0; fiberIndex < 20 && reactNode; fiberIndex += 1) {
            const props = reactNode.memoizedProps || reactNode.pendingProps
              || reactNode.props || reactNode;
            const pluginData = props?.jit_plugin_data || props?.pluginData
              || props?.card?.jit_plugin_data;
            const allowOnce = pluginData?.from_server?.actions?.allow_once;
            const identity = allowOnce?.target_message_id || allowOnce?.targetMessageId
              || props?.target_message_id || props?.targetMessageId;
            if (identity) return String(identity);
            reactNode = reactNode.return;
          }
        }
        domNode = domNode.parentElement;
      }
      return '';
    };
    const visible = element => !!(element
      && !element.disabled
      && (element.offsetWidth || element.offsetHeight || element.getClientRects().length));
    const label = button => normalize(
      button.innerText || button.textContent
        || button.getAttribute('aria-label') || button.getAttribute('title')
    );
    const allowLabels = new Set([
      'allow', 'allow once', 'approve', 'approve once', 'confirm', 'confirm once',
      '允许', '允许一次', '同意', '同意一次', '确认', '确认一次',
      'full access', '完全访问'
    ]);
    const rejectLabels = new Set([
      'deny', 'reject', 'cancel', 'deny once', 'reject once',
      '拒绝', '拒绝一次', '不允许', '不允许一次', '取消'
    ]);
    const sessionHints = [
      'this chat', 'this conversation', 'for this chat', 'for this conversation',
      'for this session', 'during this chat', 'always allow in this chat',
      '本次会话', '这次会话', '此会话', '当前会话', '在此聊天中', '本次聊天',
      '始终允许', '会话期间'
    ];
    const buttons = [...document.querySelectorAll('button, a, [role="button"]')]
      .filter(visible);
    const candidates = buttons
      .map((button, index) => ({ button, index, label: label(button) }))
      .filter(candidate => allowLabels.has(candidate.label));
    const candidate = candidates[0];
    if (!candidate) {
      return {
        ok: true,
        found: false,
        candidates: 0,
        candidateLabels: [],
        selectedLabel: '',
        cardButtonLabels: [],
        sessionScopeLabels: [],
        menuTriggerLabels: [],
        menuTriggerCount: 0,
        unlabeledControlCount: 0
      };
    }

    let container = candidate.button.parentElement;
    for (let index = 0; index < 15 && container; index += 1) {
      const cardButtons = [...container.querySelectorAll('button, a, [role="button"]')]
        .filter(visible);
      const cardLabels = cardButtons.map(label);
      const hasReject = cardLabels.some(value => rejectLabels.has(value));
      const cardText = normalize(container.innerText || container.textContent || '');
      if (hasReject || cardText.includes('allow chatgpt to use') || cardText.includes('允许 chatgpt 使用')) {
        const nonDecisionControls = cardButtons.filter(button => {
          const value = label(button);
          return !allowLabels.has(value) && !rejectLabels.has(value);
        });
        const menuTriggers = nonDecisionControls.filter(button =>
          button.getAttribute('aria-haspopup') === 'menu'
            || button.getAttribute('aria-expanded') !== null
            || normalize(button.getAttribute('data-state')) === 'open'
            || /menu|dropdown|chevron|more/.test(normalize(
              button.getAttribute('data-testid') || button.getAttribute('data-slot')
                || button.getAttribute('class') || ''
            ))
        );
        const sessionScopeLabels = cardLabels.filter(value =>
          value && sessionHints.some(hint => value.includes(hint))
        );
        const requestIdentity = approvalRequestIdentity(candidate.button);
        return {
          ok: true,
          found: true,
          candidates: candidates.length,
          candidateLabels: candidates.map(item => item.label),
          selectedLabel: candidate.label,
          cardButtonLabels: cardLabels.filter(Boolean),
          sessionScopeLabels,
          menuTriggerLabels: menuTriggers.map(label).filter(Boolean),
          menuTriggerCount: menuTriggers.length,
          cardFingerprint: fingerprint(requestIdentity
            ? `request:${requestIdentity}`
            : `card:${cardText}`),
          requestIdentityAvailable: !!requestIdentity,
          unlabeledControlCount: nonDecisionControls.filter(button => !label(button)).length
        };
      }
      container = container.parentElement;
    }

    return {
      ok: true,
      found: true,
      candidates: candidates.length,
      candidateLabels: candidates.map(item => item.label),
      selectedLabel: candidate.label,
      cardButtonLabels: [],
      sessionScopeLabels: [],
      menuTriggerLabels: [],
      menuTriggerCount: 0,
      cardFingerprint: fingerprint(`label:${candidate.label}`),
      requestIdentityAvailable: false,
      unlabeledControlCount: 0
    };
  })()
  """#
}

func autoApproveDedicatedAuthorizationJS() -> String {
  #"""
  (async () => {
    const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
    const normalize = value => (value || '').replace(/[\s\u21b5\u23ce]+/g, ' ').trim().toLowerCase();
    const fingerprint = value => {
      let hash = 2166136261;
      for (const character of value) {
        hash ^= character.codePointAt(0);
        hash = Math.imul(hash, 16777619);
      }
      return `fnv1a32:${(hash >>> 0).toString(16).padStart(8, '0')}`;
    };
    const rendered = element => !!(element && element.isConnected !== false
      && (element.offsetWidth || element.offsetHeight || element.getClientRects().length));
    const visible = element => rendered(element) && !element.disabled;
    const allowed = new Set([
      '\u5b8c\u5168\u8bbf\u95ee', 'full access', 'allow', 'allow once',
      '\u5141\u8bb8', '\u5141\u8bb8\u4e00\u6b21', 'approve', 'approve once',
      'confirm', 'confirm once', '\u786e\u8ba4', '\u786e\u8ba4\u4e00\u6b21',
      '\u540c\u610f', '\u540c\u610f\u4e00\u6b21'
    ]);
    const rejectLabels = new Set([
      'deny', 'reject', 'cancel', 'deny once', 'reject once',
      '\u62d2\u7edd', '\u62d2\u7edd\u4e00\u6b21', '\u4e0d\u5141\u8bb8',
      '\u4e0d\u5141\u8bb8\u4e00\u6b21', '\u53d6\u6d88'
    ]);
    const sessionHints = [
      'this chat', 'this conversation', 'for this chat', 'for this conversation',
      'for this session', 'during this chat', 'always allow in this chat',
      '\u672c\u6b21\u4f1a\u8bdd', '\u8fd9\u6b21\u4f1a\u8bdd',
      '\u6b64\u4f1a\u8bdd', '\u5f53\u524d\u4f1a\u8bdd',
      '\u5728\u6b64\u804a\u5929\u4e2d', '\u672c\u6b21\u804a\u5929',
      '\u59cb\u7ec8\u5141\u8bb8', '\u4f1a\u8bdd\u671f\u95f4'
    ];
    const label = button => normalize(
      button.innerText || button.textContent
        || button.getAttribute('aria-label') || button.getAttribute('title')
    );
    const isSessionScope = value => !!value
      && sessionHints.some(hint => value.includes(hint));
    const approvalRequestIdentity = element => {
      let domNode = element;
      for (let ancestorIndex = 0; ancestorIndex < 15 && domNode; ancestorIndex += 1) {
        const reactKeys = Object.keys(domNode).filter(key =>
          key.startsWith('__reactFiber$') || key.startsWith('__reactProps$')
        );
        for (const reactKey of reactKeys) {
          let reactNode = domNode[reactKey];
          for (let fiberIndex = 0; fiberIndex < 20 && reactNode; fiberIndex += 1) {
            const props = reactNode.memoizedProps || reactNode.pendingProps
              || reactNode.props || reactNode;
            const pluginData = props?.jit_plugin_data || props?.pluginData
              || props?.card?.jit_plugin_data;
            const allowOnce = pluginData?.from_server?.actions?.allow_once;
            const identity = allowOnce?.target_message_id || allowOnce?.targetMessageId
              || props?.target_message_id || props?.targetMessageId;
            if (identity) return String(identity);
            reactNode = reactNode.return;
          }
        }
        domNode = domNode.parentElement;
      }
      return '';
    };
    const approvalCardFingerprint = button => {
      let card = button?.parentElement;
      for (let index = 0; index < 15 && card; index += 1) {
        const cardButtons = [...card.querySelectorAll('button, a, [role="button"]')]
          .filter(visible);
        const cardLabels = cardButtons.map(label);
        const cardText = normalize(card.innerText || card.textContent || '');
        if (cardLabels.some(value => rejectLabels.has(value))
            || cardText.includes('allow chatgpt to use')
            || cardText.includes('\u5141\u8bb8 chatgpt \u4f7f\u7528')) {
          const requestIdentity = approvalRequestIdentity(button);
          return fingerprint(requestIdentity
            ? `request:${requestIdentity}`
            : `card:${cardText}`);
        }
        card = card.parentElement;
      }
      return '';
    };
    const dispatchPointerClick = candidate => {
      const rect = candidate.getBoundingClientRect?.();
      const clientX = rect ? rect.left + Math.min(12, Math.max(1, rect.width / 2)) : 1;
      const clientY = rect ? rect.top + Math.min(12, Math.max(1, rect.height / 2)) : 1;
      const pressed = {
        bubbles: true, cancelable: true, composed: true,
        button: 0, buttons: 1, clientX, clientY
      };
      candidate.dispatchEvent(new PointerEvent('pointerdown', {
        ...pressed, pointerId: 1, pointerType: 'mouse', isPrimary: true
      }));
      candidate.dispatchEvent(new MouseEvent('mousedown', pressed));
      candidate.dispatchEvent(new PointerEvent('pointerup', {
        ...pressed, buttons: 0, pointerId: 1, pointerType: 'mouse', isPrimary: true
      }));
      candidate.dispatchEvent(new MouseEvent('mouseup', { ...pressed, buttons: 0 }));
      candidate.dispatchEvent(new MouseEvent('click', { ...pressed, buttons: 0 }));
    };
    const confirmCardClosed = async candidate => {
      const expectedFingerprint = approvalCardFingerprint(candidate);
      let stableMissingSamples = 0;
      for (let index = 0; index < 40; index += 1) {
        await sleep(100);
        const matchingRequestStillRendered = expectedFingerprint && [...document.querySelectorAll('button')]
          .filter(visible)
          .filter(button => allowed.has(label(button)))
          .some(button => approvalCardFingerprint(button) === expectedFingerprint);
        if (!matchingRequestStillRendered) {
          stableMissingSamples += 1;
          if (stableMissingSamples >= 5) return true;
        } else {
          stableMissingSamples = 0;
        }
      }
      return false;
    };
    const priority = new Map([
      ['allow', 0], ['\u5141\u8bb8', 0], ['approve', 0], ['\u540c\u610f', 0],
      ['confirm', 0], ['\u786e\u8ba4', 0], ['allow once', 1],
      ['\u5141\u8bb8\u4e00\u6b21', 1], ['approve once', 1],
      ['\u540c\u610f\u4e00\u6b21', 1], ['confirm once', 1],
      ['\u786e\u8ba4\u4e00\u6b21', 1], ['full access', 20],
      ['\u5b8c\u5168\u8bbf\u95ee', 20]
    ]);
    const candidates = [...document.querySelectorAll('button')]
      .filter(visible)
      .map((button, index) => ({ button, index, label: label(button) }))
      .filter(candidate => allowed.has(candidate.label))
      .sort((left, right) =>
        (priority.get(left.label) ?? 10) - (priority.get(right.label) ?? 10)
          || left.index - right.index
      );
    const candidateLabels = candidates.map(candidate => candidate.label);
    const candidate = candidates[0];
    if (!candidate) {
      return { ok: true, clicked: false, confirmed: false, candidateLabels };
    }

    let card = candidate.button.parentElement;
    let cardButtons = [];
    for (let index = 0; index < 15 && card; index += 1) {
      cardButtons = [...card.querySelectorAll('button, a, [role="button"]')]
        .filter(visible);
      const cardLabels = cardButtons.map(label);
      const cardText = normalize(card.innerText || card.textContent || '');
      if (cardLabels.some(value => rejectLabels.has(value))
          || cardText.includes('allow chatgpt to use')
          || cardText.includes('\u5141\u8bb8 chatgpt \u4f7f\u7528')) {
        break;
      }
      card = card.parentElement;
      cardButtons = [];
    }

    const sessionControl = cardButtons.find(button =>
      button !== candidate.button && isSessionScope(label(button))
    ) || cardButtons.find(button => {
      if (button === candidate.button) return false;
      const value = label(button);
      return !allowed.has(value) && !rejectLabels.has(value) && (
        button.getAttribute('aria-haspopup') === 'menu'
          || button.getAttribute('aria-expanded') !== null
          || /menu|dropdown|chevron|more/.test(normalize(
            button.getAttribute('data-testid') || button.getAttribute('data-slot')
              || button.getAttribute('class') || ''
          ))
      );
    });

    if (sessionControl) {
      const menuTriggerLabel = label(sessionControl);
      try {
        dispatchPointerClick(sessionControl);
      } catch (error) {
        return {
          ok: false, clicked: false, confirmed: false,
          strategy: 'session-scope', label: menuTriggerLabel, candidateLabels,
          error: String(error?.message || error || 'session_scope_menu_click_failed')
        };
      }
      let menuCandidates = [];
      for (let index = 0; index < 40; index += 1) {
        await sleep(100);
        if (!candidate.button.isConnected || !rendered(candidate.button)) {
          return {
            ok: true, clicked: true, confirmed: true,
            strategy: 'session-scope-direct', label: menuTriggerLabel,
            menuTriggerLabel, candidateLabels
          };
        }
        const menuItems = [...document.querySelectorAll(
          '[role="menuitem"], [role="menuitemradio"], [role="option"], '
            + '[role="menu"] button, [role="listbox"] button, '
            + '[data-radix-menu-content] button, '
            + '[data-radix-popper-content-wrapper] button'
        )].filter(item => item !== sessionControl && visible(item));
        menuCandidates = menuItems.map(label).filter(Boolean).slice(-30);
        const sessionOption = menuItems.find(item => isSessionScope(label(item)));
        if (!sessionOption) continue;
        const sessionScopeLabel = label(sessionOption);
        try {
          dispatchPointerClick(sessionOption);
        } catch (error) {
          return {
            ok: false, clicked: true, confirmed: false,
            strategy: 'session-scope', label: sessionScopeLabel,
            menuTriggerLabel, candidateLabels, menuCandidates,
            error: String(error?.message || error || 'session_scope_option_click_failed')
          };
        }
        const confirmed = await confirmCardClosed(candidate.button);
        return {
          ok: confirmed, clicked: true, confirmed,
          strategy: 'session-scope', label: sessionScopeLabel,
          menuTriggerLabel, sessionScopeLabel, candidateLabels, menuCandidates,
          error: confirmed ? null : 'session_scope_approval_not_confirmed'
        };
      }
      return {
        ok: false, clicked: true, confirmed: false,
        strategy: 'session-scope', label: menuTriggerLabel,
        menuTriggerLabel, candidateLabels, menuCandidates,
        error: 'session_scope_option_not_found'
      };
    }

    try {
      dispatchPointerClick(candidate.button);
    } catch (error) {
      return {
        ok: false, clicked: false, confirmed: false,
        strategy: 'single-approval', label: candidate.label, candidateLabels,
        error: String(error?.message || error || 'approval_click_failed')
      };
    }
    const confirmed = await confirmCardClosed(candidate.button);
    return {
      ok: confirmed, clicked: true, confirmed,
      strategy: 'single-approval', label: candidate.label, candidateLabels,
      error: confirmed ? null : 'approval_click_not_confirmed'
    };
  })()
  """#
}

func prepareNewChatTarget(
  port: Int,
  targetId: String,
  timeout: TimeInterval = 4.0,
  allowBlankConversationReuse: Bool = false
) -> [String: Any]? {
  // First wait for the app bundle/composer. Target.createTarget can expose a
  // static startup shell until its explicit Page.navigate has completed.
  func confirmedChatSelection(_ result: [String: Any]?) -> Bool {
    guard result?["ok"] as? Bool == true else { return false }
    return result?["alreadySelected"] as? Bool == true
  }
  var chatModeConfirmed = confirmedChatSelection(cdpValue(
    port: port,
    targetId: targetId,
    expression: clickChatJS(),
    timeout: timeout
  ))
  var baseline: [String: Any]?
  for _ in 0..<40 {
    baseline = cdpValue(
      port: port,
      targetId: targetId,
      expression: prepareBackgroundChatJS(
        newChat: false,
        confirmedChatMode: chatModeConfirmed
      ),
      timeout: timeout
    )
    if baseline?["ok"] as? Bool == true { break }
    if baseline?["error"] as? String == "not_chat_surface" {
      chatModeConfirmed = confirmedChatSelection(cdpValue(
        port: port,
        targetId: targetId,
        expression: clickChatJS(),
        timeout: timeout
      )) || chatModeConfirmed
    }
    Thread.sleep(forTimeInterval: 0.25)
  }
  guard let baseline,
        baseline["ok"] as? Bool == true else { return nil }
  let previousConversationId = baseline["conversationId"] as? String
  let baselineWasBlank = (baseline["messageCount"] as? Int ?? 1) == 0 &&
    (baseline["inputTextLength"] as? Int ?? 1) == 0
  if allowBlankConversationReuse && baselineWasBlank {
    var stableBlankSamples = 0
    for _ in 0..<12 {
      let current = cdpValue(
        port: port,
        targetId: targetId,
        expression: prepareBackgroundChatJS(
          newChat: false,
          confirmedChatMode: chatModeConfirmed
        ),
        timeout: timeout
      )
      let blankAndReady = current?["ok"] as? Bool == true
        && (current?["messageCount"] as? Int ?? 1) == 0
        && (current?["inputTextLength"] as? Int ?? 1) == 0
      stableBlankSamples = blankAndReady ? stableBlankSamples + 1 : 0
      if stableBlankSamples >= 3 {
        var result = current ?? [:]
        result["newChatClicked"] = false
        result["blankConversationReused"] = true
        result["stableSamples"] = stableBlankSamples
        return result
      }
      Thread.sleep(forTimeInterval: 0.15)
    }
  }
  guard let clicked = cdpValue(
    port: port,
    targetId: targetId,
    expression: clickNewChatJS(),
    timeout: timeout
  ), clicked["ok"] as? Bool == true else { return nil }
  let previous = clicked["previousConversationId"] as? String ?? previousConversationId

  var stableConversationId: String?
  var stableSamples = 0
  for _ in 0..<80 {
    let prepared = cdpValue(
      port: port,
      targetId: targetId,
      expression: prepareBackgroundChatJS(
        newChat: false,
        confirmedChatMode: chatModeConfirmed
      ),
      timeout: timeout
    )
    if prepared?["ok"] as? Bool == true {
      let conversationId = prepared?["conversationId"] as? String ?? ""
      let changed = (previous?.isEmpty != false && !conversationId.isEmpty) || 
                    (previous?.isEmpty == false && conversationId != previous)
      let blankConversation = allowBlankConversationReuse &&
        baselineWasBlank &&
        (prepared?["messageCount"] as? Int ?? 1) == 0
      // The desktop renderer intentionally keeps a virtualized fallback turn
      // from the previous Chat in the DOM after switching. The portal id and
      // composer are authoritative; requiring zero message nodes would reject
      // a correctly created blank Chat forever.
      let composerReady = (prepared?["inputTextLength"] as? Int ?? 1) == 0
      let candidateReady = composerReady &&
        (changed || blankConversation)
      if candidateReady && stableConversationId == conversationId {
        stableSamples += 1
      } else if candidateReady {
        stableConversationId = conversationId
        stableSamples = 1
      } else {
        stableConversationId = nil
        stableSamples = 0
      }
      // React updates the portal conversation id before it finishes replacing
      // the old message tree and composer. Require several identical blank
      // observations so task B cannot type into task A's transitioning view.
      if stableSamples >= 3 {
        var result = prepared ?? [:]
        result["newChatClicked"] = true
        result["stableSamples"] = stableSamples
        return result
      }
    }
    Thread.sleep(forTimeInterval: 0.25)
  }
  return nil
}

@discardableResult
func ensureHiddenChatTarget(
  _ state: inout PluginState,
  newChat: Bool = false,
  conversationId: String? = nil
) -> [String: Any]? {
  let port = hiddenChatPort(state)
  let profilePath = configuredHiddenChatProfilePath()
    ?? state.backgroundProfilePath
    ?? hiddenChatProfilePath()
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
      if let codexHomePath = state.backgroundCodexHomePath {
        var environment = ProcessInfo.processInfo.environment
        environment["CODEX_HOME"] = codexHomePath
        launcher.environment = environment
      }
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
  let initialChatSelection = cdpValue(
    port: port,
    targetId: targetId,
    expression: clickChatJS(),
    timeout: 4.0
  )
  var chatModeConfirmed = initialChatSelection?["ok"] as? Bool == true
    && initialChatSelection?["alreadySelected"] as? Bool == true

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
    prepared = prepareNewChatTarget(port: port, targetId: targetId, allowBlankConversationReuse: true)
  } else {
    var current: [String: Any]?
    for _ in 0..<40 {
      current = cdpValue(
        port: port,
        targetId: targetId,
        expression: prepareBackgroundChatJS(
          newChat: false,
          conversationId: conversationId,
          confirmedChatMode: chatModeConfirmed
        ),
        timeout: 4.0
      )
      if current?["ok"] as? Bool == true { break }
      if current?["error"] as? String == "not_chat_surface" {
        let retrySelection = cdpValue(
          port: port,
          targetId: targetId,
          expression: clickChatJS(),
          timeout: 4.0
        )
        chatModeConfirmed = chatModeConfirmed
          || (retrySelection?["alreadySelected"] as? Bool == true)
      }
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

  if !runningOnGitHubActions(),
     queueTargetRuntimeState(
       port: port,
       targetId: targetId,
       refreshLifecycle: false
     ) != .hidden {
    state.lastError = "background_chat_visibility_not_hidden"
    return [
      "ok": false,
      "errorCode": "background_chat_visibility_not_hidden",
      "message": "专用 ChatGPT 页面未保持隐藏；已拒绝启动，避免影响当前可见页面。",
      "backgroundOnly": true,
      "workerUsed": false,
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

func keepApprovalBackgroundEndpointAlive(_ state: inout PluginState) {
  guard let port = state.backgroundAppPort,
        let targetId = state.backgroundChatTargetId,
        let target = CDPClient.fetchTargets(portOverride: port).first(where: {
          $0["id"] as? String == targetId
        }),
        let wsURL = target["webSocketDebuggerUrl"] as? String else {
    // Locally, a missing endpoint can mean the user intentionally quit the
    // plugin-owned ChatGPT instance. Respect that decision and require an
    // explicit start instead of reopening an app behind the user's back.
    state.backgroundChatTargetId = nil
    if !runningOnGitHubActions() {
      state.enabled = false
      state.lastError = "background_chat_closed_requires_restart"
      return
    }
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

func scanIPC(_ state: inout PluginState) -> [String: Any]? {
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
        // Handle at most one authorization request per watcher tick. The
        // native rate limiter persists the decision before the next scan.
        break;
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
    let targetId = endpoint.target["id"] as? String ?? "unknown-target"
    var approvalDetection: [String: Any]?
    var approvalScreenshotPath: String?
    if let detectionEval = CDPClient.evaluate(
          wsURLString: wsURL,
          expression: detectDedicatedAuthorizationJS()
        ),
       let detectionResult = detectionEval["result"] as? [String: Any],
       let detectionValue = ((detectionResult["result"] as? [String: Any])?["value"]
         ?? detectionResult["value"]) as? [String: Any],
       detectionValue["found"] as? Bool == true {
      approvalDetection = detectionValue
      approvalScreenshotPath = captureHiddenChatScreenshot(
        port: endpoint.port,
        targetId: targetId,
        label: "approval-watcher-before"
      )
      queueTrace(
        "task=approval-watcher stage=approval-ipc-detected strategy=per-card "
          + "target=\(targetId) selected=\(detectionValue["selectedLabel"] as? String ?? "none") "
          + "screenshot=\(approvalScreenshotPath ?? "none") "
          + approvalDetectionTraceFields(detectionValue)
      )
    }
    if let fingerprint = approvalFingerprint(approvalDetection) {
      let currentDate = Date()
      if (state.handledApprovalFingerprints ?? []).contains(fingerprint) {
        let repeatedFor = state.lastAutomaticApprovalFingerprint == fingerprint
          ? state.lastAutomaticApprovalAt
            .flatMap(isoFormatter.date(from:))
            .map { currentDate.timeIntervalSince($0) }
          : nil
        totalCandidates += 1
        if let repeatedFor, repeatedFor >= duplicateApprovalGraceSeconds {
          state.enabled = false
          state.lastError = "approval_duplicate_circuit_open"
          totalBlocked += 1
          queueTrace(
            "task=approval-watcher stage=approval-ipc-blocked "
              + "reason=duplicate fingerprint=\(fingerprint) age=\(Int(repeatedFor))"
          )
        } else {
          totalPending += 1
          state.lastError = "approval_duplicate_suppressed"
          queueTrace(
            "task=approval-watcher stage=approval-ipc-skipped "
              + "reason=duplicate fingerprint=\(fingerprint)"
          )
        }
        continue
      }
      let recentApprovals = prunedAutomaticApprovalTimestamps(
        state.automaticApprovalTimestamps,
        now: currentDate
      )
      state.automaticApprovalTimestamps = recentApprovals
      if recentApprovals.count >= maxAutomaticApprovalsPerWindow {
        state.enabled = false
        state.lastError = "approval_rate_circuit_open"
        totalCandidates += 1
        totalBlocked += 1
        queueTrace(
          "task=approval-watcher stage=approval-ipc-blocked "
            + "reason=rate count=\(recentApprovals.count) "
            + "window=\(Int(automaticApprovalWindowSeconds))"
        )
        continue
      }
    }
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
    if a > 0, let fingerprint = approvalFingerprint(approvalDetection) {
      recordHandledApprovalFingerprint(
        fingerprint,
        fingerprints: &state.handledApprovalFingerprints,
        timestamps: &state.automaticApprovalTimestamps,
        lastFingerprint: &state.lastAutomaticApprovalFingerprint,
        lastApprovedAt: &state.lastAutomaticApprovalAt,
        now: Date()
      )
    }

    if approvalDetection != nil || a > 0 || b > 0 {
      queueTrace(
        "task=approval-watcher stage=approval-ipc-result strategy=per-card "
          + "target=\(targetId) approved=\(a) pending=\(p) blocked=\(b) unmatched=\(u) "
          + "internalActions=\(internalActions) domEvents=\(domEvents) "
          + "screenshot=\(approvalScreenshotPath ?? "none") "
          + approvalDetectionTraceFields(approvalDetection)
      )
      if approvalDetection != nil && a == 0 {
        let afterPath = captureHiddenChatScreenshot(
          port: endpoint.port,
          targetId: targetId,
          label: "approval-watcher-after"
        )
        queueTrace(
          "task=approval-watcher stage=approval-ipc-unconfirmed strategy=per-card "
            + "target=\(targetId) beforeScreenshot=\(approvalScreenshotPath ?? "none") "
            + "afterScreenshot=\(afterPath ?? "none")"
        )
      }
    }

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
    if state.enabled { state.lastError = nil }
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
