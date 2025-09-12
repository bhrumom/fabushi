import { EmailMessage } from 'cloudflare:email';
import { STRIPE_CONFIG, createStripeClient, checkMembershipStatus, calculateTrialEndDate } from './stripe-config.js';
// 管理员系统配置
const ADMIN_EMAIL = '1315518325@qq.com';
const ADMIN_PRICES = {
  'monthly': '0.01',
  'quarterly': '0.01',
  'yearly': '0.01'
};

// 兑换码类型配置
const REDEEM_CODE_TYPES = {
  'trial_7': {
    name: '7天试用',
    days: 7,
    type: 'trial'
  },
  'monthly': {
    name: '月度会员',
    days: 30,
    type: 'premium'
  },
  'quarterly': {
    name: '季度会员',
    days: 90,
    type: 'premium'
  },
  'yearly': {
    name: '年度会员',
    days: 365,
    type: 'premium'
  }
};

// 管理员权限检查
function isAdmin(email) {
  return email && email.toLowerCase() === ADMIN_EMAIL.toLowerCase();
}

// 兑换码生成器
function generateRedeemCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';
  for (let i = 0; i < 12; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

// Cloudflare Worker 认证系统 - 带邮箱验证码、忘记密码和Stripe支付功能
// 简化版本 - 无需外部依赖

// CORS 头配置
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, Range',
  'Content-Type': 'application/json'
};

// 工具函数
function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  });
}

function htmlResponse(html, status = 200) {
  return new Response(html, {
    status,
    headers: { 'Content-Type': 'text/html; charset=utf-8', ...corsHeaders }
  });
}

// Base64URL 工具
function base64UrlEncode(buffer) {
  let binary = '';
  const bytes = new Uint8Array(buffer);
  const len = bytes.byteLength;
  for (let i = 0; i < len; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function base64UrlDecodeToArray(base64url) {
  const base64 = base64url.replace(/-/g, '+').replace(/_/g, '/');
  const pad = base64.length % 4 === 2 ? '==' : base64.length % 4 === 3 ? '=' : '';
  const str = atob(base64 + pad);
  const bytes = new Uint8Array(str.length);
  for (let i = 0; i < str.length; i++) bytes[i] = str.charCodeAt(i);
  return bytes;
}

// 随机盐
function randomBytes(size = 16) {
  const array = new Uint8Array(size);
  crypto.getRandomValues(array);
  return array;
}

// PBKDF2 派生
async function derivePbkdf2(password, saltBytes, iterations = 100000) {
  const enc = new TextEncoder();
  const keyMaterial = await crypto.subtle.importKey(
    'raw',
    enc.encode(password),
    'PBKDF2',
    false,
    ['deriveBits']
  );
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', hash: 'SHA-256', salt: saltBytes, iterations },
    keyMaterial,
    256
  );
  return new Uint8Array(bits);
}

// 新的密码哈希：PBKDF2 + Salt（同时兼容旧版 SHA-256 存量用户）
async function createPasswordHash(password) {
  const salt = randomBytes(16);
  const iterations = 100000;
  const hashBytes = await derivePbkdf2(password, salt, iterations);
  return {
    passwordHash: base64UrlEncode(hashBytes),
    salt: base64UrlEncode(salt),
    iterations,
    algo: 'PBKDF2-SHA256'
  };
}

async function verifyPassword(password, user) {
  // 新版
  if (user && user.passwordHash && user.salt) {
    const saltBytes = base64UrlDecodeToArray(user.salt);
    const iterations = user.iterations || 100000;
    const hashBytes = await derivePbkdf2(password, saltBytes, iterations);
    const computed = base64UrlEncode(hashBytes);
    return computed === user.passwordHash;
  }
  // 兼容旧版（纯 SHA-256 十六进制），用于平滑迁移
  if (user && user.password) {
    const encoder = new TextEncoder();
    const data = encoder.encode(password);
    const hashBuffer = await crypto.subtle.digest('SHA-256', data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const hex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
    return hex === user.password;
  }
  return false;
}

// 如果用户为旧版哈希且验证通过，则升级为 PBKDF2
async function upgradePasswordIfNeeded(password, username, user, env) {
  if (user && user.password && (!user.passwordHash || !user.salt)) {
    const updated = { ...user };
    const { passwordHash, salt, iterations, algo } = await createPasswordHash(password);
    delete updated.password;
    updated.passwordHash = passwordHash;
    updated.salt = salt;
    updated.iterations = iterations;
    updated.algo = algo;
    await env.USERS_KV.put(`user:${username}`, JSON.stringify(updated));
    return updated;
  }
  return user;
}

// 正式 JWT（HMAC-SHA256）
async function generateToken(username, env) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const payload = {
    username,
    exp: Math.floor(Date.now() / 1000) + (7 * 24 * 60 * 60), // 7天有效期
    jti: crypto.randomUUID() // 增加一个唯一的ID，确保每次生成的token都不同
  };
  const enc = new TextEncoder();
  const secret = (env && (env.JWT_SECRET || (env.vars && env.vars.JWT_SECRET))) || 'dev-secret';

  const headerB64 = base64UrlEncode(enc.encode(JSON.stringify(header)));
  const payloadB64 = base64UrlEncode(enc.encode(JSON.stringify(payload)));
  const data = `${headerB64}.${payloadB64}`;

  const key = await crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(data));
  const sigB64 = base64UrlEncode(new Uint8Array(sig));
  return `${data}.${sigB64}`;
}

async function verifyToken(token, env) {
  try {
    const [h, p, s] = token.split('.');
    if (!h || !p || !s) return null;
    const enc = new TextEncoder();
    const secret = (env && (env.JWT_SECRET || (env.vars && env.vars.JWT_SECRET))) || 'dev-secret';
    const key = await crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['verify']);
    const ok = await crypto.subtle.verify('HMAC', key, base64UrlDecodeToArray(s), enc.encode(`${h}.${p}`));
    if (!ok) return null;
    const payloadJson = new TextDecoder().decode(base64UrlDecodeToArray(p));
    const payload = JSON.parse(payloadJson);
    if (!payload.exp || payload.exp < Math.floor(Date.now() / 1000)) return null;
    return { username: payload.username };
  } catch {
    return null;
  }
}

// 生成6位验证码
function generateVerificationCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// 模拟发送邮件（实际部署时可配置真实邮件服务）
// 发送邮件函数 - 使用更健壮的环境变量处理
async function sendEmail(to, subject, body, env) {
  console.log('开始发送邮件流程:', { to, subject });

  // 统一发件人 - 优先使用已验证的域名
  let fromEmail = "onboarding@resend.dev";  // 临时使用 Resend 测试域名，确保基本功能
  if (env && env.vars && env.vars.FROM_EMAIL) fromEmail = env.vars.FROM_EMAIL;
  else if (env && env.FROM_EMAIL) fromEmail = env.FROM_EMAIL;

  // 调试信息
  console.log('sendEmail 调试信息:', {
    to,
    subject,
    bodyLength: body ? body.length : 0,
    fromEmail,
    hasEnv: !!env,
    hasResendKey: !!(env && env.RESEND_API_KEY),
    resendKeyLength: env && env.RESEND_API_KEY ? env.RESEND_API_KEY.length : 'N/A',
    hasEmail: !!(env && env.EMAIL),
    hasMailChannels: !!(env && env.MAILCHANNELS_API_KEY),
    envVars: env && env.vars ? Object.keys(env.vars) : 'N/A',
    envKeys: env ? Object.keys(env) : 'N/A'
  });

  // 验证必要参数
  if (!to || !subject || !body) {
    console.error('邮件参数不完整:', { to: !!to, subject: !!subject, body: !!body });
    return { ok: false, error: '邮件参数不完整' };
  }

  // 1) 首选 Resend（需要域名验证，但更稳定）
  // 注意：secrets 直接在 env 对象上，不在 env.vars 中
  if (env && env.RESEND_API_KEY) {
    try {
      const apiKey = env.RESEND_API_KEY;
      console.log('尝试使用 Resend 发送邮件:', { to, fromEmail, apiKeyLength: apiKey.length });

      const payload = {
        from: fromEmail,
        to: [to], // Resend 要求数组格式
        subject,
        text: body,
        html: `<div style="font-family: 'Microsoft YaHei', sans-serif; line-height: 1.6; padding: 20px; background-color: #f9f9f9; border-radius: 8px;">${body.replace(/\n/g, '<br>')}</div>`
      };

      console.log('Resend 请求载荷:', JSON.stringify(payload, null, 2));

      const resp = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
      });

      console.log('Resend API 响应状态:', resp.status, resp.statusText);

      if (resp.ok) {
        const respData = await resp.json();
        console.log('邮件发送成功(Resend):', { to, subject, respData });
        return { ok: true, service: 'Resend', data: respData };
      }

      const errBody = await resp.text();
      console.error('Resend 发送失败:', resp.status, errBody);

      // 如果是认证错误，不继续尝试其他服务
      if (resp.status === 401 || resp.status === 403) {
        return { ok: false, error: `Resend认证失败: ${errBody}` };
      }

      // 其他错误继续尝试下一个服务
    } catch (e) {
      console.error('Resend 调用异常:', String(e && (e.message || e)));
      console.error('Resend 异常堆栈:', e.stack);
    }
  } else {
    console.log('Resend API Key 未找到，跳过 Resend 服务');
  }

  // 2) 回退 Cloudflare SendEmail（已绑定，无域名限制）
  if (env && env.EMAIL) {
    try {
      console.log('尝试使用 Cloudflare SendEmail 发送邮件:', { to, fromEmail });

      const message = new EmailMessage(fromEmail, to, subject, body);
      await env.EMAIL.send(message);
      console.log('邮件发送成功(Cloudflare):', { to, subject });
      return { ok: true, service: 'Cloudflare' };
    } catch (e) {
      const errText = String(e && (e.message || e));
      console.error('Cloudflare 邮件发送失败:', errText);
      console.error('Cloudflare 异常堆栈:', e.stack);
      // 继续尝试其他服务
    }
  } else {
    console.log('Cloudflare EMAIL 绑定未找到，跳过 Cloudflare 服务');
  }

  // 3) 最后回退 MailChannels（需要 MAILCHANNELS_API_KEY）
  if (env && env.MAILCHANNELS_API_KEY) {
    try {
      const mcKey = env.MAILCHANNELS_API_KEY;
      console.log('尝试使用 MailChannels 发送邮件:', { to, fromEmail, keyLength: mcKey.length });

      const payload = {
        personalizations: [{ to: [{ email: to }] }],
        from: { email: fromEmail, name: 'Fabushi' },
        subject,
        content: [
          { type: 'text/plain; charset=utf-8', value: body },
          { type: 'text/html; charset=utf-8', value: `<div style="font-family: 'Microsoft YaHei', sans-serif; line-height: 1.6;">${body.replace(/\n/g, '<br>')}</div>` }
        ]
      };

      // 尝试两种常见鉴权头（不同计划可能略有差异）
      const authHeadersList = [
        { 'Authorization': `Bearer ${mcKey}`, 'Content-Type': 'application/json' },
        { 'X-Api-Key': mcKey, 'Content-Type': 'application/json' }
      ];

      for (const headers of authHeadersList) {
        try {
          console.log('尝试 MailChannels 认证方式:', Object.keys(headers));
          const resp = await fetch('https://api.mailchannels.net/tx/v1/send', {
            method: 'POST',
            headers,
            body: JSON.stringify(payload)
          });

          console.log('MailChannels API 响应状态:', resp.status, resp.statusText);

          if (resp.status === 202 || resp.status === 200) {
            const respData = await resp.text();
            console.log('邮件发送成功(MailChannels):', { to, subject, respData });
            return { ok: true, service: 'MailChannels' };
          }

          const errText = await resp.text();
          console.error('MailChannels 发送失败:', resp.status, errText);

          // 若 401/403 则尝试下一种头；其他错误直接跳出循环
          if (!(resp.status === 401 || resp.status === 403)) break;
        } catch (e) {
          console.error('MailChannels 调用异常:', String(e && (e.message || e)));
          console.error('MailChannels 异常堆栈:', e.stack);
        }
      }
    } catch (e) {
      console.error('MailChannels 整体异常:', String(e && (e.message || e)));
    }
  } else {
    console.log('MailChannels API Key 未找到，跳过 MailChannels 服务');
  }

  console.error('所有邮件服务都失败了');
  return { ok: false, error: '所有邮箱服务都不可用，请检查 RESEND_API_KEY、EMAIL 或 MAILCHANNELS_API_KEY 配置' };
}

