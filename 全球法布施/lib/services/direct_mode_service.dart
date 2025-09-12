import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:js/js_util.dart' as js_util;
import 'dart:html' as html;

/// 直接模式服务
/// 
/// 这个服务负责在Web平台上管理直接模式功能，
/// 包括WebRTC、Web蓝牙等无需中继服务器的传输方式。
class DirectModeService {
  static final DirectModeService _instance = DirectModeService._internal();
  factory DirectModeService() => _instance;
  
  bool _initialized = false;
  bool get isInitialized => _initialized;
  
  bool _webrtcSupported = false;
  bool _bluetoothSupported = false;
  bool _webTransportSupported = false;
  bool _webUSBSupported = false;
  
  bool get isWebRTCSupported => _webrtcSupported;
  bool get isBluetoothSupported => _bluetoothSupported;
  bool get isWebTransportSupported => _webTransportSupported;
  bool get isWebUSBSupported => _webUSBSupported;
  
  // 文件ID映射
  final Map<String, PlatformFile> _fileMap = {};
  
  // 创建一个流控制器来监听初始化状态
  final _initializationController = StreamController<bool>.broadcast();
  Stream<bool> get onInitialized => _initializationController.stream;
  
  DirectModeService._internal();
  
  /// 初始化直接模式服务
  Future<bool> initialize() async {
    if (!kIsWeb) {
      debugPrint('直接模式服务仅在Web平台上可用');
      return false;
    }
    
    if (_initialized) {
      debugPrint('直接模式服务已初始化');
      return true;
    }
    
    debugPrint('正在初始化直接模式服务...');
    
    try {
      // 确保direct-mode.js已加载
      await _ensureScriptLoaded('direct-mode.js');
      
      // 调用JavaScript初始化函数
      final flutterDirectMode = js_util.getProperty(html.window, 'flutterDirectMode');
      final result = await js_util.promiseToFuture(
        js_util.callMethod(
          flutterDirectMode,
          'initialize',
          []
        )
      );
      
      // 解析结果
      _webrtcSupported = js_util.getProperty(result, 'webrtcSupported');
      _bluetoothSupported = js_util.getProperty(result, 'bluetoothSupported');
      _webTransportSupported = js_util.getProperty(result, 'webTransportSupported');
      _webUSBSupported = js_util.getProperty(result, 'webUSBSupported');
      
      debugPrint('直接模式服务初始化完成');
      debugPrint('WebRTC支持: $_webrtcSupported');
      debugPrint('Web蓝牙支持: $_bluetoothSupported');
      debugPrint('WebTransport支持: $_webTransportSupported');
      debugPrint('WebUSB支持: $_webUSBSupported');
      
      _initialized = true;
      _initializationController.add(true);
      return true;
    } catch (e) {
      debugPrint('初始化直接模式服务时出错: $e');
      _initializationController.add(false);
      return false;
    }
  }
  
  /// 确保JavaScript脚本已加载
  Future<void> _ensureScriptLoaded(String scriptPath) async {
    final completer = Completer<void>();
    
    // 检查脚本是否已加载
    final scripts = html.document.querySelectorAll('script');
    for (final script in scripts) {
      final scriptElement = script as html.ScriptElement;
      if (scriptElement.src != null && scriptElement.src!.contains(scriptPath)) {
        completer.complete();
        return completer.future;
      }
    }
    
    // 加载脚本
    final script = html.ScriptElement()
      ..src = scriptPath
      ..type = 'text/javascript';
    
    script.onLoad.listen((event) {
      debugPrint('脚本已加载: $scriptPath');
      completer.complete();
    });
    
    script.onError.listen((event) {
      debugPrint('加载脚本时出错: $scriptPath');
      completer.completeError('加载脚本失败: $scriptPath');
    });
    
    html.document.head!.append(script);
    return completer.future;
  }
  
  /// 创建WebRTC连接
  Future<bool> createWebRTCConnection() async {
    if (!_initialized || !_webrtcSupported) {
      debugPrint('WebRTC不可用');
      return false;
    }
    
    try {
      final flutterDirectMode = js_util.getProperty(html.window, 'flutterDirectMode');
      final result = await js_util.promiseToFuture(
        js_util.callMethod(
          flutterDirectMode,
          'createWebRTCConnection',
          []
        )
      );
      
      final success = js_util.getProperty(result, 'success');
      final message = js_util.getProperty(result, 'message');
      
      debugPrint('创建WebRTC连接: $success, $message');
      return success;
    } catch (e) {
      debugPrint('创建WebRTC连接时出错: $e');
      return false;
    }
  }
  
  /// 注册文件
  String registerFile(PlatformFile file) {
    if (!_initialized) {
      debugPrint('直接模式服务未初始化');
      return '';
    }
    
    // 生成唯一ID
    final fileId = 'file_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
    
    // 存储文件引用
    _fileMap[fileId] = file;
    
    // 创建JavaScript File对象
    final jsFile = html.File(
      [file.bytes!],
      file.name,
      {'type': _getMimeType(file.name)}
    );
    
    // 注册到JavaScript
    js_util.callMethod(
      html.window,
      'registerFileForDirectMode',
      [fileId, jsFile]
    );
    
    debugPrint('已注册文件: ${file.name}, ID: $fileId');
    return fileId;
  }
  
