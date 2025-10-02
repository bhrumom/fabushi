// 支付宝登录相关处理函数

import { generateToken, verifyToken, jsonResponse, verifyPassword, createPasswordHash } from './auth-utils.js';
import { importPrivateKey, importPublicKey, generateSign, verifySign } from './alipay-utils.js';

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
        user_id: '2088123456789012',
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
      throw new Error('支付宝授权失败: ' + (tokenResult?.msg || '未知错误'));
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
        nick_name: '支付宝用户',
        avatar: '',
        province: '',
        city: '',
        gender: 'M'
      };
    }
    
    const userInfo = userInfoResult;
    console.log('成功获取支付宝用户信息:', userInfo);
    
    return {
      user_id: user_id,
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
    const { alipayUserId, email, password, nickname, avatar } = await request.json();
    
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
    
    // 更新用户信息
    user.alipayUserId = alipayUserId;
    user.alipayNickname = nickname || '支付宝用户';
    user.alipayAvatar = avatar || '';
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
      return Response.redirect(new URL('/assets/login.html?error=missing_auth_code', request.url).toString(), 302);
    }
    
    // 验证state
    if (state) {
      const storedState = await env.USERS_KV.get(`alipay_state:${state}`);
      if (!storedState) {
        console.error('无效的state参数:', state);
        return Response.redirect(new URL('/assets/login.html?error=invalid_state', request.url).toString(), 302);
      }
      // 删除已使用的state
      await env.USERS_KV.delete(`alipay_state:${state}`);
    }
    
    // 获取支付宝用户信息
    const alipayUser = await getAlipayUserInfo(authCode, env);
    
    // 检查是否已有绑定账号
    const existingBinding = await env.USERS_KV.get(`alipay_binding:${alipayUser.user_id}`);
    
    if (existingBinding) {
      // 已有绑定，直接登录
      const userData = await env.USERS_KV.get(`user:${existingBinding}`);
      if (userData) {
        const user = JSON.parse(userData);
        const token = await generateToken(user.username, env);
        
        // 重定向到前端页面，带上token
        const redirectUrl = new URL('/assets/login.html', request.url);
        redirectUrl.searchParams.set('alipay_login_success', 'true');
        redirectUrl.searchParams.set('token', token);
        redirectUrl.searchParams.set('username', user.username);
        redirectUrl.searchParams.set('login_method', 'alipay');
        
        console.log('支付宝登录成功，重定向到:', redirectUrl.toString());
        return Response.redirect(redirectUrl.toString(), 302);
      }
    }
    
    // 新用户或未绑定，重定向到登录页面进行绑定或注册
    const redirectUrl = new URL('/assets/login.html', request.url);
    redirectUrl.searchParams.set('alipay_auth_code', authCode);
    redirectUrl.searchParams.set('alipay_user_id', alipayUser.user_id);
    redirectUrl.searchParams.set('alipay_nickname', alipayUser.nick_name || '');
    redirectUrl.searchParams.set('alipay_avatar', alipayUser.avatar || '');
    redirectUrl.searchParams.set('needs_binding', 'true');
    
    console.log('新用户或未绑定，重定向到绑定页面:', redirectUrl.toString());
    return Response.redirect(redirectUrl.toString(), 302);
    
  } catch (error) {
    console.error('支付宝回调处理失败:', error);
    return Response.redirect(new URL('/assets/login.html?error=callback_failed', request.url).toString(), 302);
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
          user_id: tokenResponse.user_id,
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
          nick_name: userInfoResponse.nick_name,
          avatar: userInfoResponse.avatar,
          province: userInfoResponse.province,
          city: userInfoResponse.city,
          gender: userInfoResponse.gender,
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

export { generateAlipayLoginUrl, getAlipayUserInfo, handleAlipayLogin, handleAlipayBind, handleAlipayRegister, getAccessToken, getUserInfoWithToken, handleAlipayCallback };