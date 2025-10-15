var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// .wrangler/tmp/bundle-r02JVv/checked-fetch.js
var urls = /* @__PURE__ */ new Set();
function checkURL(request, init) {
  const url = request instanceof URL ? request : new URL(
    (typeof request === "string" ? new Request(request, init) : request).url
  );
  if (url.port && url.port !== "443" && url.protocol === "https:") {
    if (!urls.has(url.toString())) {
      urls.add(url.toString());
      console.warn(
        `WARNING: known issue with \`fetch()\` requests to custom HTTPS ports in published Workers:
 - ${url.toString()} - the custom port will be ignored when the Worker is published using the \`wrangler deploy\` command.
`
      );
    }
  }
}
__name(checkURL, "checkURL");
globalThis.fetch = new Proxy(globalThis.fetch, {
  apply(target, thisArg, argArray) {
    const [request, init] = argArray;
    checkURL(request, init);
    return Reflect.apply(target, thisArg, argArray);
  }
});

// worker.js
import { EmailMessage } from "cloudflare:email";

// stripe-config.js
var STRIPE_CONFIG = {
  // 价格配置已移至Worker配置统一管理
  // MONTHLY_PRICE_CNY: 700, // 7元 = 700分
  // MONTHLY_PRICE_USD: 100, // 1美元，用于测试
  // 新用户免费试用天数
  FREE_TRIAL_DAYS: 3,
  // Stripe 产品和价格 ID (需要在 Stripe Dashboard 中创建)
  PRODUCTS: {
    MONTHLY_MEMBERSHIP_CNY: "price_monthly_membership_cny",
    // 替换为实际的价格ID
    MONTHLY_MEMBERSHIP_USD: "price_monthly_membership_usd"
    // 替换为实际的价格ID
  }
};
function createStripeClient(apiKey) {
  return {
    async createCustomer(email, name) {
      const response = await fetch("https://api.stripe.com/v1/customers", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/x-www-form-urlencoded"
        },
        body: new URLSearchParams({
          email,
          name: name || email.split("@")[0]
        })
      });
      if (!response.ok) {
        throw new Error(`Stripe API error: ${response.status}`);
      }
      return await response.json();
    },
    async createSubscription(customerId, priceId, trialPeriodDays = null) {
      const params = {
        customer: customerId,
        items: JSON.stringify([{ price: priceId }]),
        payment_behavior: "default_incomplete",
        payment_settings: JSON.stringify({
          save_default_payment_method: "on_subscription"
        }),
        expand: JSON.stringify(["latest_invoice.payment_intent"])
      };
      if (trialPeriodDays) {
        params.trial_period_days = trialPeriodDays;
      }
      const response = await fetch("https://api.stripe.com/v1/subscriptions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/x-www-form-urlencoded"
        },
        body: new URLSearchParams(params)
      });
      if (!response.ok) {
        throw new Error(`Stripe API error: ${response.status}`);
      }
      return await response.json();
    },
    async createPaymentIntent(amount, currency = "cny", customerId = null) {
      const params = {
        amount,
        currency,
        automatic_payment_methods: JSON.stringify({ enabled: true })
      };
      if (customerId) {
        params.customer = customerId;
      }
      const response = await fetch("https://api.stripe.com/v1/payment_intents", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/x-www-form-urlencoded"
        },
        body: new URLSearchParams(params)
      });
      if (!response.ok) {
        throw new Error(`Stripe API error: ${response.status}`);
      }
      return await response.json();
    },
    async retrieveSubscription(subscriptionId) {
      const response = await fetch(`https://api.stripe.com/v1/subscriptions/${subscriptionId}`, {
        headers: {
          "Authorization": `Bearer ${apiKey}`
        }
      });
      if (!response.ok) {
        throw new Error(`Stripe API error: ${response.status}`);
      }
      return await response.json();
    },
    async cancelSubscription(subscriptionId) {
      const response = await fetch(`https://api.stripe.com/v1/subscriptions/${subscriptionId}`, {
        method: "DELETE",
        headers: {
          "Authorization": `Bearer ${apiKey}`
        }
      });
      if (!response.ok) {
        throw new Error(`Stripe API error: ${response.status}`);
      }
      return await response.json();
    }
  };
}
__name(createStripeClient, "createStripeClient");
function checkMembershipStatus(user) {
  const now = /* @__PURE__ */ new Date();
  if (user.freeTrialEndDate) {
    const trialEnd = new Date(user.freeTrialEndDate);
    if (now <= trialEnd) {
      return {
        isActive: true,
        type: "trial",
        expiresAt: trialEnd,
        daysLeft: Math.ceil((trialEnd - now) / (1e3 * 60 * 60 * 24))
      };
    }
  }
  const membershipEndDate = user.membershipExpiresAt;
  if (membershipEndDate) {
    const membershipEnd = new Date(membershipEndDate);
    if (now <= membershipEnd) {
      const membershipType = user.membershipType === "trial" ? "trial" : "paid";
      return {
        isActive: true,
        type: membershipType,
        expiresAt: membershipEnd,
        daysLeft: Math.ceil((membershipEnd - now) / (1e3 * 60 * 60 * 24))
      };
    }
  }
  return {
    isActive: false,
    type: "none",
    expiresAt: null,
    daysLeft: 0
  };
}
__name(checkMembershipStatus, "checkMembershipStatus");
function calculateTrialEndDate2(startDate = /* @__PURE__ */ new Date()) {
  const endDate = new Date(startDate);
  endDate.setDate(endDate.getDate() + STRIPE_CONFIG.FREE_TRIAL_DAYS);
  return endDate;
}
__name(calculateTrialEndDate2, "calculateTrialEndDate");

// auth-utils.js
function base64UrlEncode(buffer) {
  let binary = "";
  const bytes = new Uint8Array(buffer);
  const len = bytes.byteLength;
  for (let i = 0; i < len; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}
__name(base64UrlEncode, "base64UrlEncode");
function base64UrlDecodeToArray(base64url) {
  const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/");
  const pad = base64.length % 4 === 2 ? "==" : base64.length % 4 === 3 ? "=" : "";
  const str = atob(base64 + pad);
  const bytes = new Uint8Array(str.length);
  for (let i = 0; i < str.length; i++) bytes[i] = str.charCodeAt(i);
  return bytes;
}
__name(base64UrlDecodeToArray, "base64UrlDecodeToArray");
function randomBytes(size = 16) {
  const array = new Uint8Array(size);
  crypto.getRandomValues(array);
  return array;
}
__name(randomBytes, "randomBytes");
async function derivePbkdf2(password, saltBytes, iterations = 1e5) {
  const enc = new TextEncoder();
  const keyMaterial = await crypto.subtle.importKey(
    "raw",
    enc.encode(password),
    "PBKDF2",
    false,
    ["deriveBits"]
  );
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", hash: "SHA-256", salt: saltBytes, iterations },
    keyMaterial,
    256
  );
  return new Uint8Array(bits);
}
__name(derivePbkdf2, "derivePbkdf2");
async function createPasswordHash(password) {
  const salt = randomBytes(16);
  const iterations = 1e5;
  const hashBytes = await derivePbkdf2(password, salt, iterations);
  return {
    passwordHash: base64UrlEncode(hashBytes),
    salt: base64UrlEncode(salt),
    iterations,
    algo: "PBKDF2-SHA256"
  };
}
__name(createPasswordHash, "createPasswordHash");
async function verifyPassword(password, user) {
  try {
    if (user && user.passwordHash && user.salt) {
      console.log("Attempting to verify password with new PBKDF2 hash.");
      const saltBytes = base64UrlDecodeToArray(user.salt);
      const iterations = user.iterations || 1e5;
      const hashBytes = await derivePbkdf2(password, saltBytes, iterations);
      const computed = base64UrlEncode(hashBytes);
      const result = computed === user.passwordHash;
      console.log(`PBKDF2 comparison result: ${result}`);
      if (!result) console.error("PBKDF2 comparison failed.");
      return result;
    }
    if (user && user.password) {
      console.log("Attempting to verify password with old SHA-256 hash.");
      const encoder = new TextEncoder();
      const data = encoder.encode(password);
      const hashBuffer = await crypto.subtle.digest("SHA-256", data);
      const hashArray = Array.from(new Uint8Array(hashBuffer));
      const hex = hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
      const result = hex === user.password;
      console.log(`SHA-256 comparison result: ${result}`);
      if (!result) console.error("SHA-256 comparison failed.");
      return result;
    }
    console.error("User object has no recognizable password format:", JSON.stringify(user));
    return false;
  } catch (e) {
    console.error("Password verification crashed:", e.stack);
    return false;
  }
}
__name(verifyPassword, "verifyPassword");
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
__name(upgradePasswordIfNeeded, "upgradePasswordIfNeeded");
async function generateToken(username, env) {
  const header = { alg: "HS256", typ: "JWT" };
  const payload = {
    username,
    exp: Math.floor(Date.now() / 1e3) + 7 * 24 * 60 * 60,
    // 7天有效期
    jti: crypto.randomUUID()
    // 增加一个唯一的ID，确保每次生成的token都不同
  };
  const enc = new TextEncoder();
  const secret = env && (env.JWT_SECRET || env.vars && env.vars.JWT_SECRET) || "dev-secret";
  const headerB64 = base64UrlEncode(enc.encode(JSON.stringify(header)));
  const payloadB64 = base64UrlEncode(enc.encode(JSON.stringify(payload)));
  const data = `${headerB64}.${payloadB64}`;
  const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("HMAC", key, enc.encode(data));
  const sigB64 = base64UrlEncode(signature);
  return `${data}.${sigB64}`;
}
__name(generateToken, "generateToken");
async function verifyToken(token, env) {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const [headerB64, payloadB64, sigB64] = parts;
    const enc = new TextEncoder();
    const secret = env && (env.JWT_SECRET || env.vars && env.vars.JWT_SECRET) || "dev-secret";
    const data = `${headerB64}.${payloadB64}`;
    const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["verify"]);
    const sig = base64UrlDecodeToArray(sigB64);
    const valid = await crypto.subtle.verify("HMAC", key, sig, enc.encode(data));
    if (!valid) return null;
    const payload = JSON.parse(atob(payloadB64));
    if (payload.exp && payload.exp < Math.floor(Date.now() / 1e3)) return null;
    return payload;
  } catch {
    return null;
  }
}
__name(verifyToken, "verifyToken");
function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization"
    }
  });
}
__name(jsonResponse, "jsonResponse");

// alipay-utils.js
async function importPrivateKey(pem) {
  const pemContents = pem.replace(/-----(BEGIN|END) (RSA )?PRIVATE KEY-----/g, "").replace(/\s+/g, "");
  const binaryDer = atob(pemContents);
  const buffer = new ArrayBuffer(binaryDer.length);
  const bytes = new Uint8Array(buffer);
  for (let i = 0; i < binaryDer.length; i++) {
    bytes[i] = binaryDer.charCodeAt(i);
  }
  return crypto.subtle.importKey(
    "pkcs8",
    buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    true,
    ["sign"]
  );
}
__name(importPrivateKey, "importPrivateKey");
async function importPublicKey(pem) {
  const pemContents = pem.replace(/-----(BEGIN|END) PUBLIC KEY-----/g, "").replace(/\s+/g, "");
  const binaryDer = atob(pemContents);
  const buffer = new ArrayBuffer(binaryDer.length);
  const bytes = new Uint8Array(buffer);
  for (let i = 0; i < binaryDer.length; i++) {
    bytes[i] = binaryDer.charCodeAt(i);
  }
  return crypto.subtle.importKey(
    "spki",
    buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    true,
    ["verify"]
  );
}
__name(importPublicKey, "importPublicKey");
function getSignStr(params) {
  const sortedKeys = Object.keys(params).sort();
  let signStr = "";
  for (const key of sortedKeys) {
    if (key === "sign" || params[key] === void 0 || params[key] === null || params[key] === "") {
      continue;
    }
    if (signStr.length > 0) {
      signStr += "&";
    }
    let value = String(params[key]);
    signStr += `${key}=${value}`;
  }
  console.log("\u7B7E\u540D\u5B57\u7B26\u4E32:", signStr);
  return signStr;
}
__name(getSignStr, "getSignStr");
async function generateSign(params, privateKey) {
  const signStr = getSignStr(params);
  const encoder = new TextEncoder();
  const data = encoder.encode(signStr);
  const signatureBuffer = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    privateKey,
    data
  );
  const binary = String.fromCharCode.apply(null, new Uint8Array(signatureBuffer));
  return btoa(binary);
}
__name(generateSign, "generateSign");
async function verifySign(params, sign, alipayPublicKey) {
  const signStr = getSignStr(params);
  const encoder = new TextEncoder();
  const data = encoder.encode(signStr);
  const binarySign = atob(sign);
  const signatureBuffer = new Uint8Array(binarySign.length);
  for (let i = 0; i < binarySign.length; i++) {
    signatureBuffer[i] = binarySign.charCodeAt(i);
  }
  return crypto.subtle.verify(
    { name: "RSASSA-PKCS1-v1_5" },
    alipayPublicKey,
    signatureBuffer,
    data
  );
}
__name(verifySign, "verifySign");

