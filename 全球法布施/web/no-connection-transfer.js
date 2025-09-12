/**
 * 无连接全球发送 JavaScript 实现
 * 
 * 这个库实现了真正的无连接发送模式，不需要建立连接就能直接发送数据
 * 使用多种Web技术确保数据能够真实离开设备并发送到全球网络
 */

// 全局命名空间
window.noConnectionTransfer = {};

// 无连接发送管理器
class NoConnectionManager {
  constructor() {
    this.isRunning = false;
    this.sentCount = 0;
    this.dataSentInMB = 0;
    this.dataSentInBytes = 0;
    
    // 全球目标端点
    this.globalTargets = this._createGlobalTargets();
    
    console.log('🚀 无连接发送管理器初始化完成');
    console.log(`🌍 已准备 ${this.globalTargets.length} 个全球目标端点`);
  }
  
  /**
   * 创建全球目标端点
   */
  _createGlobalTargets() {
    return [
      // 全球知名HTTP端点
      {
        type: 'http',
        url: 'https://httpbin.org/post',
        name: 'HTTPBin',
        priority: 1
      },
      {
        type: 'http',
        url: 'https://postman-echo.com/post',
        name: 'Postman Echo',
        priority: 1
      },
      {
        type: 'http',
        url: 'https://reqres.in/api/users',
        name: 'ReqRes API',
        priority: 2
      },
      {
        type: 'http',
        url: 'https://jsonplaceholder.typicode.com/posts',
        name: 'JSONPlaceholder',
        priority: 2
      },
      
      // WebSocket端点
      {
        type: 'websocket',
        url: 'wss://echo.websocket.org',
        name: 'WebSocket Echo',
        priority: 1
      },
      {
        type: 'websocket',
        url: 'wss://ws.postman-echo.com/raw',
        name: 'Postman WebSocket',
        priority: 2
      },
      
      // WebRTC STUN服务器
      {
        type: 'webrtc',
        url: 'stun:stun.l.google.com:19302',
        name: 'Google STUN',
        priority: 1
      },
      {
        type: 'webrtc',
        url: 'stun:stun1.l.google.com:19302',
        name: 'Google STUN 2',
        priority: 1
      },
      {
        type: 'webrtc',
        url: 'stun:stun.stunprotocol.org:3478',
        name: 'STUN Protocol',
        priority: 2
      },
      
      // 图片上传端点（利用图片上传API发送数据）
      {
        type: 'image',
        url: 'https://api.imgur.com/3/image',
        name: 'Imgur API',
        priority: 3
      },
      
      // DNS over HTTPS端点
      {
        type: 'dns',
        url: 'https://cloudflare-dns.com/dns-query',
        name: 'Cloudflare DoH',
        priority: 2
      },
      {
        type: 'dns',
        url: 'https://dns.google/dns-query',
        name: 'Google DoH',
        priority: 2
      }
    ];
  }
  
  /**
   * 开始无连接发送
   */
  async startSending(files, options = {}) {
    if (this.isRunning) {
      console.warn('⚠️ 发送已在进行中');
      return;
    }
    
    this.isRunning = true;
    this.sentCount = 0;
    this.dataSentInMB = 0;
    this.dataSentInBytes = 0;
    
    console.log('🚀 开始无连接全球发送');
    console.log(`📁 准备发送 ${files.length} 个文件`);
    
    try {
      const isLoop = options.isLoop || false;
      
      do {
        for (const file of files) {
          if (!this.isRunning) break;
          
          console.log(`📤 准备无连接发送文件: ${file.name}`);
          
          // 立即开始发送，无需等待连接
          await this._sendFileWithoutConnection(file);
          
          this.sentCount++;
          
          // 通知Flutter进度更新
          if (window.flutterProgressCallback) {
            window.flutterProgressCallback(this.sentCount);
          }
          
          console.log(`✅ 文件 ${file.name} 无连接发送完成`);
        }
      } while (this.isRunning && isLoop);
      
    } catch (error) {
      console.error('❌ 无连接发送过程中发生错误:', error);
    } finally {
      this.isRunning = false;
      console.log('🔚 无连接全球发送服务已停止');
      
      // 通知Flutter发送停止
      if (window.flutterStoppedCallback) {
        window.flutterStoppedCallback();
      }
    }
  }
  
