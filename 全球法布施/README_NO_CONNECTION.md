# 无连接全球发送实现文档

## 概述

无连接全球发送是一种革命性的数据传输模式，它不需要建立传统的连接就能直接将数据发送到全球网络。这种模式确保数据能够真实离开设备并进入网络，即使没有接收设备也能完成发送。

## 核心特点

### ✅ 主要优势
- **无需连接**：不需要建立TCP连接或等待握手
- **立即发送**：选择文件后立即开始发送
- **全球覆盖**：数据发送到全球多个网络端点
- **多协议支持**：使用UDP、HTTP、WebSocket、WebRTC等多种协议
- **真实传输**：确保数据真实离开设备进入网络

### ⚠️ 注意事项
- 此模式会向全球多个网络端点发送数据
- 数据包可能被网络设备或防火墙过滤
- 不保证数据被接收，但保证数据被发送

## 技术架构

### 1. 双平台实现

#### Native平台 (iOS/Android/macOS/Windows/Linux)
- **服务类**：`NoConnectionService`
- **核心技术**：
  - UDP广播和多播
  - 原始套接字
  - 全球DNS服务器
  - 多种网络协议并行发送

#### Web平台
- **服务类**：`NoConnectionWebService`
- **桥接器**：`flutter-no-connection-bridge.js`
- **核心技术**：
  - HTTP POST请求
  - WebSocket连接
  - WebRTC STUN服务器
  - DNS over HTTPS
  - 图片上传API

### 2. 全球目标端点

#### Native平台目标
```dart
// 全球知名DNS服务器
'8.8.8.8:53'        // Google DNS
'1.1.1.1:53'        // Cloudflare DNS
'208.67.222.222:53' // OpenDNS

// 全球多播地址
'224.0.0.1:5353'         // mDNS多播
'239.255.255.250:1900'   // SSDP多播

// 全球广播地址
'255.255.255.255:8080'   // 全局广播
```

#### Web平台目标
```javascript
// HTTP端点
'https://httpbin.org/post'
'https://postman-echo.com/post'
'https://jsonplaceholder.typicode.com/posts'

// WebSocket端点
'wss://echo.websocket.org'
'wss://ws.postman-echo.com/raw'

// WebRTC STUN服务器
'stun:stun.l.google.com:19302'
'stun:stun.stunprotocol.org:3478'

// DNS over HTTPS
'https://cloudflare-dns.com/dns-query'
'https://dns.google/dns-query'
```

## 实现细节

### 1. Native平台实现

#### 核心服务：`NoConnectionService`
```dart
class NoConnectionService {
  // 创建多个发送套接字
  Future<List<RawDatagramSocket>> _createMultipleSockets()
  
  // 获取全球目标地址
  List<Map<String, dynamic>> _getGlobalTargets(String country)
  
  // 无连接发送文件
  Future<void> _sendFileWithoutConnection(...)
}
```

#### 关键特性
- **多套接字发送**：创建多个UDP套接字并行发送
- **智能目标选择**：根据国家选择不同的目标端点
- **数据包封装**：包含文件元数据和分块信息
- **错误容忍**：单个目标失败不影响整体发送

### 2. Web平台实现

#### 核心服务：`NoConnectionWebService`
```dart
class NoConnectionWebService {
  // 初始化JavaScript桥接器
  Future<bool> initialize()
  
  // 设置JavaScript回调函数
  void _setupCallbacks()
  
  // 开始无连接发送
  Future<void> startSending(...)
}
```

#### JavaScript桥接器：`flutter-no-connection-bridge.js`
```javascript
window.flutterNoConnectionBridge = {
  initialize: function(),
  registerFile: function(fileId, fileName, fileBytes),
  startSending: async function(fileIds, options),
  stopSending: function(),
  getStatus: function(),
  testConnections: async function()
}
```

#### 核心管理器：`no-connection-transfer.js`
```javascript
class NoConnectionManager {
  // 创建全球目标端点
  _createGlobalTargets()
  
  // 无连接发送文件
  async _sendFileWithoutConnection(file)
  
  // 发送到指定目标
  async _sendToTarget(target, data, binaryData)
}
```

### 3. 数据包格式

