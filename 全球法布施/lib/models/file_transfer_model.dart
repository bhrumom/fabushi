import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../services/global_transfer_service.dart';
import '../screens/asset_screen.dart';
import '../services/wifi_broadcast_service.dart';
import '../services/webrtc_direct_service.dart';
import '../config/unified_config.dart';

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
  GlobalTransferService? _globalTransferService;
  WebRTCDirectService? _webrtcDirectService;
  
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
      // 显示下载提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('开始下载 ${assetPaths.length} 个素材')),
      );
      
      // 逐个下载素材
      for (String assetPath in assetPaths) {
        await _downloadSingleAsset(context, assetPath);
      }
      
      // 下载完成提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('所有素材下载完成')),
      );
    } catch (e) {
      // 下载失败提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载失败: $e'), backgroundColor: Colors.red),
      );
    }
  }
  
  /// 下载单个素材
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
      
      // 发送请求
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception('下载失败: ${response.statusCode}');
      }
      
      // 获取文件名
      final fileName = assetPath.split('/').last;
      
      // Web平台不支持本地文件保存，直接返回成功
      if (kIsWeb) {
        debugPrint('Web平台跳过文件保存: $fileName');
        // Web平台直接添加到已选文件列表，不保存到本地
        final fileInfo = PlatformFile(
          name: fileName,
          size: response.bodyBytes.length,
          path: null, // Web平台没有本地路径
          bytes: response.bodyBytes,
        );
        addFiles([fileInfo]);
        debugPrint('Web平台素材下载完成: $fileName');
        return;
      }
      
      // 获取保存目录（仅移动端）
      final Directory? dir;
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      
      if (dir == null) {
        throw Exception("无法获取下载目录");
      }
      
      // 创建文件并写入数据
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      
      // 将下载的文件添加到已选文件列表
      final fileInfo = PlatformFile(
        name: fileName,
        size: response.bodyBytes.length,
        path: filePath,
      );
      
      addFiles([fileInfo]);
      
      debugPrint('素材下载完成: $fileName');
    } catch (e) {
      debugPrint('下载素材失败: $e');
      rethrow;
    }
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
      
      // 启动全球发送
      if (_isGlobalSendEnabled && _globalTransferService != null) {
        debugPrint('🌍 启动全球发送服务');
        _globalTransferService!.startSending(
          files: _selectedFiles,
          isWeb: kIsWeb,
          isLoop: _isLooping,
          country: _countryList.first,
        );
      }
      
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
    _globalTransferService?.stopSending();
    _webrtcDirectService?.stopSending();
    
    debugPrint('🛑 所有传输服务已停止');
    notifyListeners();
  }
  
  /// 初始化传输服务
  Future<void> _initializeServices() async {
    // 初始化全球传输服务
    if (_isGlobalSendEnabled) {
      _globalTransferService = GlobalTransferService(
        onProgress: (count) {
          _globalSentCount = count;
          notifyListeners();
        },
        onDataSent: (mb) {
          _globalDataSentMB = mb;
          notifyListeners();
        },
        onStopped: () {
          debugPrint('🌍 全球发送服务已停止');
        },
      );
    }
    

    
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