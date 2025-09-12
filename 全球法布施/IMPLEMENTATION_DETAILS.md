# 全球法布施 - 无中继服务器实现细节

本文档详细介绍了全球法布施应用中无中继服务器Web文件传输方案的技术实现细节，供开发者参考。

## 系统架构

整个系统由以下几个主要组件组成：

1. **Flutter Web应用** - 提供用户界面和业务逻辑
2. **P2P网络层** - 处理点对点连接和通信
3. **Service Worker** - 拦截和处理网络请求
4. **JavaScript桥接层** - 连接Flutter和Web API

### 架构图

```
+---------------------+     +---------------------+
|   Flutter Web App   |     |   Flutter Web App   |
|   (设备A)           |     |   (设备B)           |
+----------+----------+     +----------+----------+
           |                            |
           v                            v
+----------+----------+     +----------+----------+
|  JavaScript Bridge  |     |  JavaScript Bridge  |
+----------+----------+     +----------+----------+
           |                            |
           v                            v
+----------+----------+     +----------+----------+
|    P2P Network      |<--->|    P2P Network      |
+----------+----------+     +----------+----------+
           |                            |
           v                            v
+----------+----------+     +----------+----------+
| Service Worker      |     | Service Worker      |
+---------------------+     +---------------------+
```

## 核心组件实现

### 1. P2P网络层

P2P网络层负责建立和管理点对点连接，实现在`p2p-network.js`中：

