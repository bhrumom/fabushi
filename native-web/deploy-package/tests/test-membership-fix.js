// 测试会员系统修复
// 这个脚本用于测试付费会员有效期更新和记录功能

const API_BASE = 'http://localhost:8787'; // 或者你的实际域名

async function testMembershipFix() {
  console.log('🧪 开始测试会员系统修复...\n');

  // 测试用户登录
  const loginResponse = await fetch(`${API_BASE}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      username: 'testuser',
      password: 'TestPassword123'
    })
  });

  if (!loginResponse.ok) {
    console.error('❌ 登录失败，请确保测试用户存在');
    return;
  }

  const { token } = await loginResponse.json();
  console.log('✅ 登录成功');

  // 测试获取购买记录
  console.log('\n📋 测试获取购买记录...');
  const purchaseResponse = await fetch(`${API_BASE}/api/admin/purchase-history`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });

  if (purchaseResponse.ok) {
    const purchaseData = await purchaseResponse.json();
    console.log('✅ 购买记录获取成功');
    console.log(`   记录数量: ${purchaseData.total}`);
    if (purchaseData.purchases.length > 0) {
      const latest = purchaseData.purchases[0];
      console.log(`   最新购买: ${latest.plan} - ¥${latest.amount}`);
      console.log(`   购买时间: ${new Date(latest.purchasedAt).toLocaleString()}`);
    }
  } else {
    console.log('⚠️  购买记录获取失败或为空');
  }

  // 测试获取兑换记录
  console.log('\n🎫 测试获取兑换记录...');
  const redeemResponse = await fetch(`${API_BASE}/api/admin/redeem-history`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });

  if (redeemResponse.ok) {
    const redeemData = await redeemResponse.json();
    console.log('✅ 兑换记录获取成功');
    console.log(`   记录数量: ${redeemData.total}`);
    if (redeemData.redeems.length > 0) {
      const latest = redeemData.redeems[0];
      console.log(`   最新兑换: ${latest.name} - ${latest.days}天`);
      console.log(`   兑换时间: ${new Date(latest.redeemedAt).toLocaleString()}`);
    }
  } else {
    console.log('⚠️  兑换记录获取失败或为空');
  }

  // 测试会员状态检查
  console.log('\n👤 测试会员状态检查...');
  const statusResponse = await fetch(`${API_BASE}/api/alipay/check-membership`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });

  if (statusResponse.ok) {
    const statusData = await statusResponse.json();
    console.log('✅ 会员状态检查成功');
    console.log(`   会员状态: ${statusData.membership.isActive ? '激活' : '未激活'}`);
    console.log(`   会员类型: ${statusData.membership.type}`);
    if (statusData.membership.expiresAt) {
      console.log(`   到期时间: ${new Date(statusData.membership.expiresAt).toLocaleString()}`);
    }
  } else {
    console.error('❌ 会员状态检查失败');
  }

  console.log('\n🎉 测试完成！');
}

// 如果直接运行此脚本
if (typeof window === 'undefined') {
  testMembershipFix().catch(console.error);
}