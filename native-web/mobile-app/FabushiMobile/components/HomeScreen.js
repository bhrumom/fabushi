import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Alert,
  AppState,
} from 'react-native';
import { Card } from 'react-native-elements';
import FileSender from './FileSender';
import authManager from '../../../shared/auth.js';
import BackgroundSenderService from './BackgroundSenderService';

const HomeScreen = ({ navigation }) => {
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [currentUser, setCurrentUser] = useState(null);
  const [logs, setLogs] = useState([]);
  const [appState, setAppState] = useState(AppState.currentState);

  useEffect(() => {
    // 检查用户登录状态
    const checkLoginStatus = async () => {
      const loggedIn = authManager.isLoggedIn();
      setIsLoggedIn(loggedIn);
      if (loggedIn) {
        setCurrentUser(authManager.getCurrentUser());
      }
    };

    checkLoginStatus();

    // 添加认证状态监听器
    const authListener = (event, data) => {
      if (event === 'login') {
        setIsLoggedIn(true);
        setCurrentUser(data);
      } else if (event === 'logout') {
        setIsLoggedIn(false);
        setCurrentUser(null);
      }
    };

    authManager.addListener(authListener);

    // 监听应用状态变化
    const appStateListener = AppState.addEventListener('change', (nextAppState) => {
      setAppState(nextAppState);
      
      // 当应用进入后台时，如果有正在发送的任务，提醒用户
      if (appState.match(/active/) && nextAppState.match(/inactive|background/)) {
        if (BackgroundSenderService.isCurrentlySending()) {
          Alert.alert(
            '后台发送',
            '文件正在发送中，应用进入后台后将继续发送',
            [{ text: '确定' }]
          );
        }
      }
    });

    // 添加后台发送服务监听器
    const backgroundSenderListener = (event, data) => {
      switch (event) {
        case 'sendingStarted':
          addLog(`开始后台发送 ${data.files} 个文件`);
          break;
        case 'progressUpdate':
          addLog(`发送进度: ${data.completed}/${data.total}`);
          break;
        case 'sendingCompleted':
          if (data.success) {
            addLog('✅ 后台发送完成！');
          } else {
            addLog(`❌ 后台发送失败: ${data.error}`);
          }
          break;
        case 'sendingError':
          addLog(`❌ 后台发送错误: ${data.error}`);
          break;
        case 'logMessage':
          addLog(data);
          break;
      }
    };

    BackgroundSenderService.addListener(backgroundSenderListener);

    return () => {
      authManager.removeListener(authListener);
      if (appStateListener && appStateListener.remove) {
        appStateListener.remove();
      }
      BackgroundSenderService.removeListener(backgroundSenderListener);
    };
  }, [appState]);

  const addLog = (message) => {
    const timestamp = new Date().toLocaleTimeString();
    setLogs(prevLogs => [...prevLogs, `[${timestamp}] ${message}`]);
  };

  return (
    <ScrollView style={styles.container}>
      <Card containerStyle={styles.card}>
        <Card.Title>✨ 全球法布施 ✨</Card.Title>
        <Card.Divider />
        
        {isLoggedIn ? (
          <View style={styles.userInfo}>
            <Text style={styles.welcomeText}>欢迎, {currentUser?.username || '用户'}!</Text>
            <Text 
              style={styles.profileLink} 
              onPress={() => navigation.navigate('Profile')}
            >
              查看个人资料
            </Text>
          </View>
        ) : (
          <View style={styles.loginPrompt}>
            <Text style={styles.loginText}>🔒 全球法布施功能需要登录后使用</Text>
            <Text 
              style={styles.loginButton} 
              onPress={() => navigation.navigate('Login')}
            >
              登录 / 注册
            </Text>
          </View>
        )}
      </Card>

      <FileSender onLog={addLog} />

      <Card containerStyle={styles.card}>
        <Card.Title>📋 发送日志</Card.Title>
        <Card.Divider />
        
        <View style={styles.logContainer}>
          {logs.length === 0 ? (
            <Text style={styles.emptyLog}>暂无日志信息</Text>
          ) : (
            logs.map((log, index) => (
              <Text key={index} style={styles.logEntry}>{log}</Text>
            ))
          )}
        </View>
      </Card>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  card: {
    borderRadius: 15,
    margin: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  userInfo: {
    alignItems: 'center',
    marginBottom: 10,
  },
  welcomeText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#2c3e50',
    marginBottom: 5,
  },
  profileLink: {
    color: '#66a6ff',
    textDecorationLine: 'underline',
    fontSize: 16,
  },
  loginPrompt: {
    alignItems: 'center',
  },
  loginText: {
    fontSize: 16,
    color: '#856404',
    backgroundColor: 'rgba(255, 193, 7, 0.1)',
    padding: 10,
    borderRadius: 8,
    marginBottom: 15,
    textAlign: 'center',
  },
  loginButton: {
    color: 'white',
    backgroundColor: '#66a6ff',
    borderRadius: 25,
    paddingHorizontal: 20,
    paddingVertical: 10,
    overflow: 'hidden',
  },
  logContainer: {
    backgroundColor: '#2c3e50',
    borderRadius: 8,
    padding: 10,
    maxHeight: 200,
  },
  emptyLog: {
    color: '#ecf0f1',
    textAlign: 'center',
    fontStyle: 'italic',
    padding: 20,
  },
  logEntry: {
    color: '#ecf0f1',
    paddingVertical: 2,
    fontSize: 12,
  },
});

export default HomeScreen;