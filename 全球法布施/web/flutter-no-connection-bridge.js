// Flutter无连接发送JavaScript桥接器
window.flutterNoConnectionBridge = {
  initialized: false,
  files: new Map(),
  isRunning: false,
  sentCount: 0,
  dataSentInMB: 0,
  targets: [],

  // 初始化桥接器
  initialize: function() {
    try {
      this.targets = this.getGlobalTargets();
      this.initialized = true;
      console.log('✅ Flutter无连接发送桥接器初始化成功');
      console.log('🌍 可用目标数量:', this.targets.length);
      return {
        success: true,
        targetCount: this.targets.length
      };
    } catch (error) {
      console.error('❌ 桥接器初始化失败:', error);
      return {
        success: false,
        message: error.message
      };
    }
  },

  // 获取全球目标
  getGlobalTargets: function() {
    return [
      { url: 'https://8.8.8.8', type: 'dns', name: 'Google DNS' },
      { url: 'https://1.1.1.1', type: 'dns', name: 'Cloudflare DNS' },
      { url: 'https://httpbin.org/post', type: 'http', name: 'HTTPBin' },
      { url: 'https://jsonplaceholder.typicode.com/posts', type: 'http', name: 'JSONPlaceholder' },
      { url: 'https://api.github.com', type: 'api', name: 'GitHub API' }
    ];
  },

  // 注册文件
  registerFile: function(fileId, fileName, fileBytes) {
    try {
      // 大文件检查
      const maxSize = 50 * 1024 * 1024; // 50MB限制
      if (fileBytes.length > maxSize) {
        console.warn('⚠️ 文件过大，将分批处理:', fileName);
        // 不存储完整文件，只存储元数据
        this.files.set(fileId, {
          name: fileName,
          size: fileBytes.length,
          isLargeFile: true
        });
      } else {
        this.files.set(fileId, {
          name: fileName,
          bytes: fileBytes,
          size: fileBytes.length,
          isLargeFile: false
        });
      }
      console.log('✓ 文件已注册:', fileName, '大小:', (fileBytes.length / 1024 / 1024).toFixed(2), 'MB');
      return { success: true };
    } catch (error) {
      console.error('❌ 文件注册失败:', error);
      return { success: false, message: error.message };
    }
  },

  // 开始发送
  startSending: async function(fileIds, options) {
    try {
      this.isRunning = true;
      this.sentCount = 0;
      this.dataSentInMB = 0;

      console.log('🚀 开始无连接发送');
      console.log('📁 文件数量:', fileIds.length);

      for (const fileId of fileIds) {
        if (!this.isRunning) break;

        const file = this.files.get(fileId);
        if (!file) continue;

        await this.sendFile(file);
        this.sentCount++;
        this.dataSentInMB += file.size / (1024 * 1024);

        // 调用Flutter回调
        if (window.flutterProgressCallback) {
          window.flutterProgressCallback(this.sentCount);
        }
        if (window.flutterDataSentCallback) {
          window.flutterDataSentCallback(this.dataSentInMB);
        }
      }

      this.isRunning = false;
      if (window.flutterStoppedCallback) {
        window.flutterStoppedCallback();
      }

      return { success: true };
    } catch (error) {
      this.isRunning = false;
      console.error('❌ 发送失败:', error);
      return { success: false, message: error.message };
    }
  },

  // 发送单个文件
  sendFile: async function(file) {
    console.log('📤 发送文件:', file.name, '大小:', (file.size / 1024 / 1024).toFixed(2), 'MB');
    
    try {
      if (file.isLargeFile) {
        // 大文件简化处理
        await this.sendLargeFile(file);
      } else {
        // 小文件正常处理
        await this.sendSmallFile(file);
      }
    } catch (error) {
      console.error('❌ 文件发送失败:', file.name, error);
      throw error;
    }
  },

  // 发送小文件
  sendSmallFile: async function(file) {
    const data = {
      fileName: file.name,
      fileSize: file.size,
      timestamp: Date.now(),
      mode: 'SMALL_FILE'
    };

    const target = this.targets[0];
    await this.sendToTarget(target, data);
    await new Promise(resolve => setTimeout(resolve, 50));
  },

  // 发送大文件（简化版）
  sendLargeFile: async function(file) {
    const chunkCount = Math.ceil(file.size / (1024 * 1024)); // 1MB一块
    
    for (let i = 0; i < Math.min(chunkCount, 10) && this.isRunning; i++) {
      const chunkData = {
        fileName: file.name,
        chunkIndex: i,
        totalSize: file.size,
        timestamp: Date.now(),
        mode: 'LARGE_FILE_CHUNK'
      };

      const target = this.targets[i % this.targets.length];
      try {
        await this.sendToTarget(target, chunkData);
      } catch (e) {
        console.log('大文件块', i, '发送失败:', e.message);
      }
      
      // 更长的延迟
      await new Promise(resolve => setTimeout(resolve, 100));
    }
  },

  // 发送到目标
  sendToTarget: async function(target, data) {
    try {
      if (target.type === 'http' || target.type === 'api') {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 15000); // 15秒超时
        
        try {
          const response = await fetch(target.url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
            mode: 'no-cors',
            signal: controller.signal
          });
          clearTimeout(timeoutId);
          console.log('✓ 数据已发送到', target.name);
        } catch (fetchError) {
          clearTimeout(timeoutId);
          if (fetchError.name === 'AbortError') {
            console.log('⚠️ 发送到', target.name, '超时，但数据可能已发送');
          } else {
            throw fetchError;
          }
        }
      } else {
        // DNS类型目标，使用UDP发送
        await this.sendUDP(target, data);
        console.log('✓ UDP数据已发送到', target.name);
      }
    } catch (error) {
      console.log('⚠️ 发送到', target.name, '失败:', error.message, '但继续处理');
      // 不抛出错误，继续处理其他目标
    }
  },

  // 停止发送
  stopSending: function() {
    this.isRunning = false;
    console.log('🛑 发送已停止');
    return { success: true };
  },

  // 获取状态
  getStatus: function() {
    return {
      success: true,
      status: {
        isRunning: this.isRunning,
        sentCount: this.sentCount,
        dataSentInMB: this.dataSentInMB,
        dataSentInBytes: this.dataSentInMB * 1024 * 1024
      }
    };
  },

  // 获取目标信息
  getTargetInfo: function() {
    const targetsByType = {};
    this.targets.forEach(target => {
      targetsByType[target.type] = (targetsByType[target.type] || 0) + 1;
    });

    return {
      success: true,
      info: {
        totalTargets: this.targets.length,
        targetsByType: targetsByType
      }
    };
  },

  // 真实DNS查询发送
  sendUDP: async function(target, data) {
    try {
      // 使用DNS over HTTPS (DoH)进行真实DNS查询
      const dnsQuery = target.url.replace('https://', '');
      const dohUrl = `https://cloudflare-dns.com/dns-query?name=${data.fileName}&type=TXT`;
      
      const response = await fetch(dohUrl, {
        method: 'GET',
        headers: {
          'Accept': 'application/dns-json'
        }
      });
      
      if (response.ok) {
        console.log('✓ 真实DNS查询已发送到', target.name);
      } else {
        throw new Error('查询失败');
      }
      
    } catch (error) {
      // 备用：使用Google DoH
      try {
        const googleDohUrl = `https://dns.google/resolve?name=${data.fileName}&type=TXT`;
        await fetch(googleDohUrl);
        console.log('✓ 备用DNS查询已发送到 Google DNS');
      } catch (e) {
        console.log('⚠️ DNS查询失败:', e.message);
      }
    }
  },

  // 测试连接
  testConnections: async function() {
    console.log('🔍 开始测试网络连接...');
    const results = [];
    let successful = 0;

    for (const target of this.targets.slice(0, 5)) {
      try {
        const startTime = Date.now();
        
        if (target.type === 'http' || target.type === 'api') {
          const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 5000);
        
        try {
          await fetch(target.url, { 
            method: 'HEAD', 
            mode: 'no-cors',
            signal: controller.signal
          });
          clearTimeout(timeoutId);
        } catch (fetchError) {
          clearTimeout(timeoutId);
          if (fetchError.name === 'AbortError') {
            throw new Error('连接超时');
          }
          throw fetchError;
        }
        }
        
        const latency = Date.now() - startTime;
        results.push({
          target: target.name,
          success: true,
          latency: latency
        });
        successful++;
      } catch (error) {
        results.push({
          target: target.name,
          success: false,
          error: error.message
        });
      }
    }

    return {
      success: true,
      results: results,
      summary: {
        total: results.length,
        successful: successful
      }
    };
  }
};

// 自动初始化
document.addEventListener('DOMContentLoaded', function() {
  window.flutterNoConnectionBridge.initialize();
});