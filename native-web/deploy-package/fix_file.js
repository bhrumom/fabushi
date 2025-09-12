const fs = require('fs');

// 读取文件
const filePath = './public/sender.js';
let lines = fs.readFileSync(filePath, 'utf8').split('\n');

console.log('原始行数:', lines.length);

// 查找并修复文件结构问题
// 1. 查找重复的类定义
let firstClassIndex = -1;
let secondClassIndex = -1;

for (let i = 0; i < lines.length; i++) {
  if (lines[i].includes('class GlobalDharmaSender {')) {
    if (firstClassIndex === -1) {
      firstClassIndex = i;
    } else {
      secondClassIndex = i;
      break;
    }
  }
}

// 如果找到重复的类定义，移除第二个开始的部分
if (secondClassIndex !== -1) {
  console.log(`发现重复的类定义，从第 ${secondClassIndex + 1} 行开始移除`);
  lines.splice(secondClassIndex, lines.length - secondClassIndex);
}

// 2. 修复不完整的函数定义
// 查找不完整的 handleWorkerMessage 函数
let incompleteFunctionStart = -1;
let incompleteFunctionEnd = -1;

for (let i = 0; i < lines.length; i++) {
  if (lines[i].includes('case \'country-completed\':')) {
    incompleteFunctionStart = i;
  }
  
  if (incompleteFunctionStart !== -1 && lines[i].includes('    }handleCycleComplete(payload) {')) {
    incompleteFunctionEnd = i;
    break;
  }
}

// 如果找到不完整的函数，修复它
if (incompleteFunctionStart !== -1 && incompleteFunctionEnd !== -1) {
  console.log(`修复不完整的函数定义，从第 ${incompleteFunctionStart + 1} 行到第 ${incompleteFunctionEnd} 行`);
  
  // 移除不完整的部分
  lines.splice(incompleteFunctionStart, incompleteFunctionEnd - incompleteFunctionStart);
  
  // 在正确的位置添加缺失的右花括号
  lines.splice(incompleteFunctionStart, 0, '                }');
  lines.splice(incompleteFunctionStart + 1, 0, '                break;');
  lines.splice(incompleteFunctionStart + 2, 0, '                ');
}

// 3. 确保文件以正确的结构结束
// 查找最后一个预期的函数
let lastFunctionIndex = -1;
for (let i = lines.length - 1; i >= 0; i--) {
  if (lines[i].includes('document.addEventListener(\'DOMContentLoaded\', () => {')) {
    lastFunctionIndex = i;
    break;
  }
}

// 如果没有找到结束部分，添加它
if (lastFunctionIndex === -1) {
  // 查找类定义的结束位置
  let classEndIndex = -1;
  for (let i = lines.length - 1; i >= 0; i--) {
    if (lines[i].trim() === '}' && !lines[i].includes('}');') {
      classEndIndex = i;
      break;
    }
  }
  
  if (classEndIndex !== -1) {
    // 添加缺失的结束部分
    lines.splice(classEndIndex + 1, 0, '');
    lines.splice(classEndIndex + 2, 0, 'document.addEventListener(\'DOMContentLoaded\', () => {');
    lines.splice(classEndIndex + 3, 0, '    new GlobalDharmaSender();');
    lines.splice(classEndIndex + 4, 0, '});');
    lines.splice(classEndIndex + 5, 0, '');
  }
}

// 4. 移除可能存在的多余空行
let cleanedLines = [];
for (let i = 0; i < lines.length; i++) {
  // 避免连续的空行
  if (i > 0 && lines[i].trim() === '' && lines[i-1].trim() === '') {
    continue;
  }
  cleanedLines.push(lines[i]);
}

// 写回文件
fs.writeFileSync(filePath, cleanedLines.join('\n'), 'utf8');

console.log('修复后行数:', cleanedLines.length);
console.log('文件修复完成');