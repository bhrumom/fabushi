const WebSocket = require('ws');
const dgram = require('dgram');
const http = require('http');

const PORT = process.env.PORT || 8081;

// 创建HTTP服务器
const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('WebSocket中继服务器正在运行');
});

// 创建WebSocket服务器
const wss = new WebSocket.Server({ server });

// 创建UDP客户端
const udpClient = dgram.createSocket('udp4');

// 处理WebSocket连接
wss.on('connection', (ws) => {
  console.log('新的WebSocket连接已建立');
  
  let currentFileMetadata = null;
  
  ws.on('message', (message) => {
    try {
      // 检查是否是元数据消息
      if (typeof message === 'string' && message.startsWith('META:')) {
        const metadataStr = message.substring(5);
        currentFileMetadata = JSON.parse(metadataStr);
        console.log(`接收到文件元数据: ${JSON.stringify(currentFileMetadata)}`);
        return;
      }
      
      // 如果没有元数据，则无法处理文件内容
      if (!currentFileMetadata) {
        console.error('收到文件内容但没有元数据');
        return;
      }
      
      // 处理文件内容（二进制数据）
      const fileBuffer = Buffer.from(message);
      const { name, size, target_ip } = currentFileMetadata;
      
      console.log(`接收到文件: ${name} (${size} 字节), 准备发送到: ${target_ip}`);
      
      // 定义要发送到的端口列表
      const ports = [53, 80, 443, 5353];
      
      // 将文件内容通过UDP发送到每个端口
      ports.forEach(port => {
        udpClient.send(fileBuffer, 0, fileBuffer.length, port, target_ip, (err) => {
          if (err) {
            console.error(`发送到 ${target_ip}:${port} 失败:`, err);
          } else {
            console.log(`成功发送到 ${target_ip}:${port}`);
          }
        });
      });
      
      // 重置当前文件元数据
      currentFileMetadata = null;
      
    } catch (error) {
      console.error('处理WebSocket消息时出错:', error);
    }
  });
  
  ws.on('close', () => {
    console.log('WebSocket连接已关闭');
  });
  
  ws.on('error', (error) => {
    console.error('WebSocket错误:', error);
  });
});

// 启动服务器
server.listen(PORT, () => {
  console.log(`WebSocket中继服务器正在运行在端口 ${PORT}`);
});

// 优雅地关闭
process.on('SIGINT', () => {
  udpClient.close(() => {
    console.log('UDP客户端已关闭');
    server.close(() => {
      console.log('HTTP/WebSocket服务器已关闭');
      process.exit(0);
    });
  });
});