// alipay-login-functions.js
async function generateAlipayLoginUrl(env, platform) {
  try {
    console.log("\u751F\u6210\u652F\u4ED8\u5B9D\u767B\u5F55URL\u5F00\u59CB");
    let isMacOSApp = false;
    let callbackType = "web";
    if (platform === "macos") {
      isMacOSApp = true;
      callbackType = "macos";
    }
    console.log("\u5E73\u53F0\u68C0\u6D4B:", { platform, isMacOSApp, callbackType });
    console.log("\u73AF\u5883\u53D8\u91CF\u68C0\u67E5:", {
      hasAppId: !!env.ALIPAY_APP_ID,
      hasWorkerUrl: !!env.WORKER_URL,
      hasUsersKv: !!env.USERS_KV,
      isMacOSApp,
      callbackType
    });
    let state;
    try {
      state = crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).substring(2) + Date.now().toString(36);
    } catch (cryptoError) {
      console.warn("crypto.randomUUID\u4E0D\u53EF\u7528\uFF0C\u4F7F\u7528\u5907\u7528\u65B9\u6848:", cryptoError);
      state = Math.random().toString(36).substring(2) + Date.now().toString(36);
    }
    const appId = env.ALIPAY_APP_ID;
    if (!appId) {
      console.error("\u652F\u4ED8\u5B9D\u5E94\u7528ID\u672A\u914D\u7F6E");
      return jsonResponse({ error: "\u652F\u4ED8\u5B9D\u5E94\u7528ID\u672A\u914D\u7F6E" }, 500);
    }
    const workerUrl = env.WORKER_URL || "https://your-worker-url.workers.dev";
    console.log("\u4F7F\u7528worker URL:", workerUrl);
    let redirectUri;
    if (isMacOSApp) {
      redirectUri = encodeURIComponent(`${workerUrl}/api/auth/alipay/macos-callback`);
      console.log("macOS\u5E94\u7528\u4E13\u7528\u56DE\u8C03\u5730\u5740:", redirectUri);
    } else {
      redirectUri = encodeURIComponent(`${workerUrl}/api/auth/alipay/callback`);
      console.log("Web\u5E94\u7528\u6807\u51C6\u56DE\u8C03\u5730\u5740:", redirectUri);
    }
    const authUrl = `https://openauth.alipay.com/oauth2/publicAppAuthorize.htm?app_id=${appId}&scope=auth_user&redirect_uri=${redirectUri}&state=${state}`;
    console.log("\u751F\u6210\u7684\u6388\u6743URL:", authUrl);
    if (env.USERS_KV) {
      const stateData = {
        type: callbackType,
        timestamp: Date.now(),
        valid: true
      };
      await env.USERS_KV.put(`alipay_state:${state}`, JSON.stringify(stateData), { expirationTtl: 600 });
      console.log("state\u5DF2\u5B58\u50A8\u5230KV:", stateData);
    } else {
      console.warn("USERS_KV\u672A\u7ED1\u5B9A\uFF0C\u8DF3\u8FC7state\u5B58\u50A8");
    }
    const response = jsonResponse({
      authUrl,
      state,
      appId,
      platform: callbackType
    });
    console.log("\u54CD\u5E94\u6570\u636E:", { authUrl, state, appId, platform: callbackType });
    return response;
  } catch (error) {
    console.error("\u751F\u6210\u652F\u4ED8\u5B9D\u767B\u5F55URL\u5931\u8D25:", error);
    console.error("\u9519\u8BEF\u5806\u6808:", error.stack);
    return jsonResponse({ error: "\u751F\u6210\u652F\u4ED8\u5B9D\u767B\u5F55URL\u5931\u8D25: " + error.message }, 500);
  }
}
__name(generateAlipayLoginUrl, "generateAlipayLoginUrl");
async function getAlipayUserInfo(authCode, env) {
  const appId = env.ALIPAY_APP_ID;
  const privateKey = env.ALIPAY_PRIVATE_KEY;
  const alipayPublicKey = env.ALIPAY_PUBLIC_KEY;
  console.log("\u652F\u4ED8\u5B9D\u914D\u7F6E\u68C0\u67E5:", {
    hasAppId: !!appId,
    hasPrivateKey: !!privateKey,
    hasAlipayPublicKey: !!alipayPublicKey,
    appIdLength: appId ? appId.length : 0
  });
  try {
    console.log("\u83B7\u53D6\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F\uFF0C\u6388\u6743\u7801:", authCode);
    if (!appId || !privateKey || !alipayPublicKey) {
      console.warn("\u652F\u4ED8\u5B9D\u914D\u7F6E\u4E0D\u5B8C\u6574\uFF0C\u4F7F\u7528\u6A21\u62DF\u6570\u636E");
      const mockUserInfo = {
        user_id: "mock_alipay_user_" + Date.now(),
        // 使用当前时间戳生成唯一的模拟用户ID
        nick_name: "\u652F\u4ED8\u5B9D\u7528\u6237",
        avatar: "https://tfsimg.alipay.com/images/partner/T1kFldXk0rXXXXXXXX",
        province: "\u6D59\u6C5F\u7701",
        city: "\u676D\u5DDE\u5E02",
        gender: "M"
      };
      return mockUserInfo;
    }
    console.log("\u5F00\u59CB\u8C03\u7528\u652F\u4ED8\u5B9DAPI\u83B7\u53D6access_token...");
    const tokenResult = await getAccessToken(authCode, env);
    if (!tokenResult || tokenResult.code !== "10000") {
      console.error("\u83B7\u53D6access_token\u5931\u8D25:", tokenResult);
      throw new Error("\u652F\u4ED8\u5B9D\u6388\u6743\u5931\u8D25: " + (tokenResult?.msg || tokenResult?.sub_msg || "\u672A\u77E5\u9519\u8BEF"));
    }
    const { access_token, user_id } = tokenResult;
    console.log("\u6210\u529F\u83B7\u53D6access_token\u548Cuser_id:", { access_token, user_id });
    console.log("\u5F00\u59CB\u83B7\u53D6\u7528\u6237\u8BE6\u7EC6\u4FE1\u606F...");
    const userInfoResult = await getUserInfoWithToken(access_token, env);
    if (!userInfoResult || userInfoResult.code !== "10000") {
      console.error("\u83B7\u53D6\u7528\u6237\u4FE1\u606F\u5931\u8D25:", userInfoResult);
      return {
        user_id,
        nick_name: userInfoResult?.nick_name || "\u652F\u4ED8\u5B9D\u7528\u6237",
        avatar: userInfoResult?.avatar || "",
        province: userInfoResult?.province || "",
        city: userInfoResult?.city || "",
        gender: userInfoResult?.gender || "M"
      };
    }
    const userInfo = userInfoResult;
    console.log("\u6210\u529F\u83B7\u53D6\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F:", userInfo);
    return {
      user_id,
      // 使用从token获取的user_id（或open_id）
      nick_name: userInfo.nick_name || "\u652F\u4ED8\u5B9D\u7528\u6237",
      avatar: userInfo.avatar || "",
      province: userInfo.province || "",
      city: userInfo.city || "",
      gender: userInfo.gender || "M"
    };
  } catch (error) {
    console.error("\u83B7\u53D6\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F\u5931\u8D25:", error);
    throw error;
  }
}
__name(getAlipayUserInfo, "getAlipayUserInfo");
async function handleAlipayLogin(request, env) {
  try {
    const { auth_code, state } = await request.json();
    if (!auth_code) {
      return jsonResponse({ error: "\u7F3A\u5C11\u6388\u6743\u7801" }, 400);
    }
    if (state) {
      const storedState = await env.USERS_KV.get(`alipay_state:${state}`);
      if (!storedState) {
        return jsonResponse({ error: "\u65E0\u6548\u7684state\u53C2\u6570" }, 400);
      }
      await env.USERS_KV.delete(`alipay_state:${state}`);
    }
    const alipayUser = await getAlipayUserInfo(auth_code, env);
    const existingUser = await env.USERS_KV.get(`alipay_binding:${alipayUser.user_id}`);
    if (existingUser) {
      const userData = await env.USERS_KV.get(`user:${existingUser}`);
      if (userData) {
        const user = JSON.parse(userData);
        const token = await generateToken(user.username, env);
        return jsonResponse({
          token,
          username: user.username,
          isNewUser: false,
          loginMethod: "alipay",
          alipayUser: {
            userId: alipayUser.user_id,
            nickname: alipayUser.nick_name,
            avatar: alipayUser.avatar
          }
        });
      }
    }
    return jsonResponse({
      alipayUser,
      isNewUser: true,
      needsRegistration: true
    });
  } catch (error) {
    console.error("\u652F\u4ED8\u5B9D\u767B\u5F55\u5931\u8D25:", error);
    return jsonResponse({ error: "\u652F\u4ED8\u5B9D\u767B\u5F55\u5931\u8D25: " + error.message }, 500);
  }
}
__name(handleAlipayLogin, "handleAlipayLogin");
async function registerAlipayUser(request, env) {
  try {
    const { username, email, password, captcha, alipayUserId, alipayOpenId, alipayNickname, alipayAvatar } = await request.json();
    const normalizedEmail = email.toLowerCase().trim();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(normalizedEmail)) {
      return jsonResponse({ error: "\u90AE\u7BB1\u683C\u5F0F\u4E0D\u6B63\u786E" }, 400);
    }
    if (password.length < 6) {
      return jsonResponse({ error: "\u5BC6\u7801\u957F\u5EA6\u81F3\u5C116\u4F4D" }, 400);
    }
    if (!username || username.trim().length < 2) {
      return jsonResponse({ error: "\u7528\u6237\u540D\u81F3\u5C112\u4E2A\u5B57\u7B26" }, 400);
    }
    if (!captcha || captcha.length < 4) {
      return jsonResponse({ error: "\u8BF7\u8F93\u5165\u6709\u6548\u7684\u9A8C\u8BC1\u7801" }, 400);
    }
    const existingUser = await env.USERS_KV.get(`email_to_username:${normalizedEmail}`);
    if (existingUser) {
      return jsonResponse({ error: "\u8BE5\u90AE\u7BB1\u5DF2\u88AB\u6CE8\u518C" }, 400);
    }
    const existingAlipay = await env.USERS_KV.get(`alipay_binding:${alipayUserId}`);
    if (existingAlipay) {
      return jsonResponse({ error: "\u8BE5\u652F\u4ED8\u5B9D\u8D26\u53F7\u5DF2\u6CE8\u518C\u5176\u4ED6\u7528\u6237" }, 400);
    }
    const userId = generateUserId();
    const hashedPassword = await hashPassword(password);
    const userData = {
      id: userId,
      username: username.trim(),
      email: normalizedEmail,
      password: hashedPassword,
      alipayUserId,
      alipayOpenId,
      alipayNickname,
      alipayAvatar,
      alipayBoundAt: (/* @__PURE__ */ new Date()).toISOString(),
      createdAt: (/* @__PURE__ */ new Date()).toISOString(),
      updatedAt: (/* @__PURE__ */ new Date()).toISOString(),
      emailVerified: true,
      // 支付宝用户默认已验证
      membershipType: "free",
      membershipExpiresAt: null
    };
    await env.USERS_KV.put(`user:${username}`, JSON.stringify(userData));
    await env.USERS_KV.put(`email_to_username:${normalizedEmail}`, username);
    await env.USERS_KV.put(`alipay_binding:${alipayUserId}`, username);
    await env.USERS_KV.put(`user_alipay:${username}`, alipayUserId);
    const token = await generateToken(username, env);
    return jsonResponse({
      success: true,
      message: "\u6CE8\u518C\u6210\u529F",
      token,
      username: userData.username,
      email: userData.email
    });
  } catch (error) {
    console.error("\u652F\u4ED8\u5B9D\u7528\u6237\u6CE8\u518C\u5931\u8D25:", error);
    return jsonResponse({ error: "\u6CE8\u518C\u5931\u8D25: " + error.message }, 500);
  }
}
__name(registerAlipayUser, "registerAlipayUser");
async function sendRegistrationCaptcha(request, env) {
  try {
    const { alipayUserId, username, password, nickname, avatar, email } = await request.json();
    if (!alipayUserId || !username || !password) {
      return jsonResponse({ error: "\u7F3A\u5C11\u5FC5\u8981\u53C2\u6570" }, 400);
    }
    const existingUser = await env.USERS_KV.get(`user:${username}`);
    if (existingUser) {
      return jsonResponse({ error: "\u7528\u6237\u540D\u5DF2\u5B58\u5728" }, 400);
    }
    if (email) {
      const emailMapped = await env.USERS_KV.get(`email_to_username:${String(email).trim().toLowerCase()}`);
      if (emailMapped) {
        return jsonResponse({ error: "\u8BE5\u90AE\u7BB1\u5DF2\u88AB\u6CE8\u518C" }, 400);
      }
    }
    const existingBinding = await env.USERS_KV.get(`alipay_binding:${alipayUserId}`);
    if (existingBinding) {
      return jsonResponse({ error: "\u8BE5\u652F\u4ED8\u5B9D\u8D26\u53F7\u5DF2\u6CE8\u518C\u5176\u4ED6\u7528\u6237" }, 400);
    }
    const creds = await createPasswordHash(password);
    const trialEndDate = calculateTrialEndDate();
    const userData = {
      username,
      email: email ? String(email).trim().toLowerCase() : null,
      passwordHash: creds.passwordHash,
      salt: creds.salt,
      iterations: creds.iterations,
      algo: creds.algo,
      createdAt: (/* @__PURE__ */ new Date()).toISOString(),
      emailVerified: !!email,
      // 支付宝相关字段
      alipayUserId,
      alipayNickname: nickname || "\u652F\u4ED8\u5B9D\u7528\u6237",
      alipayAvatar: avatar || "",
      alipayBoundAt: (/* @__PURE__ */ new Date()).toISOString(),
      // 会员相关字段
      freeTrialEndDate: trialEndDate.toISOString(),
      membershipType: "trial",
      stripeCustomerId: null,
      subscriptionId: null
    };
    await env.USERS_KV.put(`user:${username}`, JSON.stringify(userData));
    if (userData.email) {
      await env.USERS_KV.put(`email_to_username:${userData.email}`, username);
    }
    await env.USERS_KV.put(`alipay_binding:${alipayUserId}`, username);
    await env.USERS_KV.put(`user_alipay:${username}`, alipayUserId);
    const token = await generateToken(username, env);
    return jsonResponse({
      token,
      username,
      message: "\u6CE8\u518C\u6210\u529F\uFF0C\u652F\u4ED8\u5B9D\u8D26\u53F7\u5DF2\u6CE8\u518C"
    }, 201);
  } catch (error) {
    console.error("\u652F\u4ED8\u5B9D\u6CE8\u518C\u5931\u8D25:", error);
    return jsonResponse({ error: "\u652F\u4ED8\u5B9D\u6CE8\u518C\u5931\u8D25: " + error.message }, 500);
  }
}
__name(sendRegistrationCaptcha, "sendRegistrationCaptcha");
async function checkEmailAvailability(request, env) {
  try {
    const { email } = await request.json();
    const normalizedEmail = email.toLowerCase().trim();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(normalizedEmail)) {
      return jsonResponse({ error: "\u90AE\u7BB1\u683C\u5F0F\u4E0D\u6B63\u786E" }, 400);
    }
    const existingUser = await env.USERS_KV.get(`user:${normalizedEmail}`);
    return jsonResponse({
      success: true,
      available: !existingUser,
      message: existingUser ? "\u8BE5\u90AE\u7BB1\u5DF2\u88AB\u6CE8\u518C" : "\u90AE\u7BB1\u53EF\u7528"
    });
  } catch (error) {
    console.error("\u90AE\u7BB1\u68C0\u67E5\u5931\u8D25:", error);
    return jsonResponse({ error: "\u90AE\u7BB1\u68C0\u67E5\u5931\u8D25: " + error.message }, 500);
  }
}
__name(checkEmailAvailability, "checkEmailAvailability");
async function handleMacOSAlipayCallback(request, env) {
  try {
    const url = new URL(request.url);
    const authCode = url.searchParams.get("auth_code");
    const state = url.searchParams.get("state");
    console.log("\u6536\u5230macOS\u5E94\u7528\u652F\u4ED8\u5B9D\u767B\u5F55\u56DE\u8C03:", { authCode, state });
    if (!authCode) {
      const redirectUrl2 = `globaldharma://error=missing_auth_code&error_message=${encodeURIComponent("\u7F3A\u5C11\u6388\u6743\u7801")}`;
      console.error("macOS\u652F\u4ED8\u5B9D\u56DE\u8C03\u7F3A\u5C11\u6388\u6743\u7801\uFF0C\u91CD\u5B9A\u5411\u5230\u5E94\u7528:", redirectUrl2);
      return Response.redirect(redirectUrl2, 302);
    }
    if (state) {
      const storedStateData = await env.USERS_KV.get(`alipay_state:${state}`);
      if (!storedStateData) {
        console.error("macOS\u652F\u4ED8\u5B9D\u56DE\u8C03\u65E0\u6548\u7684state\u53C2\u6570:", state);
        const redirectUrl2 = `globaldharma://error=invalid_state&error_message=${encodeURIComponent("\u767B\u5F55\u72B6\u6001\u65E0\u6548\uFF0C\u8BF7\u91CD\u65B0\u767B\u5F55")}`;
        return Response.redirect(redirectUrl2, 302);
      }
      try {
        const stateData = JSON.parse(storedStateData);
        if (stateData.type !== "macos") {
          console.warn("state\u7C7B\u578B\u4E0D\u5339\u914D\uFF0C\u671F\u671Bmacos\uFF0C\u5B9E\u9645:", stateData.type);
        }
      } catch (parseError) {
        console.warn("\u89E3\u6790state\u6570\u636E\u5931\u8D25:", parseError);
      }
      await env.USERS_KV.delete(`alipay_state:${state}`);
    }
    const alipayUser = await getAlipayUserInfo(authCode, env);
    console.log("macOS\u5E94\u7528\u83B7\u53D6\u5230\u7684\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F:", alipayUser);
    if (!alipayUser || !alipayUser.user_id) {
      console.error("macOS\u5E94\u7528\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F\u4E0D\u5B8C\u6574:", alipayUser);
      const redirectUrl2 = `globaldharma://error=invalid_alipay_user&error_message=${encodeURIComponent("\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F\u4E0D\u5B8C\u6574")}`;
      return Response.redirect(redirectUrl2, 302);
    }
    const existingUser = await env.USERS_KV.get(`alipay_binding:${alipayUser.user_id}`);
    if (existingUser) {
      const userData = await env.USERS_KV.get(`user:${existingUser}`);
      if (userData) {
        const user = JSON.parse(userData);
        const token = await generateToken(user.username, env);
        console.log("macOS\u5E94\u7528\u652F\u4ED8\u5B9D\u767B\u5F55\u6210\u529F\uFF0C\u7528\u6237\u5DF2\u6CE8\u518C:", user.username);
        const redirectUrl2 = `globaldharma://alipay_auth_code=${authCode}&state=${state}&token=${token}&username=${user.username}&isNewUser=false&loginMethod=alipay&alipay_user_id=${alipayUser.user_id}&alipay_nickname=${encodeURIComponent(alipayUser.nick_name || "")}&alipay_avatar=${encodeURIComponent(alipayUser.avatar || "")}`;
        console.log("macOS\u5E94\u7528\u652F\u4ED8\u5B9D\u767B\u5F55\u6210\u529F\uFF0C\u91CD\u5B9A\u5411\u5230\u5E94\u7528:", redirectUrl2);
        return Response.redirect(redirectUrl2, 302);
      }
    }
    console.log("macOS\u5E94\u7528\u65B0\u7528\u6237\u6216\u672A\u6CE8\u518C\u652F\u4ED8\u5B9D\u8D26\u53F7\uFF0C\u91CD\u5B9A\u5411\u5230\u5E94\u7528\u8FDB\u884C\u6CE8\u518C");
    const redirectUrl = `globaldharma://alipay_auth_code=${authCode}&state=${state}&isNewUser=true&needsRegistration=true&loginMethod=alipay&alipay_user_id=${alipayUser.user_id}&alipay_nickname=${encodeURIComponent(alipayUser.nick_name || "")}&alipay_avatar=${encodeURIComponent(alipayUser.avatar || "")}`;
    console.log("macOS\u5E94\u7528\u65B0\u7528\u6237\uFF0C\u91CD\u5B9A\u5411\u5230\u5E94\u7528\u8FDB\u884C\u6CE8\u518C:", redirectUrl);
    return Response.redirect(redirectUrl, 302);
  } catch (error) {
    console.error("macOS\u5E94\u7528\u652F\u4ED8\u5B9D\u56DE\u8C03\u5904\u7406\u5931\u8D25:", error);
    const redirectUrl = `globaldharma://error=callback_failed&error_message=${encodeURIComponent(error.message || "\u652F\u4ED8\u5B9D\u767B\u5F55\u5904\u7406\u5931\u8D25")}`;
    return Response.redirect(redirectUrl, 302);
  }
}
__name(handleMacOSAlipayCallback, "handleMacOSAlipayCallback");
async function handleAlipayCallback(request, env) {
  try {
    const url = new URL(request.url);
    const authCode = url.searchParams.get("auth_code");
    const state = url.searchParams.get("state");
    console.log("\u6536\u5230\u652F\u4ED8\u5B9D\u767B\u5F55\u56DE\u8C03:", { authCode, state });
    if (!authCode) {
      const redirectUrl2 = new URL("/index.html", request.url);
      redirectUrl2.hash = "error=missing_auth_code&error_message=\u7F3A\u5C11\u6388\u6743\u7801";
      return Response.redirect(redirectUrl2.toString(), 302);
    }
    if (state) {
      const storedState = await env.USERS_KV.get(`alipay_state:${state}`);
      if (!storedState) {
        console.error("\u65E0\u6548\u7684state\u53C2\u6570:", state);
        const redirectUrl2 = new URL("/index.html", request.url);
        redirectUrl2.hash = "error=invalid_state&error_message=\u767B\u5F55\u72B6\u6001\u65E0\u6548\uFF0C\u8BF7\u91CD\u65B0\u767B\u5F55";
        return Response.redirect(redirectUrl2.toString(), 302);
      }
      await env.USERS_KV.delete(`alipay_state:${state}`);
    }
    const alipayUser = await getAlipayUserInfo(authCode, env);
    console.log("\u83B7\u53D6\u5230\u7684\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F:", alipayUser);
    if (!alipayUser || !alipayUser.user_id) {
      console.error("\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F\u4E0D\u5B8C\u6574:", alipayUser);
      const redirectUrl2 = new URL("/index.html", request.url);
      redirectUrl2.hash = "error=invalid_alipay_user&error_message=\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F\u4E0D\u5B8C\u6574";
      return Response.redirect(redirectUrl2.toString(), 302);
    }
    const existingUser = await env.USERS_KV.get(`alipay_binding:${alipayUser.user_id}`);
    if (existingUser) {
      const userData = await env.USERS_KV.get(`user:${existingUser}`);
      if (userData) {
        const user = JSON.parse(userData);
        const token = await generateToken(user.username, env);
        const redirectUrl2 = new URL("/index.html", request.url);
        redirectUrl2.hash = `token=${token}&username=${user.username}&login_method=alipay`;
        console.log("\u652F\u4ED8\u5B9D\u767B\u5F55\u6210\u529F\uFF0C\u76F4\u63A5\u8DF3\u8F6C\u5230Flutter\u4E3B\u5E94\u7528:", redirectUrl2.toString());
        return Response.redirect(redirectUrl2.toString(), 302);
      }
    }
    const redirectUrl = new URL("/index.html", request.url);
    redirectUrl.hash = `alipay_auth_code=${authCode}&alipay_user_id=${alipayUser.user_id}&alipay_nickname=${encodeURIComponent(alipayUser.nick_name || "")}&alipay_avatar=${encodeURIComponent(alipayUser.avatar || "")}&needs_registration=true&login_method=alipay`;
    console.log("\u65B0\u7528\u6237\u6216\u672A\u6CE8\u518C\uFF0C\u76F4\u63A5\u8DF3\u8F6C\u5230Flutter\u4E3B\u5E94\u7528\u6CE8\u518C\u9875\u9762:", redirectUrl.toString());
    return Response.redirect(redirectUrl.toString(), 302);
  } catch (error) {
    console.error("\u652F\u4ED8\u5B9D\u56DE\u8C03\u5904\u7406\u5931\u8D25:", error);
    const redirectUrl = new URL("/index.html", request.url);
    redirectUrl.hash = `error=callback_failed&error_message=${encodeURIComponent(error.message || "\u652F\u4ED8\u5B9D\u767B\u5F55\u5904\u7406\u5931\u8D25")}`;
    return Response.redirect(redirectUrl.toString(), 302);
  }
}
__name(handleAlipayCallback, "handleAlipayCallback");
async function getAccessToken(authCode, env) {
  try {
    const appId = env.ALIPAY_APP_ID;
    const privateKey = env.ALIPAY_PRIVATE_KEY;
    const timestamp = (/* @__PURE__ */ new Date()).toLocaleString("zh-CN", {
      timeZone: "Asia/Shanghai",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hour12: false
    }).replace(/\//g, "-");
    const params = {
      app_id: appId,
      method: "alipay.system.oauth.token",
      format: "JSON",
      charset: "utf-8",
      sign_type: "RSA2",
      timestamp,
      version: "1.0",
      grant_type: "authorization_code",
      code: authCode
    };
    const privateKeyObj = await importPrivateKey(privateKey);
    const sign = await generateSign(params, privateKeyObj);
    params.sign = sign;
    console.log("\u751F\u6210\u7B7E\u540D:", sign);
    console.log("\u83B7\u53D6access_token\u8BF7\u6C42\u53C2\u6570:", params);
    const gatewayUrl = env.ALIPAY_USE_SANDBOX === "true" ? "https://openapi-sandbox.dl.alipaydev.com/gateway.do" : "https://openapi.alipay.com/gateway.do";
    const response = await fetch(gatewayUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded;charset=utf-8"
      },
      body: new URLSearchParams(params).toString()
    });
    if (!response.ok) {
      throw new Error(`\u652F\u4ED8\u5B9DAPI\u8BF7\u6C42\u5931\u8D25: ${response.status} ${response.statusText}`);
    }
    const result = await response.json();
    console.log("\u652F\u4ED8\u5B9Daccess_token\u54CD\u5E94:", result);
    if (result.alipay_system_oauth_token_response) {
      const tokenResponse = result.alipay_system_oauth_token_response;
      if (tokenResponse.access_token) {
        return {
          code: "10000",
          access_token: tokenResponse.access_token,
          user_id: tokenResponse.user_id || tokenResponse.open_id,
          // 支付宝可能返回user_id或open_id
          expires_in: tokenResponse.expires_in,
          refresh_token: tokenResponse.refresh_token,
          re_expires_in: tokenResponse.re_expires_in
        };
      } else if (tokenResponse.code) {
        return {
          code: tokenResponse.code,
          msg: tokenResponse.msg,
          sub_code: tokenResponse.sub_code,
          sub_msg: tokenResponse.sub_msg
        };
      } else {
        return {
          code: "UNKNOWN_ERROR",
          msg: "\u652F\u4ED8\u5B9DAPI\u8FD4\u56DE\u672A\u77E5\u54CD\u5E94\u683C\u5F0F",
          sub_code: "unknown",
          sub_msg: JSON.stringify(tokenResponse)
        };
      }
    } else {
      throw new Error("\u652F\u4ED8\u5B9DAPI\u54CD\u5E94\u683C\u5F0F\u9519\u8BEF");
    }
  } catch (error) {
    console.error("\u83B7\u53D6access_token\u5931\u8D25:", error);
    throw error;
  }
}
__name(getAccessToken, "getAccessToken");
async function getUserInfoWithToken(accessToken, env) {
  try {
    const appId = env.ALIPAY_APP_ID;
    const privateKey = env.ALIPAY_PRIVATE_KEY;
    const timestamp = (/* @__PURE__ */ new Date()).toLocaleString("zh-CN", {
      timeZone: "Asia/Shanghai",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hour12: false
    }).replace(/\//g, "-");
    const params = {
      app_id: appId,
      method: "alipay.user.info.share",
      format: "JSON",
      charset: "utf-8",
      sign_type: "RSA2",
      timestamp,
      version: "1.0",
      auth_token: accessToken
    };
    const privateKeyObj = await importPrivateKey(privateKey);
    const sign = await generateSign(params, privateKeyObj);
    params.sign = sign;
    console.log("\u83B7\u53D6\u7528\u6237\u4FE1\u606F\u8BF7\u6C42\u53C2\u6570:", params);
    const gatewayUrl = env.ALIPAY_USE_SANDBOX === "true" ? "https://openapi-sandbox.dl.alipaydev.com/gateway.do" : "https://openapi.alipay.com/gateway.do";
    const response = await fetch(gatewayUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded;charset=utf-8"
      },
      body: new URLSearchParams(params).toString()
    });
    if (!response.ok) {
      throw new Error(`\u652F\u4ED8\u5B9DAPI\u8BF7\u6C42\u5931\u8D25: ${response.status} ${response.statusText}`);
    }
    const result = await response.json();
    console.log("\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F\u54CD\u5E94:", result);
    if (result.alipay_user_info_share_response) {
      const userInfoResponse = result.alipay_user_info_share_response;
      if (userInfoResponse.code === "10000") {
        return {
          code: "10000",
          nick_name: userInfoResponse.nick_name || "\u652F\u4ED8\u5B9D\u7528\u6237",
          avatar: userInfoResponse.avatar || "",
          province: userInfoResponse.province || "",
          city: userInfoResponse.city || "",
          gender: userInfoResponse.gender || "M",
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
      throw new Error("\u652F\u4ED8\u5B9DAPI\u54CD\u5E94\u683C\u5F0F\u9519\u8BEF");
    }
  } catch (error) {
    console.error("\u83B7\u53D6\u7528\u6237\u4FE1\u606F\u5931\u8D25:", error);
    throw error;
  }
}
__name(getUserInfoWithToken, "getUserInfoWithToken");

// alipay-config.js
var ALIPAY_CONFIG = {
  // 支付宝网关地址
  GATEWAY_URL: "https://openapi.alipay.com/gateway.do",
  // 支付宝沙箱网关地址
  SANDBOX_GATEWAY_URL: "https://openapi-sandbox.dl.alipaydev.com/gateway.do",
  // 获取当前环境的网关地址
  getGatewayUrl: /* @__PURE__ */ __name(function() {
    return this.APP_CONFIG.sandbox ? this.SANDBOX_GATEWAY_URL : this.GATEWAY_URL;
  }, "getGatewayUrl"),
  // 回调地址配置
  CALLBACK_CONFIG: {
    // 应用网关地址 - 用于接收支付宝异步通知
    // 注意：这个地址必须是外网可访问的，本地开发时可以使用 ngrok 等工具进行内网穿透
    NOTIFY_URL: "/api/alipay/notify",
    // 授权回调地址 - 用户支付完成后跳转回应用的地址
    RETURN_URL: "/payment-success.html",
    // 支付宝登录回调地址
    LOGIN_RETURN_URL: "/login.html"
  },
  // 当面付产品码
  PRODUCT_CODE: "FACE_TO_FACE_PAYMENT",
  // 会员价格配置已移至Worker配置统一管理
  // MEMBERSHIP_PRICES: { ... }
  CURRENCY: "CNY",
  // 订单超时时间 (分钟)
  TIMEOUT_EXPRESS: "30m",
  // 应用配置 (将从环境变量安全加载)
  APP_CONFIG: {
    charset: "utf-8",
    sign_type: "RSA2",
    version: "1.0",
    sandbox: false
    // 沙箱环境开关, 将由环境变量 ALIPAY_SANDBOX 控制
    // app_id, merchant_private_key, alipay_public_key 将从 env 中动态获取
    // notify_url, return_url 将在 worker 中动态构建或从 env 获取
  },
  // 登录授权配置
  LOGIN: {
    SCOPE: "auth_user",
    // 授权范围：auth_user（获取用户信息）或 auth_base（静默授权）
    STATE_TIMEOUT: 600,
    // state参数有效期（秒）
    GATEWAY_URL: "https://openapi.alipay.com/gateway.do",
    SANDBOX_GATEWAY_URL: "https://openapi-sandbox.dl.alipaydev.com/gateway.do"
  }
};

// worker.js
var ADMIN_EMAIL = "1315518325@qq.com";
var ADMIN_PRICES = {
  "monthly": "0.01",
  "quarterly": "0.01",
  "yearly": "0.01"
};
var WORKER_MEMBERSHIP_PLANS = {
  "monthly": {
    name: "\u6708\u5EA6\u4F1A\u5458",
    duration: 30 * 24 * 60 * 60 * 1e3,
    // 30天，毫秒
    price: "21.00",
    adminPrice: "0.01",
    features: ["\u57FA\u7840\u529F\u80FD\u8BBF\u95EE", "\u6BCF\u65E510\u6B21\u4F7F\u7528\u989D\u5EA6", "\u90AE\u4EF6\u652F\u6301"]
  },
  "quarterly": {
    name: "\u5B63\u5EA6\u4F1A\u5458",
    duration: 90 * 24 * 60 * 60 * 1e3,
    // 90天，毫秒
    price: "63.00",
    adminPrice: "0.01",
    features: ["\u57FA\u7840\u529F\u80FD\u8BBF\u95EE", "\u6BCF\u65E530\u6B21\u4F7F\u7528\u989D\u5EA6", "\u90AE\u4EF6\u652F\u6301", "\u4F18\u5148\u5BA2\u670D"]
  },
  "yearly": {
    name: "\u5E74\u5EA6\u4F1A\u5458",
    duration: 365 * 24 * 60 * 60 * 1e3,
    // 365天，毫秒
    price: "252.00",
    adminPrice: "0.01",
    features: ["\u57FA\u7840\u529F\u80FD\u8BBF\u95EE", "\u6BCF\u65E5100\u6B21\u4F7F\u7528\u989D\u5EA6", "\u90AE\u4EF6\u652F\u6301", "\u4F18\u5148\u5BA2\u670D", "\u4E13\u5C5E\u529F\u80FD"]
  }
};
var REDEEM_CODE_TYPES = {
  "trial_7": {
    name: "7\u5929\u8BD5\u7528",
    days: 7,
    type: "trial"
  },
  "monthly": {
    name: "\u6708\u5EA6\u4F1A\u5458",
    days: 30,
    type: "premium"
  },
  "quarterly": {
    name: "\u5B63\u5EA6\u4F1A\u5458",
    days: 90,
    type: "premium"
  },
  "yearly": {
    name: "\u5E74\u5EA6\u4F1A\u5458",
    days: 365,
    type: "premium"
  }
};
function isAdmin(email) {
  return email && email.toLowerCase() === ADMIN_EMAIL.toLowerCase();
}
__name(isAdmin, "isAdmin");
function generateRedeemCode() {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let result = "";
  for (let i = 0; i < 12; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}
__name(generateRedeemCode, "generateRedeemCode");
var corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, Range",
  "Content-Type": "application/json"
};
function generateVerificationCode() {
  return Math.floor(1e5 + Math.random() * 9e5).toString();
}
__name(generateVerificationCode, "generateVerificationCode");
async function sendEmail(to, subject, body, env) {
  console.log("\u5F00\u59CB\u53D1\u9001\u90AE\u4EF6\u6D41\u7A0B:", { to, subject });
  let fromEmail = "onboarding@resend.dev";
  if (env && env.vars && env.vars.FROM_EMAIL) fromEmail = env.vars.FROM_EMAIL;
  else if (env && env.FROM_EMAIL) fromEmail = env.FROM_EMAIL;
  console.log("sendEmail \u8C03\u8BD5\u4FE1\u606F:", {
    to,
    subject,
    bodyLength: body ? body.length : 0,
    fromEmail,
    hasEnv: !!env,
    hasResendKey: !!(env && env.RESEND_API_KEY),
    resendKeyLength: env && env.RESEND_API_KEY ? env.RESEND_API_KEY.length : "N/A",
    hasEmail: !!(env && env.EMAIL),
    hasMailChannels: !!(env && env.MAILCHANNELS_API_KEY),
    envVars: env && env.vars ? Object.keys(env.vars) : "N/A",
    envKeys: env ? Object.keys(env) : "N/A"
  });
  if (!to || !subject || !body) {
    console.error("\u90AE\u4EF6\u53C2\u6570\u4E0D\u5B8C\u6574:", { to: !!to, subject: !!subject, body: !!body });
    return { ok: false, error: "\u90AE\u4EF6\u53C2\u6570\u4E0D\u5B8C\u6574" };
  }
  if (env && env.RESEND_API_KEY) {
    try {
      const apiKey = env.RESEND_API_KEY;
      console.log("\u5C1D\u8BD5\u4F7F\u7528 Resend \u53D1\u9001\u90AE\u4EF6:", { to, fromEmail, apiKeyLength: apiKey.length });
      const payload = {
        from: fromEmail,
        to: [to],
        // Resend 要求数组格式
        subject,
        text: body,
        html: `<div style="font-family: 'Microsoft YaHei', sans-serif; line-height: 1.6; padding: 20px; background-color: #f9f9f9; border-radius: 8px;">${body.replace(/\n/g, "<br>")}</div>`
      };
      console.log("Resend \u8BF7\u6C42\u8F7D\u8377:", JSON.stringify(payload, null, 2));
      const resp = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify(payload)
      });
      console.log("Resend API \u54CD\u5E94\u72B6\u6001:", resp.status, resp.statusText);
      if (resp.ok) {
        const respData = await resp.json();
        console.log("\u90AE\u4EF6\u53D1\u9001\u6210\u529F(Resend):", { to, subject, respData });
        return { ok: true, service: "Resend", data: respData };
      }
      const errBody = await resp.text();
      console.error("Resend \u53D1\u9001\u5931\u8D25:", resp.status, errBody);
      if (resp.status === 401 || resp.status === 403) {
        return { ok: false, error: `Resend\u8BA4\u8BC1\u5931\u8D25: ${errBody}` };
      }
    } catch (e) {
      console.error("Resend \u8C03\u7528\u5F02\u5E38:", String(e && (e.message || e)));
      console.error("Resend \u5F02\u5E38\u5806\u6808:", e.stack);
    }
  } else {
    console.log("Resend API Key \u672A\u627E\u5230\uFF0C\u8DF3\u8FC7 Resend \u670D\u52A1");
  }
  if (env && env.EMAIL) {
    try {
      console.log("\u5C1D\u8BD5\u4F7F\u7528 Cloudflare SendEmail \u53D1\u9001\u90AE\u4EF6:", { to, fromEmail });
      const message = new EmailMessage(fromEmail, to, subject, body);
      await env.EMAIL.send(message);
      console.log("\u90AE\u4EF6\u53D1\u9001\u6210\u529F(Cloudflare):", { to, subject });
      return { ok: true, service: "Cloudflare" };
    } catch (e) {
      const errText = String(e && (e.message || e));
      console.error("Cloudflare \u90AE\u4EF6\u53D1\u9001\u5931\u8D25:", errText);
      console.error("Cloudflare \u5F02\u5E38\u5806\u6808:", e.stack);
    }
  } else {
    console.log("Cloudflare EMAIL \u7ED1\u5B9A\u672A\u627E\u5230\uFF0C\u8DF3\u8FC7 Cloudflare \u670D\u52A1");
  }
  if (env && env.MAILCHANNELS_API_KEY) {
    try {
      const mcKey = env.MAILCHANNELS_API_KEY;
      console.log("\u5C1D\u8BD5\u4F7F\u7528 MailChannels \u53D1\u9001\u90AE\u4EF6:", { to, fromEmail, keyLength: mcKey.length });
      const payload = {
        personalizations: [{ to: [{ email: to }] }],
        from: { email: fromEmail, name: "Fabushi" },
        subject,
        content: [
          { type: "text/plain; charset=utf-8", value: body },
          { type: "text/html; charset=utf-8", value: `<div style="font-family: 'Microsoft YaHei', sans-serif; line-height: 1.6;">${body.replace(/\n/g, "<br>")}</div>` }
        ]
      };
      const authHeadersList = [
        { "Authorization": `Bearer ${mcKey}`, "Content-Type": "application/json" },
        { "X-Api-Key": mcKey, "Content-Type": "application/json" }
      ];
      for (const headers of authHeadersList) {
        try {
          console.log("\u5C1D\u8BD5 MailChannels \u8BA4\u8BC1\u65B9\u5F0F:", Object.keys(headers));
          const resp = await fetch("https://api.mailchannels.net/tx/v1/send", {
            method: "POST",
            headers,
            body: JSON.stringify(payload)
          });
          console.log("MailChannels API \u54CD\u5E94\u72B6\u6001:", resp.status, resp.statusText);
          if (resp.status === 202 || resp.status === 200) {
            const respData = await resp.text();
            console.log("\u90AE\u4EF6\u53D1\u9001\u6210\u529F(MailChannels):", { to, subject, respData });
            return { ok: true, service: "MailChannels" };
          }
          const errText = await resp.text();
          console.error("MailChannels \u53D1\u9001\u5931\u8D25:", resp.status, errText);
          if (!(resp.status === 401 || resp.status === 403)) break;
        } catch (e) {
          console.error("MailChannels \u8C03\u7528\u5F02\u5E38:", String(e && (e.message || e)));
          console.error("MailChannels \u5F02\u5E38\u5806\u6808:", e.stack);
        }
      }
    } catch (e) {
      console.error("MailChannels \u6574\u4F53\u5F02\u5E38:", String(e && (e.message || e)));
    }
  } else {
    console.log("MailChannels API Key \u672A\u627E\u5230\uFF0C\u8DF3\u8FC7 MailChannels \u670D\u52A1");
  }
  console.error("\u6240\u6709\u90AE\u4EF6\u670D\u52A1\u90FD\u5931\u8D25\u4E86");
  return { ok: false, error: "\u6240\u6709\u90AE\u7BB1\u670D\u52A1\u90FD\u4E0D\u53EF\u7528\uFF0C\u8BF7\u68C0\u67E5 RESEND_API_KEY\u3001EMAIL \u6216 MAILCHANNELS_API_KEY \u914D\u7F6E" };
}
__name(sendEmail, "sendEmail");
async function handleSendVerificationCode(request, env, ctx) {
  try {
    console.log("\u5F00\u59CB\u5904\u7406\u9A8C\u8BC1\u7801\u53D1\u9001\u8BF7\u6C42...");
    let requestBody;
    try {
      requestBody = await request.json();
      console.log("\u8BF7\u6C42\u4F53\u89E3\u6790\u6210\u529F:", requestBody);
    } catch (parseError) {
      console.error("\u8BF7\u6C42\u4F53\u89E3\u6790\u5931\u8D25:", parseError);
      return jsonResponse({ error: "\u8BF7\u6C42\u683C\u5F0F\u9519\u8BEF" }, 400);
    }
    let { email, type = "register" } = requestBody;
    console.log("\u63D0\u53D6\u53C2\u6570:", { email, type });
    if (!email) {
      console.error("\u90AE\u7BB1\u5730\u5740\u4E3A\u7A7A");
      return jsonResponse({ error: "\u90AE\u7BB1\u5730\u5740\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
    }
    email = String(email).trim().toLowerCase();
    console.log("\u5904\u7406\u540E\u7684\u90AE\u7BB1:", email);
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      console.error("\u90AE\u7BB1\u683C\u5F0F\u65E0\u6548:", email);
      return jsonResponse({ error: "\u90AE\u7BB1\u683C\u5F0F\u4E0D\u6B63\u786E" }, 400);
    }
    console.log("\u68C0\u67E5\u73AF\u5883\u53D8\u91CF:", {
      hasEnv: !!env,
      hasUsersKV: !!(env && env.USERS_KV),
      hasResendKey: !!(env && env.RESEND_API_KEY),
      hasEmail: !!(env && env.EMAIL)
    });
    if (!env || !env.USERS_KV) {
      console.error("\u73AF\u5883\u53D8\u91CF\u914D\u7F6E\u9519\u8BEF");
      return jsonResponse({ error: "\u670D\u52A1\u914D\u7F6E\u9519\u8BEF" }, 500);
    }
    const rateKey = `rate:verify:${email}`;
    console.log("\u68C0\u67E5\u9891\u7387\u9650\u5236:", rateKey);
    try {
      const recent = await env.USERS_KV.get(rateKey);
      if (recent) {
        console.log("\u9891\u7387\u9650\u5236\u89E6\u53D1:", email);
        return jsonResponse({ error: "\u8BF7\u6C42\u8FC7\u4E8E\u9891\u7E41\uFF0C\u8BF7\u7A0D\u540E\u518D\u8BD5" }, 429);
      }
    } catch (kvError) {
      console.error("KV\u5B58\u50A8\u8BBF\u95EE\u9519\u8BEF:", kvError);
      return jsonResponse({ error: "\u5B58\u50A8\u670D\u52A1\u9519\u8BEF" }, 500);
    }
    if (type === "register") {
      console.log("\u68C0\u67E5\u90AE\u7BB1\u662F\u5426\u5DF2\u6CE8\u518C:", email);
      try {
        const exists = await env.USERS_KV.get(`email_to_username:${email}`);
        if (exists) {
          console.log("\u90AE\u7BB1\u5DF2\u88AB\u6CE8\u518C:", email);
          return jsonResponse({ error: "\u8BE5\u90AE\u7BB1\u5DF2\u88AB\u6CE8\u518C" }, 400);
        }
      } catch (kvError) {
        console.error("\u68C0\u67E5\u90AE\u7BB1\u6CE8\u518C\u72B6\u6001\u65F6\u51FA\u9519:", kvError);
      }
    }
    if (type === "forgot") {
      console.log("\u68C0\u67E5\u90AE\u7BB1\u662F\u5426\u5B58\u5728:", email);
      try {
        let exists = await env.USERS_KV.get(`email_to_username:${email}`);
        if (!exists) {
          console.log("\u5C1D\u8BD5\u56DE\u586B\u90AE\u7BB1\u6620\u5C04...");
          const users = await env.USERS_KV.list({ prefix: "user:" });
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
          console.log("\u90AE\u7BB1\u672A\u6CE8\u518C:", email);
          return jsonResponse({ error: "\u8BE5\u90AE\u7BB1\u672A\u6CE8\u518C" }, 400);
        }
      } catch (kvError) {
        console.error("\u68C0\u67E5\u90AE\u7BB1\u5B58\u5728\u72B6\u6001\u65F6\u51FA\u9519:", kvError);
        return jsonResponse({ error: "\u5B58\u50A8\u670D\u52A1\u9519\u8BEF" }, 500);
      }
    }
    const code = generateVerificationCode();
    const expiry = Date.now() + 10 * 60 * 1e3;
    console.log("\u751F\u6210\u9A8C\u8BC1\u7801:", { code, expiry });
    try {
      await env.USERS_KV.put(`verify:${email}`, JSON.stringify({ code, expiry, type }));
      await env.USERS_KV.put(rateKey, "1", { expirationTtl: 60 });
      console.log("\u9A8C\u8BC1\u7801\u5B58\u50A8\u6210\u529F");
    } catch (kvError) {
      console.error("\u9A8C\u8BC1\u7801\u5B58\u50A8\u5931\u8D25:", kvError);
      return jsonResponse({ error: "\u5B58\u50A8\u670D\u52A1\u9519\u8BEF" }, 500);
    }
    const subject = type === "register" ? "\u6CE8\u518C\u9A8C\u8BC1\u7801" : "\u5BC6\u7801\u91CD\u7F6E\u9A8C\u8BC1\u7801";
    const body = `\u60A8\u7684\u9A8C\u8BC1\u7801\u662F\uFF1A${code}
\u6709\u6548\u671F10\u5206\u949F\uFF0C\u8BF7\u5C3D\u5FEB\u4F7F\u7528\u3002
\u5982\u975E\u672C\u4EBA\u64CD\u4F5C\uFF0C\u8BF7\u5FFD\u7565\u6B64\u90AE\u4EF6\u3002`;
    console.log("\u5F00\u59CB\u5C06\u90AE\u4EF6\u4EFB\u52A1\u63A8\u5165\u540E\u53F0...");
    ctx.waitUntil(
      sendEmail(email, subject, body, env).then((sent) => {
        if (!sent.ok) {
          console.error(`\u540E\u53F0\u90AE\u4EF6\u53D1\u9001\u5931\u8D25 to ${email}:`, sent.error);
        } else {
          console.log(`\u540E\u53F0\u90AE\u4EF6\u53D1\u9001\u6210\u529F to ${email} via ${sent.service || "N/A"}`);
        }
      }).catch((error) => {
        console.error(`\u540E\u53F0\u90AE\u4EF6\u53D1\u9001\u5F02\u5E38 to ${email}:`, error);
      })
    );
    console.log("\u9A8C\u8BC1\u7801\u53D1\u9001\u8BF7\u6C42\u5DF2\u63A5\u53D7\uFF0C\u7ACB\u5373\u8FD4\u56DE\u54CD\u5E94\u3002");
    return jsonResponse({ message: "\u9A8C\u8BC1\u7801\u5DF2\u53D1\u9001\uFF0C\u8BF7\u67E5\u6536\u90AE\u4EF6\u3002" });
  } catch (error) {
    console.error("\u53D1\u9001\u9A8C\u8BC1\u7801\u5931\u8D25\uFF0C\u8BE6\u7EC6\u9519\u8BEF:", error);
    console.error("\u9519\u8BEF\u5806\u6808:", error.stack);
    return jsonResponse({ error: `\u53D1\u9001\u9A8C\u8BC1\u7801\u5931\u8D25: ${error.message}` }, 500);
  }
}
__name(handleSendVerificationCode, "handleSendVerificationCode");
async function handleVerifyCode(request, env) {
  try {
    console.log("\u5F00\u59CB\u9A8C\u8BC1\u9A8C\u8BC1\u7801...");
    let { email, code } = await request.json();
    console.log("\u9A8C\u8BC1\u7801\u9A8C\u8BC1\u8BF7\u6C42:", { email, code });
    if (!email || !code) {
      console.error("\u9A8C\u8BC1\u7801\u9A8C\u8BC1\u7F3A\u5C11\u5B57\u6BB5:", { email: !!email, code: !!code });
      return jsonResponse({ error: "\u90AE\u7BB1\u548C\u9A8C\u8BC1\u7801\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
    }
    email = String(email).trim().toLowerCase();
    console.log("\u4ECEKV\u5B58\u50A8\u83B7\u53D6\u9A8C\u8BC1\u7801\u6570\u636E...");
    const verifyData = await env.USERS_KV.get(`verify:${email}`);
    console.log("\u9A8C\u8BC1\u7801\u6570\u636E\u72B6\u6001:", { email, hasVerifyData: !!verifyData });
    if (!verifyData) {
      console.error("\u9A8C\u8BC1\u7801\u4E0D\u5B58\u5728\u6216\u5DF2\u8FC7\u671F:", email);
      return jsonResponse({ error: "\u9A8C\u8BC1\u7801\u4E0D\u5B58\u5728\u6216\u5DF2\u8FC7\u671F" }, 400);
    }
    const { code: storedCode, expiry } = JSON.parse(verifyData);
    console.log("\u89E3\u6790\u9A8C\u8BC1\u7801\u6570\u636E:", { storedCode, expiry, currentTime: Date.now() });
    if (Date.now() > expiry) {
      console.error("\u9A8C\u8BC1\u7801\u5DF2\u8FC7\u671F:", { email, expiry, currentTime: Date.now() });
      await env.USERS_KV.put(`verify:${email}`, null);
      return jsonResponse({ error: "\u9A8C\u8BC1\u7801\u5DF2\u8FC7\u671F" }, 400);
    }
    if (code !== storedCode) {
      console.error("\u9A8C\u8BC1\u7801\u4E0D\u5339\u914D:", { email, providedCode: code, storedCode });
      return jsonResponse({ error: "\u9A8C\u8BC1\u7801\u9519\u8BEF" }, 400);
    }
    console.log("\u9A8C\u8BC1\u7801\u9A8C\u8BC1\u901A\u8FC7\uFF0C\u6807\u8BB0\u90AE\u7BB1\u4E3A\u5DF2\u9A8C\u8BC1...");
    await env.USERS_KV.put(`verified:${email}`, "true", { expirationTtl: 30 * 60 });
    console.log("\u9A8C\u8BC1\u7801\u9A8C\u8BC1\u6210\u529F:", email);
    return jsonResponse({ message: "\u9A8C\u8BC1\u7801\u6B63\u786E" });
  } catch (error) {
    console.error("\u9A8C\u8BC1\u9A8C\u8BC1\u7801\u5931\u8D25\uFF0C\u8BE6\u7EC6\u9519\u8BEF:", error);
    console.error("\u9519\u8BEF\u5806\u6808:", error.stack);
    return jsonResponse({ error: `\u9A8C\u8BC1\u9A8C\u8BC1\u7801\u5931\u8D25: ${error.message}` }, 500);
  }
}
__name(handleVerifyCode, "handleVerifyCode");
async function handleRegister(request, env) {
  try {
    console.log("\u5F00\u59CB\u5904\u7406\u6CE8\u518C\u8BF7\u6C42...");
    let { username, email, password, verificationCode } = await request.json();
    console.log("\u6CE8\u518C\u8BF7\u6C42\u6570\u636E:", { username, email, passwordLength: password?.length, verificationCode });
    if (!username || !email || !password || !verificationCode) {
      const missingFields = [];
      if (!username) missingFields.push("username");
      if (!email) missingFields.push("email");
      if (!password) missingFields.push("password");
      if (!verificationCode) missingFields.push("verificationCode");
      console.error("\u7F3A\u5C11\u5FC5\u8981\u5B57\u6BB5:", missingFields);
      return jsonResponse({ error: `\u7F3A\u5C11\u5FC5\u8981\u5B57\u6BB5: ${missingFields.join(", ")}` }, 400);
    }
    username = String(username).trim();
    email = String(email).trim().toLowerCase();
    console.log("\u5904\u7406\u540E\u7684\u6570\u636E:", { username, email, passwordLength: password.length, verificationCode });
    if (!/^[a-zA-Z0-9_]{3,20}$/.test(username)) {
      console.error("\u7528\u6237\u540D\u683C\u5F0F\u65E0\u6548:", username);
      return jsonResponse({ error: "\u7528\u6237\u540D\u9700\u4E3A3-20\u4F4D\u5B57\u6BCD\u3001\u6570\u5B57\u6216\u4E0B\u5212\u7EBF" }, 400);
    }
    if (password.length < 8) {
      console.error("\u5BC6\u7801\u957F\u5EA6\u4E0D\u8DB3:", password.length);
      return jsonResponse({ error: "\u5BC6\u7801\u957F\u5EA6\u81F3\u5C118\u4E2A\u5B57\u7B26" }, 400);
    }
    if (!/[A-Z]/.test(password)) {
      console.error("\u5BC6\u7801\u7F3A\u5C11\u5927\u5199\u5B57\u6BCD");
      return jsonResponse({ error: "\u5BC6\u7801\u5FC5\u987B\u5305\u542B\u5927\u5199\u5B57\u6BCD" }, 400);
    }
    if (!/[a-z]/.test(password)) {
      console.error("\u5BC6\u7801\u7F3A\u5C11\u5C0F\u5199\u5B57\u6BCD");
      return jsonResponse({ error: "\u5BC6\u7801\u5FC5\u987B\u5305\u542B\u5C0F\u5199\u5B57\u6BCD" }, 400);
    }
    if (!/\d/.test(password)) {
      console.error("\u5BC6\u7801\u7F3A\u5C11\u6570\u5B57");
      return jsonResponse({ error: "\u5BC6\u7801\u5FC5\u987B\u5305\u542B\u6570\u5B57" }, 400);
    }
    console.log("\u6B63\u5728\u9A8C\u8BC1\u9A8C\u8BC1\u7801...");
    const verifyData = await env.USERS_KV.get(`verify:${email}`);
    if (!verifyData) {
      console.error("\u9A8C\u8BC1\u7801\u4E0D\u5B58\u5728\u6216\u5DF2\u8FC7\u671F:", email);
      return jsonResponse({ error: "\u9A8C\u8BC1\u7801\u4E0D\u5B58\u5728\u6216\u5DF2\u8FC7\u671F\uFF0C\u8BF7\u91CD\u65B0\u53D1\u9001" }, 400);
    }
    const { code: storedCode, expiry } = JSON.parse(verifyData);
    if (Date.now() > expiry) {
      console.error("\u9A8C\u8BC1\u7801\u5DF2\u8FC7\u671F:", email);
      await env.USERS_KV.delete(`verify:${email}`);
      return jsonResponse({ error: "\u9A8C\u8BC1\u7801\u5DF2\u8FC7\u671F\uFF0C\u8BF7\u91CD\u65B0\u53D1\u9001" }, 400);
    }
    if (verificationCode !== storedCode) {
      console.error("\u9A8C\u8BC1\u7801\u4E0D\u5339\u914D:", { email, providedCode: verificationCode, storedCode });
      return jsonResponse({ error: "\u9A8C\u8BC1\u7801\u9519\u8BEF" }, 400);
    }
    console.log("\u68C0\u67E5\u7528\u6237\u540D\u662F\u5426\u5DF2\u5B58\u5728...");
    const existingUser = await env.USERS_KV.get(`user:${username}`);
    if (existingUser) {
      console.error("\u7528\u6237\u540D\u5DF2\u5B58\u5728:", username);
      return jsonResponse({ error: "\u7528\u6237\u540D\u5DF2\u5B58\u5728" }, 400);
    }
    console.log("\u68C0\u67E5\u90AE\u7BB1\u662F\u5426\u5DF2\u88AB\u6CE8\u518C...");
    const emailMapped = await env.USERS_KV.get(`email_to_username:${email}`);
    if (emailMapped) {
      console.error("\u90AE\u7BB1\u5DF2\u88AB\u6CE8\u518C:", { email, existingUsername: emailMapped });
      return jsonResponse({ error: "\u8BE5\u90AE\u7BB1\u5DF2\u88AB\u6CE8\u518C" }, 400);
    }
    console.log("\u521B\u5EFA\u5BC6\u7801\u54C8\u5E0C...");
    const creds = await createPasswordHash(password);
    const trialEndDate = calculateTrialEndDate2();
    const userData = {
      username,
      email,
      passwordHash: creds.passwordHash,
      salt: creds.salt,
      iterations: creds.iterations,
      algo: creds.algo,
      createdAt: (/* @__PURE__ */ new Date()).toISOString(),
      emailVerified: true,
      // 会员相关字段
      freeTrialEndDate: trialEndDate.toISOString(),
      membershipType: "trial",
      stripeCustomerId: null,
      subscriptionId: null
    };
    console.log("\u4FDD\u5B58\u7528\u6237\u6570\u636E\u5230KV\u5B58\u50A8...");
    await env.USERS_KV.put(`user:${username}`, JSON.stringify(userData));
    await env.USERS_KV.put(`email_to_username:${email}`, username);
    console.log("\u6E05\u7406\u9A8C\u8BC1\u7801\u6570\u636E...");
    await env.USERS_KV.delete(`verify:${email}`);
    await env.USERS_KV.delete(`verified:${email}`);
    console.log("\u6CE8\u518C\u6210\u529F:", username);
    return jsonResponse({ message: "\u6CE8\u518C\u6210\u529F" }, 201);
  } catch (error) {
    console.error("\u6CE8\u518C\u5931\u8D25\uFF0C\u8BE6\u7EC6\u9519\u8BEF:", error);
    console.error("\u9519\u8BEF\u5806\u6808:", error.stack);
    return jsonResponse({ error: `\u6CE8\u518C\u5931\u8D25: ${error.message}` }, 500);
  }
}
__name(handleRegister, "handleRegister");
async function handleForgotPassword(request, env) {
  try {
    let { email } = await request.json();
    if (!email) {
      return jsonResponse({ error: "\u90AE\u7BB1\u5730\u5740\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
    }
    email = String(email).trim().toLowerCase();
    let username = await env.USERS_KV.get(`email_to_username:${email}`);
    if (!username) {
      const users = await env.USERS_KV.list({ prefix: "user:" });
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
      return jsonResponse({ error: "\u8BE5\u90AE\u7BB1\u672A\u6CE8\u518C" }, 400);
    }
    const resetToken = await generateToken(username, env);
    await env.USERS_KV.put(`reset:${email}`, resetToken, { expirationTtl: 30 * 60 });
    const resetUrl = `${new URL(request.url).origin}/reset-password.html?token=${resetToken}&email=${email}`;
    const subject = "\u5BC6\u7801\u91CD\u7F6E\u8BF7\u6C42";
    const body = `\u70B9\u51FB\u4EE5\u4E0B\u94FE\u63A5\u91CD\u7F6E\u60A8\u7684\u5BC6\u7801\uFF1A
${resetUrl}
\u94FE\u63A530\u5206\u949F\u5185\u6709\u6548\u3002
\u5982\u975E\u672C\u4EBA\u64CD\u4F5C\uFF0C\u8BF7\u5FFD\u7565\u6B64\u90AE\u4EF6\u3002`;
    await sendEmail(email, subject, body, env);
    return jsonResponse({ message: "\u91CD\u7F6E\u90AE\u4EF6\u5DF2\u53D1\u9001" });
  } catch (error) {
    console.error("\u5FD8\u8BB0\u5BC6\u7801\u8BF7\u6C42\u5931\u8D25:", error);
    return jsonResponse({ error: "\u8BF7\u6C42\u5931\u8D25" }, 500);
  }
}
__name(handleForgotPassword, "handleForgotPassword");
async function handleResetPassword(request, env) {
  try {
    let { email, token, newPassword } = await request.json();
    if (!email || !token || !newPassword) {
      return jsonResponse({ error: "\u7F3A\u5C11\u5FC5\u8981\u5B57\u6BB5" }, 400);
    }
    email = String(email).trim().toLowerCase();
    if (newPassword.length < 8) {
      return jsonResponse({ error: "\u5BC6\u7801\u957F\u5EA6\u81F3\u5C118\u4E2A\u5B57\u7B26" }, 400);
    }
    if (!/[A-Z]/.test(newPassword)) {
      return jsonResponse({ error: "\u5BC6\u7801\u5FC5\u987B\u5305\u542B\u5927\u5199\u5B57\u6BCD" }, 400);
    }
    if (!/[a-z]/.test(newPassword)) {
      return jsonResponse({ error: "\u5BC6\u7801\u5FC5\u987B\u5305\u542B\u5C0F\u5199\u5B57\u6BCD" }, 400);
    }
    if (!/\d/.test(newPassword)) {
      return jsonResponse({ error: "\u5BC6\u7801\u5FC5\u987B\u5305\u542B\u6570\u5B57" }, 400);
    }
    const storedToken = await env.USERS_KV.get(`reset:${email}`);
    if (!storedToken || storedToken !== token) {
      return jsonResponse({ error: "\u91CD\u7F6E\u94FE\u63A5\u65E0\u6548\u6216\u5DF2\u8FC7\u671F" }, 400);
    }
    let username = await env.USERS_KV.get(`email_to_username:${email}`);
    if (!username) {
      const users = await env.USERS_KV.list({ prefix: "user:" });
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
      return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 400);
    }
    const userData = await env.USERS_KV.get(`user:${username}`);
    const user = JSON.parse(userData);
    const creds = await createPasswordHash(newPassword);
    user.passwordHash = creds.passwordHash;
    user.salt = creds.salt;
    user.iterations = creds.iterations;
    user.algo = creds.algo;
    delete user.password;
    await env.USERS_KV.put(`user:${username}`, JSON.stringify(user));
    await env.USERS_KV.delete(`reset:${email}`);
    return jsonResponse({ message: "\u5BC6\u7801\u91CD\u7F6E\u6210\u529F" });
  } catch (error) {
    console.error("\u91CD\u7F6E\u5BC6\u7801\u5931\u8D25:", error);
    return jsonResponse({ error: "\u91CD\u7F6E\u5BC6\u7801\u5931\u8D25" }, 500);
  }
}
__name(handleResetPassword, "handleResetPassword");
async function handleLogin(request, env) {
  try {
    console.log("--- New Login Attempt ---");
    const { username: loginIdentifier, password } = await request.json();
    console.log(`Login identifier received: "${loginIdentifier}"`);
    if (!loginIdentifier || !password) {
      console.error("Error: Missing login identifier or password.");
      return jsonResponse({ error: "\u7528\u6237\u540D\u6216\u90AE\u7BB1\u548C\u5BC6\u7801\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
    }
    let username = loginIdentifier.trim();
    if (username.includes("@")) {
      const email = username.toLowerCase();
      console.log(`Identifier is an email: ${email}`);
      let mappedUsername = await env.USERS_KV.get(`email_to_username:${email}`);
      if (!mappedUsername) {
        console.log(`Email-to-username mapping not found for ${email}. Attempting backfill.`);
        const list = await env.USERS_KV.list({ prefix: "user:" });
        for (const key of list.keys) {
          const userJson = await env.USERS_KV.get(key.name);
          if (userJson) {
            const user2 = JSON.parse(userJson);
            if (user2.email && user2.email.toLowerCase() === email) {
              mappedUsername = user2.username;
              await env.USERS_KV.put(`email_to_username:${email}`, mappedUsername);
              console.log(`Backfilled mapping for ${email} to ${mappedUsername}.`);
              break;
            }
          }
        }
      }
      if (!mappedUsername) {
        console.error(`User not found for email: ${email}`);
        return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 401);
      }
      username = mappedUsername;
      console.log(`Email mapped to username: ${username}`);
    } else {
      console.log(`Identifier is a username: ${username}`);
    }
    const userData = await env.USERS_KV.get(`user:${username}`);
    if (!userData) {
      console.error(`User data not found in KV for key: user:${username}`);
      return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 401);
    }
    console.log(`User data found for ${username}.`);
    let user = JSON.parse(userData);
    const ok = await verifyPassword(password, user);
    if (!ok) {
      console.error(`Password verification failed for user: ${username}`);
      return jsonResponse({ error: "\u5BC6\u7801\u9519\u8BEF" }, 401);
    }
    console.log(`Password verified for ${username}.`);
    user = await upgradePasswordIfNeeded(password, username, user, env);
    const token = await generateToken(username, env);
    console.log(`Token generated for ${username}. Login successful.`);
    return jsonResponse({ token, username });
  } catch (error) {
    console.error("Login function crashed:", error.stack);
    return jsonResponse({ error: "\u767B\u5F55\u5931\u8D25" }, 500);
  }
}
__name(handleLogin, "handleLogin");
async function handleVerify(request, env) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
    }
    const token = authHeader.substring(7);
    const isValid = await verifyToken(token, env);
    if (!isValid) {
      return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
    }
    return jsonResponse({ username: isValid.username });
  } catch (error) {
    return jsonResponse({ error: "\u9A8C\u8BC1\u5931\u8D25" }, 500);
  }
}
__name(handleVerify, "handleVerify");
async function handleLogout(request, env) {
  return jsonResponse({ message: "\u767B\u51FA\u6210\u529F" });
}
__name(handleLogout, "handleLogout");
var WECHAT_CONFIG = {
  APP_ID: "your_wechat_app_id",
  // 需要在环境变量中设置
  APP_SECRET: "your_wechat_app_secret",
  // 需要在环境变量中设置
  REDIRECT_URI: "https://your-domain.com/wechat-callback.html",
  // 回调地址
  SCOPE: "snsapi_userinfo"
  // 授权范围
};
async function generateWechatLoginUrl(env) {
  const state = crypto.randomUUID();
  const appId = env.WECHAT_APP_ID || WECHAT_CONFIG.APP_ID;
  const redirectUri = encodeURIComponent(env.WECHAT_REDIRECT_URI || WECHAT_CONFIG.REDIRECT_URI);
  const authUrl = `https://open.weixin.qq.com/connect/oauth2/authorize?appid=${appId}&redirect_uri=${redirectUri}&response_type=code&scope=${WECHAT_CONFIG.SCOPE}&state=${state}#wechat_redirect`;
  await env.USERS_KV.put(`wechat_state:${state}`, "valid", { expirationTtl: 600 });
  return { authUrl, state };
}
__name(generateWechatLoginUrl, "generateWechatLoginUrl");
async function getWechatUserInfo(code, env) {
  const appId = env.WECHAT_APP_ID || WECHAT_CONFIG.APP_ID;
  const appSecret = env.WECHAT_APP_SECRET || WECHAT_CONFIG.APP_SECRET;
  try {
    const tokenUrl = `https://api.weixin.qq.com/sns/oauth2/access_token?appid=${appId}&secret=${appSecret}&code=${code}&grant_type=authorization_code`;
    const tokenResponse = await fetch(tokenUrl);
    const tokenData = await tokenResponse.json();
    if (tokenData.errcode) {
      throw new Error(`\u83B7\u53D6access_token\u5931\u8D25: ${tokenData.errmsg}`);
    }
    const { access_token, openid } = tokenData;
    const userInfoUrl = `https://api.weixin.qq.com/sns/userinfo?access_token=${access_token}&openid=${openid}&lang=zh_CN`;
    const userInfoResponse = await fetch(userInfoUrl);
    const userInfo = await userInfoResponse.json();
    if (userInfo.errcode) {
      throw new Error(`\u83B7\u53D6\u7528\u6237\u4FE1\u606F\u5931\u8D25: ${userInfo.errmsg}`);
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
    console.error("\u83B7\u53D6\u5FAE\u4FE1\u7528\u6237\u4FE1\u606F\u5931\u8D25:", error);
    throw error;
  }
}
__name(getWechatUserInfo, "getWechatUserInfo");
async function handleWechatLogin(request, env) {
  try {
    const { code, state } = await request.json();
    if (!code) {
      return jsonResponse({ error: "\u7F3A\u5C11\u6388\u6743\u7801" }, 400);
    }
    if (state) {
      const storedState = await env.USERS_KV.get(`wechat_state:${state}`);
      if (!storedState) {
        return jsonResponse({ error: "\u65E0\u6548\u7684state\u53C2\u6570" }, 400);
      }
      await env.USERS_KV.delete(`wechat_state:${state}`);
    }
    const wechatUser = await getWechatUserInfo(code, env);
    const existingBinding = await env.USERS_KV.get(`wechat_binding:${wechatUser.openid}`);
    if (existingBinding) {
      const userData = await env.USERS_KV.get(`user:${existingBinding}`);
      if (userData) {
        const user = JSON.parse(userData);
        const token = await generateToken(user.username, env);
        return jsonResponse({
          token,
          username: user.username,
          isNewUser: false,
          loginMethod: "wechat"
        });
      }
    }
    return jsonResponse({
      wechatUser,
      isNewUser: true,
      needsRegistration: true
    });
  } catch (error) {
    console.error("\u5FAE\u4FE1\u767B\u5F55\u5931\u8D25:", error);
    return jsonResponse({ error: "\u5FAE\u4FE1\u767B\u5F55\u5931\u8D25: " + error.message }, 500);
  }
}
__name(handleWechatLogin, "handleWechatLogin");
async function handleWechatBind(request, env) {
  try {
    const { openid, email, password } = await request.json();
    if (!openid || !email || !password) {
      return jsonResponse({ error: "\u7F3A\u5C11\u5FC5\u8981\u53C2\u6570" }, 400);
    }
    const username = await env.USERS_KV.get(`email_to_username:${email}`);
    if (!username) {
      return jsonResponse({ error: "\u90AE\u7BB1\u672A\u6CE8\u518C" }, 400);
    }
    const userData = await env.USERS_KV.get(`user:${username}`);
    if (!userData) {
      return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 400);
    }
    const user = JSON.parse(userData);
    const isValidPassword = await verifyPassword(password, user);
    if (!isValidPassword) {
      return jsonResponse({ error: "\u5BC6\u7801\u9519\u8BEF" }, 400);
    }
    const existingBinding = await env.USERS_KV.get(`wechat_binding:${openid}`);
    if (existingBinding && existingBinding !== username) {
      return jsonResponse({ error: "\u8BE5\u5FAE\u4FE1\u8D26\u53F7\u5DF2\u7ED1\u5B9A\u5176\u4ED6\u7528\u6237" }, 400);
    }
    const userWechatBinding = await env.USERS_KV.get(`user_wechat:${username}`);
    if (userWechatBinding) {
      return jsonResponse({ error: "\u8BE5\u8D26\u53F7\u5DF2\u7ED1\u5B9A\u5176\u4ED6\u5FAE\u4FE1" }, 400);
    }
    await env.USERS_KV.put(`wechat_binding:${openid}`, username);
    await env.USERS_KV.put(`user_wechat:${username}`, openid);
    user.wechatOpenid = openid;
    user.wechatBoundAt = (/* @__PURE__ */ new Date()).toISOString();
    await env.USERS_KV.put(`user:${username}`, JSON.stringify(user));
    const token = await generateToken(username, env);
    return jsonResponse({
      token,
      username,
      message: "\u5FAE\u4FE1\u8D26\u53F7\u7ED1\u5B9A\u6210\u529F"
    });
  } catch (error) {
    console.error("\u5FAE\u4FE1\u7ED1\u5B9A\u5931\u8D25:", error);
    return jsonResponse({ error: "\u5FAE\u4FE1\u7ED1\u5B9A\u5931\u8D25: " + error.message }, 500);
  }
}
__name(handleWechatBind, "handleWechatBind");
async function handleWechatRegister(request, env) {
  try {
    const { openid, nickname, headimgurl, username, email, password } = await request.json();
    if (!openid || !username || !password) {
      return jsonResponse({ error: "\u7F3A\u5C11\u5FC5\u8981\u53C2\u6570" }, 400);
    }
    const existingUser = await env.USERS_KV.get(`user:${username}`);
    if (existingUser) {
      return jsonResponse({ error: "\u7528\u6237\u540D\u5DF2\u5B58\u5728" }, 400);
    }
    if (email) {
      const emailMapped = await env.USERS_KV.get(`email_to_username:${String(email).trim().toLowerCase()}`);
      if (emailMapped) {
        return jsonResponse({ error: "\u8BE5\u90AE\u7BB1\u5DF2\u88AB\u6CE8\u518C" }, 400);
      }
    }
    const existingBinding = await env.USERS_KV.get(`wechat_binding:${openid}`);
    if (existingBinding) {
      return jsonResponse({ error: "\u8BE5\u5FAE\u4FE1\u8D26\u53F7\u5DF2\u7ED1\u5B9A\u5176\u4ED6\u7528\u6237" }, 400);
    }
    const creds = await createPasswordHash(password);
    const trialEndDate = calculateTrialEndDate2();
    const userData = {
      username,
      email: email ? String(email).trim().toLowerCase() : null,
      passwordHash: creds.passwordHash,
      salt: creds.salt,
      iterations: creds.iterations,
      algo: creds.algo,
      createdAt: (/* @__PURE__ */ new Date()).toISOString(),
      emailVerified: !!email,
      // 微信相关字段
      wechatOpenid: openid,
      wechatNickname: nickname,
      wechatHeadimgurl: headimgurl,
      wechatBoundAt: (/* @__PURE__ */ new Date()).toISOString(),
      // 会员相关字段
      freeTrialEndDate: trialEndDate.toISOString(),
      membershipType: "trial",
      stripeCustomerId: null,
      subscriptionId: null
    };
    await env.USERS_KV.put(`user:${username}`, JSON.stringify(userData));
    if (userData.email) {
      await env.USERS_KV.put(`email_to_username:${userData.email}`, username);
    }
    await env.USERS_KV.put(`wechat_binding:${openid}`, username);
    await env.USERS_KV.put(`user_wechat:${username}`, openid);
    const token = await generateToken(username, env);
    return jsonResponse({
      token,
      username,
      message: "\u6CE8\u518C\u6210\u529F\uFF0C\u5FAE\u4FE1\u8D26\u53F7\u5DF2\u7ED1\u5B9A"
    }, 201);
  } catch (error) {
    console.error("\u5FAE\u4FE1\u6CE8\u518C\u5931\u8D25:", error);
    return jsonResponse({ error: "\u5FAE\u4FE1\u6CE8\u518C\u5931\u8D25: " + error.message }, 500);
  }
}
__name(handleWechatRegister, "handleWechatRegister");
async function handleWechatUnbind(request, env) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
    }
    const token = authHeader.substring(7);
    const tokenData = await verifyToken(token, env);
    if (!tokenData) {
      return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
    }
    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 404);
    }
    const user = JSON.parse(userData);
    if (!user.wechatOpenid) {
      return jsonResponse({ error: "\u8BE5\u8D26\u53F7\u672A\u7ED1\u5B9A\u5FAE\u4FE1" }, 400);
    }
    await env.USERS_KV.delete(`wechat_binding:${user.wechatOpenid}`);
    await env.USERS_KV.delete(`user_wechat:${tokenData.username}`);
    delete user.wechatOpenid;
    delete user.wechatNickname;
    delete user.wechatHeadimgurl;
    delete user.wechatBoundAt;
    await env.USERS_KV.put(`user:${tokenData.username}`, JSON.stringify(user));
    return jsonResponse({ message: "\u5FAE\u4FE1\u8D26\u53F7\u89E3\u7ED1\u6210\u529F" });
  } catch (error) {
    console.error("\u5FAE\u4FE1\u89E3\u7ED1\u5931\u8D25:", error);
    return jsonResponse({ error: "\u5FAE\u4FE1\u89E3\u7ED1\u5931\u8D25: " + error.message }, 500);
  }
}
__name(handleWechatUnbind, "handleWechatUnbind");
async function handleGetWechatLoginUrl(request, env) {
  try {
    const { authUrl, state } = await generateWechatLoginUrl(env);
    return jsonResponse({ authUrl, state });
  } catch (error) {
    console.error("\u751F\u6210\u5FAE\u4FE1\u767B\u5F55URL\u5931\u8D25:", error);
    return jsonResponse({ error: "\u751F\u6210\u5FAE\u4FE1\u767B\u5F55URL\u5931\u8D25: " + error.message }, 500);
  }
}
__name(handleGetWechatLoginUrl, "handleGetWechatLoginUrl");
async function handleGetUserInfo(request, env) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
    }
    const token = authHeader.substring(7);
    const tokenData = await verifyToken(token, env);
    if (!tokenData) {
      return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
    }
    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 404);
    }
    const user = JSON.parse(userData);
    const membershipStatus = checkMembershipStatus(user);
    return jsonResponse({
      username: user.username,
      email: user.email,
      wechatOpenid: user.wechatOpenid || null,
      wechatNickname: user.wechatNickname || null,
      wechatHeadimgurl: user.wechatHeadimgurl || null,
      wechatBoundAt: user.wechatBoundAt || null,
      createdAt: user.createdAt,
      emailVerified: user.emailVerified,
      membership: membershipStatus,
      alipayUserId: user.alipayUserId || null,
      alipayNickname: user.alipayNickname || null
    });
  } catch (error) {
    console.error("\u83B7\u53D6\u7528\u6237\u4FE1\u606F\u5931\u8D25:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u7528\u6237\u4FE1\u606F\u5931\u8D25: " + error.message }, 500);
  }
}
__name(handleGetUserInfo, "handleGetUserInfo");
async function handleBindEmail(request, env) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
    }
    const token = authHeader.substring(7);
    const tokenData = await verifyToken(token, env);
    if (!tokenData) {
      return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
    }
    const { email, verificationCode } = await request.json();
    if (!email || !verificationCode) {
      return jsonResponse({ error: "\u90AE\u7BB1\u4E0E\u9A8C\u8BC1\u7801\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
    }
    const normalizedEmail = String(email).trim().toLowerCase();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(normalizedEmail)) {
      return jsonResponse({ error: "\u90AE\u7BB1\u683C\u5F0F\u4E0D\u6B63\u786E" }, 400);
    }
    const existing = await env.USERS_KV.get(`email_to_username:${normalizedEmail}`);
    if (existing) {
      return jsonResponse({ error: "\u8BE5\u90AE\u7BB1\u5DF2\u88AB\u5176\u4ED6\u8D26\u53F7\u7ED1\u5B9A" }, 400);
    }
    const verifyDataStr = await env.USERS_KV.get(`verify:${normalizedEmail}`);
    if (!verifyDataStr) {
      return jsonResponse({ error: "\u9A8C\u8BC1\u7801\u4E0D\u5B58\u5728\u6216\u5DF2\u8FC7\u671F" }, 400);
    }
    const { code: storedCode, expiry } = JSON.parse(verifyDataStr);
    if (Date.now() > expiry) {
      await env.USERS_KV.delete(`verify:${normalizedEmail}`);
      return jsonResponse({ error: "\u9A8C\u8BC1\u7801\u5DF2\u8FC7\u671F" }, 400);
    }
    if (verificationCode !== storedCode) {
      return jsonResponse({ error: "\u9A8C\u8BC1\u7801\u9519\u8BEF" }, 400);
    }
    const userKey = `user:${tokenData.username}`;
    const userStr = await env.USERS_KV.get(userKey);
    if (!userStr) {
      return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 404);
    }
    const user = JSON.parse(userStr);
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
    await env.USERS_KV.delete(`verify:${normalizedEmail}`);
    return jsonResponse({ message: "\u90AE\u7BB1\u7ED1\u5B9A\u6210\u529F", email: normalizedEmail });
  } catch (error) {
    console.error("\u7ED1\u5B9A\u90AE\u7BB1\u5931\u8D25:", error);
    return jsonResponse({ error: "\u7ED1\u5B9A\u90AE\u7BB1\u5931\u8D25: " + error.message }, 500);
  }
}
__name(handleBindEmail, "handleBindEmail");
async function handleCheckAdminStatus(request, env) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
    }
    const token = authHeader.substring(7);
    const tokenData = await verifyToken(token, env);
    if (!tokenData) {
      return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
    }
    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 404);
    }
    const user = JSON.parse(userData);
    const adminStatus = isAdmin(user.email);
    return jsonResponse({
      isAdmin: adminStatus,
      email: user.email,
      username: user.username
    });
  } catch (error) {
    console.error("\u68C0\u67E5\u7BA1\u7406\u5458\u72B6\u6001\u5931\u8D25:", error);
    return jsonResponse({ error: "\u68C0\u67E5\u7BA1\u7406\u5458\u72B6\u6001\u5931\u8D25" }, 500);
  }
}
__name(handleCheckAdminStatus, "handleCheckAdminStatus");
async function handleCreateRedeemCode(request, env) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
    }
    const token = authHeader.substring(7);
    const tokenData = await verifyToken(token, env);
    if (!tokenData) {
      return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
    }
    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 404);
    }
    const user = JSON.parse(userData);
    if (!isAdmin(user.email)) {
      return jsonResponse({ error: "\u6743\u9650\u4E0D\u8DB3\uFF0C\u4EC5\u7BA1\u7406\u5458\u53EF\u751F\u6210\u5151\u6362\u7801" }, 403);
    }
    const { type, quantity = 1, description = "" } = await request.json();
    if (!REDEEM_CODE_TYPES[type]) {
      return jsonResponse({ error: "\u65E0\u6548\u7684\u5151\u6362\u7801\u7C7B\u578B" }, 400);
    }
    if (quantity < 1 || quantity > 100) {
      return jsonResponse({ error: "\u5151\u6362\u7801\u6570\u91CF\u5FC5\u987B\u57281-100\u4E4B\u95F4" }, 400);
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
        createdAt: (/* @__PURE__ */ new Date()).toISOString(),
        used: false,
        usedBy: null,
        usedAt: null
      };
      await env.REDEEM_CODES_KV.put(`code:${code}`, JSON.stringify(codeData));
      codes.push(code);
    }
    return jsonResponse({
      message: `\u6210\u529F\u751F\u6210${quantity}\u4E2A\u5151\u6362\u7801`,
      codes,
      type: codeType.name
    });
  } catch (error) {
    console.error("\u751F\u6210\u5151\u6362\u7801\u5931\u8D25:", error);
    return jsonResponse({ error: "\u751F\u6210\u5151\u6362\u7801\u5931\u8D25" }, 500);
  }
}
__name(handleCreateRedeemCode, "handleCreateRedeemCode");
async function handleGetPurchaseHistory(request, env) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
    }
    const token = authHeader.substring(7);
    const tokenData = await verifyToken(token, env);
    if (!tokenData) {
      return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
    }
    const purchases = await env.USERS_KV.get(`purchases:${tokenData.username}`);
    const purchaseHistory = purchases ? JSON.parse(purchases) : [];
    return jsonResponse({
      purchases: purchaseHistory,
      total: purchaseHistory.length
    });
  } catch (error) {
    console.error("\u83B7\u53D6\u8D2D\u4E70\u8BB0\u5F55\u5931\u8D25:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u8D2D\u4E70\u8BB0\u5F55\u5931\u8D25" }, 500);
  }
}
__name(handleGetPurchaseHistory, "handleGetPurchaseHistory");
async function handleGetRedeemHistory(request, env) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
    }
    const token = authHeader.substring(7);
    const tokenData = await verifyToken(token, env);
    if (!tokenData) {
      return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
    }
    const redeems = await env.USERS_KV.get(`redeems:${tokenData.username}`);
    const redeemHistory = redeems ? JSON.parse(redeems) : [];
    return jsonResponse({
      redeems: redeemHistory,
      total: redeemHistory.length
    });
  } catch (error) {
    console.error("\u83B7\u53D6\u5151\u6362\u8BB0\u5F55\u5931\u8D25:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u5151\u6362\u8BB0\u5F55\u5931\u8D25" }, 500);
  }
}
__name(handleGetRedeemHistory, "handleGetRedeemHistory");
async function handleListRedeemCodes(request, env) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
    }
    const token = authHeader.substring(7);
    const tokenData = await verifyToken(token, env);
    if (!tokenData) {
      return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
    }
    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 404);
    }
    const user = JSON.parse(userData);
    if (!isAdmin(user.email)) {
      return jsonResponse({ error: "\u6743\u9650\u4E0D\u8DB3\uFF0C\u4EC5\u7BA1\u7406\u5458\u53EF\u67E5\u770B\u5151\u6362\u7801" }, 403);
    }
    const url = new URL(request.url);
    const page = parseInt(url.searchParams.get("page") || "1");
    const limit = parseInt(url.searchParams.get("limit") || "20");
    const status = url.searchParams.get("status");
    const allCodes = await env.REDEEM_CODES_KV.list({ prefix: "code:" });
    const codes = [];
    for (const key of allCodes.keys) {
      const codeData = await env.REDEEM_CODES_KV.get(key.name);
      if (codeData) {
        const code = JSON.parse(codeData);
        if (status === "used" && !code.used) continue;
        if (status === "unused" && code.used) continue;
        codes.push(code);
      }
    }
    codes.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
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
    console.error("\u67E5\u8BE2\u5151\u6362\u7801\u5931\u8D25:", error);
    return jsonResponse({ error: "\u67E5\u8BE2\u5151\u6362\u7801\u5931\u8D25" }, 500);
  }
}
__name(handleListRedeemCodes, "handleListRedeemCodes");
async function handleUseRedeemCode(request, env) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
    }
    const token = authHeader.substring(7);
    const tokenData = await verifyToken(token, env);
    if (!tokenData) {
      return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
    }
    const { code } = await request.json();
    if (!code) {
      return jsonResponse({ error: "\u5151\u6362\u7801\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
    }
    const codeData = await env.REDEEM_CODES_KV.get(`code:${code.toUpperCase()}`);
    if (!codeData) {
      return jsonResponse({ error: "\u5151\u6362\u7801\u4E0D\u5B58\u5728\u6216\u5DF2\u5931\u6548" }, 400);
    }
    const redeemCode = JSON.parse(codeData);
    if (redeemCode.used) {
      return jsonResponse({
        error: "\u5151\u6362\u7801\u5DF2\u88AB\u4F7F\u7528",
        usedBy: redeemCode.usedBy,
        usedAt: redeemCode.usedAt
      }, 400);
    }
    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 404);
    }
    const user = JSON.parse(userData);
    let newExpiryDate;
    const now = /* @__PURE__ */ new Date();
    let currentExpiryDate = null;
    if (user.membershipExpiresAt && new Date(user.membershipExpiresAt) > now) {
      currentExpiryDate = new Date(user.membershipExpiresAt);
    }
    if (user.freeTrialEndDate && new Date(user.freeTrialEndDate) > now) {
      const trialEnd = new Date(user.freeTrialEndDate);
      if (!currentExpiryDate || trialEnd > currentExpiryDate) {
        currentExpiryDate = trialEnd;
      }
    }
    if (currentExpiryDate) {
      newExpiryDate = new Date(currentExpiryDate);
    } else {
      newExpiryDate = new Date(now);
    }
    newExpiryDate.setDate(newExpiryDate.getDate() + redeemCode.days);
    user.membershipType = redeemCode.type;
    user.membershipExpiresAt = newExpiryDate.toISOString();
    user.lastRedeemCode = code.toUpperCase();
    user.lastRedeemAt = now.toISOString();
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
    const existingRedeems = await env.USERS_KV.get(`redeems:${tokenData.username}`);
    const redeems = existingRedeems ? JSON.parse(existingRedeems) : [];
    redeems.unshift(redeemRecord);
    await env.USERS_KV.put(`redeems:${tokenData.username}`, JSON.stringify(redeems));
    if (redeemCode.type === "premium" && user.freeTrialEndDate) {
      delete user.freeTrialEndDate;
    }
    await env.USERS_KV.put(`user:${tokenData.username}`, JSON.stringify(user));
    redeemCode.used = true;
    redeemCode.usedBy = tokenData.username;
    redeemCode.usedAt = now.toISOString();
    await env.REDEEM_CODES_KV.put(`code:${code.toUpperCase()}`, JSON.stringify(redeemCode));
    return jsonResponse({
      message: `\u5151\u6362\u6210\u529F\uFF01\u83B7\u5F97${redeemCode.name}`,
      membershipType: redeemCode.type,
      expiresAt: newExpiryDate.toISOString(),
      daysAdded: redeemCode.days
    });
  } catch (error) {
    console.error("\u4F7F\u7528\u5151\u6362\u7801\u5931\u8D25:", error);
    return jsonResponse({ error: "\u4F7F\u7528\u5151\u6362\u7801\u5931\u8D25" }, 500);
  }
}
__name(handleUseRedeemCode, "handleUseRedeemCode");
async function handleDeleteRedeemCode(request, env) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
    }
    const token = authHeader.substring(7);
    const tokenData = await verifyToken(token, env);
    if (!tokenData) {
      return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
    }
    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 404);
    }
    const user = JSON.parse(userData);
    if (!isAdmin(user.email)) {
      return jsonResponse({ error: "\u6743\u9650\u4E0D\u8DB3\uFF0C\u4EC5\u7BA1\u7406\u5458\u53EF\u5220\u9664\u5151\u6362\u7801" }, 403);
    }
    const { code } = await request.json();
    if (!code) {
      return jsonResponse({ error: "\u5151\u6362\u7801\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
    }
    const codeKey = `code:${code.toUpperCase()}`;
    const codeData = await env.REDEEM_CODES_KV.get(codeKey);
    if (!codeData) {
      return jsonResponse({ error: "\u5151\u6362\u7801\u4E0D\u5B58\u5728" }, 404);
    }
    await env.REDEEM_CODES_KV.delete(codeKey);
    return jsonResponse({ message: "\u5151\u6362\u7801\u5220\u9664\u6210\u529F" });
  } catch (error) {
    console.error("\u5220\u9664\u5151\u6362\u7801\u5931\u8D25:", error);
    return jsonResponse({ error: "\u5220\u9664\u5151\u6362\u7801\u5931\u8D25" }, 500);
  }
}
__name(handleDeleteRedeemCode, "handleDeleteRedeemCode");
async function handleGetAdminPrice(request, env) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
    }
    const token = authHeader.substring(7);
    const tokenData = await verifyToken(token, env);
    if (!tokenData) {
      return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
    }
    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 404);
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
    console.error("\u83B7\u53D6\u7BA1\u7406\u5458\u4EF7\u683C\u5931\u8D25:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u4EF7\u683C\u5931\u8D25" }, 500);
  }
}
__name(handleGetAdminPrice, "handleGetAdminPrice");
function getOriginalPrice(plan) {
  const prices = {
    "monthly": "21",
    "quarterly": "63",
    "yearly": "252"
  };
  return prices[plan] || "21";
}
__name(getOriginalPrice, "getOriginalPrice");
function getAlipayEnvConfig(env) {
  const isSandbox = env.ALIPAY_SANDBOX === "true";
  ALIPAY_CONFIG.APP_CONFIG.sandbox = isSandbox;
  return {
    app_id: env.ALIPAY_APP_ID,
    privateKey: env.ALIPAY_PRIVATE_KEY,
    alipayPublicKey: env.ALIPAY_PUBLIC_KEY,
    isSandbox,
    gateway: isSandbox ? ALIPAY_CONFIG.SANDBOX_GATEWAY_URL : ALIPAY_CONFIG.GATEWAY_URL
    // 直接使用对应的网关地址
  };
}
__name(getAlipayEnvConfig, "getAlipayEnvConfig");
async function handleCreateAlipayOrder(request, env) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
    }
    const token = authHeader.substring(7);
    const tokenData = await verifyToken(token, env);
    if (!tokenData) {
      return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
    }
    const { plan = "monthly" } = await request.json();
    const planDetails = WORKER_MEMBERSHIP_PLANS[plan];
    if (!planDetails) {
      return jsonResponse({ error: "\u65E0\u6548\u7684\u4F1A\u5458\u8BA1\u5212" }, 400);
    }
    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 404);
    }
    const user = JSON.parse(userData);
    const isAdminUser = isAdmin(user.email);
    let finalAmount = planDetails.price;
    if (isAdminUser && planDetails.adminPrice) {
      finalAmount = planDetails.adminPrice;
    }
    const alipayConfig = getAlipayEnvConfig(env);
    if (!alipayConfig.app_id || !alipayConfig.privateKey || !alipayConfig.alipayPublicKey) {
      console.error("Alipay environment variables are not set");
      return jsonResponse({ error: "\u652F\u4ED8\u670D\u52A1\u914D\u7F6E\u4E0D\u5B8C\u6574" }, 500);
    }
    const outTradeNo = `MEMBER_${tokenData.username}_${Date.now()}`;
    const subject = `\u5168\u7403\u6CD5\u5E03\u65BD - ${planDetails.name}`;
    const orderData = {
      orderId: outTradeNo,
      userId: tokenData.username,
      plan,
      amount: finalAmount,
      originalAmount: planDetails.price,
      isAdminOrder: isAdminUser,
      status: "PENDING",
      createdAt: (/* @__PURE__ */ new Date()).toISOString()
    };
    await env.ORDERS_KV.put(outTradeNo, JSON.stringify(orderData));
    const bizContent = {
      out_trade_no: outTradeNo,
      total_amount: finalAmount,
      subject,
      product_code: ALIPAY_CONFIG.PRODUCT_CODE,
      timeout_express: ALIPAY_CONFIG.TIMEOUT_EXPRESS
    };
    const now = /* @__PURE__ */ new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, "0");
    const day = String(now.getDate()).padStart(2, "0");
    const hours = String(now.getHours()).padStart(2, "0");
    const minutes = String(now.getMinutes()).padStart(2, "0");
    const seconds = String(now.getSeconds()).padStart(2, "0");
    const timestamp = `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
    const params = {
      app_id: alipayConfig.app_id,
      method: "alipay.trade.precreate",
      format: "JSON",
      charset: ALIPAY_CONFIG.APP_CONFIG.charset,
      sign_type: ALIPAY_CONFIG.APP_CONFIG.sign_type,
      timestamp,
      version: ALIPAY_CONFIG.APP_CONFIG.version,
      notify_url: "https://flutter.ombhrum.com/api/alipay/notify",
      return_url: "https://flutter.ombhrum.com/#/membership",
      biz_content: JSON.stringify(bizContent)
    };
    console.log("\u652F\u4ED8\u5B9DAPI\u53C2\u6570:", params);
    const privateKey = await importPrivateKey(alipayConfig.privateKey);
    params.sign = await generateSign(params, privateKey);
    const searchParams = new URLSearchParams();
    for (const key in params) {
      searchParams.append(key, params[key]);
    }
    console.log("\u8BF7\u6C42\u652F\u4ED8\u5B9DAPI:", alipayConfig.gateway);
    console.log("\u8BF7\u6C42\u53C2\u6570:", JSON.stringify(params, null, 2));
    try {
      const formData = new URLSearchParams();
      for (const key in params) {
        formData.append(key, params[key]);
      }
      const response = await fetch(alipayConfig.gateway, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded;charset=utf-8" },
        body: formData.toString(),
        redirect: "follow"
      });
      if (!response.ok) {
        console.error("\u652F\u4ED8\u5B9DAPI\u54CD\u5E94\u9519\u8BEF:", response.status, response.statusText);
        const responseText2 = await response.text();
        console.error("\u54CD\u5E94\u5185\u5BB9:", responseText2.substring(0, 1e3));
        return jsonResponse({ error: `\u652F\u4ED8\u5B9DAPI\u8BF7\u6C42\u5931\u8D25: ${response.status} ${response.statusText}` }, 500);
      }
      const responseText = await response.text();
      console.log("\u652F\u4ED8\u5B9DAPI\u54CD\u5E94:", responseText.substring(0, 500));
      try {
        const alipayResponse = JSON.parse(responseText);
        const precreateResponse = alipayResponse.alipay_trade_precreate_response;
        if (precreateResponse.code === "10000") {
          return jsonResponse({
            orderId: outTradeNo,
            qrCode: precreateResponse.qr_code,
            amount: finalAmount,
            originalAmount: planDetails.price,
            isAdminOrder: isAdminUser,
            plan
          });
        } else {
          console.error("Alipay precreate failed:", precreateResponse);
          return jsonResponse({ error: "\u521B\u5EFA\u652F\u4ED8\u4E8C\u7EF4\u7801\u5931\u8D25", detail: precreateResponse.sub_msg }, 500);
        }
      } catch (parseError) {
        console.error("\u89E3\u6790\u652F\u4ED8\u5B9DAPI\u54CD\u5E94\u5931\u8D25:", parseError);
        console.error("\u54CD\u5E94\u5185\u5BB9:", responseText.substring(0, 1e3));
        return jsonResponse({ error: "\u89E3\u6790\u652F\u4ED8\u5B9DAPI\u54CD\u5E94\u5931\u8D25: \u8FD4\u56DE\u5185\u5BB9\u4E0D\u662F\u6709\u6548\u7684JSON" }, 500);
      }
    } catch (fetchError) {
      console.error("\u8BF7\u6C42\u652F\u4ED8\u5B9DAPI\u5931\u8D25:", fetchError);
      return jsonResponse({ error: `\u8BF7\u6C42\u652F\u4ED8\u5B9DAPI\u5931\u8D25: ${fetchError.message}` }, 500);
    }
  } catch (error) {
    console.error("\u521B\u5EFA\u652F\u4ED8\u5B9D\u8BA2\u5355\u5931\u8D25:", error);
    return jsonResponse({ error: "\u521B\u5EFA\u8BA2\u5355\u5931\u8D25: " + error.message }, 500);
  }
}
__name(handleCreateAlipayOrder, "handleCreateAlipayOrder");
async function handleCreateAlipayWebOrder(request, env) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
    }
    const token = authHeader.substring(7);
    const tokenData = await verifyToken(token, env);
    if (!tokenData) {
      return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
    }
    const { plan = "monthly" } = await request.json();
    const planDetails = WORKER_MEMBERSHIP_PLANS[plan];
    if (!planDetails) {
      return jsonResponse({ error: "\u65E0\u6548\u7684\u4F1A\u5458\u8BA1\u5212" }, 400);
    }
    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 404);
    }
    const user = JSON.parse(userData);
    const isAdminUser = isAdmin(user.email);
    let finalAmount = planDetails.price;
    if (isAdminUser && planDetails.adminPrice) {
      finalAmount = planDetails.adminPrice;
    }
    const alipayConfig = getAlipayEnvConfig(env);
    if (!alipayConfig.app_id || !alipayConfig.privateKey || !alipayConfig.alipayPublicKey) {
      console.error("Alipay environment variables are not set");
      return jsonResponse({ error: "\u652F\u4ED8\u670D\u52A1\u914D\u7F6E\u4E0D\u5B8C\u6574" }, 500);
    }
    const outTradeNo = `WEB_${tokenData.username}_${Date.now()}`;
    const subject = `\u5168\u7403\u6CD5\u5E03\u65BD - ${planDetails.name}`;
    const orderData = {
      orderId: outTradeNo,
      userId: tokenData.username,
      plan,
      amount: finalAmount,
      originalAmount: planDetails.price,
      isAdminOrder: isAdminUser,
      status: "PENDING",
      platform: "web",
      createdAt: (/* @__PURE__ */ new Date()).toISOString()
    };
    await env.ORDERS_KV.put(outTradeNo, JSON.stringify(orderData));
    const bizContent = {
      out_trade_no: outTradeNo,
      total_amount: finalAmount,
      subject,
      product_code: "FAST_INSTANT_TRADE_PAY",
      // 电脑网站支付使用不同的产品码
      timeout_express: ALIPAY_CONFIG.TIMEOUT_EXPRESS,
      quit_url: "https://flutter.ombhrum.com/#/membership"
      // 用户付款中途退出返回的商户页面地址
    };
    const now = /* @__PURE__ */ new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, "0");
    const day = String(now.getDate()).padStart(2, "0");
    const hours = String(now.getHours()).padStart(2, "0");
    const minutes = String(now.getMinutes()).padStart(2, "0");
    const seconds = String(now.getSeconds()).padStart(2, "0");
    const timestamp = `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
    const params = {
      app_id: alipayConfig.app_id,
      method: "alipay.trade.page.pay",
      // 电脑网站支付接口
      format: "JSON",
      charset: ALIPAY_CONFIG.APP_CONFIG.charset,
      sign_type: ALIPAY_CONFIG.APP_CONFIG.sign_type,
      timestamp,
      version: ALIPAY_CONFIG.APP_CONFIG.version,
      notify_url: "https://flutter.ombhrum.com/api/alipay/notify",
      return_url: "https://flutter.ombhrum.com/payment-success.html",
      biz_content: JSON.stringify(bizContent)
    };
    console.log("\u652F\u4ED8\u5B9DWeb\u652F\u4ED8API\u53C2\u6570:", params);
    const privateKey = await importPrivateKey(alipayConfig.privateKey);
    params.sign = await generateSign(params, privateKey);
    const queryString = new URLSearchParams(params).toString();
    const paymentUrl = `${alipayConfig.gateway}?${queryString}`;
    console.log("\u652F\u4ED8\u5B9DWeb\u652F\u4ED8URL:", paymentUrl);
    return jsonResponse({
      orderId: outTradeNo,
      paymentUrl,
      amount: finalAmount,
      originalAmount: planDetails.price,
      isAdminOrder: isAdminUser,
      plan
    });
  } catch (error) {
    console.error("\u521B\u5EFA\u652F\u4ED8\u5B9DWeb\u8BA2\u5355\u5931\u8D25:", error);
    return jsonResponse({ error: "\u521B\u5EFAWeb\u8BA2\u5355\u5931\u8D25: " + error.message }, 500);
  }
}
__name(handleCreateAlipayWebOrder, "handleCreateAlipayWebOrder");
async function handleQueryAlipayOrder(request, env) {
  try {
    const url = new URL(request.url);
    const orderId = url.searchParams.get("orderId");
    if (!orderId) {
      return jsonResponse({ error: "\u8BA2\u5355ID\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
    }
    const orderData = await env.ORDERS_KV.get(orderId);
    if (!orderData) {
      return jsonResponse({ error: "\u8BA2\u5355\u4E0D\u5B58\u5728" }, 404);
    }
    return jsonResponse(JSON.parse(orderData));
  } catch (error) {
    console.error("\u67E5\u8BE2\u8BA2\u5355\u5931\u8D25:", error);
    return jsonResponse({ error: "\u67E5\u8BE2\u8BA2\u5355\u5931\u8D25: " + error.message }, 500);
  }
}
__name(handleQueryAlipayOrder, "handleQueryAlipayOrder");
async function handleAlipayNotify(request, env) {
  console.log("Received Alipay notify request.");
  try {
    const alipayConfig = getAlipayEnvConfig(env);
    const alipayPublicKey = await importPublicKey(alipayConfig.alipayPublicKey);
    const formData = await request.formData();
    const params = {};
    const signParams = {};
    for (const [key, value] of formData.entries()) {
      params[key] = value;
      if (key !== "sign" && key !== "sign_type") {
        signParams[key] = value;
      }
    }
    console.log("Alipay notify params:", JSON.stringify(params, null, 2));
    const sign = params["sign"];
    const isValid = await verifySign(signParams, sign, alipayPublicKey);
    console.log(`Signature verification result: ${isValid}`);
    if (!isValid) {
      console.error("Alipay notify signature verification failed. Params:", JSON.stringify(params));
      return new Response("failure", { status: 400 });
    }
    if (params.trade_status === "TRADE_SUCCESS" || params.trade_status === "TRADE_FINISHED") {
      const outTradeNo = params.out_trade_no;
      const orderDataStr = await env.ORDERS_KV.get(outTradeNo);
      if (!orderDataStr) {
        console.error(`Order not found for notify: ${outTradeNo}`);
        return new Response("failure", { status: 404 });
      }
      const orderData = JSON.parse(orderDataStr);
      if (orderData.status === "PAID") {
        console.log(`Order already paid: ${outTradeNo}`);
        return new Response("success", { status: 200 });
      }
      orderData.status = "PAID";
      orderData.paidAt = params.gmt_payment || (/* @__PURE__ */ new Date()).toISOString();
      orderData.tradeNo = params.trade_no;
      await env.ORDERS_KV.put(outTradeNo, JSON.stringify(orderData));
      const userDataStr = await env.USERS_KV.get(`user:${orderData.userId}`);
      if (!userDataStr) {
        console.error(`User not found for order: ${outTradeNo}, user: ${orderData.userId}`);
        return new Response("failure", { status: 404 });
      }
      const user = JSON.parse(userDataStr);
      const planDetails = WORKER_MEMBERSHIP_PLANS[orderData.plan];
      const currentMembership = checkMembershipStatus(user);
      const startDate = currentMembership.isActive && currentMembership.expiresAt ? new Date(currentMembership.expiresAt) : /* @__PURE__ */ new Date();
      const endDate = new Date(startDate.getTime() + planDetails.duration);
      user.membershipType = "paid";
      user.membershipExpiresAt = endDate.toISOString();
      const purchaseRecord = {
        id: crypto.randomUUID(),
        orderId: outTradeNo,
        plan: orderData.plan,
        amount: planDetails.price,
        currency: "CNY",
        status: "completed",
        paymentMethod: "alipay",
        purchasedAt: (/* @__PURE__ */ new Date()).toISOString(),
        validFrom: startDate.toISOString(),
        validTo: endDate.toISOString()
      };
      const existingPurchases = await env.USERS_KV.get(`purchases:${orderData.userId}`);
      const purchases = existingPurchases ? JSON.parse(existingPurchases) : [];
      purchases.unshift(purchaseRecord);
      await env.USERS_KV.put(`purchases:${orderData.userId}`, JSON.stringify(purchases));
      await env.USERS_KV.put(`user:${orderData.userId}`, JSON.stringify(user));
      console.log(`Membership activated for user ${orderData.userId} until ${user.membershipExpiresAt}`);
    }
    return new Response("success", { status: 200 });
  } catch (error) {
    console.error("\u5904\u7406\u652F\u4ED8\u5B9D\u901A\u77E5\u5931\u8D25:", error.message, error.stack);
    return new Response("failure", { status: 500 });
  }
}
__name(handleAlipayNotify, "handleAlipayNotify");
async function handleGetAlipayMembershipStatus(request, env) {
  return handleGetMembershipStatus(request, env);
}
__name(handleGetAlipayMembershipStatus, "handleGetAlipayMembershipStatus");
async function handleGetMembershipStatus(request, env) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
    }
    const token = authHeader.substring(7);
    const tokenData = await verifyToken(token, env);
    if (!tokenData) {
      return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
    }
    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 404);
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
    console.error("\u83B7\u53D6\u4F1A\u5458\u72B6\u6001\u5931\u8D25:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u4F1A\u5458\u72B6\u6001\u5931\u8D25" }, 500);
  }
}
__name(handleGetMembershipStatus, "handleGetMembershipStatus");
async function handleCreateSubscription(request, env) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
    }
    const token = authHeader.substring(7);
    const tokenData = await verifyToken(token, env);
    if (!tokenData) {
      return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
    }
    const { currency = "cny" } = await request.json();
    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 404);
    }
    const user = JSON.parse(userData);
    const membershipStatus = checkMembershipStatus(user);
    if (membershipStatus.isActive && membershipStatus.type === "paid") {
      return jsonResponse({ error: "\u60A8\u5DF2\u7ECF\u662F\u4ED8\u8D39\u4F1A\u5458" }, 400);
    }
    if (!env.STRIPE_SECRET_KEY) {
      return jsonResponse({ error: "Stripe\u914D\u7F6E\u672A\u8BBE\u7F6E" }, 500);
    }
    const stripe = createStripeClient(env.STRIPE_SECRET_KEY);
    let customerId = user.stripeCustomerId;
    if (!customerId) {
      const customer = await stripe.createCustomer(user.email, user.username);
      customerId = customer.id;
      user.stripeCustomerId = customerId;
      await env.USERS_KV.put(`user:${tokenData.username}`, JSON.stringify(user));
    }
    const priceId = currency === "usd" ? STRIPE_CONFIG.PRODUCTS.MONTHLY_MEMBERSHIP_USD : STRIPE_CONFIG.PRODUCTS.MONTHLY_MEMBERSHIP_CNY;
    const isTrialUser = membershipStatus.type === "trial" && membershipStatus.isActive;
    const subscription = await stripe.createSubscription(
      customerId,
      priceId,
      isTrialUser ? null : STRIPE_CONFIG.FREE_TRIAL_DAYS
    );
    return jsonResponse({
      subscriptionId: subscription.id,
      clientSecret: subscription.latest_invoice.payment_intent.client_secret,
      customerId
    });
  } catch (error) {
    console.error("\u521B\u5EFA\u8BA2\u9605\u5931\u8D25:", error);
    return jsonResponse({ error: "\u521B\u5EFA\u8BA2\u9605\u5931\u8D25: " + error.message }, 500);
  }
}
__name(handleCreateSubscription, "handleCreateSubscription");
async function handleStripeWebhook(request, env) {
  try {
    if (!env.STRIPE_WEBHOOK_SECRET) {
      return jsonResponse({ error: "Webhook\u914D\u7F6E\u672A\u8BBE\u7F6E" }, 500);
    }
    const body = await request.text();
    const signature = request.headers.get("stripe-signature");
    const event = JSON.parse(body);
    console.log("\u6536\u5230Stripe Webhook\u4E8B\u4EF6:", event.type);
    switch (event.type) {
      case "invoice.payment_succeeded":
        await handlePaymentSucceeded(event.data.object, env);
        break;
      case "invoice.payment_failed":
        await handlePaymentFailed(event.data.object, env);
        break;
      case "customer.subscription.updated":
      case "customer.subscription.created":
        await handleSubscriptionUpdated(event.data.object, env);
        break;
      case "customer.subscription.deleted":
        await handleSubscriptionDeleted(event.data.object, env);
        break;
      default:
        console.log("\u672A\u5904\u7406\u7684\u4E8B\u4EF6\u7C7B\u578B:", event.type);
    }
    return jsonResponse({ received: true });
  } catch (error) {
    console.error("Webhook\u5904\u7406\u5931\u8D25:", error);
    return jsonResponse({ error: "Webhook\u5904\u7406\u5931\u8D25" }, 400);
  }
}
__name(handleStripeWebhook, "handleStripeWebhook");
async function handlePaymentSucceeded(invoice, env) {
  try {
    const customerId = invoice.customer;
    const subscriptionId = invoice.subscription;
    const users = await env.USERS_KV.list({ prefix: "user:" });
    for (const key of users.keys) {
      const userData = await env.USERS_KV.get(key.name);
      if (!userData) continue;
      const user = JSON.parse(userData);
      if (user.stripeCustomerId === customerId) {
        const now = /* @__PURE__ */ new Date();
        const nextMonth = new Date(now);
        nextMonth.setMonth(nextMonth.getMonth() + 1);
        user.membershipType = "paid";
        user.membershipExpiresAt = nextMonth.toISOString();
        user.subscriptionId = subscriptionId;
        user.lastPaymentDate = now.toISOString();
        await env.USERS_KV.put(key.name, JSON.stringify(user));
        console.log("\u7528\u6237\u4F1A\u5458\u72B6\u6001\u5DF2\u66F4\u65B0:", user.username);
        break;
      }
    }
  } catch (error) {
    console.error("\u5904\u7406\u652F\u4ED8\u6210\u529F\u4E8B\u4EF6\u5931\u8D25:", error);
  }
}
__name(handlePaymentSucceeded, "handlePaymentSucceeded");
async function handlePaymentFailed(invoice, env) {
  try {
    const customerId = invoice.customer;
    const users = await env.USERS_KV.list({ prefix: "user:" });
    for (const key of users.keys) {
      const userData = await env.USERS_KV.get(key.name);
      if (!userData) continue;
      const user = JSON.parse(userData);
      if (user.stripeCustomerId === customerId) {
        user.lastPaymentFailedDate = (/* @__PURE__ */ new Date()).toISOString();
        await env.USERS_KV.put(key.name, JSON.stringify(user));
        console.log("\u8BB0\u5F55\u652F\u4ED8\u5931\u8D25:", user.username);
        break;
      }
    }
  } catch (error) {
    console.error("\u5904\u7406\u652F\u4ED8\u5931\u8D25\u4E8B\u4EF6\u5931\u8D25:", error);
  }
}
__name(handlePaymentFailed, "handlePaymentFailed");
async function handleSubscriptionUpdated(subscription, env) {
  try {
    const customerId = subscription.customer;
    const status = subscription.status;
    const users = await env.USERS_KV.list({ prefix: "user:" });
    for (const key of users.keys) {
      const userData = await env.USERS_KV.get(key.name);
      if (!userData) continue;
      const user = JSON.parse(userData);
      if (user.stripeCustomerId === customerId) {
        user.subscriptionStatus = status;
        user.subscriptionId = subscription.id;
        if (status === "active") {
          const periodEnd = new Date(subscription.current_period_end * 1e3);
          user.membershipType = "paid";
          user.membershipExpiresAt = periodEnd.toISOString();
        } else if (status === "canceled" || status === "unpaid") {
          user.membershipType = "expired";
        }
        await env.USERS_KV.put(key.name, JSON.stringify(user));
        console.log("\u8BA2\u9605\u72B6\u6001\u5DF2\u66F4\u65B0:", user.username, status);
        break;
      }
    }
  } catch (error) {
    console.error("\u5904\u7406\u8BA2\u9605\u66F4\u65B0\u4E8B\u4EF6\u5931\u8D25:", error);
  }
}
__name(handleSubscriptionUpdated, "handleSubscriptionUpdated");
async function handleSubscriptionDeleted(subscription, env) {
  try {
    const customerId = subscription.customer;
    const users = await env.USERS_KV.list({ prefix: "user:" });
    for (const key of users.keys) {
      const userData = await env.USERS_KV.get(key.name);
      if (!userData) continue;
      const user = JSON.parse(userData);
      if (user.stripeCustomerId === customerId) {
        user.subscriptionStatus = "canceled";
        user.membershipType = "expired";
        user.subscriptionId = null;
        await env.USERS_KV.put(key.name, JSON.stringify(user));
        console.log("\u8BA2\u9605\u5DF2\u53D6\u6D88:", user.username);
        break;
      }
    }
  } catch (error) {
    console.error("\u5904\u7406\u8BA2\u9605\u5220\u9664\u4E8B\u4EF6\u5931\u8D25:", error);
  }
}
__name(handleSubscriptionDeleted, "handleSubscriptionDeleted");
async function handleCancelSubscription(request, env) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
    }
    const token = authHeader.substring(7);
    const tokenData = await verifyToken(token, env);
    if (!tokenData) {
      return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
    }
    const userData = await env.USERS_KV.get(`user:${tokenData.username}`);
    if (!userData) {
      return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 404);
    }
    const user = JSON.parse(userData);
    if (!user.subscriptionId) {
      return jsonResponse({ error: "\u6CA1\u6709\u6D3B\u8DC3\u7684\u8BA2\u9605" }, 400);
    }
    if (!env.STRIPE_SECRET_KEY) {
      return jsonResponse({ error: "Stripe\u914D\u7F6E\u672A\u8BBE\u7F6E" }, 500);
    }
    const stripe = createStripeClient(env.STRIPE_SECRET_KEY);
    await stripe.cancelSubscription(user.subscriptionId);
    return jsonResponse({ message: "\u8BA2\u9605\u5DF2\u53D6\u6D88" });
  } catch (error) {
    console.error("\u53D6\u6D88\u8BA2\u9605\u5931\u8D25:", error);
    return jsonResponse({ error: "\u53D6\u6D88\u8BA2\u9605\u5931\u8D25: " + error.message }, 500);
  }
}
__name(handleCancelSubscription, "handleCancelSubscription");
var worker_default = {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const pathname = url.pathname;
    const method = request.method;
    if (method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }
    try {
      if (pathname === "/health") {
        return jsonResponse({ status: "ok", timestamp: (/* @__PURE__ */ new Date()).toISOString() });
      }
      if (pathname === "/api/assets/list" && method === "GET") {
        try {
          let r2Files = [];
          if (env.R2_BUCKET) {
            const r2Objects = await env.R2_BUCKET.list();
            if (r2Objects && r2Objects.objects) {
              r2Files = r2Objects.objects.map((obj) => ({
                key: obj.key,
                size: obj.size,
                uploaded: obj.uploaded,
                source: "r2"
                // 标记来源为 R2
              }));
            }
          }
          let staticFiles = [];
          if (env.ASSETS) {
            const manifestUrl = new URL("/asset-manifest.json", request.url);
            const manifestRequest = new Request(manifestUrl);
            const manifestResponse = await env.ASSETS.fetch(manifestRequest);
            if (manifestResponse.ok) {
              try {
                staticFiles = await manifestResponse.json();
              } catch (e) {
                console.error("Failed to parse asset-manifest.json", e);
              }
            }
          }
          const allFiles = [...staticFiles, ...r2Files];
          const finalFiles = [];
          const seenKeys = /* @__PURE__ */ new Set();
          for (const file of r2Files) {
            if (!seenKeys.has(file.key)) {
              finalFiles.push(file);
              seenKeys.add(file.key);
            }
          }
          for (const file of staticFiles) {
            if (!seenKeys.has(file.key)) {
              finalFiles.push(file);
              seenKeys.add(file.key);
            }
          }
          return jsonResponse({
            files: finalFiles,
            count: finalFiles.length
          });
        } catch (error) {
          console.error("\u83B7\u53D6\u7D20\u6750\u5217\u8868\u5931\u8D25:", error);
          return jsonResponse({ error: "\u83B7\u53D6\u7D20\u6750\u5217\u8868\u5931\u8D25: " + error.message }, 500);
        }
      }
      if (pathname.startsWith("/api/auth/")) {
        if (pathname === "/api/auth/register" && method === "POST") {
          return await handleRegister(request, env);
        }
        if (pathname === "/api/auth/login" && method === "POST") {
          return await handleLogin(request, env);
        }
        if (pathname === "/api/auth/verify" && method === "GET") {
          return await handleVerify(request, env);
        }
        if (pathname === "/api/auth/logout" && method === "POST") {
          return await handleLogout(request, env);
        }
        if (pathname === "/api/auth/send-verification-code" && method === "POST") {
          return await handleSendVerificationCode(request, env, ctx);
        }
        if (pathname === "/api/auth/verify-code" && method === "POST") {
          return await handleVerifyCode(request, env);
        }
        if (pathname === "/api/auth/forgot-password" && method === "POST") {
          return await handleForgotPassword(request, env);
        }
        if (pathname === "/api/auth/reset-password" && method === "POST") {
          return await handleResetPassword(request, env);
        }
        if (pathname === "/api/auth/wechat/login-url" && method === "GET") {
          return await handleGetWechatLoginUrl(request, env);
        }
        if (pathname === "/api/auth/wechat/login" && method === "POST") {
          return await handleWechatLogin(request, env);
        }
        if (pathname === "/api/auth/wechat/bind" && method === "POST") {
          return await handleWechatBind(request, env);
        }
        if (pathname === "/api/auth/wechat/register" && method === "POST") {
          return await handleWechatRegister(request, env);
        }
        if (pathname === "/api/auth/wechat/unbind" && method === "POST") {
          return await handleWechatUnbind(request, env);
        }
        if (pathname === "/api/auth/alipay/login-url" && method === "GET") {
          console.log("\u6536\u5230\u652F\u4ED8\u5B9D\u767B\u5F55URL\u8BF7\u6C42");
          try {
            const url2 = new URL(request.url);
            const platform = url2.searchParams.get("platform");
            const result = await generateAlipayLoginUrl(env, platform);
            console.log("\u652F\u4ED8\u5B9D\u767B\u5F55URL\u751F\u6210\u7ED3\u679C:", result);
            return result;
          } catch (error) {
            console.error("\u652F\u4ED8\u5B9D\u767B\u5F55URL\u8BF7\u6C42\u5904\u7406\u5931\u8D25:", error);
            return jsonResponse({ error: "\u652F\u4ED8\u5B9D\u767B\u5F55URL\u8BF7\u6C42\u5904\u7406\u5931\u8D25: " + error.message }, 500);
          }
        }
        if (pathname === "/api/auth/alipay/login" && method === "POST") {
          return await handleAlipayLogin(request, env);
        }
        if (pathname === "/api/auth/alipay/register" && method === "POST") {
          return await registerAlipayUser(request, env);
        }
        if (pathname === "/api/auth/alipay/check-email" && method === "POST") {
          return await checkEmailAvailability(request, env);
        }
        if (pathname === "/api/auth/alipay/send-captcha" && method === "POST") {
          return await sendRegistrationCaptcha(request, env);
        }
        if (pathname === "/api/auth/alipay/callback" && method === "GET") {
          return await handleAlipayCallback(request, env);
        }
        if (pathname === "/api/auth/alipay/macos-callback" && method === "GET") {
          return await handleMacOSAlipayCallback(request, env);
        }
        if (pathname === "/api/auth/user-info" && method === "GET") {
          return await handleGetUserInfo(request, env);
        }
        if (pathname === "/api/auth/bind-email" && method === "POST") {
          return await handleBindEmail(request, env);
        }
      }
      if (pathname.startsWith("/api/alipay/")) {
        if (pathname === "/api/alipay/create-order" && method === "POST") {
          return await handleCreateAlipayOrder(request, env);
        }
        if (pathname === "/api/alipay/create-web-order" && method === "POST") {
          return await handleCreateAlipayWebOrder(request, env);
        }
        if (pathname === "/api/alipay/query-order" && method === "GET") {
          return await handleQueryAlipayOrder(request, env);
        }
        if (pathname === "/api/alipay/notify" && method === "POST") {
          return await handleAlipayNotify(request, env);
        }
        if (pathname === "/api/alipay/check-membership" && method === "GET") {
          return await handleGetAlipayMembershipStatus(request, env);
        }
      }
      if (pathname.startsWith("/api/stripe/")) {
        if (pathname === "/api/stripe/membership-status" && method === "GET") {
          return await handleGetMembershipStatus(request, env);
        }
        if (pathname === "/api/stripe/create-subscription" && method === "POST") {
          return await handleCreateSubscription(request, env);
        }
        if (pathname === "/api/stripe/cancel-subscription" && method === "POST") {
          return await handleCancelSubscription(request, env);
        }
        if (pathname === "/api/stripe/webhook" && method === "POST") {
          return await handleStripeWebhook(request, env);
        }
      }
      if (pathname.startsWith("/api/admin/")) {
        if (pathname === "/api/admin/check-status" && method === "GET") {
          return await handleCheckAdminStatus(request, env);
        }
        if (pathname === "/api/admin/create-redeem-code" && method === "POST") {
          return await handleCreateRedeemCode(request, env);
        }
        if (pathname === "/api/admin/redeem-codes" && method === "GET") {
          return await handleListRedeemCodes(request, env);
        }
        if (pathname === "/api/admin/use-redeem-code" && method === "POST") {
          return await handleUseRedeemCode(request, env);
        }
        if (pathname === "/api/admin/delete-redeem-code" && method === "DELETE") {
          return await handleDeleteRedeemCode(request, env);
        }
        if (pathname === "/api/admin/get-price" && method === "POST") {
          return await handleGetAdminPrice(request, env);
        }
        if (pathname === "/api/admin/purchase-history" && method === "GET") {
          return await handleGetPurchaseHistory(request, env);
        }
        if (pathname === "/api/admin/redeem-history" && method === "GET") {
          return await handleGetRedeemHistory(request, env);
        }
      }
      if (pathname === "/r2" && url.searchParams.has("list")) {
        console.log("R2 \u5217\u8868\u8BF7\u6C42\u5F00\u59CB");
        console.log("\u73AF\u5883\u53D8\u91CF\u68C0\u67E5:", {
          hasR2Bucket: !!env.R2_BUCKET,
          envKeys: Object.keys(env || {}),
          bucketType: typeof env.R2_BUCKET
        });
        if (!env.R2_BUCKET) {
          console.error("R2_BUCKET \u672A\u7ED1\u5B9A");
          return new Response("\u9519\u8BEF\uFF1AR2 \u5B58\u50A8\u6876\u672A\u7ED1\u5B9A\u5230\u6B64 Worker", { status: 500, headers: corsHeaders });
        }
        try {
          console.log("\u5F00\u59CB\u5217\u51FA R2 \u5B58\u50A8\u6876\u5185\u5BB9...");
          const objects = await env.R2_BUCKET.list();
          console.log(`R2 \u5217\u8868\u7ED3\u679C: \u627E\u5230 ${objects.objects?.length || 0} \u4E2A\u5BF9\u8C61`);
          if (!objects.objects) {
            console.log("R2 \u5217\u8868\u8FD4\u56DE\u7684 objects \u4E3A\u7A7A");
            return jsonResponse({
              objects: [],
              files: [],
              count: 0,
              truncated: false,
              error: "R2 \u5217\u8868\u8FD4\u56DE\u7A7A\u7ED3\u679C"
            });
          }
          const fileList = objects.objects.map((obj) => ({
            key: obj.key,
            size: obj.size,
            uploaded: obj.uploaded
          }));
          console.log("R2 \u6587\u4EF6\u5217\u8868:", fileList.map((f) => f.key));
          return jsonResponse({
            objects: fileList,
            // 改为 objects 以保持一致性
            files: fileList,
            // 保留 files 字段以兼容旧代码
            count: fileList.length,
            truncated: objects.truncated
          });
        } catch (error) {
          console.error("\u5217\u51FAR2\u5BF9\u8C61\u5931\u8D25:", error);
          console.error("\u9519\u8BEF\u8BE6\u60C5:", error.stack);
          return jsonResponse({
            error: "\u5217\u51FA\u6587\u4EF6\u5931\u8D25: " + error.message,
            details: error.stack
          }, 500);
        }
      }
      if (pathname === "/member-center.html") {
        const memberCenterHTML = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>\u4F1A\u5458\u4E2D\u5FC3</title>
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
        <h1>\u6B22\u8FCE, <span id="username"></span>!</h1>
        <p>\u8FD9\u91CC\u662F\u60A8\u7684\u4F1A\u5458\u4E2D\u5FC3\u3002</p>
        <button onclick="logout()">\u9000\u51FA\u767B\u5F55</button>
    </div>
    <div id="loading">\u6B63\u5728\u9A8C\u8BC1\u8EAB\u4EFD\uFF0C\u8BF7\u7A0D\u5019...</div>

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
                    const errorData = await response.json().catch(() => ({ error: '\u65E0\u6CD5\u89E3\u6790\u9519\u8BEF\u4FE1\u606F' }));
                    console.error('Authentication failed:', errorData);
                    alert('\u4F1A\u8BDD\u65E0\u6548\u6216\u5DF2\u8FC7\u671F\uFF0C\u8BF7\u91CD\u65B0\u767B\u5F55\u3002\\n\u670D\u52A1\u5668\u8FD4\u56DE\u4FE1\u606F: ' + (errorData.error || '\u672A\u77E5\u9519\u8BEF'));
                    localStorage.removeItem('authToken');
                    window.location.href = '/login.html';
                }
            } catch (error) {
                console.error('Authentication network error:', error);
                alert('\u9A8C\u8BC1\u8EAB\u4EFD\u65F6\u53D1\u751F\u7F51\u7EDC\u9519\u8BEF\uFF0C\u8BF7\u68C0\u67E5\u60A8\u7684\u7F51\u7EDC\u8FDE\u63A5\u3002');
                localStorage.removeItem('authToken');
                window.location.href = '/login.html';
            }
        })();

        function logout() {
            localStorage.removeItem('authToken');
            window.location.href = '/login.html';
        }
    <\/script>
