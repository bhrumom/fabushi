/**
 * 全球法布施 - P2P网络JavaScript库
 * 
 * 这个库提供了在Web平台上实现点对点网络通信的功能，
 * 完全不依赖中继服务器。它使用WebRTC和WebRTC-SFU技术
 * 实现分布式网络通信。
 */

class P2PNetwork {
  constructor() {
    this.peers = new Map(); // 存储所有对等连接
    this.dataChannels = new Map(); // 存储所有数据通道
    this.localId = this._generatePeerId(); // 本地节点ID
    this.discoveredPeers = new Set(); // 已发现的对等节点
    this.messageHandlers = new Map(); // 消息处理器
    this.isInitialized = false;
    
    // 注册消息处理器
    this._registerMessageHandlers();
    
    console.log(`P2P网络初始化，本地节点ID: ${this.localId}`);
  }
  
  /**
   * 初始化P2P网络
   */
  async initialize() {
    if (this.isInitialized) {
      return true;
    }
    
    try {
      // 创建本地发现服务
      await this._setupLocalDiscovery();
      
      // 设置WebRTC连接
      await this._setupWebRTC();
      
      this.isInitialized = true;
      console.log('P2P网络初始化完成');
      return true;
    } catch (error) {
      console.error('初始化P2P网络时出错:', error);
      return false;
    }
  }
  
  /**
   * 设置本地发现服务
   */
  async _setupLocalDiscovery() {
    // 使用mDNS或本地广播发现同一网络中的其他节点
    // 由于浏览器限制，我们使用一个简化的发现机制
    
    // 创建一个BroadcastChannel用于同一浏览器上下文中的通信
    try {
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
      
      // 广播自己的存在
      this._announceSelf();
      
      console.log('本地发现服务已设置');
    } catch (error) {
      console.warn('设置BroadcastChannel失败，尝试替代方法:', error);
      
      // 如果BroadcastChannel不可用，尝试使用localStorage作为替代
      this._setupLocalStorageDiscovery();
    }
    
    // 定期广播自己的存在
    setInterval(() => this._announceSelf(), 5000);
  }
  
  /**
   * 使用localStorage作为发现机制的替代方法
   */
  _setupLocalStorageDiscovery() {
    // 使用localStorage作为通信通道
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
    
    // 广播方法重写
    this._announceSelf = () => {
      const message = {
        type: 'peer-announce',
        peerId: this.localId,
        timestamp: Date.now()
      };
      
      localStorage.setItem('global-sharing-discovery', JSON.stringify(message));
      // 短暂延迟后清除，以便其他标签页能检测到变化
      setTimeout(() => {
        localStorage.removeItem('global-sharing-discovery');
      }, 100);
    };
    
    console.log('使用localStorage作为发现机制');
  }
  
  /**
   * 广播自己的存在
   */
  _announceSelf() {
    if (this.broadcastChannel) {
      this.broadcastChannel.postMessage({
        type: 'peer-announce',
        peerId: this.localId,
        timestamp: Date.now()
      });
    }
  }
  
  /**
   * 设置WebRTC连接
   */
  async _setupWebRTC() {
    // 检查WebRTC支持
    if (!window.RTCPeerConnection) {
      throw new Error('此浏览器不支持WebRTC');
    }
    
    console.log('WebRTC支持已确认');
  }
  