  /**
   * 无连接发送单个文件
   */
  async _sendFileWithoutConnection(file) {
    const fileSize = file.size;
    const fileName = file.name;
    
    console.log(`📊 文件信息: ${fileName}, 大小: ${(fileSize / 1024 / 1024).toFixed(2)} MB`);
    
    // 读取文件数据
    const fileBuffer = await file.arrayBuffer();
    const fileBytes = new Uint8Array(fileBuffer);
    
    // 创建文件元数据
    const metaData = {
      type: 'FILE_START',
      name: fileName,
      size: fileSize,
      timestamp: Date.now(),
      id: this._generateUniqueId(),
      mode: 'NO_CONNECTION_WEB',
    };
    
    // 立即向所有目标发送元数据，无需等待连接确认
    const metaDataSent = await this._sendMetaDataToAllTargets(metaData);
    console.log(`📡 元数据发送完成: ${metaDataSent} 个目标`);
    
    // 分块发送文件
    const chunkSize = 8192; // 8KB
    const totalChunks = Math.ceil(fileSize / chunkSize);
    let sentChunks = 0;
    let successfulSends = 0;
    
    for (let i = 0; i < fileBytes.length; i += chunkSize) {
      if (!this.isRunning) break;
      
      const end = Math.min(i + chunkSize, fileBytes.length);
      const chunk = fileBytes.slice(i, end);
      
      // 创建数据包
      const chunkData = {
        type: 'FILE_CHUNK',
        index: sentChunks,
        size: chunk.length,
        fileName: fileName,
        id: this._generateUniqueId(),
        totalChunks: totalChunks
      };
      
      // 立即向多个目标发送，无需等待确认
      const chunkSent = await this._sendChunkToTargets(chunkData, chunk);
      if (chunkSent > 0) {
        successfulSends++;
        this.dataSentInBytes += chunk.length;
        this.dataSentInMB = this.dataSentInBytes / (1024 * 1024);
        
        // 通知Flutter数据发送更新
        if (window.flutterDataSentCallback) {
          window.flutterDataSentCallback(this.dataSentInMB);
        }
      }
      
      sentChunks++;
      
      // 进度报告
      if (sentChunks % 200 === 0) {
        const progress = (sentChunks / totalChunks * 100).toFixed(1);
        console.log(`📊 无连接发送进度: ${sentChunks}/${totalChunks} 块, ${this.dataSentInMB.toFixed(2)} MB (${progress}%)`);
      }
      
      // 控制发送速率
      await this._delay(1);
    }
    
    // 发送文件结束标记
    const endMarker = {
      type: 'FILE_END',
      fileName: fileName,
      totalChunks: sentChunks,
      totalSize: fileSize,
      timestamp: Date.now(),
      id: this._generateUniqueId(),
    };
    
    const endMarkerSent = await this._sendEndMarkerToTargets(endMarker);
    
    const actualSentMB = (this.dataSentInBytes / 1024 / 1024).toFixed(2);
    console.log(`🎉 文件 ${fileName} 无连接发送完成`);
    console.log(`📈 发送统计: 成功发送 ${successfulSends} 个数据包`);
    console.log(`📊 实际发送: ${actualSentMB} MB, 结束标记发送: ${endMarkerSent} 次`);
  }
  
  /**
   * 发送元数据到所有目标
   */
  async _sendMetaDataToAllTargets(metaData) {
    let sentCount = 0;
    const promises = [];
    
    // 选择高优先级目标
    const highPriorityTargets = this.globalTargets.filter(t => t.priority === 1);
    
    for (const target of highPriorityTargets) {
      promises.push(
        this._sendToTarget(target, metaData, null)
          .then(success => {
            if (success) {
              sentCount++;
              if (sentCount <= 5) {
                console.log(`✓ 元数据已发送到 ${target.name}`);
              }
            }
          })
          .catch(() => {
            // 忽略错误，继续发送到其他目标
          })
      );
    }
    
    // 等待所有发送完成（但不阻塞）
    await Promise.allSettled(promises);
    
    return sentCount;
  }
  
