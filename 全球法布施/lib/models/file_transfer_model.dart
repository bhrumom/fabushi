import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../services/global_transfer_service.dart';
import '../screens/asset_screen.dart';
import '../services/wifi_broadcast_service.dart';
import '../services/webrtc_direct_service.dart';
import '../config/unified_config.dart';
import '../services/downloaded_assets_service.dart';
import '../services/download_manager.dart';
import '../widgets/download_progress_widget.dart';

// Web平台特定的导入
import 'package:universal_html/html.dart' as html;

/// 传输状态枚举
enum TransferStatus {
  idle,
  transferring,
  completed,
  error,
}

/// 文件传输模型
/// 
/// 管理文件传输的状态和逻辑，支持全球发送和WiFi广播
class FileTransferModel extends ChangeNotifier {
  // 传输模式状态
  bool _isGlobalSendEnabled = true;
  bool _isLooping = false;
  double _sendRateMB = 1.0; // 每秒发送MB数
  
  // 文件相关
  List<PlatformFile> _selectedFiles = [];
  List<String> _countryList = ['ALL'];
  
  // 传输状态
  bool _isTransferring = false;
  TransferStatus _status = TransferStatus.idle;
  
  // 统计数据
  int _globalSentCount = 0;
  double _globalDataSentMB = 0.0;
  
  // 传输服务
  // GlobalTransferService? _globalTransferService; // 暂时禁用旧的全局服务引用
  WebRTCDirectService? _webrtcDirectService;
  
  // 已下载素材服务
  final DownloadedAssetsService _downloadedAssetsService = DownloadedAssetsService();
  final DownloadManager _downloadManager = DownloadManager();
  Map<String, String> _assetToTaskMap = {};
  
  // Getters
  bool get isGlobalSendEnabled => _isGlobalSendEnabled;
  bool get isLooping => _isLooping;
  double get sendRateMB => _sendRateMB;
  List<PlatformFile> get selectedFiles => _selectedFiles;
  List<String> get countryList => _countryList;
  bool get isTransferring => _isTransferring;
  TransferStatus get status => _status;
  bool get hasFiles => _selectedFiles.isNotEmpty;
  int get globalSentCount => _globalSentCount;
  double get globalDataSentMB => _globalDataSentMB;
  
  /// 设置全球发送启用状态
  void setGlobalSendEnabled(bool enabled) {
    _isGlobalSendEnabled = enabled;
    notifyListeners();
  }
  
  /// 设置循环发送状态
  void setLooping(bool looping) {
    _isLooping = looping;
    notifyListeners();
  }
  
  /// 设置发送速度
  void setSendRateMB(double rateMB) {
    _sendRateMB = rateMB.clamp(0.1, 5.0);
    notifyListeners();
  }
  
  /// 设置国家列表
  void setCountryList(List<String> countries) {
    _countryList = countries;
    notifyListeners();
  }
  
