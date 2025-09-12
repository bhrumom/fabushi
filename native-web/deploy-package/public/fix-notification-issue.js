/**
 * 锁屏通知问题修复脚本
 * 解决切换应用或锁屏时通知栏不显示发送进度的问题
 */

class NotificationFixer {
    constructor() {
        this.isFixing = false;
        this.notificationPermission = 'default';
        this.serviceWorkerReady = false;
    }

    /**
     * 初始化通知修复
     */
    async init() {
        console.log('🔧 开始修复锁屏通知问题...');
        
        // 1. 检查浏览器支持
        if (!this.checkBrowserSupport()) {
            return false;
        }

        // 2. 确保Service Worker就绪
        await this.ensureServiceWorkerReady();

        // 3. 修复通知权限传递
        await this.fixNotificationPermission();

        // 4. 增强通知更新机制
        this.enhanceNotificationUpdates();

        // 5. 添加页面可见性监听
        this.setupVisibilityListener();

        console.log('✅ 锁屏通知修复完成');
        return true;
    }

    /**
     * 检查浏览器支持
     */
    checkBrowserSupport() {
        if (!('Notification' in window)) {
            console.error('❌ 浏览器不支持通知功能');
            return false;
        }

        if (!('serviceWorker' in navigator)) {
            console.error('❌ 浏览器不支持Service Worker');
            return false;
        }

        console.log('✅ 浏览器支持检查通过');
        return true;
    }

    /**
     * 确保Service Worker就绪
     */
    async ensureServiceWorkerReady() {
        try {
            // 等待Service Worker注册完成
            const registration = await navigator.serviceWorker.ready;
            console.log('✅ Service Worker已就绪');

            // 确保有活跃的Service Worker
            if (!registration.active) {
                console.warn('⚠️ 没有活跃的Service Worker，尝试重新注册...');
                await navigator.serviceWorker.register('/service-worker.js');
                await navigator.serviceWorker.ready;
            }

            this.serviceWorkerReady = true;
            console.log('✅ Service Worker状态确认完成');
        } catch (error) {
            console.error('❌ Service Worker准备失败:', error);
            throw error;
        }
    }

    /**
     * 修复通知权限传递问题
     */
    async fixNotificationPermission() {
        try {
            // 检查当前权限状态
            let permission = Notification.permission;
            console.log('🔔 当前通知权限:', permission);

            // 如果权限未授予，主动请求
            if (permission === 'default') {
                console.log('🔔 正在请求通知权限...');
                permission = await Notification.requestPermission();
                console.log('🔔 通知权限请求结果:', permission);
            }

            this.notificationPermission = permission;

            // 立即通知Service Worker权限状态
            if (this.serviceWorkerReady && navigator.serviceWorker.controller) {
                const messageType = permission === 'granted' ? 
                    'NOTIFICATION_PERMISSION_GRANTED' : 
                    'NOTIFICATION_PERMISSION_DENIED';
                
                navigator.serviceWorker.controller.postMessage({
                    type: messageType
                });

                console.log(`✅ 已通知Service Worker权限状态: ${permission}`);
            }

            // 显示测试通知确认权限工作
            if (permission === 'granted') {
                this.showTestNotification();
            }

        } catch (error) {
            console.error('❌ 修复通知权限失败:', error);
        }
    }

    /**
     * 显示测试通知
     */
    showTestNotification() {
        try {
            const notification = new Notification('🔧 通知修复完成', {
                body: '锁屏通知功能已修复，现在可以在后台查看发送进度了',
                icon: '/favicon.ico',
                tag: 'notification-fix-test',
                requireInteraction: false,
                silent: true
            });

            notification.onclick = () => {
                window.focus();
                notification.close();
            };

            // 3秒后自动关闭
            setTimeout(() => {
                notification.close();
            }, 3000);

            console.log('✅ 测试通知已显示');
        } catch (error) {
            console.error('❌ 显示测试通知失败:', error);
        }
    }

