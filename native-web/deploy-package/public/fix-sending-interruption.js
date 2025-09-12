/**
 * 修复发送中途停止问题的解决方案
 * 解决内存泄漏、网络超时、Service Worker生命周期等问题
 */

class SendingInterruptionFixer {
    constructor() {
        this.isActive = false;
        this.heartbeatInterval = null;
        this.memoryMonitor = null;
        this.progressBackup = new Map();
        this.retryQueue = [];
        this.maxRetries = 3;
        this.heartbeatFrequency = 30000; // 30秒心跳
        this.memoryCheckInterval = 60000; // 1分钟内存检查
        this.maxMemoryUsage = 500 * 1024 * 1024; // 500MB内存限制
    }

    /**
     * 启动发送保护机制
     */
    startProtection() {
        if (this.isActive) return;
        
        this.isActive = true;
        console.log('🛡️ 发送保护机制已启动');
        
        // 启动心跳检测
        this.startHeartbeat();
        
        // 启动内存监控
        this.startMemoryMonitor();
        
        // 监听页面可见性变化
        this.setupVisibilityListener();
        
        // 监听网络状态变化
        this.setupNetworkListener();
        
        // 设置Service Worker消息监听
        this.setupServiceWorkerListener();
    }

    /**
     * 停止保护机制
     */
    stopProtection() {
        this.isActive = false;
        
        if (this.heartbeatInterval) {
            clearInterval(this.heartbeatInterval);
            this.heartbeatInterval = null;
        }
        
        if (this.memoryMonitor) {
            clearInterval(this.memoryMonitor);
            this.memoryMonitor = null;
        }
        
        console.log('🛡️ 发送保护机制已停止');
    }

    /**
     * 启动心跳检测
     */
    startHeartbeat() {
        this.heartbeatInterval = setInterval(() => {
            if (!this.isActive) return;
            
            // 向Service Worker发送心跳
            this.sendHeartbeat();
            
            // 检查发送状态
            this.checkSendingStatus();
            
        }, this.heartbeatFrequency);
    }

