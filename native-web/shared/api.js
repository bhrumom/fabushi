/**
 * 全局法布施API客户端
 * 用于在不同平台间共享的API调用逻辑
 */

class FabushiAPI {
  constructor() {
    // 在Web应用中，这些环境变量会从Cloudflare Workers中获取
    // 在移动端和桌面端应用中，我们需要配置API的基础URL
    this.baseURL = typeof process !== 'undefined' && process.env.REACT_APP_API_URL 
      ? process.env.REACT_APP_API_URL 
      : typeof window !== 'undefined' && window.location 
        ? window.location.origin 
        : 'https://your-fabushi-worker.your-subdomain.workers.dev';
    
    this.token = null;
  }

  /**
   * 设置认证令牌
   * @param {string} token - JWT令牌
   */
  setToken(token) {
    this.token = token;
  }

  /**
   * 清除认证令牌
   */
  clearToken() {
    this.token = null;
  }

  /**
   * 通用API请求方法
   * @param {string} endpoint - API端点
   * @param {Object} options - 请求选项
   * @returns {Promise} API响应
   */
  async request(endpoint, options = {}) {
    const url = `${this.baseURL}${endpoint}`;
    
    const config = {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers
      },
      ...options
    };

    if (this.token) {
      config.headers.Authorization = `Bearer ${this.token}`;
    }

    try {
      const response = await fetch(url, config);
      
      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.message || `HTTP Error: ${response.status}`);
      }
      
      return await response.json();
    } catch (error) {
      console.error('API请求失败:', error);
      throw error;
    }
  }

  /**
   * 用户注册
   * @param {Object} userData - 用户数据
   * @returns {Promise} 注册结果
   */
  async register(userData) {
    return this.request('/api/auth/register', {
      method: 'POST',
      body: JSON.stringify(userData)
    });
  }

  /**
   * 用户登录
   * @param {Object} credentials - 登录凭据
   * @returns {Promise} 登录结果
   */
  async login(credentials) {
    return this.request('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify(credentials)
    });
  }

  /**
   * 获取用户信息
   * @returns {Promise} 用户信息
   */
  async getUserInfo() {
    return this.request('/api/auth/me');
  }

  /**
   * 检查会员状态
   * @returns {Promise} 会员状态
   */
  async checkMembership() {
    return this.request('/api/alipay/check-membership');
  }

  /**
   * 获取内置资源列表
   * @returns {Promise} 资源列表
   */
  async getDharmaAssets() {
    // 在移动端和桌面端，我们可能需要从不同的源获取这些数据
    // 这里先返回一个Promise，实际实现时可能需要调整
    return typeof window !== 'undefined' && window.dharmaAssets 
      ? window.dharmaAssets 
      : Promise.resolve({});
  }

  /**
   * 获取国家服务器信息
   * @returns {Promise} 国家服务器信息
   */
  async getCountryServers() {
    // 在移动端和桌面端，我们可能需要从不同的源获取这些数据
    return typeof window !== 'undefined' && window.globalCountryServers 
      ? {
          servers: window.globalCountryServers.servers,
          countryNames: window.globalCountryServers.countryNames,
          getAllCountries: window.globalCountryServers.getAllCountries.bind(window.globalCountryServers)
        }
      : Promise.resolve({
          servers: {},
          countryNames: {},
          getAllCountries: () => []
        });
  }

  /**
   * 发送文件到所有国家
   * @param {Object} fileData - 文件数据
   * @returns {Promise} 发送结果
   */
  async sendToAllCountries(fileData) {
    return this.request('/api/send/all-countries', {
      method: 'POST',
      body: fileData instanceof FormData ? fileData : JSON.stringify(fileData)
    });
  }
}

// 创建单例实例
const apiClient = new FabushiAPI();

// 导出API客户端
export default apiClient;

// 导出类，以便在需要时创建新实例
export { FabushiAPI };