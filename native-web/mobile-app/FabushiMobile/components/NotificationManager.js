import { Platform } from 'react-native';
import notifee, { AndroidImportance, AndroidStyle } from '@notifee/react-native';

/**
 * 通知管理器类
 * 用于处理安卓平台的通知功能
 */
class NotificationManager {
  constructor() {
    this.channelId = null;
    this.isInitialized = false;
  }

  /**
   * 初始化通知功能
   */
  async initialize() {
    if (Platform.OS !== 'android') {
      return;
    }

    if (this.isInitialized) {
      return;
    }

    try {
      // 创建通知渠道
      this.channelId = await notifee.createChannel({
        id: 'fabushi-sending',
        name: '法布施发送通知',
        importance: AndroidImportance.HIGH,
        vibration: true,
        sound: 'default',
      });

      // 创建后台发送通知渠道
      await notifee.createChannel({
        id: 'fabushi-background-sending',
        name: '法布施后台发送通知',
        importance: AndroidImportance.LOW,
        vibration: false,
      });

      this.isInitialized = true;
    } catch (error) {
      console.error('通知初始化失败:', error);
    }
  }

  /**
   * 显示发送进度通知
   * @param {number} progress - 发送进度 (0-100)
   * @param {number} completed - 已完成的国家数
   * @param {number} total - 总国家数
   */
  async showSendingProgress(progress, completed, total) {
    if (Platform.OS !== 'android' || !this.isInitialized) {
      return;
    }

    try {
      await notifee.displayNotification({
        title: '全球法布施发送中',
        body: `正在发送到全球249个国家... (${completed}/${total})`,
        android: {
          channelId: this.channelId,
          progress: {
            max: 100,
            current: progress,
          },
          style: {
            type: AndroidStyle.BIGTEXT,
            text: `已发送到 ${completed} 个国家，总共 ${total} 个国家`,
          },
          timestamp: Date.now(),
          showTimestamp: true,
          ongoing: true, // 持续通知
          autoCancel: false,
        },
      });
    } catch (error) {
      console.error('显示进度通知失败:', error);
    }
  }

  /**
   * 显示后台发送进度通知
   * @param {number} progress - 发送进度 (0-100)
   * @param {number} completed - 已完成的国家数
   * @param {number} total - 总国家数
   */
  async showBackgroundSendingProgress(progress, completed, total) {
    if (Platform.OS !== 'android' || !this.isInitialized) {
      return;
    }

    try {
      await notifee.displayNotification({
        id: 'background-sending-progress',
        title: '法布施后台发送中',
        body: `后台发送进行中... (${completed}/${total})`,
        android: {
          channelId: 'fabushi-background-sending',
          progress: {
            max: 100,
            current: progress,
          },
          onlyAlertOnce: true,
          ongoing: true,
          autoCancel: false,
        },
      });
    } catch (error) {
      console.error('显示后台进度通知失败:', error);
    }
  }

  /**
   * 显示发送完成通知
   * @param {boolean} success - 是否发送成功
   * @param {string} message - 消息内容
   */
  async showSendingCompleted(success, message) {
    if (Platform.OS !== 'android' || !this.isInitialized) {
      return;
    }

    try {
      await notifee.displayNotification({
        title: success ? '发送成功' : '发送失败',
        body: message,
        android: {
          channelId: this.channelId,
          pressAction: {
            id: 'default',
          },
          ongoing: false,
          autoCancel: true,
        },
      });
    } catch (error) {
      console.error('显示完成通知失败:', error);
    }
  }

  /**
   * 隐藏进度通知
   */
  async hideProgressNotification() {
    if (Platform.OS !== 'android' || !this.isInitialized) {
      return;
    }

    try {
      await notifee.hideNotificationDrawer();
    } catch (error) {
      console.error('隐藏通知失败:', error);
    }
  }

  /**
   * 清除所有通知
   */
  async clearAllNotifications() {
    if (Platform.OS !== 'android' || !this.isInitialized) {
      return;
    }

    try {
      await notifee.cancelAllNotifications();
    } catch (error) {
      console.error('清除通知失败:', error);
    }
  }
}

// 导出单例实例
export default new NotificationManager();