# MediaPipe LLM Inference API 切换方案

## 1. 背景与目标

### 当前实现
- **库**：`llama_cpp_dart`（llama.cpp 的 Dart 绑定）
- **模型格式**：GGUF
- **支持模型**：Qwen2.5 系列、DeepSeek R1、Qwen3-VL 多模态
- **支持平台**：Android、iOS、macOS

### 目标实现
- **库**：`flutter_mediapipe_chat`（Google MediaPipe 框架）
- **模型格式**：.bin / .tflite
- **支持模型**：Gemma 系列
- **支持平台**：Android (API 24+)、iOS (13.0+)

---

## 2. 技术方案对比

| 特性 | llama_cpp_dart | flutter_mediapipe_chat |
|-----|---------------|----------------------|
| 维护方 | 社区 | 基于 Google MediaPipe |
| 模型格式 | GGUF | .bin (TFLite) |
| 支持模型 | Qwen, DeepSeek, LLaMA 等 | Gemma 系列 |
| CPU/GPU 支持 | 有限 GPU | 完整 CPU/GPU |
| Android 支持 | ✅ | ✅ (API 24+) |
| iOS 支持 | ✅ | ✅ (13.0+) |
| macOS 支持 | ✅ | ❌ |
| 多模态 | ✅ (Qwen3-VL) | ❌ |
| LoRA 微调 | ❌ | ✅ |

---

## 3. 关键变更

### 3.1 依赖变更

```yaml
# 移除
llama_cpp_dart:
  git:
    url: https://github.com/netdur/llama_cpp_dart.git
    ref: main

# 新增
flutter_mediapipe_chat: ^1.0.0
```

### 3.2 模型变更

| 旧模型 | 新模型 | 变化 |
|-------|--------|-----|
| Qwen 0.5B (~386MB) | Gemma 2B GPU int4 (~1.3GB) | 模型更大但性能更好 |
| Qwen 1.5B (~986MB) | Gemma-2 2B GPU int8 (~2.5GB) | 推荐使用 |
| DeepSeek R1 (~1.1GB) | - | 无替代 |
| Qwen3-VL 多模态 | - | 无替代 |

### 3.3 推理服务重构

```dart
// 旧代码
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
final parent = LlamaParent(loadCommand);
await parent.init();
parent.sendPrompt(prompt);

// 新代码
import 'package:flutter_mediapipe_chat/flutter_mediapipe_chat.dart';
final plugin = FlutterMediapipeChat();
await plugin.loadModel(config);
plugin.generateResponseAsync(prompt);
```

---

## 4. 影响评估

### 正面影响
- ✅ Google 官方维护，更稳定
- ✅ 更好的 GPU 加速支持
- ✅ 支持 LoRA 微调
- ✅ 更简洁的 API

### 负面影响
- ❌ 失去 Qwen 模型支持
- ❌ 失去多模态能力
- ❌ 失去 macOS 支持
- ❌ 模型文件更大
- ❌ 需要重新下载模型

---

## 5. 用户确认事项

1. **是否接受切换到 Gemma 模型？**
   - Gemma 2B 是 Google 的开源模型，中文能力有限

2. **是否接受 macOS 不支持？**
   - 如需保留 macOS，需要做平台条件编译

3. **是否接受多模态功能失去？**
   - MediaPipe 目前不支持 VL 模型

---

## 6. 实施步骤

1. 替换依赖包
2. 更新 Android/iOS 平台配置
3. 重写模型配置
4. 重写推理服务
5. 更新 UI 调用
6. 真机测试验证
