import 'package:flutter/material.dart';
import '../services/llm_model_config.dart';
import '../services/llm_model_manager.dart';
import '../services/device_capability_service.dart';
import '../services/app_settings.dart';

/// 模型选择对话框
/// 
/// 用于首次启动时引导用户选择 AI 模型，
/// 或在设置中手动切换模型。
/// 支持按类别分组显示，多模态模型显示特殊标识。
class ModelSelectionDialog extends StatefulWidget {
  /// 是否为首次启动引导模式
  final bool isFirstLaunch;
  
  /// 过滤显示的模型类别（null 表示全部显示）
  final LLMModelCategory? filterCategory;
  
  const ModelSelectionDialog({
    Key? key,
    this.isFirstLaunch = false,
    this.filterCategory,
  }) : super(key: key);

  /// 显示模型选择对话框
  static Future<LLMModelType?> show(
    BuildContext context, {
    bool isFirstLaunch = false,
    LLMModelCategory? filterCategory,
  }) async {
    return showDialog<LLMModelType>(
      context: context,
      barrierDismissible: true, // 允许点击外部关闭
      builder: (context) => ModelSelectionDialog(
        isFirstLaunch: isFirstLaunch,
        filterCategory: filterCategory,
      ),
    );
  }

  @override
  State<ModelSelectionDialog> createState() => _ModelSelectionDialogState();
}

class _ModelSelectionDialogState extends State<ModelSelectionDialog> {
  DeviceCapabilityInfo? _deviceInfo;
  Map<LLMModelType, ModelStatus>? _modelStatus;
  LLMModelType? _selectedType;
  bool _isLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStage = '';
  String? _error;
  
  // 当前展开的类别
  Set<LLMModelCategory> _expandedCategories = {
    LLMModelCategory.textOnly,
    LLMModelCategory.multimodal,
  };

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final deviceInfo = await DeviceCapabilityService.instance.getDeviceCapabilityInfo();
      final modelStatus = await LLMModelManager.instance.getAllModelStatus();
      
      // 加载已选择的模型
      final savedModelName = await AppSettings.getSelectedModelName();
      LLMModelType? savedType;
      if (savedModelName != null) {
        try {
          savedType = LLMModelType.values.firstWhere((t) => t.name == savedModelName);
        } catch (_) {}
      }
      
