// 无限制发送Web Worker
class UnlimitedSender {
  constructor() {
    this.isRunning = false;
    this.channels = [];
    this.initializeChannels();
  }

  initializeChannels() {
    // 创建多个广播通道
    const channelNames = [
      'dharma-broadcast-1',
      'dharma-broadcast-2', 
      'dharma-broadcast-3',
      'global-transfer',
      'file-stream'
    ];

    channelNames.forEach(name => {
      const channel = new BroadcastChannel(name);
      this.channels.push(channel);
    });

    // 创建SharedArrayBuffer进行内存共享
    if (typeof SharedArrayBuffer !== 'undefined') {
      this.sharedBuffer = new SharedArrayBuffer(1024 * 1024); // 1MB
      this.sharedView = new Uint8Array(this.sharedBuffer);
    }

    console.log('✅ 无限制发送通道初始化完成');
  }

  async sendFile(fileData, fileName) {
    if (!fileData) return;

    console.log(`📤 开始无限制发送: ${fileName}`);
    
    // 方法1: 广播通道发送
    await this.sendViaBroadcast(fileData, fileName);
    
    // 方法2: IndexedDB存储
    await this.sendViaIndexedDB(fileData, fileName);
    
    // 方法3: WebSocket尝试
    await this.sendViaWebSocket(fileData, fileName);
    
    // 方法4: Service Worker缓存
    await this.sendViaServiceWorker(fileData, fileName);

    console.log(`✅ 文件 ${fileName} 多通道发送完成`);
  }

  async sendViaBroadcast(fileData, fileName) {
    const chunkSize = 64 * 1024; // 64KB
    const totalChunks = Math.ceil(fileData.length / chunkSize);

    for (let i = 0; i < totalChunks; i++) {
      const start = i * chunkSize;
      const end = Math.min(start + chunkSize, fileData.length);
      const chunk = fileData.slice(start, end);

      const message = {
        type: 'FILE_CHUNK',
        fileName,
        chunkIndex: i,
        totalChunks,
        data: Array.from(chunk),
        timestamp: Date.now()
      };

      // 向所有通道广播
      this.channels.forEach((channel, index) => {
        try {
          channel.postMessage(message);
          if (i % 50 === 0) {
            console.log(`✅ 广播块 ${i}/${totalChunks} 到通道 ${index}`);
          }
        } catch (e) {
          console.log(`⚠️ 广播块 ${i} 到通道 ${index} 失败`);
        }
      });

      // 控制发送速率
      if (i % 10 === 0) {
        await new Promise(resolve => setTimeout(resolve, 1));
      }
    }
  }

  async sendViaIndexedDB(fileData, fileName) {
    try {
      const request = indexedDB.open('DharmaStorage', 1);
      
      request.onupgradeneeded = (event) => {
        const db = event.target.result;
        if (!db.objectStoreNames.contains('files')) {
          db.createObjectStore('files', { keyPath: 'id' });
        }
      };

      request.onsuccess = (event) => {
        const db = event.target.result;
        const transaction = db.transaction(['files'], 'readwrite');
        const store = transaction.objectStore('files');
        
        const fileRecord = {
          id: `${fileName}_${Date.now()}`,
          name: fileName,
          data: Array.from(fileData),
          timestamp: Date.now(),
          size: fileData.length
        };

        store.add(fileRecord);
        console.log(`✅ 文件 ${fileName} 已存储到IndexedDB`);
      };
    } catch (e) {
      console.log(`⚠️ IndexedDB存储失败: ${e}`);
    }
  }

  async sendViaWebSocket(fileData, fileName) {
    // 尝试连接到多个WebSocket端点
    const endpoints = [
      'wss://echo.websocket.org',
      'wss://ws.postman-echo.com/raw',
    ];

    for (const endpoint of endpoints) {
      try {
        const ws = new WebSocket(endpoint);
        
        ws.onopen = () => {
          const message = {
            type: 'FILE_TRANSFER',
            fileName,
            data: Array.from(fileData.slice(0, 1024)), // 只发送前1KB作为示例
            timestamp: Date.now()
          };
          
          ws.send(JSON.stringify(message));
          console.log(`✅ WebSocket发送到 ${endpoint}`);
          ws.close();
        };

        ws.onerror = () => {
          console.log(`⚠️ WebSocket连接 ${endpoint} 失败`);
        };

        // 等待连接
        await new Promise(resolve => setTimeout(resolve, 100));
        
      } catch (e) {
        console.log(`⚠️ WebSocket ${endpoint} 错误: ${e}`);
      }
    }
  }

  async sendViaServiceWorker(fileData, fileName) {
    try {
      if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
        navigator.serviceWorker.controller.postMessage({
          type: 'CACHE_FILE',
          fileName,
          data: Array.from(fileData),
          timestamp: Date.now()
        });
        console.log(`✅ 文件 ${fileName} 已发送到Service Worker`);
      }
    } catch (e) {
      console.log(`⚠️ Service Worker发送失败: ${e}`);
    }
  }

  stop() {
    this.isRunning = false;
    this.channels.forEach(channel => channel.close());
    console.log('🛑 无限制发送已停止');
  }
}

// Worker消息处理
const sender = new UnlimitedSender();

self.onmessage = async function(e) {
  const { type, fileData, fileName } = e.data;
  
  switch (type) {
    case 'SEND_FILE':
      await sender.sendFile(new Uint8Array(fileData), fileName);
      self.postMessage({ type: 'FILE_SENT', fileName });
      break;
      
    case 'STOP':
      sender.stop();
      self.postMessage({ type: 'STOPPED' });
      break;
  }
};

console.log('📡 无限制发送Worker已启动');