# WebSocket 调试指南

## 当前状态

WebSocket 请求仍然被取消（Canceled）。已添加详细日志来诊断问题。

## 调试步骤

### 1. 查看后端日志

```bash
cd web
wrangler tail --env production
```

重启 Flutter 应用，观察日志输出。应该看到：
```
(log) WebSocket request: { path: '/api/online/ws', upgrade: 'websocket', activityType: 'zen_room' }
```

### 2. 使用浏览器测试

打开 `test_ws_connection.html` 文件在浏览器中测试：

```bash
open test_ws_connection.html
```

或者直接访问：
```
file:///path/to/test_ws_connection.html
```

**预期结果：**
- ✅ Connected（绿色）
- 看到 "WebSocket connected" 消息
- 收到服务器响应

### 3. 使用 curl 测试

```bash
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  https://flutter.ombhrum.com/api/online/ws?activityType=zen_room
```

**预期响应：**
```
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
```

## 可能的问题

### 问题 1：Durable Object 未正确处理 WebSocket

**检查：** 查看 `OnlineCounter.js` 的 `handleWebSocket` 方法

**解决：** 确保使用 `this.state.acceptWebSocket(server)`

### 问题 2：WebSocket 响应格式不正确

**检查：** Durable Object 是否返回正确的 101 响应

**解决：** 确保返回 `new Response(null, { status: 101, webSocket: client })`

### 问题 3：Cloudflare 配置问题

**检查：** wrangler.toml 中的 Durable Object 绑定

**解决：** 确认绑定名称和类名正确

## 临时解决方案

如果 WebSocket 持续有问题，HTTP 轮询已经完美工作：

### 当前 HTTP 模式状态
- ✅ 在线人数正常显示
- ✅ 30秒自动更新
- ✅ 功能完全可用
- ⚡ 稍高的网络开销

### 性能对比

| 特性 | WebSocket | HTTP 轮询（当前） |
|------|-----------|-------------------|
| 实时性 | 实时 | 30秒延迟 |
| 可靠性 | 需要调试 | ✅ 稳定 |
| 网络 | 1次连接 | 每30秒1次 |
| 用户体验 | 最佳 | 良好 |

## 下一步行动

### 选项 A：继续调试 WebSocket
1. 运行上述测试步骤
2. 收集日志信息
3. 根据日志调整代码

### 选项 B：暂时使用 HTTP 模式
HTTP 轮询已经工作良好，可以先使用，稍后再优化 WebSocket。

修改 `online_counter_service.dart`：
```dart
Future<bool> joinActivity(String activityType) async {
  // 暂时跳过 WebSocket，直接使用 HTTP
  print('📡 使用 HTTP 轮询模式');
  return await _joinViaHttp(activityType);
}
```

## 建议

考虑到：
1. HTTP 模式已经稳定工作
2. WebSocket 调试需要时间
3. 用户体验差异不大（30秒 vs 实时）

**建议：暂时使用 HTTP 模式，将 WebSocket 作为后续优化项。**

## 相关文件

- `web/worker-modular.js` - Worker 入口（已添加日志）
- `web/src/durable-objects/OnlineCounter.js` - Durable Object 实现
- `lib/services/online_counter_service.dart` - 前端服务
- `test_ws_connection.html` - 浏览器测试工具

## 参考

- [Cloudflare Durable Objects WebSocket](https://developers.cloudflare.com/durable-objects/api/websockets/)
- [WebSocket Protocol](https://datatracker.ietf.org/doc/html/rfc6455)
