import ApplicationServices
import Cocoa
import Darwin
import Foundation
import SystemConfiguration

func loadedApprovalTargets(_ state: PluginState) -> [CDPApprovalTarget] {
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

func cdpValue(
  wsURLString: String,
  expression: String,
  timeout: TimeInterval = 5.0
) -> [String: Any]? {
  guard let response = CDPClient.evaluate(
    wsURLString: wsURLString,
    expression: expression,
    timeout: timeout
  ), let outer = response["result"] as? [String: Any] else { return nil }
  if let value = (outer["result"] as? [String: Any])?["value"] as? [String: Any] {
    return sanitizeJSONValue(value) as? [String: Any]
  }
  if let value = outer["value"] as? [String: Any] {
    return sanitizeJSONValue(value) as? [String: Any]
  }
  return nil
}

func cdpValuePersistent(
  wsURLString: String,
  expression: String,
  timeout: TimeInterval = 5.0
) -> [String: Any]? {
  queueTrace("task=approval-watcher stage=approval-cdp-wrapper-enter")
  let response = CDPClient.evaluatePersistent(
    wsURLString: wsURLString,
    expression: expression,
    timeout: timeout
  )
  queueTrace(
    "task=approval-watcher stage=approval-cdp-wrapper-return response=\(response != nil)"
  )
  guard let response,
        let outer = response["result"] as? [String: Any] else { return nil }
  if let exception = outer["exceptionDetails"] {
    queueTrace(
      "task=approval-watcher stage=approval-cdp-wrapper-exception "
        + String(String(describing: exception).prefix(1200))
    )
  }
  if let inner = outer["result"] as? [String: Any] {
    queueTrace(
      "task=approval-watcher stage=approval-cdp-wrapper-result "
        + "type=\(inner["type"] as? String ?? "none") "
        + "subtype=\(inner["subtype"] as? String ?? "none") "
        + "hasValue=\(inner["value"] != nil)"
    )
  }
  if let value = (outer["result"] as? [String: Any])?["value"] as? [String: Any] {
    return sanitizeJSONValue(value) as? [String: Any]
  }
  if let value = outer["value"] as? [String: Any] {
    return sanitizeJSONValue(value) as? [String: Any]
  }
  return nil
}

func cdpWebSocketURL(port: Int, targetId: String) -> String? {
  CDPClient.fetchTargets(portOverride: port)
    .first(where: { $0["id"] as? String == targetId })?["webSocketDebuggerUrl"] as? String
}

func approvalCoordinate(_ value: Any?) -> Double? {
  if let number = value as? NSNumber { return number.doubleValue }
  if let number = value as? Double { return number }
  if let number = value as? Int { return Double(number) }
  return nil
}

func approvalPoint(_ value: Any?) -> (x: Double, y: Double)? {
  guard let point = value as? [String: Any],
        let x = approvalCoordinate(point["x"]),
        let y = approvalCoordinate(point["y"]) else { return nil }
  return (x, y)
}

func approvalRect(_ value: Any?) -> (left: Double, top: Double, width: Double, height: Double)? {
  guard let rect = value as? [String: Any],
        let left = approvalCoordinate(rect["left"]),
        let top = approvalCoordinate(rect["top"]),
        let width = approvalCoordinate(rect["width"]),
        let height = approvalCoordinate(rect["height"]),
        width > 0, height > 0 else { return nil }
  return (left, top, width, height)
}

func nativeApprovalArrowKey(
  port: Int,
  targetId: String,
  point: (x: Double, y: Double)?,
  wsURLString: String,
  label: String?
) -> Bool {
  let wsURL = wsURLString
  let x = String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), point?.x ?? 0)
  let y = String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), point?.y ?? 0)
  let pointAvailableLiteral = point == nil ? "false" : "true"
  let requestedLabelLiteral = jsonStringLiteral(label ?? "")
  let directKeyExpression = #"""
  (() => {
    const normalize = value => String(value || '')
      .replace(/[\s\u21b5\u00a0]+/g, ' ').trim().toLowerCase()
      .replace(/\s*(?:enter|return|⏎|↵)$/i, '').trim();
    const requested = normalize(#(requestedLabelLiteral));
    const labelOf = element => normalize(
      element?.getAttribute?.('aria-label')
        || element?.getAttribute?.('title')
        || element?.getAttribute?.('data-label')
        || element?.innerText
        || element?.textContent
        || ''
    );
    const matchesRequested = element => {
      if (!requested) return true;
      const value = labelOf(element);
      return value === requested || value.includes(requested) || requested.includes(value);
    };
    const pointAvailable = #(pointAvailableLiteral);
    const hit = pointAvailable ? document.elementFromPoint(#(x), #(y)) : null;
    const hitTarget = hit?.closest?.(
      '[aria-haspopup], [aria-expanded], [role="button"], button'
    ) || hit;
    const labelledTargets = [...document.querySelectorAll?.(
      'button, [role="button"], [aria-haspopup], [aria-expanded]'
    ) || []].filter(element => matchesRequested(element));
    const target = hitTarget && matchesRequested(hitTarget)
      ? hitTarget
      : labelledTargets.find(element =>
        element.getAttribute?.('aria-haspopup') !== null
          || element.getAttribute?.('aria-expanded') !== null
      ) || labelledTargets[0];
    if (!target || typeof target.dispatchEvent !== 'function') {
      return { ok: false, error: 'approval_key_target_missing' };
    }
    try { target.focus({ preventScroll: true }); } catch (_) {}
    const eventOptions = {
      key: 'ArrowDown', code: 'ArrowDown', keyCode: 40, which: 40,
      bubbles: true, cancelable: true, composed: true
    };
    setTimeout(() => {
      try {
        target.dispatchEvent(new KeyboardEvent('keydown', eventOptions));
        target.dispatchEvent(new KeyboardEvent('keyup', eventOptions));
      } catch (_) {}
    }, 0);
    return {
      ok: true,
      mode: 'component-dom-key-event-queued',
      tag: target.tagName || '',
      label: labelOf(target),
      expanded: target.getAttribute?.('aria-expanded') ?? null
    };
  })()
  """#
  return cdpValuePersistent(
    wsURLString: wsURL,
    expression: directKeyExpression,
    timeout: 2.5
  )?["ok"] as? Bool == true
}

func nativeApprovalComponentActionResult(
  port: Int,
  targetId: String,
  point: (x: Double, y: Double)?,
  action: String,
  wsURLString: String,
  label: String?
) -> [String: Any]? {
  queueTrace("task=approval-watcher stage=approval-native-component-function-enter action=\(action)")
  let wsURL = wsURLString
  queueTrace("task=approval-watcher stage=approval-native-component-url-ready action=\(action)")
  let x = String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), point?.x ?? 0)
  let y = String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), point?.y ?? 0)
  let pointAvailableLiteral = point == nil ? "false" : "true"
  queueTrace("task=approval-watcher stage=approval-native-component-coordinates-ready action=\(action)")
  let requestedLabelLiteral = jsonStringLiteral(label ?? "")
  let actionLiteral = jsonStringLiteral(action)
  queueTrace("task=approval-watcher stage=approval-native-component-labels-ready action=\(action)")
  if action == "trigger" || action == "option" {
    queueTrace("task=approval-watcher stage=approval-native-component-expression-begin action=\(action)")
    let directComponentExpression = #"""
    (() => {
      const action = \#(actionLiteral);
      const requested = String(\#(requestedLabelLiteral) || '')
        .replace(/[\s\u21b5\u00a0⏎↵]+/g, ' ').trim().toLowerCase();
      const pointAvailable = \#(pointAvailableLiteral);
      const selector = [
        'button', '[role="button"]', '[role="menuitem"]',
        '[role="menuitemradio"]', '[role="option"]',
        '[data-radix-collection-item]'
      ].join(',');
      const labelOf = element => String(
        element?.getAttribute?.('aria-label')
          || element?.getAttribute?.('title')
          || element?.getAttribute?.('data-label')
          || element?.innerText
          || element?.textContent
          || ''
      ).replace(/[\s\u21b5\u00a0⏎↵]+/g, ' ').trim().toLowerCase();
      const parentOf = element => element?.parentElement
        || element?.parentNode?.host || null;
      const connected = element => !!(element && element.isConnected !== false);
      const structuralMarker = element => String([
        element?.getAttribute?.('data-testid'), element?.getAttribute?.('data-slot'),
        element?.getAttribute?.('data-state'), element?.getAttribute?.('class'),
        element?.getAttribute?.('id')
      ].filter(Boolean).join(' ')).toLowerCase();
      const hasMenuStructure = element => !!(element && (
        element.getAttribute?.('aria-haspopup') !== null
        || element.getAttribute?.('aria-expanded') !== null
        || /menu|dropdown|chevron|caret|arrow|more|overflow|popover|split|disclosure/.test(
          structuralMarker(element)
        )
      ));
      const surfaceFor = element => {
        let node = element;
        for (let depth = 0; depth < 12 && node; depth += 1) {
          const role = String(node.getAttribute?.('role') || '').toLowerCase();
          if (['menu', 'listbox', 'dialog'].includes(role)
              || node.getAttribute?.('aria-modal') === 'true'
              || node.getAttribute?.('data-state') === 'open'
              || /menu|dropdown|popover|listbox|select|command/.test(structuralMarker(node))) {
            return node;
          }
          node = parentOf(node);
        }
        return null;
      };
      const isAllow = element => /allow|approve|confirm|authorize|authorise|permit|grant|\u5141\u8bb8|\u540c\u610f|\u786e\u8ba4|\u51c6\u8bb8/.test(labelOf(element));
      const matchesRequested = element => {
        if (!requested) return true;
        const value = labelOf(element);
        return value === requested || value.includes(requested);
      };
      const query = (root, querySelector) => {
        try { return [...(root?.querySelectorAll?.(querySelector) || [])]; }
        catch (_) { return []; }
      };
      const collect = root => {
        const output = query(root, selector);
        for (const node of query(root, '*')) {
          if (node.shadowRoot) output.push(...collect(node.shadowRoot));
          if (node.tagName?.toLowerCase() === 'iframe') {
            try { if (node.contentDocument) output.push(...collect(node.contentDocument)); }
            catch (_) {}
          }
        }
        return output;
      };
      const allControls = [...new Set(collect(document))]
        .filter(element => connected(element) && !element.disabled
          && element.getAttribute?.('aria-disabled') !== 'true');
      const approvalControls = allControls
        .filter(element => isAllow(element) || matchesRequested(element));
      const selectedApproval = approvalControls
        .sort((left, right) => {
          const score = element => (matchesRequested(element) ? 1000 : 0)
            + (isAllow(element) ? 200 : 0)
            + (hasMenuStructure(element) ? 100 : 0)
            - Math.min(80, labelOf(element).length);
          return score(right) - score(left);
        })[0] || null;
      const rootsFor = element => {
        const roots = [];
        let node = element;
        for (let depth = 0; depth < 18 && node; depth += 1) {
          roots.push(node);
          node = parentOf(node);
        }
        return roots;
      };
      const contains = (root, element) => !!(root && element
        && (root === element || root.contains?.(element)));
      const componentRoot = selectedApproval
        ? rootsFor(selectedApproval).find(root =>
          query(root, selector).some(element => hasMenuStructure(element)))
        : null;
      const componentControls = componentRoot
        ? [...new Set([
          ...(componentRoot.matches?.(selector) ? [componentRoot] : []),
          ...query(componentRoot, selector)
        ])].filter(element => connected(element) && !element.disabled
          && element.getAttribute?.('aria-disabled') !== 'true')
        : [];
      let target = null;
      if (action === 'trigger') {
        target = componentControls
          .filter(element => hasMenuStructure(element))
          .sort((left, right) => {
            const score = element => (element === selectedApproval ? 500 : 0)
              + (isAllow(element) ? 100 : 0)
              + (matchesRequested(element) ? 50 : 0)
              + (!isAllow(element) ? 25 : 0);
            return score(right) - score(left);
          })[0] || null;
        if (!target && selectedApproval && hasMenuStructure(selectedApproval)) {
          target = selectedApproval;
        }
      } else {
        const surfaces = [...new Set([
          ...query(document, '[role="menu"], [role="listbox"], [role="dialog"], '
            + '[data-state="open"], [data-radix-menu-content], '
            + '[data-radix-popper-content-wrapper], [data-slot*="menu" i]')
        ])].filter(connected);
        const candidates = surfaces.flatMap(surface => [
          ...(surface.matches?.(selector) ? [surface] : []),
          ...query(surface, selector)
        ]).filter((candidate, index, all) =>
          all.indexOf(candidate) === index
            && connected(candidate)
            && surfaceFor(candidate)
            && matchesRequested(candidate)
        );
        target = candidates.sort((left, right) => {
            const score = element => (labelOf(element) === requested ? 1000 : 0)
              + (['menuitem', 'menuitemradio', 'option'].includes(
                String(element.getAttribute?.('role') || '').toLowerCase()
              ) ? 100 : 0)
              - Math.min(80, labelOf(element).length);
            return score(right) - score(left);
          })[0] || null;
      }
      if (!target || typeof target.dispatchEvent !== 'function') {
        return {
          ok: false,
          action,
          error: action === 'trigger'
            ? 'approval_trigger_component_missing'
            : 'session_option_component_missing'
        };
      }
      const ownKeys = node => {
        try { return Object.getOwnPropertyNames(node); } catch (_) { return []; }
      };
      const propsFrom = source => source?.memoizedProps || source?.pendingProps
        || source?.props || source || {};
      const handlers = [];
      const seenHandlers = new Set();
      const sameAllowControl = action === 'trigger' && isAllow(target);
      const handlerNames = action === 'trigger'
        ? (sameAllowControl
          ? ['onKeyDown', 'onPointerDown']
          : ['onClick', 'onPointerDown', 'onKeyDown'])
        : ['onClick', 'onSelect', 'onPointerUp', 'onPointerDown', 'onKeyDown'];
      const inspectSource = (source, owner, fiberDepth) => {
        const props = propsFrom(source);
        for (const name of handlerNames) {
          const handler = props?.[name];
          if (typeof handler !== 'function' || seenHandlers.has(handler)) continue;
          seenHandlers.add(handler);
          handlers.push({ name, handler, owner, fiberDepth });
        }
      };
      const inspectNode = node => {
        for (const key of ownKeys(node)) {
          if (key.startsWith('__reactProps$')) inspectSource(node[key], node, 0);
          if (!key.startsWith('__reactFiber$')) continue;
          let fiber = node[key];
          for (let depth = 1; depth < 40 && fiber; depth += 1) {
            inspectSource(fiber, node, depth);
            fiber = fiber.return;
          }
        }
      };
      let node = target;
      for (let depth = 0; depth < 10 && node; depth += 1) {
        inspectNode(node);
        node = parentOf(node);
      }
      // ChatGPT renders the Allow-once control as one split component. The
      // disclosure triangle is not a second DOM button: the component decides
      // whether the click is primary or disclosure from the trailing event
      // coordinates. Dispatch that event inside the live renderer instead of
      // calling click(), which would always grant Allow once.
      if (action === 'trigger' && sameAllowControl && hasMenuStructure(target)) {
        const rect = target.getBoundingClientRect?.();
        const pointUsed = pointAvailable && Number.isFinite(#(x))
          && Number.isFinite(#(y)) && (#(x) > 0 || #(y) > 0);
        const eventX = pointUsed
          ? #(x)
          : rect && rect.width > 0
            ? rect.right - Math.min(8, Math.max(4, rect.width * 0.08))
            : 0;
        const eventY = pointUsed
          ? #(y)
          : rect && rect.height > 0 ? rect.top + rect.height / 2 : 0;
        const hiddenFallback = !rect || rect.width <= 0 || rect.height <= 0;
        let clickEvent = null;
        try {
          if (typeof MouseEvent === 'function') {
            clickEvent = new MouseEvent('click', {
              bubbles: true,
              cancelable: true,
              composed: true,
              view: window,
              detail: 1,
              button: 0,
              buttons: 0,
              clientX: eventX,
              clientY: eventY,
              screenX: eventX,
              screenY: eventY
            });
          }
        } catch (_) {}
        if (!clickEvent) {
          try {
            clickEvent = document.createEvent('MouseEvents');
            clickEvent.initMouseEvent(
              'click', true, true, window, 1, eventX, eventY, eventX, eventY,
              false, false, false, false, 0, target
            );
          } catch (error) {
            return {
              ok: false,
              action,
              targetTag: target.tagName || '',
              targetLabel: labelOf(target),
              error: 'split_disclosure_event_create_failed:'
                + String(error?.message || error || 'unknown')
            };
          }
        }
        setTimeout(() => {
          try { target.dispatchEvent(clickEvent); } catch (_) {}
          // A hidden renderer may not have hit-test geometry at all. ArrowDown
          // is the component's non-primary disclosure action in that case.
          if (hiddenFallback) {
            try {
              const options = {
                key: 'ArrowDown', code: 'ArrowDown', keyCode: 40, which: 40,
                bubbles: true, cancelable: true, composed: true
              };
              target.dispatchEvent(new KeyboardEvent('keydown', options));
              target.dispatchEvent(new KeyboardEvent('keyup', options));
            } catch (_) {}
          }
        }, 0);
        return {
          ok: true,
          action,
          mode: 'component-split-disclosure-event-queued',
          targetTag: target.tagName || '',
          targetRole: target.getAttribute?.('role') || '',
          targetLabel: labelOf(target),
          pointUsed: pointUsed || !!rect,
          hiddenFallback
        };
      }
      const targetAtPoint = target;
      const eventBase = {
        target: targetAtPoint,
        currentTarget: target,
        bubbles: true,
        cancelable: true,
        defaultPrevented: false,
        button: 0,
        buttons: action === 'trigger' ? 0 : 1,
        clientX: \#(x),
        clientY: \#(y),
        pageX: \#(x),
        pageY: \#(y),
        preventDefault() { this.defaultPrevented = true; },
        stopPropagation() { this.propagationStopped = true; },
        stopImmediatePropagation() { this.immediatePropagationStopped = true; },
        isPropagationStopped() { return this.propagationStopped === true; },
        isDefaultPrevented() { return this.defaultPrevented === true; },
        persist() {},
        nativeEvent: {
          target: targetAtPoint,
          currentTarget: target,
          button: 0,
          buttons: action === 'trigger' ? 0 : 1,
          clientX: \#(x),
          clientY: \#(y)
        }
      };
      if (handlers.length) {
        const selected = handlers[0];
        const isKey = selected.name === 'onKeyDown';
        const event = isKey
          ? {
              ...eventBase,
              type: 'keydown', key: 'ArrowDown', code: 'ArrowDown',
              keyCode: 40, which: 40, repeat: false, isComposing: false,
              nativeEvent: {
                ...eventBase.nativeEvent,
                type: 'keydown', key: 'ArrowDown', code: 'ArrowDown',
                keyCode: 40, which: 40, repeat: false
              }
            }
          : {
              ...eventBase,
              type: selected.name === 'onSelect'
                ? 'select'
                : selected.name === 'onClick' ? 'click' : 'pointerdown',
              pointerId: 1, pointerType: 'mouse', isPrimary: true,
              nativeEvent: {
                ...eventBase.nativeEvent,
                type: selected.name === 'onSelect'
                  ? 'select'
                  : selected.name === 'onClick' ? 'click' : 'pointerdown',
                pointerId: 1, pointerType: 'mouse', isPrimary: true
              }
            };
        try {
          selected.handler.call(selected.owner, event);
          return {
            ok: true,
            action,
            mode: 'react-handler-invoked',
            handler: selected.name,
            handlerFiberDepth: selected.fiberDepth,
            targetTag: target.tagName || '',
            targetRole: target.getAttribute?.('role') || '',
            targetLabel: labelOf(target),
            pointUsed: pointAvailable
          };
        } catch (error) {
          return {
            ok: false,
            action,
            mode: 'react-handler',
            handler: selected.name,
            targetTag: target.tagName || '',
            targetLabel: labelOf(target),
            error: String(error?.message || error || 'approval_component_handler_failed')
          };
        }
      }
      // A separately rendered disclosure or menu item can still expose the
      // native component activation without a React prop on the exact node.
      // Never call click() on the labelled Allow control for trigger: that is
      // the primary Allow once action, not the session-scope disclosure.
      if (typeof target.click === 'function' && !(action === 'trigger' && sameAllowControl)) {
        try {
          target.click();
          return {
            ok: true,
            action,
            mode: 'component-dom-activation',
            targetTag: target.tagName || '',
            targetRole: target.getAttribute?.('role') || '',
            targetLabel: labelOf(target),
            pointUsed: pointAvailable
          };
        } catch (error) {
          return {
            ok: false,
            action,
            error: String(error?.message || error || 'component_dom_activation_failed')
          };
        }
      }
      return {
        ok: false,
        action,
        handlerNames: handlers.map(item => item.name),
        targetTag: target.tagName || '',
        targetRole: target.getAttribute?.('role') || '',
        targetLabel: labelOf(target),
        error: action === 'trigger'
          ? 'approval_trigger_component_handler_missing'
          : 'session_option_component_handler_missing'
      };
    })()
    """#
    queueTrace("task=approval-watcher stage=approval-native-component-expression-ready action=\(action)")
    queueTrace("task=approval-watcher stage=approval-native-component-probe-begin")
    let componentProbe = cdpValuePersistent(
      wsURLString: wsURL,
      expression: "({ok:true})",
      timeout: 1.0
    )
    queueTrace(
      "task=approval-watcher stage=approval-native-component-probe-return "
        + "found=\(componentProbe != nil)"
    )
    guard componentProbe != nil else {
      return ["ok": false, "action": action, "error": "approval_cdp_probe_failed"]
    }
    queueTrace("task=approval-watcher stage=approval-native-component-eval-begin")
    let componentResult = cdpValuePersistent(
      wsURLString: wsURL,
      expression: directComponentExpression,
      timeout: 2.5
    )
    queueTrace(
      "task=approval-watcher stage=approval-native-component-eval-return "
        + "found=\(componentResult != nil)"
    )
    return componentResult
  }
  let expression = #"""
  (() => {
    const normalize = value => String(value || '')
      .replace(/[\s\u21b5\u00a0\u23ce\u21b5]+/g, ' ')
      .trim().toLowerCase()
      .replace(/\s*(?:enter|return|esc|escape|⏎|↵)$/i, '')
      .replace(/\s+/g, ' ').trim();
    const requested = normalize(\#(requestedLabelLiteral));
    const action = \#(actionLiteral);
    const selector = [
      'button', '[role="button"]', '[role="menuitem"]',
      '[role="menuitemradio"]', '[role="option"]',
      '[data-radix-collection-item]'
    ].join(',');
    const labelOf = element => normalize(
      element?.getAttribute?.('aria-label')
        || element?.getAttribute?.('title')
        || element?.getAttribute?.('data-label')
        || element?.innerText
        || element?.textContent
        || ''
    );
    const parentOf = element => element?.parentElement || element?.parentNode?.host || null;
    const structuralMarker = element => normalize([
      element?.getAttribute?.('data-slot'),
      element?.getAttribute?.('data-state'),
      element?.getAttribute?.('class'),
      element?.getAttribute?.('id')
    ].filter(Boolean).join(' '));
    const menuSurfaceFor = element => {
      let node = element;
      for (let depth = 0; depth < 12 && node; depth += 1) {
        const role = normalize(node.getAttribute?.('role'));
        if (['menu', 'listbox', 'dialog'].includes(role)
            || node.getAttribute?.('aria-modal') === 'true'
            || node.getAttribute?.('data-state') === 'open'
            || /menu|dropdown|popover|listbox|select|command/.test(structuralMarker(node))) {
          return node;
        }
        node = parentOf(node);
      }
      return null;
    };
    const connected = element => !!(element && element.isConnected !== false);
    const matchesRequested = element => {
      if (!requested) return true;
      const value = labelOf(element);
      return value === requested || value.includes(requested);
    };
    const pointHit = document.elementFromPoint(\#(x), \#(y));
    const pointTarget = pointHit?.closest?.(selector)
      || (pointHit?.matches?.(selector) ? pointHit : null);
    const ancestors = element => {
      const result = [];
      let node = element;
      for (let depth = 0; depth < 12 && node; depth += 1) {
        if (node.matches?.(selector)) result.push(node);
        node = parentOf(node);
      }
      return result;
    };
    const menuSurfaces = () => [...new Set([
      ...document.querySelectorAll?.(
        '[role="menu"], [role="listbox"], [role="dialog"], '
          + '[data-state="open"], [data-radix-menu-content], '
          + '[data-radix-popper-content-wrapper], [data-slot*="menu" i]'
      ) || [],
      ...(pointTarget ? [menuSurfaceFor(pointTarget)] : [])
    ])].filter(connected);
    const labelCandidates = () => {
      const roots = action === 'option' ? menuSurfaces() : [];
      const nodes = roots.flatMap(root => [
        root,
        ...(root.querySelectorAll?.(selector) || [])
      ]);
      return nodes.filter((node, index, all) =>
        all.indexOf(node) === index
          && connected(node)
          && (action !== 'option' || !!menuSurfaceFor(node))
          && matchesRequested(node)
      );
    };
    let target = ancestors(pointTarget).find(node => {
      if (!connected(node) || !matchesRequested(node)) return false;
      if (action === 'option') return !!menuSurfaceFor(node);
      const value = labelOf(node);
      return /allow|approve|confirm|authorize|authorise|permit|grant|\u5141\u8bb8|\u540c\u610f|\u786e\u8ba4|\u51c6\u8bb8/.test(value);
    });
    if (!target) target = labelCandidates()[0] || null;
    if (!target) {
      return {
        ok: false,
        action,
        error: action === 'option'
          ? 'session_option_component_missing'
          : 'approval_trigger_component_missing'
      };
    }
    const targetAtPoint = pointHit && target.contains?.(pointHit) ? pointHit : target;
    // The approval card uses one split button: the primary surface invokes
    // Allow once, while the right-edge click opens the scope menu. Dispatch
    // the event inside the renderer so React's delegated listener receives
    // the exact component event; this is not coordinate input through CDP.
    if (action === 'trigger' && typeof target.dispatchEvent === 'function') {
      const clickEvent = new MouseEvent('click', {
        bubbles: true,
        cancelable: true,
        composed: true,
        view: window,
        detail: 1,
        button: 0,
        buttons: 0,
        clientX: \#(x),
        clientY: \#(y),
        screenX: \#(x),
        screenY: \#(y)
      });
      setTimeout(() => {
        try { target.dispatchEvent(clickEvent); } catch (_) {}
      }, 0);
      return {
        ok: true,
        action,
        mode: 'component-dom-click-event-queued',
        targetTag: target.tagName || '',
        targetRole: target.getAttribute?.('role') || '',
        targetLabel: labelOf(target),
        clientX: \#(x),
        clientY: \#(y),
        expanded: target.getAttribute?.('aria-expanded') ?? null
      };
    }
    const ownKeys = node => {
      try { return Object.getOwnPropertyNames(node); } catch (_) { return []; }
    };
    const propsFrom = source => source?.memoizedProps || source?.pendingProps
      || source?.props || source || {};
    const handlers = [];
    const seenHandlers = new Set();
    const inspectSource = (source, owner, fiberDepth) => {
      const props = propsFrom(source);
      const names = action === 'trigger'
        ? ['onKeyDown', 'onPointerDown', 'onClick']
        : ['onClick', 'onPointerUp', 'onPointerDown', 'onKeyDown'];
      for (const name of names) {
        const handler = props?.[name];
        if (typeof handler !== 'function' || seenHandlers.has(handler)) continue;
        seenHandlers.add(handler);
        handlers.push({ name, handler, owner, fiberDepth });
      }
    };
    const inspectNode = node => {
      for (const key of ownKeys(node)) {
        if (key.startsWith('__reactProps$')) inspectSource(node[key], node, 0);
        if (!key.startsWith('__reactFiber$')) continue;
        let fiber = node[key];
        for (let depth = 1; depth < 40 && fiber; depth += 1) {
          inspectSource(fiber, node, depth);
          fiber = fiber.return;
        }
      }
    };
    let node = target;
    for (let depth = 0; depth < 10 && node; depth += 1) {
      inspectNode(node);
      node = parentOf(node);
    }
    const eventBase = {
      target: targetAtPoint,
      currentTarget: target,
      bubbles: true,
      cancelable: true,
      defaultPrevented: false,
      button: 0,
      buttons: action === 'trigger' ? 0 : 1,
      clientX: \#(x),
      clientY: \#(y),
      pageX: \#(x),
      pageY: \#(y),
      preventDefault() { this.defaultPrevented = true; },
      stopPropagation() { this.propagationStopped = true; },
      stopImmediatePropagation() { this.immediatePropagationStopped = true; },
      isPropagationStopped() { return this.propagationStopped === true; },
      isDefaultPrevented() { return this.defaultPrevented === true; },
      persist() {},
      nativeEvent: {
        target: targetAtPoint,
        currentTarget: target,
        button: 0,
        buttons: action === 'trigger' ? 0 : 1,
        clientX: \#(x),
        clientY: \#(y)
      }
    };
    if (handlers.length) {
      const selected = handlers[0];
      const event = action === 'trigger' && selected.name === 'onKeyDown'
        ? {
            ...eventBase,
            type: 'keydown', key: 'ArrowDown', code: 'ArrowDown',
            keyCode: 40, which: 40, repeat: false, isComposing: false,
            nativeEvent: {
              ...eventBase.nativeEvent,
              type: 'keydown', key: 'ArrowDown', code: 'ArrowDown',
              keyCode: 40, which: 40, repeat: false
            }
          }
        : {
            ...eventBase,
            type: selected.name === 'onClick' ? 'click' : 'pointerdown',
            pointerId: 1, pointerType: 'mouse', isPrimary: true,
            nativeEvent: {
              ...eventBase.nativeEvent,
              type: selected.name === 'onClick' ? 'click' : 'pointerdown',
              pointerId: 1, pointerType: 'mouse', isPrimary: true
            }
      };
      try {
        setTimeout(() => {
          try { selected.handler.call(selected.owner, event); } catch (_) {}
        }, 0);
        return {
          ok: true,
          action,
          mode: 'react-handler-queued',
          handler: selected.name,
          handlerFiberDepth: selected.fiberDepth,
          targetTag: target.tagName || '',
          targetRole: target.getAttribute?.('role') || '',
          targetLabel: labelOf(target)
        };
      } catch (error) {
        return {
          ok: false,
          action,
          mode: 'react-handler',
          handler: selected.name,
          targetTag: target.tagName || '',
          targetLabel: labelOf(target),
          error: String(error?.message || error || 'approval_component_handler_failed')
        };
      }
    }
    // A menu item can be a native button without React props. Its exact
    // component has already been bounded by the open menu surface and label;
    // use its native DOM activation instead of any coordinate input.
    if (action === 'option' && typeof target.click === 'function') {
      try {
        setTimeout(() => {
          try { target.click(); } catch (_) {}
        }, 0);
        return {
          ok: true,
          action,
          mode: 'component-dom-activation-queued',
          targetTag: target.tagName || '',
          targetRole: target.getAttribute?.('role') || '',
          targetLabel: labelOf(target)
        };
      } catch (error) {
        return {
          ok: false,
          action,
          error: String(error?.message || error || 'session_option_component_activation_failed')
        };
      }
    }
    return {
      ok: false,
      action,
      handlerNames: handlers.map(item => item.name),
      error: action === 'trigger'
        ? 'approval_trigger_component_handler_missing'
        : 'session_option_component_handler_missing'
    };
  })()
  """#
  return cdpValue(
    wsURLString: wsURL,
    expression: expression,
    timeout: 2.5
  )
}

func sessionScopeComponentProbeJS() -> String {
  #"""
  (() => {
    const normalize = value => String(value || '')
      .replace(/[\s\u21b5\u00a0\u23ce\u21b5]+/g, ' ')
      .trim().toLowerCase()
      .replace(/\s*(?:enter|return|esc|escape|⏎|↵)$/i, '')
      .replace(/\s+/g, ' ').trim();
    const sessionHints = [
      'this chat', 'this conversation', 'for this chat',
      'for this conversation', 'for this session', 'during this chat',
      'always allow in this chat', 'this thread', 'for this thread',
      'conversation only', 'chat only', '本次会话', '这次会话', '此会话',
      '当前会话', '本次对话', '此对话', '当前对话', '仅此会话',
      '始终允许'
    ];
    const isSession = value => {
      const text = normalize(value);
      return !!text && sessionHints.some(hint => text.includes(hint));
    };
    const parentOf = element => element?.parentElement || element?.parentNode?.host || null;
    const marker = element => normalize([
      element?.getAttribute?.('data-slot'),
      element?.getAttribute?.('data-state'),
      element?.getAttribute?.('class'),
      element?.getAttribute?.('id')
    ].filter(Boolean).join(' '));
    const surfaceFor = element => {
      let node = element;
      for (let depth = 0; depth < 12 && node; depth += 1) {
        const role = normalize(node.getAttribute?.('role'));
        if (['menu', 'listbox', 'dialog'].includes(role)
            || node.getAttribute?.('aria-modal') === 'true'
            || node.getAttribute?.('data-state') === 'open'
            || /menu|dropdown|popover|listbox|select|command/.test(marker(node))) {
          return node;
        }
        node = parentOf(node);
      }
      return null;
    };
    const labelOf = element => normalize(
      element?.getAttribute?.('aria-label')
        || element?.getAttribute?.('title')
        || element?.getAttribute?.('data-label')
        || element?.innerText
        || element?.textContent
        || ''
    );
    const surfaces = [...new Set(
      [...document.querySelectorAll?.(
        '[role="menu"], [role="listbox"], [role="dialog"], '
          + '[data-state="open"], [data-radix-menu-content], '
          + '[data-radix-popper-content-wrapper], [data-slot*="menu" i]'
      ) || []]
    )].filter(node => node?.isConnected !== false);
    const selector = [
      '[role="menuitem"]', '[role="menuitemradio"]', '[role="option"]',
      'button', '[data-radix-collection-item]', '[data-slot*="menu" i]'
    ].join(',');
    const options = surfaces.flatMap(surface => [
      ...(surface.querySelectorAll?.(selector) || [])
    ]).filter((node, index, all) =>
      all.indexOf(node) === index
        && node?.isConnected !== false
        && !!surfaceFor(node)
        && isSession(labelOf(node))
    ).sort((left, right) => {
      const leftRect = left.getBoundingClientRect?.();
      const rightRect = right.getBoundingClientRect?.();
      const leftRole = normalize(left.getAttribute?.('role'));
      const rightRole = normalize(right.getAttribute?.('role'));
      const leftScore = (['menuitem', 'menuitemradio', 'option'].includes(leftRole) ? 1000 : 0)
        - ((leftRect?.width || 0) * (leftRect?.height || 0)) / 100;
      const rightScore = (['menuitem', 'menuitemradio', 'option'].includes(rightRole) ? 1000 : 0)
        - ((rightRect?.width || 0) * (rightRect?.height || 0)) / 100;
      return rightScore - leftScore;
    });
    const option = options[0];
    const rect = option?.getBoundingClientRect?.();
    const point = rect ? {
      x: rect.left + rect.width / 2,
      y: rect.top + rect.height / 2
    } : null;
    return option ? {
      ok: false,
      clicked: false,
      confirmed: false,
      strategy: 'session-scope',
      error: 'session_scope_native_option_required',
      sessionScopeLabel: labelOf(option),
      sessionOptionPoint: point,
      sessionOptionRect: rect ? {
        left: rect.left, top: rect.top, width: rect.width, height: rect.height
      } : null
    } : {
      ok: false,
      clicked: false,
      confirmed: false,
      strategy: 'session-scope',
      error: surfaces.length ? 'session_scope_option_not_found' : 'session_scope_menu_not_opened'
    };
  })()
  """#
}

func nativeApprovalDOMClickResult(
  port: Int,
  targetId: String,
  point: (x: Double, y: Double),
  label: String? = nil
) -> [String: Any]? {
  let x = String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), point.x)
  let y = String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), point.y)
  let requestedLabelLiteral = jsonStringLiteral(label ?? "")
  let expression = #"""
  (() => {
    const selector =
      '[role="menuitem"], [role="menuitemradio"], [role="option"], button, '
        + '[data-radix-collection-item], [data-slot*="menu" i]';
    const normalize = value => String(value || '')
      .replace(/[\s\u21b5\u00a0]+/g, ' ').trim().toLowerCase();
    const requested = normalize(\#(requestedLabelLiteral));
    const labelOf = element => normalize(
      element?.getAttribute?.('aria-label')
        || element?.getAttribute?.('title')
        || element?.getAttribute?.('data-label')
        || element?.innerText
        || element?.textContent
        || ''
    );
    const parentOf = element => element?.parentElement || element?.parentNode?.host || null;
    const isMenuSurface = element => {
      let node = element;
      for (let depth = 0; depth < 12 && node; depth += 1) {
        const role = normalize(node.getAttribute?.('role'));
        const marker = normalize([
          node.getAttribute?.('data-slot'),
          node.getAttribute?.('data-state'),
          node.getAttribute?.('class'),
          node.getAttribute?.('id')
        ].filter(Boolean).join(' '));
        if (['menu', 'listbox', 'dialog'].includes(role)
            || node.getAttribute?.('aria-modal') === 'true'
            || node.getAttribute?.('data-state') === 'open'
            || /menu|dropdown|popover|listbox|select|command/.test(marker)) {
          return true;
        }
        node = parentOf(node);
      }
      return false;
    };
    const hit = document.elementFromPoint(\#(x), \#(y));
    const pointTarget = hit?.closest?.(selector) || (hit?.matches?.(selector) ? hit : null);
    const labelTarget = requested
      ? [...document.querySelectorAll(selector)]
        .filter(node => isMenuSurface(node) && labelOf(node) === requested)
        .sort((left, right) => {
          const leftRect = left.getBoundingClientRect?.();
          const rightRect = right.getBoundingClientRect?.();
          return (leftRect?.width || 0) * (leftRect?.height || 0)
            - (rightRect?.width || 0) * (rightRect?.height || 0);
        })[0]
      : null;
    const target = requested
      ? (pointTarget && labelOf(pointTarget) === requested ? pointTarget : labelTarget)
      : pointTarget;
    if (!target) return { ok: false, error: 'session_option_hit_missing' };
    if (target.disabled || target.getAttribute?.('aria-disabled') === 'true') {
      return { ok: false, error: 'session_option_hit_disabled' };
    }
    if (typeof target.focus !== 'function') {
      return { ok: false, error: 'session_option_hit_not_focusable' };
    }
    // This is the direct renderer path: no scrolling and no coordinate input
    // are required once the exact menu component has been identified.
    try { target.focus({ preventScroll: true }); } catch (_) {}
    target.click();
    const rect = target.getBoundingClientRect?.();
    return {
      ok: true,
      tag: target.tagName || '',
      role: target.getAttribute?.('role') || '',
      text: String(target.innerText || target.textContent || '').trim().slice(0, 160),
      rect: rect ? {
        left: rect.left, top: rect.top, width: rect.width, height: rect.height
      } : null
    };
  })()
  """#
  return cdpValue(
    port: port,
    targetId: targetId,
    expression: expression,
    timeout: 4.0
  )
}

func dedicatedApprovalWithNativeInput(
  port: Int,
  targetId: String,
  detection: [String: Any]
) -> [String: Any]? {
  guard let approvalWSURL = cdpWebSocketURL(port: port, targetId: targetId) else {
    queueTrace(
      "task=approval-watcher stage=approval-native-target-url-missing target=\(targetId)"
    )
    return [
      "ok": false,
      "clicked": false,
      "confirmed": false,
      "strategy": "session-scope",
      "error": "approval_cdp_target_missing",
    ]
  }
  queueTrace("task=approval-watcher stage=approval-native-enter target=\(targetId)")
  func evaluateSessionScope() -> [String: Any]? {
    queueTrace("task=approval-watcher stage=approval-native-scope-begin")
    let scope = cdpValuePersistent(
      wsURLString: approvalWSURL,
      expression: sessionScopeComponentProbeJS(),
      timeout: 2.0
    )
    let scopeError = scope?["error"] as? String ?? "none"
    queueTrace(
      "task=approval-watcher stage=approval-native-scope-return "
        + "found=\(scope != nil) error=\(scopeError)"
    )
    return scope
  }

  let triggerPoint = approvalPoint(detection["menuTriggerPoint"])
  let menuTriggerIsSelectedButton = detection["menuTriggerIsSelectedButton"] as? Bool == true
  var nativeTriggerClicked = false
  var nativeTriggerClickAttempts = 0
  var nativeTriggerClickSuccesses = 0
  var nativeTriggerKeyAttempts = 0
  var nativeTriggerKeySuccesses = 0
  var nativeTriggerKeyUsed = false
  var nativeTriggerComponentAttempts = 0
  var nativeTriggerComponentSuccesses = 0
  var nativeTriggerComponentLastMode = "none"
  var nativeTriggerComponentLastError = "none"
  func annotateNativeTrigger(_ result: inout [String: Any]) {
    result["nativeTriggerClickAttempts"] = nativeTriggerClickAttempts
    result["nativeTriggerClickSuccesses"] = nativeTriggerClickSuccesses
    result["nativeTriggerKeyAttempts"] = nativeTriggerKeyAttempts
    result["nativeTriggerKeySuccesses"] = nativeTriggerKeySuccesses
    result["nativeTriggerComponentAttempts"] = nativeTriggerComponentAttempts
    result["nativeTriggerComponentSuccesses"] = nativeTriggerComponentSuccesses
    result["nativeTriggerComponentLastMode"] = nativeTriggerComponentLastMode
    result["nativeTriggerComponentLastError"] = nativeTriggerComponentLastError
    if nativeTriggerClicked { result["nativeTriggerClicked"] = true }
    if nativeTriggerKeyUsed { result["nativeTriggerKeyUsed"] = true }
  }

  func pollSessionScope(_ initial: [String: Any]?) -> [String: Any]? {
    var current = initial
    if current?["error"] as? String == "session_scope_menu_not_opened"
        || current?["error"] as? String == "session_scope_option_not_found" {
      for _ in 0..<6 {
        Thread.sleep(forTimeInterval: 0.15)
        current = evaluateSessionScope()
        if current?["error"] as? String == "session_scope_native_option_required" {
          break
        }
      }
    }
    return current
  }

  var result: [String: Any]?
  if (detection["menuTriggerCount"] as? Int ?? 0) > 0 {
    // A same-button split control exposes the disclosure through its own
    // component semantics. The live renderer action below can locate that
    // control even when its geometry is absent or outside the viewport.
    if menuTriggerIsSelectedButton {
      nativeTriggerComponentAttempts += 1
      queueTrace("task=approval-watcher stage=approval-native-component-begin action=trigger")
      let componentResult = nativeApprovalComponentActionResult(
        port: port,
        targetId: targetId,
        point: triggerPoint,
        action: "trigger",
        wsURLString: approvalWSURL,
        label: detection["selectedLabel"] as? String
      )
      let componentOK = componentResult?["ok"] as? Bool == true
      let componentMode = componentResult?["mode"] as? String ?? "none"
      let componentError = componentResult?["error"] as? String ?? "none"
      queueTrace(
        "task=approval-watcher stage=approval-native-component-return action=trigger "
          + "ok=\(componentOK) mode=\(componentMode) error=\(componentError)"
      )
      nativeTriggerComponentLastMode = componentResult?["mode"] as? String ?? "none"
      nativeTriggerComponentLastError = componentResult?["error"] as? String ?? "none"
      if componentResult?["ok"] as? Bool == true {
        nativeTriggerComponentSuccesses += 1
        nativeTriggerClicked = true
        Thread.sleep(forTimeInterval: 0.35)
        result = pollSessionScope(evaluateSessionScope())
      } else {
        // Some Electron builds do not expose the disclosure callback through
        // React props. After the exact component was identified, ArrowDown is
        // the bounded non-primary fallback; it still cannot invoke Allow once.
        nativeTriggerKeyAttempts += 1
        if nativeApprovalArrowKey(
          port: port,
          targetId: targetId,
          point: triggerPoint,
          wsURLString: approvalWSURL,
          label: detection["selectedLabel"] as? String
        ) {
          nativeTriggerKeySuccesses += 1
          nativeTriggerKeyUsed = true
          Thread.sleep(forTimeInterval: 0.35)
          result = pollSessionScope(evaluateSessionScope())
        }
      }
    }

    let hasSessionOption = approvalPoint(result?["sessionOptionPoint"]) != nil
      || result?["sessionScopeLabel"] != nil
    // A same-button split control has no safe primary-button fallback: its
    // outer labelled control is also Allow once. If the component disclosure
    // could not open, leave the card pending instead of granting once.
    if !menuTriggerIsSelectedButton
      && !hasSessionOption {
      nativeTriggerComponentAttempts += 1
      let componentResult = nativeApprovalComponentActionResult(
        port: port,
        targetId: targetId,
        point: triggerPoint,
        action: "trigger",
        wsURLString: approvalWSURL,
        label: detection["selectedLabel"] as? String
      )
      nativeTriggerComponentLastMode = componentResult?["mode"] as? String ?? "none"
      nativeTriggerComponentLastError = componentResult?["error"] as? String ?? "none"
      if componentResult?["ok"] as? Bool == true {
        nativeTriggerComponentSuccesses += 1
        nativeTriggerClicked = true
        Thread.sleep(forTimeInterval: 0.35)
        result = pollSessionScope(evaluateSessionScope())
      } else {
        nativeTriggerKeyAttempts += 1
        if nativeApprovalArrowKey(
          port: port,
          targetId: targetId,
          point: triggerPoint,
          wsURLString: approvalWSURL,
          label: detection["selectedLabel"] as? String
        ) {
          nativeTriggerKeySuccesses += 1
          nativeTriggerKeyUsed = true
          Thread.sleep(forTimeInterval: 0.35)
          result = pollSessionScope(evaluateSessionScope())
        }
      }
    }
  }

  if result == nil {
    result = pollSessionScope(evaluateSessionScope())
  }

  guard var finalResult = result else {
    var failure: [String: Any] = [
      "ok": false,
      "clicked": nativeTriggerClicked,
      "confirmed": false,
      "strategy": "session-scope",
      "error": "session_scope_cdp_eval_failed",
    ]
    annotateNativeTrigger(&failure)
    return failure
  }
  annotateNativeTrigger(&finalResult)

  // The menu item is activated directly through its live renderer component
  // while the menu is still open. No viewport movement or coordinate input is
  // needed once the component root and exact session label are known.
  var cardsApproved = 0
  var nativeOptionClickAttempts = 0
  var nativeOptionClickSuccesses = 0
  var nativeOptionComponentAttempts = 0
  var nativeOptionComponentSuccesses = 0
  var nativeOptionComponentLastMode = "none"
  var nativeOptionComponentLastTarget = "none"
  var nativeOptionComponentLastError = "none"
  let nativeOptionDOMFallbackAttempts = 0
  let nativeOptionDOMFallbackSuccesses = 0
  var nativeOptionDOMFallbackLastError = "none"
  var nativeOptionDOMFallbackLastTarget = "none"
  var lastSessionOptionPoint: Any?
  var lastSessionOptionRect: Any?
  func annotateNativeInput(_ result: inout [String: Any]) {
    annotateNativeTrigger(&result)
    result["nativeOptionClickAttempts"] = nativeOptionClickAttempts
    result["nativeOptionClickSuccesses"] = nativeOptionClickSuccesses
    result["nativeOptionComponentAttempts"] = nativeOptionComponentAttempts
    result["nativeOptionComponentSuccesses"] = nativeOptionComponentSuccesses
    result["nativeOptionComponentLastMode"] = nativeOptionComponentLastMode
    result["nativeOptionComponentLastTarget"] = nativeOptionComponentLastTarget
    result["nativeOptionComponentLastError"] = nativeOptionComponentLastError
    result["nativeOptionDOMFallbackAttempts"] = nativeOptionDOMFallbackAttempts
    result["nativeOptionDOMFallbackSuccesses"] = nativeOptionDOMFallbackSuccesses
    result["nativeOptionDOMFallbackLastError"] = nativeOptionDOMFallbackLastError
    result["nativeOptionDOMFallbackLastTarget"] = nativeOptionDOMFallbackLastTarget
    if result["sessionOptionPoint"] == nil, let lastSessionOptionPoint {
      result["sessionOptionPoint"] = lastSessionOptionPoint
    }
    if result["sessionOptionRect"] == nil, let lastSessionOptionRect {
      result["sessionOptionRect"] = lastSessionOptionRect
    }
  }
  for attempt in 0..<2 {
    if finalResult["sessionOptionPoint"] != nil
        || finalResult["sessionScopeLabel"] != nil {
      let optionPoint = approvalPoint(finalResult["sessionOptionPoint"])
      lastSessionOptionPoint = finalResult["sessionOptionPoint"]
      lastSessionOptionRect = finalResult["sessionOptionRect"]
      var optionPoints: [(x: Double, y: Double)?] = []
      if let optionPoint { optionPoints.append(optionPoint) }
      // A menu row can expose a padded wrapper around its actual action. If
      // the first trusted click is rejected by that wrapper, try one more
      // point inside the same structurally identified row. Never retry after
      // the menu has closed: that could hit the main Allow once control.
      if let optionRect = approvalRect(finalResult["sessionOptionRect"]) {
        optionPoints.append((
          x: optionRect.left + optionRect.width / 2,
          y: optionRect.top + optionRect.height * 0.35
        ))
      }
      if optionPoints.isEmpty { optionPoints.append(nil) }
      var optionClicked = false
      for point in optionPoints {
        nativeOptionClickAttempts += 1
        nativeOptionComponentAttempts += 1
        let componentResult = nativeApprovalComponentActionResult(
          port: port,
          targetId: targetId,
          point: point,
          action: "option",
          wsURLString: approvalWSURL,
          label: finalResult["sessionScopeLabel"] as? String
        )
        nativeOptionComponentLastMode = componentResult?["mode"] as? String ?? "none"
        nativeOptionComponentLastTarget = componentResult?["targetLabel"] as? String ?? "none"
        nativeOptionComponentLastError = componentResult?["error"] as? String ?? "none"
        if componentResult?["ok"] as? Bool == true {
          nativeOptionClickSuccesses += 1
          nativeOptionComponentSuccesses += 1
          optionClicked = true
          nativeOptionDOMFallbackLastTarget = nativeOptionComponentLastTarget
          if let point {
            finalResult["sessionOptionClickPoint"] = ["x": point.x, "y": point.y]
          }
          Thread.sleep(forTimeInterval: 0.45)
          if let after = cdpValuePersistent(
            wsURLString: approvalWSURL,
            expression: detectDedicatedAuthorizationJS(),
            timeout: 3.0
          ), after["found"] as? Bool != true {
            cardsApproved += 1
            finalResult["ok"] = true
            finalResult["clicked"] = true
            finalResult["confirmed"] = true
            finalResult["strategy"] = "session-scope-component"
            finalResult["nativeInput"] = true
            finalResult["cardsApproved"] = cardsApproved
            finalResult["cardsRemaining"] = 0
            finalResult["error"] = "none"
            annotateNativeInput(&finalResult)
            return finalResult
          }
        } else {
          nativeOptionDOMFallbackLastError = componentResult?["error"] as? String
            ?? "session_option_component_eval_failed"
        }
      }
      if optionClicked {
        finalResult["clicked"] = true
        finalResult["nativeInput"] = true
        if let after = cdpValuePersistent(
          wsURLString: approvalWSURL,
          expression: detectDedicatedAuthorizationJS(),
          timeout: 3.0
        ), after["found"] as? Bool != true {
          cardsApproved += 1
          finalResult["ok"] = true
          finalResult["clicked"] = true
          finalResult["confirmed"] = true
          finalResult["strategy"] = "session-scope-native"
          finalResult["nativeInput"] = true
          finalResult["cardsApproved"] = cardsApproved
          finalResult["cardsRemaining"] = 0
          finalResult["error"] = "none"
          annotateNativeInput(&finalResult)
          return finalResult
        }
      }
    }

    guard attempt < 1 else { break }
    guard var refreshed = evaluateSessionScope() else { break }
    if nativeTriggerClicked { refreshed["nativeTriggerClicked"] = true }
    if refreshed["confirmed"] as? Bool == true {
      refreshed["cardsApproved"] = cardsApproved
      annotateNativeInput(&refreshed)
      return refreshed
    }

    let refreshedError = refreshed["error"] as? String ?? ""
    let refreshedHasOption = approvalPoint(refreshed["sessionOptionPoint"]) != nil
      || refreshed["sessionScopeLabel"] != nil
    if !refreshedHasOption,
       (refreshedError == "session_scope_native_input_required"
         || refreshedError == "session_scope_menu_not_opened"
         || refreshedError == "session_scope_option_not_found") {
      let retryPoint = approvalPoint(refreshed["menuTriggerPoint"]) ?? triggerPoint
      nativeTriggerComponentAttempts += 1
      let retriedResult = nativeApprovalComponentActionResult(
        port: port,
        targetId: targetId,
        point: retryPoint,
        action: "trigger",
        wsURLString: approvalWSURL,
        label: detection["selectedLabel"] as? String
      )
      nativeTriggerComponentLastMode = retriedResult?["mode"] as? String ?? "none"
      nativeTriggerComponentLastError = retriedResult?["error"] as? String ?? "none"
      let retried: Bool
      if retriedResult?["ok"] as? Bool == true {
        nativeTriggerComponentSuccesses += 1
        retried = true
      } else if menuTriggerIsSelectedButton {
        nativeTriggerKeyAttempts += 1
        retried = nativeApprovalArrowKey(
          port: port,
          targetId: targetId,
          point: retryPoint,
          wsURLString: approvalWSURL,
          label: detection["selectedLabel"] as? String
        )
        if retried {
          nativeTriggerKeySuccesses += 1
          nativeTriggerKeyUsed = true
        }
      } else {
        let separateTriggerResult = nativeApprovalComponentActionResult(
          port: port,
          targetId: targetId,
          point: retryPoint,
          action: "trigger",
          wsURLString: approvalWSURL,
          label: detection["selectedLabel"] as? String
        )
        nativeTriggerComponentLastMode = separateTriggerResult?["mode"] as? String ?? "none"
        nativeTriggerComponentLastError = separateTriggerResult?["error"] as? String ?? "none"
        retried = separateTriggerResult?["ok"] as? Bool == true
        if retried {
          nativeTriggerComponentSuccesses += 1
        }
      }
      nativeTriggerClicked = nativeTriggerClicked || (!menuTriggerIsSelectedButton && retried)
      if retried {
        Thread.sleep(forTimeInterval: 0.35)
      }
    }
    finalResult = evaluateSessionScope() ?? refreshed
    if nativeTriggerClicked { finalResult["nativeTriggerClicked"] = true }
  }
  annotateNativeInput(&finalResult)
  return finalResult
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
    const normalize = value => String(value || '')
      .replace(/[\s\u21b5\u00a0]+/g, ' ').trim().toLowerCase();
    const rendered = element => !!(element
      && (element.offsetWidth || element.offsetHeight || element.getClientRects?.().length));
    // A hidden Electron renderer can expose an attached permission card before
    // layout has produced a non-zero rect. It is still safe to inspect and
    // dispatch the card's own events when the node is attached and paired with
    // the component's allow control; container scoping below prevents page
    // copy from becoming an approval candidate.
    const visible = element => !!(element
      && !element.disabled
      && (rendered(element) || element.isConnected !== false));
    const parentOf = element => element?.parentElement || element?.parentNode?.host || null;
    const labelParts = element => [
      element?.getAttribute?.('aria-label'),
      element?.getAttribute?.('title'),
      element?.getAttribute?.('data-label'),
      element?.innerText,
      element?.textContent
    ].map(normalize).filter(Boolean);
    const label = element => labelParts(element)[0] || '';
    const labelText = element => [...new Set(labelParts(element))].join(' ');
    const query = (root, selector) => {
      try { return [...(root?.querySelectorAll?.(selector) || [])]; } catch (_) { return []; }
    };
    const controlSelectors = [
      'button', 'a', 'input[type="button"]', 'input[type="submit"]', 'summary',
      '[role="button"]', '[role="menuitem"]', '[role="menuitemradio"]',
      '[role="option"]', '[role="link"]', '[onclick]', '[tabindex]:not([tabindex="-1"])',
      '[aria-label]', '[title]', '[data-label]', '[data-testid*="allow" i]',
      '[data-testid*="deny" i]', '[data-testid*="permission" i]'
    ];
    const collectInteractive = (root, output, visited) => {
      if (!root || visited.has(root)) return;
      visited.add(root);
      for (const selector of controlSelectors) output.push(...query(root, selector));
      for (const element of query(root, '*')) {
        if (hasClickSemantics(element)
            || (element.children?.length === 0
              && (hasAllowLabel(element)
                || hasRejectLabel(element)
                || isSessionScope(labelText(element))))) {
          output.push(element);
        }
        if (element.shadowRoot) collectInteractive(element.shadowRoot, output, visited);
        if (element.tagName?.toLowerCase() === 'iframe') {
          try { if (element.contentDocument) collectInteractive(element.contentDocument, output, visited); }
          catch (_) {}
        }
      }
    };
    const allInteractive = () => {
      const output = [];
      collectInteractive(document, output, new Set());
      return output.filter((element, index, all) => all.indexOf(element) === index && visible(element));
    };
    const sessionHints = [
      'this chat', 'this conversation', 'for this chat', 'for this conversation',
      'for this session', 'during this chat', 'always allow in this chat',
      'this thread', 'for this thread', 'conversation only', 'chat only',
      '本次会话', '这次会话', '此会话', '当前会话', '本次对话', '此对话',
      '当前对话', '本次聊天', '在此聊天中', '会话期间', '仅此会话', '始终允许'
    ];
    const isSessionScope = value => {
      const normalized = normalize(value);
      return !!normalized && sessionHints.some(hint => normalized.includes(hint));
    };
    const allowLabels = new Set([
      'allow', 'allow once', 'allow this time', 'allow one time',
      'approve', 'approve once', 'confirm', 'confirm once',
      'authorize', 'authorise', 'permit', 'grant access', 'full access',
      '允许', '允许一次', '允许本次', '允许此次', '允许访问', '授权',
      '同意', '同意一次', '确认', '确认一次', '准许', '完全访问'
    ]);
    const rejectLabels = new Set([
      'deny', 'reject', 'cancel', 'deny once', 'reject once', 'decline',
      '拒绝', '拒绝一次', '不允许', '不允许一次', '取消', '不同意'
    ]);
    const stripDecorators = value => normalize(value)
      .replace(/[()[\]{}]/g, ' ')
      .replace(/[⌘⌥⇧⌃⏎↵]/g, ' ')
      .replace(/\s+/g, ' ').trim();
    const withoutShortcut = value => stripDecorators(value)
      .replace(/\s+(?:escape|esc|enter|return|space|tab)(?:\s+.*)?$/i, '')
      .trim();
    const isAllowLabel = value => {
      const normalized = withoutShortcut(value);
      if (!normalized || isSessionScope(normalized)) return false;
      if (allowLabels.has(normalized)) return true;
      return /^(allow|approve|confirm|authorize|authorise|permit)(?:\s+(?:once|one time|this time))?$/.test(normalized)
        || /^(允许|同意|确认|准许)(一次|本次|此次)?$/.test(normalized);
    };
    const isRejectLabel = value => {
      const normalized = withoutShortcut(value);
      return rejectLabels.has(normalized)
        || /^(deny|reject|cancel|decline)(?:\s+once)?$/.test(normalized)
        || /^(拒绝|不允许|取消)(一次)?$/.test(normalized);
    };
    const hasAllowLabel = element => labelParts(element).some(isAllowLabel);
    const hasRejectLabel = element => labelParts(element).some(isRejectLabel);
    const hasClickSemantics = element => {
      if (!element) return false;
      const tagName = element.tagName?.toLowerCase();
      const role = normalize(element.getAttribute?.('role'));
      if (['button', 'a', 'summary', 'input', 'select'].includes(tagName)
          || ['button', 'link', 'menuitem', 'menuitemradio', 'option'].includes(role)) {
        return true;
      }
      if (element.getAttribute?.('onclick') !== null
          || element.getAttribute?.('aria-haspopup') !== null
          || element.getAttribute?.('aria-expanded') !== null
          || Number(element.tabIndex) >= 0) {
        return true;
      }
      return Object.keys(element).some(key => {
        if (!key.startsWith('__reactProps$') && !key.startsWith('__reactFiber$')) return false;
        const value = element[key];
        const props = value?.memoizedProps || value?.pendingProps || value;
        return typeof props?.onClick === 'function' || typeof props?.onKeyDown === 'function';
      });
    };
    const isOneShot = value => /\bonce\b|one time|this time|一次|本次|此次/.test(normalize(value));
    const isGenericConfirm = value => {
      const normalized = withoutShortcut(value);
      return normalized === 'confirm' || normalized === '确认';
    };
    const isExplicitAllowLabel = value => {
      const normalized = withoutShortcut(value);
      return isAllowLabel(normalized) && !isGenericConfirm(normalized);
    };
    const approvalLabel = element => {
      const parts = labelParts(element);
      return parts.find(value => isExplicitAllowLabel(value) && isOneShot(value))
        || parts.find(isExplicitAllowLabel)
        || parts.find(isAllowLabel)
        || parts[0]
        || '';
    };
    const sharesComponent = (left, right) => {
      let leftAncestor = parentOf(left);
      for (let leftDepth = 0; leftDepth < 12 && leftAncestor; leftDepth += 1) {
        let rightAncestor = parentOf(right);
        for (let rightDepth = 0; rightDepth < 12 && rightAncestor; rightDepth += 1) {
          if (leftAncestor === rightAncestor) return true;
          rightAncestor = parentOf(rightAncestor);
        }
        leftAncestor = parentOf(leftAncestor);
      }
      return false;
    };
    const structuralMarker = element => normalize([
      element?.getAttribute?.('data-testid'),
      element?.getAttribute?.('data-slot'),
      element?.getAttribute?.('data-state'),
      element?.getAttribute?.('class'),
      element?.getAttribute?.('id')
    ].filter(Boolean).join(' '));
    const isArrowLike = element => {
      if (!element) return false;
      const tagName = element.tagName?.toLowerCase();
      if (['kbd', 'br', 'img'].includes(tagName)) return false;
      const marker = structuralMarker(element);
      return element.getAttribute?.('aria-haspopup') !== null
        || element.getAttribute?.('aria-expanded') !== null
        || /menu|dropdown|chevron|caret|arrow|more|overflow|popover|split|disclosure/.test(marker)
        || (['svg', 'path', 'polyline', 'polygon'].includes(tagName) && !labelText(element));
    };
    const hasMenuStructure = element => {
      if (!element) return false;
      return element.getAttribute?.('aria-haspopup') !== null
        || element.getAttribute?.('aria-expanded') !== null
        || /menu|dropdown|chevron|caret|arrow|more|overflow|popover|split|disclosure/.test(
          structuralMarker(element)
        );
    };
    const isNearRightSplit = (element, candidate) => {
      if (!element || !candidate || element === candidate || labelText(element)) return false;
      const elementRect = element.getBoundingClientRect?.();
      const candidateRect = candidate.getBoundingClientRect?.();
      if (!elementRect || !candidateRect
          || elementRect.width <= 0 || elementRect.height <= 0
          || candidateRect.width <= 0 || candidateRect.height <= 0) return false;
      const verticalOverlap = Math.min(elementRect.bottom, candidateRect.bottom)
        - Math.max(elementRect.top, candidateRect.top);
      if (verticalOverlap <= 0) return false;
      const maxArrowWidth = Math.max(20, Math.min(56, candidateRect.width * 0.45));
      if (elementRect.width > maxArrowWidth) return false;
      const adjacentRight = elementRect.left >= candidateRect.right - 8
        && elementRect.left <= candidateRect.right + 64;
      const insideRight = elementRect.right >= candidateRect.right - 4
        && elementRect.left >= candidateRect.left + candidateRect.width * 0.55;
      return adjacentRight || insideRight;
    };
    const isMenuTrigger = (button, candidate, container = null) => {
      if (!button) return false;
      const value = labelText(button);
      const sameButton = button === candidate;
      if (sameButton) {
        return hasClickSemantics(button)
          && (isOneShot(labelText(candidate)) || isAllowLabel(labelText(candidate)))
          && hasMenuStructure(button);
      }
      const sameContainer = !!(container
        && (container === button || container.contains?.(button))
        && (container === candidate || container.contains?.(candidate)));
      const sameComponent = sameContainer || sharesComponent(button, candidate);
      if (!sameComponent) return false;
      const tagName = button.tagName?.toLowerCase();
      const nonActionableTag = ['kbd', 'svg', 'path', 'polyline', 'polygon'].includes(tagName);
      const actionableCompanion = hasClickSemantics(button)
        || isNearRightSplit(button, candidate)
        || (hasMenuStructure(button) && !nonActionableTag);
      if (!actionableCompanion) return false;
      const approvalRelated = !value
        || isSessionScope(value)
        || isOneShot(value)
        || isAllowLabel(value);
      const structural = approvalRelated && hasMenuStructure(button);
      const iconOnlyCompanion = !value
        && (isArrowLike(button) || isNearRightSplit(button, candidate));
      const labeledSplitCompanion = isOneShot(value)
        && isOneShot(labelText(candidate))
        && (isArrowLike(button) || isNearRightSplit(button, candidate));
      const buttonRect = button.getBoundingClientRect?.();
      const narrowAllowCompanion = isAllowLabel(value)
        && isOneShot(labelText(candidate))
        && buttonRect
        && buttonRect.width > 0
        && buttonRect.width <= 48;
      return structural || iconOnlyCompanion || labeledSplitCompanion || narrowAllowCompanion;
    };
    const componentRoots = container => {
      const roots = [];
      let root = container;
      for (let depth = 0; depth < 6 && root; depth += 1) {
        roots.push(root);
        root = parentOf(root);
      }
      return roots;
    };
    const componentControls = (container, candidate) => {
      if (!container) return [];
      const output = [];
      for (const root of componentRoots(container)) {
        output.push(...query(root, 'button, a, [role="button"], [aria-haspopup], [aria-expanded], [data-testid], [data-slot], [data-state]'));
        output.push(...query(root, '*').filter(element => {
          return !labelText(element)
            && (isArrowLike(element) || isNearRightSplit(element, candidate));
        }));
      }
      return output.filter((element, index, all) => all.indexOf(element) === index && visible(element));
    };
    const findMenuTrigger = (card, candidate) => {
      const controls = [
        ...card.cardButtons,
        ...componentControls(card.container, candidate)
      ].filter((button, index, all) => all.indexOf(button) === index);
      return controls.find(button => isMenuTrigger(button, candidate, card.container)) || null;
    };
    const rectObject = element => {
      const rect = element?.getBoundingClientRect?.();
      if (!rect || rect.width <= 0 || rect.height <= 0) return null;
      const left = rect.left || 0;
      const top = rect.top || 0;
      const width = rect.width || 0;
      const height = rect.height || 0;
      return {
        left, top, width, height,
        right: Number.isFinite(rect.right) ? rect.right : left + width,
        bottom: Number.isFinite(rect.bottom) ? rect.bottom : top + height
      };
    };
    const menuTriggerPoint = (element, candidate) => {
      const rect = rectObject(element);
      if (!rect) return null;
      const sameButton = element && element === candidate;
      if (sameButton) {
        // Some renderers put the disclosure triangle in the trailing padding
        // of the same button as the visible Allow once label. Use the center
        // of that trailing affordance, not the outer border: the border can
        // be hit-tested as the primary action or ignored by hidden Chromium
        // renderers. A keyboard-chip child gives us the exact left boundary;
        // otherwise keep a small component-relative fallback.
        const childRights = query(element, '*')
          .map(child => ({ child, rect: rectObject(child) }))
          .filter(item => item.rect && visible(item.child))
          .map(item => item.rect.right);
        const contentRight = childRights.length
          ? Math.max(...childRights)
          : rect.right;
        const trailingWidth = rect.right - contentRight;
        const offset = trailingWidth >= 4 && trailingWidth <= 20
          ? trailingWidth / 2
          : Math.min(8, Math.max(4, rect.width * 0.08));
        return {
          x: Math.max(rect.left + 1, rect.right - offset),
          y: rect.top + rect.height / 2
        };
      }
      return {
        x: rect.left + Math.min(rect.width / 2, Math.max(1, rect.width - 1)),
        y: rect.top + rect.height / 2
      };
    };
    const componentControlSamples = (card, candidate) => {
      const reactHandlerNames = element => {
        const names = [];
        for (const key of Object.keys(element || {})) {
          if (!key.startsWith('__reactProps$')) continue;
          const value = element[key];
          const props = value?.memoizedProps || value?.pendingProps || value;
          for (const prop of Object.keys(props || {})) {
            if (/^on[A-Z]/.test(prop)) names.push(prop);
          }
        }
        return [...new Set(names)].slice(0, 20);
      };
      const compactElement = element => {
        if (!element) return null;
        const rect = element.getBoundingClientRect?.();
        return {
          tag: element.tagName?.toLowerCase() || '',
          role: normalize(element.getAttribute?.('role')),
          text: labelText(element).slice(0, 120),
          className: String(element.getAttribute?.('class') || '').slice(0, 160),
          clickSemantics: hasClickSemantics(element),
          reactHandlers: reactHandlerNames(element),
          rect: rect ? {
            left: rect.left, top: rect.top, width: rect.width, height: rect.height,
            right: rect.right, bottom: rect.bottom
          } : null
        };
      };
      const nodes = componentRoots(card.container)
        .flatMap(root => query(root, '*'))
        .filter((element, index, all) => all.indexOf(element) === index)
        .filter(element => {
          if (!visible(element)) return false;
          const value = labelText(element);
          return value.length <= 120
            && (hasAllowLabel(element)
              || hasRejectLabel(element)
              || hasClickSemantics(element)
              || !value
              || isArrowLike(element)
              || isNearRightSplit(element, candidate));
        });
      const score = element => {
        const value = labelText(element);
        return (element === candidate ? 100 : 0)
          + (hasAllowLabel(element) ? 20 : 0)
          + (isNearRightSplit(element, candidate) ? 8 : 0)
          + (isArrowLike(element) ? 4 : 0)
          + (hasClickSemantics(element) ? 2 : 0)
          + (value ? 1 : 0);
      };
      return nodes
        .sort((left, right) => score(right) - score(left))
        .slice(0, 24)
        .map(element => {
          const rect = element.getBoundingClientRect?.();
          return {
            tag: element.tagName?.toLowerCase() || '',
            role: normalize(element.getAttribute?.('role')),
            ariaLabel: element.getAttribute?.('aria-label') || '',
            ariaHasPopup: element.getAttribute?.('aria-haspopup') || '',
            ariaExpanded: element.getAttribute?.('aria-expanded') || '',
            title: element.getAttribute?.('title') || '',
            dataTestId: element.getAttribute?.('data-testid') || '',
            dataSlot: element.getAttribute?.('data-slot') || '',
            dataState: element.getAttribute?.('data-state') || '',
            id: element.getAttribute?.('id') || '',
            className: String(element.getAttribute?.('class') || '').slice(0, 160),
            text: labelText(element).slice(0, 120),
            clickSemantics: hasClickSemantics(element),
            arrowLike: isArrowLike(element),
            nearRightSplit: isNearRightSplit(element, candidate),
            reactHandlers: reactHandlerNames(element),
            childElements: hasAllowLabel(element)
              ? query(element, '*').slice(0, 20).map(compactElement)
              : [],
            rightEdgeHit: hasAllowLabel(element)
              ? (() => {
                const elementRect = element.getBoundingClientRect?.();
                if (!elementRect || elementRect.width <= 0 || elementRect.height <= 0) return null;
                return compactElement(document.elementFromPoint?.(
                  elementRect.right - 2,
                  elementRect.top + elementRect.height / 2
                ));
              })()
              : null,
            rect: rect ? {
              left: rect.left, top: rect.top, width: rect.width, height: rect.height,
              right: rect.right, bottom: rect.bottom
            } : null
          };
        });
    };
    const approvalComponentData = element => {
      const ownKeys = node => {
        try { return Object.getOwnPropertyNames(node); } catch (_) { return []; }
      };
      const approvalActionPattern = /^(allow|approve|confirm|authorize|authorise|grant|permit)(?:_|$)/i;
      const targetFrom = action => action?.target_message_id
        || action?.targetMessageId
        || action?.target_messageID
        || '';
      const inspect = (source, domNode, fiberDepth) => {
        const props = source?.memoizedProps || source?.pendingProps || source?.props || source;
        const pluginData = props?.jit_plugin_data
          || props?.pluginData
          || props?.card?.jit_plugin_data;
        const fromServer = pluginData?.from_server || pluginData?.fromServer;
        const actions = fromServer?.actions || pluginData?.actions || props?.actions;
        if (!actions || typeof actions !== 'object') return null;
        const entries = Object.entries(actions);
        const actionKeys = entries.map(([key]) => key);
        const hasApprovalAction = actionKeys.some(action => approvalActionPattern.test(action));
        const targetMessageId = entries
          .filter(([key]) => approvalActionPattern.test(key))
          .map(([, action]) => targetFrom(action))
          .find(Boolean)
          || targetFrom(props)
          || '';
        const hasPluginAuthorizationData = Boolean(pluginData && fromServer);
        if (!hasApprovalAction || (!hasPluginAuthorizationData && !targetMessageId)) return null;
        return {
          root: domNode,
          actionKeys,
          targetMessageId,
          fiberDepth
        };
      };
      const seenFibers = new Set();
      let node = element;
      for (let depth = 0; depth < 30 && node; depth += 1) {
        for (const key of ownKeys(node)) {
          if (!key.startsWith('__reactProps$') && !key.startsWith('__reactFiber$')) continue;
          const value = node[key];
          const direct = inspect(value, node, 0);
          if (direct) return direct;
          if (!key.startsWith('__reactFiber$')) continue;
          let fiber = value;
          for (let fiberDepth = 1; fiberDepth < 50 && fiber; fiberDepth += 1) {
            if (seenFibers.has(fiber)) break;
            seenFibers.add(fiber);
            const found = inspect(fiber, node, fiberDepth);
            if (found) return found;
            fiber = fiber.return;
          }
        }
        node = parentOf(node);
      }
      return null;
    };
    const interactive = allInteractive();
    const candidates = interactive
      .map((button, index) => ({ button, index, label: approvalLabel(button) }))
      .filter(candidate => hasAllowLabel(candidate.button));
    const cardFor = candidate => {
      let container = parentOf(candidate.button);
      for (let index = 0; index < 30 && container; index += 1) {
        const localButtons = [];
        collectInteractive(container, localButtons, new Set());
        const cardButtons = [
          ...allInteractive().filter(button => {
            try { return container.contains?.(button); } catch (_) { return false; }
          }),
          ...localButtons
        ].filter((button, buttonIndex, all) =>
          all.indexOf(button) === buttonIndex
            && visible(button)
            && labelText(button).length <= 240
        );
        const cardLabels = cardButtons.map(label).filter(Boolean);
        const hasExplicitAllow = cardButtons.some(button =>
          isExplicitAllowLabel(approvalLabel(button))
        );
        const componentData = approvalComponentData(candidate.button);
        const hasComponentAuthorization = Boolean(componentData)
          || cardButtons.some(button => Boolean(approvalComponentData(button)));
        // The explicit allow control is the authorization-card marker. React
        // metadata is retained for diagnostics, but it must not block a real
        // Allow once/Allow button when the renderer omits or reshapes it.
        if (hasExplicitAllow || hasComponentAuthorization) {
          return {
            container, cardButtons, cardLabels, componentData,
            hasComponentAuthorization
          };
        }
        container = parentOf(container);
      }
      return null;
    };
    const cards = candidates.map(cardFor).filter(Boolean);
    const card = cards[0];
    const allowControlScore = button => {
      const value = approvalLabel(button);
      return (hasClickSemantics(button) ? 1000 : 0)
        + (hasMenuStructure(button) ? 100 : 0)
        + (isArrowLike(button) ? 20 : 0)
        + (isOneShot(value) ? 10 : 0)
        - Math.min(40, labelText(button).length / 10);
    };
    const selectedButton = card?.cardButtons
      .filter(button => isExplicitAllowLabel(approvalLabel(button)) || hasAllowLabel(button))
      .sort((left, right) => allowControlScore(right) - allowControlScore(left))[0]
      || candidates[0]?.button;
    const componentProbe = interactive
      .map(button => approvalComponentData(button))
      .filter(Boolean);
    const componentActionKeys = [...new Set(componentProbe
      .flatMap(item => item.actionKeys || []))];
    const componentTargetMessageIdPresent = componentProbe
      .some(item => Boolean(item.targetMessageId));
    const interactiveLabelSamples = interactive
      .map(button => label(button))
      .filter(Boolean)
      .slice(0, 40);
    if (!card) {
      return {
        ok: true,
        found: false,
        candidates: candidates.length,
        candidateLabels: candidates.map(item => item.label),
        selectedLabel: '',
        cardButtonLabels: interactive
          .filter(button => hasAllowLabel(button) || hasRejectLabel(button))
          .map(label)
          .filter(Boolean),
        sessionScopeLabels: [],
        menuTriggerLabels: [],
        menuTriggerCount: 0,
        unlabeledControlCount: 0,
        componentActionKeys,
        componentTargetMessageIdPresent,
        componentControlSamples: [],
        selectedButtonRect: null,
        menuTriggerRect: null,
        menuTriggerPoint: null,
        interactiveLabelSamples,
        cardCount: 0,
        interactiveCount: interactive.length,
        detectionStrategy: 'interactive-dom-shadow-iframe'
      };
    }
    const menuTrigger = findMenuTrigger(card, selectedButton);
    const selectedButtonRect = rectObject(selectedButton);
    const menuTriggerRect = rectObject(menuTrigger);
    return {
      ok: true,
      found: true,
      candidates: candidates.length,
      candidateLabels: candidates.map(item => item.label),
      selectedLabel: approvalLabel(selectedButton),
      cardButtonLabels: card.cardLabels.filter(Boolean),
      sessionScopeLabels: card.cardLabels.filter(value => isSessionScope(value)),
      menuTriggerLabels: menuTrigger
        ? [approvalLabel(menuTrigger) || '[unlabeled companion]'] : [],
      menuTriggerCount: menuTrigger ? 1 : 0,
      unlabeledControlCount: card.cardButtons.filter(button =>
        !hasAllowLabel(button) && !hasRejectLabel(button) && !label(button)
      ).length,
      componentActionKeys: card.componentData?.actionKeys || [],
      componentTargetMessageIdPresent: Boolean(card.componentData?.targetMessageId),
      componentControlSamples: componentControlSamples(card, selectedButton),
      selectedButtonRect,
      menuTriggerRect,
      menuTriggerPoint: menuTriggerPoint(menuTrigger, selectedButton),
      menuTriggerIsSelectedButton: menuTrigger === selectedButton,
      cardCount: cards.length,
      interactiveCount: interactive.length,
      detectionStrategy: 'interactive-dom-shadow-iframe'
    };
  })()
  """#
}

func autoApproveDedicatedAuthorizationJS(nativeOnly: Bool = false) -> String {
  let nativeOnlyLiteral = nativeOnly ? "true" : "false"
  return #"""
  (async () => {
    const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
    const nativeOnly = \#(nativeOnlyLiteral);
    const normalize = value => String(value || '')
      .replace(/[\s\u21b5\u00a0]+/g, ' ').trim().toLowerCase();
    const rendered = element => !!(element
      && (element.offsetWidth || element.offsetHeight || element.getClientRects?.().length));
    // Hidden ChatGPT renderer cards may be attached before they receive layout
    // geometry. Treat those card-owned controls as actionable as long as they
    // remain connected and enabled; collectCard still requires the allow
    // control's authorization component root before any event is dispatched.
    const hasAllowLabel = element => labelParts(element).some(isAllowLabel);
    const hasRejectLabel = element => labelParts(element).some(isRejectLabel);
    const visible = element => !!(element
      && !element.disabled
      && (rendered(element) || element.isConnected !== false));
    const parentOf = element => element?.parentElement || element?.parentNode?.host || null;
    const labelParts = element => [
      element?.getAttribute?.('aria-label'),
      element?.getAttribute?.('title'),
      element?.getAttribute?.('data-label'),
      element?.innerText,
      element?.textContent
    ].map(normalize).filter(Boolean);
    const label = element => labelParts(element)[0] || '';
    const labelText = element => [...new Set(labelParts(element))].join(' ');
    const query = (root, selector) => {
      try { return [...(root?.querySelectorAll?.(selector) || [])]; } catch (_) { return []; }
    };
    const controlSelectors = [
      'button', 'a', 'input[type="button"]', 'input[type="submit"]', 'summary',
      '[role="button"]', '[role="menuitem"]', '[role="menuitemradio"]',
      '[role="option"]', '[role="link"]', '[onclick]', '[tabindex]:not([tabindex="-1"])',
      '[aria-label]', '[title]', '[data-label]', '[data-testid*="allow" i]',
      '[data-testid*="deny" i]', '[data-testid*="permission" i]'
    ];
    const collectInteractive = (root, output, visited) => {
      if (!root || visited.has(root)) return;
      visited.add(root);
      for (const selector of controlSelectors) output.push(...query(root, selector));
      for (const element of query(root, '*')) {
        if (hasClickSemantics(element)
            || (element.children?.length === 0
              && (hasAllowLabel(element)
                || hasRejectLabel(element)
                || isSessionScope(labelText(element))))) {
          output.push(element);
        }
        if (element.shadowRoot) collectInteractive(element.shadowRoot, output, visited);
        if (element.tagName?.toLowerCase() === 'iframe') {
          try { if (element.contentDocument) collectInteractive(element.contentDocument, output, visited); }
          catch (_) {}
        }
      }
    };
    const allInteractive = () => {
      const output = [];
      collectInteractive(document, output, new Set());
      return output.filter((element, index, all) => all.indexOf(element) === index && visible(element));
    };
    const sessionHints = [
      'this chat', 'this conversation', 'for this chat', 'for this conversation',
      'for this session', 'during this chat', 'always allow in this chat',
      'this thread', 'for this thread', 'conversation only', 'chat only',
      '\u672c\u6b21\u4f1a\u8bdd', '\u8fd9\u6b21\u4f1a\u8bdd', '\u6b64\u4f1a\u8bdd',
      '\u5f53\u524d\u4f1a\u8bdd', '\u672c\u6b21\u5bf9\u8bdd', '\u6b64\u5bf9\u8bdd',
      '\u5f53\u524d\u5bf9\u8bdd', '\u672c\u6b21\u804a\u5929', '\u5728\u6b64\u804a\u5929\u4e2d',
      '\u4f1a\u8bdd\u671f\u95f4', '\u4ec5\u6b64\u4f1a\u8bdd', '\u59cb\u7ec8\u5141\u8bb8'
    ];
    const isSessionScope = value => {
      const normalized = normalize(value);
      return !!normalized && sessionHints.some(hint => normalized.includes(hint));
    };
    const allowLabels = new Set([
      '\u5b8c\u5168\u8bbf\u95ee', 'full access', 'allow', 'allow once',
      'allow this time', 'allow one time', 'approve', 'approve once',
      'confirm', 'confirm once', 'authorize', 'authorise', 'permit', 'grant access',
      '\u5141\u8bb8', '\u5141\u8bb8\u4e00\u6b21', '\u5141\u8bb8\u672c\u6b21', '\u5141\u8bb8\u8bbf\u95ee', '\u6388\u6743',
      'allow', 'approve', '\u786e\u8ba4', '\u786e\u8ba4\u4e00\u6b21',
      '\u540c\u610f', '\u540c\u610f\u4e00\u6b21', '\u51c6\u8bb8'
    ]);
    const rejectLabels = new Set([
      'deny', 'reject', 'cancel', 'deny once', 'reject once', 'decline',
      '\u62d2\u7edd', '\u62d2\u7edd\u4e00\u6b21', '\u4e0d\u5141\u8bb8',
      '\u4e0d\u5141\u8bb8\u4e00\u6b21', '\u53d6\u6d88', '\u4e0d\u540c\u610f'
    ]);
    const stripDecorators = value => normalize(value)
      .replace(/[()[\]{}]/g, ' ')
      .replace(/[⌘⌥⇧⌃⏎↵]/g, ' ')
      .replace(/\s+/g, ' ').trim();
    const withoutShortcut = value => stripDecorators(value)
      .replace(/\s+(?:escape|esc|enter|return|space|tab)(?:\s+.*)?$/i, '')
      .trim();
    const isAllowLabel = value => {
      const normalized = withoutShortcut(value);
      if (!normalized || isSessionScope(normalized)) return false;
      if (allowLabels.has(normalized)) return true;
      return /^(allow|approve|confirm|authorize|authorise|permit)(?:\s+(?:once|one time|this time))?$/.test(normalized)
        || /^(\u5141\u8bb8|\u540c\u610f|\u786e\u8ba4|\u51c6\u8bb8)(\u4e00\u6b21|\u672c\u6b21|\u6b64\u6b21)?$/.test(normalized);
    };
    const isRejectLabel = value => {
      const normalized = withoutShortcut(value);
      return rejectLabels.has(normalized)
        || /^(deny|reject|cancel|decline)(?:\s+once)?$/.test(normalized)
        || /^(\u62d2\u7edd|\u4e0d\u5141\u8bb8|\u53d6\u6d88)(\u4e00\u6b21)?$/.test(normalized);
    };
    const hasClickSemantics = element => {
      if (!element) return false;
      const tagName = element.tagName?.toLowerCase();
      const role = normalize(element.getAttribute?.('role'));
      if (['button', 'a', 'summary', 'input', 'select'].includes(tagName)
          || ['button', 'link', 'menuitem', 'menuitemradio', 'option'].includes(role)) {
        return true;
      }
      if (element.getAttribute?.('onclick') !== null
          || element.getAttribute?.('aria-haspopup') !== null
          || element.getAttribute?.('aria-expanded') !== null
          || Number(element.tabIndex) >= 0) {
        return true;
      }
      return Object.keys(element).some(key => {
        if (!key.startsWith('__reactProps$') && !key.startsWith('__reactFiber$')) return false;
        const value = element[key];
        const props = value?.memoizedProps || value?.pendingProps || value;
        return typeof props?.onClick === 'function' || typeof props?.onKeyDown === 'function';
      });
    };
    const isGenericConfirm = value => {
      const normalized = withoutShortcut(value);
      return normalized === 'confirm' || normalized === '确认';
    };
    const isExplicitAllowLabel = value => {
      const normalized = withoutShortcut(value);
      return isAllowLabel(normalized) && !isGenericConfirm(normalized);
    };
    const approvalLabel = element => {
      const parts = labelParts(element);
      return parts.find(value => isExplicitAllowLabel(value) && isOneShot(value))
        || parts.find(isExplicitAllowLabel)
        || parts.find(isAllowLabel)
        || parts[0]
        || '';
    };
    const sharesComponent = (left, right) => {
      let leftAncestor = parentOf(left);
      for (let leftDepth = 0; leftDepth < 12 && leftAncestor; leftDepth += 1) {
        let rightAncestor = parentOf(right);
        for (let rightDepth = 0; rightDepth < 12 && rightAncestor; rightDepth += 1) {
          if (leftAncestor === rightAncestor) return true;
          rightAncestor = parentOf(rightAncestor);
        }
        leftAncestor = parentOf(leftAncestor);
      }
      return false;
    };
    const structuralMarker = element => normalize([
      element?.getAttribute?.('data-testid'),
      element?.getAttribute?.('data-slot'),
      element?.getAttribute?.('data-state'),
      element?.getAttribute?.('class'),
      element?.getAttribute?.('id')
    ].filter(Boolean).join(' '));
    const isArrowLike = element => {
      if (!element) return false;
      const tagName = element.tagName?.toLowerCase();
      if (['kbd', 'br', 'img'].includes(tagName)) return false;
      const marker = structuralMarker(element);
      return element.getAttribute?.('aria-haspopup') !== null
        || element.getAttribute?.('aria-expanded') !== null
        || /menu|dropdown|chevron|caret|arrow|more|overflow|popover|split|disclosure/.test(marker)
        || (['svg', 'path', 'polyline', 'polygon'].includes(tagName) && !labelText(element));
    };
    const isNearRightSplit = (element, candidate) => {
      if (!element || !candidate || element === candidate || labelText(element)) return false;
      const elementRect = element.getBoundingClientRect?.();
      const candidateRect = candidate.getBoundingClientRect?.();
      if (!elementRect || !candidateRect
          || elementRect.width <= 0 || elementRect.height <= 0
          || candidateRect.width <= 0 || candidateRect.height <= 0) return false;
      const verticalOverlap = Math.min(elementRect.bottom, candidateRect.bottom)
        - Math.max(elementRect.top, candidateRect.top);
      if (verticalOverlap <= 0) return false;
      const maxArrowWidth = Math.max(20, Math.min(56, candidateRect.width * 0.45));
      if (elementRect.width > maxArrowWidth) return false;
      const adjacentRight = elementRect.left >= candidateRect.right - 8
        && elementRect.left <= candidateRect.right + 64;
      const insideRight = elementRect.right >= candidateRect.right - 4
        && elementRect.left >= candidateRect.left + candidateRect.width * 0.55;
      return adjacentRight || insideRight;
    };
    const isMenuTrigger = (button, candidate, container = null) => {
      if (!button) return false;
      const value = labelText(button);
      const sameButton = button === candidate;
      if (sameButton) {
        return hasClickSemantics(button)
          && (isOneShot(labelText(candidate)) || isAllowLabel(labelText(candidate)))
          && hasMenuStructure(button);
      }
      const sameContainer = !!(container
        && (container === button || container.contains?.(button))
        && (container === candidate || container.contains?.(candidate)));
      const sameComponent = sameContainer || sharesComponent(button, candidate);
      if (!sameComponent) return false;
      const tagName = button.tagName?.toLowerCase();
      const nonActionableTag = ['kbd', 'svg', 'path', 'polyline', 'polygon'].includes(tagName);
      const actionableCompanion = hasClickSemantics(button)
        || isNearRightSplit(button, candidate)
        || (hasMenuStructure(button) && !nonActionableTag);
      if (!actionableCompanion) return false;
      const approvalRelated = !value
        || isSessionScope(value)
        || isOneShot(value)
        || isAllowLabel(value);
      const structural = approvalRelated && hasMenuStructure(button);
      const iconOnlyCompanion = !value
        && (isArrowLike(button) || isNearRightSplit(button, candidate));
      const labeledSplitCompanion = isOneShot(value)
        && isOneShot(labelText(candidate))
        && (isArrowLike(button) || isNearRightSplit(button, candidate));
      const buttonRect = button.getBoundingClientRect?.();
      const narrowAllowCompanion = isAllowLabel(value)
        && isOneShot(labelText(candidate))
        && buttonRect
        && buttonRect.width > 0
        && buttonRect.width <= 48;
      return structural || iconOnlyCompanion || labeledSplitCompanion || narrowAllowCompanion;
    };
    const componentRoots = container => {
      const roots = [];
      let root = container;
      for (let depth = 0; depth < 6 && root; depth += 1) {
        roots.push(root);
        root = parentOf(root);
      }
      return roots;
    };
    const componentControls = (container, candidate) => {
      if (!container) return [];
      const output = [];
      for (const root of componentRoots(container)) {
        output.push(...query(root, 'button, a, [role="button"], [aria-haspopup], [aria-expanded], [data-testid], [data-slot], [data-state]'));
        output.push(...query(root, '*').filter(element => {
          return !labelText(element)
            && (isArrowLike(element) || isNearRightSplit(element, candidate));
        }));
      }
      return output.filter((element, index, all) => all.indexOf(element) === index && visible(element));
    };
    const hasMenuStructure = element => {
      if (!element) return false;
      return element.getAttribute?.('aria-haspopup') !== null
        || element.getAttribute?.('aria-expanded') !== null
        || /menu|dropdown|chevron|caret|arrow|more|overflow|popover|split|disclosure/.test(
          structuralMarker(element)
        );
    };
    const menuTriggerOptions = new WeakMap();
    const rectObject = element => {
      const rect = element?.getBoundingClientRect?.();
      if (!rect || rect.width <= 0 || rect.height <= 0) return null;
      const left = rect.left || 0;
      const top = rect.top || 0;
      const width = rect.width || 0;
      const height = rect.height || 0;
      return {
        left, top, width, height,
        right: Number.isFinite(rect.right) ? rect.right : left + width,
        bottom: Number.isFinite(rect.bottom) ? rect.bottom : top + height
      };
    };
    const menuTriggerPoint = (trigger, candidate) => {
      const rect = rectObject(trigger);
      if (!rect) return null;
      if (trigger === candidate) {
        const childRights = query(trigger, '*')
          .map(child => ({ child, rect: rectObject(child) }))
          .filter(item => item.rect && visible(item.child))
          .map(item => item.rect.right);
        const contentRight = childRights.length
          ? Math.max(...childRights)
          : rect.right;
        const trailingWidth = rect.right - contentRight;
        const offset = trailingWidth >= 4 && trailingWidth <= 20
          ? trailingWidth / 2
          : Math.min(8, Math.max(4, rect.width * 0.08));
        return {
          x: Math.max(rect.left + 1, rect.right - offset),
          y: rect.top + rect.height / 2
        };
      }
      return {
        x: rect.left + Math.min(rect.width / 2, Math.max(1, rect.width - 1)),
        y: rect.top + rect.height / 2
      };
    };
    const configureMenuTrigger = (trigger, candidate) => {
      if (!trigger || trigger !== candidate) return;
      const point = menuTriggerPoint(trigger, candidate);
      if (!point) {
        menuTriggerOptions.set(trigger, { coordinateOnly: false });
        return;
      }
      // The ChatGPT permission control is a split button in some renderers:
      // its visible Allow once label and disclosure arrow share one <button>.
      // Keep the native click path off and dispatch at the right edge so the
      // host receives the disclosure activation instead of the one-shot action.
      menuTriggerOptions.set(trigger, {
        coordinateOnly: true,
        point
      });
    };
    const findMenuTrigger = (card, candidate) => {
      const controls = [
        ...card.cardButtons,
        ...componentControls(card.container, candidate)
      ].filter((button, index, all) => all.indexOf(button) === index);
      const companion = controls.find(button => isMenuTrigger(button, candidate, card.container));
      configureMenuTrigger(companion, candidate);
      return companion || null;
    };
    const isMenuSurface = element => {
      if (!element) return false;
      const role = normalize(element.getAttribute?.('role'));
      if (['menu', 'listbox', 'dialog'].includes(role)) return true;
      const marker = structuralMarker(element);
      return element.getAttribute?.('aria-modal') === 'true'
        || element.getAttribute?.('data-state') === 'open'
        || /menu|dropdown|popover|listbox|select|command/.test(marker);
    };
    const menuSurfaceFor = element => {
      let node = element;
      for (let depth = 0; depth < 12 && node; depth += 1) {
        if (isMenuSurface(node)) return node;
        node = parentOf(node);
      }
      return null;
    };
    const menuTargetFor = element => {
      let node = element;
      for (let depth = 0; depth < 8 && node; depth += 1) {
        const role = normalize(node.getAttribute?.('role'));
        const actionableRole = ['button', 'menuitem', 'menuitemradio', 'option'].includes(role);
        if (node !== sessionControl
            && !cardButtons.includes(node)
            && hasAllowLabel(node)
            && (hasClickSemantics(node) || actionableRole)) {
          return node;
        }
        node = parentOf(node);
      }
      return element;
    };
    const sessionMenuItemScore = (node, sessionLabel) => {
      const rect = rectObject(node);
      const role = normalize(node.getAttribute?.('role'));
      const tagName = node.tagName?.toLowerCase();
      const actionableRole = ['menuitem', 'menuitemradio', 'option'].includes(role);
      const semanticTag = ['button', 'a', 'summary'].includes(tagName);
      const inViewport = !!(rect
        && rect.bottom > 0
        && rect.top < (window.innerHeight || 0)
        && rect.right > 0
        && rect.left < (window.innerWidth || 0));
      const textLength = labelText(node).length;
      const area = rect ? rect.width * rect.height : Number.MAX_SAFE_INTEGER;
      return (sessionLabel ? 100000 : 0)
        + (actionableRole ? 10000 : 0)
        + (semanticTag ? 5000 : 0)
        + (inViewport ? 2000 : 0)
        + (hasClickSemantics(node) ? 1000 : 0)
        - Math.min(2000, textLength)
        - Math.min(2000, area / 100);
    };
    const sessionMenuItemFor = (item, sessionControl, cardButtons) => {
      let node = item;
      const candidates = [];
      for (let depth = 0; depth < 10 && node; depth += 1) {
        if (node !== sessionControl
            && !cardButtons.includes(node)
            && menuSurfaceFor(node)
            && visible(node)
            && hasClickSemantics(node)) {
          const labels = labelParts(node);
          const sessionLabel = labels.find(isSessionScope);
          const allowLabel = labels.find(isAllowLabel);
          if (sessionLabel || allowLabel) {
            candidates.push({ node, sessionLabel: !!sessionLabel });
          }
        }
        node = parentOf(node);
      }
      if (!candidates.length) return null;
      return candidates.sort((left, right) =>
        sessionMenuItemScore(right.node, right.sessionLabel)
        - sessionMenuItemScore(left.node, left.sessionLabel)
      )[0].node;
    };
    const sessionMenuItems = (sessionControl, cardButtons) => [...new Set(
      allInteractive()
        .map(item => {
          const sessionItem = sessionMenuItemFor(item, sessionControl, cardButtons);
          if (sessionItem) return sessionItem;
          if (!hasAllowLabel(item)
              || item === sessionControl
              || cardButtons.includes(item)
              || !menuSurfaceFor(item)) {
            return null;
          }
          return menuTargetFor(item);
        })
        .filter(Boolean)
    )].filter(item => {
      if (item === sessionControl || cardButtons.includes(item)) return false;
      return (isSessionScope(labelText(item)) || hasAllowLabel(item)) && visible(item);
    }).sort((left, right) =>
      sessionMenuItemScore(right, isSessionScope(labelText(right)))
      - sessionMenuItemScore(left, isSessionScope(labelText(left)))
    );
    const pointForElement = element => {
      const rect = rectObject(element);
      return rect ? {
        x: rect.left + rect.width / 2,
        y: rect.top + rect.height / 2
      } : null;
    };
    const approvalComponentData = element => {
      const ownKeys = node => {
        try { return Object.getOwnPropertyNames(node); } catch (_) { return []; }
      };
      const approvalActionPattern = /^(allow|approve|confirm|authorize|authorise|grant|permit)(?:_|$)/i;
      const targetFrom = action => action?.target_message_id
        || action?.targetMessageId
        || action?.target_messageID
        || '';
      const inspect = (source, domNode, fiberDepth) => {
        const props = source?.memoizedProps || source?.pendingProps || source?.props || source;
        const pluginData = props?.jit_plugin_data
          || props?.pluginData
          || props?.card?.jit_plugin_data;
        const fromServer = pluginData?.from_server || pluginData?.fromServer;
        const actions = fromServer?.actions || pluginData?.actions || props?.actions;
        if (!actions || typeof actions !== 'object') return null;
        const entries = Object.entries(actions);
        const actionKeys = entries.map(([key]) => key);
        const hasApprovalAction = actionKeys.some(action => approvalActionPattern.test(action));
        const targetMessageId = entries
          .filter(([key]) => approvalActionPattern.test(key))
          .map(([, action]) => targetFrom(action))
          .find(Boolean)
          || targetFrom(props)
          || '';
        const hasPluginAuthorizationData = Boolean(pluginData && fromServer);
        if (!hasApprovalAction || (!hasPluginAuthorizationData && !targetMessageId)) return null;
        return {
          root: domNode,
          actionKeys,
          targetMessageId,
          fiberDepth
        };
      };
      const seenFibers = new Set();
      let node = element;
      for (let depth = 0; depth < 30 && node; depth += 1) {
        for (const key of ownKeys(node)) {
          if (!key.startsWith('__reactProps$') && !key.startsWith('__reactFiber$')) continue;
          const value = node[key];
          const direct = inspect(value, node, 0);
          if (direct) return direct;
          if (!key.startsWith('__reactFiber$')) continue;
          let fiber = value;
          for (let fiberDepth = 1; fiberDepth < 50 && fiber; fiberDepth += 1) {
            if (seenFibers.has(fiber)) break;
            seenFibers.add(fiber);
            const found = inspect(fiber, node, fiberDepth);
            if (found) return found;
            fiber = fiber.return;
          }
        }
        node = parentOf(node);
      }
      return null;
    };
    const isOneShot = value => /\bonce\b|one time|this time|\u4e00\u6b21|\u672c\u6b21|\u6b64\u6b21/.test(normalize(value));
    const dispatchPointerClick = candidate => {
      const options = menuTriggerOptions.get(candidate) || {};
      const rect = candidate.getBoundingClientRect?.();
      const clientX = Number.isFinite(options.point?.x)
        ? options.point.x
        : (rect ? rect.left + Math.min(12, Math.max(1, rect.width / 2)) : 1);
      const clientY = Number.isFinite(options.point?.y)
        ? options.point.y
        : (rect ? rect.top + Math.min(12, Math.max(1, rect.height / 2)) : 1);
      const hit = options.coordinateOnly && document.elementFromPoint?.(clientX, clientY);
      const eventTarget = hit && (hit === candidate || candidate.contains?.(hit))
        ? hit : candidate;
      const pressed = {
        bubbles: true, cancelable: true, composed: true,
        button: 0, buttons: 1, clientX, clientY
      };
      eventTarget.dispatchEvent(new PointerEvent('pointerdown', {
        ...pressed, pointerId: 1, pointerType: 'mouse', isPrimary: true
      }));
      eventTarget.dispatchEvent(new MouseEvent('mousedown', pressed));
      eventTarget.dispatchEvent(new PointerEvent('pointerup', {
        ...pressed, buttons: 0, pointerId: 1, pointerType: 'mouse', isPrimary: true
      }));
      eventTarget.dispatchEvent(new MouseEvent('mouseup', { ...pressed, buttons: 0 }));
      // Dispatching an untrusted MouseEvent alone is not enough for every
      // React/Chromium renderer. Use the element's native activation path when
      // available; the synthetic event remains the fallback for test doubles
      // and custom elements without HTMLElement.click(). A split control must
      // keep the pointer coordinate so native click() cannot replace the
      // disclosure activation with the one-shot action.
      try {
        if (!options.coordinateOnly && typeof candidate.click === 'function') {
          candidate.click();
          return;
        }
      } catch (_) {}
      eventTarget.dispatchEvent(new MouseEvent('click', { ...pressed, buttons: 0 }));
    };
    const click = candidate => {
      try { dispatchPointerClick(candidate); }
      catch (_) { candidate.click?.(); }
    };
    const collectCard = candidate => {
      let container = parentOf(candidate);
      for (let index = 0; index < 30 && container; index += 1) {
        const localButtons = [];
        collectInteractive(container, localButtons, new Set());
        const cardButtons = [
          ...allInteractive().filter(button => {
            try { return container.contains?.(button); } catch (_) { return false; }
          }),
          ...localButtons
        ].filter((button, buttonIndex, all) =>
          all.indexOf(button) === buttonIndex
            && visible(button)
            && labelText(button).length <= 240
        );
        const cardLabels = cardButtons.map(label).filter(Boolean);
        const hasExplicitAllow = cardButtons.some(button =>
          isExplicitAllowLabel(approvalLabel(button))
        );
        const componentData = approvalComponentData(candidate);
        const hasComponentAuthorization = Boolean(componentData)
          || cardButtons.some(button => Boolean(approvalComponentData(button)));
        // The explicit allow control is the authorization-card marker. React
        // metadata is retained for diagnostics, but it must not block a real
        // Allow once/Allow button when the renderer omits or reshapes it.
        if (hasExplicitAllow || hasComponentAuthorization) {
          return {
            container, cardButtons, cardLabels, componentData,
            hasComponentAuthorization
          };
        }
        container = parentOf(container);
      }
      return null;
    };
    const confirmCardClosed = async (candidate, card) => {
      for (let index = 0; index < 30; index += 1) {
        await sleep(100);
        if (!candidate.isConnected || !visible(candidate)) return true;
        if (card?.container && (!card.container.isConnected || !visible(card.container))) return true;
        if (!collectCard(candidate)) return true;
      }
      return false;
    };
    const maxCards = 20;
    const approvedCards = [];
    let lastFailure = null;
    let lastMenuCandidates = [];
    for (let cardIndex = 0; cardIndex < maxCards; cardIndex += 1) {
      const candidates = allInteractive()
        .map((button, index) => ({ button, index, label: approvalLabel(button) }))
        .filter(candidate => hasAllowLabel(candidate.button))
        .map(candidate => ({ ...candidate, card: collectCard(candidate.button) }))
        .filter(candidate => candidate.card)
        .filter(candidate => {
          const hasExplicitAllow = candidate.card.cardButtons.some(button =>
            isExplicitAllowLabel(approvalLabel(button))
          );
          return !hasExplicitAllow || isExplicitAllowLabel(candidate.label);
        })
        .sort((left, right) => {
          const leftGeneric = isGenericConfirm(left.label) ? 1 : 0;
          const rightGeneric = isGenericConfirm(right.label) ? 1 : 0;
          const leftOneShot = isOneShot(left.label) ? 1 : 0;
          const rightOneShot = isOneShot(right.label) ? 1 : 0;
          const leftClickable = hasClickSemantics(left.button) ? 1 : 0;
          const rightClickable = hasClickSemantics(right.button) ? 1 : 0;
          const leftMenuStructure = hasMenuStructure(left.button) ? 1 : 0;
          const rightMenuStructure = hasMenuStructure(right.button) ? 1 : 0;
          return rightClickable - leftClickable
            || rightMenuStructure - leftMenuStructure
            || rightOneShot - leftOneShot
            || leftGeneric - rightGeneric
            || left.index - right.index;
        });
      const candidateLabels = candidates.map(candidate => candidate.label);
      const candidate = candidates[0];
      if (!candidate) {
        if (nativeOnly) {
          return {
            ok: false, clicked: false, confirmed: false,
            strategy: 'session-scope',
            error: 'session_scope_card_not_found_after_trigger',
            cardsApproved: 0, cardsRemaining: maxCards
          };
        }
        break;
      }

      const card = candidate.card;
      const cardButtons = card.cardButtons;
      const sessionControl = findMenuTrigger(card, candidate.button);

      if (sessionControl) {
        const menuTriggerLabel = label(sessionControl);
        const menuTriggerPointValue = menuTriggerPoint(sessionControl, candidate.button);
        let menuCandidates = [];
        let sessionOption = sessionMenuItems(sessionControl, cardButtons)[0] || null;
        if (!sessionOption) {
          // A self split-button has no separate DOM arrow. Do not synthesize a
          // click on its main action because that would grant Allow once.
          // Swift replays menuTriggerPointValue through trusted CDP input.
          if (sessionControl === candidate.button) {
            lastFailure = {
              ok: false, clicked: false, confirmed: false,
              strategy: 'session-scope', label: menuTriggerLabel,
              menuTriggerLabel, menuTriggerPoint: menuTriggerPointValue,
              candidateLabels,
              error: 'session_scope_native_input_required'
            };
            break;
          }
          try { dispatchPointerClick(sessionControl); }
          catch (error) {
            lastFailure = {
              ok: false, clicked: false, confirmed: false,
              strategy: 'session-scope', label: menuTriggerLabel,
              menuTriggerLabel, menuTriggerPoint: menuTriggerPointValue,
              candidateLabels,
              error: String(error?.message || error || 'session_scope_menu_click_failed')
            };
            break;
          }
        }
        for (let waitIndex = 0; waitIndex < 40 && !sessionOption; waitIndex += 1) {
          await sleep(100);
          if (!candidate.button.isConnected || !rendered(candidate.button)) {
            lastFailure = {
              ok: false, clicked: true, confirmed: false,
              strategy: 'session-scope', label: menuTriggerLabel,
              menuTriggerLabel, menuTriggerPoint: menuTriggerPointValue,
              candidateLabels,
              error: 'session_scope_menu_not_opened'
            };
            break;
          }
          menuCandidates = allInteractive().map(label).filter(Boolean).slice(-40);
          sessionOption = sessionMenuItems(sessionControl, cardButtons)[0] || null;
        }
        if (!sessionOption) {
          if (lastFailure?.error !== 'session_scope_menu_not_opened') {
            lastFailure = {
              ok: false, clicked: true, confirmed: false,
              strategy: 'session-scope', label: menuTriggerLabel,
              menuTriggerLabel, menuTriggerPoint: menuTriggerPointValue,
              candidateLabels, menuCandidates,
              error: 'session_scope_option_not_found'
            };
          }
          break;
        }
        const sessionScopeLabel = label(sessionOption);
        const sessionOptionPoint = pointForElement(sessionOption);
        const sessionOptionRect = rectObject(sessionOption);
        if (nativeOnly) {
          // Do not dispatch a synthetic menu-item click. Swift will replay
          // this exact point through trusted CDP input while the menu remains
          // open, then verify that the authorization card disappeared.
          return {
            ok: false, clicked: false, confirmed: false,
            strategy: 'session-scope', label: sessionScopeLabel,
            menuTriggerLabel, sessionScopeLabel,
            menuTriggerPoint: menuTriggerPointValue,
            sessionOptionPoint, sessionOptionRect, candidateLabels, menuCandidates,
            error: 'session_scope_native_option_required'
          };
        }
        try { dispatchPointerClick(sessionOption); }
        catch (error) {
          lastFailure = {
            ok: false, clicked: true, confirmed: false,
            strategy: 'session-scope', label: sessionScopeLabel,
            menuTriggerLabel, sessionScopeLabel,
            menuTriggerPoint: menuTriggerPointValue,
            sessionOptionPoint, sessionOptionRect, candidateLabels, menuCandidates,
            error: String(error?.message || error || 'session_scope_option_click_failed')
          };
          break;
        }
        const confirmed = await confirmCardClosed(candidate.button, card);
        if (!confirmed) {
          lastFailure = {
            ok: false, clicked: true, confirmed: false,
            strategy: 'session-scope', label: sessionScopeLabel,
            menuTriggerLabel, sessionScopeLabel,
            menuTriggerPoint: menuTriggerPointValue,
            sessionOptionPoint, candidateLabels, menuCandidates,
            error: 'session_scope_approval_not_confirmed'
          };
          break;
        }
        approvedCards.push({
          strategy: 'session-scope', label: sessionScopeLabel,
          menuTriggerLabel, sessionScopeLabel, candidateLabels, menuCandidates
        });
        await sleep(150);
        continue;
      }

      if (nativeOnly) {
        // A dedicated approval card must never fall through to the main
        // `Allow once` action when no session selector was found. Returning a
        // diagnostic keeps the card pending for a caller that can recover the
        // component's disclosure control with trusted input.
        lastFailure = {
          ok: false, clicked: false, confirmed: false,
          strategy: 'session-scope', label: candidate.label,
          candidateLabels,
          error: 'session_scope_menu_trigger_required'
        };
        break;
      }

      // Some ChatGPT builds expose only the single-card `Allow once` action;
      // it remains a legacy fallback only when this native session-scope path
      // is not active. A split control always returns through the branch above.
      const approvalStrategy = isOneShot(candidate.label)
        ? 'single-approval-allow-once'
        : 'single-approval';
      try { click(candidate.button); }
      catch (error) {
        lastFailure = {
          ok: false, clicked: false, confirmed: false,
          strategy: approvalStrategy, label: candidate.label,
          candidateLabels,
          error: String(error?.message || error || 'approval_click_failed')
        };
        break;
      }
      const confirmed = await confirmCardClosed(candidate.button, card);
      if (!confirmed) {
        lastFailure = {
          ok: false, clicked: true, confirmed: false,
          strategy: approvalStrategy, label: candidate.label,
          candidateLabels, error: 'approval_click_not_confirmed'
        };
        break;
      }
      approvedCards.push({
        strategy: approvalStrategy, label: candidate.label, candidateLabels
      });
      await sleep(150);
    }

    const clicked = approvedCards.length > 0 || lastFailure?.clicked === true;
    const confirmed = approvedCards.length > 0 && !lastFailure;
    if (lastFailure) {
      return {
        ...lastFailure,
        clicked,
        confirmed,
        cardsApproved: approvedCards.length,
        cardsRemaining: Math.max(0, maxCards - approvedCards.length)
      };
    }
    if (approvedCards.length === 0) {
      return { ok: true, clicked: false, confirmed: false, cardsApproved: 0, candidateLabels: [] };
    }
    const last = approvedCards[approvedCards.length - 1];
    return {
      ok: true, clicked: true, confirmed: true,
      strategy: approvedCards.length > 1 ? 'session-scope-batch' : last.strategy,
      label: last.label, menuTriggerLabel: last.menuTriggerLabel,
      sessionScopeLabel: last.sessionScopeLabel,
      candidateLabels: last.candidateLabels,
      menuCandidates: last.menuCandidates || [],
      cardsApproved: approvedCards.length,
      cardsRemaining: 0
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
    var approvalProbe: [String: Any]?
    var approvalScreenshotPath: String?
    if let detectionEval = CDPClient.evaluatePersistent(
      wsURLString: wsURL,
      expression: detectDedicatedAuthorizationJS()
    ),
       let detectionResult = detectionEval["result"] as? [String: Any],
       let detectionValue = ((detectionResult["result"] as? [String: Any])?["value"]
         ?? detectionResult["value"]) as? [String: Any],
       true {
      approvalProbe = detectionValue
      if detectionValue["found"] as? Bool == true {
        approvalDetection = detectionValue
        // Do not open a second CDP command for a diagnostic screenshot here.
        // The same live renderer target is handed directly to the component
        // action below; a screenshot/wake round-trip can stale or suspend the
        // hidden target between detection and authorization.
        approvalScreenshotPath = nil
        queueTrace(
          "task=approval-watcher stage=approval-ipc-detected strategy=per-card "
            + "target=\(targetId) selected=\(detectionValue["selectedLabel"] as? String ?? "none") "
            + "screenshot=\(approvalScreenshotPath ?? "none") "
            + approvalDetectionTraceFields(detectionValue)
        )
      }
    }
    // Use the same session-aware path for the general watcher. The legacy IPC
    // sweep only pressed the first `allow_once` control, which could bypass the
    // adjacent “allow for this conversation” menu and also missed role buttons
    // that are not literal <button> elements. Once a real card is detected,
    // never fall through to that one-shot fallback.
    if let detection = approvalDetection {
      let result = dedicatedApprovalWithNativeInput(
        port: endpoint.port,
        targetId: targetId,
        detection: detection
      ) ?? [
        "ok": false,
        "clicked": false,
        "confirmed": false,
        "strategy": "session-scope",
        "error": "session_aware_approval_eval_failed",
      ]
      let clicked = result["clicked"] as? Bool == true
      let confirmed = result["confirmed"] as? Bool == true
      let approvedCards = max(0, result["cardsApproved"] as? Int ?? (confirmed ? 1 : 0))
      let cardCount = max(1, approvedCards)
      let strategy = result["strategy"] as? String ?? "session-scope"
      let error = result["error"] as? String ?? "none"
      totalCandidates += cardCount
      if confirmed {
        totalApproved += cardCount
      } else if clicked {
        totalPending += cardCount
      } else {
        totalBlocked += cardCount
      }
      queueTrace(
        "task=approval-watcher stage=approval-ipc-result strategy="
          + "\(strategy) "
          + "target=\(targetId) approved=\(confirmed ? cardCount : 0) "
          + "pending=\(confirmed ? 0 : (clicked ? cardCount : 0)) "
          + "blocked=\(confirmed || clicked ? 0 : cardCount) "
          + "clicked=\(clicked) confirmed=\(confirmed) "
          + "cardsApproved=\(approvedCards) "
          + "error=\(error) "
          + "screenshot=\(approvalScreenshotPath ?? "none") "
          + approvalDetectionTraceFields(detection)
      )
      if !confirmed {
        let afterPath = captureHiddenChatScreenshot(
          port: endpoint.port,
          targetId: targetId,
          label: "approval-watcher-after"
        )
        queueTrace(
          "task=approval-watcher stage=approval-ipc-unconfirmed strategy="
            + "\(strategy) "
            + "target=\(targetId) beforeScreenshot=\(approvalScreenshotPath ?? "none") "
            + "afterScreenshot=\(afterPath ?? "none") "
            + "error=\(error)"
        )
      }
      continue
    }
    // If the component-root probe saw an approval-shaped control but could
    // not yet compute a complete card, do not fall through to the legacy
    // allow_once text sweep. Leaving it untouched gives the dedicated path a
    // later chance to recover the hidden component without granting the
    // one-shot permission.
    if let probe = approvalProbe {
      let candidateLabels = probe["candidateLabels"] as? [Any] ?? []
      let cardButtonLabels = probe["cardButtonLabels"] as? [Any] ?? []
      let componentActionKeys = probe["componentActionKeys"] as? [Any] ?? []
      if !candidateLabels.isEmpty || !cardButtonLabels.isEmpty || !componentActionKeys.isEmpty {
        queueTrace(
          "task=approval-watcher stage=approval-component-probe-blocked "
            + "strategy=session-scope target=\(targetId) "
            + approvalDetectionTraceFields(probe)
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
