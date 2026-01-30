# 数据库迁移记录

## 2025-11-04: 添加排行榜功能字段

### 问题
排行榜功能报错 HTTP 500，原因是数据库 `users` 表缺少必要的字段：
- `total_transferred_bytes` - 总传输字节数
- `last_transfer_at` - 最后传输时间

### 解决方案

#### 1. 添加字段到生产数据库

```bash
cd web

# 添加总传输字节数字段
npx wrangler d1 execute fabushi-db --remote --command "ALTER TABLE users ADD COLUMN total_transferred_bytes INTEGER DEFAULT 0;"

# 添加最后传输时间字段
npx wrangler d1 execute fabushi-db --remote --command "ALTER TABLE users ADD COLUMN last_transfer_at TEXT;"
```

#### 2. 验证字段已添加

```bash
npx wrangler d1 execute fabushi-db --remote --command "PRAGMA table_info(users);"
```

#### 3. 测试排行榜 API

```bash
curl https://flutter.ombhrum.com/api/leaderboard
```

预期响应：
```json
{
  "leaderboard": []
}
```

### 当前状态

✅ 字段已成功添加到生产数据库
✅ 排行榜 API 正常工作
✅ 所有现有用户的 `total_transferred_bytes` 默认为 0

### 后续步骤

1. **更新 schema.sql**：确保新部署时包含这些字段
2. **测试传输功能**：确认传输数据能正确更新到数据库
3. **监控排行榜**：观察用户传输数据后排行榜是否正常显示

### 相关文件

- `web/schema.sql` - 数据库表结构定义
- `web/migration-add-leaderboard-fields.sql` - 本次迁移脚本
- `web/src/services/database.js` - 数据库服务（包含排行榜查询）
- `web/src/handlers/leaderboard.js` - 排行榜 API 处理器
- `lib/services/leaderboard_service.dart` - 前端排行榜服务

### 注意事项

- 所有现有用户的传输数据从 0 开始计算
- 如需恢复历史数据，需要从其他数据源导入
- 新用户注册时会自动包含这些字段（默认值 0 和 NULL）

## 迁移命令参考

### 查看表结构
```bash
npx wrangler d1 execute fabushi-db --remote --command "PRAGMA table_info(users);"
```

### 查询用户数据
```bash
npx wrangler d1 execute fabushi-db --remote --command "SELECT username, total_transferred_bytes, last_transfer_at FROM users LIMIT 10;"
```

### 查询排行榜
```bash
npx wrangler d1 execute fabushi-db --remote --command "SELECT username, total_transferred_bytes FROM users WHERE total_transferred_bytes > 0 ORDER BY total_transferred_bytes DESC LIMIT 10;"
```

### 手动更新测试数据（仅用于测试）
```bash
npx wrangler d1 execute fabushi-db --remote --command "UPDATE users SET total_transferred_bytes = 1048576, last_transfer_at = datetime('now') WHERE username = 'testuser';"
```
