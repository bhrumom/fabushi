/// LLM 模型配置
/// 
/// 定义支持的 LLM 模型及其配置信息。
/// 包括模型下载地址、大小、RAM 要求，以及多模态模型的 mmproj 配置。

/// 模型类别枚举
enum LLMModelCategory {
  /// 纯文本对话模型（Qwen2.5 系列、DeepSeek、Gemma 等）
  textOnly,
  
  /// 多模态视觉语言模型（Qwen3-VL 系列）
  /// 需要额外的 mmproj 视觉编码器文件
  multimodal,
  
  /// 文本嵌入模型（Qwen3-Embedding）
  /// 用于语义检索和向量化
  embedding,
  
  /// 文本重排序模型（Qwen3-Reranker）
  /// 用于优化检索结果排序
  reranker,
}

/// 模型支持的平台
enum LLMModelPlatform {
  /// 所有平台
  all,
  
  /// 仅 macOS（使用 llama_cpp_dart）
  macOSOnly,
  
  /// 仅 Android/iOS（使用 MediaPipe）
  mobileOnly,
}

/// HuggingFace 下载源
enum HFDownloadSource {
  /// 官方源 (huggingface.co) - 国外用户
  official,
  
  /// 镜像源 (hf-mirror.com) - 国内用户
  mirror,
}

/// 下载源配置
class HFSourceConfig {
  static const String officialDomain = 'huggingface.co';
  static const String mirrorDomain = 'hf-mirror.com';
  
  /// 根据源获取完整 URL
  static String getFullUrl(String relativePath, HFDownloadSource source) {
    final domain = source == HFDownloadSource.official 
        ? officialDomain 
        : mirrorDomain;
    return 'https://$domain$relativePath';
  }
  
  /// 从完整 URL 提取相对路径
  static String extractRelativePath(String fullUrl) {
    // https://huggingface.co/xxx/xxx -> /xxx/xxx
    final uri = Uri.parse(fullUrl);
    return uri.path;
  }
}

/// 模型类型枚举
enum LLMModelType {
  // ========== macOS 专用模型（llama_cpp_dart / GGUF）==========
  
  /// Qwen2.5-0.5B-Instruct - 入门级，适合低端设备
  qwen05b,
  
  /// Qwen2.5-1.5B-Instruct - 标准版，适合普通设备
  qwen15b,
  
  /// DeepSeek-R1-Distill-Qwen-1.5B - DeepSeek 蒸馏版，推理能力强
  deepseekR1,
  
  /// Qwen2.5-3B-Instruct - 高端版，适合高配设备
  qwen3b,
  
  /// Qwen3-VL-2B-Instruct - 多模态视觉语言模型（轻量版）
  qwen3VL2b,
  
  /// Qwen3-VL-8B-Instruct - 多模态视觉语言模型（高端版）
  qwen3VL8b,
  
  /// Qwen3-Embedding-0.6B - 文本嵌入模型，用于语义检索
  qwen3Embedding06b,
  
  /// Qwen3-Reranker-0.6B - 文本重排序模型，用于检索结果优化
  qwen3Reranker06b,
  
  // ========== Android/iOS 专用模型（flutter_gemma / Gemma 3n）==========
  
  /// Gemma 3n E2B - 专为移动端优化，2GB RAM 即可运行
  gemma3n_e2b,
  
  // ========== macOS 也可用的 Gemma 3n GGUF ==========
  
  /// Gemma 3n E2B GGUF Q4_K_M - macOS llama.cpp
  gemma3n_e2b_gguf,
}

/// 设备能力等级
enum DeviceLevel {
  /// 低端设备：RAM < 3GB
  low,
  
  /// 普通设备：RAM 3-6GB
  medium,
  
  /// 高端设备：RAM > 6GB
  high,
}

/// LLM 模型配置类
class LLMModelConfig {
  /// 模型类型
  final LLMModelType type;
  
  /// 模型类别
  final LLMModelCategory category;
  
  /// 显示名称
  final String displayName;
  
  /// 模型文件名
  final String fileName;
  
  /// 下载地址
  final String downloadUrl;
  
  /// 预期文件大小（字节）
  final int expectedSizeBytes;
  
  /// 最低 RAM 要求（MB）
  final int minRamMb;
  
  /// 模型描述
  final String description;
  
  /// 版本号
  final String version;
  
