import { AppState } from 'react-native';
import { FileSender } from '../../../shared/file-handler.js';
import countryServers from '../../../shared/country-servers.js';
import NotificationManager from './NotificationManager';
import SendingHistoryManager from './SendingHistoryManager';

/**
 * 后台发送服务类
 * 用于在应用后台运行时继续发送文件
 */
class BackgroundSenderService {
  constructor() {
    this.isSending = false;
    this.currentProgress = { total: 0, completed: 0 };
    this.appState = AppState.currentState;
    this.listeners = [];
    
    // 初始化通知管理器
    NotificationManager.initialize();
    
    // 监听应用状态变化
    AppState.addEventListener('change', this._handleAppStateChange.bind(this));
  }

  /**
   * 添加监听器
   * @param {Function} listener - 监听器函数
   */
  addListener(listener) {
    this.listeners.push(listener);
  }

  /**
   * 移除监听器
   * @param {Function} listener - 监听器函数
   */
  removeListener(listener) {
    const index = this.listeners.indexOf(listener);
    if (index > -1) {
      this.listeners.splice(index, 1);
    }
  }

  /**
   * 通知监听器
   * @param {string} event - 事件名称
   * @param {any} data - 事件数据
   */
  _notifyListeners(event, data) {
    this.listeners.forEach(listener => {
      try {
        listener(event, data);
      } catch (error) {
        console.error('BackgroundSenderService listener error:', error);
      }
    });
  }

  /**
   * 处理应用状态变化
   * @param {string} nextAppState - 下一个应用状态
   */
  _handleAppStateChange(nextAppState) {
    if (this.appState.match(/inactive|background/) && nextAppState === 'active') {
      // 应用从后台回到前台
      this._notifyListeners('appStateChanged', { state: 'foreground' });
    } else if (this.appState === 'active' && nextAppState.match(/inactive|background/)) {
      // 应用从前台进入后台
      this._notifyListeners('appStateChanged', { state: 'background' });
    }
    
    this.appState = nextAppState;
  }

  /**
   * 开始后台发送任务
   * @param {Array} files - 要发送的文件列表
   * @param {Function} onProgress - 进度回调函数
   * @param {Function} onLog - 日志回调函数
   * @returns {Promise<Object>} 发送结果
   */
  async startBackgroundSending(files, onProgress, onLog) {
    if (this.isSending) {
      throw new Error('发送任务已在进行中');
    }

    this.isSending = true;
    this.currentProgress = { total: 0, completed: 0 };
    
    const fileSender = new FileSender(countryServers);
    
    try {
      // 通知开始后台发送
      this._notifyListeners('sendingStarted', { files: files.length });
      
      const result = await fileSender.startSending(
        files,
        (progress) => {
          this.currentProgress = progress;
          if (onProgress) onProgress(progress);
          this._notifyListeners('progressUpdate', progress);
          
          // 更新通知进度
          if (progress.total > 0) {
            const percent = Math.round((progress.completed / progress.total) * 100);
            NotificationManager.showBackgroundSendingProgress(percent, progress.completed, progress.total);
          }
        },
        (message) => {
          if (onLog) onLog(message);
          this._notifyListeners('logMessage', message);
        }
      );

      // 通知发送完成
      this._notifyListeners('sendingCompleted', result);
      
      // 显示完成通知
      if (result.success) {
        NotificationManager.showSendingCompleted(true, `文件已成功发送到 ${result.countriesSent} 个国家`);
      } else {
        NotificationManager.showSendingCompleted(false, `发送失败: ${result.error}`);
      }
      
      return result;
    } catch (error) {
      // 通知发送错误
      this._notifyListeners('sendingError', { error: error.message });
      
      // 显示错误通知
      NotificationManager.showSendingCompleted(false, `发送错误: ${error.message}`);
      
      throw error;
    } finally {
      this.isSending = false;
    }
  }

  /**
   * 停止后台发送任务
   */
  stopBackgroundSending() {
    if (this.isSending) {
      this.isSending = false;
      this.currentProgress = { total: 0, completed: 0 };
      this._notifyListeners('sendingStopped', {});
      
      // 清除通知
      NotificationManager.clearAllNotifications();
    }
  }

  /**
   * 检查是否正在发送
   * @returns {boolean} 是否正在发送
   */
  isCurrentlySending() {
    return this.isSending;
  }

  /**
   * 获取当前进度
   * @returns {Object} 当前进度信息
   */
  getCurrentProgress() {
    return { ...this.currentProgress };
  }
}

// 导出单例实例
export default new BackgroundSenderService();