  /**
   * 连接到对等节点
   */
  async _connectToPeer(peerId) {
    if (this.peers.has(peerId)) {
      console.log(`已经连接到节点 ${peerId}`);
      return;
    }
    
    console.log(`尝试连接到节点 ${peerId}`);
    
    try {
      // 创建RTCPeerConnection
      const configuration = {
        iceServers: [
          { urls: 'stun:stun.l.google.com:19302' }
        ]
      };
      
      const peerConnection = new RTCPeerConnection(configuration);
      
      // 创建数据通道
      const dataChannel = peerConnection.createDataChannel('fileTransfer', {
        ordered: true
      });
      
      // 设置数据通道事件
      this._setupDataChannel(dataChannel, peerId);
      
      // 存储连接
      this.peers.set(peerId, peerConnection);
      
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
      
      // 监听连接状态
      peerConnection.onconnectionstatechange = () => {
        console.log(`与节点 ${peerId} 的连接状态: ${peerConnection.connectionState}`);
        
        if (peerConnection.connectionState === 'disconnected' || 
            peerConnection.connectionState === 'failed' ||
            peerConnection.connectionState === 'closed') {
          this.peers.delete(peerId);
          this.dataChannels.delete(peerId);
          console.log(`与节点 ${peerId} 的连接已关闭`);
        }
      };
      
      // 监听数据通道
      peerConnection.ondatachannel = (event) => {
        console.log(`从节点 ${peerId} 接收到新的数据通道`);
        this._setupDataChannel(event.channel, peerId);
      };
      
      // 创建提议
      const offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);
      
      // 发送提议
      this._sendSignalingMessage({
        type: 'offer',
        offer: peerConnection.localDescription,
        source: this.localId,
        target: peerId
      });
      
      console.log(`已向节点 ${peerId} 发送连接提议`);
    } catch (error) {
      console.error(`连接到节点 ${peerId} 时出错:`, error);
    }
  }
  
  /**
   * 设置数据通道
   */
  _setupDataChannel(dataChannel, peerId) {
    dataChannel.onopen = () => {
      console.log(`与节点 ${peerId} 的数据通道已打开`);
      this.dataChannels.set(peerId, dataChannel);
      
      // 发送问候消息
      this._sendToPeer(peerId, {
        type: 'greeting',
        message: `你好，我是节点 ${this.localId}`
      });
    };
    
    dataChannel.onclose = () => {
      console.log(`与节点 ${peerId} 的数据通道已关闭`);
      this.dataChannels.delete(peerId);
    };
    
    dataChannel.onerror = (error) => {
      console.error(`与节点 ${peerId} 的数据通道错误:`, error);
    };
    
    dataChannel.onmessage = (event) => {
      this._handleDataChannelMessage(event.data, peerId);
    };
  }
  
  /**
   * 处理数据通道消息
   */
  _handleDataChannelMessage(data, peerId) {
    try {
      // 检查是否是二进制数据
      if (data instanceof ArrayBuffer || data instanceof Blob) {
        // 处理二进制数据（文件块）
        this._handleBinaryMessage(data, peerId);
        return;
      }
      
      // 处理JSON消息
      const message = typeof data === 'string' ? JSON.parse(data) : data;
      const handler = this.messageHandlers.get(message.type);
      
      if (handler) {
        handler(message, peerId);
      } else {
        console.log(`收到未知类型消息: ${message.type}`, message);
      }
    } catch (error) {
      console.error('处理数据通道消息时出错:', error);
    }
  }
  
  /**
   * 处理二进制消息
   */
  _handleBinaryMessage(data, peerId) {
    // 这里处理文件块数据
    console.log(`从节点 ${peerId} 接收到二进制数据: ${data.byteLength} 字节`);
    
    // 触发文件块接收事件
    this._triggerEvent('fileChunkReceived', {
      data,
      peerId
    });
  }
  
  /**
   * 发送信令消息
   */
  _sendSignalingMessage(message) {
    if (this.broadcastChannel) {
      this.broadcastChannel.postMessage({
        type: 'webrtc-signal',
        peerId: this.localId,
        data: message
      });
    } else {
      // 使用localStorage作为替代
      const signalMessage = {
        type: 'webrtc-signal',
        peerId: this.localId,
        data: message,
        timestamp: Date.now()
      };
      
      localStorage.setItem('global-sharing-discovery', JSON.stringify(signalMessage));
      // 短暂延迟后清除
      setTimeout(() => {
        localStorage.removeItem('global-sharing-discovery');
      }, 100);
    }
  }
  
  /**
   * 处理信令消息
   */
  async _handleSignalingMessage(data) {
    try {
      const { type, source, target, offer, answer, candidate } = data;
      
      if (target !== this.localId) {
        return; // 不是发给我的消息
      }
      
      console.log(`收到来自节点 ${source} 的信令消息: ${type}`);
      
      let peerConnection = this.peers.get(source);
      
      // 如果是提议但没有连接，创建一个新的连接
      if (type === 'offer' && !peerConnection) {
        const configuration = {
          iceServers: [
            { urls: 'stun:stun.l.google.com:19302' }
          ]
        };
        
        peerConnection = new RTCPeerConnection(configuration);
        
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
        
        // 监听连接状态
        peerConnection.onconnectionstatechange = () => {
          console.log(`与节点 ${source} 的连接状态: ${peerConnection.connectionState}`);
          
          if (peerConnection.connectionState === 'disconnected' || 
              peerConnection.connectionState === 'failed' ||
              peerConnection.connectionState === 'closed') {
            this.peers.delete(source);
            this.dataChannels.delete(source);
            console.log(`与节点 ${source} 的连接已关闭`);
          }
        };
        
        // 监听数据通道
        peerConnection.ondatachannel = (event) => {
          console.log(`从节点 ${source} 接收到新的数据通道`);
          this._setupDataChannel(event.channel, source);
        };
        
        this.peers.set(source, peerConnection);
      }
      
      // 处理不同类型的信令消息
      switch (type) {
        case 'offer':
          await peerConnection.setRemoteDescription(new RTCSessionDescription(offer));
          const answer = await peerConnection.createAnswer();
          await peerConnection.setLocalDescription(answer);
          
          this._sendSignalingMessage({
            type: 'answer',
            answer: peerConnection.localDescription,
            source: this.localId,
            target: source
          });
          break;
          
        case 'answer':
          await peerConnection.setRemoteDescription(new RTCSessionDescription(answer));
          break;
          
        case 'ice-candidate':
          if (candidate) {
            await peerConnection.addIceCandidate(new RTCIceCandidate(candidate));
          }
          break;
      }
    } catch (error) {
      console.error('处理信令消息时出错:', error);
    }
  }
  
  /**
   * 向特定节点发送消息
   */
  _sendToPeer(peerId, message) {
    const dataChannel = this.dataChannels.get(peerId);
    
    if (!dataChannel || dataChannel.readyState !== 'open') {
      console.warn(`无法向节点 ${peerId} 发送消息，数据通道未打开`);
      return false;
    }
    
    try {
      const messageString = typeof message === 'string' ? message : JSON.stringify(message);
      dataChannel.send(messageString);
      return true;
    } catch (error) {
      console.error(`向节点 ${peerId} 发送消息时出错:`, error);
      return false;
    }
  }
  
  /**
   * 向所有连接的节点广播消息
   */
  broadcast(message) {
    let successCount = 0;
    
    for (const peerId of this.dataChannels.keys()) {
      if (this._sendToPeer(peerId, message)) {
        successCount++;
      }
    }
    
    console.log(`广播消息到 ${successCount}/${this.dataChannels.size} 个节点`);
    return successCount;
  }
  
  /**
   * 发送文件到特定节点
   */
  async sendFileToPeer(file, peerId) {
    const dataChannel = this.dataChannels.get(peerId);
    
    if (!dataChannel || dataChannel.readyState !== 'open') {
      throw new Error(`无法向节点 ${peerId} 发送文件，数据通道未打开`);
    }
    
    try {
      // 读取文件
      const fileBuffer = await file.arrayBuffer();
      const fileName = file.name;
      const fileSize = file.size;
      
      console.log(`准备向节点 ${peerId} 发送文件: ${fileName}, 大小: ${fileSize} 字节`);
      
      // 发送文件元数据
      this._sendToPeer(peerId, {
        type: 'file-meta',
        name: fileName,
        size: fileSize,
        timestamp: Date.now()
      });
      
      // 分块发送文件
      const chunkSize = 16384; // 16KB
      const totalChunks = Math.ceil(fileBuffer.byteLength / chunkSize);
      let sentChunks = 0;
      
      for (let i = 0; i < fileBuffer.byteLength; i += chunkSize) {
        if (dataChannel.readyState !== 'open') {
          throw new Error('数据通道已关闭');
        }
        
        const end = Math.min(i + chunkSize, fileBuffer.byteLength);
        const chunk = fileBuffer.slice(i, end);
        
        // 发送块头部
        this._sendToPeer(peerId, {
          type: 'file-chunk',
          name: fileName,
          index: sentChunks,
          total: totalChunks
        });
        
        // 短暂延迟，确保头部和数据不会混淆
        await new Promise(resolve => setTimeout(resolve, 10));
        
        // 发送块数据
        dataChannel.send(chunk);
        sentChunks++;
        
        if (sentChunks % 100 === 0 || sentChunks < 10) {
          const progress = (sentChunks / totalChunks * 100).toFixed(1);
          console.log(`向节点 ${peerId} 发送文件块 ${sentChunks}/${totalChunks} (${progress}%)`);
        }
        
        // 控制发送速率，避免浏览器过载
        if (sentChunks % 10 === 0) {
          await new Promise(resolve => setTimeout(resolve, 5));
        }
      }
      
      // 发送结束标记
      this._sendToPeer(peerId, {
        type: 'file-end',
        name: fileName,
        timestamp: Date.now()
      });
      
      console.log(`向节点 ${peerId} 发送文件完成: ${fileName}`);
      
      return {
        success: true,
        sentChunks,
        dataSentInMB: fileBuffer.byteLength / (1024 * 1024)
      };
    } catch (error) {
      console.error(`向节点 ${peerId} 发送文件时出错:`, error);
      throw error;
    }
  }
  
  /**
   * 广播文件到所有连接的节点
   */
  async broadcastFile(file) {
    const results = [];
    
    for (const peerId of this.dataChannels.keys()) {
      try {
        const result = await this.sendFileToPeer(file, peerId);
        results.push({
          peerId,
          success: true,
          ...result
        });
      } catch (error) {
        results.push({
          peerId,
          success: false,
          error: error.message
        });
      }
    }
    
    const successCount = results.filter(r => r.success).length;
    console.log(`广播文件到 ${successCount}/${this.dataChannels.size} 个节点`);
    
    return {
      success: successCount > 0,
      results,
      sentCount: successCount,
      dataSentInMB: results.reduce((sum, r) => sum + (r.dataSentInMB || 0), 0)
    };
  }
  
  /**
   * 注册消息处理器
   */
  _registerMessageHandlers() {
    // 处理问候消息
    this.messageHandlers.set('greeting', (message, peerId) => {
      console.log(`收到来自节点 ${peerId} 的问候: ${message.message}`);
    });
    
    // 处理文件元数据
    this.messageHandlers.set('file-meta', (message, peerId) => {
      console.log(`收到来自节点 ${peerId} 的文件元数据: ${message.name}, 大小: ${message.size} 字节`);
      
      // 触发文件元数据接收事件
      this._triggerEvent('fileMetaReceived', {
        meta: message,
        peerId
      });
    });
    
    // 处理文件块头部
    this.messageHandlers.set('file-chunk', (message, peerId) => {
      // 触发文件块头部接收事件
      this._triggerEvent('fileChunkHeader', {
        header: message,
        peerId
      });
    });
    
    // 处理文件结束
    this.messageHandlers.set('file-end', (message, peerId) => {
      console.log(`收到来自节点 ${peerId} 的文件结束标记: ${message.name}`);
      
      // 触发文件结束事件
      this._triggerEvent('fileEndReceived', {
        meta: message,
        peerId
      });
    });
  }
  
  /**
   * 触发事件
   */
  _triggerEvent(eventName, data) {
    const event = new CustomEvent(`p2p-${eventName}`, { detail: data });
    window.dispatchEvent(event);
  }
  
  /**
   * 生成对等节点ID
   */
  _generatePeerId() {
    const randomPart = Math.random().toString(36).substring(2, 10);
    const timePart = Date.now().toString(36);
    return `peer-${randomPart}-${timePart}`;
  }
  
  /**
   * 获取连接的节点数量
   */
  getConnectedPeersCount() {
    return this.dataChannels.size;
  }
  
  /**
   * 获取所有连接的节点ID
   */
  getConnectedPeerIds() {
    return Array.from(this.dataChannels.keys());
  }
  
  /**
   * 关闭所有连接
   */
  closeAllConnections() {
    // 关闭所有数据通道
    for (const dataChannel of this.dataChannels.values()) {
      try {
        dataChannel.close();
      } catch (error) {
        // 忽略关闭错误
      }
    }
    
    // 关闭所有对等连接
    for (const peerConnection of this.peers.values()) {
      try {
        peerConnection.close();
      } catch (error) {
        // 忽略关闭错误
      }
    }
    
    // 清空集合
    this.peers.clear();
    this.dataChannels.clear();
    
    // 关闭广播通道
    if (this.broadcastChannel) {
      this.broadcastChannel.close();
    }
    
    // 移除localStorage监听器
    if (this._localStorageListener) {
      window.removeEventListener('storage', this._localStorageListener);
    }
    
    console.log('已关闭所有P2P连接');
  }
}

