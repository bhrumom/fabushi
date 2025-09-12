const fs = require('fs');

// 读取文件
const filePath = './public/sender.js';
let lines = fs.readFileSync(filePath, 'utf8').split('\n');

console.log('原始行数:', lines.length);

// 定义要检查的函数名
const functionNames = [
  'handleCountryStatusUpdate',
  'handleCountryComplete',
  'handleCycleComplete',
  'handleDelayProgress',
  'handleWorkerProgress'
];

// 统计每个函数的出现次数
const functionCounts = {};
const functionLines = {};

// 首先统计函数出现次数和位置
for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  for (const funcName of functionNames) {
    if (line.includes(funcName + '(payload)')) {
      if (!functionCounts[funcName]) {
        functionCounts[funcName] = 0;
        functionLines[funcName] = [];
      }
      functionCounts[funcName]++;
      functionLines[funcName].push(i);
    }
  }
}

console.log('函数统计:');
Object.entries(functionCounts).forEach(([func, count]) => {
  console.log(`  ${func}: ${count} 个定义`);
});

// 移除重复的函数定义，只保留第一个
const linesToRemove = new Set();

for (const [funcName, lineNumbers] of Object.entries(functionLines)) {
  if (lineNumbers.length > 1) {
    console.log(`处理 ${funcName}，移除 ${lineNumbers.length - 1} 个重复定义`);
    
    // 对于每个重复的定义，找到整个函数块并标记为删除
    for (let i = 1; i < lineNumbers.length; i++) {
      const startLine = lineNumbers[i];
      
      // 找到函数开始的位置
      let funcStart = startLine;
      while (funcStart >= 0 && !lines[funcStart].includes(funcName + '(payload)')) {
        funcStart--;
      }
      
      // 找到函数结束的位置
      let funcEnd = startLine;
      let braceCount = 0;
      let foundStart = false;
      
      while (funcEnd < lines.length) {
        const line = lines[funcEnd];
        
        // 查找函数开始的大括号
        if (line.includes(funcName + '(payload)')) {
          foundStart = true;
        }
        
        if (foundStart) {
          // 计算大括号
          for (const char of line) {
            if (char === '{') braceCount++;
            if (char === '}') braceCount--;
          }
          
          // 当大括号匹配时，函数结束
          if (braceCount === 0 && foundStart) {
            break;
          }
        }
        
        funcEnd++;
      }
      
      // 标记从函数开始到结束的所有行进行删除
      for (let j = funcStart; j <= funcEnd; j++) {
        linesToRemove.add(j);
      }
    }
  }
}

// 创建新的行数组，排除标记为删除的行
const newLines = [];
for (let i = 0; i < lines.length; i++) {
  if (!linesToRemove.has(i)) {
    newLines.push(lines[i]);
  }
}

// 修复语法错误：确保所有函数参数正确解构
for (let i = 0; i < newLines.length; i++) {
  // 修复函数参数解构
  newLines[i] = newLines[i].replace(/(\w+)\(payload\)\s*\{([^}]*\}\s*=\s*payload;)/, '$1(payload) {\n        const { $2');
  newLines[i] = newLines[i].replace(/\}\s*=\s*payload;/g, '');
  
  // 修复可能的语法错误
  newLines[i] = newLines[i].replace(/(\w+)\(\w+\)\s*\{[^}]*\}(\w+)/g, '$1(payload) {\n        const { $2 } = payload;');
}

// 写回文件
fs.writeFileSync(filePath, newLines.join('\n'), 'utf8');

console.log('清理后行数:', newLines.length);
console.log('删除了', lines.length - newLines.length, '行重复代码');
console.log('重复代码清理完成');