```javascript
class P2PNetwork {
  constructor() {
    // 生成唯一ID
    this.localId = this._generatePeerId();
    
    // 存储连接信息
    this.peerConnections = new Map();
    this.dataChannels = new Map();
    this.discoveredPeers = new Set();
    
    // 初始化本地发现机制
    this._initDiscovery();
  }
  
  // 初始化本地发现机制
  _initDiscovery() {
    // 使用BroadcastChannel作为主要发现通道
    try {
      this.broadcastChannel = new BroadcastChannel('global-sharing-discovery');
      
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
      
      // 广播自己的存在
      this._announceSelf();
    } catch (e) {
      console.warn('BroadcastChannel不可用，使用localStorage作为备选', e);
      this._initLocalStorageDiscovery();
    }
  }
  
  // 使用localStorage作为备选发现机制
  _initLocalStorageDiscovery() {
    this._localStorageListener = (event) => {
      if (event.key === 'global-sharing-discovery') {
        try {
          const message = JSON.parse(event.newValue);
          const { type, peerId, data } = message;
          
          if (type === 'peer-announce' && peerId !== this.localId) {
            console.log(`通过localStorage发现新节点: ${peerId}`);
            this.discoveredPeers.add(peerId);
            this._connectToPeer(peerId);
          } else if (type === 'webrtc-signal' && data.target === this.localId) {
            this._handleSignalingMessage(data);
          }
        } catch (e) {
          // 忽略解析错误
        }
      }
    };
    
    window.addEventListener('storage', this._localStorageListener);
    
    // 广播自己的存在
    this._announceSelfViaLocalStorage();
  }
  
  // 连接到对等节点
  async _connectToPeer(peerId) {
    if (this.peerConnections.has(peerId)) {
      return; // 已经连接或正在连接
    }
    
    console.log(`尝试连接到节点: ${peerId}`);
    
    // 创建RTCPeerConnection
    const peerConnection = new RTCPeerConnection({
      iceServers: [
        { urls: 'stun:stun.l.google.com:19302' }
      ]
    });
    
    this.peerConnections.set(peerId, peerConnection);
    
    // 创建数据通道
    const dataChannel = peerConnection.createDataChannel('fileTransfer', {
      ordered: false,
      maxRetransmits: 0
    });
    
    this._setupDataChannel(dataChannel, peerId);
    this.dataChannels.set(peerId, dataChannel);
    
    // 处理ICE候选
    peerConnection.onicecandidate = (event) => {
      if (event.candidate) {
        this._sendSignalingMessage({
          type: 'ice-candidate',
          candidate: event.candidate,
          source: this.localId,
          target: peerId
        });
      }
    };
    
    // 创建和发送提议
    try {
      const offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);
      
      this._sendSignalingMessage({
        type: 'offer',
        offer: peerConnection.localDescription,
        source: this.localId,
        target: peerId
      });
    } catch (e) {
      console.error(`创建提议时出错: ${e}`);
      this.peerConnections.delete(peerId);
    }
  }
  
  // 处理信令消息
  async _handleSignalingMessage(data) {
    const { type, source, target } = data;
    
    if (target !== this.localId) {
      return; // 不是发给我的消息
    }
    
    console.log(`收到来自 ${source} 的信令消息: ${type}`);
    
    let peerConnection = this.peerConnections.get(source);
    
    // 如果是提议但还没有连接，创建新连接
    if (type === 'offer' && !peerConnection) {
      peerConnection = new RTCPeerConnection({
        iceServers: [
          { urls: 'stun:stun.l.google.com:19302' }
        ]
      });
      
      this.peerConnections.set(source, peerConnection);
      
      // 处理数据通道
      peerConnection.ondatachannel = (event) => {
        const dataChannel = event.channel;
        this._setupDataChannel(dataChannel, source);
        this.dataChannels.set(source, dataChannel);
      };
      
      // 处理ICE候选
      peerConnection.onicecandidate = (event) => {
        if (event.candidate) {
          this._sendSignalingMessage({
            type: 'ice-candidate',
            candidate: event.candidate,
            source: this.localId,
            target: source
          });
        }
      };
    }
    
    try {
      if (type === 'offer') {
        await peerConnection.setRemoteDescription(new RTCSessionDescription(data.offer));
        const answer = await peerConnection.createAnswer();
        await peerConnection.setLocalDescription(answer);
        
        this._sendSignalingMessage({
          type: 'answer',
          answer: peerConnection.localDescription,
          source: this.localId,
          target: source
        });
      } else if (type === 'answer') {
        await peerConnection.setRemoteDescription(new RTCSessionDescription(data.answer));
      } else if (type === 'ice-candidate') {
        await peerConnection.addIceCandidate(new RTCIceCandidate(data.candidate));
      }
    } catch (e) {
      console.error(`处理信令消息时出错: ${e}`);
    }
  }
  
  // 设置数据通道
  _setupDataChannel(dataChannel, peerId) {
    dataChannel.onopen = () => {
      console.log(`与节点 ${peerId} 的数据通道已打开`);
      this._notifyConnectionChanged();
    };
    
    dataChannel.onclose = () => {
      console.log(`与节点 ${peerId} 的数据通道已关闭`);
      this.dataChannels.delete(peerId);
      this._notifyConnectionChanged();
    };
    
    dataChannel.onerror = (error) => {
      console.error(`数据通道错误: ${error}`);
    };
    
    dataChannel.onmessage = (event) => {
      this._handleDataChannelMessage(event.data, peerId);
    };
  }
  
  // 发送文件
  async sendFile(file, peerId) {
    if (!this.dataChannels.has(peerId)) {
      throw new Error(`没有到节点 ${peerId} 的连接`);
    }
    
    const dataChannel = this.dataChannels.get(peerId);
    if (dataChannel.readyState !== 'open') {
      throw new Error(`到节点 ${peerId} 的数据通道未打开`);
    }
    
    // 读取文件
    const fileBuffer = await file.arrayBuffer();
    const fileName = file.name;
    const fileSize = file.size;
    
    console.log(`准备发送文件: ${fileName}, 大小: ${fileSize} 字节, 到节点: ${peerId}`);
    
    // 发送文件元数据
    const metaData = JSON.stringify({
      type: 'FILE_META',
      name: fileName,
      size: fileSize,
      timestamp: Date.now()
    });
    
    dataChannel.send(metaData);
    
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
      
      // 控制发送速率
      if (sentChunks % 10 === 0) {
        await new Promise(resolve => setTimeout(resolve, 5));
      }
    }
    
    // 发送结束标记
    const endMarker = JSON.stringify({
      type: 'FILE_END',
      name: fileName,
      timestamp: Date.now()
    });
    
    dataChannel.send(endMarker);
    console.log(`文件发送完成: ${fileName}, 发送到节点: ${peerId}`);
    
    return {
      success: true,
      sentChunks,
      dataSentInMB: fileBuffer.byteLength / (1024 * 1024)
    };
  }
  
  // 广播文件到所有连接的节点
  async broadcastFile(file) {
    const results = [];
    const peerIds = Array.from(this.dataChannels.keys());
    
    if (peerIds.length === 0) {
      return {
        success: false,
        message: '没有连接的节点'
      };
    }
    
    console.log(`广播文件到 ${peerIds.length} 个节点`);
    
    for (const peerId of peerIds) {
      try {
        const result = await this.sendFile(file, peerId);
        results.push({ peerId, ...result });
      } catch (e) {
        console.error(`向节点 ${peerId} 发送文件时出错: ${e}`);
        results.push({ peerId, success: false, error: e.message });
      }
    }
    
    const successCount = results.filter(r => r.success).length;
    const totalSentMB = results.reduce((sum, r) => sum + (r.dataSentInMB || 0), 0);
    
    return {
      success: successCount > 0,
      sentCount: successCount,
      dataSentInMB: totalSentMB,
      details: results
    };
  }
}
```

