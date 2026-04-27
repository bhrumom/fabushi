# Video Feed 更新指南

## 三种更新方式

### 方式 1: 一键同步脚本（推荐）

```bash
./sync_video_feed.sh
```

执行后会自动：
1. 从 GitHub 拉取最新代码
2. 复制到项目目录
3. 提示后续步骤

然后手动执行：
```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### 方式 2: GitHub Actions 自动同步

在 GitHub 仓库中：
1. 进入 Actions 标签
2. 选择 "Sync Video Feed" 工作流
3. 点击 "Run workflow"

系统会自动创建 PR，包含最新更新。

### 方式 3: 手动更新

```bash
# 1. 更新源代码
cd temp_video_feed
git pull origin main
cd ..

# 2. 复制更新
cp -r temp_video_feed/lib/features/video_feed/* lib/features/video_feed/

# 3. 安装依赖
flutter pub get

# 4. 生成代码
flutter pub run build_runner build --delete-conflicting-outputs

# 5. 测试
flutter run
```

## 更新检查清单

- [ ] 代码已同步
- [ ] 依赖已安装
- [ ] 代码已生成
- [ ] 应用可正常运行
- [ ] 视频播放正常
- [ ] 无编译错误

## 版本追踪

当前集成版本：基于 https://github.com/Deatsilence/flutter-video-feed

最后同步时间：2024-01-15

## 注意事项

1. 更新前建议先提交当前代码
2. 更新后测试所有视频功能
3. 检查是否有破坏性更改
4. 必要时更新依赖版本

## 回滚

如果更新出现问题：

```bash
git checkout lib/features/video_feed
git checkout lib/core/video_feed_di
flutter pub get
```
