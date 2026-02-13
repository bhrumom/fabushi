import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/llm_inference_service.dart';
import '../services/llm_model_manager.dart';
import '../services/llm_model_config.dart';
import '../services/app_settings.dart';

/// AI问经页面
/// 
/// 用于对话式经文问答，支持本地AI模型推理
class SutraAIPage extends StatefulWidget {
  const SutraAIPage({
    required this.bookTitle,
    required this.fullText,
    super.key,
  });

  final String bookTitle;
  final String fullText;

  @override
  State<SutraAIPage> createState() => _SutraAIPageState();
}

class _SutraAIPageState extends State<SutraAIPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isGenerating = false;
  bool _isModelReady = false;
  String _currentResponse = '';
  StreamSubscription<String>? _streamSubscription;
  
  // 模型选择相关
  List<LLMModelType> _availableModels = [];
  LLMModelType? _selectedModel;
  
  // 预设问题
  final List<String> _presetQuestions = [
    '青少年案例对理解\'自由\'有何启示？',
    '阿德勒如何用\'被讨厌\'定义自由？',
    '为何说\'自由=被讨厌\'是自我觉醒的起点？',
  ];
  
  // 快捷按钮
  final List<_QuickAction> _quickActions = [
    _QuickAction('全书总结', Icons.summarize),
    _QuickAction('书籍亮点', Icons.auto_awesome),
    _QuickAction('背景解读', Icons.history_edu),
  ];

  @override
  void initState() {
    super.initState();
    _loadAvailableModels();
  }
  
  /// 加载可用的对话模型
  Future<void> _loadAvailableModels() async {
    final downloadedModels = await LLMModelManager.instance.getDownloadedModels();
    
    // 根据平台筛选可用模型
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final platformModels = LLMModelConfig.getChatModelsForPlatform(isMobile: isMobile);
    final platformModelTypes = platformModels.map((c) => c.type).toSet();
    
    // 只保留已下载且当前平台支持的模型
    final chatModels = downloadedModels.where((type) {
      return platformModelTypes.contains(type);
    }).toList();
    
    // 加载上次选择的模型
    LLMModelType? savedModel;
    final savedModelName = await AppSettings.getSelectedModelName();
    if (savedModelName != null) {
      try {
        savedModel = LLMModelType.values.firstWhere((t) => t.name == savedModelName);
        // 确保保存的模型在可用列表中
        if (!chatModels.contains(savedModel)) {
          savedModel = null;
        }
      } catch (_) {}
    }
    
    if (mounted) {
      setState(() {
        _availableModels = chatModels;
        _selectedModel = savedModel ?? (chatModels.isNotEmpty ? chatModels.first : null);
        _isModelReady = _selectedModel != null;
      });
    }
  }
  
  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }
  
  /// 切换模型
  Future<void> _switchModel(LLMModelType type) async {
    if (type == _selectedModel) return;
    
    // 保存选择
    await AppSettings.setSelectedModelName(type.name);
    
    // 如果推理服务已初始化，需要重新初始化
    final inferenceService = LLMInferenceService.instance;
    if (inferenceService.isInitialized) {
      await inferenceService.dispose();
    }
    
    if (mounted) {
      setState(() {
        _selectedModel = type;
      });
    }
  }
  
  /// 发送消息
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isGenerating) return;
    
    HapticFeedback.lightImpact();
    
    // 添加用户消息
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isGenerating = true;
      _currentResponse = '';
    });
    
    _inputController.clear();
    _scrollToBottom();
    
    // 构建提示词
    final prompt = _buildPrompt(text);
    
    try {
      if (_selectedModel == null) {
        throw Exception('请先选择一个AI模型');
      }
      
      final inferenceService = LLMInferenceService.instance;
      
      if (!inferenceService.isInitialized) {
        // 初始化模型
        final modelManager = LLMModelManager.instance;
        final modelPath = await modelManager.getModelPath(_selectedModel!);
        await inferenceService.initialize(modelPath);
      }
      
      // 流式生成回答
      final stream = inferenceService.generateStream(prompt);
      
      _streamSubscription = stream.listen(
        (token) {
          if (mounted) {
            setState(() {
              _currentResponse += token;
            });
            _scrollToBottom();
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _messages.add(_ChatMessage(text: _currentResponse, isUser: false));
              _currentResponse = '';
              _isGenerating = false;
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _messages.add(_ChatMessage(
                text: '生成失败: $error', 
                isUser: false,
                isError: true,
              ));
              _currentResponse = '';
              _isGenerating = false;
            });
          }
        },
      );
    } catch (e, stackTrace) {
      // 打印详细错误到日志
      debugPrint('SutraAIPage: AI模型连接失败');
      debugPrint('  错误类型: ${e.runtimeType}');
      debugPrint('  错误信息: $e');
      debugPrint('  堆栈: $stackTrace');
      
      // 提取更友好的错误消息
      String errorMessage = '$e';
      if (errorMessage.contains('Could not load model')) {
        errorMessage = '模型加载失败，请检查：\n'
            '1. 设备内存是否充足（需要2GB+）\n'
            '2. 模型文件是否完整下载\n'
            '3. 详情请查看日志';
      } else if (errorMessage.contains('FileSystemException')) {
        errorMessage = '模型文件不存在，请重新下载';
      }
      
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            text: '无法连接AI模型:\n$errorMessage', 
            isUser: false,
            isError: true,
          ));
          _isGenerating = false;
        });
      }
    }
  }
  
  /// 构建提示词
  String _buildPrompt(String question) {
    // 截取经文摘要（避免上下文过长）
    final textSummary = widget.fullText.length > 2000 
        ? widget.fullText.substring(0, 2000) + '...'
        : widget.fullText;
    
    return '''你是一位佛学大师和智慧导师，精通佛教经典。
用户正在阅读《${widget.bookTitle}》，以下是经文内容摘要：

$textSummary

请根据经文内容回答用户的问题。回答要简洁明了，深入浅出，引导思考。

用户问题：$question

请用中文回答：''';
  }
  
  /// 滚动到底部
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  /// 处理快捷操作
  void _handleQuickAction(String action) {
    switch (action) {
      case '全书总结':
        _sendMessage('请帮我总结这本书的核心要点和主旨');
        break;
      case '书籍亮点':
        _sendMessage('这本书有哪些让人印象深刻的亮点或观点？');
        break;
      case '背景解读':
        _sendMessage('请介绍一下这本书的创作背景和作者背景');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildChatArea()),
            _buildPresetQuestions(),
            _buildQuickActions(),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    final currentConfig = _selectedModel != null 
        ? LLMModelConfig.getConfig(_selectedModel!)
        : null;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white70,
              size: 28,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Ai 问书',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '《${widget.bookTitle}》',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // 模型选择按钮
          if (_availableModels.isNotEmpty)
            PopupMenuButton<LLMModelType>(
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentConfig?.categoryIcon ?? '🤖',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.expand_more,
                    color: Colors.white54,
                    size: 18,
                  ),
                ],
              ),
              color: const Color(0xFF2A2A3E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tooltip: '选择AI模型',
              onSelected: _switchModel,
              itemBuilder: (context) => _availableModels.map((type) {
                final config = LLMModelConfig.getConfig(type);
                final isSelected = type == _selectedModel;
                return PopupMenuItem<LLMModelType>(
                  value: type,
                  child: Row(
                    children: [
                      Text(config.categoryIcon, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          config.displayName,
                          style: TextStyle(
                            color: isSelected ? Colors.amber : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check, color: Colors.amber, size: 18),
                    ],
                  ),
                );
              }).toList(),
            )
          else
            // 无可用模型时显示提示
            GestureDetector(
              onTap: () => _showNoModelHint(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '无模型',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// 显示无模型提示
  void _showNoModelHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('请先在设置中下载AI模型'),
        backgroundColor: Color(0xFF2A2A3E),
      ),
    );
  }
  
  /// 构建对话区域
  Widget _buildChatArea() {
    if (_messages.isEmpty && _currentResponse.isEmpty) {
      return _buildEmptyState();
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_currentResponse.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < _messages.length) {
          return _buildMessageBubble(_messages[index]);
        } else {
          // 正在生成的消息
          return _buildMessageBubble(
            _ChatMessage(text: _currentResponse, isUser: false),
            isStreaming: true,
          );
        }
      },
    );
  }
  
  /// 空状态
  Widget _buildEmptyState() {
    final currentModelName = _selectedModel != null 
        ? LLMModelConfig.getConfig(_selectedModel!).displayName
        : null;
    
    String hintText;
    if (_availableModels.isEmpty) {
      hintText = '请先在设置中下载AI模型';
    } else if (_isModelReady) {
      hintText = '使用 $currentModelName\n向AI询问关于《${widget.bookTitle}》的问题';
    } else {
      hintText = '正在准备AI模型...';
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _availableModels.isEmpty ? Icons.download : Icons.auto_awesome,
            color: _availableModels.isEmpty 
                ? Colors.orange.withValues(alpha: 0.5)
                : Colors.amber.withValues(alpha: 0.5),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            hintText,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  /// 构建消息气泡
  Widget _buildMessageBubble(_ChatMessage message, {bool isStreaming = false}) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 12,
        left: message.isUser ? 48 : 0,
        right: message.isUser ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment: message.isUser 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B68EE), Color(0xFF9370DB)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Ai',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: message.isUser 
                    ? const Color(0xFF2D5A27)
                    : message.isError 
                        ? Colors.red.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isError ? Colors.red[300] : Colors.white,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  if (isStreaming) ...[
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.amber.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建预设问题
  Widget _buildPresetQuestions() {
    if (_messages.isNotEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _presetQuestions.map((question) => 
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => _sendMessage(question),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  question,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ).toList(),
      ),
    );
  }
  
  /// 构建快捷操作按钮
  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: _quickActions.map((action) => 
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _handleQuickAction(action.label),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  action.label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ).toList(),
      ),
    );
  }
  
  /// 构建输入区域
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _inputController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: '针对本书提出你的问题',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: _sendMessage,
                enabled: !_isGenerating,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isGenerating 
                ? null 
                : () => _sendMessage(_inputController.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isGenerating 
                    ? Colors.grey 
                    : const Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isGenerating ? Icons.hourglass_empty : Icons.arrow_upward,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 聊天消息数据类
class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
}

/// 快捷操作数据类
class _QuickAction {
  final String label;
  final IconData icon;
  
  const _QuickAction(this.label, this.icon);
}
