import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Alert,
  Platform,
} from 'react-native';
import { Button, Card, Icon, ListItem, Divider } from 'react-native-elements';
import { requestPurchase, getProducts, flushFailedPurchasesCachedAsPendingAndroid } from 'react-native-iap';
import authManager from '../../../shared/auth.js';

// 产品ID应该与您在应用商店中配置的ID匹配
const PRODUCT_IDS = Platform.select({
  ios: ['membership_monthly', 'membership_quarterly', 'membership_yearly'],
  android: ['membership_monthly', 'membership_quarterly', 'membership_yearly'],
});

const PaymentScreen = ({ navigation }) => {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(false);
  const [currentUser, setCurrentUser] = useState(null);
  const [membershipStatus, setMembershipStatus] = useState(null);

  useEffect(() => {
    // 获取用户信息
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

    // 初始化IAP
    initializeIAPConnection();

    return () => {
      // 清理
    };
  }, []);

  const initializeIAPConnection = async () => {
    try {
      if (Platform.OS === 'android') {
        await flushFailedPurchasesCachedAsPendingAndroid();
      }
      
      const products = await getProducts({ skus: PRODUCT_IDS });
      setProducts(products);
    } catch (error) {
      console.warn('获取产品信息时出错:', error);
      Alert.alert('错误', '无法获取会员产品信息');
    }
  };

  const handlePurchase = async (sku) => {
    if (!authManager.isLoggedIn()) {
      Alert.alert('请先登录', '购买会员需要先登录账户');
      return;
    }

    setLoading(true);
    try {
      // 请求购买
      const purchase = await requestPurchase({ sku });
      console.log('购买结果:', purchase);
      
      Alert.alert('购买成功', '感谢您的购买！会员权益已激活');
      
      // 重新检查会员状态
      const status = await authManager.checkMembership();
      setMembershipStatus(status);
    } catch (error) {
      console.error('购买过程中出错:', error);
      if (error.code !== 'E_USER_CANCELLED') {
        Alert.alert('购买失败', error.message || '购买过程中发生错误');
      }
    } finally {
      setLoading(false);
    }
  };

  const handleAlipayPurchase = () => {
    if (!authManager.isLoggedIn()) {
      Alert.alert('请先登录', '购买会员需要先登录账户');
      return;
    }

    // 在实际应用中，您需要实现支付宝支付流程
    Alert.alert('功能说明', '在移动应用中，您可以通过支付宝完成购买。此功能需要集成支付宝SDK并实现相应的支付流程。');
  };

  const handleRedeemCode = () => {
    // 导航到个人资料页面进行兑换码操作
    navigation.navigate('Profile');
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

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Icon name="diamond" size={60} color="#f39c12" />
        <Text style={styles.title}>💎 会员中心</Text>
        <Text style={styles.subtitle}>解锁更多高级功能</Text>
      </View>

      <Card containerStyle={styles.card}>
        <Card.Title>当前会员状态</Card.Title>
        <Card.Divider />
        
        <View style={styles.membershipStatusContainer}>
          <Text style={[styles.membershipStatusText, { color: getMembershipStatusColor() }]}>
            {getMembershipStatusText()}
          </Text>
        </View>
        
        {!membershipStatus?.isActive && (
          <Text style={styles.nonMemberText}>
            成为会员可以享受无限制的全球法布施服务
          </Text>
        )}
      </Card>

      <Card containerStyle={styles.card}>
        <Card.Title>会员套餐</Card.Title>
        <Card.Divider />
        
        {products.length > 0 ? (
          products.map((product, index) => (
            <View key={product.productId}>
              <ListItem bottomDivider>
                <Icon name="shopping-cart" />
                <ListItem.Content>
                  <ListItem.Title>{product.title}</ListItem.Title>
                  <ListItem.Subtitle>{product.description}</ListItem.Subtitle>
                </ListItem.Content>
                <Text style={styles.price}>¥{product.price}</Text>
                <Button
                  title="购买"
                  onPress={() => handlePurchase(product.productId)}
                  loading={loading}
                  disabled={loading}
                  buttonStyle={styles.purchaseButton}
                />
              </ListItem>
              {index < products.length - 1 && <Divider />}
            </View>
          ))
        ) : (
          <Text style={styles.loadingText}>加载会员套餐中...</Text>
        )}
      </Card>

      <Card containerStyle={styles.card}>
        <Card.Title>其他支付方式</Card.Title>
        <Card.Divider />
        
        <Button
          title="支付宝支付"
          onPress={handleAlipayPurchase}
          buttonStyle={[styles.paymentButton, styles.alipayButton]}
          icon={<Icon name="account-balance-wallet" color="white" />}
        />
        
        <Button
          title="兑换码"
          onPress={handleRedeemCode}
          buttonStyle={[styles.paymentButton, styles.redeemButton]}
          icon={<Icon name="card-giftcard" color="white" />}
        />
      </Card>

      <Card containerStyle={styles.card}>
        <Card.Title>会员权益</Card.Title>
        <Card.Divider />
        
        <ListItem bottomDivider>
          <Icon name="check-circle" color="#27ae60" />
          <ListItem.Content>
            <ListItem.Title>无限制全球发送</ListItem.Title>
          </ListItem.Content>
        </ListItem>
        
        <ListItem bottomDivider>
          <Icon name="check-circle" color="#27ae60" />
          <ListItem.Content>
            <ListItem.Title>优先发送队列</ListItem.Title>
          </ListItem.Content>
        </ListItem>
        
        <ListItem bottomDivider>
          <Icon name="check-circle" color="#27ae60" />
          <ListItem.Content>
            <ListItem.Title>专属客服支持</ListItem.Title>
          </ListItem.Content>
        </ListItem>
        
        <ListItem>
          <Icon name="check-circle" color="#27ae60" />
          <ListItem.Content>
            <ListItem.Title>新功能优先体验</ListItem.Title>
          </ListItem.Content>
        </ListItem>
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
  membershipStatusContainer: {
    alignItems: 'center',
    marginVertical: 15,
  },
  membershipStatusText: {
    fontSize: 18,
    fontWeight: 'bold',
  },
  nonMemberText: {
    textAlign: 'center',
    color: '#7f8c8d',
    fontStyle: 'italic',
  },
  loadingText: {
    textAlign: 'center',
    color: '#7f8c8d',
    padding: 20,
  },
  price: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#27ae60',
    marginRight: 10,
  },
  purchaseButton: {
    backgroundColor: '#f39c12',
    borderRadius: 20,
    paddingHorizontal: 20,
  },
  paymentButton: {
    borderRadius: 25,
    paddingVertical: 12,
    marginVertical: 8,
  },
  alipayButton: {
    backgroundColor: '#1aad19',
  },
  redeemButton: {
    backgroundColor: '#9b59b6',
  },
});

export default PaymentScreen;
