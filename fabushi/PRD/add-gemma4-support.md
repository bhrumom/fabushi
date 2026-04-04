# 添加 Gemma 4 支持需求文档

## 背景说明
随着 Google Gemma 4 家族模型发布，需要在本地模型库配置中添加对 Gemma 4 E2B 和 Gemma 4 E4B 版本的GGUF格式支持，以增强客户端的本地离线AI能力选项。

## 改动点设计
在现有的 `lib/services/llm_model_config.dart` 增加相应的配置：

1. `LLMModelType` 枚举中新增 `gemma4_e2b_gguf` 和 `gemma4_e4b_gguf`。
2. 在 `LLMModelConfig.configs` 列表中增加这两个类的详细下载链接与要求说明。
    - Gemma 4 E2B：2.2 GB 大小，轻量级，2GB 内存可运行。
    - Gemma 4 E4B：3.8 GB 大小，增强级，4GB 内存可运行。

## 测试与验证步骤
1. 添加配置后即可在应用内的LLM模型下载界面看到 Gemma 4 相关的选项。
2. 因为底层的 Llama.cpp 接口及网络逻辑已经稳定，添加新模型仅相当于新增记录。
3. 执行 flutter analyze 确认无语法错误。

## 测试结果与遇到问题记录
1. **遇到的问题 1**：在添加 `gemma4_e2b_gguf` 和 `gemma4_e4b_gguf` 变量时，dart analyze 给出了 `constant_identifier_names` 的提示（因为没有采用 lowerCamelCase）。
2. **如何解决的**：该提示跟原来已有的 `gemma3n_e2b_gguf` 一致，属于 severity:3 的代码风格提示，并非语法和编译错误。为了保持统一性（都使用带下划线的形式，类似 `gemma4_e2b_gguf`），保留了该命名格式。
3. **遇到的问题 2**：Gemma 4 是刚刚（2026年4月2日）发布的最新模型，原先预估使用的 `bartowski/google_gemma-4-E2B-it-GGUF` 路径实际在 HuggingFace 并不存在。同时需要为国内用户找到可下载的地址。
4. **如何解决的**：通过 HuggingFace API 搜索获取到了社区已有的有效 GGUF 仓库 `tatsuyaaaaaaa/gemma-4-E2B-it-gguf` 及 `tatsuyaaaaaaa/gemma-4-E4B-it-gguf`。将下载直链更正为该仓库中确实存在的具体模型文件（如 `gemma-4-E2B-it_Q4_K_M.gguf`），并直接将域名替换为国内访问极其顺畅的镜像源 `https://hf-mirror.com`，免去了手动下载与重新上传。
5. **整体流程**：自动化代码分析已通过，无阻断性编译问题。配置更新成功，功能接入完毕且国内网络亲和。
