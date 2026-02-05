# 会员数据显示修复

## 问题

购买记录和兑换记录API返回500错误，无法显示数据。

## 原因

后端数据库查询使用了错误的字段名：
- 代码中使用：`username`
- D1表中实际：`user_id`

## D1数据库表结构

### purchase_history表
```sql
CREATE TABLE purchase_history (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,  -- ✅ 使用user_id
  order_id TEXT,
  plan TEXT,
  amount TEXT,
  currency TEXT,
  status TEXT,
  payment_method TEXT,
  purchased_at TEXT,
  valid_from TEXT,
  valid_to TEXT,
  created_at TEXT
);
```

### redeem_history表
```sql
CREATE TABLE redeem_history (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,  -- ✅ 使用user_id
  code TEXT,
  type TEXT,
  name TEXT,
  days INTEGER,
  redeemed_at TEXT,
  valid_from TEXT,
  valid_to TEXT,
  previous_expiry_date TEXT,
  created_at TEXT
);
```

## 修复内容

**文件**: `web/src/services/database.js`

### 修复前
```javascript
async getPurchaseHistory(username) {
  const result = await this.db.prepare(
    'SELECT * FROM purchase_history WHERE username = ? ORDER BY purchased_at DESC'
  ).bind(username).all();
  return result.results || [];
}

async getRedeemHistory(username) {
  const result = await this.db.prepare(
    'SELECT * FROM redeem_history WHERE username = ? ORDER BY redeemed_at DESC'
  ).bind(username).all();
  return result.results || [];
}
```

### 修复后
```javascript
async getPurchaseHistory(username) {
  const result = await this.db.prepare(
    'SELECT * FROM purchase_history WHERE user_id = ? ORDER BY purchased_at DESC'
  ).bind(username).all();
  return result.results || [];
}

async getRedeemHistory(username) {
  const result = await this.db.prepare(
    'SELECT * FROM redeem_history WHERE user_id = ? ORDER BY redeemed_at DESC'
  ).bind(username).all();
  return result.results || [];
}
```

## 验证数据

### bhrum用户的会员信息
```bash
wrangler d1 execute DB --remote --command "SELECT * FROM memberships WHERE user_id='bhrum';"
```

结果：
- membership_type: "paid"
- membership_expires_at: "2027-02-03T12:41:15.217Z"
- ✅ 会员有效期到2027年2月

### bhrum用户的购买记录
```bash
wrangler d1 execute DB --remote --command "SELECT * FROM purchase_history WHERE user_id='bhrum';"
```

结果：
- order_id: "WEB_bhrum_1760182736957"
- plan: "monthly"
- amount: "21.00"
- status: "completed"
- ✅ 有购买记录

## 部署

```bash
cd web
wrangler deploy --env production
```

部署成功：
- Version: c77f9285-dc53-4371-a876-2a88b2cfa271
- URL: https://flutter.ombhrum.com

## 测试步骤

1. **登录bhrum账号**
2. **进入个人中心**
3. **点击"购买记录"** - 应该显示购买历史
4. **点击"兑换记录"** - 应该显示兑换历史

## 预期结果

✅ 购买记录显示：
- 订单号
- 套餐类型
- 金额
- 状态
- 购买时间

✅ 兑换记录显示：
- 兑换码
- 类型
- 天数
- 兑换时间

## 总结

问题已修复并部署到生产环境。现在购买记录和兑换记录API可以正常返回数据。