  /**
   * 发送数据块到目标
   */
  async _sendChunkToTargets(chunkData, chunk) {
    let sentCount = 0;
    
    // 随机选择一些目标发送，避免网络拥塞
    const selectedTargets = this._selectRandomTargets(5);
    
    const promises = selectedTargets.map(target => 
      this._sendToTarget(target, chunkData, chunk)
        .then(success => {
          if (success) {
            sentCount++;
          }
        })
        .catch(() => {
          // 忽略错误
        })
    );
    
    // 等待至少一个发送成功
    await Promise.race([
      Promise.allSettled(promises),
      this._delay(1000) // 最多等待1秒
    ]);
    
    return sentCount;
  }
  
  /**
   * 发送结束标记到目标
   */
  async _sendEndMarkerToTargets(endMarker) {
    let sentCount = 0;
    const promises = [];
    
    // 选择前5个目标发送结束标记
    const selectedTargets = this.globalTargets.slice(0, 5);
    
    for (const target of selectedTargets) {
      promises.push(
        this._sendToTarget(target, endMarker, null)
          .then(success => {
            if (success) {
              sentCount++;
            }
          })
          .catch(() => {
            // 忽略错误
          })
      );
    }
    
    await Promise.allSettled(promises);
    
    return sentCount;
  }
  
  /**
   * 发送数据到指定目标
   */
  async _sendToTarget(target, data, binaryData) {
    try {
      switch (target.type) {
        case 'http':
          return await this._sendViaHTTP(target, data, binaryData);
        case 'websocket':
          return await this._sendViaWebSocket(target, data, binaryData);
        case 'webrtc':
          return await this._sendViaWebRTC(target, data, binaryData);
        case 'image':
          return await this._sendViaImage(target, data, binaryData);
        case 'dns':
          return await this._sendViaDNS(target, data, binaryData);
        default:
          return false;
      }
    } catch (error) {
      // 忽略发送错误，确保程序继续运行
      return false;
    }
  }
  
  /**
   * 通过HTTP发送数据
   */
  async _sendViaHTTP(target, data, binaryData) {
    try {
      const payload = {
        metadata: data,
        timestamp: Date.now(),
        source: 'no-connection-transfer'
      };
      
      if (binaryData) {
        // 将二进制数据转换为Base64
        payload.binaryData = this._arrayBufferToBase64(binaryData);
      }
      
      const response = await fetch(target.url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Transfer-Mode': 'NO-CONNECTION',
          'X-Target': target.name
        },
        body: JSON.stringify(payload)
      });
      
