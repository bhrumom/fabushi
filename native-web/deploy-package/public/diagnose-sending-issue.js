// 发送问题诊断脚本
// 用于分析和修复发送中途停止的问题

class SendingDiagnostics {
    constructor() {
        this.logs = [];
        this.startTime = null;
        this.lastActivityTime = null;
        this.countryProgress = new Map();
        this.errorPatterns = new Map();
        this.stallThreshold = 5 * 60 * 1000; // 5分钟无活动视为停滞
    }

    // 开始诊断
    startDiagnosis() {
        console.log('🔍 开始发送诊断...');
        this.startTime = Date.now();
        this.lastActivityTime = Date.now();
        
        // 监听 Service Worker 消息
        if ('serviceWorker' in navigator) {
            navigator.serviceWorker.addEventListener('message', (event) => {
                this.handleServiceWorkerMessage(event);
            });
        }
        
        // 启动监控定时器
        this.startMonitoring();
    }

    // 处理 Service Worker 消息
    handleServiceWorkerMessage(event) {
        const { type, message, payload } = event.data;
        
        this.lastActivityTime = Date.now();
        this.logActivity(type, message, payload);
        
        switch (type) {
            case 'log':
                this.analyzeLogMessage(message);
                break;
                
            case 'progress':
                this.updateProgress(payload);
                break;
                
            case 'stall_detected':
                this.handleStallDetection(payload);
                break;
        }
    }

    // 记录活动
    logActivity(type, message, payload) {
        const entry = {
            timestamp: Date.now(),
            type,
            message,
            payload
        };
        
        this.logs.push(entry);
        
        // 限制日志数量
        if (this.logs.length > 1000) {
            this.logs = this.logs.slice(-500);
        }
    }

    // 分析日志消息
    analyzeLogMessage(message) {
        // 提取国家信息
        const countryMatch = message.match(/([A-Z]{2})\) - (发送成功|发送失败)/);
        if (countryMatch) {
            const [, countryCode, status] = countryMatch;
            this.updateCountryProgress(countryCode, status === '发送成功');
        }
        
        // 检测错误模式
        if (message.includes('发送失败') || message.includes('❌')) {
            this.recordErrorPattern(message);
        }
        
