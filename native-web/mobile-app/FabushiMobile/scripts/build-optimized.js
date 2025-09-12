#!/usr/bin/env node

// React Native 应用性能优化构建脚本

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

console.log('开始优化构建 React Native 应用...');

try {
  // 1. 清理构建缓存
  console.log('1. 清理构建缓存...');
  execSync('npx react-native start --reset-cache', { stdio: 'inherit' });
  
  // 2. 运行 ESLint 检查
  console.log('2. 运行代码质量检查...');
  execSync('npx eslint .', { stdio: 'inherit' });
  
  // 3. 运行测试
  console.log('3. 运行测试...');
  execSync('npm test', { stdio: 'inherit' });
  
  // 4. 优化图片资源
  console.log('4. 优化图片资源...');
  // 在实际应用中，您可以使用像 imagemin 这样的工具来优化图片
  
  // 5. 构建应用
  console.log('5. 构建应用...');
  // 对于 Android
  execSync('npx react-native build-android', { stdio: 'inherit' });
  
  // 对于 iOS
  execSync('npx react-native build-ios', { stdio: 'inherit' });
  
  console.log('优化构建完成！');
} catch (error) {
  console.error('构建过程中出错:', error.message);
  process.exit(1);
}