    /**
     * 发送心跳到Service Worker
     */
    async sendHeartbeat() {
        try {
            if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
                navigator.serviceWorker.controller.postMessage({
                    type: 'HEARTBEAT',
                    timestamp: Date.now()
                });
            }
        } catch (error) {
            console.warn('❤️ 心跳发送失败:', error);
        }
    }

    /**
     * 检查发送状态
     */
    checkSendingStatus() {
        // 检查是否有长时间无响应的任务
        const now = Date.now();
        for (const [taskId, progress] of this.progressBackup) {
            if (now - progress.lastUpdate > 300000) { // 5分钟无更新
                console.warn('⚠️ 检测到可能停滞的任务:', taskId);
                this.handleStuckTask(taskId, progress);
            }
        }
    }

    /**
     * 处理停滞的任务
     */
    async handleStuckTask(taskId, progress) {
        console.log('🔄 尝试恢复停滞任务:', taskId);
        
        // 添加到重试队列
        this.retryQueue.push({
            taskId,
            progress,
            retryCount: 0,
            timestamp: Date.now()
        });
        
        // 尝试重启任务
        await this.restartTask(taskId, progress);
    }

    /**
     * 重启任务
     */
    async restartTask(taskId, progress) {
        try {
            if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
                navigator.serviceWorker.controller.postMessage({
                    type: 'RESTART_TASK',
                    taskId,
                    progress
                });
            }
        } catch (error) {
            console.error('❌ 任务重启失败:', error);
        }
    }

    /**
     * 启动内存监控
     */
    startMemoryMonitor() {
        this.memoryMonitor = setInterval(() => {
            this.checkMemoryUsage();
        }, this.memoryCheckInterval);
    }

    /**
     * 检查内存使用情况
     */
    checkMemoryUsage() {
        if ('memory' in performance) {
            const memInfo = performance.memory;
            const usedMemory = memInfo.usedJSHeapSize;
            const totalMemory = memInfo.totalJSHeapSize;
            const memoryLimit = memInfo.jsHeapSizeLimit;
            
            console.log(`💾 内存使用: ${(usedMemory / 1024 / 1024).toFixed(1)}MB / ${(totalMemory / 1024 / 1024).toFixed(1)}MB`);
            
            // 如果内存使用超过阈值，触发清理
            if (usedMemory > this.maxMemoryUsage || usedMemory / memoryLimit > 0.8) {
                console.warn('⚠️ 内存使用过高，触发清理');
                this.triggerMemoryCleanup();
            }
        }
    }

    /**
     * 触发内存清理
     */
    async triggerMemoryCleanup() {
        try {
            // 通知Service Worker进行内存清理
            if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
                navigator.serviceWorker.controller.postMessage({
                    type: 'MEMORY_CLEANUP'
                });
            }
            
            // 主线程内存清理
            
            // 强制垃圾回收（如果可用）
            if (window.gc) {
                window.gc();
            }
            
            console.log('🧹 内存清理完成');
        } catch (error) {
            console.error('❌ 内存清理失败:', error);
        }
    }

    /**
     * 设置页面可见性监听
     */
    setupVisibilityListener() {
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                console.log('👁️ 页面隐藏，保存发送状态');
                this.saveProgressState();
            } else {
                console.log('👁️ 页面显示，恢复发送状态');
                this.restoreProgressState();
            }
        });
    }

    /**
     * 设置网络状态监听
     */
    setupNetworkListener() {
        window.addEventListener('online', () => {
            console.log('🌐 网络已连接，恢复发送');
            this.resumeSending();
        });
        
        window.addEventListener('offline', () => {
            console.log('🌐 网络已断开，暂停发送');
            this.pauseSending();
        });
    }

    /**
     * 设置Service Worker消息监听
     */
    setupServiceWorkerListener() {
        if ('serviceWorker' in navigator) {
            navigator.serviceWorker.addEventListener('message', (event) => {
                const { type, data } = event.data;
                
                switch (type) {
                    case 'PROGRESS_UPDATE':
                        this.updateProgress(data);
                        break;
                    case 'TASK_COMPLETED':
                        this.handleTaskCompleted(data);
                        break;
                    case 'TASK_FAILED':
                        this.handleTaskFailed(data);
                        break;
                    case 'MEMORY_WARNING':
                        this.handleMemoryWarning(data);
                        break;
                }
            });
        }
    }

    /**
     * 更新进度
     */
    updateProgress(data) {
        const { taskId, progress } = data;
        this.progressBackup.set(taskId, {
            ...progress,
            lastUpdate: Date.now()
        });
    }

    /**
     * 处理任务完成
     */
    handleTaskCompleted(data) {
        const { taskId } = data;
        this.progressBackup.delete(taskId);
        console.log('✅ 任务完成:', taskId);
    }

    /**
     * 处理任务失败
     */
    handleTaskFailed(data) {
        const { taskId, error } = data;
        console.error('❌ 任务失败:', taskId, error);
        
        // 检查是否需要重试
        const retryItem = this.retryQueue.find(item => item.taskId === taskId);
        if (retryItem && retryItem.retryCount < this.maxRetries) {
            retryItem.retryCount++;
            console.log(`🔄 准备重试任务 ${taskId} (第${retryItem.retryCount}次)`);
            setTimeout(() => {
                this.restartTask(taskId, retryItem.progress);
            }, 5000 * retryItem.retryCount); // 递增延迟
        } else {
            console.error('💀 任务彻底失败:', taskId);
            this.progressBackup.delete(taskId);
        }
    }

    /**
     * 处理内存警告
     */
    handleMemoryWarning(data) {
        console.warn('⚠️ Service Worker内存警告:', data);
        this.triggerMemoryCleanup();
    }

    /**
     * 保存进度状态
     */
    saveProgressState() {
        try {
            const state = {
                progressBackup: Array.from(this.progressBackup.entries()),
                retryQueue: this.retryQueue,
                timestamp: Date.now()
            };
            localStorage.setItem('sendingState', JSON.stringify(state));
        } catch (error) {
            console.error('❌ 保存状态失败:', error);
        }
    }

    /**
     * 恢复进度状态
     */
    restoreProgressState() {
        try {
            const savedState = localStorage.getItem('sendingState');
            if (savedState) {
                const state = JSON.parse(savedState);
                this.progressBackup = new Map(state.progressBackup);
                this.retryQueue = state.retryQueue || [];
                console.log('📥 已恢复发送状态');
            }
        } catch (error) {
            console.error('❌ 恢复状态失败:', error);
        }
    }

    /**
     * 暂停发送
     */
    pauseSending() {
        if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
            navigator.serviceWorker.controller.postMessage({
                type: 'PAUSE_SENDING'
            });
        }
    }

    /**
     * 恢复发送
     */
    resumeSending() {
        if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
            navigator.serviceWorker.controller.postMessage({
                type: 'RESUME_SENDING'
            });
        }
    }

    /**
     * 获取发送统计
     */
    getSendingStats() {
        return {
            activeTasks: this.progressBackup.size,
            retryQueue: this.retryQueue.length,
            isActive: this.isActive,
            memoryUsage: 'memory' in performance ? performance.memory : null
        };
    }
}

// 创建全局实例
window.sendingFixer = new SendingInterruptionFixer();

// 自动启动保护机制
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        window.sendingFixer.startProtection();
    });
} else {
    window.sendingFixer.startProtection();
}

console.log('🛡️ 发送中断修复器已加载');
console.log('使用 window.sendingFixer.getSendingStats() 查看发送状态');
console.log('使用 window.sendingFixer.triggerMemoryCleanup() 手动清理内存');