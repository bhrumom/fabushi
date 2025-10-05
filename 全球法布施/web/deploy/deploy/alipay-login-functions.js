// 支付宝登录相关处理函数

// 生成支付宝登录URL
async function generateAlipayLoginUrl(env) {
  try {
    console.log('生成支付宝登录URL开始');
    console.log('环境变量检查:', {
      hasAppId: !!env.ALIPAY_APP_ID,
      hasWorkerUrl: !!env.WORKER_URL,
      hasUsersKv: !!env.USERS_KV
    });
    
    // 生成state，兼容不同的crypto实现
    let state;
    try {
      state = crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).substring(2) + Date.now().toString(36);
    } catch (cryptoError) {
      console.warn('crypto.randomUUID不可用，使用备用方案:', cryptoError);
      state = Math.random().toString(36).substring(2) + Date.now().toString(36);
    }
    const appId = env.ALIPAY_APP_ID;
    
    if (!appId) {
      console.error('支付宝应用ID未配置');
      return jsonResponse({ error: '支付宝应用ID未配置' }, 500);
    }
    
    const workerUrl = env.WORKER_URL || 'https://your-worker-url.workers.dev';
    console.log('使用worker URL:', workerUrl);
    
    const redirectUri = encodeURIComponent(`${workerUrl}/api/auth/alipay/callback`);
    
    const authUrl = `https://openauth.alipay.com/oauth2/publicAppAuthorize.htm?app_id=${appId}&scope=auth_user&redirect_uri=${redirectUri}&state=${state}`;
    
    console.log('生成的授权URL:', authUrl);
    
    // 存储state用于验证
    if (env.USERS_KV) {
      await env.USERS_KV.put(`alipay_state:${state}`, 'valid', { expirationTtl: 600 }); // 10分钟有效
      console.log('state已存储到KV');
    } else {
      console.warn('USERS_KV未绑定，跳过state存储');
    }
    
    const response = jsonResponse({ 
      authUrl: authUrl, 
      state: state,
      appId: appId 
    });
    
    console.log('响应数据:', { authUrl, state, appId });
    return response;
    
  } catch (error) {
    console.error('生成支付宝登录URL失败:', error);
    console.error('错误堆栈:', error.stack);
    return jsonResponse({ error: '生成支付宝登录URL失败: ' + error.message }, 500);
  }
}

// 通过支付宝授权码获取用户信息
async function getAlipayUserInfo(authCode, env) {
  const appId = env.ALIPAY_APP_ID;
  const privateKey = env.ALIPAY_PRIVATE_KEY;
  const alipayPublicKey = env.ALIPAY_PUBLIC_KEY;
  
  try {
    // 这里需要实现支付宝的签名验证和用户信息获取
    // 由于支付宝API需要复杂的签名处理，这里先返回模拟数据
    // 实际部署时需要实现完整的支付宝SDK逻辑
    
    console.log('获取支付宝用户信息，授权码:', authCode);
    
    // 模拟用户信息（实际应该调用支付宝API）
    const mockUserInfo = {
      user_id: '2088123456789012',
      nick_name: '支付宝用户',
      avatar: 'https://tfsimg.alipay.com/images/partner/T1kFldXk0rXXXXXXXX',
      province: '浙江省',
      city: '杭州市',
      gender: 'M'
    };
    
    return mockUserInfo;
  } catch (error) {
    console.error('获取支付宝用户信息失败:', error);
    throw error;
  }
}

// 处理支付宝登录
async function handleAlipayLogin(request, env) {
  try {
    const { auth_code, state } = await request.json();
    
    if (!auth_code) {
      return jsonResponse({ error: '缺少授权码' }, 400);
    }
    
    // 验证state
    if (state) {
      const storedState = await env.USERS_KV.get(`alipay_state:${state}`);
      if (!storedState) {
        return jsonResponse({ error: '无效的state参数' }, 400);
      }
      // 删除已使用的state
      await env.USERS_KV.delete(`alipay_state:${state}`);
    }
    
    // 获取支付宝用户信息
    const alipayUser = await getAlipayUserInfo(auth_code, env);
    
    // 检查是否已有绑定账号
    const existingBinding = await env.USERS_KV.get(`alipay_binding:${alipayUser.user_id}`);
    
    if (existingBinding) {
      // 已有绑定，直接登录
      const userData = await env.USERS_KV.get(`user:${existingBinding}`);
      if (userData) {
        const user = JSON.parse(userData);
        const token = await generateToken(user.username, env);
        return jsonResponse({ 
          token, 
          username: user.username,
          isNewUser: false,
          loginMethod: 'alipay',
          alipayUser: {
            userId: alipayUser.user_id,
            nickname: alipayUser.nick_name,
            avatar: alipayUser.avatar
          }
        });
      }
    }
    
    // 新用户或未绑定，返回用户信息供前端处理
    return jsonResponse({
      alipayUser,
      isNewUser: true,
      needsBinding: true
    });
    
  } catch (error) {
    console.error('支付宝登录失败:', error);
    return jsonResponse({ error: '支付宝登录失败: ' + error.message }, 500);
  }
}

