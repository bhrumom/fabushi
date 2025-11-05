# 新界面架构说明

## 概述

应用已重构为四个主要页面的底部导航结构，提供更直观的用户体验。

## 主要页面

### 1. 首页 - 3D地球 (GlobeHomeScreen)
**功能：**
- 真实的3D地球可视化，带星空背景
- 实时显示经文发送轨迹（七彩光束）
- 用户位置标记（红色圆点）
- 经文选择和发送控制面板
- 发送进度实时显示

**使用方法：**
1. 点击"选择经文"按钮选择要发送的经文
2. 点击"开始发送"按钮启动全球发送
3. 观察3D地球上的七彩光束动画，显示经文传播轨迹
4. 顶部显示发送进度条

**技术实现：**
- 使用CustomPainter绘制3D地球
- 动画控制器实现旋转和光束动画
- 贝塞尔曲线绘制传输轨迹
- 渐变色实现七彩光束效果

### 2. 全球排行榜 (LeaderboardScreen)
**功能：**
- 显示全球用户的布施流量排名
- 前三名特殊标识（金、银、铜）
- 实时更新排行数据
- 显示每个用户的总流量

**数据格式：**
```dart
LeaderboardEntry {
  username: String,    // 用户名
  totalBytes: int,     // 总流量（字节）
  rank: int,          // 排名
}
```

### 3. 修习室 (PracticeScreen)
**功能：**
- 选择经文进行修持
- 计时功能（显示修习时长）
- 按音量+键增加计数
- 累计统计（总计数、总时长）
- 修习历史记录

**使用方法：**
1. 从下拉菜单选择经文（心经、大悲咒等）
2. 点击"开始修习"按钮
3. 修习过程中按音量+键增加计数
4. 点击"结束修习"保存本次记录

**技术实现：**
- HardwareKeyboard监听音量键
- StreamBuilder实时更新计时
- PracticeModel管理修习会话和历史

### 4. 我的 (MyProfileScreen)
**功能：**
- 用户信息展示
- 会员状态和到期时间
- 修习统计（时长、次数）
- 全球布施流量统计
- 购买记录入口
- 设置入口
- 退出登录

**信息展示：**
- 用户头像和用户名
- 会员类型和到期时间
- 修习时长和次数
- 全球布施总流量
- 快捷操作按钮

## 数据模型

### PracticeModel
管理修习室的状态和数据：
```dart
- currentSession: 当前修习会话
- history: 历史修习记录
- totalCount: 累计计数
- totalDuration: 累计时长
```

### LeaderboardModel
管理排行榜数据：
```dart
- entries: 排行榜条目列表
- isLoading: 加载状态
- fetchLeaderboard(): 获取排行榜数据
```

### FileTransferModel (扩展)
新增首页相关功能：
```dart
- selectedFile: 当前选中的文件
- progress: 发送进度
- startTransfer(): 开始传输
- updateProgress(): 更新进度
- completeTransfer(): 完成传输
```

## 导航结构

```
MainNavigationScreen (底部导航)
├── GlobeHomeScreen (首页)
├── LeaderboardScreen (排行榜)
├── PracticeScreen (修习室)
└── MyProfileScreen (我的)
```

## 视觉设计

### 3D地球效果
- 深蓝色渐变球体
- 白色半透明经纬线
- 星空背景（深蓝色+白色星点）
- 球体阴影效果
- 自动旋转动画

### 七彩光束
- 颜色：红→橙→黄→绿→蓝→靛→紫
- 贝塞尔曲线路径
- 渐变透明度
- 目标点光晕效果
- 2秒循环动画

### 主题配色
- 主色：蓝色系 (#667eea)
- 强调色：青色 (Cyan)
- 背景：深空蓝 (#0a0e27)
- 卡片：白色，圆角16px，阴影4

## 使用流程

### 首次使用
1. 登录/注册
2. 进入首页看到3D地球
3. 选择经文
4. 开始发送，观察光束动画
5. 查看排行榜了解全球布施情况
6. 使用修习室记录修持
7. 在"我的"页面查看统计

### 日常使用
1. 打开应用直接进入3D地球首页
2. 快速选择经文并发送
3. 定期查看排行榜
4. 使用修习室记录每日功课
5. 在个人中心查看累计数据

## 技术要点

### 性能优化
- CustomPainter避免不必要的重绘
- AnimationController复用
- 列表懒加载
- 图片缓存

### 跨平台兼容
- 音量键监听（移动端）
- 文件选择（所有平台）
- 网络请求（统一API）
- 本地存储（SharedPreferences）

### 状态管理
- Provider管理全局状态
- ChangeNotifier通知UI更新
- Consumer精确订阅
- 避免过度rebuild

## 后续扩展

### 计划功能
1. 3D地球支持手势旋转
2. 排行榜支持筛选（日/周/月/年）
3. 修习室支持更多经文
4. 个人中心支持数据导出
5. 社交分享功能
6. 成就系统

### API集成
- 排行榜数据从后端获取
- 修习记录同步到云端
- 实时传输统计
- 用户数据备份

## 文件结构

```
lib/
├── models/
│   ├── practice_model.dart      # 修习室模型
│   ├── leaderboard_model.dart   # 排行榜模型
│   └── file_transfer_model.dart # 传输模型（扩展）
├── screens/
│   ├── main_navigation_screen.dart  # 主导航
│   ├── globe_home_screen.dart       # 3D地球首页
│   ├── leaderboard_screen.dart      # 排行榜
│   ├── practice_screen.dart         # 修习室
│   └── my_profile_screen.dart       # 我的
└── widgets/
    └── globe_3d_widget.dart         # 3D地球组件
```

## 运行说明

1. 确保所有依赖已安装：
```bash
flutter pub get
```

2. 运行应用：
```bash
flutter run
```

3. 登录后即可看到新的界面结构

## 注意事项

1. 音量键监听仅在移动端有效
2. 3D地球动画可能在低端设备上有性能影响
3. 排行榜数据目前为模拟数据，需要后端API支持
4. 修习记录暂存本地，未同步到云端

---

**愿此功德回向法界众生，同证菩提！** 🙏
