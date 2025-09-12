# 全球法布施 - 无中继服务器实现细节（第2部分）

## 关键技术点详解（续）

### 2. 文件分块传输

为了处理大文件传输，我们实现了文件分块机制：

```javascript
// 分块发送文件
const chunkSize = 16384; // 16KB
const totalChunks = Math.ceil(fileBuffer.byteLength / chunkSize);
let sentChunks = 0;

for (let i = 0; i < fileBuffer.byteLength; i += chunkSize) {
  const end = Math.min(i + chunkSize, fileBuffer.byteLength);
  const chunk = fileBuffer.slice(i, end);
  
  // 创建块头部
  const header = JSON.stringify({
    i: sentChunks,
    n: fileName,
    total: totalChunks
  });
  
  // 组合头部和数据
  const headerBytes = new TextEncoder().encode(header);
  const separator = new TextEncoder().encode('|');
  const fullPacket = new Uint8Array(headerBytes.length + separator.length + chunk.byteLength);
  
  fullPacket.set(headerBytes, 0);
  fullPacket.set(separator, headerBytes.length);
  fullPacket.set(new Uint8Array(chunk), headerBytes.length + separator.length);
  
  dataChannel.send(fullPacket);
  sentChunks++;
}
```

### 3. Service Worker拦截

Service Worker拦截网络请求并在本地处理，无需服务器：

```javascript
// 拦截网络请求
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  
  // 处理API请求
  if (url.pathname.startsWith('/api/')) {
    // 处理WiFi广播API
    if (url.pathname === '/api/wifi-broadcast') {
      event.respondWith(handleWifiBroadcast(event.request));
      return;
    }
  }
});
```

### 4. Flutter与JavaScript互操作

使用`js_util`包实现Flutter与JavaScript的互操作：

```dart
// 调用JavaScript函数
final result = await js_util.promiseToFuture(
  js_util.callMethod(
    js_util.getProperty(html.window, 'flutterP2PNetwork'),
    'broadcastFile',
    [fileId]
  )
);

// 解析JavaScript返回的结果
final success = js_util.getProperty(result, 'success');
final sentCount = js_util.getProperty(result, 'sentCount');
```

## 实现挑战与解决方案

### 1. WebRTC信令问题

**挑战**：WebRTC需要信令服务器进行初始连接协商。

**解决方案**：使用BroadcastChannel和localStorage作为本地信令通道。

```javascript
// 初始化本地发现机制
_initDiscovery() {
  // 使用BroadcastChannel作为主要发现通道
  try {
    this.broadcastChannel = new BroadcastChannel('global-sharing-discovery');
    // ...
  } catch (e) {
    console.warn('BroadcastChannel不可用，使用localStorage作为备选', e);
    this._initLocalStorageDiscovery();
  }
}
```

### 2. 跨设备发现问题

**挑战**：在不同设备间发现对方节点。

**解决方案**：使用localStorage事件和Service Worker消息通道。

```javascript
// 使用localStorage作为备选发现机制
_initLocalStorageDiscovery() {
  this._localStorageListener = (event) => {
    if (event.key === 'global-sharing-discovery') {
      try {
        const message = JSON.parse(event.newValue);
        // 处理消息...
      } catch (e) {
        // 忽略解析错误
      }
    }
  };
  
  window.addEventListener('storage', this._localStorageListener);
}
```

### 3. 大文件传输问题

**挑战**：WebRTC数据通道有消息大小限制。

**解决方案**：实现文件分块和流式传输。

```javascript
// 控制发送速率，避免浏览器过载
if (sentChunks % 10 === 0) {
  await new Promise(resolve => setTimeout(resolve, 5));
}
```

### 4. 浏览器兼容性问题

**挑战**：不同浏览器对WebRTC和其他Web API的支持程度不同。

**解决方案**：实现特性检测和渐进式增强。

```javascript
// 检查WebRTC支持
_checkWebRTCSupport() {
  return !!(window.RTCPeerConnection && 
           window.RTCSessionDescription && 
           window.RTCIceCandidate);
}

// 检查Web蓝牙支持
_checkWebBluetoothSupport() {
  return !!(navigator.bluetooth);
}
```

## 性能优化

### 1. 连接管理

为了优化连接管理，我们实现了以下策略：

