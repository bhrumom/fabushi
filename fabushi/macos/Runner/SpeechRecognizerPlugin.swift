import Cocoa
import FlutterMacOS
import Speech

/// macOS 语音识别插件
/// 使用 SFSpeechRecognizer 进行实时语音识别
class SpeechRecognizerPlugin: NSObject, FlutterPlugin, SFSpeechRecognizerDelegate {
    
    private var channel: FlutterMethodChannel?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var isRecognizing = false
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.fabushi.app/speech",
            binaryMessenger: registrar.messenger
        )
        let instance = SpeechRecognizerPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initialize(result: result)
        case "startRecognizing":
            startRecognizing(result: result)
        case "processAudio":
            // 对于实时识别，我们使用麦克风输入，不需要手动处理音频数据
            result(nil)
        case "stopRecognizing":
            stopRecognizing(result: result)
        case "reset":
            reset(result: result)
        case "dispose":
            dispose(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - 初始化
    
    private func initialize(result: @escaping FlutterResult) {
        // 请求语音识别权限
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    // 初始化中文识别器
                    self?.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
                    self?.speechRecognizer?.delegate = self
                    self?.audioEngine = AVAudioEngine()
                    
                    if self?.speechRecognizer?.isAvailable == true {
                        result(true)
                    } else {
                        // 尝试繁体中文
                        self?.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-TW"))
                        result(self?.speechRecognizer?.isAvailable == true)
                    }
                    
                case .denied:
                    self?.sendError("语音识别权限被拒绝")
                    result(false)
                    
                case .restricted:
                    self?.sendError("语音识别在此设备上受限")
                    result(false)
                    
                case .notDetermined:
                    self?.sendError("语音识别权限未确定")
                    result(false)
                    
                @unknown default:
                    result(false)
                }
            }
        }
    }
    
    // MARK: - 开始识别
    
    private func startRecognizing(result: @escaping FlutterResult) {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            sendError("语音识别器不可用")
            result(false)
            return
        }
        
        // 如果已经在识别，先停止
        if isRecognizing {
            stopRecognizingInternal()
        }
        
        do {
            // 创建识别请求
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            guard let recognitionRequest = recognitionRequest else {
                sendError("无法创建识别请求")
                result(false)
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            // 如果支持设备端处理，启用它
            if #available(macOS 13.0, *) {
                recognitionRequest.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition
            }
            
            // 配置音频
            let inputNode = audioEngine!.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
            
            // 开始音频引擎
            audioEngine!.prepare()
            try audioEngine!.start()
            
            // 开始识别任务
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] recognitionResult, error in
                guard let self = self else { return }
                
                if let recognitionResult = recognitionResult {
                    let text = recognitionResult.bestTranscription.formattedString
                    let isFinal = recognitionResult.isFinal
                    
                    // 发送结果到 Flutter
                    DispatchQueue.main.async {
                        self.channel?.invokeMethod("onResult", arguments: [
                            "text": text,
                            "isFinal": isFinal
                        ])
                    }
                    
                    if isFinal {
                        self.stopRecognizingInternal()
                    }
                }
                
                if let error = error {
                    self.sendError(error.localizedDescription)
                    self.stopRecognizingInternal()
                }
            }
            
            isRecognizing = true
            result(true)
            
        } catch {
            sendError("无法启动音频引擎: \(error.localizedDescription)")
            result(false)
        }
    }
    
    // MARK: - 停止识别
    
    private func stopRecognizing(result: @escaping FlutterResult) {
        let finalText = stopRecognizingInternal()
        result(finalText)
    }
    
    @discardableResult
    private func stopRecognizingInternal() -> String {
        var finalText = ""
        
        if let task = recognitionTask {
            // 获取最后的结果
            // 由于任务是异步的，这里可能无法立即获取结果
            finalText = ""
            task.cancel()
        }
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        isRecognizing = false
        
        return finalText
    }
    
    // MARK: - 重置
    
    private func reset(result: @escaping FlutterResult) {
        stopRecognizingInternal()
        result(nil)
    }
    
    // MARK: - 释放资源
    
    private func dispose(result: @escaping FlutterResult) {
        stopRecognizingInternal()
        speechRecognizer = nil
        audioEngine = nil
        result(nil)
    }
    
    // MARK: - 发送错误
    
    private func sendError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.channel?.invokeMethod("onError", arguments: message)
        }
    }
    
    // MARK: - SFSpeechRecognizerDelegate
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            sendError("语音识别服务暂时不可用")
        }
    }
}