        // 检测停滞模式
        if (message.includes('已有') && message.includes('秒没有进度更新')) {
            const timeMatch = message.match(/已有 (\d+) 秒没有进度更新/);
            if (timeMatch) {
                const stallTime = parseInt(timeMatch[1]) * 1000;
                this.handleStallDetection({ stallDuration: stallTime });
            }
        }
    }

    // 更新国家进度
    updateCountryProgress(countryCode, success) {
        if (!this.countryProgress.has(countryCode)) {
            this.countryProgress.set(countryCode, { success: 0, failure: 0, lastUpdate: Date.now() });
        }
        
        const progress = this.countryProgress.get(countryCode);
        if (success) {
            progress.success++;
        } else {
            progress.failure++;
        }
        progress.lastUpdate = Date.now();
    }

    // 记录错误模式
    recordErrorPattern(errorMessage) {
        // 提取错误类型
        let errorType = 'unknown';
        
        if (errorMessage.includes('网络错误') || errorMessage.includes('fetch')) {
            errorType = 'network';
        } else if (errorMessage.includes('超时') || errorMessage.includes('timeout')) {
            errorType = 'timeout';
        } else if (errorMessage.includes('中止') || errorMessage.includes('Abort')) {
            errorType = 'abort';
        } else if (errorMessage.includes('CORS')) {
            errorType = 'cors';
        }
        
        const count = this.errorPatterns.get(errorType) || 0;
        this.errorPatterns.set(errorType, count + 1);
    }

    // 更新进度
    updateProgress(payload) {
        console.log('📊 进度更新:', payload);
    }

    // 处理停滞检测
    handleStallDetection(payload) {
        console.warn('🚨 检测到发送停滞:', payload);
        
        // 分析可能的原因
        const analysis = this.analyzeStallCause();
        console.log('🔍 停滞原因分析:', analysis);
        
        // 提供修复建议
        const suggestions = this.getSuggestions(analysis);
        console.log('💡 修复建议:', suggestions);
    }

    // 分析停滞原因
    analyzeStallCause() {
        const now = Date.now();
        const timeSinceStart = now - this.startTime;
        const timeSinceLastActivity = now - this.lastActivityTime;
        
        const analysis = {
            runtime: timeSinceStart,
            stallDuration: timeSinceLastActivity,
            totalCountries: this.countryProgress.size,
            successfulCountries: 0,
            failedCountries: 0,
            errorPatterns: Object.fromEntries(this.errorPatterns),
            possibleCauses: []
        };
        
        // 统计成功和失败的国家
        for (const [country, progress] of this.countryProgress) {
            if (progress.success > 0) analysis.successfulCountries++;
            if (progress.failure > 0) analysis.failedCountries++;
        }
        
        // 分析可能的原因
        if (analysis.errorPatterns.network > 10) {
            analysis.possibleCauses.push('网络连接问题');
        }
        
        if (analysis.errorPatterns.timeout > 5) {
            analysis.possibleCauses.push('请求超时过多');
        }
        
        if (analysis.errorPatterns.abort > 0) {
            analysis.possibleCauses.push('请求被意外中止');
        }
        
        if (analysis.stallDuration > this.stallThreshold) {
            analysis.possibleCauses.push('Worker 可能已停止工作');
        }
        
        if (analysis.successfulCountries === 0 && analysis.totalCountries > 0) {
            analysis.possibleCauses.push('所有请求都失败，可能是配置问题');
        }
        
        return analysis;
    }

    // 获取修复建议
    getSuggestions(analysis) {
        const suggestions = [];
        
        if (analysis.possibleCauses.includes('网络连接问题')) {
            suggestions.push('检查网络连接，考虑降低并发数');
        }
        
        if (analysis.possibleCauses.includes('请求超时过多')) {
            suggestions.push('增加请求超时时间，检查服务器响应速度');
        }
        
        if (analysis.possibleCauses.includes('请求被意外中止')) {
            suggestions.push('检查 AbortController 的使用，确保不会意外触发中止');
        }
        
        if (analysis.possibleCauses.includes('Worker 可能已停止工作')) {
            suggestions.push('重启 Service Worker 或重新开始发送任务');
        }
        
        if (analysis.possibleCauses.includes('所有请求都失败，可能是配置问题')) {
            suggestions.push('检查服务器配置和 CORS 设置');
        }
        
        if (suggestions.length === 0) {
            suggestions.push('尝试重启发送任务，如果问题持续，请检查浏览器控制台错误');
        }
        
        return suggestions;
    }

    // 启动监控
    startMonitoring() {
        setInterval(() => {
            const now = Date.now();
            const timeSinceLastActivity = now - this.lastActivityTime;
            
            if (timeSinceLastActivity > this.stallThreshold) {
                console.warn(`⚠️ 检测到 ${Math.round(timeSinceLastActivity / 1000)} 秒无活动`);
                this.handleStallDetection({ stallDuration: timeSinceLastActivity });
            }
        }, 30000); // 每30秒检查一次
    }

    // 生成诊断报告
    generateReport() {
        const now = Date.now();
        const runtime = now - this.startTime;
        
        const report = {
            timestamp: new Date().toISOString(),
            runtime: runtime,
            totalLogs: this.logs.length,
            countryProgress: Object.fromEntries(this.countryProgress),
            errorPatterns: Object.fromEntries(this.errorPatterns),
            recentLogs: this.logs.slice(-20),
            analysis: this.analyzeStallCause()
        };
        
        return report;
    }

    // 导出诊断数据
    exportDiagnostics() {
        const report = this.generateReport();
        const blob = new Blob([JSON.stringify(report, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `sending-diagnostics-${new Date().toISOString().slice(0, 19).replace(/:/g, '-')}.json`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        
        console.log('📋 诊断报告已导出');
        return report;
    }

    // 自动修复尝试
    attemptAutoFix() {
        console.log('🔧 尝试自动修复...');
        
        const analysis = this.analyzeStallCause();
        
        // 如果检测到停滞，尝试重启
        if (analysis.stallDuration > this.stallThreshold) {
            console.log('🔄 尝试重启发送任务...');
            if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
                navigator.serviceWorker.controller.postMessage({ command: 'restart' });
                return true;
            }
        }
        
        return false;
    }
}

// 全局诊断实例
window.sendingDiagnostics = new SendingDiagnostics();

// 自动启动诊断（如果在发送页面）
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        if (window.location.pathname.includes('index.html') || 
            window.location.pathname.includes('test-sending-fix.html')) {
            window.sendingDiagnostics.startDiagnosis();
        }
    });
} else {
    if (window.location.pathname.includes('index.html') || 
        window.location.pathname.includes('test-sending-fix.html')) {
        window.sendingDiagnostics.startDiagnosis();
    }
}

console.log('🔍 发送诊断脚本已加载');
console.log('使用 window.sendingDiagnostics.exportDiagnostics() 导出诊断报告');
console.log('使用 window.sendingDiagnostics.attemptAutoFix() 尝试自动修复');