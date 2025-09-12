// R2 下载问题修复脚本
// 这个脚本包含了几个常见的 R2 文件下载问题的修复方案

console.log('🔧 R2 下载问题修复脚本已加载');

// 修复方案 1: 改进的文件名编码处理
function normalizeFileName(fileName) {
    // 移除不可见字符和多余空格
    return fileName
        .replace(/[\u200B-\u200D\uFEFF]/g, '') // 移除零宽字符
        .replace(/\s+/g, ' ') // 合并多个空格为一个
        .trim(); // 移除首尾空格
}

// 修复方案 2: 改进的 R2 文件检查函数
async function checkR2FileExists(filePath) {
    const normalizedPath = normalizeFileName(filePath);
    
    console.log(`检查 R2 文件: "${normalizedPath}"`);
    console.log(`字符编码: [${Array.from(normalizedPath).map(c => c.charCodeAt(0)).join(', ')}]`);
    
    try {
        // 尝试多种编码方式
        const encodingMethods = [
            { name: 'encodeURIComponent', encode: encodeURIComponent },
            { name: 'encodeURI', encode: encodeURI },
            { name: 'manual', encode: (str) => str.replace(/ /g, '%20') },
            { name: 'none', encode: (str) => str }
        ];
        
        for (const method of encodingMethods) {
            const encodedPath = method.encode(normalizedPath);
            const url = `/r2?file=${encodedPath}`;
            
            console.log(`尝试 ${method.name} 编码: ${url}`);
            
            try {
                const response = await fetch(url, { method: 'HEAD' });
                if (response.ok) {
                    console.log(`✅ 文件存在! 使用 ${method.name} 编码成功`);
                    return { exists: true, url, method: method.name };
                } else {
                    console.log(`❌ ${method.name} 编码失败: ${response.status}`);
                }
            } catch (error) {
                console.log(`❌ ${method.name} 编码请求异常: ${error.message}`);
            }
        }
        
        return { exists: false, error: '所有编码方式都失败' };
    } catch (error) {
        return { exists: false, error: error.message };
    }
}

// 修复方案 3: 改进的 R2 文件下载函数
async function downloadR2File(filePath, options = {}) {
    const { useCache = true, retryCount = 3 } = options;
    
    // 首先检查文件是否存在
    const checkResult = await checkR2FileExists(filePath);
    if (!checkResult.exists) {
        throw new Error(`文件不存在: ${filePath} (${checkResult.error})`);
    }
    
    console.log(`开始下载 R2 文件: ${filePath}`);
    
    let lastError;
    for (let attempt = 1; attempt <= retryCount; attempt++) {
        try {
            const response = await fetch(checkResult.url);
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            const blob = await response.blob();
            console.log(`✅ 下载成功: ${filePath} (${(blob.size / 1024 / 1024).toFixed(2)} MB)`);
            return blob;
        } catch (error) {
            lastError = error;
            console.log(`❌ 下载尝试 ${attempt}/${retryCount} 失败: ${error.message}`);
            
            if (attempt < retryCount) {
                const delay = Math.pow(2, attempt) * 1000; // 指数退避
                console.log(`等待 ${delay}ms 后重试...`);
                await new Promise(resolve => setTimeout(resolve, delay));
            }
        }
    }
    
    throw new Error(`下载失败，已重试 ${retryCount} 次: ${lastError.message}`);
}

// 修复方案 4: 批量检查和修复 r2-assets.js 中的路径
async function validateAndFixR2Assets() {
    if (!window.r2DharmaAssets) {
        console.error('❌ 未找到 r2DharmaAssets 配置');
        return;
    }
    
    console.log('🔍 开始验证 R2 资产配置...');
    
    const issues = [];
    const fixes = [];
    
    function processNode(node, path = '') {
        if (node._files) {
            node._files.forEach((file, index) => {
                if (typeof file === 'object' && file.path) {
                    const originalPath = file.path;
                    const normalizedPath = normalizeFileName(originalPath);
                    
                    if (originalPath !== normalizedPath) {
                        issues.push({
                            type: 'path_normalization',
                            location: `${path}._files[${index}]`,
                            original: originalPath,
                            suggested: normalizedPath
                        });
                    }
                }
            });
        }
        
        for (const key in node) {
            if (key !== '_files') {
                processNode(node[key], path ? `${path}.${key}` : key);
            }
        }
    }
    
    processNode(window.r2DharmaAssets);
    
    if (issues.length > 0) {
        console.log(`发现 ${issues.length} 个潜在问题:`);
        issues.forEach((issue, index) => {
            console.log(`${index + 1}. ${issue.type} at ${issue.location}`);
            console.log(`   原始: "${issue.original}"`);
            console.log(`   建议: "${issue.suggested}"`);
        });
        
        // 生成修复代码
        console.log('\n🔧 建议的修复代码:');
        issues.forEach(issue => {
            if (issue.type === 'path_normalization') {
                console.log(`// 修复路径: ${issue.location}`);
                console.log(`// 将 "${issue.original}" 改为 "${issue.suggested}"`);
            }
        });
    } else {
        console.log('✅ 所有路径格式正常');
    }
    
    return { issues, fixes };
}