### 2. Service Worker实现

Service Worker负责拦截和处理网络请求，实现在`service-worker.js`中：

```javascript
// 安装Service Worker
self.addEventListener('install', (event) => {
  console.log('Service Worker 安装中...');
  self.skipWaiting();
});

// 激活Service Worker
self.addEventListener('activate', (event) => {
  console.log('Service Worker 已激活');
  event.waitUntil(clients.claim());
});

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
  
  // 对于其他请求，不做特殊处理
});

// 处理WiFi广播请求
async function handleWifiBroadcast(request) {
  console.log('处理WiFi广播请求');
  
  if (request.method !== 'POST') {
    return new Response(JSON.stringify({ error: '只支持POST请求' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' }
    });
  }
  
  try {
    // 解析请求数据
    const formData = await request.formData();
    const file = formData.get('file');
    const fileName = formData.get('fileName');
    const fileSize = formData.get('fileSize');
    
    if (!file) {
      return new Response(JSON.stringify({ error: '未提供文件' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }
    
    // 使用P2P网络广播文件
    const message = {
      type: 'broadcast-file',
      file,
      fileName,
      fileSize
    };
    
    // 通过消息通道发送到主线程
    const allClients = await clients.matchAll();
    for (const client of allClients) {
      client.postMessage(message);
    }
    
    return new Response(JSON.stringify({ success: true, message: '文件已广播' }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    });
  } catch (error) {
    console.error('处理WiFi广播请求时出错:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
}

// 处理全球发送请求
async function handleGlobalSend(request) {
  console.log('处理全球发送请求');
  
  if (request.method !== 'POST') {
    return new Response(JSON.stringify({ error: '只支持POST请求' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' }
    });
  }
  
  try {
    // 解析请求数据
    const formData = await request.formData();
    const file = formData.get('file');
    const fileName = formData.get('fileName');
    const fileSize = formData.get('fileSize');
    const country = formData.get('country');
    
    if (!file) {
      return new Response(JSON.stringify({ error: '未提供文件' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }
    
    // 使用P2P网络发送文件
    const message = {
      type: 'global-send-file',
      file,
      fileName,
      fileSize,
      country
    };
    
    // 通过消息通道发送到主线程
    const allClients = await clients.matchAll();
    for (const client of allClients) {
      client.postMessage(message);
    }
    
    return new Response(JSON.stringify({ success: true, message: '文件已发送' }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    });
  } catch (error) {
    console.error('处理全球发送请求时出错:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
}
```

