# 延迟函数错误修复

## 问题描述
在大文件分片上传过程中出现错误：`delay is not a function`

## 错误原因
在 `retryWithBackoff` 和 `uploadInChunks` 函数中，错误地使用了变量名 `delay` 来调用延迟函数，导致与函数参数名冲突。

## 具体错误位置

### 1. retryWithBackoff 函数
```javascript
// 错误代码
const delay = initialDelay * Math.pow(2, attempt) + Math.random() * 1000;
await delay(delay); // ❌ delay 是数字，不是函数
```

### 2. uploadInChunks 函数  
```javascript
// 错误代码
await delay(50); // ❌ 在某些作用域中 delay 未定义
```

### 3. startSendingProcess 函数
```javascript
// 错误代码
await delay(500); // ❌ 类似问题
```

## 修复方案

### 1. 重命名变量避免冲突
```javascript
// 修复后
const delayMs = initialDelay * Math.pow(2, attempt) + Math.random() * 1000;
await new Promise(resolve => setTimeout(resolve, delayMs));
```

### 2. 统一使用 Promise + setTimeout
```javascript
// 修复后 - 所有延迟调用都使用这种方式
await new Promise(resolve => setTimeout(resolve, 50));
await new Promise(resolve => setTimeout(resolve, 500));
await new Promise(resolve => setTimeout(resolve, delayMs));
```

## 修复的文件位置

### service-worker.js
- **行 830-836**: `retryWithBackoff` 函数中的延迟调用
- **行 720**: `uploadInChunks` 函数中的分片间延迟  
- **行 558**: `startSendingProcess` 函数中的文件间延迟
- **行 1075**: 另一个重试机制中的延迟调用

## 修复验证

### 测试方法
1. 使用 `test-delay-fix.html` 测试基本功能
2. 重新尝试大文件上传
3. 观察日志中是否还有 `delay is not a function` 错误

### 预期结果
- ✅ 不再出现 `delay is not a function` 错误
- ✅ 重试机制正常工作
- ✅ 分片上传正常进行
- ✅ 大文件上传成功率提升

## 根本原因分析

这个错误是由于 JavaScript 作用域和变量命名冲突导致的：

1. **变量遮蔽**: 局部变量 `delay` 遮蔽了全局的 `delay` 函数
2. **类型错误**: 试图调用数字类型的变量作为函数
3. **作用域混乱**: 在某些嵌套作用域中 `delay` 函数不可访问

## 预防措施

1. **避免变量名冲突**: 使用更具描述性的变量名如 `delayMs`, `waitTime` 等
2. **统一延迟实现**: 使用 `Promise + setTimeout` 而不是自定义 `delay` 函数
3. **代码审查**: 检查变量名是否与函数名冲突

---

**修复时间**: 2025年1月18日 11:50  
**影响范围**: Service Worker 中的重试和延迟机制  
**风险等级**: 低 (仅修复函数调用，不改变逻辑)