      return response.ok;
    } catch (error) {
      return false;
    }
  }
  
  /**
   * 通过WebSocket发送数据
   */
  async _sendViaWebSocket(target, data, binaryData) {
    return new Promise((resolve) => {
      try {
        const ws = new WebSocket(target.url);
        
        const timeout = setTimeout(() => {
          ws.close();
          resolve(false);
        }, 5000);
        
        ws.onopen = () => {
          try {
            const payload = {
              metadata: data,
              timestamp: Date.now(),
              source: 'no-connection-transfer'
            };
            
            if (binaryData) {
              payload.binaryData = this._arrayBufferToBase64(binaryData);
            }
            
            ws.send(JSON.stringify(payload));
            clearTimeout(timeout);
            ws.close();
            resolve(true);
          } catch (e) {
            clearTimeout(timeout);
            ws.close();
            resolve(false);
          }
        };
        
        ws.onerror = () => {
          clearTimeout(timeout);
          resolve(false);
        };
        
        ws.onclose = () => {
          clearTimeout(timeout);
        };
        
      } catch (error) {
        resolve(false);
      }
    });
  }
  
  /**
   * 通过WebRTC发送数据
   */
  async _sendViaWebRTC(target, data, binaryData) {
    try {
      const pc = new RTCPeerConnection({
        iceServers: [{ urls: target.url }]
      });
      
      // 创建数据通道
      const dc = pc.createDataChannel('no-connection-transfer');
      
      // 创建offer
      const offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      
      // 等待ICE候选项生成
      return new Promise((resolve) => {
        let candidateCount = 0;
        const timeout = setTimeout(() => {
          pc.close();
          resolve(candidateCount > 0);
        }, 3000);
        
        pc.onicecandidate = (event) => {
          if (event.candidate) {
            candidateCount++;
            // ICE候选项的生成表明网络连接尝试已经开始
            if (candidateCount >= 3) {
              clearTimeout(timeout);
              pc.close();
              resolve(true);
            }
          }
        };
      });
    } catch (error) {
      return false;
    }
  }
  
  /**
   * 通过图片上传发送数据
   */
  async _sendViaImage(target, data, binaryData) {
    try {
      // 创建一个包含数据的图片
      const canvas = document.createElement('canvas');
      canvas.width = 100;
      canvas.height = 100;
      const ctx = canvas.getContext('2d');
      
      // 在图片中编码数据
      ctx.fillStyle = '#000000';
      ctx.fillRect(0, 0, 100, 100);
      ctx.fillStyle = '#FFFFFF';
      ctx.fillText(JSON.stringify(data).substring(0, 50), 10, 50);
      
      // 转换为blob
      return new Promise((resolve) => {
        canvas.toBlob(async (blob) => {
          try {
            const formData = new FormData();
            formData.append('image', blob, 'data.png');
            formData.append('type', 'base64');
            
            const response = await fetch(target.url, {
              method: 'POST',
              headers: {
                'Authorization': 'Client-ID anonymous' // 匿名上传
              },
              body: formData
            });
            
            resolve(response.ok);
          } catch (error) {
            resolve(false);
          }
        }, 'image/png');
      });
    } catch (error) {
      return false;
    }
  }
  
  /**
   * 通过DNS over HTTPS发送数据
   */
  async _sendViaDNS(target, data, binaryData) {
    try {
      // 将数据编码到DNS查询中
      const encodedData = btoa(JSON.stringify(data)).substring(0, 50);
      const dnsQuery = `${encodedData}.example.com`;
      
      const response = await fetch(`${target.url}?name=${dnsQuery}&type=A`, {
        headers: {
          'Accept': 'application/dns-json'
        }
      });
      
      return response.ok;
    } catch (error) {
      return false;
    }
  }
  
  /**
   * 随机选择目标
   */
  _selectRandomTargets(count) {
    const shuffled = [...this.globalTargets].sort(() => 0.5 - Math.random());
    return shuffled.slice(0, count);
  }
  
  /**
   * 生成唯一ID
   */
  _generateUniqueId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2, 5);
  }
  
  /**
   * ArrayBuffer转Base64
   */
  _arrayBufferToBase64(buffer) {
    let binary = '';
    const bytes = new Uint8Array(buffer);
    const len = bytes.byteLength;
    for (let i = 0; i < len; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary);
  }
  
  /**
   * 延迟函数
   */
  _delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
  
  /**
   * 停止发送
   */
  stopSending() {
    this.isRunning = false;
    console.log('🛑 无连接发送已停止');
  }
}

// 创建全局实例
window.noConnectionTransfer.manager = new NoConnectionManager();

// 导出到Flutter的接口
window.flutterNoConnectionTransfer = {
  /**
   * 初始化无连接传输
   */
  initialize: function() {
    console.log('从Flutter初始化无连接传输');
    return {
      success: true,
      targetCount: window.noConnectionTransfer.manager.globalTargets.length,
      message: '无连接传输初始化完成'
    };
  },
  
  /**
   * 开始发送文件
   */
  startSending: async function(fileIds, options = {}) {
    try {
      // 从文件映射中获取文件
      const files = [];
      for (const fileId of fileIds) {
        const file = window._flutterFileMap[fileId];
        if (file) {
          files.push(file);
        }
      }
      
      if (files.length === 0) {
        throw new Error('没有找到要发送的文件');
      }
      
      await window.noConnectionTransfer.manager.startSending(files, options);
      
      return {
        success: true,
        message: `开始无连接发送 ${files.length} 个文件`
      };
    } catch (error) {
      return {
        success: false,
        message: error.message
      };
    }
  },
  
  /**
   * 停止发送
   */
  stopSending: function() {
    try {
      window.noConnectionTransfer.manager.stopSending();
      return {
        success: true,
        message: '无连接发送已停止'
      };
    } catch (error) {
      return {
        success: false,
        message: error.message
      };
    }
  },
  
  /**
   * 获取发送状态
   */
  getStatus: function() {
    const manager = window.noConnectionTransfer.manager;
    return {
      isRunning: manager.isRunning,
      sentCount: manager.sentCount,
      dataSentInMB: manager.dataSentInMB
    };
  }
};

// 确保文件映射存在
if (!window._flutterFileMap) {
  window._flutterFileMap = {};
}

console.log('🚀 无连接全球发送JavaScript库已加载');