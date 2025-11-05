const fs = require('fs');
const path = require('path');

const assetsDir = path.join(__dirname, 'web', 'assets');
const manifestPath = path.join(__dirname, 'web', 'asset-manifest.json');

function getFiles(dir) {
  const dirents = fs.readdirSync(dir, { withFileTypes: true });
  const files = dirents.map((dirent) => {
    const res = path.resolve(dir, dirent.name);
    // 从web/assets目录开始计算相对路径
    const relativePath = path.relative(path.join(__dirname, 'web', 'assets'), res).replace(/\\/g, '/');
    // 添加assets/前缀，因为实际部署时文件在assets目录下
    const finalPath = 'assets/' + relativePath;
    return dirent.isDirectory() ? getFiles(res) : { key: finalPath, source: 'static' };
  });
  return Array.prototype.concat(...files);
}

try {
  if (fs.existsSync(assetsDir)) {
    const assetFiles = getFiles(assetsDir);
    fs.writeFileSync(manifestPath, JSON.stringify(assetFiles, null, 2));
    console.log(`Asset manifest created successfully at ${manifestPath}`);
  } else {
    console.log(`Assets directory not found: ${assetsDir}. Skipping manifest generation.`);
    // Create an empty manifest if the assets directory doesn't exist
    fs.writeFileSync(manifestPath, JSON.stringify([], null, 2));
  }
} catch (error) {
  console.error('Error generating asset manifest:', error);
  process.exit(1);
}