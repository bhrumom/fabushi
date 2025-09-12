/**
 * 全球法布施 - 直接模式JavaScript库
 * 
 * 这个库提供了在Web平台上直接访问网络功能的方法，
 * 无需依赖中继服务器。它使用现代Web API实现类似于
 * 原生应用的网络功能。
 */

class DirectModeManager {
  constructor() {
    this.isWebRTCSupported = this._checkWebRTCSupport();
    this.isWebBluetoothSupported = this._checkWebBluetoothSupport();
    this.isWebTransportSupported = this._checkWebTransportSupport();
    this.isWebUSBSupported = this._checkWebUSBSupport();
    
    this.peerConnections = [];
    this.dataChannels = [];
    this.bluetoothDevices = [];
    
    console.log('直接模式管理器初始化完成');
    console.log(`WebRTC支持: ${this.isWebRTCSupported}`);
    console.log(`Web蓝牙支持: ${this.isWebBluetoothSupported}`);
    console.log(`WebTransport支持: ${this.isWebTransportSupported}`);
    console.log(`WebUSB支持: ${this.isWebUSBSupported}`);
  }
  
  /**
   * 检查WebRTC支持
   */
  _checkWebRTCSupport() {
    return !!(window.RTCPeerConnection && 
             window.RTCSessionDescription && 
             window.RTCIceCandidate);
  }
  
  /**
   * 检查Web蓝牙支持
   */
  _checkWebBluetoothSupport() {
    return !!(navigator.bluetooth);
  }
  
  /**
   * 检查WebTransport支持
   */
  _checkWebTransportSupport() {
    return !!(window.WebTransport);
  }
  
  /**
   * 检查WebUSB支持
   */
  _checkWebUSBSupport() {
    return !!(navigator.usb);
  }
  
  /**
   * 创建WebRTC点对点连接
   */
  async createP2PConnection() {
    if (!this.isWebRTCSupported) {
      throw new Error('此浏览器不支持WebRTC');
    }
    
    try {
      // 创建RTCPeerConnection
      const configuration = {
        iceServers: [
          { urls: 'stun:stun.l.google.com:19302' }
        ]
      };
      
      const peerConnection = new RTCPeerConnection(configuration);
      
      // 创建数据通道
      const dataChannelOptions = {
        ordered: false,  // 无序传输，类似UDP
        maxRetransmits: 0  // 不重传，提高实时性
      };
      
      const dataChannel = peerConnection.createDataChannel('fileTransfer', dataChannelOptions);
      
      // 设置数据通道事件监听器
      dataChannel.onopen = (event) => {
        console.log('数据通道已打开，可以开始传输文件');
      };
      
      dataChannel.onclose = (event) => {
        console.log('数据通道已关闭');
      };
      
      dataChannel.onerror = (error) => {
        console.error('数据通道错误:', error);
      };
      
      // 存储连接和数据通道
      this.peerConnections.push(peerConnection);
      this.dataChannels.push(dataChannel);
      
      console.log('已创建WebRTC点对点连接');
      return { peerConnection, dataChannel };
    } catch (error) {
      console.error('创建WebRTC点对点连接时出错:', error);
      throw error;
    }
  }
  
  /**
   * 通过WebRTC发送文件
   */
  async sendFileViaWebRTC(file) {
    if (this.dataChannels.length === 0) {
      throw new Error('没有可用的WebRTC数据通道');
    }
    
    const dataChannel = this.dataChannels[0];
    if (dataChannel.readyState !== 'open') {
      throw new Error('WebRTC数据通道未打开');
    }
    
    try {
      // 读取文件
      const fileBuffer = await file.arrayBuffer();
      const fileName = file.name;
      const fileSize = file.size;
      
      console.log(`准备通过WebRTC发送文件: ${fileName}, 大小: ${fileSize} 字节`);
      
      // 发送文件元数据
      const metaData = JSON.stringify({
        type: 'FILE_META',
        name: fileName,
        size: fileSize,
        timestamp: Date.now()
      });
      
      dataChannel.send(metaData);
      console.log('已发送文件元数据');
      
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
        
        if (sentChunks % 100 === 0 || sentChunks < 10) {
          const progress = (sentChunks / totalChunks * 100).toFixed(1);
          console.log(`WebRTC块 ${sentChunks}/${totalChunks} 发送成功 (${progress}%)`);
        }
        
        // 控制发送速率，避免浏览器过载
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
      console.log('WebRTC文件发送完成');
      
      return {
        sentChunks,
        dataSentInMB: fileBuffer.byteLength / (1024 * 1024)
      };
    } catch (error) {
      console.error('通过WebRTC发送文件时出错:', error);
      throw error;
    }
  }
  
