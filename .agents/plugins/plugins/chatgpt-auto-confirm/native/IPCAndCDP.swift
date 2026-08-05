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

  private static func decodeTargetPayload(_ data: Data) -> [[String: Any]] {
    guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      return []
    }
    return array
  }

  private static func decodeHTTPBody(_ response: Data) -> Data? {
    let bytes = Array(response)
    guard bytes.count >= 4 else { return nil }
    var separatorIndex: Int?
    for index in 0...(bytes.count - 4) {
      if bytes[index] == 13, bytes[index + 1] == 10,
         bytes[index + 2] == 13, bytes[index + 3] == 10 {
        separatorIndex = index
        break
      }
    }
    guard let separatorIndex else { return nil }
    let header = String(
      decoding: bytes[0..<separatorIndex],
      as: UTF8.self
    ).lowercased()
    let body = Array(bytes[(separatorIndex + 4)...])
    guard header.contains("transfer-encoding: chunked") else {
      return Data(body)
    }

    var decoded: [UInt8] = []
    var offset = 0
    while offset < body.count {
      var lineEnd: Int?
      if body.count >= offset + 2 {
        for index in offset...(body.count - 2) {
          if body[index] == 13, body[index + 1] == 10 {
            lineEnd = index
            break
          }
        }
      }
      guard let lineEnd else { return nil }
      let lengthToken = String(
        String(decoding: body[offset..<lineEnd], as: UTF8.self)
          .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true)
          .first ?? ""
      )
      guard let length = UInt64(lengthToken, radix: 16),
            length <= UInt64(Int.max) else {
        return nil
      }
      offset = lineEnd + 2
      if length == 0 { return Data(decoded) }
      let chunkLength = Int(length)
      guard offset + chunkLength + 2 <= body.count else { return nil }
      decoded.append(contentsOf: body[offset..<(offset + chunkLength)])
      offset += chunkLength
      guard body[offset] == 13, body[offset + 1] == 10 else { return nil }
      offset += 2
    }
    return Data(decoded)
  }

  private static func fetchTargetsOverLocalSocket(port: Int) -> [[String: Any]] {
    let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else { return [] }
    defer { Darwin.close(fd) }

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = in_port_t(UInt16(port).bigEndian)
    let addressHost = host() == "localhost" ? "127.0.0.1" : host()
    guard addressHost.withCString({
      Darwin.inet_pton(AF_INET, $0, &address.sin_addr)
    }) == 1 else {
      return []
    }

    let originalFlags = Darwin.fcntl(fd, F_GETFL, 0)
    guard originalFlags >= 0,
          Darwin.fcntl(fd, F_SETFL, originalFlags | O_NONBLOCK) == 0 else {
      return []
    }
    let deadline = Date().addingTimeInterval(1.8)
    func waitForSocketEvent(_ events: Int16) -> Bool {
      while Date() < deadline {
        let remainingMs = Int32(
          max(1, min(1_800, Int(deadline.timeIntervalSinceNow * 1_000)))
        )
        var descriptor = pollfd()
        descriptor.fd = fd
        descriptor.events = events
        descriptor.revents = 0
        let result = Darwin.poll(&descriptor, 1, remainingMs)
        if result > 0 {
          return descriptor.revents & (events | Int16(POLLERR | POLLHUP)) != 0
        }
        if result < 0, errno == EINTR { continue }
        return false
      }
      return false
    }
    let connectResult = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
        Darwin.connect(
          fd,
          socketAddress,
          socklen_t(MemoryLayout<sockaddr_in>.size)
        )
      }
    }
    if connectResult != 0 {
      guard errno == EINPROGRESS else { return [] }
      guard waitForSocketEvent(Int16(POLLOUT)) else { return [] }
      var socketError: Int32 = 0
      var socketErrorLength = socklen_t(MemoryLayout<Int32>.size)
      guard Darwin.getsockopt(
        fd,
        SOL_SOCKET,
        SO_ERROR,
        &socketError,
        &socketErrorLength
      ) == 0, socketError == 0 else {
        return []
      }
    }

    let request = Data(
      "GET /json HTTP/1.1\r\nHost: \(addressHost)\r\nConnection: close\r\n\r\n".utf8
    )
    var sent = 0
    while sent < request.count {
      guard waitForSocketEvent(Int16(POLLOUT)) else { return [] }
      let written = request.withUnsafeBytes { bytes -> Int in
        guard let baseAddress = bytes.baseAddress else { return 0 }
        return Darwin.send(
          fd,
          baseAddress.advanced(by: sent),
          request.count - sent,
          0
        )
      }
      if written > 0 {
        sent += written
      } else if errno != EAGAIN && errno != EWOULDBLOCK {
        return []
      }
    }

    var response = Data()
    var buffer = [UInt8](repeating: 0, count: 16 * 1024)
    while response.count < 4 * 1024 * 1024, waitForSocketEvent(Int16(POLLIN)) {
      let received = buffer.withUnsafeMutableBytes { bytes -> Int in
        guard let baseAddress = bytes.baseAddress else { return 0 }
        return Darwin.recv(fd, baseAddress, bytes.count, 0)
      }
      if received > 0 {
        response.append(contentsOf: buffer.prefix(received))
      } else if received == 0 || (errno != EAGAIN && errno != EWOULDBLOCK) {
        break
      }
    }
    guard let body = decodeHTTPBody(response) else { return [] }
    return decodeTargetPayload(body)
  }

  private static func fetchTargetsOverURLSession(port: Int) -> [[String: Any]] {
    guard let url = URL(string: "http://\(host()):\(port)/json") else { return [] }
    var request = URLRequest(url: url)
    request.timeoutInterval = 1.5
    var resultData: Data?
    let semaphore = DispatchSemaphore(value: 0)
    let task = URLSession.shared.dataTask(with: request) { data, _, _ in
      resultData = data
      semaphore.signal()
    }
    task.resume()
    if semaphore.wait(timeout: .now() + 1.8) == .timedOut {
      // A dedicated Electron process can keep an unopened CDP port around
      // while its first renderer is starting.  Cancel the request when the
      // bounded probe expires so timed-out attempts do not accumulate in the
      // shared URLSession connection pool and stall the next worker probe.
      task.cancel()
      return []
    }
    guard let resultData else { return [] }
    return decodeTargetPayload(resultData)
  }

  static func fetchTargets(portOverride: Int? = nil) -> [[String: Any]] {
    let resolvedPort = portOverride ?? port()
    let resolvedHost = host().lowercased()
    // Keep the proven URLSession path for the primary authenticated renderer
    // (usually 9324 and the integration-test's ephemeral port). The isolated
    // worker range is the only path that needs the independent socket probe:
    // a second Electron process can otherwise wedge URLSession's shared local
    // connection pool while its CDP endpoint is still opening.
    if (resolvedHost == "127.0.0.1" || resolvedHost == "localhost"),
       (9330...9380).contains(resolvedPort) {
      return fetchTargetsOverLocalSocket(port: resolvedPort)
    }
    return fetchTargetsOverURLSession(port: resolvedPort)
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

  // Approval actions must use the same live renderer target that performed
  // card detection. The action transport is deliberately bounded and local;
  // it never depends on viewport visibility or an OS input device.
  static func evaluatePersistent(
    wsURLString: String,
    expression: String,
    timeout: TimeInterval = 2.5
  ) -> [String: Any]? {
    let params = "{\"expression\":\(jsonStringLiteral(expression)),\"returnByValue\":true,\"awaitPromise\":true}"
    return sendRawCommand(
      wsURLString: wsURLString,
      method: "Runtime.evaluate",
      paramsJSON: params,
      timeout: timeout
    )
  }

  // URLSessionWebSocketTask can block while a renderer is closing a previous
  // DevTools session. Approval handling needs a transport whose connect, send,
  // receive, and close phases all have the same hard deadline, so use a small
  // bounded local WebSocket client for the direct Runtime.evaluate action.
  private static func sendRawCommand(
    wsURLString: String,
    method: String,
    paramsJSON: String,
    timeout: TimeInterval
  ) -> [String: Any]? {
    queueTrace("task=approval-watcher stage=approval-cdp-raw-enter method=\(method)")
    defer {
      queueTrace("task=approval-watcher stage=approval-cdp-raw-exit method=\(method)")
    }
    guard let url = URL(string: wsURLString),
          url.scheme?.lowercased() == "ws",
          let host = url.host,
          let port = url.port else { return nil }
    let deadline = Date().addingTimeInterval(max(timeout, 1.0) + 1.0)
    guard let fd = connectRawSocket(host: host, port: port, deadline: deadline) else {
      queueTrace("task=approval-watcher stage=approval-cdp-raw-connect-failed method=\(method)")
      return nil
    }
    defer { Darwin.close(fd) }

    let path = (url.path.isEmpty ? "/" : url.path)
      + (url.query.map { "?\($0)" } ?? "")
    let key = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
      .base64EncodedString()
    let hostHeader = "\(host):\(port)"
    let handshakeText =
      "GET \(path) HTTP/1.1\r\nHost: \(hostHeader)\r\nUpgrade: websocket\r\n"
        + "Connection: Upgrade\r\nSec-WebSocket-Key: \(key)\r\n"
        + "Sec-WebSocket-Version: 13\r\n\r\n"
    let handshake = Data(handshakeText.utf8)
    guard writeRawSocket(handshake, fd: fd, deadline: deadline),
          let responseHeader = readRawHTTPHeader(fd: fd, deadline: deadline),
          String(decoding: responseHeader, as: UTF8.self)
            .lowercased()
            .hasPrefix("http/1.1 101") else {
      queueTrace("task=approval-watcher stage=approval-cdp-raw-handshake-failed method=\(method)")
      return nil
    }
    queueTrace("task=approval-watcher stage=approval-cdp-raw-handshake-ok method=\(method)")

    let messageId = Int.random(in: 1000...999999)
    let request = "{\"id\":\(messageId),\"method\":\(jsonStringLiteral(method)),\"params\":\(paramsJSON)}"
    guard writeRawSocket(
      Data(makeRawWebSocketFrame(opcode: 0x1, payload: Array(request.utf8))),
      fd: fd,
      deadline: deadline
    ) else { return nil }
    queueTrace("task=approval-watcher stage=approval-cdp-raw-request-sent method=\(method)")

    var fragmentedPayload: [UInt8] = []
    var fragmented = false
    while Date() < deadline {
      guard let frame = readRawWebSocketFrame(fd: fd, deadline: deadline) else { return nil }
      if frame.opcode == 0x9 {
        _ = writeRawSocket(
          Data(makeRawWebSocketFrame(opcode: 0xA, payload: frame.payload)),
          fd: fd,
          deadline: deadline
        )
        continue
      }
      if frame.opcode == 0x8 { return nil }
      if frame.opcode == 0x1 {
        fragmentedPayload = frame.payload
        fragmented = !frame.fin
      } else if frame.opcode == 0x0, fragmented {
        fragmentedPayload.append(contentsOf: frame.payload)
        fragmented = !frame.fin
      } else {
        continue
      }
      guard !fragmented else { continue }
      guard let decoded = try? JSONSerialization.jsonObject(
        with: Data(fragmentedPayload)
      ), let object = decoded as? [String: Any] else {
        fragmentedPayload.removeAll(keepingCapacity: true)
        continue
      }
      let responseId = (object["id"] as? NSNumber)?.intValue
      if responseId == messageId {
        queueTrace("task=approval-watcher stage=approval-cdp-raw-response method=\(method)")
        return sanitizeJSONDict(object)
      }
      fragmentedPayload.removeAll(keepingCapacity: true)
    }
    return nil
  }

  private static func connectRawSocket(
    host: String,
    port: Int,
    deadline: Date
  ) -> Int32? {
    let addressHost = host == "localhost" ? "127.0.0.1" : host
    guard let portNumber = UInt16(exactly: port),
          addressHost.withCString({
            var address = in_addr()
            return Darwin.inet_pton(AF_INET, $0, &address) == 1
          }) else { return nil }
    let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else { return nil }
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = in_port_t(portNumber.bigEndian)
    guard addressHost.withCString({
      Darwin.inet_pton(AF_INET, $0, &address.sin_addr)
    }) == 1 else {
      Darwin.close(fd)
      return nil
    }
    let originalFlags = Darwin.fcntl(fd, F_GETFL, 0)
    guard originalFlags >= 0,
          Darwin.fcntl(fd, F_SETFL, originalFlags | O_NONBLOCK) == 0 else {
      Darwin.close(fd)
      return nil
    }
    let result = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
        Darwin.connect(
          fd,
          socketAddress,
          socklen_t(MemoryLayout<sockaddr_in>.size)
        )
      }
    }
    if result != 0 {
      guard errno == EINPROGRESS,
            waitForRawSocket(fd, events: Int16(POLLOUT), deadline: deadline) else {
        Darwin.close(fd)
        return nil
      }
      var socketError: Int32 = 0
      var socketErrorLength = socklen_t(MemoryLayout<Int32>.size)
      guard Darwin.getsockopt(
        fd,
        SOL_SOCKET,
        SO_ERROR,
        &socketError,
        &socketErrorLength
      ) == 0, socketError == 0 else {
        Darwin.close(fd)
        return nil
      }
    }
    return fd
  }

  private static func waitForRawSocket(
    _ fd: Int32,
    events: Int16,
    deadline: Date
  ) -> Bool {
    while Date() < deadline {
      var descriptor = pollfd()
      descriptor.fd = fd
      descriptor.events = events
      descriptor.revents = 0
      let milliseconds = Int32(
        max(1, min(1_000, Int(deadline.timeIntervalSinceNow * 1_000)))
      )
      let result = Darwin.poll(&descriptor, 1, milliseconds)
      if result > 0 {
        return descriptor.revents & (events | Int16(POLLERR | POLLHUP)) != 0
      }
      if result < 0, errno == EINTR { continue }
      if result == 0 { continue }
      return false
    }
    return false
  }

  private static func writeRawSocket(
    _ data: Data,
    fd: Int32,
    deadline: Date
  ) -> Bool {
    let bytes = Array(data)
    var offset = 0
    while offset < bytes.count {
      guard waitForRawSocket(fd, events: Int16(POLLOUT), deadline: deadline) else {
        return false
      }
      let written = bytes.withUnsafeBytes { buffer -> Int in
        guard let baseAddress = buffer.baseAddress else { return -1 }
        return Darwin.send(
          fd,
          baseAddress.advanced(by: offset),
          bytes.count - offset,
          0
        )
      }
      if written > 0 {
        offset += written
      } else if written < 0, errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK {
        continue
      } else {
        return false
      }
    }
    return true
  }

  private static func readRawBytes(
    count: Int,
    fd: Int32,
    deadline: Date
  ) -> [UInt8]? {
    guard count >= 0 else { return nil }
    var bytes = [UInt8](repeating: 0, count: count)
    var offset = 0
    while offset < count {
      guard waitForRawSocket(fd, events: Int16(POLLIN), deadline: deadline) else {
        return nil
      }
      let received = bytes.withUnsafeMutableBytes { buffer -> Int in
        guard let baseAddress = buffer.baseAddress else { return -1 }
        return Darwin.recv(
          fd,
          baseAddress.advanced(by: offset),
          count - offset,
          0
        )
      }
      if received > 0 {
        offset += received
      } else if received < 0, errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK {
        continue
      } else {
        return nil
      }
    }
    return bytes
  }

  private static func readRawHTTPHeader(fd: Int32, deadline: Date) -> [UInt8]? {
    var bytes: [UInt8] = []
    let delimiter: [UInt8] = [13, 10, 13, 10]
    while bytes.count < 64 * 1024 {
      guard waitForRawSocket(fd, events: Int16(POLLIN), deadline: deadline) else {
        return nil
      }
      var buffer = [UInt8](repeating: 0, count: 4 * 1024)
      let received = buffer.withUnsafeMutableBytes { rawBuffer -> Int in
        guard let baseAddress = rawBuffer.baseAddress else { return -1 }
        return Darwin.recv(fd, baseAddress, rawBuffer.count, 0)
      }
      if received > 0 {
        bytes.append(contentsOf: buffer.prefix(received))
        if bytes.count >= delimiter.count,
           Array(bytes.suffix(delimiter.count)) == delimiter {
          return bytes
        }
      } else if received < 0, errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK {
        continue
      } else {
        return nil
      }
    }
    return nil
  }

  private static func makeRawWebSocketFrame(
    opcode: UInt8,
    payload: [UInt8]
  ) -> [UInt8] {
    var frame: [UInt8] = [UInt8(0x80) | (opcode & 0x0F)]
    let length = payload.count
    if length < 126 {
      frame.append(UInt8(0x80) | UInt8(length))
    } else if length <= Int(UInt16.max) {
      frame.append(UInt8(0x80 | 126))
      frame.append(UInt8((length >> 8) & 0xFF))
      frame.append(UInt8(length & 0xFF))
    } else {
      frame.append(UInt8(0x80 | 127))
      let length64 = UInt64(length)
      for shift in stride(from: 56, through: 0, by: -8) {
        frame.append(UInt8((length64 >> UInt64(shift)) & 0xFF))
      }
    }
    let mask = (0..<4).map { _ in UInt8.random(in: 0...255) }
    frame.append(contentsOf: mask)
    for index in 0..<payload.count {
      frame.append(payload[index] ^ mask[index % 4])
    }
    return frame
  }

  private static func readRawWebSocketFrame(
    fd: Int32,
    deadline: Date
  ) -> (fin: Bool, opcode: UInt8, payload: [UInt8])? {
    guard let header = readRawBytes(count: 2, fd: fd, deadline: deadline) else {
      return nil
    }
    let fin = (header[0] & 0x80) != 0
    let opcode = header[0] & 0x0F
    let masked = (header[1] & 0x80) != 0
    var length = Int(header[1] & 0x7F)
    if length == 126 {
      guard let extended = readRawBytes(count: 2, fd: fd, deadline: deadline) else {
        return nil
      }
      length = (Int(extended[0]) << 8) | Int(extended[1])
    } else if length == 127 {
      guard let extended = readRawBytes(count: 8, fd: fd, deadline: deadline) else {
        return nil
      }
      var length64: UInt64 = 0
      for byte in extended { length64 = (length64 << 8) | UInt64(byte) }
      guard length64 <= UInt64(Int.max), length64 <= 4 * 1024 * 1024 else { return nil }
      length = Int(length64)
    }
    var mask: [UInt8] = []
    if masked {
      guard let maskBytes = readRawBytes(count: 4, fd: fd, deadline: deadline) else {
        return nil
      }
      mask = maskBytes
    }
    guard var payload = readRawBytes(count: length, fd: fd, deadline: deadline) else {
      return nil
    }
    if !mask.isEmpty {
      for index in 0..<payload.count { payload[index] ^= mask[index % 4] }
    }
    return (fin, opcode, payload)
  }

  @discardableResult
  static func dispatchMouseClick(
    wsURLString: String,
    x: Double,
    y: Double,
    timeout: TimeInterval = 4.0
  ) -> Bool {
    let coordinate = { (value: Double) in
      String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
    let events: [(String, String)] = [
      (
        "mouseMoved",
        "{\"type\":\"mouseMoved\",\"x\":\(coordinate(x)),\"y\":\(coordinate(y))}"
      ),
      (
        "mousePressed",
        "{\"type\":\"mousePressed\",\"x\":\(coordinate(x)),\"y\":\(coordinate(y)),"
          + "\"button\":\"left\",\"buttons\":1,\"clickCount\":1}"
      ),
      (
        "mouseReleased",
        "{\"type\":\"mouseReleased\",\"x\":\(coordinate(x)),\"y\":\(coordinate(y)),"
          + "\"button\":\"left\",\"buttons\":0,\"clickCount\":1}"
      ),
    ]
    for (method, paramsJSON) in events {
      guard let response = sendCommand(
        wsURLString: wsURLString,
        method: "Input.dispatchMouseEvent",
        paramsJSON: paramsJSON,
        timeout: timeout
      ), response["error"] == nil else { return false }
    }
    return true
  }

  @discardableResult
  static func dispatchKeyPress(
    wsURLString: String,
    key: String,
    code: String,
    windowsVirtualKeyCode: Int,
    nativeVirtualKeyCode: Int,
    timeout: TimeInterval = 4.0
  ) -> Bool {
    let keyCode = "\"key\":\(jsonStringLiteral(key)),\"code\":\(jsonStringLiteral(code)),"
      + "\"windowsVirtualKeyCode\":\(windowsVirtualKeyCode),"
      + "\"nativeVirtualKeyCode\":\(nativeVirtualKeyCode),\"macCharCode\":0"
    let events = [
      "{\"type\":\"keyDown\",\(keyCode)}",
      "{\"type\":\"keyUp\",\(keyCode)}",
    ]
    for paramsJSON in events {
      guard let response = sendCommand(
        wsURLString: wsURLString,
        method: "Input.dispatchKeyEvent",
        paramsJSON: paramsJSON,
        timeout: timeout
      ), response["error"] == nil else { return false }
    }
    return true
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
    let parameterVariants = [
      "{\"format\":\"png\",\"captureBeyondViewport\":true,\"fromSurface\":true}",
      "{\"format\":\"png\",\"captureBeyondViewport\":true}",
      "{\"format\":\"png\"}",
    ]
    var data: Data?
    for paramsJSON in parameterVariants {
      guard let response = sendCommand(
        wsURLString: wsURLString,
        method: "Page.captureScreenshot",
        paramsJSON: paramsJSON,
        timeout: 8.0
      ), let result = response["result"] as? [String: Any],
         let encoded = result["data"] as? String,
         let decoded = Data(base64Encoded: encoded) else { continue }
      data = decoded
      break
    }
    guard let data else { return false }
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
  static func bringPageToFront(wsURLString: String) -> Bool {
    guard let response = sendCommand(
      wsURLString: wsURLString,
      method: "Page.bringToFront",
      paramsJSON: "{}",
      timeout: 4.0
    ) else { return false }
    return response["error"] == nil
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

  @discardableResult
  static func activateTarget(_ targetId: String, portOverride: Int? = nil) -> Bool {
    guard let browserWS = browserWebSocketURL(portOverride: portOverride),
          let response = sendCommand(
            wsURLString: browserWS,
            method: "Target.activateTarget",
            paramsJSON: "{\"targetId\":\(jsonStringLiteral(targetId))}",
            timeout: 4.0
          ), response["error"] == nil else { return false }
    return (response["result"] as? [String: Any])?["success"] as? Bool ?? true
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
