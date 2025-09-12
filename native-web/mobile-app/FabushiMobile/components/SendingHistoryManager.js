import AsyncStorage from '@react-native-async-storage/async-storage';

/**
 * 发送历史记录管理器
 * 用于管理用户的文件发送历史记录
 */
class SendingHistoryManager {
  constructor() {
    this.storageKey = 'fabushi_sending_history';
    this.maxHistoryItems = 100; // 最多保存100条记录
  }

  /**
   * 添加发送记录
   * @param {Object} record - 发送记录
   * @param {string} record.fileName - 文件名
   * @param {number} record.fileSize - 文件大小
   * @param {number} record.sentTime - 发送时间
   * @param {number} record.countriesCount - 发送到的国家数量
   * @param {boolean} record.success - 是否发送成功
   * @returns {Promise<void>}
   */
  async addRecord(record) {
    try {
      const history = await this.getHistory();
      
      // 添加新记录到开头
      const newRecord = {
        id: Date.now().toString(),
        ...record,
        sentTime: record.sentTime || Date.now(),
      };
      
      history.unshift(newRecord);
      
      // 限制历史记录数量
      if (history.length > this.maxHistoryItems) {
        history.splice(this.maxHistoryItems);
      }
      
      await AsyncStorage.setItem(this.storageKey, JSON.stringify(history));
    } catch (error) {
      console.error('添加发送记录失败:', error);
    }
  }

  /**
   * 获取发送历史记录
   * @returns {Promise<Array>} 发送历史记录数组
   */
  async getHistory() {
    try {
      const historyStr = await AsyncStorage.getItem(this.storageKey);
      return historyStr ? JSON.parse(historyStr) : [];
    } catch (error) {
      console.error('获取发送历史记录失败:', error);
      return [];
    }
  }

  /**
   * 清除所有发送历史记录
   * @returns {Promise<void>}
   */
  async clearHistory() {
    try {
      await AsyncStorage.removeItem(this.storageKey);
    } catch (error) {
      console.error('清除发送历史记录失败:', error);
    }
  }

  /**
   * 删除特定发送记录
   * @param {string} id - 记录ID
   * @returns {Promise<void>}
   */
  async deleteRecord(id) {
    try {
      const history = await this.getHistory();
      const filteredHistory = history.filter(record => record.id !== id);
      await AsyncStorage.setItem(this.storageKey, JSON.stringify(filteredHistory));
    } catch (error) {
      console.error('删除发送记录失败:', error);
    }
  }

  /**
   * 获取发送统计信息
   * @returns {Promise<Object>} 统计信息
   */
  async getStatistics() {
    try {
      const history = await this.getHistory();
      
      const totalSent = history.length;
      const successfulSends = history.filter(record => record.success).length;
      const failedSends = totalSent - successfulSends;
      
      // 计算总发送文件大小
      const totalSize = history.reduce((sum, record) => sum + (record.fileSize || 0), 0);
      
      // 计算总发送到的国家数量
      const totalCountries = history.reduce((sum, record) => sum + (record.countriesCount || 0), 0);
      
      return {
        totalSent,
        successfulSends,
        failedSends,
        totalSize,
        totalCountries,
      };
    } catch (error) {
      console.error('获取发送统计信息失败:', error);
      return {
        totalSent: 0,
        successfulSends: 0,
        failedSends: 0,
        totalSize: 0,
        totalCountries: 0,
      };
    }
  }
}

// 导出单例实例
export default new SendingHistoryManager();