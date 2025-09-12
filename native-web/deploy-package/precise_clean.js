const fs = require('fs');

// 读取文件
const filePath = './public/sender.js';
let content = fs.readFileSync(filePath, 'utf8');

console.log('原始文件大小:', content.length, '字符');

// 定义要移除的重复函数模式
const functionPatterns = [
  {
    name: 'handleCountryStatusUpdate',
    pattern: /handleCountryStatusUpdate\(payload\)\s*\{[^}]*\}[\s\n\r]*handleCountryStatusUpdate\(payload\)\s*\{[^}]*\}/g
  },
  {
    name: 'handleCountryComplete',
    pattern: /handleCountryComplete\(payload\)\s*\{[^}]*\}[\s\n\r]*handleCountryComplete\(payload\)\s*\{[^}]*\}/g
  },
  {
    name: 'handleCycleComplete',
    pattern: /handleCycleComplete\(payload\)\s*\{[^}]*\}[\s\n\r]*handleCycleComplete\(payload\)\s*\{[^}]*\}/g
  },
  {
    name: 'handleDelayProgress',
    pattern: /handleDelayProgress\(payload\)\s*\{[^}]*\}[\s\n\r]*handleDelayProgress\(payload\)\s*\{[^}]*\}/g
  },
  {
    name: 'handleWorkerProgress',
    pattern: /handleWorkerProgress\(payload\)\s*\{[^}]*\}[\s\n\r]*handleWorkerProgress\(payload\)\s*\{[^}]*\}/g
  }
];

// 用于跟踪清理统计
const stats = {
  handleCountryStatusUpdate: 0,
  handleCountryComplete: 0,
  handleCycleComplete: 0,
  handleDelayProgress: 0,
  handleWorkerProgress: 0
};

// 精确移除重复函数
function removeExactDuplicates(content, pattern, funcName) {
  let match;
  let newContent = content;
  
  // 查找所有匹配项
  while ((match = pattern.exec(content)) !== null) {
    // 找到两个连续的相同函数定义
    const fullMatch = match[0];
    
    // 提取第一个函数定义
    const firstFunction = fullMatch.match(/handle\w+\(payload\)\s*\{[^}]*\}/)[0];
    
    // 用第一个函数定义替换整个匹配项
    newContent = newContent.replace(fullMatch, firstFunction);
    stats[funcName]++;
  }
  
  return newContent;
}

// 应用清理
for (const { name, pattern } of functionPatterns) {
  content = removeExactDuplicates(content, pattern, name);
}

// 修复文件末尾可能存在的语法错误
// 移除多余的赋值语句
content = content.replace(/\}\s*=\s*payload;/g, '}');
content = content.replace(/=\s*payload;/g, '');

// 移除可能存在的重复代码块
content = content.replace(/(\s*handle\w+\(payload\)\s*\{[^}]*\}\s*){3,}/g, '$1');

// 写回文件
fs.writeFileSync(filePath, content, 'utf8');

console.log('清理统计:');
Object.entries(stats).forEach(([func, count]) => {
  console.log(`  ${func}: 移除了 ${count} 个重复定义`);
});

console.log('清理后的文件大小:', content.length, '字符');
console.log('精确重复代码清理完成');