// GENERATED CODE - DO NOT EDIT BY HAND.
// Source: native/miniapp-core. Regenerate with:
//   cargo run --manifest-path native/miniapp-core/Cargo.toml --bin miniapp-codegen

export const MINIAPP_SPEC_SCHEMA_VERSION = 2;
export const MINIAPP_HOST_API_VERSION = "1.6";
export const MINIAPP_HOST_SDK_VERSION = "1.6.0";

export const MINIAPP_HOST_SPEC = {
  "schemaVersion": 2,
  "hostApiVersion": "1.6",
  "hostSdkVersion": "1.6.0",
  "invokePattern": "window.FabushiMiniApp.invoke(method, params)",
  "commandProtocol": {
    "event": "fabushi-miniapp-command",
    "lastCommandCache": "window.__fabushiLastMiniAppCommand",
    "helpers": [
      "window.FabushiMiniApp.bot.onAnyCommand(callback)",
      "window.FabushiMiniApp.bot.onCommand(command, callback)"
    ],
    "defaultCommand": "/start",
    "detail": {
      "id": "stable command id",
      "command": "/start",
      "args": "message text without command prefix",
      "text": "raw chat text",
      "background": true,
      "source": "chat"
    },
    "resultMethods": ["bot.postMessage", "bot.reportCommandResult"]
  },
  "permissionGroups": {
    "botMessaging": ["bot.chat"],
    "core": ["app.context"],
    "creation": ["flashcards.create", "platform.publish"],
    "device": ["device.biometrics", "device.qrScanner", "haptics.feedback"],
    "externalNavigation": ["browser.external"],
    "identity": ["auth.session", "auth.token"],
    "localAutomation": ["desktop.control", "files.pick", "fs.readWrite", "local.loopback", "openclaw.chat", "openclaw.status", "projects.read", "shell.execute"],
    "nativeNetwork": ["network.interfaces", "network.udp"],
    "nativeUi": ["ui.native"],
    "payments": ["payments.alipay", "payments.entitlement", "payments.fudeGold", "wallet.balance"],
    "share": ["share.chat"],
    "storage": ["cloud.kv"],
    "system": ["hotspot.settings", "system.keepAwake"]
  },
  "capabilityModel": {
    "name": "Rust-backed capability negotiation layer",
    "manifestField": "permissions",
    "requestMethod": "app.requestCapabilities",
    "preinstalledAdapterRequired": true,
    "canCreateNewSystemApi": false,
    "rule": "小程序只能使用 manifest 已声明、宿主已预置 adapter、当前平台可用、并满足信任等级的能力原语。",
    "principle": "小程序不能让宿主凭空获得新的系统 API；新增系统级能力必须先进入 Rust 契约和宿主 adapter，再由 SDK 暴露。",
    "statusMeanings": {
      "granted": "权限已声明、adapter 已预置、平台可用、信任等级满足。",
      "denied": "宿主支持该能力，但当前小程序 manifest 未声明或未获准。",
      "unsupportedPlatform": "宿主已内置该能力原语，但当前平台不可用。",
      "trustRequired": "能力属于高危原生面，只允许受信官方小程序调用。",
      "unknown": "宿主没有内置该能力原语或 adapter。"
    },
    "flow": [
      "小程序在 manifest.permissions 声明需要的能力原语。",
      "运行时调用 app.requestCapabilities 请求协商。",
      "宿主按权限声明、adapter、平台可用性、信任等级返回状态。",
      "小程序只调用 granted 能力；业务逻辑仍留在小程序或其服务侧。"
    ]
  },
  "capabilities": [
    {
      "id": "app.context",
      "layer": "core",
      "native": false,
      "adapter": "MiniAppHostContextAdapter",
      "availability": "always",
      "trust": "declared",
      "risk": "low",
      "methods": ["app.getContext", "app.getCapabilities", "app.requestCapabilities", "app.getHostApiSpec", "app.getTheme"],
      "note": "能力协商基础层；小程序读取上下文、权限列表和宿主 API 规格。"
    },
    {
      "id": "bot.chat",
      "layer": "botMessaging",
      "native": false,
      "adapter": "MiniAppBotBridgeAdapter",
      "availability": "always",
      "trust": "declared",
      "risk": "low",
      "methods": ["bot.sendMessage", "bot.postMessage", "bot.reportCommandResult", "bot.takePendingCommands", "bot.openPanel", "bot.setPanelState", "bot.setCommands", "bot.close"],
      "note": "宿主只做聊天命令、面板和回写媒介，不承载小程序业务逻辑。"
    },
    {
      "id": "auth.session",
      "layer": "identity",
      "native": false,
      "adapter": "AuthSessionAdapter",
      "availability": "always",
      "trust": "declared",
      "risk": "medium",
      "methods": ["auth.getSession", "auth.requireLogin"],
      "note": "返回脱敏用户与会员状态；不返回宿主访问 token。"
    },
    {
      "id": "auth.token",
      "layer": "identity",
      "native": false,
      "adapter": "AuthTokenAdapter",
      "availability": "always",
      "trust": "trustedOfficial",
      "risk": "critical",
      "methods": ["auth.getAccessToken"],
      "note": "访问 token 只给受信官方小程序；第三方使用 Telegram 风格 initData 签名。"
    },
    {
      "id": "payments.alipay",
      "layer": "payments",
      "native": true,
      "adapter": "AlipayPaymentAdapter",
      "availability": "always",
      "trust": "trustedOfficial",
      "risk": "high",
      "methods": ["payments.alipay.createOrder", "payments.alipay.pay", "payments.alipay.queryOrder"],
      "note": "官方兼容能力；开放平台商品结算应优先走福德金 / invoice 抽象。"
    },
    {
      "id": "payments.entitlement",
      "layer": "payments",
      "native": false,
      "adapter": "MiniAppEntitlementAdapter",
      "availability": "always",
      "trust": "declared",
      "risk": "medium",
      "methods": ["payments.checkEntitlement", "payments.alipay.checkEntitlement"]
    },
    {
      "id": "payments.fudeGold",
      "layer": "payments",
      "native": false,
      "adapter": "FudeGoldPaymentAdapter",
      "availability": "always",
      "trust": "declared",
      "risk": "high",
      "methods": ["payments.requestPayment"],
      "note": "统一平台代币支付入口；宿主负责原生确认和权益登记。"
    },
    {
      "id": "wallet.balance",
      "layer": "payments",
      "native": false,
      "adapter": "WalletBalanceAdapter",
      "availability": "always",
      "trust": "declared",
      "risk": "medium",
      "methods": ["wallet.getBalance"]
    },
    {
      "id": "network.udp",
      "layer": "nativeNetwork",
      "native": true,
      "adapter": "UdpSocketAdapter",
      "availability": "nativeIo",
      "trust": "trustedOfficial",
      "risk": "high",
      "methods": ["network.udp.open", "network.udp.send", "network.udp.broadcast", "network.udp.close"],
      "note": "宿主提供 UDP socket 原语，小程序自行解释业务协议。"
    },
    {
      "id": "network.interfaces",
      "layer": "nativeNetwork",
      "native": true,
      "adapter": "NetworkInterfaceAdapter",
      "availability": "nativeIo",
      "trust": "trustedOfficial",
      "risk": "high",
      "methods": ["network.interfaces.list"],
      "note": "暴露本机网卡与地址，默认只给受信官方小程序。"
    },
    {
      "id": "system.keepAwake",
      "layer": "system",
      "native": true,
      "adapter": "KeepAwakeAdapter",
      "availability": "always",
      "trust": "declared",
      "risk": "medium",
      "methods": ["system.keepAwake"]
    },
    {
      "id": "hotspot.settings",
      "layer": "system",
      "native": true,
      "adapter": "HotspotSettingsAdapter",
      "availability": "nativeIo",
      "trust": "trustedOfficial",
      "risk": "high",
      "methods": ["hotspot.openSettings"]
    },
    {
      "id": "ui.native",
      "layer": "nativeUi",
      "native": true,
      "adapter": "NativeUiAdapter",
      "availability": "always",
      "trust": "declared",
      "risk": "medium",
      "methods": ["ui.alert", "ui.confirm", "ui.mainButton.set"],
      "note": "对标 Telegram MainButton 与微信原生弹窗；具体 UI adapter 可逐平台补齐。"
    },
    {
      "id": "haptics.feedback",
      "layer": "device",
      "native": true,
      "adapter": "HapticFeedbackAdapter",
      "availability": "nativeIo",
      "trust": "declared",
      "risk": "medium",
      "methods": ["haptics.impact", "haptics.notification", "haptics.selection"]
    },
    {
      "id": "device.biometrics",
      "layer": "device",
      "native": true,
      "adapter": "BiometricAuthAdapter",
      "availability": "nativeIo",
      "trust": "trustedOfficial",
      "risk": "high",
      "methods": ["device.biometrics.authenticate"],
      "note": "高危操作可拉起 Face ID / Touch ID / Android biometrics。"
    },
    {
      "id": "device.qrScanner",
      "layer": "device",
      "native": true,
      "adapter": "QrScannerAdapter",
      "availability": "nativeIo",
      "trust": "declared",
      "risk": "medium",
      "methods": ["device.qrScanner.scan"]
    },
    {
      "id": "cloud.kv",
      "layer": "storage",
      "native": false,
      "adapter": "CloudKeyValueStorageAdapter",
      "availability": "always",
      "trust": "declared",
      "risk": "medium",
      "methods": ["cloud.kv.get", "cloud.kv.set", "cloud.kv.delete"],
      "note": "每个小程序隔离的轻量云端 Key-Value。"
    },
    {
      "id": "share.chat",
      "layer": "share",
      "native": false,
      "adapter": "ShareToChatAdapter",
      "availability": "always",
      "trust": "declared",
      "risk": "medium",
      "methods": ["share.chat.send"],
      "note": "生成富文本卡片并唤起法布施联系人分享。"
    },
    {
      "id": "flashcards.create",
      "layer": "creation",
      "native": false,
      "adapter": "FlashcardDeckAdapter",
      "availability": "always",
      "trust": "declared",
      "risk": "medium",
      "methods": ["flashcards.createDeck", "flashcards.openDeck"],
      "note": "复用宿主制卡流水线；小程序只声明权限并传入内容。"
    },
    {
      "id": "platform.publish",
      "layer": "creation",
      "native": false,
      "adapter": "PlatformPublishAdapter",
      "availability": "always",
      "trust": "declared",
      "risk": "medium",
      "methods": ["platformPublish.createDraft", "platformPublish.publishDraft"]
    },
    {
      "id": "files.pick",
      "layer": "localAutomation",
      "native": true,
      "adapter": "FilePickerAdapter",
      "availability": "nativeIo",
      "trust": "declared",
      "risk": "medium",
      "methods": ["files.pick"]
    },
    {
      "id": "projects.read",
      "layer": "localAutomation",
      "native": true,
      "adapter": "LocalProjectCatalogAdapter",
      "availability": "desktopNative",
      "trust": "trustedOfficial",
      "risk": "high",
      "methods": ["projects.list", "projects.select"]
    },
    {
      "id": "openclaw.status",
      "layer": "localAutomation",
      "native": true,
      "adapter": "OpenClawRuntimeStatusAdapter",
      "availability": "desktopNative",
      "trust": "trustedOfficial",
      "risk": "high",
      "methods": ["openclaw.status", "openclaw.restart"]
    },
    {
      "id": "openclaw.chat",
      "layer": "localAutomation",
      "native": false,
      "adapter": "OpenClawChatAdapter",
      "availability": "desktopNative",
      "trust": "trustedOfficial",
      "risk": "high",
      "methods": ["openclaw.chat"],
      "note": "桌面 AI/终端协作通道；必须由宿主预置具体 adapter。"
    },
    {
      "id": "desktop.control",
      "layer": "localAutomation",
      "native": true,
      "adapter": "DesktopControlAdapter",
      "availability": "desktopNative",
      "trust": "trustedOfficial",
      "risk": "critical",
      "methods": ["desktopControl.executeTool"],
      "note": "桌面控制原语，只给受信官方小程序。"
    },
    {
      "id": "local.loopback",
      "layer": "localAutomation",
      "native": true,
      "adapter": "LocalLoopbackAdapter",
      "availability": "desktopNative",
      "trust": "trustedOfficial",
      "risk": "high",
      "methods": ["localLoopback.fetch"],
      "note": "仅允许访问 localhost / 127.0.0.1 / ::1。"
    },
    {
      "id": "fs.readWrite",
      "layer": "localAutomation",
      "native": true,
      "adapter": "MiniAppPrivateFileSystemAdapter",
      "availability": "desktopNative",
      "trust": "trustedOfficial",
      "risk": "critical",
      "methods": ["fs.writeFile", "fs.readFile"],
      "note": "默认限制到小程序私有目录；绝对路径需后续接用户授权 token。"
    },
    {
      "id": "shell.execute",
      "layer": "localAutomation",
      "native": true,
      "adapter": "LocalShellAdapter",
      "availability": "desktopNative",
      "trust": "trustedOfficial",
      "risk": "critical",
      "methods": ["shell.execute"],
      "note": "本地命令执行必须受信、可审计，并由宿主流式回传日志。"
    },
    {
      "id": "browser.external",
      "layer": "externalNavigation",
      "native": true,
      "adapter": "ExternalBrowserAdapter",
      "availability": "always",
      "trust": "declared",
      "risk": "medium",
      "methods": ["browser.open"]
    }
  ],
  "nativeCapabilities": [
    {
      "id": "payments.alipay",
      "layer": "payments",
      "native": true,
      "adapter": "AlipayPaymentAdapter",
      "availability": "always",
      "trust": "trustedOfficial",
      "risk": "high",
      "methods": ["payments.alipay.createOrder", "payments.alipay.pay", "payments.alipay.queryOrder"],
      "note": "官方兼容能力；开放平台商品结算应优先走福德金 / invoice 抽象。"
    },
    {
      "id": "network.udp",
      "layer": "nativeNetwork",
      "native": true,
      "adapter": "UdpSocketAdapter",
      "availability": "nativeIo",
      "trust": "trustedOfficial",
      "risk": "high",
      "methods": ["network.udp.open", "network.udp.send", "network.udp.broadcast", "network.udp.close"],
      "note": "宿主提供 UDP socket 原语，小程序自行解释业务协议。"
    },
    {
      "id": "network.interfaces",
      "layer": "nativeNetwork",
      "native": true,
      "adapter": "NetworkInterfaceAdapter",
      "availability": "nativeIo",
      "trust": "trustedOfficial",
      "risk": "high",
      "methods": ["network.interfaces.list"],
      "note": "暴露本机网卡与地址，默认只给受信官方小程序。"
    },
    {
      "id": "system.keepAwake",
      "layer": "system",
      "native": true,
      "adapter": "KeepAwakeAdapter",
      "availability": "always",
      "trust": "declared",
      "risk": "medium",
      "methods": ["system.keepAwake"]
    },
    {
      "id": "hotspot.settings",
      "layer": "system",
      "native": true,
      "adapter": "HotspotSettingsAdapter",
      "availability": "nativeIo",
      "trust": "trustedOfficial",
      "risk": "high",
      "methods": ["hotspot.openSettings"]
    },
    {
      "id": "ui.native",
      "layer": "nativeUi",
      "native": true,
      "adapter": "NativeUiAdapter",
      "availability": "always",
      "trust": "declared",
      "risk": "medium",
      "methods": ["ui.alert", "ui.confirm", "ui.mainButton.set"],
      "note": "对标 Telegram MainButton 与微信原生弹窗；具体 UI adapter 可逐平台补齐。"
    },
    {
      "id": "haptics.feedback",
      "layer": "device",
      "native": true,
      "adapter": "HapticFeedbackAdapter",
      "availability": "nativeIo",
      "trust": "declared",
      "risk": "medium",
      "methods": ["haptics.impact", "haptics.notification", "haptics.selection"]
    },
    {
      "id": "device.biometrics",
      "layer": "device",
      "native": true,
      "adapter": "BiometricAuthAdapter",
      "availability": "nativeIo",
      "trust": "trustedOfficial",
      "risk": "high",
      "methods": ["device.biometrics.authenticate"],
      "note": "高危操作可拉起 Face ID / Touch ID / Android biometrics。"
    },
    {
      "id": "device.qrScanner",
      "layer": "device",
      "native": true,
      "adapter": "QrScannerAdapter",
      "availability": "nativeIo",
      "trust": "declared",
      "risk": "medium",
      "methods": ["device.qrScanner.scan"]
    },
    {
      "id": "files.pick",
      "layer": "localAutomation",
      "native": true,
      "adapter": "FilePickerAdapter",
      "availability": "nativeIo",
      "trust": "declared",
      "risk": "medium",
      "methods": ["files.pick"]
    },
    {
      "id": "projects.read",
      "layer": "localAutomation",
      "native": true,
      "adapter": "LocalProjectCatalogAdapter",
      "availability": "desktopNative",
      "trust": "trustedOfficial",
      "risk": "high",
      "methods": ["projects.list", "projects.select"]
    },
    {
      "id": "openclaw.status",
      "layer": "localAutomation",
      "native": true,
      "adapter": "OpenClawRuntimeStatusAdapter",
      "availability": "desktopNative",
      "trust": "trustedOfficial",
      "risk": "high",
      "methods": ["openclaw.status", "openclaw.restart"]
    },
    {
      "id": "desktop.control",
      "layer": "localAutomation",
      "native": true,
      "adapter": "DesktopControlAdapter",
      "availability": "desktopNative",
      "trust": "trustedOfficial",
      "risk": "critical",
      "methods": ["desktopControl.executeTool"],
      "note": "桌面控制原语，只给受信官方小程序。"
    },
    {
      "id": "local.loopback",
      "layer": "localAutomation",
      "native": true,
      "adapter": "LocalLoopbackAdapter",
      "availability": "desktopNative",
      "trust": "trustedOfficial",
      "risk": "high",
      "methods": ["localLoopback.fetch"],
      "note": "仅允许访问 localhost / 127.0.0.1 / ::1。"
    },
    {
      "id": "fs.readWrite",
      "layer": "localAutomation",
      "native": true,
      "adapter": "MiniAppPrivateFileSystemAdapter",
      "availability": "desktopNative",
      "trust": "trustedOfficial",
      "risk": "critical",
      "methods": ["fs.writeFile", "fs.readFile"],
      "note": "默认限制到小程序私有目录；绝对路径需后续接用户授权 token。"
    },
    {
      "id": "shell.execute",
      "layer": "localAutomation",
      "native": true,
      "adapter": "LocalShellAdapter",
      "availability": "desktopNative",
      "trust": "trustedOfficial",
      "risk": "critical",
      "methods": ["shell.execute"],
      "note": "本地命令执行必须受信、可审计，并由宿主流式回传日志。"
    },
    {
      "id": "browser.external",
      "layer": "externalNavigation",
      "native": true,
      "adapter": "ExternalBrowserAdapter",
      "availability": "always",
      "trust": "declared",
      "risk": "medium",
      "methods": ["browser.open"]
    }
  ],
  "methods": [
    {
      "method": "app.getContext",
      "permission": "app.context",
      "risk": "low",
      "description": "读取宿主、小程序、机器人和平台上下文。"
    },
    {
      "method": "app.getCapabilities",
      "permission": "app.context",
      "risk": "low",
      "description": "读取当前小程序可用能力列表。"
    },
    {
      "method": "app.requestCapabilities",
      "permission": "app.context",
      "risk": "low",
      "description": "按 manifest、adapter、平台、信任等级协商能力状态。"
    },
    {
      "method": "app.getHostApiSpec",
      "permission": "app.context",
      "risk": "low",
      "description": "读取宿主 API 规格。"
    },
    {
      "method": "app.getTheme",
      "permission": "app.context",
      "risk": "low",
      "description": "读取宿主主题 token。"
    },
    {
      "method": "bot.sendMessage",
      "permission": "bot.chat",
      "risk": "low",
      "description": "小程序向宿主机器人发送消息。"
    },
    {
      "method": "bot.postMessage",
      "permission": "bot.chat",
      "risk": "low",
      "description": "小程序把后台命令进度、结果或错误写回聊天框。"
    },
    {
      "method": "bot.reportCommandResult",
      "permission": "bot.chat",
      "risk": "low",
      "description": "按 commandId 上报后台命令完成、失败或仍在运行。"
    },
    {
      "method": "bot.takePendingCommands",
      "permission": "bot.chat",
      "risk": "low",
      "description": "从宿主消息队列拉取聊天命令。"
    },
    {
      "method": "bot.openPanel",
      "permission": "bot.chat",
      "risk": "low",
      "description": "请求打开小程序面板。"
    },
    {
      "method": "bot.setPanelState",
      "permission": "bot.chat",
      "risk": "low",
      "description": "设置小程序面板状态。"
    },
    {
      "method": "bot.setCommands",
      "permission": "bot.chat",
      "risk": "low",
      "description": "向宿主暴露可从聊天触发的命令。"
    },
    {
      "method": "bot.close",
      "permission": "bot.chat",
      "risk": "low",
      "description": "请求关闭小程序。"
    },
    {
      "method": "auth.getSession",
      "permission": "auth.session",
      "risk": "medium",
      "description": "读取宿主登录态、脱敏用户资料和会员状态。"
    },
    {
      "method": "auth.requireLogin",
      "permission": "auth.session",
      "risk": "medium",
      "description": "要求用户登录；未登录时由宿主打开登录页。"
    },
    {
      "method": "auth.getAccessToken",
      "permission": "auth.token",
      "risk": "critical",
      "description": "读取宿主访问 token，仅受信官方小程序可用。"
    },
    {
      "method": "payments.alipay.createOrder",
      "permission": "payments.alipay",
      "risk": "high",
      "description": "创建支付宝订单；开放平台应优先使用统一 invoice。"
    },
    {
      "method": "payments.alipay.pay",
      "permission": "payments.alipay",
      "risk": "high",
      "description": "拉起支付宝 App 或网页支付。"
    },
    {
      "method": "payments.alipay.queryOrder",
      "permission": "payments.alipay",
      "risk": "high",
      "description": "查询支付宝订单状态。"
    },
    {
      "method": "payments.checkEntitlement",
      "permission": "payments.entitlement",
      "risk": "medium",
      "description": "查询宿主后端是否已解锁一次性付费商品。"
    },
    {
      "method": "payments.alipay.checkEntitlement",
      "permission": "payments.entitlement",
      "risk": "medium",
      "description": "查询宿主后端是否已解锁一次性付费商品。"
    },
    {
      "method": "payments.requestPayment",
      "permission": "payments.fudeGold",
      "risk": "high",
      "description": "请求宿主弹出原生确认并扣除福德金。"
    },
    {
      "method": "wallet.getBalance",
      "permission": "wallet.balance",
      "risk": "medium",
      "description": "读取当前用户福德金余额。"
    },
    {
      "method": "network.udp.open",
      "permission": "network.udp",
      "risk": "high",
      "description": "打开原生 UDP socket。"
    },
    {
      "method": "network.udp.send",
      "permission": "network.udp",
      "risk": "high",
      "description": "通过已打开的 socket 发送 base64 UDP 数据包。"
    },
    {
      "method": "network.udp.broadcast",
      "permission": "network.udp",
      "risk": "high",
      "description": "向广播地址发送 base64 UDP 数据包。"
    },
    {
      "method": "network.udp.close",
      "permission": "network.udp",
      "risk": "high",
      "description": "关闭指定 UDP socket。"
    },
    {
      "method": "network.interfaces.list",
      "permission": "network.interfaces",
      "risk": "high",
      "description": "列出宿主网络接口和 IP 地址。"
    },
    {
      "method": "system.keepAwake",
      "permission": "system.keepAwake",
      "risk": "medium",
      "description": "请求宿主在任务期间尽量保持唤醒。"
    },
    {
      "method": "hotspot.openSettings",
      "permission": "hotspot.settings",
      "risk": "high",
      "description": "打开或引导系统热点设置。"
    },
    {
      "method": "ui.alert",
      "permission": "ui.native",
      "risk": "medium",
      "description": "显示宿主原生提示弹窗。"
    },
    {
      "method": "ui.confirm",
      "permission": "ui.native",
      "risk": "medium",
      "description": "显示宿主原生确认弹窗。"
    },
    {
      "method": "ui.mainButton.set",
      "permission": "ui.native",
      "risk": "medium",
      "description": "设置宿主底部主按钮状态。"
    },
    {
      "method": "haptics.impact",
      "permission": "haptics.feedback",
      "risk": "medium",
      "description": "触发冲击触觉反馈。"
    },
    {
      "method": "haptics.notification",
      "permission": "haptics.feedback",
      "risk": "medium",
      "description": "触发通知触觉反馈。"
    },
    {
      "method": "haptics.selection",
      "permission": "haptics.feedback",
      "risk": "medium",
      "description": "触发选择触觉反馈。"
    },
    {
      "method": "device.biometrics.authenticate",
      "permission": "device.biometrics",
      "risk": "high",
      "description": "拉起系统生物识别确认。"
    },
    {
      "method": "device.qrScanner.scan",
      "permission": "device.qrScanner",
      "risk": "medium",
      "description": "拉起原生扫码并返回结果。"
    },
    {
      "method": "cloud.kv.get",
      "permission": "cloud.kv",
      "risk": "medium",
      "description": "读取小程序隔离云端 Key-Value。"
    },
    {
      "method": "cloud.kv.set",
      "permission": "cloud.kv",
      "risk": "medium",
      "description": "写入小程序隔离云端 Key-Value。"
    },
    {
      "method": "cloud.kv.delete",
      "permission": "cloud.kv",
      "risk": "medium",
      "description": "删除小程序隔离云端 Key-Value。"
    },
    {
      "method": "share.chat.send",
      "permission": "share.chat",
      "risk": "medium",
      "description": "生成富文本卡片并分享给联系人。"
    },
    {
      "method": "flashcards.createDeck",
      "permission": "flashcards.create",
      "risk": "medium",
      "description": "复用宿主背诵闪卡流水线生成卡组。"
    },
    {
      "method": "flashcards.openDeck",
      "permission": "flashcards.create",
      "risk": "medium",
      "description": "打开宿主闪卡学习界面。"
    },
    {
      "method": "platformPublish.createDraft",
      "permission": "platform.publish",
      "risk": "medium",
      "description": "复用宿主发布草稿生成能力。"
    },
    {
      "method": "platformPublish.publishDraft",
      "permission": "platform.publish",
      "risk": "medium",
      "description": "请求宿主执行发布草稿流程。"
    },
    {
      "method": "files.pick",
      "permission": "files.pick",
      "risk": "medium",
      "description": "调用宿主文件选择器。"
    },
    {
      "method": "projects.list",
      "permission": "projects.read",
      "risk": "high",
      "description": "列出宿主本地项目目录。"
    },
    {
      "method": "projects.select",
      "permission": "projects.read",
      "risk": "high",
      "description": "选择宿主本地项目。"
    },
    {
      "method": "openclaw.status",
      "permission": "openclaw.status",
      "risk": "high",
      "description": "读取本机 OpenClaw 运行状态。"
    },
    {
      "method": "openclaw.restart",
      "permission": "openclaw.status",
      "risk": "high",
      "description": "重启本机 OpenClaw runtime。"
    },
    {
      "method": "openclaw.chat",
      "permission": "openclaw.chat",
      "risk": "high",
      "description": "通过宿主 OpenClaw adapter 对话。"
    },
    {
      "method": "desktopControl.executeTool",
      "permission": "desktop.control",
      "risk": "critical",
      "description": "调用宿主桌面控制工具。"
    },
    {
      "method": "localLoopback.fetch",
      "permission": "local.loopback",
      "risk": "high",
      "description": "通过宿主访问本机回环服务。"
    },
    {
      "method": "fs.writeFile",
      "permission": "fs.readWrite",
      "risk": "critical",
      "description": "写入小程序私有目录或授权路径。"
    },
    {
      "method": "fs.readFile",
      "permission": "fs.readWrite",
      "risk": "critical",
      "description": "读取小程序私有目录或授权路径。"
    },
    {
      "method": "shell.execute",
      "permission": "shell.execute",
      "risk": "critical",
      "description": "启动本地命令并将日志流回宿主聊天。"
    },
    {
      "method": "browser.open",
      "permission": "browser.external",
      "risk": "medium",
      "description": "使用系统浏览器打开 URL。"
    }
  ]
} as const;

export const MINIAPP_HOST_CAPABILITIES = MINIAPP_HOST_SPEC.capabilities;
export const MINIAPP_HOST_NATIVE_CAPABILITIES = MINIAPP_HOST_SPEC.nativeCapabilities;
export const MINIAPP_HOST_METHODS = MINIAPP_HOST_SPEC.methods;
export type MiniAppHostMethod = typeof MINIAPP_HOST_METHODS[number]["method"];
export type MiniAppCapabilityId = typeof MINIAPP_HOST_CAPABILITIES[number]["id"];
