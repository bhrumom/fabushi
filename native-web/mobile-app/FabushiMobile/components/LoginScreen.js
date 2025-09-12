import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Alert,
  TouchableOpacity,
} from 'react-native';
import { Button, Input, Card, Icon } from 'react-native-elements';
import authManager from '../../../shared/auth.js';

const LoginScreen = ({ navigation }) => {
  const [isLogin, setIsLogin] = useState(true);
  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const validateEmail = (email) => {
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return re.test(email);
  };

  const validatePassword = (password) => {
    // 密码至少8位，包含字母和数字
    const re = /^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{8,}$/;
    return re.test(password);
  };

  const handleLogin = async () => {
    if (!username.trim()) {
      Alert.alert('请输入用户名');
      return;
    }

    if (!password) {
      Alert.alert('请输入密码');
      return;
    }

    setLoading(true);
    try {
      const result = await authManager.login({
        username: username.trim(),
        password: password,
      });

      if (result.success) {
        Alert.alert('登录成功', '欢迎回来！', [
          { text: '确定', onPress: () => navigation.navigate('Home') }
        ]);
      } else {
        Alert.alert('登录失败', result.error);
      }
    } catch (error) {
      Alert.alert('登录错误', error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleRegister = async () => {
    if (!username.trim()) {
      Alert.alert('请输入用户名');
      return;
    }

    if (!email.trim()) {
      Alert.alert('请输入邮箱地址');
      return;
    }

    if (!validateEmail(email.trim())) {
      Alert.alert('请输入有效的邮箱地址');
      return;
    }

    if (!password) {
      Alert.alert('请输入密码');
      return;
    }

    if (!validatePassword(password)) {
      Alert.alert('密码至少8位，包含字母和数字');
      return;
    }

    if (password !== confirmPassword) {
      Alert.alert('密码确认不匹配');
      return;
    }

    setLoading(true);
    try {
      const result = await authManager.register({
        username: username.trim(),
        email: email.trim(),
        password: password,
      });

      if (result.success) {
        Alert.alert('注册成功', '您的账户已创建，请登录', [
          { text: '确定', onPress: () => setIsLogin(true) }
        ]);
      } else {
        Alert.alert('注册失败', result.error);
      }
    } catch (error) {
      Alert.alert('注册错误', error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>✨ 全球法布施 ✨</Text>
        <Text style={styles.subtitle}>登录到您的账户</Text>
      </View>

      <Card containerStyle={styles.card}>
        <Card.Title>{isLogin ? '用户登录' : '用户注册'}</Card.Title>
        <Card.Divider />

        <Input
          placeholder="用户名"
          leftIcon={<Icon name="person" size={24} color="gray" />}
          value={username}
          onChangeText={setUsername}
          autoCapitalize="none"
          autoCorrect={false}
        />

        {!isLogin && (
          <Input
            placeholder="邮箱地址"
            leftIcon={<Icon name="email" size={24} color="gray" />}
            value={email}
            onChangeText={setEmail}
            autoCapitalize="none"
            autoCorrect={false}
            keyboardType="email-address"
          />
        )}

        <Input
          placeholder="密码"
          leftIcon={<Icon name="lock" size={24} color="gray" />}
          value={password}
          onChangeText={setPassword}
          secureTextEntry
        />

        {!isLogin && (
          <Input
            placeholder="确认密码"
            leftIcon={<Icon name="lock" size={24} color="gray" />}
            value={confirmPassword}
            onChangeText={setConfirmPassword}
            secureTextEntry
          />
        )}

        <Button
          title={loading ? "处理中..." : (isLogin ? "登录" : "注册")}
          onPress={isLogin ? handleLogin : handleRegister}
          loading={loading}
          disabled={loading}
          buttonStyle={styles.actionButton}
        />

        <View style={styles.switchContainer}>
          <Text style={styles.switchText}>
            {isLogin ? "还没有账户?" : "已有账户?"}
          </Text>
          <TouchableOpacity onPress={() => setIsLogin(!isLogin)}>
            <Text style={styles.switchLink}>
              {isLogin ? "立即注册" : "立即登录"}
            </Text>
          </TouchableOpacity>
        </View>

        {isLogin && (
          <TouchableOpacity style={styles.forgotPasswordContainer}>
            <Text style={styles.forgotPasswordText}>忘记密码?</Text>
          </TouchableOpacity>
        )}
      </Card>

      <View style={styles.footer}>
        <Text style={styles.footerText}>© 2025 全球法布施</Text>
        <Text style={styles.footerText}>传播佛法，利益众生</Text>
      </View>
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
    fontSize: 32,
    fontWeight: 'bold',
    color: '#2c3e50',
    marginBottom: 10,
  },
  subtitle: {
    fontSize: 18,
    color: '#7f8c8d',
  },
  card: {
    borderRadius: 15,
    margin: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  actionButton: {
    backgroundColor: '#66a6ff',
    borderRadius: 25,
    paddingVertical: 12,
    marginVertical: 10,
  },
  switchContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginVertical: 15,
  },
  switchText: {
    fontSize: 16,
    color: '#34495e',
  },
  switchLink: {
    fontSize: 16,
    color: '#66a6ff',
    fontWeight: 'bold',
    marginLeft: 5,
    textDecorationLine: 'underline',
  },
  forgotPasswordContainer: {
    alignItems: 'center',
    marginVertical: 10,
  },
  forgotPasswordText: {
    color: '#66a6ff',
    fontSize: 16,
    textDecorationLine: 'underline',
  },
  footer: {
    alignItems: 'center',
    marginVertical: 30,
  },
  footerText: {
    color: '#7f8c8d',
    fontSize: 14,
  },
});

export default LoginScreen;