  /// 选择文件
  Future<void> selectFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: true,
      );
      
      if (result != null) {
        _selectedFiles.addAll(result.files);
        notifyListeners();
        debugPrint('已选择 ${result.files.length} 个文件');
      }
    } catch (e) {
      debugPrint('选择文件失败: $e');
    }
  }
  
  /// 选择内置素材
  Future<void> selectBuiltInAssets(BuildContext context) async {
    // 所有平台都导航到AssetScreen
    final selectedAssets = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AssetScreen()),
    );
    
    // 如果用户选择了素材，则从Cloudflare下载
    if (selectedAssets != null && selectedAssets is List && selectedAssets.isNotEmpty) {
      // 将List<dynamic>转换为List<String>
      final List<String> assetPaths = selectedAssets.map((asset) => asset.toString()).toList();
      _downloadSelectedAssets(context, assetPaths);
    }
  }
  
  /// 下载选中的素材
  Future<void> _downloadSelectedAssets(BuildContext context, List<String> assetPaths) async {
    try {
      // 初始化已下载素材服务
      await _downloadedAssetsService.initialize();
      
      // 分离已下载和未下载的素材
      final List<String> needDownloadAssets = [];
      final List<String> alreadyDownloadedAssets = [];
      
      for (String assetPath in assetPaths) {
        if (_downloadedAssetsService.isAssetDownloaded(assetPath)) {
          alreadyDownloadedAssets.add(assetPath);
        } else {
          needDownloadAssets.add(assetPath);
        }
      }
      
      // 显示智能提示
      String message = '';
      if (alreadyDownloadedAssets.isNotEmpty && needDownloadAssets.isNotEmpty) {
        message = '发现 ${alreadyDownloadedAssets.length} 个素材已下载，将下载 ${needDownloadAssets.length} 个新素材';
      } else if (alreadyDownloadedAssets.isNotEmpty) {
        message = '所有 ${alreadyDownloadedAssets.length} 个素材都已下载，将直接复用';
      } else if (needDownloadAssets.isNotEmpty) {
        message = '开始下载 ${needDownloadAssets.length} 个素材';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      
      // 处理已下载的素材（直接复用）
      if (alreadyDownloadedAssets.isNotEmpty) {
        await _reuseDownloadedAssets(context, alreadyDownloadedAssets);
      }
      
      // 下载未下载的素材
      if (needDownloadAssets.isNotEmpty) {
        for (String assetPath in needDownloadAssets) {
          await _downloadSingleAsset(context, assetPath);
        }
      }
      
      // 下载完成提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('所有素材处理完成')),
      );
    } catch (e) {
      // 下载失败提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('处理失败: $e'), backgroundColor: Colors.red),
      );
    }
  }
  
  /// 复用已下载的素材
  Future<void> _reuseDownloadedAssets(BuildContext context, List<String> assetPaths) async {
    try {
      for (String assetPath in assetPaths) {
        final fileName = assetPath.split('/').last;
        
        if (kIsWeb) {
          // Web平台：从本地存储读取文件数据
          final fileData = await _getFileFromWebStorage(fileName);
          if (fileData != null) {
            final fileInfo = PlatformFile(
              name: fileName,
              size: fileData.length,
              path: null, // Web平台没有本地路径
              bytes: Uint8List.fromList(fileData),
            );
            addFiles([fileInfo]);
            debugPrint('Web平台复用已下载素材: $fileName');
          }
        } else {
          // 本地平台：从本地文件读取
          final Directory? dir;
          if (Platform.isAndroid) {
            dir = await getExternalStorageDirectory();
          } else {
            dir = await getApplicationDocumentsDirectory();
          }
          
          if (dir != null) {
            final filePath = '${dir.path}/$fileName';
            final file = File(filePath);
            
            if (await file.exists()) {
              final fileInfo = PlatformFile(
                name: fileName,
                size: await file.length(),
                path: filePath,
              );
              addFiles([fileInfo]);
              debugPrint('本地平台复用已下载素材: $fileName');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('复用已下载素材失败: $e');
      rethrow;
    }
  }

  /// 从Web存储获取文件
  Future<List<int>?> _getFileFromWebStorage(String fileName) async {
    try {
      // 从Web平台的localStorage获取文件数据
      final savedFilesStr = html.window.localStorage['saved_files'] ?? '[]';
      final List<dynamic> savedFiles = json.decode(savedFilesStr);
      
      // 查找文件信息
      final fileInfo = savedFiles.firstWhere(
        (f) => f['name'] == fileName,
        orElse: () => null,
      );
      
      if (fileInfo == null) return null;
      
      // 获取文件数据
      final fileDataStr = html.window.localStorage['file_$fileName'];
      if (fileDataStr == null) return null;
      
      // 解码base64数据
      return base64.decode(fileDataStr);
    } catch (e) {
      debugPrint('从Web存储获取文件失败: $e');
      return null;
    }
  }

  /// 下载单个素材（增强版，支持进度显示、暂停、断点续传）
  Future<void> _downloadSingleAsset(BuildContext context, String assetPath) async {
    try {
      // 构建下载URL - 根据素材路径判断是静态文件还是R2文件
      // 如果路径包含中文佛经或音频文件，说明是静态文件
      final bool isStaticFile = assetPath.contains('乾隆大藏经') || 
                               assetPath.contains('房山石经陀罗尼') || 
                               assetPath.contains('咒语') ||
                               assetPath.contains('经文');
      
      final String url;
      if (isStaticFile) {
        // 静态文件直接访问
        url = '${UnifiedConfig.currentBackendUrl}/$assetPath';
      } else {
        // 其他文件使用R2端点
        url = '${UnifiedConfig.currentBackendUrl}/r2?file=${Uri.encodeComponent(assetPath)}';
      }
      
      debugPrint('下载素材URL: $url');
      
      // 获取文件名
      final fileName = assetPath.split('/').last;
      
      // 检查是否已有下载任务
      final existingTaskId = _assetToTaskMap[assetPath];
      if (existingTaskId != null) {
        final task = _downloadManager.tasks[existingTaskId];
        if (task != null && task.status == DownloadStatus.paused) {
          // 如果任务已暂停，恢复下载
          await _downloadManager.resumeDownload(existingTaskId);
          return;
        }
      }
      
      // 创建下载任务
      final taskId = await _downloadManager.createTask(url, fileName, assetPath);
      _assetToTaskMap[assetPath] = taskId;
      
      // 显示下载进度对话框
      _showDownloadProgressDialog(context, taskId, fileName);
      
      // 开始下载
      await _downloadManager.startDownload(taskId);
      
    } catch (e) {
      debugPrint('下载素材失败: $e');
      rethrow;
    }
  }

  /// 显示下载进度对话框
  void _showDownloadProgressDialog(BuildContext context, String taskId, String fileName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DownloadProgressDialog(
        taskId: taskId,
        downloadManager: _downloadManager,
        onComplete: () async {
          debugPrint('📥 下载完成回调开始执行');
          
          try {
            // 获取下载的文件
            final task = _downloadManager.tasks[taskId];
            if (task != null && task.status == DownloadStatus.completed) {
              final fileName = task.fileName;
              debugPrint('📁 处理下载完成的文件: $fileName');
              
              if (kIsWeb) {
                // Web平台：从localStorage获取文件
                debugPrint('🌐 Web平台：获取下载的文件数据');
                final fileData = await _downloadManager.getDownloadedFile(fileName);
                if (fileData != null) {
                  debugPrint('📊 文件数据获取成功，大小: ${fileData.length} bytes');
                  final fileInfo = PlatformFile(
                    name: fileName,
                    size: fileData.length,
                    path: null, // Web平台没有本地路径
                    bytes: fileData,
                  );
                  
                  // 添加文件到选择列表
                  addFiles([fileInfo]);
                  debugPrint('✅ 文件已添加到选择列表');
                  
                  // 标记素材为已下载
                  await _downloadedAssetsService.markAssetAsDownloaded(task.assetPath);
                  debugPrint('🏷️ 素材已标记为已下载');
                  
                  // 延迟确保UI更新
                  await Future.delayed(Duration(milliseconds: 200));
                  debugPrint('⏱️ UI更新延迟完成');
                } else {
                  debugPrint('❌ Web平台文件数据获取失败');
                }
              } else {
                // 本地平台：从文件系统获取文件
                debugPrint('📱 本地平台：获取下载的文件');
                final Directory? dir;
                if (Platform.isAndroid) {
                  dir = await getExternalStorageDirectory();
                } else {
                  dir = await getApplicationDocumentsDirectory();
                }
                
                if (dir != null) {
                  final filePath = '${dir.path}/$fileName';
                  final file = File(filePath);
                  
                  if (await file.exists()) {
                    debugPrint('📂 文件存在，路径: $filePath');
                    final fileInfo = PlatformFile(
                      name: fileName,
                      size: await file.length(),
                      path: filePath,
                    );
                    
                    // 添加文件到选择列表
                    addFiles([fileInfo]);
                    debugPrint('✅ 文件已添加到选择列表');
                    
                    // 标记素材为已下载
                    await _downloadedAssetsService.markAssetAsDownloaded(task.assetPath);
                    debugPrint('🏷️ 素材已标记为已下载');
                    
                    // 延迟确保UI更新
                    await Future.delayed(Duration(milliseconds: 200));
                    debugPrint('⏱️ UI更新延迟完成');
                  } else {
                    debugPrint('❌ 本地文件不存在: $filePath');
                  }
                } else {
                  debugPrint('❌ 无法获取本地目录');
                }
              }
            } else {
              debugPrint('❌ 下载任务不存在或状态不正确');
            }
          } catch (e) {
            debugPrint('❌ 下载完成处理出错: $e');
          } finally {
            // 清理任务
            _assetToTaskMap.remove(taskId);
            debugPrint('🧹 任务清理完成');
            
            // 确保关闭对话框
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              debugPrint('🔒 对话框已关闭');
            }
          }
        },
      ),
    );
  }
  
  /// 添加文件
  void addFiles(List<PlatformFile> files) {
    _selectedFiles.addAll(files);
    notifyListeners();
  }
  
  /// 移除文件
  void removeFile(PlatformFile file) {
    _selectedFiles.remove(file);
    notifyListeners();
  }
  
  /// 清空文件
  void clearFiles() {
    _selectedFiles.clear();
    notifyListeners();
  }
  
  /// 获取文件类型
  String getFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return '图片';
      case 'mp4':
      case 'avi':
      case 'mov':
        return '视频';
      case 'mp3':
      case 'wav':
      case 'flac':
        return '音频';
      case 'pdf':
        return 'PDF';
      case 'doc':
      case 'docx':
        return '文档';
      case 'txt':
        return '文本';
      default:
        return '文件';
    }
  }
  
  /// 获取文件大小字符串
  String getFileSizeString(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
  
  /// 开始传输
  Future<void> startTransfer() async {
    if (_isTransferring || _selectedFiles.isEmpty) return;
    
    _isTransferring = true;
    _status = TransferStatus.transferring;
    _resetStats();
    notifyListeners();
    
    try {
      debugPrint('🚀 开始真实传输 - 文件数量: ${_selectedFiles.length}');
      
      // 初始化传输服务
      await _initializeServices();
      
      // 全球发送逻辑已迁移到 GlobalDharmaScreen，此处禁用
      // if (_isGlobalSendEnabled && _globalTransferService != null) {
      //   debugPrint('🌍 启动全球发送服务');
      //   _globalTransferService!.startSending(
      //     files: _selectedFiles,
      //     isWeb: kIsWeb,
      //     isLoop: _isLooping,
      //     country: _countryList.first,
      //   );
      // }
      
      // 启动WebRTC直接传输
      if (_webrtcDirectService != null) {
        debugPrint('🔗 启动WebRTC直接传输服务');
        await _webrtcDirectService!.startSending(
          files: _selectedFiles,
          isLoop: _isLooping,
        );
      }
      
      _status = TransferStatus.completed;
      
    } catch (e) {
      debugPrint('❌ 传输启动失败: $e');
      _status = TransferStatus.error;
      _isTransferring = false;
      notifyListeners();
    }
  }
  
  /// 停止传输
  void stopTransfer() {
    if (!_isTransferring) return;
    
    _isTransferring = false;
    _status = TransferStatus.idle;
    
    // 停止所有传输服务
    // _globalTransferService?.stopSending(); // 禁用
    _webrtcDirectService?.stopSending();
    
    debugPrint('🛑 所有传输服务已停止');
    notifyListeners();
  }
  
  /// 初始化传输服务
  Future<void> _initializeServices() async {
    // 初始化全球传输服务 (已禁用，逻辑迁移到 GlobalDharmaScreen)
    // if (_isGlobalSendEnabled) {
    //   _globalTransferService = GlobalTransferService(
    //     onProgress: (count) {
    //       _globalSentCount = count;
    //       notifyListeners();
    //     },
    //     onDataSent: (mb) {
    //       _globalDataSentMB = mb;
    //       notifyListeners();
    //     },
    //     onStopped: () {
    //       debugPrint('🌍 全球发送服务已停止');
    //     },
    //   );
    // }
    

    
    // 初始化WebRTC直接传输服务
    _webrtcDirectService = WebRTCDirectService(
      onProgress: (count) {
        // WebRTC的进度会合并到其他服务中
        debugPrint('🔗 WebRTC传输进度: $count');
      },
      onDataSent: (mb) {
        // WebRTC的数据会合并到其他服务中
        debugPrint('🔗 WebRTC传输数据: ${mb.toStringAsFixed(2)} MB');
      },
      onStopped: () {
        debugPrint('🔗 WebRTC直接传输服务已停止');
        if (_isTransferring) {
          _isTransferring = false;
          _status = TransferStatus.completed;
          notifyListeners();
        }
      },
    );
    
    // 初始化WebRTC服务
    if (_webrtcDirectService != null) {
      await _webrtcDirectService!.initialize();
    }
  }
  
  /// 更新传输进度
  void updateProgress(int count) {
    _globalSentCount = count;
    notifyListeners();
  }
  
  /// 更新已发送数据量
  void updateDataSent(double dataMB) {
    _globalDataSentMB = dataMB;
    notifyListeners();
  }
  
  /// 更新传输状态
  void updateStatus(TransferStatus status) {
    _status = status;
    notifyListeners();
  }
  
  /// 重置统计数据
  void _resetStats() {
    _globalSentCount = 0;
    _globalDataSentMB = 0.0;
  }
  
  @override
  void dispose() {
    stopTransfer();
    super.dispose();
  }
}