// 发送邮箱验证码
async function handleSendVerificationCode(request, env, ctx) {
  try {
    console.log('开始处理验证码发送请求...');

    // 检查请求体
    let requestBody;
    try {
      requestBody = await request.json();
      console.log('请求体解析成功:', requestBody);
    } catch (parseError) {
      console.error('请求体解析失败:', parseError);
      return jsonResponse({ error: '请求格式错误' }, 400);
    }

    let { email, type = 'register' } = requestBody;
    console.log('提取参数:', { email, type });

    if (!email) {
      console.error('邮箱地址为空');
      return jsonResponse({ error: '邮箱地址不能为空' }, 400);
    }

    email = String(email).trim().toLowerCase();
    console.log('处理后的邮箱:', email);

    // 验证邮箱格式
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      console.error('邮箱格式无效:', email);
      return jsonResponse({ error: '邮箱格式不正确' }, 400);
    }

    // 检查环境变量
    console.log('检查环境变量:', {
      hasEnv: !!env,
      hasUsersKV: !!(env && env.USERS_KV),
      hasResendKey: !!(env && env.RESEND_API_KEY),
      hasEmail: !!(env && env.EMAIL)
    });

    if (!env || !env.USERS_KV) {
      console.error('环境变量配置错误');
      return jsonResponse({ error: '服务配置错误' }, 500);
    }

    // 简单频率限制：60 秒内同一邮箱仅允许发送一次
    const rateKey = `rate:verify:${email}`;
    console.log('检查频率限制:', rateKey);

    try {
      const recent = await env.USERS_KV.get(rateKey);
      if (recent) {
        console.log('频率限制触发:', email);
        return jsonResponse({ error: '请求过于频繁，请稍后再试' }, 429);
      }
    } catch (kvError) {
      console.error('KV存储访问错误:', kvError);
      return jsonResponse({ error: '存储服务错误' }, 500);
    }

    // 检查邮箱是否已注册（注册时）
    if (type === 'register') {
      console.log('检查邮箱是否已注册:', email);
      try {
        const exists = await env.USERS_KV.get(`email_to_username:${email}`);
        if (exists) {
          console.log('邮箱已被注册:', email);
          return jsonResponse({ error: '该邮箱已被注册' }, 400);
        }
      } catch (kvError) {
        console.error('检查邮箱注册状态时出错:', kvError);
        // 继续执行，不阻断流程
      }
    }

    // 检查邮箱是否存在（忘记密码时）
    if (type === 'forgot') {
      console.log('检查邮箱是否存在:', email);
      try {
        let exists = await env.USERS_KV.get(`email_to_username:${email}`);
        // 兼容旧数据：尝试回填映射
        if (!exists) {
          console.log('尝试回填邮箱映射...');
          const users = await env.USERS_KV.list({ prefix: 'user:' });
          for (const k of users.keys) {
            const ujson = await env.USERS_KV.get(k.name);
            if (!ujson) continue;
            const u = JSON.parse(ujson);
            if (u.email === email) {
              await env.USERS_KV.put(`email_to_username:${email}`, u.username);
              exists = u.username;
              break;
            }
          }
        }
        if (!exists) {
          console.log('邮箱未注册:', email);
          return jsonResponse({ error: '该邮箱未注册' }, 400);
        }
      } catch (kvError) {
        console.error('检查邮箱存在状态时出错:', kvError);
        return jsonResponse({ error: '存储服务错误' }, 500);
      }
    }

    const code = generateVerificationCode();
    const expiry = Date.now() + 10 * 60 * 1000; // 10分钟有效期
    console.log('生成验证码:', { code, expiry });

    // 存储验证码
    try {
      await env.USERS_KV.put(`verify:${email}`, JSON.stringify({ code, expiry, type }));
      await env.USERS_KV.put(rateKey, '1', { expirationTtl: 60 });
      console.log('验证码存储成功');
    } catch (kvError) {
      console.error('验证码存储失败:', kvError);
      return jsonResponse({ error: '存储服务错误' }, 500);
    }

    // 使用 ctx.waitUntil 在后台发送邮件，避免请求超时
    const subject = type === 'register' ? '注册验证码' : '密码重置验证码';
    const body = `您的验证码是：${code}\n有效期10分钟，请尽快使用。\n如非本人操作，请忽略此邮件。`;

    console.log('开始将邮件任务推入后台...');
    ctx.waitUntil(
      sendEmail(email, subject, body, env)
        .then(sent => {
          if (!sent.ok) {
            console.error(`后台邮件发送失败 to ${email}:`, sent.error);
          } else {
            console.log(`后台邮件发送成功 to ${email} via ${sent.service || 'N/A'}`);
          }
        })
        .catch(error => {
          console.error(`后台邮件发送异常 to ${email}:`, error);
        })
    );

    console.log('验证码发送请求已接受，立即返回响应。');
    return jsonResponse({ message: '验证码已发送，请查收邮件。' });

  } catch (error) {
    console.error('发送验证码失败，详细错误:', error);
    console.error('错误堆栈:', error.stack);
    return jsonResponse({ error: `发送验证码失败: ${error.message}` }, 500);
  }
}

// 验证邮箱验证码
async function handleVerifyCode(request, env) {
  try {
    console.log('开始验证验证码...');

    let { email, code } = await request.json();
    console.log('验证码验证请求:', { email, code });

    if (!email || !code) {
      console.error('验证码验证缺少字段:', { email: !!email, code: !!code });
      return jsonResponse({ error: '邮箱和验证码不能为空' }, 400);
    }
    email = String(email).trim().toLowerCase();

    console.log('从KV存储获取验证码数据...');
    const verifyData = await env.USERS_KV.get(`verify:${email}`);
    console.log('验证码数据状态:', { email, hasVerifyData: !!verifyData });

    if (!verifyData) {
      console.error('验证码不存在或已过期:', email);
      return jsonResponse({ error: '验证码不存在或已过期' }, 400);
    }

    const { code: storedCode, expiry } = JSON.parse(verifyData);
    console.log('解析验证码数据:', { storedCode, expiry, currentTime: Date.now() });

    if (Date.now() > expiry) {
      console.error('验证码已过期:', { email, expiry, currentTime: Date.now() });
      await env.USERS_KV.put(`verify:${email}`, null);
      return jsonResponse({ error: '验证码已过期' }, 400);
    }

    if (code !== storedCode) {
      console.error('验证码不匹配:', { email, providedCode: code, storedCode });
      return jsonResponse({ error: '验证码错误' }, 400);
    }

    // 验证通过，标记为已验证
    console.log('验证码验证通过，标记邮箱为已验证...');
    await env.USERS_KV.put(`verified:${email}`, 'true', { expirationTtl: 30 * 60 }); // 30分钟有效

    console.log('验证码验证成功:', email);
    return jsonResponse({ message: '验证码正确' });
  } catch (error) {
    console.error('验证验证码失败，详细错误:', error);
    console.error('错误堆栈:', error.stack);
    return jsonResponse({ error: `验证验证码失败: ${error.message}` }, 500);
  }
}

// 更新注册处理函数
async function handleRegister(request, env) {
  try {
    console.log('开始处理注册请求...');

    let { username, email, password, verificationCode } = await request.json();
    console.log('注册请求数据:', { username, email, passwordLength: password?.length, verificationCode });

    if (!username || !email || !password || !verificationCode) {
      const missingFields = [];
      if (!username) missingFields.push('username');
      if (!email) missingFields.push('email');
      if (!password) missingFields.push('password');
      if (!verificationCode) missingFields.push('verificationCode');
      console.error('缺少必要字段:', missingFields);
      return jsonResponse({ error: `缺少必要字段: ${missingFields.join(', ')}` }, 400);
    }

    username = String(username).trim();
    email = String(email).trim().toLowerCase();
    console.log('处理后的数据:', { username, email, passwordLength: password.length, verificationCode });

    // 用户名校验：3-20位，字母数字下划线
    if (!/^[a-zA-Z0-9_]{3,20}$/.test(username)) {
      console.error('用户名格式无效:', username);
      return jsonResponse({ error: '用户名需为3-20位字母、数字或下划线' }, 400);
    }

    // 密码强度验证
    if (password.length < 8) {
      console.error('密码长度不足:', password.length);
      return jsonResponse({ error: '密码长度至少8个字符' }, 400);
    }
    if (!/[A-Z]/.test(password)) {
      console.error('密码缺少大写字母');
      return jsonResponse({ error: '密码必须包含大写字母' }, 400);
    }
    if (!/[a-z]/.test(password)) {
      console.error('密码缺少小写字母');
      return jsonResponse({ error: '密码必须包含小写字母' }, 400);
    }
    if (!/\d/.test(password)) {
      console.error('密码缺少数字');
      return jsonResponse({ error: '密码必须包含数字' }, 400);
    }

    // 在注册函数内部直接验证验证码
    console.log('正在验证验证码...');
    const verifyData = await env.USERS_KV.get(`verify:${email}`);
    if (!verifyData) {
      console.error('验证码不存在或已过期:', email);
      return jsonResponse({ error: '验证码不存在或已过期，请重新发送' }, 400);
    }

    const { code: storedCode, expiry } = JSON.parse(verifyData);
    if (Date.now() > expiry) {
      console.error('验证码已过期:', email);
      await env.USERS_KV.delete(`verify:${email}`);
      return jsonResponse({ error: '验证码已过期，请重新发送' }, 400);
    }

    if (verificationCode !== storedCode) {
      console.error('验证码不匹配:', { email, providedCode: verificationCode, storedCode });
      return jsonResponse({ error: '验证码错误' }, 400);
    }

    console.log('检查用户名是否已存在...');
    const existingUser = await env.USERS_KV.get(`user:${username}`);
    if (existingUser) {
      console.error('用户名已存在:', username);
      return jsonResponse({ error: '用户名已存在' }, 400);
    }

    // 二次校验邮箱唯一（防止竞态）
    console.log('检查邮箱是否已被注册...');
    const emailMapped = await env.USERS_KV.get(`email_to_username:${email}`);
    if (emailMapped) {
      console.error('邮箱已被注册:', { email, existingUsername: emailMapped });
      return jsonResponse({ error: '该邮箱已被注册' }, 400);
    }

    console.log('创建密码哈希...');
    const creds = await createPasswordHash(password);

    // 为新用户设置3天免费试用
    const trialEndDate = calculateTrialEndDate();

    const userData = {
      username,
      email,
      passwordHash: creds.passwordHash,
      salt: creds.salt,
      iterations: creds.iterations,
      algo: creds.algo,
      createdAt: new Date().toISOString(),
      emailVerified: true,
      // 会员相关字段
      freeTrialEndDate: trialEndDate.toISOString(),
      membershipType: 'trial',
      stripeCustomerId: null,
      subscriptionId: null
    };

    console.log('保存用户数据到KV存储...');
    await env.USERS_KV.put(`user:${username}`, JSON.stringify(userData));
    await env.USERS_KV.put(`email_to_username:${email}`, username);

    // 清理验证码
    console.log('清理验证码数据...');
    await env.USERS_KV.delete(`verify:${email}`);
    await env.USERS_KV.delete(`verified:${email}`); // 即使不再使用 verified 键，也清理一下以防万一

    console.log('注册成功:', username);
    return jsonResponse({ message: '注册成功' }, 201);
  } catch (error) {
    console.error('注册失败，详细错误:', error);
    console.error('错误堆栈:', error.stack);
    return jsonResponse({ error: `注册失败: ${error.message}` }, 500);
  }
}

// 忘记密码请求
async function handleForgotPassword(request, env) {
  try {
    let { email } = await request.json();

    if (!email) {
      return jsonResponse({ error: '邮箱地址不能为空' }, 400);
    }
    email = String(email).trim().toLowerCase();

    // 查找用户
    let username = await env.USERS_KV.get(`email_to_username:${email}`);
    if (!username) {
      // 兼容旧数据：回填映射
      const users = await env.USERS_KV.list({ prefix: 'user:' });
      for (const k of users.keys) {
        const ujson = await env.USERS_KV.get(k.name);
        if (!ujson) continue;
        const u = JSON.parse(ujson);
        if (u.email === email) {
          username = u.username;
          await env.USERS_KV.put(`email_to_username:${email}`, username);
          break;
        }
      }
    }

    if (!username) {
      return jsonResponse({ error: '该邮箱未注册' }, 400);
    }

    // 生成重置令牌
    const resetToken = await generateToken(username, env);
    await env.USERS_KV.put(`reset:${email}`, resetToken, { expirationTtl: 30 * 60 }); // 30分钟有效

    // 发送重置邮件
    const resetUrl = `${new URL(request.url).origin}/reset-password.html?token=${resetToken}&email=${email}`;
    const subject = '密码重置请求';
    const body = `点击以下链接重置您的密码：\n${resetUrl}\n链接30分钟内有效。\n如非本人操作，请忽略此邮件。`;

    await sendEmail(email, subject, body, env);

    return jsonResponse({ message: '重置邮件已发送' });
  } catch (error) {
    console.error('忘记密码请求失败:', error);
    return jsonResponse({ error: '请求失败' }, 500);
  }
}