#### 文件元数据包
```json
{
  "type": "FILE_START",
  "name": "filename.txt",
  "size": 1024000,
  "timestamp": 1640995200000,
  "id": "unique_id",
  "mode": "NO_CONNECTION"
}
```

#### 数据块包
```json
{
  "type": "FILE_CHUNK",
  "index": 0,
  "size": 8192,
  "fileName": "filename.txt",
  "id": "unique_id",
  "totalChunks": 125
}
```

#### 结束标记包
```json
{
  "type": "FILE_END",
  "fileName": "filename.txt",
  "totalChunks": 125,
  "totalSize": 1024000,
  "timestamp": 1640995300000,
  "id": "unique_id"
}
```

## 用户界面

### 1. 主界面集成
- 在文件选择区域添加"无连接发送"按钮
- 橙色主题突出无连接模式的特殊性
- 提供快速启动和详细配置两种方式

### 2. 专用界面：`NoConnectionScreen`
- **功能介绍**：详细说明无连接发送的特点
- **文件管理**：选择和管理要发送的文件
- **发送设置**：
  - 目标区域选择（全球/特定国家）
  - 循环发送模式
- **实时状态**：
  - 发送进度动画
  - 已发送文件数量
  - 已发送数据量
- **技术信息**：显示使用的网络协议和技术原理

### 3. 状态指示
- **Web服务状态**：显示JavaScript桥接器是否就绪
- **发送动画**：脉冲动画表示正在发送
- **进度统计**：实时更新发送统计信息

## 使用方法

### 1. 基本使用
```dart
// 创建无连接服务
final service = NoConnectionService(
  onProgress: (count) => print('已发送 $count 个文件'),
  onDataSent: (mb) => print('已发送 ${mb.toStringAsFixed(2)} MB'),
  onStopped: () => print('发送完成'),
);

// 开始发送
await service.startSending(
  files: selectedFiles,
  isWeb: kIsWeb,
  isLoop: false,
  country: 'ALL',
);
```

### 2. Web平台使用
```dart
// 初始化Web服务
final webService = NoConnectionWebService(...);
await webService.initialize();

// 开始发送
await webService.startSending(
  files: selectedFiles,
  isLoop: false,
  country: 'ALL',
);
```

## 技术优势

### 1. 无连接特性
- **即时发送**：无需等待连接建立
- **高可靠性**：不依赖特定的接收端
- **网络适应性**：适应各种网络环境

### 2. 多协议支持
- **协议多样性**：UDP、TCP、HTTP、WebSocket、WebRTC
- **平台适配**：针对不同平台使用最适合的协议
- **容错能力**：单个协议失败不影响整体发送

### 3. 全球覆盖
- **地理分布**：目标端点分布在全球各地
- **服务多样性**：DNS、CDN、公共API等多种服务
- **高可用性**：多个备用目标确保发送成功

## 安全考虑

### 1. 数据隐私
- 数据发送到公共端点，需要考虑隐私保护
- 建议对敏感数据进行加密
- 避免发送个人身份信息

### 2. 网络影响
- 控制发送速率，避免网络拥塞
- 尊重目标服务器的使用条款
- 避免对单个端点发送过多数据

### 3. 合规性
- 遵守当地网络使用法规
- 尊重网络服务提供商的政策
- 确保使用方式符合道德标准

## 故障排除

### 1. 常见问题
- **Web服务未初始化**：检查JavaScript文件是否正确加载
- **发送失败**：检查网络连接和防火墙设置
- **进度不更新**：检查回调函数是否正确设置

### 2. 调试方法
- 查看控制台日志
- 使用网络监控工具
- 测试网络连接状态

### 3. 性能优化
- 调整数据块大小
- 控制并发发送数量
- 优化目标端点选择

## 未来发展

### 1. 协议扩展
- 支持更多网络协议
- 增加P2P直连功能
- 集成区块链网络

### 2. 智能化
- AI驱动的目标选择
- 自适应发送策略
- 网络质量预测

### 3. 安全增强
- 端到端加密
- 数字签名验证
- 匿名化传输

---

**注意**：无连接发送是一种实验性技术，使用时请遵守相关法律法规和网络使用规范。