import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Alert,
  TouchableOpacity,
  TextInput,
} from 'react-native';
import { Button, Card, Icon, ListItem, Input } from 'react-native-elements';
import authManager from '../../../shared/auth.js';

const ProfileScreen = ({ navigation }) => {
  const [currentUser, setCurrentUser] = useState(null);
  const [membershipStatus, setMembershipStatus] = useState(null);
  const [loading, setLoading] = useState(false);
  const [redeemCode, setRedeemCode] = useState('');

  useEffect(() => {
    const fetchUserInfo = async () => {
      if (authManager.isLoggedIn()) {
        const user = authManager.getCurrentUser();
        setCurrentUser(user);
        
        // 检查会员状态
        try {
          const status = await authManager.checkMembership();
          setMembershipStatus(status);
        } catch (error) {
          console.error('检查会员状态时出错:', error);
        }
      }
    };

    fetchUserInfo();

    // 添加认证状态监听器
    const authListener = (event, data) => {
      if (event === 'login') {
        setCurrentUser(data);
      } else if (event === 'logout') {
        setCurrentUser(null);
        setMembershipStatus(null);
      }
    };

    authManager.addListener(authListener);

    return () => {
      authManager.removeListener(authListener);
    };
  }, []);

  const handleLogout = () => {
    Alert.alert(
      '确认退出',
      '您确定要退出登录吗？',
      [
        { text: '取消', style: 'cancel' },
        {
          text: '退出',
          style: 'destructive',
          onPress: () => {
            authManager.logout();
            navigation.navigate('Home');
          },
        },
      ],
      { cancelable: true }
    );
  };

  const handleRedeemCode = async () => {
    if (!redeemCode.trim()) {
      Alert.alert('请输入兑换码', '请输入有效的兑换码');
      return;
    }

    setLoading(true);
    try {
      const result = await authManager.redeemCode(redeemCode.trim());
      if (result.success) {
        Alert.alert('兑换成功', result.message);
        setRedeemCode('');
        
        // 重新检查会员状态
        try {
          const status = await authManager.checkMembership();
          setMembershipStatus(status);
        } catch (error) {
          console.error('检查会员状态时出错:', error);
        }
      } else {
        Alert.alert('兑换失败', result.message);
      }
    } catch (error) {
      Alert.alert('兑换错误', error.message || '兑换过程中发生错误');
    } finally {
      setLoading(false);
    }
  };

  const getMembershipStatusText = () => {
    if (!membershipStatus) return '检查中...';
    
    if (!membershipStatus.isActive) {
      return '非会员';
    }
    
    if (membershipStatus.type === 'trial') {
      return `试用会员 (剩余 ${membershipStatus.daysLeft} 天)`;
    }
    
    if (membershipStatus.type === 'paid') {
      return `付费会员 (剩余 ${membershipStatus.daysLeft} 天)`;
    }
    
    return '未知状态';
  };

  const getMembershipStatusColor = () => {
    if (!membershipStatus) return '#7f8c8d';
    
    if (!membershipStatus.isActive) {
      return '#e74c3c';
    }
    
    if (membershipStatus.type === 'trial') {
      return '#f39c12';
    }
    
    if (membershipStatus.type === 'paid') {
      return '#27ae60';
    }
    
    return '#7f8c8d';
  };

  if (!currentUser) {
    return (
      <View style={styles.centerContainer}>
        <Text style={styles.notLoggedInText}>请先登录查看个人资料</Text>
        <Button
          title="前往登录"
          onPress={() => navigation.navigate('Login')}
          buttonStyle={styles.loginButton}
        />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Icon
          name="account-circle"
          size={80}
          color="#667eea"
          iconStyle={styles.avatar}
        />
        <Text style={styles.username}>{currentUser.username}</Text>
        <Text style={styles.email}>{currentUser.email}</Text>
      </View>

      <Card containerStyle={styles.card}>
        <Card.Title>账户信息</Card.Title>
        <Card.Divider />
        
        <ListItem bottomDivider>
          <Icon name="person" />
          <ListItem.Content>
            <ListItem.Title>用户名</ListItem.Title>
            <ListItem.Subtitle>{currentUser.username}</ListItem.Subtitle>
          </ListItem.Content>
        </ListItem>
        
        <ListItem bottomDivider>
          <Icon name="email" />
          <ListItem.Content>
            <ListItem.Title>邮箱</ListItem.Title>
            <ListItem.Subtitle>{currentUser.email}</ListItem.Subtitle>
          </ListItem.Content>
        </ListItem>
        
        <ListItem>
          <Icon name="calendar-today" />
          <ListItem.Content>
            <ListItem.Title>注册时间</ListItem.Title>
            <ListItem.Subtitle>
              {new Date(currentUser.createdAt).toLocaleDateString()}
            </ListItem.Subtitle>
          </ListItem.Content>
        </ListItem>
      </Card>

      <Card containerStyle={styles.card}>
        <Card.Title>会员信息</Card.Title>
        <Card.Divider />
        
        <View style={styles.membershipStatusContainer}>
          <Text style={[styles.membershipStatusText, { color: getMembershipStatusColor() }]}>
            {getMembershipStatusText()}
          </Text>
        </View>
        
        <Button
          title="💎 会员中心"
          onPress={() => navigation.navigate('Membership')}
          buttonStyle={styles.membershipButton}
          titleStyle={styles.membershipButtonTitle}
        />
        
        <Card containerStyle={styles.redeemCard}>
          <Card.Title>🎫 使用兑换码</Card.Title>
          <Card.Divider />
          
          <Input
            placeholder="请输入兑换码"
            value={redeemCode}
            onChangeText={setRedeemCode}
            inputStyle={styles.input}
            containerStyle={styles.inputContainer}
          />
          
          <Button
            title="兑换"
            onPress={handleRedeemCode}
            loading={loading}
            disabled={loading || !redeemCode.trim()}
            buttonStyle={styles.redeemButton}
            titleStyle={styles.redeemButtonTitle}
          />
        </Card>
      </Card>

      <Card containerStyle={styles.card}>
        <Card.Title>账户操作</Card.Title>
        <Card.Divider />
        
        <Button
          title="🚪 退出登录"
          onPress={handleLogout}
          buttonStyle={styles.logoutButton}
          titleStyle={styles.logoutButtonTitle}
        />
      </Card>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  notLoggedInText: {
    fontSize: 18,
    color: '#34495e',
    marginBottom: 20,
  },
  loginButton: {
    backgroundColor: '#66a6ff',
    borderRadius: 25,
    paddingHorizontal: 30,
  },
  header: {
    alignItems: 'center',
    marginVertical: 30,
  },
  avatar: {
    marginBottom: 15,
  },
  username: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#2c3e50',
    marginBottom: 5,
  },
  email: {
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
  redeemCard: {
    borderRadius: 15,
    margin: 10,
    marginTop: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  membershipStatusContainer: {
    alignItems: 'center',
    marginVertical: 15,
  },
  membershipStatusText: {
    fontSize: 18,
    fontWeight: 'bold',
  },
  membershipButton: {
    backgroundColor: '#f39c12',
    borderRadius: 25,
    paddingVertical: 12,
    marginVertical: 10,
  },
  membershipButtonTitle: {
    color: 'white',
    fontWeight: 'bold',
  },
  inputContainer: {
    paddingHorizontal: 0,
  },
  input: {
    fontSize: 16,
  },
  redeemButton: {
    backgroundColor: '#9b59b6',
    borderRadius: 25,
    paddingVertical: 12,
    marginVertical: 10,
  },
  redeemButtonTitle: {
    color: 'white',
    fontWeight: 'bold',
  },
  logoutButton: {
    backgroundColor: '#e74c3c',
    borderRadius: 25,
    paddingVertical: 12,
    marginVertical: 10,
  },
  logoutButtonTitle: {
    color: 'white',
    fontWeight: 'bold',
  },
});

export default ProfileScreen;
