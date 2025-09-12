#!/usr/bin/env node

// Electron 桌面应用性能优化构建脚本

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

console.log('开始优化构建 Electron 桌面应用...');

try {
  // 1. 清理构建目录
  console.log('1. 清理构建目录...');
  if (fs.existsSync(path.join(__dirname, '../dist'))) {
    fs.rmSync(path.join(__dirname, '../dist'), { recursive: true });
  }
  
  // 2. 运行 ESLint 检查
  console.log('2. 运行代码质量检查...');
  execSync('npx eslint .', { stdio: 'inherit' });
  
  // 3. 运行测试
  console.log('3. 运行测试...');
  execSync('node test.js', { stdio: 'inherit' });
  
  // 4. 优化资源文件
  console.log('4. 优化资源文件...');
  // 在实际应用中，您可以使用像 imagemin 这样的工具来优化图片
  
  // 5. 使用 Webpack 构建主进程
  console.log('5. 构建主进程...');
  execSync('npx webpack --config webpack.config.js', { stdio: 'inherit' });
  
  // 6. 使用 electron-builder 构建应用
  console.log('6. 构建桌面应用...');
  execSync('npx electron-builder --mac --win --linux', { stdio: 'inherit' });
  
  console.log('优化构建完成！');
  console.log('构建文件位于 dist/ 目录中');
} catch (error) {
  console.error('构建过程中出错:', error.message);
  process.exit(1);
}