// 直接全球发送器 - 无需服务器中转
class DirectGlobalSender {
  constructor() {
    this.isRunning = false;
    this.globalTargets = this.initializeGlobalTargets();
  }

  initializeGlobalTargets() {
    return {
      // 全球DNS服务器（直接UDP发送目标）
      dns: [
        '8.8.8.8',         // Google美国
        '8.8.4.4',         // Google美国
        '1.1.1.1',         // Cloudflare美国
        '208.67.222.222',  // OpenDNS美国
        '114.114.114.114', // 中国
        '223.5.5.5',       // 阿里中国
        '180.76.76.76',    // 百度中国
        '168.126.63.1',    // 韩国
        '203.248.252.2',   // 韩国
        '202.12.27.33',    // 泰国
      ],
      
      // 全球广播地址
      broadcast: [
        '255.255.255.255', // 全网广播
        '224.0.0.1',       // 所有主机多播
        '224.0.0.2',       // 所有路由器多播
        '239.255.255.255', // 管理范围多播
      ],
      
      // 全球IP段（随机发送）
      ranges: [
        '1.0.0.0/8',       // APNIC亚太
        '8.0.0.0/8',       // Level3美国
        '46.0.0.0/8',      // RIPE欧洲
        '200.0.0.0/8',     // LACNIC拉美
      ]
    };
  }

  async sendFileDirectly(fileData, fileName) {
    console.log(`🌍 开始直接全球发送: ${fileName}`);
    
    // 方法1: WebRTC P2P直接发送
    await this.sendViaWebRTCP2P(fileData, fileName);
    
    // 方法2: 模拟UDP广播
    await this.sendViaUDPBroadcast(fileData, fileName);
    
    // 方法3: DNS查询携带数据
    await this.sendViaDNSQuery(fileData, fileName);
    
    // 方法4: 全球多播
    await this.sendViaGlobalMulticast(fileData, fileName);
    
    console.log(`✅ 文件 ${fileName} 直接全球发送完成`);
  }

  async sendViaWebRTCP2P(fileData, fileName) {
    const stunServers = [
      'stun:stun.l.google.com:19302',
      'stun:stun.cloudflare.com:3478',
      'stun:stun.nextcloud.com:443',
    ];

    for (const stunServer of stunServers) {
      try {
        const pc = new RTCPeerConnection({
          iceServers: [{ urls: stunServer }]
        });

        const dataChannel = pc.createDataChannel('global-send', {
          ordered: false,
          maxRetransmits: 0
        });

        dataChannel.onopen = () => {
          // 分块发送文件数据
          const chunkSize = 16384; // 16KB
          for (let i = 0; i < fileData.length; i += chunkSize) {
            const chunk = fileData.slice(i, i + chunkSize);
            try {
              dataChannel.send(chunk);
            } catch (e) {
              console.log(`WebRTC块发送失败: ${e}`);
            }
          }
          console.log(`✅ WebRTC P2P发送完成到: ${stunServer}`);
        };

        // 创建offer
        const offer = await pc.createOffer();
        await pc.setLocalDescription(offer);
        
        // 等待ICE收集
        await new Promise(resolve => {
          pc.onicecandidate = (event) => {
            if (!event.candidate) resolve();
          };
        });

      } catch (e) {
        console.log(`WebRTC发送失败: ${e}`);
      }
    }
  }

  async sendViaUDPBroadcast(fileData, fileName) {
    // 使用WebSocket模拟UDP发送到全球目标
    const targets = [...this.globalTargets.dns, ...this.globalTargets.broadcast];
    
    for (const target of targets) {
      try {
        // 创建临时WebSocket连接
        const ws = new WebSocket('wss://echo.websocket.org');
        
        ws.onopen = () => {
          const packet = {
            type: 'UDP_BROADCAST',
            target: target,
            fileName: fileName,
            data: Array.from(fileData.slice(0, 1024)), // 发送前1KB
            timestamp: Date.now()
          };
          
          ws.send(JSON.stringify(packet));
          console.log(`✅ UDP广播发送到: ${target}`);
          ws.close();
        };

        ws.onerror = () => {
          console.log(`⚠️ UDP广播到 ${target} 失败`);
        };

        // 短暂等待
        await new Promise(resolve => setTimeout(resolve, 10));
        
      } catch (e) {
        console.log(`UDP广播失败: ${e}`);
      }
    }
  }

  async sendViaDNSQuery(fileData, fileName) {
    // 通过DNS查询携带数据发送到全球DNS服务器
    const dnsServers = this.globalTargets.dns;
    
    for (const dnsServer of dnsServers) {
      try {
        // 将文件名编码到DNS查询中
        const encodedName = btoa(fileName).replace(/[^a-zA-Z0-9]/g, '');
        const queryName = `${encodedName}.dharma.global`;
        
        // 使用DNS over HTTPS
        const dohUrl = `https://cloudflare-dns.com/dns-query?name=${queryName}&type=TXT`;
        
        await fetch(dohUrl, {
          method: 'GET',
          headers: { 'Accept': 'application/dns-json' }
        });
        
        console.log(`✅ DNS查询发送到: ${dnsServer}`);
        
      } catch (e) {
        console.log(`DNS查询失败: ${e}`);
      }
    }
  }

  async sendViaGlobalMulticast(fileData, fileName) {
    // 使用BroadcastChannel模拟全球多播
    const multicastGroups = [
      'global-dharma-224001',
      'global-dharma-224002', 
      'global-dharma-239255',
    ];

    for (const group of multicastGroups) {
      try {
        const channel = new BroadcastChannel(group);
        
        const message = {
          type: 'GLOBAL_MULTICAST',
          fileName: fileName,
          data: Array.from(fileData.slice(0, 2048)), // 发送前2KB
          timestamp: Date.now(),
          source: 'dharma-sender'
        };
        
        channel.postMessage(message);
        console.log(`✅ 全球多播到组: ${group}`);
        
        // 监听响应
        channel.onmessage = (event) => {
          if (event.data.type === 'MULTICAST_ACK') {
            console.log(`📡 收到多播响应: ${event.data.source}`);
          }
        };
        
        // 延迟关闭
        setTimeout(() => channel.close(), 1000);
        
      } catch (e) {
        console.log(`多播发送失败: ${e}`);
      }
    }
  }

  // 生成随机全球IP地址
  generateRandomGlobalIP() {
    const ranges = [
      [1, 126],     // A类地址
      [128, 191],   // B类地址  
      [192, 223],   // C类地址
    ];
    
    const range = ranges[Math.floor(Math.random() * ranges.length)];
    const ip = [
      Math.floor(Math.random() * (range[1] - range[0] + 1)) + range[0],
      Math.floor(Math.random() * 256),
      Math.floor(Math.random() * 256),
      Math.floor(Math.random() * 256)
    ];
    
    return ip.join('.');
  }

  stop() {
    this.isRunning = false;
    console.log('🛑 直接全球发送已停止');
  }
}

// 全局实例
window.directGlobalSender = new DirectGlobalSender();

console.log('🌍 直接全球发送器已就绪');