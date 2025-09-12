# 全球法布施 - Web平台功能说明

## 概述

全球法布施应用的Web版本使用了创新的技术方案，使网页应用能够模拟原生应用的功能，包括WiFi广播和全球发送功能。这是通过WebAssembly和Service Worker技术实现的，无需用户安装任何额外软件。

## 技术架构

Web版本使用以下技术实现硬件访问功能：

1. **WebAssembly (WASM)** - 将Rust代码编译为可在浏览器中运行的二进制格式
2. **Service Worker** - 在浏览器后台运行，拦截网络请求并处理文件传输
3. **WebSocket中继服务器** - 接收来自浏览器的WebSocket连接，并将数据转换为UDP数据包

## 功能限制

由于浏览器安全限制，Web版本的某些功能与原生应用相比有一定限制：

1. **WiFi广播** - 需要通过WebSocket中继服务器转发，可能有延迟
2. **全球发送** - 同样需要通过中继服务器，可能有带宽限制
3. **后台运行** - 浏览器标签关闭后，应用无法继续在后台运行

## 部署说明

### 本地测试

1. 安装必要工具：
   - Rust和wasm-pack (用于编译WebAssembly)
   - Node.js (用于运行中继服务器)
   - Flutter SDK

2. 编译WebAssembly模块：
   ```bash
   cd web/wasm-proxy
   wasm-pack build --target web --out-dir pkg
   ```

3. 启动中继服务器：
   ```bash
   cd web/relay-server
   npm install
   npm start
   ```

4. 构建并运行Flutter Web应用：
   ```bash
   flutter run -d chrome
   ```

### 生产部署

1. 使用提供的构建脚本：
   ```bash
   ./build_web.sh
   ```

2. 将`build/web`目录部署到Web服务器

3. 将中继服务器部署到支持WebSocket的服务器上

## 配置说明

### 中继服务器URL

默认情况下，应用使用`wss://relay.example.com`作为中继服务器地址。您需要修改以下文件中的URL：

1. `lib/services/wasm_proxy_service.dart` - 修改`_relayServerUrl`变量
2. `web/service-worker.js` - 修改`relayServerUrl`变量

### 安全考虑

1. 在生产环境中，建议使用HTTPS和WSS协议确保数据传输安全
2. 中继服务器应实施适当的访问控制和速率限制
3. 考虑添加用户认证机制，避免服务被滥用

## 故障排除

1. **Service Worker未注册** - 检查浏览器控制台错误信息，确保Service Worker文件路径正确
2. **WebAssembly模块加载失败** - 确保WASM文件已正确编译并放置在正确位置
3. **无法连接到中继服务器** - 检查中继服务器是否正在运行，URL是否正确
4. **文件传输失败** - 检查浏览器控制台日志，可能是由于文件大小限制或网络问题

## 进一步改进

1. 实现端到端加密，提高数据传输安全性
2. 添加WebRTC支持，实现点对点文件传输
3. 实现渐进式Web应用(PWA)功能，提供离线支持
4. 优化大文件传输性能，实现分块上传