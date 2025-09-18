import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';

/// 下载任务状态枚举
enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
}

/// 下载任务模型
class DownloadTask {
  final String id;
  final String url;
  final String fileName;
  final String assetPath;
  double progress;
  DownloadStatus status;
  int totalBytes;
  int downloadedBytes;
  String? error;
  DateTime? startTime;
  DateTime? pauseTime;
  List<int>? partialData;

  DownloadTask({
    required this.id,
    required this.url,
    required this.fileName,
    required this.assetPath,
    this.progress = 0.0,
    this.status = DownloadStatus.pending,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.error,
    this.startTime,
    this.pauseTime,
    this.partialData,
  });
}

/// 下载管理器
class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal() {
    _initializeStreamController();
  }

  final Map<String, DownloadTask> _tasks = {};
  late StreamController<DownloadTask> _taskStreamController;
  final Map<String, http.StreamedResponse> _activeResponses = {};
  final Map<String, StreamSubscription<List<int>>> _activeSubscriptions = {};
  bool _isDisposed = false;

  /// 初始化StreamController
  void _initializeStreamController() {
    _taskStreamController = StreamController.broadcast(
      onListen: () => debugPrint('DownloadManager: StreamController开始监听'),
      onCancel: () => debugPrint('DownloadManager: StreamController取消监听'),
    );
  }

  /// 获取任务流
  Stream<DownloadTask> get taskStream => _taskStreamController.stream;

  /// 获取所有任务
  Map<String, DownloadTask> get tasks => Map.unmodifiable(_tasks);

  /// 创建下载任务
  Future<String> createTask(String url, String fileName, String assetPath) async {
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final task = DownloadTask(
      id: taskId,
      url: url,
      fileName: fileName,
      assetPath: assetPath,
      startTime: DateTime.now(),
    );

    _tasks[taskId] = task;
    _notifyTaskUpdate(task);
    return taskId;
  }

  /// 开始下载
  Future<void> startDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    if (task.status == DownloadStatus.downloading) return;

    task.status = DownloadStatus.downloading;
    task.error = null;
    _notifyTaskUpdate(task);

    try {
      if (kIsWeb) {
        await _downloadForWeb(task);
      } else {
        await _downloadWithResume(task);
      }
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.error = e.toString();
      _notifyTaskUpdate(task);
    }
  }

  /// 暂停下载
  Future<void> pauseDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    if (task.status != DownloadStatus.downloading) return;

    // 取消活跃的订阅
    _activeSubscriptions[taskId]?.cancel();
    _activeSubscriptions.remove(taskId);

    // 关闭响应
    _activeResponses.remove(taskId);

    task.status = DownloadStatus.paused;
    task.pauseTime = DateTime.now();
    _notifyTaskUpdate(task);
  }

  /// 恢复下载
  Future<void> resumeDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    if (task.status != DownloadStatus.paused) return;

    await startDownload(taskId);
  }

  /// 取消下载
  Future<void> cancelDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    debugPrint('取消下载任务: $taskId, 当前状态: ${task.status}');
    
    // 先暂停下载（这会取消流订阅和关闭响应）
    await pauseDownload(taskId);
    
    // 更新任务状态为已取消
    task.status = DownloadStatus.paused; // 使用paused状态表示已取消
    task.error = '下载已取消';
    _notifyTaskUpdate(task);
    
    // 延迟后移除任务，确保取消信号被处理
    Future.delayed(Duration(milliseconds: 100), () {
      _tasks.remove(taskId);
      debugPrint('下载任务已移除: $taskId');
    });
  }

  /// 断点续传下载（仅本地平台）
  Future<void> _downloadWithResume(DownloadTask task) async {
    final Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    if (dir == null) {
      throw Exception('无法获取下载目录');
    }

    final tempFilePath = '${dir.path}/${task.fileName}.download';
    final finalFilePath = '${dir.path}/${task.fileName}';
    final tempFile = File(tempFilePath);

    // 检查是否存在部分下载的文件
    int startByte = 0;
    if (await tempFile.exists()) {
      startByte = await tempFile.length();
      task.downloadedBytes = startByte;
    }

    // 发送带有Range头的请求
    final request = http.Request('GET', Uri.parse(task.url));
    if (startByte > 0) {
      request.headers['Range'] = 'bytes=$startByte-';
    }

    final response = await http.Client().send(request);
    _activeResponses[task.id] = response;

    if (response.statusCode != 200 && response.statusCode != 206) {
      throw Exception('下载失败: ${response.statusCode}');
    }

    // 获取文件总大小
    if (response.contentLength != null) {
      task.totalBytes = startByte + response.contentLength!;
    } else {
      // 从Content-Range头获取总大小
      final contentRange = response.headers['content-range'];
      if (contentRange != null) {
        final match = RegExp(r'/(\d+)').firstMatch(contentRange);
        if (match != null) {
          task.totalBytes = int.parse(match.group(1)!);
        }
      }
    }

    // 打开文件进行追加写入
    final sink = tempFile.openWrite(mode: FileMode.append);
    int lastProgressUpdate = DateTime.now().millisecondsSinceEpoch;

    try {
      final subscription = response.stream.listen(
        (chunk) {
          sink.add(chunk);
          task.downloadedBytes += chunk.length;

          // 更新进度（限制更新频率）
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastProgressUpdate > 100) { // 每100ms更新一次
            task.progress = task.totalBytes > 0 ? task.downloadedBytes / task.totalBytes : 0.0;
            _notifyTaskUpdate(task);
            lastProgressUpdate = now;
          }
        },
        onError: (error) {
          sink.close();
          task.status = DownloadStatus.failed;
          task.error = error.toString();
          _notifyTaskUpdate(task);
        },
        onDone: () async {
          await sink.close();
          
          if (task.status == DownloadStatus.downloading) {
            // 下载完成，重命名文件
            await tempFile.rename(finalFilePath);
            
            task.status = DownloadStatus.completed;
            task.progress = 1.0;
            _notifyTaskUpdate(task);
          }
        },
      );

      _activeSubscriptions[task.id] = subscription;
    } catch (e) {
      await sink.close();
      rethrow;
    }
  }

  /// Web平台下载
  Future<void> _downloadForWeb(DownloadTask task) async {
    try {
      // 使用流式请求来支持进度更新和取消
      final request = http.Request('GET', Uri.parse(task.url));
      final response = await http.Client().send(request);
      
      if (response.statusCode != 200) {
        throw Exception('下载失败: ${response.statusCode}');
      }

      // 获取文件总大小
      task.totalBytes = response.contentLength ?? 0;
      
      // 监听下载进度
      final chunks = <int>[];
      int lastProgressUpdate = DateTime.now().millisecondsSinceEpoch;
      
      await for (final chunk in response.stream) {
        // 检查任务是否被取消
        if (task.status != DownloadStatus.downloading) {
          debugPrint('Web下载被取消，停止接收数据');
          return;
        }
        
        chunks.addAll(chunk);
        task.downloadedBytes += chunk.length;
        
        // 更新进度（限制更新频率）
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastProgressUpdate > 100) { // 每100ms更新一次
          task.progress = task.totalBytes > 0 ? task.downloadedBytes / task.totalBytes : 0.0;
          _notifyTaskUpdate(task);
          lastProgressUpdate = now;
        }
      }

      // 下载完成，保存到localStorage
      final fileData = base64.encode(Uint8List.fromList(chunks));
      final savedFilesStr = html.window.localStorage['saved_files'] ?? '[]';
      final List<dynamic> savedFiles = json.decode(savedFilesStr);
      
      // 添加或更新文件信息
      final fileInfo = {
        'name': task.fileName,
        'size': chunks.length,
        'path': task.assetPath,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // 移除已存在的相同文件
      savedFiles.removeWhere((f) => f['name'] == task.fileName);
      savedFiles.add(fileInfo);
      
      // 保存文件信息和数据
      html.window.localStorage['saved_files'] = json.encode(savedFiles);
      html.window.localStorage['file_${task.fileName}'] = fileData;

      task.status = DownloadStatus.completed;
      task.progress = 1.0;
      task.totalBytes = chunks.length;
      task.downloadedBytes = chunks.length;
      _notifyTaskUpdate(task);
      
      debugPrint('Web下载完成: ${task.fileName}, 大小: ${chunks.length} bytes');
    } catch (e) {
      // 只有在任务未被取消的情况下才标记为失败
      if (task.status == DownloadStatus.downloading) {
        task.status = DownloadStatus.failed;
        task.error = e.toString();
        _notifyTaskUpdate(task);
      }
      debugPrint('Web下载失败: $e');
      rethrow;
    }
  }

  /// 获取已下载文件（Web平台）
  Future<Uint8List?> getDownloadedFile(String fileName) async {
    try {
      final savedFilesStr = html.window.localStorage['saved_files'] ?? '[]';
      final List<dynamic> savedFiles = json.decode(savedFilesStr);
      
      final fileInfo = savedFiles.firstWhere(
        (f) => f['name'] == fileName,
        orElse: () => null,
      );
      
      if (fileInfo == null) return null;
      
      final fileDataStr = html.window.localStorage['file_$fileName'];
      if (fileDataStr == null) return null;
      
      return base64.decode(fileDataStr);
    } catch (e) {
      return null;
    }
  }

  /// 清理完成的任务
  void clearCompletedTasks() {
    _tasks.removeWhere((id, task) => task.status == DownloadStatus.completed);
  }

  /// 获取下载速度（字节/秒）
  double getDownloadSpeed(String taskId) {
    final task = _tasks[taskId];
    if (task == null || task.startTime == null) return 0.0;

    // 如果任务已暂停，使用暂停时间来计算实际下载时间
    final DateTime endTime;
    if (task.status == DownloadStatus.paused && task.pauseTime != null) {
      endTime = task.pauseTime!;
    } else {
      endTime = DateTime.now();
    }

    final elapsedSeconds = endTime.difference(task.startTime!).inSeconds;
    if (elapsedSeconds == 0) return 0.0;

    return task.downloadedBytes / elapsedSeconds;
  }

  

  /// 获取剩余时间（秒）
  int getRemainingTime(String taskId) {
    final task = _tasks[taskId];
    if (task == null || task.totalBytes == 0) return 0;
    
    final downloadSpeed = getDownloadSpeed(taskId);
    if (downloadSpeed == 0) return 0;

    final remainingBytes = task.totalBytes - task.downloadedBytes;
    return (remainingBytes / downloadSpeed).ceil();
  }

  /// 通知任务更新
  void _notifyTaskUpdate(DownloadTask task) {
    if (!_isDisposed && !_taskStreamController.isClosed) {
      try {
        _taskStreamController.add(task);
      } catch (e) {
        debugPrint('DownloadManager: 通知任务更新失败 - $e');
        // 如果StreamController已经关闭，尝试重新初始化
        if (_taskStreamController.isClosed && !_isDisposed) {
          debugPrint('DownloadManager: StreamController已关闭，尝试重新初始化');
          _initializeStreamController();
          try {
            _taskStreamController.add(task);
          } catch (e2) {
            debugPrint('DownloadManager: 重新初始化后仍然失败 - $e2');
          }
        }
      }
    }
  }

  /// 释放资源
  void dispose() {
    if (_isDisposed) return;
    
    debugPrint('DownloadManager: 开始释放资源');
    _isDisposed = true;
    
    // 先取消所有活跃的订阅
    _activeSubscriptions.forEach((_, subscription) => subscription.cancel());
    _activeSubscriptions.clear();
    _activeResponses.clear();
    
    // 最后关闭StreamController
    if (!_taskStreamController.isClosed) {
      _taskStreamController.close();
      debugPrint('DownloadManager: StreamController已关闭');
    }
    
    debugPrint('DownloadManager: 资源释放完成');
  }
}