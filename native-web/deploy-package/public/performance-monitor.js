// 性能监控工具 - v1.0
// 监控内存使用、CPU占用和网络状态，帮助用户优化发送参数

class PerformanceMonitor {
    constructor() {
        this.isMonitoring = false;
        this.memoryStats = [];
        this.networkStats = [];
        this.maxMemoryUsage = 0;
        this.startTime = 0;
        
        this.initMonitoring();
    }
    
    initMonitoring() {
        // 每5秒收集一次性能数据
        setInterval(() => {
            if (this.isMonitoring) {
                this.collectStats();
            }
        }, 5000);
    }
    
    startMonitoring() {
        this.isMonitoring = true;
        this.startTime = Date.now();
        this.memoryStats = [];
        this.networkStats = [];
        this.maxMemoryUsage = 0;
        console.log('📊 性能监控已启动');
    }
    
    stopMonitoring() {
        this.isMonitoring = false;
        this.generateReport();
    }
    
    collectStats() {
        // 收集内存使用情况
        if (performance.memory) {
            const memoryInfo = {
                timestamp: Date.now(),
                used: performance.memory.usedJSHeapSize,
                total: performance.memory.totalJSHeapSize,
                limit: performance.memory.jsHeapSizeLimit
            };
            
            this.memoryStats.push(memoryInfo);
            this.maxMemoryUsage = Math.max(this.maxMemoryUsage, memoryInfo.used);
            
            // 内存使用超过80%时发出警告
            const memoryUsagePercent = (memoryInfo.used / memoryInfo.limit) * 100;
            if (memoryUsagePercent > 80) {
                console.warn(`⚠️ 内存使用率过高: ${memoryUsagePercent.toFixed(1)}%`);
                this.suggestOptimization('memory');
            }
        }
        
        // 收集网络连接信息
        if (navigator.connection) {
            const connectionInfo = {
                timestamp: Date.now(),
                effectiveType: navigator.connection.effectiveType,
                downlink: navigator.connection.downlink,
                rtt: navigator.connection.rtt
            };
            
            this.networkStats.push(connectionInfo);
            
            // 网络较慢时建议降低并发数
            if (connectionInfo.effectiveType === 'slow-2g' || connectionInfo.effectiveType === '2g') {
                this.suggestOptimization('network');
            }
        }
    }
    
    suggestOptimization(type) {
        const suggestions = {
            memory: [
                '🔧 建议降低并发数到 1-2',
                '🧹 点击"清理文件缓存"释放内存',
                '📱 关闭其他占用内存的应用程序',
                '⏸️ 暂停发送，让设备休息片刻'
            ],
            network: [
                '🐌 检测到网络较慢，建议降低并发数到 1',
                '📶 尝试切换到更稳定的网络连接',
                '⏳ 增加循环间隔时间',
                '🎯 选择较小的文件进行发送'
            ]
        };
        
        const typeSuggestions = suggestions[type] || [];
        console.log(`💡 性能优化建议 (${type}):`);
        typeSuggestions.forEach(suggestion => console.log(`  ${suggestion}`));
    }
    
    generateReport() {
        if (this.memoryStats.length === 0) return;
        
        const duration = (Date.now() - this.startTime) / 1000;
        const avgMemoryUsage = this.memoryStats.reduce((sum, stat) => sum + stat.used, 0) / this.memoryStats.length;
        
        console.log('\n📈 性能监控报告');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log(`⏱️ 监控时长: ${duration.toFixed(1)} 秒`);
        console.log(`💾 平均内存使用: ${(avgMemoryUsage / 1024 / 1024).toFixed(1)} MB`);
        console.log(`📊 峰值内存使用: ${(this.maxMemoryUsage / 1024 / 1024).toFixed(1)} MB`);
        
        if (this.networkStats.length > 0) {
            const latestNetwork = this.networkStats[this.networkStats.length - 1];
            console.log(`📶 网络类型: ${latestNetwork.effectiveType}`);
            console.log(`⬇️ 下行速度: ${latestNetwork.downlink} Mbps`);
            console.log(`🔄 网络延迟: ${latestNetwork.rtt} ms`);
        }
        
        // 生成优化建议
        this.generateOptimizationSuggestions();
    }
    
    generateOptimizationSuggestions() {
        console.log('\n💡 优化建议:');
        
        const memoryUsagePercent = (this.maxMemoryUsage / performance.memory.jsHeapSizeLimit) * 100;
        
        if (memoryUsagePercent > 70) {
            console.log('🔴 内存使用率较高，建议:');
            console.log('  • 降低并发数到 1-3');
            console.log('  • 定期清理文件缓存');
            console.log('  • 避免同时发送大文件');
        } else if (memoryUsagePercent > 50) {
            console.log('🟡 内存使用适中，建议:');
            console.log('  • 并发数保持在 3-6');
            console.log('  • 可以适当增加文件数量');
        } else {
            console.log('🟢 内存使用良好，可以:');
            console.log('  • 适当提高并发数到 6-10');
            console.log('  • 同时发送多个文件');
        }
        
        if (this.networkStats.length > 0) {
            const latestNetwork = this.networkStats[this.networkStats.length - 1];
            if (latestNetwork.rtt > 500) {
                console.log('🔴 网络延迟较高，建议降低并发数');
            } else if (latestNetwork.rtt > 200) {
                console.log('🟡 网络延迟适中，保持当前设置');
            } else {
                console.log('🟢 网络状况良好，可以提高效率');
            }
        }
        
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    }
    
    // 获取当前系统状态
    getCurrentStatus() {
        if (!performance.memory) {
            return { status: 'unknown', message: '无法获取性能信息' };
        }
        
        const memoryUsagePercent = (performance.memory.usedJSHeapSize / performance.memory.jsHeapSizeLimit) * 100;
        
        if (memoryUsagePercent > 80) {
            return { 
                status: 'critical', 
                message: `内存使用率 ${memoryUsagePercent.toFixed(1)}% - 建议立即降低并发数`,
                color: '#ff4757'
            };
        } else if (memoryUsagePercent > 60) {
            return { 
                status: 'warning', 
                message: `内存使用率 ${memoryUsagePercent.toFixed(1)}% - 建议适度降低并发数`,
                color: '#ffa502'
            };
        } else {
            return { 
                status: 'good', 
                message: `内存使用率 ${memoryUsagePercent.toFixed(1)}% - 系统运行良好`,
                color: '#2ed573'
            };
        }
    }
}

// 创建全局性能监控实例
window.performanceMonitor = new PerformanceMonitor();

// 在发送开始时启动监控
document.addEventListener('DOMContentLoaded', () => {
    const originalStartSending = window.GlobalDharmaSender?.prototype?.startSending;
    if (originalStartSending) {
        window.GlobalDharmaSender.prototype.startSending = function() {
            window.performanceMonitor.startMonitoring();
            return originalStartSending.call(this);
        };
    }
    
    const originalStopSending = window.GlobalDharmaSender?.prototype?.stopSending;
    if (originalStopSending) {
        window.GlobalDharmaSender.prototype.stopSending = function(isFinished) {
            window.performanceMonitor.stopMonitoring();
            return originalStopSending.call(this, isFinished);
        };
    }
});

console.log('📊 性能监控工具已加载');