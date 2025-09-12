/**
 * @format
 */

import 'react-native';
import React from 'react';
import App from '../App';

// Note: test renderer must be required after react-native.
import renderer from 'react-test-renderer';

it('renders correctly', () => {
  renderer.create(<App />);
});

// 测试主屏幕组件
import HomeScreen from '../components/HomeScreen';

it('renders HomeScreen correctly', () => {
  const navigation = { navigate: jest.fn() };
  renderer.create(<HomeScreen navigation={navigation} />);
});

// 测试登录屏幕组件
import LoginScreen from '../components/LoginScreen';

it('renders LoginScreen correctly', () => {
  const navigation = { navigate: jest.fn() };
  renderer.create(<LoginScreen navigation={navigation} />);
});

// 测试个人资料屏幕组件
import ProfileScreen from '../components/ProfileScreen';

it('renders ProfileScreen correctly', () => {
  const navigation = { navigate: jest.fn() };
  renderer.create(<ProfileScreen navigation={navigation} />);
});

// 测试文件发送组件
import FileSender from '../components/FileSender';

it('renders FileSender correctly', () => {
  const mockOnLog = jest.fn();
  renderer.create(<FileSender onLog={mockOnLog} />);
});

// 测试支付屏幕组件
import PaymentScreen from '../components/PaymentScreen';

it('renders PaymentScreen correctly', () => {
  const navigation = { navigate: jest.fn() };
  renderer.create(<PaymentScreen navigation={navigation} />);
});