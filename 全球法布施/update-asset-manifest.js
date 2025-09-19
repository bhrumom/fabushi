const fs = require('fs');
const path = require('path');

// 递归获取目录下所有文件
function getAllFiles(dirPath, arrayOfFiles = []) {
  const files = fs.readdirSync(dirPath);

  files.forEach(function(file) {
    const fullPath = path.join(dirPath, file);
    if (fs.statSync(fullPath).isDirectory()) {
      arrayOfFiles = getAllFiles(fullPath, arrayOfFiles);
    } else {
      // 过滤掉不需要的文件
      if (!file.startsWith('.') && 
          !file.endsWith('.DS_Store') && 
          !file.endsWith('.json') &&
          !file.includes('node_modules')) {
        arrayOfFiles.push(fullPath);
      }
    }
  });

  return arrayOfFiles;
}

// 主函数
function updateAssetManifest() {
  const webAssetsDir = path.join(__dirname, 'web/assets');
  const builtInAssetsDir = path.join(__dirname, 'assets/built_in');
  const manifestPath = path.join(__dirname, 'assets/data/asset-manifest.json');

  console.log('正在扫描素材目录...');
  
  const manifest = [];

  // 扫描 web/assets 目录
  if (fs.existsSync(webAssetsDir)) {
    console.log('扫描 web/assets 目录...');
    const webFiles = getAllFiles(webAssetsDir);
    webFiles.forEach(filePath => {
      const relativePath = path.relative(__dirname, filePath).replace(/\\/g, '/');
      manifest.push({
        key: relativePath,
        source: 'static'
      });
    });
    console.log(`web/assets 目录找到 ${webFiles.length} 个文件`);
  }

  // 扫描 assets/built_in 目录
  if (fs.existsSync(builtInAssetsDir)) {
    console.log('扫描 assets/built_in 目录...');
    const builtInFiles = getAllFiles(builtInAssetsDir);
    builtInFiles.forEach(filePath => {
      const relativePath = path.relative(__dirname, filePath).replace(/\\/g, '/');
      manifest.push({
        key: relativePath,
        source: 'local'
      });
    });
    console.log(`assets/built_in 目录找到 ${builtInFiles.length} 个文件`);
  }

  // 添加现有的本地数据文件
  manifest.push({
    key: "assets/data/r2-files-list.json",
    source: "local"
  });

  console.log(`总共找到 ${manifest.length} 个素材文件`);

  // 写入清单文件
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2), 'utf8');
  console.log(`素材清单已更新: ${manifestPath}`);
  
  // 显示一些示例文件
  console.log('\n素材清单示例:');
  manifest.slice(0, 10).forEach((item, index) => {
    console.log(`${index + 1}. ${item.key} (${item.source})`);
  });
  
  if (manifest.length > 10) {
    console.log(`... 还有 ${manifest.length - 10} 个文件`);
  }
}

// 运行脚本
updateAssetManifest();