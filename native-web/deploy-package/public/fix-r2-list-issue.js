// R2 列表问题修复脚本

// 修复方案 1: 改进的 R2 列表处理
function getImprovedR2ListHandler() {
    return `
// 改进的 R2 列表处理逻辑
if (pathname === '/r2' && url.searchParams.has('list')) {
    console.log('R2 列表请求开始');
    console.log('环境变量检查:', {
        hasR2Bucket: !!env.R2_BUCKET,
        envKeys: Object.keys(env || {}),
        bucketType: typeof env.R2_BUCKET
    });
    
    if (!env.R2_BUCKET) {
        console.error('R2_BUCKET 未绑定');
        return new Response('错误：R2 存储桶未绑定到此 Worker', { status: 500, headers: corsHeaders });
    }

    try {
        console.log('开始调用 R2 列表 API...');
        
        // 尝试不同的列表参数
        const listOptions = {};
        
        // 检查查询参数
        const limit = url.searchParams.get('limit');
        const prefix = url.searchParams.get('prefix');
        const cursor = url.searchParams.get('cursor');
        
        if (limit) listOptions.limit = parseInt(limit, 10);
        if (prefix) listOptions.prefix = prefix;
        if (cursor) listOptions.cursor = cursor;
        
        console.log('列表选项:', listOptions);
        
        const objects = await env.R2_BUCKET.list(listOptions);
        console.log('R2 列表 API 调用成功');
        console.log('返回结果类型:', typeof objects);
        console.log('返回结果键:', Object.keys(objects || {}));
        console.log('对象数量:', objects?.objects?.length || 0);
        
        if (!objects) {
            console.error('R2 列表返回 null');
            return jsonResponse({
                error: 'R2 列表返回空结果',
                objects: [],
                files: [],
                count: 0
            }, 500);
        }
        
        if (!objects.objects) {
            console.error('R2 列表返回的对象没有 objects 属性');
            console.log('实际返回:', objects);
            return jsonResponse({
                error: 'R2 列表格式异常',
                rawResponse: objects,
                objects: [],
                files: [],
                count: 0
            }, 500);
        }
        
        const fileList = objects.objects.map(obj => {
            console.log('处理对象:', obj.key, obj.size);
            return {
                key: obj.key,
                size: obj.size,
                uploaded: obj.uploaded,
                etag: obj.etag,
                httpEtag: obj.httpEtag
            };
        });

        console.log('最终文件列表:', fileList.map(f => f.key));

        return jsonResponse({
            objects: fileList,
            files: fileList, // 兼容性
            count: fileList.length,
            truncated: objects.truncated || false,
            cursor: objects.cursor || null
        });
        
    } catch (error) {
        console.error('R2 列表操作失败:', error);
        console.error('错误类型:', error.constructor.name);
        console.error('错误消息:', error.message);
        console.error('错误堆栈:', error.stack);
        
        return jsonResponse({ 
            error: '列出文件失败: ' + error.message,
            errorType: error.constructor.name,
            details: error.stack,
            objects: [],
            files: [],
            count: 0
        }, 500);
    }
}
`;
}

// 修复方案 2: 检查 R2 绑定状态
async function checkR2Binding() {
    console.log('🔍 检查 R2 绑定状态...');
    
    try {
        const response = await fetch('/r2?list');
        const data = await response.json();
        
        if (response.ok) {
            console.log('✅ R2 绑定正常');
            return { success: true, data };
        } else {
            console.log('❌ R2 绑定异常:', data);
            return { success: false, error: data };
        }
    } catch (error) {
        console.log('❌ R2 检查失败:', error.message);
        return { success: false, error: error.message };
    }
}

// 修复方案 3: 替代的文件检查方法
async function checkFileExistsAlternative(fileName) {
    console.log(\`🔍 使用替代方法检查文件: \${fileName}\`);
    
    try {
        // 直接尝试 HEAD 请求
        const url = \`/r2?file=\${encodeURIComponent(fileName)}\`;
        const response = await fetch(url, { method: 'HEAD' });
        
        if (response.ok) {
            console.log('✅ 文件存在 (通过 HEAD 请求确认)');
            return {
                exists: true,
                size: response.headers.get('Content-Length'),
                etag: response.headers.get('ETag'),
                contentType: response.headers.get('Content-Type')
            };
        } else {
            console.log(\`❌ 文件不存在: \${response.status} \${response.statusText}\`);
            return { exists: false, status: response.status };
        }
    } catch (error) {
        console.log(\`❌ 检查失败: \${error.message}\`);
        return { exists: false, error: error.message };
    }
}

// 修复方案 4: 诊断 R2 权限问题
async function diagnoseR2Permissions() {
    console.log('🔐 诊断 R2 权限问题...');
    
    const tests = [
        {
            name: '基础连接测试',
            test: async () => {
                const response = await fetch('/');
                return { success: response.ok, status: response.status };
            }
        },
        {
            name: 'R2 列表权限测试',
            test: async () => {
                const response = await fetch('/r2?list');
                const data = await response.text();
                return { 
                    success: response.ok, 
                    status: response.status, 
                    data: data.substring(0, 200) 
                };
            }
        },
        {
            name: 'R2 文件访问权限测试',
            test: async () => {
                const response = await fetch('/r2?file=test');
                return { 
                    success: response.status !== 500, // 500 表示绑定问题
                    status: response.status 
                };
            }
        }
    ];
    
    const results = {};
    for (const test of tests) {
        try {
            console.log(\`执行: \${test.name}\`);
            results[test.name] = await test.test();
            console.log(\`\${test.name}: \`, results[test.name]);
        } catch (error) {
            results[test.name] = { success: false, error: error.message };
            console.log(\`\${test.name} 失败: \${error.message}\`);
        }
    }
    
    return results;
}

// 导出修复工具
if (typeof window !== 'undefined') {
    window.R2ListFix = {
        getImprovedR2ListHandler,
        checkR2Binding,
        checkFileExistsAlternative,
        diagnoseR2Permissions
    };
    
    console.log('✅ R2 列表修复工具已加载');
}

// 自动诊断（如果在浏览器环境中）
if (typeof window !== 'undefined') {
    window.addEventListener('load', () => {
        setTimeout(async () => {
            console.log('🚀 自动运行 R2 诊断...');
            await diagnoseR2Permissions();
            await checkR2Binding();
        }, 2000);
    });
}