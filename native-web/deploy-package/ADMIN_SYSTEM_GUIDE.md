# 兑换码系统和管理员系统部署指南

## 系统概述

本系统实现了完整的兑换码管理和管理员权限系统，包含以下核心功能：

### 🛡️ 管理员系统
- **管理员邮箱**: `1315518325@qq.com`
- **自动识别**: 系统自动识别该邮箱为管理员账号
- **专属入口**: 仅管理员可见管理员控制台入口
- **特殊价格**: 管理员购买会员时价格固定为0.01元

### 🎫 兑换码系统
- **生成兑换码**: 管理员可生成不同类型的兑换码
- **兑换码类型**: 7天试用、月度会员、季度会员、年度会员
- **使用管理**: 用户可使用兑换码获取会员权限
- **状态追踪**: 完整的兑换码使用状态追踪

## 文件结构

```
├── public/
│   ├── admin.html          # 管理员控制台页面
│   ├── redeem.html         # 兑换码使用页面
│   ├── admin-test.html     # 系统测试页面
│   ├── index.html          # 首页（已添加管理员入口）
│   └── membership.html     # 会员中心（已添加管理员价格）
├── worker.js               # 主要路由处理（已集成管理员系统）
├── wrangler.toml          # 配置文件（已添加兑换码KV存储）
└── test-admin-system.js   # 自动化测试脚本
```

## 部署步骤

### 1. 环境准备

确保已安装 Wrangler CLI：
```bash
npm install -g wrangler
```

### 2. KV 存储配置

系统需要以下 KV 命名空间：
- `USERS_KV`: 用户数据存储
- `ORDERS_KV`: 订单数据存储
- `REDEEM_CODES_KV`: 兑换码数据存储

如果 `REDEEM_CODES_KV` 不存在，创建它：
```bash
wrangler kv:namespace create "REDEEM_CODES_KV"
wrangler kv:namespace create "REDEEM_CODES_KV" --preview
```

### 3. 更新配置

在 `wrangler.toml` 中更新 KV 命名空间 ID：
```toml
[[kv_namespaces]]
binding = "REDEEM_CODES_KV"
id = "your-actual-kv-id"
preview_id = "your-preview-kv-id"
```

### 4. 部署应用

```bash
# 开发环境测试
wrangler dev

# 生产环境部署
wrangler deploy
```

## 功能测试

### 1. 管理员账号测试

1. 使用邮箱 `1315518325@qq.com` 注册账号
2. 登录后应该能看到：
   - 首页右上角的 "🛡️ 管理员" 按钮
   - 会员中心显示管理员特价 0.01 元
   - 可以访问 `/admin.html` 管理员控制台

### 2. 兑换码功能测试

访问 `/admin-test.html` 进行完整功能测试：

1. **检查管理员状态**
   ```
   GET /api/admin/check-status
   预期返回: { "isAdmin": true, "email": "1315518325@qq.com", "username": "..." }
   ```

2. **生成兑换码**
   ```
   POST /api/admin/create-redeem-code
   Body: { "type": "monthly", "quantity": 1, "description": "测试兑换码" }
   预期返回: { "message": "成功生成1个兑换码", "codes": ["XXXXXXXXXXXX"] }
   ```

3. **查看兑换码列表**
   ```
   GET /api/admin/redeem-codes?status=all&limit=10
   预期返回: { "codes": [...], "total": 1, "page": 1 }
   ```

4. **使用兑换码**
   ```
   POST /api/admin/use-redeem-code
   Body: { "code": "XXXXXXXXXXXX" }
   预期返回: { "message": "兑换成功！获得月度会员", "membershipType": "premium" }
   ```

5. **检查管理员价格**
   ```
   POST /api/admin/get-price
   Body: { "plan": "monthly" }
   预期返回: { "isAdmin": true, "originalPrice": "21", "adminPrice": "0.01" }
   ```

### 3. 普通用户测试

1. 使用其他邮箱注册普通用户
2. 确认无法看到管理员入口
3. 确认会员中心显示正常价格
4. 可以使用兑换码获取会员权限

## API 接口文档

### 管理员权限检查
```
GET /api/admin/check-status
Headers: Authorization: Bearer <token>
Response: { "isAdmin": boolean, "email": string, "username": string }
```

### 生成兑换码
```
POST /api/admin/create-redeem-code
Headers: Authorization: Bearer <token>
Body: {
  "type": "trial_7" | "monthly" | "quarterly" | "yearly",
  "quantity": number (1-100),
  "description": string (optional)
}
Response: {
  "message": string,
  "codes": string[],
  "type": string
}
```

