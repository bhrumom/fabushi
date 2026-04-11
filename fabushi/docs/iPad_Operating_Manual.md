# iPad 真机调试操作手册

为了让您的 iPad 能够成功连接电脑并运行正在开发的“全球法布施”应用，请按照以下步骤进行操作：

## 1. iPad 端的设置 (iPad Side)

### 第一步：物理连接
- 使用 USB-C 或 Lightning 线缆将 iPad 连接到 Mac。
- 如果 iPad 弹出 **“要信任此电脑吗？”** 的提示，请点击 **“信任”** 并输入 iPad 的解锁密码。

### 第二步：开启“开发者模式” (iOS 16 及以上)
1. 打开 iPad 上的 **设置 (Settings)**。
2. 进入 **隐私与安全性 (Privacy & Security)**。
3. 滑动到底部，找到 **开发者模式 (Developer Mode)**。
4. 将开关打开。iPad 此时会提示需要**重启**，请点击重启。
5. 重启进入系统后，iPad 会再次弹出确认窗口，请确认“打开”开发者模式。

---

## 2. Mac 端的设置 (Mac Side)

### 第三步：验证设备连接
在 Mac 终端运行以下命令，确认 iPad 已被识别：
```bash
flutter devices
```
您应该能在列表中看到您的 iPad 名称及其设备 ID。

### 第四步：Xcode 签名验证
1. 打开项目中的 iOS 工程：`open ios/Runner.xcworkspace`。
2. 在左侧文件树点击顶部的 **Runner** 蓝色图标。
3. 选择 **TARGETS -> Runner**。
4. 进入 **Signing & Capabilities** 选项卡。
5. 确保 **Development Team** 已经选择（目前项目已配置 Team ID: `M4Q99K4UR4`）。
6. 如果看到红色的签名错误，请确保您的 Apple ID 已加入对应的开发者团队。

---

## 3. 运行应用

### 第五步：启动运行
您可以通过以下任一方式运行：
- **VS Code**: 在底部状态栏选择您的 iPad 设备，然后按 F5。
- **命令行**: 
  ```bash
  flutter run -d [您的iPad设备ID]
  ```

### 第六步：信任 App (首次运行)
首次安装应用后，iPad 可能会提示“不受信任的开发者”。
1. 打开 iPad **设置 (Settings)**。
2. 进入 **通用 (General)** -> **VPN 与设备管理 (VPN & Device Management)**。
3. 点击您的 Apple ID 或开发者名称。
4. 点击 **“信任...”**。

---

## 4. 常见问题排查
- **无法找到开发者模式**：请确保 iPad 已通过线缆连接到 Mac。如果还是没有，请先通过 Xcode 尝试运行一次应用，该选项通常会随后出现。
- **Xcode 提示 OS Version 无法支持**：请确保 iPad 的 iOS 版本不高于 Mac 上 Xcode 支持的最高版本。