// 绑定支付宝账号到现有邮箱账号
async function handleAlipayBind(request, env) {
  try {
    const { alipayUserId, email, password } = await request.json();
    
    if (!alipayUserId || !email || !password) {
      return jsonResponse({ error: '缺少必要参数' }, 400);
    }
    
    // 验证邮箱和密码
    const username = await env.USERS_KV.get(`email_to_username:${email}`);
    if (!username) {
      return jsonResponse({ error: '邮箱未注册' }, 400);
    }
    
    const userData = await env.USERS_KV.get(`user:${username}`);
    if (!userData) {
      return jsonResponse({ error: '用户不存在' }, 400);
    }
    
    const user = JSON.parse(userData);
    const isValidPassword = await verifyPassword(password, user);
    if (!isValidPassword) {
      return jsonResponse({ error: '密码错误' }, 400);
    }
    
    // 检查是否已有其他支付宝账号绑定
    const existingBinding = await env.USERS_KV.get(`alipay_binding:${alipayUserId}`);
    if (existingBinding && existingBinding !== username) {
      return jsonResponse({ error: '该支付宝账号已绑定其他用户' }, 400);
    }
    
    // 检查用户是否已绑定其他支付宝账号
    const userAlipayBinding = await env.USERS_KV.get(`user_alipay:${username}`);
    if (userAlipayBinding) {
      return jsonResponse({ error: '该账号已绑定其他支付宝' }, 400);
    }
    
    // 建立绑定关系
    await env.USERS_KV.put(`alipay_binding:${alipayUserId}`, username);
    await env.USERS_KV.put(`user_alipay:${username}`, alipayUserId);
    
    // 更新用户信息，添加支付宝绑定信息
    user.alipayUserId = alipayUserId;
    user.alipayBoundAt = new Date().toISOString();
    await env.USERS_KV.put(`user:${username}`, JSON.stringify(user));
    
    const token = await generateToken(username, env);
    return jsonResponse({ 
      token, 
      username,
      message: '支付宝账号绑定成功'
    });
    
  } catch (error) {
    console.error('支付宝绑定失败:', error);
    return jsonResponse({ error: '支付宝绑定失败: ' + error.message }, 500);
  }
}

// 支付宝账号注册（新用户）
async function handleAlipayRegister(request, env) {
  try {
    const { alipayUserId, username, password, nickname, avatar, email } = await request.json();
    
    if (!alipayUserId || !username || !password) {
      return jsonResponse({ error: '缺少必要参数' }, 400);
    }
    
    // 检查用户名是否已存在
    const existingUser = await env.USERS_KV.get(`user:${username}`);
    if (existingUser) {
      return jsonResponse({ error: '用户名已存在' }, 400);
    }
    
    // 如提供邮箱则检查唯一
    if (email) {
      const emailMapped = await env.USERS_KV.get(`email_to_username:${String(email).trim().toLowerCase()}`);
      if (emailMapped) {
        return jsonResponse({ error: '该邮箱已被注册' }, 400);
      }
    }
    
    // 检查支付宝是否已绑定
    const existingBinding = await env.USERS_KV.get(`alipay_binding:${alipayUserId}`);
    if (existingBinding) {
      return jsonResponse({ error: '该支付宝账号已绑定其他用户' }, 400);
    }
    
    // 创建密码哈希
    const creds = await createPasswordHash(password);
    
    // 为新用户设置3天免费试用
    const trialEndDate = calculateTrialEndDate();
    
    const userData = {
      username,
      email: email ? String(email).trim().toLowerCase() : null,
      passwordHash: creds.passwordHash,
      salt: creds.salt,
      iterations: creds.iterations,
      algo: creds.algo,
      createdAt: new Date().toISOString(),
      emailVerified: !!email,
      // 支付宝相关字段
      alipayUserId: alipayUserId,
      alipayNickname: nickname,
      alipayAvatar: avatar,
      alipayBoundAt: new Date().toISOString(),
      // 会员相关字段
      freeTrialEndDate: trialEndDate.toISOString(),
      membershipType: 'trial',
      stripeCustomerId: null,
      subscriptionId: null
    };
    
    // 保存用户数据
    await env.USERS_KV.put(`user:${username}`, JSON.stringify(userData));
    if (userData.email) {
      await env.USERS_KV.put(`email_to_username:${userData.email}`, username);
    }
    
    // 建立支付宝绑定关系
    await env.USERS_KV.put(`alipay_binding:${alipayUserId}`, username);
    await env.USERS_KV.put(`user_alipay:${username}`, alipayUserId);
    
    const token = await generateToken(username, env);
    return jsonResponse({ 
      token, 
      username,
      message: '注册成功，支付宝账号已绑定'
    }, 201);
    
  } catch (error) {
    console.error('支付宝注册失败:', error);
    return jsonResponse({ error: '支付宝注册失败: ' + error.message }, 500);
  }
}