  /// 取消注册文件
  void unregisterFile(String fileId) {
    if (!_initialized || fileId.isEmpty) {
      return;
    }
    
    // 从JavaScript取消注册
    js_util.callMethod(
      html.window,
      'unregisterFileForDirectMode',
      [fileId]
    );
    
    // 从本地映射中移除
    _fileMap.remove(fileId);
    
    debugPrint('已取消注册文件ID: $fileId');
  }
  
  /// 通过WebRTC发送文件
  Future<Map<String, dynamic>> sendFileViaWebRTC(PlatformFile file) async {
    if (!_initialized || !_webrtcSupported) {
      return {'success': false, 'message': 'WebRTC不可用'};
    }
    
    try {
      // 注册文件
      final fileId = registerFile(file);
      if (fileId.isEmpty) {
        return {'success': false, 'message': '注册文件失败'};
      }
      
      // 调用JavaScript发送文件
      final flutterDirectMode = js_util.getProperty(html.window, 'flutterDirectMode');
      final result = await js_util.promiseToFuture(
        js_util.callMethod(
          flutterDirectMode,
          'sendFileViaWebRTC',
          [fileId]
        )
      );
      
      // 取消注册文件
      unregisterFile(fileId);
      
      // 解析结果
      final success = js_util.getProperty(result, 'success');
      
      if (success) {
        final sentChunks = js_util.getProperty(result, 'sentChunks');
        final dataSentInMB = js_util.getProperty(result, 'dataSentInMB');
        
        return {
          'success': true,
          'sentCount': 1,
          'dataSentInMB': dataSentInMB
        };
      } else {
        final message = js_util.getProperty(result, 'message');
        return {'success': false, 'message': message};
      }
    } catch (e) {
      debugPrint('通过WebRTC发送文件时出错: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
  
  /// 请求蓝牙设备
  Future<bool> requestBluetoothDevice() async {
    if (!_initialized || !_bluetoothSupported) {
      debugPrint('Web蓝牙不可用');
      return false;
    }
    
    try {
      final flutterDirectMode = js_util.getProperty(html.window, 'flutterDirectMode');
      final result = await js_util.promiseToFuture(
        js_util.callMethod(
          flutterDirectMode,
          'requestBluetoothDevice',
          []
        )
      );
      
      final success = js_util.getProperty(result, 'success');
      final message = js_util.getProperty(result, 'message');
      
      debugPrint('请求蓝牙设备: $success, $message');
      return success;
    } catch (e) {
      debugPrint('请求蓝牙设备时出错: $e');
      return false;
    }
  }
  
  /// 通过蓝牙发送文件
  Future<Map<String, dynamic>> sendFileViaBluetooth(PlatformFile file) async {
    if (!_initialized || !_bluetoothSupported) {
      return {'success': false, 'message': 'Web蓝牙不可用'};
    }
    
    try {
      // 注册文件
      final fileId = registerFile(file);
      if (fileId.isEmpty) {
        return {'success': false, 'message': '注册文件失败'};
      }
      
      // 调用JavaScript发送文件
      final flutterDirectMode = js_util.getProperty(html.window, 'flutterDirectMode');
      final result = await js_util.promiseToFuture(
        js_util.callMethod(
          flutterDirectMode,
          'sendFileViaBluetooth',
          [fileId]
        )
      );
      
      // 取消注册文件
      unregisterFile(fileId);
      
      // 解析结果
      final success = js_util.getProperty(result, 'success');
      
      if (success) {
        final sentChunks = js_util.getProperty(result, 'sentChunks');
        final dataSentInMB = js_util.getProperty(result, 'dataSentInMB');
        
        return {
          'success': true,
          'sentCount': 1,
          'dataSentInMB': dataSentInMB
        };
      } else {
        final message = js_util.getProperty(result, 'message');
        return {'success': false, 'message': message};
      }
    } catch (e) {
      debugPrint('通过蓝牙发送文件时出错: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
  
  /// 关闭所有连接
  Future<bool> closeAllConnections() async {
    if (!_initialized) {
      return false;
    }
    
    try {
      final flutterDirectMode = js_util.getProperty(html.window, 'flutterDirectMode');
      final result = await js_util.promiseToFuture(
        js_util.callMethod(
          flutterDirectMode,
          'closeAllConnections',
          []
        )
      );
      
      final success = js_util.getProperty(result, 'success');
      return success;
    } catch (e) {
      debugPrint('关闭所有连接时出错: $e');
      return false;
    }
  }
  
  /// 获取文件MIME类型
  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'html':
      case 'htm':
        return 'text/html';
      case 'css':
        return 'text/css';
      case 'js':
        return 'application/javascript';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'application/xml';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      case '7z':
        return 'application/x-7z-compressed';
      case 'mp3':
        return 'audio/mpeg';
      case 'mp4':
        return 'video/mp4';
      case 'avi':
        return 'video/x-msvideo';
      case 'mov':
        return 'video/quicktime';
      case 'wmv':
        return 'video/x-ms-wmv';
      default:
        return 'application/octet-stream';
    }
  }
  
  /// 释放资源
  void dispose() {
    _initializationController.close();
    closeAllConnections();
  }
}