// 重置密码
async function handleResetPassword(request, env) {
  try {
    let { email, token, newPassword } = await request.json();

    if (!email || !token || !newPassword) {
      return jsonResponse({ error: '缺少必要字段' }, 400);
    }
    email = String(email).trim().toLowerCase();

    // 密码强度验证
    if (newPassword.length < 8) {
      return jsonResponse({ error: '密码长度至少8个字符' }, 400);
    }
    if (!/[A-Z]/.test(newPassword)) {
      return jsonResponse({ error: '密码必须包含大写字母' }, 400);
    }
    if (!/[a-z]/.test(newPassword)) {
      return jsonResponse({ error: '密码必须包含小写字母' }, 400);
    }
    if (!/\d/.test(newPassword)) {
      return jsonResponse({ error: '密码必须包含数字' }, 400);
    }

    // 验证重置令牌
    const storedToken = await env.USERS_KV.get(`reset:${email}`);
    if (!storedToken || storedToken !== token) {
      return jsonResponse({ error: '重置链接无效或已过期' }, 400);
    }

    // 查找用户
    let username = await env.USERS_KV.get(`email_to_username:${email}`);
    if (!username) {
      // 兼容旧数据：回填映射
      const users = await env.USERS_KV.list({ prefix: 'user:' });
      for (const k of users.keys) {
        const ujson = await env.USERS_KV.get(k.name);
        if (!ujson) continue;
        const u = JSON.parse(ujson);
        if (u.email === email) {
          username = u.username;
          await env.USERS_KV.put(`email_to_username:${email}`, username);
          break;
        }
      }
    }

    if (!username) {
      return jsonResponse({ error: '用户不存在' }, 400);
    }

    // 更新密码
    const userData = await env.USERS_KV.get(`user:${username}`);
    const user = JSON.parse(userData);
    const creds = await createPasswordHash(newPassword);
    user.passwordHash = creds.passwordHash;
    user.salt = creds.salt;
    user.iterations = creds.iterations;
    user.algo = creds.algo;
    delete user.password; // 清理旧字段
    await env.USERS_KV.put(`user:${username}`, JSON.stringify(user));

    // 清理重置令牌
    await env.USERS_KV.delete(`reset:${email}`);

    return jsonResponse({ message: '密码重置成功' });
  } catch (error) {
    console.error('重置密码失败:', error);
    return jsonResponse({ error: '重置密码失败' }, 500);
  }
}

// 更新登录处理函数（保持不变）
async function handleLogin(request, env) {
  try {
    const { username, password } = await request.json();

    if (!username || !password) {
      return jsonResponse({ error: '用户名和密码不能为空' }, 400);
    }

    const userData = await env.USERS_KV.get(`user:${username}`);
    if (!userData) {
      return jsonResponse({ error: '用户不存在' }, 401);
    }

    let user = JSON.parse(userData);
    const ok = await verifyPassword(password, user);
    if (!ok) {
      return jsonResponse({ error: '密码错误' }, 401);
    }
    // 旧用户密码平滑升级
    user = await upgradePasswordIfNeeded(password, username, user, env);

    const token = await generateToken(username, env);
    return jsonResponse({ token, username });
  } catch (error) {
    return jsonResponse({ error: '登录失败' }, 500);
  }
}

// 保持不变的处理函数
async function handleVerify(request, env) {
  try {
    const authHeader = request.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return jsonResponse({ error: '未提供认证信息' }, 401);
    }

    const token = authHeader.substring(7);
    const isValid = await verifyToken(token, env);

    if (!isValid) {
      return jsonResponse({ error: '认证失败' }, 401);
    }

    return jsonResponse({ username: isValid.username });
  } catch (error) {
    return jsonResponse({ error: '验证失败' }, 500);
  }
}

async function handleLogout(request, env) {
  return jsonResponse({ message: '登出成功' });
}

// 微信公众号登录相关处理函数

// 微信公众号配置
const WECHAT_CONFIG = {
  APP_ID: 'your_wechat_app_id', // 需要在环境变量中设置
  APP_SECRET: 'your_wechat_app_secret', // 需要在环境变量中设置
  REDIRECT_URI: 'https://your-domain.com/wechat-callback.html', // 回调地址
  SCOPE: 'snsapi_userinfo' // 授权范围
};

// 生成微信登录URL
async function generateWechatLoginUrl(env) {
  const state = crypto.randomUUID();
  const appId = env.WECHAT_APP_ID || WECHAT_CONFIG.APP_ID;
  const redirectUri = encodeURIComponent(env.WECHAT_REDIRECT_URI || WECHAT_CONFIG.REDIRECT_URI);
  
  const authUrl = `https://open.weixin.qq.com/connect/oauth2/authorize?appid=${appId}&redirect_uri=${redirectUri}&response_type=code&scope=${WECHAT_CONFIG.SCOPE}&state=${state}#wechat_redirect`;
  
  // 存储state用于验证
  await env.USERS_KV.put(`wechat_state:${state}`, 'valid', { expirationTtl: 600 }); // 10分钟有效
  
  return { authUrl, state };
}

// 通过微信授权码获取用户信息
async function getWechatUserInfo(code, env) {
  const appId = env.WECHAT_APP_ID || WECHAT_CONFIG.APP_ID;
  const appSecret = env.WECHAT_APP_SECRET || WECHAT_CONFIG.APP_SECRET;
  
  try {
    // 1. 获取access_token
    const tokenUrl = `https://api.weixin.qq.com/sns/oauth2/access_token?appid=${appId}&secret=${appSecret}&code=${code}&grant_type=authorization_code`;
    const tokenResponse = await fetch(tokenUrl);
    const tokenData = await tokenResponse.json();
    
    if (tokenData.errcode) {
      throw new Error(`获取access_token失败: ${tokenData.errmsg}`);
    }
    
    const { access_token, openid } = tokenData;
    
    // 2. 获取用户信息
    const userInfoUrl = `https://api.weixin.qq.com/sns/userinfo?access_token=${access_token}&openid=${openid}&lang=zh_CN`;
    const userInfoResponse = await fetch(userInfoUrl);
    const userInfo = await userInfoResponse.json();
    
    if (userInfo.errcode) {
      throw new Error(`获取用户信息失败: ${userInfo.errmsg}`);
    }
    
    return {
      openid: userInfo.openid,
      nickname: userInfo.nickname,
      headimgurl: userInfo.headimgurl,
      sex: userInfo.sex,
      city: userInfo.city,
      province: userInfo.province,
      country: userInfo.country,
      unionid: userInfo.unionid
    };
  } catch (error) {
    console.error('获取微信用户信息失败:', error);
    throw error;
  }
}

// 处理微信登录
async function handleWechatLogin(request, env) {
  try {
    const { code, state } = await request.json();
    
    if (!code) {
      return jsonResponse({ error: '缺少授权码' }, 400);
    }
    
    // 验证state
    if (state) {
      const storedState = await env.USERS_KV.get(`wechat_state:${state}`);
      if (!storedState) {
        return jsonResponse({ error: '无效的state参数' }, 400);
      }
      // 删除已使用的state
      await env.USERS_KV.delete(`wechat_state:${state}`);
    }
    
    // 获取微信用户信息
    const wechatUser = await getWechatUserInfo(code, env);
    
    // 检查是否已有绑定账号
    const existingBinding = await env.USERS_KV.get(`wechat_binding:${wechatUser.openid}`);
    
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
          loginMethod: 'wechat'
        });
      }
    }
    
    // 新用户或未绑定，返回用户信息供前端处理
    return jsonResponse({
      wechatUser,
      isNewUser: true,
      needsBinding: true
    });
    
  } catch (error) {
    console.error('微信登录失败:', error);
    return jsonResponse({ error: '微信登录失败: ' + error.message }, 500);
  }
}

// 绑定微信账号到现有邮箱账号
async function handleWechatBind(request, env) {
  try {
    const { openid, email, password } = await request.json();
    
    if (!openid || !email || !password) {
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
    
    // 检查是否已有其他微信账号绑定
    const existingBinding = await env.USERS_KV.get(`wechat_binding:${openid}`);
    if (existingBinding && existingBinding !== username) {
      return jsonResponse({ error: '该微信账号已绑定其他用户' }, 400);
    }
    
    // 检查用户是否已绑定其他微信账号
    const userWechatBinding = await env.USERS_KV.get(`user_wechat:${username}`);
    if (userWechatBinding) {
      return jsonResponse({ error: '该账号已绑定其他微信' }, 400);
    }
    
    // 建立绑定关系
    await env.USERS_KV.put(`wechat_binding:${openid}`, username);
    await env.USERS_KV.put(`user_wechat:${username}`, openid);
    
    // 更新用户信息，添加微信绑定信息
    user.wechatOpenid = openid;
    user.wechatBoundAt = new Date().toISOString();
    await env.USERS_KV.put(`user:${username}`, JSON.stringify(user));
    
    const token = await generateToken(username, env);
    return jsonResponse({ 
      token, 
      username,
      message: '微信账号绑定成功'
    });
    
  } catch (error) {
    console.error('微信绑定失败:', error);
    return jsonResponse({ error: '微信绑定失败: ' + error.message }, 500);
  }
}

// 创建新用户并绑定微信（邮箱可选）
async function handleWechatRegister(request, env) {
  try {
    const { openid, nickname, headimgurl, username, email, password } = await request.json();
    
    if (!openid || !username || !password) {
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
    
    // 检查微信是否已绑定
    const existingBinding = await env.USERS_KV.get(`wechat_binding:${openid}`);
    if (existingBinding) {
      return jsonResponse({ error: '该微信账号已绑定其他用户' }, 400);
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
      // 微信相关字段
      wechatOpenid: openid,
      wechatNickname: nickname,
      wechatHeadimgurl: headimgurl,
      wechatBoundAt: new Date().toISOString(),
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
    
    // 建立微信绑定关系
    await env.USERS_KV.put(`wechat_binding:${openid}`, username);
    await env.USERS_KV.put(`user_wechat:${username}`, openid);
    
    const token = await generateToken(username, env);
    return jsonResponse({ 
      token, 
      username,
      message: '注册成功，微信账号已绑定'
    }, 201);
    
  } catch (error) {
    console.error('微信注册失败:', error);
    return jsonResponse({ error: '微信注册失败: ' + error.message }, 500);
  }
}

// 解绑微信账号
async function handleWechatUnbind(request, env) {
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
    if (!user.wechatOpenid) {
      return jsonResponse({ error: '该账号未绑定微信' }, 400);
    }
    
    // 删除绑定关系
    await env.USERS_KV.delete(`wechat_binding:${user.wechatOpenid}`);
    await env.USERS_KV.delete(`user_wechat:${tokenData.username}`);
    
    // 更新用户信息
    delete user.wechatOpenid;
    delete user.wechatNickname;
    delete user.wechatHeadimgurl;
    delete user.wechatBoundAt;
    await env.USERS_KV.put(`user:${tokenData.username}`, JSON.stringify(user));
    
    return jsonResponse({ message: '微信账号解绑成功' });
    
  } catch (error) {
    console.error('微信解绑失败:', error);
    return jsonResponse({ error: '微信解绑失败: ' + error.message }, 500);
  }
}

// 获取微信登录URL
async function handleGetWechatLoginUrl(request, env) {
  try {
    const { authUrl, state } = await generateWechatLoginUrl(env);
    return jsonResponse({ authUrl, state });
  } catch (error) {
    console.error('生成微信登录URL失败:', error);
    return jsonResponse({ error: '生成微信登录URL失败: ' + error.message }, 500);
  }
}

// 获取用户详细信息
async function handleGetUserInfo(request, env) {
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
    
    // 返回用户信息（包含微信绑定信息）
    return jsonResponse({
      username: user.username,
      email: user.email,
      wechatOpenid: user.wechatOpenid || null,
      wechatNickname: user.wechatNickname || null,
      wechatHeadimgurl: user.wechatHeadimgurl || null,
      wechatBoundAt: user.wechatBoundAt || null,
      createdAt: user.createdAt,
      emailVerified: user.emailVerified
    });

  } catch (error) {
    console.error('获取用户信息失败:', error);
    return jsonResponse({ error: '获取用户信息失败: ' + error.message }, 500);
  }
}

// 绑定邮箱（需要登录，邮箱验证码校验）
async function handleBindEmail(request, env) {
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

    const { email, verificationCode } = await request.json();
    if (!email || !verificationCode) {
      return jsonResponse({ error: '邮箱与验证码不能为空' }, 400);
    }

    const normalizedEmail = String(email).trim().toLowerCase();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(normalizedEmail)) {
      return jsonResponse({ error: '邮箱格式不正确' }, 400);
    }

    // 检查邮箱是否已被占用
    const existing = await env.USERS_KV.get(`email_to_username:${normalizedEmail}`);
    if (existing) {
      return jsonResponse({ error: '该邮箱已被其他账号绑定' }, 400);
    }

    // 验证验证码
    const verifyDataStr = await env.USERS_KV.get(`verify:${normalizedEmail}`);
    if (!verifyDataStr) {
      return jsonResponse({ error: '验证码不存在或已过期' }, 400);
    }
    const { code: storedCode, expiry } = JSON.parse(verifyDataStr);
    if (Date.now() > expiry) {
      await env.USERS_KV.delete(`verify:${normalizedEmail}`);
      return jsonResponse({ error: '验证码已过期' }, 400);
    }
    if (verificationCode !== storedCode) {
      return jsonResponse({ error: '验证码错误' }, 400);
    }

    // 获取并更新用户
    const userKey = `user:${tokenData.username}`;
    const userStr = await env.USERS_KV.get(userKey);
    if (!userStr) {
      return jsonResponse({ error: '用户不存在' }, 404);
    }
    const user = JSON.parse(userStr);

    // 若用户已有邮箱映射，先清除旧映射（避免更换邮箱残留）
    if (user.email) {
      const oldEmail = String(user.email).trim().toLowerCase();
      if (oldEmail) {
        await env.USERS_KV.delete(`email_to_username:${oldEmail}`);
      }
    }

    user.email = normalizedEmail;
    user.emailVerified = true;

    await env.USERS_KV.put(userKey, JSON.stringify(user));
    await env.USERS_KV.put(`email_to_username:${normalizedEmail}`, tokenData.username);

    // 清理验证码记录
    await env.USERS_KV.delete(`verify:${normalizedEmail}`);

    return jsonResponse({ message: '邮箱绑定成功', email: normalizedEmail });
  } catch (error) {
    console.error('绑定邮箱失败:', error);
    return jsonResponse({ error: '绑定邮箱失败: ' + error.message }, 500);
  }
}

