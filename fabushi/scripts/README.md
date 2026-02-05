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
