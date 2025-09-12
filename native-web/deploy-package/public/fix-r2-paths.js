// R2 路径修复脚本
// 用于自动检测和修复 r2-assets.js 中的文件路径问题

class R2PathFixer {
    constructor() {
        this.r2Files = [];
        this.configuredFiles = [];
        this.fixes = [];
    }

    // 获取 R2 存储桶中的实际文件列表
    async fetchR2Files() {
        try {
            console.log('🔍 获取 R2 存储桶文件列表...');
            const response = await fetch('/r2?list=true');
            const data = await response.json();
            
            if (response.ok) {
                this.r2Files = data.files.map(f => f.key);
                console.log(`✅ 找到 ${this.r2Files.length} 个 R2 文件`);
                return this.r2Files;
            } else {
                throw new Error(data.error || '获取文件列表失败');
            }
        } catch (error) {
            console.error('❌ 获取 R2 文件列表失败:', error);
            throw error;
        }
    }

    // 加载配置文件中的路径
    loadConfiguredPaths() {
        console.log('📋 加载配置文件路径...');
        
        if (!window.r2DharmaAssets) {
            throw new Error('未找到 r2DharmaAssets 配置');
        }

        this.configuredFiles = [];
        for (const category in window.r2DharmaAssets) {
            if (window.r2DharmaAssets[category]._files) {
                window.r2DharmaAssets[category]._files.forEach(file => {
                    if (typeof file === 'object' && file.path) {
                        this.configuredFiles.push({
                            category,
                            name: file.name,
                            path: file.path
                        });
                    }
                });
            }
        }

        console.log(`✅ 加载了 ${this.configuredFiles.length} 个配置文件`);
        return this.configuredFiles;
    }

    // 使用模糊匹配找到最相似的文件
    findBestMatch(configPath, r2Files) {
        let bestMatch = null;
        let bestScore = 0;

        for (const r2File of r2Files) {
            const score = this.calculateSimilarity(configPath, r2File);
            if (score > bestScore && score > 0.5) { // 相似度阈值
                bestScore = score;
                bestMatch = r2File;
            }
        }

        return { match: bestMatch, score: bestScore };
    }

    // 计算两个字符串的相似度
    calculateSimilarity(str1, str2) {
        const longer = str1.length > str2.length ? str1 : str2;
        const shorter = str1.length > str2.length ? str2 : str1;
        
        if (longer.length === 0) return 1.0;
        
        const editDistance = this.levenshteinDistance(longer, shorter);
        return (longer.length - editDistance) / longer.length;
    }

    // 计算编辑距离
    levenshteinDistance(str1, str2) {
        const matrix = [];
        
        for (let i = 0; i <= str2.length; i++) {
            matrix[i] = [i];
        }
        
        for (let j = 0; j <= str1.length; j++) {
            matrix[0][j] = j;
        }
        
        for (let i = 1; i <= str2.length; i++) {
            for (let j = 1; j <= str1.length; j++) {
                if (str2.charAt(i - 1) === str1.charAt(j - 1)) {
                    matrix[i][j] = matrix[i - 1][j - 1];
                } else {
                    matrix[i][j] = Math.min(
                        matrix[i - 1][j - 1] + 1,
                        matrix[i][j - 1] + 1,
                        matrix[i - 1][j] + 1
                    );
                }
            }
        }
        
        return matrix[str2.length][str1.length];
    }

    // 分析并生成修复建议
    async analyzeAndFix() {
        console.log('🔧 开始分析和修复...');
        
        await this.fetchR2Files();
        this.loadConfiguredPaths();
        
        this.fixes = [];
        const configPaths = this.configuredFiles.map(f => f.path);
        
        // 检查每个配置文件是否存在于 R2 中
        for (const configFile of this.configuredFiles) {
            if (!this.r2Files.includes(configFile.path)) {
                // 文件不存在，尝试找到最佳匹配
                const bestMatch = this.findBestMatch(configFile.path, this.r2Files);
                
                this.fixes.push({
                    type: 'missing',
                    configFile,
                    suggestion: bestMatch.match,
                    confidence: bestMatch.score,
                    issue: '配置的路径在 R2 中不存在'
                });
            }
        }

        // 检查 R2 中未配置的文件
        for (const r2File of this.r2Files) {
            if (!configPaths.includes(r2File)) {
                this.fixes.push({
                    type: 'unconfigured',
                    r2File,
                    issue: 'R2 中的文件未在配置中'
                });
            }
        }

        console.log(`🔍 发现 ${this.fixes.length} 个需要修复的问题`);
        return this.fixes;
    }

