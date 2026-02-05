import Flutter
import UIKit
import BackgroundTasks

@main
@objc class AppDelegate: FlutterAppDelegate {
    // 内存警告 MethodChannel
    private var memoryChannel: FlutterMethodChannel?
    
    // 后台任务标识符
    private static let keepAliveTaskIdentifier = "com.ombhrum.fabushi.keepalive"
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        // 设置内存警告 MethodChannel
        if let controller = window?.rootViewController as? FlutterViewController {
            memoryChannel = FlutterMethodChannel(
                name: "com.ombhrum.fabushi/memory",
                binaryMessenger: controller.binaryMessenger
            )
        }
        
        // 注册后台任务 (iOS 13+)
        if #available(iOS 13.0, *) {
            registerBackgroundTasks()
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // MARK: - 内存警告处理
    
    override func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        super.applicationDidReceiveMemoryWarning(application)
        
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
