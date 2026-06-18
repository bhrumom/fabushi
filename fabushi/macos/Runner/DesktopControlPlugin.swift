import ApplicationServices
import Carbon.HIToolbox
import Cocoa
import FlutterMacOS

final class DesktopControlPlugin: NSObject {
  private static var retainedInstances: [DesktopControlPlugin] = []

  private let channel: FlutterMethodChannel

  static func register(with controller: FlutterViewController) {
    let plugin = DesktopControlPlugin(controller: controller)
    retainedInstances.append(plugin)
  }

  private init(controller: FlutterViewController) {
    channel = FlutterMethodChannel(
      name: "com.ombhrum.fabushi/desktop_control",
      binaryMessenger: controller.engine.binaryMessenger
    )
    super.init()
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "status":
      result(statusPayload())
    case "observe":
      result([
        "status": statusPayload(),
        "activeApplication": activeApplicationPayload(),
        "windows": enumerateWindows(),
      ])
    case "windows":
      result(["windows": enumerateWindows()])
    case "screenshot":
      screenshot(args, result: result)
    case "click":
      guard requireAccessibility(result) else { return }
      click(args, result: result)
    case "type":
      guard requireAccessibility(result) else { return }
      typeText(args, result: result)
    case "hotkey":
      guard requireAccessibility(result) else { return }
      hotkey(args, result: result)
    case "scroll":
      guard requireAccessibility(result) else { return }
      scroll(args, result: result)
    case "requestScreenRecording":
      if #available(macOS 10.15, *) {
        result(["requested": CGRequestScreenCaptureAccess()])
      } else {
        result(["requested": false])
      }
    case "requestAccessibility":
      let options = [
        kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
      ] as CFDictionary
      result(["trusted": AXIsProcessTrustedWithOptions(options)])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func statusPayload() -> [String: Any] {
    [
      "platform": "macos",
      "screenRecordingGranted": screenRecordingGranted(),
      "accessibilityGranted": AXIsProcessTrusted(),
      "activeApplication": activeApplicationPayload(),
    ]
  }

  private func activeApplicationPayload() -> [String: Any] {
    guard let app = NSWorkspace.shared.frontmostApplication else {
      return [:]
    }
    return [
      "localizedName": app.localizedName ?? "",
      "bundleIdentifier": app.bundleIdentifier ?? "",
      "processIdentifier": app.processIdentifier,
    ]
  }