      if (mounted) {
        setState(() {
          _deviceInfo = deviceInfo;
          _modelStatus = modelStatus;
          _selectedType = savedType ?? deviceInfo.recommendedModel;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载设备信息失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadAndSelect(LLMModelType type) async {
    // 检查是否已下载
    if (_modelStatus?[type] == ModelStatus.downloaded) {
      await _selectModel(type);
      return;
    }

    // 开始下载
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStage = '准备下载';
      _selectedType = type;
    });

    // 使用 Future 开始下载，不等待完成（允许后台运行）
    _startBackgroundDownload(type);
  }
  
  /// 启动后台下载
  void _startBackgroundDownload(LLMModelType type) {
    LLMModelManager.instance.downloadModel(
      type,
      onProgress: (progress, stage) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
            _downloadStage = stage;
          });
        }
      },
    ).then((_) async {
      // 下载完成
      if (mounted) {
        await _selectModel(type);
      } else {
        // 对话框已关闭，显示全局通知
        _showDownloadCompleteNotification(type);
      }
    }).catchError((e) {
      if (mounted) {
        setState(() {
          _error = '下载失败: $e';
          _isDownloading = false;
        });
      } else {
        // 对话框已关闭，显示全局错误通知
        _showDownloadErrorNotification(e);
      }
    });
  }
  
  /// 显示下载完成通知（当对话框已关闭时）
  static void _showDownloadCompleteNotification(LLMModelType type) {
    final config = LLMModelConfig.getConfig(type);
    // 保存选择
    AppSettings.setSelectedModelName(type.name);
    AppSettings.setModelSetupComplete(true);
    LLMModelManager.instance.selectedModel = type;
    
    // 使用全局 OverlayEntry 显示通知
    GlobalNotification.show(
      message: '${config.displayName} 下载完成',
      isError: false,
    );
  }
  
  /// 显示下载错误通知
  static void _showDownloadErrorNotification(dynamic error) {
    GlobalNotification.show(
      message: '模型下载失败: $error',
      isError: true,
    );
  }
  
  /// 隐藏对话框，继续后台下载
  void _hideAndContinueDownload() {
    // 保存 Overlay 引用以便后台下载完成后显示通知
    GlobalNotification.saveOverlay(context);
    Navigator.of(context).pop(); // 关闭对话框，下载继续在后台进行
  }

  Future<void> _selectModel(LLMModelType type) async {
    // 保存选择
    await AppSettings.setSelectedModelName(type.name);
    await AppSettings.setModelSetupComplete(true);
    
    LLMModelManager.instance.selectedModel = type;
    
    if (mounted) {
      Navigator.of(context).pop(type);
    }
  }

  void _cancelDownload() {
    LLMModelManager.instance.cancelDownload();
    setState(() {
      _isDownloading = false;
      _downloadProgress = 0.0;
      _downloadStage = '';
    });
  }
  
  /// 选中模型卡片（不自动下载）
  void _selectModelCard(LLMModelType type) {
    setState(() {
      _selectedType = type;
    });
  }
  
  /// 构建操作按钮
  Widget _buildActionButtons() {
    final hasSelectedModel = _selectedType != null;
    final status = hasSelectedModel ? (_modelStatus?[_selectedType!] ?? ModelStatus.notDownloaded) : null;
    final isDownloaded = status == ModelStatus.downloaded;
    
    return Row(
      children: [
        // 暂不下载/关闭按钮
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white54,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(widget.isFirstLaunch ? '暂不下载' : '取消'),
          ),
        ),
        const SizedBox(width: 12),
        // 下载并使用/确定按钮
        Expanded(
          child: ElevatedButton(
            onPressed: hasSelectedModel ? () => _downloadAndSelect(_selectedType!) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black87,
              disabledBackgroundColor: Colors.white12,
              disabledForegroundColor: Colors.white24,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(isDownloaded ? '使用此模型' : '下载并使用'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 650),
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? _buildLoading()
            : _isDownloading
                ? _buildDownloadProgress()
                : _buildModelSelection(),
      ),
    );
  }

  Widget _buildLoading() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: Colors.amber),
        SizedBox(height: 16),
        Text(
          '正在检测设备配置...',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildDownloadProgress() {
    final config = LLMModelConfig.getConfig(_selectedType!);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.downloading, color: Colors.amber, size: 48),
        const SizedBox(height: 16),
        Text(
          '正在下载 ${config.displayName}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          config.totalSizeString, // 使用总大小（含 mmproj）
          style: const TextStyle(color: Colors.white54),
        ),
        if (_downloadStage.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _downloadStage,
            style: const TextStyle(color: Colors.amber, fontSize: 12),
          ),
        ],
        const SizedBox(height: 24),
        LinearProgressIndicator(
          value: _downloadProgress,
          backgroundColor: Colors.white12,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
        ),
        const SizedBox(height: 8),
        Text(
          '${(_downloadProgress * 100).toStringAsFixed(1)}%',
          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        // 按钮行：隐藏到后台 + 取消下载
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: _hideAndContinueDownload,
              icon: const Icon(Icons.minimize, color: Colors.white70, size: 18),
              label: const Text('后台下载', style: TextStyle(color: Colors.white70)),
            ),
            TextButton.icon(
              onPressed: _cancelDownload,
              icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
              label: const Text('取消', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModelSelection() {
    return Column(
      mainAxisSize: MainAxisSize.max, // 改为 max 以占满可用空间
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Row(
          children: [
            const Icon(Icons.psychology, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            Text(
              widget.isFirstLaunch ? '选择 AI 模型' : '切换 AI 模型',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // 设备信息
        if (_deviceInfo != null) _buildDeviceInfo(),
        
        // 错误信息
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          ),
        
        // 按类别分组的模型列表 - 使用 Expanded 确保填满剩余空间并可滚动
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildCategorizedModelList(),
            ),
          ),
        ),
        
        // 操作按钮
        const SizedBox(height: 16),
        _buildActionButtons(),
      ],
    );
  }

  List<Widget> _buildCategorizedModelList() {
    final widgets = <Widget>[];
    
    // 按类别分组
    for (final category in LLMModelCategory.values) {
      // 应用过滤器
      if (widget.filterCategory != null && category != widget.filterCategory) {
        continue;
      }
      
      final modelsInCategory = LLMModelConfig.configs.entries
          .where((e) => e.value.category == category)
          .toList();
      
      if (modelsInCategory.isEmpty) continue;
      
      final isExpanded = _expandedCategories.contains(category);
      
      widgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 类别标题
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedCategories.remove(category);
                  } else {
                    _expandedCategories.add(category);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text(
                      _getCategoryIcon(category),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getCategoryTitle(category),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${modelsInCategory.length}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white38,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            
            // 模型列表
            if (isExpanded)
              ...modelsInCategory.map((e) => _buildModelCard(e.key)),
            
            const SizedBox(height: 8),
          ],
        ),
      );
    }
    
    return widgets;
  }

  String _getCategoryIcon(LLMModelCategory category) {
    switch (category) {
      case LLMModelCategory.textOnly:
        return '💬';
      case LLMModelCategory.multimodal:
        return '📷';
      case LLMModelCategory.embedding:
        return '🔍';
      case LLMModelCategory.reranker:
        return '📊';
    }
  }

  String _getCategoryTitle(LLMModelCategory category) {
    switch (category) {
      case LLMModelCategory.textOnly:
        return '对话模型';
      case LLMModelCategory.multimodal:
        return '多模态模型';
      case LLMModelCategory.embedding:
        return '嵌入模型';
      case LLMModelCategory.reranker:
        return '重排序模型';
    }
  }

  Widget _buildDeviceInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_android, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '内存 ${_deviceInfo!.ramString} | ${_deviceInfo!.levelString}设备',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard(LLMModelType type) {
    final config = LLMModelConfig.getConfig(type);
    final status = _modelStatus?[type] ?? ModelStatus.notDownloaded;
    final isRecommended = type == _deviceInfo?.recommendedModel;
    final isSelected = type == _selectedType;
    final canRun = _deviceInfo != null && 
                   _deviceInfo!.ramMb >= config.minRamMb;

    return GestureDetector(
      onTap: canRun ? () => _selectModelCard(type) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.amber.withOpacity(0.15) 
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // 模型图标
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: canRun 
                    ? _getModelIconColor(config).withOpacity(0.15) 
                    : Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  config.categoryIcon,
                  style: TextStyle(
                    fontSize: 22,
                    color: canRun ? null : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // 模型信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          config.displayName,
                          style: TextStyle(
                            color: canRun ? Colors.white : Colors.white38,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isRecommended) ...const [
                        SizedBox(width: 6),
                        _RecommendedBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getModelSizeDescription(config),
                    style: TextStyle(
                      color: canRun ? Colors.white54 : Colors.white24,
                      fontSize: 12,
                    ),
                  ),
                  if (!canRun)
                    const Text(
                      '设备内存不足',
                      style: TextStyle(color: Colors.redAccent, fontSize: 11),
                    ),
                ],
              ),
            ),
            
            // 状态指示
            _buildStatusIndicator(status, canRun),
          ],
        ),
      ),
    );
  }

  Color _getModelIconColor(LLMModelConfig config) {
    switch (config.category) {
      case LLMModelCategory.textOnly:
        return Colors.amber;
      case LLMModelCategory.multimodal:
        return Colors.purple;
      case LLMModelCategory.embedding:
        return Colors.blue;
      case LLMModelCategory.reranker:
        return Colors.green;
    }
  }

  String _getModelSizeDescription(LLMModelConfig config) {
    if (config.requiresMmproj) {
      // 多模态模型显示总大小
      return '${config.totalSizeString} (含视觉编码器) | 需要 ${config.ramRequirement} 内存';
    } else {
      return '${config.sizeString} | 需要 ${config.ramRequirement} 内存';
    }
  }

  Widget _buildStatusIndicator(ModelStatus status, bool canRun) {
    if (!canRun) {
      return const Icon(Icons.block, color: Colors.grey, size: 20);
    }
    
    switch (status) {
      case ModelStatus.downloaded:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            '已下载',
            style: TextStyle(color: Colors.green, fontSize: 11),
          ),
        );
      case ModelStatus.downloading:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
        );
      case ModelStatus.notDownloaded:
        return const Icon(Icons.download, color: Colors.amber, size: 20);
    }
  }
}