    /**
     * 增强通知更新机制
     */
    enhanceNotificationUpdates() {
        // 监听Service Worker消息
        if (navigator.serviceWorker) {
            navigator.serviceWorker.addEventListener('message', (event) => {
                if (event.data.type === 'progress') {
                    this.handleProgressUpdate(event.data.payload);
                }
            });
        }

        // 定期检查通知权限状态
        setInterval(() => {
            this.checkNotificationStatus();
        }, 30000); // 每30秒检查一次

        console.log('✅ 通知更新机制已增强');
    }

    /**
     * 处理进度更新
     */
    handleProgressUpdate(payload) {
        // 确保在后台时也能更新通知
        if (document.hidden && this.notificationPermission === 'granted') {
            console.log('📱 页面在后台，确保通知更新...');
            
            // 向Service Worker发送强制更新通知的消息
            if (navigator.serviceWorker.controller) {
                navigator.serviceWorker.controller.postMessage({
                    type: 'FORCE_NOTIFICATION_UPDATE',
                    payload: payload
                });
            }
        }
    }

    /**
     * 检查通知状态
     */
    checkNotificationStatus() {
        const currentPermission = Notification.permission;
        
        if (currentPermission !== this.notificationPermission) {
            console.log(`🔔 通知权限状态变化: ${this.notificationPermission} -> ${currentPermission}`);
            this.notificationPermission = currentPermission;
            
            // 重新通知Service Worker
            if (navigator.serviceWorker.controller) {
                const messageType = currentPermission === 'granted' ? 
                    'NOTIFICATION_PERMISSION_GRANTED' : 
                    'NOTIFICATION_PERMISSION_DENIED';
                
                navigator.serviceWorker.controller.postMessage({
                    type: messageType
                });
            }
        }
    }

    /**
     * 设置页面可见性监听
     */
    setupVisibilityListener() {
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                console.log('📱 页面已隐藏，激活后台通知模式');
                this.activateBackgroundMode();
            } else {
                console.log('👁️ 页面重新可见，恢复前台模式');
                this.deactivateBackgroundMode();
            }
        });

        console.log('✅ 页面可见性监听已设置');
    }

    /**
     * 激活后台模式
     */
    activateBackgroundMode() {
        if (navigator.serviceWorker.controller) {
            navigator.serviceWorker.controller.postMessage({
                type: 'ACTIVATE_BACKGROUND_NOTIFICATIONS'
            });
        }
    }

    /**
     * 停用后台模式
     */
    deactivateBackgroundMode() {
        if (navigator.serviceWorker.controller) {
            navigator.serviceWorker.controller.postMessage({
                type: 'DEACTIVATE_BACKGROUND_NOTIFICATIONS'
            });
        }
    }

    /**
     * 手动触发通知测试
     */
    async testNotification() {
        if (this.notificationPermission !== 'granted') {
            console.warn('⚠️ 通知权限未授予，无法测试');
            return false;
        }

        // 发送测试消息给Service Worker
        if (navigator.serviceWorker.controller) {
            navigator.serviceWorker.controller.postMessage({
                type: 'TEST_NOTIFICATION',
                payload: {
                    title: '🧪 通知测试',
                    body: '这是一个测试通知，用于验证锁屏通知功能',
                    progress: 50,
                    fileName: '测试文件.txt'
                }
            });
            
            console.log('✅ 通知测试消息已发送');
            return true;
        }

        return false;
    }
}

// 创建全局实例
window.notificationFixer = new NotificationFixer();

// 自动初始化（如果页面已加载）
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        window.notificationFixer.init();
    });
} else {
    window.notificationFixer.init();
}

// 导出供其他脚本使用
if (typeof module !== 'undefined' && module.exports) {
    module.exports = NotificationFixer;
}

console.log('🔧 通知修复脚本已加载');