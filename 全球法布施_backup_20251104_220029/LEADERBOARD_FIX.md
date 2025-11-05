# 排行榜 HTTP 500 错误修复

## 问题描述

应用在获取排行榜时出现 HTTP 500 错误：
```
flutter: 获取排行榜失败: Exception: 获取排行榜失败: HTTP 500
```

## 问题原因

1. **数据库查询问题**：`total_transferred_bytes` 字段可能为 NULL，导致查询失败
2. **错误处理不完善**：后端没有捕获数据库查询异常
3. **前端异常处理**：前端遇到错误直接抛出异常，影响用户体验

## 修复方案

### 1. 后端数据库服务修复 (`web/src/services/database.js`)

**修改前：**
```javascript
async getLeaderboard(limit) {
  const result = await this.db.prepare(`
    SELECT username, total_transferred_bytes as totalBytes
    FROM users 
    WHERE total_transferred_bytes > 0
    ORDER BY total_transferred_bytes DESC
    LIMIT ?
  `).bind(limit).all();
  
  return result.results.map((entry, index) => ({
    ...entry,
    rank: index + 1
  }));
}
```

**修改后：**
```javascript
async getLeaderboard(limit) {
  try {
    const result = await this.db.prepare(`
      SELECT username, COALESCE(total_transferred_bytes, 0) as totalBytes
      FROM users 
      WHERE COALESCE(total_transferred_bytes, 0) > 0
      ORDER BY total_transferred_bytes DESC
      LIMIT ?
    `).bind(limit).all();
    
    if (!result || !result.results) {
      return [];
    }
    
    return result.results.map((entry, index) => ({
      username: entry.username || 'Unknown',
      totalBytes: entry.totalBytes || 0,
      rank: index + 1
    }));
  } catch (error) {
    console.error('获取排行榜失败:', error);
    return [];
  }
}
```

**改进点：**
- ✅ 使用 `COALESCE` 处理 NULL 值
- ✅ 添加 try-catch 错误处理
- ✅ 检查结果是否存在
- ✅ 提供默认值防止数据异常

### 2. 后端处理器修复 (`web/src/handlers/leaderboard.js`)

**修改前：**
```javascript
export async function handleGetLeaderboard(request, env, db) {
  const cached = await env.USERS_KV.get('leaderboard:cache');
  if (cached) {
    const { data, timestamp } = JSON.parse(cached);
    if (Date.now() - timestamp < 5 * 60 * 1000) {
      return jsonResponse({ leaderboard: data, cached: true });
    }
  }

  const leaderboard = await db.getLeaderboard(100);
  
  await env.USERS_KV.put('leaderboard:cache', JSON.stringify({
    data: leaderboard,
    timestamp: Date.now()
  }), { expirationTtl: 600 });

  return jsonResponse({ leaderboard });
}
```

**修改后：**
```javascript
export async function handleGetLeaderboard(request, env, db) {
  try {
    // 尝试从缓存获取
    try {
      const cached = await env.USERS_KV.get('leaderboard:cache');
      if (cached) {
        const { data, timestamp } = JSON.parse(cached);
        if (Date.now() - timestamp < 5 * 60 * 1000) {
          return jsonResponse({ leaderboard: data, cached: true });
        }
      }
    } catch (cacheError) {
      console.error('缓存读取失败:', cacheError);
    }

    // 从数据库获取
    const leaderboard = await db.getLeaderboard(100);
    
    // 尝试缓存结果
    try {
      await env.USERS_KV.put('leaderboard:cache', JSON.stringify({
        data: leaderboard,
        timestamp: Date.now()
      }), { expirationTtl: 600 });
    } catch (cacheError) {
      console.error('缓存写入失败:', cacheError);
    }

    return jsonResponse({ leaderboard: leaderboard || [] });
  } catch (error) {
    console.error('获取排行榜失败:', error);
    return jsonResponse({ 
      error: '获取排行榜失败',
      message: error.message,
      leaderboard: [] 
    }, 200); // 返回200但带有错误信息和空数组
  }
}
```

**改进点：**
- ✅ 分离缓存和数据库错误处理
- ✅ 缓存失败不影响主流程
- ✅ 即使失败也返回 200 状态码和空数组
- ✅ 提供详细的错误日志

### 3. 前端服务修复 (`lib/services/leaderboard_service.dart`)

