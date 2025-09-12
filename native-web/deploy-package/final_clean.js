const fs = require('fs');

// 读取文件
const filePath = './public/sender.js';
let lines = fs.readFileSync(filePath, 'utf8').split('\n');

console.log('原始行数:', lines.length);

// 定义要检查的重复代码模式
const duplicatePatterns = [
  {
    name: 'handleCountryStatusUpdate',
    pattern: /this\.countryStatus\[country\] = status;\s*this\.updateCountryStatus\(\);/g
  },
  {
    name: 'handleCountryComplete',
    pattern: /this\.countryStatus\[country\] = 'complete';\s*this\.updateCountryStatus\(\);/g
  },
  {
    name: 'handleCycleComplete',
    pattern: /this\.logMessage\(`✅ 第\$\{cycle\}轮完成: \$\{completedFiles\} 个文件，\$\{totalDispatches\} 个任务`\);\s*$/g
  },
  {
    name: 'handleDelayProgress',
    pattern: /this\.sentDataEl\.innerHTML = `\s*<div style="color: #e67e22; font-weight: bold;">\s*\.\.\. 正在等待 \$\{delay\} 秒 \.\.\.\s*<\/div>\s*<div style="font-size: 12px; color: #999;">\s*请保持网络畅通，后台仍在努力发送\s*<\/div>\s*`;\s*$/g
  },
  {
    name: 'handleWorkerProgress',
    pattern: /this\.sentDataEl\.innerHTML = `\s*<div style="color: #e67e22; font-weight: bold;">\s*\.\.\. 正在处理任务 \.\.\.\s*<\/div>\s*<div style="font-size: 12px; color: #999;">\s*\$\{progress\}%\s*<\/div>\s*`;\s*$/g
  }
];

// 统计每个模式的出现次数
const patternCounts = {};

for (const { name, pattern } of duplicatePatterns) {
  const content = lines.join('\n');
  const matches = content.match(pattern);
  patternCounts[name] = matches ? matches.length : 0;
}

console.log('模式统计:');
Object.entries(patternCounts).forEach(([name, count]) => {
  console.log(`  ${name}: ${count} 个重复`);
});

// 移除重复的代码块，只保留第一个
let content = lines.join('\n');

for (const { name, pattern } of duplicatePatterns) {
  const matches = content.match(pattern);
  if (matches && matches.length > 1) {
    console.log(`处理 ${name}，移除 ${matches.length - 1} 个重复`);
    
    // 只保留第一个匹配项，移除其余的
    const firstMatch = matches[0];
    for (let i = 1; i < matches.length; i++) {
      content = content.replace(matches[i], '');
    }
  }
}

// 修复可能的多余空行
content = content.replace(/\n\s*\n\s*\n/g, '\n\n');

// 写回文件
fs.writeFileSync(filePath, content, 'utf8');

const newLines = content.split('\n');
console.log('清理后行数:', newLines.length);
console.log('删除了', lines.length - newLines.length, '行重复代码');
console.log('重复代码清理完成');