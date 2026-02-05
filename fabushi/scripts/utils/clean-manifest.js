const fs = require('fs');
const path = require('path');

const manifestPath = path.join(__dirname, '../../assets/data/asset-manifest.json');

try {
  // 读取manifest
  const manifestContent = fs.readFileSync(manifestPath, 'utf8');
  const manifest = JSON.parse(manifestContent);
  
  console.log(`原始条目数: ${manifest.length}`);
  
  // 过滤掉重复的条目：保留built_in路径，删除非built_in的重复路径
  const cleaned = manifest.filter(item => {
    const key = item.key || '';
    
    // 如果路径包含built_in，保留
    if (key.includes('/built_in/')) {
      return true;
    }
    
    // 如果路径不包含built_in，检查是否存在对应的built_in版本
    const builtInVersion = key.replace('assets/', 'assets/built_in/');
    const hasBuiltInVersion = manifest.some(m => m.key === builtInVersion);
    
    // 如果存在built_in版本，删除这个非built_in的条目
    if (hasBuiltInVersion) {
      console.log(`删除重复条目: ${key}`);
      return false;
    }
    
    // 否则保留
    return true;
  });
  
  console.log(`清理后条目数: ${cleaned.length}`);
  console.log(`删除了 ${manifest.length - cleaned.length} 个重复条目`);
  
  // 写回文件
  fs.writeFileSync(manifestPath, JSON.stringify(cleaned, null, 2));
  console.log('✅ Manifest清理完成！');
  
} catch (error) {
  console.error('❌ 清理manifest失败:', error);
  process.exit(1);
}