    // 生成修复报告
    generateReport() {
        console.log('\n📊 修复报告:');
        console.log('='.repeat(50));
        
        const missingFiles = this.fixes.filter(f => f.type === 'missing');
        const unconfiguredFiles = this.fixes.filter(f => f.type === 'unconfigured');
        
        if (missingFiles.length > 0) {
            console.log('\n❌ 配置中但 R2 中不存在的文件:');
            missingFiles.forEach((fix, index) => {
                console.log(`\n${index + 1}. ${fix.configFile.name}`);
                console.log(`   配置路径: ${fix.configFile.path}`);
                if (fix.suggestion) {
                    console.log(`   建议修复: ${fix.suggestion} (相似度: ${(fix.confidence * 100).toFixed(1)}%)`);
                } else {
                    console.log(`   建议: 检查文件是否已上传到 R2 或路径是否正确`);
                }
            });
        }
        
        if (unconfiguredFiles.length > 0) {
            console.log('\n⚠️ R2 中存在但未配置的文件:');
            unconfiguredFiles.forEach((fix, index) => {
                console.log(`${index + 1}. ${fix.r2File}`);
            });
        }
        
        return {
            missing: missingFiles,
            unconfigured: unconfiguredFiles,
            total: this.fixes.length
        };
    }

    // 生成修复后的配置文件
    generateFixedConfig() {
        const report = this.generateReport();
        
        console.log('\n🔧 生成修复配置...');
        
        // 创建修复后的配置
        const fixedConfig = {
            "高能素材": {
                "_files": []
            }
        };

        // 添加可以修复的文件
        for (const fix of this.fixes) {
            if (fix.type === 'missing' && fix.suggestion && fix.confidence > 0.7) {
                fixedConfig["高能素材"]._files.push({
                    name: fix.configFile.name,
                    path: fix.suggestion
                });
                console.log(`✅ 修复: ${fix.configFile.name} -> ${fix.suggestion}`);
            }
        }

        // 添加未配置的文件
        for (const fix of this.fixes) {
            if (fix.type === 'unconfigured') {
                // 生成友好的显示名称
                let displayName = fix.r2File;
                if (displayName.includes('.')) {
                    displayName = displayName.substring(0, displayName.lastIndexOf('.'));
                }
                if (displayName.length > 30) {
                    displayName = displayName.substring(0, 30) + '...';
                }

                fixedConfig["高能素材"]._files.push({
                    name: displayName,
                    path: fix.r2File
                });
                console.log(`➕ 添加: ${displayName} -> ${fix.r2File}`);
            }
        }

        return fixedConfig;
    }

    // 应用修复（生成新的配置代码）
    applyFixes() {
        const fixedConfig = this.generateFixedConfig();
        
        const configCode = `// 修复后的 r2-assets.js
// 自动生成于 ${new Date().toLocaleString()}

window.r2DharmaAssets = ${JSON.stringify(fixedConfig, null, 4)};`;

        console.log('\n📝 修复后的配置代码:');
        console.log('='.repeat(50));
        console.log(configCode);
        
        return configCode;
    }
}

// 全局函数
async function fixR2Paths() {
    const fixer = new R2PathFixer();
    
    try {
        await fixer.analyzeAndFix();
        const fixedCode = fixer.applyFixes();
        
        // 将结果存储到全局变量
        window.r2PathFixerResults = {
            fixes: fixer.fixes,
            fixedCode: fixedCode
        };
        
        console.log('\n🎉 修复完成！修复结果已存储到 window.r2PathFixerResults');
        console.log('💡 提示: 复制上面的配置代码替换 r2-assets.js 文件内容');
        
        return window.r2PathFixerResults;
    } catch (error) {
        console.error('💥 修复过程中出现错误:', error);
        throw error;
    }
}

// 导出到全局作用域
if (typeof window !== 'undefined') {
    window.R2PathFixer = R2PathFixer;
    window.fixR2Paths = fixR2Paths;
}

// Node.js 支持
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { R2PathFixer, fixR2Paths };
}