// 管理员系统处理函数

// 检查用户是否为管理员
async function handleCheckAdminStatus(request, env) {
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
    const adminStatus = isAdmin(user.email);

    return jsonResponse({
      isAdmin: adminStatus,
      email: user.email,
      username: user.username
    });

  } catch (error) {
    console.error('检查管理员状态失败:', error);
    return jsonResponse({ error: '检查管理员状态失败' }, 500);
  }
}

// 生成兑换码
async function handleCreateRedeemCode(request, env) {
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

    // 获取用户信息检查管理员权限
    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: '用户不存在' }, 404);
    }

    const user = JSON.parse(userData);
    if (!isAdmin(user.email)) {
      return jsonResponse({ error: '权限不足，仅管理员可生成兑换码' }, 403);
    }

    const { type, quantity = 1, description = '' } = await request.json();

    if (!REDEEM_CODE_TYPES[type]) {
      return jsonResponse({ error: '无效的兑换码类型' }, 400);
    }

    if (quantity < 1 || quantity > 100) {
      return jsonResponse({ error: '兑换码数量必须在1-100之间' }, 400);
    }

    const codes = [];
    const codeType = REDEEM_CODE_TYPES[type];

    for (let i = 0; i < quantity; i++) {
      const code = generateRedeemCode();
      const codeData = {
        code,
        type: codeType.type,
        days: codeType.days,
        name: codeType.name,
        description,
        createdBy: tokenData.username,
        createdAt: new Date().toISOString(),
        used: false,
        usedBy: null,
        usedAt: null
      };

      await env.REDEEM_CODES_KV.put(`code:${code}`, JSON.stringify(codeData));
      codes.push(code);
    }

    return jsonResponse({
      message: `成功生成${quantity}个兑换码`,
      codes,
      type: codeType.name
    });

  } catch (error) {
    console.error('生成兑换码失败:', error);
    return jsonResponse({ error: '生成兑换码失败' }, 500);
  }
}

// 获取用户购买记录
async function handleGetPurchaseHistory(request, env) {
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

    const purchases = await env.USERS_KV.get(`purchases:${tokenData.username}`);
    const purchaseHistory = purchases ? JSON.parse(purchases) : [];

    return jsonResponse({
      purchases: purchaseHistory,
      total: purchaseHistory.length
    });

  } catch (error) {
    console.error('获取购买记录失败:', error);
    return jsonResponse({ error: '获取购买记录失败' }, 500);
  }
}

// 获取用户兑换记录
async function handleGetRedeemHistory(request, env) {
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

    const redeems = await env.USERS_KV.get(`redeems:${tokenData.username}`);
    const redeemHistory = redeems ? JSON.parse(redeems) : [];

    return jsonResponse({
      redeems: redeemHistory,
      total: redeemHistory.length
    });

  } catch (error) {
    console.error('获取兑换记录失败:', error);
    return jsonResponse({ error: '获取兑换记录失败' }, 500);
  }
}

// 查询兑换码列表
async function handleListRedeemCodes(request, env) {
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

    // 检查管理员权限
    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: '用户不存在' }, 404);
    }

    const user = JSON.parse(userData);
    if (!isAdmin(user.email)) {
      return jsonResponse({ error: '权限不足，仅管理员可查看兑换码' }, 403);
    }

    const url = new URL(request.url);
    const page = parseInt(url.searchParams.get('page') || '1');
    const limit = parseInt(url.searchParams.get('limit') || '20');
    const status = url.searchParams.get('status'); // 'used', 'unused', 'all'

    const allCodes = await env.REDEEM_CODES_KV.list({ prefix: 'code:' });
    const codes = [];

    for (const key of allCodes.keys) {
      const codeData = await env.REDEEM_CODES_KV.get(key.name);
      if (codeData) {
        const code = JSON.parse(codeData);

        // 状态过滤
        if (status === 'used' && !code.used) continue;
        if (status === 'unused' && code.used) continue;

        codes.push(code);
      }
    }

    // 按创建时间倒序排序
    codes.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    // 分页
    const startIndex = (page - 1) * limit;
    const endIndex = startIndex + limit;
    const paginatedCodes = codes.slice(startIndex, endIndex);

    return jsonResponse({
      codes: paginatedCodes,
      total: codes.length,
      page,
      limit,
      totalPages: Math.ceil(codes.length / limit)
    });

  } catch (error) {
    console.error('查询兑换码失败:', error);
    return jsonResponse({ error: '查询兑换码失败' }, 500);
  }
}

// 使用兑换码
async function handleUseRedeemCode(request, env) {
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

    const { code } = await request.json();
    if (!code) {
      return jsonResponse({ error: '兑换码不能为空' }, 400);
    }

    // 查询兑换码
    const codeData = await env.REDEEM_CODES_KV.get(`code:${code.toUpperCase()}`);
    if (!codeData) {
      return jsonResponse({ error: '兑换码不存在或已失效' }, 400);
    }

    const redeemCode = JSON.parse(codeData);
    if (redeemCode.used) {
      return jsonResponse({
        error: '兑换码已被使用',
        usedBy: redeemCode.usedBy,
        usedAt: redeemCode.usedAt
      }, 400);
    }

    // 获取用户信息
    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: '用户不存在' }, 404);
    }

    const user = JSON.parse(userData);

    // 计算新的会员到期时间
    let newExpiryDate;
    const now = new Date();

    // 检查用户当前的会员状态，包括试用期和付费会员
    let currentExpiryDate = null;
    
    // 检查付费会员到期时间
    if (user.membershipExpiresAt && new Date(user.membershipExpiresAt) > now) {
      currentExpiryDate = new Date(user.membershipExpiresAt);
    }
    
    // 检查试用期到期时间
    if (user.freeTrialEndDate && new Date(user.freeTrialEndDate) > now) {
      const trialEnd = new Date(user.freeTrialEndDate);
      // 如果试用期比付费会员期更晚，使用试用期时间
      if (!currentExpiryDate || trialEnd > currentExpiryDate) {
        currentExpiryDate = trialEnd;
      }
    }

    // 如果用户当前有有效会员（试用或付费），则在现有基础上延长
    if (currentExpiryDate) {
      newExpiryDate = new Date(currentExpiryDate);
    } else {
      newExpiryDate = new Date(now);
    }

    newExpiryDate.setDate(newExpiryDate.getDate() + redeemCode.days);

    // 更新用户会员信息
    user.membershipType = redeemCode.type;
    user.membershipExpiresAt = newExpiryDate.toISOString();
    user.lastRedeemCode = code.toUpperCase();
    user.lastRedeemAt = now.toISOString();
    
    // 添加兑换记录
    const redeemRecord = {
      id: crypto.randomUUID(),
      code: code.toUpperCase(),
      type: redeemCode.type,
      name: redeemCode.name,
      days: redeemCode.days,
      redeemedAt: now.toISOString(),
      validFrom: (currentExpiryDate || now).toISOString(),
      validTo: newExpiryDate.toISOString(),
      previousExpiryDate: currentExpiryDate ? currentExpiryDate.toISOString() : null
    };
    
    // 保存兑换记录
    const existingRedeems = await env.USERS_KV.get(`redeems:${tokenData.username}`);
    const redeems = existingRedeems ? JSON.parse(existingRedeems) : [];
    redeems.unshift(redeemRecord); // 最新记录在前
    await env.USERS_KV.put(`redeems:${tokenData.username}`, JSON.stringify(redeems));

    // 如果是试用转正式会员，清除试用标记
    if (redeemCode.type === 'premium' && user.freeTrialEndDate) {
      delete user.freeTrialEndDate;
    }

    await env.USERS_KV.put(`user:${tokenData.username}`, JSON.stringify(user));

    // 标记兑换码为已使用
    redeemCode.used = true;
    redeemCode.usedBy = tokenData.username;
    redeemCode.usedAt = now.toISOString();
    await env.REDEEM_CODES_KV.put(`code:${code.toUpperCase()}`, JSON.stringify(redeemCode));

    return jsonResponse({
      message: `兑换成功！获得${redeemCode.name}`,
      membershipType: redeemCode.type,
      expiresAt: newExpiryDate.toISOString(),
      daysAdded: redeemCode.days
    });

  } catch (error) {
    console.error('使用兑换码失败:', error);
    return jsonResponse({ error: '使用兑换码失败' }, 500);
  }
}

// 删除兑换码（管理员功能）
async function handleDeleteRedeemCode(request, env) {
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

    // 检查管理员权限
    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: '用户不存在' }, 404);
    }

    const user = JSON.parse(userData);
    if (!isAdmin(user.email)) {
      return jsonResponse({ error: '权限不足，仅管理员可删除兑换码' }, 403);
    }

    const { code } = await request.json();
    if (!code) {
      return jsonResponse({ error: '兑换码不能为空' }, 400);
    }

    const codeKey = `code:${code.toUpperCase()}`;
    const codeData = await env.REDEEM_CODES_KV.get(codeKey);
    if (!codeData) {
      return jsonResponse({ error: '兑换码不存在' }, 404);
    }

    await env.REDEEM_CODES_KV.delete(codeKey);

    return jsonResponse({ message: '兑换码删除成功' });

  } catch (error) {
    console.error('删除兑换码失败:', error);
    return jsonResponse({ error: '删除兑换码失败' }, 500);
  }
}

// 获取管理员价格
async function handleGetAdminPrice(request, env) {
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

    // 获取用户信息检查管理员权限
    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: '用户不存在' }, 404);
    }

    const user = JSON.parse(userData);
    const isAdminUser = isAdmin(user.email);

    const { plan } = await request.json();

    if (isAdminUser && ADMIN_PRICES[plan]) {
      return jsonResponse({
        isAdmin: true,
        originalPrice: getOriginalPrice(plan),
        adminPrice: ADMIN_PRICES[plan],
        plan
      });
    }

    return jsonResponse({
      isAdmin: false,
      price: getOriginalPrice(plan),
      plan
    });

  } catch (error) {
    console.error('获取管理员价格失败:', error);
    return jsonResponse({ error: '获取价格失败' }, 500);
  }
}

