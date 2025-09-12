// R2文件诊断脚本
// 用于检查r2-assets.js中配置的文件是否在R2存储桶中存在

async function diagnoseR2Files() {
    console.log('🔍 开始诊断R2文件配置...');
    
    // 加载r2-assets.js配置
    let r2Assets;
    try {
        // 在浏览器环境中，r2-assets.js应该已经加载
        if (typeof window !== 'undefined' && window.r2DharmaAssets) {
            r2Assets = window.r2DharmaAssets;
        } else {
            console.error('❌ 无法加载r2-assets.js配置');
            return;
        }
    } catch (error) {
        console.error('❌ 加载r2-assets.js失败:', error);
        return;
    }
    
    console.log('✅ 成功加载r2-assets.js配置');
    
    // 收集所有R2文件
    const r2Files = [];
    for (const category in r2Assets) {
        if (r2Assets[category]._files) {
            r2Assets[category]._files.forEach(file => {
                if (typeof file === 'object' && file.path) {
                    r2Files.push({
                        category,
                        name: file.name,
                        path: file.path
                    });
                }
            });
        }
    }
    
    console.log(`📊 找到 ${r2Files.length} 个R2文件配置`);
    
    // 测试每个文件
    const results = {
        success: [],
        notFound: [],
        error: []
    };
    
    for (const file of r2Files) {
        console.log(`🔍 测试文件: ${file.name}`);
        
        try {
            const encodedPath = encodeURIComponent(file.path);
            const response = await fetch(`/r2?file=${encodedPath}`, { 
                method: 'HEAD',
                // 添加超时
                signal: AbortSignal.timeout(10000)
            });
            
            if (response.ok) {
                const contentLength = response.headers.get('Content-Length');
                const sizeMB = contentLength ? (parseInt(contentLength) / 1024 / 1024).toFixed(2) : '未知';
                
                results.success.push({
                    ...file,
                    size: sizeMB + ' MB',
                    status: response.status
                });
                
                console.log(`✅ ${file.name} - ${sizeMB} MB`);
            } else if (response.status === 404) {
                results.notFound.push({
                    ...file,
                    status: response.status,
                    error: '文件不存在'
                });
                
                console.log(`❌ ${file.name} - 404 Not Found`);
            } else {
                results.error.push({
                    ...file,
                    status: response.status,
                    error: response.statusText
                });
                
                console.log(`⚠️ ${file.name} - ${response.status} ${response.statusText}`);
            }
        } catch (error) {
            results.error.push({
                ...file,
                error: error.message
            });
            
            console.log(`💥 ${file.name} - 请求失败: ${error.message}`);
        }
        
        // 添加小延迟避免过于频繁的请求
        await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    // 输出汇总报告
    console.log('\n📋 诊断报告汇总:');
    console.log(`✅ 可用文件: ${results.success.length}`);
    console.log(`❌ 不存在文件: ${results.notFound.length}`);
    console.log(`💥 错误文件: ${results.error.length}`);
    
    if (results.notFound.length > 0) {
        console.log('\n❌ 以下文件在R2存储桶中不存在:');
        results.notFound.forEach(file => {
            console.log(`  - ${file.name} (路径: ${file.path})`);
        });
    }
    
    if (results.error.length > 0) {
        console.log('\n💥 以下文件测试时出现错误:');
        results.error.forEach(file => {
            console.log(`  - ${file.name}: ${file.error}`);
        });
    }
    
    if (results.success.length > 0) {
        console.log('\n✅ 以下文件可正常访问:');
        results.success.forEach(file => {
            console.log(`  - ${file.name} (${file.size})`);
        });
    }
    
    return results;
}

// 如果在浏览器环境中，添加到全局作用域
if (typeof window !== 'undefined') {
    window.diagnoseR2Files = diagnoseR2Files;
    
    // 自动运行诊断（延迟执行确保页面加载完成）
    setTimeout(() => {
        console.log('🚀 自动运行R2文件诊断...');
        diagnoseR2Files().then(results => {
            console.log('🏁 诊断完成');
            
            // 将结果存储到全局变量供进一步分析
            window.r2DiagnosisResults = results;
        }).catch(error => {
            console.error('💥 诊断过程中出现错误:', error);
        });
    }, 2000);
}

// Node.js环境支持
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { diagnoseR2Files };
}