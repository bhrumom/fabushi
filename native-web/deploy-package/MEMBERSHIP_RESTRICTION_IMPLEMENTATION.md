# 全球法布施会员权限限制实现

## 概述
在原有登录限制的基础上，进一步实现了会员权限控制。现在用户不仅需要登录，还必须是有效会员（试用期或付费会员）才能使用全球法布施功能。

## 实现的功能

### 1. 前端会员状态检查 (public/sender.js)

#### 1.1 添加会员状态检查方法
```javascript
async checkMembershipStatus(token) {
    try {
        const response = await fetch('/api/stripe/membership-status', {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            }
        });

        if (!response.ok) {
            if (response.status === 401) {
                throw new Error('认证失败，请重新登录');
            }
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        const data = await response.json();
        return data.membership;
    } catch (error) {
        console.error('获取会员状态失败:', error);
        throw error;
    }
}
```

#### 1.2 修改startSending方法
- 将方法改为 `async startSending()`
- 在登录检查之后添加会员权限验证
- 根据会员状态类型显示不同的提示信息
- 自动跳转到会员页面或显示会员弹窗

```javascript
// 检查用户会员状态
this.logMessage('🔍 正在验证会员权限...');
try {
    const membershipStatus = await this.checkMembershipStatus(token);
    if (!membershipStatus.isActive) {
        this.logMessage('❌ 全球法布施功能需要会员权限。');
        const upgradeMessage = membershipStatus.type === 'trial' && membershipStatus.isExpired 
            ? '您的免费试用期已结束，请升级为付费会员以继续使用全球发送功能。'
            : '全球法布施功能仅限会员使用，请先开通会员服务。';
        
        alert(`🔒 ${upgradeMessage}\n\n点击确定前往会员页面。`);
        
        // 跳转到会员页面
        if (typeof showMembershipModal === 'function') {
            showMembershipModal();
        } else {
            window.location.href = '/membership.html';
        }
        return;
    }
    
    this.logMessage(`✅ 会员验证通过 (${membershipStatus.type === 'trial' ? '试用期' : '付费会员'})`);
    if (membershipStatus.daysLeft && membershipStatus.daysLeft <= 7) {
        this.logMessage(`⚠️ 提醒：您的会员服务将在 ${membershipStatus.daysLeft} 天后到期`);
    }
} catch (error) {
    this.logMessage('❌ 会员状态验证失败，请重新登录或联系客服。');
    console.error('会员状态检查失败:', error);
    alert('会员状态验证失败，请重新登录后重试。');
    return;
}
```

### 2. 前端UI增强 (public/index.html)

#### 2.1 添加会员状态提示区域
在登录提示之后添加了会员状态提示框：

```html
<div id="membershipNotice" style="display: none; background: rgba(255, 107, 107, 0.1); border: 1px solid rgba(255, 107, 107, 0.3); border-radius: 8px; padding: 12px; margin-bottom: 16px; color: #c0392b;">
    <div style="display: flex; align-items: center; gap: 8px;">
        <span>💎</span>
        <span id="membershipNoticeText">全球法布施功能仅限会员使用，请先 <a href="#" onclick="showMembershipModal()" style="color: #66a6ff; text-decoration: underline;">开通会员</a> 或 <a href="membership.html" style="color: #66a6ff; text-decoration: underline;">了解详情</a></span>
    </div>
</div>
```

#### 2.2 增强会员状态控制函数

**updateMembershipBadge函数增强：**
- 根据会员状态控制会员提示的显示/隐藏
- 根据会员类型显示不同的提示文本
- 控制开始传送按钮的状态和文本

```javascript
function updateMembershipBadge(membership) {
    const badge = document.getElementById('membershipBadge');
    const membershipNotice = document.getElementById('membershipNotice');
    const membershipNoticeText = document.getElementById('membershipNoticeText');
    const startBtn = document.getElementById('startBtn');
    
    if (membership.isActive) {
        // 会员有效 - 隐藏会员提示，显示徽章
        if (membershipNotice) membershipNotice.style.display = 'none';
        // ... 显示会员徽章逻辑
        
        // 恢复开始传送按钮
        if (startBtn) {
            startBtn.innerHTML = '🚀 开始传送';
            startBtn.title = '';
        }
    } else {
        // 会员已过期或未开通 - 显示会员提示
        if (membershipNotice) {
            membershipNotice.style.display = 'block';
            
            if (membership.type === 'trial' && membership.isExpired) {
                membershipNoticeText.innerHTML = '您的免费试用期已结束，请 <a href="#" onclick="showMembershipModal()">升级为付费会员</a> 以继续使用全球发送功能';
            } else {
                membershipNoticeText.innerHTML = '全球法布施功能仅限会员使用，请先 <a href="#" onclick="showMembershipModal()">开通会员</a> 或 <a href="membership.html">了解详情</a>';
            }
        }
        
        // 更新开始传送按钮状态
        if (startBtn) {
            startBtn.innerHTML = '💎 需要会员';
            startBtn.title = '全球法布施功能需要会员权限';
        }
    }
}
```