  // ========== 多模态模型专用字段 ==========
  
  /// 视觉编码器文件名（仅多模态模型需要）
  final String? mmprojFileName;
  
  /// 视觉编码器下载地址
  final String? mmprojDownloadUrl;
  
  /// 视觉编码器文件大小（字节）
  final int? mmprojSizeBytes;
  
  /// 支持的平台
  final LLMModelPlatform platform;

  const LLMModelConfig({
    required this.type,
    required this.category,
    required this.displayName,
    required this.fileName,
    required this.downloadUrl,
    required this.expectedSizeBytes,
    required this.minRamMb,
    required this.description,
    this.version = '1.0.0',
    this.mmprojFileName,
    this.mmprojDownloadUrl,
    this.mmprojSizeBytes,
    this.platform = LLMModelPlatform.all,
  });

  /// 是否为多模态模型
  bool get isMultimodal => category == LLMModelCategory.multimodal;
  
  /// 是否为嵌入模型
  bool get isEmbedding => category == LLMModelCategory.embedding;
  
  /// 是否为重排序模型
  bool get isReranker => category == LLMModelCategory.reranker;
  
  /// 是否需要 mmproj 文件
  bool get requiresMmproj => mmprojFileName != null;

  /// 获取主模型文件大小的可读字符串
  String get sizeString {
    if (expectedSizeBytes >= 1024 * 1024 * 1024) {
      return '${(expectedSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } else {
      return '${(expectedSizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
  }
  
  /// 获取总下载大小（主模型 + mmproj）的可读字符串
  String get totalSizeString {
    final total = totalSizeBytes;
    if (total >= 1024 * 1024 * 1024) {
      return '${(total / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } else {
      return '${(total / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
  }
  
  /// 获取总下载大小（字节）
  int get totalSizeBytes => expectedSizeBytes + (mmprojSizeBytes ?? 0);

  /// 获取 RAM 要求的可读字符串
  String get ramRequirement => '${minRamMb >= 1024 ? '${(minRamMb / 1024).toStringAsFixed(1)} GB' : '$minRamMb MB'}+';
  
  /// 获取模型类别的显示名称
  String get categoryLabel {
    switch (category) {
      case LLMModelCategory.textOnly:
        return '对话模型';
      case LLMModelCategory.multimodal:
        return '多模态';
      case LLMModelCategory.embedding:
        return '嵌入模型';
      case LLMModelCategory.reranker:
        return '重排序';
    }
  }
  
  /// 获取模型类别图标
  String get categoryIcon {
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

  /// 预定义模型配置
  static const Map<LLMModelType, LLMModelConfig> configs = {
    // ========== 纯文本对话模型 ==========
    LLMModelType.qwen05b: LLMModelConfig(
      type: LLMModelType.qwen05b,
      category: LLMModelCategory.textOnly,
      displayName: 'Qwen 0.5B (轻量版)',
      fileName: 'Qwen2.5-0.5B-Instruct-Q4_K_M.gguf',
      downloadUrl: 'https://huggingface.co/bartowski/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf',
      expectedSizeBytes: 386 * 1024 * 1024, // ~386 MB
      minRamMb: 1024, // 1 GB
      description: '入门级模型，适合低端设备，响应快速',
      platform: LLMModelPlatform.macOSOnly,
    ),
    
    LLMModelType.qwen15b: LLMModelConfig(
      type: LLMModelType.qwen15b,
      category: LLMModelCategory.textOnly,
      displayName: 'Qwen 1.5B (标准版)',
      fileName: 'Qwen2.5-1.5B-Instruct-Q4_K_M.gguf',
      downloadUrl: 'https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf',
      expectedSizeBytes: 986 * 1024 * 1024, // ~986 MB
      minRamMb: 2048, // 2 GB
      description: '通用能力强，语义理解准确',
      platform: LLMModelPlatform.macOSOnly,
    ),
    
    LLMModelType.deepseekR1: LLMModelConfig(
      type: LLMModelType.deepseekR1,
      category: LLMModelCategory.textOnly,
      displayName: 'DeepSeek R1 (推理增强)',
      fileName: 'DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf',
      downloadUrl: 'https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf',
      expectedSizeBytes: 1100 * 1024 * 1024, // ~1.1 GB
      minRamMb: 2048, // 2 GB
      description: 'DeepSeek官方蒸馏版，推理能力强',
      platform: LLMModelPlatform.macOSOnly,
    ),
    
    LLMModelType.qwen3b: LLMModelConfig(
      type: LLMModelType.qwen3b,
      category: LLMModelCategory.textOnly,
      displayName: 'Qwen 3B (高端版)',
      fileName: 'Qwen2.5-3B-Instruct-Q4_K_M.gguf',
      downloadUrl: 'https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf',
      expectedSizeBytes: 1900 * 1024 * 1024, // ~1.9 GB
      minRamMb: 4096, // 4 GB
      description: '能力最强，适合高端设备',
      platform: LLMModelPlatform.macOSOnly,
    ),
    
    // ========== 多模态视觉语言模型 ==========
    LLMModelType.qwen3VL2b: LLMModelConfig(
      type: LLMModelType.qwen3VL2b,
      category: LLMModelCategory.multimodal,
      displayName: 'Qwen3-VL 2B (多模态)',
      fileName: 'Qwen3-VL-2B-Instruct-Q4_K_M.gguf',
      downloadUrl: 'https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF/resolve/main/Qwen3-VL-2B-Instruct-Q4_K_M.gguf',
      expectedSizeBytes: 1100 * 1024 * 1024, // ~1.1 GB
      minRamMb: 2048, // 2 GB
      description: '多模态视觉语言模型，支持图像理解',
      // 视觉编码器配置
      mmprojFileName: 'Qwen3-VL-2B-Instruct-mmproj-f16.gguf',
      mmprojDownloadUrl: 'https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF/resolve/main/Qwen3-VL-2B-Instruct-mmproj-f16.gguf',
      mmprojSizeBytes: 1500 * 1024 * 1024, // ~1.5 GB
    ),
    
    LLMModelType.qwen3VL8b: LLMModelConfig(
      type: LLMModelType.qwen3VL8b,
      category: LLMModelCategory.multimodal,
      displayName: 'Qwen3-VL 8B (多模态高端)',
      fileName: 'Qwen3-VL-8B-Instruct-Q4_K_M.gguf',
      downloadUrl: 'https://huggingface.co/bartowski/Qwen3-VL-8B-Instruct-GGUF/resolve/main/Qwen3-VL-8B-Instruct-Q4_K_M.gguf',
      expectedSizeBytes: 5030 * 1024 * 1024, // ~5 GB
      minRamMb: 8192, // 8 GB
      description: '多模态旗舰版，视觉理解能力最强',
      // 视觉编码器配置
      mmprojFileName: 'Qwen3-VL-8B-Instruct-mmproj-f16.gguf',
      mmprojDownloadUrl: 'https://huggingface.co/bartowski/Qwen3-VL-8B-Instruct-GGUF/resolve/main/Qwen3-VL-8B-Instruct-mmproj-f16.gguf',
      mmprojSizeBytes: 1500 * 1024 * 1024, // ~1.5 GB
    ),
    
    // ========== 嵌入模型 ==========
    LLMModelType.qwen3Embedding06b: LLMModelConfig(
      type: LLMModelType.qwen3Embedding06b,
      category: LLMModelCategory.embedding,
      displayName: 'Qwen3 Embedding 0.6B',
      fileName: 'Qwen3-Embedding-0.6B-f16.gguf',
      downloadUrl: 'https://huggingface.co/Qwen/Qwen3-Embedding-0.6B-GGUF/resolve/main/Qwen3-Embedding-0.6B-f16.gguf',
      expectedSizeBytes: 1200 * 1024 * 1024, // ~1.2 GB
      minRamMb: 1536, // 1.5 GB
      description: '文本嵌入模型，用于语义搜索和检索',
    ),
    
    // ========== 重排序模型 ==========
    LLMModelType.qwen3Reranker06b: LLMModelConfig(
      type: LLMModelType.qwen3Reranker06b,
      category: LLMModelCategory.reranker,
      displayName: 'Qwen3 Reranker 0.6B',
      fileName: 'Qwen3-Reranker-0.6B-Q8_0.gguf',
      downloadUrl: 'https://huggingface.co/ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF/resolve/main/qwen3-reranker-0.6b-q8_0.gguf',
      expectedSizeBytes: 650 * 1024 * 1024, // ~650 MB
      minRamMb: 1024, // 1 GB
      description: '重排序模型，优化检索结果排序',
      platform: LLMModelPlatform.macOSOnly,
    ),
    
    // ========== Android/iOS 专用 Gemma 3n 模型 ==========
    LLMModelType.gemma3n_e2b: LLMModelConfig(
      type: LLMModelType.gemma3n_e2b,
      category: LLMModelCategory.textOnly,
      displayName: 'Gemma 3n E2B',
      fileName: 'gemma-3n-E2B-it-int4.litertlm',
      // 公开仓库，hf-mirror.com 可直接下载，无需 Token
      downloadUrl: 'https://huggingface.co/bhrum108/gemma-3n-E2B-it-litertlm/resolve/main/gemma-3n-E2B-it-int4.litertlm',
      expectedSizeBytes: 3660 * 1024 * 1024, // ~3.66 GB
      minRamMb: 2048, // 2 GB（Gemma 3n 专为低内存设备优化）
      description: 'Google 最新 Gemma 3n 模型，专为手机优化',
      platform: LLMModelPlatform.mobileOnly,
    ),
    
    // ========== macOS 可用的 Gemma 3n GGUF 模型 ==========
    LLMModelType.gemma3n_e2b_gguf: LLMModelConfig(
      type: LLMModelType.gemma3n_e2b_gguf,
      category: LLMModelCategory.textOnly,
      displayName: 'Gemma 3n E2B (GGUF)',
      fileName: 'gemma-3n-E2B-it-Q4_K_M.gguf',
      // bartowski 社区仓库，非 Gated，hf-mirror 可直接下载
      downloadUrl: 'https://huggingface.co/bartowski/google_gemma-3n-E2B-it-GGUF/resolve/main/google_gemma-3n-E2B-it-Q4_K_M.gguf',
      expectedSizeBytes: 2100 * 1024 * 1024, // ~2.1 GB
      minRamMb: 2048, // 2 GB
      description: 'Gemma 3n 轻量对话模型 (macOS)',
      platform: LLMModelPlatform.macOSOnly,
    ),
  };

  /// 获取指定类型的配置
  static LLMModelConfig getConfig(LLMModelType type) {
    return configs[type]!;
  }

  /// 获取所有配置列表
  static List<LLMModelConfig> get allConfigs => configs.values.toList();
  
  /// 按类别获取模型列表
  static List<LLMModelConfig> getConfigsByCategory(LLMModelCategory category) {
    return configs.values.where((c) => c.category == category).toList();
  }
  
  /// 获取所有对话模型（文本+多模态）
  static List<LLMModelConfig> get chatModels => configs.values
      .where((c) => c.category == LLMModelCategory.textOnly || 
                    c.category == LLMModelCategory.multimodal)
      .toList();
  
  /// 获取所有多模态模型
  static List<LLMModelConfig> get multimodalModels => 
      getConfigsByCategory(LLMModelCategory.multimodal);

  /// 根据设备等级推荐模型
  static LLMModelType recommendForDeviceLevel(DeviceLevel level) {
    switch (level) {
      case DeviceLevel.low:
        return LLMModelType.qwen05b;
      case DeviceLevel.medium:
        return LLMModelType.qwen15b;
      case DeviceLevel.high:
        return LLMModelType.deepseekR1;
    }
  }
  
  /// 检查设备是否满足模型要求
  static bool canRunModel(LLMModelType type, int deviceRamMb) {
    final config = getConfig(type);
    return deviceRamMb >= config.minRamMb;
  }
  
  /// 根据平台筛选可用模型
  /// 
  /// [isMobile] 是否为移动端（Android/iOS）
  static List<LLMModelConfig> getConfigsForPlatform({required bool isMobile}) {
    return configs.values.where((c) {
      if (isMobile) {
        return c.platform == LLMModelPlatform.mobileOnly || 
               c.platform == LLMModelPlatform.all;
      } else {
        return c.platform == LLMModelPlatform.macOSOnly || 
               c.platform == LLMModelPlatform.all;
      }
    }).toList();
  }
  
  /// 获取当前平台可用的对话模型
  static List<LLMModelConfig> getChatModelsForPlatform({required bool isMobile}) {
    return getConfigsForPlatform(isMobile: isMobile)
        .where((c) => c.category == LLMModelCategory.textOnly || 
                      c.category == LLMModelCategory.multimodal)
        .toList();
  }
}
