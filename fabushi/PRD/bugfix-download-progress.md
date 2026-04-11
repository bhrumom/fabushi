# 修复下载进度超限问题 (Bugfix)

## 问题描述
用户反馈在下载AI模型（如 Gemma 4）时，设置页面的下载进度条显示与实际不符，出现超过 100% 的进度值（如截图中的 113.1%）。

## 根本原因
在 `LLMModelManager` 和后台的 `DownloadManager` 进度计算中：
1. 模型大小最初基于 `LLMModelConfig` 中静态配置的预期大小 `totalSizeBytes` 进行计算。
2. 实际下载过程中，如果有远端文件实际体积大于 `expectedSizeBytes`，随着 `downloadedBytes` 增加，计算出的 `progress = downloadedBytes / totalSizeBytes` 将会大于 `1.0`。
3. 前端界面没有对进度进行上限截断控制，导致大于 100% 的异常进度。

## 解决步骤
1. **更新 `llm_model_manager.dart`**:
   - 当正在下载模型且能获取到 HTTP Response Header 中实际 `total` 大小的时候，如果在单文件模式下，使用真实能够获取的 `total` 来替代配置文件中的预设大小进行进度计算。
   - 对所有的进度计算结果 `progress` 提供兜底限制 `if (progress > 1.0) progress = 1.0;` 防止数值溢出 100%。

2. **更新 `download_manager.dart`**:
   - 分别在本地（断点续传）和 Web 环境两套下载实现下，增加相同的截断逻辑。
   - 对计算出来的 `task.progress` 添加强校验：`if (task.progress > 1.0) task.progress = 1.0;`。

## 测试与验证
1. 通过 `flutter hot restart` 重新加载应用即可生效。
2. 尝试再次下载超出预期大小的资源时，界面显示稳定封顶 100% 直至下载真正完成。

## 结论
问题现已彻底修复。系统的所有有关进度的回传值保证 `[0.0, 1.0]`，从而阻止类似 `113.1%` 的错误现象复现。
