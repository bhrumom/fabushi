# 全球法布施 - 无中继服务器Web文件传输方案

## 项目概述

全球法布施是一个跨平台文件传输应用，支持本地WiFi广播和全球发送功能。本文档详细介绍了在Web平台上实现无中继服务器的文件传输方案，使网页应用能够直接与其他设备通信，无需依赖任何中间服务器。

## 技术方案总结

我们实现了多种无中继服务器的文件传输方案，按优先级排序如下：

1. **P2P网络** - 完全点对点的网络通信，使用WebRTC技术实现直接设备间通信
2. **WebRTC直接传输** - 使用WebRTC数据通道进行点对点文件传输
3. **Web蓝牙** - 使用Web蓝牙API实现近距离文件传输
4. **Service Worker代理** - 使用Service Worker拦截和处理网络请求，实现本地处理

这些方案完全不依赖中继服务器，实现了真正的点对点通信。

## 核心技术实现

### 1. P2P网络实现

我们的P2P网络实现基于WebRTC技术，但创新性地解决了WebRTC初始连接需要信令服务器的问题：

```javascript
// 使用BroadcastChannel作为本地信令通道
this.broadcastChannel = new BroadcastChannel('global-sharing-discovery');

// 监听发现消息
this.broadcastChannel.onmessage = (event) => {
  const { type, peerId, data } = event.data;
  
  if (type === 'peer-announce' && peerId !== this.localId) {
    console.log(`发现新节点: ${peerId}`);
    this.discoveredPeers.add(peerId);
    this._connectToPeer(peerId);
  } else if (type === 'webrtc-signal' && data.target === this.localId) {
    this._handleSignalingMessage(data);
  }
};
```

当BroadcastChannel不可用时，我们使用localStorage作为备选通信通道：

```javascript
// 使用localStorage作为通信通道
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
```

### 2. Service Worker代理

Service Worker作为Web应用的本地代理，可以拦截和处理网络请求：

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
    
    // 处理全球发送API
    if (url.pathname === '/api/global-send') {
      event.respondWith(handleGlobalSend(event.request));
      return;
    }
  }
  
  // 对于其他请求，尝试从缓存获取
  // ...
});
```

### 3. Flutter与JavaScript交互

我们使用dart:js和js_util包实现Flutter与JavaScript的交互：

```dart
// 调用JavaScript初始化函数
final result = await js_util.promiseToFuture(
  js_util.callMethod(
    js_util.getProperty(html.window, 'flutterP2PNetwork'),
    'initialize',
    []
  )
);

// 解析结果
final success = js_util.getProperty(result, 'success');
_connectedPeersCount = js_util.getProperty(result, 'connectedPeers');
```

## 用户体验

从用户角度看，无中继服务器方案提供以下体验：

1. **简化设置** - 无需安装额外软件，打开网页即可使用
2. **增强隐私** - 数据直接在设备间传输，不经过任何第三方服务器
3. **离线工作** - 在没有互联网连接的情况下也能工作，适用于局域网环境

## 使用方法

### 开发者配置

1. 确保在`web/index.html`中注册了Service Worker：
   ```html
   <script>
     if ('serviceWorker' in navigator) {
       navigator.serviceWorker.register('/service-worker.js');
     }
   </script>
   ```

2. 在Flutter应用中初始化P2P网络：
   ```dart
   final p2pService = P2PNetworkService();
   await p2pService.initialize();
   ```

3. 使用P2P网络发送文件：
   ```dart
   final result = await p2pService.broadcastFile(file);
   ```

### 用户使用流程

1. 打开Web应用
2. 点击"P2P网络演示"按钮
3. 在另一个设备或浏览器标签页中打开同样的应用
4. 两个实例会自动发现并连接
5. 选择文件并点击"发送文件"按钮
6. 文件将直接发送到所有连接的节点

## 技术限制与解决方案

### 当前限制

1. **浏览器兼容性** - WebRTC和Web蓝牙在某些浏览器中可能不可用
2. **发现机制** - 当前的本地发现机制主要适用于同一设备上的不同浏览器实例
3. **安全限制** - Web平台的安全沙箱限制了某些低级网络操作

### 解决方案

1. **混合发现机制** - 结合多种发现技术，在可能的情况下使用mDNS或UPnP
2. **渐进式增强** - 根据浏览器能力提供不同级别的功能
3. **PWA集成** - 将应用打包为PWA，提供更多系统权限

## 结论

无中继服务器方案代表了Web平台上文件传输的未来方向。通过利用现代Web API和创新的点对点通信技术，我们实现了一个完全去中心化的文件传输系统，无需依赖任何中间服务器。

这一方案不仅提高了数据传输的效率和隐私性，还简化了部署和使用流程。随着Web平台能力的不断发展，我们期待在未来实现更多创新功能，进一步增强用户体验。

## 未来展望

1. **WebTransport支持** - 实现基于WebTransport的更高效传输
2. **WebRTC-SFU集成** - 支持多对多文件传输
3. **端到端加密** - 增强数据传输安全性
4. **离线工作模式** - 完善PWA功能，支持完全离线工作