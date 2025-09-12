const { createCanvas } = require('canvas');
const fs = require('fs');

// 创建一个 32x32 的画布
const canvas = createCanvas(32, 32);
const ctx = canvas.getContext('2d');

// 绘制背景（紫色）
ctx.fillStyle = '#667eea';
ctx.fillRect(0, 0, 32, 32);

// 绘制白色圆形
ctx.beginPath();
ctx.arc(16, 16, 10, 0, Math.PI * 2);
ctx.fillStyle = '#ffffff';
ctx.fill();

// 绘制"佛"字
ctx.font = 'bold 16px Arial';
ctx.textAlign = 'center';
ctx.textBaseline = 'middle';
ctx.fillStyle = '#667eea';
ctx.fillText('佛', 16, 17); // 稍微向下偏移以居中显示

// 保存为 PNG 文件
const buffer = canvas.toBuffer('image/png');
fs.writeFileSync('/Users/gloriachan/Documents/全球发送/native-web/desktop-app/assets/tray-icon.png', buffer);

console.log('托盘图标已生成：/Users/gloriachan/Documents/全球发送/native-web/desktop-app/assets/tray-icon.png');