/// 推荐标签组件
class _RecommendedBadge extends StatelessWidget {
  const _RecommendedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        '推荐',
        style: TextStyle(
          color: Colors.green,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// 全局通知工具类
/// 
/// 用于在应用任何位置显示通知，即使当前页面已被 pop
class GlobalNotification {
  static OverlayEntry? _currentEntry;
  static OverlayState? _savedOverlay;
  
  /// 保存 Overlay 引用（在关闭对话框前调用）
  static void saveOverlay(BuildContext context) {
    _savedOverlay = Overlay.of(context);
  }
  
  /// 显示全局通知
  static void show({
    required String message,
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = _savedOverlay;
    if (overlay == null) return;
    
    // 移除现有通知
    _currentEntry?.remove();
    
    _currentEntry = OverlayEntry(
      builder: (context) => _NotificationWidget(
        message: message,
        isError: isError,
        onDismiss: () {
          _currentEntry?.remove();
          _currentEntry = null;
        },
      ),
    );
    
    overlay.insert(_currentEntry!);
    
    // 自动消失
    Future.delayed(duration, () {
      _currentEntry?.remove();
      _currentEntry = null;
    });
  }
}

/// 通知 Widget
class _NotificationWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;
  
  const _NotificationWidget({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });
  
  @override
  State<_NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isError 
                    ? const Color(0xFF2D1F1F) 
                    : const Color(0xFF1F2D1F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isError ? Colors.redAccent : Colors.green,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isError ? Icons.error_outline : Icons.check_circle_outline,
                    color: widget.isError ? Colors.redAccent : Colors.green,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: widget.isError ? Colors.redAccent : Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: Icon(
                      Icons.close,
                      color: widget.isError ? Colors.redAccent : Colors.green,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
