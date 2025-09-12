import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../services/global_transfer_service.dart';
import '../services/wifi_broadcast_service.dart';
import '../services/webrtc_direct_service.dart';

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
  Future<void> selectBuiltInAssets() async {
    // 这里可以添加内置素材的逻辑
    debugPrint('选择内置素材功能待实现');
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