import 'package:flutter/material.dart';
import 'dart:async';
import '../services/download_manager.dart';

/// 下载进度对话框
class DownloadProgressDialog extends StatefulWidget {
  final String taskId;
  final DownloadManager downloadManager;
  final VoidCallback onComplete;

  const DownloadProgressDialog({
    Key? key,
    required this.taskId,
    required this.downloadManager,
    required this.onComplete,
  }) : super(key: key);

  @override
  _DownloadProgressDialogState createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog> {
  late StreamSubscription<DownloadTask> _subscription;
  DownloadTask? _currentTask;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _subscribeToTask();
    _startUpdateTimer();
  }

  void _subscribeToTask() {
    // 获取当前任务
    final task = widget.downloadManager.tasks[widget.taskId];
    debugPrint('DownloadProgressDialog: 订阅任务 ${widget.taskId}, 任务状态: ${task?.status}');
    
    if (task != null) {
      if (mounted) {
        setState(() {
          _currentTask = task;
        });
      }
      
      // 立即检查任务状态，如果已经完成或失败，直接处理
      if (task.status == DownloadStatus.completed) {
        debugPrint('DownloadProgressDialog: 任务已完成，延迟关闭对话框');
        // 延迟处理，确保对话框完全显示
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted) {
            _onComplete();
          }
        });
        return;
      } else if (task.status == DownloadStatus.failed) {
        debugPrint('DownloadProgressDialog: 任务已失败，延迟关闭对话框');
        // 延迟处理，确保对话框完全显示
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted) {
            _onError(task.error ?? '下载失败');
          }
        });
        return;
      }
    }

    // 订阅任务更新
    _subscription = widget.downloadManager.taskStream.listen((task) {
      if (task.id == widget.taskId && mounted) {
        debugPrint('DownloadProgressDialog: 收到任务更新 - 状态: ${task.status}');
        setState(() {
          _currentTask = task;
        });

        // 检查任务是否完成或失败
        if (task.status == DownloadStatus.completed) {
          debugPrint('DownloadProgressDialog: Stream收到完成状态，关闭对话框');
          _onComplete();
        } else if (task.status == DownloadStatus.failed) {
          debugPrint('DownloadProgressDialog: Stream收到失败状态，关闭对话框');
          _onError(task.error ?? '下载失败');
        }
      }
    }, onError: (error) {
      // 处理Stream错误
      debugPrint('DownloadProgressDialog: Stream错误: $error');
      if (mounted) {
        _onError('Stream错误: $error');
      }
    });
  }

  void _startUpdateTimer() {
    // 启动定时器来更新显示（用于速度和时间计算）
    _updateTimer = Timer.periodic(Duration(milliseconds: 500), (_) {
      if (mounted && _currentTask != null) {
        setState(() {
          // 强制刷新UI以更新速度和时间显示
        });
      }
    });
  }

  void _onComplete() {
    debugPrint('DownloadProgressDialog: 执行完成回调');
    if (mounted) {
      // 延迟执行，确保所有UI更新完成
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted) {
          try {
            Navigator.of(context).pop();
            debugPrint('DownloadProgressDialog: 对话框已关闭');
          } catch (e) {
            debugPrint('DownloadProgressDialog: 关闭对话框时出错: $e');
          }
          
          // 执行用户回调
          try {
            widget.onComplete();
            debugPrint('DownloadProgressDialog: 用户回调执行完成');
          } catch (e) {
            debugPrint('DownloadProgressDialog: 执行用户回调时出错: $e');
          }
        }
      });
    }
  }

  void _onError(String error) {
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('下载失败: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentTask == null) {
      return AlertDialog(
        title: Text('下载任务不存在'),
        content: Text('下载任务可能已被取消'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('确定'),
          ),
        ],
      );
    }

    final task = _currentTask!;
    final progress = task.progress;
    final downloadedBytes = task.downloadedBytes;
    final totalBytes = task.totalBytes;
    final speed = widget.downloadManager.getDownloadSpeed(task.id);
    final remainingTime = widget.downloadManager.getRemainingTime(task.id);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.download, color: Theme.of(context).primaryColor),
          SizedBox(width: 8),
          Text('下载进度'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 文件名
          Text(
            task.fileName,
            style: TextStyle(fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 16),
          
          // 进度条
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
          SizedBox(height: 8),
          
          // 进度百分比和字节数
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(progress * 100).toStringAsFixed(1)}%'),
              Text(_formatBytes(downloadedBytes, totalBytes)),
            ],
          ),
          SizedBox(height: 8),
          
          // 下载速度和剩余时间
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatSpeed(speed)),
              if (remainingTime > 0) Text(_formatTime(remainingTime)),
            ],
          ),
          
          // 状态信息
          SizedBox(height: 8),
          Text(
            _getStatusText(task.status),
            style: TextStyle(
              color: _getStatusColor(task.status),
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        if (task.status == DownloadStatus.downloading)
          TextButton.icon(
            onPressed: () => widget.downloadManager.pauseDownload(task.id),
            icon: Icon(Icons.pause),
            label: Text('暂停'),
          )
        else if (task.status == DownloadStatus.paused)
          TextButton.icon(
            onPressed: () => widget.downloadManager.resumeDownload(task.id),
            icon: Icon(Icons.play_arrow),
            label: Text('继续'),
          ),
        
        if (task.status != DownloadStatus.completed)
          TextButton.icon(
            onPressed: () {
              widget.downloadManager.cancelDownload(task.id);
              Navigator.of(context).pop();
            },
            icon: Icon(Icons.cancel),
            label: Text('取消'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
      ],
    );
  }

  String _formatBytes(int downloaded, int total) {
    if (total == 0) return '0 B';
    
    String format(int bytes) {
      if (bytes < 1024) return '${bytes} B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    
    return '${format(downloaded)} / ${format(total)}';
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(1)} B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    if (bytesPerSecond < 1024 * 1024 * 1024) return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB/s';
  }

  String _formatTime(int seconds) {
    if (seconds < 60) return '${seconds}秒';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes < 60) return '${minutes}分${remainingSeconds}秒';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}时${remainingMinutes}分';
  }

  String _getStatusText(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.pending:
        return '等待下载...';
      case DownloadStatus.downloading:
        return '正在下载...';
      case DownloadStatus.paused:
        return '下载已暂停';
      case DownloadStatus.completed:
        return '下载完成！';
      case DownloadStatus.failed:
        return '下载失败';
    }
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.pending:
        return Colors.grey;
      case DownloadStatus.downloading:
        return Colors.blue;
      case DownloadStatus.paused:
        return Colors.orange;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
    }
  }
}

