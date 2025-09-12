import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Alert,
  Platform,
  PermissionsAndroid,
} from 'react-native';
import { Button, Card, Icon, Divider } from 'react-native-elements';
import DocumentPicker from 'react-native-document-picker';
import { launchImageLibrary } from 'react-native-image-picker';
import { FileQueue, FileSender as FileSenderHandler } from '../../../shared/file-handler.js';
import countryServers from '../../../shared/country-servers.js';
import authManager from '../../../shared/auth.js';
import { AndroidUtils } from './AndroidUtils.js';
import BackgroundSenderService from './BackgroundSenderService';
import NotificationManager from './NotificationManager';
import SendingHistoryManager from './SendingHistoryManager';

const FileSender = ({ onLog }) => {
  const [fileQueue, setFileQueue] = useState(new FileQueue());
  const [isSending, setIsSending] = useState(false);
  const [progress, setProgress] = useState({ total: 0, completed: 0 });
  const fileSenderRef = useRef(null);

  useEffect(() => {
    // 初始化通知管理器
    NotificationManager.initialize();
    
    // 添加后台发送服务监听器
    const backgroundSenderListener = (event, data) => {
      switch (event) {
        case 'progressUpdate':
          setProgress(data);
          break;
      }
    };

    BackgroundSenderService.addListener(backgroundSenderListener);

    return () => {
      BackgroundSenderService.removeListener(backgroundSenderListener);
    };
  }, []);

  const addLog = (message) => {
    if (onLog) {
      onLog(message);
    }
  };

  const requestPermissions = async () => {
    if (Platform.OS === 'android') {
      // 使用我们创建的安卓工具类来处理权限
      return await AndroidUtils.requestAndroidPermissions();
    }
    return true;
  };

  const selectFiles = async () => {
    if (!authManager.isLoggedIn()) {
      Alert.alert('请先登录', '全球法布施功能需要登录后使用，请先登录或注册账号');
      return;
    }

    try {
      const hasPermission = await requestPermissions();
      if (!hasPermission) {
        Alert.alert('权限不足', '请授予文件访问权限以选择文件');
        return;
      }

      const result = await DocumentPicker.pickMultiple({
        type: [DocumentPicker.types.allFiles],
      });

      const newFiles = result.map(file => ({
        id: Math.random().toString(36).substr(2, 9),
        name: file.name,
        size: file.size,
        uri: AndroidUtils.processAndroidFileUri(file.uri), // 使用安卓工具类处理URI
        type: file.type,
      }));

      newFiles.forEach(file => fileQueue.addFile(file));
      setFileQueue(new FileQueue()); // 触发重新渲染
      addLog(`已选择 ${newFiles.length} 个文件`);
    } catch (err) {
      if (DocumentPicker.isCancel(err)) {
        // 用户取消选择
      } else {
        Alert.alert('选择文件时出错', err.message);
      }
    }
  };

  const selectImages = async () => {
    if (!authManager.isLoggedIn()) {
      Alert.alert('请先登录', '全球法布施功能需要登录后使用，请先登录或注册账号');
      return;
    }

    const options = {
      mediaType: 'photo',
      selectionLimit: 0, // 允许多选
    };

    launchImageLibrary(options, (response) => {
      if (response.didCancel || response.error) {
        return;
      }

      if (response.assets) {
        const newFiles = response.assets.map(asset => ({
          id: Math.random().toString(36).substr(2, 9),
          name: asset.fileName || `image_${Date.now()}.jpg`,
          size: asset.fileSize,
          uri: AndroidUtils.processAndroidFileUri(asset.uri), // 使用安卓工具类处理URI
          type: asset.type || 'image/jpeg',
        }));

        newFiles.forEach(file => fileQueue.addFile(file));
        setFileQueue(new FileQueue()); // 触发重新渲染
        addLog(`已选择 ${newFiles.length} 张图片`);
      }
    });
  };

  const startSending = async () => {
    if (!authManager.isLoggedIn()) {
      Alert.alert('请先登录', '全球法布施功能需要登录后使用，请先登录或注册账号');
      return;
    }

    const files = fileQueue.getFiles();
    if (files.length === 0) {
      Alert.alert('请选择文件', '请先选择要发送的文件');
      return;
    }

    Alert.alert(
      '发送方式选择',
      '请选择发送方式：',
      [
        {
          text: '前台发送',
          onPress: () => startForegroundSending(files)
        },
        {
          text: '后台发送',
          onPress: () => startBackgroundSending(files)
        },
        {
          text: '取消',
          style: 'cancel'
        }
      ]
    );
  };

  const startForegroundSending = async (files) => {
    setIsSending(true);
    setProgress({ total: 0, completed: 0 });
    addLog('🚀 开始发送文件到全球249个国家...');

    const fileSender = new FileSenderHandler(countryServers);
    fileSenderRef.current = fileSender;
    
    // 记录发送开始时间
    const startTime = Date.now();
    
    try {
      const result = await fileSender.startSending(
        files,
        (progress) => {
          setProgress(progress);
          addLog(`正在发送到 ${countryServers.getCountryName(progress.country)}...`);
          
          // 更新通知进度
          if (progress.total > 0) {
            const percent = Math.round((progress.completed / progress.total) * 100);
            NotificationManager.showSendingProgress(percent, progress.completed, progress.total);
          }
        },
        (message) => {
          addLog(message);
        }
      );

      if (result.success) {
        addLog('✅ 所有文件发送完成！');
        NotificationManager.showSendingCompleted(true, '文件已成功发送到全球249个国家');
        Alert.alert('发送成功', '文件已成功发送到全球249个国家');
      } else {
        addLog(`❌ 发送失败: ${result.error}`);
        NotificationManager.showSendingCompleted(false, `发送失败: ${result.error}`);
        Alert.alert('发送失败', result.error);
      }
      
      // 保存发送记录
      try {
        const endTime = Date.now();
        for (const file of files) {
          await SendingHistoryManager.addRecord({
            fileName: file.name,
            fileSize: file.size,
            sentTime: endTime,
            countriesCount: result.success ? result.countriesSent : 0,
            success: result.success,
            duration: endTime - startTime,
          });
        }
      } catch (error) {
        console.error('保存发送记录失败:', error);
      }
    } catch (error) {
      addLog(`❌ 发送过程中发生错误: ${error.message}`);
      NotificationManager.showSendingCompleted(false, `发送错误: ${error.message}`);
      Alert.alert('发送错误', error.message);
      
      // 保存失败的发送记录
      try {
        const endTime = Date.now();
        for (const file of files) {
          await SendingHistoryManager.addRecord({
            fileName: file.name,
            fileSize: file.size,
            sentTime: endTime,
            countriesCount: 0,
            success: false,
            duration: endTime - startTime,
            error: error.message,
          });
        }
      } catch (saveError) {
        console.error('保存发送记录失败:', saveError);
      }
    } finally {
      setIsSending(false);
      fileSenderRef.current = null;
    }
  };

  const startBackgroundSending = async (files) => {
    try {
      addLog('🕊️ 开始后台发送文件到全球249个国家...');
      
      // 记录发送开始时间
      const startTime = Date.now();
      
      const result = await BackgroundSenderService.startBackgroundSending(
        files,
        (progress) => {
          setProgress(progress);
          addLog(`后台发送进度: ${progress.completed}/${progress.total}`);
        },
        (message) => {
          addLog(message);
        }
      );

      if (result.success) {
        addLog('✅ 后台发送任务已启动！');
        Alert.alert(
          '后台发送已启动',
          '文件正在后台发送中，您可以在通知栏查看进度',
          [{ text: '确定' }]
        );
      } else {
        addLog(`❌ 后台发送启动失败: ${result.error}`);
        Alert.alert('发送失败', result.error);
      }
      
      // 保存发送记录
      try {
        const endTime = Date.now();
        for (const file of files) {
          await SendingHistoryManager.addRecord({
            fileName: file.name,
            fileSize: file.size,
            sentTime: endTime,
            countriesCount: result.success ? result.countriesSent : 0,
            success: result.success,
            duration: endTime - startTime,
          });
        }
      } catch (error) {
        console.error('保存发送记录失败:', error);
      }
    } catch (error) {
      addLog(`❌ 后台发送启动错误: ${error.message}`);
      Alert.alert('发送错误', error.message);
      
      // 保存失败的发送记录
      try {
        const endTime = Date.now();
        for (const file of files) {
          await SendingHistoryManager.addRecord({
            fileName: file.name,
            fileSize: file.size,
            sentTime: endTime,
            countriesCount: 0,
            success: false,
            duration: endTime - startTime,
            error: error.message,
          });
        }
      } catch (saveError) {
        console.error('保存发送记录失败:', saveError);
      }
    }
  };

  const stopSending = () => {
    if (fileSenderRef.current) {
      fileSenderRef.current.stopSending();
    }
    // 同时停止后台发送
    BackgroundSenderService.stopBackgroundSending();
    NotificationManager.clearAllNotifications();
    addLog('⏹️ 发送任务已被用户中断');
    setIsSending(false);
  };

  const clearFiles = () => {
    // 如果正在后台发送，不允许清空文件
    if (BackgroundSenderService.isCurrentlySending()) {
      Alert.alert('正在发送', '后台正在发送文件，无法清空列表');
      return;
    }
    
    fileQueue.clear();
    setFileQueue(new FileQueue()); // 触发重新渲染
    addLog('已清空文件列表');
  };

  const removeFile = (fileId) => {
    // 如果正在后台发送，不允许移除文件
    if (BackgroundSenderService.isCurrentlySending()) {
      Alert.alert('正在发送', '后台正在发送文件，无法移除文件');
      return;
    }
    
    fileQueue.removeFile(fileId);
    setFileQueue(new FileQueue()); // 触发重新渲染
  };

  return (
    <View>
      <Card containerStyle={styles.card}>
        <Card.Title>🌸 选择法宝</Card.Title>
        <Card.Divider />
        
        <View style={styles.buttonRow}>
          <Button
            title="📂 选择文件"
            onPress={selectFiles}
            disabled={isSending}
            buttonStyle={[styles.actionButton, styles.fileButton]}
            disabledStyle={styles.disabledButton}
          />
          <Button
            title="🖼️ 选择图片"
            onPress={selectImages}
            disabled={isSending}
            buttonStyle={[styles.actionButton, styles.imageButton]}
            disabledStyle={styles.disabledButton}
          />
        </View>
        
        <Button
          title="🗑️ 清空列表"
          onPress={clearFiles}
          disabled={isSending || fileQueue.size() === 0}
          buttonStyle={[styles.actionButton, styles.clearButton]}
          disabledStyle={styles.disabledButton}
          titleStyle={styles.clearButtonTitle}
        />
        
        <Divider style={styles.divider} />
        
        <View style={styles.fileListContainer}>
          <Text style={styles.fileListTitle}>已选择的文件:</Text>
          {fileQueue.size() === 0 ? (
            <Text style={styles.emptyFileList}>尚未选择任何善缘或法宝</Text>
          ) : (
            <View>
              {fileQueue.getFiles().map((file) => (
                <View key={file.id} style={styles.fileItem}>
                  <View style={styles.fileInfo}>
                    <Icon name="description" size={20} color="#667eea" />
                    <Text style={styles.fileName} numberOfLines={1}>{file.name}</Text>
                  </View>
                  <Button
                    icon={<Icon name="close" size={20} color="white" />}
                    onPress={() => removeFile(file.id)}
                    buttonStyle={styles.removeButton}
                  />
                </View>
              ))}
            </View>
          )}
        </View>
      </Card>

      <Card containerStyle={styles.card}>
        <Card.Title>🕊️ 开始传送</Card.Title>
        <Card.Divider />
        
        <View style={styles.statsContainer}>
          <View style={styles.statItem}>
            <Text style={styles.statValue}>{fileQueue.size()}</Text>
            <Text style={styles.statLabel}>待发送文件</Text>
          </View>
          <View style={styles.statItem}>
            <Text style={styles.statValue}>249</Text>
            <Text style={styles.statLabel}>目标国家</Text>
          </View>
        </View>
        
        <View style={styles.buttonRow}>
          <Button
            title={isSending ? "⏹️ 停止发送" : "🚀 开始发送"}
            onPress={isSending ? stopSending : startSending}
            disabled={!authManager.isLoggedIn() || (fileQueue.size() === 0 && !isSending)}
            buttonStyle={[styles.actionButton, isSending ? styles.stopButton : styles.sendButton]}
            disabledStyle={styles.disabledButton}
          />
        </View>
        
        {isSending && (
          <View style={styles.progressContainer}>
            <Text style={styles.progressText}>
              正在发送: {progress.completed}/{progress.total}
            </Text>
          </View>
        )}
      </Card>
    </View>
  );
};

