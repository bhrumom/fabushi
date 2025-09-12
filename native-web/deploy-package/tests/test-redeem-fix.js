// 测试兑换码修复的脚本
const BASE_URL = 'http://localhost:8787'; // 本地开发环境

async function request(method, path, body = null, token = null) {
  const headers = {
    'Content-Type': 'application/json'
  };
  
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }
  
  const options = {
    method,
    headers
  };
  
  if (body) {
    options.body = JSON.stringify(body);
  }
  
  const response = await fetch(`${BASE_URL}${path}`, options);
  const data = await response.json();
  
  console.log(`${method} ${path}:`, response.status, data);
  return { response, data };
}

async function testRedeemCodeFix() {
  console.log('=== 测试兑换码会员时间更新修复 ===\n');
  
  try {
    // 1. 创建测试用户
    console.log('1. 创建测试用户...');
    const testEmail = `test-redeem-${Date.now()}@example.com`;
    const testUsername = `testuser${Date.now()}`;
    const testPassword = 'TestPass123';
    
    // 发送验证码
    await request('POST', '/api/auth/send-verification-code', {
      email: testEmail,
      type: 'register'
    });
    
    // 等待一下让验证码生成
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // 注册用户（使用固定验证码进行测试）
    const registerResult = await request('POST', '/api/auth/register', {
      username: testUsername,
      email: testEmail,
      password: testPassword,
      verificationCode: '123456' // 在开发环境中可能需要实际的验证码
    });
    
    if (registerResult.response.status !== 201) {
      console.log('注册失败，尝试登录现有用户...');
    }
    
    // 2. 登录获取token
    console.log('\n2. 登录获取token...');
    const loginResult = await request('POST', '/api/auth/login', {
      username: testUsername,
      password: testPassword
    });
    
    if (loginResult.response.status !== 200) {
      console.error('登录失败，无法继续测试');
      return;
    }
    
    const userToken = loginResult.data.token;
    
    // 3. 检查初始会员状态
    console.log('\n3. 检查初始会员状态...');
    const initialStatus = await request('GET', '/api/alipay/check-membership', null, userToken);
    console.log('初始会员状态:', initialStatus.data.membership);
    
    // 4. 创建管理员token（假设有管理员账户）
    console.log('\n4. 尝试获取管理员权限...');
    const adminLoginResult = await request('POST', '/api/auth/login', {
      username: 'admin', // 假设的管理员用户名
      password: 'admin123' // 假设的管理员密码
    });
    
    let adminToken = null;
    if (adminLoginResult.response.status === 200) {
      adminToken = adminLoginResult.data.token;
      console.log('管理员登录成功');
    } else {
      console.log('管理员登录失败，跳过兑换码生成测试');
      return;
    }
    
    // 5. 生成测试兑换码
    console.log('\n5. 生成测试兑换码...');
    const createCodeResult = await request('POST', '/api/admin/create-redeem-code', {
      type: 'monthly',
      quantity: 1,
      description: '测试兑换码'
    }, adminToken);
    
    if (createCodeResult.response.status !== 200) {
      console.error('生成兑换码失败');
      return;
    }
    
    const testCode = createCodeResult.data.codes[0];
    console.log('生成的测试兑换码:', testCode);
    
    // 6. 使用兑换码
    console.log('\n6. 使用兑换码...');
    const useCodeResult = await request('POST', '/api/admin/use-redeem-code', {
      code: testCode
    }, userToken);
    
    console.log('兑换码使用结果:', useCodeResult.data);
    
    // 7. 检查兑换后的会员状态
    console.log('\n7. 检查兑换后的会员状态...');
    const finalStatus = await request('GET', '/api/alipay/check-membership', null, userToken);
    console.log('兑换后会员状态:', finalStatus.data.membership);
    
    // 8. 验证修复效果
    console.log('\n8. 验证修复效果...');
    const membership = finalStatus.data.membership;
    
    if (membership.isActive) {
      console.log('✅ 修复成功！会员状态已激活');
      console.log(`   会员类型: ${membership.type}`);
      console.log(`   到期时间: ${membership.expiresAt}`);
      console.log(`   剩余天数: ${membership.daysLeft}`);
    } else {
      console.log('❌ 修复失败！会员状态仍未激活');
      console.log('   可能的原因:');
      console.log('   - 字段名不匹配');
      console.log('   - 时间计算错误');
      console.log('   - 数据更新失败');
    }
    
  } catch (error) {
    console.error('测试过程中发生错误:', error);
  }
}

// 运行测试
testRedeemCodeFix().catch(console.error);