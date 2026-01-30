#!/bin/bash

# 项目重构脚本
# 用途：自动化执行项目结构重组

set -e

echo "🚀 开始项目重构..."

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# 1. 创建备份
echo -e "${YELLOW}📦 创建项目备份...${NC}"
BACKUP_DIR="../全球法布施_backup_$(date +%Y%m%d_%H%M%S)"
cp -r . "$BACKUP_DIR"
echo -e "${GREEN}✅ 备份完成: $BACKUP_DIR${NC}"

# 2. 创建新目录结构
echo -e "${YELLOW}📁 创建新目录结构...${NC}"

# 创建docs目录
mkdir -p docs/{api,architecture,deployment,features,guides}

# 创建scripts目录
mkdir -p scripts/{build,deploy,setup,utils}

# 创建lib新结构
mkdir -p lib/core/{constants,config,di,errors,network,utils/{extensions,helpers,validators}}
mkdir -p lib/features/{auth,membership,transfer,dharma,profile}/{data/{models,datasources,repositories},domain/{entities,repositories,usecases},presentation/{bloc,pages,widgets}}
mkdir -p lib/shared/{widgets/{buttons,cards,dialogs,loading},models}
mkdir -p lib/routes

# 创建test目录
mkdir -p test/{unit,widget,integration}

echo -e "${GREEN}✅ 目录结构创建完成${NC}"

# 3. 移动文档文件
echo -e "${YELLOW}📄 整理文档文件...${NC}"

# API相关文档
mv API_CONFIG_README.md docs/api/ 2>/dev/null || true
mv BACKEND_INTEGRATION_GUIDE.md docs/api/ 2>/dev/null || true
mv BACKEND_SWITCHING_GUIDE.md docs/api/ 2>/dev/null || true

# 架构相关文档
mv NEW_UI_ARCHITECTURE.md docs/architecture/ 2>/dev/null || true
mv UNIFIED_CONFIG_COMPLETE.md docs/architecture/ 2>/dev/null || true
mv MODULAR_STRUCTURE.md docs/architecture/ 2>/dev/null || true

# 部署相关文档
mv DEPLOYMENT.md docs/deployment/ 2>/dev/null || true
mv CLOUDFLARE_WORKER_SETUP.md docs/deployment/ 2>/dev/null || true
mv FLUTTER_WEB_DEPLOYMENT_GUIDE.md docs/deployment/ 2>/dev/null || true
mv D1_DEPLOYMENT_GUIDE.md docs/deployment/ 2>/dev/null || true

# 功能相关文档
mv EARTH_GLOBE_*.md docs/features/ 2>/dev/null || true
mv VIDEO_FEED_*.md docs/features/ 2>/dev/null || true
mv TEXT_FEED_*.md docs/features/ 2>/dev/null || true
mv TRAJECTORY_GUIDE.md docs/features/ 2>/dev/null || true
mv DRIFT_SEARCH_GUIDE.md docs/features/ 2>/dev/null || true

# 指南文档
mv QUICK_START.md docs/guides/ 2>/dev/null || true
mv TESTING_GUIDE.md docs/guides/ 2>/dev/null || true
mv FIREBASE_*.md docs/guides/ 2>/dev/null || true
mv ALIPAY_*.md docs/guides/ 2>/dev/null || true

# 其他文档移到docs根目录
mv *_FIX*.md docs/ 2>/dev/null || true
mv *_SUMMARY.md docs/ 2>/dev/null || true
mv *_MIGRATION*.md docs/ 2>/dev/null || true
mv 问题修复总结.md docs/ 2>/dev/null || true
mv 支付宝*.md docs/ 2>/dev/null || true

echo -e "${GREEN}✅ 文档整理完成${NC}"

# 4. 移动脚本文件
echo -e "${YELLOW}🔧 整理脚本文件...${NC}"

# 构建脚本
mv build*.sh scripts/build/ 2>/dev/null || true
mv cloudflare_build.sh scripts/build/ 2>/dev/null || true
mv verify-build.sh scripts/build/ 2>/dev/null || true

# 部署脚本
mv deploy*.sh scripts/deploy/ 2>/dev/null || true
mv clear-*.sh scripts/deploy/ 2>/dev/null || true
mv force-*.sh scripts/deploy/ 2>/dev/null || true

# 设置脚本
mv setup*.sh scripts/setup/ 2>/dev/null || true
mv add_firebase*.sh scripts/setup/ 2>/dev/null || true
mv create_*.sh scripts/setup/ 2>/dev/null || true
mv update_*.sh scripts/setup/ 2>/dev/null || true

# 工具脚本
mv fix*.sh scripts/utils/ 2>/dev/null || true
mv test*.sh scripts/utils/ 2>/dev/null || true
mv run*.sh scripts/utils/ 2>/dev/null || true
mv sync*.sh scripts/utils/ 2>/dev/null || true
mv optimize*.sh scripts/utils/ 2>/dev/null || true
mv generate*.js scripts/utils/ 2>/dev/null || true
mv migrate*.js scripts/utils/ 2>/dev/null || true
mv migrate*.sh scripts/utils/ 2>/dev/null || true

