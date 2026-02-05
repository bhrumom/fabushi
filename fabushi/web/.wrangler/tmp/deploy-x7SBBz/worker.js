var __defProp = Object.defineProperty;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });
var __esm = (fn, res) => function __init() {
  return fn && (res = (0, fn[__getOwnPropNames(fn)[0]])(fn = 0)), res;
};
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};

// src/config/constants.js
var constants_exports = {};
__export(constants_exports, {
  ADMIN_EMAIL: () => ADMIN_EMAIL,
  ADMIN_PRICES: () => ADMIN_PRICES,
  CORS_HEADERS: () => CORS_HEADERS,
  MEMBERSHIP_PLANS: () => MEMBERSHIP_PLANS,
  REDEEM_CODE_TYPES: () => REDEEM_CODE_TYPES
});
var ADMIN_EMAIL, ADMIN_PRICES, MEMBERSHIP_PLANS, REDEEM_CODE_TYPES, CORS_HEADERS;
var init_constants = __esm({
  "src/config/constants.js"() {
    ADMIN_EMAIL = "1315518325@qq.com";
    ADMIN_PRICES = {
      "monthly": "0.01",
      "quarterly": "0.01",
      "yearly": "0.01"
    };
    MEMBERSHIP_PLANS = {
      "monthly": {
        name: "\u6708\u5EA6\u4F1A\u5458",
        duration: 30 * 24 * 60 * 60 * 1e3,
        price: "21.00",
        adminPrice: "0.01"
      },
      "quarterly": {
        name: "\u5B63\u5EA6\u4F1A\u5458",
        duration: 90 * 24 * 60 * 60 * 1e3,
        price: "63.00",
        adminPrice: "0.01"
      },
      "yearly": {
        name: "\u5E74\u5EA6\u4F1A\u5458",
        duration: 365 * 24 * 60 * 60 * 1e3,
        price: "252.00",
        adminPrice: "0.01"
      }
    };
    REDEEM_CODE_TYPES = {
      "trial_7": { name: "7\u5929\u8BD5\u7528", days: 7, type: "trial" },
      "monthly": { name: "\u6708\u5EA6\u4F1A\u5458", days: 30, type: "premium" },
      "quarterly": { name: "\u5B63\u5EA6\u4F1A\u5458", days: 90, type: "premium" },
      "yearly": { name: "\u5E74\u5EA6\u4F1A\u5458", days: 365, type: "premium" }
    };
    CORS_HEADERS = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization, Range",
      "Content-Type": "application/json"
    };
  }
});