```javascript
// 定期清理无效连接
_cleanupConnections() {
  for (const [peerId, connection] of this.peerConnections.entries()) {
    if (connection.connectionState === 'failed' || 
        connection.connectionState === 'closed') {
      this.peerConnections.delete(peerId);
      this.dataChannels.delete(peerId);
      console.log(`清理无效连接: ${peerId}`);
    }
  }
}
```

### 2. 数据传输优化

为了提高数据传输效率，我们实现了以下优化：

```javascript
// 优化数据通道配置
const dataChannel = peerConnection.createDataChannel('fileTransfer', {
  ordered: false,  // 无序传输，类似UDP
  maxRetransmits: 0,  // 不重传，提高实时性
  priority: 'high'  // 高优先级
});
```

### 3. 内存管理

为了避免内存泄漏，我们实现了资源清理：

```dart
/// 关闭服务
void dispose() {
  // 清理JavaScript资源
  if (_initialized) {
    js_util.callMethod(
      js_util.getProperty(html.window, 'flutterP2PNetwork'),
      'dispose',
      []
    );
  }
  
  // 清理Dart资源
  _connectionController.close();
  _fileMap.clear();
}
```

## 安全考虑

### 1. 数据安全

虽然点对点通信本身提供了一定的安全性，但我们仍然实现了额外的安全措施：

```javascript
// 实现简单的数据验证
_validateData(data) {
  // 检查数据完整性
  if (!data || typeof data !== 'object') {
    return false;
  }
  
  // 检查必要字段
  if (!data.type || !data.timestamp) {
    return false;
  }
  
  // 检查时间戳（防止重放攻击）
  const now = Date.now();
  if (now - data.timestamp > 30000) { // 30秒过期
    return false;
  }
  
  return true;
}
```

### 2. 用户授权

确保用户明确授权所有操作：

```javascript
// 请求用户授权
async requestUserPermission(operation) {
  return new Promise((resolve) => {
    const message = `应用请求执行以下操作: ${operation}`;
    
    if (confirm(message)) {
      resolve(true);
    } else {
      resolve(false);
    }
  });
}
```

## 未来改进

### 1. WebTransport支持

计划添加WebTransport支持，提供更高效的数据传输：

```javascript
// WebTransport实现（计划中）
async _initWebTransport() {
  if (!window.WebTransport) {
    return false;
  }
  
  try {
    const transport = new WebTransport('https://example.com/wt');
    await transport.ready;
    
    const writable = await transport.createUnidirectionalStream();
    const writer = writable.getWriter();
    
    // 使用WebTransport发送数据
    // ...
    
    return true;
  } catch (e) {
    console.error('WebTransport初始化失败:', e);
    return false;
  }
}
```

### 2. 端到端加密

计划实现端到端加密，进一步增强数据安全性：

```javascript
// 端到端加密实现（计划中）
async _encryptData(data) {
  // 使用Web Crypto API
  const encoder = new TextEncoder();
  const dataBuffer = encoder.encode(JSON.stringify(data));
  
  // 生成加密密钥
  const key = await window.crypto.subtle.generateKey(
    {
      name: 'AES-GCM',
      length: 256
    },
    true,
    ['encrypt', 'decrypt']
  );
  
  // 加密数据
  const iv = window.crypto.getRandomValues(new Uint8Array(12));
  const encryptedData = await window.crypto.subtle.encrypt(
    {
      name: 'AES-GCM',
      iv
    },
    key,
    dataBuffer
  );
  
  // 返回加密结果
  return {
    encryptedData,
    iv,
    key
  };
}
```

### 3. 多对多文件传输

计划实现基于WebRTC-SFU的多对多文件传输：

```javascript
// 多对多文件传输（计划中）
class P2PGroup {
  constructor(groupId) {
    this.groupId = groupId;
    this.members = new Set();
    this.messages = [];
  }
  
  addMember(peerId) {
    this.members.add(peerId);
  }
  
  removeMember(peerId) {
    this.members.delete(peerId);
  }
  
  async broadcastToGroup(data) {
    const promises = [];
    
    for (const peerId of this.members) {
      if (peerId !== this.localId) {
        promises.push(this.sendToPeer(peerId, data));
      }
    }
    
    return Promise.all(promises);
  }
}
```

## 结论

无中继服务器Web文件传输方案通过创新的技术组合，成功实现了在Web平台上的点对点文件传输。这一方案不仅提高了数据传输的效率和隐私性，还简化了部署和使用流程。

虽然当前实现仍有一些限制，但随着Web平台能力的不断发展，我们有信心在未来实现更多创新功能，进一步增强用户体验。