  /**
   * 请求连接蓝牙设备
   */
  async requestBluetoothDevice() {
    if (!this.isWebBluetoothSupported) {
      throw new Error('此浏览器不支持Web蓝牙');
    }
    
    try {
      // 示例UUID，实际应用中应使用特定服务的UUID
      const SERVICE_UUID = '0000180f-0000-1000-8000-00805f9b34fb';
      
      const device = await navigator.bluetooth.requestDevice({
        filters: [
          { services: [SERVICE_UUID] }
        ],
        optionalServices: [SERVICE_UUID]
      });
      
      console.log(`已连接到蓝牙设备: ${device.name}`);
      this.bluetoothDevices.push(device);
      
      return device;
    } catch (error) {
      console.error('请求蓝牙设备时出错:', error);
      throw error;
    }
  }
  
  /**
   * 通过Web蓝牙发送文件
   */
  async sendFileViaBluetooth(file, device) {
    if (!device) {
      throw new Error('未提供蓝牙设备');
    }
    
    try {
      // 连接到GATT服务器
      const SERVICE_UUID = '0000180f-0000-1000-8000-00805f9b34fb';
      const CHARACTERISTIC_UUID = '00002a19-0000-1000-8000-00805f9b34fb';
      
      console.log('连接到GATT服务器...');
      const server = await device.gatt.connect();
      
      console.log('获取主服务...');
      const service = await server.getPrimaryService(SERVICE_UUID);
      
      console.log('获取特征...');
      const characteristic = await service.getCharacteristic(CHARACTERISTIC_UUID);
      
      // 读取文件
      const fileBuffer = await file.arrayBuffer();
      const fileName = file.name;
      const fileSize = file.size;
      
      console.log(`准备通过蓝牙发送文件: ${fileName}, 大小: ${fileSize} 字节`);
      
      // 发送文件元数据
      const metaData = JSON.stringify({
        type: 'FILE_META',
        name: fileName,
        size: fileSize,
        timestamp: Date.now()
      });
      
      const metaDataBytes = new TextEncoder().encode(metaData);
      await characteristic.writeValue(metaDataBytes);
      console.log('已发送文件元数据');
      
      // 分块发送文件
      const chunkSize = 512; // 蓝牙MTU通常较小
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
        
        await characteristic.writeValue(fullPacket);
        sentChunks++;
        
        if (sentChunks % 50 === 0 || sentChunks < 10) {
          const progress = (sentChunks / totalChunks * 100).toFixed(1);
          console.log(`蓝牙块 ${sentChunks}/${totalChunks} 发送成功 (${progress}%)`);
        }
        
        // 控制发送速率，避免蓝牙堆栈过载
        await new Promise(resolve => setTimeout(resolve, 50));
      }
      
      // 发送结束标记
      const endMarker = JSON.stringify({
        type: 'FILE_END',
        name: fileName,
        timestamp: Date.now()
      });
      
      const endMarkerBytes = new TextEncoder().encode(endMarker);
      await characteristic.writeValue(endMarkerBytes);
      console.log('蓝牙文件发送完成');
      
      return {
        sentChunks,
        dataSentInMB: fileBuffer.byteLength / (1024 * 1024)
      };
    } catch (error) {
      console.error('通过蓝牙发送文件时出错:', error);
      throw error;
    }
  }
  
  /**
   * 创建本地网络发现
   */
  async createLocalDiscovery() {
    // 这里应该实现本地网络发现逻辑
    // 由于浏览器限制，这通常需要一个信令服务器
    
    console.log('本地网络发现功能尚未实现');
    return [];
  }
  
  /**
   * 关闭所有连接
   */
  closeAllConnections() {
    // 关闭WebRTC连接
    for (const dataChannel of this.dataChannels) {
      try {
        dataChannel.close();
      } catch (error) {
        // 忽略关闭错误
      }
    }
    
    for (const peerConnection of this.peerConnections) {
      try {
        peerConnection.close();
      } catch (error) {
        // 忽略关闭错误
      }
    }
    
    this.dataChannels = [];
    this.peerConnections = [];
    
    // 断开蓝牙设备
    for (const device of this.bluetoothDevices) {
      try {
        if (device.gatt && device.gatt.connected) {
          device.gatt.disconnect();
        }
      } catch (error) {
        // 忽略断开错误
      }
    }
    
    this.bluetoothDevices = [];
    
    console.log('已关闭所有连接');
  }
}

