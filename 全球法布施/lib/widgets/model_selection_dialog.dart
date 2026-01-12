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
      barrierDismissible: !isFirstLaunch, // 首次启动不允许点击外部关闭
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

    try {
      await LLMModelManager.instance.downloadModel(
        type,
        onProgress: (progress, stage) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
              _downloadStage = stage;
            });
          }
        },
      );
      
      // 下载完成，选择模型
      await _selectModel(type);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '下载失败: $e';
          _isDownloading = false;
        });
      }
    }
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
        TextButton(
          onPressed: _cancelDownload,
          child: const Text('取消下载', style: TextStyle(color: Colors.redAccent)),
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
        
        // 跳过按钮（仅非首次启动时显示）
        if (!widget.isFirstLaunch) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消', style: TextStyle(color: Colors.white54)),
            ),
          ),
        ],
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
      onTap: canRun ? () => _downloadAndSelect(type) : null,
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
