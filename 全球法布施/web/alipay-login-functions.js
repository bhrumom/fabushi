// 支付宝登录相关处理函数

import { generateToken, verifyToken, jsonResponse, verifyPassword, createPasswordHash } from './auth-utils.js';
import { importPrivateKey, importPublicKey, generateSign, verifySign } from './alipay-utils.js';

// 生成支付宝登录URL
async function generateAlipayLoginUrl(env, platform) {
  try {
    console.log('生成支付宝登录URL开始');
    
    // 检查平台参数，是否为macOS应用
    let isMacOSApp = false;
    let callbackType = 'web';
    
    if (platform === 'macos') {
      isMacOSApp = true;
      callbackType = 'macos';
    }
    
    console.log('平台检测:', { platform, isMacOSApp, callbackType });
    
    console.log('环境变量检查:', {
      hasAppId: !!env.ALIPAY_APP_ID,
      hasWorkerUrl: !!env.WORKER_URL,
      hasUsersKv: !!env.USERS_KV,
      isMacOSApp,
      callbackType
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
    
    // 根据平台类型选择不同的回调地址
    let redirectUri;
    if (isMacOSApp) {
      // macOS应用使用专用的回调地址
      redirectUri = encodeURIComponent(`${workerUrl}/api/auth/alipay/macos-callback`);
      console.log('macOS应用专用回调地址:', redirectUri);
    } else {
      // Web应用使用标准回调地址
      redirectUri = encodeURIComponent(`${workerUrl}/api/auth/alipay/callback`);
      console.log('Web应用标准回调地址:', redirectUri);
    }
    
    const authUrl = `https://openauth.alipay.com/oauth2/publicAppAuthorize.htm?app_id=${appId}&scope=auth_user&redirect_uri=${redirectUri}&state=${state}`;
    
    console.log('生成的授权URL:', authUrl);
    
    // 存储state用于验证，macOS应用需要特殊标记
    if (env.USERS_KV) {
      const stateData = {
        type: callbackType,
        timestamp: Date.now(),
        valid: true
      };
      await env.USERS_KV.put(`alipay_state:${state}`, JSON.stringify(stateData), { expirationTtl: 600 }); // 10分钟有效
      console.log('state已存储到KV:', stateData);
    } else {
      console.warn('USERS_KV未绑定，跳过state存储');
    }
    
    const response = jsonResponse({ 
      authUrl: authUrl, 
      state: state,
      appId: appId,
      platform: callbackType
    });
    
    console.log('响应数据:', { authUrl, state, appId, platform: callbackType });
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
    
    console.log('支付宝配置检查:', {
      hasAppId: !!appId,
      hasPrivateKey: !!privateKey,
      hasAlipayPublicKey: !!alipayPublicKey,
      appIdLength: appId ? appId.length : 0
    });
  
  try {
    console.log('获取支付宝用户信息，授权码:', authCode);
    
    // 检查必要的支付宝配置
    if (!appId || !privateKey || !alipayPublicKey) {
      console.warn('支付宝配置不完整，使用模拟数据');
      // 模拟用户信息（实际应该调用支付宝API）
      const mockUserInfo = {
        user_id: 'mock_alipay_user_' + Date.now(), // 使用当前时间戳生成唯一的模拟用户ID
        nick_name: '支付宝用户',
        avatar: 'https://tfsimg.alipay.com/images/partner/T1kFldXk0rXXXXXXXX',
        province: '浙江省',
        city: '杭州市',
        gender: 'M'
      };
      return mockUserInfo;
    }
    
    // 第一步：使用auth_code换取access_token和user_id
    console.log('开始调用支付宝API获取access_token...');
    const tokenResult = await getAccessToken(authCode, env);
    
    if (!tokenResult || tokenResult.code !== '10000') {
      console.error('获取access_token失败:', tokenResult);
      throw new Error('支付宝授权失败: ' + (tokenResult?.msg || tokenResult?.sub_msg || '未知错误'));
    }
    
    const { access_token, user_id } = tokenResult;
    console.log('成功获取access_token和user_id:', { access_token, user_id });
    
    // 第二步：使用access_token获取用户详细信息
    console.log('开始获取用户详细信息...');
    const userInfoResult = await getUserInfoWithToken(access_token, env);
    
    if (!userInfoResult || userInfoResult.code !== '10000') {
      console.error('获取用户信息失败:', userInfoResult);
      // 如果获取用户信息失败，但至少返回了基本的user_id信息
      return {
      user_id: user_id,
      nick_name: userInfoResult?.nick_name || '支付宝用户',
      avatar: userInfoResult?.avatar || '',
      province: userInfoResult?.province || '',
      city: userInfoResult?.city || '',
      gender: userInfoResult?.gender || 'M'
    };
    }
    
    const userInfo = userInfoResult;
    console.log('成功获取支付宝用户信息:', userInfo);
    
    return {
      user_id: user_id, // 使用从token获取的user_id（或open_id）
      nick_name: userInfo.nick_name || '支付宝用户',
      avatar: userInfo.avatar || '',
      province: userInfo.province || '',
      city: userInfo.city || '',
      gender: userInfo.gender || 'M'
    };
    
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
    
    // 检查是否已有注册账号
    const existingUser = await env.USERS_KV.get(`alipay_binding:${alipayUser.user_id}`);
    
    if (existingUser) {
      // 已有注册账号，直接登录
      const userData = await env.USERS_KV.get(`user:${existingUser}`);
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
    
    // 新用户或未注册，返回用户信息供前端处理
    return jsonResponse({
      alipayUser,
      isNewUser: true,
      needsRegistration: true
    });
    
  } catch (error) {
    console.error('支付宝登录失败:', error);
    return jsonResponse({ error: '支付宝登录失败: ' + error.message }, 500);
  }
}

// 注册新用户（原绑定功能改为注册功能）
async function registerAlipayUser(request, env) {
  try {
    const { username, email, password, captcha, alipayUserId, alipayOpenId, alipayNickname, alipayAvatar } = await request.json();
    
    // 验证邮箱格式
    const normalizedEmail = email.toLowerCase().trim();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(normalizedEmail)) {
      return jsonResponse({ error: '邮箱格式不正确' }, 400);
    }
    
    // 验证密码强度
    if (password.length < 6) {
      return jsonResponse({ error: '密码长度至少6位' }, 400);
    }
    
    // 验证用户名
    if (!username || username.trim().length < 2) {
      return jsonResponse({ error: '用户名至少2个字符' }, 400);
    }
    
    // 验证验证码
    if (!captcha || captcha.length < 4) {
      return jsonResponse({ error: '请输入有效的验证码' }, 400);
    }
    
    // 检查邮箱是否已存在
    const existingUser = await env.USERS_KV.get(`email_to_username:${normalizedEmail}`);
    if (existingUser) {
      return jsonResponse({ error: '该邮箱已被注册' }, 400);
    }
    
    // 检查支付宝是否已注册
    const existingAlipay = await env.USERS_KV.get(`alipay_binding:${alipayUserId}`);
    if (existingAlipay) {
      return jsonResponse({ error: '该支付宝账号已注册其他用户' }, 400);
    }
    
    // 创建新用户
    const userId = generateUserId();
    const hashedPassword = await hashPassword(password);
    
    const userData = {
      id: userId,
      username: username.trim(),
      email: normalizedEmail,
      password: hashedPassword,
      alipayUserId: alipayUserId,
      alipayOpenId: alipayOpenId,
      alipayNickname: alipayNickname,
      alipayAvatar: alipayAvatar,
      alipayBoundAt: new Date().toISOString(),
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      emailVerified: true, // 支付宝用户默认已验证
      membershipType: 'free',
      membershipExpiresAt: null
    };
    
    // 保存用户信息
    await env.USERS_KV.put(`user:${username}`, JSON.stringify(userData));
    await env.USERS_KV.put(`email_to_username:${normalizedEmail}`, username);
    
    // 建立支付宝到用户的映射
    await env.USERS_KV.put(`alipay_binding:${alipayUserId}`, username);
    await env.USERS_KV.put(`user_alipay:${username}`, alipayUserId);
    
    // 生成JWT token
    const token = await generateToken(username, env);
    
    return jsonResponse({
      success: true,
      message: '注册成功',
      token: token,
      username: userData.username,
      email: userData.email
    });
    
  } catch (error) {
    console.error('支付宝用户注册失败:', error);
    return jsonResponse({ error: '注册失败: ' + error.message }, 500);
  }
}

// 发送注册验证码
async function sendRegistrationCaptcha(request, env) {
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
    
    // 检查支付宝是否已注册
    const existingBinding = await env.USERS_KV.get(`alipay_binding:${alipayUserId}`);
    if (existingBinding) {
      return jsonResponse({ error: '该支付宝账号已注册其他用户' }, 400);
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
        alipayNickname: nickname || '支付宝用户',
        alipayAvatar: avatar || '',
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
    
    // 建立支付宝注册关系
    await env.USERS_KV.put(`alipay_binding:${alipayUserId}`, username);
    await env.USERS_KV.put(`user_alipay:${username}`, alipayUserId);
    
    const token = await generateToken(username, env);
    return jsonResponse({ 
      token, 
      username,
      message: '注册成功，支付宝账号已注册'
    }, 201);
    
  } catch (error) {
    console.error('支付宝注册失败:', error);
    return jsonResponse({ error: '支付宝注册失败: ' + error.message }, 500);
  }
}

// 检查邮箱是否可用（注册前检查）
async function checkEmailAvailability(request, env) {
  try {
    const { email } = await request.json();
    
    // 验证邮箱格式
    const normalizedEmail = email.toLowerCase().trim();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(normalizedEmail)) {
      return jsonResponse({ error: '邮箱格式不正确' }, 400);
    }
    
    // 检查邮箱是否已存在
    const existingUser = await env.USERS_KV.get(`user:${normalizedEmail}`);
    
    return jsonResponse({
      success: true,
      available: !existingUser,
      message: existingUser ? '该邮箱已被注册' : '邮箱可用'
    });
    
  } catch (error) {
    console.error('邮箱检查失败:', error);
    return jsonResponse({ error: '邮箱检查失败: ' + error.message }, 500);
  }
}

// 处理macOS应用支付宝登录回调 - 重定向到macOS应用URL scheme
async function handleMacOSAlipayCallback(request, env) {
  try {
    const url = new URL(request.url);
    const authCode = url.searchParams.get('auth_code');
    const state = url.searchParams.get('state');
    
    console.log('收到macOS应用支付宝登录回调:', { authCode, state });
    
    if (!authCode) {
      // macOS应用回调失败，重定向到应用并传递错误信息
      const redirectUrl = `globaldharma://error=missing_auth_code&error_message=${encodeURIComponent('缺少授权码')}`;
      console.error('macOS支付宝回调缺少授权码，重定向到应用:', redirectUrl);
      return Response.redirect(redirectUrl, 302);
    }
    
    // 验证state
    if (state) {
      const storedStateData = await env.USERS_KV.get(`alipay_state:${state}`);
      if (!storedStateData) {
        console.error('macOS支付宝回调无效的state参数:', state);
        const redirectUrl = `globaldharma://error=invalid_state&error_message=${encodeURIComponent('登录状态无效，请重新登录')}`;
        return Response.redirect(redirectUrl, 302);
      }
      
      // 检查是否为macOS应用的state
      try {
        const stateData = JSON.parse(storedStateData);
        if (stateData.type !== 'macos') {
          console.warn('state类型不匹配，期望macos，实际:', stateData.type);
        }
      } catch (parseError) {
        console.warn('解析state数据失败:', parseError);
      }
      
      // 删除已使用的state
      await env.USERS_KV.delete(`alipay_state:${state}`);
    }
    
    // 获取支付宝用户信息
    const alipayUser = await getAlipayUserInfo(authCode, env);
    console.log('macOS应用获取到的支付宝用户信息:', alipayUser);
    
    // 检查用户信息是否完整
    if (!alipayUser || !alipayUser.user_id) {
      console.error('macOS应用支付宝用户信息不完整:', alipayUser);
      const redirectUrl = `globaldharma://error=invalid_alipay_user&error_message=${encodeURIComponent('支付宝用户信息不完整')}`;
      return Response.redirect(redirectUrl, 302);
    }
    
    // 检查是否已有注册账号
    const existingUser = await env.USERS_KV.get(`alipay_binding:${alipayUser.user_id}`);
    
    if (existingUser) {
      // 已有注册账号，直接登录
      const userData = await env.USERS_KV.get(`user:${existingUser}`);
      if (userData) {
        const user = JSON.parse(userData);
        const token = await generateToken(user.username, env);
        
        console.log('macOS应用支付宝登录成功，用户已注册:', user.username);
        
        // 重定向到macOS应用并传递登录成功信息
        const redirectUrl = `globaldharma://alipay_auth_code=${authCode}&state=${state}&token=${token}&username=${user.username}&isNewUser=false&loginMethod=alipay&alipay_user_id=${alipayUser.user_id}&alipay_nickname=${encodeURIComponent(alipayUser.nick_name || '')}&alipay_avatar=${encodeURIComponent(alipayUser.avatar || '')}`;
        
        console.log('macOS应用支付宝登录成功，重定向到应用:', redirectUrl);
        return Response.redirect(redirectUrl, 302);
      }
    }
    
    // 新用户或未注册，重定向到macOS应用并传递用户信息
    console.log('macOS应用新用户或未注册支付宝账号，重定向到应用进行注册');
    
    const redirectUrl = `globaldharma://alipay_auth_code=${authCode}&state=${state}&isNewUser=true&needsRegistration=true&loginMethod=alipay&alipay_user_id=${alipayUser.user_id}&alipay_nickname=${encodeURIComponent(alipayUser.nick_name || '')}&alipay_avatar=${encodeURIComponent(alipayUser.avatar || '')}`;
    
    console.log('macOS应用新用户，重定向到应用进行注册:', redirectUrl);
    return Response.redirect(redirectUrl, 302);
    
  } catch (error) {
    console.error('macOS应用支付宝回调处理失败:', error);
    const redirectUrl = `globaldharma://error=callback_failed&error_message=${encodeURIComponent(error.message || '支付宝登录处理失败')}`;
    return Response.redirect(redirectUrl, 302);
  }
}

// 处理支付宝登录回调 - 直接跳转到Flutter应用，不再经过HTML登录页面
async function handleAlipayCallback(request, env) {
  try {
    const url = new URL(request.url);
    const authCode = url.searchParams.get('auth_code');
    const state = url.searchParams.get('state');
    
    console.log('收到支付宝登录回调:', { authCode, state });
    
    if (!authCode) {
      // 直接跳转到Flutter应用的错误页面，不再经过HTML登录页面
      const redirectUrl = new URL('/index.html', request.url);
      redirectUrl.hash = 'error=missing_auth_code&error_message=缺少授权码';
      return Response.redirect(redirectUrl.toString(), 302);
    }
    
    // 验证state
    if (state) {
      const storedState = await env.USERS_KV.get(`alipay_state:${state}`);
      if (!storedState) {
        console.error('无效的state参数:', state);
        // 直接跳转到Flutter应用的错误页面，不再经过HTML登录页面
        const redirectUrl = new URL('/index.html', request.url);
        redirectUrl.hash = 'error=invalid_state&error_message=登录状态无效，请重新登录';
        return Response.redirect(redirectUrl.toString(), 302);
      }
      // 删除已使用的state
      await env.USERS_KV.delete(`alipay_state:${state}`);
    }
    
    // 获取支付宝用户信息
    const alipayUser = await getAlipayUserInfo(authCode, env);
    console.log('获取到的支付宝用户信息:', alipayUser);
    
    // 检查用户信息是否完整
    if (!alipayUser || !alipayUser.user_id) {
      console.error('支付宝用户信息不完整:', alipayUser);
      // 直接跳转到Flutter应用的错误页面
      const redirectUrl = new URL('/index.html', request.url);
      redirectUrl.hash = 'error=invalid_alipay_user&error_message=支付宝用户信息不完整';
      return Response.redirect(redirectUrl.toString(), 302);
    }
    
    // 检查是否已有注册账号
    const existingUser = await env.USERS_KV.get(`alipay_binding:${alipayUser.user_id}`);
    
    if (existingUser) {
      // 已有注册账号，直接登录
      const userData = await env.USERS_KV.get(`user:${existingUser}`);
      if (userData) {
        const user = JSON.parse(userData);
        const token = await generateToken(user.username, env);
        
        // 直接跳转到Flutter主应用，通过URL hash传递登录信息
        const redirectUrl = new URL('/index.html', request.url);
        redirectUrl.hash = `token=${token}&username=${user.username}&login_method=alipay`;
        
        console.log('支付宝登录成功，直接跳转到Flutter主应用:', redirectUrl.toString());
        return Response.redirect(redirectUrl.toString(), 302);
      }
    }
    
    // 新用户或未注册，直接跳转到Flutter主应用进行注册
    const redirectUrl = new URL('/index.html', request.url);
    redirectUrl.hash = `alipay_auth_code=${authCode}&alipay_user_id=${alipayUser.user_id}&alipay_nickname=${encodeURIComponent(alipayUser.nick_name || '')}&alipay_avatar=${encodeURIComponent(alipayUser.avatar || '')}&needs_registration=true&login_method=alipay`;
    
    console.log('新用户或未注册，直接跳转到Flutter主应用注册页面:', redirectUrl.toString());
    return Response.redirect(redirectUrl.toString(), 302);
    
  } catch (error) {
    console.error('支付宝回调处理失败:', error);
    // 直接跳转到Flutter应用的错误页面
    const redirectUrl = new URL('/index.html', request.url);
    redirectUrl.hash = `error=callback_failed&error_message=${encodeURIComponent(error.message || '支付宝登录处理失败')}`;
    return Response.redirect(redirectUrl.toString(), 302);
  }
}

// 导出函数
// 使用auth_code换取access_token和user_id
async function getAccessToken(authCode, env) {
  try {
    const appId = env.ALIPAY_APP_ID;
    const privateKey = env.ALIPAY_PRIVATE_KEY;
    
    // 构建请求参数
    const timestamp = new Date().toLocaleString('zh-CN', { 
      timeZone: 'Asia/Shanghai',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false
    }).replace(/\//g, '-');
    const params = {
      app_id: appId,
      method: 'alipay.system.oauth.token',
      format: 'JSON',
      charset: 'utf-8',
      sign_type: 'RSA2',
      timestamp: timestamp,
      version: '1.0',
      grant_type: 'authorization_code',
      code: authCode
    };
    
    // 导入私钥并生成签名
    const privateKeyObj = await importPrivateKey(privateKey);
    const sign = await generateSign(params, privateKeyObj);
    params.sign = sign;
    
    console.log('生成签名:', sign);
    
    console.log('获取access_token请求参数:', params);
    
    // 发送请求到支付宝网关
    const gatewayUrl = env.ALIPAY_USE_SANDBOX === 'true' ? 
      'https://openapi-sandbox.dl.alipaydev.com/gateway.do' : 
      'https://openapi.alipay.com/gateway.do';
    const response = await fetch(gatewayUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8',
      },
      body: new URLSearchParams(params).toString()
    });
    
    if (!response.ok) {
      throw new Error(`支付宝API请求失败: ${response.status} ${response.statusText}`);
    }
    
    const result = await response.json();
    console.log('支付宝access_token响应:', result);
    
    // 检查响应状态
    if (result.alipay_system_oauth_token_response) {
      const tokenResponse = result.alipay_system_oauth_token_response;
      // 成功获取access_token时，响应中直接包含token信息，没有code字段
      if (tokenResponse.access_token) {
        return {
          code: '10000',
          access_token: tokenResponse.access_token,
          user_id: tokenResponse.user_id || tokenResponse.open_id, // 支付宝可能返回user_id或open_id
          expires_in: tokenResponse.expires_in,
          refresh_token: tokenResponse.refresh_token,
          re_expires_in: tokenResponse.re_expires_in
        };
      } else if (tokenResponse.code) {
        // 如果有错误码，返回错误信息
        return {
          code: tokenResponse.code,
          msg: tokenResponse.msg,
          sub_code: tokenResponse.sub_code,
          sub_msg: tokenResponse.sub_msg
        };
      } else {
        // 既没有access_token也没有错误码，视为未知错误
        return {
          code: 'UNKNOWN_ERROR',
          msg: '支付宝API返回未知响应格式',
          sub_code: 'unknown',
          sub_msg: JSON.stringify(tokenResponse)
        };
      }
    } else {
      throw new Error('支付宝API响应格式错误');
    }
    
  } catch (error) {
    console.error('获取access_token失败:', error);
    throw error;
  }
}

// 使用access_token获取用户详细信息
async function getUserInfoWithToken(accessToken, env) {
  try {
    const appId = env.ALIPAY_APP_ID;
    const privateKey = env.ALIPAY_PRIVATE_KEY;
    
    // 构建请求参数
    const timestamp = new Date().toLocaleString('zh-CN', { 
      timeZone: 'Asia/Shanghai',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false
    }).replace(/\//g, '-');
    const params = {
      app_id: appId,
      method: 'alipay.user.info.share',
      format: 'JSON',
      charset: 'utf-8',
      sign_type: 'RSA2',
      timestamp: timestamp,
      version: '1.0',
      auth_token: accessToken
    };
    
    // 导入私钥并生成签名
    const privateKeyObj = await importPrivateKey(privateKey);
    const sign = await generateSign(params, privateKeyObj);
    params.sign = sign;
    
    console.log('获取用户信息请求参数:', params);
    
    // 发送请求到支付宝网关
    const gatewayUrl = env.ALIPAY_USE_SANDBOX === 'true' ? 
      'https://openapi-sandbox.dl.alipaydev.com/gateway.do' : 
      'https://openapi.alipay.com/gateway.do';
    const response = await fetch(gatewayUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8',
      },
      body: new URLSearchParams(params).toString()
    });
    
    if (!response.ok) {
      throw new Error(`支付宝API请求失败: ${response.status} ${response.statusText}`);
    }
    
    const result = await response.json();
    console.log('支付宝用户信息响应:', result);
    
    // 检查响应状态
    if (result.alipay_user_info_share_response) {
      const userInfoResponse = result.alipay_user_info_share_response;
      if (userInfoResponse.code === '10000') {
        return {
          code: '10000',
          nick_name: userInfoResponse.nick_name || '支付宝用户',
          avatar: userInfoResponse.avatar || '',
          province: userInfoResponse.province || '',
          city: userInfoResponse.city || '',
          gender: userInfoResponse.gender || 'M',
          user_type: userInfoResponse.user_type,
          is_certified: userInfoResponse.is_certified,
          is_student_certified: userInfoResponse.is_student_certified
        };
      } else {
        return {
          code: userInfoResponse.code,
          msg: userInfoResponse.msg,
          sub_code: userInfoResponse.sub_code,
          sub_msg: userInfoResponse.sub_msg
        };
      }
    } else {
      throw new Error('支付宝API响应格式错误');
    }
    
  } catch (error) {
    console.error('获取用户信息失败:', error);
    throw error;
  }
}

export { generateAlipayLoginUrl, getAlipayUserInfo, handleAlipayLogin, registerAlipayUser, checkEmailAvailability, sendRegistrationCaptcha, getAccessToken, getUserInfoWithToken, handleAlipayCallback, handleMacOSAlipayCallback };