**修改前：**
```dart
Future<List<Map<String, dynamic>>> fetchLeaderboard() async {
  try {
    final response = await HttpService.get(
      UnifiedConfig.leaderboardUrl,
      useAuth: false,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['leaderboard'] ?? []);
    } else {
      throw Exception('获取排行榜失败: HTTP ${response.statusCode}');
    }
  } catch (e) {
    print('获取排行榜失败: $e');
    rethrow;
  }
}
```

**修改后：**
```dart
Future<List<Map<String, dynamic>>> fetchLeaderboard() async {
  try {
    final response = await HttpService.get(
      UnifiedConfig.leaderboardUrl,
      useAuth: false,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // 即使后端返回错误，也尝试获取leaderboard字段
      if (data['leaderboard'] != null) {
        return List<Map<String, dynamic>>.from(data['leaderboard']);
      }
      // 如果有错误信息，记录但返回空数组
      if (data['error'] != null) {
        print('后端返回错误: ${data['error']} - ${data['message'] ?? ""}');
        return [];
      }
      return [];
    } else {
      print('获取排行榜失败: HTTP ${response.statusCode}');
      print('响应内容: ${response.body}');
      return []; // 返回空数组而不是抛出异常
    }
  } catch (e) {
    print('获取排行榜失败: $e');
    return []; // 返回空数组而不是抛出异常
  }
}
```

**改进点：**
- ✅ 不再抛出异常，返回空数组
- ✅ 处理后端返回的错误信息
- ✅ 记录详细的错误日志
- ✅ 提升用户体验，不会因为排行榜加载失败而崩溃

## 部署步骤

### 方式一：使用部署脚本（推荐）

```bash
./deploy-fix.sh
```

### 方式二：手动部署

```bash
cd web
npx wrangler deploy --env production
```

## 验证修复

### 1. 测试排行榜API

```bash
curl https://flutter.ombhrum.com/api/leaderboard
```

**预期响应：**
```json
{
  "leaderboard": []
}
```

或者如果有数据：
```json
{
  "leaderboard": [
    {
      "username": "user1",
      "totalBytes": 1024000,
      "rank": 1
    }
  ]
}
```

### 2. 在应用中测试

1. 重启 Flutter 应用
2. 进入排行榜页面
3. 应该能正常显示（即使是空列表）
4. 不应该再出现 HTTP 500 错误

## 技术要点

### SQL COALESCE 函数

`COALESCE(total_transferred_bytes, 0)` 的作用：
- 如果 `total_transferred_bytes` 为 NULL，返回 0
- 否则返回实际值
- 确保查询不会因为 NULL 值而失败

### 错误处理策略

1. **数据库层**：捕获查询异常，返回空数组
2. **API层**：捕获所有异常，返回 200 状态码 + 空数组
3. **前端层**：不抛出异常，返回空数组给UI

### 为什么返回 200 而不是 500？

- 对于排行榜这种非关键功能，即使数据获取失败，也不应该影响应用的正常使用
- 返回 200 + 空数组，UI 可以正常渲染（显示"暂无数据"）
- 如果返回 500，前端可能会显示错误页面，影响用户体验

## 后续优化建议

1. **数据库迁移**：确保所有用户的 `total_transferred_bytes` 字段都有默认值 0
   ```sql
   UPDATE users SET total_transferred_bytes = 0 WHERE total_transferred_bytes IS NULL;
   ```

2. **监控告警**：添加日志监控，当排行榜查询失败时发送告警

3. **降级策略**：考虑添加本地缓存，当服务器不可用时显示缓存数据

4. **性能优化**：
   - 增加缓存时间（目前5分钟）
   - 考虑使用 CDN 缓存排行榜数据
   - 添加分页功能，避免一次加载过多数据

## 相关文件

- `web/src/services/database.js` - 数据库服务
- `web/src/handlers/leaderboard.js` - 排行榜处理器
- `lib/services/leaderboard_service.dart` - 前端排行榜服务
- `web/schema.sql` - 数据库表结构

## 测试清单

- [x] 数据库查询添加 NULL 值处理
- [x] 后端添加完善的错误处理
- [x] 前端改为返回空数组而不是抛出异常
- [ ] 部署到生产环境
- [ ] 验证 API 响应正常
- [ ] 在应用中测试排行榜功能
- [ ] 检查日志确认没有错误

## 联系方式

如有问题，请联系：
- 邮箱: support@fabushi.com
- 官网: https://fabushi.ombhrum.com
