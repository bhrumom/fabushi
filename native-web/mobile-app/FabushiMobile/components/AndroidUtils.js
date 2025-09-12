import { Platform, PermissionsAndroid, Alert } from 'react-native';
import notifee from '@notifee/react-native';

/**
 * 安卓平台工具类
 * 用于处理安卓平台特有的功能和权限
 */
export class AndroidUtils {
  /**
   * 检查并请求安卓平台所需的权限
   * @returns {Promise<boolean>} 是否获得了所需权限
   */
  static async requestAndroidPermissions() {
    if (Platform.OS !== 'android') {
      return true;
    }

    try {
      // 请求存储读取权限
      const readPermission = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.READ_EXTERNAL_STORAGE,
        {
          title: '存储权限请求',
          message: '全球法布施需要访问您的存储以选择和发送文件',
          buttonNeutral: '稍后询问',
          buttonNegative: '取消',
          buttonPositive: '允许',
        }
      );

      // 对于Android 11及以上版本，请求管理外部存储权限
      if (Platform.Version >= 30) {
        const managePermission = await PermissionsAndroid.request(
          PermissionsAndroid.PERMISSIONS.MANAGE_EXTERNAL_STORAGE,
          {
            title: '文件管理权限请求',
            message: '为了更好地处理文件，全球法布施需要文件管理权限',
            buttonNeutral: '稍后询问',
            buttonNegative: '取消',
            buttonPositive: '允许',
          }
        );

        // 请求通知权限
        await notifee.requestPermission();

        return (
          readPermission === PermissionsAndroid.RESULTS.GRANTED ||
          managePermission === PermissionsAndroid.RESULTS.GRANTED
        );
      }

      // 对于Android 11以下版本，请求通知权限
      await notifee.requestPermission();

      return readPermission === PermissionsAndroid.RESULTS.GRANTED;
    } catch (err) {
      console.warn('权限请求失败:', err);
      return false;
    }
  }

  /**
   * 检查安卓平台版本
   * @returns {Object} 版本信息
   */
  static getAndroidVersionInfo() {
    if (Platform.OS !== 'android') {
      return { isAndroid: false };
    }

    return {
      isAndroid: true,
      version: Platform.Version,
      isAndroid11OrAbove: Platform.Version >= 30,
      isAndroid10OrAbove: Platform.Version >= 29,
    };
  }

  /**
   * 显示安卓平台特定的提示信息
   * @param {string} title - 标题
   * @param {string} message - 消息内容
   */
  static showAndroidAlert(title, message) {
    if (Platform.OS === 'android') {
      Alert.alert(title, message, [{ text: '确定' }]);
    }
  }

  /**
   * 处理安卓平台的文件URI
   * @param {string} uri - 原始URI
   * @returns {string} 处理后的URI
   */
  static processAndroidFileUri(uri) {
    if (Platform.OS !== 'android' || !uri) {
      return uri;
    }

    // 处理content:// URI
    if (uri.startsWith('content://')) {
      // 对于安卓平台，可能需要特殊处理content URI
      return uri;
    }

    // 处理file:// URI
    if (uri.startsWith('file://')) {
      return uri;
    }

    // 如果是相对路径，添加file://前缀
    if (!uri.includes('://')) {
      return `file://${uri}`;
    }

    return uri;
  }
}

export default AndroidUtils;