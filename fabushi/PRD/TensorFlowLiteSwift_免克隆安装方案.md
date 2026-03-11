# TensorFlowLiteSwift 免克隆安装方案

## 背景与问题描述
当前环境在执行 `pod install` 安装 `flutter_gemma` 的原生依赖时遇到网络连接中断（Error 56: Connection reset by peer）并报 `early EOF`。
分析发现其中 `TensorFlowLiteSwift` 版本为 `0.0.1-nightly.20250619`。该 nightly 版本在 CocoaPods 官方配置的源 (source) 为 **Git 克隆整个 TensorFlow 仓库**。
```json
"source": {
  "git": "https://github.com/tensorflow/tensorflow.git",
  "commit": "d969db94661693f84d7be32a5525045873f429df"
}
```
TensorFlow 整个 Git 历史仓库非常庞大（通常 > 2GB），在国内或 VPN 环境下，极易长时间无响应甚至中断失败。

## 更优的解决方案（免克隆方案）
我们可以绕过 Git Clone，通过修改本地 CocoaPods 的 Spec 镜像文件，将其强制改为从 GitHub 下载此特定 commit 的 **ZIP 源码压缩包**，大小骤降至 ~200MB，且下载稳定性大幅度好于 Git Checkout。

### 执行步骤记录
1. 定位到了本地的 Spec 文件：
   `~/.cocoapods/repos/trunk/Specs/d/9/6/TensorFlowLiteSwift/0.0.1-nightly.20250619/TensorFlowLiteSwift.podspec.json`
2. 已将该 json 的 Source 替换为：
   ```json
   "source": {
     "http": "https://github.com/tensorflow/tensorflow/archive/d969db94661693f84d7be32a5525045873f429df.zip"
   }
   ```

## 后续用户使用指南
目前我已经通过脚本修改了该本地 `podspec.json` 文件。
用户只需要：
1. 取消或是杀掉当前所有卡住的 `pod spec cat` 或 `pod install` 进程。
2. 进入 `ios` 目录。
3. 执行纯净的 `pod install`（**切记：请勿添加 `--repo-update`，否则会导致修改被远端覆盖重置**）。
4. 等待其输出 `Installing TensorFlowLiteSwift ...` 并完成下载压缩包并进入下一个环节即可。
