# WebSocket 连接错误修复方案

## 问题分析

### 错误现象
```
WebSocketException: Connection to 'https://flutter.ombhrum.com:0/api/online/ws?activityType=zen_room#' was not upgraded to websocket
```

### 根本原因

1. **URL 构建错误**：
   - 端口号显示为 `:0`（无效端口）
   - URL 末尾有多余的 `#` 字符
   - 这导致 WebSocket 握手失败

2. **异常未捕获**：
   - WebSocket 连接失败时抛出未处理的异常
   - 导致应用崩溃和无限重连循环

3. **后端可能不支持 WebSocket**：
   - Cloudflare Workers 需要特殊配置才能支持 WebSocket
   - 可能需要使用 Durable Objects 的 WebSocket API

## 解决方案

### 方案 1：修复 WebSocket URL 构建（推荐）

修改 `lib/services/online_counter_service.dart` 中的 `_connectWebSocket` 方法：

```dart
/// 建立 WebSocket 连接
Future<bool> _connectWebSocket(String activityType) async {\n  try {
    // 修复：正确构建 WebSocket URL
    final uri = Uri.parse('$wsUrl/api/online/ws')
        .replace(queryParameters: {'activityType': activityType});
    
    print('🔌 连接 WebSocket: $uri');
    
    _channel = WebSocketChannel.connect(uri);

    // 添加超时控制
    final connectionTimeout = Timer(const Duration(seconds: 10), () {
      if (!_isConnected) {
        print('⏱️ WebSocket 连接超时');
        _channel?.sink.close();
      }
    });

    // 监听 WebSocket 消息
    _channel!.stream.listen(
      (message) {
        connectionTimeout.cancel();
        _isConnected = true;
        _handleWebSocketMessage(message);
      },
      onError: (error) {
        connectionTimeout.cancel();
        print('❌ WebSocket 错误: $error');
        _handleWebSocketError();
      },
      onDone: () {
        connectionTimeout.cancel();
        print('🔌 WebSocket 连接关闭');
        _handleWebSocketClose();
      },
      cancelOnError: true, // 添加此选项
    );

    // 发送 join 消息
    _sendWebSocketMessage({
      'action': 'join',
      'sessionId': _sessionId,
      'activityType': activityType,
    });

    // 等待连接确认
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (_isConnected) {
      print('✅ WebSocket 连接成功');
      _startHeartbeat();
      return true;
    } else {
      print('⚠️ WebSocket 连接未确认');
      return false;
    }
  } catch (e, stackTrace) {
    print('❌ WebSocket 连接失败: $e');
    print('Stack trace: $stackTrace');
    return false;
  }
}
```

### 方案 2：禁用 WebSocket，使用 HTTP 轮询（临时方案）

如果后端暂不支持 WebSocket，可以完全使用 HTTP 方案：

```dart
/// 加入活动（仅使用 HTTP）
Future<bool> joinActivity(String activityType) async {
  if (_currentActivity == activityType && _sessionId != null) {
    return true;
  }

  if (_currentActivity != null) {
    await leaveActivity();
  }

  _sessionId = _uuid.v4();
  _currentActivity = activityType;
  _shouldReconnect = true;

  // 直接使用 HTTP，跳过 WebSocket
  print('📡 使用 HTTP 轮询模式');
  return await _joinViaHttp(activityType);
}
```

### 方案 3：后端添加 WebSocket 支持

如果要使用 WebSocket，需要在 Cloudflare Workers 中添加 WebSocket 处理：

在 `web/worker-modular.js` 中添加：

```javascript
// 处理 WebSocket 升级请求
if (url.pathname === '/api/online/ws') {
  const upgradeHeader = request.headers.get('Upgrade');
  if (upgradeHeader !== 'websocket') {
    return new Response('Expected Upgrade: websocket', { status: 426 });
  }

  const activityType = url.searchParams.get('activityType');
  if (!activityType || !['global_sending', 'zen_room'].includes(activityType)) {
    return new Response('Invalid activityType', { status: 400 });
  }

  // 获取 Durable Object 实例
  const id = env.ONLINE_COUNTER.idFromName(activityType);
  const stub = env.ONLINE_COUNTER.get(id);
  
  // 转发 WebSocket 请求到 Durable Object
  return stub.fetch(request);
}
```

在 `web/src/durable-objects/OnlineCounter.js` 中添加 WebSocket 处理：

```javascript
async fetch(request) {
  const url = new URL(request.url);
  
  // 处理 WebSocket 升级
  if (request.headers.get('Upgrade') === 'websocket') {
    return this.handleWebSocket(request);
  }
  
  // ... 现有的 HTTP 处理代码
}

async handleWebSocket(request) {
  const pair = new WebSocketPair();
  const [client, server] = Object.values(pair);

  this.state.acceptWebSocket(server);

  // 处理 WebSocket 消息
  server.addEventListener('message', async (event) => {
    try {
      const data = JSON.parse(event.data);
      const response = await this.handleWebSocketMessage(data);
      server.send(JSON.stringify(response));
    } catch (error) {
      server.send(JSON.stringify({ type: 'error', message: error.message }));
    }
  });

  return new Response(null, {
    status: 101,
    webSocket: client,
  });
}
```

## 推荐实施步骤

### 立即修复（使用 HTTP 轮询）

1. 修改 `lib/services/online_counter_service.dart`：

```dart
/// 加入活动 - 临时禁用 WebSocket
Future<bool> joinActivity(String activityType) async {
  if (_currentActivity == activityType && _sessionId != null) {
    return true;
  }

  if (_currentActivity != null) {
    await leaveActivity();
  }

  _sessionId = _uuid.v4();
  _currentActivity = activityType;
  _shouldReconnect = true;

  // 临时方案：直接使用 HTTP
  print('📡 使用 HTTP 轮询模式（WebSocket 暂时禁用）');
  return await _joinViaHttp(activityType);
}
```

2. 重新运行应用：
```bash
flutter run
```

### 长期方案（实现 WebSocket）

1. 在后端实现 WebSocket 支持（见方案 3）
2. 测试 WebSocket 连接
3. 恢复前端 WebSocket 代码

## 验证修复

### 测试步骤

1. 清除应用缓存
2. 启动应用并进入禅修室
3. 检查控制台输出：
   - 应该看到 "📡 使用 HTTP 轮询模式"
   - 不应该有 WebSocket 错误
   - 应该能正常显示在线人数

### 预期结果

- ✅ 无 WebSocket 连接错误
- ✅ 无未处理异常
- ✅ 在线人数正常显示
- ✅ 心跳正常工作

## 相关文件

- `lib/services/online_counter_service.dart` - 在线人数服务
- `web/worker-modular.js` - Cloudflare Workers 主文件
- `web/src/handlers/online.js` - 在线人数 HTTP 处理器
- `web/src/durable-objects/OnlineCounter.js` - Durable Object 实现

## 参考资料

- [Cloudflare Workers WebSocket](https://developers.cloudflare.com/workers/runtime-apis/websockets/)
- [Durable Objects WebSocket](https://developers.cloudflare.com/durable-objects/api/websockets/)
- [Flutter WebSocket](https://pub.dev/packages/web_socket_channel)
