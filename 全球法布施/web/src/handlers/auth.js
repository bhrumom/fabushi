import { jsonResponse } from '../utils/response.js';
import { createPasswordHash, verifyPassword, generateToken, verifyToken } from '../../auth-utils.js';
import { calculateTrialEndDate } from '../../stripe-config.js';

// 注册
export async function handleRegister(request, env, db) {
  const { username, email, password, verificationCode } = await request.json();
  
  if (!username || !email || !password || !verificationCode) {
    return jsonResponse({ error: '缺少必要字段' }, 400);
  }

  // 验证验证码（使用KV）
  const verifyData = await env.USERS_KV.get(`verify:${email.toLowerCase()}`);
  if (!verifyData) {
    return jsonResponse({ error: '验证码不存在或已过期' }, 400);
  }

  const { code, expiry } = JSON.parse(verifyData);
  if (Date.now() > expiry || verificationCode !== code) {
    return jsonResponse({ error: '验证码错误或已过期' }, 400);
  }

  // 检查用户是否存在
  const existingUser = await db.getUser(username);
  if (existingUser) {
    return jsonResponse({ error: '用户名已存在' }, 400);
  }

  const existingEmail = await db.getUserByEmail(email.toLowerCase());
  if (existingEmail) {
    return jsonResponse({ error: '该邮箱已被注册' }, 400);
  }

  // 创建用户
  const creds = await createPasswordHash(password);
  const trialEndDate = calculateTrialEndDate();

  await db.createUser({
    username,
    email: email.toLowerCase(),
    passwordHash: creds.passwordHash,
    salt: creds.salt,
    iterations: creds.iterations,
    algo: creds.algo,
    emailVerified: true,
    membershipType: 'trial',
    freeTrialEndDate: trialEndDate.toISOString(),
    createdAt: new Date().toISOString()
  });

  await env.USERS_KV.delete(`verify:${email.toLowerCase()}`);

  return jsonResponse({ message: '注册成功' }, 201);
}

// 登录
export async function handleLogin(request, env, db) {
  const { username: loginIdentifier, password } = await request.json();
  
  if (!loginIdentifier || !password) {
    return jsonResponse({ error: '用户名或邮箱和密码不能为空' }, 400);
  }

  let user;
  if (loginIdentifier.includes('@')) {
    user = await db.getUserByEmail(loginIdentifier.toLowerCase());
  } else {
    user = await db.getUser(loginIdentifier);
  }

  if (!user) {
    return jsonResponse({ error: '用户不存在' }, 401);
  }

  const ok = await verifyPassword(password, {
    passwordHash: user.password_hash,
    salt: user.salt,
    iterations: user.iterations,
    algo: user.algo
  });

  if (!ok) {
    return jsonResponse({ error: '密码错误' }, 401);
  }

  const token = await generateToken(user.username, env);
  return jsonResponse({ token, username: user.username });
}

// 获取用户信息
export async function handleGetUserInfo(request, env, db) {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return jsonResponse({ error: '未提供认证信息' }, 401);
  }

  const token = authHeader.substring(7);
  const tokenData = await verifyToken(token, env);
  if (!tokenData) {
    return jsonResponse({ error: '认证失败' }, 401);
  }

  const user = await db.getUser(tokenData.username);
  if (!user) {
    return jsonResponse({ error: '用户不存在' }, 404);
  }

  return jsonResponse({
    username: user.username,
    email: user.email,
    createdAt: user.created_at,
    emailVerified: user.email_verified === 1,
    membership: {
      type: user.membership_type,
      expiresAt: user.membership_expires_at
    }
  });
}