### 3. Flutter与JavaScript桥接

Flutter与JavaScript的桥接实现在`p2p_network_service.dart`中：

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:js/js_util.dart' as js_util;
import 'dart:html' as html;

/// P2P网络服务
/// 
/// 这个服务负责在Web平台上管理P2P网络功能，
/// 包括节点发现、连接管理和文件传输。
class P2PNetworkService {
  static final P2PNetworkService _instance = P2PNetworkService._internal();
  factory P2PNetworkService() => _instance;
  
  bool _initialized = false;
  bool get isInitialized => _initialized;
  
  bool _webrtcSupported = false;
  bool get isWebRTCSupported => _webrtcSupported;
  
  int _connectedPeersCount = 0;
  int get connectedPeersCount => _connectedPeersCount;
  
  List<String> _connectedPeerIds = [];
  List<String> get connectedPeerIds => List.unmodifiable(_connectedPeerIds);
  
  // 文件ID映射
  final Map<String, PlatformFile> _fileMap = {};
  
  // 创建一个流控制器来监听连接变化
  final _connectionController = StreamController<int>.broadcast();
  Stream<int> get onConnectionChanged => _connectionController.stream;
  
  P2PNetworkService._internal();
  
  /// 初始化P2P网络服务
  Future<bool> initialize() async {
    if (!kIsWeb) {
      debugPrint('P2P网络服务仅在Web平台上可用');
      return false;
    }
    
    if (_initialized) {
      debugPrint('P2P网络服务已初始化');
      return true;
    }
    
    debugPrint('正在初始化P2P网络服务...');
    
    try {
      // 确保p2p-network.js已加载
      await _ensureScriptLoaded('p2p-network.js');
      
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
      _webrtcSupported = js_util.getProperty(result, 'webrtcSupported');
      _connectedPeersCount = js_util.getProperty(result, 'connectedPeers');
      
      final peerIds = js_util.getProperty(result, 'peerIds');
      _connectedPeerIds = List<String>.from(js_util.dartify(peerIds));
      
      // 设置连接变化监听器
      js_util.setProperty(html.window, 'onP2PConnectionChanged', js_util.allowInterop((count, peerIds) {
        _connectedPeersCount = count;
        _connectedPeerIds = List<String>.from(js_util.dartify(peerIds));
        _connectionController.add(count);
      }));
      
      debugPrint('P2P网络服务初始化完成');
      debugPrint('WebRTC支持: $_webrtcSupported');
      debugPrint('已连接节点数: $_connectedPeersCount');
      
      _initialized = true;
      return success;
    } catch (e) {
      debugPrint('初始化P2P网络服务时出错: $e');
      return false;
    }
  }
  
  /// 确保JavaScript脚本已加载
  Future<void> _ensureScriptLoaded(String scriptPath) async {
    final completer = Completer<void>();
    
    // 检查脚本是否已加载
    final scripts = html.document.querySelectorAll('script');
    for (final script in scripts) {
      if (script.src.contains(scriptPath)) {
        completer.complete();
        return completer.future;
      }
    }
    
    // 加载脚本
    final script = html.ScriptElement()
      ..src = scriptPath
      ..type = 'text/javascript';
    
    script.onLoad.listen((event) {
      debugPrint('脚本已加载: $scriptPath');
      completer.complete();
    });
    
    script.onError.listen((event) {
      debugPrint('加载脚本时出错: $scriptPath');
      completer.completeError('加载脚本失败: $scriptPath');
    });
    
    html.document.head!.append(script);
    return completer.future;
  }
  