/// 下载进度显示小部件
class DownloadProgressWidget extends StatefulWidget {
  final String taskId;
  final DownloadManager downloadManager;

  const DownloadProgressWidget({
    Key? key,
    required this.taskId,
    required this.downloadManager,
  }) : super(key: key);

  @override
  _DownloadProgressWidgetState createState() => _DownloadProgressWidgetState();
}

class _DownloadProgressWidgetState extends State<DownloadProgressWidget> {
  DownloadTask? _currentTask;
  late StreamSubscription<DownloadTask> _subscription;

  @override
  void initState() {
    super.initState();
    _subscribeToTask();
  }

  void _subscribeToTask() {
    // 获取当前任务
    final task = widget.downloadManager.tasks[widget.taskId];
    if (task != null) {
      if (mounted) {
        setState(() {
          _currentTask = task;
        });
      }
    }

    // 订阅任务更新
    _subscription = widget.downloadManager.taskStream.listen((task) {
      if (task.id == widget.taskId && mounted) {
        setState(() {
          _currentTask = task;
        });
      }
    }, onError: (error) {
      // 处理Stream错误，避免静默失败
      debugPrint('下载进度小部件Stream错误: $error');
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentTask == null) return SizedBox.shrink();

    final task = _currentTask!;
    final progress = task.progress;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
          ),
          SizedBox(width: 8),
          Text(
            '${(progress * 100).toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}