// 获取原始价格
function getOriginalPrice(plan) {
  const prices = {
    'monthly': '21',
    'quarterly': '63',
    'yearly': '252'
  };
  return prices[plan] || '21';
}

// 支付宝当面付相关处理函数
import { ALIPAY_CONFIG } from './alipay-config.js';
import { importPrivateKey, importPublicKey, generateSign, verifySign } from './alipay-utils.js';

// Helper to get Alipay config from environment
function getAlipayEnvConfig(env) {
  const isSandbox = env.ALIPAY_SANDBOX === 'true';
  // 更新 APP_CONFIG 中的沙箱环境设置
  ALIPAY_CONFIG.APP_CONFIG.sandbox = isSandbox;

  return {
    app_id: env.ALIPAY_APP_ID,
    privateKey: env.ALIPAY_PRIVATE_KEY,
    alipayPublicKey: env.ALIPAY_PUBLIC_KEY,
    isSandbox: isSandbox,
    gateway: isSandbox ? ALIPAY_CONFIG.SANDBOX_GATEWAY_URL : ALIPAY_CONFIG.GATEWAY_URL, // 直接使用对应的网关地址
  };
}

// 创建支付宝订单
async function handleCreateAlipayOrder(request, env) {
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

    const { plan = 'monthly' } = await request.json();
    const planDetails = ALIPAY_CONFIG.MEMBERSHIP_PRICES[plan];
    if (!planDetails) {
      return jsonResponse({ error: '无效的会员计划' }, 400);
    }

    // 检查用户是否为管理员，如果是则使用管理员价格
    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: '用户不存在' }, 404);
    }

    const user = JSON.parse(userData);
    const isAdminUser = isAdmin(user.email);

    // 如果是管理员，使用管理员特殊价格
    let finalAmount = planDetails.amount;
    if (isAdminUser && ADMIN_PRICES[plan]) {
      finalAmount = ADMIN_PRICES[plan];
    }

    const alipayConfig = getAlipayEnvConfig(env);
    if (!alipayConfig.app_id || !alipayConfig.privateKey || !alipayConfig.alipayPublicKey) {
      console.error('Alipay environment variables are not set');
      return jsonResponse({ error: '支付服务配置不完整' }, 500);
    }

    const outTradeNo = `MEMBER_${tokenData.username}_${Date.now()}`;
    const subject = `全球法布施 - ${planDetails.name}`;

    const orderData = {
      orderId: outTradeNo,
      userId: tokenData.username,
      plan: plan,
      amount: finalAmount,
      originalAmount: planDetails.amount,
      isAdminOrder: isAdminUser,
      status: 'PENDING',
      createdAt: new Date().toISOString(),
    };
    await env.ORDERS_KV.put(outTradeNo, JSON.stringify(orderData));

    const bizContent = {
      out_trade_no: outTradeNo,
      total_amount: finalAmount,
      subject: subject,
      product_code: ALIPAY_CONFIG.PRODUCT_CODE,
      timeout_express: ALIPAY_CONFIG.TIMEOUT_EXPRESS,
    };

    // 支付宝要求的时间戳格式：yyyy-MM-dd HH:mm:ss
    // 使用东八区时间（北京时间）
    const now = new Date();
    // 格式化为 yyyy-MM-dd HH:mm:ss
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const seconds = String(now.getSeconds()).padStart(2, '0');
    const timestamp = `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;

    const params = {
      app_id: alipayConfig.app_id,
      method: 'alipay.trade.precreate',
      format: 'JSON',
      charset: ALIPAY_CONFIG.APP_CONFIG.charset,
      sign_type: ALIPAY_CONFIG.APP_CONFIG.sign_type,
      timestamp: timestamp,
      version: ALIPAY_CONFIG.APP_CONFIG.version,
      notify_url: 'https://ombhrum.com/api/alipay/notify',
      return_url: 'https://ombhrum.com/membership.html',
      biz_content: JSON.stringify(bizContent),
    };

    console.log('支付宝API参数:', params);

    const privateKey = await importPrivateKey(alipayConfig.privateKey);
    params.sign = await generateSign(params, privateKey);

    // 使用 URLSearchParams 构建请求参数
    const searchParams = new URLSearchParams();
    for (const key in params) {
      searchParams.append(key, params[key]);
    }

    console.log('请求支付宝API:', alipayConfig.gateway);
    console.log('请求参数:', JSON.stringify(params, null, 2));

    try {
      // 确保使用正确的请求格式
      const formData = new URLSearchParams();
      for (const key in params) {
        formData.append(key, params[key]);
      }

      const response = await fetch(alipayConfig.gateway, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8' },
        body: formData.toString(),
        redirect: 'follow',
      });

      // 检查响应状态
      if (!response.ok) {
        console.error('支付宝API响应错误:', response.status, response.statusText);
        const responseText = await response.text();
        console.error('响应内容:', responseText.substring(0, 1000)); // 只记录前1000个字符，避免日志过大
        return jsonResponse({ error: `支付宝API请求失败: ${response.status} ${response.statusText}` }, 500);
      }

      // 尝试解析响应内容
      const responseText = await response.text();
      console.log('支付宝API响应:', responseText.substring(0, 500)); // 只记录前500个字符

      try {
        const alipayResponse = JSON.parse(responseText);
        const precreateResponse = alipayResponse.alipay_trade_precreate_response;

        if (precreateResponse.code === '10000') {
          return jsonResponse({
            orderId: outTradeNo,
            qrCode: precreateResponse.qr_code,
            amount: finalAmount,
            originalAmount: planDetails.amount,
            isAdminOrder: isAdminUser,
            plan: plan,
          });
        } else {
          console.error('Alipay precreate failed:', precreateResponse);
          return jsonResponse({ error: '创建支付二维码失败', detail: precreateResponse.sub_msg }, 500);
        }
      } catch (parseError) {
        console.error('解析支付宝API响应失败:', parseError);
        console.error('响应内容:', responseText.substring(0, 1000));
        return jsonResponse({ error: '解析支付宝API响应失败: 返回内容不是有效的JSON' }, 500);
      }
    } catch (fetchError) {
      console.error('请求支付宝API失败:', fetchError);
      return jsonResponse({ error: `请求支付宝API失败: ${fetchError.message}` }, 500);
    }
  } catch (error) {
    console.error('创建支付宝订单失败:', error);
    return jsonResponse({ error: '创建订单失败: ' + error.message }, 500);
  }
}

// 查询支付宝订单状态 (from KV)
async function handleQueryAlipayOrder(request, env) {
  try {
    const url = new URL(request.url);
    const orderId = url.searchParams.get('orderId');
    if (!orderId) {
      return jsonResponse({ error: '订单ID不能为空' }, 400);
    }

    const orderData = await env.ORDERS_KV.get(orderId);
    if (!orderData) {
      return jsonResponse({ error: '订单不存在' }, 404);
    }

    return jsonResponse(JSON.parse(orderData));
  } catch (error) {
    console.error('查询订单失败:', error);
    return jsonResponse({ error: '查询订单失败: ' + error.message }, 500);
  }
}

// 处理支付宝异步通知
async function handleAlipayNotify(request, env) {
  console.log('Received Alipay notify request.');
  try {
    const alipayConfig = getAlipayEnvConfig(env);
    const alipayPublicKey = await importPublicKey(alipayConfig.alipayPublicKey);

    const formData = await request.formData();
    const params = {};
    const signParams = {};
    for (const [key, value] of formData.entries()) {
      params[key] = value;
      if (key !== 'sign' && key !== 'sign_type') {
        signParams[key] = value;
      }
    }
    
    console.log('Alipay notify params:', JSON.stringify(params, null, 2));

    const sign = params['sign'];
    const isValid = await verifySign(signParams, sign, alipayPublicKey);
    
    console.log(`Signature verification result: ${isValid}`);

    if (!isValid) {
      console.error('Alipay notify signature verification failed. Params:', JSON.stringify(params));
      return new Response('failure', { status: 400 });
    }

    if (params.trade_status === 'TRADE_SUCCESS' || params.trade_status === 'TRADE_FINISHED') {
      const outTradeNo = params.out_trade_no;
      const orderDataStr = await env.ORDERS_KV.get(outTradeNo);
      if (!orderDataStr) {
        console.error(`Order not found for notify: ${outTradeNo}`);
        return new Response('failure', { status: 404 });
      }

      const orderData = JSON.parse(orderDataStr);
      if (orderData.status === 'PAID') {
        console.log(`Order already paid: ${outTradeNo}`);
        return new Response('success', { status: 200 });
      }

      // Update order status
      orderData.status = 'PAID';
      orderData.paidAt = params.gmt_payment || new Date().toISOString();
      orderData.tradeNo = params.trade_no;
      await env.ORDERS_KV.put(outTradeNo, JSON.stringify(orderData));

      // Activate membership
      const userDataStr = await env.USERS_KV.get(`user:${orderData.userId}`);
      if (!userDataStr) {
        console.error(`User not found for order: ${outTradeNo}, user: ${orderData.userId}`);
        return new Response('failure', { status: 404 });
      }
      const user = JSON.parse(userDataStr);
      const planDetails = ALIPAY_CONFIG.MEMBERSHIP_PRICES[orderData.plan];

      const currentMembership = checkMembershipStatus(user);

      // 如果用户会员是激活状态，则在当前到期时间上叠加，否则从现在开始计算
      const startDate = (currentMembership.isActive && currentMembership.expiresAt)
        ? new Date(currentMembership.expiresAt)
        : new Date();

      const endDate = new Date(startDate.getTime() + planDetails.duration);

      user.membershipType = 'paid';
      user.membershipExpiresAt = endDate.toISOString();
      
      // 添加购买记录
      const purchaseRecord = {
        id: crypto.randomUUID(),
        orderId: outTradeNo,
        plan: orderData.plan,
        amount: planDetails.amount,
        currency: 'CNY',
        status: 'completed',
        paymentMethod: 'alipay',
        purchasedAt: new Date().toISOString(),
        validFrom: startDate.toISOString(),
        validTo: endDate.toISOString()
      };
      
      // 保存购买记录
      const existingPurchases = await env.USERS_KV.get(`purchases:${orderData.userId}`);
      const purchases = existingPurchases ? JSON.parse(existingPurchases) : [];
      purchases.unshift(purchaseRecord); // 最新记录在前
      await env.USERS_KV.put(`purchases:${orderData.userId}`, JSON.stringify(purchases));

      await env.USERS_KV.put(`user:${orderData.userId}`, JSON.stringify(user));
      console.log(`Membership activated for user ${orderData.userId} until ${user.membershipExpiresAt}`);
    }

    return new Response('success', { status: 200 });
  } catch (error) {
    console.error('处理支付宝通知失败:', error.message, error.stack);
    return new Response('failure', { status: 500 });
  }
}

// 获取用户会员状态 (This is the same as the Stripe one, but let's keep it for clarity with the API routes)
async function handleGetAlipayMembershipStatus(request, env) {
  return handleGetMembershipStatus(request, env);
}

// Stripe支付相关处理函数

// 获取用户会员状态
async function handleGetMembershipStatus(request, env) {
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
    const membershipStatus = checkMembershipStatus(user);

    return jsonResponse({
      username: user.username,
      email: user.email,
      membership: membershipStatus,
      hasStripeCustomer: !!user.stripeCustomerId
    });
  } catch (error) {
    console.error('获取会员状态失败:', error);
    return jsonResponse({ error: '获取会员状态失败' }, 500);
  }
}

// 创建Stripe客户和订阅
async function handleCreateSubscription(request, env) {
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

    const { currency = 'cny' } = await request.json();

    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: '用户不存在' }, 404);
    }

    const user = JSON.parse(userData);

    // 检查是否已有有效订阅
    const membershipStatus = checkMembershipStatus(user);
    if (membershipStatus.isActive && membershipStatus.type === 'paid') {
      return jsonResponse({ error: '您已经是付费会员' }, 400);
    }

    if (!env.STRIPE_SECRET_KEY) {
      return jsonResponse({ error: 'Stripe配置未设置' }, 500);
    }

    const stripe = createStripeClient(env.STRIPE_SECRET_KEY);

    // 创建或获取Stripe客户
    let customerId = user.stripeCustomerId;
    if (!customerId) {
      const customer = await stripe.createCustomer(user.email, user.username);
      customerId = customer.id;

      // 更新用户数据
      user.stripeCustomerId = customerId;
      await env.USERS_KV.put(`user:${tokenData.username}`, JSON.stringify(user));
    }

    // 选择价格ID
    const priceId = currency === 'usd'
      ? STRIPE_CONFIG.PRODUCTS.MONTHLY_MEMBERSHIP_USD
      : STRIPE_CONFIG.PRODUCTS.MONTHLY_MEMBERSHIP_CNY;

    // 创建订阅（如果是试用期用户，不再给试用期）
    const isTrialUser = membershipStatus.type === 'trial' && membershipStatus.isActive;
    const subscription = await stripe.createSubscription(
      customerId,
      priceId,
      isTrialUser ? null : STRIPE_CONFIG.FREE_TRIAL_DAYS
    );

    return jsonResponse({
      subscriptionId: subscription.id,
      clientSecret: subscription.latest_invoice.payment_intent.client_secret,
      customerId: customerId
    });

  } catch (error) {
    console.error('创建订阅失败:', error);
    return jsonResponse({ error: '创建订阅失败: ' + error.message }, 500);
  }
}

// 处理Stripe Webhook
async function handleStripeWebhook(request, env) {
  try {
    if (!env.STRIPE_WEBHOOK_SECRET) {
      return jsonResponse({ error: 'Webhook配置未设置' }, 500);
    }

    const body = await request.text();
    const signature = request.headers.get('stripe-signature');

    // 这里应该验证webhook签名，简化版本跳过
    const event = JSON.parse(body);

    console.log('收到Stripe Webhook事件:', event.type);

    switch (event.type) {
      case 'invoice.payment_succeeded':
        await handlePaymentSucceeded(event.data.object, env);
        break;
      case 'invoice.payment_failed':
        await handlePaymentFailed(event.data.object, env);
        break;
      case 'customer.subscription.updated':
      case 'customer.subscription.created':
        await handleSubscriptionUpdated(event.data.object, env);
        break;
      case 'customer.subscription.deleted':
        await handleSubscriptionDeleted(event.data.object, env);
        break;
      default:
        console.log('未处理的事件类型:', event.type);
    }

    return jsonResponse({ received: true });
  } catch (error) {
    console.error('Webhook处理失败:', error);
    return jsonResponse({ error: 'Webhook处理失败' }, 400);
  }
}

// 支付成功处理
async function handlePaymentSucceeded(invoice, env) {
  try {
    const customerId = invoice.customer;
    const subscriptionId = invoice.subscription;

    // 查找用户
    const users = await env.USERS_KV.list({ prefix: 'user:' });
    for (const key of users.keys) {
      const userData = await env.USERS_KV.get(key.name);
      if (!userData) continue;

      const user = JSON.parse(userData);
      if (user.stripeCustomerId === customerId) {
        // 更新会员状态
        const now = new Date();
        const nextMonth = new Date(now);
        nextMonth.setMonth(nextMonth.getMonth() + 1);

        user.membershipType = 'paid';
        user.membershipExpiresAt = nextMonth.toISOString();
        user.subscriptionId = subscriptionId;
        user.lastPaymentDate = now.toISOString();

        await env.USERS_KV.put(key.name, JSON.stringify(user));
        console.log('用户会员状态已更新:', user.username);
        break;
      }
    }
  } catch (error) {
    console.error('处理支付成功事件失败:', error);
  }
}

// 支付失败处理
async function handlePaymentFailed(invoice, env) {
  try {
    const customerId = invoice.customer;

    // 查找用户并记录支付失败
    const users = await env.USERS_KV.list({ prefix: 'user:' });
    for (const key of users.keys) {
      const userData = await env.USERS_KV.get(key.name);
      if (!userData) continue;

      const user = JSON.parse(userData);
      if (user.stripeCustomerId === customerId) {
        user.lastPaymentFailedDate = new Date().toISOString();
        await env.USERS_KV.put(key.name, JSON.stringify(user));
        console.log('记录支付失败:', user.username);
        break;
      }
    }
  } catch (error) {
    console.error('处理支付失败事件失败:', error);
  }
}

// 订阅更新处理
async function handleSubscriptionUpdated(subscription, env) {
  try {
    const customerId = subscription.customer;
    const status = subscription.status;

    const users = await env.USERS_KV.list({ prefix: 'user:' });
    for (const key of users.keys) {
      const userData = await env.USERS_KV.get(key.name);
      if (!userData) continue;

      const user = JSON.parse(userData);
      if (user.stripeCustomerId === customerId) {
        user.subscriptionStatus = status;
        user.subscriptionId = subscription.id;

        // 根据订阅状态更新会员状态
        if (status === 'active') {
          const periodEnd = new Date(subscription.current_period_end * 1000);
          user.membershipType = 'paid';
          user.membershipExpiresAt = periodEnd.toISOString();
        } else if (status === 'canceled' || status === 'unpaid') {
          // 保持当前会员状态直到到期
          user.membershipType = 'expired';
        }

        await env.USERS_KV.put(key.name, JSON.stringify(user));
        console.log('订阅状态已更新:', user.username, status);
        break;
      }
    }
  } catch (error) {
    console.error('处理订阅更新事件失败:', error);
  }
}

// 订阅删除处理
async function handleSubscriptionDeleted(subscription, env) {
  try {
    const customerId = subscription.customer;

    const users = await env.USERS_KV.list({ prefix: 'user:' });
    for (const key of users.keys) {
      const userData = await env.USERS_KV.get(key.name);
      if (!userData) continue;

      const user = JSON.parse(userData);
      if (user.stripeCustomerId === customerId) {
        user.subscriptionStatus = 'canceled';
        user.membershipType = 'expired';
        user.subscriptionId = null;

        await env.USERS_KV.put(key.name, JSON.stringify(user));
        console.log('订阅已取消:', user.username);
        break;
      }
    }
  } catch (error) {
    console.error('处理订阅删除事件失败:', error);
  }
}

// 取消订阅
async function handleCancelSubscription(request, env) {
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
    if (!user.subscriptionId) {
      return jsonResponse({ error: '没有活跃的订阅' }, 400);
    }

    if (!env.STRIPE_SECRET_KEY) {
      return jsonResponse({ error: 'Stripe配置未设置' }, 500);
    }

    const stripe = createStripeClient(env.STRIPE_SECRET_KEY);
    await stripe.cancelSubscription(user.subscriptionId);

    return jsonResponse({ message: '订阅已取消' });
  } catch (error) {
    console.error('取消订阅失败:', error);
    return jsonResponse({ error: '取消订阅失败: ' + error.message }, 500);
  }
}

// 新的HTML页面 - 忘记密码
const forgotPasswordHTML = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>忘记密码 - 全球法布施</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Microsoft YaHei', sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .forgot-container { background: white; padding: 40px; border-radius: 10px; box-shadow: 0 15px 35px rgba(0,0,0,0.1); width: 100%; max-width: 400px; }
        h2 { text-align: center; margin-bottom: 30px; color: #333; }
        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 5px; color: #555; }
        input { width: 100%; padding: 12px; border: 1px solid #ddd; border-radius: 5px; font-size: 16px; }
        button { width: 100%; padding: 12px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border: none; border-radius: 5px; cursor: pointer; font-size: 16px; }
        button:hover { opacity: 0.9; }
        .message { margin-top: 15px; padding: 10px; border-radius: 5px; text-align: center; }
        .error { background: #fee; color: #c33; }
        .success { background: #efe; color: #3c3; }
        .login-link { text-align: center; margin-top: 20px; }
        .login-link a { color: #667eea; text-decoration: none; }
    </style>
</head>
<body>
    <div class="forgot-container">
        <h2>忘记密码</h2>
        <form id="forgotForm">
            <div class="form-group">
                <label for="email">注册邮箱</label>
                <input type="email" id="email" name="email" required>
            </div>
            <button type="submit">发送重置邮件</button>
        </form>
        <div id="message" class="message" style="display: none;"></div>
        <div class="login-link">
            <a href="/login.html">返回登录</a>
        </div>
    </div>

    <script>
        document.getElementById('forgotForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const email = document.getElementById('email').value;
            const messageDiv = document.getElementById('message');
            
            try {
                const response = await fetch('/api/auth/forgot-password', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email })
                });
                
                const data = await response.json();
                
                if (response.ok) {
                    messageDiv.className = 'message success';
                    messageDiv.textContent = '重置邮件已发送，请查收邮箱';
                } else {
                    messageDiv.className = 'message error';
                    messageDiv.textContent = data.error || '请求失败';
                }
                messageDiv.style.display = 'block';
            } catch (error) {
                messageDiv.className = 'message error';
                messageDiv.textContent = '网络错误，请重试';
                messageDiv.style.display = 'block';
            }
        });
    </script>
</body>
</html>`;

