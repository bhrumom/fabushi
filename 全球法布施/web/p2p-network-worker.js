/**
 * 全球法布施 - P2P网络Worker
 * 
 * 这个Worker实现了在Web平台上的P2P网络功能，
 * 可以在后台运行，不会阻塞主线程。
 */

// 导入P2P网络库
importScripts('p2p-network.js');

// P2P网络实例
let p2pNetwork = null;

// 处理来自主线程的消息
self.addEventListener('message', async (event) => {
  const { type, data } = event.data;
  
  switch (type) {
    case 'init':
      // 初始化P2P网络
      await initP2PNetwork();
      break;
      
    case 'broadcast-file':
      // 广播文件
      await broadcastFile(data.file);
      break;
      
    case 'send-to-peer':
      // 发送文件到特定节点
      await sendFileToPeer(data.file, data.peerId);
      break;
      
    case 'get-status':
      // 获取状态
      sendStatus();
      break;
      
    case 'close':
      // 关闭所有连接
      await closeAllConnections();
      break;
  }
});

/**
 * 初始化P2P网络
 */
async function initP2PNetwork() {
  try {
    if (!self.p2pNetwork) {
      self.postMessage({
        type: 'init-result',
        success: false,
        message: 'P2P网络库未加载'
      });
      return;
    }
    
    p2pNetwork = self.p2pNetwork;
    const result = await p2pNetwork.initialize();
    
    self.postMessage({
      type: 'init-result',
      success: result,
      connectedPeers: p2pNetwork.getConnectedPeersCount()
    });
    
    // 开始定期发送状态更新
    setInterval(sendStatus, 3000);
  } catch (error) {
    self.postMessage({
      type: 'init-result',
      success: false,
      message: error.message
    });
  }
}

/**
 * 广播文件
 */
async function broadcastFile(file) {
  try {
    if (!p2pNetwork) {
      self.postMessage({
        type: 'broadcast-result',
        success: false,
        message: 'P2P网络未初始化'
      });
      return;
    }
    
    const result = await p2pNetwork.broadcastFile(file);
    
    self.postMessage({
      type: 'broadcast-result',
      success: result.success,
      sentCount: result.sentCount,
      dataSentInMB: result.dataSentInMB,
      details: result.results
    });
  } catch (error) {
    self.postMessage({
      type: 'broadcast-result',
      success: false,
      message: error.message
    });
  }
}

/**
 * 发送文件到特定节点
 */
async function sendFileToPeer(file, peerId) {
  try {
    if (!p2pNetwork) {
      self.postMessage({
        type: 'send-result',
        success: false,
        message: 'P2P网络未初始化'
      });
      return;
    }
    
    const result = await p2pNetwork.sendFileToPeer(file, peerId);
    
    self.postMessage({
      type: 'send-result',
      success: result.success,
      sentChunks: result.sentChunks,
      dataSentInMB: result.dataSentInMB
    });
  } catch (error) {
    self.postMessage({
      type: 'send-result',
      success: false,
      message: error.message
    });
  }
}

/**
 * 发送状态更新
 */
function sendStatus() {
  try {
    if (!p2pNetwork) {
      return;
    }
    
    const connectedPeers = p2pNetwork.getConnectedPeersCount();
    const connectedPeerIds = p2pNetwork.getConnectedPeerIds();
    
    self.postMessage({
      type: 'status-update',
      connectedPeers,
      connectedPeerIds
    });
  } catch (error) {
    self.postMessage({
      type: 'error',
      message: error.message
    });
  }
}

/**
 * 关闭所有连接
 */
async function closeAllConnections() {
  try {
    if (!p2pNetwork) {
      return;
    }
    
    p2pNetwork.closeAllConnections();
    
    self.postMessage({
      type: 'close-result',
      success: true
    });
  } catch (error) {
    self.postMessage({
      type: 'close-result',
      success: false,
      message: error.message
    });
  }
}

// 向主线程发送Worker已准备就绪的消息
self.postMessage({
  type: 'worker-ready'
});