  private func screenRecordingGranted() -> Bool {
    if #available(macOS 10.15, *) {
      return CGPreflightScreenCaptureAccess()
    }
    return true
  }

  private func enumerateWindows() -> [[String: Any]] {
    let options: CGWindowListOption = [
      .optionOnScreenOnly,
      .excludeDesktopElements,
    ]
    let rawList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
    return rawList.compactMap { item in
      let ownerName = item[kCGWindowOwnerName as String] as? String ?? ""
      let windowName = item[kCGWindowName as String] as? String ?? ""
      let layer = item[kCGWindowLayer as String] as? Int ?? 0
      let alpha = item[kCGWindowAlpha as String] as? Double ?? 0
      guard layer == 0, alpha > 0 else { return nil }

      var boundsPayload: [String: Any] = [:]
      if let boundsDict = item[kCGWindowBounds as String] as? [String: Any],
         let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
        boundsPayload = [
          "x": bounds.origin.x,
          "y": bounds.origin.y,
          "width": bounds.size.width,
          "height": bounds.size.height,
        ]
      }

      return [
        "windowId": item[kCGWindowNumber as String] as? Int ?? 0,
        "ownerName": ownerName,
        "windowName": windowName,
        "processIdentifier": item[kCGWindowOwnerPID as String] as? Int ?? 0,
        "bounds": boundsPayload,
      ]
    }
  }

  private func screenshot(_ args: [String: Any], result: @escaping FlutterResult) {
    guard screenRecordingGranted() else {
      result(FlutterError(
        code: "screen_recording_required",
        message: "Screen Recording permission is required for screenshots.",
        details: statusPayload()
      ))
      return
    }

    let rect = captureRect(args)
    let imageOptions: CGWindowImageOption = [
      .boundsIgnoreFraming,
      .bestResolution,
    ]
    guard let cgImage = CGWindowListCreateImage(
      rect,
      .optionOnScreenOnly,
      kCGNullWindowID,
      imageOptions
    ) else {
      result(FlutterError(
        code: "screenshot_failed",
        message: "Unable to capture the screen.",
        details: statusPayload()
      ))
      return
    }

    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let png = rep.representation(using: .png, properties: [:]) else {
      result(FlutterError(
        code: "screenshot_encoding_failed",
        message: "Unable to encode screenshot.",
        details: nil
      ))
      return
    }

    result([
      "format": "png",
      "width": cgImage.width,
      "height": cgImage.height,
      "base64": png.base64EncodedString(),
    ])
  }

  private func click(_ args: [String: Any], result: @escaping FlutterResult) {
    guard let x = doubleArg(args, "x"), let y = doubleArg(args, "y") else {
      result(FlutterError(
        code: "invalid_arguments",
        message: "desktop.click requires x and y.",
        details: nil
      ))
      return
    }

    let point = CGPoint(x: x, y: y)
    let buttonName = (args["button"] as? String ?? "left").lowercased()
    let button: CGMouseButton = buttonName == "right" ? .right : .left
    let downType: CGEventType = button == .right ? .rightMouseDown : .leftMouseDown
    let upType: CGEventType = button == .right ? .rightMouseUp : .leftMouseUp

    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: button)?
      .post(tap: .cghidEventTap)
    CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: point, mouseButton: button)?
      .post(tap: .cghidEventTap)
    CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: point, mouseButton: button)?
      .post(tap: .cghidEventTap)

    result(["clicked": true, "x": x, "y": y, "button": buttonName])
  }

  private func typeText(_ args: [String: Any], result: @escaping FlutterResult) {
    let text = args["text"] as? String ?? ""
    for scalar in text.utf16 {
      var character = scalar
      let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
      down?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &character)
      down?.post(tap: .cghidEventTap)

      let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
      up?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &character)
      up?.post(tap: .cghidEventTap)
    }
    result(["typed": true, "length": text.count])
  }

  private func hotkey(_ args: [String: Any], result: @escaping FlutterResult) {
    let rawKeys: [String]
    if let keys = args["keys"] as? [String] {
      rawKeys = keys
    } else if let key = args["key"] as? String {
      rawKeys = [key]
    } else {
      rawKeys = []
    }

    var flags = CGEventFlags()
    var keyCode: CGKeyCode?
    for rawKey in rawKeys {
      let key = rawKey.lowercased()
      switch key {
      case "cmd", "command", "meta":
        flags.insert(.maskCommand)
      case "ctrl", "control":
        flags.insert(.maskControl)
      case "alt", "option":
        flags.insert(.maskAlternate)
      case "shift":
        flags.insert(.maskShift)
      default:
        keyCode = keyCodeFor(key)
      }
    }

    guard let code = keyCode else {
      result(FlutterError(
        code: "invalid_arguments",
        message: "desktop.hotkey requires a non-modifier key.",
        details: nil
      ))
      return
    }

    let down = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true)
    down?.flags = flags
    down?.post(tap: .cghidEventTap)
    let up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false)
    up?.flags = flags
    up?.post(tap: .cghidEventTap)
    result(["hotkey": rawKeys])
  }

  private func scroll(_ args: [String: Any], result: @escaping FlutterResult) {
    let deltaX = Int32(doubleArg(args, "deltaX") ?? 0)
    let deltaY = Int32(doubleArg(args, "deltaY") ?? 0)
    guard deltaX != 0 || deltaY != 0 else {
      result(FlutterError(
        code: "invalid_arguments",
        message: "desktop.scroll requires deltaX or deltaY.",
        details: nil
      ))
      return
    }
    CGEvent(
      scrollWheelEvent2Source: nil,
      units: .pixel,
      wheelCount: 2,
      wheel1: deltaY,
      wheel2: deltaX,
      wheel3: 0
    )?.post(tap: .cghidEventTap)
    result(["scrolled": true, "deltaX": deltaX, "deltaY": deltaY])
  }

  private func captureRect(_ args: [String: Any]) -> CGRect {
    guard let x = doubleArg(args, "x"),
          let y = doubleArg(args, "y"),
          let width = doubleArg(args, "width"),
          let height = doubleArg(args, "height"),
          width > 0,
          height > 0 else {
      return CGRect.null
    }
    return CGRect(x: x, y: y, width: width, height: height)
  }

  private func requireAccessibility(_ result: @escaping FlutterResult) -> Bool {
    guard AXIsProcessTrusted() else {
      result(FlutterError(
        code: "accessibility_required",
        message: "Accessibility permission is required for input actions.",
        details: statusPayload()
      ))
      return false
    }
    return true
  }

  private func doubleArg(_ args: [String: Any], _ key: String) -> Double? {
    if let value = args[key] as? Double { return value }
    if let value = args[key] as? Int { return Double(value) }
    if let value = args[key] as? NSNumber { return value.doubleValue }
    if let value = args[key] as? String { return Double(value) }
    return nil
  }

  private func keyCodeFor(_ key: String) -> CGKeyCode? {
    let letters: [String: Int] = [
      "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
      "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
      "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
      "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
      "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
      "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
      "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
      "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
      "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
      "8": kVK_ANSI_8, "9": kVK_ANSI_9,
      "return": kVK_Return, "enter": kVK_Return, "tab": kVK_Tab,
      "escape": kVK_Escape, "esc": kVK_Escape, "space": kVK_Space,
      "delete": kVK_Delete, "backspace": kVK_Delete,
      "left": kVK_LeftArrow, "right": kVK_RightArrow,
      "up": kVK_UpArrow, "down": kVK_DownArrow,
    ]
    guard let code = letters[key] else { return nil }
    return CGKeyCode(code)
  }
}
