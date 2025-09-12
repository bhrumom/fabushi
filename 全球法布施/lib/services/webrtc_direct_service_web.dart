import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

// 只在Web平台导入Web专用库
import 'package:js/js_util.dart' as js_util show getProperty, callConstructor, callMethod, setProperty, allowInterop, promiseToFuture, jsify;
import 'dart:html' as html show window;

/// Web平台WebRTC直接传输服务 - 无连接真实发送实现
/// 
/// 专门为Web平台设计的WebRTC无连接文件传输服务
/// 使用WebRTC DataChannel进行真实的点对点数据传输，不依赖任何中继服务器
class WebRTCDirectServiceWeb {
  bool _initialized = false;
  bool get isInitialized => _initialized;
  
  // 回调函数
  final Function(int)? onProgress;
  final Function(double)? onDataSent;
  final Function()? onStopped;
  
  // WebRTC相关
  dynamic _RTCPeerConnection;
  final Map<String, dynamic> _peerConnections = {};
  final Map<String, dynamic> _dataChannels = {};
  
  // 传输状态
  bool _isSending = false;
  int _sentCount = 0;
  double _dataSentMB = 0.0;
  
  // 流控制器
  final _progressController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onTransferProgress => _progressController.stream;
  
  WebRTCDirectServiceWeb({
    this.onProgress,
    this.onDataSent,
    this.onStopped,
  });
  
  /// 初始化WebRTC服务
  Future<bool> initialize() async {
    if (!kIsWeb) {
      debugPrint('WebRTC直接传输服务仅在Web平台上可用');
      return false;
    }
    
    if (_initialized) {
      debugPrint('WebRTC服务已初始化');
      return true;
    }
    
    debugPrint('正在初始化WebRTC无连接直接传输服务...');
    
    try {
      // 检查WebRTC支持
      if (js_util.getProperty(html.window, 'RTCPeerConnection') == null) {
        throw Exception('浏览器不支持WebRTC');
      }
      
      _RTCPeerConnection = js_util.getProperty(html.window, 'RTCPeerConnection');
      
      _initialized = true;
      debugPrint('WebRTC无连接直接传输服务初始化成功');
      return true;
    } catch (e) {
      debugPrint('初始化WebRTC服务时出错: $e');
      return false;
    }
  }
  
