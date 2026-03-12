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
    console.log("\u{1F50D} verifyToken: \u5F00\u59CB\u9A8C\u8BC1");
    const parts = token.split(".");
    if (parts.length !== 3) {
      console.log("\u274C verifyToken: token \u683C\u5F0F\u9519\u8BEF\uFF0Cparts.length =", parts.length);
      return null;
    }
    const [headerB64, payloadB64, sigB64] = parts;
    const enc = new TextEncoder();
    const secret = env && (env.JWT_SECRET || env.vars && env.vars.JWT_SECRET) || "dev-secret";
    console.log("\u{1F511} verifyToken: \u4F7F\u7528 secret:", secret ? secret.substring(0, 20) + "..." : "null");
    const data = `${headerB64}.${payloadB64}`;
    const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["verify"]);
    const sig = base64UrlDecodeToArray(sigB64);
    const valid = await crypto.subtle.verify("HMAC", key, sig, enc.encode(data));
    console.log("\u{1F510} verifyToken: \u7B7E\u540D\u9A8C\u8BC1\u7ED3\u679C:", valid);
    if (!valid) {
      console.log("\u274C verifyToken: \u7B7E\u540D\u9A8C\u8BC1\u5931\u8D25");
      return null;
    }
    const payloadBytes = base64UrlDecodeToArray(payloadB64);
    const payloadStr = new TextDecoder().decode(payloadBytes);
    const payload = JSON.parse(payloadStr);
    console.log("\u{1F4E6} verifyToken: payload =", payload);
    const now = Math.floor(Date.now() / 1e3);
    if (payload.exp && payload.exp < now) {
      console.log("\u274C verifyToken: token \u5DF2\u8FC7\u671F, exp:", payload.exp, "now:", now);
      return null;
    }
    console.log("\u2705 verifyToken: \u9A8C\u8BC1\u6210\u529F");
    return payload;
  } catch (e) {
    console.log("\u274C verifyToken: \u5F02\u5E38:", e.message);
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
  generateAlipayAuthString: () => generateAlipayAuthString,
  generateAlipayLoginUrl: () => generateAlipayLoginUrl,
  getAccessToken: () => getAccessToken,
  getAlipayUserInfo: () => getAlipayUserInfo,
  getUserInfoWithToken: () => getUserInfoWithToken,
  handleAlipayCallback: () => handleAlipayCallback,
  handleAlipayLogin: () => handleAlipayLogin,
  handleAlipaySDKLogin: () => handleAlipaySDKLogin,
  handleGetAlipayAuthString: () => handleGetAlipayAuthString,
  handleMacOSAlipayCallback: () => handleMacOSAlipayCallback,
  handleMobileAlipayCallback: () => handleMobileAlipayCallback,
  registerAlipayUser: () => registerAlipayUser,
  sendRegistrationCaptcha: () => sendRegistrationCaptcha
});
async function generateAlipayLoginUrl(env, platform) {
  try {
    console.log("\u751F\u6210\u652F\u4ED8\u5B9D\u767B\u5F55URL\u5F00\u59CB");
    let callbackType = "web";
    let isMobileApp = false;
    let isMacOSApp = false;
    if (platform === "macos") {
      isMacOSApp = true;
      callbackType = "macos";
    } else if (platform === "ios" || platform === "android") {
      isMobileApp = true;
      callbackType = "mobile";
    }
    console.log("\u5E73\u53F0\u68C0\u6D4B:", { platform, isMobileApp, isMacOSApp, callbackType });
    console.log("\u73AF\u5883\u53D8\u91CF\u68C0\u67E5:", {
      hasAppId: !!env.ALIPAY_APP_ID,
      hasWorkerUrl: !!env.WORKER_URL,
      hasUsersKv: !!env.USERS_KV,
      isMobileApp,
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
    } else if (isMobileApp) {
      redirectUri = encodeURIComponent(`${workerUrl}/api/auth/alipay/mobile-callback`);
      console.log("\u79FB\u52A8\u7AEF\u5E94\u7528\u4E13\u7528\u56DE\u8C03\u5730\u5740:", redirectUri);
    } else {
      redirectUri = encodeURIComponent(`${workerUrl}/api/auth/alipay/callback`);
      console.log("Web\u5E94\u7528\u6807\u51C6\u56DE\u8C03\u5730\u5740:", redirectUri);
    }
    const authUrl = `https://openauth.alipay.com/oauth2/publicAppAuthorize.htm?app_id=${appId}&scope=auth_user&redirect_uri=${redirectUri}&state=${state}`;
    console.log("\u751F\u6210\u7684\u6388\u6743URL:", authUrl);
    if (env.DB) {
      const stateData = {
        type: callbackType,
        timestamp: Date.now(),
        valid: true
      };
      const expiresAt = new Date(Date.now() + 6e5).toISOString();
      await env.DB.prepare(
        "INSERT INTO alipay_states (state, state_data, expires_at) VALUES (?, ?, ?)"
      ).bind(state, JSON.stringify(stateData), expiresAt).run();
      console.log("state\u5DF2\u5B58\u50A8\u5230D1:", stateData);
    } else {
      console.warn("DB\u672A\u7ED1\u5B9A\uFF0C\u8DF3\u8FC7state\u5B58\u50A8");
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
      const storedState = await env.DB.prepare(
        'SELECT state_data FROM alipay_states WHERE state = ? AND expires_at > datetime("now")'
      ).bind(state).first();
      if (!storedState) {
        return jsonResponse2({ error: "\u65E0\u6548\u7684state\u53C2\u6570" }, 400);
      }
      await env.DB.prepare("DELETE FROM alipay_states WHERE state = ?").bind(state).run();
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
    const bindingResult = await env.DB.prepare(
      "SELECT username FROM alipay_bindings WHERE alipay_user_id = ?"
    ).bind(alipayUser.user_id).first();
    if (bindingResult) {
      const userResult = await env.DB.prepare(
        "SELECT * FROM users WHERE username = ?"
      ).bind(bindingResult.username).first();
      if (userResult) {
        const user = userResult;
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
      const existingAlipay2 = await env.DB.prepare(
        "SELECT username FROM alipay_bindings WHERE alipay_user_id = ?"
      ).bind(alipayUserId).first();
      if (existingAlipay2) {
        return jsonResponse2({ error: "\u8BE5\u652F\u4ED8\u5B9D\u8D26\u53F7\u5DF2\u6CE8\u518C\u5176\u4ED6\u7528\u6237" }, 400);
      }
      const baseUsername = alipayNickname || "\u652F\u4ED8\u5B9D\u7528\u6237";
      let autoUsername = baseUsername;
      let counter = 1;
      let usernameCheck = await env.DB.prepare(
        "SELECT username FROM users WHERE username = ?"
      ).bind(autoUsername).first();
      while (usernameCheck) {
        autoUsername = `${baseUsername}_${counter}`;
        counter++;
        usernameCheck = await env.DB.prepare(
          "SELECT username FROM users WHERE username = ?"
        ).bind(autoUsername).first();
      }
      const autoEmail = `alipay_${alipayUserId}_${Date.now()}@alipay.user`;
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
      await env.DB.prepare(`
        INSERT INTO users (
          username, email, password_hash, salt, iterations, algo,
          email_verified, membership_type, membership_expires_at,
          alipay_user_id, alipay_open_id, alipay_nickname, alipay_avatar,
          created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).bind(
        autoUsername,
        autoEmail,
        creds2.passwordHash,
        creds2.salt,
        creds2.iterations,
        creds2.algo,
        1,
        // email_verified
        "trial",
        // membership_type
        calculateTrialEndDate().toISOString(),
        alipayUserId,
        alipayOpenId || null,
        alipayNickname || "\u652F\u4ED8\u5B9D\u7528\u6237",
        alipayAvatar || null,
        (/* @__PURE__ */ new Date()).toISOString(),
        (/* @__PURE__ */ new Date()).toISOString()
      ).run();
      await env.DB.prepare(
        "INSERT INTO email_username_mapping (email, username) VALUES (?, ?)"
      ).bind(autoEmail, autoUsername).run();
      await env.DB.prepare(
        "INSERT OR REPLACE INTO alipay_bindings (alipay_user_id, username, bound_at) VALUES (?, ?, ?)"
      ).bind(alipayUserId, autoUsername, (/* @__PURE__ */ new Date()).toISOString()).run();
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
    const existingEmail = await env.DB.prepare(
      "SELECT username FROM email_username_mapping WHERE email = ?"
    ).bind(normalizedEmail).first();
    if (existingEmail) {
      return jsonResponse2({ error: "\u8BE5\u90AE\u7BB1\u5DF2\u88AB\u6CE8\u518C" }, 400);
    }
    const existingAlipay = await env.DB.prepare(
      "SELECT username FROM alipay_bindings WHERE alipay_user_id = ?"
    ).bind(alipayUserId).first();
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
    await env.DB.prepare(`
      INSERT INTO users (
        username, email, password_hash, salt, iterations, algo,
        email_verified, membership_type,
        alipay_user_id, alipay_open_id, alipay_nickname, alipay_avatar,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).bind(
      username.trim(),
      normalizedEmail,
      creds.passwordHash,
      creds.salt,
      creds.iterations,
      creds.algo,
      1,
      "free",
      alipayUserId,
      alipayOpenId || null,
      alipayNickname || "\u652F\u4ED8\u5B9D\u7528\u6237",
      alipayAvatar || null,
      (/* @__PURE__ */ new Date()).toISOString(),
      (/* @__PURE__ */ new Date()).toISOString()
    ).run();
    await env.DB.prepare(
      "INSERT INTO email_username_mapping (email, username) VALUES (?, ?)"
    ).bind(normalizedEmail, username.trim()).run();
    await env.DB.prepare(
      "INSERT INTO alipay_bindings (alipay_user_id, username, bound_at) VALUES (?, ?, ?)"
    ).bind(alipayUserId, username.trim(), (/* @__PURE__ */ new Date()).toISOString()).run();
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
    const existingUser = await env.DB.prepare(
      "SELECT username FROM users WHERE username = ?"
    ).bind(username).first();
    if (existingUser) {
      return jsonResponse2({ error: "\u7528\u6237\u540D\u5DF2\u5B58\u5728" }, 400);
    }
    if (email) {
      const emailMapped = await env.DB.prepare(
        "SELECT username FROM email_username_mapping WHERE email = ?"
      ).bind(String(email).trim().toLowerCase()).first();
      if (emailMapped) {
        return jsonResponse2({ error: "\u8BE5\u90AE\u7BB1\u5DF2\u88AB\u6CE8\u518C" }, 400);
      }
    }
    const existingBinding = await env.DB.prepare(
      "SELECT username FROM alipay_bindings WHERE alipay_user_id = ?"
    ).bind(alipayUserId).first();
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
    await env.DB.prepare(`
      INSERT INTO users (
        username, email, password_hash, salt, iterations, algo,
        email_verified, membership_type, membership_expires_at,
        alipay_user_id, alipay_nickname, alipay_avatar,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).bind(
      username,
      userData.email,
      userData.passwordHash,
      userData.salt,
      userData.iterations,
      userData.algo,
      userData.emailVerified ? 1 : 0,
      userData.membershipType,
      userData.freeTrialEndDate,
      alipayUserId,
      nickname || "\u652F\u4ED8\u5B9D\u7528\u6237",
      avatar || "",
      (/* @__PURE__ */ new Date()).toISOString(),
      (/* @__PURE__ */ new Date()).toISOString()
    ).run();
    if (userData.email) {
      await env.DB.prepare(
        "INSERT INTO email_username_mapping (email, username) VALUES (?, ?)"
      ).bind(userData.email, username).run();
    }
    await env.DB.prepare(
      "INSERT INTO alipay_bindings (alipay_user_id, username, bound_at) VALUES (?, ?, ?)"
    ).bind(alipayUserId, username, (/* @__PURE__ */ new Date()).toISOString()).run();
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
    const existingUser = await env.DB.prepare(
      "SELECT username FROM email_username_mapping WHERE email = ?"
    ).bind(normalizedEmail).first();
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
      const redirectUrl2 = `com.ombhrum.fabushi://error=missing_auth_code&error_message=${encodeURIComponent("\u7F3A\u5C11\u6388\u6743\u7801")}`;
      console.error("macOS\u652F\u4ED8\u5B9D\u56DE\u8C03\u7F3A\u5C11\u6388\u6743\u7801\uFF0C\u91CD\u5B9A\u5411\u5230\u5E94\u7528:", redirectUrl2);
      return Response.redirect(redirectUrl2, 302);
    }
    if (authCode.length < 10) {
      console.error("macOS\u652F\u4ED8\u5B9D\u56DE\u8C03\u6388\u6743\u7801\u683C\u5F0F\u65E0\u6548:", authCode);
      const redirectUrl2 = `com.ombhrum.fabushi://error=invalid_auth_code&error_message=${encodeURIComponent("\u6388\u6743\u7801\u683C\u5F0F\u65E0\u6548")}`;
      return Response.redirect(redirectUrl2, 302);
    }
    if (state) {
      const storedStateData = await env.DB.prepare(
        'SELECT state_data FROM alipay_states WHERE state = ? AND expires_at > datetime("now")'
      ).bind(state).first();
      if (!storedStateData) {
        console.error("macOS\u652F\u4ED8\u5B9D\u56DE\u8C03\u65E0\u6548\u7684state\u53C2\u6570:", state);
        const redirectUrl2 = `com.ombhrum.fabushi://error=invalid_state&error_message=${encodeURIComponent("\u767B\u5F55\u72B6\u6001\u65E0\u6548\uFF0C\u8BF7\u91CD\u65B0\u767B\u5F55")}`;
        return Response.redirect(redirectUrl2, 302);
      }
      try {
        const stateData = JSON.parse(storedStateData.state_data);
        if (stateData.type !== "macos") {
          console.warn("state\u7C7B\u578B\u4E0D\u5339\u914D\uFF0C\u671F\u671Bmacos\uFF0C\u5B9E\u9645:", stateData.type);
        }
      } catch (parseError) {
        console.warn("\u89E3\u6790state\u6570\u636E\u5931\u8D25:", parseError);
      }
      await env.DB.prepare("DELETE FROM alipay_states WHERE state = ?").bind(state).run();
    }
    const alipayUserResult = await getAlipayUserInfo(authCode, env);
    if (alipayUserResult.error) {
      console.error("\u83B7\u53D6\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F\u5931\u8D25:", alipayUserResult);
      if (alipayUserResult.code === "CODE_INVALID" || alipayUserResult.code === "CODE_REUSED") {
        const errorMessage = alipayUserResult.message || "\u652F\u4ED8\u5B9D\u6388\u6743\u5931\u8D25";
        const redirectUrl2 = `com.ombhrum.fabushi://error=auth_failed&error_message=${encodeURIComponent(errorMessage)}&error_code=${alipayUserResult.code}`;
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
      const redirectUrl2 = `com.ombhrum.fabushi://error=invalid_alipay_user&error_message=${encodeURIComponent("\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F\u4E0D\u5B8C\u6574")}`;
      return Response.redirect(redirectUrl2, 302);
    }
    const macosBindingResult = await env.DB.prepare(
      "SELECT username FROM alipay_bindings WHERE alipay_user_id = ?"
    ).bind(alipayUser.user_id).first();
    if (macosBindingResult) {
      const macosUserResult = await env.DB.prepare(
        "SELECT * FROM users WHERE username = ?"
      ).bind(macosBindingResult.username).first();
      if (macosUserResult) {
        const user = macosUserResult;
        console.log("\u{1F510} \u751F\u6210 token \u524D - JWT_SECRET \u72B6\u6001:", env.JWT_SECRET ? "\u5DF2\u914D\u7F6E" : "\u672A\u914D\u7F6E");
        console.log("\u{1F511} \u751F\u6210 token \u524D - JWT_SECRET \u503C:", env.JWT_SECRET ? env.JWT_SECRET.substring(0, 20) + "..." : "null");
        const token = await generateToken(user.username, env);
        console.log("\u2705 token \u5DF2\u751F\u6210:", token.substring(0, 30) + "...");
        console.log("macOS\u5E94\u7528\u652F\u4ED8\u5B9D\u767B\u5F55\u6210\u529F\uFF0C\u7528\u6237\u5DF2\u6CE8\u518C:", user.username);
        const redirectUrl2 = `com.ombhrum.fabushi://alipay_auth_code=${authCode}&state=${state}&token=${token}&username=${user.username}&isNewUser=false&loginMethod=alipay&alipay_user_id=${alipayUser.user_id}&alipay_nickname=${encodeURIComponent(alipayUser.nick_name || "")}&alipay_avatar=${encodeURIComponent(alipayUser.avatar || "")}`;
        console.log("macOS\u5E94\u7528\u652F\u4ED8\u5B9D\u767B\u5F55\u6210\u529F\uFF0C\u91CD\u5B9A\u5411\u5230\u5E94\u7528:", redirectUrl2);
        return Response.redirect(redirectUrl2, 302);
      }
    }
    console.log("macOS\u5E94\u7528\u65B0\u7528\u6237\u6216\u672A\u6CE8\u518C\u652F\u4ED8\u5B9D\u8D26\u53F7\uFF0C\u91CD\u5B9A\u5411\u5230\u5E94\u7528\u8FDB\u884C\u6CE8\u518C");
    const redirectUrl = `com.ombhrum.fabushi://alipay_auth_code=${authCode}&state=${state}&isNewUser=true&needsRegistration=true&loginMethod=alipay&alipay_user_id=${alipayUser.user_id}&alipay_nickname=${encodeURIComponent(alipayUser.nick_name || "")}&alipay_avatar=${encodeURIComponent(alipayUser.avatar || "")}`;
    console.log("macOS\u5E94\u7528\u65B0\u7528\u6237\uFF0C\u91CD\u5B9A\u5411\u5230\u5E94\u7528\u8FDB\u884C\u6CE8\u518C:", redirectUrl);
    return Response.redirect(redirectUrl, 302);
  } catch (error) {
    console.error("macOS\u5E94\u7528\u652F\u4ED8\u5B9D\u56DE\u8C03\u5904\u7406\u5931\u8D25:", error);
    const redirectUrl = `com.ombhrum.fabushi://error=callback_failed&error_message=${encodeURIComponent(error.message || "\u652F\u4ED8\u5B9D\u767B\u5F55\u5904\u7406\u5931\u8D25")}`;
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
      const storedState = await env.DB.prepare(
        'SELECT state_data FROM alipay_states WHERE state = ? AND expires_at > datetime("now")'
      ).bind(state).first();
      if (!storedState) {
        console.error("\u65E0\u6548\u7684state\u53C2\u6570:", state);
        const redirectUrl2 = new URL("/index.html", request.url);
        redirectUrl2.hash = "error=invalid_state&error_message=\u767B\u5F55\u72B6\u6001\u65E0\u6548\uFF0C\u8BF7\u91CD\u65B0\u767B\u5F55";
        return Response.redirect(redirectUrl2.toString(), 302);
      }
      await env.DB.prepare("DELETE FROM alipay_states WHERE state = ?").bind(state).run();
    }
    const alipayUser = await getAlipayUserInfo(authCode, env);
    console.log("\u83B7\u53D6\u5230\u7684\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F:", alipayUser);
    if (!alipayUser || !alipayUser.user_id) {
      console.error("\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F\u4E0D\u5B8C\u6574:", alipayUser);
      const redirectUrl2 = new URL("/index.html", request.url);
      redirectUrl2.hash = "error=invalid_alipay_user&error_message=\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F\u4E0D\u5B8C\u6574";
      return Response.redirect(redirectUrl2.toString(), 302);
    }
    const webBindingResult = await env.DB.prepare(
      "SELECT username FROM alipay_bindings WHERE alipay_user_id = ?"
    ).bind(alipayUser.user_id).first();
    if (webBindingResult) {
      const webUserResult = await env.DB.prepare(
        "SELECT * FROM users WHERE username = ?"
      ).bind(webBindingResult.username).first();
      if (webUserResult) {
        const user = webUserResult;
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
async function handleMobileAlipayCallback(request, env) {
  try {
    const url = new URL(request.url);
    const authCode = url.searchParams.get("auth_code");
    const state = url.searchParams.get("state");
    console.log("\u6536\u5230\u79FB\u52A8\u7AEF\u5E94\u7528\u652F\u4ED8\u5B9D\u767B\u5F55\u56DE\u8C03:", {
      authCode: authCode ? authCode.substring(0, 10) + "..." : "null",
      state: state || "null",
      fullUrl: request.url
    });
    const appScheme = "com.ombhrum.fabushi://";
    if (!authCode) {
      const redirectUrl2 = `${appScheme}error=missing_auth_code&error_message=${encodeURIComponent("\u7F3A\u5C11\u6388\u6743\u7801")}`;
      console.error("\u79FB\u52A8\u7AEF\u652F\u4ED8\u5B9D\u56DE\u8C03\u7F3A\u5C11\u6388\u6743\u7801\uFF0C\u91CD\u5B9A\u5411\u5230\u5E94\u7528:", redirectUrl2);
      return Response.redirect(redirectUrl2, 302);
    }
    if (authCode.length < 10) {
      console.error("\u79FB\u52A8\u7AEF\u652F\u4ED8\u5B9D\u56DE\u8C03\u6388\u6743\u7801\u683C\u5F0F\u65E0\u6548:", authCode);
      const redirectUrl2 = `${appScheme}error=invalid_auth_code&error_message=${encodeURIComponent("\u6388\u6743\u7801\u683C\u5F0F\u65E0\u6548")}`;
      return Response.redirect(redirectUrl2, 302);
    }
    if (state) {
      const storedStateData = await env.DB.prepare(
        'SELECT state_data FROM alipay_states WHERE state = ? AND expires_at > datetime("now")'
      ).bind(state).first();
      if (!storedStateData) {
        console.error("\u79FB\u52A8\u7AEF\u652F\u4ED8\u5B9D\u56DE\u8C03\u65E0\u6548\u7684state\u53C2\u6570:", state);
        const redirectUrl2 = `${appScheme}error=invalid_state&error_message=${encodeURIComponent("\u767B\u5F55\u72B6\u6001\u65E0\u6548\uFF0C\u8BF7\u91CD\u65B0\u767B\u5F55")}`;
        return Response.redirect(redirectUrl2, 302);
      }
      try {
        const stateData = JSON.parse(storedStateData.state_data);
        if (stateData.type !== "mobile") {
          console.warn("state\u7C7B\u578B\u4E0D\u5339\u914D\uFF0C\u671F\u671Bmobile\uFF0C\u5B9E\u9645:", stateData.type);
        }
      } catch (parseError) {
        console.warn("\u89E3\u6790state\u6570\u636E\u5931\u8D25:", parseError);
      }
      await env.DB.prepare("DELETE FROM alipay_states WHERE state = ?").bind(state).run();
    }
    const alipayUserResult = await getAlipayUserInfo(authCode, env);
    if (alipayUserResult.error) {
      console.error("\u83B7\u53D6\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F\u5931\u8D25:", alipayUserResult);
      if (alipayUserResult.code === "CODE_INVALID" || alipayUserResult.code === "CODE_REUSED") {
        const errorMessage = alipayUserResult.message || "\u652F\u4ED8\u5B9D\u6388\u6743\u5931\u8D25";
        const redirectUrl2 = `${appScheme}error=auth_failed&error_message=${encodeURIComponent(errorMessage)}&error_code=${alipayUserResult.code}`;
        console.log("\u79FB\u52A8\u7AEF\u652F\u4ED8\u5B9D\u6388\u6743\u5931\u8D25\uFF0C\u91CD\u5B9A\u5411\u5230\u5E94\u7528:", redirectUrl2);
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
    console.log("\u79FB\u52A8\u7AEF\u5E94\u7528\u83B7\u53D6\u5230\u7684\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F:", alipayUser);
    if (!alipayUser || !alipayUser.user_id) {
      console.error("\u79FB\u52A8\u7AEF\u5E94\u7528\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F\u4E0D\u5B8C\u6574:", alipayUser);
      const redirectUrl2 = `${appScheme}error=invalid_alipay_user&error_message=${encodeURIComponent("\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F\u4E0D\u5B8C\u6574")}`;
      return Response.redirect(redirectUrl2, 302);
    }
    const mobileBindingResult = await env.DB.prepare(
      "SELECT username FROM alipay_bindings WHERE alipay_user_id = ?"
    ).bind(alipayUser.user_id).first();
    if (mobileBindingResult) {
      const mobileUserResult = await env.DB.prepare(
        "SELECT * FROM users WHERE username = ?"
      ).bind(mobileBindingResult.username).first();
      if (mobileUserResult) {
        const user = mobileUserResult;
        console.log("\u{1F510} \u79FB\u52A8\u7AEF\u751F\u6210 token \u524D - JWT_SECRET \u72B6\u6001:", env.JWT_SECRET ? "\u5DF2\u914D\u7F6E" : "\u672A\u914D\u7F6E");
        const token = await generateToken(user.username, env);
        console.log("\u2705 \u79FB\u52A8\u7AEF token \u5DF2\u751F\u6210:", token.substring(0, 30) + "...");
        console.log("\u79FB\u52A8\u7AEF\u5E94\u7528\u652F\u4ED8\u5B9D\u767B\u5F55\u6210\u529F\uFF0C\u7528\u6237\u5DF2\u6CE8\u518C:", user.username);
        const redirectUrl2 = `${appScheme}alipay_auth_code=${authCode}&state=${state}&token=${token}&username=${user.username}&isNewUser=false&loginMethod=alipay&alipay_user_id=${alipayUser.user_id}&alipay_nickname=${encodeURIComponent(alipayUser.nick_name || "")}&alipay_avatar=${encodeURIComponent(alipayUser.avatar || "")}`;
        console.log("\u79FB\u52A8\u7AEF\u5E94\u7528\u652F\u4ED8\u5B9D\u767B\u5F55\u6210\u529F\uFF0C\u91CD\u5B9A\u5411\u5230\u5E94\u7528:", redirectUrl2);
        return Response.redirect(redirectUrl2, 302);
      }
    }
    console.log("\u79FB\u52A8\u7AEF\u5E94\u7528\u65B0\u7528\u6237\u6216\u672A\u6CE8\u518C\u652F\u4ED8\u5B9D\u8D26\u53F7\uFF0C\u91CD\u5B9A\u5411\u5230\u5E94\u7528\u8FDB\u884C\u6CE8\u518C");
    const redirectUrl = `${appScheme}alipay_auth_code=${authCode}&state=${state}&isNewUser=true&needsRegistration=true&loginMethod=alipay&alipay_user_id=${alipayUser.user_id}&alipay_nickname=${encodeURIComponent(alipayUser.nick_name || "")}&alipay_avatar=${encodeURIComponent(alipayUser.avatar || "")}`;
    console.log("\u79FB\u52A8\u7AEF\u5E94\u7528\u65B0\u7528\u6237\uFF0C\u91CD\u5B9A\u5411\u5230\u5E94\u7528\u8FDB\u884C\u6CE8\u518C:", redirectUrl);
    return Response.redirect(redirectUrl, 302);
  } catch (error) {
    console.error("\u79FB\u52A8\u7AEF\u5E94\u7528\u652F\u4ED8\u5B9D\u56DE\u8C03\u5904\u7406\u5931\u8D25:", error);
    const redirectUrl = `com.ombhrum.fabushi://error=callback_failed&error_message=${encodeURIComponent(error.message || "\u652F\u4ED8\u5B9D\u767B\u5F55\u5904\u7406\u5931\u8D25")}`;
    return Response.redirect(redirectUrl, 302);
  }
}
async function generateAlipayAuthString(env) {
  try {
    const appId = env.ALIPAY_APP_ID;
    const privateKey = env.ALIPAY_PRIVATE_KEY;
    if (!appId || !privateKey) {
      console.error("\u652F\u4ED8\u5B9D\u914D\u7F6E\u4E0D\u5B8C\u6574", { hasAppId: !!appId, hasPrivateKey: !!privateKey });
      return jsonResponse2({ error: "\u652F\u4ED8\u5B9D\u914D\u7F6E\u4E0D\u5B8C\u6574" }, 500);
    }
    const pid = env.ALIPAY_PID;
    if (!pid) {
      console.error("\u8B66\u544A: ALIPAY_PID \u672A\u914D\u7F6E\uFF0CSDK\u6388\u6743\u53EF\u80FD\u5931\u8D25");
    }
    const targetId = crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).substring(2) + Date.now().toString(36);
    const authParams = {
      apiname: "com.alipay.account.auth",
      app_id: appId,
      app_name: "mc",
      auth_type: "AUTHACCOUNT",
      biz_type: "openservice",
      method: "alipay.open.auth.sdk.code.get",
      product_id: "APP_FAST_LOGIN",
      scope: "auth_user",
      // 改为auth_user以获取用户信息
      sign_type: "RSA2",
      target_id: targetId
    };
    if (pid) {
      authParams.pid = pid;
    }
    console.log("\u751F\u6210SDK\u6388\u6743\u5B57\u7B26\u4E32\uFF0C\u53C2\u6570:", authParams);
    const cryptoKey = await importPrivateKey(privateKey);
    const sign = await generateSign(authParams, cryptoKey);
    console.log("\u7B7E\u540D\u751F\u6210\u6210\u529F\uFF0C\u957F\u5EA6:", sign.length);
    const authStrParts = [];
    const sortedKeys = Object.keys(authParams).sort();
    for (const key of sortedKeys) {
      authStrParts.push(`${key}=${authParams[key]}`);
    }
    authStrParts.push(`sign=${encodeURIComponent(sign)}`);
    const authString = authStrParts.join("&");
    console.log("\u751F\u6210\u7684\u6388\u6743\u5B57\u7B26\u4E32\u957F\u5EA6:", authString.length);
    console.log("\u6388\u6743\u5B57\u7B26\u4E32\u9884\u89C8:", authString.substring(0, 200) + "...");
    return jsonResponse2({
      success: true,
      authString,
      targetId
    });
  } catch (error) {
    console.error("\u751F\u6210SDK\u6388\u6743\u5B57\u7B26\u4E32\u5931\u8D25:", error);
    return jsonResponse2({ error: "\u751F\u6210\u6388\u6743\u5B57\u7B26\u4E32\u5931\u8D25: " + error.message }, 500);
  }
}
async function handleGetAlipayAuthString(request, env) {
  return await generateAlipayAuthString(env);
}
async function handleAlipaySDKLogin(request, env) {
  try {
    const { auth_code, target_id } = await request.json();
    if (!auth_code) {
      return jsonResponse2({ error: "\u7F3A\u5C11\u6388\u6743\u7801auth_code" }, 400);
    }
    console.log("SDK\u6388\u6743\u767B\u5F55\uFF0Cauth_code:", auth_code.substring(0, 10) + "...");
    const alipayUser = await getAlipayUserInfo(auth_code, env);
    if (alipayUser.error) {
      console.error("\u83B7\u53D6\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F\u5931\u8D25:", alipayUser);
      if (alipayUser.code === "CODE_INVALID" || alipayUser.code === "CODE_REUSED") {
        return jsonResponse2({
          error: alipayUser.message || "\u652F\u4ED8\u5B9D\u6388\u6743\u5931\u8D25",
          code: alipayUser.code
        }, 400);
      }
      return jsonResponse2({
        error: "\u652F\u4ED8\u5B9D\u767B\u5F55\u5931\u8D25",
        details: alipayUser.message
      }, 500);
    }
    console.log("\u83B7\u53D6\u5230\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F:", alipayUser);
    if (!alipayUser || !alipayUser.user_id) {
      return jsonResponse2({ error: "\u652F\u4ED8\u5B9D\u7528\u6237\u4FE1\u606F\u4E0D\u5B8C\u6574" }, 400);
    }
    const bindingResult = await env.DB.prepare(
      "SELECT username FROM alipay_bindings WHERE alipay_user_id = ?"
    ).bind(alipayUser.user_id).first();
    if (bindingResult) {
      const userResult = await env.DB.prepare(
        "SELECT * FROM users WHERE username = ?"
      ).bind(bindingResult.username).first();
      if (userResult) {
        const token = await generateToken(userResult.username, env);
        return jsonResponse2({
          success: true,
          token,
          username: userResult.username,
          isNewUser: false,
          loginMethod: "alipay_sdk",
          alipayUser: {
            userId: alipayUser.user_id,
            nickname: alipayUser.nick_name,
            avatar: alipayUser.avatar
          }
        });
      }
    }
    return jsonResponse2({
      success: true,
      isNewUser: true,
      needsRegistration: true,
      alipayUser: {
        userId: alipayUser.user_id,
        nickname: alipayUser.nick_name,
        avatar: alipayUser.avatar
      }
    });
  } catch (error) {
    console.error("SDK\u6388\u6743\u767B\u5F55\u5931\u8D25:", error);
    return jsonResponse2({ error: "SDK\u767B\u5F55\u5931\u8D25: " + error.message }, 500);
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
    __name(handleMobileAlipayCallback, "handleMobileAlipayCallback");
    __name(generateAlipayAuthString, "generateAlipayAuthString");
    __name(handleGetAlipayAuthString, "handleGetAlipayAuthString");
    __name(handleAlipaySDKLogin, "handleAlipaySDKLogin");
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
  // 直接暴露 prepare 方法，允许处理器直接调用 db.prepare()
  prepare(query2) {
    return this.db.prepare(query2);
  }
  // 用户操作
  async getUser(username) {
    return await this.db.prepare("SELECT * FROM users WHERE username = ?").bind(username).first();
  }
  async getUserByAlipayId(alipayUserId) {
    const binding = await this.db.prepare("SELECT username FROM alipay_bindings WHERE alipay_user_id = ?").bind(alipayUserId).first();
    if (!binding) return null;
    return await this.getUser(binding.username);
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
  // 根据手机号查询用户
  async getUserByPhone(phoneNumber) {
    return await this.db.prepare("SELECT * FROM users WHERE phone_number = ?").bind(phoneNumber).first();
  }
  // 根据Firebase UID查询用户
  async getUserByFirebaseUid(firebaseUid) {
    return await this.db.prepare("SELECT * FROM users WHERE firebase_uid = ?").bind(firebaseUid).first();
  }
  // 创建手机用户 (无密码)
  async createPhoneUser(userData) {
    await this.db.prepare(`
      INSERT INTO users (username, email, phone_number, firebase_uid, password_hash, salt, iterations, algo, email_verified, membership_type, free_trial_end_date, created_at)
      VALUES (?, ?, ?, ?, '', '', 0, '', 1, ?, ?, ?)
    `).bind(
      userData.username,
      userData.email,
      userData.phoneNumber,
      userData.firebaseUid,
      userData.membershipType,
      userData.freeTrialEndDate,
      userData.createdAt
    ).run();
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
    const result = await this.db.prepare("SELECT * FROM purchase_history WHERE user_id = ? ORDER BY purchased_at DESC").bind(username).all();
    return result.results || [];
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
    const result = await this.db.prepare("SELECT * FROM redeem_history WHERE user_id = ? ORDER BY redeemed_at DESC").bind(username).all();
    return result.results || [];
  }
  // 兑换码列表
  async listRedeemCodes(status, page, limit) {
    let query2 = "SELECT * FROM redeem_codes";
    const params = [];
    if (status === "used") {
      query2 += " WHERE used = 1";
    } else if (status === "unused") {
      query2 += " WHERE used = 0";
    }
    query2 += " ORDER BY created_at DESC LIMIT ? OFFSET ?";
    params.push(limit, (page - 1) * limit);
    const result = await this.db.prepare(query2).bind(...params).all();
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
    nickname: user.nickname,
    avatar: user.avatar,
    createdAt: user.created_at,
    emailVerified: user.email_verified === 1,
    membership: {
      type: user.membership_type,
      expiresAt: user.membership_expires_at
    }
  });
}
__name(handleGetUserInfo, "handleGetUserInfo");
async function handleUpdateProfile(request, env, db) {
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
    const { nickname, avatar } = await request.json();
    const updates = [];
    const values = [];
    if (nickname !== void 0) {
      updates.push("nickname = ?");
      values.push(nickname);
    }
    if (avatar !== void 0) {
      updates.push("avatar = ?");
      values.push(avatar);
    }
    if (updates.length === 0) {
      return jsonResponse({ message: "\u6CA1\u6709\u9700\u8981\u66F4\u65B0\u7684\u5B57\u6BB5" });
    }
    updates.push("updated_at = ?");
    values.push((/* @__PURE__ */ new Date()).toISOString());
    values.push(tokenData.username);
    await db.prepare(`
      UPDATE users 
      SET ${updates.join(", ")}
      WHERE username = ?
    `).bind(...values).run();
    return jsonResponse({ message: "\u4E2A\u4EBA\u8D44\u6599\u66F4\u65B0\u6210\u529F" });
  } catch (error) {
    console.error("\u66F4\u65B0\u4E2A\u4EBA\u8D44\u6599\u5931\u8D25:", error);
    return jsonResponse({ error: "\u66F4\u65B0\u4E2A\u4EBA\u8D44\u6599\u5931\u8D25" }, 500);
  }
}
__name(handleUpdateProfile, "handleUpdateProfile");
async function handleFirebasePhoneLogin(request, env, db) {
  try {
    const { idToken, phoneNumber, firebaseUid, isNewUser } = await request.json();
    if (!idToken || !phoneNumber || !firebaseUid) {
      return jsonResponse({ error: "\u7F3A\u5C11\u5FC5\u8981\u53C2\u6570" }, 400);
    }
    let user = await db.getUserByPhone(phoneNumber);
    if (!user) {
      user = await db.getUserByFirebaseUid(firebaseUid);
    }
    let token;
    let username;
    if (user) {
      if (!user.firebase_uid) {
        await db.prepare(`
          UPDATE users SET firebase_uid = ?, phone_number = ?, updated_at = ?
          WHERE username = ?
        `).bind(firebaseUid, phoneNumber, (/* @__PURE__ */ new Date()).toISOString(), user.username).run();
      }
      username = user.username;
      token = await generateToken(username, env);
      return jsonResponse({
        success: true,
        token,
        username,
        isNewUser: false,
        user: {
          username: user.username,
          email: user.email || "",
          phoneNumber,
          membership: {
            type: user.membership_type || "trial",
            expiresAt: user.membership_expires_at
          }
        }
      });
    } else {
      username = `user_${Date.now().toString(36)}`;
      const email = `${firebaseUid}@phone.user`;
      const trialEndDate = calculateTrialEndDate();
      await db.createPhoneUser({
        username,
        email,
        phoneNumber,
        firebaseUid,
        membershipType: "trial",
        freeTrialEndDate: trialEndDate.toISOString(),
        createdAt: (/* @__PURE__ */ new Date()).toISOString()
      });
      token = await generateToken(username, env);
      return jsonResponse({
        success: true,
        token,
        username,
        isNewUser: true,
        user: {
          username,
          email,
          phoneNumber,
          membership: {
            type: "trial",
            expiresAt: trialEndDate.toISOString()
          }
        }
      });
    }
  } catch (error) {
    console.error("Firebase\u624B\u673A\u767B\u5F55\u5931\u8D25:", error);
    return jsonResponse({ error: "Firebase\u624B\u673A\u767B\u5F55\u5931\u8D25: " + error.message }, 500);
  }
}
__name(handleFirebasePhoneLogin, "handleFirebasePhoneLogin");

// src/handlers/sms.js
function generateCode() {
  return Math.floor(1e5 + Math.random() * 9e5).toString();
}
__name(generateCode, "generateCode");
async function handleSendSmsCode(request, env, db) {
  try {
    const { phoneNumber } = await request.json();
    if (!phoneNumber || phoneNumber.length < 11) {
      return new Response(JSON.stringify({
        success: false,
        error: "\u8BF7\u8F93\u5165\u6709\u6548\u7684\u624B\u673A\u53F7"
      }), { status: 400 });
    }
    const code = generateCode();
    const expiresAt = Date.now() + 5 * 60 * 1e3;
    await env.USERS_KV.put(
      `sms_code_${phoneNumber}`,
      JSON.stringify({ code, expiresAt, attempts: 0 }),
      { expirationTtl: 300 }
      // 5分钟后自动删除
    );
    console.log(`\u{1F4F1} \u53D1\u9001\u9A8C\u8BC1\u7801\u5230 ${phoneNumber}: ${code}`);
    const isDev = env.ENVIRONMENT === "development";
    return new Response(JSON.stringify({
      success: true,
      message: "\u9A8C\u8BC1\u7801\u5DF2\u53D1\u9001",
      // 生产环境不返回验证码
      ...isDev && { debugCode: code }
    }), { status: 200 });
  } catch (e) {
    console.error("\u53D1\u9001\u9A8C\u8BC1\u7801\u5931\u8D25:", e);
    return new Response(JSON.stringify({
      success: false,
      error: "\u53D1\u9001\u9A8C\u8BC1\u7801\u5931\u8D25"
    }), { status: 500 });
  }
}
__name(handleSendSmsCode, "handleSendSmsCode");
async function handleSmsLogin(request, env, db) {
  try {
    const { phoneNumber, code } = await request.json();
    if (!phoneNumber || !code) {
      return new Response(JSON.stringify({
        success: false,
        error: "\u624B\u673A\u53F7\u548C\u9A8C\u8BC1\u7801\u4E0D\u80FD\u4E3A\u7A7A"
      }), { status: 400 });
    }
    const storedData = await env.USERS_KV.get(`sms_code_${phoneNumber}`);
    if (!storedData) {
      return new Response(JSON.stringify({
        success: false,
        error: "\u9A8C\u8BC1\u7801\u5DF2\u8FC7\u671F\uFF0C\u8BF7\u91CD\u65B0\u83B7\u53D6"
      }), { status: 400 });
    }
    const { code: storedCode, expiresAt, attempts = 0 } = JSON.parse(storedData);
    if (attempts >= 5) {
      await env.USERS_KV.delete(`sms_code_${phoneNumber}`);
      return new Response(JSON.stringify({
        success: false,
        error: "\u9A8C\u8BC1\u7801\u9519\u8BEF\u6B21\u6570\u8FC7\u591A\uFF0C\u8BF7\u91CD\u65B0\u83B7\u53D6"
      }), { status: 400 });
    }
    if (Date.now() > expiresAt) {
      await env.USERS_KV.delete(`sms_code_${phoneNumber}`);
      return new Response(JSON.stringify({
        success: false,
        error: "\u9A8C\u8BC1\u7801\u5DF2\u8FC7\u671F"
      }), { status: 400 });
    }
    if (code !== storedCode) {
      await env.USERS_KV.put(
        `sms_code_${phoneNumber}`,
        JSON.stringify({ code: storedCode, expiresAt, attempts: attempts + 1 }),
        { expirationTtl: Math.floor((expiresAt - Date.now()) / 1e3) }
      );
      return new Response(JSON.stringify({
        success: false,
        error: "\u9A8C\u8BC1\u7801\u9519\u8BEF"
      }), { status: 400 });
    }
    await env.USERS_KV.delete(`sms_code_${phoneNumber}`);
    let user = await db.getUserByPhone(phoneNumber);
    let isNewUser = false;
    if (!user) {
      isNewUser = true;
      const username = `user_${Date.now().toString(36)}`;
      const now = (/* @__PURE__ */ new Date()).toISOString();
      const trialEnd = new Date(Date.now() + 3 * 24 * 60 * 60 * 1e3).toISOString();
      await db.createPhoneUser({
        username,
        email: `${phoneNumber.replace("+", "")}@phone.user`,
        phoneNumber,
        firebaseUid: null,
        membershipType: "trial",
        freeTrialEndDate: trialEnd,
        createdAt: now
      });
      user = await db.getUserByPhone(phoneNumber);
    }
    const token = await generateJWT(user, env.JWT_SECRET);
    return new Response(JSON.stringify({
      success: true,
      token,
      username: user.username,
      isNewUser,
      user: {
        username: user.username,
        email: user.email,
        phoneNumber: user.phone_number,
        membership: {
          type: user.membership_type || "trial",
          expiresAt: user.membership_expires_at || user.free_trial_end_date
        }
      }
    }), { status: 200 });
  } catch (e) {
    console.error("\u9A8C\u8BC1\u7801\u767B\u5F55\u5931\u8D25:", e);
    return new Response(JSON.stringify({
      success: false,
      error: "\u767B\u5F55\u5931\u8D25: " + e.message
    }), { status: 500 });
  }
}
__name(handleSmsLogin, "handleSmsLogin");
async function generateJWT(user, secret) {
  const header = { alg: "HS256", typ: "JWT" };
  const payload = {
    sub: user.username,
    iat: Math.floor(Date.now() / 1e3),
    exp: Math.floor(Date.now() / 1e3) + 30 * 24 * 60 * 60,
    // 30天
    isAdmin: user.is_admin === 1
  };
  const base64Header = btoa(JSON.stringify(header)).replace(/=/g, "");
  const base64Payload = btoa(JSON.stringify(payload)).replace(/=/g, "");
  const dataToSign = `${base64Header}.${base64Payload}`;
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(dataToSign));
  const base64Signature = btoa(String.fromCharCode(...new Uint8Array(signature))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
  return `${dataToSign}.${base64Signature}`;
}
__name(generateJWT, "generateJWT");

// src/handlers/comments.js
init_auth_utils();
async function handleGetComments(request, env, db) {
  try {
    const url = new URL(request.url);
    const contentId = url.searchParams.get("contentId") || url.searchParams.get("videoId");
    const page = parseInt(url.searchParams.get("page") || "1");
    const pageSize = parseInt(url.searchParams.get("pageSize") || "20");
    const offset = (page - 1) * pageSize;
    if (!contentId) {
      return jsonResponse({ error: "\u5185\u5BB9ID\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
    }
    const comments = await db.db.prepare(`
      SELECT 
        c.id, c.content_id, c.username as user_id, c.content, c.created_at, c.parent_id, c.like_count, c.tag, c.main_practice,
        u.username, u.nickname, u.avatar
      FROM comments c
      LEFT JOIN users u ON c.username = u.username
      WHERE c.content_id = ?
      ORDER BY c.created_at DESC
      LIMIT ? OFFSET ?
    `).bind(contentId, pageSize, offset).all();
    const totalResult = await db.db.prepare(`
      SELECT COUNT(*) as count FROM comments WHERE content_id = ?
    `).bind(contentId).first();
    return jsonResponse({
      comments: comments.results,
      total: totalResult.count,
      page,
      pageSize
    });
  } catch (error) {
    console.error("\u83B7\u53D6\u8BC4\u8BBA\u5931\u8D25:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u8BC4\u8BBA\u5931\u8D25" }, 500);
  }
}
__name(handleGetComments, "handleGetComments");
async function handlePostComment(request, env, db) {
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
    const { videoId, contentId: requestContentId, content, parentId, tag, videoTitle, filePath, mainPractice } = await request.json();
    const contentId = requestContentId || filePath || videoId;
    if (!contentId || !content) {
      return jsonResponse({ error: "\u5185\u5BB9ID\u548C\u8BC4\u8BBA\u5185\u5BB9\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
    }
    const validTags = ["ganying", "fayuan", "practice", null];
    if (tag && !validTags.includes(tag)) {
      return jsonResponse({ error: "\u65E0\u6548\u7684\u6807\u7B7E\u7C7B\u578B" }, 400);
    }
    const now = (/* @__PURE__ */ new Date()).toISOString();
    const result = await db.db.prepare(`
      INSERT INTO comments (content_id, video_id, username, user_id, content, created_at, parent_id, tag, content_title, main_practice, sync_version)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
    `).bind(contentId, contentId, tokenData.username, tokenData.username, content, now, parentId || null, tag || null, videoTitle || null, mainPractice || null).run();
    await db.db.prepare(`
            INSERT INTO content_metadata (content_id, content_type, title, file_path, like_count, comment_count)
            VALUES (?, 'text', ?, ?, 0, 1)
            ON CONFLICT(content_id) DO UPDATE SET 
              title = COALESCE(excluded.title, title),
              file_path = COALESCE(excluded.file_path, file_path),
              comment_count = comment_count + 1
        `).bind(contentId, videoTitle || null, filePath || null).run();
    const newComment = await db.db.prepare(`
      SELECT 
        c.id, c.content_id, c.username as user_id, c.content, c.created_at, c.parent_id, c.like_count, c.tag, c.content_title, c.main_practice,
        u.username, u.nickname, u.avatar
      FROM comments c
      LEFT JOIN users u ON c.username = u.username
      WHERE c.id = ?
    `).bind(result.meta.last_row_id).first();
    return jsonResponse({
      message: "\u8BC4\u8BBA\u53D1\u5E03\u6210\u529F",
      comment: newComment
    }, 201);
  } catch (error) {
    console.error("\u53D1\u5E03\u8BC4\u8BBA\u5931\u8D25:", error);
    return jsonResponse({ error: "\u53D1\u5E03\u8BC4\u8BBA\u5931\u8D25: " + error.message }, 500);
  }
}
__name(handlePostComment, "handlePostComment");
async function handleDeleteComment(request, env, db) {
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
    const url = new URL(request.url);
    const commentId = url.searchParams.get("id");
    if (!commentId) {
      return jsonResponse({ error: "\u8BC4\u8BBAID\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
    }
    const comment = await db.db.prepare(`
      SELECT username FROM comments WHERE id = ?
    `).bind(commentId).first();
    if (!comment) {
      return jsonResponse({ error: "\u8BC4\u8BBA\u4E0D\u5B58\u5728" }, 404);
    }
    if (comment.username !== tokenData.username) {
      return jsonResponse({ error: "\u65E0\u6743\u5220\u9664\u6B64\u8BC4\u8BBA" }, 403);
    }
    await db.db.prepare(`
      DELETE FROM comments WHERE id = ?
    `).bind(commentId).run();
    return jsonResponse({ message: "\u8BC4\u8BBA\u5DF2\u5220\u9664" });
  } catch (error) {
    console.error("\u5220\u9664\u8BC4\u8BBA\u5931\u8D25:", error);
    return jsonResponse({ error: "\u5220\u9664\u8BC4\u8BBA\u5931\u8D25" }, 500);
  }
}
__name(handleDeleteComment, "handleDeleteComment");
async function handleGetTaggedPosts(request, env, db) {
  try {
    const url = new URL(request.url);
    const tag = url.searchParams.get("tag");
    const page = parseInt(url.searchParams.get("page") || "1");
    const pageSize = parseInt(url.searchParams.get("pageSize") || "20");
    const offset = (page - 1) * pageSize;
    if (!tag || !["ganying", "fayuan"].includes(tag)) {
      return jsonResponse({ error: "\u6807\u7B7E\u7C7B\u578B\u65E0\u6548\uFF0C\u5FC5\u987B\u662F ganying \u6216 fayuan" }, 400);
    }
    const posts = await db.db.prepare(`
      SELECT 
        c.id, c.content_id, c.username as user_id, c.content, c.created_at, c.tag, c.like_count, c.content_title,
        u.username, u.nickname, u.avatar
      FROM comments c
      LEFT JOIN users u ON c.username = u.username
      WHERE c.tag = ?
      ORDER BY c.created_at DESC
      LIMIT ? OFFSET ?
    `).bind(tag, pageSize, offset).all();
    const postsWithTitle = posts.results.map((post) => {
      if (post.content_title && post.content_title.trim()) {
        return post;
      }
      let contentTitle = "";
      if (post.content_id) {
        const parts = post.content_id.split("/");
        const filename = parts[parts.length - 1];
        contentTitle = filename.replace(/\.[^/.]+$/, "");
        contentTitle = contentTitle.replace(/[_-]/g, " ");
      }
      return { ...post, content_title: contentTitle };
    });
    const totalResult = await db.db.prepare(`
      SELECT COUNT(*) as count FROM comments WHERE tag = ?
    `).bind(tag).first();
    return jsonResponse({
      posts: postsWithTitle,
      total: totalResult.count,
      page,
      pageSize
    });
  } catch (error) {
    console.error("\u83B7\u53D6\u5E16\u5B50\u5217\u8868\u5931\u8D25:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u5E16\u5B50\u5217\u8868\u5931\u8D25" }, 500);
  }
}
__name(handleGetTaggedPosts, "handleGetTaggedPosts");
async function handleGetHotFeed(request, env, db) {
  try {
    const url = new URL(request.url);
    const page = parseInt(url.searchParams.get("page") || "1");
    const pageSize = parseInt(url.searchParams.get("pageSize") || "20");
    const offset = (page - 1) * pageSize;
    const hotContent = await db.db.prepare(`
          SELECT 
            content_id as id,
            content_type,
            title,
            file_path,
            like_count,
            comment_count
          FROM content_metadata
          WHERE like_count > 0 OR comment_count > 0
          ORDER BY like_count DESC, comment_count DESC
          LIMIT ? OFFSET ?
        `).bind(pageSize, offset).all();
    const totalResult = await db.db.prepare(`
          SELECT COUNT(*) as count FROM content_metadata WHERE like_count > 0 OR comment_count > 0
        `).first();
    return jsonResponse({
      hotContent: hotContent.results,
      total: totalResult.count,
      page,
      pageSize
    });
  } catch (error) {
    console.error("\u83B7\u53D6\u70ED\u95E8\u5185\u5BB9\u5931\u8D25:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u70ED\u95E8\u5185\u5BB9\u5931\u8D25" }, 500);
  }
}
__name(handleGetHotFeed, "handleGetHotFeed");
async function handleGetPostDetail(request, env, db) {
  try {
    const url = new URL(request.url);
    const postId = url.searchParams.get("id");
    if (!postId) {
      return jsonResponse({ error: "\u5E16\u5B50ID\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
    }
    const post = await db.db.prepare(`
      SELECT 
        c.id, c.content_id, c.username as user_id, c.content, c.created_at, c.tag, c.like_count,
        u.username, u.nickname, u.avatar
      FROM comments c
      LEFT JOIN users u ON c.username = u.username
      WHERE c.id = ? AND c.tag IS NOT NULL
    `).bind(postId).first();
    if (!post) {
      return jsonResponse({ error: "\u5E16\u5B50\u4E0D\u5B58\u5728" }, 404);
    }
    return jsonResponse({ post });
  } catch (error) {
    console.error("\u83B7\u53D6\u5E16\u5B50\u8BE6\u60C5\u5931\u8D25:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u5E16\u5B50\u8BE6\u60C5\u5931\u8D25" }, 500);
  }
}
__name(handleGetPostDetail, "handleGetPostDetail");
async function handleBatchGetCommentCounts(request, env, db) {
  try {
    const { videoIds } = await request.json();
    if (!videoIds || !Array.isArray(videoIds) || videoIds.length === 0) {
      return jsonResponse({ error: "\u89C6\u9891ID\u5217\u8868\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
    }
    const limitedIds = videoIds.slice(0, 100);
    const placeholders = limitedIds.map(() => "?").join(",");
    const results = await db.db.prepare(`
            SELECT content_id, COUNT(*) as comment_count
            FROM comments
            WHERE content_id IN (${placeholders})
            GROUP BY content_id
        `).bind(...limitedIds).all();
    const counts = {};
    for (const row of results.results) {
      counts[row.content_id] = row.comment_count;
    }
    for (const id of limitedIds) {
      if (!(id in counts)) {
        counts[id] = 0;
      }
    }
    return jsonResponse({ counts });
  } catch (error) {
    console.error("\u6279\u91CF\u83B7\u53D6\u8BC4\u8BBA\u6570\u5931\u8D25:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u8BC4\u8BBA\u6570\u5931\u8D25" }, 500);
  }
}
__name(handleBatchGetCommentCounts, "handleBatchGetCommentCounts");

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
async function handleMobileAlipayCallback2(request, env) {
  const { handleMobileAlipayCallback: handleMobileAlipayCallback3 } = await Promise.resolve().then(() => (init_alipay_login_functions(), alipay_login_functions_exports));
  return await handleMobileAlipayCallback3(request, env);
}
__name(handleMobileAlipayCallback2, "handleMobileAlipayCallback");
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
async function handleGetAlipayAuthString2(request, env) {
  const { handleGetAlipayAuthString: handleGetAlipayAuthString3 } = await Promise.resolve().then(() => (init_alipay_login_functions(), alipay_login_functions_exports));
  return await handleGetAlipayAuthString3(request, env);
}
__name(handleGetAlipayAuthString2, "handleGetAlipayAuthString");
async function handleAlipaySDKLogin2(request, env) {
  const { handleAlipaySDKLogin: handleAlipaySDKLogin3 } = await Promise.resolve().then(() => (init_alipay_login_functions(), alipay_login_functions_exports));
  return await handleAlipaySDKLogin3(request, env);
}
__name(handleAlipaySDKLogin2, "handleAlipaySDKLogin");

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
init_alipay_utils();
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
  const { plan = "monthly", platform = "app" } = await request.json();
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
  const outTradeNo = platform === "web" ? `WEB_${tokenData.username}_${Date.now()}` : `MEMBER_${tokenData.username}_${Date.now()}`;
  await db.createOrder({
    orderId: outTradeNo,
    userId: tokenData.username,
    plan,
    amount: finalAmount,
    originalAmount: planDetails.price,
    isAdminOrder: isAdminUser,
    status: "PENDING",
    platform: platform || "app",
    createdAt: (/* @__PURE__ */ new Date()).toISOString()
  });
  if (platform === "web") {
    const now2 = /* @__PURE__ */ new Date();
    const timestamp2 = `${now2.getFullYear()}-${String(now2.getMonth() + 1).padStart(2, "0")}-${String(now2.getDate()).padStart(2, "0")} ${String(now2.getHours()).padStart(2, "0")}:${String(now2.getMinutes()).padStart(2, "0")}:${String(now2.getSeconds()).padStart(2, "0")}`;
    const bizContent = {
      out_trade_no: outTradeNo,
      total_amount: finalAmount,
      subject: `\u5168\u7403\u6CD5\u5E03\u65BD - ${planDetails.name}`,
      product_code: "FAST_INSTANT_TRADE_PAY",
      timeout_express: "30m",
      quit_url: env.WORKER_URL || "https://flutter.ombhrum.com"
    };
    const params = {
      app_id: env.ALIPAY_APP_ID,
      method: "alipay.trade.page.pay",
      format: "JSON",
      charset: "utf-8",
      sign_type: "RSA2",
      timestamp: timestamp2,
      version: "1.0",
      notify_url: `${env.WORKER_URL || "https://flutter.ombhrum.com"}/api/alipay/notify`,
      return_url: `${env.WORKER_URL || "https://flutter.ombhrum.com"}/payment-success.html`,
      biz_content: JSON.stringify(bizContent)
    };
    const privateKey2 = await importPrivateKey(env.ALIPAY_PRIVATE_KEY);
    params.sign = await generateSign(params, privateKey2);
    const gateway = env.ALIPAY_SANDBOX === "true" ? "https://openapi-sandbox.dl.alipaydev.com/gateway.do" : "https://openapi.alipay.com/gateway.do";
    const queryString = new URLSearchParams(params).toString();
    const paymentUrl = `${gateway}?${queryString}`;
    return jsonResponse({
      success: true,
      orderId: outTradeNo,
      amount: finalAmount,
      plan,
      paymentUrl
    });
  }
  const now = /* @__PURE__ */ new Date();
  const timestamp = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")} ${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}:${String(now.getSeconds()).padStart(2, "0")}`;
  const appBizContent = {
    out_trade_no: outTradeNo,
    total_amount: finalAmount.toString(),
    subject: `\u5168\u7403\u6CD5\u5E03\u65BD - ${planDetails.name}`,
    product_code: "QUICK_MSECURITY_PAY",
    timeout_express: "30m"
  };
  const appParams = {
    app_id: env.ALIPAY_APP_ID,
    method: "alipay.trade.app.pay",
    format: "JSON",
    charset: "utf-8",
    sign_type: "RSA2",
    timestamp,
    version: "1.0",
    notify_url: `${env.WORKER_URL || "https://flutter.ombhrum.com"}/api/alipay/notify`,
    biz_content: JSON.stringify(appBizContent)
  };
  const privateKey = await importPrivateKey(env.ALIPAY_PRIVATE_KEY);
  appParams.sign = await generateSign(appParams, privateKey);
  const orderString = Object.keys(appParams).sort().map((key) => `${key}=${encodeURIComponent(appParams[key])}`).join("&");
  return jsonResponse({
    success: true,
    orderId: outTradeNo,
    amount: finalAmount,
    plan,
    orderString
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

// src/handlers/membership.js
init_auth_utils();
async function handleCheckMembershipStatus(request, env, db) {
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
  const now = /* @__PURE__ */ new Date();
  const membershipExpiry = user.membership_expires_at ? new Date(user.membership_expires_at) : null;
  const isActive = membershipExpiry && membershipExpiry > now;
  const daysLeft = isActive ? Math.ceil((membershipExpiry - now) / (1e3 * 60 * 60 * 24)) : 0;
  return jsonResponse({
    username: user.username,
    email: user.email,
    membership: {
      isActive,
      type: user.membership_type || "free",
      expiresAt: user.membership_expires_at,
      daysLeft
    },
    hasStripeCustomer: false
    // 暂时设为false，因为使用支付宝
  });
}
__name(handleCheckMembershipStatus, "handleCheckMembershipStatus");
async function handleCheckAlipayMembership(request, env, db) {
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
  const now = /* @__PURE__ */ new Date();
  const membershipExpiry = user.membership_expires_at ? new Date(user.membership_expires_at) : null;
  const isActive = membershipExpiry && membershipExpiry > now;
  const daysLeft = isActive ? Math.ceil((membershipExpiry - now) / (1e3 * 60 * 60 * 24)) : 0;
  return jsonResponse({
    username: user.username,
    email: user.email,
    membership: {
      isActive,
      type: user.membership_type || "free",
      expiresAt: user.membership_expires_at,
      daysLeft
    },
    hasStripeCustomer: false
  });
}
__name(handleCheckAlipayMembership, "handleCheckAlipayMembership");

// src/handlers/migration.js
init_auth_utils();
async function handleMigrateKvToD1(request, env, db) {
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
    return jsonResponse({ error: "\u6743\u9650\u4E0D\u8DB3\uFF0C\u9700\u8981\u7BA1\u7406\u5458\u6743\u9650" }, 403);
  }
  const results = {
    users: { migrated: 0, errors: [] },
    purchases: { migrated: 0, errors: [] },
    redeems: { migrated: 0, errors: [] },
    memberships: { migrated: 0, errors: [] }
  };
  try {
    console.log("\u5F00\u59CB\u5B8C\u6574\u6570\u636E\u8FC1\u79FB...");
    await migrateUsers(env, db, results);
    await migratePurchases(env, db, results);
    await migrateRedeems(env, db, results);
    await migrateMemberships(env, db, results);
    console.log("\u8FC1\u79FB\u5B8C\u6210:", results);
    return jsonResponse({
      success: true,
      message: "\u6570\u636E\u8FC1\u79FB\u5B8C\u6210",
      results
    });
  } catch (error) {
    console.error("\u8FC1\u79FB\u5931\u8D25:", error);
    return jsonResponse({
      success: false,
      error: error.message,
      results
    }, 500);
  }
}
__name(handleMigrateKvToD1, "handleMigrateKvToD1");
async function migrateUsers(env, db, results) {
  console.log("\u5F00\u59CB\u8FC1\u79FB\u7528\u6237\u6570\u636E...");
  const usersList = await env.USERS_KV.list();
  for (const key of usersList.keys) {
    try {
      const userData = await env.USERS_KV.get(key.name, "json");
      if (!userData) continue;
      const existingUser = await db.db.prepare(
        "SELECT username FROM users WHERE username = ?"
      ).bind(userData.username).first();
      if (existingUser) {
        await db.db.prepare(`
          UPDATE users SET 
            email = ?, password_hash = ?, salt = ?, iterations = ?, algo = ?,
            email_verified = ?, membership_type = ?, membership_expires_at = ?,
            free_trial_end_date = ?, stripe_customer_id = ?, subscription_id = ?,
            wechat_openid = ?, wechat_nickname = ?, wechat_headimgurl = ?, wechat_bound_at = ?,
            alipay_user_id = ?, alipay_nickname = ?, alipay_bound_at = ?,
            total_transferred_bytes = ?, last_transfer_at = ?, updated_at = ?
          WHERE username = ?
        `).bind(
          userData.email,
          userData.passwordHash,
          userData.salt,
          userData.iterations,
          userData.algo,
          userData.emailVerified ? 1 : 0,
          userData.membershipType || "trial",
          userData.membershipExpiresAt,
          userData.freeTrialEndDate,
          userData.stripeCustomerId,
          userData.subscriptionId,
          userData.wechatOpenid,
          userData.wechatNickname,
          userData.wechatHeadimgurl,
          userData.wechatBoundAt,
          userData.alipayUserId,
          userData.alipayNickname,
          userData.alipayBoundAt,
          userData.totalTransferredBytes || 0,
          userData.lastTransferAt,
          (/* @__PURE__ */ new Date()).toISOString(),
          userData.username
        ).run();
      } else {
        await db.db.prepare(`
          INSERT INTO users (
            username, email, password_hash, salt, iterations, algo, email_verified,
            membership_type, membership_expires_at, free_trial_end_date,
            stripe_customer_id, subscription_id, wechat_openid, wechat_nickname, 
            wechat_headimgurl, wechat_bound_at, alipay_user_id, alipay_nickname, 
            alipay_bound_at, total_transferred_bytes, last_transfer_at, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).bind(
          userData.username,
          userData.email,
          userData.passwordHash,
          userData.salt,
          userData.iterations,
          userData.algo,
          userData.emailVerified ? 1 : 0,
          userData.membershipType || "trial",
          userData.membershipExpiresAt,
          userData.freeTrialEndDate,
          userData.stripeCustomerId,
          userData.subscriptionId,
          userData.wechatOpenid,
          userData.wechatNickname,
          userData.wechatHeadimgurl,
          userData.wechatBoundAt,
          userData.alipayUserId,
          userData.alipayNickname,
          userData.alipayBoundAt,
          userData.totalTransferredBytes || 0,
          userData.lastTransferAt,
          userData.createdAt || (/* @__PURE__ */ new Date()).toISOString()
        ).run();
        await db.db.prepare(
          "INSERT OR REPLACE INTO email_username_mapping (email, username) VALUES (?, ?)"
        ).bind(userData.email, userData.username).run();
      }
      results.users.migrated++;
      console.log(`\u7528\u6237 ${userData.username} \u8FC1\u79FB\u6210\u529F`);
    } catch (error) {
      console.error(`\u7528\u6237 ${key.name} \u8FC1\u79FB\u5931\u8D25:`, error);
      results.users.errors.push({ key: key.name, error: error.message });
    }
  }
}
__name(migrateUsers, "migrateUsers");
async function migratePurchases(env, db, results) {
  console.log("\u5F00\u59CB\u8FC1\u79FB\u8D2D\u4E70\u8BB0\u5F55...");
  const ordersList = await env.ORDERS_KV.list();
  for (const key of ordersList.keys) {
    try {
      const orderData = await env.ORDERS_KV.get(key.name, "json");
      if (!orderData) continue;
      const existing = await db.db.prepare(
        "SELECT id FROM purchase_history WHERE order_id = ?"
      ).bind(key.name).first();
      if (!existing) {
        await db.db.prepare(`
          INSERT INTO purchase_history (
            username, order_id, plan, amount, currency, status, payment_method,
            purchased_at, valid_from, valid_to
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).bind(
          orderData.userId || orderData.username,
          key.name,
          orderData.plan || "monthly",
          orderData.amount || "21.00",
          orderData.currency || "CNY",
          orderData.status || "completed",
          orderData.paymentMethod || "alipay",
          orderData.createdAt || orderData.purchasedAt || (/* @__PURE__ */ new Date()).toISOString(),
          orderData.validFrom || (/* @__PURE__ */ new Date()).toISOString(),
          orderData.validTo || new Date(Date.now() + 30 * 24 * 60 * 60 * 1e3).toISOString()
        ).run();
        results.purchases.migrated++;
        console.log(`\u8D2D\u4E70\u8BB0\u5F55 ${key.name} \u8FC1\u79FB\u6210\u529F`);
      }
    } catch (error) {
      console.error(`\u8D2D\u4E70\u8BB0\u5F55 ${key.name} \u8FC1\u79FB\u5931\u8D25:`, error);
      results.purchases.errors.push({ key: key.name, error: error.message });
    }
  }
}
__name(migratePurchases, "migratePurchases");
async function migrateRedeems(env, db, results) {
  console.log("\u5F00\u59CB\u8FC1\u79FB\u5151\u6362\u8BB0\u5F55...");
  const redeemsList = await env.REDEEM_CODES_KV.list();
  for (const key of redeemsList.keys) {
    try {
      const redeemData = await env.REDEEM_CODES_KV.get(key.name, "json");
      if (!redeemData) continue;
      if (redeemData.used && redeemData.usedBy) {
        const existing = await db.db.prepare(
          "SELECT id FROM redeem_history WHERE code = ? AND username = ?"
        ).bind(key.name, redeemData.usedBy).first();
        if (!existing) {
          await db.db.prepare(`
            INSERT INTO redeem_history (
              username, code, type, days, redeemed_at, valid_from, valid_to, previous_expiry_date
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          `).bind(
            redeemData.usedBy,
            key.name,
            redeemData.type || "premium",
            redeemData.days || 30,
            redeemData.usedAt || (/* @__PURE__ */ new Date()).toISOString(),
            redeemData.validFrom || (/* @__PURE__ */ new Date()).toISOString(),
            redeemData.validTo || new Date(Date.now() + (redeemData.days || 30) * 24 * 60 * 60 * 1e3).toISOString(),
            redeemData.previousExpiryDate
          ).run();
          results.redeems.migrated++;
          console.log(`\u5151\u6362\u8BB0\u5F55 ${key.name} \u8FC1\u79FB\u6210\u529F`);
        }
      }
    } catch (error) {
      console.error(`\u5151\u6362\u8BB0\u5F55 ${key.name} \u8FC1\u79FB\u5931\u8D25:`, error);
      results.redeems.errors.push({ key: key.name, error: error.message });
    }
  }
}
__name(migrateRedeems, "migrateRedeems");
async function migrateMemberships(env, db, results) {
  console.log("\u5F00\u59CB\u8FC1\u79FB\u4F1A\u5458\u6570\u636E...");
  const membershipsList = await env.MEMBERSHIP_KV.list();
  for (const key of membershipsList.keys) {
    try {
      const membershipData = await env.MEMBERSHIP_KV.get(key.name, "json");
      if (!membershipData) continue;
      const username = key.name.replace("membership_", "");
      await db.db.prepare(`
        UPDATE users SET 
          membership_type = ?, 
          membership_expires_at = ?,
          updated_at = ?
        WHERE username = ?
      `).bind(
        membershipData.type || "paid",
        membershipData.expiresAt,
        (/* @__PURE__ */ new Date()).toISOString(),
        username
      ).run();
      results.memberships.migrated++;
      console.log(`\u4F1A\u5458\u6570\u636E ${username} \u8FC1\u79FB\u6210\u529F`);
    } catch (error) {
      console.error(`\u4F1A\u5458\u6570\u636E ${key.name} \u8FC1\u79FB\u5931\u8D25:`, error);
      results.memberships.errors.push({ key: key.name, error: error.message });
    }
  }
}
__name(migrateMemberships, "migrateMemberships");

// src/handlers/admin.js
init_auth_utils();
async function handleCheckAdminStatus(request, env, db) {
  console.log("\u{1F50D} handleCheckAdminStatus \u88AB\u8C03\u7528");
  const authHeader = request.headers.get("Authorization");
  console.log("\u{1F4CB} Authorization header:", authHeader ? authHeader.substring(0, 30) + "..." : "null");
  if (!authHeader?.startsWith("Bearer ")) {
    console.log("\u274C \u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F");
    return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
  }
  const token = authHeader.substring(7);
  console.log("\u{1F511} Token preview:", token.substring(0, 30) + "...");
  console.log("\u{1F510} JWT_SECRET \u72B6\u6001:", env.JWT_SECRET ? "\u5DF2\u914D\u7F6E" : "\u672A\u914D\u7F6E\uFF08\u5C06\u4F7F\u7528\u9ED8\u8BA4\u503C\uFF09");
  const tokenData = await verifyToken(token, env);
  console.log("\u2705 Token \u9A8C\u8BC1\u7ED3\u679C:", tokenData ? "\u6210\u529F" : "\u5931\u8D25");
  if (!tokenData) {
    console.log("\u274C Token \u9A8C\u8BC1\u5931\u8D25\uFF0C\u8FD4\u56DE 401");
    return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
  }
  const user = await db.getUser(tokenData.username);
  if (!user) return jsonResponse({ error: "\u7528\u6237\u4E0D\u5B58\u5728" }, 404);
  return jsonResponse({
    isAdmin: isAdmin(user.email),
    email: user.email,
    username: user.username,
    nickname: user.nickname || null,
    avatar: user.avatar || null,
    membershipType: user.membership_type || "expired",
    membershipExpiresAt: user.membership_expires_at
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
async function handleSearch(request, env, db) {
  try {
    const url = new URL(request.url);
    const query2 = url.searchParams.get("q") || "";
    const category = url.searchParams.get("category");
    const limit = parseInt(url.searchParams.get("limit") || "50");
    const offset = parseInt(url.searchParams.get("offset") || "0");
    if (!query2) {
      return jsonResponse({ query: "", total: 0, results: [] });
    }
    let sql = `
      SELECT 
        f.id, f.title, 
        tc.file_path, tc.category,
        snippet(text_contents_fts, 1, '<b>', '</b>', '...', 64) as snippet
      FROM text_contents_fts f
      JOIN text_contents tc ON f.rowid = tc.id
      WHERE text_contents_fts MATCH ?
    `;
    const params = [query2];
    if (category) {
      sql += " AND tc.category = ?";
      params.push(category);
    }
    sql += " ORDER BY rank";
    sql += " LIMIT ? OFFSET ?";
    params.push(limit, offset);
    const { results } = await db.prepare(sql).bind(...params).all();
    const formattedResults = results.map((row) => {
      return {
        id: row.file_path,
        title: row.title,
        path: row.file_path,
        category: row.category,
        preview: row.snippet,
        titleMatch: false
        // FTS5 已经自动处理了排名
      };
    });
    let countSql = "SELECT COUNT(*) as total FROM text_contents_fts WHERE text_contents_fts MATCH ?";
    const countParams = [query2];
    if (category) {
      countSql = `
        SELECT COUNT(*) as total 
        FROM text_contents_fts f
        JOIN text_contents tc ON f.rowid = tc.id
        WHERE text_contents_fts MATCH ? AND tc.category = ?
      `;
      countParams.push(category);
    }
    const { total } = await db.prepare(countSql).bind(...countParams).first();
    return jsonResponse({
      query: query2,
      category: category || "all",
      total: total || 0,
      limit,
      offset,
      results: formattedResults
    });
  } catch (error) {
    console.error("Search error:", error);
    return jsonResponse({
      error: error.message,
      query: query || "",
      total: 0,
      results: []
    }, 500);
  }
}
__name(handleSearch, "handleSearch");
async function handleGetTextContent(request, env, db) {
  try {
    const url = new URL(request.url);
    const path = url.searchParams.get("path");
    if (!path) {
      return jsonResponse({ error: "\u7F3A\u5C11path\u53C2\u6570" }, 400);
    }
    const result = await db.prepare("SELECT title, content, file_path, category FROM text_contents WHERE file_path = ?").bind(path).first();
    if (!result) {
      return jsonResponse({ error: "\u672A\u627E\u5230\u5185\u5BB9" }, 404);
    }
    return jsonResponse({
      title: result.title,
      content: result.content,
      path: result.file_path,
      category: result.category
    });
  } catch (error) {
    console.error("Get text content error:", error);
    return jsonResponse({ error: error.message }, 500);
  }
}
__name(handleGetTextContent, "handleGetTextContent");
async function handleGetCategories(request, env, db) {
  try {
    const { results } = await db.prepare("SELECT DISTINCT category, COUNT(*) as count FROM text_contents GROUP BY category").all();
    return jsonResponse({
      categories: results.map((r) => ({
        name: r.category,
        count: r.count
      }))
    });
  } catch (error) {
    console.error("Get categories error:", error);
    return jsonResponse({ error: error.message }, 500);
  }
}
__name(handleGetCategories, "handleGetCategories");

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

// src/handlers/likes.js
init_auth_utils();
async function handleToggleLike(request, env, db) {
  try {
    const authHeader = request.headers.get("Authorization");
    const token = authHeader?.replace("Bearer ", "");
    let userId = null;
    if (token) {
      const decoded = await verifyToken(token, env);
      userId = decoded?.username || null;
    }
    const { contentId, contentType, action, title, filePath } = await request.json();
    if (!contentId || !contentType) {
      return jsonResponse({ error: "\u7F3A\u5C11\u5FC5\u8981\u53C2\u6570" }, 400);
    }
    if (action === "like") {
      await db.prepare(
        "INSERT OR IGNORE INTO content_likes (content_id, content_type, username, title, file_path, created_at, sync_version) VALUES (?, ?, ?, ?, ?, ?, 1)"
      ).bind(contentId, contentType, userId, title || null, filePath || null, (/* @__PURE__ */ new Date()).toISOString()).run();
      await db.prepare(`
                INSERT INTO content_metadata (content_id, content_type, title, file_path, like_count, comment_count)
                VALUES (?, ?, ?, ?, 1, 0)
                ON CONFLICT(content_id) DO UPDATE SET 
                  title = COALESCE(excluded.title, title),
                  file_path = COALESCE(excluded.file_path, file_path),
                  like_count = like_count + 1
            `).bind(contentId, contentType, title || null, filePath || null).run();
    } else if (action === "unlike") {
      if (userId) {
        await db.prepare("DELETE FROM content_likes WHERE content_id = ? AND username = ?").bind(contentId, userId).run();
      } else {
        await db.prepare("DELETE FROM content_likes WHERE content_id = ? AND username IS NULL").bind(contentId).run();
      }
      await db.prepare(`
                UPDATE content_metadata SET like_count = MAX(0, like_count - 1) WHERE content_id = ?
            `).bind(contentId).run();
    }
    const result = await db.prepare(
      "SELECT COUNT(*) as count FROM content_likes WHERE content_id = ?"
    ).bind(contentId).first();
    return jsonResponse({ success: true, likeCount: result.count });
  } catch (error) {
    console.error("Toggle like error:", error);
    return jsonResponse({ error: "\u64CD\u4F5C\u5931\u8D25" }, 500);
  }
}
__name(handleToggleLike, "handleToggleLike");
async function handleGetLikeCount(request, env, db) {
  try {
    const url = new URL(request.url);
    const contentId = url.searchParams.get("contentId");
    if (!contentId) {
      return jsonResponse({ error: "\u7F3A\u5C11contentId\u53C2\u6570" }, 400);
    }
    const result = await db.prepare(
      "SELECT COUNT(*) as count FROM content_likes WHERE content_id = ?"
    ).bind(contentId).first();
    return jsonResponse({ likeCount: result.count || 0 });
  } catch (error) {
    console.error("Get like count error:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u5931\u8D25" }, 500);
  }
}
__name(handleGetLikeCount, "handleGetLikeCount");
async function handleBatchGetLikeCounts(request, env, db) {
  try {
    const { contentIds } = await request.json();
    if (!contentIds || !Array.isArray(contentIds)) {
      return jsonResponse({ error: "\u7F3A\u5C11contentIds\u53C2\u6570" }, 400);
    }
    const placeholders = contentIds.map(() => "?").join(",");
    const results = await db.prepare(
      `SELECT content_id, COUNT(*) as count FROM content_likes WHERE content_id IN (${placeholders}) GROUP BY content_id`
    ).bind(...contentIds).all();
    const likeCounts = {};
    results.results.forEach((row) => {
      likeCounts[row.content_id] = row.count;
    });
    return jsonResponse({ likeCounts });
  } catch (error) {
    console.error("Batch get like counts error:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u5931\u8D25" }, 500);
  }
}
__name(handleBatchGetLikeCounts, "handleBatchGetLikeCounts");
async function handleGetMyLikes(request, env, db) {
  try {
    const authHeader = request.headers.get("Authorization");
    const token = authHeader?.replace("Bearer ", "");
    if (!token) {
      return jsonResponse({ error: "\u672A\u767B\u5F55" }, 401);
    }
    const decoded = await verifyToken(token, env);
    if (!decoded?.username) {
      return jsonResponse({ error: "\u65E0\u6548\u7684token" }, 401);
    }
    const results = await db.prepare(
      "SELECT content_id as id, content_type as contentType, title, file_path as filePath, created_at as likedAt FROM content_likes WHERE username = ? ORDER BY created_at DESC"
    ).bind(decoded.username).all();
    return jsonResponse({ success: true, likes: results.results });
  } catch (error) {
    console.error("Get my likes error:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u5931\u8D25" }, 500);
  }
}
__name(handleGetMyLikes, "handleGetMyLikes");
async function handleGetReceivedLikeCount(request, env, db) {
  try {
    const authHeader = request.headers.get("Authorization");
    const token = authHeader?.replace("Bearer ", "");
    if (!token) {
      return jsonResponse({ error: "\u672A\u767B\u5F55" }, 401);
    }
    const decoded = await verifyToken(token, env);
    if (!decoded?.username) {
      return jsonResponse({ error: "\u65E0\u6548\u7684token" }, 401);
    }
    const result = await db.prepare(
      "SELECT COALESCE(SUM(like_count), 0) as totalLikes FROM comments WHERE username = ?"
    ).bind(decoded.username).first();
    return jsonResponse({
      success: true,
      receivedLikeCount: result?.totalLikes || 0
    });
  } catch (error) {
    console.error("Get received like count error:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u5931\u8D25" }, 500);
  }
}
__name(handleGetReceivedLikeCount, "handleGetReceivedLikeCount");

// src/handlers/favorites.js
init_auth_utils();
async function handleToggleFavorite(request, env, db) {
  try {
    const authHeader = request.headers.get("Authorization");
    const token = authHeader?.replace("Bearer ", "");
    if (!token) {
      return jsonResponse({ error: "\u672A\u767B\u5F55" }, 401);
    }
    const decoded = await verifyToken(token, env);
    if (!decoded?.username) {
      return jsonResponse({ error: "\u65E0\u6548\u7684token" }, 401);
    }
    const { contentId, contentType, action, title, filePath, description } = await request.json();
    if (!contentId || !contentType) {
      return jsonResponse({ error: "\u7F3A\u5C11\u5FC5\u8981\u53C2\u6570" }, 400);
    }
    if (action === "favorite") {
      await db.prepare(
        `INSERT OR IGNORE INTO content_favorites 
                 (content_id, content_type, username, title, file_path, description, created_at) 
                 VALUES (?, ?, ?, ?, ?, ?, ?)`
      ).bind(contentId, contentType, decoded.username, title || null, filePath || null, description || null, (/* @__PURE__ */ new Date()).toISOString()).run();
    } else if (action === "unfavorite") {
      await db.prepare(
        "DELETE FROM content_favorites WHERE content_id = ? AND username = ?"
      ).bind(contentId, decoded.username).run();
    }
    const result = await db.prepare(
      "SELECT COUNT(*) as count FROM content_favorites WHERE content_id = ? AND username = ?"
    ).bind(contentId, decoded.username).first();
    return jsonResponse({
      success: true,
      isFavorited: result.count > 0
    });
  } catch (error) {
    console.error("Toggle favorite error:", error);
    return jsonResponse({ error: "\u64CD\u4F5C\u5931\u8D25" }, 500);
  }
}
__name(handleToggleFavorite, "handleToggleFavorite");
async function handleGetMyFavorites(request, env, db) {
  try {
    const authHeader = request.headers.get("Authorization");
    const token = authHeader?.replace("Bearer ", "");
    if (!token) {
      return jsonResponse({ error: "\u672A\u767B\u5F55" }, 401);
    }
    const decoded = await verifyToken(token, env);
    if (!decoded?.username) {
      return jsonResponse({ error: "\u65E0\u6548\u7684token" }, 401);
    }
    const results = await db.prepare(
      `SELECT content_id as id, content_type as contentType, title, file_path as filePath, 
                    description, created_at as favoritedAt 
             FROM content_favorites 
             WHERE username = ? 
             ORDER BY created_at DESC`
    ).bind(decoded.username).all();
    return jsonResponse({ success: true, favorites: results.results });
  } catch (error) {
    console.error("Get my favorites error:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u5931\u8D25" }, 500);
  }
}
__name(handleGetMyFavorites, "handleGetMyFavorites");
async function handleBatchCheckFavorites(request, env, db) {
  try {
    const authHeader = request.headers.get("Authorization");
    const token = authHeader?.replace("Bearer ", "");
    let username = null;
    if (token) {
      const decoded = await verifyToken(token, env);
      username = decoded?.username || null;
    }
    if (!username) {
      return jsonResponse({ favoriteStatus: {} });
    }
    const { contentIds } = await request.json();
    if (!contentIds || !Array.isArray(contentIds) || contentIds.length === 0) {
      return jsonResponse({ favoriteStatus: {} });
    }
    const placeholders = contentIds.map(() => "?").join(",");
    const results = await db.prepare(
      `SELECT content_id FROM content_favorites WHERE username = ? AND content_id IN (${placeholders})`
    ).bind(username, ...contentIds).all();
    const favoriteStatus = {};
    contentIds.forEach((id) => {
      favoriteStatus[id] = results.results.some((r) => r.content_id === id);
    });
    return jsonResponse({ favoriteStatus });
  } catch (error) {
    console.error("Batch check favorites error:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u5931\u8D25" }, 500);
  }
}
__name(handleBatchCheckFavorites, "handleBatchCheckFavorites");

// src/handlers/content-stats.js
async function handleBatchGetContentStats(request, env, db) {
  try {
    const { contentIds } = await request.json();
    if (!contentIds || !Array.isArray(contentIds) || contentIds.length === 0) {
      return jsonResponse({ error: "\u5185\u5BB9ID\u5217\u8868\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
    }
    const limitedIds = contentIds.slice(0, 100);
    const placeholders = limitedIds.map(() => "?").join(",");
    const [likeResults, commentResults] = await Promise.all([
      // 查询点赞数
      db.db.prepare(`
                SELECT content_id, COUNT(*) as count
                FROM content_likes
                WHERE content_id IN (${placeholders})
                GROUP BY content_id
            `).bind(...limitedIds).all(),
      // 查询评论数
      db.db.prepare(`
                SELECT video_id, COUNT(*) as count
                FROM comments
                WHERE video_id IN (${placeholders})
                GROUP BY video_id
            `).bind(...limitedIds).all()
    ]);
    const stats = {};
    for (const id of limitedIds) {
      stats[id] = { likeCount: 0, commentCount: 0 };
    }
    for (const row of likeResults.results) {
      if (stats[row.content_id]) {
        stats[row.content_id].likeCount = row.count;
      }
    }
    for (const row of commentResults.results) {
      if (stats[row.video_id]) {
        stats[row.video_id].commentCount = row.count;
      }
    }
    return jsonResponse({ stats });
  } catch (error) {
    console.error("\u6279\u91CF\u83B7\u53D6\u5185\u5BB9\u7EDF\u8BA1\u5931\u8D25:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u7EDF\u8BA1\u5931\u8D25" }, 500);
  }
}
__name(handleBatchGetContentStats, "handleBatchGetContentStats");

// src/handlers/online.js
function getCounterInstance(env, activityType) {
  const id = env.ONLINE_COUNTER.idFromName(activityType);
  return env.ONLINE_COUNTER.get(id);
}
__name(getCounterInstance, "getCounterInstance");
async function handleOnlineJoin(request, env) {
  try {
    const { activityType, sessionId } = await request.json();
    if (!activityType || !sessionId) {
      return jsonResponse({ error: "activityType and sessionId required" }, 400);
    }
    if (!["global_sending", "zen_room"].includes(activityType)) {
      return jsonResponse({ error: "Invalid activityType" }, 400);
    }
    const counter = getCounterInstance(env, activityType);
    const url = new URL(request.url);
    url.searchParams.set("action", "join");
    const response = await counter.fetch(new Request(url.toString(), {
      method: "POST",
      body: JSON.stringify({ sessionId }),
      headers: { "Content-Type": "application/json" }
    }));
    return response;
  } catch (error) {
    console.error("handleOnlineJoin error:", error);
    return jsonResponse({ error: error.message }, 500);
  }
}
__name(handleOnlineJoin, "handleOnlineJoin");
async function handleOnlineHeartbeat(request, env) {
  try {
    const { activityType, sessionId } = await request.json();
    if (!activityType || !sessionId) {
      return jsonResponse({ error: "activityType and sessionId required" }, 400);
    }
    if (!["global_sending", "zen_room"].includes(activityType)) {
      return jsonResponse({ error: "Invalid activityType" }, 400);
    }
    const counter = getCounterInstance(env, activityType);
    const url = new URL(request.url);
    url.searchParams.set("action", "heartbeat");
    const response = await counter.fetch(new Request(url.toString(), {
      method: "POST",
      body: JSON.stringify({ sessionId }),
      headers: { "Content-Type": "application/json" }
    }));
    return response;
  } catch (error) {
    console.error("handleOnlineHeartbeat error:", error);
    return jsonResponse({ error: error.message }, 500);
  }
}
__name(handleOnlineHeartbeat, "handleOnlineHeartbeat");
async function handleOnlineLeave(request, env) {
  try {
    const { activityType, sessionId } = await request.json();
    if (!activityType || !sessionId) {
      return jsonResponse({ error: "activityType and sessionId required" }, 400);
    }
    if (!["global_sending", "zen_room"].includes(activityType)) {
      return jsonResponse({ error: "Invalid activityType" }, 400);
    }
    const counter = getCounterInstance(env, activityType);
    const url = new URL(request.url);
    url.searchParams.set("action", "leave");
    const response = await counter.fetch(new Request(url.toString(), {
      method: "POST",
      body: JSON.stringify({ sessionId }),
      headers: { "Content-Type": "application/json" }
    }));
    return response;
  } catch (error) {
    console.error("handleOnlineLeave error:", error);
    return jsonResponse({ error: error.message }, 500);
  }
}
__name(handleOnlineLeave, "handleOnlineLeave");
async function handleOnlineCount(request, env) {
  try {
    const url = new URL(request.url);
    const activityType = url.searchParams.get("activityType");
    if (!activityType) {
      return jsonResponse({ error: "activityType required" }, 400);
    }
    if (!["global_sending", "zen_room"].includes(activityType)) {
      return jsonResponse({ error: "Invalid activityType" }, 400);
    }
    const counter = getCounterInstance(env, activityType);
    const doUrl = new URL(request.url);
    doUrl.searchParams.set("action", "count");
    const response = await counter.fetch(new Request(doUrl.toString(), {
      method: "GET"
    }));
    return response;
  } catch (error) {
    console.error("handleOnlineCount error:", error);
    return jsonResponse({ error: error.message }, 500);
  }
}
__name(handleOnlineCount, "handleOnlineCount");

// src/handlers/meditation.js
async function authenticateUser(request, db) {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return { error: "\u672A\u6388\u6743\u8BBF\u95EE", status: 401 };
  }
  const token = authHeader.substring(7);
  try {
    const parts = token.split(".");
    if (parts.length !== 3) {
      return { error: "Token\u683C\u5F0F\u65E0\u6548", status: 401 };
    }
    const payload = JSON.parse(atob(parts[1]));
    const username = payload.username || payload.sub;
    if (!username) {
      return { error: "\u65E0\u6CD5\u83B7\u53D6\u7528\u6237\u4FE1\u606F", status: 401 };
    }
    return { username };
  } catch (e) {
    return { error: "Token\u89E3\u6790\u5931\u8D25", status: 401 };
  }
}
__name(authenticateUser, "authenticateUser");
async function handleSyncRecord(request, env, db) {
  const auth = await authenticateUser(request, db);
  if (auth.error) {
    return jsonResponse({ success: false, error: auth.error }, auth.status);
  }
  try {
    const body = await request.json();
    const { sutra, sutraSource = "custom", duration = 0, chantCount = 0, notes = "", isManual = false, recordDate } = body;
    if (!sutra) {
      return jsonResponse({ success: false, error: "\u529F\u8BFE\u540D\u79F0\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
    }
    const now = (/* @__PURE__ */ new Date()).toISOString();
    const date = recordDate || now.split("T")[0];
    await db.prepare(`
      INSERT INTO meditation_records (username, sutra_name, sutra_source, duration, chant_count, record_date, is_manual, notes, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).bind(auth.username, sutra, sutraSource, duration, chantCount, date, isManual ? 1 : 0, notes, now).run();
    await db.prepare(`
      UPDATE meditation_goals
      SET current_count = current_count + ?,
          updated_at = ?
      WHERE username = ? AND sutra_name = ? AND status = 'active'
    `).bind(chantCount, now, auth.username, sutra).run();
    return jsonResponse({ success: true, message: "\u4FEE\u884C\u8BB0\u5F55\u5DF2\u540C\u6B65" });
  } catch (e) {
    console.error("\u540C\u6B65\u4FEE\u884C\u8BB0\u5F55\u5931\u8D25:", e);
    return jsonResponse({ success: false, error: "\u540C\u6B65\u5931\u8D25: " + e.message }, 500);
  }
}
__name(handleSyncRecord, "handleSyncRecord");
async function handleGetRecords(request, env, db) {
  const auth = await authenticateUser(request, db);
  if (auth.error) {
    return jsonResponse({ success: false, error: auth.error }, auth.status);
  }
  try {
    const url = new URL(request.url);
    const limit = parseInt(url.searchParams.get("limit") || "50");
    const offset = parseInt(url.searchParams.get("offset") || "0");
    const sutra = url.searchParams.get("sutra");
    let query2 = `
      SELECT id, sutra_name, sutra_source, duration, chant_count, record_date, is_manual, notes, created_at
      FROM meditation_records
      WHERE username = ?
    `;
    const params = [auth.username];
    if (sutra) {
      query2 += ` AND sutra_name = ?`;
      params.push(sutra);
    }
    query2 += ` ORDER BY record_date DESC, created_at DESC LIMIT ? OFFSET ?`;
    params.push(limit, offset);
    const result = await db.prepare(query2).bind(...params).all();
    return jsonResponse({
      success: true,
      data: {
        records: result.results || [],
        total: result.results?.length || 0
      }
    });
  } catch (e) {
    console.error("\u83B7\u53D6\u4FEE\u884C\u8BB0\u5F55\u5931\u8D25:", e);
    return jsonResponse({ success: false, error: "\u83B7\u53D6\u8BB0\u5F55\u5931\u8D25" }, 500);
  }
}
__name(handleGetRecords, "handleGetRecords");
async function handleGetStats(request, env, db) {
  const auth = await authenticateUser(request, db);
  if (auth.error) {
    return jsonResponse({ success: false, error: auth.error }, auth.status);
  }
  try {
    const today = (/* @__PURE__ */ new Date()).toISOString().split("T")[0];
    const todayStats = await db.prepare(`
      SELECT sutra_name, SUM(chant_count) as today_count, SUM(duration) as today_duration
      FROM meditation_records
      WHERE username = ? AND record_date = ?
      GROUP BY sutra_name
      ORDER BY today_count DESC
      LIMIT 1
    `).bind(auth.username, today).first();
    const totalStats = await db.prepare(`
      SELECT 
        COUNT(*) as total_records,
        SUM(chant_count) as total_count,
        SUM(duration) as total_duration,
        COUNT(DISTINCT record_date) as total_days
      FROM meditation_records
      WHERE username = ?
    `).bind(auth.username).first();
    const consecutiveDays = await calculateConsecutiveDays(db, auth.username, today);
    const sutraStats = await db.prepare(`
      SELECT sutra_name, SUM(chant_count) as count, SUM(duration) as duration, COUNT(DISTINCT record_date) as days
      FROM meditation_records
      WHERE username = ?
      GROUP BY sutra_name
      ORDER BY count DESC
    `).bind(auth.username).all();
    return jsonResponse({
      success: true,
      data: {
        today: {
          sutra: todayStats?.sutra_name || null,
          count: todayStats?.today_count || 0,
          duration: todayStats?.today_duration || 0
        },
        total: {
          records: totalStats?.total_records || 0,
          count: totalStats?.total_count || 0,
          duration: totalStats?.total_duration || 0,
          days: totalStats?.total_days || 0
        },
        consecutiveDays,
        bySubject: sutraStats.results || []
      }
    });
  } catch (e) {
    console.error("\u83B7\u53D6\u4FEE\u884C\u7EDF\u8BA1\u5931\u8D25:", e);
    return jsonResponse({ success: false, error: "\u83B7\u53D6\u7EDF\u8BA1\u5931\u8D25" }, 500);
  }
}
__name(handleGetStats, "handleGetStats");
async function calculateConsecutiveDays(db, username, today) {
  try {
    const result = await db.prepare(`
      SELECT DISTINCT record_date
      FROM meditation_records
      WHERE username = ?
      ORDER BY record_date DESC
      LIMIT 365
    `).bind(username).all();
    if (!result.results || result.results.length === 0) {
      return 0;
    }
    const dates = result.results.map((r) => r.record_date);
    let consecutive = 0;
    let checkDate = new Date(today);
    for (let i = 0; i < 365; i++) {
      const dateStr = checkDate.toISOString().split("T")[0];
      if (dates.includes(dateStr)) {
        consecutive++;
        checkDate.setDate(checkDate.getDate() - 1);
      } else if (i === 0) {
        checkDate.setDate(checkDate.getDate() - 1);
      } else {
        break;
      }
    }
    return consecutive;
  } catch (e) {
    console.error("\u8BA1\u7B97\u8FDE\u7EED\u5929\u6570\u5931\u8D25:", e);
    return 0;
  }
}
__name(calculateConsecutiveDays, "calculateConsecutiveDays");
async function handleGetWeeklyStats(request, env, db) {
  const auth = await authenticateUser(request, db);
  if (auth.error) {
    return jsonResponse({ success: false, error: auth.error }, auth.status);
  }
  try {
    const today = /* @__PURE__ */ new Date();
    const weekAgo = new Date(today);
    weekAgo.setDate(weekAgo.getDate() - 6);
    const result = await db.prepare(`
      SELECT record_date, SUM(chant_count) as count, SUM(duration) as duration
      FROM meditation_records
      WHERE username = ? AND record_date >= ? AND record_date <= ?
      GROUP BY record_date
      ORDER BY record_date ASC
    `).bind(auth.username, weekAgo.toISOString().split("T")[0], today.toISOString().split("T")[0]).all();
    const weekData = [];
    for (let i = 0; i < 7; i++) {
      const date = new Date(weekAgo);
      date.setDate(date.getDate() + i);
      const dateStr = date.toISOString().split("T")[0];
      const dayData = result.results?.find((r) => r.record_date === dateStr);
      weekData.push({
        date: dateStr,
        day: ["\u65E5", "\u4E00", "\u4E8C", "\u4E09", "\u56DB", "\u4E94", "\u516D"][date.getDay()],
        count: dayData?.count || 0,
        duration: dayData?.duration || 0
      });
    }
    const weekTotal = weekData.reduce((sum, d) => sum + d.count, 0);
    return jsonResponse({
      success: true,
      data: {
        days: weekData,
        weekTotal
      }
    });
  } catch (e) {
    console.error("\u83B7\u53D6\u5468\u7EDF\u8BA1\u5931\u8D25:", e);
    return jsonResponse({ success: false, error: "\u83B7\u53D6\u5468\u7EDF\u8BA1\u5931\u8D25" }, 500);
  }
}
__name(handleGetWeeklyStats, "handleGetWeeklyStats");
async function handleGetMonthlyStats(request, env, db) {
  const auth = await authenticateUser(request, db);
  if (auth.error) {
    return jsonResponse({ success: false, error: auth.error }, auth.status);
  }
  try {
    const today = /* @__PURE__ */ new Date();
    const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
    const result = await db.prepare(`
      SELECT record_date, SUM(chant_count) as count, SUM(duration) as duration
      FROM meditation_records
      WHERE username = ? AND record_date >= ? AND record_date <= ?
      GROUP BY record_date
      ORDER BY record_date ASC
    `).bind(auth.username, monthStart.toISOString().split("T")[0], today.toISOString().split("T")[0]).all();
    const monthTotal = result.results?.reduce((sum, d) => sum + d.count, 0) || 0;
    return jsonResponse({
      success: true,
      data: {
        days: result.results || [],
        monthTotal
      }
    });
  } catch (e) {
    console.error("\u83B7\u53D6\u6708\u7EDF\u8BA1\u5931\u8D25:", e);
    return jsonResponse({ success: false, error: "\u83B7\u53D6\u6708\u7EDF\u8BA1\u5931\u8D25" }, 500);
  }
}
__name(handleGetMonthlyStats, "handleGetMonthlyStats");
async function handleSetGoal(request, env, db) {
  const auth = await authenticateUser(request, db);
  if (auth.error) {
    return jsonResponse({ success: false, error: auth.error }, auth.status);
  }
  try {
    const body = await request.json();
    const { sutra, targetCount, dedication = "" } = body;
    if (!sutra || !targetCount) {
      return jsonResponse({ success: false, error: "\u529F\u8BFE\u540D\u79F0\u548C\u76EE\u6807\u6570\u91CF\u4E0D\u80FD\u4E3A\u7A7A" }, 400);
    }
    const now = (/* @__PURE__ */ new Date()).toISOString();
    const existing = await db.prepare(`
      SELECT id, current_count FROM meditation_goals
      WHERE username = ? AND sutra_name = ? AND status = 'active'
    `).bind(auth.username, sutra).first();
    if (existing) {
      await db.prepare(`
        UPDATE meditation_goals
        SET target_count = ?, dedication = ?, updated_at = ?
        WHERE id = ?
      `).bind(targetCount, dedication, now, existing.id).run();
    } else {
      await db.prepare(`
        INSERT INTO meditation_goals (username, sutra_name, target_count, dedication, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
      `).bind(auth.username, sutra, targetCount, dedication, now, now).run();
    }
    return jsonResponse({ success: true, message: "\u53D1\u613F\u76EE\u6807\u5DF2\u8BBE\u7F6E" });
  } catch (e) {
    console.error("\u8BBE\u7F6E\u53D1\u613F\u76EE\u6807\u5931\u8D25:", e);
    return jsonResponse({ success: false, error: "\u8BBE\u7F6E\u76EE\u6807\u5931\u8D25" }, 500);
  }
}
__name(handleSetGoal, "handleSetGoal");
async function handleGetGoals(request, env, db) {
  const auth = await authenticateUser(request, db);
  if (auth.error) {
    return jsonResponse({ success: false, error: auth.error }, auth.status);
  }
  try {
    const url = new URL(request.url);
    const status = url.searchParams.get("status") || "active";
    const result = await db.prepare(`
      SELECT id, sutra_name, target_count, current_count, dedication, status, created_at, completed_at
      FROM meditation_goals
      WHERE username = ? AND status = ?
      ORDER BY created_at DESC
    `).bind(auth.username, status).all();
    const goals = (result.results || []).map((goal) => ({
      ...goal,
      progress: goal.target_count > 0 ? Math.round(goal.current_count / goal.target_count * 100) : 0
    }));
    return jsonResponse({
      success: true,
      data: { goals }
    });
  } catch (e) {
    console.error("\u83B7\u53D6\u53D1\u613F\u76EE\u6807\u5931\u8D25:", e);
    return jsonResponse({ success: false, error: "\u83B7\u53D6\u76EE\u6807\u5931\u8D25" }, 500);
  }
}
__name(handleGetGoals, "handleGetGoals");
async function handleMeditationSettings(request, env, db) {
  const auth = await authenticateUser(request, db);
  if (auth.error) {
    return jsonResponse({ success: false, error: auth.error }, auth.status);
  }
  if (request.method === "GET") {
    try {
      const settings = await db.prepare(`
        SELECT default_sutra, default_duration, reminder_enabled, reminder_time
        FROM meditation_settings
        WHERE username = ?
      `).bind(auth.username).first();
      return jsonResponse({
        success: true,
        data: settings || {
          default_sutra: null,
          default_duration: 30,
          reminder_enabled: 0,
          reminder_time: null
        }
      });
    } catch (e) {
      return jsonResponse({ success: false, error: "\u83B7\u53D6\u8BBE\u7F6E\u5931\u8D25" }, 500);
    }
  }
  if (request.method === "POST") {
    try {
      const body = await request.json();
      const { defaultSutra, defaultDuration = 30, reminderEnabled = false, reminderTime } = body;
      const now = (/* @__PURE__ */ new Date()).toISOString();
      await db.prepare(`
        INSERT INTO meditation_settings (username, default_sutra, default_duration, reminder_enabled, reminder_time, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(username) DO UPDATE SET
          default_sutra = excluded.default_sutra,
          default_duration = excluded.default_duration,
          reminder_enabled = excluded.reminder_enabled,
          reminder_time = excluded.reminder_time,
          updated_at = excluded.updated_at
      `).bind(auth.username, defaultSutra, defaultDuration, reminderEnabled ? 1 : 0, reminderTime, now, now).run();
      return jsonResponse({ success: true, message: "\u8BBE\u7F6E\u5DF2\u4FDD\u5B58" });
    } catch (e) {
      return jsonResponse({ success: false, error: "\u4FDD\u5B58\u8BBE\u7F6E\u5931\u8D25" }, 500);
    }
  }
  return jsonResponse({ success: false, error: "\u4E0D\u652F\u6301\u7684\u8BF7\u6C42\u65B9\u6CD5" }, 405);
}
__name(handleMeditationSettings, "handleMeditationSettings");

// src/handlers/sync.js
init_auth_utils();
async function handleGetSyncData(request, env, db) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
    }
    const token = authHeader.substring(7);
    const tokenData = await verifyToken(token, env);
    if (!tokenData?.username) {
      return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
    }
    const url = new URL(request.url);
    const sinceVersion = parseInt(url.searchParams.get("since") || "0");
    const username = tokenData.username;
    const [likes, comments, meditationRecords, meditationGoals, follows] = await Promise.all([
      // 点赞数据
      db.prepare(`
                SELECT id, content_id, content_type, title, file_path, created_at, sync_version
                FROM content_likes 
                WHERE username = ? AND sync_version > ?
                ORDER BY sync_version ASC
            `).bind(username, sinceVersion).all(),
      // 评论数据
      db.prepare(`
                SELECT id, content_id, content, parent_id, tag, content_title, like_count, created_at, sync_version
                FROM comments 
                WHERE username = ? AND sync_version > ?
                ORDER BY sync_version ASC
            `).bind(username, sinceVersion).all(),
      // 修行记录
      db.prepare(`
                SELECT id, sutra_name, sutra_source, duration, chant_count, record_date, is_manual, notes, created_at, sync_version
                FROM meditation_records 
                WHERE username = ? AND sync_version > ?
                ORDER BY sync_version ASC
            `).bind(username, sinceVersion).all(),
      // 修行目标
      db.prepare(`
                SELECT id, sutra_name, target_count, current_count, dedication, status, created_at, updated_at, completed_at, sync_version
                FROM meditation_goals 
                WHERE username = ? AND sync_version > ?
                ORDER BY sync_version ASC
            `).bind(username, sinceVersion).all(),
      // 关注关系
      db.prepare(`
                SELECT id, following_username, created_at, sync_version
                FROM user_follows 
                WHERE follower_username = ? AND sync_version > ?
                ORDER BY sync_version ASC
            `).bind(username, sinceVersion).all()
    ]);
    const maxVersionResult = await db.prepare(`
            SELECT MAX(sync_version) as max_version FROM (
                SELECT MAX(sync_version) as sync_version FROM content_likes WHERE username = ?
                UNION ALL
                SELECT MAX(sync_version) as sync_version FROM comments WHERE username = ?
                UNION ALL
                SELECT MAX(sync_version) as sync_version FROM meditation_records WHERE username = ?
                UNION ALL
                SELECT MAX(sync_version) as sync_version FROM meditation_goals WHERE username = ?
                UNION ALL
                SELECT MAX(sync_version) as sync_version FROM user_follows WHERE follower_username = ?
            )
        `).bind(username, username, username, username, username).first();
    const currentVersion = maxVersionResult?.max_version || sinceVersion;
    return jsonResponse({
      success: true,
      syncVersion: currentVersion,
      data: {
        likes: likes.results || [],
        comments: comments.results || [],
        meditationRecords: meditationRecords.results || [],
        meditationGoals: meditationGoals.results || [],
        follows: follows.results || []
      }
    });
  } catch (error) {
    console.error("\u83B7\u53D6\u540C\u6B65\u6570\u636E\u5931\u8D25:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u540C\u6B65\u6570\u636E\u5931\u8D25: " + error.message }, 500);
  }
}
__name(handleGetSyncData, "handleGetSyncData");
async function handlePushSyncData(request, env, db) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
    }
    const token = authHeader.substring(7);
    const tokenData = await verifyToken(token, env);
    if (!tokenData?.username) {
      return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
    }
    const username = tokenData.username;
    const { changes } = await request.json();
    if (!changes || !Array.isArray(changes)) {
      return jsonResponse({ error: "\u65E0\u6548\u7684\u540C\u6B65\u6570\u636E" }, 400);
    }
    const results = [];
    const conflicts = [];
    const now = (/* @__PURE__ */ new Date()).toISOString();
    for (const change of changes) {
      const { table, action, data, clientVersion } = change;
      try {
        if (action === "insert") {
          const result = await handleInsert(db, username, table, data, now);
          results.push({ table, action, success: true, id: result.id });
        } else if (action === "update") {
          const result = await handleUpdate(db, username, table, data, clientVersion);
          if (result.conflict) {
            conflicts.push({ table, recordId: data.id, serverVersion: result.serverVersion });
          } else {
            results.push({ table, action, success: true, id: data.id });
          }
        } else if (action === "delete") {
          await handleDelete(db, username, table, data.id);
          results.push({ table, action, success: true, id: data.id });
        }
      } catch (error) {
        console.error(`\u5904\u7406\u53D8\u66F4\u5931\u8D25: ${table}/${action}`, error);
        results.push({ table, action, success: false, error: error.message });
      }
    }
    await db.prepare(`
            INSERT INTO user_sync_state (username, last_sync_at)
            VALUES (?, ?)
            ON CONFLICT(username) DO UPDATE SET last_sync_at = excluded.last_sync_at
        `).bind(username, now).run();
    return jsonResponse({
      success: true,
      results,
      conflicts,
      hasConflicts: conflicts.length > 0
    });
  } catch (error) {
    console.error("\u63A8\u9001\u540C\u6B65\u6570\u636E\u5931\u8D25:", error);
    return jsonResponse({ error: "\u63A8\u9001\u540C\u6B65\u6570\u636E\u5931\u8D25: " + error.message }, 500);
  }
}
__name(handlePushSyncData, "handlePushSyncData");
async function handleGetSyncState(request, env, db) {
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return jsonResponse({ error: "\u672A\u63D0\u4F9B\u8BA4\u8BC1\u4FE1\u606F" }, 401);
    }
    const token = authHeader.substring(7);
    const tokenData = await verifyToken(token, env);
    if (!tokenData?.username) {
      return jsonResponse({ error: "\u8BA4\u8BC1\u5931\u8D25" }, 401);
    }
    const state = await db.prepare(`
            SELECT last_sync_version, last_sync_at FROM user_sync_state WHERE username = ?
        `).bind(tokenData.username).first();
    return jsonResponse({
      success: true,
      lastSyncVersion: state?.last_sync_version || 0,
      lastSyncAt: state?.last_sync_at || null
    });
  } catch (error) {
    console.error("\u83B7\u53D6\u540C\u6B65\u72B6\u6001\u5931\u8D25:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u540C\u6B65\u72B6\u6001\u5931\u8D25" }, 500);
  }
}
__name(handleGetSyncState, "handleGetSyncState");
async function handleInsert(db, username, table, data, now) {
  const versionResult = await db.prepare(`
        SELECT COALESCE(MAX(sync_version), 0) + 1 as next_version FROM ${table} WHERE username = ?
    `).bind(username).first();
  const nextVersion = versionResult.next_version;
  switch (table) {
    case "content_likes":
      await db.prepare(`
                INSERT INTO content_likes (content_id, content_type, username, title, file_path, created_at, sync_version)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            `).bind(data.content_id, data.content_type || "text", username, data.title, data.file_path, now, nextVersion).run();
      break;
    case "comments":
      await db.prepare(`
                INSERT INTO comments (content_id, username, content, parent_id, tag, content_title, created_at, sync_version)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            `).bind(data.content_id, username, data.content, data.parent_id, data.tag, data.content_title, now, nextVersion).run();
      break;
    case "meditation_records":
      await db.prepare(`
                INSERT INTO meditation_records (username, sutra_name, sutra_source, duration, chant_count, record_date, is_manual, notes, created_at, sync_version)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            `).bind(username, data.sutra_name, data.sutra_source || "custom", data.duration || 0, data.chant_count || 0, data.record_date, data.is_manual || 0, data.notes, now, nextVersion).run();
      break;
    case "meditation_goals":
      await db.prepare(`
                INSERT INTO meditation_goals (username, sutra_name, target_count, current_count, dedication, status, created_at, sync_version)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            `).bind(username, data.sutra_name, data.target_count, data.current_count || 0, data.dedication, data.status || "active", now, nextVersion).run();
      break;
    case "user_follows":
      await db.prepare(`
                INSERT INTO user_follows (follower_username, following_username, created_at, sync_version)
                VALUES (?, ?, ?, ?)
            `).bind(username, data.following_username, now, nextVersion).run();
      break;
  }
  return { id: data.id, version: nextVersion };
}
__name(handleInsert, "handleInsert");
async function handleUpdate(db, username, table, data, clientVersion) {
  const serverRecord = await db.prepare(`
        SELECT sync_version FROM ${table} WHERE id = ? AND username = ?
    `).bind(data.id, username).first();
  if (!serverRecord) {
    throw new Error("\u8BB0\u5F55\u4E0D\u5B58\u5728");
  }
  if (serverRecord.sync_version > clientVersion) {
    return { conflict: true, serverVersion: serverRecord.sync_version };
  }
  const nextVersion = serverRecord.sync_version + 1;
  const now = (/* @__PURE__ */ new Date()).toISOString();
  switch (table) {
    case "meditation_goals":
      await db.prepare(`
                UPDATE meditation_goals 
                SET current_count = ?, status = ?, updated_at = ?, sync_version = ?
                WHERE id = ? AND username = ?
            `).bind(data.current_count, data.status, now, nextVersion, data.id, username).run();
      break;
    case "meditation_records":
      await db.prepare(`
                UPDATE meditation_records 
                SET duration = ?, chant_count = ?, notes = ?, sync_version = ?
                WHERE id = ? AND username = ?
            `).bind(data.duration, data.chant_count, data.notes, nextVersion, data.id, username).run();
      break;
  }
  return { conflict: false, version: nextVersion };
}
__name(handleUpdate, "handleUpdate");
async function handleDelete(db, username, table, recordId) {
  await db.prepare(`
        DELETE FROM ${table} WHERE id = ? AND username = ?
    `).bind(recordId, username).run();
}
__name(handleDelete, "handleDelete");

// migrate-builtin-handler-fixed.js
var CHINESE_NUMS = ["\u96F6", "\u4E00", "\u4E8C", "\u4E09", "\u56DB", "\u4E94", "\u516D", "\u4E03", "\u516B", "\u4E5D"];
function numberToChinese(num) {
  if (num < 0 || num >= 100) return num.toString();
  if (num < 10) return CHINESE_NUMS[num];
  if (num === 10) return "\u5341";
  if (num < 20) return "\u5341" + CHINESE_NUMS[num % 10];
  const ten = Math.floor(num / 10);
  const unit = num % 10;
  return CHINESE_NUMS[ten] + "\u5341" + (unit === 0 ? "" : CHINESE_NUMS[unit]);
}
__name(numberToChinese, "numberToChinese");
function normalizeQuery(text) {
  return text.replace(/\d+/g, (match) => {
    const num = parseInt(match, 10);
    if (isNaN(num) || num >= 100) return match;
    return numberToChinese(num);
  });
}
__name(normalizeQuery, "normalizeQuery");
function extractKeywords(text) {
  const keywords = [];
  const sutraMatch = text.match(/^(.+?经)/);
  if (sutraMatch) {
    keywords.push(sutraMatch[1]);
    const remaining = text.substring(sutraMatch[1].length);
    if (remaining.trim()) {
      keywords.push(remaining.trim());
    }
  } else {
    if (text.includes("\u7B2C")) {
      const parts = text.split(/(第.+)/);
      parts.forEach((p) => {
        if (p.trim()) keywords.push(p.trim());
      });
    } else {
      const numUnitMatch = text.match(/^(.+?)([一二三四五六七八九十百千万]+[卷品章节集部篇回]+)$/);
      if (numUnitMatch) {
        keywords.push(numUnitMatch[1]);
        keywords.push(numUnitMatch[2]);
      } else {
        keywords.push(text);
      }
    }
  }
  return keywords.filter((k) => k && k.length > 0);
}
__name(extractKeywords, "extractKeywords");
function expandVolumeKeyword(keyword) {
  const volumePattern = /^([一二三四五六七八九十百千万]+)(卷|品|章|节|集|部|篇|回)$/;
  const match = keyword.match(volumePattern);
  if (match && !keyword.startsWith("\u7B2C")) {
    return [keyword, "\u7B2C" + keyword];
  }
  return [keyword];
}
__name(expandVolumeKeyword, "expandVolumeKeyword");
var CREATE_TABLES_SQL = `
-- \u521B\u5EFAtexts\u8868\u5B58\u50A8\u6587\u672C\u5185\u5BB9
CREATE TABLE IF NOT EXISTS texts (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    file_path TEXT NOT NULL,
    category TEXT NOT NULL,
    file_name TEXT NOT NULL,
    word_count INTEGER DEFAULT 0,
    source TEXT DEFAULT 'builtin',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- \u521B\u5EFAFTS5\u865A\u62DF\u8868\u7528\u4E8E\u5168\u6587\u641C\u7D22
CREATE VIRTUAL TABLE IF NOT EXISTS texts_fts USING fts5(
    title,
    content,
    category,
    content='texts',
    content_rowid='rowid'
);

-- \u521B\u5EFA\u7D22\u5F15\u4F18\u5316\u67E5\u8BE2\u6027\u80FD
CREATE INDEX IF NOT EXISTS idx_texts_category ON texts(category);
CREATE INDEX IF NOT EXISTS idx_texts_source ON texts(source);
CREATE INDEX IF NOT EXISTS idx_texts_created_at ON texts(created_at);
CREATE INDEX IF NOT EXISTS idx_texts_word_count ON texts(word_count);
`;
async function ensureTablesExist(env) {
  try {
    const statements = CREATE_TABLES_SQL.split(";").filter((s) => s.trim());
    for (const statement of statements) {
      if (statement.trim()) {
        await env.DB.prepare(statement.trim()).run();
      }
    }
    console.log("\u2705 \u6570\u636E\u5E93\u8868\u7ED3\u6784\u68C0\u67E5\u5B8C\u6210");
    return true;
  } catch (error) {
    console.error("\u274C \u521B\u5EFA\u8868\u5931\u8D25:", error);
    return false;
  }
}
__name(ensureTablesExist, "ensureTablesExist");
async function handleBuiltinMigration(request, env) {
  try {
    const tablesReady = await ensureTablesExist(env);
    if (!tablesReady) {
      return new Response(JSON.stringify({
        success: false,
        error: "Failed to create database tables"
      }), {
        status: 500,
        headers: { "Content-Type": "application/json" }
      });
    }
    const { texts } = await request.json();
    if (!texts || !Array.isArray(texts)) {
      return new Response(JSON.stringify({
        success: false,
        error: "Invalid texts data"
      }), {
        status: 400,
        headers: { "Content-Type": "application/json" }
      });
    }
    console.log(`\u{1F4E5} \u63A5\u6536\u5230 ${texts.length} \u4E2A\u6587\u672C\u8FDB\u884C\u8FC1\u79FB`);
    let successful = 0;
    let failed = 0;
    for (const text of texts) {
      try {
        const {
          id,
          title,
          content,
          filePath,
          category,
          fileName,
          wordCount,
          source = "builtin"
        } = text;
        await env.DB.prepare(`
                    INSERT OR REPLACE INTO texts (
                        id, title, content, file_path, category, 
                        file_name, word_count, source, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))
                `).bind(id, title, content, filePath, category, fileName, wordCount, source).run();
        successful++;
        console.log(`\u2705 \u63D2\u5165\u6210\u529F: ${title}`);
      } catch (error) {
        failed++;
        console.error(`\u274C \u63D2\u5165\u5931\u8D25: ${text.title}`, error);
      }
    }
    console.log(`\u{1F4CA} \u8FC1\u79FB\u5B8C\u6210 - \u6210\u529F: ${successful}, \u5931\u8D25: ${failed}`);
    return new Response(JSON.stringify({
      success: true,
      message: `Successfully migrated ${successful} texts`,
      stats: {
        total: texts.length,
        successful,
        failed
      }
    }), {
      status: 200,
      headers: { "Content-Type": "application/json" }
    });
  } catch (error) {
    console.error("\u274C \u8FC1\u79FB\u5931\u8D25:", error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }
}
__name(handleBuiltinMigration, "handleBuiltinMigration");
async function handleFullTextSearch(request, env) {
  try {
    const url = new URL(request.url);
    const query2 = url.searchParams.get("q");
    const category = url.searchParams.get("category");
    const limit = parseInt(url.searchParams.get("limit") || "20");
    const offset = parseInt(url.searchParams.get("offset") || "0");
    if (!query2 || query2.trim().length === 0) {
      return new Response(JSON.stringify({
        success: false,
        error: "Search query is required"
      }), {
        status: 400,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, Authorization"
        }
      });
    }
    console.log(`\u{1F50D} \u5168\u6587\u641C\u7D22: "${query2}" \u5206\u7C7B: ${category || "\u5168\u90E8"}`);
    const normalizedQuery = normalizeQuery(query2);
    const hasNumber = /\d/.test(query2);
    if (hasNumber) {
      console.log(`\u{1F504} \u68C0\u6D4B\u5230\u6570\u5B57\uFF0C\u4F7F\u7528\u589E\u5F3A\u641C\u7D22: "${query2}" -> "${normalizedQuery}"`);
    }
    let searchResults;
    if (hasNumber) {
      console.log("\u{1F4CC} \u4F7F\u7528LIKE\u641C\u7D22\uFF08\u652F\u6301\u6570\u5B57\u8F6C\u4E2D\u6587+\u5206\u8BCD\u5339\u914D\uFF09");
      const keywords = extractKeywords(normalizedQuery);
      console.log(`\u{1F524} \u5206\u8BCD\u7ED3\u679C: ${JSON.stringify(keywords)}`);
      if (keywords.length > 1) {
        let conditions = keywords.map((kw) => {
          const expanded = expandVolumeKeyword(kw);
          if (expanded.length > 1) {
            return `(${expanded.map(() => "title LIKE ? OR content LIKE ?").join(" OR ")})`;
          }
          return "(title LIKE ? OR content LIKE ?)";
        }).join(" AND ");
        let likeQuery = `
                    SELECT 
                        id, title, category, file_path, word_count,
                        SUBSTR(content, 1, 100) as snippet
                    FROM texts
                    WHERE ${conditions}
                `;
        let likeParams = [];
        keywords.forEach((kw) => {
          const expanded = expandVolumeKeyword(kw);
          expanded.forEach((ek) => {
            likeParams.push(`%${ek}%`, `%${ek}%`);
          });
        });
        if (category && category !== "all") {
          likeQuery += ` AND category = ?`;
          likeParams.push(category);
        }
        likeQuery += ` ORDER BY word_count DESC LIMIT ? OFFSET ?`;
        likeParams.push(limit, offset);
        searchResults = await env.DB.prepare(likeQuery).bind(...likeParams).all();
      } else {
        let likeQuery = `
                    SELECT 
                        id, title, category, file_path, word_count,
                        SUBSTR(content, 1, 100) as snippet
                    FROM texts
                    WHERE (title LIKE ? OR title LIKE ? OR content LIKE ? OR content LIKE ?)
                `;
        let likeParams = [`%${query2}%`, `%${normalizedQuery}%`, `%${query2}%`, `%${normalizedQuery}%`];
        if (category && category !== "all") {
          likeQuery += ` AND category = ?`;
          likeParams.push(category);
        }
        likeQuery += ` ORDER BY title LIKE ? DESC, title LIKE ? DESC, word_count DESC LIMIT ? OFFSET ?`;
        likeParams.push(`%${query2}%`, `%${normalizedQuery}%`, limit, offset);
        searchResults = await env.DB.prepare(likeQuery).bind(...likeParams).all();
      }
    } else {
      const ftsQuery = query2.split("").filter((c) => c.trim()).join(" ") + "*";
      console.log(`\u{1F50E} \u4F7F\u7528FTS5\u67E5\u8BE2: "${ftsQuery}"`);
      let searchQuery = `
                SELECT 
                    t.id, t.title, t.category, t.file_path, t.word_count,
                    snippet(texts_fts, 1, '<b>', '</b>', '...', 64) as snippet
                FROM texts_fts
                JOIN texts t ON texts_fts.rowid = t.rowid
                WHERE texts_fts MATCH ?
            `;
      let params = [ftsQuery];
      if (category && category !== "all") {
        searchQuery += ` AND t.category = ?`;
        params.push(category);
      }
      searchQuery += ` ORDER BY rank LIMIT ? OFFSET ?`;
      params.push(limit, offset);
      searchResults = await env.DB.prepare(searchQuery).bind(...params).all();
      if (!searchResults.results || searchResults.results.length === 0) {
        console.log("\u26A0\uFE0F FTS5 \u65E0\u7ED3\u679C\uFF0C\u56DE\u9000\u5230 LIKE \u641C\u7D22");
        let likeQuery = `
                    SELECT 
                        id, title, category, file_path, word_count,
                        SUBSTR(content, 1, 100) as snippet
                    FROM texts
                    WHERE (title LIKE ? OR content LIKE ?)
                `;
        let likeParams = [`%${query2}%`, `%${query2}%`];
        if (category && category !== "all") {
          likeQuery += ` AND category = ?`;
          likeParams.push(category);
        }
        likeQuery += ` ORDER BY title LIKE ? DESC, word_count DESC LIMIT ? OFFSET ?`;
        likeParams.push(`%${query2}%`, limit, offset);
        searchResults = await env.DB.prepare(likeQuery).bind(...likeParams).all();
      }
    }
    let total = 0;
    try {
      if (hasNumber) {
        let likeCountQuery = `SELECT COUNT(*) as total FROM texts WHERE (title LIKE ? OR title LIKE ? OR content LIKE ? OR content LIKE ?)`;
        let likeCountParams = [`%${query2}%`, `%${normalizedQuery}%`, `%${query2}%`, `%${normalizedQuery}%`];
        if (category && category !== "all") {
          likeCountQuery += ` AND category = ?`;
          likeCountParams.push(category);
        }
        const likeCountResult = await env.DB.prepare(likeCountQuery).bind(...likeCountParams).first();
        total = likeCountResult?.total || 0;
      } else {
        const ftsQuery = query2.split("").filter((c) => c.trim()).join(" ") + "*";
        let countQuery = `SELECT COUNT(*) as total FROM texts_fts WHERE texts_fts MATCH ?`;
        let countParams = [ftsQuery];
        if (category && category !== "all") {
          countQuery += ` AND category = ?`;
          countParams.push(category);
        }
        const countResult = await env.DB.prepare(countQuery).bind(...countParams).first();
        total = countResult?.total || 0;
        if (total === 0) {
          let likeCountQuery = `SELECT COUNT(*) as total FROM texts WHERE (title LIKE ? OR content LIKE ?)`;
          let likeCountParams = [`%${query2}%`, `%${query2}%`];
          if (category && category !== "all") {
            likeCountQuery += ` AND category = ?`;
            likeCountParams.push(category);
          }
          const likeCountResult = await env.DB.prepare(likeCountQuery).bind(...likeCountParams).first();
          total = likeCountResult?.total || 0;
        }
      }
    } catch (e) {
      console.error("\u83B7\u53D6\u603B\u6570\u5931\u8D25:", e);
    }
    console.log(`\u{1F4CA} FTS5 \u641C\u7D22\u7ED3\u679C: ${searchResults.results?.length || 0} \u6761\uFF0C\u603B\u8BA1: ${total} \u6761`);
    return new Response(JSON.stringify({
      success: true,
      data: {
        results: (searchResults.results || []).map((r) => ({
          ...r,
          content: r.snippet
          // 用高亮片段作为预览内容
        })),
        pagination: {
          total,
          limit,
          offset,
          hasMore: offset + limit < total
        },
        query: query2,
        category
      }
    }), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization"
      }
    });
  } catch (error) {
    console.error("\u274C \u641C\u7D22\u5931\u8D25:", error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization"
      }
    });
  }
}
__name(handleFullTextSearch, "handleFullTextSearch");
async function handleGetCategories2(request, env) {
  try {
    const categoriesResult = await env.DB.prepare(`
            SELECT category, COUNT(*) as count
            FROM texts
            WHERE source = 'builtin'
            GROUP BY category
            ORDER BY count DESC
        `).all();
    return new Response(JSON.stringify({
      success: true,
      data: categoriesResult.results || []
    }), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization"
      }
    });
  } catch (error) {
    console.error("\u274C \u83B7\u53D6\u5206\u7C7B\u5931\u8D25:", error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }
}
__name(handleGetCategories2, "handleGetCategories");

// src/handlers/moderation.js
async function handleReport(request, env, db) {
  try {
    const body = await request.json();
    const { content_id, reason, description, reporter_user_id, timestamp } = body;
    if (!content_id || !reason) {
      return jsonResponse({ error: "\u7F3A\u5C11\u5FC5\u8981\u53C2\u6570" }, 400);
    }
    await db.prepare(`
      CREATE TABLE IF NOT EXISTS content_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content_id TEXT NOT NULL,
        reason TEXT NOT NULL,
        description TEXT DEFAULT '',
        reporter_user_id TEXT DEFAULT 'anonymous',
        status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        reviewed_at TEXT,
        reviewer_note TEXT
      )
    `).run();
    await db.prepare(`
      INSERT INTO content_reports (content_id, reason, description, reporter_user_id, status, created_at)
      VALUES (?, ?, ?, ?, 'pending', ?)
    `).bind(
      content_id,
      reason,
      description || "",
      reporter_user_id || "anonymous",
      timestamp || (/* @__PURE__ */ new Date()).toISOString()
    ).run();
    console.log(`\u{1F4E2} \u65B0\u4E3E\u62A5: content_id=${content_id}, reason=${reason}, reporter=${reporter_user_id}`);
    return jsonResponse({ success: true, message: "\u4E3E\u62A5\u5DF2\u63D0\u4EA4" }, 201);
  } catch (error) {
    console.error("\u4E3E\u62A5\u5904\u7406\u5931\u8D25:", error);
    return jsonResponse({ error: "\u4E3E\u62A5\u5904\u7406\u5931\u8D25" }, 500);
  }
}
__name(handleReport, "handleReport");
async function handleBlockUser(request, env, db) {
  try {
    const body = await request.json();
    const { blocked_user_id, action, reason, timestamp } = body;
    if (!blocked_user_id || !action) {
      return jsonResponse({ error: "\u7F3A\u5C11\u5FC5\u8981\u53C2\u6570" }, 400);
    }
    await db.prepare(`
      CREATE TABLE IF NOT EXISTS user_blocks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        blocked_user_id TEXT NOT NULL,
        action TEXT NOT NULL,
        reason TEXT DEFAULT '',
        status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        reviewed_at TEXT
      )
    `).run();
    await db.prepare(`
      INSERT INTO user_blocks (blocked_user_id, action, reason, status, created_at)
      VALUES (?, ?, ?, 'pending', ?)
    `).bind(
      blocked_user_id,
      action,
      reason || "",
      timestamp || (/* @__PURE__ */ new Date()).toISOString()
    ).run();
    console.log(`\u{1F6AB} \u7528\u6237\u5C4F\u853D: blocked_user_id=${blocked_user_id}, action=${action}`);
    return jsonResponse({ success: true, message: `\u7528\u6237${action === "block" ? "\u5DF2\u5C4F\u853D" : "\u5DF2\u53D6\u6D88\u5C4F\u853D"}` }, 201);
  } catch (error) {
    console.error("\u5C4F\u853D\u5904\u7406\u5931\u8D25:", error);
    return jsonResponse({ error: "\u5C4F\u853D\u5904\u7406\u5931\u8D25" }, 500);
  }
}
__name(handleBlockUser, "handleBlockUser");
async function handleGetReports(request, env, db) {
  try {
    const url = new URL(request.url);
    const status = url.searchParams.get("status") || "pending";
    const page = parseInt(url.searchParams.get("page") || "1");
    const pageSize = parseInt(url.searchParams.get("pageSize") || "20");
    const offset = (page - 1) * pageSize;
    await db.prepare(`
      CREATE TABLE IF NOT EXISTS content_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content_id TEXT NOT NULL,
        reason TEXT NOT NULL,
        description TEXT DEFAULT '',
        reporter_user_id TEXT DEFAULT 'anonymous',
        status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        reviewed_at TEXT,
        reviewer_note TEXT
      )
    `).run();
    const result = await db.prepare(`
      SELECT * FROM content_reports 
      WHERE status = ? 
      ORDER BY created_at DESC 
      LIMIT ? OFFSET ?
    `).bind(status, pageSize, offset).all();
    const countResult = await db.prepare(
      "SELECT COUNT(*) as total FROM content_reports WHERE status = ?"
    ).bind(status).first();
    return jsonResponse({
      reports: result.results || [],
      total: countResult?.total || 0,
      page,
      pageSize
    });
  } catch (error) {
    console.error("\u83B7\u53D6\u4E3E\u62A5\u5217\u8868\u5931\u8D25:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u4E3E\u62A5\u5217\u8868\u5931\u8D25" }, 500);
  }
}
__name(handleGetReports, "handleGetReports");
async function handleReviewReport(request, env, db) {
  try {
    const body = await request.json();
    const { report_id, action, reviewer_note } = body;
    if (!report_id || !action) {
      return jsonResponse({ error: "\u7F3A\u5C11\u5FC5\u8981\u53C2\u6570" }, 400);
    }
    await db.prepare(`
      UPDATE content_reports 
      SET status = ?, reviewed_at = ?, reviewer_note = ? 
      WHERE id = ?
    `).bind(
      action,
      (/* @__PURE__ */ new Date()).toISOString(),
      reviewer_note || "",
      report_id
    ).run();
    return jsonResponse({ success: true, message: "\u5BA1\u6838\u5B8C\u6210" });
  } catch (error) {
    console.error("\u5BA1\u6838\u4E3E\u62A5\u5931\u8D25:", error);
    return jsonResponse({ error: "\u5BA1\u6838\u4E3E\u62A5\u5931\u8D25" }, 500);
  }
}
__name(handleReviewReport, "handleReviewReport");
async function handleGetBlocks(request, env, db) {
  try {
    const url = new URL(request.url);
    const page = parseInt(url.searchParams.get("page") || "1");
    const pageSize = parseInt(url.searchParams.get("pageSize") || "20");
    const offset = (page - 1) * pageSize;
    await db.prepare(`
      CREATE TABLE IF NOT EXISTS user_blocks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        blocked_user_id TEXT NOT NULL,
        action TEXT NOT NULL,
        reason TEXT DEFAULT '',
        status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        reviewed_at TEXT
      )
    `).run();
    const result = await db.prepare(`
      SELECT * FROM user_blocks 
      ORDER BY created_at DESC 
      LIMIT ? OFFSET ?
    `).bind(pageSize, offset).all();
    const countResult = await db.prepare(
      "SELECT COUNT(*) as total FROM user_blocks"
    ).first();
    return jsonResponse({
      blocks: result.results || [],
      total: countResult?.total || 0,
      page,
      pageSize
    });
  } catch (error) {
    console.error("\u83B7\u53D6\u5C4F\u853D\u8BB0\u5F55\u5931\u8D25:", error);
    return jsonResponse({ error: "\u83B7\u53D6\u5C4F\u853D\u8BB0\u5F55\u5931\u8D25" }, 500);
  }
}
__name(handleGetBlocks, "handleGetBlocks");

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
  if (pathname === "/api/sms/send" && method === "POST") return await handleSendSmsCode(request, env, db);
  if (pathname === "/api/sms/login" && method === "POST") return await handleSmsLogin(request, env, db);
  if (pathname === "/api/auth/register" && method === "POST") return await handleRegister(request, env, db);
  if (pathname === "/api/auth/login" && method === "POST") return await handleLogin(request, env, db);
  if (pathname === "/api/auth/user-info" && method === "GET") return await handleGetUserInfo(request, env, db);
  if (pathname === "/api/auth/send-verification-code" && method === "POST") return await handleSendVerificationCode(request, env, ctx);
  if (pathname === "/api/auth/forgot-password" && method === "POST") return await handleForgotPassword(request, env, db);
  if (pathname === "/api/auth/reset-password" && method === "POST") return await handleResetPassword(request, env, db);
  if (pathname === "/api/auth/bind-email" && method === "POST") return await handleBindEmail(request, env, db);
  if (pathname === "/api/auth/bind-email" && method === "POST") return await handleBindEmail(request, env, db);
  if (pathname === "/api/auth/update-profile" && method === "POST") return await handleUpdateProfile(request, env, db);
  if (pathname === "/api/auth/firebase-phone-login" && method === "POST") return await handleFirebasePhoneLogin(request, env, db);
  if (pathname === "/api/comments" && method === "GET") return await handleGetComments(request, env, db);
  if (pathname === "/api/comments" && method === "POST") return await handlePostComment(request, env, db);
  if (pathname === "/api/comments" && method === "DELETE") return await handleDeleteComment(request, env, db);
  if (pathname === "/api/comments/batch-counts" && method === "POST") return await handleBatchGetCommentCounts(request, env, db);
  if (pathname === "/api/posts" && method === "GET") return await handleGetTaggedPosts(request, env, db);
  if (pathname === "/api/posts/detail" && method === "GET") return await handleGetPostDetail(request, env, db);
  if (pathname === "/api/feed/hot" && method === "GET") return await handleGetHotFeed(request, env, db);
  if (pathname === "/api/auth/wechat/login-url" && method === "GET") return await handleGetWechatLoginUrl(request, env);
  if (pathname === "/api/auth/alipay/login-url" && method === "GET") return await handleGetAlipayLoginUrl(request, env);
  if (pathname === "/api/auth/alipay/login" && method === "POST") return await handleAlipayLogin2(request, env);
  if (pathname === "/api/auth/alipay/register" && method === "POST") return await handleAlipayRegister(request, env);
  if (pathname === "/api/auth/alipay/macos-callback" && method === "GET") return await handleMacOSAlipayCallback2(request, env);
  if (pathname === "/api/auth/alipay/mobile-callback" && method === "GET") return await handleMobileAlipayCallback2(request, env);
  if (pathname === "/api/auth/alipay/auth-string" && method === "GET") return await handleGetAlipayAuthString2(request, env);
  if (pathname === "/api/auth/alipay/sdk-login" && method === "POST") return await handleAlipaySDKLogin2(request, env);
  if (pathname === "/api/alipay/create-order" && method === "POST") return await handleCreateAlipayOrder(request, env, db);
  if (pathname === "/api/alipay/query-order" && method === "GET") return await handleQueryAlipayOrder(request, env, db);
  if (pathname === "/api/alipay/notify" && method === "POST") return await handleAlipayNotify(request, env, db);
  if (pathname === "/api/alipay/check-membership" && method === "GET") return await handleCheckAlipayMembership(request, env, db);
  if (pathname === "/api/stripe/membership-status" && method === "GET") return await handleCheckMembershipStatus(request, env, db);
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
  if (pathname === "/api/search" && method === "GET") return await handleSearch(request, env, db);
  if (pathname === "/api/search/content" && method === "GET") return await handleGetTextContent(request, env, db);
  if (pathname === "/api/search/categories" && method === "GET") return await handleGetCategories(request, env, db);
  if (pathname === "/api/leaderboard" && method === "GET") return await handleGetLeaderboard(request, env, db);
  if (pathname === "/api/leaderboard/update" && method === "POST") return await handleUpdateTransferData(request, env, db);
  if (pathname === "/api/likes/toggle" && method === "POST") return await handleToggleLike(request, env, db);
  if (pathname === "/api/likes/count" && method === "GET") return await handleGetLikeCount(request, env, db);
  if (pathname === "/api/likes/batch-counts" && method === "POST") return await handleBatchGetLikeCounts(request, env, db);
  if (pathname === "/api/likes/my-likes" && method === "GET") return await handleGetMyLikes(request, env, db);
  if (pathname === "/api/likes/received-count" && method === "GET") return await handleGetReceivedLikeCount(request, env, db);
  if (pathname === "/api/favorites/toggle" && method === "POST") return await handleToggleFavorite(request, env, db);
  if (pathname === "/api/favorites/my-favorites" && method === "GET") return await handleGetMyFavorites(request, env, db);
  if (pathname === "/api/favorites/batch-check" && method === "POST") return await handleBatchCheckFavorites(request, env, db);
  if (pathname === "/api/content/batch-stats" && method === "POST") return await handleBatchGetContentStats(request, env, db);
  if (pathname === "/api/online/join" && method === "POST") return await handleOnlineJoin(request, env);
  if (pathname === "/api/online/heartbeat" && method === "POST") return await handleOnlineHeartbeat(request, env);
  if (pathname === "/api/online/leave" && method === "POST") return await handleOnlineLeave(request, env);
  if (pathname === "/api/online/count" && method === "GET") return await handleOnlineCount(request, env);
  if (pathname === "/api/meditation/record" && method === "POST") return await handleSyncRecord(request, env, db);
  if (pathname === "/api/meditation/records" && method === "GET") return await handleGetRecords(request, env, db);
  if (pathname === "/api/meditation/stats" && method === "GET") return await handleGetStats(request, env, db);
  if (pathname === "/api/meditation/weekly" && method === "GET") return await handleGetWeeklyStats(request, env, db);
  if (pathname === "/api/meditation/monthly" && method === "GET") return await handleGetMonthlyStats(request, env, db);
  if (pathname === "/api/meditation/goal" && method === "POST") return await handleSetGoal(request, env, db);
  if (pathname === "/api/meditation/goal" && method === "GET") return await handleGetGoals(request, env, db);
  if (pathname === "/api/meditation/settings" && (method === "GET" || method === "POST")) return await handleMeditationSettings(request, env, db);
  if (pathname === "/api/sync" && method === "GET") return await handleGetSyncData(request, env, db);
  if (pathname === "/api/sync" && method === "POST") return await handlePushSyncData(request, env, db);
  if (pathname === "/api/sync/state" && method === "GET") return await handleGetSyncState(request, env, db);
  if (pathname === "/api/admin/migrate-kv-to-d1" && method === "POST") return await handleMigrateKvToD1(request, env, db);
  if (pathname === "/migrate-builtin-complete" && method === "POST") return await handleBuiltinMigration(request, env);
  if (pathname === "/api/builtin/search" && method === "GET") return await handleFullTextSearch(request, env);
  if (pathname === "/api/builtin/categories" && method === "GET") return await handleGetCategories2(request, env);
  if (pathname === "/api/report" && method === "POST") return await handleReport(request, env, db);
  if (pathname === "/api/block-user" && method === "POST") return await handleBlockUser(request, env, db);
  if (pathname === "/api/admin/reports" && method === "GET") return await handleGetReports(request, env, db);
  if (pathname === "/api/admin/reports/review" && method === "POST") return await handleReviewReport(request, env, db);
  if (pathname === "/api/admin/blocks" && method === "GET") return await handleGetBlocks(request, env, db);
  return null;
}
__name(route, "route");

// src/durable-objects/OnlineCounter.js
var OnlineCounter = class {
  static {
    __name(this, "OnlineCounter");
  }
  constructor(state, env) {
    this.state = state;
    this.env = env;
    this.sessions = /* @__PURE__ */ new Map();
    this.webSockets = /* @__PURE__ */ new Map();
    this.pendingSockets = /* @__PURE__ */ new Set();
    this.TIMEOUT_MS = 90 * 1e3;
    this.CLEANUP_INTERVAL_MS = 30 * 1e3;
  }
  /**
   * 处理HTTP请求（包括 WebSocket 升级）
   */
  async fetch(request) {
    const url = new URL(request.url);
    const upgradeHeader = request.headers.get("Upgrade");
    console.log("DO received request:", {
      upgrade: upgradeHeader,
      path: url.pathname
    });
    if (upgradeHeader && upgradeHeader.toLowerCase() === "websocket") {
      console.log("DO handling WebSocket");
      return this.handleWebSocket(request);
    }
    const action = url.searchParams.get("action");
    try {
      switch (action) {
        case "join":
          return await this.handleJoin(request);
        case "heartbeat":
          return await this.handleHeartbeat(request);
        case "leave":
          return await this.handleLeave(request);
        case "count":
          return await this.handleCount();
        default:
          return this.jsonResponse({ error: "Invalid action" }, 400);
      }
    } catch (error) {
      console.error("OnlineCounter error:", error);
      return this.jsonResponse({ error: error.message }, 500);
    }
  }
  /**
   * 处理 WebSocket 连接
   */
  async handleWebSocket(request) {
    try {
      const pair = new WebSocketPair();
      const [client, server] = Object.values(pair);
      console.log("Creating WebSocket pair");
      server.accept();
      console.log("WebSocket accepted (Standard API)");
      this.pendingSockets.add(server);
      server.addEventListener("message", async (event) => {
        try {
          const message = JSON.parse(event.data);
          await this.handleWebSocketMessage(server, message);
        } catch (error) {
          console.error("WebSocket message error:", error);
          server.send(JSON.stringify({ type: "error", message: error.message }));
        }
      });
      server.addEventListener("close", () => {
        this.pendingSockets.delete(server);
        this.handleWebSocketClose(server);
      });
      server.addEventListener("error", (error) => {
        console.error("WebSocket error:", error);
        this.pendingSockets.delete(server);
        this.handleWebSocketClose(server);
      });
      console.log("Returning 101 response");
      return new Response(null, { status: 101, webSocket: client });
    } catch (error) {
      console.error("handleWebSocket error:", error);
      return new Response("WebSocket upgrade failed: " + error.message, { status: 500 });
    }
  }
  /**
   * 处理 WebSocket 消息
   */
  async handleWebSocketMessage(ws, message) {
    const { action, sessionId, activityType } = message;
    switch (action) {
      case "join":
        if (!sessionId) {
          ws.send(JSON.stringify({ type: "error", message: "sessionId required" }));
          return;
        }
        const now = Date.now();
        this.sessions.set(sessionId, { lastHeartbeat: now, ws });
        this.webSockets.set(ws, sessionId);
        await this.ensureAlarm();
        console.log(`Session ${sessionId} joined via WebSocket. Total: ${this.sessions.size}`);
        this.broadcastCount();
        break;
      case "heartbeat":
        if (!sessionId) {
          ws.send(JSON.stringify({ type: "error", message: "sessionId required" }));
          return;
        }
        const session = this.sessions.get(sessionId);
        if (!session) {
          ws.send(JSON.stringify({
            type: "error",
            message: "Session not found",
            shouldRejoin: true
          }));
          return;
        }
        session.lastHeartbeat = Date.now();
        break;
      case "leave":
        if (!sessionId) {
          ws.send(JSON.stringify({ type: "error", message: "sessionId required" }));
          return;
        }
        this.sessions.delete(sessionId);
        this.webSockets.delete(ws);
        console.log(`Session ${sessionId} left. Total: ${this.sessions.size}`);
        this.broadcastCount();
        break;
      default:
        ws.send(JSON.stringify({ type: "error", message: "Invalid action" }));
    }
  }
  /**
   * 处理 WebSocket 断开
   */
  handleWebSocketClose(ws) {
    const sessionId = this.webSockets.get(ws);
    if (sessionId) {
      this.sessions.delete(sessionId);
      this.webSockets.delete(ws);
      console.log(`WebSocket closed for session ${sessionId}. Total: ${this.sessions.size}`);
      this.broadcastCount();
    }
  }
  /**
   * 向所有连接的客户端广播在线人数
   */
  broadcastCount() {
    const count = this.sessions.size;
    const message = JSON.stringify({
      type: "count_update",
      count,
      timestamp: Date.now()
    });
    console.log(`Broadcasting count ${count} to ${this.webSockets.size} clients`);
    for (const [ws, sessionId] of this.webSockets.entries()) {
      try {
        ws.send(message);
        console.log(`Sent update to session ${sessionId}`);
      } catch (error) {
        console.error(`Failed to send to session ${sessionId}:`, error);
        this.webSockets.delete(ws);
        this.sessions.delete(sessionId);
      }
    }
  }
  /**
   * HTTP 降级方案：用户加入活动
   */
  async handleJoin(request) {
    const { sessionId } = await request.json();
    if (!sessionId) {
      return this.jsonResponse({ error: "sessionId required" }, 400);
    }
    const now = Date.now();
    this.sessions.set(sessionId, { lastHeartbeat: now, ws: null });
    await this.ensureAlarm();
    console.log(`Session ${sessionId} joined via HTTP. Total: ${this.sessions.size}`);
    return this.jsonResponse({
      success: true,
      sessionId,
      count: this.sessions.size
    });
  }
  /**
   * HTTP 降级方案：用户心跳保活
   */
  async handleHeartbeat(request) {
    const { sessionId } = await request.json();
    if (!sessionId) {
      return this.jsonResponse({ error: "sessionId required" }, 400);
    }
    const session = this.sessions.get(sessionId);
    if (!session) {
      return this.jsonResponse({
        error: "Session not found",
        shouldRejoin: true
      }, 404);
    }
    session.lastHeartbeat = Date.now();
    return this.jsonResponse({
      success: true,
      count: this.sessions.size
    });
  }
  /**
   * HTTP 降级方案：用户主动离开
   */
  async handleLeave(request) {
    const { sessionId } = await request.json();
    if (!sessionId) {
      return this.jsonResponse({ error: "sessionId required" }, 400);
    }
    const existed = this.sessions.delete(sessionId);
    console.log(`Session ${sessionId} left via HTTP. Total: ${this.sessions.size}`);
    return this.jsonResponse({
      success: true,
      existed,
      count: this.sessions.size
    });
  }
  /**
   * 获取当前在线人数
   */
  async handleCount() {
    await this.cleanupTimeoutSessions();
    return this.jsonResponse({
      count: this.sessions.size
    });
  }
  /**
   * 清理超时的会话
   */
  async cleanupTimeoutSessions() {
    const now = Date.now();
    let cleanedCount = 0;
    for (const [sessionId, session] of this.sessions.entries()) {
      if (now - session.lastHeartbeat > this.TIMEOUT_MS) {
        this.sessions.delete(sessionId);
        if (session.ws) {
          this.webSockets.delete(session.ws);
          try {
            session.ws.close(1e3, "Session timeout");
          } catch (e) {
            console.error("Error closing WebSocket:", e);
          }
        }
        cleanedCount++;
      }
    }
    if (cleanedCount > 0) {
      console.log(`Cleaned ${cleanedCount} timeout sessions. Remaining: ${this.sessions.size}`);
      this.broadcastCount();
    }
    return cleanedCount;
  }
  /**
   * 确保设置了定时清理alarm
   */
  async ensureAlarm() {
    const currentAlarm = await this.state.storage.getAlarm();
    if (currentAlarm === null) {
      await this.state.storage.setAlarm(Date.now() + this.CLEANUP_INTERVAL_MS);
    }
  }
  /**
   * Alarm处理器 - 定期清理超时会话
   */
  async alarm() {
    await this.cleanupTimeoutSessions();
    if (this.sessions.size > 0) {
      await this.state.storage.setAlarm(Date.now() + this.CLEANUP_INTERVAL_MS);
    }
  }
  /**
   * 辅助方法：返回JSON响应
   */
  jsonResponse(data, status = 200) {
    return new Response(JSON.stringify(data), {
      status,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type"
      }
    });
  }
};

// worker-modular.js
var worker_modular_default = {
  async fetch(request, env, ctx) {
    try {
      const url = new URL(request.url);
      console.log(`\u{1F4E5} Request: ${request.method} ${url.pathname}${url.search}`);
      if (url.pathname === "/api/online/ws") {
        const upgradeHeader = request.headers.get("Upgrade");
        const activityType = url.searchParams.get("activityType");
        console.log("WebSocket request received:", {
          path: url.pathname,
          upgrade: upgradeHeader,
          activityType,
          method: request.method,
          headers: Object.fromEntries(request.headers.entries())
        });
        if (upgradeHeader && upgradeHeader.toLowerCase() === "websocket") {
          if (!activityType || !["global_sending", "zen_room"].includes(activityType)) {
            console.log("\u274C Invalid activityType:", activityType);
            return new Response("Invalid activityType", { status: 400 });
          }
          console.log("\u2705 WebSocket upgrade - forwarding to Durable Object:", activityType);
          try {
            const id = env.ONLINE_COUNTER.idFromName(activityType);
            const stub = env.ONLINE_COUNTER.get(id);
            const response2 = await stub.fetch(request);
            console.log("\u{1F4E1} Durable Object response status:", response2.status);
            return response2;
          } catch (error) {
            console.error("\u274C Error forwarding to Durable Object:", error);
            return new Response("WebSocket upgrade failed: " + error.message, { status: 500 });
          }
        } else {
          console.log("\u26A0\uFE0F Not a WebSocket upgrade request, upgrade header:", upgradeHeader);
        }
      }
      const db = new DatabaseService(env.DB);
      const response = await route(request, env, db);
      if (response) return response;
      if (url.pathname === "/support" || url.pathname === "/support/") {
        try {
          if (env.ASSETS) {
            const supportRequest = new Request(new URL("/support/index.html", request.url), request);
            const assetResponse = await env.ASSETS.fetch(supportRequest);
            if (assetResponse.status === 200) {
              const newResponse = new Response(assetResponse.body, {
                status: 200,
                headers: {
                  "Content-Type": "text/html; charset=utf-8",
                  "Access-Control-Allow-Origin": "*",
                  "Cache-Control": "public, max-age=3600"
                }
              });
              return newResponse;
            }
          }
        } catch (e) {
          console.error("Error serving support page from assets:", e);
        }
        return Response.redirect(new URL("/support/index.html", request.url).href, 307);
      }
      if (env.ASSETS) {
        const url2 = new URL(request.url);
        const pathname = url2.pathname;
        let assetResponse = await env.ASSETS.fetch(request);
        if (assetResponse.status === 404 && !pathname.startsWith("/api/")) {
          if (pathname === "/support" || pathname === "/support/") {
            const supportRequest = new Request(new URL("/support/index.html", request.url), request);
            const supportResponse = await env.ASSETS.fetch(supportRequest);
            if (supportResponse.status === 200) {
              assetResponse = supportResponse;
            }
          } else if (!/\.[^/]+$/.test(pathname) && !pathname.startsWith("/support/")) {
            const spaRequest = new Request(new URL("/index.html", request.url), request);
            assetResponse = await env.ASSETS.fetch(spaRequest);
          }
        }
        const newResponse = new Response(
          request.method === "HEAD" ? null : assetResponse.body,
          {
            status: assetResponse.status,
            statusText: assetResponse.statusText,
            headers: assetResponse.headers
          }
        );
        newResponse.headers.set("Access-Control-Allow-Origin", "*");
        const noCacheList = ["/", "/index.html", "/support/", "/support/index.html", "/flutter_service_worker.js", "/main.dart.js"];
        if (noCacheList.includes(pathname)) {
          newResponse.headers.set("Cache-Control", "no-cache, no-store, must-revalidate");
        } else if (/\.(js|css|png|jpg|jpeg|gif|svg|woff2?|json|wasm)$/i.test(pathname)) {
          if (!newResponse.headers.has("Cache-Control")) {
            newResponse.headers.set("Cache-Control", "public, max-age=31536000, immutable");
          }
        }
        return newResponse;
      }
      return new Response("Not Found", { status: 404, headers: { "Access-Control-Allow-Origin": "*" } });
    } catch (error) {
      console.error("Worker error:", error);
      return new Response("Internal Server Error", {
        status: 500,
        headers: { "Access-Control-Allow-Origin": "*" }
      });
    }
  }
};
export {
  OnlineCounter,
  worker_modular_default as default
};
//# sourceMappingURL=worker-modular.js.map
