/**
 * 发送循环中断问题修复脚本
 * 专门解决发送到第7轮后停止的问题
 */

class LoopInterruptionFixer {
    constructor() {
        this.isActive = false;
        this.loopMonitor = null;
        this.lastLoopProgress = null;
        this.consecutiveStallCount = 0;
        this.recoveryAttempts = 0;
        
        // 优化：只在错误时输出日志
        console.log('🔧 循环中断修复器已初始化');
    }

    // 启动循环监控
    startMonitoring() {
        if (this.isActive) return;
        
        this.isActive = true;
        this.lastLoopProgress = Date.now();
        this.consecutiveStallCount = 0;
        this.recoveryAttempts = 0;
        
        // 优化：只记录重要状态，移除启动信息
        // console.log('🔍 开始监控循环进度...');
        
        // 监听 Service Worker 消息
        if ('serviceWorker' in navigator) {
            navigator.serviceWorker.addEventListener('message', this.handleServiceWorkerMessage.bind(this));
        }
        
        // 启动循环监控
        this.loopMonitor = setInterval(() => {
            this.checkLoopProgress();
        }, 30000); // 每30秒检查一次
        
        // 优化：仅记录重要状态，成功信息不输出到控制台
        this.updateCountryStatus('monitoring', 'started');
        // 移除监控启动的日志输出，只在出现错误时输出
        // console.log('✅ 循环监控已启动');
    }

    // 停止监控
    stopMonitoring() {
        if (!this.isActive) return;
        
        this.isActive = false;
        
        if (this.loopMonitor) {
            clearInterval(this.loopMonitor);
            this.loopMonitor = null;
        }
        
        // 优化：仅记录停止状态，移除日志输出
        this.updateCountryStatus('monitoring', 'stopped');
        // 移除监控停止的日志输出，只在出现错误时输出
        // console.log('⏹️ 循环监控已停止');
    }

    // 处理 Service Worker 消息
    handleServiceWorkerMessage(event) {
        if (!this.isActive) return;
        
        const { type, payload } = event.data;
        
        // 监控循环相关的消息
        if (type === 'progress' || 
            type === 'cycleComplete' || 
            (type === 'log' && payload?.message?.includes('轮'))) {
            
            this.lastLoopProgress = Date.now();
            this.consecutiveStallCount = 0;
            
            // 优化：循环进度只记录到国家状态，不输出控制台
            if (type === 'progress' && payload?.cycle) {
                this.updateCountryStatus('progress', {
                    cycle: payload.cycle,
                    timestamp: Date.now()
                });
                // 不再输出到控制台，减少日志噪音
            }
        }

        // 特别监控循环延迟消息
        if (type === 'log' && payload?.message) {
            const message = payload.message;
            
            // 优化：延迟信息记录到状态，不输出控制台
            if (message.includes('开始循环延迟')) {
                this.updateCountryStatus('delay', 'started');
                this.lastLoopProgress = Date.now();
                // 不再输出到控制台
            }
            
            // 检测循环延迟完成
            if (message.includes('循环延迟完成')) {
                this.updateCountryStatus('delay', 'completed');
                this.lastLoopProgress = Date.now();
                this.consecutiveStallCount = 0;
                // 不再输出到控制台
            }
            
            // 检测可能的卡住情况
            if (message.includes('DOM节点过多') && this.consecutiveStallCount > 2) {
                console.warn('🚨 检测到可能的DOM过载导致的卡住');
                this.attemptRecovery('dom_overload');
            }
        }
    }

    // 检查循环进度
    checkLoopProgress() {
        if (!this.isActive) return;
        
        const now = Date.now();
        const timeSinceLastProgress = now - this.lastLoopProgress;
        
        // 如果超过2分钟没有进度更新，认为可能卡住了
        if (timeSinceLastProgress > 120000) { // 2分钟
            this.consecutiveStallCount++;
            // 优化：只输出警告和错误信息
            if (this.consecutiveStallCount >= 3) {
                console.error(`⚠️ 循环进度停滞 (${this.consecutiveStallCount}/3): ${Math.floor(timeSinceLastProgress/1000)}秒无更新`);
                console.error('🆘 循环严重停滞，尝试恢复...');
                this.attemptRecovery('loop_stall');
            }
        }
    }