</body>
</html>`;
        return new Response(memberCenterHTML, { headers: { "Content-Type": "text/html;charset=UTF-8" } });
      }
      if (pathname === "/") {
        return Response.redirect(new URL("/member-center.html", request.url).toString(), 302);
      }
      if (pathname === "/r2" && url.searchParams.has("file")) {
        let fileKey = url.searchParams.get("file").trim();
        if (!fileKey) {
          return new Response("\u9519\u8BEF\uFF1A\u672A\u6307\u5B9A\u6587\u4EF6\u53C2\u6570", { status: 400, headers: corsHeaders });
        }
        if (!env.R2_BUCKET) {
          return new Response("\u9519\u8BEF\uFF1AR2 \u5B58\u50A8\u6876\u672A\u7ED1\u5B9A\u5230\u6B64 Worker", { status: 500, headers: corsHeaders });
        }
        if (method === "HEAD") {
          console.log(`HEAD \u8BF7\u6C42\u6587\u4EF6: ${fileKey}`);
          console.log(`\u6587\u4EF6 Key \u957F\u5EA6: ${fileKey.length}`);
          console.log(`\u6587\u4EF6 Key CharCodes: ${Array.from(fileKey).map((c) => c.charCodeAt(0)).join(",")}`);
          let headObject;
          try {
            headObject = await env.R2_BUCKET.head(fileKey);
            if (headObject === null) {
              console.log(`\u6587\u4EF6\u4E0D\u5B58\u5728: ${fileKey}`);
              try {
                const prefix = fileKey.length > 3 ? fileKey.substring(0, 3) : fileKey;
                const listResult = await env.R2_BUCKET.list({ prefix, limit: 10 });
                if (listResult.objects && listResult.objects.length > 0) {
                  console.log("\u5B58\u50A8\u6876\u4E2D\u7684\u76F8\u4F3C\u6587\u4EF6:");
                  listResult.objects.forEach((obj) => {
                    console.log(`  - "${obj.key}" (${(obj.size / 1024 / 1024).toFixed(2)} MB)`);
                  });
                } else {
                  console.log("\u5B58\u50A8\u6876\u4E2D\u6CA1\u6709\u627E\u5230\u76F8\u4F3C\u6587\u4EF6");
                }
              } catch (listError) {
                console.log("\u65E0\u6CD5\u5217\u51FA\u76F8\u4F3C\u6587\u4EF6:", listError.message);
              }
              return new Response("\u9519\u8BEF\uFF1A\u5728 R2 \u5B58\u50A8\u6876\u4E2D\u672A\u627E\u5230\u6307\u5B9A\u7684\u6587\u4EF6", { status: 404, headers: corsHeaders });
            }
            console.log(`R2 HEAD \u7ED3\u679C: size=${headObject.size}, etag=${headObject.httpEtag}`);
            const headers2 = new Headers();
            try {
              headObject.writeHttpMetadata(headers2);
            } catch (metadataError) {
              console.warn("\u5199\u5165HTTP\u5143\u6570\u636E\u5931\u8D25:", metadataError.message);
            }
            headers2.set("etag", headObject.httpEtag);
            headers2.set("Content-Length", String(headObject.size));
            headers2.set("Accept-Ranges", "bytes");
            headers2.set("Access-Control-Allow-Origin", "*");
            headers2.set("Access-Control-Allow-Headers", "Content-Type, Authorization, Range");
            headers2.set("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS");
            headers2.set("Access-Control-Expose-Headers", "Content-Length, Content-Range, Etag");
            headers2.set("Cache-Control", "no-cache, no-store, must-revalidate");
            headers2.set("Pragma", "no-cache");
            headers2.set("Expires", "0");
            console.log(`HEAD \u54CD\u5E94\u5934 Content-Length: ${headers2.get("Content-Length")}`);
            return new Response(null, { status: 200, headers: headers2 });
          } catch (error) {
            console.error("R2 HEAD \u8BF7\u6C42\u5931\u8D25:", error);
            return new Response(`R2 \u8BBF\u95EE\u9519\u8BEF: ${error.message}`, { status: 500, headers: corsHeaders });
          }
        }
        const rangeHeader = request.headers.get("Range");
        if (rangeHeader) {
          console.log(`Range \u8BF7\u6C42: ${rangeHeader} for ${fileKey}`);
          const match = /bytes\s*=\s*(\d+)-(\d+)?/.exec(rangeHeader);
          if (match) {
            const start = Number(match[1]);
            const endMaybe = match[2] !== void 0 ? Number(match[2]) : void 0;
            const headObject = await env.R2_BUCKET.head(fileKey);
            if (headObject === null) {
              console.log(`Range \u8BF7\u6C42\u65F6\u6587\u4EF6\u4E0D\u5B58\u5728: ${fileKey}`);
              try {
                const prefix = fileKey.length > 3 ? fileKey.substring(0, 3) : fileKey;
                const listResult = await env.R2_BUCKET.list({ prefix, limit: 5 });
                if (listResult.objects && listResult.objects.length > 0) {
                  console.log("\u5B58\u50A8\u6876\u4E2D\u7684\u76F8\u4F3C\u6587\u4EF6:");
                  listResult.objects.forEach((obj) => {
                    console.log(`  - "${obj.key}"`);
                  });
                }
              } catch (listError) {
                console.log("\u65E0\u6CD5\u5217\u51FA\u76F8\u4F3C\u6587\u4EF6:", listError.message);
              }
              return new Response("\u9519\u8BEF\uFF1A\u5728 R2 \u5B58\u50A8\u6876\u4E2D\u672A\u627E\u5230\u6307\u5B9A\u7684\u6587\u4EF6", { status: 404, headers: corsHeaders });
            }
            const size = headObject.size;
            console.log(`Range \u8BF7\u6C42\u4E2D R2 HEAD \u7ED3\u679C: size=${size}, etag=${headObject.httpEtag}`);
            const end = endMaybe !== void 0 ? Math.min(endMaybe, size - 1) : size - 1;
            const length = end - start + 1;
            if (start >= size || start < 0 || length <= 0) {
              return new Response("\u8BF7\u6C42\u7684\u8303\u56F4\u65E0\u6548", { status: 416, headers: { "Content-Range": `bytes */${size}` } });
            }
            const rangedObject = await env.R2_BUCKET.get(fileKey, { range: { offset: start, length } });
            if (rangedObject === null) {
              return new Response("\u9519\u8BEF\uFF1A\u5728 R2 \u5B58\u50A8\u6876\u4E2D\u672A\u627E\u5230\u6307\u5B9A\u7684\u6587\u4EF6", { status: 404, headers: corsHeaders });
            }
            const headers2 = new Headers();
            try {
              rangedObject.writeHttpMetadata(headers2);
            } catch (metadataError) {
              console.warn("Range\u8BF7\u6C42\u5199\u5165HTTP\u5143\u6570\u636E\u5931\u8D25:", metadataError.message);
            }
            headers2.set("etag", rangedObject.httpEtag);
            headers2.set("Content-Length", String(length));
            headers2.set("Content-Range", `bytes ${start}-${end}/${size}`);
            headers2.set("Accept-Ranges", "bytes");
            headers2.set("Access-Control-Allow-Origin", "*");
            headers2.set("Access-Control-Allow-Headers", "Content-Type, Authorization, Range");
            headers2.set("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS");
            headers2.set("Access-Control-Expose-Headers", "Content-Length, Content-Range, Etag");
            headers2.set("Cache-Control", "no-cache, no-store, must-revalidate");
            return new Response(rangedObject.body, { status: 206, headers: headers2 });
          }
        }
        const object = await env.R2_BUCKET.get(fileKey);
        if (object === null) {
          return new Response("\u9519\u8BEF\uFF1A\u5728 R2 \u5B58\u50A8\u6876\u4E2D\u672A\u627E\u5230\u6307\u5B9A\u7684\u6587\u4EF6", { status: 404, headers: corsHeaders });
        }
        const headers = new Headers();
        try {
          object.writeHttpMetadata(headers);
        } catch (metadataError) {
          console.warn("GET\u8BF7\u6C42\u5199\u5165HTTP\u5143\u6570\u636E\u5931\u8D25:", metadataError.message);
        }
        headers.set("etag", object.httpEtag);
        headers.set("Content-Length", String(object.size));
        headers.set("Accept-Ranges", "bytes");
        headers.set("Access-Control-Allow-Origin", "*");
        headers.set("Access-Control-Allow-Headers", "Content-Type, Authorization, Range");
        headers.set("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS");
        headers.set("Access-Control-Expose-Headers", "Content-Length, Content-Range, Etag");
        headers.set("Cache-Control", "no-cache, no-store, must-revalidate");
        return new Response(object.body, {
          headers,
          status: 200
        });
      }
      if (!env.ASSETS) {
        return new Response("Error: [ASSETS] binding is not configured. Check your wrangler.toml file.", { status: 500 });
      }
      let response = await env.ASSETS.fetch(request);
      if (response.status === 404) {
        const url2 = new URL(request.url);
        if (!url2.pathname.startsWith("/api/") && !/\.[^/]+$/.test(url2.pathname)) {
          const spaRequest = new Request(new URL("/index.html", request.url), request);
          response = await env.ASSETS.fetch(spaRequest);
        }
      }
      if (pathname === "/membership.html") {
        const indexRequest = new Request(new URL("/index.html", request.url), request);
        response = await env.ASSETS.fetch(indexRequest);
      }
      if (pathname === "/membership") {
        const indexRequest = new Request(new URL("/index.html", request.url), request);
        response = await env.ASSETS.fetch(indexRequest);
      }
      if (pathname === "/#/membership") {
        const indexRequest = new Request(new URL("/index.html", request.url), request);
        response = await env.ASSETS.fetch(indexRequest);
      }
      if (response) {
        const newResponse = new Response(
          request.method === "HEAD" ? null : response.body,
          {
            status: response.status,
            statusText: response.statusText,
            headers: response.headers
          }
        );
        newResponse.headers.set("Access-Control-Allow-Origin", "*");
        newResponse.headers.set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        newResponse.headers.set("Access-Control-Allow-Headers", "Content-Type, Authorization, Range");
        newResponse.headers.set("Access-Control-Expose-Headers", "Content-Length, Content-Range, Etag");
        const p = url.pathname;
        const noCacheList = ["/", "/index.html", "/flutter_service_worker.js", "/main.dart.js"];
        if (noCacheList.includes(p)) {
          newResponse.headers.set("Cache-Control", "no-cache, no-store, must-revalidate");
          newResponse.headers.set("Pragma", "no-cache");
          newResponse.headers.set("Expires", "0");
        } else if (/\.(?:js|css|png|jpg|jpeg|gif|svg|woff2?|json|wasm)$/i.test(p)) {
          if (!newResponse.headers.has("Cache-Control")) {
            newResponse.headers.set("Cache-Control", "public, max-age=31536000, immutable");
          }
        }
        return newResponse;
      }
      return response;
    } catch (error) {
      console.error("Worker error:", error);
      console.error("Error type:", error.constructor.name);
      console.error("Error message:", error.message);
      console.error("Error stack:", error.stack);
      console.error("Request URL:", request.url);
      console.error("Request method:", request.method);
      return new Response("Internal Server Error", { status: 500, headers: corsHeaders });
    }
  }
};

// ../../../../.npm-global/lib/node_modules/wrangler/templates/middleware/middleware-ensure-req-body-drained.ts
var drainBody = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } finally {
    try {
      if (request.body !== null && !request.bodyUsed) {
        const reader = request.body.getReader();
        while (!(await reader.read()).done) {
        }
      }
    } catch (e) {
      console.error("Failed to drain the unused request body.", e);
    }
  }
}, "drainBody");
var middleware_ensure_req_body_drained_default = drainBody;

// ../../../../.npm-global/lib/node_modules/wrangler/templates/middleware/middleware-miniflare3-json-error.ts
function reduceError(e) {
  return {
    name: e?.name,
    message: e?.message ?? String(e),
    stack: e?.stack,
    cause: e?.cause === void 0 ? void 0 : reduceError(e.cause)
  };
}
__name(reduceError, "reduceError");
var jsonError = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } catch (e) {
    const error = reduceError(e);
    return Response.json(error, {
      status: 500,
      headers: { "MF-Experimental-Error-Stack": "true" }
    });
  }
}, "jsonError");
var middleware_miniflare3_json_error_default = jsonError;

// .wrangler/tmp/bundle-r02JVv/middleware-insertion-facade.js
var __INTERNAL_WRANGLER_MIDDLEWARE__ = [
  middleware_ensure_req_body_drained_default,
  middleware_miniflare3_json_error_default
];
var middleware_insertion_facade_default = worker_default;

// ../../../../.npm-global/lib/node_modules/wrangler/templates/middleware/common.ts
var __facade_middleware__ = [];
function __facade_register__(...args) {
  __facade_middleware__.push(...args.flat());
}
__name(__facade_register__, "__facade_register__");
function __facade_invokeChain__(request, env, ctx, dispatch, middlewareChain) {
  const [head, ...tail] = middlewareChain;
  const middlewareCtx = {
    dispatch,
    next(newRequest, newEnv) {
      return __facade_invokeChain__(newRequest, newEnv, ctx, dispatch, tail);
    }
  };
  return head(request, env, ctx, middlewareCtx);
}
__name(__facade_invokeChain__, "__facade_invokeChain__");
function __facade_invoke__(request, env, ctx, dispatch, finalMiddleware) {
  return __facade_invokeChain__(request, env, ctx, dispatch, [
    ...__facade_middleware__,
    finalMiddleware
  ]);
}
__name(__facade_invoke__, "__facade_invoke__");

// .wrangler/tmp/bundle-r02JVv/middleware-loader.entry.ts
var __Facade_ScheduledController__ = class ___Facade_ScheduledController__ {
  constructor(scheduledTime, cron, noRetry) {
    this.scheduledTime = scheduledTime;
    this.cron = cron;
    this.#noRetry = noRetry;
  }
  static {
    __name(this, "__Facade_ScheduledController__");
  }
  #noRetry;
  noRetry() {
    if (!(this instanceof ___Facade_ScheduledController__)) {
      throw new TypeError("Illegal invocation");
    }
    this.#noRetry();
  }
};
function wrapExportedHandler(worker) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return worker;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  const fetchDispatcher = /* @__PURE__ */ __name(function(request, env, ctx) {
    if (worker.fetch === void 0) {
      throw new Error("Handler does not export a fetch() function.");
    }
    return worker.fetch(request, env, ctx);
  }, "fetchDispatcher");
  return {
    ...worker,
    fetch(request, env, ctx) {
      const dispatcher = /* @__PURE__ */ __name(function(type, init) {
        if (type === "scheduled" && worker.scheduled !== void 0) {
          const controller = new __Facade_ScheduledController__(
            Date.now(),
            init.cron ?? "",
            () => {
            }
          );
          return worker.scheduled(controller, env, ctx);
        }
      }, "dispatcher");
      return __facade_invoke__(request, env, ctx, dispatcher, fetchDispatcher);
    }
  };
}
__name(wrapExportedHandler, "wrapExportedHandler");
function wrapWorkerEntrypoint(klass) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return klass;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  return class extends klass {
    #fetchDispatcher = /* @__PURE__ */ __name((request, env, ctx) => {
      this.env = env;
      this.ctx = ctx;
      if (super.fetch === void 0) {
        throw new Error("Entrypoint class does not define a fetch() function.");
      }
      return super.fetch(request);
    }, "#fetchDispatcher");
    #dispatcher = /* @__PURE__ */ __name((type, init) => {
      if (type === "scheduled" && super.scheduled !== void 0) {
        const controller = new __Facade_ScheduledController__(
          Date.now(),
          init.cron ?? "",
          () => {
          }
        );
        return super.scheduled(controller);
      }
    }, "#dispatcher");
    fetch(request) {
      return __facade_invoke__(
        request,
        this.env,
        this.ctx,
        this.#dispatcher,
        this.#fetchDispatcher
      );
    }
  };
}
__name(wrapWorkerEntrypoint, "wrapWorkerEntrypoint");
var WRAPPED_ENTRY;
if (typeof middleware_insertion_facade_default === "object") {
  WRAPPED_ENTRY = wrapExportedHandler(middleware_insertion_facade_default);
} else if (typeof middleware_insertion_facade_default === "function") {
  WRAPPED_ENTRY = wrapWorkerEntrypoint(middleware_insertion_facade_default);
}
var middleware_loader_entry_default = WRAPPED_ENTRY;
export {
  __INTERNAL_WRANGLER_MIDDLEWARE__,
  middleware_loader_entry_default as default
};
//# sourceMappingURL=worker.js.map
