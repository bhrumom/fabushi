#!/usr/bin/env node
// 完整修复所有CORS问题的脚本

const fs = require('fs');

console.log('🔧 开始修复CORS问题...');

// 读取当前配置文件
let content = fs.readFileSync('global-country-servers.js', 'utf8');

// 支持CORS的替代端点
const corsAlternatives = [
    'https://httpbin.org/post',
    'https://jsonplaceholder.typicode.com/posts', 
    'https://reqres.in/api/posts'
];

// 统计替换次数
let replacements = 0;

// 替换所有 postman-echo.com 引用
content = content.replace(/'https:\/\/postman-echo\.com\/post'/g, (match) => {
    replacements++;
    // 轮换使用不同的替代端点
    const alternative = corsAlternatives[replacements % corsAlternatives.length];
    return `'${alternative}'`;
});

// 写回文件
fs.writeFileSync('global-country-servers.js', content);

console.log(`✅ 修复完成！共替换了 ${replacements} 个 postman-echo.com 端点`);
console.log('🌍 所有国家现在都使用支持CORS的端点');

// 验证修复结果
const verifyContent = fs.readFileSync('global-country-servers.js', 'utf8');
const remainingPostmanEcho = (verifyContent.match(/postman-echo\.com/g) || []).length;

if (remainingPostmanEcho === 0) {
    console.log('🎉 验证成功：已完全移除所有 postman-echo.com 引用');
} else {
    console.log(`⚠️ 警告：仍有 ${remainingPostmanEcho} 个 postman-echo.com 引用未被替换`);
}