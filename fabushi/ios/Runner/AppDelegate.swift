import Flutter
import UIKit
import BackgroundTasks

@_silgen_name("fabushi_telegram_force_link")
private func fabushiTelegramForceLink() -> UInt32

@_silgen_name("mahayana_runtime_force_link")
private func mahayanaRuntimeForceLink() -> UInt32

@main
@objc class AppDelegate: FlutterAppDelegate {
    // 内存警告 MethodChannel
    private var memoryChannel: FlutterMethodChannel?
    private var inboundShareChannel: FlutterMethodChannel?
    private let inboundShareAppGroup = "group.com.ombhrum.fabushi.share"
    private let inboundSharePayloadKey = "inboundSharePayload"
    private var pendingSharePayload: [String: Any]?

    // 后台任务标识符
    private static let keepAliveTaskIdentifier = "com.ombhrum.fabushi.keepalive"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        precondition(
            fabushiTelegramForceLink() == 1,
            "Telegram Rust runtime failed to link"
        )
        precondition(
            mahayanaRuntimeForceLink() == 1,
            "Mahayana Rust runtime failed to link"
        )

        // 设置 MethodChannel
        if let controller = window?.rootViewController as? FlutterViewController {
            memoryChannel = FlutterMethodChannel(
                name: "com.ombhrum.fabushi/memory",
                binaryMessenger: controller.binaryMessenger
            )
            configureInboundShareChannel(controller: controller)
        }
        pendingSharePayload = readSharedInboundPayload()

        // 注册后台任务 (iOS 13+)
        if #available(iOS 13.0, *) {
            registerBackgroundTasks()
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - iOS Share Extension inbound payload

    private func configureInboundShareChannel(controller: FlutterViewController) {
        inboundShareChannel = FlutterMethodChannel(
            name: "com.ombhrum.fabushi/inbound_share",
            binaryMessenger: controller.binaryMessenger
        )
        inboundShareChannel?.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            switch call.method {
            case "getInitialShare":
                if let payload = self.pendingSharePayload ?? self.readSharedInboundPayload() {
                    self.pendingSharePayload = payload
                    result(payload)
                } else {
                    result([String: Any]())
                }
            case "clearInitialShare":
                self.pendingSharePayload = nil
                UserDefaults(suiteName: self.inboundShareAppGroup)?.removeObject(forKey: self.inboundSharePayloadKey)
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func readSharedInboundPayload() -> [String: Any]? {
        guard let defaults = UserDefaults(suiteName: inboundShareAppGroup),
              let payload = defaults.dictionary(forKey: inboundSharePayloadKey) else {
            return nil
        }
        let text = (payload["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let url = (payload["url"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return (text.isEmpty && url.isEmpty) ? nil : payload
    }

    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        if url.scheme == "fabushi" {
            if let payload = readSharedInboundPayload() {
                pendingSharePayload = payload
                inboundShareChannel?.invokeMethod("onIncomingShare", arguments: payload)
            }
            return true
        }
        return super.application(app, open: url, options: options)
    }

    // MARK: - 内存警告处理

    override func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        NSLog("⚠️ iOS 收到内存警告")

        // 通知 Flutter 层释放内存
        memoryChannel?.invokeMethod("warning", arguments: nil)
    }

    // MARK: - 后台任务处理 (iOS 13+)

    @available(iOS 13.0, *)
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AppDelegate.keepAliveTaskIdentifier,
            using: nil
        ) { task in
            self.handleKeepAliveTask(task as! BGProcessingTask)
        }

        NSLog("✅ BGTaskScheduler 已注册")
    }

    @available(iOS 13.0, *)
    private func handleKeepAliveTask(_ task: BGProcessingTask) {
        NSLog("📋 执行后台保活任务")

        // 设置过期处理
        task.expirationHandler = {
            NSLog("⏰ 后台任务即将过期")
            task.setTaskCompleted(success: false)
        }

        // 检查是否有需要恢复的任务
        let userDefaults = UserDefaults.standard
        let isActive = userDefaults.bool(forKey: "flutter.sending_is_active")

        if isActive {
            NSLog("🔄 检测到需要恢复的发送任务")
            // 这里只能记录状态，让应用下次启动时恢复
            // iOS 后台任务无法直接启动 UI
        }

        task.setTaskCompleted(success: true)

        // 安排下一次任务
        scheduleKeepAliveTask()
    }

    @available(iOS 13.0, *)
    func scheduleKeepAliveTask() {
        let request = BGProcessingTaskRequest(identifier: AppDelegate.keepAliveTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 分钟后

        do {
            try BGTaskScheduler.shared.submit(request)
            NSLog("✅ 后台任务已调度")
        } catch {
            NSLog("❌ 调度后台任务失败: \(error)")
        }
    }

    // MARK: - 应用进入后台时调度任务

    override func applicationDidEnterBackground(_ application: UIApplication) {
        super.applicationDidEnterBackground(application)

        if #available(iOS 13.0, *) {
            scheduleKeepAliveTask()
        }
    }
}
