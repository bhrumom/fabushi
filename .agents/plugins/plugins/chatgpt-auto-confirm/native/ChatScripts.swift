import ApplicationServices
import Cocoa
import Darwin
import Foundation
import SystemConfiguration


// MARK: - CDP interaction JS scripts

func taskReportContract() -> String {
  """

持续执行要求：不要只描述下一步、不要阶段性收尾、不要回复等待时间。没有完成目标不要停，一直工作下去直到实现目标！需要时间跑的异步任务（如 GitHub Actions）必须自己运行 sleep 睡眠命令，睡眠之后起来检查是否完成，未完成则继续执行 sleep 等待，直到出结果并立刻继续。全部目标完成时直接给出正常最终结果，不要输出机器模板；小程序会把该结果发送到新的独立验收 Chat。

只有出现当前权限和工具确实无法绕过的阻塞，或平台硬性终止本次会话且任务仍未完成时，才在回答末尾输出以下未完成续作模板。不要把 JSON 放进 Markdown 代码块：
MAHAYANA_TASK_REPORT_V1_BEGIN
{"protocol":"mahayana.task-report.v1","status":"incomplete|blocked","summary":"本轮实际结果","completed":["已完成项"],"remaining":["未完成项"],"blockers":["真实卡点；没有则用空数组"],"verification":["已取得的验证证据"],"next_connector":"下一新 Chat 要使用的 connector；无需切换则为空字符串","next_task":"给下一个工作 Chat 的完整可执行续作指令"}
MAHAYANA_TASK_REPORT_V1_END
未完成时 remaining 和 next_task 必须非空。云端 GitHub 阶段 next_connector 填 GitHub，本地阶段填 bhrum2。
"""
}

func messageWithTaskReportContract(_ message: String) -> String {
  message.contains("MAHAYANA_TASK_REPORT_V1_BEGIN") ? message : message + taskReportContract()
}

func parseTaskReport(_ content: String) -> [String: Any]? {
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
  guard (0...604_800).contains(waitSeconds) else { return nil }
  if status == "complete" {
    guard remaining.isEmpty, blockers.isEmpty,
          nextTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
  } else {
    guard !nextTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
  }
  return report
}

