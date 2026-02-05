# 会员历史记录修复需求

## 问题描述

管理员账号登录后，会员页面显示以下问题：
1. 会员状态显示为 "expired"（已过期）
2. 购买记录为空
3. 兑换记录为空

## 根本原因

在 `web/src/services/database.js` 中，`getPurchaseHistory` 和 `getRedeemHistory` 方法使用了错误的字段名：
- 使用了 `user_id` 字段
- 但数据库表 `purchase_history` 和 `redeem_history` 实际使用的是 `username` 字段

## 解决方案

修改 `web/src/services/database.js` 中的两个方法：

### 1. 修复购买记录查询
```javascript
// 修改前
async getPurchaseHistory(username) {
  const result = await this.db.prepare('SELECT * FROM purchase_history WHERE user_id = ? ORDER BY purchased_at DESC').bind(username).all();
  return result.results || [];
}

// 修改后
async getPurchaseHistory(username) {
  const result = await this.db.prepare('SELECT * FROM purchase_history WHERE username = ? ORDER BY purchased_at DESC').bind(username).all();
  return result.results || [];
}
```

### 2. 修复兑换记录查询
```javascript
// 修改前
async getRedeemHistory(username) {
  const result = await this.db.prepare('SELECT * FROM redeem_history WHERE user_id = ? ORDER BY redeemed_at DESC').bind(username).all();
  return result.results || [];
}

// 修改后
async getRedeemHistory(username) {
  const result = await this.db.prepare('SELECT * FROM redeem_history WHERE username = ? ORDER BY redeemed_at DESC').bind(username).all();
  return result.results || [];
}
```

## 验证步骤

1. 部署修复后的代码到后端
2. 登录管理员账号
3. 进入会员中心页面
4. 检查：
   - 会员状态是否正确显示
   - 购买记录是否正常显示
   - 兑换记录是否正常显示

## 相关文件

- `web/src/services/database.js` - 数据库服务层（已修复）
- `web/schema.sql` - 数据库表结构定义
- `lib/screens/membership_screen.dart` - 前端会员页面
- `lib/services/membership_service.dart` - 前端会员服务
