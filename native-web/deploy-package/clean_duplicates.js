const fs = require('fs');

// 读取文件
const filePath = './public/sender.js';
let content = fs.readFileSync(filePath, 'utf8');

console.log('原始文件大小:', content.length, '字符');

// 定义要移除的重复函数
const duplicateFunctions = [
  'handleCountryStatusUpdate',
  'handleCountryComplete',
  'handleCycleComplete',
  'handleDelayProgress',
  'handleWorkerProgress'
];

// 用于跟踪已保留的函数
const preservedFunctions = new Set();

// 函数用于移除重复的函数定义
function removeDuplicateFunctions(content, functionName) {
  // 创建匹配函数定义的正则表达式
  const functionRegex = new RegExp(
    `(\\s*${functionName}\\s*\\([^}]*\\{[\\s\\S]*?\\}\\s*){2,}`,
    'g'
  );
  
  // 替换重复的函数定义，只保留第一个
  return content.replace(functionRegex, (match) => {
    // 如果已经保留过这个函数，就完全移除
    if (preservedFunctions.has(functionName)) {
      return '';
    }
    
    // 否则，只保留第一个定义
    const firstDefinition = match.match(new RegExp(`${functionName}\\s*\\([^}]*\\{[\\s\\S]*?\\}`, 's'));
    if (firstDefinition) {
      preservedFunctions.add(functionName);
      return firstDefinition[0];
    }
    return match;
  });
}

// 移除重复函数
for (const func of duplicateFunctions) {
  content = removeDuplicateFunctions(content, func);
}

// 修复文件末尾的语法错误
// 移除多余的闭合大括号和不完整的代码块
content = content.replace(/\s*\}\s*\}\s*catch\s*\(\s*\w*\s*\)\s*\{\s*.*?\s*\}\s*$/s, '\n}\n\n');

// 移除可能存在的重复类定义
content = content.replace(/(\s*class\s+GlobalDharmaSender\s*\{[\s\S]*?}\s*){2,}/, '$1');

// 写回文件
fs.writeFileSync(filePath, content, 'utf8');

console.log('清理后的文件大小:', content.length, '字符');
console.log('重复代码清理完成');