// 修复方案 5: Worker.js 中的 R2 处理改进
function getImprovedR2Handler() {
    return `
// 改进的 R2 文件处理逻辑
if (pathname === '/r2' && url.searchParams.has('file')) {
    let fileKey = url.searchParams.get('file').trim();
    
    if (!fileKey) {
        return new Response('错误：未指定文件参数', { status: 400, headers: corsHeaders });
    }
    
    // 文件名标准化处理
    fileKey = fileKey
        .replace(/[\\u200B-\\u200D\\uFEFF]/g, '') // 移除零宽字符
        .replace(/\\s+/g, ' ') // 合并多个空格
        .trim(); // 移除首尾空格
    
    if (!env.R2_BUCKET) {
        return new Response('错误：R2 存储桶未绑定到此 Worker', { status: 500, headers: corsHeaders });
    }

    console.log(\`R2 请求 - 方法: \${method}, 文件: "\${fileKey}"\`);
    console.log(\`文件 Key 长度: \${fileKey.length}\`);
    console.log(\`文件 Key 字符编码: [\${Array.from(fileKey).map(c => c.charCodeAt(0)).join(', ')}]\`);

    if (method === 'HEAD') {
        try {
            const headObject = await env.R2_BUCKET.head(fileKey);
            if (headObject === null) {
                console.log(\`文件不存在: "\${fileKey}"\`);
                
                // 尝试列出相似文件以帮助调试
                try {
                    const listResult = await env.R2_BUCKET.list({ prefix: fileKey.substring(0, 5) });
                    if (listResult.objects.length > 0) {
                        console.log('相似文件:');
                        listResult.objects.forEach(obj => {
                            console.log(\`  - "\${obj.key}"\`);
                        });
                    }
                } catch (listError) {
                    console.log('无法列出相似文件:', listError.message);
                }
                
                return new Response('错误：在 R2 存储桶中未找到指定的文件', { 
                    status: 404, 
                    headers: corsHeaders 
                });
            }

            console.log(\`R2 HEAD 成功: size=\${headObject.size}, etag=\${headObject.httpEtag}\`);

            const headers = new Headers();
            headObject.writeHttpMetadata(headers);
            headers.set('etag', headObject.httpEtag);
            headers.set('Content-Length', String(headObject.size));
            headers.set('Accept-Ranges', 'bytes');
            headers.set('Access-Control-Allow-Origin', '*');
            headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, Range');
            headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
            headers.set('Access-Control-Expose-Headers', 'Content-Length, Content-Range, Etag');
            headers.set('Cache-Control', 'public, max-age=31536000'); // 1年缓存

            return new Response(null, { status: 200, headers });
        } catch (error) {
            console.error('R2 HEAD 请求失败:', error);
            return new Response(\`R2 访问错误: \${error.message}\`, { 
                status: 500, 
                headers: corsHeaders 
            });
        }
    }
    
    // GET 请求处理...
    // (类似的改进逻辑)
}
`;
}

// 导出修复函数
if (typeof window !== 'undefined') {
    window.R2FixUtils = {
        normalizeFileName,
        checkR2FileExists,
        downloadR2File,
        validateAndFixR2Assets,
        getImprovedR2Handler
    };
    
    console.log('✅ R2 修复工具已加载到 window.R2FixUtils');
}

// 如果在 Node.js 环境中
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        normalizeFileName,
        checkR2FileExists,
        downloadR2File,
        validateAndFixR2Assets,
        getImprovedR2Handler
    };
}