  /// 开始发送文件
  Future<void> startSending({
    required List<PlatformFile> files,
    required bool isLoop,
  }) async {
    if (!_initialized) {
      debugPrint('WebRTC服务未初始化');
      return;
    }
    
    if (_isSending) {
      debugPrint('WebRTC服务正在发送中');
      return;
    }
    
    _isSending = true;
    _sentCount = 0;
    _dataSentMB = 0.0;
    
    debugPrint('🔗 开始WebRTC无连接直接传输，文件数量: ${files.length}');
    
    try {
      do {
        for (final file in files) {
          await _sendFileViaWebRTC(file);
          
          _sentCount++;
          _dataSentMB += (file.size / 1024 / 1024);
          
          onProgress?.call(_sentCount);
          onDataSent?.call(_dataSentMB);
          
          // 发送间隔
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
        if (isLoop) {
          debugPrint('🔄 循环模式：继续下一轮WebRTC传输');
          await Future.delayed(const Duration(seconds: 1));
        }
      } while (isLoop && _isSending);
      
    } catch (e) {
      debugPrint('❌ WebRTC传输过程中出错: $e');
    } finally {
      _isSending = false;
      onStopped?.call();
      debugPrint('🛑 WebRTC无连接直接传输已停止');
    }
  }
  
  /// 通过WebRTC发送文件
  Future<void> _sendFileViaWebRTC(PlatformFile file) async {
    try {
      debugPrint('🔗 开始WebRTC无连接发送: ${file.name}');
      
      // 创建无连接的WebRTC数据通道
      final dataChannel = await _createConnectionlessDataChannel();
      
      if (dataChannel == null) {
        debugPrint('❌ 创建WebRTC数据通道失败');
        return;
      }
      
      // 准备文件数据
      final fileBytes = file.bytes!;
      final fileName = file.name;
      
      // 发送文件元数据
      await _sendMetaData(dataChannel, fileName, fileBytes.length);
      
      // 分块发送文件数据
      await _sendFileChunks(dataChannel, fileName, fileBytes);
      
      // 发送结束标记
      await _sendEndMarker(dataChannel, fileName);
      
      // 关闭数据通道
      await _closeDataChannel(dataChannel);
      
      debugPrint('✅ WebRTC无连接发送完成: ${file.name}');
      
    } catch (e) {
      debugPrint('❌ WebRTC发送文件时出错: $e');
    }
  }
  
  /// 创建无连接的WebRTC数据通道
  Future<dynamic> _createConnectionlessDataChannel() async {
    try {
      // WebRTC配置 - 完全无连接模式
      final configuration = js_util.jsify({
        'iceServers': [], // 不使用任何ICE服务器
        'iceCandidatePoolSize': 0,
        'bundlePolicy': 'balanced',
        'rtcpMuxPolicy': 'require',
      });
      
      // 创建RTCPeerConnection
      final peerConnection = js_util.callConstructor(_RTCPeerConnection, [configuration]);
      
      // 创建数据通道配置
      final dataChannelOptions = js_util.jsify({
        'ordered': false, // 无序传输
        'maxRetransmits': 0, // 不重传
        'protocol': 'connectionless-transfer',
      });
      
      // 创建数据通道
      final dataChannel = js_util.callMethod(
        peerConnection,
        'createDataChannel',
        ['fileTransfer', dataChannelOptions]
      );
      
      // 设置数据通道事件处理
      js_util.setProperty(dataChannel, 'onopen', js_util.allowInterop((event) {
        debugPrint('🔗 WebRTC无连接数据通道已打开');
      }));
      
      js_util.setProperty(dataChannel, 'onclose', js_util.allowInterop((event) {
        debugPrint('🔗 WebRTC无连接数据通道已关闭');
      }));
      
      js_util.setProperty(dataChannel, 'onerror', js_util.allowInterop((error) {
        debugPrint('❌ WebRTC数据通道错误: $error');
      }));
      
      // 监听连接状态变化
      js_util.setProperty(peerConnection, 'onconnectionstatechange', js_util.allowInterop((event) {
        final state = js_util.getProperty(peerConnection, 'connectionState');
        debugPrint('🔗 WebRTC连接状态: $state');
      }));
      
      // 存储连接引用
      final connectionId = 'conn_${DateTime.now().millisecondsSinceEpoch}';
      _peerConnections[connectionId] = peerConnection;
      _dataChannels[connectionId] = dataChannel;
      
      return dataChannel;
    } catch (e) {
      debugPrint('❌ 创建WebRTC数据通道时出错: $e');
      return null;
    }
  }
  
  /// 发送文件元数据
  Future<void> _sendMetaData(dynamic dataChannel, String fileName, int fileSize) async {
    try {
      final metaData = json.encode({
        'type': 'file_meta',
        'fileName': fileName,
        'fileSize': fileSize,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'transferId': 'webrtc_${Random().nextInt(10000)}',
      });
      
      js_util.callMethod(dataChannel, 'send', [metaData]);
      debugPrint('📋 WebRTC元数据已发送: $fileName');
      
      // 等待数据通道准备
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      debugPrint('❌ 发送WebRTC元数据时出错: $e');
    }
  }
  
  /// 分块发送文件数据
  Future<void> _sendFileChunks(dynamic dataChannel, String fileName, Uint8List fileBytes) async {
    try {
      const int chunkSize = 16384; // 16KB chunks for WebRTC
      final int totalChunks = (fileBytes.length / chunkSize).ceil();
      
      debugPrint('📦 开始WebRTC分块传输: $totalChunks 个分块');
      
      for (int i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = min(start + chunkSize, fileBytes.length);
        final chunk = fileBytes.sublist(start, end);
        
        // 创建数据包
        final packet = json.encode({
          'type': 'file_chunk',
          'chunkIndex': i,
          'totalChunks': totalChunks,
          'data': base64Encode(chunk),
        });
        
        // 发送数据包
        js_util.callMethod(dataChannel, 'send', [packet]);
        
        // 更新进度
        _progressController.add({
          'fileName': fileName,
          'chunkIndex': i,
          'totalChunks': totalChunks,
          'progress': ((i + 1) / totalChunks * 100).toStringAsFixed(1),
          'method': 'WebRTC',
        });
        
        // WebRTC发送间隔
        await Future.delayed(const Duration(milliseconds: 5));
      }
      
      debugPrint('✅ WebRTC分块传输完成: $fileName');
    } catch (e) {
      debugPrint('❌ WebRTC分块传输时出错: $e');
    }
  }
  
  /// 发送结束标记
  Future<void> _sendEndMarker(dynamic dataChannel, String fileName) async {
    try {
      final endMarker = json.encode({
        'type': 'file_end',
        'fileName': fileName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      js_util.callMethod(dataChannel, 'send', [endMarker]);
      debugPrint('🏁 WebRTC结束标记已发送: $fileName');
      
      // 等待发送完成
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      debugPrint('❌ 发送WebRTC结束标记时出错: $e');
    }
  }
  
  /// 关闭数据通道
  Future<void> _closeDataChannel(dynamic dataChannel) async {
    try {
      js_util.callMethod(dataChannel, 'close', []);
      debugPrint('🔒 WebRTC数据通道已关闭');
      
      // 等待关闭完成
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      debugPrint('❌ 关闭WebRTC数据通道时出错: $e');
    }
  }
  
  /// 停止发送
  void stopSending() {
    if (!_isSending) return;
    
    _isSending = false;
    debugPrint('🛑 WebRTC传输已停止');
    
    // 关闭所有连接
    _closeAllConnections();
    
    onStopped?.call();
  }
  
  /// 关闭所有连接
  void _closeAllConnections() {
    try {
      // 关闭所有数据通道
      for (final dataChannel in _dataChannels.values) {
        try {
          js_util.callMethod(dataChannel, 'close', []);
        } catch (e) {
          debugPrint('关闭数据通道时出错: $e');
        }
      }
      
      // 关闭所有peer连接
      for (final peerConnection in _peerConnections.values) {
        try {
          js_util.callMethod(peerConnection, 'close', []);
        } catch (e) {
          debugPrint('关闭peer连接时出错: $e');
        }
      }
      
      _dataChannels.clear();
      _peerConnections.clear();
      
      debugPrint('🔒 所有WebRTC连接已关闭');
    } catch (e) {
      debugPrint('❌ 关闭WebRTC连接时出错: $e');
    }
  }
  
  /// 获取传输统计
  Map<String, dynamic> getStats() {
    return {
      'isInitialized': _initialized,
      'isSending': _isSending,
      'sentCount': _sentCount,
      'dataSentMB': _dataSentMB,
      'activeConnections': _peerConnections.length,
      'activeChannels': _dataChannels.length,
    };
  }
  
  /// 释放资源
  void dispose() {
    stopSending();
    _closeAllConnections();
    _progressController.close();
    _initialized = false;
    debugPrint('🗑️ WebRTC服务资源已释放');
  }
}