  /// 注册文件
  String _registerFile(PlatformFile file) {
    if (!_initialized) {
      debugPrint('P2P网络服务未初始化');
      return '';
    }
    
    // 生成唯一ID
    final fileId = 'file_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
    
    // 存储文件引用
    _fileMap[fileId] = file;
    
    // 创建JavaScript File对象
    final jsFile = html.File(
      [file.bytes!],
      file.name,
      {'type': _getMimeType(file.name)}
    );
    
    // 注册到JavaScript
    js_util.callMethod(
      html.window,
      'registerFileForP2P',
      [fileId, jsFile]
    );
    
    debugPrint('已注册文件: ${file.name}, ID: $fileId');
    return fileId;
  }
  
  /// 取消注册文件
  void _unregisterFile(String fileId) {
    if (!_initialized || fileId.isEmpty) {
      return;
    }
    
    // 从JavaScript取消注册
    js_util.callMethod(
      html.window,
      'unregisterFileForP2P',
      [fileId]
    );
    
    // 从本地映射中移除
    _fileMap.remove(fileId);
    
    debugPrint('已取消注册文件ID: $fileId');
  }
  
  /// 广播文件
  Future<Map<String, dynamic>> broadcastFile(PlatformFile file) async {
    if (!_initialized) {
      return {'success': false, 'message': 'P2P网络服务未初始化'};
    }
    
    if (_connectedPeersCount == 0) {
      return {'success': false, 'message': '没有连接的节点'};
    }
    
    try {
      // 注册文件
      final fileId = _registerFile(file);
      if (fileId.isEmpty) {
        return {'success': false, 'message': '注册文件失败'};
      }
      
      // 调用JavaScript广播文件
      final result = await js_util.promiseToFuture(
        js_util.callMethod(
          js_util.getProperty(html.window, 'flutterP2PNetwork'),
          'broadcastFile',
          [fileId]
        )
      );
      
      // 取消注册文件
      _unregisterFile(fileId);
      
      // 解析结果
      final success = js_util.getProperty(result, 'success');
      
      if (success) {
        final sentCount = js_util.getProperty(result, 'sentCount');
        final dataSentInMB = js_util.getProperty(result, 'dataSentInMB');
        
        return {
          'success': true,
          'sentCount': sentCount,
          'dataSentInMB': dataSentInMB
        };
      } else {
        final message = js_util.getProperty(result, 'message');
        return {'success': false, 'message': message};
      }
    } catch (e) {
      debugPrint('广播文件时出错: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
  
  /// 获取MIME类型
  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'html':
      case 'htm':
        return 'text/html';
      case 'css':
        return 'text/css';
      case 'js':
        return 'application/javascript';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'application/xml';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      case 'mp3':
        return 'audio/mpeg';
      case 'mp4':
        return 'video/mp4';
      case 'wav':
        return 'audio/wav';
      case 'avi':
        return 'video/x-msvideo';
      case 'mov':
        return 'video/quicktime';
      default:
        return 'application/octet-stream';
    }
  }
  
  /// 关闭服务
  void dispose() {
    _connectionController.close();
  }
}
```

## 关键技术点详解

### 1. 去中心化信令机制

传统WebRTC需要中央信令服务器进行连接协商，我们的方案使用浏览器内置API作为本地信令通道：

```javascript
// 使用BroadcastChannel广播信令消息
_sendSignalingMessage(message) {
  if (this.broadcastChannel) {
    this.broadcastChannel.postMessage({
      type: 'webrtc-signal',
      peerId: this.localId,
      data: message
    });
  } else {
    // 使用localStorage作为备选
    const storageMessage = {
      type: 'webrtc-signal',
      peerId: this.localId,
      data: message,
      timestamp: Date.now()
    };
    
    localStorage.setItem('global-sharing-discovery', JSON.stringify(storageMessage));
    // 触发storage事件
    setTimeout(() => {
      localStorage.removeItem('global-sharing-discovery');
    }, 10);
  }
}
```

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