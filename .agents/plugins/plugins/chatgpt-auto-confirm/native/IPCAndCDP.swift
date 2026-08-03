import ApplicationServices
import Cocoa
import Darwin
import Foundation
import SystemConfiguration

struct UnixIPCClient {
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

func jsonStringLiteral(_ value: String) -> String {
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

func cdpDebug(_ message: String) {
  guard ProcessInfo.processInfo.environment["CHATGPT_AUTO_CONFIRM_DEBUG"] == "1" else { return }
  FileHandle.standardError.write(Data("[chatgpt-auto-confirm] \(message)\n".utf8))
}

func isChatGptRendererTarget(_ target: [String: Any]) -> Bool {
  guard target["type"] as? String == "page",
        (target["webSocketDebuggerUrl"] as? String) != nil else { return false }
  let url = target["url"] as? String ?? ""
  let title = (target["title"] as? String ?? "").lowercased()
  return url.contains("chatgpt.com") || title.contains("chatgpt")
}

func isLoadedApprovalRendererTarget(_ target: [String: Any]) -> Bool {
  guard target["type"] as? String == "page",
        (target["webSocketDebuggerUrl"] as? String) != nil else { return false }
  let url = (target["url"] as? String ?? "").lowercased()
  if url.hasPrefix("app://-/index.html") && !url.contains("/avatar-overlay") {
    return true
  }
  return isChatGptRendererTarget(target)
}

struct CDPApprovalTarget {
  let port: Int
  let target: [String: Any]
}

struct CDPClient {
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

  static func allCookies(wsURLString: String, timeout: TimeInterval = 5.0) -> [[String: Any]] {
    guard let response = sendCommand(
      wsURLString: wsURLString,
      method: "Network.getAllCookies",
      paramsJSON: "{}",
      timeout: timeout
    ), let result = response["result"] as? [String: Any],
       let cookies = result["cookies"] as? [[String: Any]] else { return [] }
    return cookies
  }

  static func captureScreenshot(wsURLString: String, outputURL: URL) -> Bool {
    guard let response = sendCommand(
      wsURLString: wsURLString,
      method: "Page.captureScreenshot",
      paramsJSON: "{\"format\":\"png\",\"captureBeyondViewport\":true,\"fromSurface\":true}",
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

  // ChatGPT's Electron shell can report a stale NSRunningApplication hidden
  // flag even after a dedicated renderer has been launched.  Asking CDP to
  // transition the page to the hidden lifecycle state is harmless on builds
  // that do not expose the command (they return an error) and fixes the
  // renderer visibility on builds that do.
  @discardableResult
  static func setWebLifecycleHidden(wsURLString: String) -> Bool {
    guard let response = sendCommand(
      wsURLString: wsURLString,
      method: "Page.setWebLifecycleState",
      paramsJSON: "{\"state\":\"hidden\"}",
      timeout: 4.0
    ) else { return false }
    return response["error"] == nil
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

  static func createTarget(
    url: String,
    browserContextId: String?,
    background: Bool,
    portOverride: Int? = nil
  ) -> String? {
    guard let browserWS = browserWebSocketURL(portOverride: portOverride) else { return nil }
    func create(in contextId: String?) -> String? {
      let contextJSON = contextId.map {
        ",\"browserContextId\":\(jsonStringLiteral($0))"
      } ?? ""
      let paramsJSON: String
      if background {
        paramsJSON = "{\"url\":\(jsonStringLiteral(url)),\"background\":true\(contextJSON)}"
      } else {
        paramsJSON = "{\"url\":\(jsonStringLiteral(url)),\"background\":false\(contextJSON)}"
      }
      guard let response = sendCommand(
            wsURLString: browserWS,
            method: "Target.createTarget",
            paramsJSON: paramsJSON,
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

  static func createBackgroundTarget(url: String, browserContextId: String?, portOverride: Int? = nil) -> String? {
    createTarget(
      url: url,
      browserContextId: browserContextId,
      background: true,
      portOverride: portOverride
    )
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