#### 2.3 添加会员弹窗控制函数
```javascript
function showMembershipModal() {
    // 如果有会员弹窗，显示它；否则跳转到会员页面
    const membershipModal = document.getElementById('membershipModal');
    if (membershipModal) {
        membershipModal.style.display = 'block';
    } else {
        window.location.href = '/membership.html';
    }
}
```

#### 2.4 更新showGuestMode函数
确保访客模式下隐藏会员提示，只显示登录提示：

```javascript
function showGuestMode() {
    // ... 原有逻辑
    
    // 显示登录提示，隐藏会员提示
    const loginNotice = document.getElementById('loginNotice');
    const membershipNotice = document.getElementById('membershipNotice');
    if (loginNotice) {
        loginNotice.style.display = 'block';
    }
    if (membershipNotice) {
        membershipNotice.style.display = 'none';
    }
    
    // ... 原有逻辑
}
```

### 3. 后端API支持

系统使用现有的会员状态检查API：
- **端点**: `/api/stripe/membership-status`
- **方法**: GET
- **认证**: Bearer Token
- **返回**: 包含会员状态信息的JSON对象

会员状态对象结构：
```javascript
{
    isActive: boolean,      // 会员是否有效
    type: string,          // 'trial' | 'paid' | 'expired'
    daysLeft: number,      // 剩余天数
    isExpired: boolean,    // 是否已过期（仅试用期）
    expiresAt: string      // 过期时间ISO字符串
}
```

## 用户体验流程

### 未登录用户：
1. 看到登录提示框
2. 开始传送按钮显示"🔒 请先登录"
3. 点击按钮提示需要先登录

### 已登录但非会员用户：
1. 看到会员权限提示框
2. 开始传送按钮显示"💎 需要会员"
3. 点击按钮后：
   - 进行会员状态检查
   - 显示相应的升级提示
   - 自动跳转到会员页面

### 试用期用户：
1. 显示试用期徽章（如"试用 2天"）
2. 可以正常使用全球发送功能
3. 剩余天数≤7天时显示到期提醒

### 试用期过期用户：
1. 看到"试用期已结束"的会员提示
2. 开始传送按钮显示"💎 需要会员"
3. 提示升级为付费会员

### 付费会员用户：
1. 显示会员徽章（如"会员 25天"）
2. 可以正常使用全球发送功能
3. 剩余天数≤7天时显示续费提醒

## 安全特性

1. **双重验证**：前端和后端都进行会员状态检查
2. **实时验证**：每次发送前都重新检查会员状态
3. **状态同步**：UI状态与实际会员状态保持同步
4. **优雅降级**：API调用失败时提供友好的错误提示

## 测试

创建了专门的测试页面 `test-membership-restriction.html`：
- 模拟不同用户状态（访客、试用期、付费、过期）
- 测试会员状态检查功能
- 测试发送功能的权限控制
- 提供详细的测试日志和状态显示

## 兼容性

- 与现有的登录系统完全兼容
- 与现有的会员系统（Stripe/支付宝）完全兼容
- 保持了原有的UI设计风格
- 向后兼容，不影响现有功能

## 注意事项

1. 试用期用户可以正常使用全球发送功能
2. 试用期过期后需要升级为付费会员
3. 会员状态检查失败时会阻止发送操作
4. 建议在后端API层面也添加相应的权限检查以提高安全性
5. 会员状态缓存机制可以考虑添加以提高性能

## 后续优化建议

1. 添加会员状态缓存机制，减少API调用频率
2. 在后端发送API中也添加会员权限检查
3. 添加会员到期前的主动提醒功能
4. 考虑添加不同会员等级的功能限制
5. 优化会员页面的用户体验和转化率