// 创建全局实例
window.directModeManager = new DirectModeManager();

// 导出到Flutter
window.flutterDirectMode = {
  /**
   * 初始化直接模式
   */
  initialize: function() {
    console.log('从Flutter初始化直接模式');
    return {
      webrtcSupported: window.directModeManager.isWebRTCSupported,
      bluetoothSupported: window.directModeManager.isWebBluetoothSupported,
      webTransportSupported: window.directModeManager.isWebTransportSupported,
      webUSBSupported: window.directModeManager.isWebUSBSupported
    };
  },
  
  /**
   * 创建WebRTC连接
   */
  createWebRTCConnection: async function() {
    try {
      const result = await window.directModeManager.createP2PConnection();
      return {
        success: true,
        message: '已创建WebRTC连接'
      };
    } catch (error) {
      return {
        success: false,
        message: error.message
      };
    }
  },
  
  /**
   * 通过WebRTC发送文件
   */
  sendFileViaWebRTC: async function(fileId) {
    try {
      // 从Flutter传递的fileId获取文件
      // 这里需要实现文件传递机制
      const file = window._flutterFileMap[fileId];
      if (!file) {
        throw new Error(`找不到ID为${fileId}的文件`);
      }
      
      const result = await window.directModeManager.sendFileViaWebRTC(file);
      return {
        success: true,
        sentChunks: result.sentChunks,
        dataSentInMB: result.dataSentInMB
      };
    } catch (error) {
      return {
        success: false,
        message: error.message
      };
    }
  },
  
  /**
   * 请求蓝牙设备
   */
  requestBluetoothDevice: async function() {
    try {
      await window.directModeManager.requestBluetoothDevice();
      return {
        success: true,
        message: '已连接蓝牙设备'
      };
    } catch (error) {
      return {
        success: false,
        message: error.message
      };
    }
  },
  
  /**
   * 通过蓝牙发送文件
   */
  sendFileViaBluetooth: async function(fileId) {
    try {
      // 从Flutter传递的fileId获取文件
      const file = window._flutterFileMap[fileId];
      if (!file) {
        throw new Error(`找不到ID为${fileId}的文件`);
      }
      
      // 使用第一个连接的蓝牙设备
      if (window.directModeManager.bluetoothDevices.length === 0) {
        throw new Error('没有连接的蓝牙设备');
      }
      
      const device = window.directModeManager.bluetoothDevices[0];
      const result = await window.directModeManager.sendFileViaBluetooth(file, device);
      
      return {
        success: true,
        sentChunks: result.sentChunks,
        dataSentInMB: result.dataSentInMB
      };
    } catch (error) {
      return {
        success: false,
        message: error.message
      };
    }
  },
  
  /**
   * 关闭所有连接
   */
  closeAllConnections: function() {
    try {
      window.directModeManager.closeAllConnections();
      return {
        success: true,
        message: '已关闭所有连接'
      };
    } catch (error) {
      return {
        success: false,
        message: error.message
      };
    }
  }
};

// 初始化文件映射
window._flutterFileMap = {};

// 注册文件
window.registerFileForDirectMode = function(fileId, file) {
  window._flutterFileMap[fileId] = file;
  console.log(`已注册文件: ${file.name}, ID: ${fileId}`);
  return true;
};

// 取消注册文件
window.unregisterFileForDirectMode = function(fileId) {
  if (window._flutterFileMap[fileId]) {
    delete window._flutterFileMap[fileId];
    console.log(`已取消注册文件ID: ${fileId}`);
    return true;
  }
  return false;
};

console.log('全球法布施直接模式JavaScript库已加载');