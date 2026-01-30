# 会员历史记录修复设计

## 问题分析

### 数据流程

1. **前端请求** → `MembershipService.getPurchaseHistory(token)`
2. **API调用** → `GET /api/admin/purchase-history`
3. **后端处理** → `handleGetPurchaseHistory()` in `redeem.js`
4. **数据库查询** → `db.getPurchaseHistory(username)` in `database.js`
5. **SQL执行** → `SELECT * FROM purchase_history WHERE user_id = ?` ❌ **错误**

### 数据库表结构

根据 `web/schema.sql`：

```sql
CREATE TABLE IF NOT EXISTS purchase_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL,  -- ✅ 正确字段名
  order_id TEXT NOT NULL,
  plan TEXT NOT NULL,
  amount TEXT NOT NULL,
  currency TEXT DEFAULT 'CNY',
  status TEXT NOT NULL,
  payment_method TEXT NOT NULL,
  purchased_at TEXT NOT NULL,
  valid_from TEXT NOT NULL,
  valid_to TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS redeem_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL,  -- ✅ 正确字段名
  code TEXT NOT NULL,
  type TEXT NOT NULL,
  days INTEGER NOT NULL,
  redeemed_at TEXT NOT NULL,
  valid_from TEXT NOT NULL,
  valid_to TEXT NOT NULL,
  previous_expiry_date TEXT
);
```

### 错误原因

在 `database.js` 中，查询使用了 `user_id` 而不是 `username`：
- `WHERE user_id = ?` ❌ 错误
- `WHERE username = ?` ✅ 正确

## 修复方案

### 1. 数据库服务层修复

修改 `web/src/services/database.js` 中的两个方法：

```javascript
// 购买记录查询
async getPurchaseHistory(username) {
  const result = await this.db.prepare(
    'SELECT * FROM purchase_history WHERE username = ? ORDER BY purchased_at DESC'
  ).bind(username).all();
  return result.results || [];
}

// 兑换记录查询
async getRedeemHistory(username) {
  const result = await this.db.prepare(
    'SELECT * FROM redeem_history WHERE username = ? ORDER BY redeemed_at DESC'
  ).bind(username).all();
  return result.results || [];
}
```

### 2. 前端显示逻辑

前端代码已经正确实现，无需修改：

```dart
// lib/screens/membership_screen.dart
Future<void> _loadHistory() async {
  // 加载购买记录
  final purchaseResult = await _membershipService.getPurchaseHistory(authModel.authToken!);
  if (purchaseResult['success'] == true && purchaseResult['purchases'] != null) {
    final purchases = purchaseResult['purchases'] as List;
    setState(() {
      _purchaseHistory = purchases.map((item) => PurchaseRecord.fromJson(item)).toList();
    });
  }

  // 加载兑换记录
  final redeemResult = await _membershipService.getRedeemHistory(authModel.authToken!);
  if (redeemResult['success'] == true && redeemResult['redeems'] != null) {
    final redeems = redeemResult['redeems'] as List;
    setState(() {
      _redeemHistory = redeems.map((item) => RedeemRecord.fromJson(item)).toList();
    });
  }
}
```

## 测试计划

### 单元测试

1. 测试 `getPurchaseHistory` 方法
   - 输入：有效的 username
   - 预期：返回该用户的购买记录列表

2. 测试 `getRedeemHistory` 方法
   - 输入：有效的 username
   - 预期：返回该用户的兑换记录列表

### 集成测试

1. 创建测试用户
2. 添加购买记录
3. 添加兑换记录
4. 调用API验证返回数据

### 端到端测试

1. 登录管理员账号
2. 进入会员中心
3. 验证购买记录显示
4. 验证兑换记录显示

## 部署步骤

1. 提交代码到版本控制
2. 部署到测试环境
3. 执行测试计划
4. 部署到生产环境
5. 监控错误日志

## 回滚计划

如果修复导致问题：
1. 回滚到上一个版本
2. 检查数据库表结构
3. 重新分析问题
4. 提供新的修复方案
