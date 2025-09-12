# 兑换码会员时间更新修复

## 问题描述
使用兑换码后，会员的时间没有更新，用户在会员中心看不到会员状态的变化。

## 问题原因
1. **字段名不匹配**: 兑换码逻辑更新的是 `membershipExpiresAt` 字段，但会员状态检查函数查找的是 `membershipEndDate` 字段
2. **试用期处理不完整**: 没有正确处理用户当前试用期与兑换码时间的叠加

## 修复内容

### 1. 修复会员状态检查函数 (`stripe-config.js`)
```javascript
// 修复前
if (user.membershipEndDate) {
  const membershipEnd = new Date(user.membershipEndDate);
  // ...
}

// 修复后
const membershipEndDate = user.membershipExpiresAt || user.membershipEndDate;
if (membershipEndDate) {
  const membershipEnd = new Date(membershipEndDate);
  const membershipType = user.membershipType === 'trial' ? 'trial' : 'paid';
  // ...
}
```

### 2. 改进兑换码时间计算逻辑 (`worker.js`)
```javascript
// 修复前：只考虑付费会员时间
if (user.membershipExpiresAt && new Date(user.membershipExpiresAt) > now) {
  newExpiryDate = new Date(user.membershipExpiresAt);
}

// 修复后：同时考虑试用期和付费会员时间
let currentExpiryDate = null;

// 检查付费会员到期时间
if (user.membershipExpiresAt && new Date(user.membershipExpiresAt) > now) {
  currentExpiryDate = new Date(user.membershipExpiresAt);
}

// 检查试用期到期时间
if (user.freeTrialEndDate && new Date(user.freeTrialEndDate) > now) {
  const trialEnd = new Date(user.freeTrialEndDate);
  if (!currentExpiryDate || trialEnd > currentExpiryDate) {
    currentExpiryDate = trialEnd;
  }
}
```

## 修复效果
1. ✅ 兑换码使用后会员状态正确更新
2. ✅ 会员中心正确显示会员信息
3. ✅ 支持试用期和付费会员时间的正确叠加
4. ✅ 保持向后兼容性（支持旧的字段名）

## 测试方法

### 方法1: 使用测试页面
1. 访问 `/test-membership-status.html`
2. 点击"检查会员状态"查看当前状态
3. 点击"测试兑换码"输入兑换码进行测试
4. 观察会员状态是否正确更新

### 方法2: 使用测试脚本
```bash
node test-redeem-fix.js
```

### 方法3: 手动测试
1. 登录系统
2. 访问兑换码页面 `/redeem.html`
3. 输入有效的兑换码
4. 访问会员中心 `/membership.html`
5. 确认会员状态和到期时间正确显示

## 相关文件
- `stripe-config.js` - 会员状态检查函数
- `worker.js` - 兑换码使用逻辑
- `public/redeem.html` - 兑换码使用页面
- `public/membership.html` - 会员中心页面
- `test-membership-status.html` - 测试页面
- `test-redeem-fix.js` - 测试脚本

## 注意事项
1. 修复保持了向后兼容性，支持旧的 `membershipEndDate` 字段
2. 正确处理了试用会员和付费会员的类型区分
3. 兑换码时间会在现有会员时间基础上累加，而不是覆盖