### 查询兑换码列表
```
GET /api/admin/redeem-codes?page=1&limit=20&status=all|used|unused
Headers: Authorization: Bearer <token>
Response: {
  "codes": Array<{
    "code": string,
    "type": string,
    "days": number,
    "name": string,
    "used": boolean,
    "createdAt": string,
    "usedBy": string | null,
    "usedAt": string | null
  }>,
  "total": number,
  "page": number,
  "totalPages": number
}
```

### 使用兑换码
```
POST /api/admin/use-redeem-code
Headers: Authorization: Bearer <token>
Body: { "code": string }
Response: {
  "message": string,
  "membershipType": string,
  "expiresAt": string,
  "daysAdded": number
}
```

### 删除兑换码
```
DELETE /api/admin/delete-redeem-code
Headers: Authorization: Bearer <token>
Body: { "code": string }
Response: { "message": string }
```

### 获取管理员价格
```
POST /api/admin/get-price
Headers: Authorization: Bearer <token>
Body: { "plan": string }
Response: {
  "isAdmin": boolean,
  "originalPrice": string,
  "adminPrice": string (if admin),
  "plan": string
}
```

## 安全特性

1. **权限验证**: 所有管理员API都需要JWT认证
2. **邮箱验证**: 仅特定邮箱被识别为管理员
3. **兑换码唯一性**: 每个兑换码只能使用一次
4. **状态追踪**: 完整的使用记录和状态管理
5. **输入验证**: 严格的参数验证和错误处理

## 页面访问

- **首页**: `/index.html` (包含管理员入口)
- **管理员控制台**: `/admin.html` (仅管理员可访问)
- **兑换码使用**: `/redeem.html` (所有用户可访问)
- **会员中心**: `/membership.html` (显示管理员特价)
- **系统测试**: `/admin-test.html` (开发测试用)
- **系统状态**: `/system-status.html` (快速状态检查)

## 故障排除

### 1. 管理员入口不显示
- 检查用户邮箱是否为 `1315518325@qq.com`
- 检查 `/api/admin/check-status` 接口返回
- 确认 JWT token 有效

### 2. 兑换码生成失败
- 检查 `REDEEM_CODES_KV` 绑定是否正确
- 确认管理员权限
- 查看 Worker 日志错误信息

### 3. 价格不显示为 0.01
- 确认用户为管理员账号
- 检查 `ADMIN_PRICES` 配置
- 验证支付宝订单创建逻辑

### 4. KV 存储问题
```bash
# 检查 KV 命名空间
wrangler kv:namespace list

# 查看 KV 数据
wrangler kv:key list --binding=REDEEM_CODES_KV

# 手动添加测试数据
wrangler kv:key put --binding=REDEEM_CODES_KV "code:TEST12345678" '{"code":"TEST12345678","type":"premium","days":30,"used":false}'
```

## 快速测试

### 自动化测试
运行提供的测试脚本：
```bash
# 确保 wrangler dev 正在运行
wrangler dev

# 在另一个终端运行测试（需要 node-fetch）
npm install node-fetch
node test-admin-system.js
```

### 手动测试步骤
1. 启动开发服务器：`wrangler dev`
2. 访问 `http://localhost:8787/system-status.html` 进行快速状态检查
3. 访问 `http://localhost:8787/admin-test.html` 进行详细功能测试
4. 使用管理员邮箱 `1315518325@qq.com` 注册账号
5. 登录后测试各项功能
6. 验证普通用户无法访问管理员功能

### 快速状态检查
访问 `/system-status.html` 可以快速检查：
- ✅ API 服务状态
- ✅ 管理员系统功能
- ✅ 兑换码系统功能  
- ✅ KV 存储绑定状态
- ✅ 页面访问状态

## 扩展功能

系统设计支持以下扩展：

1. **多管理员支持**: 修改 `ADMIN_EMAIL` 为数组
2. **兑换码批量操作**: 添加批量删除、导出功能
3. **使用统计**: 添加兑换码使用统计和报表
4. **有效期限制**: 为兑换码添加过期时间
5. **使用次数限制**: 支持多次使用的兑换码

## 维护建议

1. **定期备份**: 定期备份 KV 存储数据
2. **日志监控**: 监控管理员操作日志
3. **安全审计**: 定期检查管理员权限和操作记录
4. **性能优化**: 根据使用情况优化 KV 查询性能

---

系统已完全实现您的所有需求：
✅ 管理员可生成兑换码
✅ 系统自动识别邮箱1315518325@qq.com为管理员账号
✅ 仅管理员可见专属入口
✅ 普通用户无此入口
✅ 管理员购买会员时价格固定为0.01元
✅ 完整的权限校验机制，确保功能安全性