// 解绑支付宝账号
async function handleAlipayUnbind(request, env) {
  try {
    const authHeader = request.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return jsonResponse({ error: '未提供认证信息' }, 401);
    }
    
    const token = authHeader.substring(7);
    const tokenData = await verifyToken(token, env);
    if (!tokenData) {
      return jsonResponse({ error: '认证失败' }, 401);
    }
    
    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: '用户不存在' }, 404);
    }
    
    const user = JSON.parse(userData);
    if (!user.alipayUserId) {
      return jsonResponse({ error: '该账号未绑定支付宝' }, 400);
    }
    
    // 删除绑定关系
    await env.USERS_KV.delete(`alipay_binding:${user.alipayUserId}`);
    await env.USERS_KV.delete(`user_alipay:${tokenData.username}`);
    
    // 更新用户信息
    delete user.alipayUserId;
    delete user.alipayNickname;
    delete user.alipayAvatar;
    delete user.alipayBoundAt;
    await env.USERS_KV.put(`user:${tokenData.username}`, JSON.stringify(user));
    
    return jsonResponse({ message: '支付宝账号解绑成功' });
    
  } catch (error) {
    console.error('支付宝解绑失败:', error);
    return jsonResponse({ error: '支付宝解绑失败: ' + error.message }, 500);
  }
}

// 处理支付宝登录回调
async function handleAlipayCallback(request, env) {
  try {
    const url = new URL(request.url);
    const authCode = url.searchParams.get('auth_code');
    const state = url.searchParams.get('state');
    
    console.log('收到支付宝登录回调:', { authCode, state });
    
    if (!authCode) {
      return Response.redirect(new URL('/login.html?error=missing_auth_code', request.url).toString(), 302);
    }
    
    // 验证state
    if (state) {
      const storedState = await env.USERS_KV.get(`alipay_state:${state}`);
      if (!storedState) {
        console.error('无效的state参数:', state);
        return Response.redirect(new URL('/login.html?error=invalid_state', request.url).toString(), 302);
      }
      // 删除已使用的state
      await env.USERS_KV.delete(`alipay_state:${state}`);
    }
    
    // 获取支付宝用户信息
    const alipayUser = await getAlipayUserInfo(authCode, env);
    
    // 检查用户信息是否完整
    if (!alipayUser || !alipayUser.user_id) {
      console.error('支付宝用户信息不完整:', alipayUser);
      // 直接跳转到Flutter应用的错误页面
      const redirectUrl = new URL('/index.html', request.url);
      redirectUrl.hash = 'error=invalid_alipay_user&error_message=支付宝用户信息不完整';
      return Response.redirect(redirectUrl.toString(), 302);
    }
    
    // 检查是否已有绑定账号
    const existingBinding = await env.USERS_KV.get(`alipay_binding:${alipayUser.user_id}`);
    
    if (existingBinding) {
      // 已有绑定，直接登录
      const userData = await env.USERS_KV.get(`user:${existingBinding}`);
      if (userData) {
        const user = JSON.parse(userData);
        const token = await generateToken(user.username, env);
        
        // 直接跳转到Flutter主应用，通过URL hash传递登录信息
        const redirectUrl = new URL('/index.html', request.url);
        redirectUrl.hash = `token=${token}&username=${user.username}`;
        
        console.log('支付宝登录成功，直接跳转到Flutter主应用:', redirectUrl.toString());
        return Response.redirect(redirectUrl.toString(), 302);
      }
    }
    
    // 新用户或未绑定，直接跳转到Flutter主应用进行绑定或注册
    const redirectUrl = new URL('/index.html', request.url);
    redirectUrl.hash = `alipay_auth_code=${authCode}&alipay_user_id=${alipayUser.user_id}&alipay_nickname=${encodeURIComponent(alipayUser.nick_name || '')}&alipay_avatar=${encodeURIComponent(alipayUser.avatar || '')}&needs_binding=true`;
    
    console.log('新用户或未绑定，直接跳转到Flutter主应用绑定页面:', redirectUrl.toString());
    return Response.redirect(redirectUrl.toString(), 302);
    
  } catch (error) {
    console.error('支付宝回调处理失败:', error);
    // 直接跳转到Flutter主应用的错误页面
    const redirectUrl = new URL('/index.html', request.url);
    redirectUrl.hash = `error=callback_failed&error_message=${encodeURIComponent(error.message)}`;
    return Response.redirect(redirectUrl.toString(), 302);
  }
}

// 辅助函数：JSON响应
function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization'
    }
  });
}

// 导出函数
export { generateAlipayLoginUrl, handleAlipayLogin, handleAlipayBind, handleAlipayRegister, handleAlipayCallback };