echo -e "${GREEN}✅ 脚本整理完成${NC}"

# 5. 清理临时文件
echo -e "${YELLOW}🧹 清理临时文件...${NC}"

# 移除lib中的测试文件
rm -f lib/main_simple_test.dart
rm -f lib/main_simple.dart
rm -f lib/test_*.dart

# 移除examples目录（如果不需要）
# rm -rf lib/examples

echo -e "${GREEN}✅ 清理完成${NC}"

# 6. 创建README文件
echo -e "${YELLOW}📝 创建说明文件...${NC}"

cat > docs/README.md << 'EOF'
# 项目文档

## 目录结构

- **api/** - API接口文档
- **architecture/** - 架构设计文档
- **deployment/** - 部署相关文档
- **features/** - 功能模块文档
- **guides/** - 使用指南

## 文档索引

### 快速开始
- [快速开始指南](guides/QUICK_START.md)
- [测试指南](guides/TESTING_GUIDE.md)

### API文档
- [API配置说明](api/API_CONFIG_README.md)
- [后端集成指南](api/BACKEND_INTEGRATION_GUIDE.md)

### 架构文档
- [UI架构说明](architecture/NEW_UI_ARCHITECTURE.md)
- [统一配置说明](architecture/UNIFIED_CONFIG_COMPLETE.md)

### 部署文档
- [部署指南](deployment/DEPLOYMENT.md)
- [Cloudflare Worker设置](deployment/CLOUDFLARE_WORKER_SETUP.md)

### 功能文档
- [地球仪功能](features/)
- [视频流功能](features/)
- [文本流功能](features/)
EOF

cat > scripts/README.md << 'EOF'
# 项目脚本

## 目录结构

- **build/** - 构建相关脚本
- **deploy/** - 部署相关脚本
- **setup/** - 初始化设置脚本
- **utils/** - 工具脚本

## 常用脚本

### 构建
```bash
./scripts/build/build_web_release.sh    # 构建Web版本
./scripts/build/cloudflare_build.sh     # Cloudflare构建
```

### 部署
```bash
./scripts/deploy/deploy-complete.sh     # 完整部署
./scripts/deploy/deploy-backend-only.sh # 仅部署后端
```

### 开发
```bash
./scripts/utils/run_app.sh              # 运行应用
./scripts/utils/run_web.sh              # 运行Web版本
```

### 测试
```bash
./scripts/utils/test_earth_globe.sh     # 测试地球仪
./scripts/utils/test-leaderboard.sh     # 测试排行榜
```
EOF

echo -e "${GREEN}✅ 说明文件创建完成${NC}"

# 7. 更新.gitignore
echo -e "${YELLOW}📝 更新.gitignore...${NC}"

cat >> .gitignore << 'EOF'

# 备份文件
*_backup_*/

# 临时文件
*.tmp
*.temp
EOF

echo -e "${GREEN}✅ .gitignore更新完成${NC}"

# 8. 生成重构报告
echo -e "${YELLOW}📊 生成重构报告...${NC}"

cat > REFACTOR_REPORT.md << EOF
# 项目重构报告

**执行时间**: $(date '+%Y-%m-%d %H:%M:%S')

## 执行的操作

1. ✅ 创建项目备份
2. ✅ 创建新目录结构
3. ✅ 整理文档文件
4. ✅ 整理脚本文件
5. ✅ 清理临时文件
6. ✅ 创建说明文件
7. ✅ 更新.gitignore

## 新目录结构

\`\`\`
全球法布施/
├── docs/           # 所有文档
├── scripts/        # 所有脚本
├── lib/            # 源代码（待进一步重构）
├── test/           # 测试文件
└── assets/         # 资源文件
\`\`\`

## 下一步

1. 查看 PROJECT_REFACTOR_PLAN.md 了解完整重构计划
2. 执行代码层面的重构
3. 更新依赖配置
4. 完善测试覆盖

## 备份位置

$BACKUP_DIR

## 注意事项

- 原始项目已备份
- 如需回滚，请使用备份目录
- 建议在新分支上继续开发
EOF

echo -e "${GREEN}✅ 重构报告生成完成${NC}"

echo ""
echo -e "${GREEN}🎉 项目重构第一阶段完成！${NC}"
echo ""
echo "📋 下一步操作："
echo "1. 查看 REFACTOR_REPORT.md 了解重构详情"
echo "2. 查看 PROJECT_REFACTOR_PLAN.md 了解完整计划"
echo "3. 执行 'flutter pub get' 确保依赖正常"
echo "4. 执行 'flutter run' 测试应用是否正常运行"
echo ""
echo "💾 备份位置: $BACKUP_DIR"
echo ""