const styles = StyleSheet.create({
  card: {
    borderRadius: 15,
    margin: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  buttonRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 15,
  },
  actionButton: {
    borderRadius: 25,
    paddingHorizontal: 15,
  },
  fileButton: {
    backgroundColor: '#f6d365',
    flex: 1,
    marginRight: 5,
  },
  imageButton: {
    backgroundColor: '#89f7fe',
    flex: 1,
    marginLeft: 5,
  },
  clearButton: {
    backgroundColor: '#ff7675',
  },
  clearButtonTitle: {
    color: 'white',
  },
  stopButton: {
    backgroundColor: '#ff7675',
  },
  sendButton: {
    backgroundColor: '#89f7fe',
  },
  disabledButton: {
    backgroundColor: '#bdc3c7',
  },
  divider: {
    marginVertical: 15,
  },
  fileListContainer: {
    marginTop: 10,
  },
  fileListTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 10,
    color: '#34495e',
  },
  emptyFileList: {
    textAlign: 'center',
    color: '#999',
    fontStyle: 'italic',
    padding: 20,
  },
  fileItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 10,
    backgroundColor: 'rgba(255, 255, 255, 0.9)',
    borderWidth: 1,
    borderColor: '#eee',
    borderRadius: 8,
    marginBottom: 8,
  },
  fileInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  fileName: {
    marginLeft: 10,
    flex: 1,
  },
  removeButton: {
    backgroundColor: '#ff7675',
    borderRadius: 15,
    width: 30,
    height: 30,
    padding: 0,
  },
  statsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginBottom: 20,
  },
  statItem: {
    alignItems: 'center',
  },
  statValue: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#ff8a65',
  },
  statLabel: {
    fontSize: 14,
    color: '#555',
    marginTop: 4,
  },
  progressContainer: {
    marginTop: 15,
    alignItems: 'center',
  },
  progressText: {
    fontSize: 16,
    color: '#34495e',
  },
});

export default FileSender;