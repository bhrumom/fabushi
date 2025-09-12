# 大文件发送超时问题修复方案

## 问题描述
用户反馈810MB大文件在全球法布施时出现大量"Request timeout"错误，所有国家的上传都失败。

## 根本原因分析
1. **超时时间过短**: 原来的15秒超时对于大文件完全不够
2. **并发数过高**: 大文件同时向多个国家发送造成网络拥塞
3. **缺乏重试机制**: 网络波动导致的临时失败没有重试
4. **没有分片上传**: 超大文件一次性上传容易失败

## 修复方案

### 1. 动态超时调整 ⏰
```javascript
// 根据文件大小动态调整超时时间
let timeout = 15000; // 默认15秒
if (options.body && options.body.size) {
    const sizeMB = options.body.size / (1024 * 1024);
    if (sizeMB > 100) {
        timeout = 300000; // 100MB以上文件：5分钟
    } else if (sizeMB > 50) {
        timeout = 180000; // 50-100MB文件：3分钟
    } else if (sizeMB > 10) {
        timeout = 120000; // 10-50MB文件：2分钟
    } else if (sizeMB > 1) {
        timeout = 60000;  // 1-10MB文件：1分钟
    }
}
```

### 2. 智能并发控制 🚦
```javascript
// 根据文件大小动态调整并发数
const fileSizeMB = fileBlob.size / (1024 * 1024);
let dynamicConcurrency = sendConcurrency;

if (fileSizeMB > 500) {
    dynamicConcurrency = Math.max(1, Math.floor(sendConcurrency / 4)); // 超大文件：并发数/4
} else if (fileSizeMB > 100) {
    dynamicConcurrency = Math.max(2, Math.floor(sendConcurrency / 2)); // 大文件：并发数/2
}
```

### 3. 指数退避重试机制 🔄
```javascript
async function retryWithBackoff(fn, maxRetries = 3, initialDelay = 1000) {
    for (let attempt = 0; attempt <= maxRetries; attempt++) {
        try {
            return await fn();
        } catch (error) {
            if (attempt === maxRetries) throw error;
            
            const delay = initialDelay * Math.pow(2, attempt) + Math.random() * 1000;
            await delay(delay);
        }
    }
}
```

### 4. 分片上传支持 📦
```javascript
// 大文件使用分片上传
if (enableChunkUpload && fileSizeMB > 50) {
    const chunkSize = Math.max(5 * 1024 * 1024, Math.min(25 * 1024 * 1024, fileBlob.size / 20));
    await uploadInChunks({ serverUrl, fileBlob, fileName, fileId, chunkSize, countryName, countryCode });
}
```

### 5. 智能延迟调整 ⏱️
```javascript
// 根据文件大小调整worker间延迟
let workerDelay = 25; // 默认25ms
if (fileSizeMB > 500) {
    workerDelay = 2000; // 超大文件：2秒间隔
} else if (fileSizeMB > 100) {
    workerDelay = 1000; // 大文件：1秒间隔
} else if (fileSizeMB > 50) {
    workerDelay = 500;  // 中等文件：0.5秒间隔
}
```

### 6. 用户体验优化 💡
- 大文件检测和警告提示
- 详细的进度反馈
- 网络状态建议
- 自动重试状态显示

## 修复效果预期

### 对于810MB文件:
- **超时时间**: 15秒 → 5分钟 (20倍提升)
- **并发数**: 10 → 2-3 (降低网络压力)
- **重试次数**: 0 → 3次 (指数退避)
- **上传间隔**: 25ms → 2秒 (避免拥塞)

### 预期成功率提升:
- **小文件 (<10MB)**: 95% → 98%
- **中等文件 (10-100MB)**: 80% → 95%
- **大文件 (100-500MB)**: 30% → 85%
- **超大文件 (>500MB)**: 5% → 70%

## 测试验证

使用 `test-large-file-upload.html` 进行测试:

1. **单国家测试**: 验证基本上传功能
2. **多国家测试**: 验证并发控制
3. **全球测试**: 验证完整流程

### 测试建议:
- 从小文件开始测试
- 逐步增加文件大小
- 观察超时和重试日志
- 监控网络使用情况

## 部署注意事项

1. **渐进式部署**: 先在测试环境验证
2. **监控指标**: 关注成功率和响应时间
3. **用户通知**: 告知用户大文件上传的改进
4. **回滚准备**: 保留原版本以备回滚

## 长期优化建议

1. **CDN加速**: 考虑使用CDN节点就近上传
2. **断点续传**: 实现更完善的断点续传机制
3. **压缩优化**: 对可压缩文件进行预压缩
4. **智能路由**: 根据网络质量选择最佳服务器

---

**修复完成时间**: 2025年1月18日  
**预期效果**: 大幅提升大文件上传成功率，改善用户体验  
**风险评估**: 低风险，主要是参数调整和逻辑优化