// 重置密码页面
const resetPasswordHTML = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>重置密码 - 全球法布施</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Microsoft YaHei', sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .reset-container { background: white; padding: 40px; border-radius: 10px; box-shadow: 0 15px 35px rgba(0,0,0,0.1); width: 100%; max-width: 400px; }
        h2 { text-align: center; margin-bottom: 30px; color: #333; }
        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 5px; color: #555; }
        input { width: 100%; padding: 12px; border: 1px solid #ddd; border-radius: 5px; font-size: 16px; }
        button { width: 100%; padding: 12px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border: none; border-radius: 5px; cursor: pointer; font-size: 16px; }
        button:hover { opacity: 0.9; }
        .message { margin-top: 15px; padding: 10px; border-radius: 5px; text-align: center; }
        .error { background: #fee; color: #c33; }
        .success { background: #efe; color: #3c3; }
        .login-link { text-align: center; margin-top: 20px; }
        .login-link a { color: #667eea; text-decoration: none; }
    </style>
</head>
<body>
    <div class="reset-container">
        <h2>重置密码</h2>
        <form id="resetForm">
            <div class="form-group">
                <label for="newPassword">新密码</label>
                <input type="password" id="newPassword" name="newPassword" required minlength="6">
            </div>
            <div class="form-group">
                <label for="confirmPassword">确认密码</label>
                <input type="password" id="confirmPassword" name="confirmPassword" required minlength="6">
            </div>
            <button type="submit">重置密码</button>
        </form>
        <div id="message" class="message" style="display: none;"></div>
        <div class="login-link">
            <a href="/login.html">返回登录</a>
        </div>
    </div>

    <script>
        const urlParams = new URLSearchParams(window.location.search);
        const token = urlParams.get('token');
        const email = urlParams.get('email');
        
        if (!token || !email) {
            document.getElementById('message').className = 'message error';
            document.getElementById('message').textContent = '无效的重置链接';
            document.getElementById('message').style.display = 'block';
            document.querySelector('button').disabled = true;
        }

        document.getElementById('resetForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const newPassword = document.getElementById('newPassword').value;
            const confirmPassword = document.getElementById('confirmPassword').value;
            const messageDiv = document.getElementById('message');
            
            if (newPassword !== confirmPassword) {
                messageDiv.className = 'message error';
                messageDiv.textContent = '两次输入的密码不一致';
                messageDiv.style.display = 'block';
                return;
            }
            
            try {
                const response = await fetch('/api/auth/reset-password', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email, token, newPassword })
                });
                
                const data = await response.json();
                
                if (response.ok) {
                    messageDiv.className = 'message success';
                    messageDiv.textContent = '密码重置成功，正在跳转登录...';
                    setTimeout(() => {
                        window.location.href = '/login.html';
                    }, 2000);
                } else {
                    messageDiv.className = 'message error';
                    messageDiv.textContent = data.error || '重置失败';
                }
                messageDiv.style.display = 'block';
            } catch (error) {
                messageDiv.className = 'message error';
                messageDiv.textContent = '网络错误，请重试';
                messageDiv.style.display = 'block';
            }
        });
    </script>
</body>
</html>`;

// 更新注册页面，添加邮箱验证码功能
const registerHTML = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>注册 - 全球法布施</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Microsoft YaHei', sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .register-container { background: white; padding: 40px; border-radius: 10px; box-shadow: 0 15px 35px rgba(0,0,0,0.1); width: 100%; max-width: 400px; }
        h2 { text-align: center; margin-bottom: 30px; color: #333; }
        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 5px; color: #555; }
        input { width: 100%; padding: 12px; border: 1px solid #ddd; border-radius: 5px; font-size: 16px; }
        .verification-group { display: flex; gap: 10px; }
        .verification-group input { flex: 1; }
        .verification-group button { width: auto; padding: 12px 15px; font-size: 14px; }
        button { width: 100%; padding: 12px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border: none; border-radius: 5px; cursor: pointer; font-size: 16px; }
        button:hover:not(:disabled) { opacity: 0.9; }
        button:disabled { background: #ccc; cursor: not-allowed; }
        .message { margin-top: 15px; padding: 10px; border-radius: 5px; text-align: center; }
        .error { background: #fee; color: #c33; }
        .success { background: #efe; color: #3c3; }
        .login-link { text-align: center; margin-top: 20px; }
        .login-link a { color: #667eea; text-decoration: none; }
    </style>
</head>
<body>
    <div class="register-container">
        <h2>用户注册</h2>
        <form id="registerForm">
            <div class="form-group">
                <label for="username">用户名</label>
                <input type="text" id="username" name="username" required minlength="3" maxlength="20">
            </div>
            <div class="form-group">
                <label for="email">邮箱</label>
                <input type="email" id="email" name="email" required>
            </div>
            <div class="form-group">
                <label for="password">密码</label>
                <input type="password" id="password" name="password" required minlength="6">
            </div>
            <div class="form-group">
                <label for="confirmPassword">确认密码</label>
                <input type="password" id="confirmPassword" name="confirmPassword" required minlength="6">
            </div>
            <div class="form-group">
                <label for="verificationCode">邮箱验证码</label>
                <div class="verification-group">
                    <input type="text" id="verificationCode" name="verificationCode" required maxlength="6" placeholder="6位验证码">
                    <button type="button" id="sendCodeBtn" onclick="sendVerificationCode()">发送验证码</button>
                </div>
            </div>
            <button type="submit">注册</button>
        </form>
        <div id="message" class="message" style="display: none;"></div>
        <div class="login-link">
            <a href="/login.html">已有账号？立即登录</a>
        </div>
    </div>

    <script>
        let countdown = 0;
        
        async function sendVerificationCode() {
            const email = document.getElementById('email').value;
            const sendBtn = document.getElementById('sendCodeBtn');
            const messageDiv = document.getElementById('message');
            
            if (!email) {
                messageDiv.className = 'message error';
                messageDiv.textContent = '请先填写邮箱地址';
                messageDiv.style.display = 'block';
                return;
            }
            
            // 验证邮箱格式
            const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            if (!emailRegex.test(email)) {
                messageDiv.className = 'message error';
                messageDiv.textContent = '邮箱格式不正确';
                messageDiv.style.display = 'block';
                return;
            }
            
            try {
                sendBtn.disabled = true;
                const response = await fetch('/api/auth/send-verification-code', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email, type: 'register' })
                });
                
                const data = await response.json();
                
                if (response.ok) {
                    messageDiv.className = 'message success';
                    messageDiv.textContent = '验证码已发送到您的邮箱';
                    startCountdown();
                } else {
                    messageDiv.className = 'message error';
                    messageDiv.textContent = data.error || '发送失败';
                    sendBtn.disabled = false;
                }
                messageDiv.style.display = 'block';
            } catch (error) {
                messageDiv.className = 'message error';
                messageDiv.textContent = '网络错误，请重试';
                messageDiv.style.display = 'block';
                sendBtn.disabled = false;
            }
        }
        
        function startCountdown() {
            countdown = 60;
            const sendBtn = document.getElementById('sendCodeBtn');
            
            const timer = setInterval(() => {
                countdown--;
                sendBtn.textContent = \`\${countdown}秒后重试\`;
                
                if (countdown <= 0) {
                    clearInterval(timer);
                    sendBtn.textContent = '发送验证码';
                    sendBtn.disabled = false;
                }
            }, 1000);
        }
        
        document.getElementById('registerForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const username = document.getElementById('username').value;
            const email = document.getElementById('email').value;
            const password = document.getElementById('password').value;
            const confirmPassword = document.getElementById('confirmPassword').value;
            const verificationCode = document.getElementById('verificationCode').value;
            const messageDiv = document.getElementById('message');
            
            if (password !== confirmPassword) {
                messageDiv.className = 'message error';
                messageDiv.textContent = '两次输入的密码不一致';
                messageDiv.style.display = 'block';
                return;
            }
            
            try {
                const response = await fetch('/api/auth/register', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ username, email, password, verificationCode })
                });
                
                const data = await response.json();
                
                if (response.ok) {
                    messageDiv.className = 'message success';
                    messageDiv.textContent = '注册成功，正在跳转登录...';
                    messageDiv.style.display = 'block';
                    
                    setTimeout(() => {
                        window.location.href = '/login.html';
                    }, 1500);
                } else {
                    messageDiv.className = 'message error';
                    messageDiv.textContent = data.error || '注册失败';
                    messageDiv.style.display = 'block';
                }
            } catch (error) {
                messageDiv.className = 'message error';
                messageDiv.textContent = '网络错误，请重试';
                messageDiv.style.display = 'block';
            }
        });
    </script>
</body>
</html>`;

// 更新登录页面，添加忘记密码链接
const loginHTML = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>登录 - 全球法布施</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Microsoft YaHei', sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .login-container { background: white; padding: 40px; border-radius: 10px; box-shadow: 0 15px 35px rgba(0,0,0,0.1); width: 100%; max-width: 400px; }
        h2 { text-align: center; margin-bottom: 30px; color: #333; }
        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 5px; color: #555; }
        input { width: 100%; padding: 12px; border: 1px solid #ddd; border-radius: 5px; font-size: 16px; }
        button { width: 100%; padding: 12px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border: none; border-radius: 5px; cursor: pointer; font-size: 16px; }
        button:hover { opacity: 0.9; }
        .message { margin-top: 15px; padding: 10px; border-radius: 5px; text-align: center; }
        .error { background: #fee; color: #c33; }
        .success { background: #efe; color: #3c3; }
        .links { text-align: center; margin-top: 20px; display: flex; justify-content: space-between; }
        .links a { color: #667eea; text-decoration: none; font-size: 14px; }
    </style>
</head>
<body>
    <div class="login-container">
        <h2>登录系统</h2>
        <form id="loginForm">
            <div class="form-group">
                <label for="username">用户名</label>
                <input type="text" id="username" name="username" required>
            </div>
            <div class="form-group">
                <label for="password">密码</label>
                <input type="password" id="password" name="password" required>
            </div>
            <button type="submit">登录</button>
        </form>
        <div id="message" class="message" style="display: none;"></div>
        <div class="links">
            <a href="/register.html">没有账号？立即注册</a>
            <a href="/forgot-password.html">忘记密码？</a>
        </div>
    </div>

    <script>
        const originalFetch = window.fetch;
        window.fetch = function (url, options) {
            const token = localStorage.getItem('authToken');
            if (token) {
                options = options || {};
                options.headers = options.headers || {};
                options.headers['Authorization'] = 'Bearer ' + token;
            }
            return originalFetch(url, options);
        };

        document.getElementById('loginForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const username = document.getElementById('username').value;
            const password = document.getElementById('password').value;
            const messageDiv = document.getElementById('message');
            
            try {
                const response = await fetch('/api/auth/login', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ username, password })
                });
                
                const data = await response.json();
                
                if (response.ok) {
                    localStorage.setItem('authToken', data.token);
                    messageDiv.className = 'message success';
                    messageDiv.textContent = '登录成功，正在跳转...';
                    messageDiv.style.display = 'block';
                    
                    setTimeout(() => {
                        window.location.href = '/member-center.html';
                    }, 1000);
                } else {
                    messageDiv.className = 'message error';
                    messageDiv.textContent = data.error || '登录失败';
                    messageDiv.style.display = 'block';
                }
            } catch (error) {
                messageDiv.className = 'message error';
                messageDiv.textContent = '网络错误，请重试';
                messageDiv.style.display = 'block';
            }
        });
    </script>
</body>
</html>`;

// 主请求处理函数
export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const pathname = url.pathname;
    const method = request.method;

    // 处理预检请求
    if (method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      // API 路由
      if (pathname.startsWith('/api/auth/')) {
        if (pathname === '/api/auth/register' && method === 'POST') {
          return await handleRegister(request, env);
        }
        if (pathname === '/api/auth/login' && method === 'POST') {
          return await handleLogin(request, env);
        }
        if (pathname === '/api/auth/verify' && method === 'GET') {
          return await handleVerify(request, env);
        }
        if (pathname === '/api/auth/logout' && method === 'POST') {
          return await handleLogout(request, env);
        }
        if (pathname === '/api/auth/send-verification-code' && method === 'POST') {
          return await handleSendVerificationCode(request, env, ctx);
        }
        if (pathname === '/api/auth/verify-code' && method === 'POST') {
          return await handleVerifyCode(request, env);
        }
        if (pathname === '/api/auth/forgot-password' && method === 'POST') {
          return await handleForgotPassword(request, env);
        }
        if (pathname === '/api/auth/reset-password' && method === 'POST') {
          return await handleResetPassword(request, env);
        }
        // 微信登录相关API
        if (pathname === '/api/auth/wechat/login-url' && method === 'GET') {
          return await handleGetWechatLoginUrl(request, env);
        }
        if (pathname === '/api/auth/wechat/login' && method === 'POST') {
          return await handleWechatLogin(request, env);
        }
        if (pathname === '/api/auth/wechat/bind' && method === 'POST') {
          return await handleWechatBind(request, env);
        }
        if (pathname === '/api/auth/wechat/register' && method === 'POST') {
          return await handleWechatRegister(request, env);
        }
        if (pathname === '/api/auth/wechat/unbind' && method === 'POST') {
          return await handleWechatUnbind(request, env);
        }
        if (pathname === '/api/auth/user-info' && method === 'GET') {
          return await handleGetUserInfo(request, env);
        }
        if (pathname === '/api/auth/bind-email' && method === 'POST') {
          return await handleBindEmail(request, env);
        }
      }

      // 支付宝当面付相关API路由
      if (pathname.startsWith('/api/alipay/')) {
        if (pathname === '/api/alipay/create-order' && method === 'POST') {
          return await handleCreateAlipayOrder(request, env);
        }
        if (pathname === '/api/alipay/query-order' && method === 'GET') {
          return await handleQueryAlipayOrder(request, env);
        }
        if (pathname === '/api/alipay/notify' && method === 'POST') {
          return await handleAlipayNotify(request, env);
        }
        if (pathname === '/api/alipay/check-membership' && method === 'GET') {
          return await handleGetAlipayMembershipStatus(request, env);
        }
      }

      // Stripe支付相关API路由
      if (pathname.startsWith('/api/stripe/')) {
        if (pathname === '/api/stripe/membership-status' && method === 'GET') {
          return await handleGetMembershipStatus(request, env);
        }
        if (pathname === '/api/stripe/create-subscription' && method === 'POST') {
          return await handleCreateSubscription(request, env);
        }
        if (pathname === '/api/stripe/cancel-subscription' && method === 'POST') {
          return await handleCancelSubscription(request, env);
        }
        if (pathname === '/api/stripe/webhook' && method === 'POST') {
          return await handleStripeWebhook(request, env);
        }
      }

      // 管理员系统API路由
      if (pathname.startsWith('/api/admin/')) {
        if (pathname === '/api/admin/check-status' && method === 'GET') {
          return await handleCheckAdminStatus(request, env);
        }
        if (pathname === '/api/admin/create-redeem-code' && method === 'POST') {
          return await handleCreateRedeemCode(request, env);
        }
        if (pathname === '/api/admin/redeem-codes' && method === 'GET') {
          return await handleListRedeemCodes(request, env);
        }
        if (pathname === '/api/admin/use-redeem-code' && method === 'POST') {
          return await handleUseRedeemCode(request, env);
        }
        if (pathname === '/api/admin/delete-redeem-code' && method === 'DELETE') {
          return await handleDeleteRedeemCode(request, env);
        }
        if (pathname === '/api/admin/get-price' && method === 'POST') {
          return await handleGetAdminPrice(request, env);
        }
        if (pathname === '/api/admin/purchase-history' && method === 'GET') {
          return await handleGetPurchaseHistory(request, env);
        }
        if (pathname === '/api/admin/redeem-history' && method === 'GET') {
          return await handleGetRedeemHistory(request, env);
        }
      }

      // R2 列表路由：用于调试，列出存储桶中的所有文件
      if (pathname === '/r2' && url.searchParams.has('list')) {
        console.log('R2 列表请求开始');
        console.log('环境变量检查:', {
          hasR2Bucket: !!env.R2_BUCKET,
          envKeys: Object.keys(env || {}),
          bucketType: typeof env.R2_BUCKET
        });

        if (!env.R2_BUCKET) {
          console.error('R2_BUCKET 未绑定');
          return new Response('错误：R2 存储桶未绑定到此 Worker', { status: 500, headers: corsHeaders });
        }

        try {
          console.log('开始列出 R2 存储桶内容...');
          const objects = await env.R2_BUCKET.list();
          console.log(`R2 列表结果: 找到 ${objects.objects?.length || 0} 个对象`);

          if (!objects.objects) {
            console.log('R2 列表返回的 objects 为空');
            return jsonResponse({
              objects: [],
              files: [],
              count: 0,
              truncated: false,
              error: 'R2 列表返回空结果'
            });
          }

          const fileList = objects.objects.map(obj => ({
            key: obj.key,
            size: obj.size,
            uploaded: obj.uploaded
          }));

          console.log('R2 文件列表:', fileList.map(f => f.key));

          return jsonResponse({
            objects: fileList,  // 改为 objects 以保持一致性
            files: fileList,    // 保留 files 字段以兼容旧代码
            count: fileList.length,
            truncated: objects.truncated
          });
        } catch (error) {
          console.error('列出R2对象失败:', error);
          console.error('错误详情:', error.stack);
          return jsonResponse({
            error: '列出文件失败: ' + error.message,
            details: error.stack
          }, 500);
        }
      }

      // 会员中心页面
      if (pathname === '/member-center.html') {
        const memberCenterHTML = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>会员中心</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background-color: #f0f2f5; }
        .container { text-align: center; padding: 50px; background: white; border-radius: 12px; box-shadow: 0 8px 24px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        p { color: #666; font-size: 1.1em; }
        button { padding: 12px 24px; border: none; background: #e74c3c; color: white; border-radius: 8px; cursor: pointer; margin-top: 25px; font-size: 1em; transition: background 0.3s; }
        button:hover { background: #c0392b; }
        #loading { font-size: 1.2em; color: #555; }
    </style>
</head>
<body>
    <div class="container" id="content" style="display: none;">
        <h1>欢迎, <span id="username"></span>!</h1>
        <p>这里是您的会员中心。</p>
        <button onclick="logout()">退出登录</button>
    </div>
    <div id="loading">正在验证身份，请稍候...</div>

    <script>
        (async function() {
            const token = localStorage.getItem('authToken');
            if (!token) {
                window.location.href = '/login.html';
                return;
            }

            try {
                const response = await fetch('/api/auth/verify', {
                    headers: {
                        'Authorization': 'Bearer ' + token
                    }
                });

                if (response.ok) {
                    const data = await response.json();
                    document.getElementById('username').textContent = data.username;
                    document.getElementById('loading').style.display = 'none';
                    document.getElementById('content').style.display = 'block';
                } else {
                    const errorData = await response.json().catch(() => ({ error: '无法解析错误信息' }));
                    console.error('Authentication failed:', errorData);
                    alert('会话无效或已过期，请重新登录。\\n服务器返回信息: ' + (errorData.error || '未知错误'));
                    localStorage.removeItem('authToken');
                    window.location.href = '/login.html';
                }
            } catch (error) {
                console.error('Authentication network error:', error);
                alert('验证身份时发生网络错误，请检查您的网络连接。');
                localStorage.removeItem('authToken');
                window.location.href = '/login.html';
            }
        })();

        function logout() {
            localStorage.removeItem('authToken');
            window.location.href = '/login.html';
        }
    </script>
</body>
</html>`;
        return new Response(memberCenterHTML, { headers: { 'Content-Type': 'text/html;charset=UTF-8' } });
      }

      // 根路径重定向到会员中心
      if (pathname === '/') {
        return Response.redirect(new URL('/member-center.html', request.url).toString(), 302);
      }

      // R2 代理路由：支持同源通过 /r2?file=... 访问 R2 对象
      if (pathname === '/r2' && url.searchParams.has('file')) {
        // [修复] 移除 .normalize()，直接使用解码后的原始文件名进行查找
        let fileKey = url.searchParams.get('file').trim();

        if (!fileKey) {
          return new Response('错误：未指定文件参数', { status: 400, headers: corsHeaders });
        }
        if (!env.R2_BUCKET) {
          return new Response('错误：R2 存储桶未绑定到此 Worker', { status: 500, headers: corsHeaders });
        }

        // 预检已在上方统一处理，这里处理 HEAD/GET/Range
        if (method === 'HEAD') {
          console.log(`HEAD 请求文件: ${fileKey}`);
          // 增加详细的诊断日志
          console.log(`文件 Key 长度: ${fileKey.length}`);
          console.log(`文件 Key CharCodes: ${Array.from(fileKey).map(c => c.charCodeAt(0)).join(',')}`);

          let headObject;
          try {
            headObject = await env.R2_BUCKET.head(fileKey);
            if (headObject === null) {
              console.log(`文件不存在: ${fileKey}`);

              // 尝试列出相似文件以帮助调试
              try {
                const prefix = fileKey.length > 3 ? fileKey.substring(0, 3) : fileKey;
                const listResult = await env.R2_BUCKET.list({ prefix, limit: 10 });
                if (listResult.objects && listResult.objects.length > 0) {
                  console.log('存储桶中的相似文件:');
                  listResult.objects.forEach(obj => {
                    console.log(`  - "${obj.key}" (${(obj.size / 1024 / 1024).toFixed(2)} MB)`);
                  });
                } else {
                  console.log('存储桶中没有找到相似文件');
                }
              } catch (listError) {
                console.log('无法列出相似文件:', listError.message);
              }

              return new Response('错误：在 R2 存储桶中未找到指定的文件', { status: 404, headers: corsHeaders });
            }

            console.log(`R2 HEAD 结果: size=${headObject.size}, etag=${headObject.httpEtag}`);

            const headers = new Headers();

            // 安全地写入HTTP元数据
            try {
              headObject.writeHttpMetadata(headers);
            } catch (metadataError) {
              console.warn('写入HTTP元数据失败:', metadataError.message);
              // 继续执行，手动设置基本头部
            }

            headers.set('etag', headObject.httpEtag);
            headers.set('Content-Length', String(headObject.size));
            headers.set('Accept-Ranges', 'bytes');
            headers.set('Access-Control-Allow-Origin', '*');
            headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, Range');
            headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
            headers.set('Access-Control-Expose-Headers', 'Content-Length, Content-Range, Etag');
            headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');
            headers.set('Pragma', 'no-cache');
            headers.set('Expires', '0');

            console.log(`HEAD 响应头 Content-Length: ${headers.get('Content-Length')}`);
            return new Response(null, { status: 200, headers });
          } catch (error) {
            console.error('R2 HEAD 请求失败:', error);
            return new Response(`R2 访问错误: ${error.message}`, { status: 500, headers: corsHeaders });
          }
        }

        // 解析 Range 请求
        const rangeHeader = request.headers.get('Range');
        if (rangeHeader) {
          console.log(`Range 请求: ${rangeHeader} for ${fileKey}`);
          const match = /bytes\s*=\s*(\d+)-(\d+)?/.exec(rangeHeader);
          if (match) {
            const start = Number(match[1]);
            const endMaybe = match[2] !== undefined ? Number(match[2]) : undefined;
            const headObject = await env.R2_BUCKET.head(fileKey);
            if (headObject === null) {
              console.log(`Range 请求时文件不存在: ${fileKey}`);

              // 尝试列出相似文件
              try {
                const prefix = fileKey.length > 3 ? fileKey.substring(0, 3) : fileKey;
                const listResult = await env.R2_BUCKET.list({ prefix, limit: 5 });
                if (listResult.objects && listResult.objects.length > 0) {
                  console.log('存储桶中的相似文件:');
                  listResult.objects.forEach(obj => {
                    console.log(`  - "${obj.key}"`);
                  });
                }
              } catch (listError) {
                console.log('无法列出相似文件:', listError.message);
              }

              return new Response('错误：在 R2 存储桶中未找到指定的文件', { status: 404, headers: corsHeaders });
            }
            const size = headObject.size;
            console.log(`Range 请求中 R2 HEAD 结果: size=${size}, etag=${headObject.httpEtag}`);
            const end = endMaybe !== undefined ? Math.min(endMaybe, size - 1) : size - 1;
            const length = end - start + 1;

            if (start >= size || start < 0 || length <= 0) {
              return new Response('请求的范围无效', { status: 416, headers: { 'Content-Range': `bytes */${size}` } });
            }

            const rangedObject = await env.R2_BUCKET.get(fileKey, { range: { offset: start, length } });
            if (rangedObject === null) {
              return new Response('错误：在 R2 存储桶中未找到指定的文件', { status: 404, headers: corsHeaders });
            }

            const headers = new Headers();

            // 安全地写入HTTP元数据
            try {
              rangedObject.writeHttpMetadata(headers);
            } catch (metadataError) {
              console.warn('Range请求写入HTTP元数据失败:', metadataError.message);
            }

            headers.set('etag', rangedObject.httpEtag);
            headers.set('Content-Length', String(length));
            headers.set('Content-Range', `bytes ${start}-${end}/${size}`);
            headers.set('Accept-Ranges', 'bytes');
            headers.set('Access-Control-Allow-Origin', '*');
            headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, Range');
            headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
            headers.set('Access-Control-Expose-Headers', 'Content-Length, Content-Range, Etag');
            headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');
            return new Response(rangedObject.body, { status: 206, headers });
          }
        }

        // 常规 GET: 全量返回 - 优化大文件处理
        const object = await env.R2_BUCKET.get(fileKey);
        if (object === null) {
          return new Response('错误：在 R2 存储桶中未找到指定的文件', { status: 404, headers: corsHeaders });
        }

        const headers = new Headers();

        // 安全地写入HTTP元数据
        try {
          object.writeHttpMetadata(headers);
        } catch (metadataError) {
          console.warn('GET请求写入HTTP元数据失败:', metadataError.message);
        }

        headers.set('etag', object.httpEtag);
        headers.set('Content-Length', String(object.size));
        headers.set('Accept-Ranges', 'bytes');
        headers.set('Access-Control-Allow-Origin', '*');
        headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, Range');
        headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
        headers.set('Access-Control-Expose-Headers', 'Content-Length, Content-Range, Etag');
        headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');

        // 对于大文件，直接流式传输，不缓存到内存
        return new Response(object.body, {
          headers,
          status: 200
        });
      }

      // 提供忘记密码和重置密码页面 - 注释掉，使用静态文件
      // if (pathname === '/forgot-password.html') {
      //   return htmlResponse(forgotPasswordHTML);
      // }
      // if (pathname === '/reset-password.html') {
      //   return htmlResponse(resetPasswordHTML);
      // }

      // 对于所有其他请求，让Cloudflare的静态文件服务处理
      const response = await env.ASSETS.fetch(request);

      // 为所有响应添加CORS头
      if (response) {
        // 正确处理HEAD请求，保留原始头部信息
        const newResponse = new Response(
          request.method === 'HEAD' ? null : response.body,
          {
            status: response.status,
            statusText: response.statusText,
            headers: response.headers
          }
        );

        // 添加CORS头部
        newResponse.headers.set('Access-Control-Allow-Origin', '*');
        newResponse.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
        newResponse.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, Range');
        newResponse.headers.set('Access-Control-Expose-Headers', 'Content-Length, Content-Range, Etag');

        return newResponse;
      }

      return response;

    } catch (error) {
      console.error('Worker error:', error);
      console.error('Error type:', error.constructor.name);
      console.error('Error message:', error.message);
      console.error('Error stack:', error.stack);
      console.error('Request URL:', request.url);
      console.error('Request method:', request.method);
      return new Response('Internal Server Error', { status: 500, headers: corsHeaders });
    }
  }
};

// 辅助函数：根据文件路径获取Content-Type
function getContentType(pathname) {
  if (pathname.endsWith('.js')) return 'application/javascript';
  if (pathname.endsWith('.css')) return 'text/css';
  if (pathname.endsWith('.ico')) return 'image/x-icon';
  if (pathname.endsWith('.html')) return 'text/html; charset=utf-8';
  if (pathname.endsWith('.txt')) return 'text/plain; charset=utf-8';
  if (pathname.endsWith('.mp3')) return 'audio/mpeg';
  return 'application/octet-stream';
}