// 创建全局实例
window.p2pNetwork = new P2PNetwork();

// 导出到Flutter
window.flutterP2PNetwork = {
  /**
   * 初始化P2P网络
   */
  initialize: async function() {
    try {
      const result = await window.p2pNetwork.initialize();
      return {
        success: result,
        connectedPeers: window.p2pNetwork.getConnectedPeersCount()
      };
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  },
  
  /**
   * 获取连接的节点数量
   */
  getConnectedPeersCount: function() {
    return {
      count: window.p2pNetwork.getConnectedPeersCount()
    };
  },
  
  /**
   * 获取连接的节点ID
   */
  getConnectedPeerIds: function() {
    return {
      peerIds: window.p2pNetwork.getConnectedPeerIds()
    };
  },
  
  /**
   * 广播文件
   */
  broadcastFile: async function(fileId) {
    try {
      // 从Flutter传递的fileId获取文件
      const file = window._flutterFileMap[fileId];
      if (!file) {
        throw new Error(`找不到ID为${fileId}的文件`);
      }
      
      const result = await window.p2pNetwork.broadcastFile(file);
      return {
        success: result.success,
        sentCount: result.sentCount,
        dataSentInMB: result.dataSentInMB,
        details: JSON.stringify(result.results)
      };
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  },
  
  /**
   * 关闭所有连接
   */
  closeAllConnections: function() {
    try {
      window.p2pNetwork.closeAllConnections();
      return {
        success: true
      };
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }
};

// 设置文件接收处理
let currentFileReceiving = null;
let currentFileChunks = null;

// 监听文件元数据接收事件
window.addEventListener('p2p-fileMetaReceived', (event) => {
  const { meta, peerId } = event.detail;
  
  console.log(`准备接收来自节点 ${peerId} 的文件: ${meta.name}, 大小: ${meta.size} 字节`);
  
  currentFileReceiving = {
    name: meta.name,
    size: meta.size,
    peerId: peerId,
    chunks: [],
    receivedChunks: 0,
    totalChunks: 0,
    timestamp: meta.timestamp
  };
  
  currentFileChunks = new Map();
});

// 监听文件块头部接收事件
window.addEventListener('p2p-fileChunkHeader', (event) => {
  const { header, peerId } = event.detail;
  
  if (!currentFileReceiving || currentFileReceiving.peerId !== peerId) {
    return;
  }
  
  currentFileReceiving.totalChunks = header.total;
  
  // 准备接收下一个块的数据
  currentFileReceiving.currentChunkIndex = header.index;
});

// 监听文件块数据接收事件
window.addEventListener('p2p-fileChunkReceived', (event) => {
  const { data, peerId } = event.detail;
  
  if (!currentFileReceiving || currentFileReceiving.peerId !== peerId) {
    return;
  }
  
  const index = currentFileReceiving.currentChunkIndex;
  
  // 存储块数据
  currentFileChunks.set(index, data);
  currentFileReceiving.receivedChunks++;
  
  const progress = (currentFileReceiving.receivedChunks / currentFileReceiving.totalChunks * 100).toFixed(1);
  
  if (currentFileReceiving.receivedChunks % 100 === 0 || currentFileReceiving.receivedChunks < 10) {
    console.log(`接收文件 ${currentFileReceiving.name} 进度: ${progress}%`);
  }
});

// 监听文件结束接收事件
window.addEventListener('p2p-fileEndReceived', (event) => {
  const { meta, peerId } = event.detail;
  
  if (!currentFileReceiving || currentFileReceiving.peerId !== peerId) {
    return;
  }
  
  console.log(`文件 ${meta.name} 接收完成，正在组装...`);
  
  // 组装文件
  const chunks = Array.from({ length: currentFileReceiving.totalChunks })
    .map((_, i) => currentFileChunks.get(i))
    .filter(chunk => chunk); // 过滤掉未接收的块
  
  if (chunks.length !== currentFileReceiving.totalChunks) {
    console.warn(`文件 ${meta.name} 接收不完整: ${chunks.length}/${currentFileReceiving.totalChunks} 块`);
  }
  
  // 创建Blob
  const blob = new Blob(chunks);
  
  // 创建下载链接
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = meta.name;
  a.style.display = 'none';
  document.body.appendChild(a);
  a.click();
  
  // 清理
  setTimeout(() => {
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }, 100);
  
  console.log(`文件 ${meta.name} 已保存`);
  
  // 重置状态
  currentFileReceiving = null;
  currentFileChunks = null;
});

console.log('全球法布施P2P网络JavaScript库已加载');