// 这个文件只在Web平台上编译
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'webrtc_direct_service.dart';

// Web专用导入
import 'package:js/js_util.dart' as js_util;
import 'dart:html' as html;

/// Web平台WebRTC直接传输服务实现
class WebRTCDirectServiceWebImpl implements WebRTCDirectServiceInterface {
  // 回调函数
  final Function(int)? onProgress;
  final Function(double)? onDataSent;
  final Function()? onStopped;
  
  bool _initialized = false;
  bool _isRunning = false;
  int _sentCount = 0;
  double _dataSentMB = 0.0;
  
  // WebRTC相关
  dynamic _RTCPeerConnection;
  final Map<String, dynamic> _peerConnections = {};
  final Map<String, dynamic> _dataChannels = {};
  
  final _progressController = StreamController<Map<String, dynamic>>.broadcast();
  
  WebRTCDirectServiceWebImpl({
    this.onProgress,
    this.onDataSent,
    this.onStopped,
  });
  
  @override
  bool get isInitialized => _initialized;
  
  @override
  bool get isRunning => _isRunning;
  
  @override
  Stream<Map<String, dynamic>> get onTransferProgress => _progressController.stream;
  
  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    
    debugPrint('🚀 初始化Web平台WebRTC无连接直接传输服务...');
    
    try {
      // 检查WebRTC支持
      if (js_util.getProperty(html.window, 'RTCPeerConnection') == null) {
        throw Exception('浏览器不支持WebRTC');
      }
      
      _RTCPeerConnection = js_util.getProperty(html.window, 'RTCPeerConnection');
      
      _initialized = true;
      debugPrint('✅ Web平台WebRTC无连接直接传输服务初始化成功');
      return true;
    } catch (e) {
      debugPrint('❌ 初始化WebRTC服务时出错: $e');
      return false;
    }
  }
  
  @override
  Future<void> startSending({
    required List<PlatformFile> files,
    required bool isLoop,
  }) async {
    if (!_initialized || _isRunning) return;
    
    _isRunning = true;
    _sentCount = 0;
    _dataSentMB = 0.0;
    
    debugPrint('🔗 开始WebRTC无连接直接传输，文件数量: ${files.length}');
    
    try {
      do {
        for (final file in files) {
          if (!_isRunning) break;
          
          await _sendFileViaWebRTC(file);
          
          _sentCount++;
          _dataSentMB += (file.size / 1024 / 1024);
          
          onProgress?.call(_sentCount);
          onDataSent?.call(_dataSentMB);
          
          // 发送间隔
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
        if (isLoop && _isRunning) {
          debugPrint('🔄 循环模式：继续下一轮WebRTC传输');
          await Future.delayed(const Duration(seconds: 1));
        }
      } while (isLoop && _isRunning);
      
    } catch (e) {
      debugPrint('❌ WebRTC传输过程中出错: $e');
    } finally {
      _isRunning = false;
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
      
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      debugPrint('❌ 发送WebRTC元数据时出错: $e');
    }
  }
  
  /// 分块发送文件数据
  Future<void> _sendFileChunks(dynamic dataChannel, String fileName, Uint8List fileBytes) async {
    try {
      const int chunkSize = 1024; // 1KB chunks for WebRTC
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
        await Future.delayed(const Duration(milliseconds: 20));
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
      
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      debugPrint('❌ 关闭WebRTC数据通道时出错: $e');
    }
  }
  
  @override
  void stopSending() {
    if (!_isRunning) return;
    
    _isRunning = false;
    debugPrint('🛑 WebRTC传输已停止');
    
    _closeAllConnections();
    onStopped?.call();
  }
  
  /// 关闭所有连接
  void _closeAllConnections() {
    try {
      for (final dataChannel in _dataChannels.values) {
        try {
          js_util.callMethod(dataChannel, 'close', []);
        } catch (e) {
          debugPrint('关闭数据通道时出错: $e');
        }
      }
      
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
  
  @override
  Map<String, dynamic> getStats() {
    return {
      'isInitialized': _initialized,
      'isSending': _isRunning,
      'sentCount': _sentCount,
      'dataSentMB': _dataSentMB,
      'activeConnections': _peerConnections.length,
      'activeChannels': _dataChannels.length,
    };
  }
  
  @override
  void dispose() {
    stopSending();
    _closeAllConnections();
    _progressController.close();
    _initialized = false;
    debugPrint('🗑️ WebRTC服务资源已释放');
  }
}

/// 创建WebRTC服务的工厂函数（Web平台实现）
WebRTCDirectServiceInterface createWebRTCService({
  Function(int)? onProgress,
  Function(double)? onDataSent,
  Function()? onStopped,
}) {
  return WebRTCDirectServiceWebImpl(
    onProgress: onProgress,
    onDataSent: onDataSent,
    onStopped: onStopped,
  );
}
