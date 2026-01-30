# 点赞功能部署指南

## 说明

项目已有D1数据库 `fabushi-db`，只需要在现有数据库中添加 `content_likes` 表即可。

## 快速部署

### 方式1：使用脚本（推荐）
```bash
cd web
./migrate-add-likes.sh
```

### 方式2：直接执行SQL
```bash
cd web
wrangler d1 execute fabushi-db --file=./schema-likes.sql
```

### 方式3：手动执行
```bash
cd web
wrangler d1 execute fabushi-db --command="
CREATE TABLE IF NOT EXISTS content_likes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  content_id TEXT NOT NULL,
  content_type TEXT NOT NULL,
  user_id TEXT,
  created_at TEXT NOT NULL,
  UNIQUE(content_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_content_likes_content_id ON content_likes(content_id);
CREATE INDEX IF NOT EXISTS idx_content_likes_user_id ON content_likes(user_id);
"
```

## 验证

检查表是否创建成功：
```bash
wrangler d1 execute fabushi-db --command="SELECT name FROM sqlite_master WHERE type='table' AND name='content_likes';"
```

应该看到输出：
```
name
content_likes
```

## 部署后端

```bash
cd web
wrangler deploy
```

## 运行应用

```bash
flutter run
```

## 注意事项

1. **只需执行一次**：表创建后不需要重复执行
2. **使用现有数据库**：不需要创建新数据库
3. **IF NOT EXISTS**：SQL使用了安全检查，重复执行不会报错
4. **索引优化**：自动创建索引提升查询性能

## 完成！

部署完成后，用户就可以：
- ✅ 在法流页面点赞内容
- ✅ 查看我的喜欢列表
- ✅ 点击查看内容详情
- ✅ 看到真实的点赞数量

---

**简单三步，功能上线！** 🚀
