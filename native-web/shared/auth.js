/**
 * 认证管理模块
 * 用于在不同平台间共享的用户认证和会员认证逻辑
 */

import apiClient from './api.js';

/**
 * 认证管理器
 */
export class AuthManager {
    constructor() {
        this.currentUser = null;
        this.token = null;
        this.listeners = [];
    }
    
    /**
     * 用户注册
     * @param {Object} userData - 用户数据
     * @returns {Promise<Object>} 注册结果
     */
    async register(userData) {
        try {
            const result = await apiClient.register(userData);
            return { success: true, data: result };
        } catch (error) {
            return { success: false, error: error.message };
        }
    }
    
    /**
     * 用户登录
     * @param {Object} credentials - 登录凭据
     * @returns {Promise<Object>} 登录结果
     */
    async login(credentials) {
        try {
            const result = await apiClient.login(credentials);
            this.token = result.token;
            apiClient.setToken(this.token);
            
            // 获取用户信息
            this.currentUser = await apiClient.getUserInfo();
            
            // 通知监听器
            this.notifyListeners('login', this.currentUser);
            
            return { success: true, data: result };
        } catch (error) {
            return { success: false, error: error.message };
        }
    }
    
    /**
     * 用户登出
     */
    logout() {
        this.token = null;
        this.currentUser = null;
        apiClient.clearToken();
        
        // 通知监听器
        this.notifyListeners('logout');
    }
    
    /**
     * 检查用户是否已登录
     * @returns {boolean} 是否已登录
     */
    isLoggedIn() {
        return !!this.token && !!this.currentUser;
    }
    
    /**
     * 获取当前用户信息
     * @returns {Object|null} 当前用户信息
     */
    getCurrentUser() {
        return this.currentUser;
    }
    
    /**
     * 获取认证令牌
     * @returns {string|null} 认证令牌
     */
    getToken() {
        return this.token;
    }
    
    /**
     * 检查会员状态
     * @returns {Promise<Object>} 会员状态
     */
    async checkMembership() {
        if (!this.isLoggedIn()) {
            return { isActive: false, type: 'none', expiresAt: null, daysLeft: 0 };
        }
        
        try {
            const result = await apiClient.checkMembership();
            return result.membership || { isActive: false, type: 'none', expiresAt: null, daysLeft: 0 };
        } catch (error) {
            console.error('检查会员状态时发生错误:', error);
            return { isActive: false, type: 'none', expiresAt: null, daysLeft: 0 };
        }
    }
    
    /**
     * 添加认证状态监听器
     * @param {Function} listener - 监听器函数
     */
    addListener(listener) {
        this.listeners.push(listener);
    }
    
    /**
     * 移除认证状态监听器
     * @param {Function} listener - 监听器函数
     */
    removeListener(listener) {
        this.listeners = this.listeners.filter(l => l !== listener);
    }
    
    /**
     * 通知监听器
     * @param {string} event - 事件类型
     * @param {Object} data - 事件数据
     */
    notifyListeners(event, data) {
        this.listeners.forEach(listener => {
            try {
                listener(event, data);
            } catch (error) {
                console.error('调用监听器时发生错误:', error);
            }
        });
    }
    
    /**
     * 从本地存储恢复会话
     * @returns {Promise<boolean>} 是否成功恢复
     */
    async restoreSession() {
        // 在Web应用中，我们可以从localStorage或cookie中恢复会话
        // 在移动端和桌面端应用中，我们需要使用相应的存储机制
        if (typeof localStorage !== 'undefined') {
            const token = localStorage.getItem('fabushi_token');
            const user = localStorage.getItem('fabushi_user');
            
            if (token && user) {
                try {
                    this.token = token;
                    this.currentUser = JSON.parse(user);
                    apiClient.setToken(token);
                    
                    // 验证令牌是否仍然有效
                    await apiClient.getUserInfo();
                    
                    // 通知监听器
                    this.notifyListeners('login', this.currentUser);
                    
                    return true;
                } catch (error) {
                    console.error('恢复会话时发生错误:', error);
                    this.logout();
                }
            }
        }
        
        return false;
    }
    
    /**
     * 保存会话到本地存储
     */
    saveSession() {
        if (typeof localStorage !== 'undefined') {
            if (this.token && this.currentUser) {
                localStorage.setItem('fabushi_token', this.token);
                localStorage.setItem('fabushi_user', JSON.stringify(this.currentUser));
            } else {
                localStorage.removeItem('fabushi_token');
                localStorage.removeItem('fabushi_user');
            }
        }
    }
}

/**
 * 会员状态检查工具
 * @param {Object} user - 用户对象
 * @returns {Object} 会员状态
 */
export function checkMembershipStatus(user) {
    const now = new Date();
    
    // 检查免费试用期
    if (user.freeTrialEndDate) {
        const trialEnd = new Date(user.freeTrialEndDate);
        if (now <= trialEnd) {
            return {
                isActive: true,
                type: 'trial',
                expiresAt: trialEnd,
                daysLeft: Math.ceil((trialEnd - now) / (1000 * 60 * 60 * 24))
            };
        }
    }
    
    // 检查付费会员
    const membershipEndDate = user.membershipExpiresAt;
    if (membershipEndDate) {
        const membershipEnd = new Date(membershipEndDate);
        if (now <= membershipEnd) {
            // 根据会员类型返回正确的类型
            const membershipType = user.membershipType === 'trial' ? 'trial' : 'paid';
            return {
                isActive: true,
                type: membershipType,
                expiresAt: membershipEnd,
                daysLeft: Math.ceil((membershipEnd - now) / (1000 * 60 * 60 * 24))
            };
        }
    }
    
    return {
        isActive: false,
        type: 'none',
        expiresAt: null,
        daysLeft: 0
    };
}

/**
 * 计算免费试用结束时间
 * @param {Date} startDate - 开始日期
 * @returns {Date} 结束日期
 */
export function calculateTrialEndDate(startDate = new Date()) {
    const endDate = new Date(startDate);
    endDate.setDate(endDate.getDate() + 3); // 3天免费试用
    return endDate;
}

// 创建并导出默认实例
const authManager = new AuthManager();
export default authManager;