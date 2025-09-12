import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Alert,
  RefreshControl,
} from 'react-native';
import { Button, Card, Icon, ListItem, Divider } from 'react-native-elements';
import SendingHistoryManager from './SendingHistoryManager';

const SendingHistoryScreen = ({ navigation }) => {
  const [history, setHistory] = useState([]);
  const [statistics, setStatistics] = useState(null);
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    loadHistory();
  }, []);

  const loadHistory = async () => {
    try {
      const historyData = await SendingHistoryManager.getHistory();
      setHistory(historyData);
      
      const stats = await SendingHistoryManager.getStatistics();
      setStatistics(stats);
    } catch (error) {
      console.error('加载发送历史记录失败:', error);
      Alert.alert('错误', '加载发送历史记录失败');
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadHistory();
    setRefreshing(false);
  };

  const clearHistory = () => {
    Alert.alert(
      '确认清除',
      '您确定要清除所有发送历史记录吗？',
      [
        { text: '取消', style: 'cancel' },
        {
          text: '清除',
          style: 'destructive',
          onPress: async () => {
            try {
              await SendingHistoryManager.clearHistory();
              setHistory([]);
              setStatistics({
                totalSent: 0,
                successfulSends: 0,
                failedSends: 0,
                totalSize: 0,
                totalCountries: 0,
              });
              Alert.alert('成功', '发送历史记录已清除');
            } catch (error) {
              console.error('清除发送历史记录失败:', error);
              Alert.alert('错误', '清除发送历史记录失败');
            }
          },
        },
      ],
      { cancelable: true }
    );
  };

  const formatFileSize = (bytes) => {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  const formatDate = (timestamp) => {
    const date = new Date(timestamp);
    return date.toLocaleString('zh-CN');
  };

  const getStatusIcon = (success) => {
    return success ? 
      <Icon name="check-circle" color="#27ae60" size={20} /> : 
      <Icon name="error" color="#e74c3c" size={20} />;
  };

  return (
    <ScrollView 
      style={styles.container}
      refreshControl={
        <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
      }
    >
      <View style={styles.header}>
        <Icon name="history" size={60} color="#667eea" />
        <Text style={styles.title}>发送历史记录</Text>
        <Text style={styles.subtitle}>查看您的文件发送历史</Text>
      </View>

      {statistics && (
        <Card containerStyle={styles.card}>
          <Card.Title>发送统计</Card.Title>
          <Card.Divider />
          
          <View style={styles.statsContainer}>
            <View style={styles.statItem}>
              <Text style={styles.statValue}>{statistics.totalSent}</Text>
              <Text style={styles.statLabel}>总发送</Text>
            </View>
            <View style={styles.statItem}>
              <Text style={styles.statValue}>{statistics.successfulSends}</Text>
              <Text style={styles.statLabel}>成功</Text>
            </View>
            <View style={styles.statItem}>
              <Text style={styles.statValue}>{statistics.failedSends}</Text>
              <Text style={styles.statLabel}>失败</Text>
            </View>
          </View>
          
          <View style={styles.statsContainer}>
            <View style={styles.statItem}>
              <Text style={styles.statValue}>{formatFileSize(statistics.totalSize)}</Text>
              <Text style={styles.statLabel}>总大小</Text>
            </View>
            <View style={styles.statItem}>
              <Text style={styles.statValue}>{statistics.totalCountries}</Text>
              <Text style={styles.statLabel}>国家数</Text>
            </View>
          </View>
        </Card>
      )}

      <Card containerStyle={styles.card}>
        <View style={styles.historyHeader}>
          <Card.Title>发送记录</Card.Title>
          {history.length > 0 && (
            <Button
              title="清除记录"
              onPress={clearHistory}
              buttonStyle={styles.clearButton}
              titleStyle={styles.clearButtonTitle}
            />
          )}
        </View>
        <Card.Divider />
        
        {history.length === 0 ? (
          <Text style={styles.emptyText}>暂无发送记录</Text>
        ) : (
          history.map((record, index) => (
            <View key={record.id}>
              <ListItem bottomDivider>
                {getStatusIcon(record.success)}
                <ListItem.Content>
                  <ListItem.Title style={styles.fileName}>{record.fileName}</ListItem.Title>
                  <ListItem.Subtitle>
                    {formatDate(record.sentTime)}
                  </ListItem.Subtitle>
                  <View style={styles.recordDetails}>
                    <Text style={styles.detailText}>
                      大小: {formatFileSize(record.fileSize)}
                    </Text>
                    <Text style={styles.detailText}>
                      国家: {record.countriesCount}
                    </Text>
                  </View>
                </ListItem.Content>
              </ListItem>
              {index < history.length - 1 && <Divider />}
            </View>
          ))
        )}
      </Card>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  header: {
    alignItems: 'center',
    marginVertical: 30,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#2c3e50',
    marginVertical: 10,
  },
  subtitle: {
    fontSize: 16,
    color: '#7f8c8d',
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
  statsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginVertical: 10,
  },
  statItem: {
    alignItems: 'center',
  },
  statValue: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#667eea',
  },
  statLabel: {
    fontSize: 14,
    color: '#7f8c8d',
    marginTop: 4,
  },
  historyHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  clearButton: {
    backgroundColor: '#e74c3c',
    borderRadius: 20,
    paddingHorizontal: 15,
    paddingVertical: 5,
  },
  clearButtonTitle: {
    fontSize: 14,
    color: 'white',
  },
  emptyText: {
    textAlign: 'center',
    color: '#7f8c8d',
    fontStyle: 'italic',
    padding: 20,
  },
  fileName: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#2c3e50',
  },
  recordDetails: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 5,
  },
  detailText: {
    fontSize: 12,
    color: '#7f8c8d',
  },
});

export default SendingHistoryScreen;