const fs = require('fs');
const path = require('path');

const assetsDir = path.join(__dirname, 'assets');
const outputFile = path.join(__dirname, 'dharma-assets.js');
const r2AssetsFile = path.join(__dirname, 'r2-assets.js');
const indexHtmlPath = path.join(__dirname, 'index.html');


/**
 * 从 r2-assets.js 文件中提取所有 R2 文件的路径。
 * @returns {Set<string>} - 一个包含所有 R2 文件路径的 Set。
 */
function getR2AssetPaths() {
    try {
        const r2Content = fs.readFileSync(r2AssetsFile, 'utf8');
        // 伪造一个 window 对象来执行 R2 资源文件
        const fakeWindow = {};
        new Function('window', r2Content)(fakeWindow);

        if (fakeWindow.r2DharmaAssets) {
            const paths = new Set();
            // 遍历 R2 资产对象的所有类别
            for (const category in fakeWindow.r2DharmaAssets) {
                // 检查是否存在 _files 数组
                if (fakeWindow.r2DharmaAssets[category]._files) {
                    // 从每个文件对象中提取 path 属性
                    fakeWindow.r2DharmaAssets[category]._files.forEach(file => {
                        if (file.path) {
                            paths.add(file.path);
                        }
                    });
                }
            }
            return paths;
        }
    } catch (error) {
        console.error('❌ 读取或解析 R2 资源文件时出错:', error);
    }
    return new Set(); // 如果出错则返回空集合
}


/**
 * 递归扫描目录并生成一个代表其结构的树形对象。
 * @param {string} dir - 要扫描的目录路径。
 * @param {Set<string>} r2Paths - 从R2配置文件中读取到的云端资源路径集合。
 * @param {string} currentPath - 当前正在扫描的相对路径。
 * @returns {object} - 代表目录结构的树形对象。
 */
function generateTree(dir, r2Paths, currentPath = '') {
    const tree = {};
    const items = fs.readdirSync(dir);

    for (const item of items) {
        if (item === '.DS_Store') {
            continue;
        }

        const itemPath = path.join(dir, item);
        const relativePath = path.join(currentPath, item); // 计算相对路径
        const stat = fs.statSync(itemPath);

        if (stat.isDirectory()) {
            const subTree = generateTree(itemPath, r2Paths, relativePath);
            // 仅当子目录不为空时才添加
            if (Object.keys(subTree).length > 0) {
                tree[item] = subTree;
            }
        } else {
            // 如果文件路径不存在于 R2 资源列表中，则添加到本地资源树
            if (!r2Paths.has(relativePath)) {
                if (!tree._files) {
                    tree._files = [];
                }
                tree._files.push(item);
            }
        }
    }
    return tree;
}

/**
 * 更新 index.html 文件中 dharma-assets.js 脚本标签的版本号（时间戳）。
 * 这可以防止浏览器缓存旧的资源文件。
 */
function updateHtmlTimestamp() {
    try {
        let content = fs.readFileSync(indexHtmlPath, 'utf8');
        const timestamp = Date.now();
        
        // 正则表达式匹配 <script src="dharma-assets.js..."></script>
        // 并用新的时间戳替换查询字符串。
        const regex = /(<script\s+src="dharma-assets\.js)(\?v=[^"]*)?("><\/script>)/;
        
        if (regex.test(content)) {
            const newScriptTag = `$1?v=${timestamp}$3`;
            content = content.replace(regex, newScriptTag);
            fs.writeFileSync(indexHtmlPath, content, 'utf8');
            console.log(`✅ 已成功更新 index.html 中的脚本版本为: ${timestamp}`);
        } else {
            console.warn(`⚠️ 在 index.html 中未找到 "dharma-assets.js" 的脚本标签。`);
        }
    } catch (error) {
        console.error('❌ 更新 index.html 时出错:', error);
    }
}


// --- 主执行逻辑 ---
try {
    // 1. 获取所有 R2 (云端) 资源的路径
    console.log('正在读取 R2 资源列表...');
    const r2AssetPaths = getR2AssetPaths();
    console.log(`↳ 找到了 ${r2AssetPaths.size} 个 R2 资源。`);

    // 2. 生成本地资源树，同时排除 R2 资源
    console.log(`正在扫描本地资源目录: ${assetsDir}`);
    const assetTree = generateTree(assetsDir, r2AssetPaths);
    const outputContent = `window.dharmaAssets = ${JSON.stringify(assetTree, null, 2)};`;

    // 3. 写入处理后的本地资源树 JS 文件
    fs.writeFileSync(outputFile, outputContent, 'utf8');
    console.log(`✅ 成功生成过滤后的本地资源树到: ${outputFile}`);

    // 4. 更新 HTML 文件中的时间戳以避免缓存问题
    updateHtmlTimestamp();

} catch (error) {
    console.error('❌ 生成资源树时发生严重错误:', error);
}