// auth-utils.js
var auth_utils_exports = {};
__export(auth_utils_exports, {
  base64UrlDecodeToArray: () => base64UrlDecodeToArray,
  base64UrlEncode: () => base64UrlEncode,
  createPasswordHash: () => createPasswordHash,
  derivePbkdf2: () => derivePbkdf2,
  generateToken: () => generateToken,
  jsonResponse: () => jsonResponse2,
  randomBytes: () => randomBytes,
  upgradePasswordIfNeeded: () => upgradePasswordIfNeeded,
  verifyPassword: () => verifyPassword,
  verifyToken: () => verifyToken
});
function base64UrlEncode(buffer) {
  let binary = "";
  const bytes = new Uint8Array(buffer);
  const len = bytes.byteLength;
  for (let i = 0; i < len; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}
function base64UrlDecodeToArray(base64url) {
  const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/");
  const pad = base64.length % 4 === 2 ? "==" : base64.length % 4 === 3 ? "=" : "";
  const str = atob(base64 + pad);
  const bytes = new Uint8Array(str.length);
  for (let i = 0; i < str.length; i++) bytes[i] = str.charCodeAt(i);
  return bytes;
}
function randomBytes(size = 16) {
  const array = new Uint8Array(size);
  crypto.getRandomValues(array);
  return array;
}
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
function jsonResponse2(data, status = 200) {
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
var init_auth_utils = __esm({
  "auth-utils.js"() {
    __name(base64UrlEncode, "base64UrlEncode");
    __name(base64UrlDecodeToArray, "base64UrlDecodeToArray");
    __name(randomBytes, "randomBytes");
    __name(derivePbkdf2, "derivePbkdf2");
    __name(createPasswordHash, "createPasswordHash");
    __name(verifyPassword, "verifyPassword");
    __name(upgradePasswordIfNeeded, "upgradePasswordIfNeeded");
    __name(generateToken, "generateToken");
    __name(verifyToken, "verifyToken");
    __name(jsonResponse2, "jsonResponse");
  }
});

// stripe-config.js
function calculateTrialEndDate(startDate = /* @__PURE__ */ new Date()) {
  const endDate = new Date(startDate);
  endDate.setDate(endDate.getDate() + STRIPE_CONFIG.FREE_TRIAL_DAYS);
  return endDate;
}
var STRIPE_CONFIG;
var init_stripe_config = __esm({
  "stripe-config.js"() {
    STRIPE_CONFIG = {
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
    __name(calculateTrialEndDate, "calculateTrialEndDate");
  }
});

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
var init_alipay_utils = __esm({
  "alipay-utils.js"() {
    __name(importPrivateKey, "importPrivateKey");
    __name(getSignStr, "getSignStr");
    __name(generateSign, "generateSign");
  }
});

// alipay-login-functions.js
var alipay_login_functions_exports = {};
__export(alipay_login_functions_exports, {
  checkEmailAvailability: () => checkEmailAvailability,
  generateAlipayLoginUrl: () => generateAlipayLoginUrl,
  getAccessToken: () => getAccessToken,
  getAlipayUserInfo: () => getAlipayUserInfo,
  getUserInfoWithToken: () => getUserInfoWithToken,
  handleAlipayCallback: () => handleAlipayCallback,
  handleAlipayLogin: () => handleAlipayLogin,
  handleMacOSAlipayCallback: () => handleMacOSAlipayCallback,
  registerAlipayUser: () => registerAlipayUser,
  sendRegistrationCaptcha: () => sendRegistrationCaptcha
});
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
      return jsonResponse2({ error: "\u652F\u4ED8\u5B9D\u5E94\u7528ID\u672A\u914D\u7F6E" }, 500);
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
    const response = jsonResponse2({
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
    return jsonResponse2({ error: "\u751F\u6210\u652F\u4ED8\u5B9D\u767B\u5F55URL\u5931\u8D25: " + error.message }, 500);
  }
}
async function getAlipayUserInfo(authCode, env) {
  const appId = env.ALIPAY_APP_ID;
  const privateKey = env.ALIPAY_PRIVATE_KEY;
  const alipayPublicKey = env.ALIPAY_PUBLIC_KEY;
  console.log("\u83B7\u53D6\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F\u5F00\u59CB:", {
    authCode: authCode ? authCode.substring(0, 10) + "..." : "null",
    hasAppId: !!appId,
    hasPrivateKey: !!privateKey,
    hasAlipayPublicKey: !!alipayPublicKey,
    appIdLength: appId ? appId.length : 0
  });
  try {
    if (!authCode || authCode.length < 10) {
      console.error("\u6388\u6743\u7801\u65E0\u6548: \u6388\u6743\u7801\u4E3A\u7A7A\u6216\u592A\u77ED");
      return {
        error: true,
        code: "CODE_INVALID",
        message: "\u652F\u4ED8\u5B9D\u6388\u6743\u5931\u8D25: \u6388\u6743\u7801\u65E0\u6548\u6216\u683C\u5F0F\u9519\u8BEF",
        details: { authCode: authCode ? "invalid_format" : "missing" }
      };
    }
    if (!appId || !privateKey || !alipayPublicKey) {
      console.warn("\u652F\u4ED8\u5B9D\u914D\u7F6E\u4E0D\u5B8C\u6574\uFF0C\u4F7F\u7528\u6A21\u62DF\u6570\u636E");
      console.warn("\u7F3A\u5C11\u7684\u914D\u7F6E:", {
        appId: !appId,
        privateKey: !privateKey,
        alipayPublicKey: !alipayPublicKey
      });
      const mockUserInfo = {
        user_id: "mock_alipay_user_" + Date.now(),
        nick_name: "\u652F\u4ED8\u5B9D\u7528\u6237",
        avatar: "https://tfsimg.alipay.com/images/partner/T1kFldXk0rXXXXXXXX",
        province: "\u6D59\u6C5F\u7701",
        city: "\u676D\u5DDE\u5E02",
        gender: "M",
        isMock: true
        // 标记为模拟数据
      };
      return mockUserInfo;
    }
    console.log("\u5F00\u59CB\u8C03\u7528\u652F\u4ED8\u5B9DAPI\u83B7\u53D6access_token...");
    if (env.USERS_KV) {
      const usedAuthCode = await env.USERS_KV.get(`used_auth_code:${authCode}`);
      if (usedAuthCode) {
        console.error("\u6388\u6743\u7801\u5DF2\u88AB\u4F7F\u7528:", authCode);
        return {
          error: true,
          code: "CODE_REUSED",
          message: "\u652F\u4ED8\u5B9D\u6388\u6743\u5931\u8D25: \u6388\u6743\u7801\u5DF2\u88AB\u4F7F\u7528\uFF0C\u8BF7\u91CD\u65B0\u767B\u5F55",
          details: { reason: "auth_code_already_used" }
        };
      }
    }
    const tokenResult = await getAccessToken(authCode, env);
    if (!tokenResult || tokenResult.code !== "10000") {
      console.error("\u83B7\u53D6access_token\u5931\u8D25:", tokenResult);
      const errorMsg = tokenResult?.msg || tokenResult?.sub_msg || "\u672A\u77E5\u9519\u8BEF";
      if (tokenResult?.sub_code === "isv.code-invalid" || tokenResult?.sub_msg?.includes("\u6388\u6743\u7801code\u65E0\u6548")) {
        return {
          error: true,
          code: "CODE_INVALID",
          message: "\u652F\u4ED8\u5B9D\u6388\u6743\u5931\u8D25: \u6388\u6743\u7801\u5DF2\u8FC7\u671F\u6216\u65E0\u6548\uFF0C\u8BF7\u91CD\u65B0\u5C1D\u8BD5",
          details: tokenResult
        };
      }
      return {
        error: true,
        code: tokenResult?.code || "UNKNOWN_ERROR",
        message: "\u652F\u4ED8\u5B9D\u6388\u6743\u5931\u8D25: " + errorMsg,
        details: tokenResult
      };
    }
    if (env.USERS_KV) {
      await env.USERS_KV.put(`used_auth_code:${authCode}`, "1", { expirationTtl: 3600 });
      console.log("\u6388\u6743\u7801\u5DF2\u6807\u8BB0\u4E3A\u5DF2\u4F7F\u7528:", authCode);
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
        gender: userInfoResult?.gender || "M",
        partial: true,
        // 标记这是部分信息
        error: userInfoResult?.code !== "10000" ? {
          code: userInfoResult?.code,
          message: userInfoResult?.msg || userInfoResult?.sub_msg,
          details: userInfoResult
        } : null
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
async function handleAlipayLogin(request, env) {
  try {
    const { auth_code, state } = await request.json();
    if (!auth_code) {
      return jsonResponse2({ error: "\u7F3A\u5C11\u6388\u6743\u7801" }, 400);
    }
    if (state) {
      const storedState = await env.USERS_KV.get(`alipay_state:${state}`);
      if (!storedState) {
        return jsonResponse2({ error: "\u65E0\u6548\u7684state\u53C2\u6570" }, 400);
      }
      await env.USERS_KV.delete(`alipay_state:${state}`);
    }
    const alipayUser = await getAlipayUserInfo(auth_code, env);
    if (alipayUser.error) {
      if (alipayUser.code === "CODE_INVALID" || alipayUser.sub_code === "isv.code-invalid" || typeof alipayUser.error === "string" && alipayUser.error.includes("\u6388\u6743\u7801\u5DF2\u8FC7\u671F\u6216\u65E0\u6548") || typeof alipayUser.error === "object" && alipayUser.error.message && typeof alipayUser.error.message === "string" && alipayUser.error.message.includes("\u6388\u6743\u7801\u5DF2\u8FC7\u671F\u6216\u65E0\u6548")) {
        return jsonResponse2({
          error: "\u652F\u4ED8\u5B9D\u6388\u6743\u5931\u8D25: \u6388\u6743\u7801\u5DF2\u8FC7\u671F\u6216\u65E0\u6548\uFF0C\u8BF7\u91CD\u65B0\u5C1D\u8BD5",
          code: "CODE_INVALID",
          sub_code: alipayUser.sub_code,
          sub_msg: alipayUser.sub_msg
        }, 400);
      }
      const errorMessage = typeof alipayUser.error === "string" ? alipayUser.error : typeof alipayUser.error === "object" && alipayUser.error.message ? alipayUser.error.message : "\u652F\u4ED8\u5B9D\u767B\u5F55\u5931\u8D25";
      return jsonResponse2({ error: errorMessage }, 500);
    }
    const existingUser = await env.USERS_KV.get(`alipay_binding:${alipayUser.user_id}`);
    if (existingUser) {
      const userData = await env.USERS_KV.get(`user:${existingUser}`);
      if (userData) {
        const user = JSON.parse(userData);
        const token = await generateToken(user.username, env);
        return jsonResponse2({
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
    return jsonResponse2({
      alipayUser,
      isNewUser: true,
      needsRegistration: true
    });
  } catch (error) {
    console.error("\u652F\u4ED8\u5B9D\u767B\u5F55\u5931\u8D25:", error);
    return jsonResponse2({ error: "\u652F\u4ED8\u5B9D\u767B\u5F55\u5931\u8D25: " + error.message }, 500);
  }
}
async function registerAlipayUser(request, env) {
  try {
    const { username, email, password, captcha, alipayUserId, alipayOpenId, alipayNickname, alipayAvatar, oneClick } = await request.json();
    if (oneClick === true) {
      const existingAlipay2 = await env.USERS_KV.get(`alipay_binding:${alipayUserId}`);
      if (existingAlipay2) {
        return jsonResponse2({ error: "\u8BE5\u652F\u4ED8\u5B9D\u8D26\u53F7\u5DF2\u6CE8\u518C\u5176\u4ED6\u7528\u6237" }, 400);
      }
      const baseUsername = alipayNickname || "\u652F\u4ED8\u5B9D\u7528\u6237";
      let autoUsername = baseUsername;
      let counter = 1;
      while (await env.USERS_KV.get(`user:${autoUsername}`)) {
        autoUsername = `${baseUsername}_${counter}`;
        counter++;
      }
      const autoEmail = `${alipayUserId}@alipay.user`;
      const creds2 = await createPasswordHash("alipay_default_password");
      const userData2 = {
        username: autoUsername,
        email: autoEmail,
        password: creds2.passwordHash,
        alipayUserId,
        alipayOpenId,
        alipayNickname,
        alipayAvatar,
        alipayBoundAt: (/* @__PURE__ */ new Date()).toISOString(),
        createdAt: (/* @__PURE__ */ new Date()).toISOString(),
        updatedAt: (/* @__PURE__ */ new Date()).toISOString(),
        emailVerified: true,
        // 支付宝用户默认已验证
        membershipType: "trial",
        // 默认试用会员
        membershipExpiresAt: calculateTrialEndDate().toISOString()
      };
      await env.USERS_KV.put(`user:${autoUsername}`, JSON.stringify(userData2));
      await env.USERS_KV.put(`email_to_username:${autoEmail}`, autoUsername);
      await env.USERS_KV.put(`alipay_binding:${alipayUserId}`, autoUsername);
      await env.USERS_KV.put(`user_alipay:${autoUsername}`, alipayUserId);
      const token2 = await generateToken(autoUsername, env);
      return jsonResponse2({
        success: true,
        message: "\u4E00\u952E\u6CE8\u518C\u6210\u529F",
        token: token2,
        username: userData2.username,
        email: userData2.email,
        isOneClick: true
      });
    }
    const normalizedEmail = email.toLowerCase().trim();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(normalizedEmail)) {
      return jsonResponse2({ error: "\u90AE\u7BB1\u683C\u5F0F\u4E0D\u6B63\u786E" }, 400);
    }
    if (password.length < 6) {
      return jsonResponse2({ error: "\u5BC6\u7801\u957F\u5EA6\u81F3\u5C116\u4F4D" }, 400);
    }
    if (!username || username.trim().length < 2) {
      return jsonResponse2({ error: "\u7528\u6237\u540D\u81F3\u5C112\u4E2A\u5B57\u7B26" }, 400);
    }
    if (!captcha || captcha.length < 4) {
      return jsonResponse2({ error: "\u8BF7\u8F93\u5165\u6709\u6548\u7684\u9A8C\u8BC1\u7801" }, 400);
    }
    const existingUser = await env.USERS_KV.get(`email_to_username:${normalizedEmail}`);
    if (existingUser) {
      return jsonResponse2({ error: "\u8BE5\u90AE\u7BB1\u5DF2\u88AB\u6CE8\u518C" }, 400);
    }
    const existingAlipay = await env.USERS_KV.get(`alipay_binding:${alipayUserId}`);
    if (existingAlipay) {
      return jsonResponse2({ error: "\u8BE5\u652F\u4ED8\u5B9D\u8D26\u53F7\u5DF2\u6CE8\u518C\u5176\u4ED6\u7528\u6237" }, 400);
    }
    const creds = await createPasswordHash(password);
    const userData = {
      username: username.trim(),
      email: normalizedEmail,
      password: creds.passwordHash,
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
    return jsonResponse2({
      success: true,
      message: "\u6CE8\u518C\u6210\u529F",
      token,
      username: userData.username,
      email: userData.email
    });
  } catch (error) {
    console.error("\u652F\u4ED8\u5B9D\u7528\u6237\u6CE8\u518C\u5931\u8D25:", error);
    return jsonResponse2({ error: "\u6CE8\u518C\u5931\u8D25: " + error.message }, 500);
  }
}
async function sendRegistrationCaptcha(request, env) {
  try {
    const { alipayUserId, username, password, nickname, avatar, email } = await request.json();
    if (!alipayUserId || !username || !password) {
      return jsonResponse2({ error: "\u7F3A\u5C11\u5FC5\u8981\u53C2\u6570" }, 400);
    }
    const existingUser = await env.USERS_KV.get(`user:${username}`);
    if (existingUser) {
      return jsonResponse2({ error: "\u7528\u6237\u540D\u5DF2\u5B58\u5728" }, 400);
    }
    if (email) {
      const emailMapped = await env.USERS_KV.get(`email_to_username:${String(email).trim().toLowerCase()}`);
      if (emailMapped) {
        return jsonResponse2({ error: "\u8BE5\u90AE\u7BB1\u5DF2\u88AB\u6CE8\u518C" }, 400);
      }
    }
    const existingBinding = await env.USERS_KV.get(`alipay_binding:${alipayUserId}`);
    if (existingBinding) {
      return jsonResponse2({ error: "\u8BE5\u652F\u4ED8\u5B9D\u8D26\u53F7\u5DF2\u6CE8\u518C\u5176\u4ED6\u7528\u6237" }, 400);
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
    return jsonResponse2({
      token,
      username,
      message: "\u6CE8\u518C\u6210\u529F\uFF0C\u652F\u4ED8\u5B9D\u8D26\u53F7\u5DF2\u6CE8\u518C"
    }, 201);
  } catch (error) {
    console.error("\u652F\u4ED8\u5B9D\u6CE8\u518C\u5931\u8D25:", error);
    return jsonResponse2({ error: "\u652F\u4ED8\u5B9D\u6CE8\u518C\u5931\u8D25: " + error.message }, 500);
  }
}
async function checkEmailAvailability(request, env) {
  try {
    const { email } = await request.json();
    const normalizedEmail = email.toLowerCase().trim();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(normalizedEmail)) {
      return jsonResponse2({ error: "\u90AE\u7BB1\u683C\u5F0F\u4E0D\u6B63\u786E" }, 400);
    }
    const existingUser = await env.USERS_KV.get(`user:${normalizedEmail}`);
    return jsonResponse2({
      success: true,
      available: !existingUser,
      message: existingUser ? "\u8BE5\u90AE\u7BB1\u5DF2\u88AB\u6CE8\u518C" : "\u90AE\u7BB1\u53EF\u7528"
    });
  } catch (error) {
    console.error("\u90AE\u7BB1\u68C0\u67E5\u5931\u8D25:", error);
    return jsonResponse2({ error: "\u90AE\u7BB1\u68C0\u67E5\u5931\u8D25: " + error.message }, 500);
  }
}
async function handleMacOSAlipayCallback(request, env) {
  try {
    const url = new URL(request.url);
    const authCode = url.searchParams.get("auth_code");
    const state = url.searchParams.get("state");
    console.log("\u6536\u5230macOS\u5E94\u7528\u652F\u4ED8\u5B9D\u767B\u5F55\u56DE\u8C03:", {
      authCode: authCode ? authCode.substring(0, 10) + "..." : "null",
      state: state || "null",
      fullUrl: request.url
    });
    if (!authCode) {
      const redirectUrl2 = `globaldharma://error=missing_auth_code&error_message=${encodeURIComponent("\u7F3A\u5C11\u6388\u6743\u7801")}`;
      console.error("macOS\u652F\u4ED8\u5B9D\u56DE\u8C03\u7F3A\u5C11\u6388\u6743\u7801\uFF0C\u91CD\u5B9A\u5411\u5230\u5E94\u7528:", redirectUrl2);
      return Response.redirect(redirectUrl2, 302);
    }
    if (authCode.length < 10) {
      console.error("macOS\u652F\u4ED8\u5B9D\u56DE\u8C03\u6388\u6743\u7801\u683C\u5F0F\u65E0\u6548:", authCode);
      const redirectUrl2 = `globaldharma://error=invalid_auth_code&error_message=${encodeURIComponent("\u6388\u6743\u7801\u683C\u5F0F\u65E0\u6548")}`;
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
    const alipayUserResult = await getAlipayUserInfo(authCode, env);
    if (alipayUserResult.error) {
      console.error("\u83B7\u53D6\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F\u5931\u8D25:", alipayUserResult);
      if (alipayUserResult.code === "CODE_INVALID" || alipayUserResult.code === "CODE_REUSED") {
        const errorMessage = alipayUserResult.message || "\u652F\u4ED8\u5B9D\u6388\u6743\u5931\u8D25";
        const redirectUrl2 = `globaldharma://error=auth_failed&error_message=${encodeURIComponent(errorMessage)}&error_code=${alipayUserResult.code}`;
        console.log("macOS\u652F\u4ED8\u5B9D\u6388\u6743\u5931\u8D25\uFF0C\u91CD\u5B9A\u5411\u5230\u5E94\u7528:", redirectUrl2);
        return Response.redirect(redirectUrl2, 302);
      }
      return jsonResponse2({
        error: "\u652F\u4ED8\u5B9D\u767B\u5F55\u5931\u8D25",
        details: alipayUserResult.message,
        code: alipayUserResult.code,
        fullError: alipayUserResult.details
      }, 500);
    }
    const alipayUser = alipayUserResult;
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
async function handleAlipayCallback(request, env) {
  try {
    const url = new URL(request.url);
    const authCode = url.searchParams.get("auth_code");
    const state = url.searchParams.get("state");
    console.log("\u6536\u5230\u652F\u4ED8\u5B9D\u767B\u5F55\u56DE\u8C03:", {
      authCode: authCode ? authCode.substring(0, 10) + "..." : "null",
      state: state || "null",
      fullUrl: request.url
    });
    if (!authCode) {
      const redirectUrl2 = new URL("/index.html", request.url);
      redirectUrl2.hash = "error=missing_auth_code&error_message=\u7F3A\u5C11\u6388\u6743\u7801";
      return Response.redirect(redirectUrl2.toString(), 302);
    }
    if (authCode.length < 10) {
      console.error("\u652F\u4ED8\u5B9D\u56DE\u8C03\u6388\u6743\u7801\u683C\u5F0F\u65E0\u6548:", authCode);
      const redirectUrl2 = new URL("/index.html", request.url);
      redirectUrl2.hash = "error=invalid_auth_code&error_message=\u6388\u6743\u7801\u683C\u5F0F\u65E0\u6548";
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
async function getAccessToken(authCode, env) {
  try {
    const appId = env.ALIPAY_APP_ID;
    const privateKey = env.ALIPAY_PRIVATE_KEY;
    console.log("\u5F00\u59CB\u83B7\u53D6access_token\uFF0C\u6388\u6743\u7801:", authCode ? authCode.substring(0, 10) + "..." : "null");
    if (!authCode || authCode.length < 10) {
      console.error("\u6388\u6743\u7801\u683C\u5F0F\u65E0\u6548:", { authCode: authCode ? "invalid_length" : "missing" });
      return {
        code: "CODE_INVALID",
        msg: "\u6388\u6743\u7801\u65E0\u6548",
        sub_code: "isv.code-invalid",
        sub_msg: "\u6388\u6743\u7801\u683C\u5F0F\u9519\u8BEF\u6216\u5DF2\u8FC7\u671F"
      };
    }
    if (!appId || !privateKey) {
      console.error("\u652F\u4ED8\u5B9D\u914D\u7F6E\u7F3A\u5931:", {
        hasAppId: !!appId,
        hasPrivateKey: !!privateKey
      });
      return {
        code: "CONFIG_ERROR",
        msg: "\u652F\u4ED8\u5B9D\u914D\u7F6E\u4E0D\u5B8C\u6574",
        sub_code: "missing_config",
        sub_msg: "\u7F3A\u5C11\u5FC5\u8981\u7684\u652F\u4ED8\u5B9DAPI\u914D\u7F6E"
      };
    }
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
    } else if (result.error_response) {
      const errorResponse = result.error_response;
      console.error("\u652F\u4ED8\u5B9DAPI\u9519\u8BEF\u54CD\u5E94:", errorResponse);
      return {
        code: errorResponse.code || "API_ERROR",
        msg: errorResponse.msg || "\u652F\u4ED8\u5B9DAPI\u8FD4\u56DE\u9519\u8BEF",
        sub_code: errorResponse.sub_code || "unknown",
        sub_msg: errorResponse.sub_msg || JSON.stringify(errorResponse)
      };
    } else {
      console.error("\u652F\u4ED8\u5B9DAPI\u54CD\u5E94\u683C\u5F0F\u4E0D\u6B63\u786E\uFF0C\u5B8C\u6574\u54CD\u5E94:", JSON.stringify(result));
      return {
        code: "INVALID_RESPONSE",
        msg: "\u652F\u4ED8\u5B9DAPI\u54CD\u5E94\u683C\u5F0F\u4E0D\u6B63\u786E",
        sub_code: "invalid_format",
        sub_msg: `\u54CD\u5E94\u7F3A\u5C11alipay_system_oauth_token_response\u5B57\u6BB5\uFF0C\u5B8C\u6574\u54CD\u5E94: ${JSON.stringify(result)}`
      };
    }
  } catch (error) {
    console.error("\u83B7\u53D6access_token\u5931\u8D25:", error);
    throw error;
  }
}
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
    } else if (result.error_response) {
      const errorResponse = result.error_response;
      console.error("\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606FAPI\u9519\u8BEF\u54CD\u5E94:", errorResponse);
      return {
        code: errorResponse.code || "API_ERROR",
        msg: errorResponse.msg || "\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606FAPI\u8FD4\u56DE\u9519\u8BEF",
        sub_code: errorResponse.sub_code || "unknown",
        sub_msg: errorResponse.sub_msg || JSON.stringify(errorResponse)
      };
    } else {
      console.error("\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606FAPI\u54CD\u5E94\u683C\u5F0F\u4E0D\u6B63\u786E\uFF0C\u5B8C\u6574\u54CD\u5E94:", JSON.stringify(result));
      return {
        code: "INVALID_RESPONSE",
        msg: "\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606FAPI\u54CD\u5E94\u683C\u5F0F\u4E0D\u6B63\u786E",
        sub_code: "invalid_format",
        sub_msg: `\u54CD\u5E94\u7F3A\u5C11alipay_user_info_share_response\u5B57\u6BB5\uFF0C\u5B8C\u6574\u54CD\u5E94: ${JSON.stringify(result)}`
      };
    }
  } catch (error) {
    console.error("\u83B7\u53D6\u7528\u6237\u4FE1\u606F\u5931\u8D25:", error);
    throw error;
  }
}
var init_alipay_login_functions = __esm({
  "alipay-login-functions.js"() {
    init_auth_utils();
    init_alipay_utils();
    init_stripe_config();
    __name(generateAlipayLoginUrl, "generateAlipayLoginUrl");
    __name(getAlipayUserInfo, "getAlipayUserInfo");
    __name(handleAlipayLogin, "handleAlipayLogin");
    __name(registerAlipayUser, "registerAlipayUser");
    __name(sendRegistrationCaptcha, "sendRegistrationCaptcha");
    __name(checkEmailAvailability, "checkEmailAvailability");
    __name(handleMacOSAlipayCallback, "handleMacOSAlipayCallback");
    __name(handleAlipayCallback, "handleAlipayCallback");
    __name(getAccessToken, "getAccessToken");
    __name(getUserInfoWithToken, "getUserInfoWithToken");
  }
});

// src/services/database.js
var DatabaseService = class {
  static {
    __name(this, "DatabaseService");
  }
  constructor(db) {
    this.db = db;
  }
  // 用户操作
  async getUser(username) {
    return await this.db.prepare("SELECT * FROM users WHERE username = ?").bind(username).first();
  }
  async getUserByEmail(email) {
    const mapping = await this.db.prepare("SELECT username FROM email_username_mapping WHERE email = ?").bind(email).first();
    if (!mapping) return null;
    return await this.getUser(mapping.username);
  }
  async createUser(userData) {
    await this.db.prepare(`
      INSERT INTO users (username, email, password_hash, salt, iterations, algo, email_verified, membership_type, free_trial_end_date, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).bind(
      userData.username,
      userData.email,
      userData.passwordHash,
      userData.salt,
      userData.iterations,
      userData.algo,
      userData.emailVerified ? 1 : 0,
      userData.membershipType,
      userData.freeTrialEndDate,
      userData.createdAt
    ).run();
    await this.db.prepare("INSERT INTO email_username_mapping (email, username) VALUES (?, ?)").bind(userData.email, userData.username).run();
  }
  async updateUser(username, updates) {
    const fields = Object.keys(updates).map((k) => `${k} = ?`).join(", ");
    const values = Object.values(updates);
    await this.db.prepare(`UPDATE users SET ${fields}, updated_at = ? WHERE username = ?`).bind(...values, (/* @__PURE__ */ new Date()).toISOString(), username).run();
  }
  // 订单操作
  async createOrder(orderData) {
    await this.db.prepare(`
      INSERT INTO orders (order_id, user_id, plan, amount, original_amount, is_admin_order, status, platform, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).bind(
      orderData.orderId,
      orderData.userId,
      orderData.plan,
      orderData.amount,
      orderData.originalAmount,
      orderData.isAdminOrder ? 1 : 0,
      orderData.status,
      orderData.platform,
      orderData.createdAt
    ).run();
  }
  async getOrder(orderId) {
    return await this.db.prepare("SELECT * FROM orders WHERE order_id = ?").bind(orderId).first();
  }
  async updateOrder(orderId, updates) {
    const fields = Object.keys(updates).map((k) => `${k} = ?`).join(", ");
    const values = Object.values(updates);
    await this.db.prepare(`UPDATE orders SET ${fields} WHERE order_id = ?`).bind(...values, orderId).run();
  }
  // 兑换码操作
  async createRedeemCode(codeData) {
    await this.db.prepare(`
      INSERT INTO redeem_codes (code, type, days, name, description, created_by, created_at, used)
      VALUES (?, ?, ?, ?, ?, ?, ?, 0)
    `).bind(
      codeData.code,
      codeData.type,
      codeData.days,
      codeData.name,
      codeData.description,
      codeData.createdBy,
      codeData.createdAt
    ).run();
  }
  async getRedeemCode(code) {
    return await this.db.prepare("SELECT * FROM redeem_codes WHERE code = ? AND used = 0").bind(code).first();
  }
  async useRedeemCode(code, username) {
    await this.db.prepare("UPDATE redeem_codes SET used = 1, used_by = ?, used_at = ? WHERE code = ?").bind(username, (/* @__PURE__ */ new Date()).toISOString(), code).run();
  }
  // 购买记录
  async addPurchaseHistory(data) {
    await this.db.prepare(`
      INSERT INTO purchase_history (username, order_id, plan, amount, currency, status, payment_method, purchased_at, valid_from, valid_to)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).bind(
      data.username,
      data.orderId,
      data.plan,
      data.amount,
      data.currency,
      data.status,
      data.paymentMethod,
      data.purchasedAt,
      data.validFrom,
      data.validTo
    ).run();
  }
  async getPurchaseHistory(username) {
    const result = await this.db.prepare("SELECT * FROM purchase_history WHERE username = ? ORDER BY purchased_at DESC").bind(username).all();
    return result.results;
  }
  // 兑换记录
  async addRedeemHistory(data) {
    await this.db.prepare(`
      INSERT INTO redeem_history (username, code, type, days, redeemed_at, valid_from, valid_to)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).bind(
      data.username,
      data.code,
      data.type,
      data.days,
      data.redeemedAt,
      data.validFrom,
      data.validTo
    ).run();
  }
  async getRedeemHistory(username) {
    const result = await this.db.prepare("SELECT * FROM redeem_history WHERE username = ? ORDER BY redeemed_at DESC").bind(username).all();
    return result.results;
  }
  // 兑换码列表
  async listRedeemCodes(status, page, limit) {
    let query = "SELECT * FROM redeem_codes";
    const params = [];
    if (status === "used") {
      query += " WHERE used = 1";
    } else if (status === "unused") {
      query += " WHERE used = 0";
    }
    query += " ORDER BY created_at DESC LIMIT ? OFFSET ?";
    params.push(limit, (page - 1) * limit);
    const result = await this.db.prepare(query).bind(...params).all();
    const countResult = await this.db.prepare("SELECT COUNT(*) as total FROM redeem_codes").first();
    return {
      codes: result.results,
      total: countResult.total,
      page,
      limit,
      totalPages: Math.ceil(countResult.total / limit)
    };
  }
  async deleteRedeemCode(code) {
    await this.db.prepare("DELETE FROM redeem_codes WHERE code = ?").bind(code).run();
  }
  // 排行榜
  async getLeaderboard(limit) {
    try {
      const result = await this.db.prepare(`
        SELECT username, COALESCE(total_transferred_bytes, 0) as totalBytes
        FROM users 
        WHERE COALESCE(total_transferred_bytes, 0) > 0
        ORDER BY total_transferred_bytes DESC
        LIMIT ?
      `).bind(limit).all();
      if (!result || !result.results) {
        return [];
      }
      return result.results.map((entry, index) => ({
        username: entry.username || "Unknown",
        totalBytes: entry.totalBytes || 0,
        rank: index + 1
      }));
    } catch (error) {
      console.error("\u83B7\u53D6\u6392\u884C\u699C\u5931\u8D25:", error);
      return [];
    }
  }
  async updateTransferData(username, bytes) {
    await this.db.prepare(`
      UPDATE users 
      SET total_transferred_bytes = total_transferred_bytes + ?,
          last_transfer_at = ?
      WHERE username = ?
    `).bind(bytes, (/* @__PURE__ */ new Date()).toISOString(), username).run();
  }
};

// src/utils/response.js
init_constants();
function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: CORS_HEADERS
  });
}
__name(jsonResponse, "jsonResponse");

// src/handlers/auth.js
init_auth_utils();
init_stripe_config();
async function handleRegister(request, env, db) {
  const { username, email, password, verificationCode } = await request.json();
  if (!username || !email || !password || !verificationCode) {
    return jsonResponse({ error: "\u7F3A\u5C11\u5FC5\u8981\u5B57\u6BB5" }, 400);
  }
  const verifyData = await env.USERS_KV.get(`verify:${email.toLowerCase()}`);
  if (!verifyData) {
    return jsonResponse({ error: "\u9A8C\u8BC1\u7801\u4E0D\u5B58\u5728\u6216\u5DF2\u8FC7\u671F" }, 400);
  }
  const { code, expiry } = JSON.parse(verifyData);
  if (Date.now() > expiry || verificationCode !== code) {
    return jsonResponse({ error: "\u9A8C\u8BC1\u7801\u9519\u8BEF\u6216\u5DF2\u8FC7\u671F" }, 400);
  }
  const existingUser = await db.getUser(username);
  if (existingUser) {
    return jsonResponse({ error: "\u7528\u6237\u540D\u5DF2\u5B58\u5728" }, 400);
  }
  const existingEmail = await db.getUserByEmail(email.toLowerCase());
  if (existingEmail) {
    return jsonResponse({ error: "\u8BE5\u90AE\u7BB1\u5DF2\u88AB\u6CE8\u518C" }, 400);
  }
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
    membershipType: "trial",
    freeTrialEndDate: trialEndDate.toISOString(),
    createdAt: (/* @__PURE__ */ new Date()).toISOString()
  });
  await env.USERS_KV.delete(`verify:${email.toLowerCase()}`);
  return jsonResponse({ message: "\u6CE8\u518C\u6210\u529F" }, 201);
}
__name(handleRegister, "handleRegister");
async function handleLogin(request, env, db) {
  const { username: loginIdentifier, password } = await request.json();
  if (!loginIdentifier || !password) {
    return jsonResponse({ error: "\u7528\u6237\u540D\u6216\u90AE\u7BB1\u548C\u5BC6\u7801\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
  }
  let user;
  if (loginIdentifier.includes("@")) {
    user = await db.getUserByEmail(loginIdentifier.toLowerCase());
  } else {
    user = await db.getUser(loginIdentifier);
  }
  if (!user) {
    return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 401);
  }
  const ok = await verifyPassword(password, {
    passwordHash: user.password_hash,
    salt: user.salt,
    iterations: user.iterations,
    algo: user.algo
  });
  if (!ok) {
    return jsonResponse({ error: "\u5BC6\u7801\u9519\u8BEF" }, 401);
  }
  const token = await generateToken(user.username, env);
  return jsonResponse({ token, username: user.username });
}
__name(handleLogin, "handleLogin");
async function handleGetUserInfo(request, env, db) {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
  }
  const token = authHeader.substring(7);
  const tokenData = await verifyToken(token, env);
  if (!tokenData) {
    return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
  }
  const user = await db.getUser(tokenData.username);
  if (!user) {
    return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 404);
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
__name(handleGetUserInfo, "handleGetUserInfo");

// src/handlers/verification.js
async function handleSendVerificationCode(request, env, ctx) {
  const { email, type = "register" } = await request.json();
  if (!email) return jsonResponse({ error: "\u90AE\u7BB1\u5730\u5740\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
  const normalizedEmail = email.toLowerCase();
  const rateKey = `rate:verify:${normalizedEmail}`;
  if (await env.USERS_KV.get(rateKey)) {
    return jsonResponse({ error: "\u8BF7\u6C42\u8FC7\u4E8E\u9891\u7E41\uFF0C\u8BF7\u7A0D\u540E\u518D\u8BD5" }, 429);
  }
  const code = Math.floor(1e5 + Math.random() * 9e5).toString();
  const expiry = Date.now() + 10 * 60 * 1e3;
  await env.USERS_KV.put(`verify:${normalizedEmail}`, JSON.stringify({ code, expiry, type }));
  await env.USERS_KV.put(rateKey, "1", { expirationTtl: 60 });
  const subject = type === "register" ? "\u6CE8\u518C\u9A8C\u8BC1\u7801" : "\u5BC6\u7801\u91CD\u7F6E\u9A8C\u8BC1\u7801";
  const body = `\u60A8\u7684\u9A8C\u8BC1\u7801\u662F\uFF1A${code}
\u6709\u6548\u671F10\u5206\u949F\uFF0C\u8BF7\u5C3D\u5FEB\u4F7F\u7528\u3002`;
  ctx.waitUntil(sendEmail(normalizedEmail, subject, body, env));
  return jsonResponse({ message: "\u9A8C\u8BC1\u7801\u5DF2\u53D1\u9001\uFF0C\u8BF7\u67E5\u6536\u90AE\u4EF6\u3002" });
}
__name(handleSendVerificationCode, "handleSendVerificationCode");
async function handleForgotPassword(request, env, db) {
  const { email } = await request.json();
  if (!email) return jsonResponse({ error: "\u90AE\u7BB1\u5730\u5740\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
  const user = await db.getUserByEmail(email.toLowerCase());
  if (!user) return jsonResponse({ error: "\u8BE5\u90AE\u7BB1\u672A\u6CE8\u518C" }, 400);
  const resetToken = crypto.randomUUID();
  await env.USERS_KV.put(`reset:${email.toLowerCase()}`, resetToken, { expirationTtl: 30 * 60 });
  const resetUrl = `${new URL(request.url).origin}/reset-password.html?token=${resetToken}&email=${email}`;
  await sendEmail(email, "\u5BC6\u7801\u91CD\u7F6E\u8BF7\u6C42", `\u70B9\u51FB\u4EE5\u4E0B\u94FE\u63A5\u91CD\u7F6E\u60A8\u7684\u5BC6\u7801\uFF1A
${resetUrl}
\u94FE\u63A530\u5206\u949F\u5185\u6709\u6548\u3002`, env);
  return jsonResponse({ message: "\u91CD\u7F6E\u90AE\u4EF6\u5DF2\u53D1\u9001" });
}
__name(handleForgotPassword, "handleForgotPassword");
async function handleResetPassword(request, env, db) {
  const { email, token, newPassword } = await request.json();
  if (!email || !token || !newPassword) return jsonResponse({ error: "\u7F3A\u5C11\u5FC5\u8981\u5B57\u6BB5" }, 400);
  const storedToken = await env.USERS_KV.get(`reset:${email.toLowerCase()}`);
  if (!storedToken || storedToken !== token) {
    return jsonResponse({ error: "\u91CD\u7F6E\u94FE\u63A5\u65E0\u6548\u6216\u5DF2\u8FC7\u671F" }, 400);
  }
  const user = await db.getUserByEmail(email.toLowerCase());
  if (!user) return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 400);
  const { createPasswordHash: createPasswordHash2 } = await Promise.resolve().then(() => (init_auth_utils(), auth_utils_exports));
  const creds = await createPasswordHash2(newPassword);
  await db.updateUser(user.username, {
    password_hash: creds.passwordHash,
    salt: creds.salt,
    iterations: creds.iterations,
    algo: creds.algo
  });
  await env.USERS_KV.delete(`reset:${email.toLowerCase()}`);
  return jsonResponse({ message: "\u5BC6\u7801\u91CD\u7F6E\u6210\u529F" });
}
__name(handleResetPassword, "handleResetPassword");
async function sendEmail(to, subject, body, env) {
  if (env.RESEND_API_KEY) {
    await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${env.RESEND_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        from: env.FROM_EMAIL || "onboarding@resend.dev",
        to: [to],
        subject,
        text: body
      })
    });
  }
}
__name(sendEmail, "sendEmail");

// src/handlers/thirdparty.js
init_auth_utils();
async function handleGetWechatLoginUrl(request, env) {
  const state = crypto.randomUUID();
  const appId = env.WECHAT_APP_ID;
  const redirectUri = encodeURIComponent(env.WECHAT_REDIRECT_URI);
  const authUrl = `https://open.weixin.qq.com/connect/oauth2/authorize?appid=${appId}&redirect_uri=${redirectUri}&response_type=code&scope=snsapi_userinfo&state=${state}#wechat_redirect`;
  await env.USERS_KV.put(`wechat_state:${state}`, "valid", { expirationTtl: 600 });
  return jsonResponse({ authUrl, state });
}
__name(handleGetWechatLoginUrl, "handleGetWechatLoginUrl");
async function handleGetAlipayLoginUrl(request, env) {
  const { generateAlipayLoginUrl: generateAlipayLoginUrl2 } = await Promise.resolve().then(() => (init_alipay_login_functions(), alipay_login_functions_exports));
  const platform = new URL(request.url).searchParams.get("platform");
  return await generateAlipayLoginUrl2(env, platform);
}
__name(handleGetAlipayLoginUrl, "handleGetAlipayLoginUrl");
async function handleAlipayLogin2(request, env) {
  const { handleAlipayLogin: handleAlipayLogin3 } = await Promise.resolve().then(() => (init_alipay_login_functions(), alipay_login_functions_exports));
  return await handleAlipayLogin3(request, env);
}
__name(handleAlipayLogin2, "handleAlipayLogin");
async function handleMacOSAlipayCallback2(request, env) {
  const { handleMacOSAlipayCallback: handleMacOSAlipayCallback3 } = await Promise.resolve().then(() => (init_alipay_login_functions(), alipay_login_functions_exports));
  return await handleMacOSAlipayCallback3(request, env);
}
__name(handleMacOSAlipayCallback2, "handleMacOSAlipayCallback");
async function handleAlipayRegister(request, env) {
  const { registerAlipayUser: registerAlipayUser2 } = await Promise.resolve().then(() => (init_alipay_login_functions(), alipay_login_functions_exports));
  return await registerAlipayUser2(request, env);
}
__name(handleAlipayRegister, "handleAlipayRegister");
async function handleBindEmail(request, env, db) {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
  }
  const token = authHeader.substring(7);
  const tokenData = await verifyToken(token, env);
  if (!tokenData) return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
  const { email, verificationCode } = await request.json();
  if (!email || !verificationCode) {
    return jsonResponse({ error: "\u90AE\u7BB1\u4E0E\u9A8C\u8BC1\u7801\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
  }
  const normalizedEmail = email.toLowerCase();
  const verifyData = await env.USERS_KV.get(`verify:${normalizedEmail}`);
  if (!verifyData) return jsonResponse({ error: "\u9A8C\u8BC1\u7801\u4E0D\u5B58\u5728\u6216\u5DF2\u8FC7\u671F" }, 400);
  const { code, expiry } = JSON.parse(verifyData);
  if (Date.now() > expiry || verificationCode !== code) {
    return jsonResponse({ error: "\u9A8C\u8BC1\u7801\u9519\u8BEF\u6216\u5DF2\u8FC7\u671F" }, 400);
  }
  const existing = await db.getUserByEmail(normalizedEmail);
  if (existing) return jsonResponse({ error: "\u8BE5\u90AE\u7BB1\u5DF2\u88AB\u5176\u4ED6\u8D26\u53F7\u7ED1\u5B9A" }, 400);
  await db.updateUser(tokenData.username, { email: normalizedEmail, email_verified: 1 });
  await env.USERS_KV.delete(`verify:${normalizedEmail}`);
  return jsonResponse({ message: "\u90AE\u7BB1\u7ED1\u5B9A\u6210\u529F", email: normalizedEmail });
}
__name(handleBindEmail, "handleBindEmail");

// src/handlers/payment.js
init_auth_utils();
init_constants();

// src/utils/helpers.js
init_constants();
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

// src/handlers/payment.js
async function handleCreateAlipayOrder(request, env, db) {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
  }
  const token = authHeader.substring(7);
  const tokenData = await verifyToken(token, env);
  if (!tokenData) {
    return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
  }
  const { plan = "monthly" } = await request.json();
  const planDetails = MEMBERSHIP_PLANS[plan];
  if (!planDetails) {
    return jsonResponse({ error: "\u65E0\u6548\u7684\u4F1A\u5458\u8BA1\u5212" }, 400);
  }
  const user = await db.getUser(tokenData.username);
  if (!user) {
    return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 404);
  }
  const isAdminUser = isAdmin(user.email);
  const finalAmount = isAdminUser ? planDetails.adminPrice : planDetails.price;
  const outTradeNo = `MEMBER_${tokenData.username}_${Date.now()}`;
  await db.createOrder({
    orderId: outTradeNo,
    userId: tokenData.username,
    plan,
    amount: finalAmount,
    originalAmount: planDetails.price,
    isAdminOrder: isAdminUser,
    status: "PENDING",
    platform: "alipay",
    createdAt: (/* @__PURE__ */ new Date()).toISOString()
  });
  return jsonResponse({
    orderId: outTradeNo,
    amount: finalAmount,
    plan
  });
}
__name(handleCreateAlipayOrder, "handleCreateAlipayOrder");
async function handleQueryAlipayOrder(request, env, db) {
  const url = new URL(request.url);
  const orderId = url.searchParams.get("orderId");
  if (!orderId) {
    return jsonResponse({ error: "\u8BA2\u5355ID\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
  }
  const order = await db.getOrder(orderId);
  if (!order) {
    return jsonResponse({ error: "\u8BA2\u5355\u4E0D\u5B58\u5728" }, 404);
  }
  return jsonResponse({
    orderId: order.order_id,
    userId: order.user_id,
    plan: order.plan,
    amount: order.amount,
    status: order.status,
    createdAt: order.created_at
  });
}
__name(handleQueryAlipayOrder, "handleQueryAlipayOrder");
async function handleAlipayNotify(request, env, db) {
  const formData = await request.formData();
  const params = {};
  for (const [key, value] of formData.entries()) {
    params[key] = value;
  }
  if (params.trade_status === "TRADE_SUCCESS" || params.trade_status === "TRADE_FINISHED") {
    const outTradeNo = params.out_trade_no;
    const order = await db.getOrder(outTradeNo);
    if (!order) {
      return new Response("failure", { status: 404 });
    }
    if (order.status === "PAID") {
      return new Response("success", { status: 200 });
    }
    await db.updateOrder(outTradeNo, {
      status: "PAID",
      paid_at: (/* @__PURE__ */ new Date()).toISOString(),
      trade_no: params.trade_no
    });
    const user = await db.getUser(order.user_id);
    const planDetails = MEMBERSHIP_PLANS[order.plan];
    const now = /* @__PURE__ */ new Date();
    let startDate = now;
    if (user.membership_expires_at && new Date(user.membership_expires_at) > now) {
      startDate = new Date(user.membership_expires_at);
    }
    const endDate = new Date(startDate.getTime() + planDetails.duration);
    await db.updateUser(order.user_id, {
      membership_type: "paid",
      membership_expires_at: endDate.toISOString()
    });
    await db.addPurchaseHistory({
      username: order.user_id,
      orderId: outTradeNo,
      plan: order.plan,
      amount: planDetails.price,
      currency: "CNY",
      status: "completed",
      paymentMethod: "alipay",
      purchasedAt: now.toISOString(),
      validFrom: startDate.toISOString(),
      validTo: endDate.toISOString()
    });
  }
  return new Response("success", { status: 200 });
}
__name(handleAlipayNotify, "handleAlipayNotify");

// src/handlers/redeem.js
init_auth_utils();
init_constants();
async function handleCreateRedeemCode(request, env, db) {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
  }
  const token = authHeader.substring(7);
  const tokenData = await verifyToken(token, env);
  if (!tokenData) {
    return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
  }
  const user = await db.getUser(tokenData.username);
  if (!isAdmin(user.email)) {
    return jsonResponse({ error: "\u6743\u9650\u4E0D\u8DB3" }, 403);
  }
  const { type, quantity = 1, description = "" } = await request.json();
  const codeType = REDEEM_CODE_TYPES[type];
  if (!codeType) {
    return jsonResponse({ error: "\u65E0\u6548\u7684\u5151\u6362\u7801\u7C7B\u578B" }, 400);
  }
  const codes = [];
  for (let i = 0; i < quantity; i++) {
    const code = generateRedeemCode();
    await db.createRedeemCode({
      code,
      type: codeType.type,
      days: codeType.days,
      name: codeType.name,
      description,
      createdBy: tokenData.username,
      createdAt: (/* @__PURE__ */ new Date()).toISOString()
    });
    codes.push(code);
  }
  return jsonResponse({
    message: `\u6210\u529F\u751F\u6210${quantity}\u4E2A\u5151\u6362\u7801`,
    codes,
    type: codeType.name
  });
}
__name(handleCreateRedeemCode, "handleCreateRedeemCode");
async function handleUseRedeemCode(request, env, db) {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
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
  const redeemCode = await db.getRedeemCode(code.toUpperCase());
  if (!redeemCode) {
    return jsonResponse({ error: "\u5151\u6362\u7801\u4E0D\u5B58\u5728\u6216\u5DF2\u4F7F\u7528" }, 400);
  }
  const user = await db.getUser(tokenData.username);
  const now = /* @__PURE__ */ new Date();
  let newExpiryDate = new Date(now);
  if (user.membership_expires_at && new Date(user.membership_expires_at) > now) {
    newExpiryDate = new Date(user.membership_expires_at);
  }
  newExpiryDate.setDate(newExpiryDate.getDate() + redeemCode.days);
  await db.updateUser(tokenData.username, {
    membership_type: redeemCode.type,
    membership_expires_at: newExpiryDate.toISOString()
  });
  await db.useRedeemCode(code.toUpperCase(), tokenData.username);
  await db.addRedeemHistory({
    username: tokenData.username,
    code: code.toUpperCase(),
    type: redeemCode.type,
    days: redeemCode.days,
    redeemedAt: now.toISOString(),
    validFrom: now.toISOString(),
    validTo: newExpiryDate.toISOString()
  });
  return jsonResponse({
    message: `\u5151\u6362\u6210\u529F\uFF01\u83B7\u5F97${redeemCode.name}`,
    expiresAt: newExpiryDate.toISOString(),
    daysAdded: redeemCode.days
  });
}
__name(handleUseRedeemCode, "handleUseRedeemCode");
async function handleGetPurchaseHistory(request, env, db) {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
  }
  const token = authHeader.substring(7);
  const tokenData = await verifyToken(token, env);
  if (!tokenData) {
    return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
  }
  const purchases = await db.getPurchaseHistory(tokenData.username);
  return jsonResponse({
    purchases,
    total: purchases.length
  });
}
__name(handleGetPurchaseHistory, "handleGetPurchaseHistory");
async function handleGetRedeemHistory(request, env, db) {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
  }
  const token = authHeader.substring(7);
  const tokenData = await verifyToken(token, env);
  if (!tokenData) {
    return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
  }
  const redeems = await db.getRedeemHistory(tokenData.username);
  return jsonResponse({
    redeems,
    total: redeems.length
  });
}
__name(handleGetRedeemHistory, "handleGetRedeemHistory");

// src/handlers/admin.js
init_auth_utils();
async function handleCheckAdminStatus(request, env, db) {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
  }
  const token = authHeader.substring(7);
  const tokenData = await verifyToken(token, env);
  if (!tokenData) return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
  const user = await db.getUser(tokenData.username);
  if (!user) return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 404);
  return jsonResponse({
    isAdmin: isAdmin(user.email),
    email: user.email,
    username: user.username
  });
}
__name(handleCheckAdminStatus, "handleCheckAdminStatus");
async function handleListRedeemCodes(request, env, db) {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
  }
  const token = authHeader.substring(7);
  const tokenData = await verifyToken(token, env);
  if (!tokenData) return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
  const user = await db.getUser(tokenData.username);
  if (!isAdmin(user.email)) {
    return jsonResponse({ error: "\u6743\u9650\u4E0D\u8DB3" }, 403);
  }
  const url = new URL(request.url);
  const page = parseInt(url.searchParams.get("page") || "1");
  const limit = parseInt(url.searchParams.get("limit") || "20");
  const status = url.searchParams.get("status");
  const codes = await db.listRedeemCodes(status, page, limit);
  return jsonResponse(codes);
}
__name(handleListRedeemCodes, "handleListRedeemCodes");
async function handleDeleteRedeemCode(request, env, db) {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
  }
  const token = authHeader.substring(7);
  const tokenData = await verifyToken(token, env);
  if (!tokenData) return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
  const user = await db.getUser(tokenData.username);
  if (!isAdmin(user.email)) {
    return jsonResponse({ error: "\u6743\u9650\u4E0D\u8DB3" }, 403);
  }
  const { code } = await request.json();
  if (!code) return jsonResponse({ error: "\u5151\u6362\u7801\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
  await db.deleteRedeemCode(code.toUpperCase());
  return jsonResponse({ message: "\u5151\u6362\u7801\u5220\u9664\u6210\u529F" });
}
__name(handleDeleteRedeemCode, "handleDeleteRedeemCode");
async function handleGetAdminPrice(request, env, db) {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
  }
  const token = authHeader.substring(7);
  const tokenData = await verifyToken(token, env);
  if (!tokenData) return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
  const user = await db.getUser(tokenData.username);
  const { plan } = await request.json();
  const { MEMBERSHIP_PLANS: MEMBERSHIP_PLANS2 } = await Promise.resolve().then(() => (init_constants(), constants_exports));
  if (isAdmin(user.email)) {
    return jsonResponse({
      isAdmin: true,
      originalPrice: MEMBERSHIP_PLANS2[plan].price,
      adminPrice: MEMBERSHIP_PLANS2[plan].adminPrice,
      plan
    });
  }
  return jsonResponse({
    isAdmin: false,
    price: MEMBERSHIP_PLANS2[plan].price,
    plan
  });
}
__name(handleGetAdminPrice, "handleGetAdminPrice");

// src/handlers/assets.js
async function handleGetAssetsList(request, env) {
  let r2Files = [];
  if (env.R2_BUCKET) {
    const r2Objects = await env.R2_BUCKET.list();
    if (r2Objects?.objects) {
      r2Files = r2Objects.objects.map((obj) => ({
        key: obj.key,
        size: obj.size,
        uploaded: obj.uploaded,
        source: "r2"
      }));
    }
  }
  let staticFiles = [];
  if (env.ASSETS) {
    const manifestUrl = new URL("/asset-manifest.json", request.url);
    const manifestResponse = await env.ASSETS.fetch(new Request(manifestUrl));
    if (manifestResponse.ok) {
      try {
        staticFiles = await manifestResponse.json();
      } catch (e) {
      }
    }
  }
  const finalFiles = [...r2Files, ...staticFiles];
  return jsonResponse({ files: finalFiles, count: finalFiles.length });
}
__name(handleGetAssetsList, "handleGetAssetsList");
async function handleR2List(request, env) {
  if (!env.R2_BUCKET) {
    return jsonResponse({ error: "R2\u5B58\u50A8\u6876\u672A\u7ED1\u5B9A" }, 500);
  }
  const objects = await env.R2_BUCKET.list();
  const fileList = objects.objects.map((obj) => ({
    key: obj.key,
    size: obj.size,
    uploaded: obj.uploaded
  }));
  return jsonResponse({
    objects: fileList,
    files: fileList,
    count: fileList.length,
    truncated: objects.truncated
  });
}
__name(handleR2List, "handleR2List");
async function handleR2Proxy(request, env) {
  const url = new URL(request.url);
  const fileKey = url.searchParams.get("file")?.trim();
  if (!fileKey) return new Response("\u9519\u8BEF\uFF1A\u672A\u6307\u5B9A\u6587\u4EF6\u53C2\u6570", { status: 400 });
  if (!env.R2_BUCKET) return new Response("\u9519\u8BEF\uFF1AR2\u5B58\u50A8\u6876\u672A\u7ED1\u5B9A", { status: 500 });
  const method = request.method;
  if (method === "HEAD") {
    const headObject = await env.R2_BUCKET.head(fileKey);
    if (!headObject) return new Response("\u9519\u8BEF\uFF1A\u6587\u4EF6\u4E0D\u5B58\u5728", { status: 404 });
    const headers2 = new Headers();
    headers2.set("etag", headObject.httpEtag);
    headers2.set("Content-Length", String(headObject.size));
    headers2.set("Accept-Ranges", "bytes");
    headers2.set("Access-Control-Allow-Origin", "*");
    return new Response(null, { status: 200, headers: headers2 });
  }
  const rangeHeader = request.headers.get("Range");
  if (rangeHeader) {
    const match = /bytes\s*=\s*(\d+)-(\d+)?/.exec(rangeHeader);
    if (match) {
      const start = Number(match[1]);
      const headObject = await env.R2_BUCKET.head(fileKey);
      if (!headObject) return new Response("\u9519\u8BEF\uFF1A\u6587\u4EF6\u4E0D\u5B58\u5728", { status: 404 });
      const size = headObject.size;
      const end = match[2] ? Math.min(Number(match[2]), size - 1) : size - 1;
      const length = end - start + 1;
      const rangedObject = await env.R2_BUCKET.get(fileKey, { range: { offset: start, length } });
      if (!rangedObject) return new Response("\u9519\u8BEF\uFF1A\u6587\u4EF6\u4E0D\u5B58\u5728", { status: 404 });
      const headers2 = new Headers();
      headers2.set("Content-Length", String(length));
      headers2.set("Content-Range", `bytes ${start}-${end}/${size}`);
      headers2.set("Accept-Ranges", "bytes");
      headers2.set("Access-Control-Allow-Origin", "*");
      return new Response(rangedObject.body, { status: 206, headers: headers2 });
    }
  }
  const object = await env.R2_BUCKET.get(fileKey);
  if (!object) return new Response("\u9519\u8BEF\uFF1A\u6587\u4EF6\u4E0D\u5B58\u5728", { status: 404 });
  const headers = new Headers();
  headers.set("Content-Length", String(object.size));
  headers.set("Accept-Ranges", "bytes");
  headers.set("Access-Control-Allow-Origin", "*");
  return new Response(object.body, { status: 200, headers });
}
__name(handleR2Proxy, "handleR2Proxy");

// src/handlers/search.js
async function handleSearch(request, env) {
  const url = new URL(request.url);
  const query = url.searchParams.get("q") || "";
  const limit = parseInt(url.searchParams.get("limit") || "50");
  if (!query) {
    return jsonResponse({ query: "", total: 0, results: [] });
  }
  if (!env.DB) {
    return jsonResponse({ error: "\u6570\u636E\u5E93\u672A\u914D\u7F6E" }, 500);
  }
  const searchQuery = `%${query}%`;
  const { results } = await env.DB.prepare(`
    SELECT id, title, content, file_path as filePath, category 
    FROM text_contents 
    WHERE title LIKE ?1 OR content LIKE ?1 
    LIMIT ?2
  `).bind(searchQuery, limit).all();
  return jsonResponse({
    query,
    total: results.length,
    results: results.map((r) => ({
      id: r.id,
      title: r.title,
      path: r.filePath,
      category: r.category,
      preview: r.content.substring(0, 200)
    }))
  });
}
__name(handleSearch, "handleSearch");
async function handleIndexTexts(request, env) {
  if (!env.DB) {
    return jsonResponse({ error: "\u6570\u636E\u5E93\u672A\u914D\u7F6E" }, 500);
  }
  const { texts } = await request.json();
  if (!Array.isArray(texts)) {
    return jsonResponse({ error: "\u65E0\u6548\u7684\u8BF7\u6C42\u6570\u636E" }, 400);
  }
  await env.DB.prepare(`
    CREATE TABLE IF NOT EXISTS text_contents (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      file_path TEXT NOT NULL,
      category TEXT NOT NULL
    )
  `).run();
  let indexed = 0;
  for (const text of texts) {
    await env.DB.prepare(`
      INSERT INTO text_contents (title, content, file_path, category) 
      VALUES (?1, ?2, ?3, ?4)
    `).bind(text.title, text.content, text.filePath, text.category).run();
    indexed++;
  }
  return jsonResponse({ success: true, indexed });
}
__name(handleIndexTexts, "handleIndexTexts");

// src/handlers/leaderboard.js
init_auth_utils();
async function handleGetLeaderboard(request, env, db) {
  try {
    try {
      const cached = await env.USERS_KV.get("leaderboard:cache");
      if (cached) {
        const { data, timestamp } = JSON.parse(cached);
        if (Date.now() - timestamp < 5 * 60 * 1e3) {
          return jsonResponse({ leaderboard: data, cached: true });
        }
      }
    } catch (cacheError) {
      console.error("\u7F13\u5B58\u8BFB\u53D6\u5931\u8D25:", cacheError);
    }
    const leaderboard = await db.getLeaderboard(100);
    try {
      await env.USERS_KV.put("leaderboard:cache", JSON.stringify({
        data: leaderboard,
        timestamp: Date.now()
      }), { expirationTtl: 600 });
    } catch (cacheError) {
      console.error("\u7F13\u5B58\u5199\u5165\u5931\u8D25:", cacheError);
    }
    return jsonResponse({ leaderboard: leaderboard || [] });
  } catch (error) {
    console.error("\u83B7\u53D6\u6392\u884C\u699C\u5931\u8D25:", error);
    return jsonResponse({
      error: "\u83B7\u53D6\u6392\u884C\u699C\u5931\u8D25",
      message: error.message,
      leaderboard: []
    }, 200);
  }
}
__name(handleGetLeaderboard, "handleGetLeaderboard");
async function handleUpdateTransferData(request, env, db) {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
  }
  const token = authHeader.substring(7);
  const tokenData = await verifyToken(token, env);
  if (!tokenData) return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
  const { bytes } = await request.json();
  if (!bytes || bytes <= 0) {
    return jsonResponse({ error: "\u65E0\u6548\u7684\u5B57\u8282\u6570" }, 400);
  }
  await db.updateTransferData(tokenData.username, bytes);
  await env.USERS_KV.delete("leaderboard:cache");
  return jsonResponse({
    message: "\u4F20\u8F93\u6570\u636E\u5DF2\u66F4\u65B0",
    bytes
  });
}
__name(handleUpdateTransferData, "handleUpdateTransferData");

// src/router.js
async function route(request, env, db, ctx) {
  const url = new URL(request.url);
  const pathname = url.pathname;
  const method = request.method;
  if (method === "OPTIONS") {
    return new Response(null, { headers: { "Access-Control-Allow-Origin": "*" } });
  }
  if (pathname === "/health") {
    return jsonResponse({ status: "ok", timestamp: (/* @__PURE__ */ new Date()).toISOString() });
  }
  if (pathname === "/api/auth/register" && method === "POST") return await handleRegister(request, env, db);
  if (pathname === "/api/auth/login" && method === "POST") return await handleLogin(request, env, db);
  if (pathname === "/api/auth/user-info" && method === "GET") return await handleGetUserInfo(request, env, db);
  if (pathname === "/api/auth/send-verification-code" && method === "POST") return await handleSendVerificationCode(request, env, ctx);
  if (pathname === "/api/auth/forgot-password" && method === "POST") return await handleForgotPassword(request, env, db);
  if (pathname === "/api/auth/reset-password" && method === "POST") return await handleResetPassword(request, env, db);
  if (pathname === "/api/auth/bind-email" && method === "POST") return await handleBindEmail(request, env, db);
  if (pathname === "/api/auth/wechat/login-url" && method === "GET") return await handleGetWechatLoginUrl(request, env);
  if (pathname === "/api/auth/alipay/login-url" && method === "GET") return await handleGetAlipayLoginUrl(request, env);
  if (pathname === "/api/auth/alipay/login" && method === "POST") return await handleAlipayLogin2(request, env);
  if (pathname === "/api/auth/alipay/register" && method === "POST") return await handleAlipayRegister(request, env);
  if (pathname === "/api/auth/alipay/macos-callback" && method === "GET") return await handleMacOSAlipayCallback2(request, env);
  if (pathname === "/api/alipay/create-order" && method === "POST") return await handleCreateAlipayOrder(request, env, db);
  if (pathname === "/api/alipay/query-order" && method === "GET") return await handleQueryAlipayOrder(request, env, db);
  if (pathname === "/api/alipay/notify" && method === "POST") return await handleAlipayNotify(request, env, db);
  if (pathname === "/api/admin/create-redeem-code" && method === "POST") return await handleCreateRedeemCode(request, env, db);
  if (pathname === "/api/admin/use-redeem-code" && method === "POST") return await handleUseRedeemCode(request, env, db);
  if (pathname === "/api/admin/purchase-history" && method === "GET") return await handleGetPurchaseHistory(request, env, db);
  if (pathname === "/api/admin/redeem-history" && method === "GET") return await handleGetRedeemHistory(request, env, db);
  if (pathname === "/api/admin/redeem-codes" && method === "GET") return await handleListRedeemCodes(request, env, db);
  if (pathname === "/api/admin/delete-redeem-code" && method === "DELETE") return await handleDeleteRedeemCode(request, env, db);
  if (pathname === "/api/admin/check-status" && method === "GET") return await handleCheckAdminStatus(request, env, db);
  if (pathname === "/api/admin/get-price" && method === "POST") return await handleGetAdminPrice(request, env, db);
  if (pathname === "/api/assets/list" && method === "GET") return await handleGetAssetsList(request, env);
  if (pathname === "/r2" && url.searchParams.has("list")) return await handleR2List(request, env);
  if (pathname === "/r2" && url.searchParams.has("file")) return await handleR2Proxy(request, env);
  if (pathname === "/api/search" && method === "GET") return await handleSearch(request, env);
  if (pathname === "/api/search/index" && method === "POST") return await handleIndexTexts(request, env);
  if (pathname === "/api/leaderboard" && method === "GET") return await handleGetLeaderboard(request, env, db);
  if (pathname === "/api/leaderboard/update" && method === "POST") return await handleUpdateTransferData(request, env, db);
  return null;
}
__name(route, "route");

// worker.js
init_constants();
var APP_VERSION = Date.now().toString();
var worker_default = {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const pathname = url.pathname;
    const method = request.method;
    if (method === "OPTIONS") {
      return new Response(null, { headers: CORS_HEADERS });
    }
    try {
      const db = new DatabaseService(env.DB);
      const response = await route(request, env, db, ctx);
      if (response) return response;
      if (env.ASSETS) {
        let assetResponse = await env.ASSETS.fetch(request);
        if (assetResponse.status === 404 && !pathname.startsWith("/api/") && !/\.[^/]+$/.test(pathname)) {
          const spaRequest = new Request(new URL("/index.html", request.url), request);
          assetResponse = await env.ASSETS.fetch(spaRequest);
        }
        const newResponse = new Response(
          method === "HEAD" ? null : assetResponse.body,
          {
            status: assetResponse.status,
            statusText: assetResponse.statusText,
            headers: assetResponse.headers
          }
        );
        newResponse.headers.set("Access-Control-Allow-Origin", "*");
        newResponse.headers.set("X-App-Version", APP_VERSION);
        const noCacheList = ["/", "/index.html", "/flutter_service_worker.js", "/main.dart.js"];
        if (noCacheList.includes(pathname)) {
          newResponse.headers.set("Cache-Control", "no-cache, no-store, must-revalidate");
        } else if (/\.(js|css|png|jpg|jpeg|gif|svg|woff2?|json|wasm)$/i.test(pathname)) {
          if (!newResponse.headers.has("Cache-Control")) {
            newResponse.headers.set("Cache-Control", "public, max-age=31536000, immutable");
          }
        }
        return newResponse;
      }
      return new Response("Not Found", { status: 404, headers: CORS_HEADERS });
    } catch (error) {
      console.error("Worker error:", error);
      return new Response("Internal Server Error", {
        status: 500,
        headers: CORS_HEADERS
      });
    }
  }
};
export {
  worker_default as default
};
//# sourceMappingURL=worker.js.map
