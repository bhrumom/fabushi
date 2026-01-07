import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    // 注册语音识别插件
    if let registrar = self.registrar(forPlugin: "SpeechRecognizerPlugin") {
      SpeechRecognizerPlugin.register(with: registrar)
    }
    // 注册语义 NLP 插件
    if let registrar = self.registrar(forPlugin: "SemanticNlpPlugin") {
      SemanticNlpPlugin.register(with: registrar)
    }
  }
  
  // 处理URL打开事件（用于支付宝回调）
  override func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      handleIncomingURL(url)
    }
    super.application(application, open: urls)
  }
  
  // 处理单个URL
  private func handleIncomingURL(_ url: URL) {
    // 获取Flutter引擎的控制器
    guard let controller = NSApplication.shared.mainWindow?.contentViewController as? FlutterViewController else {
      return
    }
    
    // 解析URL参数
    let urlString = url.absoluteString
    
    // 创建方法通道，与Flutter端通信
    let channel = FlutterMethodChannel(name: "com.globaldharma.alipay/callback", 
                                       binaryMessenger: controller.engine.binaryMessenger)
    
    // 将URL传递给Flutter端处理
    channel.invokeMethod("handleAlipayCallback", arguments: urlString)
  }
}