func continuationFromTaskReport(
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

func relayFreshChatContinuation(_ params: [String: Any]) -> Never {
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

func jsEscape(_ text: String) -> String {
  text
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")
    .replacingOccurrences(of: "\n", with: "\\n")
    .replacingOccurrences(of: "\r", with: "\\r")
    .replacingOccurrences(of: "\t", with: "\\t")
}

func verifySentMessageJS(message: String) -> String {
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

func sendMessageJS(
  message: String,
  connector: String?,
  newChat: Bool = false,
  expectedConversationId: String? = nil
) -> String {
  let escapedMessage = jsEscape(message)
  let connectorPart: String
  if let connector, !connector.isEmpty {
    connectorPart = "\"\(jsEscape(connector))\""
  } else {
    connectorPart = "null"
  }
  let newChatBool = newChat ? "true" : "false"
  let expectedConversation = jsonStringLiteral(expectedConversationId ?? "")
  return """
  (async () => {
    const connector = \(connectorPart);
    const message = "\(escapedMessage)";
    const newChat = \(newChatBool);
    const expectedConversationId = \(expectedConversation);
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
    const dispatchPointerClick = element => {
      const rect = element?.getBoundingClientRect?.();
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
      element.dispatchEvent(new PointerEvent('pointerdown', {
        ...pressed,
        pointerId: 1,
        pointerType: 'mouse',
        isPrimary: true
      }));
      element.dispatchEvent(new MouseEvent('mousedown', pressed));
      element.dispatchEvent(new PointerEvent('pointerup', {
        ...pressed,
        buttons: 0,
        pointerId: 1,
        pointerType: 'mouse',
        isPrimary: true
      }));
      element.dispatchEvent(new MouseEvent('mouseup', { ...pressed, buttons: 0 }));
      element.dispatchEvent(new MouseEvent('click', { ...pressed, buttons: 0 }));
    };
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

    function quickChatRoot() {
      return document.querySelector(
        '[data-pip-obstacle="quick-chat"], [data-quick-chat-drag-handle]'
      )?.closest('[role="dialog"], section, div') || null;
    }

    function findTextarea() {
      const quickRoot = quickChatRoot();
      return quickRoot
        ? quickRoot.querySelector('#prompt-textarea, [contenteditable="true"]')
        : document.querySelector('#prompt-textarea')
        || document.querySelector('[contenteditable="true"][data-placeholder]')
        || document.querySelector('[contenteditable="true"]');
    }

    function findSendButton() {
      const scope = quickChatRoot() || document;
      return scope.querySelector('[data-testid="send-button"]')
        || scope.querySelector('button[aria-label="Send prompt"]')
        || scope.querySelector('button[aria-label="发送"]');
    }

    function chatSurfaceEvidence() {
      const quickRoot = quickChatRoot();
      const scope = quickRoot || document;
      const modeControls = [...scope.querySelectorAll('button, [role="button"]')]
        .filter(visible)
        .map(button => normalize([
          button.textContent,
          button.getAttribute('aria-label'),
          button.getAttribute('title')
        ].filter(Boolean).join(' ')))
        .filter(label => /^(chat|work|聊天|工作)$|current mode|当前模式/i.test(label))
        .slice(0, 12);
      const relevantControls = [...scope.querySelectorAll('button, [role="button"]')]
        .filter(visible)
        .map(button => normalize([
          button.textContent,
          button.getAttribute('aria-label'),
          button.getAttribute('title'),
          button.getAttribute('data-testid')
        ].filter(Boolean).join(' ')))
        .filter(label => /model|模型|gpt|thinking|instant|high|medium|pro|reasoning|推理|项目|project|folder|文件夹|work/i.test(label))
        .slice(0, 32);
      return {
        url: window.location.href || '',
        quickChatRoot: !!quickRoot,
        hasInput: !!findTextarea(),
        workComposer: !!document.querySelector('[data-codex-composer="true"]'),
        chatMode: chatModeIsActive(),
        modeControls,
        relevantControls
      };
    }

    function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

    function inputText(el) {
      if (!el) return '';
      return el.tagName === 'TEXTAREA' || el.tagName === 'INPUT'
        ? (el.value || '')
        : (el.innerText || el.textContent || '');
    }

    function userMessages() {
      const scope = quickChatRoot() || document;
      const web = [...scope.querySelectorAll('[data-message-author-role="user"]')];
      const app = [...scope.querySelectorAll('[data-user-message-bubble]')];
      return web.length > 0 ? web : app;
    }

    function currentConversationId() {
      const raw = document.querySelector('[data-above-composer-conversation-id]')
        ?.getAttribute('data-above-composer-conversation-id') || '';
      return raw.startsWith('chatgpt:') ? raw.slice('chatgpt:'.length) : raw;
    }

    function conversationIsExpected() {
      return !expectedConversationId || currentConversationId() === expectedConversationId;
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
    const desiredQuickChatModel = 'Thinking';

    function modelPickerButton() {
      const input = findTextarea();
      const send = findSendButton();
      const scope = quickChatRoot() || document;

      const controlLabel = button => normalize([
        button?.textContent,
        button?.getAttribute('aria-label'),
        button?.getAttribute('title'),
        button?.getAttribute('data-testid')
      ].filter(Boolean).join(' ')).toLowerCase();
      const isProjectPicker = button => {
        const label = controlLabel(button);
        return /(?:choose|select|new)\\s+project|project\\s+(?:source|folder)|source\\s+folders|add\\s+folders|选择项目|项目文件夹|源文件夹|添加文件夹|新建项目|创建项目/i.test(label);
      };
      const isModelPickerLabel = button => {
        if (isProjectPicker(button)) return false;
        const label = controlLabel(button);
        return label.includes('chatgpt 模型')
          || /select chatgpt model/i.test(label)
          || label.includes('model selector')
          || label.includes('choose model')
          || label.includes('选择模型')
          || label.includes('intelligence')
          || label.includes('reasoning')
          || label.includes('推理')
          || label.includes('高')
          || label.includes('智能')
          // The hosted Chat renderer currently concatenates hidden model
          // labels into one button, e.g. "5.6 TerraExtra High5.6 SolMedium".
          // Word boundaries therefore miss "High5.6" and "SolMedium".
          || /(?:gpt|model|thinking|instant|high|medium|pro|terra|sol)/i.test(label);
      };

      const testIdButton = scope.querySelector('[data-testid="model-switcher"], [data-testid="composer-model-selector"], [data-testid="model-picker"], [data-testid="chat-model-selector"]');
      if (testIdButton && visible(testIdButton) && !isProjectPicker(testIdButton)) return testIdButton;

      const composer = input?.closest('form') || input?.parentElement?.parentElement;

      // Prefer an explicitly labelled model control. The composer can also contain
      // project/source pickers, so a generic aria-haspopup match is not sufficient.
      const explicit = [...scope.querySelectorAll(
        'button[aria-label], [role="button"][aria-label]'
      )].filter(button => {
        return visible(button) && button !== send && isModelPickerLabel(button);
      }).sort((left, right) => {
        const leftInComposer = composer?.contains(left) ? 0 : 1;
        const rightInComposer = composer?.contains(right) ? 0 : 1;
        if (leftInComposer !== rightInComposer) return leftInComposer - rightInComposer;
        const inputRect = input?.getBoundingClientRect();
        if (!inputRect) return 0;
        const l = left.getBoundingClientRect();
        const r = right.getBoundingClientRect();
        return Math.abs(inputRect.bottom - l.bottom) - Math.abs(inputRect.bottom - r.bottom);
      })[0] || null;
      if (explicit) return explicit;

      // Use includes() not === to handle buttons with extra SVG/icon text appended
      const textMatch = [...scope.querySelectorAll('button, [role="button"]')].find(button => {
        if (!visible(button) || button === send) return false;
        return isModelPickerLabel(button);
      });
      if (textMatch) return textMatch;

      // Only use a generic popup as a last resort, and only when its label still
      // looks like a model control. This prevents "Choose project" from opening
      // the project menu and being misreported as a missing High-reasoning choice.
      const popupButton = [...(composer || document).querySelectorAll(
        '[aria-haspopup], [aria-haspopup="menu"], [aria-haspopup="listbox"], [aria-haspopup="true"]'
      )].find(button => visible(button) && button !== send && isModelPickerLabel(button));
      if (popupButton) return popupButton;

      const fallbackScope = composer || document.body;
      const candidates = [...fallbackScope.querySelectorAll(
        'button, [role="button"], [data-testid], [aria-haspopup="menu"]'
      )].filter(button => {
        if (!visible(button) || button === send) return false;
        if (isProjectPicker(button)) return false;
        return isModelPickerLabel(button);
      });
      return candidates.sort((left, right) => {
        const leftPopup = left.getAttribute('aria-haspopup') ? 0 : 1;
        const rightPopup = right.getAttribute('aria-haspopup') ? 0 : 1;
        if (leftPopup !== rightPopup) return leftPopup - rightPopup;
        return right.getBoundingClientRect().width - left.getBoundingClientRect().width;
      })[0] || null;
    }

    function visibleModelMenus() {
      const selectors = [
        '[role="menu"]', '[role="listbox"]', '[data-composer-overlay-floating-ui]',
        '[data-radix-menu-content]', '[data-radix-popper-content-wrapper]',
        '[data-state="open"]', '.popover'
      ].join(',');
      return [...document.querySelectorAll(selectors)].filter(visible);
    }

    function exactModelChoice(root, label) {
      const scope = root || document;
      const target = normalize(label).toLowerCase();
      const candidates = [...scope.querySelectorAll(
        'button, [role="menuitem"], [role="menuitemradio"], [role="option"], [data-list-navigation-item="true"]'
      )].filter(element => {
        if (!visible(element)) return false;
        const text = normalize(element.textContent).toLowerCase().replace(/>/g, '').trim();
        return text === target;
      });
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
      )].filter(element => {
        if (!visible(element)) return false;
        const text = normalize(element.textContent).toLowerCase().replace(/>/g, '').trim();
        return text === target;
      });
    }

    function allPrefixedModelChoices(label) {
      const target = normalize(label).toLowerCase();
      return [...document.querySelectorAll(
        'button, [role="menuitem"], [role="menuitemradio"], [role="option"], [data-list-navigation-item="true"]'
      )].filter(element => {
        if (!visible(element)) return false;
        const text = normalize(element.textContent).toLowerCase().replace(/>/g, '').trim();
        return text === target || text.startsWith(`${target} `);
      });
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
      // Dismiss promotional modals before looking for the model picker. The
      // desktop app can show localized Fast-mode announcements over a newly
      // created Chat; their buttons otherwise look like the only open menu.
      const neutralPromoLabels = new Set([
        'try gpt-5.6 sol now', 'okay', 'got it',
        'use standard speed', 'continue with standard speed',
        '使用标准速度', '使用標準速度',
        'not now', 'maybe later', '暂不', '暫不', '以后再说', '稍後再說'
      ]);
      for (let attempt = 0; attempt < 3; attempt += 1) {
        const promoButton = [...document.querySelectorAll('button')].find(btn => {
          const text = normalize([
            btn.textContent,
            btn.getAttribute('aria-label'),
            btn.getAttribute('title')
          ].filter(Boolean).join(' ')).toLowerCase();
          return visible(btn) && neutralPromoLabels.has(text);
        });
        if (!promoButton) break;
        promoButton.click();
        await sleep(600);
      }
      let picker = null;
      for (let i = 0; i < 40; i++) {
        picker = modelPickerButton();
        if (picker) break;
        await sleep(100);
      }
      if (!picker) {
        return {
          ok: false,
          error: 'model_picker_not_found',
          model: desiredModel,
          reasoning: desiredReasoning,
          modelConfirmed: false,
          reasoningConfirmed: false,
          surface: chatSurfaceEvidence()
        };
      }
      const pickerBefore = normalize([
        picker.textContent,
        picker.getAttribute('aria-label'),
        picker.getAttribute('title')
      ].filter(Boolean).join(' '));
      let selectedLabel = normalize(picker.textContent).toLowerCase();
      // Desktop Quick Chat is the authenticated orchestration surface. It
      // exposes ChatGPT choices such as Instant/Thinking, not the Codex
      // GPT-5.6 Sol reasoning menu. Require its strongest reasoning choice
      // before sending, while the task contract separately requires downstream
      // Codex/devspace execution to use GPT-5.6 Sol / High.
      const quickChatModelSurface = !!quickChatRoot()
        || ['instant', 'thinking', 'pro', 'high', 'medium'].some(label =>
          selectedLabel === label || selectedLabel.startsWith(`${label} `)
        );
      if (quickChatModelSurface) {
        let quickChatChoiceClicked = false;
        let quickChatConfirmed = selectedLabel === 'thinking'
          || selectedLabel === '思考'
          || selectedLabel.startsWith('thinking ')
          || selectedLabel === 'high'
          || selectedLabel === '高'
          || selectedLabel.startsWith('high ');
        if (!quickChatConfirmed) {
          // The desktop ChatGPT model switcher is a Radix trigger that opens
          // on pointerdown; HTMLElement.click() alone leaves the menu closed.
          dispatchPointerClick(picker);
          await sleep(500);
          const thinkingChoice = [
            ...allPrefixedModelChoices('Thinking'),
            ...allPrefixedModelChoices('思考'),
            ...allPrefixedModelChoices('High'),
            ...allPrefixedModelChoices('高')
          ][0] || null;
          if (thinkingChoice) {
            if (!selectedChoice(thinkingChoice)) thinkingChoice.click();
            quickChatChoiceClicked = true;
            await sleep(350);
          }
          picker = modelPickerButton();
          selectedLabel = normalize(picker?.textContent).toLowerCase();
          quickChatConfirmed = selectedLabel === 'thinking'
            || selectedLabel === '思考'
            || selectedLabel.startsWith('thinking ')
            || selectedLabel === 'high'
            || selectedLabel === '高'
            || selectedLabel.startsWith('high ');
        }
        if (!quickChatConfirmed) {
          return {
            ok: false,
            error: 'quick_chat_thinking_not_selected',
            model: desiredQuickChatModel,
            reasoning: desiredReasoning,
            modelConfirmed: false,
            reasoningConfirmed: false,
            pickerBefore,
            selectedLabel,
            quickChatChoiceClicked,
            visibleMenuText: visibleModelMenus()
              .map(menu => normalize(menu.textContent).slice(0, 500)),
            surface: chatSurfaceEvidence()
          };
        }
        return {
          ok: true,
          model: desiredQuickChatModel,
          reasoning: desiredReasoning,
          modelConfirmed: true,
          reasoningConfirmed: true,
          pickerBefore,
          selectedLabel,
          pickerEvidence: 'quick-chat-thinking-selection',
          quickChatChoiceClicked,
          verificationModelSelected: true,
          submenuHighSelected: true,
          downstreamModel: desiredModel,
          downstreamReasoning: desiredReasoning
        };
      }
      let reasoningConfirmed = selectedLabel === 'high'
        || selectedLabel === '高'
        || selectedLabel.startsWith('high ');
      let modelConfirmed = pickerBefore.toLowerCase().includes(desiredModel.toLowerCase());
      let modelChoiceClicked = false;
      let highChoiceClicked = false;

      if (!reasoningConfirmed || !modelConfirmed) {
        dispatchPointerClick(picker);
        await sleep(500);

        let modelChoice = allExactModelChoices(desiredModel).find(choice =>
          visibleModelMenus().some(menu => menu.contains(choice))
        ) || allExactModelChoices(desiredModel)[0] || null;
        if (modelChoice) {
          if (!selectedChoice(modelChoice)) modelChoice.click();
          modelChoiceClicked = true;
          modelConfirmed = true;
          await sleep(350);
        }

        let highChoice = [
          ...allExactModelChoices('High'),
          ...allExactModelChoices('高')
        ].find(choice =>
          visibleModelMenus().some(menu => menu.contains(choice))
        ) || null;
        if (!highChoice) {
          const reasoningBtn = [...document.querySelectorAll('button')].find(b => {
             const t = normalize(b.textContent).toLowerCase();
             const a = normalize(b.getAttribute('aria-label')).toLowerCase();
             return t.includes('reasoning') || a.includes('reasoning') || t.includes('推理') || a.includes('推理');
          });
          if (reasoningBtn) {
             reasoningBtn.click();
          } else {
             picker = modelPickerButton();
             picker?.click();
          }
          await sleep(400);
          highChoice = [
            ...allExactModelChoices('High'),
            ...allExactModelChoices('高')
          ].find(choice =>
            visibleModelMenus().some(menu => menu.contains(choice))
          ) || null;
        }
        if (highChoice) {
          if (!selectedChoice(highChoice)) highChoice.click();
          highChoiceClicked = true;
          await sleep(350);
        }

        picker = modelPickerButton();
        const pickerAfter = normalize([
          picker?.textContent,
          picker?.getAttribute('aria-label'),
          picker?.getAttribute('title')
        ].filter(Boolean).join(' '));
        selectedLabel = normalize(picker?.textContent).toLowerCase();
        reasoningConfirmed = selectedLabel === 'high'
          || selectedLabel === '高'
          || selectedLabel.startsWith('high ')
          || selectedChoice(highChoice)
          || highChoiceClicked;
        modelConfirmed = modelConfirmed
          || pickerAfter.toLowerCase().includes(desiredModel.toLowerCase());
      }
      if (!reasoningConfirmed) {
        return {
          ok: false,
          error: 'reasoning_high_not_selected',
          model: desiredModel,
          reasoning: desiredReasoning,
          modelConfirmed,
          reasoningConfirmed: false,
          pickerBefore,
          selectedLabel,
          modelChoiceClicked,
          highChoiceClicked,
          visibleMenuText: visibleModelMenus()
            .map(menu => normalize(menu.textContent).slice(0, 500)),
          surface: chatSurfaceEvidence()
        };
      }
      if (!modelConfirmed) {
        return {
          ok: false,
          error: 'target_model_not_selected',
          model: desiredModel,
          reasoning: desiredReasoning,
          modelConfirmed: false,
          reasoningConfirmed: true,
          pickerBefore,
          selectedLabel,
          modelChoiceClicked,
          highChoiceClicked,
          visibleMenuText: visibleModelMenus()
            .map(menu => normalize(menu.textContent).slice(0, 500)),
          surface: chatSurfaceEvidence()
        };
      }

      return {
        ok: true,
        model: desiredModel,
        reasoning: desiredReasoning,
        modelConfirmed,
        reasoningConfirmed: true,
        pickerBefore,
        selectedLabel,
        pickerEvidence: 'selected_button_state',
        verificationModelSelected: modelConfirmed,
        submenuHighSelected: highChoiceClicked || reasoningConfirmed
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
      const quickRoot = quickChatRoot();
      const workComposer = !quickRoot
        && !!document.querySelector('[data-codex-composer="true"]');
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
      const chatModel = [...document.querySelectorAll('button')].some(button => {
        const label = button.getAttribute('aria-label') || '';
        return label.includes('ChatGPT 模型') || /select chatgpt model/i.test(label);
      });
      const webChat = window.location.protocol === 'https:'
        && window.location.hostname === 'chatgpt.com';
      // The desktop app can leave the Work composer mounted while a stale
      // ChatGPT flag or model label is still present. Work must never pass as
      // Chat: the top-level Chat/Work switch is authoritative here.
      return (!!quickRoot || currentChatGPTMode || chatModel || webChat)
        && !!findTextarea() && !workComposer;
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
    record('chat_surface', true, {
      surface: 'chat', workerUsed: false, surfaceEvidence: chatSurfaceEvidence()
    });
    if (!conversationIsExpected()) {
      return fail('conversation_guard', 'conversation_changed_before_send', {
        expectedConversationId,
        actualConversationId: currentConversationId() || null
      });
    }

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
    let ta2 = null;
    let actualInput = '';
    let inputConfirmed = false;
    for (let attempt = 0; attempt < 8 && !inputConfirmed; attempt += 1) {
      if (!conversationIsExpected()) {
        return fail('conversation_guard', 'conversation_changed_during_send', {
          expectedConversationId,
          actualConversationId: currentConversationId() || null,
          inputAttempt: attempt
        });
      }
      // React can replace the contenteditable after a new-chat or connector
      // transition. Reacquire it on every attempt instead of writing through
      // a detached node.
      ta2 = findTextarea();
      if (!ta2 || !document.contains(ta2)) {
        await sleep(250);
        continue;
      }
      const before = normalize(inputText(ta2));
      const connectorStillSelected = !connector ||
        before.includes(connector.toLowerCase()) ||
        connectorEvidence(connector.toLowerCase()).length > 0;
      if (!(before.endsWith(normalize(message)) && connectorStillSelected)) {
        ta2.focus();
        if (connector && attempt === 0) {
          appendTextPreservingConnector(ta2, message);
        } else {
          replaceText(ta2, message);
        }
      }
      await sleep(250);
      const currentInput = findTextarea();
      if (!currentInput || !document.contains(currentInput)) continue;
      ta2 = currentInput;
      actualInput = inputText(ta2);
      const normalizedActualInput = normalize(actualInput);
      inputConfirmed = connector
        ? normalizedActualInput.endsWith(normalize(message))
          && (normalizedActualInput.includes(connector.toLowerCase())
            || connectorEvidence(connector.toLowerCase()).length > 0)
        : normalizedActualInput === normalize(message);
    }
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
    if (!conversationIsExpected()) {
      return fail('conversation_guard', 'conversation_changed_before_dispatch', {
        expectedConversationId,
        actualConversationId: currentConversationId() || null
      });
    }

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

func stopCurrentResponseJS() -> String {
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

func getReplyJS() -> String {
  #"""
  (async () => {
    const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
    const visible = element => !!(element && (element.offsetWidth || element.offsetHeight || element.getClientRects().length));
    const quickChatRoot = document.querySelector(
      '[data-pip-obstacle="quick-chat"], [data-quick-chat-drag-handle]'
    )?.closest('[role="dialog"], section, div');
    const main = quickChatRoot || document.querySelector('main') || document.body;
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

    const webMessages = [...main.querySelectorAll('[data-message-author-role="assistant"]')];
    const appMessages = [...main.querySelectorAll('[data-local-conversation-final-assistant]')];
    const messages = webMessages.length > 0 ? webMessages : appMessages;
    const webUsers = [...main.querySelectorAll('[data-message-author-role="user"]')];
    const appUsers = [...main.querySelectorAll('[data-user-message-bubble]')];
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
    let stopBtn = stopSelectors.map(selector => main.querySelector(selector)).find(visible) || null;
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

func chatStatusJS() -> String {
  #"""
  (() => {
  const quickChatRoot = document.querySelector(
    '[data-pip-obstacle="quick-chat"], [data-quick-chat-drag-handle]'
  )?.closest('[role="dialog"], section, div');
  const scope = quickChatRoot || document;
  const textarea = scope.querySelector('#prompt-textarea')
    || document.querySelector('[contenteditable="true"]');
  const hasInput = !!textarea;

  const stopBtn = scope.querySelector('[data-testid="stop-button"]')
    || scope.querySelector('[aria-label="Stop streaming"]')
    || scope.querySelector('[aria-label="Stop responding"]')
    || scope.querySelector('[aria-label="停止输出"]')
    || scope.querySelector('[aria-label="停止回答"]')
    || scope.querySelector('button[aria-label="停止"]')
    || scope.querySelector('button[data-testid*="stop"]');
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
  const normalizedMode = mode.toLowerCase();
  const currentChatGPTMode = normalizedMode.includes('current mode: chatgpt')
    || (normalizedMode.includes('当前模式') && normalizedMode.includes('chatgpt'));
  const chatModel = [...document.querySelectorAll('button')].some(button => {
    const label = button.getAttribute('aria-label') || '';
    return label.includes('ChatGPT 模型') || /select chatgpt model/i.test(label);
  });
  const webChat = window.location.protocol === 'https:'
    && window.location.hostname === 'chatgpt.com';
  // A stale mode flag must not hide the Work composer from surface checks.
  const workComposer = !quickChatRoot
    && !!document.querySelector('[data-codex-composer="true"]');
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
    chatMode: (!!quickChatRoot || currentChatGPTMode || chatModel || webChat)
      && hasInput && !workComposer,
    surface: (!!quickChatRoot || currentChatGPTMode || chatModel || webChat)
      && hasInput && !workComposer ? 'chat' : 'not-chat',
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

func addConnectorJS(connector: String) -> String {
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
    const quickChatRoot = document.querySelector(
      '[data-pip-obstacle="quick-chat"], [data-quick-chat-drag-handle]'
    )?.closest('[role="dialog"], section, div');
    const input = quickChatRoot?.querySelector(
      '#prompt-textarea, [contenteditable="true"]'
    ) || document.querySelector('#prompt-textarea')
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
    if ((!quickChatRoot && !chatModel && !webChat)
        || (!quickChatRoot && document.querySelector('[data-codex-composer="true"]'))) {
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

func sanitizeJSONValue(_ value: Any) -> Any {
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

func cdpEvaluateOnChatGPT(
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
