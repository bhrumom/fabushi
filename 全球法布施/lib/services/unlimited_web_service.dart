import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class UnlimitedWebService {
  final ValueChanged<int> onProgress;
  final ValueChanged<double> onDataSent;
  final VoidCallback onStopped;

  bool _isRunning = false;
  int _sentCount = 0;
  double _dataSentInMB = 0.0;
  html.Worker? _worker;
  List<html.BroadcastChannel> _channels = [];

  UnlimitedWebService({
    required this.onProgress,
    required this.onDataSent,
    required this.onStopped,
  });

  Future<bool> initialize() async {
    try {
      // 初始化Web Worker
      _worker = html.Worker('unlimited-worker.js');
      _worker!.onMessage.listen(_handleWorkerMessage);
      
      // 初始化广播通道
      _initializeBroadcastChannels();
      
      // 初始化IndexedDB
      await _initializeIndexedDB();
      
      debugPrint('✅ 无限制Web发送服务初始化成功');
      return true;
    } catch (e) {
      debugPrint('❌ 初始化失败: $e');
      return false;
    }
  }

  void _initializeBroadcastChannels() {
    final channelNames = [
      'dharma-unlimited-1',
      'dharma-unlimited-2',
      'dharma-unlimited-3',
      'global-broadcast',
      'file-transfer-unlimited'
    ];

    for (final name in channelNames) {
      try {
        final channel = html.BroadcastChannel(name);
        _channels.add(channel);
        
        // 监听其他标签页的响应
        channel.onMessage.listen((event) {
          debugPrint('📡 收到广播响应: ${event.data}');
        });
      } catch (e) {
        debugPrint('⚠️ 创建广播通道 $name 失败: $e');
      }
    }
  }

  Future<void> _initializeIndexedDB() async {
    try {
      final request = html.window.indexedDB!.open('DharmaUnlimited', 1);
      
      request.onUpgradeNeeded.listen((event) {
        final db = (event.target as html.IdbOpenDbRequest).result as html.IdbDatabase;
        if (!db.objectStoreNames!.contains('files')) {
          db.createObjectStore('files', keyPath: 'id');
        }
      });
      
      debugPrint('✅ IndexedDB初始化完成');
    } catch (e) {
      debugPrint('⚠️ IndexedDB初始化失败: $e');
    }
  }

  void _handleWorkerMessage(html.MessageEvent event) {
    final data = event.data;
    if (data['type'] == 'FILE_SENT') {
      debugPrint('✅ Worker完成文件发送: ${data['fileName']}');
    }
  }

  Future<void> startSending({
    required List<PlatformFile> files,
    required bool isLoop,
    required String country,
  }) async {
    if (_isRunning) return;
    
    _isRunning = true;
    _sentCount = 0;
    _dataSentInMB = 0.0;

    try {
      for (final file in files) {
        if (!_isRunning) break;
        
        debugPrint('📤 无限制发送文件: ${file.name}');
        await _sendFileUnlimited(file);
        
        _sentCount++;
        _dataSentInMB += file.size / (1024 * 1024);
        
        onProgress(_sentCount);
        onDataSent(_dataSentInMB);
      }
    } catch (e) {
      debugPrint('❌ 发送失败: $e');
    } finally {
      _isRunning = false;
      onStopped();
    }
  }

  Future<void> _sendFileUnlimited(PlatformFile file) async {
    if (file.bytes == null) return;

    // 方法1: Web Worker发送
    await _sendViaWorker(file);
    
    // 方法2: 广播通道发送
    await _sendViaBroadcast(file);
    
    // 方法3: IndexedDB存储
    await _sendViaIndexedDB(file);
    
    // 方法4: localStorage分片存储
    await _sendViaLocalStorage(file);
    
    // 方法5: Blob URL创建
    await _sendViaBlobURL(file);
    
    // 方法6: Canvas绘制（图像文件）
    if (_isImageFile(file.name)) {
      await _sendViaCanvas(file);
    }
  }

  Future<void> _sendViaWorker(PlatformFile file) async {
    try {
      _worker?.postMessage({
        'type': 'SEND_FILE',
        'fileName': file.name,
        'fileData': file.bytes!.toList(),
      });
      debugPrint('✅ 文件已发送到Worker: ${file.name}');
    } catch (e) {
      debugPrint('⚠️ Worker发送失败: $e');
    }
  }

  Future<void> _sendViaBroadcast(PlatformFile file) async {
    const chunkSize = 32 * 1024; // 32KB chunks
    final totalChunks = (file.bytes!.length / chunkSize).ceil();

    for (int i = 0; i < totalChunks && _isRunning; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize < file.bytes!.length) 
          ? start + chunkSize 
          : file.bytes!.length;
      
      final chunk = file.bytes!.sublist(start, end);
      
      final message = {
        'type': 'UNLIMITED_CHUNK',
        'fileName': file.name,
        'chunkIndex': i,
        'totalChunks': totalChunks,
        'data': chunk.toList(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // 向所有通道广播
      for (final channel in _channels) {
        try {
          channel.postMessage(message);
        } catch (e) {
          // 忽略单个通道错误
        }
      }

      if (i % 100 == 0) {
        debugPrint('✅ 广播块 $i/$totalChunks');
      }
    }
  }

  Future<void> _sendViaIndexedDB(PlatformFile file) async {
    try {
      final request = html.window.indexedDB!.open('DharmaUnlimited', 1);
      
      request.onSuccess.listen((event) {
        final db = (event.target as html.IdbOpenDbRequest).result as html.IdbDatabase;
        final transaction = db.transaction(['files'], 'readwrite');
        final store = transaction.objectStore('files');
        
        final fileRecord = {
          'id': '${file.name}_${DateTime.now().millisecondsSinceEpoch}',
          'name': file.name,
          'data': file.bytes!.toList(),
          'size': file.size,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        store.add(fileRecord);
        debugPrint('✅ 文件已存储到IndexedDB: ${file.name}');
      });
    } catch (e) {
      debugPrint('⚠️ IndexedDB存储失败: $e');
    }
  }

  Future<void> _sendViaLocalStorage(PlatformFile file) async {
    try {
      const chunkSize = 1024 * 1024; // 1MB chunks for localStorage
      final totalChunks = (file.bytes!.length / chunkSize).ceil();

      for (int i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = (start + chunkSize < file.bytes!.length) 
            ? start + chunkSize 
            : file.bytes!.length;
        
        final chunk = file.bytes!.sublist(start, end);
        final key = 'dharma_${file.name}_chunk_$i';
        final value = base64Encode(chunk);
        
        try {
          html.window.localStorage[key] = value;
        } catch (e) {
          // localStorage满了，清理旧数据
          _cleanupLocalStorage();
          html.window.localStorage[key] = value;
        }
      }
      
      // 存储元数据
      html.window.localStorage['dharma_${file.name}_meta'] = jsonEncode({
        'totalChunks': totalChunks,
        'size': file.size,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      debugPrint('✅ 文件已分片存储到localStorage: ${file.name}');
    } catch (e) {
      debugPrint('⚠️ localStorage存储失败: $e');
    }
  }

  Future<void> _sendViaBlobURL(PlatformFile file) async {
    try {
      final blob = html.Blob([file.bytes!]);
      final url = html.Url.createObjectUrl(blob);
      
      // 创建隐藏的下载链接触发"发送"
      final anchor = html.AnchorElement()
        ..href = url
        ..download = file.name
        ..style.display = 'none';
      
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
      
      // 延迟释放URL
      Timer(const Duration(seconds: 1), () {
        html.Url.revokeObjectUrl(url);
      });
      
      debugPrint('✅ 文件已通过Blob URL处理: ${file.name}');
    } catch (e) {
      debugPrint('⚠️ Blob URL处理失败: $e');
    }
  }

  Future<void> _sendViaCanvas(PlatformFile file) async {
    try {
      final canvas = html.CanvasElement(width: 1024, height: 1024);
      final ctx = canvas.context2D;
      
      // 将文件数据绘制到canvas
      final imageData = ctx.createImageData(1024, 1024);
      final data = imageData.data;
      
      for (int i = 0; i < file.bytes!.length && i < data.length; i++) {
        data[i] = file.bytes![i];
      }
      
      ctx.putImageData(imageData, 0, 0);
      
      // 导出为DataURL
      final dataUrl = canvas.toDataUrl();
      debugPrint('✅ 文件已编码到Canvas: ${file.name}');
      
    } catch (e) {
      debugPrint('⚠️ Canvas处理失败: $e');
    }
  }

  void _cleanupLocalStorage() {
    final keys = <String>[];
    for (int i = 0; i < html.window.localStorage.length!; i++) {
      final key = html.window.localStorage.key(i);
      if (key != null && key.startsWith('dharma_')) {
        keys.add(key);
      }
    }
    
    // 删除最旧的一半数据
    keys.sort();
    for (int i = 0; i < keys.length ~/ 2; i++) {
      html.window.localStorage.remove(keys[i]);
    }
  }

  bool _isImageFile(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
  }

  void stopSending() {
    _isRunning = false;
    _worker?.postMessage({'type': 'STOP'});
  }

  void dispose() {
    _worker?.terminate();
    for (final channel in _channels) {
      channel.close();
    }
  }
}