    // 尝试恢复
    async attemptRecovery(reason) {
        if (this.recoveryAttempts >= 3) {
            console.error('❌ 恢复尝试次数已达上限，停止恢复');
            return;
        }
        
        this.recoveryAttempts++;
        // 优化：恢复过程只输出错误，成功信息记录到状态
        console.error(`🔄 开始第${this.recoveryAttempts}次恢复尝试 (原因: ${reason})`);
        
        try {
            // 1. 强制内存清理
            this.updateCountryStatus('recovery', 'memory_cleanup');
            
            // 2. 通知 Service Worker 进行清理
            if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
                navigator.serviceWorker.controller.postMessage({
                    type: 'MEMORY_CLEANUP',
                    data: { reason: 'loop_recovery', attempt: this.recoveryAttempts }
                });
            }
            
            // 3. 等待一段时间让清理完成
            await new Promise(resolve => setTimeout(resolve, 3000));
            
            // 4. 强制垃圾回收
            if (window.gc) {
                window.gc();
                this.updateCountryStatus('recovery', 'gc_completed');
            }
            
            // 5. 重置监控状态
            this.lastLoopProgress = Date.now();
            this.consecutiveStallCount = 0;
            
            // 优化：成功信息只记录到状态，不输出到控制台
            this.updateCountryStatus('recovery', 'completed');
            
        } catch (error) {
            console.error(`❌ 恢复尝试失败: ${error.message}`);
        }
    }

    // 获取监控状态
    getStatus() {
        return {
            isActive: this.isActive,
            lastProgress: this.lastLoopProgress,
            stallCount: this.consecutiveStallCount,
            recoveryAttempts: this.recoveryAttempts,
            timeSinceLastProgress: Date.now() - this.lastLoopProgress
        };
    }

    // 手动触发恢复
    manualRecovery() {
        console.error('🔧 手动触发恢复...'); // 作为用户操作，保留日志
        this.attemptRecovery('manual_trigger');
    }

    // 重置监控状态
    reset() {
        this.lastLoopProgress = Date.now();
        this.consecutiveStallCount = 0;
        this.recoveryAttempts = 0;
        // 优化：重置信息记录到状态，不输出控制台
        this.updateCountryStatus('monitoring', 'reset');
        // 移除重置的日志输出，只在出现错误时输出
    }

    // 优化：新增国家状态更新方法，统一管理状态记录
    updateCountryStatus(type, status) {
        if (!this.countryStatusCache) {
            this.countryStatusCache = new Map();
        }
        
        this.countryStatusCache.set(type, {
            status: status,
            timestamp: Date.now(),
            lastUpdate: new Date().toLocaleTimeString()
        });
        
        // 只在发生错误时才输出到控制台
        if (typeof status === 'string' && (status.includes('failed') || status.includes('error'))) {
            console.error(`❌ 状态更新: ${type} - ${status}`);
        }
    }

    // 获取国家状态缓存
    getCountryStatusCache() {
        return this.countryStatusCache || new Map();
    }
}

// 全局实例
window.loopInterruptionFixer = new LoopInterruptionFixer();

// 自动启动（在发送页面）
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        if (window.location.pathname.includes('index.html') || 
            window.location.pathname === '/') {
            window.loopInterruptionFixer.startMonitoring();
        }
    });
} else {
    if (window.location.pathname.includes('index.html') || 
        window.location.pathname === '/') {
        window.loopInterruptionFixer.startMonitoring();
    }
}

// 页面卸载时停止监控
window.addEventListener('beforeunload', () => {
    if (window.loopInterruptionFixer) {
        window.loopInterruptionFixer.stopMonitoring();
    }
});

// 导出工具函数供手动使用
window.loopFixerUtils = {
    getStatus: () => window.loopInterruptionFixer.getStatus(),
    manualRecovery: () => window.loopInterruptionFixer.manualRecovery(),
    reset: () => window.loopInterruptionFixer.reset(),
    restart: () => {
        window.loopInterruptionFixer.stopMonitoring();
        setTimeout(() => {
            window.loopInterruptionFixer.startMonitoring();
        }, 1000);
    }
};

// 优化：移除加载信息输出
// console.log('🔧 循环中断修复脚本已加载 (已优化日志输出)');
// 工具信息仅在调试时输出
if (window.location.search.includes('debug=true')) {
    console.log('使用 window.loopFixerUtils.getStatus() 查看状态');
    console.log('使用 window.loopFixerUtils.manualRecovery() 手动恢复');
}